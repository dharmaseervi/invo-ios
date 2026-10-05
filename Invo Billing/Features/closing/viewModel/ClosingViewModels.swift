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

    @Published var errorMessage: String?
    @Published var showError = false
    @Published var message: String?

    private let service = ClosingService()

    var expected: Double { today?.expected_cash ?? 0 }
    var opening: Double { today?.opening_cash ?? 0 }

    func load(date: Date) async {
        guard let companyID = SessionManager.shared.selectedCompanyId else {
            show("Select a company first.")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Both together: the day being closed and the days behind it are read on
            // the same screen and should never be a refresh apart.
            async let day = service.dayClosing(companyID: companyID, date: date)
            async let history = service.recentClosings(companyID: companyID)
            let (loadedDay, loadedHistory) = try await (day, history)
            today = loadedDay
            recent = loadedHistory
        } catch {
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
