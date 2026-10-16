import SwiftUI

struct GSTReportView: View {
    @StateObject private var vm = GSTReportViewModel()
    @State private var shareURL: URL?

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                monthNavigator

                if vm.isLoading && vm.report == nil {
                    Spacer()
                    ProgressView().tint(.sAccent)
                    Spacer()
                } else if vm.report == nil, let message = vm.errorMessage {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.sMutedFG)
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.sMutedFG)
                            .multilineTextAlignment(.center)
                        Button("Try again") { Task { await vm.load() } }
                            .buttonStyle(.borderedProminent)
                            .tint(.sAccent)
                    }
                    .padding(.horizontal, AppSpacing.page)
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
        .safeAreaInset(edge: .top) {
            if let message = vm.errorMessage, vm.report != nil {
                ReportStatusView(message: message, hasData: true) { await vm.load() }
                    .background(Color.sBackground)
            } else if vm.isLoading && vm.report != nil {
                ProgressView("Refreshing…").padding(8)
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
                .disabled(!vm.canExport || vm.report?.summary.invoice_count == 0)
            }
        }
        .task(id: SessionManager.shared.selectedCompanyId) { await vm.load() }
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.sForeground)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous month")
            Spacer()
            Text(vm.monthLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.sForeground)
            Spacer()
            Button { vm.goToNextMonth() } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.sForeground)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Next month")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Summary Card
    private func summaryCard(_ report: GSTReportResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Taxable value")
                    .font(.subheadline)
                    .foregroundColor(.sMutedFG)
                Text(Money.text(report.summary.taxable_value)).moneyLine()
                    .font(.title2.weight(.bold))
                    .foregroundColor(.sForeground)
                Text("\(report.summary.invoice_count) invoice\(report.summary.invoice_count == 1 ? "" : "s") · \(report.company_state.isEmpty ? "State not set" : report.company_state)")
                    .font(.footnote)
                    .foregroundColor(.sMutedFG)
            }

            Rectangle().fill(Color.sBorder).frame(height: 0.5)

            AdaptiveStatRow(stats: [
                .init(label: "CGST", value: Money.text(report.summary.cgst)),
                .init(label: "SGST", value: Money.text(report.summary.sgst)),
                .init(label: "IGST", value: Money.text(report.summary.igst)),
                .init(label: "Total", value: Money.text(report.summary.total), color: .sAccent),
            ])
        }
        .padding(AppSpacing.card)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(16)
        .padding(.horizontal, AppSpacing.page)
    }


    // MARK: - HSN Summary
    private func hsnSection(_ report: GSTReportResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HSN summary")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.sMutedFG)
                .padding(.horizontal, AppSpacing.page)

            VStack(spacing: 0) {
                ForEach(Array(report.hsn_summary.enumerated()), id: \.element.id) { idx, row in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.hsn_code.isEmpty ? "No HSN" : row.hsn_code)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.sForeground)
                            Text("\(String(format: "%.0f", row.total_qty)) units · \(String(format: "%.0f", row.tax_rate))% GST")
                                .font(.caption)
                                .foregroundColor(.sMutedFG)
                        }
                        Spacer()
                        Text(Money.text(row.total_value)).moneyLine()
                            .font(.subheadline.weight(.semibold))
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
            .padding(.horizontal, AppSpacing.page)
        }
    }

    // MARK: - Invoice-wise
    private func invoiceSection(_ report: GSTReportResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Invoice-wise")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.sMutedFG)
                .padding(.horizontal, AppSpacing.page)

            VStack(spacing: 0) {
                ForEach(Array(report.invoices.enumerated()), id: \.element.id) { idx, row in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.invoice_number)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.sForeground)
                            Text(row.client_name)
                                .font(.caption)
                                .foregroundColor(.sMutedFG)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Money.text(row.total)).moneyLine()
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.sForeground)
                            Text(row.igst > 0 ? "IGST" : "CGST+SGST")
                                .font(.caption)
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
            .padding(.horizontal, AppSpacing.page)
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.sMutedFG)
            Text("No GST activity in \(vm.monthLabel)")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.sForeground)
            Text("Issued invoices for this month will show up here")
                .font(.subheadline)
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
