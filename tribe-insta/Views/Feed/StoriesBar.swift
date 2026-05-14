import SwiftUI

struct StoriesBar: View {
    let currentUser: User
    let stories: [Story]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                storyItem(
                    avatarURL: currentUser.avatarURL,
                    label: "Your story",
                    isOwn: true,
                    hasUnseen: false,
                    isViewed: false
                )

                ForEach(stories) { story in
                    storyItem(
                        avatarURL: story.author.avatarURL,
                        label: story.author.username,
                        isOwn: false,
                        hasUnseen: true,
                        isViewed: story.isViewed
                    )
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
    StoriesBar(currentUser: MockData.currentUser, stories: MockData.stories)
}
