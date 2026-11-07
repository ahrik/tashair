import Foundation

/// General planning guidance, not a diagnosis or an official weather warning.
public enum Advice: String, CaseIterable, Sendable, Identifiable {
    case airGood, airModerate, airSensitive, airUnhealthy, airVeryUnhealthy, airHazardous
    case maskRoutine, maskSensitive, maskConsider, maskUse, maskAvoid
    case airUnavailable, weatherUnavailable, heat, extremeHeat, cold, severeCold, rain, snow, storm, wind, uv, extremeUV
    public var id: String { rawValue }
    public var symbol: String {
        switch self {
        case .maskRoutine, .maskSensitive, .maskConsider, .maskUse, .maskAvoid: "facemask"
        case .heat, .extremeHeat: "thermometer.sun"
        case .cold, .severeCold: "thermometer.snowflake"
        case .rain: "umbrella"
        case .snow: "snowflake"
        case .storm: "cloud.bolt.rain"
        case .wind: "wind"
        case .uv, .extremeUV: "sun.max"
        case .airUnavailable, .weatherUnavailable: "clock.badge.exclamationmark"
        default: "aqi.medium"
        }
    }
    public func title(_ language: Language) -> String { language == .ru ? copy.0 : copy.1 }
    public func body(_ language: Language) -> String { language == .ru ? copy.2 : copy.3 }
    private var copy: (String, String, String, String) {
        switch self {
        case .airGood: ("Воздух · хорошо", "Havo · yaxshi", "По качеству воздуха обычные прогулки и занятия на улице допустимы.", "Havo sifati odatiy sayr va ochiq havodagi mashg‘ulotlarga mos.")
        case .airModerate: ("Воздух · умеренно", "Havo · o‘rtacha", "Большинство людей могут заниматься на улице. При повышенной чувствительности сократите нагрузку, если появляется дискомфорт.", "Ko‘pchilik ochiq havoda mashq qilishi mumkin. Sezgir bo‘lsangiz, noqulaylik paydo bo‘lganda yuklamani kamaytiring.")
        case .airSensitive: ("Воздух · берегите чувствительные группы", "Havo · sezgir guruhlarni asrang", "Детям, пожилым и людям с болезнями сердца или лёгких стоит сократить длительные и интенсивные занятия на улице.", "Bolalar, keksalar, yurak yoki o‘pka kasalligi borlar uzoq va jadal tashqi mashg‘ulotlarni qisqartirsin.")
        case .airUnhealthy: ("Воздух · сократите нагрузку", "Havo · yuklamani kamaytiring", "Всем стоит сократить длительную и интенсивную нагрузку на улице. Чувствительным группам лучше перенести занятия в помещение.", "Hamma uzoq va jadal tashqi yuklamani kamaytirsin. Sezgir guruhlar mashg‘ulotlarni binoga ko‘chirgani ma’qul.")
        case .airVeryUnhealthy: ("Воздух · оставайтесь в помещении", "Havo · bino ichida qoling", "Избегайте физической нагрузки на улице; чувствительным группам лучше оставаться внутри. При пыли или дыме используйте очиститель с HEPA и держите окна закрытыми, если внутри не жарко.", "Tashqarida jismoniy yuklamadan saqlaning; sezgir guruhlar ichkarida qolsin. Chang yoki tutunda HEPA tozalagichdan foydalaning, ichkarisi issiq bo‘lmasa derazalarni yoping.")
        case .airHazardous: ("Воздух · опасный уровень", "Havo · xavfli daraja", "Всем следует избегать физической активности на улице. Оставайтесь в помещении с более чистым воздухом и следите за сообщениями местных служб.", "Hamma tashqarida jismoniy faollikdan saqlansin. Havosi tozaroq binoda qoling va mahalliy xizmatlar xabarlarini kuzating.")
        case .maskRoutine: ("Маска · обычно не нужна", "Niqob · odatda kerak emas", "При AQI до 100 респиратор обычно не нужен только из-за индекса. Учитывайте видимый дым, пыль, самочувствие и рекомендации врача.", "AQI 100 gacha bo‘lsa, faqat indeks sabab respirator odatda kerak emas. Ko‘rinadigan tutun, chang, holatingiz va shifokor tavsiyalarini hisobga oling.")
        case .maskSensitive: ("Маска · для чувствительных групп", "Niqob · sezgir guruhlar uchun", "AQI 101–150: при пыли или дыме чувствительным людям стоит рассмотреть плотно прилегающий N95 или FFP2 для необходимого выхода.", "AQI 101–150: chang yoki tutunda sezgir kishilar zarur chiqish uchun yuzga zich yopishadigan N95 yoki FFP2 ni ko‘rib chiqsin.")
        case .maskConsider: ("Маска · рассмотрите респиратор", "Niqob · respiratorni ko‘rib chiqing", "AQI 151–200: при пыли или дыме всем стоит рассмотреть N95 или FFP2 для необходимого выхода. Сократите время на улице.", "AQI 151–200: chang yoki tutunda zarur chiqish uchun hamma N95 yoki FFP2 ni ko‘rib chiqsin. Tashqaridagi vaqtni qisqartiring.")
        case .maskUse: ("Маска · при необходимом выходе", "Niqob · zarur chiqishda", "AQI 201–300: избегайте выходов; если выйти необходимо и есть пыль или дым, используйте плотно прилегающий N95 или FFP2.", "AQI 201–300: tashqariga chiqishdan saqlaning; chiqish zarur bo‘lsa va chang yoki tutun bo‘lsa, zich N95 yoki FFP2 dan foydalaning.")
        case .maskAvoid: ("Маска не делает выход безопасным", "Niqob chiqishni xavfsiz qilmaydi", "AQI выше 300: отложите выход. При неизбежном выходе в пыль или дым используйте N95 или FFP2 и сведите время снаружи к минимуму.", "AQI 300 dan yuqori: chiqishni kechiktiring. Chang yoki tutunda chiqish muqarrar bo‘lsa, N95 yoki FFP2 ishlating va tashqarida juda qisqa qoling.")
        case .airUnavailable: ("Советы по воздуху недоступны", "Havo bo‘yicha maslahat mavjud emas", "Нет актуальной оценки воздуха. Обновите данные; сохранённые значения не используются для текущих советов.", "Havoning dolzarb bahosi yo‘q. Ma’lumotni yangilang; saqlangan qiymatlar joriy maslahat uchun ishlatilmaydi.")
        case .weatherUnavailable: ("Советы по погоде недоступны", "Ob-havo maslahati mavjud emas", "Нет актуальных показателей погоды. Обновите данные перед планированием выхода.", "Dolzarb ob-havo ko‘rsatkichlari yo‘q. Chiqishni rejalashdan oldin ma’lumotni yangilang.")
        case .heat: ("Жарко · вода и тень", "Issiq · suv va soya", "Пейте воду, отдыхайте в тени или прохладном помещении. Перенесите интенсивные занятия на более прохладное время.", "Suv iching, soyada yoki salqin binoda dam oling. Jadal mashg‘ulotlarni salqinroq vaqtga ko‘chiring.")
        case .extremeHeat: ("Сильная жара · сократите выходы", "Kuchli issiq · chiqishni kamaytiring", "Проведите жаркие часы в прохладном помещении, избегайте нагрузки и регулярно пейте воду. Не оставляйте детей и животных в машине.", "Issiq soatlarni salqin binoda o‘tkazing, yuklamadan saqlaning va muntazam suv iching. Bola va hayvonlarni mashinada qoldirmang.")
        case .cold: ("Холодно · одевайтесь слоями", "Sovuq · qatlamlab kiyining", "Наденьте несколько слоёв одежды, шапку и перчатки. Сохраняйте одежду сухой, особенно при ветре и осадках.", "Qatlamlab kiyining, bosh kiyim va qo‘lqop taqing. Ayniqsa shamol va yog‘inda kiyimni quruq saqlang.")
        case .severeCold: ("Сильный холод · короткие выходы", "Kuchli sovuq · qisqa chiqishlar", "Сократите время на улице, закройте открытые участки кожи и делайте перерывы в тепле. Ветер усиливает потерю тепла.", "Tashqaridagi vaqtni qisqartiring, ochiq terini yoping va issiqda tanaffus qiling. Shamol issiqlik yo‘qotilishini kuchaytiradi.")
        case .rain: ("Осадки · защита от дождя", "Yog‘in · yomg‘irdan himoya", "Возьмите зонт или непромокаемую одежду и обувь. Будьте внимательны на мокрых поверхностях.", "Soyabon yoki suv o‘tkazmaydigan kiyim va poyabzal oling. Ho‘l joylarda ehtiyot bo‘ling.")
        case .snow: ("Снег или гололёд", "Qor yoki muzlama", "Выберите обувь с нескользящей подошвой, двигайтесь осторожно и заложите больше времени на дорогу.", "Sirpanmaydigan taglikli poyabzal tanlang, ehtiyot yuring va yo‘lga ko‘proq vaqt ajrating.")
        case .storm: ("Гроза · укройтесь в здании", "Momaqaldiroq · binoga kiring", "Отложите прогулку и укройтесь в капитальном здании или закрытом автомобиле. Деревья и открытые навесы не защищают от молнии.", "Sayrni kechiktiring, mustahkam bino yoki yopiq avtomobilga kiring. Daraxt va ochiq ayvon chaqmoqdan himoya qilmaydi.")
        case .wind: ("Сильный ветер", "Kuchli shamol", "Держитесь подальше от деревьев, рекламных щитов и незакреплённых предметов. Для дождя лучше непромокаемая одежда, чем зонт.", "Daraxtlar, reklama taxtalari va mahkamlanmagan buyumlardan uzoqroq turing. Yomg‘irda soyabondan ko‘ra suv o‘tkazmaydigan kiyim ma’qul.")
        case .uv: ("УФ · нужна защита от солнца", "UV · quyoshdan himoya kerak", "При УФ от 3 используйте тень, закрытую одежду, головной убор, очки и солнцезащитное средство SPF 30+ на открытой коже.", "UV 3 dan boshlab soya, yopiq kiyim, bosh kiyim, ko‘zoynak va ochiq teriga SPF 30+ himoya vositasidan foydalaning.")
        case .extremeUV: ("Очень высокий УФ", "Juda yuqori UV", "Сведите пребывание на прямом солнце к минимуму, особенно около полудня. Нужны тень, закрытая одежда, очки и SPF 30+.", "Ayniqsa tush atrofida bevosita quyoshda juda qisqa qoling. Soya, yopiq kiyim, ko‘zoynak va SPF 30+ kerak.")
        }
    }
}

public enum EnvironmentAdvice {
    public static func air(_ snapshot: EnvironmentSnapshot, at now: Date, failed: Bool = false) -> [Advice] {
        guard !failed, snapshot.isFresh(.air, at: now), let level = AirQuality.level(snapshot.air?.aqi) else { return [.airUnavailable] }
        switch level {
        case .good: return [.airGood, .maskRoutine]
        case .moderate: return [.airModerate, .maskRoutine]
        case .sensitive: return [.airSensitive, .maskSensitive]
        case .unhealthy: return [.airUnhealthy, .maskConsider]
        case .veryUnhealthy: return [.airVeryUnhealthy, .maskUse]
        case .hazardous: return [.airHazardous, .maskAvoid]
        }
    }
    public static func weather(_ snapshot: EnvironmentSnapshot, at now: Date, failed: Bool = false) -> [Advice] {
        guard !failed, snapshot.isFresh(.weather, at: now), let weather = snapshot.weather else { return [.weatherUnavailable] }
        func finite(_ value: Double?) -> Double? { value.flatMap { $0.isFinite ? $0 : nil } }
        var result: [Advice] = []
        let code = finite(weather.code)
        if let code, [95.0, 96, 99].contains(code) { result.append(.storm) }
        if max(finite(weather.wind) ?? 0, finite(weather.gusts) ?? 0) >= 15 { result.append(.wind) }
        if let temperature = finite(weather.apparent) ?? finite(weather.temperature) {
            if temperature >= 35 { result.append(.extremeHeat) }
            else if temperature >= 30 { result.append(.heat) }
            else if temperature <= -10 { result.append(.severeCold) }
            else if temperature <= 0 { result.append(.cold) }
        }
        if let code, [56.0, 57, 66, 67, 71, 73, 75, 77, 85, 86].contains(code) { result.append(.snow) }
        else if (finite(weather.precipitation) ?? 0) > 0 || code.map({ [51.0, 53, 55, 61, 63, 65, 80, 81, 82].contains($0) }) == true { result.append(.rain) }
        if let uv = finite(snapshot.currentHour(at: now)?.uv), uv >= 3 { result.append(uv >= 8 ? .extremeUV : .uv) }
        return result
    }
}
