import SwiftUI

/// Reads replies to a post and lets the user post one of their own.
/// "Comment" on the IG-shaped surface is just a reply Tweet with
/// `parent_hash` set, so reading is `/v1/replies?hash=…` and writing
/// is a regular `publishTweet` envelope.
struct CommentsSheet: View {
    let post: Post

    @EnvironmentObject private var service: TribeService
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var comments: [Comment] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var draft: String = ""
    @State private var isSending: Bool = false
    @FocusState private var draftFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                commentsList
                composer
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private var commentsList: some View {
        if comments.isEmpty {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView().padding(.top, 60)
                } else if let errorMessage {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2).foregroundStyle(.secondary)
                    Text("Couldn't load comments").font(.headline)
                    Text(errorMessage).font(.caption).foregroundStyle(.secondary)
                    Button("Retry") { Task { await load() } }
                        .font(.subheadline.weight(.semibold))
                } else {
                    Image(systemName: "bubble.left")
                        .font(.title2).foregroundStyle(.secondary)
                        .padding(.top, 60)
                    Text("No comments yet").font(.headline)
                    Text("Be the first to comment.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(comments) { comment in
                    CommentRow(comment: comment)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .refreshable { await load() }
        }
    }

    private var composer: some View {
        HStack(spacing: 12) {
            AvatarView(url: state.walletAddress.flatMap { _ in nil }, size: 32)
            TextField("Add a comment…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($draftFocused)
                .disabled(post.hash == nil || isSending)
            Button {
                Task { await sendComment() }
            } label: {
                if isSending {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Post").fontWeight(.semibold)
                }
            }
            .disabled(!canSubmit)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var canSubmit: Bool {
        post.hash != nil
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSending
    }

    @MainActor
    private func load() async {
        guard let hash = post.hash else {
            comments = []
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            comments = try await service.replies(forPostHash: hash)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    private func sendComment() async {
        isSending = true
        defer { isSending = false }
        do {
            _ = try await service.reply(to: post, text: draft)
            draft = ""
            draftFocused = false
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CommentRow: View {
    let comment: Comment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(url: comment.author.avatarURL, size: 36)
            VStack(alignment: .leading, spacing: 4) {
                (Text(comment.author.username).fontWeight(.semibold)
                 + Text(" ")
                 + Text(comment.text))
                    .font(.subheadline)
                Text(Formatters.shortRelative(comment.createdAt))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CommentsSheet(post: MockData.posts[0])
        .environmentObject(AppState())
        .environmentObject(TribeService(state: AppState()))
}
