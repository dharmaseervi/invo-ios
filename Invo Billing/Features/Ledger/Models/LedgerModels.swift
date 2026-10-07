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

/// What a ledger entry came from.
///
/// ADJUSTMENT was missing, and because an unknown value makes Codable throw, one
/// cancelled invoice in a customer's history made their entire statement fail to load —
/// not the one row, the whole response. Found on a device: the oldest page of a
/// customer's ledger would not decode.
///
/// So unknown values now fall back to `.other` rather than throwing. The server can add
/// a source type without blanking a statement in every copy of the app already on a
/// phone, which is the kind of change this app cannot ship a fix for quickly.
enum LedgerSourceType: String, Codable {
    case invoice = "INVOICE"
    case payment = "PAYMENT"
    case creditNote = "CREDIT_NOTE"
    case opening = "OPENING"
    /// Written when an invoice is cancelled: the reversing entry.
    case adjustment = "ADJUSTMENT"
    case other

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = LedgerSourceType(rawValue: raw) ?? .other
    }
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

/// A customer's standing, counted by the server over their whole history.
///
/// The screens used to sum the rows they had fetched, which meant downloading a
/// business's entire ledger to draw a list of names and balances — and would have meant
/// showing a page's totals as a customer's totals once those rows were paged.
struct LedgerSummaryModel: Codable, Identifiable {
    let client_id: Int
    let client_name: String
    let debit: Double
    let credit: Double
    let balance: Double
    let entries: Int

    var id: Int { client_id }

    var asClientLedger: ClientLedger {
        ClientLedger(
            id: client_id, clientID: client_id, clientName: client_name,
            totalDebit: debit, totalCredit: credit, balance: balance
        )
    }

    static let empty = LedgerSummaryModel(
        client_id: 0, client_name: "", debit: 0, credit: 0, balance: 0, entries: 0
    )
}

/// The business's ledger position across every customer, counted by the server.
///
/// Receivable and payable are separate: a customer in credit does not reduce what the
/// others owe, and one netted figure hides both.
struct CompanyLedgerTotals: Codable {
    let receivable: Double
    let payable: Double
    let clients: Int

    static let empty = CompanyLedgerTotals(receivable: 0, payable: 0, clients: 0)
}

/// A page of customer rows and the totals that describe all of them.
struct CompanyLedgerPage {
    let rows: [LedgerSummaryModel]
    /// nil when the totals could not be read, so the screen can say "unavailable"
    /// rather than showing zeroes.
    let totals: CompanyLedgerTotals?
}
