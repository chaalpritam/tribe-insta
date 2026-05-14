import SwiftUI

struct AvatarView: View {
    let url: URL?
    var size: CGFloat = 36

    var body: some View {
        RemoteImage(url: url)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(.separator).opacity(0.4), lineWidth: 0.5))
    }
}

struct StoryAvatarView: View {
    let url: URL?
    var size: CGFloat = 64
    var isViewed: Bool = false
    var isOwn: Bool = false
    var hasUnseen: Bool = true

    private let unseenGradient = LinearGradient(
        colors: [Color(red: 0.96, green: 0.40, blue: 0.20),
                 Color(red: 0.91, green: 0.18, blue: 0.41),
                 Color(red: 0.69, green: 0.13, blue: 0.80)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ring
                .frame(width: size, height: size)
                .overlay(
                    RemoteImage(url: url)
                        .frame(width: size - 8, height: size - 8)
                        .clipShape(Circle())
                )

            if isOwn {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: size * 0.28, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor)
                    .background(Circle().fill(.background).padding(2))
                    .offset(x: 2, y: 2)
            }
        }
    }

    @ViewBuilder
    private var ring: some View {
        if hasUnseen && !isViewed {
            Circle().strokeBorder(unseenGradient, lineWidth: 2.5)
        } else {
            Circle().strokeBorder(Color(.tertiaryLabel), lineWidth: 1)
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        StoryAvatarView(url: MockData.picsum("me", 200), isOwn: true)
        StoryAvatarView(url: MockData.picsum("ada", 200))
        StoryAvatarView(url: MockData.picsum("linus", 200), isViewed: true)
        AvatarView(url: MockData.picsum("grace", 200), size: 44)
    }
    .padding()
}
