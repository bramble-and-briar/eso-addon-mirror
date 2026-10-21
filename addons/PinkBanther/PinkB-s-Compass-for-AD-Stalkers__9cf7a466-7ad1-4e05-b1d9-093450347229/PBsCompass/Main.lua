local A, S = PBS_COMPASS, PBS_COMPASS_STRINGS
local em = EVENT_MANAGER

-- ---------------------------------------------------------------------------------------
-- Output
--
-- A message printed at EVENT_ADD_ON_LOADED is thrown away because chat is not up yet, so anything
-- user-facing is either a command response or fires on EVENT_PLAYER_ACTIVATED.
-- ---------------------------------------------------------------------------------------

function A:Say(text)
	if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
		CHAT_ROUTER:AddSystemMessage(text)
	elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
		CHAT_SYSTEM:AddMessage(text)
	else
		d(text)
	end
end

local PREFIX = "|cFF69B4" .. A.chatName .. "|r: "

function A:Print(text, ...)
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		self:Say(PREFIX .. (ok and formatted or text))
	else
		self:Say(PREFIX .. text)
	end
end

-- ---------------------------------------------------------------------------------------
-- Who may use it
-- ---------------------------------------------------------------------------------------

-- Compared the way player names are everywhere else: case, a leading @ and a gender suffix do not
-- matter.
local ALLOWED_USERS = {
	["so1-wylde"] = true,
	["pinkbanther"] = true,
}

-- Shown in Japanese whatever the client language is: the wording was asked for exactly.
local DENIED_MESSAGE = "あなたはこのアドオンを使用できません"

-- The console ID of the logged-in player (the PSN online ID). An empty answer is "unknown", which is
-- not on the list.
local function PlatformId()
	return GetPlatformDisplayName and GetPlatformDisplayName() or ""
end
A.PlatformId = PlatformId

function A.IsAllowedUser()
	return ALLOWED_USERS[A.NameKey(PlatformId())] == true
end

-- Everyone else: the message once after login and again whenever the command is tried. The command
-- also says which ID was read, so the owner can tell a refused stranger from a mis-read ID.
function A:RefuseToRun()
	self.denied = true
	local function handler()
		self:Print(DENIED_MESSAGE)
		self:Say("PSN ID: " .. tostring(PlatformId()))
	end
	SLASH_COMMANDS[self.slash] = handler
	SLASH_COMMANDS[self.shortSlash] = handler

	local told = false
	em:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, function()
		if not told then
			told = true
			self:Print(DENIED_MESSAGE)
		end
	end)
end

-- ---------------------------------------------------------------------------------------
-- /pbcompass status: what the add-on reads from the game
-- ---------------------------------------------------------------------------------------

local function Metres(centimetres)
	return string.format("%.1f m", centimetres / 100)
end

function A:StatusLines()
	local lines = {}
	local function add(text, ...)
		lines[#lines + 1] = select("#", ...) > 0 and string.format(text, ...) or text
	end
	local diag, world, cal = self.diag, self.world, self.cal

	add("%s", self.title)
	add("PSN ID: %s (allowed)", tostring(A.PlatformId()))

	local heading = self:ReadHeading()
	if heading then
		add("camera heading: %d° = looking %s (0 = north, 90 = west)", math.floor(math.deg(heading) + 0.5) % 360, A.HeadingWord(heading))
	else
		add("camera heading: unavailable")
	end

	-- Asking for the player's own position is the one-shot measurement of the world position call,
	-- for someone who is not in a group.
	local zone, x, z = self:WorldOf("player")
	if zone then
		add("player: zone %d, east %s, south %s", zone, Metres(x), Metres(z))
	else
		add("player: no world position")
	end
	add("world position call: %s (the game says: %s)", world.why, tostring(world.asked or "not asked"))
	if self.lastCrash then
		add("a call failed on an earlier login: %s (/pbcompass retry forgets it)", tostring(self.lastCrash))
	end

	self:RefreshRoster()
	self:Locate()
	add("group: %d in the game's group, %d shown, %d left out (offline, other zone or instance)", GetGroupSize(), #self.roster, diag.skipped)
	add("placed by: world %d, map %d, direction only %d", diag.world, diag.map, diag.direction)
	for _, entry in ipairs(self.located) do
		add("  %s  %s  east %.1f m, south %.1f m%s", entry.member.name, entry.source, entry.dx, entry.dz,
			entry.distance and "" or " (direction only)")
	end
	add("map scale: %s; axis check: %d agree, %d disagree", cal.scale and string.format("%.0f cm per map unit", cal.scale) or "not measured",
		diag.axisAgree, diag.axisDisagree)
	add("updates: %d%s", diag.ticks, diag.lastError and ("; last error: " .. diag.lastError) or "")
	return lines
end

-- ---------------------------------------------------------------------------------------
-- /pbcompass
-- ---------------------------------------------------------------------------------------

local NUMBERS = { radius = "radius", range = "range", opacity = "opacity", x = "x", y = "y", size = "markerSize" }
local SWITCHES = { names = "names", ring = "ring" }

function A:Command(input)
	local command, arg = string.lower(input or ""):match("^%s*(%S*)%s*(.-)%s*$")
	local number = tonumber(arg)
	if command == "on" or command == "off" then
		self:Set("enabled", command == "on")
	elseif command == "reset" then
		self:Reset()
	elseif command == "status" then
		for _, line in ipairs(self:StatusLines()) do
			self:Say(line)
		end
	elseif command == "test" then
		self:StartDemo()
		self:Print(S.testOn)
	elseif command == "retry" then
		self.sv.probe = {}
		self.lastCrash = nil
		self.world = { checked = false, usable = false, why = "not checked yet" }
		self:Print(S.retried)
	elseif NUMBERS[command] and number then
		self:Set(NUMBERS[command], number)
	elseif SWITCHES[command] and (arg == "on" or arg == "off") then
		self:Set(SWITCHES[command], arg == "on")
	elseif command == "letters" and (arg == "small" or arg == "medium" or arg == "large") then
		self:Set("letterSize", arg)
	elseif command == "rotate" and (arg == "camera" or arg == "north") then
		self:Set("rotate", arg)
	else
		self:Say(S.help)
		return
	end
	if self.panel and self.panel.UpdateControls then
		self.panel:UpdateControls()
	end
end

-- ---------------------------------------------------------------------------------------
-- Start-up
-- ---------------------------------------------------------------------------------------

local function OnLoaded(_, name)
	if name ~= A.name then
		return
	end
	em:UnregisterForEvent(A.name, EVENT_ADD_ON_LOADED)

	-- Nothing below this check runs for anyone who is not on the list: no saved variables, no
	-- commands, no panel, no events.
	if not A.IsAllowedUser() then
		A:RefuseToRun()
		return
	end

	A.sv = ZO_SavedVars:NewAccountWide("PBsCompass_Data", 1, nil, A.defaults)
	A:Sanitize()
	A:CreateUI()
	A:ApplyLayout()
	A:InitSettings()

	local function command(input)
		A:Command(input)
	end
	SLASH_COMMANDS[A.slash] = command
	SLASH_COMMANDS[A.shortSlash] = command

	local function refresh()
		A:RefreshVisibility()
	end
	HUD_SCENE:RegisterCallback("StateChange", refresh)
	HUD_UI_SCENE:RegisterCallback("StateChange", refresh)

	local bannerShown = false
	em:RegisterForEvent(A.name, EVENT_PLAYER_ACTIVATED, function()
		A.active = true
		A:MarkRosterStale()
		A:ApplyLayout()
		refresh()
		if not bannerShown then
			bannerShown = true
			A:Print(S.bannerLine, A.title)
		end
	end)
	em:RegisterForEvent(A.name, EVENT_PLAYER_DEACTIVATED, function()
		A.active = false
		A:SetPanelOpen(false)
		refresh()
	end)
	em:RegisterForEvent(A.name, EVENT_SCREEN_RESIZED, function()
		A:ApplyLayout()
	end)

	-- The group changed: read it again at the next update instead of waiting out the interval.
	local function stale()
		A:MarkRosterStale()
	end
	em:RegisterForEvent(A.name .. "GroupUpdate", EVENT_GROUP_UPDATE, stale)
	em:RegisterForEvent(A.name .. "GroupJoined", EVENT_GROUP_MEMBER_JOINED, stale)
	em:RegisterForEvent(A.name .. "GroupLeft", EVENT_GROUP_MEMBER_LEFT, stale)
	em:RegisterForEvent(A.name .. "GroupStatus", EVENT_GROUP_MEMBER_CONNECTED_STATUS, stale)
	em:RegisterForEvent(A.name .. "Leader", EVENT_LEADER_UPDATE, stale)
end

em:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, OnLoaded)
