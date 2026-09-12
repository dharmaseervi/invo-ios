import SwiftUI

struct EstimateDetailView: View {
    let estimateID: Int
    @ObservedObject var vm: EstimateViewModel
    @State private var showConvertConfirm = false
    @State private var navigateToInvoice = false
    @State private var showEditEstimate = false

    private func statusConfig(_ status: EstimateStatus) -> (label: String, color: Color) {
        switch status {
        case .draft:     return ("Draft", Color(UIColor.systemGray))
        case .sent:      return ("Sent", .sAccent)
        case .accepted:  return ("Accepted", Color(red: 0.086, green: 0.639, blue: 0.341))
        case .rejected:  return ("Rejected", Color(red: 0.863, green: 0.149, blue: 0.149))
        case .expired:   return ("Expired", Color(red: 0.722, green: 0.494, blue: 0.051))
        case .converted: return ("Converted", Color(red: 0.086, green: 0.639, blue: 0.341))
        }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            if vm.isFetchingDetail {
                ProgressView().tint(.sAccent)
            } else if let detail = vm.estimateDetail {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {

                        // MARK: - Header Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(Color.sAccentMuted).frame(width: 48, height: 48)
                                    Text(initials(for: detail.client.name))
                                        .font(.scaled(15, weight: .semibold))
                                        .foregroundColor(.sAccent)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(detail.client.name)
                                        .font(.scaled(16, weight: .semibold))
                                        .foregroundColor(.sForeground)
                                    Text(detail.estimate_number)
                                        .font(.scaled(13))
                                        .foregroundColor(.sMutedFG)
                                }
                                Spacer()
                                let config = statusConfig(detail.status)
                                Text(config.label)
                                    .font(.scaled(11, weight: .medium))
                                    .foregroundColor(config.color)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(config.color.opacity(0.1)))
                            }

                            Rectangle().fill(Color.sBorder).frame(height: 0.5)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Total amount")
                                    .font(.scaled(11))
                                    .foregroundColor(.sMutedFG)
                                Text(Money.text(detail.total))
                                    .font(.scaled(22, weight: .bold))
                                    .foregroundColor(.sForeground)
                            }

                            if let expiry = detail.expiry_date {
                                Text("Valid until \(expiry)")
                                    .font(.scaled(12))
                                    .foregroundColor(.sMutedFG)
                            }
                        }
                        .padding(18)
                        .background(Color.sCard)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sBorder, lineWidth: 0.5))
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        // MARK: - Actions
                        actionButtons(detail).padding(.horizontal, 20).padding(.top, 16)

                        // MARK: - Line Items
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Line items")
                                .font(.scaled(13, weight: .medium))
                                .foregroundColor(.sMutedFG)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 10)
                                .padding(.top, 20)

                            VStack(spacing: 10) {
                                ForEach(detail.items) { item in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(vm.itemNames[item.item_id] ?? "Item #\(item.item_id)")
                                                .font(.scaled(13, weight: .semibold))
                                                .foregroundColor(.sForeground)
                                            Text("Qty: \(item.qty)")
                                                .font(.scaled(11))
                                                .foregroundColor(.sMutedFG)
                                        }
                                        Spacer()
                                        Text(Money.text(item.total))
                                            .font(.scaled(13, weight: .semibold))
                                            .foregroundColor(.sForeground)
                                    }
                                    .padding(14)
                                    .background(Color.sCard)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                                    .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // MARK: - Summary
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Summary")
                                .font(.scaled(13, weight: .medium))
                                .foregroundColor(.sMutedFG)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 10)
                                .padding(.top, 20)

                            VStack(spacing: 0) {
                                summaryRow("Subtotal", detail.subtotal)
                                Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)
                                summaryRow("Tax", detail.tax)
                                if detail.discount > 0 {
                                    Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)
                                    summaryRow("Discount", -detail.discount)
                                }
                                Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)
                                summaryRow("Total", detail.total, isTotal: true)
                            }
                            .background(Color.sCard)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                            .cornerRadius(10)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
        }
        .navigationTitle("Estimate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let detail = vm.estimateDetail {
                        NavigationLink {
                            EstimatePrintView(estimateDetail: detail)
                        } label: {
                            Label("Print", systemImage: "printer")
                        }
                    }
                    Button {
                        Task { await vm.generateEstimatePDF(estimateID: estimateID) }
                    } label: {
                        Label("Download PDF", systemImage: "arrow.down.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $vm.showPDF) {
            if let url = vm.pdfURL { PDFLookView(pdfURL: url) }
        }
        .sheet(isPresented: $showEditEstimate) {
            NavigationStack {
                EditEstimateView(estimateID: estimateID)
            }
        }
        .onChange(of: showEditEstimate) { isPresented in
            if !isPresented {
                Task { await vm.fetchEstimateDetail(estimateID: estimateID) }
            }
        }
        .onAppear {
            Task { await vm.fetchEstimateDetail(estimateID: estimateID) }
        }
        .confirmationDialog(
            "Convert to invoice?",
            isPresented: $showConvertConfirm,
            titleVisibility: .visible
        ) {
            Button("Convert") {
                Task { await vm.convertToInvoice(estimateID: estimateID) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This creates a new draft invoice with the same client and items.")
        }
        .presentationCompactAdaptation(.sheet)
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Something went wrong")
        }
        .alert(vm.successMessage, isPresented: $vm.showSuccessAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func actionButtons(_ detail: EstimateDetailResponse) -> some View {
        VStack(spacing: 10) {
            switch detail.status {
            case .draft:
                Button {
                    Task { await vm.markAsSent(estimateID: estimateID) }
                } label: {
                    actionLabel("Mark as sent", icon: "paperplane.fill", filled: true)
                }
                Button {
                    showEditEstimate = true
                } label: {
                    actionLabel("Edit estimate", icon: "pencil", filled: false)
                }
            case .sent:
                HStack(spacing: 10) {
                    Button {
                        Task { await vm.markAsAccepted(estimateID: estimateID) }
                    } label: {
                        actionLabel("Accepted", icon: "checkmark", filled: true)
                    }
                    Button {
                        Task { await vm.markAsRejected(estimateID: estimateID) }
                    } label: {
                        actionLabel("Rejected", icon: "xmark", filled: false)
                    }
                }
            case .accepted:
                Button {
                    showConvertConfirm = true
                } label: {
                    actionLabel("Convert to invoice", icon: "doc.text.fill", filled: true)
                }
            case .rejected, .expired:
                EmptyView()
            case .converted:
                if let invoiceID = detail.converted_invoice_id {
                    NavigationLink {
                        InvoiceDetailView(invoiceID: invoiceID, vm: InvoiceViewModel())
                    } label: {
                        actionLabel("View invoice", icon: "arrow.up.right", filled: true)
                    }
                }
            }
        }
    }

    private func actionLabel(_ title: String, icon: String, filled: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.scaled(14, weight: .semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .foregroundColor(filled ? .sAccentFG : .sForeground)
        .background(filled ? Color.sPrimary : Color.sCard)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(filled ? Color.clear : Color.sBorder, lineWidth: 0.5)
        )
        .cornerRadius(10)
    }

    private func summaryRow(_ label: String, _ value: Double, isTotal: Bool = false) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.scaled(isTotal ? 14 : 13, weight: isTotal ? .semibold : .regular))
                .foregroundColor(.sForeground)
            Spacer()
            Text(Money.text(value))
                .font(.scaled(isTotal ? 15 : 13, weight: isTotal ? .semibold : .regular))
                .foregroundColor(.sForeground)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
