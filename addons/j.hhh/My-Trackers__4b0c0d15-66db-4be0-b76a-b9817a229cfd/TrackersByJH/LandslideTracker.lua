-- Landslide Tracker by JH - standalone PS5 stack-only tracker
-- Uses the Bright Harbinger settings/movement pattern, but intentionally no timer.
local ADDON = "LandslideTrackerByJH"
local ABILITY = 29465
local sv, frame, icon, stacksLabel, borderTop, borderBottom, borderLeft, borderRight
local moving, lastMs = false, 0
local HUDHidden = true
local defaults = {enabled=true, size=72, x=300, y=200, speed=420}
local function Save()
    local am = GetAddOnManager and GetAddOnManager()
    if am and am.RequestAddOnSavedVariablesPrioritySave then
        am:RequestAddOnSavedVariablesPrioritySave(ADDON)
    end
end
local function Position()
    if not frame or not sv then return end
    frame:ClearAnchors()
    frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.x, sv.y)
end
local function ApplySize()
    if not frame then return end
    frame:SetDimensions(sv.size, sv.size)
    icon:SetDimensions(sv.size, sv.size)
    stacksLabel:SetDimensions(sv.size, sv.size)
    stacksLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick",math.max(18,math.floor(sv.size*.7))))
    local bw=math.max(2,math.floor(sv.size*.045))
    borderTop:SetDimensions(sv.size,bw); borderBottom:SetDimensions(sv.size,bw)
    borderLeft:SetDimensions(bw,sv.size); borderRight:SetDimensions(bw,sv.size)
end
local current = 0
local Refresh
local function HasEarthenHeart()
    -- Earthen Heart is one of the Dragonknight class skill lines.
    -- Console builds proved unreliable when querying the skill-line active flag,
    -- so use the stable numeric class id instead. Dragonknight = class id 1.
    if not GetUnitClassId then return false end
    return GetUnitClassId("player") == 1
end
local function SetupHUDVisibility()
    -- Use the same HUD/hudui scene-state approach as our working Sul-Xan tracker.
    -- Do not use IsInUIMode() on console: Gamepad UI can report UI mode while the HUD is active.
    if not SCENE_MANAGER then return end
    local hud = SCENE_MANAGER:GetScene("hud")
    local hudUI = SCENE_MANAGER:GetScene("hudui")

    local function OnHUDStateChanged(oldState, newState)
        if newState == SCENE_SHOWN then
            HUDHidden = false
        else
            HUDHidden = true
        end
        Refresh()
    end

    if hud then hud:RegisterCallback("StateChange", OnHUDStateChanged) end
    if hudUI then hudUI:RegisterCallback("StateChange", OnHUDStateChanged) end

    -- Resolve the initial state without relying on keyboard-only inventory scenes.
    local current = SCENE_MANAGER.currentScene
    if current and current.GetName then
        local name = current:GetName()
        HUDHidden = not (name == "hud" or name == "hudui")
    end
end
local function StackColor(n)
    n=math.max(0,math.min(12,n or 0))
    -- Exact anchor colors: 1 = red, 5 = orange, 12 = green.
    if n <= 1 then
        return 1, 0, 0, 1
    elseif n <= 5 then
        local t=(n-1)/4
        return 1, 0.5*t, 0, 1 -- red (1) -> orange (5)
    end
    local t=(n-5)/7
    return 1-t, 0.5+0.5*t, 0, 1 -- orange (5) -> green (12)
end
Refresh = function()
    if not frame then return end
    -- At zero stacks the icon remains visible, but no "0" is drawn.
    stacksLabel:SetText(current > 0 and tostring(current) or "")
    stacksLabel:SetColor(StackColor(current))
    frame:SetHidden(not (moving or (sv.enabled and HasEarthenHeart() and not HUDHidden)))
end
local function Poll()
    if not sv then return end
    local count = 0
    for i=1,GetNumBuffs("player") do
        local buffName, startTime, endTime, buffSlot, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, abilityId = GetUnitBuffInfo("player",i)
        if abilityId == ABILITY then count=stackCount or 0; break end
    end
    if current~=count then current=count end
    Refresh()
end
local function OnEffect(_, changeType, slot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId)
    if abilityId~=ABILITY then return end
    if unitTag~="player" and (not AreUnitsEqual or not AreUnitsEqual("player",unitTag)) then return end
    if changeType==EFFECT_RESULT_FADED then current=0 else current=stackCount or 0 end
    Refresh()
end
local function MoveTick()
    if not moving then return end
    local now=GetGameTimeMilliseconds()
    local dt=lastMs>0 and math.min((now-lastMs)/1000,.05) or .016
    lastMs=now
    local x=GetGamepadLeftStickX and GetGamepadLeftStickX(true) or 0
    local y=GetGamepadLeftStickY and GetGamepadLeftStickY(true) or 0
    if math.abs(x)<.18 then x=0 end
    if math.abs(y)<.18 then y=0 end
    if x==0 and y==0 then return end
    sv.x=sv.x+x*sv.speed*dt
    sv.y=sv.y-y*sv.speed*dt
    Position()
end
local function Stop()
    if not moving then return end
    moving=false
    EVENT_MANAGER:UnregisterForUpdate(ADDON.."Move")
    lastMs=0; Save(); Refresh()
end
local function Start()
    if moving then return end
    moving=true; lastMs=0; Refresh()
    EVENT_MANAGER:RegisterForUpdate(ADDON.."Move",16,MoveTick)
end
local function SetupLAM()
    local options = {
        {type="description",text="Landslide (ability ID 29465). Stacks only; no timer. Automatically visible on Dragonknight (Earthen Heart class line). Hidden in main UI menus unless move mode is active. Use the left stick in move mode."},
        {type="checkbox",name="Enable tracker",getFunc=function()return sv.enabled end,setFunc=function(v)sv.enabled=v;Refresh() end,default=true,width="full"},
        {type="slider",name="Tracker size",min=32,max=300,step=2,getFunc=function()return sv.size end,setFunc=function(v)sv.size=v;ApplySize() end,default=72,width="full"},
        {type="slider",name="Gamepad move speed",min=100,max=1000,step=25,getFunc=function()return sv.speed end,setFunc=function(v)sv.speed=v end,default=420,width="full"},
        {type="button",name="Start move mode",func=Start,width="full"},
        {type="button",name="Save position / Stop move mode",func=Stop,width="full"},
        {type="button",name="Reset position",func=function()sv.x=300;sv.y=200;Position();Save()end,width="full"},
    }
    if TrackersByJH_RegisterMenu then
        TrackersByJH_RegisterMenu("Landslide Tracker", options)
    end
end
local function Initialize(_,addonName)
    if addonName~=ADDON and addonName~="TrackersByJH" then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON,EVENT_ADD_ON_LOADED)
    sv=ZO_SavedVars:NewAccountWide("LandslideTrackerByJHSavedVariables",1,nil,defaults)
    frame=WINDOW_MANAGER:CreateTopLevelWindow(ADDON.."Window")
    frame:SetClampedToScreen(true)
    icon=WINDOW_MANAGER:CreateControl(nil,frame,CT_TEXTURE)
    icon:SetAnchorFill(frame)
    icon:SetTexture(GetAbilityIcon(ABILITY))
    -- Black frame that scales with the tracker. Four texture strips avoid PC-only backdrop dependencies.
    local function BlackEdge()
        local c=WINDOW_MANAGER:CreateControl(nil,frame,CT_TEXTURE)
        c:SetColor(0,0,0,1)
        c:SetDrawLayer(DL_OVERLAY)
        return c
    end
    borderTop=BlackEdge(); borderTop:SetAnchor(TOPLEFT,frame,TOPLEFT,0,0)
    borderBottom=BlackEdge(); borderBottom:SetAnchor(BOTTOMLEFT,frame,BOTTOMLEFT,0,0)
    borderLeft=BlackEdge(); borderLeft:SetAnchor(TOPLEFT,frame,TOPLEFT,0,0)
    borderRight=BlackEdge(); borderRight:SetAnchor(TOPRIGHT,frame,TOPRIGHT,0,0)
    stacksLabel=WINDOW_MANAGER:CreateControl(nil,frame,CT_LABEL)
    stacksLabel:SetAnchorFill(frame)
    stacksLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    stacksLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    stacksLabel:SetColor(1,1,1,1)
    ApplySize();Position();SetupHUDVisibility();Refresh()
    EVENT_MANAGER:RegisterForEvent(ADDON.."Effect",EVENT_EFFECT_CHANGED,OnEffect)
    EVENT_MANAGER:AddFilterForEvent(ADDON.."Effect",EVENT_EFFECT_CHANGED,REGISTER_FILTER_ABILITY_ID,ABILITY)
    -- Player/class data is not guaranteed to be ready at ADD_ON_LOADED on console.
    -- Re-check the DK/Earthen Heart visibility after the character is fully activated.
    EVENT_MANAGER:RegisterForEvent(ADDON.."PlayerActivated",EVENT_PLAYER_ACTIVATED,function()
        Poll()
        zo_callLater(Poll,1000)
    end)
    SLASH_COMMANDS["/landslidemove"]=function()if moving then Stop()else Start()end end
    zo_callLater(SetupLAM,500)
    Poll()
end
EVENT_MANAGER:RegisterForEvent(ADDON,EVENT_ADD_ON_LOADED,Initialize)