//
//  CreditNoteStatus.swift
//  Invo Billing
//
//  Created by dharmaseervi on 1/11/26.
//
import Foundation

struct CreditNoteModel: Identifiable, Codable {
    let id: Int
    let credit_number: String
    let client_name: String
    let type: String
    let total: Double
    let credit_date: String
}
 
enum CreditNoteType: String, CaseIterable, Codable {
    case returnItems = "return"
    case adjustment  = "adjustment"
    case discount    = "discount"
    
    var title: String {
        switch self {
        case .returnItems: return "Item Return"
        case .adjustment:  return "Adjustment"
        case .discount:    return "Discount"
        }
    }
    
    /// Determines whether this CN requires item selection
    var requiresItems: Bool {
        self == .returnItems
    }
    
    /// Determines whether this CN uses a flat amount
    var usesAmountOnly: Bool {
        self == .adjustment || self == .discount
    }
}
struct CreateCreditNoteItemDTO: Codable {
    let item_id: Int
    let qty: Double
    let rate: Double
    let discount: Double
    let tax_rate: Double
}


struct CreateCreditNoteRequestDTO: Codable {
    let company_id: Int
    let client_id: Int
    let invoice_id: Int?
    let credit_date: String
    let type: String
    
    // VALUE MODE
    let amount: Double?
    
    // ITEM MODE
    let items: [CreateCreditNoteItemDTO]?
    
    let reason: String?
    let notes: String?
}


struct CreditNoteListResponse: Codable {
    let data: [CreditNoteModel]?
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decodeIfPresent([CreditNoteModel].self, forKey: .data)
    }
}

struct CreditNoteItemModel: Identifiable, Codable {
    let id: Int
    let item_id: Int
    let item_name: String
    let qty: Double
    let rate: Double
    let tax_rate: Double
    let total: Double
}


struct CreditNoteDetailModel: Identifiable, Codable {
    let id: Int
    let credit_number: String
    
    let client_id: Int
    let client_name: String
    
    let invoice_id: Int?
    let invoice_number: String?
    
    let type: String
    let reason: String?
    
    let subtotal: Double
    let tax: Double
    let total: Double
    let balance: Double
    
    let status: String
    let credit_date: String
    let created_at: String
    
    // 🔴 IMPORTANT
    let items: [CreditNoteItemModel]
}

