PBF=PBF or {}
-- Every PB's game lives under one shared "Game Centre PX" entry in the gamepad main menu. The
-- first game to load creates it; the rest find it by name and add themselves underneath, so the
-- order the add-ons load in does not matter. Same shape as PBsTetris and PBsTradeGame.
local icon='EsoUI/Art/HUD/Gamepad/gp_radialIcon_duel_down.dds'
local function entry(data,id)
 local e=ZO_GamepadEntryData:New(data.name,data.icon);e.data=data;e.id=id;e:SetIconTintOnSelection(true);e:SetIconDisabledTintOnSelection(true);e:SetEnabled(true);return e
end
function PBF.EnsureMenu(app)
 if not ZO_MENU_ENTRIES then return end
 local parent,index
 for i,e in ipairs(ZO_MENU_ENTRIES) do
  if e.data and e.data.name=='ゲームセンターPX' then parent=e end
  if e.data and e.data.scene=='gamepad_options_root' then index=i end
 end
 if not parent then
  if not index then return end
  parent=entry({name='ゲームセンターPX',icon=icon,customTemplate='ZO_GamepadMenuEntryTemplateWithArrow',subMenu={}},'PBsPX')
  -- Inserted at the options entry rather than after it, which puts it between help and options.
  parent.subMenu={};table.insert(ZO_MENU_ENTRIES,index,parent)
 end
 parent.subMenu=parent.subMenu or {};parent.data.subMenu=parent.data.subMenu or {}
 for _,e in ipairs(parent.subMenu) do if e.id=='PBsFMEGA' or (e.data and e.data.name==PBF.ModeMenu.TITLE) then return end end
 -- Giving the entry a scene rather than a callback is what the menu itself does for Options and
 -- the rest: selecting it pushes that scene over the sub-menu.
 local data={name=PBF.ModeMenu.TITLE,icon=icon,customTemplate='ZO_GamepadMenuEntryTemplateWithArrow',scene=PBF.ModeMenu.SCENE}
 table.insert(parent.data.subMenu,data);table.insert(parent.subMenu,entry(data,'PBsFMEGA'))
end
function PBF.HookMenus(app)
 if not PBF.modeMenu and PBsFMEGAModeMenu then PBF.modeMenu=PBF.ModeMenu:New(PBsFMEGAModeMenu,app) end
 PBF.EnsureMenu(app)
 ZO_PreHook(MAIN_MENU_GAMEPAD,'RefreshMainList',function() PBF.EnsureMenu(app) end)
end
