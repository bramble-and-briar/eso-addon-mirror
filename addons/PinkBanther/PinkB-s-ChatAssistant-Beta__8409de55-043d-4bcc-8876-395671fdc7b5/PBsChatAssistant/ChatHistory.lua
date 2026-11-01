-- Chat carried across /reloadui, character changes and logins.
--
-- The client builds its chat windows from nothing every time the UI loads, so whatever was being
-- said a moment ago is gone. This keeps the last messages in the saved variables, which the game
-- writes on every reload and logout, and plays them back once the chat windows exist again.
--
-- Recording listens to EVENT_CHAT_MESSAGE_CHANNEL itself and keeps the raw arguments, not the
-- formatted line. Playback hands those arguments back to CHAT_ROUTER under the same event key, so
-- each message goes through the client's own formatter (and the recruitment filter wrapped round
-- it), lands in whichever tabs carry its category -- guild tabs included -- and reaches the chat
-- menu's log as well as the HUD window. It is the same route d() takes, not a hook.
--
-- Played-back messages do not fire the event, so they are never recorded twice. They stay in the
-- history, which is what lets the next reload show them again alongside anything newer.
--
-- Account-wide, because the saved variables are: a character change carries guild chat over.

-- PBS_CHAT_ASSISTANT is nil if Main.lua bailed out early (the add-on was already loaded).
if not PBS_CHAT_ASSISTANT then
	return
end

local addon = PBS_CHAT_ASSISTANT
local em = EVENT_MANAGER

local history = {}
addon.chatHistory = history

local RECORD_EVENT = addon.name .. "History"
local RESTORE_EVENT = addon.name .. "HistoryRestore"

-- Hard bounds, whatever the saved settings say. The cap is what the saved-variables file and the
-- add-on's memory have to hold; a console chat message is at most a few hundred bytes.
history.MIN_COUNT = 10
history.MAX_COUNT = 200
history.MIN_MINUTES = 5
history.MAX_MINUTES = 720

-- The chat windows are built on the first EVENT_PLAYER_ACTIVATED by a handler the client
-- registered before any add-on, so they normally exist by the time ours runs. These retries only
-- cover a client that one day builds them later.
local RESTORE_RETRY_MS = 500
local RESTORE_MAX_ATTEMPTS = 20

-- NPC speech is not conversation, and on a busy street it would push everything else out.
local function SkippedChannels()
	local skipped = {}
	for _, channel in ipairs({ CHAT_CHANNEL_MONSTER_SAY, CHAT_CHANNEL_MONSTER_YELL,
		CHAT_CHANNEL_MONSTER_WHISPER, CHAT_CHANNEL_MONSTER_EMOTE }) do
		if channel then
			skipped[channel] = true
		end
	end
	return skipped
end
local SKIPPED = SkippedChannels()

local function Clamp(value, low, high, fallback)
	value = tonumber(value) or fallback
	if value < low then return low end
	if value > high then return high end
	return value
end

function history:MaxCount()
	return Clamp(addon.sv.historyCount, self.MIN_COUNT, self.MAX_COUNT, 50)
end

function history:MaxAgeSeconds()
	return Clamp(addon.sv.historyMinutes, self.MIN_MINUTES, self.MAX_MINUTES, 60) * 60
end

function history:Entries()
	local entries = addon.sv.chatHistory
	if type(entries) ~= "table" then
		entries = {}
		addon.sv.chatHistory = entries
	end
	return entries
end

-- Oldest first. Trimmed from the front, so the file never holds more than the cap.
function history:Trim()
	local entries = self:Entries()
	local excess = #entries - self:MaxCount()
	if excess > 0 then
		for _ = 1, excess do
			table.remove(entries, 1)
		end
	end
end

function history:Record(channel, fromName, text, isCustomerService, fromDisplayName)
	if not addon.sv.historyEnabled or SKIPPED[channel] or type(text) ~= "string" then
		return
	end
	local entries = self:Entries()
	entries[#entries + 1] = {
		t = GetTimeStamp(),
		c = channel,
		n = fromName,
		m = text,
		d = fromDisplayName,
		cs = isCustomerService and true or nil,
	}
	self:Trim()
end

-- What playback would show right now: inside the age limit, at most the cap, oldest first.
function history:Recent()
	local entries = self:Entries()
	local oldest = GetTimeStamp() - self:MaxAgeSeconds()
	local recent = {}
	for _, entry in ipairs(entries) do
		if type(entry) == "table" and tonumber(entry.t) and entry.t >= oldest
			and entry.c and type(entry.m) == "string" then
			recent[#recent + 1] = entry
		end
	end
	local excess = #recent - self:MaxCount()
	if excess > 0 then
		for _ = 1, excess do
			table.remove(recent, 1)
		end
	end
	return recent
end

local function ChatReady()
	local chat = type(ZO_GetChatSystem) == "function" and ZO_GetChatSystem()
	return chat and chat.primaryContainer and chat.loaded ~= false
end

function history:Restore()
	local recent = self:Recent()
	self.restored = 0
	if #recent == 0 then
		return 0
	end
	if type(CHAT_ROUTER) ~= "table" or type(CHAT_ROUTER.FormatAndAddChatMessage) ~= "function" then
		return 0
	end

	CHAT_ROUTER:AddSystemMessage(zo_strformat(GetString(SI_PBSCHATASSISTANT_HISTORY_BEGIN), #recent))
	for _, entry in ipairs(recent) do
		-- One bad entry must not take the rest with it.
		local ok = pcall(CHAT_ROUTER.FormatAndAddChatMessage, CHAT_ROUTER, EVENT_CHAT_MESSAGE_CHANNEL,
			entry.c, entry.n or "", entry.m, entry.cs == true, entry.d or "")
		if ok then
			self.restored = self.restored + 1
		end
	end
	CHAT_ROUTER:AddSystemMessage(GetString(SI_PBSCHATASSISTANT_HISTORY_END))
	return self.restored
end

function history:Clear()
	addon.sv.chatHistory = {}
end

function history:Install()
	em:RegisterForEvent(RECORD_EVENT, EVENT_CHAT_MESSAGE_CHANNEL,
		function(_, channel, fromName, text, isCustomerService, fromDisplayName)
			self:Record(channel, fromName, text, isCustomerService, fromDisplayName)
		end)

	-- Once per loaded copy of the add-on: a zone change rebuilds nothing, so it must not replay.
	em:RegisterForEvent(RESTORE_EVENT, EVENT_PLAYER_ACTIVATED, function()
		em:UnregisterForEvent(RESTORE_EVENT, EVENT_PLAYER_ACTIVATED)
		if not addon.sv.historyEnabled then
			return
		end
		local attempts = 0
		local function TryRestore()
			attempts = attempts + 1
			if ChatReady() then
				self:Restore()
			elseif attempts < RESTORE_MAX_ATTEMPTS then
				zo_callLater(TryRestore, RESTORE_RETRY_MS)
			end
		end
		TryRestore()
	end)
end
