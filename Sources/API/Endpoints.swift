import Foundation

/// Read-only mirror of the tribe-hub endpoints tribe-insta needs.
/// Mostly a port of `tribe-ios/Sources/API/Endpoints.swift`, with two
/// trims:
///
/// - `User` renamed to `HubUser` everywhere to avoid clashing with the
///   view-model `User` struct in `tribe-insta/Models/Models.swift`.
/// - DM, on-chain tip, karma, poll/event/task/crowdfund endpoints
///   dropped — Phase 1 (this port) only needs feed / users / search /
///   notifications, and Phase 2 (writes) adds reactions / bookmarks on
///   top of `HubClient.swift` directly.
///
/// Endpoint names match `tribe-app/src/lib/api.ts` so the two clients
/// can be eyeballed side-by-side.
public extension HubClient {
    // MARK: - Feeds

    func fetchFeed(tid: String? = nil) async throws -> [Tweet] {
        if let tid {
            let res: TweetListResponse = try await get("v1/feed/\(tid)")
            return res.tweets
        }
        let res: TweetListResponse = try await get("v1/feed")
        return res.tweets
    }

    /// Cursor-paginated read of `/v1/feed`. Pass `nil` for the first
    /// page; pass back the response's `cursor` to walk further into
    /// history. The hub serves a full page (default 20 rows) on each
    /// hit and returns a nil cursor once the tail is reached.
    func fetchFeedPage(cursor: String? = nil, limit: Int = 20) async throws -> FeedPage {
        var query: [String: String] = ["limit": String(limit)]
        if let cursor { query["cursor"] = cursor }
        return try await get("v1/feed", query: query)
    }

    func fetchTweets(tid: String? = nil) async throws -> [Tweet] {
        if let tid {
            let res: TweetListResponse = try await get("v1/tweets/\(tid)")
            return res.tweets
        }
        let res: TweetListResponse = try await get("v1/tweets")
        return res.tweets
    }

    func fetchTweet(hash: String) async throws -> Tweet {
        try await get("v1/tweet/\(hash)")
    }

    func fetchReplies(hash: String) async throws -> [Tweet] {
        struct R: Decodable { let replies: [Tweet] }
        let r: R = try await get("v1/replies", query: ["hash": hash])
        return r.replies
    }

    // MARK: - Users

    func fetchUsers(limit: Int = 50) async throws -> [HubUser] {
        let res: HubUserListResponse = try await get("v1/users", query: ["limit": String(limit)])
        return res.users
    }

    func fetchUser(_ tid: String) async throws -> HubUser {
        try await get("v1/user/\(tid)")
    }

    /// `/v1/tid-by-wallet/:address`. Reverse lookup. Returns nil when
    /// no TID is registered to the wallet on this hub.
    func fetchTidByWallet(_ address: String) async throws -> HubUser? {
        let res: HubUserListResponse = try await get("v1/tid-by-wallet/\(address)")
        return res.users.first
    }

    func fetchFollowers(_ tid: String, limit: Int = 100) async throws -> [HubUser] {
        let res: HubUserListResponse = try await get(
            "v1/followers/\(tid)",
            query: ["limit": String(limit)]
        )
        return res.users
    }

    func fetchFollowing(_ tid: String, limit: Int = 100) async throws -> [HubUser] {
        let res: HubUserListResponse = try await get(
            "v1/following/\(tid)",
            query: ["limit": String(limit)]
        )
        return res.users
    }

    // MARK: - Notifications

    func fetchNotifications(_ tid: String, limit: Int = 50) async throws -> [TribeNotification] {
        let res: NotificationListResponse = try await get(
            "v1/notifications/\(tid)",
            query: ["limit": String(limit)]
        )
        return res.notifications
    }

    func fetchUnreadCount(_ tid: String, since: Date? = nil) async throws -> Int {
        var query: [String: String] = [:]
        if let since {
            query["since"] = ISO8601DateFormatter().string(from: since)
        }
        let res: NotificationCountResponse = try await get(
            "v1/notifications/\(tid)/count",
            query: query
        )
        return res.count
    }

    // MARK: - Search

    func searchTweets(_ query: String) async throws -> [Tweet] {
        let res: TweetListResponse = try await get("v1/search", query: ["q": query, "limit": "30"])
        return res.tweets
    }

    func searchUsers(_ query: String) async throws -> [HubUser] {
        let res: HubUserListResponse = try await get("v1/search/users", query: ["q": query, "limit": "20"])
        return res.users
    }

    // MARK: - Media URL resolver

    /// `media:<hash>` and absolute `/v1/media/<hash>` references both
    /// route to whichever hub the app is currently pointing at, so
    /// embedded images survive a hub IP change.
    func resolveMediaURL(_ value: String?) -> URL? {
        guard let v = value else { return nil }
        if v.hasPrefix("media:") {
            let hash = String(v.dropFirst("media:".count))
            return baseURL.appendingPathComponent("v1/media/\(hash)")
        }
        if let range = v.range(of: #"/v1/media/[0-9a-fA-F]{64}"#, options: .regularExpression) {
            let path = String(v[range])
            return baseURL.appendingPathComponent(path)
        }
        return URL(string: v)
    }
}
