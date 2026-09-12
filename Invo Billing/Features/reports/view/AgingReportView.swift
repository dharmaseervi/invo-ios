import SwiftUI

struct AgingReportView: View {
    @StateObject private var vm = AgingReportViewModel()

    private let bucketColors: [Color] = [
        Color(UIColor.systemGray),                          // Current
        Color(red: 0.851, green: 0.588, blue: 0.082),        // 1-30
        Color(red: 0.910, green: 0.451, blue: 0.098),        // 31-60
        Color(red: 0.863, green: 0.259, blue: 0.149),        // 61-90
        Color(red: 0.702, green: 0.098, blue: 0.098)         // 90+
    ]
    private let bucketLabels = ["Current", "1-30d", "31-60d", "61-90d", "90d+"]

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            if vm.isLoading {
                ProgressView().tint(.sAccent)
            } else if let report = vm.report, report.clients.isEmpty {
                emptyState
            } else if let report = vm.report {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        summaryCard(report)
                        clientList(report)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .refreshable { await vm.load() }
            }
        }
        .navigationTitle("Client Aging")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Something went wrong")
        }
    }

    // MARK: - Summary
    private func summaryCard(_ report: AgingReportResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total outstanding")
                    .font(.scaled(13))
                    .foregroundColor(.sMutedFG)
                Text(Money.text(report.grand_total)).moneyLine()
                    .font(.scaled(26, weight: .bold))
                    .foregroundColor(.sForeground)
                Text("Across \(report.clients.count) client\(report.clients.count == 1 ? "" : "s") · as of \(AppDate.text(fromWire: report.as_of))")
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
            }

            Rectangle().fill(Color.sBorder).frame(height: 0.5)

            let values = [
                report.totals.current, report.totals.days_1_30, report.totals.days_31_60,
                report.totals.days_61_90, report.totals.days_90_plus
            ]
            HStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Money.text(values[i])).moneyLine()
                            .font(.scaled(12.5, weight: .semibold))
                            .foregroundColor(values[i] > 0 ? bucketColors[i] : .sMutedFG)
                        Text(bucketLabels[i])
                            .font(.scaled(10))
                            .foregroundColor(.sMutedFG)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if i < 4 {
                        Rectangle().fill(Color.sBorder).frame(width: 0.5, height: 26)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }

    // MARK: - Client List
    private func clientList(_ report: AgingReportResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("By client")
                .font(.scaled(13, weight: .medium))
                .foregroundColor(.sMutedFG)
                .padding(.horizontal, 20)

            VStack(spacing: 10) {
                ForEach(report.clients) { row in
                    NavigationLink {
                        LedgerListView(clientID: row.client_id)
                    } label: {
                        AgingClientRow(row: row, colors: bucketColors)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.scaled(32))
                .foregroundColor(.sMutedFG)
            Text("Nothing outstanding")
                .font(.scaled(15, weight: .medium))
                .foregroundColor(.sForeground)
            Text("Every invoice is fully paid right now")
                .font(.scaled(13))
                .foregroundColor(.sMutedFG)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Client Row
private struct AgingClientRow: View {
    let row: ClientAgingRow
    let colors: [Color]

    private var initials: String {
        let parts = row.client_name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(row.client_name.prefix(2)).uppercased()
    }

    private var segments: [(Double, Color)] {
        let values = [row.buckets.current, row.buckets.days_1_30, row.buckets.days_31_60, row.buckets.days_61_90, row.buckets.days_90_plus]
        return zip(values, colors).filter { $0.0 > 0 }
    }

    /// The oldest bucket with money in it — used to color the trailing total, so the
    /// number itself signals urgency even before you look at the bar.
    private var worstColor: Color {
        segments.last?.1 ?? .sForeground
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.sAccentMuted).frame(width: 36, height: 36)
                    Text(initials)
                        .font(.scaled(12, weight: .semibold))
                        .foregroundColor(.sAccent)
                }
                Text(row.client_name)
                    .font(.scaled(14, weight: .medium))
                    .foregroundColor(.sForeground)
                Spacer()
                Text(Money.text(row.total)).moneyLine()
                    .font(.scaled(14, weight: .semibold))
                    .foregroundColor(worstColor)
            }

            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        Capsule()
                            .fill(segment.1)
                            .frame(width: max(4, geo.size.width * (segment.0 / row.total)))
                    }
                }
            }
            .frame(height: 5)
        }
        .padding(14)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(12)
    }
}
