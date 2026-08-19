//
//  PaymentModel.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/31/25.
//

import Foundation

enum PaymentMethods: String, Codable, CaseIterable {
    case cash
    case bankTransfer = "bank_transfer"
    case upi
    case cheque
}


struct PaymentRequestDTO: Codable {
    
    let client_id: Int
    let amount: Double
    let payment_method: PaymentMethods
    let reference: String?
    let notes: String?
    
    /// 🔑 This is mandatory now
    let allocations: [PaymentAllocationDTO]
}

struct PaymentResponse: Codable {
    let id: Int
    let amount: Double
    let method: PaymentMethods
    let reference: String?
    let created_at: String
}


struct PaymentAllocationDTO: Codable {
    let invoice_id: Int
    let amount: Double
}

enum PaymentContext {
    case client
    case invoice(invoiceID: Int, remaining: Double)
}
