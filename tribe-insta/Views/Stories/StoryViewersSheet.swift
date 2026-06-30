import SwiftUI
import TribeCore

/// "Seen by" list for a single story. Shown only to the story's
/// author (the hub 403s a non-author request when viewer_tid is set,
/// but the StoryViewer also hides the entry point so non-authors
/// never see it in the first place).
struct StoryViewersSheet: View {
    let story: Story

    @EnvironmentObject private var service: TribeService
    @Environment(\.dismiss) private var dismiss

    @State private var viewers: [HubStoryViewer] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Seen by")
                .navigationBarTitleDisplayMode(.inline)
                .opaqueNavBar()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if viewers.isEmpty {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView().padding(.top, 60)
                } else if let errorMessage {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2).foregroundStyle(.secondary)
                    Text("Couldn't load viewers").font(.headline)
                    Text(errorMessage)
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Button("Retry") { Task { await load() } }
                        .font(.subheadline.weight(.semibold))
                } else {
                    Image(systemName: "eye")
                        .font(.title2).foregroundStyle(.secondary)
                        .padding(.top, 60)
                    Text("No one yet").font(.headline)
                    Text("Viewers show up here as they tap through your story.")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(viewers) { viewer in
                    HStack(spacing: 12) {
                        AvatarView(
                            url: viewer.pfpUrl.flatMap { service.api.resolveMediaURL($0) },
                            size: 40
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewer.username ?? "tid\(viewer.viewerTid)")
                                .font(.subheadline).fontWeight(.semibold)
                            Text(Formatters.shortRelative(viewer.viewedAt))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.plain)
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            viewers = try await service.storyViewers(story)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
