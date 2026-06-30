import SwiftUI

/// Follow / unfollow backed by the ER sequencer. Writes when a custody
/// key is on device; otherwise explains how to follow from tribe-twitter-app.
struct FollowButton: View {
    @EnvironmentObject private var state: AppState
    let targetTID: String

    @State private var status: ERLinkStatus?
    @State private var loading = false
    @State private var explaining = false
    @State private var actionError: String?

    private var isMe: Bool { targetTID == state.myTID }
    private var following: Bool { status?.isFollowing == true }
    private var pending: Bool { status?.isPending == true }
    private var canWrite: Bool { state.custodyKey != nil }

    var body: some View {
        if isMe {
            EmptyView()
        } else {
            Button { Task { await onTap() } } label: {
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
            .disabled(loading || pending)
            .task(id: targetTID) { await refresh() }
            .sheet(isPresented: $explaining) {
                FollowExplainerSheet(following: following)
                    .presentationDetents([.medium])
            }
            .alert("Couldn't update follow", isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(actionError ?? "")
            }
        }
    }

    private var label: String {
        if pending { return "Pending" }
        if following { return "Following" }
        return "Follow"
    }

    @MainActor
    private func onTap() async {
        guard canWrite, let me = state.myTID, let custody = state.custodyKey else {
            explaining = true
            return
        }
        loading = true
        defer { loading = false }
        do {
            if following {
                try await state.er.unfollow(
                    followerTID: me,
                    followingTID: targetTID,
                    custody: custody
                )
            } else {
                try await state.er.follow(
                    followerTID: me,
                    followingTID: targetTID,
                    custody: custody
                )
            }
            await refresh()
        } catch {
            actionError = error.localizedDescription
        }
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

                Text(following ? "Unfollow needs your custody key" : "Follow needs your custody key")
                    .font(.title3.bold())

                Text("Import a backup file or connect with your seed phrase so this device holds your Solana custody key. You can also follow from tribe-twitter-app on desktop."
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
