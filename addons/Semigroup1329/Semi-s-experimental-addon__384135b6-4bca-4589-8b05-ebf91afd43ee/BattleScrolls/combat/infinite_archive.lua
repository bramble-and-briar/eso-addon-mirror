-----------------------------------------------------------
-- Infinite Archive
-- Records the Infinite Archive (the API's Endless Dungeon) run state a fight
-- began with: arc, cycle and stage, and the player's active Verses and
-- Visions (Mora's Boons).
--
-- StateObserver: captures at combat start, only inside a started run, the
-- way ZO_EndlessDungeonManager:UpdateDungeonBuffs reads an active run.
-- Nothing in the base game's UI blocks the boon selector or holds back
-- EVENT_ENDLESS_DUNGEON_BUFF_STACK_COUNT_UPDATED during combat, so a boon can
-- change mid-fight (e.g. a pick made while adds are still up). The record
-- keeps the boons the fight began with and flags such a change.
--
-- Stored as a section of the fight's binary payload (storage/binary.lua).
-- Local only: the wire layout the web export encodes never carries the
-- section, and the group summary has its own payload.
-----------------------------------------------------------

if not SemisPlaygroundCheckAccess() then
    return
end

BattleScrolls = BattleScrolls or {}

---@class InfiniteArchiveVision
---@field abilityId number
---@field stackCount number At least 1

---@class InfiniteArchiveRecord
---@field arc number
---@field cycle number
---@field stage number
---@field verses number[] Verse ability ids (ascending and distinct after a decode)
---@field visions InfiniteArchiveVision[] Visions (ascending by ability id after a decode)
---@field changedInCombat boolean A boon was gained or lost while the fight was still in combat

---@class InfiniteArchive : StateObserver
local infiniteArchive = {}
BattleScrolls.infiniteArchive = infiniteArchive

local EVENT_NAMESPACE = "BattleScrolls_InfiniteArchive"

-- =============================================================================
-- CAPTURE
-- =============================================================================

---Reads the active run's progression and boons the way the base game's
---ZO_EndlessDungeonManager:UpdateDungeonBuffs reads an active run.
---@return InfiniteArchiveRecord|nil record Nil outside a started, not yet completed run
function infiniteArchive.capture()
    if not IsInstanceEndlessDungeon() or not IsEndlessDungeonStarted() or IsEndlessDungeonCompleted() then
        return nil
    end

    local verses = {}
    for index = 1, GetNumEndlessDungeonActiveVerses() do
        verses[#verses + 1] = GetEndlessDungeonActiveVerseAbility(index)
    end

    ---@type InfiniteArchiveVision[]
    local visions = {}
    local abilityId, stackCount = GetNextEndlessDungeonVisionAbilityAndStackCount()
    while abilityId do
        -- The base game drops zero-stack entries from its own buff tables
        if stackCount and stackCount > 0 then
            visions[#visions + 1] = { abilityId = abilityId, stackCount = stackCount }
        end
        abilityId, stackCount = GetNextEndlessDungeonVisionAbilityAndStackCount(abilityId)
    end

    return {
        arc = GetEndlessDungeonCounterValue(ENDLESS_DUNGEON_COUNTER_TYPE_ARC),
        cycle = GetEndlessDungeonCounterValue(ENDLESS_DUNGEON_COUNTER_TYPE_CYCLE),
        stage = GetEndlessDungeonCounterValue(ENDLESS_DUNGEON_COUNTER_TYPE_STAGE),
        verses = verses,
        visions = visions,
        changedInCombat = false,
    }
end

-- =============================================================================
-- STATE OBSERVER
-- =============================================================================

local function onBuffStackCountUpdated()
    local state = BattleScrolls.state
    local record = state.infiniteArchive
    -- A pick made after combat dropped, while the encounter waits to close,
    -- did not affect the fight
    if not record or not state.inCombat then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_ENDLESS_DUNGEON_BUFF_STACK_COUNT_UPDATED)
    record.changedInCombat = true
end

function infiniteArchive:Initialize()
    BattleScrolls.state:RegisterObserver(self)
end

function infiniteArchive:OnStateInitialized()
    local record = infiniteArchive.capture()
    if not record then
        return
    end
    BattleScrolls.state.infiniteArchive = record
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ENDLESS_DUNGEON_BUFF_STACK_COUNT_UPDATED,
        onBuffStackCountUpdated)
end

function infiniteArchive:OnStatePreReset()
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_ENDLESS_DUNGEON_BUFF_STACK_COUNT_UPDATED)
end
