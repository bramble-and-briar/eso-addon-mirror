local N=TMEUI
local defaults={enabled=true,bars=true,resources=true,replaceAction=true,replaceResources=true,x=0,y=-100,scale=100,barX=0,barY=0,barScale=100,resourceX=0,resourceY=-160,resourceScale=100,moveSynergy=true,synergyX=0,synergyY=0,moveNativeBuffs=true,buffX=0,buffY=0,curvedResources=true,dimUnaffordable=true,resourceNumbers=true,resourcePulse=true,resourceSkinEthereal=false,arcDistance=330,arcY=0,awareness=true,low=20,alertX=0,alertY=415,alertScale=100}
local panel,registered,index=nil,false,1
local function refresh() if N.updateInterface then N.updateInterface() end end
local function register()
 if registered then return true end
 local lib=LibHarvensAddonSettings
 if not N.saved or not lib or type(lib.AddAddon)~='function' then return false end
 local c=N.saved;local opts={}
 local function add(t) opts[#opts+1]=t end
 local function heading(n) if lib.ST_SECTION then add({type=lib.ST_SECTION,label=n}) end end
 local function toggle(k,n) add({type=lib.ST_CHECKBOX,label=n,default=defaults[k],getFunction=function()return c[k] end,setFunction=function(v)c[k]=v==true;refresh() end}) end
 local function slider(k,n,lo,hi,step) add({type=lib.ST_SLIDER,label=n,min=lo,max=hi,step=step or 5,default=defaults[k],getFunction=function()return c[k]end,setFunction=function(v) if type(v)=='number' then c[k]=math.max(lo,math.min(hi,v));refresh() end end}) end
 local function button(n,f) if lib.ST_BUTTON then add({type=lib.ST_BUTTON,label=n,buttonText=n,clickHandler=f}) end end
 heading('General');toggle('enabled','Enable TME UI');button('Preview HUD for 20 seconds',function() N.previewUntil=(N.safe(GetFrameTimeSeconds) or 0)+20;refresh() end);button('End preview',function() N.previewUntil=nil;refresh() end);button('Restore default layout',function() for k,v in pairs(defaults) do c[k]=v end;N.previewUntil=nil;refresh() end)
 slider('x','Overall horizontal position',-1500,1500);slider('y','Overall vertical position',-1000,0);slider('scale','Overall scale (%)',50,200)
 heading('Action bars');toggle('bars','Dual action bars');toggle('replaceAction','Hide native action slots');toggle('dimUnaffordable','Dim unaffordable abilities');slider('barX','Action bars X',-1500,1500);slider('barY','Action bars Y',-1000,1000);slider('barScale','Action bar scale (%)',50,200)
 heading('Resource meters');toggle('resources','Custom resource meters');toggle('replaceResources','Hide native resource bars');toggle('curvedResources','Curved Magicka / Stamina');toggle('resourceSkinEthereal','Use ethereal resource skin');toggle('resourceNumbers','Show resource numbers');toggle('resourcePulse','Pulse low side resources');slider('resourceX','Resource meters X',-1500,1500);slider('resourceY','Resource meters Y',-1000,1000);slider('resourceScale','Resource meter scale (%)',50,200);slider('arcDistance','Side meter distance',150,900);slider('arcY','Side meter vertical position',-600,600)
 heading('Native prompts');toggle('moveNativeBuffs','Reposition native buff icons');slider('buffX','Native buffs X',-1500,1500);slider('buffY','Native buffs Y',-1000,1000);toggle('moveSynergy','Reposition synergy prompt');slider('synergyX','Synergy prompt X',-1500,1500);slider('synergyY','Synergy prompt Y',-1000,1000)
 heading('Combat alert HUD');toggle('awareness','Combat alerts');slider('low','Low resource threshold (%)',5,40,1);slider('alertX','Alert X',-1000,1000);slider('alertY','Alert Y',-700,700);slider('alertScale','Alert scale (%)',50,150)
 if N.addCameraSettings then N.addCameraSettings(lib,add,heading,button) end
 if not panel then panel=lib:AddAddon('TME UI',{allowDefaults=true,allowRefresh=true}) end
 if not panel or type(panel.AddSetting)~='function' then return false end
 while index<=#opts do panel:AddSetting(opts[index]);index=index+1 end
 registered=true;return true
end
local function tryRegister()
 local ok,res=pcall(register);if ok and res then return true end
 if not ok then N.settingsError=tostring(res) end;return false
end
local function registerWithRetry()
 if tryRegister() then return end
 local tries=0
 EVENT_MANAGER:UnregisterForUpdate('TMEUISettingsRetry')
 EVENT_MANAGER:RegisterForUpdate('TMEUISettingsRetry',1000,function() tries=tries+1;if tryRegister() or tries>=15 then EVENT_MANAGER:UnregisterForUpdate('TMEUISettingsRetry');if not registered and d then d('TME UI: settings unavailable. Check LibHarvensAddonSettings / LibVotans. '..(N.settingsError or '')) end end end)
end
EVENT_MANAGER:RegisterForEvent('TMEUIInit',EVENT_ADD_ON_LOADED,function(_,name)
 if name~=N.name then return end
 EVENT_MANAGER:UnregisterForEvent('TMEUIInit',EVENT_ADD_ON_LOADED)
 N.saved=ZO_SavedVars:NewAccountWide('TMEUISaved',1,nil,defaults)
 if not N.saved.alertPosition104 then
  if N.saved.alertX==0 and N.saved.alertY==-220 then N.saved.alertY=415 end
  N.saved.alertPosition104=true
 end
 N.initInterface();N.initAlerts()
 -- Register on load as well as first activation, with duplicate protection.
 registerWithRetry()
end)
EVENT_MANAGER:RegisterForEvent('TMEUISettingsActivation',EVENT_PLAYER_ACTIVATED,registerWithRetry)
