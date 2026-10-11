import SwiftUI

struct ActiveSessionsView: View {
    @State private var sessions: [DeviceSession] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var revokeError: String?
    @State private var showRevokeAllConfirm = false

    private let currentSessionID = KeychainManager.shared.loadSessionID()

    var body: some View {
        Group {
                if isLoading {
                    ProgressView()
                        .tint(.sAccent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundColor(.sDestructive)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.sMutedFG)
                            .multilineTextAlignment(.center)
                        Button("Try again") { loadSessions() }
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.sAccent)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    sessionList
                }
        }
        .navigationTitle("Active sessions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if sessions.count > 1 {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign out all") {
                        showRevokeAllConfirm = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.sDestructive)
                }
            }
        }
        .alert("Sign out all other devices?", isPresented: $showRevokeAllConfirm) {
            Button("Sign out all", role: .destructive) { revokeAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll stay signed in on this device. All other sessions will end immediately.")
        }
        .alert("Error", isPresented: .constant(revokeError != nil)) {
            Button("OK") { revokeError = nil }
        } message: {
            Text(revokeError ?? "")
        }
        .onAppear { loadSessions() }
    }

    // MARK: - Session list

    private var sessionList: some View {
        List {
            Section {
                ForEach(sessions) { session in
                    sessionRow(session)
                }
            } footer: {
                Text("\(sessions.count) active session\(sessions.count == 1 ? "" : "s")")
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Single row

    private func sessionRow(_ session: DeviceSession) -> some View {
        let isCurrent = session.id == currentSessionID
        let detail = [relativeTime(session.last_seen), session.ip_address]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")

        return HStack(spacing: 12) {
            Image(systemName: platformIcon(session.platform))
                .font(.body)
                .foregroundStyle(isCurrent ? Color.sAccent : .secondary)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(session.device_name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if isCurrent {
                        Text("This device")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.sAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.sAccent.opacity(0.1), in: Capsule())
                    }
                }
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }

            Spacer(minLength: 8)

            if !isCurrent {
                Button("Revoke") { revokeSession(session) }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.sDestructive)
                    .buttonStyle(.borderless)
            }
        }
        .swipeActions(edge: .trailing) {
            if !isCurrent {
                Button("Revoke", role: .destructive) { revokeSession(session) }
            }
        }
    }

    // MARK: - Actions

    private func loadSessions() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await AuthService.shared.fetchSessions()
                await MainActor.run {
                    sessions = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Couldn't load sessions"
                    isLoading = false
                }
            }
        }
    }

    private func revokeSession(_ session: DeviceSession) {
        Task {
            do {
                try await AuthService.shared.revokeSession(id: session.id)
                await MainActor.run {
                    sessions.removeAll { $0.id == session.id }
                }
            } catch {
                await MainActor.run { revokeError = "Failed to revoke session" }
            }
        }
    }

    private func revokeAll() {
        Task {
            do {
                try await AuthService.shared.revokeAllOtherSessions()
                await MainActor.run {
                    sessions = sessions.filter { $0.id == currentSessionID }
                }
            } catch {
                await MainActor.run { revokeError = "Failed to sign out other devices" }
            }
        }
    }

    // MARK: - Helpers

    private func platformIcon(_ platform: String) -> String {
        switch platform.lowercased() {
        case "ios": return "iphone"
        case "android": return "phone"
        case "web": return "globe"
        case "mac": return "laptopcomputer"
        default: return "rectangle.connected.to.line.below"
        }
    }

    private func relativeTime(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: iso)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: iso)
        }
        guard let date else { return iso }
        let diff = Date().timeIntervalSince(date)
        switch diff {
        case ..<60:      return "Just now"
        case ..<3_600:   return "\(Int(diff / 60))m ago"
        case ..<86_400:  return "\(Int(diff / 3_600))h ago"
        case ..<604_800: return "\(Int(diff / 86_400))d ago"
        default:
            let df = DateFormatter()
            df.dateStyle = .medium; df.timeStyle = .none
            return df.string(from: date)
        }
    }
}
