-- Native camera slider metadata only. No direct writes or protected function calls.
local name='TMEHorizon'
local H={}
local patches,inserted={},{}
local function say(msg) if type(d)=='function' then d('TME Horizon: '..msg) end end
local function num(v) v=tonumber(v);if v and v==v and math.abs(v)<1e6 then return v end end
local function read(id)
 if id==nil or SETTING_TYPE_CAMERA==nil or type(GetSetting)~='function' then return nil end
 local ok,v=pcall(GetSetting,SETTING_TYPE_CAMERA,id);if ok then return num(v) end
end
local function specs()
 return {{id=CAMERA_SETTING_THIRD_PERSON_FIELD_OF_VIEW,label='Third-person FOV',base=65,limit=80,fov=true},{id=CAMERA_SETTING_DISTANCE,label='Camera distance',base=10,limit=100},{id=CAMERA_SETTING_DISTANCE_UNSHEATHED,label='Unsheathed distance',base=10,limit=100}}
end
local function tables()
 local data=ZO_SharedOptions_SettingsData
 local menu=GAMEPAD_SETTINGS_DATA
 if type(data)~='table' or type(menu)~='table' or SETTING_PANEL_CAMERA==nil or SETTING_TYPE_CAMERA==nil then return end
 local panel=data[SETTING_PANEL_CAMERA]
 local list=menu[SETTING_PANEL_CAMERA]
 if type(panel)~='table' or type(list)~='table' or type(panel[SETTING_TYPE_CAMERA])~='table' then return end
 return panel[SETTING_TYPE_CAMERA],list
end
local function patch(t,k,v)
 if t[k]==v then return end
 patches[t]=patches[t] or {}
 if not patches[t][k] then patches[t][k]={old=t[k],new=v} else patches[t][k].new=v end
 t[k]=v
end
local function restore()
 for t,fields in pairs(patches) do for k,p in pairs(fields) do if t[k]==p.new then t[k]=p.old end end end
 patches={}
 for _,x in ipairs(inserted) do
  for j=#x.list,1,-1 do if x.list[j]==x.row then table.remove(x.list,j) end end
  if x.data[x.id]==x.meta and x.created then x.data[x.id]=nil end
 end
 inserted={}
end
local function findRow(list,id)
 for _,row in ipairs(list) do if type(row)=='table' and row.settingId==id and row.system==SETTING_TYPE_CAMERA then return row end end
end
local function extend()
 local data,list=tables();if not data then return false,'Native Camera tables unavailable.' end
 local out={}
 for _,spec in ipairs(specs()) do
  if spec.id~=nil then
   local meta=data[spec.id];local row=findRow(list,spec.id)
   local enabled=spec.fov and H.saved.native or not spec.fov and H.saved.distanceRows
   if enabled then
    -- Only add distance rows on explicit opt-in, and only for readable native camera settings.
    if not spec.fov and not row and read(spec.id)~=nil and OPTIONS_SLIDER~=nil then
     local created=false
     if meta==nil then
      meta={controlType=OPTIONS_SLIDER,system=SETTING_TYPE_CAMERA,settingId=spec.id,panel=SETTING_PANEL_CAMERA,text='Horizon: '..spec.label..' (experimental)',tooltipText=SI_INTERFACE_OPTIONS_CAMERA_THIRD_PERSON_FOV_TOOLTIP,minValue=1,maxValue=10,valueFormat='%.2f',showValue=true,showValueMin=1,showValueMax=10,excludeFromResetToDefault=true}
      data[spec.id]=meta;created=true
     end
     if type(meta)=='table' and meta.controlType==OPTIONS_SLIDER and num(meta.maxValue)==spec.base then
      row={panel=SETTING_PANEL_CAMERA,system=SETTING_TYPE_CAMERA,settingId=spec.id};list[#list+1]=row
      inserted[#inserted+1]={list=list,row=row,data=data,id=spec.id,meta=meta,created=created}
     elseif created then data[spec.id]=nil end
    end
    if row and type(meta)=='table' and meta.controlType==OPTIONS_SLIDER then
     local max=num(meta.maxValue)
     if max==spec.base then
      patch(meta,'maxValue',spec.limit)
      if spec.fov and num(meta.showValueMax)==130 then patch(meta,'showValueMax',160)
      elseif not spec.fov and num(meta.showValueMax)==10 then patch(meta,'showValueMax',spec.limit)
      elseif not spec.fov and num(meta.showValueMax)==100 then patch(meta,'showValueMax',spec.limit*10) end
     end
     out[#out+1]=spec.label..' slider max '..tostring(meta.maxValue)
    else out[#out+1]=spec.label..' not exposed' end
   end
  end
 end
 return true,#out>0 and table.concat(out,' | ') or 'All extensions off.'
end
local function rescan(report)
 local ok,ready,msg=pcall(extend)
 if not ok then restore();say('Native metadata extension failed; reverted. '..tostring(ready));return end
 if report then say(msg or 'Unavailable.');say('Back out and reopen native Options > Camera. Adjust there only.') end
end
local function toggle(k,v)
 restore();H.saved[k]=v==true;rescan(true)
end
local function status()
 local data,list=tables();local out={}
 for _,s in ipairs(specs()) do
  local v=read(s.id);local row=list and s.id and findRow(list,s.id);local m=data and s.id and data[s.id]
  local label=s.label..': '..(v and string.format('%.2f',v) or 'unavailable')
  if v and s.fov then label=label..' raw ('..string.format('%.1f',v*2)..' displayed)' end
  if row and type(m)=='table' then label=label..' | slider max '..tostring(m.maxValue) else label=label..' | no native row' end
  out[#out+1]=label
 end
 for _,line in ipairs(out) do say(line) end
 say('Readback is not proof of actual rendered camera distance.')
end
local function capture()
 local baseline={}
 for _,s in ipairs(specs()) do local v=read(s.id);if v~=nil then baseline[s.label]=v end end
 if next(baseline) then H.saved.baseline=baseline;say('Baseline captured (read-only). Restore manually in native Camera menu.') else say('Camera values unavailable.') end
end
local function reportBaseline()
 if type(H.saved.baseline)~='table' then say('No baseline captured.');return end
 for _,s in ipairs(specs()) do local v=H.saved.baseline[s.label];if num(v) then say('Baseline '..s.label..': '..v..(s.fov and (' raw / '..(v*2)..' displayed') or ' raw')) end end
end
local registered,panel,index=false,nil,1
local function register()
 if registered then return end
 local lib=LibHarvensAddonSettings;if not H.saved or not lib or type(lib.AddAddon)~='function' then return end
 local c=H.saved;local opts={}
 local function add(t) opts[#opts+1]=t end
 local function button(n,f) if lib.ST_BUTTON then add({type=lib.ST_BUTTON,label=n,buttonText=n,clickHandler=f}) end end
 local function checkbox(k,n) add({type=lib.ST_CHECKBOX,label=n,default=false,getFunction=function()return c[k]==true end,setFunction=function(v)toggle(k,v) end}) end
 if lib.ST_SECTION then add({type=lib.ST_SECTION,label='Native Camera menu experiments'}) end
 checkbox('native','Extend native third-person FOV to 160')
 checkbox('distanceRows','Expose extended camera distance sliders (up to 100)')
 button('Scan native Camera sliders',function()rescan(true)end)
 button('Report current camera values',status)
 button('Capture current camera as restore point',capture)
 button('Report captured restore point',reportBaseline)
 if TMEHorizonLab then TMEHorizonLab.addSettings(lib,add,button) end
 if not panel then panel=lib:AddAddon('TME Horizon',{allowDefaults=false,allowRefresh=true}) end
 if not panel or type(panel.AddSetting)~='function' then return end
 while index<=#opts do panel:AddSetting(opts[index]);index=index+1 end
 registered=true
end
local function activate()
 if not H.saved then return end
 rescan(false)
 local ok,err=pcall(register);if not ok then say('Settings registration failed: '..tostring(err)) end
end
EVENT_MANAGER:RegisterForEvent(name,EVENT_ADD_ON_LOADED,function(_,addon)
 if addon~=name then return end
 EVENT_MANAGER:UnregisterForEvent(name,EVENT_ADD_ON_LOADED)
 H.saved=ZO_SavedVars:NewAccountWide('TMEHorizonSaved',1,nil,{native=false,distanceRows=false})
 if H.saved.nativeOnlyRevision~=2 then H.saved.native=false;H.saved.distanceRows=false;H.saved.nativeOnlyRevision=2 end
 if TMEHorizonLab then TMEHorizonLab.init() end
 activate()
end)
EVENT_MANAGER:RegisterForEvent(name..'Activate',EVENT_PLAYER_ACTIVATED,activate)
