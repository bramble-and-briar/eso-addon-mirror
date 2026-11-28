local C = CrownCrateCodex
function C:ManageWindow(window)
    self.managedWindows=self.managedWindows or {}
    if not self.managedWindows[window] and SCENE_MANAGER and SCENE_MANAGER.RegisterTopLevel
        and SCENE_MANAGER.ShowTopLevel and SCENE_MANAGER.HideTopLevel then
        -- Shown top levels retain the cursor without locking UI mode. A lock
        -- prevents ESO's Escape/menu handler from reaching HideTopLevels.
        SCENE_MANAGER:RegisterTopLevel(window,false)
        self.managedWindows[window]=true
    end
end
function C:SetWindowHidden(window,hidden)
    if not window then return end
    -- Native top-level ownership keeps chat focus loss from recapturing the
    -- cursor, and lets ESO preserve UI mode for other open panels on close.
    self.visibilityDepth=(self.visibilityDepth or 0)+1
    if self.managedWindows and self.managedWindows[window] and SCENE_MANAGER
        and SCENE_MANAGER.ShowTopLevel and SCENE_MANAGER.HideTopLevel then
        if hidden then SCENE_MANAGER:HideTopLevel(window) else SCENE_MANAGER:ShowTopLevel(window) end
    else window:SetHidden(hidden) end
    self.visibilityDepth=self.visibilityDepth-1
    -- Acquire our controller layer after ESO has acquired its native UI layer.
    if self.visibilityDepth==0 and self.SyncGamepad then self:SyncGamepad() end
end
function C:ScopeHelp()
    return C.L("Lifetime or Session statistics\nLifetime: all saved openings eligible for your selected crate and import switches.\nSession: openings recorded directly by Codex since the last UI load. Logging in or using /reloadui starts a new session.\nClick the selector to switch which percentages are displayed. Neither choice deletes or resets your saved lifetime history.\nThe history list remains available in both modes.")
end
function C:ImportHelp(kind)
    if kind=="tiers" then
        return C.L("Include imported rarity tiers in percentages\nOFF: rarity percentages use openings recorded directly by Codex. Your old history stays visible.\nON: imported openings with verified rarity data also count.\nUnknown rarities are excluded. Only fully classified eligible openings enter rarity percentages; the panel shows coverage.\nThis is separate from including imported openings in item and bonus-card rates.")
    end
    return C.L("Include imported openings in percentages\nON: old Tracker openings count toward item and bonus-card rates.\nOFF: percentages use native Codex openings only. All old history stays visible.\nImported rarity percentages also require the separate imported-tiers switch.")
end
function C:ActionHint(text)
    local color=self.db.settings.actionColor
    return string.format("|c%02X%02X%02X%s|r",math.floor(color[1]*255+0.5),math.floor(color[2]*255+0.5),math.floor(color[3]*255+0.5),text)
end
function C:RaiseWindow()
    if not self.window then return end
    if self.HideChoiceMenu then self:HideChoiceMenu() end
    self.window:SetDrawTier(self.db.settings.alwaysOnTop and DT_HIGH or DT_MEDIUM)
    self.window:SetTopmost(self.db.settings.alwaysOnTop)
    self.window:BringWindowToTop()
end
function C:SetBrowseMode(mode)
    if mode~="Pages" and mode~="Scrolling" then return end
    self.db.settings.browseMode=mode
    self.page,self.scrollOffset=1,0
    if self.window then self:RefreshUI() end
end
function C:ScrollRows(delta)
    if self.db.settings.browseMode~="Scrolling" then return end
    local nextOffset=math.max(0,math.min(self.maxScrollOffset or 0,(self.scrollOffset or 0)-delta*self.db.settings.scrollStep))
    if nextOffset==self.scrollOffset then return end
    self.scrollOffset=nextOffset
    self:RefreshUI(true)
end
function C:MoveRows(direction)
    if self.db.settings.browseMode=="Scrolling" then
        self.scrollOffset=math.max(0,math.min(self.maxScrollOffset or 0,(self.scrollOffset or 0)+direction*self.pageSize))
    else self.page=math.max(1,math.min(self.totalPages or 1,self.page+direction)) end
    self:RefreshUI(true)
end
function C:RunManualImport()
    return self:OpenLegacyImportDialog()
end
