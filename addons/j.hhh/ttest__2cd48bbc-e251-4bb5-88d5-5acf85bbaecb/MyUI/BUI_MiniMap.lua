-- Satuve Xbox UI - Votan's Minimap bridge
-- Votan owns ESO's native map/minimap modes. Satuve only supplies controller
-- settings and does not create, clip, or reparent a second map viewport.

BUI.MiniMap=BUI.MiniMap or {}
local Mini=BUI.MiniMap
local RETRY_NAME="SXUI_VotanMinimapBridge"
local APPLY_NAME="SXUI_VotanMinimapApply"
local MOVE_HANDLE_NAME="BUI_Minimap"
local initialized,settingsReady=false,false

Mini.Defaults={
 MiniMap=true,MiniMapDimensions=250,MiniMapTitle=true,MiniMapAlpha=100,
 PinScale=75,BUI_Minimap={TOPRIGHT,TOPRIGHT,0,0},
 ZoomZone=60,ZoomSubZone=30,ZoomDungeon=60,ZoomCyrodiil=45,
 ZoomImperialsewer=60,ZoomImperialCity=80,ZoomMountRatio=70,
 ZoomGlobal=3,PinColor={},
}
if MAP_PIN_TYPE_GROUP_LEADER then Mini.Defaults.PinColor[MAP_PIN_TYPE_GROUP_LEADER]={1,1,0,1} end
if MAP_PIN_TYPE_GROUP then Mini.Defaults.PinColor[MAP_PIN_TYPE_GROUP]={1,1,1,1} end
if MAP_PIN_TYPE_POI_COMPLETE then Mini.Defaults.PinColor[MAP_PIN_TYPE_POI_COMPLETE]={1,1,1,1} end
if MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE then Mini.Defaults.PinColor[MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE]={1,1,1,1} end
if MAP_PIN_TYPE_ASSISTED_QUEST_ENDING then Mini.Defaults.PinColor[MAP_PIN_TYPE_ASSISTED_QUEST_ENDING]={1,1,1,1} end
BUI:JoinTables(BUI.Defaults,Mini.Defaults)

local function Clamp(value,minimum,maximum)
 value=tonumber(value) or minimum
 if value<minimum then return minimum end
 if value>maximum then return maximum end
 return value
end

local function GetVotan()
 local addon=rawget(_G,"VOTANS_MINIMAP")
 if type(addon)~="table" or type(addon.account)~="table" or type(addon.player)~="table" then return nil end
 return addon
end

local function GetMoveHandle()
 return rawget(_G,MOVE_HANDLE_NAME)
end

local function EnsureMoveHandle()
 local handle=GetMoveHandle()
 if not handle then
  handle=WINDOW_MANAGER:CreateTopLevelWindow(MOVE_HANDLE_NAME)
  handle:SetParent(GuiRoot)
  handle:SetDrawTier(DT_HIGH)
  handle:SetDrawLayer(DL_OVERLAY)
  handle:SetClampedToScreen(true)
  handle.backdrop=WINDOW_MANAGER:CreateControl(MOVE_HANDLE_NAME.."Backdrop",handle,CT_BACKDROP)
  handle.backdrop:SetAnchorFill(handle)
  handle.backdrop:SetCenterColor(0.04,0.08,0.12,0.38)
  handle.backdrop:SetEdgeColor(1,0.82,0.12,1)
  handle.backdrop:SetEdgeTexture("",8,2,2)
  local label=WINDOW_MANAGER:CreateControl(MOVE_HANDLE_NAME.."Label",handle,CT_LABEL)
  label:SetAnchor(CENTER,handle,CENTER,0,0)
  label:SetFont("ZoFontGamepad42")
  label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  label:SetText("MINIMAP")
  handle.SXUI_MoveLabel=label
  handle:SetHidden(true)
 end
 return handle
end

function Mini.PrepareMoveHandle()
 local addon=GetVotan()
 if not addon then return nil end
 local handle=EnsureMoveHandle()
 local size=math.floor(Clamp(BUI.Vars.MiniMapDimensions or 250,200,500)+0.5)
 local width=tonumber(addon.account.width) or size
 local height=tonumber(addon.account.height) or size
 handle:SetDimensions(math.max(width,32),math.max(height,32))
 handle:ClearAnchors()
 handle:SetAnchor(CENTER,GuiRoot,CENTER,tonumber(addon.account.x) or 0,tonumber(addon.account.y) or 0)
 handle:SetHidden(false)
 return handle
end

function Mini.CommitMoveHandle(control)
 local addon=GetVotan()
 local handle=control or GetMoveHandle()
 if not addon or not handle or not handle.GetCenter then return end
 local x,y=handle:GetCenter()
 local rootX,rootY=GuiRoot:GetCenter()
 if not x or not y or not rootX or not rootY then return end
 addon.account.x=x-rootX
 addon.account.y=y-rootY
 if addon.RestorePosition then addon:RestorePosition() end
end

function Mini.CancelMoveHandle() end

function Mini.HideMoveHandle()
 local handle=GetMoveHandle()
 if handle then handle:SetHidden(true) end
end

local function IsMiniMode()
 local mode=rawget(_G,"MAP_MODE_VOTANS_MINIMAP")
 return mode and WORLD_MAP_MANAGER and WORLD_MAP_MANAGER.IsInMode and WORLD_MAP_MANAGER:IsInMode(mode)
end

local function ApplyAppearance()
 if not ZO_WorldMap then return end
 if IsMiniMode() then
  ZO_WorldMap:SetAlpha(Clamp(BUI.Vars.MiniMapAlpha or 100,0,100)/100)
  if ZO_WorldMapTitle then ZO_WorldMapTitle:SetHidden(not BUI.Vars.MiniMapTitle) end
 else
  ZO_WorldMap:SetAlpha(1) -- Never fade the full world map.
 end
end

local function ApplySizeNow()
 local addon=GetVotan()
 if not addon or not ZO_WorldMap or not ZO_WorldMapScroll then return false end
 local size=math.floor(Clamp(BUI.Vars.MiniMapDimensions or 250,200,500)+0.5)
 BUI.Vars.MiniMapDimensions=size

 -- Votan stores outer-frame dimensions; Satuve stores visible map pixels.
 local chromeWidth=addon.__satuveChromeWidth
 local chromeHeight=addon.__satuveChromeHeight
 if IsMiniMode() and (chromeWidth==nil or chromeHeight==nil) then
  local frameWidth,frameHeight=ZO_WorldMap:GetDimensions()
  local mapWidth,mapHeight=ZO_WorldMapScroll:GetDimensions()
  local measuredWidth=frameWidth-mapWidth
  local measuredHeight=frameHeight-mapHeight
  if measuredWidth>=0 and measuredWidth<=128 then chromeWidth=measuredWidth end
  if measuredHeight>=0 and measuredHeight<=128 then chromeHeight=measuredHeight end
 end
 chromeWidth=chromeWidth or 3
 chromeHeight=chromeHeight or 5
 addon.__satuveChromeWidth=chromeWidth
 addon.__satuveChromeHeight=chromeHeight
 addon.account.keepSquare=true
 if addon.modeData then
  addon.modeData.keepSquare=true
  addon.modeData.width=size+chromeWidth
  addon.modeData.height=size+chromeHeight
 end
 addon.account.width=size+chromeWidth
 addon.account.height=size+chromeHeight

 if IsMiniMode() then
  ZO_WorldMapScroll:SetDimensions(size,size)
  if addon.RestorePosition then addon:RestorePosition() end
  ZO_WorldMapScroll:SetDimensions(size,size)
  local pins=ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager()
  if pins and pins.UpdatePinsForMapSizeChange then pins:UpdatePinsForMapSizeChange() end
 end
 return true
end

local function SyncVotan()
 local addon=GetVotan()
 if not addon then return false end
 addon.account.enableMap=true
 addon.player.showMap=BUI.Vars.MiniMap and true or false
 addon.account.zoom=Clamp((BUI.Vars.ZoomZone or 60)/50,0,2)
 addon.account.subZoneZoom=Clamp((BUI.Vars.ZoomSubZone or 30)/100,0,2)
 addon.account.dungeonZoom=Clamp((BUI.Vars.ZoomDungeon or 60)/100,0,2)
 addon.account.mountedZoom=Clamp((BUI.Vars.ZoomMountRatio or 70)/100,0,2)
 addon.account.unitPinScaleLimit=Clamp((BUI.Vars.PinScale or 75)/100,0,1)
 ApplySizeNow()
 if addon.UpdateVisibility then addon:UpdateVisibility() end
 if addon.UpdateBorder then addon:UpdateBorder() end
 ApplyAppearance()
 return true
end

local function ScheduleApply(delay)
 BUI.CallLater(APPLY_NAME,delay or 50,function()
  if SyncVotan() then ApplyAppearance() end
 end)
end

function Mini.SetSize(value)
 BUI.Vars.MiniMapDimensions=math.floor(Clamp(value,200,500)+0.5)
 ApplySizeNow()
 ScheduleApply(75)
end
function Mini.ApplyTransparency()
 BUI.Vars.MiniMapAlpha=Clamp(BUI.Vars.MiniMapAlpha or 100,0,100)
 ApplyAppearance()
end
function Mini.Show() SyncVotan() end
function Mini.ReInit() SyncVotan() ScheduleApply(75) end
function Mini.PinColors() end
function Mini.ResizePins() end
function Mini.UpdateDimensions() Mini.SetSize(BUI.Vars.MiniMapDimensions) end
function Mini.UpdatePosition() ApplySizeNow() end
function Mini.ZoneChanged() ScheduleApply(100) end
function Mini.Update() end
function Mini.Restore() ScheduleApply(50) end
function Mini.Map_Toggle() Mini.ReInit() end

function Mini.Settings_Init()
 if settingsReady then return end
 settingsReady=true
 local options={
  {type="checkbox",name="Minimap",getFunc=function() return BUI.Vars.MiniMap end,
   setFunc=function(value) BUI.Vars.MiniMap=value Mini.ReInit() end},
  {type="slider",name="MiniMapDimensions",min=200,max=500,step=20,
   getFunc=function() return BUI.Vars.MiniMapDimensions end,
   setFunc=function(value) Mini.SetSize(value) end,
   disabled=function() return not BUI.Vars.MiniMap end},
  {type="slider",name="MinimapTransparency",min=0,max=100,step=5,
   getFunc=function() return BUI.Vars.MiniMapAlpha or 100 end,
   setFunc=function(value) BUI.Vars.MiniMapAlpha=value Mini.ApplyTransparency() end,
   disabled=function() return not BUI.Vars.MiniMap end},
  {type="checkbox",name="MinimapTitle",getFunc=function() return BUI.Vars.MiniMapTitle end,
   setFunc=function(value) BUI.Vars.MiniMapTitle=value Mini.ReInit() end,
   disabled=function() return not BUI.Vars.MiniMap end},
  {type="slider",name="PinScale",min=50,max=100,step=2,
   getFunc=function() return BUI.Vars.PinScale end,
   setFunc=function(value) BUI.Vars.PinScale=value Mini.ReInit() end,
   disabled=function() return not BUI.Vars.MiniMap end},
  {type="header",name="ZoomHeader"},
  {type="slider",name="ZoomZone",min=0,max=100,step=10,
   getFunc=function() return BUI.Vars.ZoomZone end,
   setFunc=function(value) BUI.Vars.ZoomZone=value Mini.Show() end,
   disabled=function() return not BUI.Vars.MiniMap end},
  {type="slider",name="ZoomSubZone",min=0,max=100,step=10,
   getFunc=function() return BUI.Vars.ZoomSubZone end,
   setFunc=function(value) BUI.Vars.ZoomSubZone=value Mini.Show() end,
   disabled=function() return not BUI.Vars.MiniMap end},
  {type="slider",name="ZoomDungeon",min=0,max=100,step=10,
   getFunc=function() return BUI.Vars.ZoomDungeon end,
   setFunc=function(value) BUI.Vars.ZoomDungeon=value Mini.Show() end,
   disabled=function() return not BUI.Vars.MiniMap end},
  {type="slider",name="ZoomMountRatio",min=50,max=100,step=10,
   getFunc=function() return BUI.Vars.ZoomMountRatio end,
   setFunc=function(value) BUI.Vars.ZoomMountRatio=value Mini.Show() end,
   disabled=function() return not BUI.Vars.MiniMap end},
  {type="button",name="MinimapReset",func=function()
   ZO_Dialogs_ShowDialog("BUI_RESET_CONFIRMATION",{text=BUI.Loc("MinimapResetDesc"),
    func=function() BUI.Menu.Reset("Minimap") end})
  end},
 }
 local panelName="9.  |t32:32:/esoui/art/icons/achievements_indexicon_exploration_up.dds|t"..BUI.Loc("MinimapHeader")
 if BUI.SettingsBridge and BUI.SettingsBridge.AddGroupedSection then
  BUI.SettingsBridge.AddGroupedSection("BUI_BanditUI",{id="Minimap",name=panelName,order=9,options=options})
 end
 BUI.Menu.RegisterPanel("BUI_MenuMinimap",{type="panel",name=panelName})
 BUI.Menu.RegisterOptions("BUI_MenuMinimap",options)
 local panel=_G.BUI_MenuMinimap
 if panel then
  panel:SetHandler("OnEffectivelyShown",function() BUI.inMenu=true Mini.Show() end)
  panel:SetHandler("OnEffectivelyHidden",function() BUI.inMenu=false end)
 end
end

local function HookVotan(addon)
 if addon.__satuveXboxBridgeHooked then return end
 addon.__satuveXboxBridgeHooked=true
 if addon.UpdateBorder then
  local original=addon.UpdateBorder
  function addon:UpdateBorder(...) original(self,...) ApplyAppearance() end
 end
 if addon.GoMiniMapMode then
  local original=addon.GoMiniMapMode
  function addon:GoMiniMapMode(...)
   local result=original(self,...)
   ScheduleApply(50)
   return result
  end
 end
end

local function RegisterSceneCallbacks()
 if Mini.SceneCallbacksRegistered then return end
 Mini.SceneCallbacksRegistered=true
 local function StateChanged(_,newState)
  if not ZO_WorldMap then return end
  if newState==SCENE_SHOWING or newState==SCENE_SHOWN then
   ZO_WorldMap:SetAlpha(1)
  elseif newState==SCENE_HIDING or newState==SCENE_HIDDEN then
   ScheduleApply(75)
  end
 end
 if WORLD_MAP_SCENE then WORLD_MAP_SCENE:RegisterCallback("StateChange",StateChanged) end
 if GAMEPAD_WORLD_MAP_SCENE then GAMEPAD_WORLD_MAP_SCENE:RegisterCallback("StateChange",StateChanged) end
end

function Mini.Initialize()
 Mini.Settings_Init()
 local addon=GetVotan()
 if not addon then BUI.CallLater(RETRY_NAME,500,Mini.Initialize) return end
 HookVotan(addon)
 RegisterSceneCallbacks()
 SyncVotan()
 if not initialized then
  initialized=true
  EVENT_MANAGER:RegisterForEvent("SXUI_VotanMinimap",EVENT_PLAYER_ACTIVATED,function() ScheduleApply(100) end)
 end
 BUI.init.MiniMap=true
end
