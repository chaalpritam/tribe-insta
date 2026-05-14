import SwiftUI

struct SearchView: View {
    let posts: [Post]
    let users: [User]

    @State private var query: String = ""

    private var filteredUsers: [User] {
        guard !query.isEmpty else { return [] }
        let q = query.lowercased()
        return users.filter {
            $0.username.lowercased().contains(q) || $0.displayName.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    ExploreGrid(posts: posts)
                } else {
                    UserResultsList(users: filteredUsers)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search")
        }
    }
}

private struct ExploreGrid: View {
    let posts: [Post]

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(posts.enumerated()), id: \.element.id) { idx, post in
                    cell(for: post, index: idx)
                }
            }
            .padding(.horizontal, 0)
        }
    }

    @ViewBuilder
    private func cell(for post: Post, index: Int) -> some View {
        let isTall = index % 7 == 3
        ZStack(alignment: .topTrailing) {
            RemoteImage(url: post.imageURLs.first)
                .frame(maxWidth: .infinity)
                .aspectRatio(isTall ? 0.5 : 1, contentMode: .fill)
                .clipped()
            if isTall {
                Image(systemName: "play.rectangle.fill")
                    .font(.callout)
                    .foregroundStyle(.white)
                    .shadow(radius: 1)
                    .padding(6)
            } else if post.imageURLs.count > 1 {
                Image(systemName: "square.on.square")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .shadow(radius: 1)
                    .padding(6)
            }
        }
        .gridCellColumns(isTall ? 1 : 1)
        .gridCellUnsizedAxes(.vertical)
    }
}

private struct UserResultsList: View {
    let users: [User]

    var body: some View {
        List(users) { user in
            HStack(spacing: 12) {
                AvatarView(url: user.avatarURL, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(user.username).fontWeight(.semibold)
                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2).foregroundStyle(.blue)
                        }
                    }
                    Text(user.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .listRowSeparator(.hidden)
            .padding(.vertical, 4)
        }
        .listStyle(.plain)
    }
}

#Preview {
    SearchView(posts: MockData.explorePosts, users: MockData.users)
}
