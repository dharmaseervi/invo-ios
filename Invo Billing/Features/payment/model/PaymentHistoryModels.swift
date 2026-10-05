//
//  PaymentHistoryModels.swift
//  Invo Billing
//

import Foundation

/// One payment in a company's history.
struct PaymentHistoryRow: Codable, Identifiable {
    let id: Int
    let client_id: Int
    let client_name: String
    let amount: Double
    let payment_method: String
    let reference: String
    let notes: String
    let payment_date: String
    let applied_to: String
    /// "recorded" or "reversed". A reversed payment stays in the list with its reason —
    /// a customer's statement has to be able to explain itself.
    let status: String?
    let reversal_reason: String?
    /// What this payment did not settle: money the customer is holding with the shop.
    let unapplied_amount: Double?
    let allocations: [PaymentAllocationRow]?

    var isReversed: Bool { status == "reversed" }
    var onAccount: Double { unapplied_amount ?? 0 }
    var invoices: [PaymentAllocationRow] { allocations ?? [] }
}

struct PaymentAllocationRow: Codable, Identifiable {
    let invoice_id: Int
    let invoice_number: String
    let amount: Double

    var id: Int { invoice_id }
}

/// Money going back to a customer.
struct RefundRequestDTO: Codable {
    let client_id: Int
    var credit_note_id: Int?
    let amount: Double
    let method: String
    var reference: String?
    var notes: String?
    var refund_date: String?
}
