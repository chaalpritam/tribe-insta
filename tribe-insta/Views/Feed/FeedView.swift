import SwiftUI

struct FeedView: View {
    let currentUser: User
    let stories: [Story]
    let posts: [Post]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    StoriesBar(currentUser: currentUser, stories: stories)
                    Divider().opacity(0.4)
                    ForEach(posts) { post in
                        PostCardView(post: post)
                        Divider().opacity(0.4)
                    }
                }
            }
            .refreshable {
                try? await Task.sleep(nanoseconds: 800_000_000)
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
    }
}

#Preview {
    FeedView(
        currentUser: MockData.currentUser,
        stories: MockData.stories,
        posts: MockData.posts
    )
}
