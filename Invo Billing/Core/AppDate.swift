//
//  AppDate.swift
//  Invo Billing
//

import Foundation

/// Every date the app parses, sends or shows goes through here.
///
/// The app previously built a `DateFormatter` wherever it needed one — thirty of them —
/// and none pinned a locale or a calendar. A `DateFormatter` with `dateFormat` set but
/// the device's own locale formats in the device's *calendar*, so on a phone set to the
/// Indian National calendar an invoice dated 12 September 2026 serialised as
/// `1948-06-21` and that is what reached the server. A GST invoice filed with a date
/// seventy-eight years wrong is not a cosmetic problem, and it would only ever have
/// shown up on customers' devices, never on a developer's.
///
/// So: ``wire`` is pinned to `en_US_POSIX` and the Gregorian calendar and is the only
/// thing that touches the API. Display formatters follow the user's language but stay
/// Gregorian, because the date on a tax invoice is a Gregorian date by law.
enum AppDate {

    /// The API's date format. Pinned, and never used for display.
    private static let wire: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        return f
    }()

    /// Timestamps the API returns for created_at and similar.
    private static let wireTimestamp: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func display(_ template: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = .current
        f.calendar = Calendar(identifier: .gregorian)
        f.setLocalizedDateFormatFromTemplate(template)
        return f
    }

    private static let dayMonthYear = display("ddMMMyyyy")   // 12 Sept 2026
    private static let dayMonthOnly = display("ddMMM")       // 12 Sept
    private static let monthYearOnly = display("MMMMyyyy")   // September 2026
    private static let weekdayOnly = display("EEEEE")        // S

    // MARK: - Wire

    /// `2026-09-12` for the API. Correct regardless of the device's calendar.
    static func wireString(from date: Date) -> String {
        wire.string(from: date)
    }

    /// Parses an API date. Accepts a bare `yyyy-MM-dd` or a full timestamp, because the
    /// API returns both depending on the endpoint.
    static func date(fromWire value: String) -> Date? {
        if let d = wire.date(from: value) { return d }
        if let d = wireTimestamp.date(from: value) { return d }
        // Timestamps without fractional seconds.
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }

    // MARK: - Display

    /// `12 Sept 2026`.
    static func text(_ date: Date) -> String { dayMonthYear.string(from: date) }

    /// `12 Sept`, for lists where the year is obvious.
    static func shortText(_ date: Date) -> String { dayMonthOnly.string(from: date) }

    /// `September 2026`.
    static func monthYear(_ date: Date) -> String { monthYearOnly.string(from: date) }

    /// `S`, a single-letter weekday for a chart axis.
    static func weekdayInitial(_ date: Date) -> String { weekdayOnly.string(from: date) }

    // MARK: - Display, straight from an API string

    /// Formats an API date for display. Returns the input untouched if it cannot be
    /// parsed, so a surprising server value is visible rather than silently blank.
    static func text(fromWire value: String) -> String {
        guard let d = date(fromWire: value) else { return value }
        return text(d)
    }

    static func shortText(fromWire value: String) -> String {
        guard let d = date(fromWire: value) else { return value }
        return shortText(d)
    }

    static func weekdayInitial(fromWire value: String) -> String {
        guard let d = date(fromWire: value) else { return "" }
        return weekdayInitial(d)
    }
}
