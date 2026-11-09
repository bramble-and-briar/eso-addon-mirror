-- The preview of a saved set, drawn beside the settings panel.
--
-- LibHarvensAddonSettings can show an info panel for a row (its `tooltip`), but on a console that is one gamepad
-- quadrant wide (470 units) in the client's body font (size 42): about a dozen characters a line, where a set
-- holds up to sixteen pieces of gear, twelve skills and twelve champion stars. So the panel stays the list of
-- actions, and the contents are drawn in a window of our own on the right, built from plain controls (a
-- top-level window, textures and labels: no client template and no client function), the way PB's Chat Window
-- Customizer draws its preview, which was measured on a PS5.
--
-- Two parts:
--   A:PreviewModel(index)  what to show for a slot, as plain data (no controls): testable, and the one place that
--                          decides what is red (cannot be used now) or yellow (differs from when saved)
--   preview                the window: created once, filled by Update(), shown while this add-on's panel is open
--
-- Red and yellow use the checks a load makes (the backpack, SKILLS_DATA_MANAGER, the champion points, the
-- subclass), so the preview tells what a load would run into without loading.

local A, S = PBS_EQUIPMENT_CHANGER, PBS_EQUIPMENT_CHANGER_STRINGS

local OK, MISSING, DIFFERENT, EMPTY = "ok", "missing", "different", "empty"
A.PREVIEW_STATES = { ok = OK, missing = MISSING, different = DIFFERENT, empty = EMPTY }

-- ---------------------------------------------------------------------------------------
-- What to show
-- ---------------------------------------------------------------------------------------

-- The word the game itself uses for a worn slot, in the player's language ("Main Hand", "利き手").
local function SlotName(def)
	if GetString and def.slot then
		local ok, text = pcall(GetString, "SI_EQUIPSLOT", def.slot)
		if ok and type(text) == "string" and text ~= "" then
			return text
		end
	end
	return def.key
end

-- Can a load find this piece of gear? Worn now, worn in another slot, or in the backpack.
function A:PreviewGearState(def, want)
	local ok, found = pcall(function()
		return self:InPlace(def, want) == true or self:FindInBackpack(def, want) ~= nil or self:FindWorn(def, want) ~= nil
	end)
	if not ok then
		return OK
	end
	return found and OK or MISSING
end

-- Can a load slot this skill? Not unlocked / not scribed: no. Another morph or other scripts: yes, but not as saved.
function A:PreviewSkillState(entry)
	local ok, actionType, _, info = pcall(self.ResolveSkill, self, entry)
	if not ok then
		return OK
	end
	if actionType == nil then
		return MISSING
	end
	if type(info) == "table" and (info.morphDiffers or info.scriptsDiffer) then
		return DIFFERENT
	end
	return OK
end

function A:PreviewModel(index)
	local set = self:GetSet(index)
	local model = { index = index }
	if not set then
		model.empty = true
		model.title = string.format(S.slotInfoEmpty, index)
		model.hint = S.previewEmpty
		return model
	end
	model.title = self:SlotLabel(index)
	model.summary = self:Describe(set)

	local problems = { [MISSING] = 0, [DIFFERENT] = 0 }
	local function note(state)
		if problems[state] then
			problems[state] = problems[state] + 1
		end
		return state
	end

	if set.gear then
		local rows = {}
		for _, def in ipairs(self.GEAR) do
			local want = set.gear[def.key]
			if want and def.slot then
				rows[#rows + 1] = { label = SlotName(def), name = want.name or def.key, icon = want.icon, state = note(self:PreviewGearState(def, want)) }
			end
		end
		model.gear = rows
	end

	if set.bars then
		local bars = {}
		local first, last = self:SkillSlotRange()
		for _, bar in ipairs(self.BARS) do
			local saved = type(set.bars[bar.key]) == "table" and set.bars[bar.key] or nil
			local rows = {}
			for slot = first, last do
				local entry = saved and saved[slot]
				if entry then
					rows[#rows + 1] = { name = entry.name or tostring(entry.id), icon = entry.icon, state = note(self:PreviewSkillState(entry)) }
				else
					rows[#rows + 1] = { state = EMPTY }
				end
			end
			bars[#bars + 1] = { key = bar.key, caption = bar.key == "primary" and S.previewBarPrimary or S.previewBarBackup, rows = rows }
		end
		model.bars = bars
	end

	if set.champion then
		local rows = {}
		local first, last = self:ChampionSlotRange()
		for slot = first, last do
			local saved = set.champion[slot]
			if saved then
				rows[#rows + 1] = { name = saved.name or tostring(saved.id), state = note(self:ChampionUsable(saved.id) and OK or MISSING) }
			else
				rows[#rows + 1] = { state = EMPTY }
			end
		end
		model.champion = rows
	end

	if type(set.class) == "table" then
		local _, kinds = self:ClassStateNotes(set)
		local differs = {}
		for _, kind in ipairs(kinds) do
			differs[kind] = true
		end
		model.class = {
			{ text = string.format(S.previewSubclass, A.LinesText(set.class.lines)), state = note(differs.subclass and DIFFERENT or OK) },
			{ text = string.format(S.previewMastery, A.MasteryText(set.class)), state = note(differs.mastery and DIFFERENT or OK) },
		}
	end

	-- the Mundus Stone the set was saved with (yellow when it is not the one active now); beside the summary line
	if type(set.mundus) == "table" then
		model.mundus = {
			text = string.format(S.previewMundus, A.MundusText(set.mundus)),
			state = note(self:MundusNote(set) and DIFFERENT or OK),
		}
	end

	if problems[MISSING] > 0 or problems[DIFFERENT] > 0 then
		model.legend = S.previewLegend
	end
	return model
end

-- ---------------------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------------------

local preview = {
	gear = {},
	skills = { primary = {}, backup = {} },
	champion = {},
	class = {},
}
A.preview = preview

local NAME = "PBsEquipmentChangerPreview"

-- UI units: the gamepad UI is laid out on 1920 x 1080 (ZO_GAMEPAD_UI_REFERENCE_WIDTH), with a safe zone of 96 x 54.
local WIDTH = 820
local PAD = 18
local COLUMN_GAP = 24
local ROW = 30
local ICON = 26
local ICON_GAP = 8
local EMPTY_HEIGHT = 190 -- an empty slot needs only the title and the hint
local GEAR_ROWS = 8
local CHAMPION_ROWS = 4
local SKILL_ROWS = 6 -- what the bars have (slots 3 to 8)
local CHECK_INTERVAL_MS = 250

local PINK = { 1, 0.41, 0.71 }
local COLORS = {
	[OK] = { 1, 1, 1, 1 },
	[MISSING] = { 1, 0.45, 0.45, 1 },
	[DIFFERENT] = { 1, 0.82, 0.35, 1 },
	[EMPTY] = { 1, 1, 1, 0.4 },
}
local DIM = { 1, 1, 1, 0.6 }

-- Named fonts the gamepad UI has already built.
local FONT_TITLE, FONT_HEADER, FONT_ROW, FONT_SMALL = "ZoFontGamepad34", "ZoFontGamepad27", "ZoFontGamepad22", "ZoFontGamepad18"

local counter = 0
local function Unique(suffix)
	counter = counter + 1
	return NAME .. suffix .. counter
end

local function Texture(parent, r, g, b, a)
	local texture = WINDOW_MANAGER:CreateControl(Unique("Tex"), parent, CT_TEXTURE)
	texture:SetColor(r, g, b, a)
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

local function Paint(label, color)
	label:SetColor(color[1], color[2], color[3], color[4])
end

function preview:Create()
	if self.control then
		return self.control
	end
	if not (WINDOW_MANAGER and GuiRoot) then
		return nil
	end

	local top = WINDOW_MANAGER:CreateTopLevelWindow(NAME)
	top:SetHidden(true)
	top:SetMouseEnabled(false)
	-- above the settings panel, which is what it is drawn beside
	top:SetDrawLayer(DL_OVERLAY)
	top:SetDrawTier(DT_HIGH)
	self.control = top

	-- the background and a thin pink edge, created first so that everything else is drawn over them
	local fill = Texture(top, 0, 0, 0, 0.8)
	fill:SetAnchor(TOPLEFT, top, TOPLEFT, 0, 0)
	fill:SetAnchor(BOTTOMRIGHT, top, BOTTOMRIGHT, 0, 0)
	local edges = {
		{ TOPLEFT, TOPRIGHT, "height" },
		{ BOTTOMLEFT, BOTTOMRIGHT, "height" },
		{ TOPLEFT, BOTTOMLEFT, "width" },
		{ TOPRIGHT, BOTTOMRIGHT, "width" },
	}
	for _, edge in ipairs(edges) do
		local line = Texture(top, PINK[1], PINK[2], PINK[3], 0.9)
		line:SetAnchor(edge[1], top, edge[1], 0, 0)
		line:SetAnchor(edge[2], top, edge[2], 0, 0)
		if edge[3] == "height" then
			line:SetHeight(2)
		else
			line:SetWidth(2)
		end
	end

	-- the slot words are longer in some languages ("Main Hand Backup") than in others ("利き手予備"): the width of that column
	-- is a language string
	local SLOT_LABEL_WIDTH = tonumber(S.previewSlotWidth) or 120
	local contentWidth = WIDTH - 2 * PAD
	local columnWidth = math.floor((contentWidth - COLUMN_GAP) / 2)
	local championWidth = math.floor((contentWidth - 2 * COLUMN_GAP) / 3)

	-- Rows are laid out once, top to bottom; Update() only changes what they say.
	local y = PAD
	self.title = Label(top, FONT_TITLE, contentWidth, 44)
	Place(self.title, top, PAD, y)
	y = y + 44
	-- the summary and, at the right on the same line, the Mundus Stone (the window has no row to spare)
	local mundusWidth = tonumber(S.previewMundusWidth) or 300
	self.subtitle = Label(top, FONT_ROW, contentWidth - mundusWidth - COLUMN_GAP, 30)
	Place(self.subtitle, top, PAD, y)
	self.mundus = Label(top, FONT_SMALL, mundusWidth, 30)
	Place(self.mundus, top, PAD + contentWidth - mundusWidth, y)
	if self.mundus.SetHorizontalAlignment and TEXT_ALIGN_RIGHT then
		self.mundus:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
	end
	y = y + 30 + 6

	local function header(key)
		local label = Label(top, FONT_HEADER, contentWidth, 36)
		Place(label, top, PAD, y)
		Paint(label, PINK)
		y = y + 36
		self[key] = label
		return label
	end

	header("gearHeader")
	local gearTop = y
	for i = 1, GEAR_ROWS * 2 do
		local column, row = math.floor((i - 1) / GEAR_ROWS), (i - 1) % GEAR_ROWS
		local x = PAD + column * (columnWidth + COLUMN_GAP)
		local cell = {}
		cell.slot = Label(top, FONT_SMALL, SLOT_LABEL_WIDTH, ROW)
		Place(cell.slot, top, x, gearTop + row * ROW)
		cell.icon = Texture(top, 1, 1, 1, 1)
		cell.icon:SetDimensions(ICON, ICON)
		Place(cell.icon, top, x + SLOT_LABEL_WIDTH, gearTop + row * ROW + math.floor((ROW - ICON) / 2))
		cell.name = Label(top, FONT_ROW, columnWidth - SLOT_LABEL_WIDTH - ICON - ICON_GAP, ROW)
		Place(cell.name, top, x + SLOT_LABEL_WIDTH + ICON + ICON_GAP, gearTop + row * ROW)
		self.gear[i] = cell
	end
	y = gearTop + GEAR_ROWS * ROW + 4

	header("skillsHeader")
	for barIndex, key in ipairs({ "primary", "backup" }) do
		local x = PAD + (barIndex - 1) * (columnWidth + COLUMN_GAP)
		local caption = Label(top, FONT_ROW, columnWidth, 28)
		Place(caption, top, x, y)
		Paint(caption, DIM)
		self.skills[key].caption = caption
		for i = 1, SKILL_ROWS do
			local cell = {}
			cell.icon = Texture(top, 1, 1, 1, 1)
			cell.icon:SetDimensions(ICON, ICON)
			Place(cell.icon, top, x, y + 28 + (i - 1) * ROW + math.floor((ROW - ICON) / 2))
			cell.name = Label(top, FONT_ROW, columnWidth - ICON - ICON_GAP, ROW)
			Place(cell.name, top, x + ICON + ICON_GAP, y + 28 + (i - 1) * ROW)
			self.skills[key][i] = cell
		end
	end
	y = y + 28 + 6 * ROW + 4

	header("championHeader")
	local championTop = y
	for i = 1, CHAMPION_ROWS * 3 do
		local column, row = math.floor((i - 1) / CHAMPION_ROWS), (i - 1) % CHAMPION_ROWS
		local label = Label(top, FONT_ROW, championWidth, ROW)
		Place(label, top, PAD + column * (championWidth + COLUMN_GAP), championTop + row * ROW)
		self.champion[i] = label
	end
	y = championTop + CHAMPION_ROWS * ROW + 4

	for i = 1, 2 do
		local label = Label(top, FONT_ROW, contentWidth, ROW)
		Place(label, top, PAD, y)
		self.class[i] = label
		y = y + ROW
	end
	self.legend = Label(top, FONT_SMALL, contentWidth, 26)
	Place(self.legend, top, PAD, y)
	Paint(self.legend, DIM)
	y = y + 26 + PAD

	-- the empty slot's hint is a wrapped paragraph, not a line
	self.hint = WINDOW_MANAGER:CreateControl(Unique("Hint"), top, CT_LABEL)
	self.hint:SetFont(FONT_ROW)
	self.hint:SetDimensions(contentWidth, 120)
	Place(self.hint, top, PAD, 100)
	Paint(self.hint, DIM)

	-- Beside the panel's list, at the right edge of the safe zone, from the top of the quadrants down.
	self.fullHeight = y
	top:SetDimensions(WIDTH, y)
	top:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, ZO_GAMEPAD_QUADRANT_4_RIGHT_OFFSET or -56, ZO_GAMEPAD_QUADRANT_TOP_OFFSET or 54)

	-- Checked a few times a second while shown: the window goes away by itself once the panel it belongs to is no
	-- longer on screen, whichever way the player left it.
	local nextCheck = 0
	top:SetHandler("OnUpdate", function()
		local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
		if now < nextCheck then
			return
		end
		nextCheck = now + CHECK_INTERVAL_MS
		if not preview:StillWanted() then
			preview:Hide()
		end
	end)
	return top
end

local function SetCellIcon(texture, icon)
	if type(icon) == "string" and icon ~= "" then
		texture:SetTexture(icon)
		texture:SetHidden(false)
	else
		texture:SetHidden(true)
	end
end

local function ClearCell(cell)
	if cell.slot then
		cell.slot:SetHidden(true)
	end
	if cell.icon then
		cell.icon:SetHidden(true)
	end
	if cell.name then
		cell.name:SetHidden(true)
	end
end

-- Fill a list of cells (each an icon and a name) from model rows; a section the set does not hold says so on its first row.
local function FillCells(cells, rows, count, withSlot)
	for i = 1, count do
		local cell, row = cells[i], rows and rows[i]
		if cell then
			ClearCell(cell)
			if row and row.name then
				cell.name:SetText(row.name)
				Paint(cell.name, COLORS[row.state] or COLORS[OK])
				cell.name:SetHidden(false)
				SetCellIcon(cell.icon, row.icon)
				if withSlot then
					cell.slot:SetText(row.label or "")
					Paint(cell.slot, DIM)
					cell.slot:SetHidden(false)
				end
			elseif row and row.state == EMPTY then
				cell.name:SetText("-")
				Paint(cell.name, COLORS[EMPTY])
				cell.name:SetHidden(false)
			elseif not rows and i == 1 then
				cell.name:SetText(S.previewNotSaved)
				Paint(cell.name, COLORS[EMPTY])
				cell.name:SetHidden(false)
			end
		end
	end
end

local function SetText(label, text, color)
	label:SetText(text or "")
	if color then
		Paint(label, color)
	end
	label:SetHidden(text == nil or text == "")
end

function preview:Draw(model)
	local empty = model.empty == true
	-- the window is only as tall as what it shows
	self.control:SetHeight(empty and EMPTY_HEIGHT or self.fullHeight)
	SetText(self.title, model.title, COLORS[OK])
	SetText(self.subtitle, model.summary, DIM)
	SetText(self.mundus, (not empty) and model.mundus and model.mundus.text or nil, model.mundus and COLORS[model.mundus.state] or COLORS[OK])

	SetText(self.hint, empty and model.hint or nil, DIM)
	self.hint:SetHidden(not empty)

	for _, key in ipairs({ "gearHeader", "skillsHeader", "championHeader" }) do
		self[key]:SetHidden(empty)
	end
	self.gearHeader:SetText(S.previewGear)
	self.skillsHeader:SetText(S.previewSkills)
	self.championHeader:SetText(S.previewChampion)

	-- gear
	FillCells(self.gear, model.gear, #self.gear, true)
	for i = 1, #self.gear do
		if empty then
			ClearCell(self.gear[i])
		end
	end

	-- the two skill bars
	for index, key in ipairs({ "primary", "backup" }) do
		local group = self.skills[key]
		local bar = model.bars and model.bars[index]
		SetText(group.caption, (not empty) and (bar and bar.caption or (key == "primary" and S.previewBarPrimary or S.previewBarBackup)) or nil)
		FillCells(group, bar and bar.rows or nil, SKILL_ROWS, false)
		for i = 1, SKILL_ROWS do
			if empty then
				ClearCell(group[i])
			end
		end
	end

	-- champion bar
	for i = 1, #self.champion do
		local label, row = self.champion[i], model.champion and model.champion[i]
		if empty then
			label:SetHidden(true)
		elseif row and row.name then
			SetText(label, row.name, COLORS[row.state] or COLORS[OK])
		elseif row then
			SetText(label, "-", COLORS[EMPTY])
		elseif not model.champion and i == 1 then
			SetText(label, S.previewNotSaved, COLORS[EMPTY])
		else
			label:SetHidden(true)
		end
	end

	-- subclass and Class Mastery
	for i = 1, #self.class do
		local entry = model.class and model.class[i]
		SetText(self.class[i], (not empty) and entry and entry.text or nil, entry and COLORS[entry.state] or COLORS[OK])
	end
	SetText(self.legend, model.legend, DIM)
end

function preview:IsShown()
	return self.control ~= nil and not self.control:IsHidden()
end

-- Redraws the slot the panel is working on. Cheap, and a no-op while hidden. Never raises: a preview that fails
-- must not take the panel with it, so the error is kept for /pbec status instead.
function preview:Update()
	if not self:IsShown() then
		return
	end
	local ok, err = pcall(function()
		self:Draw(A:PreviewModel(A.sv and A.sv.slot or 1))
	end)
	self.lastError = (not ok) and tostring(err) or nil
end

function preview:Show()
	if not self:Create() then
		return false
	end
	self.scene = SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene and SCENE_MANAGER:GetCurrentScene() or nil
	self.control:SetHidden(false)
	self:Update()
	return true
end

function preview:Hide()
	if self.control then
		self.control:SetHidden(true)
	end
	self.forPanel = false
end

-- Whether the panel is still on screen: the scene the window was shown in, and the panel itself. The library marks the
-- selected add-on's panel with .selected; a copy of the library that does not is judged by the scene alone.
function preview:StillWanted()
	if not self.forPanel then
		return false
	end
	local current = SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene and SCENE_MANAGER:GetCurrentScene() or nil
	if current ~= self.scene then
		return false
	end
	if not (A.sv and A.sv.preview) then
		return false
	end
	local panel = A.panel
	if panel and panel.selected == false then
		return false
	end
	return true
end

-- ---------------------------------------------------------------------------------------
-- Following the settings panel
--
-- On console the library opens a panel in two steps (LibHarvensAddonSettings, Console/Settings.lua):
--
--   addon:Select()                                      fires AddonSelected, then sets .selected
--   SCENE_MANAGER:Push("LibHarvensAddonSettingsScene")  and only then shows the panel
--
-- So AddonSelected arrives while the add-on list is still the current scene, and Select() returns early for the
-- add-on already selected, so a second visit to the same panel fires nothing at all. The panel scene itself is the
-- reliable signal: shown with our panel selected means the window is wanted, hiding means it is not. (Measured on a
-- PS5 in PB's Chat Window Customizer, which does the same.) The scene exists only once the library has initialised,
-- which it does the first time the main menu opens -- after every add-on has loaded -- so it is looked up when a
-- panel is picked, not at load.
-- ---------------------------------------------------------------------------------------

local PANEL_SCENE_NAME = "LibHarvensAddonSettingsScene"

function preview:PanelScene()
	local library = LibHarvensAddonSettings
	local scene = library and library.scene
	if not scene and SCENE_MANAGER and type(SCENE_MANAGER.GetScene) == "function" then
		scene = SCENE_MANAGER:GetScene(PANEL_SCENE_NAME)
	end
	if type(scene) == "table" and type(scene.RegisterCallback) == "function" then
		return scene
	end
	return nil
end

-- Registered on the library's scene, beside the library's own callbacks. Once only.
function preview:WatchPanelScene()
	if self.panelScene then
		return self.panelScene
	end
	local scene = self:PanelScene()
	if not scene then
		return nil
	end
	self.panelScene = scene
	scene:RegisterCallback("StateChange", function(_, newState)
		if newState == SCENE_SHOWN then
			local panel = A.panel
			self:SetPanelOpen(panel ~= nil and panel.selected == true)
		elseif newState == SCENE_HIDING then
			self:SetPanelOpen(false)
		end
	end)
	return scene
end

-- LibHarvensAddonSettings_AddonSelected. On console the panel scene is not up yet, and its SCENE_SHOWN does the
-- showing; the PC copy of the library has no such scene and shows the panel in place, so there it goes up at once.
function preview:OnAddonSelected(addonSettings)
	local scene = self:WatchPanelScene()
	if addonSettings ~= A.panel then
		self:SetPanelOpen(false)
		return
	end
	if scene and not (type(scene.IsShowing) == "function" and scene:IsShowing()) then
		return
	end
	self:SetPanelOpen(true)
end

-- The settings panel was opened (true) or another add-on's panel was picked (false).
function preview:SetPanelOpen(open)
	self.forPanel = open and true or false
	if self.forPanel and A.sv and A.sv.preview then
		self:Show()
	else
		self:Hide()
	end
end

-- The option was switched on or off while the panel is open.
function preview:OptionChanged()
	if A.sv.preview then
		if self.panelScene and type(self.panelScene.IsShowing) == "function" and self.panelScene:IsShowing() and A.panel and A.panel.selected then
			self:SetPanelOpen(true)
		end
	else
		self:Hide()
	end
end
