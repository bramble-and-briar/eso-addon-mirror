-- PB's Emote Synchronizer
-- Author: PinkBanther
--
-- When the group leader plays an emote, every member who runs this add-on plays the same one.
--
-- ---------------------------------------------------------------------------------------
-- HOW THE LEADER'S EMOTE IS SEEN
-- ---------------------------------------------------------------------------------------
--
-- Nothing in the API says that an emote started, for the player or for anybody else. The only
-- emote event is EVENT_PLAYER_EMOTE_FAILED_PLAY. What does exist: the emote menu, the utility
-- wheel and every /slash emote command call the global PlayEmoteByIndex by name each time they
-- are used. This add-on puts a small function in that global's place. It is a leaf: it sends
-- the emote's id to the group and then calls the real function. The real one is never
-- skipped because of an error here, and nothing of the client's is wrapped or rebuilt.
--
-- The id travels, not the index: the index depends on what the player owns and which language
-- the game runs in, GetEmoteIndex(emoteId) turns the id back into the receiver's own index.
--
-- ---------------------------------------------------------------------------------------
-- HOW LONG IT TAKES
-- ---------------------------------------------------------------------------------------
--
-- The channel is LibGroupBroadcast. Its first message after a quiet spell waits 500 ms before
-- it goes out, and the game then enforces a cooldown between messages, so members trail the
-- leader by at least half a second plus the trip. "Leader waits" holds the leader's own emote
-- back by that time (the leader's call is swallowed and made again after the wait), and
-- /emotesync ping measures the round trip to pick a value from. How long it is on a console is
-- not known until it has been measured there.
--
-- ---------------------------------------------------------------------------------------
-- WHAT IT DOES NOT DO
-- ---------------------------------------------------------------------------------------
--
-- No emote can be seen ending, so stopping is left to each player (moving cancels an emote).
-- A member plays an emote only if they own it and are out of combat; anything else is skipped
-- and counted, /emotesync status says why.
-- ---------------------------------------------------------------------------------------

if PBS_EMOTESYNCHRONIZER then
	return
end

-- TYPOGRAPHIC apostrophe (U+2019). With an ASCII ' here the settings panel eats the whole
-- "PB's " and shows only the rest. The manifest keeps the ASCII form, because that is what the
-- in-game add-on list and the store listing want.
local DISPLAY_NAME = "PB’s Emote Synchronizer"

local addon = {
	name = "PBsEmoteSynchronizer",
	title = DISPLAY_NAME, -- gets the version added once the manifest is read: this is the name in the add-on list
	author = "PinkBanther",
	version = "", -- read from the manifest's ## Title line, see ReadManifestVersion
	DEFAULTS = {
		enabled = true,
		send = true,
		follow = true,
		notify = true,
		leadMs = 0,
	},
}
PBS_EMOTESYNCHRONIZER = addon

local em = EVENT_MANAGER

local MAX_LEAD_MS = 3000
local PING_WAIT_MS = 6000
local PONG_MIN_GAP_MS = 1000
local FAILURE_WINDOW_MS = 3000
local SEQ_MODULUS = 2147483000

local state = {
	debug = false,
	seq = 0,
	lastSeq = {}, -- sender display name -> the last sequence number taken from them
	ping = nil,
	lastOneWayMs = nil,
	lastPongAt = nil,
	pendingName = nil,
	pendingAt = nil,
	stats = { sent = 0, heard = 0, played = 0, failed = 0, skipped = {} },
}
addon.state = state

local original -- the real PlayEmoteByIndex, once it has been replaced

local function Now()
	return GetGameTimeMilliseconds()
end

local function Debug(fmt, ...)
	if state.debug then
		d(string.format("[EmoteSync] " .. fmt, ...))
	end
end

local function OnOff(value)
	return GetString(value and SI_PBSES_STATE_ON or SI_PBSES_STATE_OFF)
end

function addon:Skip(reason)
	local skipped = state.stats.skipped
	skipped[reason] = (skipped[reason] or 0) + 1
	Debug("skipped: %s", reason)
end

function addon:Role()
	if GetGroupSize() <= 1 then
		return "solo"
	end
	return IsUnitGroupLeader("player") and "leader" or "member"
end

local function EmoteLabel(emoteIndex)
	local slash, _, _, display = GetEmoteInfo(emoteIndex)
	if display and display ~= "" then
		return display
	end
	return slash or tostring(emoteIndex)
end

-- ---- playing --------------------------------------------------------------------------
-- Every emote this add-on starts goes through here. It calls the real function, not the global,
-- so the replacement below never sees it and never sends it on again.
local function PlayOwn(emoteIndex)
	if not original then
		return false
	end
	local ok, err = pcall(original, emoteIndex)
	if not ok then
		Debug("PlayEmoteByIndex failed: %s", tostring(err))
	end
	return ok
end

-- The leader's side: called for every emote the player starts while the add-on is on. Returns
-- how long the leader's own emote should be held back, or nil to play it at once.
function addon:OnLocalEmote(emoteIndex)
	local sv = self.sv
	if not (sv.enabled and sv.send) then
		return nil
	end
	if GetGroupSize() <= 1 or not IsUnitGroupLeader("player") then
		return nil
	end
	if IsUnitInCombat("player") then
		self:Skip("sendCombat")
		return nil
	end
	local emoteId = select(3, GetEmoteInfo(emoteIndex))
	if not emoteId or not self.transport then
		return nil
	end
	state.seq = (state.seq + 1) % SEQ_MODULUS
	if not self.transport:SendEmote(emoteId, state.seq) then
		Debug("not sent: %s", tostring(self.transport.why))
		return nil
	end
	state.stats.sent = state.stats.sent + 1
	Debug("sent %s (id %d, seq %d)", EmoteLabel(emoteIndex), emoteId, state.seq)
	return sv.leadMs
end

local function Replacement(emoteIndex, ...)
	if not addon.sv then
		return original(emoteIndex, ...)
	end
	local ok, lead = pcall(addon.OnLocalEmote, addon, emoteIndex)
	if not ok then
		Debug("send failed: %s", tostring(lead))
	elseif lead and lead > 0 then
		zo_callLater(function()
			PlayOwn(emoteIndex)
		end, lead)
		return
	end
	return original(emoteIndex, ...)
end

function addon:InstallHook()
	if original then
		return true
	end
	if type(PlayEmoteByIndex) ~= "function" then
		return false
	end
	original = PlayEmoteByIndex
	PlayEmoteByIndex = Replacement
	return true
end

-- ---- receiving ------------------------------------------------------------------------
function addon:OnEmote(unitTag, sender, emoteId, seq)
	local sv = self.sv
	state.stats.heard = state.stats.heard + 1
	if not (sv.enabled and sv.follow) then
		return self:Skip("off")
	end
	if not IsUnitGroupLeader(unitTag) then
		return self:Skip("notLeader")
	end
	if state.lastSeq[sender] == seq then
		return self:Skip("duplicate")
	end
	state.lastSeq[sender] = seq
	if IsUnitInCombat("player") then
		return self:Skip("combat")
	end
	local emoteIndex = GetEmoteIndex(emoteId)
	if not emoteIndex then
		return self:Skip("unknown")
	end
	local collectibleId = GetEmoteCollectibleId(emoteIndex)
	if collectibleId and collectibleId ~= 0 and not IsCollectibleUnlocked(collectibleId) then
		return self:Skip("locked")
	end
	local label = EmoteLabel(emoteIndex)
	state.pendingName, state.pendingAt = label, Now()
	Debug("playing %s (id %d, seq %d) from %s", label, emoteId, seq, sender)
	if PlayOwn(emoteIndex) then
		state.stats.played = state.stats.played + 1
		if sv.notify then
			d(string.format(GetString(SI_PBSES_FOLLOWED), label))
		end
	end
end

local function FailureText(failure)
	if failure == PLAYER_EMOTE_PLAY_FAILURE_BLACKLISTED then
		return GetString(SI_PBSES_FAIL_BLACKLISTED)
	elseif failure == PLAYER_EMOTE_PLAY_FAILURE_GENERIC then
		return GetString(SI_PBSES_FAIL_GENERIC)
	elseif failure == PLAYER_EMOTE_PLAY_FAILURE_LOCKED then
		return GetString(SI_PBSES_FAIL_LOCKED)
	end
	return string.format(GetString(SI_PBSES_FAIL_UNKNOWN), tostring(failure))
end

-- The game says an emote could not be played, not which one. It counts as ours only if this
-- add-on asked for one a moment ago.
local function OnEmoteFailed(_, failure)
	if state.pendingAt and Now() - state.pendingAt <= FAILURE_WINDOW_MS then
		state.stats.failed = state.stats.failed + 1
		state.stats.played = math.max(0, state.stats.played - 1)
		if addon.sv.notify then
			d(string.format(GetString(SI_PBSES_FAILED), state.pendingName or "?", FailureText(failure)))
		end
		state.pendingAt = nil
	else
		Debug("an emote failed that was not ours (%s)", tostring(failure))
	end
end

-- ---- measuring ------------------------------------------------------------------------
function addon:Ping()
	local transport = self.transport
	if GetGroupSize() <= 1 then
		d(GetString(SI_PBSES_NOT_GROUPED))
		return
	end
	local nonce = math.random(1, 2147483000)
	if not (transport and transport:SendPing(nonce)) then
		d(string.format(GetString(SI_PBSES_SEND_FAILED), tostring(transport and transport.why or GetString(SI_PBSES_WHY_NOT_READY))))
		return
	end
	state.ping = { nonce = nonce, t0 = Now(), replies = {}, rtts = {} }
	d(GetString(SI_PBSES_PING_SENT))
	zo_callLater(function()
		self:PingSummary(nonce)
	end, PING_WAIT_MS)
end

function addon:OnPing(nonce)
	local now = Now()
	if state.lastPongAt and now - state.lastPongAt < PONG_MIN_GAP_MS then
		return
	end
	state.lastPongAt = now
	if self.transport then
		self.transport:SendPong(nonce)
	end
end

function addon:OnPong(sender, nonce)
	local ping = state.ping
	if not ping or ping.nonce ~= nonce or ping.replies[sender] then
		return
	end
	local rtt = Now() - ping.t0
	ping.replies[sender] = rtt
	ping.rtts[#ping.rtts + 1] = rtt
	d(string.format(GetString(SI_PBSES_PING_REPLY), sender, rtt))
end

function addon:PingSummary(nonce)
	local ping = state.ping
	if not ping or ping.nonce ~= nonce then
		return
	end
	local rtts = ping.rtts
	if #rtts == 0 then
		d(GetString(SI_PBSES_PING_NONE))
		return
	end
	table.sort(rtts)
	local median = rtts[math.floor((#rtts + 1) / 2)]
	state.lastOneWayMs = math.floor(median / 2 + 0.5)
	d(string.format(GetString(SI_PBSES_PING_SUMMARY), #rtts, rtts[1], median, rtts[#rtts], state.lastOneWayMs))
end

-- ---- messages from the channel --------------------------------------------------------
function addon:OnTransportData(kind, unitTag, sender, a, b)
	local T = self.Transport
	if kind == T.EMOTE then
		self:OnEmote(unitTag, sender, a, b)
	elseif kind == T.PING then
		self:OnPing(a)
	elseif kind == T.PONG then
		self:OnPong(sender, a)
	end
end

-- ---- public ---------------------------------------------------------------------------
function addon:Set(key, value)
	self.sv[key] = value
end

function addon:Reset()
	for key, value in pairs(self.DEFAULTS) do
		self.sv[key] = value
	end
end

local function Clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

-- ---- slash commands -------------------------------------------------------------------
local function FindEmote(word)
	word = zo_strlower(zo_strtrim(word or ""))
	word = (word:gsub("^/", ""))
	if word == "" then
		return nil
	end
	for index = 1, GetNumEmotes() do
		local names = zo_strlower(GetEmoteSlashNameByIndex(index) or "")
		for alias in string.gmatch(names, "%S+") do
			if (alias:gsub("^/", "")) == word then
				return index
			end
		end
	end
	return nil
end

local function PrintStatus()
	local sv, stats = addon.sv, state.stats
	local roles = { solo = SI_PBSES_ROLE_SOLO, leader = SI_PBSES_ROLE_LEADER, member = SI_PBSES_ROLE_MEMBER }
	d(
		string.format(
			GetString(SI_PBSES_STATUS_ROLE),
			GetString(roles[addon:Role()]),
			OnOff(sv.enabled),
			OnOff(sv.send),
			OnOff(sv.follow),
			sv.leadMs,
			GetString(original and SI_PBSES_HOOK_ACTIVE or SI_PBSES_HOOK_MISSING)
		)
	)
	d(addon.transport and addon.transport:Report() or GetString(SI_PBSES_NO_LIBRARY))
	d(string.format(GetString(SI_PBSES_STATUS_COUNTS), stats.sent, stats.heard, stats.played, stats.failed))
	local names = {}
	for reason in pairs(stats.skipped) do
		names[#names + 1] = reason
	end
	table.sort(names)
	local parts = {}
	for _, reason in ipairs(names) do
		parts[#parts + 1] = reason .. " " .. stats.skipped[reason]
	end
	d(string.format(GetString(SI_PBSES_STATUS_SKIPPED), #parts > 0 and table.concat(parts, ", ") or GetString(SI_PBSES_STATUS_NONE)))
end

-- Asks the game, instead of calling and finding out. Whether these two may themselves be called
-- from an add-on is not known; if they are refused the client shows its own error screen.
local function PrintProbe()
	if type(IsPrivateFunction) ~= "function" or type(IsProtectedFunction) ~= "function" then
		d(GetString(SI_PBSES_PROBE_UNAVAILABLE))
		return
	end
	local cooldown = GetGroupAddOnDataBroadcastCooldownRemainingMS and GetGroupAddOnDataBroadcastCooldownRemainingMS() or -1
	d(
		string.format(
			GetString(SI_PBSES_PROBE),
			tostring(IsPrivateFunction("PlayEmoteByIndex")),
			tostring(IsProtectedFunction("PlayEmoteByIndex")),
			GetNumEmotes(),
			cooldown
		)
	)
end

local function OnSlash(arg)
	arg = zo_strtrim(arg or "")
	local word, rest = arg:match("^(%S*)%s*(.-)$")
	word = zo_strlower(word or "")
	if word == "on" or word == "off" then
		addon.sv.enabled = word == "on"
		d(GetString(addon.sv.enabled and SI_PBSES_ON or SI_PBSES_OFF))
	elseif word == "status" then
		PrintStatus()
	elseif word == "debug" then
		state.debug = not state.debug
		d(GetString(state.debug and SI_PBSES_DEBUG_ON or SI_PBSES_DEBUG_OFF))
	elseif word == "probe" then
		PrintProbe()
	elseif word == "ping" then
		addon:Ping()
	elseif word == "lead" then
		local value
		if zo_strlower(rest) == "auto" then
			if not state.lastOneWayMs then
				d(GetString(SI_PBSES_LEAD_NO_MEASURE))
				return
			end
			value = state.lastOneWayMs
		else
			value = tonumber(rest)
		end
		if not value then
			d(GetString(SI_PBSES_LEAD_USAGE))
			return
		end
		addon.sv.leadMs = Clamp(math.floor(value / 50 + 0.5) * 50, 0, MAX_LEAD_MS)
		d(string.format(GetString(SI_PBSES_LEAD_SET), addon.sv.leadMs))
	elseif word == "play" then
		if rest == "" then
			d(GetString(SI_PBSES_PLAY_USAGE))
			return
		end
		local emoteIndex = FindEmote(rest)
		if not emoteIndex then
			d(string.format(GetString(SI_PBSES_PLAY_NONE), rest))
			return
		end
		d(string.format(GetString(SI_PBSES_PLAY_DONE), EmoteLabel(emoteIndex)))
		PlayOwn(emoteIndex)
	else
		d(GetString(SI_PBSES_HELP))
	end
end

-- ---- load -----------------------------------------------------------------------------
local function OnPlayerActivated()
	em:UnregisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED)
	-- chat is up by now; a line printed at EVENT_ADD_ON_LOADED is lost
	d(string.format(GetString(SI_PBSES_LOADED), addon.version))
	if addon.transport and addon.transport.error then
		d(addon.transport.error)
	end
end

-- The version is written only in the manifest, in the ## Title line; it is read back from there, so
-- a release changes it in one place (and in ## Version, which the game's own list shows).
local function ReadManifestVersion()
	local manager = GetAddOnManager and GetAddOnManager()
	if not manager then
		return ""
	end
	for index = 1, manager:GetNumAddOns() do
		local name, title = manager:GetAddOnInfo(index)
		if name == addon.name and title then
			local plain = title:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
			return plain:match("([%d]+[%d%.]*)%s*$") or ""
		end
	end
	return ""
end

local function OnAddOnLoaded(_, name)
	if name ~= addon.name then
		return
	end
	em:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

	addon.version = ReadManifestVersion()
	addon.title = addon.version ~= "" and (DISPLAY_NAME .. " " .. addon.version) or DISPLAY_NAME

	addon.sv = ZO_SavedVars:NewAccountWide("PBsEmoteSynchronizer_Data", 1, nil, addon.DEFAULTS)

	-- A sequence number must not repeat after a reload, or the first emote afterwards would be
	-- taken for a duplicate of the last one before it.
	state.seq = (GetTimeStamp() * 7 + GetGameTimeMilliseconds()) % SEQ_MODULUS

	if addon.Transport then
		addon.transport = addon.Transport.New(function(kind, unitTag, sender, a, b)
			addon:OnTransportData(kind, unitTag, sender, a, b)
		end)
	end
	-- Without a working channel there is nothing to send, so the game's function stays untouched.
	if addon.transport and addon.transport.protocol then
		addon:InstallHook()
	end

	em:RegisterForEvent(addon.name, EVENT_PLAYER_EMOTE_FAILED_PLAY, OnEmoteFailed)
	em:RegisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

	SLASH_COMMANDS["/emotesync"] = OnSlash

	if addon.InitSettings then
		addon:InitSettings()
	end
end

em:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
