ACTION_RESULT_HEAL=5
local env=dofile('tests/standalone.lua')
local meter,bridge=SimpleGroupDPS_DamageMeter,SimpleGroupDPS_BattleScrolls
assert(env.saved.shareDPS==nil and env.menu['DPS/HPS mit Gruppe teilen']==nil)
assert(bridge.SendDPS==nil and bridge.SendHPS==nil and bridge.SendMetrics==nil
    and bridge.SetSharingEnabled==nil and bridge.ResetSendClock==nil,
    'Outgoing metric API and obsolete send controls are physically absent')
-- Fail immediately if our addon tries to submit a protocol packet.
BattleScrolls=nil
local protocols,sends={},0
LibGroupBroadcast={CreateNumericField=function() return {} end,
    CreateOptionalField=function(field) return field end,
    RegisterHandler=function() return {SetDisplayName=function() end,SetDescription=function() end,
        DeclareProtocol=function(_,id)
            local protocol={AddField=function() end,Finalize=function() return true end,
                OnData=function(self,fn) self.receive=fn end,
                Send=function() sends=sends+1;error('Outgoing metrics are forbidden') end}
            protocols[id]=protocol;return protocol
        end} end}
assert(bridge:Connect())
function DoesUnitExist(tag) return tag=='group1' end
function GetUnitDisplayName(tag) return tag=='group1' and '@Peer' or '@Me' end
function AreUnitsEqual(a,b) return a==b end
bridge:Clear()
protocols[430].receive('group1',{encodedAllDPS=255})
assert(#bridge:GetRows()==1 and bridge:GetRows()[1].dps==255,'Peer reception is preserved')
env.setClock(800000);env.setCombat(true)
env.events['SimpleGroupDPSDamageState:combat'](nil,true)
env.setClock(801000)
meter:OnDamage(1,false,1,'Enemy',0,5000,10,99)
env.tick()
assert(meter:GetStats().dps==5000 and not env.window.hidden)
env.saved.shareDPS=true -- Even manually restoring the obsolete variable cannot enable sending.
env.setClock(802000)
meter:OnDamage(5,false,1,'Self',1,500,99,99,500,123)
env.tick()
assert(meter:GetStats().rawHPS==1000 and meter:GetStats().total==5000)
env.setCombat(false)
env.events['SimpleGroupDPSDamageState:combat'](nil,false)
env.updates.SimpleGroupDPSDamageReset()
assert(sends==0 and env.saved.lastSummary.damageTotal==5000 and env.saved.lastSummary.rawHPS==1000,
    'Live updates and combat completion never send DPS/HPS, even with old sharing enabled')
print('PASS: receive-only addon, no sending API/menu, legacy preferences inert, own DPS/HPS and final result preserved')
