//
//  InvoiceAddressFormView.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/21/25.
//

import SwiftUI

struct InvoiceAddressFormView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Binding var address: AddressFormModel

    @State private var draft: AddressFormModel

    @FocusState private var focusedField: AddressField?
    @State private var showValidation = false

    private var isLine1Valid: Bool {
        !draft.line1.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init(address: Binding<AddressFormModel>) {
        self._address = address
        self._draft = State(initialValue: address.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sBackground.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {

                        // ADDRESS SECTION
                        section(
                            title: "ADDRESS INFORMATION",
                            icon: "location.fill",
                            content: {
                                addressField(
                                    "Name",
                                    text: $draft.name,
                                    icon: "person.fill",
                                    field: .name,
                                    placeholder: "Business or person name"
                                )
                                
                                addressField(
                                    "Address Line 1",
                                    text: $draft.line1,
                                    icon: "house.fill",
                                    field: .line1,
                                    placeholder: "Street address",
                                    isRequired: true,
                                    errorMessage: (showValidation && !isLine1Valid) ? "Address line 1 is required" : nil
                                )

                                addressField(
                                    "Address Line 2",
                                    text: $draft.line2,
                                    icon: "door.left.hand.open",
                                    field: .line2,
                                    placeholder: "Apartment, suite, etc. (optional)"
                                )
                                
                                HStack(spacing: 12) {
                                    VStack(spacing: 8) {
                                        Label("City", systemImage: "building.2.fill")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.sMutedFG)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        TextField("City", text: $draft.city)
                                            .font(.system(size: 14, weight: .regular))
                                            .focused($focusedField, equals: .city)
                                            .textFieldStyle(.plain)
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 0)
                                            .overlay(
                                                Rectangle()
                                                    .frame(height: 1)
                                                    .foregroundColor(
                                                        focusedField == .city ? Color.sAccent : Color.sBorder
                                                    ),
                                                alignment: .bottom
                                            )
                                            .animation(.easeInOut(duration: 0.2), value: focusedField)
                                    }
                                    
                                    VStack(spacing: 8) {
                                        Label("State", systemImage: "map.fill")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.sMutedFG)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        Menu {
                                            ForEach(IndianStates.all, id: \.self) { state in
                                                Button {
                                                    draft.state = state
                                                } label: {
                                                    if draft.state == state {
                                                        Label(state, systemImage: "checkmark")
                                                    } else {
                                                        Text(state)
                                                    }
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Text(draft.state.isEmpty ? "Select state" : draft.state)
                                                    .font(.system(size: 14, weight: .regular))
                                                    .foregroundColor(draft.state.isEmpty ? .sMutedFG : .sForeground)
                                                Spacer()
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundColor(.sMutedFG)
                                            }
                                        }
                                        .padding(.vertical, 10)
                                        .overlay(
                                            Rectangle()
                                                .frame(height: 1)
                                                .foregroundColor(Color.sBorder),
                                            alignment: .bottom
                                        )
                                    }
                                }
                                
                                HStack(spacing: 12) {
                                    VStack(spacing: 8) {
                                        Label("Postal Code", systemImage: "mailbox.fill")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.sMutedFG)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        TextField("Postal Code", text: $draft.postalCode)
                                            .font(.system(size: 14, weight: .regular))
                                            .focused($focusedField, equals: .postalCode)
                                            .textFieldStyle(.plain)
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 0)
                                            .overlay(
                                                Rectangle()
                                                    .frame(height: 1)
                                                    .foregroundColor(
                                                        focusedField == .postalCode ? Color.sAccent : Color.sBorder
                                                    ),
                                                alignment: .bottom
                                            )
                                            .animation(.easeInOut(duration: 0.2), value: focusedField)
                                    }
                                    
                                    VStack(spacing: 8) {
                                        Label("Country", systemImage: "globe")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.sMutedFG)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        TextField("Country", text: $draft.country)
                                            .font(.system(size: 14, weight: .regular))
                                            .focused($focusedField, equals: .country)
                                            .textFieldStyle(.plain)
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 0)
                                            .overlay(
                                                Rectangle()
                                                    .frame(height: 1)
                                                    .foregroundColor(
                                                        focusedField == .country ? Color.sAccent : Color.sBorder
                                                    ),
                                                alignment: .bottom
                                            )
                                            .animation(.easeInOut(duration: 0.2), value: focusedField)
                                    }
                                }
                            }
                        )
                        
                        // CONTACT & TAX SECTION
                        section(
                            title: "CONTACT & TAX",
                            icon: "phone.fill",
                            content: {
                                addressField(
                                    "Phone",
                                    text: $draft.phone,
                                    icon: "phone.fill",
                                    field: .phone,
                                    placeholder: "+91 XXXXX XXXXX"
                                )
                                
                                addressField(
                                    "Email",
                                    text: $draft.email,
                                    icon: "envelope.fill",
                                    field: .email,
                                    placeholder: "name@company.com"
                                )
                                
                                addressField(
                                    "GST Number",
                                    text: $draft.gstNumber,
                                    icon: "doc.text.fill",
                                    field: .gstNumber,
                                    placeholder: "27AABCT5055K1Z0"
                                )
                            }
                        )
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            Button(action: {
                                showValidation = true
                                guard isLine1Valid else { return }
                                address = draft
                                dismiss()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Save address")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.sPrimary)
                                .foregroundColor(.sAccentFG)
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("\(draft.type.capitalized) address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Components
    
    private func section<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.sAccent)

                Text(title.capitalized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.sMutedFG)

                Spacer()
            }

            VStack(spacing: 16) {
                content()
            }
            .padding(16)
            .background(Color.sCard)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.sBorder, lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 20)
    }
    
    private func addressField(
        _ label: String,
        text: Binding<String>,
        icon: String,
        field: AddressField,
        placeholder: String = "",
        isRequired: Bool = false,
        errorMessage: String? = nil
    ) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Label(label, systemImage: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.sMutedFG)

                if isRequired {
                    Circle()
                        .fill(Color.sDestructive)
                        .frame(width: 4, height: 4)
                }

                Spacer()
            }

            TextField(placeholder, text: text)
                .font(.system(size: 14, weight: .regular))
                .focused($focusedField, equals: field)
                .textFieldStyle(.plain)
                .padding(.vertical, 10)
                .padding(.horizontal, 0)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(
                            errorMessage != nil ? Color.sDestructive : (focusedField == field ? Color.sAccent : Color.sBorder)
                        ),
                    alignment: .bottom
                )
                .animation(.easeInOut(duration: 0.2), value: focusedField)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.sDestructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Focus Field Enum
enum AddressField: Hashable {
    case name
    case line1
    case line2
    case city
    case state
    case postalCode
    case country
    case phone
    case email
    case gstNumber
}

