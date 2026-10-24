--[[
    AbyssQuest settings (integrated into AbyssUI panel)
]]

AetherPath = AetherPath or {}
local AP = AetherPath
AP.Settings = AP.Settings or {}

local Settings = AP.Settings

function Settings:Initialize()
    if AP.Travel and AP.Travel.RegisterDialogs then
        AP.Travel:RegisterDialogs()
    end
end

local function refreshUI()
    if AP.UI then
        if AP.UI.ApplyTheme then AP.UI:ApplyTheme() end
        if AP.UI.RebuildQuestList then AP.UI:RebuildQuestList() end
    end
    if AP.Tracker then AP.Tracker:Refresh() end
end

function Settings:BuildOptions()
    local fontChoices = AP.FontChoices or AP.FontList or { "Game", "Game Small" }
    local fontValues  = AP.FontValues or AP.FontList or { "ZoFontGame", "ZoFontGameSmall" }

    return {
        {
            type = "description",
            text = "AbyssQuest — rastreador minimalista (uma missão focada).",
        },
        {
            type = "checkbox",
            name = AP.L("SETTINGS_SHOW_TRACKER"),
            getFunc = function() return AP.sv.showTracker ~= false end,
            setFunc = function(v)
                AP.sv.showTracker = v
                if AP.UI then AP.UI:SetTrackerVisible(v) end
            end,
            default = true,
        },
        {
            type = "checkbox",
            name = AP.L("SETTINGS_LOCK_TRACKER"),
            getFunc = function() return AP.sv.trackerLocked == true end,
            setFunc = function(v)
                AP.sv.trackerLocked = v
                if AP.UI then AP.UI:ApplyLock() end
            end,
            default = false,
        },
        {
            type = "slider",
            name = AP.L("SETTINGS_SCALE"),
            min = 70, max = 130, step = 5,
            getFunc = function() return math.floor((AP.sv.trackerScale or 1) * 100) end,
            setFunc = function(v)
                AP.sv.trackerScale = v / 100
                if AP.UI then AP.UI:ApplyScale() end
            end,
            default = 100,
        },
        {
            type = "slider",
            name = AP.L("SETTINGS_ALPHA"),
            min = 50, max = 100, step = 5,
            getFunc = function() return math.floor((AP.sv.trackerAlpha or 0.94) * 100) end,
            setFunc = function(v)
                AP.sv.trackerAlpha = v / 100
                if AP.UI then AP.UI:ApplyAlpha() end
            end,
            default = 94,
        },
        {
            type = "slider",
            name = AP.L("SETTINGS_CONTRAST") or "Contrast",
            tooltip = AP.L("SETTINGS_CONTRAST_TIP"),
            min = 70, max = 140, step = 5,
            getFunc = function() return math.floor((AP.sv.contrast or 1) * 100) end,
            setFunc = function(v)
                AP.sv.contrast = v / 100
                if AP.ApplyContrast then AP.ApplyContrast(AP.sv.contrast) end
                refreshUI()
            end,
            default = 100,
        },
        {
            type = "checkbox",
            name = AP.L("SETTINGS_SHOW_OBJECTIVES"),
            getFunc = function() return AP.sv.showObjectives ~= false end,
            setFunc = function(v)
                AP.sv.showObjectives = v
                refreshUI()
            end,
            default = true,
        },
        {
            type = "checkbox",
            name = AP.L("SETTINGS_SHOW_TOMES"),
            getFunc = function() return AP.sv.showTomes ~= false end,
            setFunc = function(v)
                AP.sv.showTomes = v
                if AP.Tomes then AP.Tomes:Refresh() end
            end,
            default = true,
        },
        {
            type = "header",
            name = AP.L("SETTINGS_STYLE") or "Title & Description",
        },
        {
            type = "dropdown",
            name = AP.L("SETTINGS_TITLE_FONT") or "Title font",
            choices = fontChoices,
            choicesValues = fontValues,
            getFunc = function() return AP.sv.titleFont or "ZoFontWinH4" end,
            setFunc = function(v)
                AP.sv.titleFont = v
                refreshUI()
            end,
            default = "ZoFontWinH4",
            scrollable = true,
        },
        {
            type = "colorpicker",
            name = AP.L("SETTINGS_TITLE_COLOR") or "Title color",
            getFunc = function()
                local c = AP.sv.titleColor or {0.40, 0.60, 0.90, 1}
                return c[1], c[2], c[3], c[4] or 1
            end,
            setFunc = function(r, g, b, a)
                AP.sv.titleColor = {r, g, b, a or 1}
                refreshUI()
            end,
            default = {0.40, 0.60, 0.90, 1},
        },
        {
            type = "dropdown",
            name = AP.L("SETTINGS_STEP_FONT") or "Description font",
            choices = fontChoices,
            choicesValues = fontValues,
            getFunc = function() return AP.sv.stepFont or "ZoFontGameSmall" end,
            setFunc = function(v)
                AP.sv.stepFont = v
                refreshUI()
            end,
            default = "ZoFontGameSmall",
            scrollable = true,
        },
        {
            type = "colorpicker",
            name = AP.L("SETTINGS_STEP_COLOR") or "Description color",
            getFunc = function()
                local c = AP.sv.stepColor or {0.72, 0.48, 0.30, 1}
                return c[1], c[2], c[3], c[4] or 1
            end,
            setFunc = function(r, g, b, a)
                AP.sv.stepColor = {r, g, b, a or 1}
                refreshUI()
            end,
            default = {0.72, 0.48, 0.30, 1},
        },
        {
            type = "dropdown",
            name = AP.L("SETTINGS_LANGUAGE"),
            tooltip = AP.L("SETTINGS_LANGUAGE_TIP"),
            choices = { "auto", "en", "pt", "de" },
            choicesValues = { "auto", "en", "pt", "de" },
            getFunc = function() return AP.sv.language or "auto" end,
            setFunc = function(v)
                AP.sv.language = v
                AP.LoadLanguage()
                refreshUI()
            end,
            default = "auto",
        },
        {
            type = "button",
            name = AP.L("SETTINGS_RESET_POS"),
            func = function()
                AP.sv.position = { point = TOPLEFT, relPoint = TOPLEFT, x = 40, y = 120 }
                if AP.UI then AP.UI:ApplyPosition() end
            end,
        },
    }
end
