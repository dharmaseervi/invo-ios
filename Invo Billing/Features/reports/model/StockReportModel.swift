import Foundation

enum StockStatus: String, Codable {
    case inStock = "in"
    case low
    case out

    var label: String {
        switch self {
        case .inStock: return "In stock"
        case .low: return "Low stock"
        case .out: return "Out of stock"
        }
    }
}

struct StockReportItem: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let quantity: Int
    let cost_price: Double
    let price: Double
    let stock_value: Double
    let low_stock_alert: Int

    // Added alongside the category breakdown. Optional so a client running against an
    // older server (or an older cached response) still decodes instead of throwing.
    let sku: String?
    let category_id: Int?
    let category_name: String?
    let unit: String?
    let retail_value: Double?
    let status: String?

    var categoryLabel: String { category_name ?? "Uncategorised" }
    var retailValue: Double { retail_value ?? price * Double(quantity) }

    var stockStatus: StockStatus {
        if let status, let parsed = StockStatus(rawValue: status) { return parsed }
        if quantity <= 0 { return .out }
        if low_stock_alert > 0 && quantity <= low_stock_alert { return .low }
        return .inStock
    }
}

struct StockCategorySummary: Codable, Identifiable, Hashable {
    let category_id: Int?
    let category_name: String
    let item_count: Int
    let total_units: Int
    let cost_value: Double
    let retail_value: Double
    let potential_profit: Double
    let low_stock_count: Int
    let out_of_stock_count: Int
    let share_of_value: Double

    // Categories are grouped by name server-side (the "Uncategorised" bucket has no id),
    // so the name is what uniquely identifies a row here.
    var id: String { category_name }
}

struct StockReportResponse: Codable {
    let as_of: String
    let total_items: Int
    let total_stock_units: Int
    let total_cost_value: Double
    let total_retail_value: Double
    let potential_profit: Double
    let low_stock_count: Int
    let out_of_stock_count: Int
    let low_stock_items: [StockReportItem]
    let out_of_stock_items: [StockReportItem]
    let top_value_items: [StockReportItem]

    let items: [StockReportItem]?
    let categories: [StockCategorySummary]?

    /// Falls back to reconstructing the list from the attention buckets if the server
    /// predates the full-item payload, so filtering still shows something useful.
    var allItems: [StockReportItem] {
        if let items, !items.isEmpty { return items }
        var seen = Set<Int>()
        return (top_value_items + low_stock_items + out_of_stock_items).filter { seen.insert($0.id).inserted }
    }
}

struct StockMovement: Codable, Identifiable {
    let id: Int
    let item_id: Int
    let movement_type: String
    let quantity_change: Int
    let previous_quantity: Int
    let new_quantity: Int
    let reference: String?
    let note: String?
    let created_at: String
}

struct StockMovementListResponse: Codable {
    let movements: [StockMovement]
}

struct RestockRequestDTO: Codable {
    let quantity: Int
    let reference: String?
    let note: String?
}
