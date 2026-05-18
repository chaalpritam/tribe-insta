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

    /// Public so a few surfaces (the story viewers sheet's avatar
    /// resolver, mainly) can resolve media URLs without re-typing the
    /// HubClient handle.
    var api: HubClient { state.api }

    // MARK: - Feed

    /// Photo-only home feed. `/v1/feed` returns every tweet kind; we
    /// drop the ones without image embeds since they're not IG-shaped
    /// content. The hub doesn't yet expose a `post_kind` discriminator
    /// (see PLAN.md Phase 3) — once it does, this becomes a server-side
    /// filter and we stop downloading text-only rows.
    func feed(limit: Int = 30) async throws -> [Post] {
        let page = try await api.fetchFeedPage(limit: limit)
        var posts = page.tweets.compactMap(mapToPost)
        posts = await enrichFollowing(on: posts)
        return posts
    }

    /// Cursor-paginated photo feed. Returns the next cursor when more
    /// pages exist.
    func feedPage(cursor: String? = nil, limit: Int = 20) async throws -> (posts: [Post], nextCursor: String?) {
        let page = try await api.fetchFeedPage(cursor: cursor, limit: limit)
        var posts = page.tweets.compactMap(mapToPost)
        posts = await enrichFollowing(on: posts)
        return (posts, page.cursor)
    }

    /// Load a single photo post by protocol hash (post detail, deep links).
    func post(hash: String) async throws -> Post? {
        let tweet = try await api.fetchTweet(hash: hash)
        guard var post = mapToPost(tweet) else { return nil }
        let enriched = await enrichFollowing(on: [post])
        post = enriched[0]
        return post
    }

    // MARK: - Profile

    /// Returns the view-model `User` for the profile header plus the
    /// user's photo-only posts for the grid. Hub doesn't expose a
    /// `posts_count` field on /v1/user — for now we count what we
    /// fetched. Phase 3's `post_kind` migration would let the hub
    /// surface the photo count directly.
    func profile(tid: String) async throws -> (user: User, posts: [Post], reels: [Reel]) {
        async let hubUser = api.fetchUser(tid)
        async let tweets = api.fetchTweets(tid: tid)
        let allTweets = try await tweets
        var posts = allTweets.compactMap(mapToPost)
        posts = await enrichFollowing(on: posts)
        let reels = allTweets.compactMap(mapToReel)
        var u = mapToUser(try await hubUser)
        u.postsCount = posts.count
        if let me = state.myTID, me != tid,
           let link = try? await state.er.link(followerTID: me, followingTID: tid) {
            u.isFollowing = link.isFollowing
        }
        return (u, posts, reels)
    }

    func followers(of tid: String) async throws -> [User] {
        try await api.fetchFollowers(tid).map(mapToUser)
    }

    func following(of tid: String) async throws -> [User] {
        try await api.fetchFollowing(tid).map(mapToUser)
    }

    /// Bookmarked photo posts for the signed-in user.
    func savedPosts() async throws -> [Post] {
        let (_, tid, _) = try requireSignedIn()
        let tweets = try await api.fetchBookmarkedTweets(tid: tid)
        return tweets.compactMap(mapToPost)
    }

    // MARK: - Search

    func searchUsers(_ query: String) async throws -> [User] {
        let hubUsers = try await api.searchUsers(query)
        var users = hubUsers.map(mapToUser)
        users = await enrichFollowing(users: users)
        return users
    }

    func searchPosts(_ query: String) async throws -> [Post] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let q = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        var posts = try await api.searchTweets(q).compactMap(mapToPost)
        posts = await enrichFollowing(on: posts)
        return posts
    }

    /// Sum of unread DM counts across conversations.
    func unreadDMCount() async throws -> Int {
        try await conversations().reduce(0) { $0 + $1.unreadCount }
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

    /// Reply to a story via DM. Looks up the recipient's x25519
    /// pubkey, encrypts via nacl.box, and submits DM_SEND.
    /// Plaintext is JSON `{"text": ..., "story_hash": ...}` so a
    /// future inbox can render "Replied to your story" anchored to
    /// the right target.
    func replyToStory(_ story: Story, text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ServiceError.emptyText }
        guard let recipientTID = story.author.tid,
              let storyHash = story.hash
        else { throw ServiceError.notProtocolBacked }
        let (appKey, myTID, _) = try requireSignedIn()

        let dmKey = try await state.ensureDMKey()
        guard let recipientPub = try await api.fetchDMPublicKey(recipientTID) else {
            throw ServiceError.recipientHasNoDMKey
        }

        let plaintext: [String: Any] = [
            "text": trimmed,
            "story_hash": storyHash,
        ]
        let plaintextBytes = try JSONSerialization.data(
            withJSONObject: plaintext,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )

        let nonce = NaClBox.randomNonce()
        let ciphertext = try NaClBox.box(
            plaintextBytes,
            nonce: nonce,
            recipientPublicKey: recipientPub,
            senderPrivateKey: dmKey.privateKey
        )

        _ = try await api.sendDM(
            recipientTID: recipientTID,
            ciphertext: ciphertext,
            nonce: nonce,
            senderX25519: dmKey.publicKey,
            as: appKey,
            tid: myTID
        )
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
        let (items, _) = try await reelsPage(cursor: nil, limit: limit)
        return items
    }

    func reelsPage(
        cursor: String? = nil,
        limit: Int = 20,
        sort: HubClient.ReelsSort = .engagement
    ) async throws -> (reels: [Reel], nextCursor: String?) {
        let page = try await api.fetchReelsPage(cursor: cursor, limit: limit, sort: sort)
        return (page.reels.compactMap(mapToReel), page.cursor)
    }

    /// Batch ER lookups so feed/search cards can show Following state.
    func enrichFollowing(users: [User]) async -> [User] {
        guard let me = state.myTID else { return users }
        var copy = users
        await withTaskGroup(of: (Int, Bool).self) { group in
            for (idx, user) in copy.enumerated() {
                guard let tid = user.tid, tid != me else { continue }
                group.addTask { [er = state.er] in
                    let following = (try? await er.link(
                        followerTID: me,
                        followingTID: tid
                    ))?.isFollowing == true
                    return (idx, following)
                }
            }
            for await (idx, following) in group {
                copy[idx].isFollowing = following
            }
        }
        return copy
    }

    func enrichFollowing(on posts: [Post]) async -> [Post] {
        guard state.myTID != nil else { return posts }
        var copy = posts
        let authorTIDs = Set(copy.compactMap(\.author.tid))
        var followingByTID: [String: Bool] = [:]
        await withTaskGroup(of: (String, Bool).self) { group in
            guard let me = state.myTID else { return }
            for tid in authorTIDs where tid != me {
                group.addTask { [er = state.er] in
                    let following = (try? await er.link(
                        followerTID: me,
                        followingTID: tid
                    ))?.isFollowing == true
                    return (tid, following)
                }
            }
            for await (tid, following) in group {
                followingByTID[tid] = following
            }
        }
        for i in copy.indices {
            if let tid = copy[i].author.tid, let following = followingByTID[tid] {
                copy[i].author.isFollowing = following
            }
        }
        return copy
    }

    /// ER follow state for rendering Follow / Following / Pending.
    func followStatus(targetTID: String) async throws -> ERLinkStatus? {
        guard let me = state.myTID, me != targetTID else { return nil }
        return try await state.er.link(followerTID: me, followingTID: targetTID)
    }

    func deletePost(_ post: Post) async throws {
        let (appKey, tid, hash) = try requireWriteContext(post: post)
        try await api.deleteTweet(hash: hash, as: appKey, tid: tid)
        feedRevision &+= 1
    }

    func updateProfileField(_ field: String, value: String) async throws {
        let (appKey, tid, _) = try requireSignedIn()
        _ = try await api.updateProfile(field: field, value: value, as: appKey, tid: tid)
        await state.refreshIdentityMetadata()
    }

    /// Upload avatar bytes and set `pfpUrl` to the returned media hash.
    func updateAvatar(imageJPEG: Data) async throws {
        let (appKey, tid, _) = try requireSignedIn()
        let hash = try await api.uploadMedia(
            data: imageJPEG,
            contentType: "image/jpeg",
            filename: "avatar.jpg"
        )
        _ = try await api.updateProfile(
            field: "pfpUrl",
            value: "media:\(hash)",
            as: appKey,
            tid: tid
        )
        await state.refreshIdentityMetadata()
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

    // MARK: - Inbox

    /// 1:1 conversations the signed-in user is part of, newest first.
    func conversations() async throws -> [DMConversation] {
        let (_, tid, _) = try requireSignedIn()
        let raw = try await api.fetchConversations(tid)
        return raw.sorted { lhs, rhs in
            (lhs.lastMessageAt ?? .distantPast) > (rhs.lastMessageAt ?? .distantPast)
        }
    }

    /// Ciphertext rows for a conversation. Decryption happens in
    /// `decrypt(_:)` so a single corrupt envelope can't sink the
    /// whole thread.
    func messages(forConversationId conversationId: String) async throws -> [DMMessage] {
        let (_, tid, _) = try requireSignedIn()
        return try await api.fetchDMMessages(conversationId: conversationId, tid: tid)
    }

    /// Open a single DMMessage with our DMKey + the embedded sender
    /// x25519 pubkey. Returns the plaintext + an optional story_hash
    /// when the JSON payload includes one (story replies from this
    /// app — and from tribe-app's StoryViewer composer — carry it).
    func decrypt(_ message: DMMessage) async throws -> DecryptedDM {
        let dmKey = try await state.ensureDMKey()
        guard let cipherBytes = Data(base64Encoded: message.ciphertext),
              let nonceBytes = Data(base64Encoded: message.nonce),
              let senderPubBase64 = message.senderX25519,
              let senderPub = Data(base64Encoded: senderPubBase64)
        else {
            throw ServiceError.invalidDMPayload
        }
        let plaintextBytes = try NaClBox.boxOpen(
            cipherBytes,
            nonce: nonceBytes,
            senderPublicKey: senderPub,
            recipientPrivateKey: dmKey.privateKey
        )

        // Try JSON first (story replies + the iOS/web composers
        // both pack a {text, story_hash} object). Fall back to UTF-8
        // text so legacy bare-string DMs still render.
        if let object = try? JSONSerialization.jsonObject(with: plaintextBytes) as? [String: Any] {
            let text = (object["text"] as? String) ?? ""
            let storyHash = object["story_hash"] as? String
            return DecryptedDM(text: text, storyHash: storyHash)
        }
        let text = String(data: plaintextBytes, encoding: .utf8) ?? ""
        return DecryptedDM(text: text, storyHash: nil)
    }

    /// Send a plaintext DM to a specific peer TID. Used by the
    /// ConversationView composer — wraps the same NaClBox pipeline
    /// replyToStory uses but doesn't bundle a story_hash.
    @discardableResult
    func sendDM(to recipientTID: String, text: String) async throws -> Data {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ServiceError.emptyText }
        let (appKey, myTID, _) = try requireSignedIn()

        let dmKey = try await state.ensureDMKey()
        guard let recipientPub = try await api.fetchDMPublicKey(recipientTID) else {
            throw ServiceError.recipientHasNoDMKey
        }

        let plaintext: [String: Any] = ["text": trimmed]
        let plaintextBytes = try JSONSerialization.data(
            withJSONObject: plaintext,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )

        let nonce = NaClBox.randomNonce()
        let ciphertext = try NaClBox.box(
            plaintextBytes,
            nonce: nonce,
            recipientPublicKey: recipientPub,
            senderPrivateKey: dmKey.privateKey
        )

        return try await api.sendDM(
            recipientTID: recipientTID,
            ciphertext: ciphertext,
            nonce: nonce,
            senderX25519: dmKey.publicKey,
            as: appKey,
            tid: myTID
        )
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
            // Phase 6: aggregate counts come from /v1/feed's correlated
            // subqueries. Older hub builds that haven't migrated yet
            // return nil → 0 (counter stays blank, but PostCardView's
            // likesRow hides empty counts anyway).
            likesCount: tweet.reactionCount ?? 0,
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
            likesCount: tweet.reactionCount ?? 0,
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
    case recipientHasNoDMKey
    case invalidDMPayload

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
        case .recipientHasNoDMKey:
            return "This user hasn't set up DMs on the hub yet."
        case .invalidDMPayload:
            return "Could not decode message."
        }
    }
}

/// Plaintext result from TribeService.decrypt(_:). `storyHash` is
/// non-nil when the DM's plaintext was a story-reply payload — the
/// view layer can use it to render "Replied to your story" inline.
struct DecryptedDM: Hashable {
    let text: String
    let storyHash: String?
}
