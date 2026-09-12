import SwiftUI
import Combine

struct InvoiceView: View {
    #if DEBUG
    @State private var debugFormOpen = false
    #endif
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
    
    var filteredInvoices: [InvoiceResponse] {
        var invoices = vm.invoices
        if !searchText.isEmpty {
            invoices = invoices.filter {
                $0.invoice_number.localizedCaseInsensitiveContains(searchText)
                || ($0.client_name ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        switch selectedFilter {
        case .all: break
        case .paid: invoices = invoices.filter { $0.status == .paid }
        case .draft: invoices = invoices.filter { $0.status == .draft }
        case .overdue: invoices = invoices.filter { isOverdue($0) }
        case .partial: invoices = invoices.filter { $0.status == .partial }
        case .issued: invoices = invoices.filter { $0.status == .issued }
        }
        return invoices
    }
    
    var totalAmount: Double { filteredInvoices.reduce(0) { $0 + $1.total } }
    var outstandingAmount: Double {
        vm.invoices
            .filter { $0.status != .paid && $0.status != .cancelled }
            .reduce(0) { $0 + $1.remaining_amount }
    }
    var overdueCount: Int { vm.invoices.filter { isOverdue($0) }.count }
    var paidCount: Int { vm.invoices.filter { $0.status == .paid }.count }
    var draftCount: Int { vm.invoices.filter { $0.status == .draft && !isOverdue($0) }.count }
    var partialCount: Int { vm.invoices.filter { $0.status == .partial && !isOverdue($0) }.count }
    var issuedCount: Int { vm.invoices.filter { $0.status == .issued }.count }
    
    /// Overdue means the due date has *passed*, not that it has arrived.
    ///
    /// This compared `Date() > due`, and `due` parses to midnight, so every invoice
    /// became overdue at 00:00 on the day it was due — a full day early. It drove the
    /// red badge, the "6 overdue" count and the Overdue filter, so customers were being
    /// chased a day before they were late, and the row could read "Due today" beside an
    /// Overdue badge.
    private func isOverdue(_ invoice: InvoiceResponse) -> Bool {
        guard invoice.status != .paid,
              let due = AppDate.date(fromWire: invoice.due_date) else { return false }
        let calendar = Calendar.current
        return calendar.startOfDay(for: due) < calendar.startOfDay(for: Date())
    }
    
    private func countFor(_ filter: InvoiceFilter) -> Int {
        switch filter {
        case .all: return vm.invoices.count
        case .paid: return paidCount
        case .draft: return draftCount
        case .overdue: return overdueCount
        case .partial: return partialCount
        case .issued: return issuedCount
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    if vm.isFetchingList {
                        loadingView
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                if vm.invoices.isEmpty == false || !searchText.isEmpty {
                                    summaryCard.padding(.top, 16)
                                }
                                searchBar.padding(.top, 16)
                                filterRow.padding(.top, 12)
                                if filteredInvoices.isEmpty {
                                    emptyState.frame(minHeight: 360)
                                } else {
                                    invoiceList.padding(.top, 18)
                                }
                                Spacer(minLength: 100)
                            }
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 10)
                        }
                        .refreshable { await vm.fetchInvoices() }
                    }
                }
            }
            .navigationTitle("Invoices")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: CreateInvoiceView()) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                Task { await vm.fetchInvoices() }
                withAnimation(.easeOut(duration: 0.3)) { appearAnimation = true }
            }
            // Debug builds accept -startScreen newinvoice so the creation form can be
            // opened directly for a screenshot pass. Compiled out of release.
            #if DEBUG
            .navigationDestination(isPresented: $debugFormOpen) { CreateInvoiceView() }
            .onAppear {
                if UserDefaults.standard.string(forKey: "startScreen") == "newinvoice" {
                    debugFormOpen = true
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
                    Text(Money.compact(outstandingAmount)).moneyLine()
                        .font(.scaled(28, weight: .bold))
                        .foregroundColor(.sForeground)
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

            VStack(spacing: 10) {
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
                NavigationLink(destination: CreateInvoiceView()) {
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
                            Text("·").font(.scaled(12)).foregroundColor(.sMutedFG)
                            dueText
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            invoiceNumberText
                            dueText
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
