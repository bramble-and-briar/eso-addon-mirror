--[[
    AetherPath - Core utilities
    Original code - no third-party sources
]]

AetherPath = AetherPath or {}
local AP = AetherPath
AP.Core = AP.Core or {}

local Core = AP.Core

function Core:Initialize()
end

function AP.L(key)
    local lang = AP.currentLang or "en"
    local t = AP.Strings and AP.Strings[lang]
    if t and t[key] then return t[key] end
    t = AP.Strings and AP.Strings["en"]
    return (t and t[key]) or key
end

function AP.LoadLanguage()
    local wanted = AP.sv and AP.sv.language or "auto"
    if wanted == "auto" then
        local gameLang = GetCVar("language.2") or "en"
        if AP.Strings and AP.Strings[gameLang] then
            AP.currentLang = gameLang
        else
            AP.currentLang = "en"
        end
    else
        AP.currentLang = (AP.Strings and AP.Strings[wanted]) and wanted or "en"
    end
end

-- Dark palette (base). Contrast setting brightens text / edges.
AP.ColorsBase = {
    bg          = {0.02, 0.02, 0.03, 0.94},
    bgHeader    = {0.04, 0.04, 0.06, 0.96},
    border      = {0.12, 0.13, 0.16, 0.9},
    text        = {0.78, 0.80, 0.84, 1},
    textDim     = {0.42, 0.44, 0.50, 1},
    accent      = {0.35, 0.55, 0.85, 1},
    accentDark  = {0.18, 0.28, 0.48, 1},
    complete    = {0.32, 0.70, 0.42, 1},
    incomplete  = {0.75, 0.48, 0.28, 1},
    danger      = {0.82, 0.28, 0.28, 1},
    favorite    = {0.88, 0.72, 0.22, 1},
}

AP.Colors = {}

local function clamp(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

-- contrast: 0.7 .. 1.4 (1 = default). Higher = brighter text/accent on dark bg.
function AP.ApplyContrast(contrast)
    contrast = tonumber(contrast) or 1
    if contrast < 0.7 then contrast = 0.7 end
    if contrast > 1.4 then contrast = 1.4 end
    local base = AP.ColorsBase
    for k, c in pairs(base) do
        local r, g, b, a = c[1], c[2], c[3], c[4]
        if k == "bg" or k == "bgHeader" then
            -- slightly deeper when contrast is high (more separation)
            local darken = 1 - (contrast - 1) * 0.15
            AP.Colors[k] = { clamp(r * darken), clamp(g * darken), clamp(b * darken), a }
        elseif k == "border" then
            AP.Colors[k] = { clamp(r * contrast), clamp(g * contrast), clamp(b * contrast), a }
        else
            AP.Colors[k] = { clamp(r * contrast), clamp(g * contrast), clamp(b * contrast), a }
        end
    end
end

-- init with default
AP.ApplyContrast(1)

function AP.SetControlColor(control, colorTable)
    if not control or not colorTable then return end
    if control.SetColor then
        control:SetColor(unpack(colorTable))
    elseif control.SetCenterColor then
        control:SetCenterColor(unpack(colorTable))
    end
end

function AP.FormatCost(cost)
    if not cost or cost <= 0 then return AP.L("FREE") end
    if ZO_Currency_FormatPlatform then
        return zo_strformat("|cFFD700<<1>>|r", ZO_Currency_FormatPlatform(CURT_MONEY, cost, ZO_CURRENCY_FORMAT_AMOUNT_ICON))
    end
    return tostring(cost)
end

function AP.CanTravelFree(nodeIndex)
    if AP.atWayshrine then return true end
    return false
end

ZO_CreateStringId("SI_BINDING_NAME_AETHERPATH_TOGGLE", "AbyssQuest: Toggle Tracker")
ZO_CreateStringId("SI_BINDING_NAME_AETHERPATH_TRAVEL", "AbyssQuest: Travel Panel")
ZO_CreateStringId("SI_BINDING_NAME_AETHERPATH_CYCLE", "AbyssQuest: Next Quest")
ZO_CreateStringId("SI_BINDING_NAME_AETHERPATH_LOCK", "AbyssQuest: Lock Tracker")


-- Fonts: named Zo* + Trajan/system via $(BOLD_FONT)/$(MEDIUM_FONT) etc.
AP.FontChoices = {
    "Game",
    "Game Small",
    "Game Large",
    "Game Outline",
    "Game Shadow",
    "Chat",
    "Window H1",
    "Window H2",
    "Window H3",
    "Window H4",
    "Window H5",
    "Header",
    "Header 2",
    "Header 3",
    "Callout",
    "Tooltip Title",
    "Tooltip Outline",
    "Announce Large",
    "Announce Medium",
    "Announce Small",
    "Window Title",
    "Window Subtitle",
    "Trajan Bold 14",
    "Trajan Bold 16",
    "Trajan Bold 18",
    "Trajan Bold 20",
    "Trajan Bold 22",
    "Trajan Medium 14",
    "Trajan Medium 16",
    "Trajan Medium 18",
    "Trajan Medium 20",
    "Trajan Soft 16",
    "Trajan Soft 18",
    "Trajan Soft 20",
    "Antique 16",
    "Antique 18",
    "Stone Tablet 16",
    "Stone Tablet 18",
    "Gamepad Bold 18",
    "Gamepad Bold 22",
    "Gamepad Medium 18",
    "Chat Soft 16",
    "Chat Soft 18",
}

AP.FontValues = {
    "ZoFontGame",
    "ZoFontGameSmall",
    "ZoFontGameLarge",
    "ZoFontGameOutline",
    "ZoFontGameShadow",
    "ZoFontChat",
    "ZoFontWinH1",
    "ZoFontWinH2",
    "ZoFontWinH3",
    "ZoFontWinH4",
    "ZoFontWinH5",
    "ZoFontHeader",
    "ZoFontHeader2",
    "ZoFontHeader3",
    "ZoFontCallout3",
    "ZoFontTooltipTitle",
    "ZoFontTooltipOutline",
    "ZoFontAnnounceLarge",
    "ZoFontAnnounceMedium",
    "ZoFontAnnounceSmall",
    "ZoFontWindowTitle",
    "ZoFontWindowSubtitle",
    "$(BOLD_FONT)|14|soft-shadow-thin",
    "$(BOLD_FONT)|16|soft-shadow-thin",
    "$(BOLD_FONT)|18|soft-shadow-thin",
    "$(BOLD_FONT)|20|soft-shadow-thin",
    "$(BOLD_FONT)|22|soft-shadow-thin",
    "$(MEDIUM_FONT)|14|soft-shadow-thin",
    "$(MEDIUM_FONT)|16|soft-shadow-thin",
    "$(MEDIUM_FONT)|18|soft-shadow-thin",
    "$(MEDIUM_FONT)|20|soft-shadow-thin",
    "$(BOLD_FONT)|16|soft-shadow-thick",
    "$(BOLD_FONT)|18|soft-shadow-thick",
    "$(BOLD_FONT)|20|soft-shadow-thick",
    "$(ANTIQUE_FONT)|16|soft-shadow-thin",
    "$(ANTIQUE_FONT)|18|soft-shadow-thin",
    "$(STONE_TABLET_FONT)|16|soft-shadow-thin",
    "$(STONE_TABLET_FONT)|18|soft-shadow-thin",
    "$(GAMEPAD_BOLD_FONT)|18|soft-shadow-thick",
    "$(GAMEPAD_BOLD_FONT)|22|soft-shadow-thick",
    "$(GAMEPAD_MEDIUM_FONT)|18|soft-shadow-thin",
    "$(CHAT_FONT)|16|soft-shadow-thin",
    "$(CHAT_FONT)|18|soft-shadow-thin",
}

AP.FontList = AP.FontValues

function AP.SafeFont(name)
    if type(name) == "string" and name ~= "" then
        return name
    end
    return "ZoFontGameSmall"
end

