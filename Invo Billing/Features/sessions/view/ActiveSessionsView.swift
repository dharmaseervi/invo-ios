import SwiftUI

struct ActiveSessionsView: View {
    @State private var sessions: [DeviceSession] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var revokeError: String?
    @State private var showRevokeAllConfirm = false

    private let currentSessionID = KeychainManager.shared.loadSessionID()

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            Group {
                if isLoading {
                    ProgressView()
                        .tint(.sAccent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.scaled(28))
                            .foregroundColor(.sDestructive)
                        Text(errorMessage)
                            .font(.scaled(13))
                            .foregroundColor(.sMutedFG)
                            .multilineTextAlignment(.center)
                        Button("Try again") { loadSessions() }
                            .font(.scaled(13, weight: .medium))
                            .foregroundColor(.sAccent)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    sessionList
                }
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
                    .font(.scaled(13))
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
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 1) {
                    ForEach(sessions) { session in
                        sessionRow(session)
                    }
                }
                .background(Color.sCard)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Text("\(sessions.count) active session\(sessions.count == 1 ? "" : "s")")
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Single row

    @ViewBuilder
    private func sessionRow(_ session: DeviceSession) -> some View {
        let isCurrent = session.id == currentSessionID

        HStack(spacing: 14) {
            Image(systemName: platformIcon(session.platform))
                .font(.scaled(20))
                .foregroundColor(isCurrent ? .sAccent : .sMutedFG)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(session.device_name)
                        .font(.scaled(14, weight: .medium))
                        .foregroundColor(.sForeground)
                    if isCurrent {
                        Text("This device")
                            .font(.scaled(11, weight: .semibold))
                            .foregroundColor(.sAccent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.sAccent.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                Text(relativeTime(session.last_seen))
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
                if !session.ip_address.isEmpty {
                    Text(session.ip_address)
                        .font(.scaled(11))
                        .foregroundColor(.sMutedFG.opacity(0.7))
                }
            }

            Spacer()

            if !isCurrent {
                Button {
                    revokeSession(session)
                } label: {
                    Text("Revoke")
                        .font(.scaled(12, weight: .medium))
                        .foregroundColor(.sDestructive)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.sDestructive.opacity(0.08))
                        .cornerRadius(6)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)

        if session.id != sessions.last?.id {
            Divider().padding(.leading, 62)
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
