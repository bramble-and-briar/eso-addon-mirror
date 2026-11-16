-- PB's Online Status Alert
-- Author: PinkBanther
--
-- Shows a banner at the top right of the screen when a member of a guild the player picked comes online or goes
-- offline: who it is, and which guild.
--
-- ---------------------------------------------------------------------------------------
-- WHERE THE INFORMATION COMES FROM
-- ---------------------------------------------------------------------------------------
--
-- EVENT_GUILD_MEMBER_PLAYER_STATUS_CHANGED (guildId, displayName, oldStatus, newStatus). It is the event the
-- game's own guild roster listens to (esoui ingame/guild/guildroster_shared.lua), so the roster on a console
-- is fed by it. A member is "online" while the status is not PLAYER_STATUS_OFFLINE: online, away and
-- do-not-disturb all count, so going from online to away is not an arrival and not a departure.
--
-- The guild of an event is a guildId; the picked guilds are stored by guildId, not by the slot (1-5) the guild
-- has in the player's list, so a changed order of the guilds does not change which ones are watched.
--
-- ---------------------------------------------------------------------------------------
-- WHAT IS NOT KNOWN YET (nothing here has been run on a console)
-- ---------------------------------------------------------------------------------------
--
-- * Whether the game sends one such event per member as the guild roster loads at login. If it does, every
--   member who is already online would read as "came online". The add-on stays quiet for a few seconds after
--   login (the "quiet" setting) and /pbosa status counts what arrived inside that time, so the first real
--   login answers it.
-- * Whether the character name is there at the moment of the event. It is asked for with
--   GetGuildMemberCharacterInfo, the way the game's roster does it, and left out when it is not.
--
-- ---------------------------------------------------------------------------------------
-- TEXT
--
-- Names and guild names reach the screen untouched. Nothing here runs a Lua character class (%s %c %a ...) or
-- lower()/upper() over them: those ask the C library, which answers by the process's locale, and in a
-- non-"C" locale the bytes inside Japanese UTF-8 can be taken for control characters or blanks. Commands are
-- the only text that is read, and they are cut at ASCII blanks and lowered one ASCII letter at a time.
-- ---------------------------------------------------------------------------------------

PBS_OSA = {
	name = "PBsOnlineStatusAlert",
	baseTitle = "PB’s Online Status Alert",
	chatName = "PB’s Online Status Alert",
	author = "PinkBanther",
	version = "0.1.0",
	slash = "/pbosa",
	longSlash = "/pbonlinestatusalert",
	savedVar = "PBsOnlineStatusAlert_Data",
	MAX_GUILDS = 5,
	-- The banner sizes. Fonts are the named gamepad faces the console UI already has loaded (a face nothing else
	-- uses has to be built on use, and that crashed a PS5 once); on a Japanese client the same names come out
	-- smaller. w/h are the banner's size, padX the room left of the text, the rest are the two lines.
	SIZES = {
		{ title = "ZoFontGamepadBold22", detail = "ZoFontGamepad18", w = 500, h = 70, padX = 22, padY = 8, titleH = 30, detailH = 24 },
		{ title = "ZoFontGamepadBold27", detail = "ZoFontGamepad22", w = 580, h = 88, padX = 24, padY = 10, titleH = 36, detailH = 30 },
		{ title = "ZoFontGamepadBold34", detail = "ZoFontGamepad27", w = 700, h = 108, padX = 28, padY = 12, titleH = 44, detailH = 36 },
	},
	LIMITS = {
		duration = { 2, 10 },
		size = { 1, 3 },
		posX = { 0, 900 },
		posY = { 0, 700 },
		quiet = { 0, 60 },
	},
	defaults = {
		enabled = true,
		notifyOnline = true,
		notifyOffline = true,
		showGuildName = true,
		showCharacter = true,
		sound = false, -- not asked for, so off
		duration = 4, -- seconds a banner stays
		size = 2,
		posX = 40, -- from the right edge
		posY = 40, -- from the top
		quiet = 10, -- seconds after login in which events are ignored
		watch = {}, -- ["<guildId>"] = true for each watched guild. None until the player picks them.
	},
}
local A = PBS_OSA
local S = PBS_OSA_STRINGS

-- The version comes from the manifest, the same way PB's other add-ons read it.
do
	local manager = GetAddOnManager and GetAddOnManager()
	if manager then
		for index = 1, manager:GetNumAddOns() do
			local name, title = manager:GetAddOnInfo(index)
			if name == A.name and title then
				local plain = title:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[ \t\r\n]+$", "")
				A.version = plain:match("(%d+[%d%.]*)$") or A.version
				break
			end
		end
	end
end
A.title = A.baseTitle .. " " .. A.version

function A.Now()
	return GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
end

A.errors = 0
A.lastError = nil

-- A handler that cannot raise: an error in an event handler would reach the game as an error screen.
function A.Guard(fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			A.errors = A.errors + 1
			A.lastError = tostring(err)
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- Commands are the only text that is read
-- ---------------------------------------------------------------------------------------

function A.LowerAscii(text)
	return (tostring(text or ""):gsub("[A-Z]", function(c)
		return string.char(c:byte() + 32)
	end))
end

local function IsAsciiBlank(b)
	return b == 32 or (b >= 9 and b <= 13)
end

function A.SplitWords(input)
	input = tostring(input or "")
	local words, from = {}, nil
	for i = 1, #input + 1 do
		local b = input:byte(i)
		if b == nil or IsAsciiBlank(b) then
			if from then
				words[#words + 1] = input:sub(from, i - 1)
				from = nil
			end
		elseif not from then
			from = i
		end
	end
	return words
end

-- ---------------------------------------------------------------------------------------
-- Saved settings
-- ---------------------------------------------------------------------------------------

local function Clamp(value, limits, default)
	value = tonumber(value)
	if not value or value ~= value then
		return default
	end
	value = math.floor(value + 0.5)
	if value < limits[1] then
		return limits[1]
	elseif value > limits[2] then
		return limits[2]
	end
	return value
end

-- Whatever is in the saved file (an older version, a hand edit) is brought back into range.
function A:Sanitize()
	local sv, defaults = self.sv, self.defaults
	for _, key in ipairs({ "enabled", "notifyOnline", "notifyOffline", "showGuildName", "showCharacter", "sound" }) do
		if type(sv[key]) ~= "boolean" then
			sv[key] = defaults[key]
		end
	end
	for key, limits in pairs(self.LIMITS) do
		sv[key] = Clamp(sv[key], limits, defaults[key])
	end
	if type(sv.watch) ~= "table" then
		sv.watch = {}
	end
	for key, value in pairs(sv.watch) do
		if value ~= true or type(key) ~= "string" then
			sv.watch[key] = nil
		end
	end
end

function A:Set(key, value)
	local limits = self.LIMITS[key]
	if limits then
		value = Clamp(value, limits, self.defaults[key])
	end
	self.sv[key] = value
end

-- ---------------------------------------------------------------------------------------
-- Guilds
-- ---------------------------------------------------------------------------------------

local function GuildKey(guildId)
	return string.format("%d", guildId)
end

-- The guildId in slot i (1-5) of the player's guild list, or nil when there is no guild in it.
function A:GuildIdAt(i)
	if not (GetNumGuilds and GetGuildId) then
		return nil
	end
	if i < 1 or i > GetNumGuilds() then
		return nil
	end
	local id = GetGuildId(i)
	if type(id) ~= "number" or id == 0 then
		return nil
	end
	return id
end

-- The guild's name, or a stand-in while the game has not loaded it (index is only used for that).
function A:GuildName(guildId, index)
	local name = GetGuildName and GetGuildName(guildId)
	if type(name) == "string" and name ~= "" then
		return name
	end
	return string.format(S.guildFallback, index or 0)
end

function A:IsWatched(guildId)
	return type(guildId) == "number" and self.sv.watch[GuildKey(guildId)] == true
end

function A:SetWatched(guildId, watched)
	if type(guildId) ~= "number" then
		return
	end
	self.sv.watch[GuildKey(guildId)] = watched and true or nil
end

-- The slot (1-5) of a guildId in the guild list, or nil.
function A:SlotOfGuild(guildId)
	for i = 1, self.MAX_GUILDS do
		if self:GuildIdAt(i) == guildId then
			return i
		end
	end
	return nil
end

-- The names of the guilds that are watched and that the player is still in, in slot order.
function A:WatchedNames()
	local names = {}
	for i = 1, self.MAX_GUILDS do
		local id = self:GuildIdAt(i)
		if id and self:IsWatched(id) then
			names[#names + 1] = self:GuildName(id, i)
		end
	end
	return names
end

-- ---------------------------------------------------------------------------------------
-- Names, the way the game shows them
-- ---------------------------------------------------------------------------------------

-- The account name as the player sees it: on a console without the leading "@" (the client's own helper).
function A.UserName(displayName)
	displayName = tostring(displayName or "")
	if ZO_FormatUserFacingDisplayName then
		local ok, shown = pcall(ZO_FormatUserFacingDisplayName, displayName)
		if ok and type(shown) == "string" and shown ~= "" then
			return shown
		end
	end
	return displayName
end

-- A character name as the game shows it: the raw name carries a gender suffix after a "^".
function A.CharacterName(raw)
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	local text = raw
	if zo_strformat and SI_UNIT_NAME then
		local ok, formatted = pcall(zo_strformat, SI_UNIT_NAME, raw)
		if ok and type(formatted) == "string" then
			text = formatted
		end
	end
	local cut = text:find("^", 1, true) -- a plain, byte-wise search
	if cut then
		text = text:sub(1, cut - 1)
	end
	if text == "" then
		return nil
	end
	return text
end

-- Is this account the player's own?
function A.IsSelf(displayName)
	local own = GetDisplayName and GetDisplayName()
	if type(own) ~= "string" or own == "" then
		return false
	end
	return displayName == own or A.UserName(displayName) == A.UserName(own)
end

PBS_OSA_MARK("Core")
