//
//  ClosingModels.swift
//  Invo Billing
//
//  Closing the day: what is on the floor, and what is in the drawer.
//

import Foundation

// MARK: - Counting the floor

/// One item as counted.
struct StocktakeLine: Codable, Identifiable {
    let item_id: Int
    let item_name: String
    let unit: String
    /// What the books said when it was counted, and what was found.
    let expected: Int
    let counted: Int

    var id: Int { item_id }

    /// Positive means more on the floor than the books had.
    var variance: Int { counted - expected }
    var isOff: Bool { variance != 0 }

    /// "4 short" / "2 extra" — read the way somebody would say it out loud.
    var varianceText: String {
        if variance == 0 { return "Matches" }
        let count = abs(variance)
        let unitText = unit.isEmpty ? "" : " \(unit.lowercased())"
        return variance < 0 ? "\(count)\(unitText) short" : "\(count)\(unitText) extra"
    }
}

struct Stocktake: Codable {
    let id: Int
    let status: String
    let note: String
    let started_at: String
    let applied_at: String
    let lines: [StocktakeLine]
    let items_counted: Int
    let items_off: Int

    var isDraft: Bool { status == "draft" }
}

struct StartStocktakeResponse: Codable {
    let stocktake_id: Int
}

struct ApplyStocktakeResponse: Codable {
    let message: String
    let items_adjusted: Int
}

// MARK: - Counting the drawer

/// One line of where the drawer's money came from or went.
struct CashLine: Codable, Identifiable {
    let label: String
    let amount: Double
    let count: Int

    var id: String { label }
}

/// One day's cash: what the drawer should hold against what was counted.
///
/// A till holds what was in it this morning, plus what came in, less what went out.
/// All three are kept so the screen can show the arithmetic rather than one figure
/// somebody has to take on faith.
struct DayClosing: Codable, Identifiable {
    let date: String
    let opening_cash: Double
    let cash_in: Double
    let cash_out: Double
    let expected_cash: Double
    let counted_cash: Double
    /// Counted less expected: negative is short, positive is over.
    let difference: Double
    let note: String
    let closed: Bool

    /// Where each side came from. Optional so a day with nothing on it still decodes.
    let in_breakdown: [CashLine]?
    let out_breakdown: [CashLine]?

    var id: String { date }

    var cashIn: [CashLine] { in_breakdown ?? [] }
    var cashOut: [CashLine] { out_breakdown ?? [] }

    var isShort: Bool { difference < -0.004 }
    var isOver: Bool { difference > 0.004 }

    /// Said in words. A minus sign in front of a rupee figure is read wrong about half
    /// the time, and this is the figure somebody acts on.
    var differenceText: String {
        if isShort { return "\(Money.text(abs(difference))) short" }
        if isOver { return "\(Money.text(difference)) over" }
        return "Tallies"
    }
}

struct DayClosingsResponse: Codable {
    let data: [DayClosing]
}
