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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appState.interactions)
                .environmentObject(TribeService(state: appState))
        }
    }
}
