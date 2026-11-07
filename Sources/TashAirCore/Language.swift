import Foundation

public enum Language: String, Codable, CaseIterable, Sendable, Identifiable {
    case ru, uz
    public var id: String { rawValue }
    public var title: String { self == .ru ? "Русский" : "O‘zbekcha" }
    public static var system: Language { Locale.preferredLanguages.first?.hasPrefix("uz") == true ? .uz : .ru }
    public func text(_ key: String) -> String { self == .uz ? Self.uzbek[key] ?? key : key }
    public static let uzbek: [String: String] = [
        "Ташкент": "Toshkent", "Обзор": "Umumiy", "Воздух": "Havo", "Погода": "Ob-havo", "Солнце": "Quyosh",
        "Космическая погода": "Kosmik ob-havo", "Настройки": "Sozlamalar", "Готово": "Tayyor", "Обновить": "Yangilash",
        "Качество воздуха": "Havo sifati", "Температура": "Harorat", "УФ-индекс": "UV indeksi", "Геомагнитная активность": "Geomagnit faollik",
        "Хорошее": "Yaxshi", "Умеренное": "O‘rtacha", "Вредно для чувствительных групп": "Sezgir guruhlar uchun zararli",
        "Вредное": "Zararli", "Очень вредное": "Juda zararli", "Опасное": "Xavfli",
        "Ясно": "Ochiq", "Переменная облачность": "Qisman bulutli", "Пасмурно": "Bulutli", "Туман": "Tuman",
        "Дождь": "Yomg‘ir", "Снег": "Qor", "Ливень": "Jala", "Снегопад": "Kuchli qor", "Гроза": "Momaqaldiroq",
        "Нет данных": "Ma’lumot yo‘q", "Загрузка…": "Yuklanmoqda…", "Сохранённые данные": "Saqlangan ma’lumotlar",
        "Модельная оценка": "Model bahosi", "Глобальные показатели": "Global ko‘rsatkichlar", "Данные": "Ma’lumotlar",
        "Проверено": "Tekshirildi", "Время данных": "Ma’lumot vaqti", "Источник": "Manba", "Источники": "Manbalar",
        "Сейчас": "Hozir", "Сутки": "Sutka", "5 дней": "5 kun", "7 дней": "7 kun", "16 дней": "16 kun",
        "История 30 дней": "30 kunlik tarix", "Архив модельных данных": "Model ma’lumotlari arxivi",
        "Прогноз": "Prognoz", "История": "Tarix", "Оценка": "Baho", "Наблюдение": "Kuzatuv",
        "Ощущается": "His etiladi", "Влажность": "Namlik", "Давление": "Bosim", "Ветер": "Shamol",
        "Порывы": "Shamol kuchayishi", "Осадки": "Yog‘in", "Облачность": "Bulutlilik", "Видимость": "Ko‘rinish",
        "Пыль": "Chang", "Восход": "Quyosh chiqishi", "Закат": "Quyosh botishi", "Длина дня": "Kun davomiyligi",
        "Излучение": "Quyosh nurlanishi", "Максимальный УФ": "Eng yuqori UV", "Солнечные вспышки": "Quyosh chaqnashlari",
        "Вспышек в ответе источника нет": "Manba javobida chaqnashlar yo‘q", "Последние 7 дней": "So‘nggi 7 kun",
        "Язык": "Til", "Строка меню": "Menyu satri", "Показатель": "Ko‘rsatkich", "Автозапуск": "Avtomatik ishga tushirish",
        "Уведомления": "Bildirishnomalar", "Ежедневная сводка": "Kunlik xulosa", "Время по Ташкенту": "Toshkent vaqti",
        "Порог": "Chegara", "Ниже или равно": "Past yoki teng", "Выше или равно": "Yuqori yoki teng",
        "Высокая температура": "Yuqori harorat", "Низкая температура": "Past harorat", "Разрешить уведомления": "Bildirishnomalarga ruxsat berish",
        "Разрешено": "Ruxsat berilgan", "Нет разрешения": "Ruxsat yo‘q", "Открыть настройки macOS": "macOS sozlamalarini ochish",
        "Порог достигнут": "Chegaraga yetdi", "Сводка по Ташкенту": "Toshkent bo‘yicha xulosa",
        "Проверка сети не удалась": "Tarmoq tekshiruvi muvaffaqiyatsiz", "Часть источников недоступна": "Ayrim manbalar mavjud emas",
        "О программе": "Dastur haqida", "Завершить TashAir": "TashAir’dan chiqish", "Сбросить кэш": "Keshni tozalash",
        "Нативная экологическая сводка": "Tabiiy muhit ko‘rsatkichlari", "Световой день": "Yorug‘ kun",
        "Данные характеризуют территорию, а не конкретную улицу. Разрешение модели — около 45 км.": "Ma’lumotlar aniq ko‘chani emas, hududni tavsiflaydi. Model aniqligi taxminan 45 km.",
        "Показатели Kp и вспышек глобальные; это не локальные измерения над Ташкентом.": "Kp va chaqnashlar global ko‘rsatkichlar; ular Toshkent ustidagi mahalliy o‘lchovlar emas.",
        "Уведомления работают, пока TashAir запущен и Mac не спит. Пропущенные сводки не повторяются.": "Bildirishnomalar TashAir ishlaganda va Mac uyg‘oq bo‘lganda keladi. O‘tkazib yuborilgan xulosalar takrorlanmaydi.",
        "История за 30 завершённых дней. Это модельный архив, не измерения метеостанции.": "Oldingi 30 to‘liq kun tarixi. Bu meteostansiya o‘lchovlari emas, model arxivi.",
        "Без регистрации, рекламы и аналитики. Настройки и кэш хранятся на вашем Mac.": "Ro‘yxatdan o‘tish, reklama va tahlil yo‘q. Sozlamalar va kesh Mac’da saqlanadi.",
        "Нет свежих данных для сводки": "Xulosa uchun yangi ma’lumot yo‘q", "Ошибка сохранения": "Saqlash xatosi",
        "Версия": "Versiya", "Модель": "Model", "Настроить виджет": "Vidjetni sozlash", "Следующее обновление определяет macOS": "Keyingi yangilanishni macOS belgilaydi",
        "Солнечное излучение — среднее за предыдущий час.": "Quyosh nurlanishi — oldingi soatning o‘rtacha qiymati.",
        "ч": "soat", "мин": "daq", "м/с": "m/s", "мм": "mm", "км": "km", "Открыть приложение": "Dasturni ochish",
        "Сводка": "Xulosa", "Наблюдения и оценки": "Kuzatuvlar va baholar", "Состояние источников": "Manbalar holati",
        "Как в macOS": "macOS bilan bir xil", "Ташкент · воздух, погода и солнце": "Toshkent · havo, ob-havo va quyosh",
        "Воздух, погода и солнце": "Havo, ob-havo va quyosh", "Глобально": "Global",
        "Солнечная активность": "Quyosh faolligi",
        "Шкала US AQI": "US AQI shkalasi",
        "Осадки сейчас": "Hozirgi yog‘in", "Часы": "Soat", "Минуты": "Daqiqa",
        "Температура, осадки и качество воздуха каждый день в выбранное время.": "Har kuni tanlangan vaqtda harorat, yog‘in va havo sifati.",
        "Пример уведомления по текущим данным": "Joriy ma’lumotlar bo‘yicha bildirishnoma namunasi",
        "Проверить уведомление": "Bildirishnomani tekshirish", "Проверка сводки": "Xulosani tekshirish"
    ]
}
