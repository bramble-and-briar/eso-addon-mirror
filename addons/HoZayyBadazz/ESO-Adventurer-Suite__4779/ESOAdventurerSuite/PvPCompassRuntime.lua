-- ESO Adventurer Suite
-- PvP Compass / World Direction Runtime
-- Lightweight directional markers for PvP objectives when ESO does not expose a usable raw-world Z coordinate.
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.

local EPC = ESOProgressionCoach
if not EPC or not EPC.PvP then return end
local P = EPC.PvP

if P._compassRuntimeLoaded029754 then return end
P._compassRuntimeLoaded029754 = true

local pi = math.pi
local atan2 = math.atan2 or math.atan
local FOV = pi * 0.60

local function sv() return EPC.saved or EPC.defaults or {} end
local function call(name, fallback, ...)
    local fn = rawget(_G, name)
    if type(fn) ~= "function" then return fallback end
    local ok, a,b,c,d,e,f,g,h = pcall(fn, ...)
    if not ok or a == nil then return fallback end
    return a,b,c,d,e,f,g,h
end
local function num(v,d) local n=tonumber(v); if n==nil then return tonumber(d) or 0 end return n end
local function clean(v)
    v=tostring(v or "")
    if v~="" and type(zo_strformat)=="function" then local ok,r=pcall(zo_strformat,"<<C:1>>",v); if ok and r and r~="" then v=r end end
    return v
end

local function bgContext()
    local fn=rawget(_G,"ZO_WorldMap_GetBattlegroundQueryType")
    if type(fn)=="function" then local ok,v=pcall(fn); if ok and v~=nil then return v end end
    return rawget(_G,"BGQUERY_LOCAL") or rawget(_G,"BGQUERY_ASSIGNED_CAMPAIGN") or 1
end

function P:EnsurePvPCompass029754()
    if self.pvpCompass029754 then return end
    if not WINDOW_MANAGER or not COMPASS or not COMPASS.container then return end
    local root = WINDOW_MANAGER:CreateControl("EAS_PvPCompass029754", COMPASS.container, CT_CONTROL)
    root:SetAnchorFill(COMPASS.container)
    root:SetMouseEnabled(false)
    root:SetHidden(true)
    self.pvpCompass029754 = root
    self.pvpCompassMarkers029754 = {}
end

function P:GetCompassMarker029754(index)
    self:EnsurePvPCompass029754()
    if not self.pvpCompass029754 then return nil end
    local marker = self.pvpCompassMarkers029754[index]
    if marker then return marker end
    marker = WINDOW_MANAGER:CreateControl(nil, self.pvpCompass029754, CT_CONTROL)
    marker:SetDimensions(86, 42)
    marker:SetMouseEnabled(false)
    local icon = WINDOW_MANAGER:CreateControl(nil, marker, CT_TEXTURE)
    icon:SetDimensions(24,24)
    icon:SetAnchor(TOP, marker, TOP, 0, 0)
    icon:SetTexture("/esoui/art/ava/ava_rankicon_general_01.dds")
    local label = WINDOW_MANAGER:CreateControl(nil, marker, CT_LABEL)
    label:SetAnchor(TOPLEFT, icon, BOTTOMLEFT, -31, -2)
    label:SetDimensions(86,18)
    label:SetFont("ZoFontGameSmall")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    marker.icon, marker.label = icon, label
    marker:SetHidden(true)
    self.pvpCompassMarkers029754[index] = marker
    return marker
end

function P:HidePvPCompass029754()
    if self.pvpCompass029754 then self.pvpCompass029754:SetHidden(true) end
    for _, m in ipairs(self.pvpCompassMarkers029754 or {}) do m:SetHidden(true) end
end

function P:IsUnitWithinPvPMarkerDistance029754(unitTag)
    local maxMeters = math.max(25, num(sv().pvp3DDistance029753, 450))
    local pZone, px, py, pz = call("GetUnitRawWorldPosition", nil, "player")
    local uZone, ux, uy, uz = call("GetUnitRawWorldPosition", nil, unitTag)
    px, py, pz, ux, uy, uz = tonumber(px), tonumber(py), tonumber(pz), tonumber(ux), tonumber(uy), tonumber(uz)
    if not px or not py or not pz or not ux or not uy or not uz then return true end
    if pZone ~= nil and uZone ~= nil and pZone ~= uZone then return false end
    local dx, dy, dz = px - ux, py - uy, pz - uz
    return (math.sqrt(dx * dx + dy * dy + dz * dz) / 100) <= maxMeters
end

function P:AddDirectionalCandidate029754(list, kind, x, y, label, texture, priority)
    x,y=tonumber(x),tonumber(y)
    if not x or not y or x<0 or x>1 or y<0 or y>1 then return end
    list[#list+1]={kind=kind,x=x,y=y,label=label or kind,texture=texture,priority=priority or 0}
end

function P:BuildDirectionalCandidates029754()
    local s=sv()
    local list={}
    local context=self:GetContext()
    if not self:IsPvPContext() or s.pvp3DMarkers029753==false then return list end
    local bg=bgContext()

    if s.pvp3DGroupCrown029753~=false then
        local size=num(call("GetGroupSize",0),0)
        for i=1,size do
            local tag="group"..tostring(i)
            if call("DoesUnitExist",false,tag)==true and call("IsUnitGroupLeader",false,tag)==true and self:IsUnitWithinPvPMarkerDistance029754(tag) then
                local x,y=call("GetMapPlayerPosition",nil,tag)
                self:AddDirectionalCandidate029754(list,"CROWN",x,y,"CROWN","/esoui/art/compass/quest_assistedareapin.dds",100)
                break
            end
        end
    end

    if s.pvp3DRally029753~=false then
        local x,y=call("GetMapRallyPoint",nil)
        self:AddDirectionalCandidate029754(list,"RALLY",x,y,"RALLY","/esoui/art/compass/quest_assistedareapin.dds",90)
    end

    if s.pvp3DCamps029753~=false and (context=="CYRODIIL" or context=="IMPERIAL_CITY") then
        local count=num(call("GetNumForwardCamps",0,bg),0)
        for i=1,math.min(count,8) do
            local pinType,x,y,radius,useable=call("GetForwardCampPinInfo",nil,bg,i)
            if useable~=false then
                self:AddDirectionalCandidate029754(list,"CAMP",x,y,"CAMP","/esoui/art/compass/ava_resurrection.dds",80)
            end
        end
    end

    if s.pvp3DObjectives029753~=false and (context=="CYRODIIL" or context=="IMPERIAL_CITY") then
        local count=num(call("GetNumKeeps",0),0)
        local cap=math.min(count,120)
        for i=1,cap do
            local keepId=num(call("GetKeepKeysByIndex",0,i),0)
            if keepId>0 then
                local attacked=call("GetKeepUnderAttack",false,keepId,bg)==true
                if not attacked then attacked=call("GetKeepInCombat",false,keepId,bg)==true end
                if attacked then
                    local _,x,y=call("GetKeepPinInfo",nil,keepId,bg)
                    local name=clean(call("GetKeepName","OBJECTIVE",keepId))
                    self:AddDirectionalCandidate029754(list,"KEEP",x,y,name,"/esoui/art/compass/ava_capture_neutral.dds",75)
                end
            end
        end
    end

    if s.pvpMapDanger029753~=false or s.pvp3DObjectives029753~=false then
        local count=num(call("GetNumKillLocations",0),0)
        for i=1,math.min(count,10) do
            local _,x,y=call("GetKillLocationPinInfo",nil,i)
            self:AddDirectionalCandidate029754(list,"BATTLE",x,y,"BATTLE","/esoui/art/compass/ava_killlocation.dds",60)
        end
    end

    if s.pvp3DScrolls029753~=false and context=="CYRODIIL" then
        local count=num(call("GetNumKeeps",0),0)
        for i=1,math.min(count,120) do
            local keepId=num(call("GetKeepKeysByIndex",0,i),0)
            if keepId>0 and rawget(_G,"KEEPTYPE_ARTIFACT_KEEP") and call("GetKeepType",0,keepId)==KEEPTYPE_ARTIFACT_KEEP then
                local objectiveId=num(call("GetKeepArtifactObjectiveId",0,keepId),0)
                if objectiveId>0 then
                    local name,artifactType,state=call("GetObjectiveInfo","",keepId,objectiveId,bg)
                    if state~=rawget(_G,"OBJECTIVE_CONTROL_STATE_FLAG_AT_BASE") then
                        local _,x,y=call("GetKeepPinInfo",nil,keepId,bg)
                        self:AddDirectionalCandidate029754(list,"SCROLL",x,y,clean(name)~="" and clean(name) or "SCROLL","/esoui/art/compass/ava_artifact_neutral.dds",95)
                    end
                end
            end
        end
    end

    table.sort(list,function(a,b) return (a.priority or 0)>(b.priority or 0) end)
    local maxVisible=math.max(1,math.min(24,num(s.pvp3DMaxVisible029753,24)))
    while #list>maxVisible do table.remove(list) end
    return list
end

function P:RefreshPvPCompass029754()
    self:EnsurePvPCompass029754()
    local root=self.pvpCompass029754
    if not root then return end
    if not self:ShouldDisplay() or sv().pvp3DMarkers029753==false then self:HidePvPCompass029754(); return end

    local px,py=call("GetMapPlayerPosition",nil,"player")
    px,py=tonumber(px),tonumber(py)
    if not px or not py then self:HidePvPCompass029754(); return end
    local heading=num(call("GetPlayerCameraHeading",0),0)
    if heading>pi then heading=heading-(2*pi) end
    local width=COMPASS.container:GetWidth()
    local candidates=self:BuildDirectionalCandidates029754()
    local shown=0
    for i,c in ipairs(candidates) do
        local dx=px-c.x
        local dy=py-c.y
        local angle=-atan2(dx,dy)+heading
        if angle>pi then angle=angle-(2*pi) elseif angle<-pi then angle=angle+(2*pi) end
        local norm=2*angle/FOV
        if math.abs(norm)<=1 then
            shown=shown+1
            local m=self:GetCompassMarker029754(shown)
            if m then
                local x=0.5*width*norm
                m:ClearAnchors()
                m:SetAnchor(TOP,root,TOP,x-43,1)
                if c.texture and c.texture~="" then m.icon:SetTexture(c.texture) end
                m.label:SetText(tostring(c.label or c.kind))
                if c.kind=="CROWN" then m.icon:SetColor(1.0,0.82,0.18,1)
                elseif c.kind=="CAMP" then m.icon:SetColor(0.45,1.0,0.55,1)
                elseif c.kind=="BATTLE" then m.icon:SetColor(1.0,0.30,0.15,1)
                elseif c.kind=="SCROLL" then m.icon:SetColor(0.85,0.60,1.0,1)
                else m.icon:SetColor(1.0,0.72,0.22,1) end
                m:SetHidden(false)
            end
        end
    end
    for i=shown+1,#(self.pvpCompassMarkers029754 or {}) do self.pvpCompassMarkers029754[i]:SetHidden(true) end
    root:SetHidden(shown==0)
end

function P:InstallCompassRuntime029754()
    if self._compassRuntimeInstalled029754 then return end
    self._compassRuntimeInstalled029754=true
    self:EnsurePvPCompass029754()
    local key=EPC.name.."_PvPCompass029754"
    EPC.Runtime:UnregisterUpdate("PvPCompassRuntime", key)
    EPC.Runtime:RegisterUpdate("PvPCompassRuntime", key,250,function()
        if P:IsPvPContext() then P:RefreshPvPCompass029754() else P:HidePvPCompass029754() end
    end)
end

local baseInitialize=P.Initialize
function P:Initialize(...)
    local result
    if type(baseInitialize)=="function" then result=baseInitialize(self,...) end
    self:InstallCompassRuntime029754()
    return result
end
