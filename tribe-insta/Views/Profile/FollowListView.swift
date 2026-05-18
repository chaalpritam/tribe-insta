import SwiftUI

/// Followers or following list for a profile. Backed by
/// `/v1/followers/:tid` and `/v1/following/:tid`.
struct FollowListView: View {
    enum Mode: String, Hashable {
        case followers, following
    }

    let tid: String
    let mode: Mode

    @EnvironmentObject private var service: TribeService
    @EnvironmentObject private var state: AppState

    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var title: String {
        mode == .followers ? "Followers" : "Following"
    }

    var body: some View {
        Group {
            if isLoading && users.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, users.isEmpty {
                VStack(spacing: 10) {
                    Text("Couldn't load \(title.lowercased())")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { Task { await load() } }
                }
                .padding(24)
            } else if users.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: mode == .followers ? "person.2" : "person.2.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(mode == .followers ? "No followers yet" : "Not following anyone yet")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(users) { user in
                    if let userTID = user.tid {
                        NavigationLink(value: userTID) {
                            FollowListRow(user: user)
                        }
                        .listRowSeparator(.hidden)
                    } else {
                        FollowListRow(user: user)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: String.self) { profileTID in
            UserProfileView(tid: profileTID)
        }
        .refreshable { await load() }
        .task(id: "\(tid)-\(mode)") { await load() }
    }

    @MainActor
    private func load() async {
        isLoading = users.isEmpty
        errorMessage = nil
        do {
            switch mode {
            case .followers:
                users = try await service.followers(of: tid)
            case .following:
                users = try await service.following(of: tid)
            }
            users = await service.enrichFollowing(users: users)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct FollowListRow: View {
    let user: User
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: user.avatarURL, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !user.bio.isEmpty {
                    Text(user.bio)
                        .font(.caption)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if let tid = user.tid, tid != state.myTID {
                FollowButton(targetTID: tid)
            }
        }
        .padding(.vertical, 4)
    }
}
