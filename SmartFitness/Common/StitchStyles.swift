import SwiftUI

// MARK: - Stitch Theme (Kinetic Noir)
enum StitchTheme {
    static let background = Color(hex: "0e0e0e")
    static let surfaceContainer = Color(hex: "1a1a1a")
    static let surfaceContainerLow = Color(hex: "131313")
    static let surfaceContainerHigh = Color(hex: "20201f")
    static let surfaceContainerLowest = Color(hex: "000000")
    static let surfaceBright = Color(hex: "2c2c2c")
    static let surfaceContainerHighest = Color(hex: "262626")
    
    static let primary = Color(hex: "f3ffca")
    static let primaryContainer = Color(hex: "cafd00")
    static let onPrimaryFixed = Color(hex: "3a4a00")
    static let primaryDim = Color(hex: "beee00")
    
    static let secondary = Color(hex: "ff7441")
    static let secondaryContainer = Color(hex: "ab3600")
    
    static let tertiary = Color(hex: "81ecff")
    
    static let onSurfaceVariant = Color(hex: "adaaaa")
    static let onSurface = Color(hex: "ffffff")
    static let outline = Color(hex: "767575")
    static let outlineVariant = Color(hex: "484847")
}

enum StitchTypography {
    static let headline = Font.system(size: 32, weight: .black, design: .rounded)
    static let headlineLarge = Font.system(size: 48, weight: .black, design: .rounded)
    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let label = Font.system(size: 10, weight: .bold, design: .monospaced)
    static let labelSmall = Font.system(size: 8, weight: .bold, design: .monospaced)
    static let bodyBold = Font.system(size: 16, weight: .bold, design: .default)
    static let dataLarge = Font.system(size: 36, weight: .bold, design: .rounded)
    static let dataMedium = Font.system(size: 24, weight: .bold, design: .rounded)
    static let displayLarge = Font.system(size: 56, weight: .black, design: .rounded)
}
