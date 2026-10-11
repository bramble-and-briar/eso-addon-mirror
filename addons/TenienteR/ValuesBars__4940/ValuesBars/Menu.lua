--[[
    Menu.lua
    Menú de ajustes con LibAddonMenu-2.0 (Ajustes > Addons > ValuesBars).
    La librería es opcional: sin ella el addon funciona con los valores por defecto.
    Todos los textos visibles salen de lang/*.lua a traves de VB.L(clave).
]]

ValuesBars = ValuesBars or {}
local VB = ValuesBars

local PANEL_ID = "ValuesBarsOptions"

function VB.InitMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local L = VB.L

    local function IsDisabled()
        return not VB.sv.enabled
    end

    local panelData = {
        type = "panel",
        name = VB.name,
        displayName = VB.name,
        author = "|c37FAC6Teniente.R|r",
        version = "1.0.0",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    -- Los grupos van de lo general a lo específico. Cada grupo empieza con un encabezado
    -- y dentro de él la opción que activa o desactiva va antes que las que dependen de ella.
    -- Las opciones nuevas se añaden dentro del grupo que les corresponda, con sus textos
    -- en lang/*.lua.
    local optionsData = {
        ---------------------------------------------------------------------
        -- General
        ---------------------------------------------------------------------
        {
            type = "header",
            name = L("MENU_HEADER_GENERAL"),
        },
        {
            type = "checkbox",
            name = L("MENU_SHOW_VALUES"),
            tooltip = L("MENU_SHOW_VALUES_TT"),
            getFunc = function() return VB.sv.enabled end,
            setFunc = function(value)
                VB.sv.enabled = value
                VB.ApplyEnabled()
                if not value then VB.SetPreview(false) end
            end,
            default = VB.defaults.enabled,
        },
        {
            type = "checkbox",
            name = L("MENU_PREVIEW"),
            tooltip = L("MENU_PREVIEW_TT"),
            getFunc = function() return VB.IsPreviewActive() end,
            setFunc = function(value) VB.SetPreview(value) end,
            default = false,
            disabled = IsDisabled,
        },

        ---------------------------------------------------------------------
        -- Texto y valores
        ---------------------------------------------------------------------
        {
            type = "header",
            name = L("MENU_HEADER_TEXT"),
        },
        {
            type = "slider",
            name = L("MENU_FONT_SIZE"),
            tooltip = L("MENU_FONT_SIZE_TT"),
            min = 14,
            max = 24,
            step = 1,
            getFunc = function() return VB.sv.fontSize end,
            setFunc = function(value)
                VB.sv.fontSize = value
                VB.ApplyFont()
            end,
            default = VB.defaults.fontSize,
            disabled = IsDisabled,
        },
        {
            type = "dropdown",
            name = L("MENU_CONTRAST"),
            tooltip = L("MENU_CONTRAST_TT"),
            choices = {
                L("MENU_CONTRAST_SOFT_THIN"),
                L("MENU_CONTRAST_SOFT_THICK"),
                L("MENU_CONTRAST_SHADOW"),
                L("MENU_CONTRAST_OUTLINE"),
            },
            choicesValues = { "soft-shadow-thin", "soft-shadow-thick", "shadow", "thick-outline" },
            getFunc = function() return VB.sv.fontStyle end,
            setFunc = function(value)
                VB.sv.fontStyle = value
                VB.ApplyFont()
            end,
            default = VB.defaults.fontStyle,
            disabled = IsDisabled,
        },
        {
            type = "dropdown",
            name = L("MENU_NUMBER_FORMAT"),
            tooltip = L("MENU_NUMBER_FORMAT_TT"),
            choices = { L("MENU_NUMBER_FORMAT_SEPARATED"), L("MENU_NUMBER_FORMAT_PLAIN") },
            choicesValues = { "separated", "plain" },
            getFunc = function() return VB.sv.numberFormat end,
            setFunc = function(value)
                VB.sv.numberFormat = value
                VB.RefreshAll()
            end,
            default = VB.defaults.numberFormat,
            disabled = IsDisabled,
        },
        {
            type = "checkbox",
            name = L("MENU_SHOW_PERCENT"),
            tooltip = L("MENU_SHOW_PERCENT_TT"),
            getFunc = function() return VB.sv.showPercent end,
            setFunc = function(value)
                VB.sv.showPercent = value
                VB.RefreshAll()
            end,
            default = VB.defaults.showPercent,
            disabled = IsDisabled,
        },

        ---------------------------------------------------------------------
        -- Barras del personaje
        ---------------------------------------------------------------------
        {
            type = "header",
            name = L("MENU_HEADER_PLAYER_BARS"),
        },
        {
            type = "dropdown",
            name = L("MENU_PLAYER_POSITION"),
            tooltip = L("MENU_PLAYER_POSITION_TT"),
            choices = { L("MENU_POSITION_INSIDE"), L("MENU_POSITION_ABOVE"), L("MENU_POSITION_BELOW") },
            choicesValues = { "inside", "above", "below" },
            getFunc = function() return VB.sv.playerBarsPosition end,
            setFunc = function(value)
                VB.sv.playerBarsPosition = value
                VB.ApplyPosition()
            end,
            default = VB.defaults.playerBarsPosition,
            disabled = IsDisabled,
        },
        {
            type = "slider",
            name = L("MENU_TEXT_GAP"),
            tooltip = L("MENU_TEXT_GAP_TT"),
            min = 0,
            max = 10,
            step = 1,
            getFunc = function() return VB.sv.textGap end,
            setFunc = function(value)
                VB.sv.textGap = value
                VB.ApplyPosition()
            end,
            default = VB.defaults.textGap,
            disabled = function()
                return not VB.sv.enabled or VB.sv.playerBarsPosition == "inside"
            end,
        },
        {
            type = "dropdown",
            name = L("MENU_MAGICKA_ALIGN"),
            tooltip = L("MENU_MAGICKA_ALIGN_TT"),
            choices = { L("MENU_ALIGN_CENTER"), L("MENU_ALIGN_RIGHT") },
            choicesValues = { "center", "right" },
            getFunc = function() return VB.sv.magickaAlign end,
            setFunc = function(value)
                VB.sv.magickaAlign = value
                VB.ApplyPosition()
            end,
            default = VB.defaults.magickaAlign,
            disabled = IsDisabled,
        },
        {
            type = "dropdown",
            name = L("MENU_STAMINA_ALIGN"),
            tooltip = L("MENU_STAMINA_ALIGN_TT"),
            choices = { L("MENU_ALIGN_CENTER"), L("MENU_ALIGN_LEFT") },
            choicesValues = { "center", "left" },
            getFunc = function() return VB.sv.staminaAlign end,
            setFunc = function(value)
                VB.sv.staminaAlign = value
                VB.ApplyPosition()
            end,
            default = VB.defaults.staminaAlign,
            disabled = IsDisabled,
        },
        {
            type = "dropdown",
            name = L("MENU_XP_ALIGN"),
            tooltip = L("MENU_XP_ALIGN_TT"),
            choices = { L("MENU_ALIGN_CENTER"), L("MENU_ALIGN_LEFT") },
            choicesValues = { "center", "left" },
            getFunc = function() return VB.sv.xpAlign end,
            setFunc = function(value)
                VB.sv.xpAlign = value
                VB.ApplyPosition()
            end,
            default = VB.defaults.xpAlign,
            disabled = IsDisabled,
        },

        ---------------------------------------------------------------------
        -- Habilidad máxima
        ---------------------------------------------------------------------
        {
            type = "header",
            name = L("MENU_HEADER_ULTIMATE"),
        },
        {
            type = "checkbox",
            name = L("MENU_ULTIMATE_SHOW"),
            tooltip = L("MENU_ULTIMATE_SHOW_TT"),
            getFunc = function() return VB.sv.showUltimatePercent end,
            setFunc = function(value)
                VB.sv.showUltimatePercent = value
                VB.RefreshAll()
            end,
            default = VB.defaults.showUltimatePercent,
            disabled = IsDisabled,
        },
        {
            type = "dropdown",
            name = L("MENU_ULTIMATE_POSITION"),
            tooltip = L("MENU_ULTIMATE_POSITION_TT"),
            choices = { L("MENU_ULTIMATE_TOP"), L("MENU_ULTIMATE_CENTER"), L("MENU_ULTIMATE_BOTTOM") },
            choicesValues = { "top", "center", "bottom" },
            getFunc = function() return VB.sv.ultimatePosition end,
            setFunc = function(value)
                VB.sv.ultimatePosition = value
                VB.ApplyPosition()
            end,
            default = VB.defaults.ultimatePosition,
            disabled = function() return IsDisabled() or not VB.sv.showUltimatePercent end,
        },
    }

    LAM:RegisterAddonPanel(PANEL_ID, panelData)
    LAM:RegisterOptionControls(PANEL_ID, optionsData)
end
