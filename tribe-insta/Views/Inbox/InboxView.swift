import SwiftUI

/// 1:1 conversations list. Reads /v1/dm/conversations/<myTID>;
/// tapping a row opens the ConversationView. Composing a brand-new
/// thread isn't supported here yet — the only entry point into
/// tribe-insta's DM surface today is replying to a story, which lands
/// the conversation in the list on the next refresh.
struct InboxView: View {
    var embeddedInTab: Bool = false

    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var service: TribeService
    @Environment(\.dismiss) private var dismiss

    @State private var conversations: [DMConversation] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showNewMessage = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Messages")
                .navigationBarTitleDisplayMode(.inline)
                .opaqueNavBar()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showNewMessage = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                    if !embeddedInTab {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { dismiss() }
                        }
                    }
                }
                .sheet(isPresented: $showNewMessage) {
                    NewMessageView()
                }
        }
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if conversations.isEmpty {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView().padding(.top, 80)
                } else if let errorMessage {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2).foregroundStyle(.secondary)
                    Text("Couldn't load messages").font(.headline)
                    Text(errorMessage)
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 24)
                    Button("Retry") { Task { await load() } }
                        .font(.subheadline.weight(.semibold))
                } else {
                    Image(systemName: "paperplane")
                        .font(.title2).foregroundStyle(.secondary)
                        .padding(.top, 80)
                    Text("No messages yet").font(.headline)
                    Text("Replies to your stories and DMs from other users show up here.")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(conversations) { conversation in
                NavigationLink {
                    ConversationView(conversation: conversation)
                } label: {
                    ConversationRow(conversation: conversation)
                }
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .refreshable { await load() }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            conversations = try await service.conversations()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct ConversationRow: View {
    let conversation: DMConversation

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: nil, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(conversation.peerUsername ?? "tid\(conversation.peerTid)")
                        .font(.subheadline).fontWeight(.semibold)
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption2).fontWeight(.semibold)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.accentColor, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
                if let last = conversation.lastMessageAt {
                    Text(Formatters.shortRelative(last))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}
