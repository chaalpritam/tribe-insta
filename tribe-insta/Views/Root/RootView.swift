import SwiftUI

/// Five-tab shell: Home, Search, Messages (center), Reels, Profile (avatar).
/// Swipe left on Home to open the camera. Create is no longer a tab.
struct RootView: View {
    enum Tab: Hashable {
        case feed, search, messages, reels, profile
    }

    @EnvironmentObject private var state: AppState
    @State private var selection: Tab = .feed
    @State private var showBackupReminder = false
    @AppStorage("tribe.hasSeenBackupReminder") private var hasSeenBackupReminder = false

    private let badgeTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView(selection: $selection) {
            HomeShellView()
                .tabItem {
                    Label("Home", systemImage: selection == .feed ? "house.fill" : "house")
                }
                .tag(Tab.feed)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)

            InboxView(embeddedInTab: true)
                .tabItem {
                    Label("Messages", systemImage: selection == .messages ? "paperplane.fill" : "paperplane")
                }
                .tag(Tab.messages)
                .badge(state.unreadDMCount > 0 ? state.unreadDMCount : 0)

            ReelsView()
                .tabItem { Label("Reels", systemImage: "play.square") }
                .tag(Tab.reels)

            ProfileView()
                .tabItem {
                    Label {
                        Text("Profile")
                    } icon: {
                        ProfileTabIcon(
                            avatarURL: state.myAvatarURL,
                            isSelected: selection == .profile
                        )
                    }
                }
                .tag(Tab.profile)
        }
        .tint(.primary)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color(.systemBackground), for: .tabBar)
        .toolbarColorScheme(.none, for: .tabBar)
        .task { await state.refreshBadgeCounts() }
        .onChange(of: selection) { _, _ in
            Task { await state.refreshBadgeCounts() }
        }
        .onReceive(badgeTimer) { _ in
            Task { await state.refreshBadgeCounts() }
        }
        .onAppear {
            if !hasSeenBackupReminder {
                showBackupReminder = true
                hasSeenBackupReminder = true
            }
        }
        .alert("Back up your account", isPresented: $showBackupReminder) {
            Button("Open Settings") { selection = .profile }
            Button("Later", role: .cancel) {}
        } message: {
            Text("Export a .tribe backup from Settings before you lose this device. It's the only way to recover your app key.")
        }
        .sheet(item: $state.pendingDeepLink) { link in
            deepLinkSheet(link)
        }
    }

    @ViewBuilder
    private func deepLinkSheet(_ link: DeepLink) -> some View {
        switch link {
        case .post(let hash):
            PostDetailLoaderView(hash: hash)
        case .profile(let tid):
            NavigationStack {
                UserProfileView(tid: tid)
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .environmentObject(TribeService(state: AppState()))
}
