import SwiftUI

struct ChallanDetailView: View {
    let challanID: Int
    @ObservedObject var vm: ChallanViewModel
    @State private var showDispatchConfirm = false

    private var detail: ChallanDetailResponse? { vm.matchingDetail(id: challanID) }

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            Group {
                if vm.isLoadingDetail && detail == nil {
                    VStack(spacing: 12) {
                        ProgressView().tint(.sAccent)
                        Text("Loading...")
                            .font(.subheadline)
                            .foregroundColor(.sMutedFG)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let detail {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            if let message = vm.detailError {
                                ReportStatusView(message: message, hasData: true) { await vm.loadDetail(id: challanID) }
                            }
                            headerCard(detail: detail)
                            itemsCard(detail: detail)
                            if detail.status == .draft {
                                dispatchButton(id: detail.id)
                            }
                        }
                        .padding(.horizontal, AppSpacing.page)
                        .padding(.vertical, 12)
                    }
                    .refreshable { await vm.loadDetail(id: challanID) }
                } else if let message = vm.detailError {
                    ReportStatusView(message: message, hasData: false) { await vm.loadDetail(id: challanID) }
                }
            }
        }
        .navigationTitle("Challan Detail")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Dispatch Challan", isPresented: $showDispatchConfirm) {
            Button("Dispatch", role: .destructive) {
                Task { await vm.dispatch(id: challanID) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Mark this challan as dispatched? This cannot be undone.")
        }
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .task { await vm.loadDetail(id: challanID) }
    }

    @ViewBuilder
    private func headerCard(detail: ChallanDetailResponse) -> some View {
        let isDispatched = detail.status == .dispatched
        let statusColor: Color = isDispatched ? .sSuccess : .sNeutral

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(detail.challan_number)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.sForeground)
                    Text(detail.client.name)
                        .font(.subheadline)
                        .foregroundColor(.sMutedFG)
                }
                Spacer()
                Text(detail.status.rawValue.capitalized)
                    .font(.caption.weight(.medium))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(statusColor.opacity(0.1)))
            }

            Rectangle().fill(Color.sBorder).frame(height: 0.5)

            rowItem(label: "Date", value: String(detail.challan_date.prefix(10)))
            if let invoiceID = detail.invoice_id {
                rowItem(label: "Invoice", value: "#\(invoiceID)")
            }
            if let notes = detail.notes, !notes.isEmpty {
                rowItem(label: "Notes", value: notes)
            }
        }
        .padding(16)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func itemsCard(detail: ChallanDetailResponse) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Items")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.sMutedFG)
                .padding(.horizontal, AppSpacing.page)
                .padding(.vertical, 12)

            Rectangle().fill(Color.sBorder).frame(height: 0.5)

            ForEach(detail.items) { item in
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.item_name ?? "Item #\(item.item_id)")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.sForeground)
                        if let desc = item.description, !desc.isEmpty {
                            Text(desc)
                                .font(.caption)
                                .foregroundColor(.sMutedFG)
                        }
                    }
                    Spacer()
                    Text("Qty: \(item.qty)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.sForeground)
                }
                .padding(.horizontal, AppSpacing.page)
                .padding(.vertical, 12)
                Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, AppSpacing.page)
            }
        }
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func dispatchButton(id: Int) -> some View {
        Button(action: { showDispatchConfirm = true }) {
            HStack {
                Spacer()
                if vm.isLoading {
                    ProgressView().tint(.sAccentFG)
                } else {
                    Label("Mark as Dispatched", systemImage: "shippingbox.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.sAccentFG)
                }
                Spacer()
            }
            .padding(.vertical, 14)
            .background(Color.sPrimary)
            .cornerRadius(10)
        }
        .disabled(!vm.canDispatch(id: id))
    }

    private func rowItem(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.footnote)
                .foregroundColor(.sMutedFG)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundColor(.sForeground)
        }
    }
}
