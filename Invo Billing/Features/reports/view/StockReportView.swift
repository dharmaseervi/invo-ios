import SwiftUI

struct StockReportView: View {
    @StateObject private var vm = StockReportViewModel()
    @State private var shareURL: URL?
    @State private var showBreakdown = true

    private let lowStockColor = Color(red: 0.851, green: 0.588, blue: 0.082)
    private let profitColor = Color(red: 0.086, green: 0.639, blue: 0.341)

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            if vm.isLoading && vm.report == nil {
                ProgressView().tint(.sAccent)
            } else if let report = vm.report, report.total_items == 0 {
                emptyState
            } else if vm.report != nil {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if let failure = vm.refreshFailure {
                            refreshFailureBar(failure)
                        }
                        summaryCard
                        searchBar
                        filterBar

                        if !vm.categories.isEmpty {
                            categoryBreakdown
                        }

                        itemsSection
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .refreshable { await vm.load() }
            }
        }
        .navigationTitle("Stock Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let url = vm.exportCSV() { shareURL = url }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(vm.report == nil || vm.report?.total_items == 0)
            }
        }
        .task { await vm.load() }
        .sheet(item: Binding(
            get: { shareURL.map { StockShareURL(url: $0) } },
            set: { shareURL = $0?.url }
        )) { wrapper in
            StockShareSheet(activityItems: [wrapper.url])
        }
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Something went wrong")
        }
    }

    /// A refresh that failed over figures that are still on screen. Not an alert: the
    /// numbers below are the ones that loaded successfully, and the only thing to do is
    /// pull again, which the bar says.
    private func refreshFailureBar(_ message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.scaled(12))
                .foregroundColor(lowStockColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.scaled(13, weight: .medium))
                    .foregroundColor(.sForeground)
                Text("Showing the last figures that loaded. Pull down to try again.")
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
            }
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .background(lowStockColor.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(lowStockColor.opacity(0.35), lineWidth: 0.5))
        .cornerRadius(10)
        .padding(.horizontal, 20)
    }

    // MARK: - Summary

    private var summaryCard: some View {
        let totals = vm.visibleTotals

        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Stock value (at cost)")
                        .font(.scaled(13))
                        .foregroundColor(.sMutedFG)
                    if vm.isFiltered {
                        Text("FILTERED")
                            .font(.scaled(9, weight: .bold))
                            .foregroundColor(.sAccentFG)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.sAccent)
                            .cornerRadius(4)
                    }
                }

                Text(currency(totals.costValue))
                    .font(.scaled(26, weight: .bold))
                    .foregroundColor(.sForeground)

                Text("\(totals.itemCount) items · \(totals.units) units · as of \(AppDate.text(fromWire: vm.report?.as_of ?? ""))")
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
            }

            Rectangle().fill(Color.sBorder).frame(height: 0.5)

            AdaptiveStatRow(stats: [
                .init(label: "Retail value", value: currency(totals.retailValue)),
                .init(label: "Potential profit", value: currency(totals.potentialProfit), color: profitColor),
                .init(
                    label: "Need attention",
                    value: "\(totals.lowCount + totals.outCount)",
                    color: totals.outCount > 0 ? .sDestructive : .sForeground
                ),
            ])
        }
        .padding(18)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }

    // MARK: - Search & filters

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.scaled(14))
                .foregroundColor(.sMutedFG)

            TextField("Search name, SKU or category", text: $vm.searchText)
                .font(.scaled(14))
                .foregroundColor(.sForeground)
                .tint(.sAccent)
                .autocorrectionDisabled()

            if !vm.searchText.isEmpty {
                Button {
                    vm.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.scaled(14))
                        .foregroundColor(.sMutedFG)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sInput, lineWidth: 0.5))
        .cornerRadius(8)
        .padding(.horizontal, 20)
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(title: "All categories", isSelected: vm.selectedCategory == nil) {
                        vm.selectedCategory = nil
                    }
                    ForEach(vm.categories) { category in
                        chip(
                            title: "\(category.category_name) (\(category.item_count))",
                            isSelected: vm.selectedCategory == category.category_name
                        ) {
                            vm.selectedCategory = vm.selectedCategory == category.category_name
                                ? nil
                                : category.category_name
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            // Scrolls rather than squeezing: at a large text size the fixed row crushed
            // "In stock" and "Low" into "In…" and "Lo…", and stacked the Sort label into
            // a vertical column of letters.
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 8) {
                ForEach(StockStatusFilter.allCases) { status in
                    chip(title: status.label, isSelected: vm.statusFilter == status) {
                        vm.statusFilter = status
                    }
                }

                Menu {
                    Picker("Sort", selection: $vm.sortOption) {
                        ForEach(StockSortOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text("Sort")
                    }
                    .font(.scaled(12, weight: .medium))
                    .foregroundColor(.sForeground)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.sCard)
                    .overlay(Capsule().stroke(Color.sBorder, lineWidth: 0.5))
                    .clipShape(Capsule())
                }
              }
              .padding(.horizontal, 20)
            }

            if vm.isFiltered {
                Button {
                    vm.clearFilters()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                        Text("Clear filters")
                    }
                    .font(.scaled(12, weight: .medium))
                    .foregroundColor(.sAccent)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.scaled(12, weight: .medium))
                .foregroundColor(isSelected ? .sAccentFG : .sForeground)
                .lineLimit(1)
                // The chip sizes to its label instead of being squeezed by the row —
                // "In stock" was rendering as "In…".
                .fixedSize()
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color.sAccent : Color.sCard)
                .overlay(Capsule().stroke(isSelected ? Color.clear : Color.sBorder, lineWidth: 0.5))
                .clipShape(Capsule())
        }
    }

    // MARK: - Category breakdown

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showBreakdown.toggle() }
            } label: {
                HStack {
                    Text("By category")
                        .font(.scaled(13, weight: .medium))
                        .foregroundColor(.sMutedFG)
                    Spacer()
                    Text("\(vm.categories.count)")
                        .font(.scaled(11, weight: .medium))
                        .foregroundColor(.sMutedFG)
                    Image(systemName: showBreakdown ? "chevron.up" : "chevron.down")
                        .font(.scaled(11, weight: .semibold))
                        .foregroundColor(.sMutedFG)
                }
                .padding(.horizontal, 20)
            }

            if showBreakdown {
                VStack(spacing: 10) {
                    ForEach(vm.categories) { category in
                        Button {
                            vm.selectedCategory = vm.selectedCategory == category.category_name
                                ? nil
                                : category.category_name
                        } label: {
                            CategoryBreakdownRow(
                                category: category,
                                isSelected: vm.selectedCategory == category.category_name,
                                profitColor: profitColor,
                                lowStockColor: lowStockColor
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Items

    private var itemsSection: some View {
        let items = vm.filteredItems

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(vm.selectedCategory ?? "All items")
                    .font(.scaled(13, weight: .medium))
                    .foregroundColor(.sMutedFG)
                Spacer()
                Text("\(items.count)")
                    .font(.scaled(11, weight: .medium))
                    .foregroundColor(.sMutedFG)
            }
            .padding(.horizontal, 20)

            if items.isEmpty {
                VStack(spacing: 6) {
                    Text("No items match these filters")
                        .font(.scaled(14, weight: .medium))
                        .foregroundColor(.sForeground)
                    Button("Clear filters") { vm.clearFilters() }
                        .font(.scaled(13, weight: .medium))
                        .foregroundColor(.sAccent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.sCard)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(items) { item in
                        StockReportRow(item: item, lowStockColor: lowStockColor)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .font(.scaled(32))
                .foregroundColor(.sMutedFG)
            Text("No items yet")
                .font(.scaled(15, weight: .semibold))
                .foregroundColor(.sForeground)
            Text("Add items with a cost price to see what your stock is worth")
                .font(.scaled(13))
                .foregroundColor(.sMutedFG)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func currency(_ value: Double) -> String {
        Money.text(value)
    }
}

// MARK: - Category row

private struct CategoryBreakdownRow: View {
    let category: StockCategorySummary
    let isSelected: Bool
    let profitColor: Color
    let lowStockColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(category.category_name)
                    .font(.scaled(14, weight: .semibold))
                    .foregroundColor(.sForeground)
                    .lineLimit(1)
                Spacer()
                Text(Money.text(category.cost_value)).moneyLine()
                    .font(.scaled(13, weight: .semibold))
                    .foregroundColor(.sForeground)
            }

            // Share of the company's total stock value — makes it obvious at a glance
            // which category is holding the money.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.sMuted)
                    Capsule()
                        .fill(Color.sAccent)
                        .frame(width: max(2, geo.size.width * min(1, category.share_of_value / 100)))
                }
            }
            .frame(height: 4)

            HStack(spacing: 10) {
                Text("\(category.item_count) items · \(category.total_units) units")
                Text("·")
                Text("\(String(format: "%.0f", category.share_of_value))% of value")

                Spacer()

                if category.out_of_stock_count > 0 {
                    Label("\(category.out_of_stock_count)", systemImage: "exclamationmark.circle.fill")
                        .foregroundColor(.sDestructive)
                }
                if category.low_stock_count > 0 {
                    Label("\(category.low_stock_count)", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(lowStockColor)
                }
            }
            .font(.scaled(10))
            .foregroundColor(.sMutedFG)
            .lineLimit(1)

            HStack {
                Text("Retail \(Money.text(category.retail_value))")
                    .foregroundColor(.sMutedFG)
                Spacer()
                Text("Profit \(Money.text(category.potential_profit))")
                    .foregroundColor(profitColor)
            }
            .font(.scaled(11, weight: .medium))
        }
        .padding(14)
        .background(Color.sCard)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.sAccent : Color.sBorder, lineWidth: isSelected ? 1.5 : 0.5)
        )
        .cornerRadius(12)
    }
}

// MARK: - Item row

private struct StockReportRow: View {
    let item: StockReportItem
    let lowStockColor: Color

    private var statusColor: Color {
        switch item.stockStatus {
        case .out: return .sDestructive
        case .low: return lowStockColor
        case .inStock: return .sMutedFG
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(statusColor)
                .frame(width: 3, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.scaled(14, weight: .medium))
                    .foregroundColor(.sForeground)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.scaled(11))
                    .foregroundColor(.sMutedFG)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(Money.text(item.stock_value)).moneyLine()
                    .font(.scaled(13, weight: .semibold))
                    .foregroundColor(.sForeground)
                Text("\(item.quantity)\(item.unit.map { $0.isEmpty ? "" : " \($0)" } ?? "") in stock")
                    .font(.scaled(10))
                    .foregroundColor(statusColor)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(12)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let sku = item.sku, !sku.isEmpty { parts.append(sku) }
        parts.append(item.categoryLabel)
        parts.append("\(Money.text(item.price)) each")
        return parts.joined(separator: " · ")
    }
}

// MARK: - Share helpers

private struct StockShareURL: Identifiable {
    let id = UUID()
    let url: URL
}

private struct StockShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
