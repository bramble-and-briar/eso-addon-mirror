-- Native BattleScrolls network/dpsshare.lua classifyData selects healing only
-- when rawHPS > allTargetsDPS; role is not part of that decision.
dofile('BattleScrollsBridge.lua')
local bridge=SimpleGroupDPS_BattleScrolls
LFG_ROLE_DPS,LFG_ROLE_TANK,LFG_ROLE_HEAL=1,2,4
local role,kind,values
function GetSelectedLFGRole() return role end
bridge.SendDPS=function(_,dps,force,boss) kind='damage';values={dps,force,boss};return true end
bridge.SendHPS=function(_,raw,effective,force) kind='healing';values={raw,effective,force};return true end
for _,r in ipairs({1,2,4}) do
    role=r
    assert(bridge:SendMetrics({dps=3000,bossDPS=2000,rawHPS=10700,effectiveHPS=1100},false))
    assert(kind=='healing' and values[1]==10700 and values[2]==1100 and values[3]==false)
    bridge:SendMetrics({dps=3000,bossDPS=2000,rawHPS=2400,effectiveHPS=1100},true)
    assert(kind=='damage' and values[1]==3000 and values[2]==true and values[3]==2000)
    bridge:SendMetrics({dps=3000,bossDPS=2000,rawHPS=3000,effectiveHPS=1100},false)
    assert(kind=='damage','Equal HPS and DPS selects damage, exactly as BattleScrolls')
end
print('PASS: automatic sender classification matches BattleScrolls for DD/tank/healer, ties and final-force forwarding')
