AtlasAddon = AtlasAddon or {}
local AE = AtlasAddon

-- Atlas 2.1: Translation tables for all languages are loaded at startup.
-- AE.T retains its table identity because other Lua modules keep a local reference.
AE.T = AE.T or {}
AE.Translations = AE.Translations or {}

AE.LanguageStyleValues = AE.LanguageStyleValues or {
    "pergament", "papier", "pergament_dunkel", "nebel", "kohle", "schwarz",
}

AE.LanguageChoices = {
    { code = "auto" },
    { code = "de", name = "Deutsch" },
    { code = "en", name = "English" },
    { code = "fr", name = "Français" },
    { code = "es", name = "Español" },
    { code = "ru", name = "Русский" },
    { code = "zh", name = "简体中文" },
    { code = "jp", name = "日本語" },
}

local supported = { en = true, de = true, fr = true, es = true, ru = true, zh = true, jp = true }

local function NormalizeLanguage(value)
    local language = string.lower(tostring(value or ""))
    language = string.gsub(language, "^%s+", "")
    language = string.gsub(language, "%s+$", "")
    -- The Japanese ESO client uses 'jp'; some community language files use 'ja'.
    if string.sub(language, 1, 2) == "ja" then return "jp" end
    local prefix = string.sub(language, 1, 2)
    if supported[prefix] then return prefix end
    return nil
end

function AE:GetClientLanguage()
    local language = GetCVar and GetCVar("language.2") or "en"
    return NormalizeLanguage(language) or "en"
end

function AE:NormalizeLanguageSetting(setting)
    if setting == nil or setting == "" then return "auto" end
    local value = string.lower(tostring(setting))
    if value == "auto" then return "auto" end
    return NormalizeLanguage(value) or "auto"
end

function AE:ResolveLanguage(setting)
    local chosen = self:NormalizeLanguageSetting(setting)
    return chosen == "auto" and self:GetClientLanguage() or chosen
end

function AE:GetLanguageChoiceLabel(code)
    if code == "auto" then return self.T.LANGUAGE_AUTO or "Automatic (ESO language)" end
    for _, entry in ipairs(self.LanguageChoices) do
        if entry.code == code then return entry.name end
    end
    return code
end

function AE:SetLanguage(setting)
    local language = self:ResolveLanguage(setting)
    local english = self.Translations.en or {}
    local source = self.Translations[language] or english
    local target = self.T

    -- Per-key and per-array-element English fallback; never leave empty labels.
    for key in pairs(target) do target[key] = nil end
    for key, englishValue in pairs(english) do
        local translated = source[key]
        if type(englishValue) == "table" then
            local items = {}
            for index, englishItem in ipairs(englishValue) do
                local item = type(translated) == "table" and translated[index] or nil
                if type(item) ~= "string" or item == "" then item = englishItem end
                items[index] = item
            end
            target[key] = items
        elseif type(translated) == "string" and translated ~= "" then
            target[key] = translated
        else
            target[key] = englishValue
        end
    end
    -- Style file identifiers are not translatable and must remain stable.
    target.STYLE_VALUES = self.LanguageStyleValues
    self.activeLanguage = language
    return language
end

function AE:SetAddonLanguage(setting)
    local chosen = self:NormalizeLanguageSetting(setting)
    if self.settings then self.settings.language = chosen end
    self:SetLanguage(chosen)
    if self.RefreshSettingsLocalization then
        self:RefreshSettingsLocalization()
    elseif self.RefreshArchiveLocalization then
        self:RefreshArchiveLocalization()
    end
    return chosen
end
