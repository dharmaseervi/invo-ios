import Foundation

@MainActor final class SessionManager {
    static let shared = SessionManager()
    var selectedCompanyId: Int? = 1
}
struct ClientModel { let id: Int }
struct ChallanPage { let challans: [ChallanResponse]; let has_more: Bool?; let total: Int? }
@MainActor final class ChallanService {
    static var failingDetail: Set<Int> = []
    static var delays: [Int: UInt64] = [:]
    static var failPage = false
    static var dispatches: [Int] = []
    func getChallanByID(_ id: Int) async throws -> ChallanDetailResponse {
        if let delay = Self.delays[id] { try await Task.sleep(nanoseconds: delay) }
        if Self.failingDetail.contains(id) { throw URLError(.notConnectedToInternet) }
        return ChallanDetailResponse(id: id, challan_number: "DC-\(id)", client: ChallanClient(id: 1, name: "Customer"), challan_date: "2026-10-12", status: .draft, invoice_id: nil, notes: nil, items: [])
    }
    func listChallans(companyID: Int, search: String, limit: Int, offset: Int) async throws -> ChallanPage {
        if Self.failPage && offset > 0 { throw URLError(.timedOut) }
        let total = search.isEmpty ? 121 : 0
        let rows = offset < total ? (offset..<min(offset + limit, total)).map { value in
            ChallanResponse(id: value + 1, challan_number: "DC-\(value)", client_name: "Customer", challan_date: "2026-10-12", status: .draft, invoice_id: nil, created_at: "2026-10-12")
        } : []
        return ChallanPage(challans: rows, has_more: offset + rows.count < total, total: total)
    }
    func dispatchChallan(_ id: Int) async throws { Self.dispatches.append(id) }
    func createChallan(payload: ChallanRequestDTO) async throws -> CreateChallanResponse { CreateChallanResponse(id: 1, challan_number: "DC-1") }
}

@main struct ChallanChecks {
    @MainActor static func main() async throws {
        let vm = ChallanViewModel()
        await vm.loadDetail(id: 1)
        precondition(vm.canDispatch(id: 1))
        ChallanService.failingDetail = [2]
        await vm.loadDetail(id: 2)
        precondition(vm.matchingDetail(id: 1) == nil && vm.matchingDetail(id: 2) == nil)
        await vm.dispatch(id: 2)
        precondition(ChallanService.dispatches.isEmpty)
        ChallanService.delays[1] = 80_000_000
        let old = Task { await vm.loadDetail(id: 1) }
        try await Task.sleep(nanoseconds: 10_000_000)
        await vm.loadDetail(id: 3)
        await old.value
        precondition(vm.matchingDetail(id: 3)?.id == 3)
        precondition(vm.matchingDetail(id: 1) == nil)
        SessionManager.shared.selectedCompanyId = 2
        precondition(!vm.canDispatch(id: 3))

        await vm.loadChallans()
        precondition(vm.challans.count == 40 && vm.hasMore)
        ChallanService.failPage = true
        await vm.loadMore()
        precondition(vm.challans.count == 40 && vm.pageError != nil && vm.hasMore)
        ChallanService.failPage = false
        while vm.hasMore { await vm.loadMore() }
        precondition(vm.challans.count == 121 && Set(vm.challans.map(\.id)).count == 121)
        vm.searchText = "no match"
        await vm.loadChallans()
        precondition(vm.challans.isEmpty && !vm.hasMore)
        vm.searchText = ""
        await vm.loadChallans()
        precondition(vm.challans.count == 40)
        print("PASS: challan A→B failure, obsolete response, dispatch identity, company change, 121 rows, page retry and search clearing")
    }
}
