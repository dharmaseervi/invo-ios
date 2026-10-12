import SwiftUI

struct LedgerView: View {

    @StateObject private var vm = LedgerListViewModel()
    /// Tracked rather than guessed from an empty list: a search that matched nothing
    /// leaves the list empty, and inferring it would take the search box away again.
    @State private var hasLoadedOnce = false

    private var isFirstLoad: Bool { vm.isLoading && !hasLoadedOnce }

    var body: some View {
        Group {
            Group {
                // Once the first load is done the summary and the search box stay
                // mounted, whatever the rows are doing — empty, loading, or being
                // searched. Everything else renders underneath them.
                //
                // Each earlier version of this took the field away at a different
                // moment: first on every keystroke, then on an empty box with an
                // empty list, which is the state during the debounce right after a
                // no-results search is cleared.
                if isFirstLoad {
                    ProgressView()
                        .tint(.sAccent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        summaryCard
                            .listHeaderRow()

                        if vm.isLoading {
                            HStack { Spacer(); ProgressView().tint(.sAccent); Spacer() }
                                .padding(.vertical, 60)
                                .listRowSeparator(.hidden)
                        } else if vm.filteredClients.isEmpty {
                            // "No customers yet" when there is genuinely nothing, "no
                            // matches" when a search found nothing — both below the
                            // search box, which stays where it is either way.
                            Group {
                                if vm.searchText.isEmpty {
                                    emptyState
                                } else {
                                    ContentUnavailableView.search(text: vm.searchText)
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } else {
                            ForEach(vm.filteredClients) { client in
                                NavigationLink {
                                    LedgerListView(clientID: client.clientID)
                                } label: {
                                    LedgerRow(client: client)
                                }
                                .standardListRow()
                                .listRowSeparator(.hidden, edges: client.id == vm.filteredClients.first?.id ? .top : [])
                                .task { await vm.loadMoreIfNeeded(currentItem: client) }
                            }

                            if vm.isLoadingMore {
                                HStack { Spacer(); ProgressView().tint(.sAccent); Spacer() }
                                    .padding(.vertical, 12)
                                    .listRowSeparator(.hidden)
                            } else if vm.loadMoreFailed {
                                VStack(spacing: 6) {
                                    Text("Couldn't load more customers.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Button("Try again") { Task { await vm.retryLoadMore() } }
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.sAccent)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .contentMargins(.bottom, 16, for: .scrollContent)
                    .refreshable { await vm.fetchCompanyLedger() }
                }
            }
            .searchable(text: $vm.searchText, prompt: "Search clients")
            .navigationTitle("Ledger")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await vm.fetchCompanyLedger()
                    hasLoadedOnce = true
                }
            }
            // The search box asks the server, debounced — it used to filter only the
            // customers whose entries happened to have been downloaded.
            .task(id: vm.searchText) {
                // Only skip the run before the first load, which onAppear performs.
                // The old guard also skipped an empty box with an empty list — the
                // state after clearing a search that matched nothing — so the full
                // list never came back.
                guard hasLoadedOnce else { return }
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                await vm.fetchCompanyLedger()
                hasLoadedOnce = true
            }
            .alert("Error", isPresented: $vm.showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "Something went wrong")
            }
        }
    }

    // MARK: - Summary Card
    private var summaryCard: some View {
        // A dash when the figure could not be fetched: ₹0 reads as "nobody owes
        // anything", which is the opposite of "we could not check".
        SummaryCard(
            title: "Total receivable",
            value: vm.totalsFailed ? "—" : Money.text(vm.totalReceivable),
            valueColor: vm.totalsFailed ? .sMutedFG
                : (vm.totalReceivable > 0 ? .sDestructive : .sSuccess)
        ) {
            if vm.totalsFailed {
                Button("Totals unavailable — retry") {
                    Task { await vm.fetchCompanyLedger() }
                }
                .font(.footnote)
                .tint(Color.sAccent)
            } else {
                // Every customer with history, counted by the server — not the rows
                // that happen to be loaded.
                Text("Across \(vm.totals.clients) client\(vm.totals.clients == 1 ? "" : "s")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if vm.totalPayable > 0 {
                    // Advances and credit balances, which netting into the receivable
                    // would hide.
                    Text("\(Money.text(vm.totalPayable)) in customer credit")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        ContentUnavailableView(
            "No ledger activity yet",
            systemImage: "book",
            description: Text("Client balances will show up here once invoices or payments are recorded")
        )
        .padding(.vertical, 40)
    }
}

struct LedgerRow: View {

    let client: ClientLedger

    private var balanceColor: Color {
        client.balance > 0 ? .sDestructive : .sSuccess
    }

    private var balanceLabel: String {
        if client.balance == 0 { return "Settled" }
        return client.balance > 0 ? "Receivable" : "Advance"
    }

    var body: some View {
        HStack(spacing: 12) {
            MinimalAvatarView(name: client.clientName)

            VStack(alignment: .leading, spacing: 3) {
                Text(client.clientName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(balanceLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }

            Spacer(minLength: 8)

            Text(Money.text(abs(client.balance))).moneyLine()
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(client.balance == 0 ? Color.sForeground : balanceColor)
                .frame(minWidth: 88, alignment: .trailing)
        }
    }
}
