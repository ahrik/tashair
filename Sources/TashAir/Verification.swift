import AppKit
import SwiftUI
import TashAirCore

/// Explicit developer mode: isolated cache, no saved preferences, no notification delivery.
@MainActor enum Verification {
    static func run(directory: URL) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
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
    private static func render<V: View>(_ content: V, to file: URL, dark: Bool) throws {
        let size = NSSize(width: 540, height: 780)
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
