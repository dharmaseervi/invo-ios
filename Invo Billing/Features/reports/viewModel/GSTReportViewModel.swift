import Combine
import Foundation

@MainActor
final class GSTReportViewModel: ObservableObject {

    @Published var selectedMonth: Date = Date()
    @Published var report: GSTReportResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showAlert = false

    private let service = GSTReportService()

    var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }

    func goToPreviousMonth() {
        if let date = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = date
            Task { await load() }
        }
    }

    func goToNextMonth() {
        if let date = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = date
            Task { await load() }
        }
    }

    private func monthRange() -> (start: String, end: String) {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let components = calendar.dateComponents([.year, .month], from: selectedMonth)
        let startOfMonth = calendar.date(from: components) ?? selectedMonth
        let range = calendar.range(of: .day, in: .month, for: startOfMonth) ?? 1..<2
        let endOfMonth = calendar.date(byAdding: .day, value: range.count - 1, to: startOfMonth) ?? startOfMonth

        return (formatter.string(from: startOfMonth), formatter.string(from: endOfMonth))
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

        let (start, end) = monthRange()

        do {
            report = try await service.fetchGSTReport(companyID: companyID, start: start, end: end)
        } catch {
            errorMessage = "Couldn't load the GST report. Pull to retry."
            showAlert = true
        }
    }

    // MARK: - CSV export (GSTR-1 style: HSN summary + invoice-wise, as two sections in one file)
    func exportCSV() -> URL? {
        guard let report else { return nil }

        var csv = "GSTR-1 Summary — \(monthLabel)\n"
        csv += "Company state,\(report.company_state)\n\n"

        csv += "Summary\n"
        csv += "Invoices,Taxable Value,CGST,SGST,IGST,Total\n"
        csv += "\(report.summary.invoice_count),\(report.summary.taxable_value),\(report.summary.cgst),\(report.summary.sgst),\(report.summary.igst),\(report.summary.total)\n\n"

        csv += "HSN Summary\n"
        csv += "HSN Code,Tax Rate,Qty,Taxable Value,CGST,SGST,IGST,Total\n"
        for row in report.hsn_summary {
            csv += "\(row.hsn_code),\(row.tax_rate),\(row.total_qty),\(row.taxable_value),\(row.cgst),\(row.sgst),\(row.igst),\(row.total_value)\n"
        }
        csv += "\n"

        csv += "Invoice-wise (B2B)\n"
        csv += "Invoice No,Date,Client,GSTIN,Place of Supply,Taxable Value,CGST,SGST,IGST,Total\n"
        for row in report.invoices {
            csv += "\(row.invoice_number),\(row.invoice_date),\(row.client_name),\(row.client_gstin),\(row.place_of_supply),\(row.taxable_value),\(row.cgst),\(row.sgst),\(row.igst),\(row.total)\n"
        }

        let fileName = "GSTR1_\(monthLabel.replacingOccurrences(of: " ", with: "_")).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
