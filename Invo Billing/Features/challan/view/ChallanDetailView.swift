import SwiftUI

struct ChallanDetailView: View {
    let challanID: Int
    @ObservedObject var vm: ChallanViewModel
    @State private var showDispatchConfirm = false

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            Group {
                if vm.isLoading && vm.challanDetail == nil {
                    VStack(spacing: 12) {
                        ProgressView().tint(.sAccent)
                        Text("Loading...")
                            .font(.scaled(13))
                            .foregroundColor(.sMutedFG)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let detail = vm.challanDetail {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            headerCard(detail: detail)
                            itemsCard(detail: detail)
                            if detail.status == .draft {
                                dispatchButton(id: detail.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
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
        let statusColor: Color = isDispatched ? Color(red: 0.086, green: 0.639, blue: 0.341) : Color(UIColor.systemGray)

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(detail.challan_number)
                        .font(.scaled(17, weight: .bold))
                        .foregroundColor(.sForeground)
                    Text(detail.client_name ?? "Client #\(detail.client_id)")
                        .font(.scaled(13))
                        .foregroundColor(.sMutedFG)
                }
                Spacer()
                Text(detail.status.rawValue.capitalized)
                    .font(.scaled(11, weight: .medium))
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
                .font(.scaled(13, weight: .medium))
                .foregroundColor(.sMutedFG)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Rectangle().fill(Color.sBorder).frame(height: 0.5)

            ForEach(detail.items) { item in
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.item_name ?? "Item #\(item.item_id)")
                            .font(.scaled(13, weight: .medium))
                            .foregroundColor(.sForeground)
                        if let desc = item.description, !desc.isEmpty {
                            Text(desc)
                                .font(.scaled(11))
                                .foregroundColor(.sMutedFG)
                        }
                    }
                    Spacer()
                    Text("Qty: \(item.qty)")
                        .font(.scaled(13, weight: .semibold))
                        .foregroundColor(.sForeground)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 16)
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
                        .font(.scaled(14, weight: .semibold))
                        .foregroundColor(.sAccentFG)
                }
                Spacer()
            }
            .padding(.vertical, 14)
            .background(Color.sPrimary)
            .cornerRadius(10)
        }
        .disabled(vm.isLoading)
    }

    private func rowItem(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.scaled(12))
                .foregroundColor(.sMutedFG)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.scaled(13))
                .foregroundColor(.sForeground)
        }
    }
}
