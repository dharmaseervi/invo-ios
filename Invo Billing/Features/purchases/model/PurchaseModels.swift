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
}

struct SuppliersResponse: Codable {
    let data: [Supplier]
    /// Everything the shop owes, across all suppliers.
    let total_due: Double
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

    var isOverdue: Bool { is_overdue ?? false }
    var isSettled: Bool { status == "paid" }
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
}

struct SupplierPaymentRequestDTO: Codable {
    let supplier_id: Int
    var bill_id: Int?
    let amount: Double
    let method: String
    var reference: String?
    var paid_on: String?
}
