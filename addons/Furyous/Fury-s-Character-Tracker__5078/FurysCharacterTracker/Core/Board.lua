-- shared
-- The board's rules, with no drawing in them: what each cell says and how it looks, the sort
-- order, the totals row, the line above the columns. The game window (UI/Window.lua) and the
-- offline viewer both draw what this file hands them, so they cannot disagree.
--
-- A column (made in Trackers/*.lua) is a table with:
--   key      unique name; a tab lists its columns by key (Data/Views.lua)
--   title    column title: text, or function() for a title that comes from saved data
--   width    in pixels
--   align    "left" or "center" (the default)
--   head     hover text of the title: what the column is (text or function())
--   value    function(e) -> number or text; also what the column sorts by
--   max      number or function(e): makes it a progress cell, violet when value >= max
--   display  function(value, e) -> the text shown instead of the plain value
--   dim      function(value, e) -> true to show the cell dim
--   gold     function(value, e) -> true to show the cell as maxed
--   warn     function(value, e) -> true to show the cell amber: it wants your attention
--   bar      false: no progress bar behind an in-progress value
--   tip      hover text of a cell: text or function(e)
--   foot     function(entries) -> the text of the bottom row for this column
--   sum      true: the totals row adds the column up (total = function(sum) -> text, optional)
--   pick     { field =, values = }: click for a dropdown of your own picks
--   note     true: click to edit the note
--   icon     function(e) -> texture drawn before the text (game only)
-- `e` is a board entry: { id =, name =, c = saved character, m = your picks }.
local CT = FurysCharacterTracker
local U = CT.Util
local Board = {}
CT.Board = Board

-- Where the last tab and the sort orders are remembered: your saved data in game, a table that
-- lasts until the page is closed in the offline viewer.
local sessionPrefs = { sort = {}, lastView = "overview" }
function CT.Prefs()
    return CT.sv or sessionPrefs
end

function Board.View(id)
    return CT.VIEW_BY_ID[id or CT.Prefs().lastView] or CT.VIEWS[1]
end

function Board.Columns(view)
    return CT.Trackers.Columns(view.columns)
end

function Board.Title(column)
    if type(column.title) == "function" then return column.title() end
    return column.title
end

local function Max(column, e)
    if type(column.max) == "function" then return column.max(e) end
    return column.max
end

-- What one cell shows: { text =, maxed =, dim =, warn =, pick =, pct = (0 to 1, in progress), value = }.
function Board.Cell(column, e)
    local value = column.value(e)
    local max = Max(column, e)
    local isNumber = type(value) == "number"
    local text
    if column.display then text = column.display(value, e) elseif isNumber then text = U.Whole(value) else text = tostring(value) end
    local maxed, dim, pct = false, false, nil
    if isNumber and max then
        if value >= max then
            maxed = true
            if not column.display then text = U.Whole(math.min(value, max)) end
        elseif value <= 0 then
            dim = true
            if not column.display then text = "-" end
        elseif column.bar ~= false then
            pct = value / max
        end
    end
    if column.dim and column.dim(value, e) then dim = true end
    if column.gold and column.gold(value, e) then maxed = true end
    local pick = column.pick ~= nil or column.note == true
    if pick and text == "" then text = "-" end
    if maxed then dim, pct = false, nil end
    local warn = (not maxed) and column.warn ~= nil and column.warn(value, e) == true
    return { text = text, maxed = maxed, dim = dim, warn = warn, pick = pick, pct = pct, value = value }
end

function Board.Tip(column, e)
    if type(column.tip) == "function" then return column.tip(e) end
    return column.tip
end

function Board.HeadTip(column)
    local head = column.head
    if type(head) == "function" then head = head() end
    return (head or Board.Title(column)) .. "\n\n" .. CT.TEXT.SORT_TIP
end

-- Sorting -------------------------------------------------------------------------------------
-- Remembered per tab as { key = column key, desc = }. Nothing remembered = your own row order.

local function SortValue(column)
    return function(e)
        local value = column.value(e)
        if type(value) == "number" then return value end
        return string.lower(tostring(value or ""))
    end
end

function Board.Sort(view)
    local sort = CT.Prefs().sort[view.id]
    local column = sort and sort.key and CT.Trackers.Column(sort.key)
    if not column then return nil end
    return sort, column
end

-- A click on a column title: sort by it, then reversed, then back to your own order.
-- Numbers sort biggest first, names A to Z.
function Board.ClickSort(view, column)
    local sorts = CT.Prefs().sort
    local sort = sorts[view.id]
    if sort and sort.key == column.key then
        if sort.flipped then sorts[view.id] = nil else sort.desc, sort.flipped = not sort.desc, true end
    else
        local first = CT.Roster:List()[1]
        sorts[view.id] = { key = column.key, desc = first ~= nil and type(column.value(first)) == "number" }
    end
end

-- Rows --------------------------------------------------------------------------------------------

-- The characters on a tab, in order, and the ones on the account not read yet (those come last).
function Board.Rows(view)
    local sort, column = Board.Sort(view)
    local entries = CT.Roster:List(column and SortValue(column), sort and sort.desc)
    return entries, CT.Roster:Unread()
end

-- Hover text of a row that has not been read yet.
function Board.UnreadTip(info)
    local who = info.level and string.format("Level %s %s %s  ·  %s", info.level, info.race or "", info.class or "", info.alliance or "") or "On this account"
    return string.format("%s\n%s\n\n%s", info.name, who, CT.TEXT.UNREAD_TIP)
end

-- The bottom row: how many characters have each column maxed, or the sum for plain numbers.
function Board.Totals(view, columns, entries)
    local totals = {}
    for i, column in ipairs(columns) do
        local text = ""
        if i == 1 then
            text = view.totals or "Maxed on"
        elseif column.foot then
            text = column.foot(entries)
        elseif column.sum then
            local sum = 0
            for _, e in ipairs(entries) do sum = sum + (column.value(e) or 0) end
            text = column.total and column.total(sum) or U.Comma(sum)
        elseif column.max then
            local maxed = 0
            for _, e in ipairs(entries) do
                local value, max = column.value(e), Max(column, e)
                if type(value) == "number" and max and value >= max then maxed = maxed + 1 end
            end
            text = U.Of(maxed, #entries)
        end
        totals[i] = text
    end
    return totals
end

-- The line above the columns, and its hover text when it has more to say than fits.
function Board.Summary(view, entries, unread)
    local data = CT.Data()
    local never, count, home = #unread, #entries, CT.IsHome()
    local old = 0
    for _, e in ipairs(entries) do
        if (e.c.v or 1) < CT.READ_VERSION then old = old + 1 end
    end
    local parts = { U.Count(count, "character") }
    if not home and CT.view then
        local saved = (data.account or {}).lastScan
        parts[#parts + 1] = string.format("%s as saved %s", CT.ViewLabel(), saved and U.FormatDate(saved) or "at its last logout")
        if CT.live then parts[#parts + 1] = "log in on that account to update it" end
    end
    if count == 0 and home then parts = { "Nothing read yet. This character is read a few seconds after you log in." } end
    -- New columns of this version stay "-" until a character is read by it.
    if old > 0 then parts[#parts + 1] = string.format("%d last read by an older version: log in on each once to fill the new columns", old) end
    if never > 0 then parts[#parts + 1] = string.format("%d not read yet (the dim rows)%s", never, (home and old == 0) and ": log in on each once" or "") end
    if home and count > 0 and old == 0 and never == 0 then
        parts[#parts + 1] = "every character on this account is here"
        parts[#parts + 1] = "/fct unread lists the out-of-date ones"
    end
    local summary = table.concat(parts, "  ·  ")
    if view.id == "wallet" then
        return CT.WalletSummary(data)
    elseif view.id == "daily" and CT.view then
        local now = GetTimeStamp()
        summary = U.Count(count, "character") .. "  ·  writs reset at " .. os.date("%I:%M %p", CT.Daily.LastReset(CT.view.world, now) + 86400) .. " your time"
        local challenges = CT.ChallengeText(data, now)
        if challenges then summary = summary .. "  ·  " .. challenges end
    elseif view.id == "weekly" then
        summary = U.Count(count, "character") .. "  ·  " .. CT.WeeklySummary(GetTimeStamp())
    elseif view.id == "progress" and count > 0 then
        -- Until some character has a line from an earlier day, every cell is a dash: say why.
        local today, compared = CT.History.Day(GetTimeStamp()), false
        for _, e in ipairs(entries) do
            local since = CT.History.Since(data, e.id)
            if since and since < today then compared = true break end
        end
        if not compared then
            summary = U.Count(count, "character") .. "  ·  nothing to compare yet: one line is saved for each day you play a character, and what it gained shows here from the next day on"
        end
    end
    return summary, nil
end

-- Everything a tab shows, as plain tables: what the offline viewer draws, what "Copy for Discord"
-- writes out, and what the tests compare. `withTips` adds every hover text.
function Board.Snapshot(viewId, withTips)
    local view = Board.View(viewId)
    local columns = Board.Columns(view)
    local entries, unread = Board.Rows(view)
    local sort = Board.Sort(view)
    local snap = { id = view.id, title = view.title, tip = view.tip, live = view.live == true, columns = {}, rows = {}, unread = {},
                   sortKey = sort and sort.key or nil, sortDesc = sort and sort.desc == true or false }
    for i, column in ipairs(columns) do
        snap.columns[i] = { key = column.key, title = Board.Title(column), width = column.width, align = column.align or "center",
                            head = withTips and Board.HeadTip(column) or nil, pick = column.pick and column.pick.field or nil,
                            note = column.note == true }
    end
    for r, e in ipairs(entries) do
        local row = { id = e.id, name = e.name, cells = {} }
        for i, column in ipairs(columns) do
            local cell = Board.Cell(column, e)
            cell.value = nil
            if withTips then cell.tip = Board.Tip(column, e) end
            row.cells[i] = cell
        end
        snap.rows[r] = row
    end
    for r, info in ipairs(unread) do
        snap.unread[r] = { name = info.name, class = info.class or "", tip = Board.UnreadTip(info) }
    end
    snap.totals = Board.Totals(view, columns, entries)
    snap.summary, snap.summaryTip = Board.Summary(view, entries, unread)
    return snap
end
