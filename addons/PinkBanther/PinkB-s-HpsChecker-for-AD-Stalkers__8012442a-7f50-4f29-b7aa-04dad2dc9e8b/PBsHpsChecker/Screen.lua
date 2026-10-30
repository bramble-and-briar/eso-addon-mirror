PBsHpsChecker = PBsHpsChecker or {}
local ADDON = PBsHpsChecker

---------------------------------------------------------------------------------------------------
-- The statistics screen
--
-- A screen of its own, opened from the game's main menu (Menu.lua puts an entry beside PB's Ultra
-- Detailed Stats), in the middle of the screen on an opaque background. Three pages:
--
--   1  Statistics     the summary, the players healed (top 10), the skills (top 10) and the latest ten
--                     fights, over one PERIOD; left and right step to the previous and the next period
--   2  Periods        every period there is -- today, this month, all, past months, past days (as many
--                     as are kept) -- one row each with its amount, HPS, fights and shares; up and down
--                     choose a row, A opens that period on page 1
--   3  Fights         the latest 40 fights, newest first, with their HPS and who they went to
--
-- LB and RB turn the pages, X goes back to today. It takes its input from the keybind strip, like PB's
-- Ultra Detailed Stats does: nothing here is a control that wants input, so nothing takes a button from
-- the game while the screen is not open.
--
-- Everything is built the first time it is shown, a page at a time. The font is the biggest of the named
-- gamepad fonts the console UI has loaded at which the longest rows there can be fit their columns, as
-- the client measures them (ADDON.MeasureText), and the page has room for them.
---------------------------------------------------------------------------------------------------

local records = ADDON.records

local screen = {
    -- The period page 1 shows: "today", "thismonth", "all", a day number or "m<year><month>".
    scope = "today",
    page = 1,
    -- Page 2 and 3: the chosen row, and the first row shown.
    selected = { 0, 1, 1 },
    top = { 0, 1, 1 },
}
ADDON.screen = screen

local NAME = "PBsHpsCheckerScreen"
local PAGES = 3
local ROWS = ADDON.RANKING_ROWS or 10
local PAD = 24
local GAP = 22
local BLOCK_GAP = 24
local LINE_PADDING = 4
-- The room left round the screen: the keybind strip is along the bottom.
local SIDE_MARGIN = 60
local TOP_MARGIN = 40
local BOTTOM_RESERVE = 150
local MAX_WIDTH = 1760
local MAX_HEIGHT = 900
local MIN_TABLE_ROWS = 8
local MAX_PERIOD_DAYS = records.RETAIN_DAYS

local TITLE_FONT = "ZoFontGamepadBold34"
local TAB_FONT = "ZoFontGamepadBold25"
-- Named fonts the console UI already has loaded: no face is built. The biggest tier that fits is used.
local FONT_TIERS = {
    { row = "ZoFontGamepad34", heading = "ZoFontGamepadBold34" },
    { row = "ZoFontGamepad27", heading = "ZoFontGamepadBold27" },
    { row = "ZoFontGamepad25", heading = "ZoFontGamepadBold25" },
    { row = "ZoFontGamepad22", heading = "ZoFontGamepadBold22" },
    { row = "ZoFontGamepad20", heading = "ZoFontGamepadBold20" },
}

local PINK = { 1, 0.41, 0.71 }
local GREY = { 0.62, 0.65, 0.69 }
local WHITE = { 0.95, 0.95, 0.92 }
-- Opaque: the last number is the alpha.
local BACKGROUND = { 0.03, 0.035, 0.07, 1 }

local function L(id)
    return GetString(id)
end

-- The blocks of page 1, left to right, top to bottom.
screen.BLOCKS = {
    { titleId = SI_PBSHPS_BLOCK_SUMMARY, column = 0, row = 0,
      lines = function(scope) return records:SummaryLines(scope) end },
    { titleId = SI_PBSHPS_BLOCK_TARGETS, column = 1, row = 0,
      lines = function(scope) return records:TopLines("targets", scope, ROWS) end },
    { titleId = SI_PBSHPS_BLOCK_SKILLS, column = 0, row = 1,
      lines = function(scope) return records:TopLines("skills", scope, ROWS) end },
    { titleId = SI_PBSHPS_BLOCK_FIGHTS, column = 1, row = 1,
      lines = function() return records:FightLines(ROWS) end },
}

-- The columns of the two lists. `samples` are the longest each can be, to measure; the last column of
-- the list of fights takes whatever width is left.
local function PeriodSamples()
    return {
        string.format(L(SI_PBSHPS_SCOPE_ALL), records.RETAIN_DAYS),
        records:DateText(records:DayKey()),
        records:MonthText(202612),
    }
end

screen.TABLES = {
    [2] = {
        columns = {
            { head = SI_PBSHPS_COL_PERIOD, samples = PeriodSamples },
            { head = SI_PBSHPS_COL_HEAL, right = true, samples = function() return { "999,999,999" } end },
            { head = SI_PBSHPS_COL_HPS, right = true, samples = function() return { "99,999" } end },
            { head = SI_PBSHPS_COL_FIGHTS, right = true, samples = function() return { "999" } end },
            { head = SI_PBSHPS_COL_TIME, right = true, samples = function() return { "99:59:59" } end },
            { head = SI_PBSHPS_COL_PARTY, right = true, samples = function() return { "100.0%" } end },
            { head = SI_PBSHPS_COL_SHARE, right = true, samples = function() return { "100.0%" } end },
        },
    },
    [3] = {
        columns = {
            { head = SI_PBSHPS_COL_WHEN, samples = function() return { "12/31 23:59" } end },
            { head = SI_PBSHPS_COL_LENGTH, right = true, samples = function() return { "9:59:59" } end },
            { head = SI_PBSHPS_COL_HPS, right = true, samples = function() return { "99,999" } end },
            { head = SI_PBSHPS_COL_HEAL, right = true, samples = function() return { "99,999,999" } end },
            { head = SI_PBSHPS_COL_PEOPLE, right = true, samples = function() return { "999" } end },
            { head = SI_PBSHPS_COL_PARTY, right = true, samples = function() return { "100.0%" } end },
            { head = SI_PBSHPS_COL_TOP, flex = true, samples = function() return { "Abcdefghijklmnop(Abcdefghijklmnopqrst)" } end },
        },
    },
}

local PAGE_TITLES = { SI_PBSHPS_PAGE_STATS, SI_PBSHPS_PAGE_PERIODS, SI_PBSHPS_PAGE_FIGHTS }
local PAGE_HINTS = { SI_PBSHPS_HINT_STATS, SI_PBSHPS_HINT_PERIODS, SI_PBSHPS_HINT_FIGHTS }

---------------------------------------------------------------------------------------------------
-- Measuring and laying out
---------------------------------------------------------------------------------------------------

-- How wide a text is in a font. A client that does not say gets an estimate, which only has to be in
-- the right region: there the layout cannot be checked anyway.
local function Width(font, text)
    local width = ADDON.MeasureText(font, text)
    if width then
        return width
    end
    return #text * ADDON.MeasureFont(font) * 0.55
end

local function Clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

function screen:Size()
    local width = math.floor(math.min(MAX_WIDTH, GuiRoot:GetWidth() - SIDE_MARGIN * 2))
    local height = math.floor(math.min(MAX_HEIGHT, GuiRoot:GetHeight() - BOTTOM_RESERVE - TOP_MARGIN))
    return math.max(640, width), math.max(480, height)
end

-- Heights and places for a font tier on a screen of this size.
function screen:Metrics(tier, width, height)
    local m = {}
    m.rowHeight = ADDON.MeasureFont(tier.row) + LINE_PADDING
    m.headHeight = ADDON.MeasureFont(tier.heading) + LINE_PADDING
    m.titleHeight = ADDON.MeasureFont(TITLE_FONT) + LINE_PADDING
    local y = PAD
    m.titleY = y
    y = y + m.titleHeight + 2
    m.subY = y
    y = y + m.rowHeight + 6
    m.lineY = y
    y = y + 2 + 10
    m.contentY = y
    m.hintY = height - PAD - m.rowHeight
    m.contentHeight = m.hintY - 8 - m.contentY
    m.columnWidth = math.floor((width - PAD * 3) / 2)
    m.blockHeight = m.headHeight + ROWS * m.rowHeight
    m.tableRows = math.floor((m.contentHeight - m.headHeight) / m.rowHeight)
    return m
end

-- The width of every column of a list, or nil when the last column would be left too little.
function screen:ColumnWidths(spec, tier, width)
    local available = width - PAD * 2
    local widths, used, flexIndex, flexNeed = {}, 0, nil, 0
    for index, column in ipairs(spec.columns) do
        local need = Width(tier.heading, L(column.head))
        for _, sample in ipairs(column.samples()) do
            need = math.max(need, Width(tier.row, sample))
        end
        need = math.ceil(need)
        if column.flex then
            flexIndex, flexNeed = index, need
        else
            widths[index] = need + GAP
            used = used + widths[index]
        end
    end
    if flexIndex then
        widths[flexIndex] = available - used
        if widths[flexIndex] < flexNeed then
            return nil
        end
    elseif used > available then
        return nil
    end
    return widths
end

-- Whether a tier has the room: the four blocks of page 1 in their columns, and both lists across the
-- screen with at least MIN_TABLE_ROWS rows. A client that does not measure text answers fits.
function screen:FitsTier(tier, width, height)
    local m = self:Metrics(tier, width, height)
    if m.blockHeight * 2 + BLOCK_GAP > m.contentHeight or m.tableRows < MIN_TABLE_ROWS then
        return false, m
    end
    for _, line in ipairs(records:WorstCaseLines()) do
        if Width(tier.row, line) > m.columnWidth then
            return false, m
        end
    end
    for _, block in ipairs(self.BLOCKS) do
        if Width(tier.heading, L(block.titleId)) > m.columnWidth then
            return false, m
        end
    end
    for _, spec in pairs(self.TABLES) do
        if not self:ColumnWidths(spec, tier, width) then
            return false, m
        end
    end
    return true, m
end

---------------------------------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------------------------------

local function Label(parent, suffix, font, width, height)
    local label = WINDOW_MANAGER:CreateControl(NAME .. suffix, parent, CT_LABEL)
    label:SetFont(font)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetMaxLineCount(1)
    label:SetDimensions(width, height)
    return label
end

local function Place(control, parent, x, y)
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
end

local function Color(control, color)
    control:SetColor(color[1], color[2], color[3], 1)
end

function screen:Build()
    if self.root then
        return true
    end
    if not WINDOW_MANAGER or not GuiRoot then
        return false
    end

    local width, height = self:Size()
    local chosen, metrics
    for _, tier in ipairs(FONT_TIERS) do
        local fits, m = self:FitsTier(tier, width, height)
        chosen, metrics = tier, m
        if fits then
            break
        end
    end
    self.tier, self.m, self.width, self.height = chosen, metrics, width, height
    local m, tier = metrics, chosen

    local root = WINDOW_MANAGER:CreateTopLevelWindow(NAME)
    root:SetHidden(true)
    root:SetMouseEnabled(false)
    root:SetDimensions(width, height)
    -- In the middle of what the keybind strip leaves.
    root:SetAnchor(CENTER, GuiRoot, CENTER, 0, math.floor((TOP_MARGIN - BOTTOM_RESERVE) / 2))
    self.root = root

    local fill = WINDOW_MANAGER:CreateControl(NAME .. "Fill", root, CT_TEXTURE)
    fill:SetColor(BACKGROUND[1], BACKGROUND[2], BACKGROUND[3], BACKGROUND[4])
    fill:SetAnchorFill(root)
    self.fill = fill

    self.title = Label(root, "Title", TITLE_FONT, width - PAD * 2, m.titleHeight)
    Place(self.title, root, PAD, m.titleY)
    Color(self.title, PINK)
    self.title:SetText(ADDON.title)

    -- The page names, along the right of the title row; the current one is pink.
    self.tabs = {}
    local right = PAD
    for page = PAGES, 1, -1 do
        local text = L(PAGE_TITLES[page])
        local tabWidth = math.ceil(Width(TAB_FONT, text)) + 8
        local tab = Label(root, "Tab" .. page, TAB_FONT, tabWidth, m.titleHeight)
        tab:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        tab:ClearAnchors()
        tab:SetAnchor(TOPRIGHT, root, TOPRIGHT, -right, m.titleY + 4)
        tab:SetText(text)
        self.tabs[page] = tab
        right = right + tabWidth + 26
    end

    self.sub = Label(root, "Sub", tier.row, width - PAD * 2, m.rowHeight)
    Place(self.sub, root, PAD, m.subY)
    Color(self.sub, WHITE)

    local line = WINDOW_MANAGER:CreateControl(NAME .. "Line", root, CT_TEXTURE)
    line:SetColor(PINK[1], PINK[2], PINK[3], 0.8)
    line:SetDimensions(width - PAD * 2, 2)
    Place(line, root, PAD, m.lineY)

    self.hint = Label(root, "Hint", tier.row, width - PAD * 2, m.rowHeight)
    Place(self.hint, root, PAD, m.hintY)
    Color(self.hint, GREY)

    -- One list of controls per page, shown and hidden together. A page is built the first time it is
    -- wanted.
    self.pageControls = { {}, {}, {} }
    self.built = {}
    return true
end

function screen:BuildStatsPage()
    local m, tier, root = self.m, self.tier, self.root
    self.blocks = {}
    local controls = self.pageControls[1]
    for index, block in ipairs(self.BLOCKS) do
        local x = PAD + block.column * (m.columnWidth + PAD)
        local y = m.contentY + block.row * (m.blockHeight + BLOCK_GAP)
        local heading = Label(root, "Heading" .. index, tier.heading, m.columnWidth, m.headHeight)
        Place(heading, root, x, y)
        Color(heading, PINK)
        heading:SetText(L(block.titleId))
        controls[#controls + 1] = heading
        local rows = {}
        for row = 1, ROWS do
            local label = Label(root, "Block" .. index .. "Row" .. row, tier.row, m.columnWidth, m.rowHeight)
            Place(label, root, x, y + m.headHeight + (row - 1) * m.rowHeight)
            Color(label, WHITE)
            rows[row] = label
            controls[#controls + 1] = label
        end
        self.blocks[index] = { heading = heading, rows = rows, lines = block.lines }
    end
end

function screen:BuildTable(page)
    local m, tier, root = self.m, self.tier, self.root
    local spec = self.TABLES[page]
    local widths = self:ColumnWidths(spec, tier, self.width) or {}
    local controls = self.pageControls[page]
    local view = { widths = widths, xs = {}, rows = {}, heads = {} }

    local x = PAD
    for index, column in ipairs(spec.columns) do
        -- The last column of a list may be left no room at all on a very small screen.
        widths[index] = widths[index] or 80
        view.xs[index] = x
        x = x + widths[index]
    end

    -- A bar behind the chosen row, moved from row to row.
    local bar = WINDOW_MANAGER:CreateControl(NAME .. "Bar" .. page, root, CT_TEXTURE)
    bar:SetColor(PINK[1], PINK[2], PINK[3], 0.28)
    bar:SetDimensions(self.width - PAD * 2, m.rowHeight)
    Place(bar, root, PAD, m.contentY + m.headHeight)
    controls[#controls + 1] = bar
    view.bar = bar

    for index, column in ipairs(spec.columns) do
        local head = Label(root, "Table" .. page .. "Head" .. index, tier.heading, widths[index] - (column.flex and 0 or GAP), m.headHeight)
        Place(head, root, view.xs[index], m.contentY)
        Color(head, GREY)
        head:SetText(L(column.head))
        if column.right then
            head:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        end
        controls[#controls + 1] = head
        view.heads[index] = head
    end
    for row = 1, m.tableRows do
        local cells = {}
        for index, column in ipairs(spec.columns) do
            local cell = Label(root, "Table" .. page .. "Row" .. row .. "Col" .. index, tier.row, widths[index] - (column.flex and 0 or GAP), m.rowHeight)
            Place(cell, root, view.xs[index], m.contentY + m.headHeight + (row - 1) * m.rowHeight)
            Color(cell, WHITE)
            if column.right then
                cell:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
            end
            cells[index] = cell
            controls[#controls + 1] = cell
        end
        view.rows[row] = cells
    end
    self.tables = self.tables or {}
    self.tables[page] = view
end

function screen:EnsurePage(page)
    if self.built[page] then
        return
    end
    self.built[page] = true
    if page == 1 then
        self:BuildStatsPage()
    else
        self:BuildTable(page)
    end
end

---------------------------------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------------------------------

function screen:ShowPage()
    self:EnsurePage(self.page)
    if self.shownPage == self.page then
        return
    end
    self.shownPage = self.page
    for page = 1, PAGES do
        for _, control in ipairs(self.pageControls[page]) do
            control:SetHidden(page ~= self.page)
        end
    end
end

-- Where the chosen period is among the periods, and how many there are.
function screen:PeriodIndex()
    local list = records:ScopeList(MAX_PERIOD_DAYS)
    for index, token in ipairs(list) do
        if tostring(token) == tostring(self.scope) then
            return index, #list, list
        end
    end
    return 0, #list, list
end

function screen:DrawStats()
    for _, block in ipairs(self.blocks) do
        local lines = block.lines(self.scope)
        for row = 1, ROWS do
            local text = lines[row]
            block.rows[row]:SetText(text or "")
            block.rows[row]:SetHidden(text == nil)
        end
    end
    local index, count = self:PeriodIndex()
    local text = records:ScopeText(self.scope)
    self.sub:SetText(index > 0 and string.format(L(SI_PBSHPS_SCREEN_PERIOD), text, index, count) or text)
end

-- Fills a list's rows from `columnsFor(i)`, i counting from 1; keeps the chosen row in view.
function screen:DrawTable(page, count, columnsFor)
    local view = self.tables[page]
    local rows = #view.rows
    local selected = Clamp(self.selected[page], 1, math.max(1, count))
    self.selected[page] = selected
    local top = self.top[page]
    if selected < top then
        top = selected
    elseif selected > top + rows - 1 then
        top = selected - rows + 1
    end
    top = Clamp(top, 1, math.max(1, count - rows + 1))
    self.top[page] = top

    for row = 1, rows do
        local columns = columnsFor(top + row - 1)
        for index, cell in ipairs(view.rows[row]) do
            cell:SetText(columns and columns[index] or "")
            cell:SetHidden(columns == nil)
        end
    end
    if count == 0 then
        local first = view.rows[1] and view.rows[1][1]
        if first then
            first:SetText(L(SI_PBSHPS_NONE))
            first:SetHidden(false)
        end
    end
    view.bar:SetHidden(count == 0)
    view.bar:ClearAnchors()
    view.bar:SetAnchor(TOPLEFT, self.root, TOPLEFT, PAD, self.m.contentY + self.m.headHeight + (selected - top) * self.m.rowHeight)
end

function screen:DrawPeriods()
    local _, count, list = self:PeriodIndex()
    self:DrawTable(2, count, function(index)
        return list[index] and records:PeriodColumns(list[index]) or nil
    end)
    self.sub:SetText(string.format(L(SI_PBSHPS_SCREEN_PERIODS), count))
end

function screen:DrawFights()
    local count = records:FightCount()
    self:DrawTable(3, count, function(index)
        return records:FightColumns(index)
    end)
    self.sub:SetText(string.format(L(SI_PBSHPS_SCREEN_FIGHTS), count))
end

-- Draws the page that is up. Cheap enough to run every couple of seconds while the screen is open.
function screen:Refresh()
    if not (self.root or self:Build()) then
        return
    end
    self:ShowPage()
    for page, tab in ipairs(self.tabs) do
        Color(tab, page == self.page and PINK or GREY)
    end
    if self.page == 1 then
        self:DrawStats()
    elseif self.page == 2 then
        self:DrawPeriods()
    else
        self:DrawFights()
    end
    self.hint:SetText(L(PAGE_HINTS[self.page]))
end

---------------------------------------------------------------------------------------------------
-- Moving about
---------------------------------------------------------------------------------------------------

function screen:PageChanged()
    if self.onPageChanged then
        self.onPageChanged()
    end
    self:Refresh()
end

function screen:MovePage(delta)
    local page = Clamp(self.page + delta, 1, PAGES)
    if page ~= self.page then
        self.page = page
        self:PageChanged()
    end
end

-- Page 1: the previous (-1) or the next (1) period in the list of periods.
function screen:MovePeriod(delta)
    if self.page ~= 1 then
        return
    end
    local index, count, list = self:PeriodIndex()
    if count == 0 then
        return
    end
    self.scope = list[Clamp((index > 0 and index or 1) + delta, 1, count)]
    self:Refresh()
end

-- Pages 2 and 3: the chosen row up (-1) or down (1).
function screen:MoveRow(delta)
    if self.page == 1 then
        return
    end
    self.selected[self.page] = self.selected[self.page] + delta
    self:Refresh()
end

-- A on page 2: show the chosen period on page 1.
function screen:Activate()
    if self.page ~= 2 then
        return
    end
    local _, count, list = self:PeriodIndex()
    local token = list[Clamp(self.selected[2], 1, math.max(1, count))]
    if token ~= nil then
        self.scope = token
        self.page = 1
        self:PageChanged()
    end
end

function screen:GoToday()
    self.scope = "today"
    self.page = 1
    self:PageChanged()
end

-- Opens on this period (a command's, or the settings'); the screen itself is Menu.lua's.
function screen:SetScope(scope)
    self.scope = scope or "today"
    self.page = 1
    if self.root then
        self:Refresh()
    end
end

-- The keybind group for the strip: back, A on the list of periods, today, the pages (shown), and
-- the arrows (not shown: the hint line at the bottom of the screen says what they do).
function screen:Keybinds()
    local group = { alignment = KEYBIND_STRIP_ALIGN_LEFT }
    local function bind(keybind, name, callback, ethereal, visible)
        group[#group + 1] = { keybind = keybind, name = name, callback = callback, ethereal = ethereal, visible = visible }
    end
    bind("UI_SHORTCUT_NEGATIVE", L(SI_PBSHPS_KEY_BACK), function() SCENE_MANAGER:HideCurrentScene() end)
    bind("UI_SHORTCUT_PRIMARY", L(SI_PBSHPS_KEY_OPEN), function() self:Activate() end, false, function() return self.page == 2 end)
    bind("UI_SHORTCUT_SECONDARY", L(SI_PBSHPS_KEY_TODAY), function() self:GoToday() end)
    bind("UI_SHORTCUT_LEFT_SHOULDER", L(SI_PBSHPS_KEY_PREV_PAGE), function() self:MovePage(-1) end)
    bind("UI_SHORTCUT_RIGHT_SHOULDER", L(SI_PBSHPS_KEY_NEXT_PAGE), function() self:MovePage(1) end)
    bind("UI_SHORTCUT_INPUT_LEFT", L(SI_PBSHPS_KEY_PREV_PERIOD), function() self:MovePeriod(-1) end, true)
    bind("UI_SHORTCUT_INPUT_RIGHT", L(SI_PBSHPS_KEY_NEXT_PERIOD), function() self:MovePeriod(1) end, true)
    bind("UI_SHORTCUT_INPUT_UP", L(SI_PBSHPS_KEY_PREV_ROW), function() self:MoveRow(-1) end, true)
    bind("UI_SHORTCUT_INPUT_DOWN", L(SI_PBSHPS_KEY_NEXT_ROW), function() self:MoveRow(1) end, true)
    return group
end
