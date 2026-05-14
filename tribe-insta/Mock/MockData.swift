import Foundation

enum MockData {
    static func picsum(_ seed: String, _ width: Int = 600, _ height: Int? = nil) -> URL {
        let h = height ?? width
        return URL(string: "https://picsum.photos/seed/\(seed)/\(width)/\(h)")!
    }

    static let currentUser = User(
        username: "you.tribe",
        displayName: "You",
        avatarURL: picsum("me", 200),
        bio: "Building things at Tribe.\nDesigner • Photographer ✨",
        postsCount: 24,
        followersCount: 1248,
        followingCount: 312,
        isVerified: true
    )

    static let users: [User] = [
        User(username: "ada.lovelace", displayName: "Ada Lovelace",
             avatarURL: picsum("ada", 200), bio: "First programmer.",
             postsCount: 88, followersCount: 12_400, followingCount: 410, isVerified: true),
        User(username: "linus", displayName: "Linus",
             avatarURL: picsum("linus", 200), bio: "Just for fun.",
             postsCount: 102, followersCount: 88_000, followingCount: 23),
        User(username: "grace.hopper", displayName: "Grace Hopper",
             avatarURL: picsum("grace", 200), bio: "Compilers, ships, & coffee.",
             postsCount: 56, followersCount: 34_120, followingCount: 198, isVerified: true),
        User(username: "marie.c", displayName: "Marie Curie",
             avatarURL: picsum("marie", 200), bio: "Radiating curiosity.",
             postsCount: 14, followersCount: 9_300, followingCount: 612, isFollowing: true),
        User(username: "nikola", displayName: "Nikola Tesla",
             avatarURL: picsum("nikola", 200), bio: "Sparks fly.",
             postsCount: 33, followersCount: 21_100, followingCount: 12),
        User(username: "rosalind", displayName: "Rosalind Franklin",
             avatarURL: picsum("rosalind", 200), bio: "Double helix enthusiast.",
             postsCount: 47, followersCount: 5_220, followingCount: 304, isFollowing: true),
        User(username: "richard.f", displayName: "Richard Feynman",
             avatarURL: picsum("richard", 200), bio: "Surely you're joking.",
             postsCount: 71, followersCount: 41_800, followingCount: 88, isVerified: true),
        User(username: "katherine.j", displayName: "Katherine Johnson",
             avatarURL: picsum("katherine", 200), bio: "Hidden no more.",
             postsCount: 29, followersCount: 18_900, followingCount: 220)
    ]

    static let stories: [Story] = users.enumerated().map { idx, user in
        Story(
            author: user,
            imageURL: picsum("story-\(idx)", 800, 1400),
            createdAt: Date().addingTimeInterval(TimeInterval(-idx * 1800)),
            isViewed: idx > 4
        )
    }

    static let posts: [Post] = [
        Post(
            author: users[0],
            imageURLs: [picsum("post-1a", 900), picsum("post-1b", 900)],
            caption: "Golden hour over the harbor 🌅 Sometimes the city slows down just enough.",
            location: "Brooklyn, NY",
            likesCount: 1_204,
            commentsCount: 42,
            createdAt: Date().addingTimeInterval(-3_600),
            isLiked: true,
            comments: sampleComments(for: 0)
        ),
        Post(
            author: users[2],
            imageURLs: [picsum("post-2", 900)],
            caption: "Wrote some tiny code today. It compiled on the first try. Suspicious.",
            location: nil,
            likesCount: 532,
            commentsCount: 19,
            createdAt: Date().addingTimeInterval(-14_400),
            comments: sampleComments(for: 1)
        ),
        Post(
            author: users[4],
            imageURLs: [picsum("post-3a", 900), picsum("post-3b", 900), picsum("post-3c", 900)],
            caption: "Lab notes. Sparks everywhere ⚡️",
            location: "Colorado Springs",
            likesCount: 2_910,
            commentsCount: 88,
            createdAt: Date().addingTimeInterval(-32_400),
            isSaved: true,
            comments: sampleComments(for: 2)
        ),
        Post(
            author: users[5],
            imageURLs: [picsum("post-4", 900)],
            caption: "Photo 51 vibes today.",
            likesCount: 312,
            commentsCount: 8,
            createdAt: Date().addingTimeInterval(-86_400),
            comments: sampleComments(for: 3)
        ),
        Post(
            author: users[6],
            imageURLs: [picsum("post-5a", 900), picsum("post-5b", 900)],
            caption: "There's plenty of room at the bottom. Still no luck finding it though.",
            location: "Caltech",
            likesCount: 4_551,
            commentsCount: 233,
            createdAt: Date().addingTimeInterval(-172_800),
            isLiked: true,
            comments: sampleComments(for: 4)
        )
    ]

    static func sampleComments(for postIndex: Int) -> [Comment] {
        let pool: [String] = [
            "this is unreal 🔥", "okay but the light tho", "saved! 👀",
            "where is this exactly?", "🙌🙌🙌", "stop it I love this",
            "the composition is chef's kiss", "needed this today, thank you",
            "second slide >>>"
        ]
        let userCount = users.count
        let poolCount = pool.count
        var result: [Comment] = []
        for i in 0..<3 {
            let authorIdx = (postIndex + i + 1) % userCount
            let textIdx = (postIndex * 3 + i) % poolCount
            let created = Date().addingTimeInterval(TimeInterval(-i * 600))
            result.append(Comment(
                author: users[authorIdx],
                text: pool[textIdx],
                createdAt: created,
                likesCount: Int.random(in: 0...42)
            ))
        }
        return result
    }

    static let reels: [Reel] = (0..<6).map { i in
        Reel(
            author: users[i % users.count],
            thumbnailURL: picsum("reel-\(i)", 800, 1400),
            caption: ["tiny coding loop", "watch til the end", "best of this week",
                      "saturday vibes", "POV: deploy on friday", "we tried this so you don't have to"][i],
            likesCount: Int.random(in: 800...50_000),
            commentsCount: Int.random(in: 20...2_000),
            sharesCount: Int.random(in: 10...800),
            audioTitle: ["Original audio · \(MockData.users[i % users.count].username)",
                         "trending sound · 1.2M reels",
                         "lo-fi study beats",
                         "Original audio · grace.hopper",
                         "summer hits 2026",
                         "Original audio · linus"][i],
            isLiked: i.isMultiple(of: 2)
        )
    }

    static let explorePosts: [Post] = (0..<24).map { i in
        Post(
            author: users[i % users.count],
            imageURLs: [picsum("explore-\(i)", 600)],
            caption: "",
            likesCount: Int.random(in: 100...20_000),
            commentsCount: Int.random(in: 5...500),
            createdAt: Date().addingTimeInterval(TimeInterval(-i * 3600))
        )
    }

    static let notifications: [AppNotification] = [
        AppNotification(actor: users[0],
                        kind: .like(postThumb: picsum("explore-2", 200)),
                        createdAt: Date().addingTimeInterval(-300)),
        AppNotification(actor: users[1],
                        kind: .follow,
                        createdAt: Date().addingTimeInterval(-1_800)),
        AppNotification(actor: users[2],
                        kind: .comment(postThumb: picsum("explore-7", 200),
                                       text: "this is so clean ✨"),
                        createdAt: Date().addingTimeInterval(-5_400)),
        AppNotification(actor: users[3],
                        kind: .like(postThumb: picsum("explore-12", 200)),
                        createdAt: Date().addingTimeInterval(-10_800)),
        AppNotification(actor: users[4],
                        kind: .mention(postThumb: picsum("explore-5", 200),
                                       text: "mentioned you in a comment"),
                        createdAt: Date().addingTimeInterval(-86_400)),
        AppNotification(actor: users[5],
                        kind: .follow,
                        createdAt: Date().addingTimeInterval(-172_800)),
        AppNotification(actor: users[6],
                        kind: .like(postThumb: picsum("explore-18", 200)),
                        createdAt: Date().addingTimeInterval(-259_200)),
        AppNotification(actor: users[7],
                        kind: .comment(postThumb: picsum("explore-9", 200),
                                       text: "saving this for later"),
                        createdAt: Date().addingTimeInterval(-345_600))
    ]

    static let myPosts: [Post] = (0..<12).map { i in
        Post(
            author: currentUser,
            imageURLs: [picsum("mine-\(i)", 600)],
            caption: "",
            likesCount: Int.random(in: 50...3_000),
            commentsCount: Int.random(in: 1...120),
            createdAt: Date().addingTimeInterval(TimeInterval(-i * 86_400))
        )
    }
}
