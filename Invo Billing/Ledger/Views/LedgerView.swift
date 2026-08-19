import SwiftUI

struct LedgerView: View {
    
    @StateObject private var vm = LedgerListViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // MARK: Header (MATCH MoreView)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("LEDGER")
                            .font(.system(size: 28, weight: .thin))
                            .tracking(0.5)
                        
                        Divider()
                            .frame(height: 1)
                            .background(Color.black)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                    
                    // MARK: Search (Minimal)
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.black.opacity(0.6))
                        
                        TextField("Search", text: $vm.searchText)
                            .font(.system(size: 13, weight: .light))
                    }
                    .padding(.vertical, 10)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.black.opacity(0.2)),
                        alignment: .bottom
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    
                    // MARK: Content
                    if vm.isLoading {
                        Spacer()
                        ProgressView().tint(.black)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                
                                ForEach(vm.filteredClients) { client in
                                    NavigationLink {
                                        LedgerListView(clientID: client.clientID)
                                    } label: {
                                        LedgerRow(client: client)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Divider()
                                        .frame(height: 1)
                                        .background(Color.black.opacity(0.08))
                                        .padding(.leading, 24)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true) // ✅ SAME as MoreView
            .onAppear {
                Task { await vm.fetchCompanyLedger() }
            }
        }
    }
}

struct LedgerRow: View {
    
    let client: ClientLedger
    
    var body: some View {
        HStack {
            
            VStack(alignment: .leading, spacing: 6) {
                
                Text(client.clientName.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1)
                
                Text("₹\(client.balance, specifier: "%.2f")")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(.black.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.black.opacity(0.3))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }
}
struct ClientLedgerRowView: View {
    
    let client: ClientLedger
    
    var body: some View {
        HStack {
            
            VStack(alignment: .leading, spacing: 6) {
                
                Text(client.clientName.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(.black)
                
                Text("₹\(client.balance, specifier: "%.2f")")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.black.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.black.opacity(0.4))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
    }
}
