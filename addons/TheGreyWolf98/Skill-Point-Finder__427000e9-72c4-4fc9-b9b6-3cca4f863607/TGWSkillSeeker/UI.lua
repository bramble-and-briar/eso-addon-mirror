local M=TGWSS
local ui,keys,heading,summary,detail,footer,labels,zoneHeaders,zoneArrows
local function Selected()return M.db.characters[ui.character]end
local function Rows()local s=Selected();return s and s.rows[ui.category] or {}end
local function PageSize()return not ui.picker and (ui.category==1 or ui.category==2 or ui.category==7) and 24 or 12 end
local groupNames={"EP","DC","AD","DLC","DLC continued","Other"}
local zoneGroups={}
for _,id in ipairs({280,281,41,57,117,101,103})do zoneGroups[id]=1 end
for _,id in ipairs({534,535,3,19,20,104,92})do zoneGroups[id]=2 end
for _,id in ipairs({537,381,383,108,58,382})do zoneGroups[id]=3 end
for _,id in ipairs({809,347,888})do zoneGroups[id]=6 end
-- Story route for alliance zones; release chronology for DLC zones.
local zoneOrder={}
for i,id in ipairs({280,281,41,57,117,101,103,534,535,3,19,20,104,92,537,381,383,108,58,382,684,816,823,849,980,1011,726,1086,1133,1160,1207,1261,1286,1318,1383,1413,1443,1502,809,347,888})do zoneOrder[id]=i end
local function IsZones()return not ui.picker and ui.category==3 end
local function GroupRows()
 local groups={{},{},{},{},{},{}};local column,index=1,1
 local ordered={};for i,r in ipairs(Rows())do ordered[#ordered+1]={row=r,index=i}end
 table.sort(ordered,function(a,b)return (zoneOrder[a.row.zone] or 999)<(zoneOrder[b.row.zone] or 999)end)
 for _,entry in ipairs(ordered)do local i,r=entry.index,entry.row
  local g=zoneGroups[r.zone] or 4
  if g==4 and #groups[4]>=10 then g=5 end
  groups[g][#groups[g]+1]={row=r,index=i}
  if i==ui.selected then column=g;index=#groups[g]end
 end
 return groups,column,index
end
local function Paint(c,complete) c:SetColor(complete and .35 or 1,complete and 1 or .65,.6,1)end
local function Render()
 if not ui then return end
 local chars=M.Characters();local name="Character";for _,c in ipairs(chars)do if c.id==ui.character then name=c.name end end
 local s=Selected()
 summary:SetText("Character: "..name.."  |  X: select character\n"..(M.scanning and "Scanning current character: "..M.scanProgress.."%" or s and "Available points: "..tostring(ui.character==M.CharId() and GetAvailableSkillPoints() or s.availablePoints or "rescan to read").."  |  "..s.shards.."/"..s.shardTotal.." skyshards across catalogue zones" or "Not scanned: log into this character once."))
 local rows=ui.picker and chars or Rows();local count=#rows
 ui.selected=math.max(1,math.min(ui.selected,math.max(1,count)));ui.page=math.floor((ui.selected-1)/PageSize())+1
 heading:SetText(ui.picker and "Select character  |  D-pad selects; A confirms" or M.categories[ui.category].."  |  Page "..ui.page.." / "..math.max(1,math.ceil(count/PageSize())))
 for _,c in ipairs(zoneHeaders)do c:SetHidden(not IsZones())end
 for _,c in ipairs(zoneArrows)do c:SetText("")end
 if IsZones() then
  heading:SetText("Zones  |  Quest rewards and skyshards")
  local groups=GroupRows()
  for g=1,6 do
   zoneHeaders[g]:SetText(groupNames[g])
   for j=1,(g==6 and 3 or 10) do
    local c=labels[g==6 and 50+j or (g-1)*10+j];local entry=groups[g][j]
    local x=g==6 and 820 or 35+(g-1)*220;local y=g==6 and 55+(j-1)*41 or 240+(j-1)*40
    c.name:ClearAnchors();c.name:SetAnchor(TOPLEFT,ui.window,TOPLEFT,x,y);c.name:SetDimensions(g==6 and 305 or 210,22);c.name:SetFont("ZoFontGamepad20");c.name:SetMaxLineCount(1)
    c.shards:ClearAnchors();c.shards:SetAnchor(TOPLEFT,ui.window,TOPLEFT,x,y+20);c.shards:SetDimensions(g==6 and 305 or 210,20);c.shards:SetFont("ZoFontGamepad18")
    c.name:SetColor(.9,.9,.9,1)
    if entry then
     local r=entry.row;c.name:SetText((entry.index==ui.selected and "> " or "")..r.name)
     local questColor=r.done==r.total and "|c59FF99" or "|cFFA666"
     local shardColor=r.shards==r.shardTotal and "|c59FF99" or "|cFFA666"
     c.shards:SetText(questColor.."SP "..r.done.."/"..r.total.."|r  "..shardColor.."SS "..r.shards.."/"..r.shardTotal.."|r")
    else c.name:SetText("");c.shards:SetText("")end
   end
  end
 else
 for i,c in ipairs(labels)do
  local x=35+math.floor((i-1)/12)*550;local y=220+((i-1)%12)*32
  c.name:ClearAnchors();c.name:SetAnchor(TOPLEFT,ui.window,TOPLEFT,x,y);c.name:SetFont("ZoFontGamepad22");c.name:SetMaxLineCount(1)
  c.name:SetDimensions(PageSize()==24 and 530 or 1090,32)
  local idx=(ui.page-1)*PageSize()+i;local r=i<=PageSize() and rows[idx] or nil
  if not r then c.name:SetText("");c.shards:SetText("")
  else
   local prefix=idx==ui.selected and "> " or "  "
   local status
   if ui.picker then status=r.scanned and "[Saved] " or "[New] "
   elseif r.unknown then status="[?] "
   elseif (ui.category==1 or ui.category==2 or ui.category==7) then
    status="|t24:24:EsoUI/Art/Buttons/"..(r.done==r.total and "checkbox_checked.dds" or "checkbox_unchecked.dds").."|t "
   else status="["..r.done.."/"..r.total.."] " end
   c.name:SetText(prefix..status..r.name)
   c.name:SetColor(r.unknown and .7 or ui.picker and .88 or r.done==r.total and .35 or 1,r.unknown and .7 or ui.picker and .88 or r.done==r.total and 1 or .65,.6,1)
   c.shards:SetText("")
   if r.shards then c.name:SetText(prefix..status..r.name.."  |  Shards "..r.shards.."/"..r.shardTotal) end
  end
 end
 end
 local r=rows[ui.selected]
 local text=ui.picker and "Choose any character. Unscanned characters need one login; offline characters show their last saved scan." or (IsZones() and "SP: quest skill-point rewards | SS: skyshards | Green: complete | Amber: remaining | A: details" or "A: row details  |  Checked / green: complete  |  Empty / amber: remaining  |  Unknown: excluded from totals")
 if not ui.picker and ui.expanded and r then
  local lines={};for line in (r.detail.."\n"):gmatch("(.-)\n")do lines[#lines+1]=line end
  ui.detailPages=math.max(1,math.ceil(#lines/5));ui.detailPage=math.min(ui.detailPage or 1,ui.detailPages)
  local chunk={};for i=(ui.detailPage-1)*5+1,math.min(#lines,ui.detailPage*5)do chunk[#chunk+1]=lines[i]end
  text=table.concat(chunk,"\n");if text==""then text="No skill-point quests in this catalogue row."end
 end
 detail:SetText(text)
 footer:SetText("LB/RB category | Hold D-pad to move; left/right column | LT/RT page | X character | Y scan CURRENT toon | B back\n"..(ui.picker and "Character selector" or "Dungeon rows track the skill-point quest, not every boss kill. Shards are counts, not skill points."))
 if SCENE_MANAGER:IsShowing("tgwskillseeker")then KEYBIND_STRIP:UpdateKeybindButtonGroup(keys)end
end
local function Build()
 if ui then return end
 local wm=WINDOW_MANAGER;local w=wm:CreateTopLevelWindow("TGWSSWindow")
 w:SetDimensions(1160,850);w:SetAnchor(CENTER,GuiRoot,CENTER,0,0);w:SetHidden(true)
 local sw,sh=GuiRoot:GetDimensions();w:SetScale(math.min(1,sw/1220,sh/900))
 local bg=wm:CreateControl(nil,w,CT_BACKDROP);bg:SetAnchorFill();bg:SetCenterColor(.012,.012,.018,1);bg:SetEdgeColor(.4,.08,.07,1)
 local function Label(x,y,width,height,font)local c=wm:CreateControl(nil,w,CT_LABEL);c:SetAnchor(TOPLEFT,w,TOPLEFT,x,y);c:SetDimensions(width,height);c:SetFont(font);c:SetColor(.88,.88,.9,1);return c end
 Label(35,20,770,45,"ZoFontGamepad34"):SetText("Skill Point Finder  |  Your next skill point")
 summary=Label(35,75,770,70,"ZoFontGamepad22");heading=Label(35,155,1090,38,"ZoFontGamepad27")
 zoneHeaders={};zoneArrows={};for i=1,6 do
  zoneHeaders[i]=Label(i==6 and 820 or 35+(i-1)*220,i==6 and 20 or 205,i==6 and 305 or 210,30,"ZoFontGamepad27")
 end
 labels={};for i=1,53 do
  local column=math.floor((i-1)/12);local y=220+((i-1)%12)*32;local x=35+column*550
  labels[i]={name=Label(x,y,530,32,"ZoFontGamepad22"),shards=Label(x+30,y+23,490,20,"ZoFontGamepad18")}
  labels[i].name:SetMaxLineCount(1)
 end
 detail=Label(35,650,1090,120,"ZoFontGamepad20");detail:SetMaxLineCount(5)
 footer=Label(35,770,1090,44,"ZoFontGamepad18");Label(35,815,1090,28,"ZoFontGamepad20"):SetText("@TheGreyWolf98  |  1.0.0  |  /spf")
 ui={window=w,character=M.CharId(),category=1,selected=1,page=1,picker=false,expanded=false}
 local function Count()return #(ui.picker and M.Characters() or Rows())end
 local function Move(n)ui.selected=math.max(1,math.min(math.max(1,Count()),ui.selected+n));ui.expanded=false;Render()end
 local function Vertical(n)
  if not IsZones()then Move(n);return end
  local groups,column,index=GroupRows();local entries=groups[column];local target=entries[math.max(1,math.min(#entries,index+n))]
  if target then ui.selected=target.index end;ui.expanded=false;Render()
 end
 local function Horizontal(n)
  if not IsZones()then if PageSize()==24 then Move(n*12)end;return end
  local groups,column,index=GroupRows();local nextColumn=column+n
  while nextColumn>=1 and nextColumn<=6 do
   local entries=groups[nextColumn];if #entries>0 then ui.selected=entries[math.min(index,#entries)].index;ui.expanded=false;Render();return end
   nextColumn=nextColumn+n
  end
 end
 local function StopRepeat()EVENT_MANAGER:UnregisterForUpdate(M.name.."Scroll");ui.held=nil end
 local function Held(n,up)
  if up then if ui.held==n then StopRepeat()end;return end
  StopRepeat();ui.held=n;Vertical(n);local ticks=0
  EVENT_MANAGER:RegisterForUpdate(M.name.."Scroll",120,function()ticks=ticks+1;if ticks>=3 then Vertical(n)end end)
 end
 local function Category(n)StopRepeat();if ui.picker then return end;ui.category=(ui.category-1+n)%#M.categories+1;ui.selected=1;ui.expanded=false;Render()end
 keys={alignment=KEYBIND_STRIP_ALIGN_CENTER,
 {name="Previous category",keybind="UI_SHORTCUT_LEFT_SHOULDER",callback=function()Category(-1)end},
 {name="Next category",keybind="UI_SHORTCUT_RIGHT_SHOULDER",callback=function()Category(1)end},
 {name="Select / details",keybind="UI_SHORTCUT_PRIMARY",callback=function()if ui.picker then local c=M.Characters()[ui.selected];if c then ui.character=c.id end;ui.picker=false;ui.selected=1 else ui.detailPage=1;ui.expanded=not ui.expanded end;Render()end},
 {name="Characters",keybind="UI_SHORTCUT_SECONDARY",callback=function()StopRepeat();ui.picker=not ui.picker;ui.selected=1;ui.expanded=false;Render()end},
 {name="Scan current character",keybind="UI_SHORTCUT_TERTIARY",callback=function()M.Scan();Render()end},
 {name="Previous page",keybind="UI_SHORTCUT_LEFT_TRIGGER",callback=function()if ui.expanded then ui.detailPage=math.max(1,(ui.detailPage or 1)-1);Render()else Vertical(IsZones() and -6 or -PageSize())end end},
 {name="Next page",keybind="UI_SHORTCUT_RIGHT_TRIGGER",callback=function()if ui.expanded then ui.detailPage=math.min(ui.detailPages or 1,(ui.detailPage or 1)+1);Render()else Vertical(IsZones() and 6 or PageSize())end end},
 {keybind="UI_SHORTCUT_INPUT_LEFT",callback=function()Horizontal(-1) end},
 {keybind="UI_SHORTCUT_INPUT_RIGHT",callback=function()Horizontal(1) end},
 {keybind="UI_SHORTCUT_INPUT_UP",handlesKeyUp=true,callback=function(up)Held(-1,up)end},
 {keybind="UI_SHORTCUT_INPUT_DOWN",handlesKeyUp=true,callback=function(up)Held(1,up)end},
 {name="Back",keybind="UI_SHORTCUT_NEGATIVE",callback=function()if ui.picker then ui.picker=false;ui.selected=1;Render()else SCENE_MANAGER:Hide("tgwskillseeker")end end}}
 local scene=ZO_Scene:New("tgwskillseeker",SCENE_MANAGER);scene:AddFragmentGroup(IsInGamepadPreferredMode() and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW or FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW);scene:AddFragment(ZO_FadeSceneFragment:New(w))
 scene:RegisterCallback("StateChange",function(_,state)if state==SCENE_SHOWN then KEYBIND_STRIP:AddKeybindButtonGroup(keys) elseif state==SCENE_HIDING then StopRepeat();KEYBIND_STRIP:RemoveKeybindButtonGroup(keys)end end)
 M.render=function()if not w:IsHidden()then Render()end end
end
function M.Open()Build();Render();SCENE_MANAGER:Show("tgwskillseeker")end
