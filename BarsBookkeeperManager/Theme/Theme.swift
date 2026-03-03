import SwiftUI

// MARK: - Theme Colors (matching the web app's CSS custom properties)

struct AppColors {
    // Light theme
    struct Light {
        static let bgPrimary = Color(hex: "#ffffff")
        static let bgSecondary = Color(hex: "#f7f7f5")
        static let bgSurface = Color(hex: "#ffffff")
        static let bgHover = Color(hex: "#efefef")
        static let bgActive = Color(hex: "#e5e5e5")
        static let bgCard = Color(hex: "#fdfdfd")
        static let bgHeader = Color(hex: "#fafafa")
        static let bgInput = Color(hex: "#ffffff")
        static let bgIcon = Color(hex: "#f4f4f5")

        static let textPrimary = Color(hex: "#37352f")
        static let textSecondary = Color(hex: "#787774")
        static let textTertiary = Color(hex: "#9ca3af")
        static let textInverse = Color(hex: "#ffffff")
        static let textLink = Color(hex: "#2eaadc")

        static let borderSubtle = Color(hex: "#e9e9e7")
        static let borderDefault = Color.black.opacity(0.08)
        static let borderStrong = Color.black.opacity(0.16)
        static let borderFocus = Color(hex: "#2eaadc")

        static let success = Color(hex: "#22c55e")
        static let successSubtle = Color(hex: "#dcfce7")
        static let error = Color(hex: "#ef4444")
        static let errorSubtle = Color(hex: "#fee2e2")
        static let warning = Color(hex: "#f59e0b")
        static let warningSubtle = Color(hex: "#fef3c7")
    }

    // Dark theme
    struct Dark {
        static let bgPrimary = Color(hex: "#191919")
        static let bgSecondary = Color(hex: "#202020")
        static let bgSurface = Color(hex: "#262626")
        static let bgHover = Color(hex: "#2c2c2c")
        static let bgActive = Color(hex: "#262626")
        static let bgCard = Color(hex: "#191919")
        static let bgHeader = Color(hex: "#202020")
        static let bgInput = Color(hex: "#262626")
        static let bgIcon = Color(hex: "#2a2a2a")

        static let textPrimary = Color(hex: "#d4d4d4")
        static let textSecondary = Color(hex: "#a3a3a3")
        static let textTertiary = Color(hex: "#737373")
        static let textInverse = Color(hex: "#191919")
        static let textLink = Color(hex: "#38bdf8")

        static let borderSubtle = Color(hex: "#2c2c2c")
        static let borderDefault = Color(hex: "#404040")
        static let borderStrong = Color(hex: "#525252")
        static let borderFocus = Color(hex: "#38bdf8")

        static let success = Color(hex: "#4ade80")
        static let successSubtle = Color(hex: "#4ade80").opacity(0.15)
        static let error = Color(hex: "#f87171")
        static let errorSubtle = Color(hex: "#f87171").opacity(0.15)
        static let warning = Color(hex: "#fbbf24")
        static let warningSubtle = Color(hex: "#fbbf24").opacity(0.15)
    }
}

// MARK: - Adaptive Theme Environment

struct AppTheme {
    let colorScheme: ColorScheme

    var bgPrimary: Color { colorScheme == .dark ? AppColors.Dark.bgPrimary : AppColors.Light.bgPrimary }
    var bgSecondary: Color { colorScheme == .dark ? AppColors.Dark.bgSecondary : AppColors.Light.bgSecondary }
    var bgSurface: Color { colorScheme == .dark ? AppColors.Dark.bgSurface : AppColors.Light.bgSurface }
    var bgHover: Color { colorScheme == .dark ? AppColors.Dark.bgHover : AppColors.Light.bgHover }
    var bgActive: Color { colorScheme == .dark ? AppColors.Dark.bgActive : AppColors.Light.bgActive }
    var bgCard: Color { colorScheme == .dark ? AppColors.Dark.bgCard : AppColors.Light.bgCard }
    var bgHeader: Color { colorScheme == .dark ? AppColors.Dark.bgHeader : AppColors.Light.bgHeader }
    var bgInput: Color { colorScheme == .dark ? AppColors.Dark.bgInput : AppColors.Light.bgInput }
    var bgIcon: Color { colorScheme == .dark ? AppColors.Dark.bgIcon : AppColors.Light.bgIcon }

    var textPrimary: Color { colorScheme == .dark ? AppColors.Dark.textPrimary : AppColors.Light.textPrimary }
    var textSecondary: Color { colorScheme == .dark ? AppColors.Dark.textSecondary : AppColors.Light.textSecondary }
    var textTertiary: Color { colorScheme == .dark ? AppColors.Dark.textTertiary : AppColors.Light.textTertiary }
    var textInverse: Color { colorScheme == .dark ? AppColors.Dark.textInverse : AppColors.Light.textInverse }
    var textLink: Color { colorScheme == .dark ? AppColors.Dark.textLink : AppColors.Light.textLink }

    var borderSubtle: Color { colorScheme == .dark ? AppColors.Dark.borderSubtle : AppColors.Light.borderSubtle }
    var borderDefault: Color { colorScheme == .dark ? AppColors.Dark.borderDefault : AppColors.Light.borderDefault }
    var borderStrong: Color { colorScheme == .dark ? AppColors.Dark.borderStrong : AppColors.Light.borderStrong }
    var borderFocus: Color { colorScheme == .dark ? AppColors.Dark.borderFocus : AppColors.Light.borderFocus }

    var success: Color { colorScheme == .dark ? AppColors.Dark.success : AppColors.Light.success }
    var successSubtle: Color { colorScheme == .dark ? AppColors.Dark.successSubtle : AppColors.Light.successSubtle }
    var error: Color { colorScheme == .dark ? AppColors.Dark.error : AppColors.Light.error }
    var errorSubtle: Color { colorScheme == .dark ? AppColors.Dark.errorSubtle : AppColors.Light.errorSubtle }
    var warning: Color { colorScheme == .dark ? AppColors.Dark.warning : AppColors.Light.warning }
    var warningSubtle: Color { colorScheme == .dark ? AppColors.Dark.warningSubtle : AppColors.Light.warningSubtle }
}

// MARK: - Environment Key

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme(colorScheme: .light)
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography

struct AppTypography {
    static let titleLarge = Font.system(size: 28, weight: .semibold, design: .default)
    static let titleMedium = Font.system(size: 22, weight: .semibold, design: .default)
    static let titleSmall = Font.system(size: 18, weight: .semibold, design: .default)
    static let headline = Font.system(size: 16, weight: .semibold, design: .default)
    static let body = Font.system(size: 15, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 15, weight: .medium, design: .default)
    static let caption = Font.system(size: 13, weight: .regular, design: .default)
    static let captionMedium = Font.system(size: 13, weight: .medium, design: .default)
    static let small = Font.system(size: 12, weight: .regular, design: .default)
    static let smallMedium = Font.system(size: 12, weight: .medium, design: .default)
    static let mono = Font.system(size: 13, weight: .regular, design: .monospaced)
}

// MARK: - Spacing

struct AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

struct AppRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
}
