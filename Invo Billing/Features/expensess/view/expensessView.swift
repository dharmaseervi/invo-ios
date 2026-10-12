//
//  ExpenseView.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/19/25.
//

import SwiftUI

struct ExpenseView: View {
    #if DEBUG
    @State private var debugExpenseForm = false
    #endif

    @StateObject private var vm = ExpenseViewModel()
    @State private var showDeleteAlert = false
    @State private var selectedExpense: Expense? = nil
    @State private var showFilterSheet = false
    @State private var searchTask: Task<Void, Never>?

    var totalAmount: Double { vm.summary.total }

    var averageAmount: Double {
        guard vm.summary.count > 0 else { return 0 }
        return vm.summary.total / Double(vm.summary.count)
    }

    var hasActiveFilter: Bool {
        !vm.filterCategory.isEmpty || vm.filterFrom != nil || vm.filterTo != nil
    }

    var body: some View {
        Group {
            contentArea
                .navigationTitle("Expenses")
                #if DEBUG
                .navigationDestination(isPresented: $debugExpenseForm) { ExpenseFormView() }
                .onAppear {
                    if UserDefaults.standard.string(forKey: "startScreen") == "expenseform" { debugExpenseForm = true }
                }
                #endif
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $vm.searchText, prompt: "Search expenses")
                .onChange(of: vm.searchText) { _ in
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        guard !Task.isCancelled else { return }
                        await vm.fetchExpenses()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 16) {
                            Button {
                                showFilterSheet = true
                            } label: {
                                Image(systemName: hasActiveFilter
                                      ? "line.3.horizontal.decrease.circle.fill"
                                      : "line.3.horizontal.decrease.circle")
                                    .foregroundStyle(hasActiveFilter ? Color.sAccent : .secondary)
                            }
                            NavigationLink {
                                ExpenseFormView()
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
                .task { await vm.fetchExpenses() }
                .refreshable { await vm.fetchExpenses() }
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
                            Task { await vm.deleteExpense(id: expense.id) }
                        }
                    }
                } message: {
                    Text("Are you sure you want to delete this expense? This action cannot be undone.")
                }
                .sheet(isPresented: $showFilterSheet) {
                    ExpenseFilterSheet(vm: vm)
                }
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if vm.isLoading && vm.expenses.isEmpty {
            VStack(spacing: 12) {
                ProgressView().tint(.sAccent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                // Active filter chips
                if hasActiveFilter {
                    filterChipsRow
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                // Overview stats (when there are expenses)
                if !vm.expenses.isEmpty {
                    overviewSection
                        .listHeaderRow()
                }

                // Empty state
                if vm.expenses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.scaled(40))
                            .foregroundStyle(.secondary)
                        Text(vm.searchText.isEmpty ? "No expenses" : "No results")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(vm.searchText.isEmpty
                             ? "Add your first expense to get started"
                             : "Try a different search")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        if vm.searchText.isEmpty {
                            NavigationLink {
                                ExpenseFormView()
                            } label: {
                                Text("Add expense")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.sAccentFG)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.sPrimary)
                                    .cornerRadius(10)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                } else {
                    ForEach(vm.expenses, id: \.id) { expense in
                        NavigationLink {
                            ExpenseEditView(vm: vm, expense: expense)
                        } label: {
                            ExpenseRowContent(expense: expense)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                selectedExpense = expense
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .standardListRow()
                        .listRowSeparator(.hidden, edges: expense.id == vm.expenses.first?.id ? .top : [])
                        .task { await vm.loadMoreIfNeeded(currentItem: expense) }
                    }

                    if vm.isLoadingMore {
                        HStack { Spacer(); ProgressView().tint(.sAccent); Spacer() }
                            .padding(.vertical, 12)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    } else if vm.loadMoreFailed {
                        VStack(spacing: 6) {
                            Text("Couldn't load more expenses.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Try again") { Task { await vm.retryLoadMore() } }
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.sAccent)
                        }
                        .padding(.vertical, 12)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .contentMargins(.bottom, 16, for: .scrollContent)
        }
    }

    private var overviewSection: some View {
        SummaryCard(
            title: "Total spent",
            value: vm.summaryFailed ? "—" : Money.text(totalAmount),
            stats: [
                .init(label: "Expenses", value: vm.summaryFailed ? "—" : "\(vm.summary.count)"),
                .init(label: "Average", value: vm.summaryFailed ? "—" : Money.text(averageAmount)),
                .init(label: "Latest", value: vm.expenses.first.map { AppDate.shortText(fromWire: $0.date) } ?? "—")
            ]
        )
    }

    private var filterChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !vm.filterCategory.isEmpty {
                    filterChip(vm.filterCategory) {
                        vm.filterCategory = ""
                        Task { await vm.fetchExpenses() }
                    }
                }
                if let from = vm.filterFrom {
                    filterChip("From \(chipDate(from))") {
                        vm.filterFrom = nil
                        Task { await vm.fetchExpenses() }
                    }
                }
                if let to = vm.filterTo {
                    filterChip("To \(chipDate(to))") {
                        vm.filterTo = nil
                        Task { await vm.fetchExpenses() }
                    }
                }
                Button("Clear all") {
                    vm.filterCategory = ""; vm.filterFrom = nil; vm.filterTo = nil
                    Task { await vm.fetchExpenses() }
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.sAccent)
            }
            .padding(.horizontal, AppSpacing.page)
        }
    }

    /// Parses whatever shape the API sends — this field comes back as a full
    /// timestamp, which the old "yyyy-MM-dd"-only parser rejected, leaving
    /// "2026-09-11T00:00:00Z" on screen.

    @ViewBuilder
    private func filterChip(_ label: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.footnote.weight(.medium)).foregroundStyle(.primary)
            Button(action: onRemove) {
                Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(UIColor.separator), lineWidth: 0.5))
        .cornerRadius(14)
    }

    private func chipDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f.string(from: date)
    }
}

// MARK: - Filter sheet
struct ExpenseFilterSheet: View {
    @ObservedObject var vm: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var localCategory: String
    @State private var localFrom: Date
    @State private var localTo: Date
    @State private var fromEnabled: Bool
    @State private var toEnabled: Bool

    init(vm: ExpenseViewModel) {
        self.vm = vm
        _localCategory = State(initialValue: vm.filterCategory)
        _localFrom = State(initialValue: vm.filterFrom ?? Calendar.current.date(byAdding: .month, value: -1, to: Date())!)
        _localTo = State(initialValue: vm.filterTo ?? Date())
        _fromEnabled = State(initialValue: vm.filterFrom != nil)
        _toEnabled = State(initialValue: vm.filterTo != nil)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Category") {
                    Picker("Category", selection: $localCategory) {
                        Text("All categories").tag("")
                        ForEach(expenseCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.sAccent)
                }

                Section("Date range") {
                    Toggle("From", isOn: $fromEnabled)
                        .tint(.sAccent)
                    if fromEnabled {
                        DatePicker("", selection: $localFrom, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .tint(.sAccent)
                            .labelsHidden()
                    }
                    Toggle("To", isOn: $toEnabled)
                        .tint(.sAccent)
                    if toEnabled {
                        DatePicker("", selection: $localTo, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .tint(.sAccent)
                            .labelsHidden()
                    }
                }
            }
            .navigationTitle("Filter expenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        vm.filterCategory = localCategory
                        vm.filterFrom = fromEnabled ? localFrom : nil
                        vm.filterTo = toEnabled ? localTo : nil
                        dismiss()
                        Task { await vm.fetchExpenses() }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Expense Row Content (no card styling — applied by the List row)
struct ExpenseRowContent: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(formatDate(expense.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let cat = expense.category, !cat.isEmpty {
                        Text(cat)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.sAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.sAccent.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(Money.text(expense.amount)).moneyLine()
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let description = expense.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 88, alignment: .trailing)
        }
    }

    /// Parses whatever shape the API sends — this field comes back as a full
    /// timestamp, which the old "yyyy-MM-dd"-only parser rejected, leaving
    /// "2026-09-11T00:00:00Z" on screen.
    private func formatDate(_ raw: String) -> String {
        AppDate.text(fromWire: raw)
    }
}

// MARK: - ExpenseRowWithActions kept for any external callers
struct ExpenseRowWithActions: View {
    let expense: Expense
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.sForeground)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(formatDate(expense.date))
                        .font(.caption)
                        .foregroundColor(.sMutedFG)
                    if let cat = expense.category, !cat.isEmpty {
                        Text(cat)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.sAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.sAccent.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(Money.text(expense.amount)).moneyLine()
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.sForeground)

                if let description = expense.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.sMutedFG)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 88, alignment: .trailing)

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
        AppDate.text(fromWire: raw)
    }
}

// MARK: - Empty State
struct EmptyExpenseView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "tray")
                .font(.scaled(40))
                .foregroundColor(.sMutedFG)

            Text("No expenses")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.sForeground)

            Text("Add your first expense to get started")
                .font(.subheadline)
                .foregroundColor(.sMutedFG)
                .multilineTextAlignment(.center)

            NavigationLink {
                ExpenseFormView()
            } label: {
                Text("Add expense")
                    .font(.subheadline.weight(.semibold))
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
