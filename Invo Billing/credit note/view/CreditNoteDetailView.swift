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
            Color.cnWhite.ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // HEADER
                headerView
                
                Divider()
                
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
        .navigationBarHidden(true)
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

// MARK: - HEADER
private extension CreditNoteDetailView {
    
    var headerView: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.cnBlack)
            }
            
            Spacer()
            
            Text("CREDIT NOTE")
                .font(.system(size: 12, weight: .regular))
                .tracking(4)
            
            Spacer()
            
            Spacer().frame(width: 24)
        }
        .padding(24)
    }
}

// MARK: - SECTIONS
private extension CreditNoteDetailView {
    
    func creditInfoSection(_ cn: CreditNoteDetailModel) -> some View {
        VStack(spacing: 10) {
            Text(cn.credit_number)
                .font(.system(size: 22, weight: .light))
                .tracking(1)
                .foregroundColor(.cnBlack)
            
            Text(cn.client_name.uppercased())
                .font(.system(size: 11, weight: .regular))
                .tracking(2)
                .foregroundColor(.cnGray)
            
            HStack(spacing: 8) {
                statusBadge(cn.status)
                typeBadge(cn.type)
            }
        }
        .padding(.horizontal, 24)
    }
    
    func summarySection(_ cn: CreditNoteDetailModel) -> some View {
        VStack(spacing: 14) {
            detailRow("Credit Date", formatDate(cn.credit_date))
            
//            if let inv = cn.invoice_number {
//                detailRow("Invoice", inv.invoice_number)
//            }
            
            detailRow("Type", cn.type.capitalized)
        }
        .padding(24)
        .background(Color.cnCream.opacity(0.4))
        .overlay(
            Rectangle()
                .stroke(Color.cnLightGray, lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
    
    func itemsSection(_ items: [CreditNoteItemModel]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            
            Text("ITEMS")
                .font(.system(size: 10, weight: .medium))
                .tracking(3)
                .foregroundColor(.cnGray)
            
            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.item_name)
                            .font(.system(size: 14, weight: .light))
                        
                        Text(
                            "Qty \(item.qty, specifier: "%.0f") × ₹\(item.rate, specifier: "%.2f")"
                        )
                        .font(.system(size: 10))
                        .foregroundColor(.cnGray)
                    }
                    
                    Spacer()
                    
                    Text("₹\(item.total, specifier: "%.2f")")
                        .font(.system(size: 14, weight: .light))
                }
                
                Rectangle()
                    .fill(Color.cnLightGray)
                    .frame(height: 1)
            }
        }
        .padding(24)
        .overlay(
            Rectangle()
                .stroke(Color.cnLightGray, lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
    
    func totalsSection(_ cn: CreditNoteDetailModel) -> some View {
        VStack(spacing: 14) {
            amountRow("Subtotal", cn.subtotal)
            amountRow("Tax", cn.tax)
            
            Rectangle()
                .fill(Color.cnLightGray)
                .frame(height: 1)
            
            amountRow("Total", cn.total, bold: true)
            amountRow("Balance", cn.balance, bold: true)
        }
        .padding(24)
        .background(Color.cnCream.opacity(0.4))
        .overlay(
            Rectangle()
                .stroke(Color.cnLightGray, lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
    
    func actionsSection(_ cn: CreditNoteDetailModel) -> some View {
        VStack(spacing: 16) {
            
            if cn.balance > 0 {
                Button("APPLY TO INVOICE") {
                    // navigate to apply credit flow
                }
                .buttonStyle(PrimaryCNButton())
            }
            
            Button("REFUND CREDIT") {
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
                .foregroundColor(.cnGray)
            
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
        Text(status.uppercased())
            .font(.system(size: 9, weight: .medium))
            .tracking(1)
            .foregroundColor(.cnSuccess)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.cnSuccess.opacity(0.1))
    }
    
    func typeBadge(_ type: String) -> some View {
        Text(type.uppercased())
            .font(.system(size: 9, weight: .medium))
            .tracking(1)
            .foregroundColor(.cnBlack)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.cnLightGray.opacity(0.5))
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
                .foregroundColor(.cnGray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - BUTTON STYLES
struct PrimaryCNButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .tracking(3)
            .foregroundColor(.cnWhite)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.cnBlack)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct OutlineCNButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .tracking(3)
            .foregroundColor(.cnBlack)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .overlay(
                Rectangle()
                    .stroke(Color.cnBlack, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
