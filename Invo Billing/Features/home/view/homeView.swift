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
                        .padding(.bottom, 100)
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
                                .font(.system(size: 12))
                            Text(selectedCompanyName)
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
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
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .font(.system(size: 14, weight: .medium))
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

    // MARK: - Revenue Card
    var revenueCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total revenue")
                        .font(.system(size: 13))
                        .foregroundColor(.sMutedFG)
                    Text("₹\(formattedAmount(viewModel.dashboard?.revenue.total ?? 0))")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.sForeground)
                }
                Spacer()
                
                let change = viewModel.dashboard?.revenue.changePercent ?? 0
                HStack(spacing: 4) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(String(format: "%.1f", abs(change)))%")
                        .font(.system(size: 12, weight: .medium))
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
            
            // Last seven days of real revenue. This previously drew a fixed set of bar
            // heights — invented data on the dashboard of a billing app. Hidden
            // entirely when the server sends no trend, rather than showing something
            // made up.
            if let trend = revenueTrend, !trend.isEmpty {
                let peak = max(trend.map(\.total).max() ?? 0, 1)

                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(trend.enumerated()), id: \.element.id) { index, day in
                        let isToday = index == trend.count - 1
                        // Scaled against the week's peak, with a visible floor so a
                        // zero-revenue day reads as an empty day rather than a gap.
                        let height = max(3, CGFloat(day.total / peak) * 64)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(isToday ? Color.sAccent : Color.sMuted)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(isToday ? Color.clear : Color.sBorder, lineWidth: 0.5)
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: height)
                    }
                }
                .frame(height: 64)
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
    
    func formattedAmount(_ value: Double) -> String {
        if value >= 100000 { return String(format: "%.1fL", value / 100000) }
        if value >= 1000 { return String(format: "%.0fK", value / 1000) }
        return "\(Int(value))"
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
                .font(.system(size: 13, weight: .medium))
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
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.sMutedFG)
                Spacer()
                NavigationLink(destination: InvoiceView()) {
                    Text("View all")
                        .font(.system(size: 13))
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
                        amount: "₹\(Int(invoice.total))",
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
                            .font(.system(size: 22))
                            .foregroundColor(.sMutedFG)
                        Text("No recent activity")
                            .font(.system(size: 13))
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
                .font(.system(size: 24))
                .foregroundColor(.sMutedFG)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.sMutedFG)
                .multilineTextAlignment(.center)
            Button {
                fetch()
            } label: {
                Text("Retry")
                    .font(.system(size: 13, weight: .medium))
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
                .font(.system(size: 14))
                .foregroundColor(.sMutedFG)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.sForeground)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.sMutedFG)
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
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(.sForeground)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.sForeground)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.sMutedFG)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
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
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.sForeground)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.sForeground)
                Text(number)
                    .font(.system(size: 12))
                    .foregroundColor(.sMutedFG)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(amount)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.sForeground)
                Text(status)
                    .font(.system(size: 11, weight: .medium))
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
