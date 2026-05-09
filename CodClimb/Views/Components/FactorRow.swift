import SwiftUI

struct FactorRow: View {
    let factor: ClimbScore.Factor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(factor.name)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Text("\(Int((factor.score * 100).rounded()))")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(barColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.divider)
                    Capsule().fill(barColor)
                        .frame(width: geo.size.width * factor.score)
                }
            }
            .frame(height: 6)
            Text(factor.detail)
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(.vertical, 8)
    }

    private var barColor: Color {
        switch factor.score {
        case 0.75...: return Theme.Palette.send
        case 0.5..<0.75: return Theme.Palette.good
        case 0.25..<0.5: return Theme.Palette.marginal
        default: return Theme.Palette.nogo
        }
    }
}
