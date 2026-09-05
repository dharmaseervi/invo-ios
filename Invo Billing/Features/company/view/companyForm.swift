import SwiftUI

struct companyForm: View {
    @StateObject private var vm = CompanyFormViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: FormField?
    
    enum FormField {
        case name, phone, gst, address, city, pincode, state
    }
    
    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {

                        // MARK: - Company Information Section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Company information")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.sMutedFG)

                            VStack(spacing: 12) {
                                CompanyFormField(
                                    title: "Company name",
                                    placeholder: "Enter company name",
                                    text: $vm.name,
                                    error: vm.name.isEmpty ? "Name is required" : nil,
                                    focused: focusedField == .name
                                )
                                .focused($focusedField, equals: .name)

                                CompanyFormField(
                                    title: "Phone",
                                    placeholder: "+91 XXXXX XXXXX",
                                    text: $vm.phone,
                                    keyboardType: .phonePad,
                                    focused: focusedField == .phone
                                )
                                .focused($focusedField, equals: .phone)

                                CompanyFormField(
                                    title: "GST number",
                                    placeholder: "XX XXXXX XXXXX XXXXX",
                                    text: $vm.gst,
                                    focused: focusedField == .gst
                                )
                                .focused($focusedField, equals: .gst)
                            }
                        }

                        // MARK: - Address Section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Address")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.sMutedFG)

                            VStack(spacing: 12) {
                                CompanyFormFieldMultiline(
                                    title: "Street address",
                                    placeholder: "Enter street address",
                                    text: $vm.address,
                                    focused: focusedField == .address
                                )
                                .focused($focusedField, equals: .address)

                                HStack(spacing: 10) {
                                    CompanyFormFieldHalf(
                                        title: "City",
                                        placeholder: "City",
                                        text: $vm.city,
                                        focused: focusedField == .city
                                    )
                                    .focused($focusedField, equals: .city)

                                    CompanyFormFieldHalf(
                                        title: "Pincode",
                                        placeholder: "123456",
                                        text: $vm.pincode,
                                        keyboardType: .numberPad,
                                        focused: focusedField == .pincode
                                    )
                                    .focused($focusedField, equals: .pincode)
                                }

                                IndianStatePicker(label: "State", text: $vm.state)
                            }
                        }

                        VStack(spacing: 10) {
                            Button(action: {
                                Task {
                                    let ok = await vm.saveCompany()
                                    if ok { dismiss() }
                                }
                            }) {
                                HStack(spacing: 8) {
                                    if vm.isSaving {
                                        ProgressView()
                                            .tint(.sAccentFG)
                                            .scaleEffect(0.85)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text("Save company")
                                            .font(.system(size: 15, weight: .semibold))
                                    }
                                }
                                .foregroundColor(.sAccentFG)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(vm.isValid ? Color.sPrimary : Color.sPrimary.opacity(0.4))
                                .cornerRadius(10)
                            }
                            .disabled(vm.isSaving || !vm.isValid)

                            Button(action: {
                                dismiss()
                            }) {
                                Text("Cancel")
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .foregroundColor(.sForeground)
                                    .background(Color.sCard)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.sBorder, lineWidth: 0.5)
                                    )
                                    .cornerRadius(10)
                            }
                            .disabled(vm.isSaving)
                        }

                        Color.clear.frame(height: 40)
                    }
                    .padding(20)
                }
            }

        }
        .navigationTitle("New company")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Company Form Field
struct CompanyFormField: View {
    let title: String
    var placeholder: String = ""
    @Binding var text: String
    var error: String? = nil
    var keyboardType: UIKeyboardType = .default
    var focused: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.sForeground)
                if error != nil {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.sDestructive)
                }
            }

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .font(.system(size: 14))
                .foregroundColor(.sForeground)
                .tint(.sAccent)
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
                    .font(.system(size: 11))
                    .foregroundColor(.sDestructive)
            }
        }
    }
}

// MARK: - Company Form Field Multiline
struct CompanyFormFieldMultiline: View {
    let title: String
    var placeholder: String = ""
    @Binding var text: String
    var focused: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.sForeground)

            TextEditor(text: $text)
                .font(.system(size: 14))
                .foregroundColor(.sForeground)
                .scrollContentBackground(.hidden)
                .frame(height: 80)
                .padding(8)
                .background(Color.sCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.sInput, lineWidth: 0.5)
                )
                .cornerRadius(8)
        }
    }
}

// MARK: - Company Form Field Half Width
struct CompanyFormFieldHalf: View {
    let title: String
    var placeholder: String = ""
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var focused: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.sForeground)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .font(.system(size: 14))
                .foregroundColor(.sForeground)
                .tint(.sAccent)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.sCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.sInput, lineWidth: 0.5)
                )
                .cornerRadius(8)
        }
    }
}

#Preview {
    companyForm()
}
