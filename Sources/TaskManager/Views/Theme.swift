import SwiftUI
import AppKit

/// One accent, true black in dark mode, and depth from a 6% hairline instead
/// of grey-blue panels with borders. Light mode is its own palette (opaque
/// white on light grey), not the dark one brightened.
enum Theme {
    static let accent = dynamic(
        light: NSColor(calibratedRed: 0.18, green: 0.38, blue: 0.85, alpha: 1),
        dark: NSColor(calibratedRed: 0.24, green: 0.49, blue: 1.0, alpha: 1)
    )
    /// Only for state, never decoration: a value the user should act on.
    static let warning = Color(nsColor: .systemOrange)
    static let danger = Color(nsColor: .systemRed)

    static let sidebarBackground = contentBackground
    static let contentBackground = dynamic(
        light: NSColor(calibratedRed: 0.95, green: 0.95, blue: 0.97, alpha: 1),
        dark: NSColor.black
    )
    static let cardBackground = dynamic(
        light: NSColor.white,
        dark: NSColor.white.withAlphaComponent(0.045)
    )
    static let controlBackground = dynamic(
        light: NSColor.black.withAlphaComponent(0.05),
        dark: NSColor.white.withAlphaComponent(0.08)
    )
    static let rowHover = dynamic(
        light: NSColor.black.withAlphaComponent(0.04),
        dark: NSColor.white.withAlphaComponent(0.05)
    )
    static let separator = dynamic(
        light: NSColor.black.withAlphaComponent(0.08),
        dark: NSColor.white.withAlphaComponent(0.06)
    )

    /// Usage tint behind a busy value. Stays invisible for idle processes so
    /// only what is actually working draws the eye.
    static func heat(_ fraction: Double, base: Color = accent) -> Color {
        let f = min(max(fraction, 0), 1)
        return f < 0.02 ? .clear : base.opacity(0.12 + f * 0.35)
    }

    /// Bar color: the accent until the value deserves attention.
    static func level(_ fraction: Double) -> Color {
        fraction > 0.9 ? danger : (fraction > 0.75 ? warning : accent)
    }

    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

extension Double {
    /// "640 MB" below a gigabyte, "1.7 GB" from there on.
    var megabytesText: String {
        self >= 1024 ? String(format: "%.1f GB", self / 1024) : String(format: "%.0f MB", self)
    }
}
