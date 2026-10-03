BETABars = BETABars or {}
local T = BETABars

local function L(key, fallback)
    local loc = T.L or {}
    return loc[key] or fallback or key
end

local function Vars()
    return T.savedVars
end

local function ColorGet(tbl, d1, d2, d3, d4)
    if type(tbl) ~= "table" then
        return d1, d2, d3, d4
    end
    return tonumber(tbl[1]) or d1, tonumber(tbl[2]) or d2, tonumber(tbl[3]) or d3, tonumber(tbl[4]) or d4
end

local function ColorSet(tbl, r, g, b, a)
    tbl[1] = r
    tbl[2] = g
    tbl[3] = b
    tbl[4] = a or 1
end

local function Refresh()
    if T.Apply then T.Apply() end
end

local STYLE_ORDER = { "thin", "segments", "classic", "orbs" }

local function StyleLabel(id)
    if id == "segments" then return L("STYLE_SEG", "Segments") end
    if id == "classic" then return L("STYLE_CLASSIC", "Classic") end
    if id == "orbs" then return L("STYLE_ORB", "Orbs") end
    return L("STYLE_THIN", "Thin")
end

local function StyleItems()
    return {
        { name = L("STYLE_THIN", "Thin"), data = "thin" },
        { name = L("STYLE_SEG", "Segments"), data = "segments" },
        { name = L("STYLE_CLASSIC", "Classic"), data = "classic" },
        { name = L("STYLE_ORB", "Orbs"), data = "orbs" },
    }
end

function T.RegisterSettings()
    local LibHarven = LibHarvensAddonSettings
    if not LibHarven then return end
    local vars = Vars()
    if not vars then return end

    local settings = LibHarven:AddAddon(L("TITLE", "BETA Bars"), {
        allowRefresh = true,
        allowDefaults = true,
    })
    if not settings then return end
    settings.version = "0.1.1"
    settings.author = "Tetsurion"

    settings:AddSetting({
        type = LibHarven.ST_LABEL,
        label = L("INFO", "Info"),
        tooltip = L("INFO_TT", ""),
        canSelect = true,
    })

    settings:AddSetting({
        type = LibHarven.ST_CHECKBOX,
        label = L("ENABLED", "Enabled"),
        tooltip = L("ENABLED_TT", ""),
        default = true,
        getFunction = function()
            return vars.enabled ~= false
        end,
        setFunction = function(val)
            vars.enabled = val and true or false
            Refresh()
        end,
    })

    settings:AddSetting({
        type = LibHarven.ST_DROPDOWN,
        label = L("STYLE", "Style"),
        tooltip = L("STYLE_TT", ""),
        items = StyleItems(),
        default = L("STYLE_THIN", "Thin"),
        getFunction = function()
            return StyleLabel(vars.style or "thin")
        end,
        setFunction = function(_, _, item)
            local id = item and item.data or "thin"
            local ok = false
            for i = 1, #STYLE_ORDER do
                if STYLE_ORDER[i] == id then ok = true end
            end
            vars.style = ok and id or "thin"
            Refresh()
        end,
    })

    settings:AddSetting({
        type = LibHarven.ST_CHECKBOX,
        label = L("HIDE_STOCK", "Hide default bars"),
        tooltip = L("HIDE_STOCK_TT", "Removes the official bars from the HUD. If another addon puts them back, this takes them off again. Werewolf keeps the official bars."),
        default = true,
        getFunction = function()
            return vars.hideStock ~= false
        end,
        setFunction = function(val)
            vars.hideStock = val and true or false
            Refresh()
        end,
    })

    settings:AddSetting({
        type = LibHarven.ST_CHECKBOX,
        label = L("HIDE_FULL", "Hide when full, out of combat"),
        tooltip = L("HIDE_FULL_TT", ""),
        default = true,
        getFunction = function()
            return vars.hideFull ~= false
        end,
        setFunction = function(val)
            vars.hideFull = val and true or false
            Refresh()
        end,
    })

    settings:AddSetting({
        type = LibHarven.ST_CHECKBOX,
        label = L("NUMBERS", "Numbers"),
        tooltip = L("NUMBERS_TT", "Current amount only, to the right of the bar. Max is not shown."),
        default = false,
        getFunction = function()
            return vars.showNumbers == true
        end,
        setFunction = function(val)
            vars.showNumbers = val and true or false
            Refresh()
        end,
    })

    settings:AddSetting({
        type = LibHarven.ST_CHECKBOX,
        label = L("PERCENT", "Percent"),
        tooltip = L("PERCENT_TT", "A second column, further right. Off by default."),
        default = false,
        getFunction = function()
            return vars.showPercent == true
        end,
        setFunction = function(val)
            vars.showPercent = val and true or false
            Refresh()
        end,
    })

    settings:AddSetting({
        type = LibHarven.ST_CHECKBOX,
        label = L("TAIL", "Damage tail"),
        tooltip = L("TAIL_TT", ""),
        default = true,
        getFunction = function()
            return vars.damageTail ~= false
        end,
        setFunction = function(val)
            vars.damageTail = val and true or false
            Refresh()
        end,
    })

    settings:AddSetting({
        type = LibHarven.ST_CHECKBOX,
        label = L("SHIELD", "Shield rim"),
        tooltip = L("SHIELD_TT", ""),
        default = true,
        getFunction = function()
            return vars.shieldRim ~= false
        end,
        setFunction = function(val)
            vars.shieldRim = val and true or false
            Refresh()
        end,
    })

    settings:AddSetting({
        type = LibHarven.ST_CHECKBOX,
        label = L("NOTCH", "Cost notches"),
        tooltip = L("NOTCH_TT", ""),
        default = true,
        getFunction = function()
            return vars.notches ~= false
        end,
        setFunction = function(val)
            vars.notches = val and true or false
            Refresh()
        end,
    })

    settings:AddSetting({
        type = LibHarven.ST_SLIDER,
        label = L("SCALE", "Scale"),
        tooltip = L("SCALE_TT", ""),
        min = 50,
        max = 150,
        step = 5,
        default = 100,
        getFunction = function()
            return tonumber(vars.scale) or 100
        end,
        setFunction = function(val)
            vars.scale = tonumber(val) or 100
            Refresh()
        end,
    })

    settings:AddSetting({
        type = LibHarven.ST_SLIDER,
        label = L("OFFX", "Horizontal offset"),
        tooltip = "",
        min = -900,
        max = 900,
        step = 10,
        default = 0,
        getFunction = function()
            return tonumber(vars.offsetX) or 0
        end,
        setFunction = function(val)
            vars.offsetX = tonumber(val) or 0
            Refresh()
        end,
    })

    settings:AddSetting({
        type = LibHarven.ST_SLIDER,
        label = L("OFFY", "Vertical offset"),
        tooltip = "",
        min = -500,
        max = 500,
        step = 10,
        default = 220,
        getFunction = function()
            return tonumber(vars.offsetY) or 220
        end,
        setFunction = function(val)
            vars.offsetY = tonumber(val) or 220
            Refresh()
        end,
    })

    if LibHarven.ST_COLOR then
        settings:AddSetting({
            type = LibHarven.ST_COLOR,
            label = L("COLOR_H", "Health color"),
            tooltip = "",
            default = { 0.80, 0.18, 0.16, 1 },
            getFunction = function()
                return ColorGet(vars.colorH, 0.80, 0.18, 0.16, 1)
            end,
            setFunction = function(r, g, b, a)
                if type(vars.colorH) ~= "table" then vars.colorH = {} end
                ColorSet(vars.colorH, r, g, b, a)
                Refresh()
            end,
        })
        settings:AddSetting({
            type = LibHarven.ST_COLOR,
            label = L("COLOR_M", "Magicka color"),
            tooltip = "",
            default = { 0.22, 0.48, 0.95, 1 },
            getFunction = function()
                return ColorGet(vars.colorM, 0.22, 0.48, 0.95, 1)
            end,
            setFunction = function(r, g, b, a)
                if type(vars.colorM) ~= "table" then vars.colorM = {} end
                ColorSet(vars.colorM, r, g, b, a)
                Refresh()
            end,
        })
        settings:AddSetting({
            type = LibHarven.ST_COLOR,
            label = L("COLOR_S", "Stamina color"),
            tooltip = "",
            default = { 0.28, 0.72, 0.34, 1 },
            getFunction = function()
                return ColorGet(vars.colorS, 0.28, 0.72, 0.34, 1)
            end,
            setFunction = function(r, g, b, a)
                if type(vars.colorS) ~= "table" then vars.colorS = {} end
                ColorSet(vars.colorS, r, g, b, a)
                Refresh()
            end,
        })
    end

    settings:AddSetting({
        type = LibHarven.ST_CHECKBOX,
        label = L("PREVIEW", "Preview sample"),
        tooltip = L("PREVIEW_TT", ""),
        default = false,
        getFunction = function()
            return vars.preview == true
        end,
        setFunction = function(val)
            vars.preview = val and true or false
            Refresh()
        end,
    })
end
