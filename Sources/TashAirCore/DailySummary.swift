import Foundation

/// Current conditions only. Missing or stale values are explicitly unavailable, never zero.
public enum DailySummary {
    public static func body(snapshot: EnvironmentSnapshot, failed: Set<Feed> = [], at now: Date, language: Language) -> String? {
        func valid(_ value: Double?, nonnegative: Bool = false) -> Double? {
            value.flatMap { $0.isFinite && (!nonnegative || $0 >= 0) ? $0 : nil }
        }
        let weatherFresh = !failed.contains(.weather) && snapshot.isFresh(.weather, at: now)
        let airFresh = !failed.contains(.air) && snapshot.isFresh(.air, at: now)
        let temperature = weatherFresh ? valid(snapshot.weather?.temperature) : nil
        let precipitation = weatherFresh ? valid(snapshot.weather?.precipitation, nonnegative: true) : nil
        let aqi = airFresh ? valid(snapshot.air?.aqi, nonnegative: true) : nil
        guard temperature != nil || precipitation != nil || aqi != nil else { return nil }
        let missing = language.text("Нет данных")
        let temperatureText = temperature.map { Metric.temperature.formatted($0) + " °C" } ?? missing
        let rainText = precipitation.map { String(format: "%.1f", $0) + " " + language.text("мм") } ?? missing
        let airText = aqi.map { Metric.aqi.formatted($0) + " US AQI · " + language.text(AirQuality.title($0)) } ?? missing
        return [
            language.text("Температура") + ": " + temperatureText,
            language.text("Осадки сейчас") + ": " + rainText,
            language.text("Качество воздуха") + ": " + airText,
            language.text("Модельная оценка") + " · " + Tashkent.date(now)
        ].joined(separator: "\n")
    }
}
