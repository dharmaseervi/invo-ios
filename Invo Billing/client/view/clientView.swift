import SwiftUI

struct clientView: View {
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
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // MARK: - Header
                    VStack(alignment: .leading, spacing: 16) {
                        Text("CLIENTS")
                            .font(.system(size: 28, weight: .thin, design: .default))
                            .tracking(0.5)
                        
                        Divider()
                            .frame(height: 1)
                            .background(Color.black)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                    
                    // MARK: - Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.black.opacity(0.4))
                        
                        TextField("Search name or email", text: $searchText)
                            .font(.system(size: 14, weight: .light, design: .default))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                                        
                    // MARK: - Content
                    Group {
                        if vm.isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .tint(.black)
                                Text("Loading clients...")
                                    .font(.system(size: 13, weight: .light, design: .default))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        else if let error = vm.errorMessage {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 32, weight: .thin))
                                    .foregroundColor(.red)
                                
                                Text("Error")
                                    .font(.system(size: 14, weight: .semibold, design: .default))
                                
                                Text(error)
                                    .font(.system(size: 12, weight: .light, design: .default))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(24)
                        }
                        else if filteredClients.isEmpty {
                            VStack(spacing: 24) {
                                Image(systemName: "person.crop.square")
                                    .font(.system(size: 48, weight: .thin))
                                    .foregroundColor(.black.opacity(0.2))
                                
                                VStack(spacing: 8) {
                                    Text("No Clients")
                                        .font(.system(size: 16, weight: .semibold, design: .default))
                                        .tracking(0.3)
                                    
                                    Text("Add your first client to get started")
                                        .font(.system(size: 12, weight: .light, design: .default))
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        else {
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 0) {
                                    ForEach(filteredClients) { client in
                                        NavigationLink {
                                            ClientDetailedView(client: client)
                                        } label: {
                                            ClientListRowView(client: client)
                                        }
                                        
                                        if client.id != filteredClients.last?.id {
                                            Divider()
                                                .frame(height: 1)
                                                .background(Color.black.opacity(0.08))
                                                .padding(.horizontal, 24)
                                        }
                                    }
                                }
                                .padding(.vertical, 24)
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink { ClientFormView() } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                        
                        }
                        .foregroundColor(.black)
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                // Avatar
                MinimalAvatarView(name: client.name)
                
                // Client Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(client.name)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundColor(.black)
                    
                    if !client.email.isEmpty {
                        Text(client.email)
                            .font(.system(size: 12, weight: .light, design: .default))
                            .foregroundColor(.gray)
                    }
                    
                    if !client.phone.isEmpty {
                        Text(client.phone)
                            .font(.system(size: 11, weight: .light, design: .default))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black.opacity(0.3))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Color.white)
    }
}

// MARK: - Minimal Avatar View
struct MinimalAvatarView: View {
    let name: String
    let size: CGFloat = 44
    
    var body: some View {
        let first = String(name.prefix(1)).uppercased()
        
        Text(first)
            .font(.system(size: 14, weight: .semibold, design: .default))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(Color.black)
            .cornerRadius(4)
    }
}

