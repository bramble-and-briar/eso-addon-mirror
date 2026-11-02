-- Jesus de Platre - Minimal Cyber Reticle 0.8.3
-- The reticle art is a real DXT5 texture, anchored to ESO's native reticle control.
local ADDON="JesusDePlatre_PrivateMarker"
local NS="JDPCrosshair83"
local TAUNT_ID=38254
local TEXTURE="JesusDePlatre_PrivateMarker/Textures/cyber_reticle.dds"
local defaults={
 enabled=true,size=124,x=0,y=0,anchor="native",showText=true,
 textSide="left",textOffset=22,showWhenNoTarget=true,alertAt=3,replaceOriginal=false,
}
local saved, root, reticle, status, timer, textBacking, native, nativeAlpha
local demo
local stateColors={
 mine={0.20,0.98,0.35,"YOUR TAUNT"},
 other={0.24,0.67,1,"OTHER TAUNT"},
 none={1,0.25,0.25,"NO TAUNT"},
 unknown={1,0.80,0.25,"TAUNT UNKNOWN"},
 idle={0.65,0.75,0.80,"NO TARGET"},
}
local function msg(v) d("|c55ddee[JDP Cyber]|r "..v) end
local function clock() return GetFrameTimeSeconds() end
local function obtainNative()
 local r=_G.ZO_ReticleContainerReticle
 if not r and _G.RETICLE then r=RETICLE.reticleTexture end
 if r and type(r.GetCenter)=="function" and type(r.SetAlpha)=="function" then return r end
 return nil
end
local function applyNativeVisibility()
 local target=obtainNative()
 if native and native~=target and nativeAlpha~=nil then native:SetAlpha(nativeAlpha);nativeAlpha=nil end
 native=target
 if not native then return end
 if saved.enabled and saved.replaceOriginal then
  if nativeAlpha==nil then nativeAlpha=native:GetAlpha() end
  native:SetAlpha(0)
 elseif nativeAlpha~=nil then
  native:SetAlpha(nativeAlpha)
  nativeAlpha=nil
 end
end
local function targetState()
 if demo then return demo,9.4 end
 if not DoesUnitExist("reticleover") or IsUnitDead("reticleover") or not IsUnitAttackable("reticleover") then return "idle",nil end
 for i=1,(GetNumBuffs("reticleover") or 0) do
  local _,_,endsAt,_,_,_,_,_,_,_,abilityId,_,castByPlayer=GetUnitBuffInfo("reticleover",i)
  if abilityId==TAUNT_ID then
   local remaining=type(endsAt)=="number" and math.max(0,endsAt-clock()) or nil
   if castByPlayer==true then return "mine",remaining end
   if castByPlayer==false then return "other",remaining end
   return "unknown",remaining
  end
 end
 return "none",nil
end
local function position()
 if not root then return end
 local size=math.max(64,math.min(240,tonumber(saved.size) or 124))
 root:SetDimensions(size,size)
 root:ClearAnchors()
 local ref
 if saved.anchor=="native" then ref=obtainNative() end
 root:SetAnchor(CENTER,ref or GuiRoot,CENTER, tonumber(saved.x) or 0, tonumber(saved.y) or 0)
 reticle:SetDimensions(size,size)
 reticle:ClearAnchors(); reticle:SetAnchor(CENTER,root,CENTER,0,0)
 textBacking:ClearAnchors()
 status:ClearAnchors()
 timer:ClearAnchors()
 local offset=tonumber(saved.textOffset) or 22
 if saved.textSide=="right" then
  textBacking:SetAnchor(LEFT,root,RIGHT,offset,0)
 elseif saved.textSide=="below" then
  textBacking:SetAnchor(TOP,root,BOTTOM,0,offset)
 else
  textBacking:SetAnchor(RIGHT,root,LEFT,-offset,0)
 end
 status:SetAnchor(TOPLEFT,textBacking,TOPLEFT,8,3)
 timer:SetAnchor(TOPLEFT,textBacking,TOPLEFT,8,29)
end
local function build()
 root=WINDOW_MANAGER:CreateTopLevelWindow("JDPCyberReticle083")
 root:SetDrawLayer(DL_OVERLAY);root:SetDrawTier(DT_HIGH)
 root:SetMouseEnabled(false);root:SetHidden(true)
 reticle=WINDOW_MANAGER:CreateControl(nil,root,CT_TEXTURE)
 reticle:SetTexture(TEXTURE)
 reticle:SetTextureCoords(0,1,0,1)
 reticle:SetMouseEnabled(false)
 textBacking=WINDOW_MANAGER:CreateControl(nil,root,CT_BACKDROP)
 textBacking:SetDimensions(168,60)
 textBacking:SetCenterColor(0.01,0.04,0.065,0.72)
 textBacking:SetEdgeColor(0.10,0.48,0.54,0.60)
 textBacking:SetMouseEnabled(false)
 status=WINDOW_MANAGER:CreateControl(nil,textBacking,CT_LABEL)
 status:SetFont("ZoFontGameBold");status:SetDimensions(154,25)
 timer=WINDOW_MANAGER:CreateControl(nil,textBacking,CT_LABEL)
 timer:SetFont("ZoFontWinH4");timer:SetDimensions(154,28)
 position()
end
local function update()
 if not saved or not root then return end
 applyNativeVisibility()
 if not saved.enabled then root:SetHidden(true);return end
 local st,remaining=targetState()
 if st=="idle" and not saved.showWhenNoTarget and not demo then root:SetHidden(true);return end
 local col=stateColors[st] or stateColors.idle
 local alpha=1
 if st=="mine" and remaining and remaining<=saved.alertAt then
  alpha=math.floor(clock()*5)%2==0 and 0.28 or 1
 end
 reticle:SetColor(col[1],col[2],col[3],alpha)
 status:SetText(col[4]);status:SetColor(col[1],col[2],col[3],alpha)
 timer:SetText(remaining and string.format("%.1fs",remaining) or "")
 timer:SetColor(col[1],col[2],col[3],alpha)
 textBacking:SetHidden(not saved.showText)
 root:SetHidden(false)
end
local function probe()
 local r=obtainNative()
 if r then
  local x,y=r:GetCenter()
  msg("Native reticle found: "..tostring(r:GetName()).." center="..tostring(x)..","..tostring(y))
  msg("Anchor="..saved.anchor.." x="..tostring(saved.x).." y="..tostring(saved.y))
 else msg("Native reticle unavailable; anchored to screen center. Try /jdpcross anchor native later.") end
end
local function help()
 msg("/jdpcross on/off | demo green/red/blue/yellow/off | probe")
 msg("/jdpcross anchor native/screen | x N | y N | size 64-240 | reset")
 msg("/jdpcross text on/off | textpos left/right/below | textoffset 0-150")
 msg("/jdpcross vanilla on/off | shownotarget on/off | alert 1-10")
end
local function command(s)
 local args={}; for w in string.gmatch(string.lower(s or ""),"%S+") do args[#args+1]=w end
 local a,b=args[1],args[2]
 if a=="on" or a=="off" then saved.enabled=a=="on";msg("Crosshair "..a)
 elseif a=="demo" then
  local map={green="mine",blue="other",red="none",yellow="unknown"}
  if b=="off" then demo=nil;msg("Live taunt detection restored")
  elseif map[b] then demo=map[b];saved.enabled=true;msg("Demo "..b)
  else msg("Use demo green/red/blue/yellow/off") end
 elseif a=="anchor" then
  if b=="native" or b=="screen" then saved.anchor=b;position();msg("Anchor="..b) else msg("Use anchor native/screen") end
 elseif a=="x" or a=="y" then
  local n=tonumber(b)
  if n and n>=-300 and n<=300 then saved[a]=math.floor(n);position();msg(a.."="..saved[a]) else msg("Use -300 to 300") end
 elseif a=="size" then
  local n=tonumber(b)
  if n and n>=64 and n<=240 then saved.size=math.floor(n);position();msg("Size="..saved.size) else msg("Use size 64-240") end
 elseif a=="text" or a=="shownotarget" then
  if b=="on" or b=="off" then saved[a=="text" and "showText" or "showWhenNoTarget"]=(b=="on") else msg("Use on/off") end
 elseif a=="textpos" then
  if b=="left" or b=="right" or b=="below" then saved.textSide=b;position();msg("Text on "..b) else msg("Use left/right/below") end
 elseif a=="textoffset" then
  local n=tonumber(b)
  if n and n>=0 and n<=150 then saved.textOffset=math.floor(n);position();msg("Text spacing "..n) else msg("Use 0-150") end
 elseif a=="vanilla" then
  if b=="on" or b=="off" then saved.replaceOriginal=b=="off";applyNativeVisibility();msg("Original crosshair "..b) else msg("Use vanilla on/off") end
 elseif a=="alert" then
  local n=tonumber(b)
  if n and n>=1 and n<=10 then saved.alertAt=n;msg("Flash at "..n.." seconds") else msg("Use 1-10") end
 elseif a=="probe" then probe()
 elseif a=="reset" then
  for k,v in pairs(defaults) do saved[k]=v end
  position();applyNativeVisibility();msg("Settings reset; native anchoring enabled")
 else help() end
 update()
end
local function loaded(_,name)
 if name~=ADDON then return end
 EVENT_MANAGER:UnregisterForEvent(NS.."_load",EVENT_ADD_ON_LOADED)
 JDPCrosshairSaved=JDPCrosshairSaved or {}
 saved=JDPCrosshairSaved
 for k,v in pairs(defaults) do if saved[k]==nil then saved[k]=v end end
 -- 0.8.2 used screen center. Migrate once to native anchor, zero offset.
 if (saved.cyberVersion or 0)<83 then
  saved.anchor="native";saved.x=0;saved.y=0;saved.size=124
  saved.textSide="left";saved.textOffset=22;saved.cyberVersion=83
 end
 build()
 SLASH_COMMANDS["/jdpcross"]=command
 EVENT_MANAGER:RegisterForUpdate(NS.."_tick",100,update)
 EVENT_MANAGER:RegisterForEvent(NS.."_target",EVENT_RETICLE_TARGET_CHANGED,update)
 msg("v0.8.3 loaded. Native reticle anchoring + circular texture. /jdpcross probe")
end
EVENT_MANAGER:RegisterForEvent(NS.."_load",EVENT_ADD_ON_LOADED,loaded)
