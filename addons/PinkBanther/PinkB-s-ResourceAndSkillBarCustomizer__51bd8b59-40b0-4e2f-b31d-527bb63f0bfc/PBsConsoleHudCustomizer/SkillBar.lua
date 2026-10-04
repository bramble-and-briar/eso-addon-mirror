-- PBS_CONSOLE_HUD_CUSTOMIZER is nil if Main.lua bailed out early (e.g. already loaded).
if not PBS_CONSOLE_HUD_CUSTOMIZER then
	return
end

local addon = PBS_CONSOLE_HUD_CUSTOMIZER
local Round = addon.Round
local Clamp = addon.Clamp

-- ---------------------------------------------------------------------------------------
-- The gaps along the skill bar
--
-- The game chains the buttons left to right with ActionButton:ApplyAnchor, which is nothing but
--
--     self.slot:SetAnchor(LEFT, target, RIGHT, offsetX, 0)      -- or RIGHT on LEFT, going left
--
-- and the offsets come from GAMEPAD_CONSTANTS in actionbar.lua:
--
--     abilitySlotOffsetX  = 10     between the five abilities
--     ultimateSlotOffsetX = 65     the ultimate, out on its own past the fifth
--     weaponSwapOffsetX   = 61     where the weapon swap marker sits inside the bar
--     quickslotOffsetXFromFirstSlot = 5    the quickslot, 5 to the left of that marker
--
-- The marker itself (ZO_ActionBar1WeaponSwap) is permanently hidden on the gamepad
-- (showWeaponSwapButton = false), but it is still a control with a width, and the quickslot is
-- anchored to the far side of it. So the gap the player actually sees between the item and the
-- first ability is 5 + the marker's width + 10 -- the reason it looks so far away, and the reason
-- this add-on anchors the quickslot to the first ability directly instead. The number in the
-- settings panel is then the gap on screen, not a number with an invisible control inside it.
--
-- Three gaps, three writes of the same shape as the game's own. A gap is only written once the
-- player has moved it; the game's own are measured off the controls first, so an untouched
-- install is still indistinguishable from not having the add-on.
-- ---------------------------------------------------------------------------------------

local skillbar = {}
addon.skillbar = skillbar

addon.GAP_KEYS = { "skill", "ultimate", "item" }
addon.MIN_GAP = 0
addon.MAX_GAP = 150

-- Only used until the real ones are measured.
addon.GAP_FALLBACK = { skill = 10, ultimate = 65, item = 60 }

local FIRST_SLOT = (ACTION_BAR_FIRST_NORMAL_SLOT_INDEX or 2) + 1
local LAST_ABILITY_SLOT = (ACTION_BAR_FIRST_NORMAL_SLOT_INDEX or 2) + (ACTION_BAR_SLOTS_PER_PAGE or 6) - 1
local ULTIMATE_SLOT = (ACTION_BAR_ULTIMATE_SLOT_INDEX or 7) + 1

local QUICKSLOT_NAME = "QuickslotButton"
local COMPANION_NAME = "CompanionUltimateButton"

-- ---------------------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------------------

function addon:Spacing()
	return self:Account().spacing
end

function addon:MeasuredGaps()
	local measured = self:Account().measured
	if type(measured.spacing) ~= "table" then
		measured.spacing = {}
	end
	return measured.spacing
end

-- The gap the game itself leaves: measured where it could be, worked out from its own constants
-- where it could not.
function addon:GameGap(key)
	local measured = self:MeasuredGaps()[key]
	if type(measured) == "number" then
		return measured
	end
	return self.GAP_FALLBACK[key]
end

function addon:Gap(key)
	local saved = self:Spacing()[key]
	if type(saved) == "number" then
		return Clamp(Round(saved), self.MIN_GAP, self.MAX_GAP)
	end
	return self:GameGap(key)
end

function addon:SetGap(key, value)
	self:Spacing()[key] = Clamp(Round(value), self.MIN_GAP, self.MAX_GAP)
end

function addon:SpacingDiffers()
	if not self:SkillBarAllowed() then
		return false
	end
	for _, key in ipairs(self.GAP_KEYS) do
		if self:Gap(key) ~= self:GameGap(key) then
			return true
		end
	end
	return false
end

function addon:ResetSpacing()
	self:Account().spacing = {}
end

-- ---------------------------------------------------------------------------------------
-- The controls
-- ---------------------------------------------------------------------------------------

local function Control(name)
	local control = _G[name]
	if type(control) ~= "table" and type(control) ~= "userdata" then
		return nil
	end
	if type(control.SetAnchor) ~= "function" then
		return nil
	end
	return control
end

function skillbar:Button(slot)
	return Control("ActionButton" .. slot)
end

function skillbar:Quickslot()
	return Control(QUICKSLOT_NAME)
end

-- The companion's ultimate is only in the row while a companion is out: the client hides its
-- slot with SetEnabled(false) otherwise (ActionButton:SetEnabled), and re-anchors the quickslot
-- past it in SetCompanionAnchors.
function skillbar:CompanionUltimate()
	local control = Control(COMPANION_NAME)
	if not control or type(control.IsHidden) ~= "function" then
		return nil
	end
	-- Its own flag: with the whole bar hidden behind a menu, the drawn state says "hidden" for a
	-- companion that is out, and the bar would be laid out as if it were not.
	if addon.OwnHidden(control) then
		return nil
	end
	return control
end

-- Every control this add-on re-anchors, in the order they sit on the bar.
function skillbar:Each(fn)
	for slot = FIRST_SLOT + 1, LAST_ABILITY_SLOT do
		local control = self:Button(slot)
		if control then
			fn(control, "skill", self:Button(slot - 1))
		end
	end
	local ultimate = self:Button(ULTIMATE_SLOT)
	local lastAbility = self:Button(LAST_ABILITY_SLOT)
	if ultimate and lastAbility then
		fn(ultimate, "ultimate", lastAbility)
	end
	-- Leftwards from the first ability: the companion's ultimate where there is one, then the
	-- quickslot. Both get the item gap, so the left-hand end of the bar keeps one spacing.
	local target = self:Button(FIRST_SLOT)
	local companion = self:CompanionUltimate()
	if companion and target then
		fn(companion, "item", target, true)
		target = companion
	end
	local quickslot = self:Quickslot()
	if quickslot and target then
		fn(quickslot, "item", target, true)
	end
end

-- ---------------------------------------------------------------------------------------
-- Measuring, and putting back
-- ---------------------------------------------------------------------------------------

local function ReadAnchor(control, index)
	local ok, isValid, point, relativeTo, relativePoint, offsetX, offsetY, constrains = pcall(control.GetAnchor, control, index)
	if not ok or not isValid then
		return nil
	end
	return {
		point = point,
		relativeTo = relativeTo,
		relativePoint = relativePoint,
		offsetX = offsetX or 0,
		offsetY = offsetY or 0,
		constrains = constrains,
	}
end

local function Edges(control)
	local okLeft, left = pcall(control.GetLeft, control)
	local okRight, right = pcall(control.GetRight, control)
	if not okLeft or not okRight or type(left) ~= "number" or type(right) ~= "number" then
		return nil
	end
	return left, right
end

-- The anchor a control had before this add-on touched it, remembered the moment before the
-- first write to that control and never afterwards -- re-reading later would record our own
-- offset as the game's. Per control rather than in one pass, because the row can grow: a
-- companion summoned mid-session brings a button the client has only just anchored.
function skillbar:Remember(control)
	self.original = self.original or {}
	if self.original[control] ~= nil then
		return self.original[control] or nil
	end
	local anchor = ReadAnchor(control, 0)
	if not anchor or ReadAnchor(control, 1) then
		self.original[control] = false
		return nil
	end
	self.original[control] = anchor
	return anchor
end

-- The gaps the game itself leaves, measured off the screen. Only while none of ours is on the
-- bar, and only at the bar's own scale: after either, the distances read back are ours.
function skillbar:Measure()
	if self.written or addon:ScalePercent(addon.actionBar) ~= addon.DEFAULT_SCALE then
		return false
	end
	local gaps = addon:MeasuredGaps()
	local measured = true
	self:Each(function(control, key, target, leftwards)
		if gaps[key] ~= nil then
			return
		end
		local left, right = Edges(control)
		local targetLeft, targetRight = Edges(target)
		if not left or not targetLeft then
			measured = false
			return
		end
		local gap = leftwards and (targetLeft - right) or (left - targetRight)
		if gap < addon.MIN_GAP or gap > addon.MAX_GAP then
			measured = false
			return
		end
		gaps[key] = Round(gap)
	end)
	return measured
end

function skillbar:Restore()
	if not self.original then
		return false
	end
	for control, anchor in pairs(self.original) do
		if anchor then
			addon:Write("spacing", control.ClearAnchors, control)
			addon:Write("spacing", control.SetAnchor, control, anchor.point, anchor.relativeTo, anchor.relativePoint,
				anchor.offsetX, anchor.offsetY, anchor.constrains)
		end
	end
	self.original = nil
	self.written = false
	return true
end

-- ---------------------------------------------------------------------------------------
-- Writing
-- ---------------------------------------------------------------------------------------

local function InPlace(control, point, target, relativePoint, offsetX)
	local anchor = ReadAnchor(control, 0)
	if not anchor or ReadAnchor(control, 1) then
		return false
	end
	return anchor.point == point and anchor.relativeTo == target and anchor.relativePoint == relativePoint
		and Round(anchor.offsetX) == Round(offsetX) and Round(anchor.offsetY) == 0
end

function skillbar:Apply()
	if not addon:Control(addon.actionBar) then
		return false
	end

	if not addon:SpacingDiffers() then
		if self.written then
			return self:Restore()
		end
		self:Measure()
		return true
	end

	-- Whatever has not been measured yet is measured now, while the bar is still the game's.
	self:Measure()

	self:Each(function(control, key, target, leftwards)
		local gap = addon:Gap(key)
		local point = leftwards and RIGHT or LEFT
		local relativePoint = leftwards and LEFT or RIGHT
		local offsetX = leftwards and -gap or gap
		if InPlace(control, point, target, relativePoint, offsetX) then
			return
		end
		if not self:Remember(control) then
			-- Nothing to put back with, so it is left where the game has it.
			addon.writeErrors = addon.writeErrors or {}
			addon.writeErrors.spacing = "could not read " .. tostring(control.GetName and control:GetName() or "a button") .. "'s own anchor"
			return
		end
		addon:Write("spacing", control.ClearAnchors, control)
		addon:Write("spacing", control.SetAnchor, control, point, target, relativePoint, offsetX, 0)
	end)

	self.written = true
	return true
end

-- ---------------------------------------------------------------------------------------
-- Where the buttons sit inside the bar
--
-- The bar's control is 606 wide and the buttons occupy rather less of it: the weapon swap marker
-- holds the left-hand end, and where the row ends depends on the gaps. Measured off the real
-- controls and given back as fractions of the bar's width, which is what the settings panel's
-- preview needs to draw a row over the buttons rather than a band across the whole bar.
--
-- Fractions rather than distances because they are free of scale: both numbers are scaled the
-- same and it cancels, so the answer holds whatever size the bar has been set to.
-- ---------------------------------------------------------------------------------------

function addon:ButtonSpan()
	local bar = self:Control(self.actionBar)
	local first = skillbar:Button(FIRST_SLOT)
	local last = skillbar:Button(ULTIMATE_SLOT) or skillbar:Button(LAST_ABILITY_SLOT)
	if not bar or not first or not last then
		return nil
	end
	local okBar, barLeft = pcall(bar.GetLeft, bar)
	local okWidth, barWidth = pcall(bar.GetWidth, bar)
	local okFirst, firstLeft = pcall(first.GetLeft, first)
	local okLast, lastRight = pcall(last.GetRight, last)
	if not (okBar and okWidth and okFirst and okLast) or type(barWidth) ~= "number" or barWidth <= 0 then
		return nil
	end
	-- The abilities and the ultimate only. The quickslot and a companion's ultimate sit further
	-- left and have no row above them: the other weapon set's slots stand over ActionButton3 to
	-- ActionButton8 and nothing else, which is the whole point of measuring this.
	local from = (firstLeft - barLeft) / barWidth
	local to = (lastRight - barLeft) / barWidth
	if to <= from then
		return nil
	end
	return from, to
end

-- ---------------------------------------------------------------------------------------
-- Whether the weapon sets can be swapped at all
--
-- Two reasons they cannot, and both are answered by the client rather than guessed at from an
-- item (Action Duration Reminder looks for "oakensoul" in the icon of each worn ring):
--
--   GetActiveWeaponPairInfo() returns the pair and whether it is locked. The Oakensoul Ring,
--   and anything else that welds you to one bar, sets that second value -- it is what the
--   client's own weapon swap button reads, and EVENT_WEAPON_PAIR_LOCK_CHANGED reports it.
--
--   GetUnitLevel("player") < GetWeaponSwapUnlockedLevel() is a character too low to have earned
--   the second set yet.
--
-- With no second set, a row showing one is a row of nothing useful, so it goes away on its own.
-- ---------------------------------------------------------------------------------------

-- Match the equipped ring's icon, as FancyActionBar+ does. The worn slots make
-- this independent of inventory contents, item quality and localized item names.
local OAKENSOUL_ICON = "esoui/art/icons/u34_mythic_oakensoul_ring.dds"

function addon:OakensoulEquipped()
	if type(GetItemInfo) ~= "function" or BAG_WORN == nil then return false end
	local function Matches(slot)
		if slot == nil then return false end
		local ok, icon = pcall(GetItemInfo, BAG_WORN, slot)
		return ok and type(icon) == "string"
			and icon:lower():gsub("^/", "") == OAKENSOUL_ICON
	end
	return Matches(EQUIP_SLOT_RING1) or Matches(EQUIP_SLOT_RING2)
end

function addon:WeaponSwapState()
	if type(GetUnitLevel) == "function" and type(GetWeaponSwapUnlockedLevel) == "function" then
		local okLevel, level = pcall(GetUnitLevel, "player")
		local okUnlock, unlock = pcall(GetWeaponSwapUnlockedLevel)
		if okLevel and okUnlock and type(level) == "number" and type(unlock) == "number" and level < unlock then
			return false, "unearned"
		end
	end
	if type(GetActiveWeaponPairInfo) == "function" then
		local ok, _, locked = pcall(GetActiveWeaponPairInfo)
		if ok and locked then
			return false, "locked"
		end
	end
	return true, nil
end

function addon:WeaponSwapAvailable()
	return (self:WeaponSwapState())
end

-- The front bar's size belongs to its physical controls, not to either weapon set.
-- Keep the user scale on ZO_ActionBar1 only; slot, FlipCard and Icon use local scale 1.
-- The separate back row applies BackBarScale to its own controls in Timers.lua.
local function Playing(timeline)
	return timeline and type(timeline.IsPlaying) == "function" and timeline:IsPlaying()
end

local function RestoreScale(control, scale)
	if control and type(control.GetScale) == "function" and control:GetScale() ~= scale then
		return addon:Write("skill icon scale", control.SetScale, control, scale)
	end
	return false
end

local function RestoreSize(control, size)
	if not control or type(control.GetDimensions) ~= "function" then return false end
	local width, height = control:GetDimensions()
	if math.abs(width - size) > 0.01 or math.abs(height - size) > 0.01 then
		return addon:Write("skill icon", control.SetDimensions, control, size, size)
	end
	return false
end

-- ApplySwapAnimationStyle reads FlipCard's current dimensions and stores them in the
-- timeline. Fixing the control alone leaves a stale endpoint to be replayed on the
-- next swap. Write canonical local dimensions to the idle timeline as well, without
-- invoking the client's ApplyStyle (which also updates protected combat state).
local function RestoreSwapSize(timeline, size)
	if not timeline or type(timeline.GetFirstAnimation) ~= "function"
		or type(timeline.GetLastAnimation) ~= "function" then return false end
	local first, last = timeline:GetFirstAnimation(), timeline:GetLastAnimation()
	if not first or not last then return false end
	local ok = addon:Write("skill swap size", first.SetStartAndEndWidth, first, size, size)
	ok = addon:Write("skill swap size", first.SetStartAndEndHeight, first, size, 0) and ok
	ok = addon:Write("skill swap size", last.SetStartAndEndWidth, last, size, size) and ok
	return addon:Write("skill swap size", last.SetStartAndEndHeight, last, 0, size) and ok
end

function skillbar:RepairIcons()
	if not addon:SkillBarAllowed() or type(IsInGamepadPreferredMode) ~= "function"
		or not IsInGamepadPreferredMode() or type(ZO_ActionBar_GetButton) ~= "function" then
		return
	end
	RestoreScale(addon:Control(addon.actionBar), addon:ScalePercent(addon.actionBar) / 100)
	self.iconStates = self.iconStates or {}
	local hotbar = type(GetActiveHotbarCategory) == "function" and GetActiveHotbarCategory() or nil
	for slot = FIRST_SLOT, ULTIMATE_SLOT do
		local ok, button = pcall(ZO_ActionBar_GetButton, slot)
		if ok and button then
			local state = self.iconStates[slot]
			if not state or state.button ~= button then
				state = { button = button, dirty = true }
				self.iconStates[slot] = state
			end
			if state.hotbar ~= hotbar then state.dirty = true end
			state.hotbar = hotbar
			if Playing(button.bounceAnimation) or Playing(button.iconBounceAnimation)
				or Playing(button.hotbarSwapAnimation) then
				-- Animation owns these dimensions until it finishes or is interrupted.
				state.dirty = true
			else
				local size = slot == ULTIMATE_SLOT and (ZO_GAMEPAD_ULTIMATE_BUTTON_SIZE or 67)
					or (ZO_GAMEPAD_ACTION_BUTTON_SIZE or 61)
				local slotControl = button.slot or self:Button(slot)
				RestoreScale(slotControl, 1)
				RestoreScale(button.flipCard, 1)
				RestoreScale(button.icon, 1)
				RestoreSize(slotControl, size + 3)
				local frameChanged = RestoreSize(button.flipCard, size)
				RestoreSize(button.icon, size)
				if state.dirty or frameChanged or state.timeline ~= button.hotbarSwapAnimation then
					if RestoreSwapSize(button.hotbarSwapAnimation, size) then
						state.timeline = button.hotbarSwapAnimation
						state.dirty = false
					end
				end
			end
		end
	end
end
