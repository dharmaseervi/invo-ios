import Foundation

struct LedgerEntryModel: Identifiable, Codable {
    
    let id: Int
    let companyID: Int
    let clientID: Int
    
    let sourceType: LedgerSourceType
    let sourceID: Int
    
    let debit: Double
    let credit: Double
    let balance: Double
    
    let description: String?
    let createdAt: Date
    
    let clientName: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case companyID = "company_id"
        case clientID = "client_id"
        case clientName = "client_name"
        case sourceType = "source_type"
        case sourceID = "source_id"
        case debit
        case credit
        case balance
        case description
        case createdAt = "created_at"
    }
}

enum LedgerSourceType: String, Codable {
    case invoice = "INVOICE"
    case payment = "PAYMENT"
    case creditNote = "CREDIT_NOTE"
    case opening = "OPENING"
}



struct LedgerResponse: Codable {
    let data: [LedgerEntryModel]
}

struct ClientLedger: Identifiable {
    let id: Int      // clientID
    let clientID: Int
    let clientName: String   // ✅ ADD THIS
    let totalDebit: Double
    let totalCredit: Double
    let balance: Double
}
