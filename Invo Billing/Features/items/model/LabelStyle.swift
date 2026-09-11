import Combine
import Foundation
import UIKit

enum LabelTextAlignment: String, Codable, CaseIterable, Hashable {
    case left, center, right

    var nsAlignment: NSTextAlignment {
        switch self {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }

    var label: String {
        switch self {
        case .left: return "Left"
        case .center: return "Center"
        case .right: return "Right"
        }
    }

    var icon: String {
        switch self {
        case .left: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .right: return "text.alignright"
        }
    }
}

/// A distinct label layout, not just a size — each arranges name/price/details/code
/// differently, so bigger label sizes have an option that actually fills the space
/// instead of just stretching the same left-stacked text layout with empty margins.
enum LabelTemplate: String, Codable, CaseIterable, Hashable {
    case standard
    case bordered
    case compact
    case centered

    var label: String {
        switch self {
        case .standard: return "Standard"
        case .bordered: return "Bordered"
        case .compact: return "Compact"
        case .centered: return "Centered"
        }
    }

    var subtitle: String {
        switch self {
        case .standard: return "Name, details, code"
        case .bordered: return "Framed, shelf-tag style"
        case .compact: return "Essentials only, tight"
        case .centered: return "Centered, big code"
        }
    }

    var icon: String {
        switch self {
        case .standard: return "rectangle.lefthalf.filled"
        case .bordered: return "rectangle.badge.checkmark"
        case .compact: return "rectangle.compress.vertical"
        case .centered: return "square.and.line.vertical.and.square"
        }
    }
}

/// User-configurable label appearance. `titleScale`/`bodyScale` are *relative*
/// multipliers applied on top of each label size's own base font sizes — never absolute
/// point values — so turning text up for a big label doesn't blow past a small label's
/// canvas the next time you switch, and vice versa. Persisted so it's set once and
/// applies to every future label.
struct LabelStyle: Codable, Equatable {
    var titleScale: CGFloat = 1.0
    var bodyScale: CGFloat = 1.0
    var showPrice: Bool = true
    var showID: Bool = true
    var showCostCode: Bool = true
    var textAlignment: LabelTextAlignment = .left
    var template: LabelTemplate = .standard

    static let scaleRange: ClosedRange<CGFloat> = 0.75...1.5
}

@MainActor
final class LabelStyleManager: ObservableObject {
    static let shared = LabelStyleManager()

    @Published var style: LabelStyle {
        didSet {
            if let data = try? JSONEncoder().encode(style) {
                UserDefaults.standard.set(data, forKey: Self.key)
            }
        }
    }

    private static let key = "label_style_settings"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(LabelStyle.self, from: data) {
            style = decoded
        } else {
            style = LabelStyle()
        }
    }

    func resetToDefault() {
        style = LabelStyle()
    }
}
