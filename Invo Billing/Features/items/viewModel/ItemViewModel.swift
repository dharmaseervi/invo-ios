// MARK: - Enhanced ViewModel

import Foundation
import Combine
import UIKit

@MainActor
class ItemViewModel: ObservableObject {
    let categoryService = CategoryService()

    /// Generates a practically-unique SKU: a time-based component (so two taps a
    /// second apart never collide) plus two random digits for the rare same-second
    /// case. The backend's unique index on (company_id, sku) is the real guarantee —
    /// if this ever collides, saving will fail with a clear "already used" message.
    static func generateSKU() -> String {
        let timeComponent = String(Int(Date().timeIntervalSince1970))
        let suffix = String(format: "%02d", Int.random(in: 0...99))
        return "ITM-\(timeComponent.suffix(6))\(suffix)"
    }
    
    @Published var name = ""
    @Published var category: Int?
    @Published var sku = ""
    @Published var description = ""
    @Published var costPrice = ""
    @Published var price = ""
    @Published var quantity = ""
    @Published var lowStockAlert = ""
    @Published var taxRate = "18"
    @Published var selectedCategoryId: Int?
    @Published var unit: String?
    @Published var hsnCode = ""

    @Published var categories: [CategoryResponse] = []
    @Published var items: [ItemResponse] = []

    @Published var isLoading = false
    @Published var showAlert = false
    @Published var errorMessage: String?
    /// Set when the server rejected the token — the list screen hides "Try again" in this
    /// case, because retrying with the same dead token can only fail again.
    @Published var sessionExpired = false

    /// Paging state. nextCursor is nil once the catalogue is exhausted, which is also
    /// what stops the list asking for more forever at the bottom.
    @Published var isLoadingMore = false
    private var nextCursor: String?
    private var activeSearch = ""
    private var searchTask: Task<Void, Never>?

    var hasMore: Bool { nextCursor != nil }

    /// Page size. Large enough that a typical catalogue is one or two requests, small
    /// enough that the first screen appears immediately on a slow connection.
    private static let pageSize = 100

    /// Set when editing an existing item; nil means the form is creating a new one.
    @Published var editingItemId: Int?
    var isEditMode: Bool { editingItemId != nil }

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
            hsn_code: hsnCode,
            unit: unit,
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
        } catch let error as ItemServiceError {
            errorMessage = error.message
            showAlert = true
            return false
        } catch {
            errorMessage = "Failed to create item"
            showAlert = true
            return false
        }
    }
  
    /// Pre-fills the form with an existing item's data, switching the form into edit mode.
    func loadForEdit(_ item: ItemResponse) {
        editingItemId = item.id
        name = item.name
        selectedCategoryId = item.category_id
        sku = item.sku ?? ""
        hsnCode = item.hsn_code ?? ""
        description = item.description ?? ""
        costPrice = item.cost_price.map { String($0) } ?? ""
        price = String(item.price)
        quantity = String(item.quantity)
        lowStockAlert = item.low_stock_alert.map { String($0) } ?? ""
        taxRate = item.tax_rate.map { String($0) } ?? "18"
        unit = item.unit
    }

    /// Applies a category's default HSN code / GST rate to a new item's form —
    /// only when creating (never overwrites an existing item's own saved values).
    func applyCategoryDefaults(_ category: CategoryResponse) {
        guard !isEditMode else { return }
        if hsnCode.isEmpty, let defaultHSN = category.default_hsn_code, !defaultHSN.isEmpty {
            hsnCode = defaultHSN
        }
        if let defaultTax = category.default_tax_rate {
            taxRate = String(defaultTax)
        }
    }

    func updateItem() async -> Bool {
        guard let itemId = editingItemId else { return false }
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
            hsn_code: hsnCode,
            unit: unit,
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
            let success = try await ItemService().updateItem(id: itemId, payload: payload)
            if !success { throw NSError(domain: "", code: 0) }
            return true
        } catch let error as ItemServiceError {
            errorMessage = error.message
            showAlert = true
            return false
        } catch {
            errorMessage = "Failed to save changes"
            showAlert = true
            return false
        }
    }

    /// Records stock received from a supplier — separate from a manual quantity edit,
    /// so it lands in the audit trail as a "restock" rather than an "adjustment".
    func restock(quantityReceived: Int, reference: String, note: String) async -> Bool {
        guard let itemId = editingItemId else { return false }

        let payload = RestockRequestDTO(
            quantity: quantityReceived,
            reference: reference.isEmpty ? nil : reference,
            note: note.isEmpty ? nil : note
        )

        isLoading = true
        defer { isLoading = false }

        do {
            let success = try await ItemService().restockItem(id: itemId, payload: payload)
            if success {
                quantity = String((Int(quantity) ?? 0) + quantityReceived)
            }
            return success
        } catch {
            errorMessage = "Failed to record stock"
            showAlert = true
            return false
        }
    }

    func loadItems() async {
        guard let companyId = SessionManager.shared.selectedCompanyId else { return }

        isLoading = true
        items = []
        nextCursor = nil
        // Cleared up front, not just on failure: the list screen renders its error state
        // whenever this is non-nil, so a stale message from an earlier attempt would keep
        // that screen up even after a retry successfully fetched the items.
        errorMessage = nil
        showAlert = false
        sessionExpired = false
        defer { isLoading = false }

        do {
            let page = try await ItemService().loadItems(
                companyId: companyId,
                limit: Self.pageSize,
                search: activeSearch.isEmpty ? nil : activeSearch
            )
            items = page.items
            nextCursor = page.next_cursor
        } catch is SessionExpiredError {
            errorMessage = "Your session has expired. Sign out and sign in again."
            sessionExpired = true
            showAlert = true
        } catch {
            errorMessage = "Couldn't reach the server. Check your connection and try again."
            showAlert = true
        }
    }

    /// Fetches the next page when the list nears its end. Guarded so overlapping
    /// scroll events cannot fire several identical requests.
    func loadMoreIfNeeded(currentItem item: ItemResponse) async {
        guard !isLoadingMore, let cursor = nextCursor,
              let companyId = SessionManager.shared.selectedCompanyId else { return }

        // Trigger a few rows early so the next page is usually already there by the
        // time the user reaches the bottom.
        guard let index = items.firstIndex(where: { $0.id == item.id }),
              index >= items.count - 10 else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await ItemService().loadItems(
                companyId: companyId,
                limit: Self.pageSize,
                cursor: cursor,
                search: activeSearch.isEmpty ? nil : activeSearch
            )
            // Guard against duplicates if a reload landed while this was in flight.
            let existing = Set(items.map(\.id))
            items.append(contentsOf: page.items.filter { !existing.contains($0.id) })
            nextCursor = page.next_cursor
        } catch {
            // A failed page is not worth an error screen over a list that already has
            // content; the user can scroll again to retry.
            nextCursor = nil
        }
    }

    /// Debounced server-side search. Filtering client-side only works when the whole
    /// catalogue is loaded, which is exactly what pagination stops doing.
    func search(_ query: String) {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self else { return }
            self.activeSearch = query.trimmingCharacters(in: .whitespaces)
            await self.loadItems()
        }
    }

    /// Looks a scanned code up on the server. The scanned item may be on a page that
    /// was never loaded, so searching the in-memory list would report "no match" for
    /// an item that exists.
    func findByCode(_ code: String) async -> ItemResponse? {
        guard let companyId = SessionManager.shared.selectedCompanyId else { return nil }

        let sku = code.hasPrefix("ITEM_ID:") ? "" : code
        if !sku.isEmpty {
            if let page = try? await ItemService().loadItems(
                companyId: companyId, limit: 25, search: sku
            ) {
                if let exact = page.items.first(where: { $0.sku?.caseInsensitiveCompare(sku) == .orderedSame }) {
                    return exact
                }
            }
        }

        // This app's own printed labels encode ITEM_ID:<id>.
        if let idPart = code.split(separator: ":").last, let id = Int(idPart) {
            if let match = items.first(where: { $0.id == id }) { return match }
            return try? await ItemService().getItemByID(id).first
        }
        return nil
    }

    func loadCategories() async {
        guard let companyId = SessionManager.shared.selectedCompanyId else { return }

        errorMessage = nil
        showAlert = false

        do {
            categories = try await categoryService
                .getCategories(companyId: companyId)
        } catch {
            errorMessage = "Failed to load categories"
            showAlert = true
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
        taxRate = "18"
        hsnCode = ""
        unit = nil
        selectedCategoryId = nil
        editingItemId = nil

        errorMessage = nil
        showAlert = false
    }

    
}
