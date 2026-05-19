import SwiftUI

/// Notifications grouped by Today / This week / Earlier. Fetches
/// /v1/notifications/<myTID> on appear and pull-down refresh; stamps
/// "now" as the read mark so the bell badge resets (Phase 2 surfaces
/// the badge in FeedView toolbar).
struct ActivityView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var service: TribeService

    @State private var notifications: [AppNotification] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Notifications")
                .navigationBarTitleDisplayMode(.inline)
                .opaqueNavBar()
                .navigationDestination(for: String.self) { tid in
                    UserProfileView(tid: tid)
                }
        }
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if notifications.isEmpty {
            emptyState
        } else {
            List {
                let groups = group(notifications)
                ForEach(groups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.items) { note in
                            NotificationRow(notification: note)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    }
                }
            }
            .listStyle(.plain)
            .refreshable { await load() }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            if isLoading {
                ProgressView().padding(.top, 80)
            } else if let errorMessage {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2).foregroundStyle(.secondary)
                Text("Couldn't load notifications").font(.headline)
                Text(errorMessage)
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button("Retry") { Task { await load() } }
                    .font(.subheadline.weight(.semibold))
            } else {
                Image(systemName: "bell")
                    .font(.title2).foregroundStyle(.secondary)
                    .padding(.top, 80)
                Text("Nothing new").font(.headline)
                Text("Reactions, replies, mentions, and follows on your posts show up here.")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private struct NotificationGroup {
        let title: String
        let items: [AppNotification]
    }

    private func group(_ notes: [AppNotification]) -> [NotificationGroup] {
        var today: [AppNotification] = []
        var thisWeek: [AppNotification] = []
        var earlier: [AppNotification] = []
        let now = Date()
        for n in notes {
            let secs = now.timeIntervalSince(n.createdAt)
            if secs < 86_400 { today.append(n) }
            else if secs < 604_800 { thisWeek.append(n) }
            else { earlier.append(n) }
        }
        var result: [NotificationGroup] = []
        if !today.isEmpty { result.append(.init(title: "Today", items: today)) }
        if !thisWeek.isEmpty { result.append(.init(title: "This week", items: thisWeek)) }
        if !earlier.isEmpty { result.append(.init(title: "Earlier", items: earlier)) }
        return result
    }

    @MainActor
    private func load() async {
        guard let tid = state.myTID else { return }
        isLoading = true
        errorMessage = nil
        do {
            notifications = try await service.notifications(tid: tid)
            state.markNotificationsRead(tid: tid)
            await state.refreshBadgeCounts()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct NotificationRow: View {
    let notification: AppNotification

    var body: some View {
        Group {
            if let tid = notification.actor.tid {
                NavigationLink(value: tid) { rowContent }
                    .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 12) {
            AvatarView(url: notification.actor.avatarURL, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                description
                Text(Formatters.shortRelative(notification.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            trailing
        }
        .padding(.vertical, 4)
    }

    private var description: some View {
        let username = Text(notification.actor.username).fontWeight(.semibold)
        switch notification.kind {
        case .like:
            return (username + Text(" liked your post.")).font(.subheadline)
        case .follow:
            return (username + Text(" started following you.")).font(.subheadline)
        case .comment(_, let text):
            return (username + Text(" commented: ") + Text("\"\(text)\"").italic())
                .font(.subheadline)
        case .mention(_, let text):
            return (username + Text(" \(text)")).font(.subheadline)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch notification.kind {
        case .like(let thumb), .comment(let thumb, _), .mention(let thumb, _):
            if thumb != nil {
                RemoteImage(url: thumb)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                EmptyView()
            }
        case .follow:
            if let tid = notification.actor.tid {
                FollowButton(targetTID: tid)
            }
        }
    }
}

#Preview {
    ActivityView()
        .environmentObject(AppState())
        .environmentObject(TribeService(state: AppState()))
}
