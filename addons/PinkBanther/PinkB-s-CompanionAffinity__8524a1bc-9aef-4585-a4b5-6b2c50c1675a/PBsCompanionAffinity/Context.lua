-- What the player has just done, so a rapport change can be traced to something.
--
-- Each event the add-on watches only drops a note into a small ring (kind, label, game time). Nothing
-- here reads the world or draws: a note is a few table writes, and the ring never holds more than
-- RING_MAX of them. The notes are only looked at when rapport changes (Tracker.lua).
--
-- Which notes exist is a guess about what raises rapport, taken from the community tables. A rapport
-- change with no matching note is not lost: it falls back to the place the player is in, and
-- /pbcabs log shows every note near each change, so a missing kind can be added from real data.
local A, S = PBS_CABS, PBS_CABS_STRINGS
local em = EVENT_MANAGER

-- How long before a rapport change a note may be and still be its cause. The change comes from the
-- server a moment after the action; how long a moment is has not been measured.
local WINDOW_MS = 4000
-- Notes this close to the newest one count as simultaneous, and the likelier kind wins.
local TIE_MS = 400
-- /pbcabs log lists notes up to this old, those outside the window marked as such.
local KEEP_MS = 15000
local RING_MAX = 12

-- What is likelier the cause when two notes are simultaneous.
local PRIORITY = {
	quest = 7, dig = 6, scry = 6, lead = 5, craft = 5, book = 4, talk = 4, use = 4, lockpick = 4,
	kill = 3, travel = 3, mount = 2, interact = 2, place = 1,
}
A.WINDOW_MS = WINDOW_MS

-- An action whose note is not followed by any rapport change shows that a cooldown is still running (see
-- CheckMisses). All of them but a change of place, which happens at every sub-zone border.
local MISSABLE = {
	quest = true, kill = true, craft = true, book = true, talk = true, dig = true, scry = true, lead = true,
	use = true, interact = true, lockpick = true, mount = true, travel = true,
}
local MISS_AFTER_MS = WINDOW_MS + 1500 -- when an action is judged: the window has closed, with a little to spare
local PENDING_MAX = 20

A.ring = {}
A.pending = {}

local function Now()
	return GetGameTimeMilliseconds()
end

function A:Note(kind, label, key)
	local ring, now = self.ring, Now()
	label = label or ""
	local note = { t = now, kind = kind, label = label, key = key or (label ~= "" and label) or kind }
	ring[#ring + 1] = note
	while #ring > RING_MAX or (#ring > 0 and now - ring[1].t > KEEP_MS) do
		table.remove(ring, 1)
	end
	-- While a companion is out, the action is also set aside to be judged later: did rapport follow?
	if MISSABLE[kind] and self:HasCompanion() then
		local pending = self.pending
		pending[#pending + 1] = { t = now, ts = GetTimeStamp(), kind = kind, key = note.key, companion = self:ActiveCompanionId() }
		while #pending > PENDING_MAX do
			table.remove(pending, 1)
		end
	end
end

-- Judge the actions set aside by Note. One that no rapport change followed, within the window, was not
-- paid for: if it is the action of a source that has paid out before, that source's cooldown was still
-- running, and had been for at least the time since it paid. That is recorded as `low`, and a cooldown
-- that is only an estimate, or only learned, and is no longer than that, is given up (see A.StateOf).
-- Any rapport change at all in the window excuses the action: the change may be for something else
-- that was done at the same moment, and the action was then judged by the change.
function A:CheckMisses()
	local pending = self.pending
	if #pending == 0 then
		return
	end
	local nowMs = Now()
	local waiting = {}
	for _, p in ipairs(pending) do
		if nowMs - p.t < MISS_AFTER_MS then
			waiting[#waiting + 1] = p
		elseif not (self.lastRapportMs and self.lastRapportMs >= p.t) then
			local row = self.led.rows[string.format("%d|+|%s|%s", p.companion or -1, p.kind, p.key)]
			if row and row.last and p.ts > row.last then
				row.low = math.max(row.low or 0, p.ts - row.last)
				self.diag.misses = self.diag.misses + 1
			end
		end
	end
	self.pending = waiting
end

-- Where the player is: the sub-zone when there is one, the zone otherwise. Empty if the game does not say.
function A.PlaceName()
	local name = ""
	if GetPlayerActiveSubzoneName then
		name = A.CleanName(GetPlayerActiveSubzoneName())
	end
	if name == "" and GetPlayerActiveZoneName then
		name = A.CleanName(GetPlayerActiveZoneName())
	end
	return name
end

-- The cause of a rapport change at game time `nowMs`: { kind, label, key, notes } where `notes` lists
-- every recent note, newest first ("kill:Goblin -0.2s"), for the log.
function A:Attribute(nowMs)
	local ring = self.ring
	local best
	local listed = {}
	for i = #ring, 1, -1 do
		local note = ring[i]
		local age = nowMs - note.t
		listed[#listed + 1] = string.format("%s:%s -%.1fs%s", note.kind, note.label, age / 1000, age > WINDOW_MS and "*" or "")
		if age <= WINDOW_MS then
			if not best then
				best = note
			elseif best.t - note.t <= TIE_MS and (PRIORITY[note.kind] or 0) > (PRIORITY[best.kind] or 0) then
				best = note
			end
		end
	end
	local cause
	if best then
		cause = { kind = best.kind, label = best.label, key = best.key }
		self.diag.matched = self.diag.matched + 1
	else
		-- Nothing recent: a rapport change just for being somewhere (a guildhall, a wayshrine, Artaeum).
		local place = A.PlaceName()
		if place ~= "" then
			-- Not a visit to a place (that is a "place" note): the action is not known, only where it was.
			cause = { kind = "somewhere", label = place, key = place }
		else
			cause = { kind = "unknown", label = "", key = "?" }
		end
		self.diag.fallback = self.diag.fallback + 1
	end
	cause.notes = listed
	return cause
end

-- ---------------------------------------------------------------------------------------
-- The watchers
-- ---------------------------------------------------------------------------------------

local function guard(fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			A.diag.errors = A.diag.errors + 1
			A.diag.lastError = tostring(err)
		end
	end
end

-- Which crafting station a CRAFTING_TYPE_* constant is, as the key of a string.
local function CraftName(craftSkill)
	local names = {
		{ CRAFTING_TYPE_BLACKSMITHING, "craft_blacksmithing" },
		{ CRAFTING_TYPE_CLOTHIER, "craft_clothier" },
		{ CRAFTING_TYPE_WOODWORKING, "craft_woodworking" },
		{ CRAFTING_TYPE_JEWELRYCRAFTING, "craft_jewelry" },
		{ CRAFTING_TYPE_ENCHANTING, "craft_enchanting" },
		{ CRAFTING_TYPE_ALCHEMY, "craft_alchemy" },
		{ CRAFTING_TYPE_PROVISIONING, "craft_provisioning" },
		{ CRAFTING_TYPE_SCRIBING, "craft_scribing" },
	}
	for _, entry in ipairs(names) do
		if entry[1] ~= nil and entry[1] == craftSkill then
			return entry[2]
		end
	end
	return "craft_other"
end

-- Which sort of item was used, as the key of a string: the sound category the game files it under.
local function UseName(category)
	local groups = {
		{ "use_eat", ITEM_SOUND_CATEGORY_FOOD, ITEM_SOUND_CATEGORY_BREAD, ITEM_SOUND_CATEGORY_MEAT, ITEM_SOUND_CATEGORY_FISH },
		{ "use_drink", ITEM_SOUND_CATEGORY_DRINK },
		{ "use_potion", ITEM_SOUND_CATEGORY_POTION },
		{ "use_repair", ITEM_SOUND_CATEGORY_REPAIR_KIT },
		{ "use_soulgem", ITEM_SOUND_CATEGORY_SOUL_GEM },
	}
	for _, group in ipairs(groups) do
		for i = 2, 5 do
			if group[i] ~= nil and group[i] == category then
				return group[1]
			end
		end
	end
	return "use_item"
end

function A:RegisterContext()
	local name = self.name
	local function on(suffix, event, fn)
		if event ~= nil then
			em:RegisterForEvent(name .. suffix, event, guard(fn))
		end
	end

	on("Quest", EVENT_QUEST_COMPLETE, function(_, questName)
		self:Note("quest", A.CleanName(questName))
	end)
	on("Craft", EVENT_CRAFT_COMPLETED, function(_, craftSkill)
		local key = CraftName(craftSkill)
		self:Note("craft", S[key], key)
	end)
	on("Book", EVENT_SHOW_BOOK, function(_, title, _, _, _, bookId)
		self:Note("book", A.CleanName(title), bookId and tostring(bookId) or nil)
	end)
	-- These three say what they are by their kind alone, so the label stays empty.
	on("Dig", EVENT_ANTIQUITY_DIGGING_ANTIQUITY_UNEARTHED, function()
		self:Note("dig", "", "dig")
	end)
	on("Scry", EVENT_ANTIQUITY_SCRYING_RESULT, function()
		self:Note("scry", "", "scry")
	end)
	on("Lead", EVENT_ANTIQUITY_LEAD_ACQUIRED, function()
		self:Note("lead", "", "lead")
	end)
	on("Talk", EVENT_CHATTER_BEGIN, function()
		-- Who is being spoken to: the interaction target's tag. If the game gives no name, one shared note.
		local who = GetUnitName and A.CleanName(GetUnitName("interact")) or ""
		self:Note("talk", who, who ~= "" and who or "talk")
	end)
	-- Something in the world was used: the target's name, and the verb the reticle offered ("Harvest").
	on("Interact", EVENT_CLIENT_INTERACT_RESULT, function(_, result, targetName)
		if CLIENT_INTERACT_RESULT_SUCCESS ~= nil and result ~= CLIENT_INTERACT_RESULT_SUCCESS then
			return
		end
		local name = A.CleanName(targetName)
		if name == "" then
			return
		end
		local verb = ""
		if GetGameCameraInteractableActionInfo then
			local ok, action = pcall(GetGameCameraInteractableActionInfo)
			if ok and type(action) == "string" then
				verb = A.CleanName(action)
			end
		end
		-- The verb is in the label to read, not in the key: harvesting and examining the same thing are one source.
		self:Note("interact", verb ~= "" and (verb .. " " .. name) or name, name)
	end)
	-- An item was used (eaten, drunk, a repair kit): which sort is all the game says.
	on("Item", EVENT_INVENTORY_ITEM_USED, function(_, category)
		local key = UseName(category)
		self:Note("use", S[key], key)
	end)
	on("Mount", EVENT_MOUNTED_STATE_CHANGED, function(_, mounted)
		if mounted then
			self:Note("mount", "", "mount")
		end
	end)
	on("Lockpick", EVENT_LOCKPICK_SUCCESS, function()
		self:Note("lockpick", "", "lockpick")
	end)
	on("Travel", EVENT_START_FAST_TRAVEL_INTERACTION, function()
		self:Note("travel", "", "travel")
	end)
	on("Zone", EVENT_ZONE_CHANGED, function(_, zoneName, subZoneName)
		local place = A.CleanName(subZoneName)
		if place == "" then
			place = A.CleanName(zoneName)
		end
		if place ~= "" then
			self:Note("place", place)
		end
	end)

	-- The player's own killing blows, and the companion's; the engine narrows the event, so the
	-- handler only runs for those (PB's KillLog registers the same filter).
	-- EVENT_COMBAT_EVENT: eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType,
	-- sourceName, sourceType, targetName -- the ninth argument is the one that died.
	local function onKill(_, _, _, _, _, _, _, _, targetName)
		self:Note("kill", A.CleanName(targetName))
	end
	for suffix, sourceType in pairs({ KillSelf = COMBAT_UNIT_TYPE_PLAYER, KillCompanion = COMBAT_UNIT_TYPE_PLAYER_COMPANION }) do
		if EVENT_COMBAT_EVENT ~= nil and sourceType ~= nil then
			em:RegisterForEvent(name .. suffix, EVENT_COMBAT_EVENT, guard(onKill))
			em:AddFilterForEvent(name .. suffix, EVENT_COMBAT_EVENT,
				REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_KILLING_BLOW,
				REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, sourceType)
		end
	end
end

if PBS_CABS_MARK then
	PBS_CABS_MARK("Context")
end
