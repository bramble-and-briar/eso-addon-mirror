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
    -- other add-ons' saved data
    "SELECT name, addon, characters, tables, tables_list FROM saved_variables ORDER BY name",
    "SELECT table_name, addon, records, columns, pattern FROM sv_tables ORDER BY records DESC",
    "SELECT sv, path, value FROM sv_values WHERE sv LIKE '%ConsoleMetrics%' LIMIT 200",
    "SCAN savedvariables",
    -- your own saved tables
    "CREATE TABLE IF NOT EXISTS notes (id INT PRIMARY KEY, note TEXT, done BOOL)",
    "INSERT INTO notes VALUES ((SELECT COALESCE(MAX(id), 0) + 1 FROM notes), 'Farm Kinras''s Wrath', FALSE)",
    "SELECT * FROM notes ORDER BY done, id",
    "UPDATE notes SET done = TRUE WHERE id = 1",
    "DELETE FROM notes WHERE done",
    "UPSERT INTO notes (id, done) VALUES (1, TRUE)",
    "CREATE TABLE IF NOT EXISTS best_times (boss TEXT PRIMARY KEY, secs REAL, tries INT)",
    "INSERT INTO best_times VALUES ('Zaan', 61.5, 1) ON CONFLICT DO UPDATE SET secs = MIN(secs, excluded.secs), tries = tries + 1",
    "CREATE TABLE IF NOT EXISTS wishlist (set_name TEXT, piece TEXT)",
    "INSERT INTO wishlist SELECT set_name, name FROM set_pieces WHERE set_name LIKE '%kinras%' AND NOT unlocked",
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
    S.barW = px(12)
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

-- Stacking order of ESQL's top-level windows, bottom to top. A higher draw
-- layer always wins, whichever window was clicked last, so dialogs can't end
-- up behind the main window.
local LAYERS = {
    main = { layer = DL_CONTROLS or 1, level = 1 },
    dialog = { layer = DL_OVERLAY or 3, level = 10 },   -- New table, Copy
    popup = { layer = DL_OVERLAY or 3, level = 50 },    -- dropdown lists
    tooltip = { layer = DL_OVERLAY or 3, level = 60 },
}

local function stack(win, kind)
    local l = LAYERS[kind]
    win:SetDrawTier(DT_HIGH)
    win:SetDrawLayer(l.layer)
    win:SetDrawLevel(l.level)
end

-- show a dialog in front of everything ESQL draws
local function raise(win)
    win:SetHidden(false)
    if win.BringWindowToTop then win:BringWindowToTop() end
end

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
    b.label = l
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
    stack(win, "main")
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

        -- Syntax highlighting: an edit box draws in one colour, so when you're
        -- not typing, a coloured label is shown in its place (the edit text is
        -- made transparent). While you type, the plain text is shown: edit
        -- boxes scroll sideways and a label can't follow that.
        local hl = WM:CreateControl(N("QueryHighlight"), win, CT_LABEL)
        hl:SetAnchor(TOPLEFT, editBg, TOPLEFT, 8, 0)
        hl:SetAnchor(BOTTOMRIGHT, editBg, BOTTOMRIGHT, -8, 0)
        hl:SetFont(font(S.editFont, false))
        hl:SetColor(1, 1, 1, 1)
        hl:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        hl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        hl:SetMaxLineCount(1)
        hl:SetDrawLevel(3)
        hl:SetMouseEnabled(false)
        UI.highlight = hl
        edit:SetHandler("OnTextChanged", function() UI.RefreshHighlight() end)

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
            UI.RefreshHighlight(true)
        end)
        edit:SetHandler("OnFocusLost", function(self)
            catcher:SetHidden(false)
            editBg:SetColor(0, 0, 0, 0.85)
            UI.RefreshHighlight(false)
            -- where to insert a clicked table / column name later
            UI.editCursor = self.GetCursorPosition and self:GetCursorPosition() or nil
            UI.editCursorText = self:GetText()
        end)
        UI.editCatcher = catcher
        UI.RefreshHighlight()
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
        addButton("NewTable", "New table", function() UI.ShowCreateTable() end)
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

    -- scroll bars: rows on the right, columns along the bottom
    UI.vbar = UI.Scrollbar(grid, "VBar", true)
    UI.vbar:SetAnchor(TOPRIGHT, grid, TOPRIGHT, 0, S.headerH)
    UI.vbar:SetAnchor(BOTTOMRIGHT, grid, BOTTOMRIGHT, 0, -S.barW)
    UI.vbar:SetWidth(S.barW)
    UI.hbar = UI.Scrollbar(grid, "HBar", false)
    UI.hbar:SetAnchor(BOTTOMLEFT, grid, BOTTOMLEFT, 0, 0)
    UI.hbar:SetAnchor(BOTTOMRIGHT, grid, BOTTOMRIGHT, -S.barW, 0)
    UI.hbar:SetHeight(S.barW)

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
    row:SetAnchor(TOPRIGHT, grid, TOPRIGHT, -S.barW, y)
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
        cell:SetHandler("OnMouseUp", function(self, btn, upInside)
            if upInside then UI.OnCellClicked(self.rowIndex, self.colIndex) end
        end)
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
    local n = math.max(1, floor((h - S.headerH - S.barW) / S.rowH))
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
        if UI.createWin then UI.createWin:SetHidden(true) end
        UI.CloseDropdown()
        UI.win, UI.edit, UI.grid, UI.status, UI.exportWin, UI.exportEdit = nil, nil, nil, nil, nil, nil
        UI.createWin = nil
        UI.exportPrev, UI.exportNext, UI.exportFormatBtn, UI.exportNote = nil, nil, nil, nil
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
    if not res then UI.UpdateScrollbars(); UI.UpdateStatus(); return end

    local widths = UI.widths or columnWidths(res)
    UI.widths = widths
    local gridW = UI.grid:GetWidth()
    if gridW <= 0 then gridW = UI.win:GetWidth() - 2 * S.pad end
    gridW = gridW - S.barW - 4
    local ncols = #res.columns
    -- the furthest column offset that still fills the grid
    local maxCol, acc = ncols - 1, 8
    for c = ncols, 1, -1 do
        acc = acc + math.min(widths[c], gridW) + 10
        if acc > gridW + 10 then break end
        maxCol = c - 1
    end
    UI.maxColOffset = math.max(0, maxCol)
    UI.colOffset = math.max(0, math.min(UI.colOffset, UI.maxColOffset))

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
                    if UI.CellRef(r, slot.col) then
                        cell:SetColor(0.45, 0.82, 1, 1)
                    else
                        cell:SetColor(0.92, 0.92, 0.92, 1)
                    end
                    cell:SetHidden(false)
                else
                    cell:SetHidden(true)
                end
            end
        end
    end
    UI.UpdateScrollbars()
    UI.UpdateStatus()
end

---------------------------------------------------------------------------
-- Scroll bars (plain controls; the game's scroll bar templates are keyboard-only)
---------------------------------------------------------------------------
local THUMB_IDLE, THUMB_HOT = 0.55, 0.9

-- the numbers each bar shows: offset, largest offset, visible, total
local function barState(bar)
    local res = UI.result
    if not res then return 0, 0, 0, 0 end
    if bar.vertical then
        local total, vis = #res.rows, UI.visibleRows or 1
        return UI.rowOffset, math.max(0, total - vis), vis, total
    end
    local total = #res.columns
    local vis = math.max(1, (UI.lastVisibleCol or 0) - UI.colOffset)
    return UI.colOffset, UI.maxColOffset or 0, vis, total
end

local function setBarOffset(bar, v)
    local _, maxOffset = barState(bar)
    v = math.max(0, math.min(maxOffset, floor(v + 0.5)))
    if bar.vertical then
        if v == UI.rowOffset then return end
        UI.rowOffset = v
    else
        if v == UI.colOffset then return end
        UI.colOffset = v
    end
    UI.Render()
end

local function mouseAlong(bar)
    local x, y = GetUIMousePosition()
    return bar.vertical and y or x
end

function UI.Scrollbar(parent, name, vertical)
    local bar = WM:CreateControl(N(name), parent, CT_CONTROL)
    bar.vertical = vertical
    bar:SetMouseEnabled(true)
    bar:SetDrawLevel(6)
    local track = solid(bar, name .. "Track", 1, 1, 1, 0.07)
    track:SetAnchorFill(bar)
    local thumb = WM:CreateControl(N(name .. "Thumb"), bar, CT_CONTROL)
    thumb:SetMouseEnabled(true)
    thumb:SetDrawLevel(7)
    local tex = solid(thumb, name .. "ThumbTex", 0.31, 0.76, 0.97, THUMB_IDLE)
    tex:SetAnchorFill(thumb)
    bar.thumb, bar.thumbTex = thumb, tex

    thumb:SetHandler("OnMouseEnter", function() tex:SetColor(0.31, 0.76, 0.97, THUMB_HOT) end)
    thumb:SetHandler("OnMouseExit", function() if not bar.drag then tex:SetColor(0.31, 0.76, 0.97, THUMB_IDLE) end end)
    -- drag the thumb
    thumb:SetHandler("OnMouseDown", function(_, button)
        if button and button ~= 1 then return end
        local offset = barState(bar)
        bar.drag = { start = mouseAlong(bar), offset = offset }
        thumb:SetHandler("OnUpdate", function()
            local d = bar.drag
            if not d then return end
            local _, maxOffset = barState(bar)
            local room = math.max(1, (bar.len or 1) - (bar.size or 0))
            setBarOffset(bar, d.offset + (mouseAlong(bar) - d.start) * maxOffset / room)
        end)
    end)
    thumb:SetHandler("OnMouseUp", function()
        bar.drag = nil
        thumb:SetHandler("OnUpdate", nil)
        tex:SetColor(0.31, 0.76, 0.97, THUMB_IDLE)
    end)
    -- click the track above / below (or left / right of) the thumb: a page
    bar:SetHandler("OnMouseUp", function(_, button, upInside)
        if not upInside or (button and button ~= 1) or thumb:IsHidden() then return end
        local m = mouseAlong(bar)
        local start = vertical and thumb:GetTop() or thumb:GetLeft()
        local offset, _, vis = barState(bar)
        if m < start then
            setBarOffset(bar, offset - math.max(1, vis - (vertical and 1 or 0)))
        elseif m > start + (bar.size or 0) then
            setBarOffset(bar, offset + math.max(1, vis - (vertical and 1 or 0)))
        end
    end)
    bar:SetHandler("OnMouseWheel", function(_, delta)
        if vertical then UI.ScrollRows(delta > 0 and -3 or 3) else UI.ScrollCols(delta > 0 and -1 or 1) end
    end)
    return bar
end

local function updateBar(bar)
    if not bar then return end
    local offset, maxOffset, vis, total = barState(bar)
    local len = bar.vertical and bar:GetHeight() or bar:GetWidth()
    local thick = S.barW
    if maxOffset <= 0 or total <= 0 or len <= thick * 2 then
        bar.thumb:SetHidden(true)          -- everything fits
        bar.len, bar.size = len, 0
        return
    end
    local size = math.min(len, math.max(thick * 2, floor(len * vis / total)))
    local pos = floor((len - size) * offset / maxOffset + 0.5)
    bar.thumb:ClearAnchors()
    if bar.vertical then
        bar.thumb:SetAnchor(TOPLEFT, bar, TOPLEFT, 0, pos)
        bar.thumb:SetDimensions(thick, size)
    else
        bar.thumb:SetAnchor(TOPLEFT, bar, TOPLEFT, pos, 0)
        bar.thumb:SetDimensions(size, thick)
    end
    bar.thumb:SetHidden(false)
    bar.len, bar.size, bar.pos = len, size, pos
end

function UI.UpdateScrollbars()
    updateBar(UI.vbar)
    updateBar(UI.hbar)
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
        if not E.isConsole then
            text = text .. (UI.HasCellRefs(res) and "  |  click a blue table or column name to use it in your query"
                or "  |  wheel scrolls, shift+wheel: columns, click a row: print it")
        end
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
    stack(tip, "tooltip")
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

---------------------------------------------------------------------------
-- Syntax highlighting of the query box
---------------------------------------------------------------------------
function UI.HighlightEnabled()
    return E.sv == nil or E.sv.highlight ~= false
end

-- Show the coloured copy when the box isn't being typed in (and isn't empty,
-- so its "Type SQL here" hint stays visible); otherwise the plain edit text.
-- focused: true / false from the focus handlers (HasFocus may not have
-- changed yet while they run); nil asks the edit box.
function UI.RefreshHighlight(focused)
    local edit, hl = UI.edit, UI.highlight
    if not edit or not hl then return end
    if focused == nil then focused = edit.HasFocus and edit:HasFocus() or false end
    UI.editFocused = focused
    local text = edit:GetText() or ""
    local show = UI.HighlightEnabled() and text ~= "" and not focused
    if show then
        local oneLine = text:gsub("[\r\n]+", " ")
        hl:SetText(LibESQL.Highlight(oneLine))
        hl:SetHidden(false)
        edit:SetColor(1, 1, 1, 0)
    else
        hl:SetHidden(true)
        edit:SetColor(1, 1, 1, 1)
    end
end

function UI.SetHighlight(on)
    E.sv.highlight = on and true or false
    UI.RefreshHighlight()
    if UI.createDialog then UI.RefreshCreatePreview() end
end

---------------------------------------------------------------------------
-- Clicking a table or column name puts it into the query box
---------------------------------------------------------------------------
local function trimText(t) return ((t or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- Which result columns hold table or column names. A column counts as table
-- names when it is called table_name / table, or when every value in it is an
-- existing table (SHOW TABLES, SELECT name FROM tables). column_name holds
-- column names (DESCRIBE, the columns table).
local function refColumns(res)
    if res._refCols then return res._refCols end
    local refs = {}
    for c, header in ipairs(res.columns) do
        local h = tostring(header):lower():gsub("^.*%.", "")
        if h == "column_name" then
            refs[c] = "column"
        elseif h == "table_name" or h == "table" or h == "name" then
            local any, all = false, true
            for r = 1, math.min(#res.rows, 200) do
                local v = res.rows[r][c]
                if v ~= nil then
                    any = true
                    if type(v) ~= "string" or not E.GetTable(v) then all = false; break end
                end
            end
            if any and all then refs[c] = "table" end
        end
    end
    res._refCols = refs
    return refs
end

function UI.HasCellRefs(res)
    return res ~= nil and next(refColumns(res)) ~= nil
end

-- { kind = "table" | "column", word = name, table = owning table (columns) } or nil
function UI.CellRef(r, c)
    local res = UI.result
    if not res or not r or not c or not res.rows[r] then return nil end
    local kind = refColumns(res)[c]
    local v = res.rows[r][c]
    if not kind or type(v) ~= "string" or v == "" then return nil end
    local ref = { kind = kind, word = v }
    if kind == "column" then
        -- the owning table: a table_name column in the same row, or DESCRIBE <table>
        for c2, header in ipairs(res.columns) do
            if tostring(header):lower() == "table_name" then ref.table = res.rows[r][c2] end
        end
        if not ref.table then
            ref.table = (res.query or E.sv.lastQuery or ""):lower():match("^%s*desc%a*%s+([%w_]+)")
        end
    end
    return ref
end

local function isListingQuery(text)
    local l = trimText(text):lower()
    return l == "" or l:find("^show%s") ~= nil or l:find("^desc") ~= nil or l:find("^help") ~= nil
end

-- Put a table / column name into the query box.
--  - box empty or still SHOW TABLES / DESCRIBE / HELP: start a new query
--      table  -> SELECT * FROM t
--      column -> SELECT col FROM t
--  - otherwise: insert the name at the cursor (or at the end), with spaces as needed
function UI.UseInQuery(ref)
    if not UI.edit or not ref then return end
    local edit = UI.edit
    local text = edit:GetText() or ""
    local new, cursor
    if isListingQuery(text) then
        if ref.kind == "table" then
            new = "SELECT * FROM " .. ref.word .. " "
        elseif ref.table then
            new = "SELECT " .. ref.word .. " FROM " .. ref.table .. " "
        else
            new = "SELECT " .. ref.word .. " "
        end
        cursor = #new
    else
        local pos = #text
        if UI.editCursor and UI.editCursorText == text then pos = math.max(0, math.min(UI.editCursor, #text)) end
        local before, after = text:sub(1, pos), text:sub(pos + 1)
        local sepBefore = (before == "" or before:find("[%s%(,]$")) and "" or " "
        local sepAfter = (after == "" or after:find("^[%s%),;]")) and (after == "" and " " or "") or " "
        new = before .. sepBefore .. ref.word .. sepAfter .. after
        cursor = #before + #sepBefore + #ref.word + #sepAfter
    end
    edit:SetText(new)
    edit:TakeFocus()
    if edit.SetCursorPosition then edit:SetCursorPosition(cursor) end
    UI.editCursor, UI.editCursorText = cursor, new
    UI.SetStatus(format("Added %s %s to the query. Keep typing, then press Enter.", ref.kind, ref.word))
end

function UI.OnCellClicked(r, c)
    local ref = UI.CellRef(r, c)
    if ref then
        UI.UseInQuery(ref)
    else
        UI.PrintRow(r)
    end
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
    local ref = UI.CellRef(cell.rowIndex, cell.colIndex)
    if ref then
        body = body .. format("\n|c7FD67FClick to use this %s in your query|r", ref.kind)
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

-- The Copy window. ESO edit boxes garble their text once they hold tens of
-- thousands of characters, so the export is split into pages that are small
-- enough to draw. Each page ends at a row boundary.
UI.EXPORT_PAGE_CHARS = 6000   -- characters per page (well under what an edit box can draw)
UI.EXPORT_CELL_MAX = 1000     -- longer cells are cut, so one cell can't overflow a page
UI.exportFormat = "tsv"       -- "tsv" (tabs, for spreadsheets), "csv" (commas) or "mysql" (.sql dump)

local FORMAT_LABEL = { tsv = "Tabs (spreadsheet)", csv = "Commas (CSV)", mysql = "MySQL (.sql)" }
local NEXT_FORMAT = { tsv = "csv", csv = "mysql", mysql = "tsv" }

-- MySQL table name for a result: the table it was read from, or esql_export
function UI.ExportTableName(res)
    local from = (res.query or ""):match("[Ff][Rr][Oo][Mm]%s+([%w_]+)")
    return LibESQL.MySQLTableName(from and ("esql_" .. from) or "esql_export")
end

local function exportCell(v, fmt)
    if v == nil then return "" end
    local text = tostring(SQL.ToText(v)):gsub("[\r\n]+", " ")
    if #text > UI.EXPORT_CELL_MAX then text = text:sub(1, UI.EXPORT_CELL_MAX) .. "..." end
    if fmt == "csv" then
        if text:find('[,"]') or text:find("^%s") or text:find("%s$") then
            text = '"' .. text:gsub('"', '""') .. '"'
        end
    else
        text = text:gsub("\t", " ")
    end
    return text
end

local function exportLine(values, n, fmt)
    local parts = {}
    for c = 1, n do parts[c] = exportCell(values[c], fmt) end
    return table.concat(parts, fmt == "csv" and "," or "\t")
end

-- Whole result as text (header + every row). Used for small results and by add-ons.
function UI.ResultText(res, max, fmt)
    fmt = fmt or "tsv"
    local n = #res.columns
    local lines = { exportLine(res.columns, n, fmt) }
    for r = 1, math.min(#res.rows, max or #res.rows) do lines[#lines + 1] = exportLine(res.rows[r], n, fmt) end
    return table.concat(lines, "\n")
end

-- Split a result into pages: { { first = row, last = row, text = "..." }, ... }.
-- The header row is on page 1 only, so pasted pages stack into one sheet.
local function buildMySQLPages(res, pageChars)
    local _, blocks = LibESQL.ToMySQL(res, UI.ExportTableName(res), {
        rowsPerInsert = 200, maxInsertBytes = pageChars - 200,
        comment = res.query and ("From: " .. res.query) or nil,
    })
    local pages, cur, curLen, first, last = {}, {}, 0, nil, nil
    local function flush()
        if #cur > 0 then
            pages[#pages + 1] = { first = first or 1, last = last or 0, text = table.concat(cur, "\n\n"), sql = true }
            cur, curLen, first, last = {}, 0, nil, nil
        end
    end
    for _, b in ipairs(blocks) do
        if #cur > 0 and curLen + 2 + #b.text > pageChars then flush() end
        cur[#cur + 1] = b.text
        curLen = curLen + (#cur > 1 and 2 or 0) + #b.text
        if b.first then first = first or b.first; last = b.last end
    end
    flush()
    return pages
end

function UI.BuildExportPages(res, fmt, pageChars)
    fmt = fmt or "tsv"
    pageChars = pageChars or UI.EXPORT_PAGE_CHARS
    if fmt == "mysql" then return buildMySQLPages(res, pageChars) end
    local n = #res.columns
    local pages = {}
    local cur, curLen, first = { exportLine(res.columns, n, fmt) }, 0, 1
    curLen = #cur[1]
    local function flush(last)
        pages[#pages + 1] = { first = first, last = last, text = table.concat(cur, "\n") }
    end
    for r = 1, #res.rows do
        local line = exportLine(res.rows[r], n, fmt)
        if #cur > 0 and curLen + 1 + #line > pageChars and (#pages > 0 or #cur > 1) then
            flush(r - 1)
            cur, curLen, first = {}, 0, r
        end
        cur[#cur + 1] = line
        curLen = curLen + (#cur > 1 and 1 or 0) + #line
    end
    if #cur > 0 or #pages == 0 then flush(#res.rows) end
    return pages
end

local function showExportPage(i)
    local pages = UI.exportPages
    if not pages or #pages == 0 then return end
    i = math.max(1, math.min(i, #pages))
    UI.exportPageIndex = i
    local page = pages[i]
    UI.exportText = page.text
    local res = UI.result
    local rows = page.last >= page.first and format("rows %d-%d of %d", page.first, page.last, #res.rows)
        or (page.sql and "table structure" or "no rows")
    local tail
    if page.sql then
        tail = #pages > 1 and " Paste the pages in order into one .sql file, then import it in phpMyAdmin." or " Save it as a .sql file and import it in phpMyAdmin."
    else
        tail = (i == 1 and #pages > 1) and " The header row is on page 1." or ""
    end
    UI.exportNote:SetText(format("Page %d of %d, %s. Select all, then Ctrl+C to copy.%s", i, #pages, rows, tail))
    UI.exportEdit:SetText(page.text)
    UI.exportPrev:SetHidden(i <= 1)
    UI.exportNext:SetHidden(i >= #pages)
    UI.exportEdit:TakeFocus()
    UI.exportEdit:SelectAll()
end
UI.ShowExportPage = showExportPage

function UI.SetExportFormat(fmt)
    UI.exportFormat = fmt
    if UI.exportFormatBtn then
        UI.exportFormatBtn.label:SetText(FORMAT_LABEL[fmt] or FORMAT_LABEL.tsv)
    end
    if UI.result and UI.exportWin and not UI.exportWin:IsHidden() then
        local row = UI.exportPages and UI.exportPages[UI.exportPageIndex or 1]
        UI.exportPages = UI.BuildExportPages(UI.result, fmt)
        -- stay on the page that holds the same first row
        local target = 1
        for i, p in ipairs(UI.exportPages) do
            if row and p.first <= row.first and p.last >= row.first then target = i; break end
        end
        showExportPage(target)
    end
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
        stack(w, "dialog")
        local bg = solid(w, "ExportBG", 0.03, 0.03, 0.05, 0.97)
        bg:SetAnchorFill(w)
        local t = label(w, "ExportTitle", S.headFont, true, "Copy results")
        t:SetAnchor(TOPLEFT, w, TOPLEFT, S.pad, S.pad * 0.6)
        local c = button(w, "ExportClose", "Close", S.buttonFont * 5, function() w:SetHidden(true) end)
        c:SetAnchor(TOPRIGHT, w, TOPRIGHT, -S.pad * 0.6, S.pad * 0.6)

        local edit = WM:CreateControl(N("ExportEdit"), w, CT_EDITBOX)
        -- ESO doesn't let add-ons write to the clipboard (CopyAllTextToClipboard is
        -- private), so this selects the page and you press Ctrl+C.
        local selectAll = button(w, "ExportSelect", "Select all (then Ctrl+C)", S.buttonFont * 13, function() UI.CopyExport() end)
        selectAll:SetAnchor(RIGHT, c, LEFT, -8, 0)

        local note = label(w, "ExportNote", S.statusFont, false, "")
        note:SetAnchor(TOPLEFT, w, TOPLEFT, S.pad, S.buttonH + S.pad * 1.2)
        note:SetAnchor(TOPRIGHT, w, TOPRIGHT, -S.pad, S.buttonH + S.pad * 1.2)
        note:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        note:SetColor(0.78, 0.84, 0.9, 1)
        UI.exportNote = note

        -- page and format controls
        local y2 = S.buttonH + S.pad * 1.2 + S.statusFont + 10
        local prev = button(w, "ExportPrev", "< Prev", S.buttonFont * 5, function() showExportPage((UI.exportPageIndex or 1) - 1) end)
        prev:SetAnchor(TOPLEFT, w, TOPLEFT, S.pad, y2)
        local nextB = button(w, "ExportNext", "Next >", S.buttonFont * 5, function() showExportPage((UI.exportPageIndex or 1) + 1) end)
        nextB:SetAnchor(TOPLEFT, w, TOPLEFT, S.pad + S.buttonFont * 5 + 8, y2)
        local fmtBtn = button(w, "ExportFormat", "", S.buttonFont * 10, function()
            UI.SetExportFormat(NEXT_FORMAT[UI.exportFormat] or "tsv")
        end)
        fmtBtn:SetAnchor(TOPRIGHT, w, TOPRIGHT, -S.pad, y2)
        UI.exportPrev, UI.exportNext, UI.exportFormatBtn = prev, nextB, fmtBtn

        local box = solid(w, "ExportBox", 0, 0, 0, 0.6)
        box:SetAnchor(TOPLEFT, w, TOPLEFT, S.pad, y2 + S.buttonH + 8)
        box:SetAnchor(BOTTOMRIGHT, w, BOTTOMRIGHT, -S.pad, -S.pad)
        edit:SetAnchor(TOPLEFT, box, TOPLEFT, 6, 4)
        edit:SetAnchor(BOTTOMRIGHT, box, BOTTOMRIGHT, -6, -4)
        edit:SetFont(font(S.cellFont, false))
        edit:SetColor(1, 1, 1, 1)
        edit:SetMultiLine(true)
        edit:SetNewLineEnabled(true)
        edit:SetCopyEnabled(true)
        edit:SetMaxInputChars(UI.EXPORT_PAGE_CHARS + UI.EXPORT_CELL_MAX + 4096)
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
    UI.SetExportFormat(UI.exportFormat)   -- button text
    UI.exportPages = UI.BuildExportPages(res, UI.exportFormat)
    raise(UI.exportWin)
    showExportPage(1)
end

-- Select the page so Ctrl+C copies it. (Add-ons can't put text on the
-- clipboard themselves: the game made that private.)
function UI.CopyExport()
    local edit = UI.exportEdit
    if not edit then return end
    edit:TakeFocus()
    edit:SelectAll()
    if UI.SetStatus then
        local pages = UI.exportPages or {}
        UI.exportNote:SetText(format("Selected page %d of %d (%d characters). Press Ctrl+C to copy it.",
            UI.exportPageIndex or 1, #pages, #(UI.exportText or "")))
    end
end

---------------------------------------------------------------------------
-- Dropdown (built from plain controls; the game's combo box templates are
-- keyboard-only and don't render in every UI mode)
---------------------------------------------------------------------------
local openList

function UI.CloseDropdown()
    if openList then openList:SetHidden(true); openList = nil end
end

-- choices: { { value = , text = }, ... }; getValue() -> current value; onSelect(value)
local function dropdown(parent, name, width, choices, getValue, onSelect)
    local b = button(parent, name, "", width, function() end)
    local listW = math.max(width, floor(S.buttonFont * 14))
    local list = WM:CreateTopLevelWindow(N(name .. "List"))
    stack(list, "popup")
    list:SetMouseEnabled(true)
    list:SetClampedToScreen(true)
    list:SetHidden(true)
    list:SetDimensions(listW, #choices * S.buttonH)
    local lbg = solid(list, name .. "ListBG", 0.02, 0.03, 0.05, 0.98)
    lbg:SetAnchorFill(list)
    local function textFor(v)
        for _, c in ipairs(choices) do if c.value == v then return c.short or c.text end end
        return tostring(v or "")
    end
    function b.Refresh() b.label:SetText(textFor(getValue()) .. "  v") end
    for i, c in ipairs(choices) do
        local opt = button(list, name .. "Opt" .. i, c.text, listW, function()
            UI.CloseDropdown()
            onSelect(c.value)
            b.Refresh()
        end)
        opt:SetAnchor(TOPLEFT, list, TOPLEFT, 0, (i - 1) * S.buttonH)
    end
    b:SetHandler("OnMouseUp", function(_, btn, upInside)
        if not upInside then return end
        if openList == list then UI.CloseDropdown(); return end
        UI.CloseDropdown()
        list:ClearAnchors()
        list:SetAnchor(TOPLEFT, b, BOTTOMLEFT, 0, 2)
        raise(list)
        openList = list
        if PlaySound and SOUNDS then PlaySound(SOUNDS.DEFAULT_CLICK) end
    end)
    b.Refresh()
    return b
end
UI.Dropdown = dropdown

---------------------------------------------------------------------------
-- Create Table dialog (PC): name + one row per column with a type dropdown
---------------------------------------------------------------------------
local MAX_NEW_COLUMNS = 12

-- an edit box with the same click-to-focus fix as the query box
local function inputBox(parent, name, width, defaultText, onChange)
    local bg = solid(parent, name .. "BG", 0, 0, 0, 0.85)
    bg:SetDimensions(width, S.editH)
    bg:SetMouseEnabled(true)
    local edit = WM:CreateControl(N(name), parent, CT_EDITBOX)
    edit:SetAnchor(TOPLEFT, bg, TOPLEFT, 6, 0)
    edit:SetAnchor(BOTTOMRIGHT, bg, BOTTOMRIGHT, -6, 0)
    edit:SetFont(font(S.editFont, false))
    edit:SetColor(1, 1, 1, 1)
    edit:SetMaxInputChars(40)
    edit:SetMouseEnabled(true)
    edit:SetDrawLevel(3)
    if edit.SetVirtualKeyboardType then edit:SetVirtualKeyboardType(VIRTUAL_KEYBOARD_TYPE_DEFAULT or 0) end
    if defaultText then edit:SetDefaultText(defaultText) end
    local catcher = WM:CreateControl(N(name .. "Click"), parent, CT_CONTROL)
    catcher:SetAnchorFill(bg)
    catcher:SetMouseEnabled(true)
    catcher:SetDrawLevel(4)
    catcher:SetHandler("OnMouseDown", function() catcher:SetHidden(true); edit:TakeFocus() end)
    edit:SetHandler("OnFocusGained", function() catcher:SetHidden(true); bg:SetColor(0.05, 0.12, 0.18, 0.95) end)
    edit:SetHandler("OnFocusLost", function() catcher:SetHidden(false); bg:SetColor(0, 0, 0, 0.85) end)
    edit:SetHandler("OnEscape", function(self) self:LoseFocus() end)
    edit:SetHandler("OnEnter", function(self) self:LoseFocus() end)
    if onChange then edit:SetHandler("OnTextChanged", function(self) onChange(self:GetText()) end) end
    return bg, edit
end

local function typeChoices()
    local out = {}
    for i, t in ipairs(E.Console.TYPE_CHOICES) do
        out[i] = { value = t.value, short = t.value, text = t.value .. "  |c9AA4B0" .. t.hint .. "|r" }
    end
    return out
end

local function newModel() return { name = "", cols = { { name = "", type = "TEXT" } } } end

-- the Columns line ("id INT, note TEXT") from the dialog rows; empty names are skipped
function UI.CreateColumnsText()
    local parts = {}
    for _, c in ipairs(UI.newTable.cols) do
        local n = (c.name or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if n ~= "" then parts[#parts + 1] = E.Console.ColumnSpec(n, c.type) .. (c.primary and " PRIMARY KEY" or "") end
    end
    return table.concat(parts, ", ")
end

local function updateCreatePreview()
    local d = UI.createDialog
    if not d then return end
    local cols = UI.CreateColumnsText()
    local text
    if (UI.newTable.name or "") == "" and cols == "" then
        text = "Name the table, add columns and pick their types."
    else
        local sql, err = E.Console.BuildCreateSQL(UI.newTable.name, cols)
        if sql and UI.HighlightEnabled() then sql = LibESQL.Highlight(sql) end
        text = sql and ("|c7FD67FWill run:|r " .. sql) or ("|cFF6666" .. err .. "|r")
    end
    d.preview:SetText(text)
end

function UI.RefreshCreatePreview() updateCreatePreview() end

local function layoutCreate()
    local d = UI.createDialog
    local m = UI.newTable
    for i = 1, MAX_NEW_COLUMNS do
        local row = d.rows[i]
        local c = m.cols[i]
        row:SetHidden(c == nil)
        if c then
            d.suppress = true
            if row.edit:GetText() ~= (c.name or "") then row.edit:SetText(c.name or "") end
            d.suppress = false
            row.type.Refresh()
            row.key.label:SetText(c.primary and "* Key" or "Key")
            row.key.label:SetColor(c.primary and 1 or 0.6, c.primary and 0.84 or 0.65, c.primary and 0.31 or 0.7, 1)
        end
    end
    if d.nameEdit:GetText() ~= (m.name or "") then
        d.suppress = true; d.nameEdit:SetText(m.name or ""); d.suppress = false
    end
    d.template.Refresh()
    local n = #m.cols
    local y = d.rowsTop + n * (S.editH + 6) + 4
    d.addCol:ClearAnchors()
    d.addCol:SetAnchor(TOPLEFT, d.win, TOPLEFT, S.pad, y)
    d.addCol:SetHidden(n >= MAX_NEW_COLUMNS)
    y = y + S.buttonH + 10
    d.preview:ClearAnchors()
    d.preview:SetAnchor(TOPLEFT, d.win, TOPLEFT, S.pad, y)
    d.preview:SetWidth(d.width - 2 * S.pad)
    y = y + 2 * (S.statusFont + 8) + 8
    d.createBtn:ClearAnchors()
    d.createBtn:SetAnchor(TOPLEFT, d.win, TOPLEFT, S.pad, y)
    d.win:SetHeight(y + S.buttonH + S.pad)
    updateCreatePreview()
end

local function buildCreateDialog()
    local C = E.Console
    local W = floor(math.min(GuiRoot:GetWidth() * 0.9, 820 * S.k))
    local win = WM:CreateTopLevelWindow(N("Create"))
    win:SetDimensions(W, 400)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    win:SetMovable(true); win:SetMouseEnabled(true); win:SetClampedToScreen(true)
    stack(win, "dialog")
    win:SetHidden(true)
    local bg = solid(win, "CreateBG", 0.04, 0.05, 0.07, 0.97)
    bg:SetAnchorFill(win)
    local accent = solid(win, "CreateAccent", 0.31, 0.76, 0.97, 1)
    accent:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 0)
    accent:SetAnchor(TOPRIGHT, win, TOPRIGHT, 0, 0)
    accent:SetHeight(3)

    local d = { win = win, width = W, rows = {} }
    UI.createDialog = d
    local pad = S.pad
    local labelW = floor(S.buttonFont * 7)

    local title = label(win, "CreateTitle", S.titleFont, true, "Create a table")
    title:SetAnchor(TOPLEFT, win, TOPLEFT, pad, pad * 0.6)
    local close = button(win, "CreateClose", "X", S.buttonH, function() UI.HideCreateTable() end)
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -pad * 0.6, pad * 0.6)

    -- template
    local y = pad * 0.6 + S.buttonH + pad * 0.6
    local tl = label(win, "CreateTplLabel", S.cellFont, false, "Start from")
    tl:SetAnchor(TOPLEFT, win, TOPLEFT, pad, y + 6)
    local tplChoices = {}
    for i, t in ipairs(C.TEMPLATES) do tplChoices[i] = { value = i, text = t.name } end
    d.template = dropdown(win, "CreateTpl", floor(S.buttonFont * 14), tplChoices,
        function() return UI.newTable.template end,
        function(i)
            local t = C.TEMPLATES[i]
            UI.newTable = { name = t.table, cols = {}, template = i }
            local parsed = C.ParseColumns(t.cols) or {}
            for k, c in ipairs(parsed) do UI.newTable.cols[k] = { name = c.name, type = c.type or "ANY", primary = c.primary } end
            if #UI.newTable.cols == 0 then UI.newTable.cols[1] = { name = "", type = "TEXT" } end
            layoutCreate()
        end)
    d.template:SetAnchor(TOPLEFT, win, TOPLEFT, pad + labelW, y)

    -- table name
    y = y + S.buttonH + 10
    local nl = label(win, "CreateNameLabel", S.cellFont, false, "Table name")
    nl:SetAnchor(TOPLEFT, win, TOPLEFT, pad, y + 8)
    local nameBox, nameEdit = inputBox(win, "CreateName", W - 2 * pad - labelW, "for example my_notes", function(text)
        if d.suppress then return end
        UI.newTable.name = text
        updateCreatePreview()
    end)
    nameBox:SetAnchor(TOPLEFT, win, TOPLEFT, pad + labelW, y)
    d.nameEdit = nameEdit

    -- column header
    y = y + S.editH + 12
    local typeW = floor(S.buttonFont * 8)
    local removeW = S.buttonH
    local keyW = floor(S.buttonFont * 4)
    local nameW = W - 2 * pad - typeW - keyW - removeW - 24
    local h1 = label(win, "CreateColHead", S.headFont, true, "Column")
    h1:SetColor(0.45, 0.82, 1, 1)
    h1:SetAnchor(TOPLEFT, win, TOPLEFT, pad, y)
    local h2 = label(win, "CreateTypeHead", S.headFont, true, "Type")
    h2:SetColor(0.45, 0.82, 1, 1)
    h2:SetAnchor(TOPLEFT, win, TOPLEFT, pad + nameW + 8, y)
    d.rowsTop = y + S.headFont + 10

    -- column rows (created once, shown as needed)
    local choices = typeChoices()
    for i = 1, MAX_NEW_COLUMNS do
        local row = WM:CreateControl(N("CreateRow" .. i), win, CT_CONTROL)
        row:SetDimensions(W - 2 * pad, S.editH)
        row:SetAnchor(TOPLEFT, win, TOPLEFT, pad, d.rowsTop + (i - 1) * (S.editH + 6))
        local box, edit = inputBox(row, "CreateCol" .. i, nameW, i == 1 and "column name, e.g. note" or "column name", function(text)
            if d.suppress then return end
            local c = UI.newTable.cols[i]
            if c then c.name = text end
            updateCreatePreview()
        end)
        box:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
        row.edit = edit
        row.type = dropdown(row, "CreateType" .. i, typeW, choices,
            function() local c = UI.newTable.cols[i]; return c and c.type end,
            function(v)
                local c = UI.newTable.cols[i]
                if c then c.type = v end
                updateCreatePreview()
            end)
        row.type:SetAnchor(TOPLEFT, row, TOPLEFT, nameW + 8, floor((S.editH - S.buttonH) / 2))
        -- Key: part of the PRIMARY KEY (UPSERT matches rows on it)
        row.key = button(row, "CreateKey" .. i, "Key", keyW, function()
            local c = UI.newTable.cols[i]
            if c then c.primary = not c.primary end
            layoutCreate()
        end)
        row.key:SetAnchor(TOPLEFT, row, TOPLEFT, nameW + 8 + typeW + 8, floor((S.editH - S.buttonH) / 2))
        local rm = button(row, "CreateRm" .. i, "X", removeW, function()
            UI.CloseDropdown()
            table.remove(UI.newTable.cols, i)
            if #UI.newTable.cols == 0 then UI.newTable.cols[1] = { name = "", type = "TEXT" } end
            layoutCreate()
        end)
        rm:SetAnchor(TOPLEFT, row, TOPLEFT, nameW + 8 + typeW + 8 + keyW + 8, floor((S.editH - S.buttonH) / 2))
        d.rows[i] = row
    end

    d.addCol = button(win, "CreateAddCol", "+ Add column", floor(S.buttonFont * 9), function()
        UI.CloseDropdown()
        if #UI.newTable.cols < MAX_NEW_COLUMNS then
            UI.newTable.cols[#UI.newTable.cols + 1] = { name = "", type = "TEXT" }
            layoutCreate()
            local row = d.rows[#UI.newTable.cols]
            if row then row.edit:TakeFocus() end
        end
    end)

    d.preview = label(win, "CreatePreview", S.statusFont, false, "")
    d.preview:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    d.preview:SetMaxLineCount(2)

    d.createBtn = button(win, "CreateGo", "Create", floor(S.buttonFont * 6), function() UI.CreateTableFromDialog() end)
    local cancel = button(win, "CreateCancel", "Cancel", floor(S.buttonFont * 6), function() UI.HideCreateTable() end)
    cancel:SetAnchor(LEFT, d.createBtn, RIGHT, 8, 0)

    UI.createWin = win
end

function UI.ShowCreateTable()
    UI.Show()
    if not UI.newTable then UI.newTable = newModel() end
    if not UI.createWin then buildCreateDialog() end
    raise(UI.createWin)
    layoutCreate()
end

function UI.HideCreateTable()
    UI.CloseDropdown()
    if UI.createWin then UI.createWin:SetHidden(true) end
end

function UI.CreateTableFromDialog()
    UI.CloseDropdown()
    local C = E.Console
    C.newName, C.newCols = UI.newTable.name, UI.CreateColumnsText()
    return C.CreateFromPrompt(function(ok)
        if ok and C.created then
            UI.newTable = newModel()
            UI.HideCreateTable()
            -- ready to add the first row
            if UI.edit and C.query then UI.edit:SetText(C.query); UI.edit:TakeFocus() end
            UI.SetStatus(format("Created table %s. Edit the INSERT in the query box and press Run to add a row.", C.created))
        end
    end)
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
-- UPDATE / DELETE without WHERE change every row of a table: ask first.
-- Returns true when the caller should stop and wait for a second Run.
local function needsConfirm(text)
    local ok, stmt = pcall(SQL.Parse, text, setmetatable({}, { __index = function() return 0 end }))
    if not ok or type(stmt) ~= "table" then return false end
    if (stmt.k ~= "update" and stmt.k ~= "delete") or stmt.where then
        UI.pendingConfirm = nil
        return false
    end
    if UI.pendingConfirm == text then
        UI.pendingConfirm = nil
        return false
    end
    UI.pendingConfirm = text
    local def = E.GetTable(stmt.name)
    local n = def and def.rows and #def.rows
    UI.SetStatus(format("|cFFD54FThis %s every row%s of %s. Press Run again to confirm, or add a WHERE.|r",
        stmt.k == "delete" and "deletes" or "changes", n and format(" (%d)", n) or "", stmt.name))
    return true
end

function UI.RunText(text, onDone)
    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return end
    UI.Show()
    if UI.edit and UI.edit:GetText() ~= text then UI.edit:SetText(text) end
    if needsConfirm(text) then
        if E.Console and E.Console.Refresh then E.Console.Refresh() end
        -- console: the status line isn't always visible, so say it in chat too
        if E.isConsole then E.Print("%s", E.StripMarkup(UI.statusText or "")) end
        return
    end
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
            res.query = text
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
