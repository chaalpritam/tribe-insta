import Foundation

struct User: Identifiable, Hashable {
    let id: UUID
    /// Tribe Identifier (TID) when this user is backed by the protocol.
    /// nil for mock data. Phase 2 writes need this to address the right
    /// account in REACTION_ADD / BOOKMARK_ADD envelopes.
    var tid: String?
    var username: String
    var displayName: String
    var avatarURL: URL?
    var bio: String
    var postsCount: Int
    var followersCount: Int
    var followingCount: Int
    var isVerified: Bool
    var isFollowing: Bool

    init(
        id: UUID = UUID(),
        tid: String? = nil,
        username: String,
        displayName: String,
        avatarURL: URL? = nil,
        bio: String = "",
        postsCount: Int = 0,
        followersCount: Int = 0,
        followingCount: Int = 0,
        isVerified: Bool = false,
        isFollowing: Bool = false
    ) {
        self.id = id
        self.tid = tid
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.bio = bio
        self.postsCount = postsCount
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.isVerified = isVerified
        self.isFollowing = isFollowing
    }
}

struct Story: Identifiable, Hashable {
    let id: UUID
    /// Protocol envelope hash when backed by a STORY_ADD on the hub.
    /// nil for mock data. Phase 3 viewStory needs this to address the
    /// right target.
    var hash: String?
    var author: User
    var imageURL: URL?
    var caption: String?
    var music: String?
    var createdAt: Date
    var expiresAt: Date?
    var isViewed: Bool

    init(
        id: UUID = UUID(),
        hash: String? = nil,
        author: User,
        imageURL: URL? = nil,
        caption: String? = nil,
        music: String? = nil,
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        isViewed: Bool = false
    ) {
        self.id = id
        self.hash = hash
        self.author = author
        self.imageURL = imageURL
        self.caption = caption
        self.music = music
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.isViewed = isViewed
    }
}

struct Comment: Identifiable, Hashable {
    let id: UUID
    var author: User
    var text: String
    var createdAt: Date
    var likesCount: Int

    init(
        id: UUID = UUID(),
        author: User,
        text: String,
        createdAt: Date = Date(),
        likesCount: Int = 0
    ) {
        self.id = id
        self.author = author
        self.text = text
        self.createdAt = createdAt
        self.likesCount = likesCount
    }
}

struct Post: Identifiable, Hashable {
    let id: UUID
    /// Protocol content hash when this post is backed by a real tweet.
    /// nil for mock data. Phase 2 writes (like / bookmark / reply) need
    /// this to address the right envelope target.
    var hash: String?
    var author: User
    var imageURLs: [URL]
    var caption: String
    var location: String?
    var likesCount: Int
    var commentsCount: Int
    var createdAt: Date
    var isLiked: Bool
    var isSaved: Bool
    var comments: [Comment]

    init(
        id: UUID = UUID(),
        hash: String? = nil,
        author: User,
        imageURLs: [URL],
        caption: String,
        location: String? = nil,
        likesCount: Int = 0,
        commentsCount: Int = 0,
        createdAt: Date = Date(),
        isLiked: Bool = false,
        isSaved: Bool = false,
        comments: [Comment] = []
    ) {
        self.id = id
        self.hash = hash
        self.author = author
        self.imageURLs = imageURLs
        self.caption = caption
        self.location = location
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.createdAt = createdAt
        self.isLiked = isLiked
        self.isSaved = isSaved
        self.comments = comments
    }
}

struct Reel: Identifiable, Hashable {
    let id: UUID
    /// Protocol content hash. Phase 3 — set when the reel is backed by
    /// a TWEET_ADD with post_kind='reel' on the hub.
    var hash: String?
    var author: User
    /// The video URL served from /v1/media/<hash>. Phase 3 wires the
    /// SwiftUI VideoPlayer in ReelCard against this.
    var videoURL: URL?
    var thumbnailURL: URL?
    var caption: String
    var likesCount: Int
    var commentsCount: Int
    var sharesCount: Int
    var audioTitle: String
    var isLiked: Bool

    init(
        id: UUID = UUID(),
        hash: String? = nil,
        author: User,
        videoURL: URL? = nil,
        thumbnailURL: URL? = nil,
        caption: String,
        likesCount: Int = 0,
        commentsCount: Int = 0,
        sharesCount: Int = 0,
        audioTitle: String = "Original audio",
        isLiked: Bool = false
    ) {
        self.id = id
        self.hash = hash
        self.author = author
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.caption = caption
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.sharesCount = sharesCount
        self.audioTitle = audioTitle
        self.isLiked = isLiked
    }
}

enum NotificationKind: Hashable {
    case like(postThumb: URL?)
    case comment(postThumb: URL?, text: String)
    case follow
    case mention(postThumb: URL?, text: String)
}

struct AppNotification: Identifiable, Hashable {
    let id: UUID
    var actor: User
    var kind: NotificationKind
    var createdAt: Date

    init(id: UUID = UUID(), actor: User, kind: NotificationKind, createdAt: Date) {
        self.id = id
        self.actor = actor
        self.kind = kind
        self.createdAt = createdAt
    }
}
