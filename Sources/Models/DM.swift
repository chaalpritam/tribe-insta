import Foundation

/// One row from `/v1/dm/conversations/:tid`. The hub joins through
/// the `tids` table so each row already carries the peer's username
/// (when set) and last-message timestamp.
public struct DMConversation: Decodable, Identifiable, Hashable {
    public let id: String
    public let peerTid: String
    public let peerUsername: String?
    public let messageCount: Int
    public let unreadCount: Int
    public let lastMessageAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case peerTid = "peer_tid"
        case peerUsername = "peer_username"
        case messageCount = "message_count"
        case unreadCount = "unread_count"
        case lastMessageAt = "last_message_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.peerTid = try HubDecode.bigInt(c, forKey: .peerTid)
        self.peerUsername = try c.decodeIfPresent(String.self, forKey: .peerUsername)
        self.messageCount = HubDecode.intCount(c, forKey: .messageCount)
        self.unreadCount = HubDecode.intCount(c, forKey: .unreadCount)
        self.lastMessageAt = try HubDecode.dateIfPresent(c, forKey: .lastMessageAt)
    }

    public init(
        id: String,
        peerTid: String,
        peerUsername: String?,
        messageCount: Int = 0,
        unreadCount: Int = 0,
        lastMessageAt: Date? = nil
    ) {
        self.id = id
        self.peerTid = peerTid
        self.peerUsername = peerUsername
        self.messageCount = messageCount
        self.unreadCount = unreadCount
        self.lastMessageAt = lastMessageAt
    }
}

/// Hub 1:1 conversation id: `min(tid):max(tid)` as decimal strings.
public func dmConversationId(myTID: String, peerTID: String) -> String? {
    guard let a = Int64(myTID), let b = Int64(peerTID) else { return nil }
    let lo = min(a, b)
    let hi = max(a, b)
    return "\(lo):\(hi)"
}

/// One row from `/v1/dm/messages/:id`. Ciphertext + nonce decrypt
/// client-side using nacl.box.open with our DM private key and the
/// sender's pubkey.
public struct DMMessage: Decodable, Identifiable, Hashable {
    public let hash: String
    public let senderTid: String
    public let ciphertext: String
    public let nonce: String
    public let senderX25519: String?
    public let timestamp: Date

    public var id: String { hash }

    enum CodingKeys: String, CodingKey {
        case hash, ciphertext, nonce, timestamp
        case senderTid = "sender_tid"
        case senderX25519 = "sender_x25519"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hash = try c.decode(String.self, forKey: .hash)
        self.senderTid = try HubDecode.bigInt(c, forKey: .senderTid)
        self.ciphertext = try c.decode(String.self, forKey: .ciphertext)
        self.nonce = try c.decode(String.self, forKey: .nonce)
        self.senderX25519 = try c.decodeIfPresent(String.self, forKey: .senderX25519)
        self.timestamp = try HubDecode.date(c, forKey: .timestamp)
    }
}
