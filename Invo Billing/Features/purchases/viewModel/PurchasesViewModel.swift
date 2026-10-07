//
//  PurchasesViewModel.swift
//  Invo Billing
//

import Combine
import Foundation

@MainActor
final class PurchasesViewModel: ObservableObject {

    @Published private(set) var suppliers: [Supplier] = []
    /// What the shop owes its suppliers, or nil when that is not known yet.
    ///
    /// Optional rather than 0, because those are different facts and the screen has to
    /// say which one it has. Starting at 0 meant a first load that failed left the
    /// header reading "Owed to them ₹0.00" — a shop that owes four lakh being told, in
    /// a perfectly confident typeface, that it owes nothing.
    @Published private(set) var totalDue: Double?
    @Published private(set) var bills: [PurchaseBill] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isWorking = false
    /// Set when the last load failed, so totals already on screen can be marked as out
    /// of date rather than silently passing for current.
    @Published private(set) var loadFailed = false

    @Published var errorMessage: String?
    @Published var showError = false
    @Published var message: String?

    /// nil for every bill; otherwise "owed", "paid" or "overdue".
    @Published var billFilter: String?
    @Published var search = ""
    @Published private(set) var hasMoreBills = false
    @Published private(set) var isLoadingMoreBills = false
    @Published private(set) var pageError: String?
    private let pageSize = 50
    private var billOffset = 0
    private var loadedCompanyID: Int?
    private var loadedFilter: String?
    private var loadedSearch = ""

    private let service = PurchasesService()

    /// Identifies the newest load. Changing the filter starts another one while the
    /// first is still out, and without this the slower reply wins — the list went empty
    /// because a filtered load landed on top of an unfiltered one.
    private var requestID = 0

    var oldestOutstanding: [PurchaseBill] {
        bills.filter { !$0.isSettled && !$0.isCancelled }
    }

    func load() async {
        guard let companyID = SessionManager.shared.selectedCompanyId else {
            show("Select a company first.")
            return
        }

        requestID += 1
        let request = requestID
        isLoading = true
        hasMoreBills = false
        pageError = nil
        isLoadingMoreBills = false
        if loadedCompanyID != companyID || loadedFilter != billFilter || loadedSearch != search {
            bills = []
        }
        if loadedCompanyID != companyID { suppliers = []; totalDue = nil }
        loadedCompanyID = companyID
        loadedFilter = billFilter
        loadedSearch = search
        defer { if request == requestID { isLoading = false } }

        do {
            // Both at once: the screen shows what is owed overall beside the bills that
            // make it up, and they should never be a refresh apart.
            async let suppliersResult = service.suppliers(companyID: companyID)
            async let billsResult = service.bills(companyID: companyID, status: billFilter, search: search, limit: pageSize)

            let (supplierPage, billPage) = try await (suppliersResult, billsResult)
            guard request == requestID else { return }
            suppliers = supplierPage.data
            totalDue = supplierPage.total_due
            bills = billPage
            billOffset = billPage.count
            hasMoreBills = billPage.count == pageSize
            loadFailed = false
        } catch {
            guard request == requestID else { return }
            loadFailed = true
            show(error.localizedDescription)
        }
    }

    func loadMoreBills(retry: Bool = false) async {
        guard let companyID = loadedCompanyID, companyID == SessionManager.shared.selectedCompanyId,
              !isLoading, !isLoadingMoreBills, hasMoreBills,
              pageError == nil || retry else { return }
        let request = requestID
        isLoadingMoreBills = true
        pageError = nil
        defer { if request == requestID { isLoadingMoreBills = false } }
        do {
            let page = try await service.bills(companyID: companyID, status: loadedFilter,
                search: loadedSearch, limit: pageSize, offset: billOffset)
            guard request == requestID else { return }
            let known = Set(bills.map(\.id))
            bills += page.filter { !known.contains($0.id) }
            billOffset += page.count
            hasMoreBills = page.count == pageSize
        } catch {
            guard request == requestID else { return }
            pageError = error.localizedDescription
        }
    }

    func addSupplier(_ request: NewSupplierRequest) async -> Bool {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return false }
        isWorking = true
        defer { isWorking = false }

        do {
            try await service.addSupplier(companyID: companyID, request: request)
            message = "Supplier added."
            await load()
            return true
        } catch {
            show(error.localizedDescription)
            return false
        }
    }

    func recordBill(_ request: NewPurchaseBillRequest) async -> Bool {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return false }
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            try await service.recordBill(companyID: companyID, request: request)
            message = request.bill_amount == nil
                ? "Bill recorded. Stock updated."
                : "Bill recorded in the supplier ledger."
            await load()
            return true
        } catch {
            show(error.localizedDescription)
            return false
        }
    }

    func recordReturn(_ request: NewPurchaseReturnRequest) async -> Bool {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return false }
        isWorking = true
        defer { isWorking = false }

        do {
            try await service.recordReturn(companyID: companyID, request: request)
            message = "Sent back. Stock and the bill both updated."
            await load()
            return true
        } catch {
            show(error.localizedDescription)
            return false
        }
    }

    func pay(_ request: SupplierPaymentRequestDTO) async -> Bool {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return false }
        isWorking = true
        defer { isWorking = false }

        do {
            try await service.paySupplier(companyID: companyID, request: request)
            message = "Payment recorded."
            await load()
            return true
        } catch {
            show(error.localizedDescription)
            return false
        }
    }

    func updateSupplier(id: Int, request: UpdateSupplierRequest) async -> Bool {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            try await service.updateSupplier(companyID: companyID, supplierID: id, request: request)
            message = "Supplier updated."
            await load()
            return true
        } catch {
            show(error.localizedDescription)
            return false
        }
    }

    func cancelBill(id: Int) async -> Bool {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            try await service.cancelBill(companyID: companyID, billID: id)
            message = "Bill cancelled. Supplier balance updated."
            await load()
            return true
        } catch {
            show(error.localizedDescription)
            return false
        }
    }

    private func show(_ text: String) {
        errorMessage = text
        showError = true
    }
}
