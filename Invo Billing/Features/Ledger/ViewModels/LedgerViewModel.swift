import Combine
import SwiftUI

@MainActor
final class LedgerViewModel: ObservableObject {

    @Published var entries: [LedgerEntryModel] = []
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var errorMessage: String?

    let clientID: Int

    init(clientID: Int) {
        self.clientID = clientID
    }

    func fetchLedger() async {
        isLoading = true
        defer { isLoading = false }

        guard let companyId = SessionManager.shared.selectedCompanyId else {
            errorMessage = "Select company first"
            showAlert = true
            return
        }

        do {
            entries = try await LedgerService.shared.fetchLedger(
                clientID: clientID,
                companyID: companyId
            )
        } catch {
            errorMessage = error.localizedDescription
            showAlert = true
        }
    }

    var totalDebit: Double {
        entries.reduce(0) { $0 + $1.debit }
    }

    var totalCredit: Double {
        entries.reduce(0) { $0 + $1.credit }
    }

    var closingBalance: Double {
        entries.last?.balance ?? 0
    }
}
