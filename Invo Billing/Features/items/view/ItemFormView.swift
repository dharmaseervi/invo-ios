import Combine
import SwiftUI

struct ItemFormView: View {
    var existingItem: ItemResponse? = nil

    @StateObject var vm = ItemViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showRestockSheet = false
    @State private var initialFields: [String]?
    @State private var confirmDiscard = false
    private var fields: [String] {
        [vm.name, vm.sku, vm.description, vm.costPrice, vm.price, vm.quantity,
         vm.lowStockAlert, vm.taxRate, vm.unit ?? "", vm.hsnCode, vm.barcode,
         vm.selectedCategoryId.map(String.init) ?? ""]
    }
    private var isDirty: Bool { initialFields.map { $0 != fields } ?? false }

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Scrollable Content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ItemDetailsSection(vm: vm)
                        PricingStockSection(vm: vm)

                        if vm.isEditMode {
                            Button {
                                showRestockSheet = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "shippingbox.fill")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Record stock received")
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundColor(.sAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.sAccentMuted)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.sAccent.opacity(0.25), lineWidth: 0.5)
                                )
                                .cornerRadius(10)
                            }
                            .padding(.horizontal, AppSpacing.page)
                            .padding(.top, 16)
                        }
                    }
                    .padding(.bottom, 20)
                }

                // MARK: - Fixed Bottom Buttons
                VStack(spacing: 10) {
                    Button(action: {
                        Task {
                            let success = vm.isEditMode
                                ? await vm.updateItem()
                                : await vm.createItem()
                            if success {
                                if !vm.isEditMode { vm.resetForm() }
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
                                    .font(.subheadline.weight(.semibold))
                                Text(vm.isEditMode ? "Save changes" : "Create item")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        .foregroundColor(.sAccentFG)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(vm.isValid ? Color.sPrimary : Color.sPrimary.opacity(0.4))
                        .cornerRadius(10)
                    }
                    .disabled(vm.isLoading || !vm.isValid)

                }
                .padding(.horizontal, AppSpacing.page)
                .padding(.top, 14)
                .padding(.bottom, 40)
                .background(Color.sBackground)
            }
        }
        .navigationTitle(vm.isEditMode ? "Edit item" : "New item")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isDirty)
        .protectUnsavedChanges(isDirty: isDirty, confirmDiscard: $confirmDiscard) { dismiss() }
        .toolbar {
            if isDirty {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { confirmDiscard = true }.disabled(vm.isLoading) }
            }
        }
        .task {
            guard initialFields == nil else { return }
            if let existingItem { vm.loadForEdit(existingItem) }
            initialFields = fields
        }
        .sheet(isPresented: $showRestockSheet) {
            RestockSheet(vm: vm)
                .presentationDetents([.medium, .large])
        }
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Unknown error")
        }
    }
}

// MARK: - Restock Sheet
private struct RestockSheet: View {
    @ObservedObject var vm: ItemViewModel
    @Environment(\.dismiss) var dismiss

    @State private var quantityReceived = ""
    @State private var reference = ""
    @State private var note = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Stock received") {
                    TextField("Quantity", text: $quantityReceived)
                        .keyboardType(.numberPad)
                    TextField("Supplier / reference (optional)", text: $reference)
                    TextField("Note (optional)", text: $note)
                }
            }
            .navigationTitle("Record stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isSaving = true
                            let qty = Int(quantityReceived) ?? 0
                            if qty > 0 {
                                let success = await vm.restock(
                                    quantityReceived: qty,
                                    reference: reference,
                                    note: note
                                )
                                if success { dismiss() }
                            }
                            isSaving = false
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving || (Int(quantityReceived) ?? 0) <= 0)
                }
            }
        }
    }
}
