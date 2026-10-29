-- =========================================================
-- MugShot - EsoAdapter  (ESO/EsoAdapter.lua)
-- Thin wrapper around ESO global API calls.
-- Isolates the rest of the codebase from raw ESO globals,
-- making unit testing without ESO globals straightforward.
-- =========================================================

local EsoAdapter = {}
EsoAdapter.__index = EsoAdapter

-- Localized functions for Lua 5.1 bytecode speed (Code65536 / Baertram pattern)
local table_insert = table.insert
local table_sort   = table.sort

-- ── Constructor ───────────────────────────────────────────
function EsoAdapter.New()
    return setmetatable({}, EsoAdapter)
end

-- ── ReadIdentity ──────────────────────────────────────────
-- Reads unit identity data from the ESO API.
-- @param  unitTag  string  e.g. "reticleover"
-- @return table {
--     name           : string
--     displayName    : string
--     isPlayer       : bool
--     reaction       : UnitReactionType constant
--     reactionR      : number (0–1)
--     reactionG      : number (0–1)
--     reactionB      : number (0–1)
--     portraitTexture: string | nil
--     raceIcon       : string | nil
--     allianceIcon   : string | nil
--     allianceColor  : table | nil
-- }
function EsoAdapter:ReadIdentity(unitTag)
    local name        = (GetUnitName and GetUnitName(unitTag)) or ""
    local displayName = (GetUnitDisplayName and GetUnitDisplayName(unitTag)) or ""
    local isPlayer    = (IsUnitPlayer and IsUnitPlayer(unitTag)) or false
    local reaction    = (GetUnitReaction and GetUnitReaction(unitTag)) or UNIT_REACTION_DEFAULT

    if unitTag == "player" then
        isPlayer = true
        if (reaction == nil or reaction == UNIT_REACTION_DEFAULT) and UNIT_REACTION_PLAYER_ALLY then
            reaction = UNIT_REACTION_PLAYER_ALLY
        end
    end

    -- Reaction color resolution (Style mapping or API fallback)
    local r, g, b = 0.8, 0.8, 0.8
    if MugShot.Style and MugShot.Style.REACTION_COLORS and MugShot.Style.REACTION_COLORS[reaction] then
        local c = MugShot.Style.REACTION_COLORS[reaction]
        r, g, b = c.r, c.g, c.b
    elseif GetUnitReactionColor then
        local qr, qg, qb = GetUnitReactionColor(unitTag)
        if qr then r, g, b = qr, qg, qb end
    end

    -- Portrait and badge resolution
    local pInfo = {}
    if MugShot.Portraits and MugShot.Portraits.GetPortraitInfo then
        pInfo = MugShot.Portraits.GetPortraitInfo(unitTag) or {}
    end

    return {
        name            = name,
        displayName     = displayName,
        isPlayer        = isPlayer,
        reaction        = reaction,
        reactionR       = r,
        reactionG       = g,
        reactionB       = b,
        portraitTexture = pInfo.portraitTexture,
        portraitCoords  = pInfo.portraitCoords,
        classIcon       = pInfo.classIcon,
        customIcon      = pInfo.customIcon,
        raceIcon        = pInfo.raceIcon,
        allianceIcon    = pInfo.allianceIcon,
        allianceColor   = pInfo.allianceColor,
    }
end

-- ── ReadVitals ────────────────────────────────────────────
-- Reads health power and damage shield via GetUnitPower and
-- GetUnitAttributeVisualizerEffectInfo.
-- MUST NOT be called if DoesUnitExist(unitTag) is false.
-- @param  unitTag  string
-- @return table {
--     healthKnown   : bool
--     currentHealth : number | nil
--     maxHealth     : number | nil
--     shield        : number
-- }
function EsoAdapter:ReadVitals(unitTag)
    local cur, max, _effectiveMax
    if GetUnitPower then
        cur, max, _effectiveMax = GetUnitPower(unitTag, COMBAT_MECHANIC_FLAGS_HEALTH)
    end

    if cur == nil then
        return { healthKnown = false, currentHealth = nil, maxHealth = nil, shield = 0, isDead = false }
    end

    local isDead = false
    if IsUnitDead then
        isDead = IsUnitDead(unitTag)
    end
    if cur <= 0 then
        isDead = true
    end

    -- Damage shield reading
    local shield = 0
    if GetUnitAttributeVisualizerEffectInfo and ATTRIBUTE_VISUAL_POWER_SHIELDING then
        local val = GetUnitAttributeVisualizerEffectInfo(
            unitTag,
            ATTRIBUTE_VISUAL_POWER_SHIELDING,
            STAT_MITIGATION,
            ATTRIBUTE_HEALTH,
            COMBAT_MECHANIC_FLAGS_HEALTH
        )
        if val and val > 0 then
            shield = val
        end
    end

    return {
        healthKnown   = true,
        currentHealth = cur,
        maxHealth     = max,
        shield        = shield,
        isDead        = isDead,
    }
end

-- ── ReadEffects ───────────────────────────────────────────
-- Reads active buffs and debuffs on the unit.
-- For target units, only effects cast by the player are retained by default
-- to avoid displaying raid-wide debuff clutter (e.g., 40+ debuffs in trials).
-- Single-pass filtering avoids allocating throwaway tables for other players' debuffs.
-- @param  unitTag         string
-- @param  onlyPlayerCast  bool | nil (default: true for targets, false for "player")
-- @return table array of { name, icon, stackCount, timeEnding, timer, castByPlayer }
function EsoAdapter:ReadEffects(unitTag, onlyPlayerCast)
    if not DoesUnitExist or not DoesUnitExist(unitTag) then return {} end
    if not GetNumBuffs or not GetUnitBuffInfo then return {} end

    local filterPlayer
    if onlyPlayerCast ~= nil then
        filterPlayer = onlyPlayerCast
    else
        filterPlayer = (unitTag ~= "player")
    end
    local now = (GetGameTimeSeconds and GetGameTimeSeconds()) or 0
    local effects = {}
    local numBuffs = GetNumBuffs(unitTag) or 0

    for i = 1, numBuffs do
        local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff, castByPlayer = GetUnitBuffInfo(unitTag, i)
        if iconFilename and iconFilename ~= "" then
            if not filterPlayer or castByPlayer then
                local timer = (timeEnding and timeEnding > now) and (timeEnding - now) or 0
                table_insert(effects, {
                    name         = buffName or "",
                    icon         = iconFilename,
                    stackCount   = stackCount or 0,
                    timeEnding   = timeEnding or 0,
                    timer        = timer,
                    castByPlayer = castByPlayer or false,
                })
            end
        end
    end

    -- Sort effects: player-applied first, then ascending remaining duration
    table_sort(effects, function(a, b)
        if a.castByPlayer ~= b.castByPlayer then
            return a.castByPlayer == true
        end
        if a.timer > 0 and b.timer > 0 then
            return a.timer < b.timer
        end
        if a.timer > 0 or b.timer > 0 then
            return a.timer > b.timer
        end
        return (a.name or "") < (b.name or "")
    end)

    return effects
end

-- ── IsInTrial ─────────────────────────────────────────────
-- Returns true when player is inside an active trial/raid or its staging area.
-- Official ESO API: IsPlayerInRaid() / IsPlayerInRaidStagingArea()
function EsoAdapter:IsInTrial()
    if IsPlayerInRaid and IsPlayerInRaid() then
        return true
    end
    if IsPlayerInRaidStagingArea and IsPlayerInRaidStagingArea() then
        return true
    end
    return false
end

MugShot.EsoAdapter = EsoAdapter
MugShot.logger:Info("=== EsoAdapter loaded ===")
