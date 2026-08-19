//
//  CompanyBankListView.swift
//  Invo Billing
//
//  Created by dharmaseervi on 2/5/26.
//

import SwiftUI

//
//  CompanyBankListView.swift
//  Invo Billing
//
//  Created by dharmaseervi on 2/5/26.
//

struct CompanyBankListView: View {
    
    let companyId: Int
    @StateObject private var vm = CompanyBankViewModel()
    @State private var showForm = false
    @State private var selectedBank: CompanyBankResponse?
    
    var body: some View {
        VStack {
            
            if vm.isLoading {
                ProgressView().tint(.black)
            }
            
            else if vm.banks.isEmpty {
                VStack(spacing: 20) {
                    Text("No Bank Accounts")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Button("Add Bank") {
                        showForm = true
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
                                VStack(alignment: .leading) {
                                    Text(bank.bank_name)
                                        .font(.headline)
                                    
                                    Text("A/C: \(bank.account_number)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                if bank.is_default {
                                    Text("Default")
                                        .font(.caption2)
                                        .padding(6)
                                        .background(Color.black.opacity(0.1))
                                        .cornerRadius(6)
                                }
                            }
                        }
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
            }
        }
        .navigationTitle("Bank Accounts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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
