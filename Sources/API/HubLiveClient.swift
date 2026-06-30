import Foundation

/// Subscribes to the hub's `/v1/ws` stream for `new_message` and
/// `new_dm` events so the app can refresh badges without polling.
final class HubLiveClient: @unchecked Sendable {
    enum Event: Sendable {
        case connected
        case newMessage(hash: String, tid: String, type: Int?)
        case newDM(recipientTid: String?)
        case disconnected
    }

    private let queue = DispatchQueue(label: "tribe.hub.live")
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var onEvent: (@Sendable (Event) -> Void)?
    private var hubBaseURL: URL?

    func start(hubBaseURL: URL, onEvent: @escaping @Sendable (Event) -> Void) {
        queue.async {
            self.task?.cancel(with: .goingAway, reason: nil)
            self.task = nil
            self.onEvent = onEvent
            self.hubBaseURL = hubBaseURL
            self.openSocket()
        }
    }

    func stop() {
        queue.async {
            self.task?.cancel(with: .goingAway, reason: nil)
            self.task = nil
            self.session?.invalidateAndCancel()
            self.session = nil
            self.onEvent?(.disconnected)
            self.onEvent = nil
            self.hubBaseURL = nil
        }
    }

    func restartIfNeeded(hubBaseURL: URL) {
        queue.async {
            guard self.hubBaseURL != hubBaseURL || self.task == nil else { return }
            self.stop()
            guard let onEvent = self.onEvent else { return }
            self.start(hubBaseURL: hubBaseURL, onEvent: onEvent)
        }
    }

    private func openSocket() {
        guard let hubBaseURL, let onEvent else { return }
        guard let wsURL = Self.webSocketURL(from: hubBaseURL) else { return }

        let session = URLSession(configuration: .default)
        self.session = session
        let task = session.webSocketTask(with: wsURL)
        self.task = task
        task.resume()
        receive(on: task, onEvent: onEvent)
    }

    private func receive(
        on task: URLSessionWebSocketTask,
        onEvent: @escaping @Sendable (Event) -> Void
    ) {
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure:
                onEvent(.disconnected)
                self.queue.asyncAfter(deadline: .now() + 5) {
                    guard self.hubBaseURL != nil else { return }
                    self.openSocket()
                }
            case .success(let message):
                if case .string(let text) = message {
                    self.handle(text: text, onEvent: onEvent)
                }
                self.receive(on: task, onEvent: onEvent)
            }
        }
    }

    private func handle(text: String, onEvent: @escaping @Sendable (Event) -> Void) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String
        else { return }

        let payload = json["data"] as? [String: Any] ?? [:]
        switch event {
        case "connected":
            onEvent(.connected)
        case "new_message":
            let hash = payload["hash"] as? String ?? ""
            let tid = payload["tid"] as? String ?? ""
            let type = payload["type"] as? Int
            onEvent(.newMessage(hash: hash, tid: tid, type: type))
        case "new_dm":
            let recipient = payload["recipientTid"] as? String
            onEvent(.newDM(recipientTid: recipient))
        default:
            break
        }
    }

    private static func webSocketURL(from hub: URL) -> URL? {
        guard var parts = URLComponents(url: hub, resolvingAgainstBaseURL: false) else {
            return nil
        }
        switch parts.scheme?.lowercased() {
        case "https": parts.scheme = "wss"
        case "http": parts.scheme = "ws"
        case "wss", "ws": break
        default: return nil
        }
        parts.path = ""
        parts.query = nil
        parts.fragment = nil
        guard let base = parts.url else { return nil }
        return base.appendingPathComponent("v1/ws")
    }
}
