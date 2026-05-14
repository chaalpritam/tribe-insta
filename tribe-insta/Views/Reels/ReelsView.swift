import SwiftUI

struct ReelsView: View {
    let reels: [Reel]

    @State private var currentIndex: Int = 0

    var body: some View {
        GeometryReader { proxy in
            TabView(selection: $currentIndex) {
                ForEach(Array(reels.enumerated()), id: \.element.id) { idx, reel in
                    ReelCard(reel: reel)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .rotationEffect(.degrees(-90))
                        .tag(idx)
                }
            }
            .frame(width: proxy.size.height, height: proxy.size.width)
            .rotationEffect(.degrees(90), anchor: .topLeading)
            .offset(x: proxy.size.width)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(Color.black)
            .ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            HStack {
                Text("Reels")
                    .font(.title3).fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
                Button { } label: {
                    Image(systemName: "camera")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
}

private struct ReelCard: View {
    @State var reel: Reel

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: reel.thumbnailURL)
                .clipped()
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

            Text(reel.caption)
                .font(.subheadline)
                .foregroundStyle(.white)
                .lineLimit(2)

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
                reel.isLiked.toggle()
                reel.likesCount += reel.isLiked ? 1 : -1
            }
            railButton(system: "bubble.right", tint: .white, count: reel.commentsCount) { }
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
}

#Preview {
    ReelsView(reels: MockData.reels)
}
