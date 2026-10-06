//
//  PurchasesViewModel.swift
//  Invo Billing
//

import Combine
import Foundation

@MainActor
final class PurchasesViewModel: ObservableObject {

    @Published private(set) var suppliers: [Supplier] = []
    @Published private(set) var totalDue: Double = 0
    @Published private(set) var bills: [PurchaseBill] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isWorking = false

    @Published var errorMessage: String?
    @Published var showError = false
    @Published var message: String?

    /// nil for every bill; otherwise "owed", "paid" or "overdue".
    @Published var billFilter: String?

    private let service = PurchasesService()

    /// Identifies the newest load. Changing the filter starts another one while the
    /// first is still out, and without this the slower reply wins — the list went empty
    /// because a filtered load landed on top of an unfiltered one.
    private var requestID = 0

    var oldestOutstanding: [PurchaseBill] {
        bills.filter { !$0.isSettled }
    }

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
            // Both at once: the screen shows what is owed overall beside the bills that
            // make it up, and they should never be a refresh apart.
            async let suppliersResult = service.suppliers(companyID: companyID)
            async let billsResult = service.bills(companyID: companyID, status: billFilter)

            let (supplierPage, billPage) = try await (suppliersResult, billsResult)
            guard request == requestID else { return }
            suppliers = supplierPage.data
            totalDue = supplierPage.total_due
            bills = billPage
        } catch {
            guard request == requestID else { return }
            show(error.localizedDescription)
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
        isWorking = true
        defer { isWorking = false }

        do {
            try await service.recordBill(companyID: companyID, request: request)
            message = "Bill recorded. Stock updated."
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

    private func show(_ text: String) {
        errorMessage = text
        showError = true
    }
}
