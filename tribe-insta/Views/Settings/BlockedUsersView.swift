import SwiftUI

/// Manage hub-synced block and mute lists.
struct BlockedUsersView: View {
    @EnvironmentObject private var state: AppState

    @State private var blocked: [String] = []
    @State private var muted: [String] = []

    var body: some View {
        List {
            if blocked.isEmpty && muted.isEmpty {
                Section {
                    Text("No blocked or muted accounts.")
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("Block and mute sync across your devices via the hub.")
                }
            }
            if !blocked.isEmpty {
                Section("Blocked") {
                    ForEach(blocked, id: \.self) { tid in
                        restrictionRow(tid: tid, label: "Blocked") {
                            Task {
                                await state.restrictions.unblock(tid)
                                reload()
                            }
                        }
                    }
                }
            }
            if !muted.isEmpty {
                Section("Muted") {
                    ForEach(muted, id: \.self) { tid in
                        restrictionRow(tid: tid, label: "Muted") {
                            Task {
                                await state.restrictions.unmute(tid)
                                reload()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Blocked accounts")
        .navigationBarTitleDisplayMode(.inline)
        .opaqueNavBar()
        .onAppear { reload() }
        .refreshable {
            await state.restrictions.refresh()
            reload()
        }
    }

    private func restrictionRow(tid: String, label: String, unblock: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TID \(tid)")
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Remove", action: unblock)
                .font(.caption.weight(.semibold))
        }
    }

    private func reload() {
        blocked = state.restrictions.blockedTIDs.sorted()
        muted = state.restrictions.mutedTIDs.sorted()
    }
}
