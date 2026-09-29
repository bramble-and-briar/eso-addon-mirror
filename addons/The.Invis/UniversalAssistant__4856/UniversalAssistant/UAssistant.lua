UAssistant = {
    addonName = "UniversalAssistant",
    version = "1.0.1",
    Localization = {
        defaultLanguage = "en",
        languages = {},
        order = {},
    },
}

local ua = UAssistant
local localization = ua.Localization

function ua.RegisterLanguage(code, displayName, strings)
    if not localization.languages[code] then
        localization.languages[code] = {
            displayName = displayName,
            strings = {},
        }
        table.insert(localization.order, code)
    end

    local language = localization.languages[code]
    language.displayName = displayName or language.displayName

    for key, value in pairs(strings or {}) do
        language.strings[key] = value
    end
end

function ua.AddLanguageStrings(code, strings, prefix)
    local language = localization.languages[code]
    if not language then
        return
    end

    local function AddStrings(values, currentPrefix)
        for key, value in pairs(values) do
            local fullKey = currentPrefix and (currentPrefix .. "_" .. key) or key
            if type(value) == "table" then
                AddStrings(value, fullKey)
            else
                language.strings[fullKey] = value
            end
        end
    end

    AddStrings(strings or {}, prefix)
end

function ua.GetLanguageCode()
    local languageSettings = ua.profileStorage or ua.savedVariables
    local savedLanguage = languageSettings and languageSettings.language

    if localization.languages[savedLanguage] then
        return savedLanguage
    end

    local clientLanguage = GetCVar("language.2")
    if localization.languages[clientLanguage] then
        return clientLanguage
    end

    return localization.defaultLanguage
end

function ua.GetString(key)
    local selected = localization.languages[ua.GetLanguageCode()]
    local fallback = localization.languages[localization.defaultLanguage]

    return (selected and selected.strings[key]) or (fallback and fallback.strings[key]) or key
end

function ua.GetLanguageChoices()
    local choices = {}
    local values = {}

    for _, code in ipairs(localization.order) do
        local language = localization.languages[code]
        table.insert(choices, language.displayName)
        table.insert(values, code)
    end

    return choices, values
end

local ADDON_NAME = ua.addonName

local function OnAddOnLoaded(eventCode, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    ua.Initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
