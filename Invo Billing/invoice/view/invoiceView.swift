import Combine
import SwiftUI

// MARK: - Zara Design System Colors
extension Color {
    static let zaraBlack = Color(hex: "1A1A1A")
    static let zaraWhite = Color(hex: "FAFAFA")
    static let zaraCream = Color(hex: "F5F3EF")
    static let zaraGray = Color(hex: "8A8A8A")
    static let zaraLightGray = Color(hex: "E8E8E8")
    static let zaraRed = Color(hex: "C41E3A")
    static let zaraTan = Color(hex: "D4C4B0")
    static let zaraSuccess = Color(hex: "2D5A27")
    static let zaraAmber = Color(hex: "B8860B")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(
            in: CharacterSet.alphanumerics.inverted
        )
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (
                255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17
            )
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (
                int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF
            )
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct InvoiceView: View {
    @StateObject private var vm = InvoiceViewModel()
    @State private var searchText = ""
    @State private var selectedFilter: InvoiceFilter = .all
    @State private var appearAnimation = false
    @State private var showPDF = false
    @State private var pdfURL: URL?

    enum InvoiceFilter: String, CaseIterable {
        case all = "ALL"
        case paid = "PAID"
        case draft = "DRAFT"
        case overdue = "OVERDUE"
        case partial = "PARTIAL"
        case issued = "ISSUED"
    }

    var filteredInvoices: [InvoiceResponse] {
        var invoices = vm.invoices

        // Search filter
        if !searchText.isEmpty {
            invoices = invoices.filter {
                $0.invoice_number.localizedCaseInsensitiveContains(searchText)
                    || String($0.client_id).contains(searchText)
            }
        }

        // Status filter
        switch selectedFilter {
        case .all:
            break
        case .paid:
            invoices = invoices.filter { $0.status == .paid }
        case .draft:
            invoices = invoices.filter { $0.status == .draft }
        case .overdue:
            invoices = invoices.filter { isOverdue($0) }
        case .partial:
            invoices = invoices.filter { $0.status == .partial }
        case .issued:
            invoices = invoices.filter { $0.status == .issued }
        }

        return invoices
    }

    var totalAmount: Double {
        filteredInvoices.reduce(0) { $0 + $1.total }
    }

    var overdueCount: Int {
        vm.invoices.filter { isOverdue($0) }.count
    }

    var paidCount: Int {
        vm.invoices.filter { $0.status == .paid }.count
    }

    var draftCount: Int {
        vm.invoices.filter { $0.status == .draft && !isOverdue($0) }.count
    }

    var partialCount: Int {
        vm.invoices.filter { $0.status == .partial && !isOverdue($0) }.count
    }

    var issuedCount: Int {
        vm.invoices.filter { $0.status == .issued }.count
    }

    private func isOverdue(_ invoice: InvoiceResponse) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let due = formatter.date(from: invoice.due_date) else {
            return false
        }
        return Date() > due && invoice.status != .paid
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.zaraWhite.ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - Zara Header
                    zaraHeader

                    if vm.isFetchingList {
                        zaraLoadingView
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 0) {
                                // Search Bar - Always visible
                                zaraSearchBar
                                    .padding(.top, 20)

                                // Filter Pills - Always visible
                                filterPills
                                    .padding(.top, 20)

                                if filteredInvoices.isEmpty {
                                    // Empty State
                                    ZaraEmptyInvoiceView(
                                        isSearching: !searchText.isEmpty
                                            || selectedFilter != .all
                                    )
                                    .frame(minHeight: 400)
                                } else {
                                    // Stats Overview
                                    statsOverview
                                        .padding(.top, 32)

                                    // Invoice List
                                    invoiceList
                                        .padding(.top, 32)
                                }

                                Spacer(minLength: 100)
                            }
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                Task { await vm.fetchInvoices() }
                withAnimation(.easeOut(duration: 0.6)) {
                    appearAnimation = true
                }
            }
            .refreshable {
                await vm.fetchInvoices()
            }
            .sheet(isPresented: $vm.showPDF) {
                if let url = vm.pdfURL {
                    PDFLookView(pdfURL: url)
                }
            }
            .sheet(isPresented: $vm.showEmailSheet) {
                if let id = vm.selectedEmailInvoiceID,
                   let invoice = vm.invoices.first(where: { $0.id == id }) {
                    SendEmailSheet(
                        invoiceID: id,
                        invoiceNumber: invoice.invoice_number,
                        vm: vm
                    )
                    .presentationDetents([.medium])
                }
            }
            .alert(
                "ERROR",
                isPresented: $vm.showAlert,
                actions: { Button("OK", role: .cancel) {} },
                message: { Text(vm.errorMessage ?? "Unknown error") }
            )
            .confirmationDialog(
                "Select Copy",
                isPresented: $vm.showCopyPicker,
                titleVisibility: .visible
            ) {
                Button("Original") {
                    Task {
                        if let id = vm.selectedInvoiceID {
                            await vm.generateInvoicePDFFromServer(
                                invoiceID: id,
                                copy: "original"
                            )
                        }
                    }
                }
                Button("Duplicate") {
                    Task {
                        if let id = vm.selectedInvoiceID {
                            await vm.generateInvoicePDFFromServer(
                                invoiceID: id,
                                copy: "duplicate"
                            )
                        }
                    }
                }
                Button("Buyer Copy") {
                    Task {
                        if let id = vm.selectedInvoiceID {
                            await vm.generateInvoicePDFFromServer(
                                invoiceID: id,
                                copy: "buyer"
                            )
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Zara Header
    private var zaraHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("INVOICES")
                        .font(.system(size: 28, weight: .thin))
                        .tracking(6)
                        .foregroundColor(.zaraBlack)

                    Text("\(vm.invoices.count) total")
                        .font(.system(size: 11, weight: .light))
                        .tracking(1)
                        .foregroundColor(.zaraGray)
                }

                Spacer()

                NavigationLink {
                    CreateInvoiceView()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .light))
                        Text("NEW")
                            .font(.system(size: 11, weight: .regular))
                            .tracking(2)
                    }
                    .foregroundColor(.zaraWhite)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.zaraBlack)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            Rectangle()
                .fill(Color.zaraBlack)
                .frame(height: 1)
        }
    }

    // MARK: - Search Bar
    private var zaraSearchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.zaraGray)

            TextField("Search invoice number or client", text: $searchText)
                .font(.system(size: 13, weight: .light))
                .foregroundColor(.zaraBlack)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.zaraGray)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.zaraCream.opacity(0.6))
        .overlay(
            Rectangle()
                .stroke(Color.zaraLightGray, lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    // MARK: - Filter Pills
    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(InvoiceFilter.allCases, id: \.self) { filter in
                    FilterPill(
                        title: filter.rawValue,
                        count: countFor(filter),
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
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

    // MARK: - Stats Overview
    private var statsOverview: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("OVERVIEW")
                    .font(.system(size: 10, weight: .regular))
                    .tracking(3)
                    .foregroundColor(.zaraGray)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            // Stats Grid
            HStack(spacing: 0) {
                StatCard(
                    value: "₹\(formatCompactAmount(totalAmount))",
                    label: "TOTAL",
                    accent: .zaraBlack
                )

                Rectangle()
                    .fill(Color.zaraLightGray)
                    .frame(width: 1)
                    .padding(.vertical, 16)

                StatCard(
                    value: "\(paidCount)",
                    label: "PAID",
                    accent: .zaraSuccess
                )

                Rectangle()
                    .fill(Color.zaraLightGray)
                    .frame(width: 1)
                    .padding(.vertical, 16)

                StatCard(
                    value: "\(overdueCount)",
                    label: "OVERDUE",
                    accent: overdueCount > 0 ? .zaraRed : .zaraGray
                )
            }
            .background(Color.zaraCream.opacity(0.5))
            .overlay(
                Rectangle()
                    .stroke(Color.zaraLightGray, lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Invoice List
    private var invoiceList: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("INVOICES")
                    .font(.system(size: 10, weight: .regular))
                    .tracking(3)
                    .foregroundColor(.zaraGray)

                Spacer()

                Text("\(filteredInvoices.count) items")
                    .font(.system(size: 10, weight: .light))
                    .tracking(1)
                    .foregroundColor(.zaraGray)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            Rectangle()
                .fill(Color.zaraLightGray)
                .frame(height: 1)
                .padding(.horizontal, 24)

            // Invoice Rows
            ForEach(Array(filteredInvoices.enumerated()), id: \.element.id) {
                index,
                invoice in
                NavigationLink {
                    InvoiceDetailView(invoiceID: invoice.id, vm: vm)
                } label: {
                    ZaraInvoiceRow(
                        invoice: invoice,
                        vm: vm,
                        isOverdue: isOverdue(invoice)
                    )
                }

                if index < filteredInvoices.count - 1 {
                    Rectangle()
                        .fill(Color.zaraLightGray)
                        .frame(height: 1)
                        .padding(.horizontal, 24)
                }
            }

            Rectangle()
                .fill(Color.zaraLightGray)
                .frame(height: 1)
                .padding(.horizontal, 24)
        }
    }

    // MARK: - Loading View
    private var zaraLoadingView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color.zaraLightGray, lineWidth: 1)
                    .frame(width: 40, height: 40)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Color.zaraBlack, lineWidth: 1)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(appearAnimation ? 360 : 0))
                    .animation(
                        .linear(duration: 1).repeatForever(autoreverses: false),
                        value: appearAnimation
                    )
            }

            Text("LOADING")
                .font(.system(size: 10, weight: .regular))
                .tracking(4)
                .foregroundColor(.zaraGray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { appearAnimation = true }
    }

    // MARK: - Helpers
    private func formatCompactAmount(_ value: Double) -> String {
        if value >= 100000 {
            return String(format: "%.1fL", value / 100000)
        } else if value >= 1000 {
            return String(format: "%.1fK", value / 1000)
        }
        return String(format: "%.0f", value)
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(
                        .system(size: 11, weight: isSelected ? .medium : .light)
                    )
                    .tracking(1.5)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(
                            isSelected ? .zaraWhite.opacity(0.7) : .zaraGray
                        )
                }
            }
            .foregroundColor(isSelected ? .zaraWhite : .zaraBlack)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.zaraBlack : Color.clear)
            .overlay(
                Rectangle()
                    .stroke(
                        isSelected ? Color.clear : Color.zaraLightGray,
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let value: String
    let label: String
    let accent: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 22, weight: .light))
                .tracking(0.5)
                .foregroundColor(accent)

            Text(label)
                .font(.system(size: 9, weight: .regular))
                .tracking(2)
                .foregroundColor(.zaraGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Zara Invoice Row
struct ZaraInvoiceRow: View {
    let invoice: InvoiceResponse
    let vm: InvoiceViewModel
    let isOverdue: Bool

    var statusConfig: (text: String, color: Color, bgColor: Color) {
        if isOverdue {
            return ("OVERDUE", .zaraRed, .zaraRed.opacity(0.08))
        }

        switch invoice.status {
        case .paid:
            return ("PAID", .zaraSuccess, .zaraSuccess.opacity(0.08))
        case .pending:
            return ("PENDING", .zaraAmber, .zaraAmber.opacity(0.08))
        case .partial:
            return ("PARTIAL", .zaraAmber, .zaraAmber.opacity(0.08))
        case .draft:
            return ("DRAFT", .zaraGray, .zaraGray.opacity(0.08))
        case .cancelled:
            return ("CANCELLED", .zaraGray, .zaraGray.opacity(0.08))
        case .sent:
            return ("SENT", .zaraGray, .zaraGray.opacity(0.08))
        case .issued:
            return ("ISSUED", .zaraGray, .zaraGray.opacity(0.08))
        case .overdue:
            return ("OVERDUE", .zaraRed, .zaraRed.opacity(0.08))
        }
    }

    var daysInfo: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let due = formatter.date(from: invoice.due_date) else {
            return ""
        }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: due)
        let days = components.day ?? 0

        if isOverdue {
            return "\(abs(days)) days ago"
        } else if days == 0 {
            return "Due today"
        } else if days == 1 {
            return "Due tomorrow"
        } else {
            return "Due in \(days) days"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                // Left side - Invoice info
                VStack(alignment: .leading, spacing: 10) {
                    // Invoice Number
                    Text(invoice.invoice_number)
                        .font(.system(size: 16, weight: .light))
                        .tracking(0.5)
                        .foregroundColor(.zaraBlack)

                    // Client ID
                    Text("Client #\(invoice.client_id)")
                        .font(.system(size: 11, weight: .light))
                        .tracking(0.5)
                        .foregroundColor(.zaraGray)

                    // Status Tag
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusConfig.color)
                            .frame(width: 5, height: 5)

                        Text(statusConfig.text)
                            .font(.system(size: 9, weight: .medium))
                            .tracking(1.5)
                            .foregroundColor(statusConfig.color)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusConfig.bgColor)
                }

                Spacer()

                // Right side - Amount & Actions
                VStack(alignment: .trailing, spacing: 10) {
                    // Amount
                    Text("₹\(String(format: "%.2f", invoice.total))")
                        .font(.system(size: 18, weight: .light))
                        .tracking(0.5)
                        .foregroundColor(.zaraBlack)

                    // Due info
                    Text(daysInfo)
                        .font(.system(size: 10, weight: .light))
                        .tracking(0.5)
                        .foregroundColor(isOverdue ? .zaraRed : .zaraGray)

                    // Actions
                    HStack(spacing: 16) {
                        Button {
                            vm.selectedInvoiceID = invoice.id
                            vm.showCopyPicker = true
                        } label: {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(.zaraGray)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(.zaraLightGray)
                        
                        // ← NEW Email button
                        Button {
                            vm.selectedEmailInvoiceID = invoice.id
                            vm.showEmailSheet = true
                        } label: {
                            Image(systemName: "paperplane")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(.zaraGray)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(.zaraLightGray)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            // Date strip
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text("ISSUED")
                        .font(.system(size: 8, weight: .regular))
                        .tracking(1)
                        .foregroundColor(.zaraGray)

                    Text(formatDate(invoice.invoice_date))
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(.zaraBlack)
                }

                Spacer()

                Rectangle()
                    .fill(Color.zaraLightGray)
                    .frame(width: 24, height: 1)

                Spacer()

                HStack(spacing: 6) {
                    Text("DUE")
                        .font(.system(size: 8, weight: .regular))
                        .tracking(1)
                        .foregroundColor(.zaraGray)

                    Text(formatDate(invoice.due_date))
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(isOverdue ? .zaraRed : .zaraBlack)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .padding(.top, 4)
        }
        .background(Color.zaraWhite)
    }

    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"

        guard let date = inputFormatter.date(from: dateString) else {
            return dateString
        }

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MMM dd"
        return outputFormatter.string(from: date).uppercased()
    }
}

// MARK: - Empty Invoice View
struct ZaraEmptyInvoiceView: View {
    let isSearching: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            VStack(spacing: 16) {
                Rectangle()
                    .fill(Color.zaraLightGray)
                    .frame(width: 60, height: 1)

                Image(systemName: "doc.text")
                    .font(.system(size: 40, weight: .ultraLight))
                    .foregroundColor(.zaraGray)

                Rectangle()
                    .fill(Color.zaraLightGray)
                    .frame(width: 60, height: 1)
            }

            // Text
            VStack(spacing: 12) {
                Text(isSearching ? "NO RESULTS" : "NO INVOICES")
                    .font(.system(size: 14, weight: .regular))
                    .tracking(4)
                    .foregroundColor(.zaraBlack)

                Text(
                    isSearching
                        ? "Try adjusting your search or filters"
                        : "Create your first invoice to begin"
                )
                .font(.system(size: 12, weight: .light))
                .tracking(0.5)
                .foregroundColor(.zaraGray)
                .multilineTextAlignment(.center)
            }

            // Action Button
            if !isSearching {
                NavigationLink {
                    CreateInvoiceView()
                } label: {
                    HStack(spacing: 12) {
                        Text("CREATE INVOICE")
                            .font(.system(size: 11, weight: .regular))
                            .tracking(3)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .light))
                    }
                    .foregroundColor(.zaraWhite)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.zaraBlack)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

