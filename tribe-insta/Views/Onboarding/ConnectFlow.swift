import SwiftUI

struct ConnectFlow: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ConnectWelcomeView { path.append(Step.hub) }
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .hub:
                        ConfigureHubView { path.append(Step.identity) }
                    case .identity:
                        IdentityChoiceView(path: $path)
                    case .qrLogin:
                        QRLoginView()
                    case .seedPhrase:
                        SeedPhraseConnectView()
                    case .createKey:
                        CreateAppKeyView()
                    case .importKey:
                        ImportIdentityView()
                    case .restoreBackup:
                        RestoreBackupView()
                    }
                }
        }
    }

    enum Step: Hashable {
        case hub
        case identity
        case qrLogin
        case seedPhrase
        case createKey
        case importKey
        case restoreBackup
    }
}

// MARK: - Welcome

private struct ConnectWelcomeView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "camera.circle.fill")
                .font(.system(size: 72))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.primary)
            VStack(spacing: 8) {
                Text("Tribe")
                    .font(.largeTitle.bold())
                Text("Photo social on the Tribe protocol. Connect your identity and share posts, stories, and reels with your network.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Button("Get started", action: onContinue)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.onboardingBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Hub

private struct ConfigureHubView: View {
    @EnvironmentObject private var app: AppState
    @State private var hubInput = ""
    @State private var validating = false
    @State private var error: String?
    var onContinue: () -> Void

    var body: some View {
        Form {
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
            } footer: {
                Text("Point at your Tribe hub. On a phone, use your Mac's LAN IP (from `tribe share`) instead of 127.0.0.1.")
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
                    Task { await validate() }
                } label: {
                    HStack {
                        if validating { ProgressView() }
                        Text(validating ? "Checking…" : "Continue")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(validating || hubInput.isEmpty)
            }
        }
        .navigationTitle("Connect to hub")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if hubInput.isEmpty { hubInput = app.hubBaseURL.absoluteString }
        }
    }

    private func validate() async {
        guard let url = URL(string: hubInput.trimmingCharacters(in: .whitespaces)),
              url.scheme == "http" || url.scheme == "https" else {
            error = "URL must start with http:// or https://"
            return
        }
        validating = true
        error = nil
        defer { validating = false }
        let probe = HubClient(baseURL: url)
        do {
            struct Health: Decodable { let status: String? }
            let _: Health = try await probe.get("health")
            app.hubBaseURL = url
            onContinue()
        } catch {
            self.error = "Couldn't reach hub: \(error.localizedDescription)"
        }
    }
}

// MARK: - Identity choice

private struct IdentityChoiceView: View {
    @Binding var path: NavigationPath

    var body: some View {
        List {
            Section {
                Text("Your TID lives on Solana. This device holds an app key that signs protocol envelopes.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .listRowBackground(Color.clear)
            }

            Section {
                identityRow(
                    icon: "qrcode.viewfinder",
                    title: "Scan QR to sign in",
                    subtitle: "Pair from tribe-app → Wallet → Pair phone"
                ) { path.append(ConnectFlow.Step.qrLogin) }

                identityRow(
                    icon: "list.bullet.rectangle",
                    title: "Seed phrase",
                    subtitle: "Recover wallet via BIP39, then paste your app key"
                ) { path.append(ConnectFlow.Step.seedPhrase) }

                identityRow(
                    icon: "key.horizontal",
                    title: "Create app key",
                    subtitle: "Generate a fresh ed25519 key on this device"
                ) { path.append(ConnectFlow.Step.createKey) }

                identityRow(
                    icon: "square.and.arrow.down",
                    title: "Import TID + app key",
                    subtitle: "Paste credentials from tribe-app"
                ) { path.append(ConnectFlow.Step.importKey) }

                identityRow(
                    icon: "doc.badge.arrow.up",
                    iconTint: Theme.primary,
                    title: "Restore from backup",
                    subtitle: "Open a .tribe / .tribe.enc file from tribe-app"
                ) { path.append(ConnectFlow.Step.restoreBackup) }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.onboardingBackground.ignoresSafeArea())
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.large)
    }

    private func identityRow(
        icon: String,
        iconTint: Color = Theme.primary,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(iconTint)
            }
        }
    }
}
