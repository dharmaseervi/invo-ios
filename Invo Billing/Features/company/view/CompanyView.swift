import SwiftUI

struct CompanyView: View {
    @StateObject var vm = CompanyFormViewModel()
    @EnvironmentObject var session: SessionManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            ZStack {
                Color.sBackground.ignoresSafeArea()

                VStack(spacing: 0) {

                    // MARK: - Content
                    Group {
                        if vm.isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(.sAccent)
                                Text("Loading companies...")
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
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(24)
                        }
                        else if !vm.companies.isEmpty {
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 10) {
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
                                    }
                                }
                                .padding(20)
                            }
                        }
                        else {
                            VStack(spacing: 16) {
                                Image(systemName: "building.2")
                                    .font(.scaled(40))
                                    .foregroundColor(.sMutedFG)

                                VStack(spacing: 4) {
                                    Text("No companies")
                                        .font(.scaled(15, weight: .semibold))
                                        .foregroundColor(.sForeground)

                                    Text("Add your first company to get started")
                                        .font(.scaled(13))
                                        .foregroundColor(.sMutedFG)
                                        .multilineTextAlignment(.center)
                                }

                                NavigationLink(destination: companyForm()) {
                                    Text("Add company")
                                        .font(.scaled(13, weight: .semibold))
                                        .foregroundColor(.sAccentFG)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.sPrimary)
                                        .cornerRadius(8)
                                }
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(24)
                        }
                    }
                }
            }
            .navigationTitle("Companies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: companyForm()) {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await vm.loadCompanies()
            }
        }
    }
}

// MARK: - Company Row
struct CompanyRowZara: View {
    let company: CompanyResponse
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {

            Button(action: onSelect) {
                HStack(spacing: 14) {
                    Text(String(company.name.prefix(1)).uppercased())
                        .font(.scaled(14, weight: .semibold))
                        .foregroundColor(.sAccentFG)
                        .frame(width: 44, height: 44)
                        .background(Color.sAccent)
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(company.name)
                            .font(.scaled(13, weight: .medium))
                            .foregroundColor(.sForeground)

                        Text("\(company.city), \(company.state)")
                            .font(.scaled(11))
                            .foregroundColor(.sMutedFG)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.sAccent)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            Menu {
                NavigationLink {
                    CompanyBankListView(companyId: company.id)
                } label: {
                    Label("Manage Banks", systemImage: "building.columns")
                }

                Button(role: .destructive) {
                    // Call delete here
                } label: {
                    Label("Delete Company", systemImage: "trash")
                }

            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.sMutedFG)
                    .padding(.leading, 4)
            }
        }
        .padding(14)
        .background(Color.sCard)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.sAccent.opacity(0.4) : Color.sBorder, lineWidth: 0.5)
        )
        .cornerRadius(12)
    }
}
