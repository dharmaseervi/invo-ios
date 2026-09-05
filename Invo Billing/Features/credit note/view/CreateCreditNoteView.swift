//
//  CreateCreditNoteView.swift
//  Invo Billing
//
//  Created by dharmaseervi on 1/12/26.
//

import SwiftUI

struct CreateCreditNoteView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = CreateCreditNoteViewModel()
    @StateObject private var vmInvoice: InvoiceViewModel = InvoiceViewModel()
    @State private var showClientPicker = false
    @State private var showItemPicker = false
    @State private var showBillingSheet = false
    @State private var showShippingSheet = false
    @State private var editingItem: InvoiceLineItem?

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack {

                        VStack {
                            // Credit Type
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Credit type")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.sMutedFG)

                                Picker("", selection: $vm.creditType) {
                                    ForEach(CreditNoteType.allCases, id: \.self)
                                    {
                                        Text($0.title)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        VStack(alignment: .leading) {
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
                            .padding(.top, 20)
                            .onChange(of: vm.selectedClient) { client in
                                guard client != nil else { return }
                                Task { await vm.loadClientAddresses() }
                            }

                            // Credit Date
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Credit date")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.sMutedFG)

                                DatePicker(
                                    "",
                                    selection: $vm.creditDate,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                .tint(.sAccent)
                                .labelsHidden()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 16)


                            if vm.creditType == .returnItems {
                                // ITEM RETURN UI
                                ItemsSection(
                                    invoiceItems: $vm.items,
                                    editingItem: $editingItem,
                                    showItemPicker: $showItemPicker,
                                    showScanner: $vm.showScanner
                                )

                            } else {
                                // VALUE ADJUSTMENT UI
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Credit amount")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.sMutedFG)

                                    TextField("₹0.00", text: $vm.amount)
                                        .keyboardType(.decimalPad)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.sForeground)
                                        .tint(.sAccent)
                                        .multilineTextAlignment(.leading)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 14)
                                        .background(Color.sCard)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.sInput, lineWidth: 0.5)
                                        )
                                        .cornerRadius(8)

                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 16)
                            }

                        }

                    }

                }

                // Save Button
                Button {
                    Task {
                        let success = await vm.submit()
                        if success { dismiss() }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if vm.isLoading {
                            ProgressView()
                                .tint(.sAccentFG)
                                .scaleEffect(0.85)
                        } else {
                            Text("Save credit note")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(vm.isValid ? Color.sPrimary : Color.sPrimary.opacity(0.4))
                    .foregroundColor(.sAccentFG)
                    .cornerRadius(10)
                }
                .disabled(!vm.isValid || vm.isLoading)
                .padding(20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Create credit note")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showClientPicker) {
            ClientPickerView(selectedClient: $vm.selectedClient)
        }
        .sheet(isPresented: $showItemPicker) {
            SelectItemSheet(selectedItems: $vm.items)
        }
        .sheet(isPresented: $showBillingSheet) {
            InvoiceAddressFormView(address: $vm.billingAddress)
        }

        .sheet(isPresented: $showShippingSheet) {
            InvoiceAddressFormView(address: $vm.shippingAddress)
        }
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }
}
