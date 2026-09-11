import SwiftUI

struct AddCategorySheet: View {
    @ObservedObject var vm: ItemViewModel
    @Environment(\.dismiss) var dismiss

    @State private var newCategory = ""
    @State private var defaultHSNCode = ""
    @State private var defaultTaxRate = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let taxOptions = ["5", "12", "18"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Create Category") {
                    TextField("Category Name", text: $newCategory)
                }

                Section {
                    TextField("e.g. 3208", text: $defaultHSNCode)
                        .keyboardType(.numberPad)

                    Picker("Default GST rate", selection: $defaultTaxRate) {
                        Text("None").tag("")
                        ForEach(taxOptions, id: \.self) { rate in
                            Text("\(rate)%").tag(rate)
                        }
                    }
                } header: {
                    Text("Defaults for items in this category")
                } footer: {
                    Text("Optional — new items you add under this category will start with this HSN code and GST rate pre-filled. Useful when most products in a category (e.g. all enamel paints) share the same HSN.")
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.sDestructive)
                }

                Button {
                    Task { await saveCategory() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.sAccent)
                    } else {
                        Text("Save Category")
                            .foregroundColor(.sAccent)
                    }
                }
                .disabled(newCategory.isEmpty || isLoading)
            }
            .navigationTitle("New Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Save Category Logic
    func saveCategory() async {
        guard !newCategory.isEmpty else { return }
        guard let companyId = SessionManager.shared.selectedCompanyId else {
            return
        }
        isLoading = true

        do {
            _ = try await vm.categoryService.createCategory(
                name: newCategory,
                companyId: companyId,
                defaultHSNCode: defaultHSNCode.isEmpty ? nil : defaultHSNCode,
                defaultTaxRate: defaultTaxRate.isEmpty ? nil : Double(defaultTaxRate)
            )
            dismiss()

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
