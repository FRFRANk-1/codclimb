import SwiftUI

struct HourlyForecastView: View {
    let hours: [WeatherSnapshot]

    private var formatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "ha"
        f.amSymbol = "a"
        f.pmSymbol = "p"
        return f
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(hours.prefix(24).enumerated()), id: \.offset) { _, hour in
                    VStack(spacing: 8) {
                        Text(formatter.string(from: hour.time).lowercased())
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textTertiary)
                        Image(systemName: hour.sfSymbolName)
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .frame(height: 22)
                        Text("\(Int(hour.temperatureF.rounded()))°")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        if hour.precipitationIn >= 0.01 {
                            Text(String(format: "%.2f\"", hour.precipitationIn))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Theme.Palette.accent)
                        } else {
                            Text(" ")
                                .font(.system(size: 10))
                        }
                    }
                    .frame(width: 52)
                }
            }
            .padding(.horizontal, Theme.Metrics.cardPadding)
        }
    }
}
