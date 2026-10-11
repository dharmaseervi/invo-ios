import Combine
import Foundation

@MainActor
final class SupplierAgingViewModel: ObservableObject {
    @Published var report: SupplierAgingReport?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showAlert = false

    private let service = SupplierAgingService()

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
            report = try await service.fetchReport(companyID: companyID)
        } catch {
            errorMessage = "Couldn't load the supplier aging report. Pull to retry."
            showAlert = true
        }
    }

    func exportCSV() -> URL? {
        guard let report = report else { return nil }
        var lines = ["Supplier,Current,1-30d,31-60d,61-90d,90d+,Total"]
        for row in report.suppliers {
            let b = row.buckets
            lines.append("\(row.supplier_name),\(b.current),\(b.days_1_30),\(b.days_31_60),\(b.days_61_90),\(b.days_90_plus),\(row.total)")
        }
        let t = report.totals
        lines.append("TOTAL,\(t.current),\(t.days_1_30),\(t.days_31_60),\(t.days_61_90),\(t.days_90_plus),\(report.grand_total)")
        let csv = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("SupplierAgingReport.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
