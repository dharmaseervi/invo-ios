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
        ZStack {
            Color.sBackground.ignoresSafeArea()

            if vm.isLoading && vm.today == nil {
                ProgressView().tint(.sAccent)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        expectedCard
                        countCard

                        if !vm.recent.isEmpty {
                            Text("Earlier days")
                                .font(.scaled(13, weight: .medium))
                                .foregroundColor(.sMutedFG)
                                .padding(.top, 6)

                            ForEach(vm.recent) { day in
                                dayCard(day)
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
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

    private var expectedCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            DatePicker("Day", selection: $date, displayedComponents: .date)
                .font(.scaled(13))

            Divider().padding(.vertical, 8)

            Text("Should be in the drawer")
                .font(.scaled(13))
                .foregroundColor(.sMutedFG)

            if vm.loadFailed {
                Text("Couldn't read this day")
                    .font(.scaled(20, weight: .semibold))
                    .foregroundColor(.sMutedFG)
                Button("Try again") { Task { await vm.load(date: date) } }
                    .font(.scaled(13, weight: .medium))
                    .foregroundColor(.sAccent)
            } else if vm.today == nil {
                // Loading. A placeholder rather than a zero, which would read as a
                // day that genuinely took nothing.
                Text("—")
                    .font(.scaled(26, weight: .bold))
                    .foregroundColor(.sMutedFG)
            } else {
                Text(Money.text(liveExpected)).moneyLine()
                    .font(.scaled(26, weight: .bold))
                    .foregroundColor(.sForeground)
            }

            // The arithmetic, not just its answer. A shopkeeper who disagrees with the
            // figure needs to see which part they disagree with — and the single
            // number this screen used to show was wrong for anybody who keeps a float
            // or pays a supplier in cash.
            if vm.today != nil {
            VStack(spacing: 6) {
                breakdownRow("In the drawer this morning", openingValue, isOut: false)

                ForEach(vm.today?.cashIn ?? []) { line in
                    breakdownRow(line.label, line.amount, isOut: false, count: line.count)
                }
                ForEach(vm.today?.cashOut ?? []) { line in
                    breakdownRow(line.label, line.amount, isOut: true, count: line.count)
                }

                if (vm.today?.cashIn.isEmpty ?? true) && (vm.today?.cashOut.isEmpty ?? true) {
                    Text("Nothing has gone in or out of the till today.")
                        .font(.scaled(12))
                        .foregroundColor(.sMutedFG)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 10)
            }

            Button(showOpeningField ? "Use yesterday's figure" : "The float was different") {
                if showOpeningField { openingOverride = "" }
                showOpeningField.toggle()
            }
            .font(.scaled(12, weight: .medium))
            .foregroundColor(.sAccent)
            .padding(.top, 2)

            if showOpeningField {
                HStack {
                    Text("₹")
                        .font(.scaled(15))
                        .foregroundColor(.sMutedFG)
                    TextField("What was in it this morning", text: $openingOverride)
                        .keyboardType(.decimalPad)
                        .font(.scaled(15))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.sBackground)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sInput, lineWidth: 0.5))
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(16)
    }

    /// One line of the drawer's arithmetic: what it was and which way it moved.
    private func breakdownRow(
        _ label: String, _ amount: Double, isOut: Bool, count: Int? = nil
    ) -> some View {
        HStack {
            Text(count.flatMap { $0 > 0 ? "\(label) (\($0))" : nil } ?? label)
                .font(.scaled(12))
                .foregroundColor(.sMutedFG)
            Spacer()
            Text((isOut ? "− " : "+ ") + Money.text(amount))
                .font(.scaled(12, weight: .medium))
                .foregroundColor(isOut ? .sDestructive : .sForeground)
        }
    }

    private var countCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(vm.today?.closed == true ? "Counted" : "Count the drawer")
                .font(.scaled(13, weight: .medium))
                .foregroundColor(.sMutedFG)

            HStack {
                Text("₹")
                    .font(.scaled(17))
                    .foregroundColor(.sMutedFG)
                TextField(
                    vm.today?.closed == true
                        ? Money.text(vm.today?.counted_cash ?? 0)
                        : "What is actually in it",
                    text: $counted
                )
                .keyboardType(.decimalPad)
                .font(.scaled(17))
                .focused($countFocused)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.sBackground)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sInput, lineWidth: 0.5))
            .cornerRadius(8)

            if let difference = liveDifference {
                Text(differenceText(difference))
                    .font(.scaled(13, weight: .medium))
                    .foregroundColor(differenceColour(difference))
            } else if let today = vm.today, today.closed {
                Text(today.differenceText)
                    .font(.scaled(13, weight: .medium))
                    .foregroundColor(differenceColour(today.difference))
                if !today.note.isEmpty {
                    Text(today.note)
                        .font(.scaled(12))
                        .foregroundColor(.sMutedFG)
                }
            }

            TextField("Note (optional)", text: $note)
                .font(.scaled(14))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.sBackground)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sInput, lineWidth: 0.5))
                .cornerRadius(8)

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
                    .font(.scaled(15, weight: .semibold))
                    .foregroundColor(.sAccentFG)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        countedValue == nil || !vm.isReady(for: date)
                            ? Color.sPrimary.opacity(0.4)
                            : Color.sPrimary
                    )
                    .cornerRadius(10)
            }
            // Waits for the day's own figures. Counted against a stale or missing
            // expectation, a closing records a difference that was never real.
            .disabled(countedValue == nil || !vm.isReady(for: date))
        }
        .padding(18)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(16)
    }

    private func dayCard(_ day: DayClosing) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppDate.text(fromWire: day.date))
                    .font(.scaled(14, weight: .medium))
                    .foregroundColor(.sForeground)
                Text("\(Money.text(day.expected_cash)) expected · \(Money.text(day.counted_cash)) counted")
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
            }
            Spacer()
            Text(day.differenceText)
                .font(.scaled(12, weight: .medium))
                .foregroundColor(differenceColour(day.difference))
        }
        .padding(14)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(14)
    }

    private func differenceText(_ difference: Double) -> String {
        if difference < -0.004 { return "\(Money.text(abs(difference))) short" }
        if difference > 0.004 { return "\(Money.text(difference)) over" }
        return "Tallies exactly"
    }

    private func differenceColour(_ difference: Double) -> Color {
        if difference < -0.004 { return .sDestructive }
        if difference > 0.004 { return .sAccent }
        return Color(red: 0.086, green: 0.639, blue: 0.341)
    }
}
