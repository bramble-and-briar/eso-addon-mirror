local AMW=AutoMasterWrits

function AMW:RunFromMenu(callback)
    SCENE_MANAGER:Show("hud")
    callback()
end

function AMW:OpenActions()
    if not self:EnsureRuntime() then return end
    self:StartJob("actionsUI",function()
        if not self.actionsDialog then self.actionsDialog=LibConsoleDialogs:Create(self.title) end
        local dialog,LHA=self.actionsDialog,LibHarvensAddonSettings
        dialog:RemoveAllSettings()
        local function add(entry) dialog:AddSetting(entry); self:Yield() end
        local function button(label,handler,tooltip)
            add({type=LHA.ST_BUTTON,label=label,buttonText="Select",clickHandler=handler,tooltip=tooltip})
        end
        add({type=LHA.ST_LABEL,label="Version "..self.version.." by xbutch. Work starts only when you select a command."})
        button("Scan backpack",function() self:Scan(true) end)
        button("Open unopened writs",function() self:RunFromMenu(function() self:StartExtraction() end) end)
        button("Review deferred writs",function() self:OpenReview() end)
        button("Queue eligible writs",function() self:QueueEligible() end,"Adds one request at a time to Lazy Writ Crafter's LibLazyCrafting queue.")
        button("Review queued materials",function() self:OpenMaterials() end)
        button("Start or resume guarded delivery",function() self:RunFromMenu(function() self:StartDelivery() end) end)
        button("Stop all work",function() self:StopAll("Stopped. The delivery XP guard is now off.") end)
        button("Show XP status",function() self:ShowXPStatus() end)
        button("Print active effect IDs",function() self:PrintBuffDiagnostics() end)
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
        checkbox("Show operation status on the HUD","showHUD")
        add({type=LHA.ST_SLIDER,label="Free backpack slots to keep",min=2,max=30,step=1,
            getFunction=function() return self.saved.reserveSlots end,
            setFunction=function(value) self.saved.reserveSlots=value end})
        add({type=LHA.ST_SLIDER,label="Unopened writs per batch",min=1,max=200,step=1,
            getFunction=function() return self.saved.extractLimit end,
            setFunction=function(value) self.saved.extractLimit=value end})
        add({type=LHA.ST_LABEL,label="No automatic cost filters for consumable writs. Defer individual writs from their inventory actions."})
        dialog:Show()
    end)
end

function AMW:CreateLauncher()
    if not LibHarvensAddonSettings then return end
    local LHA=LibHarvensAddonSettings
    local panel=LHA:AddAddon(self.title,{allowRefresh=false})
    panel.author=self.author
    panel:AddSetting({type=LHA.ST_BUTTON,label="Open Auto Master Writs",buttonText="Open",
        clickHandler=function() self:OpenActions() end,
        tooltip="Load the controls on request. Nothing is scanned automatically at login or on zone changes."})
    self.settingsPanel=panel
end

function AMW:OpenReview(page)
    if not self:ActivateSession() then return end
    if self:IsBusy() then return self:Alert("Finish or stop the current operation before reviewing writs.") end
    self:StartJob("review",function()
        if not self:ScanWorker() then return end
        self:ArmBanking()
        local rows=self:DeferredRowsWorker()
        local pages=math.max(1,math.ceil(#rows/10))
        page=math.max(1,math.min(page or 1,pages))
        if not self.reviewDialog then self.reviewDialog=LibConsoleDialogs:Create("Review deferred writs") end
        local dialog,LHA=self.reviewDialog,LibHarvensAddonSettings
        dialog:RemoveAllSettings()
        local function add(entry) dialog:AddSetting(entry); self:Yield() end
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
        dialog:Show()
    end)
end

function AMW:InstallInventoryActions()
    self:OwnHook("session",_G,"ZO_InventorySlot_DiscoverSlotActionsFromActionList",nil,function(info,actions)
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
    if not LibRadialMenu then return end
    LibRadialMenu:RegisterAddon(self.name,self.title)
    local icon="/esoui/art/icons/master_writ_blacksmithing.dds"
    local entries={
        {"Open controls","controls",function() self:OpenActions() end},
        {"Start or resume delivery","delivery",function() self:StartDelivery() end},
        {"Review deferred writs","review",function() self:OpenReview() end},
        {"Queue eligible writs","queue",function() self:QueueEligible() end},
        {"Stop all work","stop",function() self:StopAll("Stopped. The delivery XP guard is now off.") end},
    }
    for _,entry in ipairs(entries) do LibRadialMenu:RegisterEntry(self.name,entry[1],entry[2],icon,entry[3]) end
end

