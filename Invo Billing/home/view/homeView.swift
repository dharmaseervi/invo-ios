import SwiftUI

extension Color {
    static let accentBrand = Color(red: 32/255, green: 64/255, blue: 96/255) // muted indigo
    static let softBackground = Color.black.opacity(0.04)
}

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var session: SessionManager
    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedPeriod = "Week"
    
    private func apiPeriod(_ ui: String) -> String {
        ui.lowercased()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 28) {
                            if viewModel.isLoading {
                                ProgressView().padding(.top, 40)
                            } else {
                                metrics
                                quickActions
                                recentActivity
                            }
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear { fetch() }
            .onChange(of: selectedPeriod) { _ in fetch() }
        }
    }
    
    private func fetch() {
        Task { await viewModel.load(period: apiPeriod(selectedPeriod)) }
    }
}


// MARK: - Sub-Sections
private extension HomeView {
    
    var header: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dashboard")
                        .font(.system(size: 30, weight: .thin))
                    
                    Text("Overview for this \(selectedPeriod.lowercased())")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            
            periodSelector
            Divider()
        }
        .padding(.top, 10)
    }
    
    var periodSelector: some View {
        HStack(spacing: 0) {
            ForEach(["Week", "Month", "Year"], id: \.self) { period in
                Button {
                    selectedPeriod = period
                } label: {
                    VStack(spacing: 6) {
                        Text(period.uppercased())
                            .font(.system(size: 10, weight: selectedPeriod == period ? .semibold : .light))
                            .foregroundColor(selectedPeriod == period ? .accentBrand : .gray)
                        
                        Capsule()
                            .fill(selectedPeriod == period ? Color.accentBrand : .clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
    }
}
private extension HomeView {
    
    var metrics: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("KEY METRICS")
            
            VStack(spacing: 16) {
                revenueCard
                countsRow
            }
            .padding(.horizontal, 24)
        }
    }
    
    var revenueCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Total Revenue")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            
            HStack(alignment: .lastTextBaseline) {
                Text("₹\(Int(viewModel.dashboard?.revenue.total ?? 0))")
                    .font(.system(size: 38, weight: .thin))
                
                Spacer()
                
                trendView
            }
        }
        .padding(20)
        .background(Color.softBackground)
        .cornerRadius(14)
    }
    
    var trendView: some View {
        let value = viewModel.dashboard?.revenue.changePercent ?? 0
        return HStack(spacing: 4) {
            Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
            Text("\(String(format: "%.1f", abs(value)))%")
        }
        .font(.system(size: 12))
        .foregroundColor(value >= 0 ? .accentBrand : .secondary)
    }
    
    var countsRow: some View {
        HStack {
            MiniStatCard(title: "Invoices", value: "\(viewModel.dashboard?.counts.invoices ?? 0)")
            Divider()
            MiniStatCard(title: "Clients", value: "\(viewModel.dashboard?.counts.clients ?? 0)")
            Divider()
            MiniStatCard(title: "Items", value: "\(viewModel.dashboard?.counts.items ?? 0)")
        }
        .padding(16)
        .background(Color.softBackground)
        .cornerRadius(14)
    }
}
   
private extension HomeView {
    
    var quickActions: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("QUICK ACTIONS")
            
            VStack(spacing: 0) {
                QuickActionRowZara(title: "Create Invoice", subtitle: "Bill your client", icon: "doc.text", destination: AnyView(CreateInvoiceView()))
                Divider().padding(.leading, 52)
                QuickActionRowZara(title: "Add Client", subtitle: "New customer", icon: "person.crop.circle.badge.plus", destination: AnyView(ClientFormView()))
                Divider().padding(.leading, 52)
                QuickActionRowZara(title: "Add Item", subtitle: "Product or service", icon: "cube.box", destination: AnyView(ItemFormView()))
            }
            .padding(.horizontal, 24)
            .background(Color.softBackground)
            .cornerRadius(14)
            .padding(.horizontal, 24)
        }
    }
}
private extension HomeView {
    
    var recentActivity: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sectionTitle("RECENT ACTIVITY")
                Spacer()
                NavigationLink("VIEW ALL", destination: InvoiceView())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.accentBrand)
            }
            .padding(.horizontal, 24)
            
            VStack(spacing: 0) {
                if let invoices = viewModel.dashboard?.recentInvoices, !invoices.isEmpty {
                    ForEach(invoices) { invoice in
                        ActivityRowEnhancedZara(
                            title: invoice.invoiceNumber,
                            subtitle: invoice.clientName,
                            amount: "₹\(Int(invoice.total))",
                            status: invoice.status.capitalized,
                            isLast: invoice.id == invoices.last?.id
                        )
                    }
                } else {
                    Text("No recent activity")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .padding(20)
                }
            }
            .padding(.horizontal, 24)
            .background(Color.softBackground)
            .cornerRadius(14)
            .padding(.horizontal, 24)
        }
    }
}
private extension HomeView {
    func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.4)
            .foregroundColor(.secondary)
            .padding(.horizontal, 24)
    }
}


// MARK: - Reusable Components

struct MiniStatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .regular))
                .foregroundColor(.gray)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 18, weight: .thin))
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickActionRowZara: View {
    let title: String; let subtitle: String; let icon: String; let destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .ultraLight))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .regular))
                    Text(subtitle).font(.system(size: 11, weight: .light)).foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .light)).foregroundColor(.gray)
            }
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ActivityRowEnhancedZara: View {
    let title: String; let subtitle: String; let amount: String; let status: String; let isLast: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 13, weight: .medium))
                    Text(subtitle).font(.system(size: 12, weight: .light)).foregroundColor(.gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(amount).font(.system(size: 13, weight: .regular))
                    Text(status).font(.system(size: 10, weight: .light))
                        .padding(.horizontal, 6)
                        .background(status == "Paid" ? Color.black.opacity(0.05) : Color.clear)
                        .border(status == "Paid" ? Color.clear : Color.black.opacity(0.1), width: 0.5)
                }
            }
            .padding(.vertical, 16)
            if !isLast { Divider().background(Color.black.opacity(0.05)) }
        }
    }
}
