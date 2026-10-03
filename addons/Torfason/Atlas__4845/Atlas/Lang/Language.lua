AtlasAddon = AtlasAddon or {}
local AE = AtlasAddon

-- Zentrale Sprachverwaltung. Die eigentlichen Übersetzungen liegen getrennt
-- unter Lang/de.lua und Lang/en.lua, damit weitere Sprachen ohne Änderungen
-- an der Kartenlogik ergänzt werden können.
AE.T = AE.T or {}
AE.Translations = AE.Translations or {}

AE.LanguageStyleValues = AE.LanguageStyleValues or {
    "pergament",
    "papier",
    "pergament_dunkel",
    "nebel",
    "kohle",
    "schwarz",
}

function AE:GetClientLanguage()
    local language = GetCVar and GetCVar("language.2") or "en"
    language = string.lower(tostring(language or "en"))
    if string.sub(language, 1, 2) == "de" then return "de" end
    return "en"
end

function AE:ResolveLanguage(setting)
    setting = string.lower(tostring(setting or "auto"))
    if setting == "de" or setting == "en" then return setting end
    return self:GetClientLanguage()
end

function AE:SetLanguage(setting)
    local language = self:ResolveLanguage(setting)
    local source = self.Translations[language] or self.Translations.en
    local target = self.T
    for key in pairs(target) do target[key] = nil end
    for key, value in pairs(source) do target[key] = value end
    self.activeLanguage = language
    return language
end

