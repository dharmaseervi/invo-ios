import SwiftUI

struct ClientDetailedView: View {
    let client: ClientModel
    @Environment(\.dismiss) var dismiss

    var avatarLetter: String {
        String(client.name.prefix(1)).uppercased()
    }
    @StateObject private var vm = ClientViewModel()

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {

                    // MARK: - Profile Header
                    VStack(spacing: 14) {
                        Text(avatarLetter)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.sAccentFG)
                            .frame(width: 72, height: 72)
                            .background(Color.sAccent)
                            .cornerRadius(16)

                        Text(client.name)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.sForeground)
                    }
                    .padding(.top, 20)

                    // MARK: - Contact Information Section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Contact information")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.sMutedFG)
                            .padding(.horizontal, 16)
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

                    // MARK: - Address Section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Address")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.sMutedFG)
                            .padding(.horizontal, 16)
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

                    // MARK: - Invoices Section
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Invoices")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.sMutedFG)
                            Spacer()
                            Text("View all")
                                .font(.system(size: 13))
                                .foregroundColor(.sAccent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 10)

                        Rectangle().fill(Color.sBorder).frame(height: 0.5)

                        if vm.invoices.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 22))
                                    .foregroundColor(.sMutedFG)
                                Text("No invoices yet")
                                    .font(.system(size: 13))
                                    .foregroundColor(.sMutedFG)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(vm.invoices.prefix(3).enumerated()), id: \.element.id) { idx, invoice in
                                    HStack {
                                        Text(invoice.invoice_number)
                                            .font(.system(size: 13))
                                            .foregroundColor(.sForeground)
                                        Spacer()
                                        Text("₹\(invoice.total, specifier: "%.2f")")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.sForeground)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)

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
                                    .font(.system(size: 13, weight: .semibold))
                                Text("View ledger")
                                    .font(.system(size: 14, weight: .semibold))
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
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Record payment")
                                    .font(.system(size: 14, weight: .semibold))
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
                .padding(20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle(client.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await vm.load(clientID: client.id) }
        }
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
                    .font(.system(size: 13))
                    .foregroundColor(.sMutedFG)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 11))
                        .foregroundColor(.sMutedFG)
                    Text(value)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.sForeground)
                        .lineLimit(1)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}
