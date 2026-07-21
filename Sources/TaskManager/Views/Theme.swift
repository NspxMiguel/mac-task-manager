import SwiftUI
import AppKit

/// Cores inspiradas no Task Manager do Windows 11, adaptadas para claro/escuro
/// automaticamente conforme a aparência do sistema (Ajustes > Geral > Aparência).
enum Theme {
    static let accent = Color(red: 0.36, green: 0.42, blue: 0.95)

    static let sidebarBackground = dynamic(
        light: NSColor(calibratedWhite: 0.90, alpha: 1),
        dark: NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.13, alpha: 1)
    )
    static let contentBackground = dynamic(
        light: NSColor(calibratedWhite: 0.96, alpha: 1),
        dark: NSColor(calibratedRed: 0.13, green: 0.13, blue: 0.15, alpha: 1)
    )
    static let cardBackground = dynamic(
        light: NSColor.white,
        dark: NSColor(calibratedRed: 0.17, green: 0.17, blue: 0.19, alpha: 1)
    )
    static let controlBackground = dynamic(
        light: NSColor.black.withAlphaComponent(0.045),
        dark: NSColor.white.withAlphaComponent(0.06)
    )
    static let rowHover = dynamic(
        light: NSColor.black.withAlphaComponent(0.04),
        dark: NSColor.white.withAlphaComponent(0.05)
    )
    static let separator = dynamic(
        light: NSColor.black.withAlphaComponent(0.09),
        dark: NSColor.white.withAlphaComponent(0.08)
    )

    /// A cor de "calor" que o Task Manager do Windows usa para destacar
    /// colunas de uso (quanto maior o valor, mais forte a cor).
    static func heat(_ fraction: Double, base: Color = accent) -> Color {
        base.opacity(min(max(fraction, 0), 1) * 0.5)
    }

    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}
