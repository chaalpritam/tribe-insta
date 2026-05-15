import Foundation
import SwiftUI

/// Bridges protocol-shaped types (`Tweet`, `HubUser`, `TribeNotification`)
/// from `Sources/` to the IG-shaped view models (`Post`, `User`,
/// `AppNotification`) the views in `tribe-insta/Views/` consume.
///
/// Keeps the views pure UI — they don't import `HubClient`, don't know
/// about envelopes or hashes. Phase 2 writes can land here too
/// (`like(post:)`, `bookmark(post:)`, `publishPost(...)`) so the views
/// continue to deal in view models only.
@MainActor
final class TribeService: ObservableObject {
    private let state: AppState

    init(state: AppState) {
        self.state = state
    }

    private var api: HubClient { state.api }

    // MARK: - Feed

    /// Photo-only home feed. `/v1/feed` returns every tweet kind; we
    /// drop the ones without image embeds since they're not IG-shaped
    /// content. The hub doesn't yet expose a `post_kind` discriminator
    /// (see PLAN.md Phase 3) — once it does, this becomes a server-side
    /// filter and we stop downloading text-only rows.
    func feed(limit: Int = 30) async throws -> [Post] {
        let page = try await api.fetchFeedPage(limit: limit)
        return page.tweets.compactMap(mapToPost)
    }

    // MARK: - Profile

    /// Returns the view-model `User` for the profile header plus the
    /// user's photo-only posts for the grid. Hub doesn't expose a
    /// `posts_count` field on /v1/user — for now we count what we
    /// fetched. Phase 3's `post_kind` migration would let the hub
    /// surface the photo count directly.
    func profile(tid: String) async throws -> (user: User, posts: [Post]) {
        async let hubUser = api.fetchUser(tid)
        async let tweets = api.fetchTweets(tid: tid)
        let posts = (try await tweets).compactMap(mapToPost)
        var u = mapToUser(try await hubUser)
        u.postsCount = posts.count
        return (u, posts)
    }

    // MARK: - Search

    func searchUsers(_ query: String) async throws -> [User] {
        let hubUsers = try await api.searchUsers(query)
        return hubUsers.map(mapToUser)
    }

    // MARK: - Notifications

    func notifications(tid: String, limit: Int = 50) async throws -> [AppNotification] {
        let raw = try await api.fetchNotifications(tid, limit: limit)
        return raw.compactMap(mapToNotification)
    }

    // MARK: - Mapping

    /// Tweet → Post. Returns nil for tweets without image embeds —
    /// those aren't IG-shaped content and don't belong in the feed
    /// or the profile grid.
    private func mapToPost(_ tweet: Tweet) -> Post? {
        let images = (tweet.embeds ?? []).compactMap(api.resolveMediaURL)
        guard !images.isEmpty else { return nil }
        let author = User(
            tid: tweet.tid,
            username: tweet.username ?? "tid\(tweet.tid)",
            displayName: tweet.username ?? "TID #\(tweet.tid)",
            avatarURL: nil
        )
        return Post(
            hash: tweet.hash,
            author: author,
            imageURLs: images,
            caption: tweet.text ?? "",
            // /v1/feed rows don't carry reaction aggregates today.
            // Phase 2's interaction cache will fold counts in from the
            // per-tweet endpoint when a card is on-screen.
            likesCount: 0,
            commentsCount: tweet.replyCount ?? 0,
            createdAt: tweet.timestamp
        )
    }

    /// HubUser → view-model User. The IG-shaped UI carries fields the
    /// protocol doesn't surface yet (`isVerified`, `isFollowing`,
    /// `postsCount`) — defaulted here, populated by surfaces that have
    /// the necessary data (e.g. `profile(tid:)` fills `postsCount`).
    private func mapToUser(_ u: HubUser) -> User {
        User(
            tid: u.tid,
            username: u.username ?? "tid\(u.tid)",
            displayName: u.displayName,
            avatarURL: u.profile?.pfpUrl.flatMap { api.resolveMediaURL($0) },
            bio: u.profile?.bio ?? "",
            postsCount: 0,
            followersCount: u.followersCount,
            followingCount: u.followingCount,
            isVerified: false,
            isFollowing: false
        )
    }

    /// TribeNotification → AppNotification. Drops kinds the IG-shaped
    /// activity surface doesn't render yet (tips, poll votes, RSVPs,
    /// task claims, crowdfund pledges). Phase 3+ can either add new
    /// `NotificationKind` cases or carry these through as-is.
    private func mapToNotification(_ n: TribeNotification) -> AppNotification? {
        let actor = User(
            tid: n.actorTid,
            username: n.actorUsername ?? "tid\(n.actorTid)",
            displayName: n.actorUsername ?? "TID #\(n.actorTid)",
            avatarURL: n.actorPfpUrl.flatMap { api.resolveMediaURL($0) }
        )
        let kind: NotificationKind
        switch n.type {
        case .reaction:
            kind = .like(postThumb: nil)
        case .reply:
            kind = .comment(postThumb: nil, text: n.preview ?? "")
        case .follow:
            kind = .follow
        case .mention:
            kind = .mention(postThumb: nil, text: n.preview ?? "")
        case .tip, .pollVote, .eventRsvp, .taskClaim, .taskComplete, .crowdfundPledge:
            return nil
        }
        return AppNotification(
            actor: actor,
            kind: kind,
            createdAt: n.createdAt
        )
    }
}
