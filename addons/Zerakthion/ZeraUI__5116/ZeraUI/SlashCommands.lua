-- Zera UI: slash commands (/zera, /zeraui) and custom slot tracking command helpers.
function ZeraUIAttachCommands(A,UI)
    local Tracker=ZeraUITracker
    local PRIMARY,BACKUP=HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP
    local flash,clearFlash=UI.flash,UI.clearFlash

    local function printHelp()
        d("Zera UI: /zera (or /zeraui) on | off | replace | preview | scale 0.9 | y -110 | animations | track | ids | attributes")
    end
    local function trackHelp()
        d("Zera UI: /zera track  - open custom tracking menu")
        d("/zera track front 2 martial  |  /zera track back 4 status")
        d("/zera track front 2 217353 5 auto  |  /zera track back 4 217358 10 cast")
        d("/zera track front 2 217353 0 effect  |  /zera untrack front 2  |  /zera ids")
    end
    local function barCategory(bar)
        if bar=="front" or bar=="f" then return PRIMARY end
        if bar=="back" or bar=="b" then return BACKUP end
        if bar=="active" or bar=="a" then return GetActiveHotbarCategory() end
    end

    function A:SaveTrackSlot(category,number,effect,duration,mode,index)
        local key,id=Tracker.IdentifySlot(number+2,category)
        if number>5 then return false,"Ultimates keep their built-in tracking." end
        local row=self.categories and (self.categories[1]==category and 1 or self.categories[2]==category and 2) or nil
        local state=row and self.slots[row][number]
        if state and state.abilityKey==key then
            local lock=self:TrackingLock(state)
            if lock then return false,"This skill is locked by another feature." end
            if (index or 1)==1 and self:MiddleBlocked(state) then return false,"The middle timer can't be used for this skill." end
        end
        local ok,result=self.tracker:SetRule(key,effect,duration,mode,index)
        if not ok then return false,result end
        self:RefreshSlots()
        -- Never report success for a rule another feature removed at once.
        if not self.tracker.rules[key] then return false,"This skill is locked by another feature." end
        return true,string.format("%s (%d) -> effect %d, %gs, %s",GetSlotName(number+2,category) or "Skill",id,result.effect,result.duration,result.mode)
    end

    function A:ClearTrackSlot(category,number,index)
        local key,id=Tracker.IdentifySlot(number+2,category)
        if not key then return false,"No skill in that slot." end
        self.tracker:ClearRule(key,index)
        self:RefreshSlots()
        return true,index and "Effect entry removed (remaining effects shift up)." or "Default tracking restored: "..tostring(GetSlotName(number+2,category) or id)
    end

    -- The tracking window lives in Studio.lua. Older entry points open it.
    function A:OpenTrackMenu() self:OpenStudio() end
    function A:CloseTrackMenu() if self.CloseStudio then self:CloseStudio() end end

    function A:TrackCommand(cmd,arg)
        if cmd=="track" and arg=="" then
            if self.menuFailed then trackHelp(); return end
            local ok,err=pcall(function() self:OpenTrackMenu() end)
            if not ok then
                self.menuFailed=true
                d("Zera UI tracking menu: "..tostring(err)); trackHelp()
            end
            return
        end
        if cmd=="ids" then
            for _,category in ipairs({PRIMARY,BACKUP}) do
                for i=1,5 do
                    local key,id=Tracker.IdentifySlot(i+2,category)
                    local rule=self.tracker:RuleFor(key,id)
                    if key then d(string.format("%s %d: %s | %d%s",category==PRIMARY and "front" or "back",i,GetSlotName(i+2,category) or "Skill",id,rule and (" -> "..rule.effect.." ("..rule.mode..")") or "")) end
                end
            end
            return
        end
        local bar,slot,rest=arg:match("^(%S+)%s+(%d+)%s*(.-)%s*$")
        local category,n=barCategory(bar),tonumber(slot)
        if not category or not n or n<1 or n>5 then trackHelp(); return end
        if cmd=="untrack" then local _,msg=self:ClearTrackSlot(category,n); d(msg); return end
        local preset=Tracker.presets[rest]
        local effect,duration,mode
        if preset then effect,duration,mode=preset.effect,preset.duration,preset.mode
        else effect,duration,mode=rest:match("^(%d+)%s+(%S+)%s*(%S*)$"); if mode=="" then mode="auto" end end
        local _,message=self:SaveTrackSlot(category,n,effect,duration,mode)
        d(message)
    end

    function A:Command(input)
        local cmd,arg=input:match("^(%S*)%s*(.-)%s*$")
        if cmd=="sets" then
            if arg=="gear" then self.setCooldowns:ReportGear(); return end
            if arg=="zen" then self.setCooldowns:ReportZen(); return end
            if arg=="probe" then self.setCooldowns:StartProbe(); return end
            if arg=="probe stop" then self.setCooldowns:StopProbe(); return end
            if arg=="on" or arg=="off" then self.settings.setCooldownEnabled=arg=="on"; self:ApplySettings()
            elseif arg=="preview" then
                if not self.settings.setCooldownEnabled then self.settings.setCooldownEnabled=true; self:ApplySettings() end
                self.setCooldowns:ToggleDemo()
            elseif arg=="refresh" then self.setCooldowns:Refresh(true) end
            self.setCooldowns:Report(); return
        end
        if cmd=="attributes" then
            d("Zera UI attribute bars: "..tostring(self.attrStatus or "Not initialized"))
            return
        end
        if cmd=="finder" or cmd=="tracking" then self:OpenStudio(); return end
        if cmd=="track" or cmd=="untrack" or cmd=="ids" then self:TrackCommand(cmd,arg); return end
        if cmd=="on" then self.settings.enabled=true; self.previewWasDisabled=nil
        elseif cmd=="off" then
            if self.editing then self:FinishEdit(false) end
            local wasPreview=self.preview
            self.settings.enabled=false; self.preview=false; self.previewWasDisabled=nil
            if wasPreview then self.slotRefreshPending=true end
        elseif cmd=="replace" then self.settings.replaceNative=not self.settings.replaceNative; d("Replace native: "..tostring(self.settings.replaceNative))
        elseif cmd=="animations" then self.settings.animations=not self.settings.animations; d("Animations: "..tostring(self.settings.animations)); self:ApplySettings(); return
        elseif cmd=="scale" and tonumber(arg) then self:SetHudSize("scale",math.max(.5,math.min(1.6,tonumber(arg)))); self:ApplySettings(); return
        elseif cmd=="y" and tonumber(arg) then self.settings.y=tonumber(arg); self:AnchorHudRoot()
        elseif cmd=="preview" then
            if self.gamepadSuspended and not self.preview then return end
            self.preview=not self.preview
            self:ResetExpiryState()
            if self.preview then
                self:ClearCast()
                self.synergy.offer=nil; self:WatchSynergy(nil)
                self.previewWasDisabled=not self.settings.enabled or nil
                self.settings.enabled=true
                if self.previewWasDisabled then self:SyncNativeTimers() end
                self:UpdatePreview()
                flash(self.slots[1][4]); flash(self.ultimate); self:FadeSynergy(self.settings.showSynergy,true); self:FlashSynergy()
            else
                for r=1,2 do for i=1,5 do
                    local s=self.slots[r][i]
                    self:SetToggle(s,false); self:SetProc(s,false); s.hasActiveDisplay=nil
                end end
                clearFlash(self.synergy); self.synergy.offer=nil; self:WatchSynergy(nil); self.synergy.hold=nil
                self.lastSynergy=nil; self.synergy.transition=nil; self.synergy.container:SetHidden(true); self.synergy.container:SetAlpha(0)
                self:ClearCast()
                self.cast:SetHidden(true); self.castShown=nil
                if self.previewWasDisabled and not self.editing then
                    self.settings.enabled=false; self.previewWasDisabled=nil; self:SyncNativeTimers()
                end
                self:RefreshSlots(); self:RefreshSynergy()
            end
        else printHelp() end
        self:ApplyVisibility()
        if cmd=="on" or cmd=="off" then self:SyncNativeTimers() end
    end
end
