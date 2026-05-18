import AVFoundation
import SwiftUI
import UIKit

/// Live camera preview with photo + video capture for the home swipe surface.
@MainActor
final class CameraCaptureModel: NSObject, ObservableObject {
    enum Mode: String, CaseIterable {
        case post = "POST"
        case reel = "REEL"
    }

    @Published var mode: Mode = .post
    @Published var permissionDenied = false
    @Published var isRecording = false
    @Published var errorMessage: String?

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "tribe.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var currentPosition: AVCaptureDevice.Position = .back
    private var recordingCompletion: ((Result<URL, Error>) -> Void)?

    private var photoCompletion: ((UIImage?) -> Void)?

    func configure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSessionIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.startSessionIfNeeded()
                    } else {
                        self?.permissionDenied = true
                    }
                }
            }
        default:
            permissionDenied = true
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func flipCamera() {
        sessionQueue.async { [weak self] in
            self?.reconfigureCamera(position: self?.currentPosition == .back ? .front : .back)
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard mode == .post else { return }
        photoCompletion = completion
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func toggleRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        guard mode == .reel else { return }
        if isRecording {
            movieOutput.stopRecording()
            recordingCompletion = completion
        } else {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("reel-capture-\(UUID().uuidString).mov")
            try? FileManager.default.removeItem(at: url)
            recordingCompletion = completion
            movieOutput.startRecording(to: url, recordingDelegate: self)
            isRecording = true
        }
    }

    private func startSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.inputs.isEmpty {
                self.reconfigureCamera(position: .back)
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    private func reconfigureCamera(position: AVCaptureDevice.Position) {
        session.beginConfiguration()
        for input in session.inputs { session.removeInput(input) }
        for output in session.outputs { session.removeOutput(output) }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            session.commitConfiguration()
            Task { @MainActor in self.permissionDenied = true }
            return
        }
        session.addInput(input)
        videoInput = input
        currentPosition = position

        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }

        session.sessionPreset = .high
        session.commitConfiguration()
    }
}

extension CameraCaptureModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
        Task { @MainActor in
            photoCompletion?(image)
            photoCompletion = nil
        }
    }
}

extension CameraCaptureModel: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            isRecording = false
            if let error {
                recordingCompletion?(.failure(error))
            } else {
                recordingCompletion?(.success(outputFileURL))
            }
            recordingCompletion = nil
        }
    }
}

struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
