-- PB's FurnitureEditor -- the progress bar
--
-- A cut, a move and a paste are hundreds of requests, one at a time, and a console player in the housing editor
-- cannot see the chat. This draws a bar with what is being done and how far it is: "Move  placed 12 / 38 ...".
--
-- It is built the way PBsCraftMaterialAssistant builds its window, for the same reasons:
--   * A plain top-level window with the mouse switched off. It cannot be clicked, dragged or focused, so it can
--     never take a click away from the game underneath it.
--   * Created the first time something has to be drawn, not at load: nothing is left behind in the UI by an
--     add-on that is never used (and the bar can be switched off: /pbfe progress off).
--   * In no scene, so nothing hides it; the draw layer (overlay, high tier) is what puts it over the editor.
--   * Only fonts the console UI has already loaded, by alias: a face nothing else is drawing with has to be
--     built on use, and that build comes out of the memory every add-on shares (measured crashing a PS5).
--   * Every client call is inside pcall. A control that will not build turns the bar off, once, with a line in chat;
--     the cut or paste goes on without it.
--
-- The bar is not the progress of anything the add-on does not know. "Done" is what has been confirmed (a piece is
-- out of the house, or placed, or linked), so a request that fails leaves the bar short of full, and the end says
-- how many failed.
--
--   /pbfe progress              on or off, and where
--   /pbfe progress on|off
--   /pbfe progress top|center|bottom
--   /pbfe progress test         a bar that fills over a few seconds, to see where it is and how it reads

local addon = PBS_FURNITURE_EDITOR

local Try1 = addon.Try1
local Print = addon.Print

local progress = {}
addon.progress = progress

local WINDOW_NAME = "PBsFurnitureEditorProgress"

-- measures, in UI units (the console UI is 1920 x 1080)
local WIDTH, HEIGHT = 640, 104
local PADDING = 16
local BAR_TOP, BAR_HEIGHT = 50, 14

-- the font: an alias the client has loaded, never a path
local FONT = "$(GAMEPAD_MEDIUM_FONT)|26|soft-shadow-thick"

-- how long the last state stays up after the work has ended, in milliseconds
local LINGER_MS = 3000

local COLOUR = {
	panel = { 0, 0, 0, 0.72 },
	track = { 0.25, 0.25, 0.25, 0.95 },
	fill = { 1.0, 0.41, 0.71, 1 },        -- the add-on's pink
	done = { 0.44, 0.89, 0.54, 1 },
	failed = { 1.0, 0.38, 0.38, 1 },
}

-- where the window sits: anchor point name, offset from the screen's edge
local PLACES = {
	top = { point = "TOP", y = 90 },
	center = { point = "CENTER", y = 0 },
	bottom = { point = "BOTTOM", y = -190 },
}

local TEXT = {
	en = {
		cut = "Cut", move = "Move", paste = "Paste", undo = "Undo", test = "Progress bar (test)",
		place = "placing", link = "linking", state = "finishing", retry = "retrying",
		counts = "%d / %d (%d%%)",
		left = "about %d s left", leftMinutes = "about %d min left",
		finished = "done", finishedFailed = "done, %d failed", stopped = "stopped",
	},
	jp = {
		cut = "カット", move = "ムーブ", paste = "ペースト", undo = "取り消し", test = "進捗バー（テスト）",
		place = "配置中", link = "リンク中", state = "仕上げ中", retry = "再試行中",
		counts = "%d / %d（%d%%）",
		left = "残り約%d秒", leftMinutes = "残り約%d分",
		finished = "完了", finishedFailed = "完了（失敗 %d）", stopped = "停止",
	},
}

local function Text()
	return TEXT[Try1(GetCVar, "language.2")] or TEXT.en
end

-- ---------------------------------------------------------------------------------------
-- The controls
-- ---------------------------------------------------------------------------------------

local function Safe(fn, ...)
	return pcall(fn, ...)
end

function progress:Enabled()
	return addon.sv ~= nil and addon.sv.progress ~= false and not self.failed
end

function progress:Place()
	return PLACES[addon.sv and addon.sv.progressAt] or PLACES.top
end

local function MakeBackdrop(wm, name, parent, colour)
	local control = wm:CreateControl(name, parent, CT_BACKDROP)
	control:SetMouseEnabled(false)
	control:SetCenterColor(unpack(colour))
	control:SetEdgeColor(colour[1], colour[2], colour[3], 0)
	return control
end

local function MakeLabel(wm, name, parent)
	local label = wm:CreateControl(name, parent, CT_LABEL)
	label:SetMouseEnabled(false)
	label:SetFont(FONT)
	label:SetColor(1, 1, 1, 1)
	label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	return label
end

-- Builds the window once. Returns true when there is a window to draw in.
function progress:Create()
	if self.window then
		return true
	end
	if self.failed then
		return false
	end

	local wm = WINDOW_MANAGER
	if not (wm and wm.CreateTopLevelWindow and wm.CreateControl and CT_LABEL and CT_BACKDROP and GuiRoot) then
		self:Fail("the client has no window manager to build it with")
		return false
	end

	local ok, why = Safe(function()
		local window = wm:CreateTopLevelWindow(WINDOW_NAME)
		window:SetMouseEnabled(false)
		window:SetMovable(false)
		window:SetHidden(true)
		window:SetDimensions(WIDTH, HEIGHT)

		-- in front of the housing editor, and of a full-screen menu; failing is survivable
		Safe(function()
			window:SetDrawLayer(DL_OVERLAY)
			window:SetDrawTier(DT_HIGH)
		end)

		local panel = MakeBackdrop(wm, WINDOW_NAME .. "Panel", window, COLOUR.panel)
		panel:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
		panel:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, 0, 0)

		local title = MakeLabel(wm, WINDOW_NAME .. "Title", window)
		title:SetAnchor(TOPLEFT, window, TOPLEFT, PADDING, 8)
		title:SetDimensions(WIDTH - PADDING * 2, 34)

		local track = MakeBackdrop(wm, WINDOW_NAME .. "Track", window, COLOUR.track)
		track:SetAnchor(TOPLEFT, window, TOPLEFT, PADDING, BAR_TOP)
		track:SetDimensions(WIDTH - PADDING * 2, BAR_HEIGHT)

		local fill = MakeBackdrop(wm, WINDOW_NAME .. "Fill", window, COLOUR.fill)
		fill:SetAnchor(TOPLEFT, window, TOPLEFT, PADDING, BAR_TOP)
		fill:SetDimensions(1, BAR_HEIGHT)
		fill:SetHidden(true)

		local detail = MakeLabel(wm, WINDOW_NAME .. "Detail", window)
		detail:SetAnchor(TOPLEFT, window, TOPLEFT, PADDING, BAR_TOP + BAR_HEIGHT + 6)
		detail:SetDimensions(WIDTH - PADDING * 2, 30)

		self.window, self.title, self.fill, self.detail = window, title, fill, detail
	end)

	if not ok then
		self.window = nil
		self:Fail(tostring(why))
		return false
	end
	return true
end

-- A bar that cannot be built is turned off for the rest of the session, said once.
function progress:Fail(why)
	self.failed = true
	Print("the progress bar could not be drawn (%s); it is off for this session", tostring(why))
end

function progress:Position()
	local place = self:Place()
	local ok = Safe(function()
		self.window:ClearAnchors()
		self.window:SetAnchor(_G[place.point], GuiRoot, _G[place.point], 0, place.y)
	end)
	return ok
end

-- ---------------------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------------------

local function Colour(control, colour)
	control:SetCenterColor(unpack(colour))
end

-- Draws the current state: `s` = { kind, total, done, phase, ended, failed, stopped, started }.
function progress:Draw()
	local s = self.state
	if not s or not self:Create() then
		return
	end

	local text = Text()
	local fraction = s.total > 0 and math.min(s.done / s.total, 1) or 0
	if s.ended and not s.failed and not s.stopped then
		fraction = 1
	end
	local percent = math.floor(fraction * 100 + 0.5)

	local detail = string.format(text.counts, s.done, s.total, percent)
	if s.ended then
		if s.stopped then
			detail = detail .. "  " .. text.stopped
		elseif s.failed > 0 then
			detail = detail .. "  " .. string.format(text.finishedFailed, s.failed)
		else
			detail = detail .. "  " .. text.finished
		end
	else
		if s.phase and text[s.phase] then
			detail = detail .. "  " .. text[s.phase]
		end
		-- a time, once there is something to go on
		if s.done >= 5 and s.done < s.total then
			local seconds = math.ceil((addon.Now() - s.started) / 1000 * (s.total - s.done) / s.done)
			if seconds >= 90 then
				detail = detail .. "  " .. string.format(text.leftMinutes, math.ceil(seconds / 60))
			else
				detail = detail .. "  " .. string.format(text.left, seconds)
			end
		end
	end

	local colour = COLOUR.fill
	if s.ended then
		colour = (s.failed > 0 or s.stopped) and COLOUR.failed or COLOUR.done
	end

	local ok = Safe(function()
		self.title:SetText(text[s.kind] or tostring(s.kind))
		self.detail:SetText(detail)

		local width = math.floor((WIDTH - PADDING * 2) * fraction)
		if width <= 0 then
			self.fill:SetHidden(true)
		else
			self.fill:SetDimensions(width, BAR_HEIGHT)
			Colour(self.fill, colour)
			self.fill:SetHidden(false)
		end
	end)
	if not ok then
		self:Fail("a control refused to draw")
		return
	end

	self.drawn = { title = text[s.kind], detail = detail, percent = percent }
end

function progress:Show()
	if self:Create() and self:Position() then
		Safe(function()
			self.window:SetHidden(false)
		end)
	end
end

function progress:HideNow()
	if self.window then
		Safe(function()
			self.window:SetHidden(true)
		end)
	end
end

-- ---------------------------------------------------------------------------------------
-- What the runs say
-- ---------------------------------------------------------------------------------------

-- A run has begun. kind: "cut", "undo", "paste" or "move".
function progress:Begin(kind, total)
	if not self:Enabled() then
		self.state = nil
		return
	end

	self.token = (self.token or 0) + 1
	self.state = {
		kind = kind, total = math.max(total or 0, 0), done = 0, failed = 0,
		started = addon.Now(),
	}
	if kind == "paste" or kind == "move" then
		self.state.phase = "place"
	end
	self:Show()
	self:Draw()
end

-- How far a run has got, read from the run itself: nothing is counted twice.
function progress:Update(run)
	local s = self.state
	if not s or self.run ~= run then
		return
	end

	if run.kind == "paste" then
		s.done = math.min(run.placed + run.linked, s.total)
		if run.phase == "link" then
			s.phase = run.linkRounds and run.linkRounds > 0 and "retry" or "link"
		elseif run.phase == "state" then
			s.phase = "state"
		else
			s.phase = run.placeRounds and run.placeRounds > 0 and "retry" or "place"
		end
	else
		s.done = math.min(run.removed + run.skipped, s.total)
		s.phase = run.removeRounds and run.removeRounds > 0 and "retry" or nil
	end
	self:Draw()
end

-- Where a run starts and ends, called from Paste.lua.
function progress:RunStarted(run)
	if run.kind == "paste" then
		local clip = run.plan and run.plan.clip
		local links = run.plan and #run.plan.links or 0
		self.run = run
		self:Begin(clip and clip.cut and "move" or "paste", (run.total or 0) + links)
	elseif run.kind == "cut" or run.kind == "undo" then
		self.run = run
		self:Begin(run.kind, run.total or 0)
	end
end

function progress:RunEnded(run, reason)
	local s = self.state
	if not s or self.run ~= run then
		return
	end

	s.ended = true
	s.phase = nil
	s.failed = #run.failed + #(run.linkFailed or {})
	s.stopped = reason ~= nil           -- a run that ends with a reason did not run to its end
	if run.kind == "paste" then
		s.done = math.min(run.placed + run.linked, s.total)
	else
		s.done = math.min(run.removed + run.skipped, s.total)
	end
	self:Draw()

	-- it stays a moment, unless something else starts
	local token = self.token
	addon.Later(LINGER_MS, function()
		if progress.token == token then
			progress:HideNow()
		end
	end)
end

-- ---------------------------------------------------------------------------------------
-- A test, and the command
-- ---------------------------------------------------------------------------------------

function progress:Test()
	if not self:Enabled() then
		Print("the progress bar is off (/pbfe progress on)")
		return
	end

	local total = 40
	self:Begin("test", total)
	self.run = nil
	if not self.state then
		return
	end

	for step = 1, total do
		addon.Later(step * 150, function()
			if progress.state and progress.token == progress.testToken then
				progress.state.done = step
				progress.state.phase = step < total and "place" or nil
				progress:Draw()
			end
		end)
	end
	self.testToken = self.token
	addon.Later(total * 150 + 200, function()
		if progress.token == progress.testToken and progress.state then
			progress.state.ended = true
			progress.state.phase = nil
			progress:Draw()
		end
	end)
	addon.Later(total * 150 + 200 + LINGER_MS, function()
		if progress.token == progress.testToken then
			progress:HideNow()
		end
	end)
end

addon:AddCommand("progress", "  /pbfe progress [on|off|top|center|bottom|test]   the progress bar for cut, move and paste", function(self, words)
	local what = words[1]

	if what == "on" then
		self.sv.progress = true
		self.progress.failed = nil
		Print("the progress bar is on (%s)", self.sv.progressAt or "top")
	elseif what == "off" then
		self.sv.progress = false
		self.progress:HideNow()
		Print("the progress bar is off")
	elseif PLACES[what or ""] then
		self.sv.progressAt = what
		if self.progress.window then
			self.progress:Position()
		end
		Print("the progress bar is at the %s of the screen", what)
	elseif what == "test" then
		self.progress:Test()
	else
		Print("the progress bar is %s, at the %s%s", self.sv.progress == false and "off" or "on", self.sv.progressAt or "top",
			self.progress.failed and " (it could not be drawn this session)" or "")
		Print("/pbfe progress on|off|top|center|bottom|test")
	end
end)
