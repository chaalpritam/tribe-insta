import SwiftUI
import AVKit

/// Vertical reels pager. Pulls /v1/reels through TribeService and
/// renders each row as a full-screen VideoPlayer that autoplays on
/// appear and pauses on disappear. The trick to making TabView act
/// vertical is the same rotation hack the original mock used.
struct ReelsView: View {
    @EnvironmentObject private var service: TribeService

    @State private var reels: [Reel] = []
    @State private var currentIndex: Int = 0
    @State private var isLoading: Bool = false
    @State private var isLoadingMore = false
    @State private var reelsCursor: String?
    @State private var errorMessage: String?
    @State private var showCreate = false

    var body: some View {
        GeometryReader { proxy in
            content(size: proxy.size)
        }
        .background(Color.black)
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            HStack {
                Text("Reels")
                    .font(.title3).fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
                Button { showCreate = true } label: {
                    Image(systemName: "camera")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .task { await load(refresh: true) }
        .onChange(of: service.feedRevision) { _, _ in
            Task { await load(refresh: true) }
        }
        .sheet(isPresented: $showCreate) {
            CreatePostView()
        }
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        if reels.isEmpty {
            emptyState
        } else {
            TabView(selection: $currentIndex) {
                ForEach(Array(reels.enumerated()), id: \.element.id) { idx, reel in
                    ReelCard(reel: reel, isCurrent: idx == currentIndex)
                        .frame(width: size.width, height: size.height)
                        .rotationEffect(.degrees(-90))
                        .tag(idx)
                        .onAppear {
                            if idx == reels.count - 1 {
                                Task { await loadMore() }
                            }
                        }
                }
            }
            .frame(width: size.height, height: size.width)
            .rotationEffect(.degrees(90), anchor: .topLeading)
            .offset(x: size.width)
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 14) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if let errorMessage {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.white)
                Text("Couldn't load reels")
                    .font(.headline).foregroundStyle(.white)
                Text(errorMessage)
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button("Retry") { Task { await load() } }
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "play.square.stack")
                    .font(.system(size: 56))
                    .foregroundStyle(.white.opacity(0.8))
                Text("No reels yet")
                    .font(.title3).fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text("Share a video from the + tab to start the feed.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func load(refresh: Bool = false) async {
        if refresh { reelsCursor = nil }
        isLoading = reels.isEmpty
        errorMessage = nil
        do {
            let page = try await service.reelsPage()
            reels = page.reels
            reelsCursor = page.nextCursor
        } catch {
            errorMessage = error.localizedDescription
            if refresh { reels = [] }
        }
        isLoading = false
    }

    @MainActor
    private func loadMore() async {
        guard let cursor = reelsCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await service.reelsPage(cursor: cursor)
            reels.append(contentsOf: page.reels)
            reelsCursor = page.nextCursor
        } catch {
            reelsCursor = nil
        }
    }
}

/// Single reel card. Owns its AVPlayer so the player survives
/// horizontal re-renders inside the TabView; isCurrent toggles
/// playback so the off-screen cards don't keep playing audio.
private struct ReelCard: View {
    @State var reel: Reel
    let isCurrent: Bool

    @State private var player: AVPlayer? = nil
    @State private var showComments: Bool = false
    @EnvironmentObject private var service: TribeService
    @EnvironmentObject private var interactions: InteractionCache

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            videoLayer
                .overlay(
                    LinearGradient(
                        colors: [.clear, .clear, .black.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            HStack(alignment: .bottom, spacing: 12) {
                bottomMeta
                Spacer(minLength: 12)
                actionRail
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 96)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            setupPlayer()
            syncFromCache()
        }
        .onDisappear { player?.pause() }
        .onChange(of: isCurrent) { _, current in
            if current { player?.play() } else { player?.pause() }
        }
        .onChange(of: interactions.likedHashes) { _, _ in syncFromCache() }
        .sheet(isPresented: $showComments) {
            CommentsSheet(targetHash: reel.hash)
        }
    }

    private func syncFromCache() {
        guard let hash = reel.hash, interactions.loaded else { return }
        reel.isLiked = interactions.contains(liked: hash)
    }

    @ViewBuilder
    private var videoLayer: some View {
        if let url = reel.videoURL {
            VideoPlayer(player: player ?? AVPlayer(url: url))
                .disabled(true)
        } else {
            // Fallback for mock data / rows without resolvable video.
            RemoteImage(url: reel.thumbnailURL)
                .clipped()
        }
    }

    private func setupPlayer() {
        guard player == nil, let url = reel.videoURL else { return }
        let p = AVPlayer(url: url)
        p.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: p.currentItem,
            queue: .main
        ) { _ in
            p.seek(to: .zero)
            p.play()
        }
        player = p
        if isCurrent {
            p.play()
        }
    }

    private var bottomMeta: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AvatarView(url: reel.author.avatarURL, size: 32)
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                Text(reel.author.username)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                Button { } label: {
                    Text("Follow")
                        .font(.caption).fontWeight(.semibold)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white, lineWidth: 1))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            if !reel.caption.isEmpty {
                Text(reel.caption)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                Image(systemName: "music.note")
                    .font(.caption)
                Text(reel.audioTitle)
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
        }
    }

    private var actionRail: some View {
        VStack(spacing: 22) {
            railButton(
                system: reel.isLiked ? "heart.fill" : "heart",
                tint: reel.isLiked ? .red : .white,
                count: reel.likesCount
            ) {
                Task { await runLike() }
            }
            railButton(
                system: "bubble.right",
                tint: .white,
                count: reel.commentsCount
            ) { showComments = true }
            railButton(system: "paperplane", tint: .white, count: reel.sharesCount) { }
            Button { } label: {
                Image(systemName: "ellipsis").font(.title3).foregroundStyle(.white)
            }
            RemoteImage(url: reel.author.avatarURL)
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white, lineWidth: 1))
        }
    }

    private func railButton(
        system: String, tint: Color, count: Int, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: system).font(.title2).foregroundStyle(tint)
                Text(Formatters.compactCount(count))
                    .font(.caption2).fontWeight(.semibold).foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func runLike() async {
        guard let hash = reel.hash else { return }
        reel.isLiked.toggle()
        reel.likesCount += reel.isLiked ? 1 : -1
        do {
            _ = try await service.toggleLikeByHash(hash)
        } catch {
            // Revert local optimistic state — the cache revert is
            // handled inside the service.
            reel.isLiked.toggle()
            reel.likesCount += reel.isLiked ? 1 : -1
        }
    }
}

#Preview {
    ReelsView()
        .environmentObject(AppState())
        .environmentObject(TribeService(state: AppState()))
}
