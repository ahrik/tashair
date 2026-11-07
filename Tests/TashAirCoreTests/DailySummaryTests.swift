import Foundation
import Testing
@testable import TashAirCore

struct DailySummaryTests {
    let now = Providers.noaaDate("2026-11-07T03:00:00Z")!
    func snapshot() -> EnvironmentSnapshot {
        var result = EnvironmentSnapshot()
        result.weather = WeatherData(time: now, temperature: -2, precipitation: 0, hours: [], days: [])
        result.air = AirData(time: now, aqi: 64, hours: [])
        result.fetched = [.air: now, .weather: now]
        return result
    }
    @Test func currentSummaryContainsRequestedFieldsAndTashkentTime() {
        let body = DailySummary.body(snapshot: snapshot(), at: now, language: .ru)!
        #expect(body.contains("Температура: -2.0 °C"))
        #expect(body.contains("Осадки сейчас: 0.0 мм"))
        #expect(body.contains("Качество воздуха: 64 US AQI · Умеренное"))
        #expect(body.contains("07.11 08:00"))
        #expect(!body.contains("Kp"))
    }
    @Test func rainAndUzbekCopy() {
        var state = snapshot(); state.weather?.precipitation = 2.4
        let body = DailySummary.body(snapshot: state, at: now, language: .uz)!
        #expect(body.contains("Harorat: -2.0 °C"))
        #expect(body.contains("Hozirgi yog‘in: 2.4 mm"))
        #expect(body.contains("Havo sifati: 64 US AQI · O‘rtacha"))
    }
    @Test func failuresAndStaleFeedsAreIndependent() {
        let body = DailySummary.body(snapshot: snapshot(), failed: [.weather], at: now, language: .ru)!
        #expect(body.contains("Температура: Нет данных"))
        #expect(body.contains("Осадки сейчас: Нет данных"))
        #expect(body.contains("64 US AQI"))
        var state = snapshot(); state.air?.time = now.addingTimeInterval(-7200)
        let stale = DailySummary.body(snapshot: state, at: now, language: .ru)!
        #expect(stale.contains("Качество воздуха: Нет данных"))
        #expect(stale.contains("Осадки сейчас: 0.0 мм"))
        #expect(DailySummary.body(snapshot: snapshot(), failed: [.air, .weather], at: now, language: .ru) == nil)
        #expect(DailySummary.body(snapshot: snapshot(), at: now.addingTimeInterval(7200), language: .ru) == nil)
    }
    @Test func missingInvalidAndForecastValuesAreNeverPresentedAsCurrent() {
        var state = snapshot(); state.weather?.temperature = .nan; state.weather?.precipitation = nil
        state.weather?.hours = [.init(time: now.addingTimeInterval(3600), temperature: 30)]
        state.air?.aqi = .infinity
        #expect(DailySummary.body(snapshot: state, at: now, language: .ru) == nil)
        state.weather?.temperature = 10; state.weather?.precipitation = -1; state.air?.aqi = -1
        let body = DailySummary.body(snapshot: state, at: now, language: .ru)!
        #expect(body.contains("Осадки сейчас: Нет данных"))
        #expect(body.contains("Качество воздуха: Нет данных"))
    }
    @Test func customTimePersistsOncePerDayAcrossRestart() throws {
        var ledger = AlertLedger()
        let target = Providers.noaaDate("2026-11-07T04:45:00Z")!
        #expect(ledger.summaryDue(enabled: true, hour: 9, minute: 45, at: target.addingTimeInterval(-20)) == false)
        #expect(ledger.summaryDue(enabled: true, hour: 9, minute: 45, at: target) == true)
        var restored = try JSONDecoder().decode(AlertLedger.self, from: JSONEncoder().encode(ledger))
        restored.resetSummaryClock()
        #expect(restored.summaryDue(enabled: true, hour: 9, minute: 45, at: target.addingTimeInterval(-10)) == false)
        #expect(restored.summaryDue(enabled: true, hour: 9, minute: 45, at: target.addingTimeInterval(10)) == false)
        let tomorrow = target.addingTimeInterval(86400)
        #expect(restored.summaryDue(enabled: true, hour: 9, minute: 45, at: tomorrow.addingTimeInterval(-20)) == false)
        #expect(restored.summaryDue(enabled: true, hour: 9, minute: 45, at: tomorrow) == true)
    }
}
