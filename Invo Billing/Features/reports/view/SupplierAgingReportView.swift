import SwiftUI

struct SupplierAgingReportView: View {
    @StateObject private var vm = SupplierAgingViewModel()
    @State private var shareItem: SupplierShareWrapper?


    var body: some View {
        Group {
            if vm.isLoading && vm.report == nil {
                ProgressView()
                    .tint(.sAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let report = vm.report, !report.suppliers.isEmpty {
                List {
                    summaryCard(report)
                        .listHeaderRow()

                    ForEach(report.suppliers) { row in
                        AgingBucketRow(
                            name: row.supplier_name,
                            total: row.total,
                            buckets: [row.buckets.current, row.buckets.days_1_30, row.buckets.days_31_60,
                                      row.buckets.days_61_90, row.buckets.days_90_plus],
                            colors: AgingBuckets.colors
                        )
                        .standardListRow()
                        .listRowSeparator(.hidden, edges: row.id == report.suppliers.first?.id ? .top : [])
                    }
                }
                .listStyle(.plain)
                .contentMargins(.bottom, 16, for: .scrollContent)
                .refreshable { await vm.load() }
            } else {
                ContentUnavailableView(
                    "No outstanding supplier bills",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("All bills are paid or there are no bills yet.")
                )
            }
        }
        .navigationTitle("Supplier Aging")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let url = vm.exportCSV() { shareItem = SupplierShareWrapper(url: url) }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(vm.report == nil)
            }
        }
        .sheet(item: $shareItem) { wrapper in
            SupplierAgingShareSheet(url: wrapper.url)
        }
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.errorMessage ?? "") }
        .task { await vm.load() }
    }

    private func summaryCard(_ report: SupplierAgingReport) -> some View {
        let t = report.totals
        return SummaryCard(
            title: "Total owed to suppliers",
            value: Money.text(report.grand_total),
            stats: AgingBuckets.stats([t.current, t.days_1_30, t.days_31_60, t.days_61_90, t.days_90_plus])
        ) {
            Text("Across \(report.suppliers.count) supplier\(report.suppliers.count == 1 ? "" : "s") · as of \(AppDate.text(fromWire: report.as_of))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SupplierShareWrapper: Identifiable {
    let id = UUID()
    let url: URL
}

private struct SupplierAgingShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
