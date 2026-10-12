import SwiftUI

struct CreditNoteListView: View {

    @StateObject private var vm = CreditNoteListViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showCreate = false
    @State private var searchText = ""
    /// Tracked, not inferred from an empty list: a search that matches nothing would
    /// otherwise take the search box away with it.
    @State private var hasLoadedOnce = false
    @State private var selectedFilter: CNFilterType = .all

    // MARK: - Filters
    enum CNFilterType: String, CaseIterable {
        case all = "ALL"
        case `return` = "RETURN"
        case adjustment = "ADJUSTMENT"
        case discount = "DISCOUNT"

        var icon: String {
            switch self {
            case .all: return "square.stack"
            case .return: return "cube.box"
            case .adjustment: return "indianrupeesign.circle"
            case .discount: return "percent"
            }
        }
    }

    // MARK: - Rows
    //
    // As the server returned them: the search box and the filter are query parameters.
    // Filtering here searched only the page that had been loaded, so older credit notes
    // could not be found at all, and the counts below described that page.
    var filteredNotes: [CreditNoteModel] { vm.creditNotes }

    /// What the filter tab asks the server for.
    private var serverType: String? {
        switch selectedFilter {
        case .all: return nil
        case .return: return "return"
        case .adjustment: return "adjustment"
        case .discount: return "discount"
        }
    }

    /// Fetches the rows and their figures for what is on screen.
    private func reload() async {
        await vm.load(
            search: searchText.trimmingCharacters(in: .whitespaces),
            type: serverType
        )
        hasLoadedOnce = true
    }

    // MARK: - Stats, counted by the server over everything that matches
    var totalAmount: Double { vm.summary.amount }

    var returnCount: Int { vm.summary.returns }

    var adjustmentCount: Int { vm.summary.adjustments }

    var discountCount: Int { vm.summary.discounts }

    var body: some View {
        Group {
            // Only the very first load replaces the screen. Every search set
            // isLoading, and this branch took the search field and keyboard with
            // it on each keystroke.
            if vm.isLoading && !hasLoadedOnce {
                ProgressView()
                    .tint(.sAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    cnFilterPills
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    if filteredNotes.isEmpty {
                        cnEmptyView
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        cnSummaryCard
                            .padding(.horizontal, AppSpacing.page)
                            .padding(.bottom, 4)
                            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                        ForEach(filteredNotes) { cn in
                            NavigationLink {
                                CreditNoteDetailView(creditNoteID: cn.id)
                            } label: {
                                CNRowView(cn: cn)
                            }
                            .standardListRow()
                            .listRowSeparator(.hidden, edges: cn.id == filteredNotes.first?.id ? .top : [])
                            // Per row, a few from the end: keyed on the count it fired again on
                            // every change to the list, which is both eager and repetitive.
                            .task { await vm.loadMoreIfNeeded(currentItem: cn) }
                        }

                        if vm.isLoadingMore {
                            HStack { Spacer(); ProgressView().tint(.sAccent); Spacer() }
                                .padding(.vertical, 12)
                                .listRowSeparator(.hidden)
                        } else if vm.loadMoreFailed {
                            VStack(spacing: 6) {
                                Text("Couldn't load more credit notes.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Button("Try again") { Task { await vm.retryLoadMore() } }
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.sAccent)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .listRowSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.plain)
                .contentMargins(.bottom, 16, for: .scrollContent)
                .refreshable { await reload() }
            }
        }
        .searchable(text: $searchText, prompt: "Search by number or client")
        .navigationTitle("Credit notes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreate = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(isPresented: $showCreate) {
            CreateCreditNoteView()
        }
        .onChange(of: selectedFilter) { _, _ in
            Task { await reload() }
        }
        // Debounced: a request per keystroke, and the one answering last is not
        // necessarily the one for what is in the box now.
        .task(id: searchText) {
            // Only skip the run that fires before the first load; onAppear does that
            // one. The old guard also skipped an empty box with an empty list, which is
            // exactly the state after clearing a search that matched nothing — so the
            // full list never came back.
            guard hasLoadedOnce else { return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await reload()
        }
        .onAppear {
            Task { await reload() }
        }
        .onChange(of: SessionManager.shared.selectedCompanyId) { _ in
            Task {
                vm.creditNotes = []
                await reload()
            }
        }
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Something went wrong")
        }
    }

    // MARK: - Filters
    private var cnFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.inline) {
                ForEach(CNFilterType.allCases, id: \.self) { filter in
                    AppFilterChip(title: "\(filter.rawValue.capitalized) \(countFor(filter))",
                                  isSelected: selectedFilter == filter) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, AppSpacing.page)
        }
    }

    private func countFor(_ filter: CNFilterType) -> Int {
        switch filter {
        // From the server: this counted the rows that had been downloaded.
        case .all: return vm.summary.total
        case .return: return returnCount
        case .adjustment: return adjustmentCount
        case .discount: return discountCount
        }
    }

    // MARK: - Summary
    private var cnSummaryCard: some View {
        // Dashes and a retry, not zeroes: "₹0 credited, 0 returns" above a page of real
        // credit notes reads as fact, and it is not.
        SummaryCard(
            title: "Total credited",
            value: vm.summaryFailed ? "—" : Money.text(totalAmount),
            stats: [
                .init(label: "Returns", value: vm.summaryFailed ? "—" : "\(returnCount)"),
                .init(label: "Adjustments", value: vm.summaryFailed ? "—" : "\(adjustmentCount)"),
                .init(label: "Discounts", value: vm.summaryFailed ? "—" : "\(discountCount)")
            ]
        ) {
            if vm.summaryFailed {
                Button("Retry") { Task { await reload() } }
                    .font(.footnote)
                    .tint(Color.sAccent)
            }
        }
    }

    // MARK: - Empty View
    private var cnEmptyView: some View {
        let isUnfiltered = searchText.isEmpty && selectedFilter == .all
        return ContentUnavailableView {
            Label(isUnfiltered ? "No credit notes" : "No results",
                  systemImage: "arrow.uturn.backward.circle")
        } description: {
            Text(isUnfiltered
                 ? "Create a credit note for returns or adjustments"
                 : "Try adjusting your search or filters")
        } actions: {
            if isUnfiltered {
                Button("Create credit note") { showCreate = true }
                    .buttonStyle(.borderedProminent)
                    .tint(.sAccent)
            }
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Credit Note Row View
struct CNRowView: View {
    let cn: CreditNoteModel

    var typeConfig: (icon: String, color: Color, label: String) {
        switch cn.type.lowercased() {
        case "return":
            return ("cube.box", .sAccent, "Item return")
        case "discount":
            return ("percent", .sSuccess, "Discount")
        default:  // adjustment
            return ("indianrupeesign.circle", .sWarning, "Adjustment")
        }
    }

    private var dateText: String? {
        let raw = cn.credit_date.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? nil : AppDate.text(fromWire: raw)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: typeConfig.icon)
                .font(.body)
                .foregroundStyle(typeConfig.color)
                .frame(width: 40, height: 40)
                .background(typeConfig.color.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(cn.credit_number)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(cn.client_name) · \(typeConfig.label)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(Money.text(cn.total)).moneyLine()
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if let dateText {
                    Text(dateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 88, alignment: .trailing)
        }
    }
}

#Preview {
    NavigationStack {
        CreditNoteListView()
    }
}
