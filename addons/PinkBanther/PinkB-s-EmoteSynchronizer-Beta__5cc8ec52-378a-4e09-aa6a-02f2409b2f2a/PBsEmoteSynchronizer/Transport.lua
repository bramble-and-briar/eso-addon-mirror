-- PB's Emote Synchronizer -- the LibGroupBroadcast side
--
-- One protocol, three kinds of message:
--
--     EMOTE   a = the emote's id,  b = a sequence number (the leader's, to drop duplicates)
--     PING    a = a random number the answer must repeat
--     PONG    a = that number again
--
-- PBS_EMOTESYNCHRONIZER is nil if Main.lua bailed out early (e.g. already loaded).
if not PBS_EMOTESYNCHRONIZER then
	return
end

local addon = PBS_EMOTESYNCHRONIZER

-- Protocol ids are one number per add-on, shared by everything a player has installed, and whichever
-- add-on declares one second is refused outright. 460-469 is PinkBanther's block: 460 Tetris, 461
-- Janken, 462 Translate, 463 War Table, 464 this. DEVELOPMENT: reserve it before a public release.
local T = {
	ID = 464,
	NAME = "PBsEmoteSyncV1",
	VERSION = 1,
	EMOTE = 1,
	PING = 2,
	PONG = 3,
}
T.__index = T
addon.Transport = T

-- Laid out like PBsJanken's, the shape known to work on console: two bits of version, three of
-- kind, then full 32 bit words. The version keeps its width forever, so a client on another
-- version can still read it and say so.
function T.New(onData)
	local self = setmetatable({ sent = 0, heard = 0, mismatched = 0 }, T)
	if not LibGroupBroadcast then
		self.error = GetString(SI_PBSES_NO_LIBRARY)
		return self
	end
	local stage = "registerHandler"
	local ok, err = pcall(function()
		local handler = assert(LibGroupBroadcast:RegisterHandler(addon.name), "Handler registration returned nil")
		handler:SetDisplayName(addon.title)
		handler:SetDescription("Plays the group leader's emotes for the whole group.")
		stage = "declareProtocol"
		local p = handler:DeclareProtocol(T.ID, T.NAME)
		self.protocol = p
		p:SetDisplayName(addon.title)
		stage = "createFields"
		p:AddField(LibGroupBroadcast.CreateNumericField("version", { numBits = 2 }))
		p:AddField(LibGroupBroadcast.CreateNumericField("kind", { numBits = 3 }))
		p:AddField(LibGroupBroadcast.CreateNumericField("a", { numBits = 32 }))
		p:AddField(LibGroupBroadcast.CreateNumericField("b", { numBits = 32 }))
		stage = "registerReceiver"
		p:OnData(function(unitTag, data)
			-- The library hands a sender its own broadcasts back. Dropped without a word.
			local sender = GetUnitDisplayName(unitTag)
			if not sender or sender == "" or sender == GetDisplayName() then
				return
			end
			self.heard = self.heard + 1
			if data.version ~= T.VERSION then
				self.mismatched = self.mismatched + 1
				self.why = GetString(SI_PBSES_WHY_VERSION)
				return
			end
			onData(data.kind, unitTag, sender, data.a or 0, data.b or 0)
		end)
		stage = "finalizeProtocol"
		assert(p:Finalize({ isRelevantInCombat = false, replaceQueuedMessages = false }), "Protocol validation failed")
	end)
	if not ok then
		self.protocol = nil
		-- DeclareProtocol only raises when the id or the name is already taken; the library's own
		-- message names the protocol sitting there.
		local first = tostring(err):match("^[^\n]*") or tostring(err)
		local detail = "[" .. stage .. "] " .. first:gsub("^.*[/\\]", "")
		if first:find("already exists", 1, true) then
			self.error = string.format(GetString(SI_PBSES_TRANSPORT_ID_TAKEN), T.ID, detail)
		else
			self.error = string.format(GetString(SI_PBSES_TRANSPORT_FAILED), detail)
		end
	end
	return self
end

-- `replace` lets this message take the place of any still waiting in the queue: right for an
-- emote, where only the newest matters, wrong for a ping reply, which must not push one out.
function T:Send(kind, a, b, replace)
	if not self.protocol then
		self.why = GetString(SI_PBSES_WHY_NOT_READY)
		return false
	end
	if not self.protocol:IsEnabled() then
		self.why = GetString(SI_PBSES_WHY_DISABLED)
		return false
	end
	local values = { version = T.VERSION, kind = kind, a = a or 0, b = b or 0 }
	if self.protocol:Send(values, { replaceQueuedMessages = replace == true }) ~= true then
		self.why = GetString(SI_PBSES_WHY_REFUSED)
		return false
	end
	self.why = nil
	self.sent = self.sent + 1
	return true
end

function T:SendEmote(emoteId, seq)
	return self:Send(T.EMOTE, emoteId, seq, true)
end

function T:SendPing(nonce)
	return self:Send(T.PING, nonce, 0, false)
end

function T:SendPong(nonce)
	return self:Send(T.PONG, nonce, 0, false)
end

function T:Report()
	if self.error then
		return self.error
	end
	local enabled = self.protocol and self.protocol:IsEnabled()
	return string.format(
		GetString(SI_PBSES_TRANSPORT_REPORT),
		T.ID,
		GetString(enabled and SI_PBSES_STATE_ON or SI_PBSES_STATE_OFF),
		self.sent,
		self.heard,
		self.mismatched,
		self.why and string.format(GetString(SI_PBSES_WHY_LAST), self.why) or ""
	)
end
