LazyCrown=LazyCrown or{}
local ADDON_NAME="LazyCrown"
LazyCrown.VERSION="0.4.0"
local AUTHOR="absolventR3M"
local loadingFrame
function LazyCrown.LoadAll()
local later=LazyCrown.later
if not later then return end
local now=GetFrameTimeMilliseconds and GetFrameTimeMilliseconds()
if now~=nil and loadingFrame==now then return end
loadingFrame=now
local compile=zo_loadstring or loadstring
while later[1] do
local file=later[1]
local fn,err=nil,"can't compile here"
if compile then
local okC,result,message=pcall(compile,file.code,file.name)
if okC then fn,err=result,message else err=result end
end
local ok=false
if fn then ok,err=pcall(fn)end
if later[1]==file then table.remove(later,1)end
if not ok then
pcall(function()CHAT_ROUTER:AddSystemMessage("[Lazy Crown] " .. file.name .. " didn't load: " .. tostring(err))end)
end
end
LazyCrown.later,loadingFrame=nil,nil
end
local toldNotLoaded=false
local function Core(name)
return function(...)
LazyCrown.LoadAll()
local fn=LazyCrown.core and LazyCrown.core[name]
if fn then return fn(...)end
if not LazyCrown.later and not toldNotLoaded then
toldNotLoaded=true
pcall(function()CHAT_ROUTER:AddSystemMessage("[Lazy Crown] Not loaded, try /reloadui.")end)
end
end
end
local PS_BUTTONS={["Press X"]="Press Square",["press X"]="press Square",["Press A"]="Press Cross",
["LT or RT"]="L2 or R2",["Hit start"]="Hit Options"}
function LazyCrown.Buttons(text)
local ps=false
if ZO_IsPlaystationPlatform then
local ok,result=pcall(ZO_IsPlaystationPlatform)
ps=ok and result==true
end
if not ps then return text end
for xbox,playstation in pairs(PS_BUTTONS)do text=text:gsub(xbox,playstation)end
return text
end
SLASH_COMMANDS["/lazycrown"]=Core("SlashCommand")
local slotDialogOpened=false
local SLOT_REMINDER="Reload UI when you can. Setting wheel slots can break whispers, group invites, Enter Now and respawning until you do."
local function Status(text)
pcall(function()
local ok,hex=pcall(function()return LazyCrown.StatusHex and LazyCrown.StatusHex()end)
CHAT_ROUTER:AddSystemMessage("|c" ..(ok and hex or "FF5F1F").. "[Lazy Crown] " .. text .. "|r")
end)
end
local function FromWheel(name)
local fn=Core(name)
return function(...)
if slotDialogOpened then Status(SLOT_REMINDER)end
return fn(...)
end
end
local ICON_PICK_FALLBACK="EsoUI/Art/currency/gamepad/gp_crown_gems.dds"
local ICON_SHARE_FALLBACK="EsoUI/Art/currency/gamepad/gp_crowns.dds"
local ICON_SCOREBOARD="EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_leaderBoards.dds"
local ICON_RESET="EsoUI/Art/Guild/Gamepad/gp_guild_options_delete.dds"
local ICON_PERSONALITY="EsoUI/Art/Campaign/Gamepad/gp_bonusIcon_emperor.dds"
local ICON_GROUP="EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_groups.dds"
local ICON_HISTORY="EsoUI/Art/Guild/History/Gamepad/gp_guildHistory_allianceWar.dds"
local ICON_OVERRIDE="EsoUI/Art/TargetMarkers/Gamepad/Target_Red_Weapons.dds"
local SHARE_HELP="Too lazy to lead? Let the crown decide. Places the call in the Text Chat box. Press X to send."
local SCOREBOARD_SHARE_HELP="Places the scoreboard in the Text Chat box. Press X to send."
pcall(function()
LibRadialMenu:RegisterAddon(ADDON_NAME,"Lazy Crown")
LibRadialMenu:RegisterEntry(ADDON_NAME,"Crown Command","1share",ICON_SHARE_FALLBACK,FromWheel("PickAndShare"),SHARE_HELP)
LibRadialMenu:RegisterEntry(ADDON_NAME,"Change Personality","2persona",ICON_PERSONALITY,FromWheel("CyclePersonality"),
"Puts the next personality on the crown.")
LibRadialMenu:RegisterEntry(ADDON_NAME,"Scoreboard","3record",ICON_SCOREBOARD,FromWheel("ShareScoreboard"),SCOREBOARD_SHARE_HELP)
LibRadialMenu:RegisterEntry(ADDON_NAME,"Reset Scoreboard","4reset",ICON_RESET,FromWheel("ResetScoreboard"),
"Clears the scoreboard.")
LibRadialMenu:RegisterEntry(ADDON_NAME,"Group Check","5group",ICON_GROUP,FromWheel("GroupCheck"),
"Your group size, roles, and how many have Barrier, a necro rez or Negate. In Cyrodiil also the emperor, population, score and where our scrolls are. Shows in your chat window.")
LibRadialMenu:RegisterEntry(ADDON_NAME,"Private Command","6pick",ICON_PICK_FALLBACK,FromWheel("PickPrivately"),
"Just for you, no call-outs. Tells you where to go in your chat window.")
LibRadialMenu:RegisterEntry(ADDON_NAME,"History","7history",ICON_HISTORY,FromWheel("History"),
"Your calls this run with their W or L. Shows in your chat window. Resetting the scoreboard clears it.")
LibRadialMenu:RegisterEntry(ADDON_NAME,"Override","8override",ICON_OVERRIDE,FromWheel("Override"),
"Opens Text Chat. Type where you're going and press Send. Lazy Crown judges your W or L on that one instead of its own call.")
end)
local function AskWhenShown(entryId,fields)
local mine=LibRadialMenu.registeredEntries and LibRadialMenu.registeredEntries[ADDON_NAME]
local entry=mine and mine[entryId]
if type(entry)~="table" or getmetatable(entry)then return end
for field in pairs(fields)do entry[field]=nil end
setmetatable(entry,{__index=function(t,field)
local ask=fields[field]
if not ask then return nil end
local value=ask()
rawset(t,field,value)
return value
end})
end
local function CurrencyIcon(currency,fallback)
if not(currency and GetCurrencyGamepadIcon)then return fallback end
local ok,path=pcall(GetCurrencyGamepadIcon,currency)
return(ok and type(path)=="string" and path~="")and path or fallback
end
pcall(AskWhenShown,"1share",{
icon=function()return CurrencyIcon(CURT_CROWNS,ICON_SHARE_FALLBACK)end,
description=function()return LazyCrown.Buttons(SHARE_HELP)end,
})
pcall(AskWhenShown,"3record",{description=function()return LazyCrown.Buttons(SCOREBOARD_SHARE_HELP)end})
pcall(AskWhenShown,"6pick",{icon=function()return CurrencyIcon(CURT_CROWN_GEMS,ICON_PICK_FALLBACK)end})
local SLOT_WARNING="Reload UI after setting slots. Until you do, whispers, group invites, Enter Now and respawning can break."
local function DialogButtonsUntrusted()
local strip=KEYBIND_STRIP
if not(IsTrustedFunction and strip and strip.GetButtonOrEtherealDescriptorForKeybind)then return nil end
local seen=false
for _,keybind in ipairs({"DIALOG_PRIMARY","DIALOG_NEGATIVE"})do
local button=strip:GetButtonOrEtherealDescriptorForKeybind(keybind)
local descriptor=type(button)=="userdata" and button.keybindButtonDescriptor or button
if type(descriptor)=="table" and type(descriptor.callback)=="function" then
seen=true
if IsTrustedFunction(descriptor.callback)==false then return true end
end
end
if seen then return false end
end
pcall(function()
local dialog=ESO_Dialogs and ESO_Dialogs["LibProfileAssignDialogue"]
if type(dialog)~="table" then return end
local original=dialog.OnShownCallback
dialog.OnShownCallback=function(...)
if not slotDialogOpened then
local ok,untrusted=pcall(DialogButtonsUntrusted)
if not(ok and untrusted==false)then
slotDialogOpened=true
Status(SLOT_WARNING .. " Next time use Lazy Crown > Wheel slots.")
pcall(function()
local alert=ZO_AlertNoSuppression or ZO_Alert
if alert then alert(UI_ALERT_CATEGORY_ALERT,nil,"[Lazy Crown] " .. SLOT_WARNING)end
end)
end
end
if original then return original(...)end
end
end)
pcall(function()
local lib=LibHarvensAddonSettings
if not(lib and lib.AddAddon)then return end
local panel=lib:AddAddon("Lazy Crown")
panel.version,panel.author=LazyCrown.VERSION,AUTHOR
local librarySelect=panel.Select
panel.Select=function(self,...)
local ok,rows=pcall(Core("SettingsRows"))
if ok and type(rows)=="table" and#rows>0 then
self.Select=nil
self:AddSettings(rows)
elseif not ok then
self.Select=nil
pcall(function()CHAT_ROUTER:AddSystemMessage("[Lazy Crown] Settings page didn't load: " .. tostring(rows))end)
end
if librarySelect then return librarySelect(self,...)end
end
end)
