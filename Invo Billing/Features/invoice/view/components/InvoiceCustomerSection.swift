import SwiftUI

/// Customer block for invoice / credit-note forms.
/// Before a client is chosen it shows a single "Select client" row.
/// After selection it shows the client with Bill-to / Ship-to summaries,
/// the way Zoho / QuickBooks / FreshBooks present it.
struct InvoiceCustomerSection: View {
    let selectedClient: ClientModel?
    let billingAddress: AddressFormModel
    let shippingAddress: AddressFormModel
    @Binding var isShippingSameAsBilling: Bool

    let onSelectClient: () -> Void
    let onEditBilling: () -> Void
    let onEditShipping: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Customer")
                .font(.scaled(13, weight: .medium))
                .foregroundColor(.sMutedFG)

            VStack(spacing: 0) {
                // Client row
                Button(action: onSelectClient) {
                    HStack(spacing: 12) {
                        if let client = selectedClient {
                            if let quickSale = client.quickSaleAccount {
                                Image(systemName: quickSale.icon)
                                    .font(.scaled(16, weight: .semibold))
                                    .foregroundColor(.sAccentFG)
                                    .frame(width: 40, height: 40)
                                    .background(Color.sAccent)
                                    .cornerRadius(10)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(client.name) sale")
                                        .font(.scaled(15, weight: .semibold))
                                        .foregroundColor(.sForeground)
                                    Text("No customer details needed")
                                        .font(.scaled(12))
                                        .foregroundColor(.sMutedFG)
                                }
                            } else {
                            Text(String(client.name.prefix(1)).uppercased())
                                .font(.scaled(14, weight: .semibold))
                                .foregroundColor(.sAccentFG)
                                .frame(width: 40, height: 40)
                                .background(Color.sAccent)
                                .cornerRadius(10)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.name)
                                    .font(.scaled(15, weight: .semibold))
                                    .foregroundColor(.sForeground)
                                let secondary = client.email.isEmpty ? client.phone : client.email
                                if !secondary.isEmpty {
                                    Text(secondary)
                                        .font(.scaled(12))
                                        .foregroundColor(.sMutedFG)
                                        .lineLimit(1)
                                }
                            }
                            }
                        } else {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.scaled(20))
                                .foregroundColor(.sAccent)
                                .frame(width: 40, height: 40)
                                .background(Color.sAccentMuted)
                                .cornerRadius(10)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Select client")
                                    .font(.scaled(15, weight: .medium))
                                    .foregroundColor(.sForeground)
                                Text("Choose who this invoice is for")
                                    .font(.scaled(12))
                                    .foregroundColor(.sMutedFG)
                            }
                        }

                        Spacer()

                        Text(selectedClient == nil ? "" : "Change")
                            .font(.scaled(13, weight: .medium))
                            .foregroundColor(.sAccent)
                        Image(systemName: "chevron.right")
                            .font(.scaled(12, weight: .semibold))
                            .foregroundColor(.sMutedFG)
                    }
                    .padding(14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if let client = selectedClient, !client.isQuickSaleAccount {
                    Rectangle().fill(Color.sBorder).frame(height: 0.5)

                    addressRow(
                        title: "Bill to",
                        address: billingAddress,
                        emptyText: "Add billing address",
                        action: onEditBilling
                    )

                    Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.leading, 14)

                    // Ship to
                    VStack(spacing: 0) {
                        HStack {
                            Text("Ship to")
                                .font(.scaled(12, weight: .medium))
                                .foregroundColor(.sMutedFG)
                            Spacer()
                            Toggle(isOn: $isShippingSameAsBilling) {
                                Text("Same as billing")
                                    .font(.scaled(12))
                                    .foregroundColor(.sMutedFG)
                            }
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .tint(.sAccent)
                            .fixedSize()
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, isShippingSameAsBilling ? 12 : 6)

                        if !isShippingSameAsBilling {
                            addressBody(
                                address: shippingAddress,
                                emptyText: "Add shipping address",
                                action: onEditShipping
                            )
                            .padding(.bottom, 12)
                        }
                    }
                }
            }
            .background(Color.sCard)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
            .cornerRadius(12)
        }
    }

    // MARK: - Pieces

    private func addressRow(
        title: String,
        address: AddressFormModel,
        emptyText: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.scaled(12, weight: .medium))
                .foregroundColor(.sMutedFG)
            addressBody(address: address, emptyText: emptyText, action: action)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func addressBody(
        address: AddressFormModel,
        emptyText: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                if address.isEmpty {
                    Image(systemName: "plus.circle")
                        .font(.scaled(14))
                        .foregroundColor(.sAccent)
                    Text(emptyText)
                        .font(.scaled(13, weight: .medium))
                        .foregroundColor(.sAccent)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        if !address.name.isEmpty {
                            Text(address.name)
                                .font(.scaled(13, weight: .medium))
                                .foregroundColor(.sForeground)
                        }
                        Text(formatted(address))
                            .font(.scaled(13))
                            .foregroundColor(.sForeground)
                            .lineLimit(2)
                        if !address.gstNumber.isEmpty {
                            Text("GSTIN \(address.gstNumber)")
                                .font(.scaled(11))
                                .foregroundColor(.sMutedFG)
                        }
                    }
                    Spacer()
                    Text("Edit")
                        .font(.scaled(13, weight: .medium))
                        .foregroundColor(.sAccent)
                }
            }
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -14)
    }

    private func formatted(_ a: AddressFormModel) -> String {
        var parts: [String] = []
        if !a.line1.isEmpty { parts.append(a.line1) }
        if !a.line2.isEmpty { parts.append(a.line2) }
        let cityState = [a.city, a.state].filter { !$0.isEmpty }.joined(separator: ", ")
        var cityLine = cityState
        if !a.postalCode.isEmpty { cityLine += cityLine.isEmpty ? a.postalCode : " \(a.postalCode)" }
        if !cityLine.isEmpty { parts.append(cityLine) }
        return parts.joined(separator: ", ")
    }
}
