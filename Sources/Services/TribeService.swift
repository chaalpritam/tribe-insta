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
    /// Bumps every time a write that the feed cares about lands —
    /// publishPhotoPost, deleteTweet, etc. FeedView observes this so
    /// the new post shows up without a manual pull-to-refresh.
    @Published private(set) var feedRevision: Int = 0

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

    // MARK: - Stories

    /// Active stories. When the user is signed in we pass their TID
    /// through so the hub returns only stories from authors they
    /// follow + their own; signed-out renders see everyone (useful
    /// for the demo / landing experience).
    func stories(limit: Int = 100) async throws -> [Story] {
        let raw = try await api.fetchStories(limit: limit, viewerTID: state.myTID)
        return raw.map(mapToStory)
    }

    /// One author's currently-active stories, oldest-first.
    func stories(forUserTID tid: String) async throws -> [Story] {
        let raw = try await api.fetchStories(forTID: tid)
        return raw.map(mapToStory)
    }

    /// Author-only "seen by" list for a story. Hub 403s when the
    /// requester isn't the story's author — Swift surfaces that as a
    /// thrown HubError.
    func storyViewers(_ story: Story) async throws -> [HubStoryViewer] {
        let (_, tid, _) = try requireSignedIn()
        guard let hash = story.hash else { return [] }
        return try await api.fetchStoryViewers(storyHash: hash, viewerTID: tid)
    }

    /// Fires a STORY_VIEW envelope. Idempotent — the hub keeps the
    /// first view per (story_hash, viewer_tid), later calls are a
    /// no-op at the storage layer.
    func viewStory(_ story: Story) async throws {
        let (appKey, tid, _) = try requireSignedIn()
        guard let hash = story.hash else { return }
        _ = try await api.viewStory(storyHash: hash, as: appKey, tid: tid)
    }

    /// Upload the image, then publish STORY_ADD. caption and music
    /// optional; the hub stamps a 24h expiry server-side so the client
    /// can't override TTL.
    @discardableResult
    func publishStory(
        image: (data: Data, contentType: String),
        caption: String? = nil,
        music: String? = nil
    ) async throws -> String {
        let (appKey, tid, _) = try requireSignedIn()
        let mediaHash = try await api.uploadMedia(
            data: image.data,
            contentType: image.contentType,
            filename: "story.jpg"
        )
        let hash = try await api.publishStory(
            mediaHash: mediaHash,
            as: appKey,
            tid: tid,
            caption: caption,
            music: music
        )
        feedRevision &+= 1
        return hash
    }

    // MARK: - Reels

    /// Paginated feed of reels (TWEET_ADD with post_kind='reel').
    func reels(limit: Int = 20) async throws -> [Reel] {
        let tweets = try await api.fetchReels(limit: limit)
        return tweets.compactMap(mapToReel)
    }

    /// Upload the video, then publish a TWEET_ADD with
    /// post_kind='reel'. caption + audioTitle optional.
    @discardableResult
    func publishReel(
        video: (data: Data, contentType: String),
        caption: String = "",
        audioTitle: String? = nil,
        location: String? = nil
    ) async throws -> String {
        let (appKey, tid, _) = try requireSignedIn()
        let mediaHash = try await api.uploadMedia(
            data: video.data,
            contentType: video.contentType,
            filename: "reel.mp4"
        )
        let hash = try await api.publishReel(
            videoEmbed: "media:\(mediaHash)",
            as: appKey,
            tid: tid,
            caption: caption,
            audioTitle: audioTitle,
            location: location
        )
        feedRevision &+= 1
        return hash
    }

    // MARK: - Notifications

    func notifications(tid: String, limit: Int = 50) async throws -> [AppNotification] {
        let raw = try await api.fetchNotifications(tid, limit: limit)
        return raw.compactMap(mapToNotification)
    }

    // MARK: - Replies (Comments)

    /// Returns reply tweets as IG-shaped Comments. Replies aren't
    /// required to have image embeds (text-only comments are normal),
    /// so we don't filter the way `mapToPost` does.
    func replies(forPostHash hash: String) async throws -> [Comment] {
        let tweets = try await api.fetchReplies(hash: hash)
        return tweets.map { reply in
            Comment(
                author: User(
                    tid: reply.tid,
                    username: reply.username ?? "tid\(reply.tid)",
                    displayName: reply.username ?? "TID #\(reply.tid)"
                ),
                text: reply.text ?? "",
                createdAt: reply.timestamp,
                likesCount: 0
            )
        }
    }

    // MARK: - Writes

    /// Toggle the heart on a post. Updates the interaction cache
    /// optimistically, then sends the REACTION envelope; reverts the
    /// cache on failure and rethrows. Returns the new liked state.
    @discardableResult
    func toggleLike(_ post: Post) async throws -> Bool {
        guard let hash = post.hash else { throw ServiceError.notProtocolBacked }
        return try await toggleLikeByHash(hash)
    }

    /// Toggle the bookmark on a post. Same optimistic-update pattern
    /// as toggleLike.
    @discardableResult
    func toggleBookmark(_ post: Post) async throws -> Bool {
        guard let hash = post.hash else { throw ServiceError.notProtocolBacked }
        return try await toggleBookmarkByHash(hash)
    }

    /// Like/unlike toggle by target hash. Used by surfaces that don't
    /// have a `Post` wrapper handy — reels (which are TWEET_ADD rows
    /// stored in `messages`), comment cards, search hits, etc.
    @discardableResult
    func toggleLikeByHash(_ hash: String) async throws -> Bool {
        let (appKey, tid, _) = try requireSignedIn()
        let wantsLiked = !state.interactions.contains(liked: hash)
        state.interactions.setLiked(wantsLiked, hash: hash)
        do {
            if wantsLiked {
                try await api.likeTweet(hash: hash, as: appKey, tid: tid)
            } else {
                try await api.unlikeTweet(hash: hash, as: appKey, tid: tid)
            }
            return wantsLiked
        } catch {
            state.interactions.setLiked(!wantsLiked, hash: hash)
            throw error
        }
    }

    @discardableResult
    func toggleBookmarkByHash(_ hash: String) async throws -> Bool {
        let (appKey, tid, _) = try requireSignedIn()
        let wantsSaved = !state.interactions.contains(bookmarked: hash)
        state.interactions.setBookmarked(wantsSaved, hash: hash)
        do {
            try await api.bookmark(hash: hash, as: appKey, tid: tid, add: wantsSaved)
            return wantsSaved
        } catch {
            state.interactions.setBookmarked(!wantsSaved, hash: hash)
            throw error
        }
    }

    /// Post a reply (an IG "comment") to a post. Returns the new hash.
    @discardableResult
    func reply(to post: Post, text: String) async throws -> String {
        guard let hash = post.hash else { throw ServiceError.notProtocolBacked }
        return try await reply(toHash: hash, text: text)
    }

    /// Reply directly against a target hash. Same envelope shape
    /// (TWEET_ADD with parent_hash) — used by surfaces that don't
    /// carry a `Post` wrapper (reels, deep-linked tweet pages, etc.).
    @discardableResult
    func reply(toHash hash: String, text: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ServiceError.emptyText
        }
        let (appKey, tid, _) = try requireSignedIn()
        return try await api.publishTweet(
            text: trimmed,
            as: appKey,
            tid: tid,
            parentHash: hash,
            channelId: nil,
            embeds: nil
        )
    }

    /// Publish a photo post. Uploads each image to /v1/upload first,
    /// collects the media hashes, then submits a TWEET_ADD envelope
    /// with `embeds = ["media:<hash>", ...]`. Throws fast if any
    /// individual upload fails — partial state on the hub would be
    /// confusing.
    @discardableResult
    func publishPhotoPost(
        images: [(data: Data, contentType: String)],
        caption: String
    ) async throws -> String {
        guard !images.isEmpty else {
            throw ServiceError.noImages
        }
        let (appKey, tid, _) = try requireSignedIn()
        var mediaRefs: [String] = []
        mediaRefs.reserveCapacity(images.count)
        for (idx, image) in images.enumerated() {
            let hash = try await api.uploadMedia(
                data: image.data,
                contentType: image.contentType,
                filename: "photo-\(idx).jpg"
            )
            mediaRefs.append("media:\(hash)")
        }
        let hash = try await api.publishTweet(
            text: caption,
            as: appKey,
            tid: tid,
            parentHash: nil,
            channelId: nil,
            embeds: mediaRefs
        )
        feedRevision &+= 1
        return hash
    }

    // MARK: - Write helpers

    private func requireWriteContext(post: Post) throws -> (AppKey, String, String) {
        let (appKey, tid, _) = try requireSignedIn()
        guard let hash = post.hash else {
            throw ServiceError.notProtocolBacked
        }
        return (appKey, tid, hash)
    }

    /// Returns (appKey, tid, _) — the third tuple slot is reserved so
    /// `requireWriteContext` can layer the hash on top with the same
    /// shape.
    private func requireSignedIn() throws -> (AppKey, String, String) {
        guard let appKey = state.appKey, let tid = state.myTID else {
            throw ServiceError.notSignedIn
        }
        return (appKey, tid, "")
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

    /// HubStory → view-model Story. Resolves the media URL through
    /// HubClient so the path survives hub IP changes.
    private func mapToStory(_ s: HubStory) -> Story {
        let author = User(
            tid: s.authorTid,
            username: s.username ?? "tid\(s.authorTid)",
            displayName: s.username ?? "TID #\(s.authorTid)",
            avatarURL: s.pfpUrl.flatMap { api.resolveMediaURL($0) }
        )
        return Story(
            hash: s.hash,
            author: author,
            imageURL: api.resolveMediaURL("media:\(s.mediaHash)"),
            caption: s.caption,
            music: s.music,
            createdAt: s.createdAt,
            expiresAt: s.expiresAt,
            isViewed: false
        )
    }

    /// Tweet (post_kind='reel') → view-model Reel. Drops tweets
    /// without any embed since there's no video to play.
    private func mapToReel(_ tweet: Tweet) -> Reel? {
        guard let firstEmbed = tweet.embeds?.first,
              let videoURL = api.resolveMediaURL(firstEmbed)
        else { return nil }
        let author = User(
            tid: tweet.tid,
            username: tweet.username ?? "tid\(tweet.tid)",
            displayName: tweet.username ?? "TID #\(tweet.tid)"
        )
        return Reel(
            hash: tweet.hash,
            author: author,
            videoURL: videoURL,
            thumbnailURL: nil,
            caption: tweet.text ?? "",
            likesCount: 0,
            commentsCount: tweet.replyCount ?? 0,
            sharesCount: 0,
            audioTitle: tweet.audioTitle ?? "Original audio",
            isLiked: false
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

enum ServiceError: LocalizedError {
    case notSignedIn
    case notProtocolBacked
    case emptyText
    case noImages

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in to do that."
        case .notProtocolBacked:
            return "This post isn't backed by the protocol yet."
        case .emptyText:
            return "Type something first."
        case .noImages:
            return "Pick at least one photo."
        }
    }
}
