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
    @State private var viewerStories: [Story] = []
    @State private var showStoryViewer: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
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
                            Divider().opacity(0.4)
                        }
                    }
                }
            }
            .refreshable {
                await load()
            }
            .navigationTitle("Tribe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Tribe")
                        .font(.system(.title2, design: .serif).italic())
                        .fontWeight(.bold)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { } label: {
                        Image(systemName: "heart")
                    }
                    Button { } label: {
                        Image(systemName: "paperplane")
                    }
                }
            }
        }
        .task { await load() }
        .onChange(of: service.feedRevision) { _, _ in
            Task { await load() }
        }
        .fullScreenCover(isPresented: $showStoryViewer) {
            StoryViewer(stories: viewerStories)
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
    private func load() async {
        isLoading = true
        errorMessage = nil
        // Stories failure shouldn't sink the feed — the tray just stays
        // empty if /v1/stories errors. Posts are the load-bearing path.
        async let storiesTask: [Story] = (try? await service.stories()) ?? []
        do {
            let fetched = try await service.feed()
            posts = fetched
        } catch {
            errorMessage = error.localizedDescription
        }
        stories = await storiesTask
        isLoading = false
    }

    /// Open the StoryViewer for one author. nil/missing TID falls back
    /// to dismissing — there's nothing to render.
    @MainActor
    private func openStories(forAuthor authorTID: String?) async {
        guard let authorTID else { return }
        let authorStories: [Story]
        if authorTID == state.myTID {
            // For my own story tap, /v1/stories doesn't return my row
            // if it didn't make the global ranking, so always go straight
            // at /v1/stories/<my-tid> instead of filtering the cached list.
            authorStories = (try? await service.stories(forUserTID: authorTID)) ?? []
        } else {
            authorStories = stories.filter { $0.author.tid == authorTID }
        }
        guard !authorStories.isEmpty else { return }
        viewerStories = authorStories
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
