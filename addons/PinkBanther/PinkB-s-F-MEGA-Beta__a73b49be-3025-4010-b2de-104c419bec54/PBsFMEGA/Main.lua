PBF=PBF or {}
local C=PBF.Core
local A={keys={},steer=0};PBF.App=A
local floor,min,max,abs=math.floor,math.min,math.max,math.abs
A.LEVELS={'やさしい','ふつう','つよい'}
-- Pixel height of one band of road rows in the 1280x720 picture. Smaller is smoother and costs
-- more controls; 6 is the default until a PS5 says otherwise.
A.QUALITY={low={9,'低',false},mid={7,'中',false},high={5,'高',true}}   -- {band px, name, scrolling stripes outside the road}
A.QUALITY_ORDER={'low','mid','high'}
function A:Alert(message) ZO_Alert(UI_ALERT_CATEGORY_ALERT,nil,message) end
function A:ClearKeys() self.keys={};self.steer=0 end
-- ------------------------------------------------------------------------------------------
-- Things the client may refuse. A call that raises a private-function error puts up the client's
-- error screen and cannot be caught, so the first call of each is marked in the saved variables
-- before it is made: if the screen appears, the next start finds the mark still there and
-- switches the feature off instead of trying it again.
function A:Probe(name,fn,...)
 local v=self.saved.verified
 if v[name] then return fn(...) end
 self.saved.pending=name
 local ok,a,b,c=pcall(fn,...)
 self.saved.pending=nil
 if ok then v[name]=true;return a,b,c end
 self.saved[name]=false
 self:Alert('この機能は使えませんでした：'..name)
end
local function readAnalog() return GetGamepadLeftStickX(true),GetGamepadRightTriggerMagnitude(),GetGamepadLeftTriggerMagnitude() end
local function rumble(ms,power) SetGamepadVibration(ms,power,power,0,0,'PBsFMEGA') end
-- ------------------------------------------------------------------------------------------
function A:Course() return PBF.Courses[self.courseIndex] end
function A:TrackFor(index)
 self.tracks=self.tracks or {}
 local t=self.tracks[index]
 if not t then t=PBF.Track.New(PBF.Courses[index]);self.tracks[index]=t end
 return t
end
function A:NewRace()
 local seed=(self.seed or 1)
 self.race=PBF.Race.New(self.track,{kind=self.saved.kind,level=self.saved.level,seed=seed,rivals=7})
 self.race.onEvent=function(kind,m,a) self:OnEvent(kind,m,a) end
 self.ui.view:Follow(self.race.player,.016,true)
end
-- ------------------------------------------------------------------------------------------
-- Opening and the states a visit moves through: garage -> race <-> paused -> result -> garage.
function A:Open(index)
 if self.state or self.opening then return end
 if IsUnitInCombat and IsUnitInCombat('player') then self:Alert('戦闘中は遊べません。');return end
 self.courseIndex=index;self.saved.lastCourse=index
 self.opening=true
 self.ui:Fade(function()
  self:Prepare()
  SCENE_MANAGER:Show('pbfGame')
  self:EnterGarage()
  self.opening=false
 end)
end
function A:Prepare()
 local def=self:Course()
 self.track=self:TrackFor(self.courseIndex)
 if not self.view then
  local q=A.QUALITY[self.saved.quality or 'mid']
  self.view=PBF.View.New({band=q[1],rich=self.saved.rich~=false});self.view.stripes=q[3]
  self.view.lite=self.gov>=1
 end
 self.view:SetTheme(def.id)
 self.ui:EnsureBuilt(self.view,self.track)
 self.ui.view=self.view
end
function A:EnterGarage()
 self.seed=(self.seed or 0)+1+(GetTimeStamp() % 1000)
 self.state='garage'
 self:ClearKeys()
 self:NewRace()
 self.ui:HideHud(true);self.ui.text.banner:SetHidden(true)
 self:RefreshGarage()
 self.ui:UpdateKeybinds()
 self.drawAt=0
end
function A:RefreshGarage()
 local def=self:Course();local st=PBF.Machine.Types[self.saved.kind];local t=self.ui.text
 local best=self.saved.best[def.id]
 self.ui:ShowPanel('garage')
 t.ovTitle:SetText(def.name)
 t.ovSub:SetText(string.format('%s\n全長 %.1f km　%d周',def.blurb,self.track.length/1000,def.laps))
 t.ovMachine:SetText('◀　'..st.name..'　▶')
 for i,name in ipairs({'最高速','加速','旋回','グリップ'}) do self.ui.statNames[i]:SetText(name) end
 self.ui:SetBars({st.top/250,st.accel/80,st.turn/2.8,st.grip/9})
 t.ovNote:SetText(st.note)
 t.ovLevel:SetText('ライバルの強さ：'..A.LEVELS[self.saved.level]..'　（上下）')
 t.ovMusic:SetText((best and ('ベストタイム '..C.FormatTime(best.time)..'　／　') or '')..self.audio:Label()..'（□）')
 t.ovHint:SetText('左右：機体　上下：ライバルの強さ　□：BGM　×：スタート　△：戻る')
end
function A:StartRace()
 if self.state~='garage' then return end
 -- Held buttons are kept: Input records presses in every state, so the button that started
 -- the race is already counted as the accelerator when the light goes green.
 self.state='race'
 self:NewRace()
 self.ui:ShowPanel(nil);self.ui:HideHud(false)
 self.ui.text.ovHint:SetHidden(true)
 self.ui:UpdateKeybinds()
 self.footerUntil=GetFrameTimeSeconds()+6
 self.watch={t=0,n=0,since=0,slow=0}
 self.ui.footer:SetText('R2/×：アクセル　L2/□：ブレーキ　○：ブースト　L1/R1：スライド　△：一時停止');self.ui.footer:SetHidden(false)
end
function A:Pause()
 if self.state~='race' then return end
 self.state='paused'
 local t=self.ui.text
 self.ui:ShowPanel('result')
 t.ovTitle:SetText('一時停止');t.ovSub:SetText(self:Course().name)
 t.ovA:SetText('');t.ovB:SetText('×　再開\n□　やり直し\n△　終了');t.ovC:SetText('')
 t.ovHint:SetText('');self.ui:UpdateKeybinds()
end
function A:Resume()
 if self.state~='paused' then return end
 self.state='race';self.ui:ShowPanel(nil);self.ui:UpdateKeybinds()
end
function A:Restart()
 self.seed=(self.seed or 0)+1
 self.state='garage';self:StartRace()
end
function A:ShowResult()
 local race=self.race;local p=race.player
 self.state='result'
 local def=self:Course();local t=self.ui.text
 local rows,names,times={}, {}, {}
 for i,m in ipairs(race.order) do
  rows[i]=string.format('%d位',i)
  names[i]=(m.player and '▶ ' or '')..m.type.name
  times[i]=m.finished and C.FormatTime(m.finishTime) or (m.wrecked and '爆発' or '走行中')
 end
 local sub
 if p.finished then
  sub='タイム '..C.FormatTime(p.finishTime)..'　ベストラップ '..C.FormatTime(race.bestLap)
  local best=self.saved.best[def.id]
  if not best or p.finishTime<best.time then
   self.saved.best[def.id]={time=p.finishTime,lap=race.bestLap,kind=p.kind}
   sub=sub..'\nコースレコード更新！'
  else sub=sub..'\nコースレコード '..C.FormatTime(best.time) end
 else sub='エネルギーがなくなりました' end
 self.ui:ShowPanel('result')
 t.ovTitle:SetText(p.finished and ('第'..p.rank..'位') or 'リタイア')
 t.ovSub:SetText(sub)
 t.ovA:SetText(table.concat(rows,'\n'));t.ovB:SetText(table.concat(names,'\n'));t.ovC:SetText(table.concat(times,'\n'))
 t.ovHint:SetText('×：もう一度　□：機体を選ぶ　△：終了')
 self.ui:UpdateKeybinds()
end
function A:Close()
 if SCENE_MANAGER:IsShowing('pbfGame') then SCENE_MANAGER:Hide('pbfGame') end
end
function A:BackLabel()
 local s=self.state
 if s=='race' then return '一時停止' end
 if s=='garage' then return '戻る' end
 return '終了'
end
function A:Back()
 local s=self.state
 if s=='race' then self:Pause() elseif s then self:Close() end
end
function A:Hidden()
 self.ui:CancelFade();self.audio:Stop();self:ClearKeys()
 self.state=nil;self.race=nil;self.opening=false
end
-- ------------------------------------------------------------------------------------------
-- Input. Bindings.xml reports presses and releases; held buttons live in `keys`, and the ones
-- that act once on a press are handled here.
function A:Input(key,down)
 if not self.state then self.keys={};return end
 self.keys[key]=down or nil
 if not down then return end
 local s=self.state
 if s=='garage' then
  if key=='left' or key=='right' then
   local n=#PBF.Machine.Types
   self.saved.kind=(self.saved.kind-1+(key=='left' and -1 or 1))%n+1
   self.audio:Play('select');self:NewRace();self:RefreshGarage()
  elseif key=='up' or key=='down' then
   self.saved.level=C.clamp(self.saved.level+(key=='up' and 1 or -1),1,#A.LEVELS)
   self.audio:Play('select');self:NewRace();self:RefreshGarage()
  elseif key=='brake' then self.audio:Cycle(true);self:RefreshGarage()
  elseif key=='accel' then self:StartRace() end
 elseif s=='paused' then
  if key=='accel' then self:Resume() elseif key=='brake' then self:Restart() end
 elseif s=='result' then
  if key=='accel' then self:Restart() elseif key=='brake' then self:EnterGarage() end
 end
end
-- The pad as the race sees it. Digital steering is ramped: a stick that is only ever fully left,
-- centre or fully right needs a little inertia to feel like it has a middle.
function A:Controls(dt)
 local k=self.keys
 local target=(k.right and 1 or 0)-(k.left and 1 or 0)
 local rate=target==0 and 10 or ((target*self.steer<0) and 14 or 5.5)
 self.steer=self.steer+C.clamp(target-self.steer,-rate*dt,rate*dt)
 local inp=self.race.input
 inp.steer=self.steer
 inp.throttle=(k.accel or k.trigR or self.saved.autoAccel) and 1 or 0
 inp.brake=(k.brake or k.trigL) and 1 or 0
 inp.boost=k.boost and true or false
 inp.lean=(k.leanL and -1 or 0)+(k.leanR and 1 or 0)
 if self.saved.analog then
  local x,rt,lt=self:Probe('analog',readAnalog)
  if x then
   if abs(x)>abs(inp.steer) then inp.steer=x end
   if rt>inp.throttle then inp.throttle=rt end
   if lt>inp.brake then inp.brake=lt end
  end
 end
end
function A:OnEvent(kind,m,a)
 local ui=self.ui
 if kind=='count' then ui:Banner(tostring(a),.95,3);self.audio:Play('count')
 elseif kind=='go' then ui:Banner('GO!',1,3);self.audio:Play('go')
 elseif kind=='lap' then ui:Banner('ラップ '..m.lap,1.4,1.6);self.audio:Play('lap')
 elseif kind=='finalLap' then ui:Banner('ファイナルラップ',1.8,1.6);self.audio:Play('finalLap')
 elseif kind=='finish' then
  if m.player then ui:Banner('FINISH!',2.5,2.4);self.audio:Play('finish') end
 elseif kind=='wall' or kind=='bump' then
  ui:Shake(min(22,a*.6));ui:Hit(a);self.audio:Play(kind)
  if self.saved.rumble then self:Probe('rumble',rumble,120,min(1,a/40)) end
 elseif kind=='pad' then self.audio:Play('pad')
 elseif kind=='jump' then ui:Banner('JUMP!',.8,1.6);self.audio:Play('jump')
 elseif kind=='loop' then ui:Banner('SKY LOOP!',1.1,1.8);self.audio:Play('loop')
 elseif kind=='land' then ui:Shake(5);self.audio:Play('land')
 elseif kind=='explode' then
  if m.player then ui:Banner('リタイア',2.4,2.2);ui:Shake(30);self.audio:Play('explode') end
 elseif kind=='over' then
  self:ShowResult()
 end
end
-- ------------------------------------------------------------------------------------------
function A:Tick()
 local now=GetFrameTimeSeconds()
 local raw=now-(self.lastTick or now)
 local dt=min(.1,max(0,raw));self.lastTick=now
 local ui=self.ui
 ui:Tick(dt)
 if not self.state or not ui.scene:IsShowing() or not self.race then self.audio:Sync(false);return end
 self.audio:Sync(true)
 -- The reading counts every frame the engine ran, drawn or not: counting only the frames this
 -- add-on drew flatters it, because the drawn ones are exactly the slow ones.
 if self.saved.showFps then
  self.fpsAcc=(self.fpsAcc or 0)+min(raw,.25);self.fpsN=(self.fpsN or 0)+1
  if self.fpsAcc>=1 then
   self.fps=self.fpsN/self.fpsAcc
   ui:Text('fps',string.format('%d fps  %d rects  段階%d',floor(self.fps+.5),ui.view.o.n,self.gov))
   self.fpsAcc,self.fpsN=0,0
  end
 end
 if self.state=='race' and self.race.state=='racing' then self:Watch(raw) end
 if self.state=='race' then
  self:Controls(dt)
  local boosting=self.race.player.boosting
  self.race:Tick(dt)
  if boosting and not self.wasBoosting then self.audio:Play('boost') end
  self.wasBoosting=boosting
 end
 if now>=(self.drawAt or 0) then
  self.drawAt=now+max(self.saved.frameMs or 33,self.drawMs or 0)/1000
  local drawDt=min(.1,now-(self.lastDraw or now))
  ui:Draw(self.track,self.race,drawDt);self.lastDraw=now
  ui:Effects(self.race,drawDt,self.state=='race')
  local failed=ui:CheckPictures(now)
  if failed then self:RichFailed(failed) end
  if self.state~='garage' then ui:Hud(self.race,self.saved) end
  ui:TickBanner(now);ui:TickShake(dt)
  if self.footerUntil and now>self.footerUntil then self.footerUntil=nil;ui.footer:SetHidden(true) end
 end
end
-- ------------------------------------------------------------------------------------------
-- Frame-rate watch. Drawing is the expensive part and how expensive depends on the machine, so
-- rather than guess, the race measures its own frame rate and, if it stays low, lightens the
-- drawing one step at a time. It only ever lightens: a game that keeps changing its mind is worse
-- than one that settles. Steps: 1 fewer effects and roadside objects, far road updated a third
-- as often; 2 drawn every 50 ms; 3 drawn every 66 ms. The physics never slows down.
A.GOV_FLOOR=26          -- frames per second below which a window counts as slow
function A:Watch(raw)
 -- A stall (a scene change, the pause menu, a hitch) says nothing about the load.
 if raw>.25 then return end
 local w=self.watch
 w.t=w.t+raw;w.n=w.n+1;w.since=w.since+raw
 if w.t<2 then return end
 local fps=w.n/w.t
 w.t,w.n=0,0
 -- the first seconds of a race (the countdown's last moment, textures arriving) are not typical
 if w.since<5 or self.saved.governor==false or self.gov>=3 then w.slow=0;return end
 if fps<A.GOV_FLOOR then w.slow=w.slow+1 else w.slow=0 end
 if w.slow>=2 then w.slow=0;self:Lighten(fps) end
end
function A:Lighten(fps)
 self.gov=self.gov+1
 if self.gov==1 then
  self.ui.lite=true;if self.view then self.view.lite=true end
  self.ui.lodEvery=3
 elseif self.gov==2 then self.drawMs=50
 else self.drawMs=66 end
 self:Alert(string.format('F-MEGA：動作が重い（約%dfps）ため、描画を軽くしました（段階%d）。/pbfm gov で自動調整を切れます。',floor(fps+.5),self.gov))
end
function A:ResetGov()
 self.gov=0;self.drawMs=nil
 if self.ui then self.ui.lite=false;self.ui.lodEvery=2 end
 if self.view then self.view.lite=false end
 self.watch={t=0,n=0,since=0,slow=0}
end
function A:Initialize()
 self.saved=ZO_SavedVars:NewAccountWide('PBsFMEGASavedVariables',1,nil,{
  kind=1,level=2,quality='mid',musicMode='dueling',soundEnabled=true,showFps=false,
  analog=false,rumble=false,autoAccel=false,frameMs=33,lastCourse=1,rich=true,governor=true,verified={},best={}})
 local s=self.saved
 if s.pending then s[s.pending]=false;self.pendingNotice=s.pending;s.pending=nil end
 if not PBF.Machine.Types[s.kind] then s.kind=1 end
 if not A.QUALITY[s.quality] then s.quality='mid' end
 self.audio=PBF.Audio.New(s)
 self.gov=0;self.watch={t=0,n=0,since=0,slow=0}
 self.ui=PBF.UI.New(self);PBF.HookMenus(self)
 SLASH_COMMANDS['/pbfm']=function(arg)
  local word,rest=(arg or ''):match('^(%S*)%s*(.-)$')
  if word=='' then self:Open(s.lastCourse or 1)
  elseif word=='gov' then s.governor=not s.governor;self:ResetGov();self:Alert('自動で描画を軽くする：'..(s.governor and '入' or '切'))
  elseif word=='fps' then s.showFps=not s.showFps;self:Alert('FPS表示：'..(s.showFps and '入' or '切'))
  elseif word=='quality' then
   if A.QUALITY[rest] then s.quality=rest;self:ResetGov();self:ApplyQuality() else self:Alert('quality low / mid / high') end
  elseif word=='analog' then s.analog=not s.analog;s.verified.analog=nil;self:Alert('アナログ入力：'..(s.analog and '入（未検証）' or '切'))
  elseif word=='rumble' then s.rumble=not s.rumble;s.verified.rumble=nil;self:Alert('振動：'..(s.rumble and '入（未検証）' or '切'))
  elseif word=='auto' then s.autoAccel=not s.autoAccel;self:Alert('オートアクセル：'..(s.autoAccel and '入' or '切'))
  elseif word=='flat' then self:SetRich(false);self:Alert('描画：矩形のみ（画像なし）')
  elseif word=='rich' then self:SetRich(true);self:Alert('描画：画像あり')
  elseif word=='music' then self:Alert(self.audio:Cycle(self.state~=nil))
  elseif word=='sound' then s.soundEnabled=not s.soundEnabled;self:Alert('効果音：'..(s.soundEnabled and '入' or '切'))
  elseif word=='frame' then local ms=tonumber(rest);if ms and ms>=16 and ms<=100 then s.frameMs=ms;self:ResetGov();self:Alert('描画間隔：'..ms..' ms') else self:Alert('frame 16-100 (ミリ秒)') end
  elseif word=='debug' then d(self:Report())
  else self:Alert('/pbfm [fps|gov|quality low|mid|high|rich|flat|analog|rumble|auto|music|sound|frame ms|debug]') end
 end
 self.lastTick=GetFrameTimeSeconds()
 EVENT_MANAGER:RegisterForUpdate('PBsFMEGATick',0,function() self:Tick() end)
 local function leave() self:Hidden();if SCENE_MANAGER:IsShowing('pbfGame') then SCENE_MANAGER:Hide('pbfGame') end end
 EVENT_MANAGER:RegisterForEvent('PBsFMEGA',EVENT_CONTROLLER_DISCONNECTED,leave)
 EVENT_MANAGER:RegisterForEvent('PBsFMEGA',EVENT_PLAYER_DEACTIVATED,leave)
 EVENT_MANAGER:RegisterForEvent('PBsFMEGA',EVENT_PLAYER_COMBAT_STATE,function(_,combat) if combat then leave() end end)
 if self.pendingNotice then
  EVENT_MANAGER:RegisterForEvent('PBsFMEGANotice',EVENT_PLAYER_ACTIVATED,function()
   EVENT_MANAGER:UnregisterForEvent('PBsFMEGANotice',EVENT_PLAYER_ACTIVATED)
   self:Alert('F-MEGA：前回の「'..tostring(self.pendingNotice)..'」でエラーが出たため、無効にしました。')
  end)
 end
end
-- Turns the pictures on or off. Everything that depends on the mode is rebuilt from the view.
function A:SetRich(on)
 self.saved.rich=on and true or false
 if self.view then
  self.view:SetRich(on)
  if self.state then self.ui:Configure(self.view,self.track) end
 end
end
-- The loader gave a 1 x 1 placeholder for one of the pictures, which is what a missing or
-- unreadable texture looks like. Fall back to plain rectangles and say so, rather than leave
-- the player looking at nothing; /pbfm rich tries again.
function A:RichFailed(which)
 self:SetRich(false)
 self:Alert('F-MEGA：画像（'..tostring(which)..'）を読み込めなかったため、矩形のみの描画に切り替えました。')
end
function A:ApplyQuality()
 local band=A.QUALITY[self.saved.quality][1]
 if self.view then
  self.view.stripes=A.QUALITY[self.saved.quality][3]
  self.view:SetBand(band)
  if self.state then self.ui:Configure(self.view,self.track) end
 end
 self:Alert('描画品質：'..A.QUALITY[self.saved.quality][2]..'（'..band..'px）')
end
function A:Report()
 local v=self.view
 return string.format('F-MEGA state=%s mode=%s quality=%s band=%s rects=%s controls=%d frameMs=%s lua=%.1fMB analog=%s rumble=%s gov=%d fps=%s',tostring(self.state),(v and v.rich) and 'rich' or 'flat',tostring(self.saved.quality),
  v and v.band or '-',v and v.o.n or '-',self.ui and (function() local n=0 for _ in pairs(self.ui.slots) do n=n+1 end return n end)() or 0,
  tostring(self.saved.frameMs),collectgarbage('count')/1024,tostring(self.saved.analog),tostring(self.saved.rumble),self.gov,self.fps and string.format('%.0f',self.fps) or '-')
end
EVENT_MANAGER:RegisterForEvent('PBsFMEGA',EVENT_ADD_ON_LOADED,function(_,name)
 if name=='PBsFMEGA' then EVENT_MANAGER:UnregisterForEvent('PBsFMEGA',EVENT_ADD_ON_LOADED);A:Initialize() end
end)
