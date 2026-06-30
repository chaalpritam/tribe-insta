import SwiftUI
import TribeCore

/// One DM thread.
struct ConversationView: View {
    let conversation: DMConversation

    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var service: TribeService

    @State private var bubbles: [Bubble] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var draft: String = ""
    @State private var isSending: Bool = false
    @FocusState private var draftFocused: Bool

    /// View-model row built from a decrypted DMMessage so the view can
    /// render without keeping ciphertext+plaintext side by side.
    struct Bubble: Identifiable, Hashable {
        let id: String
        let isMine: Bool
        let text: String
        let storyHash: String?
        let timestamp: Date
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            composer
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .opaqueNavBar()
        .task { await load() }
    }

    private var displayName: String {
        conversation.peerUsername ?? "tid\(conversation.peerTid)"
    }

    @ViewBuilder
    private var messageList: some View {
        if bubbles.isEmpty {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView().padding(.top, 80)
                } else if let errorMessage {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2).foregroundStyle(.secondary)
                    Text("Couldn't load thread").font(.headline)
                    Text(errorMessage)
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 24)
                    Button("Retry") { Task { await load() } }
                        .font(.subheadline.weight(.semibold))
                } else {
                    Image(systemName: "lock.shield")
                        .font(.title2).foregroundStyle(.secondary)
                        .padding(.top, 80)
                    Text("No messages yet").font(.headline)
                    Text("End-to-end encrypted with NaCl-box.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(bubbles) { bubble in
                            BubbleRow(bubble: bubble)
                                .id(bubble.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
                .onAppear { scrollToLatest(proxy: proxy) }
                .onChange(of: bubbles.last?.id) { _, _ in scrollToLatest(proxy: proxy) }
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 12) {
            TextField("Message…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($draftFocused)
                .disabled(isSending)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 18))
            Button {
                Task { await send() }
            } label: {
                if isSending {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.callout)
                }
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var canSend: Bool {
        !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let raw = try await service.messages(forConversationId: conversation.id)
            var built: [Bubble] = []
            for message in raw {
                let isMine = message.senderTid == state.myTID
                do {
                    let plain = try await service.decrypt(message)
                    built.append(Bubble(
                        id: message.hash,
                        isMine: isMine,
                        text: plain.text,
                        storyHash: plain.storyHash,
                        timestamp: message.timestamp
                    ))
                } catch {
                    // Single-row decrypt failure — render a placeholder
                    // rather than dropping the bubble so the user knows
                    // something arrived but couldn't open.
                    built.append(Bubble(
                        id: message.hash,
                        isMine: isMine,
                        text: "[Encrypted — couldn't open]",
                        storyHash: nil,
                        timestamp: message.timestamp
                    ))
                }
            }
            bubbles = built.sorted { $0.timestamp < $1.timestamp }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func send() async {
        let text = draft
        isSending = true
        defer { isSending = false }
        do {
            _ = try await service.sendDM(to: conversation.peerTid, text: text)
            draft = ""
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scrollToLatest(proxy: ScrollViewProxy) {
        guard let lastId = bubbles.last?.id else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}

private struct BubbleRow: View {
    let bubble: ConversationView.Bubble

    var body: some View {
        HStack {
            if bubble.isMine { Spacer(minLength: 44) }
            VStack(alignment: .leading, spacing: 4) {
                if let storyHash = bubble.storyHash {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.caption2)
                        Text("Replied to story")
                            .font(.caption2)
                    }
                    .foregroundStyle(bubble.isMine ? .white.opacity(0.85) : .secondary)
                    .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 2)
                    let _ = storyHash // currently informational; Phase 7 deep-links
                }
                Text(bubble.text)
                    .font(.subheadline)
                    .foregroundStyle(bubble.isMine ? .white : .primary)
                    .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .background(
                bubble.isMine
                    ? Color.accentColor
                    : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 16)
            )
            if !bubble.isMine { Spacer(minLength: 44) }
        }
    }
}
