import SwiftUI

enum IndianStates {
    /// GST state list — 28 states + 8 union territories, in the order GSTIN state codes are assigned.
    static let all: [String] = [
        "Jammu and Kashmir", "Himachal Pradesh", "Punjab", "Chandigarh", "Uttarakhand",
        "Haryana", "Delhi", "Rajasthan", "Uttar Pradesh", "Bihar",
        "Sikkim", "Arunachal Pradesh", "Nagaland", "Manipur", "Mizoram",
        "Tripura", "Meghalaya", "Assam", "West Bengal", "Jharkhand",
        "Odisha", "Chhattisgarh", "Madhya Pradesh", "Gujarat",
        "Daman and Diu", "Dadra and Nagar Haveli", "Maharashtra", "Andhra Pradesh",
        "Karnataka", "Goa", "Lakshadweep", "Kerala", "Tamil Nadu",
        "Puducherry", "Andaman and Nicobar Islands", "Telangana", "Ladakh",
        "Other Territory"
    ]

    private static let defaultStateKey = "default_state"

    /// The state pre-filled on new client/address forms — set once in Settings instead of
    /// picking the same state (usually the company's own) every single time.
    static var defaultState: String {
        get { UserDefaults.standard.string(forKey: defaultStateKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: defaultStateKey) }
    }
}

/// Dropdown field for picking an Indian state — used anywhere a GST-relevant address is
/// entered, since state determines CGST/SGST vs IGST on an invoice. Matches the bordered
/// box chrome of ClientField/CompanyFormField so it drops in as a like-for-like replacement.
struct IndianStatePicker: View {
    let label: String
    @Binding var text: String
    var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.scaled(13, weight: .medium))
                    .foregroundColor(.sForeground)
                if error != nil {
                    Image(systemName: "exclamationmark.circle")
                        .font(.scaled(12))
                        .foregroundColor(.sDestructive)
                }
            }

            Menu {
                ForEach(IndianStates.all, id: \.self) { state in
                    Button {
                        text = state
                    } label: {
                        if text == state {
                            Label(state, systemImage: "checkmark")
                        } else {
                            Text(state)
                        }
                    }
                }
            } label: {
                HStack {
                    Text(text.isEmpty ? "Select state" : text)
                        .font(.scaled(14))
                        .foregroundColor(text.isEmpty ? .sMutedFG : .sForeground)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.scaled(11, weight: .semibold))
                        .foregroundColor(.sMutedFG)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.sCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.sInput, lineWidth: 0.5)
                )
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
}
