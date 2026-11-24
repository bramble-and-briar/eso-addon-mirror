-- Arclight Taunt localization: English is the canonical source and fallback.
-- Persisted settings (media names, sound names, sorting keys) never change
-- with the player's language; only labels and tooltips are translated.
local A = ArclightTaunt
local language = GetCVar("language.2")
local englishText = A.translations and A.translations.en or {}
-- The manifest loads English first, then only the client's $(language) file.
-- Missing or unsupported languages use English, never a previous translation.
A.language = (A.translations and A.translations[language]) and language or "en"
function A.T(english)
    if type(english) ~= "string" then return english end
    if A.language ~= "en" then
        local dictionary = A.translations and A.translations[A.language]
        local translated = type(dictionary) == "table" and dictionary[english]
        if type(translated) == "string" and translated ~= "" then return translated end
    end
    local refined = englishText[english]
    if type(refined) == "string" and refined ~= "" then return refined end
    return english
end
-- Historic 0.9.x media and sound keys are German strings. Translate only
-- their displayed labels, never the saved keys or LibMediaProvider lookups.
function A.TStored(storedKey)
    local english = A.legacyLabels and A.legacyLabels[storedKey]
    return A.T(english or storedKey)
end

function A.BossAlertText(kind, count, bossName)
    if A.language == "ru" then
        return A.RussianBossAlertText(kind, count, bossName)
    end
    local name = count == 1 and (bossName or A.T("Boss")) or (tostring(count) .. " " .. A.T("enemies"))
    local title = kind == "early" and (count == 1 and A.T("BOSS TAUNT EXPIRING")
        or (tostring(count) .. A.T(" BOSS TAUNTS EXPIRING")))
        or (count == 1 and A.T("BOSS TAUNT EXPIRED")
        or (tostring(count) .. A.T(" BOSS TAUNTS EXPIRED")))
    return title, name
end
