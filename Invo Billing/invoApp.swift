//
//  invoApp.swift
//  invo
//
//  Created by dharmaseervi on 11/11/25.
//

import SwiftUI

@main
struct invoApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject var session = SessionManager.shared
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                .environmentObject(session) 
                .onAppear {
                    session.loadTokenFromKeychain()
                }
        }
    }
}
