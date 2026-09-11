//
//  EditInvoiceView.swift
//  Invo Billing
//
//  Created by dharmaseervi on 2/1/26.
//


//
//  EditInvoiceView.swift
//  invo
//
//  Edit invoice view - only for draft invoices
//

import SwiftUI

struct EditInvoiceView: View {
    let invoiceID: Int
    
    @StateObject private var vm = EditInvoiceViewModel()
    @Environment(\.dismiss) var dismiss
    
    @State private var showClientPicker = false
    @State private var showItemPicker = false
    @State private var editingItem: InvoiceLineItem?
    @State private var showBillingSheet = false
    @State private var showShippingSheet = false
    
    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            if vm.isLoadingInvoice {
                // Loading State
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.sAccent)
                    Text("Loading invoice...")
                        .font(.system(size: 13))
                        .foregroundColor(.sMutedFG)
                }
            } else if !vm.canEdit && !vm.invoiceStatus.isEmpty {
                // Non-editable state for non-draft invoices
                VStack(spacing: 18) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.sMutedFG)

                    VStack(spacing: 6) {
                        Text("Invoice cannot be edited")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.sForeground)

                        Text("Only draft invoices can be edited.\nThis invoice status is: \(vm.invoiceStatus.uppercased())")
                            .font(.system(size: 13))
                            .foregroundColor(.sMutedFG)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: { dismiss() }) {
                        Text("Go back")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.sAccentFG)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(Color.sPrimary)
                            .cornerRadius(10)
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 24)
            } else {
                VStack(spacing: 0) {


                    // Invoice Number Badge (Read-only)
                    HStack {
                        Text("Invoice: \(vm.invoiceNumber)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.sAccentFG)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.sPrimary)
                            .cornerRadius(6)

                        Spacer()

                        Text("DRAFT")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.5)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.orange, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.sCard)
                    
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
                            .padding(.top, 16)
                            .onChange(of: vm.selectedClient) { client in
                                guard client != nil else { return }
                                Task { await vm.loadClientAddresses() }
                            }

                            InvoiceDetailsSection(
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
                            
                            // Action Buttons
                            VStack(spacing: 10) {
                                Button(action: {
                                    Task {
                                        let success = await vm.updateInvoice()
                                        if success {
                                            dismiss()
                                        }
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        if vm.isLoading {
                                            ProgressView()
                                                .tint(.sAccentFG)
                                                .scaleEffect(0.85)
                                        } else {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 13, weight: .semibold))
                                            Text("Save changes")
                                                .font(.system(size: 15, weight: .semibold))
                                        }
                                    }
                                    .foregroundColor(.sAccentFG)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(vm.isValid ? Color.sPrimary : Color.sPrimary.opacity(0.4))
                                    .cornerRadius(10)
                                }
                                .disabled(vm.isLoading || !vm.isValid)

                                Button(action: { dismiss() }) {
                                    Text("Cancel")
                                        .font(.system(size: 14, weight: .medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .foregroundColor(.sForeground)
                                        .background(Color.sCard)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.sBorder, lineWidth: 0.5)
                                        )
                                        .cornerRadius(10)
                                }
                                .disabled(vm.isLoading)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 28)
                            
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationTitle("Edit invoice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
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
        .task {
            await vm.loadInvoice(invoiceID: invoiceID)
        }
        .alert("Error", isPresented: $vm.showAlert, presenting: vm.errorMessage) { _ in
            Button("OK") { vm.showAlert = false }
        } message: { errorMessage in
            Text(errorMessage)
        }
        .alert("Success", isPresented: $vm.showSuccessAlert) {
            Button("OK") {
                vm.showSuccessAlert = false
                dismiss()
            }
        } message: {
            Text(vm.successMessage)
        }
    }
}


