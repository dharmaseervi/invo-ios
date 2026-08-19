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
    let context: PaymentContext
    let isInvoiceMode: Bool
    
    // MARK: - Inputs
    @Published var amount: String = ""
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
        context: PaymentContext
    ) {
        self.companyID = companyID
        self.clientID = clientID
        self.context = context
        self.isInvoiceMode = {
            if case .invoice = context { return true }
            return false
        }()
        
        // Auto-fill amount for invoice flow
        if case let .invoice(_, remaining) = context {
            self.amount = String(format: "%.2f", remaining)
        }
        
    }
    
    // MARK: - Validation
    var isValid: Bool {
        (Double(amount) ?? 0) > 0
    }
    
    // MARK: - Load unpaid invoices (client flow only)
    func loadUnpaidInvoices() async {
        guard case .client = context else { return }
        
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
        
        guard let amountValue = Double(amount), amountValue > 0 else {
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
                    amount: amountValue
                )
            ]
            
            // ✅ CLIENT PAYMENT (FIFO allocation)
        case .client:
            var remaining = amountValue
            var temp: [PaymentAllocationDTO] = []
            
            for invoice in unpaidInvoices where remaining > 0 {
                let applied = min(invoice.remainingAmount, remaining)
                temp.append(
                    PaymentAllocationDTO(
                        invoice_id: invoice.id,
                        amount: applied
                    )
                )
                remaining -= applied
            }
            
            allocations = temp
        }
        
        let dto = PaymentRequestDTO(
            client_id: clientID,
            amount: amountValue,
            payment_method: method.self,
            reference: reference.isEmpty ? nil : reference,
            notes: notes.isEmpty ? nil : notes,
            allocations: allocations
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

