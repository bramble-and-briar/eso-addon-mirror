TamrielCalendar = TamrielCalendar or {}
local TC = TamrielCalendar

local ru = {
    days = {"Сандас", "Морндас", "Тирдас", "Миддас", "Турдас", "Фредас", "Лоредас"},
    shortDays = {"Сн", "Мн", "Тд", "Мд", "Тр", "Фр", "Лр"},
    months = {"Утренней звезды", "Восхода солнца", "Первоцвета", "Руки дождя", "Второго зерна", "Середины года", "Высокого солнца", "Последнего зерна", "Огня очага", "Начала морозов", "Заката солнца", "Вечерней звезды"},
    realMonths = {"Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"},
    signs = {"Ритуал", "Любовник", "Лорд", "Маг", "Тени", "Конь", "Ученик", "Воин", "Леди", "Башня", "Атронах", "Вор", "Змей"},
    moonPhases = {"Новолуние", "Растущий серп", "Первая четверть", "Растущая луна", "Полнолуние", "Убывающая луна", "Последняя четверть", "Убывающий серп"},
    yearSuffix = "год 2-й эры",
    monthPrefix = "Месяц",
    signPrefix = "Знак:",
    stripFormat = "%s, %d %s %d г. | %s | %02d:%02d",
    titleHoliday = "День праздника (Лор):",
    btnPrev = "Назад",
    btnNext = "Вперед",
    hNames = {
        nl = "Фестиваль Новой жизни",
        hd = "День Сердец (Сангвин)",
        aj = "Юбилей ESO",
        jd = "День Шута",
        zz = "День Зенитара",
        my = "Середина года (Пелинал)",
        wf = "Фестиваль Ведьм",
        ud = "День Воина (Неустрашимые)",
        ol = "Старая жизнь"
    }
}

for k, v in pairs(ru) do
    TC.L[k] = v
end

ZO_CreateStringId("SI_BINDING_NAME_TC_TOGGLE_UI", "Показать/Скрыть плашку")
ZO_CreateStringId("SI_BINDING_NAME_TC_TOGGLE_WINDOW", "Открыть большой календарь")

-- Settings Panel Strings (RU)
ZO_CreateStringId("SI_TC_SECTION_APPEARANCE", "Внешний вид плашки")
ZO_CreateStringId("SI_TC_AUTO_WIDTH_NAME", "Автоматическая ширина")
ZO_CreateStringId("SI_TC_AUTO_WIDTH_TIP", "Плашка сама подстраивает свою ширину под длину текста, чтобы слова никогда не обрезались.")
ZO_CreateStringId("SI_TC_STRIP_WIDTH_NAME", "Фиксированная ширина (px)")
ZO_CreateStringId("SI_TC_STRIP_WIDTH_TIP", "Работает, только если выключена автоматическая ширина.")
ZO_CreateStringId("SI_TC_STRIP_HEIGHT_NAME", "Высота плашки (px)")
ZO_CreateStringId("SI_TC_STRIP_ALPHA_NAME", "Прозрачность фона (%)")
ZO_CreateStringId("SI_TC_STRIP_LOCK_NAME", "Закрепить плашку")
ZO_CreateStringId("SI_TC_STRIP_LOCK_TIP", "Блокирует случайное перемещение плашки мышью.")

ZO_CreateStringId("SI_TC_SECTION_FONT", "Настройка шрифта и текста")
ZO_CreateStringId("SI_TC_TEXT_COLOR_NAME", "Цвет текста")
ZO_CreateStringId("SI_TC_TEXT_COLOR_TIP", "Выберите цвет текста на плашке.")
ZO_CreateStringId("SI_TC_FONT_FAMILY_NAME", "Гарнитура шрифта")
ZO_CreateStringId("SI_TC_FONT_SIZE_NAME", "Размер шрифта (px)")
ZO_CreateStringId("SI_TC_FONT_STYLE_NAME", "Стиль тени / обводки")

-- Font Dropdown Choices
ZO_CreateStringId("SI_TC_FONT_CHOICE_BOLD", "Системный Жирный (Univers Bold)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_REGULAR", "Системный Обычный (Univers Regular)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_MEDIUM", "Системный Средний (Univers Medium)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_GAME", "Игровой интерфейсный (Game UI)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_ANTIQUE", "Книжный / Свитки (Antique)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_HANDWRITTEN", "Рукописный / Записки (Handwritten)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_STONE", "Каменная плита / Заголовки (Stone Tablet)")

-- Shadow Dropdown Choices
ZO_CreateStringId("SI_TC_STYLE_CHOICE_SOFT", "Мягкая тень (Рекомендуется)")
ZO_CreateStringId("SI_TC_STYLE_CHOICE_HARD", "Четкая тень")
ZO_CreateStringId("SI_TC_STYLE_CHOICE_OUTLINE", "Контур (Outline)")
ZO_CreateStringId("SI_TC_STYLE_CHOICE_THIN", "Тонкая тень")
ZO_CreateStringId("SI_TC_STYLE_CHOICE_NONE", "Без тени")

-- Elements Toggles
ZO_CreateStringId("SI_TC_SECTION_ELEMENTS", "Отображаемые элементы")
ZO_CreateStringId("SI_TC_SHOW_WDAY_NAME", "День недели")
ZO_CreateStringId("SI_TC_SHOW_WDAY_TIP", "Показывать день недели (Сандас, Морндас...)")
ZO_CreateStringId("SI_TC_SHOW_DATE_NAME", "Число и месяц")
ZO_CreateStringId("SI_TC_SHOW_DATE_TIP", "Показывать число и месяц (14 Утренней звезды...)")
ZO_CreateStringId("SI_TC_SHOW_YEAR_NAME", "Год и эра")
ZO_CreateStringId("SI_TC_SHOW_YEAR_TIP", "Показывать год (582 год 2-й эры)")
ZO_CreateStringId("SI_TC_SHOW_SIGN_NAME", "Знак зодиака")
ZO_CreateStringId("SI_TC_SHOW_SIGN_TIP", "Показывать текущее созвездие (Знак: Ритуал...)")
ZO_CreateStringId("SI_TC_SHOW_TIME_NAME", "Время Тамриэля")
ZO_CreateStringId("SI_TC_SHOW_TIME_TIP", "Показывать игровое время (часы и минуты)")