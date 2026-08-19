import SwiftUI

struct ClientPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedClient: ClientModel?
    
    @StateObject var vm = ClientViewModel()
    @State private var searchText = ""
    @State private var showAddClient = false  // ✅ New state for add client sheet
    
    var filteredClients: [ClientModel] {
        if searchText.isEmpty { return vm.clients }
        return vm.clients.filter { client in
            client.name.lowercased().contains(searchText.lowercased()) ||
            client.email.lowercased().contains(searchText.lowercased())
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // MARK: - Header
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 14, weight: .light, design: .default))
                            }
                            .foregroundColor(.black)
                        }
                        
                        Spacer()
                        
                        Text("SELECT CLIENT")
                            .font(.system(size: 12, weight: .semibold, design: .default))
                            .tracking(0.5)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        // ✅ Changed to Add Client Button
                        Button(action: { showAddClient = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .frame(height: 1)
                        .background(Color.black.opacity(0.08))
                    
                    // MARK: - Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.black.opacity(0.4))
                        
                        TextField("Search clients", text: $searchText)
                            .font(.system(size: 14, weight: .light, design: .default))
                            .foregroundColor(.black)
                            .autocorrectionDisabled()
                        
                        // ✅ Clear button
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.black.opacity(0.3))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    
                    // MARK: - Add New Client Row ✅
                    Button(action: { showAddClient = true }) {
                        HStack(spacing: 14) {
                            // Dashed circle with plus
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(
                                        Color.black.opacity(0.3),
                                        style: StrokeStyle(lineWidth: 1, dash: [4])
                                    )
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundColor(.black.opacity(0.5))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Add New Client")
                                    .font(.system(size: 13, weight: .semibold, design: .default))
                                    .foregroundColor(.black)
                                
                                Text("Create a new client record")
                                    .font(.system(size: 11, weight: .light, design: .default))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.black.opacity(0.3))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.02))
                    }
                    
                    Divider()
                        .frame(height: 1)
                        .background(Color.black.opacity(0.08))
                        .padding(.top, 8)
                    
                    // MARK: - Clients List
                    if vm.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.black)
                            Text("Loading clients...")
                                .font(.system(size: 13, weight: .light, design: .default))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredClients.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "person.crop.square")
                                .font(.system(size: 40, weight: .thin))
                                .foregroundColor(.black.opacity(0.2))
                            
                            VStack(spacing: 6) {
                                Text(searchText.isEmpty ? "No Clients Yet" : "No Clients Found")
                                    .font(.system(size: 14, weight: .semibold, design: .default))
                                    .tracking(0.3)
                                
                                Text(searchText.isEmpty ? "Add your first client to get started" : "Try a different search")
                                    .font(.system(size: 12, weight: .light, design: .default))
                                    .foregroundColor(.gray)
                            }
                            
                            // ✅ Add client button in empty state
                            if searchText.isEmpty {
                                Button(action: { showAddClient = true }) {
                                    Text("ADD CLIENT")
                                        .font(.system(size: 12, weight: .semibold, design: .default))
                                        .tracking(0.5)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(Color.black)
                                }
                                .padding(.top, 8)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // ✅ Section header
                        HStack {
                            Text("EXISTING CLIENTS")
                                .font(.system(size: 10, weight: .semibold, design: .default))
                                .tracking(0.8)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text("\(filteredClients.count)")
                                .font(.system(size: 10, weight: .semibold, design: .default))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredClients) { client in
                                    ClientPickerRow(
                                        client: client,
                                        isSelected: selectedClient?.id == client.id,
                                        onSelect: {
                                            selectedClient = client
                                            dismiss()
                                        }
                                    )
                                    
                                    if client.id != filteredClients.last?.id {
                                        Divider()
                                            .frame(height: 1)
                                            .background(Color.black.opacity(0.08))
                                            .padding(.horizontal, 24)
                                    }
                                }
                            }
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .task { await vm.loadClients() }
            
            // ✅ Add Client Sheet
            .sheet(isPresented: $showAddClient, onDismiss: {
                // Refresh client list after adding new client
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
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(.black)
                            }
                        }
                }
                .presentationDetents([.large])
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
                // Avatar
                Text(String(client.name.prefix(1)).uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Color.black : Color.black.opacity(0.85))
                    .cornerRadius(4)
                
                // Client Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(client.name)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if !client.email.isEmpty {
                            Text(client.email)
                                .font(.system(size: 11, weight: .light, design: .default))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        
                        if !client.phone.isEmpty && !client.email.isEmpty {
                            Text("•")
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        
                        if !client.phone.isEmpty {
                            Text(client.phone)
                                .font(.system(size: 11, weight: .light, design: .default))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                    
                    if !client.city.isEmpty {
                        Text(client.city)
                            .font(.system(size: 10, weight: .light, design: .default))
                            .foregroundColor(.gray.opacity(0.6))
                            .tracking(0.2)
                    }
                }
                
                Spacer()
                
                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.black.opacity(0.3))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(isSelected ? Color.black.opacity(0.02) : Color.white)
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
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(Color.black)
            .cornerRadius(4)
    }
}

