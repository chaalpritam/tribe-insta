import SwiftUI

/// Self profile screen. Fetches /v1/user/<myTID> + /v1/tweets/<myTID>
/// through TribeService and renders the IG-shaped header + photo grid.
struct ProfileView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var service: TribeService

    @State private var user: User?
    @State private var posts: [Post] = []
    @State private var reels: [Reel] = []
    @State private var taggedPosts: [Post] = []
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

                        Section {
                            tabContent
                                .frame(maxWidth: .infinity)
                        } header: {
                            tabSelector
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
        .task(id: state.myTID) {
            await load()
            await state.refreshBadgeCounts()
        }
        .onChange(of: service.feedRevision) { _, _ in
            Task { await load() }
        }
        .onChange(of: reels.isEmpty) { _, isEmpty in
            if isEmpty, selectedTab == .reels {
                selectedTab = .grid
            }
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
            if taggedPosts.isEmpty {
                taggedEmptyState
            } else {
                ProfilePostsGrid(posts: taggedPosts)
            }
        }
    }

    private var taggedEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.square")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No tagged posts")
                .font(.headline)
            Text("When people tag you in photos, they'll show up here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private var tabSelector: some View {
        ProfileTabSelector(selection: $selectedTab, showReels: !reels.isEmpty)
    }

    @MainActor
    private func load() async {
        guard let tid = state.myTID else {
            user = nil
            posts = []
            reels = []
            taggedPosts = []
            errorMessage = nil
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            async let profileResult = service.profile(tid: tid)
            let (u, p, r) = try await profileResult
            user = u
            state.myAvatarURL = u.avatarURL
            if state.myUsername == nil || state.myUsername?.isEmpty == true {
                state.myUsername = u.username
            }
            posts = p
            reels = r
            taggedPosts = (try? await service.taggedPosts(tid: tid)) ?? []
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

    var body: some View {
        if posts.isEmpty {
            profileGridEmptyState(
                systemImage: "camera",
                title: "No posts yet",
                subtitle: "Share a photo from the + tab."
            )
        } else {
            ProfileMediaGrid {
                ForEach(posts) { post in
                    NavigationLink(value: post) {
                        ProfilePhotoCell(url: post.imageURLs.first)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ProfileReelsGrid: View {
    let reels: [Reel]

    var body: some View {
        ProfileMediaGrid {
            ForEach(reels) { reel in
                ProfileGridCell {
                    ZStack {
                        RemoteImage(url: reel.thumbnailURL ?? reel.videoURL, contentMode: .fill)
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

/// Pinned tab bar under the profile header. Reels tab appears only when the user has reels.
struct ProfileTabSelector: View {
    @Binding var selection: ProfileView.ProfileTab
    let showReels: Bool

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.grid, systemImage: "square.grid.3x3")
            if showReels {
                tabButton(.reels, systemImage: "play.rectangle.on.rectangle")
            }
            tabButton(.tagged, systemImage: "person.crop.square")
        }
        .background(.bar)
    }

    private func tabButton(_ tab: ProfileView.ProfileTab, systemImage: String) -> some View {
        Button { selection = tab } label: {
            VStack(spacing: 0) {
                Image(systemName: systemImage)
                    .font(.body)
                    .symbolVariant(selection == tab ? .fill : .none)
                    .foregroundStyle(selection == tab ? .primary : .secondary)
                    .frame(height: 24)
                Rectangle()
                    .fill(selection == tab ? Color.primary : Color.clear)
                    .frame(height: 1)
            }
            .padding(.top, 10)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: tab))
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }

    private func accessibilityLabel(for tab: ProfileView.ProfileTab) -> String {
        switch tab {
        case .grid: return "Posts"
        case .reels: return "Reels"
        case .tagged: return "Tagged"
        }
    }
}

// MARK: - Shared profile grid layout (IG 3-column square grid, 1pt gutters)

private enum ProfileGridMetrics {
    static let spacing: CGFloat = 1
    static let columns = Array(
        repeating: GridItem(.flexible(), spacing: spacing),
        count: 3
    )
}

private struct ProfileMediaGrid<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        LazyVGrid(columns: ProfileGridMetrics.columns, spacing: ProfileGridMetrics.spacing) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Square IG profile cell with the photo cropped to fill.
private struct ProfilePhotoCell: View {
    let url: URL?

    var body: some View {
        ProfileGridCell {
            RemoteImage(url: url, contentMode: .fill)
        }
    }
}

/// Fixed 1:1 frame so every column lines up across posts and reels tabs.
private struct ProfileGridCell<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width
            content()
                .frame(width: side, height: side)
                .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
    }
}

private func profileGridEmptyState(
    systemImage: String,
    title: String,
    subtitle: String?
) -> some View {
    VStack(spacing: 8) {
        Image(systemName: systemImage)
            .font(.title2)
            .foregroundStyle(.secondary)
        Text(title)
            .font(.headline)
        if let subtitle {
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    .padding(.vertical, 40)
    .frame(maxWidth: .infinity)
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
        .environmentObject(TribeService(state: AppState()))
}
