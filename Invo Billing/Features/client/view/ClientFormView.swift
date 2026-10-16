// ClientFormView.swift
// Invo Billing

import SwiftUI

struct ClientFormView: View {
    @StateObject var vm = ClientViewModel()
    @Environment(\.dismiss) var dismiss
    @FocusState private var focusedField: FormField?
    @State private var attemptedSave = false
    @State private var confirmDiscard = false
    private var isDirty: Bool {
        !vm.name.isEmpty || !vm.email.isEmpty || !vm.phone.isEmpty || !vm.address.isEmpty || !vm.city.isEmpty || !vm.pincode.isEmpty || vm.state != IndianStates.defaultState
    }

    enum FormField {
        case name, email, phone, address, city, state, pincode
    }

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {

                    // MARK: - Contact Information Section
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Contact information")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.sMutedFG)

                        VStack(spacing: 12) {
                            ClientField(
                                label: "Full name (required)",
                                placeholder: "Client name",
                                text: $vm.name,
                                error: attemptedSave && vm.name.trimmingCharacters(in: .whitespaces).isEmpty ? "Enter the client name." : nil
                            )
                            .focused($focusedField, equals: .name)

                            ClientField(
                                label: "Email",
                                placeholder: "name@company.com",
                                text: $vm.email,
                                keyboard: .emailAddress
                            )
                            .focused($focusedField, equals: .email)

                            ClientField(
                                label: "Phone",
                                placeholder: "Phone number",
                                text: $vm.phone,
                                keyboard: .phonePad
                            )
                            .focused($focusedField, equals: .phone)
                        }
                    }

                    // MARK: - Address Section
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Address")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.sMutedFG)

                        VStack(spacing: 12) {
                            ClientField(
                                label: "Street address",
                                placeholder: "Street address",
                                text: $vm.address
                            )
                            .focused($focusedField, equals: .address)

                            AdaptiveFormRow {
                                ClientField(
                                    label: "City",
                                    placeholder: "City",
                                    text: $vm.city
                                )
                                .focused($focusedField, equals: .city)

                                IndianStatePicker(label: "State", text: $vm.state)
                            }

                            ClientField(
                                label: "Pincode",
                                placeholder: "Pincode",
                                text: $vm.pincode,
                                keyboard: .numberPad
                            )
                            .focused($focusedField, equals: .pincode)
                        }
                    }

                    // MARK: - Action Buttons
                    VStack(spacing: 10) {
                        Button {
                            attemptedSave = true
                            focusedField = nil
                            Task {
                                let success = await vm.createNewClient()
                                if success {
                                    vm.resetForm()
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                if vm.isLoading {
                                    ProgressView()
                                        .tint(.sAccentFG)
                                        .scaleEffect(0.85)
                                } else {
                                    Text("Save client")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.sAccentFG)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(vm.name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.sPrimary.opacity(0.4) : Color.sPrimary)
                            .cornerRadius(10)
                        }
                        .disabled(vm.isLoading)

                    }
                    .padding(.top, 4)
                }
                .padding(AppSpacing.card)
            }
        }
        .navigationTitle("New client")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isDirty)
        .protectUnsavedChanges(isDirty: isDirty, confirmDiscard: $confirmDiscard) { dismiss() }
        .toolbar {
            if isDirty {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { confirmDiscard = true }.disabled(vm.isLoading) }
            }
        }
        .alert(
            "Error",
            isPresented: $vm.showAlert,
            actions: {
                Button("OK", role: .cancel) { }
            },
            message: { Text(vm.errorMessage ?? "Unknown error") }
        )
    }
}

// MARK: - Client Field
struct ClientField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.sForeground)
                if error != nil {
                    Image(systemName: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundColor(.sDestructive)
                }
            }

            TextField(label, text: $text, prompt: Text(placeholder))
                .accessibilityLabel(label)
                .keyboardType(keyboard)
                .font(.body)
                .foregroundColor(.sForeground)
                .tint(.sAccent)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.sCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(error != nil ? Color.sDestructive.opacity(0.5) : Color.sInput, lineWidth: 0.5)
                )
                .cornerRadius(8)

            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.sDestructive)
            }
        }
    }
}
