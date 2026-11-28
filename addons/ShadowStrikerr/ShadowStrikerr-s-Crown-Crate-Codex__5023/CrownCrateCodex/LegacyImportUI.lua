local C=CrownCrateCodex
local function Server(world)
    return world=="NA Megaserver" and "PC_NA" or world=="EU Megaserver" and "PC_EU" or world
end

function C:LegacyImportSnapshot()
    local source=self:TrackerRecords() or self.legacySeed
    local records,invalid={},0
    for _,record in ipairs(source or {}) do
        local raw=type(record)=="table" and record.Data or record
        if self:ParseLegacy(raw) then records[#records+1]=raw else invalid=invalid+1 end
    end
    return records,invalid
end

function C:ConfirmLegacyImport(target,confirmed,records)
    if not confirmed or target~=self.world or not self.shared then return nil,C.L("Select the logged-in server and confirm ownership first.") end
    local accepted,blocked={},0
    for _,raw in ipairs(records or {}) do
        local other=false
        for profile,accounts in pairs(self.profileRoot or {}) do
            local account=type(accounts)=="table" and accounts[self.profileAccount]
            local data=type(account)=="table" and account["$AccountWide"]
            if profile~=target and profile~="Codex Shared" and type(data)=="table" then
                for _,opening in ipairs(data.history or {}) do
                    if (opening.trackerRaw or opening.legacyRaw)==raw then other=true; break end
                end
            end
        end
        if other then blocked=blocked+1
        elseif self:ParseLegacy(raw) then
            self.shared.approvedLegacy[raw]=target
            self.shared.trackerOwners[raw]=target
            accepted[#accepted+1]=raw
        end
    end
    local report=self:ImportLegacy(accepted)
    report.otherServer=blocked
    self.db.lastManualImport=report
    self.lastTrackerTable=nil
    return report
end

function C:CloseLegacyImportDialog()
    self:HideChoiceMenu()
    if self.legacyImportWindow then self:SetWindowHidden(self.legacyImportWindow,true) end
    self.legacyImportConfirmed=false
end

function C:RefreshLegacyImportDialog()
    local target=self.legacyImportTarget
    local name=target and Server(target) or C.L("Select server")
    self.legacyImportServer:SetText("|c69D6FF"..name.."  v|r")
    self.legacyImportCount:SetText(string.format(C.L("Records found: %d / Unreadable: %d"),#self.legacyImportRecords,self.legacyImportInvalid))
    self.legacyImportCheck:SetText((self.legacyImportConfirmed and "[X] " or "[ ] ")..string.format(C.L("I confirm all these records belong to %s."),name))
    local enabled=self.legacyImportConfirmed and target==self.world and #self.legacyImportRecords>0
    self.legacyImportCommit:SetEnabled(enabled)
    self.legacyImportCommit:SetNormalFontColor(enabled and 0.91 or 0.45,enabled and 0.8 or 0.45,enabled and 0.52 or 0.45,1)
    self.legacyImportHint:SetText(target and target~=self.world and string.format(C.L("Log into %s to import there. Current server: %s"),name,Server(self.world))
        or #self.legacyImportRecords==0 and C.L("No Crown Crate Tracker history is loaded. Import is optional; Codex records new crates independently.")
        or C.L("Nothing is imported until you confirm. Existing records are preserved; duplicates are skipped."))
end

function C:OpenLegacyImportDialog()
    if not self.shared then
        d(C.L("Crown Crate Codex: history profiles are not ready. Reload the UI and try again."))
        return false
    end
    -- Leave the game-menu scene before showing our standalone window. Its
    -- scene controls can otherwise cover the dialog despite SetTopmost.
    if SCENE_MANAGER then SCENE_MANAGER:Hide("gameMenuInGame") end
    if self.window then self:SetWindowHidden(self.window,true) end
    local ok,problem=pcall(function() self:ShowLegacyImportDialog() end)
    if not ok then
        self.db.diagnostics.importDialogError=tostring(problem)
        d(C.L("Crown Crate Codex: could not open the import dialog: ")..tostring(problem))
    end
    return ok
end

function C:ShowLegacyImportDialog()
    if not self.shared then return end
    self:HideTooltip(); self:HideChoiceMenu()
    self.legacyImportRecords,self.legacyImportInvalid=self:LegacyImportSnapshot()
    self.legacyImportTarget,self.legacyImportConfirmed=nil,false
    if not self.legacyImportWindow then
        local window=WINDOW_MANAGER:CreateTopLevelWindow("CrownCrateCodexLegacyImportDialog")
        window:SetHidden(true)
        self.legacyImportWindow=window
        window:SetDimensions(1000,620); window:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
        window:SetClampedToScreen(true); window:SetMouseEnabled(true)
        window:SetDrawTier(DT_HIGH); window:SetTopmost(true)
        self.UI.Backdrop(window,1)
        local title=self.UI.Label(window,nil,28,22,944,48,"ZoFontWinH2")
        title:SetText(C.L("IMPORT CROWN CRATE TRACKER HISTORY"))
        if self.FitLocalizedLabel then self:FitLocalizedLabel(title) end
        local warning=WINDOW_MANAGER:CreateControl(nil,window,CT_CONTROL)
        warning:SetAnchor(TOPLEFT,window,TOPLEFT,24,86); warning:SetDimensions(952,184)
        self.UI.Backdrop(warning,1)
        local lines={
            C.L("Old Crown Crate Tracker history has no server labels."),
            C.L("Only import if ALL records belong to the server you select."),
            C.L("If you opened crates on both PC_NA and PC_EU, the records"),
            C.L("may be mixed and cannot be reliably separated."),
        }
        for i,text in ipairs(lines) do
            local label=self.UI.Label(warning,nil,20,16+(i-1)*38,912,36,"ZoFontGame")
            label:SetText(text)
            if self.FitLocalizedLabel then self:FitLocalizedLabel(label) end
        end
        self.UI.Label(window,nil,30,292,300,32,"ZoFontGameBold"):SetText(C.L("Import into server:"))
        self.legacyImportServer=self.UI.Button(window,nil,"",340,292,400,function()
            local entries={}
            for _,world in ipairs({"NA Megaserver","EU Megaserver"}) do
                local value=world
                entries[#entries+1]={name=Server(value),callback=function()
                    self.legacyImportTarget=value; self.legacyImportConfirmed=false; self:RefreshLegacyImportDialog()
                end}
            end
            self:ShowChoiceMenu(self.legacyImportServer,C.L("Import into server"),entries)
        end)
        self.UI.Backdrop(self.legacyImportServer,1)
        self.legacyImportCount=self.UI.Label(window,nil,30,344,940,32,"ZoFontGame")
        self.legacyImportCheck=self.UI.Button(window,nil,"",30,408,940,function()
            if self.legacyImportTarget then self.legacyImportConfirmed=not self.legacyImportConfirmed; self:RefreshLegacyImportDialog() end
        end)
        self.legacyImportCheck:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        self.UI.Button(window,nil,C.L("Cancel"),110,500,300,function() self:CloseLegacyImportDialog() end)
        self.legacyImportCommit=self.UI.Button(window,nil,C.L("Import History"),590,500,300,function()
            local report=self:ConfirmLegacyImport(self.legacyImportTarget,self.legacyImportConfirmed,self.legacyImportRecords)
            if not report then return end
            self:CloseLegacyImportDialog()
            d(string.format(C.L("Crown Crate Codex: %d imported into %s, %d already present, %d skipped because they exist on another server."),report.imported,Server(self.world),report.existing,report.otherServer))
            if self.window then self:RefreshUI() end
        end)
        self.legacyImportHint=self.UI.Label(window,nil,30,556,940,58,"ZoFontGame")
        if self.WatchGamepadWindow then self:WatchGamepadWindow(window) end
    end
    self.legacyImportWindow:SetScale(math.min(1,(GuiRoot:GetWidth()-32)/1000,(GuiRoot:GetHeight()-32)/620))
    self:RefreshLegacyImportDialog()
    self:SetWindowHidden(self.legacyImportWindow,false); self.legacyImportWindow:BringWindowToTop()
    if self.SyncGamepad then self:SyncGamepad() end
end
