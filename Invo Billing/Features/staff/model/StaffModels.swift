//
//  StaffModels.swift
//  Invo Billing
//
//  Who works in the shop, and what each of them may do.
//

import Foundation

/// What somebody is to a business.
///
/// The server decides every one of these; this copy only decides what the app bothers
/// to draw. Hiding a screen somebody cannot use is a kindness, not a lock — the lock is
/// on the server, and a build of this app with every check removed still gets 403.
enum MemberRole: String, CaseIterable, Identifiable {
    case owner
    case manager
    case staff

    var id: String { rawValue }

    /// Lenient, like the rest of the app's decoding: a role this version has never
    /// heard of is treated as the most restricted one rather than crashing or, worse,
    /// being waved through.
    init(_ raw: String?) {
        self = MemberRole(rawValue: (raw ?? "").lowercased()) ?? .staff
    }

    var label: String {
        switch self {
        case .owner: return "Owner"
        case .manager: return "Manager"
        case .staff: return "Staff"
        }
    }

    /// Said in terms of the shop, not of permissions.
    var explanation: String {
        switch self {
        case .owner:
            return "Everything, including who works here."
        case .manager:
            return "Runs the shop day to day. Can't change staff or company details."
        case .staff:
            return "Bills customers and takes payments. No costs, no reports, no deleting."
        }
    }

    // MARK: - What the app will draw

    /// Purchases, supplier statements and anything showing what stock costs.
    var canSeeCosts: Bool { self != .staff }
    /// Takings, ledgers, GST, ageing — the money view of the business.
    var canSeeReports: Bool { self != .staff }
    /// Adding items and changing prices.
    var canEditCatalogue: Bool { self != .staff }
    /// Company details, banks, invoice template.
    var canChangeSettings: Bool { self == .owner }
    /// Deciding who works here.
    var canManageStaff: Bool { self == .owner }
}

/// Somebody who works in this business.
struct StaffMember: Codable, Identifiable {
    let id: Int
    let user_id: Int
    let email: String
    let name: String
    let role: String
    /// The day they were added, as YYYY-MM-DD.
    let since: String

    var memberRole: MemberRole { MemberRole(role) }
    var isOwner: Bool { memberRole == .owner }

    /// What to call them. Falls back to the login where no name was given — an owner
    /// backfilled from an existing account has no name on their row.
    var displayName: String {
        name.trimmingCharacters(in: .whitespaces).isEmpty ? email : name
    }
}

struct StaffResponse: Codable {
    let data: [StaffMember]
}

struct NewStaffRequest: Codable {
    let name: String
    let email: String
    let password: String
    let role: String
}

struct UpdateStaffRequest: Codable {
    let name: String
    let role: String
}
