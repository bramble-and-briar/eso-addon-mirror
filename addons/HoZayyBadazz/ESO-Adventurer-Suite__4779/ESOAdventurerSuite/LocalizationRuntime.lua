-- ESO Adventurer Suite
-- v0.29.552 - runtime i18n integration.
-- Localizes Suite-owned controls after creation and wires the Modern UI,
-- bank grid, and character gear refresh paths into the central localization layer.

local EPC = ESOProgressionCoach
if not EPC or not EPC.I18N then return end
local I = EPC.I18N

local function localizeTree(control)
    if control and I.LocalizeControlTree then I:LocalizeControlTree(control, 0) end
end

local function isSuiteName(name)
    name = tostring(name or "")
    return name:find("^EAS") ~= nil or name:find("^EPC") ~= nil or name:find("^ESOProgressionCoach") ~= nil
end

function I:LocalizeTopLevelSuiteControls()
    local root = rawget(_G, "GuiRoot")
    if not root or type(root.GetNumChildren) ~= "function" or type(root.GetChild) ~= "function" then return end
    local ok, count = pcall(root.GetNumChildren, root)
    count = ok and tonumber(count) or 0
    for index = 1, count do
        local okChild, child = pcall(root.GetChild, root, index)
        if okChild and child then
            local name = ""
            if type(child.GetName) == "function" then
                local okName, value = pcall(child.GetName, child)
                if okName then name = tostring(value or "") end
            end
            if isSuiteName(name) then localizeTree(child) end
        end
    end
end

local function scheduleSweep(delay)
    if not EVENT_MANAGER then
        I:LocalizeTopLevelSuiteControls()
        return
    end
    local key = (EPC.name or "ESOAdventurerSuite") .. "_I18NSweep029552"
    EVENT_MANAGER:UnregisterForUpdate(key)
    EVENT_MANAGER:RegisterForUpdate(key, math.max(1, tonumber(delay) or 50), function()
        EVENT_MANAGER:UnregisterForUpdate(key)
        I:LocalizeTopLevelSuiteControls()
    end)
end

local function wrapMethod(object, methodName, marker, rootResolver)
    if type(object) ~= "table" or type(object[methodName]) ~= "function" or object[marker] then return end
    local base = object[methodName]
    object[methodName] = function(self, ...)
        local result = base(self, ...)
        local root = rootResolver and rootResolver(self) or nil
        if root then localizeTree(root) else scheduleSweep(1) end
        return result
    end
    object[marker] = true
end

-- Modern application: localize every newly created/lazily refreshed page.
local M = EPC.ModernAppUI
if type(M) == "table" then
    local function modernRoot(self) return self and self.window end
    wrapMethod(M, "Show", "_i18nShow029552", modernRoot)
    wrapMethod(M, "SetTab", "_i18nSetTab029552", modernRoot)
    wrapMethod(M, "RefreshCurrent", "_i18nRefresh029552", modernRoot)
    wrapMethod(M, "CreateShell", "_i18nCreateShell029552", modernRoot)
    if M.window then localizeTree(M.window) end
end

-- Bank grid: category/count labels are rebuilt as filters and modes change.
local B = EPC.BankGridUnifiedV2
if type(B) == "table" then
    local function bankRoot(self) return self and (self.root or self.frame) end
    wrapMethod(B, "Render", "_i18nRender029552", bankRoot)
    wrapMethod(B, "Refresh", "_i18nRefresh029552", bankRoot)
    if B.root then localizeTree(B.root) end
end

-- Character / companion equipment screen.
local G = EPC.CharacterGearScreen
if type(G) == "table" then
    local function gearRoot(self)
        if not self then return nil end
        return self.root or self.playerRoot or self.companionRoot or self.window
    end
    wrapMethod(G, "Refresh", "_i18nRefresh029552", gearRoot)
    wrapMethod(G, "RequestRefresh", "_i18nRequestRefresh029552", gearRoot)
end

-- Main Suite UI/HUD-owned top-level controls are localized once after activation.
if EVENT_MANAGER and EVENT_PLAYER_ACTIVATED then
    local eventName = (EPC.name or "ESOAdventurerSuite") .. "_I18NPlayerActivated029552"
    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_PLAYER_ACTIVATED, function()
        scheduleSweep(250)
    end)
end

-- Scene changes can create lazy Suite controls. Do a single deferred sweep only
-- when a scene transition occurs; there is no permanent polling/update loop.
if SCENE_MANAGER and type(SCENE_MANAGER.RegisterCallback) == "function" then
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(_, _, newState)
        if newState == SCENE_SHOWN or newState == SCENE_SHOWING then scheduleSweep(80) end
    end)
end

scheduleSweep(1)


-- BEGIN ABSORBED: LocalizationLiveSwitchFix.lua
-- ESO Adventurer Suite
-- v0.29.553 - live i18n language switching fix.
-- Allows already-localized controls to switch directly between any supported
-- language and immediately refreshes visible Suite UI without /reloadui.

local EPC = ESOProgressionCoach
if not EPC or not EPC.I18N then return end
local I = EPC.I18N

local reverseExact = {}
local english = I.keys and I.keys.en or {}

-- Build a translation -> canonical English lookup for every supported locale.
-- This lets a control currently showing German/Russian/etc. switch directly to
-- French/Japanese/etc. instead of requiring the source text to still be English.
if type(I.keys) == "table" and type(english) == "table" then
    for _, locale in pairs(I.keys) do
        if type(locale) == "table" then
            for key, translated in pairs(locale) do
                local source = english[key]
                if type(source) == "string" and type(translated) == "string" then
                    reverseExact[translated] = source
                end
            end
        end
    end
end

local function trim(value)
    value = tostring(value or "")
    value = value:gsub("^%s+", "")
    value = value:gsub("%s+$", "")
    return value
end

local function canonicalEnglish(text)
    if type(text) ~= "string" or text == "" then return text end
    if reverseExact[text] then return reverseExact[text] end

    -- Preserve category counters such as "Waffen (12)" / "Оружие (12)".
    local base, count = text:match("^(.-)%s*(%(%d+%))$")
    if base then
        local canonical = reverseExact[trim(base)] or trim(base)
        return canonical .. " " .. count
    end

    -- Preserve dynamic values after translated fixed labels.
    local left, right = text:match("^([^:]+):%s*(.+)$")
    if left and right then
        local canonical = reverseExact[trim(left)] or trim(left)
        return canonical .. ": " .. right
    end

    -- Handle compact A / B labels after either side has already been localized.
    local a, b = text:match("^([^/]+)/([^/]+)$")
    if a and b then
        a, b = trim(a), trim(b)
        return (reverseExact[a] or a) .. " / " .. (reverseExact[b] or b)
    end

    return text
end

local function translateCanonical(text, lang)
    if type(text) ~= "string" or text == "" or lang == "en" then return text end
    local raw = I.raw and I.raw[lang]
    if type(raw) ~= "table" then return text end

    if raw[text] then return raw[text] end

    local base, count = text:match("^(.-)%s*(%(%d+%))$")
    if base and raw[trim(base)] then return raw[trim(base)] .. " " .. count end

    local left, right = text:match("^([^:]+):%s*(.+)$")
    if left and right and raw[trim(left)] then return raw[trim(left)] .. ": " .. right end

    local a, b = text:match("^([^/]+)/([^/]+)$")
    if a and b then
        a, b = trim(a), trim(b)
        if raw[a] or raw[b] then return (raw[a] or a) .. " / " .. (raw[b] or b) end
    end

    return text
end

-- Replace the one-direction localization behavior with language-agnostic
-- relocalization. English remains the canonical source language.
function I:Localize(text)
    if type(text) ~= "string" or text == "" then return text end
    local lang = self.language or self:GetLanguage()
    self.language = lang
    return translateCanonical(canonicalEnglish(text), lang)
end

local function localizeVisibleControls()
    if type(I.LocalizeTopLevelSuiteControls) == "function" then
        pcall(I.LocalizeTopLevelSuiteControls, I)
    end
end

local function refreshLiveSurfaces()
    localizeVisibleControls()

    local M = EPC.ModernAppUI
    if type(M) == "table" then
        if type(M.RefreshCurrent) == "function" then pcall(M.RefreshCurrent, M) end
        if M.window and type(I.LocalizeControlTree) == "function" then
            pcall(I.LocalizeControlTree, I, M.window, 0)
        end
    end

    local B = EPC.BankGridUnifiedV2
    if type(B) == "table" and type(B.Refresh) == "function" then pcall(B.Refresh, B) end

    local G = EPC.CharacterGearScreen
    if type(G) == "table" and type(G.RequestRefresh) == "function" then
        pcall(G.RequestRefresh, G, 0)
    end

    local S = EPC.Settings
    if type(S) == "table" and S.panelObject and type(S.panelObject.RefreshPanel) == "function" then
        pcall(S.panelObject.RefreshPanel, S.panelObject)
    end

    if type(EPC.RefreshGameplayOverlays) == "function" then
        pcall(EPC.RefreshGameplayOverlays, EPC)
    end
end

local baseSetLanguage = I.SetLanguage
function I:SetLanguage(code)
    local result
    if type(baseSetLanguage) == "function" then
        result = baseSetLanguage(self, code)
    else
        code = tostring(code or "AUTO")
        if EPC.saved then EPC.saved.i18nLanguage029552 = code end
        self.language = self:GetLanguage()
        result = self.language
    end

    refreshLiveSurfaces()

    -- Some LAM/scene controls update one frame after the dropdown callback.
    -- Perform two one-shot sweeps; there is no persistent polling loop.
    if EVENT_MANAGER then
        local key = (EPC.name or "ESOAdventurerSuite") .. "_I18NLiveSwitch029553"
        EVENT_MANAGER:UnregisterForUpdate(key)
        local pass = 0
        EVENT_MANAGER:RegisterForUpdate(key, 80, function()
            pass = pass + 1
            refreshLiveSurfaces()
            if pass >= 2 then EVENT_MANAGER:UnregisterForUpdate(key) end
        end)
    end

    return result
end

-- Also make control-tree sweeps reversible when the currently displayed label
-- was produced by a previous language selection.
local baseTree = I.LocalizeControlTree
function I:LocalizeControlTree(control, depth)
    if not control then return end
    depth = tonumber(depth) or 0
    if depth > 18 then return end

    if type(control.GetText) == "function" and type(control.SetText) == "function" then
        local ok, text = pcall(control.GetText, control)
        if ok and type(text) == "string" and text ~= "" then
            local localized = self:Localize(text)
            if localized ~= text then pcall(control.SetText, control, localized) end
        end
    end

    if type(control.GetNumChildren) == "function" and type(control.GetChild) == "function" then
        local ok, count = pcall(control.GetNumChildren, control)
        count = ok and tonumber(count) or 0
        for index = 1, count do
            local okChild, child = pcall(control.GetChild, control, index)
            if okChild and child then self:LocalizeControlTree(child, depth + 1) end
        end
    elseif type(baseTree) == "function" then
        pcall(baseTree, self, control, depth)
    end
end

I.liveSwitch029553 = true

-- END ABSORBED: LocalizationLiveSwitchFix.lua


-- BEGIN ABSORBED: LocalizationSettingsRegistrationFix.lua
-- ESO Adventurer Suite
-- v0.29.557 - safe recursive localization for LibAddonMenu settings.
-- The original i18n hook only localized the top-level organizedOptions table,
-- while nearly every Suite setting lives inside submenu.controls. It also wrote
-- a non-array marker key onto the options array, which could confuse LAM's entry
-- accounting. This layer keeps the existing hook but replaces the two methods it
-- calls with recursive, array-safe implementations.

local EPC = ESOProgressionCoach
if not EPC or not EPC.I18N then return end
local I = EPC.I18N

local function localizeOptionRecursive(option)
    if type(option) ~= "table" then return option end

    for _, field in ipairs({ "name", "title", "text", "tooltip", "warning", "buttonText" }) do
        local value = option[field]
        if type(value) == "string" then
            option[field] = I:Localize(value)
        elseif type(value) == "function" then
            local marker = "_easI18NRecursive_" .. field
            if option[marker] ~= true then
                local base = value
                option[field] = function(...)
                    local result = base(...)
                    if type(result) == "string" then return I:Localize(result) end
                    return result
                end
                option[marker] = true
            end
        end
    end

    if type(option.choices) == "table" then
        for index = 1, #option.choices do
            if type(option.choices[index]) == "string" then
                option.choices[index] = I:Localize(option.choices[index])
            end
        end
    end

    if type(option.controls) == "table" then
        for index = 1, #option.controls do
            localizeOptionRecursive(option.controls[index])
        end
    end

    return option
end

function I:LocalizeOption(option)
    return localizeOptionRecursive(option)
end

function I:LocalizeOptions(options)
    if type(options) ~= "table" then return options end
    for index = 1, #options do
        localizeOptionRecursive(options[index])
    end
    return options
end

-- Inject exactly one localization submenu without adding bookkeeping keys to the
-- numeric LAM options array. A language change reloads the UI once so every Suite
-- module reconstructs its labels/tooltips using the newly selected locale.
function I:InjectSettings(options)
    if type(options) ~= "table" then return options end

    -- Avoid duplicate injection if Settings is initialized more than once.
    for index = 1, #options do
        local entry = options[index]
        if type(entry) == "table" and entry._easLanguageMenu029557 == true then
            return options
        end
    end

    local languageChoices = {
        self:T("AUTO_ESO_LANGUAGE"),
        "English", "Deutsch", "Français", "Русский", "Español", "简体中文", "日本語",
    }
    local languageValues = { "AUTO", "en", "de", "fr", "ru", "es", "zh", "ja" }

    local languageMenu = {
        type = "submenu",
        name = self:T("LANGUAGE"),
        tooltip = self:T("INTERFACE_LANGUAGE"),
        _easLanguageMenu029557 = true,
        controls = {
            {
                type = "dropdown",
                name = self:T("INTERFACE_LANGUAGE"),
                tooltip = self:T("RELOAD_LANGUAGE"),
                choices = languageChoices,
                choicesValues = languageValues,
                getFunc = function()
                    return EPC.saved and (EPC.saved.i18nLanguage029552 or "AUTO") or "AUTO"
                end,
                setFunc = function(value)
                    I:SetLanguage(value)
                    -- LAM controls are constructed from registration data. A clean
                    -- reload guarantees the entire 500+ control panel and every
                    -- other Suite surface rebuild in the selected language instead
                    -- of leaving old labels cached in existing controls.
                    if type(ReloadUI) == "function" then
                        ReloadUI()
                    elseif type(EPC.Print) == "function" then
                        EPC:Print(I:T("RELOAD_LANGUAGE"))
                    end
                end,
                default = "AUTO",
                width = "full",
            },
        },
    }

    -- Keep the explanatory Settings description first, then localization.
    local insertAt = (#options > 0 and type(options[1]) == "table" and options[1].type == "description") and 2 or 1
    table.insert(options, insertAt, languageMenu)
    return options
end

I.settingsRegistrationFix029557 = true

-- END ABSORBED: LocalizationSettingsRegistrationFix.lua
