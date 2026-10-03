MidTrialMechs = MidTrialMechs or {}
local MTM = MidTrialMechs
MTM.UI = MTM.UI or {}
local UI = MTM.UI

local C={panel={.92,.92,.92,.94},edge={.1,.1,.1,.95},text={.08,.08,.08,1},muted={.3,.3,.3,1},red={.70,.05,.05,1},redSoft={.55,.08,.08,1},white={1,1,1,1},green={.08,.45,.16,1}}
local NOTE_HINT="LEFT BLANK - FOR USER TO ADD YOUR OWN NOTES FOR GROUP CONTENT IF NEEDED"
local CHAT_MAX=350
local function color(c,v)c:SetColor(v[1],v[2],v[3],v[4])end
local function label(p,f,t)local c=WINDOW_MANAGER:CreateControl(nil,p,CT_LABEL)c:SetFont(f)c:SetText(t or "")color(c,C.text)return c end
local function button(p,t,w,h,cb)
 local b=WINDOW_MANAGER:CreateControl(nil,p,CT_BUTTON)b:SetDimensions(w,h)b:SetMouseEnabled(true)b:SetClickSound("Click")
 local bg=WINDOW_MANAGER:CreateControl(nil,b,CT_BACKDROP)bg:SetAnchorFill(b)bg:SetCenterColor(.12,.12,.12,.94)bg:SetEdgeColor(.04,.04,.04,1)bg:SetEdgeTexture(nil,1,1,1)
 local l=label(b,"ZoFontGameBold",t)l:SetAnchorFill(b)l:SetHorizontalAlignment(TEXT_ALIGN_CENTER)l:SetVerticalAlignment(TEXT_ALIGN_CENTER)color(l,C.white)
 b.bg,b.label=bg,l;b:SetHandler("OnMouseEnter",function()bg:SetCenterColor(C.redSoft[1],C.redSoft[2],C.redSoft[3],.98)end)b:SetHandler("OnMouseExit",function()bg:SetCenterColor(.12,.12,.12,.94)end)b:SetHandler("OnClicked",cb)return b
end
local function setStatus(self,text,c)self.status:SetText(text)color(self.status,c or C.muted)end
local function compactForChat(text)return (text:gsub("\r",""):gsub("\n+"," | "):gsub("•%s*",""):gsub("%s+"," "))end

function UI:CloseDropdown() if self.dropPanel then self.dropPanel:SetHidden(true) end self.dropMode=nil end
function UI:OpenDropdown(mode,items)
 self:CloseDropdown();self.dropMode=mode
 local anchor=(mode=="trial") and self.trialButton or self.bossButton
 local width=(mode=="trial") and 300 or 420
 self.dropPanel:SetWidth(width);self.dropPanel:ClearAnchors();self.dropPanel:SetAnchor(TOPLEFT,anchor,BOTTOMLEFT,0,2)
 for _,b in ipairs(self.dropButtons) do b:SetHidden(true) end
 for i,name in ipairs(items) do
  local b=self.dropButtons[i]
  if not b then b=button(self.dropPanel,name,width,30,function()self:ChooseDropdown(i)end);self.dropButtons[i]=b end
  b.label:SetText(name);b.value=name;b:SetDimensions(width,30);b:ClearAnchors();b:SetAnchor(TOPLEFT,self.dropPanel,TOPLEFT,0,(i-1)*30);b:SetHidden(false)
 end
 self.dropPanel:SetHeight(#items*30);self.dropPanel:SetHidden(false)
end
function UI:ChooseDropdown(i)
 local b=self.dropButtons[i];if not b or not b.value then return end
 local value,mode=b.value,self.dropMode;self:CloseDropdown();if mode=="trial" then self:SelectTrial(value) else self:SelectBoss(value) end
end

local function makeEditBox(self,x,titleText)
 local title=label(self.window,"ZoFontGameBold",titleText);title:SetAnchor(TOPLEFT,self.window,TOPLEFT,x,167)
 local bg=WINDOW_MANAGER:CreateControl(nil,self.window,CT_BACKDROP);bg:SetAnchor(TOPLEFT,self.window,TOPLEFT,x,192);bg:SetDimensions(492,240);bg:SetCenterColor(.98,.98,.98,.80);bg:SetEdgeColor(.35,.35,.35,.9);bg:SetEdgeTexture(nil,1,1,1)
 local e=WINDOW_MANAGER:CreateControl(nil,bg,CT_EDITBOX);e:SetAnchor(TOPLEFT,bg,TOPLEFT,10,8);e:SetDimensions(472,224);e:SetFont("ZoFontGame");e:SetColor(C.text[1],C.text[2],C.text[3],1);e:SetMultiLine(true);e:SetMaxInputChars(5000);e:SetNewLineEnabled(true);e:SetMouseEnabled(true);e:SetEditEnabled(false)
 e.mtmBg=bg
 return e
end

function UI:Create()
 if self.window then return end
 local wm=WINDOW_MANAGER
 self.window=wm:CreateTopLevelWindow("MidTrialMechsPanel");self.window:SetDimensions(1030,525);self.window:SetHidden(true);self.window:SetMovable(true);self.window:SetMouseEnabled(true);self.window:SetClampedToScreen(true);self.window:SetDrawTier(DT_HIGH);self.window:SetDrawLayer(DL_OVERLAY)
 local p=MTM.SV.panelPosition or {x=400,y=250};self.window:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,p.x,p.y)
 self.window:SetHandler("OnMoveStop",function()MTM.SV.panelPosition={x=self.window:GetLeft(),y=self.window:GetTop()}end)
 local bg=wm:CreateControl(nil,self.window,CT_BACKDROP);bg:SetAnchorFill(self.window);bg:SetCenterColor(unpack(C.panel));bg:SetEdgeColor(unpack(C.edge));bg:SetEdgeTexture(nil,2,2,2)
 self.moveBar=wm:CreateControl(nil,self.window,CT_BACKDROP);self.moveBar:SetAnchor(TOPLEFT,self.window,TOPLEFT,2,2);self.moveBar:SetDimensions(1026,38);self.moveBar:SetCenterColor(.10,.10,.10,.96);self.moveBar:SetEdgeColor(.04,.04,.04,1);self.moveBar:SetEdgeTexture(nil,1,1,1);self.moveBar:SetMouseEnabled(true)
 self.moveText=label(self.moveBar,"$(BOLD_FONT)|18","CLICK <HERE> TO MOVE");self.moveText:SetAnchor(CENTER,self.moveBar,CENTER,0,0);self.moveText:SetMouseEnabled(false);color(self.moveText,C.white)
 self.moveBar:SetHandler("OnMouseDown",function(_,button)if button==MOUSE_BUTTON_INDEX_LEFT then self.window:StartMoving() end end)
 self.moveBar:SetHandler("OnMouseUp",function(_,button)if button==MOUSE_BUTTON_INDEX_LEFT then self.window:StopMovingOrResizing() end end)
 self.title=label(self.window,"$(BOLD_FONT)|18","MID TRIAL MECHS");self.title:SetAnchor(TOPLEFT,self.window,TOPLEFT,18,48)
 self.tag=label(self.window,"ZoFontGameSmall","Less Typing. More Pulling.");self.tag:SetAnchor(TOPRIGHT,self.window,TOPRIGHT,-18,52);color(self.tag,C.red)
 local line=wm:CreateControl(nil,self.window,CT_TEXTURE);line:SetDimensions(994,2);line:SetAnchor(TOPLEFT,self.window,TOPLEFT,18,78);line:SetColor(C.red[1],C.red[2],C.red[3],1);line:SetTexture("EsoUI/Art/Miscellaneous/horizontalDivider.dds")
 local tl=label(self.window,"ZoFontGameBold","TRIAL");tl:SetAnchor(TOPLEFT,self.window,TOPLEFT,18,95)
 self.trialButton=button(self.window,"Select Trial",300,34,function()self:OpenDropdown("trial",MTM.trialOrder)end);self.trialButton:SetAnchor(TOPLEFT,self.window,TOPLEFT,18,117)
 local bl=label(self.window,"ZoFontGameBold","BOSS");bl:SetAnchor(TOPLEFT,self.window,TOPLEFT,336,95)
 self.bossButton=button(self.window,"Select Boss",420,34,function()local t=MTM.trials[self.selectedTrial];self:OpenDropdown("boss",t and t.order or {})end);self.bossButton:SetAnchor(TOPLEFT,self.window,TOPLEFT,336,117)
 local function addDropdownArrow(btn) local a=wm:CreateControl(nil,btn,CT_TEXTURE);a:SetDimensions(18,18);a:SetAnchor(RIGHT,btn,RIGHT,-8,0);a:SetTexture("EsoUI/Art/Buttons/large_rightarrow_up.dds");a:SetTextureRotation(math.pi/2);a:SetMouseEnabled(false);btn.mtmArrow=a end
 addDropdownArrow(self.trialButton);addDropdownArrow(self.bossButton)
 self.dropPanel=wm:CreateControl(nil,self.window,CT_CONTROL);self.dropPanel:SetDrawTier(DT_HIGH);self.dropPanel:SetDrawLayer(DL_OVERLAY);self.dropPanel:SetHidden(true);self.dropButtons={}

 self.mechEdit=makeEditBox(self,18,"VET MECHANICS")
 self.noteEdit=makeEditBox(self,520,"RAID LEAD NOTES")

 self.mechCount=label(self.window,"ZoFontGameSmall","0 / 350");self.mechCount:SetAnchor(TOPRIGHT,self.window,TOPLEFT,510,438);color(self.mechCount,C.muted)
 self.noteCount=label(self.window,"ZoFontGameSmall","0 / 350");self.noteCount:SetAnchor(TOPRIGHT,self.window,TOPLEFT,1012,438);color(self.noteCount,C.muted)
 self.mechEdit:SetHandler("OnTextChanged",function()self:UpdateCounters()end)
 self.noteEdit:SetHandler("OnTextChanged",function()self:UpdateCounters()end)

 self.mechEditButton=button(self.window,"EDIT",72,32,function()self:BeginEdit("mech")end);self.mechEditButton:SetAnchor(TOPLEFT,self.window,TOPLEFT,18,462)
 self.mechSave=button(self.window,"SAVE",72,32,function()self:SaveEdit("mech")end);self.mechSave:SetAnchor(LEFT,self.mechEditButton,RIGHT,6,0)
 self.mechReset=button(self.window,"RESET",82,32,function()self:ResetMech()end);self.mechReset:SetAnchor(LEFT,self.mechSave,RIGHT,6,0)
 self.mechSend=button(self.window,"SEND MECHS",140,32,function()self:SendMechs()end);self.mechSend:SetAnchor(LEFT,self.mechReset,RIGHT,6,0);self.mechSend.bg:SetCenterColor(C.red[1],C.red[2],C.red[3],.98)

 self.noteEditButton=button(self.window,"EDIT",72,32,function()self:BeginEdit("note")end);self.noteEditButton:SetAnchor(TOPLEFT,self.window,TOPLEFT,520,462)
 self.noteSave=button(self.window,"SAVE",72,32,function()self:SaveEdit("note")end);self.noteSave:SetAnchor(LEFT,self.noteEditButton,RIGHT,6,0)
 self.noteReset=button(self.window,"RESET",82,32,function()self:ResetNotes()end);self.noteReset:SetAnchor(LEFT,self.noteSave,RIGHT,6,0)
 self.noteSend=button(self.window,"SEND NOTES",140,32,function()self:SendNotes()end);self.noteSend:SetAnchor(LEFT,self.noteReset,RIGHT,6,0);self.noteSend.bg:SetCenterColor(C.red[1],C.red[2],C.red[3],.98)

 self.status=label(self.window,"ZoFontGameSmall","Select a trial and boss.");self.status:SetAnchor(BOTTOM,self.window,BOTTOM,0,-10);color(self.status,C.muted)
 self:SelectTrial(MTM.SV.selectedTrial or MTM.trialOrder[1],true)
end

function UI:GetOverride(trial,boss)local t=MTM.SV.customText[trial];return t and t[boss] or nil end
function UI:GetMechText(trial,boss)return self:GetOverride(trial,boss) or MTM:GetDefaultText(trial,boss) end
function UI:GetNote(trial,boss)local t=MTM.SV.bossNotes[trial];return t and t[boss] or nil end
function UI:ShowNote(trial,boss)local n=self:GetNote(trial,boss);return (n and n~="") and n or NOTE_HINT end
function UI:SelectTrial(name,restoreBoss)
 local trial=MTM.trials[name];if not trial then return end
 self.selectedTrial=name;MTM.SV.selectedTrial=name;self.trialButton.label:SetText(name)
 local boss=(restoreBoss and MTM.SV.selectedBoss and trial.bosses[MTM.SV.selectedBoss]) and MTM.SV.selectedBoss or trial.order[1];self:SelectBoss(boss)
end
function UI:FinalChatLength(which)
 if not self.selectedBoss then return 0 end
 local e=(which=="mech") and self.mechEdit or self.noteEdit
 local body=e and e:GetText() or ""
 if which=="note" and body==NOTE_HINT then body="" end
 return #compactForChat(body)
end
function UI:UpdateCounters()
 if not self.mechCount or not self.noteCount then return end
 self.mechCount:SetText(self:FinalChatLength("mech").." / "..CHAT_MAX)
 self.noteCount:SetText(self:FinalChatLength("note").." / "..CHAT_MAX)
end

function UI:SelectBoss(name)
 local trial=MTM.trials[self.selectedTrial];if not trial or not trial.bosses[name] then return end
 self.selectedBoss=name;MTM.SV.selectedBoss=name;self.bossButton.label:SetText(name)
 self.mechEdit:LoseFocus();self.noteEdit:LoseFocus();self.mechEdit:SetEditEnabled(false);self.noteEdit:SetEditEnabled(false);self.editing=nil
 self.mechEdit:SetText(self:GetMechText(self.selectedTrial,name));self.noteEdit:SetText(self:ShowNote(self.selectedTrial,name));self:UpdateCounters();setStatus(self,"Ready: "..name,C.green)
end
function UI:BeginEdit(which)
 if not self.selectedBoss then return end
 local e=(which=="mech") and self.mechEdit or self.noteEdit
 self.mechEdit:SetEditEnabled(false);self.noteEdit:SetEditEnabled(false);self.mechEdit:LoseFocus();self.noteEdit:LoseFocus()
 e:SetEditEnabled(true);if e.mtmBg then e.mtmBg:SetCenterColor(.10,.10,.10,.96) end;e:SetColor(1,1,1,1);self.editing=which;e:TakeFocus();self:UpdateCounters();setStatus(self,(which=="mech" and "Editing VET mechanics" or "Editing raid lead notes").." - press SAVE when done.",C.green)
end
function UI:SaveEdit(which)
 if self.editing~=which then setStatus(self,"Press EDIT on that section first.",C.red)return end
 local e=(which=="mech") and self.mechEdit or self.noteEdit
 if which=="mech" then
  MTM.SV.customText[self.selectedTrial]=MTM.SV.customText[self.selectedTrial] or {};MTM.SV.customText[self.selectedTrial][self.selectedBoss]=e:GetText()
 else
  MTM.SV.bossNotes[self.selectedTrial]=MTM.SV.bossNotes[self.selectedTrial] or {};MTM.SV.bossNotes[self.selectedTrial][self.selectedBoss]=e:GetText()
 end
 e:LoseFocus();e:SetEditEnabled(false);if e.mtmBg then e.mtmBg:SetCenterColor(.98,.98,.98,.80) end;e:SetColor(C.text[1],C.text[2],C.text[3],1);self.editing=nil;self:UpdateCounters();setStatus(self,which=="mech" and "Personal mechanics edit saved." or "Raid lead notes saved.",C.green)
end
function UI:ResetMech()
 local t=MTM.SV.customText[self.selectedTrial];if t then t[self.selectedBoss]=nil end
 self.mechEdit:LoseFocus();self.mechEdit:SetEditEnabled(false);if self.mechEdit.mtmBg then self.mechEdit.mtmBg:SetCenterColor(.98,.98,.98,.80) end;self.mechEdit:SetColor(C.text[1],C.text[2],C.text[3],1);self.editing=nil;self.mechEdit:SetText(MTM:GetDefaultText(self.selectedTrial,self.selectedBoss));self:UpdateCounters();setStatus(self,"Mechanics reset to shipped default.",C.green)
end
function UI:ResetNotes()
 local t=MTM.SV.bossNotes[self.selectedTrial];if t then t[self.selectedBoss]=nil end
 self.noteEdit:LoseFocus();self.noteEdit:SetEditEnabled(false);if self.noteEdit.mtmBg then self.noteEdit.mtmBg:SetCenterColor(.98,.98,.98,.80) end;self.noteEdit:SetColor(C.text[1],C.text[2],C.text[3],1);self.editing=nil;self.noteEdit:SetText(NOTE_HINT);self:UpdateCounters();setStatus(self,"Raid lead notes reset to shipped default.",C.green)
end
function UI:LoadChat(text)
 if GetGroupSize()==0 then setStatus(self,"You are not in a group.",C.red)return end
 local full=compactForChat(text)
 if #full>CHAT_MAX then setStatus(self,"Message is over the 350 character chat limit.",C.red)return end
 StartChatInput(full,CHAT_CHANNEL_PARTY);setStatus(self,"Loaded ONE group message - press Enter to send.",C.green)
end
function UI:SendMechs() if not self.selectedBoss then return end self:LoadChat(self.mechEdit:GetText()) end
function UI:SendNotes()
 if not self.selectedBoss then return end
 local note=self:GetNote(self.selectedTrial,self.selectedBoss)
 if not note or note=="" then setStatus(self,"No raid lead notes saved for this boss.",C.red)return end
 self:LoadChat(note)
end
function UI:Toggle()
 if self.panelOpen then self.panelOpen=false;if self.hudFragment then if HUD_SCENE then HUD_SCENE:RemoveFragment(self.hudFragment)end;if HUD_UI_SCENE then HUD_UI_SCENE:RemoveFragment(self.hudFragment)end end;self.window:SetHidden(true);SCENE_MANAGER:SetInUIMode(false);return end
 if not self.window then self:Create()end;self.panelOpen=true;self.window:SetDrawTier(DT_HIGH);self.window:SetDrawLayer(DL_OVERLAY);SCENE_MANAGER:SetInUIMode(true);if self.hudFragment then if HUD_SCENE then HUD_SCENE:AddFragment(self.hudFragment)end;if HUD_UI_SCENE then HUD_UI_SCENE:AddFragment(self.hudFragment)end else self.window:SetHidden(false)end
end
SLASH_COMMANDS["/mtm"]=function()UI:Toggle()end
SLASH_COMMANDS["/midtrialmechs"]=SLASH_COMMANDS["/mtm"]
