import SwiftUI

struct CreateChallanView: View {
    @ObservedObject var vm: ChallanViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showClientPicker = false
    @State private var showItemPicker = false
    @State private var tempItems: [InvoiceLineItem] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sBackground.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {

                        // MARK: - Client
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Client")
                                .font(.scaled(13, weight: .medium))
                                .foregroundColor(.sMutedFG)
                                .padding(.horizontal, 20)

                            Button(action: { showClientPicker = true }) {
                                HStack {
                                    if let client = vm.selectedClient {
                                        Text(client.name)
                                            .font(.scaled(14))
                                            .foregroundColor(.sForeground)
                                    } else {
                                        Text("Select client")
                                            .font(.scaled(14))
                                            .foregroundColor(.sMutedFG)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.scaled(12))
                                        .foregroundColor(.sMutedFG)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.sCard)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sInput, lineWidth: 0.5))
                                .cornerRadius(8)
                            }
                            .padding(.horizontal, 20)
                        }

                        // MARK: - Date
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Challan date")
                                .font(.scaled(13, weight: .medium))
                                .foregroundColor(.sMutedFG)
                                .padding(.horizontal, 20)

                            DatePicker("", selection: $vm.challanDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .padding(.horizontal, 20)
                        }

                        // MARK: - Items
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Items")
                                    .font(.scaled(13, weight: .medium))
                                    .foregroundColor(.sMutedFG)
                                Spacer()
                                Button(action: { showItemPicker = true }) {
                                    Label("Add item", systemImage: "plus")
                                        .font(.scaled(12, weight: .medium))
                                        .foregroundColor(.sAccent)
                                }
                            }
                            .padding(.horizontal, 20)

                            if vm.items.isEmpty {
                                HStack {
                                    Spacer()
                                    Text("No items added")
                                        .font(.scaled(13))
                                        .foregroundColor(.sMutedFG)
                                    Spacer()
                                }
                                .padding(.vertical, 20)
                                .background(Color.sCard)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sInput, lineWidth: 0.5))
                                .cornerRadius(8)
                                .padding(.horizontal, 20)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach($vm.items) { $line in
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(line.name)
                                                    .font(.scaled(13, weight: .medium))
                                                    .foregroundColor(.sForeground)
                                                TextField("Description (optional)", text: $line.description)
                                                    .font(.scaled(11))
                                                    .foregroundColor(.sMutedFG)
                                            }
                                            Spacer()
                                            HStack(spacing: 8) {
                                                Button(action: {
                                                    if line.qty > 1 { line.qty -= 1 }
                                                }) {
                                                    Image(systemName: "minus.circle")
                                                        .foregroundColor(.sMutedFG)
                                                }
                                                Text("\(line.qty)")
                                                    .font(.scaled(14, weight: .semibold))
                                                    .foregroundColor(.sForeground)
                                                    .frame(minWidth: 24)
                                                Button(action: { line.qty += 1 }) {
                                                    Image(systemName: "plus.circle")
                                                        .foregroundColor(.sAccent)
                                                }
                                            }
                                            Button(action: { vm.removeItem(line) }) {
                                                Image(systemName: "trash")
                                                    .font(.scaled(13))
                                                    .foregroundColor(Color(red: 0.863, green: 0.149, blue: 0.149))
                                            }
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)
                                    }
                                }
                                .background(Color.sCard)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sInput, lineWidth: 0.5))
                                .cornerRadius(8)
                                .padding(.horizontal, 20)
                            }
                        }

                        // MARK: - Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.scaled(13, weight: .medium))
                                .foregroundColor(.sMutedFG)
                                .padding(.horizontal, 20)

                            TextEditor(text: $vm.notes)
                                .font(.scaled(14))
                                .scrollContentBackground(.hidden)
                                .frame(height: 80)
                                .padding(8)
                                .background(Color.sCard)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sInput, lineWidth: 0.5))
                                .cornerRadius(8)
                                .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("New Delivery Challan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        vm.clearForm()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let ok = await vm.createChallan()
                            if ok { dismiss() }
                        }
                    }
                    .disabled(vm.selectedClient == nil || vm.items.isEmpty || vm.isLoading)
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
