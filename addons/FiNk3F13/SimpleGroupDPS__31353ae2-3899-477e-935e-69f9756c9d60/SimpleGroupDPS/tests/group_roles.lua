local env = dofile('tests/standalone.lua')
LFG_ROLE_DPS,LFG_ROLE_TANK,LFG_ROLE_HEAL=1,2,4
local peerRole=1
function GetGroupMemberSelectedRole() return peerRole end
function GetSelectedLFGRole() return 1 end
local bridge=SimpleGroupDPS_BattleScrolls
bridge:Clear()
local function peerRow()
 for key,row in pairs(env.window.swtGroupDPSLabels) do
  if type(key)=='number' and row.text=='Replacement' and not row.hidden then return row end
 end
 error('missing peer')
end
for _,role in ipairs({1,2,4}) do
 peerRole=role
 env.receive('group1',{messageType='healing',rawHPS=2200,effectiveHPS=100})
 assert(peerRow().swtDPSValue.text=='100 (2,2 Tsd.)','All roles display the received healing type')
 assert(bridge:GetRows()[1].displayType=='healing' and not bridge:GetRows()[1].stale)
 assert(not env.window.swtGroupDPSLabels.healingHeader.hidden)
 local icon=role==2 and 'tank' or (role==4 and 'healer' or 'dps')
 assert(peerRow().swtIcon.texture:find(icon,1,true),'Role icon stays independent of metric type')
 env.receive('group1',{messageType='damage',allTargetsDPS=13200,bossDPS=13200})
 assert(peerRow().swtDPSValue.text=='13,2 Tsd.','All roles display a new damage packet immediately')
 assert(bridge:GetRows()[1].displayType=='damage' and not bridge:GetRows()[1].stale)
 assert(env.window.swtGroupDPSLabels.healingHeader.hidden)
 assert(peerRow().swtIcon.texture:find(icon,1,true))
end
env.receive('group1',{messageType='healing',rawHPS=0,effectiveHPS=0})
assert(peerRow().swtDPSValue.text=='0 (0)','Received healing zero stays a valid healing packet')
print('PASS: BattleScrolls received message type controls metric for DD, tank and healer; role icons retained')
