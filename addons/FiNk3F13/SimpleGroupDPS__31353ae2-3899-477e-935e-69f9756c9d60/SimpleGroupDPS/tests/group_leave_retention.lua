local env=dofile('tests/standalone.lua')
LFG_ROLE_DPS,LFG_ROLE_TANK,LFG_ROLE_HEAL=1,2,4
local grouped=true
local names={group1='@DD',group2='@Tank',group3='@Healer'}
local roles={group1=1,group2=2,group3=4}
function IsUnitGrouped() return grouped end
function DoesUnitExist(tag) return grouped and names[tag]~=nil end
function GetUnitDisplayName(tag) return names[tag] or '@Me' end
function AreUnitsEqual(a,b) return a==b end
function GetSelectedLFGRole() return 1 end
function GetGroupMemberSelectedRole(tag)
 assert(grouped,'Detached rows must not query old unit-tag roles');return roles[tag]
end
function GetUnitClassId(tag)
 if tag~='player' then assert(grouped,'Detached rows must preserve cached class IDs') end
 return tag=='group1' and 1 or 4
end
local bridge,meter=SimpleGroupDPS_BattleScrolls,SimpleGroupDPS_DamageMeter
bridge:Clear();env.saved.lingerSeconds=60
local function row(name)
 for key,value in pairs(env.window.swtGroupDPSLabels) do
  if type(key)=='number' and value.text==name and not value.hidden then return value end
 end
end
env.setClock(800000);env.setCombat(true)
env.events['SimpleGroupDPSDamageState:combat'](nil,true)
env.setClock(801000);meter:OnDamage(1,false,1,'Enemy',0,1000,42,1)
env.receive('group1',{messageType='damage',allTargetsDPS=5000,bossDPS=4000})
env.receive('group2',{messageType='damage',allTargetsDPS=2000,bossDPS=1000})
env.receive('group3',{messageType='healing',rawHPS=10000,effectiveHPS=3000})
local before={DD=row('DD').swtDPSValue.text,Tank=row('Tank').swtDPSValue.text,Healer=row('Healer').swtDPSValue.text}
local tankIcon=row('Tank').swtIcon.texture
env.setClock(802000);env.setCombat(false);meter:Finish()
local summary=env.window.swtGroupDPSLabels.summary.swtDPSValue.text
grouped=false;names={}
env.setClock(803000);env.events['SimpleGroupDPSGroup:group']()
assert(#bridge:GetRows()==3 and row('Me') and row('DD') and row('Tank') and row('Healer'))
for name,value in pairs(before) do assert(row(name).swtDPSValue.text==value) end
assert(row('Tank').swtIcon.texture==tankIcon and env.window.swtGroupDPSLabels.summary.swtDPSValue.text==summary)
env.receive('group1',{messageType='damage',allTargetsDPS=999999})
assert(row('DD').swtDPSValue.text==before.DD,'Late callbacks after leaving cannot corrupt retained result')
env.setClock(861999);env.tick()
assert(row('DD') and row('Tank') and row('Healer'),'All result rows last for the configured time after fight end')
env.setClock(862000);env.tick()
assert(#bridge:GetRows()==0 and env.window.hidden,'Own and group results expire together without extending on each refresh')
-- A new group must not display the previous group's identities or inherit slot metrics.
grouped=true;names={group1='@OldDD'};env.setClock(900000)
env.receive('group1',{messageType='damage',allTargetsDPS=7000})
grouped=false;env.events['SimpleGroupDPSGroup:group']();assert(row('OldDD'))
grouped=true;names={group1='@NewDD'};env.events['SimpleGroupDPSGroup:group']()
assert(not row('OldDD') and #bridge:GetRows()==0)
env.receive('group1',{messageType='damage',allTargetsDPS=8000});assert(row('NewDD'))
-- Starting a new solo fight clears the archived group, not the independent meter.
grouped=false;env.events['SimpleGroupDPSGroup:group']();assert(row('NewDD'))
env.setClock(901000);env.setCombat(true)
env.events['SimpleGroupDPSDamageState:combat'](nil,true);env.tick()
assert(#bridge:GetRows()==0 and not row('NewDD') and meter:IsActive())
print('PASS: group leave preserves all roles/values/icons and summary; shared expiry; no late packets or next-group/solo contamination')
