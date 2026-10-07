//
//  EditSupplierSheet.swift
//  Invo Billing
//
//  Correct a supplier's name, phone, GSTIN, or address.
//

import SwiftUI

struct EditSupplierSheet: View {
    let supplier: Supplier
    @ObservedObject var vm: PurchasesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var phone: String
    @State private var gstin: String
    @State private var city: String
    @State private var state: String
    @State private var notes: String

    init(supplier: Supplier, vm: PurchasesViewModel) {
        self.supplier = supplier
        self.vm = vm
        _name  = State(initialValue: supplier.name)
        _phone = State(initialValue: supplier.phone)
        _gstin = State(initialValue: supplier.gstin)
        _city  = State(initialValue: supplier.city)
        _state = State(initialValue: supplier.state)
        _notes = State(initialValue: "")
    }

    private var hasChanges: Bool {
        name.trimmingCharacters(in: .whitespaces) != supplier.name ||
        phone != supplier.phone ||
        gstin != supplier.gstin ||
        city  != supplier.city  ||
        state != supplier.state ||
        !notes.isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                TextField("Phone", text: $phone)
                    .keyboardType(.phonePad)
            } footer: {
                Text("Name is required.")
            }

            Section {
                TextField("GSTIN", text: $gstin)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                TextField("City", text: $city)
                TextField("State", text: $state)
            }

            Section("Notes") {
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(3...5)
            }
        }
        .navigationTitle("Edit supplier")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task {
                        let req = UpdateSupplierRequest(
                            name: name.trimmingCharacters(in: .whitespaces),
                            phone: phone,
                            email: supplier.email,
                            gstin: gstin,
                            address: "",
                            city: city,
                            state: state,
                            pincode: "",
                            notes: notes
                        )
                        if await vm.updateSupplier(id: supplier.id, request: req) {
                            dismiss()
                        }
                    }
                }
                .disabled(
                    name.trimmingCharacters(in: .whitespaces).isEmpty ||
                    vm.isWorking || !hasChanges
                )
            }
        }
    }
}
