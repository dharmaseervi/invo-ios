//
//  ProfitLossView.swift
//  Invo Billing
//
//  Revenue, purchases and expenses in one place — the three numbers every owner
//  wants before they ask their CA anything.
//

import SwiftUI

struct ProfitLossView: View {
    @StateObject private var vm = ProfitLossViewModel()

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            if vm.isLoading && vm.report == nil {
                ProgressView().tint(.sAccent)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        periodPicker

                        if let r = vm.report {
                            profitCard(r)
                            breakdownSection(r)
                            countsSection(r)
                        } else if !vm.isLoading {
                            emptyState
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                .refreshable { await vm.load() }
                .overlay(alignment: .top) {
                    if vm.isLoading {
                        ProgressView()
                            .tint(.sAccent)
                            .padding(.top, 8)
                    }
                }
            }
        }
        .navigationTitle("Profit & Loss")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .onChange(of: vm.selectedPeriod) { _, _ in Task { await vm.load() } }
        .alert("Report", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Something went wrong")
        }
    }

    // MARK: - Period picker

    private var periodPicker: some View {
        Picker("Period", selection: $vm.selectedPeriod) {
            ForEach(ProfitLossViewModel.Period.allCases) { p in
                Text(p.label).tag(p)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Main profit card

    private func profitCard(_ r: ProfitLossResponse) -> some View {
        let isLoss = r.net_profit < -0.004
        return VStack(alignment: .leading, spacing: 8) {
            Text(isLoss ? "Net loss" : "Net profit")
                .font(.scaled(13))
                .foregroundColor(.sMutedFG)

            Text(Money.text(abs(r.net_profit))).moneyLine()
                .font(.scaled(32, weight: .bold))
                .foregroundColor(isLoss ? .sDestructive : Color(red: 0.086, green: 0.639, blue: 0.341))

            if r.revenue > 0 {
                Text("\(String(format: "%.1f", r.net_margin_pct))% net margin · \(String(format: "%.1f", r.gross_margin_pct))% gross margin")
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
            }

            Text(periodLabel(r))
                .font(.scaled(11))
                .foregroundColor(.sMutedFG)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(16)
    }

    // MARK: - Revenue / purchases / expenses breakdown

    private func breakdownSection(_ r: ProfitLossResponse) -> some View {
        VStack(spacing: 0) {
            breakdownRow(
                icon: "arrow.down.circle.fill",
                iconColor: Color(red: 0.086, green: 0.639, blue: 0.341),
                label: "Revenue",
                detail: "\(r.invoice_count) invoice\(r.invoice_count == 1 ? "" : "s")",
                amount: r.revenue,
                amountColor: Color(red: 0.086, green: 0.639, blue: 0.341),
                sign: "+"
            )
            rowDivider()
            breakdownRow(
                icon: "shippingbox.fill",
                iconColor: .sDestructive,
                label: "Purchases",
                detail: "\(r.bill_count) bill\(r.bill_count == 1 ? "" : "s")",
                amount: r.purchases,
                amountColor: .sDestructive,
                sign: "−"
            )
            rowDivider()

            // Gross profit line
            HStack {
                Text("Gross profit")
                    .font(.scaled(13, weight: .medium))
                    .foregroundColor(.sForeground)
                Spacer()
                Text(Money.text(abs(r.gross_profit))).moneyLine()
                    .font(.scaled(13, weight: .semibold))
                    .foregroundColor(r.gross_profit < -0.004 ? .sDestructive : .sForeground)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.sCard.opacity(0.5))

            rowDivider()
            breakdownRow(
                icon: "banknote.fill",
                iconColor: Color(UIColor.systemOrange),
                label: "Expenses",
                detail: "\(r.expense_count) item\(r.expense_count == 1 ? "" : "s")",
                amount: r.expenses,
                amountColor: .sDestructive,
                sign: "−"
            )
        }
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(14)
    }

    private func breakdownRow(
        icon: String,
        iconColor: Color,
        label: String,
        detail: String,
        amount: Double,
        amountColor: Color,
        sign: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.scaled(15))
                .foregroundColor(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.scaled(14, weight: .medium))
                    .foregroundColor(.sForeground)
                Text(detail)
                    .font(.scaled(11))
                    .foregroundColor(.sMutedFG)
            }

            Spacer()

            Text(sign + Money.text(amount)).moneyLine()
                .font(.scaled(14, weight: .semibold))
                .foregroundColor(amountColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func rowDivider() -> some View {
        Rectangle()
            .fill(Color.sBorder)
            .frame(height: 0.5)
            .padding(.leading, 52)
    }

    // MARK: - Transaction counts

    private func countsSection(_ r: ProfitLossResponse) -> some View {
        HStack(spacing: 12) {
            countCard(value: r.invoice_count, label: "Invoices")
            countCard(value: r.bill_count, label: "Bills")
            countCard(value: r.expense_count, label: "Expenses")
        }
    }

    private func countCard(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.scaled(20, weight: .bold))
                .foregroundColor(.sForeground)
            Text(label)
                .font(.scaled(11))
                .foregroundColor(.sMutedFG)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func periodLabel(_ r: ProfitLossResponse) -> String {
        "\(AppDate.shortText(fromWire: r.from)) – \(AppDate.shortText(fromWire: r.to))"
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.scaled(30))
                .foregroundColor(.sMutedFG)
            Text("No data for this period")
                .font(.scaled(15, weight: .medium))
                .foregroundColor(.sForeground)
            Text("Record invoices, bills and expenses and they will appear here.")
                .font(.scaled(12))
                .foregroundColor(.sMutedFG)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
