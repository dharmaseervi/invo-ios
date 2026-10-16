import Foundation

@MainActor final class SessionManager {
    static let shared = SessionManager()
    var selectedCompanyId: Int? = 1
}

@MainActor struct GSTReportService {
    static var responses: [String: GSTReportResponse] = [:]
    static var delays: [String: UInt64] = [:]
    func fetchGSTReport(companyID: Int, start: String, end: String) async throws -> GSTReportResponse {
        let response = Self.responses[start]
        if let delay = Self.delays[start] { try await Task.sleep(nanoseconds: delay) }
        guard let response else { throw URLError(.notConnectedToInternet) }
        return response
    }
}

@main struct ReportChecks {
    @MainActor static func main() async throws {
        func date(_ month: Int) -> Date {
            Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: month, day: 15))!
        }
        func report(_ month: String) -> GSTReportResponse {
            GSTReportResponse(start: "2026-\(month)-01", end: "2026-\(month)-30", company_state: "Rajasthan",
                summary: GSTSummary(invoice_count: 1, taxable_value: 100, cgst: 9, sgst: 9, igst: 0, total: 118),
                invoices: [GSTInvoiceSummaryRow(invoice_id: 1, invoice_number: "INV-1", invoice_date: "2026-\(month)-15", client_name: "Example, \"Store\"\nNew line", client_gstin: "123", place_of_supply: "Rajasthan", taxable_value: 100, cgst: 9, sgst: 9, igst: 0, total: 118)], hsn_summary: [])
        }
        let vm = GSTReportViewModel()
        vm.selectedMonth = date(9)
        GSTReportService.responses["2026-09-01"] = report("09")
        await vm.load()
        precondition(vm.canExport)
        let firstURL = vm.exportCSV()!
        let csv = try String(contentsOf: firstURL, encoding: .utf8)
        precondition(csv.contains("\"Example, \"\"Store\"\"\nNew line\""))
        precondition(firstURL.lastPathComponent == "GSTR1_2026-09-01_2026-09-30.csv")
        vm.selectedMonth = date(10)
        precondition(!vm.canExport && vm.exportCSV() == nil, "Cannot export old period even before next load starts")
        await vm.load()
        precondition(vm.report == nil && vm.errorMessage != nil && vm.exportCSV() == nil)

        GSTReportService.responses["2026-10-01"] = report("10")
        GSTReportService.delays["2026-09-01"] = 80_000_000
        vm.selectedMonth = date(9)
        let old = Task { await vm.load() }
        await Task.yield()
        try await Task.sleep(nanoseconds: 10_000_000)
        vm.selectedMonth = date(10)
        await vm.load()
        await old.value
        precondition(vm.report?.start == "2026-10-01" && vm.canExport, "Late September cannot overwrite October")
        SessionManager.shared.selectedCompanyId = 2
        precondition(!vm.canExport)
        GSTReportService.responses = [:]
        await vm.load()
        precondition(vm.report == nil && !vm.canExport)

        precondition(SafeCSV.text("a,b") == "\"a,b\"")
        precondition(SafeCSV.text("a\"b") == "\"a\"\"b\"")
        precondition(SafeCSV.text("a\rb") == "\"a\rb\"")
        for value in ["=1+1", "+SUM(A1)", "-2+3", "@SUM(A1)", " \t=1"] {
            precondition(SafeCSV.text(value).hasPrefix("\"'"))
        }
        let secondURL = try SafeCSV.write("one", filename: "same.csv")
        let thirdURL = try SafeCSV.write("two", filename: "same.csv")
        precondition(secondURL != thirdURL)
        print("PASS: report period/company identity, failed month export, out-of-order responses, CSV quoting/formula policy and unique files")
    }
}
