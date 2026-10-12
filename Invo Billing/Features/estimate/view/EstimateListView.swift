import SwiftUI

struct EstimateListView: View {
    @State private var showCreateEstimate = false
    @StateObject private var vm = EstimateViewModel()
    @State private var searchTask: Task<Void, Never>?

    private var isSearching: Bool {
        !vm.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        contentArea
            .onChange(of: vm.searchQuery) { _, _ in
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    await vm.fetchEstimates()
                }
            }
            .navigationTitle("Estimates")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $vm.searchQuery, prompt: "Search by number or customer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCreateEstimate = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
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

    @ViewBuilder
    private var contentArea: some View {
        if vm.isFetchingList && vm.estimates.isEmpty {
            VStack(spacing: 12) {
                ProgressView().tint(.sAccent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.listError, vm.estimates.isEmpty {
            VStack(spacing: 10) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundStyle(Color.sDestructive)
                Text("Couldn't load estimates")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button("Try again") { Task { await vm.fetchEstimates() } }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.sAccent)
                    .padding(.top, 4)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                if vm.estimates.isEmpty {
                    if isSearching {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("No matching estimates")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.badge.clock")
                                .font(.scaled(40))
                                .foregroundStyle(.secondary)
                            VStack(spacing: 4) {
                                Text("No estimates yet")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("Send a quote before you bill — create your first estimate")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                            Button { showCreateEstimate = true } label: {
                                Text("Create estimate")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.sAccentFG)
                                    .padding(.horizontal, AppSpacing.page)
                                    .padding(.vertical, 10)
                                    .background(Color.sPrimary)
                                    .cornerRadius(8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                } else {
                    ForEach(vm.estimates) { estimate in
                        NavigationLink {
                            EstimateDetailView(estimateID: estimate.id, vm: vm)
                        } label: {
                            EstimateRowCard(estimate: estimate)
                        }
                        .standardListRow()
                        .listRowSeparator(.hidden, edges: estimate.id == vm.estimates.first?.id ? .top : [])
                        .task { await vm.loadMoreIfNeeded(currentEstimate: estimate) }
                    }

                    if vm.isLoadingMore {
                        HStack { Spacer(); ProgressView().tint(.sAccent); Spacer() }
                            .padding(.vertical, 12)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    } else if vm.loadMoreFailed {
                        VStack(spacing: 6) {
                            Text("Couldn't load more estimates.")
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
            .refreshable { await vm.fetchEstimates() }
            .overlay(alignment: .top) {
                if vm.isFetchingList {
                    ProgressView()
                        .tint(.sAccent)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.opacity)
                }
            }
        }
    }
}

// MARK: - Row
private struct EstimateRowCard: View {
    let estimate: EstimateResponse

    var statusConfig: (label: String, color: Color) {
        switch estimate.status {
        case .draft:     return ("Draft", .sNeutral)
        case .sent:      return ("Sent", .sAccent)
        case .accepted:  return ("Accepted", .sSuccess)
        case .rejected:  return ("Rejected", .sDestructive)
        case .expired:   return ("Expired", .sWarning)
        case .converted: return ("Converted", .sSuccess)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            MinimalAvatarView(name: estimate.client_name ?? "?")

            VStack(alignment: .leading, spacing: 3) {
                Text(estimate.client_name ?? "Client")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        Text(estimate.estimate_number)
                        Text("·")
                        Text(AppDate.text(fromWire: estimate.estimate_date))
                    }
                    HStack(spacing: 6) {
                        Text(estimate.estimate_number)
                        Text("·")
                        Text(AppDate.shortText(fromWire: estimate.estimate_date))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(estimate.estimate_number)
                        Text(AppDate.text(fromWire: estimate.estimate_date))
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text(Money.text(estimate.total)).moneyLine()
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(statusConfig.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusConfig.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(statusConfig.color.opacity(0.1)))
            }
            .frame(minWidth: 88, alignment: .trailing)
        }
    }
}
