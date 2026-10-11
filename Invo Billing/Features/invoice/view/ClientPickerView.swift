import SwiftUI

struct ClientPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedClient: ClientModel?

    @StateObject var vm = ClientViewModel()
    @State private var searchText = ""
    @State private var showAddClient = false
    @State private var isProvisioningQuickSale = false

    var filteredClients: [ClientModel] {
        if searchText.isEmpty {
            // Quick sale accounts (Cash/UPI) are pinned above as their own row
            return vm.clients.filter { !$0.isQuickSaleAccount }
        }
        return vm.clients.filter { client in
            client.name.lowercased().contains(searchText.lowercased()) ||
            client.email.lowercased().contains(searchText.lowercased())
        }
    }

    private func selectQuickSale(_ account: QuickSaleAccount) {
        Task {
            isProvisioningQuickSale = true
            if let client = await vm.ensureQuickSaleClient(account) {
                selectedClient = client
                dismiss()
            }
            isProvisioningQuickSale = false
        }
    }

    private var quickSaleRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick sale")
                .font(.caption.weight(.medium))
                .foregroundColor(.sMutedFG)
                .padding(.horizontal, AppSpacing.page)

            HStack(spacing: 10) {
                ForEach(QuickSaleAccount.allCases, id: \.self) { account in
                    Button {
                        selectQuickSale(account)
                    } label: {
                        HStack(spacing: 8) {
                            if isProvisioningQuickSale {
                                ProgressView()
                                    .tint(.sAccent)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: account.icon)
                                    .font(.subheadline.weight(.semibold))
                            }
                            Text(account.rawValue)
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundColor(.sAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.sAccentMuted)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.sAccent.opacity(0.25), lineWidth: 0.5)
                        )
                        .cornerRadius(10)
                    }
                    .disabled(isProvisioningQuickSale)
                }
            }
            .padding(.horizontal, AppSpacing.page)

            Text("No customer details needed — bills straight to the \(QuickSaleAccount.cash.rawValue.lowercased())/\(QuickSaleAccount.upi.rawValue) ledger")
                .font(.caption)
                .foregroundColor(.sMutedFG)
                .padding(.horizontal, AppSpacing.page)
        }
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sBackground.ignoresSafeArea()

                VStack(spacing: 0) {

                    // MARK: - Quick Sale
                    if searchText.isEmpty {
                        quickSaleRow
                    }

                    // MARK: - Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.body)
                            .foregroundColor(.sMutedFG)

                        TextField("Search clients", text: $searchText)
                            .font(.body)
                            .foregroundColor(.sForeground)
                            .tint(.sAccent)
                            .autocorrectionDisabled()

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.body)
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
                    .padding(.horizontal, AppSpacing.page)
                    .padding(.vertical, 14)

                    // MARK: - Add New Client Row
                    Button(action: { showAddClient = true }) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        Color.sBorder,
                                        style: StrokeStyle(lineWidth: 1, dash: [4])
                                    )
                                    .frame(width: 44, height: 44)

                                Image(systemName: "plus")
                                    .font(.body)
                                    .foregroundColor(.sMutedFG)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Add new client")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.sForeground)

                                Text("Create a new client record")
                                    .font(.caption)
                                    .foregroundColor(.sMutedFG)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.sMutedFG)
                        }
                        .padding(.horizontal, AppSpacing.page)
                        .padding(.vertical, 12)
                    }

                    Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.top, 4)

                    // MARK: - Clients List
                    if vm.isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.sAccent)
                            Text("Loading clients...")
                                .font(.subheadline)
                                .foregroundColor(.sMutedFG)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredClients.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.scaled(36))
                                .foregroundColor(.sMutedFG)

                            VStack(spacing: 4) {
                                Text(searchText.isEmpty ? "No clients yet" : "No clients found")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.sForeground)

                                Text(searchText.isEmpty ? "Add your first client to get started" : "Try a different search")
                                    .font(.footnote)
                                    .foregroundColor(.sMutedFG)
                            }

                            if searchText.isEmpty {
                                Button(action: { showAddClient = true }) {
                                    Text("Add client")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.sAccentFG)
                                        .padding(.horizontal, AppSpacing.page)
                                        .padding(.vertical, 10)
                                        .background(Color.sPrimary)
                                        .cornerRadius(8)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        HStack {
                            Text("Existing clients")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.sMutedFG)

                            Spacer()

                            Text("\(filteredClients.count)")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.sMutedFG)
                        }
                        .padding(.horizontal, AppSpacing.page)
                        .padding(.top, 14)
                        .padding(.bottom, 8)

                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredClients) { client in
                                    ClientPickerRow(
                                        client: client,
                                        isSelected: selectedClient?.id == client.id,
                                        onSelect: {
                                            selectedClient = client
                                            dismiss()
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, AppSpacing.page)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("Select client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAddClient = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { await vm.loadClients() }

            .sheet(isPresented: $showAddClient, onDismiss: {
                Task { await vm.loadClients() }
            }) {
                NavigationStack {
                    ClientFormView()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    showAddClient = false
                                }
                                .font(.body)
                                .foregroundColor(.sForeground)
                            }
                        }
                }
                .presentationDetents([.large])
            }
            .alert("Error", isPresented: $vm.showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "Something went wrong")
            }
        }
    }
}

// MARK: - Client Picker Row
struct ClientPickerRow: View {
    let client: ClientModel
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                Text(String(client.name.prefix(1)).uppercased())
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.sAccentFG)
                    .frame(width: 44, height: 44)
                    .background(Color.sAccent)
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(client.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.sForeground)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if !client.email.isEmpty {
                            Text(client.email)
                                .font(.caption)
                                .foregroundColor(.sMutedFG)
                                .lineLimit(1)
                        }

                        if !client.phone.isEmpty && !client.email.isEmpty {
                            Text("•")
                                .foregroundColor(.sMutedFG)
                        }

                        if !client.phone.isEmpty {
                            Text(client.phone)
                                .font(.caption)
                                .foregroundColor(.sMutedFG)
                                .lineLimit(1)
                        }
                    }

                    if !client.city.isEmpty {
                        Text(client.city)
                            .font(.caption)
                            .foregroundColor(.sMutedFG)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.sAccent)
                } else {
                    Image(systemName: "circle")
                        .font(.body)
                        .foregroundColor(.sBorder)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color.sCard)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.sAccent.opacity(0.4) : Color.sBorder, lineWidth: 0.5)
            )
            .cornerRadius(10)
        }
    }
}

// MARK: - Legacy Avatar Support
struct AvatarView: View {
    let name: String
    let size: CGFloat

    var body: some View {
        let first = String(name.prefix(1)).uppercased()

        Text(first)
            .font(.scaled(size * 0.45, weight: .bold))
            .foregroundColor(.sAccentFG)
            .frame(width: size, height: size)
            .background(Color.sAccent)
            .cornerRadius(8)
    }
}
