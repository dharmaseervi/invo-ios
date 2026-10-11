//
//  CompanyRequestDTO.swift
//  invo
//
//  Created by dharmaseervi on 11/17/25.
//
import Foundation

struct CompanyRequestDTO: Codable {
    let name: String
    let phone: String
    let address: String
    let gst: String
    let city: String
    let state: String
    let pincode: String
    let invoice_footer: String
    let invoice_prefix: String
}

struct CompanyResponse: Codable ,Identifiable {
    let id: Int
    let user_id: Int
    let name: String
    let address: String
    let phone: String
    let gst: String
    let city: String
    let state: String
    let pincode: String

    /// Printed at the bottom of every invoice PDF. Optional so older server responses decode.
    let invoice_footer: String?
    /// Prefix for generated invoice numbers, e.g. "INV". Optional for backward compat.
    let invoice_prefix: String?

    /// What this account is to this business: owner, manager or staff. Optional so a
    /// server that does not send it yet still decodes — read it through `memberRole`.
    let role: String?

    var memberRole: MemberRole { MemberRole(role) }
}

struct CompaniesResponse: Codable {
    let companies: [CompanyResponse]
}


struct CreateCompanyResponse: Codable {
    let message: String?
    let company: CompanyResponse?
    let id: Int?
}
