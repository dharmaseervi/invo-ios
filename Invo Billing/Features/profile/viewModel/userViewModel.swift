//
//  userViewModel.swift
//  invo
//
//  Created by dharmaseervi on 11/16/25.
//

import Combine
import Foundation
import SwiftUI

@MainActor
class UserViewModel: ObservableObject {
    
    @Published var profile: UserProfile?
    @Published var errorMessage: String?
    
    func loadProfile() async {
        do {
            profile = try await userService.shared.getUserProfile()
        } catch {
            errorMessage = error.localizedDescription
            
            // If unauthorized, logout the user
            if let urlErr = error as? URLError, urlErr.code == .userAuthenticationRequired {
                SessionManager.shared.logout()
            }
        }
    }
}
