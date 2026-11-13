-- locales/ru.lua
if GetCVar("language.2") ~= "ru" then return end

ZoneAchievements = ZoneAchievements or {}
ZoneAchievements.L = ZoneAchievements.L or {}

local ruStrings = {
    lockedZone = "Заблокированная зона",
    unknown = "Неизвестно",
    recentTag = "  |cFFD700[НОВОЕ]|r",
    completed = "|c00FF00Достижение выполнено!|r",
    progress = "Прогресс: |cFFFF00%d / %d|r",
    testTitle = "|c39DB92[ZA-Test] Перетащи меня!|r",
    dragMe = "Зажми левую кнопку мыши для переноса",
    -- Вкладки и история
    tabZone = "Зона",
    tabHistory = "История",
    historyTitle = "История активности (24ч)",
    justNow = "Только что",
    minutesAgo = "%d мин. назад",
    hoursAgo = "%d ч. назад",
    -- Особые испытания и разделители
    specialHeader = "——— Главные испытания ———",
    vetHeader = "——— Ветеранский режим ———",
    otherHeader = "——— Прочие достижения ———",
    vetKeywords = { "ветеран", "ветеранск" },
    tagVet = "|c9370DB[ВЕТ]|r ",
    tagSpeed = "|c00FFFF[СПИДРАН]|r ",
    tagNoDeath = "|cE6E6FA[НЕУМИРАЙКА]|r ",
    tagHM = "|cFF4500[ХМ]|r ",
    tagTrifecta = "|cFFD700[ТРИФЕКТА]|r ",
    tagMisfortune1 = "|cFFD700[1 НЕВЗГОДА]|r ",
    tagMisfortune2 = "|cFF8C00[2 НЕВЗГОДЫ]|r ",
    tagMisfortune3 = "|cFF0000[3 НЕВЗГОДЫ]|r ",
    menuSetVet = "Пометить: [Вет]",
    menuSetSpeed = "Пометить: [Спидран]",
    menuSetNoDeath = "Пометить: [Неумирайка]",
    menuSetHM = "Пометить: [ХМ]",
    menuSetTrifecta = "Пометить: [Трифекта]",
    menuSetMisfortune1 = "Пометить: [1 Невзгода]",
    menuSetMisfortune2 = "Пометить: [2 Невзгоды]",
    menuSetMisfortune3 = "Пометить: [3 Невзгоды]",
    menuClearTag = "Убрать особую метку",
}

for k, v in pairs(ruStrings) do
    ZoneAchievements.L[k] = v
end

ZO_CreateStringId("SI_BINDING_NAME_TOGGLE_ZONEACH_WINDOW", "Открыть/закрыть окно ZoneAchievements")