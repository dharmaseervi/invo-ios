//
//  InvoiceDraft.swift
//  Invo Billing
//
//  A half-written invoice, kept so it survives the app going away.
//

import Foundation

/// An invoice as it stood while somebody was still writing it.
///
/// A draft outlives the app version that wrote it: somebody starts an invoice, the phone
/// updates overnight, and they come back to it in the morning. So every field here is
/// optional or defaulted, and a draft that cannot be read is dropped rather than
/// reported — see InvoiceDraftStore.
///
/// It keeps the customer and the items whole, rather than their ids, so that coming back
/// to an unfinished invoice never needs a working connection. That ties this format to
/// those two models; the trade-off is argued at `Line`.
struct InvoiceDraft: Codable {

    /// One line, holding the item as it was picked.
    ///
    /// The whole item rather than its id, so a draft can be restored with no network at
    /// all — a shop with one bar of signal is exactly the one that loses invoices. The
    /// cost is that this format follows ItemResponse: if that type ever changes shape,
    /// an old draft stops decoding and is quietly dropped. Losing an unfinished invoice
    /// that way is a disappointment the person can recover from in a minute; the
    /// alternative, a restore that needs the network, fails them when they need it.
    struct Line: Codable {
        let item: ItemResponse
        var qty: Int
        var rate: Double
        var discount: Double
        var taxRate: Double
    }

    /// Which shop this belongs to. A draft never crosses companies — switching shops
    /// must not surface a half-written invoice for the other one.
    let companyID: Int

    /// The customer as they were picked. Kept whole, for the same reason the items
    /// are: coming back to an unfinished invoice must not need a working connection.
    var client: ClientModel?

    var lines: [Line] = []
    var invoiceDate: Date = Date()
    var dueDate: Date = Date()
    var discount: Double = 0

    var savedAt: Date = Date()

    /// Worth keeping only if it holds work. A screen somebody opened and backed out of
    /// is not an unfinished invoice, and offering to restore one would be noise.
    var isWorthKeeping: Bool {
        client != nil || !lines.isEmpty
    }

    /// How it reads when offered back: "a few minutes ago", "yesterday".
    var age: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: savedAt, relativeTo: Date())
    }

    /// A one-line description of what is in it, so the person can tell whether it is
    /// worth going back to before they tap anything.
    var summary: String {
        let itemCount = lines.count
        let items = "\(itemCount) item\(itemCount == 1 ? "" : "s")"
        if let name = client?.name, !name.isEmpty {
            return itemCount == 0 ? name : "\(name) · \(items)"
        }
        return itemCount == 0 ? "Nothing added yet" : items
    }
}

/// Where an unfinished invoice waits.
///
/// On disk rather than in UserDefaults: a long invoice is a few kilobytes of JSON, and
/// UserDefaults is for small settings. One file per company, so two shops cannot hand
/// each other a draft.
///
/// Every operation here fails quietly. Losing a draft is a disappointment; a crash in
/// the middle of writing an invoice because a file could not be written is much worse,
/// and autosave is a convenience that must never be the thing that breaks the screen.
enum InvoiceDraftStore {

    private static let folderName = "InvoiceDrafts"

    /// Drafts older than this are not offered back. A month-old invoice is not
    /// something anybody is still in the middle of; prices and stock have moved on,
    /// and restoring it would do more harm than starting again.
    private static let maximumAge: TimeInterval = 30 * 24 * 60 * 60

    private static func folder() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        let directory = base.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func url(companyID: Int) throws -> URL {
        try folder().appendingPathComponent("company-\(companyID).json")
    }

    static func save(_ draft: InvoiceDraft) {
        guard draft.isWorthKeeping else {
            // Everything was cleared back out. The draft goes with it, rather than
            // leaving a stale one to be offered on the next visit.
            discard(companyID: draft.companyID)
            return
        }
        do {
            var copy = draft
            copy.savedAt = Date()
            let data = try JSONEncoder().encode(copy)
            try data.write(to: url(companyID: draft.companyID), options: .atomic)
        } catch {
            // Nothing to tell the person: they did not ask for this to happen.
        }
    }

    static func load(companyID: Int) -> InvoiceDraft? {
        do {
            let data = try Data(contentsOf: url(companyID: companyID))
            let draft = try JSONDecoder().decode(InvoiceDraft.self, from: data)

            guard Date().timeIntervalSince(draft.savedAt) < maximumAge else {
                discard(companyID: companyID)
                return nil
            }
            guard draft.isWorthKeeping else { return nil }
            return draft
        } catch {
            // No draft, or one written by a version that stored something else. Either
            // way there is nothing to go back to, and nothing worth saying about it.
            return nil
        }
    }

    static func discard(companyID: Int) {
        try? FileManager.default.removeItem(at: url(companyID: companyID))
    }
}
