import SwiftUI

struct RootView: View {
    enum Tab: Hashable {
        case feed, search, create, reels, activity, profile
    }

    @State private var selection: Tab = .feed
    @State private var showCreate: Bool = false

    var body: some View {
        TabView(selection: tabBinding) {
            FeedView(
                currentUser: MockData.currentUser,
                stories: MockData.stories,
                posts: MockData.posts
            )
            .tabItem { Label("Home", systemImage: selection == .feed ? "house.fill" : "house") }
            .tag(Tab.feed)

            SearchView(posts: MockData.explorePosts, users: MockData.users)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)

            Color.clear
                .tabItem { Label("Create", systemImage: "plus.app") }
                .tag(Tab.create)

            ReelsView(reels: MockData.reels)
                .tabItem { Label("Reels", systemImage: "play.square") }
                .tag(Tab.reels)

            ActivityView(notifications: MockData.notifications)
                .tabItem {
                    Label("Activity", systemImage: selection == .activity ? "heart.fill" : "heart")
                }
                .tag(Tab.activity)

            ProfileView(user: MockData.currentUser, posts: MockData.myPosts)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(Tab.profile)
        }
        .sheet(isPresented: $showCreate) {
            CreatePostView()
        }
    }

    private var tabBinding: Binding<Tab> {
        Binding(
            get: { selection },
            set: { newValue in
                if newValue == .create {
                    showCreate = true
                } else {
                    selection = newValue
                }
            }
        )
    }
}

#Preview {
    RootView()
}
