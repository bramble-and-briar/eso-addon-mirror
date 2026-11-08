-- PB's Companion Affinity Boost Supporter
-- Author: PinkBanther
--
-- Shows, on the HUD, when each way of raising your companion's rapport can be used again.
--
-- ---------------------------------------------------------------------------------------
-- WHAT THE GAME GIVES, AND WHAT IT DOES NOT
-- ---------------------------------------------------------------------------------------
--
-- There is no call that returns a rapport cooldown. The one fact the client hands an add-on is
-- EVENT_COMPANION_RAPPORT_UPDATE(companionId, previousRapport, currentRapport, amountType): rapport
-- changed, from this to that. It does not say why. So the add-on does three things:
--
--   1. Context.lua keeps the last few things the player did (a kill, a quest turned in, something
--      crafted, a book opened, a dig, a conversation, a change of place).
--   2. Tracker.lua, on a rapport change, picks the likeliest of them as the cause. The cause plus the
--      companion and the sign of the change is the SOURCE (a row on the HUD).
--   3. This file times it: when did this source last pay out in full, and how long until it may again.
--
-- A source's cooldown is, in order of trust:
--   user      set with /pbcabs cd
--   rule      known for certain from the published tables (below)
--   learned   the shortest time a source was seen to pay out in full a second time
--   estimate  a typical cooldown for a gain of that size (settings; marked ~ on the HUD)
--   none      only the time since the last gain is shown
--
-- Many sources pay a large amount ("+10") when ready and a small one ("+1") while cooling. That small
-- gain is evidence the cooldown has NOT ended, and is used that way (`low`).
--
-- Nothing here has been measured on a console yet; README.md lists what has to be.

PBS_CABS = {
	name = "PBsCompanionAffinity",
	baseTitle = "PB’s Companion Affinity",
	chatName = "PB’s Affinity",
	author = "PinkBanther",
	version = "0.5.1",
	slash = "/pbcabs",
	shortSlash = "/pbaffinity",
	savedVar = "PBsCompanionAffinity_Data",
	defaults = {
		enabled = true,
		preview = true,
		-- Shown, as a one-line notice, even when no companion is out, so it is plain that the add-on is
		-- running and where it sits. Turn it off once the position is settled.
		showWithoutCompanion = true,
		opacity = 90,
		-- Where the list's top-left corner is, in pixels from the screen's top-left corner.
		x = 60,
		y = 420,
		-- Text sizes are steps into A.TEXT_SIZES (1 = 18 ... 8 = 42): the rows, and the header line
		-- above them. `width` is a percentage of the width that suits the row text.
		textSize = 3,
		headerSize = 4,
		width = 100,
		-- Rows in a column, and how many columns: the list of every action is long, so it runs in columns.
		maxRows = 20,
		columns = 2,
		-- The full table of ways of raising this companion's rapport is listed from the start, each as not yet
		-- seen until it is done (Actions.lua, Catalog.lua).
		showCatalog = true,
		-- Everything is shown to begin with: a list that hides what it has seen cannot be told from one
		-- that has seen nothing. Raise it to keep the +1 kills out of the list.
		minAmount = 1,
		expireHours = 48,
		useEstimates = true,
		-- Rapport losses are listed too: "show everything" was the request. They are written with a minus.
		showNegative = true,
		-- Typical cooldown, in minutes, for a gain of each size (0 = no estimate). They are the commonest
		-- values in the community tables: one-off kills 5 minutes, most small rewards an hour, the big
		-- ones about a day (20 hours).
		est1 = 5,
		est5 = 60,
		est10 = 60,
		est25 = 1200,
	},
}
local A = PBS_CABS
-- `rapportRaw` counts every EVENT_COMPANION_RAPPORT_UPDATE the game sent, whatever it held; `rapport`
-- only those that were a change for a companion. The difference between them, and the last event's
-- arguments, tell "the game never sent one" from "it sent one that was dropped".
A.diag = { rapportRaw = 0, lastRapportArgs = nil, rapport = 0, matched = 0, fallback = 0, misses = 0, errors = 0, lastError = nil, loadErrors = {} }

-- The font sizes the list can use: the client's own gamepad fonts of these sizes (ZoFontGamepad<size>),
-- which it defines and uses itself, so none has to be built on use.
A.TEXT_SIZES = { 18, 20, 22, 25, 27, 34, 36, 42 }

-- The version comes from the manifest, the same way PB's other add-ons read it.
do
	local manager = GetAddOnManager and GetAddOnManager()
	if manager then
		for index = 1, manager:GetNumAddOns() do
			local name, title = manager:GetAddOnInfo(index)
			if name == A.name and title then
				local plain = title:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
				A.version = plain:match("(%d+[%d%.]*)%s*$") or A.version
				break
			end
		end
	end
end
A.title = A.baseTitle .. " " .. A.version

local floor, max, min = math.floor, math.max, math.min

-- ---------------------------------------------------------------------------------------
-- Settings: what each one may be
-- ---------------------------------------------------------------------------------------

local RANGES = {
	opacity = { 10, 100 },
	x = { 0, 1900 },
	y = { 0, 1060 },
	textSize = { 1, 8 },
	headerSize = { 1, 8 },
	width = { 60, 250 },
	maxRows = { 1, 20 },
	columns = { 1, 3 },
	minAmount = { 1, 125 },
	expireHours = { 1, 168 },
	est1 = { 0, 1440 },
	est5 = { 0, 1440 },
	est10 = { 0, 1440 },
	est25 = { 0, 1440 },
}
local ENUMS = {}
A.RANGES = RANGES

local function number(value, low, high, default)
	local n = tonumber(value)
	if not n or n ~= n then
		return default
	end
	return max(low, min(high, n))
end

function A:Validate(key, value, default)
	if RANGES[key] then
		return floor(number(value, RANGES[key][1], RANGES[key][2], default) + 0.5)
	end
	if ENUMS[key] then
		return ENUMS[key][value] and value or default
	end
	if type(value) ~= type(default) then
		return default
	end
	return value
end

function A:Set(key, value)
	if self.defaults[key] == nil then
		return
	end
	self.sv[key] = self:Validate(key, value, self.defaults[key])
	self:ApplyLayout()
	self:Render()
	self:RefreshVisibility()
end

function A:Reset()
	for key, value in pairs(self.defaults) do
		self.sv[key] = value
	end
	self:ApplyLayout()
	self:Render()
	self:RefreshVisibility()
end

-- An error that was caught: counted and kept, for /pbcabs status. (Here, not in UI.lua: the code that
-- catches errors must not depend on a file that may have failed to load.)
function A:NoteError(err)
	self.diag.errors = self.diag.errors + 1
	self.diag.lastError = tostring(err)
end

-- A name from the game can carry a grammar suffix ("Luceda^Fx").
function A.CleanName(raw)
	return (tostring(raw or ""):gsub("%^.*$", ""))
end

-- ---------------------------------------------------------------------------------------
-- Time (no game calls in here: every function takes the time it is to work with)
-- ---------------------------------------------------------------------------------------

-- Daily things reset at 10:00 UTC (the community tables say 10:00 UTC, 6:00 EDT). The add-on does not
-- trust this blindly: /pbcabs status prints it next to what GetTimedActivityTypeResetTimeS says.
A.DAILY_RESET_UTC = 10 * 3600

-- The first daily reset strictly after `ts` (a unix time).
function A.NextReset(ts)
	local day = floor((ts - A.DAILY_RESET_UTC) / 86400)
	return (day + 1) * 86400 + A.DAILY_RESET_UTC
end

-- 59 -> "0:59", 3725 -> "1:02:05", 100000 -> "1d 3h". `up` rounds a countdown up, so a cooldown that
-- has not ended never reads 0:00.
function A.FormatDuration(seconds, up)
	seconds = up and math.ceil(seconds) or floor(seconds)
	if seconds < 0 then
		seconds = 0
	end
	local d = floor(seconds / 86400)
	local h = floor((seconds % 86400) / 3600)
	local m = floor((seconds % 3600) / 60)
	local s = seconds % 60
	if d > 0 then
		return string.format(PBS_CABS_STRINGS.days, d, h)
	end
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

-- ---------------------------------------------------------------------------------------
-- Cooldowns
-- ---------------------------------------------------------------------------------------

-- What is known for certain from the amount alone (the published tables agree on every row of these
-- sizes). Only for gains. nil = nothing known; "unknown" = no row of this size has a known cooldown,
-- so no estimate is made either.
--   500+  a companion quest, once each
--   125   a daily quest, or a daily-like event
--   75    viewing a completed antiquity, 20 hours
--   150+  no data
function A.Rule(amount, sign)
	if sign and sign < 0 then
		return nil
	end
	if amount >= 500 then
		return "once"
	end
	if amount == 125 then
		return "daily"
	end
	if amount == 75 then
		return 20 * 3600
	end
	if amount > 125 then
		return "unknown"
	end
	return nil
end

-- Which of the four estimate settings covers a gain of this size.
function A.AmountClass(amount)
	if amount >= 25 then
		return "est25"
	elseif amount >= 10 then
		return "est10"
	elseif amount >= 5 then
		return "est5"
	end
	return "est1"
end

-- A cooldown learned from two gains closer together than this is not believed: two different things
-- that were taken for one source would look like a cooldown of a second or two.
local MIN_LEARN = 60

-- -> kind ("daily" | "seconds" | "once" | nil), seconds, where it came from
function A.CooldownOf(row, sv)
	local user = row.user
	if user == "daily" then
		return "daily", nil, "user"
	elseif type(user) == "number" and user > 0 then
		return "seconds", user, "user"
	end
	local rule = A.Rule(row.amount, row.sign)
	if rule == "once" then
		return "once", nil, "rule"
	elseif rule == "daily" then
		return "daily", nil, "rule"
	elseif type(rule) == "number" then
		return "seconds", rule, "rule"
	elseif rule == "unknown" then
		return nil
	end
	-- A row that is one of the table's actions has that action's cooldown, as the wiki gives it: exact when the
	-- wiki is sure ("wiki"), an estimate when it marks it with a question mark. What was learned from a shorter
	-- gap beats it. An action whose cooldown the wiki does not know has no estimate by size, only what was learned.
	local entry = row.entry and A.EntryById and A.EntryById(row.entry)
	if entry then
		local cd = entry.cd
		local src = entry.q and "estimate" or "wiki"
		if cd == "once" then
			return "once", nil, src
		elseif cd == "daily" then
			return "daily", nil, src
		elseif cd == false then
			return "free", nil, src
		elseif type(cd) == "number" then
			if row.learned and row.learned < cd then
				return "seconds", row.learned, "learned"
			end
			return "seconds", cd, src
		end
		if row.learned then
			return "seconds", row.learned, "learned"
		end
		return nil
	end
	if row.learned then
		return "seconds", row.learned, "learned"
	end
	if sv.useEstimates then
		local minutes = sv[A.AmountClass(row.amount)]
		if minutes and minutes > 0 then
			return "seconds", minutes * 60, "estimate"
		end
	end
	return nil
end

-- Where a source stands at `now`:
--   "cooling", seconds left, source of the cooldown
--   "ready",   seconds since it became ready, source
--   "elapsed", seconds since the last gain (no cooldown is known)
--   "once",    a once-only reward: it has no cooldown to show
--   "free",    an action with no cooldown at all: always available
function A.StateOf(row, now, sv)
	local since = max(0, now - row.last)
	local kind, value, src = A.CooldownOf(row, sv)
	if kind == "once" then
		return "once"
	end
	if kind == "free" then
		return "free"
	end
	if kind == nil then
		return "elapsed", since
	end
	local readyAt
	if kind == "daily" then
		readyAt = A.NextReset(row.last)
	else
		readyAt = row.last + value
	end
	-- A small gain came while this cooldown was supposed to be over: it is longer than believed, and
	-- by how much is not known. An estimate or a learned value gives way; a rule or the user's own
	-- number does not.
	if row.low and src ~= "user" and src ~= "rule" and (readyAt - row.last) <= row.low then
		return "elapsed", since
	end
	if now >= readyAt then
		return "ready", now - readyAt, src
	end
	return "cooling", readyAt - now, src
end

-- Record one rapport change in the ledger. `spec` = { companion, kind, label }; `delta` is the signed
-- change. Returns the row, whether this was the full amount ("full") or a smaller one that came while
-- the source was cooling ("reduced"), and the time of the gain before it.
function A.ApplyGain(rows, key, spec, delta, now, sv)
	local size = math.abs(delta)
	local row = rows[key]
	if not row then
		row = {
			companion = spec.companion,
			kind = spec.kind,
			label = spec.label,
			sign = delta > 0 and 1 or -1,
			amount = size,
			n = 0,
			last = now,
			seen = now,
		}
		rows[key] = row
	end
	local previous = row.last
	local tier = "full"
	if size < row.amount then
		tier = "reduced"
	elseif size > row.amount then
		row.amount = size
	end

	if tier == "full" then
		local gap = now - previous
		-- Only two full gains of the same size say anything about the cooldown between them; if the
		-- one before was a smaller (reduced) gain taken for a full one, the gap means nothing.
		if row.n > 0 and row.lastFull == size and gap >= MIN_LEARN then
			if not row.gap or gap < row.gap then
				row.gap = gap
			end
			-- It paid out in full again sooner than the cooldown assumed: that cooldown is at most this.
			local kind, value, src = A.CooldownOf(row, sv)
			if kind == "seconds" and (src == "estimate" or src == "learned" or src == "wiki") and gap < value then
				row.learned = gap
			end
		end
		row.last = now
		row.low = nil
		row.n = row.n + 1
		row.lastFull = size
	else
		-- Evidence that the cooldown has not ended yet, `now - previous` after the full gain.
		row.low = max(row.low or 0, max(0, now - previous))
	end
	row.seen = now
	row.lastDelta = delta
	return row, tier, previous
end

-- ---------------------------------------------------------------------------------------
-- The saved ledger
-- ---------------------------------------------------------------------------------------

A.KEEP_DAYS = 14
A.LOG_MAX = 40

function A.RowOk(row)
	return type(row) == "table"
		and type(row.companion) == "number"
		and type(row.last) == "number"
		and type(row.amount) == "number"
		and row.amount > 0
		and (row.sign == 1 or row.sign == -1)
		and type(row.kind) == "string"
		and type(row.label) == "string"
		and type(row.n) == "number"
end

-- Called once the saved variables are loaded. Whatever is in the file, the add-on runs on values it
-- can use.
function A:Sanitize(now)
	local sv, led = self.sv, self.led
	for key, default in pairs(self.defaults) do
		sv[key] = self:Validate(key, sv[key], default)
	end
	-- 0.1.0 kept the text size as a word; it is a step now.
	sv.fontSize = nil
	-- Up to 0.3.0 the list hid gains under +5 and all losses and showed six rows, and the saved variables kept
	-- those defaults as if they were choices. Everything is shown now (the user asked for all of it); the saved
	-- values are replaced once. (`migrated` is not a default, so old files lack it.)
	if sv.migrated == nil then
		sv.minAmount = self.defaults.minAmount
		sv.showNegative = self.defaults.showNegative
	end
	-- The rows are counted per column from 0.5.0 (twenty, in two columns, take the whole table).
	if sv.migrated ~= 3 then
		sv.maxRows = self.defaults.maxRows
		sv.migrated = 3
	end
	if type(led.rows) ~= "table" then
		led.rows = {}
	end
	if type(led.log) ~= "table" then
		led.log = {}
	end
	local oldest = now - A.KEEP_DAYS * 86400
	for key, row in pairs(led.rows) do
		if not A.RowOk(row) then
			led.rows[key] = nil
		else
			if type(row.seen) ~= "number" then
				row.seen = row.last
			end
			if row.seen < oldest then
				led.rows[key] = nil
			else
				if type(row.learned) ~= "number" then
					row.learned = nil
				end
				if type(row.low) ~= "number" then
					row.low = nil
				end
				if type(row.gap) ~= "number" then
					row.gap = nil
				end
				if type(row.lastFull) ~= "number" then
					row.lastFull = nil
				end
				if type(row.entry) ~= "string" or not (A.EntryById and A.EntryById(row.entry)) then
					row.entry = nil
				end
				if row.user ~= "daily" and type(row.user) ~= "number" then
					row.user = nil
				end
			end
		end
	end
	local log = {}
	for _, entry in ipairs(led.log) do
		if type(entry) == "table" and type(entry.t) == "number" and type(entry.d) == "number" then
			log[#log + 1] = entry
		end
	end
	while #log > A.LOG_MAX do
		table.remove(log, 1)
	end
	led.log = log
end

if PBS_CABS_MARK then
	PBS_CABS_MARK("Core")
end
