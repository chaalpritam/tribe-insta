import Foundation

/// In-app routes from `tribeinsta://` links and shared hub URLs.
enum DeepLink: Equatable, Identifiable, Hashable {
    case post(hash: String)
    case profile(tid: String)

    var id: String {
        switch self {
        case .post(let hash): return "post-\(hash)"
        case .profile(let tid): return "profile-\(tid)"
        }
    }
}

enum DeepLinkParser {
    /// `tribeinsta://post/<hash>`, `tribeinsta://profile/<tid>`, or
    /// `https://<hub>/v1/tweet/<hash>` from ShareLink.
    static func parse(_ url: URL) -> DeepLink? {
        if url.scheme?.lowercased() == "tribeinsta" {
            return parseCustomScheme(url)
        }
        if let host = url.host, url.path.hasPrefix("/v1/tweet/") {
            let hash = String(url.path.dropFirst("/v1/tweet/".count))
            if !hash.isEmpty { return .post(hash: hash) }
        }
        if url.scheme == "http" || url.scheme == "https" {
            return parseCustomScheme(url) ?? parseHubPath(url)
        }
        return nil
    }

    private static func parseCustomScheme(_ url: URL) -> DeepLink? {
        let host = (url.host ?? "").lowercased()
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        switch host {
        case "post":
            if path.isEmpty, let q = url.queryItem(named: "hash"), !q.isEmpty {
                return .post(hash: q)
            }
            return path.isEmpty ? nil : .post(hash: path)
        case "profile", "user":
            if path.isEmpty, let q = url.queryItem(named: "tid"), !q.isEmpty {
                return .profile(tid: q)
            }
            return path.isEmpty ? nil : .profile(tid: path)
        default:
            return nil
        }
    }

    private static func parseHubPath(_ url: URL) -> DeepLink? {
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count >= 3, parts[0] == "v1" else { return nil }
        if parts[1] == "tweet", !parts[2].isEmpty {
            return .post(hash: parts[2])
        }
        if parts[1] == "user", !parts[2].isEmpty {
            return .profile(tid: parts[2])
        }
        return nil
    }
}

private extension URL {
    func queryItem(named name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }
}
