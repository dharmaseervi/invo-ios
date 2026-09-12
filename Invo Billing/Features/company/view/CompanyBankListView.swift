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

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            if vm.isLoading {
                ProgressView().tint(.sAccent)
            }
            else if vm.banks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "building.columns")
                        .font(.scaled(36))
                        .foregroundColor(.sMutedFG)

                    Text("No bank accounts")
                        .font(.scaled(15, weight: .semibold))
                        .foregroundColor(.sForeground)

                    Button {
                        showForm = true
                    } label: {
                        Text("Add bank")
                            .font(.scaled(13, weight: .semibold))
                            .foregroundColor(.sAccentFG)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.sPrimary)
                            .cornerRadius(8)
                    }
                }
            }
            else {
                List {
                    ForEach(vm.banks) { bank in
                        Button {
                            selectedBank = bank
                            showForm = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bank.bank_name)
                                        .font(.scaled(14, weight: .medium))
                                        .foregroundColor(.sForeground)

                                    Text("A/C: \(bank.account_number)")
                                        .font(.scaled(12))
                                        .foregroundColor(.sMutedFG)
                                }

                                Spacer()

                                if bank.is_default {
                                    Text("Default")
                                        .font(.scaled(11, weight: .medium))
                                        .foregroundColor(.sAccent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.sAccentMuted)
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .listRowBackground(Color.sCard)
                    }
                    .onDelete { indexSet in
                        if let index = indexSet.first {
                            let bank = vm.banks[index]
                            Task {
                                await vm.deleteBank(companyId: companyId, bankId: bank.id)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
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
        .sheet(isPresented: $showForm) {
            CompanyBankFormView(
                vm: vm,
                companyId: companyId,
                bank: selectedBank
            )
        }
    }
}
