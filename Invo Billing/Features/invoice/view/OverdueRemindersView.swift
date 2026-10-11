import Combine
import SwiftUI

// MARK: - Per-client group

struct ClientOverdueGroup: Identifiable {
    let clientID: Int
    let clientName: String
    let phone: String           // may be empty
    var invoices: [InvoiceResponse]

    var id: Int { clientID }
    var totalOwed: Double { invoices.reduce(0) { $0 + $1.remaining_amount } }
    var oldestDue: String { invoices.map(\.due_date).min() ?? "" }
}

// MARK: - View

struct OverdueRemindersView: View {
    @StateObject private var vm = OverdueRemindersViewModel()

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView()
                    .tint(.sAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.groups.isEmpty {
                ContentUnavailableView(
                    "No overdue invoices",
                    systemImage: "checkmark.seal",
                    description: Text("All your invoices are either paid or not yet due.")
                )
            } else {
                List {
                    summaryCard
                        .padding(.horizontal, AppSpacing.page)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    ForEach(vm.groups) { group in
                        Section {
                            clientRow(group)
                                .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 8, trailing: 20))
                                .listRowSeparator(.hidden, edges: .top)
                            ForEach(group.invoices) { inv in
                                invoiceRow(inv)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 72, bottom: 6, trailing: 20))
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .contentMargins(.bottom, 16, for: .scrollContent)
                .refreshable { await vm.load() }
            }
        }
        .navigationTitle("Overdue reminders")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Total overdue")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Money.text(vm.totalOverdue)).moneyLine()
                    .font(.title.bold())
                    .foregroundStyle(Color.sDestructive)
                Text("\(vm.groups.count) client\(vm.groups.count == 1 ? "" : "s") overdue")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button {
                vm.sendAll()
            } label: {
                Label("Remind all", systemImage: "message.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(.sAccent)
            .disabled(vm.groups.filter { !$0.phone.isEmpty }.isEmpty)
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Rows

    private func clientRow(_ group: ClientOverdueGroup) -> some View {
        HStack(spacing: 12) {
            MinimalAvatarView(name: group.clientName)

            VStack(alignment: .leading, spacing: 3) {
                Text(group.clientName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(group.invoices.count) invoice\(group.invoices.count == 1 ? "" : "s") · due since \(AppDate.shortText(fromWire: group.oldestDue))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(Money.text(group.totalOwed)).moneyLine()
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.sDestructive)
                if !group.phone.isEmpty {
                    Button {
                        sendWhatsApp(to: group.phone, name: group.clientName,
                                     amount: group.totalOwed, invoices: group.invoices)
                    } label: {
                        Label("WhatsApp", systemImage: "message")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.sAccent)
                    }
                    .buttonStyle(.borderless)
                } else {
                    Text("No phone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 88, alignment: .trailing)
        }
    }

    private func invoiceRow(_ inv: InvoiceResponse) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(inv.invoice_number)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                Text("\(inv.days_overdue)d overdue")
                    .font(.caption)
                    .foregroundStyle(Color.sDestructive)
            }
            Spacer(minLength: 8)
            Text(Money.text(inv.remaining_amount)).moneyLine()
                .font(.footnote.weight(.medium))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - WhatsApp

    private func sendWhatsApp(to phone: String, name: String, amount: Double, invoices: [InvoiceResponse]) {
        let clean = phone.filter { $0.isNumber }
        let full = clean.hasPrefix("91") ? clean : "91\(clean)"
        let invoiceList = invoices.map { "• \($0.invoice_number) — \(Money.text($0.remaining_amount))" }.joined(separator: "\n")
        let message = """
Hi \(name),

This is a friendly reminder that the following invoice\(invoices.count == 1 ? "" : "s") \(invoices.count == 1 ? "is" : "are") overdue:

\(invoiceList)

Total outstanding: \(Money.text(amount))

Please arrange payment at your earliest convenience. Thank you.
"""
        guard let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "whatsapp://send?phone=\(full)&text=\(encoded)") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - ViewModel

@MainActor
final class OverdueRemindersViewModel: ObservableObject {
    @Published private(set) var groups: [ClientOverdueGroup] = []
    @Published private(set) var isLoading = false

    private let service = InvoiceService()

    var totalOverdue: Double { groups.reduce(0) { $0 + $1.totalOwed } }

    func load() async {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await service.getInvoices(
                companyID: companyID, status: "overdue", limit: 200, offset: 0
            )
            groups = buildGroups(result.data)
        } catch {}
    }

    func sendAll() {
        for group in groups where !group.phone.isEmpty {
            sendWhatsApp(to: group.phone, name: group.clientName,
                         amount: group.totalOwed, invoices: group.invoices)
        }
    }

    private func sendWhatsApp(to phone: String, name: String, amount: Double, invoices: [InvoiceResponse]) {
        let clean = phone.filter { $0.isNumber }
        let full = clean.hasPrefix("91") ? clean : "91\(clean)"
        let invoiceList = invoices.map { "• \($0.invoice_number) — \(Money.text($0.remaining_amount))" }.joined(separator: "\n")
        let message = """
Hi \(name),

This is a friendly reminder that the following invoice\(invoices.count == 1 ? "" : "s") \(invoices.count == 1 ? "is" : "are") overdue:

\(invoiceList)

Total outstanding: \(Money.text(amount))

Please arrange payment at your earliest convenience. Thank you.
"""
        guard let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "whatsapp://send?phone=\(full)&text=\(encoded)") else { return }
        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }

    private func buildGroups(_ invoices: [InvoiceResponse]) -> [ClientOverdueGroup] {
        var map: [Int: ClientOverdueGroup] = [:]
        for inv in invoices {
            let key = inv.client_id
            if map[key] == nil {
                map[key] = ClientOverdueGroup(
                    clientID: key,
                    clientName: inv.client_name ?? "Unknown",
                    phone: inv.client_phone ?? "",
                    invoices: []
                )
            }
            map[key]?.invoices.append(inv)
        }
        return map.values.sorted { $0.totalOwed > $1.totalOwed }
    }
}
