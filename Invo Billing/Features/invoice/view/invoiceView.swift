import SwiftUI
import Combine

struct InvoiceView: View {
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
    
    /// The rows as the server returned them: the search box and the filter are query
    /// parameters now, so there is nothing left to filter here.
    ///
    /// Filtering the loaded rows meant searching only what had been scrolled past, and
    /// the counts beside the filters described that handful of rows while looking like
    /// the state of the whole business.
    var filteredInvoices: [InvoiceResponse] { vm.invoices }

    /// What the server's status filter is called for each tab.
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
    /// What customers owe across every matching invoice: issued and part-paid only.
    var outstandingAmount: Double { vm.summary.outstanding }
    var overdueCount: Int { vm.summary.overdue }
    var paidCount: Int { vm.summary.paid }
    var draftCount: Int { vm.summary.draft }
    var partialCount: Int { vm.summary.partial }
    var issuedCount: Int { vm.summary.issued }
    
    /// Overdue means the due date has *passed*, not that it has arrived.
    ///
    /// This compared `Date() > due`, and `due` parses to midnight, so every invoice
    /// became overdue at 00:00 on the day it was due — a full day early. It drove the
    /// red badge, the "6 overdue" count and the Overdue filter, so customers were being
    /// chased a day before they were late, and the row could read "Due today" beside an
    /// Overdue badge.
    ///
    /// And only an invoice that is actually owed can be late. "Not paid" also caught
    /// drafts, which nobody has been sent, and cancelled invoices — a draft read "7 days
    /// overdue" and swelled the overdue count.
    private func isOverdue(_ invoice: InvoiceResponse) -> Bool {
        guard Self.isOwed(invoice.status),
              let due = AppDate.date(fromWire: invoice.due_date) else { return false }
        let calendar = Calendar.current
        return calendar.startOfDay(for: due) < calendar.startOfDay(for: Date())
    }

    /// Issued to the customer and not yet settled — the same rule the server uses.
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
    
    /// The very first load, where there is nothing on screen yet to keep. Later loads
    /// leave the controls in place.
    ///
    /// Tracked rather than guessed from an empty list: a search that matched nothing
    /// leaves the list empty, so clearing that search made this true again and the
    /// search box disappeared under the placeholder exactly when it was being used.
    @State private var hasLoadedOnce = false

    private var isFirstLoad: Bool { vm.isFetchingList && !hasLoadedOnce }

    /// Fetches the list and its figures for whatever is in the search box and selected
    /// on the filter bar.
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

    private var screen: some View {
            ZStack {
                Color.sBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    // The search field and the filters stay mounted while a search
                    // runs. They used to be inside the branch that the loading
                    // placeholder replaced, so every keystroke tore the field off the
                    // screen, the keyboard went with it, and the next character had
                    // nowhere to go. Only the results area waits.
                    if isFirstLoad {
                        loadingView
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                if vm.invoices.isEmpty == false || !searchText.isEmpty {
                                    // What the shop is owed overall is the money view
                                    // of the business, which a counter role is not
                                    // shown. Left in, the card sits there asking them
                                    // to retry something that will never work for them.
                                    if SessionManager.shared.companyRole.canSeeReports {
                                        summaryCard.padding(.top, 16)
                                    }
                                }
                                searchBar.padding(.top, 16)
                                filterRow.padding(.top, 12)
                                // The spinner replaces the list only when there is no
                                // list yet. Typing in the search box reloads from the
                                // server, and this used to blank every row and the
                                // scroll position with it on each search. A reload with
                                // invoices already on screen keeps them and shows a
                                // small indicator over them instead.
                                if vm.isFetchingList && vm.invoices.isEmpty {
                                    ProgressView()
                                        .tint(.sAccent)
                                        .frame(minHeight: 360)
                                } else if filteredInvoices.isEmpty {
                                    emptyState.frame(minHeight: 360)
                                } else {
                                    invoiceList
                                        .padding(.top, 18)
                                        .overlay(alignment: .top) {
                                            if vm.isFetchingList {
                                                ProgressView()
                                                    .tint(.sAccent)
                                                    .scaleEffect(0.8)
                                                    .padding(8)
                                                    .background(.ultraThinMaterial, in: Capsule())
                                                    .transition(.opacity)
                                            }
                                        }
                                }
                                Spacer(minLength: 100)
                            }
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 10)
                        }
                        .refreshable { await reload() }
                    }
                }
            }
            .navigationTitle(clientName.map { "\($0) invoices" } ?? "Invoices")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCreateInvoice = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                Task { await reload() }
                withAnimation(.easeOut(duration: 0.3)) { appearAnimation = true }
            }
            // The filter is a query parameter, so changing tab asks the server.
            .onChange(of: selectedFilter) { _, _ in
                Task { await reload() }
            }
            // Typing is debounced: a request per keystroke would be a request per
            // keystroke, and the one that answers last is not necessarily the one for
            // what is now in the box.
            .task(id: searchText) {
                // Only skip the run before the first load, which onAppear performs.
                // Testing for an empty box and an empty list also skipped the state
                // after clearing a search that matched nothing, so the full list never
                // came back.
                guard hasLoadedOnce else { return }
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                await reload()
            }
            // Creating an invoice is a multistep task, and Apple's guidance is that
            // those belong in a full-screen modal rather than pushed inside a tab
            // (sheets.md › "For complex or prolonged user flows"). Pushed, the sticky
            // action bar and the tab bar stacked up and ate a quarter of the screen at
            // a large text size — and the tab bar let someone wander off mid-invoice.
            .fullScreenCover(isPresented: $showCreateInvoice) {
                NavigationStack { CreateInvoiceView() }
            }
            // Debug builds accept -startScreen newinvoice so the creation form can be
            // opened directly for a screenshot pass. Compiled out of release.
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
                        onDismiss: {
                            vm.showEmailSheet = false
                        },  // ← correct label
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
                Button("Original") { Task { if let id = vm.selectedInvoiceID { await vm.generateInvoicePDFFromServer(invoiceID: id, copy: "original") } } }
                Button("Duplicate") { Task { if let id = vm.selectedInvoiceID { await vm.generateInvoicePDFFromServer(invoiceID: id, copy: "duplicate") } } }
                Button("Buyer copy") { Task { if let id = vm.selectedInvoiceID { await vm.generateInvoicePDFFromServer(invoiceID: id, copy: "buyer") } } }
                Button("Cancel", role: .cancel) {}
            }
            .presentationCompactAdaptation(.sheet)
    }
    
    // MARK: - Search Bar
    var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.scaled(14))
                .foregroundColor(.sMutedFG)
            TextField("Search invoices...", text: $searchText)
                .font(.scaled(14))
                .foregroundColor(.sForeground)
                .tint(.sAccent)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
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
    
    // MARK: - Filter Row
    var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(InvoiceFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedFilter = filter
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(filter.rawValue)
                                .font(.scaled(13, weight: selectedFilter == filter ? .medium : .regular))
                                .foregroundColor(selectedFilter == filter ? .sForeground : .sMutedFG)
                            let count = countFor(filter)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.scaled(11))
                                    .foregroundColor(.sMutedFG)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedFilter == filter ? Color.sCard : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(selectedFilter == filter ? Color.sBorder : Color.clear, lineWidth: 0.5)
                                )
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(3)
            .background(Color.sMuted)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sBorder, lineWidth: 0.5))
            .cornerRadius(8)
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Summary Card
    var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Outstanding")
                        .font(.scaled(13))
                        .foregroundColor(.sMutedFG)
                    // A dash, not ₹0, when the figures could not be fetched: zero reads
                    // as "nothing is owed", which is the opposite of "we don't know".
                    Text(vm.summaryFailed ? "—" : Money.compact(outstandingAmount)).moneyLine()
                        .font(.scaled(28, weight: .bold))
                        .foregroundColor(.sForeground)
                    if vm.summaryFailed {
                        Button("Totals unavailable — retry") { Task { await reload() } }
                            .font(.scaled(12))
                            .foregroundColor(.sAccent)
                    }
                }
                Spacer()
                if overdueCount > 0 {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(red: 0.863, green: 0.149, blue: 0.149))
                            .frame(width: 6, height: 6)
                        Text("\(overdueCount) overdue")
                            .font(.scaled(12, weight: .medium))
                    }
                    .foregroundColor(Color(red: 0.863, green: 0.149, blue: 0.149))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color(red: 0.863, green: 0.149, blue: 0.149).opacity(0.1))
                    )
                }
            }

            Rectangle().fill(Color.sBorder).frame(height: 0.5)

            HStack(spacing: 0) {
                summaryStat(label: "Invoiced", value: Money.compact(totalAmount))
                Rectangle().fill(Color.sBorder).frame(width: 0.5, height: 30)
                summaryStat(label: "Paid", value: "\(paidCount)")
                Rectangle().fill(Color.sBorder).frame(width: 0.5, height: 30)
                summaryStat(label: "Drafts", value: "\(draftCount)")
            }
        }
        .padding(18)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }

    private func summaryStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.scaled(15, weight: .semibold))
                .foregroundColor(.sForeground)
            Text(label)
                .font(.scaled(11))
                .foregroundColor(.sMutedFG)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
    }
    
    // MARK: - Invoice List
    var invoiceList: some View {
        VStack(spacing: 0) {
            HStack {
                Text(selectedFilter == .all ? "All invoices" : selectedFilter.rawValue)
                    .font(.scaled(13, weight: .medium))
                    .foregroundColor(.sMutedFG)
                Spacer()
                Text("\(filteredInvoices.count) items")
                    .font(.scaled(13))
                    .foregroundColor(.sMutedFG)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            // Lazy: a plain VStack builds every row as soon as the list is drawn, and
            // each row's .task fires with it — so opening the screen asked for the next
            // page immediately, however little had been scrolled, and a long list paid
            // for rows nobody had looked at.
            LazyVStack(spacing: 10) {
                ForEach(filteredInvoices) { invoice in
                    NavigationLink(destination: InvoiceDetailView(invoiceID: invoice.id, vm: vm)) {
                        InvoiceRowCard(invoice: invoice, vm: vm, isOverdue: isOverdue(invoice))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .task {
                        await vm.loadMoreInvoices(currentItem: invoice)
                    }
                }

                if vm.isLoadingMoreInvoices {
                    ProgressView()
                        .tint(.sAccent)
                        .padding(.vertical, 12)
                } else if vm.loadMoreFailed {
                    // A failed page used to end the list silently: the older invoices
                    // were simply unreachable until the screen was reopened, with
                    // nothing on screen to say anything had gone wrong.
                    VStack(spacing: 6) {
                        Text("Couldn't load more invoices.")
                            .font(.scaled(13))
                            .foregroundColor(.sMutedFG)
                        Button("Try again") { Task { await vm.retryLoadMore() } }
                            .font(.scaled(13, weight: .medium))
                            .foregroundColor(.sAccent)
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Empty State
    var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.sMuted)
                    .overlay(Circle().stroke(Color.sBorder, lineWidth: 0.5))
                    .frame(width: 60, height: 60)
                Image(systemName: "doc.text")
                    .font(.scaled(22))
                    .foregroundColor(.sMutedFG)
            }
            Text(searchText.isEmpty && selectedFilter == .all ? "No invoices yet" : "No results")
                .font(.scaled(15, weight: .medium))
                .foregroundColor(.sForeground)
            Text(searchText.isEmpty && selectedFilter == .all
                 ? "Create your first invoice to get started"
                 : "Try adjusting your search or filters")
            .font(.scaled(13))
            .foregroundColor(.sMutedFG)
            .multilineTextAlignment(.center)
            if searchText.isEmpty && selectedFilter == .all {
                Button { showCreateInvoice = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.scaled(13, weight: .medium))
                        Text("Create invoice")
                            .font(.scaled(14, weight: .medium))
                    }
                    .foregroundColor(.sAccentFG)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.sAccent)
                    .cornerRadius(8)
                }
                .padding(.top, 4)
            }
            Spacer()
        }
        .padding(24)
    }
    
    // MARK: - Loading
    var loadingView: some View {
        VStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.sMuted)
                    .frame(height: 72)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                    .shimmer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Invoice Row
struct InvoiceRowCard: View {
    let invoice: InvoiceResponse
    let vm: InvoiceViewModel
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
        if isOverdue { return ("Overdue", Color(red: 0.863, green: 0.149, blue: 0.149)) }
        switch invoice.status {
        case .paid:      return ("Paid",      Color(red: 0.086, green: 0.639, blue: 0.341))
        case .pending:   return ("Pending",   Color(red: 0.722, green: 0.494, blue: 0.051))
        case .partial:   return ("Partial",   Color(red: 0.722, green: 0.494, blue: 0.051))
        case .draft:     return ("Draft",     Color(UIColor.systemGray))
        case .issued:    return ("Issued",    Color.sAccent)
        case .cancelled: return ("Cancelled", Color(UIColor.systemGray))
        case .sent:      return ("Sent",      Color(UIColor.systemGray))
        case .overdue:   return ("Overdue",   Color(red: 0.863, green: 0.149, blue: 0.149))
        }
    }

    private var invoiceNumberText: some View {
        Text(invoice.invoice_number)
            .font(.scaled(12))
            .foregroundColor(.sMutedFG)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var dueText: some View {
        Text(daysInfo)
            .font(.scaled(12))
            .foregroundColor(isOverdue ? .sDestructive : .sMutedFG)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    var daysInfo: String {
        guard let due = AppDate.date(fromWire: invoice.due_date) else { return "" }
        if invoice.status == .paid { return "Paid" }

        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: due)
        ).day ?? 0

        // Counted in whole days from midnight, and "due today" is checked before
        // "overdue": the overdue branch used to win for an invoice due today, so five
        // rows on one screen read "0d overdue", which is not a thing.
        if days == 0 { return "Due today" }
        if days == 1 { return "Due tomorrow" }
        if days < 0 {
            // Past the date but not owed (a draft, a cancelled invoice): it isn't late,
            // so it says nothing rather than "7 days overdue" beside a Draft badge.
            guard isOverdue else { return "" }
            let late = abs(days)
            return late == 1 ? "1 day overdue" : "\(late) days overdue"
        }
        return days == 1 ? "Due in 1 day" : "Due in \(days) days"
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(statusConfig.color)
                .frame(width: 3)
                .padding(.vertical, 10)

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.sAccentMuted)
                        .frame(width: 40, height: 40)
                    Text(initials)
                        .font(.scaled(13, weight: .semibold))
                        .foregroundColor(.sAccent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.scaled(14, weight: .medium))
                        .foregroundColor(.sForeground)
                        .lineLimit(1)
                    // Side by side at normal sizes; stacked once the text is large,
                    // because the two together no longer fit a row and the number was
                    // breaking mid-token into "INV/ FY26- 27/00 08".
                    let meta = ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) {
                            invoiceNumberText
                            if !daysInfo.isEmpty {
                                Text("·").font(.scaled(12)).foregroundColor(.sMutedFG)
                                dueText
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            invoiceNumberText
                            if !daysInfo.isEmpty { dueText }
                        }
                    }
                    meta
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    Text(Money.text(invoice.total)).moneyLine()
                        .font(.scaled(14, weight: .semibold))
                        .foregroundColor(.sForeground)
                    Text(statusConfig.label)
                        .font(.scaled(10, weight: .medium))
                        .foregroundColor(statusConfig.color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(statusConfig.color.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(14)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                vm.selectedInvoiceID = invoice.id
                vm.showCopyPicker = true
            } label: {
                Label("Download PDF", systemImage: "arrow.down.doc")
            }
            Button {
                vm.selectedEmailInvoiceID = invoice.id
                vm.showEmailSheet = true
            } label: {
                Label("Send by email", systemImage: "paperplane")
            }
        }
    }
}
