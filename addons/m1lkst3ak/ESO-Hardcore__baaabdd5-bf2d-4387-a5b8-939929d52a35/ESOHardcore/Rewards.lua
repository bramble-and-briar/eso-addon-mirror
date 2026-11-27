-- Bounded, read-only milestone rewards. No new controls, no global scans.
local N=ESOHardcore;local s=N.safe
local R={};N.rewards=R
local marks={5,15,30,50,75,99};R.marks=marks
local function c() return N.hardcore.saved end
local function active() local a=c();return a and a.active and not a.fallen end
local function store(k)
 local a=c();a.rewardJournal=a.rewardJournal or {};local r=a.rewardJournal[k];if not r then r={count=0,days={},zones={},recent={},total=0};a.rewardJournal[k]=r end;return r
end
local function stamp() return s(GetTimeStamp) or 0 end
local function zone() return tostring(s(GetUnitZone,'player') or 'Unknown region') end
local function put(t,key,n,cap)
 if t[key]==nil then local size=0;for _ in pairs(t) do size=size+1 end;if size>=cap then return end end;t[key]=(t[key] or 0)+n
end
local function fmt(n) return tostring(math.floor(tonumber(n) or 0)) end
local function best(t) local k,v=nil,0;for a,b in pairs(t or {}) do if b>v then k,v=a,b end end;return k,v end
function R.record(k,base)
 if not active() then return end
 local r=store(k);local t=stamp();local day=math.floor(t/86400);local z=zone();r.count=r.count+1;r.total=r.total+(tonumber(base) or 0);r.last=t;r.first=r.first or t;r.lastZone=z
 if r.day~=day then r.day=day;r.today=0 end;r.today=(r.today or 0)+1;r.bestDay=math.max(r.bestDay or 0,r.today)
 put(r.zones,z,1,64);r.days[day]=(r.days[day] or 0)+1;for d in pairs(r.days) do if d<day-6 then r.days[d]=nil end end
 if #r.recent>=5 then table.remove(r.recent,1) end;r.recent[#r.recent+1]=z
end
local nouns={Harvesting='harvests',Survivalist='survival intervals',Perception='encounters',Endurance='combat endurance awards',['Combat Mastery']='combat actions'}
local function count(k,r) return fmt(r.count)..' '..nouns[k]..' observed since update' end
local function recent(k,r) return r.lastZone and ('Last location: '..r.lastZone) or 'No recorded activity yet' end
local function day(k,r) return 'Today: '..fmt(r.day==math.floor(stamp()/86400) and r.today or 0)..' | Personal best day: '..fmt(r.bestDay) end
local function regions(k,r) local z,n=best(r.zones);return z and ('Most active recorded region: '..z..' ('..n..')') or 'No regional activity yet' end
local function week(k,r) local n=0;local today=math.floor(stamp()/86400);for d,v in pairs(r.days) do if d>=today-6 then n=n+v end end;return 'Last 7 UTC days: '..n..' '..nouns[k] end
local function mastery(k,r) return 'Mastered | Lifetime recorded base XP: '..fmt(r.total)..' | '..count(k,r) end
function R.observe(k,key,n)
 if not active() then return end;local r=store(k);r.observed=r.observed or {};r.observed[key]=(r.observed[key] or 0)+n
end
local function observation(k,r,key) return fmt(r.observed and r.observed[key]) end
local function power(flag)
 if not flag then return nil end;local v,m=s(GetUnitPower,'player',flag);if type(v)=='number' and type(m)=='number' and m>0 then return math.floor(v/m*100) end
end
local function pct(v) return v and (v..'%') or 'Unavailable' end
local function nutrition() return 'Hunger '..fmt(c().food)..'% | Thirst '..fmt(c().water)..'%' end
local function gold() local p,b;if N.hcGold then p,b=N.hcGold() end;return 'HC gold carried '..fmt(p)..' | bank '..fmt(b) end
local function stock() local n,q=0,0;for _,v in pairs(c().ownership or {}) do n=n+1;q=q+v end;return 'Personal HC ledger: '..n..' item types | '..q..' units' end
local function bankstock() local n,q=0,0;local db=N.economy and N.economy.db;for _,v in pairs(db and db.bank or {}) do n=n+1;q=q+v end;return 'HC bank: '..n..' item types | '..q..' units' end
local function sites() return 'Personal resource sites: '..fmt(c().journal and c().journal.nodeCount) end
local function route() local j=c().journal;local top;for _,v in pairs(j and j.nodes or {}) do if not top or v.visits>top.visits then top=v end end;return top and ('Most visited site: '..top.name..' ('..top.visits..' visits)') or 'No sites recorded' end
local function hours() return 'Active survival: '..fmt((c().survivalSeconds or 0)/60)..' min' end
local function health() return 'Health: '..pct(power(COMBAT_MECHANIC_FLAGS_HEALTH or POWERTYPE_HEALTH)) end
local function stamina() return 'Stamina: '..pct(power(COMBAT_MECHANIC_FLAGS_STAMINA or POWERTYPE_STAMINA)) end
local function magicka() return 'Magicka: '..pct(power(COMBAT_MECHANIC_FLAGS_MAGICKA or POWERTYPE_MAGICKA)) end
local function integrity() return 'Recent integrity entries retained: '..#(c().integrityNotes or {}) end
local function difficulty() return 'Current difficulty: '..N.hardcore.difficultyName() end
local function backpack() local a=s(GetNumBagUsedSlots,BAG_BACKPACK);local b=s(GetBagSize,BAG_BACKPACK);return type(a)=='number' and type(b)=='number' and ('Free backpack slots: '..math.max(0,b-a)) or 'Backpack capacity unavailable' end
local function condition() local low=0;local checked=0;if BAG_WORN then for i=0,(s(GetBagSize,BAG_WORN) or 0)-1 do local v=s(GetItemCondition,BAG_WORN,i);if type(v)=='number' and v>0 then checked=checked+1;if v<20 then low=low+1 end end end end;return checked>0 and ('Low-condition equipped items: '..low) or 'Condition data unavailable' end
local function recentList(k,r) return #r.recent>0 and ('Recent regions: '..table.concat(r.recent,', ')) or 'No recent activity' end
local function rate(k,r) local sec=c().survivalSeconds or 0;return sec>0 and string.format('Recorded actions / run hour: %.1f',r.count*3600/sec) or 'No active time recorded' end
local function reward(label,fn) return {label,fn} end
local function common(k) return {reward('Activity journal',count),reward('Last activity region',recent),reward('Daily record',day),reward('Regional activity record',regions),reward('Weekly activity report',week),reward('Mastery report',mastery)} end
R.defs={}
local roadmap={
 ["Harvesting"]={"Lifetime harvesting statistics","Automatic resource node location recording","Previously discovered node map markers","Nearby known resource indicators","Personalized farming route suggestions","Farming efficiency and regional profitability analysis"},
 ["Survivalist"]={"Basic survival journal","Equipment condition warnings","Critical health awareness","General combat danger indicators","Advanced threat awareness and potion warnings","Comprehensive survival intelligence and emergency alerts"},
 ["Perception"]={"Combat engagement history","Combat initiation notification","General proximity or danger warning","Detected off-screen threat indicators","Rear-threat awareness","Multiple threat prioritization"},
 ["Endurance"]={"Expedition duration tracking","Fatigue awareness","Low stamina warnings","Resource depletion trend indicators","Sustained combat efficiency analysis","Advanced exhaustion and resource management advisor"},
 ["Combat Mastery"]={"Combat journal","Block and dodge statistics","Interrupt performance analysis","Recognized enemy attack reference","Defensive performance feedback","Comprehensive post-combat analysis"},
}
for k,labels in pairs(roadmap) do R.defs[k]={};for i,label in ipairs(labels) do R.defs[k][i]={label,nil} end end
local function set(k,i,fn) R.defs[k][i][2]=fn end
for k in pairs(roadmap) do set(k,1,count) end
set('Harvesting',2,sites)
set('Survivalist',2,condition);set('Survivalist',3,health)
set('Perception',2,function() return 'Combat initiation notification enabled' end)
set('Endurance',1,hours);set('Endurance',3,stamina)
set('Combat Mastery',2,function(k,r) return 'Blocks '..observation(k,r,'blocks')..' | Dodges '..observation(k,r,'dodges') end)
function R.install(k,i,fn) set(k,i,fn) end
function R.label(k,i) return R.defs[k][i][1] end
function R.line(k,i,level)
 local v=R.defs[k][i];if not v[2] then return 'Planned - not implemented' end
 if level<marks[i] then return 'Locked' end
 local ok,result=pcall(v[2],k,store(k));return ok and tostring(result) or 'Data unavailable'
end
function R.countUnlocked(k,l) local n=0;for _,m in ipairs(marks) do if l>=m then n=n+1 end end;return n end
function R.onLevel(k,old,new) local a=R.countUnlocked(k,old);local b=R.countUnlocked(k,new);if b>a and d then for i=a+1,b do if R.defs[k][i][2] then d('Hardcore: '..k..' reward unlocked: '..R.label(k,i)) end end end end

function R.tick() end
