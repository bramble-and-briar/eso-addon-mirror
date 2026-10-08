-- MasterBaiter 1.0.1: Xbox fishing suite.
local NAME="MasterBaiter"
local collection=MasterBaiterCollection
local db,ui,hud,ready=false,nil,nil,false
local diagnostics=false
local log={}
local lastPrompt,lastAttempt,lastBite="",nil,false
local status="Look at a fishing hole to identify its water type."
local baitNames={
 ocean={"worms","chub"},lake={"guts","minnow","minnows"},
 river={"insect parts","shad"},foul={"crawlers","fish roe"},
}
local waterLabels={ocean="Ocean / Saltwater",lake="Lake",river="River",foul="Foul"}
local soundChoices={}
local sounds={
 {"Level up","LEVEL_UP"}, {"Achievement","ACHIEVEMENT_AWARDED"},
 {"Quest complete","QUEST_COMPLETED"}, {"Positive click","DEFAULT_CLICK"},
 {"Negative click","NEGATIVE_CLICK"},
}
local function Clean(s)return zo_strformat("<<1>>",s or "")end
local function Normal(s)
 local n=string.lower(Clean(s))
 n=n:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|t.-|t", ""):gsub("%^%a+", "")
 return n:gsub("^%s+", ""):gsub("%s+$", "")
end
local function Trace(s)
 if not diagnostics then return end
 if log[#log]==s then return end
 log[#log+1]=s;if #log>96 then table.remove(log,1)end
end
local function Water(name)
 local n=Normal(name)
 -- Use literal names, avoiding frontier-pattern dependence in the game client.
 local aliases={{"ocean",{"saltwater","salt water","ocean"}},
  {"foul",{"foul"}}, {"lake",{"lake"}}, {"river",{"river"}}}
 local found
 for _,entry in ipairs(aliases)do
  for _,word in ipairs(entry[2])do
   if n:find(word,1,true)then
    if found and found~=entry[1]then return end
    found=entry[1];break
   end
  end
 end
 return found
end
local function BaitName(name)
 -- Console lure labels include a comma-separated water description.
 local n=Normal(name)
 return (n:match("^([^,]+)") or n):gsub("%s+$", "")
end
local function GoodBait(name,water)
 for _,n in ipairs(baitNames[water]or{})do if BaitName(name)==n then return true end end
 return false
end
local function SelectedSound()
 local sound=soundChoices[db.sound]
 return sound and sound.value
end
local function PlayAlert()
 local sound=SelectedSound();if db.audio and sound then PlaySound(sound)end
end
local function MakeHUD()
 if hud then return end
 local w=WINDOW_MANAGER:CreateTopLevelWindow("MasterBaiterHUD")
 w:SetDimensions(300,300);w:SetAnchor(CENTER,GuiRoot,CENTER,0,-160);w:SetHidden(true);w:SetMouseEnabled(false)
 w:SetDrawTier(DT_HIGH);w:SetDrawLayer(DL_OVERLAY)
 local icon=WINDOW_MANAGER:CreateControl(nil,w,CT_TEXTURE)
 icon:SetDimensions(300,300);icon:SetAnchor(CENTER,w,CENTER,0,0)
 icon:SetTexture("MasterBaiter/Textures/BiteFish.dds");icon:SetHidden(false)
 hud=w
end
local alertSerial=0
local castAlerted=false
local castLure,castStack
local function Bite(preview)
 MakeHUD();alertSerial=alertSerial+1;local serial=alertSerial
 if db.visual or preview then hud:SetHidden(false)end
 if preview then local sound=SelectedSound();if sound then PlaySound(sound)end else PlayAlert()end
 Trace("BITE: reel-in alert")
 zo_callLater(function()if serial==alertSerial then hud:SetHidden(true)end end,2000)
end
local function StopAlert()
 lastBite=false;castAlerted=false;castLure=nil;castStack=nil;alertSerial=alertSerial+1;if hud then hud:SetHidden(true)end
end
local lastState
local function Chatter()
 if not ready then return end
 local interaction=GetInteractionType()
 local count=GetChatterOptionCount()
 local state=tostring(interaction)..":"..tostring(count)
 if state~=lastState then Trace("STATE interaction "..tostring(interaction).." / options "..tostring(count));lastState=state end
 local bite=false
 if interaction==INTERACTION_FISH then
  local selected=GetFishingLure()
  local stack
  if selected then local _,_,n=GetFishingLureInfo(selected);stack=n end
  if selected==castLure and castStack and stack and stack<castStack then
   bite=true;Trace("BITE SIGNAL: selected bait consumed "..tostring(castStack).." -> "..tostring(stack))
  end
  castLure=selected;castStack=stack
 else castAlerted=false;castLure=nil;castStack=nil end
 for i=1,count do
  local text,kind=GetChatterOption(i)
  Trace("CHATTER "..tostring(interaction).." / "..tostring(kind).." / "..Clean(text))
  if interaction==INTERACTION_FISH and kind==CHATTER_FISH_BITE then bite=true end
 end
 if bite and not castAlerted then castAlerted=true;Bite(false)end
 lastBite=bite
end
local function Lures()
 local rows={}
 for i=1,GetNumFishingLures()do
  local name,icon,stack=GetFishingLureInfo(i)
  rows[#rows+1]={index=i,name=Clean(name),stack=stack or 0}
 end
 return rows
end
local lureSnapshot,lastFishingPrompt
local function InspectFishing(force)
 if not ready or not diagnostics then return end
 local rows=Lures();local parts={}
 for _,lure in ipairs(rows)do
  parts[#parts+1]=lure.index..":"..Normal(lure.name)..":"..tostring(lure.stack)
 end
 local snapshot=table.concat(parts,"|").." selected="..tostring(GetFishingLure())
 if force or snapshot~=lureSnapshot then
  Trace("BAIT STOCK / interaction "..tostring(GetInteractionType()))
  for _,lure in ipairs(rows)do Trace("LURE "..lure.index.." ["..Normal(lure.name).."] x"..tostring(lure.stack))end
  Trace("SELECTED "..tostring(GetFishingLure()));lureSnapshot=snapshot
 end
 if GetInteractionType()==INTERACTION_FISH then
  local action,name,blocked,owned,info,context=GetGameCameraInteractableActionInfo()
  local prompt=Clean(action).." / "..Clean(name).." / blocked "..tostring(blocked).." / info "..tostring(info).." / context "..tostring(context)
  if prompt~=lastFishingPrompt then Trace("CAST PROMPT "..prompt);lastFishingPrompt=prompt end
 else lastFishingPrompt=nil end
end
local function AutoBait()
 if not ready then return end
 if IsInteracting()or IsUnitInCombat("player")then return end
 local action,name,blocked,owned,info=GetGameCameraInteractableActionInfo()
 if info~=ADDITIONAL_INTERACT_INFO_FISHING_NODE then lastPrompt="";lastAttempt=nil;return end
 local prompt=tostring(name).." / "..tostring(blocked)
 if prompt~=lastPrompt then Trace("PROMPT "..Clean(action).." / "..Clean(name).." / blocked "..tostring(blocked).." / normalized ["..Normal(name).."]");lastPrompt=prompt;lastAttempt=nil end
 local water=Water(name)
 if not water then status="Unknown water type: "..Clean(name)..". Current bait kept.";return end
 local lures=Lures();local selected=GetFishingLure()
 for _,lure in ipairs(lures)do
  if lure.index==selected and lure.stack>0 and GoodBait(lure.name,water)then
   status=waterLabels[water].."  |  "..lure.name.." selected ("..lure.stack..")";return
  end
 end
 if not db.autoBait then status=waterLabels[water].."  |  Automatic bait selection is off.";return end
 local choice
 for _,wanted in ipairs(baitNames[water])do
  for _,lure in ipairs(lures)do if lure.stack>0 and BaitName(lure.name)==wanted then choice=lure;break end end
  if choice then break end
 end
 if not choice and db.simpleFallback then
  for _,lure in ipairs(lures)do if lure.stack>0 and BaitName(lure.name)=="simple bait"then choice=lure;break end end
 end
 if not choice then status=waterLabels[water].."  |  No suitable bait available. Current bait kept.";return end
 local attempt=prompt..":"..choice.index
 -- One attempt per prompt/choice. A blocked or rejected API call cannot loop.
 if lastAttempt==attempt then return end
 lastAttempt=attempt
 local ok,err=pcall(SetFishingLure,choice.index)
 if ok and GetFishingLure()==choice.index then
  status=waterLabels[water].."  |  Selected "..choice.name.." ("..choice.stack..")"
  Trace("BAIT "..choice.name.." / "..water)
 else status="Bait switch not confirmed. Choose bait manually.";Trace("BAIT switch failed: "..tostring(err))end
end
local function Toggle(key)db[key]=not db[key];lastAttempt=nil end
local function BuildWindow()
 if ui then return end
 local wm=WINDOW_MANAGER
 local w=wm:CreateTopLevelWindow("MasterBaiterWindow")
 w:SetDimensions(1120,820);w:SetAnchor(CENTER,GuiRoot,CENTER,0,0);w:SetHidden(true);w:SetMouseEnabled(true)
 local sw,sh=GuiRoot:GetDimensions();w:SetScale(math.min(1,sw/1180,sh/900))
 local bg=wm:CreateControl(nil,w,CT_BACKDROP);bg:SetAnchorFill();bg:SetCenterColor(.012,.012,.018,1);bg:SetEdgeColor(.38,.07,.065,1)
 local function Label(x,y,width,height,font)
  local c=wm:CreateControl(nil,w,CT_LABEL);c:SetAnchor(TOPLEFT,w,TOPLEFT,x,y);c:SetDimensions(width,height);c:SetFont(font);c:SetColor(.85,.85,.88,1);return c
 end
 local title=Label(35,20,1050,45,"ZoFontGamepad34");title:SetText("MasterBaiter  |  Right bait. Right time. Reel it in.")
 local summary=Label(35,80,1050,70,"ZoFontGamepad22")
 local heading=Label(35,165,1050,38,"ZoFontGamepad27");heading:SetColor(.85,.3,.28,1)
 local lines={};for i=1,16 do lines[i]=Label(35,210+(i-1)*28,1050,28,"ZoFontGamepad22");lines[i]:SetMaxLineCount(1)end
 local footer=Label(35,710,1050,50,"ZoFontGamepad22")
 local credit=Label(35,770,1050,30,"ZoFontGamepad22");credit:SetText("by @TheGreyWolf98  |  MasterBaiter 1.0.1");credit:SetColor(.57,.24,.23,1)
 ui={tab=1,selected=1,page=1}
 local settings={
 {name="Automatic bait selection",key="autoBait"},
 {name="Reel-in sound",key="audio"},
 {name="Reel-in visual alert",key="visual"},
 {name="Alert sound",key="sound"},
 {name="Use Simple Bait if suitable bait runs out",key="simpleFallback"},
 {name="Rare-fish HUD",key="fishHUD",values={"Off","Fishing only","Always"}},
 {name="Show zone arrival reminder for 10 seconds",key="zoneReminder"},
 {name="Show caught fish on the HUD",key="showCaught"},
 {name="Fishing map pins",key="mapPins"},
 {name="Show spots for completed water types",key="allSpots"},
 {name="Map pin size",key="pinSize"},
 }
 local keys
 local function Render()
  summary:SetText(Clean(GetUnitName("player")).."  |  Fishing companion\n"..status)
  local rows={}
  if ui.tab==1 then
   heading:SetText("Settings  |  D-pad selects; A changes")
   for i,setting in ipairs(settings)do
    local value
    if setting.key=="sound"then value=soundChoices[db.sound]and soundChoices[db.sound].name or "No sound available"
    elseif setting.values then value=setting.values[db[setting.key]]
    elseif setting.key=="pinSize"then value=tostring(db.pinSize)
    else value=db[setting.key]and"On"or"Off"end
    rows[#rows+1]=(ui.selected==i and "> "or"  ")..setting.name..": "..value
   end
   rows[#rows+1]="";rows[#rows+1]="X previews the selected sound and reel-in alert."
   rows[#rows+1]="Disable other automatic-bait and bite alerts to avoid conflicts."
  elseif ui.tab==2 then
   heading:SetText("Available bait")
   local selected=GetFishingLure()
   for _,lure in ipairs(Lures())do rows[#rows+1]=(lure.index==selected and "[Selected] "or"")..lure.name.."  x"..lure.stack end
   if #rows==0 then rows[1]="No bait available."end
  elseif ui.tab==3 then
   heading:SetText("How to use MasterBaiter")
   rows={"/mb or /masterbaiter opens this window. /mb help opens these instructions.",
    "Look at a fishing hole until its interaction prompt appears.",
    "Recognized water names select suitable bait from your available stock.",
    "An already suitable bait is kept. Unknown water types keep your current bait.",
    "Automatic bait selection supports English water and bait names.",
    "Ocean / Saltwater: Worms or Chub. Lake: Guts or Minnows.",
    "River: Insect Parts or Shad. Foul: Crawlers or Fish Roe.",
    "Cast normally. At a bite, your enabled sound and large fish icon alert you to reel in.",
    "A changes a setting. X previews the chosen alert. LB/RB changes tabs.",
    "LT/RT changes pages. Y refreshes. B closes.",
    "Settings are saved for your account, separately for each server.",
    "For a missed bait switch or bite: /mb debug before fishing, then reopen it.",
    "Rare fish: fifth tab lists every fish and your account achievement progress.",
    "HUD: Off / Fishing only / Always. /mbhud temporarily hides or restores it.",
    "Zone reminder: missing fish appear below the compass for 10 seconds.",
    "Map pins: known locations, not a guarantee that a hole is currently active.",
    "Turn off other fishing-map pins and fish HUDs to avoid duplicate displays.",
    "Show completed spots and pin size are adjustable in Settings."}
  elseif ui.tab==5 then
   heading:SetText("Rare-fish checklist  |  Current zone")
   rows=collection.Rows()
  else
   heading:SetText("Diagnostic log  |  /mb debug enables capture")
   rows[#rows+1]="Capture: "..(diagnostics and "On"or"Off")..". Aim at a hole, cast, wait for a bite, then reopen /mb debug."
   for _,line in ipairs(log)do rows[#rows+1]=line end
  end
  ui.pages=math.max(1,math.ceil(#rows/16));ui.page=math.max(1,math.min(ui.page,ui.pages))
  for i,label in ipairs(lines)do label:SetText(rows[(ui.page-1)*16+i]or"")end
  footer:SetText("LB/RB: tabs  |  LT/RT: pages  |  Page "..ui.page.." / "..ui.pages.."\nD-pad: select  |  A: change  |  X: preview  |  Y: refresh  |  B: close")
  if keys and KEYBIND_STRIP.UpdateKeybindButtonGroup and SCENE_MANAGER:IsShowing("masterbaiter")then KEYBIND_STRIP:UpdateKeybindButtonGroup(keys)end
 end
 ui.render=Render
 local function Tab(delta)ui.tab=(ui.tab-1+delta)%5+1;ui.page=1;Render()end
 local function Move(delta)ui.selected=(ui.selected-1+delta)%#settings+1;Render()end
 local function Change()
  local setting=settings[ui.selected]
  if setting.key=="sound"then db.sound=db.sound%math.max(1,#soundChoices)+1
  elseif setting.values then db[setting.key]=db[setting.key]%#setting.values+1
  elseif setting.key=="pinSize"then db.pinSize=db.pinSize>=40 and 16 or db.pinSize+4
  else Toggle(setting.key)end
  collection.SettingsChanged()
  Render()
 end
 keys={alignment=KEYBIND_STRIP_ALIGN_CENTER,
  {name="Previous tab",keybind="UI_SHORTCUT_LEFT_SHOULDER",callback=function()Tab(-1)end},
  {name="Next tab",keybind="UI_SHORTCUT_RIGHT_SHOULDER",callback=function()Tab(1)end},
  {name="Preview alert",keybind="UI_SHORTCUT_SECONDARY",callback=function()Bite(true)end},
  {name="Refresh",keybind="UI_SHORTCUT_TERTIARY",callback=function()AutoBait();Chatter();collection.SettingsChanged();Render()end},
  {name="Previous page",keybind="UI_SHORTCUT_LEFT_TRIGGER",enabled=function()return ui.page>1 end,callback=function()ui.page=ui.page-1;Render()end},
  {name="Next page",keybind="UI_SHORTCUT_RIGHT_TRIGGER",enabled=function()return ui.page<ui.pages end,callback=function()ui.page=ui.page+1;Render()end},
  {name="Close",keybind="UI_SHORTCUT_NEGATIVE",callback=function()SCENE_MANAGER:Hide("masterbaiter")end},
  {name="Change setting",keybind="UI_SHORTCUT_PRIMARY",visible=function()return ui.tab==1 end,callback=function()if ui.tab==1 then Change()end end},
  {keybind="UI_SHORTCUT_INPUT_UP",visible=function()return ui.tab==1 end,callback=function()if ui.tab==1 then Move(-1)end end},
  {keybind="UI_SHORTCUT_INPUT_DOWN",visible=function()return ui.tab==1 end,callback=function()if ui.tab==1 then Move(1)end end},
 }
 local scene=ZO_Scene:New("masterbaiter",SCENE_MANAGER)
 scene:AddFragmentGroup(IsInGamepadPreferredMode()and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW or FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
 scene:AddFragment(ZO_FadeSceneFragment:New(w))
 scene:RegisterCallback("StateChange",function(_,state)
  if state==SCENE_SHOWN then KEYBIND_STRIP:AddKeybindButtonGroup(keys)
  elseif state==SCENE_HIDING then KEYBIND_STRIP:RemoveKeybindButtonGroup(keys)end
 end)
end
local function Open(arg)
 BuildWindow();local a=Normal(arg)
 ui.tab=a=="help"and 3 or a=="debug"and 4 or a=="fish"and 5 or 1;ui.page=1
 if a=="debug"then
  diagnostics=true;Trace("Started on "..Clean(GetUnitName("player")))
  Trace("API: fishing interaction "..tostring(INTERACTION_FISH).." / bite "..tostring(CHATTER_FISH_BITE))
  InspectFishing(true);Chatter()
 end
 ui.render();SCENE_MANAGER:Show("masterbaiter")
end
EVENT_MANAGER:RegisterForEvent(NAME,EVENT_ADD_ON_LOADED,function(_,addon)
 if addon~=NAME then return end
 EVENT_MANAGER:UnregisterForEvent(NAME,EVENT_ADD_ON_LOADED)
 db=ZO_SavedVars:NewAccountWide("MasterBaiterSavedVariables",1,GetWorldName(),{autoBait=true,audio=true,visual=true,simpleFallback=false,sound=1})
 for _,choice in ipairs(sounds)do if SOUNDS[choice[2]]then soundChoices[#soundChoices+1]={name=choice[1],value=SOUNDS[choice[2]]}end end
 -- Discover the client-provided duel sounds instead of guessing an identifier.
 local duelKeys={}
 for key,value in pairs(SOUNDS)do
  if type(key)=="string" and key:upper():find("DUEL",1,true) and type(value)=="string"then duelKeys[#duelKeys+1]=key end
 end
 table.sort(duelKeys)
 for _,key in ipairs(duelKeys)do
  local label="Duelling: "..key
  if key:upper():find("START",1,true)then label="Duelling commencing ("..key..")"end
  soundChoices[#soundChoices+1]={name=label,value=SOUNDS[key]}
 end
 db.sound=math.max(1,math.min(tonumber(db.sound)or 1,math.max(1,#soundChoices)))
 collection.Init(db)
 ready=true
 SLASH_COMMANDS["/mb"]=Open;SLASH_COMMANDS["/masterbaiter"]=Open
 EVENT_MANAGER:RegisterForEvent(NAME,EVENT_CHATTER_BEGIN,function(_,count,source)
  Trace("CHATTER BEGIN count "..tostring(count).." / source "..tostring(source));Chatter()
 end)
 EVENT_MANAGER:RegisterForEvent(NAME,EVENT_CHATTER_END,function()Trace("CHATTER END");StopAlert()end)
 if EVENT_INVENTORY_SINGLE_SLOT_UPDATE and GetItemType then
  EVENT_MANAGER:RegisterForEvent(NAME,EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function(_,bag,slot,isNew,sound,reason,change)
   if diagnostics and GetInteractionType()==INTERACTION_FISH and GetItemType(bag,slot)==ITEMTYPE_LURE then
    Trace("BAIT INVENTORY delta "..tostring(change).." / reason "..tostring(reason));InspectFishing(true)
   end
  end)
 end
 EVENT_MANAGER:RegisterForEvent(NAME,EVENT_FISHING_LURE_SET,function(_,index)Trace("LURE selected: "..tostring(index))end)
 EVENT_MANAGER:RegisterForEvent(NAME,EVENT_PLAYER_ACTIVATED,function()
  ready=true;StopAlert();lastPrompt="";lastAttempt=nil;collection.Activated()
  EVENT_MANAGER:RegisterForUpdate(NAME.."Fishing",200,function()
   InspectFishing(false);AutoBait();collection.Tick();if GetInteractionType()==INTERACTION_FISH then Chatter()elseif lastBite then StopAlert()end
  end)
 end)
 EVENT_MANAGER:RegisterForEvent(NAME,EVENT_PLAYER_DEACTIVATED,function()
  collection.Deactivate();ready=false;EVENT_MANAGER:UnregisterForUpdate(NAME.."Fishing");StopAlert()
  if SCENE_MANAGER:IsShowing("masterbaiter")then SCENE_MANAGER:Hide("masterbaiter")end
 end)
end)
