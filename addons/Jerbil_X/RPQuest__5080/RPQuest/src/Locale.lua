-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.Locale = {}
local Locale = Addon.Locale

local DEFAULT_LANG = "en"

function Locale:DetectClientLanguage()
    local lang = GetCVar("language.2") or GetCVar("Language.2")
    if type(lang) == "string" and lang ~= "" then
        lang = lang:lower()
        if Addon.Locales and Addon.Locales[lang] then
            return lang
        end
    end
    return DEFAULT_LANG
end

function Locale:Initialize(overrideLang)
    local lang = overrideLang or self:DetectClientLanguage()
    if not (Addon.Locales and Addon.Locales[lang]) then
        lang = DEFAULT_LANG
    end
    self.activeLang = lang
    self._dict = (Addon.Locales and Addon.Locales[lang]) or {}
    self._fallbackDict = (Addon.Locales and Addon.Locales[DEFAULT_LANG]) or {}

    if not self._stringsRegistered then
        ZO_CreateStringId("SI_KEYBINDINGS_CATEGORY_RPQUEST", self:Get("SI_KEYBINDINGS_CATEGORY_RPQUEST"))
        ZO_CreateStringId("SI_BINDING_NAME_RPQUEST_CAPTURE_TARGET", self:Get("SI_BINDING_NAME_RPQUEST_CAPTURE_TARGET"))
        ZO_CreateStringId("SI_BINDING_NAME_RPQUEST_TOGGLE_JOURNAL", self:Get("SI_BINDING_NAME_RPQUEST_TOGGLE_JOURNAL"))
        self._stringsRegistered = true
    end
end

function Locale:GetLanguage()
    if not self.activeLang then
        self.activeLang = self:DetectClientLanguage()
    end
    return self.activeLang
end

function Locale:Get(key, ...)
    local dict = self._dict
    local fallbackDict = self._fallbackDict
    if not dict or not fallbackDict then
        local lang = self:GetLanguage()
        dict = (Addon.Locales and Addon.Locales[lang]) or {}
        fallbackDict = (Addon.Locales and Addon.Locales[DEFAULT_LANG]) or {}
        self._dict = dict
        self._fallbackDict = fallbackDict
    end

    local template = dict[key] or fallbackDict[key] or tostring(key)
    if select("#", ...) > 0 then
        return string.format(template, ...)
    end
    return template
end
