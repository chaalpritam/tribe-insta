import SwiftUI

/// Pick a user and start a 1:1 DM thread.
struct NewMessageView: View {
    @EnvironmentObject private var service: TribeService
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var users: [User] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var openedConversation: DMConversation?

    var body: some View {
        NavigationStack {
            Group {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 60)
                        Text("Search for someone")
                            .font(.headline)
                        Text("Find a user by username to send a message.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isSearching {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if users.isEmpty {
                    Text("No users found")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(users) { user in
                        if let tid = user.tid {
                            Button {
                                openConversation(peerTID: tid, username: user.username)
                            } label: {
                                HStack(spacing: 12) {
                                    AvatarView(url: user.avatarURL, size: 44)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(user.username).fontWeight(.semibold)
                                        Text(user.displayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("New message")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search users")
            .onChange(of: query) { _, newValue in
                Task { await runSearch(newValue) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(item: $openedConversation) { conversation in
                ConversationView(conversation: conversation)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
            }
        }
    }

    @MainActor
    private func runSearch(_ q: String) async {
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            users = []
            return
        }
        isSearching = true
        errorMessage = nil
        do {
            users = try await service.searchUsers(trimmed)
        } catch {
            users = []
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }

    private func openConversation(peerTID: String, username: String) {
        guard let me = state.myTID,
              let convId = dmConversationId(myTID: me, peerTID: peerTID)
        else { return }
        openedConversation = DMConversation(
            id: convId,
            peerTid: peerTID,
            peerUsername: username
        )
    }
}
