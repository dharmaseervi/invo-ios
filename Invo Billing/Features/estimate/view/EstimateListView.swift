import SwiftUI

struct EstimateListView: View {
    @StateObject private var vm = EstimateViewModel()
    @State private var searchText = ""

    var filteredEstimates: [EstimateResponse] {
        if searchText.isEmpty { return vm.estimates }
        return vm.estimates.filter {
            $0.estimate_number.localizedCaseInsensitiveContains(searchText)
            || ($0.client_name ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                if vm.isFetchingList {
                    Spacer()
                    ProgressView().tint(.sAccent)
                    Spacer()
                } else if vm.estimates.isEmpty {
                    emptyState
                } else {
                    searchBar.padding(.top, 16)

                    if filteredEstimates.isEmpty {
                        noResultsState
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 10) {
                                ForEach(filteredEstimates) { estimate in
                                    NavigationLink {
                                        EstimateDetailView(estimateID: estimate.id, vm: vm)
                                    } label: {
                                        EstimateRowCard(estimate: estimate)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(20)
                        }
                        .refreshable { await vm.fetchEstimates() }
                    }
                }
            }
        }
        .navigationTitle("Estimates")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: CreateEstimateView()) {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await vm.fetchEstimates() }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.scaled(14))
                .foregroundColor(.sMutedFG)
            TextField("Search estimates...", text: $searchText)
                .font(.scaled(14))
                .foregroundColor(.sForeground)
                .tint(.sAccent)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.scaled(14))
                        .foregroundColor(.sMutedFG)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sInput, lineWidth: 0.5))
        .cornerRadius(8)
        .padding(.horizontal, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.badge.clock")
                .font(.scaled(40))
                .foregroundColor(.sMutedFG)
            VStack(spacing: 4) {
                Text("No estimates yet")
                    .font(.scaled(15, weight: .semibold))
                    .foregroundColor(.sForeground)
                Text("Send a quote before you bill — create your first estimate")
                    .font(.scaled(13))
                    .foregroundColor(.sMutedFG)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            NavigationLink(destination: CreateEstimateView()) {
                Text("Create estimate")
                    .font(.scaled(13, weight: .semibold))
                    .foregroundColor(.sAccentFG)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.sPrimary)
                    .cornerRadius(8)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.scaled(22))
                .foregroundColor(.sMutedFG)
            Text("No matching estimates")
                .font(.scaled(14, weight: .medium))
                .foregroundColor(.sForeground)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row
private struct EstimateRowCard: View {
    let estimate: EstimateResponse

    var statusConfig: (label: String, color: Color) {
        switch estimate.status {
        case .draft:     return ("Draft", Color(UIColor.systemGray))
        case .sent:      return ("Sent", .sAccent)
        case .accepted:  return ("Accepted", Color(red: 0.086, green: 0.639, blue: 0.341))
        case .rejected:  return ("Rejected", Color(red: 0.863, green: 0.149, blue: 0.149))
        case .expired:   return ("Expired", Color(red: 0.722, green: 0.494, blue: 0.051))
        case .converted: return ("Converted", Color(red: 0.086, green: 0.639, blue: 0.341))
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(statusConfig.color)
                .frame(width: 3)
                .padding(.vertical, 10)

            HStack(spacing: 12) {
                MinimalAvatarView(name: estimate.client_name ?? "?")

                VStack(alignment: .leading, spacing: 3) {
                    Text(estimate.client_name ?? "Client")
                        .font(.scaled(14, weight: .medium))
                        .foregroundColor(.sForeground)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(estimate.estimate_number)
                        // The invoice row carries a date; this one did not, so the two
                        // lists read as different kinds of record.
                        Text("·")
                        Text(AppDate.text(fromWire: estimate.estimate_date))
                    }
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
                    .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    Text(Money.text(estimate.total)).moneyLine()
                        .font(.scaled(14, weight: .semibold))
                        .foregroundColor(.sForeground)
                    Text(statusConfig.label)
                        .font(.scaled(10, weight: .medium))
                        .foregroundColor(statusConfig.color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(statusConfig.color.opacity(0.1)))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(14)
    }
}
