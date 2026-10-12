import SwiftUI

struct CompanyView: View {
    @StateObject var vm = CompanyFormViewModel()
    @EnvironmentObject var session: SessionManager
    @Environment(\.dismiss) var dismiss
    @State private var editingCompanyID: Int?
    @State private var bankCompanyID: Int?

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView()
                    .tint(.sAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            else if let error = vm.errorMessage {
                ContentUnavailableView(
                    "Couldn't load companies",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            }
            else if !vm.companies.isEmpty {
                List {
                    ForEach(vm.companies) { company in
                        CompanyRowZara(
                            company: company,
                            isSelected: session.selectedCompanyId == company.id,
                            onSelect: {
                                withAnimation(.spring()) {
                                    session.selectedCompanyId = company.id
                                    SessionManager.saveSelectedCompanyId(company.id)
                                }
                            },
                            onEdit: { editingCompanyID = company.id },
                            onManageBanks: { bankCompanyID = company.id }
                        )
                        .standardListRow(trailing: 12)
                        .listRowSeparator(.hidden, edges: company.id == vm.companies.first?.id ? .top : [])
                    }
                }
                .listStyle(.plain)
            }
            else {
                ContentUnavailableView {
                    Label("No companies", systemImage: "building.2")
                } description: {
                    Text("Add your first company to get started")
                } actions: {
                    NavigationLink("Add company", destination: companyForm())
                        .buttonStyle(.borderedProminent)
                        .tint(.sAccent)
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
        // Attached here rather than on each row: inside a List the rows are lazy, and a
        // destination declared on one of them is ignored.
        .navigationDestination(item: $editingCompanyID) { id in
            if let company = vm.companies.first(where: { $0.id == id }) {
                CompanyEditView(company: company)
            }
        }
        .navigationDestination(item: $bankCompanyID) { id in
            CompanyBankListView(companyId: id)
        }
        .task {
            await vm.loadCompanies()
        }
    }
}

// MARK: - Company Row
struct CompanyRowZara: View {
    let company: CompanyResponse
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onManageBanks: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Text(String(company.name.prefix(1)).uppercased())
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.sAccentFG)
                        .frame(width: 40, height: 40)
                        .background(Color.sAccent, in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(company.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)

                        Text("\(company.city), \(company.state)")
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }

                    Spacer(minLength: 8)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.sAccent)
                            .accessibilityLabel("Selected")
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)

            Menu {
                Button(action: onEdit) {
                    Label("Edit details", systemImage: "pencil")
                }

                Button(action: onManageBanks) {
                    Label("Manage banks", systemImage: "building.columns")
                }

                Button(role: .destructive) {
                    // Call delete here
                } label: {
                    Label("Delete Company", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Actions for \(company.name)")
        }
    }
}
