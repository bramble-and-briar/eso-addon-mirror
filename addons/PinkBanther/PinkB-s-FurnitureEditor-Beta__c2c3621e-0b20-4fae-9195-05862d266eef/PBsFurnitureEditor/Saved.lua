-- PB's FurnitureEditor -- saved link sets
--
-- A copied group can be kept under a name and brought back later: it is saved with the game, so it is still there
-- after a log-out, and loading one puts it on the clipboard (the quickslot wheel then offers Paste in any house of
-- yours, as after a copy).
--
--   /pbfe save [name]        keep the clipboard; no name = the add-on names it ("Redguard Table x38")
--   /pbfe saved              the saved sets, numbered, newest first
--   /pbfe load <name|n>      put one on the clipboard
--   /pbfe drop <name|n>      forget one
--
-- A name is what you typed, spaces and capitals included ("Throne room"); a name is found again whatever the case,
-- and a set can be named by its number in /pbfe saved. The settings panel (Settings.lua) does the same with rows, for
-- a console player who would rather not type.
--
-- What is kept is a copy of the clipboard: the furnishings, where they stood, how they link. A set made from a cut that
-- has not been pasted keeps that fact (it is the record of where the furnishings go), and loading it makes the
-- clipboard a pending cut again.
--
-- There is room for MAX_SAVED sets. Every one is loaded into the game's memory at log-in, which a console shares among
-- all add-ons, so the number is held down rather than left to grow.

local addon = PBS_FURNITURE_EDITOR

local Try1 = addon.Try1
local Print, Line = addon.Print, addon.Line

local MAX_SAVED = 20
local MAX_NAME = 60

-- ---------------------------------------------------------------------------------------
-- The list
-- ---------------------------------------------------------------------------------------

local function Trim(text)
	return (tostring(text or ""):gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " "))
end

-- A date for a saved set, from the game's own clock; nothing if it cannot be made.
local function DateText(timestamp)
	if not timestamp or timestamp == 0 then
		return ""
	end
	local text = Try1(GetDateStringFromTimestamp, timestamp)
	if type(text) == "string" and text ~= "" then
		return text
	end
	local ok, value = pcall(os.date, "%Y-%m-%d", timestamp)
	return ok and value or ""
end

-- The saved sets, newest first: { name, clip, at, count, date }.
function addon:SavedSets()
	local list = {}
	for name, clip in pairs(self.sv.library) do
		if type(clip) == "table" and type(clip.nodes) == "table" then
			local at = clip.savedAt or clip.takenAt or 0
			list[#list + 1] = { name = name, clip = clip, at = at, count = #clip.nodes, date = DateText(at) }
		end
	end
	table.sort(list, function(a, b)
		if a.at ~= b.at then
			return a.at > b.at
		end
		return a.name < b.name
	end)
	return list
end

-- A set by its number in /pbfe saved, by its exact name, or by its name whatever the case.
function addon:FindSaved(text)
	text = Trim(text)
	if text == "" then
		return nil
	end

	local list = self:SavedSets()
	local index = tonumber(text)
	if index and list[index] and not self.sv.library[text] then
		return list[index]
	end

	for _, entry in ipairs(list) do
		if entry.name == text then
			return entry
		end
	end
	local lower = string.lower(text)
	for _, entry in ipairs(list) do
		if string.lower(entry.name) == lower then
			return entry
		end
	end
	return nil
end

-- "Redguard Table x38": the furnishing the group hangs from, and how many there are. Unique among the saved sets.
function addon:AutoName(clip)
	local root = clip.nodes[1] and clip.nodes[1].name
	local base = string.format("%s x%d", Trim(root ~= nil and root ~= "" and root or "Group"), #clip.nodes)
	base = string.sub(base, 1, MAX_NAME)

	local name, n = base, 1
	while self:FindSaved(name) do
		n = n + 1
		name = string.format("%s (%d)", base, n)
	end
	return name
end

-- ---------------------------------------------------------------------------------------
-- Saving, loading, forgetting
-- ---------------------------------------------------------------------------------------

-- Keep the clipboard. `name` empty: named automatically. `replace`: a set of that name is overwritten rather than
-- refused. Returns the name it was saved under, or nil and why ("empty", "exists" or "full").
function addon:SaveClip(name, replace)
	local clip = self.sv.clip
	if not clip or not clip.nodes or #clip.nodes == 0 then
		return nil, "empty"
	end

	name = string.sub(Trim(name), 1, MAX_NAME)
	if name == "" then
		name = self:AutoName(clip)
	end

	local existing = self:FindSaved(name)
	if existing and not replace then
		return nil, "exists", existing.name
	end
	if not existing and #self:SavedSets() >= MAX_SAVED then
		return nil, "full"
	end

	if existing then
		self.sv.library[existing.name] = nil
	end

	local copy = addon.DeepCopy(clip)
	copy.savedAt = Try1(GetTimeStamp) or 0
	self.sv.library[name] = copy
	return name, existing and "replaced" or "new"
end

-- Put a saved set on the clipboard, as a copy. Returns the set, or nil.
function addon:LoadSaved(text, force)
	local entry = self:FindSaved(text)
	if not entry then
		Print("nothing saved under that name (/pbfe saved)")
		return nil
	end

	if self:PendingCutBlocks(force) then
		return nil
	end

	self.sv.clip = addon.DeepCopy(entry.clip)
	self.sv.clipFresh = true
	Print("%s is on the clipboard: %d furnishings%s", entry.name, entry.count, entry.clip.cut and " (a CUT, not yet pasted)" or "")
	if self.AnnounceMenu then
		self:AnnounceMenu()
	end
	return entry
end

function addon:DropSaved(text)
	local entry = self:FindSaved(text)
	if not entry then
		Print("nothing saved under that name")
		return nil
	end
	self.sv.library[entry.name] = nil
	Print("dropped %s", entry.name)
	return entry
end

-- ---------------------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------------------

-- What was typed after the command, case kept, without the words that are flags.
local function TypedText(self, ...)
	local flags = {}
	for _, flag in ipairs({ ... }) do
		flags[flag] = true
	end

	local parts = {}
	for _, word in ipairs(self.rawWords or {}) do
		if not flags[string.lower(word)] then
			parts[#parts + 1] = word
		end
	end
	return table.concat(parts, " ")
end

addon:AddCommand("save", "  /pbfe save [name]       keep the clipboard under a name (none: named for you); /pbfe saved, load, drop", function(self, words)
	local force = addon.TakeFlag(words, "force")
	local name, how, other = self:SaveClip(TypedText(self, "force"), force)

	if not name then
		if how == "empty" then
			Print("the clipboard is empty: copy a group first")
		elseif how == "exists" then
			Print("%s is already saved. Another name, or add 'force' to replace it", other)
		else
			Print("there are already %d saved sets: /pbfe drop one first", MAX_SAVED)
		end
		return
	end

	Print("%s as %s (%d furnishings). /pbfe load %s brings it back", how == "replaced" and "replaced" or "saved", name,
		#self.sv.library[name].nodes, name)
end)

addon:AddCommand("load", nil, function(self, words)
	local force = addon.TakeFlag(words, "force")
	self:LoadSaved(TypedText(self, "force"), force)
end)

addon:AddCommand("drop", nil, function(self, words)
	self:DropSaved(TypedText(self))
end)

addon:AddCommand("saved", nil, function(self)
	local list = self:SavedSets()
	if #list == 0 then
		Print("nothing saved (/pbfe save)")
		return
	end

	Print("%d of %d saved sets, newest first (/pbfe load <name or number>):", #list, MAX_SAVED)
	for index, entry in ipairs(list) do
		Line("  %d  %s  -  %d furnishings%s%s", index, entry.name, entry.count,
			entry.date ~= "" and ("  " .. entry.date) or "", entry.clip.cut and "  (a cut)" or "")
	end
end)

addon.MAX_SAVED = MAX_SAVED
