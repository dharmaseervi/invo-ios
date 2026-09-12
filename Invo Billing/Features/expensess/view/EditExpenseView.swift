import SwiftUI

struct ExpenseEditView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var vm: ExpenseViewModel

    let expense: Expense

    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var description: String = ""
    @State private var date: Date = Date()

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !amount.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(amount) ?? 0 > 0
    }

    var hasChanges: Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let newDateString = dateFormatter.string(from: date)

        return name != expense.name ||
        amount != String(expense.amount) ||
        description != (expense.description ?? "") ||
        newDateString != expense.date
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
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.sMutedFG)

                            FormFieldView(
                                label: "Expense name",
                                placeholder: "Enter expense name",
                                text: $name
                            )

                            // Amount Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Amount")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.sForeground)

                                HStack(spacing: 8) {
                                    Text("₹")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.sMutedFG)

                                    TextField("0.00", text: $amount)
                                        .font(.system(size: 15))
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

                            // Date Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Date")
                                    .font(.system(size: 13, weight: .medium))
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
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.sMutedFG)

                            TextEditor(text: $description)
                                .font(.system(size: 15))
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
                    .padding(.horizontal, 20)
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

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let parsedDate = formatter.date(from: expense.date) {
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
        let dateString = dateFormatter.string(from: date)

        Task {
            let success = await vm.updateExpense(
                id: expense.id,
                name: name.trimmingCharacters(in: .whitespaces),
                amount: Double(amount) ?? 0,
                description: description.isEmpty ? nil : description
                    .trimmingCharacters(in: .whitespaces), date: dateString
            )

            if success {
                dismiss()
            }
        }
    }
}

// MARK: - Form Field Component
struct FormFieldView: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.sForeground)

            TextField(placeholder, text: $text)
                .font(.system(size: 15))
                .foregroundColor(.sForeground)
                .tint(.sAccent)
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
