import Foundation

public enum Tashkent {
    public static let latitude = 41.3111
    public static let longitude = 69.2797
    public static let timeZone = TimeZone(identifier: "Asia/Tashkent")!
    public static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = timeZone
        return value
    }
    public static func date(_ date: Date, format: String = "dd.MM HH:mm") -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

public enum Metric: String, CaseIterable, Codable, Sendable, Identifiable {
    case aqi, pm25, temperature, uv, kp
    public var id: String { rawValue }
    public var unit: String {
        switch self { case .aqi: "US AQI"; case .pm25: "µg/m³"; case .temperature: "°C"; case .uv: "UV"; case .kp: "Kp" }
    }
    public var title: String {
        switch self { case .aqi: "Качество воздуха"; case .pm25: "PM2.5"; case .temperature: "Температура"; case .uv: "УФ-индекс"; case .kp: "Геомагнитная активность" }
    }
    public var symbol: String {
        switch self { case .aqi, .pm25: "aqi.medium"; case .temperature: "thermometer.medium"; case .uv: "sun.max"; case .kp: "waveform.path" }
    }
    public var section: String {
        switch self { case .aqi, .pm25: "air"; case .temperature: "weather"; case .uv: "sun"; case .kp: "space" }
    }
    public var link: URL { URL(string: "tashair://\(section)")! }
    public func formatted(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        return String(format: self == .aqi ? "%.0f" : "%.1f", value)
    }
}

public enum Feed: String, CaseIterable, Codable, Sendable {
    case weather, air, space, flares, history
    public var interval: TimeInterval {
        switch self { case .weather, .space, .flares: 900; case .air: 3600; case .history: 86400 }
    }
    public var source: String {
        switch self { case .weather, .history: "Open-Meteo"; case .air: "Open-Meteo · CAMS Global"; case .space, .flares: "NOAA SWPC" }
    }
}

public struct Hour: Codable, Sendable, Identifiable {
    public var time: Date
    public var temperature: Double?
    public var precipitationProbability: Double?
    public var uv: Double?
    public var radiation: Double?
    public var visibility: Double?
    public var aqi: Double?
    public var pm25: Double?
    public var pm10: Double?
    public var dust: Double?
    public var id: Date { time }
    public init(time: Date, temperature: Double? = nil, precipitationProbability: Double? = nil, uv: Double? = nil, radiation: Double? = nil, visibility: Double? = nil, aqi: Double? = nil, pm25: Double? = nil, pm10: Double? = nil, dust: Double? = nil) {
        self.time = time; self.temperature = temperature; self.precipitationProbability = precipitationProbability
        self.uv = uv; self.radiation = radiation; self.visibility = visibility
        self.aqi = aqi; self.pm25 = pm25; self.pm10 = pm10; self.dust = dust
    }
}

public struct Day: Codable, Sendable, Identifiable {
    public var time: Date
    public var minimum: Double?
    public var maximum: Double?
    public var mean: Double?
    public var precipitation: Double?
    public var code: Double?
    public var sunrise: Date?
    public var sunset: Date?
    public var daylight: Double?
    public var uv: Double?
    public var id: Date { time }
}

public struct WeatherData: Codable, Sendable {
    public var time: Date
    public var temperature: Double?
    public var apparent: Double?
    public var humidity: Double?
    public var pressure: Double?
    public var wind: Double?
    public var direction: Double?
    public var gusts: Double?
    public var precipitation: Double?
    public var clouds: Double?
    public var code: Double?
    public var hours: [Hour]
    public var days: [Day]
}

public struct AirData: Codable, Sendable {
    public var time: Date
    public var aqi: Double?
    public var pm25: Double?
    public var pm10: Double?
    public var dust: Double?
    public var co: Double?
    public var no2: Double?
    public var so2: Double?
    public var ozone: Double?
    public var hours: [Hour]
}

public enum ObservationKind: String, Codable, Sendable { case observed, estimated, predicted }
public struct KpPoint: Codable, Sendable, Identifiable {
    public var time: Date
    public var value: Double
    public var kind: ObservationKind
    public var scale: String?
    public var id: Date { time }
    public init(time: Date, value: Double, kind: ObservationKind, scale: String? = nil) {
        self.time = time; self.value = value; self.kind = kind; self.scale = scale
    }
}
public struct SolarFlare: Codable, Sendable, Identifiable {
    public var time: Date
    public var classification: String
    public var id: String { "\(time.timeIntervalSince1970)-\(classification)" }
}

public struct EnvironmentSnapshot: Codable, Sendable {
    public var weather: WeatherData?
    public var air: AirData?
    public var space: [KpPoint] = []
    public var flares: [SolarFlare] = []
    public var history: [Day] = []
    public var fetched: [Feed: Date] = [:]
    public init() {}

    public func currentKp(at now: Date) -> KpPoint? {
        space.filter { $0.time <= now && $0.kind != .predicted }.max { $0.time < $1.time }
    }
    public func currentHour(at now: Date) -> Hour? {
        weather?.hours.filter { $0.time <= now && now.timeIntervalSince($0.time) < 3600 }.max { $0.time < $1.time }
    }
    public func value(_ metric: Metric, at now: Date) -> Double? {
        switch metric {
        case .aqi: air?.aqi
        case .pm25: air?.pm25
        case .temperature: weather?.temperature
        case .uv: currentHour(at: now)?.uv
        case .kp: currentKp(at: now)?.value
        }
    }
    public func isFresh(_ feed: Feed, at now: Date) -> Bool {
        guard let fetched = fetched[feed], now.timeIntervalSince(fetched) >= -60,
              now.timeIntervalSince(fetched) < feed.interval * 2 else { return false }
        let sourceTime: Date?
        let maxAge: TimeInterval
        switch feed {
        case .weather: sourceTime = weather?.time; maxAge = 7200
        case .air: sourceTime = air?.time; maxAge = 7200
        case .space: sourceTime = currentKp(at: now)?.time; maxAge = 21600
        case .flares, .history: return true
        }
        guard let sourceTime else { return false }
        return now.timeIntervalSince(sourceTime) >= -300 && now.timeIntervalSince(sourceTime) < maxAge
    }
    public func isFresh(_ metric: Metric, at now: Date) -> Bool {
        switch metric {
        case .aqi, .pm25: isFresh(.air, at: now)
        case .temperature: isFresh(.weather, at: now)
        case .uv: isFresh(.weather, at: now) && currentHour(at: now) != nil
        case .kp: isFresh(.space, at: now)
        }
    }
}

public enum AirQualityLevel: Int, CaseIterable, Sendable, Identifiable {
    case good, moderate, sensitive, unhealthy, veryUnhealthy, hazardous
    public var id: Int { rawValue }
    public var title: String {
        switch self {
        case .good: "Хорошее"
        case .moderate: "Умеренное"
        case .sensitive: "Вредно для чувствительных групп"
        case .unhealthy: "Вредное"
        case .veryUnhealthy: "Очень вредное"
        case .hazardous: "Опасное"
        }
    }
    public var rangeLabel: String {
        switch self {
        case .good: "0–50"
        case .moderate: "51–100"
        case .sensitive: "101–150"
        case .unhealthy: "151–200"
        case .veryUnhealthy: "201–300"
        case .hazardous: "301+"
        }
    }
    /// Accessible tones of the six US AQI category colours, shared by the panel and menu bar.
    public var backgroundHex: UInt32 {
        switch self {
        case .good: 0x27823D
        case .moderate: 0xF4D34B
        case .sensitive: 0xE98327
        case .unhealthy: 0xC83C45
        case .veryUnhealthy: 0x8453A3
        case .hazardous: 0x7A243A
        }
    }
    public var foregroundHex: UInt32 {
        switch self { case .moderate, .sensitive: 0x18211D; default: 0xFFFFFF }
    }
}

public enum AirQuality {
    public static func band(_ value: Double) -> Int {
        switch value { case ...50: 0; case ...100: 1; case ...150: 2; case ...200: 3; case ...300: 4; default: 5 }
    }
    public static func title(_ value: Double) -> String {
        level(value)?.title ?? "Нет данных"
    }
    public static func level(_ value: Double?) -> AirQualityLevel? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return AirQualityLevel(rawValue: band(value))
    }
}

public enum WeatherCode {
    public static func title(_ code: Double?) -> String {
        switch code.flatMap({ $0.isFinite && (0...99).contains($0) ? Int($0) : nil }) ?? -1 {
        case 0: "Ясно"
        case 1, 2: "Переменная облачность"
        case 3: "Пасмурно"
        case 45, 48: "Туман"
        case 51...67: "Дождь"
        case 71...77: "Снег"
        case 80...82: "Ливень"
        case 85, 86: "Снегопад"
        case 95...99: "Гроза"
        default: "Нет данных"
        }
    }
    public static func symbol(_ code: Double?) -> String {
        switch code.flatMap({ $0.isFinite && (0...99).contains($0) ? Int($0) : nil }) ?? -1 {
        case 0: "sun.max.fill"
        case 1, 2: "cloud.sun.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51...67, 80...82: "cloud.rain.fill"
        case 71...77, 85, 86: "cloud.snow.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "cloud"
        }
    }
}
