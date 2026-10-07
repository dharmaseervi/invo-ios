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
    @State private var showDiscardConfirm = false

    /// An unfinished invoice found on disk, waiting to be offered back.
    @State private var pendingDraft: InvoiceDraft?
    /// Set once the offer has been answered, so backing out of it does not bring the
    /// same question up again on every redraw.
    @State private var draftOfferSettled = false

    @Environment(\.scenePhase) private var scenePhase

    /// Something has been entered that would be lost. A bare screen closes without a
    /// question; a half-written invoice asks.
    private var hasUnsavedWork: Bool {
        vm.selectedClient != nil || !vm.items.isEmpty || vm.discount > 0
    }

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
                            .font(.scaled(11))
                            .foregroundColor(.sMutedFG)
                        Text(Money.text(vm.total)).moneyLine()
                            .font(.scaled(17, weight: .semibold))
                            .foregroundColor(.sForeground)
                    }
                    Spacer()
                    Button(action: {
                        // Dismiss on success. Without this the form silently blanks and
                        // the screen stays put, which reads as failure — users re-enter
                        // the invoice and submit again, creating a duplicate under a
                        // second invoice number.
                        Task {
                            if await vm.createInvoice() {
                                // The invoice exists now; the draft of it would only
                                // come back later offering to write it a second time.
                                vm.discardDraft()
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
                                Text("Create invoice")
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
        .navigationTitle("New invoice")
        .navigationBarTitleDisplayMode(.inline)
        // Presented as a full-screen cover, so there is no back chevron: without this
        // there is no way out of a half-written invoice.
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                // Asks first when there is something to lose. Cancel threw away a
                // part-written invoice on one tap, with nothing between a mis-tap and
                // losing the lot.
                Button("Cancel") {
                    if hasUnsavedWork { showDiscardConfirm = true } else { dismiss() }
                }
            }
        }
        .alert("Discard this invoice?", isPresented: $showDiscardConfirm) {
            Button("Keep editing", role: .cancel) { }
            Button("Discard", role: .destructive) {
                vm.discardDraft()
                dismiss()
            }
        } message: {
            Text("What you have entered will be lost.")
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

        .onAppear {
            Task {
                await vm.fetchInvoiceNumberPreview()
            }
            // Offered only to a screen that is still empty. Somebody who has started
            // typing is in the middle of something; interrupting them to ask about an
            // older draft would be the app talking over them.
            if !draftOfferSettled, !hasUnsavedWork, let draft = vm.pendingDraft() {
                pendingDraft = draft
            }
        }
        // Written as it is typed. Cheap — one small file, written atomically — and the
        // moment worth surviving is the one nobody sees coming: the app killed on a
        // low-memory phone, with no chance to save anything on the way out.
        .onChange(of: vm.selectedClient) { _ in vm.saveDraft() }
        .onChange(of: vm.items) { _ in vm.saveDraft() }
        .onChange(of: vm.discount) { _ in vm.saveDraft() }
        .onChange(of: vm.invoiceDate) { _ in vm.saveDraft() }
        .onChange(of: vm.dueDate) { _ in vm.saveDraft() }
        .onChange(of: scenePhase) { phase in
            if phase != .active { vm.saveDraft() }
        }
        .modifier(UnfinishedInvoicePrompt(vm: vm, draft: $pendingDraft, settled: $draftOfferSettled))

        .alert("Error", isPresented: $vm.showAlert, presenting: vm.errorMessage)
        { _ in
            Button("OK") { vm.showAlert = false }
        } message: { errorMessage in
            Text(errorMessage)
        }
    }
}

/// The offer to pick up a half-written invoice.
///
/// Its own modifier because the form's modifier chain had grown past what the type
/// checker would take in one piece.
private struct UnfinishedInvoicePrompt: ViewModifier {
    @ObservedObject var vm: InvoiceViewModel
    @Binding var draft: InvoiceDraft?
    @Binding var settled: Bool

    private var isShowing: Binding<Bool> {
        Binding(
            get: { draft != nil },
            set: { if !$0 { draft = nil } }
        )
    }

    func body(content: Content) -> some View {
        content.alert("Unfinished invoice", isPresented: isShowing, presenting: draft) { pending in
            Button("Carry on with it") {
                vm.restore(pending)
                settled = true
                draft = nil
            }
            Button("Start fresh", role: .destructive) {
                vm.discardDraft()
                settled = true
                draft = nil
            }
        } message: { pending in
            // What is in it and how old, so the choice can be made without opening it.
            Text("You started one \(pending.age) — \(pending.summary).")
        }
    }
}
