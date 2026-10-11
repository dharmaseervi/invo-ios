import SwiftUI

struct LedgerListView: View {

    @StateObject private var vm: LedgerViewModel
    @Environment(\.dismiss) var dismiss

    init(clientID: Int) {
        _vm = StateObject(
            wrappedValue: LedgerViewModel(clientID: clientID)
        )
    }

    var body: some View {
        List {
            summaryCard
                .padding(.horizontal, AppSpacing.page)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if vm.isLoading {
                HStack { Spacer(); ProgressView().tint(.sAccent); Spacer() }
                    .padding(.vertical, 60)
                    .listRowSeparator(.hidden)
            } else if vm.entries.isEmpty {
                ContentUnavailableView(
                    "No transactions yet",
                    systemImage: "book",
                    description: Text("Invoices, payments, and credit notes for this client will appear here")
                )
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                // Older entries load upwards: the statement reads forwards, so the
                // newest page is the one shown first.
                Group {
                    if vm.isLoadingMore {
                        HStack { Spacer(); ProgressView().tint(.sAccent); Spacer() }
                    } else if vm.loadMoreFailed {
                        VStack(spacing: 6) {
                            Text("Couldn't load earlier entries.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Try again") { Task { await vm.retryLoadMore() } }
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.sAccent)
                        }
                        .frame(maxWidth: .infinity)
                    } else if vm.hasMore {
                        Button("Load earlier entries") {
                            Task { await vm.loadEarlier() }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.sAccent)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 4)
                .listRowSeparator(.hidden)

                ForEach(vm.entries) { entry in
                    LedgerRowView(entry: entry)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden, edges: entry.id == vm.entries.first?.id ? .top : [])
                }
            }
        }
        .listStyle(.plain)
        .contentMargins(.bottom, 16, for: .scrollContent)
        .refreshable { await vm.fetchLedger() }
        .onAppear {
            Task { await vm.fetchLedger() }
        }
        .navigationTitle("Ledger details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // The statement to send the customer. On this screen because this is
                // where somebody is standing when the customer rings up to say they
                // have paid everything.
                NavigationLink {
                    StatementShareView(
                        clientID: vm.clientID,
                        clientName: vm.entries.first?.clientName ?? "Customer"
                    )
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.sAccent)
                }
                .disabled(vm.entries.isEmpty)
            }
        }
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Something went wrong")
        }
    }

    // The figures are the customer's whole history, so when they cannot be fetched the
    // screen says so rather than showing ₹0 totals above a page of real entries.
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Closing balance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(vm.summaryFailed ? "—" : Money.text(vm.closingBalance)).moneyLine()
                    .font(.title.bold())
                    .foregroundStyle(vm.summaryFailed ? .secondary
                                     : (vm.closingBalance > 0 ? Color.sDestructive : Color.sSuccess))
                if vm.summaryFailed {
                    Button("Totals unavailable — retry") { Task { await vm.fetchLedger() } }
                        .font(.footnote)
                        .tint(Color.sAccent)
                }
            }

            Divider()

            AdaptiveStatRow(stats: [
                .init(label: "Total debit",
                      value: vm.summaryFailed ? "—" : Money.text(vm.totalDebit),
                      color: vm.summaryFailed ? .sForeground : .sDestructive),
                .init(label: "Total credit",
                      value: vm.summaryFailed ? "—" : Money.text(vm.totalCredit),
                      color: vm.summaryFailed ? .sForeground : .sSuccess)
            ])
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}


struct LedgerRowView: View {

    let entry: LedgerEntryModel

    private var titleText: String {
        switch entry.sourceType {
        case .invoice: return "Invoice"
        case .payment: return "Payment"
        case .creditNote: return "Credit Note"
        case .opening: return "Opening"
        case .adjustment: return "Adjustment"
        // A source type this version does not know about. The description beneath says
        // what it was, so the row is still readable.
        case .other: return "Entry"
        }
    }

    private var amountText: String {
        if entry.debit > 0 {
            return "+\(Money.text(entry.debit))"
        } else {
            return Money.text(-entry.credit)
        }
    }

    private var amountColor: Color {
        entry.debit > 0 ? .sDestructive : .sSuccess
    }

    private var subtitle: String {
        var parts = [AppDate.text(entry.createdAt)]
        if let desc = entry.description, !desc.isEmpty { parts.append(desc) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(titleText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(amountText).moneyLine()
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(amountColor)
                Text("Bal \(Money.text(entry.balance))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 88, alignment: .trailing)
        }
    }
}
