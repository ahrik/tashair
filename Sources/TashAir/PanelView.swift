import AppKit
import Charts
import SwiftUI
import TashAirCore

struct PlotPoint: Identifiable {
    var time: Date
    var value: Double
    var segment: Int
    var id: Date { time }
}

func plotPoints(_ values: [(Date, Double?)]) -> [PlotPoint] {
    var segment = 0
    return values.compactMap { time, value in
        guard let value else { segment += 1; return nil }
        return PlotPoint(time: time, value: value, segment: segment)
    }
}

struct TimelineChart: View {
    let values: [(Date, Double?)]
    let unit: String
    var days = false
    var now: Date? = nil
    var body: some View {
        let points = plotPoints(values)
        if points.isEmpty {
            ContentUnavailableView("—", systemImage: "chart.xyaxis.line").frame(height: 125)
        } else {
            Chart {
                ForEach(points) { point in
                LineMark(x: .value("Time", point.time), y: .value(unit, point.value), series: .value("Segment", point.segment))
                    .foregroundStyle(.teal).lineStyle(StrokeStyle(lineWidth: 2))
                }
                if let now, now >= (points.first?.time ?? now), now <= (points.last?.time ?? now) {
                    RuleMark(x: .value("Now", now)).foregroundStyle(.secondary.opacity(0.4)).lineStyle(StrokeStyle(dash: [3, 3]))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(.quaternary)
                    AxisValueLabel { if let date = value.as(Date.self) { Text(Tashkent.date(date, format: days ? "dd.MM" : "HH:mm")) } }
                }
            }
            .chartYAxis { AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) }
            .chartLegend(.hidden).frame(height: 132)
            .accessibilityLabel(unit)
        }
    }
}

struct PanelView: View {
    @Bindable var store: Store
    @State private var weatherPeriod = 0
    @State private var airForecast = false
    @State private var spaceExpanded = false
    init(store: Store, weatherPeriod: Int = 0, airForecast: Bool = false, spaceExpanded: Bool = false) {
        self.store = store
        _weatherPeriod = State(initialValue: weatherPeriod)
        _airForecast = State(initialValue: airForecast)
        _spaceExpanded = State(initialValue: spaceExpanded)
    }
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    private var snapshot: EnvironmentSnapshot { store.snapshot }
    private func t(_ key: String) -> String { store.t(key) }
    private func number(_ value: Double?, _ digits: Int = 0) -> String { value.map { String(format: "%.*f", digits, $0) } ?? "—" }

    var body: some View {
        VStack(spacing: 0) {
            header
            if store.settingsVisible { settings }
            else {
                Picker("", selection: $store.tab) {
                    Text(t("Обзор")).tag("overview")
                    Text(t("Воздух")).tag("air")
                    Text(t("Погода")).tag("weather")
                    Text(t("Солнце")).tag("sun")
                }.pickerStyle(.segmented).labelsHidden().padding(.horizontal, 20).padding(.bottom, 12)
                Divider()
                ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if store.loading && snapshot.fetched.isEmpty { ProgressView(t("Загрузка…")).frame(maxWidth: .infinity).padding(50) }
                        switch store.tab {
                        case "air": air
                        case "weather": weather
                        case "sun": sun
                        default: overview
                        }
                        if !store.errors.isEmpty { sourceProblems }
                        if let problem = store.problem {
                            Text(problem).font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                        }
                    }.padding(20).id("top")
                }.onChange(of: spaceExpanded) { _, expanded in
                    if expanded {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { withAnimation { proxy.scrollTo("space", anchor: .top) } }
                    }
                }
                .onChange(of: store.tab) { _, _ in proxy.scrollTo("top", anchor: .top) }
                .onReceive(NotificationCenter.default.publisher(for: .init("TashAirOpenSpace"))) { _ in
                    spaceExpanded = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { withAnimation { proxy.scrollTo("space", anchor: .top) } }
                }
                }
            }
            Divider()
            HStack {
                Label(t("Ташкент") + " · UTC+5", systemImage: "location.fill")
                Spacer()
                Text(Tashkent.date(store.now, format: "dd.MM · HH:mm"))
            }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.vertical, 9)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(.teal)
        .environment(\.timeZone, Tashkent.timeZone)
    }
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "aqi.medium").font(.system(size: 24, weight: .medium)).foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 2) {
                Text("TashAir").font(.system(size: 19, weight: .semibold))
                Text(t("Воздух, погода и солнце")).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
            if store.loading { ProgressView().controlSize(.small) }
            Button { Task { await store.refresh(force: true) } } label: { Image(systemName: "arrow.clockwise") }
                .disabled(store.loading).help(t("Обновить"))
            Button { store.settingsVisible.toggle() } label: { Image(systemName: store.settingsVisible ? "checkmark" : "gearshape") }
                .help(t(store.settingsVisible ? "Готово" : "Настройки"))
        }.buttonStyle(.borderless).padding(.horizontal, 20).padding(.vertical, 15)
    }
    private func heading(_ title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(t(title)).font(.system(size: 16, weight: .semibold))
            if let subtitle { Text(t(subtitle)).font(.caption).foregroundStyle(.secondary) }
        }
    }
    private func tile(_ title: String, value: String, unit: String, symbol: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).foregroundStyle(.teal) }
                Text(t(title)).foregroundStyle(.secondary)
            }.font(.system(size: 11))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 26, weight: .medium, design: .rounded)).monospacedDigit()
                Text(unit).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
    private func source(_ feed: Feed, time: Date? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(feed.source)
                Spacer()
                if !snapshot.isFresh(feed, at: store.now) || store.errors[feed] != nil {
                    Label(t(snapshot.fetched[feed] == nil ? "Нет данных" : "Сохранённые данные"), systemImage: "clock.badge.exclamationmark").foregroundStyle(.orange)
                }
            }
            if let time { Text(t("Время данных") + ": " + Tashkent.date(time)) }
            if let fetched = snapshot.fetched[feed] { Text(t("Проверено") + ": " + Tashkent.date(fetched)) }
        }.font(.system(size: 10)).foregroundStyle(.secondary)
    }
    private var aqiColor: Color {
        AirQuality.level(snapshot.air?.aqi)?.color ?? .secondary
    }
    private var aqiScale: some View {
        AQIScaleView(aqi: snapshot.air?.aqi, language: store.language)
    }
    private var aqiHero: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(t("Качество воздуха"), systemImage: "aqi.medium").font(.system(size: 12, weight: .medium))
                Spacer()
                Text(t("Модельная оценка")).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Metric.aqi.formatted(snapshot.air?.aqi)).font(.system(size: 58, weight: .medium, design: .rounded)).monospacedDigit()
                Text("US AQI").font(.system(size: 13)).foregroundStyle(.secondary)
                Spacer()
                if let value = snapshot.air?.aqi {
                    Text(t(AirQuality.title(value))).font(.system(size: 13, weight: .medium))
                        .multilineTextAlignment(.trailing).frame(maxWidth: 185)
                }
            }
            HStack(spacing: 7) {
                Circle().fill(aqiColor).frame(width: 7, height: 7)
                Text("PM2.5  \(number(snapshot.air?.pm25, 1)) µg/m³   ·   PM10  \(number(snapshot.air?.pm10, 1)) µg/m³")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            aqiScale
        }.padding(18).background(aqiColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(aqiColor).frame(width: 3).padding(.vertical, 20) }
    }
    private func advice(_ section: Feed? = nil) -> some View {
        AdviceView(snapshot: snapshot, errors: store.errors, now: store.now, language: store.preferences.language, section: section)
    }
    private var overview: some View {
        Group {
            aqiHero
            LazyVGrid(columns: columns, spacing: 10) {
                Button { store.tab = "weather" } label: { tile("Температура", value: number(snapshot.weather?.temperature, 1), unit: "°C", symbol: WeatherCode.symbol(snapshot.weather?.code)) }
                Button { store.tab = "sun" } label: { tile("УФ-индекс", value: number(snapshot.value(.uv, at: store.now), 1), unit: "UV", symbol: "sun.max") }
            }.buttonStyle(.plain)
            HStack {
                Label(t("Геомагнитная активность"), systemImage: "waveform.path").font(.system(size: 12))
                Spacer()
                Text(Metric.kp.formatted(snapshot.value(.kp, at: store.now)) + " Kp").font(.system(size: 18, weight: .medium, design: .rounded))
                Button { store.open("space") } label: { Image(systemName: "chevron.right") }.buttonStyle(.plain)
            }
            advice()
            heading("Воздух", subtitle: "Прогноз")
            TimelineChart(values: airHours(forecast: true, count: 24).map { ($0.time, $0.aqi) }, unit: "US AQI", now: store.now)
            source(.air, time: snapshot.air?.time)
            source(.weather, time: snapshot.weather?.time)
            source(.space, time: snapshot.currentKp(at: store.now)?.time)
        }
    }
    private func airHours(forecast: Bool, count: Int) -> [Hour] {
        let start = forecast ? store.now.addingTimeInterval(-3600) : store.now.addingTimeInterval(-86400)
        let end = forecast ? store.now.addingTimeInterval(Double(count) * 3600) : store.now
        return (snapshot.air?.hours ?? []).filter { $0.time >= start && $0.time <= end }
    }
    private var air: some View {
        Group {
            aqiHero
            Text(t("Данные характеризуют территорию, а не конкретную улицу. Разрешение модели — около 45 км.")).font(.caption).foregroundStyle(.secondary)
            advice(.air)
            Picker("", selection: $airForecast) {
                Text(t("Сутки")).tag(false)
                Text(t("Прогноз") + " · " + t("5 дней")).tag(true)
            }.pickerStyle(.segmented).labelsHidden()
            TimelineChart(values: airHours(forecast: airForecast, count: 120).map { ($0.time, $0.aqi) }, unit: "US AQI", days: airForecast, now: store.now)
            LazyVGrid(columns: columns, spacing: 10) {
                tile("PM2.5", value: number(snapshot.air?.pm25, 1), unit: "µg/m³")
                tile("PM10", value: number(snapshot.air?.pm10, 1), unit: "µg/m³")
                tile("Пыль", value: number(snapshot.air?.dust, 1), unit: "µg/m³")
                tile("NO₂", value: number(snapshot.air?.no2, 1), unit: "µg/m³")
                tile("SO₂", value: number(snapshot.air?.so2, 1), unit: "µg/m³")
                tile("CO", value: number(snapshot.air?.co, 1), unit: "µg/m³")
                tile("O₃", value: number(snapshot.air?.ozone, 1), unit: "µg/m³")
            }
            source(.air, time: snapshot.air?.time)
        }
    }
    private var weather: some View {
        Group {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(number(snapshot.weather?.temperature, 1) + "°").font(.system(size: 52, weight: .medium, design: .rounded))
                    Text(t(WeatherCode.title(snapshot.weather?.code))).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: WeatherCode.symbol(snapshot.weather?.code)).symbolRenderingMode(.multicolor).font(.system(size: 54))
            }
            if weatherPeriod == 0 { advice(.weather) }
            Picker("", selection: $weatherPeriod) {
                Text(t("Сутки")).tag(0); Text(t("7 дней")).tag(1); Text(t("16 дней")).tag(2); Text(t("История 30 дней")).tag(3)
            }.pickerStyle(.segmented).labelsHidden()
            if weatherPeriod == 0 {
                let hours = (snapshot.weather?.hours ?? []).filter { $0.time >= store.now.addingTimeInterval(-3600) && $0.time <= store.now.addingTimeInterval(86400) }
                TimelineChart(values: hours.map { ($0.time, $0.temperature) }, unit: "°C", now: store.now)
                ForEach(hours.prefix(12)) { hour in
                    HStack {
                        Text(Tashkent.date(hour.time, format: "HH:mm")).foregroundStyle(.secondary)
                        Spacer()
                        Text(number(hour.temperature, 1) + " °C").monospacedDigit()
                        Text(number(hour.precipitationProbability) + " %").foregroundStyle(.secondary).frame(width: 60, alignment: .trailing)
                    }.font(.system(size: 12))
                }
            } else {
                let days = weatherDays
                heading(weatherPeriod == 3 ? "Архив модельных данных" : "Прогноз")
                TimelineChart(values: days.map { ($0.time, $0.mean) }, unit: "°C", days: true)
                if weatherPeriod == 3 {
                    Text(t("История за 30 завершённых дней. Это модельный архив, не измерения метеостанции.")).font(.caption).foregroundStyle(.secondary)
                    let rainfall = days.compactMap(\.precipitation)
                    HStack {
                        Text(t("Осадки")); Spacer()
                        Text(number(rainfall.isEmpty ? nil : rainfall.reduce(0, +), 1) + " " + t("мм"))
                    }.font(.caption)
                }
                ForEach(days) { day in
                    HStack(spacing: 10) {
                        Text(Tashkent.date(day.time, format: "dd.MM")).frame(width: 46, alignment: .leading)
                        Image(systemName: WeatherCode.symbol(day.code)).symbolRenderingMode(.multicolor).frame(width: 22).accessibilityLabel(t(WeatherCode.title(day.code)))
                        Spacer()
                        Text(number(day.minimum) + "°").foregroundStyle(.secondary).frame(width: 42, alignment: .trailing)
                        Text(number(day.maximum) + "°").frame(width: 42, alignment: .trailing)
                        Text(number(day.precipitation, 1) + " " + t("мм")).foregroundStyle(.secondary).frame(width: 67, alignment: .trailing)
                    }.font(.system(size: 12)).monospacedDigit()
                }
            }
            if weatherPeriod != 3 {
                LazyVGrid(columns: columns, spacing: 10) {
                    tile("Ощущается", value: number(snapshot.weather?.apparent, 1), unit: "°C")
                    tile("Влажность", value: number(snapshot.weather?.humidity), unit: "%")
                    tile("Давление", value: number(snapshot.weather?.pressure), unit: "hPa")
                    tile("Ветер", value: number(snapshot.weather?.wind, 1), unit: t("м/с"))
                    tile("Порывы", value: number(snapshot.weather?.gusts, 1), unit: t("м/с"))
                    tile("Осадки", value: number(snapshot.weather?.precipitation, 1), unit: t("мм"))
                    tile("Облачность", value: number(snapshot.weather?.clouds), unit: "%")
                    tile("Видимость", value: number(snapshot.currentHour(at: store.now)?.visibility.map { $0 / 1000 }, 1), unit: t("км"))
                }
            }
            source(weatherPeriod == 3 ? .history : .weather, time: weatherPeriod == 3 ? weatherDays.last?.time : snapshot.weather?.time)
        }
    }
    private var weatherDays: [Day] {
        if weatherPeriod == 3 {
            let today = Tashkent.calendar.startOfDay(for: store.now)
            let start = Tashkent.calendar.date(byAdding: .day, value: -30, to: today)!
            return snapshot.history.filter { $0.time >= start && $0.time < today }
        }
        let today = Tashkent.calendar.startOfDay(for: store.now)
        return Array((snapshot.weather?.days ?? []).filter { $0.time >= today }.prefix(weatherPeriod == 1 ? 7 : 16))
    }
    private var sun: some View {
        Group {
            heading("Солнце", subtitle: "Ташкент")
            let today = snapshot.weather?.days.first { Tashkent.calendar.isDate($0.time, inSameDayAs: store.now) }
            LazyVGrid(columns: columns, spacing: 10) {
                tile("УФ-индекс", value: number(snapshot.value(.uv, at: store.now), 1), unit: "UV", symbol: "sun.max")
                tile("Максимальный УФ", value: number(today?.uv, 1), unit: "UV")
                tile("Восход", value: today?.sunrise.map { Tashkent.date($0, format: "HH:mm") } ?? "—", unit: "", symbol: "sunrise")
                tile("Закат", value: today?.sunset.map { Tashkent.date($0, format: "HH:mm") } ?? "—", unit: "", symbol: "sunset")
                tile("Длина дня", value: today?.daylight.map { String(format: "%d:%02d", Int($0) / 3600, Int($0) % 3600 / 60) } ?? "—", unit: t("ч"))
                tile("Излучение", value: number(snapshot.currentHour(at: store.now)?.radiation), unit: "W/m²")
            }
            Text(t("Солнечное излучение — среднее за предыдущий час.")).font(.caption).foregroundStyle(.secondary)
            source(.weather, time: snapshot.currentHour(at: store.now)?.time)
            Divider()
            DisclosureGroup(isExpanded: $spaceExpanded) {
                VStack(alignment: .leading, spacing: 16) { space }.padding(.top, 12)
            } label: { heading("Космическая погода") }
            .id("space")
        }
    }
    private var space: some View {
        Group {
            Text(t("Показатели Kp и вспышек глобальные; это не локальные измерения над Ташкентом.")).font(.caption).foregroundStyle(.secondary)
            let kp = snapshot.currentKp(at: store.now)
            tile("Геомагнитная активность", value: number(kp?.value, 2), unit: "Kp", symbol: "waveform.path")
            if let kp { Text(t(kp.kind == .observed ? "Наблюдение" : "Оценка") + " · " + Tashkent.date(kp.time)).font(.caption).foregroundStyle(.secondary) }
            heading("Наблюдения и оценки")
            let past = snapshot.space.filter { $0.kind != .predicted && $0.time <= store.now && $0.time >= store.now.addingTimeInterval(-86400) }
            TimelineChart(values: past.map { ($0.time, Optional($0.value)) }, unit: "Kp")
            heading("Прогноз")
            let forecast = snapshot.space.filter { $0.kind == .predicted && $0.time > store.now }
            TimelineChart(values: forecast.map { ($0.time, Optional($0.value)) }, unit: "Kp", days: true)
            source(.space, time: kp?.time)
            heading("Солнечные вспышки", subtitle: "Последние 7 дней")
            if snapshot.flares.isEmpty { Text(t(snapshot.fetched[.flares] == nil ? "Нет данных" : "Вспышек в ответе источника нет")).font(.caption).foregroundStyle(.secondary) }
            ForEach(Array(snapshot.flares.prefix(8))) { flare in
                HStack { Text(flare.classification).fontWeight(.medium); Spacer(); Text(Tashkent.date(flare.time)).foregroundStyle(.secondary) }.font(.system(size: 12))
            }
            source(.flares, time: snapshot.flares.first?.time)
        }
    }
    private var sourceProblems: some View {
        DisclosureGroup(t("Часть источников недоступна")) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Feed.allCases, id: \.self) { feed in
                    if let message = store.errors[feed] { Text(feed.source + ": " + message).textSelection(.enabled) }
                }
            }.font(.caption).frame(maxWidth: .infinity, alignment: .leading)
        }.font(.caption).foregroundStyle(.orange)
    }
    private var dailySummarySettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(t("Ежедневная сводка"), isOn: Binding(get: { store.preferences.summary }, set: { store.enableSummary($0) }))
            Text(t("Температура, осадки и качество воздуха каждый день в выбранное время.")).font(.caption).foregroundStyle(.secondary)
            HStack {
                Text(t("Время по Ташкенту")).font(.caption)
                Spacer()
                Picker(t("Часы"), selection: $store.preferences.summaryHour) { ForEach(0..<24) { Text(String(format: "%02d", $0)).tag($0) } }.frame(width: 65).labelsHidden()
                Text(":")
                Picker(t("Минуты"), selection: $store.preferences.summaryMinute) { ForEach(0..<60) { Text(String(format: "%02d", $0)).tag($0) } }.frame(width: 65).labelsHidden()
            }
            Text(t("Пример уведомления по текущим данным")).font(.caption).foregroundStyle(.secondary)
            Text(store.summaryBody ?? t("Нет свежих данных для сводки"))
                .font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            Button(t("Проверить уведомление")) { Task { await store.testSummary() } }
                .disabled(store.loading)
        }
    }
    private var settings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heading("Настройки")
                Picker(t("Язык"), selection: $store.preferences.language) { ForEach(Language.allCases) { Text($0.title).tag($0) } }
                Picker(t("Строка меню"), selection: $store.preferences.menuMetric) { ForEach(Metric.allCases) { Text(t($0.title)).tag($0) } }
                Toggle(t("Автозапуск"), isOn: Binding(get: { store.loginEnabled }, set: { store.setLogin($0) }))
                Divider()
                heading("Уведомления")
                Text(t("Уведомления работают, пока TashAir запущен и Mac не спит. Пропущенные сводки не повторяются.")).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text(t(store.notificationPermission ? "Разрешено" : "Нет разрешения")).font(.caption)
                    Spacer()
                    Button(t("Разрешить уведомления")) { Task { _ = await store.authorize() } }
                }
                dailySummarySettings
                Divider()
                ForEach(Array(store.preferences.rules.enumerated()), id: \.element.id) { index, rule in
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(t(rule.id == "heat" ? "Высокая температура" : rule.id == "cold" ? "Низкая температура" : rule.metric.title), isOn: Binding(get: { store.preferences.rules[index].enabled }, set: { store.enableRule(index, enabled: $0) }))
                        HStack {
                            Text(t(rule.below ? "Ниже или равно" : "Выше или равно")).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            TextField("", value: $store.preferences.rules[index].threshold, format: .number).frame(width: 65).textFieldStyle(.roundedBorder)
                            Text(rule.metric.unit).font(.caption).frame(width: 48, alignment: .leading)
                        }
                    }
                }
                Button(t("Открыть настройки macOS")) { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!) }
                Divider()
                heading("Источники")
                Link("Open-Meteo · CAMS Global (Copernicus)", destination: URL(string: "https://open-meteo.com/en/docs/air-quality-api")!)
                Link("NOAA · Space Weather Prediction Center", destination: URL(string: "https://www.swpc.noaa.gov/products-and-data")!)
                Link("CC BY 4.0 · Open-Meteo", destination: URL(string: "https://open-meteo.com/en/terms")!)
                Divider()
                heading("О программе")
                Text("TashAir 0.1.0 · MIT").font(.caption)
                Text(t("Без регистрации, рекламы и аналитики. Настройки и кэш хранятся на вашем Mac.")).font(.caption).foregroundStyle(.secondary)
                Button(t("Завершить TashAir")) { NSApp.terminate(nil) }
            }.padding(20)
        }.font(.system(size: 12))
    }
}
