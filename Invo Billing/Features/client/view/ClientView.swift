import SwiftUI

struct ClientView: View {
    #if DEBUG
    @State private var debugDetail = false
    #endif
    @StateObject var vm = ClientViewModel()
    @EnvironmentObject var session: SessionManager

    @State private var searchTask: Task<Void, Never>?

    var filteredClients: [ClientModel] { vm.clients }

    var body: some View {
        NavigationStack {
            contentArea
                .navigationTitle("Clients")
                .searchable(text: $vm.searchText, prompt: "Search clients")
                .onChange(of: vm.searchText) {
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        guard !Task.isCancelled else { return }
                        await vm.loadClients()
                    }
                }
                #if DEBUG
                .navigationDestination(isPresented: $debugDetail) {
                    if let first = filteredClients.first { ClientDetailedView(client: first) }
                }
                .onChange(of: filteredClients.count) {
                    if UserDefaults.standard.string(forKey: "startScreen") == "clientdetail",
                       !filteredClients.isEmpty { debugDetail = true }
                }
                #endif
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink { ClientFormView() } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .task { await vm.loadClients() }
                .onChange(of: SessionManager.shared.selectedCompanyId) {
                    Task { await vm.loadClients() }
                }
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if vm.isLoading && vm.clients.isEmpty {
            VStack(spacing: 12) {
                ProgressView().tint(Color.sAccent)
                Text("Loading clients...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.errorMessage {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundStyle(Color.sDestructive)
                        Text("Couldn't load clients")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                        Button("Try again") {
                            Task { await vm.loadClients() }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.sAccent)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                    .padding(24)
                }
                .refreshable { await vm.loadClients() }
            }
        } else {
            List {
                let quickSaleClients = filteredClients.filter { $0.isQuickSaleAccount }
                let regularClients   = filteredClients.filter { !$0.isQuickSaleAccount }

                if filteredClients.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.scaled(40))
                            .foregroundStyle(.secondary)
                        VStack(spacing: 4) {
                            Text(vm.searchText.isEmpty ? "No clients" : "No results")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(vm.searchText.isEmpty
                                 ? "Add your first client to get started"
                                 : "Try a different search")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        if vm.searchText.isEmpty {
                            NavigationLink(destination: ClientFormView()) {
                                Text("Add client")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.sAccentFG)
                                    .padding(.horizontal, AppSpacing.page)
                                    .padding(.vertical, 10)
                                    .background(Color.sPrimary)
                                    .clipShape(.rect(cornerRadius: 8))
                            }
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                } else {
                    if !quickSaleClients.isEmpty {
                        Section("Quick-sale accounts") {
                            ForEach(quickSaleClients) { client in
                                NavigationLink {
                                    ClientDetailedView(client: client)
                                } label: {
                                    ClientListRowView(client: client)
                                }
                                .standardListRow()
                                .listRowSeparator(.hidden, edges: client.id == quickSaleClients.first?.id ? .top : [])
                            }
                        }
                    }

                    if !regularClients.isEmpty {
                        Section {
                            ForEach(regularClients) { client in
                                NavigationLink {
                                    ClientDetailedView(client: client)
                                } label: {
                                    ClientListRowView(client: client)
                                }
                                .standardListRow()
                                .listRowSeparator(.hidden, edges: client.id == regularClients.first?.id && quickSaleClients.isEmpty ? .top : [])
                                .task {
                                    if client.id == vm.clients.suffix(5).first?.id {
                                        await vm.loadMoreClients()
                                    }
                                }
                            }

                            if vm.isLoadingMoreClients {
                                HStack { Spacer(); ProgressView().tint(Color.sAccent); Spacer() }
                                    .padding(.vertical, 12)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            } else if vm.loadMoreClientsFailed {
                                VStack(spacing: 6) {
                                    Text("Couldn't load more customers.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Button("Try again") {
                                        Task { await vm.retryLoadMoreClients() }
                                    }
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.sAccent)
                                }
                                .padding(.vertical, 12)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .contentMargins(.bottom, 16, for: .scrollContent)
            .refreshable { await vm.loadClients() }
            .overlay(alignment: .top) {
                if vm.isLoading && !vm.clients.isEmpty {
                    ProgressView()
                        .tint(Color.sAccent)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.opacity)
                }
            }
        }
    }
}

// MARK: - Client List Row View
struct ClientListRowView: View {
    let client: ClientModel

    var body: some View {
        HStack(spacing: 12) {
            if let account = client.quickSaleAccount {
                Image(systemName: account.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.sAccent)
                    .frame(width: 40, height: 40)
                    .background(Color.sAccentMuted, in: Circle())
                    .accessibilityHidden(true)
            } else {
                MinimalAvatarView(name: client.name)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(client.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                if !client.phone.isEmpty {
                    Text(client.phone)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .alignmentGuide(.listRowSeparatorLeading) { _ in 52 }
    }
}

// MARK: - Minimal Avatar View
/// The client initials shown beside a name, everywhere one appears.
///
/// There used to be two of these — a tinted circle with two initials on invoices, a
/// solid violet square with one initial on estimates — for the same data on adjacent
/// screens. This is the circle: lighter in a long list, and two letters tell "Sanjay"
/// from "Sanya" where one cannot.
struct MinimalAvatarView: View {
    @ScaledMetric(relativeTo: .body) private var scaledBase: CGFloat = 40
    let name: String
    var size: CGFloat = 40

    private var initials: String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.sAccentMuted)
                .frame(width: size * scaledBase / 40, height: size * scaledBase / 40)
            Text(initials)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.sAccent)
        }
    }
}
