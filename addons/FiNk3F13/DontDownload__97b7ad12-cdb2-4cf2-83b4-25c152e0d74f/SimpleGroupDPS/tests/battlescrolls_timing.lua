-- Acceptance cases from BattleScrolls ef6d762d48998fa91e302d99fafce334568a3845
-- state.lua ChangePlayerCombatState/OnCombatEvent and arithmancer.lua getDurationS.
local clock,inCombat=900,true
local events={}
ACTION_RESULT_DAMAGE,ACTION_RESULT_HEAL=1,2
COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_GROUP=1,4
EVENT_COMBAT_EVENT,EVENT_PLAYER_COMBAT_STATE,EVENT_BOSSES_CHANGED,EVENT_EFFECT_CHANGED=1,2,3,4
function GetGameTimeMilliseconds() return clock end
function IsUnitInCombat() return inCombat end
function DoesUnitExist() return false end
EVENT_MANAGER={RegisterForEvent=function(_,name,_,fn) events[name]=fn end,UnregisterForUpdate=function() end}
dofile('DamageMeter.lua')
local meter=SimpleGroupDPS_DamageMeter
meter:Initialize()
meter:OnDamage(1,false,1,'Dummy',7,500,10)
clock=1000
events.SimpleGroupDPSDamageState(nil,true)
assert(meter:GetStats().total==500 and meter:GetStats().durationMS==0 and meter:GetStats().dps==0,
    'Buffered damage does not backdate combat initialization')
clock=1300
assert(meter:GetStats().durationMS==300 and math.abs(meter:GetStats().dps-500000/300)<0.000001)
clock=12000
assert(meter:GetStats().durationMS==11000,'Before a later damage event, BattleScrolls falls back to current time')
clock=13000
meter:OnDamage(1,false,1,'Dummy',7,1000,10)
clock=17000
assert(meter:GetStats().durationMS==12000 and meter:GetStats().dps==125,
    'Once later damage exists, idle time no longer changes the damage clock')
clock=20000
meter:OnDamage(1,false,4,'Dummy',7,9000,10)
assert(meter:GetStats().total==1500 and meter:GetStats().durationMS==19000)
clock=21000
meter:OnDamage(1,false,0,'Player',1,100,99,10)
assert(meter:GetStats().total==1500 and meter:GetStats().durationMS==20000)
clock=22000
meter:OnDamage(1,false,0,'Unknown target',0,9999,88,77)
assert(meter:GetStats().total==1500 and meter:GetStats().durationMS==21000,
    'All observed damage advances time, without attributing unknown damage to the player')
clock=23000
meter:OnDamage(1,false,1,'Dummy',7,0,10)
assert(meter:GetStats().durationMS==22000,'Zero-value damage events update lastDamageDoneMs')
clock=24000
meter:OnDamage(2,false,1,'Player',1,100,99,99,0,123)
assert(meter:GetStats().durationMS==22000,'Healing does not update last damage time')
clock=30000
meter:Finish()
assert(meter:GetStats().durationMS==22000,'Final result retains the same damage clock')
clock=40000
meter:Start(clock)
meter:OnDamage(1,false,1,'Dummy',7,2000,10)
clock=40677
meter:OnDamage(1,false,1,'Dummy',7,2319,10)
assert(meter:GetStats().durationMS==677 and math.floor(meter:GetStats().dps+0.5)==6380,
    'No one-second floor: subsecond time and DPS follow BattleScrolls')
print('PASS: original BattleScrolls timing: combat entry, fallback, every damage source, idle freeze and subsecond DPS')
