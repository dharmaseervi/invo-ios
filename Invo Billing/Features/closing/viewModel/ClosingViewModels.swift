//
//  ClosingViewModels.swift
//  Invo Billing
//

import Combine
import Foundation

// MARK: - Counting the floor

@MainActor
final class StocktakeViewModel: ObservableObject {

    @Published private(set) var stocktake: Stocktake?
    @Published private(set) var isLoading = false
    @Published private(set) var isWorking = false

    @Published var errorMessage: String?
    @Published var showError = false
    @Published var message: String?

    private let service = ClosingService()

    /// Identifies the newest load, so a slow reply cannot land on top of a count that
    /// has moved on — a line reappearing with the figure it had before a recount.
    private var requestID = 0

    var lines: [StocktakeLine] { stocktake?.lines ?? [] }
    var itemsOff: Int { stocktake?.items_off ?? 0 }
    var hasCounted: Bool { !(stocktake?.lines.isEmpty ?? true) }

    /// Opens the count, or picks up the one already open. Called when the screen
    /// appears, because a shopkeeper who put the phone down halfway through counting
    /// should come back to where they were.
    func begin() async {
        guard let companyID = SessionManager.shared.selectedCompanyId else {
            show("Select a company first.")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let id = try await service.startStocktake(companyID: companyID, note: "")
            await reload(stocktakeID: id)
        } catch {
            show(error.localizedDescription)
        }
    }

    func reload(stocktakeID: Int? = nil) async {
        guard let companyID = SessionManager.shared.selectedCompanyId,
              let id = stocktakeID ?? stocktake?.id else { return }

        requestID += 1
        let request = requestID

        do {
            let loaded = try await service.stocktake(companyID: companyID, id: id)
            guard request == requestID else { return }
            stocktake = loaded
        } catch {
            guard request == requestID else { return }
            show(error.localizedDescription)
        }
    }

    func count(itemID: Int, counted: Int) async {
        guard let companyID = SessionManager.shared.selectedCompanyId,
              let id = stocktake?.id else { return }

        isWorking = true
        defer { isWorking = false }

        do {
            try await service.count(
                companyID: companyID, stocktakeID: id, itemID: itemID, counted: counted
            )
            await reload()
        } catch {
            show(error.localizedDescription)
        }
    }

    func apply() async -> Bool {
        guard let companyID = SessionManager.shared.selectedCompanyId,
              let id = stocktake?.id else { return false }

        isWorking = true
        defer { isWorking = false }

        do {
            let adjusted = try await service.applyStocktake(companyID: companyID, id: id)
            message = adjusted == 0
                ? "Everything matched. Nothing to change."
                : "Stock corrected for \(adjusted) item\(adjusted == 1 ? "" : "s")."
            stocktake = nil
            return true
        } catch {
            show(error.localizedDescription)
            return false
        }
    }

    func abandon() async -> Bool {
        guard let companyID = SessionManager.shared.selectedCompanyId,
              let id = stocktake?.id else { return false }

        isWorking = true
        defer { isWorking = false }

        do {
            try await service.abandonStocktake(companyID: companyID, id: id)
            stocktake = nil
            return true
        } catch {
            show(error.localizedDescription)
            return false
        }
    }

    private func show(_ text: String) {
        errorMessage = text
        showError = true
    }
}

// MARK: - Counting the drawer

@MainActor
final class CashClosingViewModel: ObservableObject {

    @Published private(set) var today: DayClosing?
    @Published private(set) var recent: [DayClosing] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isWorking = false
    /// The day's figures could not be fetched. Kept apart from "not loaded yet" so the
    /// screen can offer another go instead of sitting blank.
    @Published private(set) var loadFailed = false

    @Published var errorMessage: String?
    @Published var showError = false
    @Published var message: String?

    private let service = ClosingService()

    /// Identifies the newest load. Switching days starts another while the first is
    /// still out, and without this the slower reply wins — one day's figures landing
    /// under another day's date.
    private var requestID = 0

    /// Which day the figures on screen actually describe. Nil means nothing trustworthy
    /// is loaded, whatever is left in `today`.
    private var loadedDate: Date?

    var expected: Double { today?.expected_cash ?? 0 }
    var opening: Double { today?.opening_cash ?? 0 }

    /// True only when the figures belong to the day being looked at.
    ///
    /// Closing a drawer is writing a number somebody will be held to, and the three ways
    /// this screen could previously be wrong all ended the same way: a count saved
    /// against another day's expected figure. Saving waits for this.
    func isReady(for date: Date) -> Bool {
        guard !isLoading, !isWorking, today != nil, let loaded = loadedDate else { return false }
        return Calendar.current.isDate(loaded, inSameDayAs: date)
    }

    func load(date: Date) async {
        guard let companyID = SessionManager.shared.selectedCompanyId else {
            show("Select a company first.")
            return
        }

        requestID += 1
        let request = requestID

        // Figures for one day must never sit under another day's heading. Anything
        // loaded for a different date goes now, before the wait, rather than lingering
        // on screen while the new day is fetched.
        if loadedDate.map({ !Calendar.current.isDate($0, inSameDayAs: date) }) ?? true {
            today = nil
            loadedDate = nil
        }
        loadFailed = false
        isLoading = true
        defer { if request == requestID { isLoading = false } }

        do {
            // Both together: the day being closed and the days behind it are read on
            // the same screen and should never be a refresh apart.
            async let day = service.dayClosing(companyID: companyID, date: date)
            async let history = service.recentClosings(companyID: companyID)
            let (loadedDay, loadedHistory) = try await (day, history)
            guard request == requestID else { return }
            today = loadedDay
            recent = loadedHistory
            loadedDate = date
        } catch {
            guard request == requestID else { return }
            // Cleared, not kept. Leaving the last day's figures up after a failure is
            // how somebody counts a drawer against the wrong expectation.
            today = nil
            loadedDate = nil
            loadFailed = true
            show(error.localizedDescription)
        }
    }

    func close(date: Date, counted: Double, opening: Double?, note: String) async -> Bool {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return false }

        isWorking = true
        defer { isWorking = false }

        do {
            let closing = try await service.closeDay(
                companyID: companyID, date: date, counted: counted,
                opening: opening, note: note
            )
            today = closing
            loadedDate = date
            message = closing.difference == 0
                ? "Counted and it tallies."
                : "Counted. \(closing.differenceText)."
            await load(date: date)
            return true
        } catch {
            show(error.localizedDescription)
            return false
        }
    }

    private func show(_ text: String) {
        errorMessage = text
        showError = true
    }
}
