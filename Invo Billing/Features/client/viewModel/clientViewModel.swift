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

        do {
            clients = try await service.loadClients(for: companyId)
        } catch let authErr as AuthErrorResponse {
            _ = showError(authErr.error)
        } catch {
            _ = showError(error.localizedDescription)
        }
    }

    // MARK: - Quick Sale Accounts (Cash / UPI)

    /// Returns the existing Cash/UPI client for this company, creating it once if needed.
    func ensureQuickSaleClient(_ account: QuickSaleAccount) async -> ClientModel? {
        guard let companyId = SessionManager.shared.selectedCompanyId else {
            _ = showError("Please select a company first")
            return nil
        }

        if clients.isEmpty {
            await loadClients()
        }

        var quickSaleClient = clients.first(where: { $0.quickSaleAccount == account })

        if quickSaleClient == nil {
            let payload = CreateClientRequest(
                company_id: companyId,
                name: account.rawValue,
                address: "",
                email: "",
                phone: "",
                city: "",
                state: "",
                pincode: ""
            )

            do {
                try await service.CreateClient(clientPayload: payload)
            } catch {
                _ = showError("Failed to set up \(account.rawValue) account")
                return nil
            }

            await loadClients()
            quickSaleClient = clients.first(where: { $0.quickSaleAccount == account })
        }

        guard let client = quickSaleClient else { return nil }

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
