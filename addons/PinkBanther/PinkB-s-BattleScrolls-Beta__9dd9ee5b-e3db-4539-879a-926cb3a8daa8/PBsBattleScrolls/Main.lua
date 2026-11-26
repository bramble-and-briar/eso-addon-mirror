PBsBattleScrolls = PBsBattleScrolls or {}
local ADDON = PBsBattleScrolls

---------------------------------------------------------------------------------------------------
-- Events, slash commands, start-up
--
-- Engine-side filters keep what reaches Lua small:
--   combat   two registrations: source = the player, source = a pet; errors filtered out.
--   effects  two registrations, made only while a fight goes on: unit = the player (buffs), and
--            source = the player (debuffs on others). The handlers check again in Lua, so a filter
--            the console ignores costs time, not correctness.
--   casts    EVENT_ACTION_SLOT_ABILITY_USED (one per button press).
--   ticks    one 500 ms update, only while a fight goes on.
---------------------------------------------------------------------------------------------------

local SAVED_VARS_NAME = "PBsBattleScrolls_Data"
local SAVED_VARS_VERSION = 1
local TICK_MS = 500
local DEBUG_LINES = 60

ADDON.defaults = {
    enabled = true,
    -- The HUD box.
    hud = true,
    hudHps = true,
    hudSize = 3,
    hudX = 60,
    hudY = 420,
    hudHoldSec = 10,
    hudAlpha = 50,
    -- When a fight ends: out of combat this long after the last event, or nothing for this long.
    endSec = 3,
    idleSec = 12,
    -- Shorter fights are not kept in the history.
    minSecs = 3,
    -- Debuffs the player keeps on enemies, on the buffs page.
    debuffs = true,
    -- Share DPS / HPS with group members who run this add-on (LibGroupBroadcast), and list them on the HUD.
    share = true,
    hudGroup = true,
    hudGroupRows = 6,
}

local fights = ADDON.fights
local L = ADDON.L
local Print = ADDON.Print
local sv
local debugLeft = 0
local effectsOn = false
local startErrors = {}

local counters = fights.counters
counters.fxSource = {}

---------------------------------------------------------------------------------------------------
-- Combat events
---------------------------------------------------------------------------------------------------

local HEAL_TARGET

local function OnCombat(_, result, isError, abilityName, _, slotType, _, sourceType, targetName, targetType, hitValue, _, _, _, _, _, abilityId, overflow)
    if isError then
        return
    end
    local fromPet = sourceType == COMBAT_UNIT_TYPE_PLAYER_PET
    local kind = fights.DamageResult(result)
    if kind then
        hitValue = tonumber(hitValue) or 0
        if targetType == COMBAT_UNIT_TYPE_PLAYER or hitValue <= 0 then
            return
        end
        if debugLeft > 0 then
            debugLeft = debugLeft - 1
            Print(string.format("[BS] dmg id=%s %s > %s type=%s hit=%s result=%s slot=%s pet=%s",
                tostring(abilityId), tostring(abilityName), tostring(targetName), tostring(targetType),
                tostring(hitValue), tostring(result), tostring(slotType), tostring(fromPet)))
        end
        fights:Damage(abilityId, abilityName, hitValue, kind, targetName, fromPet, slotType)
        return
    end
    kind = fights.HealResult(result)
    if kind then
        local hit, over = tonumber(hitValue) or 0, tonumber(overflow) or 0
        if hit <= 0 and over <= 0 then
            return
        end
        if debugLeft > 0 then
            debugLeft = debugLeft - 1
            Print(string.format("[BS] heal id=%s %s > %s type=%s hit=%s over=%s pet=%s",
                tostring(abilityId), tostring(abilityName), tostring(targetName), tostring(targetType),
                tostring(hit), tostring(over), tostring(fromPet)))
        end
        fights:Heal(abilityId, abilityName, hit, over, kind, targetName, HEAL_TARGET[targetType] or "other", fromPet)
    end
end

---------------------------------------------------------------------------------------------------
-- Effect events (registered while a fight goes on)
---------------------------------------------------------------------------------------------------

local function IsMine(sourceType)
    return sourceType == COMBAT_UNIT_TYPE_PLAYER or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET
end

local function OnEffectSelf(_, changeType, _, effectName, unitTag, beginTime, endTime, stackCount, _, _, effectType, _, _, _, _, abilityId, sourceType)
    counters.fxSelf = counters.fxSelf + 1
    if unitTag ~= "player" or effectType ~= BUFF_EFFECT_TYPE_BUFF then
        return
    end
    local key = tostring(sourceType)
    counters.fxSource[key] = (counters.fxSource[key] or 0) + 1
    fights:EffectChanged(changeType, effectName, beginTime, endTime, stackCount, abilityId, "p", IsMine(sourceType) and "own" or "ext")
end

local function OnEffectOut(_, changeType, _, effectName, unitTag, beginTime, endTime, stackCount, _, _, effectType, _, _, _, unitId, abilityId, sourceType)
    counters.fxOut = counters.fxOut + 1
    if unitTag == "player" or effectType ~= BUFF_EFFECT_TYPE_DEBUFF or not IsMine(sourceType) then
        return
    end
    fights:EffectChanged(changeType, effectName, beginTime, endTime, stackCount, abilityId, unitId or unitTag, "debuff")
end

local function OnTick()
    fights:Tick(GetFrameTimeSeconds())
end

local function ListenToFight(on)
    if on == effectsOn then
        return
    end
    effectsOn = on
    local em = EVENT_MANAGER
    local selfNs, outNs, tickNs = ADDON.name .. "FxSelf", ADDON.name .. "FxOut", ADDON.name .. "Tick"
    local bossNs, bossesNs = ADDON.name .. "BossHp", ADDON.name .. "Bosses"
    if on then
        -- bosses' health, filtered the way the client's boss bar does it
        em:RegisterForEvent(bossNs, EVENT_POWER_UPDATE, function(_, unitTag, _, _, value, max)
            ADDON.bosses:PowerUpdate(unitTag, value, max)
        end)
        em:AddFilterForEvent(bossNs, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG_PREFIX, "boss",
            REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_HEALTH)
        em:RegisterForEvent(bossesNs, EVENT_BOSSES_CHANGED, function() ADDON.bosses:Scan() end)
        em:RegisterForEvent(selfNs, EVENT_EFFECT_CHANGED, OnEffectSelf)
        em:AddFilterForEvent(selfNs, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
        if sv.debuffs then
            em:RegisterForEvent(outNs, EVENT_EFFECT_CHANGED, OnEffectOut)
            em:AddFilterForEvent(outNs, EVENT_EFFECT_CHANGED, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        end
        em:RegisterForUpdate(tickNs, TICK_MS, OnTick)
    else
        em:UnregisterForEvent(bossNs, EVENT_POWER_UPDATE)
        em:UnregisterForEvent(bossesNs, EVENT_BOSSES_CHANGED)
        em:UnregisterForEvent(selfNs, EVENT_EFFECT_CHANGED)
        em:UnregisterForEvent(outNs, EVENT_EFFECT_CHANGED)
        em:UnregisterForUpdate(tickNs)
    end
end

function ADDON.OnFightOpened()
    ListenToFight(true)
    ADDON.hud:Poke()
end

function ADDON.OnFightClosed(record)
    ListenToFight(false)
    ADDON.group:OnFightClosed(record)
    ADDON.hud:Refresh()
end

---------------------------------------------------------------------------------------------------
-- Switches
---------------------------------------------------------------------------------------------------

local combatOn = false

local function ListenToCombat(on)
    if on == combatOn then
        return
    end
    combatOn = on
    local em = EVENT_MANAGER
    local playerNs, petNs, castNs = ADDON.name .. "Combat", ADDON.name .. "Pet", ADDON.name .. "Cast"
    if on then
        em:RegisterForEvent(playerNs, EVENT_COMBAT_EVENT, OnCombat)
        em:AddFilterForEvent(playerNs, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
            REGISTER_FILTER_IS_ERROR, false)
        em:RegisterForEvent(petNs, EVENT_COMBAT_EVENT, OnCombat)
        em:AddFilterForEvent(petNs, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER_PET,
            REGISTER_FILTER_IS_ERROR, false)
        em:RegisterForEvent(castNs, EVENT_ACTION_SLOT_ABILITY_USED, function(_, slotIndex) fights:SlotUsed(slotIndex) end)
    else
        em:UnregisterForEvent(playerNs, EVENT_COMBAT_EVENT)
        em:UnregisterForEvent(petNs, EVENT_COMBAT_EVENT)
        em:UnregisterForEvent(castNs, EVENT_ACTION_SLOT_ABILITY_USED)
        fights:Close(GetFrameTimeSeconds())
    end
end

function ADDON.SetEnabled(value)
    sv.enabled = value and true or false
    ListenToCombat(sv.enabled)
    ADDON.hud:Refresh()
end

-- The debuff switch takes effect from the next fight.
function ADDON.SetDebuffs(value)
    sv.debuffs = value and true or false
end

local clearArmedUntil = 0

-- Deleting the history takes two presses within five seconds.
function ADDON.ClearHistory()
    local now = GetFrameTimeSeconds()
    if now > clearArmedUntil then
        clearArmedUntil = now + 5
        Print(L(SI_PBSBS_CLEAR_AGAIN))
        return false
    end
    clearArmedUntil = 0
    local history = ADDON.history
    for index = #history, 1, -1 do
        history[index] = nil
    end
    fights:Reset()
    if ADDON.screen.root then
        ADDON.screen:Latest()
    end
    ADDON.hud:Refresh()
    Print(L(SI_PBSBS_CLEARED))
    return true
end

---------------------------------------------------------------------------------------------------
-- Slash commands (/pbbs; the main menu entry is the way in on console, these are for checking)
---------------------------------------------------------------------------------------------------

local function PrintStatus()
    Print(string.format("[BS] %s  enabled=%s  inCombat=%s  live=%s  history=%d",
        ADDON.title, tostring(sv.enabled), tostring(fights.inCombat), tostring(fights.live ~= nil), #ADDON.history))
    Print(string.format("[BS] events: damage %d  heal %d  casts %d  effects on player %d  effects out %d  tracked effects %d",
        counters.dmg, counters.heal, counters.casts, counters.fxSelf, counters.fxOut, counters.fxTracked))
    Print(string.format("[BS] fights: started %d  kept %d  too short %d", counters.opened, counters.kept, counters.dropped))
    local parts = {}
    for key, count in pairs(counters.fxSource) do
        parts[#parts + 1] = key .. "=" .. count
    end
    table.sort(parts)
    Print("[BS] buff source types: " .. (#parts > 0 and table.concat(parts, " ") or "-"))
    local group = ADDON.group
    local can, why = group:CanSend()
    Print(string.format("[BS] group: %s  can send=%s%s  sent %d  refused %d  heard %d  own echoes %d  other version %d  members now %d",
        group.why, tostring(can), can and "" or (" (" .. tostring(why) .. ")"), group.sent, group.refused, group.heard,
        group.own, group.mismatched, group:CurrentCount(GetFrameTimeSeconds())))
    Print(string.format("[BS] bosses: scans %d  health updates %d", ADDON.bosses.scans, ADDON.bosses.updates))
    if group.lastError then
        Print("[BS] group read error: " .. group.lastError)
    end
    if #startErrors > 0 then
        Print("[BS] start-up errors: " .. table.concat(startErrors, " | "))
    end
    local live = fights.live
    if live then
        Print(string.format("[BS] live: %.1f s  damage %d  heal %d", live.lastT - live.startT, live.dmg, live.heal))
    end
end

local function OnSlash(argument)
    -- ASCII commands, compared as typed: no case folding of typed text (locale classes can cut UTF-8).
    local command = zo_strtrim(argument or "")
    if not sv then
        Print(string.format("[BS] %s: not started (%s)", ADDON.displayName, #startErrors > 0 and table.concat(startErrors, " | ") or "EVENT_ADD_ON_LOADED not seen"))
        return
    end
    if command == "" or command == "open" then
        ADDON.menu:Open()
    elseif command == "status" then
        PrintStatus()
    elseif command == "debug" then
        debugLeft = debugLeft > 0 and 0 or DEBUG_LINES
        Print(debugLeft > 0 and string.format(L(SI_PBSBS_DEBUG_ON), DEBUG_LINES) or L(SI_PBSBS_DEBUG_OFF))
    elseif command == "hud" then
        sv.hud = not sv.hud
        ADDON.hud:Refresh()
    elseif command == "end" then
        fights:Close(GetFrameTimeSeconds())
    elseif command == "clear" then
        ADDON.ClearHistory()
    else
        Print(L(SI_PBSBS_HELP))
    end
end

---------------------------------------------------------------------------------------------------
-- Start-up
---------------------------------------------------------------------------------------------------

local function ReadManifestVersion()
    local manager = GetAddOnManager()
    for index = 1, manager:GetNumAddOns() do
        local name, title = manager:GetAddOnInfo(index)
        if name == ADDON.name and title then
            local plain = title:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
            return plain:match("([%d]+[%d%.]*)%s*$") or ""
        end
    end
    return ""
end

-- Each start-up step runs on its own, so one failing does not stop the rest; failures are kept for
-- /pbbs status and named after login.
local function Step(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        startErrors[#startErrors + 1] = name .. ": " .. tostring(err)
    end
end

local function OnPlayerActivated()
    fights:SetCombat(IsUnitInCombat("player"))
    fights:WornSetsChanged()
    if not ADDON.announced then
        ADDON.announced = true
        -- Chat is up by now; a line printed at EVENT_ADD_ON_LOADED is lost.
        Print(string.format(L(SI_PBSBS_LOADED), ADDON.version))
        if #startErrors > 0 then
            Print("[BS] start-up errors: " .. table.concat(startErrors, " | "))
        end
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED)

    ADDON.version = ReadManifestVersion()
    ADDON.title = ADDON.version ~= "" and (ADDON.displayName .. " " .. ADDON.version) or ADDON.displayName

    sv = ZO_SavedVars:NewAccountWide(SAVED_VARS_NAME, SAVED_VARS_VERSION, nil, ADDON.defaults)
    ADDON.sv = sv
    -- The history is the character's own.
    local store = ZO_SavedVars:NewCharacterIdSettings(SAVED_VARS_NAME, SAVED_VARS_VERSION, "history", { fights = {} })
    ADDON.history = store.fights

    HEAL_TARGET = {
        [COMBAT_UNIT_TYPE_PLAYER] = "self",
        [COMBAT_UNIT_TYPE_GROUP] = "group",
    }

    local em = EVENT_MANAGER
    Step("group", function()
        ADDON.group:Setup()
        em:RegisterForEvent(ADDON.name .. "Group", EVENT_GROUP_UPDATE, function() ADDON.group:Prune() end)
        em:RegisterForEvent(ADDON.name .. "GroupLeft", EVENT_GROUP_MEMBER_LEFT, function() ADDON.group:Prune() end)
    end)
    Step("hud", function() ADDON.hud:Initialize() end)
    Step("menu", function() ADDON.menu:Initialize() end)
    Step("events", function()
        ListenToCombat(sv.enabled)
        em:RegisterForEvent(ADDON.name .. "State", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat) fights:SetCombat(inCombat) end)
        em:RegisterForEvent(ADDON.name .. "Worn", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function() fights:WornSetsChanged() end)
        em:AddFilterForEvent(ADDON.name .. "Worn", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
        em:RegisterForEvent(ADDON.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
        -- A loading screen ends the fight.
        em:RegisterForEvent(ADDON.name, EVENT_PLAYER_DEACTIVATED, function() fights:Close(GetFrameTimeSeconds()) end)
    end)
    Step("settings", function()
        if ADDON.InitializeSettings then
            ADDON.InitializeSettings()
        end
    end)
end

-- Registered at file load, so the command answers even if start-up fails.
SLASH_COMMANDS["/pbbs"] = OnSlash
EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
