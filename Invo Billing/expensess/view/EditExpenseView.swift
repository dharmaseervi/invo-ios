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
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 16) {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 16, weight: .regular))
                            }
                            .foregroundColor(.black)
                        }
                        
                        Spacer()
                        
                        Text("Edit Expense")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        if vm.isLoading {
                            ProgressView()
                                .tint(.black)
                                .frame(width: 40, height: 40)
                        } else {
                            Button(action: { saveExpense() }) {
                                Text("Save")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor((!isFormValid || !hasChanges) ? .gray : .black)
                            }
                            .disabled(!isFormValid || !hasChanges)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .background(Color.black.opacity(0.08))
                }
                .background(Color.white)
                
                // MARK: - Form Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // MARK: - Expense Details Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("EXPENSE DETAILS")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.8)
                                .foregroundColor(.gray)
                            
                            // Name Field
                            FormFieldView(
                                label: "Expense Name",
                                placeholder: "Enter expense name",
                                text: $name,
                           
                            )
                            
                            // Amount Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Amount")
                                    .font(.system(size: 12, weight: .light))
                                    .foregroundColor(.gray)
                                    .tracking(0.2)
                                
                                HStack(spacing: 8) {
                                    Text("₹")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                        .frame(width: 20, alignment: .center)
                                    
                                    TextField("0.00", text: $amount)
                                        .font(.system(size: 16, weight: .regular))
                                        .keyboardType(.decimalPad)
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 14)
                                .background(Color.gray.opacity(0.04))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                                )
                            }
                            
                            // Date Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date")
                                    .font(.system(size: 12, weight: .light))
                                    .foregroundColor(.gray)
                                    .tracking(0.2)
                                
                                DatePicker(
                                    "",
                                    selection: $date,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                .font(.system(size: 16, weight: .regular))
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                                .background(Color.gray.opacity(0.04))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                                )
                            }
                        }
                        
                        // MARK: - Description Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DESCRIPTION (OPTIONAL)")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.8)
                                .foregroundColor(.gray)
                            
                            TextEditor(text: $description)
                                .font(.system(size: 16, weight: .regular))
                                .frame(minHeight: 100)
                                .padding(12)
                                .background(Color.gray.opacity(0.04))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                                )
                                .scrollContentBackground(.hidden)
                        }
                        
                        // Bottom Spacer
                        VStack {}
                            .frame(height: 20)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                }
            }
        }
        .navigationBarHidden(true)
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
        amount = String(format: "%.2f", expense.amount)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .light))
                .foregroundColor(.gray)
                .tracking(0.2)
            
            TextField(placeholder, text: $text)
                .font(.system(size: 16, weight: .regular))
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
                .background(Color.gray.opacity(0.04))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
        }
    }
}

