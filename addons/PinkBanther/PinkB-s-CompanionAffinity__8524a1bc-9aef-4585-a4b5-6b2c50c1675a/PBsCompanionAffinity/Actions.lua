-- The table of every way of raising a companion's rapport (Catalog.lua), and how what the add-on has seen is
-- put to it.
--
-- The table is what the list shows from the start. Each of its actions begins as "not seen". A rapport change
-- that the add-on can tell is one of them (same amount, same sort of action, and, when two fit, the one whose
-- name is in the cause's name) is linked to it, and from then on the action is timed with the cooldown the
-- table gives. A change that fits two or more actions is not guessed at: it stays a row of its own, and the
-- player can say which it was (/pbcabs link). An action the add-on cannot see at all (a pickpocket, a pet, a
-- completed antiquity viewed in the journal) is marked by hand (/pbcabs used).
local A, S = PBS_CABS, PBS_CABS_STRINGS

local byId

local function Index()
	if byId then
		return byId
	end
	byId = {}
	for companionId, companion in pairs(A.CATALOG or {}) do
		for order, entry in ipairs(companion.entries) do
			entry.companion, entry.order = companionId, order
			byId[entry.id] = entry
		end
	end
	return byId
end

function A.EntryById(id)
	return id and Index()[id] or nil
end

-- The actions of this companion, in the table's order, or nil if the add-on has no table for it.
function A.EntriesOf(companionId)
	local companion = A.CATALOG and A.CATALOG[companionId]
	if companion then
		Index()
		return companion.entries
	end
	return nil
end

function A.CompanionTableName(companionId)
	local companion = A.CATALOG and A.CATALOG[companionId]
	return companion and companion.name or nil
end

-- The action's name, in the language of the texts.
function A.EntryName(entry)
	return entry[S.catalogLanguage] or entry.en
end

local function HasAmount(entry, size)
	if entry.amount == size then
		return true
	end
	for _, list in ipairs({ entry.low or {}, entry.alt or {} }) do
		for _, amount in ipairs(list) do
			if amount == size then
				return true
			end
		end
	end
	return false
end

-- Could a rapport change with this cause be this action? What was seen as "unknown" can only be an action the
-- add-on cannot see; otherwise the sorts must agree (and a craft's station, an item's category when the table
-- says them).
local function KindFits(entry, cause)
	local kind = cause.kind
	if kind == "somewhere" or kind == "unknown" then
		return entry.kind == "other"
	end
	if entry.kind ~= kind then
		return false
	end
	if kind == "craft" and entry.station and cause.key ~= entry.station then
		return false
	end
	if kind == "use" and entry.category and cause.key ~= entry.category then
		return false
	end
	return true
end

local function NameFits(entry, label)
	local lower = string.lower(label or "")
	for _, word in ipairs(entry.words or {}) do
		if lower:find(string.lower(word), 1, true) then
			return true
		end
	end
	return false
end

-- Which actions of this companion a gain of `size` with this cause could be. When several fit, those whose name
-- is in the cause's name are kept, if there are any.
function A.Candidates(companionId, cause, size)
	local entries = A.EntriesOf(companionId)
	local found = {}
	if not entries then
		return found
	end
	for _, entry in ipairs(entries) do
		if HasAmount(entry, size) and KindFits(entry, cause) then
			found[#found + 1] = entry
		end
	end
	if #found > 1 then
		local named = {}
		for _, entry in ipairs(found) do
			if NameFits(entry, cause.label) then
				named[#named + 1] = entry
			end
		end
		if #named > 0 then
			found = named
		end
	end
	return found
end

-- Link a recorded row to the action it was, if there is exactly one it can be.
function A.TryLink(row, companionId, cause, size)
	if row.entry or row.sign < 0 then
		return false
	end
	local found = A.Candidates(companionId, cause, size)
	if #found == 1 then
		row.entry = found[1].id
		return true
	end
	return false
end

-- Mark an action as done just now, by hand: for the ones the add-on cannot see.
function A:MarkUsed(entry)
	local key = string.format("%d|+|catalog|%s", entry.companion, entry.id)
	local row = A.ApplyGain(self.led.rows, key,
		{ companion = entry.companion, kind = "catalog", label = entry.en }, entry.amount, GetTimeStamp(), self.sv)
	row.entry = entry.id
	return row
end

if PBS_CABS_MARK then
	PBS_CABS_MARK("Actions")
end
