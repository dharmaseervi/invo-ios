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
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {

                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                    }

                    Spacer()

                    Text("CREATE CREDIT NOTE")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1)

                    Spacer()
                }
                .padding(24)

                Divider()

                ScrollView {
                    VStack {

                        VStack {
                            // Credit Type
                            VStack(alignment: .leading, spacing: 8) {
                                Text("CREDIT TYPE")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)

                                Picker("", selection: $vm.creditType) {
                                    ForEach(CreditNoteType.allCases, id: \.self)
                                    {
                                        Text($0.title)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)

                        VStack(alignment: .leading) {
                            ClientSection(
                                selectedClient: vm.selectedClient,
                                onTap: { showClientPicker = true }

                            ).onChange(of: vm.selectedClient) {
                                oldValue,
                                newValue in
                                guard newValue != nil else { return }
                                Task {
                                    await vm.loadClientAddresses()
                                }
                            }
                            
                            // Credit Date
                            VStack(alignment: .leading, spacing: 8) {
                                Text("CREDIT DATE")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                                
                                DatePicker(
                                    "",
                                    selection: $vm.creditDate,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 12)


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

                            if !vm.isShippingSameAsBilling {
                                InvoiceAddressSection(
                                    title: "Shipping Address",
                                    address: vm.shippingAddress
                                ) {
                                    showShippingSheet = true
                                }
                            }

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
                                    Text("CREDIT AMOUNT")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)

                                    TextField("₹0.00", text: $vm.amount)
                                        .keyboardType(.decimalPad)
                                        .font(
                                            .system(size: 18, weight: .semibold)
                                        )
                                        .multilineTextAlignment(.leading)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 14)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 0)
                                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                        )

                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 20)
                            }

                        }

                    }

                }

                // Save Button
                Button {
                    Task {
                        await vm.submit()
                        dismiss()
                    }
                } label: {
                    HStack {
                        if vm.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("SAVE CREDIT NOTE")
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(0.5)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(vm.isValid ? Color.black : Color.gray)
                    .foregroundColor(.white)
                }
                .disabled(!vm.isValid || vm.isLoading)
                .padding(24)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
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
