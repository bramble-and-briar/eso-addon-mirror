-- Manual camera settings only: no overrides on activation, combat or scene changes.
local N=TMEUI
local controls={
 distance={id=CAMERA_SETTING_DISTANCE,min=0,max=100,scale=10,label='Third-person camera distance (%)'},
 fov={id=CAMERA_SETTING_THIRD_PERSON_FIELD_OF_VIEW,min=35,max=65,scale=1,label='Third-person field of view'},
}
local revision={}
local function read(c)
 if SETTING_TYPE_CAMERA==nil or c.id==nil or type(GetSetting)~='function' then return nil end
 return tonumber(N.safe(GetSetting,SETTING_TYPE_CAMERA,c.id))
end
local function available(c)
 return type(SetSetting)=='function' and read(c)~=nil
end
local function get(c)
 local v=read(c)
 if v==nil then return c.min end
 return math.max(c.min,math.min(c.max,math.floor(v*c.scale+.5)))
end
local function warn(message)
 if type(d)=='function' then d('TME UI: '..message) end
end
local function set(c,v)
 if type(v)~='number' or v~=v or not available(c) then return false end
 v=math.max(c.min,math.min(c.max,v))/c.scale
 local ok=pcall(SetSetting,SETTING_TYPE_CAMERA,c.id,string.format('%.2f',v))
 if not ok then warn(c.label..' is unavailable in this client/state.');return false end
 revision[c]=(revision[c] or 0)+1
 local token=revision[c]
 local function verify()
  if revision[c]~=token then return end
  local actual=read(c)
  if actual==nil or math.abs(actual-v)>.06 then
   warn(c.label..' was not fully applied by ESO. Requested '..string.format('%.2f',v)..', reported '..(actual and string.format('%.2f',actual) or 'unavailable')..'.')
  end
 end
 if type(zo_callLater)=='function' then zo_callLater(verify,300) else verify() end
 return true
end
function N.addCameraSettings(lib,add,heading,button)
 local distance,fov=controls.distance,controls.fov
 if not available(distance) and not available(fov) then return end
 heading('Camera')
 for _,c in ipairs({distance,fov}) do
  if available(c) then
   -- Explicit local avoids any loop-variable capture ambiguity on Lua 5.1.
   local control=c
   add({type=lib.ST_SLIDER,label=control.label,min=control.min,max=control.max,step=1,
    default=get(control),getFunction=function() return get(control) end,
    setFunction=function(v) set(control,v) end})
  end
 end
 button('Maximum third-person view',function()
  if available(distance) then set(distance,distance.max) end
  if available(fov) then set(fov,fov.max) end
 end)
end
