//
//  addressModel.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/21/25.
//

struct AddressModel: Codable {
    let type: String
    let name: String?
    let line1: String
    let line2: String?
    let city: String
    let state: String
    let postal_code: String
    let country: String
    let phone: String?
    let email: String?
    let gst_number: String?
}


struct AddressFormModel {
    
    var type: String
    var name: String = ""
    var line1: String = ""
    var line2: String = ""
    var city: String = ""
    var state: String = ""
    var postalCode: String = ""
    var country: String = "India"
    var phone: String = ""
    var email: String = ""
    var gstNumber: String = ""
    
    static func empty(type: String) -> AddressFormModel {
        AddressFormModel(type: type)
    }
    
    func copyAsShipping() -> AddressFormModel {
        var copy = self
        copy.type = "shipping"
        return copy
    }
    
    func toRequest() -> ClientAddressRequestDTO {
        ClientAddressRequestDTO(
            type: type,
            name: name.isEmpty ? nil : name,
            line1: line1,
            line2: line2.isEmpty ? nil : line2,
            city: city.isEmpty ? nil : city,
            state: state.isEmpty ? nil : state,
            postal_code: postalCode.isEmpty ? nil : postalCode,
            country: country,
            phone: phone.isEmpty ? nil : phone,
            email: email.isEmpty ? nil : email,
            gst_number: gstNumber.isEmpty ? nil : gstNumber
        )
    }
}

extension AddressFormModel {
    
    init(from model: AddressModel) {
        self.type = model.type
        self.name = model.name ?? ""
        self.line1 = model.line1
        self.line2 = model.line2 ?? ""
        self.city = model.city
        self.state = model.state
        self.postalCode = model.postal_code
        self.country = model.country
        self.phone = model.phone ?? ""
        self.email = model.email ?? ""
        self.gstNumber = model.gst_number ?? ""
    }
}



struct ClientAddressRequestDTO: Codable {
    let type: String
    let name: String?
    let line1: String
    let line2: String?
    let city: String?
    let state: String?
    let postal_code: String?
    let country: String?
    let phone: String?
    let email: String?
    let gst_number: String?
}

struct ClientAddressResponse: Codable, Identifiable {
    let id: Int
    let address_type: String
    let name: String?
    let line1: String
    let line2: String?
    let city: String?
    let state: String?
    let postal_code: String?
    let country: String?
    let phone: String?
    let email: String?
    let gst_number: String?
}

struct AddressResponse: Codable {
    let data: AddressModel?
}
