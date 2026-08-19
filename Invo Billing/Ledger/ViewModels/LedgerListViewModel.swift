//
//  LedgerListViewModel.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/31/25.
//

import Combine
import Foundation


@MainActor
final class LedgerListViewModel: ObservableObject {
    
    @Published var entries: [LedgerEntryModel] = []
    @Published var searchText: String = ""
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var errorMessage: String?
    
    
    var filteredEntries: [LedgerEntryModel] {
        guard !searchText.isEmpty else { return entries }
        
        return entries.filter {
            ($0.description ?? "").localizedCaseInsensitiveContains(searchText)
            || String($0.clientID).contains(searchText)
        }

    }
      
    
    // MARK: Fetch All Company Ledger
    func fetchCompanyLedger() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let companyId = SessionManager.shared.selectedCompanyId else {
            return
        }
        
        do {
            entries = try await LedgerService.shared.fetchCompanyLedger(companyID: companyId)
        } catch {
            print(error)
        }
    }
    
    
    // MARK: Grouped Clients
    var clients: [ClientLedger] {
        let grouped = Dictionary(grouping: entries, by: { $0.clientID })
        
        return grouped.map { (clientID, entries) in
            let debit = entries.reduce(0) { $0 + $1.debit }
            let credit = entries.reduce(0) { $0 + $1.credit }
            let balance = entries.last?.balance ?? 0
            let name = entries.first?.clientName ?? "Unknown"
            
            return ClientLedger(
                id: clientID,
                clientID: clientID,
                clientName: name,
                totalDebit: debit,
                totalCredit: credit,
                balance: balance
            )
        }
    }
    
    // MARK: Search
    var filteredClients: [ClientLedger] {
        if searchText.isEmpty {
            return clients
        }
        
        return clients.filter {
            String($0.clientID).contains(searchText)
        }
    }
}
