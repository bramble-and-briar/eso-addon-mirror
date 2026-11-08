-- A rapport change becomes a row of the ledger, and the ledger becomes what the HUD draws.
local A, S = PBS_CABS, PBS_CABS_STRINGS

local floor = math.floor

-- ---------------------------------------------------------------------------------------
-- The active companion
-- ---------------------------------------------------------------------------------------

function A:HasCompanion()
	return HasActiveCompanion and HasActiveCompanion() and true or false
end

function A:ActiveCompanionId()
	if self:HasCompanion() and GetActiveCompanionDefId then
		return GetActiveCompanionDefId()
	end
	return nil
end

function A:CompanionName(id)
	if id and GetCompanionName then
		local name = A.CleanName(GetCompanionName(id))
		if name ~= "" then
			return name
		end
	end
	return S.sampleCompanion
end

-- "Mirri   Rapport 1234 (Friendly)"; the level word is the game's own, in the game's language.
function A:HeaderText(id)
	local name = self:CompanionName(id)
	if not (id and GetActiveCompanionRapport) then
		return name
	end
	local value = GetActiveCompanionRapport()
	local level
	if GetActiveCompanionRapportLevel and GetString then
		local ok, text = pcall(function()
			return A.CleanName(GetString("SI_COMPANIONRAPPORTLEVEL", GetActiveCompanionRapportLevel()))
		end)
		level = ok and text ~= "" and text or nil
	end
	if level then
		return string.format(S.rapportLine, name, value, level)
	end
	return string.format(S.rapportShort, name, value)
end

-- ---------------------------------------------------------------------------------------
-- A rapport change
-- ---------------------------------------------------------------------------------------

function A:AddLog(entry)
	local log = self.led.log
	log[#log + 1] = entry
	while #log > A.LOG_MAX do
		table.remove(log, 1)
	end
end

-- The game's event, as it arrives: counted and its arguments kept before anything looks at them.
function A:OnRapportEvent(_, companionId, previous, current, amountType)
	-- Any rapport change at all, whatever it was for, excuses the actions just before it (CheckMisses).
	self.lastRapportMs = GetGameTimeMilliseconds()
	local d = self.diag
	d.rapportRaw = d.rapportRaw + 1
	d.lastRapportArgs = string.format("companion %s, rapport %s -> %s, amount type %s", tostring(companionId), tostring(previous),
		tostring(current), tostring(amountType))
	self:OnRapport(companionId, previous, current)
end

function A:OnRapport(companionId, previous, current)
	local delta = (tonumber(current) or 0) - (tonumber(previous) or 0)
	if delta == 0 or type(companionId) ~= "number" then
		return
	end
	self.diag.rapport = self.diag.rapport + 1
	local now = GetTimeStamp()
	local cause = self:Attribute(GetGameTimeMilliseconds())
	local key = string.format("%d|%s|%s|%s", companionId, delta > 0 and "+" or "-", cause.kind, cause.key)
	local row, tier, before = A.ApplyGain(self.led.rows, key,
		{ companion = companionId, kind = cause.kind, label = cause.label }, delta, now, self.sv)
	-- If it can only be one of the table's actions, it is that one (more than one: it stays a row of its own).
	local linked = A.TryLink(row, companionId, cause, math.abs(delta))
	self:AddLog({
		t = now,
		c = companionId,
		d = delta,
		kind = cause.kind,
		label = cause.label,
		tier = tier,
		since = row.n > 1 and now - before or nil,
		notes = table.concat(cause.notes, "; "),
		entry = row.entry,
		linked = linked or nil,
	})
	self:Render()
end

-- ---------------------------------------------------------------------------------------
-- Rows
-- ---------------------------------------------------------------------------------------

-- "Kill: Goblin". A kind that says it all by itself ("Dig") has no label.
function A.Describe(row)
	local kind = S["kind_" .. row.kind] or row.kind
	if row.label ~= "" then
		return string.format("%s: %s", kind, row.label)
	end
	return kind
end

-- What a row says on the HUD: the timer (the cooldown's state, on the left), the detail (what the action is, on the
-- right), and which colour the timer is. An estimate is marked with ~ (before a countdown, after READY).
function A.RowTexts(entry)
	local row, action = entry.row, entry.action
	-- A line of the table says what the action is; any other line says what the add-on saw.
	local detail
	if action then
		detail = string.format("+%d  %s", action.amount, A.EntryName(action))
	else
		detail = string.format("%s%d  %s", row.sign > 0 and "+" or "-", row.amount, A.Describe(row))
	end
	if entry.state == "unseen" then
		return S.timerUnseen, detail, "unseen"
	elseif entry.state == "free" then
		return S.timerFree, detail, "free"
	end
	-- A cooldown that is only an estimate never says READY outright: it says READY?, in a quieter colour. The
	-- countdown to it is marked ~. Only a cooldown that is known (a rule, learned, or set by the user) says READY.
	local mark = entry.src == "estimate" and "~" or ""
	local timer, colorKey = nil, entry.state
	if entry.state == "cooling" then
		timer = string.format(S.timerCooling, mark .. A.FormatDuration(entry.value, true))
	elseif entry.state == "ready" then
		if entry.src == "estimate" then
			timer, colorKey = S.timerMaybe, "maybe"
		else
			timer = S.timerReady
		end
	else
		timer = string.format(S.timerElapsed, A.FormatDuration(entry.value))
	end
	return timer, detail, colorKey
end

-- Cooling comes first, then what is ready, then what was done but has no cooldown known, then what is always
-- available, then what has not been seen.
local GROUP = { cooling = 1, ready = 2, elapsed = 3, free = 4, unseen = 5 }

local function Before(a, b)
	if a.group ~= b.group then
		return a.group < b.group
	end
	if a.value ~= b.value then
		return a.value < b.value
	end
	return a.key < b.key
end

-- The lines of the active companion that the HUD draws, in order: cooling (soonest ready first), ready
-- (the one ready the shortest time first), done but with no cooldown known (newest first), always available,
-- and not seen (the biggest reward first).
--
-- With the table shown, every action of the companion is a line, and a recorded row that is linked to one
-- is that line (the newest if several are). Rows that are not linked to any action are lines of their own.
function A:BuildRows(now, companionId)
	local sv = self.sv
	local list = {}
	local horizon = sv.expireHours * 3600
	local actions = sv.showCatalog and A.EntriesOf(companionId) or nil

	local linked = {}
	for key, row in pairs(self.led.rows) do
		if actions and row.companion == companionId and row.entry then
			local best = linked[row.entry]
			if not best or row.last > best.row.last then
				linked[row.entry] = { key = key, row = row }
			end
		end
	end

	if actions then
		for _, action in ipairs(actions) do
			if action.cd ~= "once" and action.amount >= sv.minAmount then
				local hit = linked[action.id]
				local line
				if hit and now - hit.row.last <= horizon then
					local state, value, src = A.StateOf(hit.row, now, sv)
					if state ~= "once" then
						line = { key = hit.key, row = hit.row, action = action, state = state, value = value, src = src }
					end
				end
				if not line then
					-- Not done yet as far as the add-on knows (or done long ago): the table's own line.
					line = { key = "action|" .. action.id, action = action, state = action.cd == false and "free" or "unseen",
						value = (1000 - action.amount) * 1000 + action.order }
				elseif line.state == "free" then
					line.value = (1000 - action.amount) * 1000 + action.order
				end
				line.group = GROUP[line.state]
				list[#list + 1] = line
			end
		end
	end

	for key, row in pairs(self.led.rows) do
		if row.companion == companionId
			and not (actions and row.entry and linked[row.entry])
			and row.amount >= sv.minAmount
			and (row.sign > 0 or sv.showNegative)
			and now - row.last <= horizon
		then
			local state, value, src = A.StateOf(row, now, sv)
			if state ~= "once" then
				list[#list + 1] = { key = key, row = row, state = state, value = value, src = src, group = GROUP[state] }
			end
		end
	end
	table.sort(list, Before)
	local capacity = sv.maxRows * sv.columns
	while #list > capacity do
		table.remove(list)
	end
	return list
end

-- What the list says when it has nothing to draw, and why: never seen a change at all, seen changes
-- but none for this companion, or recorded but all hidden (too small, a loss, too old).
function A:EmptyNote(companionId)
	local sv = self.sv
	local total, small, loss = 0, 0, 0
	for _, row in pairs(self.led.rows) do
		if row.companion == companionId then
			total = total + 1
			if row.sign < 0 and not sv.showNegative then
				loss = loss + 1
			elseif row.amount < sv.minAmount then
				small = small + 1
			end
		end
	end
	if total > 0 then
		return string.format(S.allHidden, total, small, sv.minAmount, loss)
	end
	if self.diag.rapportRaw == 0 then
		return S.noChangeSeen
	end
	return string.format(S.noneForThis, self.diag.rapportRaw)
end

-- Every row of the active companion, newest first: the numbered list /pbcabs cd refers to.
function A:ListRows(companionId)
	local list = {}
	for key, row in pairs(self.led.rows) do
		if row.companion == companionId then
			list[#list + 1] = { key = key, row = row }
		end
	end
	table.sort(list, function(a, b)
		if a.row.seen ~= b.row.seen then
			return a.row.seen > b.row.seen
		end
		return a.key < b.key
	end)
	return list
end

-- Four made-up rows, one of each look (a countdown, an estimate, a ready one, one with no cooldown
-- known), for the settings preview and /pbcabs test. They do not depend on the user's settings or on
-- the time of day, so the preview always looks the same.
local DEMO_ESTIMATES = { useEstimates = true, est1 = 5, est5 = 60, est10 = 60, est25 = 1200 }
local DEMO_NONE = { useEstimates = false, est1 = 0, est5 = 0, est10 = 0, est25 = 0 }

function A:DemoRows(now)
	local function row(kind, label, amount, ago, user)
		return { companion = 0, kind = kind, label = label, sign = 1, amount = amount, n = 1, last = now - ago, seen = now - ago, user = user }
	end
	local specs = {
		{ row("quest", S.sampleDaily, 125, 5 * 3600 + 41 * 60, 86400), DEMO_ESTIMATES },
		{ row("craft", S.sampleCraft, 5, 18 * 60), DEMO_ESTIMATES },
		{ row("kill", S.sampleKill, 10, 61 * 60), DEMO_ESTIMATES },
		{ row("place", S.samplePlace, 10, 12 * 60 + 34), DEMO_NONE },
	}
	local list = {}
	for i, spec in ipairs(specs) do
		local state, value, src = A.StateOf(spec[1], now, spec[2])
		list[i] = { key = tostring(i), row = spec[1], state = state, value = value, src = src, group = GROUP[state] or 3 }
	end
	-- and two lines of the table that have not been done: one with a cooldown, one always available
	local function action(amount, name)
		return { amount = amount, en = name, jp = name, order = amount }
	end
	list[#list + 1] = { key = "u", action = action(10, S.sampleUnseen), state = "unseen", value = 1, group = GROUP.unseen }
	list[#list + 1] = { key = "f", action = action(5, S.sampleFree), state = "free", value = 1, group = GROUP.free }
	table.sort(list, Before)
	return list
end

-- ---------------------------------------------------------------------------------------
-- Text for the commands
-- ---------------------------------------------------------------------------------------

local function Clock(seconds)
	return string.format("%02d:%02d:%02d", floor(seconds / 3600) % 24, floor(seconds / 60) % 60, seconds % 60)
end

local function CooldownWord(row, sv)
	local kind, value, src = A.CooldownOf(row, sv)
	if kind == "daily" then
		return "daily (" .. src .. ")"
	elseif kind == "once" then
		return "once only (" .. src .. ")"
	elseif kind == "seconds" then
		return string.format("%s (%s)", A.FormatDuration(value), src)
	elseif kind == "free" then
		return "none, always available (" .. src .. ")"
	end
	return "unknown"
end

function A:ListLines()
	local id = self:ActiveCompanionId()
	local lines = {}
	if not id then
		return lines
	end
	local now = GetTimeStamp()
	for index, entry in ipairs(self:ListRows(id)) do
		local row = entry.row
		local state, value = A.StateOf(row, now, self.sv)
		local where = state == "cooling" and ("cooling, " .. A.FormatDuration(value, true) .. " left")
			or state == "ready" and "ready"
			or state == "once" and "once only"
			or state == "free" and "always available"
			or ("no cooldown known, " .. A.FormatDuration(value) .. " since")
		local action = row.entry and A.EntryById(row.entry)
		lines[#lines + 1] = string.format("%d. %s%d %s | x%d | cooldown %s | %s%s%s", index, row.sign > 0 and "+" or "-",
			row.amount, A.Describe(row), row.n, CooldownWord(row, self.sv), where,
			row.low and (" | cooling seen at " .. A.FormatDuration(row.low)) or "",
			action and (" | is: " .. A.EntryName(action)) or "")
	end
	return lines
end

-- The table of this companion's actions, numbered in the table's order (what /pbcabs used and link refer to),
-- each with where it stands.
function A:CatLines()
	local id = self:ActiveCompanionId()
	local lines = {}
	local actions = id and A.EntriesOf(id)
	if not actions then
		return lines
	end
	local now = GetTimeStamp()
	local linked = {}
	for _, row in pairs(self.led.rows) do
		if row.companion == id and row.entry then
			local best = linked[row.entry]
			if not best or row.last > best.last then
				linked[row.entry] = row
			end
		end
	end
	for order, action in ipairs(actions) do
		local row = linked[action.id]
		local where = "not seen"
		if row then
			local state, value = A.StateOf(row, now, self.sv)
			where = state == "cooling" and ("cooling, " .. A.FormatDuration(value, true) .. " left")
				or state == "ready" and ("ready (" .. A.FormatDuration(value) .. " ago)")
				or state == "free" and "always available"
				or state == "once" and "once only"
				or ("done " .. A.FormatDuration(value) .. " ago, cooldown not known")
		elseif action.cd == false then
			where = "always available"
		elseif action.cd == "once" then
			where = "once only"
		end
		local cd = action.cd == "once" and "once" or action.cd == "daily" and "daily" or action.cd == false and "none"
			or type(action.cd) == "number" and A.FormatDuration(action.cd) or "unknown"
		lines[#lines + 1] = string.format("%d. +%d %s | %s%s | %s", order, action.amount, A.EntryName(action), cd,
			action.q and "?" or "", where)
	end
	return lines
end

function A:LogLines(count)
	local log = self.led.log
	local lines = {}
	local now = GetTimeStamp()
	-- The newest entry is last in the table; shown newest first.
	local first = math.max(1, #log - count + 1)
	for i = #log, first, -1 do
		local e = log[i]
		lines[#lines + 1] = string.format("%s ago  %s%d  %s  [%s%s]  companion %s\n    notes: %s",
			A.FormatDuration(now - e.t), e.d > 0 and "+" or "", e.d, A.Describe({ kind = e.kind, label = e.label }), e.tier,
			e.since and (", " .. A.FormatDuration(e.since) .. " after the last") or "", tostring(e.c),
			(e.notes and e.notes ~= "") and e.notes or "none")
	end
	return lines
end

function A:StatusLines()
	local lines = {}
	local function add(text, ...)
		lines[#lines + 1] = select("#", ...) > 0 and string.format(text, ...) or text
	end
	local d = self.diag
	add("%s", self.title)
	local boot = PBS_CABS_BOOT
	add("start-up: %s; %d file(s) ran to the end (/pbcabs boot has the whole trace)", boot and boot.init or "?", boot and #boot.files or 0)
	for _, text in ipairs(d.loadErrors) do
		add("LOAD ERROR - %s", text)
	end

	-- Why the list is, or is not, on the screen: every condition on its own.
	local function yes(value)
		return value and "yes" or "no"
	end
	local sv, m, root = self.sv, self.metrics, self.root
	if not root then
		add("hud: the window was never created")
	else
		add("hud: player active %s, switched on %s, HUD scene up %s, companion out %s, notice without one %s",
			yes(self.active), yes(sv.enabled), yes(self:HudShowing()), yes(self:HasCompanion()), yes(sv.showWithoutCompanion))
		add("hud: wants to show %s, window hidden %s, update timer %s, sample list %s",
			yes(self:WantsToShow()), yes(root:IsHidden()), yes(self.tickOn), yes(self:ShowingDemo()))
		if m then
			add("layout: rows %dpx, top line %dpx, width %d%% = %dpx, at %d,%d, opacity %d%%", A.TEXT_SIZES[sv.textSize],
				A.TEXT_SIZES[sv.headerSize], sv.width, m.width, sv.x, sv.y, sv.opacity)
		end
		-- Where the engine actually put the window, and how big the screen is: a list that is "shown" but
		-- cannot be seen is off the screen or under something.
		local ok, left, top, screenW, screenH = pcall(function()
			return root:GetLeft(), root:GetTop(), GuiRoot:GetWidth(), GuiRoot:GetHeight()
		end)
		if ok then
			add("screen: %s x %s; the list's top-left corner is at %s, %s", tostring(screenW), tostring(screenH),
				tostring(left), tostring(top))
		end
		local drawn = {}
		for i, line in ipairs(self.lines) do
			if not line.timer.hidden then
				drawn[#drawn + 1] = i
			end
		end
		add("drawn: top line %s, %d row line(s) in use, note %s", self.header.hidden and "hidden" or ('"' .. tostring(self.header.text) .. '"'),
			#drawn, (self.note and not self.note.hidden) and "shown" or "hidden")
	end

	local id = self:ActiveCompanionId()
	if id then
		add("companion: id %d, %s", id, self:CompanionName(id))
		if GetActiveCompanionRapport then
			add("rapport: %d (min %s, max %s)", GetActiveCompanionRapport(),
				tostring(GetMinimumRapport and GetMinimumRapport()), tostring(GetMaximumRapport and GetMaximumRapport()))
		end
	else
		add("companion: none active")
	end
	local actions = id and A.EntriesOf(id)
	if id then
		add("table of actions: %s", actions and string.format("%d actions (%s); shown %s", #actions, A.CompanionTableName(id),
			self.sv.showCatalog and "yes" or "no") or ("none for companion id " .. id .. ": only what was seen is listed"))
	end
	local mine, all = 0, 0
	for _, row in pairs(self.led.rows) do
		all = all + 1
		if row.companion == id then
			mine = mine + 1
		end
	end
	add("rows: %d for this companion, %d on this character; %d log entries", mine, all, #self.led.log)
	add("rapport events from the game: %d; recorded as a change: %d (traced to a note %d, to the place %d); errors %d%s",
		d.rapportRaw, d.rapport, d.matched, d.fallback, d.errors, d.lastError and (" - last: " .. d.lastError) or "")
	add("last rapport event: %s", d.lastRapportArgs or "none yet")
	add("actions seen with no rapport change after them, from a source that had paid: %d (each shows its cooldown is still running)", d.misses)
	local byCompanion = {}
	for _, row in pairs(self.led.rows) do
		byCompanion[row.companion] = (byCompanion[row.companion] or 0) + 1
	end
	local ids = {}
	for companion, count in pairs(byCompanion) do
		ids[#ids + 1] = { companion = companion, count = count }
	end
	table.sort(ids, function(a, b)
		return a.companion < b.companion
	end)
	local parts = {}
	for _, entry in ipairs(ids) do
		parts[#parts + 1] = string.format("companion %d: %d", entry.companion, entry.count)
	end
	add("rows recorded, by companion: %s; shown from +%d%s", #parts > 0 and table.concat(parts, ", ") or "none", self.sv.minAmount,
		self.sv.showNegative and "" or ", losses hidden")
	local now = GetTimeStamp()
	local reset = A.NextReset(now)
	add("time: unix %d; next daily reset (rule, 10:00 UTC) in %s", now, A.FormatDuration(reset - now))
	if GetTimedActivityTypeResetTimeS and TIMED_ACTIVITY_TYPE_DAILY then
		local ok, stamp = pcall(GetTimedActivityTypeResetTimeS, TIMED_ACTIVITY_TYPE_DAILY)
		if ok and type(stamp) == "number" then
			add("the game's daily timer (endeavours) ends in %s", A.FormatDuration(stamp - now))
		end
	end
	local nowMs = GetGameTimeMilliseconds()
	local recent = {}
	for i = #self.ring, 1, -1 do
		local note = self.ring[i]
		recent[#recent + 1] = string.format("%s:%s -%.1fs", note.kind, note.label, (nowMs - note.t) / 1000)
	end
	add("recent notes: %s", #recent > 0 and table.concat(recent, "; ") or "none")
	return lines
end

if PBS_CABS_MARK then
	PBS_CABS_MARK("Tracker")
end
