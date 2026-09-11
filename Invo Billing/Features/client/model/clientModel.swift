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

    /// Decoded defensively: every field except id and name is nullable in the database,
    /// and a quick-sale Cash or UPI client is created with most of them blank. With the
    /// synthesised decoder a single null failed the whole array, so one incomplete
    /// client made the entire list disappear behind an error rather than showing a
    /// blank field on one row.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        company_id = try c.decodeIfPresent(Int.self, forKey: .company_id) ?? 0
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        address = try c.decodeIfPresent(String.self, forKey: .address) ?? ""
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        phone = try c.decodeIfPresent(String.self, forKey: .phone) ?? ""
        city = try c.decodeIfPresent(String.self, forKey: .city) ?? ""
        state = try c.decodeIfPresent(String.self, forKey: .state) ?? ""
        pincode = try c.decodeIfPresent(String.self, forKey: .pincode) ?? ""
    }

    init(
        id: Int, company_id: Int, name: String, address: String, email: String,
        phone: String, city: String, state: String, pincode: String
    ) {
        self.id = id
        self.company_id = company_id
        self.name = name
        self.address = address
        self.email = email
        self.phone = phone
        self.city = city
        self.state = state
        self.pincode = pincode
    }
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
