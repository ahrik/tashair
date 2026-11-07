import Foundation
import Testing
@testable import TashAirCore

struct AdviceTests {
    let now = Date(timeIntervalSince1970: 1_794_052_800)
    func state(aqi: Double? = 64) -> EnvironmentSnapshot {
        var value = EnvironmentSnapshot()
        value.air = AirData(time: now, aqi: aqi, hours: [])
        value.weather = WeatherData(time: now, temperature: 20, hours: [], days: [])
        value.fetched = [.air: now, .weather: now]
        return value
    }
    @Test func airBandsAndMasks() {
        let examples: [(Double, Advice, Advice)] = [
            (0, .airGood, .maskRoutine), (50, .airGood, .maskRoutine),
            (51, .airModerate, .maskRoutine), (100, .airModerate, .maskRoutine),
            (101, .airSensitive, .maskSensitive), (150, .airSensitive, .maskSensitive),
            (151, .airUnhealthy, .maskConsider), (200, .airUnhealthy, .maskConsider),
            (201, .airVeryUnhealthy, .maskUse), (300, .airVeryUnhealthy, .maskUse),
            (301, .airHazardous, .maskAvoid)
        ]
        for (aqi, activity, mask) in examples {
            #expect(EnvironmentAdvice.air(state(aqi: aqi), at: now) == [activity, mask])
        }
        for aqi: Double? in [nil, -1, .nan, .infinity] {
            #expect(EnvironmentAdvice.air(state(aqi: aqi), at: now) == [.airUnavailable])
        }
    }
    @Test func staleFailedAndFutureDataDoNotGiveCurrentAdvice() {
        #expect(EnvironmentAdvice.air(state(), at: now, failed: true) == [.airUnavailable])
        #expect(EnvironmentAdvice.weather(state(), at: now, failed: true) == [.weatherUnavailable])
        #expect(EnvironmentAdvice.air(state(), at: now.addingTimeInterval(7200)) == [.airUnavailable])
        #expect(EnvironmentAdvice.weather(state(), at: now.addingTimeInterval(1800)) == [.weatherUnavailable])
        #expect(EnvironmentAdvice.air(state(), at: now.addingTimeInterval(-600)) == [.airUnavailable])
        var old = state(); old.air?.time = now.addingTimeInterval(-7200)
        #expect(EnvironmentAdvice.air(old, at: now) == [.airUnavailable])
    }
    @Test func apparentTemperatureThresholdsAndFallback() {
        for (temperature, expected): (Double, [Advice]) in [(29.9, []), (30, [.heat]), (35, [.extremeHeat]), (0, [.cold]), (-10, [.severeCold])] {
            var value = state(); value.weather?.apparent = temperature
            #expect(EnvironmentAdvice.weather(value, at: now) == expected)
        }
        var value = state(); value.weather?.temperature = 35; value.weather?.apparent = .nan
        #expect(EnvironmentAdvice.weather(value, at: now) == [.extremeHeat])
        value.weather?.temperature = nil
        #expect(EnvironmentAdvice.weather(value, at: now).isEmpty)
    }
    @Test func hazardsCombineAndUseCurrentUVOnly() {
        var value = state(); value.weather?.code = 95; value.weather?.gusts = 15
        value.weather?.apparent = 35
        value.weather?.hours = [.init(time: now, uv: 8)]
        #expect(EnvironmentAdvice.weather(value, at: now) == [.storm, .wind, .extremeHeat, .extremeUV])
        value.weather?.hours = [.init(time: now.addingTimeInterval(3600), uv: 11)]
        #expect(!EnvironmentAdvice.weather(value, at: now).contains(.extremeUV))
        value.weather?.code = 71
        #expect(EnvironmentAdvice.weather(value, at: now).contains(.snow))
        value.weather?.code = 61
        #expect(EnvironmentAdvice.weather(value, at: now).contains(.rain))
    }
    @Test func uvBoundariesAndMissingValues() {
        for (uv, expected): (Double?, [Advice]) in [(nil, []), (.nan, []), (2.9, []), (3, [.uv]), (7.9, [.uv]), (8, [.extremeUV])] {
            var value = state(); value.weather?.hours = [.init(time: now, uv: uv)]
            #expect(EnvironmentAdvice.weather(value, at: now) == expected)
        }
    }
    @Test func everyAdviceHasBothLanguages() {
        for item in Advice.allCases {
            #expect(!item.title(.ru).isEmpty && !item.body(.ru).isEmpty)
            #expect(item.title(.ru) != item.title(.uz))
            #expect(item.body(.ru) != item.body(.uz))
        }
    }
}
