-- WDH_Menu.lua
-- Settings menu via LibAddonMenu-2.0 (optional)
--
-- Without LibAddonMenu the addon runs without a menu; all settings
-- stay available through the slash commands.
--
-- Important: all settings affect ONLY the crosshair display.
-- Every loot is always stored, every item with item ID and category.
-- Display settings are per character, the debug output is account-wide.

local WDH  = WhatDropsHere
local WDH_STRINGS = WDH.L
local Menu = {}
WDH.Menu = Menu

local PANEL_NAME = "WhatDropsHereMenu"

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------

local function Settings()
    return WDH.Settings()
end

-- Choice list of qualities 0 (trash) to 5 (legendary), colored
local function QualityChoices()
    local names, values = {}, {}
    for quality = ITEM_DISPLAY_QUALITY_TRASH, ITEM_DISPLAY_QUALITY_LEGENDARY do
        names[#names + 1]  = WDH.ColorByQuality(quality, WDH.QualityName(quality))
        values[#values + 1] = quality
    end
    return names, values
end

-- Like QualityChoices, with "Off" first (threshold per source type)
local function TypeChoices()
    local names, values = QualityChoices()
    table.insert(names, 1, WDH_STRINGS.MENU_SHOW_OFF)
    table.insert(values, 1, WDH.SHOW_OFF)
    return names, values
end

-- Checkbox for a display setting; changing it rebuilds the display
local function HudCheckbox(key, name, tooltip, disabled)
    return {
        type     = "checkbox",
        name     = name,
        tooltip  = tooltip,
        getFunc  = function() return Settings()[key] end,
        setFunc  = function(value)
            Settings()[key] = value
            WDH.Hud:Invalidate()
        end,
        disabled = disabled,
        default  = true,
    }
end

local function HudDisabled()
    return not Settings().hud
end

-- Display threshold choice for one source type
local function TypeDropdown(key, name, tooltip, names, values)
    return {
        type          = "dropdown",
        name          = name,
        tooltip       = tooltip,
        choices       = names,
        choicesValues = values,
        getFunc       = function() return Settings()[key] end,
        setFunc       = function(value)
            Settings()[key] = value
            WDH.Hud:Invalidate()
        end,
        disabled      = HudDisabled,
        default       = ITEM_DISPLAY_QUALITY_NORMAL,
    }
end

-- Short overview of the stored data
local function DataSummary()
    local zones, sources, loots = 0, 0, 0
    for _, zone in pairs(WDH.sv.zones) do
        local any = false
        for _, rec in pairs(zone) do
            any     = true
            sources = sources + 1
            loots   = loots + rec.loots
        end
        if any then zones = zones + 1 end
    end
    return string.format(WDH_STRINGS.MENU_DATA_SUMMARY, zones, sources, loots)
end

-- -----------------------------------------------------------------------------
-- Initialization
-- -----------------------------------------------------------------------------

function Menu:Init()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local qualityNames, qualityValues = QualityChoices()
    local typeNames, typeValues       = TypeChoices()

    -- Other characters whose settings can be copied
    local charNames, charIds = WDH.OtherCharacters()
    local copyFrom = charIds[1]
    local noChars  = #charIds == 0
    if noChars then
        charNames, charIds = { WDH_STRINGS.MENU_COPY_NONE }, { "" }
    end

    LAM:RegisterAddonPanel(PANEL_NAME, {
        type               = "panel",
        name               = "What Drops Here?",
        displayName        = "What Drops Here?",
        author             = "@Cudddel",
        version            = WDH.VERSION,
        slashCommand       = "/wdh_menu",
        registerForRefresh = true,
    })

    LAM:RegisterOptionControls(PANEL_NAME, {
        {
            type = "description",
            text = WDH_STRINGS.MENU_INTRO,
        },

        -- Crosshair display
        { type = "header", name = WDH_STRINGS.MENU_HUD_HEADER },
        {
            type = "description",
            text = string.format(WDH_STRINGS.MENU_CHAR_INFO, WDH.sv.chars[WDH.charId].name),
        },
        HudCheckbox("hud", WDH_STRINGS.MENU_HUD, WDH_STRINGS.MENU_HUD_TT),
        {
            type     = "dropdown",
            name     = WDH_STRINGS.MENU_NAME_QUALITY,
            tooltip  = WDH_STRINGS.MENU_NAME_QUALITY_TT,
            choices       = qualityNames,
            choicesValues = qualityValues,
            getFunc  = function() return Settings().nameQuality end,
            setFunc  = function(value)
                Settings().nameQuality = value
                WDH.Hud:Invalidate()
            end,
            disabled = HudDisabled,
            default  = ITEM_DISPLAY_QUALITY_ARCANE,
        },
        {
            type     = "slider",
            name     = WDH_STRINGS.MENU_MAX_LINES,
            tooltip  = WDH_STRINGS.MENU_MAX_LINES_TT,
            min      = 1,
            max      = 15,
            step     = 1,
            getFunc  = function() return Settings().hudMaxLines end,
            setFunc  = function(value)
                Settings().hudMaxLines = value
                WDH.Hud:Invalidate()
            end,
            disabled = HudDisabled,
            default  = 6,
        },

        -- Display by source type
        { type = "header", name = WDH_STRINGS.MENU_TYPES_HEADER },
        {
            type = "description",
            text = WDH_STRINGS.MENU_TYPES_INFO,
        },
        TypeDropdown("showEnemy",     WDH_STRINGS.MENU_ENEMIES,    WDH_STRINGS.MENU_ENEMIES_TT,    typeNames, typeValues),
        HudCheckbox("hudUnits",       WDH_STRINGS.MENU_UNITS,      WDH_STRINGS.MENU_UNITS_TT, function()
            return HudDisabled() or Settings().showEnemy == WDH.SHOW_OFF
        end),
        TypeDropdown("showContainer", WDH_STRINGS.MENU_CONTAINERS, WDH_STRINGS.MENU_CONTAINERS_TT, typeNames, typeValues),
        TypeDropdown("showResource",  WDH_STRINGS.MENU_RESOURCES,  WDH_STRINGS.MENU_RESOURCES_TT,  typeNames, typeValues),
        TypeDropdown("showOther",     WDH_STRINGS.MENU_OTHER,      WDH_STRINGS.MENU_OTHER_TT,      typeNames, typeValues),
        TypeDropdown("showTheft",     WDH_STRINGS.MENU_THEFT,      WDH_STRINGS.MENU_THEFT_TT,      typeNames, typeValues),
        TypeDropdown("showExcavation", WDH_STRINGS.MENU_EXCAVATION, WDH_STRINGS.MENU_EXCAVATION_TT, typeNames, typeValues),

        -- Settings of other characters
        { type = "header", name = WDH_STRINGS.MENU_COPY_HEADER },
        {
            type = "description",
            text = WDH_STRINGS.MENU_COPY_INFO,
        },
        {
            type          = "dropdown",
            name          = WDH_STRINGS.MENU_COPY_FROM,
            tooltip       = WDH_STRINGS.MENU_COPY_FROM_TT,
            choices       = charNames,
            choicesValues = charIds,
            getFunc       = function() return copyFrom or "" end,
            setFunc       = function(value) copyFrom = value end,
            disabled      = noChars,
            scrollable    = true,
        },
        {
            type        = "button",
            name        = WDH_STRINGS.MENU_COPY,
            tooltip     = WDH_STRINGS.MENU_COPY_TT,
            isDangerous = true,
            warning     = WDH_STRINGS.MENU_COPY_WARNING,
            disabled    = noChars,
            func        = function()
                if WDH.CopySettingsFrom(copyFrom) then
                    for i, id in ipairs(charIds) do
                        if id == copyFrom then
                            d(string.format(WDH_STRINGS.COPY_DONE, charNames[i]))
                        end
                    end
                end
            end,
        },

        -- Database
        { type = "header", name = WDH_STRINGS.MENU_DATA_HEADER },
        {
            type = "description",
            text = WDH_STRINGS.MENU_DATA_INFO,
        },
        {
            type = "description",
            text = DataSummary,
        },
        {
            type  = "button",
            name  = WDH_STRINGS.MENU_ZONES,
            tooltip = WDH_STRINGS.MENU_ZONES_TT,
            func  = function() WDH:PrintZones() end,
        },
        {
            type        = "button",
            name        = WDH_STRINGS.MENU_RESET,
            tooltip     = WDH_STRINGS.MENU_RESET_TT,
            isDangerous = true,
            warning     = WDH_STRINGS.MENU_RESET_WARNING,
            func        = function() WDH:ResetData() end,
        },

        -- Development
        { type = "header", name = WDH_STRINGS.MENU_DEV_HEADER },
        {
            type    = "checkbox",
            name    = WDH_STRINGS.MENU_DEBUG,
            tooltip = WDH_STRINGS.MENU_DEBUG_TT,
            getFunc = function() return WDH.sv.settings.debug end,
            setFunc = function(value) WDH.sv.settings.debug = value end,
            default = false,
        },
    })
end
