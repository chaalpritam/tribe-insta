import SwiftUI

struct ActivityView: View {
    let notifications: [AppNotification]

    var body: some View {
        NavigationStack {
            List {
                let groups = group(notifications)
                ForEach(groups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.items) { note in
                            NotificationRow(notification: note)
                                .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
        }
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
}

struct NotificationRow: View {
    let notification: AppNotification

    var body: some View {
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
            RemoteImage(url: thumb)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        case .follow:
            Button { } label: {
                Text("Follow")
                    .font(.subheadline).fontWeight(.semibold)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ActivityView(notifications: MockData.notifications)
}
