//
//  expensessFormView.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/19/25.
//
import SwiftUI


struct ExpenseFormView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = ExpenseViewModel()

    // MARK: - Form State
    @State private var name = ""
    @State private var amount = ""
    @State private var date = Date()
    @State private var description = ""
    @State private var paymentMethod = ""
    @State private var category = ""

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // Pinned: an unpinned formatter follows the device calendar, so a phone set
        // to the Indian National calendar sent 1948-06-21 for 12 September 2026.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter.string(from: date)
    }

    var body: some View {
        Group {
            ZStack {
                Color.sBackground.ignoresSafeArea()

                VStack(spacing: 0) {

                    // MARK: - Form
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {

                            FormFieldView(
                                label: "Expense name",
                                placeholder: "Office rent, Internet, Fuel…",
                                text: $name
                            )

                            FormFieldView(
                                label: "Amount",
                                placeholder: "₹ 0.00",
                                text: $amount,
                                keyboard: .decimalPad
                            )

                            ExpenseCategoryPicker(selection: $category)
                            ExpensePaymentMethodPicker(selection: $paymentMethod)

                            // Date Picker
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Date")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.sForeground)

                                DatePicker(
                                    "",
                                    selection: $date,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                .tint(.sAccent)
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            // Description
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Description")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.sForeground)

                                TextEditor(text: $description)
                                    .font(.body)
                                    .foregroundColor(.sForeground)
                                    .scrollContentBackground(.hidden)
                                    .frame(height: 100)
                                    .padding(8)
                                    .background(Color.sCard)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.sInput, lineWidth: 0.5)
                                    )
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, AppSpacing.page)
                        .padding(.top, 20)
                        .padding(.bottom, 120)
                    }

                    // MARK: - Action Bar
                    VStack(spacing: 10) {

                        Button {
                            Task {
                                let success = await vm.createExpense(
                                    name: name,
                                    amount: Double(amount) ?? 0,
                                    description: description.isEmpty ? nil : description,
                                    date: formattedDate,
                                    paymentMethod: paymentMethod,
                                    category: category.isEmpty ? nil : category
                                )

                                if success {
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if vm.isLoading {
                                    ProgressView().tint(.sAccentFG)
                                        .scaleEffect(0.85)
                                } else {
                                    Text("Save expense")
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                            .foregroundColor(.sAccentFG)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background((name.isEmpty || amount.isEmpty) ? Color.sPrimary.opacity(0.4) : Color.sPrimary)
                            .cornerRadius(10)
                        }
                        .disabled(vm.isLoading || name.isEmpty || amount.isEmpty)

                        Button {
                            resetForm()
                        } label: {
                            Text("Clear")
                                .font(.subheadline.weight(.medium))
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
                    }
                    .padding(.horizontal, AppSpacing.page)
                    .padding(.bottom, 20)
                    .background(Color.sBackground)
                }
            }
            .navigationTitle("New expense")
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                "Error",
                isPresented: $vm.showAlert,
                actions: { Button("OK", role: .cancel) {} },
                message: { Text(vm.errorMessage ?? "Unknown error") }
            )
        }
    }

    // MARK: - Reset
    private func resetForm() {
        name = ""
        amount = ""
        description = ""
        date = Date()
        paymentMethod = ""
        category = ""
    }
}

// MARK: - Category Picker

let expenseCategories = [
    "Rent", "Salaries", "Utilities", "Travel", "Food & Entertainment",
    "Office supplies", "Marketing", "Professional fees", "Repairs & Maintenance",
    "Insurance", "Taxes & levies", "Depreciation", "Other"
]

struct ExpenseCategoryPicker: View {
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Category")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.sForeground)

            Menu {
                Button { selection = "" } label: {
                    Label("Uncategorised", systemImage: selection.isEmpty ? "checkmark" : "")
                }
                ForEach(expenseCategories, id: \.self) { cat in
                    Button { selection = cat } label: {
                        Label(cat, systemImage: selection == cat ? "checkmark" : "")
                    }
                }
            } label: {
                HStack {
                    Text(selection.isEmpty ? "Uncategorised" : selection)
                        .font(.body)
                        .foregroundColor(selection.isEmpty ? .sMutedFG : .sForeground)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote)
                        .foregroundColor(.sMutedFG)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.sCard)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sInput, lineWidth: 0.5))
                .cornerRadius(8)
            }
        }
    }
}

struct ExpensePaymentMethodPicker: View {
    @Binding var selection: String
    private let methods = ["Cash", "UPI", "Bank transfer", "Card", "Cheque", "Other"]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Paid by")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.sForeground)

            Menu {
                Button { selection = "" } label: {
                    Label("Not recorded", systemImage: selection.isEmpty ? "checkmark" : "")
                }
                ForEach(methods, id: \.self) { method in
                    Button { selection = method } label: {
                        Label(method, systemImage: selection == method ? "checkmark" : "")
                    }
                }
                // Preserve values recorded by other clients, including older spellings.
                if !selection.isEmpty && !methods.contains(selection) {
                    Button { } label: { Label(selection, systemImage: "checkmark") }
                }
            } label: {
                HStack {
                    Text(selection.isEmpty ? "Not recorded" : selection)
                        .font(.body)
                        .foregroundColor(selection.isEmpty ? .sMutedFG : .sForeground)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote)
                        .foregroundColor(.sMutedFG)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.sCard)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sInput, lineWidth: 0.5))
                .cornerRadius(8)
            }

            Text("Choose Cash if this expense was paid from the drawer.")
                .font(.footnote)
                .foregroundColor(.sMutedFG)
        }
    }
}
