import SwiftUI
import TashAirCore

struct AdviceView: View {
    let snapshot: EnvironmentSnapshot
    let errors: [Feed: String]
    let now: Date
    let language: Language
    /// nil shows both current air and weather guidance in the overview.
    var section: Feed? = nil
    private func text(_ ru: String, _ uz: String) -> String { language == .ru ? ru : uz }
    private var items: [Advice] {
        (section == nil || section == .air ? EnvironmentAdvice.air(snapshot, at: now, failed: errors[.air] != nil) : []) +
        (section == nil || section == .weather ? EnvironmentAdvice.weather(snapshot, at: now, failed: errors[.weather] != nil) : [])
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(text("Советы на сейчас", "Hozirgi maslahatlar"), systemImage: "lightbulb")
                .font(.system(size: 16, weight: .semibold))
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: item.symbol).foregroundStyle(.teal).frame(width: 22)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title(language)).font(.system(size: 12, weight: .semibold))
                        Text(item.body(language)).font(.system(size: 12)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }.accessibilityElement(children: .combine)
            }
            if section == .weather && items.isEmpty {
                Text(text("По доступным текущим показателям специальных погодных советов нет. Перед выходом проверьте прогноз.", "Mavjud joriy ko‘rsatkichlar bo‘yicha maxsus ob-havo maslahati yo‘q. Chiqishdan oldin prognozni tekshiring."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            DisclosureGroup(text("Как выбрать маску и откуда советы", "Niqob tanlash va maslahat manbalari")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(text("Пыль и дым: AQI 0–100 — обычно без респиратора; 101–150 — рассмотреть для чувствительных групп; 151–200 — рассмотреть всем; 201–300 — использовать при необходимом выходе; 301+ — отложить выход. Для частиц подходит N95 или FFP2.", "Chang va tutun: AQI 0–100 — odatda respiratorsiz; 101–150 — sezgir guruhlar ko‘rib chiqsin; 151–200 — hamma ko‘rib chiqsin; 201–300 — zarur chiqishda ishlating; 301+ — chiqishni kechiktiring. Zarrachalar uchun N95 yoki FFP2 mos."))
                    Text(text("Для пыли и дыма выбирайте сертифицированный N95 или FFP2 с плотным прилеганием без зазоров. Борода мешает герметичности. Тканевые и хирургические маски не заменяют респиратор от мелких частиц.", "Chang va tutun uchun tirqishsiz, yuzga zich yopishadigan sertifikatlangan N95 yoki FFP2 tanlang. Soqol zichlikka xalaqit beradi. Mato va jarrohlik niqoblari mayda zarrachalar respiratorini almashtirmaydi."))
                    Text(text("Эти респираторы не защищают от озона, CO, NO₂ и других газов. Общий AQI не определяет, какая примесь преобладает. Более высокий класс маски не делает загрязнённый воздух безопасным.", "Bu respiratorlar ozon, CO, NO₂ va boshqa gazlardan himoya qilmaydi. Umumiy AQI qaysi modda ustunligini ko‘rsatmaydi. Yuqoriroq niqob sinfi iflos havoni xavfsiz qilmaydi."))
                    Text(text("Детям нужен подходящий размер; взрослый респиратор может не прилегать. При болезнях сердца или лёгких обсудите ношение с врачом. Если в респираторе трудно дышать, перейдите в место с чистым воздухом.", "Bolalarga mos o‘lcham kerak; kattalar respiratori zich yopishmasligi mumkin. Yurak yoki o‘pka kasalligida taqishni shifokor bilan muhokama qiling. Respiratorda nafas olish qiyinlashsa, havosi toza joyga o‘ting."))
                    Text(text("Общие подсказки по модельным данным, не медицинское назначение и не официальное предупреждение. Погодные пороги приложения: ощущается ≥30/35 °C, ≤0/−10 °C, ветер или порывы ≥15 м/с; УФ ≥3/8. При отсутствии ощущаемой температуры используется обычная.", "Model ma’lumotlariga asoslangan umumiy maslahatlar, tibbiy ko‘rsatma yoki rasmiy ogohlantirish emas. Dastur chegaralari: his etiladigan harorat ≥30/35 °C, ≤0/−10 °C, shamol yoki kuchayishi ≥15 m/s; UV ≥3/8. His etiladigan harorat yo‘q bo‘lsa, oddiy harorat ishlatiladi."))
                    Link("AirNow · AQI", destination: URL(string: "https://www.airnow.gov/aqi/aqi-basics/")!)
                    Link("CDC · N95", destination: URL(string: "https://www.cdc.gov/niosh/bulletin/2023/wildfire-smoke.html")!)
                    Link("WHO · N95 / FFP2", destination: URL(string: "https://www.who.int/news-room/questions-and-answers/item/air-pollution-personal-interventions-and-risk-communication")!)
                    Link("EPA · UV", destination: URL(string: "https://www.epa.gov/sunsafety/uv-index-scale-0")!)
                    Link("NWS · Heat", destination: URL(string: "https://www.weather.gov/safety/heat-during")!)
                    Link("NWS · Cold", destination: URL(string: "https://www.weather.gov/safety/cold-during")!)
                }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 8)
            }.font(.system(size: 11))
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }
}
