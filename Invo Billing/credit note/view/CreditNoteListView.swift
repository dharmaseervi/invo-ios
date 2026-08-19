import SwiftUI

struct CreditNoteListView: View {

    @StateObject private var vm = CreditNoteListViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showCreate = false
    @State private var searchText = ""
    @State private var selectedFilter: CNFilterType = .all
    @State private var appearAnimation = false

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

    // MARK: - Filtered Data
    var filteredNotes: [CreditNoteModel] {
        var notes = vm.creditNotes

        if !searchText.isEmpty {
            notes = notes.filter {
                $0.credit_number.localizedCaseInsensitiveContains(searchText)
                    || $0.client_name.localizedCaseInsensitiveContains(
                        searchText
                    )
            }
        }

        switch selectedFilter {
        case .all:
            break
        case .return:
            notes = notes.filter { $0.type == "return" }
        case .adjustment:
            notes = notes.filter { $0.type == "adjustment" }
        case .discount:
            notes = notes.filter { $0.type == "discount" }
        }

        return notes
    }

    // MARK: - Stats
    var totalAmount: Double {
        vm.creditNotes.reduce(0) { $0 + $1.total }
    }

    var returnCount: Int {
        vm.creditNotes.filter { $0.type == "return" }.count
    }

    var adjustmentCount: Int {
        vm.creditNotes.filter { $0.type == "adjustment" }.count
    }

    var discountCount: Int {
        vm.creditNotes.filter { $0.type == "discount" }.count
    }

    var body: some View {
        ZStack {
            Color.cnWhite.ignoresSafeArea()
            
            VStack(spacing: 0) {
                cnHeader
                
                if vm.isLoading {
                    cnLoadingView
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            cnSearchBar.padding(.top, 24)
                            cnfilterPills.padding(.top, 20)
                            
                            if filteredNotes.isEmpty {
                                cnEmptyView.frame(minHeight: 400)
                            } else {
                                cnStatsSection.padding(.top, 32)
                                cnListSection.padding(.top, 32)
                            }
                            
                            Spacer(minLength: 100)
                        }
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)
                    }
                    .refreshable {
                        await vm.load()
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showCreate) {
            CreateCreditNoteView()
        }
        .onAppear {
            Task { await vm.load() }
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                appearAnimation = true
            }
        }
        // ✅ Move onChange here — outside the if/else block
        .onChange(of: SessionManager.shared.selectedCompanyId) { _ in
            Task {
                vm.creditNotes = []
                await vm.load()
            }
        }
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Something went wrong")
        }
    }

    // MARK: - Header
    private var cnHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                // Back Button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.cnBlack)
                }
                .frame(width: 44, height: 44)

                Spacer()

                // Title
                VStack(spacing: 2) {
                    Text("CREDIT NOTES")
                        .font(.system(size: 13, weight: .regular))
                        .tracking(4)
                        .foregroundColor(.cnBlack)

                    if !vm.creditNotes.isEmpty {
                        Text("\(vm.creditNotes.count) total")
                            .font(.system(size: 10, weight: .light))
                            .tracking(1)
                            .foregroundColor(.cnGray)
                    }
                }

                Spacer()

                // Add Button
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.cnWhite)
                        .frame(width: 36, height: 36)
                        .background(Color.cnBlack)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            // Divider
            Rectangle()
                .fill(Color.cnBlack)
                .frame(height: 1)
        }
    }

    // MARK: - Search Bar
    private var cnSearchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.cnGray)

            TextField("Search by number or client", text: $searchText)
                .font(.system(size: 13, weight: .light))
                .foregroundColor(.cnBlack)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.cnGray)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.cnCream.opacity(0.6))
        .overlay(
            Rectangle()
                .stroke(Color.cnLightGray, lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    // MARK: - Filters
    private var cnfilterPills: some View {
        HStack(spacing: 12) {
            ForEach(CNFilterType.allCases, id: \.self) { filter in
                CNFilterPillButton(
                    title: filter.rawValue,
                    icon: filter.icon,
                    count: countFor(filter),
                    isSelected: selectedFilter == filter
                ) {
                    selectedFilter = filter
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func countFor(_ filter: CNFilterType) -> Int {
        switch filter {
        case .all: return vm.creditNotes.count
        case .return: return returnCount
        case .adjustment: return adjustmentCount
        case .discount: return discountCount
        }
    }

    // MARK: - Stats Section
    private var cnStatsSection: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("OVERVIEW")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(3)
                    .foregroundColor(.cnGray)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            // Stats Cards
            HStack(spacing: 0) {
                CNStatCardView(
                    value: formatAmount(totalAmount),
                    label: "TOTAL CREDITS",
                    valueColor: .cnBlack
                )

                Rectangle()
                    .fill(Color.cnLightGray)
                    .frame(width: 1)
                    .padding(.vertical, 20)

                CNStatCardView(
                    value: "\(returnCount)",
                    label: "ITEM RETURNS",
                    valueColor: .cnBlack
                )

                Rectangle()
                    .fill(Color.cnLightGray)
                    .frame(width: 1)
                    .padding(.vertical, 20)

                CNStatCardView(
                    value: "\(adjustmentCount)",
                    label: "ADJUSTMENTS",
                    valueColor: .cnBlack
                )
            }
            .background(Color.cnCream.opacity(0.4))
            .overlay(
                Rectangle()
                    .stroke(Color.cnLightGray, lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
    }

    // MARK: - List Section
    private var cnListSection: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("ALL CREDIT NOTES")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(3)
                    .foregroundColor(.cnGray)

                Spacer()

                Text("\(filteredNotes.count) items")
                    .font(.system(size: 10, weight: .light))
                    .tracking(1)
                    .foregroundColor(.cnGray)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            // List
            Rectangle()
                .fill(Color.cnLightGray)
                .frame(height: 1)
                .padding(.horizontal, 24)

            ForEach(Array(filteredNotes.enumerated()), id: \.element.id) {
                index,
                cn in
                NavigationLink {
                    CreditNoteDetailView(creditNoteID: cn.id)
                } label: {
                    CNRowView(cn: cn, index: index + 1)
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(Color.cnLightGray)
                    .frame(height: 1)
                    .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Empty View
    private var cnEmptyView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Decorative Element
            VStack(spacing: 16) {
                Rectangle()
                    .fill(Color.cnLightGray)
                    .frame(width: 60, height: 1)

                ZStack {
                    Circle()
                        .stroke(Color.cnLightGray, lineWidth: 1)
                        .frame(width: 80, height: 80)

                    Image(systemName: "arrow.uturn.backward.circle")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundColor(.cnGray)
                }

                Rectangle()
                    .fill(Color.cnLightGray)
                    .frame(width: 60, height: 1)
            }

            // Text
            VStack(spacing: 12) {
                Text(
                    searchText.isEmpty && selectedFilter == .all
                        ? "NO CREDIT NOTES" : "NO RESULTS"
                )
                .font(.system(size: 14, weight: .medium))
                .tracking(4)
                .foregroundColor(.cnBlack)

                Text(
                    searchText.isEmpty && selectedFilter == .all
                        ? "Create a credit note for returns\nor adjustments"
                        : "Try adjusting your search or filters"
                )
                .font(.system(size: 12, weight: .light))
                .tracking(0.5)
                .foregroundColor(.cnGray)
                .multilineTextAlignment(.center)
            }

            // Create Button (only show when no filters)
            if searchText.isEmpty && selectedFilter == .all {
                Button {
                    showCreate = true
                } label: {
                    HStack(spacing: 12) {
                        Text("CREATE CREDIT NOTE")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(3)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .light))
                    }
                    .foregroundColor(.cnWhite)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.cnBlack)
                }
            }

            Spacer()
        }
        .padding(24)
    }

    // MARK: - Loading View
    private var cnLoadingView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color.cnLightGray, lineWidth: 1)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Color.cnBlack, lineWidth: 1)
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(appearAnimation ? 360 : 0))
                    .animation(
                        .linear(duration: 1)
                            .repeatForever(autoreverses: false),
                        value: appearAnimation
                    )
            }

            Text("LOADING")
                .font(.system(size: 10, weight: .medium))
                .tracking(4)
                .foregroundColor(.cnGray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            appearAnimation = true
        }
    }

    // MARK: - Helper
    private func formatAmount(_ value: Double) -> String {
        if value >= 100000 {
            return "₹\(String(format: "%.1fL", value / 100000))"
        } else if value >= 1000 {
            return "₹\(String(format: "%.1fK", value / 1000))"
        }
        return "₹\(String(format: "%.0f", value))"
    }
}

// MARK: - Filter Pill Button
struct CNFilterPillButton: View {
    let title: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 6, weight: .light))

                Text(title)
                    .font(
                        .system(size: 6, weight: isSelected ? .medium : .light)
                    )
                    .tracking(1.5)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .light))
                        .foregroundColor(
                            isSelected ? .cnWhite.opacity(0.7) : .cnGray
                        )
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(
                                    isSelected
                                        ? Color.cnWhite.opacity(0.2)
                                        : Color.cnLightGray
                                )
                        )
                }
            }
            .foregroundColor(isSelected ? .cnWhite : .cnBlack)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(isSelected ? Color.cnBlack : Color.clear)
            .overlay(
                Rectangle()
                    .stroke(
                        isSelected ? Color.clear : Color.cnLightGray,
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - Stat Card View
struct CNStatCardView: View {
    let value: String
    let label: String
    let valueColor: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 18, weight: .light))
                .tracking(0.5)
                .foregroundColor(valueColor)

            Text(label)
                .font(.system(size: 8, weight: .medium))
                .tracking(2)
                .foregroundColor(.cnGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Credit Note Row View
struct CNRowView: View {
    let cn: CreditNoteModel
    let index: Int

    var typeConfig: (icon: String, color: Color, label: String) {
        switch cn.type.lowercased() {
        case "return":
            return ("cube.box", .cnBlack, "ITEM RETURN")
        case "discount":
            return ("percent", .cnSuccess, "DISCOUNT")
        default:  // adjustment
            return ("indianrupeesign.circle", .cnAmber, "ADJUSTMENT")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Index Number
            Text(String(format: "%02d", index))
                .font(.system(size: 11, weight: .light))
                .foregroundColor(.cnGray)
                .frame(width: 20)

            // Left Content
            VStack(alignment: .leading, spacing: 10) {
                // Credit Note Number
                Text(cn.credit_number)
                    .font(.system(size: 15, weight: .light))
                    .tracking(0.5)
                    .foregroundColor(.cnBlack)

                // Client Name
                Text(cn.client_name.uppercased())
                    .font(.system(size: 10, weight: .regular))
                    .tracking(1)
                    .foregroundColor(.cnGray)

                // Type Badge
                HStack(spacing: 6) {
                    Image(systemName: typeConfig.icon)
                        .font(.system(size: 9, weight: .medium))

                    Text(typeConfig.label)
                        .font(.system(size: 8, weight: .medium))
                        .tracking(1)
                }
                .foregroundColor(typeConfig.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(typeConfig.color.opacity(0.08))
            }

            Spacer()

            // Right Content - Amount
            VStack(alignment: .trailing, spacing: 8) {
                Text("₹\(String(format: "%.2f", cn.total))")
                    .font(.system(size: 16, weight: .light))
                    .tracking(0.5)
                    .foregroundColor(.cnBlack)

                // Date if available
                if !cn.credit_date.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty {
                    Text(formatDate(cn.credit_date))
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(.cnGray)
                }

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(.cnLightGray)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(Color.cnWhite)
    }

    private func formatDate(_ dateString: String) -> String {
        // Try ISO8601
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM dd"
            return formatter.string(from: date).uppercased()
        }

        // Try simple date format
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        if let date = simpleFormatter.date(from: dateString) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM dd"
            return formatter.string(from: date).uppercased()
        }

        return dateString
    }
}

// MARK: - Colors Extension
extension Color {
    static let cnBlack = Color.fromHex("1A1A1A")
    static let cnWhite = Color.fromHex("FAFAFA")
    static let cnCream = Color.fromHex("F5F3EF")
    static let cnGray = Color.fromHex("8A8A8A")
    static let cnLightGray = Color.fromHex("E5E5E5")
    static let cnAmber = Color.fromHex("B8860B")
    static let cnSuccess = Color.fromHex("2D5A27")
    static let cnRed = Color.fromHex("C41E3A")

    /// Create a SwiftUI Color from a hex string like "#RRGGBB" or "RRGGBB" (optionally with alpha AARRGGBB).
    static func fromHex(_ hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(
            in: CharacterSet.alphanumerics.inverted
        )
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch cleaned.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (
                255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17
            )
        case 6:  // RRGGBB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // AARRGGBB (32-bit)
            (a, r, g, b) = (
                int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF
            )
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    NavigationStack {
        CreditNoteListView()
    }
}
