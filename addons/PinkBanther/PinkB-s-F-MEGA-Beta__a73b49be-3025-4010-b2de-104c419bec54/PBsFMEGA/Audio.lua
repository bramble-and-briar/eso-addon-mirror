PBF=PBF or {}
local Audio={};Audio.__index=Audio;PBF.Audio=Audio
-- Every name here was checked against the client's own sound table; a name that is missing
-- simply plays nothing, so the lookup is guarded rather than trusted.
local ids={count='COUNTDOWN_TICK',go='BATTLEGROUND_COUNTDOWN_FINISH',lap='LEVEL_UP',finalLap='DUEL_BOUNDARY_WARNING',
 finish='DUEL_WON',lose='DUEL_FORFEIT',wall='LOCKPICKING_CHAMBER_LOCKED',bump='NEGATIVE_CLICK',pad='SCRYING_CAPTURE_HEX_LARGE',
 boost='ENCHANTING_POTENCY_RUNE_PLACED',explode='ABILITY_FAILED',select='DEFAULT_CLICK',
 -- the two sounds of a jump: the launch, and the thump of coming back down (both checked against the client's sound table)
 jump='SCRYING_CAPTURE_GOAL',land='LOCKPICKING_CHAMBER_STRESS'}
local modes={{key='off',label='BGM：切'},{key='dueling',label='BGM：決闘'},{key='champion',label='BGM：星座'},{key='tribute',label='BGM：カード'},{key='credits',label='BGM：終幕'}}
-- The music override is the mechanism PBsTetris already proved on a PS5. Named outright rather
-- than looked up in _G, and resolved on first use so the client has certainly finished loading.
local overrides
local function override(key)
 if not overrides then
  overrides={tribute=OVERRIDE_MUSIC_MODE_TRIBUTE,champion=OVERRIDE_MUSIC_MODE_CHAMPION,dueling=OVERRIDE_MUSIC_MODE_DUELING,credits=OVERRIDE_MUSIC_MODE_CREDITS}
 end
 return overrides[key]
end
local order={};for i,mode in ipairs(modes) do order[mode.key]=i end
function Audio.New(saved) return setmetatable({saved=saved,last={}},Audio) end
function Audio:Index() return order[self.saved.musicMode] or order.dueling end
function Audio:Label() return modes[self:Index()].label end
function Audio:Cycle(active)
 self.saved.musicMode=modes[self:Index()%#modes+1].key;self.yielded=nil;self:Sync(active);return self:Label()
end
function Audio:Report()
 local key=modes[self:Index()].key
 return string.format('%s / 設定 %s / 要求 %s / 現在 %s / 所有 %s',self:Label(),key,tostring(override(key)),
  tostring(GetOverrideMusicMode and GetOverrideMusicMode()),self.owned and 'あり' or (self.yielded and '譲渡' or 'なし'))
end
function Audio:Play(kind)
 if self.saved.soundEnabled==false then return end
 local now=GetFrameTimeSeconds();if now-(self.last[kind] or -100)<(kind=='pad' and .5 or .09) then return end
 self.last[kind]=now
 local id=SOUNDS and SOUNDS[ids[kind]]
 if id and PlaySound then PlaySound(id) end
end
function Audio:Sync(active)
 local want=active and override(modes[self:Index()].key)
 if not want then self:Stop();return end
 if not (GetOverrideMusicMode and SetOverrideMusicMode) then return end
 if self.owned then
  if self.mode==want then return end
  if GetOverrideMusicMode()~=self.mode then self.owned=false;self.previous=nil;self.yielded=true;return end
  if pcall(SetOverrideMusicMode,want) then self.mode=want end
  return
 end
 if self.yielded then return end
 local previous=GetOverrideMusicMode()
 if pcall(SetOverrideMusicMode,want) then self.owned=true;self.previous=previous;self.mode=want end
end
function Audio:Stop()
 if self.owned then
  if GetOverrideMusicMode and GetOverrideMusicMode()==self.mode then pcall(SetOverrideMusicMode,self.previous) end
  self.owned=false;self.previous=nil
 end
 self.yielded=nil
end
