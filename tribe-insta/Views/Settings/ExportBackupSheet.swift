import SwiftUI
import TribeCore

/// Export `.tribe` / `.tribe.enc` compatible with tribe-app and tribe-twitter.
struct ExportBackupSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var encrypt = true
    @State private var password = ""
    @State private var confirm = ""
    @State private var error: String?
    @State private var preparedFile: PreparedFile?
    @State private var working = false

    private var passwordsMatch: Bool { password == confirm && !password.isEmpty }
    private var canExport: Bool {
        guard state.appKey != nil, state.myTID != nil else { return false }
        if encrypt { return passwordsMatch }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Encrypt with password", isOn: $encrypt)
                } footer: {
                    Text(encrypt
                         ? "Same AES-256-GCM format as tribe-app encrypted backups."
                         : "Cleartext JSON — anyone with the file can read your app key.")
                }

                if encrypt {
                    Section {
                        SecureField("Password", text: $password)
                        SecureField("Confirm password", text: $confirm)
                        if !password.isEmpty && !confirm.isEmpty && password != confirm {
                            Label("Passwords don't match", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                                .font(.footnote)
                        }
                    } footer: {
                        Text("There is no password recovery if you lose it.")
                    }
                }

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                Section {
                    Button {
                        Task { await prepare() }
                    } label: {
                        HStack {
                            if working { ProgressView() }
                            Text(working ? "Preparing…" : "Prepare backup")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!canExport || working)

                    if let preparedFile {
                        ShareLink(item: preparedFile.url) {
                            Label("Share \(preparedFile.url.lastPathComponent)",
                                  systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Export account")
            .navigationBarTitleDisplayMode(.inline)
            .opaqueNavBar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func prepare() async {
        guard let tid = state.myTID, let appKey = state.appKey else { return }
        working = true
        defer { working = false }
        error = nil
        let dm = try? DMKey.loadIfExists()
        let backup = BackupFile.build(
            tid: tid,
            walletAddress: state.walletAddress,
            appKey: appKey,
            dmKey: dm,
            browserWalletJSON: BackupFile.storedBrowserWalletJSON()
        )
        do {
            let url: URL
            if encrypt {
                let encrypted = try backup.encrypted(password: password)
                url = try writeTemp(text: encrypted, ext: "tribe.enc", tid: tid)
            } else {
                let plain = try backup.encoded()
                url = try writeTemp(data: plain, ext: "tribe", tid: tid)
            }
            preparedFile = PreparedFile(url: url)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func writeTemp(text: String, ext: String, tid: String) throws -> URL {
        try writeTemp(data: Data(text.utf8), ext: ext, tid: tid)
    }

    private func writeTemp(data: Data, ext: String, tid: String) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let stamp = formatter.string(from: Date())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tribe-\(tid)-\(stamp).\(ext)")
        try data.write(to: url, options: .atomic)
        return url
    }
}

private struct PreparedFile: Equatable {
    let url: URL
}
