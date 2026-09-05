//
//  DesignSystem.swift
//  Invo Billing
//
//  Created by dharmaseervi on 8/23/26.
//

// MARK: - shadcn Design Tokens (Violet accent)
import SwiftUI

extension Color {
    static let sBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.047, green: 0.047, blue: 0.055, alpha: 1) // #0C0C0E
        : UIColor(red: 0.980, green: 0.980, blue: 0.980, alpha: 1) // #FAFAFA
    })
    static let sCard = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.078, green: 0.078, blue: 0.090, alpha: 1) // #141417
        : UIColor(red: 1.0,   green: 1.0,   blue: 1.0,   alpha: 1) // #FFFFFF
    })
    static let sBorder = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.165, green: 0.165, blue: 0.188, alpha: 1) // #2A2A30
        : UIColor(red: 0.886, green: 0.886, blue: 0.906, alpha: 1) // #E2E2E7
    })
    static let sInput = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.165, green: 0.165, blue: 0.188, alpha: 1)
        : UIColor(red: 0.886, green: 0.886, blue: 0.906, alpha: 1)
    })
    static let sMuted = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.137, green: 0.137, blue: 0.157, alpha: 1) // #232328
        : UIColor(red: 0.961, green: 0.961, blue: 0.965, alpha: 1) // #F5F5F7
    })
    static let sMutedFG = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.557, green: 0.557, blue: 0.600, alpha: 1) // #8E8E99
        : UIColor(red: 0.420, green: 0.420, blue: 0.471, alpha: 1) // #6B6B78
    })
    static let sForeground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
        ? UIColor(red: 0.961, green: 0.961, blue: 0.965, alpha: 1) // #F5F5F7
        : UIColor(red: 0.039, green: 0.039, blue: 0.043, alpha: 1) // #0A0A0B
    })
    
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
    static let sDestructive = Color(red: 0.863, green: 0.149, blue: 0.149) // #DC2626
    
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
}

