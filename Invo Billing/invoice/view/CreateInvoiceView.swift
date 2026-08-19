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
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: - Header
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(
                                    .system(
                                        size: 14,
                                        weight: .light,
                                        design: .default
                                    )
                                )
                        }
                        .foregroundColor(.black)
                    }

                    Spacer()

                    Text("NEW INVOICE")
                        .font(
                            .system(
                                size: 12,
                                weight: .semibold,
                                design: .default
                            )
                        )
                        .tracking(0.5)
                        .foregroundColor(.gray)

                    Spacer()

                    Image(systemName: "doc.text")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                Divider()
                    .frame(height: 1)
                    .background(Color.black.opacity(0.08))

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {

                        ClientSection(
                            selectedClient: vm.selectedClient,
                            onTap: { showClientPicker = true }
                            
                        ).onChange(of: vm.selectedClient) { client in
                            guard client != nil else { return }
                            Task {
                                await vm.loadClientAddresses()
                            }
                        }

                        
                        InvoiceAddressSection(
                            title: "Billing Address",
                            address: vm.billingAddress
                        ) {
                            showBillingSheet = true
                        }

                        Toggle(isOn: $vm.isShippingSameAsBilling) {
                            Text("Shipping address same as billing")
                                .font(.system(size: 13))
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)

                        if !vm.isShippingSameAsBilling {
                            InvoiceAddressSection(
                                title: "Shipping Address",
                                address: vm.shippingAddress
                            ) {
                                showShippingSheet = true
                            }
                        }

                        InvoiceNumberSection(
                            invoiceNumber: vm.invoiceNumber
                        )

                        InvoiceDetailsSection(
                            invoiceDate: $vm.invoiceDate,
                            dueDate: $vm.dueDate
                        )

                        ItemsSection(
                            invoiceItems: $vm.items,
                            editingItem: $editingItem,
                            showItemPicker: $showItemPicker,
                            showScanner: $vm.showScanner
                        )

                        SummarySection(
                            subtotal: vm.subtotal,
                            tax: vm.tax,
                            total: vm.total
                        )

                        VStack(spacing: 12) {
                            Button(action: {
                                Task {
                                    await vm.createInvoice()
                                }
                            }) {
                                HStack {
                                    if vm.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(
                                            systemName: "checkmark.circle.fill"
                                        )
                                        .font(
                                            .system(size: 12, weight: .semibold)
                                        )
                                        Text("CREATE INVOICE")
                                            .font(
                                                .system(
                                                    size: 12,
                                                    weight: .semibold,
                                                    design: .default
                                                )
                                            )
                                            .tracking(0.5)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.black)
                                .foregroundColor(.white)
                            }
                            .disabled(vm.isLoading || !vm.isValid)

                            Button(action: {
                                dismiss()
                            }) {
                                Text("CANCEL")
                                    .font(
                                        .system(
                                            size: 12,
                                            weight: .semibold,
                                            design: .default
                                        )
                                    )
                                    .tracking(0.5)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundColor(.black)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 0)
                                            .stroke(Color.black, lineWidth: 1)
                                    )
                            }
                            .disabled(vm.isLoading)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 32)

                    }.padding(.bottom , 40)
                }
            }

            // MARK: - Floating Create Button

        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showClientPicker) {
            ClientPickerView(selectedClient: $vm.selectedClient)
        }
        .sheet(isPresented: $showItemPicker) {
            SelectItemSheet(selectedItems: $vm.items)
        }
        .sheet(isPresented: $vm.showScanner) {
            ItemScannerView { scannedValue in
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

        .alert("ERROR", isPresented: $vm.showAlert, presenting: vm.errorMessage)
        { _ in
            Button("OK") { vm.showAlert = false }
        } message: { errorMessage in
            Text(errorMessage)
        }
    }
}
