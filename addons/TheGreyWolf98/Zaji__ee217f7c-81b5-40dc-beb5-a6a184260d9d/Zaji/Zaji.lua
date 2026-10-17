local window,scene,keys,rangeLabel
local rows={}
local topIndex=1
local VISIBLE,ROW_HEIGHT,LIST_TOP=7,80,126
local entries={
 {'ItemHound','/ih','Find items across characters, bank, Craft Bag, storage and houses.'},
 {'ZoneSweep','/zs','Check current-zone activities, discoveries and completion progress.'},
 {'Master Baiter','/mb','Fishing settings, bait selection, alerts and rare-fish progress.'},
 {'Atlas','/atlas','Map pins for skyshards, lorebooks, bosses, surveys and treasure.'},
 {'Loadout','/loadout','View character build and equipment information.'},
 {'House Directory','/houses','Browse owned houses and travel to them.'},
 {'Chat Palette','/palette','Choose colours for your chat channels.'},
 {'Atlas Mini Map','/minimap','Adjust the minimap, its position, zoom and clock.'},
 {'Bind and Invite','/tgw','Auto-bind uncollected gear and set a chat keyword for invites.'},
 {'Skill Point Finder','/spf','See skill-point opportunities and your character checklist.'},
 {'Combat Recap','/recap','Review recent fights and saved build snapshots.'},
 {'Chat Keeper','/chatkeeper','Keep recent chat history and remember the chat window position.'},
 {'Craft Master','/cm','Search plans, recipes and motifs; check what your crafters know.'},
 {'Scry Master','/sm','Track antiquities, mythics, zone collections and codex progress.'},
}
table.sort(entries,function(a,b) return a[1]:lower()<b[1]:lower() end)
local function label(parent,x,y,width,text,font,height)
 local l=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL)
 l:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);l:SetDimensions(width,height or 36)
 l:SetFont(font or 'ZoFontGamepad27');l:SetColor(.92,.92,.92,1);l:SetText(text)
 l:SetMaxLineCount(1);l:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
 return l
end
local function render()
 topIndex=math.max(1,math.min(topIndex,math.max(1,#entries-VISIBLE+1)))
 for i,row in ipairs(rows) do
  local e=entries[topIndex+i-1]
  row.name:SetText(e and e[1] or '')
  row.command:SetText(e and e[2] or '')
  row.description:SetText(e and e[3] or '')
  row.line:SetHidden(not e)
 end
 rangeLabel:SetText(topIndex..' - '..math.min(topIndex+VISIBLE-1,#entries)..' / '..#entries)
end
local function scroll(delta)
 local previous=topIndex
 topIndex=math.max(1,math.min(topIndex+delta,math.max(1,#entries-VISIBLE+1)))
 if topIndex~=previous then render() end
end
local input={active=false}
function input:UpdateDirectionalInput()
 if not self.active then return end
 local x,y=DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK_NO_KEYBOARD)
 if math.abs(y)<.55 or math.abs(x)>math.abs(y) then
  self.nextInput=0;self.held=false;return
 end
 DIRECTIONAL_INPUT:Consume(ZO_DI_LEFT_STICK)
 local now=GetFrameTimeMilliseconds()
 if now<(self.nextInput or 0) then return end
 scroll(y>0 and -1 or 1)
 self.nextInput=now+(self.held and 160 or 320);self.held=true
end
local function open()
 if IsUnitInCombat('player') then d('Zaji: open after combat.');return end
 if not window then
  window=WINDOW_MANAGER:CreateTopLevelWindow('TGWZajiWindow')
  window:SetAnchor(CENTER,GuiRoot,CENTER,0,-30);window:SetDimensions(1120,820);window:SetHidden(true)
  window:SetMouseEnabled(true)
  local bg=WINDOW_MANAGER:CreateControl(nil,window,CT_TEXTURE)
  bg:SetAnchorFill(window);bg:SetColor(.025,.03,.04,1)
  label(window,24,20,800,'ZAJI | ADDON COMMAND KEY','ZoFontGamepadBold34',44)
  rangeLabel=label(window,864,25,232,'','ZoFontGamepad27')
  rangeLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  label(window,24,78,580,'ADDON / WHAT IT DOES')
  label(window,760,78,336,'CHAT COMMAND')
  for i=1,VISIBLE do
   local y=LIST_TOP+(i-1)*ROW_HEIGHT
   local line=WINDOW_MANAGER:CreateControl(nil,window,CT_TEXTURE)
   line:SetAnchor(TOPLEFT,window,TOPLEFT,24,y+ROW_HEIGHT-4);line:SetDimensions(1072,1);line:SetColor(.5,.55,.6,.45)
   local name=label(window,24,y,700,'')
   local command=label(window,760,y,336,'');command:SetColor(.95,.72,.4,1)
   local description=label(window,24,y+36,1072,'','ZoFontGamepad22',30)
   description:SetColor(.75,.8,.86,1)
   rows[i]={name=name,command=command,description=description,line=line}
  end
  label(window,24,704,1072,'Stick / D-pad / mouse wheel: scroll  |  LB/RB: page  |  B: close','ZoFontGamepad22')
  label(window,24,740,1072,'Type a command in chat to open that addon. /zaji opens this key.','ZoFontGamepad22')
  label(window,24,776,1072,'History: /chatkeeper history  |  Fishing HUD: /mbhud  |  @TheGreyWolf98','ZoFontGamepad22')
  keys={alignment=KEYBIND_STRIP_ALIGN_LEFT,
   {name='Previous page',keybind='UI_SHORTCUT_LEFT_SHOULDER',callback=function()scroll(-VISIBLE)end},
   {name='Next page',keybind='UI_SHORTCUT_RIGHT_SHOULDER',callback=function()scroll(VISIBLE)end},
   {name='Close',keybind='UI_SHORTCUT_NEGATIVE',callback=function()SCENE_MANAGER:Hide('tgwZaji')end},
   {keybind='UI_SHORTCUT_INPUT_UP',ethereal=true,callback=function()if input.active then scroll(-1);return true end end},
   {keybind='UI_SHORTCUT_INPUT_DOWN',ethereal=true,callback=function()if input.active then scroll(1);return true end end},
  }
  window:SetHandler('OnMouseWheel',function(_,delta) if input.active then scroll(delta>0 and -1 or 1) end end)
  scene=ZO_Scene:New('tgwZaji',SCENE_MANAGER)
  scene:AddFragmentGroup(IsInGamepadPreferredMode() and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW or FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
  scene:AddFragment(ZO_SimpleSceneFragment:New(window))
  if UI_SHORTCUTS_ACTION_LAYER_FRAGMENT then scene:AddFragment(UI_SHORTCUTS_ACTION_LAYER_FRAGMENT) end
  scene:RegisterCallback('StateChange',function(_,state)
   if state==SCENE_SHOWING then
    render();input.active=true;input.nextInput=0;input.held=false
    KEYBIND_STRIP:AddKeybindButtonGroup(keys)
    if IsInGamepadPreferredMode() then DIRECTIONAL_INPUT:Activate(input,window) end
   elseif state==SCENE_HIDING then
    input.active=false;DIRECTIONAL_INPUT:Deactivate(input)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(keys)
   end
  end)
 end
 window:SetScale(math.min(1,GuiRoot:GetWidth()/1160,GuiRoot:GetHeight()/960))
 SCENE_MANAGER:Show('tgwZaji')
end
EVENT_MANAGER:RegisterForEvent('TGWZajiLoad',EVENT_ADD_ON_LOADED,function(_,name)
 if name~='Zaji' then return end
 EVENT_MANAGER:UnregisterForEvent('TGWZajiLoad',EVENT_ADD_ON_LOADED)
 SLASH_COMMANDS['/zaji']=open
end)
