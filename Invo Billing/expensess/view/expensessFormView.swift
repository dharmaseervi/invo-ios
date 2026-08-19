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
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // MARK: - Header
                    VStack(spacing: 16) {
                        HStack {
                            Button("CANCEL") {
                                dismiss()
                            }
                            .font(.system(size: 11, weight: .light))
                            .tracking(0.6)
                            .foregroundColor(.black)
                            
                            Spacer()
                            
                            Text("NEW EXPENSE")
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(1)
                            
                            Spacer()
                            
                            Spacer().frame(width: 50)
                        }
                        .padding(.horizontal, 24)
                        
                        Divider()
                            .background(Color.black)
                    }
                    .padding(.vertical, 24)
                    
                    // MARK: - Form
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 32) {
                            
                            EditorialField(
                                label: "EXPENSE NAME",
                                placeholder: "Office rent, Internet, Fuel…",
                                text: $name,
                                keyboard: .default
                            )
                            
                            EditorialField(
                                label: "AMOUNT",
                                placeholder: "₹ 0.00",
                                text: $amount,
                                keyboard: .decimalPad
                            )
                            
                            // Date Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("DATE")
                                    .font(.system(size: 10, weight: .light))
                                    .tracking(0.8)
                                    .foregroundColor(.gray)
                                
                                DatePicker(
                                    "",
                                    selection: $date,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                            }
                            
                            // Description
                            VStack(alignment: .leading, spacing: 8) {
                                Text("DESCRIPTION")
                                    .font(.system(size: 10, weight: .light))
                                    .tracking(0.8)
                                    .foregroundColor(.gray)
                                
                                TextEditor(text: $description)
                                    .font(.system(size: 14, weight: .light))
                                    .frame(height: 100)
                                    .overlay(
                                        Rectangle()
                                            .frame(height: 0.5)
                                            .foregroundColor(.black.opacity(0.2)),
                                        alignment: .bottom
                                    )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                        .padding(.bottom, 120)
                    }
                    
                    // MARK: - Action Bar
                    VStack(spacing: 12) {
                        
                        Button {
                            Task {
                                let success = await vm.createExpense(
                                    name: name,
                                    amount: Double(amount) ?? 0,
                                    description: description.isEmpty ? nil : description, date: formattedDate
                                )
                                
                                if success {
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                if vm.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("SAVE EXPENSE")
                                        .font(.system(size: 12, weight: .semibold))
                                        .tracking(0.6)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(.white)
                            .background(Color.black)
                        }
                        .disabled(vm.isLoading || name.isEmpty || amount.isEmpty)
                        
                        Button {
                            resetForm()
                        } label: {
                            Text("CLEAR")
                                .font(.system(size: 11, weight: .light))
                                .tracking(0.6)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(.black)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.black, lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .background(Color.white)
                }
            }
            .navigationBarHidden(true)
            .alert(
                "ERROR",
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
    }
}


struct EditorialField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let keyboard: UIKeyboardType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .light))
                .tracking(0.8)
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .font(.system(size: 14, weight: .light))
                .padding(.vertical, 10)
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(.black.opacity(0.2)),
                    alignment: .bottom
                )
        }
    }
}
