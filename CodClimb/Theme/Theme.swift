import SwiftUI

enum Theme {
    enum Palette {
        static let background = Color(red: 0.98, green: 0.98, blue: 0.96)
        static let surface = Color.white
        static let surfaceElevated = Color(red: 0.96, green: 0.96, blue: 0.94)
        static let textPrimary = Color(red: 0.10, green: 0.11, blue: 0.10)
        static let textSecondary = Color(red: 0.42, green: 0.44, blue: 0.42)
        static let textTertiary = Color(red: 0.62, green: 0.64, blue: 0.62)
        static let divider = Color(red: 0.90, green: 0.90, blue: 0.88)

        static let accent = Color(red: 0.478, green: 0.608, blue: 0.463)
        static let accentMuted = Color(red: 0.478, green: 0.608, blue: 0.463).opacity(0.12)

        static let send = Color(red: 0.42, green: 0.62, blue: 0.42)
        static let good = Color(red: 0.55, green: 0.66, blue: 0.40)
        static let marginal = Color(red: 0.85, green: 0.65, blue: 0.30)
        static let nogo = Color(red: 0.78, green: 0.38, blue: 0.32)
    }

    enum Typography {
        static let largeTitle = Font.system(size: 32, weight: .semibold, design: .default)
        static let title = Font.system(size: 22, weight: .semibold, design: .default)
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        static let body = Font.system(size: 15, weight: .regular, design: .default)
        static let callout = Font.system(size: 14, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let metric = Font.system(size: 28, weight: .semibold, design: .rounded)
        static let metricLarge = Font.system(size: 44, weight: .semibold, design: .rounded)
    }

    enum Metrics {
        static let cardCornerRadius: CGFloat = 16
        static let cardPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 20
    }
}

extension ClimbScore.Verdict {
    var color: Color {
        switch self {
        case .send: return Theme.Palette.send
        case .good: return Theme.Palette.good
        case .marginal: return Theme.Palette.marginal
        case .nogo: return Theme.Palette.nogo
        }
    }
}
