//
//  tribe_instaApp.swift
//  tribe-insta
//
//  Created by chaalpritam on 14/05/26.
//

import SwiftUI

@main
struct tribe_instaApp: App {
    @StateObject private var appState: AppState
    @StateObject private var tribeService: TribeService

    init() {
        let state = AppState()
        _appState = StateObject(wrappedValue: state)
        _tribeService = StateObject(wrappedValue: TribeService(state: state))
        ImageCache.configureURLCache()
        TabBarAppearance.apply()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appState.interactions)
                .environmentObject(tribeService)
                .onOpenURL { url in
                    appState.openDeepLink(url)
                }
        }
    }
}
