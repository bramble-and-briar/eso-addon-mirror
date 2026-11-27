local N=ESOHardcore
local registered=false
local panel=false
local status='Waiting for settings registration'
function N.settingsStatus() return status end
local function consoleRegister(c)
 local lib=LibHarvensAddonSettings
 if not lib or not lib.AddAddon then return false end
 local opts={}
 local function add(t) opts[#opts+1]=t end
 local function heading(n) if lib.ST_SECTION then add({type=lib.ST_SECTION,label=n}) end end
 local function toggle(k,n) add({type=lib.ST_CHECKBOX,label=n,getFunction=function()return c[k]~=false end,setFunction=function(v)c[k]=v end}) end
 local function slider(k,n,lo,hi) add({type=lib.ST_SLIDER,label=n,min=lo,max=hi,step=5,getFunction=function()return c[k]end,setFunction=function(v)c[k]=v end}) end
 local function button(n,f) if lib.ST_BUTTON then add({type=lib.ST_BUTTON,label=n,buttonText=n,clickHandler=f}) end end
 heading('Mode');add({type=lib.ST_CHECKBOX,label='Non-Hardcore immersive mode',getFunction=N.isImmersive,setFunction=N.setImmersive});toggle('hideNativeHUD','Hide native gameplay HUD');toggle('resourceAuras','Resource auras');toggle('materialOverlay','Normal crafting material overlay');toggle('fatigueEffects','Stamina fatigue effects');heading('Hardcore');button('Open Tamriel Unbound dashboard',function() N.openSkillWindow() end);button('Open HC Materials',function() N.toggleHardcorePage(8) end);button('Open Integrity Log',function() N.toggleHardcorePage(10) end)
 heading('Combat camera');toggle('combatCamera','Automatic first-person combat')
 heading('Immersion');toggle('overlays','Immersive overlays');slider('intensity','Overlay intensity',0,100)
 for _,k in ipairs({'health','poison','burn','disease','chill','shock','bleed','control','hunger','thirst'}) do toggle(k,k:sub(1,1):upper()..k:sub(2)..' effect') end
 heading('Nutrition HUD');toggle('meters','Show nutrition HUD');slider('x','Horizontal position',-1000,1000);slider('y','Vertical position',-900,0);slider('scale','Scale',50,150)
 local a=lib:AddAddon('Tamriel Unbound',{allowDefaults=false,allowRefresh=true})
 if not a then error('Console settings panel unavailable') end
 for _,o in ipairs(opts) do a:AddSetting(o) end
 return true
end
local function register()
 if registered then return true end
 local lam=LibAddonMenu2
 if not N.hardcore or not N.hardcore.saved then return false end
 local c=N.hardcore.saved
 if LibHarvensAddonSettings and not panel then
  local ok,result=pcall(consoleRegister,c)
  if ok and result then registered=true;status='Console settings registered';return true end
  if not ok then status='Console registration error: '..tostring(result) end
 end
 if not lam then if not LibHarvensAddonSettings then status='No settings library; use dashboard Settings page' end;return false end
 local ok,err=pcall(function()
  if not panel then lam:RegisterAddonPanel('ESOHardcoreSettings',{type='panel',name='Tamriel Unbound',displayName='Tamriel Unbound',author='Trash Man Enterprises',version='1.0.5',registerForRefresh=true});panel=true end
  local o={}
  local function add(v) o[#o+1]=v end
  local function header(name) add({type='header',name=name}) end
  local function toggle(key,name) add({type='checkbox',name=name,getFunc=function() return c[key]~=false end,setFunc=function(v)c[key]=v end}) end
  local function slider(key,name,lo,hi) add({type='slider',name=name,min=lo,max=hi,step=5,getFunc=function()return c[key]end,setFunc=function(v)c[key]=v end}) end
  header('Mode');add({type='checkbox',name='Non-Hardcore immersive mode',getFunc=N.isImmersive,setFunc=N.setImmersive});toggle('hideNativeHUD','Hide native gameplay HUD');toggle('resourceAuras','Resource auras');toggle('materialOverlay','Normal crafting material overlay');toggle('fatigueEffects','Stamina fatigue effects');header('Hardcore');add({type='button',name='Open Tamriel Unbound dashboard',func=function() N.openSkillWindow() end});add({type='button',name='Open HC Materials / Inventory',func=function() N.toggleHardcorePage(8) end});add({type='button',name='Open Integrity Log',func=function() N.toggleHardcorePage(10) end})
  header('Combat camera');toggle('combatCamera','Automatic first-person combat');add({type='description',text='Switches to first person in combat; restores third person two seconds after combat. Camera status is available on the Ruleset page.'});add({type='button',name='Camera diagnostics',func=function() if d then d('Hardcore: '..N.combatCamera.info()) end end})
  header('Immersion');toggle('overlays','Immersive overlays');slider('intensity','Overlay intensity',0,100)
  for _,k in ipairs({'health','poison','burn','disease','chill','shock','bleed','control','hunger','thirst'}) do toggle(k,k:sub(1,1):upper()..k:sub(2)..' effect') end
  header('Nutrition HUD');toggle('meters','Show nutrition HUD');slider('x','Horizontal position',-1000,1000);slider('y','Vertical position',-900,0);slider('scale','Scale',50,150)
  lam:RegisterOptionControls('ESOHardcoreSettings',o)
 end)
 registered=ok;status=ok and "LibAddonMenu settings registered" or ("Settings error: "..tostring(err));return ok
end
EVENT_MANAGER:RegisterForEvent('ESOHCSettings',EVENT_PLAYER_ACTIVATED,function()
 if register() then return end
 local tries=0
 EVENT_MANAGER:RegisterForUpdate('ESOHCSettingsRetry',2000,function() tries=tries+1;if register() or tries>=15 then EVENT_MANAGER:UnregisterForUpdate('ESOHCSettingsRetry') end end)
end)
