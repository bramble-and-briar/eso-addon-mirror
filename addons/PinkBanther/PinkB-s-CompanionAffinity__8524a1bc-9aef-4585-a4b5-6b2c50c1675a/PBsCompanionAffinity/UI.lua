-- The HUD list: a header with the companion and its rapport, then one line per source. A line has the
-- cooldown on the left and what the action is on the right.
--
-- Console-safe on purpose, like PB's Compass: only fonts the client already has loaded (a font nothing
-- else draws with has to be built on use and has crashed a PS5), no textures of its own, and nothing
-- takes input. The list is redrawn once a second and when a rapport change arrives; a control is only
-- written to when what it shows has changed.
--
-- The list is never blank while it is switched on and the HUD is up: with no companion it says so, and
-- with a companion but nothing to show it says that. A list that draws nothing at all cannot be told
-- from an add-on that is not running.
local A, S = PBS_CABS, PBS_CABS_STRINGS

local TICK_MS = 1000
local DEMO_MS = 20000
local MAX_TICK_ERRORS = 3
local GAP = 24 -- between two columns, in pixels

local HEADER_COLOR = { 1, 0.41, 0.71 }
local DIM_COLOR = { 0.72, 0.72, 0.72 }
local DETAIL_COLOR = { 1, 1, 1 }
local TIMER_COLORS = {
	cooling = { 1, 0.78, 0.35 },
	ready = { 0.45, 1, 0.55 },
	elapsed = { 0.72, 0.72, 0.72 },
	-- "READY?": an estimate that has run out, which is not a promise
	maybe = { 0.62, 0.78, 0.66 },
	-- an action of the table that has not been seen, and one that is always available
	unseen = { 0.55, 0.55, 0.55 },
	free = { 0.45, 1, 0.55 },
}
local UNSEEN_DETAIL_COLOR = { 0.8, 0.8, 0.8 }

local floor = math.floor

local function NewLabel(name, parent, alignment)
	local c = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
	c:SetDrawLayer(DL_TEXT)
	c:SetMouseEnabled(false)
	c:SetMaxLineCount(1)
	c:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	c:SetHorizontalAlignment(alignment)
	c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	c:SetHidden(true)
	return { ctl = c, hidden = true }
end

-- Write to a label only if it would change: text, colour, visibility.
local function Put(label, text, color)
	if label.text ~= text then
		label.ctl:SetText(text)
		label.text = text
	end
	if label.color ~= color then
		label.ctl:SetColor(color[1], color[2], color[3], 1)
		label.color = color
	end
	if label.hidden then
		label.ctl:SetHidden(false)
		label.hidden = false
	end
end

local function Hide(label)
	if not label.hidden then
		label.ctl:SetHidden(true)
		label.hidden = true
	end
end

function A:CreateUI()
	local root = WINDOW_MANAGER:CreateTopLevelWindow("PBsCABSRoot")
	root:SetHidden(true)
	root:SetMouseEnabled(false)
	root:SetMovable(false)
	root:SetDimensions(2, 2)
	self.root = root
	self.header = NewLabel("PBsCABSHeader", root, TEXT_ALIGN_LEFT)
	-- what the list says instead of lines when there are none: the width of a column, under the header
	self.note = NewLabel("PBsCABSNote", root, TEXT_ALIGN_LEFT)
	self.lines = {}
end

function A:GetLine(index)
	local line = self.lines[index]
	if not line then
		line = {
			timer = NewLabel("PBsCABSTimer" .. index, self.root, TEXT_ALIGN_LEFT),
			detail = NewLabel("PBsCABSDetail" .. index, self.root, TEXT_ALIGN_LEFT),
		}
		self.lines[index] = line
		self:LayoutLine(index)
	end
	return line
end

function A:IsPreviewing()
	return self.panelOpen and self.sv.preview and self.active and true or false
end

function A:ShowingDemo()
	return self:IsPreviewing() or (self.demoUntil ~= nil and GetGameTimeMilliseconds() < self.demoUntil)
end

local function FontName(step)
	return "ZoFontGamepad" .. A.TEXT_SIZES[step]
end

-- Size and place one line, from the current font.
function A:LayoutLine(index)
	local m, line = self.metrics, self.lines[index]
	if not (m and line) then
		return
	end
	-- Lines fill a column to the top setting, then the next column.
	local perColumn = self.sv.maxRows
	local column, row = floor((index - 1) / perColumn), (index - 1) % perColumn
	local x = column * (m.width + GAP)
	local y = m.headerHeight + row * m.rowHeight
	-- The cooldown is the left part of the line, the action the rest of it, both against the left.
	local timer, detail = line.timer.ctl, line.detail.ctl
	timer:SetFont(m.rowFont)
	detail:SetFont(m.rowFont)
	timer:ClearAnchors()
	timer:SetAnchor(TOPLEFT, self.root, TOPLEFT, x, y)
	timer:SetDimensions(m.timerWidth, m.rowHeight)
	detail:ClearAnchors()
	detail:SetAnchor(TOPLEFT, self.root, TOPLEFT, x + m.timerWidth + 8, y)
	detail:SetDimensions(m.width - m.timerWidth - 8, m.rowHeight)
	-- the next write sets the colour again
	line.timer.color, line.detail.color = nil, nil
end

-- Everything that depends on the settings.
function A:ApplyLayout()
	local root = self.root
	if not root then
		return
	end
	local sv = self.sv
	local rowPx, headerPx = A.TEXT_SIZES[sv.textSize], A.TEXT_SIZES[sv.headerSize]
	-- 100% is wide enough that every name in the table of actions (Catalog.lua keeps them short for this) and an
	-- ordinary recorded line ("+5  Craft: Blacksmithing") is whole; a long quest name is cut, with an ellipsis,
	-- at the edge of its column. The timer, on the left, takes the same share of the width at every width, but never
	-- less than 7 text heights: the longest timers are "in ~23:59:59", "23:59:59 ago" and, in Japanese with its
	-- full-width kana, "あと ~23:59:59", and a timer that is cut is worse than a name that is.
	local width = floor(rowPx * 33 * sv.width / 100 + 0.5)
	self.metrics = {
		rowFont = FontName(sv.textSize),
		headerFont = FontName(sv.headerSize),
		width = width,
		timerWidth = math.max(floor(width * 8 / 33 + 0.5), rowPx * 7),
		rowHeight = rowPx + 6,
		headerHeight = headerPx + 12,
	}
	local m = self.metrics

	local previewing = self:IsPreviewing()
	root:ClearAnchors()
	root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.x, sv.y)
	-- The window is as big as the list can get, so everything drawn stays inside it.
	root:SetDimensions(sv.columns * width + (sv.columns - 1) * GAP, m.headerHeight + sv.maxRows * m.rowHeight)
	root:SetAlpha(sv.opacity / 100)
	-- Above the settings screen while it is being adjusted, in the HUD layer otherwise.
	root:SetDrawTier(previewing and DT_HIGH or DT_MEDIUM)
	root:SetDrawLayer(previewing and DL_OVERLAY or DL_CONTROLS)
	root:SetDrawLevel(previewing and 100 or 0)

	local header = self.header.ctl
	header:SetFont(m.headerFont)
	header:ClearAnchors()
	header:SetAnchor(TOPLEFT, root, TOPLEFT, 0, 0)
	header:SetDimensions(width, m.headerHeight)
	self.header.color = nil
	local note = self.note.ctl
	note:SetFont(m.rowFont)
	note:ClearAnchors()
	note:SetAnchor(TOPLEFT, root, TOPLEFT, 0, m.headerHeight)
	note:SetDimensions(width, m.rowHeight)
	self.note.color = nil
	for index in ipairs(self.lines) do
		self:LayoutLine(index)
	end
end

-- Draw the list as it stands now.
function A:Render()
	if not self.root or self.root:IsHidden() then
		return
	end
	local demo = self:ShowingDemo()
	local now = GetTimeStamp()
	local id = (not demo) and self:ActiveCompanionId() or nil
	local list, header, headerColor, hint = {}, nil, HEADER_COLOR, nil
	if demo then
		list = self:DemoRows(now)
		header = string.format(S.rapportShort, S.sampleCompanion, 1234)
	elseif id then
		list = self:BuildRows(now, id)
		header = self:HeaderText(id)
		if #list == 0 then
			hint = self:EmptyNote(id)
		end
	else
		header, headerColor = S.noCompanion, DIM_COLOR
	end

	Put(self.header, header, headerColor)
	local shown = math.min(#list, self.sv.maxRows * self.sv.columns)
	for index = 1, shown do
		local entry = list[index]
		local line = self:GetLine(index)
		local timer, detail, state = A.RowTexts(entry)
		Put(line.timer, timer, TIMER_COLORS[state])
		Put(line.detail, detail, state == "unseen" and UNSEEN_DETAIL_COLOR or DETAIL_COLOR)
	end
	-- a hint only ever stands in for an empty list
	if hint then
		Put(self.note, hint, DIM_COLOR)
	else
		Hide(self.note)
	end
	for index = shown + 1, #self.lines do
		Hide(self.lines[index].timer)
		Hide(self.lines[index].detail)
	end
end

-- An error in the update must not repeat every second for ever: it is kept for /pbcabs status, and
-- the third one in a row stops the update.
function A:Tick()
	-- Judge the actions set aside first, so what is drawn already knows what the judging found. It has
	-- its own guard: a failure there must not stop the drawing.
	local judged, judgeErr = pcall(self.CheckMisses, self)
	local ok, err = pcall(self.Render, self)
	if ok and judged then
		self.tickErrors = 0
		return
	end
	if ok then
		err = judgeErr
	end
	self:NoteError(err)
	self.tickErrors = (self.tickErrors or 0) + 1
	if self.tickErrors >= MAX_TICK_ERRORS then
		EVENT_MANAGER:UnregisterForUpdate(self.name .. "Tick")
		self:Print("stopped after an error: " .. self.diag.lastError)
	end
end

-- Is the HUD (rather than a menu or a loading screen) what the player is looking at?
function A:HudShowing()
	return (HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing()) and true or false
end

function A:WantsToShow()
	if not self.active then
		return false
	end
	if self:ShowingDemo() then
		return true
	end
	return self.sv.enabled and self:HudShowing() and (self.sv.showWithoutCompanion or self:HasCompanion()) and true or false
end

function A:RefreshVisibility()
	local root = self.root
	if not root then
		return
	end
	local visible = self:WantsToShow()
	root:SetHidden(not visible)
	EVENT_MANAGER:UnregisterForUpdate(self.name .. "Tick")
	self.tickOn = visible
	if visible then
		self.tickErrors = 0
		-- The update timer is set up whatever the first draw does: it tries again each second.
		local ok, err = pcall(self.Render, self)
		if not ok then
			self:NoteError(err)
		end
		EVENT_MANAGER:RegisterForUpdate(self.name .. "Tick", TICK_MS, function()
			self:Tick()
		end)
	end
end

-- Sample rows for a few seconds in the HUD, for someone who has nothing recorded yet.
function A:StartDemo()
	self.demoUntil = GetGameTimeMilliseconds() + DEMO_MS
	self:ApplyLayout()
	self:RefreshVisibility()
	EVENT_MANAGER:RegisterForUpdate(self.name .. "DemoEnd", DEMO_MS + 100, function()
		EVENT_MANAGER:UnregisterForUpdate(self.name .. "DemoEnd")
		self.demoUntil = nil
		self:RefreshVisibility()
	end)
end

if PBS_CABS_MARK then
	PBS_CABS_MARK("UI")
end
