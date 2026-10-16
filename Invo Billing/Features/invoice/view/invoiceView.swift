import SwiftUI
import Combine

struct InvoiceView: View {
    @Environment(\.dynamicTypeSize) private var textSize
    var clientID: Int? = nil
    var clientName: String? = nil
    @State private var showCreateInvoice = false
    @StateObject private var vm = InvoiceViewModel()
    @State private var searchText = ""
    @State private var selectedFilter: InvoiceFilter = .all
    @State private var appearAnimation = false

    enum InvoiceFilter: String, CaseIterable {
        case all = "All"
        case paid = "Paid"
        case draft = "Draft"
        case overdue = "Overdue"
        case partial = "Partial"
        case issued = "Issued"
    }

    var filteredInvoices: [InvoiceResponse] { vm.invoices }

    private var serverStatus: String? {
        switch selectedFilter {
        case .all: return nil
        case .paid: return "paid"
        case .draft: return "draft"
        case .overdue: return "overdue"
        case .partial: return "partial"
        case .issued: return "issued"
        }
    }

    var totalAmount: Double { vm.summary.invoiced }
    var outstandingAmount: Double { vm.summary.outstanding }
    var overdueCount: Int { vm.summary.overdue }
    var paidCount: Int { vm.summary.paid }
    var draftCount: Int { vm.summary.draft }
    var partialCount: Int { vm.summary.partial }
    var issuedCount: Int { vm.summary.issued }

    private func isOverdue(_ invoice: InvoiceResponse) -> Bool {
        guard Self.isOwed(invoice.status),
              let due = AppDate.date(fromWire: invoice.due_date) else { return false }
        let calendar = Calendar.current
        return calendar.startOfDay(for: due) < calendar.startOfDay(for: Date())
    }

    static func isOwed(_ status: InvoiceStatus) -> Bool {
        switch status {
        case .issued, .partial, .sent, .pending, .overdue: return true
        case .draft, .paid, .cancelled: return false
        }
    }

    private func countFor(_ filter: InvoiceFilter) -> Int {
        switch filter {
        case .all: return vm.summary.total
        case .paid: return paidCount
        case .draft: return draftCount
        case .overdue: return overdueCount
        case .partial: return partialCount
        case .issued: return issuedCount
        }
    }

    @State private var hasLoadedOnce = false
    @State private var isSelecting = false
    @State private var selectedIDs: Set<Int> = []
    @State private var showBulkPayment = false

    private var isFirstLoad: Bool { vm.isFetchingList && !hasLoadedOnce }

    private func reload() async {
        await vm.fetchInvoices(
            clientID: clientID,
            search: searchText.trimmingCharacters(in: .whitespaces),
            status: serverStatus
        )
        hasLoadedOnce = true
    }

    var body: some View {
        if clientID == nil {
            NavigationStack { screen }
        } else {
            screen
        }
    }

    // MARK: - Main screen

    private var screen: some View {
        contentArea
        .safeAreaInset(edge: .bottom) {
            if isSelecting { bulkActionBar }
        }
        .searchable(text: $searchText, prompt: "Search invoices")
        .navigationTitle(clientName.map { "\($0) invoices" } ?? "Invoices")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbar { toolbarContent }
        .onAppear {
            Task { await reload() }
            withAnimation(.easeOut(duration: 0.3)) { appearAnimation = true }
        }
        .onChange(of: selectedFilter) { _, _ in Task { await reload() } }
        .task(id: searchText) {
            guard hasLoadedOnce else { return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await reload()
        }
        .sheet(isPresented: $showBulkPayment) {
            BulkInvoicePaymentView(invoices: payableSelection, vm: vm) { failedIDs in
                selectedIDs = failedIDs
                isSelecting = !failedIDs.isEmpty
                Task { await reload() }
            }
        }
        .fullScreenCover(isPresented: $showCreateInvoice) {
            NavigationStack { CreateInvoiceView() }
        }
        #if DEBUG
        .onAppear {
            if UserDefaults.standard.string(forKey: "startScreen") == "newinvoice" {
                showCreateInvoice = true
            }
        }
        #endif
        .sheet(isPresented: $vm.showPDF) {
            if let url = vm.pdfURL { PDFLookView(pdfURL: url) }
        }
        .sheet(isPresented: $vm.showEmailSheet) {
            if let id = vm.selectedEmailInvoiceID,
               let invoice = vm.invoices.first(where: { $0.id == id }) {
                SendEmailSheet(
                    invoiceID: id,
                    invoiceNumber: invoice.invoice_number,
                    vm: vm,
                    onDismiss: { vm.showEmailSheet = false },
                    isReminder: vm.emailIsReminder
                )
                .presentationDetents([.medium])
            }
        }
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Unknown error")
        }
        .confirmationDialog("Select copy", isPresented: $vm.showCopyPicker, titleVisibility: .visible) {
            Button("Original")  { Task { if let id = vm.selectedInvoiceID { await vm.generateInvoicePDFFromServer(invoiceID: id, copy: "original") } } }
            Button("Duplicate") { Task { if let id = vm.selectedInvoiceID { await vm.generateInvoicePDFFromServer(invoiceID: id, copy: "duplicate") } } }
            Button("Buyer copy") { Task { if let id = vm.selectedInvoiceID { await vm.generateInvoicePDFFromServer(invoiceID: id, copy: "buyer") } } }
            Button("Cancel", role: .cancel) {}
        }
        .presentationCompactAdaptation(.sheet)
    }

    @ViewBuilder
    private var contentArea: some View {
        if isFirstLoad {
            loadingView
        } else {
            List {
                // Summary card scrolls with the list
                if SessionManager.shared.companyRole.canSeeReports
                   && (!filteredInvoices.isEmpty || !searchText.isEmpty) {
                    summaryCard
                        .listHeaderRow()
                }

                // Filter chips scroll with the list
                filterRow
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                // Invoice rows
                if vm.isFetchingList && vm.invoices.isEmpty {
                    HStack { Spacer(); ProgressView().tint(.sAccent); Spacer() }
                        .padding(.vertical, 40)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else if filteredInvoices.isEmpty {
                    emptyStateRow
                } else {
                    ForEach(filteredInvoices) { invoice in
                        invoiceListRow(invoice)
                            .standardListRow()
                            .listRowSeparator(.hidden, edges: invoice.id == filteredInvoices.first?.id ? .top : [])
                    }

                    if vm.isLoadingMoreInvoices {
                        HStack { Spacer(); ProgressView().tint(.sAccent); Spacer() }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    } else if vm.loadMoreFailed {
                        VStack(spacing: 4) {
                            Text("Couldn't load more invoices.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Button("Try again") { Task { await vm.retryLoadMore() } }
                                .font(.footnote.weight(.medium))
                                .tint(Color.sAccent)
                        }
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .contentMargins(.bottom, AppSpacing.section, for: .scrollContent)
            .refreshable { await reload() }
            .opacity(appearAnimation ? 1 : 0)
            .overlay(alignment: .top) {
                if vm.isFetchingList {
                    ProgressView()
                        .padding(8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: - List row builder

    @ViewBuilder
    private func invoiceListRow(_ invoice: InvoiceResponse) -> some View {
        Group {
            if isSelecting {
                Button {
                    if selectedIDs.contains(invoice.id) { selectedIDs.remove(invoice.id) }
                    else { selectedIDs.insert(invoice.id) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selectedIDs.contains(invoice.id) ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selectedIDs.contains(invoice.id) ? Color.sAccent : Color(UIColor.tertiaryLabel))
                            .frame(width: 28)
                        InvoiceRow(invoice: invoice, isOverdue: isOverdue(invoice))
                    }
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink(destination: InvoiceDetailView(invoiceID: invoice.id, vm: vm)) {
                    InvoiceRow(invoice: invoice, isOverdue: isOverdue(invoice))
                }
                .task { await vm.loadMoreInvoices(currentItem: invoice) }
                .contextMenu {
                    Button {
                        vm.selectedInvoiceID = invoice.id
                        vm.showCopyPicker = true
                    } label: { Label("Download PDF", systemImage: "arrow.down.doc") }
                    Button {
                        vm.selectedEmailInvoiceID = invoice.id
                        vm.showEmailSheet = true
                        vm.emailIsReminder = false
                    } label: { Label("Send by email", systemImage: "paperplane") }
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 16) {
                if isSelecting {
                    Button("Done") {
                        isSelecting = false
                        selectedIDs.removeAll()
                    }
                    .fontWeight(.medium)
                } else {
                    Button("Select") { isSelecting = true }
                        .font(.subheadline.weight(.medium))
                    Button { showCreateInvoice = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    // MARK: - Filter row

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.inline) {
                ForEach(InvoiceFilter.allCases, id: \.self) { filter in
                    AppFilterChip(title: filterLabel(filter), isSelected: selectedFilter == filter) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, AppSpacing.page)
        }
    }

    private func filterLabel(_ filter: InvoiceFilter) -> String {
        let count = countFor(filter)
        switch filter {
        case .all:     return "All \(count)"
        case .paid:    return "Paid \(count)"
        case .draft:   return "Drafts \(count)"
        case .overdue: return "Overdue \(count)"
        case .partial: return "Partial \(count)"
        case .issued:  return "Issued \(count)"
        }
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            AdaptiveFormRow {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Outstanding")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(vm.summaryFailed ? "—" : Money.text(outstandingAmount))
                        .font(.title.bold())
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    if vm.summaryFailed {
                        Button("Retry") { Task { await reload() } }
                            .font(.footnote)
                            .tint(Color.sAccent)
                    }
                }
                if !textSize.isAccessibilitySize { Spacer() }
                if overdueCount > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.sDestructive)
                            .frame(width: 5, height: 5)
                        Text("\(overdueCount) overdue")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(Color.sDestructive)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.sDestructive.opacity(0.10), in: Capsule())
                }
            }

            Divider()

            AdaptiveStatRow(stats: [
                .init(label: "Total", value: vm.summaryFailed ? "—" : "\(vm.summary.total)"),
                .init(label: "Paid", value: vm.summaryFailed ? "—" : "\(paidCount)"),
                .init(label: "Drafts", value: vm.summaryFailed ? "—" : "\(draftCount)")
            ])
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Empty state (as a list row so it scrolls with the page)

    private var emptyStateRow: some View {
        ContentUnavailableView(
            searchText.isEmpty && selectedFilter == .all ? "No Invoices" : "No Results",
            systemImage: searchText.isEmpty && selectedFilter == .all ? "doc.text" : "magnifyingglass",
            description: Text(
                searchText.isEmpty && selectedFilter == .all
                ? "Create your first invoice to get started."
                : "Try adjusting your search or filter."
            )
        )
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    // MARK: - Loading skeletons

    private var loadingView: some View {
        List {
            ForEach(0..<8, id: \.self) { _ in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(UIColor.secondarySystemFill))
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.secondarySystemFill))
                            .frame(width: 140, height: 14)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.tertiarySystemFill))
                            .frame(width: 100, height: 11)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.secondarySystemFill))
                            .frame(width: 60, height: 14)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.tertiarySystemFill))
                            .frame(width: 44, height: 11)
                    }
                }
                .padding(.vertical, 4)
                .listRowSeparatorTint(Color(UIColor.separator))
                .shimmer()
            }
        }
        .listStyle(.plain)
        .allowsHitTesting(false)
    }

    // MARK: - Bulk action bar

    private var payableSelection: [InvoiceResponse] {
        filteredInvoices.filter { selectedIDs.contains($0.id) && $0.status.acceptsPayment && $0.remaining_amount > 0 }
    }

    private var bulkActionBar: some View {
        AdaptiveFormRow {
            Text("\(selectedIDs.count) selected")
                .font(.subheadline.weight(.medium))
            Spacer(minLength: 8)
            Button("Record payment (\(payableSelection.count))") { showBulkPayment = true }
                .buttonStyle(.borderedProminent)
                .disabled(payableSelection.isEmpty)
        }
        .padding()
        .background(.regularMaterial)
        .overlay(Divider(), alignment: .top)
    }

}

// MARK: - Invoice Row

struct InvoiceRow: View {
    @Environment(\.dynamicTypeSize) private var textSize
    let invoice: InvoiceResponse
    let isOverdue: Bool

    var displayName: String {
        let name = invoice.client_name ?? ""
        return name.isEmpty ? "Client #\(invoice.client_id)" : name
    }

    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    var statusConfig: (label: String, color: Color) {
        if isOverdue {
            if let due = AppDate.date(fromWire: invoice.due_date) {
                let days = abs(Calendar.current.dateComponents(
                    [.day],
                    from: Calendar.current.startOfDay(for: due),
                    to: Calendar.current.startOfDay(for: Date())
                ).day ?? 0)
                return (days <= 1 ? "1d overdue" : "\(days)d overdue", .sDestructive)
            }
            return ("Overdue", .sDestructive)
        }
        switch invoice.status {
        case .paid:      return ("Paid",      .sSuccess)
        case .pending:   return ("Pending",   .sWarning)
        case .partial:   return ("Partial",   .sWarning)
        case .draft:     return ("Draft",     .sNeutral)
        case .issued:    return ("Issued",    Color.sAccent)
        case .cancelled: return ("Cancelled", .sNeutral)
        case .sent:      return ("Sent",      .sNeutral)
        case .overdue:   return ("Overdue",   .sDestructive)
        }
    }

    var daysInfo: String {
        guard let due = AppDate.date(fromWire: invoice.due_date) else { return "" }
        if invoice.status == .paid { return "Paid" }
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: due)
        ).day ?? 0
        if days == 0 { return "Due today" }
        if days == 1 { return "Due tomorrow" }
        if days < 0 {
            guard isOverdue else { return "" }
            let late = abs(days)
            return late == 1 ? "1 day overdue" : "\(late) days overdue"
        }
        return days == 1 ? "Due in 1 day" : "Due in \(days) days"
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.row) {
            if !textSize.isAccessibilitySize {
                Text(initials)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.sAccent)
                    .frame(width: 40, height: 40)
                    .background(Color.sAccentMuted, in: Circle())
                    .accessibilityHidden(true)
            }
            if textSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.inline) {
                    identity
                    amountAndStatus
                }
            } else {
                HStack(alignment: .top, spacing: AppSpacing.row) {
                    identity
                    Spacer(minLength: AppSpacing.inline)
                    amountAndStatus
                }
            }
        }
        .alignmentGuide(.listRowSeparatorLeading) { _ in textSize.isAccessibilitySize ? 0 : 52 }
        .accessibilityElement(children: .combine)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text(displayName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(textSize.isAccessibilitySize ? nil : 2)
            Text(invoice.invoice_number)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !daysInfo.isEmpty && !isOverdue && invoice.status != .paid {
                Text(daysInfo)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var amountAndStatus: some View {
        VStack(alignment: textSize.isAccessibilitySize ? .leading : .trailing, spacing: AppSpacing.compact) {
            Text("\(invoice.status.acceptsPayment ? "Due" : "Total") \(Money.text(invoice.status.acceptsPayment ? invoice.remaining_amount : invoice.total))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            if invoice.status.acceptsPayment && abs(invoice.remaining_amount - invoice.total) > 0.004 {
                Text("Total \(Money.text(invoice.total))").font(.footnote).foregroundStyle(.secondary)
            }
            Text(statusConfig.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(statusConfig.color)
                .padding(.horizontal, AppSpacing.inline)
                .padding(.vertical, AppSpacing.compact)
                .background(statusConfig.color.opacity(0.1), in: Capsule())
        }
        .frame(minWidth: 88, alignment: .trailing)
    }
}

// Keep the old name as a typealias so any code that still references it compiles.
typealias InvoiceRowCard = InvoiceRow
