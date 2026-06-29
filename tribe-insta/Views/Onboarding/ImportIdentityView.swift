import SwiftUI
import TribeCore

struct ImportIdentityView: View {
    @EnvironmentObject private var app: AppState

    @State private var tidInput = ""
    @State private var seedInput = ""
    @State private var error: String?
    @State private var working = false

    var body: some View {
        Form {
            Section {
                TextField("TID", text: $tidInput)
                    .keyboardType(.numberPad)
            } header: {
                Text("TID")
            }

            Section {
                TextEditor(text: $seedInput)
                    .frame(minHeight: 88)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("App key (base64)")
            } footer: {
                Text("From tribe-app local storage or Settings → View app key.")
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
                    Task { await complete() }
                } label: {
                    HStack {
                        if working { ProgressView() }
                        Text(working ? "Connecting…" : "Continue")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(working || tidInput.isEmpty || seedInput.isEmpty)
            }
        }
        .navigationTitle("Import identity")
        .navigationBarTitleDisplayMode(.inline)
        .opaqueNavBar()
    }

    private func complete() async {
        let tid = tidInput.trimmingCharacters(in: .whitespaces)
        guard !tid.isEmpty, Int64(tid) != nil else {
            error = "TID must be a number."
            return
        }
        working = true
        defer { working = false }
        do {
            let key = try AppKey.restore(seedBase64: seedInput)
            _ = try? await app.api.fetchUser(tid)
            try await app.completeConnect(tid: tid, appKey: key)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
