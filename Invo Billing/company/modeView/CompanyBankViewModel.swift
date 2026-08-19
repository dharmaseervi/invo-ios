//
//  CompanyBankViewModel.swift
//  Invo Billing
//
//  Created by dharmaseervi on 2/18/26.
//


//
//  CompanyBankViewModel.swift
//  invo
//

import Foundation
import SwiftUI
import Combine

@MainActor
class CompanyBankViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var banks: [CompanyBankResponse] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // MARK: - Dependencies
    
    private let service = CompanyBankService()
    
    // MARK: - Load Banks
    
    func loadBanks(companyId: Int) async {
        await MainActor.run { self.isLoading = true }
        
        do {
            // 2. This now receives the [CompanyBankResponse] array
            let fetchedBanks = try await service.getCompanyBanks(companyId: companyId)
            
            await MainActor.run {
                self.banks = fetchedBanks
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                print("❌ ViewModel Error: \(error.localizedDescription)")
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Create Bank
    
    func createBank(companyId: Int, dto: CompanyBankRequestDTO) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let success = try await service.createBank(companyId: companyId, payload: dto)
            if success {
                await loadBanks(companyId: companyId)
            }
            return success
        } catch {
            handle(error)
            return false
        }
    }
    
    // MARK: - Update Bank
    
    func updateBank(companyId: Int, bankId: Int, dto: CompanyBankRequestDTO) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let success = try await service.updateBank(companyId: companyId, bankId: bankId, payload: dto)
            if success {
                await loadBanks(companyId: companyId)
            }
            return success
        } catch {
            handle(error)
            return false
        }
    }
    
    // MARK: - Delete Bank
    
    func deleteBank(companyId: Int, bankId: Int) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let success = try await service.deleteBank(companyId: companyId, bankId: bankId)
            if success {
                banks.removeAll { $0.id == bankId }
            }
        } catch {
            handle(error)
        }
    }
    
    // MARK: - Set Default
    
    func setDefaultBank(companyId: Int, bankId: Int) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let success = try await service.setDefaultBank(companyId: companyId, bankId: bankId)
            if success {
                await loadBanks(companyId: companyId)
            }
        } catch {
            handle(error)
        }
    }
    
    // MARK: - Error Handler
    
    private func handle(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        print("❌ CompanyBankViewModel Error:", error.localizedDescription)
    }
}
