//
//  SupplierStatementViewModel.swift
//  Invo Billing
//

import Combine
import Foundation

@MainActor
final class SupplierStatementViewModel: ObservableObject {

    @Published private(set) var entries: [SupplierLedgerEntry] = []
    @Published private(set) var summary: SupplierLedgerSummary?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingEarlier = false
    @Published private(set) var hasMore = false

    @Published var errorMessage: String?
    @Published var showError = false

    private let supplierID: Int
    private let service = PurchasesService()

    /// A page at a time, newest first. A supplier the shop has bought from for years
    /// has a long statement, and the part worth seeing is the recent end.
    private let pageSize = 40

    /// Identifies the newest load, so a slow first page cannot land on top of entries
    /// that were loaded after it — the mistake that emptied the purchases list.
    private var requestID = 0

    init(supplierID: Int) {
        self.supplierID = supplierID
    }

    /// What the shop owes right now, from the summary rather than the last row: the
    /// last row is the end of the loaded page, which is the whole history only until
    /// somebody pages back.
    var balance: Double { summary?.balance ?? 0 }
    var isInCredit: Bool { balance < -0.004 }

    func load() async {
        guard let companyID = SessionManager.shared.selectedCompanyId else {
            show("Select a company first.")
            return
        }

        requestID += 1
        let request = requestID
        isLoading = true
        defer { isLoading = false }

        do {
            let page = try await service.ledger(
                companyID: companyID, supplierID: supplierID, limit: pageSize
            )
            guard request == requestID else { return }
            entries = page.data
            summary = page.summary
            hasMore = page.summary.entries > page.data.count
        } catch {
            guard request == requestID else { return }
            show(error.localizedDescription)
        }
    }

    /// Older entries, prepended. On a button rather than on scroll: pulling pages in
    /// automatically as the list grew re-triggered itself on the statement screen and
    /// walked back through the whole history in one go.
    func loadEarlier() async {
        guard let companyID = SessionManager.shared.selectedCompanyId,
              !isLoadingEarlier, hasMore else { return }

        isLoadingEarlier = true
        defer { isLoadingEarlier = false }

        let request = requestID
        do {
            let page = try await service.ledger(
                companyID: companyID,
                supplierID: supplierID,
                limit: pageSize,
                offset: entries.count
            )
            guard request == requestID else { return }

            // Prepended, and anything already on screen is skipped: a bill recorded
            // while the statement was open shifts the offsets, and the same line would
            // otherwise arrive twice.
            let known = Set(entries.map(\.rowKey))
            entries.insert(contentsOf: page.data.filter { !known.contains($0.rowKey) }, at: 0)
            summary = page.summary
            hasMore = page.summary.entries > entries.count
        } catch {
            guard request == requestID else { return }
            show(error.localizedDescription)
        }
    }

    private func show(_ text: String) {
        errorMessage = text
        showError = true
    }
}
