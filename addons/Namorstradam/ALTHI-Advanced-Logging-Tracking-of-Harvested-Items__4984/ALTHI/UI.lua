local A = ALTHarvestItems
local function L(key) return A:T(key) end
function A:Front(window)
    window:SetDrawTier(DT_HIGH)
    window:SetHidden(false)
    window:BringWindowToTop()
end
function A:EnableEdit(edit)
    edit:SetMouseEnabled(true); edit:SetKeyboardEnabled(true); edit:SetEditEnabled(true)
    edit:SetHandler("OnMouseDown",function(control) control:TakeFocus() end)
    edit:SetHandler("OnEscape",function(control) control:LoseFocus() end)
end
function A:MenuButton(parent,text,width,callback)
    local button=self:Button(parent,text,width,callback)
    button:SetNormalFontColor(0.85,0.85,0.8,1)
    for _,edge in ipairs({TOPLEFT,BOTTOMLEFT}) do
        local line=WINDOW_MANAGER:CreateControl(nil,button,CT_TEXTURE)
        line:SetAnchor(edge,button,edge,0,0)
        line:SetAnchor(edge==TOPLEFT and TOPRIGHT or BOTTOMRIGHT,button,edge==TOPLEFT and TOPRIGHT or BOTTOMRIGHT,0,0)
        line:SetHeight(1); line:SetColor(0.65,0.65,0.6,0.45)
    end
    return button
end
function A:Label(parent, font)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetFont(font or "ZoFontGame")
    label:SetMaxLineCount(1)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return label
end
function A:Button(parent, text, width, callback)
    local button = WINDOW_MANAGER:CreateControl(nil, parent, CT_BUTTON)
    button:SetDimensions(width, 30)
    button:SetFont("ZoFontGame")
    button:SetText(text)
    button:SetMouseEnabled(true)
    button:SetHandler("OnClicked", callback)
    return button
end
function A:Backdrop(window, adjustable)
    local bg = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
    bg:SetAnchorFill(window)
    local r, g, b = self:ThemeRGB()
    bg:SetCenterColor(0.025, 0.035, 0.03, 1)
    bg:SetEdgeColor(r, g, b, 1)
    if adjustable then
        self.backdrops = self.backdrops or {}
        self.backdrops[#self.backdrops + 1] = bg
        self:ApplyAppearance()
    end
    window.althiBackdrop = bg
    bg:SetEdgeTexture("", 1, 1, 1)
    return bg
end
function A:Line(parent, x, y)
    local line = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    line:SetColor(0.65, 0.65, 0.6, 0.45)
    line:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    line:SetAnchor(TOPRIGHT, parent, TOPRIGHT, -18, y)
    line:SetHeight(1)
end
function A:MakeSlider(name, window, top, bottom, onChange)
    local slider = WINDOW_MANAGER:CreateControl(name, window, CT_SLIDER)
    slider:SetAnchor(TOPRIGHT, window, TOPRIGHT, -18, top)
    slider:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -18, bottom)
    slider:SetWidth(12)
    slider:SetOrientation(ORIENTATION_VERTICAL)
    slider:SetMouseEnabled(true)
    slider:SetValueStep(1)
    slider:SetThumbTexture("EsoUI/Art/Miscellaneous/scrollbox_elevator.dds",
        "EsoUI/Art/Miscellaneous/scrollbox_elevator_disabled.dds",
        "EsoUI/Art/Miscellaneous/scrollbox_elevator.dds", 12, 30, 0, 0, 1, 1)
    slider:SetHandler("OnValueChanged", function(_, value) onChange(math.floor(value + 0.5)) end)
    return slider
end
function A:Scroll(delta)
    self.offset = math.max(0, math.min(self.maxOffset or 0, self.offset + delta))
    self:Refresh()
end
function A:CreateRow(index)
    local row = WINDOW_MANAGER:CreateControl(nil, self.window, CT_CONTROL)
    row:SetAnchor(TOPLEFT, self.window, TOPLEFT, 18, 150 + (index - 1) * 28)
    row:SetAnchor(TOPRIGHT, self.window, TOPRIGHT, -42, 150 + (index - 1) * 28)
    row:SetHeight(28)
    row:SetMouseEnabled(true)
    row:SetHandler("OnMouseWheel", function(_, delta) self:Scroll(-delta * 3) end)
    row:SetHandler("OnMouseEnter", function(control)
        local data = control.data
        if not data then return end
        self:MaterialTooltip(control, data.id)
    end)
    row:SetHandler("OnMouseExit", function() ClearTooltip(ItemTooltip) end)
    row.icon = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    row.icon:SetDimensions(22, 22)
    row.icon:SetAnchor(LEFT, row, LEFT, 0, 0)
    row.separator=WINDOW_MANAGER:CreateControl(nil,row,CT_CONTROL)
    row.separator:SetAnchor(BOTTOMLEFT,row,BOTTOMLEFT,0,0)
    row.separator:SetAnchor(BOTTOMRIGHT,row,BOTTOMRIGHT,0,0); row.separator:SetHeight(1)
    row.separator:SetMouseEnabled(false)
    local left=WINDOW_MANAGER:CreateControl(nil,row.separator,CT_TEXTURE)
    left:SetAnchor(TOPLEFT,row.separator,TOPLEFT,0,0); left:SetDimensions(24,1)
    left:SetGradientColors(ORIENTATION_HORIZONTAL,0.65,0.65,0.6,0,0.65,0.65,0.6,0.32)
    local middle=WINDOW_MANAGER:CreateControl(nil,row.separator,CT_TEXTURE)
    middle:SetAnchor(TOPLEFT,row.separator,TOPLEFT,24,0); middle:SetAnchor(TOPRIGHT,row.separator,TOPRIGHT,-24,0)
    middle:SetHeight(1); middle:SetColor(0.65,0.65,0.6,0.32)
    local right=WINDOW_MANAGER:CreateControl(nil,row.separator,CT_TEXTURE)
    right:SetAnchor(TOPRIGHT,row.separator,TOPRIGHT,0,0); right:SetDimensions(24,1)
    right:SetGradientColors(ORIENTATION_HORIZONTAL,0.65,0.65,0.6,0.32,0.65,0.65,0.6,0)
    row.separator.left,row.separator.middle,row.separator.right=left,middle,right
    row.cells = {}
    for cell = 1, 5 do
        row.cells[cell] = self:Label(row, "ZoFontGameSmall")
        if cell > 1 then row.cells[cell]:SetHorizontalAlignment(TEXT_ALIGN_RIGHT) end
    end
    row.label, row.sessionCount, row.sessionGold, row.bagCount, row.bagGold = unpack(row.cells)
    self.rowControls[index] = row
    return row
end
function A:Refresh()
    if not self.window or self.refreshing then return end
    self.refreshing = true
    self:UpdateWindowVisibility()
    self:AccrueTime()
    local rows, totals = self:RowsAndTotals()
    local session = self.db.session
    local states = { stopped = L("STOPPED_READY"), paused = L("PAUSE"), running = L("HARVESTING") }
    self.status:SetText(string.format(L("S_S_ACTIVE_S_ITEMS_S"), states[session.state],
        self.Time(session.elapsed), self.Integer(totals.sessionCount), " · " .. (self.db.options.guildTrader and "|c44CC66"..L("GUILD_TRADER_ON") or "|cDD5555"..L("GUILD_TRADER_OFF")) .. "|r" .. (self.catalogLoading and L("LOADING_CATALOGUE") or "")))
    local function Sum(value, missing)
        return (missing > 0 and L("PARTIAL") or "") .. self.Gold(value)
            .. (missing > 0 and " (" .. missing .. L("WITHOUT_PRICE") or "")
    end
    self.sessionTotal:SetText(L("SESSION") .. Sum(totals.sessionGold, totals.missingSession))
    self.bagTotal:SetText(L("CRAFT_BAG_8C418C") .. (self.stockReady and Sum(totals.stockGold, totals.missingStock) or L("READING")))
    self.rate:SetText(totals.perHour and (totals.missingSession > 0 and L("PARTIAL") or "")
        .. self.Gold(totals.perHour) .. "/h" or self.coin .. "/h: —")
    local visible = self.db.ui.minimized and 0 or math.max(1, math.floor((self.window:GetHeight() - 210) / 28))
    self.maxOffset = math.max(0, #rows - visible)
    self.offset = math.max(0, math.min(self.offset, self.maxOffset))
    self.slider:SetMinMax(0, math.max(1, self.maxOffset))
    self.slider:SetValue(self.offset)
    self.slider:SetHidden(self.db.ui.minimized or self.maxOffset == 0)
    self.empty:SetHidden(self.db.ui.minimized or #rows > 0)
    for _,button in ipairs(self.runButtons or {}) do button:SetHidden(self.db.ui.minimized == true) end
    if self.priceNote then self.priceNote:SetHidden(self.db.ui.minimized == true or self.window:GetWidth()<900) end
    for index = 1, math.max(visible, #self.rowControls) do
        local control = self.rowControls[index]
        local data = index <= visible and rows[self.offset + index] or nil
        if data and not control then control = self:CreateRow(index) end
        if control then
            control:SetHidden(not data)
            control.data = data
            if data then
                control.icon:SetTexture(data.icon or "EsoUI/Art/Icons/icon_missing.dds")
                local color = GetItemQualityColor(data.quality)
                control.label:SetText(color and color:Colorize(self:DisplayName(data.name)) or self:DisplayName(data.name))
                control.sessionCount:SetText(self.Integer(data.count))
                control.bagCount:SetText(self.stockReady and self.Integer(data.stock) or "—")
                control.sessionGold:SetText(data.count == 0 and "—" or data.price and self.Gold(data.count * data.price) or L("NO_PRICE"))
                control.bagGold:SetText(data.stock == 0 and "—" or data.price and self.Gold(data.stock * data.price) or L("NO_PRICE"))
            end
        end
    end
    self.stockButton:SetHidden(self.db.ui.minimized == true)
    self.stockButton:SetText(self.db.ui.showStock and L("BAG_ON") or L("BAG_OFF"))
    self:LayoutTable(rows)
    self.refreshing = false
end
function A:CreateWindow()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("ALTHIWindow")
    window:SetDimensions(math.max(self.db.ui.showStock and 620 or 480, self.db.width), math.max(400, self.db.height))
    window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.db.x, self.db.y)
    window:SetMovable(true)
    window:SetMouseEnabled(true)
    window:SetClampedToScreen(true)
    window:SetDimensionConstraints(self.db.ui.showStock and 620 or 480, 400, 1800, 1100)
    window:SetResizeHandleSize(12)
    window:SetHandler("OnMoveStop", function(control) self.db.x, self.db.y = control:GetLeft(), control:GetTop() end)
    window:SetHandler("OnResizeStop", function(control)
        self.db.width = control:GetWidth()
        if not self.db.ui.minimized then self.db.height = control:GetHeight() end
        self.db.x, self.db.y = control:GetLeft(), control:GetTop(); self:Refresh()
    end)
    window:SetHandler("OnRectWidthChanged", function() self:QueueRefresh() end)
    window:SetHandler("OnHide", function() self:EndColumnDrag() end)
    window:SetHandler("OnRectHeightChanged", function() self:QueueRefresh() end)
    window:SetHandler("OnMouseWheel", function(_, delta) self:Scroll(-delta * 3) end)
    self:Backdrop(window, true)
    local title = self:Label(window, "ZoFontWinH2")
    title:SetAnchor(TOPLEFT, window, TOPLEFT, 18, 12)
    title:SetWidth(120)
    title:SetText(self:GoldText("ALTHI"))
    local subtitle = self:Label(window, "ZoFontGameSmall")
    subtitle:SetAnchor(TOPLEFT, window, TOPLEFT, 18, 38)
    subtitle:SetAnchor(TOPRIGHT, window, TOPRIGHT, -18, 38); subtitle:SetHeight(20)
    subtitle:SetText("Advanced Logging & Tracking of Harvested Items")
    local selection = self:MenuButton(window, L("FILTER_LIST"), 130, function() self:OpenSettings() end)
    selection:SetAnchor(TOPRIGHT, window, TOPRIGHT, -55, 12)
    local view = self:MenuButton(window, L("SETTINGS"), 130, function() self:OpenMainSettings() end)
    view:SetAnchor(TOPRIGHT, window, TOPRIGHT, -195, 12)
    self.status = self:Label(window, "ZoFontGameSmall")
    self.status:SetAnchor(TOPLEFT, window, TOPLEFT, 18, 60)
    self.status:SetAnchor(TOPRIGHT, window, TOPRIGHT, -18, 60)
    self.status:SetHeight(20)
    self.rate = self:Label(window, "ZoFontGameSmall")
    self.rate:SetAnchor(TOPRIGHT, window, TOPRIGHT, -18, 60)
    self.rate:SetDimensions(190, 20)
    self.rate:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.sessionTotal = self:Label(window, "ZoFontGameSmall")
    self.sessionTotal:SetAnchor(TOPLEFT, window, TOPLEFT, 18, 84)
    self.sessionTotal:SetWidth(470)
    self.bagTotal = self:Label(window, "ZoFontGameSmall")
    self.bagTotal:SetAnchor(TOPRIGHT, window, TOPRIGHT, -18, 84)
    self.bagTotal:SetWidth(490)
    self.bagTotal:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self:Line(window, 18, 109)
    self.headers, self.dividers = {}, {}
    for index = 1, 5 do
        local column = index
        local header = self:Label(window, "ZoFontGameSmall")
        header:SetHorizontalAlignment(index == 1 and 0 or TEXT_ALIGN_RIGHT)
        header:SetMouseEnabled(true)
        header:SetHandler("OnMouseUp", function(_, button)
            if button == MOUSE_BUTTON_INDEX_LEFT then self:SetSort(self.columnKeys[column]) end
        end)
        self.headers[index] = header
        local grip = WINDOW_MANAGER:CreateControl(nil, window, CT_CONTROL)
        grip:SetMouseEnabled(true)
        grip:SetHandler("OnMouseDown", function(_, button)
            if button == MOUSE_BUTTON_INDEX_LEFT then self:StartColumnDrag(column) end
        end)
        grip:SetHandler("OnMouseUp", function() self:EndColumnDrag() end)
        local line = WINDOW_MANAGER:CreateControl(nil, grip, CT_TEXTURE)
        line:SetDimensions(1, 18); line:SetAnchor(CENTER, grip, CENTER, 0, 0)
        line:SetColor(0.7, 0.6, 0.3, 0.6)
        self.dividers[index] = grip
    end
    self.sessionGroup = self:Label(window, "ZoFontGameSmall")
    self.sessionGroup:SetText(L("CURRENT_SESSION")); self.sessionGroup:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.stockGroup = self:Label(window, "ZoFontGameSmall")
    self.stockGroup:SetText(L("CRAFT_BAG_A81872")); self.stockGroup:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.measure = self:Label(window, "ZoFontGameSmall"); self.measure:SetHidden(true)
    local buttons = {
        { L("RUN"), 60, function() self:Play() end },
        { L("PAUSE"), 55, function() self:Pause() end },
        { L("STOP"), 50, function() self:Stop() end },
        { L("RESET"), 55, function() ZO_Dialogs_ShowDialog("ALTHI_RESET") end },
    }
    self.runButtons={}
    local x = 18
    local buttonMeasure = self:Label(window, "ZoFontGame"); buttonMeasure:SetHidden(true)
    for _, spec in ipairs(buttons) do
        local button = self:MenuButton(window, spec[1], spec[2], spec[3])
        self.runButtons[#self.runButtons+1]=button
        button:SetWidth(math.max(spec[2], buttonMeasure:GetStringWidth(spec[1]) + 10))
        button:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, x, -22); x = x + button:GetWidth() + 6
    end
    self.stockButton = self:MenuButton(window, L("CRAFT_BAG"), 140, function() self:ToggleStock() end)
    self.stockButton:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -18, -22)
    self.priceNote=self:Label(window,"ZoFontGameSmall")
    self.priceNote:SetAnchor(BOTTOMLEFT,window,BOTTOMLEFT,x+14,-23)
    self.priceNote:SetText(L("PRICES_SEE_TOOLTIP")); self.priceNote:SetColor(0.6,0.7,0.65,1)
    self.minimizeButton=self:MenuButton(window,"^",30,function() self:ToggleMinimized() end)
    self.minimizeButton:SetFont("ZoFontWinH3")
    self.minimizeButton:SetAnchor(TOPRIGHT,window,TOPRIGHT,-16,12)
    self.empty = self:Label(window)
    self.empty:SetAnchor(TOPLEFT, window, TOPLEFT, 24, 170)
    self.empty:SetText(L("YOUR_FIRST_HARVEST_STARTS_THE_SESSION"))
    self.slider = self:MakeSlider("ALTHIScrollbar", window, 156, -65, function(value)
        if not self.refreshing then self.offset = value; self:Refresh() end
    end)
    self.slider:SetHandler("OnMouseWheel", function(_, delta) self:Scroll(-delta * 3) end)
    self.rowControls = {}; self.window = window
    if self.db.ui.minimized then
        window:SetDimensionConstraints(self.db.ui.showStock and 620 or 480,112,1800,112)
        window:SetHeight(112); self.minimizeButton:SetText("v")
    end
    self:UpdateWindowVisibility(); self:Refresh()
end
function A:ToggleWindow(show)
    if show == nil then show = self.db.hidden end
    self.db.hidden = not show; self:UpdateWindowVisibility()
end

function A:ToggleMinimized()
    self:EndColumnDrag()
    local ui=self.db.ui
    if not ui.minimized then self.db.height=self.window:GetHeight() end
    ui.minimized=not ui.minimized
    self.window:SetDimensionConstraints(ui.showStock and 620 or 480,ui.minimized and 112 or 400,1800,ui.minimized and 112 or 1100)
    self.window:SetHeight(ui.minimized and 112 or math.max(400,self.db.height))
    self.minimizeButton:SetText(ui.minimized and "v" or "^")
    self:Refresh()
end

-- Scene visibility is temporary; never overwrite the user's manual hidden flag.
function A:UpdateWindowVisibility()
    if not self.window then return end
    local inMenu=false
    if self.db.options.hideInMenus~=false and SCENE_MANAGER and SCENE_MANAGER.IsShowingBaseScene then
        inMenu=not SCENE_MANAGER:IsShowingBaseScene()
    end
    self.menuSuppressed=inMenu
    self.window:SetHidden(self.db.hidden or inMenu)
end
function A:SetMenuHiding(value)
    self.db.options.hideInMenus=value==true
    self:UpdateWindowVisibility()
    if self.mainSettings then self:RefreshMainSettings() end
end
