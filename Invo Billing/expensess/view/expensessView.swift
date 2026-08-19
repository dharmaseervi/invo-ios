//
//  ExpenseView.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/19/25.
//

import SwiftUI

struct ExpenseView: View {

    @StateObject private var vm = ExpenseViewModel()
    @State private var showDeleteAlert = false
    @State private var selectedExpense: Expense? = nil

    var totalAmount: Double {
        vm.expenses.reduce(0) { $0 + $1.amount }
    }

    var averageAmount: Double {
        guard !vm.expenses.isEmpty else { return 0 }
        return totalAmount / Double(vm.expenses.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
          
                    VStack( spacing: 0) {
                        // MARK: - Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("EXPENSES")
                                .font(.system(size: 30, weight: .thin))
                                .tracking(0.8)
                            
                            Text("Track and manage your expenses")
                                .font(.system(size: 12, weight: .light))
                                .foregroundColor(.gray)
                                .tracking(0.4)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                            .padding(.horizontal, 24)

                        // MARK: - Content
                        if vm.isLoading {
                            Spacer()
                            ProgressView().tint(.black)
                            Spacer()

                        } else if vm.expenses.isEmpty {
                            EmptyExpenseView()

                        } else {
                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 0) {

                                    // MARK: - Overview Cards
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("OVERVIEW")
                                            .font(
                                                .system(
                                                    size: 11,
                                                    weight: .semibold
                                                )
                                            )
                                            .tracking(1)
                                            .padding(.horizontal, 24)
                                            .padding(.top, 24)
                                            .padding(.bottom, 16)

                                        // Statistics Grid
                                        VStack(spacing: 12) {
                                            HStack(spacing: 12) {
                                                ExpenseStatCard(
                                                    label: "Total Count",
                                                    value:
                                                        "\(vm.expenses.count)",
                                                    icon: "doc.text"
                                                )

                                                ExpenseStatCard(
                                                    label: "Total Amount",
                                                    value:
                                                        "₹\(String(format: "%.0f", totalAmount))",
                                                    icon: "creditcard"
                                                )
                                            }

                                            HStack(spacing: 12) {
                                                ExpenseStatCard(
                                                    label: "Average",
                                                    value:
                                                        "₹\(String(format: "%.0f", averageAmount))",
                                                    icon: "chart.bar"
                                                )

                                                ExpenseStatCard(
                                                    label: "Latest",
                                                    value: formatDate(
                                                        vm.expenses.first?.date
                                                            ?? ""
                                                    ),
                                                    icon: "calendar"
                                                )
                                            }
                                        }
                                        .padding(.horizontal, 24)
                                    }
                                    .padding(.bottom, 36)

                                    // MARK: - Expense List
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("RECENT EXPENSES")
                                            .font(
                                                .system(
                                                    size: 11,
                                                    weight: .semibold
                                                )
                                            )
                                            .tracking(1)
                                            .padding(.horizontal, 24)
                                            .padding(.bottom, 16)

                                        VStack(spacing: 8) {
                                            ForEach(vm.expenses, id: \.id) {
                                                expense in
                                                NavigationLink {
                                                    ExpenseEditView(
                                                        vm: vm,
                                                        expense: expense
                                                    )
                                                } label: {
                                                    ExpenseRowWithActions(
                                                        expense: expense,
                                                        onDelete: {
                                                            selectedExpense =
                                                                expense
                                                            showDeleteAlert =
                                                                true
                                                        }
                                                    )
                                                }
                                                .buttonStyle(.plain)
                                            }

                                        }
                                        .padding(.horizontal, 24)
                                    }
                                    .padding(.bottom, 48)
                                }
                            }
                        }
                    }
                }
                .navigationBarHidden(false)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink {
                            ExpenseFormView()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.black)
                        }
                    }
                }
                .task {
                    await vm.fetchExpenses()
                }
                .refreshable {
                    await vm.fetchExpenses()
                }
                .alert(
                    "ERROR",
                    isPresented: $vm.showAlert,
                    actions: { Button("OK", role: .cancel) {} },
                    message: { Text(vm.errorMessage ?? "Unknown error") }
                )

                .alert("Delete Expense", isPresented: $showDeleteAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        if let expense = selectedExpense {
                            Task {
                                await vm.deleteExpense(id: expense.id)
                            }
                        }
                    }
                } message: {
                    Text(
                        "Are you sure you want to delete this expense? This action cannot be undone."
                    )
                }
            
        }
    }

    private func formatDate(_ raw: String) -> String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"

        guard let date = input.date(from: raw) else { return raw }

        let output = DateFormatter()
        output.dateFormat = "MMM dd"
        return output.string(from: date)
    }
}

// MARK: - Expense Row with Actions (Edit/Delete)
struct ExpenseRowWithActions: View {
    let expense: Expense
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {

            VStack(alignment: .leading, spacing: 6) {
                Text(expense.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
                    .lineLimit(1)

                Text(formatDate(expense.date))
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("₹\(String(format: "%.2f", expense.amount))")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.black)

                if let description = expense.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }

            Menu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .foregroundColor(.black.opacity(0.5))
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.04))
        )
    }

    private func formatDate(_ raw: String) -> String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: raw) else { return raw }

        let output = DateFormatter()
        output.dateFormat = "MMM dd, yyyy"
        return output.string(from: date)
    }
}

// MARK: - Stat Card
struct ExpenseStatCard: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black.opacity(0.6))

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(.gray)
                    .tracking(0.4)

                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.04))
        )
    }
}

// MARK: - Empty State
struct EmptyExpenseView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 44, weight: .thin))
                .foregroundColor(.black.opacity(0.2))

            Text("NO EXPENSES")
                .font(.system(size: 16, weight: .semibold))
                .tracking(0.4)

            Text("ADD YOUR FIRST EXPENSE TO GET STARTED")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(.gray)
                .tracking(0.4)
                .multilineTextAlignment(.center)

            NavigationLink {
                ExpenseFormView()
            } label: {
                Text("ADD EXPENSE")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.6)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(Color.black)
                    .cornerRadius(6)
            }
            .padding(.top, 12)

            Spacer()
        }
        .padding(32)
    }
}
