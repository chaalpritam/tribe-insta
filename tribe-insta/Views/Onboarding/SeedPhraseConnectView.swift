import SwiftUI
import TribeCore

struct SeedPhraseConnectView: View {
    @EnvironmentObject private var app: AppState

    @State private var phraseInput = ""
    @State private var appKeyInput = ""
    @State private var resolving = false
    @State private var adopting = false
    @State private var resolved: ResolvedWallet?
    @State private var error: String?

    private struct ResolvedWallet: Equatable {
        let address: String
        let user: HubUser
    }

    var body: some View {
        Form {
            Section {
                TextEditor(text: $phraseInput)
                    .frame(minHeight: 88)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("BIP39 seed phrase")
            } footer: {
                Text("12 or 24 words. Derives the same Solana wallet as Phantom (m/44'/501'/0'/0').")
            }

            if resolved == nil {
                Section {
                    Button {
                        Task { await resolve() }
                    } label: {
                        HStack {
                            if resolving { ProgressView() }
                            Text(resolving ? "Looking up TID…" : "Find my TID")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(resolving || phraseInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if let resolved {
                Section {
                    LabeledContent("Wallet") {
                        Text(short(resolved.address))
                            .font(.system(.footnote, design: .monospaced))
                    }
                    LabeledContent("TID", value: resolved.user.tid)
                    if let username = resolved.user.username {
                        LabeledContent("Username", value: "\(username).tribe")
                    }
                } header: {
                    Text("Found on hub")
                }

                Section {
                    TextEditor(text: $appKeyInput)
                        .frame(minHeight: 64)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("App key (base64)")
                } footer: {
                    Text("From tribe-twitter-app Settings → View app key. Signs envelopes on this device.")
                }

                Section {
                    Button {
                        Task { await signIn() }
                    } label: {
                        HStack {
                            if adopting { ProgressView() }
                            Text(adopting ? "Connecting…" : "Continue")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(adopting || appKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Theme.error)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Seed phrase")
        .navigationBarTitleDisplayMode(.inline)
        .opaqueNavBar()
    }

    private func resolve() async {
        resolving = true
        defer { resolving = false }
        error = nil
        do {
            let (address, _) = try SolanaHD.keypair(fromMnemonic: phraseInput)
            guard let user = try await app.api.fetchTidByWallet(address) else {
                error = "No TID registered to this wallet on this hub. Finish onboarding in tribe-twitter-app first."
                return
            }
            resolved = ResolvedWallet(address: address, user: user)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func signIn() async {
        guard let resolved else { return }
        adopting = true
        defer { adopting = false }
        error = nil
        do {
            let (address, privateKey) = try SolanaHD.keypair(fromMnemonic: phraseInput)
            let key = try AppKey.restore(seedBase64: appKeyInput)
            try CustodyKey.save(seed: privateKey, address: address)
            try await app.completeConnect(
                tid: resolved.user.tid,
                appKey: key,
                walletAddress: address
            )
            app.refreshCustodyKey()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func short(_ s: String) -> String {
        guard s.count > 10 else { return s }
        return "\(s.prefix(5))…\(s.suffix(5))"
    }
}
