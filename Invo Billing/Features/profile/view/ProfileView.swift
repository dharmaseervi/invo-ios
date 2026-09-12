import SwiftUI

struct ProfileView: View {
    @StateObject var vm = UserViewModel()
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Group {
            ZStack {
                Color.sBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            
                            // MARK: - Content
                            if let profile = vm.profile {
                                
                                // MARK: - Avatar Section
                                VStack(spacing: 20) {
                                    Text(String(profile.email.prefix(1)).uppercased())
                                        .font(.scaled(30, weight: .semibold))
                                        .foregroundColor(.sAccentFG)
                                        .frame(width: 76, height: 76)
                                        .background(Color.sAccent)
                                        .cornerRadius(16)

                                    VStack(spacing: 4) {
                                        Text(profile.email)
                                            .font(.scaled(14, weight: .semibold))
                                            .foregroundColor(.sForeground)

                                        Text("User Account")
                                            .font(.scaled(12))
                                            .foregroundColor(.sMutedFG)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 28)

                                // MARK: - Account Information Section
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Account information")
                                        .font(.scaled(13, weight: .medium))
                                        .foregroundColor(.sMutedFG)

                                    VStack(spacing: 0) {
                                        ProfileRowZara(label: "Email", value: profile.email)
                                        Rectangle().fill(Color.sBorder).frame(height: 0.5)
                                        ProfileRowZara(label: "User ID", value: "\(profile.user_id)")
                                    }
                                    .padding(.horizontal, 14)
                                    .background(Color.sCard)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 24)

                                // MARK: - Account Status Section
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Account status")
                                        .font(.scaled(13, weight: .medium))
                                        .foregroundColor(.sMutedFG)

                                    HStack {
                                        Text("Status")
                                            .font(.scaled(13))
                                            .foregroundColor(.sForeground)

                                        Spacer()

                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(Color.sAccent)
                                                .frame(width: 6, height: 6)

                                            Text("Active")
                                                .font(.scaled(13))
                                                .foregroundColor(.sForeground)
                                        }
                                    }
                                    .padding(14)
                                    .background(Color.sCard)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 24)

                                // MARK: - Logout Button
                                VStack(spacing: 10) {
                                    Button(role: .destructive) {
                                        SessionManager.shared.logout()
                                    } label: {
                                        Text("Log out")
                                            .font(.scaled(14, weight: .semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .foregroundColor(.sDestructive)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.sDestructive, lineWidth: 0.5)
                                            )
                                    }

                                    Button(action: { dismiss() }) {
                                        Text("Close")
                                            .font(.scaled(14, weight: .semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(Color.sPrimary)
                                            .foregroundColor(.sAccentFG)
                                            .cornerRadius(10)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 40)

                            } else if let error = vm.errorMessage {
                                VStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.scaled(28))
                                        .foregroundColor(.sDestructive)

                                    Text(error)
                                        .font(.scaled(13))
                                        .foregroundColor(.sMutedFG)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(24)
                            } else {
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .tint(.sAccent)
                                    Text("Loading profile...")
                                        .font(.scaled(13))
                                        .foregroundColor(.sMutedFG)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .task { await vm.loadProfile() }
        }
    }
}

// MARK: - Profile Row (Zara Style)
struct ProfileRowZara: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.scaled(13))
                .foregroundColor(.sMutedFG)

            Spacer()

            Text(value)
                .font(.scaled(13, weight: .medium))
                .foregroundColor(.sForeground)
                .lineLimit(1)
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    ProfileView()
}
