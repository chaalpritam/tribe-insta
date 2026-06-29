import Foundation

/// Per-user state read-backs: have I liked / bookmarked this tweet.
/// Used by InteractionCache to populate the heart and bookmark icons
/// on every visible post without hitting the hub once per card.
///
/// Trimmed port from tribe-twitter — drops `fetchMyPollVote` and
/// `fetchMyEventRSVP` since polls and events aren't IG-shaped
/// surfaces.
public extension HubClient {
    // MARK: - Reactions

    struct ReactionRow: Decodable {
        public let targetHash: String
        public let reactionType: String?
        public let reactedAt: Date?

        enum CodingKeys: String, CodingKey {
            case targetHash = "target_hash"
            case reactionType = "reaction_type"
            case reactedAt = "reacted_at"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.targetHash = try c.decode(String.self, forKey: .targetHash)
            self.reactionType = try c.decodeIfPresent(String.self, forKey: .reactionType)
            self.reactedAt = try HubDecode.dateIfPresent(c, forKey: .reactedAt)
        }
    }

    /// Bulk read of a TID's currently-active reactions. Filtered to a
    /// specific reaction subtype when `type` is non-nil — e.g. `"1"` for
    /// likes. Used at feed mount time to populate the heart icon on
    /// every visible post without hitting the hub once per card.
    func fetchMyReactions(tid: String, type: String? = nil) async throws -> [ReactionRow] {
        struct R: Decodable { let reactions: [ReactionRow] }
        var query: [String: String] = [:]
        if let type { query["type"] = type }
        let r: R = try await get("v1/users/\(tid)/reactions", query: query)
        return r.reactions
    }

    // MARK: - Bookmarks

    struct BookmarkRow: Decodable {
        public let targetHash: String

        enum CodingKeys: String, CodingKey {
            case targetHash = "target_hash"
        }
    }

    func fetchMyBookmarks(tid: String) async throws -> [BookmarkRow] {
        struct R: Decodable { let bookmarks: [BookmarkRow] }
        let r: R = try await get("v1/bookmarks/\(tid)")
        return r.bookmarks
    }

    /// Same endpoint as `fetchMyBookmarks`, but decodes the joined
    /// tweet payload so saved-post surfaces render without N+1 fetches.
    func fetchBookmarkedTweets(tid: String) async throws -> [Tweet] {
        struct Row: Decodable {
            let targetHash: String
            let authorTid: String?
            let text: String?
            let timestamp: Date?
            let parentHash: String?
            let channelId: String?
            let embeds: [String]?
            let username: String?
            let postKind: String?

            enum CodingKeys: String, CodingKey {
                case targetHash = "target_hash"
                case authorTid = "author_tid"
                case text, timestamp, embeds, username
                case parentHash = "parent_hash"
                case channelId = "channel_id"
                case postKind = "post_kind"
            }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                self.targetHash = try c.decode(String.self, forKey: .targetHash)
                self.authorTid = try HubDecode.bigIntIfPresent(c, forKey: .authorTid)
                self.text = try c.decodeIfPresent(String.self, forKey: .text)
                self.timestamp = try HubDecode.dateIfPresent(c, forKey: .timestamp)
                self.parentHash = try c.decodeIfPresent(String.self, forKey: .parentHash)
                self.channelId = try c.decodeIfPresent(String.self, forKey: .channelId)
                self.embeds = try c.decodeIfPresent([String].self, forKey: .embeds)
                self.username = try c.decodeIfPresent(String.self, forKey: .username)
                self.postKind = try c.decodeIfPresent(String.self, forKey: .postKind)
            }
        }
        struct R: Decodable { let bookmarks: [Row] }
        let r: R = try await get("v1/bookmarks/\(tid)")
        return r.bookmarks.compactMap { row in
            guard let authorTid = row.authorTid, let ts = row.timestamp else { return nil }
            return Tweet(
                hash: row.targetHash,
                tid: authorTid,
                text: row.text,
                parentHash: row.parentHash,
                channelId: row.channelId,
                embeds: row.embeds,
                timestamp: ts,
                username: row.username,
                replyCount: nil,
                postKind: row.postKind
            )
        }
    }
}
