local SMT = {}
SMT.name = "SorcererMasteryTracker"
SMT.version = "1.3"
SMT.svName = "SorcererMasteryTrackerSavedVars"

local MASTERIES = {
    conservation = { name="Conservation of Energy", skillId=263870, effectId=263901, kind="proc" },
    font         = { name="Font of Power",          skillId=263871, effectId=263878, kind="timer", duration=10 },
    static       = { name="Static Reverberation",   skillId=263872, effectId=263928, kind="proc" },
    calculated   = { name="Calculated Defense",     skillId=263873, effectId=268274, kind="timer", duration=20 },
    sphere       = { name="Sphere of Influence",    skillId=263874, effectId=268275, kind="timer", duration=12 },
}
local ORDER = {"conservation","font","static","calculated","sphere"}

local defaults = {
    enabled=true, hideOOC=true, locked=true, iconSize=52,
    showNames=true,
    textColor={1,1,1,1}, x=0, y=180,
    mastery={conservation=true,font=true,static=true,calculated=true,sphere=true},
}

local function Chat(msg) d("|c66CCFF[Sorc Mastery]|r "..tostring(msg)) end
local function IsTracked(key)
    return SMT.sv.enabled and SMT.sv.mastery[key] and SMT.selected[key]
end

local function SetInactive(key)
    local c=SMT.controls and SMT.controls[key]
    if not c then return end
    c.texture:SetDesaturation(1)
    c.texture:SetAlpha(0.42)
    c.countdown:SetText("")
    c.activeUntil=nil
end

local function SetActive(key,seconds)
    local c=SMT.controls and SMT.controls[key]
    if not c then return end
    c.texture:SetDesaturation(0)
    c.texture:SetAlpha(1)
    if seconds and seconds>0 then c.activeUntil=GetFrameTimeSeconds()+seconds end
end

function SMT:FindMasterySkillIndices()
    self.skillIndices={}
    for skillType=1,GetNumSkillTypes() do
        for skillLineIndex=1,GetNumSkillLines(skillType) do
            for abilityIndex=1,GetNumSkillAbilities(skillType,skillLineIndex) do
                local id=GetSkillAbilityId(skillType,skillLineIndex,abilityIndex)
                for key,data in pairs(MASTERIES) do
                    if id==data.skillId then
                        self.skillIndices[key]={skillType,skillLineIndex,abilityIndex}
                    end
                end
            end
        end
    end
end

function SMT:ScanSelectedMasteries()
    if not self.skillIndices or not next(self.skillIndices) then self:FindMasterySkillIndices() end
    local changed=false
    for _,key in ipairs(ORDER) do
        local idx=self.skillIndices[key]
        local purchased=false
        if idx then
            local _,_,_,_,_,isPurchased=GetSkillAbilityInfo(idx[1],idx[2],idx[3])
            purchased=(isPurchased==true)
        end
        if self.selected[key]~=purchased then
            self.selected[key]=purchased
            changed=true
            if not purchased then SetInactive(key) end
        end
    end
    if changed then
        self:Layout()
        self:RefreshEventRegistration()
    end
end

function SMT:Layout()
    if not self.container then return end
    local size=self.sv.iconSize
    local rowGap=math.max(6,math.floor(size*0.12))
    local nameGap=math.max(8,math.floor(size*0.15))
    local nameWidth=math.max(180,math.floor(size*4.2))
    local visible={}

    for _,key in ipairs(ORDER) do
        local c=self.controls[key]
        c:SetDimensions(size+nameGap+nameWidth,size)
        c.texture:ClearAnchors()
        c.texture:SetAnchor(LEFT,c,LEFT,0,0)
        c.texture:SetDimensions(size,size)

        c.countdown:ClearAnchors()
        c.countdown:SetAnchor(CENTER,c.texture,CENTER,0,0)
        c.countdown:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick",math.max(16,math.floor(size*0.40))))
        local col=self.sv.textColor
        c.countdown:SetColor(col[1],col[2],col[3],col[4])

        c.nameLabel:ClearAnchors()
        c.nameLabel:SetAnchor(LEFT,c.texture,RIGHT,nameGap,0)
        c.nameLabel:SetDimensions(nameWidth,size)
        c.nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        c.nameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        c.nameLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin",math.max(12,math.floor(size*0.23))))
        c.nameLabel:SetColor(col[1],col[2],col[3],col[4])
        c.nameLabel:SetHidden(not self.sv.showNames)

        if self.sv.mastery[key] and self.selected[key] then
            visible[#visible+1]=key
        else
            c:SetHidden(true)
        end
    end

    local width=size
    if self.sv.showNames then width=size+nameGap+nameWidth end
    local height=#visible*size+math.max(0,#visible-1)*rowGap
    self.container:SetDimensions(width,math.max(size,height))

    for i,key in ipairs(visible) do
        local c=self.controls[key]
        c:ClearAnchors()
        c:SetAnchor(TOPLEFT,self.container,TOPLEFT,0,(i-1)*(size+rowGap))
        c:SetHidden(false)
    end
    self:RefreshVisibility()
end

function SMT:RefreshVisibility()
    if not self.container then return end
    -- Do not let the periodic visibility refresh fight the HUD scene fragment.
    -- When inventory/map/other menus hide the HUD fragment, keep the tracker hidden.
    if self.hudFragment and not self.hudFragment:IsShowing() then
        self.container:SetHidden(true)
        return
    end
    if IsUnitDead("player") then self.container:SetHidden(true) return end
    if not self.sv.enabled then self.container:SetHidden(true) return end
    local any=false
    for _,key in ipairs(ORDER) do
        if self.sv.mastery[key] and self.selected[key] then any=true break end
    end
    if not any then self.container:SetHidden(true) return end
    if self.sv.hideOOC and not IsUnitInCombat("player") and not self.testVisible then
        self.container:SetHidden(true)
    else
        self.container:SetHidden(false)
    end
end

function SMT:UpdateLock()
    self.container:SetMouseEnabled(not self.sv.locked)
    self.container:SetMovable(not self.sv.locked)
end

function SMT:SavePosition()
    self.sv.x=self.container:GetLeft()-GuiRoot:GetLeft()
    self.sv.y=self.container:GetTop()-GuiRoot:GetTop()
end

function SMT:RestorePosition()
    self.container:ClearAnchors()
    self.container:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,self.sv.x,self.sv.y)
end

function SMT:CreateUI()
    self.controls={}
    local wm=WINDOW_MANAGER
    self.container=wm:CreateTopLevelWindow("SorcererMasteryTrackerWindow")

    -- ESOUI Wiki recommended pattern: attach our TLC to the HUD/HUDUI scenes.
    -- This makes ESO hide/show the entire tracker automatically with the HUD.
    self.hudFragment = ZO_HUDFadeSceneFragment:New(self.container, nil, 0)
    HUD_SCENE:AddFragment(self.hudFragment)
    HUD_UI_SCENE:AddFragment(self.hudFragment)

    self.container:SetClampedToScreen(true)
    self.container:SetHandler("OnMoveStop",function() SMT:SavePosition() end)

    for _,key in ipairs(ORDER) do
        local data=MASTERIES[key]
        local c=wm:CreateControl("SorcererMasteryTracker_"..key,self.container,CT_CONTROL)

        local tex=wm:CreateControl("SorcererMasteryTracker_"..key.."_Texture",c,CT_TEXTURE)
        tex:SetTexture(GetAbilityIcon(data.skillId))
        tex:SetTextureCoords(0,1,0,1)
        c.texture=tex

        local cd=wm:CreateControl("SorcererMasteryTracker_"..key.."_Countdown",c,CT_LABEL)
        cd:SetAnchor(CENTER,tex,CENTER,0,0)
        cd:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        cd:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        c.countdown=cd

        local name=wm:CreateControl("SorcererMasteryTracker_"..key.."_Name",c,CT_LABEL)
        name:SetAnchor(TOP,tex,BOTTOM,0,2)
        name:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        name:SetText(data.name)
        c.nameLabel=name

        self.controls[key]=c
        SetInactive(key)
    end


    self:RestorePosition()
    self:UpdateLock()
    self:Layout()
end

function SMT:ShowProc(key)
    if not IsTracked(key) then return end
    local c=self.controls[key]
    SetActive(key)
    c.flashUntil=GetFrameTimeSeconds()+0.75
end

function SMT:StartTimer(key,seconds)
    if IsTracked(key) then SetActive(key,seconds or MASTERIES[key].duration) end
end

function SMT:OnUpdate()
    self:RefreshVisibility()
    if IsUnitDead("player") then return end
    local now=GetFrameTimeSeconds()
    for _,key in ipairs(ORDER) do
        local c=self.controls[key]
        local data=MASTERIES[key]
        if data.kind=="proc" then
            if c.flashUntil and now>=c.flashUntil then c.flashUntil=nil SetInactive(key) end
        elseif c.activeUntil then
            local remain=c.activeUntil-now
            if remain<=0 then SetInactive(key) else c.countdown:SetText(tostring(math.ceil(remain))) end
        end
    end
end

function SMT:OnCombatState(inCombat)
    if inCombat==self.inCombat then return end
    self.inCombat=inCombat
    if not inCombat then
        for _,key in ipairs(ORDER) do SetInactive(key) end
    end
    self:RefreshVisibility()
end

function SMT:RegisterProcEvent(key)
    local data=MASTERIES[key]
    local eventName=self.name.."_Proc_"..key
    EVENT_MANAGER:RegisterForEvent(eventName,EVENT_COMBAT_EVENT,function()
        SMT:ShowProc(key)
    end)
    EVENT_MANAGER:AddFilterForEvent(eventName,EVENT_COMBAT_EVENT,REGISTER_FILTER_ABILITY_ID,data.effectId)
    EVENT_MANAGER:AddFilterForEvent(eventName,EVENT_COMBAT_EVENT,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER)
end

function SMT:UnregisterProcEvent(key)
    EVENT_MANAGER:UnregisterForEvent(self.name.."_Proc_"..key,EVENT_COMBAT_EVENT)
end

function SMT:RegisterTimerEvent(key)
    local data=MASTERIES[key]
    local eventName=self.name.."_Timer_"..key
    EVENT_MANAGER:RegisterForEvent(eventName,EVENT_EFFECT_CHANGED,
        function(_,changeType,effectSlot,effectName,unitTag,beginTime,endTime,
                 stackCount,iconName,buffType,effectType,abilityType,statusEffectType,
                 unitName,unitId,abilityId,sourceType)
            -- Filters already guarantee: this effect ID, on our player, sourced by us.
            if changeType==EFFECT_RESULT_GAINED
                or changeType==EFFECT_RESULT_UPDATED
                or changeType==EFFECT_RESULT_FULL_REFRESH then
                local duration=math.max(0,(endTime or 0)-(beginTime or 0))
                SMT:StartTimer(key,duration>0 and duration or data.duration)
            elseif changeType==EFFECT_RESULT_FADED then
                SetInactive(key)
            end
        end)

    EVENT_MANAGER:AddFilterForEvent(eventName,EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_ABILITY_ID,data.effectId,
        REGISTER_FILTER_UNIT_TAG,"player",
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER)
end

function SMT:UnregisterTimerEvent(key)
    EVENT_MANAGER:UnregisterForEvent(self.name.."_Timer_"..key,EVENT_EFFECT_CHANGED)
end

function SMT:RefreshEventRegistration()
    -- Only listen for a mastery while the addon, its toggle, and that selected mastery need it.
    for _,key in ipairs({"conservation","static"}) do
        self:UnregisterProcEvent(key)
        if IsTracked(key) then self:RegisterProcEvent(key) end
    end

    for _,key in ipairs({"font","calculated","sphere"}) do
        self:UnregisterTimerEvent(key)
        if IsTracked(key) then self:RegisterTimerEvent(key) end
    end
end

function SMT:TestMastery(key)
    -- Test buttons intentionally preview even an unselected mastery.
    if not self.sv.enabled or not self.sv.mastery[key] then return end
    local wasSelected=self.selected[key]
    self.selected[key]=true
    self.testVisible=true
    self:Layout()
    if MASTERIES[key].kind=="timer" then
        self:StartTimer(key,MASTERIES[key].duration)
        zo_callLater(function()
            SMT.selected[key]=wasSelected
            SMT.testVisible=false
            SetInactive(key)
            SMT:Layout()
        end,MASTERIES[key].duration*1000+500)
    else
        self:ShowProc(key)
        zo_callLater(function()
            SMT.selected[key]=wasSelected
            SMT.testVisible=false
            SetInactive(key)
            SMT:Layout()
        end,1200)
    end
end

function SMT:CreateSettings()
    if not LibAddonMenu2 then
        Chat("LibAddonMenu-2.0 not found. Tracker still works; settings panel unavailable.")
        return
    end
    local LAM=LibAddonMenu2
    LAM:RegisterAddonPanel("SorcererMasteryTrackerOptions",{
        type="panel",name="Sorcerer Mastery Tracker",displayName="Sorcerer Mastery Tracker",
        author="WifeyRytic",version=self.version,registerForRefresh=true,registerForDefaults=true,
    })
    local options={
        {type="checkbox",name="Enable Sorcerer Mastery Tracker",
         getFunc=function() return SMT.sv.enabled end,
         setFunc=function(v) SMT.sv.enabled=v SMT:RefreshEventRegistration() SMT:RefreshVisibility() end,
         default=defaults.enabled},
        {type="checkbox",name="Hide Out of Combat",
         getFunc=function() return SMT.sv.hideOOC end,
         setFunc=function(v) SMT.sv.hideOOC=v SMT:RefreshVisibility() end,
         default=defaults.hideOOC},
        {type="checkbox",name="Lock Tracker",
         getFunc=function() return SMT.sv.locked end,
         setFunc=function(v) SMT.sv.locked=v SMT:UpdateLock() end,
         default=defaults.locked},
        {type="checkbox",name="Show Mastery Names",
         getFunc=function() return SMT.sv.showNames end,
         setFunc=function(v) SMT.sv.showNames=v SMT:Layout() end,
         default=defaults.showNames},
        {type="slider",name="Icon Size",min=28,max=100,step=1,
         getFunc=function() return SMT.sv.iconSize end,
         setFunc=function(v) SMT.sv.iconSize=v SMT:Layout() end,
         default=defaults.iconSize},
        {type="colorpicker",name="Countdown / Name / Summary Text Color",
         getFunc=function() return unpack(SMT.sv.textColor) end,
         setFunc=function(r,g,b,a) SMT.sv.textColor={r,g,b,a} SMT:Layout() end,
         default=defaults.textColor},
        {type="header",name="Masteries"},
    }
    for _,key in ipairs(ORDER) do
        local k=key
        local data=MASTERIES[k]
        options[#options+1]={
            type="checkbox",name=data.name,
            tooltip="Allows this mastery to display when it is selected in your Class Mastery skill line.",
            getFunc=function() return SMT.sv.mastery[k] end,
            setFunc=function(v)
                SMT.sv.mastery[k]=v SetInactive(k) SMT:Layout() SMT:RefreshEventRegistration()
            end,
            default=defaults.mastery[k],
        }
        options[#options+1]={
            type="button",name="Test "..data.name,
            func=function() SMT:TestMastery(k) end,width="half",
        }
    end
    options[#options+1]={
        type="button",name="Reset Position",
        func=function() SMT.sv.x=defaults.x SMT.sv.y=defaults.y SMT:RestorePosition() end,
    }
    LAM:RegisterOptionControls("SorcererMasteryTrackerOptions",options)
end

function SMT:Initialize()
    self.sv=ZO_SavedVars:NewAccountWide(self.svName,1,nil,defaults)
    if self.sv.showNames==nil then self.sv.showNames=true end
    self.selected={}
    self.inCombat=IsUnitInCombat("player")

    self:FindMasterySkillIndices()
    self:ScanSelectedMasteries()
    self:CreateUI()

    EVENT_MANAGER:RegisterForEvent(self.name.."_CombatState",EVENT_PLAYER_COMBAT_STATE,
        function(_,inCombat) SMT:OnCombatState(inCombat) end)

    self:RefreshEventRegistration()

    EVENT_MANAGER:RegisterForUpdate(self.name.."_Update",100,function() SMT:OnUpdate() end)
    EVENT_MANAGER:RegisterForUpdate(self.name.."_MasteryScan",500,function() SMT:ScanSelectedMasteries() end)

    self:CreateSettings()
    Chat("v"..self.version.." loaded.")
end

local function OnAddOnLoaded(_,addonName)
    if addonName~=SMT.name then return end
    EVENT_MANAGER:UnregisterForEvent(SMT.name,EVENT_ADD_ON_LOADED)
    SMT:Initialize()
end
EVENT_MANAGER:RegisterForEvent(SMT.name,EVENT_ADD_ON_LOADED,OnAddOnLoaded)
