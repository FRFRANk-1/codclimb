import SwiftUI

struct ScoreBadgeView: View {
    let score: ClimbScore?
    let isLoading: Bool
    var size: Size = .medium

    enum Size {
        case small, medium, large
        var diameter: CGFloat {
            switch self {
            case .small: return 44
            case .medium: return 64
            case .large: return 96
            }
        }
        var font: Font {
            switch self {
            case .small: return Theme.Typography.headline
            case .medium: return Theme.Typography.metric
            case .large: return Theme.Typography.metricLarge
            }
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Palette.divider, lineWidth: 4)
            if let score {
                Circle()
                    .trim(from: 0, to: CGFloat(score.value) / 100)
                    .stroke(score.verdict.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(score.value)")
                    .font(size.font)
                    .foregroundStyle(Theme.Palette.textPrimary)
            } else if isLoading {
                ProgressView()
            } else {
                Text("—")
                    .font(size.font)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .frame(width: size.diameter, height: size.diameter)
    }
}
