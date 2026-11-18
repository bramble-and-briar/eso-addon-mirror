-- The banner: a queue of alerts, and one banner on screen that slides in from the right edge, stays, and slides
-- out. The window itself is in PBsOnlineStatusAlert.xml.
--
-- ---------------------------------------------------------------------------------------
-- WHEN A BANNER IS ON SCREEN
-- ---------------------------------------------------------------------------------------
--
-- The window belongs to a scene fragment that sits in the HUD scenes (HUD_SCENE and HUD_UI_SCENE), the way PB's
-- KillLog and PB's TargetPlayer put their windows there, so it is on the game screen and nowhere else. While
-- the game screen is not showing (a menu, the map, a loading screen) nothing starts and nothing advances: the
-- banner that was half way waits where it was, and the alerts that arrive queue up. A banner is not played
-- behind a menu where nobody sees it. An alert older than two minutes is dropped instead of shown (it would
-- announce something that stopped being true long ago); the count of those is in /pbosa status.
--
-- The animation is driven by a RegisterForUpdate that exists only while there is something to animate and the
-- game screen is up: nothing runs per frame when idle.
--
-- The same member reported by several of the watched guilds (one event per guild) is one banner that lists all
-- of the guilds, not one banner per guild.
--
-- ---------------------------------------------------------------------------------------
-- THE PREVIEW
-- ---------------------------------------------------------------------------------------
--
-- While the add-on's settings panel is open a sample banner is shown, still, at the place the alerts will
-- appear, and it follows the position, size and text options as they are changed (Settings.lua says when the
-- panel is open). The window is shown by hand then; the fragment owns it the rest of the time.

local A, S = PBS_OSA, PBS_OSA_STRINGS
local em = EVENT_MANAGER

local WINDOW_NAME = "PBsOnlineStatusAlertWindow"
local TICK_NAME = A.name .. "Tick"
local TICK_MS = 25
local SLIDE_IN_MS = 280
local SLIDE_OUT_MS = 260
local GAP_MS = 150 -- between two banners
local MAX_STEP_MS = 250 -- one hitch must not skip a whole slide
local EXPIRE_MS = 120000 -- an alert waiting longer than this is dropped
local MERGE_MS = 3000 -- the same member reported again within this time is the same alert
local QUEUE_MAX = 30
local BACKLOG_FAST = 3 -- this many alerts waiting: banners stay shorter
local FAST_HOLD_MS = 1500
local ACCENT_W = 8

local COLORS = {
	online = { 0.40, 0.86, 0.52 },
	offline = { 0.92, 0.46, 0.42 },
}
local SOUND_NAMES = { online = "NEW_NOTIFICATION", offline = "DEFER_NOTIFICATION" }

local alert = {
	queue = {}, -- alerts waiting, oldest first
	recent = {}, -- kind|name -> the alert made for it lately (to merge a second guild into it)
	current = nil, -- the alert on screen
	phase = "idle", -- idle | in | hold | out | gap
	elapsed = 0, -- ms spent in the phase
	hud = false, -- the game screen is showing
	preview = false, -- the sample is up
	ticking = false,
	lastTick = 0,
	-- counted for /pbosa status
	shown = 0,
	merged = 0,
	expired = 0,
	dropped = 0,
}
A.alert = alert

-- ---------------------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------------------

local function Controls()
	if alert.window then
		return alert.window
	end
	local window = _G[WINDOW_NAME]
	if not window then
		return nil
	end
	alert.window = window
	alert.back = window:GetNamedChild("Background")
	alert.accent = window:GetNamedChild("Accent")
	alert.title = window:GetNamedChild("Title")
	alert.detail = window:GetNamedChild("Detail")
	return window
end

local function ContentHidden(hidden)
	if not Controls() then
		return
	end
	alert.back:SetHidden(hidden)
	alert.accent:SetHidden(hidden)
	alert.title:SetHidden(hidden)
	alert.detail:SetHidden(hidden)
end

local function Size()
	return A.SIZES[A.sv.size] or A.SIZES[2]
end

-- How far right of its place the banner starts (and ends): out of the screen.
local function Travel()
	return Size().w + A.sv.posX + 30
end

-- Slide is how far to the right of its place the banner is (0 = at its place); alpha is its opacity.
local function Place(slide, alpha)
	local window = Controls()
	if not window then
		return
	end
	window:ClearAnchors()
	window:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -A.sv.posX + slide, A.sv.posY)
	window:SetAlpha(alpha)
end

local function Ease(t)
	if t < 0 then
		return 0
	elseif t > 1 then
		return 1
	end
	return 1 - (1 - t) * (1 - t) * (1 - t)
end

-- What the banner looks like in the phase it is in.
local function PhaseVisual()
	local phase, t = alert.phase, 1
	if phase == "in" then
		t = alert.elapsed / SLIDE_IN_MS
		local e = Ease(t)
		Place(Travel() * (1 - e), e)
	elseif phase == "out" then
		t = alert.elapsed / SLIDE_OUT_MS
		local e = Ease(t)
		Place(Travel() * e, 1 - e)
	else
		Place(0, 1)
	end
end

-- Size, fonts and the position of everything in the window, from the settings.
function A:ApplyLayout()
	local window = Controls()
	if not window then
		return false
	end
	local sz = Size()
	window:SetDimensions(sz.w, sz.h)
	alert.accent:SetDimensions(ACCENT_W, sz.h)
	alert.accent:ClearAnchors()
	alert.accent:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
	alert.title:SetFont(sz.title)
	alert.title:SetDimensions(sz.w - sz.padX - 16, sz.titleH)
	alert.title:ClearAnchors()
	alert.title:SetAnchor(TOPLEFT, window, TOPLEFT, sz.padX, sz.padY)
	alert.detail:SetFont(sz.detail)
	alert.detail:SetDimensions(sz.w - sz.padX - 16, sz.detailH)
	alert.detail:ClearAnchors()
	alert.detail:SetAnchor(TOPLEFT, window, TOPLEFT, sz.padX, sz.padY + sz.titleH + 2)
	if alert.preview then
		Place(0, 1)
	else
		PhaseVisual()
	end
	return true
end

-- ---------------------------------------------------------------------------------------
-- What a banner says
-- ---------------------------------------------------------------------------------------

function A:Compose(entry)
	local sv = self.sv
	local title = entry.name or ""
	if sv.showCharacter and entry.character and entry.character ~= "" then
		title = string.format(S.titleWithCharacter, title, entry.character)
	end
	local detail = entry.kind == "online" and S.kindOnline or S.kindOffline
	if sv.showGuildName and entry.guilds and #entry.guilds > 0 then
		detail = string.format(S.detailJoin, detail, table.concat(entry.guilds, S.guildJoin))
	end
	return title, detail, COLORS[entry.kind] or COLORS.online
end

local function Render(entry)
	if not Controls() then
		return
	end
	local title, detail, color = A:Compose(entry)
	alert.title:SetText(title)
	alert.detail:SetText(detail)
	alert.accent:SetColor(color[1], color[2], color[3], 1)
	alert.detail:SetColor(color[1], color[2], color[3], 1)
end

local function PlaySoundFor(kind)
	if not A.sv.sound then
		return
	end
	-- the form that is proven on a console: look the id up, and play it only when it is there
	local id = SOUNDS and SOUNDS[SOUND_NAMES[kind]]
	if id and PlaySound then
		pcall(PlaySound, id)
	end
end

-- ---------------------------------------------------------------------------------------
-- The queue and the animation
-- ---------------------------------------------------------------------------------------

local function StartNext()
	local now = A.Now()
	while #alert.queue > 0 do
		local entry = table.remove(alert.queue, 1)
		if now - entry.at > EXPIRE_MS then
			alert.expired = alert.expired + 1
		else
			alert.current = entry
			alert.phase = "in"
			alert.elapsed = 0
			alert.shown = alert.shown + 1
			Render(entry)
			ContentHidden(false)
			PhaseVisual()
			PlaySoundFor(entry.kind)
			return
		end
	end
end

local function HoldMs()
	local ms = A.sv.duration * 1000
	if #alert.queue >= BACKLOG_FAST and ms > FAST_HOLD_MS then
		ms = FAST_HOLD_MS
	end
	return ms
end

local function Advance(dt)
	local phase = alert.phase
	if phase == "idle" then
		StartNext()
		return
	end
	alert.elapsed = alert.elapsed + dt
	if phase == "in" then
		if alert.elapsed >= SLIDE_IN_MS then
			alert.phase, alert.elapsed = "hold", 0
		end
	elseif phase == "hold" then
		if alert.elapsed >= HoldMs() then
			alert.phase, alert.elapsed = "out", 0
		end
	elseif phase == "out" then
		if alert.elapsed >= SLIDE_OUT_MS then
			alert.phase, alert.elapsed = "gap", 0
			alert.current = nil
			ContentHidden(true)
		end
	elseif phase == "gap" then
		if alert.elapsed >= GAP_MS then
			alert.phase, alert.elapsed = "idle", 0
		end
	end
	if alert.current then
		PhaseVisual()
	end
end

local function Tick()
	local now = A.Now()
	local dt = now - alert.lastTick
	alert.lastTick = now
	if dt < 0 then
		dt = 0
	elseif dt > MAX_STEP_MS then
		dt = MAX_STEP_MS
	end
	if alert.hud and not alert.preview then
		Advance(dt)
	end
	A:AlertUpdateState()
end

-- A tick that raises would raise again 25 ms later, and so on. Whatever went wrong, the banner on screen is
-- dropped (the next one starts clean) and the error is counted for /pbosa status.
local function Reset()
	alert.current = nil
	alert.phase, alert.elapsed = "idle", 0
	ContentHidden(true)
end

local function SafeTick()
	local ok, err = pcall(Tick)
	if not ok then
		A.errors = A.errors + 1
		A.lastError = "banner: " .. tostring(err)
		pcall(Reset)
		pcall(A.AlertUpdateState, A)
	end
end

-- The update runs only while there is a banner to animate or one waiting, and the game screen is up.
function A:AlertUpdateState()
	local want = alert.hud and not alert.preview and (alert.phase ~= "idle" or #alert.queue > 0)
	if want and not alert.ticking then
		alert.ticking = true
		alert.lastTick = A.Now()
		em:RegisterForUpdate(TICK_NAME, TICK_MS, SafeTick)
	elseif not want and alert.ticking then
		alert.ticking = false
		em:UnregisterForUpdate(TICK_NAME)
	end
end

-- entry = { kind = "online"|"offline", name, character (may be nil), guilds = { names }, at (optional) }
-- Returns the alert that will be shown (a merged one is returned as it already was).
function A:Enqueue(entry)
	entry.at = entry.at or A.Now()
	entry.guilds = entry.guilds or {}
	local key = entry.kind .. "|" .. tostring(entry.name)

	-- The same member reported by another watched guild a moment ago: one banner, both guild names.
	local existing = alert.recent[key]
	if existing and entry.at - existing.at <= MERGE_MS then
		for _, guild in ipairs(entry.guilds) do
			local known = false
			for _, listed in ipairs(existing.guilds) do
				if listed == guild then
					known = true
					break
				end
			end
			if not known then
				existing.guilds[#existing.guilds + 1] = guild
			end
		end
		if not existing.character and entry.character then
			existing.character = entry.character
		end
		alert.merged = alert.merged + 1
		if alert.current == existing and not alert.preview then
			Render(existing)
		end
		return existing
	end

	-- keep the table of recent alerts to the last few seconds
	for k, value in pairs(alert.recent) do
		if entry.at - value.at > MERGE_MS then
			alert.recent[k] = nil
		end
	end
	alert.recent[key] = entry

	alert.queue[#alert.queue + 1] = entry
	while #alert.queue > QUEUE_MAX do
		table.remove(alert.queue, 1)
		alert.dropped = alert.dropped + 1
	end
	self:AlertUpdateState()
	return entry
end

-- ---------------------------------------------------------------------------------------
-- The preview, while the settings panel is open
-- ---------------------------------------------------------------------------------------

function A:SampleEntry()
	local names = self:WatchedNames()
	return {
		kind = "online",
		name = S.sampleName,
		character = S.sampleCharacter,
		guilds = { names[1] or S.sampleGuild },
	}
end

function A:RefreshPreview()
	if alert.preview and Controls() then
		Render(self:SampleEntry())
	end
end

function A:SetPreview(on)
	on = on and true or false
	if alert.preview == on then
		if on then
			self:RefreshPreview()
		end
		return
	end
	local window = Controls()
	alert.preview = on
	if not window then
		return
	end
	if on then
		Render(self:SampleEntry())
		ContentHidden(false)
		window:SetHidden(false)
		Place(0, 1)
	else
		-- back to what the game screen is doing
		if alert.current then
			Render(alert.current)
			ContentHidden(false)
		else
			ContentHidden(true)
		end
		PhaseVisual()
		window:SetHidden(not alert.hud)
	end
	self:AlertUpdateState()
end

-- ---------------------------------------------------------------------------------------
-- Start-up
-- ---------------------------------------------------------------------------------------

function A:InitAlert()
	local window = Controls()
	if not window then
		error("the banner window is missing: PBsOnlineStatusAlert.xml did not load")
	end
	if not (ZO_SimpleSceneFragment and HUD_SCENE and HUD_UI_SCENE) then
		error("the game screen's scenes are not there")
	end
	self:ApplyLayout()
	ContentHidden(true)
	local fragment = ZO_SimpleSceneFragment:New(window)
	alert.fragment = fragment
	fragment:RegisterCallback("StateChange", function(_, newState)
		if newState == SCENE_FRAGMENT_SHOWN then
			alert.hud = true
		elseif newState == SCENE_FRAGMENT_HIDING or newState == SCENE_FRAGMENT_HIDDEN then
			alert.hud = false
		end
		A:AlertUpdateState()
	end)
	HUD_SCENE:AddFragment(fragment)
	HUD_UI_SCENE:AddFragment(fragment)
end

-- Queue two banners to be sure the whole path works (the /pbosa test command and the settings button).
function A:QueueTest()
	local guild = self:WatchedNames()[1] or S.sampleGuild
	self:Enqueue({ kind = "online", name = S.sampleName, character = S.sampleCharacter, guilds = { guild } })
	self:Enqueue({ kind = "offline", name = S.sampleName2, character = S.sampleCharacter2, guilds = { guild } })
end

PBS_OSA_MARK("Alert")
