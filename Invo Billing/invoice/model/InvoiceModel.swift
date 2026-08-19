//
//  InvoiceModels.swift
//  Invo
//
//  Final production-ready invoice models
//

import Foundation

// MARK: - UI-only Line Item (used while creating invoice)

struct InvoiceLineItem: Identifiable {
    
    let id = UUID()
    
    let item: ItemResponse
    var qty: Int
    var rate: Double
    var discount: Double
    var taxRate: Double   // ✅ camelCase (Swift standard)
    
    // MARK: - Computed Values (UI only)
    
    var baseAmount: Double {
        rate * Double(qty)
    }
    
    var totalBeforeTax: Double {
        max(baseAmount - discount, 0)
    }
    
    var taxAmount: Double {
        totalBeforeTax * (taxRate / 100)
    }
    
    var total: Double {
        totalBeforeTax + taxAmount
    }
}


// MARK: - Create Invoice (API Request)

struct InvoiceItemRequest: Codable {
    let item_id: Int
    let qty: Int
    let rate: Double
    let discount: Double
    let tax_rate: Double
}

struct InvoiceRequestDTO: Codable {
    let company_id: Int
    let client_id: Int
    let invoice_date: String   // yyyy-MM-dd
    let due_date: String       // yyyy-MM-dd
    let items: [InvoiceItemRequest]
}

// MARK: - Invoice Status

enum InvoiceStatus: String, Codable {
    case draft
    case sent
    case issued
    case partial
    case paid
    case overdue
    case cancelled
    case pending
}

// MARK: - Invoice List Response

struct InvoiceListResponse: Codable {
    let data: [InvoiceResponse]
    let limit: Int?
    let offset: Int?
}

struct InvoiceResponse: Codable, Identifiable {
    let id: Int
    let company_id: Int
    let client_id: Int
    
    let invoice_number: String
    let invoice_date: String
    let due_date: String
    
    let subtotal: Double
    let tax: Double
    let total: Double
    
    let status: InvoiceStatus
    let paid_amount: Double
    let remaining_amount: Double
    
    let is_overdue: Bool
    let days_overdue: Int
    
    let created_at: String
}

// MARK: - Invoice Detail Response

struct InvoiceDetailResponse: Codable {
    let id: Int
    let invoice_number: String
    
    let status: InvoiceStatus
    
    let invoice_date: String
    let due_date: String
    
    let subtotal: Double
    let tax: Double
    let total: Double
    
    let paid_amount: Double
    let remaining_amount: Double
    
    let is_overdue: Bool
    let days_overdue: Int
    
    let client: ClientSummary
    let items: [InvoiceItemDetail]
}

// MARK: - Embedded Client Summary

struct ClientSummary: Codable {
    let id: Int
    let name: String
}

// MARK: - Invoice Item (from backend)

struct InvoiceItemDetail: Codable, Identifiable {
    let id: Int
    let item_id: Int
    let qty: Int
    let rate: Double
    let discount: Double
    let tax_rate: Double
    let total: Double
}

struct CreateInvoiceResponse: Codable {
    let invoice_id: Int
    let invoice_number: String
    let financial_year: String
}


// MARK: - Payments (future-ready)

struct Payment: Codable, Identifiable {
    let id: Int
    let invoice_id: Int
    let amount: Double
    let payment_date: String
    let payment_method: PaymentMethod
    let reference_number: String?
    let notes: String?
}

enum PaymentMethod: String, Codable {
    case cash
    case bank
    case upi
    case cheque
    case card
}
struct PDFDocument: Identifiable {
    let id = UUID()
    let url: URL
}

struct InvoiceSummaryModel: Identifiable, Codable {
    
    let id: Int
    let invoiceNumber: String
    let remainingAmount: Double
    let invoiceDate: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case invoiceNumber = "invoice_number"
        case remainingAmount = "remaining_amount"
        case invoiceDate = "invoice_date"
    }
}

struct InvoiceSummaryResponse: Codable {
    let data: [InvoiceSummaryModel]
}

enum InvoiceCopyType: String, CaseIterable {
    case original   = "ORIGINAL FOR RECIPIENT"
    case duplicate  = "DUPLICATE FOR TRANSPORTER"
    case triplicate = "TRIPLICATE FOR SUPPLIER"
}
enum InvoiceWatermark {
    case none
    case draft
    case paid
    case cancelled
    
    var text: String {
        switch self {
        case .none: return ""
        case .draft: return "DRAFT"
        case .paid: return "PAID"
        case .cancelled: return "CANCELLED"
        }
    }
}
