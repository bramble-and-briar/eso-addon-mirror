-- PB's Proc Set Timer
-- Author: PinkBanther
--
-- For every set you wear whose bonus text names a time -- "for 5 seconds", "once every 8
-- seconds" -- shows
--
--     * the moment the proc fires,
--     * that it is active, and for how long,
--     * the cooldown, counting down.
--
-- ---------------------------------------------------------------------------------------
-- WHAT IS NOT IN THIS ADD-ON
-- ---------------------------------------------------------------------------------------
--
-- The sets and their effects. Add-ons of this kind keep a table of set ids, ability ids,
-- durations and cooldowns, and need an update whenever a patch touches a set or a new one is
-- released. This one keeps nothing about any set: it looks at what you wear and reads the rest
-- from the game:
--
--     which sets, and how many pieces   GetItemLinkSetInfo on the worn items
--     durations, cooldown, delay        the set's own bonus text      (Parse.lua)
--     which events are the proc         ability names, see below
--     how long a debuff really has      endTime of EVENT_EFFECT_CHANGED
--
-- Every timed EFFECT gets a row of its own, with its own cooldown and its own abilities: a
-- bonus line that has a cooldown or a duration in its text and that the worn pieces switch on is
-- an effect (bonus lines add up, so a set can have several on at once), and a line with two or
-- more cooldown sentences is cut into one effect per sentence (Parse.lua).
--
-- ---------------------------------------------------------------------------------------
-- HOW A PROC IS RECOGNISED
-- ---------------------------------------------------------------------------------------
--
-- Two events carry a proc, and which one depends on what the proc does:
--
--     EVENT_EFFECT_CHANGED   a buff or debuff appeared (a damage debuff, a self buff);
--                            beginTime/endTime are exact, and an effect that began just now
--                            is a new proc while one that began earlier is only the reticle
--                            moving to an enemy that already has it.
--     EVENT_COMBAT_EVENT     a hit (glass shards bursting). The client no longer reports effect
--                            gain/fade through it, so a pure buff never shows up here.
--
-- An event belongs to a worn effect by its ability NAME (as the client localised it), in two tiers:
--
--     1. the name is the set's name, part of it, or contains it. A set with several effects on
--        then needs one picked (see Pick): by the effect's own words, by the numbers the
--        ability's description shares with them, by the buff's length, by the kind of event,
--        and last by which effect no other ability has driven yet;
--     2. for an effect only: the name appears word for word in an effect's text AND the
--        effect lasts as long as that text says. The second condition is what keeps a
--        standard buff named in many bonus texts ("Major Brutality") from being taken for a
--        proc every time one of your own skills applies it.
--
-- Names are only a heuristic and have not been measured on a console: /procset status lists
-- what was matched, /procset probe lists everything else, /procset bind pins an ability id to
-- a set (or one effect of it) by hand and /procset ignore removes one that was matched wrongly.
--
-- The cooldown starts when the proc fires and ignores further events until it is over, so a
-- burst that hits five enemies at once counts once.
--
-- Only while a set with a row is worn are the two events listened to at all.

if PBS_PROCSETTIMER then
	return
end

local DISPLAY_NAME = "PB’s Proc Set Timer"

local addon = {
	name = "PBsProcSetTimer",
	displayName = DISPLAY_NAME,
	title = DISPLAY_NAME, -- gets the version added once the manifest is read: this is the name in the add-on list
	author = "PinkBanther",
	version = "", -- read from the manifest's ## Title line, see ReadManifestVersion
}
PBS_PROCSETTIMER = addon

local em = EVENT_MANAGER
local wm = WINDOW_MANAGER

local MAX_ROWS = 8 -- more sets than this with a timer is beyond what is worn at once
local PREVIEW_ROWS = 5 -- one sample row for each colour
local FRESH_SECONDS = 0.75 -- an effect that began this recently is a new proc
local MERGE_SECONDS = 0.25 -- one proc can report several events; they count once
local FLASH_SECONDS = 0.35
local MAX_DELAY_SECONDS = 5 -- a "delay" in the text longer than this is not a proc delay
local DURATION_TOLERANCE = 0.6 -- how far an effect's length may stray from the text's seconds
local MIN_NAME_BYTES = 6 -- shorter ability names are never matched on their own
local RESCAN_MS = 2000
-- A bar swap makes the game count the worn pieces again. A row whose bonus reads as off for
-- less than this stays (the reading may be a dip, not the bonus going away); an effect or a
-- cooldown that is still running keeps its row for as long as it runs, whatever the count says.
local GRACE_SECONDS = 2
local LOG_MAX = 40

-- Sizes of the gamepad fonts the client defines (ZoFontGamepad<size>).
addon.FONT_SIZES = { 18, 20, 22, 25, 27, 34, 42 }

-- Everything about where things are and how big they are lives here, so the settings panel
-- can offer all of it. Offsets of the three elements are from the left edge of their row and
-- from its vertical middle.
addon.DEFAULTS = {
	enabled = true,
	combatOnly = false,
	onlyDetected = false, -- rows only for sets whose proc has been seen this session
	soundReady = false,

	posX = -905, -- the block's top-left corner, from the screen centre
	posY = 100,
	scale = 100,
	rowHeight = 36,

	-- The colour of each state, red / green / blue from 0 to 255. The bar and the text beside it
	-- share it. Steps of 5, so the panel's sliders land on them.
	colorActiveR = 90,
	colorActiveG = 230,
	colorActiveB = 100,
	colorCooldownR = 255,
	colorCooldownG = 155,
	colorCooldownB = 50,
	colorReadyR = 100,
	colorReadyG = 205,
	colorReadyB = 255,
	colorIdleR = 140,
	colorIdleG = 140,
	colorIdleB = 140,
	colorFlashR = 255,
	colorFlashG = 255,
	colorFlashB = 255,

	nameShow = true,
	nameX = 0,
	nameY = 0,
	nameWidth = 270,
	nameFont = 22,

	barShow = true,
	barX = 278,
	barY = 0,
	barWidth = 140,
	barHeight = 14,

	textShow = true,
	textX = 426,
	textY = 0,
	textWidth = 220,
	textFont = 22,

	bind = {}, -- [abilityId] = setId | { set = setId, line = pieces, k = n }, pinned by hand with /procset bind
	ignore = {}, -- [abilityId] = true, never matched
	hidden = {}, -- [setId] = true, this set is not followed (/procset hide, or unticked in the panel)
	selected = {}, -- [setId] = true, this set is followed whatever trackNew says
	trackNew = true, -- a set nobody decided about is followed
	known = {}, -- [setId] = true, sets with a timed effect seen worn: the panel lists them later too
}

-- Direct hits. Damage-over-time and heal-over-time ticks are left out on purpose: a ticking
-- effect would look like a new proc every time its cooldown ran out.
local HIT_RESULTS = {}
for _, suffix in ipairs({
	"DAMAGE",
	"CRITICAL_DAMAGE",
	"PRECISE_DAMAGE",
	"WRECKING_DAMAGE",
	"BLOCKED_DAMAGE",
	"DAMAGE_SHIELDED",
	"HEAL",
	"CRITICAL_HEAL",
	"POWER_ENERGIZE",
}) do
	local value = _G["ACTION_RESULT_" .. suffix]
	if value then
		HIT_RESULTS[value] = true
	end
end

-- ---- state --------------------------------------------------------------------------
-- A set is what is worn: its pieces, its name, its text. A rec is the timer of ONE timed effect of
-- a set. A set whose bonus lines hold three timed effects gets up to three recs, each with its own
-- row, cooldown and matched abilities, so they run independently of one another.
local sets = {} -- every set seen worn this session, in the order first seen
local setById = {}
local recs = {} -- every timer made for those sets
local activeRecs = {} -- the recs with a row: switched on by the worn pieces, or still running
-- [abilityId] = rec | false, one table per kind of event; cleared whenever the sets change
local verdictEffect = {}
local verdictHit = {}

local state = {
	hudShown = false,
	inCombat = false,
	listening = false,
	probe = false,
	probeSeen = {},
	log = {}, -- the last LOG_MAX lines of what changed in the worn sets, for /procset log
}
addon.preview = false

local rows = {}
local ui = { shown = 0 }
local Relayout -- defined with the UI

local function Now()
	return GetFrameTimeSeconds()
end

local function Log(text, ...)
	local log = state.log
	log[#log + 1] = string.format("%.1f ", Now()) .. string.format(text, ...)
	if #log > LOG_MAX then
		table.remove(log, 1)
	end
end

-- Cuts a text short on a character boundary (the text may be Japanese: UTF-8 bytes 128..191
-- continue a character and must not be the first byte left out).
local function Clip(text, bytes)
	if #text <= bytes then
		return text
	end
	local cut = bytes
	while cut > 0 do
		local byte = text:byte(cut + 1)
		if byte and byte >= 128 and byte < 192 then
			cut = cut - 1
		else
			break
		end
	end
	return text:sub(1, cut) .. "..."
end

-- What the game says an ability does, on one line; "" when it says nothing.
local function Describe(abilityId)
	if type(GetAbilityDescription) ~= "function" or not abilityId or abilityId <= 0 then
		return ""
	end
	local text = GetAbilityDescription(abilityId)
	if not text or text == "" then
		return ""
	end
	return Clip((addon.NormalizeText(text):gsub("%s+", " ")), 90)
end

local function NewSet(setId)
	return {
		setId = setId,
		name = nil, -- the game's own name for the set
		count = 0, -- worn pieces, Perfected ones included
		perfected = 0,
		info = nil, -- addon.ReadSetEffect result; false if the game has no such set
		recs = {}, -- [effect.key] = the timer of that effect, made when it first switched on
	}
end

local function NewRec(set, effect)
	return {
		set = set,
		setId = set.setId,
		bonus = effect, -- the effect this timer follows: its pieces, its text, its times
		active = false, -- has a row
		live = false, -- the worn pieces switch the effect's line on right now
		offSince = nil, -- since when the reading has said it is off
		cdUntil = 0,
		cdTotal = 0,
		wasOnCd = false,
		actEnd = 0, -- latest end of the effect on any unit
		actTotal = 0,
		units = {}, -- [unitId] = endTime of the effect on that unit
		flashUntil = 0,
		lastProc = -1000,
		procs = 0,
		foreign = 0, -- name matched but the effect was not ours
		seen = {}, -- [abilityId] = { name, kind, n } the events matched so far
	}
end

-- The game's own name for the set, in the player's language. Looked up on demand so a set
-- that is not worn is still labelled correctly.
local function SetName(set)
	if not set.name or set.name == "" then
		local name = GetItemSetName(set.setId)
		if name and name ~= "" then
			set.name = name
		end
	end
	return set.name or ("#" .. set.setId)
end

-- What a row is called. A set with one timed effect is just its name; a set with several says
-- which one the row is: the pieces its line needs, and the effect's number when a line holds
-- more than one.
local function RecLabel(rec)
	local name = SetName(rec.set)
	local info = rec.set.info
	if not info or info.effectCount < 2 then
		return name
	end
	local effect = rec.bonus
	if effect.n > 1 then
		return string.format("%s (%d-%d)", name, effect.required, effect.k)
	end
	return string.format("%s (%d)", name, effect.required)
end

local function ResetTimers(rec)
	rec.cdUntil = 0
	rec.cdTotal = 0
	rec.wasOnCd = false
	rec.actEnd = 0
	rec.actTotal = 0
	rec.units = {}
	rec.flashUntil = 0
	-- a new row, a zone change: what fired before says nothing about the next proc
	rec.lastProc = -1000
end

local function ClearVerdicts()
	verdictEffect = {}
	verdictHit = {}
end

-- ---- matching events to effects -----------------------------------------------------
-- Tier 1: the name and the set's name are the same thing, or one holds the other.
local function NameOfSet(set, name)
	local setName = set.name
	-- an empty set name would be "contained" in every ability name
	return setName ~= nil
		and setName ~= ""
		and (name == setName or setName:find(name, 1, true) ~= nil or name:find(setName, 1, true) ~= nil)
end

-- Tier 2: the name is written in the effect's text, and the effect lasts as long as the text says.
local function NameInText(rec, name, length)
	local bonus = rec.bonus
	if not length or not bonus.duration or math.abs(length - bonus.duration) > DURATION_TOLERANCE then
		return false
	end
	return bonus.text:find(name, 1, true) ~= nil
end

-- The numbers in a text, as a set of values ("260", "1,5" -> 260, 1.5); `skip` values are left out.
local function NumbersOf(text, skip)
	local out = {}
	for digits in text:gmatch("%d+[%.,]?%d*") do
		local value = tonumber((digits:gsub(",", ".")))
		if value and not (skip and skip[value]) then
			out[value] = true
		end
	end
	return out
end

-- The numbers an effect's text names other than its own times: "260", "130".
local function EffectNumbers(effect)
	if not effect.numbers then
		local skip = {}
		for _, seconds in ipairs({ effect.cooldown or -1, effect.duration or -1, effect.delay or -1 }) do
			skip[seconds] = true
		end
		effect.numbers = NumbersOf(effect.text, skip)
	end
	return effect.numbers
end

-- A name that belongs to a set (tier 1 says so, or the user pinned it) says nothing about WHICH of
-- the set's effects it is. With one effect on there is no question. With several, the candidates
-- are narrowed step by step -- a step that would leave none changes nothing:
--
--     1. the effect's own text names the ability, and its duration agrees with the buff's length;
--     2. the ability's own description quotes the numbers of the effect's text ("260");
--     3. the effect lasts as long as the buff does;
--     4. the effect's text names the ability;
--     5. the kind of event: a buff or debuff (it has a length) belongs to an effect that lasts,
--        a hit to one that is instant.
--
-- What is still left is told apart by the abilities seen so far: the effect this ability already
-- drove, else one no ability has driven yet (two effects of one set are two abilities), else the
-- first. The first-come step can swap two effects that look alike; /procset status shows which
-- ability drives which, and bind corrects it.
local function Pick(set, abilityId, name, length)
	local pool = {}
	for _, rec in ipairs(activeRecs) do
		if rec.set == set then
			pool[#pool + 1] = rec
		end
	end
	if #pool <= 1 then
		return pool[1]
	end

	local function narrow(test)
		local kept = {}
		for _, rec in ipairs(pool) do
			if test(rec) then
				kept[#kept + 1] = rec
			end
		end
		if #kept > 0 then
			pool = kept
		end
	end

	narrow(function(rec)
		return NameInText(rec, name, length)
	end)

	if type(GetAbilityDescription) == "function" and abilityId and abilityId > 0 then
		local description = GetAbilityDescription(abilityId)
		if description and description ~= "" then
			local described = NumbersOf(addon.NormalizeText(description))
			local best, scores = 0, {}
			for index, rec in ipairs(pool) do
				local score = 0
				for value in pairs(EffectNumbers(rec.bonus)) do
					if described[value] then
						score = score + 1
					end
				end
				scores[rec] = score
				best = zo_max(best, score)
			end
			if best > 0 then
				narrow(function(rec)
					return scores[rec] == best
				end)
			end
		end
	end

	if length then
		narrow(function(rec)
			local duration = rec.bonus.duration
			return duration ~= nil and math.abs(length - duration) <= DURATION_TOLERANCE
		end)
	end
	narrow(function(rec)
		return name ~= nil and rec.bonus.text:find(name, 1, true) ~= nil
	end)
	narrow(function(rec)
		return (length ~= nil) == (rec.bonus.duration ~= nil)
	end)

	for _, rec in ipairs(pool) do
		if rec.seen[abilityId] then
			return rec
		end
	end
	for _, rec in ipairs(pool) do
		if next(rec.seen) == nil then
			return rec
		end
	end
	return pool[1]
end

-- A pinned ability: a set id (the whole set, Pick decides) or { set, line, k } (one effect, the
-- line named by the pieces it needs).
local function Pinned(pinned, abilityId, name, length)
	local isEffect = type(pinned) == "table"
	local set = setById[isEffect and pinned.set or pinned]
	if not set then
		return false
	end
	if not isEffect then
		return Pick(set, abilityId, name, length) or false
	end
	for _, rec in ipairs(activeRecs) do
		if rec.set == set and rec.bonus.required == pinned.line and rec.bonus.k == pinned.k then
			return rec
		end
	end
	return false
end

-- The effect an ability belongs to, or nil. Decided once per ability id and kind of event: this
-- runs for every combat event of the player, so the answer is cached until the worn sets
-- change. `length` is the effect's length in seconds, nil for a hit.
local function Match(cache, abilityId, name, length)
	local cached = cache[abilityId]
	if cached ~= nil then
		return cached or nil
	end

	local sv = addon.sv
	local hit = false
	local pinned = sv.bind[abilityId]
	if sv.ignore[abilityId] then
		hit = false
	elseif pinned then
		hit = Pinned(pinned, abilityId, name, length)
	elseif name and #name >= MIN_NAME_BYTES then
		for _, rec in ipairs(activeRecs) do
			if NameOfSet(rec.set, name) then
				hit = Pick(rec.set, abilityId, name, length)
				break
			end
		end
		if not hit and length then
			for _, rec in ipairs(activeRecs) do
				if NameInText(rec, name, length) then
					hit = rec
					break
				end
			end
		end
	end
	cache[abilityId] = hit or false
	return hit or nil
end

local function Seen(rec, abilityId, name, kind)
	local entry = rec.seen[abilityId]
	if not entry then
		entry = { name = name, kind = kind, n = 0 }
		rec.seen[abilityId] = entry
		-- a row that was waiting for its first proc appears now
		if addon.sv.onlyDetected then
			Relayout()
		end
	end
	entry.n = entry.n + 1
end

local function Probe(kind, abilityId, name, detail)
	if not state.probe or state.probeSeen[abilityId] then
		return
	end
	state.probeSeen[abilityId] = true
	d(string.format("[ProcSet probe] %s %d %s %s  %s", kind, abilityId or 0, name or "?", detail or "", Describe(abilityId)))
end

-- ---- the timers ---------------------------------------------------------------------
-- Starts a proc at time t. False if it is still inside the cooldown of an earlier one, or the
-- same proc reporting again.
local function StartProc(rec, t, quiet)
	local bonus = rec.bonus
	if t < rec.cdUntil - 0.05 or t - rec.lastProc < MERGE_SECONDS then
		return false
	end
	rec.procs = rec.procs + 1
	rec.lastProc = t
	if bonus.cooldown then
		rec.cdUntil = t + bonus.cooldown
		rec.cdTotal = bonus.cooldown
	end
	if not quiet then
		rec.flashUntil = t + FLASH_SECONDS
	end
	return true
end

local function RecomputeActive(rec, now)
	local latest = 0
	for unitId, finish in pairs(rec.units) do
		if finish <= now then
			rec.units[unitId] = nil
		elseif finish > latest then
			latest = finish
		end
	end
	rec.actEnd = latest
end

local function OnEffectChanged(
	_,
	changeType,
	_,
	effectName,
	_,
	beginTime,
	endTime,
	_,
	_,
	_,
	_,
	_,
	_,
	_,
	unitId,
	abilityId,
	sourceType
)
	local now = Now()
	unitId = unitId or 0

	if changeType == EFFECT_RESULT_FADED then
		-- a fade carries the clock of the original effect, which says nothing about whether
		-- it was ours; only an effect already known to be a proc is followed
		local rec = verdictEffect[abilityId]
		if rec then
			rec.units[unitId] = nil
			RecomputeActive(rec, now)
		end
		return
	end

	local length = (beginTime > 0 and endTime > beginTime) and (endTime - beginTime) or nil
	local rec = Match(verdictEffect, abilityId, effectName, length)
	if not rec then
		if state.probe and sourceType == COMBAT_UNIT_TYPE_PLAYER then
			Probe("effect", abilityId, effectName, string.format("begin %.1f end %.1f", beginTime or 0, endTime or 0))
		end
		return
	end
	if sourceType ~= COMBAT_UNIT_TYPE_PLAYER then
		rec.foreign = rec.foreign + 1
		return
	end
	Seen(rec, abilityId, effectName, "effect")

	local bonus = rec.bonus
	local fresh = beginTime <= 0 or now - beginTime <= FRESH_SECONDS
	local startedAt = beginTime > 0 and beginTime or now
	local finish = endTime > now and endTime or nil
	if not finish and fresh and bonus.duration then
		finish = now + bonus.duration
	end

	local wasActive = rec.actEnd > now
	if finish then
		rec.units[unitId] = finish
		rec.actTotal = finish - startedAt
		if finish > rec.actEnd then
			rec.actEnd = finish
		end
	end
	if fresh then
		-- an effect that refreshes with no cooldown (a debuff kept up by light attacks)
		-- flashes only when it first appears
		StartProc(rec, startedAt, not bonus.cooldown and wasActive)
	end
end

local function OnCombatEvent(_, result, isError, abilityName, _, slotType, _, _, _, _, _, _, _, _, _, _, abilityId)
	if isError or not HIT_RESULTS[result] then
		return
	end
	-- the text names Light Attacks; they must not be taken for the proc
	if slotType == ACTION_SLOT_TYPE_LIGHT_ATTACK or slotType == ACTION_SLOT_TYPE_HEAVY_ATTACK then
		return
	end
	local rec = Match(verdictHit, abilityId, abilityName, nil)
	if not rec then
		Probe("hit", abilityId, abilityName, "result " .. tostring(result))
		return
	end
	Seen(rec, abilityId, abilityName, "hit")

	-- The hit lands after the delay the text names (glass shards burst 1.3 s after the
	-- critical), while the cooldown began at the critical.
	local bonus = rec.bonus
	local shift = (bonus.delay and bonus.delay <= MAX_DELAY_SECONDS) and bonus.delay or 0
	StartProc(rec, Now() - shift)
end

local function RefreshEvents()
	local want = #activeRecs > 0 or state.probe
	if want == state.listening then
		return
	end
	state.listening = want
	local effectNs, hitNs = addon.name .. "Effect", addon.name .. "Hit"
	if want then
		em:RegisterForEvent(effectNs, EVENT_EFFECT_CHANGED, OnEffectChanged)
		em:RegisterForEvent(hitNs, EVENT_COMBAT_EVENT, OnCombatEvent)
		em:AddFilterForEvent(hitNs, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
	else
		em:UnregisterForEvent(effectNs, EVENT_EFFECT_CHANGED)
		em:UnregisterForEvent(hitNs, EVENT_COMBAT_EVENT)
	end
end

-- ---- worn sets ----------------------------------------------------------------------
-- The timed effects the worn pieces switch on: those of every bonus line whose pieces are worn
-- (bonus lines add up, they do not replace one another). A Perfected bonus counts Perfected
-- pieces only, as the item tooltip does. Returned as { [effect.key] = effect }.
local function WornEffects(set)
	local on = {}
	local lines = set.info and set.info.bonuses
	if not lines then
		return on
	end
	for _, line in ipairs(lines) do
		local relevant = line.perfected and set.perfected or set.count
		if line.timed and relevant >= line.required then
			for _, effect in ipairs(line.effects) do
				on[effect.key] = effect
			end
		end
	end
	return on
end

-- Whether a set is followed at all. What the user decided about this very set comes first (off
-- beats on); a set nobody decided about follows the default.
local function Tracked(setId)
	local sv = addon.sv
	if sv.hidden[setId] then
		return false
	elseif sv.selected[setId] then
		return true
	end
	return sv.trackNew ~= false
end

-- Whether a row still has something to show: its effect is on, or the reading that says it is off
-- is younger than GRACE_SECONDS, or an effect or a cooldown it started is still running (an
-- effect already on an enemy outlives the bar swap that switched the bonus off).
local function Showing(rec, now)
	if rec.live or (rec.offSince and now < rec.offSince + GRACE_SECONDS) then
		return true
	end
	return rec.cdUntil > now or rec.actEnd > now
end

-- Reads every worn piece with the call the item tooltip uses (numNormalEquipped already leaves
-- out the weapon bar that is not in hand) and works out which effects have a row.
local function Rescan()
	local sv = addon.sv
	local now = Now()
	local found = {}
	local order = {}
	for slot = 0, GetBagSize(BAG_WORN) - 1 do
		local link = GetItemLink(BAG_WORN, slot)
		if link ~= "" then
			local hasSet, setName, _, numNormal, maxEquipped, setId, numPerfected = GetItemLinkSetInfo(link, true)
			if hasSet and setId and not found[setId] then
				local total = (numNormal or 0) + (numPerfected or 0)
				if maxEquipped and maxEquipped > 0 then
					total = zo_min(total, maxEquipped)
				end
				found[setId] = { name = setName, total = total, perfected = numPerfected or 0 }
				order[#order + 1] = setId
			end
		end
	end

	for _, setId in ipairs(order) do
		if not setById[setId] then
			local set = NewSet(setId)
			setById[setId] = set
			sets[#sets + 1] = set
		end
	end

	local changed = false
	local active = {}
	for _, set in ipairs(sets) do
		local piece = found[set.setId]
		local count, perfected = piece and piece.total or 0, piece and piece.perfected or 0
		if count ~= set.count or perfected ~= set.perfected then
			-- both counts side by side: the one read from a worn item and the one the game keeps for the set
			local _, _, _, bySet, bySetPerfected = GetItemSetInfo(set.setId)
			Log("%s: %d -> %d piece(s), perfected %d -> %d; the game's count for the set: %s, perfected %s",
				SetName(set), set.count, count, set.perfected, perfected, tostring(bySet), tostring(bySetPerfected))
		end
		set.count = count
		set.perfected = perfected
		if piece then
			if not set.name or set.name == "" then
				local name = GetItemSetName(set.setId)
				set.name = (name and name ~= "") and name or piece.name
			end
			if set.info == nil then
				set.info = addon.ReadSetEffect(set.setId) or false
			end
			-- remembered, so the panel can offer the set when it is not worn
			if set.info and set.info.timed and not sv.known[set.setId] then
				sv.known[set.setId] = true
			end
		end

		local on = {}
		if piece and set.info and Tracked(set.setId) then
			on = WornEffects(set)
		end

		-- every timed effect the set has, in the order of its text
		for _, effect in ipairs(set.info and set.info.effects or {}) do
			local rec = set.recs[effect.key]
			if on[effect.key] then
				if not rec then
					rec = NewRec(set, effect)
					set.recs[effect.key] = rec
					recs[#recs + 1] = rec
				end
				if not rec.active then
					rec.active = true
					ResetTimers(rec)
					changed = true
				end
				if not rec.live then
					Log("%s: the %d-piece bonus is on", RecLabel(rec), effect.required)
				end
				rec.live = true
				rec.offSince = nil
			elseif rec and rec.active then
				if rec.live then
					rec.live = false
					rec.offSince = now
					Log("%s: its bonus is off (%d piece(s))", RecLabel(rec), count)
				end
				-- Off is not gone: the row stays while an effect or cooldown runs, or while the
				-- reading may still be a dip. A set the user stopped following is the exception.
				if not Tracked(set.setId) or not Showing(rec, now) then
					Log("%s: row dropped", RecLabel(rec))
					rec.active = false
					ResetTimers(rec)
					changed = true
				end
			end
			if rec and rec.active then
				active[#active + 1] = rec
			end
		end
	end

	if changed then
		activeRecs = active
		ClearVerdicts()
		RefreshEvents()
		Relayout()
	end
end

-- ---- UI -----------------------------------------------------------------------------
-- The states a row is painted in, and the stem of their saved-variable keys (colorActiveR ...).
addon.COLOR_STATES = { "active", "cooldown", "ready", "idle", "flash" }
addon.COLOR_NAMES = { active = "Active", cooldown = "Cooldown", ready = "Ready", idle = "Idle", flash = "Flash" }

-- A state's colour as the controls want it, 0..1 each.
local function ColorOf(colorKey)
	local sv = addon.sv
	local stem = "color" .. addon.COLOR_NAMES[colorKey]
	return sv[stem .. "R"] / 255, sv[stem .. "G"] / 255, sv[stem .. "B"] / 255
end

local function Solid(name, parent, r, g, b, a)
	local tex = wm:CreateControl(name, parent, CT_TEXTURE)
	tex:SetColor(r, g, b, a)
	return tex
end

local function FontName(size)
	for _, known in ipairs(addon.FONT_SIZES) do
		if known == size then
			return "ZoFontGamepad" .. size
		end
	end
	return "ZoFontGamepad22"
end

-- How wide a row is: far enough to hold whichever elements are shown.
local function RowWidth()
	local sv = addon.sv
	local width = 1
	if sv.nameShow then
		width = zo_max(width, sv.nameX + sv.nameWidth)
	end
	if sv.barShow then
		width = zo_max(width, sv.barX + sv.barWidth)
	end
	if sv.textShow then
		width = zo_max(width, sv.textX + sv.textWidth)
	end
	return width
end

-- Puts the three elements of a row where the settings say. Everything is anchored to the row's
-- left edge and vertical middle, so no element depends on another.
local function LayoutRow(row)
	local sv = addon.sv
	local height = sv.rowHeight
	local control = row.control
	control:SetDimensions(RowWidth(), height)

	row.name:SetFont(FontName(sv.nameFont))
	row.name:SetDimensions(sv.nameWidth, height)
	row.name:ClearAnchors()
	row.name:SetAnchor(LEFT, control, LEFT, sv.nameX, sv.nameY)
	row.name:SetHidden(not sv.nameShow)

	row.barBg:SetDimensions(sv.barWidth, sv.barHeight)
	row.barBg:ClearAnchors()
	row.barBg:SetAnchor(LEFT, control, LEFT, sv.barX, sv.barY)
	row.barBg:SetHidden(not sv.barShow)

	row.text:SetFont(FontName(sv.textFont))
	row.text:SetDimensions(sv.textWidth, height)
	row.text:ClearAnchors()
	row.text:SetAnchor(LEFT, control, LEFT, sv.textX, sv.textY)
	row.text:SetHidden(not sv.textShow)

	-- what was painted no longer fits; paint it again
	row.lastText = nil
	row.lastColor = nil
	row.lastWidth = nil
end

local function BuildRow(index)
	local control = wm:CreateControl("$(parent)Row" .. index, ui.top, CT_CONTROL)
	control:SetHidden(true)

	local name = wm:CreateControl("$(parent)Name", control, CT_LABEL)
	name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

	local barBg = Solid("$(parent)BarBg", control, 0, 0, 0, 0.55)

	local fill = Solid("$(parent)Fill", barBg, 1, 1, 1, 0.9)
	fill:SetAnchor(TOPLEFT, barBg, TOPLEFT, 0, 0)
	fill:SetDrawLevel(2)

	local text = wm:CreateControl("$(parent)Text", control, CT_LABEL)
	text:SetVerticalAlignment(TEXT_ALIGN_CENTER)

	local row = { control = control, name = name, barBg = barBg, fill = fill, text = text, shown = false }
	rows[index] = row
	LayoutRow(row)
end

local function BuildUI()
	local top = wm:CreateTopLevelWindow("PBsProcSetTimerTop")
	top:SetMouseEnabled(false)
	top:SetMovable(false)
	top:SetHidden(true)
	ui.top = top
	for index = 1, MAX_ROWS do
		BuildRow(index)
	end
end

local function RefreshVisibility()
	local sv = addon.sv
	local want = sv.enabled
		and state.hudShown
		and ui.shown > 0
		and (addon.preview or not sv.combatOnly or state.inCombat)
	ui.top:SetHidden(not want)
end

-- Rows are packed from the top, so a set that is not worn leaves no gap.
function Relayout()
	local sv = addon.sv
	local shown = 0

	local function Place(row, label)
		shown = shown + 1
		row.shown = true
		row.control:SetHidden(false)
		row.control:ClearAnchors()
		row.control:SetAnchor(TOPLEFT, ui.top, TOPLEFT, 0, (shown - 1) * sv.rowHeight)
		row.name:SetText(label)
		row.lastText = nil
		row.lastColor = nil
		row.lastWidth = nil
	end

	for _, row in ipairs(rows) do
		row.rec = nil
		row.sample = nil
		row.shown = false
		row.control:SetHidden(true)
	end

	if addon.preview then
		for index = 1, PREVIEW_ROWS do
			local row = rows[index]
			Place(row, string.format(GetString(SI_PBSPST_SAMPLE_SET), index))
			row.sample = index
		end
	else
		for _, rec in ipairs(activeRecs) do
			local row = rows[shown + 1]
			if not row then
				break
			end
			local detected = next(rec.seen) ~= nil
			if not sv.onlyDetected or detected then
				Place(row, RecLabel(rec))
				row.rec = rec
			end
		end
	end

	local width = RowWidth()
	ui.top:SetDimensions(width, zo_max(shown * sv.rowHeight, 1))
	ui.shown = shown
	RefreshVisibility()
end

function addon:ApplyLayout()
	local sv = self.sv
	ui.top:ClearAnchors()
	ui.top:SetAnchor(TOPLEFT, GuiRoot, CENTER, sv.posX, sv.posY)
	ui.top:SetScale(sv.scale / 100)
	for _, row in ipairs(rows) do
		LayoutRow(row)
	end
	Relayout()
end

local function Paint(row, colorKey, width, text)
	if row.lastColor ~= colorKey then
		row.lastColor = colorKey
		local r, g, b = ColorOf(colorKey)
		row.fill:SetColor(r, g, b, 0.9)
		row.text:SetColor(r, g, b, 1)
	end
	if row.lastWidth ~= width then
		row.lastWidth = width
		row.fill:SetDimensions(zo_max(1, width), addon.sv.barHeight)
	end
	if row.lastText ~= text then
		row.lastText = text
		row.text:SetText(text)
	end
end

-- Sample rows for placing the display and trying the colours: one of each state. An idle row has
-- no bar, only its text; the last one is the flash of a proc held still.
local function UpdateSample(row)
	local barWidth = addon.sv.barWidth
	if row.sample == 1 then
		Paint(row, "active", zo_floor(barWidth * 0.64), GetString(SI_PBSPST_PREVIEW_ROW))
	elseif row.sample == 2 then
		Paint(row, "cooldown", zo_floor(barWidth * 0.6), string.format(GetString(SI_PBSPST_COOLDOWN), 4.8))
	elseif row.sample == 3 then
		Paint(row, "ready", barWidth, GetString(SI_PBSPST_READY))
	elseif row.sample == 4 then
		Paint(row, "idle", 0, GetString(SI_PBSPST_IDLE))
	else
		Paint(row, "flash", zo_floor(barWidth * 0.64), GetString(SI_PBSPST_PREVIEW_ROW))
	end
end

local function UpdateRow(row, now)
	if row.sample then
		UpdateSample(row)
		return
	end
	local rec = row.rec
	local bonus = rec.bonus
	local sv = addon.sv
	local barWidth = sv.barWidth

	if rec.actEnd <= now and next(rec.units) then
		RecomputeActive(rec, now)
	end
	local act = rec.actEnd - now
	local cd = rec.cdUntil - now

	if cd > 0 then
		rec.wasOnCd = true
	elseif rec.wasOnCd then
		rec.wasOnCd = false
		if sv.soundReady and SOUNDS and SOUNDS.COUNTDOWN_TICK then
			PlaySound(SOUNDS.COUNTDOWN_TICK)
		end
	end

	local colorKey, frac, text
	if act > 0 then
		colorKey = "active"
		frac = rec.actTotal > 0 and act / rec.actTotal or 1
		text = string.format(GetString(SI_PBSPST_ACTIVE), act)
		if cd > 0 then
			text = text .. "  " .. string.format(GetString(SI_PBSPST_COOLDOWN), cd)
		end
	elseif cd > 0 then
		colorKey = "cooldown"
		frac = rec.cdTotal > 0 and cd / rec.cdTotal or 1
		text = string.format(GetString(SI_PBSPST_COOLDOWN), cd)
	elseif bonus.cooldown then
		colorKey = "ready"
		frac = 1
		text = GetString(SI_PBSPST_READY)
	elseif not bonus.duration and rec.procs > 0 then
		-- the text gave no timing at all: at least say when it last fired
		colorKey = "idle"
		frac = 0
		text = string.format(GetString(SI_PBSPST_AGO), now - rec.lastProc)
	else
		colorKey = "idle"
		frac = 0
		text = GetString(SI_PBSPST_IDLE)
	end

	if now < rec.flashUntil then
		colorKey = "flash"
	end
	Paint(row, colorKey, zo_floor(barWidth * zo_min(1, frac)), text)
end

local function OnUpdate()
	local now = Now()
	local over = false
	for _, row in ipairs(rows) do
		if row.shown then
			UpdateRow(row, now)
			-- a row kept only by its timers goes the moment they end, not at the next poll
			if row.rec and not Showing(row.rec, now) then
				over = true
			end
		end
	end
	if over then
		Rescan()
	end
end

local function OnWornSlot(_, _, slotId)
	Log("worn slot %s updated", tostring(slotId))
	Rescan()
end

local function OnWeaponPair(_, pair, locked)
	Log("bar swap: weapon pair %s, locked %s", tostring(pair), tostring(locked))
	Rescan()
end

local function OnHudStateChange()
	state.hudShown = HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing()
	RefreshVisibility()
end

local function OnCombatState(_, inCombat)
	state.inCombat = inCombat
	RefreshVisibility()
end

-- ---- public -------------------------------------------------------------------------
-- Changing any setting re-lays the rows out; it is a few dozen calls, cheap next to the
-- slider drag that causes it.
function addon:Set(key, value)
	self.sv[key] = value
	self:ApplyLayout()
	Rescan() -- a hidden/shown change can add or remove a row
end

-- Follow a set (true) or not (false): the user's decision about that very set, which outranks
-- the default for new sets. `quiet` skips the rescan when many are set at once.
function addon:SetTracked(setId, value, quiet)
	local sv = self.sv
	if value then
		sv.hidden[setId] = nil
		sv.selected[setId] = true
	else
		sv.hidden[setId] = true
		sv.selected[setId] = nil
	end
	if not quiet then
		Rescan()
	end
end

function addon:IsTracked(setId)
	return Tracked(setId)
end

-- The sets the panel offers, as { setId, name, worn }: those worn now that have a timed effect,
-- then the others seen worn before (or decided about by hand), by name. `noScan` leaves the worn
-- items unread, for the time the add-on is still loading.
function addon:TrackableSets(noScan)
	if not noScan then
		Rescan()
	end
	local sv = self.sv
	local list, listed = {}, {}
	for _, set in ipairs(sets) do
		if set.count > 0 and set.info and set.info.timed then
			listed[set.setId] = true
			list[#list + 1] = { setId = set.setId, name = SetName(set), worn = true }
		end
	end

	local others = {}
	local function Other(setId)
		if listed[setId] then
			return
		end
		listed[setId] = true
		local set = setById[setId]
		local info = set and set.info
		if info == nil or info == false then
			info = addon.ReadSetEffect(setId)
		end
		if info and info.timed then
			local name = set and SetName(set) or GetItemSetName(setId)
			if not name or name == "" then
				name = "#" .. setId
			end
			others[#others + 1] = { setId = setId, name = name, worn = false }
		end
	end
	for _, record in ipairs({ sv.known, sv.hidden, sv.selected }) do
		for setId in pairs(record) do
			Other(setId)
		end
	end
	table.sort(others, function(a, b)
		local x, y = zo_strlower(a.name), zo_strlower(b.name)
		if x ~= y then
			return x < y
		end
		return a.setId < b.setId
	end)
	for _, entry in ipairs(others) do
		list[#list + 1] = entry
	end
	return list
end

-- Follow every set the panel lists, or none of them.
function addon:SetAllTracked(value)
	for _, entry in ipairs(self:TrackableSets()) do
		self:SetTracked(entry.setId, value, true)
	end
	Rescan()
end

-- Back to the colours the add-on ships with.
function addon:ResetColors()
	for _, state in ipairs(self.COLOR_STATES) do
		for _, channel in ipairs({ "R", "G", "B" }) do
			local key = "color" .. self.COLOR_NAMES[state] .. channel
			self.sv[key] = self.DEFAULTS[key]
		end
	end
	self:ApplyLayout() -- repaints every row
end

function addon:SetPreview(value)
	self.preview = value
	Relayout()
end

function addon:Reset()
	for key, value in pairs(self.DEFAULTS) do
		if type(value) ~= "table" then
			self.sv[key] = value
		end
	end
	self.sv.bind = {}
	self.sv.ignore = {}
	self.sv.hidden = {}
	self.sv.selected = {}
	ClearVerdicts()
	self:ApplyLayout()
	Rescan()
end

-- ---- slash command ------------------------------------------------------------------
local function Seconds(value)
	return value and string.format("%.1fs", value) or "?"
end

-- A worn set by id or by part of its name (the sets worn at some point this session).
local function FindSet(argument)
	local id = tonumber(argument)
	if id then
		return setById[id], id
	end
	argument = zo_strlower(argument or "")
	if argument == "" then
		return nil
	end
	for _, set in ipairs(sets) do
		if zo_strlower(SetName(set)):find(argument, 1, true) then
			return set, set.setId
		end
	end
	return nil
end

local function WhyNoRow(set)
	if not Tracked(set.setId) then
		return "not followed (turned off)"
	elseif set.info == false then
		return "the game has no such set"
	elseif set.count == 0 then
		return "not worn"
	elseif not set.info.timed then
		return "no time in any bonus text"
	end
	return "worn pieces switch on no bonus that has a time"
end

-- The rows a set has right now.
local function RecsOf(set)
	local mine = {}
	for _, rec in ipairs(activeRecs) do
		if rec.set == set then
			mine[#mine + 1] = rec
		end
	end
	return mine
end

-- "5-piece bonus", "5-piece bonus, effect 2 of 2", and why it is there if its bonus is off.
local function EffectName(rec)
	local bonus = rec.bonus
	local text = string.format("%d-piece bonus", bonus.required)
	if bonus.n > 1 then
		text = text .. string.format(", effect %d of %d", bonus.k, bonus.n)
	end
	if not rec.live then
		text = text .. " (switched off, kept while its timers run)"
	end
	return text
end

local function PrintSets()
	local worn = 0
	for _, set in ipairs(sets) do
		local mine = RecsOf(set)
		if set.count > 0 or #mine > 0 or not Tracked(set.setId) then
			worn = worn + 1
			local detail
			if #mine > 0 then
				local parts = {}
				for _, rec in ipairs(mine) do
					parts[#parts + 1] = EffectName(rec)
				end
				detail = (#parts > 1 and "rows: " or "row: ") .. table.concat(parts, "; ")
			else
				detail = "no row: " .. WhyNoRow(set)
			end
			d(string.format("%s (id %d): %d piece(s) -- %s", SetName(set), set.setId, set.count, detail))
		end
	end
	if worn == 0 then
		d("No set worn.")
	end
end

local function PrintStatus()
	for _, set in ipairs(sets) do
		local mine = RecsOf(set)
		if set.count > 0 or #mine > 0 then
			d(string.format("%s (id %d): %d piece(s)%s", SetName(set), set.setId, set.count, #mine == 0 and (", no row: " .. WhyNoRow(set)) or ""))
		end
		for _, rec in ipairs(mine) do
			local bonus = rec.bonus
			d("  following the " .. EffectName(rec))
			d(
				string.format(
					"    read from the text: duration %s, cooldown %s, delay %s%s",
					Seconds(bonus.duration),
					Seconds(bonus.cooldown),
					Seconds(bonus.delay),
					bonus.inferred and " (a time was placed by its position, not by its wording)" or ""
				)
			)
			d(string.format("    procs %d, other players' events skipped %d", rec.procs, rec.foreign))
			for abilityId, entry in pairs(rec.seen) do
				d(string.format("    matched %s %d %s x%d  %s", entry.kind, abilityId, entry.name or "?", entry.n, Describe(abilityId)))
			end
		end
	end
end

-- What the worn sets did lately: bar swaps, piece counts, bonuses switching on and off.
local function PrintLog()
	if #state.log == 0 then
		d("Nothing logged yet.")
		return
	end
	for _, line in ipairs(state.log) do
		d(line)
	end
end

local function PrintText(argument)
	local targets = {}
	if argument ~= "" then
		local set, id = FindSet(argument)
		if not id then
			d(string.format(GetString(SI_PBSPST_SET_NOT_FOUND), argument))
			return
		end
		-- a set id the player never wore is still readable
		targets[1] = set or NewSet(id)
	else
		for _, set in ipairs(sets) do
			if set.count > 0 then
				targets[#targets + 1] = set
			end
		end
	end
	for _, set in ipairs(targets) do
		local info = set.info or addon.ReadSetEffect(set.setId)
		d(string.format("%s (id %d)", SetName(set), set.setId))
		if not info then
			d("  the game has no such set")
		else
			for index, bonus in ipairs(info.bonuses) do
				d(string.format("  [%d] %d pc%s: %s", index, bonus.required, bonus.perfected and " (perfected)" or "", bonus.text))
				for _, hit in ipairs(bonus.parsed.hits) do
					d(string.format("      %.1f s -> %s", hit.seconds, hit.class))
				end
				-- a line cut into several effects: what each of them was read as
				if #bonus.effects > 1 then
					for _, effect in ipairs(bonus.effects) do
						d(
							string.format(
								"      effect %d of %d: duration %s, cooldown %s, delay %s: %s",
								effect.k,
								effect.n,
								Seconds(effect.duration),
								Seconds(effect.cooldown),
								Seconds(effect.delay),
								Clip(effect.text, 60)
							)
						)
					end
				end
			end
		end
	end
end

-- bind <abilityId> <set>             the whole set (the effect is picked by the ability's name)
-- bind <abilityId> <set>:<pieces>    one effect: the bonus that needs that many pieces
-- bind <abilityId> <set>:<pieces>-<n>  the n-th effect of that bonus
local function Bind(argument)
	if argument == "clear" then
		addon.sv.bind = {}
		ClearVerdicts()
		d(GetString(SI_PBSPST_BIND_CLEARED))
		return
	end
	local id, target = argument:match("^(%d+)%s+(.+)$")
	if not id then
		d(GetString(SI_PBSPST_BIND_USAGE))
		return
	end
	id = tonumber(id)
	local setPart, line, k = target:match("^(.-):(%d+)%-?(%d*)$")
	local set = FindSet(setPart or target)
	if not set then
		d(string.format(GetString(SI_PBSPST_SET_NOT_FOUND), setPart or target))
		return
	end
	local label = SetName(set)
	if line then
		k = tonumber(k) or 1
		addon.sv.bind[id] = { set = set.setId, line = tonumber(line), k = k }
		label = string.format("%s (%s%s)", label, line, k > 1 and ("-" .. k) or "")
	else
		addon.sv.bind[id] = set.setId
	end
	ClearVerdicts()
	d(string.format(GetString(SI_PBSPST_BIND_DONE), id, label))
end

local function Ignore(argument)
	if argument == "clear" then
		addon.sv.ignore = {}
		ClearVerdicts()
		d(GetString(SI_PBSPST_IGNORE_CLEARED))
		return
	end
	local id = tonumber(argument)
	if not id then
		d(GetString(SI_PBSPST_IGNORE_USAGE))
		return
	end
	addon.sv.ignore[id] = true
	ClearVerdicts()
	d(string.format(GetString(SI_PBSPST_IGNORE_DONE), id))
end

local function HideShow(argument, hide)
	local set, id = FindSet(argument)
	if not id then
		d(string.format(GetString(SI_PBSPST_SET_NOT_FOUND), argument))
		return
	end
	addon:SetTracked(id, not hide)
	local name = set and SetName(set) or ("#" .. id)
	d(string.format(GetString(hide and SI_PBSPST_HIDE_DONE or SI_PBSPST_SHOW_DONE), name, id, id))
end

local function OnSlash(argument)
	argument = zo_strtrim(argument or "")
	local command, rest = argument:match("^(%S*)%s*(.-)$")
	command = zo_strlower(command)
	if command == "on" or command == "off" then
		addon:Set("enabled", command == "on")
		d(GetString(command == "on" and SI_PBSPST_ON or SI_PBSPST_OFF))
	elseif command == "sets" then
		Rescan()
		PrintSets()
	elseif command == "status" then
		Rescan()
		PrintStatus()
	elseif command == "log" then
		PrintLog()
	elseif command == "text" then
		PrintText(rest)
	elseif command == "hide" then
		HideShow(rest, true)
	elseif command == "show" then
		HideShow(rest, false)
	elseif command == "probe" then
		state.probe = not state.probe
		state.probeSeen = {}
		RefreshEvents()
		d(GetString(state.probe and SI_PBSPST_PROBE_ON or SI_PBSPST_PROBE_OFF))
	elseif command == "bind" then
		Bind(rest)
	elseif command == "ignore" then
		Ignore(rest)
	elseif command == "preview" then
		addon:SetPreview(not addon.preview)
		d(GetString(addon.preview and SI_PBSPST_PREVIEW_ON or SI_PBSPST_PREVIEW_OFF))
	else
		d(GetString(SI_PBSPST_HELP))
	end
end

-- ---- load ---------------------------------------------------------------------------
local function OnPlayerActivated()
	-- chat is up by now; a line printed at EVENT_ADD_ON_LOADED is lost
	if not addon.bannerShown then
		addon.bannerShown = true
		d(string.format(GetString(SI_PBSPST_LOADED), addon.version))
	end
	-- a zone change or reload drops every effect
	for _, rec in ipairs(recs) do
		ResetTimers(rec)
	end
	Rescan()
end

-- The version is written only in the manifest, in the ## Title line; it is read back from there, so
-- a release changes it in one place (and in ## Version, which the game's own list shows).
local function ReadManifestVersion()
	local manager = GetAddOnManager()
	for index = 1, manager:GetNumAddOns() do
		local name, title = manager:GetAddOnInfo(index)
		if name == addon.name and title then
			local plain = title:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
			return plain:match("([%d]+[%d%.]*)%s*$") or ""
		end
	end
	return ""
end

local function OnAddOnLoaded(_, name)
	if name ~= addon.name then
		return
	end
	em:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

	addon.version = ReadManifestVersion()
	addon.title = addon.version ~= "" and (DISPLAY_NAME .. " " .. addon.version) or DISPLAY_NAME

	addon.sv = ZO_SavedVars:NewAccountWide("PBsProcSetTimer_Data", 2, nil, addon.DEFAULTS)

	BuildUI()
	addon:ApplyLayout()
	ui.top:SetHandler("OnUpdate", OnUpdate)

	state.inCombat = IsUnitInCombat("player")

	em:RegisterForEvent(addon.name .. "Activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
	em:RegisterForEvent(addon.name .. "Combat", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
	em:RegisterForEvent(addon.name .. "Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnWornSlot)
	em:AddFilterForEvent(addon.name .. "Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
	em:RegisterForEvent(addon.name .. "Weapons", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, OnWeaponPair)
	-- the events above cover equipping; this is the net under them
	em:RegisterForUpdate(addon.name .. "Rescan", RESCAN_MS, Rescan)

	HUD_SCENE:RegisterCallback("StateChange", OnHudStateChange)
	HUD_UI_SCENE:RegisterCallback("StateChange", OnHudStateChange)
	OnHudStateChange()

	SLASH_COMMANDS["/procset"] = OnSlash

	Relayout()
	if addon.InitSettings then
		addon:InitSettings()
	end
end

em:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
