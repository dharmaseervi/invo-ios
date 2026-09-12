import SwiftUI

struct GSTReportView: View {
    @StateObject private var vm = GSTReportViewModel()
    @State private var shareURL: URL?

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                monthNavigator

                if vm.isLoading {
                    Spacer()
                    ProgressView().tint(.sAccent)
                    Spacer()
                } else if let report = vm.report, report.summary.invoice_count == 0 {
                    emptyState
                } else if let report = vm.report {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            summaryCard(report)
                            hsnSection(report)
                            invoiceSection(report)
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                    .refreshable { await vm.load() }
                }
            }
        }
        .navigationTitle("GST Reports")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let url = vm.exportCSV() { shareURL = url }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(vm.report?.summary.invoice_count == 0 || vm.report == nil)
            }
        }
        .task { await vm.load() }
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Something went wrong")
        }
        .sheet(item: Binding(
            get: { shareURL.map { ShareURLWrapper(url: $0) } },
            set: { shareURL = $0?.url }
        )) { wrapper in
            GSTShareSheet(activityItems: [wrapper.url])
        }
    }

    // MARK: - Month Navigator
    private var monthNavigator: some View {
        HStack {
            Button { vm.goToPreviousMonth() } label: {
                Image(systemName: "chevron.left")
                    .font(.scaled(14, weight: .semibold))
                    .foregroundColor(.sForeground)
                    .frame(width: 32, height: 32)
            }
            Spacer()
            Text(vm.monthLabel)
                .font(.scaled(15, weight: .semibold))
                .foregroundColor(.sForeground)
            Spacer()
            Button { vm.goToNextMonth() } label: {
                Image(systemName: "chevron.right")
                    .font(.scaled(14, weight: .semibold))
                    .foregroundColor(.sForeground)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Summary Card
    private func summaryCard(_ report: GSTReportResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Taxable value")
                    .font(.scaled(13))
                    .foregroundColor(.sMutedFG)
                Text(Money.text(report.summary.taxable_value))
                    .font(.scaled(26, weight: .bold))
                    .foregroundColor(.sForeground)
                Text("\(report.summary.invoice_count) invoice\(report.summary.invoice_count == 1 ? "" : "s") · \(report.company_state.isEmpty ? "State not set" : report.company_state)")
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
            }

            Rectangle().fill(Color.sBorder).frame(height: 0.5)

            HStack(spacing: 0) {
                taxStat(label: "CGST", value: report.summary.cgst)
                Rectangle().fill(Color.sBorder).frame(width: 0.5, height: 30)
                taxStat(label: "SGST", value: report.summary.sgst)
                Rectangle().fill(Color.sBorder).frame(width: 0.5, height: 30)
                taxStat(label: "IGST", value: report.summary.igst)
                Rectangle().fill(Color.sBorder).frame(width: 0.5, height: 30)
                taxStat(label: "Total", value: report.summary.total, isTotal: true)
            }
        }
        .padding(18)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }

    private func taxStat(label: String, value: Double, isTotal: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Money.text(value))
                .font(.scaled(13, weight: .semibold))
                .foregroundColor(isTotal ? .sAccent : .sForeground)
            Text(label)
                .font(.scaled(10.5))
                .foregroundColor(.sMutedFG)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
    }

    // MARK: - HSN Summary
    private func hsnSection(_ report: GSTReportResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HSN summary")
                .font(.scaled(13, weight: .medium))
                .foregroundColor(.sMutedFG)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(report.hsn_summary.enumerated()), id: \.element.id) { idx, row in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.hsn_code.isEmpty ? "No HSN" : row.hsn_code)
                                .font(.scaled(13, weight: .medium))
                                .foregroundColor(.sForeground)
                            Text("\(String(format: "%.0f", row.total_qty)) units · \(String(format: "%.0f", row.tax_rate))% GST")
                                .font(.scaled(11))
                                .foregroundColor(.sMutedFG)
                        }
                        Spacer()
                        Text(Money.text(row.total_value))
                            .font(.scaled(13, weight: .semibold))
                            .foregroundColor(.sForeground)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    if idx < report.hsn_summary.count - 1 {
                        Rectangle().fill(Color.sBorder).frame(height: 0.5)
                    }
                }
            }
            .background(Color.sCard)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Invoice-wise
    private func invoiceSection(_ report: GSTReportResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Invoice-wise")
                .font(.scaled(13, weight: .medium))
                .foregroundColor(.sMutedFG)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(report.invoices.enumerated()), id: \.element.id) { idx, row in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.invoice_number)
                                .font(.scaled(13, weight: .medium))
                                .foregroundColor(.sForeground)
                            Text(row.client_name)
                                .font(.scaled(11))
                                .foregroundColor(.sMutedFG)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Money.text(row.total))
                                .font(.scaled(13, weight: .semibold))
                                .foregroundColor(.sForeground)
                            Text(row.igst > 0 ? "IGST" : "CGST+SGST")
                                .font(.scaled(10))
                                .foregroundColor(.sMutedFG)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    if idx < report.invoices.count - 1 {
                        Rectangle().fill(Color.sBorder).frame(height: 0.5)
                    }
                }
            }
            .background(Color.sCard)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.scaled(32))
                .foregroundColor(.sMutedFG)
            Text("No GST activity in \(vm.monthLabel)")
                .font(.scaled(15, weight: .medium))
                .foregroundColor(.sForeground)
            Text("Issued invoices for this month will show up here")
                .font(.scaled(13))
                .foregroundColor(.sMutedFG)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Share helpers
private struct ShareURLWrapper: Identifiable {
    let id = UUID()
    let url: URL
}

private struct GSTShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
