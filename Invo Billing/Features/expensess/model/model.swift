//
//  model.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/19/25.
//

import Foundation



// MARK: - Expense Model
struct Expense: Codable, Identifiable {
    let id: Int
    let userId: Int
    let companyId: Int
    let name: String
    let amount: Double
    let description: String?
    let date: String
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case companyId = "company_id"
        case name
        case amount
        case description
        case date
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Create Expense Payload
struct ExpenseCreatePayload: Codable {
    let companyId: Int
    let name: String
    let amount: Double
    let description: String?
    let date: String
    
    enum CodingKeys: String, CodingKey {
        case companyId = "company_id"
        case name
        case amount
        case description
        case date
    }
    
    init(
        companyId: Int,
        name: String,
        amount: Double,
        description: String? = nil,
        date: String
    ) {
        self.companyId = companyId
        self.name = name
        self.amount = amount
        self.description = description
        self.date = date
    }
}

// MARK: - Update Expense Payload
struct ExpenseUpdatePayload: Codable {
    let name: String?
    let amount: Double?
    let description: String?
    let date: String?
    
    init(
        name: String? = nil,
        amount: Double? = nil,
        description: String? = nil,
        date: String? = nil
    ) {
        self.name = name
        self.amount = amount
        self.description = description
        self.date = date
    }
}

// MARK: - API Response Models

// Single Expense Response
struct ExpenseDetailResponse: Codable {
    let expense: Expense
}

// Multiple Expenses Response
struct ExpenseListResponse: Codable {
    let expenses: [Expense]
}

// Stats Response
struct ExpenseStatsResponse: Codable {
    let stats: ExpenseStats
    
    struct ExpenseStats: Codable {
        let totalAmount: Double
        let expenseCount: Int
        let averageAmount: Double
        
        enum CodingKeys: String, CodingKey {
            case totalAmount = "total_amount"
            case expenseCount = "expense_count"
            case averageAmount = "average_amount"
        }
    }
}
