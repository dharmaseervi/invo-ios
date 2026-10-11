//
//  CashClosingView.swift
//  Invo Billing
//
//  Counting the drawer at the end of the day.
//

import SwiftUI

struct CashClosingView: View {
    @StateObject private var vm = CashClosingViewModel()

    @State private var date = Date()
    @State private var counted = ""
    @State private var note = ""
    @State private var openingOverride = ""
    @State private var showOpeningField = false
    @FocusState private var countFocused: Bool

    /// The float in force: what was typed, or what the drawer carried over.
    private var openingValue: Double { Double(openingOverride) ?? vm.opening }

    private var countedValue: Double? { Double(counted) }

    /// The difference as it is being typed, before anything is saved — so a wrong digit
    /// shows itself while the money is still on the table.
    private var liveDifference: Double? {
        guard let value = countedValue else { return nil }
        return value - liveExpected
    }

    /// What should be in the drawer, following any float typed in now rather than
    /// waiting for the server to say so after saving.
    private var liveExpected: Double {
        guard let typed = Double(openingOverride) else { return vm.expected }
        return vm.expected - vm.opening + typed
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.today == nil {
                ProgressView()
                    .tint(.sAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Form {
                    Section {
                        DatePicker("Day", selection: $date, displayedComponents: .date)
                    }

                    expectedSection
                    countSection

                    if !vm.recent.isEmpty {
                        Section("Earlier days") {
                            ForEach(vm.recent) { day in
                                dayRow(day)
                            }
                        }
                    }
                }
                .refreshable { await vm.load(date: date) }
            }
        }
        .navigationTitle("Cash closing")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load(date: date) }
        .onChange(of: date) { _ in
            counted = ""
            note = ""
            openingOverride = ""
            showOpeningField = false
            Task { await vm.load(date: date) }
        }
        .alert("Cash closing", isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Something went wrong")
        }
    }

    // The arithmetic, not just its answer. A shopkeeper who disagrees with the figure
    // needs to see which part they disagree with — and the single number this screen
    // used to show was wrong for anybody who keeps a float or pays a supplier in cash.
    private var expectedSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 1) {
                Text("Should be in the drawer")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if vm.loadFailed {
                    Text("Couldn't read this day")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Button("Try again") { Task { await vm.load(date: date) } }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.sAccent)
                        .buttonStyle(.borderless)
                } else if vm.today == nil {
                    // Loading. A placeholder rather than a zero, which would read as a
                    // day that genuinely took nothing.
                    Text("—")
                        .font(.title.bold())
                        .foregroundStyle(.secondary)
                } else {
                    Text(Money.text(liveExpected)).moneyLine()
                        .font(.title.bold())
                        .foregroundStyle(.primary)
                }
            }
            .padding(.vertical, 2)

            if vm.today != nil {
                breakdownRow("In the drawer this morning", openingValue, isOut: false)
                ForEach(vm.today?.cashIn ?? []) { line in
                    breakdownRow(line.label, line.amount, isOut: false, count: line.count)
                }
                ForEach(vm.today?.cashOut ?? []) { line in
                    breakdownRow(line.label, line.amount, isOut: true, count: line.count)
                }
            }

            if showOpeningField {
                HStack {
                    Text("₹").foregroundStyle(.secondary)
                    TextField("What was in it this morning", text: $openingOverride)
                        .keyboardType(.decimalPad)
                }
            }

            Button(showOpeningField ? "Use yesterday's figure" : "The float was different") {
                if showOpeningField { openingOverride = "" }
                showOpeningField.toggle()
            }
            .font(.subheadline)
            .foregroundStyle(Color.sAccent)
        } footer: {
            if vm.today != nil,
               (vm.today?.cashIn.isEmpty ?? true) && (vm.today?.cashOut.isEmpty ?? true) {
                Text("Nothing has gone in or out of the till today.")
            }
        }
    }

    /// One line of the drawer's arithmetic: what it was and which way it moved.
    private func breakdownRow(
        _ label: String, _ amount: Double, isOut: Bool, count: Int? = nil
    ) -> some View {
        LabeledContent {
            Text((isOut ? "− " : "+ ") + Money.text(amount)).moneyLine()
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isOut ? Color.sDestructive : Color.sForeground)
        } label: {
            Text(count.flatMap { $0 > 0 ? "\(label) (\($0))" : nil } ?? label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var countSection: some View {
        Section {
            HStack {
                Text("₹").foregroundStyle(.secondary)
                TextField(
                    vm.today?.closed == true
                        ? Money.text(vm.today?.counted_cash ?? 0)
                        : "What is actually in it",
                    text: $counted
                )
                .keyboardType(.decimalPad)
                .focused($countFocused)
            }

            TextField("Note (optional)", text: $note)

            Button {
                guard let value = countedValue else { return }
                countFocused = false
                Task {
                    if await vm.close(
                        date: date, counted: value,
                        opening: Double(openingOverride), note: note
                    ) {
                        counted = ""
                        note = ""
                        openingOverride = ""
                        showOpeningField = false
                    }
                }
            } label: {
                Text(vm.today?.closed == true ? "Save the new count" : "Close the day")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.sAccent)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            // Waits for the day's own figures. Counted against a stale or missing
            // expectation, a closing records a difference that was never real.
            .disabled(countedValue == nil || !vm.isReady(for: date))
        } header: {
            Text(vm.today?.closed == true ? "Counted" : "Count the drawer")
        } footer: {
            if let difference = liveDifference {
                Text(differenceText(difference))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(differenceColour(difference))
            } else if let today = vm.today, today.closed {
                VStack(alignment: .leading, spacing: 2) {
                    Text(today.differenceText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(differenceColour(today.difference))
                    if !today.note.isEmpty {
                        Text(today.note)
                    }
                }
            }
        }
    }

    private func dayRow(_ day: DayClosing) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(AppDate.text(fromWire: day.date))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text("\(Money.text(day.expected_cash)) expected · \(Money.text(day.counted_cash)) counted")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(day.differenceText)
                .font(.footnote.weight(.medium))
                .foregroundStyle(differenceColour(day.difference))
        }
    }

    private func differenceText(_ difference: Double) -> String {
        if difference < -0.004 { return "\(Money.text(abs(difference))) short" }
        if difference > 0.004 { return "\(Money.text(difference)) over" }
        return "Tallies exactly"
    }

    private func differenceColour(_ difference: Double) -> Color {
        if difference < -0.004 { return .sDestructive }
        if difference > 0.004 { return .sAccent }
        return .sSuccess
    }
}
