import Foundation

/// One row from `/v1/stories` or `/v1/stories/:tid`.
///
/// Stories are STORY_ADD envelopes (type 33) — the hub stamps a 24h
/// `expires_at` on insert and an hourly cron purges expired rows so
/// reads can assume every row is still active.
public struct HubStory: Decodable, Identifiable, Hashable {
    public let hash: String
    public let authorTid: String
    public let mediaHash: String
    public let caption: String?
    public let music: String?
    public let createdAt: Date
    public let expiresAt: Date
    public let username: String?
    public let pfpUrl: String?

    public var id: String { hash }

    enum CodingKeys: String, CodingKey {
        case hash, caption, music, username
        case authorTid = "author_tid"
        case mediaHash = "media_hash"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case pfpUrl = "pfp_url"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hash = try c.decode(String.self, forKey: .hash)
        self.authorTid = try HubDecode.bigInt(c, forKey: .authorTid)
        self.mediaHash = try c.decode(String.self, forKey: .mediaHash)
        self.caption = try c.decodeIfPresent(String.self, forKey: .caption)
        self.music = try c.decodeIfPresent(String.self, forKey: .music)
        self.createdAt = try HubDecode.date(c, forKey: .createdAt)
        self.expiresAt = try HubDecode.date(c, forKey: .expiresAt)
        self.username = try c.decodeIfPresent(String.self, forKey: .username)
        self.pfpUrl = try c.decodeIfPresent(String.self, forKey: .pfpUrl)
    }
}

public struct HubStoryListResponse: Decodable {
    public let stories: [HubStory]
}

/// One row from `/v1/stories/:hash/viewers`. Author-only on the
/// client side; the hub will 403 when `viewer_tid` is passed and
/// doesn't match the story's author_tid.
public struct HubStoryViewer: Decodable, Identifiable, Hashable {
    public let viewerTid: String
    public let viewedAt: Date
    public let username: String?
    public let pfpUrl: String?

    public var id: String { viewerTid }

    enum CodingKeys: String, CodingKey {
        case username
        case viewerTid = "viewer_tid"
        case viewedAt = "viewed_at"
        case pfpUrl = "pfp_url"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.viewerTid = try HubDecode.bigInt(c, forKey: .viewerTid)
        self.viewedAt = try HubDecode.date(c, forKey: .viewedAt)
        self.username = try c.decodeIfPresent(String.self, forKey: .username)
        self.pfpUrl = try c.decodeIfPresent(String.self, forKey: .pfpUrl)
    }
}

public struct HubStoryViewerListResponse: Decodable {
    public let viewers: [HubStoryViewer]
}
