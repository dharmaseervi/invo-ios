import SwiftUI

struct profileView: View {
    @StateObject var vm = UserViewModel()
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // MARK: - Header
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 14, weight: .light, design: .default))
                            }
                            .foregroundColor(.black)
                        }
                        
                        Spacer()
//                        
//                        Text("PROFILE")
//                            .font(.system(size: 12, weight: .semibold, design: .default))
//                            .tracking(0.5)
//                            .foregroundColor(.gray)
//                        
//                        Spacer()
//                        
//                        Image(systemName: "person.crop.circle")
//                            .font(.system(size: 14, weight: .semibold))
//                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    
//                    Divider()
//                        .frame(height: 1)
//                        .background(Color.black.opacity(0.08))
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            
                            // MARK: - Content
                            if let profile = vm.profile {
                                
                                // MARK: - Avatar Section
                                VStack(spacing: 24) {
                                    Text(String(profile.email.prefix(1)).uppercased())
                                        .font(.system(size: 32, weight: .semibold, design: .default))
                                        .foregroundColor(.white)
                                        .frame(width: 80, height: 80)
                                        .background(Color.black)
                                        .cornerRadius(8)
                                    
                                    VStack(spacing: 4) {
                                        Text(profile.email)
                                            .font(.system(size: 14, weight: .semibold, design: .default))
                                            .foregroundColor(.black)
                                        
                                        Text("User Account")
                                            .font(.system(size: 12, weight: .light, design: .default))
                                            .foregroundColor(.gray)
                                            .tracking(0.2)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                                
                                
                                
                                // MARK: - Account Information Section
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("ACCOUNT INFORMATION")
                                        .font(.system(size: 11, weight: .semibold, design: .default))
                                        .tracking(1)
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 24)
                                        .padding(.bottom, 16)
                                    
                                    VStack(spacing: 0) {
                                        ProfileRowZara(
                                            label: "Email",
                                            value: profile.email
                                        )
                                        
                                        Divider()
                                            .frame(height: 1)
                                            .background(Color.black.opacity(0.08))
                                            .padding(.horizontal, 24)
                                        
                                        ProfileRowZara(
                                            label: "User ID",
                                            value: "\(profile.user_id)"
                                        )
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 32)
                                }
                                
                                // MARK: - Account Status Section
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("ACCOUNT STATUS")
                                        .font(.system(size: 11, weight: .semibold, design: .default))
                                        .tracking(1)
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 24)
                                        .padding(.bottom, 16)
                                    
                                    VStack(spacing: 0) {
                                        HStack(spacing: 0) {
                                            Text("Status")
                                                .font(.system(size: 12, weight: .light, design: .default))
                                                .foregroundColor(.black)
                                            
                                            Spacer()
                                            
                                            HStack(spacing: 6) {
                                                Circle()
                                                    .fill(Color.black)
                                                    .frame(width: 6, height: 6)
                                                
                                                Text("Active")
                                                    .font(.system(size: 12, weight: .light, design: .default))
                                                    .foregroundColor(.black)
                                            }
                                        }
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                    }
                                    
                                }
                                
                                // MARK: - Logout Button
                                VStack(spacing: 12) {
                                    Button(role: .destructive) {
                                        SessionManager.shared.logout()
                                    } label: {
                                        Text("LOGOUT")
                                            .font(.system(size: 12, weight: .semibold, design: .default))
                                            .tracking(0.5)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .foregroundColor(.red)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 0)
                                                    .stroke(Color.red, lineWidth: 1)
                                            )
                                    }
                                    
                                    Button(action: { dismiss() }) {
                                        Text("CLOSE")
                                            .font(.system(size: 12, weight: .semibold, design: .default))
                                            .tracking(0.5)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(Color.black)
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 48)
                                
                            } else if let error = vm.errorMessage {
                                VStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 32, weight: .thin))
                                        .foregroundColor(.red)
                                    
                                    Text("Error")
                                        .font(.system(size: 14, weight: .semibold, design: .default))
                                    
                                    Text(error)
                                        .font(.system(size: 12, weight: .light, design: .default))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(24)
                            } else {
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .tint(.black)
                                    Text("Loading profile...")
                                        .font(.system(size: 13, weight: .light, design: .default))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
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
                .font(.system(size: 12, weight: .light, design: .default))
                .foregroundColor(.black)
                .tracking(0.2)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 12, weight: .light, design: .default))
                .foregroundColor(.black)
                .lineLimit(1)
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 12)
    }
}

#Preview {
    profileView()
}
