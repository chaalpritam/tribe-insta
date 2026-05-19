import SwiftUI

/// Self profile screen. Fetches /v1/user/<myTID> + /v1/tweets/<myTID>
/// through TribeService and renders the IG-shaped header + photo grid.
struct ProfileView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var service: TribeService

    @State private var user: User?
    @State private var posts: [Post] = []
    @State private var reels: [Reel] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var selectedTab: ProfileTab = .grid
    @State private var followListMode: FollowListView.Mode?
    @State private var showSettings: Bool = false
    @State private var showEditProfile: Bool = false
    enum ProfileTab: Hashable {
        case grid, reels, tagged
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProfileTopBar(
                    title: state.myUsername ?? "Profile",
                    onMenu: { showSettings = true }
                )
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        if let user {
                            ProfileHeader(
                                user: user,
                                showEditProfile: $showEditProfile,
                                onFollowers: { followListMode = .followers },
                                onFollowing: { followListMode = .following }
                            )
                        } else if isLoading {
                            ProgressView().padding(40)
                        } else if let errorMessage {
                            VStack(spacing: 8) {
                                Text("Couldn't load profile")
                                    .font(.headline)
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                                Button("Retry") { Task { await load() } }
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(40)
                        }

                        Section(header: tabSelector) {
                            tabContent
                        }
                    }
                }
                .refreshable { await load() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Post.self) { post in
                PostDetailView(post: post)
            }
            .navigationDestination(item: $followListMode) { mode in
                if let tid = state.myTID {
                    FollowListView(tid: tid, mode: mode)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
        }
        .task {
            await load()
            await state.refreshBadgeCounts()
        }
        .onChange(of: service.feedRevision) { _, _ in
            Task { await load() }
        }
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

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(.grid, system: "square.grid.3x3")
            tabButton(.reels, system: "play.square")
            tabButton(.tagged, system: "person.crop.square")
        }
        .background(.bar)
    }

    private func tabButton(_ tab: ProfileTab, system: String) -> some View {
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

    @MainActor
    private func load() async {
        guard let tid = state.myTID else { return }
        isLoading = true
        errorMessage = nil
        do {
            let (u, p, r) = try await service.profile(tid: tid)
            user = u
            state.myAvatarURL = u.avatarURL
            posts = p
            reels = r
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

/// Custom IG-style top bar. The system nav bar is hidden because iOS 26's
/// Liquid Glass renders custom toolbar items (the username + chevron HStack)
/// inside a dark glass capsule no matter what `.toolbarBackground` is set
/// to. Rendering the bar ourselves bypasses that.
private struct ProfileTopBar: View {
    let title: String
    let onMenu: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Text(title).fontWeight(.semibold)
                Image(systemName: "chevron.down").font(.caption2)
            }
            Spacer()
            Button(action: onMenu) {
                Image(systemName: "line.3.horizontal")
                    .imageScale(.large)
            }
            .foregroundStyle(.primary)
        }
        .font(.title3)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}

private struct ProfileHeader: View {
    let user: User
    @Binding var showEditProfile: Bool
    var onFollowers: () -> Void = {}
    var onFollowing: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 24) {
                StoryAvatarView(url: user.avatarURL, size: 86)
                statsRow
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.displayName).fontWeight(.semibold)
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption).foregroundStyle(.blue)
                    }
                }
                if !user.bio.isEmpty {
                    Text(user.bio)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }

            HStack(spacing: 8) {
                Button {
                    showEditProfile = true
                } label: {
                    Text("Edit profile")
                        .font(.subheadline).fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                if let tid = user.tid {
                    ShareLink(
                        item: "Tribe profile @\(user.username) (TID \(tid))",
                        subject: Text(user.displayName)
                    ) {
                        Text("Share profile")
                            .font(.subheadline).fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statsRow: some View {
        HStack(spacing: 20) {
            stat(value: user.postsCount, label: "Posts")
            Button(action: onFollowers) {
                stat(value: user.followersCount, label: "Followers")
            }
            .buttonStyle(.plain)
            Button(action: onFollowing) {
                stat(value: user.followingCount, label: "Following")
            }
            .buttonStyle(.plain)
        }
    }

    private func stat(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(Formatters.compactCount(value)).fontWeight(.semibold)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

}

struct ProfilePostsGrid: View {
    let posts: [Post]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        if posts.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "camera").font(.title2).foregroundStyle(.secondary)
                Text("No posts yet")
                    .font(.headline)
                Text("Share a photo from the + tab.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        } else {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(posts) { post in
                    NavigationLink(value: post) {
                        RemoteImage(url: post.imageURLs.first)
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ProfileReelsGrid: View {
    let reels: [Reel]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        if reels.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "play.square")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No reels yet")
                    .font(.headline)
            }
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
        } else {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(reels) { reel in
                    ZStack {
                        RemoteImage(url: reel.thumbnailURL ?? reel.videoURL)
                            .aspectRatio(9 / 16, contentMode: .fill)
                            .clipped()
                        Image(systemName: "play.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
        .environmentObject(TribeService(state: AppState()))
}
