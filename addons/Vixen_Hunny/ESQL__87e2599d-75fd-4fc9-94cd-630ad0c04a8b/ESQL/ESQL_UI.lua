-- ESQL window: query box, buttons and a scrollable results grid (built in Lua, no XML).
-- Uses explicit font strings and plain textures (no keyboard-only templates), so it
-- renders the same in the keyboard UI, the gamepad UI and on console.
-- Text size: /esql size <0.6-2.5>, the A- / A+ buttons, or the settings panel slider.

local E = ESQL
local UI = {}
E.UI = UI

local SQL = E.SQL
local format, floor = string.format, math.floor

local MAX_COL_SLOTS = 24

UI.result = nil
UI.rowOffset = 0
UI.colOffset = 0
UI.sortCol, UI.sortDesc = nil, false
UI.historyPos = nil
UI.generation = 0

local EXAMPLES = {
    "SHOW TABLES",
    "SELECT * FROM abilities WHERE name LIKE '%flame%' LIMIT 100",
    "SELECT id, name, duration_ms, cost, cost_mechanic, target FROM abilities WHERE id = 46340",
    "SELECT line_name, morph, name, ability_id FROM skills WHERE skill_type = 'class' ORDER BY line_name, skill_index, morph",
    "SELECT unit, name, ability_id, stacks, remaining_s, effect_type FROM effects ORDER BY unit, remaining_s",
    "SELECT name, set_type, max_equipped, bonuses FROM sets WHERE name LIKE '%mother%'",
    "SELECT s.name, b.num_required, b.description FROM sets s JOIN set_bonuses b ON b.set_id = s.id WHERE b.description LIKE '%critical%'",
    "SELECT set_type, COUNT(*) AS n FROM sets GROUP BY set_type ORDER BY n DESC",
    "SELECT name, count, quality, trait, set_name FROM inventory WHERE bag = 'backpack' ORDER BY quality DESC, name",
    "SELECT name, discipline, skill_type, max_points FROM champion_skills WHERE slottable ORDER BY discipline, name",
    "SELECT category_type, COUNT(*) AS total, SUM(unlocked) AS owned FROM collectibles GROUP BY category_type ORDER BY total DESC",
    "SELECT category, COUNT(*) AS n, SUM(completed) AS done, SUM(points) AS points FROM achievements GROUP BY category",
    "SELECT name, slot, description FROM scribing_scripts ORDER BY slot, name",
    "SELECT ability, result, COUNT(*) AS hits, SUM(hit) AS total FROM combat_log WHERE source_type = 'player' GROUP BY ability, result ORDER BY total DESC",
    "SELECT name, value FROM constants WHERE family = 'ACTION_RESULT' ORDER BY value",
    "SELECT name, zone, type FROM pois WHERE type = 'group_dungeon' ORDER BY zone",
    "SELECT stat, value, base FROM stats ORDER BY stat",
}
UI.EXAMPLES = EXAMPLES
UI.exampleIndex = 0

---------------------------------------------------------------------------
-- Sizes (all scaled by the text size setting)
---------------------------------------------------------------------------
local S = {}

local function computeSizes()
    local k = E.sv and E.sv.uiScale or 1
    local function px(n) return floor(n * k + 0.5) end
    S.k = k
    S.cellFont = px(18)
    S.headFont = px(19)
    S.titleFont = px(24)
    S.statusFont = px(17)
    S.buttonFont = px(18)
    S.editFont = px(20)
    S.rowH = px(28)
    S.headerH = px(32)
    S.buttonH = px(34)
    S.editH = px(38)
    S.pad = px(12)
    S.charW = S.cellFont * 0.55
    S.minColW = px(50)
    S.maxColW = px(520)
end

local function font(size, bold)
    return format("%s|%d|soft-shadow-thin", bold and "$(BOLD_FONT)" or "$(MEDIUM_FONT)", size)
end

---------------------------------------------------------------------------
-- Formatting
---------------------------------------------------------------------------
local function isTexture(s)
    return type(s) == "string" and s:sub(-4):lower() == ".dds" and not s:find(" ", 1, true)
end

function UI.CellText(v)
    if v == nil then return "|c777777NULL|r" end
    if v == true then return "|c7FD67Ftrue|r" end
    if v == false then return "|cC07070false|r" end
    if type(v) == "number" then
        if v ~= floor(v) then return (format("%.3f", v):gsub("0+$", ""):gsub("%.$", "")) end
        return SQL.ToText(v)
    end
    if isTexture(v) then
        local n = S.rowH - 4
        return format("|t%d:%d:%s|t", n, n, v)
    end
    return (tostring(v):gsub("[\r\n]+", " "))
end

local function plainLength(s)
    if type(s) ~= "string" then return #tostring(s) end
    if isTexture(s) then return 3 end
    return #E.StripMarkup(s)
end

local function columnWidths(res)
    local widths = {}
    local sample = math.min(#res.rows, 300)
    for c, name in ipairs(res.columns) do
        local w = #tostring(name) + 2
        for r = 1, sample do
            local v = res.rows[r][c]
            if v ~= nil then
                local l = plainLength(type(v) == "number" and SQL.ToText(v) or v)
                if l > w then w = l end
            end
        end
        widths[c] = math.max(S.minColW, math.min(S.maxColW, floor(w * S.charW + 20)))
    end
    return widths
end

---------------------------------------------------------------------------
-- Control helpers
---------------------------------------------------------------------------
local WM

local function N(name) return "ESQL" .. UI.generation .. "_" .. name end

local function solid(parent, name, r, g, b, a)
    local t = WM:CreateControl(N(name), parent, CT_TEXTURE)
    t:SetColor(r, g, b, a)
    return t
end

local function label(parent, name, size, bold, text)
    local l = WM:CreateControl(N(name), parent, CT_LABEL)
    l:SetFont(font(size, bold))
    l:SetColor(0.92, 0.92, 0.92, 1)
    if text then l:SetText(text) end
    return l
end

-- simple button: coloured box + label, works without keyboard templates
local function button(parent, name, text, width, onClick)
    local b = WM:CreateControl(N(name), parent, CT_CONTROL)
    b:SetDimensions(width, S.buttonH)
    b:SetMouseEnabled(true)
    local bg = solid(b, name .. "BG", 0.16, 0.3, 0.4, 0.95)
    bg:SetAnchorFill(b)
    local l = label(b, name .. "Text", S.buttonFont, true, text)
    l:SetAnchor(CENTER, b, CENTER, 0, 0)
    l:SetColor(0.95, 0.95, 0.95, 1)
    b:SetHandler("OnMouseEnter", function() bg:SetColor(0.25, 0.48, 0.62, 1) end)
    b:SetHandler("OnMouseExit", function() bg:SetColor(0.16, 0.3, 0.4, 0.95) end)
    b:SetHandler("OnMouseUp", function(_, btn, upInside)
        if upInside then
            if PlaySound and SOUNDS then PlaySound(SOUNDS.DEFAULT_CLICK) end
            onClick()
        end
    end)
    return b
end

local function defaultWindowSize()
    local rw = GuiRoot:GetWidth()
    local rh = GuiRoot:GetHeight()
    return floor(math.min(rw * 0.85, 1800)), floor(math.min(rh * 0.78, 1200))
end

---------------------------------------------------------------------------
-- Window construction
---------------------------------------------------------------------------
function UI.Create()
    if UI.win then return UI.win end
    WM = WINDOW_MANAGER
    computeSizes()
    local pad = S.pad

    local win = WM:CreateTopLevelWindow(N("Window"))
    UI.win = win
    local sv = E.sv.window
    if sv and sv.v ~= 2 then sv = nil end
    local dw, dh = defaultWindowSize()
    win:SetDimensions(sv and sv.w or dw, sv and sv.h or dh)
    win:ClearAnchors()
    if sv and sv.x then win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.x, sv.y) else win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0) end
    win:SetMovable(true)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetResizeHandleSize(10)
    win:SetDimensionConstraints(500, 320, 4000, 3000)
    win:SetHidden(true)
    win:SetDrawTier(DT_HIGH)
    win:SetHandler("OnMoveStop", function() UI.SavePosition() end)
    win:SetHandler("OnResizeStop", function() UI.SavePosition(); UI.widths = nil; UI.Layout() end)

    local bg = solid(win, "BG", 0.04, 0.05, 0.07, 0.94)
    bg:SetAnchorFill(win)
    local accent = solid(win, "Accent", 0.31, 0.76, 0.97, 1)
    accent:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 0)
    accent:SetAnchor(TOPRIGHT, win, TOPRIGHT, 0, 0)
    accent:SetHeight(3)

    local title = label(win, "Title", S.titleFont, true, "|c4FC3F7ESQL|r  SQL for ESO game data")
    title:SetAnchor(TOPLEFT, win, TOPLEFT, pad, pad * 0.6)

    local close = button(win, "Close", "X", S.buttonH, function() UI.Hide() end)
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -pad * 0.6, pad * 0.6)
    local bigger = button(win, "Bigger", "A+", S.buttonH * 1.4, function() UI.SetScale((E.sv.uiScale or 1) + 0.1) end)
    bigger:SetAnchor(RIGHT, close, LEFT, -6, 0)
    local smaller = button(win, "Smaller", "A-", S.buttonH * 1.4, function() UI.SetScale((E.sv.uiScale or 1) - 0.1) end)
    smaller:SetAnchor(RIGHT, bigger, LEFT, -6, 0)

    local top = pad * 0.6 + S.buttonH + pad * 0.6
    do
        local editBg = solid(win, "QueryBG", 0, 0, 0, 0.85)
        editBg:SetAnchor(TOPLEFT, win, TOPLEFT, pad, top)
        editBg:SetAnchor(TOPRIGHT, win, TOPRIGHT, -pad, top)
        editBg:SetHeight(S.editH)
        editBg:SetMouseEnabled(true)

        local edit = WM:CreateControl(N("Query"), win, CT_EDITBOX)
        UI.edit = edit
        edit:SetAnchor(TOPLEFT, editBg, TOPLEFT, 8, 0)
        edit:SetAnchor(BOTTOMRIGHT, editBg, BOTTOMRIGHT, -8, 0)
        edit:SetFont(font(S.editFont, false))
        edit:SetColor(1, 1, 1, 1)
        edit:SetMaxInputChars(3000)
        edit:SetMouseEnabled(true)
        if edit.SetVirtualKeyboardType then edit:SetVirtualKeyboardType(VIRTUAL_KEYBOARD_TYPE_DEFAULT or 0) end
        edit:SetDefaultText("Type SQL here, then press Enter")
        edit:SetText(E.sv.lastQuery or "SHOW TABLES")
        edit:SetHandler("OnEnter", function() UI.Run() end)
        edit:SetHandler("OnEscape", function(self) self:LoseFocus() end)
        edit:SetHandler("OnUpArrow", function() UI.History(1) end)
        edit:SetHandler("OnDownArrow", function() UI.History(-1) end)
        edit:SetDrawLevel(3)

        -- Click anywhere on the box to type. The game's own click-to-focus
        -- doesn't fire for edit boxes made in Lua in every UI mode, so an
        -- invisible catcher on top focuses it; it steps aside while you type,
        -- so later clicks can still move the cursor inside the text.
        local catcher = WM:CreateControl(N("QueryClick"), win, CT_CONTROL)
        catcher:SetAnchorFill(editBg)
        catcher:SetMouseEnabled(true)
        catcher:SetDrawLevel(4)
        local function focus()
            catcher:SetHidden(true)
            edit:TakeFocus()
            if PlaySound and SOUNDS then PlaySound(SOUNDS.DEFAULT_CLICK) end
        end
        catcher:SetHandler("OnMouseDown", focus)
        editBg:SetHandler("OnMouseDown", focus)
        edit:SetHandler("OnMouseDown", function(self) if not self:HasFocus() then focus() end end)
        edit:SetHandler("OnFocusGained", function()
            catcher:SetHidden(true)
            editBg:SetColor(0.05, 0.12, 0.18, 0.95)
        end)
        edit:SetHandler("OnFocusLost", function()
            catcher:SetHidden(false)
            editBg:SetColor(0, 0, 0, 0.85)
        end)
        UI.editCatcher = catcher
        top = top + S.editH + 8

        local x = pad
        local function addButton(name, text, fn)
            local w = floor(#text * S.buttonFont * 0.6 + S.buttonFont * 1.6)
            local b = button(win, "Btn" .. name, text, w, fn)
            b:SetAnchor(TOPLEFT, win, TOPLEFT, x, top)
            x = x + w + 6
            return b
        end
        addButton("Edit", "Edit SQL", function() UI.EditQuery() end)
        addButton("Run", "Run", function() UI.Run() end)
        addButton("Stop", "Stop", function() UI.Stop() end)
        addButton("Tables", "Tables", function() UI.RunText("SHOW TABLES") end)
        addButton("Example", "Example", function() UI.NextExample() end)
        addButton("Help", "Help", function() UI.RunText("HELP") end)
        addButton("Copy", "Copy", function() UI.ShowExport() end)
        addButton("ColL", "<", function() UI.ScrollCols(-1) end)
        addButton("ColR", ">", function() UI.ScrollCols(1) end)
        top = top + S.buttonH + 8
    end

    local status = label(win, "Status", S.statusFont, false, "")
    status:SetAnchor(TOPLEFT, win, TOPLEFT, pad, top)
    status:SetAnchor(TOPRIGHT, win, TOPRIGHT, -pad, top)
    status:SetColor(0.78, 0.84, 0.9, 1)
    status:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    status:SetHeight(S.statusFont + 8)
    UI.status = status
    top = top + S.statusFont + 12

    local grid = WM:CreateControl(N("Grid"), win, CT_CONTROL)
    UI.grid = grid
    grid:SetAnchor(TOPLEFT, win, TOPLEFT, pad * 0.8, top)
    grid:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -pad * 0.8, -pad * 0.8)
    grid:SetMouseEnabled(true)
    grid:SetHandler("OnMouseWheel", function(_, delta, ctrl, alt, shift)
        if shift then UI.ScrollCols(delta > 0 and -1 or 1) else UI.ScrollRows(delta > 0 and -3 or 3) end
    end)
    UI.gridTop = top

    local gridBg = solid(grid, "GridBG", 0.1, 0.11, 0.14, 0.9)
    gridBg:SetAnchorFill(grid)
    local headBg = solid(grid, "HeadBG", 0.12, 0.2, 0.27, 1)
    headBg:SetAnchor(TOPLEFT, grid, TOPLEFT, 0, 0)
    headBg:SetAnchor(TOPRIGHT, grid, TOPRIGHT, 0, 0)
    headBg:SetHeight(S.headerH)

    UI.headers, UI.rows = {}, {}
    for c = 1, MAX_COL_SLOTS do
        local h = label(grid, "Head" .. c, S.headFont, true)
        h:SetColor(0.45, 0.82, 1, 1)
        h:SetHeight(S.headerH)
        h:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        h:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        h:SetMouseEnabled(true)
        h:SetHandler("OnMouseUp", function(self, btn, upInside) if upInside then UI.SortBy(self.colIndex) end end)
        h:SetHidden(true)
        UI.headers[c] = h
    end
    UI.Layout()
    return win
end

local function makeRow(i)
    local grid = UI.grid
    local y = S.headerH + (i - 1) * S.rowH
    local row = WM:CreateControl(N("Row" .. i), grid, CT_CONTROL)
    row:SetHeight(S.rowH)
    row:SetAnchor(TOPLEFT, grid, TOPLEFT, 0, y)
    row:SetAnchor(TOPRIGHT, grid, TOPRIGHT, 0, y)
    local stripe = solid(row, "Row" .. i .. "BG", 1, 1, 1, i % 2 == 0 and 0.05 or 0)
    stripe:SetAnchorFill(row)
    row.cells = {}
    for c = 1, MAX_COL_SLOTS do
        local cell = label(row, "Row" .. i .. "C" .. c, S.cellFont, false)
        cell:SetHeight(S.rowH)
        cell:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        cell:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        cell:SetMouseEnabled(not E.isConsole)
        cell:SetHandler("OnMouseEnter", function(self) UI.ShowCellTooltip(self) end)
        cell:SetHandler("OnMouseExit", function() UI.HideCellTooltip() end)
        cell:SetHandler("OnMouseUp", function(self, btn, upInside) if upInside then UI.PrintRow(self.rowIndex) end end)
        cell:SetHandler("OnMouseWheel", function(_, delta, ctrl, alt, shift)
            if shift then UI.ScrollCols(delta > 0 and -1 or 1) else UI.ScrollRows(delta > 0 and -3 or 3) end
        end)
        cell:SetHidden(true)
        row.cells[c] = cell
    end
    return row
end

function UI.Layout()
    if not UI.grid then return end
    local h = UI.grid:GetHeight()
    if h <= 0 then h = UI.win:GetHeight() - UI.gridTop - S.pad end
    local n = math.max(1, floor((h - S.headerH) / S.rowH))
    UI.visibleRows = n
    for i = 1, n do
        if not UI.rows[i] then UI.rows[i] = makeRow(i) end
    end
    UI.Render()
end

function UI.SavePosition()
    local win = UI.win
    E.sv.window = { v = 2, x = win:GetLeft(), y = win:GetTop(), w = win:GetWidth(), h = win:GetHeight() }
end

-- Change text size: rebuilds the window (old controls are hidden and left unused).
function UI.SetScale(k)
    k = math.max(0.6, math.min(2.5, floor((tonumber(k) or 1) * 10 + 0.5) / 10))
    E.sv.uiScale = k
    local wasShown = UI.win and not UI.win:IsHidden()
    local text = UI.edit and UI.edit:GetText()
    if UI.win then
        UI.win:SetHidden(true)
        if UI.exportWin then UI.exportWin:SetHidden(true) end
        UI.win, UI.edit, UI.grid, UI.status, UI.exportWin, UI.exportEdit = nil, nil, nil, nil, nil, nil
        UI.generation = UI.generation + 1
    end
    UI.widths = nil
    if wasShown then
        UI.Show()
        if text and UI.edit then UI.edit:SetText(text) end
    end
    E.Print("Text size %.1f", k)
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------
function UI.Render()
    if not UI.grid then return end
    local res = UI.result
    local headers, rows = UI.headers, UI.rows
    for c = 1, MAX_COL_SLOTS do headers[c]:SetHidden(true) end
    for i = 1, #rows do rows[i]:SetHidden(true) end
    if not res then UI.UpdateStatus(); return end

    local widths = UI.widths or columnWidths(res)
    UI.widths = widths
    local gridW = UI.grid:GetWidth()
    if gridW <= 0 then gridW = UI.win:GetWidth() - 2 * S.pad end
    local ncols = #res.columns
    UI.colOffset = math.max(0, math.min(UI.colOffset, ncols - 1))

    local slots, x = {}, 8
    for c = UI.colOffset + 1, ncols do
        if #slots >= MAX_COL_SLOTS then break end
        local w = widths[c]
        if x + w > gridW and #slots > 0 then break end
        w = math.min(w, gridW - x - 4)
        slots[#slots + 1] = { col = c, x = x, w = w }
        x = x + w + 10
    end
    UI.lastVisibleCol = slots[#slots] and slots[#slots].col or 0

    for s, slot in ipairs(slots) do
        local h = headers[s]
        h:ClearAnchors()
        h:SetAnchor(TOPLEFT, UI.grid, TOPLEFT, slot.x, 0)
        h:SetWidth(slot.w)
        local name = tostring(res.columns[slot.col])
        if UI.sortCol == slot.col then name = name .. (UI.sortDesc and " v" or " ^") end
        h:SetText(name)
        h.colIndex = slot.col
        h:SetHidden(false)
    end

    local total = #res.rows
    local nvis = UI.visibleRows or 10
    UI.rowOffset = math.max(0, math.min(UI.rowOffset, math.max(0, total - nvis)))
    for i = 1, math.min(nvis, #rows) do
        local r = UI.rowOffset + i
        local rowCtl = rows[i]
        local data = res.rows[r]
        if data then
            rowCtl:SetHidden(false)
            for s = 1, MAX_COL_SLOTS do
                local cell = rowCtl.cells[s]
                local slot = slots[s]
                if slot then
                    cell:ClearAnchors()
                    cell:SetAnchor(TOPLEFT, rowCtl, TOPLEFT, slot.x, 0)
                    cell:SetWidth(slot.w)
                    cell:SetText(UI.CellText(data[slot.col]))
                    cell.rowIndex, cell.colIndex = r, slot.col
                    cell:SetHidden(false)
                else
                    cell:SetHidden(true)
                end
            end
        end
    end
    UI.UpdateStatus()
end

function UI.UpdateStatus(extra)
    if not UI.status then return end
    local res = UI.result
    local text = extra or UI.statusText or ""
    if res and not extra and not UI.statusText then
        local total = #res.rows
        local first = total > 0 and UI.rowOffset + 1 or 0
        local last = math.min(total, UI.rowOffset + (UI.visibleRows or 10))
        text = format("%d row%s%s  |  showing %d-%d  |  columns %d-%d of %d  |  %d ms%s",
            total, total == 1 and "" or "s", res.truncated and " (capped, add LIMIT/OFFSET)" or "",
            first, last, UI.colOffset + 1, UI.lastVisibleCol or 0, #res.columns, res.elapsedMs or 0,
            res.message and ("  |  " .. res.message) or "")
        if not E.isConsole then text = text .. "  |  wheel scrolls, shift+wheel: columns, click a row: print it" end
    end
    UI.status:SetText(text)
end

function UI.SetStatus(text)
    UI.statusText = text
    if UI.status then UI.status:SetText(text) end
    if E.Console and E.Console.Refresh then E.Console.Refresh() end
end

function UI.ScrollRows(d)
    UI.rowOffset = UI.rowOffset + d
    UI.Render()
end

function UI.PageRows(d)
    UI.ScrollRows(d * math.max(1, (UI.visibleRows or 10) - 1))
end

function UI.ScrollCols(d)
    UI.colOffset = UI.colOffset + d
    UI.Render()
end

function UI.SortBy(col)
    local res = UI.result
    if not res or not col then return end
    if UI.sortCol == col then UI.sortDesc = not UI.sortDesc else UI.sortCol, UI.sortDesc = col, false end
    local desc = UI.sortDesc
    for i, r in ipairs(res.rows) do r.__i = i end
    table.sort(res.rows, function(a, b)
        local c = SQL.SortCompare(a[col], b[col])
        if c == 0 then return a.__i < b.__i end
        if desc then return c > 0 end
        return c < 0
    end)
    UI.Render()
end

---------------------------------------------------------------------------
-- Tooltips / row printing / export
---------------------------------------------------------------------------
-- Own tooltip: same font and scale as the window (the game's keyboard
-- tooltips are tiny in the gamepad UI and on console).
local function getTip()
    if UI.tip and UI.tipGeneration == UI.generation then return UI.tip end
    local tip = WM:CreateTopLevelWindow(N("Tip"))
    tip:SetDrawTier(DT_HIGH)
    tip:SetDrawLayer(DL_OVERLAY or 4)
    tip:SetClampedToScreen(true)
    tip:SetHidden(true)
    local bg = solid(tip, "TipBG", 0.02, 0.03, 0.05, 0.97)
    bg:SetAnchorFill(tip)
    local edge = solid(tip, "TipEdge", 0.31, 0.76, 0.97, 1)
    edge:SetAnchor(TOPLEFT, tip, TOPLEFT, 0, 0)
    edge:SetAnchor(TOPRIGHT, tip, TOPRIGHT, 0, 0)
    edge:SetHeight(2)
    local text = label(tip, "TipText", S.cellFont + 1, false)
    text:SetAnchor(TOPLEFT, tip, TOPLEFT, S.pad, S.pad * 0.7)
    tip.text = text
    UI.tip, UI.tipGeneration = tip, UI.generation
    return tip
end

function UI.ShowTip(anchorTo, body)
    local tip = getTip()
    local text = tip.text
    local maxW = floor(math.min(GuiRoot:GetWidth() * 0.45, 760 * S.k))
    text:SetDimensions(0, 0)
    text:SetDimensionConstraints(0, 0, maxW, 0)
    text:SetText(body)
    local w = math.min(maxW, text:GetTextWidth())
    text:SetWidth(w)
    local h = text:GetTextHeight()
    tip:SetDimensions(w + 2 * S.pad, h + 1.4 * S.pad)
    tip:ClearAnchors()
    tip:SetAnchor(BOTTOMLEFT, anchorTo, TOPLEFT, 0, -6)
    tip:SetHidden(false)
end

function UI.ShowCellTooltip(cell)
    local res = UI.result
    if not res or not cell.rowIndex then return end
    local v = res.rows[cell.rowIndex] and res.rows[cell.rowIndex][cell.colIndex]
    if v == nil then return end
    local col = tostring(res.columns[cell.colIndex])
    local body
    if isTexture(v) then
        local n = floor(64 * S.k)
        body = format("|t%d:%d:%s|t\n%s", n, n, v, v)
    else
        body = tostring(SQL.ToText(v))
    end
    UI.ShowTip(cell, format("|c4FC3F7%s|r\n%s", col, body))
end

function UI.HideCellTooltip()
    if UI.tip then UI.tip:SetHidden(true) end
end

function UI.PrintRow(r)
    local res = UI.result
    if not res or not res.rows[r] then return end
    E.Print("Row %d:", r)
    for c, name in ipairs(res.columns) do
        local v = res.rows[r][c]
        if v ~= nil then E.Print("  |c4FC3F7%s|r = %s", tostring(name), tostring(SQL.ToText(v))) end
    end
end

-- Results as tab-separated text (first `max` rows).
function UI.ResultText(res, max)
    local lines = { table.concat(res.columns, "\t") }
    for r = 1, math.min(#res.rows, max or #res.rows) do
        local parts = {}
        for c = 1, #res.columns do
            local v = res.rows[r][c]
            parts[c] = v == nil and "" or (tostring(SQL.ToText(v)):gsub("[\t\r\n]+", " "))
        end
        lines[#lines + 1] = table.concat(parts, "\t")
    end
    return table.concat(lines, "\n")
end

function UI.ShowExport()
    local res = UI.result
    if not res then E.Print("Run a query first."); return end
    if not UI.exportWin then
        local w = WM:CreateTopLevelWindow(N("Export"))
        local dw, dh = defaultWindowSize()
        w:SetDimensions(floor(dw * 0.8), floor(dh * 0.8))
        w:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        w:SetMovable(true); w:SetMouseEnabled(true); w:SetClampedToScreen(true)
        w:SetDrawTier(DT_HIGH)
        local bg = solid(w, "ExportBG", 0.03, 0.03, 0.05, 0.97)
        bg:SetAnchorFill(w)
        local t = label(w, "ExportTitle", S.headFont, true, "Results as tab-separated text (paste into a spreadsheet)")
        t:SetAnchor(TOPLEFT, w, TOPLEFT, S.pad, S.pad * 0.6)
        local c = button(w, "ExportClose", "Close", S.buttonFont * 5, function() w:SetHidden(true) end)
        c:SetAnchor(TOPRIGHT, w, TOPRIGHT, -S.pad * 0.6, S.pad * 0.6)

        local edit = WM:CreateControl(N("ExportEdit"), w, CT_EDITBOX)
        local copy = button(w, "ExportCopy", "Copy to clipboard", S.buttonFont * 11, function() UI.CopyExport() end)
        copy:SetAnchor(RIGHT, c, LEFT, -8, 0)
        local selectAll = button(w, "ExportSelect", "Select all", S.buttonFont * 7, function()
            edit:TakeFocus(); edit:SelectAll()
        end)
        selectAll:SetAnchor(RIGHT, copy, LEFT, -8, 0)

        local note = label(w, "ExportNote", S.statusFont, false, "")
        note:SetAnchor(TOPLEFT, w, TOPLEFT, S.pad, S.buttonH + S.pad * 1.2)
        note:SetColor(0.78, 0.84, 0.9, 1)
        UI.exportNote = note

        local box = solid(w, "ExportBox", 0, 0, 0, 0.6)
        box:SetAnchor(TOPLEFT, w, TOPLEFT, S.pad, S.buttonH + S.statusFont + S.pad * 2)
        box:SetAnchor(BOTTOMRIGHT, w, BOTTOMRIGHT, -S.pad, -S.pad)
        edit:SetAnchor(TOPLEFT, box, TOPLEFT, 6, 4)
        edit:SetAnchor(BOTTOMRIGHT, box, BOTTOMRIGHT, -6, -4)
        edit:SetFont(font(S.cellFont, false))
        edit:SetColor(1, 1, 1, 1)
        edit:SetMultiLine(true)
        edit:SetNewLineEnabled(true)
        edit:SetCopyEnabled(true)
        edit:SetMaxInputChars(UI.EXPORT_MAX_CHARS)
        edit:SetMouseEnabled(true)
        edit:SetDrawLevel(3)
        edit:SetHandler("OnEscape", function(self) self:LoseFocus(); w:SetHidden(true) end)
        -- same click-to-focus fix as the query box
        local catcher = WM:CreateControl(N("ExportClick"), w, CT_CONTROL)
        catcher:SetAnchorFill(box)
        catcher:SetMouseEnabled(true)
        catcher:SetDrawLevel(4)
        catcher:SetHandler("OnMouseDown", function() catcher:SetHidden(true); edit:TakeFocus() end)
        edit:SetHandler("OnFocusGained", function() catcher:SetHidden(true) end)
        edit:SetHandler("OnFocusLost", function() catcher:SetHidden(false) end)
        UI.exportWin, UI.exportEdit = w, edit
    end
    local maxRows = 2000
    local text = UI.ResultText(res, maxRows)
    local shown = math.min(#res.rows, maxRows)
    if #text > UI.EXPORT_MAX_CHARS then
        -- cut at a line end so no row is half copied
        local cut = text:sub(1, UI.EXPORT_MAX_CHARS)
        local lastNl = cut:match(".*()\n")
        text = lastNl and cut:sub(1, lastNl - 1) or cut
        local _, lines = text:gsub("\n", "")
        shown = lines
    end
    UI.exportText = text
    UI.exportNote:SetText(format("%d of %d row(s). Copy to clipboard copies everything; or click in the text and use Ctrl+A, Ctrl+C.%s",
        shown, #res.rows, shown < #res.rows and "  For more rows use Export (/esql export) or add LIMIT/OFFSET." or ""))
    UI.exportEdit:SetText(text)
    UI.exportWin:SetHidden(false)
    UI.exportEdit:TakeFocus()
    UI.exportEdit:SelectAll()
end

-- ESO edit boxes hold a limited amount of text; keep the export under it.
UI.EXPORT_MAX_CHARS = 60000

function UI.CopyExport()
    local edit = UI.exportEdit
    if not edit then return end
    if edit.CopyAllTextToClipboard then
        local ok = pcall(edit.CopyAllTextToClipboard, edit)
        if ok then
            E.Print("Copied %d characters to the clipboard.", #(UI.exportText or ""))
            return
        end
    end
    -- fallback: select it so Ctrl+C works
    edit:TakeFocus()
    edit:SelectAll()
    E.Print("Press Ctrl+C to copy the selected text.")
end

---------------------------------------------------------------------------
-- Running queries
---------------------------------------------------------------------------
function UI.ResultCap()
    return E.sv.maxRows or (E.isConsole and 2000 or 20000)
end

function UI.ShowResult(res)
    UI.result = res
    UI.rowOffset, UI.colOffset = 0, 0
    UI.sortCol, UI.sortDesc = nil, false
    UI.widths = nil
    UI.statusText = nil
    UI.Render()
    if E.Console and E.Console.Refresh then E.Console.Refresh() end
end

function UI.ShowError(msg)
    UI.ShowResult({ columns = { "error" }, rows = { { msg } }, elapsedMs = 0 })
    UI.SetStatus("|cFF6666Error:|r " .. msg)
    E.Print("|cFF6666%s|r", msg)
end

-- Run SQL text in the background and display it. onDone(ok, res) optional.
function UI.RunText(text, onDone)
    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return end
    UI.Show()
    if UI.edit and UI.edit:GetText() ~= text then UI.edit:SetText(text) end
    E.sv.lastQuery = text
    UI.AddHistory(text)
    if UI.running then E.CancelJobs(); E.ResetScanFlags() end
    UI.running = true
    UI.SetStatus("Running...")
    E.RunAsync(function()
        return SQL.Run(text, { maxRows = UI.ResultCap() })
    end, function(ok, res)
        UI.running = false
        if ok then
            UI.ShowResult(res)
            E.lastResult = res
            if E.isConsole then UI.PrintSummary(res) end
        else
            UI.ShowError(SQL.ErrorText(res))
        end
        if onDone then onDone(ok, res) end
    end, "query")
end

-- Focus the query box. Works without a mouse: on console / in the gamepad UI
-- this opens the on-screen keyboard; Enter (or confirming it) runs the query.
function UI.EditQuery()
    UI.Show()
    if not UI.edit then return end
    if E.Console and E.Console.query and E.Console.query ~= "" then UI.edit:SetText(E.Console.query) end
    UI.edit:TakeFocus()
end

function UI.Run()
    if not UI.edit then return end
    if E.Console then E.Console.query = UI.edit:GetText() end
    UI.edit:LoseFocus()
    UI.RunText(UI.edit:GetText())
end

function UI.Stop()
    if UI.running then
        E.CancelJobs()
        E.ResetScanFlags()
        UI.running = false
        UI.SetStatus("Stopped.")
    end
end

-- console: echo the first rows to chat, since the grid can't be scrolled with a mouse
function UI.PrintSummary(res, max)
    max = max or 8
    E.Print("%d row(s) in %d ms", #res.rows, res.elapsedMs or 0)
    for r = 1, math.min(max, #res.rows) do
        local parts = {}
        for c = 1, math.min(6, #res.columns) do
            local v = res.rows[r][c]
            if not isTexture(v) then parts[#parts + 1] = tostring(SQL.ToText(v) or "NULL") end
        end
        E.Print("  %s", table.concat(parts, " | "))
    end
end

function UI.AddHistory(text)
    local h = E.sv.history
    if h[1] ~= text then table.insert(h, 1, text) end
    while #h > 50 do table.remove(h) end
    UI.historyPos = nil
end

function UI.History(dir)
    local h = E.sv.history
    if #h == 0 or not UI.edit then return end
    local pos = (UI.historyPos or 0) + dir
    pos = math.max(1, math.min(#h, pos))
    UI.historyPos = pos
    UI.edit:SetText(h[pos])
end

function UI.NextExample()
    UI.exampleIndex = UI.exampleIndex % #EXAMPLES + 1
    if UI.edit then
        UI.edit:SetText(EXAMPLES[UI.exampleIndex])
        UI.edit:TakeFocus()
    end
    return EXAMPLES[UI.exampleIndex]
end

---------------------------------------------------------------------------
-- Show / hide
---------------------------------------------------------------------------
function UI.Show()
    UI.Create()
    UI.win:SetHidden(false)
    UI.Render()
    if not E.isConsole and SetGameCameraUIMode then SetGameCameraUIMode(true) end
end

function UI.Hide()
    if UI.win then UI.win:SetHidden(true) end
    UI.HideCellTooltip()
end

function UI.Toggle()
    if UI.win and not UI.win:IsHidden() then UI.Hide() else UI.Show() end
end

LibESQL.RegisterCallback("ScanProgress", function(tableName, frac, count)
    local msg
    if frac >= 1 then
        msg = format("Indexed %d %s ids.", count or 0, tableName)
    else
        msg = format("Indexing %s ids (one time per game update): %d%%%s", tableName, floor(frac * 100),
            count and format(", %d found", count) or "")
    end
    UI.SetStatus(msg)
end)
