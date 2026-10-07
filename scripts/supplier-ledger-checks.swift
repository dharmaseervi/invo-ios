import Foundation

// The view model's injected loader supplies test pages. No account or server is used.
struct PurchasesService {
    func suppliers(companyID: Int, search: String?, limit: Int?, offset: Int) async throws -> SuppliersResponse {
        fatalError("Tests must use their injected loader")
    }
}

@main
struct SupplierLedgerChecks {
    @MainActor
    static func main() async {
        let suppliers = (1...100).map { id in
            Supplier(id: id, name: "Supplier \(id)", phone: "900000\(id)", email: "",
                     gstin: "", city: "", state: "", due: Double(id), open_bills: 1, advance: nil)
        }
        var requestedOffsets: [Int] = []
        var failNextPage = false
        let vm = PurchaseLedgerViewModel { _, search, limit, offset in
            precondition(limit == 25)
            requestedOffsets.append(offset)
            if failNextPage && offset > 0 {
                failNextPage = false
                throw URLError(.notConnectedToInternet)
            }
            let matches = suppliers.filter { search.isEmpty || $0.name == search }
            return Array(matches.dropFirst(offset).prefix(limit))
        }
        await vm.load(companyID: 1, search: "")
        precondition(vm.suppliers.count == 25 && vm.hasMore)
        failNextPage = true
        await vm.loadMore()
        precondition(vm.suppliers.count == 25 && vm.pageError != nil && vm.hasMore)
        let failedRequests = requestedOffsets.count
        await vm.loadMore()
        precondition(requestedOffsets.count == failedRequests, "Do not retry failures in a loop")
        await vm.loadMore(retry: true)
        precondition(vm.suppliers.count == 50 && vm.pageError == nil)
        await vm.loadMore()
        await vm.loadMore()
        await vm.loadMore()
        precondition(vm.suppliers.count == 100 && !vm.hasMore)
        precondition(requestedOffsets == [0, 25, 25, 50, 75, 100])
        await vm.load(companyID: 1, search: " Supplier 99 ")
        precondition(vm.suppliers.map(\.id) == [99], "Search must find suppliers beyond page one")
        await vm.load(companyID: nil, search: "")
        precondition(vm.suppliers.isEmpty && vm.loadError != nil && !vm.isLoading)

        // A delayed response from a previous company must never replace the new list.
        var pending: CheckedContinuation<[Supplier], Never>?
        let racing = PurchaseLedgerViewModel { companyID, _, _, _ in
            if companyID == 1 {
                return await withCheckedContinuation { pending = $0 }
            }
            return [suppliers[99]]
        }
        let old = Task { await racing.load(companyID: 1, search: "") }
        while pending == nil { await Task.yield() }
        await racing.load(companyID: 2, search: "")
        pending?.resume(returning: Array(suppliers.prefix(25)))
        await old.value
        precondition(racing.suppliers.map(\.id) == [100] && !racing.isLoading)
        print("PASS: 100 suppliers, paging/retry, full-list search, missing company and stale-response protection")
    }
}
