import Combine
import Foundation

@MainActor
final class AgingReportViewModel: ObservableObject {

    @Published var report: AgingReportResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showAlert = false

    private let service = AgingReportService()

    func exportCSV() -> URL? {
        guard let report = report else { return nil }
        var lines = ["Client,Current,1-30d,31-60d,61-90d,90d+,Total"]
        for row in report.clients {
            let b = row.buckets
            lines.append("\(row.client_name),\(b.current),\(b.days_1_30),\(b.days_31_60),\(b.days_61_90),\(b.days_90_plus),\(row.total)")
        }
        let totals = report.totals
        lines.append("TOTAL,\(totals.current),\(totals.days_1_30),\(totals.days_31_60),\(totals.days_61_90),\(totals.days_90_plus),\(report.grand_total)")
        let csv = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("AgingReport.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

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
