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
    
    var body: some View {
        Group {
             if session.isAuthenticated  {
                 TabViewMain() // your main tab navigation
            } else {
                AuthView() // shows login/signup
                    .environmentObject(authViewModel)
            }
        }
        .onAppear {
            session.loadTokenFromKeychain()
        }
    }
}
