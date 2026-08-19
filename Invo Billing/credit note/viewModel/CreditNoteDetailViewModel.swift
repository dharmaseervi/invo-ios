//
//  CreditNoteDetailViewModel.swift
//  Invo Billing
//
//  Created by dharmaseervi on 1/22/26.
//


//
//  CreditNoteDetailViewModel.swift
//  Invo Billing
//
//  Created by dharmaseervi on 1/18/26.
//

import Foundation
import Combine

@MainActor
final class CreditNoteDetailViewModel: ObservableObject {

    // MARK: - State
    @Published var creditNote: CreditNoteDetailModel?
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var errorMessage: String?

    // MARK: - Context
    let cnID: Int
    private let service = CreditNoteService.shared

    // MARK: - Init
    init(cnID: Int) {
        self.cnID = cnID
    }

    // MARK: - Load
    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            creditNote = try await service.fetchByID(id: cnID)
            print("Loaded credit note: \(String(describing: creditNote))")
        } catch {
            errorMessage = error.localizedDescription
            showAlert = true
        }
    }

    // MARK: - Derived Helpers

    var isReturnType: Bool {
        creditNote?.type == "return"
    }

    var isAdjustmentType: Bool {
        creditNote?.type == "adjustment"
    }

    var isDiscountType: Bool {
        creditNote?.type == "discount"
    }

    var canApplyToInvoice: Bool {
        guard let cn = creditNote else { return false }
        return cn.balance > 0 && cn.status == "issued"
    }

    var canRefund: Bool {
        guard let cn = creditNote else { return false }
        return cn.balance > 0 && cn.status != "refunded"
    }
}
