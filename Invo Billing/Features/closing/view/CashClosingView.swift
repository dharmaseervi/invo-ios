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
    @FocusState private var countFocused: Bool

    private var countedValue: Double? { Double(counted) }

    /// The difference as it is being typed, before anything is saved — so a wrong digit
    /// shows itself while the money is still on the table.
    private var liveDifference: Double? {
        guard let value = countedValue else { return nil }
        return value - vm.expected
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

            Text("Cash taken, by the books")
                .font(.scaled(13))
                .foregroundColor(.sMutedFG)
            Text(Money.text(vm.expected)).moneyLine()
                .font(.scaled(26, weight: .bold))
                .foregroundColor(.sForeground)
            Text(paymentCountText)
                .font(.scaled(12))
                .foregroundColor(.sMutedFG)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(16)
    }

    private var paymentCountText: String {
        let count = vm.today?.payment_count ?? 0
        if count == 0 { return "No cash payments recorded for this day" }
        return "From \(count) cash payment\(count == 1 ? "" : "s")"
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
                    if await vm.close(date: date, counted: value, note: note) {
                        counted = ""
                        note = ""
                    }
                }
            } label: {
                Text(vm.today?.closed == true ? "Save the new count" : "Close the day")
                    .font(.scaled(15, weight: .semibold))
                    .foregroundColor(.sAccentFG)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(countedValue == nil ? Color.sPrimary.opacity(0.4) : Color.sPrimary)
                    .cornerRadius(10)
            }
            .disabled(countedValue == nil || vm.isWorking)
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
