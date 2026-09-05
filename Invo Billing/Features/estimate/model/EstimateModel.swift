import Foundation

enum EstimateStatus: String, Codable {
    case draft
    case sent
    case accepted
    case rejected
    case expired
    case converted
}

struct EstimateResponse: Codable, Identifiable {
    let id: Int
    let company_id: Int
    let client_id: Int
    let client_name: String?
    let estimate_number: String
    let estimate_date: String
    let expiry_date: String?
    let subtotal: Double
    let tax: Double
    let discount: Double
    let total: Double
    let status: EstimateStatus
    let converted_invoice_id: Int?
    let created_at: String
}

struct EstimateItemDetail: Codable, Identifiable {
    let id: Int
    let item_id: Int
    let qty: Int
    let rate: Double
    let discount: Double
    let tax_rate: Double
    let total: Double
}

struct EstimateDetailResponse: Codable {
    let id: Int
    let estimate_number: String
    let estimate_date: String
    let expiry_date: String?
    let subtotal: Double
    let tax: Double
    let discount: Double
    let total: Double
    let status: EstimateStatus
    let converted_invoice_id: Int?
    let client: ClientSummary
    let items: [EstimateItemDetail]
}

struct EstimateRequestDTO: Codable {
    let company_id: Int
    let client_id: Int
    let estimate_date: String
    let expiry_date: String?
    let discount: Double
    let items: [InvoiceItemRequest]
}

struct UpdateEstimateRequestDTO: Codable {
    let client_id: Int
    let estimate_date: String
    let expiry_date: String?
    let discount: Double
    let items: [InvoiceItemRequest]
}

struct EstimateStatusUpdateDTO: Codable {
    let status: String
}

struct CreateEstimateResponse: Codable {
    let estimate_id: Int
    let estimate_number: String
    let financial_year: String
}

struct ConvertEstimateResponse: Codable {
    let invoice_id: Int
    let invoice_number: String
}
