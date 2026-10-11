import SwiftUI

struct MoreView: View {
    @State private var notificationsOn = false
    @State private var notificationsDenied = false

    #if DEBUG
    @State private var debugScreenOpen = false
    #endif
    @StateObject var vm = UserViewModel()
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var session: SessionManager
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirmation = false
    @State private var showFinalDeleteConfirmation = false
    @State private var showDeleteError = false
    @State private var deletePassword = ""
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
            List {

                // MARK: - Profile
                Section {
                    NavigationLink { ProfileView() } label: {
                        HStack(spacing: 14) {
                            Text(String(vm.profile?.email.prefix(1).uppercased() ?? "U"))
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.sAccentFG)
                                .frame(width: 48, height: 48)
                                .background(Color.sAccent, in: RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(vm.profile?.email ?? "Loading…")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text("View profile")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // MARK: - Sales
                Section("Sales") {
                    NavigationLink { EstimateListView() } label: {
                        MoreViewRow(icon: "doc.badge.clock", label: "Estimates")
                    }
                    NavigationLink { CreditNoteListView() } label: {
                        MoreViewRow(icon: "doc.text.fill", label: "Credit notes")
                    }
                    NavigationLink { ChallanListView() } label: {
                        MoreViewRow(icon: "shippingbox", label: "Delivery challans")
                    }
                }

                // MARK: - Purchases
                if session.companyRole.canSeeCosts {
                    Section("Purchases") {
                        NavigationLink { PurchasesView() } label: {
                            MoreViewRow(icon: "shippingbox.fill", label: "Purchases")
                        }
                        NavigationLink { PurchaseLedgerView() } label: {
                            MoreViewRow(icon: "text.book.closed.fill", label: "Purchase ledger")
                        }
                    }
                }

                // MARK: - Money
                if session.companyRole.canSeeReports {
                    Section("Money") {
                        NavigationLink { PaymentsView() } label: {
                            MoreViewRow(icon: "indianrupeesign.circle.fill", label: "Payments")
                        }
                        NavigationLink { ExpenseView() } label: {
                            MoreViewRow(icon: "banknote.fill", label: "Expenses")
                        }
                        NavigationLink { LedgerView() } label: {
                            MoreViewRow(icon: "book.fill", label: "Customer ledger")
                        }
                        NavigationLink { CashClosingView() } label: {
                            MoreViewRow(icon: "indianrupeesign.square", label: "Cash closing")
                        }
                    }
                }

                // MARK: - Inventory
                if session.companyRole.canEditCatalogue || session.companyRole.canSeeReports {
                    Section("Inventory") {
                        if session.companyRole.canEditCatalogue {
                            NavigationLink { StocktakeView() } label: {
                                MoreViewRow(icon: "checklist", label: "Stock count")
                            }
                        }
                        if session.companyRole.canSeeReports {
                            NavigationLink { StockReportView() } label: {
                                MoreViewRow(icon: "shippingbox.fill", label: "Stock report")
                            }
                        }
                    }
                }

                // MARK: - Reports
                if session.companyRole.canSeeReports {
                    Section("Reports") {
                        NavigationLink { ProfitLossView() } label: {
                            MoreViewRow(icon: "chart.bar.doc.horizontal", label: "Profit & Loss")
                        }
                        NavigationLink { GSTReportView() } label: {
                            MoreViewRow(icon: "doc.text.magnifyingglass", label: "GST reports")
                        }
                        NavigationLink { AgingReportView() } label: {
                            MoreViewRow(icon: "clock.badge.exclamationmark", label: "Client aging")
                        }
                        NavigationLink { SupplierAgingReportView() } label: {
                            MoreViewRow(icon: "clock.badge.exclamationmark.fill", label: "Supplier aging")
                        }
                        NavigationLink { OverdueRemindersView() } label: {
                            MoreViewRow(icon: "bell.badge.fill", label: "Overdue reminders")
                        }
                    }
                }

                // MARK: - Business
                if session.companyRole.canChangeSettings || session.companyRole.canManageStaff {
                    Section("Business") {
                        if session.companyRole.canChangeSettings {
                            NavigationLink { CompanyView() } label: {
                                MoreViewRow(icon: "building.2.fill", label: "Company details")
                            }
                        }
                        if session.companyRole.canManageStaff {
                            NavigationLink { StaffView() } label: {
                                MoreViewRow(icon: "person.2.fill", label: "Staff")
                            }
                        }
                    }
                }

                // MARK: - Settings
                Section("Settings") {
                    Button { showTemplatePicker = true } label: {
                        MoreViewRow(icon: "paintpalette.fill", label: "Invoice template", value: selectedTemplate.title)
                    }
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
                        MoreViewRow(icon: "map.fill", label: "Default state", value: defaultState.isEmpty ? "Not set" : defaultState)
                    }
                    notificationRow
                }

                // MARK: - Security
                Section("Security") {
                    if biometricKind != .none {
                        HStack {
                            Image(systemName: biometricKind.icon)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(biometricKind.label)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Text("Unlock the app instead of staying logged out")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { session.isBiometricLockEnabled },
                                set: { newValue in toggleBiometric(newValue) }
                            ))
                            .labelsHidden()
                            .tint(.sAccent)
                        }
                    }
                    NavigationLink { ActiveSessionsView() } label: {
                        MoreViewRow(icon: "person.2.badge.key", label: "Active sessions")
                    }
                }

                // MARK: - Support
                Section("Support") {
                    NavigationLink { HelpView() } label: {
                        MoreViewRowBasic(label: "Help & Support")
                    }
                    #if DEBUG
                    Button {
                        Task { await sendTestPush() }
                    } label: {
                        MoreViewRowBasic(label: testPushStatus ?? "Send test notification")
                    }
                    #endif
                }

                // MARK: - Sign Out / Delete
                Section {
                    Button {
                        showSignOutConfirmation = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.subheadline.weight(.semibold))
                            Text("Sign out")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                Section {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash")
                                .font(.body)
                            Text("Delete account")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(Color.sDestructive.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                // MARK: - Version
                Section {
                    VStack(spacing: 4) {
                        Text(appVersion)
                            .font(.caption)
                        Text("© \(Calendar.current.component(.year, from: Date())) Invo Billing. All rights reserved.")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

            }
            .listStyle(.insetGrouped)
            .navigationTitle("More")
            #if DEBUG
            .navigationDestination(isPresented: $debugScreenOpen) {
                switch UserDefaults.standard.string(forKey: "startScreen") ?? "" {
                case "estimates": AnyView(EstimateListView())
                case "expenses": AnyView(ExpenseView())
                case "ledger": AnyView(LedgerView())
                case "gst": AnyView(GSTReportView())
                case "aging": AnyView(AgingReportView())
                case "stock": AnyView(StockReportView())
                case "pl": AnyView(ProfitLossView())
                case "credit": AnyView(CreditNoteListView())
                case "company": AnyView(CompanyView())
                case "expenseform": AnyView(ExpenseFormView())
                case "estimateform": AnyView(CreateEstimateView())
                case "printinvoice": AnyView(DebugPrintPreviewLoader())
                case "pdflook": AnyView(DebugPDFLookLoader())
                case "invoice100": AnyView(DebugInvoice100View())
                default: AnyView(EmptyView())
                }
            }
            .onAppear {
                if UserDefaults.standard.string(forKey: "startScreen") != nil {
                    debugScreenOpen = true
                }
            }
            #endif
            .navigationBarTitleDisplayMode(.large)
            .task { await vm.loadProfile() }
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
            .alert(
                "Enter your password",
                isPresented: $showFinalDeleteConfirmation
            ) {
                SecureField("Password", text: $deletePassword)
                Button("Delete My Account", role: .destructive) {
                    let password = deletePassword
                    deletePassword = ""
                    Task {
                        let success = await authVM.deleteAccount(password: password)
                        if !success { showDeleteError = true }
                    }
                }
                Button("Cancel", role: .cancel) { deletePassword = "" }
            } message: {
                Text("Your account and all data will be permanently deleted immediately. This action cannot be reversed.")
            }
            .alert("Error", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(authVM.errorMessage ?? "Failed to delete account")
            }
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
        testPushStatus = "Sending…"
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

    /// Reminders about invoices that have become overdue. Off until asked for.
    private var notificationRow: some View {
        HStack {
            Image(systemName: "bell.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text("Overdue reminders")
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { notificationsOn },
                set: { wanted in
                    if wanted {
                        Task {
                            if notificationsDenied {
                                openSystemSettings()
                            } else {
                                notificationsOn = await PushNotificationManager.shared.requestAuthorization()
                                await refreshNotificationStatus()
                            }
                        }
                    } else {
                        openSystemSettings()
                    }
                }
            ))
            .labelsHidden()
            .tint(.sAccent)
        }
        .task { await refreshNotificationStatus() }
    }

    private func refreshNotificationStatus() async {
        let status = await PushNotificationManager.shared.authorizationStatus()
        notificationsOn = status == .authorized
        notificationsDenied = status == .denied
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - More View Row (icon + label + optional trailing value)
struct MoreViewRow: View {
    let icon: String
    let label: String
    var value: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            if let value {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - More View Row Basic (label only, no icon)
struct MoreViewRowBasic: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.subheadline)
            .foregroundStyle(.primary)
    }
}
