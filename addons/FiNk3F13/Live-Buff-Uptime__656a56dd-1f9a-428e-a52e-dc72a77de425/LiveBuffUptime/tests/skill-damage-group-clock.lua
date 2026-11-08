local clock=900
ACTION_RESULT_DAMAGE,ACTION_RESULT_HEAL=1,2
COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_PLAYER_PET,COMBAT_UNIT_TYPE_GROUP=1,2,4
function GetGameTimeMilliseconds() return 100000+clock end
function GetFrameTimeSeconds() return clock/1000 end
function DoesUnitExist() return false end
EVENT_MANAGER={UnregisterForUpdate=function() end}
dofile('../SimpleGroupDPS/DamageMeter.lua')
dofile('BuffReports.lua')
local meter,reports=SimpleGroupDPS_DamageMeter,LiveBuffUptimeReports
local function hit(time,source,target,amount)
 clock=time
 meter:OnDamage(1,false,source,'Target',target,amount,900,source==1 and 1 or 2)
 reports.RecordNativeEncounterDamage(GetGameTimeMilliseconds())
 reports.RecordNativeDamage(GetFrameTimeSeconds(),source,target,900,'Target',amount,123,'Skill')
end
hit(900,1,7,500)
clock=1000
meter:Start(GetGameTimeMilliseconds())
reports.BeginNativeDamage(GetFrameTimeSeconds(),false)
reports.StartNativeEncounterClock(GetGameTimeMilliseconds())
clock=3000; reports.BeginNativeDamage(GetFrameTimeSeconds(),false,true) -- delayed library notification
hit(13000,1,7,1000)
hit(20000,4,7,9000)
hit(21000,7,1,500)
hit(22000,0,0,9999)
hit(23000,1,7,0)
clock=24000; meter:OnDamage(2,false,1,'Self',1,5000,1,1,5000,777)
clock=30000
local skills=reports.FinishNativeDamage()
meter:Finish()
local group=meter:GetStats()
assert(skills.total==1500 and group.total==skills.total)
assert(skills.duration==22 and skills.duration*1000==group.durationMS,
 'real LiveBuffUptime skill calculation follows the unchanged group clock, including other players, incoming and zero damage')
assert(skills.total/skills.duration==group.dps,'own DPS matches the group display without counting group damage in the numerator')
clock=40000; meter:Start(GetGameTimeMilliseconds()); reports.BeginNativeDamage(GetFrameTimeSeconds(),false)
reports.StartNativeEncounterClock(GetGameTimeMilliseconds()); hit(40000,1,7,2000)
clock=40300
skills=reports.FinishNativeDamage(); meter:Finish(); group=meter:GetStats()
assert(skills.duration==0.3 and skills.duration*1000==group.durationMS and skills.total/skills.duration==group.dps,
 'single-hit fallback and subsecond duration use the same rule without an extra one-second floor')
print('Skill/group parity: actual independent modules, unchanged group addon, buffered first hits, delayed library start, raid damage, zero damage and fallback duration')
