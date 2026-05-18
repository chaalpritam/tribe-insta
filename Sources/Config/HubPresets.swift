import Foundation

/// Quick hub URL picks for onboarding and settings — avoids typing
/// `http://127.0.0.1:4000` on a phone when testing against a laptop.
enum HubPresets {
    static let localhost = URL(string: "http://127.0.0.1:4000")!
    static let localhostAlt = URL(string: "http://localhost:4000")!

    /// Common presets shown during hub setup.
    static var quickPicks: [(label: String, url: URL)] {
        var picks: [(String, URL)] = [
            ("This Mac (127.0.0.1)", localhost),
            ("This Mac (localhost)", localhostAlt),
        ]
        if let lan = lanURLFromDefaults() {
            picks.append(("Saved LAN hub", lan))
        }
        return picks
    }

    /// `tribe share` / manual paste can stash a hub URL here for testers.
    static func saveLANHub(_ url: URL) {
        UserDefaults.standard.set(url.absoluteString, forKey: Keys.lanHub)
    }

    static func lanURLFromDefaults() -> URL? {
        UserDefaults.standard.string(forKey: Keys.lanHub).flatMap(URL.init(string:))
    }

    private enum Keys {
        static let lanHub = "tribe.lanHubURL"
    }
}
