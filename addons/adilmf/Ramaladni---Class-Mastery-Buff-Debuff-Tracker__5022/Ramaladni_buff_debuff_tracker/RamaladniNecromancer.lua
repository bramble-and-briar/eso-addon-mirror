-- Ramaladni Tracker v0.9.23 — Necromancer isolated runtime.
-- Mechanics copied from the v0.9.22 reference; other classes are not modified.
local M=RamaladniMastery
local shared=M.shared
local SkillState,LeadNow,HideState=shared.SkillState,shared.LeadNow,shared.HideState
local lead=shared.lead
local runtime={}
M.modules["Necromancer"]=runtime
do
local e={key="Necromancer:Nothing Wasted",class="Necromancer",en="Nothing Wasted",title="Бережливость / Nothing Wasted",passiveId=263448,candidateIDs={263461,263462},model="stacks_percent",value=2,cap=10,target=false,kind="stacks_percent+timer",mechanic="2% Max Health and Weapon/Spell Damage per stack, max 10 = 20%; decay 2 stacks per interval",durationRule="12 sec per stack duration/decay cycle per Update 51; actual buff endTime if game exposes"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Necromancer:Malevolent Promise",class="Necromancer",en="Malevolent Promise",title="Зловещее обещание / Malevolent Promise",passiveId=263465,candidateIDs={263468},model="observed_stacks",value=0,cap=0,target=true,kind="target_mark_timer+cooldown",mechanic="Marks nearest non-player enemy for corpse-consuming use",durationRule="6 sec mark; once every 2 sec"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Necromancer:Cycle Unending",class="Necromancer",en="Cycle Unending",title="Бесконечный цикл / Cycle Unending",passiveId=263509,candidateIDs={263532},model="target_health_percent",value=1,cap=25,target=false,kind="conditional_percent+timer",mechanic="1% damage per 1% Health advantage versus target, max 25% PvE /10% PvP",durationRule="25 sec"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Necromancer:Pound of Flesh",class="Necromancer",en="Pound of Flesh",title="Плата плотью / Pound of Flesh",passiveId=263549,candidateIDs={107994,108005,263552,263553},model="player_missing_health",value=10,cap=0,target=false,kind="conditional_chance+proc_counter",mechanic="10% base chance plus 1% for each missing Health percent, +1600 heal and restores 5% missing Stamina",durationRule="Proc at most once per sec, not an ongoing buff"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Necromancer:Veil's Forfeit",class="Necromancer",en="Veil's Forfeit",title="Жертва Завесы / Veil's Forfeit",passiveId=263554,candidateIDs={263555,268256},model="observed_stacks",value=0,cap=0,target=false,kind="conditional_window_timer+debuff_extension",mechanic="Directly heal target below 66% to allow corpse-consuming use; extends your Major Vulnerability by 50%",durationRule="10 sec special window; Major Vulnerability actual endTime"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end

local NOTHING_DURATION=12
runtime.OnObservedEffect=function(entry,meta,state,change,start,finish,stacks,source,actualId,now)
  if meta.key~="Necromancer:Nothing Wasted" then return end
  if actualId~=263461 and actualId~=263462 then return end
  if change==EFFECT_RESULT_FADED then
    state.masteryLastStacks=0
    state.masteryLastBegin=nil
    state.masteryEstimatedUntil=nil
    state.timerEstimated=false
    return
  end
  local n=tonumber(stacks) or 0
  if n<=0 then return end
  if type(finish)=='number' and finish>now then
    state.masteryLastStacks=n
    state.masteryLastBegin=start
    state.masteryEstimatedUntil=nil
    state.timerEstimated=false
    return
  end
  local stackChanged=(state.masteryLastStacks~=n)
  local refreshed=(source=='effect-event' and change==EFFECT_RESULT_GAINED)
  local beginChanged=(source=='effect-event' and type(start)=='number' and start>0 and
                      state.masteryLastBegin and start>state.masteryLastBegin+0.05)
  if stackChanged or refreshed or beginChanged then
    state.masteryEstimatedUntil=now+NOTHING_DURATION
  end
  state.masteryLastStacks=n
  if type(start)=='number' and start>0 then state.masteryLastBegin=start end
  if state.masteryEstimatedUntil and state.masteryEstimatedUntil>now then
    state.untilTime=state.masteryEstimatedUntil
    state.timerEstimated=true
  else
    state.untilTime=0
    state.timerEstimated=false
  end
end
runtime.Init=function() end
runtime.Display=function() return false,nil end


