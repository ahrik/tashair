import AppIntents
import Charts
import SwiftUI
import TashAirCore
import WidgetKit

enum WidgetMetric: String, AppEnum {
    case aqi, pm25, temperature, uv, kp
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Показатель"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .aqi: "US AQI", .pm25: "PM2.5", .temperature: "Температура", .uv: "УФ-индекс", .kp: "Kp"
    ]
    var metric: Metric { Metric(rawValue: rawValue)! }
}
enum WidgetLanguage: String, AppEnum {
    case system, ru, uz
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Язык"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [.system: "Как в macOS", .ru: "Русский", .uz: "O‘zbekcha"]
    var language: Language { self == .system ? .system : self == .uz ? .uz : .ru }
}
struct Configuration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Настроить виджет"
    static let description = IntentDescription("Ташкент · воздух, погода и солнце")
    @Parameter(title: "Показатель", default: .aqi) var metric: WidgetMetric
    @Parameter(title: "Язык", default: .system) var language: WidgetLanguage
}
struct Entry: TimelineEntry {
    var date: Date
    var configuration: Configuration
    var snapshot: EnvironmentSnapshot
    var failed: Set<Feed> = []
}
struct Provider: AppIntentTimelineProvider {
    static let repository = EnvironmentRepository()
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), configuration: Configuration(), snapshot: EnvironmentSnapshot()) }
    func snapshot(for configuration: Configuration, in context: Context) async -> Entry {
        let state = await Self.repository.state()
        return Entry(date: Date(), configuration: configuration, snapshot: state.snapshot, failed: Set(state.errors.keys))
    }
    func timeline(for configuration: Configuration, in context: Context) async -> Timeline<Entry> {
        let state = await Self.repository.refresh(feeds: [.weather, .air, .space])
        let now = Date()
        // Scheduled entries expire cached values even if the system delays the next network refresh.
        let dates = [now] + (1...8).map { now.addingTimeInterval(Double($0) * 900) }
        let entries = dates.map { Entry(date: $0, configuration: configuration, snapshot: state.snapshot, failed: Set(state.errors.keys)) }
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(1800)))
    }
}

struct TashAirWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Entry
    var previewFamily: WidgetFamily? = nil
    private var size: WidgetFamily { previewFamily ?? family }
    private var language: Language { entry.configuration.language.language }
    private var metric: Metric { entry.configuration.metric.metric }
    private var snapshot: EnvironmentSnapshot { entry.snapshot }
    private func t(_ value: String) -> String { language.text(value) }
    private var feeds: [Feed] { size == .systemSmall ? [metric == .kp ? .space : metric == .aqi || metric == .pm25 ? .air : .weather] : [.air, .weather, .space] }
    private var saved: Bool { feeds.contains { !snapshot.isFresh($0, at: entry.date) || entry.failed.contains($0) } }
    private var checked: Date? { feeds.compactMap { snapshot.fetched[$0] }.min() }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "aqi.medium").foregroundStyle(.teal)
                Text("TashAir").fontWeight(.semibold)
                Spacer(minLength: 2)
                Text(t("Ташкент")).foregroundStyle(.secondary)
            }.font(.system(size: 10))
            if size == .systemSmall { small }
            else {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                    GridRow { cell(.aqi); cell(.temperature) }
                    GridRow { cell(.uv); cell(.kp) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if size == .systemLarge { large }
            }
            Spacer(minLength: 0)
            footer
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(size == .systemSmall ? metric.link : URL(string: "tashair://overview")!)
        .environment(\.timeZone, Tashkent.timeZone)
    }
    private var small: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(t(metric.title)).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(metric.formatted(snapshot.value(metric, at: entry.date)))
                    .font(.system(size: 37, weight: .medium, design: .rounded)).monospacedDigit().minimumScaleFactor(0.6)
                Text(metric.unit).font(.system(size: 10)).foregroundStyle(.secondary)
            }.lineLimit(1)
            if metric == .aqi, let value = snapshot.air?.aqi { Text(t(AirQuality.title(value))).font(.system(size: 10)).lineLimit(2) }
            Text(t(metric == .kp ? "Глобальные показатели" : "Модельная оценка")).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }
    private func cell(_ metric: Metric) -> some View {
        Link(destination: metric.link) {
            VStack(alignment: .leading, spacing: 3) {
                Label(t(metric.title), systemImage: metric.symbol).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(metric.formatted(snapshot.value(metric, at: entry.date))).font(.system(size: 23, weight: .medium, design: .rounded)).monospacedDigit()
                    Text(metric.unit).font(.system(size: 9)).foregroundStyle(.secondary)
                }.lineLimit(1).minimumScaleFactor(0.7)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(.plain)
    }
    private var large: some View {
        Group {
            Divider()
            HStack { Text(t("Воздух") + " · " + t("Прогноз")); Spacer(); Text("US AQI") }.font(.system(size: 10)).foregroundStyle(.secondary)
            let hours = (snapshot.air?.hours ?? []).filter { $0.time >= entry.date && $0.time < entry.date.addingTimeInterval(86400) }
            Chart {
                ForEach(Array(hours.enumerated()), id: \.element.id) { index, hour in
                    if let value = hour.aqi {
                        // An index-based series breaks the line if any preceding hourly value is absent.
                        let segment = hours.prefix(index).filter { $0.aqi == nil }.count
                        LineMark(x: .value("Time", hour.time), y: .value("AQI", value), series: .value("Segment", segment)).foregroundStyle(.teal)
                    }
                }
            }.chartXAxis(.hidden).chartYAxis { AxisMarks(values: .automatic(desiredCount: 2)) }.chartLegend(.hidden).frame(height: 65)
            HStack(spacing: 0) {
                ForEach(Array((snapshot.weather?.days ?? []).filter { $0.time >= Tashkent.calendar.startOfDay(for: entry.date) }.prefix(5))) { day in
                    VStack(spacing: 4) {
                        Text(Tashkent.date(day.time, format: "dd.MM")).foregroundStyle(.secondary)
                        Image(systemName: WeatherCode.symbol(day.code)).symbolRenderingMode(.multicolor)
                        Text(day.maximum.map { String(format: "%.0f°", $0) } ?? "—")
                    }.font(.system(size: 10)).frame(maxWidth: .infinity)
                }
            }
        }
    }
    private var footer: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                if saved { Image(systemName: "clock.badge.exclamationmark") }
                Text(t(checked == nil ? "Нет данных" : saved ? "Сохранённые данные" : "Проверено"))
                if let checked { Text(Tashkent.date(checked, format: "HH:mm")) }
            }.foregroundStyle(saved ? .orange : .secondary)
            Text(size == .systemSmall ? (metric == .kp ? "NOAA SWPC" : metric == .aqi || metric == .pm25 ? "Open-Meteo · CAMS" : "Open-Meteo") : t("Модель") + ": Open-Meteo · CAMS / NOAA " + t("Глобально"))
                .foregroundStyle(.secondary)
        }.font(.system(size: 9)).lineLimit(1).minimumScaleFactor(0.8)
    }
}

struct TashAirWidget: Widget {
    let kind = "TashAirEnvironment"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: Configuration.self, provider: Provider()) { entry in TashAirWidgetView(entry: entry) }
            .configurationDisplayName("TashAir")
            .description("Ташкент · воздух, погода и солнце")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#if !WIDGET_PREVIEW
@main struct TashAirWidgets: WidgetBundle {
    var body: some Widget { TashAirWidget() }
}
#endif
