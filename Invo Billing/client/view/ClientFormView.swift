// ClientFormView.swift
// invo
// Minimalist Black & White Design (Zara Style)

import SwiftUI

struct ClientFormView: View {
    @StateObject var vm = ClientViewModel()
    @Environment(\.dismiss) var dismiss
    @FocusState private var focusedField: FormField?
    
    enum FormField {
        case name, email, phone, address, city, state, pincode
    }
    
    var body: some View {
        ZStack {
            // Pure white background
            Color.white.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // MARK: - Header
                    VStack(alignment: .leading, spacing: 16) {
                        Text("NEW CLIENT")
                            .font(.system(size: 28, weight: .thin, design: .default))
                            .tracking(0.5)
                        
                        Divider()
                            .frame(height: 1)
                            .background(Color.black)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                    
                    VStack(spacing: 40) {
                        // MARK: - Basic Information Section
                        VStack(alignment: .leading, spacing: 20) {
                            Text("CONTACT INFORMATION")
                                .font(.system(size: 11, weight: .semibold, design: .default))
                                .tracking(1.2)
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                            
                            VStack(spacing: 0) {
                                MinimalField(
                                    title: "Full Name",
                                    text: $vm.name,
                                    error: vm.name.isEmpty ? "Required" : nil,
                                    focused: focusedField == .name
                                )
                                .focused($focusedField, equals: .name)
                                
                                Divider()
                                    .frame(height: 1)
                                    .background(Color.black.opacity(0.1))
                                    .padding(.horizontal, 24)
                                
                                MinimalField(
                                    title: "Email",
                                    text: $vm.email,
                                    keyboardType: .emailAddress,
                                    focused: focusedField == .email
                                )
                                .focused($focusedField, equals: .email)
                                
                                Divider()
                                    .frame(height: 1)
                                    .background(Color.black.opacity(0.1))
                                    .padding(.horizontal, 24)
                                
                                MinimalField(
                                    title: "Phone",
                                    text: $vm.phone,
                                    keyboardType: .phonePad,
                                    focused: focusedField == .phone
                                )
                                .focused($focusedField, equals: .phone)
                            }
                        }
                        
                        // MARK: - Address Section
                        VStack(alignment: .leading, spacing: 20) {
                            Text("ADDRESS")
                                .font(.system(size: 11, weight: .semibold, design: .default))
                                
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                            
                            VStack(spacing: 0) {
                                MinimalField(
                                    title: "Street Address",
                                    text: $vm.address,
                                    focused: focusedField == .address
                                )
                                .focused($focusedField, equals: .address)
                                
                                Divider()
                                    .frame(height: 1)
                                    .background(Color.black.opacity(0.1))
                                    .padding(.horizontal, 24)
                                
                                HStack(spacing: 0) {
                                    MinimalFieldHalf(
                                        title: "City",
                                        text: $vm.city,
                                        focused: focusedField == .city
                                    )
                                    .focused($focusedField, equals: .city)
                                    
                                    Divider()
                                        .frame(width: 1)
                                        .background(Color.black.opacity(0.1))
                                    
                                    MinimalFieldHalf(
                                        title: "State",
                                        text: $vm.state,
                                        focused: focusedField == .state
                                    )
                                    .focused($focusedField, equals: .state)
                                }
                                
                                Divider()
                                    .frame(height: 1)
                                    .background(Color.black.opacity(0.1))
                                    .padding(.horizontal, 24)
                                
                                MinimalField(
                                    title: "Pincode",
                                    text: $vm.pincode,
                                    keyboardType: .numberPad,
                                    focused: focusedField == .pincode
                                )
                                .focused($focusedField, equals: .pincode)
                            }
                        }
                    }
                    .padding(.vertical, 0)
                    
                    // MARK: - Divider Line
                    Divider()
                        .frame(height: 1)
                        .background(Color.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 40)
                    
                    // MARK: - Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            Task {
                                let success = await vm.createNewClient()
                                if success {
                                    vm.resetForm()
                                    dismiss()
                                }
                            }
                        }) {
                            HStack(spacing: 12) {
                                if vm.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("CONFIRM")
                                        .font(.system(size: 13, weight: .semibold, design: .default))
                                       
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.black)
                            .foregroundColor(.white)
                        }
                        .disabled(vm.isLoading)
                        
                        Button(action: {
                            vm.resetForm()
                        }) {
                            Text("CLEAR")
                                .font(.system(size: 13, weight: .semibold, design: .default))
                              
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .foregroundColor(.black)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.black, lineWidth: 1)
                                )
                        }
                        .disabled(vm.isLoading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
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

// MARK: - Minimal Field
struct MinimalField: View {
    let title: String
    @Binding var text: String
    var error: String? = nil
    var keyboardType: UIKeyboardType = .default
    var focused: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 10, weight: .regular, design: .default))
                        .foregroundColor(.gray)
                        .tracking(0.3)
                    
                    TextField(title, text: $text)
                        .keyboardType(keyboardType)
                        .font(.system(size: 15, weight: .light, design: .default))
                        .foregroundColor(.black)
                }
                
                if error != nil {
                    Image(systemName: "exclamationmark")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            
            if let error = error {
                Text(error)
                    .font(.system(size: 9, weight: .regular, design: .default))
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Minimal Field Half Width
struct MinimalFieldHalf: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var focused: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 10, weight: .regular, design: .default))
                    .foregroundColor(.gray)
                    .tracking(0.3)
                
                TextField(title, text: $text)
                    .keyboardType(keyboardType)
                    .font(.system(size: 15, weight: .light, design: .default))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
    }
}

