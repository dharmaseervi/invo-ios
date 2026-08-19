import SwiftUI

struct MoreView: View {
    @StateObject var vm = UserViewModel()
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirmation = false
    @State private var showFinalDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // MARK: - Header
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SETTINGS")
                            .font(.system(size: 28, weight: .thin))
                            .tracking(0.5)
                        Divider()
                            .frame(height: 1)
                            .background(Color.black)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            
                            // MARK: - Profile Section
                            VStack(alignment: .leading, spacing: 0) {
                                Text("PROFILE")
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(1)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 16)
                                
                                NavigationLink {
                                    profileView()
                                } label: {
                                    HStack(spacing: 16) {
                                        Text(String(vm.profile?.email.prefix(1).uppercased() ?? "U"))
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.white)
                                            .frame(width: 56, height: 56)
                                            .background(Color.black)
                                            .cornerRadius(4)
                                        
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(vm.profile?.email ?? "Loading...")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.black)
                                            Text("User ID: \(vm.profile?.user_id ?? 0)")
                                                .font(.system(size: 11, weight: .light))
                                                .foregroundColor(.gray)
                                                .tracking(0.2)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.black.opacity(0.3))
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 14)
                                    .background(Color.black.opacity(0.02))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 0)
                                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                    )
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 32)
                            }
                            
                            // MARK: - Account Section
                            sectionHeader("ACCOUNT")
                            
                            VStack(spacing: 0) {
                                NavigationLink {
                                    companyView()
                                } label: {
                                    MoreViewRow(icon: "building.2.fill", label: "Company Details")
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
                                    CreditNoteListView()
                                } label: {
                                    MoreViewRow(icon: "doc.text.fill", label: "Credit Notes")
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)
                            
                            // MARK: - Support Section
                            sectionHeader("SUPPORT")
                            
                            VStack(spacing: 0) {
                                NavigationLink {
                                    HelpView()
                                } label: {
                                    MoreViewRowBasic(label: "Help & Support")
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)
                            
                            // MARK: - Sign Out Button
                            Button {
                                SessionManager.shared.logout()
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 14, weight: .light))
                                    Text("SIGN OUT")
                                        .font(.system(size: 12, weight: .semibold))
                                        .tracking(0.5)
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)
                            
                            // MARK: - Delete Account Button
                            Button {
                                showDeleteConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .light))
                                    Text("DELETE ACCOUNT")
                                        .font(.system(size: 12, weight: .semibold))
                                        .tracking(0.5)
                                }
                                .foregroundColor(.red.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.red.opacity(0.15), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)
                            
                            // MARK: - Version
                            VStack(spacing: 8) {
                                Text("Version 1.0.2")
                                    .font(.system(size: 11, weight: .light))
                                    .foregroundColor(.gray)
                                    .tracking(0.2)
                                Text("© 2025 invo. All rights reserved.")
                                    .font(.system(size: 10, weight: .light))
                                    .foregroundColor(.gray.opacity(0.6))
                                    .tracking(0.2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 48)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
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
            
            // MARK: - Step 2 Final Confirmation
            .alert(
                "Are you absolutely sure?",
                isPresented: $showFinalDeleteConfirmation
            ) {
                Button("Delete My Account", role: .destructive) {
                    Task {
                        let success = await authVM.deleteAccount()
                        if !success {
                            // error handled in authVM.errorMessage
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your account and all data will be permanently deleted immediately. This action cannot be reversed.")
            }
        }
    }
    
    // MARK: - Helpers
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
    }
    
    private func rowDivider() -> some View {
        Divider()
            .frame(height: 1)
            .background(Color.black.opacity(0.08))
    }
}

// MARK: - More View Row (with icon)
struct MoreViewRow: View {
    let icon: String
    let label: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.black.opacity(0.6))
                .frame(width: 24)
            
            Text(label)
                .font(.system(size: 13, weight: .light))
                .foregroundColor(.black)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.black.opacity(0.3))
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
                .font(.system(size: 13, weight: .light))
                .foregroundColor(.black)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.black.opacity(0.3))
        }
        .padding(.vertical, 12)
    }
}
