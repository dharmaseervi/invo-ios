import SwiftUI

struct ClientView: View {
    #if DEBUG
    @State private var debugDetail = false
    #endif
    @StateObject var vm = ClientViewModel()
    @EnvironmentObject var session: SessionManager

    /// Searching is the server's job: filtering here only ever matched the customers
    /// that happened to be on the loaded page, so a shop with three thousand customers
    /// could not find half of them.
    @State private var searchTask: Task<Void, Never>?

    var filteredClients: [ClientModel] { vm.clients }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sBackground.ignoresSafeArea()

                VStack(spacing: 0) {

                    // MARK: - Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.scaled(14))
                            .foregroundColor(.sMutedFG)

                        TextField("Search name or email", text: $vm.searchText)
                            .font(.scaled(14))
                            .foregroundColor(.sForeground)
                            .tint(.sAccent)
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
                    .padding(.top, 14)

                    // MARK: - Content
                    Group {
                        // Only when the list is empty. Search runs on the server, so
                        // this replaced the rows with a centred spinner on every
                        // search — losing what you were reading and where you were in
                        // it. With rows on screen the reload is shown quietly in the
                        // overlay below instead.
                        if vm.isLoading && vm.clients.isEmpty {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(.sAccent)
                                Text("Loading clients...")
                                    .font(.scaled(13))
                                    .foregroundColor(.sMutedFG)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        else if let error = vm.errorMessage {
                            VStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.scaled(28))
                                    .foregroundColor(.sDestructive)
                                Text(error)
                                    .font(.scaled(13))
                                    .foregroundColor(.sMutedFG)
                                    .multilineTextAlignment(.center)
                                Button {
                                    Task { await vm.loadClients() }
                                } label: {
                                    Text("Retry")
                                        .font(.scaled(13, weight: .medium))
                                        .foregroundColor(.sAccent)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(24)
                        }
                        else if filteredClients.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.scaled(40))
                                    .foregroundColor(.sMutedFG)
                                VStack(spacing: 4) {
                                    Text(vm.searchText.isEmpty ? "No clients" : "No results")
                                        .font(.scaled(15, weight: .semibold))
                                        .foregroundColor(.sForeground)
                                    Text(vm.searchText.isEmpty
                                         ? "Add your first client to get started"
                                         : "Try a different search")
                                        .font(.scaled(13))
                                        .foregroundColor(.sMutedFG)
                                        .multilineTextAlignment(.center)
                                }
                                if vm.searchText.isEmpty {
                                    NavigationLink(destination: ClientFormView()) {
                                        Text("Add client")
                                            .font(.scaled(13, weight: .semibold))
                                            .foregroundColor(.sAccentFG)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                            .background(Color.sPrimary)
                                            .cornerRadius(8)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(24)
                        }
                        else {
                            ScrollView(.vertical, showsIndicators: false) {
                                // Lazy on purpose. In a plain stack every row renders
                                // at once, so the "near the end" trigger fires
                                // immediately and walks the whole list in one go —
                                // which is the thing paging was meant to stop.
                                LazyVStack(spacing: 10) {
                                    ForEach(filteredClients) { client in
                                        NavigationLink {
                                            ClientDetailedView(client: client)
                                        } label: {
                                            ClientListRowView(client: client)
                                        }
                                        .task {
                                            // The next page is asked for as the last
                                            // few rows appear, so scrolling does not
                                            // stop at a page boundary.
                                            if client.id == vm.clients.suffix(5).first?.id {
                                                await vm.loadMoreClients()
                                            }
                                        }
                                    }

                                    if vm.isLoadingMoreClients {
                                        ProgressView()
                                            .tint(.sAccent)
                                            .padding(.vertical, 12)
                                    } else if vm.loadMoreClientsFailed {
                                        VStack(spacing: 6) {
                                            Text("Couldn't load more customers.")
                                                .font(.scaled(13))
                                                .foregroundColor(.sMutedFG)
                                            Button("Try again") {
                                                Task { await vm.retryLoadMoreClients() }
                                            }
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
                    // A reload over rows that are already there.
                    .overlay(alignment: .top) {
                        if vm.isLoading && !vm.clients.isEmpty {
                            ProgressView()
                                .tint(.sAccent)
                                .scaleEffect(0.8)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(.top, 8)
                                .transition(.opacity)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .navigationTitle("Clients")
            .onChange(of: vm.searchText) { _ in
                // Debounced, so a six-letter name is one request rather than six.
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
            .onChange(of: filteredClients.count) { _ in
                // onAppear fires before the list has loaded, so this waits for data.
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
            .task {
                await vm.loadClients()
            }
            .onChange(of: SessionManager.shared.selectedCompanyId) { _ in
                Task { await vm.loadClients() }
            }
        }
    }
}

// MARK: - Client List Row View
struct ClientListRowView: View {
    let client: ClientModel

    var body: some View {
        HStack(spacing: 12) {
            MinimalAvatarView(name: client.name)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(client.name)
                        .font(.scaled(14, weight: .medium))
                        .foregroundColor(.sForeground)

                    if client.isQuickSaleAccount {
                        Text("Ledger")
                            .font(.scaled(9, weight: .semibold))
                            .foregroundColor(.sAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.sAccentMuted)
                            .cornerRadius(4)
                    }
                }

                if !client.email.isEmpty {
                    Text(client.email)
                        .font(.scaled(12))
                        .foregroundColor(.sMutedFG)
                }
                if !client.phone.isEmpty {
                    Text(client.phone)
                        .font(.scaled(11))
                        .foregroundColor(.sMutedFG)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.scaled(12, weight: .semibold))
                .foregroundColor(.sMutedFG)
        }
        .padding(14)
        .background(Color.sCard)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.sBorder, lineWidth: 0.5)
        )
        .cornerRadius(12)
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
                .frame(width: size, height: size)
            Text(initials)
                .font(.scaled(13, weight: .semibold))
                .foregroundColor(.sAccent)
        }
    }
}
