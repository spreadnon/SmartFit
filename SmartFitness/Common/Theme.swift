import SwiftUI

struct Theme {
    static let primary = Color(hex: "2563EB")
    static let secondary = Color(hex: "F59E0B")
    static let background = Color.black
    static let surface = Color(white: 0.1)
    static let textPrimary = Color.white
    static let textSecondary = Color.gray
    
    struct Typography {
        static let title1 = Font.system(size: 28, weight: .bold)
        static let title2 = Font.system(size: 22, weight: .bold)
        static let h3 = Font.system(size: 18, weight: .semibold)
        static let body = Font.system(size: 16)
        static let label = Font.system(size: 14, weight: .medium)
        static let caption = Font.system(size: 12)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.body)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundColor(isDestructive ? .red : Theme.primary)
            .background((isDestructive ? Color.red : Theme.primary).opacity(0.1))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(), value: configuration.isPressed)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
