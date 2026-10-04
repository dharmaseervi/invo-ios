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
    
    @Published var isLoadingMore = false
    @Published var hasMore = false
    /// The last page failed; the list offers another go rather than looking finished.
    @Published var loadMoreFailed = false

    // MARK: - Dependencies
    private let service = CreditNoteService.shared

    /// Counts and amounts over everything that matches, from the server.
    @Published var summary: CreditNoteSummaryModel = .empty
    /// True when those figures could not be fetched, so the screen can say so instead
    /// of showing zeroes.
    @Published var summaryFailed = false

    /// What the screen is searching and filtering for, so a page continues the same
    /// query.
    private var activeSearch: String?
    private var activeType: String?

    /// Rows per request. The whole list used to arrive on every visit.
    private static let pageSize = 50
    private var offset = 0
    private var requestID = 0
    
    // MARK: - Fetch All Credit Notes
    func load(search: String? = nil, type: String? = nil) async {
        guard SessionManager.shared.selectedCompanyId != nil else {
            showError("No company selected")
            return
        }
        activeSearch = search
        activeType = type
        
        requestID += 1
        let request = requestID
        isLoading = true
        creditNotes = [] // ← ✅ clear stale data immediately
        offset = 0
        loadMoreFailed = false
        defer { isLoading = false }

        do {
            async let summaryResult = try? service.fetchSummary(search: search)
            let page = try await service.fetchAll(
                search: search, type: type, limit: Self.pageSize, offset: 0
            )
            let newSummary = await summaryResult
            guard request == requestID else { return }
            creditNotes = page
            offset = page.count
            hasMore = page.count >= Self.pageSize
            summary = newSummary ?? .empty
            summaryFailed = newSummary == nil
        } catch {
            guard request == requestID else { return }
            showError(error.localizedDescription)
        }
    }

    /// The next page, asked for a few rows before the end of the list.
    func loadMoreIfNeeded(currentItem note: CreditNoteModel) async {
        guard !isLoadingMore, !loadMoreFailed, hasMore else { return }
        guard let index = creditNotes.firstIndex(where: { $0.id == note.id }),
              index >= creditNotes.count - 5 else { return }
        await fetchNextPage()
    }

    /// Another go at the page that failed.
    func retryLoadMore() async {
        loadMoreFailed = false
        await fetchNextPage()
    }

    private func fetchNextPage() async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let request = requestID
        let askedAt = offset

        do {
            let page = try await service.fetchAll(
                search: activeSearch, type: activeType, limit: Self.pageSize, offset: askedAt
            )
            // Dropped if the list was reloaded while this was out.
            guard request == requestID, askedAt == offset else { return }
            let existing = Set(creditNotes.map(\.id))
            creditNotes.append(contentsOf: page.filter { !existing.contains($0.id) })
            offset += page.count
            hasMore = page.count >= Self.pageSize
        } catch {
            guard request == requestID else { return }
            // The offset is kept, so the rest stays reachable behind Try again.
            loadMoreFailed = true
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
