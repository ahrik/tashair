import AppKit
import Observation
import SwiftUI
import TashAirCore
import UserNotifications

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let store = Store(inMemory: CommandLine.arguments.contains("--verify"))
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var observer: NSObjectProtocol?
    private var ticker: Timer?
    private var badgeStyle: StatusBadgeStyle?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let index = CommandLine.arguments.firstIndex(of: "--verify"), CommandLine.arguments.count > index + 1 {
            let directory = URL(fileURLWithPath: CommandLine.arguments[index + 1])
            Task {
                do { try await Verification.run(directory: directory); NSApp.terminate(nil) }
                catch { print("Verification failed: \(error)"); exit(1) }
            }
            return
        }
        UNUserNotificationCenter.current().delegate = self
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "aqi.medium", accessibilityDescription: "TashAir")
        statusItem.button?.target = self; statusItem.button?.action = #selector(toggle)
        popover.behavior = .transient
        let height = min(780, (NSScreen.main?.visibleFrame.height ?? 900) - 60)
        popover.contentSize = NSSize(width: 540, height: height)
        popover.contentViewController = NSHostingController(rootView: PanelView(store: store).frame(width: 540, height: height))
        store.onOpen = { [weak self] section in
            if section == "space" { NotificationCenter.default.post(name: .init("TashAirOpenSpace"), object: nil) }
            self?.show()
        }
        observer = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.store.wake() }
        }
        ticker = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateStatus() }
        }
        observeStatus(); store.start()
        if CommandLine.arguments.contains("--preview") { show() }
    }
    private func observeStatus() {
        withObservationTracking {
            updateStatus()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeStatus() }
        }
    }
    private func updateStatus() {
        guard let button = statusItem.button else { return }
        let metric = store.preferences.menuMetric
        let snapshot = store.snapshot
        let now = Date()
        let airMetric = metric == .aqi || metric == .pm25
        let feed: Feed = airMetric ? .air : metric == .kp ? .space : .weather
        let rawValue = snapshot.value(metric, at: now)
        let available = rawValue?.isFinite == true && (metric != .aqi || AirQuality.level(rawValue) != nil)
        let value = metric.formatted(available ? rawValue : nil)
        let fresh = available && snapshot.isFresh(metric, at: now) && store.errors[feed] == nil
        let saved = fresh ? "" : " ◦"
        let title = "\(value) \(metric == .temperature ? "°" : metric == .aqi ? "AQI" : metric.unit)\(saved)"
        let level = fresh && airMetric ? AirQuality.level(snapshot.air?.aqi) : nil
        if airMetric {
            let style = StatusBadgeStyle(title: title, level: level, height: max(18, min(26, button.bounds.height - 4)))
            if badgeStyle != style {
                button.title = ""
                let image = StatusBadgeRenderer.image(style)
                button.image = image
                button.imagePosition = .imageOnly
                statusItem.length = image.size.width + 8
                badgeStyle = style
            }
        } else {
            badgeStyle = nil
            button.image = NSImage(systemSymbolName: "aqi.medium", accessibilityDescription: nil)
            button.imagePosition = .imageLeading
            button.title = " " + title
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            statusItem.length = NSStatusItem.variableLength
        }
        var tooltip = "TashAir · \(store.t("Ташкент"))\n\(store.t(metric.title)): \(title)\n\(store.t(metric == .kp ? "Глобальные показатели" : "Модельная оценка"))"
        if let level { tooltip += "\n\(store.t(level.title)) · \(level.rangeLabel) US AQI" }
        if !fresh { tooltip += "\n" + store.t(available ? "Сохранённые данные" : "Нет данных") }
        button.toolTip = tooltip
        button.setAccessibilityLabel(tooltip.replacingOccurrences(of: "\n", with: ", "))
    }
    @objc private func toggle() { if popover.isShown { popover.performClose(nil) } else { show() } }
    private func show() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        if !popover.isShown { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
        popover.contentViewController?.view.window?.makeKey()
        Task { await store.refresh() }
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first, url.scheme == "tashair", let section = url.host else { return }
        store.open(section)
    }
    func applicationWillTerminate(_ notification: Notification) {
        store.stop(); ticker?.invalidate()
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound] }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let section = response.notification.request.content.userInfo["section"] as? String ?? "overview"
        await MainActor.run { self.store.open(section) }
    }
}

@main struct TashAirMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
