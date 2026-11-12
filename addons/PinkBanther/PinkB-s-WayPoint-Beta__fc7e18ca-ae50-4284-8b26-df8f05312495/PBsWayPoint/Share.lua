-- Sharing the route with the group (LibGroupBroadcast).
--
-- When a member of the group marks a destination, takes a stop away, or resets the waypoints, the route as it then is
-- (the stops still to come, the destination, how many stops were reached) is sent to the group; every member who runs
-- this add-on takes it over as their own route, so the guide and the numbered pins on the map are the same for the whole
-- party. Nothing is sent for walking the route (reaching a stop, skipping one): that is each player's own progress.
-- The game's own destination pin is never written: the member who sets it sees it, and the others see this add-on's
-- numbered pin on the destination (the route's `destOwn`, see Pins.lua).
--
-- THE LIBRARY (read from its source, github.com/sirinsidiator/ESO-LibGroupBroadcast, not guessed):
--   * a numeric field is 2 to 32 bits wide: 1 bit is refused, the protocol then fails to finalize and NOTHING is sent or
--     heard (0.5.0 had a one-bit field, and so never worked);
--   * the game broadcasts 8 integers (a frame of 30 bytes, 2 of them a header per message) at a time, with a cooldown between
--     frames and a delay of 0.5 s before the first send after a quiet spell; the library packs messages into frames and
--     splits what does not fit. A frame the game refuses is dropped ("TODO handle failures" in its source): delivery is
--     best effort, so this file sends a route again after a while and lets a member ask for it;
--   * the protocol id is 9 bits (0 .. 511), one number per add-on across everything a player has installed; PB's block is
--     460-469 (460 Tetris, 461 Janken, 462 Translate, 463 War Table, 464 Emote Synchronizer) and this is 465.
-- The library is optional: without it the add-on works as before and /pbwp status says so. Numeric fields only, a version in
-- two bits and a kind in three: the shape PB's Janken, War Table and Emote Synchronizer use on a console.
--
--   ROUTE   up to three points of a route: rev, total (points in the route), start (the number of the first point here),
--           n (points in this message), done (stops reached so far), dest (1 when the last point is the destination),
--           and for each point a map id and a place on it (m1 x1 y1 .. m3 x3 y3; the place is 0 .. 65535 of the map's
--           width and height). A message is 28 bytes with its header: one frame; a route of up to three points is one message.
--   CLEAR   the route is empty
--   REQUEST "send me the route": a member who has just logged in or joined, or whose route came in with parts missing
--
-- `rev` is a number that only grows: the time (GetTimeStamp) or one more than the last one seen, whichever is larger, so a
-- player who just logged in is not outvoted by a counter that started again at 0. A route is taken over when all its
-- points have come, and only if its rev is newer than the one taken over before (the same rev from two players: the name
-- that sorts later wins, the same on every client). What was taken over is not sent again: only the player who made the
-- route sends it, and sends it again with the same rev (whoever has it ignores it) a few seconds later, when somebody joins
-- the group, and when somebody asks.
local A, S = PBS_WAYPOINT, PBS_WAYPOINT_STRINGS
local em = EVENT_MANAGER

local T = {
	ID = 465,
	NAME = "PBsWayPointV1",
	VERSION = 1,
	ROUTE = 1,
	CLEAR = 2,
	REQUEST = 3,
}
A.ShareProtocol = T

local PER_MESSAGE = 3
local MAX_POINTS = 13 -- 12 stops and the destination
local COORD = 65535 -- a point on a map is sent as 0 .. 65535 of the map's width and height
local MAX_MAP_ID = 65535
local SEND_DELAY_MS = 1000 -- after the last change: a few quick changes are one message set
local REPEAT_MS = { 6000, 12000 } -- a route is sent again after this long, and again after this long after that (nothing changed)
local JOIN_DELAY_MS = 4000 -- after somebody joins: the newcomer's add-on needs a moment
local REPLY_DELAY_MS = 1500 -- after somebody asks
local REPLY_MIN_MS = 10000 -- the route is sent again for a newcomer or an asker at most this often
local ASK_DELAY_MS = 6000 -- after logging in or joining a group: ask for the route
local ASK_MIN_MS = 20000 -- ... at most this often
local MISSING_MS = 8000 -- a route that is still not whole this long after its first part: ask again
local ASSEMBLE_MS = 30000 -- a route that did not come in full in this time is dropped

-- name, bits (each 2 .. 32)
local FIELDS = {
	{ "version", 2 }, { "kind", 3 }, { "rev", 32 }, { "total", 4 }, { "start", 4 }, { "n", 2 }, { "done", 8 }, { "dest", 2 },
}
for slot = 1, PER_MESSAGE do
	FIELDS[#FIELDS + 1] = { "m" .. slot, 16 }
	FIELDS[#FIELDS + 1] = { "x" .. slot, 16 }
	FIELDS[#FIELDS + 1] = { "y" .. slot, 16 }
end
A.ShareFields = FIELDS

A.share = {
	ready = false,
	why = "not set up yet",
	sent = 0, -- messages handed to the library
	heard = 0, -- messages from others
	adopted = 0, -- routes taken over
	ignored = 0, -- messages or routes not used (older, switched off, damaged ...)
	mismatched = 0, -- from another version of the protocol
	asked = 0, -- times this player asked for the route
	asks = 0, -- times others asked
	rev = 0, -- the rev of the route as it is now
	revOwner = nil, -- who made it
	ownRev = false, -- this player made it (so this player sends it)
	lastFrom = nil, -- the last player a route was taken over from
	lastWhy = nil, -- the last reason something was not sent or not used
	partial = {}, -- sender -> a route that is still coming in
	protocol = nil,
}

local function Now()
	return GetGameTimeMilliseconds()
end

local function Own()
	local name = GetDisplayName and GetDisplayName() or nil
	if type(name) ~= "string" or name == "" then
		return nil
	end
	return name
end

local function Grouped()
	return GetGroupSize and GetGroupSize() > 1
end

local function Number(v)
	return type(v) == "number" and v == v
end

-- ---------------------------------------------------------------------------------------
-- The library
-- ---------------------------------------------------------------------------------------

function A:SetupShare()
	local share = self.share
	if share.ready then
		return true
	end
	if not LibGroupBroadcast then
		share.why = "LibGroupBroadcast is not installed"
		return false
	end
	local stage = "registerHandler"
	local ok, err = pcall(function()
		local handler = assert(LibGroupBroadcast:RegisterHandler(self.name), "Handler registration returned nil")
		handler:SetDisplayName(self.title)
		handler:SetDescription("Shares the stops and the destination you mark with your group.")
		stage = "declareProtocol"
		local protocol = handler:DeclareProtocol(T.ID, T.NAME)
		share.protocol = protocol
		protocol:SetDisplayName(self.title)
		stage = "createFields"
		for _, field in ipairs(FIELDS) do
			protocol:AddField(LibGroupBroadcast.CreateNumericField(field[1], { numBits = field[2] }))
		end
		stage = "registerReceiver"
		protocol:OnData(function(unitTag, data)
			-- (a failure in here must not reach the library's own code)
			local fine, why = pcall(self.ShareHear, self, unitTag, data)
			if not fine then
				share.ignored = share.ignored + 1
				share.lastWhy = "an error while reading a message: " .. tostring(why)
				self.diag.lastError = share.lastWhy
				self.diag.errors = self.diag.errors + 1
			end
		end)
		stage = "finalizeProtocol"
		-- (a field the library does not like makes this return false: its warnings go to LibDebugLogger)
		assert(protocol:Finalize({ isRelevantInCombat = false, replaceQueuedMessages = false }),
			"Protocol validation failed (a field the library refuses: see its log)")
	end)
	if not ok then
		share.protocol = nil
		-- DeclareProtocol only raises when the id or the name is already taken: the library's own message names who has it
		local first = tostring(err):match("^[^\n]*") or tostring(err)
		local detail = "[" .. stage .. "] " .. first:gsub("^.*[/\\]", "")
		if first:find("already exists", 1, true) then
			share.why = string.format("the protocol id %d is taken by another add-on: %s", T.ID, detail)
		else
			share.why = "setting up failed: " .. detail
		end
		-- the one place a player can read it afterwards (the chat is quiet): /pbwp why
		self:Trace("share", "group sharing is not available: " .. share.why)
		return false
	end
	share.ready = true
	share.why = "ready"
	return true
end

-- Registers for the group's comings and goings; called once at start-up.
function A:StartShare()
	self:SetupShare()
	em:RegisterForEvent(self.name .. "Join", EVENT_GROUP_MEMBER_JOINED, function(_, _, _, isLocalPlayer)
		if isLocalPlayer then
			self:ShareAskSoon(ASK_DELAY_MS, "this player joined a group")
		else
			self:ShareResendSoon(JOIN_DELAY_MS, "a member joined", false)
		end
	end)
end

-- Called once per login, when the player is in the world: a member who logs in (or reloads) into a group asks for the route.
function A:ShareLogin()
	if self.shareLoginDone then
		return
	end
	self.shareLoginDone = true
	self:ShareAskSoon(ASK_DELAY_MS, "this player logged in")
end

-- ---------------------------------------------------------------------------------------
-- Sending
-- ---------------------------------------------------------------------------------------

-- The route as points: { done, hasDest, points = { { mapId, nx, ny } ... } }. The stops still to come, then the destination.
function A:ExportRoute()
	local route = self.route
	local points = {}
	for _, stop in ipairs(route.vias) do
		points[#points + 1] = { mapId = stop.mapId, nx = stop.nx, ny = stop.ny }
	end
	local dest = route.dest
	if dest then
		points[#points + 1] = { mapId = dest.mapId, nx = dest.nx, ny = dest.ny }
	end
	return { done = route.done, hasDest = dest ~= nil, points = points }
end

local function Fixed(value)
	return math.max(0, math.min(COORD, math.floor(value * COORD + 0.5)))
end

-- Every field there is, at zero, for a message of this kind.
local function Blank(kind, rev)
	local message = { version = T.VERSION, kind = kind, rev = rev, total = 0, start = 0, n = 0, done = 0, dest = 0 }
	for slot = 1, PER_MESSAGE do
		message["m" .. slot], message["x" .. slot], message["y" .. slot] = 0, 0, 0
	end
	return message
end

-- The messages of a route: a list of field tables, or nil and a reason.
function A.ShareMessages(snapshot, rev)
	local count = #snapshot.points
	if count == 0 then
		return { Blank(T.CLEAR, rev) }
	end
	if count > MAX_POINTS then
		return nil, "a route of more than " .. MAX_POINTS .. " points"
	end
	local done = math.max(0, math.min(255, math.floor(snapshot.done or 0)))
	local messages = {}
	for start = 1, count, PER_MESSAGE do
		local message = Blank(T.ROUTE, rev)
		message.total, message.start, message.done = count, start, done
		message.dest = snapshot.hasDest and 1 or 0
		message.n = math.min(PER_MESSAGE, count - start + 1)
		for slot = 1, message.n do
			local point = snapshot.points[start + slot - 1]
			local mapId = math.floor(point.mapId or 0)
			if mapId < 1 or mapId > MAX_MAP_ID then
				return nil, "a map id the protocol cannot carry (" .. tostring(point.mapId) .. ")"
			end
			message["m" .. slot], message["x" .. slot], message["y" .. slot] = mapId, Fixed(point.nx), Fixed(point.ny)
		end
		messages[#messages + 1] = message
	end
	return messages
end

-- A change of the route that the group should have (called where the player edits it): sent after a short quiet.
function A:ShareRoute(reason)
	local share = self.share
	if not (self.sv and self.sv.shareSend) then
		return
	end
	if not share.ready then
		return
	end
	share.pendingReason = reason
	em:UnregisterForUpdate(self.name .. "ShareRepeat") -- the old route is about to be replaced: its repeats are over
	em:UnregisterForUpdate(self.name .. "Share")
	em:RegisterForUpdate(self.name .. "Share", SEND_DELAY_MS, function()
		em:UnregisterForUpdate(self.name .. "Share")
		self:ShareSendNow(false)
	end)
end

-- After a send: the same route again a little later, and again (nothing changed, same rev: whoever has it ignores it). The
-- game drops a frame it refuses and the library does not send it again, so a member who missed one has another chance.
function A:ShareScheduleRepeats()
	local share = self.share
	local rev = share.rev
	local step = 0
	local function arm()
		step = step + 1
		local delay = REPEAT_MS[step]
		if not delay then
			return
		end
		em:UnregisterForUpdate(self.name .. "ShareRepeat")
		em:RegisterForUpdate(self.name .. "ShareRepeat", delay, function()
			em:UnregisterForUpdate(self.name .. "ShareRepeat")
			-- only while it is still this route and still ours
			if share.ownRev and share.rev == rev and self.sv.shareSend then
				self:ShareSendNow(true, "again, in case a message was lost")
				arm()
			end
		end)
	end
	arm()
end

-- Sends the route now. `again`: the route as it is, with the rev it already has. Returns true, or false and a reason.
function A:ShareSendNow(again, why)
	local share = self.share
	local function fail(reason)
		share.lastWhy = reason
		return false, reason
	end
	if not share.ready or not share.protocol then
		return fail(share.why)
	end
	if not Grouped() then
		return fail("you are not in a group")
	end
	if not share.protocol:IsEnabled() then
		return fail("the protocol is switched off in LibGroupBroadcast's settings")
	end
	if not again then
		em:UnregisterForUpdate(self.name .. "Share") -- this is that send (arming the repeats below replaces the old route's)
	end
	local rev, messages
	if again then
		-- what was sent, as it was sent: the route as it was marked, not as this player has walked it since
		rev, messages = share.rev, share.lastMessages
		if rev == 0 or not share.ownRev or not messages then
			return fail("this route is not yours to send")
		end
	else
		local stamp = GetTimeStamp and tonumber(GetTimeStamp()) or 0
		rev = math.max(share.rev + 1, math.floor(stamp))
		local reason
		messages, reason = A.ShareMessages(self:ExportRoute(), rev)
		if not messages then
			return fail(reason)
		end
	end
	for i, message in ipairs(messages) do
		-- the first message takes the place of any older route still waiting in the library's queue
		local accepted = share.protocol:Send(message, { replaceQueuedMessages = i == 1 })
		if accepted ~= true then
			return fail("the library refused a message (you may not be in a group, or its queue is full)")
		end
		share.sent = share.sent + 1
	end
	share.rev, share.revOwner, share.ownRev = rev, Own(), true
	share.lastMessages = messages
	share.lastWhy = nil
	self:Trace("share", string.format("sent the route to the group: %s (%d message%s)", again and tostring(why or "again") or tostring(share.pendingReason or "changed"),
		#messages, #messages == 1 and "" or "s"))
	if not again then
		self:ShareScheduleRepeats()
	end
	return true
end

-- The player who made the route sends it again soon: for a member who joined (`allowEmpty` false: nothing to say to a
-- newcomer about an empty route) or who asked (a stale route on their side is cleared by hearing that there is none).
function A:ShareResendSoon(delay, why, allowEmpty)
	local share = self.share
	if not (self.sv and self.sv.shareSend) or not share.ready then
		return
	end
	em:UnregisterForUpdate(self.name .. "ShareReply")
	em:RegisterForUpdate(self.name .. "ShareReply", delay, function()
		em:UnregisterForUpdate(self.name .. "ShareReply")
		local now = Now()
		if share.lastReplyAt and now - share.lastReplyAt < REPLY_MIN_MS then
			return
		end
		-- nothing to say to a newcomer about a route that was cleared
		if not allowEmpty and (not share.lastMessages or share.lastMessages[1].kind == T.CLEAR) then
			return
		end
		if self:ShareSendNow(true, why) then -- (it sends only a route that is this player's own)
			share.lastReplyAt = now
		end
	end)
end

-- ---------------------------------------------------------------------------------------
-- Asking
-- ---------------------------------------------------------------------------------------

-- "Send me the route": a short message, at most every ASK_MIN_MS. Returns true, or false and a reason.
function A:ShareAsk(why)
	local share = self.share
	if not (self.sv and self.sv.shareReceive) or not share.ready or not share.protocol then
		return false, "not receiving"
	end
	if not Grouped() or not share.protocol:IsEnabled() then
		return false, "no group, or the protocol is off"
	end
	local now = Now()
	if share.lastAskAt and now - share.lastAskAt < ASK_MIN_MS then
		return false, "asked a moment ago"
	end
	if share.protocol:Send(Blank(T.REQUEST, 0), { replaceQueuedMessages = false }) ~= true then
		return false, "the library refused the message"
	end
	share.lastAskAt = now
	share.asked = share.asked + 1
	share.sent = share.sent + 1
	self:Trace("share", "asked the group for the route: " .. tostring(why))
	return true
end

function A:ShareAskSoon(delay, why)
	local share = self.share
	if not (self.sv and self.sv.shareReceive) or not share.ready then
		return
	end
	em:UnregisterForUpdate(self.name .. "ShareAsk")
	em:RegisterForUpdate(self.name .. "ShareAsk", delay, function()
		em:UnregisterForUpdate(self.name .. "ShareAsk")
		self:ShareAsk(why)
	end)
end

-- A route has started to come in: if it is still not whole in MISSING_MS, ask again.
function A:ShareWatchMissing()
	em:UnregisterForUpdate(self.name .. "ShareMissing")
	em:RegisterForUpdate(self.name .. "ShareMissing", MISSING_MS, function()
		em:UnregisterForUpdate(self.name .. "ShareMissing")
		if next(self.share.partial) ~= nil then
			self:ShareAsk("part of a route is missing")
		end
	end)
end

-- ---------------------------------------------------------------------------------------
-- Receiving
-- ---------------------------------------------------------------------------------------

-- A message from the library. `unitTag` names the sender in the group.
function A:ShareHear(unitTag, data)
	local share = self.share
	local sender = GetUnitDisplayName and GetUnitDisplayName(unitTag) or nil
	-- the library hands a sender its own broadcasts back
	if type(sender) ~= "string" or sender == "" or sender == Own() then
		return
	end
	share.heard = share.heard + 1
	if type(data) ~= "table" then
		share.ignored = share.ignored + 1
		return
	end
	if data.version ~= T.VERSION then
		share.mismatched = share.mismatched + 1
		share.lastWhy = "a message of another version of the protocol (from " .. sender .. ")"
		return
	end
	if data.kind == T.REQUEST then
		-- somebody asks for the route: the one who made it answers (what they hear does not depend on their receive setting)
		share.asks = share.asks + 1
		self:ShareResendSoon(REPLY_DELAY_MS, "a member asked", true)
		return
	end
	if not (self.sv and self.sv.shareReceive) then
		share.ignored = share.ignored + 1
		share.lastWhy = "receiving is switched off"
		return
	end
	self:ShareReceive(sender, data)
end

-- Is a route with this rev from this player newer than the one taken over?
local function Newer(share, rev, sender)
	if rev ~= share.rev then
		return rev > share.rev
	end
	return sender > (share.revOwner or "")
end

function A:ShareReceive(sender, data)
	local share = self.share
	local kind, rev = data.kind, data.rev
	if not Number(rev) or (kind ~= T.ROUTE and kind ~= T.CLEAR) then
		share.ignored = share.ignored + 1
		share.lastWhy = "a message that could not be read (from " .. sender .. ")"
		return
	end
	if not Newer(share, rev, sender) then
		share.ignored = share.ignored + 1 -- an older route, or the one already taken over
		return
	end
	local now = Now()
	-- routes that never came in full
	for name, partial in pairs(share.partial) do
		if now - partial.at > ASSEMBLE_MS then
			share.partial[name] = nil
		end
	end

	if kind == T.CLEAR then
		share.partial[sender] = nil
		self:ShareAdopt(sender, rev, { done = 0, hasDest = false, points = {} })
		return
	end

	-- a message with up to three points of a route
	local total, start, n = data.total, data.start, data.n
	local points = {}
	local valid = Number(total) and Number(start) and Number(n) and total >= 1 and total <= MAX_POINTS and n >= 1 and n <= PER_MESSAGE
		and start >= 1 and start + n - 1 <= total
	if valid then
		for slot = 1, n do
			local mapId, x, y = data["m" .. slot], data["x" .. slot], data["y" .. slot]
			if not (Number(mapId) and Number(x) and Number(y)) or mapId < 1 or mapId > MAX_MAP_ID or x < 0 or x > COORD or y < 0 or y > COORD then
				valid = false
				break
			end
			points[slot] = { mapId = math.floor(mapId), nx = x / COORD, ny = y / COORD }
		end
	end
	if not valid then
		share.ignored = share.ignored + 1
		share.lastWhy = "a point that is not a point (from " .. sender .. ")"
		return
	end
	local partial = share.partial[sender]
	if partial and partial.rev > rev then
		share.ignored = share.ignored + 1 -- the rest of a route older than the one that is coming in
		return
	end
	if not partial or partial.rev ~= rev or partial.total ~= total then
		partial = { rev = rev, total = total, done = Number(data.done) and data.done or 0, hasDest = data.dest == 1, points = {}, got = 0, at = now }
		share.partial[sender] = partial
		self:ShareWatchMissing()
	end
	for slot = 1, n do
		local index = start + slot - 1
		if not partial.points[index] then
			partial.got = partial.got + 1
		end
		partial.points[index] = points[slot]
	end
	partial.at = now
	if partial.got == partial.total then
		share.partial[sender] = nil
		self:ShareAdopt(sender, rev, partial)
	end
end

-- Takes a whole route over as this player's own.
function A:ShareAdopt(sender, rev, snapshot)
	local share = self.share
	-- every map in it must be one this game knows: a route that cannot be placed is not taken
	for _, point in ipairs(snapshot.points) do
		if not self:MapRect(point.mapId) then
			share.ignored = share.ignored + 1
			share.lastWhy = string.format("a route from %s with a map this game does not know (%d)", sender, point.mapId)
			self:Trace("share", share.lastWhy)
			return false
		end
	end
	share.rev, share.revOwner, share.ownRev = rev, sender, false
	-- what this player was about to send (or to send again) is overtaken by what has come
	em:UnregisterForUpdate(self.name .. "Share")
	em:UnregisterForUpdate(self.name .. "ShareRepeat")
	self:ImportRoute(snapshot)
	share.adopted = share.adopted + 1
	share.lastFrom = sender
	share.lastWhy = nil
	local stops = math.max(0, #snapshot.points - (snapshot.hasDest and 1 or 0))
	self:Trace("share", string.format("took over the route of %s: %d stops%s", sender, stops, snapshot.hasDest and " and a destination" or ""))
	if #snapshot.points == 0 then
		self:Print(S.sharedCleared, sender)
	else
		self:Print(S.sharedRoute, sender, stops)
	end
	if self.sv.sound and self.Play then
		self.Play("MAP_PING")
	end
	return true
end

-- /pbwp status
function A:ShareLines()
	local share = self.share
	local lines = {}
	lines[1] = string.format("group sharing: send %s, receive %s; %s; protocol id %d; group of %d",
		self.sv.shareSend and "on" or "off", self.sv.shareReceive and "on" or "off", share.why, T.ID, GetGroupSize and GetGroupSize() or 0)
	lines[2] = string.format("   sent %d messages, heard %d, took over %d routes, did not use %d, %d of another version; asked %d times, was asked %d times%s%s",
		share.sent, share.heard, share.adopted, share.ignored, share.mismatched, share.asked, share.asks,
		share.lastFrom and ("; the last route came from " .. share.lastFrom) or "",
		share.lastWhy and ("; last problem: " .. share.lastWhy) or "")
	lines[3] = string.format("   the route's rev is %d, made by %s", share.rev, share.revOwner and (share.ownRev and "you" or share.revOwner) or "nobody yet")
	return lines
end

A.loaded.Share = true
