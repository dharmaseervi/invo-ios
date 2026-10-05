//
//  StaffViewModel.swift
//  Invo Billing
//

import Combine
import Foundation

@MainActor
final class StaffViewModel: ObservableObject {

    @Published private(set) var members: [StaffMember] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isWorking = false

    @Published var errorMessage: String?
    @Published var showError = false
    @Published var message: String?

    private let service = StaffService()

    /// Identifies the newest load, so a slow reply cannot land on top of a list that
    /// has already moved on — somebody removed in the meantime reappearing, say.
    private var requestID = 0

    var staffCount: Int { members.filter { !$0.isOwner }.count }

    func load() async {
        guard let companyID = SessionManager.shared.selectedCompanyId else {
            show("Select a company first.")
            return
        }

        requestID += 1
        let request = requestID
        isLoading = true
        defer { isLoading = false }

        do {
            let people = try await service.members(companyID: companyID)
            guard request == requestID else { return }
            members = people
        } catch {
            guard request == requestID else { return }
            show(error.localizedDescription)
        }
    }

    func add(name: String, email: String, password: String, role: MemberRole) async -> Bool {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return false }
        isWorking = true
        defer { isWorking = false }

        do {
            try await service.add(companyID: companyID, request: NewStaffRequest(
                name: name, email: email, password: password, role: role.rawValue
            ))
            message = "\(name) can now sign in."
            await load()
            return true
        } catch {
            show(error.localizedDescription)
            return false
        }
    }

    func changeRole(_ member: StaffMember, to role: MemberRole) async {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            try await service.update(
                companyID: companyID, memberID: member.id,
                request: UpdateStaffRequest(name: member.name, role: role.rawValue)
            )
            await load()
        } catch {
            show(error.localizedDescription)
        }
    }

    func remove(_ member: StaffMember) async {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            try await service.remove(companyID: companyID, memberID: member.id)
            message = "\(member.displayName) can no longer sign in."
            await load()
        } catch {
            show(error.localizedDescription)
        }
    }

    private func show(_ text: String) {
        errorMessage = text
        showError = true
    }
}
