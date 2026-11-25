local N = {name='TamrielNavigator', pending={}, recent={}, signatures={}}
TamrielNavigator=N
local function safe(fn) local ok,v=pcall(fn); if ok then return v end end
local function clean(s) return tostring(s or ''):gsub('|c%x%x%x%x%x%x',''):gsub('|r',''):gsub('%s+',' ') end
local function log(s) d('[Navigator] '..s) end
function N:read(i)
 if not i or not IsValidQuestIndex(i) then return end
 local name,bg,step,_,override,completed=GetJournalQuestInfo(i)
 local id=safe(function() return GetJournalQuestId(i) end); if id==0 then id=nil end
 local record=id and LibUespQuestData and LibUespQuestData.quests and LibUespQuestData.quests[id]
 if bg=='' or not bg then bg=record and record.backgroundText or '' end
 local context; local hay=(clean(name)..' '..clean(bg)):lower(); local notes={}; for _,note in ipairs(NavigatorLore or {}) do if hay:find(note[1],1,true) then notes[#notes+1]=note[2]; if #notes==2 then break end end end; if #notes>0 then context=table.concat(notes,' ') end
 if not context then for _,note in ipairs(NavigatorThemes or {}) do if hay:find(note[1],1,true) then context=note[2]; break end end end
 local nextStep=clean(override and override~='' and override or step)
 return {id=id or name,name=clean(name),bg=clean(bg),step=nextStep,completed=completed,index=i,matched=record~=nil,context=context}
end
function N:layout()
 self.hud:ClearAnchors(); self.hud:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,GuiRoot:GetWidth()*self.s.x/100,GuiRoot:GetHeight()*self.s.y/100); self.hud:SetScale(self.s.scale/100); self.body:SetFont('$(MEDIUM_FONT)|'..tostring(self.s.font or 30)..'|soft-shadow-thin')
end
function N:fit()
 local h=safe(function() return self.body:GetTextHeight() end) or 200
 self.hud:SetHeight(math.max(130,math.min(h+85,GuiRoot:GetHeight()*0.85/(self.s.scale/100))))
end
-- Delivery profiles shape speech text only; the native engine owns the voice.
local narratorStyles={'The Chronicler','The Scholar','The Commander','The Storyteller','Classic'}
local function sentence(t)
 t=clean(t):match('^%s*(.-)%s*$')
 if t~='' and not t:match('[%.!?]$') then t=t..'.' end
 return t
end
function N:formatSpeech(q,kind)
 local style=self.s.narratorStyle or narratorStyles[1]
 local name=sentence(q.name); local bg=sentence(q.bg); local context=sentence(q.context); local step=sentence(q.step)
 if kind=='Update' then return name..' '..step end
 if style=='Classic' then return name..' '..bg..' '..context..(step~='' and ' Next objective: '..step or '') end
 local parts={}
 local function add(t) if t and t~='' then parts[#parts+1]=t end end
 if style=='The Commander' then
  add(name); if step~='' then add('Your assignment. '..step) end; add(bg); add(context)
 elseif style=='The Scholar' then
  add(name); if context~='' then add('Some background. '..context) end; add(bg); if step~='' then add('Your next objective. '..step) end
 elseif style=='The Storyteller' then
  add('Your journey continues. '..name); add(bg); add(context); if step~='' then add('And now, your next step. '..step) end
 else
  add(name); add(bg); if context~='' and context~=bg then add(context) end; if step~='' then add('For now, here is what lies ahead. '..step) end
 end
 return table.concat(parts,'\n\n')
end
function N:show(q,kind,force)
 local sig=q.name..q.step..tostring(q.completed)
 if not force and kind~="New quest" and self.signatures[q.id]==sig then return end
 if not force and kind=="New quest" and self.briefed[q.id] then self.duplicates=(self.duplicates or 0)+1; return end
 if kind=="New quest" then self.briefed[q.id]=true end
 self.signatures[q.id]=sig
 if self.narrative and kind~='Voice test' then q.context=self:narrative(q,kind) end
 local text=self:formatSpeech(q,kind)
 self.forceVoice=false; self.spoken=text; if kind~='Voice test' then self.last=q end
 table.insert(self.recent,1,{name=q.name,bg=q.bg,step=q.step}); if #self.recent>20 then table.remove(self.recent) end
 self.title:SetText(kind=='New quest' and 'TAMRIEL NAVIGATOR  |  New adventure' or 'TAMRIEL NAVIGATOR  |  '..kind); self.body:SetText('|cD6B66A'..q.name..'|r\n\n'..q.bg..(q.context and ('\n\n|cD6B66ATHE PEOPLE & HISTORY|r\n'..q.context) or '')..'\n\n|cD6B66AYOUR NEXT STEP|r\n'..q.step)
 self:fit(); self.hud:SetHidden(not self.s.hud); self.token=(self.token or 0)+1; local token=self.token
 zo_callLater(function() if self.token==token then self.hud:SetHidden(true) end end, self.s.seconds*1000)
 if kind~='Voice test' then self:speakDirect(text,false) end
end
function N:speakDirect(text,diagnostic)
 self.attempted=(self.attempted or 0)+1
 if not self.s.voice and not diagnostic then self.lastSpeech='Voice disabled'; return end
 if not self.ready then self.lastSpeech='Registration failed'; return end
 self.spoken=text
 self.voiceTicket=(self.voiceTicket or 0)+1; local ticket=self.voiceTicket
 self.voicePending=true
 zo_callLater(function() if N.voiceTicket==ticket then N.voicePending=false; N.forceVoice=false end end, 8000)
 self.forceVoice=diagnostic==true
 self.submitted=(self.submitted or 0)+1
 local ok,err=pcall(function() SCREEN_NARRATION_MANAGER:QueueCustomEntry(N.name) end)
 self.lastSpeech=ok and 'call returned' or tostring(err)
 if not ok then self.voicePending=false; self.lastError=tostring(err) end
end
function N:scheduleFlush(delay)
 if self.flushScheduled then return end
 self.flushScheduled=true
 zo_callLater(function() N.flushScheduled=false; N:flush() end,delay or 1000)
end
function N:flush()
 if self.travel then return end
 if self.talking then return end
 local busy=safe(function() return SCENE_MANAGER:IsShowing('interact') end)
 if busy then
  self.sceneRetries=(self.sceneRetries or 0)+1
  if self.sceneRetries<12 then self:scheduleFlush(500) end
  return
 end
 self.sceneRetries=0
 if #self.pending==0 then return end
 local entry=self.pending[1]; local q=self:read(entry.index)
 if not q or q.name=='' then
  entry.tries=entry.tries+1
  if entry.tries<5 then self:scheduleFlush(500); return end
  self.lastError='Quest journal unavailable: '..tostring(entry.index)
 else
  self.lastDetected=q; self.questKeys[entry.index]=q.id; self:show(q,entry.kind,false)
 end
 table.remove(self.pending,1)
 if #self.pending>0 then self:scheduleFlush(math.max(4000, self.s.seconds*1000)) end
end
function N:defer(i,kind)
 if type(i)~='number' then return end
 self.detected=(self.detected or 0)+1
 self.lastIndex=i
 for _,entry in ipairs(self.pending) do
  if entry.index==i then if kind=='New quest' then entry.kind=kind end; return end
 end
 self.pending[#self.pending+1]={index=i,kind=kind,tries=0}
 if not self.talking then self:scheduleFlush(1000) end
end
function N:recap()
 local i=safe(function() return QUEST_JOURNAL_MANAGER:GetFocusedQuestIndex() end)
 local q=self:read(i) or self.last
 if q then self:show(q,'Recap',true) else log('Track a quest first.') end
end
function N:test()
 self:show({id='test',name='Navigator voice test',bg='Beyond the gates of Daggerfall, a new adventure awaits. The city guard needs your help.',step='Speak with the captain at the city gates.'},'Voice test',true)
 self:speakDirect(self.spoken,true)
end

function N:diagnostic(which)
 which=tonumber(which) or 0
 self.lastDiagnostic=which
 local names={'RequestReadTextChatToClient','RequestReadScreenNarrationText','NarrateText'}
 local lines={"Executed diagnostic: "..tostring(which)}
 local function report(label,fn)
  local ok,result=pcall(fn)
  lines[#lines+1]=label..': '..(ok and tostring(result or 'call returned') or ('blocked/error: '..tostring(result)))
 end
 local phrase='Navigator diagnostic '..tostring(which)..'. The road awaits.'
 if which==4 then
  report('Custom narration',function() self.spoken=phrase; return SCREEN_NARRATION_MANAGER:QueueCustomEntry(self.name) end)
 elseif which==5 then
  report('Chat queue',function() local f=SCREEN_NARRATION_MANAGER.NarrateChatMessage; if type(f)~='function' then return 'missing' end; return f(SCREEN_NARRATION_MANAGER,phrase) end)
 elseif names[which] then
  report(names[which],function() local f=_G[names[which]]; if type(f)~='function' then return 'missing' end; return f(phrase) end)
 else
  for _,name in ipairs(names) do report(name,function() return type(_G[name]) end) end
  report('QueueCustomEntry',function() return type(SCREEN_NARRATION_MANAGER.QueueCustomEntry) end)
  report('NarrateChatMessage',function() return type(SCREEN_NARRATION_MANAGER.NarrateChatMessage) end)
  report('Queue enabled control',function() return type(_G.SetTextChatNarrationQueueEnabled) end)
 end
 self.title:SetText('NAVIGATOR 0.3.10 | TEST '..tostring(which))
 self.body:SetText(table.concat(lines,'\n')..'\n\nDid you hear speech? A successful call does not prove playback.')
 self.token=(self.token or 0)+1; self.hud:SetHidden(false)
end


-- Only control the separate announcement queue; never change protected settings.
function N:announcementFilter(enable)
 if not enable and not self.announcementChanged then return end
 local ok,err=pcall(function()
  local setter=_G.SetCenterScreenAnnounceNarrationQueueEnabled
  if type(setter)~='function' then error('Announcement queue API unavailable') end
  if enable then
   if not self.announcementChanged then self.announcementPrevious=safe(function() return IsCenterScreenAnnounceNarrationQueueEnabled() end) end
   setter(false)
  else
   local previous=self.announcementPrevious
   if previous==nil then previous=true end
   setter(previous)
  end
 end)
 self.announcementStatus=ok and (enable and 'Disable call returned' or 'Restore call returned') or tostring(err)
 if ok then self.announcementChanged=enable end
end
-- Check native settings without touching private SetSetting.
function N:checkSetup()
 local function read(setting)
  if setting==nil or SETTING_TYPE_ACCESSIBILITY==nil then return nil end
  return safe(function() return GetSetting(SETTING_TYPE_ACCESSIBILITY,setting) end)
 end
 local screen=read(ACCESSIBILITY_SETTING_SCREEN_NARRATION)
 local chat=read(ACCESSIBILITY_SETTING_TEXT_CHAT_NARRATION)
 self.setupStatus='Screen: '..tostring(screen or 'unknown')..' | Chat: '..tostring(chat or 'unknown')
 if not self.s.setupNoticeShown then
  self.s.setupNoticeShown=true
  log('Voice and filter enabled by default. In Accessibility, set Screen Narration ON and Chat Narration OFF. Use /navrestore to restore native narration.')
 end
end
-- Filter only the documented native alert and announcement dispatch types.
-- Native engine calls that bypass Lua cannot be intercepted here.
function N:installDispatchFilter()
 if self.dispatchHook then return end
 local ok,err=pcall(function()
  local original=_G.RequestReadPendingNarrationTextToClient
  if type(original)~='function' then error('Dispatch API unavailable') end
  local alert,center=NARRATION_TYPE_ALERT,NARRATION_TYPE_CENTER_SCREEN_ANNOUNCEMENT
  if alert==nil or center==nil then error('Narration types unavailable') end
  local nativeTypes={}
  -- Only explicitly known narration enums; never enumerate protected globals.
  for _,name in ipairs({'NARRATION_TYPE_QUEST','NARRATION_TYPE_QUEST_TRACKER','NARRATION_TYPE_QUEST_UPDATE','NARRATION_TYPE_LOADING_SCREEN','NARRATION_TYPE_KEYBIND','NARRATION_TYPE_KEYBIND_STRIP'}) do
   local value=safe(function() return _G[name] end)
   if type(value)=='number' then nativeTypes[value]=name end
  end
  nativeTypes[alert]='alert'; nativeTypes[center]='center'
  local wrapper=function(kind,...)
   if N.quiet and kind~=nil and nativeTypes[kind] then
    local label=nativeTypes[kind]
    N.dispatchBlocked[label]=(N.dispatchBlocked[label] or 0)+1
    -- Drain only this category; never clear Navigator's UI speech queue.
    pcall(function() ClearNarrationQueue(kind) end)
    return
   end
   return original(kind,...)
  end
  _G.RequestReadPendingNarrationTextToClient=wrapper
  if _G.RequestReadPendingNarrationTextToClient~=wrapper then error('Dispatch assignment rejected') end
  self.dispatchHook={original=original,wrapper=wrapper}
 end)
 self.dispatchStatus=ok and 'Installed' or tostring(err)
end
function N:restoreDispatchFilter()
 local h=self.dispatchHook
 if h then
  pcall(function() if _G.RequestReadPendingNarrationTextToClient==h.wrapper then _G.RequestReadPendingNarrationTextToClient=h.original end end)
 end
 self.dispatchHook=nil; self.dispatchStatus='Restored'
end
function N:restoreNarration()
 if self.s then self.s.quiet=false end
 self:restoreDispatchFilter()
 self:announcementFilter(false)
 local m=SCREEN_NARRATION_MANAGER
 for key,h in pairs(self.hooks or {}) do
  if m[key]==h.wrapper then m[key]=h.original end
 end
 self.hooks={}; self.quiet=false
end
function N:quietNarration()
 if self.quiet then return end
 local m=SCREEN_NARRATION_MANAGER
 self.hooks={}; self.blocked=0; self.allowed=0
 local keys={'QueueAlert','NarrateAlert','QueueCenterScreenAnnounce','NarrateCenterScreenAnnounce','QueueFocus','QueueParametricListEntry','QueueDialog','QueueGridListEntry','QueueTextSearchHeader','QueueCustomEntry','QueueKeybind','QueueKeybinds','QueueKeybindStrip','QueueEditBox','QueueTextEntry','QueueTextField','QueueFocusedControl','NarrateKeybind','NarrateKeybinds','NarrateEditBox','NarrateTextField','QueueCenterScreenAnnouncement','QueueAnnouncement','QueueZoneName','QueueQuestUpdate','QueueEditBoxEntry','QueueKeybindButton','QueueTextInput','NarrateCenterScreenAnnouncement','NarrateAnnouncement','NarrateZoneName','NarrateQuestUpdate','NarrateTextInput','QueueLoadingScreen','QueueMap','QueueMapPin','QueueKeybindStripNarration','QueueSearch','QueueHeader','QueueHorizontalListEntry','QueueVerticalListEntry','QueueDropdown','QueueComboBox','QueueTabBar','QueueTooltip'}
 -- Discover narrowly scoped input-prompt methods on the Lua manager and its class.
 local seen={}; for _,k in ipairs(keys) do seen[k]=true end
 local function discover(t)
  if type(t)~='table' then return end
  for k,v in pairs(t) do
   if type(k)=='string' and type(v)=='function' and not seen[k] then
    local l=k:lower()
    if (l:match('^queue') or l:match('^narrate')) and (l:find('keybind',1,true) or l:find('editbox',1,true) or l:find('textfield',1,true) or l:find('textentry',1,true) or l:find('announcement',1,true) or l:find('quest',1,true) or l:find('zone',1,true) or l:find('textinput',1,true) or l:find('loading',1,true) or l:find('map',1,true) or l:find('search',1,true) or l:find('addon',1,true) or l:find('control',1,true) or l:find('header',1,true) or l:find('button',1,true)) then keys[#keys+1]=k; seen[k]=true end
   end
  end
 end
 discover(m); discover(ZO_ScreenNarrationManager)
 -- Additional public UI entry methods; do not intercept queue processing.
 for _,key in ipairs({'QueueNarration','QueueGenericEntry','QueueListEntry','QueueSpinner','QueueTab','QueueSimpleListEntry','QueueControl','QueueText','QueueGamepadDialog','QueueScreen','QueueScene','QueueMenuEntry'}) do
  if not seen[key] then keys[#keys+1]=key; seen[key]=true end
 end
 -- Block additional public queue entry points, but preserve internal processing.
 for _,key in ipairs({'QueueQuestTracker','QueueQuestObjective','QueueLoadingScreenNarration','QueueHUD','QueueHud','QueueGamepadListEntry'}) do
  if not seen[key] then keys[#keys+1]=key; seen[key]=true end
 end
 self.blockedBy={}
 self.quiet=true
 for _,key in ipairs(keys) do
  local method=key
  local original=safe(function() return m[method] end)
  if type(original)=='function' then
   local wrapper=function(manager,...)
    if not N.quiet or (method=='QueueCustomEntry' and select(1,...)==N.name) then
     if N.quiet then N.allowed=N.allowed+1 end
     return original(manager,...)
    end
    N.blocked=N.blocked+1; N.blockedBy[method]=(N.blockedBy[method] or 0)+1
   end
   local ok=pcall(function() m[method]=wrapper end)
   if ok and m[method]==wrapper then self.hooks[method]={original=original,wrapper=wrapper} end
  end
 end
 if not self.hooks.QueueCustomEntry then self:restoreNarration(); log('Filter unavailable; restored native narration.') else self.s.quiet=true; self:announcementFilter(true); self.dispatchBlocked={}; self:installDispatchFilter() end
end
function N:quietReport()
 local function short(v)
  local t=tostring(v or 'Not attempted'):match('^[^\r\n]*') or ''
  t=t:gsub('percache:[^ ]+:%d+: ','')
  if #t>110 then t=t:sub(1,107)..'...' end
  return t
 end
 local count=0; for _ in pairs(self.hooks or {}) do count=count+1 end
 local lines={
  'Native filter: '..(self.quiet and 'On' or 'Off')..' | Hooks: '..count,
  'Dispatch: '..short(self.dispatchStatus),
  'Announcements: '..short(self.announcementStatus),
  'Blocked: '..tostring(self.blocked or 0)..' | Allowed: '..tostring(self.allowed or 0),
  'Quest voice: '..(self.s.voice and 'On' or 'Off')..' | Registered: '..tostring(self.ready),
  'Speech submitted: '..tostring(self.submitted or 0),
  'Last error: '..short(self.lastError or 'None')}
 self.title:SetText('NAVIGATOR 0.3.10 | VOICE FILTER'); self.body:SetText(table.concat(lines,'\n')); self:fit(); self.token=(self.token or 0)+1; self.hud:SetHidden(false)
end

function N:init()
 self.s=ZO_SavedVars:NewCharacterIdSettings('TamrielNavigatorSaved',1,nil,{voice=true,narratorStyle="The Chronicler",quiet=true,auto=true,hud=true,updates=false,x=4,y=22,scale=100,seconds=20,font=30,zoneHud=true,zoneCombat=true,zoneX=50,zoneY=85,zoneWidth=36,zoneScale=100,zoneFont=22,adventure=true})
 if not self.s.migrated017 then self.s.voice=true; self.s.quiet=true; self.s.auto=true; self.s.migrated017=true end
 self:chronicleInit(); self.recent={}; self.briefed={}; self.questKeys={}; local w=WINDOW_MANAGER
 self.hud=w:CreateTopLevelWindow('TamrielNavigatorHUD'); self.hud:SetDimensions(1050,300); self.hud:SetHidden(true); self.hud:SetMouseEnabled(false)
 local b=w:CreateControl(nil,self.hud,CT_BACKDROP); b:SetAnchorFill(); b:SetCenterColor(.018,.014,.009,.96); b:SetEdgeColor(.76,.59,.30,1); b:SetEdgeTexture('',8,1,2)
 self.title=w:CreateControl(nil,self.hud,CT_LABEL); self.title:SetAnchor(TOPLEFT,self.hud,TOPLEFT,18,14); self.title:SetFont('$(BOLD_FONT)|34|soft-shadow-thin'); self.title:SetColor(.91,.78,.48,1)
 self.body=w:CreateControl(nil,self.hud,CT_LABEL); self.body:SetAnchor(TOPLEFT,self.title,BOTTOMLEFT,0,14); self.body:SetWidth(1014); self.body:SetHeight(0); self.body:SetFont('ZoFontGame'); self.body:SetColor(1,1,1,1); self.body:SetVerticalAlignment(TEXT_ALIGN_TOP)
 self:layout(); self:initZoneStrip()
 local ok,err=pcall(function() SCREEN_NARRATION_MANAGER:RegisterCustomObject(N.name,{canNarrate=function() return N.voicePending and (N.forceVoice or N.s.voice) end, selectedNarrationFunction=function() if not N.voicePending then return {} end; N.voicePending=false; N.forceVoice=false; return {SCREEN_NARRATION_MANAGER:CreateNarratableObject(N.spoken or '')} end}) end)
 self.ready=ok; if not ok then self.lastError=tostring(err); log('Narration registration failed: '..tostring(err)) end
 local function event(e,fn) if e then EVENT_MANAGER:RegisterForEvent(N.name,e,fn) end end
 event(EVENT_CHATTER_BEGIN,function() N.talking=true end)
 event(EVENT_CHATTER_END,function() N.talking=false; N.sceneRetries=0; N:scheduleFlush(1000) end)
 event(EVENT_QUEST_ADDED,function(_,i) local q=N:read(i); if q then N.questKeys[i]=q.id end; if N.s.auto then N:defer(i,'New quest') end end)
 event(EVENT_QUEST_REMOVED,function(_,completed,i) local id=N.questKeys[i]; if completed and id then N.ch.quests[id]=true end; if id then N.briefed[id]=nil; N.signatures[id]=nil; N.questKeys[i]=nil end; for j=#N.pending,1,-1 do if N.pending[j].index==i then table.remove(N.pending,j) end end end)
 event(EVENT_QUEST_ADVANCED,function(_,i) if N.s.updates then N:defer(i,'Update') end end)
 event(EVENT_PLAYER_DEACTIVATED,function() N.voicePending=false; N.forceVoice=false; N.travel=true; if N.quiet then N:announcementFilter(true) end end)
 event(EVENT_PLAYER_ACTIVATED,function() N.travel=false; N:recordZone(); for i=1,(MAX_JOURNAL_QUESTS or 25) do local q=N:read(i); if q then N.questKeys[i]=q.id end end; N.talking=false; N:scheduleFlush(1000); if N.s.quiet and not N.quiet then N:quietNarration() elseif N.quiet then N:announcementFilter(true) end; N:checkSetup() end)
 SLASH_COMMANDS['/navigator']=function(arg) arg=(arg or ''):lower():match('^%s*(.-)%s*$'); if arg=='audit' then N:diagnostic(0) elseif arg:match('^diag%s+[0-5]$') then N:diagnostic(tonumber(arg:sub(-1))) elseif arg=='test' then N:test() elseif arg=='hide' then N.hud:SetHidden(true) elseif arg=='voice' then N.s.voice=not N.s.voice; N.forceVoice=false; log('Voice: '..tostring(N.s.voice)) else N:recap() end end
 for i=0,5 do local test=i; SLASH_COMMANDS['/navdiag'..i]=function() N:diagnostic(test) end end
 SLASH_COMMANDS['/navquiet']=function() N:quietNarration(); N:quietReport() end
 SLASH_COMMANDS['/navrestore']=function() N:restoreNarration(); N:quietReport() end
 SLASH_COMMANDS['/navstatus']=function() N:quietReport() end
 SLASH_COMMANDS['/navvoice']=function() N.s.voice=not N.s.voice; N.forceVoice=false; log('Voice: '..tostring(N.s.voice)) end
 SLASH_COMMANDS['/navskip']=function() N:skipAdventure() end
 SLASH_COMMANDS['/navdevelop']=function() N:development(1) end
 SLASH_COMMANDS['/navtrack']=function() N:trackZoneAdvice() end
 SLASH_COMMANDS['/navzone']=function() N:zoneGuide(1) end
 SLASH_COMMANDS['/navnext']=function() N:guideNext() end
 SLASH_COMMANDS['/navchronicle']=function() N:chronicleShow() end
 SLASH_COMMANDS['/navspeak']=function() N:test() end
 local lam=LibAddonMenu2
 if lam then
  lam:RegisterAddonPanel('NavigatorOptions',{type='panel',name='Tamriel Navigator',author='Trash Man Enterprises',version='0.3.10'})
  local controls={}
  local function header(name) controls[#controls+1]={type='header',name=name} end
  local function button(name,fn) controls[#controls+1]={type='button',name=name,func=fn} end
  local function check(k,name,fn) controls[#controls+1]={type='checkbox',name=name,getFunc=function() return N.s[k] end,setFunc=function(v) N.s[k]=v; if fn then fn(v) end end} end
  local function slider(k,name,lo,hi,fn) controls[#controls+1]={type='slider',name=name,min=lo,max=hi,step=1,getFunc=function() return N.s[k] end,setFunc=function(v) N.s[k]=v; fn() end} end
  header('Adventure tools')
  button('Zone report',function() N:zoneGuide(1) end)
  button('Track recommended activity',function() N:trackZoneAdvice() end)
  button('Character development',function() N:development(1) end)
  button('Living Chronicle',function() N:chronicleShow() end)
  button('Recap tracked quest',function() N:recap() end)
  button('Next report page',function() N:guideNext() end)
  button('Close report',function() N.hud:SetHidden(true) end)
  header('Zone Intelligence HUD')
  check('adventure','Find nearby quest givers',function() N:updateZoneStrip(true) end)
  button('Skip suggested quest giver',function() N:skipAdventure() end)
  local function refresh() N:layoutZoneStrip(); N:updateZoneStrip(true) end
  check('zoneHud','Show zone HUD',refresh); check('zoneCombat','Hide during combat',refresh)
  slider('zoneX','Horizontal position (%)',0,100,refresh); slider('zoneY','Vertical position (%)',0,100,refresh)
  slider('zoneWidth','Width (% of screen)',15,85,refresh); slider('zoneScale','Scale (%)',50,150,refresh); slider('zoneFont','Text size',14,36,refresh)
  button('Reset zone HUD placement',function() N.s.zoneX=50; N.s.zoneY=85; N.s.zoneWidth=36; N.s.zoneScale=100; N.s.zoneFont=22; refresh() end)
  header('Quest briefings')
  check('auto','Automatic new quest briefings'); check('hud','Show briefing window'); check('updates','Narrate quest updates')
  local function layout() N:layout(); N:fit() end
  slider('x','Horizontal position (%)',0,80,layout); slider('y','Vertical position (%)',0,80,layout); slider('scale','Scale (%)',60,150,layout); slider('font','Text size',20,48,layout); slider('seconds','Display seconds',5,60,layout)
  header('Voice')
  controls[#controls+1]={type='dropdown',name='Narrator style',tooltip='Changes spoken wording and cadence, not the native voice itself.',choices=narratorStyles,getFunc=function() return N.s.narratorStyle or narratorStyles[1] end,setFunc=function(v) N.s.narratorStyle=v end}
  controls[#controls+1]={type='description',text='Voice identity and speech rate are controlled by native accessibility settings. Narrator styles change the script only.'}
  check('voice','Quest narration',function() N.forceVoice=false end)
  check('quiet','Suppress native narration',function(v) if v then N:quietNarration() else N:restoreNarration() end end)
  button('Test narrator',function() N:test() end)
  button('Voice filter status',function() N:quietReport() end)
  lam:RegisterOptionControls('NavigatorOptions',controls)
 end
end
EVENT_MANAGER:RegisterForEvent(N.name,EVENT_ADD_ON_LOADED,function(_,name) if name==N.name then EVENT_MANAGER:UnregisterForEvent(N.name,EVENT_ADD_ON_LOADED); N:init() end end)
