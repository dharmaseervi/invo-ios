import SwiftUI

struct SupplierAgingReportView: View {
    @StateObject private var vm = SupplierAgingViewModel()
    @State private var shareItem: SupplierShareWrapper?

    private let bucketColors: [Color] = [
        .sNeutral,
        .sWarning,
        Color(red: 0.910, green: 0.451, blue: 0.098),
        Color(red: 0.863, green: 0.259, blue: 0.149),
        Color(red: 0.702, green: 0.098, blue: 0.098)
    ]
    private let bucketLabels = ["Current", "1-30d", "31-60d", "61-90d", "90d+"]

    var body: some View {
        Group {
            if vm.isLoading && vm.report == nil {
                ProgressView()
                    .tint(.sAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let report = vm.report, !report.suppliers.isEmpty {
                List {
                    summaryCard(report)
                        .padding(.horizontal, AppSpacing.page)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    ForEach(report.suppliers) { row in
                        AgingBucketRow(
                            name: row.supplier_name,
                            total: row.total,
                            buckets: [row.buckets.current, row.buckets.days_1_30, row.buckets.days_31_60,
                                      row.buckets.days_61_90, row.buckets.days_90_plus],
                            colors: bucketColors
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
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
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Total owed to suppliers")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Money.text(report.grand_total)).moneyLine()
                    .font(.title.bold())
                    .foregroundStyle(.primary)
                Text("Across \(report.suppliers.count) supplier\(report.suppliers.count == 1 ? "" : "s") · as of \(AppDate.text(fromWire: report.as_of))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Divider()

            let t = report.totals
            let values = [t.current, t.days_1_30, t.days_31_60, t.days_61_90, t.days_90_plus]
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
