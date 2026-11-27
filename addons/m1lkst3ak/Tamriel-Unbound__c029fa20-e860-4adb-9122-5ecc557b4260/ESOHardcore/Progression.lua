local N=ESOHardcore; local s=N.safe
local function c() return N.hardcore.saved end
local function active() return N.visualActive() end
local function stats() local a=c();a.journal=a.journal or {actions={},nodes={},observations={}};return a.journal end
function N.journalAction(k) if active() then local j=stats();j.actions[k]=(j.actions[k] or 0)+1 end end
function N.recordNode()
 if not active() or N.rank('Harvesting')<15 then return end
 -- Read world position only; never change the selected native map.
 local zone,x,y,z=s(GetUnitWorldPosition,'player');if type(zone)~='number' or type(x)~='number' or type(z)~='number' then return end
 local j=stats();local key=zone..':'..math.floor(x/250)..':'..math.floor(z/250);local node=j.nodes[key];if node then node.visits=node.visits+1 elseif (j.nodeCount or 0)<5000 then j.nodes[key]={zone=zone,x=x,z=z,name=s(GetUnitZone,'player') or '?',visits=1};j.nodeCount=(j.nodeCount or 0)+1 end
end
local last=0;local warned={}
local function warn(key,msg,on) if on and not warned[key] and d then d('Hardcore: '..msg) end;warned[key]=on end
function N.progressTick(dt,visible,combat)
 if not active() or not visible then return end
 last=last+dt;if last<3 then return end;last=0
 if N.rewards then N.rewards.tick() end;if N.masteryTick then N.masteryTick() end

end
function N.journalText() local j=stats();return string.format('Resource sites recorded: %d\nGold gained (observed): %d\nGold spent (observed): %d\nHarvesting actions: %d',j.nodeCount or 0,j.goldIn or 0,j.goldOut or 0,j.actions.Harvesting or 0) end
function N.skillJournal(k) local j=stats();return '\nRecorded actions: '..(j.actions[k] or 0)..(k=='Harvesting' and '\nPersonal resource sites: '..(j.nodeCount or 0)..' (level 15 recording)' or '') end
