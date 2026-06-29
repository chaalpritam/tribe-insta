import SwiftUI
import TribeCore

struct CreateAppKeyView: View {
    @EnvironmentObject private var app: AppState

    @State private var generated = AppKey.generate()
    @State private var tidInput = ""
    @State private var acknowledgedBackup = false
    @State private var working = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                Text(generated.seedBase64)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                Button {
                    UIPasteboard.general.string = generated.seedBase64
                } label: {
                    Label("Copy app key", systemImage: "doc.on.doc")
                }
            } header: {
                Text("New app key")
            } footer: {
                Text("Save this seed before continuing. It signs every envelope from this device.")
            }

            Section {
                Toggle("I've saved the app key", isOn: $acknowledgedBackup)
            }

            Section {
                TextField("TID", text: $tidInput)
                    .keyboardType(.numberPad)
            } header: {
                Text("Your TID")
            } footer: {
                Text("Register a TID in tribe-twitter-app first, then enter it here.")
            }

            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Theme.error)
                        .font(.footnote)
                }
            }

            Section {
                Button {
                    Task { await finish() }
                } label: {
                    HStack {
                        if working { ProgressView() }
                        Text(working ? "Connecting…" : "Continue")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(working || !acknowledgedBackup || tidInput.isEmpty)
            }
        }
        .navigationTitle("Create app key")
        .navigationBarTitleDisplayMode(.inline)
        .opaqueNavBar()
    }

    private func finish() async {
        let tid = tidInput.trimmingCharacters(in: .whitespaces)
        guard Int64(tid) != nil else {
            error = "TID must be a number."
            return
        }
        working = true
        defer { working = false }
        do {
            try await app.completeConnect(tid: tid, appKey: generated)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
