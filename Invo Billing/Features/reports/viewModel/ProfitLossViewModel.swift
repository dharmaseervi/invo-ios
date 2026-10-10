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

    func load() async {
        guard let companyID = SessionManager.shared.selectedCompanyId else {
            errorMessage = "Select a company first."
            showAlert = true
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            report = try await service.fetch(companyID: companyID, period: selectedPeriod.rawValue)
        } catch {
            errorMessage = "Couldn't load the report. Pull to retry."
            showAlert = true
        }
    }

    func exportCSV() -> URL? {
        guard let r = report else { return nil }
        var csv = "Profit & Loss — \(r.period)\n"
        csv += "From,\(r.from)\nTo,\(r.to)\n\n"
        csv += "Metric,Amount\n"
        csv += "Revenue,\(r.revenue)\n"
        csv += "Purchases,\(r.purchases)\n"
        csv += "Expenses,\(r.expenses)\n"
        csv += "Gross Profit,\(r.gross_profit)\n"
        csv += "Net Profit,\(r.net_profit)\n"
        csv += "Gross Margin %,\(r.gross_margin_pct)\n"
        csv += "Net Margin %,\(r.net_margin_pct)\n"
        csv += "Invoices,\(r.invoice_count)\n"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ProfitLoss_\(r.period).csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
