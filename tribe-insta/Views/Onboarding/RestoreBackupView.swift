import SwiftUI
import UniformTypeIdentifiers
import TribeCore

/// Import a `.tribe` / `.tribe.enc` backup exported from tribe-app
/// or tribe-twitter. Complements QR / seed / manual app-key paths.
struct RestoreBackupView: View {
    @EnvironmentObject private var app: AppState

    @State private var hubInput = ""
    @State private var fileContents: String?
    @State private var filename: String?
    @State private var password = ""
    @State private var showFilePicker = false
    @State private var working = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                Text("Pick a backup file you've exported from tribe-app or tribe-twitter. Your seed never leaves this device.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            Section {
                ForEach(HubPresets.quickPicks, id: \.label) { pick in
                    Button(pick.label) {
                        hubInput = pick.url.absoluteString
                    }
                }
                TextField("http://127.0.0.1:4000", text: $hubInput)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Hub URL")
            }

            Section {
                Button { showFilePicker = true } label: {
                    HStack {
                        Image(systemName: "doc.badge.arrow.up")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(filename ?? "Choose backup file")
                            Text(filename == nil
                                 ? ".tribe or .tribe.enc from tribe-app → Settings"
                                 : (isEncrypted ? "Enter password below" : "Ready to import"))
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                    }
                }
                if isEncrypted {
                    SecureField("Backup password", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            } header: {
                Text("Backup file")
            }

            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Theme.error)
                        .font(.footnote)
                }
            }

            Section {
                Button { Task { await runImport() } } label: {
                    HStack {
                        if working { ProgressView() }
                        Text(working ? "Importing…" : "Import & continue")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(!canSubmit || working)
            }
        }
        .navigationTitle("Restore backup")
        .navigationBarTitleDisplayMode(.inline)
        .opaqueNavBar()
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.data, .text, .plainText, .json],
            allowsMultipleSelection: false
        ) { handleFilePick($0) }
        .onAppear {
            if hubInput.isEmpty { hubInput = app.hubBaseURL.absoluteString }
        }
    }

    private var isEncrypted: Bool {
        guard let fileContents else { return false }
        return BackupFile.isEncrypted(fileContents)
    }

    private var canSubmit: Bool {
        guard fileContents != nil,
              URL(string: hubInput.trimmingCharacters(in: .whitespaces)) != nil
        else { return false }
        if isEncrypted, password.isEmpty { return false }
        return true
    }

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
                error = nil
            } catch let err {
                error = "Couldn't read file: \(err.localizedDescription)"
                fileContents = nil
                filename = nil
            }
        case .failure(let err):
            error = err.localizedDescription
        }
    }

    private func runImport() async {
        guard let text = fileContents,
              let url = URL(string: hubInput.trimmingCharacters(in: .whitespaces))
        else {
            error = "Hub URL is not valid."
            return
        }
        working = true
        defer { working = false }
        do {
            let backup = try BackupFile.decode(
                text: text,
                password: password.isEmpty ? nil : password
            )
            let result = try backup.apply()
            app.hubBaseURL = url
            try await app.completeConnect(
                tid: result.tid,
                appKey: result.appKey,
                walletAddress: result.walletAddress
            )
        } catch let err as BackupError {
            error = err.errorDescription ?? "Could not import backup."
        } catch let err {
            error = err.localizedDescription
        }
    }
}
