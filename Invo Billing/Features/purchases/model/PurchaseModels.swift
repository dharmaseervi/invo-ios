//
//  PurchaseModels.swift
//  Invo Billing
//
//  The buying side: who the shop buys from, what it bought, and what it still owes.
//

import Foundation

/// Somebody the shop buys from, with what is owed to them.
struct Supplier: Codable, Identifiable {
    let id: Int
    let name: String
    let phone: String
    let email: String
    let gstin: String
    let city: String
    let state: String
    /// Outstanding across their unpaid and part-paid bills, worked out by the server.
    let due: Double
    let open_bills: Int
    /// Money paid to them that no bill has claimed — a deposit they are holding.
    /// Optional so an older server that does not send it still decodes.
    let advance: Double?

    var heldInAdvance: Double { advance ?? 0 }
}

struct SuppliersResponse: Codable {
    let data: [Supplier]
    /// Everything the shop owes, across all suppliers.
    let total_due: Double
    let total_advance: Double?
}

// MARK: - A supplier's statement

/// One line of a supplier's statement: a bill they sent or a payment made to them.
struct SupplierLedgerEntry: Codable, Identifiable {
    let kind: String
    /// The id of the bill or payment behind this line — unique only within its kind.
    let id: Int
    let date: String
    let reference: String
    let description: String
    /// What the shop took on, and what it settled.
    let debit: Double
    let credit: Double
    /// What was owed after this line. Positive means the shop owes the supplier.
    let balance: Double

    var isBill: Bool { kind == "BILL" }

    /// Unique across the statement, where `id` alone is not: a bill and a payment can
    /// both be number 3, and a ForEach keyed on `id` would drop one of them.
    var rowKey: String { "\(kind)-\(id)" }
}

/// Where a supplier stands over their whole history.
struct SupplierLedgerSummary: Codable {
    let supplier_id: Int
    let name: String
    let billed: Double
    let paid: Double
    /// Positive: the shop owes them. Negative: the shop has paid ahead.
    let balance: Double
    let entries: Int
}

struct SupplierLedgerResponse: Codable {
    let data: [SupplierLedgerEntry]
    let summary: SupplierLedgerSummary
}

/// A bill from a supplier.
struct PurchaseBill: Codable, Identifiable {
    let id: Int
    let supplier_id: Int
    let supplier_name: String
    let bill_number: String
    let bill_date: String
    let due_date: String
    let subtotal: Double
    let tax: Double
    let total: Double
    let paid_amount: Double
    let remaining_amount: Double
    let status: String
    let is_overdue: Bool?
    let amount_only: Bool?

    var isOverdue: Bool { is_overdue ?? false }
    var isSettled: Bool { status == "paid" }
    var isAmountOnly: Bool { amount_only ?? false }
}

struct PurchaseBillsResponse: Codable {
    let data: [PurchaseBill]
}

struct PurchaseBillLine: Codable, Identifiable {
    let item_id: Int
    let item_name: String
    let qty: Int
    let rate: Double
    let tax_rate: Double
    let total: Double

    var id: Int { item_id }
}

struct PurchaseBillDetail: Codable {
    let id: Int
    let supplier_id: Int
    let supplier_name: String
    let bill_number: String
    let bill_date: String
    let due_date: String
    let subtotal: Double
    let tax: Double
    let total: Double
    let paid_amount: Double
    let remaining_amount: Double
    let status: String
    let notes: String
    let items: [PurchaseBillLine]
}

// MARK: - Requests

struct NewSupplierRequest: Codable {
    let name: String
    var phone: String?
    var email: String?
    var gstin: String?
    var city: String?
    var state: String?
}

struct PurchaseLineRequest: Codable {
    let item_id: Int
    let qty: Int
    let rate: Double
    let tax_rate: Double
}

struct NewPurchaseBillRequest: Codable {
    let supplier_id: Int
    let bill_number: String
    var bill_date: String?
    var due_date: String?
    var notes: String?
    let items: [PurchaseLineRequest]
    /// Paid at the counter. The rest becomes what the shop owes.
    var paid_amount: Double
    var paid_method: String?
    /// Final invoice amount, including any tax, when no stock lines are entered.
    var bill_amount: Double? = nil
}

/// Shared by the purchase form and its payload checks. Invalid text must never turn
/// into a zero payment or a different invoice amount.
enum PurchaseAmountInput {
    static func parse(_ text: String, emptyAsZero: Bool = false) -> Double? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return emptyAsZero ? 0 : nil }
        guard value.range(of: #"^[0-9]+(?:\.[0-9]{0,2})?$"#, options: .regularExpression) != nil,
              let amount = Double(value), amount.isFinite,
              amount <= 9_999_999_999.99 else { return nil }
        return amount
    }
}

// MARK: - Sending stock back

/// Goods returned to a supplier: the buying-side twin of a credit note.
struct PurchaseReturn: Codable, Identifiable {
    let id: Int
    let supplier_id: Int
    let supplier_name: String
    let return_number: String
    let return_date: String
    let subtotal: Double
    let tax: Double
    let total: Double
    let reason: String
    /// The bill the goods came in on, where it was known.
    let bill_number: String
}

struct PurchaseReturnsResponse: Codable {
    let data: [PurchaseReturn]
}

struct PurchaseReturnLineRequest: Codable {
    let item_id: Int
    let qty: Int
    let rate: Double
    let tax_rate: Double
}

struct NewPurchaseReturnRequest: Codable {
    let supplier_id: Int
    var bill_id: Int?
    let return_number: String
    var return_date: String?
    var reason: String?
    var notes: String?
    let items: [PurchaseReturnLineRequest]
}

struct SupplierPaymentRequestDTO: Codable {
    let supplier_id: Int
    var bill_id: Int?
    let amount: Double
    let method: String
    var reference: String?
    var paid_on: String?
}
