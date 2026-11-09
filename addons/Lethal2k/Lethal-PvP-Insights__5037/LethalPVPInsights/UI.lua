-- Lethal PVP Insights - main window
-- Left: list for the selected tab. Right: details of the selected player (skills, mundus, gear & bars),
-- so you can click through players without going back and forth.
local PDI = PVPDataInsight
local UI = {}
PDI.UI = UI

-- class of a character (0 = unknown); one @account can play several classes, kept apart everywhere
local function classOf(ch) return (ch and PDI.Data:ClassOf(ch)) or 0 end

local WM = WINDOW_MANAGER
local ROW_H      = 26
local NUM_ROWS   = 22
local PANE_ROWS  = 12
local PANE_ROW_H = 27          -- details panel uses a bigger font and taller rows (row counts fit the screen)
local PANE_FONT  = "ZoFontGameMedium"
local MAX_COLS   = 10
-- sizes are adapted to the screen in UI:Init (the details panel shows skills and gear side by side)
local WIN_W, WIN_H = 1780, 820
local PAD     = 16
local LIST_W  = 720
local PANE_X  = PAD + LIST_W + 14
local PANE_W  = WIN_W - PANE_X - PAD
local HALF_W  = math.floor((PANE_W - 16) / 2)
local TOP_Y   = 124
local GRID_OFFSET = 222        -- details: info lines, then the day / class buttons, then the grids

local NORMAL = { 0.77, 0.76, 0.62, 1 }
local WHITE  = { 1, 1, 1, 1 }
local GREY   = { 0.6, 0.6, 0.6, 1 }
local TOTAL_COLOR = { 0.95, 0.82, 0.45, 1 }  -- the pinned Total row on My Kills

local TYPE_LABEL = { dmg = "Damage", dot = "DoT", kb = "Killing Blow", eff = "Effect/Proc", cc = "Crowd Control", heal = "Heal" }

-- view state
UI.tab        = "my"      -- my | feed | opp | saved | group | builds
UI.sel        = nil       -- selected player: { kind="opp"|"build", rec=, who=, date=, savedId=, savedAt=, key= }
UI.variantIdx = 1
UI.period     = "today"
UI.faction    = 0
UI.search     = ""
UI.offset     = 0
UI.paneOffset = 0
UI.oppDateIdx = 1
UI.sort = {
    my      = { key = "tot",  desc = true },
    feed    = { key = "k",    desc = true },
    opp     = { key = "last", desc = true },
    saved   = { key = "savedAt", desc = true },
    group   = { key = "last", desc = true },
    builds  = { key = "savedAt", desc = true },
    detail  = { key = "h",    desc = true },
    bdetail = { key = "h",    desc = true },
    gear    = { key = "",     desc = false },
}

---------------------------------------------------------------------------
-- Column definitions (widths are relative; they're scaled to fit each grid)
---------------------------------------------------------------------------
local function factionCell(r) if r.isTotal then return "" end return PDI.FactionText(r.al, true) end
local function num(key) return function(r) return PDI.Num(r[key]) end end
local R = TEXT_ALIGN_RIGHT

local COLUMNS = {
    my = {
        { t = "#",         w = 40,  key = "rank", align = R, nosort = true },
        { t = "Account",   w = 210, key = "who" },
        { t = "Character", w = 170, key = "c" },
        { t = "Faction",   w = 65,  key = "al", fmt = factionCell },
        { t = "Class",     w = 105, key = "clsName" },
        { t = "Kills",     w = 70,  key = "k",   num = true, fmt = num("k"),   align = R },
        { t = "Assists",   w = 75,  key = "a",   num = true, fmt = num("a"),   align = R },
        { t = "Total",     w = 75,  key = "tot", num = true, fmt = num("tot"), align = R },
    },
    feed = {
        { t = "#",         w = 40,  key = "rank", align = R, nosort = true },
        { t = "Account",   w = 250, key = "who" },
        { t = "Character", w = 210, key = "c" },
        { t = "Faction",   w = 80,  key = "al", fmt = factionCell },
        { t = "Class",     w = 120, key = "clsName" },
        { t = "Kills",     w = 80,  key = "k", num = true, fmt = num("k"), align = R },
    },
    opp = {
        { t = "Account",    w = 170, key = "who" },
        { t = "Character",  w = 140, key = "char" },
        { t = "Fac.",       w = 45,  key = "al", fmt = factionCell },
        { t = "Class",      w = 95,  key = "clsName" },
        { t = "Health",     w = 75,  key = "hp", num = true, align = R,
          fmt = function(r) return (r.hp or 0) > 0 and r.hp <= PDI.MAX_PLAUSIBLE_HP and PDI.Num(r.hp) or "-" end },
        { t = "Mundus",     w = 120, key = "mundusText" },
        { t = "Skills",     w = 55,  key = "nSkills", num = true, align = R },
        { t = "Days",       w = 45,  key = "nDays", num = true, align = R },
        { t = "Killed you", w = 75,  key = "killedYou", num = true, align = R },
    },
    saved = {
        { t = "Account",    w = 190, key = "who" },
        { t = "Character",  w = 160, key = "char" },
        { t = "Fac.",       w = 50,  key = "al", fmt = factionCell },
        { t = "Type",       w = 70,  key = "kindText" },
        { t = "Days",       w = 50,  key = "nDays", num = true, align = R },
        { t = "Last seen",  w = 105, key = "date", num = true, fmt = function(r) return PDI.FormatDate(r.date) end },
        { t = "Skills",     w = 60,  key = "nSkills", num = true, align = R },
        { t = "Killed you", w = 75,  key = "killedYou", num = true, align = R },
    },
    group = {
        { t = "Account",      w = 165, key = "who" },
        { t = "Character",    w = 130, key = "char" },
        { t = "Fac.",         w = 45,  key = "al", fmt = factionCell },
        { t = "Class",        w = 95,  key = "clsName" },
        { t = "Role",         w = 60,  key = "roleText" },
        { t = "CP",           w = 50,  key = "cp", num = true, align = R },
        { t = "Gear",         w = 50,  key = "hasLog", fmt = function(r) return r.hasLog == 1 and "|c66FF66yes|r" or "-" end },
        { t = "Last grouped", w = 115, key = "last", num = true,
          fmt = function(r) return r.now and "|c66FF66in group|r" or PDI.FormatTime(r.last) end },
    },
    builds = {
        { t = "Account",   w = 180, key = "who" },
        { t = "Character", w = 160, key = "char" },
        { t = "Class",     w = 100, key = "clsName" },
        { t = "Role",      w = 70,  key = "roleText" },
        { t = "Skills",    w = 60,  key = "nSkills", num = true, align = R },
        { t = "Saved at",  w = 150, key = "savedAt", num = true, fmt = function(r) return PDI.FormatTime(r.savedAt) end },
    },
    -- details panel: skills (bars + observed) and gear (sets + items)
    skillpane = {
        { t = "Skill",        w = 300, key = "n",    nosort = true },
        { t = "Info",         w = 170, key = "info", nosort = true },
    },
    gearpane = {
        { t = "Slot",         w = 95,  key = "sec",   nosort = true },
        { t = "Set",          w = 200, key = "n",     nosort = true },
        { t = "Item",         w = 130, key = "item",  nosort = true },
        { t = "Trait",        w = 105, key = "trait", nosort = true },
        { t = "Enchant",      w = 115, key = "ench",  nosort = true },
    },
    -- (legacy single-list views, kept for reference)
    detail = {
        { t = "Skill / Proc used on you", w = 200, key = "n" },
        { t = "Type",    w = 110, key = "tyText" },
        { t = "Hits",    w = 50,  key = "h", num = true, fmt = num("h"), align = R },
        { t = "Max",     w = 70,  key = "m", num = true, fmt = num("m"), align = R },
        { t = "Total",   w = 75,  key = "total", num = true, fmt = num("total"), align = R },
    },
    bdetail = {
        { t = "Skill / Proc observed", w = 200, key = "n" },
        { t = "Type",    w = 110, key = "tyText" },
        { t = "Uses",    w = 50,  key = "h", num = true, fmt = num("h"), align = R },
        { t = "Max",     w = 70,  key = "m", num = true, fmt = num("m"), align = R },
        { t = "Total",   w = 75,  key = "total", num = true, fmt = num("total"), align = R },
    },
    gear = {
        { t = "Section",      w = 90,  key = "sec",  nosort = true },
        { t = "Name",         w = 180, key = "n",    nosort = true },
        { t = "Trait / Info", w = 130, key = "info", nosort = true },
        { t = "Quality",      w = 60,  key = "q",    nosort = true },
        { t = "Level",        w = 45,  key = "lvl",  nosort = true },
    },
}

---------------------------------------------------------------------------
-- Control helpers
---------------------------------------------------------------------------
local function Label(name, parent, font, color)
    local l = WM:CreateControl(name, parent, CT_LABEL)
    l:SetFont(font or "ZoFontGame")
    l:SetColor(unpack(color or WHITE))
    l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    l:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    return l
end

local function Button(name, parent, text, w, onClick)
    local b = WM:CreateControlFromVirtual(name, parent, "ZO_DefaultButton")
    b:SetDimensions(w, 28)
    b:SetText(text)
    b:SetHandler("OnClicked", onClick)
    return b
end

local function setPressed(btn, pressed)
    if pressed then btn:SetState(BSTATE_PRESSED, true) else btn:SetState(BSTATE_NORMAL, false) end
end

local function showTooltip(r)
    if r.data.tooltipId and AbilityTooltip then
        InitializeTooltip(AbilityTooltip, r, RIGHT, -10, 0, LEFT)
        AbilityTooltip:SetAbilityId(r.data.tooltipId)
    elseif r.data.tooltipLink and ItemTooltip then
        InitializeTooltip(ItemTooltip, r, RIGHT, -10, 0, LEFT)
        ItemTooltip:SetLink(r.data.tooltipLink)
    end
end

local hideTooltip
-- clicking a skill / set row keeps its tooltip open (the game's pop-up tooltip, closed with its X)
local function pinTooltip(d)
    hideTooltip()
    if d.tooltipLink and ZO_PopupTooltip_SetLink then
        pcall(ZO_PopupTooltip_SetLink, d.tooltipLink)
    elseif d.tooltipId and PopupTooltip and ZO_PopupTooltip_Show then
        pcall(function()
            ZO_PopupTooltip_Show()
            PopupTooltip.lastLink = nil
            PopupTooltip:ClearLines()
            PopupTooltip:SetAbilityId(d.tooltipId)
        end)
    end
end

hideTooltip = function()
    if AbilityTooltip then ClearTooltip(AbilityTooltip) end
    if ItemTooltip then ClearTooltip(ItemTooltip) end
end

---------------------------------------------------------------------------
-- Grid: a header + fixed pool of rows with mouse-wheel scrolling
---------------------------------------------------------------------------
local Grid = {}
Grid.__index = Grid

function Grid.New(prefix, parent, width, numRows, onSort, onScroll, rowH, font, headerFont)
    rowH = rowH or ROW_H
    local g = setmetatable({ width = width, numRows = numRows, offset = 0, data = {}, rowH = rowH }, Grid)
    local box = WM:CreateControl(prefix, parent, CT_CONTROL)
    box:SetDimensions(width, rowH * (numRows + 1) + 4)
    box:SetMouseEnabled(true)
    box:SetHandler("OnMouseWheel", function(_, delta) onScroll(delta) end)
    g.box = box

    local header = WM:CreateControl(prefix .. "Header", box, CT_CONTROL)
    header:SetAnchor(TOPLEFT, box, TOPLEFT, 0, 0)
    header:SetDimensions(width, rowH)
    g.header = header
    g.headerCells = {}
    for c = 1, MAX_COLS do
        local l = Label(prefix .. "HeaderCell" .. c, header, headerFont or "ZoFontGameBold", NORMAL)
        l:SetMouseEnabled(true)
        l:SetHandler("OnMouseUp", function(_, button, upInside)
            if upInside and button == MOUSE_BUTTON_INDEX_LEFT then onSort(c) end
        end)
        g.headerCells[c] = l
    end
    local divider = WM:CreateControl(prefix .. "HeaderDivider", header, CT_TEXTURE)
    divider:SetColor(0.77, 0.76, 0.62, 0.4)
    divider:SetHeight(1)
    divider:SetAnchor(BOTTOMLEFT, header, BOTTOMLEFT, 0, 0)
    divider:SetAnchor(BOTTOMRIGHT, header, BOTTOMRIGHT, 0, 0)

    -- scrollbar (visual): shows there is more to scroll to
    local trackH = rowH * numRows
    local track = WM:CreateControl(prefix .. "Track", box, CT_TEXTURE)
    track:SetColor(1, 1, 1, 0.07)
    track:SetDimensions(5, trackH)
    track:SetAnchor(TOPRIGHT, box, TOPRIGHT, 0, rowH + 2)
    local thumb = WM:CreateControl(prefix .. "Thumb", box, CT_TEXTURE)
    thumb:SetColor(0.77, 0.76, 0.62, 0.7)
    thumb:SetWidth(5)
    g.track, g.thumb, g.trackH = track, thumb, trackH
    -- drag the scrollbar (or click the track to jump there): a wider invisible grip over the track
    local grip = WM:CreateControl(prefix .. "Grip", box, CT_CONTROL)
    grip:SetDimensions(16, trackH)
    grip:SetAnchor(TOPRIGHT, box, TOPRIGHT, 4, rowH + 2)
    grip:SetMouseEnabled(true)
    grip:SetDrawLevel(10)                       -- above the rows, so it gets the clicks
    thumb:SetDrawLevel(9); track:SetDrawLevel(8)
    grip:SetHandler("OnMouseWheel", function(_, delta) onScroll(delta) end)
    local grab                                  -- where on the thumb it was grabbed (0..1), while dragging
    local function offsetAt(mouseY)
        local total = #g.data
        local maxOff = math.max(0, total - g.numRows)
        if maxOff == 0 then return 0 end
        local h = math.max(16, g.trackH * g.numRows / total)
        local y = mouseY - track:GetTop() - (grab or 0.5) * h
        return zo_clamp(zo_round(y / math.max(1, g.trackH - h) * maxOff), 0, maxOff)
    end
    local function moveTo(mouseY)
        local o = offsetAt(mouseY)
        if o ~= g.offset then onScroll((g.offset - o) / 3) end     -- Grid:Scroll moves 3 rows per step
    end
    grip:SetHandler("OnMouseDown", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or thumb:IsHidden() then return end
        local _, my = GetUIMousePosition()
        local tTop, tBottom = thumb:GetTop(), thumb:GetBottom()
        grab = (my >= tTop and my <= tBottom) and (my - tTop) / math.max(1, tBottom - tTop) or 0.5
        moveTo(my)
        grip:SetHandler("OnUpdate", function()
            local _, y = GetUIMousePosition()
            moveTo(y)
        end)
    end)
    grip:SetHandler("OnMouseUp", function()
        grab = nil
        grip:SetHandler("OnUpdate", nil)
    end)

    g.rows = {}
    for i = 1, numRows do
        local row = WM:CreateControl(prefix .. "Row" .. i, box, CT_CONTROL)
        row:SetDimensions(width, rowH)
        row:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 0, (i - 1) * rowH + 2)
        row:SetMouseEnabled(true)
        local stripe = WM:CreateControl(prefix .. "Row" .. i .. "Stripe", row, CT_TEXTURE)
        stripe:SetAnchorFill(row)
        stripe:SetColor(1, 1, 1, 0.03)
        stripe:SetHidden(i % 2 == 1)
        local sel = WM:CreateControl(prefix .. "Row" .. i .. "Sel", row, CT_TEXTURE)
        sel:SetAnchorFill(row)
        sel:SetColor(0.77, 0.76, 0.62, 0.18)
        sel:SetHidden(true)
        local hl = WM:CreateControl(prefix .. "Row" .. i .. "HL", row, CT_TEXTURE)
        hl:SetAnchorFill(row)
        hl:SetColor(1, 1, 1, 0.08)
        hl:SetHidden(true)
        row.hl, row.sel = hl, sel
        row.cells = {}
        for c = 1, MAX_COLS do
            row.cells[c] = Label(prefix .. "Row" .. i .. "Cell" .. c, row, font or "ZoFontGame", WHITE)
        end
        row:SetHandler("OnMouseEnter", function(r)
            if not r.data then return end
            r.hl:SetHidden(false)
            showTooltip(r)
        end)
        row:SetHandler("OnMouseExit", function(r) r.hl:SetHidden(true); hideTooltip() end)
        row:SetHandler("OnMouseUp", function(r, button, upInside)
            if not (upInside and r.data) then return end
            if button == MOUSE_BUTTON_INDEX_LEFT and r.data.onClick then r.data.onClick()
            elseif button == MOUSE_BUTTON_INDEX_LEFT and (r.data.tooltipId or r.data.tooltipLink) then pinTooltip(r.data)
            elseif button == MOUSE_BUTTON_INDEX_RIGHT and r.data.onRightClick then r.data.onRightClick(r) end
        end)
        row:SetHandler("OnMouseWheel", function(_, delta) onScroll(delta) end)
        g.rows[i] = row
    end
    return g
end

function Grid:Layout(cols, sortState)
    self.cols = cols
    local total = 0
    for _, col in ipairs(cols) do total = total + col.w end
    local scale = (self.width - 14) / math.max(total, 1)
    local x = 6
    for c = 1, MAX_COLS do
        local col = cols[c]
        local w = col and math.floor(col.w * scale) or 0
        local h = self.headerCells[c]
        h:ClearAnchors()
        h:SetHidden(col == nil)
        if col then
            h:SetAnchor(LEFT, self.header, LEFT, x, 0)
            h:SetDimensions(w - 8, self.rowH)
            h:SetHorizontalAlignment(col.align or TEXT_ALIGN_LEFT)
            local arrow = (sortState and sortState.key == col.key and col.key ~= "") and (sortState.desc and " v" or " ^") or ""
            h:SetText(col.t .. arrow)
        end
        for _, row in ipairs(self.rows) do
            local cell = row.cells[c]
            cell:ClearAnchors()
            cell:SetHidden(col == nil)
            if col then
                cell:SetAnchor(LEFT, row, LEFT, x, 0)
                cell:SetDimensions(w - 8, self.rowH)
                cell:SetHorizontalAlignment(col.align or TEXT_ALIGN_LEFT)
            end
        end
        x = x + w
    end
end

function Grid:SetData(data)
    self.data = data
    self.offset = zo_clamp(self.offset, 0, math.max(0, #data - self.numRows))
end

function Grid:Scroll(delta)
    self.offset = zo_clamp(self.offset - delta * 3, 0, math.max(0, #self.data - self.numRows))
    self:Render()
end

function Grid:UpdateScrollbar()
    local total = #self.data
    local scrollable = total > self.numRows
    self.track:SetHidden(not scrollable)
    self.thumb:SetHidden(not scrollable)
    if scrollable then
        local h = math.max(16, self.trackH * self.numRows / total)
        local y = (self.trackH - h) * self.offset / math.max(1, total - self.numRows)
        self.thumb:ClearAnchors()
        self.thumb:SetHeight(h)
        self.thumb:SetAnchor(TOPRIGHT, self.box, TOPRIGHT, 0, self.rowH + 2 + y)
    end
end

function Grid:Render(selectedKey)
    if selectedKey ~= nil then self.selectedKey = selectedKey end
    self:UpdateScrollbar()
    for i, row in ipairs(self.rows) do
        local data = self.data[self.offset + i]
        row.data = data
        row:SetHidden(data == nil)
        if data then
            row.sel:SetHidden(not (self.selectedKey and data.key == self.selectedKey))
            for c, col in ipairs(self.cols) do
                local v
                if col.key == "rank" then v = data.rankText or tostring(data.rankNo or (self.offset + i))
                elseif col.fmt then v = col.fmt(data)
                else v = data[col.key]; v = (v == nil or v == "") and "-" or tostring(v) end
                row.cells[c]:SetText(v)
                row.cells[c]:SetColor(unpack(data.isTotal and TOTAL_COLOR or WHITE))
            end
        end
    end
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
function UI:Init()
    -- fit the screen: GuiRoot width depends on resolution and UI scale
    local screenW = (GuiRoot and GuiRoot.GetWidth and GuiRoot:GetWidth()) or 1920
    if not screenW or screenW <= 0 then screenW = 1920 end
    WIN_W = zo_clamp(math.floor(screenW - 40), 1300, 1780)
    LIST_W = math.floor(WIN_W * 0.42)
    PANE_X = PAD + LIST_W + 14
    PANE_W = WIN_W - PANE_X - PAD
    HALF_W = math.floor((PANE_W - 16) / 2)
    -- tall enough that a full build (12 skills, sets + ~15 items) fits without scrolling
    local screenH = (GuiRoot and GuiRoot.GetHeight and GuiRoot:GetHeight()) or 1080
    if not screenH or screenH <= 0 then screenH = 1080 end
    WIN_H = zo_clamp(math.floor(screenH - 30), 760, 1060)
    NUM_ROWS = math.floor((WIN_H - TOP_Y - 56) / ROW_H) - 1
    PANE_ROWS = math.floor((WIN_H - (TOP_Y + GRID_OFFSET) - 44) / PANE_ROW_H) - 1

    local win = WM:CreateTopLevelWindow("PVPDataInsightWindow")
    self.win = win
    win:SetDimensions(WIN_W, WIN_H)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    local pos = PDI.sv.settings.window
    if pos.x and pos.y then
        win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
    else
        win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    win:SetHandler("OnMoveStop", function(c)
        PDI.sv.settings.window.x = c:GetLeft()
        PDI.sv.settings.window.y = c:GetTop()
    end)

    local bg = WM:CreateControlFromVirtual("PVPDataInsightWindowBG", win, "ZO_DefaultBackdrop")
    bg:SetAnchorFill(win)

    local title = Label("PVPDataInsightWindowTitle", win, "ZoFontWinH2", NORMAL)
    title:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, 10)
    title:SetText(PDI.displayName)
    local newer = PDI.Share.NewerAddon and PDI.Share:NewerAddon()
    if newer and PDI.sv.settings.updateNotice ~= false then
        local upd = Label("PVPDataInsightWindowUpdate", win, PANE_FONT, WHITE)
        upd:SetAnchor(LEFT, title, RIGHT, 16, 2)
        upd:SetText(string.format("|cFFCC66New version %s available|r |c999999- update with Minion (ESOUI) or esopvp.com|r", newer))
    end

    local close = WM:CreateControlFromVirtual("PVPDataInsightWindowClose", win, "ZO_CloseButton")
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -10, 12)
    close:SetHandler("OnClicked", function() UI:Hide() end)

    local settingsBtn = Button("PVPDataInsightSettingsBtn", win, "Settings", 110, function()
        UI:Hide()
        PDI.Settings:Open()
    end)
    settingsBtn:SetAnchor(RIGHT, close, LEFT, -10, 0)
    local importBtn = Button("PVPDataInsightImportBtn", win, "Import Log", 120, function() PDI.LogAssist:ShowImportWindow() end)
    importBtn:SetAnchor(RIGHT, settingsBtn, LEFT, -6, 0)

    -- Tabs
    self.tabs = {}
    local tabDefs = { { "my", "My Kills" }, { "feed", "Kill Feed" }, { "opp", "Opponents" },
                      { "saved", "Following" }, { "group", "Group" } }
    local prev
    for i, def in ipairs(tabDefs) do
        local b = Button("PVPDataInsightTab" .. i, win, def[2], 120, function() UI:SetTab(def[1]) end)
        if prev then b:SetAnchor(LEFT, prev, RIGHT, 6, 0) else b:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, 48) end
        self.tabs[def[1]] = b
        prev = b
    end

    -- Toolbar row: periods
    self.periodBtns = {}
    prev = nil
    -- the row also holds the search box and the faction button at its right end: share the width
    local TOOLS_W = 110 + 8 + 120 + 12
    local pw = math.min(84, math.floor((LIST_W - TOOLS_W - 2 * (#PDI.PERIODS - 1)) / #PDI.PERIODS))
    for i, p in ipairs(PDI.PERIODS) do
        local b = Button("PVPDataInsightPeriod" .. i, win, pw < 80 and p.short or p.label, pw, function() UI:SetPeriod(p.key) end)
        if pw < 84 and b.SetFont then b:SetFont("ZoFontGameSmall") end
        if prev then b:SetAnchor(LEFT, prev, RIGHT, 2, 0) else b:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, 84) end
        self.periodBtns[p.key] = b
        prev = b
    end

    -- Toolbar row: opponent date cycler
    self.datePrev = Button("PVPDataInsightDatePrev", win, "<", 40, function() UI:CycleDate(1) end)
    self.datePrev:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, 84)
    self.dateLabel = Label("PVPDataInsightDateLabel", win, "ZoFontGameBold", WHITE)
    self.dateLabel:SetDimensions(150, 28)
    self.dateLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.dateLabel:SetAnchor(LEFT, self.datePrev, RIGHT, 4, 0)
    self.dateNext = Button("PVPDataInsightDateNext", win, ">", 40, function() UI:CycleDate(-1) end)
    self.dateNext:SetAnchor(LEFT, self.dateLabel, RIGHT, 4, 0)
    self.dateHint = Label("PVPDataInsightDateHint", win, "ZoFontGameSmall", GREY)
    self.dateHint:SetAnchor(LEFT, self.dateNext, RIGHT, 10, 0)
    -- room between the date arrows and the search box (40 + 4 + 150 + 4 + 40 + 10 used on the left)
    local hintW = LIST_W - TOOLS_W - (40 + 4 + 150 + 4 + 40 + 10)
    self.dateHint:SetDimensions(math.max(hintW, 1), 28)
    self.dateHint:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    self.dateHint:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.dateHint:SetText("One row per player and class - kept 7 days, the days are in the details")
    self.dateHintFits = hintW >= 60
    self.dateHint:ClearAnchors()
    self.dateHint:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, 84)
    self.dateHint:SetDimensions(math.max(LIST_W - TOOLS_W - 10, 1), 28)

    -- Faction filter + search (above the list, right edge of the list)
    self.factionBtn = Button("PVPDataInsightFaction", win, "Faction: All", 110, function() UI:CycleFaction() end)
    self.factionBtn:SetAnchor(TOPRIGHT, win, TOPLEFT, PAD + LIST_W, 84)
    local searchBg = WM:CreateControlFromVirtual("PVPDataInsightSearchBG", win, "ZO_EditBackdrop")
    searchBg:SetDimensions(120, 26)
    searchBg:SetAnchor(RIGHT, self.factionBtn, LEFT, -8, 0)
    local edit = WM:CreateControlFromVirtual("PVPDataInsightSearch", searchBg, "ZO_DefaultEditForBackdrop")
    edit:SetMaxInputChars(40)
    if ZO_EditDefaultText_Initialize then ZO_EditDefaultText_Initialize(edit, "Search...") end
    edit:SetHandler("OnTextChanged", function(c)
        UI.search = string.lower(c:GetText() or "")
        UI.list.offset = 0
        UI:Refresh()
    end)
    self.searchEdit = edit

    -- Left list
    self.list = Grid.New("PVPDataInsightList", win, LIST_W, NUM_ROWS,
        function(c) UI:SortBy(c) end, function(d) UI.list:Scroll(d); UI:Refresh() end)
    self.list.box:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, TOP_Y)

    -- Divider between list and pane
    local vline = WM:CreateControl("PVPDataInsightPaneDivider", win, CT_TEXTURE)
    vline:SetColor(0.77, 0.76, 0.62, 0.25)
    vline:SetWidth(1)
    vline:SetAnchor(TOPLEFT, win, TOPLEFT, PANE_X - 8, 50)
    vline:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, PANE_X - 8, -44)

    -- Right pane
    self.paneTitle = Label("PVPDataInsightPaneTitle", win, "ZoFontWinH3", NORMAL)
    self.paneTitle:SetAnchor(TOPLEFT, win, TOPLEFT, PANE_X, 86)
    self.paneTitle:SetDimensions(PANE_W - 290, 34)

    self.info = Label("PVPDataInsightInfo", win, PANE_FONT, WHITE)
    self.info:SetAnchor(TOPLEFT, win, TOPLEFT, PANE_X, TOP_Y)
    self.info:SetDimensions(PANE_W, 150)
    self.info:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    self.info:SetVerticalAlignment(TEXT_ALIGN_TOP)

    self.saveBtn = Button("PVPDataInsightSave", win, "Save", 140, function() UI:SaveOrDeleteSelected() end)
    self.saveBtn:SetAnchor(TOPRIGHT, win, TOPLEFT, PANE_X + PANE_W, 84)
    self.variantBtn = Button("PVPDataInsightVariant", win, "Build 1/1", 130, function()
        local snap = UI:SelectedLog()
        if snap and snap.count and snap.count > 1 then
            UI.variantIdx = snap.idx % snap.count + 1
            UI:RefreshPane()
        end
    end)
    self.variantBtn:SetAnchor(RIGHT, self.saveBtn, LEFT, -6, 0)
    self.removeBtn = Button("PVPDataInsightRemove", win, "Remove", 110, function()
        local s = UI.sel
        if s and s.kind == "build" and not s.savedId then UI:ConfirmRemoveGroup(s.who) end
    end)
    self.removeBtn:SetAnchor(RIGHT, self.variantBtn, LEFT, -6, 0)
    self.removeBtn:SetHidden(true)
    self.linkBtn = Button("PVPDataInsightLink", win, "Link", 80, function() PDI.Link:InsertSelected() end)
    self.linkBtn:SetAnchor(RIGHT, self.removeBtn, LEFT, -6, 0)
    self.linkBtn:SetHidden(true)

    -- day and class buttons (one player can play several classes; each day is shown on its own)
    self.dayLabel = Label("PVPDataInsightDaysLabel", win, "ZoFontGameSmall", GREY)
    self.dayLabel:SetAnchor(TOPLEFT, win, TOPLEFT, PANE_X, TOP_Y + 154)
    self.dayLabel:SetDimensions(42, 28)
    self.dayLabel:SetText("Days:")
    self.dayBtns, self.classBtns = {}, {}
    local prevB = self.dayLabel
    for i = 1, 7 do
        local b = Button("PVPDataInsightDay" .. i, win, "", 66, function() UI:PickDay(i) end)
        if b.SetFont then b:SetFont("ZoFontGameSmall") end
        b:SetAnchor(LEFT, prevB, RIGHT, i == 1 and 0 or 2, 0)
        b:SetHidden(true)
        self.dayBtns[i] = b
        prevB = b
    end
    self.classLabel = Label("PVPDataInsightClassLabel", win, "ZoFontGameSmall", GREY)
    self.classLabel:SetDimensions(110, 28)
    self.classLabel:SetText("Other classes:")
    for i = 1, 3 do
        local b = Button("PVPDataInsightClass" .. i, win, "", 104, function() UI:PickClass(i) end)
        if b.SetFont then b:SetFont("ZoFontGameSmall") end
        b:SetHidden(true)
        self.classBtns[i] = b
    end
    self.dayLabel:SetHidden(true); self.classLabel:SetHidden(true)
    if ESO_Dialogs then
        ESO_Dialogs["PVPDI_REMOVE_GROUP"] = {
            title = { text = "Remove from Group" },
            mainText = { text = "Remove <<1>> from the Group tab, including their imported gear and skill bars?\n\n" ..
                "Saved builds are kept. If they're in your group right now they come back at the next scan." },
            buttons = {
                { text = "Remove", callback = function(dialog) if dialog and dialog.data then UI:RemoveGroup(dialog.data.acct) end end },
                { text = "Cancel" },
            },
        }
    end

    -- two side-by-side grids
    local GRID_Y = TOP_Y + GRID_OFFSET
    local function section(name, x, title)
        local l = Label("PVPDataInsight" .. name .. "Title", win, "ZoFontWinH4", NORMAL)
        l:SetAnchor(TOPLEFT, win, TOPLEFT, x, GRID_Y - 32)
        l:SetDimensions(HALF_W, 30)
        l:SetText(title)
        return l
    end
    local function grid(name, x)
        local g
        g = Grid.New("PVPDataInsight" .. name, win, HALF_W, PANE_ROWS, function() end,
            function(d) g:Scroll(d); UI:UpdatePaneMore() end, PANE_ROW_H, PANE_FONT, "ZoFontGameLargeBold")
        g.box:SetAnchor(TOPLEFT, win, TOPLEFT, x, GRID_Y)
        g.more = Label("PVPDataInsight" .. name .. "More", win, "ZoFontGameSmall", NORMAL)
        g.more:SetAnchor(TOPRIGHT, g.box, BOTTOMRIGHT, 0, 0)
        g.more:SetDimensions(HALF_W, 20)
        g.more:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        g.empty = Label("PVPDataInsight" .. name .. "Empty", win, PANE_FONT, GREY)
        g.empty:SetAnchor(TOPLEFT, win, TOPLEFT, x + 6, GRID_Y + PANE_ROW_H + 10)
        g.empty:SetDimensions(HALF_W - 12, 90)
        g.empty:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        g.empty:SetVerticalAlignment(TEXT_ALIGN_TOP)
        return g
    end
    self.skillTitle = section("SkillGrid", PANE_X, "Skills")
    self.gearTitle = section("GearGrid", PANE_X + HALF_W + 16, "Gear & Sets")
    self.skillGrid = grid("SkillGrid", PANE_X)
    self.gearGrid = grid("GearGrid", PANE_X + HALF_W + 16)

    self.paneEmpty = Label("PVPDataInsightPaneEmpty", win, PANE_FONT, GREY)
    self.paneEmpty:SetAnchor(TOPLEFT, win, TOPLEFT, PANE_X, TOP_Y + 20)
    self.paneEmpty:SetDimensions(PANE_W, 60)
    self.paneEmpty:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)

    -- Footer
    self.footer = Label("PVPDataInsightFooter", win, "ZoFontGameSmall", GREY)
    self.footer:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, PAD, -14)
    self.footer:SetDimensions(LIST_W - 190, 24)

    self.resetBtn = Button("PVPDataInsightResetSession", win, "Reset Session", 180, function()
        local kind, period = UI.tab, UI.period
        if period == "session" or not ZO_Dialogs_ShowDialog then
            UI:ResetPeriod(kind, period)
        else
            ZO_Dialogs_ShowDialog("PVPDI_RESET_PERIOD", { kind = kind, period = period },
                { mainTextParams = { UI:PeriodLabel(period), kind == "my" and "My Kills" or "Kill Feed",
                    period == "lifetime" and "\n\nThis clears every period of this tab." or "" } })
        end
    end)
    if ESO_Dialogs then
        ESO_Dialogs["PVPDI_RESET_PERIOD"] = {
            title = { text = "Reset Counters" },
            mainText = { text = "Delete the <<2>> counts for <<1>>? This can't be undone.<<3>>" },
            buttons = {
                { text = "Reset", callback = function(dialog)
                    if dialog and dialog.data then UI:ResetPeriod(dialog.data.kind, dialog.data.period) end
                end },
                { text = "Cancel" },
            },
        }
    end
    self.resetBtn:SetAnchor(BOTTOMRIGHT, win, BOTTOMLEFT, PAD + LIST_W, -12)

    self.clearGroupBtn = Button("PVPDataInsightClearGroup", win, "Clear Group History", 200, function()
        if ZO_Dialogs_ShowDialog then ZO_Dialogs_ShowDialog("PVPDI_CLEAR_GROUP") else UI:ClearGroup() end
    end)
    self.clearGroupBtn:SetAnchor(BOTTOMRIGHT, win, BOTTOMLEFT, PAD + LIST_W, -12)
    if ESO_Dialogs then
        ESO_Dialogs["PVPDI_CLEAR_GROUP"] = {
            title = { text = "Clear Group History" },
            mainText = { text = "Delete all players from the Group tab, including the gear and skill bars imported " ..
                "from the encounter log?\n\nFollowed players (Following tab) are kept." },
            buttons = {
                { text = "Clear", callback = function() UI:ClearGroup() end },
                { text = "Cancel" },
            },
        }
    end

    -- Scene: gives cursor, closes on ESC
    local scene = ZO_Scene:New("PVPDataInsightScene", SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    scene:AddFragment(ZO_SimpleSceneFragment:New(win))
    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then UI:Refresh() end
    end)
    self.scene = scene

    self:SetTab("my")
end

---------------------------------------------------------------------------
-- Visibility
---------------------------------------------------------------------------
function UI:Toggle() SCENE_MANAGER:Toggle("PVPDataInsightScene") end
function UI:Show()   SCENE_MANAGER:Show("PVPDataInsightScene") end
function UI:Hide()   SCENE_MANAGER:Hide("PVPDataInsightScene") end
function UI:IsVisible() return self.scene and self.scene:IsShowing() end

function UI:RefreshIfVisible()
    if not self:IsVisible() then return end
    -- throttle refreshes during big fights
    EVENT_MANAGER:UnregisterForUpdate("PVPDataInsightRefresh")
    EVENT_MANAGER:RegisterForUpdate("PVPDataInsightRefresh", 500, function()
        EVENT_MANAGER:UnregisterForUpdate("PVPDataInsightRefresh")
        UI:Refresh()
    end)
end

---------------------------------------------------------------------------
-- State changes
---------------------------------------------------------------------------
function UI:SetTab(tab)
    self.tab = tab
    self.list.offset = 0
    self.sel = nil
    if tab == "opp" then self.oppDateIdx = 1 end
    for k, b in pairs(self.tabs) do setPressed(b, k == tab) end
    self:Refresh()
end

function UI:PeriodLabel(p)
    for _, e in ipairs(PDI.PERIODS) do if e.key == p then return e.label end end
    return p or ""
end

function UI:ResetPeriod(kind, period)
    PDI.Data:ResetPeriod(kind, period)
    PDI.Msg(string.format("%s counters reset: %s.", kind == "my" and "My Kills" or "Kill Feed", self:PeriodLabel(period)))
    self.sel = nil
    self:Refresh()
end

function UI:SetPeriod(p)
    self.period = p
    self.list.offset = 0
    self:Refresh()
end

function UI:CycleFaction()
    local idx = 1
    for i, f in ipairs(PDI.FACTIONS) do if f == self.faction then idx = i end end
    idx = idx % #PDI.FACTIONS + 1
    self.faction = PDI.FACTIONS[idx]
    self.factionBtn:SetText("Faction: " .. PDI.FACTION_SHORT[self.faction])
    self.list.offset = 0
    self:Refresh()
end

function UI:CycleDate(step)
    local dates = PDI.Data:GetOpponentDates()
    if #dates == 0 then return end
    self.oppDateIdx = zo_clamp(self.oppDateIdx + step, 1, #dates)
    self.list.offset = 0
    self.sel = nil
    self:Refresh()
end

function UI:SortBy(colIdx)
    local col = COLUMNS[self.tab][colIdx]
    if not col or col.nosort then return end
    local s = self.sort[self.tab]
    if s.key == col.key then s.desc = not s.desc else s.key = col.key; s.desc = col.num and true or false end
    self:Refresh()
end

function UI:SortPane(colIdx)
    local view = self.paneView
    local col = view and COLUMNS[view][colIdx]
    if not col or col.nosort then return end
    local s = self.sort[view]
    if s.key == col.key then s.desc = not s.desc else s.key = col.key; s.desc = col.num and true or false end
    self:RefreshPane()
end

-- kind: "opp" (enemy combat data) or "build" (group member build)
function UI:Select(kind, rec, who, dateKey, savedId, savedAt, key)
    self.sel = { kind = kind, rec = rec, who = who, date = dateKey, savedId = savedId, savedAt = savedAt, key = key }
    self.variantIdx = 1
    self.skillGrid.offset, self.gearGrid.offset = 0, 0
    self.list:Render(key)
    self:RefreshPane()
end

-- A build another player saved and shares with you (esopvp.com): read-only
function UI:SelectWeb(kind, w, key)
    self:Select(kind, w.rec or {}, w.who, w.date, "web:" .. tostring(w.id), w.savedAt, key)
    self.sel.web = true
    self:RefreshPane()
end

-- Encounter-log snapshot for the selection: stored copy for saved entries, live import otherwise
function UI:SelectedLog()
    local s = self.sel
    if not s then return nil end
    if s.savedId then return s.rec.log end
    local snap = PDI.Import:Snapshot(s.who, self.variantIdx)
    -- gear captured from another character (another class) of the same @account isn't this build's
    if snap and snap.char and s.rec.char and not tostring(s.rec.char):find(snap.char, 1, true) then
        local a, b = classOf(snap.char), classOf(s.rec.char)
        if a == 0 or b == 0 or a ~= b then return nil end
    end
    return snap
end

function UI:ClearGroup()
    PDI.Group:ClearHistory()
    if self.sel and self.sel.kind == "build" and not self.sel.savedId then self.sel = nil end
    self.list.offset = 0
    self:Refresh()
end

function UI:ConfirmRemoveGroup(acct)
    if ZO_Dialogs_ShowDialog then
        ZO_Dialogs_ShowDialog("PVPDI_REMOVE_GROUP", { acct = acct }, { mainTextParams = { acct } })
    else
        self:RemoveGroup(acct)
    end
end

function UI:RemoveGroup(acct)
    PDI.Group:RemoveEntry(acct)
    if self.sel and self.sel.kind == "build" and not self.sel.savedId and self.sel.who == acct then self.sel = nil end
    PDI.Msg(string.format("Removed %s from the Group tab (saved builds kept).", acct))
    self:Refresh()
end

function UI:ShowGroupRowMenu(row, acct)
    if not (ClearMenu and AddMenuItem and ShowMenu) then return end
    ClearMenu()
    AddMenuItem("|cFFFFFF" .. acct .. "|r", function() end)
    AddMenuItem("Remove from Group tab", function() UI:ConfirmRemoveGroup(acct) end)
    ShowMenu(row)
end

-- Right-click menu on a Skills / Buffs row: pick the type directly (base game context menu)
function UI:ShowTypeMenu(row, name, current, choices, store)
    local Skills = PDI.Skills
    local function apply(fn)
        return function() fn(); UI:Refresh() end
    end
    if not (ClearMenu and AddMenuItem and ShowMenu) then
        -- no context menu available: fall back to stepping through the types
        Skills:CycleOverride(name, current, choices, store)
        UI:Refresh()
        return
    end
    ClearMenu()
    AddMenuItem("|cFFFFFF" .. tostring(name) .. "|r - choose type:", function() end)
    for _, cat in ipairs(choices) do
        local label = cat == "hidden" and "|c999999Hide this row|r"
            or (store == "buffCat" and Skills:BuffLabel(cat) or Skills.LABEL[cat] or cat)
        if cat == current then label = "> " .. label .. "  |c999999(current)|r" else label = "   " .. label end
        AddMenuItem(label, apply(function() Skills:SetOverride(name, cat, store) end))
    end
    if Skills:HasOverride(name, store) then
        AddMenuItem("|cCCCC66Back to automatic|r", apply(function() Skills:ResetOverride(name, store) end))
    end
    ShowMenu(row)
end

-- What identifies "this exact data" for the selection (a saved copy of it shows Unsave instead of Save)
function UI:SelectionFingerprint()
    local s = self.sel
    if not s or s.savedId then return nil end
    local snap = self:SelectedLog()
    local hash = snap and snap.v and snap.v.hash or "-"
    if s.kind == "build" then
        return hash .. "|" .. tostring(s.rec.buildSince or s.rec.first or "")
    elseif s.kind == "player" then
        local n = 0
        for _ in pairs(s.rec.buffs or {}) do n = n + 1 end
        return hash .. "|" .. tostring(s.rec.buffsSince or s.rec.t or "") .. "|" .. n
    end
    return nil
end

-- Id of an existing saved copy of the current (not saved) selection, or nil
function UI:ExistingSavedId()
    local s = self.sel
    if not s or s.savedId then return nil end
    if s.kind == "build" then return PDI.Group:FindSaved(s.who, self:SelectionFingerprint()) end
    if s.kind == "player" then return PDI.Data:FindSavedPlayer(s.who, self:SelectionFingerprint()) end
    if s.kind == "opp" and s.date and PDI.Data:IsSaved(s.who, s.date) then return s.who .. "|" .. tostring(s.date) end
    return nil
end

function UI:SaveOrDeleteSelected()
    local s = self.sel
    if not s then return end
    if PDI.Data:IsFollowed(s.who) then
        PDI.Data:Unfollow(s.who)
        PDI.Msg(string.format("Unfollowed %s (their snapshots were removed).", s.who))
        if s.savedId then self.sel = nil end
        self:Refresh()
        return
    end
    -- Follow: keep what you're looking at now, then a snapshot of every day you meet them from now on
    if not s.web and not self:ExistingSavedId() and not s.savedId then
        if s.kind == "build" then
            PDI.Group:SaveBuild(s.who, s.rec, self:SelectedLog(), self:SelectionFingerprint())
        elseif s.kind == "player" then
            PDI.Data:SavePlayer(s.who, s.rec, self:SelectedLog(), self:SelectionFingerprint())
        elseif s.date then
            PDI.Data:SaveOpponent(s.who, s.date, s.rec, self:SelectedLog())
        end
    end
    PDI.Data:Follow(s.who)
    PDI.Msg(string.format("Following %s - a snapshot is added every day you meet them (Following tab).", s.who))
    self:Refresh()
end

---------------------------------------------------------------------------
-- Row building
---------------------------------------------------------------------------
local function matchesSearch(text, ...)
    if text == "" then return true end
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v and string.find(string.lower(v), text, 1, true) then return true end
    end
    return false
end

local function mundusText(rec)
    local list = {}
    for m in pairs(rec.mundus or {}) do list[#list + 1] = m end
    table.sort(list)
    return #list > 0 and table.concat(list, ", ") or "-"
end

-- Opponents list: the mundus from their record, else from targeting them (any tab), the encounter log,
-- or what other players shared (esopvp.com, marked +)
local function oppMundusText(who, cls, rec)
    local t = mundusText(rec)
    if t ~= "-" then return t end
    local p = PDI.Data:GetProfile(who, rec.char)
    if p and next(p.mundus or {}) and (not cls or cls == 0 or not p.cls or p.cls == 0 or p.cls == cls) then
        return mundusText(p)
    end
    local m = PDI.Import:Mundus(PDI.Import:Snapshot(who))
    if m then return m end
    local sh = PDI.Share and PDI.Share.Shared and PDI.Share:Shared(who, cls) or nil
    if sh and type(sh.mundus) == "table" and #sh.mundus > 0 then return table.concat(sh.mundus, ", ") .. " |c66CCFF+|r" end
    return "-"
end

-- same player, character, skills and buffs = the same build (saved twice, or by you and a friend)
local function buildFingerprint(who, rec)
    rec = rec or {}
    local keys = {}
    for k in pairs(rec.skills or {}) do keys[#keys + 1] = "s:" .. tostring(k) end
    for k in pairs(rec.buffs or {}) do keys[#keys + 1] = "b:" .. tostring(k) end
    table.sort(keys)
    return tostring(who) .. "|" .. tostring(rec.char) .. "|" .. table.concat(keys, ",")
end

-- Saves of one player, class and day merged into one view: { rec = merged record, web = { sk = {...}, bf = {...} } }
-- Skills/buffs from your own saves go into rec; those only in saves shared by other players into web (shown with +).
function UI.MergedSaved(main, others)
    local base = main.rec or {}
    local rec = {}
    for k, v in pairs(base) do rec[k] = v end
    rec.skills, rec.buffs = {}, {}
    local web = { sk = {}, bf = {} }
    local function take(e, fromWeb)
        local r = e.rec or {}
        for k, sk in pairs(r.skills or {}) do
            if type(sk) == "table" and not rec.skills[k] then
                if fromWeb then
                    if not web.sk[k] then web.sk[k] = sk end
                else
                    rec.skills[k] = sk
                end
            end
        end
        for n, b in pairs(r.buffs or {}) do
            if rec.buffs[n] == nil then
                if fromWeb then
                    if web.bf[n] == nil then web.bf[n] = b end
                else
                    rec.buffs[n] = b
                end
            end
        end
        for _, k in ipairs({ "al", "race", "cls", "cp", "hp", "role", "acct" }) do
            if rec[k] == nil or rec[k] == 0 or rec[k] == "" then rec[k] = r[k] end
        end
        if not next(rec.mundus or {}) and next(r.mundus or {}) then rec.mundus = r.mundus end
        if (r.killedYou or 0) > (rec.killedYou or 0) then rec.killedYou = r.killedYou end
    end
    take(main, main.web ~= nil)
    if main.web then   -- a shared save shown on its own: its data is the row's own data
        rec.skills, rec.buffs = web.sk, web.bf
        web = { sk = {}, bf = {} }
    end
    for _, o in ipairs(others) do take(o, o.web ~= nil) end
    for k in pairs(web.sk) do if rec.skills[k] then web.sk[k] = nil end end
    for n in pairs(web.bf) do if rec.buffs[n] ~= nil then web.bf[n] = nil end end
    return { rec = rec, web = web, n = 1 + #others }
end

local function countSkills(rec)
    local n = 0
    for _ in pairs(rec.skills or {}) do n = n + 1 end
    return n
end

-- what the Skills list actually shows for an opponent: classified rows that aren't hidden
local function countVisibleSkills(rec)
    local n = 0
    for _, sk in pairs(rec.skills or {}) do
        if PDI.Skills:Classify(sk) ~= "hidden" then n = n + 1 end
    end
    return n
end

-- Selecting a player from My Kills / Kill Feed: show their latest enemy data (or just log gear)
-- fill gaps in an opponent record from the player's targeting profile
-- same character on the same day only (a build can change from one day to the next)
local function sameCharDay(char1, t1, char2, t2)
    if char1 and char2 and char1 ~= char2 then return false end
    if t1 and t2 and PDI.DateKey(t1) ~= PDI.DateKey(t2) then return false end
    return true
end

local function enrichFromProfile(rec, p)
    if not p or not sameCharDay(rec.char, rec.last or rec.first, p.char, p.t) then return end
    if (rec.al or 0) == 0 then rec.al = p.al end
    if (rec.cls or 0) == 0 then rec.cls = p.cls end
    if (rec.hp or 0) == 0 then rec.hp = p.hp end
    if not next(rec.mundus or {}) and p.mundus then rec.mundus = rec.mundus or {}; for m in pairs(p.mundus) do rec.mundus[m] = true end end
end

---------------------------------------------------------------------------
-- One player, several classes: everything is kept per @account and class (a Dragonknight and a
-- Sorcerer of the same @account never mix). Opponent records are per day; each day is shown on its own.
---------------------------------------------------------------------------
-- classes in one opponent record: { [cls] = { chars... } }
local function recClasses(rec)
    local out = {}
    if rec.chars and next(rec.chars) then
        for ch, ce in pairs(rec.chars) do
            local k = classOf(ch)
            if k == 0 and type(ce) == "table" then k = ce.cls or 0 end
            out[k] = out[k] or {}
            table.insert(out[k], ch)
        end
    else
        local k = classOf(rec.char)
        if k == 0 then k = rec.cls or 0 end
        out[k] = { rec.char }
    end
    return out
end

-- every opponent record split by class: { ["who|cls"] = { who, cls, parts = { [dk] = part }, days = {dk...} } }
local function opponentGroups()
    local groups = {}
    for dk, b in pairs(PDI.sv.opponents) do
        for who, rec in pairs(b) do
            -- only confirmed players (@account known); NPCs with player-like names never get one
            local confirmed = type(rec) == "table" and (rec.acct ~= nil or who:sub(1, 1) == "@")
            if confirmed and rec.hit and rec.hostile then
                for k, chars in pairs(recClasses(rec)) do
                    local key = who .. "|" .. k
                    local g = groups[key]
                    if not g then g = { who = who, cls = k, parts = {} }; groups[key] = g end
                    g.parts[dk] = { rec = rec, chars = chars, dk = dk }
                end
            end
        end
    end
    for _, g in pairs(groups) do
        g.days = {}
        for dk in pairs(g.parts) do g.days[#g.days + 1] = dk end
        table.sort(g.days, function(a, b) return a > b end)
    end
    return groups
end
UI.OpponentGroups = opponentGroups

-- the opponent record of one class on one day (only that class's characters' skills)
local function oppView(part, cls)
    local rec = part.rec
    local want, nClasses = {}, 0
    for _, ch in ipairs(part.chars) do want[ch] = true end
    for _ in pairs(recClasses(rec)) do nClasses = nClasses + 1 end
    local single = nClasses <= 1
    local skills = rec.skills or {}
    if not single then
        skills = {}
        for key, sk in pairs(rec.skills or {}) do
            if not sk.c then
                skills[key] = sk                    -- character unknown (seen as @account)
            else
                local h = 0
                for ch, n in pairs(sk.c) do if want[ch] then h = h + n end end
                if h > 0 then
                    local copy = {}
                    for kk, vv in pairs(sk) do copy[kk] = vv end
                    copy.h = h
                    skills[key] = copy
                end
            end
        end
    end
    local mainCls = classOf(rec.char)
    if mainCls == 0 then mainCls = rec.cls or 0 end
    return {
        acct = rec.acct, char = table.concat(part.chars, ", "), al = rec.al,
        cls = (cls and cls ~= 0) and cls or rec.cls, hp = rec.hp, mundus = rec.mundus or {}, skills = skills,
        killedYou = (single or mainCls == cls) and (rec.killedYou or 0) or 0, first = rec.first, last = rec.last,
        hit = rec.hit, hostile = rec.hostile,
    }
end

-- other classes of a player (Opponents data), newest first: { {cls=, day=}, ... }
local function otherClasses(groups, who, cls)
    local list = {}
    for _, g in pairs(groups) do
        if g.who == who and g.cls ~= cls then list[#list + 1] = { cls = g.cls, day = g.days[1] } end
    end
    table.sort(list, function(a, b) return a.day > b.day end)
    return list
end

-- Following tab: one group per followed player and class; each group has its days, and each day the
-- snapshots of that day (yours from combat / targeting / your group, and other players' shared ones, +)
local function followGroups()
    local groups = {}
    local function add(e)
        local rec = e.rec or {}
        local cls = classOf(rec.char)
        if cls == 0 then cls = tonumber(rec.cls) or 0 end
        local day = e.date or (e.savedAt and PDI.DateKey(e.savedAt)) or 0
        local gk = tostring(e.who) .. "|" .. tostring(cls)
        local g = groups[gk]
        if not g then g = { who = e.who, cls = cls, byDay = {}, days = {} }; groups[gk] = g end
        local list = g.byDay[day]
        if not list then list = {}; g.byDay[day] = list; g.days[#g.days + 1] = day end
        list[#list + 1] = e
    end
    for id, e in pairs(PDI.sv.saved or {}) do
        if type(e) == "table" and e.who then
            add({ who = e.who, kind = e.kind == "player" and "player" or "opp", rec = e.rec, date = e.date,
                  savedAt = e.savedAt, id = id })
        end
    end
    for id, b in pairs(PDI.sv.savedBuilds or {}) do
        if type(b) == "table" and b.who then
            add({ who = b.who, kind = "build", rec = b.rec, date = b.savedAt and PDI.DateKey(b.savedAt), savedAt = b.savedAt, id = id })
        end
    end
    for _, w in ipairs(PDI.Share:SharedSaved("enemy", "player", "group")) do
        add({ who = w.who, kind = (w.kind == "player" and "player") or (w.kind == "group" and "build") or "opp",
              rec = w.rec, date = w.date, savedAt = w.savedAt, web = w })
    end
    for _, g in pairs(groups) do
        table.sort(g.days, function(a, b) return a > b end)
        for _, list in pairs(g.byDay) do
            -- your own newest snapshot first, then the shared ones (newest first)
            table.sort(list, function(a, b)
                if (a.web == nil) ~= (b.web == nil) then return a.web == nil end
                return (a.savedAt or 0) > (b.savedAt or 0)
            end)
        end
    end
    return groups
end
UI.FollowGroups = followGroups

-- the merged snapshot of one day of a followed player
local function followDay(g, dk)
    local list = g.byDay[dk] or {}
    local main = list[1]
    local others = {}
    for i = 2, #list do others[#others + 1] = list[i] end
    return main, UI.MergedSaved(main or {}, others)
end

-- Show one followed player + class + day (the day buttons switch days, like in Opponents)
function UI:SelectFollow(who, cls, dk, key)
    local groups = followGroups()
    local g = groups[who .. "|" .. tostring(cls or 0)]
    if not g then return false end
    dk = (dk and g.byDay[dk]) and dk or g.days[1]
    local main, view = followDay(g, dk)
    if not main then return false end
    key = key or ("f:" .. who .. "|" .. tostring(cls))
    if main.web then
        self:Select(main.kind, main.rec or {}, who, dk, "web:" .. tostring(main.web.id), main.savedAt, key)
        self.sel.web = true
    else
        self:Select(main.kind, main.rec or {}, who, dk, main.id, main.savedAt, key)
    end
    self.sel.rec, self.sel.webExtra = view.rec, view.web
    self.sel.follow, self.sel.cls, self.sel.days, self.sel.classes = true, cls, g.days, otherClasses(groups, who, cls)
    self:RefreshPane()
    return true
end

-- Show one player + class + day from the Opponents data
function UI:SelectOpp(who, cls, dk, key)
    local groups = opponentGroups()
    local g = groups[who .. "|" .. tostring(cls or 0)]
    if not g then return false end
    dk = (dk and g.parts[dk]) and dk or g.days[1]
    local view = oppView(g.parts[dk], cls)
    local prof = PDI.Data:GetProfile(who)
    if prof and classOf(prof.char) == cls then enrichFromProfile(view, prof) end
    self:Select("opp", view, who, dk, nil, nil, key or ("o:" .. who .. "|" .. tostring(cls)))
    self.sel.cls, self.sel.days, self.sel.classes = cls, g.days, otherClasses(groups, who, cls)
    self:RefreshPane()
    return true
end

function UI:PickDay(i)
    local s = self.sel
    if not (s and s.days and s.days[i]) then return end
    if s.follow then self:SelectFollow(s.who, s.cls, s.days[i], s.key) else self:SelectOpp(s.who, s.cls, s.days[i], s.key) end
end

function UI:PickClass(i)
    local s = self.sel
    local c = s and s.classes and s.classes[i]
    if not c then return end
    if s.follow then self:SelectFollow(s.who, c.cls, c.day, s.key) else self:SelectOpp(s.who, c.cls, c.day, s.key) end
end

-- Selecting a player from My Kills / Kill Feed: their enemy data of that class if any, otherwise what
-- you saw when targeting them (works for friendly players too)
local function selectFromKills(who, char, al, cls, key)
    if cls and UI:SelectOpp(who, cls, nil, key) then return end
    local prof = PDI.Data:GetProfile(who, char ~= "-" and char or nil)
    if prof and cls and cls ~= 0 and classOf(prof.char) ~= 0 and classOf(prof.char) ~= cls then prof = nil end
    prof = prof or {}
    local p = {
        char = prof.char or (char ~= "-" and char or nil), acct = who:sub(1, 1) == "@" and who or prof.acct,
        al = (prof.al and prof.al ~= 0) and prof.al or al, cls = prof.cls or cls, race = prof.race, cp = prof.cp, hp = prof.hp,
        mundus = prof.mundus or {}, buffs = prof.buffs or {}, buffsSince = prof.buffsSince, t = prof.t, skills = {},
    }
    UI:Select("player", p, who, nil, nil, nil, key or ("k:" .. who))
end

-- My Kills / Kill Feed: { k, a, al, c, ch = { [char] = {k, a} } } -> one entry per class
local function killRowsByClass(e)
    local byCls = {}
    local function add(k, x, ch)
        local r = byCls[k]
        if not r then r = { k = 0, a = 0, chars = {} }; byCls[k] = r end
        r.k = r.k + (x.k or 0); r.a = r.a + (x.a or 0)
        if ch and ch ~= "?" then r.chars[#r.chars + 1] = ch end
    end
    for ch, x in pairs(e.ch or {}) do
        local k = ch == "?" and 0 or classOf(ch)
        if k == 0 and ch ~= "?" then k = tonumber(x.cls) or 0 end      -- esopvp.com's leaderboard knows it
        add(k, x, ch)
    end
    if not next(byCls) then add(classOf(e.c), { k = e.k, a = e.a }, e.c) end
    -- counts whose character's class isn't known yet go with the class of their last character
    local lastCls = classOf(e.c)
    if byCls[0] and lastCls ~= 0 and byCls[lastCls] then
        local u, t = byCls[0], byCls[lastCls]
        t.k = t.k + u.k; t.a = t.a + u.a
        for _, ch in ipairs(u.chars) do t.chars[#t.chars + 1] = ch end
        byCls[0] = nil
    end
    local out = {}
    for k, r in pairs(byCls) do
        if r.k > 0 or r.a > 0 then
            table.sort(r.chars)
            out[#out + 1] = { cls = k, k = r.k, a = r.a, chars = r.chars }
        end
    end
    return out
end

function UI:BuildRows()
    local rows = {}
    local fac, q = self.faction, self.search

    if self.tab == "my" or self.tab == "feed" then
        -- one row per player and class (that class's characters listed)
        for who, e in pairs(PDI.Data:GetPeriod(self.tab, self.period)) do
            for _, r in ipairs(killRowsByClass(e)) do
                local c = #r.chars > 0 and table.concat(r.chars, ", ") or "-"
                if (fac == 0 or e.al == fac) and matchesSearch(q, who, c) then
                    local key = "k:" .. who .. "|" .. r.cls
                    local cls, first = r.cls, r.chars[1] or "-"
                    rows[#rows + 1] = { who = who, c = c, al = e.al or 0,
                                        clsName = r.cls ~= 0 and PDI.ClassText(r.cls) or "-",
                                        k = r.k, a = r.a, tot = r.k + r.a, key = key,
                                        onClick = function() selectFromKills(who, first, e.al, cls, key) end }
                end
            end
        end
    elseif self.tab == "opp" then
        -- one row per player and class over all the days kept (7); the details show one day at a time
        for _, g in pairs(opponentGroups()) do
            local newest = g.parts[g.days[1]]
            local rec = newest.rec
            local chars, seenCh, killed = {}, {}, 0
            for _, dk in ipairs(g.days) do
                local part = g.parts[dk]
                for _, ch in ipairs(part.chars) do
                    if ch and not seenCh[ch] then seenCh[ch] = true; chars[#chars + 1] = ch end
                end
                killed = killed + (oppView(part, g.cls).killedYou or 0)
            end
            local charText = table.concat(chars, ", ")
            if (fac == 0 or rec.al == fac) and matchesSearch(q, g.who, charText) then
                local key = "o:" .. g.who .. "|" .. g.cls
                local who, cls = g.who, g.cls
                rows[#rows + 1] = {
                    who = who, char = charText ~= "" and charText or "-", al = rec.al or 0,
                    clsName = g.cls ~= 0 and PDI.ClassText(g.cls) or "-",
                    hp = rec.hp or 0, mundusText = oppMundusText(who, g.cls, rec), nSkills = countVisibleSkills(oppView(newest, g.cls)),
                    nDays = #g.days, killedYou = killed, last = rec.last or 0, key = key,
                    onClick = function() UI:SelectOpp(who, cls, nil, key) end,
                }
            end
        end
    elseif self.tab == "saved" then
        -- one row per followed player and class; the details show one day at a time (day buttons)
        local TYPE = { opp = "|cFF8866Enemy|r", player = "|c66DD66Player|r", build = "|c66CCFFGroup|r" }
        for _, g in pairs(followGroups()) do
            local newest = g.days[1]
            local main, view = followDay(g, newest)
            local rec = (main and main.rec) or {}
            local chars, seenCh, kinds, web, killed, followedAt = {}, {}, {}, false, 0, nil
            for _, dk in ipairs(g.days) do
                for _, e in ipairs(g.byDay[dk]) do
                    local ch = e.rec and e.rec.char
                    if ch and not seenCh[ch] then seenCh[ch] = true; chars[#chars + 1] = ch end
                    if e.web then web = true end
                    kinds[e.kind] = true
                    killed = math.max(killed, tonumber(e.rec and e.rec.killedYou) or 0)
                end
            end
            local typeText = TYPE[main and main.kind or "opp"] or ""
            local charText = table.concat(chars, ", ")
            if (fac == 0 or (view.rec.al or rec.al) == fac) and matchesSearch(q, g.who, charText) then
                local key = "f:" .. g.who .. "|" .. g.cls
                local who, cls = g.who, g.cls
                local isPlayer = not kinds.opp
                rows[#rows + 1] = {
                    who = who, char = charText ~= "" and charText or "-", al = view.rec.al or rec.al or 0,
                    kindText = typeText .. (web and " |c66CCFF+|r" or ""), nDays = #g.days, date = newest,
                    nSkills = countVisibleSkills(view.rec) + countVisibleSkills({ skills = view.web.sk }),
                    killedYou = isPlayer and "-" or killed, key = key,
                    onClick = function() UI:SelectFollow(who, cls, nil, key) end,
                }
            end
        end
    elseif self.tab == "group" then
        for acct, e in pairs(PDI.sv.group) do
            if (fac == 0 or e.al == fac) and matchesSearch(q, acct, e.char) then
                local key = "g:" .. acct
                rows[#rows + 1] = {
                    who = acct, char = e.char or "-", al = e.al or 0, clsName = PDI.ClassText(e.cls),
                    roleText = PDI.RoleText(e.role), cp = e.cp or 0, last = e.last or 0,
                    now = PDI.Group.current[acct], hasLog = PDI.Import:Has(acct) and 1 or 0, key = key,
                    onClick = function() UI:Select("build", e, acct, nil, nil, nil, key) end,
                    onRightClick = function(row) UI:ShowGroupRowMenu(row, acct) end,
                }
            end
            -- their other characters (another class) keep their own row
            local curCls = classOf(e.char) ~= 0 and classOf(e.char) or (e.cls or 0)
            for ch, o in pairs(e.other or {}) do
                local oc = (type(o) == "table" and o.cls and o.cls ~= 0) and o.cls or classOf(ch)
                if type(o) == "table" and oc ~= curCls and (fac == 0 or e.al == fac) and matchesSearch(q, acct, ch) then
                    local key = "g:" .. acct .. "|" .. ch
                    local view = {}
                    for k, v in pairs(o) do view[k] = v end
                    view.al, view.acct, view.times, view.first = e.al, e.acct, e.times, e.first
                    view.cls = oc
                    rows[#rows + 1] = {
                        who = acct, char = ch, al = e.al or 0, clsName = PDI.ClassText(oc),
                        roleText = PDI.RoleText(o.role), cp = o.cp or 0, last = o.last or 0,
                        now = false, hasLog = 0, key = key,
                        onClick = function() UI:Select("build", view, acct, nil, nil, nil, key) end,
                        onRightClick = function(row) UI:ShowGroupRowMenu(row, acct) end,
                    }
                end
            end
        end
    end
    return rows
end

local function sortRows(rows, s, cols)
    if not s or s.key == "" then return end
    local isNum = s.key == "last"
    for _, c in ipairs(cols) do if c.key == s.key then isNum = c.num end end
    table.sort(rows, function(a, b)
        local va, vb = a[s.key], b[s.key]
        if isNum then
            va, vb = tonumber(va) or 0, tonumber(vb) or 0
        else
            va, vb = string.lower(tostring(va or "")), string.lower(tostring(vb or ""))
        end
        if va == vb then
            return string.lower(tostring(a.who or a.n or "")) < string.lower(tostring(b.who or b.n or ""))
        end
        if s.desc then return va > vb else return va < vb end
    end)
end

local function skillRows(rec)
    local rows = {}
    for _, s in pairs(rec.skills or {}) do
        local types = {}
        for ty in pairs(s.ty or {}) do types[#types + 1] = TYPE_LABEL[ty] or ty end
        table.sort(types)
        rows[#rows + 1] = { n = s.n, h = s.h or 0, m = s.m or 0, total = s.total or 0,
                            tyText = table.concat(types, ", "), tooltipId = s.id }
    end
    return rows
end

---------------------------------------------------------------------------
-- Render
---------------------------------------------------------------------------
function UI:EmptyText()
    if self.tab == "opp" then return "No enemy combat data for this date (Cyrodiil, Imperial City, Battlegrounds or duels)." end
    if self.tab == "feed" then return "No kill feed entries yet. Make sure the PvP kill feed is enabled in Settings > Social." end
    if self.tab == "group" then
        local scope = PDI.sv.settings.groupScope or "pvp"
        return scope == "pvp" and "No group history yet. Group up in Cyrodiil, Imperial City or a Battleground."
            or "No group history yet - group up with someone."
    end
    if self.tab == "saved" then return "Nobody followed yet. Select a player (Opponents, Group...) and press Follow." end
    return "No kills recorded for this period."
end

function UI:UpdateToolbar()
    local showPeriods = (self.tab == "my" or self.tab == "feed")
    for k, b in pairs(self.periodBtns) do
        b:SetHidden(not showPeriods)
        setPressed(b, k == self.period)
    end
    local showDates = false     -- Opponents: one row per player and class, days in the details
    self.datePrev:SetHidden(true)
    self.dateNext:SetHidden(true)
    self.dateLabel:SetHidden(true)
    self.dateHint:SetHidden(self.tab ~= "opp")
    if showDates then
        local dates = PDI.Data:GetOpponentDates()
        self.oppDateIdx = zo_clamp(self.oppDateIdx, 1, math.max(1, #dates))
        local dk = dates[self.oppDateIdx]
        self.dateLabel:SetText(dk and PDI.FormatDate(dk) or "No data")
        self.datePrev:SetEnabled(self.oppDateIdx < #dates)
        self.dateNext:SetEnabled(self.oppDateIdx > 1)
    end
    local fromServer = PDI.Data:FeedFromServer(self.tab, self.period)
    self.resetBtn:SetHidden(not showPeriods or fromServer ~= nil)     -- esopvp.com's leaderboard can't be reset here
    if showPeriods then self.resetBtn:SetText("Reset " .. self:PeriodLabel(self.period)) end
    self.clearGroupBtn:SetHidden(self.tab ~= "group")
end

function UI:UpdatePaneMore()
    for _, g in ipairs({ self.skillGrid, self.gearGrid }) do
        local below = #g.data - (g.offset + g.numRows)
        g.more:SetText(below > 0 and string.format("%d more below - scroll", below) or "")
    end
end

-- Rows for the Skills grid
--  * group members: skill bars from the encounter log (or skills seen in combat if none captured)
--  * opponents: what they hit you with, classified Weapon > Skill > Ultimate > Proc Set > Damage Effect
local WEB = " |c66CCFF+|r"   -- from other players (esopvp.com)
local function paneSkillRows(s, snap, sh)
    local rows = {}
    for _, r in ipairs(PDI.Import:BarRows(snap)) do
        local bar = r.sec:find("Front") and "|c66CCFFFront|r" or "|cCC99FFBack|r"
        rows[#rows + 1] = { n = r.n, info = bar .. "  " .. r.info, tooltipId = r.tooltipId }
    end
    if s.kind == "build" then
        if #rows > 0 then return rows end   -- real skill bars beat "seen" skills
        local seen = {}
        for _, sk in pairs(s.rec.skills or {}) do
            seen[#seen + 1] = { n = sk.n, info = "|c999999Seen in combat|r", h = sk.h or 0, tooltipId = sk.id }
        end
        table.sort(seen, function(a, b) return a.h > b.h end)
        for _, r in ipairs(seen) do rows[#rows + 1] = r end
        return rows
    end

    local list, have = {}, {}
    -- the character that used a skill most (one @account can switch characters during a day)
    local function topChar(sk)
        local best, bn = nil, -1
        for ch, n in pairs(sk.c or {}) do if n > bn then best, bn = ch, n end end
        return best
    end
    local function add(sk, web)
        local cat = PDI.Skills:Classify(sk)
        if cat ~= "hidden" then
            local name = PDI.Skills:BuffName(sk.n)     -- a set's proc under the set's name (Eagle's Mark = Aerie's Cry)
            list[#list + 1] = {
                n = name, cat = cat, info = PDI.Skills.LABEL[cat] .. (web and WEB or ""), h = sk.h or 0, tooltipId = sk.id,
                ch = not web and topChar(sk) or nil,
                onRightClick = function(row) UI:ShowTypeMenu(row, name, cat, PDI.Skills.CYCLE, "skillCat") end,
            }
        end
    end
    for _, sk in pairs(s.rec.skills or {}) do
        have[string.lower(sk.n or "")] = true
        add(sk)
    end
    -- what other players saw this player use (esopvp.com), when it's not in your own data
    for _, sk in ipairs(sh and sh.sk or {}) do
        if sk.n and not have[string.lower(sk.n)] then
            have[string.lower(sk.n)] = true
            add({ n = sk.n, id = sk.id, h = 0, ty = sk.ty or {} }, true)
            local last = list[#list]
            if last and last.n == sk.n and PDI.Skills:BuffUncertain(sk.n) then last.n = sk.n .. " |cFFCC66*|r" end
        end
    end
    -- several characters: one block per character (latest first), skills of unknown character last
    local chars = s.rec.chars or {}
    local nChars = 0
    for _ in pairs(chars) do nChars = nChars + 1 end
    local split = false
    if nChars > 1 then
        local seenCh = {}
        for _, r in ipairs(list) do if r.ch then seenCh[r.ch] = true end end
        local n = 0
        for _ in pairs(seenCh) do n = n + 1 end
        split = n > 1
    end
    local function chRank(r)
        if not split then return 0 end
        if not r.ch then return 1e12 end
        return -((chars[r.ch] and chars[r.ch].last) or 0)
    end
    table.sort(list, function(a, b)
        local ca, cb = chRank(a), chRank(b)
        if ca ~= cb then return ca < cb end
        local oa, ob = PDI.Skills.ORDER[a.cat] or 9, PDI.Skills.ORDER[b.cat] or 9
        if oa ~= ob then return oa < ob end
        if a.h ~= b.h then return a.h > b.h end
        return a.n < b.n
    end)
    if #rows > 0 and #list > 0 then
        rows[#rows + 1] = { n = "", info = "" }   -- spacer between captured bars and what hit you
    end
    local lastCh = false
    for _, r in ipairs(list) do
        if split and r.ch ~= lastCh then
            lastCh = r.ch
            local e = r.ch and chars[r.ch]
            rows[#rows + 1] = { n = "|cFFCC66" .. (r.ch or "Earlier (character unknown)") .. "|r",
                                info = e and (e.cls or 0) ~= 0 and PDI.ClassText(e.cls) or "" }
        end
        rows[#rows + 1] = r
    end
    return rows
end

-- Days / other classes of the selected player (Opponents data)
function UI:UpdateDayButtons()
    local s = self.sel
    local days = (s and s.days) or {}
    local showDays = #days > 1
    self.dayLabel:SetHidden(not showDays)
    local last = self.dayLabel
    for i, b in ipairs(self.dayBtns) do
        local dk = showDays and days[i]
        b:SetHidden(not dk)
        if dk then
            b:SetText(string.format("%02d-%02d", math.floor(dk / 100) % 100, dk % 100))
            setPressed(b, dk == s.date)
            last = b
        end
    end
    local classes = (s and s.classes) or {}
    self.classLabel:SetHidden(#classes == 0)
    self.classLabel:ClearAnchors()
    self.classLabel:SetAnchor(LEFT, showDays and last or self.dayLabel, showDays and RIGHT or LEFT, showDays and 14 or 0, 0)
    local prev = self.classLabel
    for i, b in ipairs(self.classBtns) do
        local c = classes[i]
        b:SetHidden(not c)
        if c then
            b:SetText(c.cls ~= 0 and zo_strformat("<<1>>", PDI.ClassText(c.cls)) or "Unknown")
            b:ClearAnchors()
            b:SetAnchor(LEFT, prev, RIGHT, 2, 0)
            prev = b
        end
    end
end

function UI:RefreshPane()
    local s = self.sel
    local snap = s and self:SelectedLog() or nil
    local hasSel = s ~= nil

    -- Follow works on any @account (also an entry other players shared): from then on, every day you meet them
    self.saveBtn:SetHidden(not hasSel or type(s.who) ~= "string" or s.who:sub(1, 1) ~= "@")
    self.variantBtn:SetHidden(true)
    self.removeBtn:SetHidden(not (hasSel and s.kind == "build" and not s.savedId))
    if self.linkBtn then self.linkBtn:SetHidden(not hasSel or (s and s.link) or false) end
    self:UpdateDayButtons()
    for _, c in ipairs({ self.info, self.skillTitle, self.gearTitle, self.skillGrid.box, self.gearGrid.box,
                         self.skillGrid.more, self.gearGrid.more, self.skillGrid.empty, self.gearGrid.empty }) do
        c:SetHidden(not hasSel)
    end
    self.paneEmpty:SetHidden(hasSel)

    if not s then
        self.paneTitle:SetText("Player details")
        self.paneEmpty:SetText("Click a player on the left to see their skills, mundus, gear and skill bars here.")
        return
    end

    -- data other players shared about this player (esopvp.com, via the Companion)
    -- data other players shared about this player: the same class, the same day only
    local myCls = s.cls or classOf(s.rec.char)
    if myCls == 0 then myCls = s.rec.cls or 0 end
    local sh = PDI.Share and PDI.Share.Shared and PDI.Share:Shared(s.who, myCls) or nil
    if sh and not s.link then
        local myT = s.rec.last or s.rec.t or s.savedAt
        local myDay = s.date or (myT and PDI.DateKey(myT))
        if (sh.cls and myCls ~= 0 and sh.cls ~= myCls) or (myDay and sh.t and PDI.DateKey(sh.t) ~= myDay) then sh = nil end
    end
    local webGear = false
    if (not snap or not snap.v) and sh and sh.v and s.kind ~= "build" then
        snap = { v = sh.v, names = sh.names or {} }
        webGear = true
    end
    local rec = s.rec
    -- a group member you also targeted: add what targeting recorded (same character only)
    local prof
    if s.kind == "build" and not s.savedId then
        local p = PDI.Data:GetProfile(s.who, s.rec.char)
        if p and sameCharDay(s.rec.char, s.rec.last, p.char, p.t) then prof = p end
    end
    if sh or prof then
        -- fill what this record lacks: first from your own targeting, then from the shared profile
        local fill = {}
        for _, k in ipairs({ "al", "race", "cls", "cp", "hp", "role" }) do
            local v = prof and prof[k]
            if v == nil or v == 0 or v == "" then v = sh and sh[k] end
            fill[k] = v
        end
        local buffs, mundus
        if prof and next(prof.buffs or {}) then
            buffs = {}
            for n, b in pairs(prof.buffs) do buffs[n] = b end
            for n, b in pairs(s.rec.buffs or {}) do buffs[n] = b end
        end
        if prof and not next(s.rec.mundus or {}) and next(prof.mundus or {}) then mundus = prof.mundus end
        rec = setmetatable({}, { __index = function(_, k)
            if k == "buffs" and buffs then return buffs end
            if k == "mundus" and mundus then return mundus end
            local v = s.rec[k]
            if (v == nil or v == 0 or v == "") and fill[k] ~= nil then return fill[k] end
            return v
        end })
    end
    local charText = (rec.char and rec.char ~= s.who) and ("  |c999999(" .. rec.char .. ")|r") or ""
    local former = PDI.Share.FormerAccounts and PDI.Share:FormerAccounts(rec.acct or (s.who and s.who:sub(1, 1) == "@" and s.who) or nil)
    local formerText = former and ("  |cFFCC66formerly " .. table.concat(former, ", ") .. "|r") or ""
    self.paneTitle:SetText(s.who .. charText .. formerText)

    local logLine = snap and snap.v and string.format("|c66CCFF%s %s%s|r", webGear and "Gear (esopvp.com) captured" or "Gear captured",
        PDI.FormatTime(snap.v.seen), (snap.v.zone and snap.v.zone ~= "") and (" in " .. snap.v.zone) or "") or nil
    local tgt = PDI.Data:GetProfile(s.who, rec.char)
    if tgt and (myCls == 0 or not tgt.cls or tgt.cls == 0 or tgt.cls == myCls) and not next(tgt.mundus or {}) then tgt = nil end
    local mundus = next(rec.mundus or {}) and mundusText(rec) or PDI.Import:Mundus(snap)
        or (tgt and mundusText(tgt))
        or (sh and sh.mundus and #sh.mundus > 0 and (table.concat(sh.mundus, ", ") .. WEB)) or "-"
    local lines
    if s.kind == "build" then
        -- only plain buffs here; passives, food, sets, skills... are listed with their type in the grid
        local buffs, seenB = {}, {}
        for name, b in pairs(rec.buffs or {}) do
            local cat, shown = PDI.Skills:ClassifyBuff(name, type(b) == "table" and b.id or b, type(b) == "table" and b.perm or nil, rec.cls)
            if cat == "buff" and not seenB[shown] then seenB[shown] = true; buffs[#buffs + 1] = shown end
        end
        table.sort(buffs)
        local nSaved = PDI.Group:CountSaved(s.who)
        lines = {
            string.format("%s   %s %s", PDI.FactionText(rec.al, false), rec.race or "", PDI.ClassText(rec.cls)),
            string.format("CP |cFFFFFF%s|r   Role: |cFFFFFF%s|r   Max health: |cFFFFFF%s|r",
                rec.cp and PDI.Num(rec.cp) or "-", PDI.RoleText(rec.role),
                (rec.hp or 0) > 0 and PDI.Num(rec.hp) or "?"),
            string.format("Mundus: |cFFFFFF%s|r", mundus),
            "Buffs: |cCCCCCC" .. (#buffs > 0 and table.concat(buffs, ", ") or "-") .. "|r",
            s.link and "|c999999Linked in chat|r" or s.savedId and string.format("Saved build from %s", PDI.FormatTime(s.savedAt))
                or string.format("Grouped %d time(s), last %s%s", rec.times or 1,
                    PDI.Group.current[s.who] and "now" or PDI.FormatTime(rec.last),
                    nSaved > 0 and string.format("  |  %d saved", nSaved) or ""),
        }
        self.saveBtn:SetText(PDI.Data:IsFollowed(s.who) and "Unfollow" or "Follow")
    elseif s.kind == "player" then
        lines = {
            string.format("%s   %s %s", PDI.FactionText(rec.al, false), rec.race or "", PDI.ClassText(rec.cls)),
            string.format("CP |cFFFFFF%s|r   Health when targeted: |cFFFFFF%s|r",
                rec.cp and PDI.Num(rec.cp) or "-", (rec.hp or 0) > 0 and PDI.Num(rec.hp) or "?"),
            string.format("Mundus: |cFFFFFF%s|r", mundus),
            rec.t and string.format("Last targeted %s%s", PDI.FormatTime(rec.t),
                rec.buffsSince and string.format("   |c999999buffs collected since %s|r", PDI.FormatTime(rec.buffsSince)) or "")
                or "|c999999Not targeted yet - put your reticle on this player to record class, health, mundus and buffs.|r",
        }
        if s.savedId and not s.link then lines[#lines + 1] = "|c999999Saved " .. PDI.FormatTime(s.savedAt) .. "|r" end
        self.saveBtn:SetText(PDI.Data:IsFollowed(s.who) and "Unfollow" or "Follow")
    else
        lines = {
            string.format("%s   %s", PDI.FactionText(rec.al, false), PDI.ClassText(rec.cls)),
            string.format("Health when targeted: |cFFFFFF%s|r   Killed you: |cFFFFFF%d|r",
                (rec.hp or 0) > 0 and (rec.hp <= PDI.MAX_PLAUSIBLE_HP and PDI.Num(rec.hp) or "?") or "unknown", rec.killedYou or 0),
            string.format("Mundus: |cFFFFFF%s|r", mundus),
            s.date and string.format("Seen |cFFFFFF%s|r %s-%s%s", PDI.FormatDate(s.date),
                rec.first and os.date("%H:%M", rec.first) or "-", rec.last and os.date("%H:%M", rec.last) or "-",
                s.savedAt and (", saved " .. PDI.FormatTime(s.savedAt)) or "")
                or (s.link and "|c999999Skills seen (most used first)|r" or "No enemy combat data in the last 7 days."),
        }
        if s.savedId then
            self.saveBtn:SetText(PDI.Data:IsFollowed(s.who) and "Unfollow" or "Follow")
        else
            self.saveBtn:SetText(PDI.Data:IsFollowed(s.who) and "Unfollow" or "Follow")
        end
    end
    if logLine then lines[#lines + 1] = logLine end
    if s.link then
        lines[#lines + 1] = "|c66CCFFFrom a build link in chat|r"
    elseif s.web then
        lines[#lines + 1] = string.format("|c66CCFFShared build (esopvp.com), saved %s|r", PDI.FormatTime(s.savedAt))
    end
    do  -- one @account, several characters that day
        local list = {}
        for ch, e in pairs(s.rec.chars or {}) do
            list[#list + 1] = ch .. (((e.cls or 0) ~= 0) and (" " .. PDI.ClassText(e.cls)) or "")
        end
        if #list > 1 then
            table.sort(list)
            lines[#lines + 1] = "|cFFCC66Characters:|r " .. table.concat(list, ", ")
        end
    end
    if sh then
        lines[#lines + 1] = string.format("|c66CCFF+|r |c999999= from esopvp.com, seen %s|r", PDI.FormatTime(sh.t))
    end
    self.info:SetText(table.concat(lines, "\n"))

    if snap and (snap.count or 1) > 1 then
        self.variantBtn:SetHidden(false)
        self.variantBtn:SetText(string.format("Build %d/%d", snap.idx, snap.count))
    end

    self.skillTitle:SetText(s.kind == "build" and "Skills" or s.kind == "player" and "Skills & Buffs  |c999999(right-click: type;|r |cFFCC66*|r |c999999= maybe from another player)|r"
        or "Skills  |c999999(right-click a row to pick its type)|r")
    local skills
    if s.kind == "player" then
        skills = {}
        -- same categories and corrections as an enemy's skills (right-click a row to change its type)
        local shownSeen = {}
        for name, b in pairs(rec.buffs or {}) do
            if type(b) ~= "table" then b = { id = b } end      -- group records keep just the ability id
            local cat, shown = PDI.Skills:ClassifyBuff(name, b.id, b.perm, rec.cls)
            if cat ~= "hidden" and not shownSeen[shown] then
                shownSeen[shown] = true
                local label = PDI.Skills:BuffUncertain(name) and (shown .. " |cFFCC66*|r") or shown
                skills[#skills + 1] = { n = label, cat = cat, info = PDI.Skills:BuffLabel(cat), tooltipId = b.id,
                    onRightClick = function(row) UI:ShowTypeMenu(row, shown, cat, PDI.Skills.BUFF_CYCLE, "buffCat") end }
            end
        end
        for name, b in pairs(sh and sh.bf or {}) do
            if type(b) ~= "table" then b = { id = b } end
            local cat, shown = PDI.Skills:ClassifyBuff(name, b.id, b.perm, rec.cls)
            if cat ~= "hidden" and not shownSeen[shown] then
                shownSeen[shown] = true
                local label = PDI.Skills:BuffUncertain(name) and (shown .. " |cFFCC66*|r") or shown
                skills[#skills + 1] = { n = label, cat = cat, info = PDI.Skills:BuffLabel(cat) .. WEB, tooltipId = b.id,
                    onRightClick = function(row) UI:ShowTypeMenu(row, shown, cat, PDI.Skills.BUFF_CYCLE, "buffCat") end }
            end
        end
        local wx = s.webExtra or {}
        for name, b in pairs(wx.bf or {}) do
            if type(b) ~= "table" then b = { id = b } end
            local cat, shown = PDI.Skills:ClassifyBuff(name, b.id, b.perm, rec.cls)
            if cat ~= "hidden" and not shownSeen[shown] then
                shownSeen[shown] = true
                local label = PDI.Skills:BuffUncertain(name) and (shown .. " |cFFCC66*|r") or shown
                skills[#skills + 1] = { n = label, cat = cat, info = PDI.Skills:BuffLabel(cat) .. WEB, tooltipId = b.id,
                    onRightClick = function(row) UI:ShowTypeMenu(row, shown, cat, PDI.Skills.BUFF_CYCLE, "buffCat") end }
            end
        end
        -- skills seen in combat (a merged save of the same player as an enemy)
        local function addSkill(sk, web)
            if type(sk) ~= "table" or not sk.n then return end
            local cat = PDI.Skills:Classify(sk)
            local name = PDI.Skills:BuffName(sk.n)
            if cat ~= "hidden" and not shownSeen[name] then
                shownSeen[name] = true
                skills[#skills + 1] = { n = name, cat = cat, info = PDI.Skills.LABEL[cat] .. (web and WEB or ""), tooltipId = sk.id,
                    onRightClick = function(row) UI:ShowTypeMenu(row, name, cat, PDI.Skills.CYCLE, "skillCat") end }
            end
        end
        for _, sk in pairs(rec.skills or {}) do addSkill(sk, false) end
        for _, sk in pairs(wx.sk or {}) do addSkill(sk, true) end
        table.sort(skills, function(a, b)
            local oa = a.cat == "buff" and 999 or (PDI.Skills.ORDER[a.cat] or 50)
            local ob = b.cat == "buff" and 999 or (PDI.Skills.ORDER[b.cat] or 50)
            if oa ~= ob then return oa < ob end
            return a.n < b.n
        end)
        -- like on esopvp.com: skills, passives, sets, food... first, then the plain buffs under "Buffs"
        local firstBuff
        for idx, r in ipairs(skills) do if r.cat == "buff" then firstBuff = idx; break end end
        if firstBuff then
            table.insert(skills, firstBuff, { n = "|cC5C29EBuffs|r", info = "" })
            if firstBuff > 1 then table.insert(skills, firstBuff, { n = "", info = "" }) end
        end
    else
        local wx = s.webExtra
        local shOpp = s.kind == "opp" and sh or nil
        if wx and next(wx.sk or {}) then   -- skills only in a save another player shares (+)
            local list = {}
            for _, sk in ipairs(shOpp and shOpp.sk or {}) do list[#list + 1] = sk end
            for _, sk in pairs(wx.sk) do list[#list + 1] = { n = sk.n, id = sk.id, ty = sk.ty } end
            shOpp = setmetatable({ sk = list }, { __index = shOpp or {} })
        end
        skills = paneSkillRows(s, snap, shOpp)
        if wx and s.kind == "opp" then
            -- buffs from a merged save of the same player made by targeting them
            local brows, seenB = {}, {}
            for _, r in ipairs(skills) do seenB[r.n] = true end
            local function addBuff(name, b, web)
                if type(b) ~= "table" then b = { id = b } end
                local cat, shown = PDI.Skills:ClassifyBuff(name, b.id, b.perm, rec.cls)
                if cat ~= "hidden" and not seenB[shown] then
                    seenB[shown] = true
                    local label = PDI.Skills:BuffUncertain(name) and (shown .. " |cFFCC66*|r") or shown
                    brows[#brows + 1] = { n = label, cat = cat, info = PDI.Skills:BuffLabel(cat) .. (web and WEB or ""), tooltipId = b.id,
                        onRightClick = function(row) UI:ShowTypeMenu(row, shown, cat, PDI.Skills.BUFF_CYCLE, "buffCat") end }
                end
            end
            for n, b in pairs(rec.buffs or {}) do addBuff(n, b, false) end
            for n, b in pairs(wx.bf or {}) do addBuff(n, b, true) end
            table.sort(brows, function(a, b)
                local oa = a.cat == "buff" and 999 or (PDI.Skills.ORDER[a.cat] or 50)
                local ob = b.cat == "buff" and 999 or (PDI.Skills.ORDER[b.cat] or 50)
                if oa ~= ob then return oa < ob end
                return a.n < b.n
            end)
            if #brows > 0 then
                if #skills > 0 then skills[#skills + 1] = { n = "", info = "" } end
                local headed = false
                for _, r in ipairs(brows) do
                    if r.cat == "buff" and not headed then headed = true; skills[#skills + 1] = { n = "|cC5C29EBuffs|r", info = "" } end
                    skills[#skills + 1] = r
                end
            end
        end
        if s.kind == "build" then
            -- a group member's buffs that aren't plain buffs (Passive Skill, Food Buff, Proc Set...)
            local extra, seenB = {}, {}
            for _, r in ipairs(skills) do seenB[r.n] = true end
            -- with the gear captured, a set seen only as a buff is another group member's (Powerful Assault...)
            local worn
            for _, g in ipairs(snap and snap.v and snap.v.gear or {}) do
                local sid = tonumber(g.set)
                if sid and sid > 0 then
                    local n = (PDI.sv.setNames or {})[sid] or (GetItemSetName and GetItemSetName(sid))
                    if n and n ~= "" then worn = worn or {}; worn[string.lower(zo_strformat("<<1>>", n))] = true end
                end
            end
            for name, b in pairs(rec.buffs or {}) do
                local id = type(b) == "table" and b.id or b
                local cat, shown = PDI.Skills:ClassifyBuff(name, id, type(b) == "table" and b.perm or nil, rec.cls)
                local isSet = cat == "set" or cat == "mythic" or cat == "monster"
                if isSet and worn and not worn[string.lower(shown or "")] then cat = "hidden" end
                if cat ~= "hidden" and cat ~= "buff" and not seenB[shown] then
                    seenB[shown] = true
                    local label = PDI.Skills:BuffUncertain(name) and (shown .. " |cFFCC66*|r") or shown
                    extra[#extra + 1] = { n = label, cat = cat, info = PDI.Skills:BuffLabel(cat), tooltipId = id, fromBuff = true,
                        onRightClick = function(row) UI:ShowTypeMenu(row, shown, cat, PDI.Skills.BUFF_CYCLE, "buffCat") end }
                end
            end
            table.sort(extra, function(a, b)
                local oa, ob = PDI.Skills.ORDER[a.cat] or 50, PDI.Skills.ORDER[b.cat] or 50
                if oa ~= ob then return oa < ob end
                return a.n < b.n
            end)
            if #skills > 0 and #extra > 0 then skills[#skills + 1] = { n = "", info = "" } end
            for _, r in ipairs(extra) do skills[#skills + 1] = r end
        end
    end
    -- Monomyth Reforged: a mythic ring seen only through its 3 effects
    if s.kind ~= "opp" and PDI.Skills:HasMonomyth(rec.mm, rec.buffs, s.webExtra and s.webExtra.bf) then
        table.insert(skills, 1, { n = "Monomyth Reforged", cat = "mythic", info = PDI.Skills.LABEL.mythic or "Mythic" })
    end
    -- skills that may come from another player: a Contingency / Banner (they buff the whole group) or, when the
    -- bars were captured, any skill/ultimate seen only as a buff on them - marked * unless it is on the bars
    do
        local onBars, haveBars = {}, false
        for _, list in ipairs({ snap and snap.v and snap.v.bar1 or {}, snap and snap.v and snap.v.bar2 or {} }) do
            for _, id in ipairs(list) do
                local n = id and id > 0 and GetAbilityName(id)
                if (not n or n == "") and snap and snap.names then n = snap.names[id] end
                if n and n ~= "" then onBars[string.lower(zo_strformat("<<1>>", n))] = true; haveBars = true end
            end
        end
        for _, r in ipairs(skills) do
            if (r.cat == "skill" or r.cat == "ultimate") and type(r.n) == "string" and not r.n:find("*", 1, true) then
                local plain = string.lower(zo_strtrim((r.n:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""))))
                if not onBars[plain] and (plain:find(" contingency$") or plain:find(" banner$")
                        or (haveBars and s.kind ~= "opp" and r.fromBuff)) then
                    r.n = r.n .. " |cFFCC66*|r"
                end
            end
        end
    end
    self.skillGrid:SetData(skills)
    self.skillGrid:Layout(COLUMNS.skillpane, nil)
    self.skillGrid:Render()
    self.skillGrid.empty:SetHidden(#skills > 0)
    self.skillGrid.empty:SetText(s.kind == "player" and "No buffs recorded (Minor/Major buffs and debuffs are not listed)."
        or "No skill bars captured and no skills seen yet.")

    local gear = PDI.Import:GearRows(snap)
    self.gearGrid:SetData(gear)
    self.gearGrid:Layout(COLUMNS.gearpane, nil)
    self.gearGrid:Render()
    self.gearGrid.empty:SetHidden(#gear > 0)
    self.gearGrid.empty:SetText((s.kind == "build" or (s.kind == "player" and PDI.Group.current[s.who]))
        and "No gear captured yet. It's recorded from the encounter log during a fight while grouped."
        or "No gear captured for this player (the game only logs gear of you and your group).")

    self:UpdatePaneMore()
end

function UI:Refresh()
    if not self.win then return end
    self:UpdateToolbar()
    local rows = self:BuildRows()
    sortRows(rows, self.sort[self.tab], COLUMNS[self.tab])
    local k, a = 0, 0
    for _, r in ipairs(rows) do k = k + (r.k or 0); a = a + (r.a or 0) end
    local nPlayers = #rows
    -- My Kills: a Total row pinned above the players (sums what's listed: period, faction, search)
    if self.tab == "my" and nPlayers > 0 then
        for i, r in ipairs(rows) do r.rankNo = i end
        table.insert(rows, 1, { isTotal = true, rankText = "", who = "Total", c = string.format("%d players", nPlayers),
                                al = 0, k = k, a = a, tot = k + a, key = "k:__total" })
    end
    self.list:SetData(rows)
    self.list:Layout(COLUMNS[self.tab], self.sort[self.tab])
    self.list:Render(self.sel and self.sel.key or false)

    local total = nPlayers
    local footer
    if total == 0 then
        footer = self:EmptyText()
    else
        local shift = (#rows > nPlayers) and 1 or 0   -- the Total row isn't a player
        footer = string.format("%d-%d of %d  |  mouse wheel or drag the scrollbar",
            math.max(1, self.list.offset + 1 - shift), math.min(self.list.offset + NUM_ROWS - shift, total), total)
        if self.tab == "my" or self.tab == "feed" then
            footer = footer .. string.format("  |  kills: %s", PDI.Num(k))
            if self.tab == "my" then footer = footer .. string.format("  assists: %s", PDI.Num(a)) end
        end
    end
    self.footer:SetText(footer)
    self:RefreshPane()
end

---------------------------------------------------------------------------
-- Build link window: opened by clicking a [LPI build: @Name] link in chat
---------------------------------------------------------------------------
local LW_W, LW_ROWS = 1150, 16

function UI:CreateLinkWindow()
    if self.lw then return self.lw end
    local w = WM:CreateTopLevelWindow("PVPDataInsightLinkWindow")
    local half = math.floor((LW_W - 2 * PAD - 16) / 2)
    local gridY = 150
    local h = gridY + PANE_ROW_H * (LW_ROWS + 1) + 30
    w:SetDimensions(LW_W, h)
    w:SetAnchor(CENTER, GuiRoot, CENTER, 0, -40)
    w:SetMouseEnabled(true)
    w:SetMovable(true)
    w:SetClampedToScreen(true)
    w:SetHidden(true)
    local bg = WM:CreateControlFromVirtual("PVPDataInsightLinkWindowBG", w, "ZO_DefaultBackdrop")
    bg:SetAnchorFill(w)
    local title = Label("PVPDataInsightLinkWindowTitle", w, "ZoFontWinH3", NORMAL)
    title:SetAnchor(TOPLEFT, w, TOPLEFT, PAD, 10)
    title:SetDimensions(LW_W - 2 * PAD - 40, 34)
    local close = WM:CreateControlFromVirtual("PVPDataInsightLinkWindowClose", w, "ZO_CloseButton")
    close:SetAnchor(TOPRIGHT, w, TOPRIGHT, -10, 14)
    close:SetHandler("OnClicked", function() w:SetHidden(true) end)
    local info = Label("PVPDataInsightLinkWindowInfo", w, PANE_FONT, WHITE)
    info:SetAnchor(TOPLEFT, w, TOPLEFT, PAD, 48)
    info:SetDimensions(LW_W - 2 * PAD, gridY - 48 - 34)
    info:SetVerticalAlignment(TEXT_ALIGN_TOP)
    info:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
    local function section(name, x, text)
        local l = Label("PVPDataInsightLink" .. name .. "Title", w, "ZoFontWinH4", NORMAL)
        l:SetAnchor(TOPLEFT, w, TOPLEFT, x, gridY - 32)
        l:SetDimensions(half, 30)
        l:SetText(text)
    end
    local function grid(name, x)
        local g
        g = Grid.New("PVPDataInsightLink" .. name, w, half, LW_ROWS, function() end,
            function(d) g:Scroll(d) end, PANE_ROW_H, PANE_FONT, "ZoFontGameLargeBold")
        g.box:SetAnchor(TOPLEFT, w, TOPLEFT, x, gridY)
        g.empty = Label("PVPDataInsightLink" .. name .. "Empty", w, PANE_FONT, GREY)
        g.empty:SetAnchor(TOPLEFT, w, TOPLEFT, x + 6, gridY + PANE_ROW_H + 10)
        g.empty:SetDimensions(half - 12, 60)
        g.empty:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        return g
    end
    section("Skills", PAD, "Skills & Buffs")
    section("Gear", PAD + half + 16, "Gear & Sets")
    self.lw = { win = w, title = title, info = info, skills = grid("Skills", PAD), gear = grid("Gear", PAD + half + 16) }
    return self.lw
end

-- b = decoded link: who, cls, race, cp, role, mundus {ids}, bar1, bar2, skills {ids}, buffs {{id, perm}}, gear
function UI:ShowLinked(b)
    local lw = self:CreateLinkWindow()
    lw.title:SetText(string.format("%s  |c999999build link|r", b.who or "?"))
    local mundus = {}
    for _, id in ipairs(b.mundus or {}) do
        local n = PDI.MUNDUS_IDS and PDI.MUNDUS_IDS[id]
        if n then mundus[#mundus + 1] = n end
    end
    local race = PDI.Import.RaceText and PDI.Import.RaceText(b.race) or nil
    lw.info:SetText(table.concat({
        string.format("%s %s", race or "", PDI.ClassText(b.cls)),
        string.format("CP |cFFFFFF%s|r   Role: |cFFFFFF%s|r", (b.cp or 0) > 0 and PDI.Num(b.cp) or "-", PDI.RoleText(b.role)),
        string.format("Mundus: |cFFFFFF%s|r", #mundus > 0 and table.concat(mundus, ", ") or "-"),
        b.from and ("|c66CCFFLinked by " .. b.from .. "|r") or "|c66CCFFLinked in chat|r",
    }, "\n"))

    local snap = { v = { bar1 = b.bar1 or {}, bar2 = b.bar2 or {}, gear = b.gear or {}, effects = b.mundus }, names = {} }
    local rows = {}
    for _, r in ipairs(PDI.Import:BarRows(snap)) do
        local bar = r.sec:find("Front") and "|c66CCFFFront|r" or "|cCC99FFBack|r"
        rows[#rows + 1] = { n = r.n, info = bar .. "  " .. r.info, tooltipId = r.tooltipId }
    end
    local list = {}
    for _, id in ipairs(b.skills or {}) do
        local n = GetAbilityName(id)
        if n and n ~= "" then
            n = zo_strformat("<<1>>", n)
            local cat = PDI.Skills:Classify({ n = n, id = id, ty = { dmg = true } })
            if cat ~= "hidden" then
                list[#list + 1] = { n = n, cat = cat, info = PDI.Skills.LABEL[cat] or cat, tooltipId = id }
            end
        end
    end
    for _, bf in ipairs(b.buffs or {}) do
        local n = GetAbilityName(bf.id)
        if n and n ~= "" then
            local cat, shown = PDI.Skills:ClassifyBuff(zo_strformat("<<1>>", n), bf.id, bf.perm, b.cls)
            if cat ~= "hidden" then
                list[#list + 1] = { n = shown, cat = cat, info = PDI.Skills:BuffLabel(cat), tooltipId = bf.id }
            end
        end
    end
    table.sort(list, function(a, c)
        local oa, ob = PDI.Skills.ORDER[a.cat] or 50, PDI.Skills.ORDER[c.cat] or 50
        if oa ~= ob then return oa < ob end
        return a.n < c.n
    end)
    if #rows > 0 and #list > 0 then rows[#rows + 1] = { n = "", info = "" } end
    for _, r in ipairs(list) do rows[#rows + 1] = r end
    lw.skills.offset = 0
    lw.skills:SetData(rows)
    lw.skills:Layout(COLUMNS.skillpane, nil)
    lw.skills:Render()
    lw.skills.empty:SetHidden(#rows > 0)
    lw.skills.empty:SetText("No skills in this link.")

    local gear = PDI.Import:GearRows(snap)
    lw.gear.offset = 0
    lw.gear:SetData(gear)
    lw.gear:Layout(COLUMNS.gearpane, nil)
    lw.gear:Render()
    lw.gear.empty:SetHidden(#gear > 0)
    lw.gear.empty:SetText("No gear in this link.")

    lw.win:SetHidden(false)
    lw.win:BringWindowToTop()
end

---------------------------------------------------------------------------
-- Real Death Recap window: the 5 biggest damage sources of the fight you died in, and the last 10 hits
---------------------------------------------------------------------------
COLUMNS.recapTop = {
    { t = "Skill",   w = 300, key = "n",   nosort = true },
    { t = "Player",  w = 330, key = "who", nosort = true },
    { t = "Damage",  w = 120, key = "v",   nosort = true, fmt = num("v"), align = R },
    { t = "Hits",    w = 60,  key = "hits", nosort = true, align = R },
    { t = "Share",   w = 80,  key = "pct", nosort = true, align = R },
}
COLUMNS.recapLog = {
    { t = "Time",    w = 80,  key = "tm",  nosort = true },
    { t = "Player",  w = 330, key = "who", nosort = true },
    { t = "Skill",   w = 280, key = "n",   nosort = true },
    { t = "Damage",  w = 200, key = "dmg", nosort = true, align = R },
}
local RW_W = 940

function UI:CreateRecapWindow()
    if self.rw then return self.rw end
    local w = WM:CreateTopLevelWindow("PVPDataInsightRecapWindow")
    local topY = 112
    local logY = topY + PANE_ROW_H * 6 + 52
    local h = logY + PANE_ROW_H * 11 + 24
    w:SetDimensions(RW_W, h)
    w:SetAnchor(CENTER, GuiRoot, CENTER, 0, -60)
    w:SetMouseEnabled(true)
    w:SetMovable(true)
    w:SetClampedToScreen(true)
    w:SetHidden(true)
    local bg = WM:CreateControlFromVirtual("PVPDataInsightRecapWindowBG", w, "ZO_DefaultBackdrop")
    bg:SetAnchorFill(w)
    local title = Label("PVPDataInsightRecapWindowTitle", w, "ZoFontWinH3", NORMAL)
    title:SetAnchor(TOPLEFT, w, TOPLEFT, PAD, 10)
    title:SetDimensions(RW_W - 2 * PAD - 40, 34)
    title:SetText("Real Death Recap")
    local function hide()
        if SCENE_MANAGER and SCENE_MANAGER.HideTopLevel then pcall(SCENE_MANAGER.HideTopLevel, SCENE_MANAGER, w) end
        if not w:IsHidden() then w:SetHidden(true) end
    end
    local close = WM:CreateControlFromVirtual("PVPDataInsightRecapWindowClose", w, "ZO_CloseButton")
    close:SetDimensions(40, 40)
    close:SetAnchor(TOPRIGHT, w, TOPRIGHT, -10, 8)
    close:SetHandler("OnClicked", hide)
    local closeBtn = Button("PVPDataInsightRecapWindowCloseBtn", w, "Close", 110, hide)
    closeBtn:SetAnchor(RIGHT, close, LEFT, -12, 0)
    -- Esc closes it (a registered top-level window), and so does pressing Alt
    if SCENE_MANAGER and SCENE_MANAGER.RegisterTopLevel then pcall(SCENE_MANAGER.RegisterTopLevel, SCENE_MANAGER, w, false) end
    local altWasDown = true
    w:SetHandler("OnUpdate", function()
        local down = IsAltKeyDown and IsAltKeyDown() or false
        if down and not altWasDown then hide() end
        altWasDown = down
    end)
    w:SetHandler("OnShow", function() altWasDown = IsAltKeyDown and IsAltKeyDown() or false end)
    local info = Label("PVPDataInsightRecapWindowInfo", w, PANE_FONT, WHITE)
    info:SetAnchor(TOPLEFT, w, TOPLEFT, PAD, 46)
    info:SetDimensions(RW_W - 2 * PAD, 30)
    local function section(name, y, text)
        local l = Label("PVPDataInsightRecap" .. name .. "Title", w, "ZoFontWinH4", NORMAL)
        l:SetAnchor(TOPLEFT, w, TOPLEFT, PAD, y - 32)
        l:SetDimensions(RW_W - 2 * PAD, 30)
        l:SetText(text)
    end
    local function grid(name, y, rows)
        local g
        g = Grid.New("PVPDataInsightRecap" .. name, w, RW_W - 2 * PAD, rows, function() end,
            function(d) g:Scroll(d) end, PANE_ROW_H, PANE_FONT, "ZoFontGameLargeBold")
        g.box:SetAnchor(TOPLEFT, w, TOPLEFT, PAD, y)
        return g
    end
    section("Top", topY, "Top damage sources in the fight")
    section("Log", logY, "Last hits before death")
    self.rw = { win = w, info = info, top = grid("Top", topY, 5), log = grid("Log", logY, 10) }
    return self.rw
end

function UI:ShowRecap(r)
    if not r then return end
    local rw = self:CreateRecapWindow()
    rw.info:SetText(string.format("%s   Damage taken: |cFFFFFF%s|r in %d hits over %.0fs%s",
        PDI.FormatTime(r.t), PDI.Num(r.total or 0), r.hits or 0, r.secs or 0,
        r.killer and ("   Killed by " .. r.killer) or ""))
    if (r.absorbed or 0) > 0 then
        rw.info:SetText(rw.info:GetText() .. string.format("   |c66CCFF(%s of it absorbed by shields)|r", PDI.Num(r.absorbed)))
    end
    local top = {}
    for _, e in ipairs(r.top or {}) do
        top[#top + 1] = { n = e.skill, who = e.who, v = e.v, hits = tostring(e.n), pct = e.pct .. "%", tooltipId = e.id }
    end
    rw.top.offset = 0
    rw.top:SetData(top)
    rw.top:Layout(COLUMNS.recapTop, nil)
    rw.top:Render()
    local log = {}
    for _, e in ipairs(r.last or {}) do
        log[#log + 1] = { tm = e.tm, who = e.who, n = e.skill, dmg = PDI.Num(e.v) .. (e.note or ""), tooltipId = e.id }
    end
    rw.log.offset = 0
    rw.log:SetData(log)
    rw.log:Layout(COLUMNS.recapLog, nil)
    rw.log:Render()
    if SCENE_MANAGER and SCENE_MANAGER.ShowTopLevel then pcall(SCENE_MANAGER.ShowTopLevel, SCENE_MANAGER, rw.win) end
    if rw.win:IsHidden() then rw.win:SetHidden(false) end
    rw.win:BringWindowToTop()
end
