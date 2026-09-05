//
//  clientModel.swift
//  invo
//
//  Created by dharmaseervi on 11/19/25.
//

import Foundation

struct ClientModel: Codable, Identifiable, Equatable {
    var id: Int
    var company_id: Int
    var name: String
    var address: String
    var email: String
    var phone: String
    var city: String
    var state: String
    var pincode: String
}

/// Default "quick sale" accounts (Tally-style Cash/UPI ledgers) — just normal clients
/// under the hood, so invoices/payments/the per-client Ledger view work unmodified.
/// No address or contact details required for these.
enum QuickSaleAccount: String, CaseIterable {
    case cash = "Cash"
    case upi = "UPI"

    var icon: String {
        switch self {
        case .cash: return "banknote"
        case .upi: return "qrcode"
        }
    }
}

extension ClientModel {
    var quickSaleAccount: QuickSaleAccount? {
        QuickSaleAccount.allCases.first {
            $0.rawValue.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    var isQuickSaleAccount: Bool { quickSaleAccount != nil }
}

struct CreateClientRequest: Codable {
    let company_id: Int
    let name: String
    let address: String
    let email: String
    let phone: String
    let city: String
    let state: String
    let pincode: String
}
