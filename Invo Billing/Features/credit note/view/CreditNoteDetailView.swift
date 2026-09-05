//
//  CreditNoteDetailView.swift
//  Invo Billing
//
//  Created by dharmaseervi on 1/18/26.
//

import SwiftUI

// MARK: - VIEW
struct CreditNoteDetailView: View {
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: CreditNoteDetailViewModel
    
    init(creditNoteID: Int) {
        _vm = StateObject(
            wrappedValue: CreditNoteDetailViewModel(cnID: creditNoteID)
        )
    }
    
    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if vm.isLoading {
                    loadingView
                } else if let cn = vm.creditNote {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 32) {
                            
                            creditInfoSection(cn)
                            summarySection(cn)
                            
                            if cn.type == "return" {
                                itemsSection(cn.items)
                            }
                            
                            totalsSection(cn)
                            actionsSection(cn)
                            
                            Spacer(minLength: 80)
                        }
                        .padding(.top, 24)
                    }
                }
                Spacer()
            }
        }
        .navigationTitle("Credit note")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await vm.load() }
        }
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }
}

// MARK: - SECTIONS
private extension CreditNoteDetailView {
    
    func creditInfoSection(_ cn: CreditNoteDetailModel) -> some View {
        VStack(spacing: 10) {
            Text(cn.credit_number)
                .font(.system(size: 22, weight: .light))
                .tracking(1)
                .foregroundColor(.sForeground)
            
            Text(cn.client_name)
                .font(.system(size: 13))
                .foregroundColor(.sMutedFG)
            
            HStack(spacing: 8) {
                statusBadge(cn.status)
                typeBadge(cn.type)
            }
        }
        .padding(.horizontal, 24)
    }
    
    func summarySection(_ cn: CreditNoteDetailModel) -> some View {
        VStack(spacing: 14) {
            detailRow("Credit date", formatDate(cn.credit_date))
            
//            if let inv = cn.invoice_number {
//                detailRow("Invoice", inv.invoice_number)
//            }
            
            detailRow("Type", cn.type.capitalized)
        }
        .padding(24)
        .background(Color.sMuted.opacity(0.4))
        .overlay(
            Rectangle()
                .stroke(Color.sBorder, lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
    
    func itemsSection(_ items: [CreditNoteItemModel]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            
            Text("Items")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.sMutedFG)
            
            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.item_name)
                            .font(.system(size: 14, weight: .light))
                        
                        Text(
                            "Qty \(item.qty, specifier: "%.0f") × ₹\(item.rate, specifier: "%.2f")"
                        )
                        .font(.system(size: 10))
                        .foregroundColor(.sMutedFG)
                    }
                    
                    Spacer()
                    
                    Text("₹\(item.total, specifier: "%.2f")")
                        .font(.system(size: 14, weight: .light))
                }
                
                Rectangle()
                    .fill(Color.sBorder)
                    .frame(height: 1)
            }
        }
        .padding(24)
        .overlay(
            Rectangle()
                .stroke(Color.sBorder, lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
    
    func totalsSection(_ cn: CreditNoteDetailModel) -> some View {
        VStack(spacing: 14) {
            amountRow("Subtotal", cn.subtotal)
            amountRow("Tax", cn.tax)
            
            Rectangle()
                .fill(Color.sBorder)
                .frame(height: 1)
            
            amountRow("Total", cn.total, bold: true)
            amountRow("Balance", cn.balance, bold: true)
        }
        .padding(24)
        .background(Color.sMuted.opacity(0.4))
        .overlay(
            Rectangle()
                .stroke(Color.sBorder, lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
    
    func actionsSection(_ cn: CreditNoteDetailModel) -> some View {
        VStack(spacing: 16) {
            
            if cn.balance > 0 {
                Button("Apply to invoice") {
                    // navigate to apply credit flow
                }
                .buttonStyle(PrimaryCNButton())
            }

            Button("Refund credit") {
                // navigate to refund flow
            }
            .buttonStyle(OutlineCNButton())
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - COMPONENTS
private extension CreditNoteDetailView {
    
    func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.sMutedFG)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 12))
        }
    }
    
    func amountRow(_ title: String, _ value: Double, bold: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
            
            Spacer()
            
            Text("₹\(value, specifier: "%.2f")")
                .font(.system(size: 13, weight: bold ? .medium : .light))
        }
    }
    
    func statusBadge(_ status: String) -> some View {
        Text(status.capitalized)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.cnSuccess)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.cnSuccess.opacity(0.1))
            .cornerRadius(6)
    }

    func typeBadge(_ type: String) -> some View {
        Text(type.capitalized)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.sForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.sBorder.opacity(0.5))
            .cornerRadius(6)
    }
    
    func formatDate(_ value: String) -> String {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) {
            let df = DateFormatter()
            df.dateFormat = "dd MMM yyyy"
            return df.string(from: date)
        }
        
        let simple = DateFormatter()
        simple.dateFormat = "yyyy-MM-dd"
        if let date = simple.date(from: value) {
            let df = DateFormatter()
            df.dateFormat = "dd MMM yyyy"
            return df.string(from: date)
        }
        
        return value
    }
}

// MARK: - LOADING
private extension CreditNoteDetailView {
    
    var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading credit note...")
                .font(.system(size: 12))
                .foregroundColor(.sMutedFG)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - BUTTON STYLES
struct PrimaryCNButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.sAccentFG)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.sPrimary)
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct OutlineCNButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.sForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.sCard)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.sBorder, lineWidth: 0.5)
            )
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
