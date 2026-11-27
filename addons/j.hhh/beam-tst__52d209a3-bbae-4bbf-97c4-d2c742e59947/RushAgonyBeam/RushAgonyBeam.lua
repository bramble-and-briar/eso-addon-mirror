-- Rush of Agony Beam -- standalone PlayStation / gamepad addon.
-- EXACT LOCAL 5pc decision: original JH LibEquipmentBonus:IsSetEquipped().
-- GROUP decision: LibSetDetection 5.0's fully-active set result received via
-- LibGroupBroadcast. Without LGB, no remote equipment data is available.
RushAgonyBeam = RushAgonyBeam or {}
local AB = RushAgonyBeam
local NAME = "RushAgonyBeam"
local SET_NAME = "Rush of Agony"
local DEFAULTS = {
    enabled = true, showOwnBeam = true, color = { 0.25, 0.85, 1, 0.85 },
    width = 240, brightness = 90, depth = false,
}
local installed = false
local equipTracker
local liveBeams = {}
local ownEnabled = false
local pvp = false
local nextSetScan = 0
local nextPvPCheck = 0
local nextGroupCheck = 0
local nextSettingsRefresh = 0
local remoteSetId
local groupActive = {}
local lastGroupScan = 0
local validPvPWorld = false

local function InPvPWorld()
    if type(IsPlayerInAvAWorld) == "function" and IsPlayerInAvAWorld() then return true end
    if type(IsActiveWorldBattleground) == "function" and IsActiveWorldBattleground() then return true end
    if type(IsInImperialCity) == "function" and IsInImperialCity() then return true end
    return false
end

local function SetColor(control)
    local sv = AB.sv
    local c = sv.color or DEFAULTS.color
    -- Alpha is capped at 1 by the renderer. Above 100%, an identical
    -- overlay contributes extra light instead of relying on alpha > 1.
    local brightness = zo_clamp(tonumber(sv.brightness) or 90, 20, 200)
    local isGlowLayer = control._rushGlowLayer == true
    local strength = isGlowLayer and math.max(0, brightness - 100) / 100
        or math.min(brightness, 100) / 100
    control:SetColor(c[1] or 1, c[2] or 1, c[3] or 1,
        (c[4] or 1) * strength)
    -- Keep the existing width-slider mapping unchanged. The beam is centered
    -- 20000 world centimeters above the feet; 400 local units = 40000 cm,
    -- so its lower edge is at the player's feet rather than 5000 cm below.
    control:Set3DLocalDimensions((sv.width or 240) / 100, 400)
    control:Set3DRenderSpaceUsesDepthBuffer(not sv.depth)
end

local function CreateBeam(unitTag)
    local win = WINDOW_MANAGER:CreateTopLevelWindow("RushAgonyBeamWin_" .. unitTag)
    win:SetDimensions(1,1)
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, -10,-10)
    win:SetMouseEnabled(false)
    win:SetHidden(false)
    win:SetDrawLayer(DL_BACKGROUND)
    win:SetDrawTier(DT_LOW)
    win:Create3DRenderSpace()
    local tex = WINDOW_MANAGER:CreateControl("RushAgonyBeamTex_" .. unitTag, win, CT_TEXTURE)
    tex:SetTexture("RushAgonyBeam/media/AgonyBeam.dds")
    tex:SetBlendMode(TEX_BLEND_MODE_ALPHA)
    tex:SetAddressMode(TEX_MODE_CLAMP)
    tex:Create3DRenderSpace()
    tex:Set3DRenderSpaceOrientation(0,0,0)
    tex:SetHidden(true)
    -- Optional brightness overlay: same texture, 3D geometry and position.
    -- It remains invisible at or below 100%, preserving the original beam.
    local glow = WINDOW_MANAGER:CreateControl("RushAgonyBeamGlow_" .. unitTag, win, CT_TEXTURE)
    glow._rushGlowLayer = true
    glow:SetTexture("RushAgonyBeam/media/AgonyBeam.dds")
    glow:SetBlendMode(TEX_BLEND_MODE_ALPHA)
    glow:SetAddressMode(TEX_MODE_CLAMP)
    glow:Create3DRenderSpace()
    glow:Set3DRenderSpaceOrientation(0,0,0)
    glow:SetHidden(true)
    local instance = { win=win, tex=tex, glow=glow, shown=false, lastX=nil, lastY=nil, lastZ=nil }
    liveBeams[unitTag] = instance
    SetColor(tex)
    SetColor(glow)
    return instance
end

local function HideOne(unitTag)
    local item = liveBeams[unitTag]
    if item then
        item.tex:SetHidden(true)
        if item.glow then item.glow:SetHidden(true) end
        item.shown=false
    end
end

local function HideAll()
    for tag in pairs(liveBeams) do HideOne(tag) end
end

local function GetGroupStatus(unitTag)
    -- IMPORTANT: Do not guess equipment from damage procs or another player's buff.
    -- This is only true when remote LibSetDetection data confirms active 5pc.
    return groupActive[unitTag] == true
end

local function IsUnitEligible(tag)
    if tag == "player" then return ownEnabled end
    if not LibGroupBroadcast then return false end
    if type(IsUnitGrouped) == "function" and not IsUnitGrouped(tag) then return false end
    if type(DoesUnitExist) == "function" and not DoesUnitExist(tag) then return false end
    if type(IsUnitOnline) == "function" and not IsUnitOnline(tag) then return false end
    return GetGroupStatus(tag)
end

-- The 3D coordinates are refreshed on EVERY rendered frame, not once per 100ms.
-- No interpolation or delayed smoothing: both cause noticeable trailing.
local function DrawOne(tag)
    -- Presentation-only switch: never change ownEnabled/AB.hasFive or
    -- the data shared with the group. Other clients decide their own visuals.
    if tag == "player" and AB.sv and AB.sv.showOwnBeam == false then
        HideOne(tag)
        return
    end
    if not AB.sv or not AB.sv.enabled or not pvp or not IsUnitEligible(tag) then
        HideOne(tag)
        return
    end
    if IsUnitDead and IsUnitDead(tag) then HideOne(tag); return end
    local zoneId, x, y, z = GetUnitRawWorldPosition(tag)
    if tag ~= "player" then
        local playerZone = GetUnitRawWorldPosition("player")
        if zoneId and playerZone and zoneId ~= 0 and playerZone ~= 0 and zoneId ~= playerZone then
            HideOne(tag); return
        end
    end
    local item = liveBeams[tag]
    if not x or not y or not z or (x == 0 and y == 0 and z == 0) then
        -- World changes can temporarily return zero. Never draw at the origin.
        HideOne(tag)
        return
    end
    if not item then item = CreateBeam(tag) end
    local gx, gy, gz = WorldPositionToGuiRender3DPosition(x, y + 20000, z)
    if not gx or not gy or not gz then HideOne(tag); return end
    -- Camera-facing vertical billboard: yaw is updated on every rendered frame,
    -- together with the existing position update. No extra smoothing or timing.
    -- ESO's Lights of Meridia uses GetPlayerCameraHeading() for its beam yaw.
    if type(GetPlayerCameraHeading) == "function" then
        local heading = GetPlayerCameraHeading()
        if type(heading) == "number" then
            item.tex:Set3DRenderSpaceOrientation(0, heading, 0)
            if item.glow then item.glow:Set3DRenderSpaceOrientation(0, heading, 0) end
        end
    end
    item.tex:Set3DRenderSpaceOrigin(gx,gy,gz)
    if item.glow then item.glow:Set3DRenderSpaceOrigin(gx,gy,gz) end
    if not item.shown then item.tex:SetHidden(false); item.shown=true end
    if item.glow then
        item.glow:SetHidden((tonumber(AB.sv.brightness) or 90) <= 100)
    end
end

function AB.RefreshOwnSet()
    ownEnabled = equipTracker and equipTracker:IsSetEquipped(SET_NAME) == true or false
    AB.hasFive = ownEnabled
end

local function IsRushName(name)
    if type(name) ~= "string" then return false end
    -- Keep the actual set name as reported by ESO; don't infer from partial names.
    local lowered = zo_strlower(name)
    return lowered == zo_strlower(SET_NAME) or lowered == zo_strlower("Auftreibende Agonie")
end

local function RefreshGroupSets()
    local LSD = LibSetDetection
    local result = {}
    if not LibGroupBroadcast or not LSD or type(LSD.GetUnitSetData) ~= "function" then
        groupActive = result
        return
    end
    local count = type(GetGroupSize) == "function" and (GetGroupSize() or 0) or 0
    for i=1,math.min(count,24) do
        local tag = type(GetGroupUnitTagByIndex) == "function" and GetGroupUnitTagByIndex(i)
        if tag and tag ~= "" and tag ~= "player" then
            -- Local player still follows JH's original detector.
            if type(AreUnitsEqual) == "function" and AreUnitsEqual(tag,"player") then
                result[tag] = ownEnabled
            else
                local ok, sets = pcall(LSD.GetUnitSetData, tag)
                if ok and type(sets) == "table" then
                    for setId, record in pairs(sets) do
                        if type(record) == "table" and IsRushName(record.setName) then
                            -- LibSetDetection activeType > 0 means the five-piece
                            -- set is complete on front OR back, not both mixed.
                            result[tag] = (tonumber(record.activeType) or 0) > 0
                            break
                        end
                    end
                end
            end
        end
    end
    groupActive = result
    lastGroupScan = GetFrameTimeMilliseconds()
end

local function RefreshWorld()
    pvp = InPvPWorld()
    if not pvp then HideAll() end
    for _, item in pairs(liveBeams) do
        -- On zone switches 3D render spaces can become invalid.
        item.tex:SetHidden(true)
        if item.glow then item.glow:SetHidden(true) end
        item.shown = false
        item.tex:Destroy3DRenderSpace()
        item.tex:Create3DRenderSpace()
        item.tex:Set3DRenderSpaceOrientation(0,0,0)
        SetColor(item.tex)
        if item.glow then
            item.glow:Destroy3DRenderSpace()
            item.glow:Create3DRenderSpace()
            item.glow:Set3DRenderSpaceOrientation(0,0,0)
            SetColor(item.glow)
        end
    end
    AB.RefreshOwnSet()
    RefreshGroupSets()
end

local function Menu()
    local LAM = LibAddonMenu2
    if not LAM then return end
    local name = "RushAgonyBeamSettings"
    LAM:RegisterAddonPanel(name, {
        type="panel", name="The PURE HATE Rush of Agony Beam",
        displayName="The PURE HATE Rush of Agony Beam", author="Community console adaptation",
        version="1.2.3", registerForRefresh=true, registerForDefaults=true,
    })
    LAM:RegisterOptionControls(name, {
        {type="description",text="The PURE HATE Rush of Agony Beam\n\nPvP only: Cyrodiil, Imperial City (including the Sewers), and Battlegrounds. Your own 5-piece set bonus is detected using JH's original LibEquipmentBonus logic. Group member detection uses LibSetDetection 5.0 and requires LibGroupBroadcast on every player's console. Without LibGroupBroadcast, other players' beams cannot be displayed."},
        {type="checkbox",name="Enable Rush of Agony Beam",default=true,
         getFunc=function() return AB.sv.enabled end,
         setFunc=function(v) AB.sv.enabled=(v==true); if not AB.sv.enabled then HideAll() end end},
        {type="checkbox",name="Show My Own Beam",default=true,
         tooltip="Local display only: When disabled, your own beam is hidden on your screen. Your Rush of Agony set status is still detected and can be displayed by group members with compatible synchronization.",
         getFunc=function() return AB.sv.showOwnBeam ~= false end,
         setFunc=function(v)
             AB.sv.showOwnBeam=(v==true)
             if not AB.sv.showOwnBeam then HideOne("player") end
         end},
        {type="colorpicker",name="Beam Color",width="full",default={r=0.25,g=0.85,b=1,a=0.85},
         getFunc=function() return unpack(AB.sv.color) end,
         setFunc=function(r,g,b,a) AB.sv.color={r,g,b,a or 1}; for _,item in pairs(liveBeams) do SetColor(item.tex); if item.glow then SetColor(item.glow) end end end},
        {type="slider",name="Beam Brightness (%)",min=20,max=200,step=5,default=90,
         getFunc=function() return zo_clamp(tonumber(AB.sv.brightness) or 90, 20, 200) end,
         setFunc=function(v)
             AB.sv.brightness=zo_clamp(tonumber(v) or 90, 20, 200)
             for _,item in pairs(liveBeams) do
                 SetColor(item.tex)
                 if item.glow then SetColor(item.glow) end
             end
         end},
        {type="slider",name="Beam Width",min=100,max=500,step=20,default=240,
         getFunc=function() return AB.sv.width end,
         setFunc=function(v) AB.sv.width=v; for _,item in pairs(liveBeams) do SetColor(item.tex); if item.glow then SetColor(item.glow) end end end},
        {type="checkbox",name="Visible Through Walls",default=false,
         getFunc=function() return AB.sv.depth end,
         setFunc=function(v) AB.sv.depth=(v==true); for _,item in pairs(liveBeams) do SetColor(item.tex); if item.glow then SetColor(item.glow) end end end},
    })
end

local function OnFrame()
    local now = GetFrameTimeMilliseconds()
    if now >= nextPvPCheck then
        nextPvPCheck = now + 250
        local current = InPvPWorld()
        if pvp ~= current then
            pvp = current
            if not pvp then HideAll() end
        end
    end
    if not pvp or not AB.sv or not AB.sv.enabled then
        HideAll()
        return
    end
    if now >= nextSetScan then
        nextSetScan = now + 1000
        AB.RefreshOwnSet()
    end
    if now >= nextGroupCheck then
        nextGroupCheck = now + 500
        RefreshGroupSets()
    end
    DrawOne("player")
    local count = GetGroupSize and (GetGroupSize() or 0) or 0
    local visited = {player=true}
    for i=1,math.min(count,24) do
        local tag = GetGroupUnitTagByIndex and GetGroupUnitTagByIndex(i)
        if tag and tag ~= "" and not visited[tag] then
            visited[tag]=true
            if AreUnitsEqual and AreUnitsEqual(tag,"player") then
                HideOne(tag)
            else
                DrawOne(tag)
            end
        end
    end
    for tag in pairs(liveBeams) do
        if not visited[tag] then HideOne(tag) end
    end
end

local function OnLoaded(_,addonName)
    if addonName ~= NAME or installed then return end
    installed=true
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    AB.sv=ZO_SavedVars:NewAccountWide("RushAgonyBeamSavedVariables",1,nil,DEFAULTS)
    if LibEquipmentBonus and type(LibEquipmentBonus.Init)=="function" then
        equipTracker=LibEquipmentBonus:Init(NAME)
        if equipTracker then
            equipTracker:FilterBySetName(SET_NAME)
            equipTracker:Register(function(setName,active)
                if setName == SET_NAME then ownEnabled=(active==true); AB.hasFive=ownEnabled end
            end,function() end)
        end
    end
    AB.RefreshOwnSet()
    Menu()
    if LibSetDetection and LibSetDetection.constants and type(LibSetDetection.RegisterEvent)=="function" then
        local C=LibSetDetection.constants
        LibSetDetection.RegisterEvent(C.event_data_update,NAME.."GroupRefresh",
            function() RefreshGroupSets() end,C.unit_type_group)
    end
    EVENT_MANAGER:RegisterForEvent(NAME.."Activate", EVENT_PLAYER_ACTIVATED, function() RefreshWorld() end)
    if EVENT_LINKED_WORLD_POSITION_CHANGED then
        EVENT_MANAGER:RegisterForEvent(NAME.."Location",EVENT_LINKED_WORLD_POSITION_CHANGED,
            function() zo_callLater(RefreshWorld,200) end)
    end
    if EVENT_ZONE_CHANGED then
        EVENT_MANAGER:RegisterForEvent(NAME.."Zone",EVENT_ZONE_CHANGED,
            function() zo_callLater(RefreshWorld,200) end)
    end
    if EVENT_GROUP_UPDATE then
        EVENT_MANAGER:RegisterForEvent(NAME.."Group",EVENT_GROUP_UPDATE,RefreshGroupSets)
    end
    -- 3D origin is updated every rendered frame, NOT on a delayed 100ms timer.
    local driver=WINDOW_MANAGER:CreateTopLevelWindow("RushAgonyBeamFrameDriver")
    driver:SetHidden(false)
    driver:SetDimensions(1,1)
    driver:SetHandler("OnUpdate",OnFrame)
    RefreshWorld()
    if not LibGroupBroadcast and CHAT_SYSTEM then
        CHAT_SYSTEM:AddMessage("[Rush Agony Beam] LibSetDetection is included. LibGroupBroadcast is also required to display beams on other players.")
    end
end
EVENT_MANAGER:RegisterForEvent(NAME,EVENT_ADD_ON_LOADED,OnLoaded)
