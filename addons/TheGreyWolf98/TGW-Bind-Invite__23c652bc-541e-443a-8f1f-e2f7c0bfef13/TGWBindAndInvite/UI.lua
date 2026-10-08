local M=TGWBI
local ui,keys,summary,heading,footer,labels
local function Options()
 return {
 {name="Automatic binding of newly received gear",value=M.db.autoBind and "ON" or "OFF",run=function() M.SetAutoBind(M.db.autoBind~=true) end},
 {name="Whisper auto invite",value=M.db.autoInvite and "ON" or "OFF",run=function() M.db.autoInvite=not M.db.autoInvite;M.pending={};M.Note("Whisper invites "..(M.db.autoInvite and "enabled." or "disabled.")) end},
 {name="Keyword preset",value=M.db.keyword,run=function()local choices={"invite","dungeon","trial","tax"}; local nextIndex=1;for i,v in ipairs(choices)do if M.db.keyword==v then nextIndex=i%#choices+1 end end;M.db.keyword=choices[nextIndex] end},
 {name="Group limit",value=tostring(M.db.groupLimit),run=function() M.db.groupLimit=M.db.groupLimit==4 and 12 or 4 end},
 {name="Chat feedback",value=M.db.messages and "ON" or "OFF",run=function()M.db.messages=not M.db.messages end},
 {name="Review backpack for manual binding",value="Open preview",run=function()M.RefreshPreview();ui.tab=2;ui.selected=1 end},
 }
end
function M.RefreshPreview()
 M.preview=M.Scan(true);M.confirmUntil=nil
end
function M.Render()
 if not ui then return end
 local rows={};local selectable=0
 summary:SetText("Binding: "..(M.db.autoBind and "AUTOMATIC" or "MANUAL").."  |  Invites: "..(M.db.autoInvite and "LISTENING" or "OFF").."  |  Whisper: "..M.db.keyword.."  |  Limit: "..M.db.groupLimit.."\n"..(M.status or "Ready. Manual binding and invites are off until you choose."))
 if ui.tab==1 then
  heading:SetText("Settings  |  D-pad selects; A changes")
  local opts=Options();selectable=#opts
  for i,r in ipairs(opts)do rows[i]=(ui.selected==i and "> " or "  ")..r.name..": "..r.value end
  rows[#rows+1]="";rows[#rows+1]="Custom keyword: /tgw keyword yourword"
  rows[#rows+1]="Automatic binding starts with new arrivals only; existing loot is kept."
 elseif ui.tab==2 then
  heading:SetText("Manual binding preview  |  A includes/excludes; X confirms batch")
  for i,r in ipairs(M.preview or {})do rows[i]=(ui.selected==i and "> " or "  ")..(M.excluded[r.uid] and "[SKIP] " or "[BIND] ")..r.link..(r.tradeable and " [GROUP TRADEABLE]" or "") end
  selectable=#rows
  if #rows==0 then rows[1]="No eligible uncollected set pieces in your backpack." end
 elseif ui.tab==3 then
  heading:SetText("How to use")
  rows={"/tgw opens this controller menu. /tgwbi is an alias.",
  "/tgw bind immediately binds one eligible copy per missing backpack collection piece.",
  "Manual mode: finish the run, offer gear to your group, then open Preview.",
  "D-pad selects a piece. A marks it BIND or SKIP. Lowest-quality duplicates are chosen.",
  "X arms the batch for 10 seconds; press X again to bind the included preview items.",
  "Y rescans the backpack. Locked, stolen, collected and ineligible items are skipped.",
  "Binding removes group trading rights. Lock gear in Inventory to protect it permanently.",
  "AutoBind OFF by default. When ON, newly received missing collection pieces bind.",
  "Turning AutoBind ON does not bind gear already sitting in your backpack.",
  "AutoInvite OFF by default. Choose keyword and 4-player / 12-player limit, then enable.",
  "Sender must whisper the exact keyword in ESO chat (case and outer spaces ignored).",
  "You must be solo or group leader. Invites are requests; recipients still accept them.",
  "Pending requests reserve places for 30 seconds. Repeated senders have a 30s cooldown.",
  "One invite request per second. A sender hitting that cooldown can repeat their whisper.",
  "Custom keyword: /tgw keyword yourword. Presets can be cycled with the controller.",
  "Xbox messages are not ESO whispers and cannot trigger this addon.",
  "Disable other AutoBind / AutoInvite features, including NQOL invites, while testing.",
  "LB/RB tabs; D-pad select; LT/RT pages; A change; X bind; Y refresh; B close.",
  "Account settings are stored separately per server. No external libraries required."}
 else heading:SetText("Session log");for _,r in ipairs(M.log)do rows[#rows+1]=r end;if #rows==0 then rows[1]="No actions yet."end end
 ui.count=selectable;ui.pages=math.max(1,math.ceil(#rows/14));ui.page=math.max(1,math.min(ui.page,ui.pages))
 for i,c in ipairs(labels)do c:SetText(rows[(ui.page-1)*14+i] or "")end
 footer:SetText((M.confirmUntil and GetFrameTimeMilliseconds()<M.confirmUntil and "Press X again to bind the included preview pieces. " or "").."Page "..ui.page.."/"..ui.pages.."\nLB/RB tabs | D-pad select | A change | X bind | Y refresh | B close")
 if SCENE_MANAGER:IsShowing("tgwbi")then KEYBIND_STRIP:UpdateKeybindButtonGroup(keys)end
end
local function Build()
 if ui then return end
 local wm=WINDOW_MANAGER;local w=wm:CreateTopLevelWindow("TGWBIWindow")
 w:SetDimensions(1120,820);w:SetAnchor(CENTER,GuiRoot,CENTER,0,0);w:SetHidden(true);w:SetMouseEnabled(true)
 local sw,sh=GuiRoot:GetDimensions();w:SetScale(math.min(1,sw/1180,sh/900))
 local bg=wm:CreateControl(nil,w,CT_BACKDROP);bg:SetAnchorFill();bg:SetCenterColor(.012,.012,.018,1);bg:SetEdgeColor(.38,.07,.065,1)
 local function Label(y,h,font)local c=wm:CreateControl(nil,w,CT_LABEL);c:SetAnchor(TOPLEFT,w,TOPLEFT,35,y);c:SetDimensions(1050,h);c:SetFont(font);c:SetColor(.85,.85,.88,1);return c end
 Label(20,45,"ZoFontGamepad34"):SetText("TGW Bind & Invite")
 summary=Label(80,80,"ZoFontGamepad22");heading=Label(175,38,"ZoFontGamepad27");heading:SetColor(.85,.3,.28,1)
 labels={};for i=1,14 do labels[i]=Label(225+(i-1)*32,32,"ZoFontGamepad22");labels[i]:SetMaxLineCount(1)end
 footer=Label(700,65,"ZoFontGamepad22");Label(780,30,"ZoFontGamepad22"):SetText("@TheGreyWolf98  |  Version 1.0.0")
 ui={tab=1,selected=1,page=1,count=0,pages=1}
 local function Tab(delta)ui.tab=(ui.tab-1+delta)%4+1;ui.selected=1;ui.page=1;M.confirmUntil=nil;if ui.tab==2 then M.RefreshPreview()end;M.Render()end
 local function Move(delta)if ui.count>0 then ui.selected=(ui.selected-1+delta)%ui.count+1;ui.page=math.floor((ui.selected-1)/14)+1;M.confirmUntil=nil;M.Render()end end
 local function Change()
  M.confirmUntil=nil
  if ui.tab==1 then Options()[ui.selected].run()
  elseif ui.tab==2 then local r=M.preview[ui.selected];if r then M.excluded[r.uid]=not M.excluded[r.uid]end end
  M.Render()
 end
 local function Bind()
  if ui.tab~=2 or M.busy then return end
  local rows={};for _,r in ipairs(M.preview or {})do if not M.excluded[r.uid]then rows[#rows+1]=r end end
  if #rows==0 then M.Note("No preview pieces selected.");return end
  if M.confirmUntil and GetFrameTimeMilliseconds()<M.confirmUntil then M.confirmUntil=nil;M.StartBind(rows,false)
  else M.confirmUntil=GetFrameTimeMilliseconds()+10000;M.Note("Review your selections: binding ends trading. Press X again within 10 seconds.")end
  M.Render()
 end
 keys={alignment=KEYBIND_STRIP_ALIGN_CENTER,
 {name="Previous tab",keybind="UI_SHORTCUT_LEFT_SHOULDER",callback=function()Tab(-1)end},
 {name="Next tab",keybind="UI_SHORTCUT_RIGHT_SHOULDER",callback=function()Tab(1)end},
 {name="Change",keybind="UI_SHORTCUT_PRIMARY",visible=function()return ui.tab<=2 end,callback=Change},
 {name="Bind selected",keybind="UI_SHORTCUT_SECONDARY",visible=function()return ui.tab==2 end,callback=Bind},
 {name="Refresh",keybind="UI_SHORTCUT_TERTIARY",callback=function()M.RefreshPreview();M.Render()end},
 {name="Previous page",keybind="UI_SHORTCUT_LEFT_TRIGGER",callback=function()ui.page=math.max(1,ui.page-1);ui.selected=(ui.page-1)*14+1;M.confirmUntil=nil;M.Render()end},
 {name="Next page",keybind="UI_SHORTCUT_RIGHT_TRIGGER",callback=function()ui.page=math.min(ui.pages,ui.page+1);ui.selected=(ui.page-1)*14+1;M.confirmUntil=nil;M.Render()end},
 {name="Close",keybind="UI_SHORTCUT_NEGATIVE",callback=function()SCENE_MANAGER:Hide("tgwbi")end},
 {keybind="UI_SHORTCUT_INPUT_UP",callback=function()Move(-1)end},
 {keybind="UI_SHORTCUT_INPUT_DOWN",callback=function()Move(1)end}}
 local scene=ZO_Scene:New("tgwbi",SCENE_MANAGER)
 scene:AddFragmentGroup(IsInGamepadPreferredMode() and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW or FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
 scene:AddFragment(ZO_FadeSceneFragment:New(w))
 scene:RegisterCallback("StateChange",function(_,state)if state==SCENE_SHOWN then KEYBIND_STRIP:AddKeybindButtonGroup(keys) elseif state==SCENE_HIDING then M.confirmUntil=nil;KEYBIND_STRIP:RemoveKeybindButtonGroup(keys)end end)
 M.render=M.Render
end
function M.Open(arg)
 local command,rest=tostring(arg or ""):match("^(%S+)%s*(.-)$")
 if command and M.Normalize(command)=="bind" then
  local rows=M.Scan()
  if #rows==0 then M.Note("No eligible uncollected pieces to bind.");return end
  M.StartBind(rows,false);return
 end
 if command and M.Normalize(command)=="keyword" then
  local word=M.Normalize(rest)
  if word=="" or #word>32 then M.Note("Keyword must contain 1-32 characters.");return end
  M.db.keyword=word;M.Note("Whisper keyword set to: "..word);return
 end
 Build();M.RefreshPreview();ui.tab=1;ui.selected=1;ui.page=1;M.Render();SCENE_MANAGER:Show("tgwbi")
end
