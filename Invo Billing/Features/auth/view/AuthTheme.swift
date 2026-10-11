import SwiftUI

/// Visual language for the auth flow (login, signup, biometric lock).
/// Adapts to the system's light/dark appearance, same as the rest of the app.
enum AuthTheme {
    static let background = Color(uiColor: .systemBackground)
    static let field = Color(uiColor: .secondarySystemFill)
    static let border = Color.sInput
    static let foreground = Color.sForeground
    static let muted = Color.sMutedFG
    static let accent = Color.sAccent
    static let accentBright = Color.sAccent
    static let destructive = Color.sDestructive
    static let success = Color(red: 0.196, green: 0.769, blue: 0.478)
    static let corner: CGFloat = 12
    static let controlHeight: CGFloat = 48
}

// MARK: - Backdrop (plain ground with a soft accent wash at the top)
struct AuthBackdrop: View {
    var body: some View {
        ZStack(alignment: .top) {
            AuthTheme.background
            LinearGradient(
                colors: [AuthTheme.accent.opacity(0.14), AuthTheme.accent.opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 340)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Header
struct AuthHeader: View {
    let title: String
    let subtitle: String
    var symbol: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.title2.weight(.medium))
                        .foregroundColor(AuthTheme.accent)
                        .frame(width: 56, height: 56)
                        .background(AuthTheme.accent.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .contentTransition(.symbolEffect(.replace))
                } else {
                    Image("LaunchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title.weight(.bold))
                    .foregroundColor(AuthTheme.foreground)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(AuthTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Grouped fields (one container, hairline dividers between rows)
struct AuthFieldGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(AuthTheme.field, in: RoundedRectangle(cornerRadius: AuthTheme.corner, style: .continuous))
    }
}

struct AuthRowDivider: View {
    var inset: CGFloat = 48
    var body: some View {
        Divider().padding(.leading, inset)
    }
}

struct AuthInputRow<Trailing: View>: View {
    let icon: String?
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType
    var contentType: UITextContentType?
    var isSecure: Bool
    let trailing: Trailing

    init(
        icon: String?,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        isSecure: Bool = false,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.placeholder = placeholder
        self._text = text
        self.keyboard = keyboard
        self.contentType = contentType
        self.isSecure = isSecure
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(AuthTheme.muted)
                    .frame(width: 22)
                    .accessibilityHidden(true)
            }

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.body)
            .foregroundColor(AuthTheme.foreground)
            .tint(AuthTheme.accent)
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            trailing
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
    }
}

extension AuthInputRow where Trailing == EmptyView {
    init(
        icon: String?,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        isSecure: Bool = false
    ) {
        self.init(icon: icon, placeholder: placeholder, text: text, keyboard: keyboard,
                  contentType: contentType, isSecure: isSecure) { EmptyView() }
    }
}

struct AuthRevealButton: View {
    @Binding var isRevealed: Bool

    var body: some View {
        Button { isRevealed.toggle() } label: {
            Image(systemName: isRevealed ? "eye.slash" : "eye")
                .font(.subheadline)
                .foregroundColor(AuthTheme.muted)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
    }
}

// MARK: - Back button (auth screens hide the navigation bar)
struct AuthBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.body.weight(.semibold))
                .foregroundColor(AuthTheme.foreground)
                .frame(width: 40, height: 40)
                .background(AuthTheme.field, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

// MARK: - One-time code entry (six boxes over a hidden field)
struct AuthCodeField: View {
    @Binding var code: String
    var length = 6
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .foregroundColor(.clear)
                .tint(.clear)
                .accessibilityLabel("Verification code")

            HStack(spacing: 8) {
                ForEach(0..<length, id: \.self) { i in
                    Text(digit(at: i))
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundColor(AuthTheme.foreground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AuthTheme.field, in: RoundedRectangle(cornerRadius: AuthTheme.corner, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AuthTheme.corner, style: .continuous)
                                .stroke(isActive(i) ? AuthTheme.accent : .clear, lineWidth: 1.5)
                        )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
            .accessibilityHidden(true)
        }
        .onChange(of: code) { newValue in
            let cleaned = String(newValue.filter(\.isNumber).prefix(length))
            if cleaned != newValue { code = cleaned }
        }
        .onAppear { focused = true }
        .animation(.easeOut(duration: 0.15), value: code)
    }

    private func digit(at index: Int) -> String {
        guard index < code.count else { return "" }
        return String(code[code.index(code.startIndex, offsetBy: index)])
    }

    private func isActive(_ index: Int) -> Bool {
        focused && index == min(code.count, length - 1)
    }
}

/// Quiet one-line note under a field (e.g. code expiry).
struct AuthHint: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.footnote)
            .foregroundColor(AuthTheme.muted)
    }
}

// MARK: - Labelled single field (OTP login, forgot password)
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
                .font(.footnote.weight(.medium))
                .foregroundColor(AuthTheme.muted)

            AuthFieldGroup {
                AuthInputRow(icon: nil, placeholder: placeholder, text: $text,
                             keyboard: keyboard, isSecure: isSecure) {
                    if let trailing { trailing }
                }
                .accessibilityLabel(label)
            }
        }
    }
}

// MARK: - Buttons
private struct AuthPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AuthPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).opacity(isLoading ? 0 : 1)
                if isLoading { ProgressView().tint(.white) }
            }
            .font(.body.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: AuthTheme.controlHeight)
            .background(AuthTheme.accent, in: RoundedRectangle(cornerRadius: AuthTheme.corner, style: .continuous))
        }
        .buttonStyle(AuthPressStyle())
        .disabled(isLoading)
        .accessibilityLabel(isLoading ? "\(title), in progress" : title)
    }
}

/// Label for a quieter, tinted action — wrap in a Button or NavigationLink.
struct AuthSecondaryLabel: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.body.weight(.medium))
        .foregroundColor(AuthTheme.accent)
        .frame(maxWidth: .infinity)
        .frame(height: AuthTheme.controlHeight)
        .background(AuthTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: AuthTheme.corner, style: .continuous))
    }
}

// MARK: - Shared error banner
struct AuthErrorBanner: View {
    let message: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
            Text(message)
            Spacer(minLength: 0)
        }
        .font(.footnote)
        .foregroundColor(AuthTheme.destructive)
        .padding(12)
        .background(AuthTheme.destructive.opacity(0.08), in: RoundedRectangle(cornerRadius: AuthTheme.corner, style: .continuous))
    }
}

// MARK: - Legacy field name (still used by OTP login / forgot password)
struct VioletField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let keyboard: UIKeyboardType
    let isSecure: Bool
    var body: some View {
        AuthField(label: label, placeholder: placeholder, text: $text,
                  keyboard: keyboard, isSecure: isSecure)
    }
}
