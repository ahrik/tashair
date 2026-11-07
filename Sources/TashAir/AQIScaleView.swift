import SwiftUI
import TashAirCore

struct AQIScaleView: View {
    let aqi: Double?
    let language: Language
    var body: some View {
        HStack(spacing: 5) {
            ForEach(AirQualityLevel.allCases) { level in
                AQIScaleSegment(level: level, selected: AirQuality.level(aqi) == level, language: language)
            }
        }.accessibilityLabel(language.text("Шкала US AQI"))
    }
}

private struct AQIScaleSegment: View {
    let level: AirQualityLevel
    let selected: Bool
    let language: Language
    private var hint: String { "\(language.text(level.title)) · \(level.rangeLabel) US AQI" }
    private var accessibilityText: String {
        let description = "\(language.text(level.title)), \(level.rangeLabel) US AQI"
        return selected ? description + ", " + language.text("Сейчас") : description
    }
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 7)).opacity(selected ? 1 : 0)
            RoundedRectangle(cornerRadius: 3).fill(level.color).frame(height: 6)
            Text(level.rangeLabel).font(.system(size: 10)).monospacedDigit().foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .help(hint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}
