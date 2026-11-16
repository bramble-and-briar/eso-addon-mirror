-- PB's Auto Loot
-- Author: PinkBanther
--
-- Three jobs, none of them needing the player to press anything:
--   Loot.lua     takes everything when a loot window opens (a chest, a body, a plant, a fishing hole ... and a box
--                that the player opened: its window is a loot window like any other)
--   Boxes.lua    opens the boxes (containers) that arrive in the backpack by itself -- OFF by default; the loot
--                window that follows is emptied by the first job
--   Collect.lua  binds a set piece that is not in the player's set collection yet, which is what adds it
--
-- ---------------------------------------------------------------------------------------
-- WHY THIS ADD-ON IS WRITTEN THE WAY IT IS
-- ---------------------------------------------------------------------------------------
--
-- It exists because the add-on it replaces (Lykeion's AutoLoot+) leaks memory. A leak in an add-on that runs for
-- every loot window and every item that arrives is a leak that grows with play time, so the rule here is that
-- nothing the add-on does per event may keep anything:
--
--   * no table, closure or string is created per loot window, per item or per tick on the normal path. The
--     queues are two small tables that are reused (Queue below) and are emptied as they are worked off; the
--     counters are numbers; every handler is one function created at file load.
--   * the only strings built while playing are the chat summary lines, one per finished batch, and a link
--     for the last item of a batch (kept in one field that the next batch overwrites).
--   * nothing is remembered about an item. The one list that can grow is the list of container item ids that
--     refused to open twice; it holds at most MAX_SKIPPED numbers.
--   * the timer that drives the queues is registered only while there is work, and unregistered when the
--     queues are empty, so an idle add-on costs nothing.
--   * `/pbal status` prints the heap size and the queue sizes, and tests/run.lua plays tens of thousands of
--     loot windows and items against a stand-in and fails if anything the add-on owns keeps growing.
--
-- ---------------------------------------------------------------------------------------
-- WHAT THE ADD-ON MAY CALL (read from ESOUIDocumentation.txt API 101051; none of it measured on a PS5 yet)
-- ---------------------------------------------------------------------------------------
--
--   LootAll(ignoreStolenItems)  no marker. The client calls it from its own "Take all" button.
--   BindItem(bag, slot)         no marker. The client's inventory has a "Bind" action that calls it (after a
--                               confirm dialog that is Lua in the client, not part of the call).
--   UseItem(bag, slot)          *protected*. Add-on code cannot call a protected function directly; the VM offers
--                               CallSecureProtected(name, ...) for that. Which of the two works for an add-on on a
--                               console is not known, so Route() asks the game and Call() tells the rest.
--
-- Add-on Lua is insecure code and a restricted call from it raises the client's UI error screen, which pcall does
-- not catch (see PB's notes "ESO add-on code is insecure"). So every one of those calls goes through Call(): the API
-- is asked first (IsPrivateFunction / IsProtectedFunction), and `pending` is written to the saved variables before
-- the call and cleared when it returns. If the error screen appears and the player reloads, the file still says
-- "pending": that is one strike against the group, and two strikes in a row switch the group off.
--
-- ---------------------------------------------------------------------------------------
-- WHAT IS STORED
-- ---------------------------------------------------------------------------------------
--
-- One account-wide file: the options below plus `probe`, `strikes` and `pending` (the guard above).

PBS_AUTO_LOOT = {
	name = "PBsAutoLoot",
	baseTitle = "PB’s Auto Loot",
	chatName = "PB’s Auto Loot",
	author = "PinkBanther",
	version = "0.1.4",
	slash = "/pbautoloot",
	shortSlash = "/pbal",
	savedVar = "PBsAutoLoot_Data",
	TICK_MS = 250, -- how often the queues are looked at while there is work
	LOOT_MAX_ATTEMPTS = 3, -- LootAll calls for one loot window (it ends at EVENT_LOOT_CLOSED)
	LOOT_QUIET_MS = 4000, -- a window that has been quiet this long is a new one even if the close event was missed
	OPEN_CHECK_MS = 3000, -- how long a box that was used may take to change the backpack before it counts as refused
	BIND_CHECK_MS = 1500, -- the same for a bind
	FLUSH_QUIET_MS = 1500, -- a summary line is printed this long after the last thing it counts
	FLUSH_MAX_MS = 8000, -- ... and at the latest this long after the first
	MAX_QUEUE = 400, -- slots waiting in one queue; more are not queued (a sweep can be run again)
	MAX_SKIPPED = 32, -- container item ids remembered as refused (per session, not saved)
	STRIKES_TO_DISABLE = 2,
	MIN_RESERVE = 0,
	MAX_RESERVE = 30,
	MIN_GAP_MS = 300,
	MAX_GAP_MS = 5000,
	defaults = {
		loot = true, -- take everything when a loot window opens
		stolenMode = "game", -- stolen items: "game" = the game's own loot settings decide (Loot.lua), "take" = always, "leave" = never
		boxes = false, -- open containers that arrive in the backpack by itself (off: the player opens them, Loot.lua empties the window)
		boxReserve = 4, -- do not open one while fewer backpack slots than this are free (a box may hold several items)
		boxGapMs = 800, -- wait this long between two boxes
		boxOnLogin = false, -- also open the boxes that are already in the backpack at login
		collect = true, -- bind set pieces that are not in the set collection, as they arrive
		collectTradeable = false, -- ... also the group drops that can still be traded (binding ends the trade window)
		collectOnLogin = false, -- also bind the ones already in the backpack at login
		skipLocked = true, -- never touch an item the player has locked
		messages = true, -- one summary line in the chat per batch
	},
}
local A = PBS_AUTO_LOOT
local S = PBS_AUTO_LOOT_STRINGS

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

-- Counters. Numbers only: this table never grows.
A.stats = {
	lootWindows = 0, -- EVENT_LOOT_UPDATED seen while the option was on
	lootCalls = 0, -- LootAll calls made
	lootGaveUp = 0, -- windows left alone because LootAll had already been tried the allowed number of times
	lootFailed = 0, -- LootAll refused or raised
	opened = 0, -- boxes that opened (the backpack changed after the call)
	openFailed = 0, -- boxes that did not
	openSkipped = 0, -- boxes passed over (locked, not usable, refused twice ...)
	bound = 0, -- set pieces that are now collected
	bindFailed = 0,
	bindSkipped = 0,
	collected = 0, -- EVENT_ITEM_SET_COLLECTION_UPDATED seen (the game's own word that a piece was added)
	queuedBoxes = 0,
	queuedBinds = 0,
	dropped = 0, -- slots not queued because a queue was full
	errors = 0,
	ticks = 0,
	peakQueue = 0,
}
A.lastError = nil -- the text of the last error (one string, overwritten)

-- ---------------------------------------------------------------------------------------
-- A queue of backpack slots
--
-- FIFO, no duplicates, bounded. `items` is an array that is read from `head` to `tail`; when it empties the two
-- indexes go back to the start, so the table does not creep along the integers for ever.
-- ---------------------------------------------------------------------------------------

local Queue = {}
Queue.__index = Queue
A.Queue = Queue

function Queue.New(limit)
	return setmetatable({ items = {}, set = {}, head = 1, tail = 0, limit = limit or 400 }, Queue)
end

function Queue:Count()
	return self.tail - self.head + 1
end

-- true when queued, false when it was already there, nil when the queue is full
function Queue:Push(value)
	if self.set[value] then
		return false
	end
	if self:Count() >= self.limit then
		return nil
	end
	self.set[value] = true
	self.tail = self.tail + 1
	self.items[self.tail] = value
	return true
end

function Queue:Pop()
	if self.head > self.tail then
		return nil
	end
	local value = self.items[self.head]
	self.items[self.head] = nil
	self.set[value] = nil
	self.head = self.head + 1
	if self.head > self.tail then
		self.head, self.tail = 1, 0
	end
	return value
end

function Queue:Clear()
	while self:Pop() ~= nil do
	end
end

-- ---------------------------------------------------------------------------------------
-- Saved variables
--
-- `pending` is written before a guarded game call and cleared when it returns. If the game shows the UI error
-- screen and the player reloads, the file still says "pending". That is a hint, not proof: the file is also
-- written on a normal logout, and a hard crash writes nothing at all. So a leftover marker is only a *strike*
-- against its group (`strikes`); the group is switched off (`probe[group] = "bad"`) after STRIKES_TO_DISABLE
-- strikes in a row, and any clean use clears the count. A console has no comfortable way to type /pbal retry,
-- so the settings panel has a button for it.
-- ---------------------------------------------------------------------------------------

-- ZO_SavedVars writes every default that is missing into the file (CopyDefaults rawsets it), so an old file holds the
-- old defaults as if they were choices. Two changes therefore need a migration, done once per file:
--   2: "boxes" became off by default (0.1.2). A file from 0.1.0 / 0.1.1 has it on; it is put back to the new default.
--   3: the two stolen-item switches (followGame, lootStolen) became one choice, stolenMode (0.1.3). It is worked out
--      from the old pair and the old keys are removed.
-- Nothing else is touched.
local SCHEMA = 3

A.STOLEN_MODES = { "game", "take", "leave" }
local STOLEN_MODE_SET = { game = true, take = true, leave = true }

-- The choice that the old pair of switches amounted to. followGame was added in 0.1.1; before it, lootStolen alone
-- decided (a file from 0.1.0 has no followGame: its lootStolen = true is a choice to take, anything else becomes
-- the new default, following the game).
local function StolenModeFrom(followGame, lootStolen)
	if followGame == false then
		return lootStolen == true and "take" or "leave"
	end
	if followGame == nil and lootStolen == true then
		return "take"
	end
	return "game"
end

local function Clamp(value, low, high)
	value = tonumber(value) or low
	return math.max(low, math.min(high, math.floor(value)))
end
A.Clamp = Clamp

function A:Sanitize()
	local sv = self.sv
	for key, default in pairs(self.defaults) do
		if type(sv[key]) ~= type(default) then
			sv[key] = default
		end
	end
	sv.boxReserve = Clamp(sv.boxReserve, self.MIN_RESERVE, self.MAX_RESERVE)
	sv.boxGapMs = Clamp(sv.boxGapMs, self.MIN_GAP_MS, self.MAX_GAP_MS)
	if not STOLEN_MODE_SET[sv.stolenMode] then
		sv.stolenMode = self.defaults.stolenMode
	end
	if type(sv.probe) ~= "table" then
		sv.probe = {}
	end
	if type(sv.strikes) ~= "table" then
		sv.strikes = {}
	end

	-- what this start-up found, for /pbal status
	local startup = { stale = nil }
	self.startup = startup

	if sv.schema ~= SCHEMA then
		if sv.schema == 1 or sv.schema == 2 then
			if sv.schema == 1 then
				sv.boxes = self.defaults.boxes
				startup.migrated = true
			end
			-- the old pair -> the one choice (read before the old keys are removed)
			local mode = StolenModeFrom(sv.followGame, sv.lootStolen)
			if sv.followGame ~= nil or sv.lootStolen ~= nil then
				sv.stolenMode = mode
				startup.stolenFrom = mode
			end
			sv.followGame, sv.lootStolen = nil, nil
		else
			sv.probe, sv.strikes, sv.pending = {}, {}, nil
		end
		sv.schema = SCHEMA
	end

	local pending = sv.pending
	sv.pending = nil
	if type(pending) == "string" then
		-- "ask" is the question about a function (IsPrivateFunction ...): if that is what was left over, asking is
		-- what to stop doing, and every group then runs without asking
		local group = pending
		local count = (tonumber(sv.strikes[group]) or 0) + 1
		sv.strikes[group] = count
		startup.stale = pending
		if count >= self.STRIKES_TO_DISABLE then
			sv.probe[group] = "bad"
		end
	end
end

-- Forget what was learned about the calls (the panel's retry button, /pbal retry).
function A:Retry()
	self.sv.probe, self.sv.strikes, self.sv.pending = {}, {}, nil
	self.routes = {}
	self.openFails, self.openFailN, self.openSkip = {}, 0, {}
	self.game.read = false
end

function A:Set(key, value)
	local default = self.defaults[key]
	if default == nil or type(value) ~= type(default) then
		return
	end
	if key == "stolenMode" and not STOLEN_MODE_SET[value] then
		return
	end
	if key == "boxReserve" then
		value = Clamp(value, self.MIN_RESERVE, self.MAX_RESERVE)
	elseif key == "boxGapMs" then
		value = Clamp(value, self.MIN_GAP_MS, self.MAX_GAP_MS)
	end
	self.sv[key] = value
	-- a switch that goes off empties its queue; one that goes on needs no help (the next arrival queues)
	if value == false then
		if key == "boxes" then
			self.boxQ:Clear()
		elseif key == "collect" then
			self.bindQ:Clear()
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- Asking the game whether a call may be made, and making it
-- ---------------------------------------------------------------------------------------

-- group -> the functions it needs. `secure` groups may be reached through CallSecureProtected when the game
-- says the function is protected.
A.GROUPS = {
	loot = { names = { "LootAll" }, secure = false },
	settings = { names = { "GetSetting" }, secure = false },
	open = { names = { "UseItem" }, secure = true },
	bind = { names = { "BindItem" }, secure = false },
}
A.routes = {}

-- Returns "direct", "secure", or nil and the reason.
function A:Route(group)
	local known = self.routes[group]
	if known then
		return known.route, known.why
	end
	local def = self.GROUPS[group]
	local state = { route = nil, why = nil, kinds = {}, asked = "" }
	self.routes[group] = state
	local sv = self.sv

	for _, name in ipairs(def.names) do
		if type(_G[name]) ~= "function" then
			state.why = string.format(S.whyMissing, name)
			return nil, state.why
		end
	end
	if sv.probe[group] == "bad" then
		state.why = S.whyEarlier
		return nil, state.why
	end

	local anyProtected = false
	if sv.probe.ask == "bad" then
		state.asked = "skipped: the question failed on an earlier login"
		-- not asking is not knowing: take the API dump's word (UseItem is protected)
		anyProtected = def.secure
	elseif type(IsPrivateFunction) == "function" and type(IsProtectedFunction) == "function" then
		local before = sv.pending
		sv.pending = "ask"
		local refused
		for _, name in ipairs(def.names) do
			local okPrivate, isPrivate = pcall(IsPrivateFunction, name)
			local okProtected, isProtected = pcall(IsProtectedFunction, name)
			if okPrivate and okProtected then
				state.kinds[name] = isPrivate and "private" or (isProtected and "protected" or "allowed")
				if isPrivate then
					refused = refused or name
				elseif isProtected then
					anyProtected = true
				end
			else
				-- a question that fails is not an answer: the same as not being able to ask
				state.kinds[name] = "question failed"
				anyProtected = anyProtected or def.secure
			end
		end
		sv.pending = before
		state.asked = refused and "refused" or "answered"
		if refused then
			state.why = string.format(S.whyPrivate, refused)
			return nil, state.why
		end
	else
		state.asked = "cannot ask"
		-- UseItem is protected in the API dump; without a way to ask, assume the dump is right
		anyProtected = def.secure
	end

	if anyProtected then
		if def.secure and type(CallSecureProtected) == "function" then
			state.route = "secure"
		else
			state.why = string.format(S.whyProtected, def.names[1])
			return nil, state.why
		end
	else
		state.route = "direct"
	end
	return state.route
end

-- Make a guarded call. Returns true when it ran and (for a secure call) the game accepted it, then the function's
-- first result; false and a reason otherwise. Nothing is created here but the call's own arguments.
function A:Call(group, name, ...)
	local route, why = self:Route(group)
	if not route then
		return false, why
	end
	local sv = self.sv
	local before = sv.pending
	sv.pending = group
	local ok, a, b
	if route == "secure" then
		ok, a, b = pcall(CallSecureProtected, name, ...)
		if ok and a ~= true then
			-- the game declined (no Lua error): not a strike, just not done
			sv.pending = before
			return false, S.whyDeclined
		end
	else
		ok, a, b = pcall(_G[name], ...)
	end
	sv.pending = before
	if ok then
		sv.probe[group] = "ok"
		sv.strikes[group] = nil
		if route == "secure" then
			return true, b
		end
		return true, a
	end
	self.stats.errors = self.stats.errors + 1
	self.lastError = tostring(a)
	return false, self.lastError
end

-- ---------------------------------------------------------------------------------------
-- Is this a moment to act?
--
-- Opening a box and binding both change the backpack, and both cause the client to refresh whatever it shows of
-- it. So they wait for the plain HUD: no menu up (a client screen that is being built while an add-on frame is on
-- the stack is how closures get tainted), no conversation, store or bank, no loot window, not in combat.
-- Returns true, or false and a short reason (a constant string: it is only for /pbal status).
-- ---------------------------------------------------------------------------------------

function A:Ready()
	if IsPlayerActivated and not IsPlayerActivated() then
		return false, "loading"
	end
	if IsUnitDeadOrReincarnating and IsUnitDeadOrReincarnating("player") then
		return false, "dead"
	end
	if IsUnitInCombat and IsUnitInCombat("player") then
		return false, "combat"
	end
	if IsLooting and IsLooting() then
		return false, "loot window"
	end
	if GetInteractionType and INTERACTION_NONE and GetInteractionType() ~= INTERACTION_NONE then
		return false, "interaction"
	end
	if SCENE_MANAGER and SCENE_MANAGER.IsShowingBaseScene and not SCENE_MANAGER:IsShowingBaseScene() then
		return false, "menu"
	end
	return true
end

-- Items that arrive while the player is at a bank were put there by the player, not found: leave them alone.
function A:AtStorage()
	if not GetInteractionType then
		return false
	end
	local kind = GetInteractionType()
	return (INTERACTION_BANK ~= nil and kind == INTERACTION_BANK) or (INTERACTION_GUILDBANK ~= nil and kind == INTERACTION_GUILDBANK)
end

-- ---------------------------------------------------------------------------------------
-- The timer
--
-- One RegisterForUpdate, present only while there is work. Tick() returns without work left -> it unregisters.
-- ---------------------------------------------------------------------------------------

local em = EVENT_MANAGER

local function TickHandler()
	A:Tick()
end

-- The longest the queues have been together (for /pbal status).
function A:NotePeak()
	local queued = self.boxQ:Count() + self.bindQ:Count()
	if queued > self.stats.peakQueue then
		self.stats.peakQueue = queued
	end
end

function A:Wake()
	if self.ticking or not self.sv then
		return
	end
	self.ticking = true
	em:RegisterForUpdate(self.name .. "Tick", self.TICK_MS, TickHandler)
end

function A:Sleep()
	if self.ticking then
		self.ticking = false
		em:UnregisterForUpdate(self.name .. "Tick")
	end
end

local function Note(self, err)
	self.stats.errors = self.stats.errors + 1
	self.lastError = tostring(err)
end

function A:Tick()
	local stats = self.stats
	stats.ticks = stats.ticks + 1
	local now = GetGameTimeMilliseconds()
	local busy = false
	-- each step in its own pcall: an error in one (a bug here, not a refused game call) must not stop the others, and
	-- must not reach the game as an error screen
	local ok, more = pcall(self.StepLogin, self, now)
	if ok then
		busy = busy or more
	else
		Note(self, more)
	end
	ok, more = pcall(self.StepBoxes, self, now)
	if ok then
		busy = busy or more
	else
		Note(self, more)
	end
	ok, more = pcall(self.StepBind, self, now)
	if ok then
		busy = busy or more
	else
		Note(self, more)
	end
	ok, more = pcall(self.StepFlush, self, now)
	if ok then
		busy = busy or more
	else
		Note(self, more)
	end
	-- a run of errors is a bug that would otherwise repeat four times a second for ever
	if stats.errors > 200 then
		self.boxQ:Clear()
		self.bindQ:Clear()
		busy = false
	end
	if not busy then
		self:Sleep()
	end
end

A.game = { read = false, stolen = nil, prevent = nil } -- the game's loot settings, as last read (Loot.lua)
A.boxQ = Queue.New(A.MAX_QUEUE)
A.bindQ = Queue.New(A.MAX_QUEUE)
A.openFails, A.openFailN, A.openSkip = {}, 0, {}

PBS_AL_MARK("Core")
