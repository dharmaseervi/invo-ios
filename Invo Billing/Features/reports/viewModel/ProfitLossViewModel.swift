//
//  ProfitLossViewModel.swift
//  Invo Billing
//

import Combine
import Foundation

@MainActor
final class ProfitLossViewModel: ObservableObject {

    enum Period: String, CaseIterable, Identifiable {
        case month = "month"
        case quarter = "quarter"
        case financialYear = "financial-year"
        case year = "year"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .month:        return "This month"
            case .quarter:      return "3 months"
            case .financialYear: return "FY"
            case .year:         return "Calendar year"
            }
        }
    }

    @Published var selectedPeriod: Period = .month
    @Published var report: ProfitLossResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showAlert = false

    private let service = ProfitLossService()

    private var loadID = UUID()
    private var loadedCompanyID: Int?
    private var loadedPeriod: Period?
    var canExport: Bool { report != nil && !isLoading && errorMessage == nil && loadedCompanyID == SessionManager.shared.selectedCompanyId && loadedPeriod == selectedPeriod }

    func load() async {
        guard let companyID = SessionManager.shared.selectedCompanyId else {
            errorMessage = "Select a company first."
            showAlert = true
            return
        }
        let request = UUID()
        loadID = request
        let period = selectedPeriod
        if loadedCompanyID != companyID || loadedPeriod != period { report = nil }
        isLoading = true
        errorMessage = nil
        defer { if request == loadID { isLoading = false } }
        do {
            let result = try await service.fetch(companyID: companyID, period: period.rawValue)
            guard request == loadID, companyID == SessionManager.shared.selectedCompanyId, period == selectedPeriod else { return }
            report = result
            loadedCompanyID = companyID
            loadedPeriod = period
        } catch {
            guard request == loadID, companyID == SessionManager.shared.selectedCompanyId, period == selectedPeriod else { return }
            errorMessage = "Couldn't load the report. Tap Retry to try again."
            showAlert = true
        }
    }

    func exportCSV() -> URL? {
        guard canExport, let r = report else { return nil }
        var csv = "Business summary — \(r.period)\n"
        csv += "From,\(r.from)\nTo,\(r.to)\n\n"
        csv += "Metric,Amount\n"
        csv += "Invoice sales (including tax),\(r.revenue)\n"
        csv += "Purchases,\(r.purchases)\n"
        csv += "Expenses,\(r.expenses)\n"
        csv += "Sales less purchases,\(r.gross_profit)\n"
        csv += "After expenses,\(r.net_profit)\n"
        csv += "Sales less purchases %,\(r.gross_margin_pct)\n"
        csv += "After expenses %,\(r.net_margin_pct)\n"
        csv += "Invoices,\(r.invoice_count)\n"
        csv += "\nScope,\(SafeCSV.text("Includes tax and all purchases in the period, not the cost of inventory sold. Credit notes and purchase returns are not deducted. This is not an accounting profit statement."))\n"
        do { return try SafeCSV.write(csv, filename: "BusinessSummary_\(r.from)_\(r.to).csv") }
        catch {
            errorMessage = "Couldn't save the CSV: \(error.localizedDescription)"
            showAlert = true
            return nil
        }
    }
}
