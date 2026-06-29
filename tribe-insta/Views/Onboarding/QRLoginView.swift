import AVFoundation
import SwiftUI
import TribeCore

struct QRLoginView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var status: Status = .scanning
    @State private var lastPayload: String?

    enum Status: Equatable {
        case scanning
        case validating
        case error(String)
    }

    var body: some View {
        ZStack {
            QRScannerRepresentable(onPayload: handle)
                .ignoresSafeArea()

            VStack {
                Spacer()
                instructionsCard
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            }
        }
        .navigationTitle("Scan to sign in")
        .navigationBarTitleDisplayMode(.inline)
        .opaqueNavBar()
    }

    private var instructionsCard: some View {
        VStack(spacing: 10) {
            switch status {
            case .scanning:
                Label("Point at the QR in tribe-app → Wallet → Pair phone", systemImage: "viewfinder")
                    .font(.subheadline)
            case .validating:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Signing in…").font(.subheadline)
                }
            case .error(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(Theme.error)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func handle(_ raw: String) {
        guard raw != lastPayload else { return }
        guard status == .scanning else { return }
        lastPayload = raw
        status = .validating
        Task { await connect(with: raw) }
    }

    private func connect(with raw: String) async {
        guard let data = raw.data(using: .utf8),
              let payload = try? JSONDecoder().decode(PairingPayload.self, from: data),
              payload.kind == "tribe-pair", payload.v == 1
        else {
            await MainActor.run {
                status = .error("That QR isn't a Tribe pairing code.")
                Task { try? await Task.sleep(nanoseconds: 1_500_000_000); status = .scanning; lastPayload = nil }
            }
            return
        }

        do {
            if let hubURL = URL(string: payload.hubUrl),
               hubURL.scheme == "http" || hubURL.scheme == "https" {
                await MainActor.run { app.hubBaseURL = hubURL }
            }
            let key = try AppKey.restore(seedBase64: payload.appKeySeedB64)
            _ = try? await app.api.fetchUser(payload.tid)
            try await app.completeConnect(tid: payload.tid, appKey: key)
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run {
                status = .error(error.localizedDescription)
                Task { try? await Task.sleep(nanoseconds: 2_000_000_000); status = .scanning; lastPayload = nil }
            }
        }
    }

    private struct PairingPayload: Decodable {
        let v: Int
        let kind: String
        let tid: String
        let appKeySeedB64: String
        let hubUrl: String
    }
}

// MARK: - Camera scanner

private struct QRScannerRepresentable: UIViewControllerRepresentable {
    var onPayload: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onPayload = onPayload
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        uiViewController.onPayload = onPayload
    }
}

private final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onPayload: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let raw = object.stringValue
        else { return }
        onPayload?(raw)
    }
}
