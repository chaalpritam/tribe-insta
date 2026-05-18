import SwiftUI

/// Settings sheet — hub URL, ER URL, identity info, sign out.
/// Reachable from the Profile screen's menu button.
struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var hubURLText: String = ""
    @State private var erURLText: String = ""
    @State private var showExportBackup = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Hub") {
                    ForEach(HubPresets.quickPicks, id: \.label) { pick in
                        Button(pick.label) {
                            hubURLText = pick.url.absoluteString
                        }
                    }
                    TextField("http://127.0.0.1:4000", text: $hubURLText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button("Remember as LAN hub") {
                        if let url = URL(string: hubURLText) {
                            HubPresets.saveLANHub(url)
                        }
                    }
                    Text("Use your Mac's LAN IP from `tribe share` when testing on a phone.")
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

                Section("Content") {
                    NavigationLink {
                        SavedPostsView()
                    } label: {
                        Label("Saved posts", systemImage: "bookmark")
                    }
                    NavigationLink {
                        BlockedUsersView()
                    } label: {
                        Label("Blocked accounts", systemImage: "hand.raised")
                    }
                }

                Section("Account") {
                    Button {
                        showExportBackup = true
                    } label: {
                        Label("Export backup", systemImage: "square.and.arrow.up")
                    }
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
                    Text("Sign out wipes the app key and TID from this device. Export a backup first. Follows and unfollows still require tribe-app (Solana custody key).")
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
        .sheet(isPresented: $showExportBackup) {
            ExportBackupSheet()
        }
    }

    private func applyAndDismiss() {
        if let url = URL(string: hubURLText) {
            if url != state.hubBaseURL { state.hubBaseURL = url }
            if url.host != "127.0.0.1", url.host != "localhost" {
                HubPresets.saveLANHub(url)
            }
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
