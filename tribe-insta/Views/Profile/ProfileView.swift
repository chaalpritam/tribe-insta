import SwiftUI

struct ProfileView: View {
    let user: User
    let posts: [Post]

    @State private var selectedTab: ProfileTab = .grid

    enum ProfileTab: Hashable {
        case grid, reels, tagged
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ProfileHeader(user: user)
                    HighlightsRow()
                    Section(header: tabSelector) {
                        ProfilePostsGrid(posts: posts)
                    }
                }
            }
            .navigationTitle(user.username)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 4) {
                        Text(user.username).fontWeight(.semibold)
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { } label: { Image(systemName: "plus.app") }
                    Button { } label: { Image(systemName: "line.3.horizontal") }
                }
            }
        }
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
}

private struct ProfileHeader: View {
    let user: User

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
                Text(user.bio)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 8) {
                actionButton(title: "Edit profile")
                actionButton(title: "Share profile")
                Button { } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.subheadline)
                        .frame(width: 32, height: 32)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statsRow: some View {
        HStack(spacing: 20) {
            stat(value: user.postsCount, label: "Posts")
            stat(value: user.followersCount, label: "Followers")
            stat(value: user.followingCount, label: "Following")
        }
    }

    private func stat(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(Formatters.compactCount(value)).fontWeight(.semibold)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func actionButton(title: String) -> some View {
        Button { } label: {
            Text(title)
                .font(.subheadline).fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}

private struct HighlightsRow: View {
    private let titles = ["New", "Travel", "Code", "Food", "2026"]
    private let seeds = ["h1", "h2", "h3", "h4", "h5"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(Array(titles.enumerated()), id: \.offset) { idx, title in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .strokeBorder(Color(.separator).opacity(0.6), lineWidth: 1)
                                .frame(width: 64, height: 64)
                            RemoteImage(url: MockData.picsum(seeds[idx], 200))
                                .frame(width: 58, height: 58)
                                .clipShape(Circle())
                        }
                        Text(title).font(.caption2)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

private struct ProfilePostsGrid: View {
    let posts: [Post]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(posts) { post in
                RemoteImage(url: post.imageURLs.first)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
            }
        }
    }
}

#Preview {
    ProfileView(user: MockData.currentUser, posts: MockData.myPosts)
}
