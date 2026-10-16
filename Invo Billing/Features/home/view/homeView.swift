import SwiftUI

struct HomeView: View {
    @EnvironmentObject var session: SessionManager
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var companyVM = CompanyFormViewModel()
    @State private var selectedPeriod = "Week"
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedCompanyName: String {
        companyVM.companies.first(where: { $0.id == session.selectedCompanyId })?.name ?? "Select company"
    }

    private func apiPeriod(_ ui: String) -> String { ui.lowercased() }
    private func fetch() async {
        // Not asked for at all when the role cannot have it. Calling it anyway would
        // spend a request to be told 403 and leave an error on screen that is not a
        // fault — the person simply does not do this part of the job.
        guard SessionManager.shared.companyRole.canSeeReports else { return }
        await viewModel.load(period: apiPeriod(selectedPeriod))
    }

    /// Home for somebody who bills at the counter: the work, and none of the money
    /// figures they are not meant to see.
    private var counterHome: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Today")
                    .font(.subheadline)
                    .foregroundColor(.sMutedFG)
                Text(AppDate.text(Date()))
                    .font(.title2.weight(.bold))
                    .foregroundColor(.sForeground)
                Text("Write an invoice, take a payment, look someone up.")
                    .font(.footnote)
                    .foregroundColor(.sMutedFG)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.card)
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

            quickActionsCard
        }
        .padding(.horizontal, AppSpacing.page)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if !session.companyRole.canSeeReports {
                        counterHome
                    } else {
                        if viewModel.dashboard != nil {
                            if viewModel.isLoading {
                                ProgressView("Refreshing figures…").tint(.sAccent)
                            }
                            if let error = viewModel.errorMessage {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Couldn't refresh. These figures may be out of date.").font(.subheadline)
                                    if let updated = viewModel.updatedAt {
                                        Text("Updated \(updated.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.footnote).foregroundStyle(.secondary)
                                    }
                                    Text(error).font(.footnote).foregroundStyle(.secondary)
                                    Button("Retry") { Task { await fetch() } }
                                }.padding(.horizontal, AppSpacing.page)
                            }
                            revenueCard
                            statsRow
                        } else if viewModel.isLoading {
                            skeletonView.accessibilityHidden(true)
                            ProgressView("Loading figures…")
                        } else if let error = viewModel.errorMessage {
                            errorView(error)
                        }
                        quickActionsCard
                        if viewModel.dashboard != nil { recentActivityCard }
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .refreshable { await fetch() }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(session.companyRole.canSeeReports ? "Dashboard" : "Today")
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
                                .font(.footnote)
                            Text(selectedCompanyName)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(.sForeground)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // The period only moves figures this role is never shown.
                    if session.companyRole.canSeeReports {
                    Menu {
                        Picker("Period", selection: $selectedPeriod) {
                            ForEach(["Week", "Month", "Year"], id: \.self) { Text($0) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedPeriod)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .font(.subheadline.weight(.medium))
                    }
                    }
                }
            }
            .task(id: "\(session.selectedCompanyId ?? 0):\(selectedPeriod)") { await fetch() }
            .task {
                if reduceMotion { appeared = true }
                else { withAnimation(.easeOut(duration: 0.3)) { appeared = true } }
                await companyVM.loadCompanies()
            }
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
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.sMutedFG)
                Spacer()
                if peak > 0 {
                    Text("Best day \(Money.text(peak))")
                        .font(.footnote)
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
                            .font(.caption.weight(isToday ? .semibold : .regular))
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
                        .font(.subheadline)
                        .foregroundColor(.sMutedFG)
                    Text(Money.compact(viewModel.dashboard?.revenue.total ?? 0)).moneyLine()
                        .font(.title.weight(.semibold))
                        .foregroundColor(.sForeground)
                }
                Spacer()
                
                let change = viewModel.dashboard?.revenue.changePercent ?? 0
                HStack(spacing: 4) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.weight(.semibold))
                    Text("\(String(format: "%.1f", abs(change)))%")
                        .font(.footnote.weight(.medium))
                }
                .foregroundColor(change >= 0 ? .sSuccess : .sDestructive)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(change >= 0 ? Color.sSuccessMuted : Color.sDestructive.opacity(0.08))
                        .overlay(
                            Capsule()
                                .stroke(change >= 0
                                        ? Color.sSuccessMuted
                                        : Color.sDestructive.opacity(0.2),
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
                    .font(.subheadline)
                    .foregroundColor(.sMutedFG)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 18)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, AppSpacing.page)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }


    // MARK: - Cash position row (receivable / overdue / payable)
    var statsRow: some View {
        VStack(spacing: 10) {
            AdaptiveFormRow {
                cashTile(
                    label: "To collect",
                    value: viewModel.dashboard?.receivables?.total ?? 0,
                    sub: "\(viewModel.dashboard?.receivables?.count ?? 0) invoices",
                    color: .sAccent
                )
                cashTile(
                    label: "Overdue",
                    value: viewModel.dashboard?.receivables?.overdue ?? 0,
                    sub: "Past due date",
                    color: (viewModel.dashboard?.receivables?.overdue ?? 0) > 0 ? .sDestructive : .sMutedFG
                )
                cashTile(
                    label: "To pay",
                    value: viewModel.dashboard?.payables?.total ?? 0,
                    sub: "\(viewModel.dashboard?.payables?.count ?? 0) bills",
                    color: .sMutedFG
                )
            }
        }
        .padding(.horizontal, AppSpacing.page)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }

    private func cashTile(label: String, value: Double, sub: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.sMutedFG)
            Text(Money.compact(value)).moneyLine()
                .font(.subheadline.weight(.semibold))
                .foregroundColor(color)
                .accessibilityLabel(Money.text(value))
            Text(sub)
                .font(.caption)
                .foregroundColor(.sMutedFG)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Quick Actions
    var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Quick actions")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.sMutedFG)
                .padding(.horizontal, AppSpacing.page)
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
            
            if session.companyRole.canEditCatalogue {
                Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.leading, 52)

                HomeActionRow(
                    icon: "cube",
                    title: "Add item",
                    subtitle: "Product or service",
                    destination: AnyView(ItemFormView())
                )
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, AppSpacing.page)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }

    // MARK: - Recent Activity
    var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent activity")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.sMutedFG)
                Spacer()
                NavigationLink(destination: InvoiceView()) {
                    Text("View all")
                        .font(.subheadline)
                        .foregroundColor(.sAccent)
                }
            }
            .padding(.horizontal, AppSpacing.page)
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
                            .font(.title2)
                            .foregroundColor(.sMutedFG)
                        Text("No recent activity")
                            .font(.subheadline)
                            .foregroundColor(.sMutedFG)
                    }
                    Spacer()
                }
                .padding(.vertical, 28)
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, AppSpacing.page)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }

    // MARK: - Error
    func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.sMutedFG)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.sMutedFG)
                .multilineTextAlignment(.center)
            Button {
                Task { await fetch() }
            } label: {
                Text("Retry")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.sAccent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, AppSpacing.page)
    }

    // MARK: - Skeleton
    var skeletonView: some View {
        VStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .frame(height: 80)
                    .shimmer()
            }
        }
        .padding(.horizontal, AppSpacing.page)
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
                .font(.body)
                .foregroundColor(.sMutedFG)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.sForeground)
                Text(label)
                    .font(.footnote)
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
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
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
                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                        .frame(width: tile, height: tile)
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.sForeground)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(.sMutedFG)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundColor(.sMutedFG)
            }
            .padding(.horizontal, AppSpacing.page)
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
        case "paid":               return .sSuccess
        case "pending", "partial": return .sWarning
        default:                   return .sNeutral
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.sAccentMuted)
                    .frame(width: 36, height: 36)
                Text(initials)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.sAccent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.sForeground)
                Text(number)
                    .font(.footnote)
                    .foregroundColor(.sMutedFG)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(amount)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.sForeground)
                Text(status)
                    .font(.caption.weight(.medium))
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
        .padding(.horizontal, AppSpacing.page)
        .padding(.vertical, 12)
    }
}
// Add this to DesignSystem.swift

// MARK: - Shimmer Effect
struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    LinearGradient(colors: [Color.sBorder.opacity(0), Color.sBorder.opacity(0.5), Color.sBorder.opacity(0)],
                        startPoint: .init(x: phase - 0.3, y: 0), endPoint: .init(x: phase + 0.3, y: 0))
                }
            }
            .accessibilityHidden(true)
            .task(id: reduceMotion) {
                guard !reduceMotion else { phase = 0; return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { phase = 1.3 }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
