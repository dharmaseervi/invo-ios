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
    @Published var state = ""
    @Published var pincode = ""

    @Published var errorMessage: String?
    @Published var showAlert = false
    @Published var isLoading = false

    private let service = ClientServices()
    
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
        
        print("Creating client with:", payload)

        isLoading = true
        defer { isLoading = false }

        do {
            let newClient: () = try await service.CreateClient(
                clientPayload: payload
            )
            print("Client created:", newClient)
            return true

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
        defer { isLoading = false }

        do {
            clients = try await service.loadClients(for: companyId)
        } catch {
            _ = showError(error.localizedDescription)
        }
    }
    
    func load(clientID: Int) async {
        guard let companyID = SessionManager.shared.selectedCompanyId else {
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
        } catch {
            print(error)
        }
    }
}
