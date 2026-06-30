import SwiftUI

/// Keeps a hub WebSocket open while the user is signed in so badge
/// counts and the home feed update without the 60s poll timer.
struct HubLiveSession: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var service: TribeService

    @State private var client = HubLiveClient()

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear { syncConnection() }
            .onChange(of: state.phase) { _, _ in syncConnection() }
            .onChange(of: state.hubBaseURL) { _, _ in syncConnection() }
            .onDisappear { client.stop() }
    }

    private func syncConnection() {
        guard state.phase == .ready else {
            client.stop()
            return
        }
        let hub = state.hubBaseURL
        client.start(hubBaseURL: hub) { event in
            Task { @MainActor in
                switch event {
                case .connected:
                    await state.refreshBadgeCounts()
                case .newMessage:
                    service.notifyFeedChanged()
                    await state.refreshBadgeCounts()
                case .newDM:
                    await state.refreshBadgeCounts()
                case .disconnected:
                    break
                }
            }
        }
    }
}
