-- Console gamepad mover for the eight-tracker PS5 build
JHSetTrackers.ConsoleMove = { active=false, speed=420, preview=false, previousShow=false }
local EM = EVENT_MANAGER
local function Target() return JHSetTrackers.ConsoleTarget end
local function C() return WINDOW_MANAGER:GetControlByName(Target() .. "_Container") end
local function EnsureControl()
  local key=Target(); local c=C(); if c then return c end
  local s=JHSetTrackers.Data.Sets[key]; if not s then return nil end
  JHSetTrackers.ConsoleMove.preview = not s.enabled
  if JHSetTrackers.ConsoleMove.preview then s.enabled=true end
  JHSetTrackers.ConsoleMove.previousShow=JHSetTrackers.UI.showIcons
  JHSetTrackers.UI.showIcons=true
  JHSetTrackers.UI.Draw(key)
  c=C(); if c then c:SetHidden(false) end
  return c
end
local function Save()
  -- Position is written directly to p.x/p.y while moving, just like Landslide.
  -- Do NOT read GetLeft()/GetTop() from a scaled control here: on console those
  -- values can be scale-adjusted and caused the saved position to drift after /reloadui.
  local am=GetAddOnManager and GetAddOnManager()
  if am and am.RequestAddOnSavedVariablesPrioritySave then am:RequestAddOnSavedVariablesPrioritySave("TrackersByJH") end
end
local last=0
local function Update()
  if not JHSetTrackers.ConsoleMove.active then return end
  local c=C(); if not c then return end
  local x=GetGamepadLeftStickX and GetGamepadLeftStickX(true) or 0
  local y=GetGamepadLeftStickY and GetGamepadLeftStickY(true) or 0
  if math.abs(x)<0.18 then x=0 end; if math.abs(y)<0.18 then y=0 end
  local now=GetGameTimeMilliseconds(); local dt=0.016
  if last>0 then dt=math.min((now-last)/1000,0.05) end; last=now
  if x==0 and y==0 then return end
  local p=JHSetTrackers.preferences.sets[Target()]
  p.x=(p.x or 150)+x*JHSetTrackers.ConsoleMove.speed*dt
  p.y=(p.y or 150)-y*JHSetTrackers.ConsoleMove.speed*dt
  c:ClearAnchors(); c:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,p.x,p.y)
end
local function Stop()
  if not JHSetTrackers.ConsoleMove.active then return end
  EM:UnregisterForUpdate(JHSetTrackers.name.."ConsoleMove")
  JHSetTrackers.ConsoleMove.active=false; last=0; Save()
  local s=JHSetTrackers.Data.Sets[Target()]; local c=C()
  if JHSetTrackers.ConsoleMove.preview and s then s.enabled=false; if c then c:SetHidden(true) end end
  JHSetTrackers.UI.showIcons=JHSetTrackers.ConsoleMove.previousShow
  JHSetTrackers.ConsoleMove.preview=false
  d("[Trackers by JH] Move mode OFF - position saved")
end
local function Start()
  if JHSetTrackers.ConsoleMove.active then return end
  local c=EnsureControl(); if not c then d("[Trackers by JH] Tracker could not be created") return end
  JHSetTrackers.ConsoleMove.active=true; last=0; c:SetHidden(false)
  EM:RegisterForUpdate(JHSetTrackers.name.."ConsoleMove",16,Update)
  d("[Trackers by JH] Move mode ON - left stick moves "..Target())
end
local function Toggle() if JHSetTrackers.ConsoleMove.active then Stop() else Start() end end
local function Reset()
  local p=JHSetTrackers.preferences and JHSetTrackers.preferences.sets[Target()]; if not p then return end
  p.x=150; p.y=150; local c=C(); if c then c:ClearAnchors(); c:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,150,150) end; Save()
end

JHSetTrackers.ConsoleMove.Toggle = Toggle
JHSetTrackers.ConsoleMove.Start = Start
JHSetTrackers.ConsoleMove.Reset = Reset
JHSetTrackers.ConsoleMove.Stop = Stop
JHSetTrackers.ConsoleMove.Select = function(key)
  if JHSetTrackers.ConsoleMove.active then Stop() end
  JHSetTrackers.ConsoleTarget = key
end

SLASH_COMMANDS["/coolmove"] = Toggle
local function SetupLAM_DISABLED()
  if not LibAddonMenu2 then return end
  local panel=JHSetTrackers.name.."ConsoleMovePanel"
  LibAddonMenu2:RegisterAddonPanel(panel,{type="panel",name="Trackers by JH - Set Trackers",displayName="Trackers by JH - Set Trackers",author="JH",version="1.0.4",registerForRefresh=true})
  LibAddonMenu2:RegisterOptionControls(panel,{
    {type="description",text="Eight-tracker console test build. Mouse movement removed. Choose a tracker, enable Move Mode, and use the left stick."},
    {type="dropdown",name="Tracker to move",choices=JHSetTrackers.ConsoleTargets,getFunc=function() return Target() end,setFunc=function(v) if JHSetTrackers.ConsoleMove.active then Stop() end; JHSetTrackers.ConsoleTarget=v end,width="full"},
    {type="slider",name="Gamepad move speed",min=100,max=1000,step=25,getFunc=function() return JHSetTrackers.ConsoleMove.speed end,setFunc=function(v) JHSetTrackers.ConsoleMove.speed=v end,width="full"},
    {type="button",name="Toggle move mode",func=Toggle,width="full"},
    {type="button",name="Reset selected tracker position",func=Reset,width="full"},
  })
end
local function Loaded(_,name) if name~="TrackersByJH" then return end end
EM:RegisterForEvent(JHSetTrackers.name.."ConsoleMoveLoader",EVENT_ADD_ON_LOADED,Loaded)
