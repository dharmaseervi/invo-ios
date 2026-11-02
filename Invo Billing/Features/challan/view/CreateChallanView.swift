import SwiftUI

struct CreateChallanView: View {
    @ObservedObject var vm: ChallanViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showClientPicker = false
    @State private var showItemPicker = false
    @State private var confirmDiscard = false
    @State private var initialDate = Date()
    private var isDirty: Bool { vm.selectedClient != nil || !vm.items.isEmpty || !vm.notes.isEmpty || !Calendar.current.isDate(vm.challanDate, inSameDayAs: initialDate) }
    @State private var tempItems: [InvoiceLineItem] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sBackground.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {

                        // MARK: - Client
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Customer")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.sMutedFG)

                            Button { showClientPicker = true } label: {
                                HStack(spacing: 12) {
                                    if let client = vm.selectedClient {
                                        MinimalAvatarView(name: client.name)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(client.name)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(Color.sForeground)
                                        }
                                    } else {
                                        Image(systemName: "person.crop.circle.badge.plus")
                                            .font(.title3)
                                            .foregroundStyle(Color.sAccent)
                                        Text("Select client")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Color.sForeground)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Color.sMutedFG)
                                }
                                .padding(14)
                            }
                            .background(Color.sCard)
                            .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5) }
                            .clipShape(.rect(cornerRadius: 12))
                        }
                        .padding(.horizontal, AppSpacing.page)

                        // MARK: - Details
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Details")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.sMutedFG)

                            VStack(spacing: 0) {
                                DatePicker(selection: $vm.challanDate, displayedComponents: .date) {
                                    Text("Challan date")
                                        .font(.body)
                                        .foregroundStyle(Color.sForeground)
                                }
                                .font(.body)
                                .tint(Color.sAccent)
                                .padding(14)

                                Rectangle().fill(Color.sBorder).frame(height: 0.5)

                                HStack(alignment: .top, spacing: 0) {
                                    Text("Notes")
                                        .font(.body)
                                        .foregroundStyle(Color.sForeground)
                                        .padding(.top, 2)
                                    Spacer()
                                    TextField("Optional", text: $vm.notes, axis: .vertical)
                                        .font(.body)
                                        .foregroundStyle(Color.sForeground)
                                        .tint(Color.sAccent)
                                        .multilineTextAlignment(.trailing)
                                        .lineLimit(1...4)
                                        .frame(maxWidth: 220)
                                }
                                .padding(14)
                            }
                            .background(Color.sCard)
                            .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5) }
                            .clipShape(.rect(cornerRadius: 12))
                        }
                        .padding(.horizontal, AppSpacing.page)

                        // MARK: - Items
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Items")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.sMutedFG)

                            VStack(spacing: 0) {
                                if vm.items.isEmpty {
                                    Button(action: { showItemPicker = true }) {
                                        HStack(spacing: 14) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.sBorder, style: StrokeStyle(lineWidth: 1, dash: [4]))
                                                    .frame(width: 38, height: 38)
                                                Image(systemName: "plus")
                                                    .font(.body)
                                                    .foregroundStyle(Color.sMutedFG)
                                            }
                                            Text("Add items to dispatch")
                                                .font(.body)
                                                .foregroundStyle(Color.sMutedFG)
                                            Spacer()
                                        }
                                        .padding(14)
                                    }
                                } else {
                                    ForEach($vm.items) { $line in
                                        AdaptiveFormRow {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(line.name)
                                                    .font(.subheadline.weight(.medium))
                                                    .foregroundStyle(Color.sForeground)
                                                TextField("Description (optional)", text: $line.description)
                                                    .font(.footnote)
                                                    .foregroundStyle(Color.sMutedFG)
                                                    .tint(Color.sAccent)
                                            }
                                            Spacer()
                                            HStack(spacing: 10) {
                                                Button(action: {
                                                    if line.qty > 1 { line.qty -= 1 }
                                                }) {
                                                    Image(systemName: "minus.circle.fill")
                                                        .font(.title3)
                                                        .foregroundStyle(Color.sMutedFG)
                                                }
                                                .frame(minWidth: 44, minHeight: 44)
                                                .accessibilityLabel("Decrease quantity for \(line.name)")
                                                Text("\(line.qty)")
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(Color.sForeground)
                                                    .frame(minWidth: 28)
                                                    .monospacedDigit()
                                                Button(action: { line.qty += 1 }) {
                                                    Image(systemName: "plus.circle.fill")
                                                        .font(.title3)
                                                        .foregroundStyle(Color.sAccent)
                                                }
                                                .frame(minWidth: 44, minHeight: 44)
                                                .accessibilityLabel("Increase quantity for \(line.name)")
                                            }
                                            Button(role: .destructive) { vm.removeItem(line) } label: {
                                                Label("Remove", systemImage: "trash")
                                            }
                                            .frame(minHeight: 44)
                                            .accessibilityLabel("Remove \(line.name)")
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)

                                        Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)
                                    }

                                    Button(action: { showItemPicker = true }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "plus.circle")
                                                .font(.body)
                                            Text("Add another item")
                                                .font(.body)
                                        }
                                        .foregroundStyle(Color.sAccent)
                                        .padding(14)
                                    }
                                }
                            }
                            .background(Color.sCard)
                            .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5) }
                            .clipShape(.rect(cornerRadius: 12))
                        }
                        .padding(.horizontal, AppSpacing.page)

                        Spacer(minLength: 32)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .protectUnsavedChanges(isDirty: isDirty, confirmDiscard: $confirmDiscard) {
                vm.clearForm()
                dismiss()
            }
            .onAppear { initialDate = vm.challanDate }
            .navigationTitle("New Delivery Challan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isDirty { confirmDiscard = true }
                        else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.isLoading {
                        ProgressView().tint(Color.sAccent)
                    } else {
                        Button("Save") {
                            Task {
                                let ok = await vm.createChallan()
                                if ok { dismiss() }
                            }
                        }
                        .disabled(vm.selectedClient == nil || vm.items.isEmpty)
                        .fontWeight(.semibold)
                    }
                }
            }
            .alert("Error", isPresented: $vm.showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .sheet(isPresented: $showClientPicker) {
                ClientPickerView(selectedClient: $vm.selectedClient)
            }
            .sheet(isPresented: $showItemPicker, onDismiss: {
                for line in tempItems {
                    vm.addItem(itemID: line.item.id, name: line.item.name)
                }
                tempItems = []
            }) {
                SelectItemSheet(selectedItems: $tempItems)
            }
        }
    }
}
