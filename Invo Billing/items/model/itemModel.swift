//
//  itemModel.swift
//  invo
//
//  Created by dharmaseervi on 11/23/25.
//

struct ItemRequestDTO: Codable {
    let company_id: Int
    let name: String
    let category_id: Int?     // <-- FIX NAME
    let sku: String
    let hsn_code: String       // ← add
    let description: String
    let cost_price: Double
    let price: Double
    let quantity: Int
    let low_stock_alert: Int
    let tax_rate: Double
}

struct CategoryModel: Codable, Identifiable {
    let id: Int
    let name: String
}

struct CategoryRequest: Codable{
    let name: String
    let company_id: Int
}

struct CategoryResponse: Codable, Identifiable {
    let id: Int
    let name: String
    let user_id: Int
    let company_id: Int
}

struct CategoryListResponse: Codable {
    let categories: [CategoryResponse]
}

struct ItemResponse: Codable, Identifiable {
    let id: Int
    let name: String
    let category_id: Int?
    let hsn_code: String?       // ← add
    let sku: String?
    let unit: String?
    let description: String?
    let cost_price: Double?
    let price: Double
    let quantity: Int
    let low_stock_alert: Int?
    let tax_rate: Double?
    let company_id: Int
    let user_id: Int
}

struct ItemListResponse: Codable {
    let items: [ItemResponse]
}
