import Foundation

struct User: Identifiable, Hashable {
    let id: UUID
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
    var author: User
    var imageURL: URL?
    var createdAt: Date
    var isViewed: Bool

    init(
        id: UUID = UUID(),
        author: User,
        imageURL: URL? = nil,
        createdAt: Date = Date(),
        isViewed: Bool = false
    ) {
        self.id = id
        self.author = author
        self.imageURL = imageURL
        self.createdAt = createdAt
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
    var author: User
    var thumbnailURL: URL?
    var caption: String
    var likesCount: Int
    var commentsCount: Int
    var sharesCount: Int
    var audioTitle: String
    var isLiked: Bool

    init(
        id: UUID = UUID(),
        author: User,
        thumbnailURL: URL? = nil,
        caption: String,
        likesCount: Int = 0,
        commentsCount: Int = 0,
        sharesCount: Int = 0,
        audioTitle: String = "Original audio",
        isLiked: Bool = false
    ) {
        self.id = id
        self.author = author
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
