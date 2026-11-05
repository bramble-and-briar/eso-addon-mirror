-- =========================================================
-- MugShot - Presentation  (Core/Presentation.lua)
-- Transforms raw TargetState data into display-ready tables
-- consumed by TargetFrameView.  No ESO globals required;
-- pure data transformation with safe fallbacks.
-- =========================================================

local MugShot = MugShot

local Presentation = {}

-- Localized functions for Lua 5.1 bytecode speed (Code65536 / Baertram pattern)
local math_floor    = math.floor
local math_ceil     = math.ceil
local tostring      = tostring
local string_format = string.format

local RGBA                 = MugShot.Constants.RGBA
local COLOR_WHITE_ARRAY    = RGBA.WHITE_ARRAY
local COLOR_DEFAULT_BORDER = RGBA.DEFAULT_BORDER

-- Flyweight static tables for countdown timer seconds [1..120] and stack counts [1..50]
local TIMER_STRINGS = {}
for i = 1, 120 do
    TIMER_STRINGS[i] = tostring(i)
end

local STACK_STRINGS = {}
for i = 1, 50 do
    STACK_STRINGS[i] = tostring(i)
end

local SOURCE_STRINGS = {}
for i = 2, 20 do
    SOURCE_STRINGS[i] = "x" .. tostring(i)
end

-- Helper to abbreviate large numbers cleanly (2.1M, 24.3K, etc.)
-- Strict uppercase K and M to comply with user specifications.
local function FormatNumber(num)
    if not num then
        return "0"
    end
    local s
    if ZO_AbbreviateAndLocalizeNumber then
        s = ZO_AbbreviateAndLocalizeNumber(num, NUMBER_ABBREVIATION_PRECISION_TENTHS, true)
    elseif num >= 1000000 then
        s = string_format("%.1fM", num / 1000000):gsub("%.0M", "M")
    elseif num >= 1000 then
        s = string_format("%.1fK", num / 1000):gsub("%.0K", "K")
    else
        s = tostring(math_floor(num + 0.5))
    end
    s = tostring(s or num)
    return s:gsub("k", "K"):gsub("m", "M")
end

-- Helper to resolve custom nicknames from LibCustomNames or HodorReflexes
local function GetCustomPlayerName(displayName, rawName)
    local handle = displayName or ""
    if handle ~= "" and handle:sub(1, 1) ~= "@" then
        handle = "@" .. handle
    end
    local raw = (handle ~= "" and handle:sub(2)) or rawName or ""

    -- 1. LibCustomNames (Standard API for ESO custom nicknames)
    local LCN = _G.LibCustomNames
    if LCN and LCN.Get then
        local custom = (handle ~= "" and LCN.Get(handle, true))
            or (raw ~= "" and LCN.Get(raw, true))
            or (handle ~= "" and LCN.Get(handle:lower(), true))
            or (raw ~= "" and LCN.Get(raw:lower(), true))
        if custom and custom ~= "" then
            return custom
        end
    end

    -- 2. HodorReflexes util hook
    local HR = _G.HodorReflexes
    if HR and HR.util and HR.util.GetUserName then
        local custom = (handle ~= "" and HR.util.GetUserName(handle, true))
            or (raw ~= "" and HR.util.GetUserName(raw, true))
            or (handle ~= "" and HR.util.GetUserName(handle:lower(), true))
            or (raw ~= "" and HR.util.GetUserName(raw:lower(), true))
        if custom and custom ~= "" and custom ~= handle and custom ~= raw and custom ~= handle:lower() and custom ~= raw:lower() then
            return custom
        end
    end

    -- 3. HodorReflexes users table fallback
    if HR and HR.users then
        local u = (handle ~= "" and (HR.users[handle] or HR.users[handle:lower()]))
            or (raw ~= "" and (HR.users[raw] or HR.users[raw:lower()]))
        if u and u[1] and type(u[1]) == "string" and u[1] ~= "" then
            return u[1]
        end
    end

    return nil
end

-- ── BuildIdentity ─────────────────────────────────────────
-- @param  state     MugShot.TargetState instance
-- @param  _settings table returned by Settings:Get()
-- @return table  {
--     displayName    : string   (what to show in the name label)
--     isPlayer       : bool
--     reaction       : number
--     attackable     : bool
--     r, g, b        : number   (reaction colour, 0–1 range)
--     portraitTexture: string | nil
--     raceIcon       : string | nil
--     allianceIcon   : string | nil
--     allianceColor  : table | nil
-- }
function Presentation.BuildIdentity(state, _settings)
    local id = state.identity or {}
    local allowCustom = not _settings or (_settings.useHodorIcons ~= false)

    -- Player name formatting:
    -- If Hodor is ON (/mugshot hodor): Display custom nickname if available, else Account Name (@DisplayName).
    -- If Hodor is OFF: Strictly display Character Name (nom de perso).
    local nameStr
    if id.isPlayer then
        if allowCustom then
            local customName = GetCustomPlayerName(id.displayName, id.name)
            if customName and customName ~= "" then
                nameStr = customName
            elseif id.displayName and id.displayName ~= "" then
                nameStr = id.displayName
            elseif id.name and id.name ~= "" then
                nameStr = id.name
            else
                nameStr = MugShot.GetText("UNKNOWN") or "Unknown"
            end
        else
            if id.name and id.name ~= "" then
                nameStr = id.name
            elseif id.displayName and id.displayName ~= "" then
                nameStr = id.displayName
            else
                nameStr = MugShot.GetText("UNKNOWN") or "Unknown"
            end
        end
    else
        -- Non-player (NPC / Boss / Monster)
        if id.name and id.name ~= "" then
            nameStr = id.name
        elseif id.displayName and id.displayName ~= "" then
            nameStr = id.displayName
        else
            nameStr = MugShot.GetText("UNKNOWN") or "Unknown"
        end
    end

    -- Default colour: neutral grey when no reaction colour is set
    local r, g, b = 0.8, 0.8, 0.8
    if id.reactionR ~= nil then
        r, g, b = id.reactionR, id.reactionG, id.reactionB
    end

    local portraitTexture = id.portraitTexture
    local portraitCoords  = id.portraitCoords
    local portraitColor   = id.portraitColor or COLOR_WHITE_ARRAY

    local isDummyOrMissing = not portraitTexture or portraitTexture == ""
        or (type(portraitTexture) == "string" and (portraitTexture:find("campaignbrowser_guestcampaign", 1, true) or portraitTexture:find("icon_missing", 1, true)))

    -- If user explicitly disabled custom Hodor icons in settings, or if portrait is a dummy/question mark, fall back to class icon
    if id.classIcon and id.classIcon ~= "" then
        if not allowCustom or isDummyOrMissing then
            portraitTexture = id.classIcon
            portraitCoords  = nil
            portraitColor   = id.classColor or COLOR_WHITE_ARRAY
        end
    end

    return {
        displayName     = nameStr,
        isPlayer        = id.isPlayer or false,
        reaction        = id.reaction,
        attackable      = (id.attackable == true),
        r               = r,
        g               = g,
        b               = b,
        portraitTexture = portraitTexture,
        portraitCoords  = portraitCoords,
        portraitColor   = portraitColor,
        raceIcon        = id.raceIcon,
        allianceIcon    = id.allianceIcon,
        allianceColor   = id.allianceColor,
    }
end

-- ── BuildVitals ───────────────────────────────────────────
-- @param  state     MugShot.TargetState instance
-- @param  _settings table returned by Settings:Get()
-- @return table  {
--     healthKnown   : bool
--     percentText   : string         e.g. "70%" or "100%"
--     healthText    : string | nil   e.g. "2.1M/3.0M" or "24.3K/24.3K [3.6K]"
--     healthPercent : number | nil   0–1
--     shieldPercent : number | nil   0–1
--     shield        : number
-- }
function Presentation.BuildVitals(state, _settings)
    local v = (state and state.vitals) or {}

    if not v.healthKnown then
        return {
            healthKnown   = false,
            percentText   = "",
            healthText    = nil,
            healthPercent = nil,
            shieldPercent = 0,
            shield        = 0,
        }
    end

    local cur = v.currentHealth or 0
    local max = v.maxHealth     or 0
    local shield = v.shield     or 0
    local pct = (max > 0) and (cur / max) or 0
    local shieldPct = (max > 0) and (shield / max) or 0
    if shieldPct > 1 then shieldPct = 1 end

    local percentText = string_format("%d%%", math_floor(pct * 100 + 0.5))
    local healthText = FormatNumber(cur) .. "/" .. FormatNumber(max)
    if shield > 0 then
        healthText = healthText .. " [" .. FormatNumber(shield) .. "]"
    end

    return {
        healthKnown   = true,
        percentText   = percentText,
        healthText    = healthText,
        healthPercent = pct,
        shieldPercent = shieldPct,
        shield        = shield,
    }
end

-- ── FormatTimer ───────────────────────────────────────────
-- Formats countdown seconds cleanly:
--   < 60s  -> seconds ("59", "1") via Flyweight TIMER_STRINGS
--   >= 60s -> minutes ("1m", "59m")
--   >= 1h  -> hours ("1h", "2h")
local function FormatTimer(timer)
    if not timer or timer <= 0 then
        return ""
    end

    if timer >= 3600 then
        return string_format("%dh", math_floor(timer / 3600))
    elseif timer >= 60 then
        return string_format("%dm", math_floor(timer / 60))
    else
        local ceilTime = math_ceil(timer)
        if ceilTime >= 60 then
            return "1m"
        elseif ceilTime > 0 then
            return TIMER_STRINGS[ceilTime] or tostring(ceilTime)
        end
        return ""
    end
end

-- ── BuildEffects ──────────────────────────────────────────
-- Transforms raw active buffs into displayable items.
-- Supports an optional reusable output buffer to achieve 0 memory allocation per tick.
-- Excludes any effect listed in excludedNames table (to prevent duplication with privileged debuffs).
-- @param  state          MugShot.TargetState instance
-- @param  _settings      table
-- @param  outBuffer      table | nil (optional reusable array)
-- @param  excludedNames  table | nil (lookup table of names/tags to filter out)
-- @return table array of displayable effect items
function Presentation.BuildEffects(state, _settings, outBuffer, excludedNames, excludedAbilityIds)
    local raw = (state and state.effects) or {}
    local numRaw = #raw
    local items = outBuffer or {}
    local outIdx = 0

    for i = 1, numRaw do
        local eff = raw[i]
        local name = eff.name or ""
        local tag = eff.tag or ""
        local isExcluded = (eff._isPrivileged == true)
            or (excludedNames and (excludedNames[name] or (tag ~= "" and excludedNames[tag])))
            or (excludedAbilityIds and eff.abilityId and excludedAbilityIds[eff.abilityId])
        if not isExcluded then
            outIdx = outIdx + 1
            local timerText = FormatTimer(eff.timer)

            local stackText = ""
            local stacks = eff.stackCount
            if stacks and stacks > 1 then
                stackText = STACK_STRINGS[stacks] or tostring(stacks)
            end

            local sourceText = ""
            local sources = eff.sourceCount
            if sources and sources > 1 then
                sourceText = SOURCE_STRINGS[sources] or ("x" .. tostring(sources))
            end

            local isPlayerCast = (eff.castByPlayer == true)
            local isMultiSource = (sources and sources > 1)
            local borderStyle = MugShot.Style
            local border = isMultiSource and (borderStyle and (borderStyle.BORDER_COLOR_MULTI or borderStyle.BORDER_COLOR_GROUP)) or (borderStyle and borderStyle.BORDER_COLOR_PLAYER) or COLOR_DEFAULT_BORDER

            local isMajor = (eff.isMajor == true) or (name:find("Major") ~= nil or name:find("Majeur") ~= nil)
            local isMinor = (eff.isMinor == true) or (name:find("Minor") ~= nil or name:find("Mineur") ~= nil)

            local item = items[outIdx]
            if not item then
                item = {}
                items[outIdx] = item
            end
            item.name         = name
            item.icon         = eff.icon
            item.timerText    = timerText
            item.stackText    = stackText
            item.sourceText   = sourceText
            item.isPlayerCast = isPlayerCast
            item.effectType   = eff.effectType
            item.isMajor      = isMajor
            item.isMinor      = isMinor
            item.isGhost      = (eff.isGhost == true)
            item.borderR      = border.r or 0
            item.borderG      = border.g or 0
            item.borderB      = border.b or 0
            item.borderA      = border.a or 1
        end
    end

    -- Trim excess slots from previous ticks
    for i = outIdx + 1, #items do
        items[i] = nil
    end

    return items
end

MugShot.Presentation = Presentation
MugShot.logger:Info("=== Presentation loaded ===")
