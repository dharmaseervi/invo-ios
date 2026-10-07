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
    @State private var address: String
    @State private var pincode: String
    @State private var notes: String

    init(supplier: Supplier, vm: PurchasesViewModel) {
        self.supplier = supplier
        self.vm = vm
        _name  = State(initialValue: supplier.name)
        _phone = State(initialValue: supplier.phone)
        _gstin = State(initialValue: supplier.gstin)
        _city  = State(initialValue: supplier.city)
        _state = State(initialValue: supplier.state)
        _notes = State(initialValue: supplier.notes ?? "")
        _address = State(initialValue: supplier.address ?? "")
        _pincode = State(initialValue: supplier.pincode ?? "")
    }

    private var hasChanges: Bool {
        name.trimmingCharacters(in: .whitespaces) != supplier.name ||
        phone != supplier.phone ||
        gstin != supplier.gstin ||
        city  != supplier.city  ||
        state != supplier.state ||
        notes != (supplier.notes ?? "") ||
        address != (supplier.address ?? "") || pincode != (supplier.pincode ?? "")
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
                TextField("Address", text: $address)
                TextField("Pincode", text: $pincode)
                TextField("City", text: $city)
                TextField("State", text: $state)
            }

            Section("Notes") {
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(3...5)
            }
        }
        .alert("Supplier", isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.errorMessage ?? "Please try again.") }
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
                            address: supplier.address == nil && address.isEmpty ? nil : address,
                            city: city,
                            state: state,
                            pincode: supplier.pincode == nil && pincode.isEmpty ? nil : pincode,
                            notes: supplier.notes == nil && notes.isEmpty ? nil : notes
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
