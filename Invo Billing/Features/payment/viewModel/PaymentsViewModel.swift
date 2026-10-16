//
//  PaymentsViewModel.swift
//  Invo Billing
//

import Combine
import Foundation

@MainActor
final class PaymentsViewModel: ObservableObject {

    @Published private(set) var payments: [PaymentHistoryRow] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isWorking = false
    @Published private(set) var hasMore = false
    @Published private(set) var loadMoreFailed = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var loadError: String?
    @Published var search = ""
    @Published var method = ""
    @Published var clientID: Int?
    @Published var clientName = ""
    @Published var startDate: Date?
    @Published var endDate: Date?

    struct Query: Equatable, Hashable {
        let companyID: Int?
        let search: String
        let method: String
        let clientID: Int?
        let start: String?
        let end: String?
    }
    var query: Query {
        Query(companyID: SessionManager.shared.selectedCompanyId,
              search: search.trimmingCharacters(in: .whitespacesAndNewlines), method: method,
              clientID: clientID, start: startDate.map(AppDate.wireString), end: endDate.map(AppDate.wireString))
    }
    var hasFilters: Bool { !search.isEmpty || !method.isEmpty || clientID != nil || startDate != nil }
    private var loadedQuery: Query?

    @Published var errorMessage: String?
    @Published var showError = false
    @Published var message: String?

    /// The invoices a payment can be moved onto: everything the customer still owes on.
    @Published private(set) var movableInvoices: [InvoiceSummaryModel] = []
    @Published private(set) var isLoadingInvoices = false

    private let service = PaymentCorrectionService()
    private let invoiceService = InvoiceService()

    private static let pageSize = 50
    private var offset = 0
    private var requestID = 0

    // MARK: - Loading

    func load(debounce: Bool = false) async {
        guard let companyID = SessionManager.shared.selectedCompanyId else {
            show("Select a company first.")
            return
        }

        requestID += 1
        let request = requestID
        let next = query
        if loadedQuery != next { payments = [] }
        loadedQuery = next
        isLoading = true
        isLoadingMore = false
        offset = 0
        hasMore = false
        loadMoreFailed = false
        loadError = nil
        defer { if request == requestID { isLoading = false } }

        do {
            if debounce && !next.search.isEmpty { try await Task.sleep(for: .milliseconds(300)) }
            try Task.checkCancellation()
            let page = try await service.history(companyID: companyID, limit: Self.pageSize,
                search: next.search, start: next.start, end: next.end, clientID: next.clientID, method: next.method)
            guard request == requestID else { return }
            payments = page
            offset = page.count
            hasMore = page.count >= Self.pageSize
        } catch {
            guard request == requestID else { return }
            guard !Task.isCancelled else { return }
            loadError = error.localizedDescription
        }
    }

    func loadMoreIfNeeded(currentItem payment: PaymentHistoryRow) async {
        guard !isLoading, !isLoadingMore, !loadMoreFailed, hasMore,
              let loadedQuery, let companyID = loadedQuery.companyID,
              companyID == SessionManager.shared.selectedCompanyId,
              let index = payments.firstIndex(where: { $0.id == payment.id }),
              index >= payments.count - 5
        else { return }

        let request = requestID
        let askedAt = offset
        isLoadingMore = true
        defer { if request == requestID { isLoadingMore = false } }

        do {
            let page = try await service.history(
                companyID: companyID, limit: Self.pageSize, offset: askedAt,
                search: loadedQuery.search, start: loadedQuery.start, end: loadedQuery.end,
                clientID: loadedQuery.clientID, method: loadedQuery.method
            )
            guard request == requestID, askedAt == offset else { return }
            let existing = Set(payments.map(\.id))
            payments.append(contentsOf: page.filter { !existing.contains($0.id) })
            offset += page.count
            hasMore = page.count >= Self.pageSize
        } catch {
            guard request == requestID else { return }
            loadMoreFailed = true
        }
    }

    func retryLoadMore() async {
        loadMoreFailed = false
        if let last = payments.last {
            await loadMoreIfNeeded(currentItem: last)
        }
    }

    // MARK: - Corrections

    func reverse(_ payment: PaymentHistoryRow, reason: String) async {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            try await service.reverse(companyID: companyID, paymentID: payment.id, reason: reason)
            message = "Payment reversed."
            await load()
        } catch {
            show(error.localizedDescription)
        }
    }

    /// The invoices this customer still owes on, for moving a payment.
    func loadInvoices(for payment: PaymentHistoryRow) async {
        isLoadingInvoices = true
        defer { isLoadingInvoices = false }
        movableInvoices = []

        do {
            guard let companyID = SessionManager.shared.selectedCompanyId else { return }
            movableInvoices = try await invoiceService.fetchUnpaidInvoices(
                clientID: payment.client_id, companyID: companyID
            )
        } catch {
            show(error.localizedDescription)
        }
    }

    func move(_ payment: PaymentHistoryRow, to allocations: [(invoiceID: Int, amount: Double)]) async -> Bool {
        guard payment.canMove, let companyID = SessionManager.shared.selectedCompanyId else { return false }
        isWorking = true
        defer { isWorking = false }

        do {
            try await service.reallocate(
                companyID: companyID, paymentID: payment.id, allocations: allocations
            )
            message = allocations.isEmpty
                ? "Payment moved to the customer's account."
                : "Payment moved."
            await load()
            return true
        } catch {
            show(error.localizedDescription)
            return false
        }
    }

    func refund(_ request: RefundRequestDTO) async -> Bool {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return false }
        isWorking = true
        defer { isWorking = false }

        do {
            try await service.refund(companyID: companyID, request: request)
            message = "Refund recorded."
            await load()
            return true
        } catch {
            show(error.localizedDescription)
            return false
        }
    }

    func clearFilters() {
        search = ""; method = ""; clientID = nil; clientName = ""; startDate = nil; endDate = nil
    }

    private func show(_ text: String) {
        errorMessage = text
        showError = true
    }
}
