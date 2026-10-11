import SwiftUI

struct CompanyEditView: View {
    let company: CompanyResponse
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Field?

    @State private var name: String
    @State private var phone: String
    @State private var gst: String
    @State private var address: String
    @State private var city: String
    @State private var pincode: String
    @State private var state: String
    @State private var invoiceFooter: String
    @State private var invoicePrefix: String

    @State private var isSaving = false
    @State private var errorMessage: String?

    private let service = CompanyService()

    enum Field { case name, phone, gst, address, city, pincode, footer, prefix }

    init(company: CompanyResponse) {
        self.company = company
        _name          = State(initialValue: company.name)
        _phone         = State(initialValue: company.phone)
        _gst           = State(initialValue: company.gst)
        _address       = State(initialValue: company.address)
        _city          = State(initialValue: company.city)
        _pincode       = State(initialValue: company.pincode)
        _state         = State(initialValue: company.state)
        _invoiceFooter = State(initialValue: company.invoice_footer ?? "")
        _invoicePrefix = State(initialValue: company.invoice_prefix ?? "INV")
    }

    var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {

                    // MARK: Company info
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Company information")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.sMutedFG)

                        VStack(spacing: 12) {
                            CompanyFormField(title: "Company name", placeholder: "Enter company name",
                                            text: $name,
                                            error: name.isEmpty ? "Name is required" : nil,
                                            focused: focused == .name)
                            .focused($focused, equals: .name)

                            CompanyFormField(title: "Phone", placeholder: "+91 XXXXX XXXXX",
                                            text: $phone, keyboardType: .phonePad,
                                            focused: focused == .phone)
                            .focused($focused, equals: .phone)

                            CompanyFormField(title: "GST number", placeholder: "XX XXXXX XXXXX XXXXX",
                                            text: $gst, focused: focused == .gst)
                            .focused($focused, equals: .gst)
                        }
                    }

                    // MARK: Address
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Address")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.sMutedFG)

                        VStack(spacing: 12) {
                            CompanyFormFieldMultiline(title: "Street address",
                                                     placeholder: "Enter street address",
                                                     text: $address,
                                                     focused: focused == .address)
                            .focused($focused, equals: .address)

                            AdaptiveFormRow {
                                CompanyFormFieldHalf(title: "City", placeholder: "City",
                                                    text: $city, focused: focused == .city)
                                .focused($focused, equals: .city)

                                CompanyFormFieldHalf(title: "Pincode", placeholder: "123456",
                                                    text: $pincode, keyboardType: .numberPad,
                                                    focused: focused == .pincode)
                                .focused($focused, equals: .pincode)
                            }
                            IndianStatePicker(label: "State", text: $state)
                        }
                    }

                    // MARK: Invoice Number Prefix
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Invoice number prefix")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.sMutedFG)
                            Text("Used when generating invoice numbers, e.g. \"INV\" → INV/2025-26/0001.")
                                .font(.caption)
                                .foregroundColor(.sMutedFG)
                        }
                        TextField("INV", text: $invoicePrefix)
                            .font(.body)
                            .foregroundColor(.sForeground)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.sCard)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sInput, lineWidth: 0.5))
                            .cornerRadius(8)
                            .focused($focused, equals: .prefix)
                    }

                    // MARK: Invoice Footer
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Invoice footer")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.sMutedFG)
                            Text("Appears at the bottom of every invoice PDF — bank details, T&C, or a thank-you note.")
                                .font(.caption)
                                .foregroundColor(.sMutedFG)
                        }

                        TextEditor(text: $invoiceFooter)
                            .font(.subheadline)
                            .foregroundColor(.sForeground)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 90)
                            .padding(10)
                            .background(Color.sCard)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sInput, lineWidth: 0.5))
                            .cornerRadius(8)
                            .focused($focused, equals: .footer)
                    }

                    // MARK: Buttons
                    VStack(spacing: 10) {
                        Button {
                            Task { await save() }
                        } label: {
                            HStack(spacing: 8) {
                                if isSaving {
                                    ProgressView().tint(.sAccentFG).scaleEffect(0.85)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Save changes")
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                            .foregroundColor(.sAccentFG)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isValid ? Color.sPrimary : Color.sPrimary.opacity(0.4))
                            .cornerRadius(10)
                        }
                        .disabled(isSaving || !isValid)

                        Button { dismiss() } label: {
                            Text("Cancel")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundColor(.sForeground)
                                .background(Color.sCard)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                                .cornerRadius(10)
                        }
                        .disabled(isSaving)
                    }

                    Color.clear.frame(height: 40)
                }
                .padding(AppSpacing.card)
            }
        }
        .navigationTitle("Edit company")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let payload = CompanyRequestDTO(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone,
            address: address,
            gst: gst,
            city: city,
            state: state,
            pincode: pincode,
            invoice_footer: invoiceFooter,
            invoice_prefix: invoicePrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "INV" : invoicePrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        do {
            try await service.updateCompany(id: company.id, payload: payload)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
