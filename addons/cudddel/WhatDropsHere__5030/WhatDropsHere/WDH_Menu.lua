-- WDH_Menu.lua
-- Einstellungsmenue ueber LibAddonMenu-2.0 (optional)
--
-- Fehlt LibAddonMenu, laeuft das Addon ohne Menue weiter; alle Einstellungen
-- bleiben ueber die Slash-Befehle erreichbar.
--
-- Wichtig: Alle Einstellungen wirken NUR auf die Anzeige am Fadenkreuz.
-- Gespeichert wird immer jede Pluenderung, jedes Item mit Item-ID und Kategorie.

local WDH  = WhatDropsHere
local Menu = {}
WDH.Menu = Menu

local PANEL_NAME = "WhatDropsHereMenu"

-- -----------------------------------------------------------------------------
-- Hilfsfunktionen
-- -----------------------------------------------------------------------------

local function Settings()
    return WDH_Saved.settings
end

-- Auswahlliste der Qualitaeten 0 (Trash) bis 5 (Legendaer), farbig
local function QualityChoices()
    local names, values = {}, {}
    for quality = ITEM_DISPLAY_QUALITY_TRASH, ITEM_DISPLAY_QUALITY_LEGENDARY do
        names[#names + 1]  = WDH.ColorByQuality(quality, WDH.QualityName(quality))
        values[#values + 1] = quality
    end
    return names, values
end

-- Checkbox fuer eine Anzeige-Einstellung; aendert sie, wird die Anzeige neu aufgebaut
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

-- Kurze Uebersicht ueber die gespeicherten Daten
local function DataSummary()
    local zones, sources, loots = 0, 0, 0
    for _, zone in pairs(WDH_Saved.zones) do
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
-- Initialisierung
-- -----------------------------------------------------------------------------

function Menu:Init()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local qualityNames, qualityValues = QualityChoices()

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

        -- Anzeige am Fadenkreuz
        { type = "header", name = WDH_STRINGS.MENU_HUD_HEADER },
        HudCheckbox("hud", WDH_STRINGS.MENU_HUD, WDH_STRINGS.MENU_HUD_TT),
        {
            type     = "dropdown",
            name     = WDH_STRINGS.MENU_SHOW_QUALITY,
            tooltip  = WDH_STRINGS.MENU_SHOW_QUALITY_TT,
            choices       = qualityNames,
            choicesValues = qualityValues,
            getFunc  = function() return Settings().showQuality end,
            setFunc  = function(value)
                Settings().showQuality = value
                WDH.Hud:Invalidate()
            end,
            disabled = HudDisabled,
            default  = ITEM_DISPLAY_QUALITY_NORMAL,
        },
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

        -- Anzeige nach Art der Quelle
        { type = "header", name = WDH_STRINGS.MENU_TYPES_HEADER },
        {
            type = "description",
            text = WDH_STRINGS.MENU_TYPES_INFO,
        },
        HudCheckbox("hudEnemies",    WDH_STRINGS.MENU_ENEMIES,    WDH_STRINGS.MENU_ENEMIES_TT,    HudDisabled),
        HudCheckbox("hudUnits",      WDH_STRINGS.MENU_UNITS,      WDH_STRINGS.MENU_UNITS_TT, function()
            return HudDisabled() or not Settings().hudEnemies
        end),
        HudCheckbox("hudContainers", WDH_STRINGS.MENU_CONTAINERS, WDH_STRINGS.MENU_CONTAINERS_TT, HudDisabled),
        HudCheckbox("hudResources",  WDH_STRINGS.MENU_RESOURCES,  WDH_STRINGS.MENU_RESOURCES_TT,  HudDisabled),
        HudCheckbox("hudOther",      WDH_STRINGS.MENU_OTHER,      WDH_STRINGS.MENU_OTHER_TT,      HudDisabled),
        HudCheckbox("hudTheft",      WDH_STRINGS.MENU_THEFT,      WDH_STRINGS.MENU_THEFT_TT,      HudDisabled),

        -- Datenbank
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

        -- Entwicklung
        { type = "header", name = WDH_STRINGS.MENU_DEV_HEADER },
        {
            type    = "checkbox",
            name    = WDH_STRINGS.MENU_DEBUG,
            tooltip = WDH_STRINGS.MENU_DEBUG_TT,
            getFunc = function() return Settings().debug end,
            setFunc = function(value) Settings().debug = value end,
            default = false,
        },
    })
end
