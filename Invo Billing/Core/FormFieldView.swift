import SwiftUI

/// A labelled text field in the standard form style (label above, bordered container).
/// Use this everywhere a single-line input is needed in forms.
struct FormFieldView: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .accessibilityLabel(label)
                .keyboardType(keyboard)
                .font(.body)
                .foregroundColor(.sForeground)
                .tint(.sAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, AppSpacing.row)
                .background(Color.sCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.sInput, lineWidth: 0.5)
                )
                .cornerRadius(8)
        }
    }
}
