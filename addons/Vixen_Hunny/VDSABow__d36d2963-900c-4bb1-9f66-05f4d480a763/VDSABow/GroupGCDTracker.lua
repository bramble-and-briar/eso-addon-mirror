-- =============================================================================
-- GroupGCDTracker.lua  v2.0  —  core
-- =============================================================================
-- Tracks per-skill GCDs and Proximity Detonation timers for every member of
-- a group (up to 12).  Data comes from native ESO events only:
--   EVENT_ACTION_SLOT_ABILITY_USED  local player casts (most reliable)
--   EVENT_COMBAT_EVENT              casts by any resolvable group member
--   EVENT_EFFECT_CHANGED            Proximity Detonation buff gained / faded
--
-- State is always keyed by a *canonical* unit tag: the local player is stored
-- under "player" even when they also occupy a "groupN" slot.
--
-- Callbacks (GroupGCDTracker:RegisterCallback(event, fn)):
--   "GCD_START"          (unitTag, abilityId, abilityName, durationMs)
--   "GCD_END"            (unitTag, abilityId, abilityName)
--   "ABILITY_USED"       (unitTag, abilityId, abilityName)
--   "PROX_DET_ARMED"     (unitTag, abilityId, abilityName, durationMs)
--   "PROX_DET_TRIGGERED" (unitTag, abilityId, abilityName)
--
-- Public API:
--   :IsOnGCD(unitTag)            -> bool, msRemaining
--   :GetLastAbility(unitTag)     -> abilityId, abilityName
--   :GetAllGCDStates()           -> { [tag] = { onGCD, msRemaining, abilityId, abilityName } }
--   :IsProxDetArmed(unitTag, id) -> bool, armedAtMs
--   :GetStateTag(unitTag)        -> canonical tag used for state lookups
--   :GetLibrarySource()          -> "Native"
-- =============================================================================

GroupGCDTracker = GroupGCDTracker or {}
local T = GroupGCDTracker

T.NAME      = "GroupGCDTracker"
T.TITLE     = "Group GCD Tracker"
T.VERSION   = "2.0"
T.MAX_GROUP = 12

-- Trans-pride palette (hex for |c escapes, RGBA for controls)
T.HEX = { BLUE = "5BCEFA", PINK = "F5A9B8", WHITE = "FFFFFF", GREY = "9AA4B2" }

T._gcdState  = {}   -- [tag] = { onGCD, startTime, endTime, abilityId, abilityName }
T._proxState = {}   -- [tag] = { armed, armedAt, startMs, endMs, durationMs, abilityId, abilityName }
T._callbacks = {}
T._libSource = "Native"
T.settings   = {}

-- =============================================================================
-- Defaults
-- =============================================================================

T.DEFAULTS = {
    enabled                  = true,
    trackSelf                = true,
    gcdDurationMs            = 1000,
    trackProximityDet        = true,
    proxDetAbilityNames      = { ["Proximity Detonation"] = true },
    proxDetDefaultDurationMs = 8000,
    showChatAlerts           = false,
    debugMode                = false,

    -- HUD behaviour
    showUI         = true,
    hideInMenus    = true,    -- only show on the HUD, not in menus / inventory
    lockPosition   = false,
    showHeader     = true,
    showRoleIcons  = true,
    sortByRole     = true,    -- tanks, healers, then DPS
    hideGCD        = false,   -- DET column expands to fill the space
    uiX            = nil,     -- nil = centred
    uiY            = nil,
    uiOpacity      = 0.9,
    uiScale        = 1.0,
    fontSizeName   = 18,
    fontSizeTimer  = 15,
    fontSizeHeader = 20,

    -- HUD colours (RGBA)
    colorBarText  = { 1.00, 1.00, 1.00, 1.00 },
    colorNameLive = { 1.00, 1.00, 1.00, 1.00 },
    colorGcdFull  = { 0.357, 0.812, 0.980, 1.00 },  -- trans blue
    colorGcdLow   = { 0.961, 0.663, 0.722, 1.00 },  -- trans pink
    colorDetFull  = { 0.180, 0.850, 0.380, 1.00 },  -- green: plenty of time
    colorDetHigh  = { 1.000, 0.250, 0.300, 1.00 },  -- red: imminent
}

-- =============================================================================
-- Utilities
-- =============================================================================

local function Copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = Copy(x) end
    return out
end

function T.Print(fmt, ...)
    d(string.format("|c%s[GGCD]|r " .. fmt, T.HEX.BLUE, ...))
end

local function Debug(fmt, ...)
    if T.settings.debugMode then T.Print(fmt, ...) end
end

function T:RegisterCallback(event, fn)
    local list = self._callbacks[event]
    if not list then list = {}; self._callbacks[event] = list end
    list[#list + 1] = fn
end

local function Fire(event, ...)
    local list = T._callbacks[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then T.Print("|c%s%s callback error:|r %s", T.HEX.PINK, event, tostring(err)) end
    end
end

-- =============================================================================
-- Unit tags & names
-- =============================================================================

--- Canonical tag for state storage: any group slot that is the local player
-- collapses to "player".
local function CanonicalTag(tag)
    if tag and tag ~= "player" and AreUnitsEqual(tag, "player") then return "player" end
    return tag
end

function T:GetStateTag(tag) return CanonicalTag(tag) end

local function IsTrackedTag(tag)
    if tag == "player" then return T.settings.trackSelf end
    if type(tag) ~= "string" or tag:sub(1, 5) ~= "group" then return false end
    local idx = tonumber(tag:sub(6))
    return idx ~= nil and idx >= 1 and idx <= T.MAX_GROUP
end

--- Strip gender suffix/prefix formatting and any @account part.
function T.CleanName(name)
    if not name or name == "" then return "" end
    name = zo_strformat("<<1>>", name)
    return name:match("^([^@]+)") or name
end

local nameToTag = {}   -- cleaned character name -> tag
local idToTag   = {}   -- combat unitId          -> tag (learned from effect events)

local function RebuildNameCache()
    nameToTag = {}
    idToTag   = {}
    for i = 1, GetGroupSize() do
        local tag = GetGroupUnitTagByIndex(i)
        if tag and DoesUnitExist(tag) then
            nameToTag[T.CleanName(GetRawUnitName(tag))] = CanonicalTag(tag)
        end
    end
    nameToTag[T.CleanName(GetRawUnitName("player"))] = "player"
end

local function ResolveSource(sourceName, sourceUnitId, sourceType)
    if sourceType == COMBAT_UNIT_TYPE_PLAYER then return "player" end
    local tag = sourceUnitId and idToTag[sourceUnitId]
    if tag then return tag end
    if sourceName and sourceName ~= "" then
        return nameToTag[T.CleanName(sourceName)]
    end
end

-- =============================================================================
-- GCD
-- =============================================================================

local function StartGCD(tag, abilityId, abilityName)
    local S = T.settings
    if not S.enabled then return end
    tag = CanonicalTag(tag)
    if not IsTrackedTag(tag) then return end

    local now = GetGameTimeMilliseconds()
    local cur = T._gcdState[tag]
    -- Several event paths report the same cast; ignore duplicates while the
    -- GCD it started is still running.
    if cur and cur.onGCD and cur.abilityId == abilityId and now < cur.endTime then return end

    local dur = S.gcdDurationMs
    abilityName = abilityName or ""
    T._gcdState[tag] = {
        onGCD = true, startTime = now, endTime = now + dur,
        abilityId = abilityId, abilityName = abilityName,
    }

    Fire("GCD_START", tag, abilityId, abilityName, dur)
    Fire("ABILITY_USED", tag, abilityId, abilityName)
    if S.showChatAlerts then
        T.Print("%s -> |c%s%s|r (%d)", tag, T.HEX.PINK, abilityName ~= "" and abilityName or "?", abilityId or 0)
    end

    zo_callLater(function()
        local s = T._gcdState[tag]
        if s and s.onGCD and s.startTime == now then
            s.onGCD = false
            Fire("GCD_END", tag, abilityId, abilityName)
        end
    end, dur)
end

-- =============================================================================
-- Proximity Detonation
-- =============================================================================

local function IsProxDetAbility(abilityId, abilityName)
    local names = T.settings.proxDetAbilityNames
    if type(names) ~= "table" or next(names) == nil then names = T.DEFAULTS.proxDetAbilityNames end
    if not abilityName or abilityName == "" then abilityName = GetAbilityName(abilityId) or "" end
    return names[zo_strformat("<<1>>", abilityName)] == true
end

local function ClearProxDet(tag, abilityId, abilityName)
    T._proxState[tag] = nil
    Fire("PROX_DET_TRIGGERED", tag, abilityId, abilityName)
end

--- Arm (or re-arm) a detonation timer.  beginSec / endSec come from the buff
-- when available; otherwise the configured default duration is used.
local function ArmProxDet(tag, abilityId, abilityName, beginSec, endSec, via)
    local S = T.settings
    if not S.enabled or not S.trackProximityDet then return end

    local now = GetGameTimeMilliseconds()
    local durMs, remMs
    if beginSec and endSec and endSec > beginSec and (endSec - beginSec) < 120 then
        durMs = zo_round((endSec - beginSec) * 1000)
        remMs = zo_clamp(zo_round((endSec - GetFrameTimeSeconds()) * 1000), 0, durMs)
    else
        durMs = S.proxDetDefaultDurationMs
        remMs = durMs
    end

    local startMs = now - (durMs - remMs)
    T._proxState[tag] = {
        armed = true, armedAt = startMs, startMs = startMs, endMs = now + remMs,
        durationMs = durMs, abilityId = abilityId, abilityName = abilityName or "",
    }
    Debug("DET armed (%s): %s -> |c%s%s|r %dms", via, tag, T.HEX.PINK, abilityName or "?", durMs)
    Fire("PROX_DET_ARMED", tag, abilityId, abilityName, durMs)

    -- Safety net in case the FADED event is never seen (out of range, etc.).
    zo_callLater(function()
        local pd = T._proxState[tag]
        if pd and pd.startMs == startMs then ClearProxDet(tag, abilityId, pd.abilityName) end
    end, remMs + 1000)
end

-- =============================================================================
-- Event handlers
-- =============================================================================

local ACTIVATION_RESULTS = {
    [ACTION_RESULT_BEGIN]                  = true,
    [ACTION_RESULT_EFFECT_GAINED]          = true,
    [ACTION_RESULT_EFFECT_GAINED_DURATION] = true,
}

local function OnEffectChanged(_, changeType, _, effectName, unitTag, beginTime, endTime,
                               _, _, _, _, _, _, _, unitId, abilityId)
    if type(unitTag) ~= "string" then return end
    if unitTag ~= "player" and unitTag:sub(1, 5) ~= "group" then return end
    local tag = CanonicalTag(unitTag)
    if unitId and unitId ~= 0 then idToTag[unitId] = tag end
    if not IsTrackedTag(tag) or not IsProxDetAbility(abilityId, effectName) then return end

    if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
        ArmProxDet(tag, abilityId, zo_strformat("<<1>>", effectName), beginTime, endTime, "effect")
    elseif changeType == EFFECT_RESULT_FADED then
        local pd = T._proxState[tag]
        if pd and pd.abilityId == abilityId then ClearProxDet(tag, abilityId, pd.abilityName) end
    end
end

local function OnCombatEvent(_, result, isError, abilityName, _, slotType, sourceName, sourceType,
                             _, _, _, _, _, _, sourceUnitId, _, abilityId)
    if isError or not ACTIVATION_RESULTS[result] then return end
    -- Only skills cast from the bar; ignores procs, passives and set effects.
    if slotType ~= ACTION_SLOT_TYPE_ACTIVE_ABILITY and slotType ~= ACTION_SLOT_TYPE_ULTIMATE then return end

    local tag = ResolveSource(sourceName, sourceUnitId, sourceType)
    if not tag or not IsTrackedTag(tag) then return end

    local name = zo_strformat("<<1>>", abilityName)
    StartGCD(tag, abilityId, name)

    -- Fallback arm path for members whose effect events this client can't see.
    if T.settings.trackProximityDet and IsProxDetAbility(abilityId, name) then
        local pd = T._proxState[tag]
        if not pd or GetGameTimeMilliseconds() > pd.endMs then
            ArmProxDet(tag, abilityId, name, nil, nil, "combat")
        end
    end
end

local function OnSlotAbilityUsed(_, slotIndex)
    local id = GetSlotBoundId(slotIndex) or 0
    if id == 0 then return end
    StartGCD("player", id, zo_strformat("<<1>>", GetAbilityName(id)))
end

local function ScheduleNameCache(delay)
    zo_callLater(RebuildNameCache, delay)
end

-- =============================================================================
-- Saved variables
-- =============================================================================

local function LoadSettings()
    GroupGCDTracker_SavedVars = GroupGCDTracker_SavedVars or {}
    local sv = GroupGCDTracker_SavedVars
    for k, v in pairs(T.DEFAULTS) do
        if sv[k] == nil then sv[k] = Copy(v) end
    end
    T.settings = sv
end

function T:ResetSettings()
    local sv = GroupGCDTracker_SavedVars
    for k in pairs(sv) do sv[k] = nil end
    for k, v in pairs(self.DEFAULTS) do sv[k] = Copy(v) end
    if self.RefreshUI then self:RefreshUI() end
end

-- =============================================================================
-- Initialisation
-- =============================================================================

local function OnAddonLoaded(_, addonName)
    if addonName ~= T.NAME then return end
    local EM = EVENT_MANAGER
    EM:UnregisterForEvent(T.NAME, EVENT_ADD_ON_LOADED)

    LoadSettings()
    if T.BuildSettingsPanel then T:BuildSettingsPanel() end

    EM:RegisterForEvent(T.NAME, EVENT_COMBAT_EVENT, OnCombatEvent)
    EM:RegisterForEvent(T.NAME, EVENT_EFFECT_CHANGED, OnEffectChanged)
    EM:RegisterForEvent(T.NAME, EVENT_ACTION_SLOT_ABILITY_USED, OnSlotAbilityUsed)

    EM:RegisterForEvent(T.NAME, EVENT_PLAYER_ACTIVATED,     function() ScheduleNameCache(1500) end)
    EM:RegisterForEvent(T.NAME, EVENT_GROUP_MEMBER_JOINED,  function() ScheduleNameCache(500) end)
    EM:RegisterForEvent(T.NAME, EVENT_GROUP_MEMBER_LEFT,    function() ScheduleNameCache(500) end)
    EM:RegisterForEvent(T.NAME, EVENT_GROUP_UPDATE,         function() ScheduleNameCache(500) end)
    ScheduleNameCache(2000)

    if T.InitUI then T:InitUI() end
    Debug("v%s loaded", T.VERSION)
end

EVENT_MANAGER:RegisterForEvent(T.NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)

-- =============================================================================
-- Public API
-- =============================================================================

function T:IsOnGCD(unitTag)
    local s = self._gcdState[CanonicalTag(unitTag)]
    if not s or not s.onGCD then return false, 0 end
    local rem = s.endTime - GetGameTimeMilliseconds()
    if rem <= 0 then s.onGCD = false; return false, 0 end
    return true, rem
end

function T:GetLastAbility(unitTag)
    local s = self._gcdState[CanonicalTag(unitTag)]
    if not s then return nil, nil end
    return s.abilityId, s.abilityName
end

function T:GetAllGCDStates()
    local now, out = GetGameTimeMilliseconds(), {}
    for tag, s in pairs(self._gcdState) do
        local rem = s.onGCD and math.max(0, s.endTime - now) or 0
        out[tag] = { onGCD = rem > 0, msRemaining = rem, abilityId = s.abilityId, abilityName = s.abilityName }
    end
    return out
end

function T:IsProxDetArmed(unitTag, abilityId)
    local pd = self._proxState[CanonicalTag(unitTag)]
    if not pd or not pd.armed then return false, nil end
    if abilityId and pd.abilityId ~= abilityId then return false, nil end
    return true, pd.armedAt
end

function T:GetLibrarySource() return self._libSource end
