-- One window, one tab per module. A module registers a tab with:
--   GT.Report:RegisterTab({
--       id = "bank",
--       title = function() return "Bank (3)" end,     -- string or function
--       tip = "What this tab shows",                   -- optional hover text for the tab button
--       GetSummary = function() return "..." end,      -- optional line under the tabs
--       GetRows = function() return { { text=, tooltip=, actions={ {label=, fn=}, ... } } } end,
--       footer = { { label = "Dismiss all", tip = "Hover text", fn = function() end }, ... },  -- optional
--       searchable = true,                             -- optional: shows the search box, tab.searchText holds it
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

local GT = FuryGMT
local Report = {}
GT.Report = Report

local ROW_TYPE = 1
local COLUMN_ROW_TYPE = 2
local MAX_COLUMNS = 8
local COLUMN_GAP = 8
local ROW_HEIGHT = 32
local MAX_FOOTER_BUTTONS = 6
local EXPORT_PART_CHARS = 20000

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

function Report:RegisterTab(def)
    table.insert(self.tabs, def)
end

function Report:GetTab(id)
    for _, tab in ipairs(self.tabs) do
        if tab.id == id then return tab end
    end
end

function Report:Initialize()
    self.control = FuryGMTReport
    self.list = FuryGMTReportList
    self.summary = FuryGMTReportSummary
    self.search = FuryGMTReportSearch
    self.searchBox = FuryGMTReportSearchBox
    FuryGMTReportVersion:SetText("v" .. GT.version)
    FuryGMTExportTextBox:SetMaxInputChars(EXPORT_PART_CHARS + 2000)
    -- Without these the edit box drops line breaks and everything runs together.
    FuryGMTExportTextBox:SetMultiLine(true)
    FuryGMTExportTextBox:SetNewLineEnabled(true)
    -- Registering with the scene manager makes Esc close these windows
    -- and handles the mouse cursor for us.
    SCENE_MANAGER:RegisterTopLevel(FuryGMTReport, false)
    SCENE_MANAGER:RegisterTopLevel(FuryGMTExport, false)
    FuryGMTReport:SetHandler("OnHide", function()
        ClearTooltip(InformationTooltip)
        if self.panelTab then self.panelTab.SetPanelShown(false); self.panelTab = nil end
    end)

    ZO_ScrollList_AddDataType(self.list, ROW_TYPE, "FuryGMT_ReportRow", ROW_HEIGHT, function(control, data)
        self:SetupRow(control, data)
    end)
    ZO_ScrollList_AddDataType(self.list, COLUMN_ROW_TYPE, "FuryGMT_ReportColumnRow", 28, function(control, data)
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
    self.header = FuryGMTReportHeader
    self.headerLabels = {}
    for i = 1, MAX_COLUMNS do
        local label = WINDOW_MANAGER:CreateControl("FuryGMTReportHeaderCol" .. i, self.header, CT_LABEL)
        label:SetFont("ZoFontGameBold")
        label:SetColor(0.83, 0.69, 0.22, 1)
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

    local previous
    for i, tab in ipairs(self.tabs) do
        local button = WINDOW_MANAGER:CreateControlFromVirtual("FuryGMTReportTab" .. i, FuryGMTReportTabs, "ZO_DefaultButton")
        button:SetDimensions(math.min(180, math.floor((1160 - 4 * (#self.tabs - 1)) / #self.tabs)), 28)
        if previous then
            button:SetAnchor(LEFT, previous, RIGHT, 4, 0)
        else
            button:SetAnchor(LEFT, FuryGMTReportTabs, LEFT, 0, 0)
        end
        button:SetHandler("OnClicked", function() self:SelectTab(tab.id) end)
        Report.SetTip(button, function() return Resolve(tab.tip) end)
        self.tabButtons[i] = button
        previous = button
    end

    previous = nil
    for i = 1, MAX_FOOTER_BUTTONS do
        local button = WINDOW_MANAGER:CreateControlFromVirtual("FuryGMTReportFooter" .. i, FuryGMTReportFooter, "ZO_DefaultButton")
        button:SetDimensions(150, 28)
        if previous then
            button:SetAnchor(LEFT, previous, RIGHT, 6, 0)
        else
            button:SetAnchor(LEFT, FuryGMTReportFooter, LEFT, 0, 0)
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
    local control = FuryGMTReport
    GT.sv.window = { x = control:GetLeft(), y = control:GetTop() }
end

function Report:SetupRow(control, data)
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
    for _, row in ipairs(rows) do
        if columns then
            row.columns = columns
            dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(COLUMN_ROW_TYPE, row)
        else
            dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(ROW_TYPE, row)
        end
    end
    ZO_ScrollList_Commit(self.list)

    local summary = tab.GetSummary and tab.GetSummary() or ""
    if #rows == 0 and not usesPanel then
        summary = (summary ~= "" and (summary .. "  ") or "") .. "Nothing to review."
    end
    self.summary:SetText(summary)

    self.search:SetHidden(not tab.searchable)
    if tab.searchable and self.searchBox:GetText() ~= (tab.searchText or "") then
        self.searchBox:SetText(tab.searchText or "")
    end

    local footer = {}
    for _, action in ipairs(Resolve(tab.footer) or {}) do footer[#footer + 1] = action end
    footer[#footer + 1] = { label = "Export / copy", tip = "Shows this tab as comma-separated text (CSV) you can copy into Excel, Google Sheets or Discord.",
        fn = function() self:ShowExport(self:GetExportLines(tab)) end }
    for i, button in ipairs(self.footerButtons) do
        local action = footer[i]
        if action then
            button:SetText(action.label)
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
    local tab = Report:GetTab(Report.currentTab)
    if not tab or not tab.searchable then return end
    local text = editBox:GetText() or ""
    if text == (tab.searchText or "") then return end
    tab.searchText = text
    if tab.OnSearchChanged then tab.OnSearchChanged(text) end
    Report:Refresh()
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
    if FuryGMTExport:IsHidden() then SCENE_MANAGER:ShowTopLevel(FuryGMTExport) end
    self:ShowExportPart(0)
end

function Report:ShowExportPart(delta)
    local parts = self.exportParts or { "" }
    self.exportIndex = zo_clamp((self.exportIndex or 1) + delta, 1, #parts)
    FuryGMTExportTextBox:SetText(parts[self.exportIndex])
    FuryGMTExportPart:SetText(string.format("Part %d of %d", self.exportIndex, #parts))
    FuryGMTExportPrev:SetHidden(#parts <= 1)
    FuryGMTExportNext:SetHidden(#parts <= 1)
    FuryGMTExportPart:SetHidden(#parts <= 1)
end

-- Addons can't write to the clipboard, so select the text and let the player press Ctrl+C.
function Report:CopyExport()
    local box = FuryGMTExportTextBox
    box:TakeFocus()
    box:SelectAll()
    FuryGMT.Util.Print("Part %d is selected. Press Ctrl+C to copy it.", self.exportIndex or 1)
end

function Report:HideExport()
    SCENE_MANAGER:HideTopLevel(FuryGMTExport)
end
