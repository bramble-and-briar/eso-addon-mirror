-- Arclight Taunt localization: English is the canonical source and fallback.
-- Persisted settings (media names, sound names, sorting keys) never change
-- with the player's language; only labels and tooltips are translated.
local A = ArclightTaunt
local language = type(GetCVar) == "function" and GetCVar("language.2") or "en"
-- The manifest loads English first, then only the client's $(language) file.
-- Missing or unsupported languages use English, never a previous translation.
A.language = (A.translations and A.translations[language]) and language or "en"
function A.T(english)
    if type(english) ~= "string" then return english end
    if A.language ~= "en" then
        local dictionary = A.translations and A.translations[A.language]
        if dictionary and dictionary[english] then return dictionary[english] end
    end
    return english -- canonical English fallback, also for unsupported locales
end
-- Historic 0.9.x media and sound keys are German strings. Translate only
-- their displayed labels, never the saved keys or LibMediaProvider lookups.
function A.TStored(storedKey)
    local english = A.legacyLabels and A.legacyLabels[storedKey]
    return A.T(english or storedKey)
end

-- Russian count forms: 1/21, 2-4/22-24, and 0/5-20/25-30.
function A.RussianCountForm(count)
    local last, hundred = count % 10, count % 100
    if last == 1 and hundred ~= 11 then return 1 end
    if last >= 2 and last <= 4 and (hundred < 12 or hundred > 14) then return 2 end
    return 3
end
function A.BossAlertText(kind, count, bossName)
    if A.language == "ru" then
        local form = A.RussianCountForm(count)
        local names = { "враг", "врага", "врагов" }
        local early = { "ПРОВОКАЦИЯ БОССА ИСТЕКАЕТ", "ПРОВОКАЦИИ БОССОВ ИСТЕКАЮТ", "ПРОВОКАЦИЙ БОССОВ ИСТЕКАЕТ" }
        local expired = { "ПРОВОКАЦИЯ БОССА ИСТЕКЛА", "ПРОВОКАЦИИ БОССОВ ИСТЕКЛИ", "ПРОВОКАЦИЙ БОССОВ ИСТЕКЛО" }
        local title = (kind == "early" and early or expired)[form]
        return (count == 1 and title or tostring(count) .. " " .. title),
            (count == 1 and (bossName or A.T("Boss")) or tostring(count) .. " " .. names[form])
    end
    local name = count == 1 and (bossName or A.T("Boss")) or (tostring(count) .. " " .. A.T("enemies"))
    local title = kind == "early" and (count == 1 and A.T("BOSS TAUNT EXPIRING")
        or (tostring(count) .. A.T(" BOSS TAUNTS EXPIRING")))
        or (count == 1 and A.T("BOSS TAUNT EXPIRED")
        or (tostring(count) .. A.T(" BOSS TAUNTS EXPIRED")))
    return title, name
end
