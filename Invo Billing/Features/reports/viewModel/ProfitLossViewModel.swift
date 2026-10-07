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
}
