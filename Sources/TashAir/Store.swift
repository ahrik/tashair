import AppKit
import Observation
import ServiceManagement
import TashAirCore
import UserNotifications

struct Preferences: Codable {
    var language = Language.system
    var menuMetric = Metric.aqi
    var rules = AlertRule.defaults
    var summary = false
    var summaryHour = 8
    var summaryMinute = 0
}

@MainActor @Observable final class Store {
    var preferences: Preferences { didSet { savePreferences() } }
    var snapshot = EnvironmentSnapshot()
    var errors: [Feed: String] = [:]
    var now = Date()
    var loading = false
    var tab = "overview"
    var settingsVisible = false
    var notificationPermission = false
    var problem: String?
    var onOpen: ((String) -> Void)?
    var loginEnabled = SMAppService.mainApp.status == .enabled
    private let repository = EnvironmentRepository()
    private let center = UNUserNotificationCenter.current()
    private var loop: Task<Void, Never>?
    private var ledger = AlertLedger()
    private var persistenceBlocked = false
    private let inMemory: Bool
    private let ledgerURL: URL
    var language: Language { preferences.language }
    func t(_ key: String) -> String { language.text(key) }

    init(inMemory: Bool = false) {
        self.inMemory = inMemory
        preferences = inMemory ? Preferences() : UserDefaults.standard.data(forKey: "preferences").flatMap { try? JSONDecoder().decode(Preferences.self, from: $0) } ?? Preferences()
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TashAir")
        ledgerURL = folder.appendingPathComponent("alerts.json")
        if !inMemory && FileManager.default.fileExists(atPath: ledgerURL.path) {
            do { ledger = try JSONDecoder().decode(AlertLedger.self, from: Data(contentsOf: ledgerURL)) }
            catch { persistenceBlocked = true; problem = "\(t("Ошибка сохранения")): \(error.localizedDescription)" }
        }
        ledger.resetSummaryClock()
    }
    private func savePreferences() {
        guard !inMemory else { return }
        do { UserDefaults.standard.set(try JSONEncoder().encode(preferences), forKey: "preferences") }
        catch { problem = error.localizedDescription }
    }
    func start() {
        guard loop == nil else { return }
        loop = Task {
            let cached = await repository.state()
            snapshot = cached.snapshot; errors = cached.errors
            await checkPermission()
            while !Task.isCancelled {
                await refresh()
                do { try await Task.sleep(for: .seconds(30)) } catch { break }
            }
        }
    }
    func stop() { loop?.cancel(); loop = nil }
    func wake() {
        ledger.resetSummaryClock()
        Task { await refresh() }
    }
    func refresh(force: Bool = false) async {
        guard !loading else { return }
        loading = true
        let state = await repository.refresh(force: force)
        now = Date(); snapshot = state.snapshot; errors = state.errors
        loading = false
        await checkPermission()
        await evaluateNotifications()
    }
    func checkPermission() async {
        let status = await center.notificationSettings().authorizationStatus
        notificationPermission = status == .authorized || status == .provisional
    }
    func authorize() async -> Bool {
        do { _ = try await center.requestAuthorization(options: [.alert, .sound]); await checkPermission() }
        catch { problem = error.localizedDescription }
        return notificationPermission
    }
    func enableRule(_ index: Int, enabled: Bool) {
        Task {
            if enabled { guard await authorize() else { return } }
            preferences.rules[index].enabled = enabled
            await evaluateNotifications()
        }
    }
    func enableSummary(_ enabled: Bool) {
        Task {
            if enabled { guard await authorize() else { return } }
            preferences.summary = enabled
            ledger.resetSummaryClock()
        }
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
        } catch { problem = error.localizedDescription }
    }
    private func evaluateNotifications() async {
        guard notificationPermission, !persistenceBlocked else { return }
        let events = ledger.evaluate(rules: preferences.rules, snapshot: snapshot, at: now)
        let summary = ledger.summaryDue(enabled: preferences.summary, hour: preferences.summaryHour, minute: preferences.summaryMinute, at: now)
        do {
            try FileManager.default.createDirectory(at: ledgerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(ledger).write(to: ledgerURL, options: .atomic)
        } catch { problem = "\(t("Ошибка сохранения")): \(error.localizedDescription)"; return }
        for event in events {
            let metric = event.rule.metric
            let qualification = metric == .kp ? t("Глобальные показатели") : t("Модельная оценка")
            await deliver(id: "threshold-\(event.rule.id)-\(Int(now.timeIntervalSince1970))", title: "TashAir · \(t("Порог достигнут"))", body: "\(t(metric.title)): \(metric.formatted(event.value)) \(metric.unit). \(qualification). \(Tashkent.date(now))", section: metric.section)
        }
        if summary {
            let fields = [Metric.aqi, .temperature, .uv, .kp].compactMap { metric -> String? in
                guard snapshot.isFresh(metric, at: now), let value = snapshot.value(metric, at: now) else { return nil }
                return "\(metric.formatted(value)) \(metric.unit)"
            }
            if !fields.isEmpty {
                await deliver(id: "summary-\(Tashkent.date(now, format: "yyyy-MM-dd"))", title: t("Сводка по Ташкенту"), body: fields.joined(separator: " · ") + "\n" + t("Модельная оценка") + " · " + Tashkent.date(now), section: "overview")
            }
        }
    }
    private func deliver(id: String, title: String, body: String, section: String) async {
        let content = UNMutableNotificationContent()
        content.title = title; content.body = body; content.sound = .default
        content.userInfo = ["section": section]
        do { try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil)) }
        catch { problem = error.localizedDescription }
    }
    func open(_ section: String) {
        guard ["overview", "air", "weather", "sun", "space"].contains(section) else { return }
        settingsVisible = false; tab = section == "space" ? "sun" : section
        onOpen?(section)
    }
}
