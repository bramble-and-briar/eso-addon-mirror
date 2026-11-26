PBsBattleScrolls = PBsBattleScrolls or {}
local ADDON = PBsBattleScrolls

---------------------------------------------------------------------------------------------------
-- PB's Battle Scrolls
-- Author: PinkBanther
--
-- A light damage / healing meter for console. While the player fights it counts what the player (and
-- the player's pets) deal and heal, which buffs the player has and which debuffs the player keeps on
-- enemies, and which skills were pressed. A small HUD box shows the fight's DPS and HPS; a screen of
-- its own (main menu entry) breaks the fight down by skill, target, buff and cast, with an icon beside
-- every name. The last ten fights are kept.
--
-- What keeps it light:
--   * only events with the player (or a pet) as the source are delivered (engine-side filters); the
--     effect events are those on the player and those the player applied;
--   * every event is one table lookup and a few additions; nothing is drawn per event;
--   * a fight is folded into a small sorted record when it ends, capped per list, and only ten of
--     those are kept;
--   * the HUD redraws at most four times a second and only while it is up; the screen only while it
--     is open.
--
-- This file: the namespace and small helpers every other file uses.
---------------------------------------------------------------------------------------------------

ADDON.name = "PBsBattleScrolls"
ADDON.author = "PinkBanther"
ADDON.displayName = "PB’s Battle Scrolls"
ADDON.title = ADDON.displayName
ADDON.version = ""

function ADDON.Print(text)
    d(text)
end

function ADDON.L(id)
    return GetString(id)
end

-- 1234567 -> "1,234,567". Whole numbers only; negative numbers keep their sign.
function ADDON.Commas(number)
    number = math.floor((tonumber(number) or 0) + 0.5)
    local sign = number < 0 and "-" or ""
    local text = tostring(math.abs(number))
    local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if out:sub(1, 1) == "," then
        out = out:sub(2)
    end
    return sign .. out
end

-- 45210 -> "45.2k", 1234567 -> "1.23M"; below 10,000 the plain number with commas.
function ADDON.Short(number)
    number = tonumber(number) or 0
    local size = math.abs(number)
    if size >= 1000000 then
        return string.format("%.2fM", number / 1000000)
    elseif size >= 10000 then
        return string.format("%.1fk", number / 1000)
    end
    return ADDON.Commas(number)
end

-- Seconds -> "m:ss" (or "h:mm:ss").
function ADDON.Duration(seconds)
    seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, secs)
    end
    return string.format("%d:%02d", minutes, secs)
end

-- A fraction 0..1 -> "42.5%".
function ADDON.Percent(fraction, decimals)
    fraction = tonumber(fraction) or 0
    return string.format("%." .. (decimals or 1) .. "f%%", fraction * 100)
end

-- Seconds since local midnight -> "HH:MM".
function ADDON.Clock(sinceMidnight)
    sinceMidnight = math.floor(tonumber(sinceMidnight) or 0) % 86400
    return string.format("%02d:%02d", math.floor(sinceMidnight / 3600), math.floor((sinceMidnight % 3600) / 60))
end

-- A unit name without the client's gender / plural suffix ("Name^Mx" -> "Name"). Byte-wise: only
-- the ASCII caret is looked for, so Japanese names are untouched.
function ADDON.Plain(name)
    if type(name) ~= "string" then
        return ""
    end
    local caret = name:find("^", 1, true)
    if caret then
        name = name:sub(1, caret - 1)
    end
    return name
end

-- The icon the game has for an ability; nil when it has none (a blank path draws nothing useful).
function ADDON.Icon(abilityId)
    if type(GetAbilityIcon) ~= "function" or not abilityId or abilityId <= 0 then
        return nil
    end
    local icon = GetAbilityIcon(abilityId)
    if type(icon) ~= "string" or icon == "" or icon:find("icon_missing", 1, true) then
        return nil
    end
    return icon
end

-- The name of an ability in the client's language; "" when it has none.
function ADDON.AbilityName(abilityId)
    if type(GetAbilityName) ~= "function" or not abilityId or abilityId <= 0 then
        return ""
    end
    return ADDON.Plain(GetAbilityName(abilityId) or "")
end

---------------------------------------------------------------------------------------------------
-- Fonts: what the client draws, measured, not guessed (the Japanese client draws the named gamepad
-- fonts smaller than the number in their name).
---------------------------------------------------------------------------------------------------

local function FontProbe()
    local probe = ADDON.fontProbe
    if not probe then
        probe = WINDOW_MANAGER:CreateControl(ADDON.name .. "FontProbe", GuiRoot, CT_LABEL)
        probe:SetHidden(true)
        ADDON.fontProbe = probe
    end
    return probe
end

function ADDON.MeasureText(font, text)
    local probe = FontProbe()
    probe:SetFont(font)
    probe:SetText(text)
    local width = type(probe.GetTextWidth) == "function" and probe:GetTextWidth() or nil
    if type(width) ~= "number" or width <= 0 then
        return nil
    end
    return width
end

function ADDON.MeasureFont(font)
    local probe = FontProbe()
    probe:SetFont(font)
    local height = type(probe.GetFontHeight) == "function" and probe:GetFontHeight() or 0
    if type(height) ~= "number" or height <= 0 then
        height = math.ceil((tonumber(font:match("(%d+)$")) or 20) * 1.3)
    end
    return height
end
