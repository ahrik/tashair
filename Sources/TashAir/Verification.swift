import AppKit
import SwiftUI
import TashAirCore

/// Explicit developer mode: isolated cache, no saved preferences, no notification delivery.
@MainActor enum Verification {
    static func run(directory: URL) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try renderStatusBadges(directory: directory)
        try renderAdvice(directory: directory)
        let repository = EnvironmentRepository(directory: directory.appendingPathComponent("cache"))
        let state = await repository.refresh(force: true)
        try JSONEncoder().encode(state.snapshot).write(to: directory.appendingPathComponent("snapshot.json"), options: .atomic)
        let report: [String: Any] = ["sources": state.snapshot.fetched.keys.map(\.rawValue).sorted(), "errors": Dictionary(uniqueKeysWithValues: state.errors.map { ($0.key.rawValue, $0.value) }), "historyDays": state.snapshot.history.count, "forecastDays": state.snapshot.weather?.days.count ?? 0, "airHours": state.snapshot.air?.hours.count ?? 0, "kpPoints": state.snapshot.space.count, "flares": state.snapshot.flares.count]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("report.json"))
        for language in Language.allCases {
            for dark in [false, true] {
                for tab in ["overview", "air", "weather", "sun", "history", "settings"] {
                    let store = Store(inMemory: true)
                    store.snapshot = state.snapshot; store.errors = state.errors; store.preferences.language = language
                    store.tab = tab == "history" ? "weather" : tab
                    store.settingsVisible = tab == "settings"
                    let view = PanelView(store: store, weatherPeriod: tab == "history" ? 3 : 0, spaceExpanded: true)
                        .environment(\.colorScheme, dark ? .dark : .light)
                        .environment(\.locale, Locale(identifier: language.rawValue))
                    try render(view, to: directory.appendingPathComponent("\(tab)-\(language.rawValue)-\(dark ? "dark" : "light").png"), dark: dark)
                }
            }
        }
        print("Live API report: \(String(data: try JSONSerialization.data(withJSONObject: report), encoding: .utf8)!)")
        guard state.errors.isEmpty, state.snapshot.fetched.count == Feed.allCases.count else { throw ProviderError.invalidData("one or more live sources failed; see report.json") }
    }
    private static func renderAdvice(directory: URL) throws {
        let now = Date()
        for language in Language.allCases {
            for dark in [false, true] {
                for severe in [false, true] {
                    var snapshot = EnvironmentSnapshot()
                    snapshot.fetched = [.air: now, .weather: now]
                    snapshot.air = try Providers.air(JSONSerialization.data(withJSONObject: ["current": ["time": now.timeIntervalSince1970, "us_aqi": severe ? 220 : 64], "hourly": ["time": [now.timeIntervalSince1970]]]))
                    snapshot.weather = try Providers.weather(JSONSerialization.data(withJSONObject: ["current": ["time": now.timeIntervalSince1970, "temperature_2m": severe ? 36 : 20, "weather_code": severe ? 95 : 0, "wind_gusts_10m": severe ? 18 : 0], "hourly": ["time": [now.timeIntervalSince1970], "uv_index": [severe ? 9 : 1]], "daily": ["time": [now.timeIntervalSince1970]]]))
                    let view = ScrollView {
                        AdviceView(snapshot: snapshot, errors: [:], now: now, language: language).padding(20)
                    }.background(Color(nsColor: .windowBackgroundColor))
                        .environment(\.colorScheme, dark ? .dark : .light)
                    try render(view, to: directory.appendingPathComponent("advice-\(severe ? "severe" : "moderate")-\(language.rawValue)-\(dark ? "dark" : "light").png"), dark: dark, size: NSSize(width: 540, height: 900))
                }
            }
        }
    }
    private static func renderStatusBadges(directory: URL) throws {
        let examples: [Double] = [28, 64, 125, 175, 250, 350]
        for language in Language.allCases {
            for dark in [false, true] {
                let content = VStack(alignment: .leading, spacing: 18) {
                    Text(language.text("Шкала US AQI")).font(.system(size: 22, weight: .semibold))
                    ForEach(examples, id: \.self) { value in
                        let level = AirQuality.level(value)!
                        HStack(spacing: 16) {
                            Image(nsImage: StatusBadgeRenderer.image(.init(title: Metric.aqi.formatted(value) + " AQI", level: level, height: 22)))
                                .frame(width: 125, alignment: .leading)
                            Text(level.rangeLabel).monospacedDigit().frame(width: 70, alignment: .leading)
                            Text(language.text(level.title))
                        }
                    }
                    Divider()
                    HStack(spacing: 16) {
                        Image(nsImage: StatusBadgeRenderer.image(.init(title: "64 AQI ◦", level: nil, height: 22)))
                            .frame(width: 125, alignment: .leading)
                        Text(language.text("Сохранённые данные"))
                    }
                    HStack(spacing: 16) {
                        Image(nsImage: StatusBadgeRenderer.image(.init(title: "— AQI ◦", level: nil, height: 22)))
                            .frame(width: 125, alignment: .leading)
                        Text(language.text("Нет данных"))
                    }
                    Spacer(minLength: 0)
                }.font(.system(size: 12)).padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .environment(\.colorScheme, dark ? .dark : .light)
                try render(content, to: directory.appendingPathComponent("status-badges-\(language.rawValue)-\(dark ? "dark" : "light").png"), dark: dark, size: NSSize(width: 580, height: 470))
            }
        }
    }
    private static func render<V: View>(_ content: V, to file: URL, dark: Bool, size: NSSize = NSSize(width: 540, height: 780)) throws {
        let host = NSHostingView(rootView: content.frame(width: size.width, height: size.height))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw ProviderError.invalidData("render") }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ProviderError.invalidData("PNG") }
        try png.write(to: file)
        window.contentView = nil
    }
}
