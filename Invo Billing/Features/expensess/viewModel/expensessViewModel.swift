//
//  ExpenseViewModel.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/19/25.
//

import SwiftUI
import Combine

class ExpenseViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var errorMessage: String?
    
    private let service = ExpenseService()
    private var companyId: Int { SessionManager.shared.selectedCompanyId ?? 0 }
 
   
    

    // MARK: - Fetch All Expenses
    @MainActor
    func fetchExpenses() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard companyId > 0 else {
                errorMessage = "No company selected"
                showAlert = true
                isLoading = false
                return
            }
            
            expenses = try await service.getExpenses(companyId: companyId)
        } catch {
            errorMessage = error.localizedDescription
            showAlert = true
        }
        
        isLoading = false
    }
    
    // MARK: - Create Expense
    @MainActor
    func createExpense(
        name: String,
        amount: Double,
        description: String?,
        date: String
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            guard companyId > 0 else {
                errorMessage = "No company selected"
                showAlert = true
                isLoading = false
                return false
            }
            
            let payload = ExpenseCreatePayload(
                companyId: companyId,
                name: name,
                amount: amount,
                description: description,
                date: date
            )
            
            let success = try await service.createExpense(payload: payload)
            
            if success {
                // Refresh the list
                await fetchExpenses()
                return true
            }
            return false
        } catch {
            errorMessage = error.localizedDescription
            showAlert = true
            isLoading = false
            return false
        }
    }
    
    // MARK: - Update Expense
    @MainActor
    func updateExpense(
        id: Int,
        name: String,
        amount: Double,
        description: String?,
        date: String
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let payload = ExpenseUpdatePayload(
                name: name.isEmpty ? nil : name,
                amount: amount > 0 ? amount : nil,
                description: description,
                date: date.isEmpty ? nil : date
            )
            let success = try await service.updateExpense(id: id, payload: payload)
            
            if success {
                // Refresh the list
                await fetchExpenses()
                return true
            }
            return false
        } catch {
            errorMessage = error.localizedDescription
            showAlert = true
            isLoading = false
            return false
        }
    }
    
    // MARK: - Delete Expense
    @MainActor
    func deleteExpense(id: Int) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let success = try await service.deleteExpense(id: id)
            
            if success {
                // Refresh the list
                await fetchExpenses()
            }
        } catch {
            errorMessage = error.localizedDescription
            showAlert = true
        }
        
        isLoading = false
    }
    
    // MARK: - Fetch Single Expense
    @MainActor
    func fetchExpenseById(id: Int) async -> Expense? {
        do {
            return try await service.getExpenseById(id: id)
        } catch {
            errorMessage = error.localizedDescription
            showAlert = true
            return nil
        }
    }
    
    // MARK: - Fetch by Date Range
    @MainActor
    func fetchExpensesByDateRange(startDate: String, endDate: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard companyId > 0 else {
                errorMessage = "No company selected"
                showAlert = true
                isLoading = false
                return
            }
            
            expenses = try await service.getExpensesByDateRange(
                companyId: companyId,
                startDate: startDate,
                endDate: endDate
            )
        } catch {
            errorMessage = error.localizedDescription
            showAlert = true
        }
        
        isLoading = false
    }
    
    // MARK: - Get Statistics
    @MainActor
    func getExpenseStats() async -> ExpenseStatsResponse.ExpenseStats? {
        do {
            guard companyId > 0 else {
                errorMessage = "No company selected"
                return nil
            }
            
            let response = try await service.getExpenseStats(companyId: companyId)
            return response.stats
        } catch {
            errorMessage = error.localizedDescription
            showAlert = true
            return nil
        }
    }
}
