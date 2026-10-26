local AMW=AutoMasterWrits

function AMW:RunFromMenu(callback)
    SCENE_MANAGER:Show("hud")
    callback()
end

function AMW:ActionSettings()
    local rows,LHA={},LibHarvensAddonSettings
    local function add(entry) rows[#rows+1]=entry end
    local function button(label,handler,tooltip)
        add({type=LHA.ST_BUTTON,label=label,buttonText="Select",clickHandler=handler,tooltip=tooltip})
    end
    add({type=LHA.ST_LABEL,label="Version "..self.version.." by xbutch. Work starts only when you select a command."})
    button("Scan backpack",function() self:Scan(true) end,
        "Rebuild the deferred list from visible writs, removing old stored entries. Filters and inclusion choices remain.")
    button("Extract unopened writs",function() self:RunFromMenu(function() self:StartExtraction() end) end,
        "Unpack unopened stacks into sealed writs. No contract is accepted. Start guarded delivery separately when the requested items are crafted.")
    button("Review deferred writs",function() self:OpenReview() end)
    button("Clear deferred list",function() self:ClearDeferred() end,
        "Clear stored deferred entries without moving items. Filters, manual deferrals and inclusion choices remain; scanning applies them again.")
    -- Temporarily disabled; retain the command for a future trial.
    -- button("Queue eligible writs",function() self:QueueEligible() end,"Adds one request at a time to Lazy Writ Crafter's LibLazyCrafting queue.")
    button("Review queued materials",function() self:OpenMaterials() end)
    button("Start or resume guarded delivery",function() self:RunFromMenu(function() self:StartDelivery() end) end)
    button("Stop all work",function() self:StopAll("Stopped. AMW acceptance and XP guards released.") end)
    local function checkbox(label,key,tooltip)
        add({type=LHA.ST_CHECKBOX,label=label,tooltip=tooltip,
            getFunction=function() return self.saved[key] end,
            setFunction=function(value)
                self.saved[key]=value
                self:SetStatus("Setting updated. Select Scan backpack to refresh the writ list.",true)
            end})
    end
    checkbox("Defer Nirnhoned equipment","filterNirnhoned")
    checkbox("Defer Epic Infused and Harmony jewelry","filterEpicJewelry","Legendary jewelry passes this rule.")
    checkbox("Deposit deferred writs when banking","autoDeposit","Bank transfers are armed by your scan, review or opening command, only for this session.")
    add({type=LHA.ST_SLIDER,label="Free backpack slots to keep",min=2,max=30,step=1,
        getFunction=function() return self.saved.reserveSlots end,
        setFunction=function(value) self.saved.reserveSlots=value end})
    add({type=LHA.ST_SLIDER,label="Writs per profession",min=1,max=200,step=1,
        tooltip="Target number of extracted master writs in your backpack for each profession. Existing writs count, including crafted, locked and deferred writs. Banked writs and accepted quests do not count.",
        getFunction=function() return self.saved.extractLimit end,
        setFunction=function(value) self.saved.extractLimit=value end})
    add({type=LHA.ST_LABEL,label="No automatic cost filters for consumable writs. Defer individual writs from their inventory actions."})
    return rows
end

function AMW:IsSettingsShowing()
    local scene=LibHarvensAddonSettings and LibHarvensAddonSettings.scene
    if not self.settingsPanel or not self.settingsPanel.selected or not scene or not scene:IsShowing() then return false end
    local state=scene.GetState and scene:GetState()
    return state~=SCENE_HIDING and state~=SCENE_HIDDEN
end

function AMW:SetSettingsRows(rows,kind)
    local panel=self.settingsPanel
    local selected=panel.selected
    if selected and panel.CleanUp then panel:CleanUp() end
    -- Batch descriptors while deselected so LibHarvens rebuilds its controls once.
    panel.selected=false
    panel:RemoveAllSettings()
    for _,row in ipairs(rows) do panel:AddSetting(row) end
    panel.selected=selected
    self.settingsPage=kind
    if selected and self:IsSettingsShowing() then panel:CreateControls(); panel:RefreshSelection() end
end

function AMW:RefreshSettingsHeader(title)
    local LHA=LibHarvensAddonSettings
    if ZO_GamepadGenericHeader_RefreshData and LHA.scrollList then
        ZO_GamepadGenericHeader_RefreshData(LHA.scrollList.header,
            {titleText=title or self.title,subtitleText=self.version,messageText=self.author})
    end
end

function AMW:OpenActions()
    if not self.settingsPanel then self:RegisterSettings() end
    local LHA=LibHarvensAddonSettings
    if not LHA or not self.settingsPanel then return end
    LHA:Initialize()
    self.settingsPanel:Select()
    self:RefreshSettingsHeader()
    if LHA.scene:IsShowing() then self.settingsPanel:RefreshSelection()
    else SCENE_MANAGER:Push(LHA.scene:GetName()) end
end

function AMW:PresentSettingsPage(title,rows,kind,generation)
    if generation~=self.settingsGeneration or not self:IsSettingsShowing() then return end
    self:InstallSettingsBack()
    table.insert(rows,1,{type=LibHarvensAddonSettings.ST_BUTTON,label="Back to commands",buttonText="Back",
        clickHandler=function() self:OpenActions() end})
    self:SetSettingsRows(rows,kind)
    self:RefreshSettingsHeader(title)
end

function AMW:InstallSettingsBack()
    if self.settingsBackInstalled then return end
    local settings=LibHarvensAddonSettings
    if not settings or type(settings.GoBack)~="function" then return end
    local nativeBack=settings.GoBack
    -- This shared addon method is UI-only. Keep normal Back for other panels,
    -- hidden scenes and our commands page; do not hook SCENE_MANAGER or keybinds.
    settings.GoBack=function(target,...)
        if self:IsSettingsShowing() and self.settingsPage and self.settingsPage~="actions" then
            self:OpenActions()
            return
        end
        return nativeBack(target,...)
    end
    self.settingsBackInstalled=true
end

function AMW:RegisterSettings()
    if self.settingsPanel then return end
    if not LibHarvensAddonSettings then return end
    local LHA=LibHarvensAddonSettings
    local panel=LHA:AddAddon(self.title,{allowRefresh=false})
    panel.author,panel.version=self.author,self.version
    self.settingsPanel=panel
    local selectPanel=panel.Select
    panel.Select=function(target,...)
        if not self:EnsureRuntime() then return end
        self.settingsGeneration=(self.settingsGeneration or 0)+1
        self:SetSettingsRows(self:ActionSettings(),"actions")
        return selectPanel(target,...)
    end
end

function AMW:OpenReview(page)
    if not self:ActivateSession() then return end
    if self:IsBusy() then return self:Alert("Finish or stop the current operation before reviewing writs.") end
    if not self:IsSettingsShowing() then self:OpenActions() end
    local generation=self.settingsGeneration
    self:StartJob("review",function()
        if not self:ScanWorker() then return end
        self:ArmBanking()
        local rows=self:DeferredRowsWorker()
        local pages=math.max(1,math.ceil(#rows/10))
        page=math.max(1,math.min(page or 1,pages))
        local entries,LHA={},LibHarvensAddonSettings
        local function add(entry) entries[#entries+1]=entry; self:Yield() end
        add({type=LHA.ST_LABEL,label=string.format("%d deferred writs. Page %d/%d. Check an entry to include it once.",#rows,page,pages)})
        add({type=LHA.ST_LABEL,label="Included banked writs return on your next personal-bank visit during this session."})
        local first,last=(page-1)*10+1,math.min(page*10,#rows)
        for index=first,last do
            local row=rows[index]
            add({type=LHA.ST_CHECKBOX,label=self:Describe(row),disable=row.unsupported==true,
                tooltip=row.reason.."\n"..row.link..(row.styleId and row.styleId>0 and "\nStyle: "..GetItemStyleName(row.styleId) or ""),
                getFunction=function() return self.saved.overrides[row.uid]==true end,
                setFunction=function(value) self:SetOverride(row.uid,value) end})
        end
        if #rows==0 then add({type=LHA.ST_LABEL,label="No deferred writs recorded."})
        else
            add({type=LHA.ST_BUTTON,label="Include this page",buttonText="Include",clickHandler=function()
                self:StartJob("overrides",function()
                    for index=first,last do self:SetOverride(rows[index].uid,true); self:Yield() end
                    self:Print("Included the displayed writs.")
                end)
            end})
        end
        if page>1 then add({type=LHA.ST_BUTTON,label="Previous page",buttonText="Previous",
            clickHandler=function() self:OpenReview(page-1) end}) end
        if page<pages then add({type=LHA.ST_BUTTON,label="Next page",buttonText="Next",
            clickHandler=function() self:OpenReview(page+1) end}) end
        self:PresentSettingsPage("Review deferred writs",entries,"review",generation)
    end)
end

function AMW:InstallInventoryActions()
    if self.inventoryActionsHookInstalled then return end
    -- The engine must build native callbacks on its trusted stack. A Lua wrapper
    -- around discovery taints actions such as UseItem. Secure post hooks cannot
    -- be removed, so register once on demand and remain inert outside the session.
    SecurePostHook(_G,"ZO_InventorySlot_DiscoverSlotActionsFromActionList",function(info,actions)
        if not self.sessionActive or not self:HasWorkBudget() or type(info)~="table"
            or not actions or type(actions.AddSlotAction)~="function" then return end
        local data=info.dataSource
        if type(data)~="table" then return end
        local bag,slot=data.bagId,data.slotIndex
        if (bag~=BAG_BACKPACK and bag~=BAG_BANK and bag~=BAG_SUBSCRIBER_BANK)
            or type(slot)~="number" or slot<0 then return end
        local record=self:ReadWrit(bag,slot)
        if not record or record.crafted or record.unsupported then return end
        self:Classify(record)
        self.inventory[record.uid]=record
        local uid=record.uid
        if self.saved.overrides[uid] then
            actions:AddSlotAction(SI_AMW_REMOVE_OVERRIDE,function() self:SetOverride(uid,false) end,"keybind4")
        elseif record.reason then
            self.saved.deferred[uid]=record
            actions:AddSlotAction(SI_AMW_INCLUDE,function() self:SetOverride(uid,true) end,"keybind4")
        else
            actions:AddSlotAction(SI_AMW_DEFER,function()
                self.saved.manualDeferred[uid]=true
                self:Classify(record)
                self.saved.deferred[uid]=record
                self:ArmBanking()
                self:Print("Writ deferred for the next personal-bank visit in this session.")
            end,"keybind4")
        end
    end)
    self.inventoryActionsHookInstalled=true
end

function AMW:CreateHUD()
    local window=WINDOW_MANAGER:CreateTopLevelWindow("AutoMasterWritsHUD")
    window:SetDimensions(620,160)
    window:SetAnchor(TOPRIGHT,GuiRoot,TOPRIGHT,-65,105)
    window:SetMouseEnabled(false)
    local background=WINDOW_MANAGER:CreateControl("$(parent)Background",window,CT_BACKDROP)
    background:SetAnchorFill()
    background:SetCenterColor(0.03,0.03,0.03,0.8)
    background:SetEdgeColor(0,0,0,0)
    local label=WINDOW_MANAGER:CreateControl("$(parent)Text",window,CT_LABEL)
    label:SetAnchor(TOPLEFT,window,TOPLEFT,14,10)
    label:SetDimensions(592,140)
    label:SetFont("ZoFontGamepad22")
    label:SetColor(0.95,0.90,0.75,1)
    window:SetHidden(true)
    self.hud,self.hudLabel=window,label
end

function AMW:UpdateHUD()
    if not self.hudEnabled then
        if self.hud then self.hud:SetHidden(true); self.hudHidden=true end
        return
    end
    if not self.saved or not self:HasWorkBudget() then return end
    local busy=self:IsBusy()
    if not self.hud then
        if busy and self.saved.showHUD and not (self.jobs and self.jobs.hud) then
            self:StartJob("hud",function() self:CreateHUD() end)
        end
        return
    end
    local scene=SCENE_MANAGER:GetCurrentScene()
    local name=scene and scene:GetName()
    local hidden=not busy or not self.saved.showHUD or (name~="hud" and name~="hudui")
    if hidden~=self.hudHidden then self.hud:SetHidden(hidden); self.hudHidden=hidden end
    if hidden then return end
    local text=self.title.."\n"..self.status
    if self.delivery then
        local xp=self:GetXPStatus()
        local seconds=math.floor(xp.remaining)
        text=text..string.format("\nXP: %d%% | %d:%02d remaining",xp.percent,math.floor(seconds/60),seconds%60)
    end
    if text~=self.lastHUDText then self.hudLabel:SetText(text); self.lastHUDText=text end
end

function AMW:RegisterRadialMenu()
    if self.radialRegistered then return true end
    if not LibRadialMenu or type(LibRadialMenu.RegisterAddon)~="function"
        or type(LibRadialMenu.RegisterEntry)~="function" then return false end
    LibRadialMenu:RegisterAddon(self.name,self.title)
    local icon="/esoui/art/icons/master_writ_blacksmithing.dds"
    local entries={
        {"Open controls","controls",function() self:OpenActions() end,"Open Auto Master Writs commands and settings."},
        {"Scan backpack","scan",function() self:Scan(true) end,"Rebuild the deferred list from visible writs and count backpack master writs. Filters and inclusion choices remain."},
        {"Extract unopened writs","open",function() self:StartExtraction() end,"Extract unopened master writs up to the backpack target for each profession, counting existing writs."},
        {"Start or resume delivery","delivery",function() self:StartDelivery() end,"Accept marked-crafted contracts with the 150% XP guard, then press A at Rolis."},
        {"Review deferred writs","review",function() self:OpenReview() end,"Review excluded writs and include selected items for another batch."},
        {"Clear deferred list","clearDeferred",function() self:ClearDeferred() end,"Clear stored deferred entries without moving items. Filters, manual deferrals and inclusion choices remain; scanning applies them again."},
        -- {"Queue eligible writs","queue",function() self:QueueEligible() end,"Queue eligible master writs with Lazy Writ Crafter for crafting."},
        {"Review queued materials","materials",function() self:OpenMaterials() end,"Review available material requirements for queued master writs."},
        {"Stop all work","stop",function() self:StopAll("Stopped. AMW acceptance and XP guards released.") end,"Cancel Auto Master Writs operations and release acceptance and XP guards."},
    }
    -- Keep entry IDs stable so previously assigned radial slots continue to work.
    for _,entry in ipairs(entries) do LibRadialMenu:RegisterEntry(self.name,entry[1],entry[2],icon,entry[3],entry[4]) end
    self.radialRegistered=true
    return true
end

