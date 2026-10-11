local window,scene,keys
local entries={
 {'Item Hound','/ih','Inventory search and stored items'},
 {'ZoneSweep','/zs','Current-zone checklist'},
 {'Master Baiter','/mb','Fishing settings and collection'},
 {'Atlas','/atlas','Map pin settings'},
 {'Loadout','/loadout','Character build and equipment'},
 {'House Directory','/houses','Owned houses and travel'},
 {'Chat Palette','/palette','Chat channel colours'},
 {'Atlas Mini Map','/minimap','Mini map settings'},
 {'Bind and Invite','/tgw','Binding and invite settings'},
 {'Skill Point Finder','/spf','Character skill point checklist'},
 {'Combat Recap','/recap','Recent fights and build snapshots'},
 {'Chat Keeper','/chatkeeper','Chat history and position'},
}
local function label(parent,x,y,width,text,font)
 local l=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL)
 l:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);l:SetDimensions(width,40)
 l:SetFont(font or 'ZoFontGamepad27');l:SetColor(.92,.92,.92,1);l:SetText(text)
 return l
end
local function open()
 if IsUnitInCombat('player') then d('Zaji: open after combat.');return end
 if not window then
  window=WINDOW_MANAGER:CreateTopLevelWindow('TGWZajiWindow')
  window:SetAnchor(CENTER,GuiRoot,CENTER,0,0);window:SetDimensions(1120,820);window:SetHidden(true)
  local bg=WINDOW_MANAGER:CreateControl(nil,window,CT_TEXTURE)
  bg:SetAnchorFill(window);bg:SetColor(.025,.03,.04,1)
  label(window,24,20,1000,'ZAJI | ADDON COMMAND KEY','ZoFontGamepadBold34')
  label(window,24,76,300,'ADDON');label(window,330,76,205,'COMMAND');label(window,545,76,550,'USE')
  for i,e in ipairs(entries) do
   local y=124+(i-1)*48
   local line=WINDOW_MANAGER:CreateControl(nil,window,CT_TEXTURE)
   line:SetAnchor(TOPLEFT,window,TOPLEFT,24,y+44);line:SetDimensions(1072,1);line:SetColor(.5,.55,.6,.45)
   label(window,24,y,300,e[1]);label(window,330,y,205,e[2]);label(window,545,y,550,e[3])
  end
  label(window,24,728,1072,'Type commands in text chat. /zaji opens this key.','ZoFontGamepad22')
  label(window,24,771,1072,'History: /chatkeeper history  |  Fishing HUD: /mbhud  |  @TheGreyWolf98','ZoFontGamepad22')
  keys={alignment=KEYBIND_STRIP_ALIGN_LEFT,{name='Close',keybind='UI_SHORTCUT_NEGATIVE',callback=function() SCENE_MANAGER:Hide('tgwZaji') end}}
  scene=ZO_Scene:New('tgwZaji',SCENE_MANAGER)
  scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
  scene:AddFragment(ZO_SimpleSceneFragment:New(window))
  scene:RegisterCallback('StateChange',function(_,state)
   if state==SCENE_SHOWING then KEYBIND_STRIP:AddKeybindButtonGroup(keys)
   elseif state==SCENE_HIDING then KEYBIND_STRIP:RemoveKeybindButtonGroup(keys) end
  end)
 end
 window:SetScale(math.min(1,GuiRoot:GetWidth()/1160,GuiRoot:GetHeight()/860))
 SCENE_MANAGER:Show('tgwZaji')
end
EVENT_MANAGER:RegisterForEvent('TGWZajiLoad',EVENT_ADD_ON_LOADED,function(_,name)
 if name~='Zaji' then return end
 EVENT_MANAGER:UnregisterForEvent('TGWZajiLoad',EVENT_ADD_ON_LOADED)
 SLASH_COMMANDS['/zaji']=open
end)
