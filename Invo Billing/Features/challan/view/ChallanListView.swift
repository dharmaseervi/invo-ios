import SwiftUI

struct ChallanListView: View {
    @StateObject private var vm = ChallanViewModel()
    @State private var showCreate = false

    var body: some View {
        contentArea
            .navigationTitle("Delivery Challans")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showCreate = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreate, onDismiss: {
                Task { await vm.loadChallans() }
            }) {
                CreateChallanView(vm: vm)
            }
            .alert("Error", isPresented: $vm.showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .task { await vm.loadChallans() }
    }

    @ViewBuilder
    private var contentArea: some View {
        if vm.isLoading && vm.challans.isEmpty {
            VStack(spacing: 12) {
                ProgressView().tint(.sAccent)
                Text("Loading challans...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.challans.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "shippingbox")
                    .font(.scaled(40))
                    .foregroundStyle(.secondary)
                Text("No delivery challans")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Create a challan to track dispatched goods")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(action: { showCreate = true }) {
                    Text("New Challan")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.sAccentFG)
                        .padding(.horizontal, AppSpacing.page)
                        .padding(.vertical, 10)
                        .background(Color.sPrimary)
                        .cornerRadius(8)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(vm.challans) { challan in
                    NavigationLink {
                        ChallanDetailView(challanID: challan.id, vm: vm)
                    } label: {
                        ChallanRow(challan: challan)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden, edges: challan.id == vm.challans.first?.id ? .top : [])
                }
            }
            .listStyle(.plain)
            .contentMargins(.bottom, 16, for: .scrollContent)
            .refreshable { await vm.loadChallans() }
        }
    }
}

private struct ChallanRow: View {
    let challan: ChallanResponse

    private var statusColor: Color {
        challan.status == .dispatched ? .sSuccess : .sNeutral
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.sAccentMuted)
                    .frame(width: 40, height: 40)
                Image(systemName: "shippingbox")
                    .font(.body)
                    .foregroundStyle(Color.sAccent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(challan.challan_number)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(challan.client_name ?? "—")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(challan.status.rawValue.capitalized)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(statusColor.opacity(0.1)))
                Text(AppDate.text(fromWire: String(challan.challan_date.prefix(10))))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
