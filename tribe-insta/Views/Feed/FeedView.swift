import SwiftUI

/// Photo-only home feed. Pulls `/v1/feed` through TribeService and
/// renders any tweet whose `embeds` carry image hashes. Stories are
/// hidden in Phase 1 — the protocol doesn't have a stories envelope
/// yet (see PLAN.md Phase 3); the bar comes back when STORY_ADD ships.
struct FeedView: View {
    @EnvironmentObject private var service: TribeService
    @EnvironmentObject private var state: AppState

    @State private var posts: [Post] = []
    @State private var stories: [Story] = []
    @State private var viewerAuthors: [[Story]] = []
    @State private var viewerInitialIndex: Int = 0
    @State private var showStoryViewer: Bool = false
    @State private var isLoading: Bool = false
    @State private var isLoadingMore = false
    @State private var feedCursor: String?
    @State private var errorMessage: String?
    @State private var profilePath = NavigationPath()

    var body: some View {
        NavigationStack(path: $profilePath) {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    if let me = state.myTID.map(currentUserViewModel) {
                        StoriesBar(
                            currentUser: me,
                            stories: stories,
                            onStoryTap: { story in
                                Task { await openStories(forAuthor: story.author.tid) }
                            },
                            onYourStoryTap: {
                                Task { await openStories(forAuthor: state.myTID) }
                            }
                        )
                        Divider().opacity(0.4)
                    }
                    if posts.isEmpty {
                        emptyState
                    } else {
                        ForEach(posts) { post in
                            PostCardView(post: post)
                                .onAppear {
                                    if post.id == posts.last?.id {
                                        Task { await loadMore() }
                                    }
                                }
                            Divider().opacity(0.4)
                        }
                        if isLoadingMore {
                            ProgressView()
                                .padding(.vertical, 16)
                        }
                    }
                }
            }
            .refreshable {
                await load(refresh: true)
            }
            .navigationDestination(for: String.self) { tid in
                UserProfileView(tid: tid)
            }
            .navigationTitle("Tribe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Tribe")
                        .font(.system(.title2, design: .serif).italic())
                        .fontWeight(.bold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ActivityView()
                    } label: {
                        Image(systemName: "heart")
                    }
                }
            }
        }
        .task { await load() }
        .onChange(of: service.feedRevision) { _, _ in
            Task { await load() }
        }
        .fullScreenCover(isPresented: $showStoryViewer) {
            StoryViewer(
                authors: viewerAuthors,
                initialAuthorIndex: viewerInitialIndex
            )
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 14) {
            if isLoading {
                ProgressView()
                    .padding(.top, 60)
            } else if let errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2).foregroundStyle(.secondary)
                    Text("Couldn't load feed")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Button("Retry") { Task { await load() } }
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 4)
                }
                .padding(.top, 80)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.stack")
                        .font(.title2).foregroundStyle(.secondary)
                    Text("No photo posts yet")
                        .font(.headline)
                    Text("Posts with images from your hub will show up here. Create one from the + tab.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 80)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @MainActor
    private func load(refresh: Bool = false) async {
        if refresh {
            feedCursor = nil
        }
        isLoading = posts.isEmpty
        errorMessage = nil
        async let storiesTask: [Story] = (try? await service.stories()) ?? []
        do {
            let page = try await service.feedPage(cursor: nil)
            posts = page.posts
            feedCursor = page.nextCursor
        } catch {
            errorMessage = error.localizedDescription
            if refresh { posts = [] }
        }
        stories = await storiesTask
        isLoading = false
    }

    @MainActor
    private func loadMore() async {
        guard let cursor = feedCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await service.feedPage(cursor: cursor)
            posts.append(contentsOf: page.posts)
            feedCursor = page.nextCursor
        } catch {
            feedCursor = nil
        }
    }

    /// Open the StoryViewer at the given author, with every author's
    /// stories pre-grouped so horizontal swipes can move between them.
    @MainActor
    private func openStories(forAuthor authorTID: String?) async {
        guard let authorTID else { return }

        // Group the cached stories list by author, preserving the
        // hub's "newest active per author" ordering. The cache is
        // chronological-newest-first per author; reverse within each
        // bucket so the viewer walks them oldest-first.
        var bucketsByAuthor: [String: [Story]] = [:]
        var orderedAuthorTids: [String] = []
        for story in stories {
            guard let tid = story.author.tid else { continue }
            if bucketsByAuthor[tid] == nil {
                bucketsByAuthor[tid] = []
                orderedAuthorTids.append(tid)
            }
            bucketsByAuthor[tid]?.append(story)
        }
        for tid in bucketsByAuthor.keys {
            bucketsByAuthor[tid]?.reverse()
        }

        // If the user tapped their own story but /v1/stories didn't
        // include it (e.g. limit truncation), fetch directly.
        if authorTID == state.myTID && bucketsByAuthor[authorTID] == nil {
            let mine = (try? await service.stories(forUserTID: authorTID)) ?? []
            if mine.isEmpty { return }
            bucketsByAuthor[authorTID] = mine
            orderedAuthorTids.insert(authorTID, at: 0)
        }

        guard let initial = orderedAuthorTids.firstIndex(of: authorTID) else { return }
        viewerAuthors = orderedAuthorTids.compactMap { bucketsByAuthor[$0] }
        viewerInitialIndex = initial
        showStoryViewer = true
    }

    /// Build a minimal "you" view-model from AppState so the StoriesBar
    /// renders the "Your story" item without a hub round-trip.
    private func currentUserViewModel(tid: String) -> User {
        User(
            tid: tid,
            username: state.myUsername ?? "you",
            displayName: state.myUsername ?? "You"
        )
    }
}

#Preview {
    FeedView()
        .environmentObject(AppState())
        .environmentObject(TribeService(state: AppState()))
}
