import Combine
import Foundation
import SwiftUI

@MainActor
class ChallanViewModel: ObservableObject {

    // MARK: - List
    @Published var challans: [ChallanResponse] = []
    @Published var isLoading = false

    // MARK: - Detail
    @Published var challanDetail: ChallanDetailResponse?

    // MARK: - Create form
    @Published var selectedClient: ClientModel?
    @Published var challanDate: Date = Date()
    @Published var notes: String = ""
    @Published var items: [ChallanLineItem] = []

    // MARK: - UI
    @Published var showAlert = false
    @Published var errorMessage: String?
    @Published var showSuccess = false
    @Published var successMessage = ""

    private let service = ChallanService()

    // MARK: - Load list
    func loadChallans() async {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            challans = try await service.listChallans(companyID: companyID)
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - Load detail
    func loadDetail(id: Int) async {
        isLoading = true
        defer { isLoading = false }
        do {
            challanDetail = try await service.getChallanByID(id)
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - Create
    func createChallan() async -> Bool {
        guard let client = selectedClient else {
            showError("Please select a client")
            return false
        }
        guard !items.isEmpty else {
            showError("Add at least one item")
            return false
        }
        guard let companyID = SessionManager.shared.selectedCompanyId else { return false }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)

        let payload = ChallanRequestDTO(
            company_id: companyID,
            client_id: client.id,
            challan_date: formatter.string(from: challanDate),
            invoice_id: nil,
            notes: notes,
            items: items.map { ChallanItemRequest(item_id: $0.itemID, qty: $0.qty, description: $0.description) }
        )

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await service.createChallan(payload: payload)
            successMessage = "Challan \(result.challan_number) created"
            showSuccess = true
            clearForm()
            await loadChallans()
            return true
        } catch {
            showError(error.localizedDescription)
            return false
        }
    }

    // MARK: - Dispatch
    func dispatch(id: Int) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.dispatchChallan(id)
            await loadDetail(id: id)
            await loadChallans()
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - Form helpers
    func addItem(itemID: Int, name: String) {
        if let i = items.firstIndex(where: { $0.itemID == itemID }) {
            items[i].qty += 1
        } else {
            items.append(ChallanLineItem(itemID: itemID, name: name, qty: 1, description: ""))
        }
    }

    func removeItem(_ line: ChallanLineItem) {
        items.removeAll { $0.id == line.id }
    }

    func clearForm() {
        selectedClient = nil
        challanDate = Date()
        notes = ""
        items = []
    }

    private func showError(_ message: String) {
        errorMessage = message
        showAlert = true
    }
}

// MARK: - UI-only line item
struct ChallanLineItem: Identifiable {
    let id = UUID()
    let itemID: Int
    let name: String
    var qty: Int
    var description: String
}
