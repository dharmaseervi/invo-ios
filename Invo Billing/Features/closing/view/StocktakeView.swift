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
        Group {
            if vm.isLoading && vm.stocktake == nil {
                ProgressView()
                    .tint(.sAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    progressCard
                        .padding(.horizontal, AppSpacing.page)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    if vm.hasCounted {
                        ForEach(vm.lines) { line in
                            lineRow(line)
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                .listRowSeparator(.hidden, edges: line.id == vm.lines.first?.id ? .top : [])
                        }
                    } else {
                        emptyState
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
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
        VStack(alignment: .leading, spacing: 1) {
            Text("Counted so far")
                .font(.subheadline)
                .foregroundColor(.sMutedFG)
            Text("\(vm.lines.count) item\(vm.lines.count == 1 ? "" : "s")")
                .font(.title.bold())
                .foregroundColor(.sForeground)
            Text(vm.itemsOff == 0
                 ? "All matching the books so far"
                 : "\(vm.itemsOff) not matching the books")
                .font(.footnote)
                .foregroundColor(vm.itemsOff == 0
                                 ? .sSuccess
                                 : .sDestructive)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func lineRow(_ line: StocktakeLine) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(line.item_name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.sForeground)
                Text("Books said \(line.expected) · you counted \(line.counted)")
                    .font(.footnote)
                    .foregroundColor(.sMutedFG)
            }
            Spacer(minLength: 8)
            Text(line.varianceText)
                .font(.caption.weight(.medium))
                .foregroundColor(line.isOff ? .sDestructive : .sSuccess)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background((line.isOff ? Color.sDestructive : .sSuccess).opacity(0.1), in: Capsule())
        }
    }

    private var finishBar: some View {
        HStack(spacing: 14) {
            Button("Throw away", role: .destructive) { showDiscardConfirm = true }
                .font(.subheadline)
            Spacer()
            Button("Finish count") { showFinishConfirm = true }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(.sAccent)
                .disabled(vm.isWorking)
        }
        .padding(.horizontal, AppSpacing.page)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing counted yet", systemImage: "checklist")
        } description: {
            Text("Add an item, type what is actually on the floor, and the app works out what is missing. You can stop and come back — the count waits for you.")
        } actions: {
            Button("Count an item") { showItemPicker = true }
                .buttonStyle(.borderedProminent)
                .tint(.sAccent)
        }
        .padding(.vertical, 16)
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
                                .font(.subheadline)
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
