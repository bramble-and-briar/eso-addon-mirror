------------------------------------------------------------
-- RYTIC COMBAT & RAID TOOLS - GROUP / RAID ASSIGNMENTS v3.0.0
-- Original Rytic implementation. Mechanic labels/data are based in part on
-- DDPositions by @Konten/@Zaan's (public-domain release supplied by user).
-- Live roster + shared-DPS ordering come from Rytic Group Frames.
------------------------------------------------------------
RyticTank=RyticTank or {}
local RyticTank=RyticTank
RyticTank.Positions=RyticTank.Positions or {}
local P=RyticTank.Positions
local WM,EM=WINDOW_MANAGER,EVENT_MANAGER
local tostring,tonumber,ipairs,pairs=tostring,tonumber,ipairs,pairs
local sort,insert,remove=table.sort,table.insert,table.remove
local floor=math.floor

P.enabled = P.enabled ~= false

local function raidControlsEnabled()
    local R=RyticTank.RaidLead
    if R and R.IsEnabled then return R.IsEnabled() end
    return P.enabled~=false
end

-- Trial mechanic labels. Assignment behavior/UI below is Rytic code.
P.data={
 [636]={order={"2Groups"},mechanics={["2Groups"]={"Upstairs","Upstairs","Upstairs","Upstairs","Downstairs","Downstairs","Downstairs","Downstairs"}}},
 [725]={order={"2Groups","Runner"},mechanics={["2Groups"]={"Exit","Exit","Exit","Exit","Entrance","Entrance","Entrance","Entrance"},Runner={"LEFT","MIDDLE","RIGHT","BACKUP"}}},
 [975]={order={"Portals","2Groups"},mechanics={Portals={"N","S","W","E"},["2Groups"]={"Left","Left","Left","Left","Right","Right","Right","Right"}}},
 [1000]={order={"Positions"},mechanics={Positions={"1","2","3","4","5","6","7","8"}}},
 [1051]={order={"Portals","Orbs"},mechanics={Portals={"P1","P1","P2","P2"},Orbs={"Orbs"}}},
 [1121]={order={"Tombs","Head&Wing","Portals","Positions(HM)","Tombs(HM)"},mechanics={Tombs={"T1","T2","T3"},["Head&Wing"]={"Head","Head","Head","Head","Wing","Wing","Wing","Wing"},Portals={"P.Left","P.Middle","P.Right"},["Positions(HM)"]={"1","2","3","4","5","6","7","8"},["Tombs(HM)"]={"T1A","T1B","T2A","T2B","T3A","T3B"}}},
 [1196]={order={"Yandir","Boat","Line","Stack(HM)"},mechanics={Yandir={"1","2","3","4","5","6","7","8"},Boat={"Boat"},Line={"Line1","Line2","Line3","Line4","Line5"},["Stack(HM)"]={"1","1","2","2","3","3","4","4"}}},
 [1263]={order={"Kite"},mechanics={Kite={"Kite"}}},
 [1344]={order={"Interrupts","Reefs","Bridges","Interrupts(HM)"},mechanics={Interrupts={"Exit.R & Swap","Exit.L & Swap","Entrance.R","Entrance.L"},Reefs={"12-5-8","3-6-9","4-7-10"},Bridges={"B1","B1","B2","B2","B3","B3"},["Interrupts(HM)"]={"Exit.R","Exit.L","Entrance.R","Entrance.L","Exit.R","Exit.L","Entrance.R","Entrance.L"}}},
 [1427]={order={"Portals","2Groups","Ansuul Portal"},mechanics={Portals={"P1","P1","P1","P1","P2","P2","P2","P2"},["2Groups"]={"Left","Left","Left","Left","Right","Right","Right","Right"},["Ansuul Portal"]={"+Portal","+Portal","+Portal"}}},
 [1478]={order={"2Groups","Mirrors"},mechanics={["2Groups"]={"Dark","Dark","Dark","Dark","Light","Light","Light","Light"},Mirrors={"N","S","E","W","NE","SE","SW","NW"}}},
 [1548]={order={"Portal","2Groups"},mechanics={Portal={"+P","+P","+P","+P"},["2Groups"]={"Left","Left","Left","Left","Right","Right","Right","Right"}}},
}
local SPECIAL={
 [1051]={title="+2 / +3",key="CR_PLUS"},
 [1427]={title="PORTAL TEAM",key="VSE_PORTAL"},
}
local function norm(s) return zo_strlower(tostring(s or "")):gsub("%s+","") end
local PAIR_A,PAIR_B="@rytic","@rytic's-wifey"
local function zid() return GetZoneId(GetUnitZoneIndex("player")) end
local function sv()
 RyticTank.saved=RyticTank.saved or {}; RyticTank.saved.positions=RyticTank.saved.positions or {}
 local s=RyticTank.saved.positions; s.saved=s.saved or {}; s.special=s.special or {}; s.lastMechanic=s.lastMechanic or nil
 return s
end
-- Prog-group position snapshots. These are plain SavedVariables-safe tables so a
-- named prog can remember mechanic slots independently of other progs.
local function deepCopy(value)
 if type(value)~="table" then return value end
 local out={}
 for k,v in pairs(value) do out[deepCopy(k)]=deepCopy(v) end
 return out
end

-- Thought-board state: all board edits remain local until PUSH ASSIGNMENTS.
P.editState=P.editState or nil
P.manualTeamOverrides=P.manualTeamOverrides or {}
local liveMembers
local function memberKey(m) return norm((m and m.account and m.account~="") and m.account or (m and (m.char or m.name)) or "") end
local function beginEditState(force)
 if P.editState and not force then return P.editState end
 local z=zid(); local G=RyticTank.GroupFrames; local state={zone=z,teams={},manualTeams=deepCopy(P.manualTeamOverrides),special={},slots={},lastMechanic=sv().lastMechanic,teamNames={"TEAM A","TEAM B"},coreName=(G and G.GetCurrentProgGroup and G.GetCurrentProgGroup()) or "Default"}
 if G and G.GetTeamName then state.teamNames={G.GetTeamName(1),G.GetTeamName(2)} end
 for _,m in ipairs(liveMembers and liveMembers() or {}) do
  local t=(G and G.GetTeam and (G.GetTeam(m.account) or G.GetTeam(m.char))) or m.team or 1
  state.teams[memberKey(m)]=(t==2) and 2 or 1
 end
 state.special=deepCopy((sv().special or {})[z] or {})
 state.slots=deepCopy((sv().saved or {})[z] or {})
 P.editState=state
 return state
end
local function editState() return P.editState or beginEditState(false) end
local function discardEditState() P.editState=nil; P.dragMember=nil end
function P.ExportProgPositions()
 local s=sv()
 return {saved=deepCopy(s.saved or {}),special=deepCopy(s.special or {}),lastMechanic=s.lastMechanic}
end
function P.ImportProgPositions(snapshot)
 if type(snapshot)~="table" then return false end
 local s=sv()
 s.saved=deepCopy(snapshot.saved or {})
 s.special=deepCopy(snapshot.special or {})
 s.lastMechanic=snapshot.lastMechanic
 if P.Refresh then P.Refresh() end
 return true
end

local function roleKey(tag)
 local role=GetGroupMemberSelectedRole and GetGroupMemberSelectedRole(tag) or nil
 if LFG_ROLE_TANK and role==LFG_ROLE_TANK then return "tank" end
 if LFG_ROLE_HEAL and role==LFG_ROLE_HEAL then return "healer" end
 if LFG_ROLE_DPS and role==LFG_ROLE_DPS then return "dps" end
 return "unknown"
end
local ROLE_ORDER={tank=1,healer=2,dps=3,unknown=4}
local ROLE_LABEL={tank="T",healer="H",dps="D",unknown="?"}
liveMembers=function()
 local out={}; local G=RyticTank.GroupFrames
 for i=1,(GetGroupSize() or 0) do
  local tag=GetGroupUnitTagByIndex(i)
  if tag and DoesUnitExist(tag) then
   local account=GetUnitDisplayName(tag) or ""; local char=GetUnitName(tag) or account; local display=account~="" and account or char
   local role=roleKey(tag)
   local dps=0; if G and G.GetSharedDps then dps=math.max(tonumber(G.GetSharedDps(char)) or 0,tonumber(G.GetSharedDps(account)) or 0) end
   local team=nil; if G and G.GetTeam then team=G.GetTeam(account) or G.GetTeam(char) end
   out[#out+1]={tag=tag,name=display,char=char,account=account,dps=dps,team=team,role=role}
  end
 end
 sort(out,function(a,b)
  local ra,rb=ROLE_ORDER[a.role] or 4,ROLE_ORDER[b.role] or 4
  if ra~=rb then return ra<rb end
  if a.role=="dps" and a.dps~=b.dps then return a.dps>b.dps end
  return norm(a.name)<norm(b.name)
 end)
 return out
end
local function liveDDs()
 local out={}
 for _,m in ipairs(liveMembers()) do if m.role=="dps" then out[#out+1]=m end end
 return out
end

local function slotsFor(z,mech)
 local zd=P.data[z]; if not zd or not zd.mechanics[mech] then return nil end
 local s=sv(); s.saved[z]=s.saved[z] or {}; local slots=s.saved[z][mech] or {}
 for i,label in ipairs(zd.mechanics[mech]) do slots[i]=slots[i] or {name="@Missing",position=label,override=false}; slots[i].position=label; if slots[i].override==nil then slots[i].override=false end end
 for i=#slots,1,-1 do
  if i>#zd.mechanics[mech] and not slots[i].dynamic then table.remove(slots,i) end
 end
 s.saved[z][mech]=slots; return slots
end
local function uniqueLabels(labels) local r,seen={},{}; for _,v in ipairs(labels) do if not seen[v] then seen[v]=true; r[#r+1]=v end end; return r end

-- When a mechanic is a true 4-DD / 4-DD split, mirror that split into the
-- staged Team A / Team B roster. This gives each visible Group Frame column
-- one tank + one healer + four DD in a standard 12-player trial without
-- requiring the raid lead to drag the same DDs a second time.
local function fourDDSplitSides(z,mech)
 if mech~="2Groups" then return nil end
 local zd=P.data[z]; local labels=zd and zd.mechanics and zd.mechanics[mech]
 if not labels or #labels~=8 then return nil end
 local sides=uniqueLabels(labels)
 if #sides~=2 then return nil end
 local counts={[sides[1]]=0,[sides[2]]=0}
 for _,labelText in ipairs(labels) do
  if counts[labelText]==nil then return nil end
  counts[labelText]=counts[labelText]+1
 end
 if counts[sides[1]]~=4 or counts[sides[2]]~=4 then return nil end
 return sides
end

function P.ImportMechanicSplitToTeams(mech,z,slots)
 z=z or zid(); mech=mech or (P.editState and P.editState.lastMechanic) or sv().lastMechanic
 if not mech then return false end
 local sides=fourDDSplitSides(z,mech)
 if not sides then return false end

 local e=editState()
 slots=slots or ((P.editState and P.editState.zone==z and P.editState.slots) and P.editState.slots[mech]) or slotsFor(z,mech)
 if not slots then return false end

 local members=liveMembers()
 local byIdentity={}
 for _,m in ipairs(members) do
  byIdentity[norm(m.name)]=m
  byIdentity[norm(m.account)]=m
  byIdentity[norm(m.char)]=m
 end

 local fixed,teamCount={}, {0,0}
 local roleCount={tank={0,0},healer={0,0}}
 local function place(m,team)
  local key=memberKey(m)
  if fixed[key] then return end
  e.teams[key]=team; fixed[key]=true; teamCount[team]=teamCount[team]+1
  if roleCount[m.role] then roleCount[m.role][team]=roleCount[m.role][team]+1 end
 end

 local assigned,manualBucket=0,{}
 for _,o in ipairs(slots) do
  if o.name and o.name~="@Missing" then
   local m=byIdentity[norm(o.name)]
   local team=(o.position==sides[1]) and 1 or ((o.position==sides[2]) and 2 or nil)
   if m and team then
    assigned=assigned+1
    if o.override then manualBucket[memberKey(m)]=true end
   end
  end
 end
 -- CLEAR MECH leaves the staged mechanic empty and does not rearrange teams.
 if assigned==0 then return false end

 -- A deliberate Team A/B drag wins over automatic mechanic/team placement.
 for _,m in ipairs(members) do
  local team=e.manualTeams and e.manualTeams[memberKey(m)]
  if team==1 or team==2 then place(m,team) end
 end
 for _,o in ipairs(slots) do
  if o.name and o.name~="@Missing" then
   local m=byIdentity[norm(o.name)]
   local team=(o.position==sides[1]) and 1 or ((o.position==sides[2]) and 2 or nil)
   if m and team then place(m,team) end
  end
 end

 -- When support roles are balanced, keep Rytic and Wifey together unless
 -- either one was deliberately placed into a team or mechanic bucket.
 local a,b=byIdentity[PAIR_A],byIdentity[PAIR_B]
 local pairManual=a and b and ((e.manualTeams and (e.manualTeams[memberKey(a)] or e.manualTeams[memberKey(b)])) or manualBucket[memberKey(a)] or manualBucket[memberKey(b)])
 if a and b and a~=b and pairManual then
  -- Keep the other person's staged team when one partner is moved manually.
  for _,m in ipairs({a,b}) do
   local key=memberKey(m); local team=e.teams[key]
   if not fixed[key] and (team==1 or team==2) then place(m,team) end
  end
 elseif a and b and a~=b and (roleCount[a.role] or roleCount[b.role]) then
  local aTeam=fixed[memberKey(a)] and e.teams[memberKey(a)] or nil
  local bTeam=fixed[memberKey(b)] and e.teams[memberKey(b)] or nil
  if aTeam and not bTeam then place(b,aTeam)
  elseif bTeam and not aTeam then place(a,bTeam)
  elseif not aTeam and not bTeam then
   local function penalty(team)
    local n=0
    if roleCount[a.role] then n=n+roleCount[a.role][team] end
    if roleCount[b.role] then n=n+roleCount[b.role][team] end
    return n*100+teamCount[team]
   end
   local team=(penalty(1)<=penalty(2)) and 1 or 2
   place(a,team); place(b,team)
  end
 end

 local tanks,healers,unknown,extraDD={},{},{},{}
 for _,m in ipairs(members) do
  local key=memberKey(m)
  if not fixed[key] then
   if m.role=="tank" then tanks[#tanks+1]=m
   elseif m.role=="healer" then healers[#healers+1]=m
   elseif m.role=="dps" then extraDD[#extraDD+1]=m
   else unknown[#unknown+1]=m end
  end
 end

 local function placeBalanced(list,role)
  for _,m in ipairs(list) do
   local counts=role and roleCount[role]
   local team
   if counts and counts[1]~=counts[2] then team=(counts[1]<counts[2]) and 1 or 2
   else team=(teamCount[1]<=teamCount[2]) and 1 or 2 end
   place(m,team)
  end
 end

 -- Supports are deliberately placed before any extra/unassigned DDs so the
 -- normal result is T + H + 4 DD on each side. Existing mechanic placements
 -- remain authoritative if a support was manually put into a mechanic bucket.
 placeBalanced(tanks,"tank")
 placeBalanced(healers,"healer")
 placeBalanced(unknown)
 placeBalanced(extraDD)
 return true
end
local function editSlotsFor(z,mech)
 local zd=P.data[z]; if not zd or not zd.mechanics[mech] then return nil end
 local e=editState(); e.slots=e.slots or {}; local slots=e.slots[mech] or {}
 for i,labelText in ipairs(zd.mechanics[mech]) do slots[i]=slots[i] or {name="@Missing",position=labelText,override=false}; slots[i].position=labelText; if slots[i].override==nil then slots[i].override=false end end
 for i=#slots,1,-1 do
  if i>#zd.mechanics[mech] and not slots[i].dynamic then table.remove(slots,i) end
 end
 e.slots[mech]=slots; return slots
end
local function mechanicExcludedSet(mech)
 local e=editState()
 e.excluded=e.excluded or {}
 e.excluded[mech]=e.excluded[mech] or {}
 return e.excluded[mech]
end

local function mechanicLockSet()
 local e=editState()
 e.mechLocks=e.mechLocks or {}
 return e.mechLocks
end

function P.IsMechanicLocked(mech)
 return mechanicLockSet()[mech]==true
end

function P.SetMechanicLocked(mech,on)
 if not mech then return end
 mechanicLockSet()[mech]=on and true or nil
 P.Refresh()
end

function P.Assign(mech,z)
 z=z or zid(); local zd=P.data[z]; if not zd or not zd.mechanics[mech] then return nil end
 local slots=(P.editState and P.editState.zone==z) and editSlotsFor(z,mech) or slotsFor(z,mech)
 local dds=liveDDs(); local ingroup,used={},{}
 local excluded=mechanicExcludedSet(mech)
 local locked=P.IsMechanicLocked(mech)

 -- LOCK means "hold exactly what the raid lead currently sees."  Do not
 -- invalidate or refill slots merely because group membership changed.
 if locked then
  if P.editState then P.editState.lastMechanic=mech else sv().lastMechanic=mech end
  return slots
 end

 -- Manual mechanic overrides are role-agnostic: tank/healer/DD may be placed.
 -- Automatic filling remains DD-only, except players explicitly pulled back
 -- to the live roster are excluded until manually placed again or CLEAR/AUTO resets.
 for _,m in ipairs(liveMembers()) do
  ingroup[norm(m.name)]=m
  if m.account then ingroup[norm(m.account)]=m end
  if m.char then ingroup[norm(m.char)]=m end
 end

 for _,o in ipairs(slots) do
  if o.manualEmpty then
   o.name="@Missing"; o.override=false
  elseif o.override and ingroup[norm(o.name)] then
   used[norm(o.name)]=true
  else
   o.name="@Missing"; o.override=false
  end
 end

 local free={}
 for _,m in ipairs(dds) do
  local nk=norm(m.name)
  local ak=norm(m.account)
  local ck=norm(m.char)
  if not used[nk] and not used[ak] and not used[ck]
     and not excluded[nk] and not excluded[ak] and not excluded[ck] then
   free[#free+1]=m
  end
 end

 if mech=="2Groups" then
  local sides=uniqueLabels(zd.mechanics[mech]); local q={[1]={},[2]={},other={}}
  local counts={0,0}
  for _,o in ipairs(slots) do
   if o.name~="@Missing" then
    local t=(o.position==sides[1]) and 1 or 2
    counts[t]=counts[t]+1
   end
  end
  for _,m in ipairs(free) do
   local staged=P.editState and P.editState.teams and P.editState.teams[memberKey(m)] or nil
   local t=(staged==1 or staged==2) and staged or ((m.team==1 or m.team==2) and m.team or nil)
   if t then q[t][#q[t]+1]=m else q.other[#q.other+1]=m end
  end
  local function take(t)
   if #q[t]>0 then return remove(q[t],1) end
   if #q.other>0 then return remove(q.other,1) end
   local o=t==1 and 2 or 1
   if #q[o]>0 then return remove(q[o],1) end
  end
  local total=counts[1]+counts[2]+#free
  local targets={math.ceil(total/2),floor(total/2)}
  local function fillSide(t,limit)
   for _,o in ipairs(slots) do
    if o.position==sides[t] and o.name=="@Missing" and not o.manualEmpty and counts[t]<limit then
     local m=take(t)
     if m then o.name=m.name; counts[t]=counts[t]+1 end
    end
   end
  end
  -- Fill available DDs evenly for short rosters; manual slots stay fixed.
  fillSide(1,targets[1]); fillSide(2,targets[2])
  fillSide(1,4); fillSide(2,4)
 else
  local n=1
  for _,o in ipairs(slots) do
   if o.name=="@Missing" and not o.manualEmpty and free[n] then
    o.name=free[n].name; n=n+1
   end
  end
 end
 if P.editState then P.editState.lastMechanic=mech else sv().lastMechanic=mech end
 return slots
end

function P.Override(mech,index,name,z)
 z=z or zid(); local slots=P.editState and editSlotsFor(z,mech) or slotsFor(z,mech); if not slots or not slots[index] then return false end
 name=tostring(name or "@Missing")
 local ex=mechanicExcludedSet(mech); ex[norm(name)]=nil
 for _,m in ipairs(liveMembers()) do
  if norm(m.name)==norm(name) or norm(m.account)==norm(name) or norm(m.char)==norm(name) then
   ex[norm(m.name)]=nil; ex[norm(m.account)]=nil; ex[norm(m.char)]=nil
  end
 end
 for i,o in ipairs(slots) do if i~=index and norm(o.name)==norm(name) then o.name="@Missing"; o.override=false end end
 slots[index].name=name; slots[index].override=true; slots[index].manualEmpty=nil; if P.editState then P.editState.lastMechanic=mech else sv().lastMechanic=mech end; P.ImportMechanicSplitToTeams(mech,z,slots); P.Refresh(); return true
end
-- Manual bucket assignment: role-agnostic and expandable. Auto-fill remains DD-only.
function P.OverrideBucket(mech,position,name,z)
 z=z or zid(); local slots=P.editState and editSlotsFor(z,mech) or slotsFor(z,mech); if not slots then return false end
 name=tostring(name or "@Missing")
 local ex=mechanicExcludedSet(mech); ex[norm(name)]=nil
 for _,m in ipairs(liveMembers()) do
  if norm(m.name)==norm(name) or norm(m.account)==norm(name) or norm(m.char)==norm(name) then
   ex[norm(m.name)]=nil; ex[norm(m.account)]=nil; ex[norm(m.char)]=nil
  end
 end
 -- A player has one assignment within a mechanic; dragging moves them between buckets.
 for _,o in ipairs(slots) do
  if norm(o.name)==norm(name) then o.name="@Missing"; o.override=false end
 end
 -- Prefer an existing empty slot for this bucket before expanding it.
 for _,o in ipairs(slots) do
  if o.position==position and o.name=="@Missing" then
   o.name=name; o.override=true; o.manualEmpty=nil
   if P.editState then P.editState.lastMechanic=mech else sv().lastMechanic=mech end
   P.ImportMechanicSplitToTeams(mech,z,slots)
   P.Refresh(); return true
  end
 end
 -- No empty predefined slot remains: add a staged dynamic slot to this bucket.
 slots[#slots+1]={name=name,position=position,override=true,dynamic=true}
 if P.editState then P.editState.lastMechanic=mech else sv().lastMechanic=mech end
 P.ImportMechanicSplitToTeams(mech,z,slots)
 P.Refresh(); return true
end

-- Dragging a player back to the live roster intentionally leaves this mechanic slot empty.
-- The change stays on the thought board until PUSH ASSIGNMENTS.
function P.UnassignFromMechanic(mech,name,z)
 z=z or zid(); local slots=P.editState and editSlotsFor(z,mech) or slotsFor(z,mech); if not slots then return false end
 local key=norm(name); local changed=false
 local ex=mechanicExcludedSet(mech)
 ex[key]=true
 for _,m in ipairs(liveMembers()) do
  if norm(m.name)==key or norm(m.account)==key or norm(m.char)==key then
   ex[norm(m.name)]=true; ex[norm(m.account)]=true; ex[norm(m.char)]=true
  end
 end
 for i=#slots,1,-1 do
  local o=slots[i]
  if norm(o.name)==key then
   if o.dynamic then table.remove(slots,i) else o.name="@Missing"; o.override=false; o.manualEmpty=true end
   changed=true
  end
 end
 if changed then
  if P.editState then P.editState.lastMechanic=mech else sv().lastMechanic=mech end
  P.ImportMechanicSplitToTeams(mech,z,slots)
  P.Refresh()
 end
 return changed
end

function P.ClearCurrentMechanic(mech,z)
 z=z or zid()
 local e=editState()
 mech=mech or e.lastMechanic
 if not mech then return false end
 local slots=editSlotsFor(z,mech)
 if not slots then return false end
 e.excluded=e.excluded or {}; e.excluded[mech]={}
 for _,m in ipairs(liveDDs()) do
  e.excluded[mech][norm(m.name)]=true
  e.excluded[mech][norm(m.account)]=true
  e.excluded[mech][norm(m.char)]=true
 end
 for i=#slots,1,-1 do
  local o=slots[i]
  if o.dynamic then
   table.remove(slots,i)
  else
   o.name="@Missing"; o.override=false; o.manualEmpty=true
  end
 end
 e.lastMechanic=mech
 P.Refresh()
 return true
end

function P.ClearSlot(mech,index,z) local s=P.editState and editSlotsFor(z or zid(),mech) or slotsFor(z or zid(),mech); if not s or not s[index] then return end; if s[index].dynamic then table.remove(s,index) else s[index].name="@Missing"; s[index].override=false end; P.Assign(mech,z); P.Refresh() end
function P.GetZoneData(z) return P.data[z or zid()] end
function P.GetLastMechanic() return (P.editState and P.editState.lastMechanic) or sv().lastMechanic end
local function assignmentText(mech,z)
 local slots=P.Assign(mech,z); if not slots then return nil end
 local parts={}; for _,o in ipairs(slots) do parts[#parts+1]=tostring(o.position)..": "..tostring(o.name) end
 return "Rytic "..tostring(mech).." | "..table.concat(parts," | ")
end
local function teamSummary(team,e)
 e=e or editState()
 local name=(e.teamNames and e.teamNames[team]) or (team==1 and "TEAM A" or "TEAM B")
 local names={}
 for _,m in ipairs(liveMembers()) do
  local t=(e.teams and e.teams[memberKey(m)]) or 1
  if t==team then names[#names+1]=m.name end
 end
 return name..": "..table.concat(names,", ")
end
function P.BuildTeamsCallout()
 local e=editState()
 return "Rytic Teams | "..teamSummary(1,e).." | "..teamSummary(2,e)
end
function P.BuildRaidCallout(mech,z)
 z=z or zid(); mech=mech or (P.editState and P.editState.lastMechanic) or sv().lastMechanic
 return mech and assignmentText(mech,z) or nil
end
function P.PushTeams()
 if GetGroupSize()==0 then d("|cFFAA00Rytic: teams require a group.|r"); return false end
 local e=editState(); local G=RyticTank.GroupFrames
 if not G or not G.ApplyBoardState then d("|cFF5555Rytic: staged team commit is unavailable.|r"); return false end
 local rows={}
 for _,m in ipairs(liveMembers()) do rows[#rows+1]={name=(m.account and m.account~="") and m.account or (m.char or m.name),team=e.teams[memberKey(m)] or 1,locked=true} end
 local ok,err=G.ApplyBoardState(rows,e.teamNames)
 if not ok then if err then d("|cFFAA00Rytic: "..tostring(err).."|r") end; return false end
 P.manualTeamOverrides=deepCopy(e.manualTeams or {})
 if G.PushOut then G.PushOut() end
 if BeginGroupElection then pcall(BeginGroupElection,1,"RYTIC TEAM UPDATE - CHECK CHAT") end
 if RyticTank.GroupSync and RyticTank.GroupSync.SendUpdateNotice then
  RyticTank.GroupSync.SendUpdateNotice("TEAM UPDATE - CHECK CHAT")
 end
 local msg=P.BuildTeamsCallout()
 if StartChatInput then StartChatInput(msg,CHAT_CHANNEL_PARTY) end
 return true
end
function P.Push(mech,z)
 z=z or zid(); local e=editState(); mech=mech or e.lastMechanic or sv().lastMechanic
 if GetGroupSize()==0 then d("|cFFAA00Rytic: assignments require a group.|r"); return false end
 local G=RyticTank.GroupFrames
 if not G or not G.ApplyBoardState then d("|cFF5555Rytic: staged board commit is unavailable.|r"); return false end
 -- Resolve the selected 4/4 mechanic at commit time, including menu pushes.
 -- The import respects deliberate Team A/B drags recorded on this board.
 if mech=="2Groups" then
  local slots=P.Assign(mech,z)
  if slots then P.ImportMechanicSplitToTeams(mech,z,slots) end
 end
 local rows={}
 for _,m in ipairs(liveMembers()) do rows[#rows+1]={name=(m.account and m.account~="") and m.account or (m.char or m.name),team=e.teams[memberKey(m)] or 1,locked=true} end
 local ok,err=G.ApplyBoardState(rows,e.teamNames)
 if not ok then if err then d("|cFFAA00Rytic: "..tostring(err).."|r") end; return false end
 P.manualTeamOverrides=deepCopy(e.manualTeams or {})
 local s=sv(); s.special[z]=deepCopy(e.special or {}); s.saved[z]=deepCopy(e.slots or {}); s.lastMechanic=mech
 if G.SetCurrentProgGroupName and e.coreName then G.SetCurrentProgGroupName(e.coreName) end
 if G.PushOut then G.PushOut() end
 if BeginGroupElection then pcall(BeginGroupElection,1,"RYTIC ASSIGNMENTS UPDATED - CHECK CHAT") end
 if RyticTank.GroupSync and RyticTank.GroupSync.SendUpdateNotice then
  RyticTank.GroupSync.SendUpdateNotice("MECHANIC UPDATE - CHECK CHAT")
 end
 P.editState=nil
 local msg=P.BuildRaidCallout(mech,z)
 if msg and StartChatInput then StartChatInput(msg,CHAT_CHANNEL_PARTY) end
 P.Refresh()
 return true
end

function P.AutoAndPush(mech,z)
 local e=editState(); e.lastMechanic=mech
 local slots=P.Assign(mech,z)
 P.ImportMechanicSplitToTeams(mech,z,slots)
 return P.Push(mech,z)
end

-- UI helpers
local teamDrop
local finishBoardDrag

local function clearBoardDrag()
 P.dragMember=nil
 P.dragSourceMech=nil
 P.dragSourceName=nil
 if P.dragGhost then P.dragGhost:SetHidden(true) end
 if P.dragReleaseOverlay then P.dragReleaseOverlay:SetHidden(true) end
end

local function ensureDragGhost()
 if P.dragGhost or not P.window then return end
 local g=WM:CreateControl(nil,P.window,CT_LABEL)
 g:SetFont("ZoFontGameBold")
 g:SetDimensions(230,28)
 g:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
 g:SetVerticalAlignment(TEXT_ALIGN_CENTER)
 g:SetColor(.55,.85,1,1)
 g:SetDrawTier(DT_HIGH)
 g:SetDrawLayer(DL_OVERLAY)
 g:SetMouseEnabled(false)
 g:SetHidden(true)
 P.dragGhost=g
end

local function ensureDragReleaseOverlay()
 if P.dragReleaseOverlay or not P.window then return end
 local o=WM:CreateControl(nil,P.window,CT_CONTROL)
 o:SetAnchorFill(P.window)
 o:SetDrawTier(DT_HIGH)
 o:SetDrawLayer(DL_OVERLAY)
 o:SetMouseEnabled(true)
 o:SetHidden(true)
 o:SetHandler("OnMouseUp",function(_,button)
  if button==MOUSE_BUTTON_INDEX_LEFT and P.dragMember then finishBoardDrag() end
 end)
 P.dragReleaseOverlay=o
end

local function startBoardDrag(member,sourceMech,sourceName)
 if not member then return end
 P.dragMember=member
 P.dragSourceMech=sourceMech
 P.dragSourceName=sourceName
 ensureDragGhost()
 ensureDragReleaseOverlay()
 if P.dragReleaseOverlay then P.dragReleaseOverlay:SetHidden(false) end
 if P.dragGhost then
  P.dragGhost:SetText("\226\137\161  "..tostring(member.name or member.account or "PLAYER"))
  P.dragGhost:SetHidden(false)
 end
end

local function pointInside(control,mx,my)
 if not control or control:IsHidden() then return false end
 local l,r,t,b=control:GetLeft(),control:GetRight(),control:GetTop(),control:GetBottom()
 if not l or not r or not t or not b then return false end
 return mx>=l and mx<=r and my>=t and my<=b
end

local function resolveBoardDrop()
 if not P.dragMember then return false end
 local mx,my=GetUIMousePosition()
 -- Resolve from absolute UI coordinates.  This deliberately does not depend on
 -- MouseIsOver(), OnMouseEnter, or the destination receiving the mouse release.
 -- The LIVE GROUP ROSTER is the unassigned drop target for mechanic-origin drags.
 if P.dragSourceMech and pointInside(P.rosterBox,mx,my) then
  local m=P.dragMember; local mech=P.dragSourceMech
  local sourceName=P.dragSourceName or (m and (m.name or m.account or m.char))
  local removed=sourceName and P.UnassignFromMechanic(mech,sourceName,zid())
  clearBoardDrag()
  return removed and true or false
 end
 if pointInside(P.teamA,mx,my) then teamDrop(1); return true end
 if pointInside(P.teamB,mx,my) then teamDrop(2); return true end
 if P.specialBox and pointInside(P.specialBox,mx,my) then teamDrop(3); return true end
 for _,r in ipairs(P.slotControls or {}) do
  if r.dropMech and pointInside(r,mx,my) then
   local m=P.dragMember
   if r.dropPosition then P.OverrideBucket(r.dropMech,r.dropPosition,m.name,zid()) else P.Override(r.dropMech,r.dropIndex,m.name,zid()) end
   clearBoardDrag()
   return true
  end
 end
 return false
end

finishBoardDrag=function()
 if not P.dragMember then return end
 local who=tostring(P.dragMember.name or P.dragMember.account or "PLAYER")
 local dropped=resolveBoardDrop()
 if dropped then
 else
  d("|cFFAA55RCRT DROP CANCELLED:|r "..who)
  clearBoardDrag()
 end
end

-- Drag release is caught by a temporary board-sized overlay created below.
-- It is shown only after the dedicated handle receives MouseDown, so it cannot
-- interfere with normal board clicks or the game camera outside an active drag.

local function backdrop(parent,r,g,b,a)
 local x=WM:CreateControl(nil,parent,CT_BACKDROP); x:SetAnchorFill(); x:SetCenterColor(r,g,b,a); x:SetEdgeColor(.22,.48,.7,1); x:SetDrawLayer(DL_BACKGROUND); return x
end
local function btn(parent,text,w,h,fn)
 local b=WM:CreateControl(nil,parent,CT_BUTTON); b:SetDimensions(w,h or 28); b:SetFont("ZoFontGameBold"); b:SetText(text); b:SetNormalFontColor(1,1,1,1); b:SetMouseOverFontColor(.55,.85,1,1); b:SetHandler("OnClicked",fn); backdrop(b,.035,.22,.38,.95); return b
end
local function label(parent,text,font)
 local l=WM:CreateControl(nil,parent,CT_LABEL); l:SetFont(font or "ZoFontGame"); l:SetText(text or ""); l:SetVerticalAlignment(TEXT_ALIGN_CENTER); return l
end
local function clearControls(t) for _,c in ipairs(t or {}) do if c then c:SetHidden(true) end end; ZO_ClearNumericallyIndexedTable(t) end
local function specialSet(z) local s=sv(); s.special[z]=s.special[z] or {}; return s.special[z] end
local function specialHas(name,z) return specialSet(z)[norm(name)]==true end
local function setSpecial(name,on,z) specialSet(z)[norm(name)]=on and true or nil end

function P.SelectMechanic(mech)
 local e=editState(); e.lastMechanic=mech
 local slots=P.Assign(mech)
 P.ImportMechanicSplitToTeams(mech,zid(),slots)
 P.Refresh()
end
function P.RefreshMechanics()
 if not P.window then return end; clearControls(P.mechControls); P.mechControls={}
 local z=zid(); local zd=P.data[z]; local y=0
 if not zd then
  local l=label(P.mechBox,"No assignment data\nfor this zone.","ZoFontGame")
  l:SetAnchor(TOPLEFT,P.mechBox,TOPLEFT,8,38)
  l:SetDimensions(164,54)
  l:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  l:SetVerticalAlignment(TEXT_ALIGN_TOP)
  P.mechControls[#P.mechControls+1]=l
  return
 end
 for _,mech in ipairs(zd.order or {}) do
  local b=btn(P.mechBox,mech,160,26,function() P.SelectMechanic(mech) end); b:SetAnchor(TOPLEFT,P.mechBox,TOPLEFT,8,38+y); P.mechControls[#P.mechControls+1]=b; y=y+30
 end
end
local function addDragHandle(row,member,rightOffset)
 local h=WM:CreateControl(nil,row,CT_BUTTON)
 h:SetDimensions(24,21)
 h:SetAnchor(RIGHT,row,RIGHT,rightOffset or -3,0)
 h:SetFont("ZoFontGameBold")
 h:SetText("=")
 h:SetNormalFontColor(.55,.85,1,1)
 h:SetMouseOverFontColor(1,1,1,1)
 h:SetMouseEnabled(true)
 h:SetHandler("OnMouseDown",function(_,button)
  if button==MOUSE_BUTTON_INDEX_LEFT then startBoardDrag(member) end
 end)
 return h
end

function P.RefreshRoster()
 if not P.window then return end; clearControls(P.rosterControls); P.rosterControls={}; local y=34
 for _,m in ipairs(liveMembers()) do
  local r=WM:CreateControl(nil,P.rosterBox,CT_BACKDROP); r:SetDimensions(238,25); r:SetAnchor(TOPLEFT,P.rosterBox,TOPLEFT,6,y); r:SetCenterColor(.05,.06,.08,.98); r:SetEdgeColor(.18,.22,.28,1); r:SetMouseEnabled(true); r.member=m
  local n=label(r,m.name,"ZoFontGameSmall"); n:SetAnchor(LEFT,r,LEFT,5,0); n:SetDimensions(175,23)
  if m.role=="dps" then local d=label(r,string.format("%.1fk",(m.dps or 0)/1000),"ZoFontGameSmall"); d:SetAnchor(RIGHT,r,RIGHT,-30,0); d:SetDimensions(55,23); d:SetHorizontalAlignment(TEXT_ALIGN_RIGHT) end
  addDragHandle(r,m,-3)
  P.rosterControls[#P.rosterControls+1]=r; y=y+27
 end
end

function P.RefreshSlots()
 if not P.window then return end; clearControls(P.slotControls); P.slotControls={}
 local mech=(P.editState and P.editState.lastMechanic) or sv().lastMechanic; local z=zid(); local zd=P.data[z]
 if not mech or not zd or not zd.mechanics[mech] then local l=label(P.slotBox,"Choose a mechanic on the left.","ZoFontGame"); l:SetAnchor(TOPLEFT,P.slotBox,TOPLEFT,10,42); P.slotControls[#P.slotControls+1]=l; return end
 local slots=P.Assign(mech,z) or {}; P.slotTitle:SetText(mech.." ASSIGNMENTS")
 local positions=uniqueLabels(zd.mechanics[mech]); local grouped={}
 for _,posName in ipairs(positions) do grouped[posName]={} end
 for i,o in ipairs(slots) do
  if o.name~="@Missing" then
   grouped[o.position]=grouped[o.position] or {}
   grouped[o.position][#grouped[o.position]+1]={slotIndex=i,name=o.name,override=o.override}
  end
 end
 local y={38,38}
 for n,posName in ipairs(positions) do
  local col=(n-1)%2; local names=grouped[posName] or {}; local h=42+math.max(0,#names-1)*20
  local r=WM:CreateControl(nil,P.slotBox,CT_BACKDROP); r:SetDimensions(250,h); r:SetAnchor(TOPLEFT,P.slotBox,TOPLEFT,8+col*258,y[col+1]); y[col+1]=y[col+1]+h+5
  r:SetCenterColor(.04,.055,.075,.98); r:SetEdgeColor(.25,.5,.75,1); r:SetMouseEnabled(true)
  local pos=label(r,posName,"ZoFontGameBold"); pos:SetAnchor(TOPLEFT,r,TOPLEFT,7,3); pos:SetDimensions(230,18); pos:SetColor(.55,.82,1,1)
  if #names==0 then
   local who=label(r,"@Missing","ZoFontGame"); who:SetAnchor(BOTTOMLEFT,r,BOTTOMLEFT,7,-3); who:SetDimensions(230,20)
  else
   for j,a in ipairs(names) do
    local who=label(r,a.name,"ZoFontGame"); who:SetAnchor(TOPLEFT,r,TOPLEFT,7,20+(j-1)*20); who:SetDimensions(190,20)
    local dragMember=nil
    for _,lm in ipairs(liveMembers()) do if norm(lm.name)==norm(a.name) or norm(lm.account)==norm(a.name) or norm(lm.char)==norm(a.name) then dragMember=lm; break end end
    if not dragMember then dragMember={name=a.name,account=a.name,char=a.name} end
    local dh=addDragHandle(r,dragMember,-3)
    dh:ClearAnchors(); dh:SetAnchor(TOPRIGHT,r,TOPRIGHT,-3,19+(j-1)*20)
    dh:SetHandler("OnMouseDown",function(_,button) if button==MOUSE_BUTTON_INDEX_LEFT then startBoardDrag(dragMember,mech,a.name) end end)
   end
  end
  r.dropMech=mech; r.dropPosition=posName
  r:SetHandler("OnMouseUp",function(_,b)
   if b==MOUSE_BUTTON_INDEX_LEFT and P.dragMember then P.OverrideBucket(mech,posName,P.dragMember.name,z); P.dragMember=nil end
  end)
  r:SetHandler("OnMouseEnter",function() InitializeTooltip(InformationTooltip,r,RIGHT,-6,0); SetTooltipText(InformationTooltip,"Drag another group member here to add them to this mechanic bucket.") end)
  r:SetHandler("OnMouseExit",function() ClearTooltip(InformationTooltip) end)
  P.slotControls[#P.slotControls+1]=r
 end
end
function P.RefreshTeams()
 if not P.window then return end; clearControls(P.teamControls); P.teamControls={}; local z=zid(); local sp=SPECIAL[z]; P.specialBox:SetHidden(not sp); if sp then P.specialTitle:SetText(sp.title) end
 local groups={[1]={},[2]={},[3]={}}; local G=RyticTank.GroupFrames
 local e=editState()
 if P.teamATitle then P.teamATitle:SetText((e.teamNames and e.teamNames[1]) or "TEAM A") end
 if P.teamBTitle then P.teamBTitle:SetText((e.teamNames and e.teamNames[2]) or "TEAM B") end
 for _,m in ipairs(liveMembers()) do
  local t; local k=memberKey(m); if sp and e.special and e.special[norm(m.name)] then t=3 else t=(e.teams and e.teams[k]) or 1; t=t==2 and 2 or 1 end
  groups[t][#groups[t]+1]=m
 end
 local boxes={P.teamA,P.teamB,P.specialBox}
 for t=1,(sp and 3 or 2) do
  for i,m in ipairs(groups[t]) do
   local r=WM:CreateControl(nil,boxes[t],CT_BACKDROP); r:SetDimensions(t==3 and 176 or 246,23); r:SetAnchor(TOPLEFT,boxes[t],TOPLEFT,5,30+(i-1)*24); r:SetCenterColor(.05,.06,.08,.98); r:SetEdgeColor(.18,.22,.28,1); r:SetMouseEnabled(true); r.member=m
   local l=label(r,m.name,"ZoFontGameSmall"); l:SetAnchor(LEFT,r,LEFT,4,0); l:SetDimensions((t==3 and 142 or 212),23); l:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
   addDragHandle(r,m,-3)
   P.teamControls[#P.teamControls+1]=r
  end
 end
end

teamDrop=function(t)
 if not P.dragMember then return end
 local m=P.dragMember; local z=zid(); local e=editState(); local k=memberKey(m)
 if t==3 and SPECIAL[z] then
  e.special[norm(m.name)]=true
 else
  e.special[norm(m.name)]=nil
  e.teams[k]=(t==2) and 2 or 1
  e.manualTeams=e.manualTeams or {}; e.manualTeams[k]=e.teams[k]
 end
 clearBoardDrag(); P.RefreshTeams(); P.RefreshSlots()
end

local function currentCoreName()
 local G=RyticTank.GroupFrames
 return (P.editState and P.editState.coreName) or ((G and G.GetCurrentProgGroup and G.GetCurrentProgGroup()) or "Default")
end
function P.RefreshCoreUI()
 if P.coreLabel then P.coreLabel:SetText("CORE: "..tostring(currentCoreName())) end
 if P.lockMechButton then
  local mech=P.editState and P.editState.lastMechanic
  P.lockMechButton:SetText((mech and P.IsMechanicLocked(mech)) and "UNLOCK MECH" or "LOCK MECH")
 end
 local G=RyticTank.GroupFrames
 local e=P.editState
 if P.teamNameA then P.teamNameA:SetText((e and e.teamNames and e.teamNames[1]) or ((G and G.GetTeamName and G.GetTeamName(1)) or "TEAM A")) end
 if P.teamNameB then P.teamNameB:SetText((e and e.teamNames and e.teamNames[2]) or ((G and G.GetTeamName and G.GetTeamName(2)) or "TEAM B")) end
end
local function saveCoreFromUI()
 local G=RyticTank.GroupFrames; if not G then return end
 local name=zo_strtrim(P.coreNameEdit and P.coreNameEdit:GetText() or "")
 if name=="" then name=currentCoreName() end
 local e=editState(); local rows={}
 for _,m in ipairs(liveMembers()) do rows[#rows+1]={name=(m.account and m.account~="") and m.account or (m.char or m.name),team=e.teams[memberKey(m)] or 1,locked=true} end
 local positions={saved={[zid()]=deepCopy(e.slots or {})},special={[zid()]=deepCopy(e.special or {})},lastMechanic=e.lastMechanic}
 if G.SaveProgGroupSnapshot and G.SaveProgGroupSnapshot(name,rows,e.teamNames,positions) then e.coreName=name; d("|c55FF55Rytic: saved staged core/prog "..name..".|r") end
 P.RefreshCoreUI(); P.RefreshTeams()
end

local function showCoreMenu()
 local G=RyticTank.GroupFrames; if not G or not G.ListProgGroups then return end
 ClearMenu()
 for _,name in ipairs(G.ListProgGroups()) do AddMenuItem(name,function()
  local snap=G.GetProgGroupSnapshot and G.GetProgGroupSnapshot(name) or nil
  if snap then
   local e=editState(); e.teams={}
   for _,m in ipairs(liveMembers()) do
    local a=snap.assignments[norm(m.account)] or snap.assignments[norm(m.char)] or snap.assignments[norm(m.name)]
    e.teams[memberKey(m)]=(a and a.team==2) and 2 or 1
   end
   e.teamNames=deepCopy(snap.teamNames or {"TEAM A","TEAM B"})
   local ps=snap.positions or {}; e.slots=deepCopy((ps.saved or {})[zid()] or {}); e.special=deepCopy((ps.special or {})[zid()] or {}); e.lastMechanic=ps.lastMechanic or e.lastMechanic
   e.coreName=name
   P.Refresh()
  end
 end) end
 ShowMenu(P.coreLoad)
end

local function deleteCurrentCore()
 local G=RyticTank.GroupFrames; local name=currentCoreName()
 if G and G.DeleteProgGroup and G.DeleteProgGroup(name) then d("|cFFAA00Rytic: deleted core/prog "..name..".|r") end
 P.RefreshCoreUI()
end

function P.Refresh()
 if not raidControlsEnabled() or not P.window or P.window:IsHidden() then return end
 P.zoneLabel:SetText(GetZoneNameById(zid()) or "Unknown Zone"); P.RefreshCoreUI(); P.RefreshMechanics(); P.RefreshRoster(); P.RefreshSlots(); P.RefreshTeams()
end
local function ensureBoardFragment()
 if P.boardFragmentHooked then return true end
 if not HUD_FRAGMENT or not P.window then return false end
 P.boardFragmentHooked=true
 HUD_FRAGMENT:RegisterCallback("StateChange",function(_,newState)
  if not P.window then return end
  if newState==SCENE_FRAGMENT_SHOWN then
   P.window:SetHidden(not P.boardOpen)
  elseif newState==SCENE_FRAGMENT_HIDDEN then
   P.window:SetHidden(true)
  end
 end)
 return true
end

function P.CloseBoard()
 clearBoardDrag()
 discardEditState()
 P.boardOpen=false
 if P.window then P.window:SetHidden(true) end
end

local function openBoard()
 local e=beginEditState(true); local zd=P.data[zid()]
 if zd and (not e.lastMechanic or not zd.mechanics[e.lastMechanic]) then e.lastMechanic=zd.order[1] end
 P.boardOpen=true
 if not ensureBoardFragment() then
  zo_callLater(function()
   if P.window and P.boardOpen then ensureBoardFragment() end
  end,500)
 end
 -- HUD_FRAGMENT is the authoritative visibility gate for menu/HUD transitions.
 local hudShown=HUD_FRAGMENT and HUD_FRAGMENT.GetState and HUD_FRAGMENT:GetState()==SCENE_FRAGMENT_SHOWN
 P.window:SetHidden(not hudShown)
 P.Refresh()
end

function P.CreateBoard()
 if not raidControlsEnabled() then return end
 if P.window then return end
 local w=WM:CreateTopLevelWindow("RyticDDAssignmentWindow"); P.window=w; w:SetHandler("OnUpdate",function() if P.dragMember and P.dragGhost and GetUIMousePosition then local mx,my=GetUIMousePosition(); P.dragGhost:ClearAnchors(); P.dragGhost:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,mx+14,my+14) end end); w:SetKeyboardEnabled(true); w:SetHandler("OnKeyDown",function(_,key) if key==KEY_ESCAPE then P.CloseBoard() end end); w:SetDimensions(1120,735); w:SetAnchor(CENTER,GuiRoot,CENTER,0,0); w:SetHidden(true); w:SetMovable(false); w:SetMouseEnabled(true); w:SetClampedToScreen(true); w:SetDrawTier(DT_HIGH); backdrop(w,.012,.018,.028,.98)
 ensureBoardFragment()
  local title=label(w,"RYTIC RAID CONTROLS — GROUP & MECHANIC ASSIGNMENTS","ZoFontWinH2"); title:SetAnchor(TOPLEFT,w,TOPLEFT,16,8); title:SetDimensions(900,32)
 P.zoneLabel=label(w,"","ZoFontGameSmall"); P.zoneLabel:SetAnchor(TOPLEFT,w,TOPLEFT,18,39); P.zoneLabel:SetDimensions(500,20); P.zoneLabel:SetColor(.65,.75,.85,1)
 local close=btn(w,"X",34,28,function() P.CloseBoard() end); close:SetAnchor(TOPRIGHT,w,TOPRIGHT,-10,9)
 local drag=WM:CreateControl(nil,w,CT_CONTROL); drag:SetDimensions(1000,38); drag:SetAnchor(TOPLEFT,w,TOPLEFT,0,0); drag:SetMouseEnabled(true); drag:SetHandler("OnMouseDown",function(_,b) if b==MOUSE_BUTTON_INDEX_LEFT then w:SetMovable(true); w:StartMoving() end end); drag:SetHandler("OnMouseUp",function(_,b) if b==MOUSE_BUTTON_INDEX_LEFT then w:StopMovingOrResizing(); w:SetMovable(false) end end)

 P.coreLabel=label(w,"CORE: Default","ZoFontGameBold"); P.coreLabel:SetAnchor(TOPLEFT,w,TOPLEFT,18,62); P.coreLabel:SetDimensions(210,26)
 P.coreNameEdit=WM:CreateControl(nil,w,CT_EDITBOX); P.coreNameEdit:SetDimensions(180,28); P.coreNameEdit:SetAnchor(LEFT,P.coreLabel,RIGHT,6,0); P.coreNameEdit:SetFont("ZoFontGame"); P.coreNameEdit:SetMaxInputChars(28); P.coreNameEdit:SetText(""); P.coreNameEdit:SetMouseEnabled(true); P.coreNameEdit:SetEditEnabled(true); if P.coreNameEdit.SetKeyboardEnabled then P.coreNameEdit:SetKeyboardEnabled(true) end; P.coreNameEdit:SetHandler("OnMouseDown",function(self,b) if b==MOUSE_BUTTON_INDEX_LEFT then self:TakeFocus() end end); backdrop(P.coreNameEdit,.025,.035,.05,.98)
 local save=btn(w,"SAVE CORE",105,28,saveCoreFromUI); save:SetAnchor(LEFT,P.coreNameEdit,RIGHT,7,0)
 P.coreLoad=btn(w,"LOAD CORE",105,28,showCoreMenu); P.coreLoad:SetAnchor(LEFT,save,RIGHT,7,0)
 local del=btn(w,"DELETE",80,28,deleteCurrentCore); del:SetAnchor(LEFT,P.coreLoad,RIGHT,7,0)

 P.mechBox=WM:CreateControl(nil,w,CT_BACKDROP); P.mechBox:SetDimensions(180,340); P.mechBox:SetAnchor(TOPLEFT,w,TOPLEFT,14,104); P.mechBox:SetCenterColor(.02,.025,.035,.95); P.mechBox:SetEdgeColor(.22,.48,.7,1)
 local mh=label(P.mechBox,"MECHANICS","ZoFontGameBold"); mh:SetAnchor(TOP,P.mechBox,TOP,0,6); mh:SetDimensions(170,22); mh:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
 P.slotBox=WM:CreateControl(nil,w,CT_BACKDROP); P.slotBox:SetDimensions(530,340); P.slotBox:SetAnchor(TOPLEFT,w,TOPLEFT,204,104); P.slotBox:SetCenterColor(.02,.025,.035,.95); P.slotBox:SetEdgeColor(.22,.48,.7,1)
 P.slotTitle=label(P.slotBox,"ASSIGNMENTS","ZoFontGameBold"); P.slotTitle:SetAnchor(TOP,P.slotBox,TOP,0,8); P.slotTitle:SetDimensions(500,24); P.slotTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
 P.rosterBox=WM:CreateControl(nil,w,CT_BACKDROP); P.rosterBox:SetDimensions(250,340); P.rosterBox:SetAnchor(TOPLEFT,w,TOPLEFT,744,104); P.rosterBox:SetCenterColor(.02,.025,.035,.95); P.rosterBox:SetEdgeColor(.22,.48,.7,1)
 local rh=label(P.rosterBox,"LIVE GROUP ROSTER","ZoFontGameBold"); rh:SetAnchor(TOP,P.rosterBox,TOP,0,7); rh:SetDimensions(240,24); rh:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

 local function teamNameEdit(x,team)
  local caption=label(w,"TEAM NAME:","ZoFontGameBold")
  caption:SetAnchor(TOPLEFT,w,TOPLEFT,x,456)
  caption:SetDimensions(92,28)
  local e=WM:CreateControl(nil,w,CT_EDITBOX)
  e:SetDimensions(163,28)
  e:SetAnchor(LEFT,caption,RIGHT,0,0)
  e:SetFont("ZoFontGameBold")
  e:SetMaxInputChars(18)
  e:SetMouseEnabled(true)
  e:SetEditEnabled(true)
  if e.SetKeyboardEnabled then e:SetKeyboardEnabled(true) end
  e:SetSelectAllOnFocus(true)
  e:SetHandler("OnMouseDown",function(self,b) if b==MOUSE_BUTTON_INDEX_LEFT then self:TakeFocus() end end)
  backdrop(e,.025,.035,.05,.98)
  local commitPending=false
  local cancelCommit=false
  local function queueTeamNameCommit(self)
   if cancelCommit then
    cancelCommit=false
    return
   end
   if commitPending then return end
   commitPending=true
   local value=zo_strtrim(self:GetText() or "")
   if value=="" then value=(team==1 and "TEAM A" or "TEAM B") end
   -- Do not rebuild GroupFrames/Positions while ESO is still processing the
   -- edit box focus event.  That can leave keyboard/mouse input captured.
   zo_callLater(function()
    commitPending=false
    local e=editState(); e.teamNames[team]=value
    P.RefreshTeams()
   end,0)
  end
  e:SetHandler("OnFocusLost",queueTeamNameCommit)
  e:SetHandler("OnEnter",function(self) self:LoseFocus() end)
  e:SetHandler("OnEscape",function(self)
   cancelCommit=true
   local e=editState(); self:SetText((e.teamNames and e.teamNames[team]) or (team==1 and "TEAM A" or "TEAM B"))
   self:LoseFocus()
  end)
  return e
 end
 P.teamNameA=teamNameEdit(204,1); P.teamNameB=teamNameEdit(474,2)
 local function groupBox(x,titleText,t,wid)
  local b=WM:CreateControl(nil,w,CT_BACKDROP); b:SetDimensions(wid or 260,180); b:SetAnchor(TOPLEFT,w,TOPLEFT,x,490); b:SetCenterColor(.02,.025,.035,.95); b:SetEdgeColor(.22,.48,.7,1); b:SetMouseEnabled(true)
  local h=label(b,titleText,"ZoFontGameBold"); h:SetAnchor(TOP,b,TOP,0,6); h:SetDimensions((wid or 260)-10,22); h:SetHorizontalAlignment(TEXT_ALIGN_CENTER); return b,h
 end
 P.teamA,P.teamATitle=groupBox(204,"TEAM A",1,260); P.teamB,P.teamBTitle=groupBox(474,"TEAM B",2,260); P.specialBox,P.specialTitle=groupBox(744,"SPECIAL",3,180)

 local auto=btn(w,"AUTO DPS TEAMS",145,30,function()
  local e=editState()
  for _,m in ipairs(liveDDs()) do e.manualTeams[memberKey(m)]=nil end
  if not P.ImportMechanicSplitToTeams(e.lastMechanic,zid()) then
   local n=0
   for _,m in ipairs(liveDDs()) do n=n+1; e.teams[memberKey(m)]=(n%2==1) and 1 or 2 end
  end
  P.RefreshTeams(); P.RefreshSlots()
 end); auto:SetAnchor(BOTTOMLEFT,w,BOTTOMLEFT,14,-14)
 local pushTeams=btn(w,"PUSH TEAMS",125,30,function() P.PushTeams() end); pushTeams:SetAnchor(LEFT,auto,RIGHT,8,0)
 local chat=btn(w,"PUSH ASSIGNMENTS",165,30,function() P.Push() end); chat:SetAnchor(LEFT,pushTeams,RIGHT,8,0)
 local refresh=btn(w,"REFRESH",95,30,function() P.Refresh() end); refresh:SetAnchor(LEFT,chat,RIGHT,8,0)
 local clear=btn(w,"CLEAR MECH",125,30,function() P.ClearCurrentMechanic() end); clear:SetAnchor(LEFT,refresh,RIGHT,8,0)
 local lock=btn(w,"LOCK MECH",125,30,function(self)
  local e=editState(); local mech=e.lastMechanic
  if not mech then return end
  local on=not P.IsMechanicLocked(mech)
  P.SetMechanicLocked(mech,on)
  self:SetText(on and "UNLOCK MECH" or "LOCK MECH")
 end); lock:SetAnchor(LEFT,clear,RIGHT,8,0)
 P.lockMechButton=lock
 P.mechControls={}; P.rosterControls={}; P.slotControls={}; P.teamControls={}
 P.RefreshCoreUI()
end

function P.SetEnabled(enabled)
 P.enabled=enabled and true or false
 if not P.enabled then
  P.CloseBoard()
 end
end

function P.ToggleBoard()
 if not raidControlsEnabled() then return end
 P.CreateBoard()
 if not P.window then return end
 if P.editState then
  P.CloseBoard()
 else
  openBoard()
 end
end
-- Refresh open board when group membership/roles change.
local function eventRefresh()
 if IsUnitGrouped and not IsUnitGrouped("player") then P.manualTeamOverrides={} end
 if not raidControlsEnabled() then return end
 if P.window and not P.window:IsHidden() then zo_callLater(P.Refresh,100) end
end
EM:RegisterForEvent("RyticPositionsGroup",EVENT_GROUP_UPDATE,eventRefresh)
if EVENT_GROUP_MEMBER_ROLE_CHANGED then EM:RegisterForEvent("RyticPositionsRole",EVENT_GROUP_MEMBER_ROLE_CHANGED,eventRefresh) end

-- Synchronize to Raid Controls if RaidLead was already initialized before this file.
zo_callLater(function()
 local R=RyticTank.RaidLead
 if R and R.IsEnabled then P.SetEnabled(R.IsEnabled()) end
end,0)
