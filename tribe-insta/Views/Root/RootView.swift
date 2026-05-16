import SwiftUI

/// Six-tab shell. Each tab fetches its own data through TribeService
/// instead of receiving pre-loaded MockData. Create stays a sheet —
/// the "+" tab intercepts selection and presents it modally.
struct RootView: View {
    enum Tab: Hashable {
        case feed, search, create, reels, activity, profile
    }

    @State private var selection: Tab = .feed
    @State private var showCreate: Bool = false

    var body: some View {
        TabView(selection: tabBinding) {
            FeedView()
                .tabItem { Label("Home", systemImage: selection == .feed ? "house.fill" : "house") }
                .tag(Tab.feed)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)

            Color.clear
                .tabItem { Label("Create", systemImage: "plus.app") }
                .tag(Tab.create)

            ReelsView()
                .tabItem { Label("Reels", systemImage: "play.square") }
                .tag(Tab.reels)

            ActivityView()
                .tabItem {
                    Label("Activity", systemImage: selection == .activity ? "heart.fill" : "heart")
                }
                .tag(Tab.activity)

            ProfileView()
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
        .environmentObject(AppState())
        .environmentObject(TribeService(state: AppState()))
}
