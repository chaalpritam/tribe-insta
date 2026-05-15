import SwiftUI

/// Photo-only home feed. Pulls `/v1/feed` through TribeService and
/// renders any tweet whose `embeds` carry image hashes. Stories are
/// hidden in Phase 1 — the protocol doesn't have a stories envelope
/// yet (see PLAN.md Phase 3); the bar comes back when STORY_ADD ships.
struct FeedView: View {
    @EnvironmentObject private var service: TribeService

    @State private var posts: [Post] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
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
        do {
            let fetched = try await service.feed()
            posts = fetched
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    FeedView()
        .environmentObject(AppState())
        .environmentObject(TribeService(state: AppState()))
}
