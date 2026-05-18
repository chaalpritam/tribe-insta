import SwiftUI

/// Grid of bookmarked photo posts (`/v1/bookmarks/:tid` join).
struct SavedPostsView: View {
    @EnvironmentObject private var service: TribeService
    @EnvironmentObject private var state: AppState

    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if state.myTID == nil {
                signInPrompt
            } else if isLoading && posts.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, posts.isEmpty {
                errorBlock(errorMessage)
            } else if posts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bookmark")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No saved posts")
                        .font(.headline)
                    Text("Tap the bookmark icon on a post to save it here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    ProfilePostsGrid(posts: posts)
                }
            }
        }
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Post.self) { post in
            PostDetailView(post: post)
        }
        .refreshable { await load() }
        .task { await load() }
        .onChange(of: service.feedRevision) { _, _ in
            Task { await load() }
        }
    }

    private var signInPrompt: some View {
        VStack(spacing: 8) {
            Text("Sign in required")
                .font(.headline)
            Text("Connect your identity to see saved posts.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorBlock(_ message: String) -> some View {
        VStack(spacing: 8) {
            Text("Couldn't load saved posts").font(.headline)
            Text(message).font(.caption).foregroundStyle(.secondary)
            Button("Retry") { Task { await load() } }
        }
        .padding(40)
    }

    @MainActor
    private func load() async {
        guard state.myTID != nil else { return }
        isLoading = posts.isEmpty
        errorMessage = nil
        do {
            posts = try await service.savedPosts()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
