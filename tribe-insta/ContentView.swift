import SwiftUI

/// Routes between Onboarding and the main TabView based on whether
/// we have a provisioned identity in AppState.
struct ContentView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        switch state.phase {
        case .onboarding:
            ConnectFlow()
                .tint(Theme.primary)
        case .ready:
            RootView()
                .background { HubLiveSession() }
        }
    }
}

#Preview("Onboarding") {
    ContentView()
        .environmentObject({
            let s = AppState()
            return s
        }())
        .environmentObject(TribeService(state: AppState()))
}
