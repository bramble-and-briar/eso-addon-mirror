------------------------------------------------------------
-- RYTIC ACTION BAR v3.0.0 - module-isolated runtime lifecycle
-- Classic two-row action bar for RyticTankTools.
------------------------------------------------------------
RyticTank = RyticTank or {}
local RyticTank=RyticTank
RyticTank.ActionBar = RyticTank.ActionBar or {}
local A=RyticTank.ActionBar
local EM,WM=EVENT_MANAGER,WINDOW_MANAGER

-- Cache hot API/standard-library references used by action/GCD update paths.
-- Hotfix: native-bar-independent tooltips + stable custom-bar visibility when ZOS action bar is disabled.
local GetFrameTimeSeconds=GetFrameTimeSeconds
local GetSlotCooldownInfo=GetSlotCooldownInfo
local GetAbilityCastInfo=GetAbilityCastInfo
local math_max=math.max
local math_min=math.min
local pairs=pairs

local FIRST,LAST=3,7
local UPDATE_NAME="RyticActionBarUpdate"
-- Latched death state. Once ESO reports player death, no visibility callback may
-- show the custom bar until ESO explicitly reports the player alive again.
A.playerDeadLatched=A.playerDeadLatched or false
local function actionBarPlayerDead()
    return A.playerDeadLatched or IsUnitDead("player")
end
local function now() return GetFrameTimeSeconds() end

local GCD_UPDATE_NAME="RyticActionBarGCDSweep"
local DEFAULT_GCD_MS=1000
local MIN_SWEEP_MS=100
local MAX_CAST_SWEEP_MS=12000
A.gcdStart=0
A.gcdDuration=1.0
A.gcdButton=nil
A.gcdAbilityId=0
A.gcdSlot=nil
A.gcdBar=nil
A.readyPulseButton=nil
A.readyPulseStart=0
local READY_PULSE_DURATION=0.22


-- Native-style radial cooldown presentation.
-- ESO/FAB users are accustomed to a dark radial cooldown wipe over the skill icon.
-- Keep Rytic's brief gold completion flash as the only custom completion cue.
local function setGCDProgress(btn,pct)
    if not btn or not btn.gcdCooldown then return end
    pct=math_max(0,math_min(1,pct or 0))
    local remain=math_max(0,(A.gcdDuration or 1)*(1-pct))
    btn.gcdCooldown:SetHidden(remain<=0)
    if remain>0 then
        -- Cooldown controls use milliseconds for the radial wipe.
        btn.gcdCooldown:StartCooldown(remain*1000, A.gcdDuration*1000, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_UNTIL, false)
    end
end

local function clearGCDSweep(btn)
    if not btn then return end
    btn.ryticGcdActive=false
    if btn.gcdCooldown then
        btn.gcdCooldown:ResetCooldown()
        btn.gcdCooldown:SetHidden(true)
    end
    if btn.gcdReadyGlow then btn.gcdReadyGlow:SetHidden(true) end
end

local function startReadyPulse(btn)
    if not btn or not btn.gcdReadyGlow then return end
    A.readyPulseButton=btn
    A.readyPulseStart=now()
    btn.gcdReadyGlow:SetHidden(false)
    btn.gcdReadyGlow:SetEdgeColor(1,.78,.08,1)
end

local function updateReadyPulse()
    local btn=A.readyPulseButton
    if not btn or not btn.gcdReadyGlow then return end
    local elapsed=now()-A.readyPulseStart
    if elapsed>=READY_PULSE_DURATION then
        btn.gcdReadyGlow:SetHidden(true)
        A.readyPulseButton=nil
        return
    end
    local pct=elapsed/READY_PULSE_DURATION
    local alpha=1-pct
    btn.gcdReadyGlow:SetEdgeColor(1,.78,.08,alpha)
end

local function getSlotTimingMs(slot,bar,abilityId)
    -- Prefer ESO's live slot cooldown. For the normal action lock this is the
    -- same timing source players see on the native action bar.
    if GetSlotCooldownInfo then
        local remain,duration=GetSlotCooldownInfo(slot,bar)
        remain=tonumber(remain) or 0
        duration=tonumber(duration) or 0
        if duration>=MIN_SWEEP_MS and duration<=MAX_CAST_SWEEP_MS and remain>0 then
            return math_max(remain,duration)
        end
    end

    -- Keep the existing cast/channel fallback for abilities where ESO does not
    -- expose useful slot cooldown timing at the activation event.
    if abilityId and abilityId~=0 and GetAbilityCastInfo then
        local a,b,c,d,e=GetAbilityCastInfo(abilityId)
        local vals={a,b,c,d,e}
        local best=0
        for _,v in ipairs(vals) do
            if type(v)=="number" and v>=MIN_SWEEP_MS and v<=MAX_CAST_SWEEP_MS then
                best=math_max(best,v)
            end
        end
        if best>0 then return best end
    end

    return DEFAULT_GCD_MS
end

local function finishSweep()
    if A.gcdButton then
        A.gcdButton.ryticGcdActive=false
        if A.gcdButton.gcdCooldown then
            A.gcdButton.gcdCooldown:ResetCooldown()
            A.gcdButton.gcdCooldown:SetHidden(true)
        end
        startReadyPulse(A.gcdButton)
    end
    EM:UnregisterForUpdate(GCD_UPDATE_NAME)
end

local function cancelSweep(leaveComplete)
    EM:UnregisterForUpdate(GCD_UPDATE_NAME)
    if A.gcdButton then
        A.gcdButton.ryticGcdActive=false
        if A.gcdButton.gcdCooldown then
            A.gcdButton.gcdCooldown:ResetCooldown()
            A.gcdButton.gcdCooldown:SetHidden(true)
        end
        if leaveComplete then startReadyPulse(A.gcdButton) end
    end
end

local function beginGCDSweep(btn,slot,bar,abilityId)
    if not btn then return end
    if A.gcdButton then clearGCDSweep(A.gcdButton) end
    if A.readyPulseButton and A.readyPulseButton~=A.gcdButton then
        clearGCDSweep(A.readyPulseButton)
    end
    A.readyPulseButton=nil
    clearGCDSweep(btn)
    A.gcdButton=btn
    A.gcdSlot=slot
    A.gcdBar=bar
    A.gcdAbilityId=abilityId or 0
    A.gcdStart=now()
    A.gcdDuration=math_max(MIN_SWEEP_MS,getSlotTimingMs(slot,bar,A.gcdAbilityId))/1000
    btn.ryticGcdActive=true

    -- Start one native-style radial wipe. We only poll ESO's live timing below
    -- to finish/correct it; we do not redraw the radial every frame.
    if btn.gcdCooldown then
        btn.gcdCooldown:SetHidden(false)
        btn.gcdCooldown:StartCooldown(A.gcdDuration*1000,A.gcdDuration*1000,CD_TYPE_RADIAL,CD_TIME_TYPE_TIME_UNTIL,false)
    end

    EM:UnregisterForUpdate(GCD_UPDATE_NAME)
    EM:RegisterForUpdate(GCD_UPDATE_NAME,16,function()
        local b=A.gcdButton
        if not b or not A.root or A.root:IsHidden() then return end

        if A.gcdSlot and A.gcdBar and GetSlotCooldownInfo then
            local remain,duration=GetSlotCooldownInfo(A.gcdSlot,A.gcdBar)
            remain=tonumber(remain) or 0
            duration=tonumber(duration) or 0
            if remain>0 and duration>=MIN_SWEEP_MS and duration<=MAX_CAST_SWEEP_MS then
                local live=math_max(remain,duration)/1000
                if live>0 and math.abs(live-A.gcdDuration)>.05 then
                    A.gcdDuration=live
                    A.gcdStart=now()
                    if b.gcdCooldown then
                        b.gcdCooldown:StartCooldown(live*1000,live*1000,CD_TYPE_RADIAL,CD_TIME_TYPE_TIME_UNTIL,false)
                    end
                end
            end
        end

        if (now()-A.gcdStart)>=A.gcdDuration then finishSweep() end
    end)
end

local function defaults()
    RyticTank.saved=RyticTank.saved or {}
    RyticTank.saved.actionBar=RyticTank.saved.actionBar or {
        enabled=true, scale=0.85, x=12, y=-665, showKeys=true, unlocked=false
    }
    return RyticTank.saved.actionBar
end

local function slotId(slot,bar)
    local id=GetSlotBoundId(slot,bar)
    if GetSlotType(slot,bar)==ACTION_TYPE_CRAFTED_ABILITY and GetAbilityIdForCraftedAbilityId then
        id=GetAbilityIdForCraftedAbilityId(id)
    end
    return id or 0
end

-- Defensive buff warning.
local MAJOR_RESOLVE_EFFECT_ID=61694

local function isMajorResolveEffect(name,abilityId)
    if tonumber(abilityId)==MAJOR_RESOLVE_EFFECT_ID then return true end
    if not name then return false end
    return zo_strformat("<<z:1>>",name):find("major resolve",1,true)~=nil
end

local function hasMajorResolve()
    local n=GetNumBuffs and GetNumBuffs("player") or 0
    local currentTime=GetFrameTimeSeconds()
    for i=1,n do
        local name,_,ending,_,_,_,_,_,_,_,abilityId=GetUnitBuffInfo("player",i)
        if isMajorResolveEffect(name,abilityId)
            and (not ending or ending==0 or ending>currentTime) then
            return true
        end
    end
    return false
end

A.resolveSlots={}

local NIGHTBLADE_CLASS_ID=3
local shadowAbilityCache={}

local function isNightblade()
    return GetUnitClassId and GetUnitClassId("player")==NIGHTBLADE_CLASS_ID
end

local function rebuildShadowAbilityCache()
    shadowAbilityCache={}
    if not isNightblade() then return end
    if not GetNumSkillLines or not GetNumSkillAbilities or not GetSkillAbilityInfo then return end

    local classType=SKILL_TYPE_CLASS or 1
    for line=1,(GetNumSkillLines(classType) or 0) do
        local lineName=GetSkillLineInfo and GetSkillLineInfo(classType,line) or ""
        lineName=lineName and zo_strformat("<<z:1>>",lineName) or ""
        if lineName:find("shadow",1,true) then
            for abilityIndex=1,(GetNumSkillAbilities(classType,line) or 0) do
                local _,_,_,isPassive,_,isPurchased,progressionIndex=
                    GetSkillAbilityInfo(classType,line,abilityIndex)
                if not isPassive and isPurchased and progressionIndex and GetAbilityProgressionAbilityId then
                    for morph=0,2 do
                        for rank=1,4 do
                            local aid=GetAbilityProgressionAbilityId(progressionIndex,morph,rank)
                            if aid and aid~=0 then shadowAbilityCache[aid]=true end
                        end
                    end
                end
            end
        end
    end
end

local function abilityIsNightbladeShadow(abilityId)
    if not isNightblade() or not abilityId or abilityId==0 then return false end
    if shadowAbilityCache[abilityId] then return true end

    -- Correct ESO API chain:
    -- abilityId -> progressionIndex -> skillType/skillLine/abilityIndex.
    if GetAbilityProgressionXPInfoFromAbilityId and GetSkillAbilityIndicesFromProgressionIndex then
        local hasProgression,progressionIndex=GetAbilityProgressionXPInfoFromAbilityId(abilityId)
        if hasProgression and progressionIndex then
            local skillType,skillLineIndex=GetSkillAbilityIndicesFromProgressionIndex(progressionIndex)
            if skillType and skillLineIndex and skillType==(SKILL_TYPE_CLASS or 1) then
                local lineName=GetSkillLineInfo(skillType,skillLineIndex)
                lineName=lineName and zo_strformat("<<z:1>>",lineName) or ""
                if lineName:find("shadow",1,true) then
                    shadowAbilityCache[abilityId]=true
                    return true
                end
            end
        end
    end
    return false
end

local function isNightbladePreferredResolveAbility(abilityId)
    if not isNightblade() or not abilityId or abilityId==0 then return false end
    local name=GetAbilityName and GetAbilityName(abilityId) or ""
    name=name and zo_strformat("<<z:1>>",name) or ""
    -- Blur is the base skill; Mirage and Phantasmal Escape are its morphs.
    return name=="blur" or name=="mirage" or name=="phantasmal escape"
end

local function findSlottedNightbladePreferredResolve()
    local bars={HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP}
    for _,bar in ipairs(bars) do
        for slot=FIRST,LAST do
            local id=slotId(slot,bar)
            if isNightbladePreferredResolveAbility(id) then
                return slot,bar,id
            end
        end
    end
    return nil,nil,nil
end

local function rememberResolveSource(slot,bar,id)
    if not slot or not bar or not id or id==0 then return end
    -- Only the slot that most recently caused Major Resolve owns the warning.
    -- Keeping older sources made multiple squares turn red after one buff expired.
    A.resolveSlots={}
    A.resolveSlots[tostring(bar)..":"..tostring(slot)]=id
end

local function slotIsResolveSource(slot,bar,id)
    local key=tostring(bar)..":"..tostring(slot)
    return A.resolveSlots[key]==id
end

local function makeText(parent,font,anchor,rel,relpt,x,y)
    local l=WM:CreateControl(nil,parent,CT_LABEL)
    l:SetFont(font); l:SetAnchor(anchor,parent,relpt or anchor,x or 0,y or 0)
    return l
end

local function clearRyticSlotTooltip(control)
    if control and control.activeTooltip then
        ClearTooltip(control.activeTooltip)
        control.activeTooltip=nil
    end
end

local function showRyticSlotTooltip(control,slot,bar)
    if not control or not slot or bar==nil then return end
    clearRyticSlotTooltip(control)

    -- Ask the assigned hotbar slot directly, as in Ash's working hover build.
    -- This does not look up a visible native ActionButton.
    local manager=ACTION_BAR_ASSIGNMENT_MANAGER
    local hotbar=manager and manager.GetHotbar and manager:GetHotbar(bar)
    local slotData=hotbar and hotbar.GetSlotData and hotbar:GetSlotData(slot)
    local tooltip=slotData and slotData.GetKeyboardTooltipControl and slotData:GetKeyboardTooltipControl()
    if tooltip and slotData.SetKeyboardTooltip then
        control.activeTooltip=tooltip
        InitializeTooltip(tooltip,control,BOTTOM,0,-5,TOP)
        slotData:SetKeyboardTooltip(tooltip)
        return
    end

    -- The Rytic slot also retains its ability ID for a tooltip when ESO's own
    -- action bar is disabled and no slot tooltip control is available.
    local abilityId=tonumber(control.ryticAbilityId) or 0
    if abilityId<=0 then abilityId=slotId(slot,bar) end
    if abilityId and abilityId>0 and AbilityTooltip and AbilityTooltip.SetAbilityId then
        control.activeTooltip=AbilityTooltip
        InitializeTooltip(AbilityTooltip,control,TOP,0,-8,BOTTOM)
        AbilityTooltip:SetAbilityId(abilityId)
    end
end

local function startRyticBarDragFromHit(self,button)
    if button~=MOUSE_BUTTON_INDEX_LEFT or not defaults().unlocked or not A.root then return end
    clearRyticSlotTooltip(self)
    A.root:StartMoving()
end

local function stopRyticBarDragFromHit(self,button)
    if button~=MOUSE_BUTTON_INDEX_LEFT or not defaults().unlocked or not A.root then return end
    A.root:StopMovingOrResizing()
    local sv=defaults()
    sv.left=A.root:GetLeft()
    sv.top=A.root:GetTop()
end

local function attachRyticSkillHover(slotControl)
    -- A full-slot hit target makes hover reliable over the icon and lets the
    -- same surface drag the bar when unlocked, as verified in Ash's build.
    local hit=WM:CreateControl(nil,slotControl,CT_CONTROL)
    hit:SetAnchorFill(slotControl)
    hit:SetDrawLevel(100)
    hit:SetMouseEnabled(true)
    hit.ryticOwner=slotControl
    hit:SetHandler("OnMouseEnter",function(self)
        local owner=self.ryticOwner
        showRyticSlotTooltip(self,owner.ryticSlot,owner.ryticBar)
    end)
    hit:SetHandler("OnMouseExit",function(self) clearRyticSlotTooltip(self) end)
    hit:SetHandler("OnMouseDown",startRyticBarDragFromHit)
    hit:SetHandler("OnMouseUp",stopRyticBarDragFromHit)
    slotControl.ryticHoverHit=hit
    slotControl:SetMouseEnabled(false)
end

local function showRyticQuickslotTooltip(control)
    if not control then return end
    local activeIndex=GetCurrentQuickslot and GetCurrentQuickslot() or nil
    if not activeIndex then return end

    clearRyticSlotTooltip(control)

    local link=GetSlotItemLink and GetSlotItemLink(activeIndex,HOTBAR_CATEGORY_QUICKSLOT_WHEEL) or ""
    if link and link~="" then
        control.activeTooltip=ItemTooltip
        InitializeTooltip(ItemTooltip,control,BOTTOM,0,-5,TOP)
        ItemTooltip:SetLink(link)
        return
    end

    -- Fallback for non-item quickslots through the same exact hotbar slotData route.
    showRyticSlotTooltip(control,activeIndex,HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
end

local function makeSlot(parent,index)
    local c=WM:CreateControl(nil,parent,CT_BACKDROP)
    c:SetDimensions(50,50); c:SetCenterColor(.015,.02,.025,.88); c:SetEdgeColor(0,0,0,0)
    c.icon=WM:CreateControl(nil,c,CT_TEXTURE); c.icon:SetAnchorFill(); c.icon:SetTextureCoords(0.06,.94,0.06,.94)
    c.border=WM:CreateControl(nil,c,CT_BACKDROP)
    c.border:SetAnchor(TOPLEFT,c,TOPLEFT,1,1); c.border:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,-1,-1)
    c.border:SetCenterColor(0,0,0,0); c.border:SetEdgeColor(1,1,1,1)
    c.border:SetEdgeTexture("",1,1,3,0); c.border:SetMouseEnabled(false)
    -- Clean active-skill cue: blue outline only, no white square/backdrop.
    c.activeGlow=WM:CreateControl(nil,c,CT_BACKDROP)
    c.activeGlow:SetAnchor(TOPLEFT,c,TOPLEFT,1,1)
    c.activeGlow:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,-1,-1)
    c.activeGlow:SetCenterColor(0,0,0,0)
    c.activeGlow:SetEdgeTexture("",1,1,3,0)
    c.activeGlow:SetEdgeColor(.08,.55,1,1)
    c.activeGlow:SetDrawLevel(10)
    c.activeGlow:SetMouseEnabled(false)
    c.activeGlow:SetHidden(true)
    c.resolveGlow=WM:CreateControl(nil,c,CT_BACKDROP)
    c.resolveGlow:SetAnchor(TOPLEFT,c,TOPLEFT,-4,-4)
    c.resolveGlow:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,4,4)
    c.resolveGlow:SetCenterColor(0,0,0,0)
    c.resolveGlow:SetEdgeTexture("",1,1,5,0)
    c.resolveGlow:SetMouseEnabled(false); c.resolveGlow:SetHidden(true)
    c.shade=WM:CreateControl(nil,c,CT_BACKDROP); c.shade:SetAnchorFill(); c.shade:SetCenterColor(0,0,0,0); c.shade:SetEdgeColor(0,0,0,0)
    c.timer=makeText(c,"ZoFontWinH3",CENTER,c,CENTER,0,0); c.timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    c.stack=makeText(c,"ZoFontGameBold",TOPRIGHT,c,TOPRIGHT,-3,2); c.stack:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    c.key=makeText(c,"ZoFontGameSmall",BOTTOM,c,BOTTOM,0,-1); c.key:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    c.index=index
    -- Native-style radial GCD overlay, matching ESO/FAB visual language.
    c.gcdCooldown=WM:CreateControl(nil,c,CT_COOLDOWN)
    c.gcdCooldown:SetAnchorFill(c)
    c.gcdCooldown:SetDrawLevel(20)
    c.gcdCooldown:SetMouseEnabled(false)
    -- Match ESO's ZO_ActionButton cooldown presentation:
    -- ZO_DefaultCooldown radial at alpha 0.7.  Do NOT tint CT_COOLDOWN;
    -- ESO greys the icon itself while the radial control supplies the rolling wipe.
    c.gcdCooldown:SetAlpha(.70)
    c.gcdCooldown:SetHidden(true)
    c.gcdReadyGlow=WM:CreateControl(nil,c,CT_BACKDROP)
    c.gcdReadyGlow:SetAnchor(TOPLEFT,c,TOPLEFT,-5,-5)
    c.gcdReadyGlow:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,5,5)
    c.gcdReadyGlow:SetCenterColor(0,0,0,0)
    c.gcdReadyGlow:SetEdgeTexture("",1,1,5,0)
    c.gcdReadyGlow:SetDrawLevel(30)
    c.gcdReadyGlow:SetMouseEnabled(false)
    c.gcdReadyGlow:SetHidden(true)
    clearGCDSweep(c)
    attachRyticSkillHover(c)
    return c
end

-- Rytic replaces the visual action bar, but ESO's native controls still own
-- protected combat/keybind behavior. Hide the native artwork without disabling it.
local nativeHiddenControls={}
local nativeMouseStates={}

local function setMouseRecursive(control,enabled,seen)
    if not control or seen[control] then return end
    seen[control]=true

    if control.SetMouseEnabled then
        if enabled==false then
            if nativeMouseStates[control]==nil then
                nativeMouseStates[control]=(control.IsMouseEnabled and control:IsMouseEnabled()) and true or false
            end
            control:SetMouseEnabled(false)
        else
            local old=nativeMouseStates[control]
            if old~=nil then
                control:SetMouseEnabled(old)
                nativeMouseStates[control]=nil
            end
        end
    end

    if control.GetNumChildren and control.GetChild then
        for i=1,control:GetNumChildren() do
            setMouseRecursive(control:GetChild(i),enabled,seen)
        end
    end
end

local function setNativeBarMouseEnabled(enabled)
    local seen={}
    setMouseRecursive(ZO_ActionBar1,enabled,seen)
    setMouseRecursive(ZO_ActionBar1WeaponSwap,enabled,seen)
    setMouseRecursive(ZO_ActionBar1UltimateSlot,enabled,seen)
    setMouseRecursive(ZO_ActionBar1Quickslot,enabled,seen)
end

local function rememberAndHide(c,hidden)
    if not c then return end
    if hidden then
        if nativeHiddenControls[c]==nil then nativeHiddenControls[c]=c:GetAlpha() end
        c:SetAlpha(0)
    else
        c:SetAlpha(nativeHiddenControls[c] or 1)
        nativeHiddenControls[c]=nil
    end
end

local function setNativeBarHidden(hidden)
    -- Keep the native action bar alive for protected input, but when its artwork is
    -- hidden do not let its invisible buttons steal mouseover from Rytic's visible bar.
    setNativeBarMouseEnabled(not hidden)
    -- Keep ZO_ActionBar1 itself alive: ESO's keybind/quickslot wheel logic depends on it.
    -- Hide the visual children while leaving the protected root enabled.
    if ZO_ActionBar1 then
        local n=ZO_ActionBar1:GetNumChildren()
        for i=1,n do
            local c=ZO_ActionBar1:GetChild(i)
            if c then rememberAndHide(c,hidden) end
        end
    end
    rememberAndHide(ZO_ActionBar1WeaponSwap,hidden)
    rememberAndHide(ZO_ActionBar1UltimateSlot,hidden)
    rememberAndHide(ZO_ActionBar1Quickslot,hidden)
end

-- ESO owns resurrection, death recap, interaction prompts, synergy prompts,
-- keybind prompts, and their anchors/draw order. Do not scan, move, re-anchor,
-- re-parent, or decorate any of those native controls from the custom action bar.
--
-- The custom bar follows ESO's action-bar lifecycle through the HUD fragment and
-- ZO_ActionBar1 effective-visibility hooks below. This keeps protected/native
-- interaction UI independent from Rytic's visual replacement.


local function alertPulse()
    -- Smooth bright pulse, roughly twice per second.
    local t=GetFrameTimeSeconds()
    return .45 + .55 * ((math.sin(t * 7.5) + 1) * .5)
end


local function potionAlertActive()
    local sv=RyticTank and RyticTank.saved and RyticTank.saved.resources
    if not sv then return false end

    local getPct=RyticTank.Resources and RyticTank.Resources.GetPercent
    if type(getPct)~="function" then return false end

    local base=tonumber(sv.potionThreshold) or 30
    local hpLimit=tonumber(sv.potionHealthThreshold) or base
    local resourceLimit=tonumber(sv.potionResourceThreshold) or base

    return getPct(POWERTYPE_HEALTH)<=hpLimit
        or getPct(POWERTYPE_STAMINA)<=resourceLimit
        or getPct(POWERTYPE_MAGICKA)<=resourceLimit
end

local function refreshQuickslot(btn)
    if not btn or not btn.icon then return end

    local icon=""
    local count=0
    local activeIndex = GetCurrentQuickslot and GetCurrentQuickslot() or nil

    if activeIndex then
        icon = GetSlotTexture(activeIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) or ""
        if icon=="" and GetSlotItemLink then
            local link=GetSlotItemLink(activeIndex,HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
            if link and link~="" and GetItemLinkIcon then icon=GetItemLinkIcon(link) or "" end
        end
        if GetSlotItemCount then count=GetSlotItemCount(activeIndex,HOTBAR_CATEGORY_QUICKSLOT_WHEEL) or 0 end
    end

    if icon~="" then
        btn.icon:SetTexture(icon)
        btn.icon:SetAlpha(1)
    else
        btn.icon:SetTexture("/esoui/art/actionbar/quickslotbg.dds")
        btn.icon:SetAlpha(.65)
    end
    if btn.count then
        btn.count:SetText(tostring(count))
        btn.count:SetHidden(false)
    end

    local remaining=0
    if GetSlotCooldownInfo and activeIndex then
        -- ESO returns remaining cooldown in milliseconds for the quickslot.
        local remain=select(1,GetSlotCooldownInfo(activeIndex,HOTBAR_CATEGORY_QUICKSLOT_WHEEL))
        remaining=tonumber(remain) or 0
    end

    local remainingSeconds=remaining/1000

    -- Ignore ESO's short global/action cooldown on the quickslot.
    -- Only treat a cooldown longer than 2 seconds as the actual potion cooldown.
    local potionCooldown = remainingSeconds>2 and remainingSeconds or 0

    if btn.timer then
        if potionCooldown>0 then
            btn.timer:SetText(potionCooldown<10 and string.format("%.1f",potionCooldown) or tostring(math.ceil(potionCooldown)))
        else
            btn.timer:SetText("")
        end
    end

    btn.icon:SetDesaturation(potionCooldown>0 and .55 or 0)
    btn.icon:SetAlpha(potionCooldown>0 and .60 or (icon~="" and 1 or .65))

    -- Dedicated top-layer potion alert. Nothing else in the action-bar refresh
    -- can overwrite this overlay.
    local alert=potionAlertActive()
    local p=alertPulse()

    -- Drive the normal visible quickslot frame directly.
    if btn.border then
        if alert then
            btn.border:SetEdgeColor(.72 + (.28*p), .02, 1, 1)
        else
            btn.border:SetEdgeColor(1,1,1,1)
        end
    end

    -- Keep the existing overlay as a second purple layer when present.
    if btn.potionAlertBorder then
        btn.potionAlertBorder:SetHidden(not alert)
        if alert then
            btn.potionAlertBorder:SetEdgeColor(.72 + (.28*p), .02, 1, 1)
        end
    end
    if btn.potionReadyGlow then
        btn.potionReadyGlow:SetHidden(not alert)
        if alert then
            btn.potionReadyGlow:SetEdgeColor(.72 + (.28*p), .02, 1, .55 + (.45*p))
        end
    end
    if btn.potionReadyGlow2 then
        btn.potionReadyGlow2:SetHidden(not alert)
        if alert then
            btn.potionReadyGlow2:SetEdgeColor(1, .05 + (.30*p), 1, .25 + (.70*p))
        end
    end
end

local OAKENSOUL_NAME="Oakensoul Ring"

local function hasOakensoulEquipped()
    for slot=EQUIP_SLOT_NECK,EQUIP_SLOT_RING2 do
        local link=GetItemLink(BAG_WORN,slot)
        if link and link~="" then
            local hasSet,setName=GetItemLinkSetInfo(link,true)
            if hasSet and setName==OAKENSOUL_NAME then return true end
        end
    end
    return false
end

-- Active display hotbar can be a weapon bar or a temporary/transformation bar
-- (Werewolf, Vampire transformation, and other ESO-provided active hotbars).
local function getDisplayHotbar()
    local active=GetActiveHotbarCategory()
    if active==nil then return HOTBAR_CATEGORY_PRIMARY end
    return active
end

local function isWeaponHotbar(bar)
    return bar==HOTBAR_CATEGORY_PRIMARY or bar==HOTBAR_CATEGORY_BACKUP
end

local function applyBarMode()
    if not A.root or not A.front or not A.back then return end
    local oneBar=hasOakensoulEquipped()
    A.oneBarMode=oneBar

    local active=getDisplayHotbar()
    -- Temporary/transformation bars render through the front visual row.
    local activeGroup=(active==HOTBAR_CATEGORY_BACKUP) and A.back or A.front
    local inactiveGroup=(active==HOTBAR_CATEGORY_BACKUP) and A.front or A.back

    if oneBar then
        -- Oakensoul: physically move the active five skills into one clean row.
        -- Hide the unused weapon row completely so no stale backdrops/children
        -- remain below the visible bar.
        for i=FIRST,LAST do
            local n=i-FIRST
            local shown=activeGroup[i]
            local hidden=inactiveGroup[i]

            shown:ClearAnchors()
            shown:SetAnchor(TOPLEFT,A.root,TOPLEFT,n*54,0)
            shown:SetHidden(false)
            shown:SetAlpha(1)

            hidden:SetHidden(true)
            hidden:SetAlpha(0)
        end

        A.root:SetDimensions(430,66)

        if A.ult then
            A.ult:ClearAnchors()
            A.ult:SetAnchor(LEFT,activeGroup[LAST],RIGHT,18,0)
            A.ult:SetHidden(false)
        end
        if A.quick then
            A.quick:ClearAnchors()
            A.quick:SetAnchor(RIGHT,activeGroup[FIRST],LEFT,-12,0)
            A.quick:SetHidden(false)
        end
    else
        -- Standard Rytic two-row layout. Restore both groups to their canonical
        -- positions after Oakensoul is removed.
        for i=FIRST,LAST do
            local n=i-FIRST
            A.front[i]:ClearAnchors()
            A.front[i]:SetAnchor(TOPLEFT,A.root,TOPLEFT,n*54,0)
            A.front[i]:SetHidden(false)
            A.front[i]:SetAlpha(1)

            A.back[i]:ClearAnchors()
            A.back[i]:SetAnchor(TOPLEFT,A.root,TOPLEFT,n*54,56)
            A.back[i]:SetHidden(false)
            A.back[i]:SetAlpha(1)
        end

        A.root:SetDimensions(430,112)

        if A.ult then
            A.ult:ClearAnchors()
            A.ult:SetAnchor(LEFT,A.front[LAST],RIGHT,18,28)
            A.ult:SetHidden(false)
        end
        if A.quick then
            A.quick:ClearAnchors()
            A.quick:SetAnchor(RIGHT,A.front[FIRST],LEFT,-12,28)
            A.quick:SetHidden(false)
        end
    end
end

function A.Create()
    if A.root then return end
    local sv=defaults()
    local root=WM:CreateTopLevelWindow("RyticActionBarRoot"); A.root=root
    if ZO_ActionBar1 then
        if root.SetDrawTier and ZO_ActionBar1.GetDrawTier then
            root:SetDrawTier(ZO_ActionBar1:GetDrawTier())
        end
        if root.SetDrawLayer and ZO_ActionBar1.GetDrawLayer then
            root:SetDrawLayer(ZO_ActionBar1:GetDrawLayer())
        end
        if root.SetDrawLevel and ZO_ActionBar1.GetDrawLevel then
            root:SetDrawLevel((ZO_ActionBar1:GetDrawLevel() or 0)+1)
        end
    end
    -- ESOUI HUD fragment: automatically hide this HUD when menus open.
    local hudFragment=ZO_HUDFadeSceneFragment:New(root,nil,0)
    HUD_SCENE:AddFragment(hudFragment)
    HUD_UI_SCENE:AddFragment(hudFragment)
    A.hudFragment=hudFragment
    root:SetDimensions(430,112)
    root:ClearAnchors()
    if sv.left ~= nil and sv.top ~= nil then
        -- Absolute screen coordinates survive reloads regardless of anchor type.
        root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.left, sv.top)
    else
        -- First-run fallback only. Once moved, left/top become authoritative.
        root:SetAnchor(BOTTOM, GuiRoot, BOTTOM, sv.x or 12, sv.y or -665)
    end
    root:SetScale(sv.scale or 0.85); root:SetMouseEnabled(true); root:SetMovable(true); root:SetClampedToScreen(true)
    root:SetHandler("OnMouseDown",function(self,button) if button==MOUSE_BUTTON_INDEX_LEFT and defaults().unlocked then self:StartMoving() end end)
    root:SetHandler("OnMouseUp",function(self,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and defaults().unlocked then
            self:StopMovingOrResizing()
            local d=defaults()
            d.left=self:GetLeft()
            d.top=self:GetTop()
        end
    end)
    root:SetHandler("OnMoveStop",function(self)
        local d=defaults()
        d.left=self:GetLeft()
        d.top=self:GetTop()
    end)

    A.front={}; A.back={}
    for i=FIRST,LAST do
        local n=i-FIRST
        local f=makeSlot(root,i); f.ryticSlot=i; f.ryticBar=HOTBAR_CATEGORY_PRIMARY; f:SetAnchor(TOPLEFT,root,TOPLEFT,n*54,0); A.front[i]=f
        local b=makeSlot(root,i); b.ryticSlot=i; b.ryticBar=HOTBAR_CATEGORY_BACKUP; b:SetAnchor(TOPLEFT,root,TOPLEFT,n*54,56); A.back[i]=b
    end

    -- Ultimate: deliberately larger and separated from the five normal skills.
    A.ult=makeSlot(root,8)
    A.ult.ryticSlot=8
    A.ult.ryticBar=getDisplayHotbar()
    A.ult:SetDimensions(78,78)
    A.ult:SetAnchor(LEFT,A.front[LAST],RIGHT,18,28)
    A.ult.border:SetEdgeTexture("",1,1,4,0)

    -- Second outer frame used only when the ultimate is ready.
    A.ult.readyGlow=WM:CreateControl(nil,A.ult,CT_BACKDROP)
    A.ult.readyGlow:SetAnchor(TOPLEFT,A.ult,TOPLEFT,-9,-9)
    A.ult.readyGlow:SetAnchor(BOTTOMRIGHT,A.ult,BOTTOMRIGHT,9,9)
    A.ult.readyGlow:SetCenterColor(0,0,0,0)
    A.ult.readyGlow:SetEdgeTexture("",1,1,8,0)
    A.ult.readyGlow:SetMouseEnabled(false)
    A.ult.readyGlow:SetHidden(true)
    A.ult.readyGlow2=WM:CreateControl(nil,A.ult,CT_BACKDROP)
    A.ult.readyGlow2:SetAnchor(TOPLEFT,A.ult,TOPLEFT,-15,-15)
    A.ult.readyGlow2:SetAnchor(BOTTOMRIGHT,A.ult,BOTTOMRIGHT,15,15)
    A.ult.readyGlow2:SetCenterColor(0,0,0,0)
    A.ult.readyGlow2:SetEdgeTexture("",1,1,5,0)
    A.ult.readyGlow2:SetMouseEnabled(false)
    A.ult.readyGlow2:SetHidden(true)

    A.quick=makeSlot(root,9); A.quick:SetDimensions(64,64); A.quick:SetAnchor(RIGHT,A.front[FIRST],LEFT,-12,28)
    -- Equipped quickslot consumable quantity.
    A.quick.count=makeText(A.quick,"ZoFontWinH3",TOPRIGHT,A.quick,TOPRIGHT,-2,1)
    A.quick.count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    A.quick.count:SetText("0")
    A.quick.potionAlertBorder=WM:CreateControl(nil,A.quick,CT_BACKDROP)
    A.quick.potionAlertBorder:SetAnchor(TOPLEFT,A.quick,TOPLEFT,1,1)
    A.quick.potionAlertBorder:SetAnchor(BOTTOMRIGHT,A.quick,BOTTOMRIGHT,-1,-1)
    A.quick.potionAlertBorder:SetCenterColor(0,0,0,0)
    A.quick.potionAlertBorder:SetEdgeTexture("",1,1,4,0)
    A.quick.potionAlertBorder:SetMouseEnabled(false)
    A.quick.potionAlertBorder:SetHidden(true)

    A.quick.potionReadyGlow=WM:CreateControl(nil,A.quick,CT_BACKDROP)
    A.quick.potionReadyGlow:SetAnchor(TOPLEFT,A.quick,TOPLEFT,-9,-9)
    A.quick.potionReadyGlow:SetAnchor(BOTTOMRIGHT,A.quick,BOTTOMRIGHT,9,9)
    A.quick.potionReadyGlow:SetCenterColor(0,0,0,0)
    A.quick.potionReadyGlow:SetEdgeTexture("",1,1,8,0)
    A.quick.potionReadyGlow:SetMouseEnabled(false)
    A.quick.potionReadyGlow:SetHidden(true)
    A.quick.potionReadyGlow2=WM:CreateControl(nil,A.quick,CT_BACKDROP)
    A.quick.potionReadyGlow2:SetAnchor(TOPLEFT,A.quick,TOPLEFT,-15,-15)
    A.quick.potionReadyGlow2:SetAnchor(BOTTOMRIGHT,A.quick,BOTTOMRIGHT,15,15)
    A.quick.potionReadyGlow2:SetCenterColor(0,0,0,0)
    A.quick.potionReadyGlow2:SetEdgeTexture("",1,1,5,0)
    A.quick.potionReadyGlow2:SetMouseEnabled(false)
    A.quick.potionReadyGlow2:SetHidden(true)

    A.quick:SetMouseEnabled(false)
    local quickHit=WM:CreateControl(nil,A.quick,CT_CONTROL)
    quickHit:SetAnchorFill(A.quick)
    quickHit:SetDrawLevel(100)
    quickHit:SetMouseEnabled(true)
    A.quick.ryticHoverHit=quickHit
    quickHit:SetHandler("OnMouseEnter",function(self) showRyticQuickslotTooltip(self) end)
    quickHit:SetHandler("OnMouseExit",function(self) clearRyticSlotTooltip(self) end)
    quickHit:SetHandler("OnMouseDown",function(self,button)
        if defaults().unlocked then startRyticBarDragFromHit(self,button)
        elseif button==MOUSE_BUTTON_INDEX_LEFT and ZO_ActionBar_OnActionButtonDown then
            ZO_ActionBar_OnActionButtonDown(9)
        end
    end)
    quickHit:SetHandler("OnMouseUp",function(self,button)
        if defaults().unlocked then stopRyticBarDragFromHit(self,button)
        elseif button==MOUSE_BUTTON_INDEX_LEFT and ZO_ActionBar_OnActionButtonUp then
            ZO_ActionBar_OnActionButtonUp(9)
        end
    end)
    applyBarMode()
    root:SetHidden(not sv.enabled)
    setNativeBarHidden(sv.enabled)
end

local function updateButton(btn,slot,bar,isActive)
    local id=slotId(slot,bar)
    btn.ryticAbilityId=id or 0
    if btn.ryticHoverHit then btn.ryticHoverHit.ryticAbilityId=btn.ryticAbilityId end
    if id==0 then
        btn.icon:SetTexture(""); btn.timer:SetText(""); btn.stack:SetText("")
        if btn.resolveGlow then btn.resolveGlow:SetHidden(true) end
        if btn.activeGlow then btn.activeGlow:SetHidden(true) end
        if btn.border then btn.border:SetEdgeColor(0,0,0,0) end
        return
    end
    local icon=GetAbilityIcon(id)
    btn.icon:SetTexture(icon or "")
    -- Dim the skills on the weapon bar that is NOT currently equipped.
    -- This affects only the icon, not the white/blue/red border state.
    -- ESO ActionButton.lua desaturates the icon while cooldown is shown.
    -- Preserve Rytic's inactive-bar treatment when this button is not the active bar.
    if btn.ryticGcdActive and isActive then
        btn.icon:SetDesaturation(1)
        btn.icon:SetAlpha(1)
    else
        btn.icon:SetDesaturation(isActive and 0 or .72)
        btn.icon:SetAlpha(isActive and 1 or .42)
    end

    local remain=0
    if GetActionSlotEffectTimeRemaining then
        remain=(GetActionSlotEffectTimeRemaining(slot,bar) or 0)/1000
    end

    local isResolveSource=slotIsResolveSource(slot,bar,id)
    local resolveActive=isResolveSource and hasMajorResolve()
    local resolveMissing=isResolveSource and not resolveActive
    local r,g,b=1,1,1
    if resolveMissing then
        local p=alertPulse()
        r,g,b=1, .04 + (.28*p), .04 + (.28*p)
        if btn.resolveGlow then
            btn.resolveGlow:SetHidden(false)
            btn.resolveGlow:SetEdgeColor(1,.02,.02,.55 + (.45*p))
        end
    elseif resolveActive then
        if btn.resolveGlow then
            btn.resolveGlow:SetHidden(false)
            btn.resolveGlow:SetEdgeColor(.08,.55,1,1)
        end
    else
        if btn.resolveGlow then btn.resolveGlow:SetHidden(true) end
    end
    -- Keep the clean square-free presentation. Timed active skills get a blue outline.
    if btn.activeGlow then
        btn.activeGlow:SetHidden(not (remain>0 and not resolveMissing))
    end
    if btn.border then
        if resolveMissing then
            btn.border:SetEdgeColor(r,g,b,1)
        else
            btn.border:SetEdgeColor(0,0,0,0)
        end
    else
        btn:SetEdgeColor(r,g,b,1)
    end
    if remain>0 then
        btn.timer:SetText(remain<10 and string.format("%.1f",remain) or tostring(math.ceil(remain)))
    else btn.timer:SetText("") end

    local stacks=0
    if GetActionSlotEffectStackCount then stacks=GetActionSlotEffectStackCount(slot,bar) or 0 end
    btn.stack:SetText(stacks>1 and tostring(stacks) or "")
    btn.key:SetText(defaults().showKeys and tostring(slot-FIRST+1) or "")
end

local setCustomBarVisible

A.visibilityTellTale=A.visibilityTellTale or {reason="none",at=0,nativeHidden=false,playerDead=false,enabled=true}
local function latchVisibilityReason(reason)
    local t=A.visibilityTellTale
    t.reason=tostring(reason or "unknown"); t.at=now()
    t.nativeHidden=(ZO_ActionBar1 and ZO_ActionBar1:IsHidden()) and true or false
    t.playerDead=actionBarPlayerDead() and true or false
    t.enabled=defaults().enabled and true or false
end
local function printVisibilityTellTale()
    local t=A.visibilityTellTale or {}
    local age=(tonumber(t.at) or 0)>0 and math_max(0,now()-(tonumber(t.at) or 0)) or 0
    d(string.format("|c49BFFFRyticActionBar tell-tale:|r reason=%s | age=%.1fs | enabled=%s | dead=%s | nativeHidden=%s",
        tostring(t.reason or "none"),age,tostring(t.enabled),tostring(t.playerDead),tostring(t.nativeHidden)))
end

function A.Update()
    updateReadyPulse()
    if not defaults().enabled then
        setCustomBarVisible(false)
        setNativeBarHidden(false)
        return
    end

    if actionBarPlayerDead() then
        setCustomBarVisible(false)
        return
    end

    if not A.root or A.root:IsHidden() then return end
    setNativeBarHidden(true)
    local active=getDisplayHotbar()
    local frontCat=HOTBAR_CATEGORY_PRIMARY
    local backCat=HOTBAR_CATEGORY_BACKUP
    local transformed=not isWeaponHotbar(active)

    -- Werewolf/Vampire/temporary transformation hotbars replace the weapon-bar
    -- display with ESO's currently active hotbar.  Use one visual row while the
    -- transformation is active, then restore the normal/Oakensoul layout on exit.
    if transformed or A.oneBarMode then
        local activeGroup=(active==backCat) and A.back or A.front
        local inactiveGroup=(active==backCat) and A.front or A.back

        for i=FIRST,LAST do
            local shown=activeGroup[i]
            local hidden=inactiveGroup[i]
            if shown then
                local n=i-FIRST
                shown:ClearAnchors()
                shown:SetAnchor(TOPLEFT,A.root,TOPLEFT,n*54,0)
                shown:SetHidden(false)
                shown:SetAlpha(1)
                shown.ryticSlot=i
                shown.ryticBar=active
            end
            if hidden then
                hidden:SetHidden(true)
                hidden:SetAlpha(0)
            end
        end
        A.root:SetDimensions(430,66)

        -- Match the normal one-bar/Oakensoul presentation: quickslot, five skills,
        -- and ultimate all centered on the same horizontal line.
        if A.quick then
            A.quick:ClearAnchors()
            A.quick:SetAnchor(RIGHT,activeGroup[FIRST],LEFT,-12,0)
            A.quick:SetHidden(false)
        end
        if A.ult then
            A.ult:ClearAnchors()
            A.ult:SetAnchor(LEFT,activeGroup[LAST],RIGHT,18,0)
            A.ult:SetHidden(false)
        end

        for i=FIRST,LAST do updateButton(activeGroup[i],i,active,true) end
    else
        -- Ensure the normal two weapon rows are restored after transformation.
        applyBarMode()
        for i=FIRST,LAST do
            A.front[i].ryticSlot=i
            A.front[i].ryticBar=frontCat
            A.back[i].ryticSlot=i
            A.back[i].ryticBar=backCat
            updateButton(A.front[i],i,frontCat,active==frontCat)
            updateButton(A.back[i],i,backCat,active==backCat)
        end
    end

    -- Ultimate follows the active weapon bar.
    A.ult.ryticSlot=8
    A.ult.ryticBar=active
    local ultId=slotId(8,active)
    A.ult.ryticAbilityId=ultId or 0
    if A.ult.ryticHoverHit then A.ult.ryticHoverHit.ryticAbilityId=A.ult.ryticAbilityId end
    if ultId~=0 then
        A.ult.icon:SetTexture(GetAbilityIcon(ultId) or "")
        local cur=GetUnitPower("player",POWERTYPE_ULTIMATE) or 0
        local cost=GetAbilityCost(ultId) or 0
        A.ult.timer:SetText(cost>0 and tostring(cur).."/"..tostring(cost) or tostring(cur))
        local ready=(cost>0 and cur>=cost)
        if A.ult.border then
            if ready then
                local p=alertPulse()
                A.ult.border:SetEdgeColor(1,.55 + (.45*p),.02,1)
            else
                A.ult.border:SetEdgeColor(1,1,1,1)
            end
        end
        if A.ult.readyGlow then
            A.ult.readyGlow:SetHidden(not ready)
            if ready then
                local p=alertPulse()
                A.ult.readyGlow:SetEdgeColor(1,.35 + (.65*p),.02,.70 + (.30*p))
            end
        end
        if A.ult.readyGlow2 then
            A.ult.readyGlow2:SetHidden(not ready)
            if ready then
                local p=alertPulse()
                A.ult.readyGlow2:SetEdgeColor(1,.08 + (.75*p),.02,.25 + (.70*p))
            end
        end
        A.ult.key:SetText("R")
    end

    -- Current ESO quickslot wheel is hotbar category QUICKslot, slot 1.
    refreshQuickslot(A.quick)
end

function A.SetUnlocked(v)
    local sv=defaults()
    sv.unlocked=v and true or false
    if A.root then
        A.root:SetMovable(true)
        A.root:SetMouseEnabled(true)
    end
end
function A.SetScale(v) local sv=defaults(); sv.scale=tonumber(v) or 1; if A.root then A.root:SetScale(sv.scale) end end

setCustomBarVisible=function(show)
    -- Central alive gate: no native action-bar hook, mouse click, scene transition,
    -- or reload reconciliation may resurrect the custom bar while the player is dead.
    if show and actionBarPlayerDead() then
        show=false
    end
    if A.root then
        A.root:SetHidden(not show)
        A.root:SetMouseEnabled(show)
        A.root:SetAlpha(show and 1 or 0)
    end
    -- Defensive child visibility. In Oakensoul mode never resurrect the
    -- intentionally hidden weapon row when ESO shows the action bar again.
    if show and A.oneBarMode and A.front and A.back then
        local active=GetActiveHotbarCategory()
        local activeGroup=(active==HOTBAR_CATEGORY_BACKUP) and A.back or A.front
        local inactiveGroup=(active==HOTBAR_CATEGORY_BACKUP) and A.front or A.back

        for i=FIRST,LAST do
            if activeGroup[i] and activeGroup[i].SetHidden then activeGroup[i]:SetHidden(false) end
            if inactiveGroup[i] and inactiveGroup[i].SetHidden then inactiveGroup[i]:SetHidden(true) end
        end
    else
        local groups={A.front,A.back}
        for _,g in ipairs(groups) do
            if g then
                for _,c in pairs(g) do
                    if c and c.SetHidden then c:SetHidden(not show) end
                end
            end
        end
    end
    if A.quick and A.quick.SetHidden then A.quick:SetHidden(not show) end
    if A.ultimate and A.ultimate.SetHidden then A.ultimate:SetHidden(not show) end
    if A.ult and A.ult.SetHidden then A.ult:SetHidden(not show) end
    if A.ultimateButton and A.ultimateButton.SetHidden then A.ultimateButton:SetHidden(not show) end
    if A.ultButton and A.ultButton.SetHidden then A.ultButton:SetHidden(not show) end
end

local function hookNativeActionBarLifecycle()
    if A._nativeLifecycleHooked or not ZO_ActionBar1 then return end
    A._nativeLifecycleHooked=true

    -- Follow ESO's EFFECTIVE visibility, not IsUnitDead().  This catches the
    -- actual action-bar lifecycle used by ESO during death/rez and scene changes.
    ZO_PreHookHandler(ZO_ActionBar1,"OnEffectivelyHidden",function()
        if defaults().enabled then
            latchVisibilityReason("native ZO_ActionBar1 effectively hidden")
            -- ESO may transiently hide its native bar during normal gameplay.
            -- Reconcile on the next UI tick against the actual HUD/death state.
            zo_callLater(function()
                if not defaults().enabled or actionBarPlayerDead() then
                    setCustomBarVisible(false)
                    return
                end
                local hudShowing=true
                if HUD_SCENE and HUD_SCENE.GetState then
                    local state=HUD_SCENE:GetState()
                    hudShowing=(state==SCENE_SHOWING or state==SCENE_SHOWN)
                end
                if not hudShowing and HUD_UI_SCENE and HUD_UI_SCENE.GetState then
                    local state=HUD_UI_SCENE:GetState()
                    hudShowing=(state==SCENE_SHOWING or state==SCENE_SHOWN)
                end
                if hudShowing then
                    setCustomBarVisible(true)
                    setNativeBarHidden(true)
                    applyBarMode()
                    A.Update()
                else
                    setCustomBarVisible(false)
                end
            end,0)
        end
    end)

    ZO_PreHookHandler(ZO_ActionBar1,"OnEffectivelyShown",function()
        if defaults().enabled and not actionBarPlayerDead() then
            setCustomBarVisible(true)
            setNativeBarHidden(true)
            if A.quick then refreshQuickslot(A.quick) end
        else
            setCustomBarVisible(false)
        end
    end)
end

local function registerRuntime()
    if A.runtimeRegistered then return end
    A.runtimeRegistered=true
    -- Do NOT mirror ZO_ActionBar1 effective visibility. ESO transiently hides
    -- the native action bar for internal UI state changes, which could make the
    -- Rytic bar vanish even though the gameplay HUD is still active.
    -- Rytic visibility is owned by its HUD fragment + explicit death/enable gates.
    EM:RegisterForUpdate(UPDATE_NAME,100,A.Update)
    if EVENT_UNIT_DEATH_STATE_CHANGED then
        EM:RegisterForEvent("RyticActionBarDeathState",EVENT_UNIT_DEATH_STATE_CHANGED,function(_,unitTag,isDead)
            if unitTag~="player" then return end

            -- Latch immediately on death. Native action-bar visibility changes,
            -- recap clicks, mouse input, and scene transitions cannot clear this.
            A.playerDeadLatched = isDead and true or false

            if A.playerDeadLatched then
                setCustomBarVisible(false)
                return
            end

            -- Only the explicit player-alive death-state event releases the latch.
            zo_callLater(function()
                if not defaults().enabled or A.playerDeadLatched or IsUnitDead("player") then
                    setCustomBarVisible(false)
                    return
                end
                -- Revive should restore from the player's alive state, not from
                -- ZO_ActionBar1:IsHidden(). The native bar can be transiently hidden
                -- while the HUD itself is valid. The HUD fragment remains the scene gate.
                setCustomBarVisible(true)
                setNativeBarHidden(true)
                applyBarMode()
                if A.quick then refreshQuickslot(A.quick) end
                A.Update()
            end,0)
        end)
    end

    if EVENT_ACTIVE_QUICKSLOT_CHANGED then
        EM:RegisterForEvent("RyticActionBarActiveQuickslot",EVENT_ACTIVE_QUICKSLOT_CHANGED,function()
            if A.quick then refreshQuickslot(A.quick) end
        end)
    end
    if EVENT_ACTION_SLOT_ABILITY_USED then
        EM:RegisterForEvent("RyticActionBarGCDAbilityUsed",EVENT_ACTION_SLOT_ABILITY_USED,function(_,slot)
            slot=tonumber(slot)
            if not slot or slot<FIRST or slot>LAST then return end
            local active=getDisplayHotbar()
            local abilityId=slotId(slot,active)

            -- Remember the actual pressed button for a very short window. We do
            -- not classify it unless ESO subsequently reports Major Resolve.
            A.lastPressedSlot=slot
            A.lastPressedBar=active
            A.lastPressedAbilityId=abilityId
            A.lastPressedAt=now()

            local btn=(active==HOTBAR_CATEGORY_BACKUP) and A.back[slot] or A.front[slot]
            if btn then beginGCDSweep(btn,slot,active,abilityId) end
        end)
    end

    if EVENT_EFFECT_CHANGED then
        EM:RegisterForEvent("RyticActionBarResolveEffect",EVENT_EFFECT_CHANGED,
            function(_,changeType,_,effectName,_,_,_,_,_,_,_,_,_,_,_,abilityId)
                if not isMajorResolveEffect(effectName,abilityId) then return end

                -- Learn only from a gain/update immediately following our own
                -- button press. No cooldown-duration guessing.
                local sourceAbilityId=tonumber(A.lastPressedAbilityId) or 0
                local validSource=sourceAbilityId~=0
                    and (not isNightblade() or abilityIsNightbladeShadow(sourceAbilityId))
                if validSource and changeType~=EFFECT_RESULT_FADED
                    and A.lastPressedSlot and A.lastPressedAt
                    and (now()-A.lastPressedAt)<=0.75 then
                    if isNightblade() then
                        local preferredSlot,preferredBar,preferredId=findSlottedNightbladePreferredResolve()
                        if preferredId then
                            rememberResolveSource(preferredSlot,preferredBar,preferredId)
                        else
                            rememberResolveSource(A.lastPressedSlot,A.lastPressedBar,A.lastPressedAbilityId)
                        end
                    else
                        rememberResolveSource(A.lastPressedSlot,A.lastPressedBar,A.lastPressedAbilityId)
                    end
                end
            end)
        EM:AddFilterForEvent("RyticActionBarResolveEffect",EVENT_EFFECT_CHANGED,
            REGISTER_FILTER_UNIT_TAG,"player")
    end
    if EVENT_COMBAT_EVENT then
        EM:RegisterForEvent("RyticActionBarGCDCombat",EVENT_COMBAT_EVENT,function(_,result,isError,abilityName,abilityGraphic,abilityActionSlotType,sourceName,sourceType,targetName,targetType,hitValue,powerType,damageType,log,sourceUnitId,targetUnitId,abilityId)
            if not A.gcdButton or not A.gcdAbilityId or A.gcdAbilityId==0 then return end
            if tonumber(abilityId)~=tonumber(A.gcdAbilityId) then return end
            if sourceType and COMBAT_UNIT_TYPE_PLAYER and sourceType~=COMBAT_UNIT_TYPE_PLAYER then return end

            local cancelled =
                (ACTION_RESULT_INTERRUPTED and result==ACTION_RESULT_INTERRUPTED) or
                (ACTION_RESULT_FAILED and result==ACTION_RESULT_FAILED) or
                (ACTION_RESULT_MISSING_EMPTY_SOUL_GEM and result==ACTION_RESULT_MISSING_EMPTY_SOUL_GEM) or
                (ACTION_RESULT_CANT_SEE_TARGET and result==ACTION_RESULT_CANT_SEE_TARGET) or
                (ACTION_RESULT_OUT_OF_RANGE and result==ACTION_RESULT_OUT_OF_RANGE) or
                (ACTION_RESULT_BAD_TARGET and result==ACTION_RESULT_BAD_TARGET)

            if cancelled then
                -- A cancelled/channel-interrupted action is no longer timing.
                -- Clear it rather than letting a stale multi-second sweep continue.
                cancelSweep(false)
            end
        end)
    end
    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then
        EM:RegisterForEvent("RyticActionBarOakensoul",EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function(_,bagId)
            if bagId==BAG_WORN then applyBarMode() end
        end)
    end
    if EVENT_HOTBAR_SLOT_UPDATED then
        EM:RegisterForEvent("RyticActionBarQuickslot",EVENT_HOTBAR_SLOT_UPDATED,function(_,slot,hotbarCategory)
            if hotbarCategory==HOTBAR_CATEGORY_QUICKSLOT_WHEEL and A.quick then refreshQuickslot(A.quick) end
        end)
    end
    if EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED then
        EM:RegisterForEvent("RyticActionBarActiveHotbar",EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED,function()
            A.Update()
        end)
    end
    if EVENT_ACTION_SLOTS_FULL_UPDATE then
        EM:RegisterForEvent("RyticActionBarFullSlots",EVENT_ACTION_SLOTS_FULL_UPDATE,function()
            A.Update()
        end)
    end
end

local function unregisterRuntime()
    A.runtimeRegistered=false
    EM:UnregisterForUpdate(UPDATE_NAME)
    EM:UnregisterForUpdate(GCD_UPDATE_NAME)
    if EVENT_UNIT_DEATH_STATE_CHANGED then EM:UnregisterForEvent("RyticActionBarDeathState",EVENT_UNIT_DEATH_STATE_CHANGED) end
    if EVENT_ACTION_SLOT_ABILITY_USED then EM:UnregisterForEvent("RyticActionBarGCDAbilityUsed",EVENT_ACTION_SLOT_ABILITY_USED) end
    if EVENT_COMBAT_EVENT then EM:UnregisterForEvent("RyticActionBarGCDCombat",EVENT_COMBAT_EVENT) end
    if EVENT_EFFECT_CHANGED then EM:UnregisterForEvent("RyticActionBarResolveEffect",EVENT_EFFECT_CHANGED) end
    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then EM:UnregisterForEvent("RyticActionBarOakensoul",EVENT_INVENTORY_SINGLE_SLOT_UPDATE) end
    EM:UnregisterForEvent("RyticActionBarActiveQuickslot",EVENT_ACTIVE_QUICKSLOT_CHANGED)
    EM:UnregisterForEvent("RyticActionBarQuickslot",EVENT_HOTBAR_SLOT_UPDATED)
    if EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED then EM:UnregisterForEvent("RyticActionBarActiveHotbar",EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED) end
    if EVENT_ACTION_SLOTS_FULL_UPDATE then EM:UnregisterForEvent("RyticActionBarFullSlots",EVENT_ACTION_SLOTS_FULL_UPDATE) end
end

function A.SetEnabled(enabled)
    local sv=defaults()
    sv.enabled=enabled and true or false

    if sv.enabled then
        setCustomBarVisible(true)
        setNativeBarHidden(true)
        registerRuntime()
        A.Update()
    else
        unregisterRuntime()
        if A.gcdButton then clearGCDSweep(A.gcdButton) end
        A.gcdButton=nil
        setCustomBarVisible(false)
        -- Restore the native ESO action bar and stop touching it while disabled.
        setNativeBarHidden(false)
    end
end

function A.Toggle()
    local sv=defaults(); A.SetEnabled(not sv.enabled)
    d("|c49BFFFRyticActionBar:|r "..(sv.enabled and "ON" or "OFF"))
end

function A.Initialize()
    rebuildShadowAbilityCache()
    A.playerDeadLatched = IsUnitDead("player") and true or false
    A.Create()
    if A.playerDeadLatched then setCustomBarVisible(false) end
    SLASH_COMMANDS["/ryticbar"]=A.Toggle
    SLASH_COMMANDS["/rabarwhy"]=printVisibilityTellTale

    -- A.Create establishes initial visibility. Runtime callbacks only exist
    -- while the custom bar is actually enabled.
    unregisterRuntime()
    if defaults().enabled then
        registerRuntime()
        A.Update()
    else
        setNativeBarHidden(false)
        setCustomBarVisible(false)
    end

    EM:UnregisterForEvent("RyticActionBarPlayerActivated",EVENT_PLAYER_ACTIVATED)
    EM:RegisterForEvent("RyticActionBarPlayerActivated",EVENT_PLAYER_ACTIVATED,function()
        zo_callLater(function()
            if not A.root then return end
            local enabled=defaults().enabled
            A.playerDeadLatched = IsUnitDead("player") and true or false
            local alive=not A.playerDeadLatched
            if enabled and alive then
                setCustomBarVisible(true)
                setNativeBarHidden(true)
                applyBarMode()
                if A.quick then refreshQuickslot(A.quick) end
                A.Update()
            else
                setCustomBarVisible(false)
                if not enabled then setNativeBarHidden(false) end
            end
        end,0)
    end)
end


EM:RegisterForEvent("RyticActionBarBootstrap",EVENT_ADD_ON_LOADED,function(_,addonName)
    if addonName~="RyticTankTools" then return end
    EM:UnregisterForEvent("RyticActionBarBootstrap",EVENT_ADD_ON_LOADED)
    A.Initialize()
end)
