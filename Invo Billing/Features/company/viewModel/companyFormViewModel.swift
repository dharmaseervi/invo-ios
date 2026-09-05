//
//  companyFormViewModel.swift
//  invo
//
//  Created by dharmaseervi on 11/17/25.
//

import Combine
import Foundation
import SwiftUI

@MainActor
class CompanyFormViewModel: ObservableObject {

    // Form fields
    @Published var name = ""
    @Published var phone = ""
    @Published var address = ""
    @Published var city = ""
    @Published var pincode = ""
    @Published var state = ""
    @Published var gst = ""

    // UI state
    @Published var isSaving = false
    @Published var errorMessage: String? = nil

    @Published var companies: [CompanyResponse] = []

    @Published var isLoading: Bool = false
    private let service = CompanyService()

    // basic validation
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Save company to backend
    func saveCompany() async -> Bool {
        guard isValid else { return false }
        
        isSaving = true
        defer { isSaving = false }
        
        let payload = CompanyRequestDTO(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone,
            address: address,
            gst: gst,
            city: city,
            state: state,
            pincode: pincode
        )
        
        if IndianStates.defaultState.isEmpty && !state.isEmpty {
            IndianStates.defaultState = state
        }

        do {
            // Try to get company ID directly from creation response
            if let newCompanyID = try await service.createCompany(payload: payload) {
                await MainActor.run {
                    SessionManager.shared.selectedCompanyId = newCompanyID
                    SessionManager.saveSelectedCompanyId(newCompanyID)
                    print("✅ Auto-selected new company ID: \(newCompanyID)")
                }
                return true
            }
            
            // Fallback — fetch all companies and select latest
            let companies = try await service.getMyCompany()
            if let newest = companies?.last {
                await MainActor.run {
                    SessionManager.shared.selectedCompanyId = newest.id
                    SessionManager.saveSelectedCompanyId(newest.id)
                    print("✅ Auto-selected company: \(newest.name) (ID: \(newest.id))")
                }
            }
            
            return true
            
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func loadCompanies() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await service.getMyCompany()
            self.companies = result ?? []

        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
