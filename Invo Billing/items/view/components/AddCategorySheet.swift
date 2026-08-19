import SwiftUI

struct AddCategorySheet: View {
    @ObservedObject var vm: ItemViewModel
    @Environment(\.dismiss) var dismiss

    @State private var newCategory = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Create Category") {
                    TextField("Category Name", text: $newCategory)
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                }

                Button {
                    Task { await saveCategory() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Save Category")
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
                companyId: companyId

            )
            dismiss()

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
