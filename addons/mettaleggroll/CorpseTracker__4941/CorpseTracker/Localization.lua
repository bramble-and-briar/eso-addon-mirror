local CT = CorpseTracker
CT.locales = {}
CT.languageCodes = { "en", "ru", "de", "fr", "es", "jp", "zh", "br" }
CT.languageNames = { "English", "Русский", "Deutsch", "Français", "Español", "日本語", "简体中文", "Português (Brasil)" }

function CT.SelectLanguage(preference)
    local code = preference
    if not code or code == "auto" then
        code = GetCVar and GetCVar("language.2") or "en"
    end
    CT.language = CT.locales[code] and code or "en"
    return CT.language
end

function CT.T(key, ...)
    local dictionary = CT.locales[CT.language or "en"] or CT.locales.en
    local value = dictionary[key] or CT.locales.en[key] or key
    if select("#", ...) > 0 then return string.format(value, ...) end
    return value
end
