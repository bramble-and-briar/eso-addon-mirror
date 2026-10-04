-- PBS_CONSOLE_HUD_CUSTOMIZER is nil if Main.lua bailed out early (e.g. already loaded).
if not PBS_CONSOLE_HUD_CUSTOMIZER then
	return
end

local addon = PBS_CONSOLE_HUD_CUSTOMIZER

-- ---------------------------------------------------------------------------------------
-- The trace
--
-- A measurement, not a feature. Nothing here changes what is drawn; it is off until
-- "/pbhud trace on" and it registers nothing until then.
--
-- It exists to answer one question that two attempts at ground-targeted abilities were built
-- on a guess about (FINDINGS 49): an ability that is aimed before it lands -- Caltrops, a
-- trap, Elemental Blockade -- is pressed once to raise the circle and once to place it, and
-- this add-on starts its countdown at the press. Which press? And is there anything at all
-- that says "it landed"?
--
-- So each of these is written down with the time it arrived:
--
--   ground     EVENT_ENTER_GROUND_TARGET_MODE and EVENT_CANCEL_GROUND_TARGET_MODE. These two
--              are what the client itself and FancyActionBar+ register; there is no third one
--              for a placement. Which of the three names actually exist is printed at the top
--              of the dump, because one of them (LEAVE) does not, and assuming it did is what
--              broke 1.12.0.
--   aiming     IsPlayerGroundTargeting(), polled, and written down when it changes. This is
--              the cross-check: if the events never arrive on console but the poll still turns
--              over, the poll is the signal to build on -- and the other way about.
--   press      EVENT_ACTION_SLOT_ABILITY_USED: the slot, the ability bound to it, and the
--              length the game gives for it. One line per press, so a two-press ability shows
--              whether the game reports one or two.
--   effect     the first EVENT_EFFECT_CHANGED for an ability that was pressed a moment ago,
--              with the begin and end the game sent.
--   combat     the first EVENT_COMBAT_EVENT for that same ability with the player as its
--              source. This is the signal FancyActionBar+ waits for on the abilities it does
--              not trust the press for (needCombatEvent, main.lua), so whether it arrives --
--              and when, relative to the two presses -- decides the design.
--
-- Only abilities pressed in the last few seconds are followed, so a fight does not fill the
-- log with everyone else's hits.
-- ---------------------------------------------------------------------------------------

local trace = {
	entries = {},
	watched = {},
	at = 0,
	count = 0,
}
addon.trace = trace

-- Twenty seconds of one ability is a few dozen lines; the ring is bigger than the measurement
-- needs so that a press, a placement and the effect that follows cannot be pushed out by the
-- rest of a fight.
local TRACE_SIZE = 160

-- How long after a press that ability's effects and combat events are still written down.
local WATCH_MS = 12000

-- How often IsPlayerGroundTargeting() is read while the trace is on.
local POLL_MS = 50

local Round = addon.Round

local function Now()
	if type(GetFrameTimeMilliseconds) == "function" then
		local ok, value = pcall(GetFrameTimeMilliseconds)
		if ok and type(value) == "number" then
			return value
		end
	end
	return GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
end

local function Call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok then
		return value
	end
	return nil
end

-- ---------------------------------------------------------------------------------------
-- Writing it down
-- ---------------------------------------------------------------------------------------

function trace:Add(kind, text)
	local now = Now()
	self.started = self.started or now
	self.count = self.count + 1
	self.at = (self.at % TRACE_SIZE) + 1
	local entry = self.entries[self.at]
	if not entry then
		entry = {}
		self.entries[self.at] = entry
	end
	entry.kind, entry.text, entry.ms = kind, text, now - self.started
	entry.index = self.count
	if self.echo then
		addon.Line("  |cFF69B4%7s|r %-7s %s", string.format("+%.2fs", entry.ms / 1000), kind, text)
	end
	return entry
end

-- An ability is followed for a while after it is pressed, and pressing it again only pushes
-- the deadline out: the second press of an aimed ability must not start a second record.
function trace:Watch(abilityId, name)
	if not abilityId or abilityId == 0 then
		return
	end
	local entry = self.watched[abilityId]
	if not entry then
		entry = { name = name, presses = 0 }
		self.watched[abilityId] = entry
	end
	entry.until_ = Now() + WATCH_MS
	entry.name = name or entry.name
	return entry
end

function trace:Watched(abilityId)
	local entry = abilityId and self.watched[abilityId]
	if not entry then
		return nil
	end
	if Now() > entry.until_ then
		self.watched[abilityId] = nil
		return nil
	end
	return entry
end

-- ---------------------------------------------------------------------------------------
-- The handlers
-- ---------------------------------------------------------------------------------------

function trace:OnGround(eventCode)
	local which = "?"
	if EVENT_ENTER_GROUND_TARGET_MODE and eventCode == EVENT_ENTER_GROUND_TARGET_MODE then
		which = "ENTER"
	elseif EVENT_CANCEL_GROUND_TARGET_MODE and eventCode == EVENT_CANCEL_GROUND_TARGET_MODE then
		which = "CANCEL"
	end
	self:Add("ground", string.format("%s (event %s)  IsPlayerGroundTargeting=%s", which,
		tostring(eventCode), tostring(Call(IsPlayerGroundTargeting))))
end

function trace:OnPress(_, slotNum)
	local slot = tonumber(slotNum)
	if not slot then
		return
	end
	local hotbar = Call(GetActiveHotbarCategory)
	local abilityId = Call(GetSlotBoundId, slot, hotbar) or 0
	local name = Call(GetSlotName, slot, hotbar) or Call(GetAbilityName, abilityId) or "?"
	local duration = Call(GetAbilityDuration, abilityId) or 0
	local timerDuration, channeled = addon.timers:AbilityDuration(slot, hotbar)
	local watched = self:Watch(abilityId, name)
	if watched then
		watched.presses = watched.presses + 1
	end
	self:Add("press", string.format("slot %d \"%s\" id=%d  the game says it lasts %.1fs  press #%d  aiming=%s  timer=%.1fs channel=%s",
		slot, tostring(name), abilityId, duration / 1000, watched and watched.presses or 1,
		tostring(Call(IsPlayerGroundTargeting)), timerDuration / 1000, tostring(channeled)))
end

-- The client's own argument order (the same one Timers.lua reads): changeType, effectSlot,
-- effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType,
-- abilityType, statusEffectType, unitName, unitId, abilityId. Counting these wrong is how a
-- trace lies to you, so they are named rather than skipped.
function trace:OnEffect(_, changeType, _, effectName, unitTag, beginTime, endTime, _, _, _, _, _, _, _, _, abilityId)
	local watched = self:Watched(abilityId)
	if not watched then
		return
	end
	-- One line per ability per change type: an effect on twenty targets is twenty events.
	local seen = watched.effects or {}
	watched.effects = seen
	local key = tostring(changeType)
	if seen[key] then
		seen[key] = seen[key] + 1
		return
	end
	seen[key] = 1
	local gained = EFFECT_RESULT_GAINED and changeType == EFFECT_RESULT_GAINED
	-- The effect's own length, and where its end falls from here: which of the two presses the
	-- game measured from is the whole question, and "ends in" is what answers it.
	local when = "no end time"
	if (endTime or 0) > 0 then
		when = string.format("runs %.1fs, ends in %.1fs", (endTime - (beginTime or 0)),
			((endTime * 1000) - Now()) / 1000)
	end
	self:Add("effect", string.format("%s \"%s\" id=%d on %s  %s",
		gained and "GAINED" or (EFFECT_RESULT_FADED and changeType == EFFECT_RESULT_FADED and "FADED" or ("type " .. tostring(changeType))),
		tostring(effectName), abilityId or 0, unitTag ~= nil and unitTag ~= "" and tostring(unitTag) or "you", when))
end

-- EVENT_COMBAT_EVENT: result, isError, abilityName, abilityGraphic, abilityActionSlotType,
-- sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log,
-- sourceUnitId, targetUnitId, abilityId (FancyActionBar+ main.lua:6827).
function trace:OnCombat(_, result, _, abilityName, _, _, _, _, targetName, _, _, _, _, _, _, _, abilityId)
	local watched = self:Watched(abilityId)
	if not watched or watched.combat then
		return
	end
	watched.combat = true
	self:Add("combat", string.format("\"%s\" id=%d result=%s on \"%s\" -- the \"it went off\" signal",
		tostring(abilityName), abilityId or 0, tostring(result), tostring(targetName)))
end

function trace:Poll()
	local aiming = Call(IsPlayerGroundTargeting)
	if aiming == nil then
		return
	end
	aiming = aiming and true or false
	if self.aiming == nil then
		self.aiming = aiming
		return
	end
	if aiming ~= self.aiming then
		self.aiming = aiming
		self:Add("aiming", aiming and "IsPlayerGroundTargeting() turned true -- the circle is up"
			or "IsPlayerGroundTargeting() turned false -- the circle is gone")
	end
end

-- ---------------------------------------------------------------------------------------
-- On and off
-- ---------------------------------------------------------------------------------------

local function Name(suffix)
	return addon.name .. "Trace" .. suffix
end

function trace:Start()
	if self.running or not EVENT_MANAGER then
		return false
	end
	self.entries, self.watched, self.at, self.count = {}, {}, 0, 0
	self.started, self.aiming = nil, nil

	-- Both of the ground events the client itself uses, and each only if the game really has
	-- it: registering a nil event is what silently left 1.12.0 with no way out of its gate.
	self.groundEvents = 0
	for suffix, event in pairs({ Enter = EVENT_ENTER_GROUND_TARGET_MODE, Cancel = EVENT_CANCEL_GROUND_TARGET_MODE }) do
		if event ~= nil then
			EVENT_MANAGER:RegisterForEvent(Name(suffix), event, function(...) trace:OnGround(...) end)
			self.groundEvents = self.groundEvents + 1
		end
	end

	if EVENT_ACTION_SLOT_ABILITY_USED then
		EVENT_MANAGER:RegisterForEvent(Name("Press"), EVENT_ACTION_SLOT_ABILITY_USED, function(...) trace:OnPress(...) end)
	end

	-- The same two sources the countdown itself listens on, for the same reason: a pet's
	-- effect is the player's effect as far as the bar is concerned.
	if EVENT_EFFECT_CHANGED then
		for suffix, source in pairs({ Effect = COMBAT_UNIT_TYPE_PLAYER, PetEffect = COMBAT_UNIT_TYPE_PLAYER_PET }) do
			if source ~= nil then
				local name = Name(suffix)
				EVENT_MANAGER:RegisterForEvent(name, EVENT_EFFECT_CHANGED, function(...) trace:OnEffect(...) end)
				if type(EVENT_MANAGER.AddFilterForEvent) == "function" and REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE then
					pcall(EVENT_MANAGER.AddFilterForEvent, EVENT_MANAGER, name, EVENT_EFFECT_CHANGED,
						REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, source)
				end
			end
		end
	end

	if EVENT_COMBAT_EVENT then
		local name = Name("Combat")
		EVENT_MANAGER:RegisterForEvent(name, EVENT_COMBAT_EVENT, function(...) trace:OnCombat(...) end)
		if type(EVENT_MANAGER.AddFilterForEvent) == "function" and REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE then
			pcall(EVENT_MANAGER.AddFilterForEvent, EVENT_MANAGER, name, EVENT_COMBAT_EVENT,
				REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
		end
	end

	if type(IsPlayerGroundTargeting) == "function" and EVENT_MANAGER.RegisterForUpdate then
		-- Read it once here, so that the first change after the trace starts is written down as
		-- a change rather than swallowed as the baseline.
		local aiming = Call(IsPlayerGroundTargeting)
		self.aiming = aiming and true or false
		EVENT_MANAGER:RegisterForUpdate(Name("Poll"), POLL_MS, function() trace:Poll() end)
		self.polling = true
	end

	self.running = true
	return true
end

function trace:Stop()
	if not self.running or not EVENT_MANAGER then
		return false
	end
	for suffix, event in pairs({
		Enter = EVENT_ENTER_GROUND_TARGET_MODE,
		Cancel = EVENT_CANCEL_GROUND_TARGET_MODE,
		Press = EVENT_ACTION_SLOT_ABILITY_USED,
		Effect = EVENT_EFFECT_CHANGED,
		PetEffect = EVENT_EFFECT_CHANGED,
		Combat = EVENT_COMBAT_EVENT,
	}) do
		if event ~= nil then
			pcall(EVENT_MANAGER.UnregisterForEvent, EVENT_MANAGER, Name(suffix), event)
		end
	end
	if self.polling and EVENT_MANAGER.UnregisterForUpdate then
		pcall(EVENT_MANAGER.UnregisterForUpdate, EVENT_MANAGER, Name("Poll"))
	end
	self.polling = false
	self.running = false
	return true
end

-- ---------------------------------------------------------------------------------------
-- Reading it back
-- ---------------------------------------------------------------------------------------

function trace:PrintEvents()
	local Line = addon.Line
	Line("  events this client has: ENTER=%s CANCEL=%s LEAVE=%s",
		tostring(EVENT_ENTER_GROUND_TARGET_MODE ~= nil), tostring(EVENT_CANCEL_GROUND_TARGET_MODE ~= nil),
		tostring(EVENT_LEAVE_GROUND_TARGET_MODE ~= nil))
	Line("  IsPlayerGroundTargeting()=%s  polled=%s  COMBAT_EVENT=%s",
		type(IsPlayerGroundTargeting) == "function" and tostring(Call(IsPlayerGroundTargeting)) or "missing",
		tostring(self.polling == true), tostring(EVENT_COMBAT_EVENT ~= nil))
end

function trace:Print()
	local Line = addon.Line
	Line("|cFF69B4%s|r -- trace: %s, %d line(s) recorded", addon.title,
		self.running and "on" or "off", self.count)
	self:PrintEvents()
	if self.count == 0 then
		Line("  nothing yet. With the trace on, cast a ground-targeted ability -- Caltrops, a trap,")
		Line("  a wall -- once placing it and once cancelling it, then run this again.")
		return
	end
	local entries = self.entries
	local total = #entries
	for index = 1, total do
		local at = (self.at + index - 1) % total + 1
		local entry = entries[at]
		if entry and entry.kind then
			Line("  %7s %-7s %s", string.format("+%.2fs", entry.ms / 1000), entry.kind, entry.text)
		end
	end
end

-- on | off | live | quiet | clear, and no word at all prints what there is.
function trace:Command(word)
	local Line = addon.Line
	word = tostring(word or ""):lower()
	if word == "on" or word == "start" then
		self.echo = self.echo ~= false
		if self:Start() then
			Line("|cFF69B4%s|r trace on (%d ground event(s) registered, lines echoed %s).", addon.title,
				self.groundEvents or 0, self.echo and "as they arrive" or "to the log only")
			self:PrintEvents()
			Line("  now: press a ground-targeted ability and place it; then press it and cancel it.")
			Line("  then \"/pbhud trace\" for the whole record, and \"/pbhud trace off\" when done.")
		else
			Line("|cFF69B4%s|r trace is already on.", addon.title)
		end
	elseif word == "off" or word == "stop" then
		if self:Stop() then
			Line("|cFF69B4%s|r trace off. %d line(s) kept -- \"/pbhud trace\" still reads them back.",
				addon.title, self.count)
		else
			Line("|cFF69B4%s|r trace is already off.", addon.title)
		end
	elseif word == "live" or word == "echo" then
		self.echo = true
		Line("|cFF69B4%s|r trace lines will appear as they arrive.", addon.title)
	elseif word == "quiet" then
		self.echo = false
		Line("|cFF69B4%s|r trace lines go to the log only.", addon.title)
	elseif word == "clear" then
		self.entries, self.watched, self.at, self.count = {}, {}, 0, 0
		self.started, self.aiming = nil, nil
		Line("|cFF69B4%s|r trace cleared.", addon.title)
	else
		self:Print()
	end
end
