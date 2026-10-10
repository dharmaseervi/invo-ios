import SwiftUI

struct ChallanListView: View {
    @StateObject private var vm = ChallanViewModel()
    @State private var showCreate = false

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            Group {
                if vm.isLoading && vm.challans.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView().tint(.sAccent)
                        Text("Loading challans...")
                            .font(.scaled(13))
                            .foregroundColor(.sMutedFG)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.challans.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "shippingbox")
                            .font(.scaled(40))
                            .foregroundColor(.sMutedFG)
                        Text("No delivery challans")
                            .font(.scaled(15, weight: .semibold))
                            .foregroundColor(.sForeground)
                        Text("Create a challan to track dispatched goods")
                            .font(.scaled(13))
                            .foregroundColor(.sMutedFG)
                            .multilineTextAlignment(.center)
                        Button(action: { showCreate = true }) {
                            Text("New Challan")
                                .font(.scaled(13, weight: .semibold))
                                .foregroundColor(.sAccentFG)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.sPrimary)
                                .cornerRadius(8)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(vm.challans) { challan in
                                NavigationLink {
                                    ChallanDetailView(challanID: challan.id, vm: vm)
                                } label: {
                                    ChallanRow(challan: challan)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .refreshable { await vm.loadChallans() }
                }
            }
        }
        .navigationTitle("Delivery Challans")
        .navigationBarTitleDisplayMode(.inline)
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
}

private struct ChallanRow: View {
    let challan: ChallanResponse

    private var statusColor: Color {
        challan.status == .dispatched ? Color(red: 0.086, green: 0.639, blue: 0.341) : Color(UIColor.systemGray)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.sAccentMuted)
                    .frame(width: 42, height: 42)
                Image(systemName: "shippingbox")
                    .font(.scaled(16))
                    .foregroundColor(.sAccent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(challan.challan_number)
                    .font(.scaled(13, weight: .semibold))
                    .foregroundColor(.sForeground)
                Text(challan.client_name ?? "Client #\(challan.client_id)")
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(challan.status.rawValue.capitalized)
                    .font(.scaled(11, weight: .medium))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(statusColor.opacity(0.1)))
                Text(challan.challan_date.prefix(10))
                    .font(.scaled(11))
                    .foregroundColor(.sMutedFG)
            }
        }
        .padding(14)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(10)
    }
}
