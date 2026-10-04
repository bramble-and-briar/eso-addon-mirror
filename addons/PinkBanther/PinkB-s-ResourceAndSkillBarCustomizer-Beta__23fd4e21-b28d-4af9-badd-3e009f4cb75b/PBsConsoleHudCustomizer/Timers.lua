-- PBS_CONSOLE_HUD_CUSTOMIZER is nil if Main.lua bailed out early (e.g. already loaded).
if not PBS_CONSOLE_HUD_CUSTOMIZER then
	return
end

local addon = PBS_CONSOLE_HUD_CUSTOMIZER

-- ---------------------------------------------------------------------------------------
-- The back bar, and the text on the icons
--
-- Two things are drawn on the skill bar:
--
--   the back bar   a row of the *other* weapon set's abilities, above the game's own bar. The
--                  game has a back row of its own (ZO_ActionBarTimer, the "back row" and
--                  "action bar timers" settings), but it only appears for the one slot whose
--                  effect is still running, and only while it is running. This one is always
--                  there, so both sets can be read at a glance.
--   the text       how long is left on each ability's effect, and how many targets are under
--                  it, on both bars.
--
-- Where the numbers come from:
--
--   GetActionSlotEffectTimeRemaining(slot, hotbarCategory)   -- ms, and it answers for the bar
--   GetActionSlotEffectDuration(slot, hotbarCategory)        --   you are NOT on as well
--   GetActionSlotEffectStackCount(slot, hotbarCategory)
--
-- Casts supply the countdown origin; matching effects refine the duration. The slot API is a
-- fallback when no cast has been recorded. Target counts come from EVENT_EFFECT_CHANGED.
-- Labels and shades belong to their front buttons. The back row belongs to the action bar,
-- so it follows HUD visibility without inheriting a front button's temporary hidden state.
-- ---------------------------------------------------------------------------------------

local timers = {
	back = {},
	labels = {},
	shades = {},
	dimmed = {},
}
addon.timers = timers

-- ACTION_BAR_FIRST_NORMAL_SLOT_INDEX is 2 and ACTION_BAR_SLOTS_PER_PAGE is 6, so the abilities
-- are slots 3 to 7 and the ultimate is 8. Read from the globals where they are there, so a
-- client that renumbers them is followed rather than guessed at.
local FIRST_SLOT = (ACTION_BAR_FIRST_NORMAL_SLOT_INDEX or 2) + 1
local LAST_SLOT = (ACTION_BAR_ULTIMATE_SLOT_INDEX or 7) + 1

local UPDATE_INTERVAL_MS = 100
local PRUNE_INTERVAL_MS = 3000

-- Keep timers, shades and held counts visible until the effect actually expires.

-- How many effects are remembered for the target count. Six abilities on each bar, a handful of
-- targets each; the cap is what stops a long fight in a crowd from growing the table for ever.
local MAX_TRACKED_EFFECTS = 128

local TIMER_COLOUR = { 0.86, 0.85, 0.13 }
local COUNT_COLOUR = { 1, 1, 1 }

local Round = addon.Round

-- The clock every effect time is measured against. The client's own code compares an effect's
-- end time to this one ("local timeLeft = (endTime * 1000.0) - GetFrameTimeMilliseconds()",
-- zo_stats_gamepad.lua), so this add-on does too rather than assuming the two are the same.
local function Now()
	if type(GetFrameTimeMilliseconds) == "function" then
		local ok, value = pcall(GetFrameTimeMilliseconds)
		if ok and type(value) == "number" then
			return value
		end
	end
	return GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
end



-- ---------------------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------------------

addon.MIN_TEXT_SIZE = 12
addon.MAX_TEXT_SIZE = 48
addon.DEFAULT_TIMER_SIZE = 27
addon.DEFAULT_COUNT_SIZE = 22

-- What to do about the countdown on the bar the player is on. The game draws one of its own
-- there when Settings > Interface > Action Bar Timers is on, at a size of its own that no add-on
-- can change -- so "draw ours as well" would mean two numbers on one icon.
--
--   addon   ours, and the game's own number faded out of the way. The default: it is the only
--           one of the three where the text size setting always does something.
--   both    ours and the game's, side by side.
--   game    the front bar is left to the game. The other weapon set still gets ours, because the
--           game never draws a number there at all.
--
-- The old names for these (auto / always / never) are migrated in Account().
addon.TIMER_MODES = { "addon", "both", "game" }

function addon:Text()
	return self:Account().text
end

function addon:BackBar()
	return self:Account().backBar
end

-- Where a size is kept. The other weapon set's row has its own pair of keys, and an unset one
-- means "whatever the bar you are on uses" -- the same shape as a position that has not been
-- moved yet. So the row follows the front bar until the player gives it a size of its own, and
-- an upgrade from a build that had one size for both changes nothing on screen.
local function SizeKey(which, isBack)
	if isBack then
		return "back" .. which:sub(1, 1):upper() .. which:sub(2) .. "Size"
	end
	return which .. "Size"
end

addon.SizeKey = SizeKey

function addon:TextSize(which, isBack)
	local text = self:Text()
	if isBack then
		local own = text[SizeKey(which, true)]
		if type(own) == "number" then
			return addon.Clamp(Round(own), self.MIN_TEXT_SIZE, self.MAX_TEXT_SIZE)
		end
	end
	local size = text[SizeKey(which, false)]
	if type(size) ~= "number" then
		return which == "timer" and self.DEFAULT_TIMER_SIZE or self.DEFAULT_COUNT_SIZE
	end
	return addon.Clamp(Round(size), self.MIN_TEXT_SIZE, self.MAX_TEXT_SIZE)
end

function addon:SetTextSize(which, value, isBack)
	self:Text()[SizeKey(which, isBack)] = addon.Clamp(Round(value), self.MIN_TEXT_SIZE, self.MAX_TEXT_SIZE)
end

-- True once the row has been given a size of its own.
function addon:TextSizeIsOwn(which)
	return type(self:Text()[SizeKey(which, true)]) == "number"
end

-- Back to following the bar you are on.
function addon:ClearBackTextSize(which)
	self:Text()[SizeKey(which, true)] = nil
end

-- Whether the game is drawing its own countdown and stack count on the bar. Its setting is
-- SETTING_TYPE_UI / UI_SETTING_SHOW_ACTION_BAR_TIMERS, which an add-on can read but not write.
function addon:GameShowsBarTimers()
	if type(GetSetting_Bool) ~= "function" or not SETTING_TYPE_UI or not UI_SETTING_SHOW_ACTION_BAR_TIMERS then
		return false
	end
	local ok, value = pcall(GetSetting_Bool, SETTING_TYPE_UI, UI_SETTING_SHOW_ACTION_BAR_TIMERS)
	return ok and value == true
end

-- The game only ever draws its numbers on the bar you are on, so "auto" is about the front bar
-- alone: the back bar's numbers are always ours to draw.
function addon:TimerMode()
	local mode = self:Text().timerMode
	for _, known in ipairs(self.TIMER_MODES) do
		if mode == known then
			return mode
		end
	end
	return "addon"
end

function addon:ShowsTimerOn(isBackBar)
	if not self:SkillBarAllowed() then
		return false
	end
	-- The game never writes a number on the set you are not on, so that one is always ours.
	if isBackBar then
		return true
	end
	return self:TimerMode() ~= "game"
end

-- True while the game's own number on the front bar should be got out of the way, because ours is
-- going on the same spot.
--
-- Deliberately not conditional on GameShowsBarTimers(): fading a label the game is not drawing
-- anything on costs nothing, and reading that setting is the one part of this that can quietly
-- come back wrong -- which shows up as two numbers on one icon, which is what it was meant to
-- prevent. The setting is still read, for status to print.
function addon:DimsGameTimer()
	return self:ShowsTimerOn(false) and self:TimerMode() == "addon"
end

function addon:ShowsCount()
	return self:SkillBarAllowed() and self:Text().showCounts ~= false
end

function addon:BackBarEnabled()
	if not (self:SkillBarAllowed() and self:BackBar().enabled ~= false) then
		return false
	end
	-- Only the equipped Oakensoul ring overrides the display setting. Temporary
	-- weapon-swap locks must not make the row disappear during combat.
	return not self:OakensoulEquipped()
end

-- ---------------------------------------------------------------------------------------
-- The shade over the icon
--
-- A Cooldown control of the add-on's own, given the ability's own icon and started with
-- CD_TYPE_VERTICAL_REVEAL. The engine then darkens the icon and wipes that darkness down it as
-- the time runs out: no work per frame here, and the sweep is exactly as long as the effect
-- because the client is the one counting.
--
-- Which way the sweep runs is the difference between CD_TIME_TYPE_TIME_UNTIL and
-- CD_TIME_TYPE_TIME_REMAINING -- one counts towards the end, the other away from it. The setting
-- is a direction rather than a time type for that reason: if a client build ever runs it the
-- other way, the player flips it and it is right again, with no round trip to a console.
-- ---------------------------------------------------------------------------------------

addon.SHADE_DIRECTIONS = { "down", "up" }

function addon:Shade()
	return self:Account().shade
end

function addon:ShadeEnabled()
	return self:SkillBarAllowed() and self:Shade().enabled ~= false
end

function addon:ShadeDarkness()
	local value = self:Shade().darkness
	if type(value) ~= "number" then
		return 60
	end
	return addon.Clamp(Round(value), 0, 100)
end

function addon:SetShadeDarkness(value)
	self:Shade().darkness = addon.Clamp(Round(value), 0, 100)
end

function addon:ShadeDirection()
	local direction = self:Shade().direction
	return direction == "up" and "up" or "down"
end

function addon:ShadeTimeType()
	-- "down" is the shade leaving the top of the icon first, which is what the effect running
	-- out should look like.
	if self:ShadeDirection() == "up" then
		return CD_TIME_TYPE_TIME_REMAINING
	end
	return CD_TIME_TYPE_TIME_UNTIL
end

-- ---------------------------------------------------------------------------------------
-- Counting targets
--
-- There is no API for "how many things are under this ability's effect", so the effects the
-- player applies are counted as they are reported: EVENT_EFFECT_CHANGED, filtered to the ones
-- the player is the source of, one entry per effect name with the units under it.
--
-- Matched to a slot by name, with the ability id as a second chance. That is a heuristic, and an
-- honest one: an effect usually carries the name of the ability that applied it, but a morph
-- that renames what it applies (or applies several) will not line up. The countdown does not
-- depend on it -- that comes from the client -- so at worst a target count is missing, never
-- wrong about the time.
-- ---------------------------------------------------------------------------------------

local effects = {}
local effectCount = 0
local idKeys = {}
local iconKeys = {}

local function Normalize(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	-- Gender and article markup ("^F", "^n") is part of the raw string and never part of what a
	-- slot is called.
	local plain = name:gsub("%^%a+", ""):gsub("^%s+", ""):gsub("%s+$", "")
	if plain == "" then
		return nil
	end
	return plain:lower()
end

timers.Normalize = Normalize

-- An icon path, as a key. GetSlotTexture and the icon an effect reports are the same art, but
-- not always spelt the same way: one may carry a leading slash, and case is not to be trusted.
local function IconKey(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end
	return (path:lower():gsub("^/", ""))
end

timers.IconKey = IconKey

-- ---------------------------------------------------------------------------------------
-- Which effect a slot's own is
--
-- The client's per-slot timer (GetActionSlotEffectTimeRemaining) answers with one number for a
-- slot that can have several of the player's effects running, and hands over between them: Blue
-- Betty's 22-second buff gives way to the five-second thing the netch does, a few seconds from
-- the end. No guard on top of that reading fixed it, because the reading itself is not the
-- ability's effect.
--
-- What the add-ons that get this right do instead -- Action Duration Reminder among them, which
-- does not call that API at all -- is watch for the cast: EVENT_ACTION_SLOT_ABILITY_USED says
-- which slot was pressed, and the effects that appear in the moment after it are that slot's.
-- The longest of them is the one the player means by "how long is left".
--
-- The association lives until the next cast of that slot, or until the effect it names ends, so
-- it survives a weapon swap: it is kept per slot *and* hotbar, and a cast records the hotbar it
-- was made on.
-- ---------------------------------------------------------------------------------------

local CAST_WINDOW_MS = 1500

-- Shorter than this is a cast time or a flash, not something to count down.
local CAST_EFFECT_MINIMUM_MS = 900

-- How far an effect's length may be from the ability's own before it is taken for a different
-- effect entirely. A quarter, and never less than a second and a half: wide enough for the
-- passives and sets that stretch a duration a little, narrow enough that a six-second effect is
-- not mistaken for a ten-second ability.
local DURATION_TOLERANCE_RATIO = 0.25
local DURATION_TOLERANCE_MIN_MS = 1500

local slotEffects = {}

-- The same ability is often in a slot on both weapon sets, and it is one effect however many
-- slots it is in: a cast from either has to answer for both, or the two rows show the same skill
-- counting down to different numbers. Kept by the slot's own art, which is the ability's.
local linksByIcon = {}

local lastUse = { slot = nil, hotbar = nil, at = -CAST_WINDOW_MS * 10 }

local function SlotKey(slot, hotbar)
	return slot .. ":" .. tostring(hotbar)
end

timers.SlotKey = SlotKey

-- What the game says the ability in a slot lasts. This is the piece that was missing: one cast
-- puts several effects on the world, and the longest of them is not the ability's own.
--
-- Templar's Power of the Light lasts 6 seconds and applies Major Breach for 20, so "the longest
-- effect of that cast" showed 20. FancyActionBar+ does not guess: it reads GetAbilityDuration
-- for the ability in the slot (main.lua, FancyActionBar.GetAbilityDuration) and works from
-- there. So does this now.
local function AbilityValue(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, value = pcall(fn, ...)
	return ok and value or nil
end

function timers:AbilityDuration(slot, hotbar)
	local abilityId = AbilityValue(GetSlotBoundId, slot, hotbar)
	if type(abilityId) ~= "number" or abilityId == 0 then return 0, false end
	-- Channel time is separate from effect duration. A channel can report duration 0
	-- while also triggering a much longer passive. Never time that passive instead.
	if type(GetAbilityCastInfo) == "function" then
		local ok, channeled, castTime, channelTime = pcall(GetAbilityCastInfo, abilityId, nil, "player")
		if ok and channeled then
			if type(channelTime) == "number" and channelTime > 0 then return channelTime, true end
			if type(castTime) == "number" and castTime > 0 then return castTime, true end
			return 0, true
		end
	end
	local duration = AbilityValue(GetAbilityDuration, abilityId, nil, "player")
	return type(duration) == "number" and duration > 0 and duration or 0, false
end

-- ---------------------------------------------------------------------------------------
-- Abilities that are aimed before they land
--
-- Caltrops, a rune, a wall: one press raises the circle and a second one puts it on the floor.
-- Counting from the press means counting from the circle, and a player who holds it for three
-- seconds sees three seconds of a countdown for something that has not happened.
--
-- What the game really sends, measured on a PS5 (FINDINGS 51, and "/pbhud trace" is what
-- measured it):
--
--   +0.00s  ENTER, then EVENT_ACTION_SLOT_ABILITY_USED for the ability -- and
--           IsPlayerGroundTargeting() is already true *inside* that handler
--   +0.62s  the circle goes down as it is placed. No event, and NO second ABILITY_USED
--   +0.80s  the effect, and a combat event, arrive
--
-- and when it is cancelled instead:
--
--   +4.63s  IsPlayerGroundTargeting() goes false and EVENT_CANCEL_GROUND_TARGET_MODE arrives
--           together. No effect ever follows
--
-- So: the press that is answered by IsPlayerGroundTargeting() == true is the circle going up,
-- not a cast, and nothing is counted from it. What follows decides what happens:
--
--   the effect arrives   the ordinary path takes over and counts from the effect, which is
--                        what FancyActionBar+ does for everything it has not named
--   the circle goes      it was placed. The ability's own length starts from that moment, for
--   down, no CANCEL      the abilities whose effect the game never reports
--   CANCEL arrives       it was never cast. Nothing is counted at all
--
-- The state this keeps is one pending press with a deadline, and losing it costs nothing but
-- the fallback -- no gate, nothing held back, and no other ability touched. That is the
-- difference from 1.12.0 and 1.12.1, where one latched flag stopped every countdown in the
-- add-on (FINDINGS 49).
-- ---------------------------------------------------------------------------------------

-- A circle held longer than this is forgotten: the ability keeps the effect path, it only
-- loses the fallback. Nothing else waits on it.
local GROUND_HOLD_MAX_MS = 10000

function timers:GroundTargeting()
	if type(IsPlayerGroundTargeting) ~= "function" then
		return nil
	end
	local ok, value = pcall(IsPlayerGroundTargeting)
	if not ok or value == nil then
		return nil
	end
	return value and true or false
end

-- The ability's own length, started from here: the block that used to sit inside OnAbilityUsed.
function timers:DeclareCast(slot, hotbar, expected, at)
	-- Even an unknown duration needs a record: otherwise the raw client timer can
	-- reintroduce the unrelated effect that LinkToCast just rejected.
	if not expected or expected < CAST_EFFECT_MINIMUM_MS then expected = 0 end
	local slotKey = SlotKey(slot, hotbar)
	local slotIcon = nil
	if type(GetSlotTexture) == "function" then
		local ok, texture = pcall(GetSlotTexture, slot, hotbar)
		if ok then
			slotIcon = IconKey(texture)
		end
	end
	local entry = {
		key = nil,
		slotIcon = slotIcon,
		beginMs = at,
		endMs = at + expected,
		castAt = at,
		-- Anything the game actually reports beats a number worked out from the tooltip.
		score = math.huge,
		declared = true,
	}
	slotEffects[slotKey] = entry
	if slotIcon then
		linksByIcon[slotIcon] = entry
	end
	self.declared = (self.declared or 0) + 1
end

-- The circle was abandoned. Nothing was cast, so there is nothing to count.
function timers:OnGroundCancel()
	if self.groundPending then
		lastUse.slot = nil
		self.groundPending = nil
		self.groundCancelled = (self.groundCancelled or 0) + 1
	end
end

-- Run from the update loop. Watches the one press that is waiting on its circle.
function timers:GroundTick(now)
	local pending = self.groundPending
	if not pending then
		return
	end
	if now - pending.at > GROUND_HOLD_MAX_MS then
		self.groundPending = nil
		self.groundExpired = (self.groundExpired or 0) + 1
		return
	end
	if self:GroundTargeting() ~= false then
		pending.downAt = nil
		return
	end
	-- The circle is down. One tick of grace before anything is counted, so that a CANCEL
	-- arriving in the same frame is seen first: cancelled and placed look identical here, and
	-- only the event tells them apart.
	if not pending.downAt then
		pending.downAt = now
		return
	end
	self.groundPending = nil
	self.groundPlaced = (self.groundPlaced or 0) + 1
	-- The cast happened now, not when the circle went up: an effect that follows has to be
	-- taken for this slot's, and the fallback has to count from here.
	if lastUse.at == pending.at then
		lastUse.at = pending.downAt
	end
	self:DeclareCast(pending.slot, pending.hotbar, pending.expected, pending.downAt)
end

function timers:OnAbilityUsed(_, slotNum)
	if type(slotNum) ~= "number" or slotNum < FIRST_SLOT or slotNum > LAST_SLOT then
		return
	end
	local _, hotbar = self:BackHotbar()
	lastUse.slot = slotNum
	lastUse.hotbar = hotbar
	lastUse.at = Now()
	lastUse.expected, lastUse.channeled = self:AbilityDuration(slotNum, hotbar)
	lastUse.abilityId = AbilityValue(GetSlotBoundId, slotNum, hotbar)
	lastUse.name = Normalize(AbilityValue(GetSlotName, slotNum, hotbar))
	lastUse.icon = IconKey(AbilityValue(GetSlotTexture, slotNum, hotbar))
	self.casts = (self.casts or 0) + 1

	-- A press that is answered by "you are aiming" is the circle going up. Measured: the game
	-- has already entered ground-targeting mode by the time this handler runs, so the two can
	-- be told apart here, with no gate and nothing held back (FINDINGS 51).
	--
	-- Any press replaces a circle still waiting on an answer: the player moved on.
	self.groundPending = nil
	if self:GroundTargeting() == true then
		self.groundPending = {
			slot = slotNum,
			hotbar = hotbar,
			expected = lastUse.expected,
			at = lastUse.at,
		}
		self.groundHeld = (self.groundHeld or 0) + 1
		return
	end

	-- Start counting at once, from what the game says the ability lasts, rather than waiting for
	-- an effect that may never be reported. FancyActionBar+ does this for a list of abilities it
	-- names (config.lua's onAbilityUsed entries, and main.lua where it sets
	-- effect.endTime = duration + t); with no such list here it is done for any ability that
	-- declares a length, and the first effect of the cast takes over from it.
	self:DeclareCast(slotNum, hotbar, lastUse.expected, lastUse.at)
end

-- Duration constrains ordinary effects. Always require an identity match;
-- temporal proximity alone cannot distinguish a skill from a triggered passive.
function timers:LinkToCast(key, icon, beginMs, endMs, now, abilityId)
	if not lastUse.slot or lastUse.channeled or endMs == 0 or endMs - now < CAST_EFFECT_MINIMUM_MS then
		return
	end
	-- While a circle is still up the cast has not happened yet, so the window cannot run out:
	-- the effect of an ability aimed for three seconds arrives three seconds after the press.
	local window = CAST_WINDOW_MS
	local pending = self.groundPending
	if pending and pending.at == lastUse.at then
		window = GROUND_HOLD_MAX_MS + CAST_WINDOW_MS
	end
	if (pending and self:GroundTargeting() == true)
		or beginMs < lastUse.at - 100 or now < lastUse.at
		or now - lastUse.at > window then
		return
	end
	local slotKey = SlotKey(lastUse.slot, lastUse.hotbar)
	local current = slotEffects[slotKey]
	local duration = endMs - beginMs
	local expected = lastUse.expected or 0
	local identity
	if abilityId and abilityId > 0 and abilityId == lastUse.abilityId then
		identity = 0
	elseif key and key == lastUse.name then
		identity = 1
	elseif icon and icon == lastUse.icon then
		identity = 2
	else
		self.unidentified = (self.unidentified or 0) + 1
		return
	end
	-- Length alone is not identity: passives can have the same duration too.
	local score = expected > 0 and math.abs(duration - expected) or identity

	-- An effect is only taken for the ability's own if it is about as long as the game says the
	-- ability lasts. Templar's Blinding Flashes is ten seconds and puts a six-second effect on
	-- the world as well; without this the six was followed and the bar read six.
	--
	-- What stands when nothing matches is the ability's own length, counted from the cast (the
	-- link made in OnAbilityUsed). That is the number in the tooltip, and it is the one the
	-- player is comparing against.
	if expected > 0 then
		local tolerance = math.max(DURATION_TOLERANCE_MIN_MS, expected * DURATION_TOLERANCE_RATIO)
		if math.abs(duration - expected) > tolerance then
			self.mismatched = (self.mismatched or 0) + 1
			return
		end
	end
	-- Read here rather than through the slot readers further down the file: those are defined
	-- after this, and an effect can arrive before anything else has run.
	local slotIcon = nil
	if type(GetSlotTexture) == "function" then
		local ok, texture = pcall(GetSlotTexture, lastUse.slot, lastUse.hotbar)
		if ok then
			slotIcon = IconKey(texture)
		end
	end
	if current and current.castAt == lastUse.at and current.score and current.score <= score then
		return
	end
	-- Effect arrival may lag the cast. Keep the origin fixed; later targets and
	-- periodic refreshes must never restart the skill countdown.
	local startAt = pending and (pending.downAt or beginMs) or lastUse.at
	local pendingCast = pending and pending.at == lastUse.at
	if pendingCast then lastUse.at = startAt end
	local entry = {
		key = key,
		score = score,
		expected = expected,
		-- The icon of the *slot* as it was when the cast happened, not the effect's: what this
		-- is for is noticing that the slot now holds another ability, and an effect's own art is
		-- often not the ability's.
		slotIcon = slotIcon,
		beginMs = startAt,
		endMs = startAt + duration,
		castAt = lastUse.at,
	}
	slotEffects[slotKey] = entry
	if slotIcon then
		linksByIcon[slotIcon] = entry
	end
	self.linked = (self.linked or 0) + 1
	-- The effect is the answer the circle was waiting for: it was placed, and what the game
	-- reports beats anything worked out from the tooltip, so the fallback is dropped.
	if pendingCast then
		self.groundPending = nil
		self.groundPlaced = (self.groundPlaced or 0) + 1
	end
end

-- What is on record for this slot, running or not: the cast made from it, or -- for the same
-- ability sitting in another slot or on the other weapon set -- the cast made from there.
function timers:LinkFor(slot, hotbar, icon)
	local entry = slotEffects[SlotKey(slot, hotbar)]
	local shared = icon and linksByIcon[icon]
	if shared and (not entry or shared.castAt >= entry.castAt) then
		return shared
	end
	if entry and (entry.slotIcon == nil or icon == nil or entry.slotIcon == icon) then
		return entry
	end
	if icon then
		local byIcon = linksByIcon[icon]
		if byIcon then
			return byIcon
		end
	end
	return nil
end

-- The same, but only while it is still running.
function timers:LinkedEffect(slot, hotbar, now)
	local icon = nil
	if type(GetSlotTexture) == "function" then
		local ok, texture = pcall(GetSlotTexture, slot, hotbar)
		if ok then
			icon = IconKey(texture)
		end
	end
	local linked = self:LinkFor(slot, hotbar, icon)
	if not linked or linked.endMs <= now then
		return nil
	end
	return linked
end

function timers:ForgetLinks()
	slotEffects = {}
	linksByIcon = {}
end

-- Room for one more. What goes is the least recently used entry with nothing live in it; only
-- if every entry is live does the least recently used of those go.
--
-- The old version took the least recently *touched*, and an entry is only touched when an effect
-- arrives -- so a damage-over-time ticking away quietly on three targets was exactly the kind of
-- thing it threw out, which reads as the target count disappearing.
local function DropOldest(now)
	local deadKey, deadTime, anyKey, anyTime
	for key, entry in pairs(effects) do
		local live = false
		for _, endMs in pairs(entry.units) do
			if endMs == 0 or endMs > now then
				live = true
				break
			end
		end
		local used = entry.used or entry.touched or 0
		if not live and (not deadTime or used < deadTime) then
			deadKey, deadTime = key, used
		end
		if not anyTime or used < anyTime then
			anyKey, anyTime = key, used
		end
	end
	local key = deadKey or anyKey
	if key then
		effects[key] = nil
		effectCount = effectCount - 1
		timers.dropped = (timers.dropped or 0) + 1
	end
end

function timers:Track(key, abilityId, icon, unitKey, endMs, now)
	local entry = effects[key]
	if not entry then
		if effectCount >= MAX_TRACKED_EFFECTS then
			DropOldest(now)
		end
		entry = { units = {} }
		effects[key] = entry
		effectCount = effectCount + 1
	end
	entry.touched = now
	entry.units[unitKey] = endMs
	entry.gained = entry.gained or {}
	entry.gained[unitKey] = now
	if type(abilityId) == "number" and abilityId > 0 then
		idKeys[abilityId] = key
	end
	if icon then
		iconKeys[icon] = key
	end
end

-- How far apart two instances' end times have to be before a fade is taken for a stale one.
local FADE_TOLERANCE_MS = 250

-- And how soon after an application a fade for the same unit is taken for the old instance's.
local FADE_AFTER_GAIN_MS = 400

-- A fade is not always the end of the effect. Re-applying a damage-over-time on a target that
-- already has it sends the new application first and the old one's fade **after** it, and
-- dropping the unit on that fade is what makes a target count appear and vanish again in the
-- same breath -- which is exactly what came back from the PS5.
--
-- The fade carries the end time of the instance that faded, so the two can be told apart: a fade
-- whose instance was due to end well before what is on record is a fade for something that has
-- already been replaced, and it is ignored.
function timers:Forget(key, unitKey, fadedEnd, now)
	local entry = effects[key]
	if not entry then
		return
	end
	local stored = entry.units[unitKey]
	if stored == nil then
		return
	end
	if stored ~= 0 and fadedEnd and fadedEnd ~= 0 and stored > fadedEnd + FADE_TOLERANCE_MS and stored > (now or 0) then
		self.staleFades = (self.staleFades or 0) + 1
		return
	end
	-- The same thing seen from the other side, for a client that sends the old instance's fade
	-- carrying the *new* times, where comparing the two says nothing: a fade arriving within a
	-- moment of an application for the same effect on the same unit is the one being replaced.
	local gainedAt = entry.gained and entry.gained[unitKey]
	if gainedAt and now and now - gainedAt < FADE_AFTER_GAIN_MS then
		self.staleFades = (self.staleFades or 0) + 1
		return
	end
	entry.units[unitKey] = nil
	if entry.gained then
		entry.gained[unitKey] = nil
	end
	self.fades = (self.fades or 0) + 1
	if next(entry.units) == nil then
		effects[key] = nil
		effectCount = effectCount - 1
	end
end

-- EVENT_EFFECT_CHANGED. The signature is the client's, and only a few of its arguments matter
-- here: what the effect is called, which unit it is on, when it ends, and whether it has just
-- gone away.
function timers:OnEffectChanged(_, changeType, effectSlot, effectName, unitTag, beginTime, endTime, _, iconName, _, _, _, _, _, unitId, abilityId)
	-- A group member's copy of a buff is the same effect on the same name; counting those would
	-- turn a self-buff into "12".
	if type(unitTag) == "string" and unitTag:find("group", 1, true) then
		return
	end
	local key = Normalize(effectName)
	if not key then
		return
	end

	-- What is a target, and what is not. FancyActionBar+ draws the same line (main.lua: isSelf
	-- from GetAbilityTargetDescription, and IsPlayerPet): an effect on yourself is not a target
	-- count -- the countdown beside it already says the buff is up -- and neither is one on
	-- something of yours. Everything else is, including an enemy the client reports with no unit
	-- tag at all, which is most of them.
	local tag = type(unitTag) == "string" and unitTag or ""
	local isSelf = tag == "player"
	local isPet = tag:find("^playerpet") ~= nil or tag == "companion"
	local now = Now()
	-- One key per target. unitId is the one to use where there is one; where there is not -- some
	-- area effects report none -- the effect's own slot tells two instances apart, which is what
	-- FancyActionBar+ does (ResolveUnitKey). Falling back to the unit tag alone, as this did,
	-- collapses every target onto one key: a count of 1 however many are hit, and one fade
	-- clearing the lot.
	local unitKey
	if type(unitId) == "number" and unitId ~= 0 then
		unitKey = unitId
	elseif type(effectSlot) == "number" and effectSlot ~= 0 then
		unitKey = "slot:" .. effectSlot
	else
		unitKey = unitTag ~= "" and unitTag or "?"
	end

	-- endTime is in seconds on the game clock, and 0 for something that does not expire.
	local endMs = (type(endTime) == "number" and endTime > 0) and math.floor(endTime * 1000) or 0

	if changeType == EFFECT_RESULT_FADED then
		local before = self.staleFades or 0
		self:Forget(key, unitKey, endMs, now)
		self:Log((self.staleFades or 0) > before and "ignore" or "fade", changeType, key, unitKey, endMs, now)
		return
	end
	self.gains = (self.gains or 0) + 1

	-- An effect that arrives already over is not an effect that is over: it is the two clocks
	-- disagreeing, and taken at face value it would be dropped the moment it is looked at, which
	-- is the other way a count can flash. Kept as one that does not expire instead, to be ended
	-- by its own fade, and counted so that status can say it is happening.
	if endMs ~= 0 and endMs < now - 1000 then
		self.pastEffects = (self.pastEffects or 0) + 1
		endMs = 0
	end
	local icon = IconKey(iconName)
	local beginMs = (type(beginTime) == "number" and beginTime > 0) and math.floor(beginTime * 1000) or now
	-- The cast is tied to the effect whoever it landed on: that is how a buff on yourself gets
	-- its countdown. Only the counting leaves self and pets out.
	if not (isSelf or isPet) then
		self:Track(key, abilityId, icon, unitKey, endMs, now)
	else
		self.untargeted = (self.untargeted or 0) + 1
	end
	self:LinkToCast(key, icon, beginMs, endMs, now, abilityId)
	self:Log((isSelf or isPet) and "self" or "gain", changeType, key, unitKey, endMs, now)
end

-- How many units are under this effect right now, and what it was matched by.
--
-- Three chances, because an effect does not have to carry the name of the ability that applied
-- it: the name, the ability id, and the icon. The icon is the one that catches a morph whose
-- effect is called something else -- the art is nearly always the ability's own.
function timers:CountFor(key, abilityId, icon, now)
	local entry, matchedBy = key and effects[key] or nil, "name"
	if not entry and type(abilityId) == "number" then
		local byId = idKeys[abilityId]
		entry = byId and effects[byId] or nil
		matchedBy = "id"
	end
	if not entry and icon then
		local byIcon = iconKeys[icon]
		entry = byIcon and effects[byIcon] or nil
		matchedBy = "icon"
	end
	if not entry then
		return 0, nil
	end
	-- Being read is being used: an effect the player is watching count down must not be the one
	-- thrown out to make room.
	entry.used = now
	local count = 0
	for unitKey, endMs in pairs(entry.units) do
		if endMs == 0 or endMs > now then
			count = count + 1
		else
			entry.units[unitKey] = nil
		end
	end
	return count, matchedBy
end

-- entry.gained is kept per unit beside entry.units, and has to go with it. Until 1.27.1 only units
-- were pruned, so an effect kept alive by recasting through a long fight kept a record of every
-- target it had ever touched: half a megabyte over a long session in a crowd (FINDINGS 57). A gain
-- is kept a moment past its unit, for as long as Forget still asks about it.
function timers:Prune(now)
	for key, entry in pairs(effects) do
		local any = false
		for unitKey, endMs in pairs(entry.units) do
			if endMs ~= 0 and endMs <= now then
				entry.units[unitKey] = nil
			else
				any = true
			end
		end
		if entry.gained then
			for unitKey, gainedAt in pairs(entry.gained) do
				if entry.units[unitKey] == nil and now - gainedAt > FADE_AFTER_GAIN_MS then
					entry.gained[unitKey] = nil
				end
			end
		end
		if not any and now - entry.touched > PRUNE_INTERVAL_MS then
			effects[key] = nil
			effectCount = effectCount - 1
		end
	end
end

function timers:Forget_All()
	effects = {}
	idKeys = {}
	iconKeys = {}
	effectCount = 0
	slotEffects = {}
	linksByIcon = {}
end

-- ---------------------------------------------------------------------------------------
-- The controls
-- ---------------------------------------------------------------------------------------

local function Font(size)
	return string.format("$(GAMEPAD_BOLD_FONT)|%d|thick-outline", size)
end

-- ---------------------------------------------------------------------------------------
-- Building a control
--
-- From Controls.xml where the template is there, and from plain controls where it is not. The
-- fallback exists because the alternative is a silent nothing on a machine that costs a whole
-- session to test: a manifest that did not pick the XML up, or a client that would not parse it,
-- would otherwise leave no text and no row and no way to tell from the HUD. status says which of
-- the two was used.
-- ---------------------------------------------------------------------------------------

local FALLBACK_PARTS = {
	PBsConsoleHudCustomizerSlotLabels = {
		{ name = "Timer", kind = "label", point = "CENTER", relative = "CENTER", x = 0, y = 0 },
		{ name = "Count", kind = "label", point = "TOPLEFT", relative = "TOPLEFT", x = -2, y = -4 },
	},
	PBsConsoleHudCustomizerBackBarSlot = {
		{ name = "BG", kind = "texture", point = "CENTER", relative = "CENTER", x = 0, y = 0,
			file = "EsoUI/Art/ActionBar/Gamepad/gp_backrow_abilityFrame_BLANK.dds",
			width = 52, height = 68, coords = { 0, 0.8125, 0, 1.0625 }, level = 0 },
		{ name = "Icon", kind = "texture", point = "CENTER", relative = "CENTER", x = 0, y = 0,
			width = 44, height = 44, level = 1 },
		{ name = "Overlay", kind = "texture", point = "CENTER", relative = "CENTER", x = 0, y = 0,
			file = "EsoUI/Art/ActionBar/Gamepad/gp_backrow_abilityFrame_overlay.dds",
			width = 52, height = 68, coords = { 0, 0.8125, 0, 1.0625 }, level = 2 },
		{ name = "Shade", kind = "cooldown", point = "CENTER", relative = "CENTER", x = 0, y = 0,
			width = 44, height = 44, level = 2 },
		{ name = "Timer", kind = "label", point = "CENTER", relative = "CENTER", x = 0, y = 0, level = 3 },
		{ name = "Count", kind = "label", point = "TOPLEFT", relative = "TOPLEFT", x = -2, y = -4, level = 3 },
	},
	PBsConsoleHudCustomizerShade = {},
	-- The plain look's rectangles. The anchors, widths and colours are set from Lua, so the
	-- parts only have to exist.
	PBsConsoleHudCustomizerPlainBar = {
		{ name = "Track", kind = "backdrop", point = "TOPLEFT", relative = "TOPLEFT", x = 0, y = 0, fill = true, level = 1 },
		{ name = "Fill", kind = "texture", point = "TOPLEFT", relative = "TOPLEFT", x = 0, y = 0, level = 2 },
		-- The outline: four thin rectangles, each held by two corners so it stretches with the
		-- bar. A backdrop's own edge would need an edge texture, and no art ships with this.
		{ name = "BorderTop", kind = "backdrop", point = "TOPLEFT", relative = "TOPLEFT", second = "TOPRIGHT", x = 0, y = 0, height = 1, level = 3 },
		{ name = "BorderBottom", kind = "backdrop", point = "BOTTOMLEFT", relative = "BOTTOMLEFT", second = "BOTTOMRIGHT", x = 0, y = 0, height = 1, level = 3 },
		{ name = "BorderLeft", kind = "backdrop", point = "TOPLEFT", relative = "TOPLEFT", second = "BOTTOMLEFT", x = 0, y = 0, width = 1, level = 3 },
		{ name = "BorderRight", kind = "backdrop", point = "TOPRIGHT", relative = "TOPRIGHT", second = "BOTTOMRIGHT", x = 0, y = 0, width = 1, level = 3 },
	},
}

-- A template whose own control is not a plain one.
local FALLBACK_KIND = { PBsConsoleHudCustomizerShade = "cooldown" }

local function ControlType(kind)
	if kind == "label" then
		return CT_LABEL
	end
	if kind == "cooldown" then
		return CT_COOLDOWN
	end
	if kind == "backdrop" then
		return CT_BACKDROP
	end
	if kind == "texture" then
		return CT_TEXTURE
	end
	return CT_CONTROL
end

local FALLBACK_SIZE = { PBsConsoleHudCustomizerBackBarSlot = { 52, 68 } }

function timers:BuildFallback(name, parent, template)
	local parts = FALLBACK_PARTS[template]
	if not parts or not WINDOW_MANAGER then
		return nil
	end
	local ok, control = pcall(WINDOW_MANAGER.CreateControl, WINDOW_MANAGER, name, parent,
		ControlType(FALLBACK_KIND[template]))
	if not ok or not control then
		return nil
	end
	local size = FALLBACK_SIZE[template]
	if size then
		control:SetDimensions(size[1], size[2])
	end
	for _, part in ipairs(parts) do
		local child = WINDOW_MANAGER:CreateControl(name .. part.name, control, ControlType(part.kind))
		child:SetAnchor(_G[part.point], control, _G[part.relative], part.x, part.y)
		if part.width then
			child:SetDimensions(part.width, part.height)
		end
		if part.file then
			child:SetTexture(part.file)
		end
		if part.fill then
			child:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0)
		end
		if part.second then
			child:SetAnchor(_G[part.second], control, _G[part.second], 0, 0)
		end
		if part.coords and type(child.SetTextureCoords) == "function" then
			child:SetTextureCoords(unpack(part.coords))
		end
		if part.colour and type(child.SetColor) == "function" then
			child:SetColor(unpack(part.colour))
		end
		if part.level and type(child.SetDrawLevel) == "function" then
			child:SetDrawLevel(part.level)
		end
		-- One level of nesting, for a bar built out of a cap, a middle and a cap.
		if part.children then
			for _, inner in ipairs(part.children) do
				local piece = WINDOW_MANAGER:CreateControl(name .. part.name .. inner.name, child, ControlType(inner.kind))
				piece:SetAnchor(_G[inner.point], child, _G[inner.relative], inner.x, inner.y)
				if inner.width then
					piece:SetWidth(inner.width)
				end
				if inner.file then
					piece:SetTexture(inner.file)
				end
				if inner.coords and type(piece.SetTextureCoords) == "function" then
					piece:SetTextureCoords(unpack(inner.coords))
				end
				child[inner.name] = piece
			end
		end
		if part.kind == "label" then
			child:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
			child:SetVerticalAlignment(part.name == "Timer" and TEXT_ALIGN_BOTTOM or TEXT_ALIGN_TOP)
		end
		control[part.name] = child
	end
	self.usedFallback = true
	return control
end

-- The template where it loaded, plain controls where it did not.
function timers:Build(name, parent, template, slot)
	if type(CreateControlFromVirtual) == "function" then
		local ok, control = pcall(CreateControlFromVirtual, name, parent, template, slot)
		if ok and control then
			return control, false
		end
		addon.writeErrors = addon.writeErrors or {}
		addon.writeErrors[template] = tostring(control or "no control")
	end
	local control = self:BuildFallback(name .. tostring(slot), parent, template)
	return control, control ~= nil
end

-- The children of a built control, whichever way it was built.
local function Child(control, name)
	if control[name] then
		return control[name]
	end
	if type(control.GetNamedChild) == "function" then
		local ok, child = pcall(control.GetNamedChild, control, name)
		if ok then
			return child
		end
	end
	return nil
end

function timers:FrontButton(slot)
	local control = _G["ActionButton" .. slot]
	if type(control) ~= "table" and type(control) ~= "userdata" then
		return nil
	end
	if type(control.SetAnchor) ~= "function" then
		return nil
	end
	return control
end

-- One pair of labels over the game's own button. Parented to the button, so it inherits its
-- hiding, its fading and any scale this add-on has put on the bar.
function timers:Labels(slot)
	local existing = self.labels[slot]
	if existing then
		return existing
	end
	local button = self:FrontButton(slot)
	if not button or type(CreateControlFromVirtual) ~= "function" then
		return nil
	end
	local control = self:Build("PBsConsoleHudCustomizerLabels", button, "PBsConsoleHudCustomizerSlotLabels", slot)
	if not control then
		return nil
	end
	-- On the icon rather than on the button: the gamepad icon is 61 inside a 64 button (67 in 70
	-- for the ultimate), so "the middle" and "the corner" mean the icon's, which is what the
	-- player is looking at.
	local icon = Child(button, "Icon") or button
	control:SetAnchor(TOPLEFT, icon, TOPLEFT, 0, 0)
	control:SetAnchor(BOTTOMRIGHT, icon, BOTTOMRIGHT, 0, 0)
	local pair = {
		control = control,
		timer = Child(control, "Timer"),
		count = Child(control, "Count"),
	}
	self.labels[slot] = pair
	self:StyleLabels(pair)
	return pair
end

-- Parent the back row to the bar so a front button being hidden cannot hide it.
-- Its anchor still follows the corresponding front button and custom spacing.
function timers:BackSlot(slot)
	local existing = self.back[slot]
	if existing then
		return existing
	end
	local button = self:FrontButton(slot)
	if not button or type(CreateControlFromVirtual) ~= "function" then
		return nil
	end
	local control = self:Build("PBsConsoleHudCustomizerBack", addon:Control(addon.actionBar) or button, "PBsConsoleHudCustomizerBackBarSlot", slot)
	if not control then
		return nil
	end
	local entry = {
		control = control,
		icon = Child(control, "Icon"),
		timer = Child(control, "Timer"),
		count = Child(control, "Count"),
		shade = Child(control, "Shade"),
		shadeState = {},
		button = button,
		isBack = true,
	}
	self.back[slot] = entry
	self:AnchorBackSlot(entry)
	self:StyleLabels(entry)
	return entry
end

local function ApplyFont(label, size, what)
	if not label then
		return
	end
	local descriptor = Font(size)
	local ok, err = pcall(label.SetFont, label, descriptor)
	if not ok then
		addon.writeErrors = addon.writeErrors or {}
		addon.writeErrors[what .. " font"] = tostring(err)
		return
	end
	-- What the client made of the descriptor. A size that never moves when the slider does is
	-- the one symptom that says the descriptor was not understood, and status prints it.
	if type(label.GetFontHeight) == "function" then
		local okHeight, height = pcall(label.GetFontHeight, label)
		label.pbsHeight = okHeight and height or nil
		-- The label is made as tall as its own text. Left at the client's fixed 25 it would hold
		-- a 48 the way a 25 box holds a 48: not in the middle.
		if okHeight and type(height) == "number" and height > 0 then
			pcall(label.SetHeight, label, height)
		end
	end
	label.pbsDescriptor = descriptor
end

-- One shade over the game's own icon, parented to the button so it fades and hides with the bar.
function timers:Shade(slot)
	local existing = self.shades[slot]
	if existing then
		return existing
	end
	local button = self:FrontButton(slot)
	if not button then
		return nil
	end
	local control = self:Build("PBsConsoleHudCustomizerShade", button, "PBsConsoleHudCustomizerShade", slot)
	if not control then
		return nil
	end
	local icon = Child(button, "Icon") or button
	control:ClearAnchors()
	control:SetAnchor(TOPLEFT, icon, TOPLEFT, 0, 0)
	control:SetAnchor(BOTTOMRIGHT, icon, BOTTOMRIGHT, 0, 0)
	control:SetHidden(true)
	self.shades[slot] = { control = control, state = {} }
	return self.shades[slot]
end

-- Starts the sweep when an effect begins or is refreshed, and takes it away when it ends.
-- Nothing is written in between: the engine runs the reveal itself.
function timers:UpdateShade(entry, slot, hotbar, icon, remaining, duration)
	if not entry or not entry.control then
		return
	end
	local control, state = entry.control, entry.state

	if not addon:ShadeEnabled() or not hotbar or remaining <= 0 or duration <= 0 then
		if state.running then
			control:SetHidden(true)
			state.running, state.duration, state.remaining, state.icon = nil, nil, nil, nil
		end
		return
	end

	-- A new cast, a refresh, or a different ability in the slot. A refresh is a jump back up in
	-- what is left; anything smaller is the same sweep carrying on.
	local restart = not state.running
		or state.duration ~= duration
		or state.icon ~= icon
		or remaining > (state.remaining or 0) + 250
	if restart then
		if icon and type(control.SetTexture) == "function" then
			addon:Write("shade", control.SetTexture, control, icon)
		end
		if type(control.SetFillColor) == "function" then
			addon:Write("shade", control.SetFillColor, control, 0, 0, 0, addon:ShadeDarkness() / 100)
		end
		if type(control.SetVerticalCooldownLeadingEdgeHeight) == "function" then
			addon:Write("shade", control.SetVerticalCooldownLeadingEdgeHeight, control,
				addon:Shade().leadingEdge ~= false and 4 or 0)
		end
		local USE_LEADING_EDGE = addon:Shade().leadingEdge ~= false
		local ok = addon:Write("shade", control.StartCooldown, control, remaining, duration,
			CD_TYPE_VERTICAL_REVEAL, addon:ShadeTimeType(), USE_LEADING_EDGE)
		if not ok then
			control:SetHidden(true)
			return
		end
		control:SetHidden(false)
		state.running = true
		state.duration = duration
		state.icon = icon
	end
	state.remaining = remaining
end

function timers:HideShades()
	for _, entry in pairs(self.shades) do
		entry.control:SetHidden(true)
		entry.state.running = nil
	end
	for _, entry in pairs(self.back) do
		if entry.shade then
			entry.shade:SetHidden(true)
			entry.shadeState.running = nil
		end
	end
end

-- The countdown goes exactly where the client puts its own -- CENTER, 4 down
-- (ACTION_BUTTON_TIMER_TEXT_OFFSET_Y_DEFAULT_GAMEPAD) -- so that switching between ours and the
-- game's moves nothing on the icon.
--
-- The one exception is "Both", with the game drawing its number there as well: two numbers on one
-- spot cannot be read, so ours drops to the bottom of the icon out of its way.
function timers:PlaceTimer(pair, centred)
	if not pair or not pair.timer or pair.centred == centred then
		return
	end
	local label = pair.timer
	label:ClearAnchors()
	if centred then
		label:SetAnchor(CENTER, pair.control, CENTER, 0, 0)
	else
		label:SetAnchor(BOTTOM, pair.control, BOTTOM, 0, 6)
	end
	pair.centred = centred
end

function timers:StyleLabels(pair)
	local isBack = pair.isBack == true
	ApplyFont(pair.timer, addon:TextSize("timer", isBack), isBack and "back timer" or "timer")
	if pair.timer then
		pair.timer:SetColor(TIMER_COLOUR[1], TIMER_COLOUR[2], TIMER_COLOUR[3], 1)
	end
	ApplyFont(pair.count, addon:TextSize("count", isBack), isBack and "back count" or "count")
	if pair.count then
		pair.count:SetColor(COUNT_COLOUR[1], COUNT_COLOUR[2], COUNT_COLOUR[3], 1)
	end
end

function timers:AnchorBackSlot(entry)
	local back = addon:BackBar()
	local gap = type(back.gap) == "number" and back.gap or 4
	local offsetX = type(back.offsetX) == "number" and back.offsetX or 0
	local scale = addon:BackBarScale() / 100
	entry.control:ClearAnchors()
	entry.control:SetAnchor(BOTTOM, entry.button, TOP, offsetX, -gap)
	entry.control:SetScale(scale)
end

function addon:BackBarScale()
	local scale = self:BackBar().scale
	if type(scale) ~= "number" then
		return 100
	end
	return addon.Clamp(Round(scale), self.MIN_SCALE, self.MAX_SCALE)
end

function addon:SetBackBarScale(value)
	self:BackBar().scale = addon.Clamp(Round(value), self.MIN_SCALE, self.MAX_SCALE)
end

-- Re-reads every setting that is baked into a control: the fonts and the back row's place.
function timers:Restyle()
	for _, pair in pairs(self.labels) do
		self:StyleLabels(pair)
	end
	for _, entry in pairs(self.back) do
		self:StyleLabels(entry)
		self:AnchorBackSlot(entry)
	end
end

function timers:HideAll()
	for _, pair in pairs(self.labels) do
		pair.control:SetHidden(true)
	end
	for _, entry in pairs(self.back) do
		entry.control:SetHidden(true)
	end
end

-- ---------------------------------------------------------------------------------------
-- The game's own number on the front bar
--
-- ActionButton<n>TimerText is the client's countdown, written by ActionButton:SetTimer and sized
-- by the client's own template -- an add-on cannot change its size, and the setting that turns it
-- on is private. When this add-on draws its own number on the same icon, the client's is faded
-- out instead: alpha is not something the client writes on that label (SetTimer only ever sets
-- its text and its hidden state), so it stays out of the way without a fight, and goes back to
-- full the moment ours is switched off.
-- ---------------------------------------------------------------------------------------

function timers:GameTimerLabel(slot)
	local button = self:FrontButton(slot)
	if not button or type(button.GetNamedChild) ~= "function" then
		return nil
	end
	local ok, label = pcall(button.GetNamedChild, button, "TimerText")
	if ok and label and type(label.SetAlpha) == "function" then
		return label
	end
	return nil
end

-- What is remembered is the label that was faded, not merely that a slot was: a slot whose
-- button has been rebuilt would otherwise be taken for done and left with the game's number on
-- top of ours for the rest of the session.
function timers:DimGameTimer(slot, dim)
	local label = self:GameTimerLabel(slot)
	if not label then
		return false
	end

	-- Read it rather than remember it. ActionButton:ApplyStyle re-applies the platform template
	-- to the button and its children, and that hands the label its alpha back -- and it runs on
	-- every HandleSlotChanged, which is every weapon swap, every zone load and every change to
	-- what is in a slot. A cache of "already faded" is wrong within a minute of play, and the
	-- game's number comes back from behind ours.
	local wanted = dim and 0 or 1
	-- Its own alpha: as drawn it also carries every fade of the bar above it.
	local current = addon.OwnAlpha(label)
	local okRead = current ~= nil
	local faded = self.dimmed[slot]
	if okRead and type(current) == "number" and math.abs(current - wanted) < 0.01 then
		self.dimmed[slot] = dim and label or nil
		return true
	end

	local ok, err = pcall(label.SetAlpha, label, wanted)
	if not ok then
		addon.writeErrors = addon.writeErrors or {}
		addon.writeErrors["game timer"] = tostring(err)
		return false
	end
	if dim then
		self.redims = (self.redims or 0) + 1
	end
	-- Anything faded earlier and since replaced is handed back as well.
	if faded and faded ~= label then
		pcall(faded.SetAlpha, faded, 1)
	end
	self.dimmed[slot] = dim and label or nil
	return true
end

function timers:UndimAll()
	for slot, label in pairs(self.dimmed) do
		pcall(label.SetAlpha, label, 1)
		self.dimmed[slot] = nil
	end
end

-- ---------------------------------------------------------------------------------------
-- Reading a slot
-- ---------------------------------------------------------------------------------------

local function SlotNumber(fn, slot, hotbar)
	if type(fn) ~= "function" then
		return 0
	end
	local ok, value = pcall(fn, slot, hotbar)
	if ok and type(value) == "number" then
		return value
	end
	return 0
end

local function SlotString(fn, slot, hotbar)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, slot, hotbar)
	if ok and type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

function timers:SlotIsEmpty(slot, hotbar)
	if type(GetSlotType) ~= "function" then
		return false
	end
	local ok, slotType = pcall(GetSlotType, slot, hotbar)
	if not ok then
		return false
	end
	return slotType == (ACTION_TYPE_NOTHING or 0)
end

-- The count a slot last had, held for as long as the client says that slot's effect is still
-- running.
--
-- This is the guarantee, rather than the effect bookkeeping being perfect: the countdown beside
-- it is the client's own number, and the two now end together by construction. A count that is
-- worked out again and comes back higher or lower replaces what is held -- targets dying is a
-- real change and should show -- but one that comes back as nothing while the effect is still
-- running does not take the number off the icon.
--
-- Dropped the moment the client says the effect is over, or the slot holds something else.
function timers:HoldCount(slot, hotbar, count, remaining, icon)
	self.counts = self.counts or {}
	local slotKey = slot .. ":" .. tostring(hotbar)
	local state = self.counts[slotKey]
	if not state then
		state = {}
		self.counts[slotKey] = state
	end

	local running = remaining > 0
	if not running or state.icon ~= icon then
		state.icon = icon
		state.count = nil
	end
	if count > 0 then
		state.count = count
		return count
	end
	if running and state.count then
		self.held = (self.held or 0) + 1
		return state.count
	end
	return 0
end

-- ---------------------------------------------------------------------------------------
-- Which effect a slot's countdown is for
--
-- One slot can have more than one effect of the player's own running at once, and the client
-- answers with a single number. Blue Betty is the example that came back from a PS5: the netch
-- grants its buff for 22 seconds and does something of its own every 5, and the countdown ran
-- 22, 21, ... and then, a few seconds from the end, started again at 5. That is the client
-- handing over to whichever effect has the longer left.
--
-- Read straight, that is what an add-on shows. What a player wants is the ability's own effect,
-- counted to the end, so a reading whose duration is much shorter than the one already running
-- is not taken while that one still has time on it. It is picked up the moment the longer one
-- ends, so a genuinely short effect on its own is still shown.
--
-- Everything on the icon comes through here -- the countdown, the shade and how long the target
-- count is held -- so the three cannot disagree.
-- ---------------------------------------------------------------------------------------

-- A reading is a different effect, not a re-cast, below this much of the running one's length.
local SHORTER_EFFECT_RATIO = 0.75

function timers:SlotTimer(slot, hotbar, now)
	local rawRemaining = SlotNumber(GetActionSlotEffectTimeRemaining, slot, hotbar)
	local rawDuration = SlotNumber(GetActionSlotEffectDuration, slot, hotbar)
	local icon = IconKey(SlotString(GetSlotTexture, slot, hotbar))

	-- 1. What this slot's last cast put on the world -- or the same ability's, cast from the
	-- other weapon set. While that is running the client's own reading is not asked at all: it
	-- is the reading that hands over to another effect, and it answers differently for the two
	-- bars, which is how one skill ends up counting down to two different numbers.
	local linked = self:LinkFor(slot, hotbar, icon)
	if linked then
		local linkedDuration = math.max(1, linked.endMs - linked.beginMs)
		if linked.endMs > now then
			return linked.endMs - now, linkedDuration, rawRemaining, "cast"
		end
		-- A completed cast stays completed until the player casts again.
		return 0, 0, rawRemaining, "over"
	end

	self.timers = self.timers or {}
	local slotKey = SlotKey(slot, hotbar)
	local state = self.timers[slotKey]
	if not state then
		state = {}
		self.timers[slotKey] = state
	end

	-- Another ability in the slot is another effect, whatever was running.
	if state.icon ~= icon then
		state.icon, state.endAt, state.duration = icon, nil, nil
	end

	local heldLeft = state.endAt and (state.endAt - now) or 0

	-- The client saying nothing is running is taken at its word: an effect purged, or its target
	-- dead, is over, and counting it on would be a lie the same size as the one this is here to
	-- stop.
	if rawRemaining <= 0 then
		state.endAt, state.duration = nil, nil
		return 0, 0, rawRemaining, "none"
	end

	-- 2. A shorter effect while the longer one is still going: keep counting the longer one.
	-- The same problem as the cast link solves, met from the other side, and it still earns its
	-- place for an effect that arrived without a cast of this slot behind it.
	if heldLeft > 0 and state.duration and rawDuration > 0
		and rawDuration < state.duration * SHORTER_EFFECT_RATIO and rawRemaining < heldLeft then
		self.shorterIgnored = (self.shorterIgnored or 0) + 1
		return heldLeft, state.duration, rawRemaining, "longer"
	end

	state.endAt = now + rawRemaining
	state.duration = rawDuration > 0 and rawDuration or rawRemaining
	return rawRemaining, state.duration, rawRemaining, "client"
end

-- What to write on one slot: the time left, and how many targets are under it.
function timers:SlotText(slot, hotbar, now)
	local remaining = self:SlotTimer(slot, hotbar, now)
	local timerText = nil
	if remaining > 0 then
		timerText = self:FormatTime(remaining)
	end

	local countText = nil
	-- The effect this slot's cast produced is the one to count, when there is one: it is the
	-- ability's own effect whatever the client happens to call it.
	local linked = self:LinkedEffect(slot, hotbar, now)
	local key = linked and linked.key or Normalize(SlotString(GetSlotName, slot, hotbar))
	local abilityId = SlotNumber(GetSlotBoundId, slot, hotbar)
	local icon = IconKey(SlotString(GetSlotTexture, slot, hotbar))
	local count, matchedBy = self:CountFor(key, abilityId, icon, now)
	if linked and matchedBy == "name" then
		matchedBy = "cast"
	end
	count = self:HoldCount(slot, hotbar, count, remaining, icon)
	local minimum = addon:Text().countFromOne and 1 or 2
	if count >= minimum then
		countText = tostring(count)
	end
	return timerText, countText, count, matchedBy
end

-- Seconds to the end, in the shape the game uses on the bar: a minute or more as whole minutes,
-- the last few seconds with one decimal, everything else as whole seconds.
function timers:FormatTime(ms)
	local seconds = ms / 1000
	if seconds >= 60 then
		return string.format("%dm", math.floor(seconds / 60))
	end
	if addon:Text().decimals ~= false and seconds < 10 then
		return string.format("%.1f", seconds)
	end
	return string.format("%d", math.floor(seconds + 0.5))
end

-- ---------------------------------------------------------------------------------------
-- The update
-- ---------------------------------------------------------------------------------------

function timers:BackHotbar()
	if type(GetActiveHotbarCategory) ~= "function" then
		return nil
	end
	local ok, active = pcall(GetActiveHotbarCategory)
	if not ok then
		return nil
	end
	-- Werewolf, a siege engine, a mount: the bar is not one of the weapon sets, and there is no
	-- other set to show. The game's own back row goes away for the same reason.
	if active == HOTBAR_CATEGORY_PRIMARY then
		return HOTBAR_CATEGORY_BACKUP, active
	end
	if active == HOTBAR_CATEGORY_BACKUP then
		return HOTBAR_CATEGORY_PRIMARY, active
	end
	return nil, active
end

local function SetText(label, text)
	if not label then
		return
	end
	if text then
		label:SetText(text)
		label:SetHidden(false)
	else
		label:SetHidden(true)
	end
end

function timers:Update()
	if addon.skillbar then addon.skillbar:RepairIcons() end
	local now = Now()
	self:GroundTick(now)
	if now - (self.lastPrune or 0) > PRUNE_INTERVAL_MS then
		self.lastPrune = now
		self:Prune(now)
	end

	local backHotbar, activeHotbar = self:BackHotbar()
	local showTimer = addon:ShowsTimerOn(false)
	local showBackTimer = addon:ShowsTimerOn(true)
	local showCount = addon:ShowsCount()
	local backEnabled = addon:BackBarEnabled() and backHotbar ~= nil
	local showEmpty = addon:BackBar().showEmpty ~= false
	local dim = addon:DimsGameTimer()
	local shadeEnabled = addon:ShadeEnabled()
	-- "Both" is a choice to have the game's number as well, so ours keeps out of its place
	-- whether or not the game happens to be drawing one at this moment.
	local centredTimer = addon:TimerMode() ~= "both"

	for slot = FIRST_SLOT, LAST_SLOT do
		self:DimGameTimer(slot, dim)

		-- The game's own bar.
		if showTimer or showCount then
			local pair = self:Labels(slot)
			if pair then
				self:PlaceTimer(pair, centredTimer)
				local timerText, countText = self:SlotText(slot, activeHotbar, now)
				pair.control:SetHidden(false)
				SetText(pair.timer, showTimer and timerText or nil)
				SetText(pair.count, showCount and countText or nil)
			end
		elseif self.labels[slot] then
			self.labels[slot].control:SetHidden(true)
		end

		if shadeEnabled then
			local shadeRemaining, shadeDuration = self:SlotTimer(slot, activeHotbar, now)
			self:UpdateShade(self:Shade(slot), slot, activeHotbar,
				SlotString(GetSlotTexture, slot, activeHotbar), shadeRemaining, shadeDuration)
		elseif self.shades[slot] then
			self:UpdateShade(self.shades[slot], slot, nil, nil, 0, 0)
		end

		-- The other weapon set.
		if backEnabled then
			local entry = self:BackSlot(slot)
			if entry then
				local empty = self:SlotIsEmpty(slot, backHotbar)
				if empty and not showEmpty then
					entry.control:SetHidden(true)
				else
					local icon = SlotString(GetSlotTexture, slot, backHotbar)
					entry.icon:SetTexture(icon or "")
					entry.icon:SetHidden(icon == nil)
					entry.control:SetHidden(false)
					local timerText, countText = self:SlotText(slot, backHotbar, now)
					SetText(entry.timer, showBackTimer and timerText or nil)
					SetText(entry.count, showCount and countText or nil)
					if entry.shade then
						local backRemaining, backDuration = self:SlotTimer(slot, backHotbar, now)
						-- Kept on the entry: built on every update, it was the one table this loop
						-- threw away ten times a second per slot.
						local shade = entry.shadeEntry
						if not shade or shade.control ~= entry.shade or shade.state ~= entry.shadeState then
							shade = { control = entry.shade, state = entry.shadeState }
							entry.shadeEntry = shade
						end
						self:UpdateShade(shade, slot, shadeEnabled and backHotbar or nil, icon, backRemaining, backDuration)
					end
				end
			end
		elseif self.back[slot] then
			self.back[slot].control:SetHidden(true)
		end
	end
end

-- The loop only runs while the HUD is up and there is something to draw: a hundred-millisecond
-- update behind a menu would be work for nothing, and on console every frame of it is billed to
-- the pool every add-on shares.
-- Whether the settings want anything drawn on the skill bar at all, HUD or no HUD.
function timers:Enabled()
	if not addon:SkillBarAllowed() then
		return false
	end
	return addon:ShowsTimerOn(false) or addon:ShowsTimerOn(true) or addon:ShowsCount()
		or addon:BackBarEnabled() or addon:ShadeEnabled()
end

function timers:Wanted()
	if not addon:SkillBarAllowed() then
		return false
	end
	-- Moving a slider in the settings panel calls Refresh, and the HUD is not up there: without
	-- this, a hundred-millisecond loop would run behind every menu the panel is reached through.
	-- It starts out true because the first apply happens on the HUD, before the fragment has had
	-- a state change to report.
	if self.hudShown == false then
		return false
	end
	return addon:ShowsTimerOn(false) or addon:ShowsTimerOn(true) or addon:ShowsCount()
		or addon:BackBarEnabled() or addon:ShadeEnabled()
end

function timers:Start()
	if self.running or not self:Wanted() then
		return false
	end
	self.paused = false
	if not EVENT_MANAGER or type(EVENT_MANAGER.RegisterForUpdate) ~= "function" then
		return false
	end
	EVENT_MANAGER:RegisterForUpdate(addon.name .. "Timers", UPDATE_INTERVAL_MS, function()
		timers:Update()
	end)
	self.running = true
	self:Update()
	return true
end

-- The bar is hidden: stop updating, and leave everything on it as it is -- the countdowns, the other
-- set's row, the shades, and the game's own countdown kept faded. The bar is hidden anyway, and
-- putting the game's look back here is what showed for a moment every time it faded back in
-- (1.27.8, FINDINGS 64). Only switching these off takes the look away (Stop).
function timers:Pause()
	if not self.running then
		return false
	end
	EVENT_MANAGER:UnregisterForUpdate(addon.name .. "Timers")
	self.running = false
	self.paused = true
	return true
end

function timers:Stop()
	if not self.running and not self.paused then
		return false
	end
	if self.running then
		EVENT_MANAGER:UnregisterForUpdate(addon.name .. "Timers")
	end
	self.running = false
	self.paused = false
	self:HideAll()
	self:HideShades()
	self:UndimAll()
	return true
end

-- Called whenever a setting changes, and on every HUD show.
function timers:Refresh()
	self:Restyle()
	if self:Wanted() then
		if self.running then
			self:Update()
		else
			self:Start()
		end
	elseif self.hudShown == false and self:Enabled() then
		-- A setting changed in a menu, with the bar hidden: kept paused, and the hidden bar brought
		-- up to date so it comes back showing the change. Stopping here put the game's own
		-- countdown back, which then showed for a moment as the bar faded in (FINDINGS 64).
		self:Pause()
		if self.paused then
			self:Update()
		end
	else
		self:Stop()
	end
end

function timers:OnHudStateChange(shown)
	self.hudShown = shown and true or false
	if shown then
		self:Refresh()
	else
		self:Pause()
	end
end

-- ---------------------------------------------------------------------------------------
-- What is really on the bar
--
-- One command that answers the two questions a report of "nothing is showing" raises: were the
-- controls ever built, and is the number this add-on worked out the one on screen.
-- ---------------------------------------------------------------------------------------

-- The last few effect events, kept so that a report of "it still disappears" can be answered
-- from the console rather than from here. Twenty entries, overwritten in place: no garbage and
-- no growth.
local LOG_SIZE = 20

function timers:Log(action, changeType, name, unitKey, endMs, now)
	self.log = self.log or {}
	self.logAt = ((self.logAt or 0) % LOG_SIZE) + 1
	local entry = self.log[self.logAt]
	if not entry then
		entry = {}
		self.log[self.logAt] = entry
	end
	entry.action, entry.changeType, entry.name = action, changeType, name
	entry.unit, entry.endMs, entry.at = unitKey, endMs, now
end

function timers:PrintLog()
	local Line = addon.Line
	local now = Now()
	Line("|cFF69B4%s|r -- the last effect events, oldest first", addon.title)
	Line("  gains=%d fades=%d stale fades ignored=%d already-over=%d counts held=%d",
		self.gains or 0, self.fades or 0, self.staleFades or 0, self.pastEffects or 0, self.held or 0)
	local log = self.log
	if not log or #log == 0 then
		Line("  nothing has arrived yet. The filter is on the player as the source, so only what")
		Line("  you apply is seen -- cast something with a lasting effect and look again.")
		return
	end
	for index = 1, #log do
		local at = ((self.logAt or 0) + index - 1) % #log + 1
		local entry = log[at]
		if entry and entry.action then
			Line("  %-6s %-28s unit=%s ends in %ss  (%ds ago)", entry.action, tostring(entry.name),
				tostring(entry.unit), entry.endMs == 0 and "never" or string.format("%.1f", (entry.endMs - now) / 1000),
				Round((now - (entry.at or now)) / 1000))
		end
	end
end

function timers:TrackedCount()
	return effectCount
end

function timers:TrackedNames(limit)
	local names = {}
	for key in pairs(effects) do
		names[#names + 1] = key
		if #names >= (limit or 6) then
			break
		end
	end
	return names
end

function timers:PrintSlots()
	local Line = addon.Line
	local now = Now()
	local backHotbar, activeHotbar = self:BackHotbar()

	Line("|cFF69B4%s|r -- the skill bar, slot by slot", addon.title)
	Line("  loop=%s hud=%s  countdown=%s (front=%s back=%s, the game's own dimmed=%s)",
		tostring(self.running == true), tostring(self.hudShown ~= false), addon:TimerMode(),
		tostring(addon:ShowsTimerOn(false)), tostring(addon:ShowsTimerOn(true)), tostring(addon:DimsGameTimer()))
	if addon.WeaponSwapState then
		local available, why = addon:WeaponSwapState()
		Line("  weapon swap available=%s%s  -> other set row=%s", tostring(available),
			why and (" (" .. why .. ")") or "", tostring(addon:BackBarEnabled()))
	end
	Line("  effect sources registered=%d (the player, and anything of theirs)  entries dropped for room=%d",
		self.sources or 0, self.dropped or 0)
	Line("  casts seen=%d  effects tied to a cast=%d  shorter readings refused=%d",
		self.casts or 0, self.linked or 0, self.shorterIgnored or 0)
	Line("  circles held=%d placed=%d cancelled=%d given up on=%d  aiming now=%s",
		self.groundHeld or 0, self.groundPlaced or 0, self.groundCancelled or 0, self.groundExpired or 0,
		tostring(self:GroundTargeting()))
	Line("  cast duration records=%d  wrong length=%d  unidentified effects=%d",
		self.declared or 0, self.mismatched or 0, self.unidentified or 0)
	Line("  clocks: frame=%d game=%d (they must agree for an effect's end time to mean anything)",
		Round(Now()), Round(GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0))
	Line("  effects: gains=%d fades=%d stale fades ignored=%d already-over on arrival=%d",
		self.gains or 0, self.fades or 0, self.staleFades or 0, self.pastEffects or 0)
	Line("  on you or yours, so not counted as targets: %d", self.untargeted or 0)
	Line("  the game's countdown faded back %d time(s)", self.redims or 0)
	Line("  effects tracked=%d  counts shown from %d target(s)  controls from %s", self:TrackedCount(),
		addon:Text().countFromOne and 1 or 2, self.usedFallback and "plain Lua (Controls.xml did not load)" or "Controls.xml")
	local names = self:TrackedNames(6)
	if #names > 0 then
		Line("  tracked: %s", table.concat(names, " | "))
	end

	for slot = FIRST_SLOT, LAST_SLOT do
		local pair = self.labels[slot]
		local name = SlotString(GetSlotName, slot, activeHotbar) or "-"
		local shown, duration, raw, source = self:SlotTimer(slot, activeHotbar, now)
		local remaining = shown
		local timerText, countText, count, matchedBy = self:SlotText(slot, activeHotbar, now)
		if source ~= "client" then
			Line("      from %s; the client's own reading is %dms over %dms", source,
				Round(raw or SlotNumber(GetActionSlotEffectTimeRemaining, slot, activeHotbar)),
				Round(SlotNumber(GetActionSlotEffectDuration, slot, activeHotbar)))
		end
		local linked = self:LinkFor(slot, activeHotbar, IconKey(SlotString(GetSlotTexture, slot, activeHotbar)))
		if linked then
			local held = effects[linked.key]
			local units = 0
			if held then
				for _ in pairs(held.units) do
					units = units + 1
				end
			end
			Line("      counting \"%s\" -- %s, %d unit(s) on record", tostring(linked.key),
				held and "tracked" or "|cFF4040not tracked|r", units)
			Line("      that effect runs %ds; the game says the ability lasts %ds",
				Round((linked.endMs - linked.beginMs) / 1000), Round((linked.expected or 0) / 1000))
		end
		Line("|cFF69B4  %d|r %s  left=%dms -> %s  targets=%d%s -> %s  label=%s h=%s", slot, name, Round(remaining),
			tostring(timerText), count or 0, matchedBy and (" by " .. matchedBy) or "",
			tostring(countText), pair and (pair.timer:IsHidden() and "hidden" or "shown") or "not built",
			pair and tostring(pair.timer.pbsHeight) or "-")
		if backHotbar then
			local backName = SlotString(GetSlotName, slot, backHotbar) or "-"
			local backRemaining = self:SlotTimer(slot, backHotbar, now)
			local backTimer, backCount = self:SlotText(slot, backHotbar, now)
			Line("      other set: %s  left=%dms -> %s  count=%s  row=%s", backName, Round(backRemaining),
				tostring(backTimer), tostring(backCount),
				self.back[slot] and (self.back[slot].control:IsHidden() and "hidden" or "shown") or "not built")
		end
	end
	Line("  a count is matched by name, then ability id, then icon. The name on the left has to")
	Line("  appear in the tracked list above, or the icon has to be the effect's own, for a")
	Line("  number to be written -- and it is only written from %d target(s) up.",
		addon:Text().countFromOne and 1 or 2)
end

-- Registered on the add-on's own name, beside everyone else's handler for the same event, with
-- the client's own filter so only what the player applied is counted.
function timers:Register()
	if self.registered or not EVENT_MANAGER then
		return false
	end
	-- Two registrations, because one is not enough: a great many effects a player applies are
	-- applied by something of theirs rather than by them. The netch of Blue Betty is a pet, and
	-- so are the sorcerer's familiars, the warden's bear and the nightblade's shade -- filtered
	-- to the player alone, none of what they put on the world is ever seen here, which is the
	-- whole of "the target count does not work" for those abilities. Action Duration Reminder
	-- registers the same two (Core.lua, addon.name and addon.name..'_pet').
	local sources = {
		{ suffix = "Effects", source = COMBAT_UNIT_TYPE_PLAYER },
		{ suffix = "PetEffects", source = COMBAT_UNIT_TYPE_PLAYER_PET },
	}
	for _, entry in ipairs(sources) do
		if entry.source ~= nil then
			local name = addon.name .. entry.suffix
			EVENT_MANAGER:RegisterForEvent(name, EVENT_EFFECT_CHANGED, function(...)
				timers:OnEffectChanged(...)
			end)
			if type(EVENT_MANAGER.AddFilterForEvent) == "function" and REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE then
				pcall(EVENT_MANAGER.AddFilterForEvent, EVENT_MANAGER, name, EVENT_EFFECT_CHANGED,
					REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, entry.source)
			end
			self.sources = (self.sources or 0) + 1
		end
	end

	-- The one ground-targeting event that is needed: the circle being abandoned. ENTER is not
	-- registered, because IsPlayerGroundTargeting() already answers inside the press handler,
	-- and EVENT_LEAVE_GROUND_TARGET_MODE is not registered because there is no such event --
	-- assuming there was is what broke 1.12.0 (FINDINGS 49).
	if EVENT_CANCEL_GROUND_TARGET_MODE then
		EVENT_MANAGER:RegisterForEvent(addon.name .. "GroundCancel", EVENT_CANCEL_GROUND_TARGET_MODE, function()
			timers:OnGroundCancel()
		end)
	end

	-- Which slot was pressed. The effects that follow within a moment are that slot's.
	if EVENT_ACTION_SLOT_ABILITY_USED then
		EVENT_MANAGER:RegisterForEvent(addon.name .. "Used", EVENT_ACTION_SLOT_ABILITY_USED, function(...)
			timers:OnAbilityUsed(...)
		end)
	end

	self.registered = true
	return true
end
