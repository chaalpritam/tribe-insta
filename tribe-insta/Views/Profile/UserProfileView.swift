import SwiftUI

/// Another user's profile — grid of their photo posts + follow CTA.
struct UserProfileView: View {
    let tid: String

    @EnvironmentObject private var service: TribeService
    @EnvironmentObject private var state: AppState

    @State private var user: User?
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                if let user {
                    header(user: user)
                } else if isLoading {
                    ProgressView().padding(40)
                } else if let errorMessage {
                    errorBlock(errorMessage)
                }
                ProfilePostsGrid(posts: posts)
            }
        }
        .refreshable { await load() }
        .navigationTitle(user?.username ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: tid) { await load() }
    }

    private func header(user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 24) {
                AvatarView(url: user.avatarURL, size: 86)
                HStack(spacing: 20) {
                    stat(value: user.postsCount, label: "Posts")
                    stat(value: user.followersCount, label: "Followers")
                    stat(value: user.followingCount, label: "Following")
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName).fontWeight(.semibold)
                if !user.bio.isEmpty {
                    Text(user.bio).font(.subheadline)
                }
            }
            if tid != state.myTID {
                FollowButton(targetTID: tid)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func stat(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(Formatters.compactCount(value)).fontWeight(.semibold)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func errorBlock(_ message: String) -> some View {
        VStack(spacing: 8) {
            Text("Couldn't load profile").font(.headline)
            Text(message).font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await load() } }
        }
        .padding(40)
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await service.profile(tid: tid)
            user = result.user
            posts = result.posts
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
