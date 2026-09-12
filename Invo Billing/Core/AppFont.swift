//
//  AppFont.swift
//  Invo Billing
//

import SwiftUI
import UIKit

/// Fonts that respect the reader's text size.
///
/// The app had 840 `.font(.system(size:))` calls and not one scalable font, so text did
/// not respond to Settings → Display & Brightness → Text Size at all. Someone who turns
/// that up — which in a shop is most people over forty — saw exactly the same 11pt
/// labels as everyone else, and the app simply could not be read.
///
/// `Font.system(size:)` is fixed by design, so this scales through `UIFontMetrics`
/// instead. At the default text size the point size is unchanged, which means none of
/// the existing layout moves; above it, text grows the way the reader asked for.
///
/// The text style each size is measured against matters: `UIFontMetrics` scales by
/// different amounts per style, and a caption should not grow as fast as a headline.
extension Font {

    /// A system font of `size` that scales with the reader's text size setting.
    static func scaled(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo style: UIFont.TextStyle? = nil
    ) -> Font {
        let base = UIFont.systemFont(ofSize: size, weight: weight.uiWeight)
        let metrics = UIFontMetrics(forTextStyle: style ?? defaultStyle(for: size))
        return Font(metrics.scaledFont(for: base))
    }

    /// The text style whose default size is closest, so each label scales at a rate
    /// appropriate to its role rather than all of them at the body rate.
    private static func defaultStyle(for size: CGFloat) -> UIFont.TextStyle {
        switch size {
        case ..<11.5: return .caption2      // 11
        case ..<12.5: return .caption1      // 12
        case ..<13.5: return .footnote      // 13
        case ..<15.5: return .subheadline   // 15
        case ..<16.5: return .callout       // 16
        case ..<17.5: return .body          // 17
        case ..<19.5: return .headline      // 17, heavier
        case ..<21.5: return .title3        // 20
        case ..<26.5: return .title2        // 22
        case ..<32.5: return .title1        // 28
        default: return .largeTitle         // 34
        }
    }
}

private extension Font.Weight {
    /// `Font.Weight` and `UIFont.Weight` are different types with the same meaning.
    var uiWeight: UIFont.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }
}
