import SwiftUI

struct ExpenseEditView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var vm: ExpenseViewModel

    let expense: Expense

    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var description: String = ""
    @State private var date: Date = Date()
    @State private var paymentMethod = ""
    @State private var category = ""

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !amount.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(amount) ?? 0 > 0
    }

    var hasChanges: Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        // Pinned: an unpinned formatter follows the device calendar, so a phone set
        // to the Indian National calendar sent 1948-06-21 for 12 September 2026.
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        let newDateString = dateFormatter.string(from: date)

        return name != expense.name ||
        amount != Money.editable(expense.amount) ||
        description != (expense.description ?? "") ||
        paymentMethod != (expense.paymentMethod ?? "") ||
        category != (expense.category ?? "") ||
        newDateString != AppDate.date(fromWire: expense.date).map(AppDate.wireString(from:))
    }

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Form Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // MARK: - Expense Details Section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Expense details")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.sMutedFG)

                            FormFieldView(
                                label: "Expense name",
                                placeholder: "Enter expense name",
                                text: $name
                            )

                            // Amount Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Amount")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.sForeground)

                                HStack(spacing: 8) {
                                    Text("₹")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.sMutedFG)

                                    TextField("0.00", text: $amount)
                                        .font(.body)
                                        .foregroundColor(.sForeground)
                                        .tint(.sAccent)
                                        .keyboardType(.decimalPad)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.sCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.sInput, lineWidth: 0.5)
                                )
                                .cornerRadius(8)
                            }

                            ExpenseCategoryPicker(selection: $category)
                            ExpensePaymentMethodPicker(selection: $paymentMethod)

                            // Date Field
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
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.sCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.sInput, lineWidth: 0.5)
                                )
                                .cornerRadius(8)
                            }
                        }

                        // MARK: - Description Section
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description (optional)")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.sMutedFG)

                            TextEditor(text: $description)
                                .font(.body)
                                .foregroundColor(.sForeground)
                                .frame(minHeight: 100)
                                .padding(10)
                                .background(Color.sCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.sInput, lineWidth: 0.5)
                                )
                                .cornerRadius(8)
                                .scrollContentBackground(.hidden)
                        }
                    }
                    .padding(.horizontal, AppSpacing.page)
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationTitle("Edit expense")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if vm.isLoading {
                    ProgressView()
                } else {
                    Button("Save") { saveExpense() }
                        .fontWeight(.semibold)
                        .disabled(!isFormValid || !hasChanges)
                }
            }
        }
        .onAppear {
            loadExpenseData()
        }
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(vm.errorMessage ?? "Unknown error")
        }
    }

    // MARK: - Private Methods

    private func loadExpenseData() {
        name = expense.name
        amount = Money.editable(expense.amount)
        description = expense.description ?? ""
        paymentMethod = expense.paymentMethod ?? ""
        category = expense.category ?? ""

        // The API can return a timestamp; changing only the payment method must not
        // accidentally move an older expense onto today's cash closing.
        if let parsedDate = AppDate.date(fromWire: expense.date) {
            date = parsedDate
        }
    }

    private func saveExpense() {
        guard isFormValid else {
            vm.errorMessage = "Please fill in all required fields"
            vm.showAlert = true
            return
        }

        guard hasChanges else {
            vm.errorMessage = "No changes made"
            vm.showAlert = true
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        // Pinned: an unpinned formatter follows the device calendar, so a phone set
        // to the Indian National calendar sent 1948-06-21 for 12 September 2026.
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        let dateString = dateFormatter.string(from: date)

        Task {
            let success = await vm.updateExpense(
                id: expense.id,
                name: name.trimmingCharacters(in: .whitespaces),
                amount: Double(amount) ?? 0,
                description: description.isEmpty ? nil : description
                    .trimmingCharacters(in: .whitespaces), date: dateString,
                paymentMethod: paymentMethod,
                category: category.isEmpty ? nil : category
            )

            if success {
                dismiss()
            }
        }
    }
}
