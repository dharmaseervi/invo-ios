import SwiftUI

struct ClientDetailedView: View {
    private var hasContactDetails: Bool {
        !client.email.isEmpty || !client.phone.isEmpty
    }

    private var hasAddress: Bool {
        ![client.address, client.city, client.state, client.pincode]
            .allSatisfy(\.isEmpty)
    }

    let client: ClientModel
    @Environment(\.dismiss) var dismiss

    var avatarLetter: String {
        String(client.name.prefix(1)).uppercased()
    }
    @StateObject private var vm = ClientViewModel()
    @StateObject private var invoiceVM = InvoiceViewModel()

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {

                    // MARK: - Profile Header
                    VStack(spacing: 14) {
                        MinimalAvatarView(name: client.name, size: 72)

                        Text(client.name)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.sForeground)
                    }
                    .padding(.top, 20)

                    // MARK: - Contact Information Section
                    // DetailInfoRow renders nothing for an empty value, so a client with
                    // no email or phone left a card holding only its own heading.
                    if hasContactDetails {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Contact information")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.sMutedFG)
                            .padding(.horizontal, AppSpacing.page)
                            .padding(.top, 14)
                            .padding(.bottom, 10)

                        Rectangle().fill(Color.sBorder).frame(height: 0.5)

                        DetailInfoRow(icon: "envelope", title: "Email", value: client.email)
                        Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.leading, 52)
                        DetailInfoRow(icon: "phone", title: "Phone", value: client.phone)
                    }
                    .background(Color.sCard)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
                    .cornerRadius(12)
                    }

                    // MARK: - Address Section
                    if hasAddress {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Address")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.sMutedFG)
                            .padding(.horizontal, AppSpacing.page)
                            .padding(.top, 14)
                            .padding(.bottom, 10)

                        Rectangle().fill(Color.sBorder).frame(height: 0.5)

                        DetailInfoRow(icon: "house", title: "Street", value: client.address)
                        Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.leading, 52)

                        HStack(spacing: 0) {
                            DetailInfoRow(icon: "building.2", title: "City", value: client.city)
                            DetailInfoRow(icon: "map", title: "State", value: client.state)
                        }
                        Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.leading, 52)
                        DetailInfoRow(icon: "number", title: "Pincode", value: client.pincode)
                    }
                    .background(Color.sCard)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
                    .cornerRadius(12)
                    }

                    // MARK: - Invoices Section
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Invoices")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.sMutedFG)
                            Spacer()
                            NavigationLink("View all") {
                                InvoiceView(clientID: client.id, clientName: client.name)
                            }
                            .font(.subheadline)
                            .foregroundColor(.sAccent)
                        }
                        .padding(.horizontal, AppSpacing.page)
                        .padding(.top, 14)
                        .padding(.bottom, 10)

                        Rectangle().fill(Color.sBorder).frame(height: 0.5)

                        if vm.invoices.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                    .font(.title2)
                                    .foregroundColor(.sMutedFG)
                                Text("No invoices yet")
                                    .font(.subheadline)
                                    .foregroundColor(.sMutedFG)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(vm.invoices.prefix(3).enumerated()), id: \.element.id) { idx, invoice in
                                    NavigationLink {
                                        InvoiceDetailView(invoiceID: invoice.id, vm: invoiceVM)
                                    } label: {
                                    HStack {
                                        Text(invoice.invoice_number)
                                            .font(.subheadline)
                                            .foregroundColor(.sForeground)
                                        Spacer()
                                        Text(Money.text(invoice.total)).moneyLine()
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.sForeground)
                                    }
                                    .padding(.horizontal, AppSpacing.page)
                                    .padding(.vertical, 12)
                                    }

                                    if idx < min(vm.invoices.count, 3) - 1 {
                                        Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.leading, 16)
                                    }
                                }
                            }
                        }
                    }
                    .background(Color.sCard)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
                    .cornerRadius(12)

                    // MARK: - Financial Actions
                    VStack(spacing: 10) {
                        NavigationLink {
                            LedgerListView(clientID: client.id)
                        } label: {
                            HStack {
                                Image(systemName: "book")
                                    .font(.subheadline.weight(.semibold))
                                Text("View ledger")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundColor(.sAccentFG)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.sPrimary)
                            .cornerRadius(10)
                        }

                        NavigationLink {
                            RecordPaymentView(
                                vm: RecordPaymentViewModel(
                                    companyID: SessionManager.shared.selectedCompanyId ?? 0,
                                    clientID: client.id,
                                    clientName: client.name,
                                    context: PaymentContext.client
                                )
                            )
                        } label: {
                            HStack {
                                Image(systemName: "creditcard")
                                    .font(.subheadline.weight(.semibold))
                                Text("Record payment")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundColor(.sForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.sCard)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(AppSpacing.card)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle(client.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load(clientID: client.id) }
        .sheet(isPresented: $invoiceVM.showPDF) {
            if let url = invoiceVM.pdfURL { PDFLookView(pdfURL: url) }
        }
        .sheet(isPresented: $invoiceVM.showEmailSheet) {
            if let id = invoiceVM.selectedEmailInvoiceID,
               let invoice = vm.invoices.first(where: { $0.id == id }) {
                SendEmailSheet(invoiceID: id, invoiceNumber: invoice.invoice_number,
                    vm: invoiceVM, onDismiss: { invoiceVM.showEmailSheet = false },
                    isReminder: invoiceVM.emailIsReminder)
                    .presentationDetents([.medium])
            }
        }
        .confirmationDialog("Select copy", isPresented: $invoiceVM.showCopyPicker) {
            ForEach(["original", "duplicate", "buyer"], id: \.self) { copy in
                Button(copy.capitalized) {
                    Task {
                        if let id = invoiceVM.selectedInvoiceID {
                            await invoiceVM.generateInvoicePDFFromServer(invoiceID: id, copy: copy)
                        }
                    }
                }
            }
        }
        .alert("Error", isPresented: $invoiceVM.showAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(invoiceVM.errorMessage ?? "Please try again.") }
    }
}

// MARK: - Detail Info Row
private struct DetailInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        if !value.isEmpty {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(.sMutedFG)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.sMutedFG)
                    Text(value)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.sForeground)
                        .lineLimit(1)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.page)
            .padding(.vertical, 12)
        }
    }
}
