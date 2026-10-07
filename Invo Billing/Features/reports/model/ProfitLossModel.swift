//
//  ProfitLossModel.swift
//  Invo Billing
//

import Foundation

struct ProfitLossResponse: Codable {
    let period: String
    let from: String
    let to: String
    let revenue: Double
    let purchases: Double
    let expenses: Double
    let gross_profit: Double
    let net_profit: Double
    let gross_margin_pct: Double
    let net_margin_pct: Double
    let invoice_count: Int
    let bill_count: Int
    let expense_count: Int
}
