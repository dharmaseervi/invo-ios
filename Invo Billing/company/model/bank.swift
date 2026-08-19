//
//  bank.swift
//  Invo Billing
//
//  Created by dharmaseervi on 2/5/26.
//

struct CompanyBank: Identifiable, Codable {
    let id: Int
    let company_id: Int
    var account_holder_name: String
    var bank_name: String
    var account_number: String
    var ifsc_code: String
    var branch: String
    var upi_id: String
    var is_default: Bool
}

struct CompanyBankRequestDTO: Codable {
    let bank_name: String
    let company_id: Int
    let account_holder_name: String
    let account_number: String
    let ifsc_code: String
    let upi_id: String?
    let branch: String?
    let is_default: Bool
}

struct CompanyBankResponse: Codable, Identifiable {
    let id: Int
    let company_id: Int
    let bank_name: String
    let account_holder_name: String
    let account_number: String
    let ifsc_code: String
    let upi_id: String?
    let branch: String?
    let is_default: Bool
    let created_at: String
}
struct CompanyBankListResponse: Codable {
    let banks: [CompanyBankResponse]
}
