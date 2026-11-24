-- One window, one tab per module. A module registers a tab with:
--   GT.Report:RegisterTab({
--       id = "bank",
--       title = function() return "Bank (3)" end,     -- string or function
--       tip = "What this tab shows",                   -- optional hover text for the tab button
--       GetSummary = function() return "..." end,      -- optional line under the tabs
--       GetOffText = function() return GT:FeatureOffText(on, "Name") end,  -- optional: shown while the feature is off
--       GetRows = function() return { { text=, tooltip=, actions={ {label=, fn=}, ... } } } end,
--       footer = { { label = "Dismiss all", tip = "Hover text", fn = function() end }, ... },  -- optional
--       searchable = true,                             -- optional: shows the search box, tab.searchText holds it
--       topBar = control or function,                  -- optional (1.23.0): controls in the title row, shown only on this tab
--       UpdateTopBar = function() end,                 -- optional: refreshes them (may hide them)
--       GetExportLines = function() return { "header", "row", ... } end,  -- optional: adds an Export button
--   })
-- Rows can have up to six action buttons ({ label =, tip =, fn = }). Every button
-- (tabs, footer, row actions, column headers) shows its tip on hover.
-- A tab can instead show aligned columns with clickable (sortable) headers:
--       columns = { { title = "Member", width = 200, sort = "name", tip = "optional" }, ... },  -- up to 8
--       sortKey = function() return "name", false end,   -- current sort key, descending?
--       OnSort = function(key) end,                       -- header clicked
--   and its rows return cells = { "text", ... } instead of text, plus up to four actions
--   (buttons on the right, 86 px each; leave that much room after the columns).
-- Any row can set OnRightClick = function(control) end for a right-click menu.
-- Report.AddMenu(row, items) gives a row a menu of all its actions (see below).

local GT = FurysGuildToolset
local Report = {}
GT.Report = Report

local ROW_TYPE = 1
local COLUMN_ROW_TYPE = 2
local MAX_COLUMNS = 8
local COLUMN_GAP = 8
local ROW_HEIGHT = 32
local MAX_FOOTER_BUTTONS = 7   -- 1.15.0: 7 for the Events tab (its buttons are narrower)
local EXPORT_PART_CHARS = 20000
-- The copy window's hint for CSV exports; Copy for Discord sets its own (Report.exportHint).
local EXPORT_HINT = "CSV, one line per row. Select all, Ctrl+C, then in Excel: Data > Text to Columns > Comma."

Report.tabs = {}
Report.tabButtons = {}
Report.footerButtons = {}

local function Resolve(value)
    if type(value) == "function" then return value() end
    return value
end

-- Hover text --------------------------------------------------------------------

function Report.ShowTip(control, text)
    if not text or text == "" then return end
    ClearTooltip(InformationTooltip)
    InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -4, TOP)
    SetTooltipText(InformationTooltip, text)
end

function Report.HideTip()
    ClearTooltip(InformationTooltip)
end

-- Gives a control hover text. tip can be a string, a function, or nil for none.
-- Pooled controls are reused, so the handlers read the tip stored on the control.
function Report.SetTip(control, tip)
    control.furyTip = tip
    if not control.furyTipHooked then
        control.furyTipHooked = true
        control:SetHandler("OnMouseEnter", function(self) Report.ShowTip(self, Resolve(self.furyTip)) end)
        control:SetHandler("OnMouseExit", Report.HideTip)
    end
end

-- Row menus ---------------------------------------------------------------------
-- Rows have no buttons: every action for a row lives in its right-click menu, and the line at
-- the top of the tab says so. items = { { label =, fn = function(control) end,
-- opensMenu = true if fn shows a menu of its own }, ... }
Report.MENU_HINT = "Right-click a row for options."

function Report.AddMenu(row, items)
    if #items == 0 then return row end
    row.tooltip = (row.tooltip and (row.tooltip .. "\n") or "") .. "|cB4B0D8Right-click for options.|r"
    row.OnRightClick = function(control)
        ClearMenu()
        for _, item in ipairs(items) do
            AddMenuItem(item.label, function()
                -- A menu can't open while this one is closing, so wait a moment.
                if item.opensMenu then
                    zo_callLater(function() item.fn(control) end, 50)
                else
                    item.fn(control)
                end
            end)
        end
        ShowMenu(control)
    end
    return row
end

-- Whisper and Mail items for a menu. Nothing is sent until you press Enter or Send.
function Report.ContactItems(displayName)
    if not displayName or displayName == "" or displayName == GetDisplayName() then return {} end
    return {
        { label = "Whisper " .. displayName, tip = "Starts a whisper to them in the chat box.", fn = function() GT.Actions.Warn(displayName, "", "", "whisper") end },
        { label = "Mail " .. displayName, tip = "Opens an empty mail to them.", fn = function() GT.Actions.Warn(displayName, "", "", "mail") end },
        Report.CopyItem(displayName),
    }
end

-- "Copy @name" for a right-click menu (1.14.0).
function Report.CopyItem(text)
    return { label = "Copy " .. text, tip = "Shows the name selected in a small window. Press Ctrl+C to copy it.", fn = function() Report:ShowCopy(text) end }
end

-- Addons can't write to the clipboard: the text goes in the export window, selected, and the
-- player presses Ctrl+C.
function Report:ShowCopy(text)
    self.exportParts = { text }
    self.exportIndex = 1
    self.exportTitle = "Copy"
    self.exportHint = nil
    GT.Util.ShowOnTop(FurysGuildToolset_Export)
    self:ShowExportPart(0)
    FurysGuildToolset_ExportTextBox:TakeFocus()
    FurysGuildToolset_ExportTextBox:SelectAll()
    GT.Util.Print("%s is selected. Press Ctrl+C to copy it.", text)
end

function Report:RegisterTab(def)
    table.insert(self.tabs, def)
end

function Report:GetTab(id)
    for _, tab in ipairs(self.tabs) do
        if tab.id == id then return tab end
    end
end

function Report:Initialize()
    self.control = FurysGuildToolset_Report
    self.list = FurysGuildToolset_ReportList
    self.summary = FurysGuildToolset_ReportSummary
    self.search = FurysGuildToolset_ReportSearch
    self.searchBox = FurysGuildToolset_ReportSearchBox
    FurysGuildToolset_ReportVersion:SetText("v" .. GT.version)
    -- Fury Night look for every window (colors and fonts are set here, not in the XML).
    local T = GT.Theme
    T.Window(FurysGuildToolset_Report, { bg = "BG" })
    T.Window(FurysGuildToolset_Export, { bg = "BG" })
    T.Window(FurysGuildToolset_EventsInput, { bg = "BG" })
    T.Window(FurysGuildToolset_AutoAlert, { bg = "BG", plain = true, font = "$(ANTIQUE_FONT)|34|soft-shadow-thick" })
    T.Window(FurysGuildToolset_RemoveDialog, { bg = "BG", plain = true })
    T.Window(FurysGuildToolset_RecruitBar, { bg = "BG", title = "Text", plain = true, font = "ZoFontGameSmall" })
    -- Search box: lighter than the window, violet edge, bright text, so it's easy to find.
    -- It sits in the title bar, so it has to draw above the theme's title glow (DL_BACKGROUND),
    -- which otherwise covers it. Solid black with a violet edge and bright text (Albert).
    self.search:SetDrawLayer(DL_CONTROLS)
    self.search:SetDrawLevel(1)
    self.searchBox:SetDrawLayer(DL_CONTROLS)
    self.searchBox:SetDrawLevel(2)
    FurysGuildToolset_ReportSearchClear:SetDrawLayer(DL_CONTROLS)
    FurysGuildToolset_ReportSearchClear:SetDrawLevel(3)
    self.search:SetCenterColor(0, 0, 0, 1)
    self.search:SetEdgeColor(T.VIOLET:UnpackRGBA())
    T.Paint(self.searchBox, T.TEXT)
    FurysGuildToolset_ExportTextBox:SetMaxInputChars(EXPORT_PART_CHARS + 2000)
    -- Without these the edit box drops line breaks and everything runs together.
    FurysGuildToolset_ExportTextBox:SetMultiLine(true)
    FurysGuildToolset_ExportTextBox:SetNewLineEnabled(true)
    -- Registering with the scene manager makes Esc close these windows
    -- and handles the mouse cursor for us.
    SCENE_MANAGER:RegisterTopLevel(FurysGuildToolset_Report, false)
    SCENE_MANAGER:RegisterTopLevel(FurysGuildToolset_Export, false)
    FurysGuildToolset_Report:SetHandler("OnHide", function()
        ClearTooltip(InformationTooltip)
        if self.panelTab then self.panelTab.SetPanelShown(false); self.panelTab = nil end
    end)

    ZO_ScrollList_AddDataType(self.list, ROW_TYPE, "FurysGuildToolset_ReportRow", ROW_HEIGHT, function(control, data)
        self:SetupRow(control, data)
    end)
    ZO_ScrollList_AddDataType(self.list, COLUMN_ROW_TYPE, "FurysGuildToolset_ReportColumnRow", 28, function(control, data)
        self:SetupColumnRow(control, data)
    end)
    -- Hide a row's hover text as soon as the list scrolls. Left anchored to a row that is moving
    -- (or being reused for another line), the tooltip could trip the game's
    -- "Too many anchors processed" error. Hovering the row again shows it.
    ZO_PostHookHandler(self.list.scrollbar, "OnValueChanged", function()
        ClearTooltip(InformationTooltip)
        if self.hoverRow then
            self.hoverRow:GetNamedChild("Highlight"):SetHidden(true)
            self.hoverRow = nil
        end
    end)

    -- Column headers: clickable labels, created once and reused by every column tab.
    self.header = FurysGuildToolset_ReportHeader
    self.headerLabels = {}
    for i = 1, MAX_COLUMNS do
        local label = WINDOW_MANAGER:CreateControl("FurysGuildToolset_ReportHeaderCol" .. i, self.header, CT_LABEL)
        label:SetFont(GT.Theme.FONT_HEADER)
        GT.Theme.Paint(label, GT.Theme.BLUE)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        label:SetMouseEnabled(true)
        label:SetHidden(true)
        self.headerLabels[i] = label
    end

    -- Tab order: these first, then the rest in the order their modules load.
    local FIRST = { crier = 1, members = 2, inactive = 3 }
    for i, tab in ipairs(self.tabs) do tab.loadOrder = i end
    table.sort(self.tabs, function(a, b)
        local fa, fb = FIRST[a.id] or 100, FIRST[b.id] or 100
        if fa ~= fb then return fa < fb end
        return a.loadOrder < b.loadOrder
    end)

    -- 1.6.4: more than 9 tabs go on two rows, so the titles fit (the window grows by one row).
    local rows = #self.tabs > 9 and 2 or 1
    local perRow = math.ceil(#self.tabs / rows)
    local width = math.min(180, math.floor((1160 - 4 * (perRow - 1)) / perRow))
    FurysGuildToolset_ReportTabs:SetHeight(32 * rows)
    if rows > 1 then FurysGuildToolset_Report:SetHeight(600 + 32 * (rows - 1)) end
    local previous
    for i, tab in ipairs(self.tabs) do
        local button = WINDOW_MANAGER:CreateControlFromVirtual("FurysGuildToolset_ReportTab" .. i, FurysGuildToolset_ReportTabs, "ZO_DefaultButton")
        button:SetDimensions(width, 28)
        if (i - 1) % perRow ~= 0 then
            button:SetAnchor(TOPLEFT, previous, TOPRIGHT, 4, 0)
        else
            button:SetAnchor(TOPLEFT, FurysGuildToolset_ReportTabs, TOPLEFT, 0, 2 + 32 * math.floor((i - 1) / perRow))
        end
        button:SetHandler("OnClicked", function() self:SelectTab(tab.id) end)
        Report.SetTip(button, function() return Resolve(tab.tip) end)
        self.tabButtons[i] = button
        previous = button
    end

    previous = nil
    for i = 1, MAX_FOOTER_BUTTONS do
        local button = WINDOW_MANAGER:CreateControlFromVirtual("FurysGuildToolset_ReportFooter" .. i, FurysGuildToolset_ReportFooter, "ZO_DefaultButton")
        button:SetDimensions(180, 28)   -- 1.7.0: wider, for labels like "Winners for Discord"
        if previous then
            button:SetAnchor(LEFT, previous, RIGHT, 6, 0)
        else
            button:SetAnchor(LEFT, FurysGuildToolset_ReportFooter, LEFT, 0, 0)
        end
        button:SetHidden(true)
        self.footerButtons[i] = button
        previous = button
    end

    local pos = GT.sv.window
    if pos then
        self.control:ClearAnchors()
        self.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
    end

    -- Reopen on the tab you last used.
    self.currentTab = (GT.sv.lastTab and self:GetTab(GT.sv.lastTab)) and GT.sv.lastTab or (self.tabs[1] and self.tabs[1].id)
end

function Report.SavePosition()
    local control = FurysGuildToolset_Report
    GT.sv.window = { x = control:GetLeft(), y = control:GetTop() }
end

-- Fury Night row fills: every other row striped, the row you right-clicked stays lit.
function Report:PaintRow(control, data)
    control:GetNamedChild("Stripe"):SetHidden(data.furyStripe ~= true)
    control:GetNamedChild("Selected"):SetHidden(data ~= self.selectedData)
end

function Report:SetupRow(control, data)
    self:PaintRow(control, data)
    local label = control:GetNamedChild("Text")
    label:SetText(data.text or "")
    -- The text gets whatever width the buttons leave (86 px per button); rows without
    -- buttons (Members, History) get the full width.
    local buttons = data.actions and #data.actions or 0
    label:SetWidth(buttons > 0 and (1144 - buttons * 86) or 1140)
    for i = 1, 6 do
        local button = control:GetNamedChild("Action" .. i)
        local action = data.actions and data.actions[i]
        if action then
            button:SetText(action.label)
            button:SetHandler("OnClicked", function(control) action.fn(control) end)
            Report.SetTip(button, action.tip)
            button:SetHidden(false)
        else
            button:SetHandler("OnClicked", nil)
            Report.SetTip(button, nil)
            button:SetHidden(true)
        end
    end
end

-- Lays the column labels out left to right using the widths in data.columns.
function Report:SetupColumnRow(control, data)
    self:PaintRow(control, data)
    local x = 6
    for i = 1, MAX_COLUMNS do
        local label = control:GetNamedChild("Col" .. i)
        local column = data.columns[i]
        if column then
            label:ClearAnchors()
            label:SetAnchor(LEFT, control, LEFT, x, 0)
            label:SetDimensions(column.width, 28)
            label:SetText(data.cells[i] or "")
            label:SetHidden(false)
            x = x + column.width + COLUMN_GAP
        else
            label:SetHidden(true)
        end
    end
    -- Buttons fill from the right: with three actions, Action2..Action4 are used.
    local actions = data.actions or {}
    local offset = 4 - #actions
    for i = 1, 4 do
        local button = control:GetNamedChild("Action" .. i)
        local action = actions[i - offset]
        if action then
            button:SetText(action.label)
            button:SetHandler("OnClicked", function(clicked) action.fn(clicked) end)
            Report.SetTip(button, action.tip)
            button:SetHidden(false)
        else
            button:SetHandler("OnClicked", nil)
            Report.SetTip(button, nil)
            button:SetHidden(true)
        end
    end
end

function Report:LayoutHeader(tab, columns)
    local key, descending = nil, false
    if tab.sortKey then key, descending = tab.sortKey() end
    local x = 6
    for i, label in ipairs(self.headerLabels) do
        local column = columns and columns[i]
        if column then
            local arrow = (column.sort and column.sort == key) and (descending and " v" or " ^") or ""
            label:ClearAnchors()
            label:SetAnchor(LEFT, self.header, LEFT, x, 0)
            label:SetDimensions(column.width, 24)
            label:SetText(column.title .. arrow)
            label:SetHandler("OnMouseUp", function(_, button, upInside)
                if upInside and column.sort and tab.OnSort then
                    tab.OnSort(column.sort)
                    self:Refresh()
                end
            end)
            local sortTip = (column.sort and tab.OnSort)
                and ("Click to sort by " .. column.title:lower() .. ". Click again to reverse the order.") or nil
            Report.SetTip(label, column.tip and (sortTip and (column.tip .. "\n" .. sortTip) or column.tip) or sortTip)
            label:SetHidden(false)
            x = x + column.width + COLUMN_GAP
        else
            label:SetHidden(true)
        end
    end
end

function Report.OnRowMouseEnter(control)
    control:GetNamedChild("Highlight"):SetHidden(false)
    Report.hoverRow = control
    ClearTooltip(InformationTooltip)
    local data = ZO_ScrollList_GetData(control)
    if data and data.tooltip then
        -- Anchored to the list (which never moves) at the row's current height, not to the
        -- row itself: rows move and get reused while the list scrolls, and a tooltip tied
        -- to one could trip the game's "Too many anchors processed" error.
        local list = Report.list
        InitializeTooltip(InformationTooltip, list, BOTTOM, 0, control:GetTop() - list:GetTop() - 4, TOP)
        SetTooltipText(InformationTooltip, data.tooltip)
    end
end

-- Rows can offer a right-click menu with data.OnRightClick(control).
function Report.OnRowMouseUp(control, button, upInside)
    if not upInside or button ~= MOUSE_BUTTON_INDEX_RIGHT then return end
    local data = ZO_ScrollList_GetData(control)
    if data and data.OnRightClick then
        ClearTooltip(InformationTooltip)
        Report.selectedData = data
        ZO_ScrollList_RefreshVisible(Report.list)
        data.OnRightClick(control)
    end
end

function Report.OnRowMouseExit(control)
    control:GetNamedChild("Highlight"):SetHidden(true)
    if Report.hoverRow == control then Report.hoverRow = nil end
    ClearTooltip(InformationTooltip)
end

function Report:SelectTab(id)
    self.currentTab = id
    GT.sv.lastTab = id
    self.selectedData = nil
    self:Refresh()
end

function Report:Refresh()
    if not self.control or self.control:IsHidden() then return end

    for i, tab in ipairs(self.tabs) do
        local button = self.tabButtons[i]
        button:SetText(Resolve(tab.title))
        button:SetEnabled(tab.id ~= self.currentTab)
    end

    local tab = self:GetTab(self.currentTab)
    if not tab then return end

    -- A tab can show its own panel (the Crier menu) instead of the row list.
    if self.panelTab and self.panelTab ~= tab then
        self.panelTab.SetPanelShown(false)
        self.panelTab = nil
    end
    local usesPanel = tab.SetPanelShown and tab.SetPanelShown(true, self.list) or false
    if usesPanel then self.panelTab = tab end
    self.list:SetHidden(usesPanel)

    local rows = usesPanel and {} or (tab.GetRows() or {})
    local columns = (not usesPanel) and Resolve(tab.columns) or nil
    self.header:SetHidden(columns == nil)
    self.list:ClearAnchors()
    self.list:SetAnchor(TOPLEFT, columns and self.header or self.summary, BOTTOMLEFT, 0, columns and 2 or 6)
    self.list:SetAnchor(BOTTOMRIGHT, self.control, BOTTOMRIGHT, -16, -56)
    if columns then self:LayoutHeader(tab, columns) end
    ZO_ScrollList_Clear(self.list)
    local dataList = ZO_ScrollList_GetDataList(self.list)
    for i, row in ipairs(rows) do
        row.furyStripe = (i % 2 == 0)
        if columns then
            row.columns = columns
            dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(COLUMN_ROW_TYPE, row)
        else
            dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(ROW_TYPE, row)
        end
    end
    ZO_ScrollList_Commit(self.list)

    local summary = tab.GetSummary and tab.GetSummary() or ""
    for _, row in ipairs(rows) do
        if row.OnRightClick and not tab.noMenuHint then
            summary = (summary ~= "" and (summary .. "  ") or "") .. Report.MENU_HINT
            break
        end
    end
    local offText = tab.GetOffText and tab.GetOffText()
    if offText then
        summary = "|cFFA45C" .. offText .. "|r" .. (summary ~= "" and ("  " .. summary) or "")
    elseif #rows == 0 and not usesPanel then
        summary = (summary ~= "" and (summary .. "  ") or "") .. "Nothing to review."
    end
    self.summary:SetText(summary)

    self.search:SetHidden(not tab.searchable)
    if tab.searchable and self.searchBox:GetText() ~= (tab.searchText or "") then
        self.searchBox:SetText(tab.searchText or "")
    end
    for _, other in ipairs(self.tabs) do
        local bar = Resolve(other.topBar)
        if bar then bar:SetHidden(other ~= tab) end
    end
    if tab.UpdateTopBar then tab.UpdateTopBar() end

    local footer = {}
    for _, action in ipairs(Resolve(tab.footer) or {}) do footer[#footer + 1] = action end
    footer[#footer + 1] = { label = "Export / copy", tip = "Shows this tab as comma-separated text (CSV) you can copy into Excel, Google Sheets or Discord.",
        fn = function() self:ShowExport(self:GetExportLines(tab)) end }
    for i, button in ipairs(self.footerButtons) do
        local action = footer[i]
        if action then
            button:SetText(action.label)
            button:SetWidth(action.width or 180)
            button:SetHandler("OnClicked", function(control) action.fn(control) end)
            Report.SetTip(button, action.tip)
            button:SetHidden(false)
        else
            button:SetHidden(true)
        end
    end
end

function Report:Show(tabId)
    if tabId and self:GetTab(tabId) then
        self.currentTab = tabId
        GT.sv.lastTab = tabId
    end
    if self.control:IsHidden() then SCENE_MANAGER:ShowTopLevel(self.control) end
    self:Refresh()
end

function Report:Hide()
    SCENE_MANAGER:HideTopLevel(self.control)
    ClearTooltip(InformationTooltip)
end

function Report:Toggle()
    if self.control:IsHidden() then self:Show() else self:Hide() end
end

function Report:RefreshIfShown()
    self:Refresh()
end

function Report.OnSearchChanged(editBox)
    -- The X is always there; it's brighter while there's something to clear.
    FurysGuildToolset_ReportSearchClear:SetAlpha((editBox:GetText() or "") == "" and 0.5 or 1)
    local tab = Report:GetTab(Report.currentTab)
    if not tab or not tab.searchable then return end
    local text = editBox:GetText() or ""
    if text == (tab.searchText or "") then return end
    tab.searchText = text
    if tab.OnSearchChanged then tab.OnSearchChanged(text) end
    Report:Refresh()
end

-- The X in the search box: empties it (the list updates through OnSearchChanged).
function Report.ClearSearch()
    Report.searchBox:SetText("")
    Report.searchBox:LoseFocus()
    Report.HideTip()
end

-- Export ---------------------------------------------------------------------
-- The game's edit boxes hold a limited amount of text, so big exports are split into
-- parts on line boundaries. Each part keeps the header line so it pastes on its own.

-- Removes color codes and turns item/guild links into their plain names.
local function PlainText(text)
    text = tostring(text or "")
    text = text:gsub("|H[^|]*|h(.-)|h", "%1")
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("[\r\n\t]+", " ")
    return zo_strtrim(text)
end

-- Exactly what the current tab shows: its name, the summary line, then one line per row.
function Report:GetVisibleLines(tab)
    local lines = { PlainText(Resolve(tab.title)) .. " - " .. os.date("%Y-%m-%d %H:%M") }
    local summary = tab.GetSummary and PlainText(tab.GetSummary()) or ""
    if summary ~= "" then lines[#lines + 1] = summary end
    local rows = tab.GetRows() or {}
    if #rows == 0 then lines[#lines + 1] = "Nothing to review." end
    for _, row in ipairs(rows) do lines[#lines + 1] = PlainText(row.text or table.concat(row.cells or {}, "  ")) end
    return lines
end

-- Tabs with GetExportLines export tab-separated columns (shown as CSV by ShowExport) (they list the same rows the tab shows);
-- the rest export the visible row text.
function Report:GetExportLines(tab)
    if tab.GetExportLines then return tab.GetExportLines() end
    return self:GetVisibleLines(tab)
end

-- The game's edit box drops tab characters, so exports are shown as CSV: commas between
-- columns, and a field that holds a comma or a quote is wrapped in quotes ("" for a quote).
-- Tabs build their lines tab-separated; this turns each one into a CSV line.
local function CsvField(field)
    if field:find('[,"]') or field ~= zo_strtrim(field) then
        return '"' .. field:gsub('"', '""') .. '"'
    end
    return field
end

local function ToCsvLine(line)
    local fields = {}
    for field in (tostring(line) .. "\t"):gmatch("(.-)\t") do fields[#fields + 1] = CsvField(field) end
    return table.concat(fields, ",")
end

function Report:ShowExport(tabLines)
    local lines = {}
    for i, line in ipairs(tabLines) do lines[i] = ToCsvLine(line) end
    local header = lines[1] or ""
    local parts, current, size = {}, { header }, #header
    for i = 2, #lines do
        local line = lines[i]
        if size + #line + 1 > EXPORT_PART_CHARS and #current > 1 then
            parts[#parts + 1] = table.concat(current, "\n")
            current, size = { header }, #header
        end
        current[#current + 1] = line
        size = size + #line + 1
    end
    parts[#parts + 1] = table.concat(current, "\n")
    self.exportParts = parts
    self.exportIndex = 1
    self.exportTitle = nil
    self.exportHint = nil
    GT.Util.ShowOnTop(FurysGuildToolset_Export)
    self:ShowExportPart(0)
end

function Report:ShowExportPart(delta)
    local parts = self.exportParts or { "" }
    self.exportIndex = zo_clamp((self.exportIndex or 1) + delta, 1, #parts)
    FurysGuildToolset_ExportTextBox:SetText(parts[self.exportIndex])
    FurysGuildToolset_ExportTitle:SetText(self.exportTitle or "Export")
    FurysGuildToolset_ExportHint:SetText(self.exportHint or EXPORT_HINT)
    FurysGuildToolset_ExportPart:SetText(string.format("Part %d of %d", self.exportIndex, #parts))
    FurysGuildToolset_ExportPrev:SetHidden(#parts <= 1)
    FurysGuildToolset_ExportNext:SetHidden(#parts <= 1)
    FurysGuildToolset_ExportPart:SetHidden(#parts <= 1)
end

-- Addons can't write to the clipboard, so select the text and let the player press Ctrl+C.
function Report:CopyExport()
    local box = FurysGuildToolset_ExportTextBox
    box:TakeFocus()
    box:SelectAll()
    GT.Util.Print("Part %d is selected. Press Ctrl+C to copy it.", self.exportIndex or 1)
end

function Report:HideExport()
    SCENE_MANAGER:HideTopLevel(FurysGuildToolset_Export)
end
