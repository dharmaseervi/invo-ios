import Combine
import Foundation

@MainActor
class ClientViewModel: ObservableObject {

    // form fields
    @Published var name = ""
    @Published var email = ""
    @Published var phone = ""
    @Published var address = ""
    @Published var city = ""
    @Published var state = IndianStates.defaultState
    @Published var pincode = ""

    @Published var errorMessage: String?
    @Published var showAlert = false
    @Published var isLoading = false

    private let service = ClientServices()
    private let addressService = AddressService()
    
    @Published var invoices: [InvoiceResponse] = []
    // Loaded list
    @Published var clients: [ClientModel] = []
    /// Searching happens on the server, so a search covers every customer rather than
    /// the page that happens to be loaded.
    @Published var searchText = ""
    @Published private(set) var hasMoreClients = false
    @Published private(set) var isLoadingMoreClients = false
    /// A page that failed to load. Paging pauses rather than ending, so the list can
    /// say so and offer to go again.
    @Published private(set) var loadMoreClientsFailed = false

    /// A page at a time. A shop with a few thousand customers used to download all of
    /// them to show the first screen.
    private let clientPageSize = 50

    /// Identifies the newest load, so a slow first page cannot land on top of a search
    /// typed after it.
    private var clientRequestID = 0

    // 🔥 Reset fields
    func resetForm() {
        name = ""
        email = ""
        phone = ""
        address = ""
        city = ""
        state = ""
        pincode = ""
    }

    // MARK: - Create Client
    func createNewClient() async -> Bool {

        guard let companyId = SessionManager.shared.selectedCompanyId else {
            return showError("Please select a company first")
        }

        // Basic validation
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            return showError("Client name is required.")
        }

        if !email.isEmpty && !email.contains("@") {
            return showError("Invalid email address.")
        }

        if !phone.isEmpty && phone.count < 8 {
            return showError("Phone number is too short.")
        }

        let payload = CreateClientRequest(
            company_id: companyId,
            name: name,
            address: address,
            email: email,
            phone: phone,
            city: city,
            state: state,
            pincode: pincode
        )
        
        isLoading = true
        defer { isLoading = false }

        do {
            try await service.CreateClient(clientPayload: payload)
            return true
        } catch let authErr as AuthErrorResponse {
            return showError(authErr.error)
        } catch {
            return showError(error.localizedDescription)
        }
    }

    private func showError(_ msg: String) -> Bool {
        errorMessage = msg
        showAlert = true
        return false
    }

    // MARK: Load Clients
    func loadClients() async {
        guard let companyId = SessionManager.shared.selectedCompanyId else {
            _ = showError("Please select a company first")
            return
        }
        isLoading = true
        // Same reason as the items list: its error state is driven purely by this value,
        // so a successful retry has to clear it or the screen never comes back.
        errorMessage = nil
        showAlert = false
        defer { isLoading = false }

        clientRequestID += 1
        let request = clientRequestID

        do {
            let page = try await service.loadClients(
                for: companyId,
                search: searchText,
                limit: clientPageSize,
                offset: 0
            )
            guard request == clientRequestID else { return }
            clients = page
            hasMoreClients = page.count >= clientPageSize
            // A fresh list starts without the previous one's paging failure.
            loadMoreClientsFailed = false
        } catch let authErr as AuthErrorResponse {
            guard request == clientRequestID else { return }
            _ = showError(authErr.error)
        } catch {
            guard request == clientRequestID else { return }
            _ = showError(error.localizedDescription)
        }
    }

    /// The next page, appended. Asked for when the list nears its end.
    func loadMoreClients() async {
        guard let companyId = SessionManager.shared.selectedCompanyId,
              hasMoreClients, !isLoadingMoreClients, !loadMoreClientsFailed else { return }

        isLoadingMoreClients = true
        defer { isLoadingMoreClients = false }

        let request = clientRequestID
        do {
            let page = try await service.loadClients(
                for: companyId,
                search: searchText,
                limit: clientPageSize,
                offset: clients.count
            )
            // A search started while this page was in flight wins; appending now would
            // put one search's customers under another's.
            guard request == clientRequestID else { return }

            // Skipping what is already held: a customer added while the list was open
            // shifts the offsets, and the same row would otherwise arrive twice.
            let known = Set(clients.map(\.id))
            clients.append(contentsOf: page.filter { !known.contains($0.id) })
            hasMoreClients = page.count >= clientPageSize
        } catch {
            // A stale failure must not switch paging off for a search that has since
            // moved on. The success path has always checked this; the failure path did
            // not, so an old request failing late could end a newer list.
            guard request == clientRequestID else { return }

            // Quiet, but not final. `hasMoreClients = false` was the old answer and it
            // said the wrong thing: after fifty customers a dropped connection made the
            // rest of the shop's customers look like they did not exist, with nothing
            // on screen to suggest otherwise and no way back but a reload. The rest are
            // still there, so the list keeps its offer to fetch them and shows a Try
            // again instead of ending.
            loadMoreClientsFailed = true
        }
    }

    /// Clears a paging failure and asks for the same page again.
    func retryLoadMoreClients() async {
        loadMoreClientsFailed = false
        await loadMoreClients()
    }

    // MARK: - Quick Sale Accounts (Cash / UPI)

    /// Returns the existing Cash/UPI client for this company, creating it once if needed.
    func ensureQuickSaleClient(_ account: QuickSaleAccount) async -> ClientModel? {
        guard let companyId = SessionManager.shared.selectedCompanyId else {
            _ = showError("Please select a company first")
            return nil
        }

        // Asked of the server by name, found or created in one go. Looking for it in
        // the loaded list is what kept this list unpaged — the account might be on a
        // page nobody had fetched — and two tills asking at once each made their own.
        let client: ClientModel
        do {
            client = try await service.quickSaleClient(companyId: companyId, account: account)
        } catch let authErr as AuthErrorResponse {
            _ = showError(authErr.error)
            return nil
        } catch {
            _ = showError("Failed to set up \(account.rawValue) account")
            return nil
        }

        // The backend requires a billing address row to exist before any invoice
        // can reference this client. Ensure one exists (covers both a fresh
        // client and one created before this address was added) so the user
        // is never asked for one when billing to Cash/UPI.
        do {
            let existingAddress: AddressModel?
            do {
                existingAddress = try await addressService.getClientAddress(
                    clientID: client.id,
                    type: "billing"
                )
            } catch {
                existingAddress = nil
            }

            if existingAddress == nil {
                try await addressService.saveClientAddress(
                    clientID: client.id,
                    payload: ClientAddressRequestDTO(
                        type: "billing",
                        name: account.rawValue,
                        line1: "\(account.rawValue) sale",
                        line2: nil,
                        city: nil,
                        state: nil,
                        postal_code: nil,
                        country: nil,
                        phone: nil,
                        email: nil,
                        gst_number: nil
                    )
                )
            }
        } catch {
            _ = showError("Failed to set up \(account.rawValue) account")
            return nil
        }

        return client
    }

    func load(clientID: Int) async {
        guard let companyID = SessionManager.shared.selectedCompanyId else {
            _ = showError("Please select a company first")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await InvoiceService()
                .getInvoices(
                    companyID: companyID,
                    clientID: clientID,
                    limit: 50
                )
            invoices = response.data
        } catch let authErr as AuthErrorResponse {
            _ = showError(authErr.error)
        } catch {
            _ = showError(error.localizedDescription)
        }
    }
}
