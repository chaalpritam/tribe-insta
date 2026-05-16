import SwiftUI

/// Settings sheet — hub URL, ER URL, identity info, sign out.
/// Reachable from the Profile screen's menu button.
struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var hubURLText: String = ""
    @State private var erURLText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Hub") {
                    TextField("http://127.0.0.1:4000", text: $hubURLText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Text("Where signed envelopes go and where the feed comes from.")
                        .font(.caption2).foregroundStyle(.secondary)
                }

                Section("Ephemeral Rollup") {
                    TextField("http://127.0.0.1:3003", text: $erURLText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Text("Sequencer that surfaces instant follow state.")
                        .font(.caption2).foregroundStyle(.secondary)
                }

                Section("Identity") {
                    LabeledContent("TID", value: state.myTID ?? "—")
                    LabeledContent("Username", value: state.myUsername ?? "—")
                    if let wallet = state.walletAddress, !wallet.isEmpty {
                        LabeledContent("Wallet") {
                            Text(wallet)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }

                Section {
                    Button("Sign out", role: .destructive) {
                        state.signOut()
                        dismiss()
                    }
                } footer: {
                    Text("Sign out wipes the app key and TID from this device. Your backup file is the only way back in — keep it somewhere safe.")
                        .font(.caption2)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { applyAndDismiss() }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            hubURLText = state.hubBaseURL.absoluteString
            erURLText = state.erBaseURL.absoluteString
        }
    }

    private func applyAndDismiss() {
        if let url = URL(string: hubURLText), url != state.hubBaseURL {
            state.hubBaseURL = url
        }
        if let url = URL(string: erURLText), url != state.erBaseURL {
            state.erBaseURL = url
        }
        dismiss()
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
