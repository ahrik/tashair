import Foundation
import Testing
@testable import TashAirCore

private let now = Date(timeIntervalSince1970: 1_794_052_800)
private func json(_ object: Any) throws -> Data { try JSONSerialization.data(withJSONObject: object) }
private func airData(aqi: Double = 125, at time: Date = now) throws -> Data {
    try json(["current": ["time": time.timeIntervalSince1970, "us_aqi": aqi, "pm2_5": 26.5], "hourly": ["time": [time.timeIntervalSince1970, time.addingTimeInterval(3600).timeIntervalSince1970], "us_aqi": [aqi, NSNull()] as [Any], "pm2_5": [26.5, NSNull()] as [Any]]])
}
private func weatherData(at time: Date = now) throws -> Data {
    try json(["current": ["time": time.timeIntervalSince1970, "temperature_2m": 19.2], "hourly": ["time": [time.timeIntervalSince1970], "uv_index": [6.1]], "daily": ["time": [Tashkent.calendar.startOfDay(for: time).timeIntervalSince1970], "temperature_2m_max": [21.0], "temperature_2m_min": [10.0], "precipitation_sum": [0.0]]])
}
private func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("TashAirTests-\(UUID().uuidString)") }
private func snapshot(aqi: Double = 125) throws -> EnvironmentSnapshot {
    var result = EnvironmentSnapshot()
    result.air = try Providers.air(airData(aqi: aqi)); result.fetched[.air] = now
    return result
}

struct ProviderTests {
    @Test func missingValuesRemainMissing() throws {
        let result = try Providers.air(airData())
        #expect(result.pm25 == 26.5)
        #expect(result.co == nil)
        #expect(result.hours[1].aqi == nil)
    }
    @Test func validatesMismatchedArrays() throws {
        let data = try json(["daily": ["time": [100, 200], "temperature_2m_max": [12]]])
        #expect(throws: (any Error).self) { try Providers.days(data) }
    }
    @Test func missingTimeIsRejected() throws {
        #expect(throws: (any Error).self) { try Providers.air(json(["current": ["us_aqi": 50]])) }
    }
    @Test func parsesWeatherAndZeroRain() throws {
        let weather = try Providers.weather(weatherData())
        #expect(weather.temperature == 19.2)
        #expect(weather.days[0].precipitation == 0)
        #expect(weather.hours[0].uv == 6.1)
        #expect(weather.hours[0].visibility == nil)
    }
    @Test func globalModelURLAndPeriods() {
        func items(_ feed: Feed) -> [String: String] { Dictionary(uniqueKeysWithValues: URLComponents(url: Providers.url(feed), resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value!) }) }
        #expect(items(.air)["domains"] == "cams_global")
        #expect(items(.weather)["forecast_days"] == "16")
        #expect(items(.history)["past_days"] == "30")
        #expect(items(.history)["forecast_days"] == "0")
        #expect(items(.weather)["wind_speed_unit"] == "ms")
        #expect(items(.weather)["timezone"] == "Asia/Tashkent")
    }
    @Test func supportsBothNOAAFormats() throws {
        let object = try json([["time_tag": "2026-11-07T09:00:00", "kp": 3.33, "observed": "observed"], ["time_tag": "2026-11-08T00:00:00Z", "kp": 5.0, "observed": "predicted"]])
        let table = try json([["time_tag", "kp", "observed", "noaa_scale"], ["2026-11-07 09:00:00", "3.33", "observed", NSNull()]] as [[Any]])
        let objects = try Providers.kp(object)
        let rows = try Providers.kp(table)
        #expect(objects.count == 2)
        #expect(rows[0].time == objects[0].time)
        #expect(objects[1].kind == .predicted)
    }
    @Test func unknownNOAAStateRejected() throws {
        let data = try json([["time_tag": "2026-11-07T09:00:00", "kp": 6, "observed": "unexpected"]])
        #expect(throws: (any Error).self) { try Providers.kp(data) }
    }
    @Test func futureKpNeverBecomesCurrent() {
        var snapshot = EnvironmentSnapshot()
        snapshot.space = [.init(time: now.addingTimeInterval(-3600), value: 3, kind: .observed), .init(time: now.addingTimeInterval(10), value: 8, kind: .estimated), .init(time: now, value: 9, kind: .predicted)]
        #expect(snapshot.currentKp(at: now)?.value == 3)
    }
    @Test func parsesFlaresAndEmptyResponses() throws {
        let result = try Providers.flares(json([["max_time": "2026-11-07T11:57:00Z", "max_class": "C6.2"]]))
        #expect(result[0].classification == "C6.2")
        #expect(try Providers.flares(Data("[]".utf8)).isEmpty)
        #expect(throws: (any Error).self) { try Providers.flares(Data("[{\"new_field\":1}]".utf8)) }
    }
    @Test func timestampsUseTashkentCalendar() {
        let date = Providers.noaaDate("2026-11-06T20:30:00Z")!
        #expect(Tashkent.date(date, format: "yyyy-MM-dd HH:mm") == "2026-11-07 01:30")
        #expect(Tashkent.date(Tashkent.calendar.startOfDay(for: date), format: "HH:mm") == "00:00")
    }
    @Test func aqiBoundaryCategories() {
        let boundaries: [(Double, AirQualityLevel)] = [
            (0, .good), (50, .good), (51, .moderate), (64, .moderate), (100, .moderate),
            (101, .sensitive), (150, .sensitive), (151, .unhealthy), (200, .unhealthy),
            (201, .veryUnhealthy), (300, .veryUnhealthy), (301, .hazardous), (500, .hazardous), (501, .hazardous)
        ]
        for (value, level) in boundaries {
            #expect(AirQuality.level(value) == level)
            #expect(AirQuality.band(value) == level.rawValue)
        }
        #expect(AirQuality.level(nil) == nil)
        #expect(AirQuality.level(-1) == nil)
        #expect(AirQuality.level(.nan) == nil)
        #expect(AirQuality.level(.infinity) == nil)
    }
    @Test func malformedWeatherCodeCannotCrashPresentation() {
        #expect(WeatherCode.title(1e100) == "Нет данных")
        #expect(WeatherCode.symbol(.infinity) == "cloud")
        #expect(Metric.uv.formatted(0.3) == "0.3")
    }
    @Test func honorsRetryAfter() {
        #expect(HTTPClient.retryDate("120", now: now) == now.addingTimeInterval(120))
        #expect(HTTPClient.retryDate("invalid", now: now) == now.addingTimeInterval(900))
        #expect(HTTPClient.retryDate("-10", now: now) > now)
        #expect(HTTPClient.retryDate("Sat, 07 Nov 2026 12:05:00 GMT", now: now) > now)
    }
}

struct AlertTests {
    @Test func edgeTriggerSurvivesRestartAndRearms() throws {
        let rules = [AlertRule(id: "aqi", metric: .aqi, threshold: 101, enabled: true)]
        var ledger = AlertLedger()
        #expect(ledger.evaluate(rules: rules, snapshot: try snapshot(), at: now).count == 1)
        var restarted = try JSONDecoder().decode(AlertLedger.self, from: JSONEncoder().encode(ledger))
        #expect(restarted.evaluate(rules: rules, snapshot: try snapshot(), at: now).isEmpty)
        #expect(restarted.evaluate(rules: rules, snapshot: try snapshot(aqi: 90), at: now).isEmpty)
        #expect(restarted.evaluate(rules: rules, snapshot: try snapshot(), at: now).count == 1)
    }
    @Test func staleAndMissingNeverTriggerOrRearm() throws {
        let rules = [AlertRule(id: "aqi", metric: .aqi, threshold: 101, enabled: true)]
        var ledger = AlertLedger()
        let state = try snapshot()
        #expect(ledger.evaluate(rules: rules, snapshot: state, at: now).count == 1)
        #expect(ledger.evaluate(rules: rules, snapshot: try snapshot(aqi: 0), at: now.addingTimeInterval(10000)).isEmpty)
        #expect(ledger.evaluate(rules: rules, snapshot: state, at: now).isEmpty)
        #expect(ledger.evaluate(rules: rules, snapshot: EnvironmentSnapshot(), at: now).isEmpty)
    }
    @Test func fetchDoesNotMakeOldSourceFresh() throws {
        var state = try snapshot()
        state.air = try Providers.air(airData(at: now.addingTimeInterval(-10800)))
        #expect(!state.isFresh(Metric.aqi, at: now))
    }
    @Test func disabledRulesAndDefaultSummary() throws {
        var ledger = AlertLedger()
        #expect(ledger.evaluate(rules: AlertRule.defaults, snapshot: try snapshot(), at: now).isEmpty)
    }
    @Test func lowTemperatureUsesReverseComparison() throws {
        var ledger = AlertLedger()
        var state = EnvironmentSnapshot()
        state.weather = try Providers.weather(weatherData()); state.weather?.temperature = -2; state.fetched[.weather] = now
        let rules = [AlertRule(id: "cold", metric: .temperature, threshold: 0, below: true, enabled: true)]
        #expect(ledger.evaluate(rules: rules, snapshot: state, at: now).count == 1)
    }
    @Test func summaryOnceAcrossScheduledMinute() {
        var ledger = AlertLedger()
        let target = Providers.noaaDate("2026-11-07T03:00:00Z")!
        #expect(ledger.summaryDue(enabled: true, hour: 8, minute: 0, at: target.addingTimeInterval(-20)) == false)
        #expect(ledger.summaryDue(enabled: true, hour: 8, minute: 0, at: target.addingTimeInterval(10)) == true)
        #expect(ledger.summaryDue(enabled: true, hour: 8, minute: 0, at: target.addingTimeInterval(40)) == false)
    }
    @Test func summaryDoesNotReplayAfterSleepOrLaunch() {
        var ledger = AlertLedger()
        let target = Providers.noaaDate("2026-11-07T03:00:00Z")!
        #expect(ledger.summaryDue(enabled: true, hour: 8, minute: 0, at: target.addingTimeInterval(-600)) == false)
        #expect(ledger.summaryDue(enabled: true, hour: 8, minute: 0, at: target.addingTimeInterval(60)) == false)
        ledger.resetSummaryClock()
        #expect(ledger.summaryDue(enabled: true, hour: 8, minute: 0, at: target.addingTimeInterval(10)) == false)
    }
    @Test func changedThresholdStartsNewEpisode() throws {
        var ledger = AlertLedger()
        let initial = AlertRule(id: "aqi", metric: .aqi, threshold: 101, enabled: true)
        #expect(ledger.evaluate(rules: [initial], snapshot: try snapshot(), at: now).count == 1)
        var updated = initial; updated.threshold = 120
        #expect(ledger.evaluate(rules: [updated], snapshot: try snapshot(), at: now).count == 1)
    }
}

private actor RequestCounter {
    var count = 0
    func load() async throws -> Data { count += 1; try await Task.sleep(for: .milliseconds(30)); return try airData() }
}
struct RepositoryTests {
    @Test func deduplicatesAndRespectsTTL() async throws {
        let folder = directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let counter = RequestCounter()
        let repo = EnvironmentRepository(directory: folder) { _ in try await counter.load() }
        async let first = repo.refresh(feeds: [.air], now: now)
        async let second = repo.refresh(feeds: [.air], now: now)
        let (firstState, secondState) = await (first, second)
        #expect(firstState.snapshot.air?.aqi == 125)
        #expect(secondState.snapshot.air?.aqi == 125)
        #expect(await counter.count == 1)
        _ = await repo.refresh(feeds: [.air], now: now.addingTimeInterval(120))
        #expect(await counter.count == 1)
        _ = await repo.refresh(feeds: [.air], now: now.addingTimeInterval(3601))
        #expect(await counter.count == 2)
    }
    @Test func cacheSurvivesOfflineRestart() async throws {
        let folder = directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let online = EnvironmentRepository(directory: folder) { _ in try airData() }
        _ = await online.refresh(feeds: [.air], now: now)
        let offline = EnvironmentRepository(directory: folder) { _ in throw URLError(.notConnectedToInternet) }
        let state = await offline.refresh(force: true, feeds: [.air], now: now.addingTimeInterval(5000))
        #expect(state.snapshot.air?.aqi == 125)
        #expect(state.snapshot.fetched[.air] == now)
        #expect(state.errors[.air] != nil)
    }
    @Test func oneFeedFailureDoesNotBlockOthers() async throws {
        let folder = directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let repo = EnvironmentRepository(directory: folder) { url in
            if url.host?.hasPrefix("air-quality") == true { return try airData() }
            throw URLError(.badServerResponse)
        }
        let state = await repo.refresh(feeds: [.air, .space], now: now)
        #expect(state.snapshot.air?.aqi == 125)
        #expect(state.errors[.space] != nil)
        #expect(state.snapshot.fetched[.space] == nil)
    }
    @Test func corruptCacheIsPreservedBeforeReplacement() async throws {
        let folder = directory(); defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: folder.appendingPathComponent("air.json"))
        let repo = EnvironmentRepository(directory: folder) { _ in try airData() }
        let state = await repo.refresh(feeds: [.air], now: now)
        #expect(state.snapshot.air?.aqi == 125)
        let backup = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).first { $0.lastPathComponent.contains("damaged-") }
        #expect(backup != nil)
        #expect(try backup.map { try String(contentsOf: $0, encoding: .utf8) } == "broken")
    }
    @Test func malformedRefreshDoesNotReplaceGoodCache() async throws {
        let folder = directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let online = EnvironmentRepository(directory: folder) { _ in try airData() }
        _ = await online.refresh(feeds: [.air], now: now)
        let bad = EnvironmentRepository(directory: folder) { _ in Data("{}".utf8) }
        let state = await bad.refresh(force: true, feeds: [.air], now: now.addingTimeInterval(5000))
        #expect(state.snapshot.air?.aqi == 125)
        #expect(state.snapshot.fetched[.air] == now)
        #expect(state.errors[.air] != nil)
    }
}
