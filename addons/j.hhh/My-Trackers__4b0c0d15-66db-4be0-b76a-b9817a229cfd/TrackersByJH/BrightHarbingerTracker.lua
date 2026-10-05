local ADDON_NAME = "BrightHarbingerTracker"
local ADDON_VERSION = "1.0.17"
local BRIGHT_HARBINGER_ID = 263672
local TEMPLAR_CLASS_ID = 6

local control, icon, timerLabel, groupCountLabel
local cooldownEnd = 0
local activeGroupBH = {}
local sv
local positioningArmed = false
local positioningActive = false
local lastStickX, lastStickY = 0, 0

local defaults = {
    enabled = true,
    pureTemplarOnly = true,
    iconSize = 64,
    groupCountEnabled = true,
    offsetX = 300,
    offsetY = 0,
    showReady = true,
    timerOffsetX = 0,
    timerOffsetY = 0,
    groupOffsetX = 0,
    groupOffsetY = 0,
    gamepadMoveSpeed = 420,
}

local function NormalVisibility()
    return sv and sv.enabled
end

local function IsInMenu()
    if not SCENE_MANAGER then return false end
    local scene = SCENE_MANAGER:GetCurrentScene()
    if not scene then return false end

    local name = scene:GetName()
    return name ~= "hud" and name ~= "hudui"
end

local function RefreshVisibility()
    if not control then return end
    if positioningActive then control:SetHidden(false); return end
    control:SetHidden((not NormalVisibility()) or IsInMenu())
end

local function SetPosition(x, y)
    sv.offsetX, sv.offsetY = x, y
    control:ClearAnchors()
    control:SetAnchor(CENTER, GuiRoot, CENTER, x, y)
end

local function SaveMousePosition()
    if not control then return end
    local _,_,_,x,y = control:GetAnchor(0)
    if x then sv.offsetX=x end
    if y then sv.offsetY=y end
end

local function ApplyTimerSize()
    if not timerLabel or not sv then return end

    local percent = tonumber(sv.timerSizePercent)
    if not percent then
        percent = tonumber(sv.timerScale) and math.floor(tonumber(sv.timerScale) * 100) or 100
        sv.timerSizePercent = percent
    end

    local iconSize = tonumber(sv.iconSize) or 64
    local fontSize = math.max(12, math.floor(iconSize * (percent / 100)))
    timerLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", fontSize))
end

local function ApplyGroupCountSize()
    if not groupCountLabel or not sv then return end
    local percent = sv.groupCountSizePercent
    if percent == nil then
        percent = 100
        sv.groupCountSizePercent = percent
    end
    local fontSize = math.max(12, math.floor(sv.iconSize * (percent / 100)))
    groupCountLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", fontSize))
end

-- GROUP TRACKING: DIRECT group1..group12 TAGS
-- The console debug screenshots proved that EVENT_EFFECT_CHANGED emits a real groupX
-- event for every affected member, including the local player (e.g. group1 / group2).
-- We therefore track ONLY groupX tags from the unfiltered ability listener.
-- player/reticleover duplicates are ignored completely.
local groupEffectEnds = {}

local function IsGroupTag(unitTag)
    if not unitTag then return false end
    local n = string.match(unitTag, "^group(%d+)$")
    n = tonumber(n)
    return n ~= nil and n >= 1 and n <= 12
end

local function PruneGroupBH()
    local now = GetGameTimeMilliseconds()
    for unitTag,endMs in pairs(groupEffectEnds) do
        if not endMs or endMs <= now then
            groupEffectEnds[unitTag] = nil
        end
    end
end

local function UpdateGroupCount()
    if not groupCountLabel or not sv then return end
    if not sv.groupCountEnabled then
        groupCountLabel:SetText("")
        return
    end

    PruneGroupBH()
    local count = 0
    for _ in pairs(groupEffectEnds) do count = count + 1 end

    if count > 0 then
        groupCountLabel:SetText(tostring(math.min(count,12)))
    else
        groupCountLabel:SetText("")
    end
end

local function OnGroupUIDEffectChanged(_, changeType, effectSlot, effectName, unitTag,
        beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType,
        statusEffectType, unitName, unitId, abilityId, sourceType)
    if abilityId ~= BRIGHT_HARBINGER_ID then return end
    if not IsGroupTag(unitTag) then return end

    if changeType == EFFECT_RESULT_GAINED
        or changeType == EFFECT_RESULT_UPDATED
        or changeType == EFFECT_RESULT_FULL_REFRESH then
        -- Use the confirmed 20 second Bright Harbinger duration.
        groupEffectEnds[unitTag] = GetGameTimeMilliseconds() + 20000
    elseif changeType == EFFECT_RESULT_FADED then
        groupEffectEnds[unitTag] = nil
    end

    UpdateGroupCount()
end

local function ApplyTimerPosition()
    if not timerLabel or not control or not sv then return end
    timerLabel:ClearAnchors()
    timerLabel:SetAnchor(CENTER, control, CENTER, tonumber(sv.timerOffsetX) or 0, tonumber(sv.timerOffsetY) or 0)
end

local function ApplyGroupPosition()
    if not groupCountLabel or not control or not sv then return end
    groupCountLabel:ClearAnchors()
    groupCountLabel:SetAnchor(CENTER, control, CENTER, tonumber(sv.groupOffsetX) or 0, tonumber(sv.groupOffsetY) or 0)
end

local function CreateUI()
    control = WINDOW_MANAGER:CreateTopLevelWindow("BrightHarbingerTrackerWindow")
    control:SetDimensions(sv.iconSize, sv.iconSize)
    control:SetAnchor(CENTER, GuiRoot, CENTER, sv.offsetX, sv.offsetY)
    control:SetMouseEnabled(false)
    control:SetMovable(false)
    control:SetClampedToScreen(true)

    icon = WINDOW_MANAGER:CreateControl("$(parent)Icon", control, CT_TEXTURE)
    icon:SetAnchorFill()
    icon:SetDrawLayer(DL_BACKGROUND)
    icon:SetDrawLevel(0)
    local p = GetAbilityIcon(BRIGHT_HARBINGER_ID)
    icon:SetTexture((p and p~="") and p or "/esoui/art/icons/icon_missing.dds")

    timerLabel = WINDOW_MANAGER:CreateControl("$(parent)Timer", control, CT_LABEL)
    timerLabel:SetAnchorFill()
    timerLabel:SetFont("ZoFontWinH1")
    timerLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timerLabel:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    timerLabel:SetColor(1,1,1,1)

    groupCountLabel = WINDOW_MANAGER:CreateControl("$(parent)GroupCount", control, CT_LABEL)
    groupCountLabel:SetDimensions(sv.iconSize, sv.iconSize)
    groupCountLabel:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 0)
    groupCountLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    groupCountLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
    groupCountLabel:SetColor(1,1,1,1)
    groupCountLabel:SetDrawLayer(DL_OVERLAY)
    groupCountLabel:SetDrawLevel(100)

    ApplyTimerSize()
    ApplyGroupCountSize()
    ApplyTimerPosition()
    ApplyGroupPosition()
    UpdateGroupCount()
    RefreshVisibility()
end

local function StartCooldown()
    if not sv.enabled then return end
    cooldownEnd = GetGameTimeMilliseconds() + 20000
    RefreshVisibility()
end

local function ResetCooldown()
    cooldownEnd = 0
    if timerLabel then timerLabel:SetText("") end
    RefreshVisibility()
end

local function Update()
    if positioningActive then
        if control then control:SetHidden(false) end
        if timerLabel then timerLabel:SetText("MOVE") end
        return
    end
    RefreshVisibility()
    UpdateGroupCount()
    if not timerLabel then return end

    if cooldownEnd <= 0 then
        timerLabel:SetText("")
        return
    end

    local remaining = (cooldownEnd - GetGameTimeMilliseconds()) / 1000
    if remaining <= 0 then
        ResetCooldown()
        return
    end

    timerLabel:SetText(tostring(math.ceil(remaining)))
end

local function OnEffectChanged(_, changeType, effectSlot, effectName, unitTag, beginTime, endTime,
        stackCount, iconName, buffType, effectType, abilityType, statusEffectType,
        unitName, unitId, abilityId, sourceType)
    if abilityId ~= BRIGHT_HARBINGER_ID then return end
    if not unitTag or not AreUnitsEqual("player", unitTag) then return end

    if changeType == EFFECT_RESULT_GAINED
        or changeType == EFFECT_RESULT_UPDATED
        or changeType == EFFECT_RESULT_FULL_REFRESH then

        -- unitTag is already confirmed as the local player above.
        -- Do NOT filter by sourceType: console debug showed valid BH player events
        -- with different sourceType values depending on who caused/refreshed the effect.
        StartCooldown()
    end
end

local function ApplyTrackerPosition()
    if not control or not sv then return end
    control:ClearAnchors()
    control:SetAnchor(CENTER, GuiRoot, CENTER, sv.offsetX or 300, sv.offsetY or 0)
end

local function RequestSavedVariablesSave()
    local addonManager = GetAddOnManager and GetAddOnManager()
    if addonManager and addonManager.RequestAddOnSavedVariablesPrioritySave then
        addonManager:RequestAddOnSavedVariablesPrioritySave("TrackersByJH")
    end
end

local function UpdateGamepadMove()
    if not positioningActive or not control or not sv then return end
    local stickX = GetGamepadLeftStickX and GetGamepadLeftStickX(true) or 0
    local stickY = GetGamepadLeftStickY and GetGamepadLeftStickY(true) or 0
    if math.abs(stickX) < 0.18 then stickX = 0 end
    if math.abs(stickY) < 0.18 then stickY = 0 end
    if stickX == 0 and stickY == 0 then return end
    local now = GetGameTimeMilliseconds()
    local dt = 0.016
    if lastStickX and lastStickX > 0 then dt = math.min((now - lastStickX) / 1000, 0.05) end
    lastStickX = now
    local speed = tonumber(sv.gamepadMoveSpeed) or 420
    sv.offsetX = (sv.offsetX or 300) + (stickX * speed * dt)
    sv.offsetY = (sv.offsetY or 0) - (stickY * speed * dt)
    ApplyTrackerPosition()
end

local function StartGamepadMoveMode()
    if positioningActive or not control then return end
    positioningActive = true
    lastStickX = 0
    control:SetHidden(false)
    if timerLabel then timerLabel:SetText("MOVE") end
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_GamepadMove", 16, UpdateGamepadMove)
    d("|cFFFFFF|cFFD700Bright Harbinger Tracker|r Move mode: |c00FF00ON|r - move with left stick")
end

local function StopGamepadMoveMode()
    if not positioningActive then return end
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_GamepadMove")
    positioningActive = false
    lastStickX = 0
    RequestSavedVariablesSave()
    if timerLabel then timerLabel:SetText("") end
    RefreshVisibility()
    d("|cFFFFFF|cFFD700Bright Harbinger Tracker|r Move mode: |cFFAA00OFF|r - position saved")
end

local function ToggleGamepadMoveMode()
    if positioningActive then StopGamepadMoveMode() else StartGamepadMoveMode() end
end

local function RegisterLAM()
    local LAM=LibAddonMenu2
    if not LAM then return end
    local options = {
        {type="checkbox",name="Enable tracker",
         getFunc=function() return sv.enabled end,
         setFunc=function(v) sv.enabled=v; RefreshVisibility() end, default=defaults.enabled},
        {type="slider",name="Icon size",min=32,max=128,step=2,
         getFunc=function() return sv.iconSize end,
         setFunc=function(v)
             sv.iconSize=v
             control:SetDimensions(v,v)
             if timerLabel then timerLabel:SetHeight(v) end
             if groupCountLabel then groupCountLabel:SetHeight(v) end
             ApplyTimerSize()
             ApplyGroupCountSize()
         end,default=defaults.iconSize},
        {type="slider",name="Timer size",min=20,max=100,step=5,
         tooltip="Size of the countdown number relative to the icon. 100% nearly fills the icon height.",
         getFunc=function() return sv.timerSizePercent end,
         setFunc=function(v)
             sv.timerSizePercent = v
             ApplyTimerSize()
         end,
        },
        {type="checkbox",name="Show group buff counter",
         tooltip="Zeigt oben rechts, wie viele Gruppenmitglieder Bright Harbinger aktuell haben.",
         getFunc=function() return sv.groupCountEnabled end,
         setFunc=function(v)
             sv.groupCountEnabled = v
             UpdateGroupCount()
         end,
         default=true},
        {type="slider",name="Group counter size",min=20,max=100,step=5,
         tooltip="Size of the group count relative to the icon. Default is 50%. The number stays inside the top-right of the icon.",
         getFunc=function() return sv.groupCountSizePercent end,
         setFunc=function(v)
             sv.groupCountSizePercent = v
             ApplyGroupCountSize()
         end},
        {type="header",name="Timer position"},
        {type="slider",name="Timer X",min=-300,max=300,step=1,
         tooltip="Moves only the timer horizontally relative to the icon.",
         getFunc=function() return tonumber(sv.timerOffsetX) or 0 end,
         setFunc=function(v) sv.timerOffsetX=v; ApplyTimerPosition() end},
        {type="slider",name="Timer Y",min=-300,max=300,step=1,
         tooltip="Moves only the timer vertically relative to the icon.",
         getFunc=function() return tonumber(sv.timerOffsetY) or 0 end,
         setFunc=function(v) sv.timerOffsetY=v; ApplyTimerPosition() end},

        {type="header",name="Stack counter position"},
        {type="slider",name="Stacks X",min=-300,max=300,step=1,
         tooltip="Moves only the group counter horizontally relative to the icon.",
         getFunc=function() return tonumber(sv.groupOffsetX) or 0 end,
         setFunc=function(v) sv.groupOffsetX=v; ApplyGroupPosition() end},
        {type="slider",name="Stacks Y",min=-300,max=300,step=1,
         tooltip="Moves only the group counter vertically relative to the icon.",
         getFunc=function() return tonumber(sv.groupOffsetY) or 0 end,
         setFunc=function(v) sv.groupOffsetY=v; ApplyGroupPosition() end},

        {type="header",name="Gamepad positioning"},
        {type="slider",name="Gamepad move speed",min=100,max=1000,step=25,
         getFunc=function() return sv.gamepadMoveSpeed or 420 end,
         setFunc=function(v) sv.gamepadMoveSpeed=v end,default=420},
        {type="button",name="Toggle move mode",func=ToggleGamepadMoveMode,width="full"},

        {type="button",name="Test timer",func=StartCooldown,width="half"},
        {type="button",name="Reset timer",func=ResetCooldown,width="half"},
    }
    if TrackersByJH_RegisterMenu then TrackersByJH_RegisterMenu("Bright Harbinger Tracker", options) end
end

local function Slash(text)
    local c=zo_strlower(zo_strtrim(text or ""))
    if c=="test" then StartCooldown()
    elseif c=="reset" then ResetCooldown()
    elseif c=="move" then ToggleGamepadMoveMode()
    else d("/bh test | reset | move") end
end

local function OnLoaded(_,name)
    if name~=ADDON_NAME and name~="TrackersByJH" then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME,EVENT_ADD_ON_LOADED)
    -- IMPORTANT: use ONE SavedVariables version only.
    -- Older test builds copied stale v1 scaler values over v2 on every /reloadui.
    -- That is why the sliders appeared to "forget" the player's setting.
    sv = ZO_SavedVars:NewAccountWide("BrightHarbingerTrackerSavedVariables",1,nil,defaults)

    -- Only create values if they truly do not exist yet.
    -- After that, LAM writes directly to these exact fields and /reloadui reads them back.
    if sv.timerSizePercent == nil then
        sv.timerSizePercent = (sv.timerScale and math.floor(sv.timerScale * 100)) or 100
    end
    if sv.groupCountSizePercent == nil then
        sv.groupCountSizePercent = 100
    end
    CreateUI()
    RegisterLAM()

    if SCENE_MANAGER then
        local function OnSceneStateChanged(oldState, newState)
            RefreshVisibility()
        end

        for _, sceneName in ipairs({
            "hud", "hudui", "gameMenuInGame", "inventory", "skills",
            "character", "map", "journal", "collections", "groupMenuGamepad",
            "gamepad_options_root"
        }) do
            local scene = SCENE_MANAGER:GetScene(sceneName)
            if scene then
                scene:RegisterCallback("StateChange", OnSceneStateChanged)
            end
        end
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME.."_Effect", EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME.."_Effect", EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_ABILITY_ID, BRIGHT_HARBINGER_ID)
    -- No target/source type filter here. OnEffectChanged itself requires unitTag == player.
    -- Separate group listener: does not replace or call the personal timer handler.
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME.."_GroupUID", EVENT_EFFECT_CHANGED, OnGroupUIDEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME.."_GroupUID", EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_ABILITY_ID, BRIGHT_HARBINGER_ID)

    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME.."_Update",100,Update)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME.."_PlayerActivated", EVENT_PLAYER_ACTIVATED, function()
        -- Console UI/font resources can finish initializing after addon load.
        -- Reapply the exact persisted sizes once the player/HUD is active.
        ApplyTimerSize()
        ApplyGroupCountSize()
    end)

    zo_callLater(function()
        ApplyTimerSize()
        ApplyGroupCountSize()
    end, 500)

    SLASH_COMMANDS["/bh"]=Slash
end
EVENT_MANAGER:RegisterForEvent(ADDON_NAME,EVENT_ADD_ON_LOADED,OnLoaded)
