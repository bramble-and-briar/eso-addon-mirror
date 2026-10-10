ChatKeeper={VERSION='0.1.1',MAX_MESSAGES=500,MAX_BYTES=262144}
local K=ChatKeeper
local defaults={history={},timestamps=true,hour24=true,offsetY=-40,offsetX=0,restore=true,restoreCount=100}
local unpackArgs=unpack or table.unpack
local function pack(...) return {n=select('#',...),...} end
local function read(fn,...)
 if type(fn)~='function' then return end
 local r=pack(pcall(fn,...));if r[1] then return unpackArgs(r,2,r.n) end
end
local function clamp(n,a,b) return math.max(a,math.min(b,n)) end
function K.Plain(s)
 s=tostring(s or ''):gsub('|H.-|h(.-)|h','%1'):gsub('|[cC]%x%x%x%x%x%x',''):gsub('|[rR]',''):gsub('|t.-|t',''):gsub('|u.-|u','')
 return s:sub(1,2000)
end
function K:Stamp(time)
 local text=time or read(GetTimeString) or ''
 local h,m=text:match('^(%d+):(%d+)');h=tonumber(h)
 if not h then return text end
 if self.saved.hour24 then return string.format('%02d:%s',h,m) end
 return string.format('%d:%s %s',(h+11)%12+1,m,h>=12 and 'PM' or 'AM')
end
local allowedChannels={}
local channelKeys={'SAY','YELL','ZONE','PARTY','WHISPER','WHISPER_SENT','EMOTE','ZONE_LANGUAGE_1','ZONE_LANGUAGE_2','ZONE_LANGUAGE_3','ZONE_LANGUAGE_4','ZONE_LANGUAGE_5'}
for _,key in ipairs(channelKeys) do
 local value=_G['CHAT_CHANNEL_'..key];if type(value)=='number' then allowedChannels[value]=true end
end
for i=1,5 do
 for _,key in ipairs({'GUILD_','OFFICER_'}) do
  local value=_G['CHAT_CHANNEL_'..key..i];if type(value)=='number' then allowedChannels[value]=true end
 end
end
function K:Allowed(channel)
 return allowedChannels[channel]==true
end
function K:Category(channel)
 return read(GetChannelCategoryFromChannel,channel)
end
function K:ChannelName(channel)
 local names={CHAT_CHANNEL_SAY='Say',CHAT_CHANNEL_YELL='Yell',CHAT_CHANNEL_ZONE='Zone',CHAT_CHANNEL_PARTY='Group',CHAT_CHANNEL_WHISPER='Whisper',CHAT_CHANNEL_WHISPER_SENT='Whisper sent',CHAT_CHANNEL_EMOTE='Emote'}
 for key,value in pairs(names) do if _G[key]==channel then return value end end
 for i=1,5 do
  if _G['CHAT_CHANNEL_GUILD_'..i]==channel then return 'Guild '..i end
  if _G['CHAT_CHANNEL_OFFICER_'..i]==channel then return 'Officers '..i end
 end
 return read(GetDynamicChatChannelName,channel) or 'Chat'
end
function K:Trim()
 local bytes=0
 for _,m in ipairs(self.saved.history) do bytes=bytes+#(m.text or '')+#(m.sender or '')+#(m.channelName or '')+64 end
 while #self.saved.history>self.MAX_MESSAGES or bytes>self.MAX_BYTES do
  local m=table.remove(self.saved.history,1);bytes=bytes-#(m.text or '')-#(m.sender or '')-#(m.channelName or '')-64
 end
 self.bytes=bytes
end
function K:Capture(channel,from,text,customer,display)
 if customer or not self:Allowed(channel) then return end
 local category=self:Category(channel)
 if category and read(IsChannelCategoryCommunicationRestricted,category) then return end
 local sender=self.Plain(display and display~='' and display or from)
 local body=self.Plain(text);if body=='' then return end
 self.saved.history[#self.saved.history+1]={channel=channel,category=category,channelName=self:ChannelName(channel),sender=sender,text=body,time=read(GetTimeString) or '',date=read(GetDate) or 0}
 self:Trim()
end
function K:Line(m,restored)
 local stamp=self.saved.timestamps and '['..self:Stamp(m.time)..'] ' or ''
 return stamp..(restored and '[Saved] ' or '')..'['..(m.channelName or 'Chat')..'] '..(m.sender or '')..': '..(m.text or '')
end
function K:ColoredLine(m)
 local r,g,b=read(GetChatCategoryColor,m.category)
 if type(r)~='number' then r,g,b=.8,.8,.8 end
 return string.format('|c%02X%02X%02X',clamp(math.floor(r*255),0,255),clamp(math.floor(g*255),0,255),clamp(math.floor(b*255),0,255))..self:Line(m,true)..'|r'
end
function K:Restore()
 if self.restored or not self.saved.restore then return true end
 if not CHAT_ROUTER or type(CHAT_ROUTER.AddSystemMessage)~='function' then return false end
 self.restored=true
 local history=self.restoreSnapshot or {};local first=math.max(1,#history-self.saved.restoreCount+1)
 for i=first,#history do
  local m=history[i]
  if not m.category or not read(IsChannelCategoryCommunicationRestricted,m.category) then
   CHAT_ROUTER:AddSystemMessage(self:ColoredLine(m))
  end
 end
 self.restoreSnapshot=nil
 return true
end
-- Wrap the existing formatter; preserve channel/category/other return values and live links.
function K:InstallTimestamps()
 if self.formatterInstalled or not CHAT_ROUTER then return end
 local formatters=read(CHAT_ROUTER.GetRegisteredMessageFormatters,CHAT_ROUTER)
 local original=formatters and formatters[EVENT_CHAT_MESSAGE_CHANNEL]
 if type(original)~='function' or type(CHAT_ROUTER.RegisterMessageFormatter)~='function' then return end
 CHAT_ROUTER:RegisterMessageFormatter(EVENT_CHAT_MESSAGE_CHANNEL,function(channel,...)
  local result=pack(original(channel,...))
  if self.saved.timestamps and self:Allowed(channel) and type(result[1])=='string' then
   result[1]='|cAAAAAA['..self:Stamp()..']|r '..result[1]
  end
  return unpackArgs(result,1,result.n)
 end)
 self.formatterInstalled=true
end
function K:GetHUDControl()
 local system=GAMEPAD_CHAT_SYSTEM
 local container=system and system.primaryContainer
 return container and container.control
end
local function anchors(control)
 local result={}
 for i=0,(read(control.GetNumAnchors,control) or 0)-1 do
  local valid,point,relative,relativePoint,x,y=read(control.GetAnchor,control,i)
  if valid then result[#result+1]={point,relative,relativePoint,x or 0,y or 0} end
 end
 return result
end
local function same(a,b)
 if not a or not b or #a~=#b then return false end
 for i=1,#a do for j=1,5 do if a[i][j]~=b[i][j] then return false end end end
 return true
end
function K:Offset()
 local c=self:GetHUDControl();if not c then self.offsetStatus='Waiting for native HUD chat';return end
 local current=anchors(c);if #current==0 then self.offsetStatus='Native chat anchors unavailable';return end
 if self.chatControl~=c then self.chatControl=c;self.baseAnchors=current;self.lastAnchors=nil end
 local hud=SCENE_MANAGER:IsShowing('hud') or SCENE_MANAGER:IsShowing('hudui')
 -- Restore original anchors in menus; recapture when ESO repositions the container.
 if not same(current,self.lastAnchors) then self.baseAnchors=current end
 local desired={}
 for _,a in ipairs(self.baseAnchors) do desired[#desired+1]={a[1],a[2],a[3],a[4]+(hud and self.saved.offsetX or 0),a[5]+(hud and self.saved.offsetY or 0)} end
 if not same(current,desired) then
  c:ClearAnchors();for _,a in ipairs(desired) do c:SetAnchor(unpackArgs(a,1,5)) end
 end
 self.lastAnchors=desired;self.offsetStatus='HUD offset active'
end
local function label(parent,x,y,w,h)
 local l=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL);l:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);l:SetDimensions(w,h);l:SetFont('ZoFontGamepad18');l:SetColor(.9,.9,.9,1);return l
end
local options={{key='offsetY',name='Chat vertical offset',step=5,min=-400,max=200},{key='offsetX',name='Chat horizontal offset',step=5,min=-400,max=400},{key='timestamps',name='Timestamps'},{key='hour24',name='24-hour format'},{key='restore',name='Restore recent chat'},{key='restoreCount',name='Messages restored',step=25,min=25,max=500}}
function K:Refresh()
 if self.window and GuiRoot.GetWidth then self.window:SetScale(math.min(1,GuiRoot:GetWidth()/1100,GuiRoot:GetHeight()/820)) end
 self.heading:SetText(self.view=='history' and ('CHAT KEEPER | '..#self.saved.history..' saved messages') or 'CHAT KEEPER | 0.1.1 TESTER')
 for _,l in ipairs(self.labels) do l:SetText('') end
 if self.view=='history' then
  local count=#self.saved.history;self.pages=math.max(1,math.ceil(count/10));self.page=clamp(self.page,1,self.pages)
  local first=math.max(1,count-self.page*10+1);local last=count-(self.page-1)*10
  for i=first,last do self.labels[i-first+1]:SetText(self:Line(self.saved.history[i],false)) end
  self.footer:SetText('Page '..self.page..'/'..self.pages..' | X: older | Y: newer | A: settings\nSaved text only. Send replies through normal ESO chat.')
 else
  for i,o in ipairs(options) do
   local v=self.saved[o.key];if type(v)=='boolean' then v=v and 'On' or 'Off' end
   self.labels[i]:SetText((i==self.selected and '> ' or '   ')..o.name..'  '..tostring(v))
  end
  self.footer:SetText('Stick / D-pad: select | X/Y: adjust | A: history\nNegative vertical offset moves chat up. '..(self.offsetStatus or ''))
 end
end
function K:Open(view)
 if IsUnitInCombat('player') then d('Chat Keeper: open after combat.');return end
 if not self.window then
  local w=WINDOW_MANAGER:CreateTopLevelWindow('TGWChatKeeperWindow');self.window=w;w:SetAnchor(CENTER,GuiRoot,CENTER,0,0);w:SetDimensions(1060,780);w:SetHidden(true)
  local bg=WINDOW_MANAGER:CreateControl(nil,w,CT_TEXTURE);bg:SetAnchorFill(w);bg:SetColor(.02,.025,.035,1)
  self.heading=label(w,24,20,1012,35);self.labels={}
  for i=1,10 do self.labels[i]=label(w,24,80+(i-1)*60,1012,56);self.labels[i]:SetMaxLineCount(2) end
  self.footer=label(w,24,700,1012,60);self.selected=1;self.page=1
  local function stop() EVENT_MANAGER:UnregisterForUpdate('TGWChatKeeper_Repeat');self.held=nil end;self.stop=stop
  local function move(n,up)
   if up then if self.held==n then stop() end;return end
   stop();self.held=n
   local function step() if self.view=='settings' then self.selected=clamp(self.selected+n,1,#options) else self.page=clamp(self.page+n,1,self.pages or 1) end;self:Refresh() end
   step();local ticks=0;EVENT_MANAGER:RegisterForUpdate('TGWChatKeeper_Repeat',120,function() ticks=ticks+1;if ticks>=3 then step() end end)
  end
  local function change(n)
   if self.view=='history' then self.page=clamp(self.page-n,1,self.pages);self:Refresh();return end
   local o=options[self.selected];if o.step then self.saved[o.key]=clamp(self.saved[o.key]+o.step*n,o.min,o.max) else self.saved[o.key]=not self.saved[o.key] end
   self:Offset();self:Refresh()
  end
  self.keys={alignment=KEYBIND_STRIP_ALIGN_LEFT,
   {name='History / settings',keybind='UI_SHORTCUT_PRIMARY',callback=function() stop();self.view=self.view=='history' and 'settings' or 'history';self.page=1;self:Refresh() end},
   {name=function() return self.view=='history' and 'Older' or 'Decrease / toggle' end,keybind='UI_SHORTCUT_SECONDARY',callback=function() change(-1) end},
   {name=function() return self.view=='history' and 'Newer' or 'Increase / toggle' end,keybind='UI_SHORTCUT_TERTIARY',callback=function() change(1) end},
   {keybind='UI_SHORTCUT_INPUT_UP',handlesKeyUp=true,callback=function(up) move(-1,up) end},
   {keybind='UI_SHORTCUT_INPUT_DOWN',handlesKeyUp=true,callback=function(up) move(1,up) end},
   {name='Reset position',keybind='UI_SHORTCUT_RIGHT_SHOULDER',callback=function() self.saved.offsetY=0;self.saved.offsetX=0;self:Offset();self:Refresh() end},
   {name='Back',keybind='UI_SHORTCUT_NEGATIVE',callback=function() SCENE_MANAGER:Hide('chatKeeper') end}}
  local scene=ZO_Scene:New('chatKeeper',SCENE_MANAGER);scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW);scene:AddFragment(ZO_SimpleSceneFragment:New(w))
  scene:RegisterCallback('StateChange',function(_,state) if state==SCENE_SHOWING then self:Refresh();KEYBIND_STRIP:AddKeybindButtonGroup(self.keys) elseif state==SCENE_HIDING then stop();KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keys) end end)
 end
 self.view=view or 'settings';self:Refresh();SCENE_MANAGER:Show('chatKeeper')
end
EVENT_MANAGER:RegisterForEvent('TGWChatKeeper_Load',EVENT_ADD_ON_LOADED,function(_,name)
 if name~='ChatKeeper' then return end
 EVENT_MANAGER:UnregisterForEvent('TGWChatKeeper_Load',EVENT_ADD_ON_LOADED)
 K.saved=ZO_SavedVars:NewAccountWide('TGWChatKeeperSaved',1,nil,defaults,GetWorldName())
 K.saved.history=type(K.saved.history)=='table' and K.saved.history or {}
 K.saved.offsetY=clamp(tonumber(K.saved.offsetY) or -40,-400,200);K.saved.offsetX=clamp(tonumber(K.saved.offsetX) or 0,-400,400)
 K.saved.restoreCount=clamp(tonumber(K.saved.restoreCount) or 100,25,500)
 K:Trim();K.restoreSnapshot={};for i,m in ipairs(K.saved.history) do K.restoreSnapshot[i]=m end
 K:InstallTimestamps()
 EVENT_MANAGER:RegisterForEvent('TGWChatKeeper_Chat',EVENT_CHAT_MESSAGE_CHANNEL,function(_,...) K:Capture(...) end)
 EVENT_MANAGER:RegisterForEvent('TGWChatKeeper_Active',EVENT_PLAYER_ACTIVATED,function()
  zo_callLater(function() K:InstallTimestamps();K:Offset();K:Restore() end,1000)
 end)
 EVENT_MANAGER:RegisterForUpdate('TGWChatKeeper_Position',500,function() K:Offset() end)
 SLASH_COMMANDS['/chatkeeper']=function(arg)
  arg=(arg or ''):lower():match('^%s*(.-)%s*$')
  if arg=='clear confirm' then K.saved.history={};K.restoreSnapshot={};K:Trim();d('Chat Keeper: saved history cleared.')
  elseif arg=='clear' then d('Chat Keeper: /chatkeeper clear confirm deletes this server\'s saved conversations.')
  elseif arg=='history' then K:Open('history')
  elseif arg=='reset' then K.saved.offsetY=0;K.saved.offsetX=0;K:Offset();d('Chat Keeper: native chat position restored.')
  else K:Open('settings') end
 end
 d('Chat Keeper 0.1.1 tester loaded. /chatkeeper for settings.')
end)
