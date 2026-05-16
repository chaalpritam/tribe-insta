import SwiftUI

/// Full-screen story viewer with multi-author swipe + auto-advance.
///
/// State shape:
/// - `authors`: each entry is one author's stories in chronological order
/// - `(authorIndex, storyIndex)`: position within the (authors, stories[author])
///   product space
/// - `progress`: 0…1 timeline for the current story; auto-advances at
///   STORY_DURATION_SEC, paused while the user long-presses
///
/// Gestures:
/// - Tap left half: previous story (or previous author at index 0)
/// - Tap right half: next story (or next author at end)
/// - Drag horizontally: prev / next author at threshold 60pt
/// - Drag vertically downward >80pt: dismiss
/// - Long-press anywhere on the image: pause the timer until release
struct StoryViewer: View {
    let authors: [[Story]]
    var initialAuthorIndex: Int = 0

    @EnvironmentObject private var service: TribeService
    @Environment(\.dismiss) private var dismiss

    @State private var authorIndex: Int
    @State private var storyIndex: Int = 0
    @State private var progress: Double = 0
    @State private var paused: Bool = false
    @State private var showViewers: Bool = false
    @State private var replyDraft: String = ""
    @State private var isReplying: Bool = false
    @State private var replyError: String?
    @State private var replySent: Bool = false
    @FocusState private var replyFocused: Bool

    @EnvironmentObject private var state: AppState

    /// Seen this session — keeps repeat STORY_VIEW envelopes off the
    /// wire while the user scrubs back and forth.
    @State private var seenHashes: Set<String> = []

    private static let storyDurationSec: Double = 5.0
    private static let timerInterval: Double = 0.05

    init(authors: [[Story]], initialAuthorIndex: Int = 0) {
        self.authors = authors
        self.initialAuthorIndex = initialAuthorIndex
        _authorIndex = State(initialValue: initialAuthorIndex)
    }

    // The timer runs at 20Hz; on every tick we add 0.05/5 to progress.
    private let ticker = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let story = currentStory {
                content(for: story)
            } else {
                emptyState
            }
        }
        .gesture(dragGesture)
        .onReceive(ticker) { _ in tickProgress() }
        .onAppear { fireViewIfNeeded() }
        .onChange(of: authorIndex) { _, _ in
            storyIndex = 0
            progress = 0
            fireViewIfNeeded()
        }
        .onChange(of: storyIndex) { _, _ in
            progress = 0
            fireViewIfNeeded()
        }
    }

    private var currentAuthorStories: [Story] {
        guard authorIndex >= 0 && authorIndex < authors.count else { return [] }
        return authors[authorIndex]
    }

    private var currentStory: Story? {
        let stories = currentAuthorStories
        guard storyIndex >= 0 && storyIndex < stories.count else { return nil }
        return stories[storyIndex]
    }

    @ViewBuilder
    private func content(for story: Story) -> some View {
        ZStack(alignment: .top) {
            RemoteImage(url: story.imageURL)
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            // Tap zones (above the image, below the progress/header).
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
                if isOwnStory(story) {
                    seenByFooter(story: story)
                } else {
                    replyComposer(story: story)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, replyFocused ? 8 : 32)
        }
        .sheet(isPresented: $showViewers) {
            if let s = currentStory {
                StoryViewersSheet(story: s)
            }
        }
        // Long-press anywhere pauses; release resumes. Doesn't disable
        // the tap zones — we use minimumDuration so a normal tap (which
        // is <0.1s) still falls through to onTapGesture above.
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.15)
                .onChanged { _ in paused = true }
                .onEnded { _ in paused = false }
        )
    }

    private var progressBars: some View {
        HStack(spacing: 4) {
            ForEach(0..<currentAuthorStories.count, id: \.self) { idx in
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .overlay(alignment: .leading) {
                        if idx < storyIndex {
                            Capsule().fill(Color.white)
                        } else if idx == storyIndex {
                            GeometryReader { geo in
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: geo.size.width * progress)
                            }
                        }
                    }
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

    /// Bottom-of-viewer "Seen by N" tap target. Only mounted when the
    /// current story belongs to the signed-in user — non-authors get
    /// the (Phase 5+) DM reply composer in this slot instead.
    private func seenByFooter(story: Story) -> some View {
        Button { showViewers = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "eye.fill")
                    .font(.caption).foregroundStyle(.white)
                Text("Seen by")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                Image(systemName: "chevron.up")
                    .font(.caption2).foregroundStyle(.white.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func isOwnStory(_ story: Story) -> Bool {
        guard let myTID = state.myTID,
              let authorTID = story.author.tid
        else { return false }
        return myTID == authorTID
    }

    /// Bottom-of-viewer DM reply composer. Visible only for non-own
    /// stories when the user is signed in. Pauses the auto-advance
    /// ticker while focused so the story doesn't roll past while typing.
    @ViewBuilder
    private func replyComposer(story: Story) -> some View {
        if state.myTID != nil {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    TextField(
                        replySent ? "Sent. Send another?" : "Reply to story",
                        text: $replyDraft,
                        axis: .vertical
                    )
                    .lineLimit(1...3)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .tint(.white)
                    .focused($replyFocused)
                    .onChange(of: replyFocused) { _, focused in
                        paused = focused
                        if focused { replySent = false }
                    }

                    if isReplying {
                        ProgressView()
                            .tint(.white)
                            .padding(.trailing, 8)
                    } else if !replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            Task { await sendReply(story: story) }
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .font(.callout).foregroundStyle(.white)
                                .padding(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(.white.opacity(0.15), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                if let replyError {
                    Text(replyError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .padding(.leading, 14)
                }
            }
        }
    }

    @MainActor
    private func sendReply(story: Story) async {
        let text = replyDraft
        isReplying = true
        replyError = nil
        defer { isReplying = false }
        do {
            try await service.replyToStory(story, text: text)
            replyDraft = ""
            replySent = true
            replyFocused = false
        } catch {
            replyError = error.localizedDescription
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle")
                .font(.title2).foregroundStyle(.white)
            Text("No stories")
                .font(.headline).foregroundStyle(.white)
        }
    }

    // MARK: Navigation

    private var dragGesture: some Gesture {
        DragGesture()
            .onEnded { value in
                let dy = value.translation.height
                let dx = value.translation.width
                if dy > 80 && abs(dy) > abs(dx) {
                    dismiss()
                } else if dx < -60 {
                    nextAuthor()
                } else if dx > 60 {
                    prevAuthor()
                }
            }
    }

    private func goBack() {
        if storyIndex > 0 {
            storyIndex -= 1
        } else {
            prevAuthor(jumpToLast: true)
        }
    }

    private func goForward() {
        if storyIndex + 1 < currentAuthorStories.count {
            storyIndex += 1
        } else {
            nextAuthor()
        }
    }

    private func nextAuthor() {
        if authorIndex + 1 < authors.count {
            authorIndex += 1
        } else {
            dismiss()
        }
    }

    private func prevAuthor(jumpToLast: Bool = false) {
        if authorIndex > 0 {
            authorIndex -= 1
            // Restart at story 0 by default. jumpToLast=true is the
            // edge case where the user tapped "back" on the first
            // story of the current author — IG behavior is to jump to
            // the *last* story of the previous author.
            if jumpToLast {
                let prev = authors[authorIndex]
                storyIndex = max(0, prev.count - 1)
            }
        } else {
            dismiss()
        }
    }

    // MARK: Auto-advance

    private func tickProgress() {
        guard !paused, currentStory != nil else { return }
        progress += Self.timerInterval / Self.storyDurationSec
        if progress >= 1.0 {
            progress = 0
            goForward()
        }
    }

    // MARK: STORY_VIEW

    private func fireViewIfNeeded() {
        guard let story = currentStory, let hash = story.hash else { return }
        if seenHashes.contains(hash) { return }
        seenHashes.insert(hash)
        Task {
            try? await service.viewStory(story)
        }
    }
}

#Preview {
    StoryViewer(authors: [MockData.stories])
        .environmentObject(AppState())
        .environmentObject({
            let s = AppState()
            return TribeService(state: s)
        }())
}
