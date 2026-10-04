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
    @Published var isLoadingMore = false
    @Published var hasMore = false
    /// The last page failed; the list offers another go rather than looking finished.
    @Published var loadMoreFailed = false

    /// One row per customer, counted by the server.
    @Published var summaries: [LedgerSummaryModel] = []
    /// The business's position across every customer, not just the loaded page.
    @Published var totals: CompanyLedgerTotals = .empty
    /// True when the figures could not be fetched, so the screen can say so rather than
    /// showing ₹0 as though nothing were owed.
    @Published var totalsFailed = false

    /// Customers per request.
    private static let pageSize = 50
    private var offset = 0
    private var requestID = 0

    var filteredEntries: [LedgerEntryModel] {
        guard !searchText.isEmpty else { return entries }
        
        return entries.filter {
            ($0.description ?? "").localizedCaseInsensitiveContains(searchText)
            || String($0.clientID).contains(searchText)
        }

    }
      
    
    // MARK: Fetch All Company Ledger
    //
    // One summary row per customer, from the server, rather than every ledger entry the
    // business has ever written grouped in the app. That download was the whole history
    // just to draw a list of names and balances, and grouping a page of it would have
    // given each customer the balance they happened to have part-way through.
    func fetchCompanyLedger() async {
        guard let companyId = SessionManager.shared.selectedCompanyId else {
            return
        }

        requestID += 1
        let request = requestID
        let search = searchText.trimmingCharacters(in: .whitespaces)
        isLoading = true
        offset = 0
        loadMoreFailed = false
        defer { isLoading = false }

        do {
            let page = try await LedgerService.shared.fetchCompanySummaries(
                companyID: companyId,
                search: search.isEmpty ? nil : search,
                limit: Self.pageSize,
                offset: 0
            )
            guard request == requestID else { return }
            summaries = page.rows
            totals = page.totals ?? .empty
            totalsFailed = page.totals == nil
            offset = page.rows.count
            hasMore = page.rows.count >= Self.pageSize
        } catch {
            guard request == requestID else { return }
            errorMessage = error.localizedDescription
            showAlert = true
        }
    }

    /// The next page of customers, asked for a few rows before the end.
    func loadMoreIfNeeded(currentItem client: ClientLedger) async {
        guard !isLoadingMore, !loadMoreFailed, hasMore else { return }
        guard let index = summaries.firstIndex(where: { $0.client_id == client.clientID }),
              index >= summaries.count - 5 else { return }
        await fetchNextPage()
    }

    func retryLoadMore() async {
        loadMoreFailed = false
        await fetchNextPage()
    }

    private func fetchNextPage() async {
        guard !isLoadingMore, let companyId = SessionManager.shared.selectedCompanyId else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let request = requestID
        let askedAt = offset
        let search = searchText.trimmingCharacters(in: .whitespaces)

        do {
            let page = try await LedgerService.shared.fetchCompanySummaries(
                companyID: companyId,
                search: search.isEmpty ? nil : search,
                limit: Self.pageSize,
                offset: askedAt
            )
            guard request == requestID, askedAt == offset else { return }
            let existing = Set(summaries.map(\.client_id))
            summaries.append(contentsOf: page.rows.filter { !existing.contains($0.client_id) })
            offset += page.rows.count
            hasMore = page.rows.count >= Self.pageSize
        } catch {
            guard request == requestID else { return }
            loadMoreFailed = true
        }
    }
    
    
    // MARK: Clients
    var clients: [ClientLedger] { summaries.map(\.asClientLedger) }

    // MARK: Search
    //
    // The search box is a query parameter now, so there is nothing to filter here: it
    // used to search only the customers whose entries had been downloaded.
    var filteredClients: [ClientLedger] { clients }

    // MARK: Totals
    //
    // From the server, over every customer. Summed from `clients` this was the
    // receivable of the customers that happened to have been loaded — a page — shown
    // as the business's total receivable.
    var totalReceivable: Double { totals.receivable }
    var totalPayable: Double { totals.payable }
}
