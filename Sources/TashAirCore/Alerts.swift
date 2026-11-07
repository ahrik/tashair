import Foundation

public struct AlertRule: Codable, Identifiable, Sendable {
    public var id: String
    public var metric: Metric
    public var threshold: Double
    public var below: Bool
    public var enabled: Bool
    public init(id: String, metric: Metric, threshold: Double, below: Bool = false, enabled: Bool = false) {
        self.id = id; self.metric = metric; self.threshold = threshold; self.below = below; self.enabled = enabled
    }
    public static let defaults: [AlertRule] = [
        .init(id: "aqi", metric: .aqi, threshold: 101), .init(id: "uv", metric: .uv, threshold: 6),
        .init(id: "kp", metric: .kp, threshold: 5), .init(id: "heat", metric: .temperature, threshold: 35),
        .init(id: "cold", metric: .temperature, threshold: 0, below: true)
    ]
    var signature: String { "\(metric.rawValue):\(threshold):\(below)" }
}

public struct AlertEvent: Sendable {
    public var rule: AlertRule
    public var value: Double
}

public struct AlertLedger: Codable, Sendable {
    private var active: [String: Bool] = [:]
    private var signatures: [String: String] = [:]
    private var summaryDay: String?
    private var lastSummaryCheck: Date?
    public init() {}

    /// Only current values can trigger rules; missing/stale data never re-arm them.
    public mutating func evaluate(rules: [AlertRule], snapshot: EnvironmentSnapshot, at now: Date) -> [AlertEvent] {
        var events: [AlertEvent] = []
        for rule in rules {
            guard rule.enabled, rule.threshold.isFinite else { active[rule.id] = nil; signatures[rule.id] = nil; continue }
            if signatures[rule.id] != rule.signature { active[rule.id] = nil; signatures[rule.id] = rule.signature }
            guard snapshot.isFresh(rule.metric, at: now), let value = snapshot.value(rule.metric, at: now), value.isFinite else { continue }
            let triggered = rule.below ? value <= rule.threshold : value >= rule.threshold
            if triggered && active[rule.id] != true { events.append(AlertEvent(rule: rule, value: value)) }
            active[rule.id] = triggered
        }
        return events
    }

    /// Require a live check across the scheduled minute. A launch/wake cannot replay missed summaries.
    public mutating func summaryDue(enabled: Bool, hour: Int, minute: Int, at now: Date) -> Bool {
        defer { lastSummaryCheck = now }
        guard enabled, let previous = lastSummaryCheck, now.timeIntervalSince(previous) >= 0,
              now.timeIntervalSince(previous) <= 90 else { return false }
        let calendar = Tashkent.calendar
        guard let target = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now), previous < target, now >= target else { return false }
        let day = Tashkent.date(now, format: "yyyy-MM-dd")
        guard summaryDay != day else { return false }
        summaryDay = day
        return true
    }
    public mutating func resetSummaryClock() { lastSummaryCheck = nil }
}
