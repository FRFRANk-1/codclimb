import SwiftUI

struct FactorRow: View {
    let factor: ClimbScore.Factor
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // ── Header row ──────────────────────────────────────────────────
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text(factor.name)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Palette.textTertiary)
                    Spacer()
                    Text("\(Int((factor.score * 100).rounded()))")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(barColor)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            .buttonStyle(.plain)

            // ── Score bar ───────────────────────────────────────────────────
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.divider)
                    Capsule().fill(barColor)
                        .frame(width: geo.size.width * factor.score)
                        .animation(.easeOut(duration: 0.4), value: factor.score)
                }
            }
            .frame(height: 6)

            // ── Detail line ─────────────────────────────────────────────────
            Text(factor.detail)
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Palette.textSecondary)

            // ── Expanded explanation ─────────────────────────────────────────
            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()

                    Text(howItScores)
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)

                    // Weight + contribution breakdown
                    HStack(spacing: 0) {
                        ContribCell(label: "Weight",
                                    value: "\(Int((factor.weight * 100).rounded()))%",
                                    sub: "of total score")
                        Divider().frame(height: 36)
                        ContribCell(label: "Factor score",
                                    value: "\(Int((factor.score * 100).rounded()))/100",
                                    sub: scoreLabel)
                        Divider().frame(height: 36)
                        ContribCell(label: "Contribution",
                                    value: "+\(Int((factor.score * factor.weight * 100).rounded())) pts",
                                    sub: "to your total")
                    }
                    .background(Theme.Palette.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.Palette.divider, lineWidth: 1))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Per-factor plain-English explanation

    private var howItScores: String {
        switch factor.name {
        case "Temperature":
            return "Sweet spot is 55–68°F (13–20°C) — the zone where friction is sharpest and fingers stay comfortable. Scores fall off below 45°F (gloves between burns) and above 78°F (rubber softens). Adjust your cloud preference in Settings → Scoring if you run cold."
        case "Dryness":
            return "Wet rock = zero score. The clock starts after the last drop of rain and rises linearly to 100% once 24 hours have passed. Sandstone and pocketed limestone dry slower — mentally subtract a few points for those rock types."
        case "Humidity":
            return "Below 50% RH is crisp and chalky-dry. Above 70% your hands feel sticky and chalk stops absorbing sweat. Above 90% it's soup — rubber slides, holds feel polished, and that project won't go."
        case "Wind":
            return "5–15 mph is the sweet spot: keeps you cool, helps the rock dry, and doesn't rattle your gear. Dead calm can feel muggy. Above 25 mph is fatiguing on exposed faces and dangerous on alpine routes."
        case "Cloud cover":
            return "Scored to your sky preference (Settings → Scoring). ☀ Sun: clear sky is rewarded. ☁ Shade: overcast is rewarded — great for shaded granite or hot summer walls. Either: mild penalty for heavy overcast regardless of temp."
        default:
            return "Contributes to the overall climbability score based on ideal conditions for rock climbing."
        }
    }

    private var scoreLabel: String {
        switch factor.score {
        case 0.85...: return "excellent"
        case 0.65..<0.85: return "good"
        case 0.45..<0.65: return "marginal"
        default: return "poor"
        }
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

// Small 3-column stat inside the expanded disclosure
private struct ContribCell: View {
    let label: String
    let value: String
    let sub: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.Palette.textTertiary)
                .tracking(0.4)
            Text(value)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
                .monospacedDigit()
            Text(sub)
                .font(.system(size: 10))
                .foregroundStyle(Theme.Palette.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}
