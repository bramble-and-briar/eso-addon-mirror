ACTION_RESULT_HEAL=5
local env=dofile('tests/standalone.lua')
local meter,bridge=SimpleGroupDPS_DamageMeter,SimpleGroupDPS_BattleScrolls
LFG_ROLE_DPS,LFG_ROLE_HEAL=1,4
local role=LFG_ROLE_DPS
function GetSelectedLFGRole() return role end
function GetGroupMemberSelectedRole() return LFG_ROLE_DPS end
function DoesUnitExist(tag) return tag=='group1' end
function GetUnitDisplayName(tag) return tag=='group1' and '@Peer' or '@Me' end
function AreUnitsEqual(a,b) return a==b end
assert(env.menu['DPS/HPS mit Gruppe teilen']==nil and bridge.SetSharingEnabled==nil,
    'Temporary sharing switch is removed')
BattleScrolls=nil
local sent,protocols={},{}
local enabled=true
LibGroupBroadcast={CreateNumericField=function() return {} end,CreateOptionalField=function(field) return field end,
 RegisterHandler=function() return {SetDisplayName=function() end,SetDescription=function() end,
 DeclareProtocol=function(_,id)
  local p={AddField=function() end,OnData=function(self,fn) self.receive=fn end,
   Finalize=function() return true end,IsEnabled=function() return enabled end,
   Send=function(_,data) sent[#sent+1]={id=id,data=data};return true end}
  protocols[id]=p;return p
 end} end}
assert(bridge:Connect())
bridge:Clear()
env.saved.shareDPS=false -- A previous test preference cannot keep normal sharing disabled.
env.setClock(800000);env.setCombat(true)
env.events['SimpleGroupDPSDamageState:combat'](nil,true)
env.setClock(801000)
meter:OnDamage(1,false,1,'Enemy',0,1000,10,99)
env.tick()
assert(#sent==1 and sent[1].id==430 and meter:GetStats().dps==1000)
protocols[430].receive('group1',sent[1].data)
assert(math.abs(bridge:GetRows()[1].dps/1000-1)<0.003,'Own DPS packet follows the BattleScrolls wire codec')
env.tick()
assert(#sent==1,'Automatic DPS sends respect the 300ms send budget')
role=LFG_ROLE_HEAL
env.setClock(802000)
meter:OnDamage(5,false,1,'Self',1,400,99,99,1600,123)
env.tick()
assert(#sent==2 and sent[2].id==431 and sent[2].data.encodedEffectiveHPS==400,
 'Higher raw HPS automatically selects healing regardless of role')
enabled=false
env.setClock(802500);env.tick()
assert(#sent==2,'LibGroupBroadcast native send preference is respected')
enabled=true
env.setClock(802800);env.tick()
assert(#sent==3)
env.setCombat(false)
env.events['SimpleGroupDPSDamageState:combat'](nil,false)
env.updates.SimpleGroupDPSDamageReset()
assert(#sent==4 and sent[4].id==431 and env.saved.lastSummary.damageTotal==1000
 and env.saved.lastSummary.rawHPS==2000 and env.saved.lastSummary.effectiveHPS==400,
 'Final HPS is forced to the queue and the same own result is saved')
assert(meter:GetStats().dps==1000 and meter:GetStats().durationMS==1000,
 'Restored sending does not change measured damage or timer')
print('PASS: automatic DPS/HPS sharing, legacy-off ignored, native permission, 300ms budget, final send and unchanged measurement')
