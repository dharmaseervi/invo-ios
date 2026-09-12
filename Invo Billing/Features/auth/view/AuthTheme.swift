import SwiftUI

/// Visual language for the auth flow (login, signup, biometric lock).
/// Adapts to the system's light/dark appearance, same as the rest of the app.
enum AuthTheme {
    static let background = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.039, green: 0.039, blue: 0.063, alpha: 1) // #0A0A10
        : UIColor(red: 0.980, green: 0.980, blue: 0.984, alpha: 1) // #FAFAFB
    })
    static let field = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.078, green: 0.071, blue: 0.114, alpha: 1) // #14121D
        : UIColor(red: 0.965, green: 0.961, blue: 0.984, alpha: 1) // #F6F5FB
    })
    static let border = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.133, green: 0.122, blue: 0.188, alpha: 1) // #221F30
        : UIColor(red: 0.902, green: 0.894, blue: 0.933, alpha: 1) // #E6E4EE
    })
    static let foreground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.945, green: 0.937, blue: 0.969, alpha: 1) // #F1EFF7
        : UIColor(red: 0.078, green: 0.078, blue: 0.098, alpha: 1) // #141419
    })
    static let muted = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.416, green: 0.400, blue: 0.518, alpha: 1) // #6A6684
        : UIColor(red: 0.443, green: 0.427, blue: 0.518, alpha: 1) // #716D84
    })
    static let accent = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.561, green: 0.420, blue: 0.941, alpha: 1) // #8F6BF0
        : UIColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 1) // #7C3AED
    })
    static let accentBright = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.718, green: 0.612, blue: 1.0,   alpha: 1) // #B79CFF
        : UIColor(red: 0.435, green: 0.196, blue: 0.847, alpha: 1) // #6F32D8
    })
    static let destructive = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.933, green: 0.392, blue: 0.353, alpha: 1) // #EE645A
        : UIColor(red: 0.863, green: 0.149, blue: 0.149, alpha: 1) // #DC2626
    })
}

// MARK: - Shared field style
struct AuthField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var isSecure: Bool = false
    var trailing: AnyView? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.scaled(12.5, weight: .medium))
                .foregroundColor(AuthTheme.muted)

            HStack(spacing: 10) {
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(.scaled(14))
                .foregroundColor(AuthTheme.foreground)
                .tint(AuthTheme.accentBright)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                if let trailing { trailing }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AuthTheme.field)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AuthTheme.border, lineWidth: 1)
            )
            .cornerRadius(10)
        }
    }
}

// MARK: - Shared primary button (the signature violet glow)
struct AuthPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.85)
                } else {
                    Text(title)
                        .font(.scaled(15, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                LinearGradient(
                    colors: [AuthTheme.accent, Color(red: 0.322, green: 0.188, blue: 0.741)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .cornerRadius(10)
            .shadow(color: AuthTheme.accent.opacity(0.45), radius: 18, x: 0, y: 8)
        }
        .disabled(isLoading)
    }
}

// MARK: - Shared error banner
struct AuthErrorBanner: View {
    let message: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.scaled(13))
            Text(message)
                .font(.scaled(13))
            Spacer()
        }
        .foregroundColor(AuthTheme.destructive)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AuthTheme.destructive.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AuthTheme.destructive.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Legacy light-style field (still used by OTP login / forgot password)
struct VioletField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let keyboard: UIKeyboardType
    let isSecure: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.scaled(13, weight: .medium))
                .foregroundColor(.sForeground)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.scaled(14))
            .foregroundColor(.sForeground)
            .tint(.sAccent)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.sCard)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.sInput, lineWidth: 0.5)
            )
            .cornerRadius(8)
        }
    }
}

// MARK: - Shared logo + glow
struct AuthLogo: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AuthTheme.accent.opacity(0.35), AuthTheme.accent.opacity(0)],
                        center: .center, startRadius: 4, endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)

            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
        }
    }
}
