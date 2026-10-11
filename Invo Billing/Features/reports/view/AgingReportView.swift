import SwiftUI

struct AgingReportView: View {
    @StateObject private var vm = AgingReportViewModel()
    @State private var shareURL: URL?

    private let bucketColors: [Color] = [
        .sNeutral,                          // Current
        .sWarning,        // 1-30
        Color(red: 0.910, green: 0.451, blue: 0.098),        // 31-60
        Color(red: 0.863, green: 0.259, blue: 0.149),        // 61-90
        Color(red: 0.702, green: 0.098, blue: 0.098)         // 90+
    ]
    private let bucketLabels = ["Current", "1-30d", "31-60d", "61-90d", "90d+"]

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView()
                    .tint(.sAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let report = vm.report, report.clients.isEmpty {
                emptyState
            } else if let report = vm.report {
                List {
                    summaryCard(report)
                        .padding(.horizontal, AppSpacing.page)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    ForEach(report.clients) { row in
                        NavigationLink {
                            LedgerListView(clientID: row.client_id)
                        } label: {
                            AgingClientRow(row: row, colors: bucketColors)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden, edges: row.id == report.clients.first?.id ? .top : [])
                    }
                }
                .listStyle(.plain)
                .contentMargins(.bottom, 16, for: .scrollContent)
                .refreshable { await vm.load() }
            }
        }
        .navigationTitle("Client Aging")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let url = vm.exportCSV() { shareURL = url }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(vm.report == nil)
            }
        }
        .sheet(item: Binding(
            get: { shareURL.map { AgingShareWrapper(url: $0) } },
            set: { shareURL = $0?.url }
        )) { wrapper in
            AgingShareSheet(activityItems: [wrapper.url])
        }
        .task { await vm.load() }
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Something went wrong")
        }
    }

    // MARK: - Summary
    private func summaryCard(_ report: AgingReportResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Total outstanding")
                    .font(.subheadline)
                    .foregroundColor(.sMutedFG)
                Text(Money.text(report.grand_total)).moneyLine()
                    .font(.title.bold())
                    .foregroundColor(.sForeground)
                Text("Across \(report.clients.count) client\(report.clients.count == 1 ? "" : "s") · as of \(AppDate.text(fromWire: report.as_of))")
                    .font(.footnote)
                    .foregroundColor(.sMutedFG)
            }

            Divider()

            let values = [
                report.totals.current, report.totals.days_1_30, report.totals.days_31_60,
                report.totals.days_61_90, report.totals.days_90_plus
            ]
            AdaptiveStatRow(stats: (0..<5).map { i in
                .init(
                    label: bucketLabels[i],
                    value: Money.text(values[i]),
                    color: values[i] > 0 ? bucketColors[i] : .sMutedFG
                )
            })
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Empty State
    private var emptyState: some View {
        ContentUnavailableView(
            "Nothing outstanding",
            systemImage: "checkmark.circle",
            description: Text("Every invoice is fully paid right now")
        )
    }
}

// MARK: - Aging row (shared by the client and supplier reports)
struct AgingBucketRow: View {
    let name: String
    let total: Double
    let buckets: [Double]
    let colors: [Color]

    private var segments: [(Double, Color)] {
        zip(buckets, colors).filter { $0.0 > 0 }
    }

    /// The oldest bucket with money in it — used to color the trailing total, so the
    /// number itself signals urgency even before you look at the bar.
    private var worstColor: Color {
        segments.last?.1 ?? .sForeground
    }

    var body: some View {
        HStack(spacing: 12) {
            MinimalAvatarView(name: name)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(Money.text(total)).moneyLine()
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(worstColor)
                }

                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                            Capsule()
                                .fill(segment.1)
                                .frame(width: max(4, geo.size.width * (segment.0 / max(total, 0.01))))
                        }
                    }
                }
                .frame(height: 5)
            }
            .alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }
        }
    }
}

private struct AgingClientRow: View {
    let row: ClientAgingRow
    let colors: [Color]

    var body: some View {
        AgingBucketRow(
            name: row.client_name,
            total: row.total,
            buckets: [row.buckets.current, row.buckets.days_1_30, row.buckets.days_31_60,
                      row.buckets.days_61_90, row.buckets.days_90_plus],
            colors: colors
        )
    }
}

private struct AgingShareWrapper: Identifiable {
    let id = UUID()
    let url: URL
}

private struct AgingShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
