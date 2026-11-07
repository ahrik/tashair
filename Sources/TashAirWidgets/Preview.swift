#if WIDGET_PREVIEW
import AppKit
import SwiftUI
import TashAirCore
import WidgetKit

@main enum WidgetPreview {
    @MainActor static func main() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let directory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "temp/widget-previews")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let snapshotFile = directory.deletingLastPathComponent().appendingPathComponent("verification/snapshot.json")
        let snapshot: EnvironmentSnapshot
        if FileManager.default.fileExists(atPath: snapshotFile.path) {
            snapshot = try JSONDecoder().decode(EnvironmentSnapshot.self, from: Data(contentsOf: snapshotFile))
        } else {
            let repository = EnvironmentRepository(directory: directory.appendingPathComponent("cache"))
            snapshot = await repository.refresh(feeds: [.air, .weather, .space]).snapshot
        }
        for language in [WidgetLanguage.ru, .uz] {
            for dark in [false, true] {
                for (family, size, name) in [(WidgetFamily.systemSmall, NSSize(width: 170, height: 170), "small"), (.systemMedium, NSSize(width: 360, height: 170), "medium"), (.systemLarge, NSSize(width: 360, height: 376), "large")] {
                    for state in ["fresh", "saved", "empty"] {
                        let config = Configuration(); config.language = language
                        let entry = Entry(date: Date().addingTimeInterval(state == "saved" ? 86400 : 0), configuration: config, snapshot: state == "empty" ? EnvironmentSnapshot() : snapshot)
                        let path = directory.appendingPathComponent("\(name)-\(language.rawValue)-\(dark ? "dark" : "light")-\(state).png")
                        try render(entry: entry, family: family, size: size, dark: dark, path: path)
                    }
                }
                for metric in [WidgetMetric.pm25, .temperature, .uv, .kp] {
                    let config = Configuration(); config.language = language; config.metric = metric
                    try render(entry: Entry(date: Date(), configuration: config, snapshot: snapshot), family: .systemSmall, size: NSSize(width: 170, height: 170), dark: dark, path: directory.appendingPathComponent("small-\(metric.rawValue)-\(language.rawValue)-\(dark ? "dark" : "light").png"))
                }
            }
        }
        for topic in WidgetTopic.allCases {
            for language in [WidgetLanguage.ru, .uz] {
                for dark in [false, true] {
                    for (family, size, name) in [(WidgetFamily.systemSmall, NSSize(width: 170, height: 170), "small"), (.systemMedium, NSSize(width: 360, height: 170), "medium"), (.systemLarge, NSSize(width: 360, height: 376), "large")] {
                        for state in ["fresh", "saved", "empty"] {
                            let config = Configuration(); config.language = language
                            let entry = Entry(date: Date().addingTimeInterval(state == "saved" ? 86400 : 0), configuration: config, snapshot: state == "empty" ? EnvironmentSnapshot() : snapshot)
                            let content = TopicWidgetView(entry: entry, topic: topic, previewFamily: family)
                            try render(content: content, size: size, dark: dark, path: directory.appendingPathComponent("\(topic.rawValue)-\(name)-\(language.rawValue)-\(dark ? "dark" : "light")-\(state).png"))
                        }
                    }
                }
            }
        }
        print("Rendered 160 widget previews to \(directory.path)")
    }
    @MainActor private static func render(entry: Entry, family: WidgetFamily, size: NSSize, dark: Bool, path: URL) throws {
        try render(content: TashAirWidgetView(entry: entry, previewFamily: family), size: size, dark: dark, path: path)
    }
    @MainActor private static func render<Content: View>(content: Content, size: NSSize, dark: Bool, path: URL) throws {
        let content = content
            .padding(16).frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .environment(\.colorScheme, dark ? .dark : .light)
        let host = NSHostingView(rootView: content)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw ProviderError.invalidData("widget render") }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ProviderError.invalidData("widget PNG") }
        try png.write(to: path)
        window.contentView = nil
    }
}
#endif
