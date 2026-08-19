import SwiftUI

struct RecordPaymentView: View {
    
    @StateObject private var vm: RecordPaymentViewModel

    // MARK: - Init (make accessible)
    init(vm: RecordPaymentViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }
  
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                header
                Divider()
                form
                saveButton
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Task { await vm.loadUnpaidInvoices() }
        }
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text("RECORD PAYMENT")
                .font(.system(size: 12, weight: .semibold))
                .tracking(1)
            Spacer()
        }
        .padding(24)
    }
    
    // MARK: - Form
    private var form: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                amountSection
                methodSection
                
                if !vm.isInvoiceMode {
                    invoiceListSection
                }
            }
            .padding(24)
        }
    }
    
    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AMOUNT")
                .font(.system(size: 10))
                .foregroundColor(.gray)
            
            TextField("₹0.00", text: $vm.amount)
                .keyboardType(.decimalPad)
                .font(.system(size: 20, weight: .semibold))
            
            Divider()
        }
    }
    
    private var methodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PAYMENT METHOD")
                .font(.system(size: 10))
                .foregroundColor(.gray)
            
            Picker("", selection: $vm.method) {
                ForEach(PaymentMethods.allCases, id: \.self) {
                    Text($0.rawValue.uppercased())
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var invoiceListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("APPLIED TO INVOICES")
                .font(.system(size: 10))
                .foregroundColor(.gray)
            
            ForEach(vm.unpaidInvoices) { invoice in
                HStack {
                    Text(invoice.invoiceNumber)
                    Spacer()
                    Text("₹\(invoice.remainingAmount, specifier: "%.2f")")
                }
                Divider()
            }
        }
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        Button {
            Task {
                if await vm.submitPayment() {
                    dismiss()
                }
            }
        } label: {
            Text("SAVE PAYMENT")
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(vm.isValid ? Color.black : Color.gray)
                .foregroundColor(.white)
        }
        .disabled(!vm.isValid || vm.isLoading)
        .padding(24)
        .padding(.bottom, 48)
    }
}

