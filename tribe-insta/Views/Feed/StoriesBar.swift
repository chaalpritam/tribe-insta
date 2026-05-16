import SwiftUI

struct StoriesBar: View {
    let currentUser: User
    let stories: [Story]
    let onStoryTap: (Story) -> Void
    let onYourStoryTap: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                Button { onYourStoryTap() } label: {
                    storyItem(
                        avatarURL: currentUser.avatarURL,
                        label: "Your story",
                        isOwn: true,
                        hasUnseen: false,
                        isViewed: false
                    )
                }
                .buttonStyle(.plain)

                ForEach(stories) { story in
                    Button { onStoryTap(story) } label: {
                        storyItem(
                            avatarURL: story.author.avatarURL,
                            label: story.author.username,
                            isOwn: false,
                            hasUnseen: true,
                            isViewed: story.isViewed
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func storyItem(
        avatarURL: URL?,
        label: String,
        isOwn: Bool,
        hasUnseen: Bool,
        isViewed: Bool
    ) -> some View {
        VStack(spacing: 6) {
            StoryAvatarView(
                url: avatarURL,
                size: 68,
                isViewed: isViewed,
                isOwn: isOwn,
                hasUnseen: hasUnseen
            )
            Text(label)
                .font(.caption2)
                .lineLimit(1)
                .frame(maxWidth: 72)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    let state = AppState()
    return StoriesBar(
        currentUser: MockData.currentUser,
        stories: MockData.stories,
        onStoryTap: { _ in },
        onYourStoryTap: { }
    )
    .environmentObject(state)
}
