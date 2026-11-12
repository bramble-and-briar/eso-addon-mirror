---------------------------------------------------------------------------
-- Stats.lua - ultimate, DPS/HPS and weapon bar of each member
--
-- Pure data: GroupFrames.lua calls GF.GetUlt, GF.GetCombat and GF.GetBar
-- every tick and draws what they return. Each of them answers with nil
-- when nothing is known about a member, and the frame then shows nothing.
---------------------------------------------------------------------------

local GF = GroupFrames

-- Ultimate, DPS and HPS of group members come from LibGroupCombatStats.
-- Which weapon bar a member is on is not available from any library, so
-- GroupFrames shares it itself through LibGroupBroadcast (only members who
-- run GroupFrames show up).
--
-- NOTE: protocol ids must be unique across all addons. Reserve this one at
-- https://wiki.esoui.com/LibGroupBroadcast_IDs before releasing the addon.
local BAR_PROTOCOL_ID = 231
local BAR_PROTOCOL_NAME = "GroupFramesWeaponBar"

local lgcs -- LibGroupCombatStats object, nil when not installed
local barProtocol -- LibGroupBroadcast protocol for the weapon bar, nil if unavailable
local memberOnBackBar = {} -- @account -> true (back bar) / false (front bar)
local lastSentBack -- what we last told the group, to avoid repeating it

---------------------------------------------------------------------------
-- Ultimate / DPS / HPS
---------------------------------------------------------------------------

-- Action slot of the ultimate (the game's constant is zero-based).
local ULTIMATE_SLOT = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1

-- Your own current ultimate, read straight from the action bar.
local function GetPlayerUlt()
    local hotbar = GetActiveHotbarCategory()
    local abilityId = GetSlotBoundId(ULTIMATE_SLOT, hotbar)
    if not abilityId or abilityId == 0 then return nil, nil end
    local cost = GetSlotAbilityCost(ULTIMATE_SLOT, COMBAT_MECHANIC_FLAGS_ULTIMATE, hotbar)
    if not cost or cost == 0 then cost = nil end
    return abilityId, cost
end

-- Picks the ultimate on the member's active bar from the shared data. When
-- the bar is unknown, or that bar has no ultimate slotted, the other one is
-- used.
local function GetSharedUlt(unitTag, data)
    local frontId, backId = data.ult1ID or 0, data.ult2ID or 0
    local frontCost, backCost = data.ult1Cost or 0, data.ult2Cost or 0
    local abilityId, cost = frontId, frontCost
    if GF.GetBar(unitTag) then abilityId, cost = backId, backCost end
    if abilityId == 0 then
        if frontId ~= 0 then
            abilityId, cost = frontId, frontCost
        else
            abilityId, cost = backId, backCost
        end
    end
    if abilityId == 0 then abilityId = nil end
    if cost == 0 then cost = nil end
    return abilityId, cost
end

-- Returns for the unit's current ultimate (the one on its active bar):
-- ultimate points, cost to cast it, ability id. Cost and id are nil when
-- unknown; returns nil when there is no data at all.
function GF.GetUlt(unitTag)
    local data = lgcs and lgcs:GetUnitULT(unitTag)

    if AreUnitsEqual(unitTag, "player") then
        local value = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_ULTIMATE)
        local abilityId, cost = GetPlayerUlt()
        if data and not (abilityId and cost) then
            local sharedId, sharedCost = GetSharedUlt(unitTag, data)
            abilityId, cost = abilityId or sharedId, cost or sharedCost
        end
        return value, cost, abilityId
    end

    if not data or data._lastUpdated == 0 then return nil end
    local abilityId, cost = GetSharedUlt(unitTag, data)
    return data.ultValue, cost, abilityId
end

-- Returns DPS and HPS of the unit in thousands (0 when out of combat), or
-- nil when LibGroupCombatStats is not installed.
function GF.GetCombat(unitTag)
    if not lgcs then return nil end
    local dps = lgcs:GetUnitDPS(unitTag)
    local hps = lgcs:GetUnitHPS(unitTag)
    return dps and dps.dps or 0, hps and hps.hps or 0
end

---------------------------------------------------------------------------
-- Weapon bar
---------------------------------------------------------------------------

-- True while your second weapon set is active.
local function IsPlayerOnBackBar()
    return GetActiveWeaponPairInfo() == ACTIVE_WEAPON_PAIR_BACKUP
end

-- Returns true when the unit is on its back bar, false on the front bar and
-- nil when unknown (the member does not run GroupFrames or does not share).
function GF.GetBar(unitTag)
    if AreUnitsEqual(unitTag, "player") then
        return IsPlayerOnBackBar()
    end
    return memberOnBackBar[GetUnitDisplayName(unitTag) or ""]
end

-- Tells the group which bar you are on, if that changed since last time.
-- The message is a single flag, the smallest LibGroupBroadcast can send,
-- because bar swaps happen every few seconds in combat.
local function SendBar()
    if not (barProtocol and GF.sv.shareBar and IsUnitGrouped("player")) then return end
    local back = IsPlayerOnBackBar()
    if back == lastSentBack then return end
    if not barProtocol:IsEnabled() then return end
    if barProtocol:Send({ backBar = back }) then
        lastSentBack = back
    end
end

local function ResendBar()
    -- somebody new may be listening: send the current bar again
    lastSentBack = nil
    zo_callLater(SendBar, 2000)
end

-- Called by LibGroupBroadcast when a groupmate reports their bar.
local function OnBarData(unitTag, data)
    if AreUnitsEqual(unitTag, "player") then return end
    memberOnBackBar[GetUnitDisplayName(unitTag) or ""] = data.backBar == true
end

-- Declares the weapon bar protocol on the handler Share.lua registered and
-- hooks the events that should trigger a send.
local function InitBarSharing()
    local LGB = LibGroupBroadcast
    local handler = GF.lgbHandler
    if not (LGB and handler) then return end

    local ok = pcall(function()
        local declared = handler:DeclareProtocol(BAR_PROTOCOL_ID, BAR_PROTOCOL_NAME)
        declared:SetDisplayName("Active weapon bar")
        declared:AddField(LGB.CreateFlagField("backBar"))
        declared:OnData(OnBarData)
        if not declared:Finalize({ isRelevantInCombat = true, replaceQueuedMessages = true }) then
            error("the protocol could not be finalized")
        end
        barProtocol = declared
    end)
    if not ok then return end

    local name = GF.name .. "Bar"
    -- the event fires at the start (locked) and end of a swap; send at the end
    EVENT_MANAGER:RegisterForEvent(name, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function(_, _, locked)
        if not locked then SendBar() end
    end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_GROUP_MEMBER_JOINED, ResendBar)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, ResendBar)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_GROUP_MEMBER_LEFT, function()
        if not IsUnitGrouped("player") then
            ZO_ClearTable(memberOnBackBar)
            lastSentBack = nil
        end
    end)
end

-- Called once at start-up, after GF.InitSharing. Registering with
-- LibGroupCombatStats also makes it broadcast your own ultimate, DPS and
-- HPS to the group - that is how the library works for every addon.
function GF.InitStats()
    local LGCS = LibGroupCombatStats
    if LGCS and LGCS.RegisterAddon then
        local ok, result = pcall(LGCS.RegisterAddon, GF.name, { "ULT", "DPS", "HPS" })
        if ok then lgcs = result end
    end
    GF.hasCombatStats = lgcs ~= nil

    InitBarSharing()
    GF.canShareBar = barProtocol ~= nil
end
