import SwiftUI

/// Loads a post by protocol hash for deep links and hub URLs.
struct PostDetailLoaderView: View {
    let hash: String

    @EnvironmentObject private var service: TribeService
    @Environment(\.dismiss) private var dismiss

    @State private var post: Post?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let post {
                    ScrollView {
                        PostCardView(post: post)
                    }
                } else if isLoading {
                    ProgressView("Loading post…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 12) {
                        Text("Couldn't open post").font(.headline)
                        Text(errorMessage ?? "Unknown error")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Dismiss") { dismiss() }
                    }
                    .padding(24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .opaqueNavBar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task(id: hash) { await load() }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        post = try? await service.post(hash: hash)
        if post == nil {
            errorMessage = "This post isn't on your hub or has no images."
        }
        isLoading = false
    }
}
