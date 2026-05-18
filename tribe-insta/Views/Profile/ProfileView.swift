import SwiftUI

/// Self profile screen. Fetches /v1/user/<myTID> + /v1/tweets/<myTID>
/// through TribeService and renders the IG-shaped header + photo grid.
struct ProfileView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var service: TribeService

    @State private var user: User?
    @State private var posts: [Post] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var selectedTab: ProfileTab = .grid
    @State private var showSettings: Bool = false
    @State private var showInbox: Bool = false
    @State private var showEditProfile: Bool = false

    enum ProfileTab: Hashable {
        case grid, reels, tagged
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if let user {
                        ProfileHeader(user: user, showEditProfile: $showEditProfile)
                    } else if isLoading {
                        ProgressView().padding(40)
                    } else if let errorMessage {
                        VStack(spacing: 8) {
                            Text("Couldn't load profile")
                                .font(.headline)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            Button("Retry") { Task { await load() } }
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(40)
                    }

                    Section(header: tabSelector) {
                        ProfilePostsGrid(posts: posts)
                    }
                }
            }
            .refreshable { await load() }
            .navigationTitle(state.myUsername ?? "Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 4) {
                        Text(state.myUsername ?? "Profile").fontWeight(.semibold)
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showInbox = true } label: { Image(systemName: "paperplane") }
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showInbox) {
            InboxView()
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
        }
        .task { await load() }
        .onChange(of: service.feedRevision) { _, _ in
            Task { await load() }
        }
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(.grid, system: "square.grid.3x3")
            tabButton(.reels, system: "play.square")
            tabButton(.tagged, system: "person.crop.square")
        }
        .background(.bar)
    }

    private func tabButton(_ tab: ProfileTab, system: String) -> some View {
        Button { selectedTab = tab } label: {
            VStack(spacing: 6) {
                Image(systemName: system)
                    .font(.title3)
                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                Rectangle()
                    .fill(selectedTab == tab ? Color.primary : Color.clear)
                    .frame(height: 1)
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func load() async {
        guard let tid = state.myTID else { return }
        isLoading = true
        errorMessage = nil
        do {
            let (u, p) = try await service.profile(tid: tid)
            user = u
            posts = p
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct ProfileHeader: View {
    let user: User
    @Binding var showEditProfile: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 24) {
                StoryAvatarView(url: user.avatarURL, size: 86)
                statsRow
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.displayName).fontWeight(.semibold)
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption).foregroundStyle(.blue)
                    }
                }
                if !user.bio.isEmpty {
                    Text(user.bio)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }

            HStack(spacing: 8) {
                Button {
                    showEditProfile = true
                } label: {
                    Text("Edit profile")
                        .font(.subheadline).fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                if let tid = user.tid {
                    ShareLink(
                        item: "Tribe profile @\(user.username) (TID \(tid))",
                        subject: Text(user.displayName)
                    ) {
                        Text("Share profile")
                            .font(.subheadline).fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statsRow: some View {
        HStack(spacing: 20) {
            stat(value: user.postsCount, label: "Posts")
            stat(value: user.followersCount, label: "Followers")
            stat(value: user.followingCount, label: "Following")
        }
    }

    private func stat(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(Formatters.compactCount(value)).fontWeight(.semibold)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

}

struct ProfilePostsGrid: View {
    let posts: [Post]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        if posts.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "camera").font(.title2).foregroundStyle(.secondary)
                Text("No posts yet")
                    .font(.headline)
                Text("Share a photo from the + tab.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        } else {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(posts) { post in
                    RemoteImage(url: post.imageURLs.first)
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
        .environmentObject(TribeService(state: AppState()))
}
