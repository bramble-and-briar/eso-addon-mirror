-- The crafting panel: while a station is open, what the add-on is doing there.
--
-- A console hides the chat window while the crafting screen is up, so the chat cannot say what happens at a station.
-- This is a small window of its own, drawn above the crafting screen while a station is open (and only then):
--   header   PB's Craft Assistant - <the station's craft>
--   state    what the add-on is doing now (crafting X, waiting for the game, done, switched off ...)
--   lines    every writ line for this station: done / being crafted / waiting / could not be made (and why) /
--            an "acquire" line that no station makes
--   counts   what the journal holds (writs, lines, lines for this station / other stations / switched-off crafts,
--            and the condition types the game reported) -- the measurement to ask for when nothing is crafted
--
-- Built in Lua from plain labels and one fill texture, the way PB's other PS5 add-ons draw their windows (no client
-- template, no hook). Nothing is redrawn per frame: the panel is rewritten on the add-on's own steps and when a writ
-- counter moves, and a label is only touched when its text or colour changes.

local A, S = PBS_CRAFT_ASSIST, PBS_CRAFT_ASSIST_STRINGS

local NAME = "PBsCraftAssistantPanel"
local WIDTH = 680
local PAD = 16
local HEAD_H, STATE_H, ROW_H, DIAG_H = 38, 32, 30, 26
local MAX_ROWS = 12
local HEAD_FONT, STATE_FONT, ROW_FONT, DIAG_FONT = "ZoFontGamepad27", "ZoFontGamepad22", "ZoFontGamepad22", "ZoFontGamepad18"

local WHITE = { 0.92, 0.92, 0.92 }
local PINK = { 1, 0.41, 0.71 }
local GREEN = { 0.45, 1, 0.55 }
local YELLOW = { 1, 0.85, 0.3 }
local RED = { 1, 0.5, 0.5 }
local GREY = { 0.62, 0.62, 0.62 }

A.POSITIONS = { "topright", "top", "topleft" }

local function NewLabel(name, parent, font)
	local c = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
	c:SetDrawLayer(DL_TEXT)
	c:SetMouseEnabled(false)
	c:SetFont(font)
	c:SetMaxLineCount(1)
	c:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	c:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
	c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	c:SetHidden(true)
	return { ctl = c, hidden = true }
end

-- Write to a label only when something changes; place it at y.
local function Put(label, text, color, y, height)
	local c = label.ctl
	if label.y ~= y or label.h ~= height then
		c:ClearAnchors()
		c:SetAnchor(TOPLEFT, c:GetParent(), TOPLEFT, PAD, y)
		c:SetDimensions(WIDTH - 2 * PAD, height)
		label.y, label.h = y, height
	end
	if label.text ~= text then
		c:SetText(text)
		label.text = text
	end
	if label.color ~= color then
		c:SetColor(color[1], color[2], color[3], 1)
		label.color = color
	end
	if label.hidden then
		c:SetHidden(false)
		label.hidden = false
	end
end

local function Hide(label)
	if not label.hidden then
		label.ctl:SetHidden(true)
		label.hidden = true
	end
end

function A:CreatePanel()
	if self.ui then
		return self.ui
	end
	local top = WINDOW_MANAGER:CreateTopLevelWindow(NAME)
	top:SetHidden(true)
	top:SetMouseEnabled(false)
	top:SetMovable(false)
	top:SetDrawTier(DT_HIGH)
	top:SetDrawLayer(DL_OVERLAY)
	top:SetDimensions(WIDTH, 200)
	-- the background first: siblings draw in the order they were made
	local fill = WINDOW_MANAGER:CreateControl(NAME .. "Fill", top, CT_TEXTURE)
	fill:SetAnchorFill(top)
	fill:SetColor(0, 0, 0, 0.78)
	fill:SetMouseEnabled(false)
	local ui = {
		top = top,
		fill = fill,
		head = NewLabel(NAME .. "Head", top, HEAD_FONT),
		state = NewLabel(NAME .. "State", top, STATE_FONT),
		rows = {},
		diag = NewLabel(NAME .. "Diag", top, DIAG_FONT),
		diag2 = NewLabel(NAME .. "Diag2", top, DIAG_FONT),
		shown = false,
		pos = nil,
	}
	for i = 1, MAX_ROWS do
		ui.rows[i] = NewLabel(NAME .. "Row" .. i, top, ROW_FONT)
	end
	self.ui = ui
	return ui
end

function A:PlacePanel()
	local ui = self.ui
	local pos = self.sv.panelPos
	if not ui or ui.pos == pos then
		return
	end
	ui.pos = pos
	local top = ui.top
	top:ClearAnchors()
	if pos == "topleft" then
		top:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 60, 90)
	elseif pos == "top" then
		top:SetAnchor(TOP, GuiRoot, TOP, 0, 90)
	else
		top:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -60, 90)
	end
end

function A:PanelShow()
	if not self.sv.panel or not WINDOW_MANAGER then
		return
	end
	local ok, err = pcall(self.CreatePanel, self)
	if not ok then
		self:NoteError(err)
		return
	end
	self:PlacePanel()
	self.ui.shown = true
	self.ui.top:SetHidden(false)
	self:PanelRefresh()
end

function A:PanelHide()
	local ui = self.ui
	if ui and ui.shown then
		ui.shown = false
		ui.top:SetHidden(true)
	end
end

-- The name in an item link (nil for none).
function A:LinkName(link)
	if type(link) ~= "string" or link == "" or not GetItemLinkName then
		return nil
	end
	local name = GetItemLinkName(link)
	if name and name ~= "" and zo_strformat then
		name = zo_strformat("<<1>>", name)
	end
	return (name and name ~= "") and name or nil
end

-- An item's name from its id: a last resort only. The id of a writ line is a generic item, and a link built from
-- it carries no material, so the name reads as the lowest one ("iron helmet" for a rubedite line). The panel uses
-- the journal's own line text, and the crafting state the link of what is actually crafted.
-- (cached; the cache is emptied when it grows past 64 names)
A.nameCache, A.nameCount = {}, 0
function A:ItemName(itemId)
	local name = self.nameCache[itemId]
	if name then
		return name
	end
	local link = string.format("|H1:item:%d:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId)
	name = GetItemLinkName and GetItemLinkName(link) or ""
	if name ~= "" and zo_strformat then
		name = zo_strformat("<<1>>", name)
	end
	if name == "" then
		name = "#" .. tostring(itemId)
	end
	if self.nameCount >= 64 then
		self.nameCache, self.nameCount = {}, 0
	end
	self.nameCache[itemId] = name
	self.nameCount = self.nameCount + 1
	return name
end

local function StateLine(self)
	local c = self.craft
	local st = c.state
	if st == "crafting" then
		return string.format(S.stCrafting, tostring(c.stateText), c.stateCount), YELLOW
	elseif st == "done" then
		return string.format(S.stDone, c.stateCount), GREEN
	elseif st == "partial" then
		return string.format(S.stPartial, c.stateCount), RED
	elseif st == "nothing" then
		return S.stNothing, WHITE
	elseif st == "busy" then
		return S.stBusy, YELLOW
	elseif st == "off" then
		return S.stOff, GREY
	elseif st == "autoOff" then
		return S.stAutoOff, GREY
	end
	return S.stStart, WHITE
end

A.panelLines = {} -- reused records for the panel's own scan (A.lines belongs to the craft rounds)

function A:PanelRefresh()
	local ui = self.ui
	if not (ui and ui.shown) then
		return
	end
	local ok, err = pcall(self.PanelDraw, self, ui)
	if not ok then
		self:NoteError(err)
	end
end

function A:PanelDraw(ui)
	local c = self.craft
	local station = c.station
	local stationName = (station and GetCraftingSkillName and GetCraftingSkillName(station)) or "?"
	local y = PAD
	Put(ui.head, string.format(S.panelHead, self.baseTitle, stationName), PINK, y, HEAD_H)
	y = y + HEAD_H
	local text, color = StateLine(self)
	Put(ui.state, text, color, y, STATE_H)
	y = y + STATE_H + 4

	-- every writ line for this station, done ones too
	local lines = self.panelLines
	local n = self:Scan(lines, true)
	local info = self.scanInfo
	local row = 0
	for i = 1, n do
		local rec = lines[i]
		if station and self:StationFor(rec) == station and row < MAX_ROWS then
			local key = rec.quest * 100 + rec.cond
			local state = c.lineState[key]
			local tag, tagColor
			if rec.done then
				tag, tagColor = S.tagDone, GREEN
			elseif state == "craft" then
				tag, tagColor = S.tagCraft, YELLOW
			elseif state == "made" then
				tag, tagColor = S.tagMade, GREEN
			elseif state == "fail" then
				tag, tagColor = S.tagFail, RED
			elseif state == "skip" then
				tag, tagColor = S.tagSkip, GREY
			elseif not self:CraftEnabled(rec.craftType) then
				tag, tagColor = S.tagOff, GREY
			else
				tag, tagColor = S.tagWait, WHITE
			end
			row = row + 1
			Put(ui.rows[row], string.format("%s  %s  %d/%d", tag, rec.text or self:ItemName(rec.itemId), rec.cur, rec.max), tagColor, y, ROW_H)
			y = y + ROW_H
			local why = c.lineReason[key]
			if why and (state == "fail" or state == "skip") and not rec.done and row < MAX_ROWS then
				row = row + 1
				Put(ui.rows[row], "      " .. why, state == "fail" and RED or GREY, y, ROW_H)
				y = y + ROW_H
			end
		end
	end
	if row == 0 then
		row = 1
		Put(ui.rows[1], S.panelNone, GREY, y, ROW_H)
		y = y + ROW_H
	end
	for i = row + 1, MAX_ROWS do
		Hide(ui.rows[i])
	end

	-- the counts: what to read out when nothing is crafted
	y = y + 6
	Put(ui.diag, string.format(S.panelDiag, info.quests, info.conditions, c.diagHere, c.diagOther, c.diagOff), GREY, y, DIAG_H)
	y = y + DIAG_H
	Put(ui.diag2, string.format(S.panelTypes, info.craft, info.gather, info.other, tostring(info.otherType or "-"),
		tostring(c.eventSkill), tostring(c.eventMode)), GREY, y, DIAG_H)
	y = y + DIAG_H
	ui.top:SetDimensions(WIDTH, y + PAD)
end

PBS_CA_MARK("Panel")
