-- DIAhelp combat session arithmetic, original code, GPL-3.0-or-later.
DIAhelpCombatModel = {}
local M = DIAhelpCombatModel
function M.New()
    return {active=false, damage=0, healing=0, incoming=0, hits=0, crits=0, duration=0, targets={}}
end
function M.Start(s,now)
    if s.active then return end
    s.active=true s.started=now s.duration=0 s.targets={} s.currentTarget=nil
    s.damage=0 s.healing=0 s.incoming=0 s.hits=0 s.crits=0
end
function M.Stop(s,now)
    if not s.active then return end
    s.duration=math.max(0,now-s.started) s.active=false
end
function M.Add(s,kind,value,critical)
    if not s.active or type(value)~="number" or value<=0 then return end
    s[kind]=s[kind]+value
    if kind=="damage" then
        s.hits=s.hits+1
        if critical then s.crits=s.crits+1 end
    end
end
function M.Values(s,now)
    local duration=s.active and math.max(0,now-s.started) or s.duration
    local divisor=math.max(1,duration)
    return duration,s.damage/divisor,s.healing/divisor,s.incoming/divisor,
        s.hits>0 and 100*s.crits/s.hits or 0
end
-- Estimate share only for targets whose HP we can observe, not all group damage.
function M.Observe(s,id,health,maximum)
    if not s.active or not id or maximum<=0 then return end
    local t=s.targets[id]
    if not t then s.targets[id]={health=health,maximum=maximum,lost=0,own=0} return end
    if t.maximum==maximum then t.lost=t.lost+math.max(0,t.health-health) end
    t.health=health t.maximum=maximum
end
function M.TargetDamage(s,id,value)
    local t=s.targets[id]
    if s.active and t and type(value)=='number' and value>0 then t.own=t.own+value s.currentTarget=id end
end
function M.Share(s)
    local target=s.currentTarget and s.targets[s.currentTarget]
    if not target or target.lost<=0 then return nil end
    return 100*math.min(target.own,target.lost)/target.lost
end
