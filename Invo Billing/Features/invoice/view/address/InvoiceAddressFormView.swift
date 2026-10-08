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
    @State private var isVerifyingGST = false
    @State private var gstVerifyMessage: String?
    @State private var gstVerifySuccess = false

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
                                            .font(.scaled(12, weight: .semibold))
                                            .foregroundColor(.sMutedFG)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        TextField("City", text: $draft.city)
                                            .font(.scaled(14, weight: .regular))
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
                                            .font(.scaled(12, weight: .semibold))
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
                                                    .font(.scaled(14, weight: .regular))
                                                    .foregroundColor(draft.state.isEmpty ? .sMutedFG : .sForeground)
                                                Spacer()
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.scaled(11, weight: .semibold))
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
                                            .font(.scaled(12, weight: .semibold))
                                            .foregroundColor(.sMutedFG)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        TextField("Postal Code", text: $draft.postalCode)
                                            .font(.scaled(14, weight: .regular))
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
                                            .font(.scaled(12, weight: .semibold))
                                            .foregroundColor(.sMutedFG)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        TextField("Country", text: $draft.country)
                                            .font(.scaled(14, weight: .regular))
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
                                
                                gstField
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
                                        .font(.scaled(14, weight: .semibold))
                                    Text("Save address")
                                        .font(.scaled(15, weight: .semibold))
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
    
    // MARK: - GST field with inline Verify button

    private var gstField: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Label("GST Number", systemImage: "doc.text.fill")
                    .font(.scaled(12, weight: .semibold))
                    .foregroundColor(.sMutedFG)
                Spacer()
                if draft.gstNumber.count == 15 {
                    Button {
                        Task { await verifyGSTIN() }
                    } label: {
                        if isVerifyingGST {
                            ProgressView().scaleEffect(0.7).tint(.sAccent)
                        } else {
                            Text("Verify")
                                .font(.scaled(12, weight: .semibold))
                                .foregroundColor(.sAccent)
                        }
                    }
                    .disabled(isVerifyingGST)
                }
            }

            TextField("27AABCT5055K1Z0", text: $draft.gstNumber)
                .font(.scaled(14, weight: .regular))
                .focused($focusedField, equals: .gstNumber)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.vertical, 10)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(focusedField == .gstNumber ? Color.sAccent : Color.sBorder),
                    alignment: .bottom
                )
                .animation(.easeInOut(duration: 0.2), value: focusedField)
                .onChange(of: draft.gstNumber) { gstin in
                    gstVerifyMessage = nil
                    // Auto-fill state from first 2 digits the moment they are typed.
                    if let stateName = IndianStates.state(fromGSTIN: gstin),
                       IndianStates.all.contains(stateName) {
                        draft.state = stateName
                    }
                }

            if let msg = gstVerifyMessage {
                HStack(spacing: 6) {
                    Image(systemName: gstVerifySuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.scaled(12))
                        .foregroundColor(gstVerifySuccess ? .green : .sDestructive)
                    Text(msg)
                        .font(.scaled(12))
                        .foregroundColor(gstVerifySuccess ? .green : .sDestructive)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @MainActor
    private func verifyGSTIN() async {
        isVerifyingGST = true
        gstVerifyMessage = nil
        defer { isVerifyingGST = false }

        let gstin = draft.gstNumber.uppercased()
        guard let url = URL(string: "\(AppEnvironment.baseURL)/gstin/\(gstin)") else {
            gstVerifyMessage = "Invalid request URL"
            gstVerifySuccess = false
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        if let token = KeychainManager.shared.loadToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

            struct GSTINResponse: Decodable {
                let valid: Bool
                let state: String?
                let message: String?
            }

            if http.statusCode == 200,
               let result = try? JSONDecoder().decode(GSTINResponse.self, from: data) {
                gstVerifySuccess = result.valid
                if result.valid {
                    if let state = result.state, IndianStates.all.contains(state) {
                        draft.state = state
                    }
                    gstVerifyMessage = result.message ?? "Valid GSTIN"
                } else {
                    gstVerifyMessage = result.message ?? "Invalid GSTIN"
                }
            } else {
                gstVerifySuccess = false
                gstVerifyMessage = "Could not verify — check the number"
            }
        } catch {
            gstVerifySuccess = false
            gstVerifyMessage = "Verification failed"
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
                    .font(.scaled(13, weight: .semibold))
                    .foregroundColor(.sAccent)

                Text(title.capitalized)
                    .font(.scaled(13, weight: .medium))
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
                    .font(.scaled(12, weight: .semibold))
                    .foregroundColor(.sMutedFG)

                if isRequired {
                    Circle()
                        .fill(Color.sDestructive)
                        .frame(width: 4, height: 4)
                }

                Spacer()
            }

            TextField(placeholder, text: text)
                .font(.scaled(14, weight: .regular))
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
                    .font(.scaled(11))
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

