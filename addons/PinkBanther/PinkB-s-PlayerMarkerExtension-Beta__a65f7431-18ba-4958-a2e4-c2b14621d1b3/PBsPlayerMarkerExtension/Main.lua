-- Start-up, the events, and the slash command.
local A, S = PBS_PME, PBS_PME_STRINGS
local em = EVENT_MANAGER

A.startErrors = {}

-- Each step of the start-up on its own, so one that fails does not take the others with it, and the command and the banner
-- can say which one it was.
local function Step(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		local failure = A.startErrors[name] or { count = 0 }
		failure.count = failure.count + 1
		failure.message = tostring(err)
		A.startErrors[name] = failure
	end
	return ok
end

local function StartErrorsText()
	local lines = {}
	for name, failure in pairs(A.startErrors) do
		lines[#lines + 1] = string.format("%s: %s (x%d)", name, failure.message, failure.count)
	end
	table.sort(lines)
	return table.concat(lines, "; ")
end

-- ---------------------------------------------------------------------------------------
-- The slash command
--
-- The text is split on spaces only and compared in ASCII: no Lua character classes on what the player typed (a Japanese
-- character cut in two by a locale-dependent class is a suspected PS5 crash).
-- ---------------------------------------------------------------------------------------

local function AsciiLower(text)
	return (text:gsub("[A-Z]", function(c)
		return string.char(c:byte() + 32)
	end))
end

local function Words(text)
	local words = {}
	for word in (text or ""):gmatch("[^ ]+") do
		words[#words + 1] = word
	end
	return words
end

local function Age(now, at)
	return string.format("%.0f s", (now - at) / 1000)
end

function A:StatusLines()
	local lines = {}
	local function add(format, ...)
		lines[#lines + 1] = string.format(format, ...)
	end
	local sv = self.sv
	local now = A.Stamp()
	add("%s", self.title)
	add("files that ran: %s", table.concat(self.fileOrder, ", "))
	if next(self.startErrors) then
		add("start-up problems: %s", StartErrorsText())
	end
	if not sv then
		add("the saved variables are not loaded")
		return lines
	end
	add("enabled: %s | settings panel: %s | HUD: %s", tostring(sv.enabled), self.panel and "yes" or (self.panelWhy or "no"), tostring(self.hudShown))
	local tex = self.tex
	add("pictures: %s | folder in use: %s", tex.state, A.ICON_PATH)
	for _, line in ipairs(tex.tries) do
		add("  %s", line)
	end
	if tex.lastError then
		add("  error: %s", tex.lastError)
	end

	local w = self.wheel
	add("wheel: %s", w.installed and "installed" or ("NOT installed: " .. tostring(w.why)))
	add("  list given out %d times (last had %s entries%s), extra picked %d, the game's own passed on %d, errors %d",
		w.opened, tostring(w.lastSize), w.limited and ", cut to ten: toggleable wheels are on" or "", w.picked, w.passed, w.errors)
	if w.lastError then
		add("  last error: %s", w.lastError)
	end
	add("  the wheel's window in front of the HUD: %s", self:WheelRaiseText())
	add("  the game's own marker taken off by an extra one: %s",
		self.engineCheck and "waiting for the game" or self.engineClearResult or "not tried yet")

	local okRoster, roster = pcall(self.RefreshRoster, self, true)
	if okRoster then
		local names = {}
		for _, entry in ipairs(roster.list) do
			names[#names + 1] = entry.name .. "=" .. entry.tag .. (entry.self and "(you)" or "") .. (entry.online and "" or "(offline)")
		end
		add("group: %d members: %s", #roster.list, #names > 0 and table.concat(names, ", ") or "-")
	end
	add("group frames (the names at the top left): %s", self:FramesText())
	add("compass bar (top of the screen): %s", self:CompassText())
	local count = 0
	for hash, m in pairs(self.marks) do
		count = count + 1
		local here = okRoster and roster.byHash[hash]
		add("  marker: %s <- %s (%s)%s, owner %s, %s ago%s", tostring(m.name), tostring(m.icon), A.IconName(m.icon),
			m.mine and " mine" or "", tostring(m.owner), Age(now, m.at),
			(okRoster and not here) and " [not in the group]" or (here and not here.online) and " [offline]" or "")
		add("    drawing it: %s", m.verdict or "not looked at yet")
	end
	add("markers: %d | placed %d, taken off %d, refused %d, heard %d, cleared by others %d, ran out %d, person left or offline %d, gave way to the game's own %d",
		count, self.stats.placed, self.stats.taken, self.stats.refused, self.stats.remoteSet, self.stats.remoteClear,
		self.stats.expired, self.stats.orphaned, self.stats.engineWon)

	local share = self.share
	add("group sharing: %s (protocol %d)", share.ready and "ready" or ("NOT ready: " .. tostring(share.why)), A.ShareProtocol.ID)
	add("  sent %d, heard %d (applied %d, ignored %d, other version %d, own echoes %d), asked %d, asked of us %d",
		share.sent, share.heard, share.applied, share.ignored, share.mismatched, share.echoes, share.asked, share.asks)
	add("  sending %s, showing the group's %s | last from: %s | last problem: %s", sv.shareSend and "on" or "off",
		sv.shareReceive and "on" or "off", tostring(share.lastFrom), tostring(share.lastWhy))

	local diag = self.diag
	add("drawing: %s | last frame %d markers, ticks %d, errors %d", self.worldOff and ("OFF: " .. self.worldOff) or "on",
		diag.lastDrawn or 0, diag.ticks, diag.errors)
	add("  scene: %s (HUD: %s) | why: %s", tostring(self.sceneName), tostring(self.hudShown), tostring(diag.why or "not looked at yet"))
	add("  the player (as last read): zone %s at %s, %s, %s | window %s, %d pictures in use", tostring(diag.pzone), tostring(diag.px),
		tostring(diag.py), tostring(diag.pz), self.world and (self.world.windowHidden and "hidden" or "shown") or "not made yet",
		self.world and self.world.used or 0)
	add("  3D window: render space made again %d times, hidden by something else and shown again %d times, an origin read back wrong %d times",
		diag.rebuilt or 0, diag.reshown or 0, diag.originDrift or 0)
	add("  zone id of your position: %s (changed %d times; %d loading screens seen) | members drawn although their zone id differed from yours (the game said one world): %d",
		tostring(diag.lastZone), diag.zoneChanges or 0, A.loads or 0, diag.zoneApart or 0)
	if diag.lastError then
		add("  last error: %s", diag.lastError)
	end
	local names = {}
	for name in pairs(self.fnState) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local state = self.fnState[name]
		add("  call %s: %s (%s)%s", name, state.usable and "usable" or "NOT usable", state.why, state.asked and (" [asked: " .. state.asked .. "]") or "")
	end
	if self.lastCrash then
		add("a call from the last session never returned and is not made again: %s (/pbpme retry)", self.lastCrash)
	end
	return lines
end

function A:WhyLines()
	local lines = { self.title .. ": what happened" }
	local now, earlier = self:TraceLines()
	if #now == 0 then
		lines[#lines + 1] = "  (nothing yet this session)"
	end
	for _, line in ipairs(now) do
		lines[#lines + 1] = "  " .. line
	end
	if #earlier > 0 then
		lines[#lines + 1] = "the session before:"
		for _, line in ipairs(earlier) do
			lines[#lines + 1] = "  " .. line
		end
	end
	return lines
end

function A:Command(input)
	local words = Words(input)
	local command = AsciiLower(words[1] or "status")
	local number = tonumber(words[2])
	self.speaking = true
	local ok, err = pcall(function()
		if command == "status" then
			for _, line in ipairs(self:StatusLines()) do
				A.Say(line)
			end
		elseif command == "why" then
			for _, line in ipairs(self:WhyLines()) do
				A.Say(line)
			end
		elseif command == "test" then
			local started, why = self:StartTest(number)
			if started then
				self:Print(S.testOn)
			else
				self:Print(S.testNoPosition, tostring(why))
			end
		elseif command == "mark" then
			if not A.IsIcon(number) then
				A.Say(string.format(S.markUsage, A.ICON_COUNT))
			else
				local delay = tonumber(words[3])
				if delay and delay > 0 and zo_callLater then
					-- a typed command cannot be sent while aiming: after this many seconds the marker goes on whoever is under the reticle
					zo_callLater(function()
						self.speaking = true
						pcall(self.PlaceExtended, self, number)
						self.speaking = false
					end, delay * 1000)
				else
					self:PlaceExtended(number)
				end
			end
		elseif command == "textures" then
			if self:StartTextureCheck(true) then
				self:Print(S.texturesChecking)
			else
				A.Say(S.texturesBusy)
			end
		elseif command == "unmark" then
			self:ClearReticle()
		elseif command == "clear" then
			self:ActClearAll()
		elseif command == "compass" then
			A.Say(self:CompassCommand(words[2] and AsciiLower(words[2])))
		elseif command == "retry" then
			self.sv.probe = {}
			self.lastCrash = nil
			self.fnState = {}
			self.worldOff = nil
			self.engineCheck, self.engineClearResult = nil, nil
			self.pausedUntil = nil
			self:CompassForget()
			self:Print(S.retried)
		else
			A.Say(S.help)
		end
		if self.panel and self.panel.UpdateControls then
			self.panel:UpdateControls()
		end
	end)
	self.speaking = false
	if not ok then
		A.Say("PBsPlayerMarkerExtension: the command failed: " .. tostring(err))
	end
end

-- ---------------------------------------------------------------------------------------
-- Start-up
-- ---------------------------------------------------------------------------------------

local started = false

local function Start(late)
	if started then
		return
	end
	started = true
	em:UnregisterForEvent(A.name, EVENT_ADD_ON_LOADED)
	A.late = late and true or false

	Step("saved variables", function()
		A.sv = ZO_SavedVars:NewAccountWide("PBsPlayerMarkerExtension_Data", 1, nil, A.defaults)
		A:Sanitize()
	end)
	if not A.sv then
		return
	end
	Step("settings", function()
		A:InitSettings()
	end)
	Step("marker wheel", function()
		A:InstallWheel()
		A:RaiseWheel()
	end)
	Step("group sharing", function()
		A:StartShare()
	end)
	Step("marker events", function()
		A:StartMarks()
	end)
	Step("tick", function()
		A:StartTick()
	end)
end

local function OnLoaded(_, name)
	if name == A.name then
		Start(false)
	end
end

local bannerShown = false
local function OnActivated()
	-- the fallback: if ADD_ON_LOADED never reached us by name, start now and say so
	if not started then
		Start(true)
	end
	if not A.sv then
		return
	end
	A.active = true
	-- loading screens counted: a zone id that changes with none in between is one world (see World.lua)
	A.loads = (A.loads or 0) + 1
	Step("marker wheel", function()
		-- the game's own wheel may not have been there when this add-on loaded
		A:InstallWheel()
		A:RaiseWheel()
	end)
	Step("group sharing", function()
		A:ShareLogin()
	end)
	Step("picture check", function()
		A:StartTextureCheck()
	end)
	if not bannerShown then
		bannerShown = true
		A:Print(S.banner, A.title)
		if A.late then
			A:Print("(started late, at the first load screen)")
		end
		if next(A.startErrors) then
			A:Print(S.notReady, StartErrorsText())
		end
	end
end

-- Both handlers are registered when the file loads; every step inside runs under pcall.
em:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, OnLoaded)
em:RegisterForEvent(A.name, EVENT_PLAYER_ACTIVATED, OnActivated)
em:RegisterForEvent(A.name, EVENT_PLAYER_DEACTIVATED, function()
	A.active = false
	A.engineCheck = nil
	A.hudShown = false
	if A.world then
		A:HideWorld()
	end
end)

A.MARK("Main")
