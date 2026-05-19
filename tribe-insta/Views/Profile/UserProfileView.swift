import SwiftUI

/// Another user's profile — grid of their photo posts + follow CTA.
struct UserProfileView: View {
    let tid: String

    @EnvironmentObject private var service: TribeService
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var user: User?
    @State private var posts: [Post] = []
    @State private var reels: [Reel] = []
    @State private var selectedTab: ProfileView.ProfileTab = .grid
    @State private var followListMode: FollowListView.Mode?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showBlockConfirm = false
    @State private var showMuteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            UserProfileTopBar(
                title: user?.username ?? "Profile",
                showActions: tid != state.myTID,
                isBlocked: state.restrictions.isBlocked(tid),
                onBack: { dismiss() },
                onUnblock: { state.restrictions.unblock(tid) },
                onMute: { showMuteConfirm = true },
                onBlock: { showBlockConfirm = true }
            )
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    if let user {
                        header(user: user)
                    } else if isLoading {
                        ProgressView().padding(40)
                    } else if let errorMessage {
                        errorBlock(errorMessage)
                    }
                    tabSelector
                    tabContent
                }
            }
            .refreshable { await load() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Block @\(user?.username ?? tid)?", isPresented: $showBlockConfirm) {
            Button("Block", role: .destructive) {
                state.restrictions.block(tid)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Their posts, stories, and reels will be hidden on this device.")
        }
        .confirmationDialog("Mute @\(user?.username ?? tid)?", isPresented: $showMuteConfirm) {
            Button("Mute", role: .destructive) {
                state.restrictions.mute(tid)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Their posts won't appear in your feed on this device. You can still visit their profile.")
        }
        .navigationDestination(for: Post.self) { post in
            PostDetailView(post: post)
        }
        .navigationDestination(item: $followListMode) { mode in
            FollowListView(tid: tid, mode: mode)
        }
        .task(id: tid) { await load() }
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(.grid, system: "square.grid.3x3")
            tabButton(.reels, system: "play.square")
            tabButton(.tagged, system: "person.crop.square")
        }
        .background(.bar)
    }

    private func tabButton(_ tab: ProfileView.ProfileTab, system: String) -> some View {
        Button { selectedTab = tab } label: {
            VStack(spacing: 6) {
                Image(systemName: system)
                    .font(.title3)
                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                Rectangle()
                    .fill(selectedTab == tab ? Color.primary : Color.clear)
                    .frame(height: 1)
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .grid:
            ProfilePostsGrid(posts: posts)
        case .reels:
            ProfileReelsGrid(reels: reels)
        case .tagged:
            taggedPlaceholder
        }
    }

    private var taggedPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.square")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No tagged posts")
                .font(.headline)
            Text("Photos you're tagged in aren't indexed on the hub yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private func header(user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 24) {
                AvatarView(url: user.avatarURL, size: 86)
                HStack(spacing: 20) {
                    stat(value: user.postsCount, label: "Posts")
                    Button { followListMode = .followers } label: {
                        stat(value: user.followersCount, label: "Followers")
                    }
                    .buttonStyle(.plain)
                    Button { followListMode = .following } label: {
                        stat(value: user.followingCount, label: "Following")
                    }
                    .buttonStyle(.plain)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName).fontWeight(.semibold)
                if !user.bio.isEmpty {
                    Text(user.bio).font(.subheadline)
                }
            }
            if tid != state.myTID {
                FollowButton(targetTID: tid)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func stat(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(Formatters.compactCount(value)).fontWeight(.semibold)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func errorBlock(_ message: String) -> some View {
        VStack(spacing: 8) {
            Text("Couldn't load profile").font(.headline)
            Text(message).font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await load() } }
        }
        .padding(40)
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await service.profile(tid: tid)
            user = result.user
            posts = result.posts
            reels = result.reels
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

/// Custom IG-style top bar for push-navigated profiles. System nav is
/// hidden because iOS 26's Liquid Glass wraps custom toolbar items in a
/// dark glass capsule that `.toolbarBackground` can't suppress; the
/// back-swipe gesture still works with the bar hidden.
private struct UserProfileTopBar: View {
    let title: String
    let showActions: Bool
    let isBlocked: Bool
    let onBack: () -> Void
    let onUnblock: () -> Void
    let onMute: () -> Void
    let onBlock: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .imageScale(.large)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.primary)

            Text(title).fontWeight(.semibold)

            Spacer()

            if showActions {
                Menu {
                    if isBlocked {
                        Button("Unblock", action: onUnblock)
                    } else {
                        Button("Mute posts", role: .destructive, action: onMute)
                        Button("Block", role: .destructive, action: onBlock)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .imageScale(.large)
                }
                .foregroundStyle(.primary)
            }
        }
        .font(.title3)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}
