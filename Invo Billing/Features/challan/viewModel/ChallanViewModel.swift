import Combine
import Foundation
import SwiftUI

@MainActor
class ChallanViewModel: ObservableObject {

    // MARK: - List
    @Published var challans: [ChallanResponse] = []
    @Published var isLoading = false
    @Published var isLoadingList = false
    @Published var isLoadingMore = false
    @Published var listError: String?
    @Published var pageError: String?
    @Published var hasMore = false
    @Published var searchText = ""
    private var listRequest = UUID()
    private var listCompanyID: Int?
    private var listSearch = ""
    private var offset = 0
    private let pageSize = 40
    private var detailRequest = UUID()
    private var detailCompanyID: Int?
    private var detailID: Int?
    @Published var isLoadingDetail = false
    @Published var detailError: String?

    func matchingDetail(id: Int) -> ChallanDetailResponse? {
        guard detailID == id, detailCompanyID == SessionManager.shared.selectedCompanyId,
              challanDetail?.id == id else { return nil }
        return challanDetail
    }
    func canDispatch(id: Int) -> Bool {
        matchingDetail(id: id)?.status == .draft && !isLoadingDetail && !isLoading && detailError == nil
    }

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
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = UUID()
        listRequest = request
        if listCompanyID != companyID || listSearch != query { challans = [] }
        listCompanyID = companyID
        listSearch = query
        listError = nil
        pageError = nil
        offset = 0
        hasMore = false
        isLoadingMore = false
        isLoadingList = true
        defer { if request == listRequest { isLoadingList = false } }
        do {
            let result = try await service.listChallans(companyID: companyID, search: query, limit: pageSize, offset: 0)
            guard request == listRequest, companyID == SessionManager.shared.selectedCompanyId else { return }
            challans = result.challans
            offset = result.challans.count
            hasMore = result.has_more ?? (result.challans.count == pageSize)
        } catch {
            guard request == listRequest else { return }
            listError = error.localizedDescription
        }
    }

    func loadMore() async {
        guard !isLoadingList, !isLoadingMore, hasMore, let companyID = listCompanyID else { return }
        let request = listRequest
        isLoadingMore = true
        pageError = nil
        defer { if request == listRequest { isLoadingMore = false } }
        do {
            let result = try await service.listChallans(companyID: companyID, search: listSearch, limit: pageSize, offset: offset)
            guard request == listRequest, companyID == SessionManager.shared.selectedCompanyId else { return }
            let existing = Set(challans.map(\.id))
            challans.append(contentsOf: result.challans.filter { !existing.contains($0.id) })
            offset += result.challans.count
            hasMore = result.has_more ?? (result.challans.count == pageSize)
        } catch {
            guard request == listRequest else { return }
            pageError = error.localizedDescription
        }
    }

    // MARK: - Load detail
    func loadDetail(id: Int) async {
        let request = UUID()
        let companyID = SessionManager.shared.selectedCompanyId
        detailRequest = request
        if detailID != id || detailCompanyID != companyID { challanDetail = nil }
        detailID = id
        detailCompanyID = companyID
        detailError = nil
        isLoadingDetail = true
        defer { if request == detailRequest { isLoadingDetail = false } }
        do {
            let result = try await service.getChallanByID(id)
            guard request == detailRequest, companyID == SessionManager.shared.selectedCompanyId else { return }
            guard result.id == id else { throw URLError(.badServerResponse) }
            challanDetail = result
        } catch {
            guard request == detailRequest else { return }
            detailError = error.localizedDescription
        }
    }

    // MARK: - Create
    func createChallan() async -> Bool {
        guard !isLoading else { return false }
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
            successMessage = "Challan \(result.challan_number) created successfully"
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
        guard canDispatch(id: id) else { return }
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
