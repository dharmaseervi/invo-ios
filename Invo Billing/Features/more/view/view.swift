import SwiftUI

struct MoreView: View {
    @StateObject var vm = UserViewModel()
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var session: SessionManager
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirmation = false
    @State private var showFinalDeleteConfirmation = false
    @State private var showDeleteError = false
    @State private var showSignOutConfirmation = false
    @State private var showTemplatePicker = false
    @State private var selectedTemplate = InvoiceTemplatePreference.load()
    @State private var biometricError: String?
    @State private var defaultState = IndianStates.defaultState
    #if DEBUG
    @State private var testPushStatus: String?
    #endif

    private let biometricKind = BiometricAuthService.availableKind()

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {

                            // MARK: - Profile Section
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Profile")
                                    .font(.scaled(13, weight: .medium))
                                    .foregroundColor(.sMutedFG)

                                NavigationLink {
                                    ProfileView()
                                } label: {
                                    HStack(spacing: 14) {
                                        Text(String(vm.profile?.email.prefix(1).uppercased() ?? "U"))
                                            .font(.scaled(18, weight: .semibold))
                                            .foregroundColor(.sAccentFG)
                                            .frame(width: 52, height: 52)
                                            .background(Color.sAccent)
                                            .cornerRadius(12)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(vm.profile?.email ?? "Loading...")
                                                .font(.scaled(14, weight: .medium))
                                                .foregroundColor(.sForeground)
                                            Text("View profile")
                                                .font(.scaled(12))
                                                .foregroundColor(.sMutedFG)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.scaled(12, weight: .semibold))
                                            .foregroundColor(.sMutedFG)
                                    }
                                    .padding(14)
                                    .background(Color.sCard)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.sBorder, lineWidth: 0.5)
                                    )
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 24)

                            // MARK: - Account Section
                            sectionHeader("Account")

                            VStack(spacing: 0) {
                                NavigationLink {
                                    CompanyView()
                                } label: {
                                    MoreViewRow(icon: "building.2.fill", label: "Company Details")
                                }
                                rowDivider()

                                NavigationLink {
                                    EstimateListView()
                                } label: {
                                    MoreViewRow(icon: "doc.badge.clock", label: "Estimates")
                                }
                                rowDivider()

                                NavigationLink {
                                    ExpenseView()
                                } label: {
                                    MoreViewRow(icon: "banknote.fill", label: "Expenses")
                                }
                                rowDivider()

                                NavigationLink {
                                    LedgerView()
                                } label: {
                                    MoreViewRow(icon: "book.fill", label: "Ledger")
                                }
                                rowDivider()

                                NavigationLink {
                                    GSTReportView()
                                } label: {
                                    MoreViewRow(icon: "doc.text.magnifyingglass", label: "GST Reports")
                                }
                                rowDivider()

                                NavigationLink {
                                    AgingReportView()
                                } label: {
                                    MoreViewRow(icon: "clock.badge.exclamationmark", label: "Client Aging")
                                }
                                rowDivider()

                                NavigationLink {
                                    StockReportView()
                                } label: {
                                    MoreViewRow(icon: "shippingbox.fill", label: "Stock Report")
                                }
                                rowDivider()

                                NavigationLink {
                                    CreditNoteListView()
                                } label: {
                                    MoreViewRow(icon: "doc.text.fill", label: "Credit Notes")
                                }
                                rowDivider()

                                Button {
                                    showTemplatePicker = true
                                } label: {
                                    MoreViewRow(
                                        icon: "paintpalette.fill",
                                        label: "Invoice Template",
                                        value: selectedTemplate.title
                                    )
                                }
                                rowDivider()

                                Menu {
                                    ForEach(IndianStates.all, id: \.self) { state in
                                        Button {
                                            defaultState = state
                                            IndianStates.defaultState = state
                                        } label: {
                                            if defaultState == state {
                                                Label(state, systemImage: "checkmark")
                                            } else {
                                                Text(state)
                                            }
                                        }
                                    }
                                } label: {
                                    MoreViewRow(
                                        icon: "map.fill",
                                        label: "Default State",
                                        value: defaultState.isEmpty ? "Not set" : defaultState
                                    )
                                }
                            }
                            .padding(.horizontal, 14)
                            .background(Color.sCard)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)

                            // MARK: - Security Section
                            if biometricKind != .none {
                                sectionHeader("Security")

                                VStack(spacing: 0) {
                                    HStack(spacing: 14) {
                                        Image(systemName: biometricKind.icon)
                                            .font(.scaled(14))
                                            .foregroundColor(.sMutedFG)
                                            .frame(width: 24)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(biometricKind.label)
                                                .font(.scaled(14))
                                                .foregroundColor(.sForeground)
                                            Text("Unlock the app instead of staying logged out")
                                                .font(.scaled(11.5))
                                                .foregroundColor(.sMutedFG)
                                        }

                                        Spacer()

                                        Toggle("", isOn: Binding(
                                            get: { session.isBiometricLockEnabled },
                                            set: { newValue in toggleBiometric(newValue) }
                                        ))
                                        .labelsHidden()
                                        .tint(.sAccent)
                                    }
                                    .padding(.vertical, 12)
                                }
                                .padding(.horizontal, 14)
                                .background(Color.sCard)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
                                .cornerRadius(12)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 24)
                            }

                            // MARK: - Support Section
                            sectionHeader("Support")

                            VStack(spacing: 0) {
                                NavigationLink {
                                    HelpView()
                                } label: {
                                    MoreViewRowBasic(label: "Help & Support")
                                }

                                #if DEBUG
                                rowDivider()
                                Button {
                                    Task { await sendTestPush() }
                                } label: {
                                    MoreViewRowBasic(label: testPushStatus ?? "Send test notification")
                                }
                                #endif
                            }
                            .padding(.horizontal, 14)
                            .background(Color.sCard)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)

                            // MARK: - Sign Out Button
                            Button {
                                showSignOutConfirmation = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.scaled(14, weight: .semibold))
                                    Text("Sign out")
                                        .font(.scaled(14, weight: .semibold))
                                }
                                .foregroundColor(.sForeground)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.sCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.sBorder, lineWidth: 0.5)
                                )
                                .cornerRadius(10)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)

                            // MARK: - Delete Account Button
                            Button {
                                showDeleteConfirmation = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash")
                                        .font(.scaled(14))
                                    Text("Delete account")
                                        .font(.scaled(14, weight: .semibold))
                                }
                                .foregroundColor(.sDestructive.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.sDestructive.opacity(0.15), lineWidth: 0.5)
                                )
                                .cornerRadius(10)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)

                            // MARK: - Version
                            VStack(spacing: 6) {
                                Text(appVersion)
                                    .font(.scaled(11))
                                    .foregroundColor(.sMutedFG)
                                Text("© \(Calendar.current.component(.year, from: Date())) Invo Billing. All rights reserved.")
                                    .font(.scaled(10))
                                    .foregroundColor(.sMutedFG)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await vm.loadProfile()
            }

            // MARK: - Step 1 Warning Dialog
            .confirmationDialog(
                "Delete Account",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Continue to Delete", role: .destructive) {
                    showFinalDeleteConfirmation = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and ALL data — invoices, clients, companies, and expenses. This cannot be undone.")
            }
            .presentationCompactAdaptation(.sheet)

            // MARK: - Step 2 Final Confirmation
            .alert(
                "Are you absolutely sure?",
                isPresented: $showFinalDeleteConfirmation
            ) {
                Button("Delete My Account", role: .destructive) {
                    Task {
                        let success = await authVM.deleteAccount()
                        if !success {
                            showDeleteError = true
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your account and all data will be permanently deleted immediately. This action cannot be reversed.")
            }
            .alert("Error", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(authVM.errorMessage ?? "Failed to delete account")
            }

            // MARK: - Sign Out Confirmation
            .confirmationDialog(
                "Sign out of Invo Billing?",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign out", role: .destructive) {
                    SessionManager.shared.logout()
                }
                Button("Cancel", role: .cancel) {}
            }
            .presentationCompactAdaptation(.sheet)

            // MARK: - Invoice Template Picker
            .sheet(isPresented: $showTemplatePicker) {
                InvoiceTemplatePickerSheet(selected: $selectedTemplate) { template in
                    selectedTemplate = template
                    InvoiceTemplatePreference.save(template)
                    showTemplatePicker = false
                }
                .presentationDetents([.medium])
            }
            .alert("Error", isPresented: Binding(
                get: { biometricError != nil },
                set: { if !$0 { biometricError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(biometricError ?? "")
            }
        }
    }

    // MARK: - Biometric toggle
    private func toggleBiometric(_ enable: Bool) {
        guard enable else {
            session.isBiometricLockEnabled = false
            return
        }
        Task {
            let success = await BiometricAuthService.authenticate(
                reason: "Confirm \(biometricKind.label) to protect Invo Billing"
            )
            await MainActor.run {
                if success {
                    session.isBiometricLockEnabled = true
                } else {
                    biometricError = "Couldn't verify \(biometricKind.label). Please try again."
                }
            }
        }
    }

    #if DEBUG
    private func sendTestPush() async {
        testPushStatus = "Sending..."
        guard let url = URL(string: "\(AppEnvironment.baseURL)/push/test") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                testPushStatus = "Sent — check server log"
            } else {
                testPushStatus = "Failed — check server log"
            }
        } catch {
            testPushStatus = "Request failed: \(error.localizedDescription)"
        }
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        testPushStatus = nil
    }
    #endif

    // MARK: - Helpers
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.scaled(13, weight: .medium))
            .foregroundColor(.sMutedFG)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
    }

    private func rowDivider() -> some View {
        Rectangle()
            .fill(Color.sBorder)
            .frame(height: 0.5)
    }
}

// MARK: - More View Row (with icon)
struct MoreViewRow: View {
    let icon: String
    let label: String
    var value: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.scaled(14))
                .foregroundColor(.sMutedFG)
                .frame(width: 24)

            Text(label)
                .font(.scaled(14))
                .foregroundColor(.sForeground)

            Spacer()

            if let value {
                Text(value)
                    .font(.scaled(13))
                    .foregroundColor(.sMutedFG)
            }

            Image(systemName: "chevron.right")
                .font(.scaled(12, weight: .semibold))
                .foregroundColor(.sMutedFG)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - More View Row Basic (no icon)
struct MoreViewRowBasic: View {
    let label: String

    var body: some View {
        HStack {
            Text(label)
                .font(.scaled(14))
                .foregroundColor(.sForeground)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.scaled(12, weight: .semibold))
                .foregroundColor(.sMutedFG)
        }
        .padding(.vertical, 12)
    }
}
