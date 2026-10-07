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
    @Published var isLoadingMore = false
    @Published var hasMore = false
    /// The last page failed; the list offers another go rather than looking finished.
    @Published var loadMoreFailed = false

    /// The month and total figures, counted by the server over every expense.
    @Published var summary: ExpenseSummaryModel = .empty
    /// True when those figures could not be fetched, so the screen can say so rather
    /// than showing ₹0 as though nothing had been spent.
    @Published var summaryFailed = false

    /// Rows per request. The whole expense history used to arrive on every visit.
    private static let pageSize = 50
    private var offset = 0
    private var requestID = 0
    @Published var showAlert = false
    @Published var errorMessage: String?
    
    private let service = ExpenseService()
    private var companyId: Int { SessionManager.shared.selectedCompanyId ?? 0 }
 
   
    

    // MARK: - Fetch All Expenses
    @MainActor
    func fetchExpenses() async {
        requestID += 1
        let request = requestID
        isLoading = true
        errorMessage = nil
        offset = 0
        loadMoreFailed = false

        do {
            guard companyId > 0 else {
                errorMessage = "No company selected"
                showAlert = true
                isLoading = false
                return
            }

            async let summaryResult = try? service.getExpenseSummary(companyId: companyId)
            let page = try await service.getExpenses(
                companyId: companyId, limit: Self.pageSize, offset: 0
            )
            let newSummary = await summaryResult
            guard request == requestID else { return }
            expenses = page
            offset = page.count
            hasMore = page.count >= Self.pageSize
            summary = newSummary ?? .empty
            summaryFailed = newSummary == nil
        } catch {
            guard request == requestID else { return }
            errorMessage = error.localizedDescription
            showAlert = true
        }

        isLoading = false
    }

    /// The next page, asked for a few rows before the end of the list.
    @MainActor
    func loadMoreIfNeeded(currentItem expense: Expense) async {
        guard !isLoadingMore, !loadMoreFailed, hasMore else { return }
        guard let index = expenses.firstIndex(where: { $0.id == expense.id }),
              index >= expenses.count - 5 else { return }
        await fetchNextPage()
    }

    /// Another go at the page that failed.
    @MainActor
    func retryLoadMore() async {
        loadMoreFailed = false
        await fetchNextPage()
    }

    @MainActor
    private func fetchNextPage() async {
        guard !isLoadingMore, companyId > 0 else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let request = requestID
        let askedAt = offset

        do {
            let page = try await service.getExpenses(
                companyId: companyId, limit: Self.pageSize, offset: askedAt
            )
            // Dropped if the list was reloaded while this page was out.
            guard request == requestID, askedAt == offset else { return }
            let existing = Set(expenses.map(\.id))
            expenses.append(contentsOf: page.filter { !existing.contains($0.id) })
            offset += page.count
            hasMore = page.count >= Self.pageSize
        } catch {
            guard request == requestID else { return }
            // The offset is kept, so the older expenses stay reachable.
            loadMoreFailed = true
        }
    }
    
    // MARK: - Create Expense
    @MainActor
    func createExpense(
        name: String,
        amount: Double,
        description: String?,
        date: String,
        paymentMethod: String
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
                date: date,
                paymentMethod: paymentMethod
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
        date: String,
        paymentMethod: String
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let payload = ExpenseUpdatePayload(
                name: name.isEmpty ? nil : name,
                amount: amount > 0 ? amount : nil,
                description: description,
                date: date.isEmpty ? nil : date,
                paymentMethod: paymentMethod
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
