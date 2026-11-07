local A, S = PBS_RETICLE, PBS_RETICLE_STRINGS
local em = EVENT_MANAGER

local NATIVE = "ZO_ReticleContainerReticle"
local DEMO_MS = 12000

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
-- What is under the reticle
-- ---------------------------------------------------------------------------------------

-- The game's own questions, the ones its reticle asks every frame. Returns the kind of target (see
-- A.LOOKS) and whether anything is going on (a target, something to use, or a fight).
function A.ReadWorld()
	local exists = DoesUnitExist("reticleover")
	local attackable = IsGameCameraUnitHighlightedAttackable()
	local interact = GetGameCameraInteractableInfo()
	local reaction, dead
	if exists then
		reaction = GetUnitReaction("reticleover")
		dead = IsUnitDead("reticleover")
	end
	local kind = A.ClassifyTarget(exists, attackable, interact, reaction, dead)
	return kind, kind ~= "none" or IsUnitInCombat("player")
end

-- ---------------------------------------------------------------------------------------
-- The game's own reticle
--
-- It is one 64-pixel texture whose colour and picture the game animates (opening over a target, a red
-- flash on an impactful hit), and whose hidden flag it sets itself when you sneak or put on a disguise.
-- So it is made see-through with the control's own alpha, which nothing in the game ever touches, and its
-- hidden flag is read as the answer to "is the game showing its stealth eye": ours fades out then too.
-- The game's interact text, which hangs on the same container, is not touched.
-- ---------------------------------------------------------------------------------------

function A:FindNative()
	if not self.native then
		self.native = _G[NATIVE] or (GetControl and GetControl(NATIVE)) or nil
	end
	return self.native
end

function A:HideNative(hide)
	local native = self:FindNative()
	if native then
		native:SetAlpha(hide and 0 or 1)
	end
	self.nativeHidden = hide and native ~= nil
end

function A:CreateLive()
	local container = _G.ZO_ReticleContainer
	if not container then
		return
	end
	local native = self:FindNative()
	local live = A.NewReticle("PBsReticleLive", container, container, 0, DL_CONTROLS, 0)
	if native then
		live.mirror = function()
			return native:IsHidden()
		end
	end
	live.onFail = function(reticle)
		self:OnLiveFailure(reticle)
	end
	self.live = live
	self.container = container
end

-- Never leave the player without a reticle.
function A:OnLiveFailure(reticle)
	reticle.root:SetHidden(true)
	self:HideNative(false)
	self:Print(S.failed, tostring(reticle.lastError))
end

-- ---------------------------------------------------------------------------------------
-- Hits
-- ---------------------------------------------------------------------------------------

-- Direct damage by the player is a hit, a critical is a crit, the killing blow is a kill. Damage over time is
-- left out on purpose: a tick every second would keep the marker flickering.
local HIT_KIND = {}
for name, kind in pairs({
	ACTION_RESULT_DAMAGE = "hit",
	ACTION_RESULT_PRECISE_DAMAGE = "hit",
	ACTION_RESULT_WRECKING_DAMAGE = "hit",
	ACTION_RESULT_BLOCKED_DAMAGE = "hit",
	ACTION_RESULT_DAMAGE_SHIELDED = "hit",
	ACTION_RESULT_CRITICAL_DAMAGE = "crit",
	ACTION_RESULT_KILLING_BLOW = "kill",
	ACTION_RESULT_DIED_XP = "kill",
}) do
	local value = _G[name]
	if value then
		HIT_KIND[value] = kind
	end
end
A.HIT_KIND = HIT_KIND

A.stats = { seen = 0, hit = 0, crit = 0, kill = 0, byResult = {} }

function A:OnCombat(result, isError, sourceType, targetType, hitValue)
	local stats = self.stats
	stats.seen = stats.seen + 1
	stats.byResult[result] = (stats.byResult[result] or 0) + 1
	if isError or sourceType ~= COMBAT_UNIT_TYPE_PLAYER or targetType == COMBAT_UNIT_TYPE_PLAYER then
		return
	end
	local kind = HIT_KIND[result]
	if not kind then
		return
	end
	if kind ~= "kill" and (hitValue or 0) <= 0 then
		return
	end
	stats[kind] = stats[kind] + 1
	local live = self.live
	if live and not live.failed then
		live:Hit(kind, GetFrameTimeSeconds())
	end
end

-- Only listening while hit markers are on: in a raid this event is the busiest one there is. The game
-- filters it to the player's own hits before it reaches us.
function A:RegisterHits()
	local name = self.name .. "Hit"
	em:UnregisterForEvent(name, EVENT_COMBAT_EVENT)
	if not (self.sv.enabled and self.sv.hit and self.live) then
		return
	end
	em:RegisterForEvent(name, EVENT_COMBAT_EVENT,
		function(_, result, isError, _, _, _, _, sourceType, _, targetType, hitValue)
			self:OnCombat(result, isError, sourceType, targetType, hitValue)
		end)
	em:AddFilterForEvent(name, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
	em:AddFilterForEvent(name, EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, false)
end

-- ---------------------------------------------------------------------------------------
-- Applying the settings
-- ---------------------------------------------------------------------------------------

function A:Apply()
	local sv, live = self.sv, self.live
	if live then
		local on = sv.enabled and not live.failed
		live.root:SetHidden(not on)
		if on then
			live:Layout()
		end
		self:HideNative(on)
	end
	if self.preview then
		self.preview:Layout()
	end
	self:RegisterHits()
	self:RefreshPreview()
end

-- The sample states for twelve seconds in the HUD, for someone with nothing to look at.
function A:StartDemo()
	local live = self.live
	if not live or live.failed then
		return false
	end
	live:SetSource(A.MakeDemo())
	em:UnregisterForUpdate(self.name .. "DemoEnd")
	em:RegisterForUpdate(self.name .. "DemoEnd", DEMO_MS, function()
		em:UnregisterForUpdate(self.name .. "DemoEnd")
		live:SetSource(nil)
	end)
	return true
end

-- ---------------------------------------------------------------------------------------
-- /pbreticle status: what the add-on reads from the game
-- ---------------------------------------------------------------------------------------

function A:StatusLines()
	local lines = {}
	local function add(text, ...)
		lines[#lines + 1] = select("#", ...) > 0 and string.format(text, ...) or text
	end
	local sv, live = self.sv, self.live

	add("%s", self.title)
	local native = self:FindNative()
	add("game reticle container: %s; its reticle texture: %s%s", self.container and "found" or "NOT FOUND",
		native and "found" or "NOT FOUND",
		native and string.format(", alpha %s, hidden by the game (stealth or disguise) %s", tostring(native:GetAlpha()),
			tostring(native:IsHidden())) or "")
	if live then
		add("live reticle: %s%s; on screen now: %s", sv.enabled and "on" or "off", live.failed and " (STOPPED after errors)" or "",
			live.root:IsControlHidden() and "no (the game's reticle is hidden: menu, loading)" or "yes")
		add("  target: %s; pose %.2f (to %.2f); colour %.2f %.2f %.2f; opacity %.2f (to %.2f)", live.kind, live.pose, live.poseT,
			live.rgb[1], live.rgb[2], live.rgb[3], live.alpha, live.alphaT)
		add("  frames %d, game reads %d, moves %d (the last two stop while nothing changes)%s", live.frames, live.polls, live.steps,
			live.lastError and ("; last error: " .. live.lastError) or "")
	else
		add("live reticle: not created (the game's container was not found), so the game's own reticle is untouched")
	end
	-- the one place that asks the game outside the update: a broken question must not break the report
	local read, reads = pcall(function()
		local exists = DoesUnitExist("reticleover")
		return string.format("target %s, attackable %s, usable %s, reaction %s, dead %s, in combat %s", tostring(exists),
			tostring(IsGameCameraUnitHighlightedAttackable()), tostring(GetGameCameraInteractableInfo()),
			exists and tostring(GetUnitReaction("reticleover")) or "-", exists and tostring(IsUnitDead("reticleover")) or "-",
			tostring(IsUnitInCombat("player")))
	end)
	add("reads now: %s", read and reads or ("failed: " .. tostring(reads)))
	local stats = self.stats
	add("hit markers: %s; your combat events seen %d; shown: hit %d, crit %d, kill %d", sv.hit and "on" or "off", stats.seen, stats.hit,
		stats.crit, stats.kill)
	local results = {}
	for result, count in pairs(stats.byResult) do
		results[#results + 1] = { result = result, count = count }
	end
	table.sort(results, function(a, b)
		return a.count > b.count or (a.count == b.count and a.result < b.result)
	end)
	local parts = {}
	for i = 1, math.min(8, #results) do
		parts[i] = string.format("%s=%d%s", tostring(results[i].result), results[i].count,
			HIT_KIND[results[i].result] and ("(" .. HIT_KIND[results[i].result] .. ")") or "")
	end
	add("  result codes seen (code=count, (kind) if it makes a marker): %s", #parts > 0 and table.concat(parts, " ") or "none yet")
	return lines
end

-- ---------------------------------------------------------------------------------------
-- /pbreticle
-- ---------------------------------------------------------------------------------------

local NUMBERS = { size = "size", gap = "gap", outline = "outline", opacity = "opacity", idle = "idle" }
local SWITCHES = { dot = "dot", auto = "auto", hit = "hit", anim = "anim", preview = "preview" }
local CHOICES = { style = A.STYLES, color = A.COLOR_NAMES, weight = A.WEIGHTS }

local function contains(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

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
		if self:StartDemo() then
			self:Print(S.testOn)
		else
			self:Print(S.testOff)
		end
	elseif NUMBERS[command] and number then
		self:Set(NUMBERS[command], number)
	elseif SWITCHES[command] and (arg == "on" or arg == "off") then
		self:Set(SWITCHES[command], arg == "on")
	elseif CHOICES[command] and contains(CHOICES[command], arg) then
		self:Set(command, arg)
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

	A.sv = ZO_SavedVars:NewAccountWide("PBsReticle_Data", 1, nil, A.defaults)
	A:Sanitize()
	A:CreateLive()
	A:CreatePreview()
	A:Apply()
	A:InitSettings()

	local function command(input)
		A:Command(input)
	end
	SLASH_COMMANDS[A.slash] = command
	SLASH_COMMANDS[A.shortSlash] = command

	local bannerShown = false
	em:RegisterForEvent(A.name, EVENT_PLAYER_ACTIVATED, function()
		A.active = true
		-- the game builds its reticle again when it is activated; make sure it is still see-through
		if A.live and A.sv.enabled and not A.live.failed then
			A:HideNative(true)
		end
		A:RefreshPreview()
		if not bannerShown then
			bannerShown = true
			A:Print(S.bannerLine, A.title)
		end
	end)
	em:RegisterForEvent(A.name, EVENT_PLAYER_DEACTIVATED, function()
		A.active = false
		A:SetPanelOpen(false)
	end)
end

em:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, OnLoaded)
