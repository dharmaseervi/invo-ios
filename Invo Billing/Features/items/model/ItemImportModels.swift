//
//  ItemImportModels.swift
//  Invo Billing
//
//  Bringing a product catalogue in from a spreadsheet.
//
//  The shapes here mirror the server's: it reads the file, decides which column means
//  what, and says what is wrong with each row. None of that happens on the phone,
//  because the same answer has to come out whichever app the file is dropped into — and
//  because "why did it import differently on my iPad" is not a conversation worth having.
//

import Foundation

/// A field a column can feed.
enum ImportColumn: String, Codable, CaseIterable, Identifiable {
    /// Not imported. The empty string is how the server is told to leave a column
    /// alone, as opposed to being left to guess at it.
    case ignore = ""
    case name, sku
    case hsnCode = "hsn_code"
    case unit, price
    case costPrice = "cost_price"
    case quantity
    case taxRate = "tax_rate"
    case lowStockAlert = "low_stock_alert"
    case description

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ignore: return "Don't import"
        case .name: return "Name"
        case .sku: return "SKU"
        case .hsnCode: return "HSN code"
        case .unit: return "Unit"
        case .price: return "Selling price"
        case .costPrice: return "Cost price"
        case .quantity: return "Stock"
        case .taxRate: return "GST rate"
        case .lowStockAlert: return "Low-stock alert"
        case .description: return "Description"
        }
    }
}

/// One row's product, as the server parsed it.
struct ImportItem: Codable, Equatable {
    var name: String = ""
    var sku: String = ""
    var hsn_code: String = ""
    var unit: String = ""
    var description: String = ""
    var price: Double = 0
    var cost_price: Double = 0
    var quantity: Int = 0
    var tax_rate: Double = 0
    var low_stock_alert: Int = 0
}

/// A product already in the catalogue that this row appears to be.
struct ImportDuplicate: Codable, Equatable {
    let item_id: Int
    /// "sku" or "name". An SKU match is a fact; a name match is a guess, and the screen
    /// says which so the person can judge it.
    let matched_on: String
    let name: String
    let sku: String
    let price: Double
    let quantity: Int

    var matchedOnSKU: Bool { matched_on == "sku" }
}

struct ImportRow: Codable, Identifiable, Equatable {
    /// The line in their file, header counted as line 1, so a problem can be found in
    /// the spreadsheet rather than in a list that cannot be mapped back to it.
    let line: Int
    let item: ImportItem
    let errors: [String]?
    let warnings: [String]?
    let duplicate: ImportDuplicate?

    var id: Int { line }
    var problems: [String] { errors ?? [] }
    var notes: [String] { warnings ?? [] }
    var canImport: Bool { problems.isEmpty }
}

struct ImportSummary: Codable, Equatable {
    let total: Int
    let valid: Int
    let invalid: Int
    let duplicates: Int

    static let empty = ImportSummary(total: 0, valid: 0, invalid: 0, duplicates: 0)
}

struct ImportPreview: Codable {
    let headers: [String]
    let mapping: [String: ImportColumn]
    /// Fields no column was found for. Name and price being here is why an import
    /// cannot go ahead.
    let missing: [ImportColumn]?
    let rows: [ImportRow]
    let summary: ImportSummary
}

/// What to do with one row.
struct ImportAction: Codable {
    let line: Int
    /// "create", "update" or "skip".
    let action: String
    var item_id: Int = 0
    let item: ImportItem
}

struct ImportFailure: Codable, Identifiable {
    let line: Int
    let name: String
    let reason: String

    var id: Int { line }
}

struct ImportResult: Codable {
    let created: Int
    let updated: Int
    let skipped: Int
    let failed: [ImportFailure]?
}
