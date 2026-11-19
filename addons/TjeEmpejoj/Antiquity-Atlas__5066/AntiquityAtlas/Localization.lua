AntiquityAtlas = AntiquityAtlas or {}
local A = AntiquityAtlas
local english = {
    ["Источник пока не указан"] = "Source not specified",
    ["Любая зона"] = "Any zone",
    ["Поля сражений"] = "Battlegrounds",
    ["Зона неизвестна"] = "Unknown zone",
    ["|cE8C563Где получить:|r "] = "|cE8C563Lead source:|r ",
    ["|cE8C563Раскопки:|r "] = "|cE8C563Excavate in:|r ",
    ["ЛКМ — источник и метка · ПКМ — раскопки"] = "Left click: source waypoint · Right click: dig zone",
    ["Antiquity Atlas: открыта зона. Точная точка источника не определена: "] = "Antiquity Atlas: zone opened. Exact source location unavailable: ",
    ["Antiquity Atlas: источник выделен мигающей иконкой — "] = "Antiquity Atlas: blinking source marker: ",
    ["Antiquity Atlas: отдельная карта этой зоны недоступна. Источник: "] = "Antiquity Atlas: no separate map for this zone. Source: ",
    ["Antiquity Atlas: не удалось открыть выбранную карту."] = "Antiquity Atlas: unable to open selected map.",
    [" · Собрано: "] = " · Completed: ",
    ["Части: %d/%d\nЗацепок: %d"] = "Pieces: %d/%d\nLeads: %d",
    ["|cA0FFAFВ+З|r"] = "|cA0FFAFD+L|r",
    ["|cA0FFAFВык.|r"] = "|cA0FFAFDug|r",
    ["|c86E8FFЕсть|r"] = "|c86E8FFHave|r",
    ["|cDDDDDDНет|r"] = "|cDDDDDDNeed|r",
    ["Наград: %d   ·   Зацепок: %d"] = "Rewards: %d   ·   Leads: %d",
    ["Награды · зацепки · мифики"] = "Rewards · Leads · Mythics",
    ["Обновить"] = "Refresh",
    ["Мои зацепки"] = "My leads",
    ["Все награды"] = "All rewards",
    ["Мифики"] = "Mythics",
    ["Выкопанное"] = "Recovered",
    ["ПОИСК"] = "SEARCH",
    ["По названию"] = "Name",
    ["Редкость: сначала высокая"] = "Quality: highest first",
    ["Скоро истекают"] = "Expiring first",
    ["Прогресс сборки"] = "Assembly progress",
    ["Любая редкость"] = "Any quality",
    ["Обычная"] = "Normal",
    ["Необычная"] = "Fine",
    ["Редкая"] = "Superior",
    ["Эпическая"] = "Epic",
    ["Легендарная"] = "Legendary",
    ["Мифическая"] = "Mythic",
    ["Любой статус"] = "Any status",
    ["Есть зацепки"] = "Have leads",
    ["Ни разу не выкопано"] = "Never recovered",
    ["Награда ещё не собрана"] = "Not completed",
    ["Все типы"] = "All types",
    ["Ничего не найдено. Измените поиск или фильтры."] = "No matches. Change your search or filters.",
    ["3D выбранной награды"] = "Preview selected reward",
    ["|cA0FFAFВык.|r — выкопано   |c86E8FFЕсть|r — зацепка есть   |cDDDDDDНет|r — нужна зацепка"] = "|cA0FFAFDug|r — recovered   |c86E8FFHave|r — lead acquired   |cDDDDDDNeed|r — lead missing",
    ["Предпросмотр награды"] = "Reward preview",
    ["Вернуться в каталог"] = "Return to catalog",
    ["Antiquity Atlas: ошибка предпросмотра: "] = "Antiquity Atlas: preview error: ",
    ["Открыть каталог древностей"] = "Open Antiquity Atlas",
    ["Источник пока не указан в базе Lead List"] = "Source not yet listed in Lead List",
    ["Мифик"] = "Mythic",
    ["Составная награда"] = "Composite reward",
    ["Древность"] = "Antiquity",
    [" · %.1f дней"] = " · %.1f days",
    [" · срок не указан"] = " · no expiry listed",
    ["|c6ED9F5Зацепка есть"] = "|c6ED9F5Lead acquired",
    ["|c84D69AВыкопано для текущей сборки|r"] = "|c84D69ARecovered for current assembly|r",
    ["|cF2B872Нужна зацепка для новой сборки|r"] = "|cF2B872Need a lead for the next assembly|r",
    ["|cF2B872Зацепка не найдена|r"] = "|cF2B872Lead not acquired|r",
    ["Выкопано всего: %d"] = "Total recovered: %d",
}
function A.L(text)
    local language = A.language or (GetCVar and GetCVar("language.2")) or "en"
    if language == "ru" then return text end
    return english[text] or text
end
local sources = {
    ["Wood Nodes"] = "Древесина: сбор ресурсов",
    ["Ore Nodes"] = "Рудные жилы: сбор ресурсов",
    ["Treasure Chests"] = "Сундуки с сокровищами",
    ["Fishing"] = "Рыбалка", ["World Bosses"] = "Мировые боссы",
    ["Delve Bosses"] = "Боссы логов", ["Safeboxes"] = "Сейфы",
    ["Psijic Portals"] = "Порталы Псиджиков", ["Final Boss"] = "Последний босс",
    ["All bosses in"] = "Все боссы в", ["Final boss in"] = "Последний босс в",
    ["(Dungeon)"] = "(Подземелье)", ["(Trial)"] = "(Испытание)",
}
function A.LocalizeSource(text)
    if (A.language or (GetCVar and GetCVar("language.2"))) ~= "ru" then return text end
    if sources[text] then return sources[text] end
    for from, to in pairs(sources) do
        if text:sub(1, #from) == from then return to .. text:sub(#from + 1) end
    end
    return text
end
