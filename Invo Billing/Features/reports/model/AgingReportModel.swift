import Foundation

struct AgingBucket: Codable {
    let current: Double
    let days_1_30: Double
    let days_31_60: Double
    let days_61_90: Double
    let days_90_plus: Double
}

struct ClientAgingRow: Codable, Identifiable {
    let client_id: Int
    let client_name: String
    let total: Double
    let buckets: AgingBucket

    var id: Int { client_id }
}

struct AgingReportResponse: Codable {
    let as_of: String
    let grand_total: Double
    let totals: AgingBucket
    let clients: [ClientAgingRow]
}
