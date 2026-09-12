//
//  CreateInvoiceView.swift
//  invo
//
//  Created by dharmaseervi on 11/25/25.
//

import SwiftUI

struct CreateInvoiceView: View {
    @StateObject private var vm = InvoiceViewModel()

    @Environment(\.dismiss) var dismiss

    @State private var showClientPicker = false
    @State private var showItemPicker = false
    @State private var editingItem: InvoiceLineItem?
    @State private var showBillingSheet = false
    @State private var showShippingSheet = false

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {

                    InvoiceCustomerSection(
                        selectedClient: vm.selectedClient,
                        billingAddress: vm.billingAddress,
                        shippingAddress: vm.shippingAddress,
                        isShippingSameAsBilling: $vm.isShippingSameAsBilling,
                        onSelectClient: { showClientPicker = true },
                        onEditBilling: { showBillingSheet = true },
                        onEditShipping: { showShippingSheet = true }
                    )
                    .padding(.horizontal, 20)
                    .onChange(of: vm.selectedClient) { client in
                        guard client != nil else { return }
                        Task { await vm.loadClientAddresses() }
                    }

                    InvoiceDetailsSection(
                        invoiceNumber: vm.invoiceNumber,
                        invoiceDate: $vm.invoiceDate,
                        dueDate: $vm.dueDate
                    )
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
        .safeAreaInset(edge: .bottom) {
            // Sticky primary action
            VStack(spacing: 0) {
                Rectangle().fill(Color.sBorder).frame(height: 0.5)
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total")
                            .font(.system(size: 11))
                            .foregroundColor(.sMutedFG)
                        Text(Money.text(vm.total))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.sForeground)
                    }
                    Spacer()
                    Button(action: {
                        // Dismiss on success. Without this the form silently blanks and
                        // the screen stays put, which reads as failure — users re-enter
                        // the invoice and submit again, creating a duplicate under a
                        // second invoice number.
                        Task {
                            if await vm.createInvoice() { dismiss() }
                        }
                    }) {
                        HStack(spacing: 8) {
                            if vm.isLoading {
                                ProgressView()
                                    .tint(.sAccentFG)
                                    .scaleEffect(0.85)
                            } else {
                                Text("Create invoice")
                                    .font(.system(size: 15, weight: .semibold))
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
        .navigationTitle("New invoice")
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
        .sheet(isPresented: $showBillingSheet) {
            InvoiceAddressFormView(address: $vm.billingAddress)
        }

        .sheet(isPresented: $showShippingSheet) {
            InvoiceAddressFormView(address: $vm.shippingAddress)
        }

        .onAppear {
            Task {
                await vm.fetchInvoiceNumberPreview()
            }
        }

        .alert("Error", isPresented: $vm.showAlert, presenting: vm.errorMessage)
        { _ in
            Button("OK") { vm.showAlert = false }
        } message: { errorMessage in
            Text(errorMessage)
        }
    }
}
