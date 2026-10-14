local l="MurfKnickknacks"
local k="Murf's\194\160Knickknacks"
local g="MurfKnickknacks_SavedVars"
local q=2
local e
local t={
nearDistanceShow=true,
nearDistanceColor={1,1,1},
farDistanceShow=true,
farDistanceColor={1,1,1},
bossBar="show",
guildStoreTimeSort=false,
mapZoomFactor=1.,
mapZoomSpeed=1.,
platformShow=true,
canLearnShow=true,
canLearnColor={1,1,1},
lockedSetShow=true,
lockedSetColor={1,1,1},
multiIconSpeed=1,
newIconShow=true,
transmuteShow=true,
guildMailHide={[1]=false,[2]=false,[3]=false,[4]=false,[5]=false},
hideLeads="off",
hideCodexEntries=false,
antiquarianEye="prompt",
}
local function s(e)
return e[1]==1 and e[2]==1 and e[3]==1
end
local function n()
if not e.nearDistanceShow then
EsoStrings[SI_COMPASS_PIN_DISTANCE_FORMATTER]=""
elseif not s(e.nearDistanceColor)then
local a=e.nearDistanceColor[1]*255
local t=e.nearDistanceColor[2]*255
local e=e.nearDistanceColor[3]*255
EsoStrings[SI_COMPASS_PIN_DISTANCE_FORMATTER]=string.format("|c%02X%02X%02X<<1>>m|r",a,t,e)
else
EsoStrings[SI_COMPASS_PIN_DISTANCE_FORMATTER]="<<1>>m"
end
if not e.farDistanceShow then
EsoStrings[SI_COMPASS_PIN_LONG_DISTANCE_FORMATTER]=""
elseif not s(e.farDistanceColor)then
local a=e.farDistanceColor[1]*255
local t=e.farDistanceColor[2]*255
local e=e.farDistanceColor[3]*255
EsoStrings[SI_COMPASS_PIN_LONG_DISTANCE_FORMATTER]=string.format("|c%02X%02X%02X<<1>>km|r",a,t,e)
else
EsoStrings[SI_COMPASS_PIN_LONG_DISTANCE_FORMATTER]="<<1>>km"
end
end
local w
local p
local function y(t)
if t=="show"then
if not w then return end
COMPASS_FRAME.RefreshVisible=w
COMPASS_FRAME.SetCompassHidden=p
COMPASS_FRAME:RefreshVisible()
return
elseif t=="hide"then
COMPASS_FRAME.SetCompassHidden=function(e,e)end
COMPASS_FRAME.RefreshVisible=function(e)
if not(e.compassReady and e.bossBarReady)then return end
if e.crossFadeTimeline then e.crossFadeTimeline:Stop()end
COMPASS_FRAME_FRAGMENT:SetHiddenForReason("contentsHidden",false)
ZO_BossBar:SetAlpha(1)
ZO_Compass:SetAlpha(1)
ZO_BossBar:SetHidden(true)
ZO_Compass:SetHidden(false)
end
elseif t=="combined"then
COMPASS_FRAME.SetCompassHidden=function(e,e)end
COMPASS_FRAME.RefreshVisible=function(e)
if not(e.compassReady and e.bossBarReady)then return end
if e.crossFadeTimeline then e.crossFadeTimeline:Stop()end
local e=
e.bossBarHiddenReasons:IsHidden()
or not e.bossBarActive
COMPASS_FRAME_FRAGMENT:SetHiddenForReason("contentsHidden",false)
ZO_BossBar:SetAlpha(1)
ZO_Compass:SetAlpha(1)
ZO_BossBar:SetHidden(e)
ZO_Compass:SetHidden(false)
end
end
COMPASS_FRAME:RefreshVisible()
end
local function b()
if TRADING_HOUSE_SEARCH==nil or GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS==nil then return end
TRADING_HOUSE_SEARCH:ChangeSort(TRADING_HOUSE_SORT_TYPE_TIME,ZO_SORT_ORDER_DOWN)
local e=GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS.sortHeaderGroup
if e~=nil then
e.sortDirection=false
if e.sortHeaders[1]and e.sortHeaders[2]then
e:DeselectHeader(e.sortHeaders[2])
e:SelectHeader(e.sortHeaders[1])
end
end
end
local o
local i
local function r()
local a=ZO_WorldMap_GetPanAndZoom()
if not o then
o=a.SetMapZoomMinMax
i=a.AddZoomDeltaGamepad
end
a.SetMapZoomMinMax=function(o,i,t)
if t>1.1 and t<4.9 then
if GetMapType()==MAPTYPE_ZONE then
t=t*e.mapZoomFactor
else
t=t*(1+(e.mapZoomFactor-1)/4)
end
end
o.mapMin=i
o.mapMax=t
o:RefreshZoom()
end
a.AddZoomDeltaGamepad=function(t,a,n)
local s=2
local o=2*e.mapZoomSpeed
local i=t.targetNormalizedZoom or t.currentNormalizedZoom
local e=t.mapMax-t.mapMin
local o=a*zo_max(o,e/s)
local e=e>0 and(o/e)or 0
local e=zo_clamp(i+n*e,0,1)
t:SetLockedNormalizedZoom(e,ZO_WorldMapScroll:GetCenter())
if a>0 and t.canZoomInFurther then
PlaySound(SOUNDS.MAP_ZOOM_IN)
elseif a<0 and t.canZoomOutFurther then
PlaySound(SOUNDS.MAP_ZOOM_OUT)
end
end
end
local function h()
local e=ZO_WorldMap_GetPanAndZoom()
r()
if e.mapMin and e.mapMax then
e:SetMapZoomMinMax(e.mapMin,e.mapMax)
end
end
local a
local function u()
if not a then
a=ZO_GetPlatformDisplayNameIcon
end
if e.platformShow then
ZO_GetPlatformDisplayNameIcon=a
else
ZO_GetPlatformDisplayNameIcon=function()return nil end
end
end
local o
local a
local r
local m
local j="EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_can_learn.dds"
local v="EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_locked_set_piece.dds"
local f="EsoUI/Art/Inventory/Gamepad/gp_inventory_trait_retrait_icon.dds"
local x="EsoUI/Art/Inventory/Gamepad/gp_inventory_trait_reconstruct_icon.dds"
local function c()
local o=ZO_MultiIconAnimation_OnStop
function ZO_MultiIconAnimation_OnStop(t)
local a=575-e.multiIconSpeed*75
local e=1750-e.multiIconSpeed*250
t:GetAnimation(1):SetDuration(a)
t:GetAnimation(2):SetDuration(a)
t:SetAnimationOffset(t:GetAnimation(2),e)
ZO_MultiIconAnimation_OnStop=o
ZO_MultiIconAnimation_OnStop(t)
end
end
local function i()
if not o then
o=ZO_MultiIcon_Initialize
end
ZO_MultiIcon_Initialize=function(t)
o(t)
if not m then
m=t.AddIcon
end
t.AddIcon=function(o,t,a,i)
if t==j then
if not e.canLearnShow then return end
a=ZO_ColorDef:New(e.canLearnColor[1],e.canLearnColor[2],e.canLearnColor[3],1)
elseif t==v then
if not e.lockedSetShow then return end
a=ZO_ColorDef:New(e.lockedSetColor[1],e.lockedSetColor[2],e.lockedSetColor[3],1)
elseif t==f then
if not e.transmuteShow then return end
elseif t==x then
if not e.transmuteShow then return end
end
m(o,t,a,i)
end
end
end
local function f()
if not a then
a=ZO_GamepadEntryData.IsNew
end
if not r then
r=ZO_GamepadEntryData.CanLevel
end
if e.newIconShow then
ZO_GamepadEntryData.IsNew=a
ZO_GamepadEntryData.CanLevel=r
else
ZO_GamepadEntryData.IsNew=function(e)
if e.text==GetString(SI_MAIN_MENU_SOCIAL)or e.text==GetString(SI_SOCIAL_MENU_MAIL)then
return a(e)
else
return false
end
end
ZO_GamepadEntryData.CanLevel=function(e)return false end
end
end
local a
local function v()
if a then return end
a=MAIL_MANAGER.HasDeletedGuildMail
MAIL_MANAGER.HasDeletedGuildMail=function(i,t)
local o=GetGuildMailItemInfo(t)
if e.guildMailHide[GetGuildIndex(o)]then
return true
else
return a(i,t)
end
end
end
local a
local function r()
if not a then
a=DoesAntiquityPassVisibilityRequirements
end
if e.hideLeads=="off"and not e.hideCodexEntries then
DoesAntiquityPassVisibilityRequirements=a
else
DoesAntiquityPassVisibilityRequirements=function(t)
if ZO_IsAntiquityScryableSubcategory(ANTIQUITY_JOURNAL_GAMEPAD:GetCurrentSubcategoryData())then
if e.hideLeads=="previously discovered"then
return GetNumAntiquitiesRecovered(t)==0
elseif e.hideLeads=="full codex"then
return GetNumAntiquityLoreEntriesAcquired(t)<GetNumAntiquityLoreEntries(t)
end
else
if e.hideCodexEntries then
return GetNumAntiquityLoreEntriesAcquired(t)<GetNumAntiquityLoreEntries(t)
end
end
return a(t)
end
end
end
local a
local function m()
local t=ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(GetAntiquityScryingToolCollectibleId())
if not a then
a=t.GetCooldownAndDurationMs
end
if e.antiquarianEye=="prompt"then
t.GetCooldownAndDurationMs=a
else
t.GetCooldownAndDurationMs=function(o)
local t,a=a(o)
if t<=0 then
t=1
if e.antiquarianEye=="when available"and IsGameCameraActive()and not IsGameCameraUIModeActive()then
o:Use()
end
end
return t,a
end
end
end
local o={
["Compass"]={"bossBar","nearDistanceShow","nearDistanceColor","farDistanceShow","farDistanceColor"},
["Guild Store"]={"guildStoreTimeSort"},
["Map Zoom"]={"mapZoomFactor","mapZoomSpeed"},
["Icon Tweaks"]={"platformShow","canLearnShow","canLearnColor","lockedSetShow","lockedSetColor",
"multiIconSpeed","newIconShow","transmuteShow"},
["Guild Mail"]={"guildMailHide"},
["Antiquities"]={"hideLeads","hideCodexEntries","antiquarianEye"},
}
local function x()
local a=LibHarvensAddonSettings.list.currentSection
local a=a and a.labelText
local o=o[a]
if not o then return end
for o,a in ipairs(o)do
local t=t[a]
if type(t)=="table"then t=ZO_ShallowTableCopy(t)end
e[a]=t
end
if a=="Compass"then
y(e.bossBar)
n()
elseif a=="Map Zoom"then
h()
elseif a=="Icon Tweaks"then
u()
i()
c()
f()
elseif a=="Antiquities"then
r()
m()
end
end
local function j()
local a=LibHarvensAddonSettings
local o=a:AddAddon(k,{
allowDefaults=true,
allowRefresh=true,
defaultsFunction=x,
})
o:AddSetting({
type=a.ST_SECTION,
label="Compass",
})
o:AddSetting({
type=a.ST_DROPDOWN,
label="Boss Bar",
tooltip="Controls how the boss bar and compass interact.",
default=t.bossBar,
ignoreDefault=true,
items={{name="show",data="show"},{name="hide",data="hide"},{name="combined",data="combined"}},
getFunction=function()
return e.bossBar
end,
setFunction=function(a,a,t)
e.bossBar=t.data
y(t.data)
end,
})
o:AddSetting({
type=a.ST_LABEL,
label=function()if not UI_SETTING_COMPASS_DISTANCE_TRACKING or GetSetting(SETTING_TYPE_UI,UI_SETTING_COMPASS_DISTANCE_TRACKING)=="1"then return""else return"|cff0000Turn on Compass Distance Tracking in Interface Options first|r"end end,
})
o:AddSetting({
type=a.ST_CHECKBOX,
label="Show Distances (Near)",
tooltip="Show distance on the compass when a target is nearby.",
default=t.nearDistanceShow,
ignoreDefault=true,
setFunction=function(t)
e.nearDistanceShow=t
n()
end,
getFunction=function()
return e.nearDistanceShow
end,
disable=function()return UI_SETTING_COMPASS_DISTANCE_TRACKING and GetSetting(SETTING_TYPE_UI,UI_SETTING_COMPASS_DISTANCE_TRACKING)~="1"end,
})
o:AddSetting({
type=a.ST_COLOR,
label="Text Color (Near)",
tooltip="Color of the distance on the compass when a target is nearby.",
setFunction=function(...)
local t,o,a=...
e.nearDistanceColor={t,o,a}
n()
end,
default=t.nearDistanceColor,
ignoreDefault=true,
getFunction=function()
return e.nearDistanceColor[1],e.nearDistanceColor[2],e.nearDistanceColor[3],1
end,
disable=function()return not e.nearDistanceShow end,
})
o:AddSetting({
type=a.ST_CHECKBOX,
label="Show Distance (Far)",
tooltip="Show distance on the compass when a target is far away.",
default=t.farDistanceShow,
ignoreDefault=true,
setFunction=function(t)
e.farDistanceShow=t
n()
end,
getFunction=function()
return e.farDistanceShow
end,
disable=function()return UI_SETTING_COMPASS_DISTANCE_TRACKING and GetSetting(SETTING_TYPE_UI,UI_SETTING_COMPASS_DISTANCE_TRACKING)~="1"end,
})
o:AddSetting({
type=a.ST_COLOR,
label="Text Color (Far)",
tooltip="Color of the distance on the compass when a target is far away.",
setFunction=function(...)
local a,o,t=...
e.farDistanceColor={a,o,t}
n()
end,
default=t.farDistanceColor,
ignoreDefault=true,
getFunction=function()
return e.farDistanceColor[1],e.farDistanceColor[2],e.farDistanceColor[3],1
end,
disable=function()return not e.farDistanceShow end,
})
o:AddSetting({
type=a.ST_SECTION,
label="Guild Store",
})
o:AddSetting({
type=a.ST_CHECKBOX,
label="Guild Store Time Sort",
tooltip="Set the default sort order in guild stores to Time on each login.",
default=t.guildStoreTimeSort,
ignoreDefault=true,
getFunction=function()
return e.guildStoreTimeSort
end,
setFunction=function(t)
e.guildStoreTimeSort=t
if t then b()end
end,
})
o:AddSetting({
type=a.ST_SECTION,
label="Map Zoom",
})
o:AddSetting({
type=a.ST_SLIDER,
label="Zoom Factor",
tooltip="Increase how far in the map will zoom in (Recommended: 1.4x).",
default=t.mapZoomFactor,
ignoreDefault=true,
min=1.,
max=3.,
step=.2,
decimals=1,
getFunction=function()return e.mapZoomFactor end,
setFunction=function(t)
e.mapZoomFactor=t
h()
end,
})
o:AddSetting({
type=a.ST_SLIDER,
label="Zoom Speedup",
tooltip="Increase how fast the map will zoom in or out (Recommended: 2.5x).",
default=t.mapZoomSpeed,
ignoreDefault=true,
min=1.,
max=5.,
step=.5,
decimals=1,
getFunction=function()return e.mapZoomSpeed end,
setFunction=function(t)
e.mapZoomSpeed=t
h()
end,
})
o:AddSetting({
type=a.ST_SECTION,
label="Icon Tweaks",
})
o:AddSetting({
type=a.ST_CHECKBOX,
label="Show Platform",
tooltip="Show the platform icon in userids.",
default=t.platformShow,
ignoreDefault=true,
setFunction=function(t)
e.platformShow=t
u()
end,
getFunction=function()
return e.platformShow
end,
})
o:AddSetting({
type=a.ST_CHECKBOX,
label="Show Can Learn",
tooltip="Show icon when an item can be learned.",
default=t.canLearnShow,
ignoreDefault=true,
setFunction=function(t)
e.canLearnShow=t
i()
end,
getFunction=function()
return e.canLearnShow
end,
})
o:AddSetting({
type=a.ST_COLOR,
label="Color (Can Learn)",
tooltip="Color of the icon for items that can be learned. Changes will be applied on next login.",
setFunction=function(...)
local a,t,o=...
e.canLearnColor={a,t,o}
i()
end,
default=t.canLearnColor,
ignoreDefault=true,
getFunction=function()
return e.canLearnColor[1],e.canLearnColor[2],e.canLearnColor[3],1
end,
disable=function()return not e.canLearnShow end,
})
o:AddSetting({
type=a.ST_CHECKBOX,
label="Show Uncollected Gear",
tooltip="Show icon on gear that can be added to your sets collection.",
default=t.lockedSetShow,
ignoreDefault=true,
setFunction=function(t)
e.lockedSetShow=t
i()
end,
getFunction=function()
return e.lockedSetShow
end,
})
o:AddSetting({
type=a.ST_COLOR,
label="Color (Uncollected Gear)",
tooltip="Color of the icon for gear that can be added to your sets collection. Changes will be applied on next login.",
setFunction=function(...)
local a,o,t=...
e.lockedSetColor={a,o,t}
i()
end,
default=t.lockedSetColor,
ignoreDefault=true,
getFunction=function()
return e.lockedSetColor[1],e.lockedSetColor[2],e.lockedSetColor[3],1
end,
disable=function()return not e.lockedSetShow end,
})
o:AddSetting({
type=a.ST_BUTTON,
label="Apply Classic colors",
tooltip="Use classic colors for the above icons.",
buttonText="Apply",
clickHandler=function(t,t)
local t,o,a=ZO_SUCCEEDED_TEXT:UnpackRGBA()
e.canLearnColor={t,o,a}
e.lockedSetColor={t,o,a}
i()
end,
})
o:AddSetting({
type=a.ST_SLIDER,
label="Icon Cycling Speed",
tooltip="Controls how long each icon is visible before fading to the next when icons are stacked. Higher values cycle through them faster. [EXPERIMENTAL]",
default=t.multiIconSpeed,
ignoreDefault=true,
min=1.,
max=5.,
step=1,
decimals=1,
getFunction=function()return e.multiIconSpeed end,
setFunction=function(t)
e.multiIconSpeed=t
c()
end,
})
o:AddSetting({
type=a.ST_CHECKBOX,
label="Show new item alerts",
tooltip="Disable to hide the icons for level up alert and new item alert. Social->Mail is unaffected by this.",
default=t.newIconShow,
ignoreDefault=true,
setFunction=function(t)
e.newIconShow=t
f()
end,
getFunction=function()return e.newIconShow end,
})
o:AddSetting({
type=a.ST_CHECKBOX,
label="Show transmute icons",
tooltip="Disable to hide the icon when an item is retraited or reconstructed.",
default=t.transmuteShow,
ignoreDefault=true,
setFunction=function(t)
e.transmuteShow=t
i()
end,
getFunction=function()return e.transmuteShow end,
})
o:AddSetting({
type=a.ST_SECTION,
label="Guild Mail",
})
for i=1,5 do
o:AddSetting({
type=a.ST_CHECKBOX,
label=string.format("Hide guild %d",i),
tooltip=function()
local e=GetGuildId(i)
if e>0 then
return string.format("Hide mail from Guild: %s",GetGuildName(e))
else
return string.format("You are currently not in Guild %d.",i)
end
end,
default=t.guildMailHide[i],
ignoreDefault=true,
setFunction=function(t)
e.guildMailHide[i]=t
v()
end,
getFunction=function()
return e.guildMailHide[i]
end,
})
end
o:AddSetting({
type=a.ST_SECTION,
label="Antiquities",
})
o:AddSetting({
type=a.ST_DROPDOWN,
label="Hide Leads",
tooltip="Hide antiquity leads that you don't want to scry.",
default=t.hideLeads,
ignoreDefault=true,
items={{name="off",data="off"},{name="previously discovered",data="previously discovered"},{name="full codex",data="full codex"}},
getFunction=function()
return e.hideLeads
end,
setFunction=function(a,a,t)
e.hideLeads=t.data
r()
end,
})
o:AddSetting({
type=a.ST_CHECKBOX,
label="Hide Full Codex Entries",
tooltip="Hide codex entries that are already complete.",
default=t.hideCodexEntries,
ignoreDefault=true,
getFunction=function()
return e.hideCodexEntries
end,
setFunction=function(t)
e.hideCodexEntries=t
r()
end,
})
o:AddSetting({
type=a.ST_DROPDOWN,
label="Antiquarian's Eye",
tooltip="Hide the prompt when entering a dig site. Optionally while exploring, use the eye when available.",
default=t.antiquarianEye,
ignoreDefault=true,
items={{name="prompt",data="prompt"},{name="no prompt",data="no prompt"},{name="when available",data="when available"}},
getFunction=function()
return e.antiquarianEye
end,
setFunction=function(a,a,t)
e.antiquarianEye=t.data
m()
end,
})
end
local function a(o,a)
if a~=l then return end
EVENT_MANAGER:UnregisterForEvent(l,EVENT_ADD_ON_LOADED)
w=COMPASS_FRAME.RefreshVisible
p=COMPASS_FRAME.SetCompassHidden
e=ZO_SavedVars:NewAccountWide(g,q,GetWorldName(),t)
j()
if e.bossBar~=t.bossBar then y(e.bossBar)end
if not(e.nearDistanceShow and e.farDistanceShow
and s(e.nearDistanceColor)
and s(e.farDistanceColor))then n()end
if e.guildStoreTimeSort~=t.guildStoreTimeSort then b()end
if e.mapZoomFactor~=t.mapZoomFactor or e.mapZoomSpeed~=t.mapZoomSpeed then h()end
if e.platformShow~=t.platformShow then u()end
if not(e.canLearnShow==t.canLearnShow and s(e.canLearnColor)and e.lockedSetShow==t.lockedSetShow and s(e.lockedSetColor)and e.transmuteShow==t.transmuteShow)then i()end
if e.multiIconSpeed~=t.multiIconSpeed then c()end
if e.newIconShow~=t.newIconShow then f()end
if not ZO_AreNumericallyIndexedTablesEqual(e.guildMailHide,t.guildMailHide)then v()end
if e.hideLeads~=t.hideLeads or e.hideCodexEntries~=t.hideCodexEntries then r()end
if e.antiquarianEye~=t.antiquarianEye then m()end
end
EVENT_MANAGER:RegisterForEvent(l,EVENT_ADD_ON_LOADED,a)
