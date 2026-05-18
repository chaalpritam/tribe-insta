import SwiftUI

struct PostCardView: View {
    @State var post: Post
    @State private var currentMediaIndex: Int = 0
    @State private var bumpHeart: Bool = false
    @State private var showComments: Bool = false
    @State private var showDeleteConfirm = false
    @State private var showMoreMenu = false

    @EnvironmentObject private var service: TribeService
    @EnvironmentObject private var state: AppState
    /// Injected separately because SwiftUI doesn't observe nested
    /// ObservableObjects through their parent — without this, cache
    /// refreshes wouldn't trigger our onChange handlers.
    @EnvironmentObject private var interactions: InteractionCache

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
        .onAppear { syncFromCache() }
        .onChange(of: interactions.likedHashes) { _, _ in syncFromCache() }
        .onChange(of: interactions.bookmarkedHashes) { _, _ in syncFromCache() }
        .sheet(isPresented: $showComments) {
            CommentsSheet(targetHash: post.hash)
        }
        .confirmationDialog("Post options", isPresented: $showMoreMenu, titleVisibility: .visible) {
            if isOwnPost {
                Button("Delete post", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete this post?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { Task { await deletePost() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the post from the hub for everyone.")
        }
    }

    private var isOwnPost: Bool {
        guard let authorTID = post.author.tid, let myTID = state.myTID else { return false }
        return authorTID == myTID
    }

    private var shareText: String {
        let user = post.author.username
        let caption = post.caption.isEmpty ? "" : " — \(post.caption)"
        return "@\(user) on Tribe\(caption)"
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            authorLink {
                StoryAvatarView(url: post.author.avatarURL, size: 36, hasUnseen: true)
            }
            authorLink {
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
            }
            Spacer()
            Button { showMoreMenu = true } label: {
                Image(systemName: "ellipsis").font(.callout).foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func authorLink<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if let tid = post.author.tid {
            NavigationLink(value: tid) { content() }
                .buttonStyle(.plain)
        } else {
            content()
        }
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
                            Task { await runLike(force: true) }
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
            Button { Task { await runLike() } } label: {
                Image(systemName: post.isLiked ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundStyle(post.isLiked ? Color.red : Color.primary)
                    .contentTransition(.symbolEffect(.replace))
            }
            Button { showComments = true } label: {
                Image(systemName: "bubble.right").font(.title3).foregroundStyle(.primary)
            }
            if let hash = post.hash, let url = shareURL(for: hash) {
                ShareLink(item: url, subject: Text(shareText), message: Text(shareText)) {
                    Image(systemName: "paperplane").font(.title3).foregroundStyle(.primary)
                }
            } else {
                ShareLink(item: shareText) {
                    Image(systemName: "paperplane").font(.title3).foregroundStyle(.primary)
                }
            }
            Spacer()
            Button { Task { await runBookmark() } } label: {
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
        Group {
            if post.likesCount > 0 {
                Text("\(Formatters.compactCount(post.likesCount)) likes")
                    .font(.subheadline).fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
            }
        }
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
                Button { showComments = true } label: {
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

    /// Reads the InteractionCache and pushes its truth onto the local
    /// optimistic state. Called on first render and whenever the cache's
    /// liked / bookmarked sets change (e.g. after `interactions.refresh()`
    /// from pull-to-refresh).
    private func syncFromCache() {
        guard let hash = post.hash else { return }
        if interactions.loaded {
            post.isLiked = interactions.contains(liked: hash)
            post.isSaved = interactions.contains(bookmarked: hash)
        }
    }

    /// Optimistic like toggle. Updates the local state first so the
    /// heart animates immediately; TribeService handles cache mutation
    /// + hub round-trip and reverts on failure (cache change pings us
    /// back through onChange).
    @MainActor
    private func runLike(force: Bool = false) async {
        guard post.hash != nil else { return }
        let wantsLiked = force ? true : !post.isLiked
        if force && post.isLiked == false {
            post.isLiked = true
            post.likesCount += 1
        } else if !force {
            post.isLiked.toggle()
            post.likesCount += post.isLiked ? 1 : -1
        }
        if force {
            bumpHeart = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { bumpHeart = false }
        }
        guard wantsLiked != interactions.contains(liked: post.hash!) else { return }
        do {
            _ = try await service.toggleLike(post)
        } catch {
            // Revert optimistic counter — cache revert handled by service.
            if force {
                post.isLiked = false
                post.likesCount -= 1
            } else {
                post.isLiked.toggle()
                post.likesCount += post.isLiked ? 1 : -1
            }
        }
    }

    private func shareURL(for hash: String) -> URL? {
        service.api.baseURL.appendingPathComponent("v1/tweet/\(hash)")
    }

    @MainActor
    private func deletePost() async {
        do {
            try await service.deletePost(post)
        } catch {
            // Silent — user can pull to refresh if delete failed.
        }
    }

    @MainActor
    private func runBookmark() async {
        guard post.hash != nil else { return }
        post.isSaved.toggle()
        do {
            _ = try await service.toggleBookmark(post)
        } catch {
            post.isSaved.toggle()
        }
    }
}

#Preview {
    let state = AppState()
    return ScrollView { PostCardView(post: MockData.posts[0]) }
        .environmentObject(state)
        .environmentObject(state.interactions)
        .environmentObject(TribeService(state: state))
}
