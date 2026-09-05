import SwiftUI

struct ClientView: View {
    @StateObject var vm = ClientViewModel()
    @EnvironmentObject var session: SessionManager

    @State private var searchText: String = ""

    var filteredClients: [ClientModel] {
        if searchText.isEmpty { return vm.clients }
        return vm.clients.filter {
            $0.name.lowercased().contains(searchText.lowercased()) ||
            $0.email.lowercased().contains(searchText.lowercased())
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sBackground.ignoresSafeArea()

                VStack(spacing: 0) {

                    // MARK: - Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(.sMutedFG)

                        TextField("Search name or email", text: $searchText)
                            .font(.system(size: 14))
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
                        if vm.isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(.sAccent)
                                Text("Loading clients...")
                                    .font(.system(size: 13))
                                    .foregroundColor(.sMutedFG)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        else if let error = vm.errorMessage {
                            VStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 28))
                                    .foregroundColor(.sDestructive)
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(.sMutedFG)
                                    .multilineTextAlignment(.center)
                                Button {
                                    Task { await vm.loadClients() }
                                } label: {
                                    Text("Retry")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.sAccent)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(24)
                        }
                        else if filteredClients.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 40))
                                    .foregroundColor(.sMutedFG)
                                VStack(spacing: 4) {
                                    Text(searchText.isEmpty ? "No clients" : "No results")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.sForeground)
                                    Text(searchText.isEmpty
                                         ? "Add your first client to get started"
                                         : "Try a different search")
                                        .font(.system(size: 13))
                                        .foregroundColor(.sMutedFG)
                                        .multilineTextAlignment(.center)
                                }
                                if searchText.isEmpty {
                                    NavigationLink(destination: ClientFormView()) {
                                        Text("Add client")
                                            .font(.system(size: 13, weight: .semibold))
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
                                VStack(spacing: 10) {
                                    ForEach(filteredClients) { client in
                                        NavigationLink {
                                            ClientDetailedView(client: client)
                                        } label: {
                                            ClientListRowView(client: client)
                                        }
                                    }
                                }
                                .padding(20)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .navigationTitle("Clients")
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
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.sForeground)

                    if client.isQuickSaleAccount {
                        Text("Ledger")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.sAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.sAccentMuted)
                            .cornerRadius(4)
                    }
                }

                if !client.email.isEmpty {
                    Text(client.email)
                        .font(.system(size: 12))
                        .foregroundColor(.sMutedFG)
                }
                if !client.phone.isEmpty {
                    Text(client.phone)
                        .font(.system(size: 11))
                        .foregroundColor(.sMutedFG)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
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
struct MinimalAvatarView: View {
    let name: String
    let size: CGFloat = 44

    var body: some View {
        let first = String(name.prefix(1)).uppercased()

        Text(first)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.sAccentFG)
            .frame(width: size, height: size)
            .background(Color.sAccent)
            .cornerRadius(10)
    }
}
