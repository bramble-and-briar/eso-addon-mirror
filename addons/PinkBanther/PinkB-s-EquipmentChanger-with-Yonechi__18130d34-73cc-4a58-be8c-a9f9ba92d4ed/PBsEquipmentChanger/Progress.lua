-- The progress bar shown while a set is being put on.
--
-- A load has up to three stages, in this order: gear (one request at a time), skills (one allocation request) and the
-- champion bar (one slotting request). The bar has one segment for each stage the load is going to do, all the same
-- width, so the segment and the words under it line up:
--
--   「Tank」を装着中…                                   33%
--   [=========][--------][--------]
--    装備        スキル     チャンピオン
--    5/8         待機中     待機中
--
-- Nothing in the bar is a guess about how long something takes. A segment is empty while the stage waits, lit while its
-- request is out (skills and the champion bar are one request each, so there is nothing to count), filled by the
-- number of gear slots settled for gear, and solid when the stage is over. A stage with nothing to change is solid
-- from the start and says so. The percentage is the filled part of the whole bar.
--
-- The window is a top-level window of plain labels and textures, like the preview (Preview.lua) and PB's Chat Window
-- Customizer's, which is the pattern that has been measured on a PS5. It is created and shown from the update loop of
-- a load, never from the caller's own context (the wheel's button release), and a load that is over in its first tick
-- never shows it. Nothing here may stop a load: every entry point catches its own errors and keeps the last one for
-- /pbec status.

local A, S = PBS_EQUIPMENT_CHANGER, PBS_EQUIPMENT_CHANGER_STRINGS

local progress = {}
A.progress = progress

local NAME = "PBsEquipmentChangerProgress"

-- UI units (the gamepad UI is laid out on 1920 x 1080).
local WIDTH = 460 -- fits the second quadrant (470 wide) of the settings panel
local PAD = 14
local BAR_HEIGHT = 14
local SEGMENT_GAP = 6
local TITLE_HEIGHT = 30
local NAME_HEIGHT = 28
local STATE_HEIGHT = 26
local PERCENT_WIDTH = 70
local HOLD_MS = 2500 -- how long the finished bar stays
local HOLD_PROBLEMS_MS = 5000
-- Where it sits. In the HUD (the wheel, a command): at the bottom, clear of the action bar. In the settings panel: at the
-- top of the second quadrant (x 536-1006), which is empty because no row has a tooltip, and clear of the preview window,
-- which starts at x 1044. Both unmeasured on a PS5.
local PANEL_LEFT = 536
local HUD_BOTTOM = -230

local ORDER = { "gear", "skills", "champion" }
local STAGE_LABEL = { gear = "progressGear", skills = "progressSkills", champion = "progressChampion" }
local STATE_TEXT = {
	pending = "progressPending", running = "progressRunning", done = "progressDone",
	same = "progressSame", warn = "progressWarn", error = "progressError",
}

local PINK = { 1, 0.41, 0.71, 1 }
local WHITE = { 1, 1, 1, 1 }
local DIM = { 1, 1, 1, 0.6 }
local YELLOW = { 1, 0.82, 0.35, 1 }
local RED = { 1, 0.45, 0.45, 1 }
local TEXT_COLOR = { pending = DIM, running = PINK, done = WHITE, same = DIM, warn = YELLOW, error = RED }
local FILL_COLOR = { running = PINK, done = PINK, same = { 1, 1, 1, 0.3 }, warn = YELLOW, error = RED }
local TRACK = { 1, 1, 1, 0.18 }
local GLOW = { 1, 0.41, 0.71, 0.35 }

-- Named fonts the gamepad UI has already built.
local FONT_TITLE, FONT_NAME, FONT_STATE = "ZoFontGamepad22", "ZoFontGamepad22", "ZoFontGamepad22"

-- ---------------------------------------------------------------------------------------
-- What there is to do, and how far it has got (no controls here)
-- ---------------------------------------------------------------------------------------

-- Counted before the first request of a load changes anything, from queries only. For each stage the load will take
-- part in: how many things it has to change (gear: the keys of the slots; skills and champion bar: the number of slot
-- changes, -1 when that could not be worked out, which counts as "something to do").
function A:ProgressPlan(set)
	local plan = {}
	if self.sv.applyGear and set.gear then
		local keys = {}
		for _, def in ipairs(self.GEAR) do
			if def.slot then
				local want = set.gear[def.key]
				if want then
					if not self:InPlace(def, want) then
						keys[#keys + 1] = def.key
					end
				elseif self.sv.unequipEmpty and GetWornItemInfo(BAG_WORN, def.slot) then
					keys[#keys + 1] = def.key
				end
			end
		end
		plan.gear = { keys = keys, total = #keys }
	end
	if self.sv.applySkills and set.bars then
		local ok, changes = pcall(self.BuildSkillChanges, self, set)
		plan.skills = { total = ok and type(changes) == "table" and #changes or -1 }
	end
	if self.sv.applyChampion and set.champion then
		local ok, changes = pcall(self.BuildChampionChanges, self, set)
		plan.champion = { total = ok and type(changes) == "table" and #changes or -1 }
	end
	return plan
end

local function GearProgress(job, info)
	local settled, flagged = 0, false
	local resolved, failed, missing = job.resolved or {}, job.failed or {}, job.missing or {}
	for _, key in ipairs(info.keys) do
		if failed[key] or missing[key] then
			settled = settled + 1
			flagged = true
		elseif resolved[key] then
			settled = settled + 1
		end
	end
	return settled, flagged
end

-- How many of the planned gear slots ended up with their item on (the others failed or could not be found).
local function GearOnCount(job, info)
	local failed, missing = job.failed or {}, job.missing or {}
	local on = 0
	for _, key in ipairs(info.keys) do
		if not (failed[key] or missing[key]) then
			on = on + 1
		end
	end
	return on
end

-- The bar as a plain table, so that it can be tested and drawn without the controls:
--   title, percent, problems ("error" | "warn" | nil), stages = { { key, label, state, fraction, text, flag }, ... }
-- `verdict` (from A:Report) is given once the load is over.
function A:ProgressModel(job, verdict)
	local plan = job.plan or {}
	local current = 3
	if verdict then
		current = 4
	elseif job.stage == "gear" then
		current = 1
	elseif job.stage == "skills" then
		current = 2
	end
	local stages, sum = {}, 0
	local worst
	for position, key in ipairs(ORDER) do
		local info = plan[key]
		if info then
			local stage = { key = key, label = S[STAGE_LABEL[key]], fraction = 0 }
			if info.total == 0 then
				stage.state, stage.fraction = "same", 1
			elseif position < current then
				stage.state, stage.fraction = "done", 1
			elseif position == current then
				stage.state = "running"
			else
				stage.state = "pending"
			end

			-- how it went: from the verdict once the load is over; while it runs, only what is already known
			local severity = verdict and verdict.stages[key] or nil
			if not verdict then
				if key == "gear" then
					local _, flagged = GearProgress(job, info)
					severity = flagged and "error" or nil
				elseif key == "skills" and job.skillError then
					severity = "error"
				elseif key == "champion" and job.champError then
					severity = "error"
				end
			end
			if severity and stage.state ~= "pending" then
				if stage.state == "running" then
					stage.flag = severity -- still going, but something is already wrong
				else
					stage.state = severity
				end
			end

			if key == "gear" and info.total > 0 and stage.state == "running" then
				local settled = GearProgress(job, info)
				stage.fraction = math.min(settled, info.total) / info.total
				stage.text = string.format("%d/%d", settled, info.total)
			elseif key == "gear" and info.total > 0 and stage.state == "error" then
				-- a gear stage that went wrong says how far it got ("13/14"), not just that it failed
				local left = info.total - GearOnCount(job, info)
				stage.text = left > 0 and string.format("%d/%d", info.total - left, info.total) or S[STATE_TEXT.error]
			else
				stage.text = S[STATE_TEXT[stage.state]]
			end

			sum = sum + stage.fraction
			if severity == "error" or (severity == "warn" and worst ~= "error") then
				worst = severity
			end
			stages[#stages + 1] = stage
		end
	end

	-- a reason that belongs to no stage (the Mundus Stone) colours the title, not a segment
	local other = verdict and verdict.other or nil
	if other == "error" or (other == "warn" and worst ~= "error") then
		worst = other
	end

	local model = { stages = stages, problems = worst }
	model.percent = #stages > 0 and math.floor(sum / #stages * 100 + 0.5) or 0
	local name = job.set and job.set.name or ""
	if verdict then
		model.title = string.format(verdict.problems and S.loadedProblems or S.loaded, name)
	else
		model.title = string.format(S.loading, name)
	end
	model.finished = verdict ~= nil
	return model
end

-- A string that changes when anything the model shows changes: the controls are only touched then.
local function Signature(model, where)
	local parts = { where, model.title, model.percent, tostring(model.problems) }
	for _, stage in ipairs(model.stages) do
		parts[#parts + 1] = table.concat({ stage.key, stage.state, string.format("%.3f", stage.fraction), stage.text or "", tostring(stage.flag) }, ":")
	end
	return table.concat(parts, "|")
end

-- ---------------------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------------------

local counter = 0
local function Unique(suffix)
	counter = counter + 1
	return NAME .. suffix .. counter
end

local function Texture(parent, color)
	local texture = WINDOW_MANAGER:CreateControl(Unique("Tex"), parent, CT_TEXTURE)
	texture:SetColor(color[1], color[2], color[3], color[4])
	return texture
end

-- One line of text that ends in "..." rather than wrapping into the line below.
local function Label(parent, font, width, height)
	local label = WINDOW_MANAGER:CreateControl(Unique("Label"), parent, CT_LABEL)
	label:SetFont(font)
	label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	label:SetMaxLineCount(1)
	label:SetDimensions(width, height)
	if label.SetVerticalAlignment and TEXT_ALIGN_CENTER then
		label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	end
	return label
end

local function Place(control, parent, x, y)
	control:ClearAnchors()
	control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
end

local function Paint(control, color)
	control:SetColor(color[1], color[2], color[3], color[4])
end

function progress:Create()
	if self.control then
		return self.control
	end
	if not (WINDOW_MANAGER and GuiRoot) then
		return nil
	end

	local top = WINDOW_MANAGER:CreateTopLevelWindow(NAME)
	top:SetHidden(true)
	top:SetMouseEnabled(false)
	top:SetDrawLayer(DL_OVERLAY)
	top:SetDrawTier(DT_HIGH)
	self.control = top

	-- the background and a thin pink edge, created first so that everything else is drawn over them
	local fill = Texture(top, { 0, 0, 0, 0.8 })
	fill:SetAnchor(TOPLEFT, top, TOPLEFT, 0, 0)
	fill:SetAnchor(BOTTOMRIGHT, top, BOTTOMRIGHT, 0, 0)
	for _, edge in ipairs({
		{ TOPLEFT, TOPRIGHT, "height" }, { BOTTOMLEFT, BOTTOMRIGHT, "height" },
		{ TOPLEFT, BOTTOMLEFT, "width" }, { TOPRIGHT, BOTTOMRIGHT, "width" },
	}) do
		local line = Texture(top, { PINK[1], PINK[2], PINK[3], 0.9 })
		line:SetAnchor(edge[1], top, edge[1], 0, 0)
		line:SetAnchor(edge[2], top, edge[2], 0, 0)
		if edge[3] == "height" then
			line:SetHeight(2)
		else
			line:SetWidth(2)
		end
	end

	local contentWidth = WIDTH - 2 * PAD
	self.contentWidth = contentWidth
	local y = PAD
	self.title = Label(top, FONT_TITLE, contentWidth - PERCENT_WIDTH, TITLE_HEIGHT)
	Place(self.title, top, PAD, y)
	self.percent = Label(top, FONT_TITLE, PERCENT_WIDTH, TITLE_HEIGHT)
	Place(self.percent, top, PAD + contentWidth - PERCENT_WIDTH, y)
	if self.percent.SetHorizontalAlignment and TEXT_ALIGN_RIGHT then
		self.percent:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
	end
	Paint(self.percent, PINK)
	y = y + TITLE_HEIGHT + 8
	self.barTop = y
	y = y + BAR_HEIGHT + 6

	-- three segments; which of them are used, and how wide each is, depends on the load (see Draw)
	self.cells = {}
	for i = 1, #ORDER do
		local cell = {}
		cell.track = Texture(top, TRACK)
		cell.glow = Texture(top, GLOW)
		cell.fill = Texture(top, PINK)
		cell.name = Label(top, FONT_NAME, contentWidth, NAME_HEIGHT)
		cell.state = Label(top, FONT_STATE, contentWidth, STATE_HEIGHT)
		self.cells[i] = cell
	end
	self.nameTop = y
	self.stateTop = y + NAME_HEIGHT
	y = self.stateTop + STATE_HEIGHT + PAD

	top:SetDimensions(WIDTH, y)
	self.height = y
	return top
end

-- In the settings panel the preview window is at the right; the bar goes beside the list instead. Anywhere else it
-- goes to the bottom of the screen.
function progress:InPanel()
	local preview = A.preview
	if not (preview and preview.forPanel) then
		return false
	end
	local scene = preview.panelScene
	return type(scene) == "table" and type(scene.IsShowing) == "function" and scene:IsShowing() == true
end

function progress:Place()
	local where = self:InPanel() and "panel" or "hud"
	if self.placed ~= where then
		self.placed = where
		self.control:ClearAnchors()
		if where == "panel" then
			self.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, PANEL_LEFT, ZO_GAMEPAD_QUADRANT_TOP_OFFSET or 54)
		else
			self.control:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, HUD_BOTTOM)
		end
	end
	return where
end

function progress:Draw(model)
	local count = #model.stages
	self.title:SetText(model.title)
	Paint(self.title, model.problems == "error" and RED or model.problems == "warn" and YELLOW or WHITE)
	self.percent:SetText(string.format("%d%%", model.percent))

	local width = math.floor((self.contentWidth - SEGMENT_GAP * (count - 1)) / math.max(count, 1))
	for i, cell in ipairs(self.cells) do
		local stage = model.stages[i]
		if not stage then
			for _, control in pairs(cell) do
				control:SetHidden(true)
			end
		else
			local x = PAD + (i - 1) * (width + SEGMENT_GAP)
			cell.track:SetDimensions(width, BAR_HEIGHT)
			Place(cell.track, self.control, x, self.barTop)
			cell.track:SetHidden(false)

			-- lit while the request is out, filled by what is done, solid when over
			cell.glow:SetDimensions(width, BAR_HEIGHT)
			Place(cell.glow, self.control, x, self.barTop)
			cell.glow:SetHidden(stage.state ~= "running")

			local filled = math.floor(width * stage.fraction + 0.5)
			if filled > 0 then
				Paint(cell.fill, FILL_COLOR[stage.state] or FILL_COLOR.running)
				cell.fill:SetDimensions(filled, BAR_HEIGHT)
				Place(cell.fill, self.control, x, self.barTop)
			end
			cell.fill:SetHidden(filled <= 0)

			cell.name:SetDimensions(width, NAME_HEIGHT)
			Place(cell.name, self.control, x, self.nameTop)
			cell.name:SetText(stage.label)
			Paint(cell.name, stage.state == "pending" and DIM or WHITE)
			cell.name:SetHidden(false)
			cell.state:SetDimensions(width, STATE_HEIGHT)
			Place(cell.state, self.control, x, self.stateTop)
			cell.state:SetText(stage.text)
			Paint(cell.state, stage.flag == "error" and RED or stage.flag == "warn" and YELLOW or TEXT_COLOR[stage.state])
			cell.state:SetHidden(false)
		end
	end
end

-- Draw only when something changed. Never raises: the error is kept for /pbec status.
function progress:Refresh(model)
	local ok, err = pcall(function()
		local where = self:Place()
		local signature = Signature(model, where)
		if signature ~= self.signature then
			self.signature = signature
			self:Draw(model)
		end
	end)
	self.lastError = (not ok) and tostring(err) or nil
end

-- ---------------------------------------------------------------------------------------
-- Following a load
-- ---------------------------------------------------------------------------------------

function progress:IsShown()
	return self.control ~= nil and not self.control:IsHidden()
end

function progress:Hide()
	if self.control then
		self.control:SetHidden(true)
	end
	self.placed, self.signature = nil, nil
end

-- Called after every tick of the load. The window comes up on the first tick of the update loop that finds the load still
-- going (`fromPoll`), so a load that is over at once shows nothing, and nothing is created in the caller's context.
function progress:Tick(job, fromPoll)
	if not (A.sv and A.sv.progress) then
		if self.job == job then
			self:Hide()
			self.job = nil
		end
		return
	end
	if self.job ~= job then
		if not fromPoll then
			return
		end
		local ok, err = pcall(function()
			if not (job.plan and (job.plan.gear or job.plan.skills or job.plan.champion)) or not self:Create() then
				error("nothing to show", 0)
			end
		end)
		if not ok then
			-- no stage to show (every part switched off) is not an error; a window that could not be made is
			self.lastError = err ~= "nothing to show" and tostring(err) or nil
			return
		end
		self.job, self.signature = job, nil
		-- a hide timer of an earlier load must not hide this one
		self.holdToken = (self.holdToken or 0) + 1
		-- drawn and placed first, shown after: the window never appears unanchored
		self:Refresh(A:ProgressModel(job))
		self.control:SetHidden(false)
		return
	end
	self:Refresh(A:ProgressModel(job))
end

-- The load is over: show the result (all segments settled, the colours the verdict gave), then let go of it.
function progress:Finish(job, verdict)
	if self.job ~= job then
		return
	end
	self.job = nil
	self:Refresh(A:ProgressModel(job, verdict))
	self.holdToken = (self.holdToken or 0) + 1
	local token = self.holdToken
	if zo_callLater then
		zo_callLater(function()
			if self.holdToken == token then
				self:Hide()
			end
		end, (verdict and verdict.problems) and HOLD_PROBLEMS_MS or HOLD_MS)
	else
		self:Hide()
	end
end

-- The load was cut short.
function progress:Abort(job)
	if self.job == job then
		self.job = nil
		self.holdToken = (self.holdToken or 0) + 1
		self:Hide()
	end
end

-- The option was switched off while a bar is up.
function progress:OptionChanged()
	if not (A.sv and A.sv.progress) then
		self.job = nil
		self.holdToken = (self.holdToken or 0) + 1
		self:Hide()
	end
end
