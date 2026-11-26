AntiquityAtlas = AntiquityAtlas or {}
local A = AntiquityAtlas
local english = {
    ["Предпросмотр"] = "Preview",
    ["Редкость: по убыванию"] = "Quality: descending",
    ["Срок зацепки"] = "Lead expiry",
    ["Не собрано"] = "Not completed",
    ["Не выкопано"] = "Never recovered",
    ["Место получения"] = "Lead source",
    ["Область раскопок"] = "Excavation region",
    ["Управление"] = "Controls",
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
function A.IsRussian()
    return (A.language or (GetCVar and GetCVar("language.2")) or "en") == "ru"
end
function A.DisplayName(text)
    -- Format ESO grammatical names before displaying them, including RuESO's
    -- bilingual strings. Residual declension tags are not player-facing text.
    return (zo_strformat("<<C:1>>", text or ""):gsub("%^[%w{}%-]+", ""))
end
function A.ZoneName(id)
    -- RuESO 48 hooks GetZoneNameByIndex for its ru/en/ruen/enru preference.
    -- Use that public API instead of reading its private saved-variable data.
    local index = GetZoneIndex and GetZoneIndex(id)
    local name = index and index > 0 and GetZoneNameByIndex and GetZoneNameByIndex(index)
    if not name or name == "" then name = GetZoneNameById(id) end
    return A.DisplayName(name)
end
function A.L(text)
    if A.IsRussian() then return text end
    return english[text] or text
end
local sources = {
    ["All loot tables"] = "Любые источники добычи",
    ["Anything and everything. Up to and including trials"] = "Любые источники добычи, включая испытания",
    ["Excavation reward"] = "Награда за раскопки",
    ["Reward for excavating previous level treasure lead"] = "Награда за раскопки сокровища предыдущего уровня",
    ["Treasure Maps"] = "Карты сокровищ",
    ["Daily Reward Coffer"] = "Сундук за ежедневное задание",
    ["All monsters"] = "Любые противники",
    ["Any and all monsters (including trial and dungeons)"] = "Любые противники, включая подземелья и испытания",
    ["Safebox"] = "Сейфы", ["Treasure chest"] = "Сундуки с сокровищами",
    ["Treasure map chest"] = "Сундуки по картам сокровищ",
    ["Zone starting lead"] = "Начальная зацепка области",
    ["All world bosses"] = "Любые мировые боссы",
    ["Drop from dragons"] = "Добыча с драконов",
    ["Drop from harrowstorms"] = "Награда за мрачные бури",
    ["Innkeeper, general merchant. Requiers Pathfinder"] = "Трактирщик или обычный торговец; требуется достижение исследователя области",
    ["High Seas Event Chests"] = "Сундуки события в открытом море",
    ["Wood Nodes"] = "Древесина: сбор ресурсов",
    ["Ore Nodes"] = "Рудные жилы: сбор ресурсов",
    ["Treasure Chests"] = "Сундуки с сокровищами",
    ["Fishing"] = "Рыбалка", ["World Bosses"] = "Мировые боссы",
    ["Delve Bosses"] = "Боссы логов", ["Safeboxes"] = "Сейфы",
    ["Psijic Portals"] = "Порталы Псиджиков", ["Final Boss"] = "Последний босс",
    ["All bosses in"] = "Все боссы в", ["Final boss in"] = "Последний босс в",
    ["(Dungeon)"] = "(Подземелье)", ["(Trial)"] = "(Испытание)",
}
local sourcePhrases = {
    {"lase secret Boss", "последний тайный босс"},
    {"last secret Boss", "последний тайный босс"},
    {"Final Boss", "Последний босс"}, {"final boss", "последний босс"},
    {"All bosses in", "Все боссы в"}, {"Final boss in", "Последний босс в"},
    {"delve boss in", "босс вылазки в"},
    {"Delve boss in", "Босс вылазки в"}, {"delve boss", "босс вылазки"},
    {"Last boss in", "Последний босс в"},
    {"Non-group-boss in", "Обычные боссы в"},
    {"group delve", "групповая вылазка"},
    {"World Bosses", "Мировые боссы"}, {"Delve Bosses", "Боссы вылазок"},
    {"Treasure Chests", "Сундуки с сокровищами"}, {"Treasure Maps", "Карты сокровищ"},
    {"Psijic Portals", "Порталы Псиджиков"}, {"Wood Nodes", "Древесина"},
    {"Ore Nodes", "Рудные жилы"}, {"Safeboxes", "Сейфы"},
    {"Fishing", "Рыбалка"}, {"secret boss", "тайный босс"},
}
function A.LocalizeSource(text, part)
    text = text or ""
    if not A.IsRussian() then return text end
    -- The route IDs stay authoritative. Replace only the display name from the
    -- frozen English short description when it names one known instance.
    local ids = part and A.LeadInstances and A.LeadInstances[part.id]
    local short = part and part.sourceShort
    if ids and #ids == 1 and short then
        local instance = short:match("^%([%a/]+%)%s+(.+)$")
        if instance and instance ~= "" then
            local escaped = instance:gsub("([^%w])", "%%%1")
            local localized = A.ZoneName(ids[1])
            text = text:gsub(escaped .. "()", function(nextIndex)
                -- Do not replace a substring in a boss's possessive name, or
                -- the first letters of a longer proper name.
                local following = text:sub(nextIndex, nextIndex)
                if following:match("[%a']") then return instance end
                return localized
            end)
        end
    end
    if sources[text] then return sources[text] end
    for _, phrase in ipairs(sourcePhrases) do
        local escaped = phrase[1]:gsub("([^%w])", "%%%1")
        text = text:gsub(escaped, function() return phrase[2] end)
    end
    return text
end
