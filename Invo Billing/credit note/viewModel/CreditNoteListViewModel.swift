//
//  CreditNoteListViewModel.swift
//  Invo Billing
//
//  Created by dharmaseervi on 1/12/26.
//

import Foundation
import Combine
 
@MainActor
final class CreditNoteListViewModel: ObservableObject {
    
    // MARK: - State
    @Published var creditNotes: [CreditNoteModel] = []
    @Published var selectedCreditNote: CreditNoteDetailModel?
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let service = CreditNoteService.shared
    
    // MARK: - Fetch All Credit Notes
    func load() async {
        guard SessionManager.shared.selectedCompanyId != nil else {
            showError("No company selected")
            return
        }
        
        isLoading = true
        creditNotes = [] // ← ✅ clear stale data immediately
        defer { isLoading = false }
        
        do {
            creditNotes = try await service.fetchAll()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    // MARK: - Fetch Credit Note by ID
    func loadByID(_ id: Int) async {
        guard SessionManager.shared.selectedCompanyId != nil else {
            showError("No company selected")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            selectedCreditNote = try await service.fetchByID(
                id: id
            )
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    // MARK: - Helpers
    private func showError(_ message: String) {
        errorMessage = message
        showAlert = true
    }
}
