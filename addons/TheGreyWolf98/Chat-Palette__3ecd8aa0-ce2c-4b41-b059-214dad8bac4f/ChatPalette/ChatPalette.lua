local M={name="ChatPalette",index=1,preset=1,rows={}}
TGWChatPalette=M
local presets={{"Red","FF5555"},{"Gold","FFD166"},{"Green","7DE28A"},{"Blue","75BFFF"},{"Purple","C899FF"},{"Pink","FF9AC6"},{"White","FFFFFF"},{"Orange","FFA45B"}}
local function Say(s)d("[Chat Palette] "..s)end
function M.Parse(s)
 s=(s or ""):gsub("^%s+",""):gsub("%s+$",""):gsub("^#",""):upper()
 if #s~=6 or not s:match("^[0-9A-F]+$")then return nil end
 return s,tonumber(s:sub(1,2),16)/255,tonumber(s:sub(3,4),16)/255,tonumber(s:sub(5,6),16)/255
end
function M.Hex(id)
 local r,g,b=GetChatCategoryColor(id)
 return string.format("%02X%02X%02X",math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5))
end
function M.Set(id,value)
 local hex,r,g,b=M.Parse(value)
 if not hex then Say("Use exactly six hex digits, for example #FF3333.");return false end
 local ok,err=pcall(SetChatCategoryColor,id,r,g,b)
 if not ok then Say("ESO rejected the colour change: "..tostring(err));return false end
 M.saved.colours[id]=hex
 if M.Render then M.Render()end
 return true
end
function M.Apply()
 for id,hex in pairs(M.saved.colours)do local _,r,g,b=M.Parse(hex)
  if r then local ok,err=pcall(SetChatCategoryColor,id,r,g,b);if not ok then Say("Could not apply saved colours: "..tostring(err));return end end
 end
 if M.Render then M.Render()end
end
function M.Reset()
 local row=M.rows[M.index];if not row then return end
 local ok,err=pcall(ResetChatCategoryColorToDefault,row.id)
 if ok then M.saved.colours[row.id]=nil;M.Render()else Say("Reset rejected: "..tostring(err))end
end
function M.Edit()
 local row=M.rows[M.index];if not row then return end
 ZO_Dialogs_ShowGamepadDialog("TGW_CHAT_HEX",{id=row.id,note=M.Hex(row.id),name=row.name})
end
function M.Build()
 if M.window then return end
 local wm=WINDOW_MANAGER;local w=wm:CreateTopLevelWindow("TGWChatPaletteWindow");M.window=w
 w:SetDimensions(1060,800);w:SetAnchor(CENTER,GuiRoot,CENTER,0,0);w:SetHidden(true)
 local sw,sh=GuiRoot:GetDimensions();w:SetScale(math.min(1,sw/1120,sh/860))
 local bg=wm:CreateControl(nil,w,CT_BACKDROP);bg:SetAnchorFill();bg:SetCenterColor(.045,.036,.03,1);bg:SetEdgeColor(.5,.38,.2,1)
 local function Label(x,y,width,height,font)
  local c=wm:CreateControl(nil,w,CT_LABEL);c:SetAnchor(TOPLEFT,w,TOPLEFT,x,y);c:SetDimensions(width,height);c:SetFont(font);c:SetColor(.9,.85,.75,1);return c
 end
 Label(35,25,1000,45,"ZoFontGamepad34"):SetText("Chat Palette  |  Your colours, every character")
 local rule=wm:CreateControl(nil,w,CT_BACKDROP);rule:SetAnchor(TOPLEFT,w,TOPLEFT,35,88);rule:SetDimensions(990,2);rule:SetCenterColor(.5,.38,.2,1);rule:SetEdgeColor(0,0,0,0)
 M.highlights={}
 M.labels={};for i=1,12 do
  local shade=wm:CreateControl(nil,w,CT_BACKDROP);shade:SetAnchor(TOPLEFT,w,TOPLEFT,30,103+(i-1)*45);shade:SetDimensions(525,42);shade:SetCenterColor(.2,.15,.08,.9);shade:SetEdgeColor(.4,.3,.15,1);shade:SetHidden(true);M.highlights[i]=shade
 M.labels[i]=Label(35,105+(i-1)*45,515,42,"ZoFontGamepad22")end
 M.preview=Label(595,130,420,180,"ZoFontGamepad27")
 M.help=Label(595,345,420,320,"ZoFontGamepad22")
 Label(35,720,990,60,"ZoFontGamepad18"):SetText("A: hex editor  |  X: apply preset  |  LB/RB: choose preset  |  Y: reset selected channel\nLT/RT: page  |  @TheGreyWolf98  |  1.0.0  |  /chatcolours")
 local function Move(n)M.index=math.max(1,math.min(#M.rows,M.index+n));M.Render()end
 local keys={alignment=KEYBIND_STRIP_ALIGN_CENTER,
 {name="Hex colour",keybind="UI_SHORTCUT_PRIMARY",callback=M.Edit},
 {name="Apply preset",keybind="UI_SHORTCUT_SECONDARY",callback=function()M.Set(M.rows[M.index].id,presets[M.preset][2])end},
 {name="Reset channel",keybind="UI_SHORTCUT_TERTIARY",callback=M.Reset},
 {name="Previous preset",keybind="UI_SHORTCUT_LEFT_SHOULDER",callback=function()M.preset=(M.preset-2)%#presets+1;M.Render()end},
 {name="Next preset",keybind="UI_SHORTCUT_RIGHT_SHOULDER",callback=function()M.preset=M.preset%#presets+1;M.Render()end},
 {name="Previous page",keybind="UI_SHORTCUT_LEFT_TRIGGER",callback=function()Move(-12)end},
 {name="Next page",keybind="UI_SHORTCUT_RIGHT_TRIGGER",callback=function()Move(12)end},
 {keybind="UI_SHORTCUT_INPUT_UP",callback=function()Move(-1)end},
 {keybind="UI_SHORTCUT_INPUT_DOWN",callback=function()Move(1)end},
 {name="Back",keybind="UI_SHORTCUT_NEGATIVE",callback=function()SCENE_MANAGER:Hide("tgwchatpalette")end}}
 function M.Render()
  local page=math.floor((M.index-1)/12)
  for i=1,12 do local index=page*12+i;local row=M.rows[index];M.highlights[i]:SetHidden(index~=M.index or row==nil)
   M.labels[i]:SetText(row and ((index==M.index and "> "or"  ")..row.name.."  |c"..M.Hex(row.id).."#"..M.Hex(row.id).."|r"..(M.saved.colours[row.id]and"  [Shared]"or""))or"")
  end
  local row=M.rows[M.index];local hex=M.Hex(row.id);local preset=presets[M.preset]
  M.preview:SetText(row.name.."\n\n|c"..hex.."Example chat message\n#"..hex.."|r")
  M.help:SetText("Preset: |c"..preset[2]..preset[1].."  #"..preset[2].."|r\n\nSaved colours reapply when you log into another character on this server.\n\nOnly channels you change are shared. Reset returns a channel to ESO's default.\n\nCheck new chat messages after applying a colour.")
  if SCENE_MANAGER:IsShowing("tgwchatpalette")then KEYBIND_STRIP:UpdateKeybindButtonGroup(keys)end
 end
 local scene=ZO_Scene:New("tgwchatpalette",SCENE_MANAGER);scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW);scene:AddFragment(ZO_FadeSceneFragment:New(w))
 scene:RegisterCallback("StateChange",function(_,state)if state==SCENE_SHOWN then KEYBIND_STRIP:AddKeybindButtonGroup(keys)elseif state==SCENE_HIDING then KEYBIND_STRIP:RemoveKeybindButtonGroup(keys)end end)
end
function M.Open()M.Build();M.Render();SCENE_MANAGER:Show("tgwchatpalette")end
local function Initialize(_,name)
 if name~=M.name then return end
 EVENT_MANAGER:UnregisterForEvent(M.name,EVENT_ADD_ON_LOADED)
 M.saved=ZO_SavedVars:NewAccountWide("TGWChatPaletteSaved",1,GetWorldName(),{colours={}})
 local function Add(name,id)if id then M.rows[#M.rows+1]={name=name,id=id}end end
 Add("Say",CHAT_CATEGORY_SAY);Add("Yell",CHAT_CATEGORY_YELL);Add("Zone",CHAT_CATEGORY_ZONE);Add("Group",CHAT_CATEGORY_PARTY)
 Add("Whispers received",CHAT_CATEGORY_WHISPER_INCOMING);Add("Whispers sent",CHAT_CATEGORY_WHISPER_OUTGOING)
 for i=1,5 do Add("Guild "..i,_G["CHAT_CATEGORY_GUILD_"..i])end
 for i=1,5 do Add("Officers "..i,_G["CHAT_CATEGORY_OFFICER_"..i])end
 Add("Emotes",CHAT_CATEGORY_EMOTE);Add("System",CHAT_CATEGORY_SYSTEM)
 local parametric=ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
 ZO_Dialogs_RegisterCustomDialog("TGW_CHAT_HEX",{
  gamepadInfo={dialogType=GAMEPAD_DIALOGS.PARAMETRIC},canQueue=true,blockDialogReleaseOnPress=true,
  setup=function(dialog)dialog:setupFunc()end,title={text="Hex colour: six digits"},
  parametricList={
   {template="ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",templateData={nameField=true,
    textChangedCallback=function(control)parametric.data.note=control:GetText()end,
    setup=function(control,data,selected)
     control.highlight:SetHidden(not selected);control.editBoxControl.textChangedCallback=data.textChangedCallback
     control.editBoxControl:SetMaxInputChars(7);control.editBoxControl:SetDefaultText("#FF3333")
     control.editBoxControl:SetText(parametric.data.note or "");data.control=control
    end,
    callback=function(dialog)local entry=dialog.entryList:GetTargetData();entry.control.editBoxControl:TakeFocus()end,
    narrationText=ZO_GetDefaultParametricListEditBoxNarrationText}},
   {template="ZO_GamepadTextFieldSubmitItem",templateData={text="Apply colour",setup=ZO_SharedGamepadEntry_OnSetup,
    callback=function(dialog)if M.Set(dialog.data.id,dialog.data.note)then ZO_Dialogs_ReleaseDialogOnButtonPress("TGW_CHAT_HEX")end end}}
  },buttons={
   {keybind="DIALOG_PRIMARY",text=SI_GAMEPAD_SELECT_OPTION,callback=function(dialog)local data=dialog.entryList:GetTargetData();if data and data.callback then data.callback(dialog)end end},
   {keybind="DIALOG_NEGATIVE",text=SI_DIALOG_CANCEL,callback=function()ZO_Dialogs_ReleaseDialogOnButtonPress("TGW_CHAT_HEX")end}
  }})
 SLASH_COMMANDS["/chatcolours"]=M.Open;SLASH_COMMANDS["/chatcolors"]=M.Open;SLASH_COMMANDS["/palette"]=M.Open
 EVENT_MANAGER:RegisterForEvent(M.name,EVENT_PLAYER_ACTIVATED,function()zo_callLater(M.Apply,1000)end)
end
EVENT_MANAGER:RegisterForEvent(M.name,EVENT_ADD_ON_LOADED,Initialize)
