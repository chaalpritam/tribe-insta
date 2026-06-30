import SwiftUI

/// Five-tab shell: Home, Search, Messages (center), Reels, Profile (avatar).
/// Swipe left on Home to open the camera. Uses a custom bottom bar instead of
/// SwiftUI `TabView` so iOS 26's floating Liquid Glass tab bar never appears.
struct RootView: View {
    enum Tab: Hashable {
        case feed, search, reels, profile
    }

    @EnvironmentObject private var state: AppState
    @State private var selection: Tab = .feed
    @State private var showCreateSheet = false
    @State private var showBackupReminder = false
    @AppStorage("tribe.hasSeenBackupReminder") private var hasSeenBackupReminder = false

    private let badgeTimer = Timer.publish(every: 120, on: .main, in: .common).autoconnect()

    var body: some View {
        tabContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                InstaBottomTabBar(
                    selection: $selection,
                    profileAvatarURL: state.myAvatarURL,
                    onCreateTap: { showCreateSheet = true }
                )
            }
            .sheet(isPresented: $showCreateSheet) {
                CreatePostView(onPublished: {
                    showCreateSheet = false
                    selection = .feed
                })
            }
            .task { await state.refreshBadgeCounts() }
            .onChange(of: selection) { _, _ in
                Task { await state.refreshBadgeCounts() }
            }
            .onReceive(badgeTimer) { _ in
                Task { await state.refreshBadgeCounts() }
            }
            .onAppear {
                TabBarAppearance.apply()
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
    private var tabContent: some View {
        switch selection {
        case .feed:
            HomeShellView()
        case .search:
            SearchView()
        case .reels:
            ReelsView()
        case .profile:
            ProfileView()
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
