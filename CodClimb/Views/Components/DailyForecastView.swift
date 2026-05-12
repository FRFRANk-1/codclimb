import SwiftUI

struct DailyForecastView: View {
    let days: [DailySummary]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                DayRow(day: day)
                if index < days.count - 1 {
                    Divider()
                        .background(Theme.Palette.divider)
                        .padding(.horizontal, Theme.Metrics.cardPadding)
                }
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .fill(Theme.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .stroke(Theme.Palette.divider, lineWidth: 1)
        )
    }
}

// MARK: - Single day row

private struct DayRow: View {
    let day: DailySummary

    private var dayLabel: String {
        if day.isToday    { return "Today" }
        if day.isTomorrow { return "Tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: day.date)
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: day.date)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Day label
            VStack(alignment: .leading, spacing: 2) {
                Text(dayLabel)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(day.isToday ? Theme.Palette.accent : Theme.Palette.textPrimary)
                Text(dateLabel)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            .frame(width: 72, alignment: .leading)

            // Weather icon
            Image(systemName: day.sfSymbolName)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 28)

            // Temp range
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(day.highF.rounded()))° / \(Int(day.lowF.rounded()))°")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textPrimary)
                if day.totalPrecipIn >= 0.01 {
                    Text(String(format: "%.2f\" precip", day.totalPrecipIn))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }

            Spacer()

            // Score bar + number
            HStack(spacing: 8) {
                ScoreBar(value: day.score.value)
                Text("\(day.score.value)")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(day.score.verdict.color)
                    .frame(width: 30, alignment: .trailing)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, Theme.Metrics.cardPadding)
        .padding(.vertical, 12)
    }

    private var iconColor: Color {
        switch day.representativeCode {
        case 0:      return .yellow
        case 1, 2:   return .orange.opacity(0.8)
        case 61...82: return Color(red: 0.4, green: 0.6, blue: 0.9)
        case 71...77: return .cyan
        default:     return Theme.Palette.textTertiary
        }
    }
}

// MARK: - Inline score bar

private struct ScoreBar: View {
    let value: Int   // 0–100

    private var fraction: CGFloat { CGFloat(max(0, min(100, value))) / 100 }

    private var color: Color {
        switch value {
        case 80...: return Theme.Palette.send
        case 60..<80: return Theme.Palette.good
        case 40..<60: return Theme.Palette.marginal
        default:     return Theme.Palette.nogo
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.divider)
                Capsule().fill(color)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(width: 60, height: 6)
    }
}
