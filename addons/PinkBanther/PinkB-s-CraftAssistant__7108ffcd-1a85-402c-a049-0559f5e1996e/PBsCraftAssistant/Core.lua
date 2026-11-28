-- PB's Craft Assistant
-- Author: PinkBanther
--
-- Daily crafting writs, hands off:
--   Dialog.lua   takes the writs at a writ board and hands the goods in at a delivery crate (the conversation is
--                driven with the game's own chatter calls; the quest is completed only after our own hand-in)
--   Craft.lua    crafts what the writs ask for as soon as the right station is opened, one call per writ line
--                (multi-craft), choosing style stones for the smithing crafts
--   Bank.lua     takes out of the bank what the writs still need: finished items that fulfil a line, and the
--                materials, runes, reagents and ingredients for the lines still to be crafted
--   Rewards.lua  opens the reward boxes that arrive when a writ is completed, and empties their loot window
--
-- ---------------------------------------------------------------------------------------
-- FAST AND LIGHT
-- ---------------------------------------------------------------------------------------
--
-- * Nothing runs per frame. Everything starts from a game event (a conversation, a station, the bank, an item that
--   arrives) and the only timer is a one-shot that exists while a job is waiting for its next step.
-- * What a writ asks for is read from the game itself (GetQuestConditionItemInfo + the helpers the game's own
--   "craft advisor" uses: GetSmithingPatternInfoForItemId, GetRunesForItemIdIfKnown, GetTraitIdFromBasePotion,
--   GetRecipeInfoFromItemId). No quest text is parsed, so it works in every client language and needs no tables of
--   item names. Only the two conversation steps need a word of the game's text (Dialog.lua).
-- * No library is needed; LibHarvensAddonSettings is used for the settings panel when it is installed.
--
-- ---------------------------------------------------------------------------------------
-- WHAT THE ADD-ON MAY CALL (ESOUIDocumentation.txt API 101051; nothing here measured on a PS5 yet)
-- ---------------------------------------------------------------------------------------
--
--   Craft*Item, SelectChatterOption, AcceptOfferedQuest, CompleteQuest, EndInteraction, LootAll   no marker
--   RequestMoveItem, UseItem                                                                       *protected*
--
-- A protected function is reached through CallSecureProtected(name, ...), called directly from Lua code with no
-- pcall on the stack (PS5, 0.1.4: through pcall it fails with a nil error). The two protected groups go through
-- Call(): the game is asked first (IsProtectedFunction), and `pending` is written to the saved variables before the
-- call and cleared after it. A marker still there at the next login is a strike; two strikes switch that group off until
-- the player presses "Try again" (the PBsAutoLoot pattern).

PBS_CRAFT_ASSIST = {
	name = "PBsCraftAssistant",
	baseTitle = "PB’s Craft Assistant",
	chatName = "PB’s Craft Assistant",
	author = "PinkBanther",
	version = "0.1.6",
	slash = "/pbcraftassist",
	shortSlash = "/pbwrit",
	savedVar = "PBsCraftAssistant_Data",

	START_DELAY_MS = 150, -- after a station opens, before the first craft (the client is still showing its screen)
	CHAIN_MS = 80, -- after one craft completes, before the next one is started
	BUSY_RETRY_MS = 250, -- the game is still busy with a craft: look again this much later
	RECHECK_MS = 700, -- after the last job, read the writs again (the counters move a little after the craft)
	MAX_ROUNDS = 3, -- rounds of "read the writs, craft what is missing" per station visit
	MOVE_GAP_MS = 120, -- between two bank moves
	MOVE_LIMIT = 60, -- bank moves per visit (a bound, not an expected number)
	OFFER_MS = 4000, -- a writ offer must arrive this soon after we picked the board's option
	DELIVER_MS = 6000, -- the completion dialog must arrive this soon after we picked the crate's option
	REWARD_WINDOW_MS = 10000, -- a box that arrives this soon after a writ is completed is a writ reward
	BOX_BEFORE_MS = 3000, -- ... or this soon before the completion event (the order of the two is not known)
	OPEN_CHECK_MS = 3000, -- a box that was used must open a loot window this soon, or it counts as refused
	OPEN_GAP_MS = 500, -- between two boxes
	MAX_BOX_IDS = 64, -- learned reward-box item ids kept
	SMITH_MAT_PER_ITEM = 15, -- bank: raw material taken out per smithing item still to make (the station is not open,
	-- so the exact amount of the pattern cannot be read there; 15 covers every daily writ pattern)
	STRIKES_TO_DISABLE = 2,
	MIN_RESERVE = 1, -- a box needs at least one free slot
	MAX_RESERVE = 30,

	defaults = {
		autoAccept = true, -- take the writs at a writ board
		closeBoard = true, -- ... and leave the board when there is nothing more to take
		autoDeliver = true, -- hand the goods in at the delivery crate and complete the writ
		autoCraft = true, -- craft at the station
		autoExit = false, -- leave the station when everything is crafted
		bs = true, -- blacksmithing
		cl = true, -- clothing
		ww = true, -- woodworking
		jw = true, -- jewelry
		en = true, -- enchanting
		al = true, -- alchemy
		pr = true, -- provisioning
		styleScope = "basic", -- "basic": the ten racial base styles only; "all": any style the character knows
		bank = true, -- take finished writ items out of the bank
		bankMaterials = true, -- ... and the materials for the lines still to be crafted
		boxes = true, -- open writ reward boxes
		boxReserve = 1, -- do not open one while fewer backpack slots are free (1 = what Lazy Writ Crafter asks; 0.1.0-0.1.3: 4)
		boxOnLogin = false, -- also open learned reward boxes already in the backpack at login
		messages = false, -- one line in the chat per finished step (off: PB asked for no chat output, 0.1.2)
		panel = true, -- show the crafting panel while a station is open
		panelPos = "topright", -- "topright" | "top" | "topleft"
	},
}
local A = PBS_CRAFT_ASSIST
local S = PBS_CRAFT_ASSIST_STRINGS

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

-- The ten racial base styles (Breton ... Khajiit, Imperial). The ITEMSTYLE_ names are PC-only aliases, so numbers.
A.BASIC_STYLES = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 34 }
A.STYLE_SCOPES = { "basic", "all" }

-- craft type -> option key (built at start-up: the CRAFTING_TYPE_ constants are there by then)
A.CRAFT_KEYS = {}
A.CRAFT_ORDER = { "bs", "cl", "ww", "jw", "en", "al", "pr" }
function A:BuildCraftKeys()
	local k = self.CRAFT_KEYS
	if CRAFTING_TYPE_BLACKSMITHING then
		k[CRAFTING_TYPE_BLACKSMITHING] = "bs"
		k[CRAFTING_TYPE_CLOTHIER] = "cl"
		k[CRAFTING_TYPE_WOODWORKING] = "ww"
		k[CRAFTING_TYPE_JEWELRYCRAFTING] = "jw"
		k[CRAFTING_TYPE_ENCHANTING] = "en"
		k[CRAFTING_TYPE_ALCHEMY] = "al"
		k[CRAFTING_TYPE_PROVISIONING] = "pr"
	end
end

function A:CraftEnabled(craftType)
	local key = self.CRAFT_KEYS[craftType]
	return key ~= nil and self.sv[key] == true
end

-- A writ line we may act on: its craft is switched on. An "acquire" line whose craft the game does not name (not
-- measured: the game may leave it 0) is taken as on -- taking an item out for it cannot do harm.
function A:LineEnabled(rec)
	if rec.kind == "gather" and self.CRAFT_KEYS[rec.craftType] == nil then
		return true
	end
	return self:CraftEnabled(rec.craftType)
end

-- Counters (numbers only; this table never grows).
A.stats = {
	accepted = 0, delivered = 0, completed = 0,
	crafted = 0, craftCalls = 0, craftFailed = 0,
	moved = 0, moveFailed = 0,
	opened = 0, openFailed = 0, looted = 0,
	errors = 0,
}
A.lastError = nil

local function Clamp(value, low, high)
	value = tonumber(value) or low
	return math.max(low, math.min(high, math.floor(value)))
end
A.Clamp = Clamp

-- ---------------------------------------------------------------------------------------
-- Saved variables
-- ---------------------------------------------------------------------------------------

-- 2 (0.1.2): "messages" became off by default. ZO_SavedVars writes every default into the file, so a file from
-- 0.1.0 / 0.1.1 holds messages = true as if chosen: it is put back to off once, nothing else is touched.
-- 3 (0.1.4): "boxReserve" default 4 -> 1 (a near-full writ-day backpack kept every box shut, and since 0.1.2 the
-- warning no longer reached the chat). A file holding the old default 4 gets the new one; any other value was chosen.
local SCHEMA = 3
local SCOPES = { basic = true, all = true }
local POSITIONS = { topright = true, top = true, topleft = true }

function A:Sanitize()
	local sv = self.sv
	for key, default in pairs(self.defaults) do
		if type(sv[key]) ~= type(default) then
			sv[key] = default
		end
	end
	sv.boxReserve = Clamp(sv.boxReserve, self.MIN_RESERVE, self.MAX_RESERVE)
	if not SCOPES[sv.styleScope] then
		sv.styleScope = self.defaults.styleScope
	end
	if not POSITIONS[sv.panelPos] then
		sv.panelPos = self.defaults.panelPos
	end
	if type(sv.probe) ~= "table" then
		sv.probe = {}
	end
	if type(sv.strikes) ~= "table" then
		sv.strikes = {}
	end
	if type(sv.boxIds) ~= "table" then
		sv.boxIds = {}
	end
	if type(sv.totals) ~= "table" then
		sv.totals = {}
	end
	sv.totals.writs = tonumber(sv.totals.writs) or 0
	sv.totals.crafted = tonumber(sv.totals.crafted) or 0

	local startup = {}
	self.startup = startup
	if sv.schema ~= SCHEMA then
		if sv.schema == 1 or sv.schema == 2 then
			if sv.schema == 1 then
				sv.messages = false
			end
			if sv.boxReserve == 4 then
				sv.boxReserve = self.defaults.boxReserve
			end
			startup.migrated = true
		else
			sv.probe, sv.strikes, sv.pending = {}, {}, nil
		end
		sv.schema = SCHEMA
	end
	local pending = sv.pending
	sv.pending = nil
	if type(pending) == "string" then
		local count = (tonumber(sv.strikes[pending]) or 0) + 1
		sv.strikes[pending] = count
		startup.stale = pending
		if count >= self.STRIKES_TO_DISABLE then
			sv.probe[pending] = "bad"
		end
	end
	-- the learned box ids stay bounded
	local n = 0
	for id in pairs(sv.boxIds) do
		n = n + 1
		if type(id) ~= "number" or n > self.MAX_BOX_IDS then
			sv.boxIds[id] = nil
		end
	end
end

function A:Set(key, value)
	local default = self.defaults[key]
	if default == nil or type(value) ~= type(default) then
		return
	end
	if key == "styleScope" and not SCOPES[value] then
		return
	end
	if key == "panelPos" and not POSITIONS[value] then
		return
	end
	if key == "boxReserve" then
		value = Clamp(value, self.MIN_RESERVE, self.MAX_RESERVE)
	end
	self.sv[key] = value
	if key == "panelPos" and self.PlacePanel then
		self:PlacePanel()
	elseif key == "panel" and value == false and self.PanelHide then
		self:PanelHide()
	end
end

function A:Retry()
	self.sv.probe, self.sv.strikes, self.sv.pending = {}, {}, nil
	self.routes = {}
end

-- ---------------------------------------------------------------------------------------
-- Asking the game whether a call may be made, and making it
-- ---------------------------------------------------------------------------------------

A.GROUPS = {
	move = { names = { "RequestMoveItem" }, secure = true },
	open = { names = { "UseItem" }, secure = true },
}
A.routes = {}

-- "direct", "secure", or nil and the reason.
function A:Route(group)
	local known = self.routes[group]
	if known then
		return known.route, known.why
	end
	local def = self.GROUPS[group]
	local state = { route = nil, why = nil, asked = "" }
	self.routes[group] = state
	local sv = self.sv
	local name = def.names[1]
	if type(_G[name]) ~= "function" and type(CallSecureProtected) ~= "function" then
		state.why = string.format(S.whyMissing, name)
		return nil, state.why
	end
	if sv.probe[group] == "bad" then
		state.why = S.whyEarlier
		return nil, state.why
	end
	-- Only IsProtectedFunction decides, as in Lazy Writ Crafter (which opens writ boxes and takes items out of the bank
	-- on consoles this way): protected -> CallSecureProtected, else a plain call. 0.1.0-0.1.3 also let an
	-- IsPrivateFunction answer of true stop the call; that answer is now only recorded for /pbwrit.
	local protected = def.secure
	if sv.probe.ask ~= "bad" and type(IsProtectedFunction) == "function" then
		local before = sv.pending
		sv.pending = "ask"
		local okProtected, isProtected = pcall(IsProtectedFunction, name)
		local okPrivate, isPrivate = false, nil
		if type(IsPrivateFunction) == "function" then
			okPrivate, isPrivate = pcall(IsPrivateFunction, name)
		end
		sv.pending = before
		if okProtected then
			protected = isProtected and true or false
			state.asked = (protected and "protected" or "not protected") .. (okPrivate and isPrivate and ", private: true" or "")
		else
			state.asked = "question failed"
		end
	else
		state.asked = "not asked"
	end
	if protected then
		if type(CallSecureProtected) == "function" then
			state.route = "secure"
		else
			state.why = string.format(S.whyProtected, name)
			return nil, state.why
		end
	else
		state.route = "direct"
	end
	return state.route
end

-- A guarded call: true and the function's first result, or false and a reason.
function A:Call(group, name, ...)
	local route, why = self:Route(group)
	if not route then
		return false, why
	end
	local sv = self.sv
	local before = sv.pending
	sv.pending = group
	if route == "secure" then
		-- CallSecureProtected is called straight from this Lua function, never through pcall, and Call is only reached
		-- from a "bare" timer (Later: box, move), so no pcall is anywhere on the stack -- exactly as Lazy Writ Crafter
		-- calls it. 0.1.0-0.1.4 wrote pcall(CallSecureProtected, ...): on a PS5 that failed every time with an
		-- empty (nil) error ("報酬の箱を開けられませんでした：NIL"), so no box was opened and nothing left the bank.
		-- An error raised here goes to the game's error screen and leaves `pending` set: the strike guard below.
		local success, result = CallSecureProtected(name, ...)
		sv.pending = before
		if success ~= true then
			return false, S.whyDeclined
		end
		sv.probe[group] = "ok"
		sv.strikes[group] = nil
		return true, result
	end
	local ok, a = pcall(_G[name], ...)
	sv.pending = before
	if ok then
		sv.probe[group] = "ok"
		sv.strikes[group] = nil
		return true, a
	end
	self:NoteError(a)
	return false, self.lastError
end

-- A plain game call that has no marker, under pcall (an error is counted, never shown as an error screen).
function A:Try(fn, ...)
	if type(fn) ~= "function" then
		return false, "missing"
	end
	local ok, a, b, c = pcall(fn, ...)
	if not ok then
		self:NoteError(a)
		return false, a
	end
	return true, a, b, c
end

function A:NoteError(err)
	self.stats.errors = self.stats.errors + 1
	self.lastError = tostring(err)
end

-- ---------------------------------------------------------------------------------------
-- One-shot timers without a closure per call: each key gets one handler, created the first time it is used.
-- ---------------------------------------------------------------------------------------

local em = EVENT_MANAGER
A.timerFns = {}
A.timerOn = {}

function A:Later(key, ms, method)
	local fn = self.timerFns[key]
	if not fn then
		local name = self.name .. "_" .. key
		local bare = A.BARE_TIMERS[key]
		fn = function()
			em:UnregisterForUpdate(name)
			A.timerOn[key] = nil
			local m = A[A.timerMethod[key]]
			if m then
				if bare then
					-- the steps that make a CallSecureProtected call run without pcall (see A:Call)
					m(A)
				else
					local ok, err = pcall(m, A)
					if not ok then
						A:NoteError(err)
					end
				end
			end
		end
		self.timerFns[key] = fn
	end
	self.timerMethod[key] = method
	local name = self.name .. "_" .. key
	if self.timerOn[key] then
		em:UnregisterForUpdate(name)
	end
	self.timerOn[key] = true
	em:RegisterForUpdate(name, ms, fn)
end
A.timerMethod = {}
-- timers whose step may call CallSecureProtected (box: UseItem, move: RequestMoveItem)
A.BARE_TIMERS = { box = true, move = true }

function A:Cancel(key)
	if self.timerOn[key] then
		self.timerOn[key] = nil
		em:UnregisterForUpdate(self.name .. "_" .. key)
	end
end

-- ---------------------------------------------------------------------------------------
-- Bags
-- ---------------------------------------------------------------------------------------

-- The next slot of a bag after `slot` (nil = the first), or nil at the end. The craft bag has its own iterator.
function A.NextSlot(bag, slot)
	if bag == BAG_VIRTUAL then
		return GetNextVirtualBagSlotId(slot)
	end
	if slot == nil then
		return 0
	end
	local size = GetBagSize(bag) or 0
	if slot < size - 1 then
		return slot + 1
	end
	return nil
end

-- The bags crafting reads from: the backpack, and the craft bag when the player has it.
A.CRAFT_BAGS = {}
function A:CraftBags()
	local bags = self.CRAFT_BAGS
	bags[1] = BAG_BACKPACK
	bags[2] = (HasCraftBagAccess and HasCraftBagAccess() and BAG_VIRTUAL) or nil
	return bags
end

-- How many of an item the backpack and the craft bag hold together.
function A:CountOwned(itemId)
	local total = 0
	local bags = self:CraftBags()
	for i = 1, 2 do
		local bag = bags[i]
		if bag then
			local slot = A.NextSlot(bag, nil)
			while slot do
				if GetItemId(bag, slot) == itemId then
					total = total + (GetSlotStackSize(bag, slot) or 0)
				end
				slot = A.NextSlot(bag, slot)
			end
		end
	end
	return total
end

-- The slot holding the most of an item in the backpack or the craft bag: bag, slot, count (nil when there is none).
function A:FindItem(itemId)
	local bestBag, bestSlot, bestCount = nil, nil, 0
	local bags = self:CraftBags()
	for i = 1, 2 do
		local bag = bags[i]
		if bag then
			local slot = A.NextSlot(bag, nil)
			while slot do
				if GetItemId(bag, slot) == itemId then
					local count = GetSlotStackSize(bag, slot) or 0
					if count > bestCount then
						bestBag, bestSlot, bestCount = bag, slot, count
					end
				end
				slot = A.NextSlot(bag, slot)
			end
		end
	end
	return bestBag, bestSlot, bestCount
end

PBS_CA_MARK("Core")
