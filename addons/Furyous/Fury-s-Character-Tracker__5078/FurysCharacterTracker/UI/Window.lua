-- The board (/fct): one row per character, one tab per group of columns.
-- What each cell says and how it looks is decided in Core/Board.lua; this file only draws it.
local CT = FurysCharacterTracker
local U = CT.Util
local Board = CT.Board
local X = CT.TEXT
local Win = {}
CT.Window = Win

local ROW_TYPE = 1
local ROW_HEIGHT = 28
local MAX_CELLS = 16
local GAP = 6
local ROW_WIDTH = 1368
local LIVE_MS = 60000   -- tabs with timers redraw once a minute while the board is open

-- Colors: violet tile = maxed, bar = in progress, dim dash = not started, blue = your own pick.
local T = CT.Theme                    -- Fury Night colors and fonts (UI/Theme.lua)
local VIOLET = T.RGB.VIOLET
local INK = T.RGB.VOID                -- text on a maxed tile
local TEXT = T.RGB.TEXT
local DIM = T.RGB.MUTED
local PICK = T.RGB.BLUE
local HEAD = T.RGB.BLUE               -- column headers
local SUB = T.RGB.SUB

-- The game's own sort arrows, drawn inside the column title.
local SORT_UP = " |t16:16:EsoUI/Art/Miscellaneous/list_sortUp.dds|t"
local SORT_DOWN = " |t16:16:EsoUI/Art/Miscellaneous/list_sortDown.dds|t"

local ALIGN = { left = TEXT_ALIGN_LEFT, center = TEXT_ALIGN_CENTER }

local function CurrentView()
    return Board.View()
end

-- Hover text --------------------------------------------------------------------------

-- Pinned to the mouse position on the screen, not to the cell: cells are reused and moved
-- every time the board redraws, and a tooltip pinned to one could end up anchored in a loop.
local function ShowTip(text)
    if not text or text == "" then return end
    local x, y = GetUIMousePosition()
    ClearTooltip(InformationTooltip)
    InitializeTooltip(InformationTooltip, GuiRoot, TOPLEFT, x + 18, y + 18, TOPLEFT)
    SetTooltipText(InformationTooltip, text)
end

local function HideTip()
    ClearTooltip(InformationTooltip)
end

-- Gives a control a hover text: `tipFn` returns it when the mouse comes in. Other windows of the
-- addon use this too.
local function SetTip(control, tipFn)
    control.furyTip = tipFn
    if not control.furyTipHooked then
        control.furyTipHooked = true
        control:SetHandler("OnMouseEnter", function(self)
            if self.furyRow then T.RowHover(self.furyRow, true) end
            if self.furyEnter then self.furyEnter(self) end
            if self.furyTip then ShowTip(self.furyTip()) end
        end)
        control:SetHandler("OnMouseExit", function(self)
            if self.furyRow then T.RowHover(self.furyRow, false) end
            if self.furyExit then self.furyExit(self) end
            HideTip()
        end)
    end
end
Win.SetTip, Win.HideTip = SetTip, HideTip

-- Setup -------------------------------------------------------------------------------

local function Button(name, parent, text, width, tip, onClick)
    local button = WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_DefaultButton")
    button:SetDimensions(width, 28)
    button:SetText(text)
    button:SetHandler("OnClicked", onClick)
    SetTip(button, function() return tip end)
    return button
end
Win.Button = Button

function Win:BuildTabs()
    self.tabs = {}
    local parent, x = FurysCharacterTracker_WindowViews, 0
    -- 1.7.0: with one more tab the row can run out of room, so the space around each title
    -- shrinks until every tab fits.
    local pad, textWidth, labels = 22, 0, {}
    for i, view in ipairs(CT.VIEWS) do
        local probe = WINDOW_MANAGER:CreateControl("FurysCharacterTracker_WindowTab" .. i, parent, CT_LABEL)
        probe:SetFont("$(BOLD_FONT)|16|soft-shadow-thin")
        probe:SetText(view.title)
        textWidth = textWidth + zo_round(probe:GetTextWidth())
        labels[i] = probe
    end
    local room = parent:GetWidth()
    if room > 0 and textWidth + #CT.VIEWS * (pad + 2) > room then
        pad = math.max(8, math.floor((room - textWidth) / #CT.VIEWS) - 2)
    end
    for i, view in ipairs(CT.VIEWS) do
        local label = labels[i]
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetMouseEnabled(true)
        local width = zo_round(label:GetTextWidth()) + pad
        label:SetDimensions(width, 30)
        label:SetAnchor(LEFT, parent, LEFT, x, 0)
        -- The violet line under the tab you are on.
        local line = T.Rect("FurysCharacterTracker_WindowTab" .. i .. "Line", parent, T.VIOLET, DL_CONTROLS, 2)
        line:SetAnchor(BOTTOMLEFT, label, BOTTOMLEFT, 4, 2)
        line:SetAnchor(BOTTOMRIGHT, label, BOTTOMRIGHT, -4, 2)
        line:SetHeight(3)
        local tab = { view = view, label = label, line = line }
        label.furyEnter = function() if not tab.active then label:SetColor(TEXT[1], TEXT[2], TEXT[3], 1) end end
        label.furyExit = function() self:PaintTab(tab) end
        SetTip(label, function() return view.tip end)
        label:SetHandler("OnMouseUp", function(_, _, upInside) if upInside then self:Show(view.id) end end)
        self.tabs[i] = tab
        x = x + width + 2
    end
end

function Win:PaintTab(tab)
    local rgb = tab.active and TEXT or SUB
    tab.label:SetColor(rgb[1], rgb[2], rgb[3], 1)
    tab.line:SetHidden(not tab.active)
end

function Win:Initialize()
    self.control = FurysCharacterTracker_Window
    self.list = FurysCharacterTracker_WindowList
    SCENE_MANAGER:RegisterTopLevel(FurysCharacterTracker_Window, false)
    FurysCharacterTracker_Window:SetHandler("OnHide", function()
        HideTip()
        EVENT_MANAGER:UnregisterForUpdate(CT.name .. "Board")
    end)

    ZO_ScrollList_AddDataType(self.list, ROW_TYPE, "FurysCharacterTracker_Row", ROW_HEIGHT, function(control, data)
        self:SetupRow(control, data)
    end)

    -- Column headers, made once and reused by every tab.
    self.headers = {}
    for i = 1, MAX_CELLS do
        local label = WINDOW_MANAGER:CreateControl("FurysCharacterTracker_WindowHeaderCol" .. i, FurysCharacterTracker_WindowHeader, CT_LABEL)
        label:SetFont(T.FONT_HEADER)
        label:SetColor(HEAD[1], HEAD[2], HEAD[3], 1)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        label:SetMouseEnabled(true)
        label:SetHidden(true)
        self.headers[i] = label
    end

    self:BuildTabs()

    -- Buttons under the board (the list is in Data/Text.lua).
    local actions = {
        timers = function() CT.Timers:Toggle() end,
        brag = function() CT.Brag:Toggle() end,
        copy = function() CT.TextWindow:ShowCopy(CT.Pages.DiscordTable(CurrentView().id)) end,
        export = function() CT.ConfirmExport() end,
        scan = function() CT.ReadNow() end,
        removed = function() CT.Roster:ShowAll(); self:Refresh() end,
    }
    local previous
    self.footer = {}
    for i, def in ipairs(X.FOOTER) do
        local width = 44 + 8 * #def.label
        local button = Button("FurysCharacterTracker_WindowFooter" .. i, FurysCharacterTracker_WindowFooter, def.label, width, def.tip, actions[def.id])
        if previous then button:SetAnchor(LEFT, previous, RIGHT, 8, 0) else button:SetAnchor(LEFT, FurysCharacterTracker_WindowFooter, LEFT, 0, 0) end
        self.footer[def.id] = button
        previous = button
    end

    FurysCharacterTracker_WindowLegend:SetText(X.LEGEND)
    -- 1.5.6: the version sits in the title, and Start here right after it, as in every Fury addon.
    T.SetTitle(FurysCharacterTracker_Window, CT.displayName, CT.version)
    FurysCharacterTracker_WindowSubtitle:SetText("")
    SetTip(FurysCharacterTracker_WindowSummary, function() return self.summaryTip end)

    -- Which account and megaserver you are looking at.
    local picker = Button("FurysCharacterTracker_WindowAccount", FurysCharacterTracker_Window, "", 300, X.ACCOUNT_TIP, function(control) Win.PickAccount(control) end)
    picker:SetAnchor(TOPRIGHT, FurysCharacterTracker_Window, TOPRIGHT, -52, 12)
    self.accountButton = picker

    -- Settings: the gear left of the account button.
    local gear = WINDOW_MANAGER:CreateControl("FurysCharacterTracker_WindowSettings", FurysCharacterTracker_Window, CT_BUTTON)
    gear:SetDimensions(32, 32)
    gear:SetAnchor(RIGHT, picker, LEFT, -10, 0)
    gear:SetNormalTexture("/esoui/art/chatwindow/chat_options_up.dds")
    gear:SetPressedTexture("/esoui/art/chatwindow/chat_options_down.dds")
    gear:SetMouseOverTexture("/esoui/art/chatwindow/chat_options_over.dds")
    gear:SetHandler("OnClicked", function() CT.Settings:Open() end)
    SetTip(gear, function() return X.SETTINGS_TIP end)

    -- Start here: the one-page guide, right after the title (Theme.lua), as in every Fury addon.
    T.StartButton(FurysCharacterTracker_Window, function() CT.Details:ShowStart() end, X.START_TIP)
    -- The other Fury addons, one click each, in the title bar (Theme.lua).
    T.TitleIcons(FurysCharacterTracker_Window, gear)

    local pos = CT.sv.window
    if pos then
        self.control:ClearAnchors()
        self.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
    end
end

function Win.SavePosition()
    CT.sv.window = { x = FurysCharacterTracker_Window:GetLeft(), y = FurysCharacterTracker_Window:GetTop() }
end

-- Show / hide -------------------------------------------------------------------------

function Win:Toggle()
    if FurysCharacterTracker_Window:IsHidden() then self:Show() else self:Hide() end
end

function Win:Show(viewId)
    if viewId then CT.sv.lastView = viewId end
    SCENE_MANAGER:ShowTopLevel(FurysCharacterTracker_Window)
    CT.Raise(FurysCharacterTracker_Window)
    self:Refresh()
    -- New install: the Start here page opens with the board, once.
    if not CT.sv.startShown then
        CT.sv.startShown = true
        CT.Details:ShowStart()
    end
end

function Win:Hide()
    SCENE_MANAGER:HideTopLevel(FurysCharacterTracker_Window)
end

-- Several things can ask for a redraw in the same moment (a read finishing, a writ changing):
-- they become one redraw a tenth of a second later.
function Win:RefreshIfShown()
    if self.redrawQueued or not self.control or self.control:IsHidden() then return end
    self.redrawQueued = true
    zo_callLater(function()
        self.redrawQueued = false
        if not self.control:IsHidden() then self:Refresh() end
    end, 100)
end

-- Cells -------------------------------------------------------------------------------

local function EnsureCells(row)
    if row.cells then return end
    row.cells = {}
    local base = row:GetName()
    for i = 1, MAX_CELLS do
        -- Above the row's stripe (level 3) and hover highlight (level 5), under the cell text.
        local tile = T.Rect(base .. "Tile" .. i, row, T.VIOLET, DL_BACKGROUND, 8)
        tile:SetColor(VIOLET[1], VIOLET[2], VIOLET[3], 0.9)
        tile:SetHidden(true)
        -- How far along an in-progress cell is: a faint bar from the left edge.
        local bar = T.Rect(base .. "Bar" .. i, row, T.VIOLET, DL_BACKGROUND, 7)
        bar:SetColor(VIOLET[1], VIOLET[2], VIOLET[3], 0.24)
        bar:SetHidden(true)
        local label = WINDOW_MANAGER:CreateControl(base .. "Cell" .. i, row, CT_LABEL)
        label:SetDrawLayer(DL_TEXT)
        label:SetFont("ZoFontGame")
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        label:SetMouseEnabled(true)
        row.cells[i] = { tile = tile, bar = bar, label = label }
    end
end

-- Draws one cell from what Core/Board.lua says about it.
local function PaintCell(cell, column, e)
    local look = Board.Cell(column, e)
    local text = look.text
    local icon = column.icon and column.icon(e)
    if icon then text = U.Icon(icon, 20) .. " " .. text end
    cell.tile:SetHidden(not look.maxed)
    cell.bar:SetHidden(look.pct == nil)
    if look.pct then cell.bar:SetWidth(math.max(2, zo_round(column.width * math.min(1, look.pct)))) end
    cell.label:SetText(text)
    cell.label:SetFont(look.maxed and "ZoFontGameBold" or "ZoFontGame")
    local rgb = (look.maxed and INK) or (look.warn and T.RGB.WARN) or (look.pick and PICK) or (look.dim and DIM) or TEXT
    cell.label:SetColor(rgb[1], rgb[2], rgb[3], 1)
end

local function LayoutCells(row, columns)
    local x = 6
    for i, cell in ipairs(row.cells) do
        local column = columns[i]
        if column then
            cell.tile:ClearAnchors()
            cell.tile:SetAnchor(LEFT, row, LEFT, x, 0)
            cell.tile:SetDimensions(column.width, ROW_HEIGHT - 4)
            cell.bar:ClearAnchors()
            cell.bar:SetAnchor(LEFT, row, LEFT, x, 0)
            cell.bar:SetDimensions(column.width, ROW_HEIGHT - 4)
            cell.label:ClearAnchors()
            cell.label:SetAnchor(LEFT, row, LEFT, x + 4, 0)
            cell.label:SetDimensions(column.width - 8, ROW_HEIGHT)
            cell.label:SetHorizontalAlignment(ALIGN[column.align] or TEXT_ALIGN_CENTER)
            cell.label:SetHidden(false)
            x = x + column.width + GAP
        else
            cell.label:SetHidden(true)
            cell.tile:SetHidden(true)
            cell.bar:SetHidden(true)
        end
    end
end

-- Menus -------------------------------------------------------------------------------

local function Marked(label, isCurrent)
    return isCurrent and ("|cA08CFF" .. label .. "  <|r") or label
end

-- Dropdown of accounts and megaservers.
function Win.PickAccount(owner)
    ClearMenu()
    for _, entry in ipairs(CT.Accounts()) do
        local label = CT.ViewLabel(entry) .. (entry == CT.home and "  (you)" or "")
        AddMenuItem(Marked(label, entry.world == CT.view.world and entry.account == CT.view.account), function() CT.SetView(entry) end)
    end
    ShowMenu(owner)
end

-- Dropdown for one of your picks. The current choice is marked.
function Win.Pick(owner, id, field, values)
    local current = (CT.Data().manual[id] or {})[field] or ""
    ClearMenu()
    for _, value in ipairs(values) do
        AddMenuItem(Marked(value == "" and "(none)" or value, value == current), function()
            CT.Roster:SetManual(id, field, value)
            Win:Refresh()
        end)
    end
    ShowMenu(owner)
end

-- Moving a row changes your own order, so the tab goes back to it if it was sorted by a column.
local function Move(id, where)
    if CT.Roster:Move(id, where) then
        CT.sv.sort[CurrentView().id] = nil
        Win:Refresh()
    end
end

-- Right-click on a row. `e` is the board entry; for a character not read yet, `unread` is what
-- the game says about it.
local function RowMenu(e, unread)
    local name = e and e.name or unread.name
    ClearMenu()
    if e then
        AddMenuItem("Details for " .. name, function() CT.Details:Show(e.id) end)
        AddMenuItem(e.m.note and "Edit the note" or "Write a note", function() CT.TextWindow:ShowNote(e.id) end)
        AddMenuItem("Copy " .. name .. " for Discord", function()
            local entry = CT.Roster:Entry(e.id)
            if entry then CT.TextWindow:ShowCopy(CT.Pages.DiscordCharacter(entry)) end
        end)
        AddMenuItem("Move up", function() Move(e.id, "up") end)
        AddMenuItem("Move down", function() Move(e.id, "down") end)
        AddMenuItem("Move to the top", function() Move(e.id, "top") end)
        AddMenuItem("Move to the bottom", function() Move(e.id, "bottom") end)
    end
    AddMenuItem("Remove " .. name .. " from the board", function()
        CT.Roster:Hide(e and e.id or unread.key)
        Win:Refresh()
        U.Print("Removed %s from the board. \"Show removed\" under the board puts it back; logging in on it does too.", name)
    end)
    ShowMenu()
end

-- Rows --------------------------------------------------------------------------------

-- A character the addon has not read yet: its name and class (the game knows those for every
-- character), then one line across the row saying how to fill it in.
local function SetupUnreadRow(row, data, columns)
    local info = data.unread
    local tip = Board.UnreadTip(info)
    for i, cell in ipairs(row.cells) do
        cell.tile:SetHidden(true)
        cell.bar:SetHidden(true)
        local text
        if i == 1 then text = info.name elseif i == 2 then text = info.class or "" elseif i == 3 then text = X.UNREAD end
        cell.label:SetHidden(text == nil)
        if text then
            if i == 3 then
                -- One wide cell from the third column to the end of the row.
                local x = 6 + columns[1].width + GAP + columns[2].width + GAP + 4
                cell.label:SetDimensions(ROW_WIDTH - x - 6, ROW_HEIGHT)
            end
            cell.label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            cell.label:SetText(text)
            cell.label:SetFont("ZoFontGame")
            cell.label:SetColor(DIM[1], DIM[2], DIM[3], 1)
            cell.label.furyRow = row
            SetTip(cell.label, function() return tip end)
            cell.label:SetHandler("OnMouseUp", function(_, button, upInside)
                if upInside and button == MOUSE_BUTTON_INDEX_RIGHT then RowMenu(nil, info) end
            end)
        end
    end
end

function Win:SetupRow(row, data)
    EnsureCells(row)
    local columns = self.columns
    LayoutCells(row, columns)
    row:GetNamedChild("Stripe"):SetHidden(data.stripe ~= true)
    T.RowHover(row, false)
    if data.unread then return SetupUnreadRow(row, data, columns) end
    local e = data.entry
    for i, cell in ipairs(row.cells) do
        local column = columns[i]
        if column then
            PaintCell(cell, column, e)
            cell.label.furyRow = row
            SetTip(cell.label, function() return Board.Tip(column, e) end)
            cell.label:SetHandler("OnMouseUp", function(_, button, upInside)
                if not upInside then return end
                if button == MOUSE_BUTTON_INDEX_RIGHT then
                    RowMenu(e)
                elseif column.pick then
                    Win.Pick(cell.label, e.id, column.pick.field, column.pick.values)
                elseif column.note then
                    CT.TextWindow:ShowNote(e.id)
                else
                    CT.Details:Show(e.id)
                end
            end)
        end
    end
end

-- The bottom row: how many characters have each column maxed (or the sum, for plain numbers).
function Win:SetupTotals(totals)
    local row = FurysCharacterTracker_WindowTotals
    EnsureCells(row)
    LayoutCells(row, self.columns)
    for i, cell in ipairs(row.cells) do
        if self.columns[i] then
            cell.tile:SetHidden(true)
            cell.bar:SetHidden(true)
            cell.label:SetText(totals[i])
            cell.label:SetFont("ZoFontGameBold")
            cell.label:SetColor(VIOLET[1], VIOLET[2], VIOLET[3], 1)
            cell.label:SetMouseEnabled(false)
        end
    end
end

-- Refresh -----------------------------------------------------------------------------

function Win:Refresh()
    HideTip()
    local view = CurrentView()
    local columns = Board.Columns(view)
    self.columns = columns
    for _, tab in ipairs(self.tabs) do
        tab.active = tab.view == view
        self:PaintTab(tab)
    end

    local entries, unread = Board.Rows(view)
    local sort = Board.Sort(view)

    -- Headers.
    local x = 6
    for i, label in ipairs(self.headers) do
        local column = columns[i]
        if column then
            local arrow = (sort and sort.key == column.key) and (sort.desc and SORT_DOWN or SORT_UP) or ""
            label:ClearAnchors()
            label:SetAnchor(LEFT, FurysCharacterTracker_WindowHeader, LEFT, x + 4, 0)
            label:SetDimensions(column.width - 8, 26)
            label:SetHorizontalAlignment(ALIGN[column.align] or TEXT_ALIGN_CENTER)
            label:SetText(Board.Title(column) .. arrow)
            label:SetHandler("OnMouseUp", function(_, _, upInside)
                if not upInside then return end
                Board.ClickSort(view, column)
                self:Refresh()
            end)
            SetTip(label, function() return Board.HeadTip(column) end)
            label:SetHidden(false)
            x = x + column.width + GAP
        else
            label:SetHidden(true)
        end
    end

    ZO_ScrollList_Clear(self.list)
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    for i, entry in ipairs(entries) do
        scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(ROW_TYPE, { entry = entry, stripe = (i % 2 == 0) })
    end
    -- Characters not read yet come last, dim, whatever the sort.
    for i, info in ipairs(unread) do
        scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(ROW_TYPE, { unread = info, stripe = ((#entries + i) % 2 == 0) })
    end
    ZO_ScrollList_Commit(self.list)
    self:SetupTotals(Board.Totals(view, columns, entries))

    self.footer.removed:SetHidden(not CT.Roster:AnyHidden())
    self.footer.scan:SetHidden(not CT.IsHome())
    self.accountButton:SetText(CT.ViewLabel() .. "  v")

    local summary
    summary, self.summaryTip = Board.Summary(view, entries, unread)
    FurysCharacterTracker_WindowSummary:SetText(summary)

    -- Tabs with timers keep counting while the board is open.
    EVENT_MANAGER:UnregisterForUpdate(CT.name .. "Board")
    if view.live then
        EVENT_MANAGER:RegisterForUpdate(CT.name .. "Board", LIVE_MS, function() self:RefreshIfShown() end)
    end
end
