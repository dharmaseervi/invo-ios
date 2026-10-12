//
//  CompanyBankListView.swift
//  Invo Billing
//
//  Created by dharmaseervi on 2/5/26.
//

import SwiftUI

struct CompanyBankListView: View {

    let companyId: Int
    @StateObject private var vm = CompanyBankViewModel()
    @State private var showForm = false
    @State private var selectedBank: CompanyBankResponse?
    @State private var bankToDelete: CompanyBankResponse?
    @State private var showDeleteConfirmation = false
    @State private var deletePassword = ""

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView()
                    .tint(.sAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            else if vm.banks.isEmpty {
                ContentUnavailableView {
                    Label("No bank accounts", systemImage: "building.columns")
                } actions: {
                    Button("Add bank") { showForm = true }
                        .buttonStyle(.borderedProminent)
                        .tint(.sAccent)
                }
            }
            else {
                List {
                    ForEach(vm.banks) { bank in
                        Button {
                            selectedBank = bank
                            showForm = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "building.columns")
                                    .font(.body)
                                    .foregroundStyle(Color.sAccent)
                                    .frame(width: 40, height: 40)
                                    .background(Color.sAccentMuted, in: Circle())
                                    .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(bank.bank_name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.primary)

                                    Text("A/C: \(bank.account_number)")
                                        .font(.footnote)
                                        .foregroundStyle(Color.secondary)
                                }
                                .alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }

                                Spacer(minLength: 8)

                                if bank.is_default {
                                    Text("Default")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.sAccent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.sAccentMuted)
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .standardListRow()
                    }
                    .onDelete { indexSet in
                        if let index = indexSet.first {
                            let bank = vm.banks[index]
                            bankToDelete = bank
                            deletePassword = ""
                            showDeleteConfirmation = true
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Bank accounts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    selectedBank = nil
                    showForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await vm.loadBanks(companyId: companyId)
        }
        // The screen had no way at all to show a failure, so a load or a delete that
        // did not work left an empty list that read as "no bank accounts".
        .alert("Something went wrong", isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Please try again.")
        }
        .alert("Remove bank account?", isPresented: $showDeleteConfirmation) {
            SecureField("Account password", text: $deletePassword)
            Button("Remove", role: .destructive) {
                guard let bank = bankToDelete else { return }
                let password = deletePassword
                deletePassword = ""
                bankToDelete = nil
                Task { await vm.deleteBank(companyId: companyId, bankId: bank.id, password: password) }
            }
            .disabled(deletePassword.isEmpty)
            Button("Cancel", role: .cancel) { deletePassword = ""; bankToDelete = nil }
        } message: {
            Text("Enter your password to remove this bank account.")
        }
        .sheet(isPresented: $showForm) {
            CompanyBankFormView(
                vm: vm,
                companyId: companyId,
                bank: selectedBank
            )
        }
    }
}
