import SwiftUI

struct HomeView: View {
    @EnvironmentObject var session: SessionManager
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var companyVM = CompanyFormViewModel()
    @State private var selectedPeriod = "Week"
    @State private var appeared = false

    private var selectedCompanyName: String {
        companyVM.companies.first(where: { $0.id == session.selectedCompanyId })?.name ?? "Select company"
    }

    private func apiPeriod(_ ui: String) -> String { ui.lowercased() }
    private func fetch() {
        Task { await viewModel.load(period: apiPeriod(selectedPeriod)) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            if viewModel.isLoading {
                                skeletonView
                            } else if let errorMessage = viewModel.errorMessage {
                                errorView(errorMessage)
                            } else {
                                revenueCard
                                statsRow
                                quickActionsCard
                                recentActivityCard
                            }
                        }
                        .padding(.top, 20)
                        // TabView already insets scroll content for the tab bar; the
                        // extra 100pt here was stacked on top of it and left a dead
                        // band under the last row.
                        .padding(.bottom, 24)
                    }
                    .refreshable { fetch() }
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(companyVM.companies) { company in
                            Button {
                                session.selectedCompanyId = company.id
                            } label: {
                                if company.id == session.selectedCompanyId {
                                    Label(company.name, systemImage: "checkmark")
                                } else {
                                    Text(company.name)
                                }
                            }
                        }
                        Divider()
                        NavigationLink(destination: CompanyView()) {
                            Label("Manage companies", systemImage: "building.2")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "building.2")
                                .font(.scaled(12))
                            Text(selectedCompanyName)
                                .font(.scaled(14, weight: .medium))
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.scaled(10, weight: .semibold))
                        }
                        .foregroundColor(.sForeground)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Period", selection: $selectedPeriod) {
                            ForEach(["Week", "Month", "Year"], id: \.self) { Text($0) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedPeriod)
                            Image(systemName: "chevron.down")
                                .font(.scaled(11, weight: .semibold))
                        }
                        .font(.scaled(14, weight: .medium))
                    }
                }
            }
            .onAppear {
                fetch()
                withAnimation(.easeOut(duration: 0.3)) { appeared = true }
                Task { await companyVM.loadCompanies() }
            }
            .onChange(of: selectedPeriod) { _ in fetch() }
            .onChange(of: session.selectedCompanyId) { _ in fetch() }
        }
    }
    
    private var revenueTrend: [DailyRevenue]? { viewModel.dashboard?.revenue.trend }

    /// Seven days of revenue as a small column chart.
    ///
    /// The bars sit on a drawn baseline and carry weekday labels, because a bare row of
    /// rectangles floating in a box reads as a chart that failed to load — which is
    /// exactly how it looked in a week with one trading day. A day with no sales now
    /// renders as an empty column above the rule rather than a 3pt stub, and the busiest
    /// day is called out in words so the chart says something even at a glance.
    @ViewBuilder
    private func revenueChart(_ trend: [DailyRevenue]) -> some View {
        let peak = trend.map(\.total).max() ?? 0
        let scale = max(peak, 1)
        let chartHeight: CGFloat = 72

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Last 7 days")
                    .font(.scaled(12, weight: .medium))
                    .foregroundColor(.sMutedFG)
                Spacer()
                if peak > 0 {
                    Text("Best day \(Money.text(peak))")
                        .font(.scaled(12))
                        .foregroundColor(.sMutedFG)
                }
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(trend.enumerated()), id: \.element.id) { index, day in
                    let isToday = index == trend.count - 1
                    let filled = CGFloat(day.total / scale) * chartHeight

                    VStack(spacing: 6) {
                        // The full-height track keeps every column the same size, so a
                        // quiet day reads as "nothing sold" instead of a missing bar.
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.sMuted.opacity(0.35))
                                .frame(height: chartHeight)

                            if day.total > 0 {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isToday ? Color.sAccent : Color.sAccent.opacity(0.45))
                                    .frame(height: max(6, filled))
                            }
                        }
                        .frame(maxWidth: .infinity)

                        Text(AppDate.weekdayInitial(fromWire: day.date))
                            .font(.scaled(11, weight: isToday ? .semibold : .regular))
                            .foregroundColor(isToday ? .sForeground : .sMutedFG)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(day.date), \(Money.text(day.total))")
                }
            }
            .overlay(alignment: .bottom) {
                // A baseline the columns stand on, so the group reads as a chart.
                Rectangle()
                    .fill(Color.sBorder)
                    .frame(height: 1)
                    .padding(.bottom, 22)
            }
        }
    }

    // MARK: - Revenue Card
    var revenueCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total revenue")
                        .font(.scaled(13))
                        .foregroundColor(.sMutedFG)
                    Text(Money.compact(viewModel.dashboard?.revenue.total ?? 0))
                        .font(.scaled(30, weight: .semibold))
                        .foregroundColor(.sForeground)
                }
                Spacer()
                
                let change = viewModel.dashboard?.revenue.changePercent ?? 0
                HStack(spacing: 4) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.scaled(11, weight: .semibold))
                    Text("\(String(format: "%.1f", abs(change)))%")
                        .font(.scaled(12, weight: .medium))
                }
                .foregroundColor(change >= 0
                                 ? Color(red: 0.086, green: 0.639, blue: 0.341)
                                 : Color(red: 0.863, green: 0.149, blue: 0.149))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(change >= 0
                              ? Color(red: 0.086, green: 0.639, blue: 0.341).opacity(0.08)
                              : Color(red: 0.863, green: 0.149, blue: 0.149).opacity(0.08))
                        .overlay(
                            Capsule()
                                .stroke(change >= 0
                                        ? Color(red: 0.086, green: 0.639, blue: 0.341).opacity(0.2)
                                        : Color(red: 0.863, green: 0.149, blue: 0.149).opacity(0.2),
                                        lineWidth: 0.5)
                        )
                )
            }
            
            // Last seven days of real revenue. Never invented: when the server sends no
            // trend the chart says so rather than drawing shapes.
            // A week of empty columns reads as a chart that failed to load, so a week
            // with no sales says so in words instead.
            if let trend = revenueTrend, trend.contains(where: { $0.total > 0 }) {
                revenueChart(trend)
            } else {
                Text("No sales recorded in the last 7 days")
                    .font(.scaled(13))
                    .foregroundColor(.sMutedFG)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 18)
            }
        }
        .padding(16)
        .background(Color.sCard)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.sBorder, lineWidth: 0.5)
        )
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }
    
    
    // MARK: - Stats Row
    var statsRow: some View {
        HStack(spacing: 10) {
            HomeStatCard(
                icon: "doc.text",
                label: "Invoices",
                value: "\(viewModel.dashboard?.counts.invoices ?? 0)"
            )
            HomeStatCard(
                icon: "person",
                label: "Clients",
                value: "\(viewModel.dashboard?.counts.clients ?? 0)"
            )
            HomeStatCard(
                icon: "cube",
                label: "Items",
                value: "\(viewModel.dashboard?.counts.items ?? 0)"
            )
        }
        .padding(.horizontal, 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }
    
    // MARK: - Quick Actions
    var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Quick actions")
                .font(.scaled(13, weight: .medium))
                .foregroundColor(.sMutedFG)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)
            
            Rectangle().fill(Color.sBorder).frame(height: 0.5)
            
            HomeActionRow(
                icon: "doc.text",
                title: "Create invoice",
                subtitle: "Bill a client",
                destination: AnyView(CreateInvoiceView())
            )
            
            Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.leading, 52)
            
            HomeActionRow(
                icon: "person.badge.plus",
                title: "Add client",
                subtitle: "New customer",
                destination: AnyView(ClientFormView())
            )
            
            Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.leading, 52)
            
            HomeActionRow(
                icon: "cube",
                title: "Add item",
                subtitle: "Product or service",
                destination: AnyView(ItemFormView())
            )
        }
        .background(Color.sCard)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.sBorder, lineWidth: 0.5)
        )
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }
    
    // MARK: - Recent Activity
    var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent activity")
                    .font(.scaled(13, weight: .medium))
                    .foregroundColor(.sMutedFG)
                Spacer()
                NavigationLink(destination: InvoiceView()) {
                    Text("View all")
                        .font(.scaled(13))
                        .foregroundColor(.sAccent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            Rectangle().fill(Color.sBorder).frame(height: 0.5)
            
            if let invoices = viewModel.dashboard?.recentInvoices, !invoices.isEmpty {
                ForEach(Array(invoices.enumerated()), id: \.element.id) { idx, invoice in
                    HomeActivityRow(
                        initials: String(invoice.clientName.prefix(2).uppercased()),
                        name: invoice.clientName,
                        number: invoice.invoiceNumber,
                        amount: Money.text(invoice.total),
                        status: invoice.status.capitalized
                    )
                    if idx < invoices.count - 1 {
                        Rectangle()
                            .fill(Color.sBorder)
                            .frame(height: 0.5)
                            .padding(.leading, 52)
                    }
                }
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.scaled(22))
                            .foregroundColor(.sMutedFG)
                        Text("No recent activity")
                            .font(.scaled(13))
                            .foregroundColor(.sMutedFG)
                    }
                    Spacer()
                }
                .padding(.vertical, 28)
            }
        }
        .background(Color.sCard)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.sBorder, lineWidth: 0.5)
        )
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }
    
    // MARK: - Error
    func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.scaled(24))
                .foregroundColor(.sMutedFG)
            Text(message)
                .font(.scaled(13))
                .foregroundColor(.sMutedFG)
                .multilineTextAlignment(.center)
            Button {
                fetch()
            } label: {
                Text("Retry")
                    .font(.scaled(13, weight: .medium))
                    .foregroundColor(.sAccent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 20)
    }

    // MARK: - Skeleton
    var skeletonView: some View {
        VStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.sMuted)
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.sBorder, lineWidth: 0.5)
                    )
                    .shimmer()
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Stat Card
struct HomeStatCard: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.scaled(14))
                .foregroundColor(.sMutedFG)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.scaled(22, weight: .semibold))
                    .foregroundColor(.sForeground)
                Text(label)
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
                    // Three of these sit side by side, so at large text sizes the
                    // column is narrower than the word: "Invoices" broke as "Invoic /
                    // es". Shrink a little before wrapping, and never break a word.
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.sCard)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.sBorder, lineWidth: 0.5)
        )
        .cornerRadius(10)
    }
}

// MARK: - Action Row
struct HomeActionRow: View {
    /// The icon inside this container scales with the reader's text size, so the
    /// container has to as well or the glyph outgrows its own tile.
    @ScaledMetric(relativeTo: .body) private var tile: CGFloat = 36

    let icon: String
    let title: String
    let subtitle: String
    let destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.sMuted)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.sBorder, lineWidth: 0.5)
                        )
                        .frame(width: tile, height: tile)
                    Image(systemName: icon)
                        .font(.scaled(14))
                        .foregroundColor(.sForeground)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.scaled(14, weight: .medium))
                        .foregroundColor(.sForeground)
                    Text(subtitle)
                        .font(.scaled(12))
                        .foregroundColor(.sMutedFG)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Activity Row
struct HomeActivityRow: View {
    let initials: String
    let name: String
    let number: String
    let amount: String
    let status: String
    
    var statusColor: Color {
        switch status.lowercased() {
        case "paid":               return Color(red: 0.086, green: 0.639, blue: 0.341)
        case "pending", "partial": return Color(red: 0.722, green: 0.494, blue: 0.051)
        default:                   return Color(UIColor.systemGray)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.sMuted)
                    .overlay(Circle().stroke(Color.sBorder, lineWidth: 0.5))
                    .frame(width: 36, height: 36)
                Text(initials)
                    .font(.scaled(12, weight: .semibold))
                    .foregroundColor(.sForeground)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.scaled(14, weight: .medium))
                    .foregroundColor(.sForeground)
                Text(number)
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(amount)
                    .font(.scaled(14, weight: .semibold))
                    .foregroundColor(.sForeground)
                Text(status)
                    .font(.scaled(11, weight: .medium))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(statusColor.opacity(0.08))
                            .overlay(
                                Capsule()
                                    .stroke(statusColor.opacity(0.2), lineWidth: 0.5)
                            )
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
// Add this to DesignSystem.swift

// MARK: - Shimmer Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.sBorder.opacity(0),
                        Color.sBorder.opacity(0.5),
                        Color.sBorder.opacity(0)
                    ],
                    startPoint: .init(x: phase - 0.3, y: 0),
                    endPoint: .init(x: phase + 0.3, y: 0)
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
