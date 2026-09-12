import SwiftUI

struct BiometricLockView: View {
    @EnvironmentObject var session: SessionManager
    @State private var isAuthenticating = false
    @State private var failed = false

    private let kind = BiometricAuthService.availableKind()

    var body: some View {
        ZStack {
            AuthTheme.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AuthTheme.accent.opacity(0.35), AuthTheme.accent.opacity(0)],
                                center: .center, startRadius: 4, endRadius: 90
                            )
                        )
                        .frame(width: 180, height: 180)

                    Image(systemName: kind.icon)
                        .font(.scaled(46, weight: .medium))
                        .foregroundColor(AuthTheme.accentBright)
                }

                VStack(spacing: 6) {
                    Text("Welcome back")
                        .font(.scaled(22, weight: .bold))
                        .foregroundColor(AuthTheme.foreground)
                    Text("Use \(kind.label) to continue to Invo Billing")
                        .font(.scaled(13))
                        .foregroundColor(AuthTheme.muted)
                }

                if failed {
                    Text("Couldn't verify — try again")
                        .font(.scaled(12.5))
                        .foregroundColor(AuthTheme.destructive)
                }

                Spacer()

                VStack(spacing: 14) {
                    AuthPrimaryButton(
                        title: "Unlock with \(kind.label)",
                        isLoading: isAuthenticating,
                        action: authenticate
                    )

                    Button {
                        session.logout()
                    } label: {
                        Text("Sign out instead")
                            .font(.scaled(13, weight: .medium))
                            .foregroundColor(AuthTheme.muted)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear { authenticate() }
    }

    private func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        failed = false
        Task {
            let success = await session.unlockWithBiometrics()
            await MainActor.run {
                isAuthenticating = false
                failed = !success
            }
        }
    }
}
