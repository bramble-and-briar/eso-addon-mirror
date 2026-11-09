-- =========================================================
-- MugShot - EsoAdapter  (ESO/EsoAdapter.lua)
-- Thin wrapper around ESO global API calls.
-- Isolates the rest of the codebase from raw ESO globals,
-- making unit testing without ESO globals straightforward.
-- =========================================================

local MugShot = MugShot

local EsoAdapter = {}
EsoAdapter.__index = EsoAdapter

-- Localized functions for Lua 5.1 bytecode speed (Code65536 / Baertram pattern)
local table_insert = table.insert
local table_sort   = table.sort

-- ── Constructor ───────────────────────────────────────────
function EsoAdapter.New()
    local self = setmetatable({}, EsoAdapter)
    self._effectsBuffer = {}
    self._mapByKey      = {}
    self._itemPool      = {}
    return self
end

-- ── ReadIdentity ──────────────────────────────────────────
-- Reads unit identity data from the ESO API.
-- @param  unitTag  string  e.g. "reticleover"
-- @return table {
--     name           : string
--     displayName    : string
--     isPlayer       : bool
--     reaction       : UnitReactionType constant
--     attackable     : bool
--     reactionR      : number (0–1)
--     reactionG      : number (0–1)
--     reactionB      : number (0–1)
--     portraitTexture: string | nil
--     raceIcon       : string | nil
--     allianceIcon   : string | nil
-- }
function EsoAdapter:ReadIdentity(unitTag)
    local name        = GetUnitName(unitTag) or ""
    local displayName = GetUnitDisplayName(unitTag) or ""
    local isPlayer    = IsUnitPlayer(unitTag) or false
    local reaction    = GetUnitReaction(unitTag) or UNIT_REACTION_DEFAULT
    local isLocal     = AreUnitsEqual(unitTag, "player")

    if unitTag == "player" or isLocal then
        isPlayer = true
        if displayName == "" or displayName == nil then
            displayName = GetDisplayName() or ""
        end
        if reaction == nil or reaction == UNIT_REACTION_DEFAULT then
            reaction = UNIT_REACTION_PLAYER_ALLY
        end
    end

    -- Reaction color resolution (Style mapping or API fallback)
    local r, g, b = 0.8, 0.8, 0.8
    local color = MugShot.Style.REACTION_COLORS[reaction]
    if color then
        r, g, b = color.r, color.g, color.b
    else
        local qr, qg, qb = GetUnitReactionColor(unitTag)
        if qr then r, g, b = qr, qg, qb end
    end

    local attackable = (IsUnitAttackable(unitTag) == true)

    -- Portrait and badge resolution
    local pInfo = MugShot.Portraits.GetPortraitInfo(unitTag) or {}

    return {
        name            = name,
        displayName     = displayName,
        isPlayer        = isPlayer,
        isLocalPlayer   = isLocal,
        reaction        = reaction,
        attackable      = attackable,
        reactionR       = r,
        reactionG       = g,
        reactionB       = b,
        portraitTexture = pInfo.portraitTexture,
        portraitCoords  = pInfo.portraitCoords,
        portraitColor   = pInfo.portraitColor,
        classIcon       = pInfo.classIcon,
        customIcon      = pInfo.customIcon,
        isClassIcon     = pInfo.isClassIcon,
        raceIcon        = pInfo.raceIcon,
        allianceIcon    = pInfo.allianceIcon,
        allianceBase    = pInfo.allianceBase,
        allianceColor   = pInfo.allianceColor,
        allianceId      = pInfo.allianceId,
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
    local cur, max, _effectiveMax = GetUnitPower(unitTag, COMBAT_MECHANIC_FLAGS_HEALTH)

    if cur == nil then
        return { healthKnown = false, currentHealth = nil, maxHealth = nil, shield = 0, isDead = false }
    end

    local isDead = IsUnitDead(unitTag)
    if cur <= 0 then
        isDead = true
    end

    -- Damage shield reading
    local shield = 0
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

    return {
        healthKnown   = true,
        currentHealth = cur,
        maxHealth     = max,
        shield        = shield,
        isDead        = isDead,
    }
end

-- ── IsInGroupOrCompanion ──────────────────────────────────
-- Returns true when player is in a group > 1 or has an active companion.
-- Official ESO API: IsUnitGrouped(), GetGroupSize(), HasActiveCompanion()
function EsoAdapter:IsInGroupOrCompanion()
    if IsUnitGrouped("player") and GetGroupSize() > 1 then
        return true
    end
    return HasActiveCompanion()
end

-- ── ReadEffects ───────────────────────────────────────────
-- Reads active buffs and debuffs on the unit.
-- In Solo mode (group size <= 1 without active companion), only effects cast by the player
-- are displayed on targets (sourceCount is strictly 1, no multi-source badges or cyan borders).
-- In Group mode (> 1) or with an active companion, all target effects are displayed,
-- and multiple casts of the same effect from team members merge into a single icon
-- showing the highest timer, the stack count, and the source multiplier (x2, x3) with cyan border.
-- On the "player" unitTag (move mode / player frame), all player effects are displayed.
-- @param  unitTag            string
-- @param  onlyPlayerCast     bool | nil (optional override)
-- @param  trackGroupDebuffs  bool | nil (default: true)
-- @param  outBuffer          table | nil (optional reusable array)
-- @return table array of { name, icon, stackCount, timeEnding, timer, castByPlayer, sourceCount, effectType }
function EsoAdapter:ReadEffects(unitTag, onlyPlayerCast, trackGroupDebuffs, outBuffer)
    local effects = outBuffer or self._effectsBuffer
    for i = #effects, 1, -1 do
        effects[i] = nil
    end
    if not DoesUnitExist(unitTag) then return effects end

    local isPlayerTag = (unitTag == "player")
    local inGroup = self:IsInGroupOrCompanion()

    local filterPlayer = false
    if not isPlayerTag then
        if onlyPlayerCast ~= nil then
            filterPlayer = onlyPlayerCast
        else
            filterPlayer = not inGroup or (trackGroupDebuffs == false)
        end
    end

    local allowMultiSource = inGroup and not filterPlayer and not isPlayerTag
    local now = GetGameTimeSeconds() or 0
    local mapByKey = self._mapByKey
    for k in pairs(mapByKey) do
        mapByKey[k] = nil
    end

    local pool = self._itemPool
    local itemCount = 0
    local numBuffs = GetNumBuffs(unitTag) or 0

    for i = 1, numBuffs do
        local buffName, _timeStarted, timeEnding, _buffSlot, stackCount, iconFilename, _buffType, effectType, _abilityType, _statusEffectType, abilityId, _canClickOff, castByPlayer = GetUnitBuffInfo(unitTag, i)
        if iconFilename and iconFilename ~= "" then
            local isCastByPlayer = castByPlayer or false

            if not filterPlayer or isCastByPlayer then
                local key = buffName or tostring(abilityId or i)
                local timer = (timeEnding and timeEnding > now) and (timeEnding - now) or 0
                local current = mapByKey[key]

                if not current then
                    itemCount = itemCount + 1
                    current = pool[itemCount]
                    if not current then
                        current = {}
                        pool[itemCount] = current
                    end
                    current.name         = buffName or ""
                    current.abilityId    = abilityId or 0
                    current.icon         = iconFilename
                    current.stackCount   = stackCount or 0
                    current.timeEnding   = timeEnding or 0
                    current.timer        = timer
                    current.castByPlayer = isCastByPlayer
                    current.sourceCount  = 1
                    current.effectType   = effectType or 0
                    current.key          = key
                    if isCastByPlayer then
                        current.playerTimer      = timer
                        current.playerTimeEnding  = timeEnding or 0
                        current.teamTimer        = 0
                        current.teamTimeEnding    = 0
                        current.castByPlayer     = true
                        current.castByTeam       = false
                    else
                        current.playerTimer      = 0
                        current.playerTimeEnding  = 0
                        current.teamTimer        = timer
                        current.teamTimeEnding    = timeEnding or 0
                        current.castByPlayer     = false
                        current.castByTeam       = true
                    end
                    current.winnerFromPlayer = isCastByPlayer
                    mapByKey[key]        = current
                    table_insert(effects, current)
                else
                    -- Merge duplicate casts (multi-source badge only in group mode)
                    if allowMultiSource then
                        current.sourceCount = current.sourceCount + 1
                    else
                        current.sourceCount = 1
                    end
                    if isCastByPlayer then
                        current.castByPlayer = true
                        if timer > (current.playerTimer or 0) then
                            current.playerTimer = timer
                            current.playerTimeEnding = timeEnding or 0
                        end
                    else
                        current.castByTeam = true
                        if timer > (current.teamTimer or 0) then
                            current.teamTimer = timer
                            current.teamTimeEnding = timeEnding or 0
                        end
                    end
                    if effectType and effectType > 0 then
                        current.effectType = effectType
                    end
                    -- Retain the highest remaining timer
                    local pTimer = current.playerTimer or 0
                    local tTimer = current.teamTimer or 0
                    current.timer = (pTimer > tTimer) and pTimer or tTimer
                    if timeEnding and timeEnding > current.timeEnding then
                        current.timeEnding = timeEnding
                    end
                    current.winnerFromPlayer = (pTimer >= tTimer) and (pTimer > 0)
                    -- Retain highest stack count
                    if stackCount and stackCount > current.stackCount then
                        current.stackCount = stackCount
                    end
                end
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
    if IsPlayerInRaid() then
        return true
    end
    if IsPlayerInRaidStagingArea() then
        return true
    end
    return false
end

MugShot.EsoAdapter = EsoAdapter
MugShot.logger:Info("=== EsoAdapter loaded ===")
