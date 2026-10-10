-- House Directory by @TheGreyWolf98. No external libraries.
local M={name="HouseDirectory",houses={},page=1,index=1,loading=true}
TGWHouseDirectory=M
local sceneName="tgwhousedirectory"
local types=function()return {
 {HOUSING_FURNISHING_LIMIT_TYPE_LOW_IMPACT_ITEM,"Standard furnishings"},
 {HOUSING_FURNISHING_LIMIT_TYPE_HIGH_IMPACT_ITEM,"Special furnishings"},
 {HOUSING_FURNISHING_LIMIT_TYPE_LOW_IMPACT_COLLECTIBLE,"Collectible furnishings"},
 {HOUSING_FURNISHING_LIMIT_TYPE_HIGH_IMPACT_COLLECTIBLE,"Special collectibles"}}
end
local function Say(s)d("[House Directory] "..s)end
local function Clean(s)return (s or ""):gsub("|",""):sub(1,100)end
function M.Rows()
 local rows={};for _,h in ipairs(M.houses)do if IsCollectibleUnlocked(h.collectible)==(M.page==1)then rows[#rows+1]=h end end
 return rows
end
function M.Selected()return M.Rows()[M.index]end
function M.ScanCurrent()
 local id=GetCurrentZoneHouseId();if not id or id==0 then return end
 local cid=GetCollectibleIdForHouse(id);if not cid or cid==0 or not IsCollectibleUnlocked(cid)then return end
 if IsOwnerOfCurrentHouse and not IsOwnerOfCurrentHouse()then return end
 local snapshot={time=GetTimeStamp(),counts={}}
 for _,t in ipairs(types())do snapshot.counts[t[1]]=GetNumHouseFurnishingsPlaced(t[1])end
 M.saved.snapshots[id]=snapshot
 if M.Render then M.Render()end
end
function M.Capacity(h,t)
 return GetHouseFurnishingPlacementLimit(h.id,t) or 0
end
function M.Summary(h)
 local t=HOUSING_FURNISHING_LIMIT_TYPE_LOW_IMPACT_ITEM;local cap=M.Capacity(h,t)
 if M.page==2 then return string.format("Capacity: %d standard furnishings",cap)end
 local s=M.saved.snapshots[h.id];local used=s and s.counts[t]
 if used==nil then return string.format("Visit to scan  |  Capacity: %d",cap)end
 return string.format("%d/%d placed  |  %d free  (saved)",used,cap,math.max(0,cap-used))
end
function M.Travel()
 local h=M.Selected();if not h then return end
 if CanJumpToHouseFromCurrentLocation and not CanJumpToHouseFromCurrentLocation()then Say("Cannot travel from this location.");return end
 if M.page==1 then SCENE_MANAGER:Hide(sceneName);RequestJumpToHouse(h.id,false)
 else local template=GetDefaultHouseTemplateIdForHouse(h.id)
  if not template or template==0 then Say("ESO has no preview template for this house.");return end
  SCENE_MANAGER:Hide(sceneName);RequestJumpToHousePreviewWithTemplate(template)
 end
end
function M.Share()
 local h=M.Selected();if not h or M.page~=1 then return end
 local link=GetHousingLink(h.id,GetDisplayName(),LINK_STYLE_DEFAULT)
 if not link or link==""then Say("House link unavailable.");return end
 SCENE_MANAGER:Hide(sceneName)
 -- Console StartChatInput enables the chat HUD through protected SetSetting.
 -- Prepare the draft using ESO's no-HUD option, then let the player open chat.
 local chat=ZO_GetChatSystem and ZO_GetChatSystem()
 if chat and chat.StartTextEntry then
  chat:StartTextEntry(link,nil,nil,true)
  Say("House link prepared. Open text chat normally, choose your channel and send.")
 else Say("Chat draft unavailable. Your house link: "..link)end
end
function M.Note()
 local h=M.Selected();if not h or M.page~=1 then return end
 M.StopRepeat()
 local show=IsInGamepadPreferredMode() and ZO_Dialogs_ShowGamepadDialog or ZO_Dialogs_ShowDialog
 show(IsInGamepadPreferredMode() and "TGW_HOUSE_NOTE_GAMEPAD" or "TGW_HOUSE_NOTE",{id=h.id,note=M.saved.notes[h.id] or ""},{mainTextParams={h.name},initialEditText=M.saved.notes[h.id] or ""})
end
function M.Entries()
 local groups={
  {id=HOUSE_CATEGORY_TYPE_STAPLE,name="Staple"},
  {id=HOUSE_CATEGORY_TYPE_CLASSIC,name="Classic"},
  {id=HOUSE_CATEGORY_TYPE_NOTABLE,name="Notable"}}
 local entries={}
 for _,group in ipairs(groups)do
  local houses={};for _,h in ipairs(M.Rows())do if GetHouseCategoryType(h.id)==group.id then houses[#houses+1]=h end end
  entries[#entries+1]={group=group.id,name=group.name,count=#houses}
  if M.expanded[group.id]then for _,h in ipairs(houses)do entries[#entries+1]={house=h}end end
 end
 return entries
end
function M.Build()
 if M.window then return end
 M.expanded={};M.cursor=1
 local wm=WINDOW_MANAGER;local w=wm:CreateTopLevelWindow("TGWHouseDirectoryWindow");M.window=w
 w:SetDimensions(1180,840);w:SetAnchor(CENTER,GuiRoot,CENTER,0,0);w:SetHidden(true)
 local sw,sh=GuiRoot:GetDimensions();w:SetScale(math.min(1,sw/1240,sh/900))
 local bg=wm:CreateControl(nil,w,CT_BACKDROP);bg:SetAnchorFill();bg:SetCenterColor(.055,.043,.033,1);bg:SetEdgeColor(.52,.39,.21,1)
 local function Label(x,y,width,height,font)
  local c=wm:CreateControl(nil,w,CT_LABEL);c:SetAnchor(TOPLEFT,w,TOPLEFT,x,y);c:SetDimensions(width,height);c:SetFont(font);c:SetColor(.9,.85,.75,1);return c
 end
 local title=Label(35,22,1100,45,"ZoFontGamepad34");title:SetText("House Directory");title:SetColor(.92,.75,.44,1)
 local rule=wm:CreateControl(nil,w,CT_BACKDROP);rule:SetAnchor(TOPLEFT,w,TOPLEFT,35,122);rule:SetDimensions(1110,2);rule:SetCenterColor(.5,.37,.2,.8);rule:SetEdgeColor(0,0,0,0)
 M.heading=Label(35,82,1100,35,"ZoFontGamepad27")
 local panel=wm:CreateControl(nil,w,CT_BACKDROP);panel:SetAnchor(TOPLEFT,w,TOPLEFT,610,135);panel:SetDimensions(535,600);panel:SetCenterColor(.075,.061,.046,1);panel:SetEdgeColor(.38,.29,.17,1)
 local frame=wm:CreateControl(nil,w,CT_BACKDROP);frame:SetAnchor(TOPLEFT,w,TOPLEFT,626,151);frame:SetDimensions(503,228);frame:SetCenterColor(.025,.02,.015,1);frame:SetEdgeColor(.6,.46,.26,1)
 M.image=wm:CreateControl(nil,w,CT_TEXTURE);M.image:SetAnchor(TOPLEFT,w,TOPLEFT,630,155);M.image:SetDimensions(495,220)
 M.image:SetTextureCoords(0,1,0,1)
 M.imageFallback=Label(650,240,455,60,"ZoFontGamepad27")
 M.houseTitle=Label(630,395,495,60,"ZoFontGamepad27")
 M.houseNote=Label(630,460,495,65,"ZoFontGamepad22")
 M.detail=Label(630,595,495,130,"ZoFontGamepad20")
 M.houseTitle:SetColor(.94,.78,.48,1);M.houseNote:SetColor(.78,.71,.6,1)
 M.barTrack=wm:CreateControl(nil,w,CT_BACKDROP);M.barTrack:SetAnchor(TOPLEFT,w,TOPLEFT,630,535);M.barTrack:SetDimensions(495,10);M.barTrack:SetCenterColor(.025,.022,.017,1);M.barTrack:SetEdgeColor(.35,.28,.18,1)
 M.barFill=wm:CreateControl(nil,w,CT_BACKDROP);M.barFill:SetAnchor(TOPLEFT,M.barTrack,TOPLEFT,1,1);M.barFill:SetDimensions(1,8);M.barFill:SetCenterColor(.68,.5,.25,1);M.barFill:SetEdgeColor(0,0,0,0)
 M.capacityLabel=Label(630,555,495,35,"ZoFontGamepad20")
 M.highlights={}
 M.labels={};for i=1,10 do
  local shade=wm:CreateControl(nil,w,CT_BACKDROP);shade:SetAnchor(TOPLEFT,w,TOPLEFT,30,138+(i-1)*57);shade:SetDimensions(560,55);shade:SetCenterColor(.22,.17,.095,.85);shade:SetEdgeColor(.42,.32,.17,.7);shade:SetHidden(true);M.highlights[i]=shade
 M.labels[i]=Label(35,140+(i-1)*57,550,55,"ZoFontGamepad22");M.labels[i]:SetMaxLineCount(2)end
 M.listFooter=Label(35,725,550,30,"ZoFontGamepad18")
 Label(35,775,1100,45,"ZoFontGamepad18"):SetText("A: expand / collapse category  |  Hold D-pad: move  |  LT/RT: page  |  RS: edit house note\n@TheGreyWolf98  |  1.0.0  |  /houses")
 function M.StopRepeat()EVENT_MANAGER:UnregisterForUpdate(M.name.."Repeat");M.held=nil end
 function M.Selected()
  local entry=M.Entries()[M.cursor];return entry and entry.house
 end
 local function Move(n)local entries=M.Entries();M.cursor=math.max(1,math.min(#entries,M.cursor+n));M.Render()end
 local function Held(n,up)
  if up then if M.held==n then M.StopRepeat()end;return end
  M.StopRepeat();M.held=n;Move(n);local ticks=0
  EVENT_MANAGER:RegisterForUpdate(M.name.."Repeat",120,function()ticks=ticks+1;if ticks>=3 then Move(n)end end)
 end
 local function Tab()M.StopRepeat();M.page=3-M.page;M.cursor=1;M.Render()end
 local function Toggle()
  M.StopRepeat();local entry=M.Entries()[M.cursor]
  if entry and entry.group then M.expanded[entry.group]=not M.expanded[entry.group];M.Render()end
 end
 local keys={alignment=KEYBIND_STRIP_ALIGN_CENTER,
 {name="Owned / Unowned",keybind="UI_SHORTCUT_LEFT_SHOULDER",callback=Tab},
 {name="Owned / Unowned",keybind="UI_SHORTCUT_RIGHT_SHOULDER",callback=Tab},
 {name="Expand / collapse",keybind="UI_SHORTCUT_PRIMARY",visible=function()return M.Selected()==nil end,callback=Toggle},
 {name="Edit note",keybind="UI_SHORTCUT_RIGHT_STICK",visible=function()return M.page==1 and M.Selected()~=nil end,callback=M.Note},
 {name=function()return M.page==1 and "Travel" or "Preview"end,keybind="UI_SHORTCUT_SECONDARY",visible=function()return M.Selected()~=nil end,callback=M.Travel},
 {name="Share in chat",keybind="UI_SHORTCUT_TERTIARY",visible=function()return M.page==1 and M.Selected()~=nil end,callback=M.Share},
 {name="Previous page",keybind="UI_SHORTCUT_LEFT_TRIGGER",callback=function()Move(-10)end},
 {name="Next page",keybind="UI_SHORTCUT_RIGHT_TRIGGER",callback=function()Move(10)end},
 {keybind="UI_SHORTCUT_INPUT_UP",handlesKeyUp=true,callback=function(up)Held(-1,up)end},
 {keybind="UI_SHORTCUT_INPUT_DOWN",handlesKeyUp=true,callback=function(up)Held(1,up)end},
 {name="Back",keybind="UI_SHORTCUT_NEGATIVE",callback=function()SCENE_MANAGER:Hide(sceneName)end}}
 function M.Render()
  local entries=M.Entries();M.cursor=math.max(1,math.min(#entries,M.cursor));local page=math.floor((M.cursor-1)/10)
  M.heading:SetText(string.format("%s  |  %d houses%s",M.page==1 and "Owned"or"Unowned",#M.Rows(),M.loading and "  |  Building catalogue..."or""))
  for i=1,10 do local index=page*10+i;local entry=entries[index];local label=M.labels[i];M.highlights[i]:SetHidden(index~=M.cursor or not entry)
   if entry then local prefix=index==M.cursor and "> "or"  "
    if entry.group then
     label:SetText(prefix..(M.expanded[entry.group]and"[-] "or"[+] ")..entry.name.."  ("..entry.count..")")
    else label:SetText(prefix..entry.house.name.."\n   |caaaaaa"..M.Summary(entry.house).."|r")end
    if entry.group then label:SetColor(.92,.75,.44,1)
    else label:SetColor(index==M.cursor and 1 or .9,index==M.cursor and .9 or .85,index==M.cursor and .68 or .75,1)end
   else label:SetText("")end
  end
  M.listFooter:SetText(string.format("Page %d/%d%s",page+1,math.max(1,math.ceil(#entries/10)),page*10+10<#entries and "  |  More below"or""))
  local h=M.Selected();M.image:SetHidden(true);M.imageFallback:SetHidden(false);M.barTrack:SetHidden(true);M.barFill:SetHidden(true);M.capacityLabel:SetText("")
  if h then
   local texture=GetHousePreviewBackgroundImage(h.id)
   if type(texture)=="string"and texture~=""then M.image:SetTexture(texture);M.image:SetHidden(false);M.imageFallback:SetHidden(true)end
   M.imageFallback:SetText("House preview unavailable")
   M.houseTitle:SetText(h.name..(IsPrimaryHouse(h.id)and" [Primary]"or""))
   local note=M.saved.notes[h.id]or(GetCollectibleNickname and GetCollectibleNickname(h.collectible))or""
   M.houseNote:SetText((note~=""and Clean(note).."\n"or"")..GetZoneNameById(GetHouseZoneId(h.id)))
   local text=""
   local cap=M.Capacity(h,HOUSING_FURNISHING_LIMIT_TYPE_LOW_IMPACT_ITEM)
   local snapshot=M.saved.snapshots[h.id];local used=snapshot and snapshot.counts[HOUSING_FURNISHING_LIMIT_TYPE_LOW_IMPACT_ITEM]
   M.capacityLabel:SetText(M.Summary(h))
   if M.page==1 and used~=nil and cap>0 then
    local ratio=math.max(0,math.min(1,used/cap));M.barTrack:SetHidden(false);M.barFill:SetHidden(ratio==0);M.barFill:SetWidth(math.max(1,493*ratio))
    M.barFill:SetCenterColor(ratio>=.95 and .75 or .68,ratio>=.95 and .3 or .5,ratio>=.95 and .2 or .25,1)
   end
   if M.page==1 then local s=M.saved.snapshots[h.id]
    for _,t in ipairs(types())do local count=s and s.counts[t[1]];text=text..t[2]..": "..(count~=nil and tostring(count)or"?").." / "..M.Capacity(h,t[1]).."\n"end
    text=text..(s and "Saved visit snapshot"or"Visit your house to record usage")
   else text=M.Summary(h).."\n\nPreview only, including off-sale houses.\nPreview access is subject to ESO availability."end
   M.detail:SetText(text)
  else
   M.imageFallback:SetText("Select a house to view its picture")
   M.houseTitle:SetText("Your homes, organised")
   M.houseNote:SetText("Staple  /  Classic  /  Notable")
   M.detail:SetText("Select a category and press A to expand its houses.\n\nSelect a house to see its picture and furnishing details.")
  end
  if SCENE_MANAGER:IsShowing(sceneName)then KEYBIND_STRIP:UpdateKeybindButtonGroup(keys)end
 end
 local scene=ZO_Scene:New(sceneName,SCENE_MANAGER)
 scene:AddFragmentGroup(IsInGamepadPreferredMode()and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW or FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
 scene:AddFragment(ZO_FadeSceneFragment:New(w))
 scene:RegisterCallback("StateChange",function(_,state)
  if state==SCENE_SHOWN then M.Render();KEYBIND_STRIP:AddKeybindButtonGroup(keys)
  elseif state==SCENE_HIDING then M.StopRepeat();KEYBIND_STRIP:RemoveKeybindButtonGroup(keys)end
 end)
end
function M.Open()M.Build();M.ScanCurrent();M.Render();SCENE_MANAGER:Show(sceneName)end
local function Initialize(_,name)
 if name~=M.name then return end
 EVENT_MANAGER:UnregisterForEvent(M.name,EVENT_ADD_ON_LOADED)
 M.saved=ZO_SavedVars:NewAccountWide("TGWHouseDirectorySaved",1,GetWorldName(),{notes={},snapshots={}})
 ZO_Dialogs_RegisterCustomDialog("TGW_HOUSE_NOTE",{
  gamepadInfo={dialogType=GAMEPAD_DIALOGS.BASIC},title={text="House nickname / note"},mainText={text="<<1>>\nLeave blank to remove your custom note."},
  editBox={maxInputCharacters=100,textType=TEXT_TYPE_ALL},
  buttons={{text="Save",callback=function(dialog)M.saved.notes[dialog.data.id]=Clean(ZO_Dialogs_GetEditBoxText(dialog));if M.Render then M.Render()end end},{text=SI_DIALOG_CANCEL}}})
 local parametric=ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
 ZO_Dialogs_RegisterCustomDialog("TGW_HOUSE_NOTE_GAMEPAD",{
  gamepadInfo={dialogType=GAMEPAD_DIALOGS.PARAMETRIC},canQueue=true,blockDialogReleaseOnPress=true,
  setup=function(dialog)dialog:setupFunc()end,title={text="House nickname / note"},
  parametricList={
   {template="ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",templateData={nameField=true,
    textChangedCallback=function(control)parametric.data.note=control:GetText()end,
    setup=function(control,data,selected)
     control.highlight:SetHidden(not selected);control.editBoxControl.textChangedCallback=data.textChangedCallback
     control.editBoxControl:SetMaxInputChars(100);control.editBoxControl:SetDefaultText("Nickname or storage note")
     control.editBoxControl:SetText(parametric.data.note or "");data.control=control
    end,
    callback=function(dialog)local entry=dialog.entryList:GetTargetData();entry.control.editBoxControl:TakeFocus()end,
    narrationText=ZO_GetDefaultParametricListEditBoxNarrationText}},
   {template="ZO_GamepadTextFieldSubmitItem",templateData={text="Save note",
    setup=ZO_SharedGamepadEntry_OnSetup,
    callback=function(dialog)M.saved.notes[dialog.data.id]=Clean(dialog.data.note);ZO_Dialogs_ReleaseDialogOnButtonPress("TGW_HOUSE_NOTE_GAMEPAD");M.Render()end}}
  },buttons={
   {keybind="DIALOG_PRIMARY",text=SI_GAMEPAD_SELECT_OPTION,callback=function(dialog)local data=dialog.entryList:GetTargetData();if data and data.callback then data.callback(dialog)end end},
   {keybind="DIALOG_NEGATIVE",text=SI_DIALOG_CANCEL,callback=function()ZO_Dialogs_ReleaseDialogOnButtonPress("TGW_HOUSE_NOTE_GAMEPAD")end}
  }})
 SLASH_COMMANDS["/houses"]=M.Open;SLASH_COMMANDS["/house"]=M.Open
 local nextId=1
 EVENT_MANAGER:RegisterForUpdate(M.name.."Catalogue",20,function()
  for _=1,20 do local id=nextId;nextId=nextId+1
   local cid=GetCollectibleIdForHouse(id)
   if cid and cid>0 then M.houses[#M.houses+1]={id=id,collectible=cid,name=zo_strformat("<<1>>",GetCollectibleName(cid))}end
  end
  if nextId>2000 then EVENT_MANAGER:UnregisterForUpdate(M.name.."Catalogue");M.loading=false;table.sort(M.houses,function(a,b)return a.name<b.name end);if M.Render then M.Render()end end
 end)
 EVENT_MANAGER:RegisterForEvent(M.name,EVENT_PLAYER_ACTIVATED,function()
  EVENT_MANAGER:UnregisterForUpdate(M.name.."HouseCounts")
  zo_callLater(function()
   M.ScanCurrent()
   if IsOwnerOfCurrentHouse() then EVENT_MANAGER:RegisterForUpdate(M.name.."HouseCounts",5000,M.ScanCurrent)end
   if M.Render then M.Render()end
  end,1500)
 end)
 if EVENT_HOUSING_FURNITURE_COUNT_CHANGED then EVENT_MANAGER:RegisterForEvent(M.name,EVENT_HOUSING_FURNITURE_COUNT_CHANGED,function()M.ScanCurrent()end)end
end
EVENT_MANAGER:RegisterForEvent(M.name,EVENT_ADD_ON_LOADED,Initialize)
