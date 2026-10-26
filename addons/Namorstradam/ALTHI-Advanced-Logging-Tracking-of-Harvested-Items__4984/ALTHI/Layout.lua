local A = ALTHarvestItems
local function L(key) return A:T(key) end
A.columnKeys = { "name", "count", "sessionGold", "stock", "stockGold" }
A.columnTitles = { "NAME", "QUANTITY", "GOLD_VALUE", "QUANTITY", "GOLD_VALUE" }
A.columnMinimums = { 130, 54, 90, 54, 90 }
local function Clamp(value, low, high) return math.max(low, math.min(high, value)) end
function A:GoldText(text)
    return GetItemQualityColor(ITEM_DISPLAY_QUALITY_LEGENDARY or ITEM_QUALITY_LEGENDARY or 5):Colorize(text)
end
function A:ThemeRGB()
    return 0.65, 0.65, 0.6
end
function A:ApplyAppearance()
    local r, g, b = self:ThemeRGB()
    for _, backdrop in ipairs(self.backdrops or {}) do
        backdrop:SetCenterColor(0.025, 0.035, 0.03, self.db.ui.backgroundAlpha)
        backdrop:SetEdgeColor(r, g, b, self.db.ui.frameAlpha)
    end
end
function A:SetSort(key)
    if self.db.ui.sortKey == key then self.db.ui.sortDescending = not self.db.ui.sortDescending
    else self.db.ui.sortKey = key; self.db.ui.sortDescending = false end
    self.offset = 0; self:QueueRefresh()
end
function A:SortRows(rows)
    local key, descending = self.db.ui.sortKey, self.db.ui.sortDescending
    local function Value(row)
        if key == "count" then return row.count end
        if key == "stock" then return row.stock end
        if key == "sessionGold" then return row.price and row.price * row.count end
        if key == "stockGold" then return row.price and row.price * row.stock end
        return zo_strlower(row.name)
    end
    table.sort(rows, function(a, b)
        local av, bv = Value(a), Value(b)
        if av == nil or bv == nil then
            if av ~= bv then return av ~= nil end -- Missing prices stay last in both directions.
        elseif av ~= bv then
            if descending then return av > bv end
            return av < bv
        end
        local an, bn = zo_strlower(a.name), zo_strlower(b.name)
        if an == bn then return a.id < b.id end
        return an < bn
    end)
end
-- Display only: full catalog names, ID matching, sorting and searching stay unchanged.
function A:DisplayName(name)
    if #name <= 30 then return name end
    local code = self:ClientLanguage() -- Names follow the client, not the chosen addon language.
    for _,rule in ipairs(self.nameAbbreviations[code] or {}) do
        name=name:gsub(rule[1],rule[2])
    end
    return name
end
function A:NameWidth(rows)
    local width = 160
    for _, row in ipairs(rows) do width = math.max(width, self.measure:GetStringWidth(self:DisplayName(row.name)) + 42) end
    return Clamp(width, 160, 400)
end
function A:ComputeColumns(rows, available)
    local count = self.db.ui.showStock and 5 or 3
    local mode = count == 5 and "both" or "session"
    local saved, widths = self.db.ui.columnWidths[mode], {}
    if saved and #saved == count then
        local remaining, weight, fixed = available, 0, {}
        for index = 1, count do weight = weight + math.max(1, saved[index]) end
        for _ = 1, count do
            local changed = false
            for index = 1, count do
                if not fixed[index] and remaining * math.max(1, saved[index]) / weight < self.columnMinimums[index] then
                    widths[index] = self.columnMinimums[index]; fixed[index] = true
                    remaining = remaining - widths[index]; weight = weight - math.max(1, saved[index]); changed = true
                end
            end
            if not changed then break end
        end
        for index = 1, count do
            if not fixed[index] then widths[index] = remaining * math.max(1, saved[index]) / weight end
        end
    else
        local minimumNumbers = 0
        for index = 2, count do minimumNumbers = minimumNumbers + self.columnMinimums[index] end
        local numberTargets={0,math.max(62,self.measure:GetStringWidth("999.999")+16),
            math.max(94,self.measure:GetStringWidth("999.999")+36),
            math.max(62,self.measure:GetStringWidth("999.999")+16),
            math.max(94,self.measure:GetStringWidth("999.999")+36)}
        for _,row in ipairs(rows) do
            numberTargets[2]=math.max(numberTargets[2],self.measure:GetStringWidth(self.Integer(row.count))+16)
            numberTargets[4]=math.max(numberTargets[4],self.measure:GetStringWidth(self.Integer(row.stock))+16)
            if row.price then
                numberTargets[3]=math.max(numberTargets[3],self.measure:GetStringWidth(self.Integer(row.count*row.price))+36)
                numberTargets[5]=math.max(numberTargets[5],self.measure:GetStringWidth(self.Integer(row.stock*row.price))+36)
            end
        end
        local targets=0; for index=2,count do targets=targets+numberTargets[index] end
        widths[1]=math.max(self.columnMinimums[1],available-targets)
        local spare = available - widths[1] - minimumNumbers
        local targetSpare=math.max(1,targets-minimumNumbers)
        for index=2,count do widths[index]=self.columnMinimums[index]+spare*(numberTargets[index]-self.columnMinimums[index])/targetSpare end
    end
    return widths, mode
end
function A:StartColumnDrag(index)
    if not self.widths[index + 1] then return end
    self:EndColumnDrag()
    local x = GetUIMousePosition()
    self.columnDrag = { index = index, startX = x, widths = self.Copy(self.widths), mode = self.layoutMode }
    local function Update()
        local drag = self.columnDrag
        if not drag then return end
        local currentX = GetUIMousePosition()
        local left, right = drag.widths[index], drag.widths[index + 1]
        local delta = Clamp(currentX - drag.startX, self.columnMinimums[index] - left,
            right - self.columnMinimums[index + 1])
        local widths = self.Copy(drag.widths)
        widths[index], widths[index + 1] = left + delta, right - delta
        self.db.ui.columnWidths[drag.mode] = widths
        self:QueueRefresh()
    end
    EVENT_MANAGER:RegisterForUpdate("ALTHIColumnDrag", 16, Update)
    EVENT_MANAGER:RegisterForEvent("ALTHIColumns", EVENT_GLOBAL_MOUSE_UP, function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then Update(); self:EndColumnDrag() end
    end)
end
function A:EndColumnDrag()
    self.columnDrag = nil
    EVENT_MANAGER:UnregisterForUpdate("ALTHIColumnDrag")
    EVENT_MANAGER:UnregisterForEvent("ALTHIColumns", EVENT_GLOBAL_MOUSE_UP)
end
function A:LayoutTable(rows)
    self.widths, self.layoutMode = self:ComputeColumns(rows, self.window:GetWidth() - 60)
    local x = 18
    for index = 1, 5 do
        local width = self.widths[index]
        local header = self.headers[index]
        header:SetHidden(self.db.ui.minimized or not width)
        self.dividers[index]:SetHidden(self.db.ui.minimized or not width or index == #self.widths)
        if width then
            header:ClearAnchors(); header:SetAnchor(TOPLEFT, self.window, TOPLEFT, x + (index == 1 and 28 or 4), 130)
            header:SetDimensions(width - (index == 1 and 36 or 12), 22)
            local marker = self.db.ui.sortKey == self.columnKeys[index] and (self.db.ui.sortDescending and " v" or " ^") or ""
            header:SetText(L(self.columnTitles[index]) .. marker)
            local divider = self.dividers[index]
            divider:ClearAnchors(); divider:SetAnchor(TOPLEFT, self.window, TOPLEFT, x + width - 4, 130)
            divider:SetDimensions(8, 22)
            for _, control in ipairs(self.rowControls) do
                local cell = control.cells[index]
                cell:ClearAnchors()
                cell:SetAnchor(LEFT, control, LEFT, x - 18 + (index == 1 and 30 or 4), 0)
                cell:SetDimensions(width - (index == 1 and 38 or 12), 26)
                cell:SetHidden(false)
            end
            x = x + width
        else
            for _, control in ipairs(self.rowControls) do control.cells[index]:SetHidden(true) end
        end
    end
    local nameEnd = 18 + self.widths[1]
    local sessionWidth = self.widths[2] + self.widths[3]
    self.sessionGroup:ClearAnchors(); self.sessionGroup:SetAnchor(TOPLEFT, self.window, TOPLEFT, nameEnd, 110)
    self.sessionGroup:SetDimensions(sessionWidth - 10, 20)
    self.sessionGroup:SetHidden(self.db.ui.minimized == true)
    self.stockGroup:SetHidden(self.db.ui.minimized or not self.db.ui.showStock)
    if self.db.ui.showStock then
        self.stockGroup:ClearAnchors(); self.stockGroup:SetAnchor(TOPLEFT, self.window, TOPLEFT, nameEnd + sessionWidth, 110)
        self.stockGroup:SetDimensions(self.widths[4] + self.widths[5] - 10, 20)
    end
    self.bagTotal:SetHidden(not self.db.ui.showStock)
    local third=(self.window:GetWidth()-36)/(self.db.ui.showStock and 3 or 2)
    self.sessionTotal:SetWidth(third)
    self.bagTotal:SetWidth(third)
    self.rate:ClearAnchors(); self.rate:SetAnchor(TOPLEFT,self.window,TOPLEFT,18+third,84)
    self.rate:SetDimensions(third,26)
    self.rate:SetHorizontalAlignment(self.db.ui.showStock and TEXT_ALIGN_CENTER or TEXT_ALIGN_RIGHT)

end
function A:ToggleStock()
    self:EndColumnDrag()
    local ui = self.db.ui
    if ui.showStock then ui.widthWithStock = self.window:GetWidth()
    else ui.widthWithoutStock = self.window:GetWidth() end
    ui.showStock = not ui.showStock
    if not ui.showStock and (ui.sortKey == "stock" or ui.sortKey == "stockGold") then ui.sortKey = "name"; ui.sortDescending = false end
    self.window:SetDimensionConstraints(ui.showStock and 620 or 480, ui.minimized and 112 or 400, 1800, ui.minimized and 112 or 1100)
    self.window:SetWidth(ui.showStock and (ui.widthWithStock or 900) or (ui.widthWithoutStock or 620))
    self.db.width = self.window:GetWidth()
    self.offset = 0; self:QueueRefresh()
end
function A:OpenViewSettings()
    if not self.viewWindow then
        local window = WINDOW_MANAGER:CreateTopLevelWindow("ALTHIViewSettings")
        window:SetDimensions(480, 330); window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        window:SetMovable(true); window:SetMouseEnabled(true); window:SetClampedToScreen(true)
        self:Backdrop(window)
        local title = self:Label(window, "ZoFontWinH2")
        title:SetAnchor(TOPLEFT, window, TOPLEFT, 18, 15); title:SetText(self:GoldText("ALTHI") .. L("VIEW"))
        local function Slider(text, key, y)
            local label = self:Label(window)
            label:SetAnchor(TOPLEFT, window, TOPLEFT, 22, y); label:SetWidth(430)
            local track = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
            track:SetColor(0.7, 0.6, 0.3, 0.4); track:SetDimensions(410, 3)
            track:SetAnchor(TOPLEFT, window, TOPLEFT, 28, y + 39)
            local slider = WINDOW_MANAGER:CreateControl(nil, window, CT_SLIDER)
            slider:SetAnchor(TOPLEFT, window, TOPLEFT, 22, y + 26); slider:SetDimensions(420, 28)
            slider:SetOrientation(ORIENTATION_HORIZONTAL); slider:SetMouseEnabled(true)
            slider:SetMinMax(0, 100); slider:SetValueStep(1)
            slider:SetThumbTexture("EsoUI/Art/Miscellaneous/scrollbox_elevator.dds",
                "EsoUI/Art/Miscellaneous/scrollbox_elevator_disabled.dds",
                "EsoUI/Art/Miscellaneous/scrollbox_elevator.dds", 16, 26, 0, 0, 1, 1)
            slider:SetHandler("OnValueChanged", function(_, value)
                value = Clamp(math.floor(value + 0.5), 0, 100)
                self.db.ui[key] = value / 100; label:SetText(text .. ": " .. value .. L("VISIBLE"))
                self:ApplyAppearance()
            end)
            slider:SetValue(self.db.ui[key] * 100)
            return slider
        end
        self.backgroundSlider = Slider(L("BACKGROUND"), "backgroundAlpha", 58)
        self.frameSlider = Slider(L("BORDER"), "frameAlpha", 135)
        local reset = self:Button(window, L("AUTOMATIC_COLUMNS"), 220, function()
            self.db.ui.columnWidths = {}; self:QueueRefresh()
        end)
        reset:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 18, -55)
        self:CloseIcon(window)
        self.viewWindow = window
    end
    self:ShowDialog(self.viewWindow)
end
