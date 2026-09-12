import SwiftUI

struct EditEstimateView: View {
    let estimateID: Int
    @StateObject private var vm = EstimateViewModel()
    @Environment(\.dismiss) var dismiss

    @State private var showClientPicker = false
    @State private var showItemPicker = false
    @State private var editingItem: InvoiceLineItem?

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            if vm.isFetchingDetail && vm.editingEstimateID == nil {
                ProgressView().tint(.sAccent)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {

                        // MARK: - Customer
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Customer")
                                .font(.scaled(13, weight: .medium))
                                .foregroundColor(.sMutedFG)

                            Button { showClientPicker = true } label: {
                                HStack(spacing: 12) {
                                    if let client = vm.selectedClient {
                                        MinimalAvatarView(name: client.name)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(client.name)
                                                .font(.scaled(14, weight: .medium))
                                                .foregroundColor(.sForeground)
                                            if !client.email.isEmpty {
                                                Text(client.email)
                                                    .font(.scaled(12))
                                                    .foregroundColor(.sMutedFG)
                                            }
                                        }
                                    } else {
                                        Image(systemName: "person.crop.circle.badge.plus")
                                            .font(.scaled(18))
                                            .foregroundColor(.sAccent)
                                        Text("Select client")
                                            .font(.scaled(14, weight: .medium))
                                            .foregroundColor(.sForeground)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.scaled(12, weight: .semibold))
                                        .foregroundColor(.sMutedFG)
                                }
                                .padding(14)
                            }
                            .background(Color.sCard)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)

                        // MARK: - Dates
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Details")
                                .font(.scaled(13, weight: .medium))
                                .foregroundColor(.sMutedFG)

                            VStack(spacing: 0) {
                                HStack {
                                    Text("Estimate number")
                                        .font(.scaled(14))
                                        .foregroundColor(.sForeground)
                                    Spacer()
                                    Text(vm.estimateNumber)
                                        .font(.scaled(14))
                                        .foregroundColor(.sMutedFG)
                                }
                                .padding(14)

                                Rectangle().fill(Color.sBorder).frame(height: 0.5)

                                DatePicker("Estimate date", selection: $vm.estimateDate, displayedComponents: .date)
                                    .font(.scaled(14))
                                    .padding(14)

                                Rectangle().fill(Color.sBorder).frame(height: 0.5)

                                Toggle("Set expiry date", isOn: $vm.hasExpiryDate)
                                    .font(.scaled(14))
                                    .tint(.sAccent)
                                    .padding(14)

                                if vm.hasExpiryDate {
                                    Rectangle().fill(Color.sBorder).frame(height: 0.5)
                                    DatePicker("Valid until", selection: $vm.expiryDate, in: vm.estimateDate..., displayedComponents: .date)
                                        .font(.scaled(14))
                                        .padding(14)
                                }
                            }
                            .background(Color.sCard)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)

                        ItemsSection(
                            invoiceItems: $vm.items,
                            editingItem: $editingItem,
                            showItemPicker: $showItemPicker,
                            showScanner: $vm.showScanner
                        )

                        SummarySection(
                            subtotal: vm.subtotal,
                            tax: vm.tax,
                            discount: $vm.discount,
                            total: vm.total
                        )
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Rectangle().fill(Color.sBorder).frame(height: 0.5)
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total")
                            .font(.scaled(11))
                            .foregroundColor(.sMutedFG)
                        Text(Money.text(vm.total)).moneyLine()
                            .font(.scaled(17, weight: .semibold))
                            .foregroundColor(.sForeground)
                    }
                    Spacer()
                    Button {
                        Task {
                            if await vm.updateEstimateChanges() { dismiss() }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if vm.isLoading {
                                ProgressView().tint(.sAccentFG).scaleEffect(0.85)
                            } else {
                                Text("Save changes")
                                    .font(.scaled(15, weight: .semibold))
                            }
                        }
                        .foregroundColor(.sAccentFG)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 13)
                        .background(vm.isValid ? Color.sPrimary : Color.sPrimary.opacity(0.4))
                        .cornerRadius(10)
                    }
                    .disabled(vm.isLoading || !vm.isValid)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.sBackground)
            }
        }
        .navigationTitle("Edit estimate")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showClientPicker) {
            ClientPickerView(selectedClient: $vm.selectedClient)
        }
        .sheet(isPresented: $showItemPicker) {
            SelectItemSheet(selectedItems: $vm.items)
        }
        .sheet(isPresented: $vm.showScanner) {
            ItemScannerView(onCancel: { vm.showScanner = false }) { scannedValue in
                vm.handleScannedCode(scannedValue)
            }
        }
        .onAppear {
            Task { await vm.loadEstimateForEdit(estimateID: estimateID) }
        }
        .alert("Error", isPresented: $vm.showAlert, presenting: vm.errorMessage) { _ in
            Button("OK") { vm.showAlert = false }
        } message: { errorMessage in
            Text(errorMessage)
        }
    }
}
