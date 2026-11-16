ACTION_RESULT_HEAL=5
local env=dofile('tests/standalone.lua')
local meter,bridge=SimpleGroupDPS2_DamageMeter,SimpleGroupDPS2_BattleScrolls
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

assert(bridge.SendDPS==nil and bridge.SendHPS==nil and bridge.SendMetrics==nil)
env.setClock(800000);env.setCombat(true)
env.events['SimpleGroupDPS2DamageState:combat'](nil,true)
env.setClock(801000)
meter:OnDamage(1,false,1,'Enemy',0,1000,10,99)
env.tick()
assert(#sent==0 and meter:GetStats().dps==1000)
protocols[430].receive('group1',{encodedAllDPS=255,encodedBossDPS=100})
assert(bridge:GetRows()[1].dps==255 and meter:GetStats().dps==1000)
role=LFG_ROLE_HEAL
env.setClock(802000)
meter:OnDamage(5,false,1,'Self',1,400,99,99,600,123)
env.tick()
assert(#sent==0 and meter:GetStats().rawHPS==1000)
env.setCombat(false)
env.events['SimpleGroupDPS2DamageState:combat'](nil,false)
env.updates.SimpleGroupDPS2DamageReset()
assert(#sent==0 and env.saved.lastSummary.damageTotal==1000
 and env.saved.lastSummary.rawHPS==1000 and env.saved.lastSummary.effectiveHPS==400)
assert(meter:GetStats().dps==1000 and meter:GetStats().durationMS==1000)
print('PASS: receive-only test build: zero packets during live DPS, healing and finalization; independent measurements preserved')
