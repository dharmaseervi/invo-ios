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
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.sMutedFG)

            VStack(spacing: 0) {
                // Client row
                Button(action: onSelectClient) {
                    HStack(spacing: 12) {
                        if let client = selectedClient {
                            if let quickSale = client.quickSaleAccount {
                                Image(systemName: quickSale.icon)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.sAccentFG)
                                    .frame(width: 40, height: 40)
                                    .background(Color.sAccent)
                                    .clipShape(.rect(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(client.name) sale")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.sForeground)
                                    Text("No customer details needed")
                                        .font(.footnote)
                                        .foregroundStyle(Color.sMutedFG)
                                }
                            } else {
                            Text(String(client.name.prefix(1)).uppercased())
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.sAccentFG)
                                .frame(width: 40, height: 40)
                                .background(Color.sAccent)
                                .clipShape(.rect(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.sForeground)
                                let secondary = client.email.isEmpty ? client.phone : client.email
                                if !secondary.isEmpty {
                                    Text(secondary)
                                        .font(.footnote)
                                        .foregroundStyle(Color.sMutedFG)
                                        .lineLimit(1)
                                }
                            }
                            }
                        } else {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.title3)
                                .foregroundStyle(Color.sAccent)
                                .frame(width: 40, height: 40)
                                .background(Color.sAccentMuted)
                                .clipShape(.rect(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Select client")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.sForeground)
                                Text("Choose who this invoice is for")
                                    .font(.footnote)
                                    .foregroundStyle(Color.sMutedFG)
                            }
                        }

                        Spacer()

                        Text(selectedClient == nil ? "" : "Change")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.sAccent)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.sMutedFG)
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
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Color.sMutedFG)
                            Spacer()
                            Toggle(isOn: $isShippingSameAsBilling) {
                                Text("Same as billing")
                                    .font(.footnote)
                                    .foregroundStyle(Color.sMutedFG)
                            }
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .tint(Color.sAccent)
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
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5) }
            .clipShape(.rect(cornerRadius: 12))
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
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.sMutedFG)
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
                        .font(.body)
                        .foregroundStyle(Color.sAccent)
                    Text(emptyText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.sAccent)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        if !address.name.isEmpty {
                            Text(address.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.sForeground)
                        }
                        Text(formatted(address))
                            .font(.subheadline)
                            .foregroundStyle(Color.sForeground)
                            .lineLimit(2)
                        if !address.gstNumber.isEmpty {
                            Text("GSTIN \(address.gstNumber)")
                                .font(.caption)
                                .foregroundStyle(Color.sMutedFG)
                        }
                    }
                    Spacer()
                    Text("Edit")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.sAccent)
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
