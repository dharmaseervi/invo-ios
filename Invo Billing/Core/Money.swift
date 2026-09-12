//
//  Money.swift
//  Invo Billing
//

import Foundation

/// Every rupee figure in the app goes through here.
///
/// Before this existed the same amount was written three different ways depending on
/// which screen you were on — `₹14K`, `₹5310`, `₹5310.00` — from fifty separate
/// `String(format: "%.2f")` call sites, and none of them grouped digits. A stock report
/// of six-figure sums read `₹548632.00`, which is not how anyone in India writes money.
///
/// Three renderings, because they are genuinely three different jobs:
///
/// - ``text(_:)`` for anything a user reads. Grouped the Indian way, always two
///   decimals: `₹5,48,632.00`.
/// - ``compact(_:)`` for headline figures where the exact paisa is noise and the
///   magnitude is the point: `₹5.49L`.
/// - ``editable(_:)`` for the value of a text field, and for CSV. Plain digits with no
///   symbol and no separators, because a grouped string cannot be parsed back into a
///   number by `Double(_:)` and would break the field the moment the user edits it.
enum Money {

    /// Formatters are expensive to build and these are called per row while scrolling.
    private static let display: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "en_IN")
        f.currencyCode = "INR"
        f.currencySymbol = "₹"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        // A true minus sign rather than a hyphen, and before the symbol: "−₹380.00",
        // not "₹-380.00".
        f.negativePrefix = "−₹"
        return f
    }()

    private static let plain: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_IN")
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    /// `₹5,48,632.00` — for display. Negative values read `−₹380.00`.
    static func text(_ value: Double) -> String {
        guard value.isFinite else { return "₹0.00" }
        return display.string(from: NSNumber(value: value)) ?? "₹\(plainString(value))"
    }

    /// `₹5.49L`, `₹14.2K`, `₹950.00` — for headline figures only.
    ///
    /// Lakhs and thousands rather than millions, because that is how the number is
    /// spoken by the people using this app.
    static func compact(_ value: Double) -> String {
        guard value.isFinite else { return "₹0.00" }
        let magnitude = abs(value)
        let sign = value < 0 ? "−" : ""

        if magnitude >= 100_000 {
            return "\(sign)₹\(trimZero(magnitude / 100_000))L"
        }
        if magnitude >= 1_000 {
            return "\(sign)₹\(trimZero(magnitude / 1_000))K"
        }
        return text(value)
    }

    /// `5310.00` — for a text field's value and for CSV. No symbol, no separators.
    static func editable(_ value: Double) -> String {
        guard value.isFinite else { return "0.00" }
        return plainString(value)
    }

    private static func plainString(_ value: Double) -> String {
        plain.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    /// One decimal place, but `5.0L` reads better as `5L`.
    private static func trimZero(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? String(Int(rounded))
            : String(format: "%.1f", rounded)
    }
}
