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
    
    func load(period: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let companyId = SessionManager.shared.selectedCompanyId else {
            errorMessage = "Select company first"
            return
        }
        do {
            dashboard = try await service
                .fetchDashboard(period: period, companyId: companyId)
        } catch let authErr as AuthErrorResponse {
            errorMessage = authErr.error
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
