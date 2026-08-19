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
    
    @FocusState private var focusedField: AddressField?
    @State private var showValidation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Subtle gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white,
                        Color.black.opacity(0.01)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 28) {
                        
                        // Header with description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(address.type.capitalized) Details")
                                .font(.system(size: 24, weight: .bold, design: .default))
                                .tracking(-0.5)
                            
                            Text("Complete address information for invoicing")
                                .font(.system(size: 13, weight: .regular, design: .default))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // ADDRESS SECTION
                        section(
                            title: "ADDRESS INFORMATION",
                            icon: "location.fill",
                            content: {
                                addressField(
                                    "Name",
                                    text: $address.name,
                                    icon: "person.fill",
                                    field: .name,
                                    placeholder: "Business or person name"
                                )
                                
                                addressField(
                                    "Address Line 1",
                                    text: $address.line1,
                                    icon: "house.fill",
                                    field: .line1,
                                    placeholder: "Street address",
                                    isRequired: true
                                )
                                
                                addressField(
                                    "Address Line 2",
                                    text: $address.line2,
                                    icon: "door.left.hand.open",
                                    field: .line2,
                                    placeholder: "Apartment, suite, etc. (optional)"
                                )
                                
                                HStack(spacing: 12) {
                                    VStack(spacing: 8) {
                                        Label("City", systemImage: "building.2.fill")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.gray)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        TextField("City", text: $address.city)
                                            .font(.system(size: 14, weight: .regular))
                                            .focused($focusedField, equals: .city)
                                            .textFieldStyle(.plain)
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 0)
                                            .overlay(
                                                Rectangle()
                                                    .frame(height: 1)
                                                    .foregroundColor(
                                                        focusedField == .city ? .black : Color.black.opacity(0.1)
                                                    ),
                                                alignment: .bottom
                                            )
                                            .animation(.easeInOut(duration: 0.2), value: focusedField)
                                    }
                                    
                                    VStack(spacing: 8) {
                                        Label("State", systemImage: "map.fill")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.gray)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        TextField("State", text: $address.state)
                                            .font(.system(size: 14, weight: .regular))
                                            .focused($focusedField, equals: .state)
                                            .textFieldStyle(.plain)
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 0)
                                            .overlay(
                                                Rectangle()
                                                    .frame(height: 1)
                                                    .foregroundColor(
                                                        focusedField == .state ? .black : Color.black.opacity(0.1)
                                                    ),
                                                alignment: .bottom
                                            )
                                            .animation(.easeInOut(duration: 0.2), value: focusedField)
                                    }
                                }
                                
                                HStack(spacing: 12) {
                                    VStack(spacing: 8) {
                                        Label("Postal Code", systemImage: "mailbox.fill")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.gray)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        TextField("Postal Code", text: $address.postalCode)
                                            .font(.system(size: 14, weight: .regular))
                                            .focused($focusedField, equals: .postalCode)
                                            .textFieldStyle(.plain)
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 0)
                                            .overlay(
                                                Rectangle()
                                                    .frame(height: 1)
                                                    .foregroundColor(
                                                        focusedField == .postalCode ? .black : Color.black.opacity(0.1)
                                                    ),
                                                alignment: .bottom
                                            )
                                            .animation(.easeInOut(duration: 0.2), value: focusedField)
                                    }
                                    
                                    VStack(spacing: 8) {
                                        Label("Country", systemImage: "globe")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.gray)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        TextField("Country", text: $address.country)
                                            .font(.system(size: 14, weight: .regular))
                                            .focused($focusedField, equals: .country)
                                            .textFieldStyle(.plain)
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 0)
                                            .overlay(
                                                Rectangle()
                                                    .frame(height: 1)
                                                    .foregroundColor(
                                                        focusedField == .country ? .black : Color.black.opacity(0.1)
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
                                    text: $address.phone,
                                    icon: "phone.fill",
                                    field: .phone,
                                    placeholder: "+91 XXXXX XXXXX"
                                )
                                
                                addressField(
                                    "Email",
                                    text: $address.email,
                                    icon: "envelope.fill",
                                    field: .email,
                                    placeholder: "name@company.com"
                                )
                                
                                addressField(
                                    "GST Number",
                                    text: $address.gstNumber,
                                    icon: "doc.text.fill",
                                    field: .gstNumber,
                                    placeholder: "27AABCT5055K1Z0"
                                )
                            }
                        )
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            Button(action: {
                                dismiss()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("SAVE ADDRESS")
                                        .font(.system(size: 13, weight: .semibold, design: .default))
                                        .tracking(0.5)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.black)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .activeOpacity()
                            }
                            
                            Button(action: {
                                dismiss()
                            }) {
                                Text("CANCEL")
                                    .font(.system(size: 13, weight: .semibold, design: .default))
                                    .tracking(0.5)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundColor(.black)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                                    )
                                    .activeOpacity()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Components
    
    private func section<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black)
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .tracking(0.8)
                    .foregroundColor(.black.opacity(0.7))
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                content()
            }
            .padding(16)
            .background(Color.black.opacity(0.02))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
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
        isRequired: Bool = false
    ) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Label(label, systemImage: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
                
                if isRequired {
                    Circle()
                        .fill(Color.red)
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
                            focusedField == field ? .black : Color.black.opacity(0.1)
                        ),
                    alignment: .bottom
                )
                .animation(.easeInOut(duration: 0.2), value: focusedField)
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

// MARK: - Helper View Modifier
extension View {
    func activeOpacity() -> some View {
        self.opacity(1.0)
            .scaleEffect(1.0)
    }
}

