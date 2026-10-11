//
//  DesignSystem.swift
//  Invo Billing
//
//  Created by dharmaseervi on 8/23/26.
//

// MARK: - Native iOS surfaces and Invo violet accent
import SwiftUI

// Native semantic surfaces follow Light/Dark Mode and Increase Contrast.
extension Color {
    static let sBackground = Color(uiColor: .systemGroupedBackground)
    static let sCard = Color(uiColor: .secondarySystemGroupedBackground)
    static let sBorder = Color(uiColor: .separator)
    static let sInput = Color(uiColor: .separator)
    static let sMuted = Color(uiColor: .tertiarySystemFill)
    static let sMutedFG = Color(uiColor: .secondaryLabel)
    static let sForeground = Color(uiColor: .label)

    // ✅ VIOLET accent — replaces blue #2563EB
    static let sAccent = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.671, green: 0.475, blue: 0.984, alpha: 1) // #AB79FB lighter in dark
        : UIColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 1) // #7C3AED
    })
    static let sAccentFG = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.039, green: 0.039, blue: 0.043, alpha: 1)
        : UIColor(red: 1.0,   green: 1.0,   blue: 1.0,   alpha: 1) // white on violet
    })
    static let sAccentMuted = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 0.15)
        : UIColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 0.08)
    })
    static let sRing = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.671, green: 0.475, blue: 0.984, alpha: 1)
        : UIColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 1)
    })
    // The one token that had no dark variant. #DC2626 on the dark card measures 3.81:1,
    // under the 4.5:1 needed for body text — and it is the colour every overdue amount
    // and every delete action is drawn in. The dark value is lifted to clear it.
    static let sDestructive = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.973, green: 0.443, blue: 0.443, alpha: 1) // #F87171 — 6.4:1 on #141417
        : UIColor(red: 0.863, green: 0.149, blue: 0.149, alpha: 1) // #DC2626 — 4.83:1 on white
    })
    
    // Primary is now violet — not black
    static let sPrimary = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.671, green: 0.475, blue: 0.984, alpha: 1)
        : UIColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 1)
    })
    static let sPrimaryFG = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.039, green: 0.039, blue: 0.043, alpha: 1)
        : UIColor(red: 1.0,   green: 1.0,   blue: 1.0,   alpha: 1)
    })

    // MARK: - Status colors
    static let sSuccess = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.204, green: 0.824, blue: 0.478, alpha: 1) // #34D27A — 5.9:1 on #141417
        : UIColor(red: 0.08, green: 0.45, blue: 0.24, alpha: 1) // Readable on light cards, including small status labels
    })
    static let sSuccessMuted = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.086, green: 0.639, blue: 0.341, alpha: 0.18)
        : UIColor(red: 0.086, green: 0.639, blue: 0.341, alpha: 0.10)
    })
    static let sWarning = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.984, green: 0.690, blue: 0.188, alpha: 1) // #FBB030
        : UIColor(red: 0.55, green: 0.34, blue: 0.02, alpha: 1) // Readable amber text on light cards
    })
    static let sWarningMuted = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.722, green: 0.494, blue: 0.051, alpha: 0.18)
        : UIColor(red: 0.722, green: 0.494, blue: 0.051, alpha: 0.10)
    })
    static let sNeutral = Color(UIColor { _ in UIColor.systemGray })
    static let sNeutralMuted = Color(UIColor { _ in UIColor.systemGray.withAlphaComponent(0.15) })
}


/// Shared spacing roles. Native List/Form keep their system insets.
enum AppSpacing {
    static let compact: CGFloat = 4
    static let inline: CGFloat = 8
    static let row: CGFloat = 12
    static let page: CGFloat = 16
    static let card: CGFloat = 16
    static let section: CGFloat = 24
    static let minimumTarget: CGFloat = 44
}

/// Reflows paired fields/figures at accessibility sizes instead of squeezing text.
struct AdaptiveFormRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var textSize
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.row))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: AppSpacing.row))
        layout { content }
    }
}

/// Shared scrollable-filter treatment with a full-size touch target and selection
/// information for VoiceOver; labels grow with Dynamic Type.
struct AppFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.sAccent : Color.sForeground)
                .padding(.horizontal, AppSpacing.row)
                .padding(.vertical, AppSpacing.inline)
                .background(isSelected ? Color.sAccentMuted : Color(uiColor: .secondarySystemFill), in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? Color.sAccent.opacity(0.4) : .clear, lineWidth: 1))
                .frame(minHeight: AppSpacing.minimumTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
