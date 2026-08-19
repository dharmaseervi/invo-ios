//
//  DashboardMetrics.swift
//  Invo Billing
//
//  Created by dharmaseervi on 2/2/26.
//

struct DashboardResponse: Codable {
    let period: String
    let revenue: RevenueBlock
    let counts: CountBlock
    let recentInvoices: [RecentInvoice]
    
    enum CodingKeys: String, CodingKey {
        case period
        case revenue
        case counts
        case recentInvoices = "recent_invoices"
    }
}

struct RevenueBlock: Codable {
    let total: Double
    let changePercent: Double
    
    enum CodingKeys: String, CodingKey {
        case total
        case changePercent = "change_percent"
    }
}

struct CountBlock: Codable {
    let invoices: Int
    let clients: Int
    let items: Int
}

struct RecentInvoice: Identifiable, Codable {
    let id: Int
    let invoiceNumber: String
    let clientName: String
    let total: Double
    let status: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case invoiceNumber = "invoice_number"
        case clientName = "client_name"
        case total
        case status
        case createdAt = "created_at"
    }
}
