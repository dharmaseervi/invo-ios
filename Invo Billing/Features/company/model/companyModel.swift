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

}

struct CompaniesResponse: Codable {
    let companies: [CompanyResponse]
}


struct CreateCompanyResponse: Codable {
    let message: String?
    let company: CompanyResponse?
    let id: Int?
}
