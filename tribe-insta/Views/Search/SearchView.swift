import SwiftUI

/// Explore + user search.
///
/// Explore grid surfaces the photo-only feed (the same TribeService
/// query as Home, just rendered as a grid). The protocol doesn't have
/// a separate explore-ranking endpoint yet — for Phase 1 that's fine,
/// the feed is the only public surface anyway.
///
/// Typing a query switches to the user-search results list backed by
/// `/v1/search/users`.
struct SearchView: View {
    @EnvironmentObject private var service: TribeService

    @State private var query: String = ""
    @State private var posts: [Post] = []
    @State private var users: [User] = []
    @State private var isLoadingExplore: Bool = false
    @State private var isSearching: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    ExploreGrid(posts: posts, isLoading: isLoadingExplore)
                } else {
                    UserResultsList(users: users, isLoading: isSearching)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search")
            .onChange(of: query) { _, newValue in
                Task { await runSearch(newValue) }
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
            return
        }
        isSearching = true
        do {
            users = try await service.searchUsers(trimmed)
        } catch {
            users = []
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
    let isLoading: Bool

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
}

#Preview {
    SearchView()
        .environmentObject(AppState())
        .environmentObject(TribeService(state: AppState()))
}
