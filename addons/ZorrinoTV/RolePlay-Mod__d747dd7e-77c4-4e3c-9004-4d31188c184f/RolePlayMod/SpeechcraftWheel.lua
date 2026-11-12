if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
local R=RolePlayMod
local B=IHR_Runtime.Beta
local S=R.Speechcraft
local W={};S.Wheel=W
local root,centre,deltaLabel,done,exitButton
local cards,numbers,edges,masks,hits,bars={},{},{},{},{},{}
local busy=false;local generation=0;local npc,game,hovered
local gamepadFocused,inputPaused=nil,false
local colors={{.39,.71,.42,1},{.36,.63,.69,1},{.74,.30,.27,1},{.80,.64,.30,1}}
local expressions={'Sourit','S’intéresse','Se renfrogne','Se crispe'}
local path='RolePlayMod/ui/speechcraft/'
local function label(parent,text,font,x,y,w,h)
 local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL);c:SetFont(font);c:SetText(text);c:SetDimensions(w,h);c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);c:SetHorizontalAlignment(TEXT_ALIGN_CENTER);c:SetMouseEnabled(false);return c
end
local function cell(index)
 index=index%64
 -- Geometry rotates; each fixed sector tints only the bars passing through it.
 for id=1,4 do bars[id]:SetTextureCoords((index%8)/8,(index%8+1)/8,math.floor(index/8)/8,(math.floor(index/8)+1)/8) end
end
local function suspended()
 local controller=R.Gamepad
 return inputPaused or controller and type(controller.IsSuspended)=='function' and controller.IsSuspended() or false
end
local function valid()
 local ui=B.ConversationUI
 local hiddenWheel=suspended() and ui and ui.current and ui.current.custom and ui.current.kind=='speechcraft'
 return npc and game and S.active and S.active.game==game and S.Enabled() and B.npc==npc and (B.IsOpen() or hiddenWheel)
end
local function interactive()
 if not root or busy or not game or game.turn>4 then return false end
 if suspended() then return false end
 local ui=B.ConversationUI;if ui and ui.IsWheelDragging and ui.IsWheelDragging() then return false end
 if root.IsControlHidden and root:IsControlHidden() then return false end
 local scene=SCENE_MANAGER:GetCurrentScene();local name=scene and scene:GetName() or ''
 return name=='hud' or name=='hudui' or name=='interact' or name=='gamepadInteract'
end
function W.ResumeAfterDrag()
 if valid() then S.Ready(interactive()) end
end
function W.Hide()
 local ui=B.ConversationUI;if ui and ui.EndWheelDrag then ui.EndWheelDrag() end
 generation=generation+1;busy=false;hovered=nil;gamepadFocused=nil;inputPaused=false
 EVENT_MANAGER:UnregisterForUpdate('RPMSpeechTimer');EVENT_MANAGER:UnregisterForUpdate('RPMSpeechRotation')
 S.Stop();npc=nil;game=nil
 if root then root:SetHidden(true) end
end
local function face(id,show,state)
 if not valid() then return end
 state=state or S.State(npc);local c=cards[id];local preference=state.preferences[id]
 local known=state.known[id]~=nil
 c.face:SetHidden(not (show or known))
 c.face:SetTextureCoords((preference-1)/4,preference/4,0,1)
 c.face:SetColor(unpack(known and colors[preference] or {.8,.77,.67,1}))
 c.hint:SetText(known and S.reactions[preference] or show and expressions[preference] or 'À découvrir')
 c.hint:SetColor(unpack(known and colors[preference] or {.75,.71,.62,1}))
end
function W.Render()
 if not valid() then W.Hide();return end
 local state=S.State(npc);local completed=game.turn>4
 centre:SetText(tostring(state.trust))
 deltaLabel:SetHidden(not completed or busy)
 if completed and not busy then
  local delta=game.total or 0
  deltaLabel:SetText(string.format('%+d',delta))
  if delta>0 then deltaLabel:SetColor(.45,.9,.42,1)
  elseif delta<0 then deltaLabel:SetColor(1,.30,.25,1)
  else deltaLabel:SetColor(.70,.67,.59,1) end
  local width=tonumber(centre.GetTextWidth and centre:GetTextWidth()) or #tostring(state.trust)*14
  deltaLabel:ClearAnchors();deltaLabel:SetAnchor(LEFT,centre,CENTER,width/2+8,0)
 end
 for id=1,4 do
  local known=state.known[id];local used=game.used[id] or completed;local strength=S.Strength(game,id)
  edges[id]:SetColor(.32,.30,.26,1)
  bars[id]:SetColor(unpack(used and {.32,.32,.32,1} or known and colors[known] or {.70,.67,.59,1}))
  masks[id]:SetHidden(not used)
  cards[id]:SetMouseEnabled(not used and not busy);hits[id]:SetMouseEnabled(not used and not busy);cards[id]:SetAlpha(used and .42 or 1)
  -- The gray bars already identify a played approach; avoid duplicate text.
  cards[id].intensity:SetText('')
  local focused=gamepadFocused==id and not busy and not used and not suspended()
  for _,line in ipairs(cards[id].gamepadLines or {}) do line:SetHidden(not focused) end
  face(id,(hovered==id or focused) and not busy and not used,state);numbers[id]:SetText(tostring(strength));numbers[id]:SetHidden(true)
 end
 done.rpmTooltip=completed and (S.pendingSubject and 'Reprendre ma question' or 'Revenir à la conversation') or 'Interrompre la persuasion'
 if not busy then cell(game.offset*16) end
 B.RefreshCustomStatus()
end
local function tick()
 if not valid() then W.Hide();return end
 if not interactive() then
  if S.active then S.active.ready=false;S.active.last=GetFrameTimeMilliseconds() end
  return
 end
 if S.active and not S.active.ready then S.Ready(true) end
 if S.Tick()>0 then W.Render() end
end
function W.Choose(id)
 if busy or not valid() or not interactive() then return false end
 local start=game.offset*16;local turn=game.turn
 if not S.Play(id,turn) then return false end
 if gamepadFocused==id then gamepadFocused=nil end
 busy=true;W.Render();cell(start)
 local token=generation;local started=GetFrameTimeMilliseconds()
 EVENT_MANAGER:RegisterForUpdate('RPMSpeechRotation',16,function()
  if token~=generation or not valid() then EVENT_MANAGER:UnregisterForUpdate('RPMSpeechRotation');return end
  local t=math.min(1,(GetFrameTimeMilliseconds()-started)/650);local eased=t*t*(3-2*t)
  cell(start+math.floor(eased*16+.5))
  if t>=1 then
   EVENT_MANAGER:UnregisterForUpdate('RPMSpeechRotation');busy=false
   S.Ready(interactive());if game.turn>4 then EVENT_MANAGER:UnregisterForUpdate('RPMSpeechTimer') end;W.Render()
  end
 end)
 return true
end
local function returnFromWheel()
 local pending=game and game.turn>4 and S.pendingSubject or nil;W.Hide()
 if pending then B.Dice.Ask(pending)
 else
  S.pendingSubject=nil
  local ui=B.ConversationUI
  if ui and ui.Back then ui.Back() else B.ShowHome() end
 end
 return true
end
-- The controller owns the hardware bindings. This view exposes only semantic
-- focus and actions, so moving the stick never counts as a persuasion choice.
local gamepadDirections={up=1,right=2,down=3,left=4}
function W.GamepadMove(direction)
 local id=gamepadDirections[direction]
 if not id or not valid() or not interactive() or game.used[id] then return false end
 gamepadFocused=id;hovered=nil;W.Render();return true
end
function W.GamepadConfirm()
 if not valid() or suspended() or busy then return false end
 if game.turn>4 then return returnFromWheel() end
 if not gamepadFocused then return false end
 return W.Choose(gamepadFocused)
end
function W.GamepadBack()
 if not valid() or suspended() then return false end
 return returnFromWheel()
end
function W.GamepadClearFocus()
 gamepadFocused=nil
 if valid() then W.Render() end
end
function W.GamepadLabel()
 if not valid() then return '' end
 if game.turn>4 then return S.pendingSubject and 'Reprendre ma question' or 'Revenir à la conversation' end
 return gamepadFocused and S.actions[gamepadFocused] or 'Choisir une approche'
end
function W.GamepadFocusState() return gamepadFocused,busy,game and game.turn or nil end
function W.GetGamepadRoot() return root end
function W.PauseInput(paused)
 local value=not not paused
 if inputPaused==value then return end
 inputPaused=value
 if S.active then S.Ready(false) end
 if valid() then W.Render();if not value then S.Ready(interactive()) end end
end
local function button(parent,name,text,x,y,w,h,callback)
 local c=WINDOW_MANAGER:CreateControl(name,parent,CT_BUTTON);c:SetDimensions(w,h);c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);c:SetFont('ZoFontGamepad22');c:SetText(text);c:SetMouseEnabled(true);c:SetNormalFontColor(.92,.85,.70,1);c:SetMouseOverFontColor(1,1,1,1);c:SetHandler('OnClicked',callback)
 local ui=B.ConversationUI;if ui and ui.BindWheelDrag then ui.BindWheelDrag(c,callback) end
 return c
end
local function iconButton(parent,name,icon,tooltip,x,y,callback)
 local ui=B.ConversationUI
 local c
 if ui and ui.CreateIconButton then
  c=ui.CreateIconButton(parent,icon,tooltip,callback,34)
 else
  c=button(parent,name,'',x,y,34,34,callback)
  local image=WINDOW_MANAGER:CreateControl(nil,c,CT_TEXTURE)
  image:SetAnchorFill();image:SetTexture('RolePlayMod/ui/conversation/'..icon..'.dds');image:SetMouseEnabled(false)
  c:SetHandler('OnMouseEnter',function()
   image:SetColor(1,1,1,1)
   if type(InitializeTooltip)=='function' and InformationTooltip and type(SetTooltipText)=='function' then
    InitializeTooltip(InformationTooltip,c,BOTTOM,0,-5,TOP);SetTooltipText(InformationTooltip,c.rpmTooltip or tooltip)
   end
  end)
  c:SetHandler('OnMouseExit',function()
   image:SetColor(.86,.82,.72,1)
   if type(ClearTooltip)=='function' and InformationTooltip then ClearTooltip(InformationTooltip) end
  end)
  image:SetColor(.86,.82,.72,1)
 end
 c.rpmTooltip=tooltip
 c:ClearAnchors();c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
 if ui and ui.BindWheelDrag then ui.BindWheelDrag(c,callback) end
 return c
end
local function create(parent)
 if root then return end
 -- The shared conversation parent scales this whole view to the safe 16:9 area.
 -- A compact local canvas leaves the NPC unobscured on the left at every ratio.
 root=WINDOW_MANAGER:CreateControl('RPMSpeechcraftWheel',parent,CT_CONTROL);root:SetDimensions(600,475);root:SetAnchor(TOPLEFT,parent,TOPLEFT,0,30)
 root:SetMouseEnabled(true)
 if B.ConversationUI and B.ConversationUI.BindWheelDrag then B.ConversationUI.BindWheelDrag(root) end
 for id=1,4 do
  bars[id]=WINDOW_MANAGER:CreateControl('RPMSpeechBars'..id,root,CT_TEXTURE);bars[id]:SetTexture(path..'bars-'..id..'.dds');bars[id]:SetDimensions(280,280);bars[id]:SetAnchor(TOPLEFT,root,TOPLEFT,160,90);bars[id]:SetMouseEnabled(false)
 end
 for id=1,4 do
  edges[id]=WINDOW_MANAGER:CreateControl('RPMSpeechEdge'..id,root,CT_TEXTURE);edges[id]:SetTexture(path..'preference-'..id..'.dds');edges[id]:SetDimensions(280,280);edges[id]:SetAnchor(TOPLEFT,root,TOPLEFT,160,90);edges[id]:SetMouseEnabled(false)
  masks[id]=WINDOW_MANAGER:CreateControl(nil,root,CT_TEXTURE);masks[id]:SetTexture(path..'used-'..id..'.dds');masks[id]:SetDimensions(280,280);masks[id]:SetAnchor(TOPLEFT,root,TOPLEFT,160,90);masks[id]:SetAlpha(.20);masks[id]:SetMouseEnabled(false)
 end
 local positions={{220,4},{440,196},{220,377},{0,196}}
 local numberPositions={{274,122},{376,211},{274,314},{172,211}}
 local hitPositions={{239,98,122,70},{370,168,70,123},{239,290,122,70},{160,168,70,123}}
 for id=1,4 do
  local action=id;local x,y=unpack(positions[id])
  local card=button(root,'RPMSpeechAction'..id,'',x,y,160,62,function() W.Choose(action) end)
  label(card,S.actions[id],'ZoFontGamepad22',0,0,160,27)
  card.hint=label(card,'','ZoFontGamepad18',26,32,132,24);card.intensity=label(card,'','ZoFontGamepad18',0,58,160,0);card.intensity:SetHidden(true)
  card.face=WINDOW_MANAGER:CreateControl(nil,card,CT_TEXTURE);card.face:SetTexture(path..'reactions.dds');card.face:SetDimensions(22,22);card.face:SetAnchor(TOPLEFT,card,TOPLEFT,2,32);card.face:SetMouseEnabled(false)
  card.gamepadLines={}
  for lineIndex=1,2 do
   local line=WINDOW_MANAGER:CreateControl(nil,card,CT_TEXTURE)
   line:SetTexture('RolePlayMod/ui/conversation/question-rule.dds');line:SetColor(.9,.88,.8,.85)
   line:SetDimensions(160,1);line:SetAnchor(TOPLEFT,card,TOPLEFT,0,lineIndex==1 and -3 or 61)
   line:SetMouseEnabled(false);line:SetHidden(true);card.gamepadLines[lineIndex]=line
  end
  card:SetHandler('OnMouseEnter',function() if not busy and valid() and not game.used[action] then hovered=action;face(action,true) end end)
  card:SetHandler('OnMouseExit',function() if hovered==action then hovered=nil end;if valid() then face(action,gamepadFocused==action) end end)
  cards[id]=card
  local hx,hy,hw,hh=unpack(hitPositions[id]);local hit=button(root,nil,'',hx,hy,hw,hh,function() W.Choose(action) end)
  hit:SetHandler('OnMouseEnter',function() if not busy and valid() and not game.used[action] then hovered=action;face(action,true) end end)
  hit:SetHandler('OnMouseExit',function() if hovered==action then hovered=nil end;if valid() then face(action,gamepadFocused==action) end end);hits[id]=hit
  local nx,ny=unpack(numberPositions[id]);numbers[id]=label(root,'','ZoFontGamepadBold27',nx,ny,52,38)
 end
 centre=label(root,'','ZoFontGamepadBold27',242,208,116,44)
 deltaLabel=label(root,'','ZoFontGamepadBold27',325,208,62,44)
 deltaLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT);deltaLabel:SetHidden(true)
 done=iconButton(root,'RPMSpeechContinue','back','Interrompre la persuasion',14,435,returnFromWheel)
 exitButton=iconButton(root,'RPMSpeechExit','exit','Quitter RolePlay Mod',58,435,function() W.Hide();B.Close() end)
end
function W.Show()
 local current=B.npc;if not current then return end
 W.Hide()
 local parent=B.ShowCustomContent('Speechcraft — faire connaissance',520,{kind='speechcraft',width=600,contentTop=30,hideNavigation=true});create(parent)
 local round,why=S.Begin(current)
 if not round then B.Show('Speechcraft',why,{{text='Revenir à la conversation.',callback=B.ShowHome}},false);return end
 npc=current;game=round;root:SetHidden(false);W.Render()
 done:SetHidden(B.Native.IsGamepadMode());exitButton:SetHidden(B.Native.IsGamepadMode())
 -- Start only after all choices are visible and can receive input.
 S.Ready(interactive())
 EVENT_MANAGER:RegisterForUpdate('RPMSpeechTimer',100,tick)
end
function W.IsVisible() return root and not root:IsHidden() or false end
