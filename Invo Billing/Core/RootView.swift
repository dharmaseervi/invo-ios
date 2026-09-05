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
        Group {
            if session.isAuthenticated {
                if session.isUnlocked {
                    TabViewMain() // your main tab navigation
                } else {
                    BiometricLockView()
                }
            } else {
                AuthView() // shows login/signup
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
