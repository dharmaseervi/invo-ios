import SwiftUI

struct LedgerView: View {

    @StateObject private var vm = LedgerListViewModel()
    /// Tracked rather than guessed from an empty list: a search that matched nothing
    /// leaves the list empty, and inferring it would take the search box away again.
    @State private var hasLoadedOnce = false

    private var isFirstLoad: Bool { vm.isLoading && !hasLoadedOnce }

    var body: some View {
        Group {
            ZStack {
                Color.sBackground.ignoresSafeArea()

                VStack(spacing: 0) {

                    // The search box and the summary stay on screen while a search
                    // runs, and while it finds nothing. They used to sit inside the
                    // branch that the spinner and the empty state replaced, so typing
                    // tore the field away mid-search — and a search that matched
                    // nothing left "No ledger activity yet" with no way to clear it.
                    if isFirstLoad {
                        Spacer()
                        ProgressView().tint(.sAccent)
                        Spacer()
                    } else if vm.clients.isEmpty && vm.searchText.isEmpty && !vm.isLoading {
                        emptyState
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                summaryCard.padding(.top, 16)

                                // MARK: Search
                                HStack(spacing: 10) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.scaled(14))
                                        .foregroundColor(.sMutedFG)

                                    TextField("Search clients", text: $vm.searchText)
                                        .font(.scaled(14))
                                        .foregroundColor(.sForeground)
                                        .tint(.sAccent)
                                        .autocorrectionDisabled()

                                    if !vm.searchText.isEmpty {
                                        Button { vm.searchText = "" } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.scaled(14))
                                                .foregroundColor(.sMutedFG)
                                        }
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.sCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.sInput, lineWidth: 0.5)
                                )
                                .cornerRadius(8)
                                .padding(.horizontal, 20)
                                .padding(.top, 16)

                                if vm.isLoading {
                                    ProgressView()
                                        .tint(.sAccent)
                                        .frame(minHeight: 240)
                                } else if vm.filteredClients.isEmpty {
                                    noResultsState.padding(.top, 60)
                                } else {
                                    LazyVStack(spacing: 10) {
                                        ForEach(vm.filteredClients) { client in
                                            NavigationLink {
                                                LedgerListView(clientID: client.clientID)
                                            } label: {
                                                LedgerRow(client: client)
                                            }
                                            .buttonStyle(.plain)
                                            .task { await vm.loadMoreIfNeeded(currentItem: client) }
                                        }

                                        if vm.isLoadingMore {
                                            ProgressView()
                                                .tint(.sAccent)
                                                .padding(.vertical, 12)
                                        } else if vm.loadMoreFailed {
                                            VStack(spacing: 6) {
                                                Text("Couldn't load more customers.")
                                                    .font(.scaled(13))
                                                    .foregroundColor(.sMutedFG)
                                                Button("Try again") { Task { await vm.retryLoadMore() } }
                                                    .font(.scaled(13, weight: .medium))
                                                    .foregroundColor(.sAccent)
                                            }
                                            .padding(.vertical, 12)
                                        }
                                    }
                                    .padding(20)
                                }
                            }
                        }
                    }
                }
            }
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
        VStack(alignment: .leading, spacing: 6) {
            Text("Total receivable")
                .font(.scaled(13))
                .foregroundColor(.sMutedFG)
            // A dash when the figure could not be fetched: ₹0 reads as "nobody owes
            // anything", which is the opposite of "we could not check".
            Text(vm.totalsFailed ? "—" : Money.text(vm.totalReceivable)).moneyLine()
                .font(.scaled(26, weight: .bold))
                .foregroundColor(
                    vm.totalsFailed ? .sMutedFG
                        : (vm.totalReceivable > 0 ? .sDestructive : Color(red: 0.086, green: 0.639, blue: 0.341))
                )
            if vm.totalsFailed {
                Button("Totals unavailable — retry") {
                    Task { await vm.fetchCompanyLedger() }
                }
                .font(.scaled(12))
                .foregroundColor(.sAccent)
            } else {
                // Every customer with history, counted by the server — not the rows
                // that happen to be loaded.
                Text("Across \(vm.totals.clients) client\(vm.totals.clients == 1 ? "" : "s")")
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
                if vm.totalPayable > 0 {
                    // Advances and credit balances, which netting into the receivable
                    // would hide.
                    Text("\(Money.text(vm.totalPayable)) in customer credit")
                        .font(.scaled(12))
                        .foregroundColor(.sMutedFG)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }

    // MARK: - Empty States
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.sMuted)
                    .overlay(Circle().stroke(Color.sBorder, lineWidth: 0.5))
                    .frame(width: 60, height: 60)
                Image(systemName: "book")
                    .font(.scaled(22))
                    .foregroundColor(.sMutedFG)
            }
            Text("No ledger activity yet")
                .font(.scaled(15, weight: .medium))
                .foregroundColor(.sForeground)
            Text("Client balances will show up here once invoices or payments are recorded")
                .font(.scaled(13))
                .foregroundColor(.sMutedFG)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.scaled(22))
                .foregroundColor(.sMutedFG)
            Text("No matching clients")
                .font(.scaled(14, weight: .medium))
                .foregroundColor(.sForeground)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LedgerRow: View {

    let client: ClientLedger

    private var initials: String {
        let parts = client.clientName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(client.clientName.prefix(2)).uppercased()
    }

    private var balanceColor: Color {
        client.balance > 0 ? .sDestructive : Color(red: 0.086, green: 0.639, blue: 0.341)
    }

    private var balanceLabel: String {
        if client.balance == 0 { return "Settled" }
        return client.balance > 0 ? "Receivable" : "Advance"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.sAccentMuted)
                    .frame(width: 40, height: 40)
                Text(initials)
                    .font(.scaled(13, weight: .semibold))
                    .foregroundColor(.sAccent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(client.clientName)
                    .font(.scaled(14, weight: .medium))
                    .foregroundColor(.sForeground)
                Text(balanceLabel)
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(Money.text(abs(client.balance))).moneyLine()
                    .font(.scaled(14, weight: .semibold))
                    .foregroundColor(client.balance == 0 ? .sForeground : balanceColor)
                Image(systemName: "chevron.right")
                    .font(.scaled(11, weight: .semibold))
                    .foregroundColor(.sMutedFG)
            }
        }
        .padding(14)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(12)
    }
}
