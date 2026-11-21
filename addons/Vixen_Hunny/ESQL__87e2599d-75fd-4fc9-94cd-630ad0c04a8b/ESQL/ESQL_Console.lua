-- Settings panel (LibHarvensAddonSettings): the way to use ESQL on console,
-- and an alternative to /esql on PC. Settings > Addons > ESQL.

local E = ESQL
local C = {}
E.Console = C

local UI = E.UI
local format = string.format

C.query = nil

local function truncate(s, n)
    if #s <= n then return s end
    return s:sub(1, n - 3) .. "..."
end

local function itemFromArgs(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "table" and v.data ~= nil then return v end
    end
end

---------------------------------------------------------------------------
-- Create a table prompt
---------------------------------------------------------------------------
C.TEMPLATES = {
    { name = "Notes", table = "notes", cols = "id INT PRIMARY KEY, note TEXT, done BOOL" },
    { name = "Wishlist (set pieces)", table = "wishlist", cols = "set_name TEXT, piece TEXT, got BOOL" },
    { name = "Boss times", table = "boss_times", cols = "boss TEXT, secs REAL, at INT" },
    { name = "Shopping list", table = "shopping", cols = "item TEXT PRIMARY KEY, count INT, bought BOOL" },
    { name = "Blank", table = "", cols = "" },
}

-- Column types offered in the type dropdowns (console panel and PC window).
C.TYPE_CHOICES = {
    { value = "TEXT", hint = "words and names" },
    { value = "INT", hint = "whole numbers" },
    { value = "REAL", hint = "decimal numbers" },
    { value = "BOOL", hint = "true / false" },
    { value = "ANY", hint = "no fixed type" },
}

-- "name TYPE" for the Columns line (ANY has no type word)
function C.ColumnSpec(name, colType)
    if not colType or colType == "ANY" then return name end
    return name .. " " .. colType
end

local TYPES = {
    int = "INT", integer = "INT", real = "REAL", float = "REAL", number = "REAL", num = "REAL",
    text = "TEXT", string = "TEXT", varchar = "TEXT", bool = "BOOL", boolean = "BOOL",
}
local MAX_COLUMNS = 30

local function trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- Parse "id INT, note TEXT" -> { {name, type}, ... } or nil + problem
function C.ParseColumns(text)
    text = trim(text)
    if text == "" then return nil, "add at least one column, e.g. id INT, note TEXT" end
    local cols, seen = {}, {}
    for part in (text .. ","):gmatch("([^,]*),") do
        part = trim(part)
        if part == "" then return nil, "there is an empty column (two commas in a row?)" end
        local name, ty, extra = part:match("^(%S+)%s*(%S*)%s*(.*)$")
        name = name and name:lower()
        if not name or not name:find("^[%a_][%w_]*$") then
            return nil, format("'%s' is not a valid column name (letters, digits and _; not starting with a digit)", part)
        end
        -- "name TYPE PRIMARY KEY" or "name PRIMARY KEY": the key used by UPSERT
        local primary = false
        local rest = ((ty ~= "" and (ty .. " ") or "") .. extra):lower():gsub("%s+", " "):gsub("%s$", "")
        if rest:find("primary key$") then
            primary = true
            rest = rest:gsub("%s*primary key$", "")
            ty = rest
            extra = ""
        end
        if extra ~= "" or ty:find(" ") then return nil, format("'%s': write one name and one type per column (and PRIMARY KEY if it's the key)", part) end
        if seen[name] then return nil, format("column '%s' is listed twice", name) end
        seen[name] = true
        local t = nil
        if ty ~= "" then
            t = TYPES[ty:lower()]
            if not t then return nil, format("unknown type '%s' for %s (use INT, REAL, TEXT or BOOL)", ty, name) end
        end
        cols[#cols + 1] = { name = name, type = t, primary = primary }
        if #cols > MAX_COLUMNS then return nil, format("at most %d columns", MAX_COLUMNS) end
    end
    return cols
end

-- Validate the prompt. Returns sql, tableName, cols  or  nil, problem
function C.BuildCreateSQL(tableName, columnsText)
    local name = trim(tableName):lower()
    if name == "" then return nil, "type a table name" end
    if not name:find("^[%a_][%w_]*$") then
        return nil, "the table name can use letters, digits and _, and can't start with a digit"
    end
    if #name > 40 then return nil, "the table name is longer than 40 characters" end
    if E.IsBuiltinTable(name) then return nil, format("'%s' is a built-in table; pick another name", name) end
    if E.GetTable(name) then return nil, format("table '%s' already exists", name) end
    local cols, err = C.ParseColumns(columnsText)
    if not cols then return nil, err end
    local parts = {}
    for i, c in ipairs(cols) do
        parts[i] = (c.type and (c.name .. " " .. c.type) or c.name) .. (c.primary and " PRIMARY KEY" or "")
    end
    local sql = format("CREATE TABLE %s (%s)", name, table.concat(parts, ", "))
    local ok, perr = E.Validate(sql)
    if not ok then return nil, perr end
    return sql, name, cols
end

-- "INSERT INTO notes (id, note, done) VALUES (0, 'text', FALSE)" for a table
function C.InsertTemplate(tableName)
    local def = E.GetTable(tableName or "")
    if not def then return nil end
    local names, values = {}, {}
    for i, c in ipairs(def.columns) do
        names[i] = c.name
        local t = c.type
        values[i] = (t == "int" or t == "num") and "0" or (t == "bool" and "FALSE") or (t == "text" and "'text'") or "NULL"
    end
    return format("INSERT INTO %s (%s) VALUES (%s)", def.name, table.concat(names, ", "), table.concat(values, ", "))
end

-- What the preview line shows
function C.CreatePreview()
    if trim(C.newName) == "" and trim(C.newCols) == "" then
        return "Pick a template or type a name and columns, then press Create."
    end
    local sql, err = C.BuildCreateSQL(C.newName, C.newCols)
    if not sql then return "|cFF6666" .. err .. "|r" end
    if UI.HighlightEnabled() then sql = E.Highlight(sql) end
    return "|c7FD67FWill run:|r " .. sql
end

-- Add column button: appends "name TYPE" to the Columns line.
-- Returns true, or false + problem (also printed).
function C.AddColumn()
    local name = trim(C.colName):lower()
    local problem
    if name == "" then
        problem = "type a column name first"
    elseif not name:find("^[%a_][%w_]*$") then
        problem = format("'%s' is not a valid column name (letters, digits and _; not starting with a digit)", name)
    else
        local cols = trim(C.newCols)
        local candidate = (cols ~= "" and (cols .. ", ") or "") .. C.ColumnSpec(name, C.colType or "TEXT")
        local ok, err = C.ParseColumns(candidate)
        if ok then
            C.newCols = candidate
            C.colName = ""
            C.Refresh()
            return true
        end
        problem = err
    end
    E.Print("|cFF6666Can't add the column:|r %s", problem)
    C.Refresh()
    return false, problem
end

-- Remove last column button
function C.RemoveLastColumn()
    local cols = trim(C.newCols)
    local cut = cols:match("^(.*),[^,]*$")
    C.newCols = cut and trim(cut) or ""
    C.Refresh()
end

-- The Create table button
function C.CreateFromPrompt(onDone)
    local sql, nameOrErr = C.BuildCreateSQL(C.newName, C.newCols)
    if not sql then
        E.Print("|cFF6666Can't create the table:|r %s", nameOrErr)
        UI.SetStatus("|cFF6666" .. nameOrErr .. "|r")
        C.Refresh()
        return false
    end
    local name = nameOrErr
    C.query = sql
    UI.RunText(sql, function(ok)
        if ok and E.GetTable(name) then
            C.created = name
            C.newName, C.newCols, C.templateName = "", "", nil
            C.query = C.InsertTemplate(name) or ("SELECT * FROM " .. name)
            E.Print("Created table %s. Use Add a row to insert into it.", name)
        end
        C.Refresh()
        if onDone then onDone(ok) end
    end)
    C.Refresh()
    return true
end

function C.Refresh()
    local panel = C.panel
    if panel and panel.selected and panel.UpdateControls then
        pcall(panel.UpdateControls, panel)
    end
end

function C.Status()
    if UI.running then return "|cFFD54FRunning...|r " .. (UI.statusText or "") end
    local res = UI.result
    if UI.statusText then return UI.statusText end
    if not res then return "No query run yet." end
    local total = #res.rows
    local nvis = UI.visibleRows or 10
    return format("%d row(s), showing %d-%d, columns %d-%d of %d (%d ms)%s", total,
        total > 0 and UI.rowOffset + 1 or 0, math.min(total, UI.rowOffset + nvis),
        UI.colOffset + 1, UI.lastVisibleCol or 0, #res.columns, res.elapsedMs or 0,
        res.truncated and " - capped, add LIMIT" or "")
end

function C.Init()
    local LHAS = LibHarvensAddonSettings
    if not LHAS or not LHAS.AddAddon then
        if E.isConsole then
            E.Print("Install LibHarvensAddonSettings to type queries on console. The Lua API (ESQL.Query) still works.")
        end
        return
    end
    C.query = E.sv.lastQuery or "SHOW TABLES"
    local panel = LHAS:AddAddon("ESQL", { allowDefaults = false, allowRefresh = true })
    C.panel = panel

    local function add(p) panel:AddSetting(p) end
    local function run()
        UI.RunText(C.query, function() C.Refresh() end)
        C.Refresh()
    end

    add({ type = LHAS.ST_SECTION, label = "Query" })
    add({
        type = LHAS.ST_BUTTON,
        label = "Edit SQL",
        buttonText = "Edit",
        tooltip = "Opens the results window and the on-screen keyboard. Confirm with Enter to run the query.",
        clickHandler = function() UI.EditQuery() end,
    })
    add({
        type = LHAS.ST_EDIT,
        label = "SQL (alternative input)",
        tooltip = "Type a query, e.g. SELECT * FROM abilities WHERE name LIKE '%rune%' LIMIT 50",
        getFunction = function() return C.query or "" end,
        setFunction = function(v) C.query = v end,
        maxChars = 1500,
        textType = TEXT_TYPE_ALL,
    })
    add({
        type = LHAS.ST_BUTTON,
        label = "Run query",
        buttonText = "Run",
        tooltip = "Runs the SQL above. Results show in the ESQL window and the first rows in chat.",
        clickHandler = run,
    })
    add({
        type = LHAS.ST_DROPDOWN,
        label = "Example queries",
        tooltip = "Pick an example to copy it into the SQL box, then press Run.",
        items = function()
            local items = {}
            for i, q in ipairs(UI.EXAMPLES) do items[i] = { name = truncate(q, 60), data = q } end
            return items
        end,
        getFunction = function() return C.exampleName end,
        setFunction = function(...)
            local item = itemFromArgs(...)
            if item then C.query = item.data; C.exampleName = item.name end
            C.Refresh()
        end,
    })
    add({
        type = LHAS.ST_DROPDOWN,
        label = "Browse a table",
        tooltip = "Pick a table to load SELECT * FROM it (LIMIT 200).",
        items = function()
            local items = {}
            for _, name in ipairs(E.tableOrder) do
                items[#items + 1] = { name = name, data = format("SELECT * FROM %s LIMIT 200", name) }
            end
            return items
        end,
        getFunction = function() return C.tableName end,
        setFunction = function(...)
            local item = itemFromArgs(...)
            if item then C.query = item.data; C.tableName = item.name end
            C.Refresh()
        end,
    })
    add({ type = LHAS.ST_LABEL, label = function() return C.Status() end })

    add({ type = LHAS.ST_SECTION, label = "Create a table" })
    add({
        type = LHAS.ST_DROPDOWN,
        label = "Start from",
        tooltip = "Fills in a table name and columns you can change before creating it.",
        items = function()
            local items = {}
            for i, t in ipairs(C.TEMPLATES) do items[i] = { name = t.name, data = t } end
            return items
        end,
        getFunction = function() return C.templateName end,
        setFunction = function(...)
            local item = itemFromArgs(...)
            if item then
                C.templateName = item.name
                C.newName, C.newCols = item.data.table, item.data.cols
            end
            C.Refresh()
        end,
    })
    add({
        type = LHAS.ST_EDIT,
        label = "Table name",
        tooltip = "Letters, digits and _, for example my_notes.",
        getFunction = function() return C.newName or "" end,
        setFunction = function(v) C.newName = v; C.Refresh() end,
        maxChars = 40,
        textType = TEXT_TYPE_ALL,
    })
    add({
        type = LHAS.ST_EDIT,
        label = "Columns",
        tooltip = "Name and type, separated by commas: id INT, note TEXT, done BOOL. Types: INT, REAL, TEXT, BOOL.",
        getFunction = function() return C.newCols or "" end,
        setFunction = function(v) C.newCols = v; C.Refresh() end,
        maxChars = 400,
        textType = TEXT_TYPE_ALL,
    })
    add({
        type = LHAS.ST_EDIT,
        label = "New column",
        tooltip = "Name of a column to add, for example note. Pick its type below, then press Add column.",
        getFunction = function() return C.colName or "" end,
        setFunction = function(v) C.colName = v end,
        maxChars = 40,
        textType = TEXT_TYPE_ALL,
    })
    add({
        type = LHAS.ST_DROPDOWN,
        label = "Type",
        tooltip = "TEXT for words, INT for whole numbers, REAL for decimals, BOOL for true/false, ANY for anything.",
        items = function()
            local items = {}
            for i, t in ipairs(C.TYPE_CHOICES) do items[i] = { name = t.value .. " - " .. t.hint, data = t.value } end
            return items
        end,
        getFunction = function()
            for _, t in ipairs(C.TYPE_CHOICES) do
                if t.value == (C.colType or "TEXT") then return t.value .. " - " .. t.hint end
            end
        end,
        setFunction = function(...)
            local item = itemFromArgs(...)
            if item then C.colType = item.data end
        end,
    })
    add({
        type = LHAS.ST_BUTTON, label = "Add column", buttonText = "Add",
        tooltip = "Adds the new column with the chosen type to the Columns line.",
        clickHandler = function() C.AddColumn() end,
    })
    add({
        type = LHAS.ST_BUTTON, label = "Remove last column", buttonText = "Remove",
        clickHandler = function() C.RemoveLastColumn() end,
    })
    add({ type = LHAS.ST_LABEL, label = function() return C.CreatePreview() end })
    add({
        type = LHAS.ST_BUTTON,
        label = "Create table",
        buttonText = "Create",
        tooltip = "Creates the table. It is saved with your account; game tables can't be changed.",
        clickHandler = function() C.CreateFromPrompt() end,
    })
    add({
        type = LHAS.ST_BUTTON,
        label = function() return C.created and ("Add a row to " .. C.created) or "Add a row" end,
        buttonText = "Add",
        tooltip = "Opens the keyboard with an INSERT for the table you just created. Change the values and confirm.",
        disable = function() return not (C.created and E.GetTable(C.created)) end,
        clickHandler = function()
            C.query = C.InsertTemplate(C.created)
            UI.EditQuery()
        end,
    })
    add({
        type = LHAS.ST_BUTTON,
        label = function() return C.created and ("View " .. C.created) or "View table" end,
        buttonText = "View",
        disable = function() return not (C.created and E.GetTable(C.created)) end,
        clickHandler = function()
            C.query = "SELECT * FROM " .. C.created
            run()
        end,
    })

    add({ type = LHAS.ST_SECTION, label = "Results" })
    add({
        type = LHAS.ST_CHECKBOX, label = "Syntax highlighting",
        tooltip = "Colours keywords, functions, table names, text and numbers in the query box and previews.",
        getFunction = function() return UI.HighlightEnabled() end,
        setFunction = function(v) UI.SetHighlight(v); C.Refresh() end,
    })
    add({
        type = LHAS.ST_SLIDER, label = "Text size", min = 6, max = 25, step = 1,
        tooltip = "Size of the text in the results window (10 = normal).",
        getFunction = function() return math.floor((E.sv.uiScale or 1) * 10 + 0.5) end,
        setFunction = function(v) UI.SetScale(v / 10) end,
    })
    add({ type = LHAS.ST_BUTTON, label = "Results window", buttonText = "Show / hide", clickHandler = function() UI.Toggle(); C.Refresh() end })
    add({ type = LHAS.ST_BUTTON, label = "Next rows", buttonText = "Down", clickHandler = function() UI.PageRows(1); C.Refresh() end })
    add({ type = LHAS.ST_BUTTON, label = "Previous rows", buttonText = "Up", clickHandler = function() UI.PageRows(-1); C.Refresh() end })
    add({ type = LHAS.ST_BUTTON, label = "More columns", buttonText = "Right", clickHandler = function() UI.ScrollCols(1); C.Refresh() end })
    add({ type = LHAS.ST_BUTTON, label = "Earlier columns", buttonText = "Left", clickHandler = function() UI.ScrollCols(-1); C.Refresh() end })
    add({
        type = LHAS.ST_BUTTON, label = "Print visible rows to chat", buttonText = "Print",
        clickHandler = function()
            local res = UI.result
            if not res then return end
            for r = UI.rowOffset + 1, math.min(#res.rows, UI.rowOffset + (UI.visibleRows or 10)) do UI.PrintRow(r) end
        end,
    })
    add({
        type = LHAS.ST_EDIT, label = "Export name",
        tooltip = "Name for the saved export (letters, digits and _). Each name is kept separately.",
        getFunction = function() return C.exportName or "export" end,
        setFunction = function(v) C.exportName = v end,
        maxChars = 40, textType = TEXT_TYPE_ALL,
    })
    add({
        type = LHAS.ST_BUTTON, label = "Save last result to SavedVariables", buttonText = "Export",
        tooltip = "Written to SavedVariables/ESQL.lua on logout or /reloadui. On PC, ESQL/tools/esql_to_mysql.py turns your exports and tables into a .sql file for phpMyAdmin.",
        clickHandler = function() E.ExportLast(C.exportName) end,
    })

    add({ type = LHAS.ST_SECTION, label = "Data collection" })
    add({
        type = LHAS.ST_CHECKBOX, label = "Track effects seen",
        tooltip = "Remember every buff/debuff id you see (table effects_seen).",
        getFunction = function() return E.IsEffectTracking() end,
        setFunction = function(v) E.SetEffectTracking(v) end,
    })
    add({
        type = LHAS.ST_CHECKBOX, label = "Record combat log",
        tooltip = "Keep combat events in memory this session (table combat_log).",
        getFunction = function() return E.IsCombatLogging() end,
        setFunction = function(v) E.SetCombatLogging(v) end,
    })
    add({ type = LHAS.ST_BUTTON, label = "Clear combat log", buttonText = "Clear", clickHandler = function() E.ClearCombatLog() end })
    add({
        type = LHAS.ST_BUTTON, label = "Re-index ability ids", buttonText = "Scan",
        tooltip = "Rebuilds the list of every ability id. Runs in the background.",
        clickHandler = function() C.query = "SCAN abilities"; run() end,
    })
    add({
        type = LHAS.ST_BUTTON, label = "Rescan other add-ons' saved data", buttonText = "Scan",
        tooltip = "Finds other add-ons' SavedVariables again and turns their lists into tables (see sv_tables).",
        clickHandler = function() C.query = "SCAN savedvariables"; run() end,
    })
    add({
        type = LHAS.ST_BUTTON, label = "Index item ids", buttonText = "Scan",
        tooltip = "Builds the list of every item id for the items table. Runs in the background.",
        clickHandler = function() C.query = "SCAN items"; run() end,
    })
end
