-- Jesus de Platre - Private Taunt Marker v0.5.0 (target health-bar indicator)
-- Private, current-target HUD only. Does NOT attach markers to world entities.
local ADDON = "JesusDePlatre_PrivateMarker"
local TICK = ADDON .. "_Tick"
local TAUNT_ID = 38254
local states = {
  mine = {0.20, 0.95, 0.35, "YOUR TAUNT"},
  other = {0.25, 0.65, 1.00, "OTHER TAUNT"},
  none = {1.00, 0.25, 0.25, "NO TAUNT"},
  unknown = {1.00, 0.82, 0.28, "TAUNT: UNKNOWN"},
}
local defaults = {enabled=true, x=0, y=-195, scale=1, showName=true, world=false, hud=true, plate=true, plateX=0, plateY=-6, plateSide="above"}
local saved, panel, arrow, label, nameLabel, timerLabel, lastAppearance
local demoState
local platePanel, plateArrow, plateText, plateTimer, plateName
local plateCandidates={"ZO_TargetUnitFramereticleover", "ZO_TargetUnitFramereticleoverFrame", "ZO_TargetUnitFramereticleoverHealth", "ZO_TargetUnitFramereticleoverHealthBar"}
local plateFrame=nil
local function Print(msg) d("|c66CCFF[JDP Marker]|r " .. msg) end
local worldMarker, worldErrorPrinted = nil, false
local lastSample = nil
local lastSeenAt = nil
local lastWorldCoordinates = nil
local function RecordTargetSample()
  if not DoesUnitExist("reticleover") then return end
  local name = GetUnitName("reticleover") or "Unknown"
  local dead = IsUnitDead("reticleover")
  local attackable = IsUnitAttackable("reticleover")
  local zone, x, y, z = nil, nil, nil, nil
  local result = "API unavailable"
  if type(GetUnitWorldPosition) == "function" then
    local ok, a, b, c, d = pcall(GetUnitWorldPosition, "reticleover")
    if ok then
      zone, x, y, z = a, b, c, d
      if type(x)=="number" and type(y)=="number" and type(z)=="number" and not (x==0 and y==0 and z==0) then
        result = "nonzero coordinates"
        lastWorldCoordinates = {zone=zone,x=x,y=y,z=z,name=name}
      else
        result = "missing/zero coordinates"
      end
    else
      result = "API error: " .. tostring(a)
    end
  end
  lastSample = {name=name,dead=dead,attackable=attackable,zone=zone,x=x,y=y,z=z,result=result}
  lastSeenAt = GetFrameTimeSeconds and GetFrameTimeSeconds() or nil
end
local function ValidWorldTarget()
  if not DoesUnitExist("reticleover") or IsUnitDead("reticleover") or not IsUnitAttackable("reticleover") then return nil end
  if type(GetUnitWorldPosition) ~= "function" or type(WorldPositionToGuiRender3DPosition) ~= "function" then return nil end
  local ok, zone, x, y, z = pcall(GetUnitWorldPosition, "reticleover")
  if not ok or not zone or not x or not y or not z or (x==0 and y==0 and z==0) then return nil end
  local pOk, pZone = pcall(GetUnitWorldPosition, "player")
  if pOk and pZone and zone ~= pZone then return nil end
  local converted, rx, ry, rz = pcall(WorldPositionToGuiRender3DPosition, x, y, z)
  if not converted or type(rx)~="number" or type(ry)~="number" or type(rz)~="number" then return nil end
  if rx~=rx or ry~=ry or rz~=rz then return nil end
  return rx,ry,rz,zone,x,y,z
end
local function CreateWorldMarker()
  if worldMarker then return true end
  if not WINDOW_MANAGER or not GUI_RENDER_3D_SPACE_SYSTEM_WORLD then return false end
  local ok, result=pcall(function()
    local w=WINDOW_MANAGER:CreateTopLevelWindow(ADDON.."WorldRoot")
    w:SetDimensions(64,64); w:SetMouseEnabled(false); w:SetHidden(false)
    local t=WINDOW_MANAGER:CreateControl(ADDON.."WorldArrow",w,CT_TEXTURE)
    t:SetTexture("/esoui/art/floatingmarkers/quest_available_icon.dds")
    t:Create3DRenderSpace()
    t:Set3DRenderSpaceSystem(GUI_RENDER_3D_SPACE_SYSTEM_WORLD)
    t:Set3DLocalDimensions(0.8,0.8)
    t:Set3DRenderSpaceUsesDepthBuffer(false)
    t:SetHidden(true)
    return t
  end)
  if ok then worldMarker=result; return true end
  if not worldErrorPrinted then Print("World marker setup failed: "..tostring(result)); worldErrorPrinted=true end
  return false
end
local function UpdateWorld(state)
  if not saved.world or demoState or not state or not CreateWorldMarker() then
    if worldMarker then worldMarker:SetHidden(true) end
    return false
  end
  local rx,ry,rz=ValidWorldTarget()
  if not rx then worldMarker:SetHidden(true); return false end
  local c=states[state]
  local ok,err=pcall(function()
    worldMarker:Set3DRenderSpaceOrigin(rx,ry+1.8,rz)
    worldMarker:SetColor(c[1],c[2],c[3],1)
    worldMarker:SetHidden(false)
  end)
  if not ok then
    worldMarker:SetHidden(true)
    if not worldErrorPrinted then Print("3D update error: "..tostring(err));worldErrorPrinted=true end
    return false
  end
  return true
end
local function Probe()
  if not lastSample then
    Print("No target recorded. Close chat, aim at a living Bloodfiend for two seconds, then retry /jdpmarker probe.")
    return
  end
  local s=lastSample
  local age=(lastSeenAt and GetFrameTimeSeconds) and math.max(0,GetFrameTimeSeconds()-lastSeenAt) or nil
  Print(string.format("CACHED target=%s; age=%s; dead=%s; attackable=%s", tostring(s.name), age and string.format("%.1fs",age) or "unknown", tostring(s.dead), tostring(s.attackable)))
  Print(string.format("Position=%s; zone=%s; xyz=%s, %s, %s",tostring(s.result),tostring(s.zone),tostring(s.x),tostring(s.y),tostring(s.z)))
  if s.result=="nonzero coordinates" then
    Print("Nonzero enemy position detected. Try /jdpmarker world on and keep target in sight.")
  else
    Print("Enemy 3D attachment unavailable from this sample; HUD mode remains functional.")
  end
end
local function GetTargetState()
  if demoState then return demoState, 9.4, "DEMO TARGET" end
  if not DoesUnitExist("reticleover") or IsUnitDead("reticleover") or not IsUnitAttackable("reticleover") then
    return nil
  end
  local unitName = GetUnitName("reticleover") or "TARGET"
  local count = GetNumBuffs("reticleover") or 0
  for i=1,count do
    local _,_,endsAt,_,_,_,_,_,_,_,abilityId,_,castByPlayer = GetUnitBuffInfo("reticleover", i)
    if abilityId == TAUNT_ID then
      local remain = (endsAt and GetFrameTimeSeconds) and math.max(0, endsAt-GetFrameTimeSeconds()) or nil
      if castByPlayer == true then return "mine", remain, unitName end
      if castByPlayer == false then return "other", remain, unitName end
      return "unknown", remain, unitName
    end
  end
  return "none", nil, unitName
end
-- Frame anchor experiment: this is the SINGLE reticle target UI frame,
-- NOT the 3D nameplate above a moving creature. Never scan arbitrary enemy models.
local function FindTargetFrame()
  for _,n in ipairs(plateCandidates) do
    local c=_G[n]
    if c and type(c.GetWidth)=="function" and type(c.IsHidden)=="function" then
      return c,n
    end
  end
  return nil,nil
end
local function PlateProbe()
  local frame,n=FindTargetFrame()
  if frame then
    Print("Target FRAME found: "..n.."; width="..tostring(frame:GetWidth()).."; hidden="..tostring(frame:IsHidden()))
    Print("This is screen UI, not an individual NPC's floating nameplate.")
  else
    Print("Target FRAME not found. ESO UI layout or another addon may differ; HUD fallback will stay visible.")
  end
  Print("ESO does not expose arbitrary enemy nameplates as addon controls; multiple enemy-attached indicators are not supported by this test.")
end
local function CreatePlateUI()
  platePanel=WINDOW_MANAGER:CreateTopLevelWindow(ADDON.."PlatePanel")
  platePanel:SetDimensions(281,64)
  platePanel:SetMouseEnabled(false)
  platePanel:SetDrawLayer(DL_OVERLAY)
  platePanel:SetDrawTier(DT_HIGH)
  platePanel:SetHidden(true)
  plateArrow=WINDOW_MANAGER:CreateControl(nil,platePanel,CT_LABEL)
  plateArrow:SetFont("ZoFontWinH1")
  plateArrow:SetText("▼")
  plateArrow:SetDimensions(40,42)
  plateArrow:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  plateArrow:SetAnchor(LEFT,platePanel,LEFT,0,0)
  plateText=WINDOW_MANAGER:CreateControl(nil,platePanel,CT_LABEL)
  plateText:SetFont("ZoFontGameBold")
  plateText:SetDimensions(233,28)
  plateText:SetAnchor(TOPLEFT,platePanel,TOPLEFT,42,0)
  plateTimer=WINDOW_MANAGER:CreateControl(nil,platePanel,CT_LABEL)
  plateTimer:SetFont("ZoFontGame")
  plateTimer:SetDimensions(220,24)
  plateTimer:SetAnchor(TOPLEFT,plateText,BOTTOMLEFT,0,-3)
  plateName=WINDOW_MANAGER:CreateControl(nil,platePanel,CT_LABEL)
  plateName:SetFont("ZoFontGame")
  plateName:SetDimensions(230,20)
  plateName:SetColor(1,1,1,1)
  plateName:SetAnchor(TOPLEFT,plateTimer,BOTTOMLEFT,0,-5)
end
local function UpdatePlate(state, remain, unitName)
  if not platePanel then return false end
  if not saved.plate or not state then platePanel:SetHidden(true);return false end
  local frame=FindTargetFrame()
  if not frame or frame:IsHidden() or frame:GetWidth()<=0 then
    platePanel:SetHidden(true)
    return false
  end
  -- Re-anchor every tick: offsets/side can be changed via slash commands.
  -- This anchors to the target HEALTH-BAR UI, not the NPC's world position.
  platePanel:ClearAnchors()
  if saved.plateSide=="below" then
    platePanel:SetAnchor(TOP,frame,BOTTOM,saved.plateX,saved.plateY)
  else
    platePanel:SetAnchor(BOTTOM,frame,TOP,saved.plateX,saved.plateY)
  end
  plateFrame=frame
  local c=states[state]
  plateArrow:SetColor(c[1],c[2],c[3],1)
  plateText:SetColor(c[1],c[2],c[3],1)
  plateTimer:SetColor(c[1],c[2],c[3],1)
  plateText:SetText(c[4])
  plateTimer:SetText(remain and remain>0 and string.format("%.1fs remaining",remain) or (state=="none" and "No active taunt detected" or "Time unavailable"))
  plateName:SetText(saved.showName and zo_strformat("<<1>>", unitName or "") or "")
  platePanel:SetHidden(false)
  return true
end
local function Place()
  if not panel then return end
  panel:ClearAnchors()
  panel:SetAnchor(CENTER, GuiRoot, CENTER, saved.x, saved.y)
  panel:SetScale(saved.scale)
end
local function Update()
  RecordTargetSample()
  if not panel or not saved.enabled then
    if worldMarker then worldMarker:SetHidden(true) end
    if panel then panel:SetHidden(true) end
    if platePanel then platePanel:SetHidden(true) end
    return
  end
  local state, remain, unitName = GetTargetState()
  if not state then panel:SetHidden(true); if platePanel then platePanel:SetHidden(true) end; if worldMarker then worldMarker:SetHidden(true) end; lastAppearance=nil; return end
  local worldDrawn=UpdateWorld(state)
  local plateDrawn=UpdatePlate(state,remain,unitName)
  local c=states[state]
  if lastAppearance ~= state then
    arrow:SetColor(c[1],c[2],c[3],1)
    label:SetColor(c[1],c[2],c[3],1)
    timerLabel:SetColor(c[1],c[2],c[3],1)
    label:SetText(c[4]); lastAppearance=state
  end
  nameLabel:SetText(saved.showName and zo_strformat("<<1>>", unitName) or "")
  if remain and remain > 0 and state ~= "none" then
    timerLabel:SetText(string.format("%.1fs",remain))
  else
    timerLabel:SetText("")
  end
  panel:SetHidden(not saved.hud or plateDrawn or (saved.world and worldDrawn))
end
local function CreateUI()
  local wm=WINDOW_MANAGER
  panel=wm:CreateTopLevelWindow(ADDON.."Panel")
  panel:SetDimensions(300,92)
  panel:SetDrawLayer(DL_OVERLAY)
  panel:SetClampedToScreen(true)
  panel:SetMouseEnabled(false)
  panel:SetHidden(true)
  arrow=wm:CreateControl(nil,panel,CT_LABEL)
  arrow:SetFont("ZoFontWinH1")
  arrow:SetText("▼")
  arrow:SetDimensions(45,45)
  arrow:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  arrow:SetAnchor(LEFT,panel,LEFT,0,0)
  label=wm:CreateControl(nil,panel,CT_LABEL)
  label:SetFont("ZoFontGameBold")
  label:SetDimensions(200,26)
  label:SetAnchor(TOPLEFT,panel,TOPLEFT,45,8)
  nameLabel=wm:CreateControl(nil,panel,CT_LABEL)
  nameLabel:SetFont("ZoFontGame")
  nameLabel:SetColor(1,1,1,1)
  nameLabel:SetDimensions(250,24)
  nameLabel:SetAnchor(TOPLEFT,label,BOTTOMLEFT,0,0)
  timerLabel=wm:CreateControl(nil,panel,CT_LABEL)
  timerLabel:SetFont("ZoFontGameBold")
  timerLabel:SetDimensions(170,23)
  timerLabel:SetAnchor(TOPLEFT,nameLabel,BOTTOMLEFT,0,-2)
  Place()
  CreatePlateUI()
end
local function Help()
  Print("/jdpmarker on | off | status | demo green/red/blue/yellow/off")
  Print("/jdpmarker x <number> | y <number> | scale <0.5-2> | name on/off | reset")
  Print("/jdpmarker world on/off | probe | hud on/off  (3D experimental)")
  Print("/jdpmarker plate on/off | plateprobe | platepos above/below | platex N | platey N")
end
local function Command(txt)
  local args={}
  for w in string.gmatch(string.lower(txt or ""),"%S+") do args[#args+1]=w end
  local a=args[1]
  if a=="on" then saved.enabled=true; demoState=nil; Print("Enabled")
  elseif a=="off" then saved.enabled=false; demoState=nil; Print("Disabled")
  elseif a=="demo" then
    local map={green="mine",red="none",blue="other",yellow="unknown"}
    if args[2]=="off" then demoState=nil; Print("Live target detection restored")
    elseif map[args[2]] then demoState=map[args[2]]; saved.enabled=true; Print("Demo "..args[2])
    else Print("Use demo green/red/blue/yellow/off") end
  elseif a=="x" or a=="y" then
    local v=tonumber(args[2]); if v and v>=-900 and v<=900 then saved[a]=math.floor(v); Place(); Print(a.."="..saved[a]) else Print("Use -900 to 900") end
  elseif a=="scale" then
    local v=tonumber(args[2]); if v and v>=0.5 and v<=2 then saved.scale=v; Place(); Print("Scale="..v) else Print("Use 0.5 to 2") end
  elseif a=="name" then
    if args[2]=="on" or args[2]=="off" then saved.showName=(args[2]=="on"); Print("Target name "..args[2]) else Print("Use name on/off") end
  elseif a=="probe" then Probe()
  elseif a=="plateprobe" then PlateProbe()
  elseif a=="plate" then
    if args[2]=="on" or args[2]=="off" then saved.plate=(args[2]=="on"); plateFrame=nil; Print("Target frame marker "..args[2])
    else Print("Use plate on/off") end
  elseif a=="platepos" then
    if args[2]=="above" or args[2]=="below" then saved.plateSide=args[2]; Print("Target bar indicator "..args[2])
    else Print("Use platepos above/below") end
  elseif a=="platex" or a=="platey" then
    local n=tonumber(args[2]); if n and n>=-500 and n<=500 then
      saved[a=="platex" and "plateX" or "plateY"]=math.floor(n)
      Print(a.."="..math.floor(n))
    else Print("Use a number from -500 to 500") end
  elseif a=="world" or a=="hud" then
    if args[2]=="on" or args[2]=="off" then saved[a]=(args[2]=="on"); Print(a.." "..args[2])
    else Print("Use "..a.." on/off") end
  elseif a=="reset" then
    saved.x=0; saved.y=-195; saved.scale=1; Place(); Print("Position reset")
  elseif a=="status" then
    Print(string.format("Enabled=%s, x=%d, y=%d, scale=%.2f, demo=%s",tostring(saved.enabled),saved.x,saved.y,saved.scale,tostring(demoState)))
    Print("World experimental="..tostring(saved.world)..", target-frame marker="..tostring(saved.plate)..", HUD="..tostring(saved.hud)..". Current target only.")
    Print(string.format("Bar position=%s, x=%d, y=%d", saved.plateSide, saved.plateX, saved.plateY))
  elseif a=="help" then Help()
  else Help() end
  lastAppearance=nil; Update()
end
local function OnLoaded(_,name)
  if name~=ADDON then return end
  EVENT_MANAGER:UnregisterForEvent(ADDON,EVENT_ADD_ON_LOADED)
  JDPPrivateMarkerSaved=JDPPrivateMarkerSaved or {}
  saved=JDPPrivateMarkerSaved
  for k,v in pairs(defaults) do if saved[k]==nil then saved[k]=v end end
  -- Turn on the health-bar indicator once when upgrading from the earlier
  -- diagnostic builds, without overriding later user choices.
  if (saved.configVersion or 0)<5 then
    saved.plate=true
    saved.hud=true
    saved.world=false
    saved.configVersion=5
  end
  -- Migrate previous default offset so indicator is visibly above the center of the screen.
  if saved.y==-95 then saved.y=-195 end
  -- Multi-target v0.6 replaces the primary display. Older indicators can
  -- still be re-enabled individually via /jdpmarker hud on or plate on.
  if (saved.configVersion or 0)<6 then
    saved.plate=false
    saved.hud=false
    saved.world=false
    saved.configVersion=6
  end
  CreateUI()
  SLASH_COMMANDS["/jdpmarker"]=Command
  EVENT_MANAGER:RegisterForUpdate(TICK,100,Update)
  EVENT_MANAGER:RegisterForEvent(ADDON.."_Target",EVENT_RETICLE_TARGET_CHANGED,Update)
  Print("v0.6.0 loaded: multi-target panel via /jdptaunt; old HUD optional via /jdpmarker")
end
EVENT_MANAGER:RegisterForEvent(ADDON,EVENT_ADD_ON_LOADED,OnLoaded)
