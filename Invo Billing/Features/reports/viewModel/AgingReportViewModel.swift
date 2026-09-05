import Combine
import Foundation

@MainActor
final class AgingReportViewModel: ObservableObject {

    @Published var report: AgingReportResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showAlert = false

    private let service = AgingReportService()

    func load() async {
        guard let companyID = SessionManager.shared.selectedCompanyId else {
            errorMessage = "Select a company first"
            showAlert = true
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            report = try await service.fetchAgingReport(companyID: companyID)
        } catch {
            errorMessage = "Couldn't load the aging report. Pull to retry."
            showAlert = true
        }
    }
}
