import SwiftUI
import UniformTypeIdentifiers

/// First-launch flow. Imports an existing identity from a `.tribe` or
/// `.tribe.enc` backup file exported from tribe-app or tribe-ios. The
/// IG-shaped client doesn't yet generate identities on its own — that
/// lands when the Solana wallet flow ships (see PLAN.md Phase 2+).
struct OnboardingView: View {
    @EnvironmentObject private var state: AppState

    @State private var hubURLText: String = ""
    @State private var fileContents: String?
    @State private var filename: String?
    @State private var password: String = ""
    @State private var showFilePicker: Bool = false
    @State private var isImporting: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    pairFromDesktopSection
                    orDivider
                    hubSection
                    backupSection
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    importButton
                    helpFootnote
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Tribe")
                        .font(.system(.title3, design: .serif).italic())
                        .fontWeight(.bold)
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: backupContentTypes(),
            allowsMultipleSelection: false
        ) { result in
            handleFilePick(result)
        }
        .onAppear {
            if hubURLText.isEmpty { hubURLText = state.hubBaseURL.absoluteString }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome to Tribe")
                .font(.title2).fontWeight(.semibold)
            Text("Bring your existing identity over from tribe-app or tribe-ios. Pick a backup file you've already exported — we never see your seed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var pairFromDesktopSection: some View {
        NavigationLink {
            PairFromDesktopView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan QR from desktop")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("Fastest. Use tribe-app → Settings → Log in on mobile.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1)
            Text("OR")
                .font(.caption2).fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1)
        }
    }

    private var hubSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hub URL").font(.caption).foregroundStyle(.secondary)
            TextField("http://127.0.0.1:4000", text: $hubURLText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .padding(10)
                .background(Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 10))
            Text("The tribe-hub instance to talk to. Defaults to localhost — change it to a LAN or Tailscale IP if your hub is on another machine.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Backup file").font(.caption).foregroundStyle(.secondary)
            Button {
                showFilePicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.badge.plus").font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(filename ?? "Choose a .tribe file")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text(filename == nil
                             ? "Exported from tribe-app → Settings → Export account"
                             : (isEncryptedFile ? "Encrypted — enter password below" : "Plain backup — no password needed"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            if isEncryptedFile {
                SecureField("Backup password", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var importButton: some View {
        Button {
            Task { await runImport() }
        } label: {
            HStack {
                if isImporting { ProgressView().controlSize(.small) }
                Text(isImporting ? "Importing…" : "Import & continue")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(canSubmit ? Color.accentColor : Color.gray.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
        }
        .disabled(!canSubmit || isImporting)
    }

    private var helpFootnote: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Don't have a backup yet?")
                .font(.caption).foregroundStyle(.secondary)
            Text("Create an account on tribe-app (brew install tribe-app && tribe-app), then go to Settings → Export account. Bring the .tribe file back here.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Derived

    private var isEncryptedFile: Bool {
        guard let contents = fileContents else { return false }
        return BackupFile.isEncrypted(contents)
    }

    private var canSubmit: Bool {
        guard fileContents != nil,
              !hubURLText.trimmingCharacters(in: .whitespaces).isEmpty,
              URL(string: hubURLText) != nil
        else { return false }
        if isEncryptedFile, password.isEmpty { return false }
        return true
    }

    // MARK: - Actions

    private func handleFilePick(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let needsRelease = url.startAccessingSecurityScopedResource()
            defer { if needsRelease { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8) else {
                    throw BackupError.invalidJSON
                }
                fileContents = text
                filename = url.lastPathComponent
                errorMessage = nil
            } catch {
                errorMessage = "Couldn't read file: \(error.localizedDescription)"
                fileContents = nil
                filename = nil
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func runImport() async {
        guard let text = fileContents else { return }
        guard let url = URL(string: hubURLText) else {
            errorMessage = "Hub URL is not valid."
            return
        }
        isImporting = true
        defer { isImporting = false }
        do {
            let backup = try BackupFile.decode(
                text: text,
                password: password.isEmpty ? nil : password
            )
            let result = try backup.apply()
            state.hubBaseURL = url
            try state.adopt(tid: result.tid, appKey: result.appKey)
            state.walletAddress = result.walletAddress
        } catch let error as BackupError {
            errorMessage = error.errorDescription ?? "Could not import backup."
        } catch {
            errorMessage = "Could not import: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    /// .tribe / .tribe.enc don't have registered UTI types, so we
    /// accept text + data and rely on the picker showing everything.
    private func backupContentTypes() -> [UTType] {
        [.data, .text, .plainText, .json]
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
