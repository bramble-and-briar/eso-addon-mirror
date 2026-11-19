-- Sharing the markers with the group (LibGroupBroadcast, protocol id 466).
--
-- When a member puts an extra marker on somebody, takes one off, or takes them all off, the group is told; every member
-- who runs this add-on keeps the same table of markers and draws them. A member who does not run the add-on sees only the
-- game's own eight (the extra ones are drawn by this add-on, not by the game).
--
-- THE LIBRARY (read from its source, github.com/sirinsidiator/ESO-LibGroupBroadcast, not guessed; PB's note on it is
-- "LibGroupBroadcast facts"):
--   * a numeric field is 2 to 32 bits wide: a 1-bit field makes the protocol fail to finalize and NOTHING is sent;
--   * the protocol id is 9 bits; PB's block is 460-469 and this add-on is 466;
--   * delivery is best effort: the game drops a frame it refuses and the library never sends it again, and there is no
--     acknowledgement. So this file sends what a player put on AGAIN every REFRESH_MS, a newcomer is sent the markers
--     when they join, and a member who has just logged in or joined asks for them (REQUEST);
--   * the library hands a sender its own broadcast back: it is dropped by display name.
-- Finalized with isRelevantInCombat = true (a marker is put on in a fight) and replaceQueuedMessages = false (one message
-- per marker: with the default, the second of two quick markers would delete the first from the queue).
--
--   SET       version, kind, target (hash of the marked person's @name), icon (1..24)   put on / still on
--   CLEAR     ... target                                                               taken off
--   CLEARALL                                                                           everything taken off
--   REQUEST                                                                            "send me your markers"
--
-- A marker has one owner, the member who sent its SET last. Hearing a SET or CLEAR for a person this player had marked
-- ends this player's ownership: the newer word is the group's.
local A, S = PBS_PME, PBS_PME_STRINGS
local em = EVENT_MANAGER

local T = {
	ID = 466,
	NAME = "PBsPlayerMarkerExtensionV1",
	VERSION = 1,
	kinds = { SET = 1, CLEAR = 2, REQUEST = 3, CLEARALL = 4 },
}
local KIND_NAME = {}
for name, number in pairs(T.kinds) do
	KIND_NAME[number] = name
end
A.ShareProtocol = T

-- name, bits (each 2 .. 32)
local FIELDS = { { "version", 2 }, { "kind", 3 }, { "target", 32 }, { "icon", 6 } }
A.ShareFields = FIELDS

local REFRESH_MS = 20000 -- what this player put on is sent again after this long, and again, for as long as it is on
local JOIN_DELAY_MS = 4000 -- after somebody joins: the newcomer's add-on needs a moment
local REPLY_DELAY_MS = 1500 -- after somebody asks
local REPLY_MIN_MS = 8000 -- the markers are sent again for a newcomer or an asker at most this often
local ASK_DELAY_MS = 6000 -- after logging in or joining a group: ask for the markers
local ASK_MIN_MS = 20000 -- ... at most this often

A.share = {
	ready = false,
	why = "not set up yet",
	sent = 0, -- messages handed to the library
	heard = 0, -- messages from others
	applied = 0, -- messages that changed something
	ignored = 0, -- messages not used (switched off, damaged, unknown ...)
	mismatched = 0, -- from another version of the protocol
	echoes = 0, -- this player's own messages given back by the library
	asked = 0,
	asks = 0,
	lastWhy = nil, -- the last reason something was not sent or not used
	lastFrom = nil,
	protocol = nil,
	nextRefresh = nil,
	replyAt = nil,
	askAt = nil,
	lastReply = -1e9,
	lastAsk = -1e9,
}

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
		handler:SetDescription("Shares the extra target markers you put on your group members with the group.")
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
		assert(protocol:Finalize({ isRelevantInCombat = true, replaceQueuedMessages = false }),
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
		self:RosterDirty()
		if isLocalPlayer then
			self:ShareAskSoon(ASK_DELAY_MS)
			-- a marker this player put on themself while alone is new to the group
			self:ShareReplySoon(ASK_DELAY_MS)
		else
			self:ShareReplySoon(JOIN_DELAY_MS)
		end
	end)
	em:RegisterForEvent(self.name .. "Left", EVENT_GROUP_MEMBER_LEFT, function(_, _, _, isLocalPlayer)
		self:RosterDirty()
		if isLocalPlayer then
			-- left the group (or it was disbanded): the group's markers are gone, a marker on this player themself stays
			self:KeepOnlyOwnMark()
			self:Trace("mark", "the group's markers dropped: this player left the group")
		end
	end)
	em:RegisterForEvent(self.name .. "Update", EVENT_GROUP_UPDATE, function()
		self:RosterDirty()
	end)
end

-- Called once per login, when the player is in the world: a member who logs in (or reloads) into a group asks.
function A:ShareLogin()
	if self.shareLoginDone then
		return
	end
	self.shareLoginDone = true
	self:ShareAskSoon(ASK_DELAY_MS)
end

-- ---------------------------------------------------------------------------------------
-- Sending
-- ---------------------------------------------------------------------------------------

-- kindName: "SET", "CLEAR", "CLEARALL" (these go when sending is on) or "REQUEST" (when showing the group's is on).
function A:ShareSend(kindName, target, icon)
	local share = self.share
	local kind = T.kinds[kindName]
	if kindName == "REQUEST" then
		if not self.sv.shareReceive then
			share.lastWhy = "showing the group's markers is switched off"
			return false
		end
	elseif not self.sv.shareSend then
		share.lastWhy = "sending is switched off"
		return false
	end
	if not share.ready then
		share.lastWhy = share.why
		return false
	end
	if not self:Grouped() then
		share.lastWhy = "not in a group"
		return false
	end
	local protocol = share.protocol
	-- the player can switch a protocol off in LibGroupBroadcast's own settings; asking first keeps the library's log quiet
	if protocol.IsEnabled and not protocol:IsEnabled() then
		share.lastWhy = "switched off in LibGroupBroadcast's settings"
		return false
	end
	local ok, queued = pcall(protocol.Send, protocol, { version = T.VERSION, kind = kind, target = target or 0, icon = icon or 0 })
	if not ok or not queued then
		share.lastWhy = "the library did not take the " .. kindName .. " message: " .. tostring(queued)
		return false
	end
	share.sent = share.sent + 1
	return true
end

-- Everything this player put on, sent again (the group's copy of it is refreshed, and a newcomer gets it).
function A:ShareResend()
	local count = 0
	for hash, m in pairs(self.marks) do
		if m.mine and self:ShareSend("SET", hash, m.icon) then
			count = count + 1
		end
	end
	return count
end

-- The next repeat is due REFRESH_MS from now (a marker was just put on).
function A:ShareArm()
	local share = self.share
	if not share.nextRefresh then
		share.nextRefresh = A.Stamp() + REFRESH_MS
	end
end

function A:ShareReplySoon(delay)
	local share = self.share
	if not self:HasMine() then
		return
	end
	local now = A.Stamp()
	if now - share.lastReply < REPLY_MIN_MS then
		return
	end
	share.replyAt = share.replyAt or (now + delay)
end

function A:ShareAskSoon(delay)
	local share = self.share
	if not self:Grouped() then
		return
	end
	local now = A.Stamp()
	if now - share.lastAsk < ASK_MIN_MS then
		return
	end
	share.askAt = share.askAt or (now + delay)
end

-- A few times a second, with the other housekeeping.
function A:ShareTick(now)
	local share = self.share
	if share.askAt and now >= share.askAt then
		share.askAt = nil
		share.lastAsk = now
		if self:ShareSend("REQUEST", 0, 0) then
			share.asked = share.asked + 1
		end
	end
	if share.replyAt and now >= share.replyAt then
		share.replyAt = nil
		share.lastReply = now
		self:ShareResend()
	end
	if share.nextRefresh and now >= share.nextRefresh then
		if self:HasMine() then
			share.nextRefresh = now + REFRESH_MS
			self:ShareResend()
		else
			share.nextRefresh = nil
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- Receiving
-- ---------------------------------------------------------------------------------------

function A:ShareHear(unitTag, data)
	local share = self.share
	share.heard = share.heard + 1
	local sender = GetUnitDisplayName and GetUnitDisplayName(unitTag) or ""
	if type(sender) ~= "string" or sender == "" or type(data) ~= "table" then
		share.ignored = share.ignored + 1
		return
	end
	-- the library gives this player's own broadcast back: by the unit tag (it is the player's own) and by name
	if (AreUnitsEqual and AreUnitsEqual(unitTag, "player")) or sender == self:OwnName() then
		share.echoes = share.echoes + 1
		return
	end
	share.lastFrom = sender
	if data.version ~= T.VERSION then
		share.mismatched = share.mismatched + 1
		share.lastWhy = string.format("%s sent version %s of the protocol (this is %d)", sender, tostring(data.version), T.VERSION)
		return
	end
	local kind = KIND_NAME[data.kind]
	if kind == "REQUEST" then
		share.asks = share.asks + 1
		if self.sv.shareSend then
			self:ShareReplySoon(REPLY_DELAY_MS)
		end
		return
	end
	if not self.sv.shareReceive then
		share.ignored = share.ignored + 1
		return
	end
	local target = data.target
	if kind == "SET" and type(target) == "number" and target ~= 0 and self:RemoteSet(sender, target, data.icon) then
		share.applied = share.applied + 1
	elseif kind == "CLEAR" and type(target) == "number" and target ~= 0 then
		self:RemoteClear(sender, target)
		share.applied = share.applied + 1
	elseif kind == "CLEARALL" then
		self:RemoteClearAll(sender)
		share.applied = share.applied + 1
	else
		share.ignored = share.ignored + 1
	end
end

A.MARK("Share")
