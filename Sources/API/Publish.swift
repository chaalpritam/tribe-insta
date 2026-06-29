import Foundation
import TribeCore

/// Hub write paths. Every protocol-state-changing action on the
/// network goes through `POST /v1/submit` carrying a signed envelope
/// (or a dedicated route like `/v1/upload`, `/v1/dm/send`, etc.).
///
/// Trimmed port from tribe-twitter — keeps only what an IG-shaped client
/// needs: media upload, post create/delete, reply (via parent_hash),
/// like / unlike, bookmark / unbookmark. Skips retweets, polls,
/// events, tasks, crowdfunds, off-chain tips, DMs, channel
/// create/join/leave, on-chain profile updates — those surfaces don't
/// exist on tribe-insta yet (and several won't ever, since they're
/// not IG-shaped concepts).
extension HubClient {
    /// POST a binary blob to /v1/upload. Returns the SHA-256 hex hash
    /// the hub assigned, which callers stitch into a tweet's `embeds`
    /// array as `"media:<hash>"`. Hub enforces ≤5 MB and only accepts
    /// the four common image MIME types — caller is responsible for
    /// downscaling / re-encoding before calling. Constructs a minimal
    /// multipart/form-data body by hand to avoid pulling in a
    /// dependency just for one call.
    func uploadMedia(data: Data, contentType: String, filename: String = "upload") async throws -> String {
        let boundary = "----TribeInstaBoundary-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n"
                .data(using: .utf8)!
        )
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/upload"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60
        request.httpBody = body

        let (respData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HubError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw HubError.statusCode(http.statusCode, body: String(data: respData, encoding: .utf8) ?? "")
        }
        struct Reply: Decodable { let hash: String }
        let reply = try JSONDecoder().decode(Reply.self, from: respData)
        return reply.hash
    }

    /// POST a signed envelope to /v1/submit. Returns the new content
    /// hash the hub assigned (base64). Throws `HubError.statusCode`
    /// with the hub's error body on rejection.
    @discardableResult
    func submit(envelope: Data) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/submit"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        request.httpBody = envelope

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HubError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw HubError.statusCode(http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }

        struct Reply: Decodable { let hash: String? }
        if let reply = try? JSONDecoder().decode(Reply.self, from: data), let h = reply.hash {
            return h
        }
        return ""
    }

    // MARK: - Posts (Tweet envelopes)

    /// Publish a tweet. For an IG-shaped post the caller fills `embeds`
    /// with `"media:<hash>"` references from prior `uploadMedia` calls.
    /// `parentHash` makes the tweet a reply (used for IG comments) and
    /// `channelId` defaults to the reserved "general" channel — every
    /// TWEET_ADD has to belong to one, matching tribe-app's composer.
    ///
    /// Phase 3 extensions: `postKind` ('photo' or 'reel'), `location`,
    /// `audioTitle`. All optional — older clients omit them. The hub
    /// validates the post_kind whitelist and length-caps location +
    /// audio_title in submit.ts.
    @discardableResult
    func publishTweet(
        text: String,
        as appKey: AppKey,
        tid: String,
        parentHash: String? = nil,
        channelId: String? = nil,
        embeds: [String]? = nil,
        postKind: String? = nil,
        location: String? = nil,
        audioTitle: String? = nil
    ) async throws -> String {
        var body: [String: Any] = [
            "text": text,
            "channel_id": channelId ?? "general",
        ]
        if let parentHash { body["parent_hash"] = parentHash }
        if let embeds, !embeds.isEmpty { body["embeds"] = embeds }
        if let postKind, !postKind.isEmpty { body["post_kind"] = postKind }
        if let location, !location.isEmpty { body["location"] = location }
        if let audioTitle, !audioTitle.isEmpty { body["audio_title"] = audioTitle }
        let envelope = try MessageSigner.sign(
            type: MessageType.tweetAdd.rawValue,
            tid: tid,
            body: body,
            appKey: appKey
        )
        return try await submit(envelope: envelope)
    }

    /// Publish a reel. Sugar over `publishTweet` that hard-codes
    /// `post_kind='reel'` and requires exactly one video embed from a
    /// prior `uploadMedia` call. caption + audioTitle + location all
    /// optional.
    @discardableResult
    func publishReel(
        videoEmbed: String,
        as appKey: AppKey,
        tid: String,
        caption: String = "",
        audioTitle: String? = nil,
        location: String? = nil,
        channelId: String? = nil
    ) async throws -> String {
        try await publishTweet(
            text: caption,
            as: appKey,
            tid: tid,
            channelId: channelId,
            embeds: [videoEmbed],
            postKind: "reel",
            location: location,
            audioTitle: audioTitle
        )
    }

    // MARK: - Stories

    /// Publish a story (STORY_ADD). `mediaHash` is the 64-char hex
    /// hash returned by /v1/upload — same format used for tweet embeds,
    /// passed bare (not wrapped in "media:") because the hub stores it
    /// as a column on the stories table rather than an embeds array.
    @discardableResult
    func publishStory(
        mediaHash: String,
        as appKey: AppKey,
        tid: String,
        caption: String? = nil,
        music: String? = nil
    ) async throws -> String {
        var body: [String: Any] = ["media_hash": mediaHash]
        if let caption, !caption.isEmpty { body["caption"] = caption }
        if let music, !music.isEmpty { body["music"] = music }
        let envelope = try MessageSigner.sign(
            type: MessageType.storyAdd.rawValue,
            tid: tid,
            body: body,
            appKey: appKey
        )
        return try await submit(envelope: envelope)
    }

    /// Mark a story as viewed (STORY_VIEW). Idempotent — re-viewing
    /// keeps the original (story_hash, viewer_tid) row on the hub.
    @discardableResult
    func viewStory(
        storyHash: String,
        as appKey: AppKey,
        tid: String
    ) async throws -> String {
        let envelope = try MessageSigner.sign(
            type: MessageType.storyView.rawValue,
            tid: tid,
            body: ["story_hash": storyHash],
            appKey: appKey
        )
        return try await submit(envelope: envelope)
    }

    /// Push a single profile field (USER_DATA_ADD type 7).
    @discardableResult
    func updateProfile(
        field: String,
        value: String,
        as appKey: AppKey,
        tid: String
    ) async throws -> String {
        let envelope = try MessageSigner.sign(
            type: MessageType.userDataAdd.rawValue,
            tid: tid,
            body: ["field": field, "value": value],
            appKey: appKey
        )
        return try await submit(envelope: envelope)
    }

    @discardableResult
    func deleteTweet(
        hash: String,
        as appKey: AppKey,
        tid: String
    ) async throws -> String {
        let envelope = try MessageSigner.sign(
            type: MessageType.tweetRemove.rawValue,
            tid: tid,
            body: ["target_hash": hash],
            appKey: appKey
        )
        return try await submit(envelope: envelope)
    }

    // MARK: - Reactions

    /// REACTION subtypes recognized by the hub. tribe-insta only uses
    /// `like` (mapped from the heart button) — `retweet` exists in
    /// tribe-twitter but doesn't have an IG-shaped surface here.
    ///
    /// Note: REACTION_REMOVE on the hub clears EVERY reaction the user
    /// has on a target regardless of subtype, but in this client only
    /// like is ever sent so that's fine in practice.
    enum ReactionSubtype: Int {
        case like = 1
    }

    /// Like a post (REACTION_ADD with body.type = 1).
    @discardableResult
    func likeTweet(
        hash: String,
        as appKey: AppKey,
        tid: String
    ) async throws -> String {
        try await react(targetHash: hash, subtype: .like, add: true, as: appKey, tid: tid)
    }

    @discardableResult
    func unlikeTweet(
        hash: String,
        as appKey: AppKey,
        tid: String
    ) async throws -> String {
        try await react(targetHash: hash, subtype: .like, add: false, as: appKey, tid: tid)
    }

    /// Internal: build + submit a signed REACTION envelope. Wire body
    /// shape is `{type: <subtype>, target_hash: <hash>}` — flat —
    /// matching what the hub's submit.ts validates against. Subtype is
    /// included on REMOVE too so the wire shape stays consistent even
    /// though the hub ignores it on remove.
    @discardableResult
    private func react(
        targetHash hash: String,
        subtype: ReactionSubtype,
        add: Bool,
        as appKey: AppKey,
        tid: String
    ) async throws -> String {
        let envelope = try MessageSigner.sign(
            type: (add ? MessageType.reactionAdd : MessageType.reactionRemove).rawValue,
            tid: tid,
            body: ["type": subtype.rawValue, "target_hash": hash],
            appKey: appKey
        )
        return try await submit(envelope: envelope)
    }

    // MARK: - Bookmarks

    @discardableResult
    func bookmark(
        hash: String,
        as appKey: AppKey,
        tid: String,
        add: Bool
    ) async throws -> String {
        let type = add ? MessageType.bookmarkAdd : MessageType.bookmarkRemove
        let envelope = try MessageSigner.sign(
            type: type.rawValue,
            tid: tid,
            body: ["target_hash": hash],
            appKey: appKey
        )
        return try await submit(envelope: envelope)
    }

    // MARK: - DMs

    /// Register our x25519 pubkey with the hub so other clients can
    /// encrypt DMs to this TID. Idempotent — overwrites any prior key.
    /// Posts to the dedicated /v1/dm/register-key route (validates the
    /// envelope the same way /v1/submit does but writes to the
    /// dm_keys table directly).
    @discardableResult
    func registerDMKey(
        publicKey x25519Pub: Data,
        as appKey: AppKey,
        tid: String
    ) async throws -> Data {
        let envelope = try MessageSigner.sign(
            type: MessageType.dmKeyRegister.rawValue,
            tid: tid,
            body: ["x25519_pubkey": x25519Pub.base64EncodedString()],
            appKey: appKey
        )
        return try await postRaw(path: "v1/dm/register-key", envelope: envelope)
    }

    /// Send an encrypted DM. Caller is responsible for producing the
    /// ciphertext (`nacl.box(plaintext, nonce, recipientPub, ourPriv)`)
    /// and the matching 24-byte nonce.
    @discardableResult
    func sendDM(
        recipientTID: String,
        ciphertext: Data,
        nonce: Data,
        senderX25519: Data,
        as appKey: AppKey,
        tid: String
    ) async throws -> Data {
        let body: [String: Any] = [
            "recipient_tid": recipientTID.numericIfFitsInt(),
            "ciphertext": ciphertext.base64EncodedString(),
            "nonce": nonce.base64EncodedString(),
            "sender_x25519": senderX25519.base64EncodedString(),
        ]
        let envelope = try MessageSigner.sign(
            type: MessageType.dmSend.rawValue,
            tid: tid,
            body: body,
            appKey: appKey
        )
        return try await postRaw(path: "v1/dm/send", envelope: envelope)
    }

    /// Internal — POST a signed envelope to a non-/v1/submit route
    /// and return the raw response body so the caller can parse the
    /// route-specific reply (e.g. the conversation_id for DM_SEND).
    private func postRaw(path: String, envelope: Data) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        request.httpBody = envelope

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HubError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw HubError.statusCode(http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }
}

private extension String {
    /// Mirror of tribe-twitter's numericIfFitsInt — hub serializes BIGINT
    /// TIDs as numbers when in safe range and strings otherwise.
    func numericIfFitsInt() -> Any {
        if let n = Int64(self), abs(n) < 9_007_199_254_740_992 {
            return n
        }
        return self
    }
}
