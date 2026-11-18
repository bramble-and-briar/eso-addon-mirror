-- Listens to the guild members' status and turns the changes that matter into alerts (Alert.lua shows them).
--
-- A change matters when the member goes between offline and not-offline. A change between online, away and
-- do-not-disturb is neither an arrival nor a departure. The test uses the old and the new status the event
-- carries, the way PB's TargetPlayer reads the friends' and guild members' events; the game's own roster keeps
-- a status of its own instead, because it may have refreshed the whole list between the moment of the event
-- and the moment it handles it. That is no reason for this add-on to keep a copy of every guild's roster: if
-- the events turn out to repeat a state, /pbosa status will show it ("same state" counts).
--
-- What is counted, and why it is here: nothing about this event has been measured on a console. The counters
-- (and the short log of the last events) are what tells, from one /pbosa status, how the game really behaves --
-- above all whether a login brings a burst of events (see "quiet" below).

local A, S = PBS_OSA, PBS_OSA_STRINGS
local em = EVENT_MANAGER

local EVENT_NAME = A.name .. "Status"
local DATA_EVENT_NAME = A.name .. "GuildData"
local BURST_WINDOW_MS = 60000 -- events inside this long after login are counted as the login burst
local RAW_LINES = 8

A.diag = {
	seen = 0, -- every status event of every guild
	unwatched = 0, -- of a guild that is not watched
	sameState = 0, -- online <-> away <-> do not disturb, or no change at all
	self = 0, -- the player's own
	kindOff = 0, -- an arrival or a departure whose alerts are switched off
	quiet = 0, -- inside the quiet time after login
	alerts = 0, -- turned into an alert
	burst = 0, -- events of watched guilds in the first minute after login
	dataLoaded = 0, -- EVENT_GUILD_DATA_LOADED seen
	raw = {}, -- the last events of watched guilds, newest last
}
local diag = A.diag

-- Ignore events until this time (ms); 0 = no quiet time running.
A.quietUntil = 0
A.loginAt = nil

-- Before the first EVENT_PLAYER_ACTIVATED the player is still in the loading screen: whatever the game reports
-- then is its roster being filled in, so it counts as quiet time too, whatever the setting says.
function A:InQuiet()
	return self.loginAt == nil or A.Now() < self.quietUntil
end

-- Starts (or extends) the quiet time. The settings say how long; 0 means none.
function A:StartQuiet()
	local ms = self.sv.quiet * 1000
	if ms <= 0 then
		return
	end
	local untilAt = A.Now() + ms
	if untilAt > self.quietUntil then
		self.quietUntil = untilAt
	end
end

local function StatusName(status)
	if PLAYER_STATUS_OFFLINE and status == PLAYER_STATUS_OFFLINE then
		return "offline"
	elseif PLAYER_STATUS_ONLINE and status == PLAYER_STATUS_ONLINE then
		return "online"
	elseif PLAYER_STATUS_AWAY and status == PLAYER_STATUS_AWAY then
		return "away"
	elseif PLAYER_STATUS_DO_NOT_DISTURB and status == PLAYER_STATUS_DO_NOT_DISTURB then
		return "dnd"
	end
	return tostring(status)
end

local function Remember(line)
	local raw = diag.raw
	raw[#raw + 1] = line
	while #raw > RAW_LINES do
		table.remove(raw, 1)
	end
end

-- The raw character name of a member, or nil: asked the way the game's roster asks.
local function RawCharacter(guildId, displayName)
	local index = GetGuildMemberIndexFromDisplayName(guildId, displayName)
	if not index then
		return nil
	end
	local hasCharacter, rawName = GetGuildMemberCharacterInfo(guildId, index)
	if hasCharacter then
		return rawName
	end
	return nil
end

function A:HandleStatus(guildId, displayName, oldStatus, newStatus)
	diag.seen = diag.seen + 1
	local sv = self.sv
	if not sv.enabled then
		return
	end
	if not self:IsWatched(guildId) then
		diag.unwatched = diag.unwatched + 1
		return
	end

	local now = A.Now()
	local sinceLogin = self.loginAt and (now - self.loginAt) or nil
	if sinceLogin and sinceLogin <= BURST_WINDOW_MS then
		diag.burst = diag.burst + 1
	end
	local slot = self:SlotOfGuild(guildId)
	Remember(string.format("%s guild %s: %s %s -> %s", sinceLogin and string.format("+%.1fs", sinceLogin / 1000) or "+?",
		tostring(slot or guildId), tostring(displayName), StatusName(oldStatus), StatusName(newStatus)))

	local wasOnline = oldStatus ~= PLAYER_STATUS_OFFLINE
	local isOnline = newStatus ~= PLAYER_STATUS_OFFLINE
	if wasOnline == isOnline then
		diag.sameState = diag.sameState + 1
		return
	end
	if A.IsSelf(displayName) then
		diag.self = diag.self + 1
		return
	end
	local kind = isOnline and "online" or "offline"
	if (isOnline and not sv.notifyOnline) or (not isOnline and not sv.notifyOffline) then
		diag.kindOff = diag.kindOff + 1
		return
	end

	local shown = A.UserName(displayName)
	local guildName = self:GuildName(guildId, slot)
	if self:InQuiet() then
		diag.quiet = diag.quiet + 1
		self:Note(S.logQuiet, shown)
		return
	end

	local ok, raw = pcall(RawCharacter, guildId, displayName)
	diag.alerts = diag.alerts + 1
	self:Note(isOnline and S.logOnline or S.logOffline, shown, guildName)
	self:Enqueue({
		kind = kind,
		name = shown,
		character = ok and A.CharacterName(raw) or nil,
		guilds = { guildName },
	})
end

local function OnStatusChanged(_, guildId, displayName, oldStatus, newStatus)
	A:HandleStatus(guildId, displayName, oldStatus, newStatus)
end

-- The guild data (the rosters) was loaded: the quiet time starts over from here.
local function OnGuildDataLoaded()
	diag.dataLoaded = diag.dataLoaded + 1
	A:StartQuiet()
end

-- Listens only while the alerts are on.
function A:ApplyListening()
	local on = self.sv.enabled
	if on and not self.listening then
		self.listening = true
		em:RegisterForEvent(EVENT_NAME, EVENT_GUILD_MEMBER_PLAYER_STATUS_CHANGED, self.Guard(OnStatusChanged))
		em:RegisterForEvent(DATA_EVENT_NAME, EVENT_GUILD_DATA_LOADED, self.Guard(OnGuildDataLoaded))
	elseif not on and self.listening then
		self.listening = false
		em:UnregisterForEvent(EVENT_NAME, EVENT_GUILD_MEMBER_PLAYER_STATUS_CHANGED)
		em:UnregisterForEvent(DATA_EVENT_NAME, EVENT_GUILD_DATA_LOADED)
	end
end

PBS_OSA_MARK("Watch")
