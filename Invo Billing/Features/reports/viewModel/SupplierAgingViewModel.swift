import Combine
import Foundation

@MainActor
final class SupplierAgingViewModel: ObservableObject {
    @Published var report: SupplierAgingReport?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showAlert = false

    private let service = SupplierAgingService()

    private var loadID = UUID()
    private var loadedCompanyID: Int?

    var canExport: Bool { report != nil && !isLoading && errorMessage == nil && loadedCompanyID == SessionManager.shared.selectedCompanyId }

    func load() async {
        guard let companyID = SessionManager.shared.selectedCompanyId else {
            errorMessage = "Select a company first"
            showAlert = true
            return
        }
        let request = UUID()
        loadID = request
        if loadedCompanyID != companyID { report = nil }
        isLoading = true
        errorMessage = nil
        defer { if request == loadID { isLoading = false } }
        do {
            let result = try await service.fetchReport(companyID: companyID)
            guard request == loadID, companyID == SessionManager.shared.selectedCompanyId else { return }
            report = result
            loadedCompanyID = companyID
        } catch {
            guard request == loadID, companyID == SessionManager.shared.selectedCompanyId else { return }
            errorMessage = "Couldn't load the supplier aging report. Tap Retry to try again."
            showAlert = true
        }
    }

    func exportCSV() -> URL? {
        guard canExport, let report else { return nil }
        var lines = ["Supplier,Current,1-30d,31-60d,61-90d,90d+,Total"]
        for row in report.suppliers {
            let b = row.buckets
            lines.append("\(SafeCSV.text(row.supplier_name)),\(b.current),\(b.days_1_30),\(b.days_31_60),\(b.days_61_90),\(b.days_90_plus),\(row.total)")
        }
        let t = report.totals
        lines.append("TOTAL,\(t.current),\(t.days_1_30),\(t.days_31_60),\(t.days_61_90),\(t.days_90_plus),\(report.grand_total)")
        let csv = lines.joined(separator: "\n")
        do { return try SafeCSV.write(csv, filename: "SupplierAgingReport.csv") }
        catch {
            errorMessage = "Couldn't save the CSV: \(error.localizedDescription)"
            showAlert = true
            return nil
        }
    }
}
