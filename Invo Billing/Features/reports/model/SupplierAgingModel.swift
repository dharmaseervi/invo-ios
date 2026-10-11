import Foundation

struct SupplierAgingRow: Codable, Identifiable {
    let supplier_id: Int
    let supplier_name: String
    let total: Double
    let buckets: AgingBucket

    var id: Int { supplier_id }
}

struct SupplierAgingReport: Codable {
    let as_of: String
    let grand_total: Double
    let totals: AgingBucket
    let suppliers: [SupplierAgingRow]
}
