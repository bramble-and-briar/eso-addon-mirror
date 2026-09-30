local PriorityRecast = PriorityRecast
local Priorities     = PriorityRecast.Priorities
local SkillId        = PriorityRecast.SkillId

-------------------------------------------------------------------------------
-- ACTION SLOT MAPPING
-------------------------------------------------------------------------------
-- In order to get a skill's state, we must know where that skill is slotted.
-- This mapping is updated as needed.
-------------------------------------------------------------------------------

local BoundId = GetSlotBoundId
local ipairs  = ipairs

local bars    = {}
local slots   = {}


local function GetSlot(id)
	return bars[id], slots[id]
end


local function FindSlot(id)
	local id = SkillId(id)
	for _, bar in ipairs { 0, 1, 8 } do
		for slot = 3, 7 do
			if SkillId(BoundId(slot, bar)) == id
			then return bar, slot end
		end
	end
end


local function UpdateSlots()
	for _, id in Priorities.Iter() do
		bars[id], slots[id] = FindSlot(id)
	end
end

-------------------------------------------------------------------------------
-- SKILL DURATIONS
-------------------------------------------------------------------------------
-- Unfortunately, we can't directly use the time remaining function in the API
-- because several skills have rapid short-lived effects that bump the timer
-- when under one second. We must ignore these updates to have a smooth timer.
-------------------------------------------------------------------------------

local FrameTime     = GetFrameTimeMilliseconds
local TimeRemaining = GetActionSlotEffectTimeRemaining

local Timers = {
	[0] = { [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0 }, -- Front bar
	[1] = { [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0 }, -- Back bar
	[8] = { [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0 }, -- Werewolf
}


local function IsDurationOver(bar, slot, offset)
	local endTime = Timers[bar][slot] or 0
	return FrameTime() > endTime - offset
end


local function UpdateTimer(_, bar, slot)
	if not Timers[bar] then return end
	if not Timers[bar][slot] then return end

	local remaining = TimeRemaining(slot, bar)
	if remaining <= 1000 then return end

	local current = FrameTime()
	Timers[bar][slot] = current + remaining
end

-------------------------------------------------------------------------------
-- DETERMINE NEXT RECAST
-------------------------------------------------------------------------------

local IsReactive       = PriorityRecast.IsReactive
local IsActivated      = PriorityRecast.IsActivated
local IsExecute        = PriorityRecast.IsExecute
local ExecuteThreshold = PriorityRecast.ExecuteThreshold
local HasDuration      = PriorityRecast.HasDuration

local BoundId          = GetSlotBoundId
local EffectiveId      = GetEffectiveAbilityIdForAbilityOnHotbar
local HasHighlight     = ActionSlotHasActivationHighlight
local HasStateFailure  = ActionSlotHasNonCostStateFailure
local UnitPower        = GetUnitPower


-- Should Execute? ------------------------------------------------------------
-- Returns true if the current target's health is at or below the skill's
-- execute threshold.

local function ShouldExecute(skillId)

	-- Get current target's health values.
	local current, max = UnitPower("reticleover", 32)
	if current == 0 then return false end

	local threshold = ExecuteThreshold(skillId)
	return current / max <= threshold
end


-- Maybe Next -----------------------------------------------------------------
-- Re-returns a skill ID if the skill is ready to be cast. Nil if not ready.
-- The returned skill ID may differ because the bar/weapon can change the ID.

local function MaybeNext(skillId, offset)

	local bar, slot = GetSlot(skillId)
	if not slot then return nil end

	-- Ignore if skill can't be used right now.
	-- if HasStateFailure(slot, bar) then return nil end

	-- Handle reactive skill.
	if IsReactive(skillId) then
		if BoundId(slot, bar) == skillId
		then return skillId else return nil end
	end

	-- Handle activated skill.
	if IsActivated(skillId) then
		if HasHighlight(slot, bar) and IsDurationOver(bar, slot, offset)
		then return skillId else return nil end
	end

	-- Handle execute skill.
	if IsExecute(skillId) then
		if ShouldExecute(skillId)
		then return skillId else return nil end
	end

	-- Handle duration skill.
	if IsDurationOver(bar, slot, offset) then
		return EffectiveId(skillId, bar)
	end
end


-- Next Recast ----------------------------------------------------------------
-- Gets the next skill that is ready to cast by priority.

local function NextRecast()
	for _, skillId, offset in Priorities.Iter() do
		local skillId = MaybeNext(skillId, offset)
		if skillId then return skillId end
	end
end

-------------------------------------------------------------------------------
-- ADDON INITIALIZE
-------------------------------------------------------------------------------

PriorityRecast:RegisterCallback("AddonLoaded", function()

	-- Run initial slot mapping.
	UpdateSlots()

	-- Update mapping when the priorities change.
	PriorityRecast:RegisterCallback("PrioritiesUpdated", UpdateSlots)

	-- Setup game events.
	PriorityRecast:On(EVENT_ACTION_SLOT_EFFECT_UPDATE, UpdateTimer)
	PriorityRecast:On(EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, UpdateSlots)
end)

-------------------------------------------------------------------------------
-- EXPORTS
-------------------------------------------------------------------------------

PriorityRecast.NextRecast = NextRecast
