//
//  RootView.swift
//  invo
//
//  Created by dharmaseervi on 11/15/25.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var session: SessionManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "startScreen") == "invoice100" {
            NavigationStack { DebugInvoice100View() }
        } else {
            authenticatedRoot
        }
        #else
        authenticatedRoot
        #endif
    }

    private var authenticatedRoot: some View {
        Group {
            if !session.sessionReady {
                // Blank screen in the app's background color while keychain is read.
                // Prevents the one-frame flash of the login screen on every launch
                // when the user already has a valid session.
                Color.sBackground.ignoresSafeArea()
            } else if session.isAuthenticated {
                if session.isUnlocked {
                    TabViewMain()
                } else {
                    BiometricLockView()
                }
            } else {
                AuthView()
                    .environmentObject(authViewModel)
            }
        }
        .onAppear {
            session.loadTokenFromKeychain()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                session.lock()
            }
        }
    }
}
