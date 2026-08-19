// MARK: - Enhanced ViewModel

import Foundation
import Combine
import UIKit

@MainActor
class ItemViewModel: ObservableObject {
    let categoryService = CategoryService()
    
    @Published var name = ""
    @Published var category: Int?
    @Published var sku = ""
    @Published var description = ""
    @Published var costPrice = ""
    @Published var price = ""
    @Published var quantity = ""
    @Published var lowStockAlert = ""
    @Published var taxRate = ""
    @Published var selectedCategoryId: Int?
    @Published var unit: String?
    @Published var hsnCode = ""
    
    @Published var categories: [CategoryResponse] = []
    @Published var items: [ItemResponse] = []
    
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var errorMessage: String?
    
   
   
    
    
    var selectedCategoryName: String {
        if let id = selectedCategoryId {
            return categories.first(where: { $0.id == id })?.name ?? "Select Category"
        }
        return "Select Category"
    }


    
    var isValid: Bool {
        !name.isEmpty && !price.isEmpty
    }
    
    func createItem() async -> Bool {
        guard let companyId = SessionManager.shared.selectedCompanyId else {
            errorMessage = "Select company first"
            showAlert = true
            return false
        }
        
        let payload = ItemRequestDTO(
            company_id: companyId,
            name: name,
            category_id: selectedCategoryId,
            sku: sku,
            hsn_code: hsnCode,        // ← add
            description: description,
            cost_price: Double(costPrice) ?? 0,
            price: Double(price) ?? 0,
            quantity: Int(quantity) ?? 0,
            low_stock_alert: Int(lowStockAlert) ?? 0,
            tax_rate: Double(taxRate) ?? 0
        )
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let success = try await ItemService().createItem(payload: payload)
            if !success { throw NSError(domain: "", code: 0) }
            return true
        } catch {
            errorMessage = "Failed to create item"
            showAlert = true
            return false
        }
    }
  
    func loadItems() async {
        guard let companyId = SessionManager.shared.selectedCompanyId else { return }
        print("🏢 Loading items for company:", companyId)

        isLoading = true
        items = [] // ← ✅ Clear stale items immediately
        defer { isLoading = false }
        
        do {
            items = try await ItemService().loadItems(companyId: companyId)
            print("items" , items)
            
        } catch {
            print("Error fetching items:", error)
        }
    }
    
    func loadCategories() async {
        guard let companyId = SessionManager.shared.selectedCompanyId else { return }
        
        do {
            categories = try await categoryService
                .getCategories(companyId: companyId)
            print("categoryName" , categories)
        } catch {
            print("Category error:", error.localizedDescription)
        }
    }
    
    func resetForm() {
        name = ""
        sku = ""
        description = ""
        costPrice = ""
        price = ""
        quantity = ""
        lowStockAlert = ""
        taxRate = ""
        hsnCode = ""              // ← add
        unit = nil
        selectedCategoryId = nil
        
        errorMessage = nil
        showAlert = false
    }

    
}
