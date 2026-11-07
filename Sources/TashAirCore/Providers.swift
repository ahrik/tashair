import Foundation

public enum ProviderError: Error, LocalizedError, Sendable {
    case invalidData(String), http(Int), backoff(Date)
    public var errorDescription: String? {
        switch self {
        case .invalidData(let field): "Некорректные данные: \(field)"
        case .http(let status): "HTTP \(status)"
        case .backoff(let date): "Повтор после \(Tashkent.date(date))"
        }
    }
}

public actor HTTPClient {
    private let session: URLSession
    private var retry: [String: Date] = [:]
    private var validators: [URL: (Data, String?, String?)] = [:]
    public init(session: URLSession = .shared) { self.session = session }
    public func data(_ url: URL) async throws -> Data {
        let host = url.host ?? ""
        if let deadline = retry[host], deadline > Date() { throw ProviderError.backoff(deadline) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("TashAir/0.1.1 (non-commercial macOS environmental dashboard)", forHTTPHeaderField: "User-Agent")
        if let old = validators[url] {
            request.setValue(old.1, forHTTPHeaderField: "If-None-Match")
            request.setValue(old.2, forHTTPHeaderField: "If-Modified-Since")
        }
        let (data, raw) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let response = raw as? HTTPURLResponse else { throw ProviderError.invalidData("HTTP") }
        if response.statusCode == 429 || response.statusCode == 503 {
            let deadline = Self.retryDate(response.value(forHTTPHeaderField: "Retry-After"), now: Date())
            retry[host] = deadline
            throw ProviderError.backoff(deadline)
        }
        if response.statusCode == 304, let old = validators[url] { return old.0 }
        guard response.statusCode == 200 else { throw ProviderError.http(response.statusCode) }
        if validators.count > 12 { validators.removeAll() }
        validators[url] = (data, response.value(forHTTPHeaderField: "ETag"), response.value(forHTTPHeaderField: "Last-Modified"))
        return data
    }
    public static func retryDate(_ value: String?, now: Date) -> Date {
        if let value, let seconds = Double(value), seconds.isFinite, seconds >= 0 { return now.addingTimeInterval(max(1, seconds)) }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .gmt
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return value.flatMap(f.date).map { max(now.addingTimeInterval(1), $0) } ?? now.addingTimeInterval(900)
    }
}

public enum Providers {
    public static func url(_ feed: Feed) -> URL {
        if feed == .space { return URL(string: "https://services.swpc.noaa.gov/products/noaa-planetary-k-index-forecast.json")! }
        if feed == .flares { return URL(string: "https://services.swpc.noaa.gov/json/goes/primary/xray-flares-7-day.json")! }
        var parts = URLComponents(string: feed == .air ? "https://air-quality-api.open-meteo.com/v1/air-quality" : "https://api.open-meteo.com/v1/forecast")!
        var query: [String: String] = ["latitude": "41.3111", "longitude": "69.2797", "timezone": "Asia/Tashkent", "timeformat": "unixtime"]
        switch feed {
        case .weather:
            query["current"] = "temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,pressure_msl,wind_speed_10m,wind_direction_10m,wind_gusts_10m,precipitation,cloud_cover"
            query["hourly"] = "temperature_2m,precipitation_probability,uv_index,shortwave_radiation,visibility"
            query["daily"] = "temperature_2m_max,temperature_2m_min,temperature_2m_mean,precipitation_sum,weather_code,sunrise,sunset,daylight_duration,uv_index_max"
            query["forecast_days"] = "16"; query["wind_speed_unit"] = "ms"
        case .history:
            query["daily"] = "temperature_2m_max,temperature_2m_min,temperature_2m_mean,precipitation_sum,weather_code"
            query["past_days"] = "30"; query["forecast_days"] = "0"
        case .air:
            query["current"] = "us_aqi,pm2_5,pm10,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone,dust"
            query["hourly"] = "us_aqi,pm2_5,pm10,dust"
            query["past_days"] = "1"; query["forecast_days"] = "5"; query["domains"] = "cams_global"
        default: break
        }
        parts.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return parts.url!
    }

    private struct Meteo: Decodable {
        var current: [String: Double?]?
        var hourly: [String: [Double?]]?
        var daily: [String: [Double?]]?
    }
    private static func series(_ data: Data, section: String) throws -> [[String: Double]] {
        let dto = try JSONDecoder().decode(Meteo.self, from: data)
        let values = section == "daily" ? dto.daily : dto.hourly
        guard let values, let times = values["time"], !times.isEmpty,
              values.values.allSatisfy({ $0.count == times.count }) else { throw ProviderError.invalidData(section) }
        return try times.indices.map { index in
            guard let time = times[index], time.isFinite else { throw ProviderError.invalidData("time") }
            var row = ["time": time]
            for (key, array) in values { if let value = array[index], value.isFinite { row[key] = value } }
            return row
        }
    }
    private static func current(_ data: Data) throws -> [String: Double] {
        let dto = try JSONDecoder().decode(Meteo.self, from: data)
        guard let current = dto.current, let time = current["time"] ?? nil, time.isFinite else { throw ProviderError.invalidData("current.time") }
        return current.compactMapValues { $0.flatMap { $0.isFinite ? $0 : nil } }
    }
    public static func weather(_ data: Data) throws -> WeatherData {
        let c = try current(data)
        let hours = try series(data, section: "hourly").map { r in
            Hour(time: Date(timeIntervalSince1970: r["time"]!), temperature: r["temperature_2m"], precipitationProbability: r["precipitation_probability"], uv: r["uv_index"], radiation: r["shortwave_radiation"], visibility: r["visibility"])
        }
        return WeatherData(time: Date(timeIntervalSince1970: c["time"]!), temperature: c["temperature_2m"], apparent: c["apparent_temperature"], humidity: c["relative_humidity_2m"], pressure: c["pressure_msl"], wind: c["wind_speed_10m"], direction: c["wind_direction_10m"], gusts: c["wind_gusts_10m"], precipitation: c["precipitation"], clouds: c["cloud_cover"], code: c["weather_code"], hours: hours, days: try days(data))
    }
    public static func days(_ data: Data) throws -> [Day] {
        try series(data, section: "daily").map { r in
            Day(time: Date(timeIntervalSince1970: r["time"]!), minimum: r["temperature_2m_min"], maximum: r["temperature_2m_max"], mean: r["temperature_2m_mean"], precipitation: r["precipitation_sum"], code: r["weather_code"], sunrise: r["sunrise"].map(Date.init(timeIntervalSince1970:)), sunset: r["sunset"].map(Date.init(timeIntervalSince1970:)), daylight: r["daylight_duration"], uv: r["uv_index_max"])
        }.sorted { $0.time < $1.time }
    }
    public static func air(_ data: Data) throws -> AirData {
        let c = try current(data)
        let hours = try series(data, section: "hourly").map { r in
            Hour(time: Date(timeIntervalSince1970: r["time"]!), aqi: r["us_aqi"], pm25: r["pm2_5"], pm10: r["pm10"], dust: r["dust"])
        }
        return AirData(time: Date(timeIntervalSince1970: c["time"]!), aqi: c["us_aqi"], pm25: c["pm2_5"], pm10: c["pm10"], dust: c["dust"], co: c["carbon_monoxide"], no2: c["nitrogen_dioxide"], so2: c["sulphur_dioxide"], ozone: c["ozone"], hours: hours)
    }
    public static func noaaDate(_ text: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let value = iso.date(from: text) { return value }
        iso.formatOptions = [.withInternetDateTime]
        if let value = iso.date(from: text) { return value }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .gmt
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm:ss.SSS"] {
            f.dateFormat = format
            if let value = f.date(from: text) { return value }
        }
        return nil
    }
    public static func kp(_ data: Data) throws -> [KpPoint] {
        let raw = try JSONSerialization.jsonObject(with: data)
        var rows: [[String: Any]]
        if let dictionaries = raw as? [[String: Any]] { rows = dictionaries }
        else if let table = raw as? [[Any]], let header = table.first as? [String] {
            rows = table.dropFirst().filter { $0.count == header.count }.map { Dictionary(uniqueKeysWithValues: zip(header, $0)) }
        } else { throw ProviderError.invalidData("Kp") }
        let points = rows.compactMap { row -> KpPoint? in
            guard let text = row["time_tag"] as? String, let time = noaaDate(text),
                  let value = number(row["kp"] ?? row["Kp"]), (0...9).contains(value),
                  let state = row["observed"] as? String, let kind = ObservationKind(rawValue: state) else { return nil }
            return KpPoint(time: time, value: value, kind: kind, scale: row["noaa_scale"] as? String)
        }
        guard !points.isEmpty else { throw ProviderError.invalidData("Kp rows") }
        return points.sorted { $0.time < $1.time }
    }
    private static func number(_ raw: Any?) -> Double? {
        if let value = raw as? Double, value.isFinite { return value }
        if let value = raw as? String, let number = Double(value), number.isFinite { return number }
        return nil
    }
    public static func flares(_ data: Data) throws -> [SolarFlare] {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { throw ProviderError.invalidData("flares") }
        let result = rows.compactMap { row -> SolarFlare? in
            guard let text = (row["max_time"] ?? row["time_tag"] ?? row["begin_time"]) as? String, let time = noaaDate(text),
                  let classification = (row["max_class"] ?? row["current_class"]) as? String else { return nil }
            return SolarFlare(time: time, classification: classification)
        }
        guard rows.isEmpty || !result.isEmpty else { throw ProviderError.invalidData("flare rows") }
        return result.sorted { $0.time > $1.time }
    }
}
