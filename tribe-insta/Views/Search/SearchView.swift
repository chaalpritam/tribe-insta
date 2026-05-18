import SwiftUI

/// Explore + user/post search.
struct SearchView: View {
    @EnvironmentObject private var service: TribeService

    @State private var query: String = ""
    @State private var posts: [Post] = []
    @State private var users: [User] = []
    @State private var isLoadingExplore: Bool = false
    @State private var isSearching: Bool = false
    @State private var searchPosts: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    ExploreGrid(posts: posts, isLoading: isLoadingExplore)
                } else if searchPosts {
                    PostResultsList(posts: posts, isLoading: isSearching)
                } else {
                    UserResultsList(users: users, isLoading: isSearching)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search users or #hashtags"
            )
            .onChange(of: query) { _, newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                searchPosts = trimmed.hasPrefix("#") || trimmed.contains(" ")
                Task { await runSearch(newValue) }
            }
            .navigationDestination(for: String.self) { tid in
                UserProfileView(tid: tid)
            }
            .navigationDestination(for: Post.self) { post in
                PostDetailView(post: post)
            }
        }
        .task { await loadExplore() }
        .onChange(of: service.feedRevision) { _, _ in
            Task { await loadExplore() }
        }
    }

    @MainActor
    private func loadExplore() async {
        isLoadingExplore = true
        do {
            posts = try await service.feed(limit: 30)
        } catch {
            posts = []
        }
        isLoadingExplore = false
    }

    @MainActor
    private func runSearch(_ q: String) async {
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            users = []
            posts = []
            return
        }
        isSearching = true
        if searchPosts {
            do {
                posts = try await service.searchPosts(trimmed)
            } catch {
                posts = []
            }
            users = []
        } else {
            do {
                users = try await service.searchUsers(trimmed)
            } catch {
                users = []
            }
        }
        isSearching = false
    }
}

private struct ExploreGrid: View {
    let posts: [Post]
    let isLoading: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ScrollView {
            if posts.isEmpty {
                VStack(spacing: 8) {
                    if isLoading {
                        ProgressView().padding(.top, 60)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.title2).foregroundStyle(.secondary)
                            .padding(.top, 80)
                        Text("Nothing to explore yet")
                            .font(.headline)
                        Text("Photo posts from your hub show up here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(Array(posts.enumerated()), id: \.element.id) { idx, post in
                        cell(for: post, index: idx)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(for post: Post, index: Int) -> some View {
        let isTall = index % 7 == 3
        NavigationLink(value: post) {
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
        }
        .buttonStyle(.plain)
        .gridCellColumns(isTall ? 1 : 1)
        .gridCellUnsizedAxes(.vertical)
    }
}

private struct PostResultsList: View {
    let posts: [Post]
    let isLoading: Bool

    var body: some View {
        if posts.isEmpty {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView().padding(.top, 60)
                } else {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title2).foregroundStyle(.secondary)
                        .padding(.top, 80)
                    Text("No posts found").font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
        } else {
            List(posts) { post in
                NavigationLink(value: post) {
                    HStack(spacing: 12) {
                        RemoteImage(url: post.imageURLs.first)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(post.author.username).fontWeight(.semibold)
                            Text(post.caption)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
        }
    }
}

private struct UserResultsList: View {
    let users: [User]
    let isLoading: Bool

    private func userRow(_ user: User) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: user.avatarURL, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.username).fontWeight(.semibold)
                    if user.isFollowing {
                        Text("Following")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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
        .padding(.vertical, 4)
    }

    var body: some View {
        if users.isEmpty {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView().padding(.top, 60)
                } else {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.title2).foregroundStyle(.secondary)
                        .padding(.top, 80)
                    Text("No users found").font(.headline)
                    Text("Try a different username or display name.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        } else {
            List(users) { user in
                if let tid = user.tid {
                    NavigationLink(value: tid) {
                        userRow(user)
                    }
                    .listRowSeparator(.hidden)
                } else {
                    userRow(user)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
        }
    }
}

#Preview {
    SearchView()
        .environmentObject(AppState())
        .environmentObject(TribeService(state: AppState()))
}
