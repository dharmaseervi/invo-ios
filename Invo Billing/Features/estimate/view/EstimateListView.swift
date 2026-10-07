import SwiftUI

struct EstimateListView: View {
    @State private var showCreateEstimate = false
    @StateObject private var vm = EstimateViewModel()
    @State private var searchTask: Task<Void, Never>?

    /// Whether anything is being searched for, which decides whether an empty list
    /// reads as "no estimates yet" or "nothing matched".
    private var isSearching: Bool {
        !vm.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // The search box stays put. It used to be drawn only when estimates had
                // already loaded, so it appeared and disappeared as the list did — and
                // there was no way to clear a search that had returned nothing.
                searchBar.padding(.top, 16)

                if vm.isFetchingList && vm.estimates.isEmpty {
                    Spacer()
                    ProgressView().tint(.sAccent)
                    Spacer()
                } else if let error = vm.listError, vm.estimates.isEmpty {
                    // A failed load said "No estimates yet" to shops that have
                    // hundreds. It says what happened, and offers to go again.
                    failedState(error)
                } else if vm.estimates.isEmpty {
                    if isSearching { noResultsState } else { emptyState }
                } else {
                    ScrollView(showsIndicators: false) {
                        // Lazy, so a long list builds the rows it shows rather than all
                        // of them — and so the paging trigger near the bottom fires when
                        // the reader gets there instead of immediately on load.
                        LazyVStack(spacing: 10) {
                            ForEach(vm.estimates) { estimate in
                                NavigationLink {
                                    EstimateDetailView(estimateID: estimate.id, vm: vm)
                                } label: {
                                    EstimateRowCard(estimate: estimate)
                                }
                                .buttonStyle(.plain)
                                .task { await vm.loadMoreIfNeeded(currentEstimate: estimate) }
                            }

                            if vm.isLoadingMore {
                                ProgressView()
                                    .tint(.sAccent)
                                    .padding(.vertical, 12)
                            } else if vm.loadMoreFailed {
                                VStack(spacing: 6) {
                                    Text("Couldn't load more estimates.")
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
                    .refreshable { await vm.fetchEstimates() }
                    .overlay(alignment: .top) {
                        if vm.isFetchingList {
                            ProgressView()
                                .tint(.sAccent)
                                .scaleEffect(0.8)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(.top, 8)
                                .transition(.opacity)
                        }
                    }
                }
            }
        }
        .onChange(of: vm.searchQuery) { _, _ in
            // Debounced, so a six-letter name is one request rather than six.
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                await vm.fetchEstimates()
            }
        }
        .navigationTitle("Estimates")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreateEstimate = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        // Modal for the same reason invoice creation is: a multistep task, and with the
        // tab bar present someone could wander off mid-estimate.
        .fullScreenCover(isPresented: $showCreateEstimate) {
            NavigationStack { CreateEstimateView() }
        }
        #if DEBUG
        .onAppear {
            if UserDefaults.standard.string(forKey: "startScreen") == "newestimate" {
                showCreateEstimate = true
            }
        }
        #endif
        .task { await vm.fetchEstimates() }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.scaled(14))
                .foregroundColor(.sMutedFG)
            TextField("Search by number or customer", text: $vm.searchQuery)
                .font(.scaled(14))
                .foregroundColor(.sForeground)
                .tint(.sAccent)
                .autocorrectionDisabled()
            if !vm.searchQuery.isEmpty {
                Button { vm.searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.scaled(14))
                        .foregroundColor(.sMutedFG)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sInput, lineWidth: 0.5))
        .cornerRadius(8)
        .padding(.horizontal, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.badge.clock")
                .font(.scaled(40))
                .foregroundColor(.sMutedFG)
            VStack(spacing: 4) {
                Text("No estimates yet")
                    .font(.scaled(15, weight: .semibold))
                    .foregroundColor(.sForeground)
                Text("Send a quote before you bill — create your first estimate")
                    .font(.scaled(13))
                    .foregroundColor(.sMutedFG)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button { showCreateEstimate = true } label: {
                Text("Create estimate")
                    .font(.scaled(13, weight: .semibold))
                    .foregroundColor(.sAccentFG)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.sPrimary)
                    .cornerRadius(8)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.scaled(22))
                .foregroundColor(.sMutedFG)
            Text("No matching estimates")
                .font(.scaled(14, weight: .medium))
                .foregroundColor(.sForeground)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Shown when the list could not be loaded at all. Distinct from the empty state on
    /// purpose: "no estimates yet" and "we could not ask" are different answers, and
    /// only one of them is the shop's fault.
    private func failedState(_ message: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.scaled(28))
                .foregroundColor(.sDestructive)
            Text("Couldn't load estimates")
                .font(.scaled(14, weight: .medium))
                .foregroundColor(.sForeground)
            Text(message)
                .font(.scaled(13))
                .foregroundColor(.sMutedFG)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try again") { Task { await vm.fetchEstimates() } }
                .font(.scaled(13, weight: .medium))
                .foregroundColor(.sAccent)
                .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row
private struct EstimateRowCard: View {
    let estimate: EstimateResponse

    var statusConfig: (label: String, color: Color) {
        switch estimate.status {
        case .draft:     return ("Draft", Color(UIColor.systemGray))
        case .sent:      return ("Sent", .sAccent)
        case .accepted:  return ("Accepted", Color(red: 0.086, green: 0.639, blue: 0.341))
        case .rejected:  return ("Rejected", Color(red: 0.863, green: 0.149, blue: 0.149))
        case .expired:   return ("Expired", Color(red: 0.722, green: 0.494, blue: 0.051))
        case .converted: return ("Converted", Color(red: 0.086, green: 0.639, blue: 0.341))
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(statusConfig.color)
                .frame(width: 3)
                .padding(.vertical, 10)

            HStack(spacing: 12) {
                MinimalAvatarView(name: estimate.client_name ?? "?")

                VStack(alignment: .leading, spacing: 3) {
                    Text(estimate.client_name ?? "Client")
                        .font(.scaled(14, weight: .medium))
                        .foregroundColor(.sForeground)
                        .lineLimit(1)
                    // Side by side while they fit, stacked when they do not: at a large
                    // text size both halves crushed to "EST… · Se…", which identifies
                    // neither the estimate nor the date.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) {
                            Text(estimate.estimate_number)
                            Text("·")
                            Text(AppDate.text(fromWire: estimate.estimate_date))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(estimate.estimate_number)
                            Text(AppDate.text(fromWire: estimate.estimate_date))
                        }
                    }
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    Text(Money.text(estimate.total)).moneyLine()
                        .font(.scaled(14, weight: .semibold))
                        .foregroundColor(.sForeground)
                    Text(statusConfig.label)
                        .font(.scaled(10, weight: .medium))
                        .foregroundColor(statusConfig.color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(statusConfig.color.opacity(0.1)))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(14)
    }
}
