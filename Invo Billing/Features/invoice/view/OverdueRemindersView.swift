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
    @Environment(\.scenePhase) private var scenePhase
    @State private var leftForWhatsApp = false

    var body: some View {
        Group {
            if vm.isLoading && vm.groups.isEmpty {
                ProgressView()
                    .tint(.sAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.loadFailed && vm.groups.isEmpty {
                // Not the "all paid" state: a failed fetch says nothing about what is owed.
                ContentUnavailableView {
                    Label("Couldn't load overdue invoices", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Check your connection and try again.")
                } actions: {
                    Button("Try again") { Task { await vm.load() } }
                        .buttonStyle(.borderedProminent)
                        .tint(.sAccent)
                }
            } else if vm.groups.isEmpty {
                ContentUnavailableView(
                    "No overdue invoices",
                    systemImage: "checkmark.seal",
                    description: Text("All your invoices are either paid or not yet due.")
                )
            } else {
                List {
                    summaryCard.listHeaderRow()

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
        // iOS opens one app at a time, so "Remind all" sends the next chat each time the
        // shop comes back from WhatsApp, instead of firing every link at once.
        .onChange(of: scenePhase) { _, phase in
            // Only after really leaving: Control Center also passes through inactive.
            if phase == .background { leftForWhatsApp = true }
            if phase == .active, leftForWhatsApp {
                leftForWhatsApp = false
                vm.sendNextQueued()
            }
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        SummaryCard(
            title: "Total overdue",
            value: Money.text(vm.totalOverdue),
            valueColor: .sDestructive
        ) {
            Text("\(vm.groups.count) client\(vm.groups.count == 1 ? "" : "s") overdue")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Group {
                if let progress = vm.queueProgress {
                    HStack {
                        Text("Reminder \(progress.sent) of \(progress.total) sent")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Stop") { vm.stopQueue() }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.sAccent)
                            .buttonStyle(.borderless)
                    }
                } else {
                    Button {
                        vm.sendAll()
                    } label: {
                        Label("Remind all on WhatsApp", systemImage: "message.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.sAccent)
                    .disabled(vm.reachableCount == 0)
                }
            }
            .padding(.top, 10)
        }
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
                        vm.send(group)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "message")
                            Text("WhatsApp")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.sAccent)
                        .fixedSize()
                        // Taller hit area without a taller row.
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                        .padding(.vertical, -10)
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
}

// MARK: - ViewModel

@MainActor
final class OverdueRemindersViewModel: ObservableObject {
    @Published private(set) var groups: [ClientOverdueGroup] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadFailed = false
    @Published private(set) var queueProgress: (sent: Int, total: Int)?

    private var queue: [ClientOverdueGroup] = []
    private let service = InvoiceService()

    var totalOverdue: Double { groups.reduce(0) { $0 + $1.totalOwed } }
    var reachableCount: Int { groups.filter { !$0.phone.isEmpty }.count }

    func load() async {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await service.getInvoices(
                companyID: companyID, status: "overdue", limit: 200, offset: 0
            )
            groups = buildGroups(result.data)
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    func send(_ group: ClientOverdueGroup) {
        WhatsApp.open(phone: group.phone, message: Self.message(for: group))
    }

    func sendAll() {
        queue = groups.filter { !$0.phone.isEmpty }
        guard !queue.isEmpty else { return }
        queueProgress = (0, queue.count)
        sendNextQueued()
    }

    /// Sends the next queued reminder. Called on start and each time the app becomes
    /// active again after WhatsApp.
    func sendNextQueued() {
        guard let progress = queueProgress else { return }
        guard !queue.isEmpty else {
            queueProgress = nil
            return
        }
        let next = queue.removeFirst()
        queueProgress = (progress.sent + 1, progress.total)
        send(next)
    }

    func stopQueue() {
        queue = []
        queueProgress = nil
    }

    private static func message(for group: ClientOverdueGroup) -> String {
        let invoices = group.invoices
        let invoiceList = invoices
            .map { "• \($0.invoice_number) — \(Money.text($0.remaining_amount))" }
            .joined(separator: "\n")
        return """
Hi \(group.clientName),

This is a friendly reminder that the following invoice\(invoices.count == 1 ? "" : "s") \(invoices.count == 1 ? "is" : "are") overdue:

\(invoiceList)

Total outstanding: \(Money.text(group.totalOwed))

Please arrange payment at your earliest convenience. Thank you.
"""
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
