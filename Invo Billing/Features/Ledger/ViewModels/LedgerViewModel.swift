import Combine
import SwiftUI

@MainActor
final class LedgerViewModel: ObservableObject {

    @Published var entries: [LedgerEntryModel] = []
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var errorMessage: String?
    @Published var isLoadingMore = false
    @Published var hasMore = false
    /// The last page failed; the statement offers another go rather than looking as
    /// though it began there.
    @Published var loadMoreFailed = false
    /// The customer's totals over their whole history, from the server.
    @Published var summary: LedgerSummaryModel = .empty
    /// True when the totals could not be fetched, so the screen can say so rather than
    /// showing zeroes as if the customer had never traded.
    @Published var summaryFailed = false

    /// Rows per request. A long-standing customer has thousands of lines.
    private static let pageSize = 50
    private var offset = 0
    private var requestID = 0

    let clientID: Int

    init(clientID: Int) {
        self.clientID = clientID
    }

    // Rows a page at a time, totals from the server.
    //
    // A customer who has been buying for years has thousands of lines, and all of them
    // were fetched, sent and rendered to show the last few. The totals below used to be
    // summed from those rows, which is why paging had to wait for the summary endpoint:
    // a page's totals shown as the customer's totals is a wrong number, not a slow one.
    func fetchLedger() async {
        guard let companyId = SessionManager.shared.selectedCompanyId else {
            errorMessage = "Select company first"
            showAlert = true
            return
        }

        requestID += 1
        let request = requestID
        isLoading = true
        offset = 0
        loadMoreFailed = false
        defer { isLoading = false }

        async let summaryResult = try? LedgerService.shared.fetchClientSummary(
            clientID: clientID, companyID: companyId
        )

        do {
            let page = try await LedgerService.shared.fetchLedger(
                clientID: clientID,
                companyID: companyId,
                limit: Self.pageSize,
                offset: 0
            )
            let newSummary = await summaryResult
            guard request == requestID else { return }
            entries = page
            offset = page.count
            hasMore = page.count >= Self.pageSize
            summary = newSummary ?? .empty
            summaryFailed = newSummary == nil
        } catch {
            guard request == requestID else { return }
            errorMessage = error.localizedDescription
            showAlert = true
        }
    }

    /// The page before the one on screen — a statement is read forwards, so paging
    /// walks backwards through the history.
    func loadMoreIfNeeded(currentItem entry: LedgerEntryModel) async {
        guard !isLoadingMore, !loadMoreFailed, hasMore else { return }
        guard let index = entries.firstIndex(where: { $0.id == entry.id }),
              index <= 5 else { return }
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

        do {
            let page = try await LedgerService.shared.fetchLedger(
                clientID: clientID,
                companyID: companyId,
                limit: Self.pageSize,
                offset: askedAt
            )
            guard request == requestID, askedAt == offset else { return }
            // Older entries go in front: each page is older than the one already shown.
            let existing = Set(entries.map(\.id))
            entries.insert(contentsOf: page.filter { !existing.contains($0.id) }, at: 0)
            offset += page.count
            hasMore = page.count >= Self.pageSize
        } catch {
            guard request == requestID else { return }
            loadMoreFailed = true
        }
    }

    var totalDebit: Double { summary.debit }

    var totalCredit: Double { summary.credit }

    var closingBalance: Double { summary.balance }
}
