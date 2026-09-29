local CAM = CraftPawns
CAM.UI = { rows={}, selectedId=nil, rounds=3, researchExpanded=false, showHidden=false, timerRows={} }
local UI, WM = CAM.UI, WINDOW_MANAGER

-- Same Plum + Silver visual language as Chill Guild Tools.
local P = {
 body={37/255,31/255,43/255,1}, header={59/255,48/255,66/255,1}, field={25/255,21/255,31/255,1},
 button={45/255,37/255,51/255,1}, hover={73/255,58/255,82/255,1}, border={165/255,156/255,174/255,1},
 divider={117/255,108/255,124/255,1}, accent={205/255,177/255,229/255,1}, accentHover={233/255,211/255,250/255,1},
 text={244/255,240/255,248/255,1}, good={154/255,213/255,170/255,1}, warn={238/255,196/255,115/255,1},
}
local function color(c,m,r) c[m](c,unpack(P[r])) end
local function label(parent,text,font,a,rel,ra,x,y)
 local c=WM:CreateControl(nil,parent,CT_LABEL); c:SetFont(font or "ZoFontGame"); c:SetText(text or ""); color(c,"SetColor","text")
 c:SetAnchor(a or TOPLEFT,rel or parent,ra or TOPLEFT,x or 0,y or 0); return c
end
local function backdrop(parent,role,edge)
 local b=WM:CreateControl(nil,parent,CT_BACKDROP); b:SetAnchorFill(parent); color(b,"SetCenterColor",role or "field"); b:SetEdgeTexture(nil,1,1,0)
 if edge then color(b,"SetEdgeColor",edge) else b:SetEdgeColor(0,0,0,0) end; b:SetDrawLayer(DL_BACKGROUND); return b
end
local function button(parent,text,w,h,callback,primary)
 local b=WM:CreateControl(nil,parent,CT_BUTTON); b:SetDimensions(w or 100,h or 26); b:SetText(text); b:SetFont("ZoFontGameBold")
 color(b,"SetNormalFontColor","text"); color(b,"SetMouseOverFontColor","accentHover"); color(b,"SetPressedFontColor","accent")
 local f=backdrop(b,primary and "header" or "button",primary and "accent" or "border")
 local u=WM:CreateControl(nil,b,CT_BACKDROP); u:SetAnchor(BOTTOMLEFT,b,BOTTOMLEFT,7,0); u:SetAnchor(BOTTOMRIGHT,b,BOTTOMRIGHT,-7,0); u:SetHeight(primary and 3 or 2); color(u,"SetCenterColor","accent"); u:SetEdgeColor(0,0,0,0)
 b:SetHandler("OnMouseEnter",function() color(f,"SetCenterColor","hover"); color(u,"SetCenterColor","accentHover") end)
 b:SetHandler("OnMouseExit",function() color(f,"SetCenterColor",primary and "header" or "button"); color(u,"SetCenterColor","accent") end)
 b:SetHandler("OnClicked",callback); return b
end
local function section(parent,title,x,y,w,h)
 local c=WM:CreateControl(nil,parent,CT_CONTROL); c:SetDimensions(w,h); c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y); backdrop(c,"field","divider")
 local t=label(c,title,"ZoFontGameBold",TOPLEFT,c,TOPLEFT,10,7); color(t,"SetColor","accent")
 local line=WM:CreateControl(nil,c,CT_BACKDROP); line:SetAnchor(TOPLEFT,c,TOPLEFT,10,29); line:SetAnchor(TOPRIGHT,c,TOPRIGHT,-10,29); line:SetHeight(1); color(line,"SetCenterColor","divider"); line:SetEdgeColor(0,0,0,0); return c
end

function UI:ComposeAuthorMail(kind)
 if CAM.MailTransfer and CAM.MailTransfer:HasQueuedAttachments() then CAM:Notify("Send or clear the current mail attachments first.",true); return end
 if type(MAIL_SEND)~="table" or type(MAIL_SEND.ComposeMailTo)~="function" then CAM:Notify("ESO's mail composer is unavailable.",true); return end
 local request=kind=="request"
 local subject=request and "CraftPawns feature request" or "CraftPawns donation"
 local body=request and "Feature request:\n\nWhat would you like CraftPawns to do?\n\n" or "Thank you for supporting CraftPawns!"
 MAIL_SEND:ComposeMailTo(CAM.authorAccount)
 if type(MAIL_SEND.SetReply)=="function" then MAIL_SEND:SetReply(CAM.authorAccount,subject,body) end
end

function UI:Initialize()
 self.rounds=CAM.sv.settings.defaultRounds or 3
 local w=WM:CreateTopLevelWindow("CraftPawnsWindow"); self.window=w
 w:SetDimensions(980,700); w:SetAnchor(CENTER,GuiRoot,CENTER); w:SetMovable(true); w:SetMouseEnabled(true); w:SetClampedToScreen(true); w:SetHidden(true); w:SetScale(CAM.sv.settings.uiScale or 1); backdrop(w,"body","border")
 local head=WM:CreateControl(nil,w,CT_CONTROL); head:SetAnchor(TOPLEFT,w,TOPLEFT,12,8); head:SetAnchor(TOPRIGHT,w,TOPRIGHT,-12,8); head:SetHeight(64); backdrop(head,"header")
 label(head,"CRAFTPAWNS","ZoFontWinH1",TOPLEFT,head,TOPLEFT,18,12); local sub=label(head,"Crafting-alt readiness","ZoFontGameSmall",TOPLEFT,head,TOPLEFT,20,43); color(sub,"SetColor","accent")
 local close=button(head,"X",34,30,function() w:SetHidden(true); if self.knowledgePopup then self.knowledgePopup:SetHidden(true) end; if self.queuePopup then self.queuePopup:SetHidden(true) end; if self.timerPopup then self.timerPopup:SetHidden(true) end end); close:SetAnchor(TOPRIGHT,head,TOPRIGHT,-8,8)
 local donate=button(head,"Donate",64,30,function() self:ComposeAuthorMail("donate") end); donate:SetAnchor(RIGHT,close,LEFT,-6,0)
 local request=button(head,"Feature Request",112,30,function() self:ComposeAuthorMail("request") end); request:SetAnchor(RIGHT,donate,LEFT,-6,0)
 self.timerButton=button(head,"Research Timers",132,30,function() self:ShowResearchTimers() end); self.timerButton:SetAnchor(RIGHT,request,LEFT,-6,0)
 local accent=WM:CreateControl(nil,w,CT_BACKDROP); accent:SetAnchor(TOPLEFT,w,TOPLEFT,12,72); accent:SetAnchor(TOPRIGHT,w,TOPRIGHT,-12,72); accent:SetHeight(2); color(accent,"SetCenterColor","divider"); accent:SetEdgeColor(0,0,0,0)

 local left=section(w,"CHARACTERS",18,86,330,596); self.list=left; self.characterCount=label(left,"","ZoFontGameSmall",TOPRIGHT,left,TOPRIGHT,-10,8)
 self.listScroll=WM:CreateControlFromVirtual("CraftPawnsCharacterScroll",left,"ZO_ScrollContainer"); self.listScroll:SetAnchor(TOPLEFT,left,TOPLEFT,8,37); self.listScroll:SetAnchor(BOTTOMRIGHT,left,BOTTOMRIGHT,-8,-42); self.listScroll:SetMouseEnabled(true)
 self.listRows=self.listScroll:GetNamedChild("ScrollChild"); self.listRows:SetWidth(294)
 self.moveUp=button(left,"Move Up",92,24,function() if self.selectedId then CAM.SavedData:Move(self.selectedId,-1); self:Refresh() end end); self.moveUp:SetAnchor(BOTTOMLEFT,left,BOTTOMLEFT,10,-9)
 self.moveDown=button(left,"Move Down",102,24,function() if self.selectedId then CAM.SavedData:Move(self.selectedId,1); self:Refresh() end end); self.moveDown:SetAnchor(LEFT,self.moveUp,RIGHT,6,0)
 self.showHiddenButton=button(left,"Hidden (0)",108,24,function() self.showHidden=not self.showHidden; self:Refresh() end); self.showHiddenButton:SetAnchor(LEFT,self.moveDown,RIGHT,6,0)

 self.main=WM:CreateControl(nil,w,CT_CONTROL); self.main:SetDimensions(604,596); self.main:SetAnchor(TOPLEFT,w,TOPLEFT,360,86)
 self.nameLabel=label(self.main,"Select a character","ZoFontWinH2",TOPLEFT,self.main,TOPLEFT,0,0); self.scanLabel=label(self.main,"","ZoFontGameSmall",TOPRIGHT,self.main,TOPRIGHT,0,8); color(self.scanLabel,"SetColor","accent")
 self.action=WM:CreateControl(nil,self.main,CT_CONTROL); self.action:SetDimensions(604,54); self.action:SetAnchor(TOPLEFT,self.main,TOPLEFT,0,38); backdrop(self.action,"header","accent")
 local cap=label(self.action,"NEXT","ZoFontGameSmall",TOPLEFT,self.action,TOPLEFT,12,7); color(cap,"SetColor","accent"); self.actionText=label(self.action,"Select a character","ZoFontGameBold",TOPLEFT,self.action,TOPLEFT,12,25); self.actionText:SetDimensions(420,22); self.actionText:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
 self.craftBox=section(self.main,"CRAFT LEVELS",0,103,294,198); self.craftText=label(self.craftBox,"","ZoFontGameSmall",TOPLEFT,self.craftBox,TOPLEFT,10,38); self.craftText:SetDimensions(274,150)
 self.knowledgeBox=section(self.main,"KNOWLEDGE",310,103,294,198); self.knowledgeText=label(self.knowledgeBox,"","ZoFontGameSmall",TOPLEFT,self.knowledgeBox,TOPLEFT,10,38); self.knowledgeText:SetDimensions(230,154)
 self.runeListButton=button(self.knowledgeBox,"List",38,19,function() self:ShowMissingKnowledge("runes") end); self.runeListButton:SetFont("ZoFontGameSmall"); self.runeListButton:SetAnchor(TOPRIGHT,self.knowledgeBox,TOPRIGHT,-9,57)
 self.alchemyListButton=button(self.knowledgeBox,"List",38,19,function() self:ShowMissingKnowledge("alchemy") end); self.alchemyListButton:SetFont("ZoFontGameSmall"); self.alchemyListButton:SetAnchor(TOPRIGHT,self.knowledgeBox,TOPRIGHT,-9,81)
 self.skillBox=section(self.main,"PERFECT WRIT ALT",0,313,604,122); self.skillText=label(self.skillBox,"","ZoFontGame",TOPLEFT,self.skillBox,TOPLEFT,10,39); self.skillText:SetDimensions(438,72)
 self.allocateButton=button(self.skillBox,"Apply Passives",138,27,function() self:ConfirmAllocation() end,true); self.allocateButton:SetAnchor(RIGHT,self.skillBox,RIGHT,-10,12)
 self.researchToggle=button(self.main,"Research Prep",128,26,function() self.researchExpanded=not self.researchExpanded; self:RefreshResearchPanel() end); self.researchToggle:SetAnchor(TOPLEFT,self.main,TOPLEFT,0,449)
 self.rescan=button(self.main,"Rescan",90,26,function() self:RescanSelected() end); self.rescan:SetAnchor(TOPRIGHT,self.main,TOPRIGHT,0,449)
 self.mailButton=button(self.main,"Mail Research",116,26,function() if self.selectedId then CAM.MailTransfer:Prepare(self.selectedId) end end,true); self.mailButton:SetAnchor(RIGHT,self.rescan,LEFT,-8,0)
 self.writMailButton=button(self.main,"Mail Decon Rewards",148,26,function() if self.selectedId then CAM.MailTransfer:QueueWritMail(self.selectedId) end end); self.writMailButton:SetAnchor(RIGHT,self.mailButton,LEFT,-8,0)
 self.hideButton=button(self.main,"Hide",72,26,function() self:ToggleSelectedHidden() end); self.hideButton:SetAnchor(RIGHT,self.writMailButton,LEFT,-8,0)
 self.researchPanel=WM:CreateControl(nil,self.main,CT_CONTROL); self.researchPanel:SetDimensions(604,112); self.researchPanel:SetAnchor(TOPLEFT,self.main,TOPLEFT,0,484); backdrop(self.researchPanel,"field","divider")
 self.daysLabel=label(self.researchPanel,"Rounds:","ZoFontGameBold",TOPLEFT,self.researchPanel,TOPLEFT,10,11); local last=self.daysLabel
 for _,rounds in ipairs(CAM.sv.settings.quickRounds or {1,2,3,5,10}) do local n=rounds; local b=button(self.researchPanel,tostring(rounds),38,23,function() self.rounds=n; self:BuildSelectedPlan() end); b:SetAnchor(LEFT,last,RIGHT,6,0); last=b end
 self.planSummary=label(self.researchPanel,"","ZoFontGameSmall",TOPLEFT,self.researchPanel,TOPLEFT,10,48); self.planSummary:SetDimensions(430,64)
 self.buildPlan=button(self.researchPanel,"Recalculate",104,25,function() self:BuildSelectedPlan() end); self.buildPlan:SetAnchor(TOPRIGHT,self.researchPanel,TOPRIGHT,-10,10)
 self.queueButton=button(self.researchPanel,"Queue Items",104,25,function() self:QueueSelectedPlan() end,true); self.queueButton:SetAnchor(TOPRIGHT,self.researchPanel,TOPRIGHT,-10,44)
 self.viewQueueButton=button(self.researchPanel,"View Queue",104,25,function() self:ShowQueue() end); self.viewQueueButton:SetAnchor(TOPRIGHT,self.researchPanel,TOPRIGHT,-124,44)
 self:CreateKnowledgePopup()
 self:CreateQueuePopup()
 self:CreateResearchTimerPopup()
 self:RefreshResearchPanel(); self:Refresh()
end

local TIMER_CRAFT_NAMES={
 [CRAFTING_TYPE_BLACKSMITHING]="Blacksmithing", [CRAFTING_TYPE_CLOTHIER]="Clothing",
 [CRAFTING_TYPE_WOODWORKING]="Woodworking", [CRAFTING_TYPE_JEWELRYCRAFTING]="Jewelry",
}

local function remainingForResearch(research,snapshot,now)
 local endsAt=tonumber(research and research.endsAt)
 if endsAt then return math.max(0,endsAt-now) end
 local remaining=tonumber(research and research.remaining) or 0
 local scannedAt=tonumber(snapshot and snapshot.scannedAt) or now
 return math.max(0,remaining-math.max(0,now-scannedAt))
end

local function formatResearchTime(seconds)
 seconds=math.max(0,math.floor(tonumber(seconds) or 0))
 local days=math.floor(seconds/86400); seconds=seconds-(days*86400)
 local hours=math.floor(seconds/3600); seconds=seconds-(hours*3600)
 local minutes=math.floor(seconds/60)
 if days>0 then return string.format("%dd %dh",days,hours) end
 if hours>0 then return string.format("%dh %dm",hours,minutes) end
 return string.format("%dm",minutes)
end

function UI:GetResearchTimerData()
 local now=GetTimeStamp(); local characters={}; local longCategories=0; local activeTotal=0
 for _,id in ipairs((CAM.server and CAM.server.order) or {}) do
  local record=CAM.server.characters[id]; local snapshot=record and record.snapshot
  if snapshot then
   local crafts={}
   for _,craftType in ipairs(CAM.RESEARCH_CRAFTS) do
    local active={}; local allOverDay=true
    for _,line in ipairs((snapshot.research[craftType] and snapshot.research[craftType].lines) or {}) do
     if line.currentResearch then
      local remaining=remainingForResearch(line.currentResearch,snapshot,now)
      if remaining>0 then
       active[#active+1]={name=line.currentResearch.name or line.name or "Research",remaining=remaining}
       activeTotal=activeTotal+1
       if remaining<=86400 then allOverDay=false end
      end
     end
    end
    if #active>0 then
     table.sort(active,function(a,b) return a.remaining<b.remaining end)
     local scrollReady=allOverDay and (not CAM.ResearchScrolls or not CAM.ResearchScrolls:IsClaimedToday(id,craftType,now))
     if scrollReady then longCategories=longCategories+1 end
     crafts[#crafts+1]={name=TIMER_CRAFT_NAMES[craftType] or tostring(craftType),active=active,allOverDay=allOverDay,scrollReady=scrollReady}
    end
   end
   if #crafts>0 then characters[#characters+1]={name=record.currentName or snapshot.name or "Unknown",account=record.account or snapshot.account or "Unknown account",crafts=crafts} end
  end
 end
 return characters,longCategories,activeTotal
end

function UI:CreateResearchTimerPopup()
 local p=WM:CreateTopLevelWindow("CraftPawnsResearchTimerPopup"); self.timerPopup=p
 p:SetDimensions(650,570); p:SetAnchor(CENTER,GuiRoot,CENTER,150,0); p:SetMovable(true); p:SetMouseEnabled(true); p:SetClampedToScreen(true); p:SetHidden(true); backdrop(p,"body","border")
 local h=WM:CreateControl(nil,p,CT_CONTROL); h:SetAnchor(TOPLEFT,p,TOPLEFT,8,8); h:SetAnchor(TOPRIGHT,p,TOPRIGHT,-8,8); h:SetHeight(48); backdrop(h,"header")
 self.timerPopupTitle=label(h,"RESEARCH TIMERS","ZoFontWinH3",LEFT,h,LEFT,12,0)
 local x=button(h,"X",30,27,function() p:SetHidden(true) end); x:SetAnchor(RIGHT,h,RIGHT,-8,0)
 local refresh=button(p,"Refresh",82,27,function() self:ShowResearchTimers() end); refresh:SetAnchor(BOTTOMRIGHT,p,BOTTOMRIGHT,-12,-12)
 local note=label(p,"Amber categories are ready for a one-day research scroll.","ZoFontGameSmall",BOTTOMLEFT,p,BOTTOMLEFT,14,-18); color(note,"SetColor","accent")
 local scroll=WM:CreateControlFromVirtual("CraftPawnsResearchTimerScroll",p,"ZO_ScrollContainer"); scroll:SetAnchor(TOPLEFT,p,TOPLEFT,12,66); scroll:SetAnchor(BOTTOMRIGHT,p,BOTTOMRIGHT,-12,-50); scroll:SetMouseEnabled(true); self.timerScroll=scroll
 self.timerPopupChild=scroll:GetNamedChild("ScrollChild"); self.timerPopupChild:SetWidth(600)
end

function UI:ShowResearchTimers()
 for _,control in ipairs(self.timerRows or {}) do control:SetHidden(true); control:SetParent(nil) end; self.timerRows={}
 local characters,longCategories,activeTotal=self:GetResearchTimerData(); local y=0; local lastAccount
 for _,character in ipairs(characters) do
  if character.account~=lastAccount then
   local account=label(self.timerPopupChild,character.account,"ZoFontGameBold",TOPLEFT,self.timerPopupChild,TOPLEFT,4,y); color(account,"SetColor","accent"); self.timerRows[#self.timerRows+1]=account; y=y+25; lastAccount=character.account
  end
  local name=label(self.timerPopupChild,character.name,"ZoFontWinH4",TOPLEFT,self.timerPopupChild,TOPLEFT,12,y); self.timerRows[#self.timerRows+1]=name; y=y+28
  for _,craft in ipairs(character.crafts) do
   local marker=craft.scrollReady and "  •  RESEARCH SCROLL READY" or (craft.allOverDay and "  •  SCROLL CLAIMED TODAY" or "")
   local craftLabel=label(self.timerPopupChild,craft.name..marker,"ZoFontGameBold",TOPLEFT,self.timerPopupChild,TOPLEFT,24,y); color(craftLabel,"SetColor",craft.scrollReady and "warn" or "text"); self.timerRows[#self.timerRows+1]=craftLabel; y=y+22
   for _,research in ipairs(craft.active) do
    local timer=label(self.timerPopupChild,string.format("%s  —  %s remaining",research.name,formatResearchTime(research.remaining)),"ZoFontGameSmall",TOPLEFT,self.timerPopupChild,TOPLEFT,40,y); timer:SetWidth(545); timer:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS); self.timerRows[#self.timerRows+1]=timer; y=y+20
   end
  end
  y=y+10
 end
 if #characters==0 then local empty=label(self.timerPopupChild,"No saved active research timers.","ZoFontGame",TOPLEFT,self.timerPopupChild,TOPLEFT,10,10); self.timerRows[1]=empty; y=40 end
 self.timerPopupChild:SetHeight(math.max(450,y)); self.timerPopupTitle:SetText(string.format("RESEARCH TIMERS (%d ACTIVE)",activeTotal)); if type(ZO_Scroll_ResetToTop)=="function" then ZO_Scroll_ResetToTop(self.timerScroll) end
 self.timerPopup:SetHidden(false); self.timerPopup:BringWindowToTop(); self:RefreshResearchTimerIndicator()
end

function UI:RefreshResearchTimerIndicator()
 if not self.timerButton then return end
 local _,longCategories,activeTotal=self:GetResearchTimerData()
 if longCategories>0 then self.timerButton:SetText(string.format("Scroll Ready (%d)",longCategories)); color(self.timerButton,"SetNormalFontColor","warn")
 else self.timerButton:SetText("Research Timers"); color(self.timerButton,"SetNormalFontColor","text") end
end

function UI:CreateQueuePopup()
 local p=WM:CreateTopLevelWindow("CraftPawnsQueuePopup"); self.queuePopup=p
 p:SetDimensions(640,540); p:SetAnchor(CENTER,GuiRoot,CENTER,140,0); p:SetMovable(true); p:SetMouseEnabled(true); p:SetClampedToScreen(true); p:SetHidden(true); backdrop(p,"body","border")
 local h=WM:CreateControl(nil,p,CT_CONTROL); h:SetAnchor(TOPLEFT,p,TOPLEFT,8,8); h:SetAnchor(TOPRIGHT,p,TOPRIGHT,-8,8); h:SetHeight(48); backdrop(h,"header")
 self.queuePopupTitle=label(h,"CRAFTPAWNS QUEUE","ZoFontWinH3",LEFT,h,LEFT,12,0)
 local x=button(h,"X",30,27,function() p:SetHidden(true) end); x:SetAnchor(RIGHT,h,RIGHT,-8,0)
 local clear=button(p,"Clear CraftPawns Queue",190,27,function() ZO_Dialogs_ShowDialog("CAM_CLEAR_QUEUE_CONFIRM") end,true); clear:SetAnchor(BOTTOMLEFT,p,BOTTOMLEFT,12,-12); self.clearQueueButton=clear
 local refresh=button(p,"Refresh",82,27,function() self:ShowQueue() end); refresh:SetAnchor(BOTTOMRIGHT,p,BOTTOMRIGHT,-12,-12)
 local scroll=WM:CreateControlFromVirtual("CraftPawnsQueueScroll",p,"ZO_ScrollContainer"); scroll:SetAnchor(TOPLEFT,p,TOPLEFT,12,66); scroll:SetAnchor(BOTTOMRIGHT,p,BOTTOMRIGHT,-12,-50); scroll:SetMouseEnabled(true); self.queueScroll=scroll
 local child=scroll:GetNamedChild("ScrollChild"); child:SetWidth(590); self.queuePopupChild=child; self.queueRows={}
end

local QUEUE_STATION_NAMES={
 [CRAFTING_TYPE_BLACKSMITHING]="Blacksmithing", [CRAFTING_TYPE_CLOTHIER]="Clothing",
 [CRAFTING_TYPE_WOODWORKING]="Woodworking", [CRAFTING_TYPE_JEWELRYCRAFTING]="Jewelry",
}

function UI:ShowQueue()
 local rows=CAM.LazyCrafting:GetQueueRows()
 for _,control in ipairs(self.queueRows or {}) do control:SetHidden(true); control:SetParent(nil) end; self.queueRows={}
 for index,row in ipairs(rows) do
  local entry=WM:CreateControl(nil,self.queuePopupChild,CT_CONTROL); entry:SetDimensions(582,60); entry:SetAnchor(TOPLEFT,self.queuePopupChild,TOPLEFT,0,(index-1)*62); backdrop(entry,index%2==0 and "button" or "field","divider")
  local itemName=label(entry,row.lineName,"ZoFontGameBold",TOPLEFT,entry,TOPLEFT,10,6); itemName:SetDimensions(210,18); itemName:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
  local station=label(entry,QUEUE_STATION_NAMES[row.station] or ("Station "..tostring(row.station)),"ZoFontGameSmall",TOPRIGHT,entry,TOPRIGHT,-41,7); station:SetDimensions(125,17); station:SetHorizontalAlignment(TEXT_ALIGN_RIGHT); color(station,"SetColor","accent")
  local progress=(row.knownCount and row.totalTraits and row.totalTraits>0) and string.format("%d/%d traits",row.knownCount,row.totalTraits) or "Progress unavailable"
  local detail=label(entry,string.format("%s  •  %s",progress,row.traitName),"ZoFontGameSmall",TOPLEFT,entry,TOPLEFT,10,24); detail:SetDimensions(520,17); detail:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
  local materials=label(entry,row.materialShortageText or "Materials available","ZoFontGameSmall",TOPLEFT,entry,TOPLEFT,10,41); materials:SetDimensions(520,16); materials:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS); color(materials,"SetColor",row.materialShortageText and "warn" or "good")
  local reference=row.reference
  local dismiss=button(entry,"X",28,25,function() local ok,message=CAM.LazyCrafting:CancelReference(reference); if not ok then CAM:Notify(message,true) end; self:ShowQueue() end); dismiss:SetAnchor(RIGHT,entry,RIGHT,-7,0)
  self.queueRows[#self.queueRows+1]=entry
 end
 self.queuePopupTitle:SetText(string.format("CRAFTPAWNS QUEUE (%d)",#rows))
 if #rows==0 then local empty=label(self.queuePopupChild,"No CraftPawns requests are queued.","ZoFontGame",TOPLEFT,self.queuePopupChild,TOPLEFT,10,10); self.queueRows[1]=empty end
 self.queuePopupChild:SetHeight(math.max(420,#rows*62)); if type(ZO_Scroll_ResetToTop)=="function" then ZO_Scroll_ResetToTop(self.queueScroll) end
 self.clearQueueButton:SetEnabled(#rows>0); self.queuePopup:SetHidden(false); self.queuePopup:BringWindowToTop()
end

function UI:CreateKnowledgePopup()
 local p=WM:CreateTopLevelWindow("CraftPawnsKnowledgePopup"); self.knowledgePopup=p
 p:SetDimensions(410,440); p:SetAnchor(CENTER,GuiRoot,CENTER,170,0); p:SetMovable(true); p:SetMouseEnabled(true); p:SetClampedToScreen(true); p:SetHidden(true); backdrop(p,"body","border")
 local h=WM:CreateControl(nil,p,CT_CONTROL); h:SetAnchor(TOPLEFT,p,TOPLEFT,8,8); h:SetAnchor(TOPRIGHT,p,TOPRIGHT,-8,8); h:SetHeight(48); backdrop(h,"header")
 self.knowledgePopupTitle=label(h,"MISSING KNOWLEDGE","ZoFontWinH3",LEFT,h,LEFT,12,0)
 local x=button(h,"X",30,27,function() p:SetHidden(true) end); x:SetAnchor(RIGHT,h,RIGHT,-8,0)
 local scroll=WM:CreateControlFromVirtual("CraftPawnsKnowledgeScroll",p,"ZO_ScrollContainer"); scroll:SetAnchor(TOPLEFT,p,TOPLEFT,12,66); scroll:SetAnchor(BOTTOMRIGHT,p,BOTTOMRIGHT,-12,-12)
 local child=scroll:GetNamedChild("ScrollChild"); self.knowledgePopupChild=child
 self.knowledgePopupText=label(child,"","ZoFontGame",TOPLEFT,child,TOPLEFT,4,2); self.knowledgePopupText:SetWidth(354)
end

function UI:ShowMissingKnowledge(kind)
 local record=self.selectedId and CAM.server.characters[self.selectedId]
 local snapshot=record and record.snapshot
 if not snapshot then return end
 local source=kind=="runes" and snapshot.runes or snapshot.alchemy
 local names={}
 for _,entry in ipairs(source and source.unknown or {}) do
  if entry.name and entry.name~="" then names[#names+1]=entry.name end
 end
 table.sort(names,function(a,b) return string.lower(a)<string.lower(b) end)
 local title=kind=="runes" and "MISSING RUNES" or "INCOMPLETE REAGENTS"
 self.knowledgePopupTitle:SetText(string.format("%s (%d)",title,#names))
 self.knowledgePopupText:SetText(#names>0 and table.concat(names,"\n") or "None")
 local height=math.max(350,#names*24+8); self.knowledgePopupText:SetHeight(height); self.knowledgePopupChild:SetHeight(height)
 self.knowledgePopup:SetHidden(false); self.knowledgePopup:BringWindowToTop()
end

function UI:Toggle()
 local opening=self.window:IsHidden()
 self.window:SetHidden(not opening)
 if opening then
  if not self.openedThisSession then
   local currentId=tostring(GetCurrentCharacterId())
   if CAM.server and CAM.server.characters and CAM.server.characters[currentId] then self.selectedId=currentId end
   self.openedThisSession=true
  end
  self:Refresh()
 end
end
function UI:ClearRows() for _,r in ipairs(self.rows) do r:SetHidden(true); r:SetParent(nil) end self.rows={} end
function UI:GetNextAction(s)
 for _,c in ipairs(CAM.CRAFTS) do local v=s.crafts[c.type]; if v and v.rank<v.maxRank then return c.name.." needs "..(v.maxRank-v.rank).." levels","warn" end end
 local rd=CAM.SkillPreset:GetReadiness(s)
 if rd.pointsNeeded>0 then return "Get "..rd.pointsNeeded.." skill points","warn" end
 if rd.missing>0 then if rd.canFill then return "Allocate "..rd.missing.." required crafting passives","warn" end return "Free or earn "..rd.shortfall.." spendable points","warn" end
 if not s.runes.valid then return s.runes.cataloging and "Building knowledge catalogue" or "Rune knowledge unavailable","warn" end
 if #(s.runes.unknown or {})>0 then return #(s.runes.unknown).." rune definitions remain","warn" end
 if not s.alchemy.valid then return s.alchemy.cataloging and "Building knowledge catalogue" or "Alchemy knowledge unavailable","warn" end
 if #(s.alchemy.unknown or {})>0 then return #(s.alchemy.unknown).." Alchemy effects remain","warn" end
 for _,ct in ipairs(CAM.RESEARCH_CRAFTS) do if not CAM.ResearchPlanner:IsComplete(s.research[ct]) then return "Continue trait research","warn" end end
 return "Writ ready","good"
end
function UI:RowStatus(r)
 if not r.snapshot then return "Needs scan","warn" end
 local s=r.snapshot
 for _,c in ipairs(CAM.CRAFTS) do local v=s.crafts[c.type]; if v and v.rank<v.maxRank then return "Craft "..v.rank.."/"..v.maxRank,"warn" end end
 local rd=CAM.SkillPreset:GetReadiness(s)
 if rd.pointsNeeded>0 then return "Get "..rd.pointsNeeded.." SP","warn" end
 if rd.missing>0 then return rd.canFill and ("Allocate "..rd.missing) or "Needs respec","warn" end
 if not s.runes.valid or not s.alchemy.valid then return (s.runes.cataloging or s.alchemy.cataloging) and "Cataloging knowledge" or "Knowledge unavailable","warn" end
 if #(s.runes.unknown or {})>0 or #(s.alchemy.unknown or {})>0 then return "Runes / Alchemy","warn" end
 for _,ct in ipairs(CAM.RESEARCH_CRAFTS) do if not CAM.ResearchPlanner:IsComplete(s.research[ct]) then return "Research","warn" end end
 return "Ready","good"
end

function UI:Refresh()
 if not self.window then return end; self:ClearRows(); local y,hiddenCount,totalCount=0,0,0
 for _,id in ipairs(CAM.server.order) do local r=CAM.server.characters[id]; if r then totalCount=totalCount+1; if r.hidden then hiddenCount=hiddenCount+1 end end end
 if hiddenCount==0 then self.showHidden=false end
 self.characterCount:SetText(tostring(totalCount).." characters"); self.showHiddenButton:SetText(self.showHidden and "Hide Hidden" or ("Hidden ("..hiddenCount..")")); self.showHiddenButton:SetEnabled(hiddenCount>0)
 local currentAccount=GetDisplayName and GetDisplayName() or "UnknownAccount"; local groups,accountOrder={},{}
 for _,id in ipairs(CAM.server.order) do local r=CAM.server.characters[id]; if r and (self.showHidden or not r.hidden) then local account=r.account or (r.snapshot and r.snapshot.account) or "Unknown account"; if not groups[account] then groups[account]={}; accountOrder[#accountOrder+1]=account end; groups[account][#groups[account]+1]={id=id,record=r} end end
 table.sort(accountOrder,function(a,b) if a==currentAccount then return true elseif b==currentAccount then return false else return string.lower(a)<string.lower(b) end end)
 for _,account in ipairs(accountOrder) do
  local header=WM:CreateControl(nil,self.listRows,CT_CONTROL); header:SetDimensions(294,22); header:SetAnchor(TOPLEFT,self.listRows,TOPLEFT,0,y); backdrop(header,"header")
  local accountLabel=label(header,account,"ZoFontGameSmall",LEFT,header,LEFT,7,0); color(accountLabel,"SetColor","accent"); self.rows[#self.rows+1]=header; y=y+23
  for _,entry in ipairs(groups[account]) do local id,r=entry.id,entry.record
  local row=WM:CreateControl(nil,self.listRows,CT_BUTTON); row:SetDimensions(294,25); row:SetAnchor(TOPLEFT,self.listRows,TOPLEFT,0,y)
  local bg=backdrop(row,id==self.selectedId and "hover" or "button"); bg:SetEdgeColor(0,0,0,0)
  local name=label(row,r.currentName,"ZoFontGameBold",LEFT,row,LEFT,8,0); name:SetDimensions(166,24); name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
  local status,role; if r.hidden then status,role="Hidden","accent" else status,role=self:RowStatus(r) end
  local st=label(row,status,"ZoFontGameSmall",RIGHT,row,RIGHT,-7,0); st:SetDimensions(112,23); st:SetHorizontalAlignment(TEXT_ALIGN_RIGHT); color(st,"SetColor",role)
  row:SetHandler("OnMouseEnter",function() color(bg,"SetCenterColor","hover") end); row:SetHandler("OnMouseExit",function() color(bg,"SetCenterColor",id==self.selectedId and "hover" or "button") end)
  row:SetHandler("OnClicked",function() self.selectedId=id; self:Refresh() end); self.rows[#self.rows+1]=row; y=y+26
 end end
 self.listRows:SetHeight(math.max(500,y))
 local selected=self.selectedId and CAM.server.characters[self.selectedId]; if selected and selected.hidden and not self.showHidden then self.selectedId=nil end
 if not self.selectedId then local currentId=tostring(GetCurrentCharacterId()); local current=CAM.server.characters[currentId]; if current and (self.showHidden or not current.hidden) then self.selectedId=currentId else for _,id in ipairs(CAM.server.order) do local r=CAM.server.characters[id]; if r and (self.showHidden or not r.hidden) then self.selectedId=id; break end end end end
 self:RefreshDetail(); self:RefreshResearchTimerIndicator()
end

function UI:RefreshDetail()
 local r=self.selectedId and CAM.server.characters[self.selectedId]; if not r then self.nameLabel:SetText("No visible characters"); self.mailButton:SetHidden(true); self.writMailButton:SetHidden(true); self.hideButton:SetHidden(true); return end; self.nameLabel:SetText(r.currentName)
 local currentAccount=GetDisplayName and GetDisplayName() or ""; local otherAccount=r.account and r.account~=currentAccount
 self.rescan:ClearAnchors(); self.rescan:SetAnchor(TOPRIGHT,self.main,TOPRIGHT,0,449)
 self.mailButton:ClearAnchors(); self.writMailButton:ClearAnchors(); self.hideButton:ClearAnchors()
 self.mailButton:SetHidden(not otherAccount); self.writMailButton:SetHidden(not otherAccount)
 if otherAccount then
  self.mailButton:SetAnchor(RIGHT,self.rescan,LEFT,-8,0)
  self.writMailButton:SetAnchor(RIGHT,self.mailButton,LEFT,-8,0)
  self.hideButton:SetAnchor(RIGHT,self.writMailButton,LEFT,-8,0)
 else
  self.hideButton:SetAnchor(RIGHT,self.rescan,LEFT,-8,0)
 end
 self.hideButton:SetHidden(false); self.hideButton:SetText(r.hidden and "Unhide" or "Hide")
 if not r.snapshot then self.scanLabel:SetText("Never scanned"); self.actionText:SetText("Log into this character once"); self.craftText:SetText("No saved crafting data."); self.knowledgeText:SetText("No saved knowledge data."); self.runeListButton:SetHidden(true); self.alchemyListButton:SetHidden(true); self.skillText:SetText("No saved skill data."); self:RefreshResearchPanel(); return end
 local s=r.snapshot; self.scanLabel:SetText("Scanned "..(GetDateStringFromTimestamp and GetDateStringFromTimestamp(r.lastScan) or tostring(r.lastScan)))
 local action,role=self:GetNextAction(s); self.actionText:SetText(action); color(self.actionText,"SetColor",role)
 local crafts={}; for _,c in ipairs(CAM.CRAFTS) do local v=s.crafts[c.type]; crafts[#crafts+1]=string.format("%s: %d / %d",c.name,v.rank,v.maxRank) end; self.craftText:SetText(table.concat(crafts,"\n"))
 local rm=#(s.runes.unknown or {}); local am=#(s.alchemy.unknown or {}); local known,total=0,0
 for _,rr in pairs(s.research or {}) do for _,ln in ipairs(rr.lines or {}) do known=known+(ln.knownCount or 0); total=total+#(ln.traits or {}) end end
 local runeText=not s.runes.valid and (s.runes.cataloging and "Building catalogue..." or "Unavailable") or (rm==0 and "Complete" or rm.." definitions missing")
 local alchText=not s.alchemy.valid and (s.alchemy.cataloging and "Building catalogue..." or "Unavailable") or (am==0 and "Complete" or am.." reagents incomplete")
 self.runeListButton:SetHidden(not s.runes.valid or rm==0); self.alchemyListButton:SetHidden(not s.alchemy.valid or am==0)
 local motifText
 if not s.motifs or not s.motifs.valid then motifText="Needs scan" else motifText=(s.motifs.knownSets or 0).." full sets" end
 local recipeText
 if not s.provisioningRecipes or not s.provisioningRecipes.valid then recipeText="Needs scan" else recipeText=string.format("%d / %d known",s.provisioningRecipes.known or 0,s.provisioningRecipes.total or 0) end
 self.knowledgeText:SetText(table.concat({"Research  "..known.." / "..total,"Runes  "..runeText,"Alchemy  "..alchText,"Recipes  "..recipeText,"Motifs  "..motifText,"","Motifs are knowledge only."},"\n"))
 local rd=CAM.SkillPreset:GetReadiness(s); local state
 if rd.pointsNeeded>0 then state="Get "..rd.pointsNeeded.." more skill points"
 elseif rd.missing==0 then state="Required passives complete"
 elseif rd.canFill then state="Can allocate all missing passives now"
 else state="Enough total points; needs available points or a respec" end
 self.skillText:SetText(string.format("Acquired: %d / %d%s\nCorrectly Allocated: %d / %d\n%s",rd.acquired,rd.target,rd.researchComplete and " (research complete)" or "",rd.correctlyAllocated,rd.target,state)); self:RefreshResearchPanel()
end

function UI:ToggleSelectedHidden()
 local record=self.selectedId and CAM.server.characters[self.selectedId]
 if not record then return end
 record.hidden=not record.hidden
 if record.hidden and not self.showHidden then self.selectedId=nil end
 self:Refresh()
end

function UI:RescanSelected()
 local currentId=tostring(GetCurrentCharacterId())
 if self.selectedId~=currentId then
  self.scanLabel:SetText("Log into this character to rescan")
  CAM:Notify("Only the currently logged-in character can be rescanned.",true)
  return
 end
 self.scanLabel:SetText("Rescanning...")
 zo_callLater(function()
  local ok,message=CAM.Scanner:ScanAndCommit()
  if ok then CAM:Notify("Scan complete.") else self.scanLabel:SetText("Scan failed"); CAM:Notify("Scan failed: "..tostring(message),true) end
 end,250)
end

function UI:ConfirmAllocation()
 if self.selectedId~=tostring(GetCurrentCharacterId()) then CAM:Notify("Log into this character before allocating passives.",true); return end
 local r=CAM.server.characters[self.selectedId]; if not r or not r.snapshot then return end
 local rd=CAM.SkillPreset:GetReadiness(r.snapshot)
 if rd.missing==0 then CAM:Notify("All required passives are already allocated."); return end
 ZO_Dialogs_ShowDialog("CAM_ALLOCATE_CONFIRM",nil,{mainTextParams={rd.missing}})
end

function UI:RefreshResearchPanel()
 if not self.researchPanel then return end; self.researchPanel:SetHidden(not self.researchExpanded); self.researchToggle:SetText(self.researchExpanded and "Research Prep -" or "Research Prep +"); if not self.researchExpanded then return end
 local plan=self.selectedId and CAM.server.plans[self.selectedId]; if not plan or plan.rounds~=self.rounds then self.planSummary:SetText("Choose how many research rounds to prepare."); return end
 local counts={ [CRAFTING_TYPE_BLACKSMITHING]=0,[CRAFTING_TYPE_CLOTHIER]=0,[CRAFTING_TYPE_WOODWORKING]=0,[CRAFTING_TYPE_JEWELRYCRAFTING]=0 }
 for _,item in ipairs(CAM.LazyCrafting:GetBatchItems(self.selectedId,plan)) do counts[item.craftType]=(counts[item.craftType] or 0)+1 end
 local total=counts[CRAFTING_TYPE_BLACKSMITHING]+counts[CRAFTING_TYPE_CLOTHIER]+counts[CRAFTING_TYPE_WOODWORKING]+counts[CRAFTING_TYPE_JEWELRYCRAFTING]
 self.planSummary:SetText(string.format("%d rounds: BS %d  •  Clothing %d  •  Wood %d  •  Jewelry %d\n%d planned  •  %d new requests",self.rounds,counts[CRAFTING_TYPE_BLACKSMITHING],counts[CRAFTING_TYPE_CLOTHIER],counts[CRAFTING_TYPE_WOODWORKING],counts[CRAFTING_TYPE_JEWELRYCRAFTING],total,CAM.LazyCrafting:CountQueueBatch(plan,self.selectedId)))
end
function UI:BuildSelectedPlan() local r=self.selectedId and CAM.server.characters[self.selectedId]; if not r or not r.snapshot then CAM:Notify("Character needs an initial scan.",true); return end; CAM.server.plans[self.selectedId]={characterId=self.selectedId,rounds=self.rounds,generatedAt=GetTimeStamp()}; self:RefreshResearchPanel() end
function UI:QueueSelectedPlan()
 local p=CAM.server.plans[self.selectedId]
 if not p or p.rounds~=self.rounds then self:BuildSelectedPlan(); p=CAM.server.plans[self.selectedId] end
 if not p then return end
 local ok,q,f=pcall(CAM.LazyCrafting.QueuePlan,CAM.LazyCrafting,self.selectedId,p)
 if not ok then CAM:Notify("Queue failed: "..tostring(q),true); return end
 CAM:Notify(string.format("%d queued%s.",q,#f>0 and string.format("; %d unavailable",#f) or ""),#f>0)
 CAM.LazyCrafting:ReportQueueShortages()
 self:RefreshResearchPanel()
end

ZO_Dialogs_RegisterCustomDialog("CAM_ALLOCATE_CONFIRM",{title={text="Allocate Craft Passives"},mainText={text="Spend up to <<1>> skill points on the missing required crafting passives? No skills will be refunded."},buttons={{text=SI_DIALOG_CONFIRM,callback=function() local _,message=CAM.SkillPreset:AllocateMissing(); CAM:Notify(message); zo_callLater(function() CAM.Scanner:ScanAndCommit() end,500) end},{text=SI_DIALOG_CANCEL}}})

ZO_Dialogs_RegisterCustomDialog("CAM_CLEAR_QUEUE_CONFIRM",{title={text="Clear CraftPawns Queue"},mainText={text="Remove all pending CraftPawns requests from LibLazyCrafting? Requests from other addons will not be changed."},buttons={{text=SI_DIALOG_CONFIRM,callback=function() local n,message=CAM.LazyCrafting:ClearQueue(); CAM:Notify(message or string.format("Cleared %d queued requests.",n),message~=nil); UI:ShowQueue() end},{text=SI_DIALOG_CANCEL}}})
