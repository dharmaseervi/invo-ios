import Combine
import Foundation

enum StockStatusFilter: String, CaseIterable, Identifiable {
    case all, inStock, low, out

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .inStock: return "In stock"
        case .low: return "Low"
        case .out: return "Out"
        }
    }
}

enum StockSortOption: String, CaseIterable, Identifiable {
    case valueHighToLow, nameAToZ, quantityLowToHigh, quantityHighToLow, profitHighToLow

    var id: String { rawValue }

    var label: String {
        switch self {
        case .valueHighToLow: return "Stock value (high → low)"
        case .nameAToZ: return "Name (A → Z)"
        case .quantityLowToHigh: return "Quantity (low → high)"
        case .quantityHighToLow: return "Quantity (high → low)"
        case .profitHighToLow: return "Potential profit (high → low)"
        }
    }
}

/// Totals recomputed over whatever the current filters leave visible, so the summary
/// card answers "what is this category worth" and not just "what is everything worth".
struct StockTotals {
    var itemCount = 0
    var units = 0
    var costValue: Double = 0
    var retailValue: Double = 0
    var lowCount = 0
    var outCount = 0

    var potentialProfit: Double { retailValue - costValue }
}

@MainActor
final class StockReportViewModel: ObservableObject {

    @Published var report: StockReportResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showAlert = false
    /// Set when a refresh fails but earlier data is still on screen. Shown as a bar
    /// under the title rather than an alert, because the numbers below it are still
    /// perfectly good and there is nothing for the reader to decide.
    @Published var refreshFailure: String?

    @Published var searchText = ""
    @Published var selectedCategory: String?
    @Published var statusFilter: StockStatusFilter = .all
    @Published var sortOption: StockSortOption = .valueHighToLow

    private let service = StockReportService()

    var categories: [StockCategorySummary] { report?.categories ?? [] }

    var isFiltered: Bool {
        selectedCategory != nil || statusFilter != .all || !searchText.trimmed.isEmpty
    }

    var filteredItems: [StockReportItem] {
        guard let report else { return [] }
        let query = searchText.trimmed.lowercased()

        let matched = report.allItems.filter { item in
            if let selectedCategory, item.categoryLabel != selectedCategory { return false }

            switch statusFilter {
            case .all: break
            case .inStock: if item.stockStatus != .inStock { return false }
            case .low: if item.stockStatus != .low { return false }
            case .out: if item.stockStatus != .out { return false }
            }

            if query.isEmpty { return true }
            return item.name.lowercased().contains(query)
                || (item.sku ?? "").lowercased().contains(query)
                || item.categoryLabel.lowercased().contains(query)
        }

        return matched.sorted { a, b in
            switch sortOption {
            case .valueHighToLow:
                if a.stock_value != b.stock_value { return a.stock_value > b.stock_value }
            case .nameAToZ:
                break
            case .quantityLowToHigh:
                if a.quantity != b.quantity { return a.quantity < b.quantity }
            case .quantityHighToLow:
                if a.quantity != b.quantity { return a.quantity > b.quantity }
            case .profitHighToLow:
                let pa = a.retailValue - a.stock_value
                let pb = b.retailValue - b.stock_value
                if pa != pb { return pa > pb }
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    /// Whole-company figures when nothing is filtered (so they match the server's own
    /// totals exactly), recomputed over the visible rows once a filter is applied.
    var visibleTotals: StockTotals {
        guard let report else { return StockTotals() }

        if !isFiltered {
            return StockTotals(
                itemCount: report.total_items,
                units: report.total_stock_units,
                costValue: report.total_cost_value,
                retailValue: report.total_retail_value,
                lowCount: report.low_stock_count,
                outCount: report.out_of_stock_count
            )
        }

        var totals = StockTotals()
        for item in filteredItems {
            totals.itemCount += 1
            totals.units += item.quantity
            totals.costValue += item.stock_value
            totals.retailValue += item.retailValue
            switch item.stockStatus {
            case .low: totals.lowCount += 1
            case .out: totals.outCount += 1
            case .inStock: break
            }
        }
        return totals
    }

    func clearFilters() {
        searchText = ""
        selectedCategory = nil
        statusFilter = .all
    }

    func load() async {
        guard let companyID = SessionManager.shared.selectedCompanyId else {
            errorMessage = "Select a company first"
            showAlert = true
            return
        }

        isLoading = true
        errorMessage = nil
        refreshFailure = nil
        defer { isLoading = false }

        do {
            report = try await service.fetchStockReport(companyID: companyID)
        } catch {
            // A failed refresh used to throw a modal over a screen full of correct
            // figures, which made a recoverable blip look like a broken app and forced
            // a tap to get back to data that had not gone anywhere. Only interrupt when
            // there is nothing to read.
            let message = readableMessage(for: error)
            if report == nil {
                errorMessage = message
                showAlert = true
            } else {
                refreshFailure = message
            }
        }
    }

    /// Offline is the common case and is the reader's to fix, so it says so plainly
    /// instead of blaming the report.
    private func readableMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return "No internet connection."
            case .timedOut:
                return "The server took too long to answer."
            default:
                return "Couldn't reach the server."
            }
        }
        return error.localizedDescription
    }

    // MARK: - CSV export

    /// Exports exactly what the filters currently show, plus the category roll-up, so
    /// the downloaded file always matches what was on screen when it was tapped.
    func exportCSV() -> URL? {
        guard let report else { return nil }

        let rows = filteredItems
        var csv = "Stock Report\n"
        csv += "As of,\(csvField(report.as_of))\n"
        if isFiltered {
            csv += "Filter,\(csvField(filterDescription))\n"
        }
        csv += "\n"

        let totals = visibleTotals
        csv += "Summary\n"
        csv += "Items,Units,Stock Value (Cost),Retail Value,Potential Profit,Low Stock,Out of Stock\n"
        csv += "\(totals.itemCount),\(totals.units),\(money(totals.costValue)),\(money(totals.retailValue)),"
        csv += "\(money(totals.potentialProfit)),\(totals.lowCount),\(totals.outCount)\n\n"

        if !categories.isEmpty {
            csv += "By Category\n"
            csv += "Category,Items,Units,Stock Value (Cost),Retail Value,Potential Profit,Share of Value %,Low Stock,Out of Stock\n"
            for c in categories {
                csv += "\(csvField(c.category_name)),\(c.item_count),\(c.total_units),\(money(c.cost_value)),"
                csv += "\(money(c.retail_value)),\(money(c.potential_profit)),"
                csv += "\(String(format: "%.1f", c.share_of_value)),\(c.low_stock_count),\(c.out_of_stock_count)\n"
            }
            csv += "\n"
        }

        csv += "Items\n"
        csv += "Name,SKU,Category,Unit,Quantity,Low Stock Alert,Status,Cost Price,Selling Price,Stock Value,Retail Value,Potential Profit\n"
        for item in rows {
            csv += "\(csvField(item.name)),\(csvField(item.sku ?? "")),\(csvField(item.categoryLabel)),"
            csv += "\(csvField(item.unit ?? "")),\(item.quantity),\(item.low_stock_alert),"
            csv += "\(csvField(item.stockStatus.label)),\(money(item.cost_price)),\(money(item.price)),"
            csv += "\(money(item.stock_value)),\(money(item.retailValue)),\(money(item.retailValue - item.stock_value))\n"
        }

        let fileName = "Stock_Report_\(report.as_of).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            // Excel only honours UTF-8 in a CSV when the byte-order mark is present —
            // without it the ₹ sign and non-ASCII item names open as mojibake.
            var data = Data([0xEF, 0xBB, 0xBF])
            data.append(Data(csv.utf8))
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private var filterDescription: String {
        var parts: [String] = []
        if let selectedCategory { parts.append("Category: \(selectedCategory)") }
        if statusFilter != .all { parts.append("Status: \(statusFilter.label)") }
        let query = searchText.trimmed
        if !query.isEmpty { parts.append("Search: \(query)") }
        return parts.joined(separator: " · ")
    }

    private func money(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    /// Item names and categories routinely contain commas ("Handle, 160mm") — without
    /// quoting, every such row shifts the remaining columns one to the right.
    private func csvField(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
