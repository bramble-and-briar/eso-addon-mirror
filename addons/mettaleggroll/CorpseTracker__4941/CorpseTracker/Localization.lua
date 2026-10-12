local CT = CorpseTracker
local GetCVar = GetCVar
local GetString = GetString
local strformat = zo_strformat
CT.languageCodes = { "en", "ru", "de", "fr", "es", "jp", "zh", "br" }
CT.languageNames = { "English", "Русский", "Deutsch", "Français", "Español", "日本語", "简体中文", "Português (Brasil)" }
local supported, translations = {}, {}
local initialized = false
for _, code in ipairs(CT.languageCodes) do supported[code] = true end

function CT.IsLanguageSupported(code)
    return supported[code] == true
end

-- All translation files are available for a manual choice, but only the chosen
-- file applies SafeAddString after SavedVariables have been read.
function CT.RegisterTranslation(code, initialize)
    if translations then translations[code] = initialize end
end

function CT.SelectLanguage(preference)
    -- A setting change takes effect on the next UI load, as requested by LAM.
    if initialized then return CT.language end
    CT.clientLanguage = GetCVar and GetCVar("language.2") or "en"
    local code = preference
    if not code or code == "auto" then code = CT.clientLanguage end
    if not supported[code] or (code ~= "en" and not translations[code]) then code = "en" end
    CT.language = code
    if translations[code] then translations[code]() end
    -- Release the unused translation callbacks after the selected strings exist.
    translations, initialized = nil, true
    return CT.language
end

function CT.T(key, ...)
    local id = CT.stringIds[key]
    local value = id and GetString(id) or key
    -- Indexed ESO placeholders let translators reorder parameters and format
    -- numbers or game names without exposing the client's grammar tags.
    if select("#", ...) > 0 then return strformat(value, ...) end
    return value
end
