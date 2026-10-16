import SwiftUI

struct AgingReportView: View {
    @StateObject private var vm = AgingReportViewModel()
    @State private var shareURL: URL?


    var body: some View {
        Group {
            if vm.isLoading && vm.report == nil {
                ProgressView()
                    .tint(.sAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let report = vm.report, report.clients.isEmpty {
                emptyState
            } else if let report = vm.report {
                List {
                    summaryCard(report)
                        .listHeaderRow()

                    ForEach(report.clients) { row in
                        NavigationLink {
                            LedgerListView(clientID: row.client_id)
                        } label: {
                            AgingClientRow(row: row, colors: AgingBuckets.colors)
                        }
                        .standardListRow()
                        .listRowSeparator(.hidden, edges: row.id == report.clients.first?.id ? .top : [])
                    }
                }
                .listStyle(.plain)
                .contentMargins(.bottom, 16, for: .scrollContent)
                .refreshable { await vm.load() }
            }
        }
        .safeAreaInset(edge: .top) {
            if let message = vm.errorMessage {
                ReportStatusView(message: message, hasData: vm.report != nil) { await vm.load() }
                    .background(Color.sBackground)
            } else if vm.isLoading && vm.report != nil {
                ProgressView("Refreshing…").padding(8)
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
                .disabled(!vm.canExport)
            }
        }
        .sheet(item: Binding(
            get: { shareURL.map { AgingShareWrapper(url: $0) } },
            set: { shareURL = $0?.url }
        )) { wrapper in
            AgingShareSheet(activityItems: [wrapper.url])
        }
        .task(id: SessionManager.shared.selectedCompanyId) { await vm.load() }
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Something went wrong")
        }
    }

    // MARK: - Summary
    private func summaryCard(_ report: AgingReportResponse) -> some View {
        let t = report.totals
        return SummaryCard(
            title: "Total outstanding",
            value: Money.text(report.grand_total),
            stats: AgingBuckets.stats([t.current, t.days_1_30, t.days_31_60, t.days_61_90, t.days_90_plus])
        ) {
            Text("Across \(report.clients.count) client\(report.clients.count == 1 ? "" : "s") · as of \(AppDate.text(fromWire: report.as_of))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
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

// MARK: - Shared by the client and supplier aging reports

enum AgingBuckets {
    static let labels = ["Current", "1-30d", "31-60d", "61-90d", "90d+"]
    static let colors: [Color] = [.secondary, .orange, .orange, .red, .red]

    /// One stat per bucket, coloured by age only when it holds money.
    static func stats(_ values: [Double]) -> [AdaptiveStatRow.Stat] {
        zip(labels, zip(values, colors)).map { label, pair in
            .init(label: label, value: Money.text(pair.0), color: pair.0 > 0 ? pair.1 : .sMutedFG)
        }
    }
}

// MARK: - Aging row
struct AgingBucketRow: View {
    @Environment(\.dynamicTypeSize) private var textSize
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
                AdaptiveFormRow {
                    Text(name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
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
                .accessibilityHidden(true)
                Text(zip(AgingBuckets.labels, buckets).filter { $0.1 > 0 }.map { "\($0.0): \(Money.text($0.1))" }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
