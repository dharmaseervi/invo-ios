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

    /// Maps the 2-digit GSTIN state code to its full name from `IndianStates.all`.
    static let gstinStateCode: [String: String] = [
        "01": "Jammu and Kashmir",  "02": "Himachal Pradesh",       "03": "Punjab",
        "04": "Chandigarh",         "05": "Uttarakhand",             "06": "Haryana",
        "07": "Delhi",              "08": "Rajasthan",               "09": "Uttar Pradesh",
        "10": "Bihar",              "11": "Sikkim",                  "12": "Arunachal Pradesh",
        "13": "Nagaland",           "14": "Manipur",                 "15": "Mizoram",
        "16": "Tripura",            "17": "Meghalaya",               "18": "Assam",
        "19": "West Bengal",        "20": "Jharkhand",               "21": "Odisha",
        "22": "Chhattisgarh",       "23": "Madhya Pradesh",          "24": "Gujarat",
        "25": "Daman and Diu",      "26": "Dadra and Nagar Haveli",  "27": "Maharashtra",
        "28": "Andhra Pradesh",     "29": "Karnataka",               "30": "Goa",
        "31": "Lakshadweep",        "32": "Kerala",                  "33": "Tamil Nadu",
        "34": "Puducherry",         "35": "Andaman and Nicobar Islands",
        "36": "Telangana",          "37": "Andhra Pradesh",          "38": "Ladakh",
        "97": "Other Territory",    "99": "Other Territory",
    ]

    /// Returns the state name for the first 2 digits of a GSTIN, or nil if unknown.
    static func state(fromGSTIN gstin: String) -> String? {
        guard gstin.count >= 2 else { return nil }
        return gstinStateCode[String(gstin.prefix(2))]
    }

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
