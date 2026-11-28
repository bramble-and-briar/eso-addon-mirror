-- TME Horizon camera laboratory. Only explicit tests; no private function calls.
TMEHorizonLab={}
local L=TMEHorizonLab
local blocked={SetSetting=true,GameCameraGamepadZoomDown=true,GameCameraGamepadZoomUp=true}
local function access(n)
 if blocked[n] then return 'private / not called' end
 if type(_G[n])~='function' then return 'missing' end
 for _,key in ipairs({'IsPrivateFunction','IsProtectedFunction'}) do
  local f=_G[key]
  if type(f)~='function' then return 'permission unknown' end
  local ok,v=pcall(f,n)
  if not ok or type(v)~='boolean' then return 'permission unknown' end
  if v then return key=='IsPrivateFunction' and 'private' or 'protected' end
 end
 return 'available'
end
local function call(n,...)
 local status=access(n);if status~='available' then return false,status end
 return pcall(_G[n],...)
end
local function say(s) if type(d)=='function' then d('Horizon: '..s) end end
local function valid(x) return type(x)=='number' and x==x and math.abs(x)<1e10 end
local function vec(x,y,z) if valid(x) and valid(y) and valid(z) then return {x,y,z} end end
local function dist(a,b) if a and b then return math.sqrt((a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2) end end
local function fmt(x) return valid(x) and string.format('%.2f',x) or 'N/A' end
local function gameplay()
 local scene=SCENE_MANAGER and SCENE_MANAGER:GetCurrentScene();local n=scene and scene:GetName()
 if n~='hud' and n~='hudui' and n~='hudgamepad' and n~='huduigamepad' then return false end
 local ok,a=call('IsGameCameraActive');if ok and not a then return false end
 local ok2,b=call('IsUnitInCombat','player');if not ok2 or b then return false end
 local ok3,c=call('IsUnitDead','player');if ok3 and c then return false end
 return true
end
local probe,report,heading,body
local function ensureUI()
 if report then return end
 report=WINDOW_MANAGER:CreateTopLevelWindow('TMEHorizonLabReport');report:SetDimensions(690,450);report:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,40,115);report:SetDrawTier(DT_HIGH);report:SetMouseEnabled(false);report:SetHidden(true)
 local bg=WINDOW_MANAGER:CreateControl(nil,report,CT_BACKDROP);bg:SetAnchorFill(report);bg:SetCenterColor(.025,.035,.05,.94);bg:SetEdgeColor(.35,.60,.87,1);bg:SetEdgeTexture('',1,1,1)
 heading=WINDOW_MANAGER:CreateControl(nil,report,CT_LABEL);heading:SetAnchor(TOPLEFT,report,TOPLEFT,18,12);heading:SetFont('$(BOLD_FONT)|25|soft-shadow-thick');heading:SetText('TME HORIZON | CAMERA LAB')
 body=WINDOW_MANAGER:CreateControl(nil,report,CT_LABEL);body:SetAnchor(TOPLEFT,report,TOPLEFT,18,51);body:SetDimensions(654,385);body:SetFont('$(MEDIUM_FONT)|19|soft-shadow-thick');body:SetVerticalAlignment(TEXT_ALIGN_TOP)
end
local function readSetting(id)
 if id==nil or SETTING_TYPE_CAMERA==nil then return nil end
 local ok,v=call('GetSetting',SETTING_TYPE_CAMERA,id);if ok then return tonumber(v) end
end
local function sample()
 local a={distance=readSetting(CAMERA_SETTING_DISTANCE),combatDistance=readSetting(CAMERA_SETTING_DISTANCE_UNSHEATHED),fov=readSetting(CAMERA_SETTING_THIRD_PERSON_FIELD_OF_VIEW),offset=readSetting(CAMERA_SETTING_THIRD_PERSON_HORIZONTAL_POSITION_MULTIPLIER),fovAllowed=readSetting(CAMERA_SETTING_FOV_CHANGES_ALLOWED)}
 local ok,w,h=call('GetWorldDimensionsOfViewFrustumAtDepth',1)
 if ok and valid(w) and valid(h) and w>0 and h>0 then a.frustum=2*math.atan(w/2)*180/math.pi;a.vertical=2*math.atan(h/2)*180/math.pi end
 local okf,f=call('GetInterfaceVerticalFieldOfView');if okf and valid(f) then a.interfaceFov=f end
 local okp,zone,x,y,z=call('GetUnitRawWorldPosition','player');if not okp or not vec(x,y,z) then a.reason='Raw player position unavailable';return a end
 a.zone=zone;a.player={x,y,z}
 local okc,px,py,pz=call('WorldPositionToGuiRender3DPosition',x,y,z)
 if not okc or not vec(px,py,pz) then a.reason='World conversion unavailable';return a end
 if access('Set3DRenderSpaceToCurrentCamera')~='available' then a.reason='Camera render-space API '..access('Set3DRenderSpaceToCurrentCamera');return a end
 local success,err=pcall(function()
  if not probe then
   probe=WINDOW_MANAGER:CreateControl('TMEHorizonLabProbe',GuiRoot,CT_TEXTURE);probe:SetDimensions(1,1);probe:SetHidden(true);probe:Create3DRenderSpace()
  end
  local yes,msg=call('Set3DRenderSpaceToCurrentCamera',probe:GetName());if not yes then error(msg) end
  local cx,cy,cz=probe:Get3DRenderSpaceOrigin();local camera=vec(cx,cy,cz)
  if not camera then error('No camera coordinates') end
  a.camera=camera;a.range=dist(camera,{px,py,pz})
  if a.range>200 then a.range=nil;error('Coordinate systems inconsistent (>200 render units)') end
 end)
 if not success then a.reason=tostring(err):sub(1,100) end
 return a
end
local function snapshotText(a)
 if not a then return 'not captured' end
 return 'range '..fmt(a.range)..' | horiz FOV '..fmt(a.frustum)..' deg | setting '..fmt(a.distance)..' / '..fmt(a.fov)
end
local function write(lines)
 ensureUI();L.lines=lines;body:SetText(table.concat(lines,'\n'));report:SetHidden(not gameplay() or not L.show)
end
local function compare(a,b)
 if not a or not b then return 'Comparison unavailable' end
 if a.zone~=b.zone or not a.player or not b.player or dist(a.player,b.player)>25 then return 'Player moved or changed zone: repeat while stationary.' end
 if not a.range or not b.range then return 'Distance measurement unavailable; inspect actual view.' end
 local delta=b.range-a.range
 return 'Range change: '..string.format('%+.2f',delta)..' render units | FOV change: '..(a.frustum and b.frustum and string.format('%+.2f deg',b.frustum-a.frustum) or 'N/A')
end
local function saveResult(name,a,b,note)
 local lines={name,'Before: '..snapshotText(a),'After:  '..snapshotText(b),compare(a,b),note or '',b and b.reason or '', 'Settings = requested/readback, not actual zoom.','Screenshot this report; reset zoom manually if needed.'}
 L.last=lines;write(lines);say(name..' | '..compare(a,b))
end
local function cleanup()
 local f=L.undo;L.undo=nil;if f then pcall(f) end
end
local function cancel()
 cleanup();L.pending=nil;L.active=nil;L.show=false;if report then report:SetHidden(true) end
end
local function queue(kind)
 cleanup();L.active=nil;L.show=true;L.pending={kind=kind,wait=0};say('Queued '..kind..'. Close menus, stand still in open terrain, out of combat.')
end
local factors={['Framing distance factor x2']=2,['Framing distance factor 0.5']=0.5,['Framing distance factor 0.25']=0.25}
local function run(kind)
 local a=sample()
 if kind=='Capture native max' then L.baseline=a;saveResult(kind,a,a,'Baseline saved for this session.');return end
 if kind=='Compare with native max' then saveResult(kind,L.baseline,a,'Manual adjustment comparison.');return end
 if kind=='API availability' then
  local names={'CameraZoomOut','CameraZoomIn','GameCameraGamepadZoomDown','SetFrameLocalPlayerLookAtDistanceFactor','SetFrameLocalPlayerInGameCamera','RequestReframeLocalPlayerInGameCamera','SetCameraOptionsPreviewModeEnabled','SetInterfaceVerticalFieldOfView','Set3DRenderSpaceToCurrentCamera','GetWorldDimensionsOfViewFrustumAtDepth'}
  local lines={'Runtime permission checks (no mutation):'};for _,n in ipairs(names) do lines[#lines+1]=n..': '..access(n) end;lines[#lines+1]='Measured: '..snapshotText(a);L.last=lines;write(lines);return
 end
 local ok,msg,note
 if kind=='Zoom out x1' or kind=='Zoom out x12' or kind=='Zoom in x1 (calibration)' then
  local n=kind=='Zoom in x1 (calibration)' and 'CameraZoomIn' or 'CameraZoomOut';local count=kind=='Zoom out x12' and 12 or 1
  if access(n)~='available' then saveResult(kind,a,a,n..': '..access(n));return end
  L.active={name=kind,before=a,remaining=count,action=n,ticks=0,note='Native zoom calls; restore manually with controller.'};return
 elseif factors[kind] then
  local ns={'SetFrameLocalPlayerLookAtDistanceFactor','SetFrameLocalPlayerInGameCamera','RequestReframeLocalPlayerInGameCamera'}
  for _,n in ipairs(ns) do if access(n)~='available' then saveResult(kind,a,a,n..': '..access(n));return end end
  L.undo=function() call(ns[1],nil);call(ns[2],false) end
  ok,msg=call(ns[1],factors[kind]);if ok then ok,msg=call(ns[2],true) end;if ok then ok,msg=call(ns[3]) end
  note='Temporary UI framing, not proven gameplay zoom. Auto-restored.'
 elseif kind=='Third-person preview' then
  local n='SetCameraOptionsPreviewModeEnabled';if access(n)~='available' or CAMERA_OPTIONS_PREVIEW_FORCE_THIRD_PERSON==nil or CAMERA_OPTIONS_PREVIEW_NONE==nil then saveResult(kind,a,a,n..': '..access(n));return end
  L.undo=function() call(n,false,CAMERA_OPTIONS_PREVIEW_NONE) end;ok,msg=call(n,true,CAMERA_OPTIONS_PREVIEW_FORCE_THIRD_PERSON);note='Native preview mode, auto-restored.'
 elseif kind=='Interface FOV +15%' then
  local n='SetInterfaceVerticalFieldOfView';if access(n)~='available' or not a.interfaceFov or a.interfaceFov<=0 or a.interfaceFov>=2.8 then saveResult(kind,a,a,'Interface FOV unavailable or invalid.');return end
  L.undo=function() call(n,a.interfaceFov) end;ok,msg=call(n,math.min(2.8,a.interfaceFov*1.15));note='Temporary interface FOV only; auto-restored.'
 else return end
 if not ok then cleanup();saveResult(kind,a,a,'Rejected: '..tostring(msg):sub(1,100));return end
 L.active={name=kind,before=a,ticks=0,note=note,temporary=true,framing=factors[kind]~=nil}
end
local function tick()
 if not gameplay() then
  if report then report:SetHidden(true) end
  if L.active then cleanup();L.active=nil;say('Test interrupted; temporary settings restored.') end
  if L.pending then L.pending.wait=0 end
  return
 end
 if report then report:SetHidden(not L.show) end
 if L.pending then L.pending.wait=L.pending.wait+1;if L.pending.wait>=6 then local k=L.pending.kind;L.pending=nil;run(k) end;return end
 local x=L.active;if not x then return end
 x.ticks=x.ticks+1
 if x.remaining and x.remaining>0 then
  local ok,msg=call(x.action);if not ok then L.active=nil;saveResult(x.name,x.before,sample(),'Rejected: '..tostring(msg):sub(1,100));return end
  x.remaining=x.remaining-1;x.ticks=0;return
 end
 if x.restoring then
  if x.ticks>=12 then
   local restored=sample();L.active=nil
   saveResult(x.name,x.before,x.during,'Restored: '..snapshotText(restored)..' | '..compare(x.before,restored)..'\nTemporary framing only; gameplay zoom unproven.')
  end
  return
 end
 if x.ticks>=(x.framing and 16 or 8) then
  local b=sample();cleanup()
  if x.framing then x.during=b;x.restoring=true;x.ticks=0;return end
  L.active=nil;saveResult(x.name,x.before,b,x.note)
 end
end
function L.addSettings(lib,add,button)
 if lib.ST_SECTION then add({type=lib.ST_SECTION,label='Camera laboratory (return to gameplay to run)'}) end
 for _,k in ipairs({'API availability','Capture native max','Compare with native max','Zoom in x1 (calibration)','Zoom out x1','Zoom out x12','Framing distance factor x2','Framing distance factor 0.5','Framing distance factor 0.25','Third-person preview','Interface FOV +15%'}) do local name=k;button(name,function() queue(name) end) end
 button('Show last laboratory report',function() L.show=true;if L.last then write(L.last) else say('No test results yet.') end end)
 button('Cancel test / hide report',cancel)
end
function L.init()
 EVENT_MANAGER:RegisterForUpdate('TMEHorizonLabTick',250,function() local ok,err=pcall(tick);if not ok then cancel();say('Lab stopped: '..tostring(err):sub(1,120)) end end)
 if EVENT_PLAYER_DEACTIVATED then EVENT_MANAGER:RegisterForEvent('TMEHorizonLabZone',EVENT_PLAYER_DEACTIVATED,cancel) end
end
