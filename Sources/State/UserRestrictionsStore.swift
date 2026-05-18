import Foundation

/// Device-local block and mute lists. The hub has no block/mute
/// envelopes yet — these filters apply only on this device until
/// protocol support lands.
@MainActor
final class UserRestrictionsStore: ObservableObject {
    @Published private(set) var blockedTIDs: Set<String> = []
    @Published private(set) var mutedTIDs: Set<String> = []

    init() {
        blockedTIDs = Set(UserDefaults.standard.stringArray(forKey: Keys.blocked) ?? [])
        mutedTIDs = Set(UserDefaults.standard.stringArray(forKey: Keys.muted) ?? [])
    }

    func isBlocked(_ tid: String) -> Bool { blockedTIDs.contains(tid) }
    func isMuted(_ tid: String) -> Bool { mutedTIDs.contains(tid) }

    func block(_ tid: String) {
        blockedTIDs.insert(tid)
        mutedTIDs.remove(tid)
        persist()
    }

    func unblock(_ tid: String) {
        blockedTIDs.remove(tid)
        persist()
    }

    func mute(_ tid: String) {
        guard !isBlocked(tid) else { return }
        mutedTIDs.insert(tid)
        persist()
    }

    func unmute(_ tid: String) {
        mutedTIDs.remove(tid)
        persist()
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
