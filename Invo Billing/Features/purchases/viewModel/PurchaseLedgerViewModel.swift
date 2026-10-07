import Combine
import Foundation

@MainActor
final class PurchaseLedgerViewModel: ObservableObject {
    @Published private(set) var suppliers: [Supplier] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMore = false
    @Published private(set) var loadError: String?
    @Published private(set) var pageError: String?

    typealias PageLoader = (Int, String, Int, Int) async throws -> [Supplier]
    private let loadPage: PageLoader
    private let pageSize = 25
    private var generation = 0
    private var nextOffset = 0
    private var companyID: Int?
    private var search = ""

    init(loadPage: @escaping PageLoader = { companyID, search, limit, offset in
        try await PurchasesService().suppliers(
            companyID: companyID, search: search, limit: limit, offset: offset
        ).data
    }) {
        self.loadPage = loadPage
    }

    func load(companyID: Int?, search: String, debounce: Bool = false) async {
        generation += 1
        let request = generation
        self.companyID = companyID
        self.search = search.trimmingCharacters(in: .whitespacesAndNewlines)
        suppliers = []
        nextOffset = 0
        hasMore = false
        loadError = nil
        pageError = nil
        isLoadingMore = false
        guard let companyID else {
            isLoading = false
            loadError = "Select a company first."
            return
        }
        isLoading = true
        defer { if request == generation { isLoading = false } }

        do {
            if debounce && !self.search.isEmpty {
                try await Task.sleep(nanoseconds: 300_000_000)
            }
            try Task.checkCancellation()
            let page = try await loadPage(companyID, self.search, pageSize, 0)
            guard request == generation, !Task.isCancelled else { return }
            suppliers = page
            nextOffset = page.count
            hasMore = page.count == pageSize
        } catch {
            guard request == generation, !Task.isCancelled else { return }
            loadError = error.localizedDescription
        }
    }

    func loadMore(retry: Bool = false) async {
        guard let companyID, hasMore, !isLoading, !isLoadingMore,
              pageError == nil || retry else { return }
        let request = generation
        isLoadingMore = true
        pageError = nil
        defer { if request == generation { isLoadingMore = false } }

        do {
            let page = try await loadPage(companyID, search, pageSize, nextOffset)
            guard request == generation, !Task.isCancelled else { return }
            let known = Set(suppliers.map(\.id))
            suppliers.append(contentsOf: page.filter { !known.contains($0.id) })
            // Advance by the rows returned, even if overlapping pages were deduplicated.
            nextOffset += page.count
            hasMore = page.count == pageSize
        } catch {
            guard request == generation, !Task.isCancelled else { return }
            pageError = error.localizedDescription
        }
    }
}
