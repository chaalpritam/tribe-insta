import SwiftUI

/// Full-screen post view with the standard card chrome and comments.
struct PostDetailView: View {
    let post: Post

    @EnvironmentObject private var service: TribeService
    @State private var displayPost: Post
    @State private var isLoading = false

    init(post: Post) {
        self.post = post
        _displayPost = State(initialValue: post)
    }

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView().padding(.top, 40)
            } else {
                PostCardView(post: displayPost)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard let hash = post.hash else { return }
            isLoading = true
            if let fresh = try? await service.post(hash: hash) {
                displayPost = fresh
            }
            isLoading = false
        }
    }
}
