//
//  clientModel.swift
//  invo
//
//  Created by dharmaseervi on 11/19/25.
//

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
