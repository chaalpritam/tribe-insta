import Foundation
import TribeCore

/// Client for the ephemeral-rollup sequencer. Surfaces instant
/// follow-graph state and submits custody-signed follow/unfollow ops.
public final class ERClient {
    public let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// `{ exists, status }`. status is "active", "pending_follow",
    /// "pending_unfollow", or "unknown". UI uses this to render the
    /// Follow button as Following / Pending / Follow.
    public func link(
        followerTID: String,
        followingTID: String
    ) async throws -> ERLinkStatus {
        let url = baseURL.appendingPathComponent("v1/link/\(followerTID)/\(followingTID)")
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw HubError.invalidResponse
        }
        if http.statusCode == 404 || !(200..<300).contains(http.statusCode) {
            return ERLinkStatus(exists: false, status: "unknown")
        }
        return (try? JSONDecoder().decode(ERLinkStatus.self, from: data))
            ?? ERLinkStatus(exists: false, status: "unknown")
    }

    public func profile(_ tid: String) async throws -> ERProfile? {
        let url = baseURL.appendingPathComponent("v1/profile/\(tid)")
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return nil
        }
        return try? JSONDecoder().decode(ERProfile.self, from: data)
    }

    /// Submit a custody-signed follow to the ER sequencer.
    public func follow(
        followerTID: String,
        followingTID: String,
        custody: CustodyKey
    ) async throws {
        try await submitOperation("follow", followerTID: followerTID, followingTID: followingTID, custody: custody)
    }

    /// Submit a custody-signed unfollow to the ER sequencer.
    public func unfollow(
        followerTID: String,
        followingTID: String,
        custody: CustodyKey
    ) async throws {
        try await submitOperation("unfollow", followerTID: followerTID, followingTID: followingTID, custody: custody)
    }

    private func submitOperation(
        _ opType: String,
        followerTID: String,
        followingTID: String,
        custody: CustodyKey
    ) async throws {
        let timestamp = Int(Date().timeIntervalSince1970)
        let message = "tribe-er:\(opType):\(followerTID):\(followingTID):\(timestamp)"
        let messageBytes = Data(message.utf8)
        let signature = try custody.sign(messageBytes)
        let body: [String: Any] = [
            "followerTid": followerTID,
            "followingTid": followingTID,
            "custodyPubkey": custody.address,
            "signature": signature.base64EncodedString(),
            "timestamp": timestamp,
        ]
        let url = baseURL.appendingPathComponent("v1/\(opType)")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 15
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw HubError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw ERError.operationFailed(detail)
        }
    }
}

public enum ERError: LocalizedError {
    case operationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .operationFailed(let detail):
            return "Follow update failed: \(detail)"
        }
    }
}

public struct ERLinkStatus: Decodable {
    public let exists: Bool
    public let status: String

    public var isFollowing: Bool { exists && status == "active" }
    public var isPending: Bool {
        exists && (status == "pending_follow" || status == "pending_unfollow")
    }
    public var isPendingUnfollow: Bool { exists && status == "pending_unfollow" }
}

public struct ERProfile: Decodable {
    public let tid: Int64
    public let followingCount: Int
    public let followersCount: Int
}
