import PhotosUI
import SwiftUI

/// Full-screen camera reached by swiping left on Home. Capture a photo (post)
/// or record a reel, then open the compose sheet to publish.
struct CameraComposerView: View {
    var onClose: () -> Void

    @StateObject private var camera = CameraCaptureModel()
    @State private var showCompose = false
    @State private var composeMode: CreatePostView.Mode = .post
    @State private var capturedPhoto: UIImage?
    @State private var capturedVideoURL: URL?
    @State private var pickerItems: [PhotosPickerItem] = []

    var body: some View {
        ZStack {
            if camera.permissionDenied {
                permissionFallback
            } else {
                CameraPreviewRepresentable(session: camera.session)
                    .ignoresSafeArea()
            }

            controlsOverlay
        }
        .background(Color.black)
        .onAppear { camera.configure() }
        .onDisappear { camera.stop() }
        .fullScreenCover(isPresented: $showCompose, onDismiss: resetCapture) {
            CreatePostView(
                initialMode: composeMode,
                initialPhoto: capturedPhoto,
                initialVideoURL: capturedVideoURL,
                onPublished: onClose
            )
        }
        .onChange(of: pickerItems) { _, items in
            guard let first = items.first else { return }
            Task { await importFromLibrary(first) }
        }
    }

    private var controlsOverlay: some View {
        VStack {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                }
                Spacer()
                Button { camera.flipCamera() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(10)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            Spacer()

            modePicker
                .padding(.bottom, 12)

            HStack(alignment: .center) {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: 1,
                    matching: camera.mode == .reel ? .videos : .images
                ) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                }

                shutterButton
                    .frame(maxWidth: .infinity)

                Color.clear.frame(width: 52, height: 52)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 36)
        }
    }

    private var modePicker: some View {
        HStack(spacing: 20) {
            ForEach(CameraCaptureModel.Mode.allCases, id: \.self) { mode in
                Button {
                    camera.mode = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.caption.weight(camera.mode == mode ? .bold : .regular))
                        .foregroundStyle(camera.mode == mode ? .white : .white.opacity(0.55))
                }
            }
        }
    }

    private var shutterButton: some View {
        Button {
            Task { await handleShutter() }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(.white, lineWidth: 4)
                    .frame(width: 76, height: 76)
                if camera.mode == .reel {
                    RoundedRectangle(cornerRadius: camera.isRecording ? 8 : 34)
                        .fill(camera.isRecording ? .red : .white)
                        .frame(
                            width: camera.isRecording ? 32 : 64,
                            height: camera.isRecording ? 32 : 64
                        )
                        .animation(.easeInOut(duration: 0.15), value: camera.isRecording)
                } else {
                    Circle()
                        .fill(.white)
                        .frame(width: 64, height: 64)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(camera.mode == .reel ? "Record reel" : "Take photo")
    }

    private var permissionFallback: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Camera access needed")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Enable camera in Settings to capture photos and reels.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    @MainActor
    private func handleShutter() async {
        switch camera.mode {
        case .post:
            camera.capturePhoto { image in
                guard let image else { return }
                capturedPhoto = image
                capturedVideoURL = nil
                composeMode = .post
                showCompose = true
            }
        case .reel:
            camera.toggleRecording { result in
                switch result {
                case .success(let url):
                    capturedVideoURL = url
                    capturedPhoto = nil
                    composeMode = .reel
                    showCompose = true
                case .failure(let error):
                    camera.errorMessage = error.localizedDescription
                }
            }
        }
    }

    @MainActor
    private func importFromLibrary(_ item: PhotosPickerItem) async {
        if camera.mode == .reel {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("reel-pick-\(UUID().uuidString).mp4")
            guard (try? data.write(to: tmp)) != nil else { return }
            capturedVideoURL = tmp
            capturedPhoto = nil
            composeMode = .reel
        } else {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            capturedPhoto = image
            capturedVideoURL = nil
            composeMode = .post
        }
        pickerItems = []
        showCompose = true
    }

    private func resetCapture() {
        capturedPhoto = nil
        capturedVideoURL = nil
        pickerItems = []
    }
}
