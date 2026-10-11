import Foundation

enum ChallanStatus: String, Codable {
    case draft
    case dispatched
}

struct ChallanItemRequest: Codable {
    let item_id: Int
    let qty: Int
    let description: String
}

struct ChallanRequestDTO: Codable {
    let company_id: Int
    let client_id: Int
    let challan_date: String
    let invoice_id: Int?
    let notes: String
    let items: [ChallanItemRequest]
}

struct ChallanResponse: Codable, Identifiable {
    let id: Int
    let challan_number: String
    let client_name: String?
    let challan_date: String
    let status: ChallanStatus
    let invoice_id: Int?
    let created_at: String
}

struct ChallanItemDetail: Codable, Identifiable {
    let id: Int
    let item_id: Int
    let item_name: String?
    let qty: Int
    let description: String?
}

struct ChallanClient: Codable {
    let id: Int
    let name: String
}

struct ChallanDetailResponse: Codable {
    let id: Int
    let challan_number: String
    let client: ChallanClient
    let challan_date: String
    let status: ChallanStatus
    let invoice_id: Int?
    let notes: String?
    let items: [ChallanItemDetail]
}

struct CreateChallanResponse: Codable {
    let id: Int
    let challan_number: String
}
