import Foundation
import TribeCore

/// Hub-synced block and mute lists. Writes signed BLOCK_ADD /
/// MUTE_ADD envelopes (and *_REMOVE) so the same TID's restrictions
/// follow across devices. UserDefaults keeps a local cache for fast
/// reads and offline filtering until the next refresh.
@MainActor
final class UserRestrictionsStore: ObservableObject {
    @Published private(set) var blockedTIDs: Set<String> = []
    @Published private(set) var mutedTIDs: Set<String> = []
    @Published private(set) var loaded = false

    private weak var app: AppState?
    private var migratedLocal = false

    init() {
        blockedTIDs = Set(UserDefaults.standard.stringArray(forKey: Keys.blocked) ?? [])
        mutedTIDs = Set(UserDefaults.standard.stringArray(forKey: Keys.muted) ?? [])
    }

    func attach(to app: AppState) {
        self.app = app
    }

    func isBlocked(_ tid: String) -> Bool { blockedTIDs.contains(tid) }
    func isMuted(_ tid: String) -> Bool { mutedTIDs.contains(tid) }

    func block(_ tid: String) async {
        applyLocalBlock(tid)
        await submitBlock(tid, add: true)
    }

    func unblock(_ tid: String) async {
        blockedTIDs.remove(tid)
        persist()
        await submitBlock(tid, add: false)
    }

    func mute(_ tid: String) async {
        guard !isBlocked(tid) else { return }
        mutedTIDs.insert(tid)
        persist()
        await submitMute(tid, add: true)
    }

    func unmute(_ tid: String) async {
        mutedTIDs.remove(tid)
        persist()
        await submitMute(tid, add: false)
    }

    /// Pull block + mute lists from the hub. Replaces in-memory state
    /// on success. One-time: pushes any pre-hub local-only entries up
    /// when the hub returns empty but this device still has cached TIDs.
    func refresh() async {
        guard let app, let myTID = app.myTID else {
            blockedTIDs = []
            mutedTIDs = []
            loaded = false
            return
        }
        guard let response = try? await app.api.fetchRestrictions(myTID) else {
            loaded = blockedTIDs.isEmpty && mutedTIDs.isEmpty ? false : true
            return
        }
        let hubBlocked = Set(response.blocked.map(\.targetTid))
        let hubMuted = Set(response.muted.map(\.targetTid))
        if !migratedLocal, hubBlocked.isEmpty, hubMuted.isEmpty,
           (!blockedTIDs.isEmpty || !mutedTIDs.isEmpty) {
            migratedLocal = true
            await migrateLocalToHub()
            return await refresh()
        }
        migratedLocal = true
        blockedTIDs = hubBlocked
        mutedTIDs = hubMuted
        persist()
        loaded = true
    }

    func clear() {
        blockedTIDs = []
        mutedTIDs = []
        loaded = false
        migratedLocal = false
        persist()
    }

    // MARK: - Internals

    private func applyLocalBlock(_ tid: String) {
        blockedTIDs.insert(tid)
        mutedTIDs.remove(tid)
        persist()
    }

    private func submitBlock(_ tid: String, add: Bool) async {
        guard let app, let myTID = app.myTID, let appKey = app.appKey else { return }
        do {
            _ = try await app.api.blockUser(targetTID: tid, as: appKey, tid: myTID, add: add)
        } catch {
            if add {
                blockedTIDs.remove(tid)
            } else {
                blockedTIDs.insert(tid)
            }
            persist()
        }
    }

    private func submitMute(_ tid: String, add: Bool) async {
        guard let app, let myTID = app.myTID, let appKey = app.appKey else { return }
        let hadMute = mutedTIDs.contains(tid)
        do {
            _ = try await app.api.muteUser(targetTID: tid, as: appKey, tid: myTID, add: add)
        } catch {
            if add {
                mutedTIDs.remove(tid)
            } else if hadMute {
                mutedTIDs.insert(tid)
            }
            persist()
        }
    }

    private func migrateLocalToHub() async {
        let blocks = blockedTIDs
        let mutes = mutedTIDs.subtracting(blocks)
        for tid in blocks {
            await submitBlock(tid, add: true)
        }
        for tid in mutes {
            await submitMute(tid, add: true)
        }
    }

    private func persist() {
        UserDefaults.standard.set(Array(blockedTIDs), forKey: Keys.blocked)
        UserDefaults.standard.set(Array(mutedTIDs), forKey: Keys.muted)
    }

    private enum Keys {
        static let blocked = "tribe.blockedTIDs"
        static let muted = "tribe.mutedTIDs"
    }
}
