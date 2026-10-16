import Combine
import Foundation

/// Bill pages belong to one company, supplier, search and status filter.
@MainActor
final class SupplierDetailViewModel: ObservableObject {
    @Published private(set) var bills: [PurchaseBill] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMore = false
    @Published private(set) var loadError: String?
    @Published private(set) var pageError: String?
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var filter: String?
    @Published var search = ""

    let purchasesVM = PurchasesViewModel()
    typealias PageLoader = (Int, Int, String?, String, Int, Int) async throws -> [PurchaseBill]
    private let loadPage: PageLoader
    private let pageSize = 50
    private var generation = 0
    private var offset = 0
    private var identity: Query?

    private struct Query: Equatable {
        let companyID: Int
        let supplierID: Int
        let status: String?
        let search: String
    }

    init(loadPage: @escaping PageLoader = { company, supplier, status, search, limit, offset in
        try await PurchasesService().bills(companyID: company, supplierID: supplier,
            status: status, search: search, limit: limit, offset: offset)
    }) { self.loadPage = loadPage }

    func load(supplier: Supplier, refreshRelated: Bool = true, debounce: Bool = false) async {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return }
        generation += 1
        let request = generation
        let query = Query(companyID: companyID, supplierID: supplier.id, status: filter,
                          search: search.trimmingCharacters(in: .whitespacesAndNewlines))
        let needsTotals = refreshRelated || identity?.companyID != companyID || identity?.supplierID != supplier.id
        if identity != query { bills = [] }
        identity = query
        isLoading = true
        isLoadingMore = false
        hasMore = false
        loadError = nil
        pageError = nil
        defer { if request == generation { isLoading = false } }
        do {
            if debounce && !query.search.isEmpty { try await Task.sleep(for: .milliseconds(300)) }
            try Task.checkCancellation()
            async let totals: Void = needsTotals ? purchasesVM.load() : ()
            let page = try await loadPage(companyID, supplier.id, query.status, query.search, pageSize, 0)
            await totals
            guard request == generation, !Task.isCancelled else { return }
            bills = page
            offset = page.count
            hasMore = page.count == pageSize
        } catch {
            guard request == generation, !Task.isCancelled else { return }
            loadError = error.localizedDescription
        }
    }

    func loadMore(retry: Bool = false) async {
        guard let query = identity, query.companyID == SessionManager.shared.selectedCompanyId,
              hasMore, !isLoading, !isLoadingMore, pageError == nil || retry else { return }
        let request = generation
        isLoadingMore = true
        pageError = nil
        defer { if request == generation { isLoadingMore = false } }
        do {
            let page = try await loadPage(query.companyID, query.supplierID, query.status,
                query.search, pageSize, offset)
            guard request == generation, !Task.isCancelled else { return }
            let known = Set(bills.map(\.id))
            bills += page.filter { !known.contains($0.id) }
            offset += page.count
            hasMore = page.count == pageSize
        } catch {
            guard request == generation, !Task.isCancelled else { return }
            pageError = error.localizedDescription
        }
    }

    func cancelBill(id: Int) async {
        guard let companyID = identity?.companyID,
              companyID == SessionManager.shared.selectedCompanyId else { return }
        do { try await PurchasesService().cancelBill(companyID: companyID, billID: id) }
        catch { errorMessage = error.localizedDescription; showError = true }
    }
}
