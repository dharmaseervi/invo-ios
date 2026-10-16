//
//  RecordPaymentViewModel.swift
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class RecordPaymentViewModel: ObservableObject {
    
 
    
    // MARK: - Context
    let companyID: Int
    let clientID: Int
    let clientName: String
    let invoiceNumber: String?
    let context: PaymentContext
    let isInvoiceMode: Bool

    // MARK: - Inputs
    @Published var amount: String = ""
    @Published var tdsAmount: String = ""
    @Published var paymentDate = Date()
    @Published var expectedTDS: Double?
    private var amountBeforeEdit = ""
    @Published var method: PaymentMethods = .upi
    @Published var reference: String = ""
    @Published var notes: String = ""
    @Published var unpaidInvoices: [InvoiceSummaryModel] = []

    // MARK: - State
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var errorMessage: String?

    private let invoiceService = InvoiceService()
    private let paymentService = PaymentService.shared

    // MARK: - Init
    init(
        companyID: Int,
        clientID: Int,
        clientName: String = "",
        invoiceNumber: String? = nil,
        context: PaymentContext
    ) {
        self.companyID = companyID
        self.clientID = clientID
        self.clientName = clientName
        self.invoiceNumber = invoiceNumber
        self.context = context
        self.isInvoiceMode = {
            if case .invoice = context { return true }
            return false
        }()

        // Auto-fill amount for invoice flow
        if case let .invoice(_, remaining) = context {
            self.amount = Money.editable(remaining)
        }

    }

    // MARK: - Validation
    var isValid: Bool {
        guard let received = Money.parse(amount), received >= 0,
              let withheld = Money.parse(tdsAmount.isEmpty ? "0" : tdsAmount), withheld >= 0 else { return false }
        let total = Money.rounded(received + withheld)
        return total > 0 && (dueAmount.map { total <= Money.rounded($0) } ?? true) && (isInvoiceMode || withheld == 0)
    }

    var dueAmount: Double? {
        if case let .invoice(_, remaining) = context { return remaining }
        return nil
    }
    
    // MARK: - Load unpaid invoices (client flow only)
    func loadUnpaidInvoices() async {
        if case let .invoice(invoiceID, _) = context {
            do {
                let detail = try await invoiceService.fetchInvoiceDetail(id: invoiceID)
                expectedTDS = max((detail.tds_amount ?? 0) - (detail.tds_withheld ?? 0), 0)
            } catch { /* Withholding can still be entered explicitly; never guess it. */ }
            return
        }
        isLoading = true
        defer { isLoading = false }
        
        do {
            unpaidInvoices = try await invoiceService
                .fetchUnpaidInvoices(
                    clientID: clientID,
                    companyID: companyID
                )
        } catch {
            errorMessage = error.localizedDescription
            showAlert = true
        }
    }
    
    // MARK: - Submit payment
    func submitPayment() async -> Bool {
        
        guard !isLoading else { return false }
        guard isValid, let amountValue = Money.parse(amount),
              let withheldValue = Money.parse(tdsAmount.isEmpty ? "0" : tdsAmount) else {
            errorMessage = "Enter a valid amount"
            showAlert = true
            return false
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let allocations: [PaymentAllocationDTO]
        
        switch context {
            
            // ✅ SINGLE INVOICE PAYMENT
        case .invoice(let invoiceID, _):
            allocations = [
                PaymentAllocationDTO(
                    invoice_id: invoiceID,
                    amount: Money.rounded(amountValue + withheldValue),
                    tds_amount: withheldValue
                )
            ]
            
            // ✅ CLIENT PAYMENT (FIFO allocation)
        case .client:
            // The server allocates cash against the current complete balance,
            // including invoices not present in this preview page.
            allocations = []
        }
        
        let dto = PaymentRequestDTO(
            client_id: clientID,
            amount: amountValue,
            payment_method: method.self,
            reference: reference.isEmpty ? nil : reference,
            notes: notes.isEmpty ? nil : notes,
            allocations: allocations,
            payment_date: AppDate.wireDate(paymentDate),
            tds_amount: withheldValue
        )
        
        do {
            try await paymentService.recordPayment(requestDTO: dto)
            return true
        } catch {
            errorMessage = error.localizedDescription
            showAlert = true
            return false
        }
    }
}

