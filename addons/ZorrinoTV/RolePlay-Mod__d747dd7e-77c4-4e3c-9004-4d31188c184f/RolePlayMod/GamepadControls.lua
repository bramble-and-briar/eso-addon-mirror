if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Scoped gamepad input. Dedicated action layers consume only RP buttons;
-- ImmersiveDialogue keeps X and native dialogue repeat keeps Y.
local R,B=RolePlayMod,IHR_Runtime.Beta
local G={};R.Gamepad=G
local activeLayer,buttonGroup,context,selection,focused
local suspended=false
local masks={}
local direction,nextMove,lastMode
local ownsStick=false
local held={}
local finishingHold=false
local holdReleaseAt,holdGuardLimit
local nativeButtons={}
local inputLog={down=0,up=0,last='aucune touche reçue',backMs=0,backSource='aucune',backResult='aucun retour',holdDown=0,holdUp=0}
local actionNames={confirm='UI_SHORTCUT_PRIMARY',back='UI_SHORTCUT_NEGATIVE',previous='UI_SHORTCUT_LEFT_SHOULDER',next='UI_SHORTCUT_RIGHT_SHOULDER',open='RPM_GP_OPEN',exit='RPM_GP_EXIT'}
local labels={RPM_GP_CONFIRM='Manette : valider',RPM_GP_BACK='Manette : retour',RPM_GP_PREVIOUS='Manette : page précédente',RPM_GP_NEXT='Manette : page suivante',
 RPM_GP_UP='Manette : haut',RPM_GP_DOWN='Manette : bas',RPM_GP_LEFT='Manette : gauche',RPM_GP_RIGHT='Manette : droite',RPM_GP_OPEN='Manette : ouvrir RolePlay Mod',RPM_GP_EXIT='Manette : maintenir pour quitter RolePlay Mod'}
for id,text in pairs(labels) do ZO_CreateStringId('SI_BINDING_NAME_'..id,text) end

function G.Enabled()
 return B.Native and B.Native.IsGamepadMode and B.Native.IsGamepadMode() or false
end
function G.IsSuspended() return suspended end
-- Consume the press and activate on release. Removing our layer after B/A
-- has completed cannot hand the same button's release to the native dialogue.
function G.Press() end
function G.Persuade()
 G.Refresh()
 if not context or suspended or context.kind=='entry' or context.kind=='wheel' then return false end
 local ui=B.ConversationUI
 if ui.current and ui.current.persuasion then ui.current.persuasion();return true end
 if R.Speechcraft and R.Speechcraft.Enabled() and B.npc then R.Speechcraft.Wheel.Show();return true end
 return false
end
local function closeForHold()
 if context and context.kind=='survival' and context.api.Back then context.api.Back() end
 B.Close()
end
local shortcuts={UI_SHORTCUT_PRIMARY='confirm',UI_SHORTCUT_NEGATIVE='back',
 UI_SHORTCUT_LEFT_SHOULDER='previous',UI_SHORTCUT_RIGHT_SHOULDER='next',
 UI_SHORTCUT_INPUT_UP='up',UI_SHORTCUT_INPUT_DOWN='down',UI_SHORTCUT_INPUT_LEFT='left',UI_SHORTCUT_INPUT_RIGHT='right'}
function G.InputDown(key,source)
 inputLog.down=inputLog.down+1;inputLog.last='appui '..tostring(key)
 G.Refresh()
 local ctx=G.Context();local action=shortcuts[key]
 if action=='back' and finishingHold then return true end
 if not action or not ctx or ctx.kind=='entry' then return false end
 if G.IsSuspended() then return true end
 if action=='back' and not held.back then
  inputLog.backSource=source or 'XML';inputLog.backMs=0;inputLog.backResult='appui en cours'
 end
 held[action]=held[action] or {time=GetFrameTimeMilliseconds()};return true
end
function G.InputUp(key)
 inputLog.up=inputLog.up+1;inputLog.last='relâchement '..tostring(key)
 G.Refresh()
 local action=shortcuts[key];local press=action and held[action]
 if not action then return false end
 if action=='back' and finishingHold then return true end
 held[action]=nil
 local ctx=G.Context()
 if not ctx or ctx.kind=='entry' then G.Refresh();return press~=nil end
 if suspended then return true end
 -- Both inherited XML actions and the native shortcut strip can deliver a
 -- release. Only a press we recorded may perform a navigation action.
 if not press then return true end
 local elapsed=press and GetFrameTimeMilliseconds()-press.time or 0
 if action=='back' then inputLog.backMs=elapsed end
 if press and press.done then return true end
 if action=='back' then
  inputLog.backResult=elapsed>=700 and 'sortie chronométrée' or 'retour court'
  if elapsed>=700 then closeForHold() else G.Back() end
 elseif action=='confirm' then G.Confirm()
 elseif action=='previous' then G.Page(-1)
 elseif action=='next' then G.Page(1)
 else G.Move(action) end
 return true
end
-- ESO exposes a separate HOLD keycode. A shortcut press can be deferred until
-- release by hold/chord arbitration, so its Down/Up duration is not sufficient
-- to recognise every physical long press. Let the engine recognise this one.
function G.ExitHoldDown()
 inputLog.holdDown=inputLog.holdDown+1
 G.Refresh()
 local alreadyClosed=held.back and held.back.done
 if not G.Enabled() or suspended or (not alreadyClosed and (not context or context.kind=='entry')) then return true end
 local press=held.back
 inputLog.backMs=press and GetFrameTimeMilliseconds()-press.time or 0
 inputLog.backSource='HOLD moteur';inputLog.backResult='sortie par maintien moteur'
 finishingHold=true;holdReleaseAt=nil;holdGuardLimit=GetFrameTimeMilliseconds()+5000
 if press then press.done=true end
 closeForHold();return true
end
function G.ExitHoldUp()
 inputLog.holdUp=inputLog.holdUp+1
 -- A deferred short B can follow the HOLD release in the same frame. Keep
 -- its layer briefly so that it cannot dismiss the restored NPC dialogue.
 if finishingHold then holdReleaseAt=GetFrameTimeMilliseconds()+150 end
 held.back=nil
 G.Refresh();return true
end
local function visible(c) return c and type(c.IsHidden)=='function' and not c:IsHidden() end
local function click(c)
 if not visible(c) then return false end
 local callback=type(c.GetHandler)=='function' and c:GetHandler('OnClicked') or type(c)=='table' and c.OnClicked
 if type(callback)~='function' then return false end
 callback(c,MOUSE_BUTTON_INDEX_LEFT or 1);return true
end
local function sceneAllowed()
 if not SCENE_MANAGER or type(SCENE_MANAGER.GetCurrentScene)~='function' then return true end
 local scene=SCENE_MANAGER:GetCurrentScene();local name=scene and scene:GetName() or ''
 return name=='hud' or name=='hudui' or name=='interact' or name=='gamepadInteract'
end
function G.Context()
 if not G.Enabled() then return end
 local survival=RolePlayNeeds and RolePlayNeeds.GamepadWheel
 if survival and survival.IsOpen() then return {kind='survival',root=MyFakeRadial,api=survival} end
 local book=B.TravelJournal
 if book and book.IsOpen() then
  local ctx=book.GetGamepadContext and book.GetGamepadContext() or {}
  return {kind='book',root=ctx.root,api=book}
 end
 local ui=B.ConversationUI
 if B.IsOpen() and ui and ui.current and visible(ui.Controls.frame) then
  local kind=ui.current.custom and ui.current.kind or 'conversation'
  if kind=='speechcraft' then kind='wheel' end
  return {kind=kind or 'conversation',root=ui.Controls.frame,view=ui.current}
 end
 if B.Native.CanOpenEntry() then
  return {kind='entry'}
 end
end
local function targets(ctx)
 local result={}
 if ctx.kind=='dice' then
  local root=B.DiceVisual.gamepadControl
  if root and visible(root.continueButton) then result[1]={control=root.continueButton,label='Continuer',callback=function() click(root.continueButton) end} end
  return result
 end
 if ctx.kind~='conversation' then return result end
 local ui=B.ConversationUI
 for _,row in ipairs(ui.Controls.rows) do
  local choice=row.rpmChoice
  if visible(row) and choice then result[#result+1]={control=row,label=choice.text,callback=choice.callback} end
 end
 for _,name in ipairs({'journal','persuasion'}) do
  local c=ui.Controls.footer[name]
  if visible(c) then result[#result+1]={control=c,label=c.rpmTooltip,callback=function() click(c) end} end
 end
 return result
end
local function clearFocus()
 if focused and focused.lines then for _,line in ipairs(focused.lines) do line:SetHidden(true) end end
 local ui=B.ConversationUI
 if ui and ui.GamepadSelect then ui.GamepadSelect(nil) end
 focused=nil
 local wheel=R.Speechcraft and R.Speechcraft.Wheel
 if wheel and wheel.GamepadClearFocus then wheel.GamepadClearFocus() end
 if B.TravelJournal and B.TravelJournal.GamepadClearFocus then B.TravelJournal.GamepadClearFocus() end
 local radial=RolePlayNeeds and RolePlayNeeds.GamepadWheel
 if radial and radial.ClearFocus then radial.ClearFocus() end
end
local function focus(item)
 if focused and focused.control==item.control then
  local ui=B.ConversationUI
  if item.control.choiceLabel and ui and ui.GamepadSelect then ui.GamepadSelect(item.control) end
  return
 end
 if focused and focused.lines then for _,line in ipairs(focused.lines) do line:SetHidden(true) end end
 local c=item.control
 local ui=B.ConversationUI
 if ui and ui.GamepadSelect then
  ui.GamepadSelect(c.choiceLabel and c or nil)
  if c.choiceLabel then focused={control=c};return end
 end
 if not c.rpmGamepadLines then
  c.rpmGamepadLines={}
  for i=1,2 do
   local line=WINDOW_MANAGER:CreateControl(nil,c,CT_TEXTURE)
   line:SetTexture('RolePlayMod/ui/conversation/question-rule.dds');line:SetColor(.9,.88,.8,.9);line:SetMouseEnabled(false)
   c.rpmGamepadLines[i]=line
  end
 end
 for i,line in ipairs(c.rpmGamepadLines) do
  line:ClearAnchors();line:SetAnchor(TOPLEFT,c,TOPLEFT,0,i==1 and 0 or c:GetHeight()-1)
  line:SetDimensions(c:GetWidth(),1);line:SetHidden(false)
 end
 focused={control=c,lines=c.rpmGamepadLines}
end
local function restoreMasks()
 for c,alpha in pairs(masks) do c:SetAlpha(alpha) end
 masks={}
end
local function mask(c)
 if not c or masks[c]~=nil then return end
 local alpha=type(c.GetAlpha)=='function' and c:GetAlpha() or 1
 masks[c]=type(alpha)=='number' and alpha or 1;c:SetAlpha(0)
end
local function setLayer(name)
 if activeLayer==name then
  -- Scenes can remove an input layer without changing our cached name.
  if name and type(IsActionLayerActiveByName)=='function' and not IsActionLayerActiveByName(name) then PushActionLayerByName(name) end
  return
 end
 if activeLayer and type(RemoveActionLayerByName)=='function' then RemoveActionLayerByName(activeLayer) end
 activeLayer=name
 if name and type(PushActionLayerByName)=='function' then PushActionLayerByName(name) end
end
local function clearButtons()
 if buttonGroup and KEYBIND_STRIP and type(KEYBIND_STRIP.RemoveKeybindButtonGroup)=='function' then KEYBIND_STRIP:RemoveKeybindButtonGroup(buttonGroup) end
 buttonGroup=nil
end
local function selectionLabel()
 local ctx=context
 if not ctx then return 'Sélectionner' end
 if ctx.kind=='wheel' then return R.Speechcraft.Wheel.GamepadLabel() end
 if ctx.kind=='book' then return B.TravelJournal.GamepadLabel() end
 if ctx.kind=='survival' then return ctx.api.Label() end
 if ctx.kind=='conversation' then return 'Sélectionner' end
 local items=targets(ctx);local item=items[selection or 1]
 return item and item.label or (ctx.kind=='dice' and 'Lancer en cours…' or 'Sélectionner')
end
local function buttons(ctx)
 clearButtons()
 if not KEYBIND_STRIP or type(KEYBIND_STRIP.AddKeybindButtonGroup)~='function' then return end
 if ctx.kind=='entry' then
  buttonGroup={alignment=KEYBIND_STRIP_ALIGN_RIGHT,{name='RolePlay Mod',keybind=actionNames.open,callback=G.Open}}
 else
  buttonGroup={alignment=KEYBIND_STRIP_ALIGN_LEFT,
   {name=selectionLabel,keybind=actionNames.confirm,callback=G.Confirm,enabled=function() return not suspended and selectionLabel()~='Lancer en cours…' end},
   {name='Retour / maintenir : quitter',keybind=actionNames.back,handlesKeyUp=true,callback=function(up)
    -- ESO's shortcut strip otherwise calls a callback immediately on Down.
    -- Use the same press/release path as our XML action, so B can be held.
    if up then G.InputUp(actionNames.back) else G.InputDown(actionNames.back,'barre native') end
   end,enabled=function() return not suspended end},
   {name=function() return context and context.kind=='survival' and 'Choix précédent' or 'Page précédente' end,keybind=actionNames.previous,callback=function() G.Page(-1) end,visible=function() return context and context.kind~='wheel' and context.kind~='dice' end,enabled=function() return not suspended end},
   {name=function() return context and context.kind=='survival' and 'Choix suivant' or 'Page suivante' end,keybind=actionNames.next,callback=function() G.Page(1) end,visible=function() return context and context.kind~='wheel' and context.kind~='dice' end,enabled=function() return not suspended end}}
 end
 KEYBIND_STRIP:AddKeybindButtonGroup(buttonGroup)
end
local function nativeCommands(active)
 if not KEYBIND_STRIP then return end
 if active and type(KEYBIND_STRIP.RemoveKeybindButton)=='function' then
  local seen={}
  local function visit(value,depth)
   if type(value)~='table' or seen[value] or value==buttonGroup or depth>3 then return end
   seen[value]=true
   if value.keybind=='UI_SHORTCUT_PRIMARY' or value.keybind=='UI_SHORTCUT_NEGATIVE' then
    if not nativeButtons[value] then nativeButtons[value]=true;KEYBIND_STRIP:RemoveKeybindButton(value) end
    return
   end
   for _,child in pairs(value) do if type(child)=='table' then visit(child,depth+1) end end
  end
  visit(GAMEPAD_INTERACTION,0)
 elseif not active then
  for descriptor in pairs(nativeButtons) do
   if B.Native.IsConversing() and type(KEYBIND_STRIP.AddKeybindButton)=='function' then KEYBIND_STRIP:AddKeybindButton(descriptor) end
  end
  nativeButtons={}
 end
end
function G.Refresh(reset)
 local next=G.Context()
 local changed=(context==nil)~=(next==nil) or context and next and (context.kind~=next.kind or context.root~=next.root or context.view~=next.view)
 if changed or reset then clearFocus();selection=1;direction=nil;nextMove=nil end
 context=next
 local frame=B.ConversationUI and B.ConversationUI.Controls and B.ConversationUI.Controls.frame
 local book=B.TravelJournal and B.TravelJournal.GetGamepadContext and B.TravelJournal.GetGamepadContext()
 for _,owned in ipairs({frame or false,book and book.root or false}) do
  if owned and type(owned.SetKeyboardEnabled)=='function' then
   owned:SetKeyboardEnabled(not B.Native.IsGamepadMode())
  end
 end
 local allowed=sceneAllowed()
 if not G.Enabled() or not allowed or finishingHold and (
  holdReleaseAt and GetFrameTimeMilliseconds()>=holdReleaseAt
  or holdGuardLimit and GetFrameTimeMilliseconds()>=holdGuardLimit) then
  finishingHold=false;holdReleaseAt=nil;holdGuardLimit=nil
  if not G.Enabled() or not allowed then held={} end
 end
 suspended=next~=nil and next.kind~='entry' and (not allowed or (B.nativeSession and not B.Native.DialogueVisible())) or false
 if suspended then
  if held.back and not held.back.done then
   inputLog.backMs=GetFrameTimeMilliseconds()-held.back.time;inputLog.backResult='annulé : dialogue masqué ou autre écran'
  end
  held={}
 end
 if suspended then
  if next then mask(next.root) end
  if B.ConversationUI and B.ConversationUI.Controls then mask(B.ConversationUI.Controls.scrim) end
 else restoreMasks() end
 local wheel=R.Speechcraft and R.Speechcraft.Wheel
 if wheel and wheel.PauseInput then wheel.PauseInput(suspended) end
 -- Keep the held B release in our layer after a long-press close. Otherwise
 -- its Up would reach the restored native Back and close that dialogue too.
 local finishingBack=G.Enabled() and (finishingHold or held.back and held.back.done)
 setLayer(finishingBack and 'RPMGamepadUI' or next and allowed and (next.kind=='entry' and 'RPMGamepadEntry' or 'RPMGamepadUI') or nil)
 local consume=next~=nil and next.kind~='entry' and allowed
 if consume~=ownsStick then
  if type(SetGamepadLeftStickConsumedByUI)=='function' then SetGamepadLeftStickConsumedByUI(consume) end
  ownsStick=consume
 end
 if next and next.kind~='entry' and allowed then nativeCommands(true) end
 if not next or not allowed then clearButtons()
 elseif changed or reset or not buttonGroup then
  buttons(next)
 elseif buttonGroup and KEYBIND_STRIP and type(KEYBIND_STRIP.UpdateKeybindButtonGroup)=='function' then KEYBIND_STRIP:UpdateKeybindButtonGroup(buttonGroup) end
 if not next or next.kind=='entry' or not allowed then nativeCommands(false) end
 if next and not suspended and next.kind~='entry' then
  local items=targets(next)
  if #items>0 then selection=math.max(1,math.min(selection or 1,#items));focus(items[selection]) end
 end
end
function G.Open()
 if not G.Enabled() or not sceneAllowed() or B.IsOpen() then return false end
 if finishingHold then return false end
 if not B.Native.CanOpenEntry() then return false end
 B.Open(true);G.Refresh(true);return B.IsOpen()
end
function G.Move(dir)
 G.Refresh()
 if not context or context.kind=='entry' or suspended then return false end
 if context.kind=='wheel' then return R.Speechcraft.Wheel.GamepadMove(dir) end
 if context.kind=='book' then local ok=B.TravelJournal.GamepadMove(dir);G.Refresh();return ok end
 if context.kind=='survival' then local ok=context.api.Move(dir);G.Refresh();return ok end
 local items=targets(context);if #items==0 then return false end
 selection=((selection or 1)-1+((dir=='up' or dir=='left') and -1 or 1))%#items+1;focus(items[selection])
 return true
end
function G.Confirm()
 G.Refresh()
 if not context or suspended then return false end
 if context.kind=='entry' then return G.Open() end
 if context.kind=='wheel' then local ok=R.Speechcraft.Wheel.GamepadConfirm();G.Refresh();return ok end
 if context.kind=='book' then local ok=B.TravelJournal.GamepadConfirm();G.Refresh();return ok end
 if context.kind=='survival' then local ok=context.api.Confirm();G.Refresh(true);return ok end
 local item=targets(context)[selection or 1]
 if not item then return false end
 item.callback();G.Refresh(true);return true
end
function G.Back()
 G.Refresh()
 if not context or context.kind=='entry' or suspended then return false end
 if context.kind=='wheel' then R.Speechcraft.Wheel.GamepadBack()
 elseif context.kind=='book' then B.TravelJournal.GamepadBack()
 elseif context.kind=='survival' then context.api.Back()
 elseif B.ConversationUI.current.isHome then B.Close()
 else B.ConversationUI.Back() end
 G.Refresh(true);return true
end
function G.Page(delta)
 G.Refresh()
 if not context or suspended then return false end
 local ok=false
 if context.kind=='book' then ok=B.TravelJournal.GamepadPage(delta)
 elseif context.kind=='survival' and context.api.Page then ok=context.api.Page(delta)
 elseif context.kind=='conversation' then
  local ui=B.ConversationUI
  local c=ui.textPageCount>1 and (delta<0 and ui.Controls.prevText or ui.Controls.nextText)
   or (delta<0 and ui.Controls.prevPage or ui.Controls.nextPage)
  ok=click(c)
 end
 G.Refresh(true);return ok
end
function G.ToggleSurvival()
 if not G.Enabled() or not sceneAllowed() then return false end
 local api=RolePlayNeeds.GamepadWheel
 if not api then return false end
 local ok=api.Toggle();G.Refresh(true);return ok
end
local function tick()
 G.Refresh()
 if not context or context.kind=='entry' or suspended or not sceneAllowed() then direction=nil;return end
 local now=GetFrameTimeMilliseconds()
 local press=held.back
 if press and not press.done and now-press.time>=700 then
  inputLog.backMs=now-press.time;inputLog.backResult='sortie chronométrée'
  press.done=true;closeForHold();return
 end
 local x=type(GetGamepadLeftStickX)=='function' and GetGamepadLeftStickX(true) or 0
 local y=type(GetGamepadLeftStickY)=='function' and GetGamepadLeftStickY(true) or 0
 local rx=type(GetGamepadRightStickX)=='function' and GetGamepadRightStickX(true) or 0
 local ry=type(GetGamepadRightStickY)=='function' and GetGamepadRightStickY(true) or 0
 if math.max(math.abs(rx),math.abs(ry))>math.max(math.abs(x),math.abs(y)) then x,y=rx,ry end
 if math.max(math.abs(x),math.abs(y))<.5 then direction=nil;nextMove=nil;return end
 local dir=math.abs(x)>math.abs(y) and (x<0 and 'left' or 'right') or (y>0 and 'up' or 'down')
 if context.kind=='survival' and math.abs(x)>.45 and math.abs(y)>.45 then dir=(y>0 and 'up' or 'down')..'-'..(x<0 and 'left' or 'right') end
 local now=GetFrameTimeMilliseconds()
 if dir~=direction or not nextMove or now>=nextMove then
  G.Move(dir);nextMove=now+(dir==direction and 180 or 350);direction=dir
 end
end
local function initialize()
 -- A HOLD binding is an actual ESO keycode, not a simulated button or a
 -- private IsKeyDown poll. It exists only in our active conversation layer.
 local backKey=KEY_GAMEPAD_BUTTON_2
 if type(GetHighestPriorityActionBindingInfoFromName)=='function' and type(IsKeyCodeGamepadKey)=='function' then
  local candidate=GetHighestPriorityActionBindingInfoFromName(actionNames.back,true)
  if type(candidate)=='number' and IsKeyCodeGamepadKey(candidate) then backKey=candidate end
 end
 local holdKey=type(ConvertKeyPressToHold)=='function' and ConvertKeyPressToHold(backKey) or KEY_GAMEPAD_BUTTON_2_HOLD
 if type(CreateDefaultActionBind)=='function' and type(holdKey)=='number' and holdKey~=KEY_INVALID then
  pcall(CreateDefaultActionBind,actionNames.exit,holdKey,KEY_INVALID or 0,KEY_INVALID or 0,KEY_INVALID or 0,KEY_INVALID or 0)
 end
 EVENT_MANAGER:RegisterForUpdate('RPMGamepadControls',75,tick)
 for _,fragment in ipairs({GAMEPAD_INTERACT_FRAGMENT or false,INTERACT_FRAGMENT or false}) do
  if fragment and type(fragment.RegisterCallback)=='function' then fragment:RegisterCallback('StateChange',function() G.Refresh() end) end
 end
 lastMode=G.Enabled();G.Refresh()
end
function G.Diagnostics()
 local ctx=G.Context()
 local layer=activeLayer and (type(IsActionLayerActiveByName)~='function' or IsActionLayerActiveByName(activeLayer)) or false
 return {version=R.version,gamepad=G.Enabled(),context=ctx and ctx.kind or 'fermé',
  layer=activeLayer or 'aucune',layerActive=not not layer,suspended=suspended,
  down=inputLog.down,up=inputLog.up,last=inputLog.last,backMs=inputLog.backMs,backSource=inputLog.backSource,
  backResult=inputLog.backResult,holdDown=inputLog.holdDown,holdUp=inputLog.holdUp}
end
if SLASH_COMMANDS then SLASH_COMMANDS['/rpmpad']=function()
 local info=G.Diagnostics()
 d('[RolePlayMod '..tostring(info.version)..'] '..info.context..' ; couche '..info.layer..' active : '..tostring(info.layerActive)..' ; suspendu : '..tostring(info.suspended))
 d('Touches reçues : '..info.down..' appuis, '..info.up..' relâchements ; '..info.last)
 d('Dernier B : '..info.backMs..' ms ; '..info.backSource..' ; '..info.backResult..' ; HOLD : '..info.holdDown..' appuis / '..info.holdUp..' relâchements')
end end
local show,close,custom=B.Show,B.Close,B.ShowCustomContent
function B.Show(...) local result=show(...);G.Refresh(true);return result end
function B.ShowCustomContent(...) local result=custom(...);G.Refresh(true);return result end
function B.Close(...) local result=close(...);G.Refresh(true);return result end
local checkNeeds=RPN_CheckNeeds
function RPN_CheckNeeds(...)
 if G.Enabled() then return G.ToggleSurvival() end
 if checkNeeds then return checkNeeds(...) end
end
EVENT_MANAGER:RegisterForEvent('RPMGamepadInit',EVENT_ADD_ON_LOADED,function(_,name)
 if name~=R.name then return end
 initialize();EVENT_MANAGER:UnregisterForEvent('RPMGamepadInit',EVENT_ADD_ON_LOADED)
end)
if EVENT_GAMEPAD_PREFERRED_MODE_CHANGED then EVENT_MANAGER:RegisterForEvent('RPMGamepadMode',EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,function()
 local mode=G.Enabled()
 if mode~=lastMode and B.nativeSession and B.Native.IsConversing() then B.Native.Restore();B.Native.Begin() end
 lastMode=mode
 if B.ConversationUI then B.ConversationUI.Relayout() end
 G.Refresh(true)
end) end
