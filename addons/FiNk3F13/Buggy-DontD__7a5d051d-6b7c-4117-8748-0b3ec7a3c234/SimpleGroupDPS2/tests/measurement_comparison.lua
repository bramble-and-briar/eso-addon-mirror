local clock=1000
ACTION_RESULT_DAMAGE=1; COMBAT_UNIT_TYPE_PLAYER=1
function GetGameTimeMilliseconds() return clock end
function DoesUnitExist() return false end
EVENT_MANAGER={UnregisterForUpdate=function() end}
dofile('DamageMeter.lua')
dofile('MeasurementComparison.lua')
local meter=SimpleGroupDPS2_DamageMeter
local comparison=SimpleGroupDPS2_MeasurementComparison
meter:Start(clock)
clock=2000
meter:OnDamage(1,false,1,'Enemy',0,1000,42,1,0,123)
local native={initialized=true,fightStartTimeMs=900,lastDamageDoneMs=2000,
 damageByUnitId={[1]={[42]={total=1500}}},unitIdToName={[42]='Enemy'}}
local calculator={personalTotalDamage=function() return 1500 end,getDurationS=function() return 1.1 end,
 personalDPS=function() return 1500/1.1 end,groupTotalDamage=function() return 1500 end,
 personalRawHPSOut=function() return 200 end,personalEffectiveHPSOut=function() return 100 end}
BattleScrolls={state=native,arithmancer={Make=function(_,state) assert(state==native);return calculator end}}
assert(comparison:Capture(false))
local latest=comparison:GetLatest()
assert(latest.own.stats.total==1000 and latest.native.total==1500)
assert(latest.own.startMS==1000 and latest.native.startMS==900)
assert(#latest.differences==1 and latest.differences[1].own==1000 and latest.differences[1].native==1500)
assert(meter:GetStats().total==1000 and meter:GetStats().dps==1000,
 'Native values are diagnostic only; they cannot enter own damage, DPS or duration')
assert(native.damageByUnitId[1][42].total==1500 and native.fightStartTimeMs==900,
 'Diagnostic does not alter BattleScrolls state')
clock=2500
assert(not comparison:Capture(false),'Diagnostic scan is limited to one per second')
meter:Finish();native.initialized=false;clock=3000
local lines={};function d(value) lines[#lines+1]=value end
comparison:Print()
assert(lines[1]:find('1.0 s',1,true),'Post-fight report explicitly shows snapshot age')
assert(lines[2]:find('1.000 / 1.100',1,true) and lines[6]:find('1000 / 1500',1,true))
BattleScrolls=nil;SimpleGroupDPS2_DamageMeter=nil
comparison:Print()
assert(comparison:GetLatest()==latest,'Report retains its last comparison without depending on a current native state')
print('PASS: independent native comparison, target mismatch, precision, no mutation, bounded sampling and post-fight report')
