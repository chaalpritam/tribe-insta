import SwiftUI

/// Home tab: feed is the default page; swipe left to reveal the camera composer.
struct HomeShellView: View {
    /// 0 = camera, 1 = feed
    @State private var page = 1

    var body: some View {
        TabView(selection: $page) {
            CameraComposerView {
                withAnimation(.easeInOut(duration: 0.25)) { page = 1 }
            }
            .tag(0)

            FeedView()
                .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color(.systemBackground))
    }
}
