local C = CrownCrateCodex
local Label, Button, Backdrop = C.UI.Label, C.UI.Button, C.UI.Backdrop

function C:ShowExport()
    -- A copy window is required: addons cannot write arbitrary CSV files.
    local text = self:Export(self.query, self.crateFilter)
    self.exportChunks = {}
    local chunk = ""
    for line in string.gmatch(text .. "\n", "(.-)\n") do
        if #chunk + #line + 1 > 12000 and chunk ~= "" then
            self.exportChunks[#self.exportChunks + 1] = chunk
            chunk = ""
        end
        chunk = chunk .. line .. "\n"
    end
    self.exportChunks[#self.exportChunks + 1] = chunk
    if not self.exportWindow then
        local window = WINDOW_MANAGER:CreateTopLevelWindow("CrownCrateCodexExport")
        window:SetHidden(true)
        self.exportWindow = window
        window:SetDimensions(900, 580)
        window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        window:SetMouseEnabled(true)
        window:SetMovable(true)
        window:SetClampedToScreen(true)
        window:SetDrawTier(DT_HIGH)
        window:SetTopmost(true)
        window:SetScale(math.min(1,GuiRoot:GetWidth()/940,GuiRoot:GetHeight()/620))
        Backdrop(window)
        self.exportTitle = Label(window, nil, 20, 15, 760, 35, "ZoFontWinH2")
        Label(window, nil, 20, 60, 850, 50):SetText(C.L("Ctrl+A, Ctrl+C to copy. Append every part in order to one UTF-8 CSV file.\nExport follows History's search and crate filter."))
        self.exportEdit=WINDOW_MANAGER:CreateControlFromVirtual("CrownCrateCodexExportText",window,"ZO_DefaultEditMultiLineForBackdrop")
        self.exportEdit:ClearAnchors()
        self.exportEdit:SetAnchor(TOPLEFT, window, TOPLEFT, 20, 120)
        self.exportEdit:SetDimensions(860, 395)
        self.exportEdit:SetFont("ZoFontGameSmall")
        self.exportEdit:SetMouseEnabled(true)
        self.exportEdit:SetEditEnabled(true)
        self.exportEdit:SetHandler("OnMouseDown",function(control) control:TakeFocus() end)
        self.exportEdit:SetMultiLine(true)
        self.exportEdit:SetMaxInputChars(20000)
        self.exportEdit:SetSelectAllOnFocus(true)
        Button(window, nil, C.L("Close"), 805, 18, 70, function() C:SetWindowHidden(window,true) end)
        Button(window, nil, C.L("Previous part"), 20, 535, 170, function() self:ExportPage(-1) end)
        Button(window, nil, C.L("Next part"), 210, 535, 170, function() self:ExportPage(1) end)
        if self.WatchGamepadWindow then self:WatchGamepadWindow(window) end
    end
    self.exportPage = 1
    self:ExportPage(0)
    self:SetWindowHidden(self.exportWindow,false)
    self.exportWindow:BringWindowToTop()
    if self.SyncGamepad then self:SyncGamepad() end
end

function C:ExportPage(offset)
    self.exportPage = math.max(1, math.min(#self.exportChunks, self.exportPage + offset))
    self.exportTitle:SetText(string.format(C.L("Copy CSV | Part %d of %d"), self.exportPage, #self.exportChunks))
    self.exportEdit:SetText(self.exportChunks[self.exportPage])
    self.exportEdit:SelectAll()
end
