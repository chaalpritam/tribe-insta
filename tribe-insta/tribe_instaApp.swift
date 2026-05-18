//
//  tribe_instaApp.swift
//  tribe-insta
//
//  Created by chaalpritam on 14/05/26.
//

import SwiftUI

@main
struct tribe_instaApp: App {
    @StateObject private var appState = AppState()

    init() {
        ImageCache.configureURLCache()
        TabBarAppearance.apply()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appState.interactions)
                .environmentObject(TribeService(state: appState))
                .onOpenURL { url in
                    appState.openDeepLink(url)
                }
        }
    }
}
