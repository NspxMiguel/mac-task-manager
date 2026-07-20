import SwiftUI

/// Cores inspiradas no tema escuro do Task Manager do Windows 11 (Mica),
/// adaptadas para os componentes nativos do macOS (vibrancy, SF Symbols).
enum Theme {
    static let sidebarBackground = Color(red: 0.11, green: 0.11, blue: 0.13)
    static let contentBackground = Color(red: 0.13, green: 0.13, blue: 0.15)
    static let cardBackground = Color(red: 0.17, green: 0.17, blue: 0.19)
    static let rowHover = Color.white.opacity(0.05)
    static let separator = Color.white.opacity(0.08)
    static let accent = Color(red: 0.36, green: 0.42, blue: 0.95)

    /// A cor de "calor" que o Task Manager do Windows usa para destacar
    /// colunas de uso (quanto maior o valor, mais forte a cor).
    static func heat(_ fraction: Double, base: Color = accent) -> Color {
        base.opacity(min(max(fraction, 0), 1) * 0.5)
    }
}
