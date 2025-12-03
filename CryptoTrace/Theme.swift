import SwiftUI

// Semantic, app-wide theme
struct AppTheme {
    // Primary accent (light blue)
    let accent: Color

    // Backgrounds and surfaces
    let background: Color          // full screen background
    let surface: Color             // cards, list row backgrounds
    let subtleFill: Color          // placeholders, chips
    let surfaceStroke: Color       // 1pt strokes for cards/containers

    // Text
    let primaryText: Color
    let secondaryText: Color

    // Convenience factory for light/dark adaptive theme with a blue-forward feel
    static var current: AppTheme {
        // Use dynamic colors that adapt to system appearance
        let accent = Color(red: 0.30, green: 0.64, blue: 1.00) // ~#4DA3FF

        // Use system backgrounds with a slight blue bias in fills
        let background = Color(.systemBackground)
        // Surface with a hint of blue in both modes
        let surface = Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1.0) // dark bluish surface
            } else {
                return UIColor(red: 0.96, green: 0.98, blue: 1.00, alpha: 1.0) // very light blue-tinted
            }
        })
        let subtleFill = Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.18, green: 0.22, blue: 0.28, alpha: 1.0)
            } else {
                return UIColor(red: 0.90, green: 0.95, blue: 1.00, alpha: 1.0)
            }
        })
        let surfaceStroke = Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(white: 1.0, alpha: 0.08)
            } else {
                return UIColor(red: 0.30, green: 0.64, blue: 1.00, alpha: 0.20)
            }
        })

        let primaryText = Color.primary
        let secondaryText = Color.secondary

        return AppTheme(
            accent: accent,
            background: background,
            surface: surface,
            subtleFill: subtleFill,
            surfaceStroke: surfaceStroke,
            primaryText: primaryText,
            secondaryText: secondaryText
        )
    }
}

// Environment key
private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .current
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

// Convenience modifier to set theme if you ever want to override per subtree
extension View {
    func appTheme(_ theme: AppTheme) -> some View {
        environment(\.appTheme, theme)
    }
}
