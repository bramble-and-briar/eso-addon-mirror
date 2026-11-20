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

    add({ type = LHAS.ST_SECTION, label = "Results" })
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
        type = LHAS.ST_BUTTON, label = "Save last result to SavedVariables", buttonText = "Export",
        tooltip = "Written to SavedVariables/ESQL.lua (ESQL_SV ... export) on logout or /reloadui.",
        clickHandler = function() E.ExportLast() end,
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
        type = LHAS.ST_BUTTON, label = "Index item ids", buttonText = "Scan",
        tooltip = "Builds the list of every item id for the items table. Runs in the background.",
        clickHandler = function() C.query = "SCAN items"; run() end,
    })
end
