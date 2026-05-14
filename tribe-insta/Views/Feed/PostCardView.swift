import SwiftUI

struct PostCardView: View {
    @State var post: Post
    @State private var currentMediaIndex: Int = 0
    @State private var bumpHeart: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            media
            actionRow
            likesRow
            captionRow
            commentsPreview
            timestampRow
        }
        .padding(.bottom, 12)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            StoryAvatarView(url: post.author.avatarURL, size: 36, hasUnseen: true)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(post.author.username).font(.subheadline).fontWeight(.semibold)
                    if post.author.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
                if let location = post.location {
                    Text(location).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { } label: {
                Image(systemName: "ellipsis").font(.callout).foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: Media

    private var media: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $currentMediaIndex) {
                ForEach(Array(post.imageURLs.enumerated()), id: \.offset) { idx, url in
                    RemoteImage(url: url)
                        .clipped()
                        .tag(idx)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            toggleLike(force: true)
                        }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .aspectRatio(1, contentMode: .fit)

            if post.imageURLs.count > 1 {
                Text("\(currentMediaIndex + 1)/\(post.imageURLs.count)")
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(10)
            }

            heartBurst
        }
        .overlay(alignment: .bottom) {
            if post.imageURLs.count > 1 {
                pageDots.padding(.bottom, 8)
            }
        }
    }

    private var heartBurst: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 96))
            .foregroundStyle(.white)
            .shadow(radius: 6)
            .scaleEffect(bumpHeart ? 1 : 0.5)
            .opacity(bumpHeart ? 1 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .animation(.spring(response: 0.35, dampingFraction: 0.55), value: bumpHeart)
    }

    private var pageDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<post.imageURLs.count, id: \.self) { i in
                Circle()
                    .fill(i == currentMediaIndex ? Color.accentColor : Color.white.opacity(0.6))
                    .frame(width: 5, height: 5)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.black.opacity(0.18), in: Capsule())
    }

    // MARK: Action row

    private var actionRow: some View {
        HStack(spacing: 14) {
            Button { toggleLike() } label: {
                Image(systemName: post.isLiked ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundStyle(post.isLiked ? Color.red : Color.primary)
                    .contentTransition(.symbolEffect(.replace))
            }
            Button { } label: {
                Image(systemName: "bubble.right").font(.title3).foregroundStyle(.primary)
            }
            Button { } label: {
                Image(systemName: "paperplane").font(.title3).foregroundStyle(.primary)
            }
            Spacer()
            Button { post.isSaved.toggle() } label: {
                Image(systemName: post.isSaved ? "bookmark.fill" : "bookmark")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var likesRow: some View {
        Text("\(Formatters.compactCount(post.likesCount)) likes")
            .font(.subheadline).fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.top, 6)
    }

    private var captionRow: some View {
        Group {
            if !post.caption.isEmpty {
                (Text(post.author.username).fontWeight(.semibold)
                 + Text(" ")
                 + Text(post.caption))
                    .font(.subheadline)
                    .lineLimit(3)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
            }
        }
    }

    private var commentsPreview: some View {
        Group {
            if post.commentsCount > 0 {
                Button { } label: {
                    Text("View all \(Formatters.compactCount(post.commentsCount)) comments")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.top, 4)
            }
        }
    }

    private var timestampRow: some View {
        Text(Formatters.shortRelative(post.createdAt) + " ago")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 12)
            .padding(.top, 4)
    }

    // MARK: Actions

    private func toggleLike(force: Bool = false) {
        if force {
            if !post.isLiked {
                post.isLiked = true
                post.likesCount += 1
            }
            bumpHeart = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { bumpHeart = false }
        } else {
            post.isLiked.toggle()
            post.likesCount += post.isLiked ? 1 : -1
        }
    }
}

#Preview {
    ScrollView { PostCardView(post: MockData.posts[0]) }
}
