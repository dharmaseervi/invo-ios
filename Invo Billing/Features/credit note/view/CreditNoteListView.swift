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
            Color.sBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if vm.isLoading {
                    cnLoadingView
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            cnSearchBar.padding(.top, 16)
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

    // MARK: - Search Bar
    private var cnSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.sMutedFG)

            TextField("Search by number or client", text: $searchText)
                .font(.system(size: 14))
                .foregroundColor(.sForeground)
                .tint(.sAccent)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.sMutedFG)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.sCard)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.sInput, lineWidth: 0.5)
        )
        .cornerRadius(8)
        .padding(.horizontal, 20)
    }

    // MARK: - Filters
    private var cnfilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(CNFilterType.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedFilter = filter
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 11))
                            Text(filter.rawValue.capitalized)
                                .font(.system(size: 13, weight: selectedFilter == filter ? .medium : .regular))
                            let count = countFor(filter)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.sMutedFG)
                            }
                        }
                        .foregroundColor(selectedFilter == filter ? .sForeground : .sMutedFG)
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
            .padding(3)
            .background(Color.sMuted)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sBorder, lineWidth: 0.5))
            .cornerRadius(8)
            .padding(.horizontal, 20)
        }
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
                Text("Overview")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.sMutedFG)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            // Stats Cards
            HStack(spacing: 0) {
                CNStatCardView(
                    value: formatAmount(totalAmount),
                    label: "Total credits",
                    valueColor: .sForeground
                )

                Rectangle()
                    .fill(Color.sBorder)
                    .frame(width: 1)
                    .padding(.vertical, 20)

                CNStatCardView(
                    value: "\(returnCount)",
                    label: "Item returns",
                    valueColor: .sForeground
                )

                Rectangle()
                    .fill(Color.sBorder)
                    .frame(width: 1)
                    .padding(.vertical, 20)

                CNStatCardView(
                    value: "\(adjustmentCount)",
                    label: "Adjustments",
                    valueColor: .sForeground
                )
            }
            .background(Color.sMuted.opacity(0.4))
            .overlay(
                Rectangle()
                    .stroke(Color.sBorder, lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
    }

    // MARK: - List Section
    private var cnListSection: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("All credit notes")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.sMutedFG)

                Spacer()

                Text("\(filteredNotes.count) items")
                    .font(.system(size: 11))
                    .foregroundColor(.sMutedFG)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            // List
            Rectangle()
                .fill(Color.sBorder)
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
                    .fill(Color.sBorder)
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
                    .fill(Color.sBorder)
                    .frame(width: 60, height: 1)

                ZStack {
                    Circle()
                        .stroke(Color.sBorder, lineWidth: 1)
                        .frame(width: 80, height: 80)

                    Image(systemName: "arrow.uturn.backward.circle")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundColor(.sMutedFG)
                }

                Rectangle()
                    .fill(Color.sBorder)
                    .frame(width: 60, height: 1)
            }

            // Text
            VStack(spacing: 8) {
                Text(
                    searchText.isEmpty && selectedFilter == .all
                        ? "No credit notes" : "No results"
                )
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.sForeground)

                Text(
                    searchText.isEmpty && selectedFilter == .all
                        ? "Create a credit note for returns\nor adjustments"
                        : "Try adjusting your search or filters"
                )
                .font(.system(size: 13))
                .foregroundColor(.sMutedFG)
                .multilineTextAlignment(.center)
            }

            // Create Button (only show when no filters)
            if searchText.isEmpty && selectedFilter == .all {
                Button {
                    showCreate = true
                } label: {
                    HStack(spacing: 8) {
                        Text("Create credit note")
                            .font(.system(size: 13, weight: .semibold))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .light))
                    }
                    .foregroundColor(.sAccentFG)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.sPrimary)
                    .cornerRadius(10)
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
                    .stroke(Color.sBorder, lineWidth: 1)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Color.sAccent, lineWidth: 1)
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(appearAnimation ? 360 : 0))
                    .animation(
                        .linear(duration: 1)
                            .repeatForever(autoreverses: false),
                        value: appearAnimation
                    )
            }

            Text("Loading...")
                .font(.system(size: 13))
                .foregroundColor(.sMutedFG)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            appearAnimation = true
        }
    }

    // MARK: - Helper
    /// The second local money formatter this app grew. Both are gone; ``Money`` is the
    /// only one, so a figure reads the same here as on every other screen.
    private func formatAmount(_ value: Double) -> String {
        Money.compact(value)
    }
}

// MARK: - Stat Card View
struct CNStatCardView: View {
    let value: String
    let label: String
    let valueColor: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(valueColor)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.sMutedFG)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Credit Note Row View
struct CNRowView: View {
    let cn: CreditNoteModel
    let index: Int

    var typeConfig: (icon: String, color: Color, label: String) {
        switch cn.type.lowercased() {
        case "return":
            return ("cube.box", .sForeground, "Item return")
        case "discount":
            return ("percent", .cnSuccess, "Discount")
        default:  // adjustment
            return ("indianrupeesign.circle", .cnAmber, "Adjustment")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Index Number
            Text(String(format: "%02d", index))
                .font(.system(size: 11))
                .foregroundColor(.sMutedFG)
                .frame(width: 20)

            // Left Content
            VStack(alignment: .leading, spacing: 8) {
                // Credit Note Number
                Text(cn.credit_number)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.sForeground)

                // Client Name
                Text(cn.client_name)
                    .font(.system(size: 12))
                    .foregroundColor(.sMutedFG)

                // Type Badge
                HStack(spacing: 6) {
                    Image(systemName: typeConfig.icon)
                        .font(.system(size: 10, weight: .medium))

                    Text(typeConfig.label)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(typeConfig.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(typeConfig.color.opacity(0.08))
                .cornerRadius(6)
            }

            Spacer()

            // Right Content - Amount
            VStack(alignment: .trailing, spacing: 8) {
                Text(Money.text(cn.total))
                    .font(.system(size: 16, weight: .light))
                    .tracking(0.5)
                    .foregroundColor(.sForeground)

                // Date if available
                if !cn.credit_date.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty {
                    Text(formatDate(cn.credit_date))
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(.sMutedFG)
                }

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(.sBorder)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.sCard)
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
