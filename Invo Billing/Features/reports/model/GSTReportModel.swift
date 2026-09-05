import Foundation

struct GSTReportResponse: Codable {
    let start: String
    let end: String
    let company_state: String
    let summary: GSTSummary
    let invoices: [GSTInvoiceSummaryRow]
    let hsn_summary: [GSTHSNSummaryRow]
}

struct GSTSummary: Codable {
    let invoice_count: Int
    let taxable_value: Double
    let cgst: Double
    let sgst: Double
    let igst: Double
    let total: Double
}

struct GSTInvoiceSummaryRow: Codable, Identifiable {
    let invoice_id: Int
    let invoice_number: String
    let invoice_date: String
    let client_name: String
    let client_gstin: String
    let place_of_supply: String
    let taxable_value: Double
    let cgst: Double
    let sgst: Double
    let igst: Double
    let total: Double

    var id: Int { invoice_id }
}

struct GSTHSNSummaryRow: Codable, Identifiable {
    let hsn_code: String
    let tax_rate: Double
    let total_qty: Double
    let taxable_value: Double
    let cgst: Double
    let sgst: Double
    let igst: Double
    let total_value: Double

    var id: String { "\(hsn_code)-\(tax_rate)" }
}
