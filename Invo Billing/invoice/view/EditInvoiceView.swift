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
            Color.white.ignoresSafeArea()
            
            if vm.isLoadingInvoice {
                // Loading State
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.black)
                    Text("Loading invoice...")
                        .font(.system(size: 13, weight: .light, design: .default))
                        .foregroundColor(.gray)
                }
            } else if !vm.canEdit && !vm.invoiceStatus.isEmpty {
                // Non-editable state for non-draft invoices
                VStack(spacing: 20) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundColor(.black.opacity(0.3))
                    
                    VStack(spacing: 8) {
                        Text("Invoice Cannot Be Edited")
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundColor(.black)
                        
                        Text("Only draft invoices can be edited.\nThis invoice status is: \(vm.invoiceStatus.uppercased())")
                            .font(.system(size: 13, weight: .light, design: .default))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: { dismiss() }) {
                        Text("GO BACK")
                            .font(.system(size: 12, weight: .semibold, design: .default))
                            .tracking(0.5)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(Color.black)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
            } else {
                VStack(spacing: 0) {
                    
                    // MARK: - Header
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 14, weight: .light, design: .default))
                            }
                            .foregroundColor(.black)
                        }
                        
                        Spacer()
                        
                        Text("EDIT INVOICE")
                            .font(.system(size: 12, weight: .semibold, design: .default))
                            .tracking(0.5)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .frame(height: 1)
                        .background(Color.black.opacity(0.08))
                    
                    // Invoice Number Badge (Read-only)
                    HStack {
                        Text("Invoice: \(vm.invoiceNumber)")
                            .font(.system(size: 11, weight: .semibold, design: .default))
                            .tracking(0.3)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black)
                        
                        Spacer()
                        
                        Text("DRAFT")
                            .font(.system(size: 10, weight: .semibold, design: .default))
                            .tracking(0.5)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.orange, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.02))
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            
                            ClientSection(
                                selectedClient: vm.selectedClient,
                                onTap: { showClientPicker = true }
                            )
                            .onChange(of: vm.selectedClient) { client in
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
                            
                            // Action Buttons
                            VStack(spacing: 12) {
                                Button(action: {
                                    Task {
                                        let success = await vm.updateInvoice()
                                        if success {
                                            dismiss()
                                        }
                                    }
                                }) {
                                    HStack {
                                        if vm.isLoading {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 12, weight: .semibold))
                                            Text("SAVE CHANGES")
                                                .font(.system(size: 12, weight: .semibold, design: .default))
                                                .tracking(0.5)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.black)
                                    .foregroundColor(.white)
                                }
                                .disabled(vm.isLoading || !vm.isValid)
                                
                                Button(action: { dismiss() }) {
                                    Text("CANCEL")
                                        .font(.system(size: 12, weight: .semibold, design: .default))
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
                            
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
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
        .task {
            await vm.loadInvoice(invoiceID: invoiceID)
        }
        .alert("ERROR", isPresented: $vm.showAlert, presenting: vm.errorMessage) { _ in
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


