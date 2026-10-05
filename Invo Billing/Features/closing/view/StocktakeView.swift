//
//  StocktakeView.swift
//  Invo Billing
//
//  Counting the floor against what the books say.
//

import SwiftUI

struct StocktakeView: View {
    @StateObject private var vm = StocktakeViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showItemPicker = false
    @State private var countingItem: ItemResponse?
    @State private var showFinishConfirm = false
    @State private var showDiscardConfirm = false

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            if vm.isLoading && vm.stocktake == nil {
                ProgressView().tint(.sAccent)
            } else {
                ScrollView {
                    // A plain stack: a count is a few dozen lines at most, and inside a
                    // lazy one the rows were built and never laid out.
                    VStack(alignment: .leading, spacing: 12) {
                        progressCard

                        if vm.hasCounted {
                            ForEach(vm.lines) { line in
                                lineCard(line)
                            }
                        } else {
                            emptyState
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                .refreshable { await vm.reload() }
            }
        }
        .navigationTitle("Stock count")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showItemPicker = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(vm.stocktake == nil)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if vm.hasCounted {
                finishBar
            }
        }
        .task { await vm.begin() }
        .sheet(isPresented: $showItemPicker) {
            StocktakeItemPicker { item in countingItem = item }
        }
        .sheet(item: $countingItem) { item in
            NavigationStack {
                CountItemSheet(item: item, vm: vm)
            }
            .presentationDetents([.height(300)])
        }
        .alert("Finish the count?", isPresented: $showFinishConfirm) {
            Button("Keep counting", role: .cancel) {}
            Button("Finish") {
                Task { if await vm.apply() { dismiss() } }
            }
        } message: {
            // Said in terms of what will change, because this is the moment stock
            // figures move and there is no undo for it.
            Text(vm.itemsOff == 0
                 ? "Everything you counted matches the books. Nothing will change."
                 : "Stock will be corrected for \(vm.itemsOff) item\(vm.itemsOff == 1 ? "" : "s"). Anything sold while you were counting is kept.")
        }
        .alert("Throw this count away?", isPresented: $showDiscardConfirm) {
            Button("Keep counting", role: .cancel) {}
            Button("Throw away", role: .destructive) {
                Task { if await vm.abandon() { dismiss() } }
            }
        } message: {
            Text("Nothing will change. You can start a new count later.")
        }
        .alert("Stock count", isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Something went wrong")
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Counted so far")
                .font(.scaled(13))
                .foregroundColor(.sMutedFG)
            Text("\(vm.lines.count) item\(vm.lines.count == 1 ? "" : "s")")
                .font(.scaled(24, weight: .bold))
                .foregroundColor(.sForeground)
            Text(vm.itemsOff == 0
                 ? "All matching the books so far"
                 : "\(vm.itemsOff) not matching the books")
                .font(.scaled(12))
                .foregroundColor(vm.itemsOff == 0
                                 ? Color(red: 0.086, green: 0.639, blue: 0.341)
                                 : .sDestructive)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(16)
    }

    private func lineCard(_ line: StocktakeLine) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(line.item_name)
                    .font(.scaled(14, weight: .medium))
                    .foregroundColor(.sForeground)
                Text("Books said \(line.expected) · you counted \(line.counted)")
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
            }
            Spacer()
            Text(line.varianceText)
                .font(.scaled(12, weight: .medium))
                .foregroundColor(line.isOff ? .sDestructive : Color(red: 0.086, green: 0.639, blue: 0.341))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (line.isOff ? Color.sDestructive : Color(red: 0.086, green: 0.639, blue: 0.341))
                        .opacity(0.12)
                )
                .cornerRadius(6)
        }
        .padding(14)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(14)
    }

    private var finishBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.sBorder).frame(height: 0.5)
            HStack(spacing: 14) {
                Button("Throw away") { showDiscardConfirm = true }
                    .font(.scaled(14))
                    .foregroundColor(.sDestructive)
                Spacer()
                Button {
                    showFinishConfirm = true
                } label: {
                    Text("Finish count")
                        .font(.scaled(15, weight: .semibold))
                        .foregroundColor(.sAccentFG)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 13)
                        .background(Color.sPrimary)
                        .cornerRadius(10)
                }
                .disabled(vm.isWorking)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.sBackground)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checklist")
                .font(.scaled(30))
                .foregroundColor(.sMutedFG)
            Text("Nothing counted yet")
                .font(.scaled(15, weight: .medium))
                .foregroundColor(.sForeground)
            Text("Add an item, type what is actually on the floor, and the app works out what is missing. You can stop and come back — the count waits for you.")
                .font(.scaled(12))
                .foregroundColor(.sMutedFG)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Button("Count an item") { showItemPicker = true }
                .font(.scaled(14, weight: .medium))
                .foregroundColor(.sAccent)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Typing one count

private struct CountItemSheet: View {
    let item: ItemResponse
    @ObservedObject var vm: StocktakeViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var counted = ""
    @FocusState private var focused: Bool

    var body: some View {
        Form {
            Section {
                LabeledContent("Books say", value: "\(item.quantity)")
                TextField("How many are there?", text: $counted)
                    .keyboardType(.numberPad)
                    .focused($focused)
            } header: {
                Text(item.name)
            } footer: {
                // The difference said out loud before anything is saved, so a typo is
                // obvious while the item is still in the person's hands.
                if let value = Int(counted) {
                    let variance = value - item.quantity
                    if variance == 0 {
                        Text("Matches the books.")
                    } else if variance < 0 {
                        Text("\(abs(variance)) fewer than the books say.")
                            .foregroundColor(.sDestructive)
                    } else {
                        Text("\(variance) more than the books say.")
                    }
                }
            }
        }
        .navigationTitle("Count")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    guard let value = Int(counted), value >= 0 else { return }
                    Task {
                        await vm.count(itemID: item.id, counted: value)
                        dismiss()
                    }
                }
                .disabled(Int(counted) == nil || vm.isWorking)
            }
        }
        .onAppear { focused = true }
    }
}

/// Picking the item being counted. The catalogue, searchable, with the figure the books
/// currently hold beside each one.
private struct StocktakeItemPicker: View {
    let onPick: (ItemResponse) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var itemVM = ItemViewModel()
    @State private var search = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(itemVM.items.filter {
                    search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
                }) { item in
                    Button {
                        onPick(item)
                        dismiss()
                    } label: {
                        HStack {
                            Text(item.name).foregroundColor(.sForeground)
                            Spacer()
                            Text("\(item.quantity)")
                                .font(.scaled(13))
                                .foregroundColor(.sMutedFG)
                        }
                    }
                }
            }
            .searchable(text: $search)
            .navigationTitle("Count which item?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await itemVM.loadItems() }
        }
    }
}
