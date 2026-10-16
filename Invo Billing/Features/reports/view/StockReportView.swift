import SwiftUI

struct StockReportView: View {
    @StateObject private var vm = StockReportViewModel()
    @State private var shareURL: URL?
    @State private var showBreakdown = true

    private let lowStockColor: Color = .sWarning
    private let profitColor: Color = .sSuccess

    var body: some View {
        Group {
            if vm.isLoading && vm.report == nil {
                ProgressView()
                    .tint(.sAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let report = vm.report, report.total_items == 0 {
                emptyState
            } else if vm.report != nil {
                List {
                    VStack(spacing: 12) {
                        if let failure = vm.refreshFailure {
                            refreshFailureBar(failure)
                        }
                        summaryCard
                    }
                    .padding(.horizontal, AppSpacing.page)
                    .padding(.top, 8)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    filterBar
                        .padding(.vertical, 8)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    if !vm.categories.isEmpty {
                        categoryBreakdown
                    }

                    itemsSection
                }
                .listStyle(.plain)
                .contentMargins(.bottom, 16, for: .scrollContent)
                .refreshable { await vm.load() }
            }
        }
        .searchable(text: $vm.searchText, prompt: "Search name, SKU or category")
        .safeAreaInset(edge: .top) {
            if let message = vm.errorMessage {
                ReportStatusView(message: message, hasData: vm.report != nil) { await vm.load() }
                    .background(Color.sBackground)
            } else if vm.isLoading && vm.report != nil {
                ProgressView("Refreshing…").padding(8)
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
        .task(id: SessionManager.shared.selectedCompanyId) { await vm.load() }
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
                .font(.footnote)
                .foregroundColor(lowStockColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.sForeground)
                Text("Showing the last figures that loaded. Pull down to try again.")
                    .font(.footnote)
                    .foregroundColor(.sMutedFG)
            }
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .background(lowStockColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Summary

    private var summaryCard: some View {
        let totals = vm.visibleTotals

        return SummaryCard(
            title: "Stock value (at cost)",
            value: currency(totals.costValue),
            stats: [
                .init(label: "Retail value", value: currency(totals.retailValue)),
                .init(label: "Potential profit", value: currency(totals.potentialProfit), color: profitColor),
                .init(
                    label: "Need attention",
                    value: "\(totals.lowCount + totals.outCount)",
                    color: totals.outCount > 0 ? .sDestructive : .sForeground
                ),
            ]
        ) {
            HStack(spacing: 8) {
                Text("\(totals.itemCount) items · \(totals.units) units · as of \(AppDate.text(fromWire: vm.report?.as_of ?? ""))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if vm.isFiltered {
                    Text("Filtered")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.sAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.sAccent.opacity(0.12), in: Capsule())
                }
            }
        }
    }

    // MARK: - Filters

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
                .padding(.horizontal, AppSpacing.page)
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
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.sForeground)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 12)
                    .frame(minHeight: AppSpacing.minimumTarget)
                    .background(Color(UIColor.secondarySystemFill), in: Capsule())
                }
              }
              .padding(.horizontal, AppSpacing.page)
            }

            if vm.isFiltered {
                Button {
                    vm.clearFilters()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                        Text("Clear filters")
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.sAccent)
                }
                .padding(.horizontal, AppSpacing.page)
            }
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        AppFilterChip(title: title, isSelected: isSelected, action: action)
    }

    // MARK: - Category breakdown

    private var categoryBreakdown: some View {
        Section {
            if showBreakdown {
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
                    .buttonStyle(.plain)
                    .standardListRow()
                }
            }
        } header: {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showBreakdown.toggle() }
            } label: {
                HStack {
                    Text("By category · \(vm.categories.count)")
                    Spacer()
                    Image(systemName: showBreakdown ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showBreakdown ? "Hide categories" : "Show categories")
        }
    }

    // MARK: - Items

    private var itemsSection: some View {
        let items = vm.filteredItems

        return Section {
            if items.isEmpty {
                VStack(spacing: 6) {
                    Text("No items match these filters")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Button("Clear filters") { vm.clearFilters() }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.sAccent)
                        .buttonStyle(.borderless)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .listRowSeparator(.hidden)
            } else {
                ForEach(items) { item in
                    StockReportRow(item: item, lowStockColor: lowStockColor)
                        .standardListRow()
                }
            }
        } header: {
            Text("\(vm.selectedCategory ?? "All items") · \(items.count)")
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView(
            "No items yet",
            systemImage: "shippingbox",
            description: Text("Add items with a cost price to see what your stock is worth")
        )
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(category.category_name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(Color.sAccent)
                        .accessibilityLabel("Selected")
                }
                Spacer(minLength: 8)
                Text(Money.text(category.cost_value)).moneyLine()
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            // Share of the company's total stock value — makes it obvious at a glance
            // which category is holding the money.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(UIColor.secondarySystemFill))
                    Capsule()
                        .fill(Color.sAccent)
                        .frame(width: max(2, geo.size.width * min(1, category.share_of_value / 100)))
                }
            }
            .frame(height: 4)

            HStack(spacing: 8) {
                Text("\(category.item_count) items · \(String(format: "%.0f", category.share_of_value))% of value · ")
                    .foregroundStyle(.secondary)
                + Text("profit \(Money.text(category.potential_profit))")
                    .foregroundStyle(profitColor)

                Spacer(minLength: 4)

                if category.out_of_stock_count > 0 {
                    Label("\(category.out_of_stock_count)", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(Color.sDestructive)
                }
                if category.low_stock_count > 0 {
                    Label("\(category.low_stock_count)", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(lowStockColor)
                }
            }
            .font(.caption)
            .lineLimit(1)
        }
        .contentShape(Rectangle())
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
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.sForeground)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(.sMutedFG)
                    .lineLimit(1)
            }
            .alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(Money.text(item.stock_value)).moneyLine()
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.sForeground)
                Text("\(item.quantity)\(item.unit.map { $0.isEmpty ? "" : " \($0)" } ?? "") in stock")
                    .font(.caption)
                    .foregroundColor(statusColor)
                    .lineLimit(1)
            }
            .frame(minWidth: 88, alignment: .trailing)
        }
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
