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
    
    /// Identifies the newest load, so a reply that is no longer the one being waited
    /// for can be thrown away.
    ///
    /// Switching company or period twice quickly left whichever reply came back last on
    /// the screen — a shop looking at another company's figures under its own name, or
    /// last month's under "This month". A counter rather than a comparison of company
    /// and period, because A → B → A makes two requests for A that look identical, and
    /// the first one answering last would still be stale.
    private var requestCounter = 0
    private var currentRequest = 0

    func load(period: String) async {
        guard let companyId = SessionManager.shared.selectedCompanyId else {
            errorMessage = "Select company first"
            isLoading = false
            return
        }

        requestCounter += 1
        let request = requestCounter
        currentRequest = request
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
    private func isCurrent(_ request: Int) -> Bool { request == currentRequest }
}
