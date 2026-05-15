import Foundation
import SwiftUI

/// Top-level app state. Carries:
///
///   - `phase`: drives the root view between Onboarding and the main
///              TabView. Computed from whether we have *both* a TID
///              and an app-key seed in the Keychain.
///   - `hubBaseURL`: the URL the HubClient hits. Persisted in
///                   UserDefaults so the user can rebuild from Settings
///                   without losing their identity.
///   - `myTID` + `myUsername` + `walletAddress`: the user's identity
///     surfaced to the rest of the UI.
///   - `appKey`: the ed25519 keypair used to sign protocol envelopes.
///     Loaded from the Keychain at launch and never written to disk
///     anywhere else.
///   - `api`: a HubClient configured to the current hubBaseURL.
///   - `er`: an ERClient pointed at the ER sequencer.
///
/// Trimmed from tribe-ios's AppState: no DM key (no DMs in the
/// IG-shaped surface yet), no interaction cache (no writes in Phase
/// 1), no on-chain tip stats cache, no user avatar cache. Add those
/// back as the matching tabs land.
@MainActor
final class AppState: ObservableObject {
    enum Phase: Equatable {
        /// First launch (or after sign out): user needs to configure a
        /// hub URL and create or import an identity before we route
        /// them to the main TabView.
        case onboarding
        /// Identity is fully provisioned and the app shell can render.
        case ready
    }

    @Published var phase: Phase

    @Published var hubBaseURL: URL {
        didSet {
            UserDefaults.standard.set(hubBaseURL.absoluteString, forKey: Keys.hubURL)
            api = HubClient(baseURL: hubBaseURL)
        }
    }

    @Published var erBaseURL: URL {
        didSet {
            UserDefaults.standard.set(erBaseURL.absoluteString, forKey: Keys.erURL)
            er = ERClient(baseURL: erBaseURL)
        }
    }

    @Published var myTID: String? {
        didSet { persistTID(); recomputePhase() }
    }

    @Published private(set) var appKey: AppKey? {
        didSet { recomputePhase() }
    }

    /// x25519 keypair used for nacl.box DM encryption. Lazy-loaded
    /// the first time something asks for it (the StoryViewer reply
    /// composer is the only surface that needs it today); first call
    /// also publishes a DM_KEY_REGISTER envelope so peers can encrypt
    /// to us.
    @Published private(set) var dmKey: DMKey?

    @Published var myUsername: String?
    @Published var walletAddress: String?

    private(set) var api: HubClient
    private(set) var er: ERClient
    /// Per-session liked / bookmarked set. Lazy-loaded on first
    /// PostCardView render with a known TID; refreshed on sign-in and
    /// pull-to-refresh. Write paths keep it in sync optimistically.
    let interactions: InteractionCache

    init() {
        // One-time correctness gates. Trap fast on startup if an
        // OS-level integer / endianness assumption ever breaks Blake3
        // or knocks the NaCl-box port off byte-compatibility with
        // tweetnacl — both are unrecoverable from a silent bug.
        Blake3.selfTest()
        NaClBox.selfTest()

        let storedURL = UserDefaults.standard.string(forKey: Keys.hubURL)
            .flatMap(URL.init(string:)) ?? Config.defaultHubURL
        let storedERURL = UserDefaults.standard.string(forKey: Keys.erURL)
            .flatMap(URL.init(string:)) ?? Config.defaultERURL
        let storedTID = UserDefaults.standard.string(forKey: Keys.tid)

        // Restore the app key from Keychain if we have one.
        let restoredKey: AppKey?
        if let seed = try? KeychainStore.load(.appKeySeed),
           seed.count == 32,
           let restored = try? AppKey.restore(seedBase64: seed.base64EncodedString()) {
            restoredKey = restored
        } else {
            restoredKey = nil
        }

        self.hubBaseURL = storedURL
        self.erBaseURL = storedERURL
        self.myTID = storedTID
        self.api = HubClient(baseURL: storedURL)
        self.er = ERClient(baseURL: storedERURL)
        self.appKey = restoredKey
        self.phase = (storedTID != nil && restoredKey != nil) ? .ready : .onboarding

        // InteractionCache holds a weak ref back to self so it can
        // read `api` / `myTID` lazily without an init-order cycle.
        self.interactions = InteractionCache()
        self.interactions.attach(to: self)

        // Best-effort fetch of profile metadata so the UI shows the
        // right name / wallet on first paint after a relaunch.
        if let tid = storedTID {
            Task { [weak self] in
                await self?.refreshIdentityMetadata(tid: tid)
                await self?.interactions.refresh()
            }
        }
    }

    // MARK: - Onboarding handoff

    /// Persist a freshly imported identity. Called from the onboarding
    /// views once the user confirms their TID + app key.
    func adopt(tid: String, appKey: AppKey) throws {
        try KeychainStore.save(appKey.privateKey.rawRepresentation, for: .appKeySeed)
        self.appKey = appKey
        self.myTID = tid
        Task { [weak self] in
            await self?.refreshIdentityMetadata(tid: tid)
            await self?.interactions.refresh()
        }
    }

    /// Wipe the identity. Hub URL stays so the user doesn't have to
    /// re-enter it on a re-onboard. Routes back to onboarding.
    func signOut() {
        try? KeychainStore.delete(.appKeySeed)
        DMKey.clearKeychain()
        appKey = nil
        dmKey = nil
        myTID = nil
        myUsername = nil
        walletAddress = nil
        interactions.clear()
    }

    /// Lazy-load (or create + persist) the DM keypair. Surfaces that
    /// need to encrypt or decrypt DMs call this; the first call also
    /// publishes a DM_KEY_REGISTER envelope so peers can encrypt to
    /// us. Subsequent calls hit the cached DMKey and skip the
    /// registration round-trip.
    @discardableResult
    func ensureDMKey() async throws -> DMKey {
        if let dm = dmKey { return dm }
        let key = try DMKey.loadOrCreate()
        await MainActor.run { self.dmKey = key }
        if let appKey, let myTID {
            _ = try? await api.registerDMKey(
                publicKey: key.publicKey,
                as: appKey,
                tid: myTID
            )
        }
        return key
    }

    func refreshIdentityMetadata() async {
        guard let tid = myTID else { return }
        await refreshIdentityMetadata(tid: tid)
    }

    private func refreshIdentityMetadata(tid: String) async {
        do {
            let user = try await api.fetchUser(tid)
            self.myUsername = user.username
            self.walletAddress = user.custodyAddress
        } catch {
            // Non-fatal: hub may be unreachable on first launch, profile
            // header just falls back to "TID #N".
        }
    }

    // MARK: - Internals

    private func persistTID() {
        if let tid = myTID {
            UserDefaults.standard.set(tid, forKey: Keys.tid)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.tid)
        }
    }

    private func recomputePhase() {
        phase = (myTID != nil && appKey != nil) ? .ready : .onboarding
    }

    /// The wall-clock moment this TID last opened the notifications
    /// screen. Backed by UserDefaults so it survives relaunches; nil
    /// the first time the user looks at notifications. Per-TID so
    /// switching accounts on one device doesn't bleed state across.
    func lastNotificationsReadAt(tid: String) -> Date? {
        let raw = UserDefaults.standard.double(forKey: Keys.notificationsReadAt(tid))
        return raw > 0 ? Date(timeIntervalSince1970: raw) : nil
    }

    /// Stamp "now" as the read mark — called when the Activity tab
    /// appears so the badge resets to zero until something new lands.
    func markNotificationsRead(tid: String) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.notificationsReadAt(tid))
    }

    private enum Keys {
        static let hubURL = "tribe.hubBaseURL"
        static let erURL = "tribe.erBaseURL"
        static let tid = "tribe.tid"
        static func notificationsReadAt(_ tid: String) -> String {
            "tribe.notificationsReadAt.\(tid)"
        }
    }
}
