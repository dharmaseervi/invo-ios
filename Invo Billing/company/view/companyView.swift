import SwiftUI

struct companyView: View {
    @StateObject var vm = CompanyFormViewModel()
    @EnvironmentObject var session: SessionManager
    @Environment(\.dismiss) var dismiss
    
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
                        
                        Text("COMPANIES")
                            .font(.system(size: 12, weight: .semibold, design: .default))
                            .tracking(0.5)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        NavigationLink(destination: companyForm()) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .frame(height: 1)
                        .background(Color.black.opacity(0.08))
                    
                    // MARK: - Content
                    Group {
                        if vm.isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .tint(.black)
                                Text("Loading companies...")
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
                        else if !vm.companies.isEmpty {
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 0) {
                                    ForEach(vm.companies) { company in
                                        CompanyRowZara(
                                            company: company,
                                            isSelected: session.selectedCompanyId == company.id,
                                            onSelect: {
                                                withAnimation(.spring()) {
                                                    session.selectedCompanyId = company.id
                                                    SessionManager.saveSelectedCompanyId(company.id)
                                                }
                                            }
                                        )
                                        
                                        if company.id != vm.companies.last?.id {
                                            Divider()
                                                .frame(height: 1)
                                                .background(Color.black.opacity(0.08))
                                                .padding(.horizontal, 24)
                                        }
                                    }
                                }
                                .padding(.vertical, 16)
                            }
                        }
                        else {
                            VStack(spacing: 24) {
                                Image(systemName: "building.2")
                                    .font(.system(size: 48, weight: .thin))
                                    .foregroundColor(.black.opacity(0.2))
                                
                                VStack(spacing: 8) {
                                    Text("No Companies")
                                        .font(.system(size: 16, weight: .semibold, design: .default))
                                        .tracking(0.3)
                                    
                                    Text("Add your first company to get started")
                                        .font(.system(size: 12, weight: .light, design: .default))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                }
                                
                                NavigationLink(destination: companyForm()) {
                                    Text("ADD COMPANY")
                                        .font(.system(size: 12, weight: .semibold, design: .default))
                                        .tracking(0.5)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .foregroundColor(.white)
                                        .background(Color.black)
                                }
                                .padding(.top, 8)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(24)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                await vm.loadCompanies()
            }
        }
    }
}

// MARK: - Company Row (Zara Style)
struct CompanyRowZara: View {
    let company: CompanyResponse
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var showMenu = false
    
    var body: some View {
        HStack(spacing: 16) {
            
            // Main Select Button
            Button(action: onSelect) {
                HStack(spacing: 16) {
                    
                    Text(String(company.name.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.black)
                        .cornerRadius(6)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(company.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.black)
                        
                        Text("\(company.city), \(company.state)")
                            .font(.system(size: 11, weight: .light))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.black)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // 3-dot menu
            Menu {
                
                NavigationLink {
                    CompanyBankListView(companyId: company.id)
                } label: {
                    Label("Manage Banks", systemImage: "building.columns")
                }
                
                NavigationLink {
//                    CompanyAddressView(companyId: company.id)
                } label: {
                    Label("Manage Address", systemImage: "location")
                }
                
                NavigationLink {
//                    companyForm(editCompany: company)
                } label: {
                    Label("Edit Company", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    // Call delete here
                } label: {
                    Label("Delete Company", systemImage: "trash")
                }
                
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
                    .padding(.leading, 8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

