local M=TGWBI
local ui,keys,summary,heading,footer,labels,cards
local PAGE=8
local function Options()
 return {
 {name="Automatic binding",detail="Newly received missing set pieces only.",value=M.db.autoBind and "ON" or "OFF",run=function()M.SetAutoBind(not M.db.autoBind)end},
 {name="Whisper invites",detail="Invite players who whisper your keyword.",value=M.db.autoInvite and "ON" or "OFF",run=function()M.db.autoInvite=not M.db.autoInvite;M.pending={};M.Note("Whisper invites "..(M.db.autoInvite and "enabled." or "disabled."))end},
 {name="Whisper keyword",detail="Custom word: /bi keyword yourword",value=M.db.keyword,run=function()local choices={"invite","dungeon","trial","tax"};local n=1;for i,v in ipairs(choices)do if M.db.keyword==v then n=i%#choices+1 end end;M.db.keyword=choices[n]end},
 {name="Group limit",detail="Maximum party size, including pending invites.",value=tostring(M.db.groupLimit),run=function()M.db.groupLimit=M.db.groupLimit==4 and 12 or 4 end},
 {name="Chat feedback",detail="Show action messages in ESO chat.",value=M.db.messages and "ON" or "OFF",run=function()M.db.messages=not M.db.messages end},
 {name="Review backpack",detail="Choose pieces before confirming a bind.",value="PREVIEW",run=function()M.RefreshPreview();ui.tab=2;ui.selected=1;ui.page=1 end},
 }
end
function M.RefreshPreview()M.preview=M.Scan(true);M.confirmUntil=nil end
local help={
 "/bi opens settings. /bind opens the binding preview.",
 "/invite opens invite settings; /invite @name invites a player.",
 "Manual binding: offer gear to your group before reviewing it.",
 "A marks a preview piece BIND or SKIP. Y rescans your backpack.",
 "X arms the batch; press X again within 10 seconds to bind it.",
 "Binding ends trading. Lock gear in Inventory to protect it.",
 "Locked, stolen, collected and ineligible items are skipped.",
 "One copy per missing piece; lowest-quality duplicates first.",
 "Automatic binding starts OFF and handles new arrivals only.",
 "Enabling it leaves your existing backpack gear alone.",
 "Turning it off cancels queued binding. Combat stops binding.",
 "Whisper invites start OFF. Enable them in Settings.",
 "Choose a whisper keyword and a 4- or 12-player group limit.",
 "/bi keyword yourword sets a custom word (1–32 characters).",
 "The ESO whisper must match; case and outer spaces are ignored.",
 "Xbox messages cannot trigger invites. Use ESO whispers.",
 "You must be solo or group leader; recipients still accept.",
 "Pending invites reserve spaces for 30 seconds.",
 "Repeated senders have a 30-second cooldown.",
 "One request per second; a sender can repeat a missed whisper.",
 "Disable competing invite features if they conflict.",
 "Settings are account-wide and separate for each server.",
 "X opens Socials from Settings, Help or Log.",
 "/tgw and /tgwbi remain available as legacy menu aliases."
}
function M.Render()
 if not ui then return end
 local tabs={"SETTINGS","BINDING PREVIEW","HELP","SESSION LOG"}
 heading:SetText(tabs[ui.tab].."   /   LB / RB switch tabs")
 summary:SetText("Binding: "..(M.db.autoBind and "AUTO" or "MANUAL").."    Invites: "..(M.db.autoInvite and "ON" or "OFF").."    Keyword: "..M.db.keyword.."    Limit: "..M.db.groupLimit.."\n"..(M.status or "Ready. Review gear before binding."))
 local rows={};ui.count=0
 if ui.tab==1 then
  local opts=Options();ui.count=#opts
  for i,c in ipairs(cards)do local r=opts[i];c.bg:SetHidden(false);c.bg:SetCenterColor(ui.selected==i and .15 or .045,ui.selected==i and .18 or .055,ui.selected==i and .23 or .07,1);c.bg:SetEdgeColor(ui.selected==i and .85 or .24,ui.selected==i and .65 or .27,ui.selected==i and .28 or .32,1);c.title:SetText(r.name);c.value:SetText(r.value);c.detail:SetText(r.detail)end
 elseif ui.tab==2 then
  for i,r in ipairs(M.preview or {})do rows[i]=(ui.selected==i and "> " or "  ")..(M.excluded[r.uid] and "[SKIP] " or "[BIND] ")..r.link..(r.tradeable and " [TRADEABLE]" or "")end
  ui.count=#rows
  if #rows==0 then rows[1]="No eligible uncollected set pieces in your backpack."end
 elseif ui.tab==3 then rows=help
 else for _,r in ipairs(M.log)do rows[#rows+1]=r end;if #rows==0 then rows[1]="No actions yet."end end
 ui.pages=math.max(1,math.ceil(#rows/PAGE));ui.page=math.max(1,math.min(ui.page,ui.pages))
 for _,c in ipairs(cards)do c.bg:SetHidden(ui.tab~=1)end
 for i,c in ipairs(labels)do c:SetHidden(ui.tab==1);c:SetText(rows[(ui.page-1)*PAGE+i]or "")end
 local armed=M.confirmUntil and GetFrameTimeMilliseconds()<M.confirmUntil
 footer:SetText((armed and "Press X again to bind selected pieces. Trading ends.\n" or "")..(ui.tab==1 and "D-pad select   A change   X Socials / Support   B close" or "Page "..ui.page.."/"..ui.pages.."   LT / RT pages   "..(ui.tab==2 and "A include / skip   X confirm bind" or "X Socials / Support")))
 if SCENE_MANAGER:IsShowing("tgwbi")then KEYBIND_STRIP:UpdateKeybindButtonGroup(keys)end
end
local function Build()
 if ui then return end
 local wm=WINDOW_MANAGER;local w=wm:CreateTopLevelWindow("TGWBIWindow")
 w:SetDimensions(1240,800);w:SetAnchor(CENTER,GuiRoot,CENTER,0,0);w:SetHidden(true)
 local function resize()w:SetScale(math.min(GuiRoot:GetWidth()*.94/1240,GuiRoot:GetHeight()*.88/800))end
 resize();w:RegisterForEvent(EVENT_SCREEN_RESIZED,resize)
 local bg=wm:CreateControl(nil,w,CT_BACKDROP);bg:SetAnchorFill(w);bg:SetCenterColor(.025,.035,.05,1);bg:SetEdgeColor(.55,.36,.13,1);bg:SetEdgeTexture(nil,1,1,2)
 local function Label(parent,x,y,width,height,size)
  local c=wm:CreateControl(nil,parent,CT_LABEL);c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);c:SetDimensions(width,height);c:SetFont("$(GAMEPAD_MEDIUM_FONT)|"..size.."|soft-shadow-thin");c:SetColor(.94,.96,1,1);return c
 end
 Label(w,36,22,1168,48,38):SetText("BIND AND INVITE")
 Label(w,36,74,1168,32,24):SetText(M.author.."   /   "..M.version)
 summary=Label(w,36,120,1168,100,26)
 heading=Label(w,36,230,1168,40,28);heading:SetColor(.9,.73,.4,1)
 cards={}
 for i=1,6 do
  local x=36+math.floor((i-1)/3)*592;local y=292+((i-1)%3)*120
  local c=wm:CreateControl(nil,w,CT_BACKDROP);c:SetAnchor(TOPLEFT,w,TOPLEFT,x,y);c:SetDimensions(576,106);c:SetEdgeTexture(nil,1,1,2)
  cards[i]={bg=c,title=Label(c,16,10,382,38,30),value=Label(c,400,12,160,36,26),detail=Label(c,16,56,544,42,23)}
 end
 labels={};for i=1,PAGE do labels[i]=Label(w,36,288+(i-1)*48,1168,46,27);labels[i]:SetMaxLineCount(1)end
 footer=Label(w,36,698,1168,86,24)
 ui={tab=1,selected=1,page=1,count=0,pages=1};M.ui=ui
 local function Tab(delta)ui.tab=(ui.tab-1+delta)%4+1;ui.selected=1;ui.page=1;M.confirmUntil=nil;if ui.tab==2 then M.RefreshPreview()end;M.Render()end
 local function Move(delta,horizontal)
  if ui.count==0 then return end
  if ui.tab==1 then
   if horizontal then ui.selected=(ui.selected-1+3)%6+1
   else local col=math.floor((ui.selected-1)/3);ui.selected=col*3+(ui.selected-1+delta)%3+1 end
  else ui.selected=(ui.selected-1+delta)%ui.count+1;ui.page=math.floor((ui.selected-1)/PAGE)+1 end
  M.confirmUntil=nil;M.Render()
 end
 local function Change()
  M.confirmUntil=nil
  if ui.tab==1 then Options()[ui.selected].run()
  elseif ui.tab==2 then local r=M.preview[ui.selected];if r then M.excluded[r.uid]=not M.excluded[r.uid]end end
  M.Render()
 end
 local function Secondary()
  if ui.tab~=2 then M.confirmUntil=nil;SCENE_MANAGER:Show("tgwBISupport");return end
  if M.busy then return end
  local rows={};for _,r in ipairs(M.preview or {})do if not M.excluded[r.uid]then rows[#rows+1]=r end end
  if #rows==0 then M.Note("No preview pieces selected.");return end
  if M.confirmUntil and GetFrameTimeMilliseconds()<M.confirmUntil then M.confirmUntil=nil;M.StartBind(rows,false)
  else M.confirmUntil=GetFrameTimeMilliseconds()+10000;M.Note("Review selections: binding ends trading. Press X again within 10 seconds.")end
  M.Render()
 end
 local function Page(delta)
  if ui.tab==1 then return end
  ui.page=math.max(1,math.min(ui.pages,ui.page+delta));ui.selected=(ui.page-1)*PAGE+1;M.confirmUntil=nil;M.Render()
 end
 keys={alignment=KEYBIND_STRIP_ALIGN_CENTER,
 {name="Previous tab",keybind="UI_SHORTCUT_LEFT_SHOULDER",callback=function()Tab(-1)end},
 {name="Next tab",keybind="UI_SHORTCUT_RIGHT_SHOULDER",callback=function()Tab(1)end},
 {name="Change",keybind="UI_SHORTCUT_PRIMARY",visible=function()return ui.tab<=2 end,callback=Change},
 {name=function()return ui.tab==2 and "Confirm bind" or "Socials / Support"end,keybind="UI_SHORTCUT_SECONDARY",callback=Secondary},
 {name="Rescan",keybind="UI_SHORTCUT_TERTIARY",visible=function()return ui.tab==2 end,callback=function()M.RefreshPreview();ui.selected=1;ui.page=1;M.Render()end},
 {keybind="UI_SHORTCUT_LEFT_TRIGGER",ethereal=true,callback=function()Page(-1)end},
 {keybind="UI_SHORTCUT_RIGHT_TRIGGER",ethereal=true,callback=function()Page(1)end},
 {name="Close",keybind="UI_SHORTCUT_NEGATIVE",callback=function()SCENE_MANAGER:Hide("tgwbi")end},
 {keybind="UI_SHORTCUT_INPUT_UP",ethereal=true,callback=function()Move(-1)end},
 {keybind="UI_SHORTCUT_INPUT_DOWN",ethereal=true,callback=function()Move(1)end},
 {keybind="UI_SHORTCUT_INPUT_LEFT",ethereal=true,callback=function()Move(-1,true)end},
 {keybind="UI_SHORTCUT_INPUT_RIGHT",ethereal=true,callback=function()Move(1,true)end}}
 local scene=ZO_Scene:New("tgwbi",SCENE_MANAGER)
 scene:AddFragmentGroup(IsInGamepadPreferredMode()and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW or FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
 scene:AddFragment(ZO_FadeSceneFragment:New(w))
 local active=false
 scene:RegisterCallback("StateChange",function(_,state)
  if state==SCENE_SHOWING then resize();if not active then KEYBIND_STRIP:AddKeybindButtonGroup(keys);active=true end
  elseif state==SCENE_HIDING or state==SCENE_HIDDEN then M.confirmUntil=nil;if active then KEYBIND_STRIP:RemoveKeybindButtonGroup(keys);active=false end end
 end)
 M:CreateSupportUI();M.render=M.Render
end
function M.Open(arg)
 local command,rest=tostring(arg or ""):match("^(%S+)%s*(.-)$");command=M.Normalize(command)
 if command=="keyword"then
  local word=M.Normalize(rest);if word==""or #word>32 then M.Note("Keyword must contain 1–32 characters.");return end
  M.db.keyword=word;M.Note("Whisper keyword set to: "..word);return
 end
 Build();M.RefreshPreview();ui.tab=command=="bind"and 2 or 1;ui.selected=command=="invite"and 2 or 1;ui.page=1;M.Render();SCENE_MANAGER:Show("tgwbi")
 if command=="socials"or command=="support"then SCENE_MANAGER:Show("tgwBISupport")end
end
