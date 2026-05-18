import SwiftUI

/// Read-only follow indicator backed by the ER sequencer. Tapping
/// explains that follows must be signed from tribe-app (custody key).
struct FollowButton: View {
    @EnvironmentObject private var state: AppState
    let targetTID: String

    @State private var status: ERLinkStatus?
    @State private var loading = false
    @State private var explaining = false

    private var isMe: Bool { targetTID == state.myTID }
    private var following: Bool { status?.isFollowing == true }
    private var pending: Bool { status?.isPending == true }

    var body: some View {
        if isMe {
            EmptyView()
        } else {
            Button { explaining = true } label: {
                HStack(spacing: 6) {
                    if loading {
                        ProgressView().controlSize(.mini)
                    } else if pending {
                        Image(systemName: "clock")
                    } else if following {
                        Image(systemName: "checkmark")
                    } else {
                        Image(systemName: "plus")
                    }
                    Text(label)
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundStyle(following ? Theme.primary : Color.white)
                .background(Capsule().fill(following ? Theme.primary.opacity(0.12) : Theme.primary))
            }
            .buttonStyle(.plain)
            .task(id: targetTID) { await refresh() }
            .sheet(isPresented: $explaining) {
                FollowExplainerSheet(following: following)
                    .presentationDetents([.medium])
            }
        }
    }

    private var label: String {
        if pending { return "Pending" }
        if following { return "Following" }
        return "Follow"
    }

    @MainActor
    private func refresh() async {
        guard let me = state.myTID, !isMe else { return }
        loading = status == nil
        defer { loading = false }
        status = try? await state.er.link(followerTID: me, followingTID: targetTID)
    }
}

private struct FollowExplainerSheet: View {
    let following: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.tint)
                    .padding(.top, 24)

                Text(following ? "Unfollow on tribe-app" : "Follow on tribe-app")
                    .font(.title3.bold())

                Text(following
                     ? "Unfollows are signed by your Solana custody key. Open tribe-app, find this profile, and tap Unfollow. The ER sequencer updates here within a second."
                     : "Follows are written to the ER sequencer with your Solana custody key. Open tribe-app on desktop to follow — this app will show Following once the sequencer confirms."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

                Spacer()

                Button("Got it") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
    }
}
