LazyCrown=LazyCrown or {}
LazyCrown.later=LazyCrown.later or {}
table.insert(LazyCrown.later,{name="Personalities.lua",code=[=[
LazyCrown=LazyCrown or{}
local P={}
LazyCrown.Personalities=P
local AD,EP,DC=ALLIANCE_ALDMERI_DOMINION or 1,ALLIANCE_EBONHEART_PACT or 2,ALLIANCE_DAGGERFALL_COVENANT or 3
local SCROLLS={
[AD]={{temple=118,hub=16,side=19},{temple=119,hub=16,side=20}},
[EP]={{temple=120,hub=10,side=12},{temple=121,hub=10,side=11}},
[DC]={{temple=122,hub=5,side=3},{temple=123,hub=5,side=4}},
}
local HUBS={[16]=true,[10]=true,[5]=true}
local COLOR={
[118]="orange",[120]="orange",[122]="orange",
[119]="purple",[121]="purple",[123]="purple",
}
local HOME={
[AD]={[15]=true,[16]=true,[17]=true,[18]=true,[19]=true,[20]=true},
[EP]={[9]=true,[10]=true,[11]=true,[12]=true,[13]=true,[14]=true},
[DC]={[3]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true},
}
local EMPEROR_KEEPS={6,7,9,13,15,17}
local WINGS={
north={keep=8,town=151,outpost=163},
west={keep=18,town=149,outpost=164},
east={keep=14,town=152,outpost=165},
}
local FLANKS={}
for _,wing in pairs(WINGS)do FLANKS[wing.town],FLANKS[wing.outpost]=true,true end
local GRUDGE_KEEPS={[DC]=3,[EP]=11,[AD]=19}
local ALLIANCE_SHORT={[AD]="Dominion",[EP]="Pact",[DC]="Covenant"}
local TROLL_CALLS={
{keepId=6,directive="troll Ash by sieging from the mine tower"},
{keepId=11,directive="troll Kingscrest by sieging from the lumbermill"},
{keepId=3,directive="troll Warden by sieging from the mine and mine tower"},
{keepId=8,directive="be annoying and take Dragonclaw from the lumbermill tower"},
{keepId=16,directive="troll Faregyl by sieging from the back wall",spot=true},
{keepId=16,directive="troll Faregyl by sieging from the lumbermill",spot=true},
{keepId=15,directive="be annoying and take Alessia from the farm",spot=true},
{keepId=17,directive="troll Roebeck by sieging from the lumbermill",spot=true},
{keepId=18,directive="be annoying and take Brindle from the lumbermill",spot=true},
{keepId=7,directive="troll Aleswell by sieging from the back hill",spot=true},
{keepId=5,directive="troll Glademist by sieging from the mine",spot=true},
{keepId=9,directive="be annoying and take Chalman from the back hill",spot=true},
{keepId=13,directive="be annoying and take Blue Road Keep from the mine side",spot=true},
{keepId=13,directive="troll Blue Road Keep by sieging from the back wall",spot=true},
{keepId=10,directive="troll Arrius by sieging from the mine",spot=true},
}
local BACK_FLAG={[3]=56,[4]=75,[5]=70,[6]=177,[7]=173,[8]=169,[9]=179,[10]=65,[11]=77,
[12]=51,[13]=176,[14]=171,[15]=167,[16]=60,[17]=165,[18]=163,[19]=49,[20]=40}
local CA_BUFFS={[39249]=true,[45617]=true}
local CA_PASSIVE=39248
local CLOSE=0.06
local NEAR=0.12
local AREA=0.2
local SIEGE_SPOT_STREAK=10
local LEAVE_AFTER_L=0.1
local OTHER_SIDE=0.35
local PUSH_REACH=0.25
local GATE_HOP=0.1
local FIGHT_RADIUS=0.025
local LOST_CAUSE=20
local BIG_FIGHT=10
local IN_THE_WAY=0.03
local CA_LOW=180
local function Dist(a,b)
if not(a and b and a.x and b.x)then return nil end
local dx,dy=a.x - b.x,a.y - b.y
return math.sqrt(dx*dx+dy*dy)
end
local function Results(ok,...)
if ok then return ... end
end
local function Safe(fn,...)
if not fn then return nil end
return Results(pcall(fn,...))
end
local function Away(w,t)
if w.Away then return w.Away(t)end
return w.player and Dist(w.player,t)
end
local function TopPick(w,list,scoreOf,n,slack)
local scored={}
for _,item in ipairs(list)do
local score=scoreOf(item)
if score and score>-1e8 then table.insert(scored,{item=item,score=score})end
end
if#scored==0 then return nil end
table.sort(scored,function(a,b)return a.score>b.score end)
if slack then
local floor=scored[1].score - slack
for i=#scored,2,-1 do if scored[i].score<floor then table.remove(scored,i)end end
end
n=math.min(n or 3,#scored)
if w.planned then
for i=1,n do if scored[i].item.keepId==w.planned then return scored[i].item end end
end
local total=n*(n+1)/2
local roll=w.Random(1,total)
for i=1,n do
roll=roll -(n - i+1)
if roll<=0 then return scored[i].item end
end
return scored[1].item
end
local function Filter(list,keep)
local out={}
for _,item in ipairs(list)do if keep(item)then table.insert(out,item)end end
return out
end
local function Nearest(from,list,maxDist)
local best,bestD
for _,item in ipairs(list)do
local d=Dist(from,item)
if d and(not maxDist or d<=maxDist)and(not bestD or d<bestD)then best,bestD=item,d end
end
return best
end
local function Fights(w)
if w._fights then return w._fights end
local fights={}
if w.Markers then
for _,m in ipairs(w.Markers())do
if(m.x~=0 or m.y~=0)and m.pinType~=MAP_PIN_TYPE_INVALID then
table.insert(fights,{x=m.x,y=m.y,kills={[AD]=m.kills[AD] or 0,[EP]=m.kills[EP] or 0,[DC]=m.kills[DC] or 0}})
end
end
w._fights=fights
return fights
end
local n=Safe(GetNumKillLocations)or 0
for i=1,n do
local pinType,x,y=Safe(GetKillLocationPinInfo,i)
if x and y and(x~=0 or y~=0)and pinType~=MAP_PIN_TYPE_INVALID then
local f={x=x,y=y,kills={}}
for _,a in ipairs({AD,EP,DC})do f.kills[a]=Safe(GetNumKillLocationAllianceKills,i,a)or 0 end
table.insert(fights,f)
end
end
w._fights=fights
return fights
end
local function FightSum(w,t)
local fights=Fights(w)
local sums=w._fightSum
if not(sums and sums.fights==fights)then
sums={fights=fights,total={},[AD]={},[EP]={},[DC]={}}
w._fightSum=sums
end
local spot=t.keepId and w.byId and w.byId[t.keepId]
local key=spot and spot.x==t.x and spot.y==t.y and t.keepId or nil
if key and sums.total[key] then return sums.total[key],sums[AD][key],sums[EP][key],sums[DC][key] end
local total,ad,ep,dc=0,0,0,0
for _,f in ipairs(fights)do
local d=Dist(t,f)
if d and d<=FIGHT_RADIUS then
local k=f.kills
total,ad,ep,dc=total+k[AD]+k[EP]+k[DC],ad+k[AD],ep+k[EP],dc+k[DC]
end
end
if key then sums.total[key],sums[AD][key],sums[EP][key],sums[DC][key]=total,ad,ep,dc end
return total,ad,ep,dc
end
local function FightAt(w,t)
local _,ad,ep,dc=FightSum(w,t)
local mine=w.mine
local ours=(mine==AD and ad)or(mine==EP and ep)or(mine==DC and dc)or 0
return ours,math.max(mine~=AD and ad or 0,mine~=EP and ep or 0,mine~=DC and dc or 0)
end
local function LostCause(w,t)
local ours,theirs=FightAt(w,t)
return theirs>=LOST_CAUSE and theirs>ours*2
end
local function NoObjectives()return{n=0,keepId={},objectiveId={},ctx={},kind={}}end
local function ReadObjective(list,i)
local keepId,objectiveId,ctx=Safe(GetObjectiveIdsForIndex,i)
local isLocal=keepId and(not IsLocalBattlegroundContext or IsLocalBattlegroundContext(ctx))
if not isLocal then return nil end
local n=list.n+1
list.n,list.keepId[n],list.objectiveId[n],list.ctx[n]=n,keepId,objectiveId,ctx
list.kind[n]=Safe(GetObjectiveType,keepId,objectiveId,ctx)
return n
end
local function Objectives(w)
if w._objectives then return w._objectives end
local list=NoObjectives()
for i=1,Safe(GetNumObjectives)or 0 do ReadObjective(list,i)end
w._objectives=list
return list
end
local function Flags(w)
if w._flags then return w._flags end
local flags={}
local list=OBJECTIVE_CAPTURE_AREA and Objectives(w)or NoObjectives()
for i=1,list.n do
local keepId,objectiveId,ctx=list.keepId[i],list.objectiveId[i],list.ctx[i]
if list.kind[i]==OBJECTIVE_CAPTURE_AREA then
local f=flags[keepId] or{total=0,moving=0,lost=0,by={}}
flags[keepId]=f
f.total=f.total+1
local state=Safe(GetObjectiveControlState,keepId,objectiveId,ctx)
local holder=Safe(GetCaptureAreaObjectiveOwner,keepId,objectiveId,ctx)
local owner=w.byId[keepId] and w.byId[keepId].owner
local neutral=state~=nil and state==OBJECTIVE_CONTROL_STATE_AREA_NO_CONTROL
local stepping=state~=nil and(state==OBJECTIVE_CONTROL_STATE_AREA_ABOVE_CONTROL_THRESHOLD
or state==OBJECTIVE_CONTROL_STATE_AREA_BELOW_CONTROL_THRESHOLD)
if neutral or stepping then
f.moving=f.moving+1
local name=tostring(Safe(GetObjectiveInfo,keepId,objectiveId,ctx)or ""):lower()
if name:find("apse",1,true)or(not name:find("nave",1,true)and BACK_FLAG[keepId]==objectiveId)then f.back=true end
end
if neutral or(holder and holder~=0 and owner and holder~=owner)then f.lost=f.lost+1 end
if holder and holder~=0 and owner and holder~=owner then f.by[holder]=(f.by[holder] or 0)+1 end
end
end
w._flags=flags
return flags
end
local function Sieges(w,t,alliance)
if alliance==nil then return Safe(GetNumSieges,t.keepId,w.ctx,alliance)or 0 end
local known=w._sieges
if not known then known={};w._sieges=known end
local byKeep=known[alliance]
if not byKeep then byKeep={};known[alliance]=byKeep end
local n=byKeep[t.keepId]
if n==nil then
n=Safe(GetNumSieges,t.keepId,w.ctx,alliance)or 0
byKeep[t.keepId]=n
end
return n
end
local function Flipping(w,keepId)
local flags=Flags(w)
if next(flags)==nil then return true end
local f=flags[keepId]
return f~=nil and(f.moving>0 or f.lost>0)
end
local function ContinuousAttack(w)
if w and w.ignoreCA then return math.huge,false end
local left=0
local now=Safe(GetFrameTimeSeconds)or 0
for i=1,Safe(GetNumBuffs,"player")or 0 do
local _,_,ending,_,_,_,_,_,_,_,abilityId=Safe(GetUnitBuffInfo,"player",i)
if CA_BUFFS[abilityId] and ending and ending>now then left=math.max(left,ending - now)end
end
local owned=true
if GetSpecificSkillAbilityKeysByAbilityId and IsSkillAbilityPurchased then
local ok,a,b,c=pcall(GetSpecificSkillAbilityKeysByAbilityId,CA_PASSIVE)
if ok and a then
local okP,purchased=pcall(IsSkillAbilityPurchased,a,b,c)
if okP then owned=purchased==true end
end
end
return left,owned
end
local function Scrolls(w,alliance)
w._scrollSpots=w._scrollSpots or{}
if w._scrollSpots[alliance] then return w._scrollSpots[alliance] end
local out={}
for _,gate in ipairs(SCROLLS[alliance] or{})do
local objectiveId=Safe(GetKeepArtifactObjectiveId,gate.temple)
local state=objectiveId and Safe(GetObjectiveControlState,gate.temple,objectiveId,w.ctx)
local spot={gate=gate}
spot.home=state==nil or OBJECTIVE_CONTROL_STATE_FLAG_AT_BASE==nil or state==OBJECTIVE_CONTROL_STATE_FLAG_AT_BASE
if not spot.home then
if OBJECTIVE_CONTROL_STATE_FLAG_AT_ENEMY_BASE and state==OBJECTIVE_CONTROL_STATE_FLAG_AT_ENEMY_BASE then
spot.heldAt=Safe(GetKeepThatHasCapturedThisArtifactScrollObjective,gate.temple,objectiveId,w.ctx)
end
end
table.insert(out,spot)
end
w._scrollSpots[alliance]=out
return out
end
local function EmperorAlliance(w)
if w._emperor==nil then
local alliance=Safe(DoesCampaignHaveEmperor,w.campaignId)and Safe(GetCampaignEmperorInfo,w.campaignId)
w._emperor=alliance and alliance~=0 and alliance or false
end
return w._emperor or nil
end
local function ScrollsHome(w)
if w._scrolls then return w._scrolls end
local home={}
for _,gate in ipairs(SCROLLS[w.mine] or{})do
local objectiveId=Safe(GetKeepArtifactObjectiveId,gate.temple)
local state=objectiveId and Safe(GetObjectiveControlState,gate.temple,objectiveId,w.ctx)
home[gate.temple]=state==nil or state==OBJECTIVE_CONTROL_STATE_FLAG_AT_BASE or OBJECTIVE_CONTROL_STATE_FLAG_AT_BASE==nil
or(OBJECTIVE_CONTROL_STATE_UNKNOWN~=nil and state==OBJECTIVE_CONTROL_STATE_UNKNOWN)
end
w._scrolls=home
return home
end
local function OwnerOf(w,keepId)
local t=w.byId[keepId]
if t and t.owner then return t.owner end
return Safe(GetKeepAlliance,keepId,w.ctx)
end
local function Threatened(w,color)
for _,a in ipairs({AD,EP,DC})do
if a~=w.mine then
for _,spot in ipairs(Scrolls(w,a))do
local holder=spot.heldAt and spot.heldAt~=0 and OwnerOf(w,spot.heldAt)
local away=holder and holder~=0 and holder~=a
if COLOR[spot.gate.temple]==color and not away then return true end
end
end
end
return false
end
local function ScrollGuard(w,keepId)
local guards,lastLock=0,false
local home=ScrollsHome(w)
for _,gate in ipairs(SCROLLS[w.mine] or{})do
if(gate.hub==keepId or gate.side==keepId)and home[gate.temple] and Threatened(w,COLOR[gate.temple])then
guards=guards+1
local other=gate.hub==keepId and gate.side or gate.hub
if OwnerOf(w,other)~=w.mine then lastLock=true end
end
end
return guards,lastLock
end
local function HaveColor(w,color)
for _,spot in ipairs(Scrolls(w,w.mine))do
if COLOR[spot.gate.temple]==color and spot.home then return true end
end
return false
end
local function FreePedestal(w)
local used={}
for _,a in ipairs({AD,EP,DC})do
for _,spot in ipairs(Scrolls(w,a))do if spot.heldAt and spot.heldAt~=0 then used[spot.heldAt]=true end end
end
for keepId in pairs(HOME[w.mine] or{})do
if OwnerOf(w,keepId)==w.mine and not used[keepId] then return true end
end
return false
end
local function RaidValues(w)
if w._raids then return w._raids end
local value={}
local function add(keepId,v)if not value[keepId] or v>value[keepId] then value[keepId]=v end end
local free=FreePedestal(w)
for _,alliance in ipairs({AD,EP,DC})do
for i,gate in ipairs(SCROLLS[alliance])do
local spot=Scrolls(w,alliance)[i]
if spot.heldAt and spot.heldAt~=0 then
if OwnerOf(w,spot.heldAt)~=w.mine then
if alliance==w.mine then add(spot.heldAt,20)
elseif HOME[w.mine][spot.heldAt] then add(spot.heldAt,16)
elseif free and HaveColor(w,COLOR[gate.temple])then add(spot.heldAt,16)end
end
elseif alliance~=w.mine and spot.home and free and HaveColor(w,COLOR[gate.temple])then
for _,keepId in ipairs({gate.hub,gate.side})do
local other=keepId==gate.hub and gate.side or gate.hub
if OwnerOf(w,keepId)==alliance then
add(keepId,(OwnerOf(w,other)~=alliance and 12 or 6)+(HUBS[keepId] and 2 or 0))
end
end
end
end
end
w._raids=value
return value
end
local function EmperorKeeps(w,alliance)
local known=w._empKeeps
if not known then known={};w._empKeeps=known end
if alliance~=nil and known[alliance] then return known[alliance] end
local keeps=EMPEROR_KEEPS
local rulesetId=Safe(GetCampaignRulesetId,w.campaignId)
local n=rulesetId and Safe(GetCampaignRulesetNumImperialKeeps,rulesetId,alliance)
if n==0 then
keeps={}
elseif n and n>0 then
local listed={}
for i=1,n do
local keepId=Safe(GetCampaignRulesetImperialKeepId,rulesetId,alliance,i)
if keepId then table.insert(listed,keepId)end
end
if#listed>0 then keeps=listed end
end
if alliance~=nil then known[alliance]=keeps end
return keeps
end
local function LastEmperorKeep(w,alliance)
local known=w._lastEmp
if not known then known={};w._lastEmp=known end
if alliance~=nil and known[alliance]~=nil then return known[alliance] or nil end
local missing
for _,keepId in ipairs(EmperorKeeps(w,alliance))do
if OwnerOf(w,keepId)~=alliance then
if missing then missing=false break end
missing=keepId
end
end
if alliance~=nil then known[alliance]=missing or false end
return missing or nil
end
local function HoldsAllHome(w,alliance)
for keepId in pairs(HOME[alliance] or{})do
if OwnerOf(w,keepId)~=alliance then return false end
end
return true
end
local function ThroneKeep(w)
local emperor=EmperorAlliance(w)
if not emperor or emperor==w.mine then return nil end
local last
for _,keepId in ipairs(EmperorKeeps(w,emperor))do
if OwnerOf(w,keepId)==emperor then
if last then return nil end
last=keepId
end
end
return last
end
local function Throne(w)
if w._throne==nil then
local throne=false
if EmperorAlliance(w)==w.mine then
throne={isEmp={},held={}}
for _,keepId in ipairs(EmperorKeeps(w,w.mine))do
throne.isEmp[keepId]=true
if OwnerOf(w,keepId)==w.mine then table.insert(throne.held,w.byId[keepId] or{keepId=keepId})end
end
end
w._throne=throne
end
return w._throne or nil
end
local function OurThrone(w)
local throne=Throne(w)
if not throne then return nil end
return throne.isEmp,#throne.held
end
local function FromClosest(keeps,t)
local best
for _,k in ipairs(keeps)do
local d=Dist(k,t)
if d and(not best or d<best)then best=d end
end
return best
end
local function MoreBars(w)
local a,b
for _,x in ipairs({AD,EP,DC})do if x~=w.mine then if a then b=x else a=x end end end
local pa,pb=w.Bars and w.Bars(a),w.Bars and w.Bars(b)
if type(pa)~="number" or type(pb)~="number" or pa==pb then return nil end
return pa>pb and a or b
end
local function PushOn(w)
if w._pushOn~=nil then return w._pushOn or nil end
local enemies={}
for _,a in ipairs({AD,EP,DC})do if a~=w.mine then table.insert(enemies,a)end end
local function weight(a)
local pop=w.Bars and w.Bars(a)
local keeps=0
for _,t in ipairs(w.targets)do if t.kind=="Keep" and t.owner==a then keeps=keeps+1 end end
return(type(pop)=="number" and pop or 0)*100+keeps
end
local a,b=enemies[1],enemies[2]
local wa,wb=weight(a),weight(b)
local push=(wa>wb and a)or(wb>wa and b)or nil
if push then
local other=push==a and b or a
local lost=w.lossesBy or{}
if(lost[tostring(push)] or 0)>=(lost[tostring(other)] or 0)+2 then push=other end
end
w._pushOn=push or false
return push
end
local function Most(count)
local best,n,tie=nil,0,false
for a,k in pairs(count)do
if k>n then best,n,tie=a,k,false elseif k==n and k>0 then tie=true end
end
return not tie and best or nil
end
local function Oppressor(w,skipFlags)
local count={}
for keepId,f in pairs(skipFlags and{}or Flags(w))do
if OwnerOf(w,keepId)==w.mine then
for a,n in pairs(f.by or{})do if a~=w.mine then count[a]=(count[a] or 0)+n end end
end
end
local who=Most(count)
if who then return who end
count={}
for _,spot in ipairs(Scrolls(w,w.mine))do
local a=not spot.home and spot.heldAt and OwnerOf(w,spot.heldAt)
if a and a~=w.mine then count[a]=(count[a] or 0)+1 end
end
who=Most(count)
if who then return who end
local emperor=EmperorAlliance(w)
if emperor and emperor~=w.mine then return emperor end
return PushOn(w)
end
local function Territory(t,alliance)
if not alliance then return false end
return t.home==alliance or(HOME[alliance] and(HOME[alliance][t.keepId] or(t.parent and HOME[alliance][t.parent])))or false
end
local function FightNear(w,t)
return(FightSum(w,t))
end
local function WingYoureIn(w)
local wing,closest
for _,name in ipairs({"north","west","east"})do
local wg=WINGS[name]
for _,keepId in ipairs({wg.town,wg.outpost,wg.keep})do
local d=Dist(w.player,w.byId[keepId])
if d and(not closest or d<closest)then wing,closest=wg,d end
end
end
return wing
end
local function InWing(wing,t)
return t~=nil and(t.keepId==wing.town or t.keepId==wing.outpost or t.keepId==wing.keep or t.parent==wing.keep)
end
local function LosingFight(w,t)
local ours,theirs=FightAt(w,t)
return theirs>=5 and theirs>ours
end
local function ThreeWay(w,t)
local _,ad,ep,dc=FightSum(w,t)
local n=0
if w.mine~=AD and ad>=5 then n=n+1 end
if w.mine~=EP and ep>=5 then n=n+1 end
if w.mine~=DC and dc>=5 then n=n+1 end
return n==2
end
local function Gated(w)
for keepId in pairs(HOME[w.mine] or{})do if OwnerOf(w,keepId)==w.mine then return false end end
return true
end
local function OurScrollIn(w,keepId)
for _,spot in ipairs(Scrolls(w,w.mine))do if not spot.home and spot.heldAt==keepId then return true end end
return false
end
local function GuardingThrone(w)
local throne=Throne(w)
if not throne or#throne.held==0 or#throne.held>2 then return nil end
if throne.guarding==nil then
local keeps={}
for keepId in pairs(throne.isEmp)do
if OwnerOf(w,keepId)==w.mine and w.byId[keepId] then table.insert(keeps,w.byId[keepId])end
end
throne.guarding=#keeps>0 and keeps or false
end
return throne.guarding or nil
end
local function BackKeep(alliance,keepId)
for _,gate in ipairs(SCROLLS[alliance] or{})do
if gate.hub==keepId or gate.side==keepId then return true end
end
return false
end
local function BallGroup(w)
local took,held={},0
for keepId in pairs(HOME[w.mine])do
local owner=OwnerOf(w,keepId)
if owner==w.mine then held=held+1
elseif owner then took[owner]=(took[owner] or 0)+1 end
end
if held<4 then return nil end
local ballGroup
for _,a in ipairs({AD,EP,DC})do
if took[a] and(not ballGroup or took[a]>took[ballGroup])then ballGroup=a end
end
return ballGroup
end
local function IntoTheBall(w,t,ballGroup)
local keepId=t.parent or t.keepId
return ballGroup~=nil and HOME[w.mine][keepId]~=nil and OwnerOf(w,keepId)==ballGroup
and not Flipping(w,keepId)and Sieges(w,w.byId[keepId] or t,w.mine)==0
end
local function ThroneSide(w,list)
if not GuardingThrone(w)then return list end
local out=Filter(list,function(t)
return Territory(t,w.mine)and not BackKeep(w.mine,t.parent or t.keepId)
end)
return#out>0 and out or list
end
local function WinRate(w,t)
local life=w.lifetime and w.lifetime[tostring(t.keepId)]
local wins,losses=life and life.w or 0,life and life.l or 0
return(wins+1)/(wins+losses+2)
end
local function ParentOf(w,t)
return t.parent and w.byId[t.parent]
end
local function ResourcesOf(w,keepId)
local ids=w._resourceIds
if not ids then
ids={}
for _,t in ipairs(w.targets)do
if t.parent then
ids[t.parent]=ids[t.parent] or{}
table.insert(ids[t.parent],t.keepId)
end
end
w._resourceIds=ids
end
local out={}
for _,id in ipairs(ids[keepId] or{})do table.insert(out,w.byId[id])end
return out
end
local WEAK_WALLS={[3]=true,[6]=true,[7]=true,[9]=true,[10]=true,[11]=true,[13]=true,[15]=true,[17]=true}
local WAY_SECONDS=1200
local LINE={Lumbermill=RESOURCETYPE_WOOD or 1,Farm=RESOURCETYPE_FOOD or 2,Mine=RESOURCETYPE_ORE or 3}
local WANT={door={"Lumbermill","Farm"},wall={"Mine","Farm"}}
local WAY_RULE={diil="any",greedy="nine",november="nine"}
local function MemoWay(w,keep)
local ways=type(w.memory)=="table" and w.memory.ways
local m=type(ways)=="table" and ways[tostring(keep.keepId)]
if type(m)=="table" and w.now and m.at and w.now - m.at<WAY_SECONDS and m.owner==keep.owner then return m.way end
end
local function RememberWay(w,keep,way)
if w.planning or not w.now or type(w.memory)~="table" then return end
local ways=type(w.memory.ways)=="table" and w.memory.ways or{}
for k,m in pairs(ways)do if type(m)~="table" or not(m.at and w.now - m.at<WAY_SECONDS)then ways[k]=nil end end
ways[tostring(keep.keepId)]={way=way,at=w.now,owner=keep.owner}
w.memory.ways=ways
end
local function WayIn(w,keep,rule,remember)
local allowed=(rule=="any" and(keep.kind=="Keep" or keep.kind=="Outpost"))
or(rule=="nine" and keep.kind=="Keep" and WEAK_WALLS[keep.keepId]~=nil)
local memo=MemoWay(w,keep)
if memo then return(memo=="wall" and allowed)and "wall" or "door" end
if not allowed then return "door" end
local way=w.Random(1,2)==1 and "wall" or "door"
if remember then RememberWay(w,keep,way)end
return way
end
local function LineLevel(w,keepId,kind)
local levels=w._lineLevels
if not levels then levels={};w._lineLevels=levels end
local key=keepId*10+LINE[kind]
if levels[key]==nil then levels[key]=Safe(GetKeepResourceLevel,keepId,w.ctx,LINE[kind],true)or false end
return levels[key] or nil
end
local function WantedResource(w,keep,list,way)
if not(keep and keep.kind=="Keep" and keep.owner and keep.owner~=w.mine)then return nil end
local order=WANT[way or "door"] or WANT.door
if w.lowDps then order={"Farm",order[1]}end
for _,kind in ipairs(order)do
local level=LineLevel(w,keep.keepId,kind)
if level==nil or level>0 then
for _,r in ipairs(list)do
if r.parent==keep.keepId and r.kind==kind and r.owner==keep.owner and not r.defend then return r end
end
end
end
end
P.NoteWay=function(w,pick)
if w.planning or not w.now or not pick.parent or pick.defend or pick.directive or pick.unscored then return end
local way=(pick.kind=="Lumbermill" and "door")or(pick.kind=="Mine" and "wall")or nil
local keep=w.byId[pick.parent]
if way and keep and keep.owner~=w.mine then RememberWay(w,keep,way)end
end
local function ScrollsAt(w,keepId)
local n=0
for _,a in ipairs({AD,EP,DC})do
for _,spot in ipairs(Scrolls(w,a))do if spot.heldAt==keepId then n=n+1 end end
end
return n
end
local KIND_VALUE={Keep=10,Outpost=7,Town=6,Lumbermill=4,Farm=4,Mine=4}
local function StrategyScoreOf(w,t)
local lost=LostCause(w,t)
if lost then return nil end
local score=KIND_VALUE[t.kind] or 4
local guards,lastLock=0,false
if HOME[w.mine][t.keepId] then guards,lastLock=ScrollGuard(w,t.keepId)end
if t.defend then
local held=ScrollsAt(w,t.keepId)
if guards==0 and held==0 and not Flipping(w,t.keepId)then return nil end
score=score+4+guards*8+held*8+(lastLock and 6 or 0)+((guards>0 and HUBS[t.keepId])and 3 or 0)
local enemyLast
for _,a in ipairs({AD,EP,DC})do
if a~=w.mine and LastEmperorKeep(w,a)==t.keepId then enemyLast=true end
end
if enemyLast then score=score+12 end
local isEmp,held=OurThrone(w)
if isEmp and isEmp[t.keepId] and held<=2 and Flipping(w,t.keepId)then score=score+4 end
else
if HOME[w.mine][t.keepId] then score=score+10+guards*6+((guards>0 and lastLock)and 8 or 0)end
if t.keepId==LastEmperorKeep(w,w.mine)then score=score+15 end
if HOME[w.mine][t.keepId] then
local missing=0
for keepId in pairs(HOME[w.mine])do if OwnerOf(w,keepId)~=w.mine then missing=missing+1 end end
if missing==1 then score=score+4 end
end
if t.kind=="Keep" and t.owner and HOME[t.owner] and HOME[t.owner][t.keepId] and HoldsAllHome(w,t.owner)then
score=score+6
end
if Sieges(w,t,w.mine)>0 then score=score+3 end
if t.owner==PushOn(w)then score=score+3 end
score=score+(RaidValues(w)[t.keepId] or 0)
local parent=ParentOf(w,t)
if parent and parent.owner==t.owner then
local held=0
for _,r in ipairs(ResourcesOf(w,parent.keepId))do if r.owner==t.owner then held=held+1 end end
if held==1 then score=score+4 end
end
if parent and parent.owner==w.mine and t.owner~=w.mine then
score=score+3+(ScrollGuard(w,parent.keepId)>0 and 3 or 0)
end
end
local ours,theirs=FightAt(w,t)
if ours>theirs then score=score+3 end
score=score+4*(WinRate(w,t)- 0.5)
return score
end
local function StrategyScore(w,t)
local scores=w._score
if not scores then scores={};w._score=scores end
local score=scores[t]
if score==nil then
score=StrategyScoreOf(w,t)or false
scores[t]=score
end
return score or nil
end
local function StrategyOk(w,t)
if LostCause(w,t)then return false end
if t.defend then
local guards=HOME[w.mine][t.keepId] and ScrollGuard(w,t.keepId)or 0
if guards==0 and ScrollsAt(w,t.keepId)==0 and not Flipping(w,t.keepId)then return false end
end
return true
end
local function IsResource(t)return t.parent~=nil end
local function AnyOf(w,list)
if#list==0 then return nil end
if w.planned then
for _,t in ipairs(list)do if t.keepId==w.planned then return t end end
end
return list[w.Random(1,#list)]
end
local OneOf=LazyCrown.OneOf
local function ScrollDefense(w,reach,list)
local best,bestScore
for _,t in ipairs(list)do
local d=Away(w,t)
if t.defend and HOME[w.mine][t.keepId] and ScrollGuard(w,t.keepId)>0 and not(d and d>reach)then
local score=StrategyScore(w,t)
if score and(not bestScore or score>bestScore)then best,bestScore=t,score end
end
end
return best
end
local function WithUs(displayName)
if not displayName or displayName=="" then return false end
if displayName==Safe(GetUnitDisplayName,"player")then return true end
for i=1,Safe(GetGroupSize)or 0 do
local tag=Safe(GetGroupUnitTagByIndex,i)
if tag and Safe(GetUnitDisplayName,tag)==displayName then return true end
end
return false
end
local function HammerAt(keepId,objectiveId,ctx)
local state=Safe(GetObjectiveControlState,keepId,objectiveId,ctx)
local enabled=not IsObjectiveEnabled or Safe(IsObjectiveEnabled,keepId,objectiveId,ctx)~=false
if not(state and state~=OBJECTIVE_CONTROL_STATE_UNKNOWN and enabled)then return nil end
local holder=Safe(GetCarryableObjectiveHoldingAllianceInfo,keepId,objectiveId,ctx)
local pinType,x,y=Safe(GetObjectivePinInfo,keepId,objectiveId,ctx)
local hammer={holder=(holder and holder~=0)and holder or nil,state=state}
local _,carrier=Safe(GetCarryableObjectiveHoldingCharacterInfo,keepId,objectiveId,ctx)
hammer.withUs=Safe(IsCarryableObjectiveCarriedByLocalPlayer,keepId,objectiveId,ctx)==true or WithUs(carrier)
if pinType~=MAP_PIN_TYPE_INVALID and type(x)=="number" and type(y)=="number" and(x~=0 or y~=0)then
hammer.x,hammer.y=x,y
end
return hammer
end
local function Hammer(w)
if w._hammer~=nil then return w._hammer or nil end
w._hammer=false
if not OBJECTIVE_DAEDRIC_WEAPON then return nil end
local list=w._objectives
if list then
for i=1,list.n do
local hammer=list.kind[i]==OBJECTIVE_DAEDRIC_WEAPON and HammerAt(list.keepId[i],list.objectiveId[i],list.ctx[i])
if hammer then w._hammer=hammer return hammer end
end
return nil
end
list=NoObjectives()
for i=1,Safe(GetNumObjectives)or 0 do
local n=ReadObjective(list,i)
local hammer=n and list.kind[n]==OBJECTIVE_DAEDRIC_WEAPON and HammerAt(list.keepId[n],list.objectiveId[n],list.ctx[n])
if hammer then w._hammer=hammer return hammer end
end
w._objectives=list
return nil
end
local function ScrollKeepUnderAttack(w)
for keepId in pairs(HOME[w.mine] or{})do
if OwnerOf(w,keepId)==w.mine and w.UnderAttack(keepId)and ScrollGuard(w,keepId)>0 then return true end
end
for _,a in ipairs({AD,EP,DC})do
for _,spot in ipairs(Scrolls(w,a))do
local k=spot.heldAt
if k and k~=0 and OwnerOf(w,k)==w.mine and w.UnderAttack(k)then return true end
end
end
return false
end
local function ThroneAtRisk(w)
for _,k in ipairs(GuardingThrone(w)or{})do
if w.UnderAttack(k.keepId)and Flipping(w,k.keepId)then return true end
end
return false
end
local function FollowHammer(w,rule)
local hammer=Hammer(w)
if not(hammer and hammer.x)or hammer.withUs then return nil end
if rule~="always" and hammer.holder~=w.mine then return nil end
if rule=="safe" and(ScrollKeepUnderAttack(w)or ThroneAtRisk(w))then return nil end
local near=Nearest(hammer,Filter(w.targets,function(t)return w.Allied(t.owner)and(not w.KindOn or w.KindOn(t.kind))end))
if not near then return nil end
local pick={}
for k,v in pairs(near)do pick[k]=v end
pick.directive="follow the hammer to " .. near.name
pick.unscored=true
return{pick=pick}
end
local function GuardThrone(w,stayClose)
local throne=Throne(w)
if not throne then return nil end
local isEmp,held=throne.isEmp,throne.held
local few=#held<=2
local flags=Flags(w)
local defenses=Filter(w.options,function(t)return t.defend and isEmp[t.keepId] end)
if#defenses>0 then
return TopPick(w,defenses,function(t)
local f=flags[t.keepId]
local d=Away(w,t)
return 10+(f and(f.lost*4+f.moving*2)or 0)-(d and 10*d or 0)
end,few and 1 or 2,6)
end
if not(stayClose and few)or#held==0 then return nil end
return TopPick(w,w.options,function(t)
if t.defend then return nil end
local closest=FromClosest(held,t)
return closest and -closest
end,3,0.05)
end
local LazyPick
local SAME_AS_LAST="Same as last time. Oh wait we own that. Darn, looks like I get to take a break."
P.lazy=function(w)
if w.justSettled=="W" and not w.planning and w.Random(1,6)==1 then return{say=SAME_AS_LAST}end
return LazyPick(w,true)
end
local NOTHING_CLOSE="Nothing close. Wake me up later."
local KEEPS_ARE_EFFORT="Keeps are effort. If %s won't move why should I?"
local SHORT_NAME={[AD]="AD",[EP]="EP",[DC]="DC"}
local function Laziest(w)
if not w.player then return nil end
local push=PushOn(w)
local flags=Flags(w)
local scored={}
local function score(t)
if scored[t]~=nil then return scored[t] or nil end
scored[t]=false
local d=Away(w,t)
if not d or d>NEAR or LostCause(w,t)or(LosingFight(w,t)and not ThreeWay(w,t))then return nil end
local f=flags[t.keepId]
local action=math.min(FightNear(w,t),20)*0.003
if f and(f.moving>0 or f.lost>0)then action=action+0.03 end
if Sieges(w,t,w.mine)>0 then action=action+0.02 end
scored[t]=-d+action+(t.owner==push and 0.02 or 0)
return scored[t]
end
local function worthIt(t)
if t.kind~="Keep" then return true end
local d=Dist(w.player,t)
local f=flags[t.keepId]
return(d and d<=CLOSE)or FightNear(w,t)>=5 or(f~=nil and(f.moving>0 or f.lost>0))
end
local best=TopPick(w,w.options,score,1)
if not best then return not w.planning and{say=NOTHING_CLOSE}or nil end
local effort=string.format(KEEPS_ARE_EFFORT,SHORT_NAME[w.mine] or "AD")
local pick=TopPick(w,Filter(w.options,worthIt),score,3,0.04)
if not pick then return not w.planning and{say=effort}or nil end
local plan={pick=pick}
if not worthIt(best)then plan.extras={effort}end
return plan
end
local function Nearby(w,list)
for _,reach in ipairs({AREA,2*AREA})do
local near=Filter(list,function(t)
local d=Away(w,t)
return d==nil or d<=reach
end)
if#near>0 then return near end
end
return list
end
local function InTheWay(w,t)
local leg=w.Route and w.Route(t)
local start=(leg and leg.from)or w.player
local d=Dist(start,t)
if not d then return false end
for _,b in ipairs(w.targets)do
if b~=t and not b.parent and b.keepId~=t.parent and b.owner and b.owner~=w.mine then
local a,c=Dist(start,b),Dist(b,t)
if a and c and a>0.02 and a+c - d<=IN_THE_WAY then return true end
end
end
return false
end
function LazyPick(w,choosy)
if not w.player then return nil end
local ballGroup=BallGroup(w)
local easy=Filter(w.options,function(t)
return not LostCause(w,t)and not(t.kind=="Keep" and IntoTheBall(w,t,ballGroup))
end)
if Gated(w)then
local soft=Filter(easy,function(t)return t.kind~="Keep" end)
if#soft>0 then easy=soft end
end
if choosy then
local others=Filter(easy,function(t)return t.kind~="Town" or t.defend end)
local function payoff(town)
local d=Away(w,town)
if not d then return true end
local nearest
for _,t in ipairs(others)do
local dt=Away(w,t)
if dt and(not nearest or dt<nearest)then nearest=dt end
if dt and dt<=AREA and not t.defend and(t.kind=="Keep" or t.kind=="Outpost")then
local via=Dist(town,t)
if via and d+via - dt<=NEAR then return true end
end
end
return nearest==nil or(nearest>=2*d and nearest - d>=CLOSE)
end
local paid=Filter(easy,function(t)return t.kind~="Town" or t.defend or payoff(t)end)
if#paid>0 then easy=paid end
end
local here=TopPick(w,easy,function(t)
local parent=ParentOf(w,t)
local d=Away(w,t)
if parent and parent.owner==w.mine and not t.defend and d and d<=CLOSE then return -d end
end,1)
if here then return{pick=here}end
local function closeness(t)
local d=Away(w,t)
return d and -d or 0
end
local near=Filter(easy,function(t)
local d=Away(w,t)
return d==nil or d<=AREA
end)
if#near==0 then
local closest=TopPick(w,easy,closeness,3,0.05)
return closest and{pick=closest}
end
local ring=Filter(near,function(t)return not InTheWay(w,t)end)
if#ring>0 then near=ring end
local sample=OneOf(w,near)
if not sample then return nil end
local kind=LazyCrown.TypeOf(sample)
local same=Filter(near,function(t)return LazyCrown.TypeOf(t)==kind and not t.defend==not sample.defend end)
local push=PushOn(w)
local pick=TopPick(w,same,function(t)return closeness(t)+(t.owner==push and 0.02 or 0)end,3,0.1)
return pick and{pick=pick}
end
P.LazyPick=function(w)return LazyPick(w)end
local POTATO_WAIT={"Imma smoke real quick while we wait.","I'm hungry, let me find a snack. Brb."}
P.bakedpotato=function(w)
if not w.player then return nil end
local fair=Filter(w.options,function(t)return not LostCause(w,t)end)
local options=ThroneSide(w,fair)
for _,t in ipairs(fair)do
local d=Dist(w.player,t)
if t.defend and d and d<=CLOSE then
local plan={pick=t}
if not Flipping(w,t.keepId)then plan.extras={POTATO_WAIT[w.Random(1,#POTATO_WAIT)]}end
return plan
end
end
local last=w.justSettled=="W" and w.lastCall and w.lastCall.result=="W" and w.byId[w.lastCall.keepId]
if last and last.parent then
for _,t in ipairs(options)do
local d=Away(w,t)
if t.keepId==last.parent and not t.defend and(not d or d<=NEAR)then return{pick=t}end
end
end
local function ready(t)
if t.kind~="Keep" or t.defend then return true end
local resources=ResourcesOf(w,t.keepId)
for _,r in ipairs(resources)do if r.owner==w.mine then return true end end
return#resources==0
end
local wanted={}
for _,k in ipairs(options)do
if k.kind=="Keep" and not k.defend and not ready(k)then
local r=WantedResource(w,k,options,"door")
if r then wanted[r]=true end
end
end
local home=TopPick(w,options,function(t)
local d=Away(w,t)
local ours=HOME[w.mine][t.keepId] or(t.parent and HOME[w.mine][t.parent])
if ours and not t.defend and ready(t)and d and d<=NEAR then return -d+(wanted[t] and 0.03 or 0)end
end,2,0.015)
if home then return{pick=home}end
local push=PushOn(w)
local function closeness(t)
local d=Away(w,t)
return(d and -d or 0)+(t.kind=="Outpost" and 0.03 or 0)+(t.owner==push and 0.005 or 0)+(wanted[t] and 0.03 or 0)
end
local pick=TopPick(w,options,function(t)
local d=Away(w,t)
if ready(t)and(not d or d<=NEAR)then return closeness(t)end
end,3,0.02)
pick=pick or TopPick(w,options,function(t)return ready(t)and closeness(t)or nil end,1)
return pick and{pick=pick}or Laziest(w)
end
local function OnTheWay(w,target,rule)
local resources=Filter(w.options,function(t)
local d=Away(w,t)
return IsResource(t)and not t.defend and not LostCause(w,t)and(d==nil or d<=AREA)
end)
local toTarget=Away(w,target)or 0
if target.kind=="Keep" and target.owner~=w.mine then
local own=Filter(resources,function(r)
return r.parent==target.keepId and(Away(w,r)or 0)+(Dist(r,target)or 0)- toTarget<=NEAR
end)
if#own>0 then
local want=WantedResource(w,target,own,WayIn(w,target,rule,true))
if want then return want end
end
end
local best,bestDetour
for _,r in ipairs(resources)do
local detour=(Away(w,r)or 0)+(Dist(r,target)or 0)- toTarget -(r.parent==target.keepId and 0.02 or 0)
if not bestDetour or detour<bestDetour then best,bestDetour=r,detour end
end
if best and bestDetour<=NEAR then return best end
return nil
end
local function Heat(w,t,flags)
local f=flags[t.keepId]
local heat=f and(f.moving*3+f.lost*2)or 0
if w.UnderAttack(t.keepId)then heat=heat+2 end
heat=heat+math.min(2*Sieges(w,t,w.mine),8)
return heat
end
local function Strategist(w,style)
local options=w.options
if style.careful then options=Filter(options,function(t)return not LosingFight(w,t)end)end
if style.dtick then
local isEmp,held=OurThrone(w)
if isEmp and held<=2 then
local defense=TopPick(w,Filter(options,function(t)return t.defend and isEmp[t.keepId] and Flipping(w,t.keepId)end),function(t)
local d=Away(w,t)
return 10 -(d and 10*d or 0)
end,1)
if defense then return{pick=defense}end
end
end
local guard=ScrollDefense(w,AREA,options)
if guard then return{pick=guard}end
local memory=w.memory or{}
local planned=memory.chrisNext
if planned and w.lastCall and w.lastCall.keepId==planned.after then
memory.chrisNext=nil
if w.lastCall.result=="W" then
for _,t in ipairs(options)do
if t.keepId==planned.keepId and not t.defend and StrategyScore(w,t)then return{pick=t}end
end
end
end
local candidates=Filter(options,function(t)
if not StrategyOk(w,t)then return false end
local d=Away(w,t)
return not(style.careful and IsResource(t)and d and d>NEAR)
end)
candidates=ThroneSide(w,candidates)
local dethrone
local throne=ThroneKeep(w)
if throne and HoldsAllHome(w,w.mine)then
local home=true
for _,spot in ipairs(Scrolls(w,w.mine))do if not spot.home then home=false end end
for _,t in ipairs(home and candidates or{})do
local leg=t.keepId==throne and not t.defend and w.Route and w.Route(t)
if leg and leg.line then dethrone=t end
end
end
local pool,distWeight=nil,style.dist
local lostAt=w.lastCall and w.lastCall.result=="L" and w.byId[w.lastCall.keepId]
if lostAt and lostAt.x then
local elsewhere=Filter(candidates,function(t)
local d=Dist(lostAt,t)
return not d or d>LEAVE_AFTER_L
end)
if#elsewhere==0 then elsewhere=candidates end
pool=Filter(elsewhere,function(t)
local d=Away(w,t)
return d==nil or d<=2*AREA
end)
if#pool==0 then pool=elsewhere end
distWeight=style.dist/2
else
pool=Nearby(w,candidates)
end
local pushInto
if lostAt and(HOME[w.mine][lostAt.keepId] or(lostAt.parent and HOME[w.mine][lostAt.parent]))then
pushInto=w.lastCall.against
end
local ballGroup=style.careful and BallGroup(w)
if ballGroup then
pushInto=pushInto or ballGroup
local avoided=Filter(pool,function(t)return not IntoTheBall(w,t,ballGroup)end)
if#avoided>0 then pool=avoided end
local listed={}
for _,t in ipairs(pool)do listed[t]=true end
for _,t in ipairs(candidates)do
local d=Away(w,t)
if not listed[t] and Territory(t,ballGroup)and(d==nil or d<=PUSH_REACH)then
if pool==candidates then pool={unpack(pool)}end
table.insert(pool,t)
end
end
end
local viaGate={}
if Gated(w)then
local sides={}
for _,gate in ipairs(SCROLLS[w.mine])do sides[gate.side]=true end
if lostAt and sides[lostAt.parent or lostAt.keepId] then
local soft=Filter(candidates,function(t)
local d=Away(w,t)
return(t.kind=="Town" or FLANKS[t.keepId])and(d==nil or d<=2*AREA)
end)
if#soft>0 then pool=soft end
else
viaGate=sides
local listed={}
for _,t in ipairs(pool)do listed[t]=true end
for _,t in ipairs(candidates)do
if viaGate[t.keepId] and not t.defend and not listed[t] then
if pool==candidates then pool={unpack(pool)}end
table.insert(pool,t)
end
end
end
end
if dethrone then
local listed=false
for _,t in ipairs(pool)do if t==dethrone then listed=true end end
if not listed then pool={unpack(pool)};table.insert(pool,dethrone)end
end
local flags=style.greedy and Flags(w)
local pick=TopPick(w,pool,function(t)
local score=StrategyScore(w,t)
if t==dethrone then score=score+15 end
if pushInto and Territory(t,pushInto)and not t.defend then score=score+6 end
if flags then score=score+Heat(w,t,flags)end
local d=Away(w,t)
local hop=style.gateHop or GATE_HOP
if viaGate[t.keepId] then d=math.min(d or hop,hop)end
return score -(d and distWeight*d or 0)
end,style.n,10)
if not pick then return nil end
if viaGate[pick.keepId] and not pick.defend then
local leg=w.Route and w.Route(pick)
if not(leg and leg.recall)then return{pick=pick,how="Stone down to the gate."}end
return{pick=pick}
end
local left,owned=ContinuousAttack(w)
if not pick.defend and not IsResource(pick)and owned and left<CA_LOW then
local leg=OnTheWay(w,pick,"nine")
if leg then
memory.chrisNext={keepId=pick.keepId,after=leg.keepId}
return{pick=leg}
end
end
return{pick=pick}
end
local function SiegeLine(w,plan,trebs)
local leg=plan.pick
if leg.kind~="Keep" or leg.defend then return nil end
if leg.directive then return "20/20 siege." end
if WayIn(w,leg,"nine")=="wall" then
local line="20/20 siege, look for a weak wall"
if trebs and w.Random(1,2)==1 then line=line .. " and I wanna see a few Trebs" end
return line .. "."
end
return "20/20 siege, front door."
end
local TROLLED={}
for _,call in ipairs(TROLL_CALLS)do TROLLED[call.keepId]=true end
local function Trolls(w,options,spotsOnly)
local list,byKeep={},{}
for _,t in ipairs(options or w.options)do
if TROLLED[t.keepId] then
byKeep[t.keepId]=byKeep[t.keepId] or{}
table.insert(byKeep[t.keepId],t)
end
end
for _,call in ipairs(TROLL_CALLS)do
for _,t in ipairs(byKeep[call.keepId] or{})do
if not t.defend and not t.directive and(call.spot or not spotsOnly)then
local directed={}
for k,v in pairs(t)do directed[k]=v end
directed.directive=call.directive
table.insert(list,directed)
end
end
end
return list
end
local SCROLL_ASK="Anyone want to run the scroll? Grab the scroll quests too."
local function ScrollAsk(w,plan)
if plan.pick and not plan.pick.defend and OurScrollIn(w,plan.pick.keepId)and w.Random(1,4)==1 then
plan.extras=plan.extras or{}
table.insert(plan.extras,SCROLL_ASK)
plan.quietTarget=true
end
end
local function PlainSpot(directive)
local keep,from=directive:match("^troll (.+) by sieging from (.+)$")
if keep then return string.format("hit %s and siege from %s",keep,from)end
return directive:match("^be annoying and (take .+)$")or directive
end
P.chris=function(w)
local plan=Strategist(w,{n=3,dist=25})
if not plan then return nil end
local pick=plan.pick
if(w.streakL or 0)>=SIEGE_SPOT_STREAK and pick.kind=="Keep" and not pick.defend then
local ways=Trolls(w,{pick},true)
if#ways>0 and w.Random(1,2)==1 then
plan.pick=ways[w.Random(1,#ways)]
plan.pick.directive=PlainSpot(plan.pick.directive)
end
end
plan.extras={SiegeLine(w,plan,true)}
ScrollAsk(w,plan)
return plan
end
local FREE_RIDE="If we die, we get up at the gate for a free ride %s."
local RIDE_HOME={[AD]="south",[EP]="east",[DC]="west"}
P.confessor=function(w)
if Gated(w)and not w.planning and w.Random(1,3)==1 then
local fight=TopPick(w,w.options,function(t)
local d=Away(w,t)
local total=FightNear(w,t)
if d and d<=NEAR and total>=10 then return total end
end,1)
if fight then return{pick=fight,extras={string.format(FREE_RIDE,RIDE_HOME[w.mine] or "south")}}end
end
local plan=Strategist(w,{n=2,dist=40,greedy=true,careful=true,dtick=true,gateHop=2*GATE_HOP})
if plan then
ScrollAsk(w,plan)
return plan
end
local pick=TopPick(w,w.options,function(t)
if LostCause(w,t)then return nil end
local d=Away(w,t)
return d and -d or 0
end,1)or TopPick(w,w.options,function(t)
local ours,theirs=FightAt(w,t)
return ours - theirs
end,1)
return pick and{pick=pick}
end
local QuestTargets
local GREEDY_SIEGE=10
local RISK="Some of you may die, but that is a risk I am willing to take."
local function GreedyPick(w)
local guard=GuardThrone(w,true)
if guard then return{pick=guard}end
local throne=ThroneKeep(w)
local hammer=FollowHammer(w,"always")
if hammer then return hammer end
local flags=Flags(w)
local haveFlags=next(flags)~=nil
local ruledOut={}
local pick=TopPick(w,w.options,function(t)
local f=flags[t.keepId]
local ours,theirs=FightAt(w,t)
local d=Away(w,t)
if t.defend then
local flipping=f and(f.moving>0 or f.lost>0)
local skip=(haveFlags and not flipping)
or theirs>=LOST_CAUSE or theirs>ours
or(f and f.total>1 and f.lost>=f.total - 1 and not(d and d<=CLOSE))
or(f and f.lost==0 and f.moving>=1 and not(d and d<=NEAR))
if skip then ruledOut[t]=true return nil end
return 6+(f and f.moving or 0)*6+(f and f.lost or 0)*4+(f and f.back and 15 or 0)+ours -(d and 20*d or 0)
end
if LosingFight(w,t)and not ThreeWay(w,t)then ruledOut[t]=true return nil end
local hot=(f and f.moving or 0)*6+(f and f.lost or 0)*4+(f and f.back and 15 or 0)
if w.UnderAttack(t.keepId)then hot=hot+4 end
local total=FightNear(w,t)
if total>0 then hot=hot+math.min(total,20)/2 end
local siege=Sieges(w,t,w.mine)
if siege>=GREEDY_SIEGE then hot=hot+12 elseif hot>0 then hot=hot+siege end
if t.keepId==throne and total>=5 and not LostCause(w,t)then hot=math.max(hot,12)end
if hot==0 then return nil end
local capturing=f and(f.moving>0 or f.lost>0)
if(IsResource(t)or capturing)and d and d>(IsResource(t)and CLOSE or NEAR)then
ruledOut[t]=true
return nil
end
return hot+ours -(d and 20*d or 0)
end,3,8)
if not pick then
local onQuest={}
for _,t in ipairs((QuestTargets(w)))do onQuest[t]=true end
local rest=Filter(w.options,function(t)
if ruledOut[t] or LostCause(w,t)or(LosingFight(w,t)and not ThreeWay(w,t))then return false end
if t.keepId==throne and not t.defend then return false end
if not IsResource(t)or onQuest[t] then return true end
local d=Away(w,t)
return d~=nil and d<=CLOSE
end)
if#rest==0 then return nil end
local throneKeep=throne and w.byId[throne]
pick=TopPick(w,rest,function(t)
local d=Away(w,t)
local staging=throneKeep and Dist(throneKeep,t)and Dist(throneKeep,t)<=NEAR and t.keepId~=throne
return(d and -d or 0)+(staging and 0.03 or 0)
end,3,0.05)
end
return{pick=pick}
end
P.greedy=function(w)
local plan=GreedyPick(w)
local pick=plan and plan.pick
if not pick or pick.unscored then return plan end
local extras={}
if Gated(w)and FightNear(w,pick)>=BIG_FIGHT then
for _,gate in ipairs(SCROLLS[w.mine])do
local keep=w.byId[gate.side]
if keep and keep.owner~=w.mine and Sieges(w,keep,w.mine)>=GREEDY_SIEGE then
table.insert(extras,string.format("If we die, we get up at the gate for a free ride to %s. Our siege is already there.",keep.name))
break
end
end
end
local f=Flags(w)[pick.keepId]
local flipping=(pick.kind=="Keep" or pick.kind=="Outpost")and f and(f.moving>0 or f.lost>0)
if(pick.defend and pick.kind=="Keep")or LosingFight(w,pick)or flipping then table.insert(extras,RISK)end
local going=f and(f.moving>0 or f.lost>0)
local nearlyDone=going and(f.back or f.total<=1 or f.lost>=f.total - 1)
if nearlyDone or(IsResource(pick)and w.UnderAttack(pick.keepId))then plan.grenade=true end
if#extras>0 then
plan.extras=plan.extras or{}
for _,line in ipairs(extras)do table.insert(plan.extras,line)end
end
return plan
end
local QUEST_PARTS={[1]=RESOURCETYPE_WOOD or 1,[2]=RESOURCETYPE_FOOD or 2,[3]=RESOURCETYPE_ORE or 3}
function QuestTargets(w)
local quests=LazyCrown.QUESTS
if not(quests and IsValidQuestIndex and GetJournalQuestId)then return{}end
local journal=w._journal
if journal then
return Filter(w.options,function(t)return journal.byKeep[t.keepId] and not t.defend end)
end
local byKeep={}
for i=1,MAX_JOURNAL_QUESTS or 25 do
if Safe(IsValidQuestIndex,i)and not Safe(GetJournalQuestIsComplete,i)then
local questId=Safe(GetJournalQuestId,i)
local code=quests.capture[questId] or quests.scout[questId]
if code then
local keepId,part=math.floor(code/10),code%10
local targetId=keepId
if part>0 then targetId=Safe(GetResourceKeepForKeep,keepId,QUEST_PARTS[part])end
if targetId then byKeep[targetId]=true end
end
end
end
w._journal={byKeep=byKeep}
return Filter(w.options,function(t)return byKeep[t.keepId] and not t.defend end)
end
local STAY_CLOSE=0.25
local NEXT_TO=0.15
P.deano=function(w)
local function troll(t)
local ways=Territory(t,w.mine)and{}or Trolls(w,{t})
if#ways>0 and w.Random(1,2)==1 then return ways[w.Random(1,#ways)] end
return t
end
local fair=Filter(w.options,function(t)return not t.defend and not LostCause(w,t)end)
local trolls=Filter(Trolls(w,fair),function(t)return not Territory(t,w.mine)end)
local push=PushOn(w)
local function grudgeOf(alliance)
local keepId=GRUDGE_KEEPS[alliance]
local list=Filter(fair,function(t)return t.keepId==keepId end)
for _,t in ipairs(trolls)do if t.keepId==keepId then table.insert(list,t)end end
return list
end
local held=GuardingThrone(w)
if held then
local function fromThrone(t)return FromClosest(held,t)end
local pool=Filter(fair,function(t)
local d=fromThrone(t)
return(t.kind=="Town" or t.kind=="Outpost")and Territory(t,w.mine)and d and d<=STAY_CLOSE
end)
local holder
for keepId in pairs((OurThrone(w)))do
local owner=OwnerOf(w,keepId)
if owner and owner~=w.mine then
if holder==nil then holder=owner elseif holder~=owner then holder=false end
end
end
if holder then
for _,t in ipairs(trolls)do if t.owner==holder and HOME[holder][t.keepId] then table.insert(pool,t)end end
end
local pick=TopPick(w,pool,function(t)
if t.directive then return 1.5 end
return(t.kind=="Town" and 3 or 2)- 10*(fromThrone(t)or 0)
end,3,2)
if pick then return{pick=pick}end
local resource=TopPick(w,ThroneSide(w,Filter(fair,IsResource)),function(t)
local d=fromThrone(t)
return d and d<=STAY_CLOSE and -d or nil
end,1)
if resource then return{pick=resource}end
end
local wing=WingYoureIn(w)
if Gated(w)then
if wing then
local edge=Filter(fair,function(t)return t.keepId==wing.town or t.keepId==wing.outpost end)
local pick=TopPick(w,edge,function(t)
local d=Away(w,t)
return d and -d or 0
end,2,0.05)
if pick then return{pick=pick}end
local keep=w.byId[wing.keep]
local grudge=push and grudgeOf(push)or{}
if keep and keep.owner~=w.mine and(#grudge==0 or keep.owner==push)then
for _,t in ipairs(fair)do if t.keepId==wing.keep then return{pick=troll(t)}end end
elseif keep and keep.owner~=w.mine and w.Random(1,2)==2 then
local wingRes=Filter(fair,function(t)return t.parent==wing.keep end)
local resource=WantedResource(w,keep,Filter(wingRes,function(t)
local d=Dist(w.player,t)
return d and d<=NEAR
end),"door")or Nearest(w.player,wingRes,NEAR)
if resource then return{pick=resource}end
end
if#grudge>0 then return{pick=AnyOf(w,grudge)}end
end
end
local emperor=EmperorAlliance(w)
if emperor and emperor~=w.mine and not Gated(w)then
local grudgeKeep=w.byId[GRUDGE_KEEPS[emperor]]
local pool=grudgeOf(emperor)
for _,t in ipairs(trolls)do
local d=Dist(grudgeKeep,t)
if t.owner==emperor and t.keepId~=GRUDGE_KEEPS[emperor] and d and d<=NEXT_TO then table.insert(pool,t)end
end
if#pool>0 then
for _,t in ipairs(fair)do if FLANKS[t.keepId] then table.insert(pool,t)end end
local pick=TopPick(w,pool,function(t)
if t.keepId==GRUDGE_KEEPS[emperor] and not t.directive then return 10 end
if t.directive then return 8 end
local d=Away(w,t)
return 8 -(d and 5*d or 0)
end,4,4)
if pick then return{pick=pick}end
end
end
if not held and wing and OwnerOf(w,wing.town)==w.mine and OwnerOf(w,wing.outpost)==w.mine then
for _,t in ipairs(fair)do if t.keepId==wing.keep then return{pick=troll(t)}end end
end
local pool=Filter(fair,function(t)return FLANKS[t.keepId] end)
local onQuest={}
for _,t in ipairs((QuestTargets(w)))do
if IsResource(t)then table.insert(pool,t);onQuest[t.keepId]=true end
end
local left,owned=ContinuousAttack(w)
if owned and left<CA_LOW then
local resource=Nearest(w.player or{},Filter(fair,IsResource))
if resource then table.insert(pool,resource)end
end
if held then pool=Filter(ThroneSide(w,pool),function(t)return t.kind~="Keep" end)end
local pick=TopPick(w,pool,function(t)
local d=Away(w,t)
local life=w.lifetime and w.lifetime[tostring(t.keepId)]
local grudge=life and life.l or 0
return 5+math.min(grudge,3)*2+(onQuest[t.keepId] and 15 or 0)+(t.owner==push and 2 or 0)-(d and 5*d or 0)
end,4,4)
return pick and{pick=pick}
end
local BEHIND=0.15
local BEHIND_DETOUR=0.05
local function DiilSiege(w,pick)
if pick.defend or(pick.kind~="Keep" and pick.kind~="Outpost")then return nil end
if pick.directive then return "20/20 siege." end
if WayIn(w,pick,"any")=="wall" then return "20/20 siege, look for a weak wall." end
return "20/20 siege, front door."
end
P.diil=function(w)
local function finish(pick)
local ways=Territory(pick,w.mine)and{}or Trolls(w,{pick})
if#ways>0 then pick=ways[w.Random(1,#ways)] end
local plan={pick=pick}
plan.extras={DiilSiege(w,pick)}
return plan
end
local throne=GuardThrone(w)
if throne then return finish(throne)end
local hammer=FollowHammer(w,"safe")
if hammer then return hammer end
local from=w.player or(w.lastCall and w.byId[w.lastCall.keepId])
local push=MoreBars(w)or Oppressor(w,true)
local bold=Filter(w.options,function(t)return(t.kind=="Keep" or t.kind=="Outpost")and not t.defend end)
local function behind(t,origin)
origin=origin or from
local dt=Dist(origin,t)
return Filter(bold,function(b)
local d,db=Dist(t,b),Dist(origin,b)
return b~=t and b.owner==t.owner and d and d<=BEHIND and dt and db and dt+d - db<=BEHIND_DETOUR
end)
end
local held=GuardingThrone(w)
if held then
local isEmp=OurThrone(w)
local empKeeps=Filter(bold,function(t)return isEmp[t.keepId] end)
local theirs=Filter(empKeeps,function(t)return t.owner==push end)
if#theirs==0 then theirs=empKeeps end
local target=TopPick(w,theirs,function(t)
local d=FromClosest(held,t)
return d and -d or 0
end,1)
local base
for _,k in ipairs(held)do
if not base or(Dist(k,target or k)or math.huge)<(Dist(base,target or base)or math.huge)then base=k end
end
if target then
local first=TopPick(w,behind(target,base),function(b)
local d=Dist(target,b)
return d and -d or 0
end,1)
return finish(first or target)
end
end
local ours=Filter(w.everything or w.options,function(t)return t.kind=="Keep" and not t.defend and OurScrollIn(w,t.keepId)end)
local pushed=Filter(ours,function(t)return t.owner==push end)
if#pushed>0 then ours=pushed end
local scroll=TopPick(w,ours,function(t)
local d=Dist(from,t)
return 10+(d and 10*d or 0)
end,2,5)
if scroll then return finish(scroll)end
local raids=RaidValues(w)
local emperor=EmperorAlliance(w)
local enemyThrone,enemyHeld={},0
if emperor and emperor~=w.mine then
for _,keepId in ipairs(EmperorKeeps(w,emperor))do
enemyThrone[keepId]=true
if OwnerOf(w,keepId)==emperor then enemyHeld=enemyHeld+1 end
end
end
local throneValue=enemyHeld<=2 and 20 or 10
local ourLast=LastEmperorKeep(w,w.mine)
local closest=TopPick(w,bold,function(t)
local d=Dist(from,t)
return d and -d or nil
end,1)
local pool=#bold>1 and Filter(bold,function(t)return t~=closest end)or bold
local isBehind={}
for _,a in ipairs({AD,EP,DC})do
if a~=w.mine then
local front=TopPick(w,Filter(bold,function(t)return t.owner==a end),function(t)
local d=Dist(from,t)
return d and -d or nil
end,1)
if front then for _,b in ipairs(behind(front))do isBehind[b]=true end end
end
end
local pick=TopPick(w,pool,function(t)
local score=(raids[t.keepId] or 0)*2
if enemyThrone[t.keepId] and t.owner==emperor then score=score+throneValue end
if t.keepId==ourLast then score=score+20 end
if HOME[t.owner] and HOME[t.owner][t.keepId] and HoldsAllHome(w,t.owner)then score=score+10 end
if t.owner==push then score=score+10 end
if isBehind[t] then score=score+8 end
if t.kind=="Outpost" then score=score - 4 end
local d=Dist(from,t)
return score+(d and 10*d or 0)
end,3,12)
if not pick then return nil end
return finish(pick)
end
local NORTH_SET={[WINGS.north.town]=true,[WINGS.north.outpost]=true,[WINGS.north.keep]=true}
local function Culprit(w)
local best,most=nil,0
local latest=w.lastCall and w.lastCall.against
for key,n in pairs(w.streakBy or{})do
local alliance=tonumber(key)
if n>most or(n==most and alliance==latest)then best,most=alliance,n end
end
return best or latest
end
local function WingTargets(w,wing)
local set={[wing.keep]=true,[wing.town]=true,[wing.outpost]=true}
return Filter(w.options,function(t)return set[t.keepId] or(t.parent==wing.keep)end)
end
local function NearTroll(w,trolls)
local from=not w.player and w.lastCall and w.byId[w.lastCall.keepId]
local function away(t)return Away(w,t)or(from and Dist(from,t))end
if not(w.player or from)then return OneOf(w,trolls)end
local near=Filter(trolls,function(t)
local d=away(t)
return d and d<=AREA
end)
if#near>0 then return OneOf(w,near)end
return TopPick(w,trolls,function(t)
local d=away(t)
return d and -d or nil
end,3,0.05)
end
local function NovemberFlanks(w)
local opp=Oppressor(w)
local fair=Filter(w.options,function(t)return not t.defend and not LostCause(w,t)end)
local function open(keepId)for _,t in ipairs(fair)do if t.keepId==keepId then return t end end end
local function within(t,reach)
local d=Away(w,t)
return d==nil or d<=reach
end
local wing=w.player and WingYoureIn(w)
local last=wing and w.lastCall and w.lastCall.result=="L" and w.byId[w.lastCall.keepId]
local lostHere=last and InWing(wing,last)
if wing then
if lostHere then
local towns={}
for _,other in pairs(WINGS)do
local t=other~=wing and open(other.town)
if t and t.owner==opp then table.insert(towns,t)end
end
local town=TopPick(w,towns,function(t)
local d=Away(w,t)
return d and -d or 0
end,1)
if town then return town end
end
local town=open(wing.town)
if not lostHere and town and within(town,AREA)then return town end
local keepSpot=w.byId[wing.keep]
local townOurs=OwnerOf(w,wing.town)==w.mine
if not lostHere and townOurs and((keepSpot and keepSpot.owner==opp)or Gated(w))then
local outpost=open(wing.outpost)
if outpost and within(outpost,2*AREA)then
local pool={outpost,outpost,outpost,outpost}
local wingRes=Filter(fair,function(t)return t.parent==wing.keep end)
local resource=WantedResource(w,keepSpot,Filter(wingRes,function(t)
local d=Dist(outpost,t)
return d and d<=NEAR
end),"door")or Nearest(outpost,wingRes,NEAR)
if resource then table.insert(pool,resource)end
local townSpot=w.byId[wing.town]
for _,t in ipairs(fair)do
local d=Dist(townSpot,t)
if t.kind=="Outpost" and t~=outpost and t.owner==opp and d and d<=AREA then table.insert(pool,t)end
end
return AnyOf(w,pool)
end
local keep=open(wing.keep)
if keep and within(keep,2*AREA)then
local pool={keep,keep}
local wingRes=Filter(fair,function(t)return t.parent==wing.keep end)
local resource=WantedResource(w,keep,wingRes,"door")or Nearest(w.player or keep,wingRes)
if resource then table.insert(pool,resource)end
local townSpot,outSpot=w.byId[wing.town],w.byId[wing.outpost]
for _,t in ipairs(fair)do
local a,b,c=Dist(townSpot,outSpot),Dist(outSpot,t),Dist(townSpot,t)
if t.kind=="Keep" and t.keepId~=wing.keep and t.owner==opp and a and b and c and b<=AREA and a+b - c<=BEHIND_DETOUR then
table.insert(pool,t)
end
end
return AnyOf(w,pool)
end
end
end
local guarding=GuardingThrone(w)
local pool={}
for _,t in ipairs(fair)do
if t.owner==opp and(t.kind=="Outpost" or(t.kind=="Keep" and HOME[opp][t.keepId]))then table.insert(pool,t)end
end
for _,t in ipairs(Trolls(w,fair))do if t.owner==opp then table.insert(pool,t)end end
pool=Filter(pool,function(t)
return within(t,2*AREA)and not(guarding and BackKeep(w.mine,t.keepId))and not(lostHere and InWing(wing,t))
end)
return TopPick(w,pool,function(t)
local d=Away(w,t)
return(t.directive and 2.5 or t.kind=="Outpost" and 2 or 1)-(d and 10*d or 0)
end,3,2)
end
P.november=function(w)
local losses=w.streakL or 0
if losses>=6 then
local lastLoss=w.lastCall and w.lastCall.result=="L" and w.lastCall.keepId
local culprit=losses>=7 and Culprit(w)
if culprit and GRUDGE_KEEPS[culprit] then
local list=Filter(w.everything or w.options,function(t)return t.keepId==GRUDGE_KEEPS[culprit] end)
for _,t in ipairs(Trolls(w,list))do table.insert(list,t)end
if#list>0 then return{pick=OneOf(w,list)}end
elseif not(lastLoss and NORTH_SET[lastLoss])then
local north=Filter(w.options,function(t)return NORTH_SET[t.keepId] end)
if#north>0 then return{pick=OneOf(w,north)}end
end
local from=(lastLoss and w.byId[lastLoss])or w.player
local against=lastLoss and w.lastCall.against
local theirs=Filter(Trolls(w),function(t)return against and t.owner==against end)
local far=Filter(theirs,function(t)
local d=Dist(from,t)
return not d or d>=OTHER_SIDE
end)
if#far>0 then return{pick=OneOf(w,far)}end
local farthest=TopPick(w,theirs,function(t)return Dist(from,t)or 0 end,2,0.1)
if farthest then return{pick=farthest}end
local close=NearTroll(w,Trolls(w))
if close then return{pick=close}end
elseif losses>=3 then
local close=NearTroll(w,Trolls(w))
if close then return{pick=close}end
end
local flank=NovemberFlanks(w)
if flank then return{pick=flank}end
local list={}
for _,wing in pairs(WINGS)do for _,t in ipairs(WingTargets(w,wing))do table.insert(list,t)end end
local pick=TopPick(w,list,function(t)
if LostCause(w,t)then return nil end
local d=Away(w,t)
local value=t.kind=="Keep" and 6 or(t.kind=="Town" or t.kind=="Outpost")and 5 or 3
return value+(t.owner==PushOn(w)and 1.5 or 0)-(d and 15*d or 0)
end,3,2)
return pick and{pick=pick}
end
local BORED_SIEGE=7
local ABBR={[AD]="AD",[EP]="EP",[DC]="DC"}
local function ActionLine(w,t)
local parts={}
local siege=Sieges(w,t,w.mine)
if siege>0 then table.insert(parts,string.format("%d %s siege",siege,ABBR[w.mine]))end
local total,ad,ep,dc=FightSum(w,t)
local by={[AD]=ad,[EP]=ep,[DC]=dc}
if total>0 then
local them={}
for _,a in ipairs({AD,EP,DC})do
if a~=w.mine and(by[a] or 0)>0 then table.insert(them,{a=a,k=by[a]})end
end
table.sort(them,function(x,y)return x.k>y.k end)
local line=string.format("%d %s victories",by[w.mine] or 0,ABBR[w.mine])
for i,e in ipairs(them)do line=line ..(i==1 and " vs " or ", ").. string.format("%d %s",e.k,ABBR[e.a])end
table.insert(parts,line)
end
if#parts==0 then return nil end
return "There's a fight there: " .. table.concat(parts,", ").. "."
end
P.bored=function(w)
local flags=Flags(w)
local function action(t)
local a=FightNear(w,t)
local f=flags[t.keepId]
if f then a=a+f.moving*6+f.lost*4 end
if w.UnderAttack(t.keepId)then a=a+8 end
for _,alliance in ipairs({AD,EP,DC})do a=a+2*Sieges(w,t,alliance)end
return a
end
local function worthTheRide(t)
local ours,theirs=FightAt(w,t)
local siege=Sieges(w,t,w.mine)
if(ours>0 or siege>0)and theirs>=5 and theirs>ours then return false end
if HOME[w.mine][t.keepId] then return siege>=BORED_SIEGE end
return siege>=BORED_SIEGE or FightNear(w,t)>=BIG_FIGHT
end
local far={}
local pick=TopPick(w,w.options,function(t)
local a=action(t)
if a==0 or LostCause(w,t)then return nil end
local d=Away(w,t)
if d and d>AREA then
if not worthTheRide(t)then return nil end
far[t]=true
end
return a -(d and 10*d or 0)
end,3,10)
if pick then
local plan={pick=pick}
if far[pick] then
plan.extras={ActionLine(w,pick)}
local leg=w.Route and w.Route(pick)
if HOME[w.mine][pick.keepId] and not(leg and leg.recall)then
table.insert(plan.extras,"Stone down to the gate if you've got a recall stone.")
end
end
return plan
end
local quiet=Filter(w.options,function(t)
if IsResource(t)or LostCause(w,t)then return false end
local leg=w.Route and w.Route(t)
return leg and leg.rideAfter and leg.rideAfter<=NEAR
end)
local easy=OneOf(w,quiet)
if easy then return{pick=easy}end
if w.planning then return nil end
return LazyPick(w)or{pick=OneOf(w,w.options)}
end
P.random=function(w)
if w.planning then return nil end
local attacks,defenses={},{}
for _,t in ipairs(w.options)do table.insert(t.defend and defenses or attacks,t)end
local side=attacks
if#defenses>0 and(#attacks==0 or w.Random(1,2)==1)then side=defenses end
if#side==0 then return nil end
local byType,types={},{}
for _,t in ipairs(side)do
local kind=LazyCrown.TypeOf(t)
if not byType[kind] then byType[kind]={};table.insert(types,kind)end
table.insert(byType[kind],t)
end
local group=byType[types[w.Random(1,#types)]]
return{pick=group[w.Random(1,#group)]}
end
P.ORDER=LazyCrown.CROWN_ORDER
P.NAMES={
lazy="Lazy",bakedpotato="Baked Potato",bored="Bored",chris="Chris",greedy="Greedy",
november="November",confessor="Confessor",deano="Deano",diil="Diil",random="Random",
}
P.TOOLTIPS={
lazy="A lazy crown isn't always a lousy one.",
bored="Bored. Chases fights and action.",
bakedpotato="Laziest crown ever, but baked. Needs a break every few calls, and sometimes forgets what it was doing.",
chris="Lazy but with a brain. Top 10 AD player according to one of the worst players of all time. Hey now.",
greedy="Give me all that AP. All we do is win, win, win. (If we get there on time, ha... HURRY UP)",
november="Unconventional and favors flanks. Will do progressively trollier and unhinged things with accumulating losses.",
confessor="Lazy as in not taking us all to our certain deaths.",
deano="Scrappy small scale with a hint of troll and a penchant for grudges.",
diil="The real Diil, but I'm too lazy to siege for you. Do it yourself.",
random="Truly random. Attack or defense first, then the kind of target, then which one.",
}
P.RENAMED={elves="lazy",selfish="lazy",mulliss="lazy",ultralazy="lazy",clever="chris"}
for _,key in ipairs({"greedy","bored"})do
local choose=P[key]
P[key]=function(w)
local all=w.options
local noTowns=Filter(all,function(t)return t.kind~="Town" end)
if#noTowns==0 or#noTowns==#all then return choose(w)end
w.options=noTowns
local ok,plan=pcall(choose,w)
if ok and not w.planning and not(type(plan)=="table" and(plan.pick or plan.say))then
w.options=Filter(noTowns,function(t)return not(LosingFight(w,t)and not ThreeWay(w,t))end)
local okL,lazy=pcall(LazyPick,w)
if okL and type(lazy)=="table" and lazy.pick then plan=lazy end
end
w.options=all
if not ok then error(plan,0)end
if not w.planning and not(type(plan)=="table" and(plan.pick or plan.say))then return choose(w)end
return plan
end
end
for _,key in ipairs({"lazy","bakedpotato","bored","diil","greedy","november"})do
local choose=P[key]
P[key]=function(w)
local plan=choose(w)
local memory=w.memory or{}
local planned=memory.caNext
if planned and w.lastCall then
memory.caNext=nil
local urgent=type(plan)=="table" and plan.pick and(plan.pick.defend or plan.pick.unscored)
if w.lastCall.keepId==planned.after and w.lastCall.result=="W" and not urgent then
if type(plan)=="table" and plan.pick and plan.pick.keepId==planned.keepId then return plan end
for _,t in ipairs(w.options)do
if t.keepId==planned.keepId and not t.defend then
return{pick=t,extras=key=="diil" and{DiilSiege(w,t)}or nil}
end
end
end
end
local pick=type(plan)=="table" and plan.pick
if not pick or not w.player or pick.defend or pick.directive or pick.unscored or IsResource(pick)or plan.grenade then return plan end
local left,owned=ContinuousAttack(w)
if not owned or left>=CA_LOW then return plan end
local leg=OnTheWay(w,pick,WAY_RULE[key])
if not leg then return plan end
memory.caNext={keepId=pick.keepId,after=leg.keepId}
return{pick=leg}
end
end
local function WeakWallLine(w,plan)
local leg=plan.pick
if leg.kind=="Keep" and not leg.defend and not leg.directive and WayIn(w,leg,"nine")=="wall" then return "Look for a weak wall." end
end
for _,key in ipairs({"confessor","deano","greedy","november"})do
local choose=P[key]
P[key]=function(w)
local plan=choose(w)
if type(plan)=="table" and plan.pick and not w.planning then
local line=WeakWallLine(w,plan)
if line then
plan.extras=plan.extras or{}
table.insert(plan.extras,line)
end
end
return plan
end
end
P.HAMMER={
lazy="ours",bakedpotato="ours",november="ours",deano="ours",greedy="always",bored="always",
chris="safe",confessor="safe",diil="safe",
}
for key,rule in pairs(P.HAMMER)do
local choose=P[key]
if key~="diil" and key~="greedy" then
P[key]=function(w)return FollowHammer(w,rule)or choose(w)end
end
end
local function LastStand(w)
local last={}
for _,k in ipairs(GuardingThrone(w)or{})do last[k.keepId]=true end
local home=HOME[w.mine] or{}
return Filter(w.everything or w.options,function(t)
if not t.defend or t.kind~="Keep" then return false end
if last[t.keepId] then return true end
if not home[t.keepId] then return false end
local guards,lastLock=ScrollGuard(w,t.keepId)
return guards>0 and lastLock
end)
end
P.LastStand=function(w)return#LastStand(w)>0 end
for key,every in pairs({lazy=true,bakedpotato=true,deano=false,november=false})do
local choose=P[key]
P[key]=function(w)
if not w.planning then
local stands=LastStand(w)
if not every and#stands>0 then
local flags=Flags(w)
stands=Filter(stands,function(t)
if LostCause(w,t)or LosingFight(w,t)then return false end
local f,d=flags[t.keepId],Away(w,t)
return not(f and f.total>1 and f.lost>=f.total - 1 and not(d and d<=CLOSE))
end)
end
if#stands>0 and(every or w.Random(1,5)==1)then
local best,bestD
for _,t in ipairs(stands)do
local d=Away(w,t)or 0
if not best or d<bestD then best,bestD=t,d end
end
local plan={pick=best}
local d=key=="bakedpotato" and w.player and Dist(w.player,best)
if d and d<=CLOSE and not Flipping(w,best.keepId)then plan.extras={POTATO_WAIT[w.Random(1,#POTATO_WAIT)]}end
return plan
end
end
return choose(w)
end
end
P.StreakTail=function(key,mine,insideJokes)
if key=="chris" then
local line=string.format("%s we are on a losing streak. It's not Chris AI's fault.",ALLIANCE_SHORT[mine] or "Dominion")
return insideJokes and(line .. " It's Mulliss' fault.")or line
elseif key=="confessor" then
return "My train is pulling into the station think I need to go to bed with this many L's."
end
end
P.SKIP_NIKEL={deano=true,november=true,diil=true}
P.SAY_SGX={chris=true,confessor=true}
P.SHARE_DRAKELOWE={chris=true,confessor=true}
P.VOICES={
lazy="guess",bored="guess",bakedpotato="baked",
chris="alright",november="alright",diil="alright",
deano="letsgo",confessor="letsgo",random="dice",
}
P.PLAN_STEPS=4
local MAP_FACTS={"_pushOn","_raids","_lastEmp","_throne","_score"}
local function Hypothetical(w,done,won)
local nw={}
for k,v in pairs(w)do nw[k]=v end
nw.targets,nw.byId,nw.options,nw.everything={},{},{},{}
local copy={}
for _,t in ipairs(w.targets)do
local c=t
if won[t.keepId] then
c={}
for k,v in pairs(t)do c[k]=v end
c.owner,c.defend=w.mine,false
end
copy[t]=c
table.insert(nw.targets,c)
nw.byId[c.keepId]=c
end
local function carry(list,into)
for _,t in ipairs(list or{})do
if not won[t.keepId] then
local c=copy[t] or{}
if not copy[t] then for k,v in pairs(t)do c[k]=v end end
table.insert(into,c)
end
end
end
carry(w.everything or w.options,nw.options)
carry(w.everything or w.options,nw.everything)
nw.player={x=done.x,y=done.y}
nw.Away,nw.Route,nw.planned,nw.planning=nil,nil,nil,true
for _,fact in ipairs(MAP_FACTS)do nw[fact]=nil end
nw.ignoreCA,nw.justSettled=true,"W"
nw.Random=function(a)return a end
nw.UnderAttack=function(keepId)return not won[keepId] and w.UnderAttack(keepId)end
nw.lastCall,nw.streakL,nw.streakBy={keepId=done.keepId,result="W"},0,{}
nw.lastType=LazyCrown.TypeOf and LazyCrown.TypeOf(done)
local memory={}
for k,v in pairs(w.memory or{})do memory[k]=v end
nw.memory=memory
return nw
end
P.PlanAhead=function(key,w,first,steps)
local choose=P[key]
if key=="lazy" or key=="random" or not(choose and first and first.x)then return nil end
local plan,won,cur={first},{},w
while#plan<(steps or P.PLAN_STEPS)do
local last=plan[#plan]
if last.unscored or not last.x then break end
won[last.keepId]=true
cur=Hypothetical(cur,last,won)
if#cur.options==0 then break end
local ok,result=pcall(choose,cur)
local nextStep=ok and type(result)=="table" and result.pick
if not nextStep or nextStep.unscored or won[nextStep.keepId] then break end
table.insert(plan,nextStep)
end
return plan
end
]=]})
