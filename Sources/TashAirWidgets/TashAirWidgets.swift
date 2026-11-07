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


// Each topic has a stable gallery identity and requests only its own sources.
enum WidgetTopic: String, CaseIterable {
    case air, weather, solar
    var title: String {
        switch self { case .air: "Воздух"; case .weather: "Погода"; case .solar: "Солнечная активность" }
    }
    var symbol: String {
        switch self { case .air: "aqi.medium"; case .weather: "cloud.sun.fill"; case .solar: "sun.max.fill" }
    }
    var feeds: [Feed] {
        switch self { case .air: [.air]; case .weather: [.weather]; case .solar: [.weather, .space, .flares] }
    }
    var link: URL {
        switch self { case .air: Metric.aqi.link; case .weather: Metric.temperature.link; case .solar: Metric.uv.link }
    }
    var source: String {
        switch self { case .air: "Open-Meteo · CAMS"; case .weather: "Open-Meteo"; case .solar: "Open-Meteo / NOAA SWPC" }
    }
}

struct TopicConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Настроить виджет"
    @Parameter(title: "Язык", default: .system) var language: WidgetLanguage
}

struct TopicProvider: AppIntentTimelineProvider {
    let topic: WidgetTopic
    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), configuration: Configuration(), snapshot: EnvironmentSnapshot())
    }
    func snapshot(for configuration: TopicConfiguration, in context: Context) async -> Entry {
        makeEntry(configuration, state: await Provider.repository.state(), at: Date())
    }
    func timeline(for configuration: TopicConfiguration, in context: Context) async -> Timeline<Entry> {
        let state = await Provider.repository.refresh(feeds: topic.feeds)
        let now = Date()
        let dates = [now] + (1...8).map { now.addingTimeInterval(Double($0) * 900) }
        return Timeline(entries: dates.map { makeEntry(configuration, state: state, at: $0) },
                        policy: .after(now.addingTimeInterval(1800)))
    }
    private func makeEntry(_ configuration: TopicConfiguration, state: RefreshState, at date: Date) -> Entry {
        let config = Configuration()
        config.language = configuration.language
        return Entry(date: date, configuration: config, snapshot: state.snapshot, failed: Set(state.errors.keys))
    }
}

struct TopicWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Entry
    let topic: WidgetTopic
    var previewFamily: WidgetFamily? = nil
    private var size: WidgetFamily { previewFamily ?? family }
    private var compact: Bool { size == .systemSmall }
    private var snapshot: EnvironmentSnapshot { entry.snapshot }
    private func t(_ key: String) -> String { entry.configuration.language.language.text(key) }
    private var visibleFeeds: [Feed] { compact && topic == .solar ? [.weather] : topic.feeds }
    private var saved: Bool { visibleFeeds.contains { !snapshot.isFresh($0, at: entry.date) || entry.failed.contains($0) } }
    private var checked: Date? { visibleFeeds.compactMap { snapshot.fetched[$0] }.min() }
    private var today: Day? {
        snapshot.weather?.days.first { Tashkent.calendar.isDate($0.time, inSameDayAs: entry.date) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 7) {
            HStack(spacing: 4) {
                Image(systemName: topic.symbol).foregroundStyle(.teal)
                Text(t(topic.title)).fontWeight(.semibold).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                if !compact { Text(t("Ташкент")).foregroundStyle(.secondary) }
            }.font(.system(size: 11))
            switch topic {
            case .air: air
            case .weather: weather
            case .solar: solar
            }
            if size == .systemLarge { forecast }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    if saved { Image(systemName: "clock.badge.exclamationmark") }
                    Text(t(checked == nil ? "Нет данных" : saved ? "Сохранённые данные" : "Проверено"))
                    if let checked { Text(Tashkent.date(checked, format: "HH:mm")) }
                }.foregroundStyle(saved ? .orange : .secondary)
                Text(compact && topic == .solar ? "Open-Meteo" : topic.source).foregroundStyle(.secondary)
            }.font(.system(size: 9)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(topic.link)
        .environment(\.timeZone, Tashkent.timeZone)
        .environment(\.locale, Locale(identifier: entry.configuration.language.language == .uz ? "uz_UZ" : "ru_RU"))
    }
    private func value(_ value: Double?, unit: String, prominent: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value.flatMap { $0.isFinite ? String(format: ["Kp", "µg/m³", t("м/с")].contains(unit) ? "%.1f" : "%.0f", $0) : nil } ?? "—")
                .font(.system(size: prominent ? (compact ? 34 : 30) : 18, weight: .medium, design: .rounded)).monospacedDigit()
            Text(unit).font(.system(size: 10)).foregroundStyle(.secondary)
        }.lineLimit(1).minimumScaleFactor(0.65)
    }
    private func detail(_ title: String, value number: Double?, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t(title)).font(.system(size: 10)).foregroundStyle(.secondary)
            value(number, unit: unit)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var air: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                value(snapshot.air?.aqi, unit: "US AQI", prominent: true)
                if !compact { detail("PM2.5", value: snapshot.air?.pm25, unit: "µg/m³") }
            }
            Text(t(snapshot.air.map { AirQuality.title($0.aqi ?? .nan) } ?? "Нет данных"))
                .font(.system(size: 11)).lineLimit(2).minimumScaleFactor(0.8)
            if !compact {
                HStack {
                    detail("PM10", value: snapshot.air?.pm10, unit: "µg/m³")
                    detail("Пыль", value: snapshot.air?.dust, unit: "µg/m³")
                }
            }
            if compact { Text(t("Модельная оценка")).font(.system(size: 9)).foregroundStyle(.secondary) }
        }
    }
    private func weatherNumber(_ number: Double?, format: String) -> String {
        guard let number, number.isFinite else { return "—" }
        return String(format: format, number)
    }
    private var precipitationSummary: String {
        let amount = weatherNumber(today?.precipitation, format: "%.1f")
        return "\(t("Осадки")): \(amount) \(t("мм"))"
    }
    private var weather: some View {
        VStack(alignment: .leading, spacing: 5) {
            weatherCurrent
            Text(t(WeatherCode.title(snapshot.weather?.code))).font(.system(size: 11)).lineLimit(1)
            weatherDaily
        }
    }
    private var weatherCurrent: some View {
        HStack {
            value(snapshot.weather?.temperature, unit: "°C", prominent: true)
            Image(systemName: WeatherCode.symbol(snapshot.weather?.code)).symbolRenderingMode(.multicolor)
            if !compact {
                Spacer()
                detail("Ощущается", value: snapshot.weather?.apparent, unit: "°C")
                detail("Ветер", value: snapshot.weather?.wind, unit: t("м/с"))
            }
        }
    }
    private var weatherDaily: some View {
        HStack(spacing: 8) {
            Text("↓ " + weatherNumber(today?.minimum, format: "%.0f°"))
            Text("↑ " + weatherNumber(today?.maximum, format: "%.0f°"))
            if !compact { Text(precipitationSummary) }
        }.font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
    }
    private var solar: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                value(snapshot.value(.uv, at: entry.date), unit: "UV", prominent: true)
                if !compact {
                    Link(destination: Metric.kp.link) {
                        detail("Глобально", value: snapshot.value(.kp, at: entry.date), unit: "Kp")
                    }.buttonStyle(.plain)
                    detail("Максимальный УФ", value: today?.uv, unit: "UV")
                }
            }
            HStack(spacing: 8) {
                Label(today?.sunrise.map { Tashkent.date($0, format: "HH:mm") } ?? "—", systemImage: "sunrise")
                Label(today?.sunset.map { Tashkent.date($0, format: "HH:mm") } ?? "—", systemImage: "sunset")
            }.font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            if !compact {
                Link(destination: Metric.kp.link) {
                    let flare = snapshot.flares.filter { $0.time <= entry.date }.max { $0.time < $1.time }
                    Text(t("Солнечные вспышки") + ": " + (flare.map { $0.classification + " · " + Tashkent.date($0.time) } ?? t("Нет данных")))
                        .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }.buttonStyle(.plain)
            }
        }
    }
    @ViewBuilder private var forecast: some View {
        Divider()
        Text(t("Прогноз")).font(.system(size: 11)).foregroundStyle(.secondary)
        if topic == .solar {
            let points = snapshot.space.filter { $0.kind == .predicted && $0.time >= entry.date }.prefix(8)
            if points.isEmpty { Text(t("Нет данных")).font(.caption).foregroundStyle(.secondary) }
            else {
                Chart(Array(points)) { point in
                    BarMark(x: .value("Time", point.time), y: .value("Kp", point.value)).foregroundStyle(.teal)
                }.chartYScale(domain: 0...9).chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) }.frame(height: 95)
            }
            Text(t("Глобальные показатели") + " · NOAA SWPC").font(.system(size: 10)).foregroundStyle(.secondary)
        } else {
            let hours = (topic == .air ? snapshot.air?.hours : snapshot.weather?.hours) ?? []
            let upcoming = hours.filter { $0.time >= entry.date && $0.time < entry.date.addingTimeInterval(86400) }
            let values = upcoming.compactMap { topic == .air ? $0.aqi : $0.temperature }
            if values.isEmpty { Text(t("Нет данных")).font(.caption).foregroundStyle(.secondary) }
            else {
                Chart {
                    ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, hour in
                        if let number = topic == .air ? hour.aqi : hour.temperature {
                            let segment = upcoming.prefix(index).filter { (topic == .air ? $0.aqi : $0.temperature) == nil }.count
                            LineMark(x: .value("Time", hour.time), y: .value(topic == .air ? "US AQI" : "°C", number), series: .value("Segment", segment)).foregroundStyle(.teal)
                        }
                    }
                }.chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) }.chartLegend(.hidden).frame(height: 85)
            }
            Text(topic == .air ? "US AQI · " + t("Модельная оценка") : "°C · " + t("Модельная оценка"))
                .font(.system(size: 10)).foregroundStyle(.secondary)
            if topic == .weather {
                HStack {
                    ForEach(Array((snapshot.weather?.days ?? []).filter { $0.time >= Tashkent.calendar.startOfDay(for: entry.date) }.prefix(5))) { day in
                        VStack(spacing: 3) {
                            Text(Tashkent.date(day.time, format: "dd.MM"))
                            Image(systemName: WeatherCode.symbol(day.code)).symbolRenderingMode(.multicolor)
                            Text(day.maximum.map { String(format: "%.0f°", $0) } ?? "—")
                        }.font(.system(size: 10)).frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

@MainActor private struct TopicWidget {
    let topic: WidgetTopic
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "TashAirTopic-" + topic.rawValue, intent: TopicConfiguration.self,
                               provider: TopicProvider(topic: topic)) { entry in
            TopicWidgetView(entry: entry, topic: topic)
        }
        .configurationDisplayName(LocalizedStringKey(topic.title))
        .description("Ташкент · воздух, погода и солнце")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct AirWidget: Widget {
    var body: some WidgetConfiguration { TopicWidget(topic: .air).body }
}
struct WeatherWidget: Widget {
    var body: some WidgetConfiguration { TopicWidget(topic: .weather).body }
}
struct SolarWidget: Widget {
    var body: some WidgetConfiguration { TopicWidget(topic: .solar).body }
}

#if !WIDGET_PREVIEW
@main struct TashAirWidgets: WidgetBundle {
    var body: some Widget {
        TashAirWidget()
        AirWidget()
        WeatherWidget()
        SolarWidget()
    }
}
#endif
