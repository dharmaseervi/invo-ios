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
        Group {
            ZStack {
                Color.sBackground.ignoresSafeArea()

                VStack(spacing: 0) {

                    // MARK: - Content
                    if vm.isLoading {
                        Spacer()
                        ProgressView().tint(.sAccent)
                        Spacer()

                    } else if vm.expenses.isEmpty {
                        EmptyExpenseView()

                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {

                                // MARK: - Overview Cards
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("Overview")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.sMutedFG)
                                        .padding(.horizontal, 20)
                                        .padding(.top, 20)
                                        .padding(.bottom, 12)

                                    VStack(spacing: 10) {
                                        HStack(spacing: 10) {
                                            ExpenseStatCard(
                                                label: "Total count",
                                                value: "\(vm.expenses.count)",
                                                icon: "doc.text"
                                            )

                                            ExpenseStatCard(
                                                label: "Total amount",
                                                value: "₹\(String(format: "%.0f", totalAmount))",
                                                icon: "creditcard"
                                            )
                                        }

                                        HStack(spacing: 10) {
                                            ExpenseStatCard(
                                                label: "Average",
                                                value: "₹\(String(format: "%.0f", averageAmount))",
                                                icon: "chart.bar"
                                            )

                                            ExpenseStatCard(
                                                label: "Latest",
                                                value: formatDate(vm.expenses.first?.date ?? ""),
                                                icon: "calendar"
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                                .padding(.bottom, 24)

                                // MARK: - Expense List
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("Recent expenses")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.sMutedFG)
                                        .padding(.horizontal, 20)
                                        .padding(.bottom, 10)

                                    VStack(spacing: 8) {
                                        ForEach(vm.expenses, id: \.id) { expense in
                                            NavigationLink {
                                                ExpenseEditView(vm: vm, expense: expense)
                                            } label: {
                                                ExpenseRowWithActions(
                                                    expense: expense,
                                                    onDelete: {
                                                        selectedExpense = expense
                                                        showDeleteAlert = true
                                                    }
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                                .padding(.bottom, 40)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Expenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ExpenseFormView()
                    } label: {
                        Image(systemName: "plus")
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
                "Error",
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
                Text("Are you sure you want to delete this expense? This action cannot be undone.")
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

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.sForeground)
                    .lineLimit(1)

                Text(formatDate(expense.date))
                    .font(.system(size: 11))
                    .foregroundColor(.sMutedFG)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("₹\(String(format: "%.2f", expense.amount))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.sForeground)

                if let description = expense.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.sMutedFG)
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
                    .foregroundColor(.sMutedFG)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(14)
        .background(Color.sCard)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.sBorder, lineWidth: 0.5)
        )
        .cornerRadius(10)
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
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.sMutedFG)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.sMutedFG)

                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.sForeground)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.sCard)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.sBorder, lineWidth: 0.5)
        )
        .cornerRadius(10)
    }
}

// MARK: - Empty State
struct EmptyExpenseView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.sMutedFG)

            Text("No expenses")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.sForeground)

            Text("Add your first expense to get started")
                .font(.system(size: 13))
                .foregroundColor(.sMutedFG)
                .multilineTextAlignment(.center)

            NavigationLink {
                ExpenseFormView()
            } label: {
                Text("Add expense")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.sAccentFG)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.sPrimary)
                    .cornerRadius(10)
            }
            .padding(.top, 4)

            Spacer()
        }
        .padding(32)
    }
}
