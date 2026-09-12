//
//  invoApp.swift
//  invo
//
//  Created by dharmaseervi on 11/11/25.
//

import SwiftUI

@main
struct invoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject var session = SessionManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                .environmentObject(session)
                .tint(Color.sAccent)
                .onChange(of: session.isAuthenticated) { isAuthenticated in
                    if isAuthenticated {
                        // Not a permission prompt: only re-registers a token when the
                        // person has already agreed. The ask lives in Settings.
                        Task { await PushNotificationManager.shared.registerIfAlreadyAuthorized() }
                    }
                }
        }
    }
}
