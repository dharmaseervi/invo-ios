//
//  DashboardViewModel.swift
//  Invo Billing
//
//  Created by dharmaseervi on 2/2/26.
//

import Foundation
import Combine


@MainActor
final class DashboardViewModel: ObservableObject {
    
    @Published var dashboard: DashboardResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let service = DashboardService()
    
    /// What the last started load was for, so a reply that is no longer the thing on
    /// screen can be thrown away.
    ///
    /// Switching company or period twice quickly left whichever reply happened to come
    /// back last on the screen — so a shop could be looking at another company's figures
    /// under its own name, or last month's under "This month".
    private var inFlight: (company: Int, period: String)?

    func load(period: String) async {
        guard let companyId = SessionManager.shared.selectedCompanyId else {
            errorMessage = "Select company first"
            isLoading = false
            return
        }

        let request = (company: companyId, period: period)
        inFlight = request
        isLoading = true
        errorMessage = nil

        do {
            let result = try await service.fetchDashboard(period: period, companyId: companyId)
            guard isCurrent(request) else { return }
            dashboard = result
            isLoading = false
        } catch let authErr as AuthErrorResponse {
            guard isCurrent(request) else { return }
            errorMessage = authErr.error
            isLoading = false
        } catch {
            guard isCurrent(request) else { return }
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// True when this reply is still the one being waited for. A superseded load also
    /// leaves `isLoading` alone, so the spinner belongs to the load still running.
    private func isCurrent(_ request: (company: Int, period: String)) -> Bool {
        inFlight?.company == request.company && inFlight?.period == request.period
    }
}
