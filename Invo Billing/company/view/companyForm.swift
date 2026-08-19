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
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // MARK: - Header
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 14, weight: .light, design: .default))
                        }
                        .foregroundColor(.black)
                    }
                    
                    Spacer()
                    
//                    Text("NEW COMPANY")
//                        .font(.system(size: 12, weight: .semibold, design: .default))
//                        .tracking(0.5)
//                        .foregroundColor(.gray)
//                    
//                    Spacer()
//                    
//                    if vm.isSaving {
//                        ProgressView()
//                            .tint(.black)
//                    } else {
//                        Image(systemName: "building.2")
//                            .font(.system(size: 14, weight: .semibold))
//                            .foregroundColor(.black)
//                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                
//                Divider()
//                    .frame(height: 1)
//                    .background(Color.black.opacity(0.08))
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        
                        // MARK: - Company Information Section
                        VStack(alignment: .leading, spacing: 0) {
                            Text("COMPANY INFORMATION")
                                .font(.system(size: 11, weight: .semibold, design: .default))
                                .tracking(1)
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.top, 28)
                                .padding(.bottom, 20)
                            
                            VStack(spacing: 0) {
                                CompanyFormField(
                                    title: "Company Name",
                                    placeholder: "Enter company name",
                                    text: $vm.name,
                                    error: vm.name.isEmpty ? "Name is required" : nil,
                                    focused: focusedField == .name
                                )
                                .focused($focusedField, equals: .name)
                                
                                Divider()
                                    .frame(height: 1)
                                    .background(Color.black.opacity(0.08))
                                    .padding(.horizontal, 24)
                                
                                CompanyFormField(
                                    title: "Phone",
                                    placeholder: "+91 XXXXX XXXXX",
                                    text: $vm.phone,
                                    keyboardType: .phonePad,
                                    focused: focusedField == .phone
                                )
                                .focused($focusedField, equals: .phone)
                                
                                Divider()
                                    .frame(height: 1)
                                    .background(Color.black.opacity(0.08))
                                    .padding(.horizontal, 24)
                                
                                CompanyFormField(
                                    title: "GST Number",
                                    placeholder: "XX XXXXX XXXXX XXXXX",
                                    text: $vm.gst,
                                    focused: focusedField == .gst
                                )
                                .focused($focusedField, equals: .gst)
                            }
                           
                        }
                        
                        // MARK: - Address Section
                        VStack(alignment: .leading, spacing: 0) {
                            Text("ADDRESS")
                                .font(.system(size: 11, weight: .semibold, design: .default))
                                .tracking(1)
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 20)
                            
                            VStack(spacing: 0) {
                                CompanyFormFieldMultiline(
                                    title: "Street Address",
                                    placeholder: "Enter street address",
                                    text: $vm.address,
                                    focused: focusedField == .address
                                )
                                .focused($focusedField, equals: .address)
                                
                                Divider()
                                    .frame(height: 1)
                                    .background(Color.black.opacity(0.08))
                                    .padding(.horizontal, 24)
                                
                                HStack(spacing: 0) {
                                    CompanyFormFieldHalf(
                                        title: "City",
                                        placeholder: "City",
                                        text: $vm.city,
                                        focused: focusedField == .city
                                    )
                                    .focused($focusedField, equals: .city)
                                    
                                    Divider()
                                        .frame(width: 1)
                                        .background(Color.black.opacity(0.08))
                                    
                                    CompanyFormFieldHalf(
                                        title: "Pincode",
                                        placeholder: "123456",
                                        text: $vm.pincode,
                                        keyboardType: .numberPad,
                                        focused: focusedField == .pincode
                                    )
                                    .focused($focusedField, equals: .pincode)
                                }
                                
                                Divider()
                                    .frame(height: 1)
                                    .background(Color.black.opacity(0.08))
                                    .padding(.horizontal, 24)
                                
                                CompanyFormField(
                                    title: "State",
                                    placeholder: "Enter state name",
                                    text: $vm.state,
                                    focused: focusedField == .state
                                )
                                .focused($focusedField, equals: .state)
                            }
                         
                        }
                        
                        VStack(spacing: 12) {
                            Button(action: {
                                Task {
                                    let ok = await vm.saveCompany()
                                    if ok { dismiss() }
                                }
                            }) {
                                HStack {
                                    if vm.isSaving {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text("SAVE COMPANY")
                                            .font(.system(size: 12, weight: .semibold, design: .default))
                                            .tracking(0.5)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.black)
                                .foregroundColor(.white)
                            }
                            .disabled(vm.isSaving || !vm.isValid)
                            
                            Button(action: {
                                dismiss()
                            }) {
                                Text("CANCEL")
                                    .font(.system(size: 12, weight: .semibold, design: .default))
                                    .tracking(0.5)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundColor(.black)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 0)
                                            .stroke(Color.black, lineWidth: 1)
                                    )
                            }
                            .disabled(vm.isSaving)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        
                        Color.clear.frame(height: 100)
                    }
                }
            }
 
        }
        .navigationBarHidden(true)
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 10, weight: .regular, design: .default))
                        .foregroundColor(.gray)
                        .tracking(0.3)
                    
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .font(.system(size: 15, weight: .light, design: .default))
                        .foregroundColor(.black)
                        .autocorrectionDisabled()
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

// MARK: - Company Form Field Multiline
struct CompanyFormFieldMultiline: View {
    let title: String
    var placeholder: String = ""
    @Binding var text: String
    var focused: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 10, weight: .regular, design: .default))
                    .foregroundColor(.gray)
                    .tracking(0.3)
                
                TextEditor(text: $text)
                    .font(.system(size: 13, weight: .light, design: .default))
                    .frame(height: 80)
                    .padding(8)
                    .background(Color.black.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
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
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 10, weight: .regular, design: .default))
                    .foregroundColor(.gray)
                    .tracking(0.3)
                
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .font(.system(size: 15, weight: .light, design: .default))
                    .foregroundColor(.black)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }
}

#Preview {
    companyForm()
}
