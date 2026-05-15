import SwiftUI

/// Full-screen story viewer. Shows one author's currently-active
/// stories in sequence with IG-style progress bars at the top.
///
/// Phase 3 v1 — single-author, tap to advance, swipe down to dismiss.
/// Phase 4+ adds:
/// - Multi-author swipe between authors
/// - Auto-advance with timer
/// - Reply composer
struct StoryViewer: View {
    let stories: [Story]
    @State private var currentIndex: Int = 0

    @EnvironmentObject private var service: TribeService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let story = currentStory {
                content(for: story)
            } else {
                emptyState
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 80 {
                        dismiss()
                    }
                }
        )
        .onAppear {
            fireViewIfNeeded()
        }
        .onChange(of: currentIndex) { _, _ in
            fireViewIfNeeded()
        }
    }

    private var currentStory: Story? {
        guard currentIndex < stories.count else { return nil }
        return stories[currentIndex]
    }

    @ViewBuilder
    private func content(for story: Story) -> some View {
        ZStack(alignment: .top) {
            RemoteImage(url: story.imageURL)
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            // Tap zones — left advances back, right advances forward.
            // Two invisible halves stacked above the image.
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { goBack() }
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { goForward() }
            }

            VStack(alignment: .leading, spacing: 8) {
                progressBars
                authorRow(story: story)
                Spacer()
                if let caption = story.caption, !caption.isEmpty {
                    captionBubble(caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    private var progressBars: some View {
        HStack(spacing: 4) {
            ForEach(0..<stories.count, id: \.self) { idx in
                Capsule()
                    .fill(idx <= currentIndex ? Color.white : Color.white.opacity(0.3))
                    .frame(height: 2)
            }
        }
    }

    private func authorRow(story: Story) -> some View {
        HStack(spacing: 10) {
            AvatarView(url: story.author.avatarURL, size: 32)
                .overlay(Circle().stroke(.white, lineWidth: 1))
            Text(story.author.username)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.white)
            Text(Formatters.shortRelative(story.createdAt))
                .font(.caption2).foregroundStyle(.white.opacity(0.7))
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.callout).fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
        }
    }

    private func captionBubble(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.black.opacity(0.4), in: Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle")
                .font(.title2).foregroundStyle(.white)
            Text("No stories")
                .font(.headline).foregroundStyle(.white)
        }
    }

    private func goBack() {
        if currentIndex > 0 {
            currentIndex -= 1
        } else {
            dismiss()
        }
    }

    private func goForward() {
        if currentIndex + 1 < stories.count {
            currentIndex += 1
        } else {
            dismiss()
        }
    }

    private func fireViewIfNeeded() {
        guard let story = currentStory, !story.isViewed else { return }
        Task {
            try? await service.viewStory(story)
        }
    }
}

#Preview {
    StoryViewer(stories: MockData.stories)
        .environmentObject(AppState())
        .environmentObject({
            let s = AppState()
            return TribeService(state: s)
        }())
}
