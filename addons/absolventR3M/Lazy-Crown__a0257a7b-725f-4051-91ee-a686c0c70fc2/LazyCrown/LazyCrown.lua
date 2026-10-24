LazyCrown=LazyCrown or {}
LazyCrown.later=LazyCrown.later or {}
table.insert(LazyCrown.later,{name="LazyCrown.lua",code=[=[
local ADDON_NAME="LazyCrown"
local TEXT_COLOR="F2C65A"
local DIAG_COLOR="FF5F1F"
local PLAN_COLOR="FFFFFF"
local chosenColors={}
local function Hex(kind,fallback)
local hex=chosenColors[kind]
return type(hex)=="string" and hex:match("^%x%x%x%x%x%x$")and hex or fallback
end
local AD,EP,DC=ALLIANCE_ALDMERI_DOMINION or 1,ALLIANCE_EBONHEART_PACT or 2,ALLIANCE_DAGGERFALL_COVENANT or 3
local ROTATION={AD,EP,DC}
local ALLIANCE_NAMES={[AD]="Aldmeri Dominion",[EP]="Ebonheart Pact",[DC]="Daggerfall Covenant"}
local CROWN_ORDER={"lazy","bakedpotato","bored","chris","confessor","deano","diil","greedy","november","random"}
local function LoadTheRest()
if LazyCrown and LazyCrown.LoadAll then LazyCrown.LoadAll()end
end
local function Personalities()
LoadTheRest()
return LazyCrown and LazyCrown.Personalities
end
local HOME_KEEPS={
[AD]={
{id=15,name="Castle Alessia"},{id=16,name="Castle Faregyl"},
{id=17,name="Castle Roebeck"},{id=18,name="Castle Brindle"},
{id=19,name="Castle Black Boot"},{id=20,name="Castle Bloodmayne"},
},
[EP]={
{id=9,name="Chalman Keep"},{id=10,name="Arrius Keep"},
{id=11,name="Kingscrest Keep"},{id=12,name="Farragut Keep"},
{id=13,name="Blue Road Keep"},{id=14,name="Drakelowe Keep"},
},
[DC]={
{id=3,name="Fort Warden"},{id=4,name="Fort Rayles"},
{id=5,name="Fort Glademist"},{id=6,name="Fort Ash"},
{id=7,name="Fort Aleswell"},{id=8,name="Fort Dragonclaw"},
},
}
local GATE_KEEPS={[AD]={[19]=true,[20]=true},[EP]={[11]=true,[12]=true},[DC]={[3]=true,[4]=true}}
local KEEP_PARTS={
{label="Keep"},
{label="Lumbermill",resource=RESOURCETYPE_WOOD or 1},
{label="Farm",resource=RESOURCETYPE_FOOD or 2},
{label="Mine",resource=RESOURCETYPE_ORE or 3},
}
local TOWNS={
{id=149,name="Vlastarus",home=AD},
{id=152,name="Cropsford",home=EP},
{id=151,name="Bruma",home=DC},
}
local OUTPOSTS={
{id=132,name="Nikel Outpost",home=AD},
{id=133,name="Sejanus Outpost",home=EP},
{id=134,name="Bleaker's Outpost",home=DC},
{id=164,name="Carmala Outpost",home=AD},
{id=165,name="Harlun's Outpost",home=EP},
{id=163,name="Winter's Peak Outpost",home=DC},
}
local Random=zo_random or math.random
local Buttons=LazyCrown.Buttons
local CrownName=function()return "Lazy" end
local function Tag()
return string.format("[Lazy Crown - %s] ",CrownName())
end
local function Say(text)
CHAT_ROUTER:AddSystemMessage(string.format("|c%s%s%s|r",Hex("calls",TEXT_COLOR),Tag(),text))
end
local function Diag(text)
CHAT_ROUTER:AddSystemMessage(string.format("|c%s%s%s|r",Hex("status",DIAG_COLOR),Tag(),text))
end
local function SayPlan(text)
CHAT_ROUTER:AddSystemMessage(string.format("|c%s[Lazy Crown - Plan] %s|r",Hex("plan",PLAN_COLOR),text))
end
local function Context()
return BGQUERY_LOCAL or 1
end
local namesFellBack=false
local function KeepName(keepId,fallback)
local ok,name=pcall(GetKeepName,keepId)
if ok and type(name)=="string" and name~="" then
return(zo_strformat and zo_strformat(SI_TOOLTIP_KEEP_NAME or "<<1>>",name))or name
end
namesFellBack=true
return fallback
end
local function PinPosition(keepId)
local ok,_,x,y=pcall(GetKeepPinInfo,keepId,Context())
if ok and type(x)=="number" and type(y)=="number" and(x~=0 or y~=0)then
return x,y
end
end
local function IsKeepType(keepId,expected)
if not(expected and GetKeepType)then return true end
local ok,keepType=pcall(GetKeepType,keepId)
return ok and keepType==expected
end
local function BuildTargets()
namesFellBack=false
local targets={}
local number=0
local function add(keepId,name,kind,home,expectedType,parent)
number=number+1
if keepId and IsKeepType(keepId,expectedType)then
table.insert(targets,{number=number,keepId=keepId,name=KeepName(keepId,name),kind=kind,home=home,parent=parent})
end
end
for i=1,6 do
for _,part in ipairs(KEEP_PARTS)do
for _,alliance in ipairs(ROTATION)do
local keep=HOME_KEEPS[alliance][i]
if part.resource then
local ok,resId=pcall(GetResourceKeepForKeep,keep.id,part.resource)
if not(ok and type(resId)=="number" and resId>0)then resId=nil end
add(resId,keep.name .. " " .. part.label,part.label,alliance,KEEPTYPE_RESOURCE,keep.id)
else
add(keep.id,keep.name,part.label,alliance,KEEPTYPE_KEEP)
end
end
end
end
for _,town in ipairs(TOWNS)do add(town.id,town.name,"Town",town.home,KEEPTYPE_TOWN)end
for _,outpost in ipairs(OUTPOSTS)do add(outpost.id,outpost.name,"Outpost",outpost.home,KEEPTYPE_OUTPOST)end
return targets,number
end
local sessionTargets
local function PickTargets()
if not sessionTargets then
local targets,total=BuildTargets()
if#targets<total or namesFellBack then return targets end
sessionTargets=targets
end
local fresh={}
for i,t in ipairs(sessionTargets)do
fresh[i]={number=t.number,keepId=t.keepId,name=t.name,kind=t.kind,home=t.home,parent=t.parent}
end
return fresh
end
local function InCyrodiil()
if IsInCyrodiil then
if not IsInCyrodiil()then return false end
elseif IsPlayerInAvAWorld and not IsPlayerInAvAWorld()then
return false
end
if IsInImperialCity and IsInImperialCity()then return false end
if IsActiveWorldBattleground and IsActiveWorldBattleground()then return false end
return true
end
local NOT_IN_CYRODIIL="Looks like you're not in Grayhost, which means I don't have to try right now. Sweet."
local function CyrodiilOnly(fn)
return function(...)
if not InCyrodiil()then
Say(NOT_IN_CYRODIIL)
return nil
end
return fn(...)
end
end
local function MapChanged()
if CALLBACK_MANAGER then CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")end
end
local function UseCyrodiilMap()
if not(GetCyrodiilMapIndex and SetMapToMapListIndex)then return nil end
local ok,from=pcall(function()
if WORLD_MAP_MANAGER and WORLD_MAP_MANAGER.IsMapChangingAllowed and not WORLD_MAP_MANAGER:IsMapChangingAllowed()then
return nil
end
local index=GetCyrodiilMapIndex()
if not index or(GetCurrentMapIndex and GetCurrentMapIndex()==index)then return nil end
local before={
mapId=GetCurrentMapId and GetCurrentMapId()or nil,
playerMap=not DoesCurrentMapMatchMapForPlayerLocation or DoesCurrentMapMatchMapForPlayerLocation()==true,
}
if SetMapToMapListIndex(index)==SET_MAP_RESULT_MAP_CHANGED then return before end
end)
return ok and from or nil
end
local function RestoreMap(before)
pcall(function()
local back=false
if not before.playerMap and before.mapId and SetMapToMapId then
pcall(SetMapToMapId,before.mapId)
back=GetCurrentMapId()==before.mapId
end
if not back and SetMapToPlayerLocation then SetMapToPlayerLocation()end
if not(back or before.mapId and GetCurrentMapId and GetCurrentMapId()==before.mapId)then MapChanged()end
end)
end
local pinged=false
local function OnCyrodiilMap(fn,needMap)
local switched=needMap~=false and UseCyrodiilMap()
pinged=false
local ok,result=pcall(fn)
if switched then
RestoreMap(switched)
if pinged and WORLD_MAP_MANAGER and WORLD_MAP_MANAGER.RefreshMapPings then pcall(WORLD_MAP_MANAGER.RefreshMapPings,WORLD_MAP_MANAGER)end
end
if not ok then
Diag("Something went wrong: " .. tostring(result))
return nil
end
return result
end
local function SetWaypoint(keepId)
local x,y=PinPosition(keepId)
if not(x and PingMap and MAP_PIN_TYPE_PLAYER_WAYPOINT)then return false end
local ok=pcall(PingMap,MAP_PIN_TYPE_PLAYER_WAYPOINT,MAP_TYPE_LOCATION_CENTERED,x,y)
if ok then pinged=true end
return ok
end
local DEFENDABLE={Keep=true,Outpost=true}
local FLAGGED_RESOURCE_SECONDS=32
local MIN_GROUP={Outpost=4,Keep=8}
local FIGHT_RADIUS=0.025
local markers
local function KillMarkers()
if markers then return markers end
markers={}
local okN,n=pcall(GetNumKillLocations)
for i=1,(okN and n)or 0 do
local okP,pinType,x,y=pcall(GetKillLocationPinInfo,i)
if okP and type(x)=="number" and type(y)=="number" then
local m={pinType=pinType,x=x,y=y,kills={}}
for alliance in pairs(ALLIANCE_NAMES)do
local okK,k=pcall(GetNumKillLocationAllianceKills,i,alliance)
if okK then m.kills[alliance]=k end
end
table.insert(markers,m)
end
end
return markers
end
local function Supported(t,mine)
local okS,siege=pcall(GetNumSieges,t.keepId,Context(),mine)
if okS and type(siege)=="number" and siege>0 then return true end
if not(t.x and GetNumKillLocations)then return false end
local by={}
for _,m in ipairs(KillMarkers())do
local dx,dy=m.x - t.x,m.y - t.y
if dx*dx+dy*dy<=FIGHT_RADIUS*FIGHT_RADIUS then
for alliance in pairs(ALLIANCE_NAMES)do
local k=m.kills[alliance]
by[alliance]=(by[alliance] or 0)+(type(k)=="number" and k or 0)
end
end
end
local ours,theirs=by[mine] or 0,0
for alliance,k in pairs(by)do if alliance~=mine then theirs=math.max(theirs,k)end end
return ours>0 and ours>theirs
end
local KIND_SETTING={Keep="pickKeeps",Lumbermill="pickResources",Farm="pickResources",Mine="pickResources",
Town="pickTowns",Outpost="pickOutposts"}
local attacked={}
local function UnderAttack(keepId)
local known=attacked[keepId]
if known==nil then
local ok,underAttack=pcall(GetKeepUnderAttack,keepId,Context())
known=ok and underAttack==true
if keepId~=nil then attacked[keepId]=known end
end
return known
end
local lastKeepId=nil
local lastType=nil
local overrideKeepId=nil
local function TypeOf(t)
if t.parent then return "resource" end
return t.kind
end
local function OneOf(w,list)
if#list==0 then return nil end
if w.planning then return nil end
if w.planned then
for _,t in ipairs(list)do if t.keepId==w.planned then return t end end
end
local byType,types={},{}
for _,t in ipairs(list)do
local kind=TypeOf(t)
if not byType[kind] then byType[kind]={};table.insert(types,kind)end
table.insert(byType[kind],t)
end
if#types>1 and w.lastType and byType[w.lastType] then
for i,kind in ipairs(types)do if kind==w.lastType then table.remove(types,i)break end end
end
local group=byType[types[w.Random(1,#types)]]
return group[w.Random(1,#group)]
end
local VOID_SECONDS=90
local sv={lifetime={}}
local Start
local function Used(fn)
return function(...)
Start()
return fn(...)
end
end
local function PersonalityKey()
local P=Personalities()
if P and P.RENAMED and P.RENAMED[sv.personality] then sv.personality=P.RENAMED[sv.personality] end
if P and P.NAMES[sv.personality] then return sv.personality end
return "lazy"
end
local function PersonalityName()
local P=Personalities()
return(P and P.NAMES[PersonalityKey()])or "Lazy"
end
CrownName=PersonalityName
local function Now()
return(GetTimeStamp and GetTimeStamp())or os.time()
end
local function Since(stamp)
if GetDiffBetweenTimeStamps then return GetDiffBetweenTimeStamps(Now(),stamp)end
return Now()- stamp
end
local function Night()
local night=sv.night
if not night then
night={w=0,l=0,void=0,targets={},lossesBy={}}
sv.night=night
end
return night
end
local function Tally(night)
return string.format("%dW %dL",night.w,night.l)
end
local function SaveSoon()
pcall(function()GetAddOnManager():RequestAddOnSavedVariablesPrioritySave(ADDON_NAME)end)
end
local DRUNK_WORDS={
Alright="Aaalright",going="goin",attack="attak",defend="defenn",defense="defensh",
should="shuold",declare="delcare",guess="guesh",siege="sheige",Castle="Cashle",
Keep="Keeeep",Outpost="Outposht",Fort="Forrt",front="fronnt",door="doooor",
take="tayke",the="teh",["Let's"]="Lesh",crown="crowwn",doth="dothhh",hit="hiit",
taken="takken",held="helld",lost="losht",Scoreboard="Shcoreboard",we="wee",
}
local COLOR_LINES={
[EP]={
{text="I think Araphel has a crush on me.",joke=true},
{text="Evil Deeds stole my sweet roll.",joke=true},
{text="Maybe Moonrox has Moon Sugar? Let's hit that pinata.",joke=true},
},
[DC]={
{text="Maybe this time Ashmax will share his moon sugar.",joke=true},
{text="TKL always hoards the best skooma.",joke=true},
{text="Maybe Cake will finally show me the moon sugar.",joke=true},
{text="Maybe Suzy will share.",joke=true},
},
[AD]={
{text="I hear the VD is sweeter than Skooma."},
{text="Law Dog stole my sweet roll.",joke=true},
{text="Silachi sounds like srirachi. Wait, sriracha? I don't know. Just get there.",joke=true},
},
}
local function ColorLines(owner,skooma)
local out={}
for _,c in ipairs(COLOR_LINES[owner] or{})do
local low=c.text:lower()
local fits=skooma or not(low:find("skooma",1,true)or low:find("moon sugar",1,true))
if fits and(not c.joke or sv.insideJokes==true)then table.insert(out,c.text)end
end
return out
end
local DRUNK_ASIDES={
"But the blue one.","No wait, the other one.","You gusy are teh best.","You know the one.",
"Not that one. Yes that one.","Or the one next to it.","Pretty sure it's still there.",
"I love you guys.","Is the floor moving?",
}
local function Drunk(line,owner)
if not sv.drunk then return line end
line=line:gsub("[%a']+",function(word)
local slurred=DRUNK_WORDS[word]
if slurred and Random(1,3)>1 then return slurred end
end)
local aside=DRUNK_ASIDES[Random(1,#DRUNK_ASIDES)]
local about=owner and ColorLines(owner,false)or{}
if#about>0 and Random(1,3)==1 then aside=about[Random(1,#about)] end
local first,rest=line:match("^(.-[%.!%?])(.*)$")
if first then line=first .. " " .. aside .. rest else line=line .. " " .. aside end
for _=1,Random(1,2)do
local spots={}
for pos in line:gmatch("() ")do table.insert(spots,pos)end
if#spots>0 then
local at=spots[Random(1,#spots)]
line=line:sub(1,at).. "*hic* " .. line:sub(at+1)
end
end
return line
end
local justSettled
local quickReroll
local QUIPS={
{won=true,text="Easy.",any=true,notWho={lazy=true,bakedpotato=true},notSkooma=true},
{won=true,text="Write that down.",who={chris=true}},
{won=true,text="More AP for the crown.",who={greedy=true}},
{won=true,text="Top 10 %s player confirmed.",who={chris=true}},
{won=true,text="Worth the short walk.",who={bored=true}},
{won=true,text="Don't get used to it.",who={lazy=true},mean=true,wins=3},
{won=false,text="We'll call that a scouting run.",who={confessor=true}},
{won=false,text="Tactical donation.",who={chris=true,november=true,deano=true}},
{won=false,text="Nobody saw that.",who={november=true,lazy=true},drunk=true},
{won=false,text="That AP was ours.",who={greedy=true,confessor=true}},
{won=false,text="That's on Mulliss.",who={chris=true},joke=true},
{won=false,text="This is why we don't do things.",who={confessor=true}},
{won=false,text="Didn't want it anyway.",who={deano=true}},
{won=false,text="Noted. Getting weirder.",skooma=true},
}
local SHORT={[AD]="AD",[EP]="EP",[DC]="DC"}
local function Quip(won,key,mine)
local fits={}
for _,q in ipairs(QUIPS)do
local ok=q.won==won
if q.skooma then ok=ok and sv.skooma==true
elseif key=="random" then ok=ok
else ok=ok and((q.who and q.who[key])or(q.any and not q.notWho[key])or(q.drunk and sv.drunk==true))end
if q.notSkooma and sv.skooma==true then ok=false end
if q.mean and sv.mean~=true then ok=false end
if q.wins and(sv.streakW or 0)<q.wins then ok=false end
if q.joke and sv.insideJokes~=true then ok=false end
if ok then table.insert(fits,q.text)end
end
if#fits==0 or Random(1,3)~=1 then return nil end
return string.format(fits[Random(1,#fits)],SHORT[mine] or "AD")
end
local HISTORY_KEEP=50
local HISTORY_SHOW=10
local function Settle(result,why,against,quiet)
local call=sv.open
if not call then return end
sv.open=nil
justSettled=result
local night=Night()
night.lossesBy=night.lossesBy or{}
sv.lastResult=result
if result~="void" then
sv.lastDecidedCall={keepId=call.keepId,result=result,against=against,plan=call.plan,planKey=call.planKey}
if result=="W" then
sv.streakL,sv.streakBy,sv.streakW=0,{},(sv.streakW or 0)+1
else
sv.streakW=0
sv.streakL=(sv.streakL or 0)+1
sv.streakBy=sv.streakBy or{}
if ALLIANCE_NAMES[against] then sv.streakBy[tostring(against)]=(sv.streakBy[tostring(against)] or 0)+1 end
end
end
quickReroll=result=="void" and not why
if quickReroll then sv.rerolls=(sv.rerolls or 0)+1 elseif result~="void" then sv.rerolls=0 end
if result=="void" then
night.void=night.void+1
if why then Diag(string.format("Last call (%s) doesn't count: %s.",call.name,why))end
return
end
local won=result=="W"
local key=tostring(call.keepId)
local t=night.targets[key] or{name=call.name,w=0,l=0}
night.targets[key]=t
local life=sv.lifetime[key] or{w=0,l=0}
sv.lifetime[key]=life
if won then
night.w,t.w,life.w=night.w+1,t.w+1,life.w+1
else
night.l,t.l,life.l=night.l+1,t.l+1,life.l+1
if ALLIANCE_NAMES[against] then
local key=tostring(against)
night.lossesBy[key]=(night.lossesBy[key] or 0)+1
end
end
night.history=night.history or{}
table.insert(night.history,{n=call.name,r=result,o=call.override})
while#night.history>HISTORY_KEEP do table.remove(night.history,1)end
local what=call.defend and(won and "held" or "lost")or(won and "taken" or "not taken")
if not quiet then
local line=string.format("%s! %s %s. Scoreboard: %s.",won and "W" or "L",call.name,what,Tally(night))
local quip=Quip(won,call.planKey or PersonalityKey(),call.alliance)
Say(Drunk(quip and(line .. " " .. quip)or line))
end
SaveSoon()
end
local function CampaignChanged(call)
if not(GetCurrentCampaignId and call.campaignId and call.campaignId~=0)then return false end
local now=GetCurrentCampaignId()
return now~=nil and now~=0 and now~=call.campaignId
end
local function PlayerSpot()
local ok,x,y,_,shown=pcall(GetMapPlayerPosition,"player")
if ok and type(x)=="number" and type(y)=="number" and shown~=false and(x~=0 or y~=0)then return{x=x,y=y}end
end
local WENT_THERE=0.3
local function FarFrom(keepId,where)
if not where then return false end
local x,y=PinPosition(keepId)
if not(x and y)or(x==0 and y==0)then return false end
local dx,dy=x - where.x,y - where.y
return math.sqrt(dx*dx+dy*dy)>WENT_THERE
end
local settledEarly
local function SettleLastCall(where)
justSettled,quickReroll=settledEarly,false
settledEarly=nil
local call=sv.open
if not call then return true end
if CampaignChanged(call)then
Settle("void","different campaign")
return true
end
local ok,owner=pcall(GetKeepAlliance,call.keepId,Context())
if not(ok and ALLIANCE_NAMES[owner])then return false end
local ours=owner==call.alliance
local quick=Since(call.at)<VOID_SECONDS
if FarFrom(call.keepId,where)then
if quick then Settle("void")else Settle("void","you weren't anywhere near it")end
return true
end
if call.defend then
if not ours then Settle("L",nil,owner)
elseif UnderAttack(call.keepId)then Settle("void","still under attack")
elseif quick then Settle("void")
else Settle("W")end
else
if ours then Settle("W")
elseif quick then Settle("void")
else Settle("L",nil,owner)end
end
return true
end
local function SettleIfDecided()
local call=sv.open
if not call or CampaignChanged(call)then return end
OnCyrodiilMap(function()
attacked={}
local ok,owner=pcall(GetKeepAlliance,call.keepId,Context())
if not(ok and ALLIANCE_NAMES[owner])or FarFrom(call.keepId,PlayerSpot())then return end
local ours=owner==call.alliance
local result
if call.defend then
if not ours then result="L"
elseif not UnderAttack(call.keepId)and Since(call.at)>=VOID_SECONDS then result="W" end
elseif ours then
result="W"
end
if result then
Settle(result,nil,result=="L" and owner or nil)
settledEarly=justSettled
end
end)
end
local function OpenCall(pick,mine,plan,planKey)
Night()
sv.open={
keepId=pick.keepId,number=pick.number,name=pick.name,defend=pick.defend or nil,
alliance=mine,at=Now(),campaignId=GetCurrentCampaignId and GetCurrentCampaignId()or nil,
plan=plan,planKey=planKey,
}
end
local function BestCall(night)
local best
for _,t in pairs(night.targets)do
if t.w>0 and(not best or t.w>best.w or(t.w==best.w and t.l<best.l))then best=t end
end
return best
end
local function LazierAlliance(night)
local most,names=0,{}
for _,alliance in ipairs(ROTATION)do
local n=(night.lossesBy or{})[tostring(alliance)] or 0
if n>most then most,names=n,{ALLIANCE_NAMES[alliance]}
elseif n==most and n>0 then table.insert(names,ALLIANCE_NAMES[alliance])end
end
if#names==0 then return nil end
return table.concat(names," and ")
end
local function SummaryLine()
local night=Night()
local best=BestCall(night)
local lazier=LazierAlliance(night)
return string.format("Scoreboard: %s.%s%s",Tally(night),
best and string.format(" Best call: %s %d-%d.",best.name,best.w,best.l)or "",
lazier and string.format(" Alliance that made me even lazier: %s.",lazier)or "")
end
local function RefreshSettings()
pcall(function()
local lib=LibHarvensAddonSettings
if lib and lib.list and lib.list.RefreshVisible then lib.list:RefreshVisible()end
end)
end
local function ResetScoreboard()
sv.night,sv.open,sv.lastResult,sv.lastDecidedCall,sv.streakL,sv.streakBy=nil,nil,nil,nil,0,{}
SaveSoon()
Say("Scoreboard reset.")
RefreshSettings()
end
local FORT_ASH,BLUE_ROAD,BRUMA,NIKEL,DRAKELOWE=6,13,151,132,14
local function Extra(pick,mine)
if pick.keepId==FORT_ASH then return "Ash till you crash." end
local P=Personalities()
local key=PersonalityKey()
local skipNikel=P and P.SKIP_NIKEL and P.SKIP_NIKEL[key]
if pick.keepId==NIKEL and not skipNikel then
return pick.defend and "We're gonna protect Nikel's pickle from tickling." or "We're gonna tickle Nikel's pickle."
end
if pick.keepId==BLUE_ROAD and P and P.SAY_SGX and P.SAY_SGX[key] and sv.insideJokes==true then
return "And don't forget sgx says the mine side is cursed."
end
local drakelowe=pick.keepId==DRAKELOWE or(pick.parent==DRAKELOWE and pick.kind=="Mine")
if drakelowe and not pick.defend and P and P.SHARE_DRAKELOWE and P.SHARE_DRAKELOWE[key] then
return "Make sure you share the Drakelowe quests with everyone."
end
if pick.keepId==BRUMA then return "Bruma is the key to the whole map guys." end
if GATE_KEEPS[mine] and GATE_KEEPS[mine][pick.keepId] then return "I guess we gotta go bail out the alliance ugh." end
end
local VOICES={
declare={attack="The crown doth declare an attack on %s.",defend="The crown doth declare the defense of %s.",
directive="The crown doth declare: %s."},
guess={attack="I guess we should hit %s.",defend="I guess we should defend %s.",
directive="I guess we should %s."},
alright={attack="Alright, we are going to hit %s.",defend="Alright, we are going to defend %s.",
directive="Alright, we are going to %s."},
letsgo={attack="Let's go take %s.",defend="Let's go defend %s.",
directive="Let's %s."},
baked={attack="Duuude... let's hit %s.",defend="Duuude, we gotta defend %s.",
directive="Duuude... let's %s."},
dice={attack="The dice say %s.",defend="The dice say defend %s.",
directive="The dice say %s."},
}
local function Voice()
local P=Personalities()
return VOICES[P and P.VOICES and P.VOICES[PersonalityKey()] or "declare"] or VOICES.declare
end
local CALL_VARIANTS={
{text="By decree of the crown: %s.",who={greedy=2}},
{text="The crown demands %s. And its AP.",who={greedy=2}},
{text="Alright, %s next. Stay on crown.",who={chris=2}},
{text="%s. Let's go.",who={deano=2,november=2,confessor=2}},
{text="Let's go see what %s has for us.",who={confessor=2,lazy=1}},
{text="%s, I guess.",who={lazy=2},losing={november=2,deano=2}},
{text="Eh... %s?",who={lazy=2,november=1,deano=1},rerolls={november=2,deano=2}},
{text="Something's happening at %s. Finally.",who={bored=2,confessor=1}},
{text="Alright, %s. Bring your own siege.",who={diil=2,november=1}},
{text="%s or %s, whatever. %s.",who={lazy=1,november=1},alt=true},
}
local PAYING_US={confessor=true,deano=true,greedy=true,lazy=true}
local GRENADE="Bring out the Holy Hand Grenade of %s. We are going to leech that tick if we can. %s"
local function Wording(pick,where,opts)
local voice=Voice()
if pick.directive then return string.format(voice.directive,pick.directive)end
local key=PersonalityKey()
if key=="random" and opts and opts.variants then
local pool={}
for _,v in pairs(VOICES)do table.insert(pool,pick.defend and v.defend or v.attack)end
if not pick.defend then
for _,v in ipairs(CALL_VARIANTS)do if not v.alt then table.insert(pool,v.text)end end
end
return string.format(pool[Random(1,#pool)],where)
end
if opts and opts.grenade and Random(1,2)==1 then
local hustle="Hustle."
if opts.seconds and LazyCrown.Travel then
hustle=string.format("Hustle, we only have maybe %s.",(LazyCrown.Travel.Eta(opts.seconds):gsub("^about ","")))
end
return string.format(GRENADE,where,hustle)
end
if pick.defend then return string.format(voice.defend,where)end
if not(opts and opts.variants and Personalities())then return string.format(voice.attack,where)end
local choices,total={{text=voice.attack,weight=4}},4
local losing,rerolls=(sv.streakL or 0)>6,(sv.rerolls or 0)>=3
for _,v in ipairs(CALL_VARIANTS)do
local weight=v.who[key] or 0
if losing and v.losing and v.losing[key] then weight=math.max(weight,v.losing[key])end
if rerolls and v.rerolls and v.rerolls[key] then weight=math.max(weight,v.rerolls[key])end
if v.alt and not opts.alt then weight=0 end
if weight>0 then
table.insert(choices,{variant=v,weight=weight})
total=total+weight
end
end
local roll=Random(1,total)
for _,c in ipairs(choices)do
roll=roll - c.weight
if roll<=0 then
local v=c.variant
if not v then return string.format(c.text,where)end
if v.alt then
local a,b=where,opts.alt
if Random(1,2)==1 then a,b=b,a end
return string.format(v.text,a,b,where)
end
return string.format(v.text,where)
end
end
return string.format(voice.attack,where)
end
local function CallLine(pick,mine,extras,tail,quiet,opts)
local where=pick.name
local line
if not sv.mean then
line=Wording(pick,where,opts)
else
local what=pick.directive or string.format("%s %s",pick.defend and "defend" or "attack",where)
local body=string.format("you're going to %s and you're gonna like it.",what)
local mix=opts and opts.variants
if mix and not pick.directive then
local roll=Random(1,4)
if roll==1 then body=string.format("try not to die on the way to %s this time.",where)
elseif roll==2 then body=string.format("%s. Even you can't mess this up, right?",where)end
end
local key=PersonalityKey()
if sv.lastResult=="W" then
if mix and(key=="confessor" or key=="november")and Random(1,2)==1 then
line="Don't let it go to your head. " .. body:gsub("^%l",string.upper)
else
line="I'd say congrats on that W but I'm too lazy. And mean. Anyways, " .. body
end
else
line=body:gsub("^%l",string.upper)
if sv.lastResult=="L" then line=((mix and Random(1,2)==1)and "Incredible. Another one. " or "Wow losers... ").. line end
end
end
for _,more in ipairs(extras or{})do line=line .. " " .. more end
local extra=not quiet and Extra(pick,mine)or nil
if extra then line=line .. " " .. extra end
for _,more in ipairs(tail or{})do line=line .. " " .. more end
return line
end
local POP_ASK_SECONDS=30
local bars,popAskedAt
local function PopulationBars(alliance)
if not bars then
bars={}
local now=Now()
if QueryCampaignSelectionData and(not popAskedAt or now - popAskedAt>=POP_ASK_SECONDS)then
popAskedAt=now
pcall(QueryCampaignSelectionData)
end
local rank={[CAMPAIGN_POP_LOW or -1]=1,[CAMPAIGN_POP_MEDIUM or -2]=2,[CAMPAIGN_POP_HIGH or -3]=3,[CAMPAIGN_POP_FULL or -4]=4}
local campaignId=GetCurrentCampaignId and GetCurrentCampaignId()
local okN,n=pcall(GetNumSelectionCampaigns)
for i=1,(okN and n)or 0 do
local okI,id=pcall(GetSelectionCampaignId,i)
if okI and id==campaignId then
for alliance in pairs(ALLIANCE_NAMES)do
local okP,pop=pcall(GetSelectionCampaignPopulationData,i,alliance)
if okP then bars[alliance]=rank[pop] end
end
break
end
end
end
return bars[alliance]
end
local function BuildWorld(mine,options,targets,withPositions,positioned,spot)
local world={
mine=mine,options=options,targets=targets,byId={},ctx=Context(),
campaignId=(GetCurrentCampaignId and GetCurrentCampaignId())or 0,
Random=Random,UnderAttack=UnderAttack,Markers=KillMarkers,Bars=PopulationBars,
Allied=function(alliance)return ALLIANCE_NAMES[alliance]~=nil end,
KindOn=function(kind)return sv[KIND_SETTING[kind] or ""]~=false end,
lifetime=sv.lifetime or{},lastCall=sv.lastDecidedCall,
streakL=sv.streakL or 0,streakBy=sv.streakBy or{},
lossesBy=type(sv.night)=="table" and sv.night.lossesBy or{},
memory=sv.memory,ignoreCA=sv.continuousAttack==false,now=Now(),
}
if IsCurrentCampaignVengeanceRuleset then
local okV,vengeance=pcall(IsCurrentCampaignVengeanceRuleset)
if okV and vengeance==true then world.ignoreCA=true end
end
if type(world.memory)~="table" then
sv.memory={}
world.memory=sv.memory
end
for _,t in ipairs(targets)do world.byId[t.keepId]=t end
if withPositions then
if not positioned then for _,t in ipairs(targets)do t.x,t.y=PinPosition(t.keepId)end end
if spot then world.player={x=spot.x,y=spot.y}end
end
return world
end
local SKOOMA_CALLS={
"Uhhh... %s? Yeah. %s.",
"The moon sugar says %s.",
"%s. Or was that a dream? Go anyway.",
"Follow the pretty colors to %s.",
}
local SKOOMA_AWAY={
"Everyone go to... away. Just away.",
"Go away. Far away. Further than that.",
"We're going to Away. It's on the map somewhere.",
}
local SKOOMA_FAR="We're going to %s. Yes, all the way over there. The journey is the destination."
local SKOOMA_SAYS={
"Moon sugar makes the whole map shiny. A little goes a very long way though.",
"Did that mudcrab just wink at me?",
"I can hear the Elder Scrolls humming. They're off key.",
"If you stare at White-Gold Tower long enough, it stares back.",
"I traded my horse for a really nice rock. Worth it.",
"The siege engines are talking to each other. Don't trust them.",
"Shh. The trees are listening.",
"Everything is purple and that's fine.",
"Who keeps moving the keeps?",
"I think the guards can hear my thoughts.",
}
local function FarAway(targets,mine,where)
if not where then return nil end
local far,farthest,best={},nil,-1
for _,t in ipairs(targets)do
local x,y=PinPosition(t.keepId)
if x and t.owner~=mine then
local d=math.sqrt((x - where.x)^2+(y - where.y)^2)
if d>=0.35 then table.insert(far,t)end
if d>best then farthest,best=t,d end
end
end
if#far>0 then return far[Random(1,#far)] end
return farthest
end
local SkoomaPick
local function SkoomaCall(targets,mine,where)
local line,pick=SkoomaPick(targets,mine,where)
if Random(1,2)==1 then
local about=pick and ColorLines(pick.owner,true)or{}
if#about>0 and Random(1,2)==1 then
line=line .. " " .. about[Random(1,#about)]
else
line=line .. " " .. SKOOMA_SAYS[Random(1,#SKOOMA_SAYS)]
end
end
return line
end
function SkoomaPick(targets,mine,where)
local roll=Random(1,10)
if roll==1 then
sv.open={keepId=0,name="No call",alliance=mine,at=Now()}
Settle("L",nil,nil,true)
return string.format("Nope. No call. I'm in a bad mood, so that's an L. Scoreboard: %s.",Tally(Night()))
elseif roll==2 then
return SKOOMA_AWAY[Random(1,#SKOOMA_AWAY)]
elseif roll==3 then
local far=FarAway(targets,mine,where)
if far then
OpenCall(far,mine)
return string.format(SKOOMA_FAR,far.name),far
end
end
local pick=targets[Random(1,#targets)]
if pick.owner==mine then
sv.open={keepId=pick.keepId,name=pick.name,alliance=mine,at=Now()}
Settle("W",nil,nil,true)
return string.format("We already have %s! That's a W. Scoreboard: %s. Taking a break for more skooma.",pick.name,Tally(Night())),pick
end
OpenCall(pick,mine)
return(string.format(SKOOMA_CALLS[Random(1,#SKOOMA_CALLS)],pick.name,pick.name)),pick
end
local POTATO_HUNGRY={
"Hold up. I'm really hungry. Snack break.",
"Brb, I gotta find a snack.",
"Can we stop for snacks? I'm starving.",
}
local POTATO_SMOKE={
"Gotta go smoke real quick. Hold the keep.",
"Smoke break. Don't take anything without me.",
"Be right back, gotta go smoke.",
}
local function PotatoBreak(targets,mine,where)
local kind=Random(1,3)
if kind==1 then return POTATO_HUNGRY[Random(1,#POTATO_HUNGRY)] end
if kind==2 then return POTATO_SMOKE[Random(1,#POTATO_SMOKE)] end
if Random(1,2)==1 then
local stop,best
for _,t in ipairs(targets)do
local ok,owner=pcall(GetKeepAlliance,t.keepId,Context())
local x,y=PinPosition(t.keepId)
if ok and owner==mine and x then
local d=where and math.sqrt((x - where.x)^2+(y - where.y)^2)or 0
if not best or d<best then stop,best=t,d end
end
end
if stop then
sv.open={keepId=stop.keepId,name=stop.name,alliance=mine,at=Now()}
Settle("W",nil,nil,true)
return string.format("Wait... what was I doing? Uh, pit stop at %s. It's ours, so that's a W. Scoreboard: %s.",stop.name,Tally(Night()))
end
end
sv.open={keepId=0,name="No call",alliance=mine,at=Now()}
Settle("L",nil,nil,true)
return string.format("...sorry, I was staring into space thinking about how big Tamriel is. Forgot to make a call. That's an L. Scoreboard: %s.",Tally(Night()))
end
local function PickTarget()
if not InCyrodiil()then
Say(NOT_IN_CYRODIIL)
return nil
end
local wantWaypoint=sv.waypoint==true
local personality=PersonalityKey()
local P=Personalities()
local needMap=wantWaypoint or P~=nil
return OnCyrodiilMap(function()
attacked,markers,bars={},nil,nil
local spot=PlayerSpot()
if not SettleLastCall(spot)then
Diag("The map is still loading. Try again in a moment.")
return nil
end
local mine=GetUnitAlliance("player")
local targets=PickTargets()
if sv.skooma and#targets>0 then
for _,t in ipairs(targets)do
local ok,owner=pcall(GetKeepAlliance,t.keepId,Context())
if ok then t.owner=owner end
end
local line=Drunk(SkoomaCall(targets,mine,spot))
Say(line)
return line
end
local potatoDue,potatoNext
if personality=="bakedpotato" and#targets>0 then
if type(sv.memory)~="table" then sv.memory={}end
local callsLeft=sv.memory.potatoIn or Random(2,5)
if callsLeft<=0 then
potatoDue,potatoNext=true,Random(2,5)
else
sv.memory.potatoIn=callsLeft - 1
end
end
local function TakeBreak()
sv.memory.potatoIn=potatoNext
local line=Drunk(PotatoBreak(targets,mine,spot))
Say(line)
return line
end
if sv.mean==true and personality=="deano" and(sv.streakL or 0)>10 and Random(1,3)==1 then
local line=Drunk(SKOOMA_AWAY[Random(1,#SKOOMA_AWAY)])
Say(line)
return line
end
local options,loading={},0
for _,t in ipairs(targets)do
local ok,owner=pcall(GetKeepAlliance,t.keepId,Context())
if ok then t.owner=owner end
if ok and not ALLIANCE_NAMES[owner] then
loading=loading+1
elseif ok and owner~=mine then
t.owner,t.defend=owner,false
table.insert(options,t)
elseif ok and DEFENDABLE[t.kind] and UnderAttack(t.keepId)then
t.owner,t.defend=owner,true
table.insert(options,t)
end
end
if#options==0 then
if loading>0 then
Diag("The map is still loading. Try again in a moment.")
else
Say("We already own everything and nothing is under attack. Go touch grass.")
end
return nil
end
local switchedOn={}
for _,t in ipairs(options)do
if sv[KIND_SETTING[t.kind] or ""]~=false then table.insert(switchedOn,t)end
end
if#switchedOn==0 then
Say("Nothing to pick with those target types switched off. Turn some back on in Objectives.")
return nil
end
options=switchedOn
local travel,positioned
if needMap and LazyCrown.Travel then
for _,t in ipairs(targets)do t.x,t.y=PinPosition(t.keepId)end
positioned=true
if spot then
local okT,route=pcall(LazyCrown.Travel.New,mine,Context(),{x=spot.x,y=spot.y},targets,KeepName,UnderAttack)
if okT then travel=route end
end
end
if travel then
local reachable={}
for _,t in ipairs(options)do
local tooLate=false
if(t.kind=="Lumbermill" or t.kind=="Farm" or t.kind=="Mine")and UnderAttack(t.keepId)then
local leg=travel(t)
tooLate=leg~=nil and leg.seconds>FLAGGED_RESOURCE_SECONDS
end
if not tooLate then table.insert(reachable,t)end
end
if#reachable>0 then options=reachable end
end
local G=LazyCrown.Group
local lowDps
if sv.groupSize==true and G then
local ok,size,dps=pcall(G.Roles)
if ok and size and dps then
if size==2 or size==3 then lowDps=Random(1,2)==1
else lowDps=size>=2 and dps<math.max(4,math.ceil(size/2))end
end
if ok and size then
local fits={}
for _,t in ipairs(options)do
if size>=(MIN_GROUP[t.kind] or 0)or Supported(t,mine)then table.insert(fits,t)end
end
options=fits
end
end
local everything={unpack(options)}
if#options>1 and lastKeepId then
for i,t in ipairs(options)do
if t.keepId==lastKeepId then table.remove(options,i)break end
end
end
if#options>1 and overrideKeepId then
for i,t in ipairs(options)do
if t.keepId==overrideKeepId then table.remove(options,i)break end
end
end
local plan,world
local choose=P and P[personality]
if choose then
world=BuildWorld(mine,options,targets,needMap,positioned,spot)
world.everything=everything
world.lastType=lastType
world.lowDps=lowDps
local last=sv.lastDecidedCall
if justSettled=="W" and last and last.plan and last.planKey==personality then world.planned=last.plan[1] end
world.justSettled=justSettled
if travel then
world.Route=travel
world.Away=function(t)
local leg=travel(t)
return leg and leg.seconds/LazyCrown.Travel.SECONDS_PER_UNIT
end
end
if potatoDue then
local okS,stand=pcall(P.LastStand,world)
if not(okS and stand)then return TakeBreak()end
end
local ok,result=pcall(choose,world)
if ok and type(result)=="table" and result.pick then plan=result end
if ok and type(result)=="table" and not result.pick and type(result.say)=="string" then
local line=Drunk(result.say)
Say(line)
return line
end
end
local pick=plan and plan.pick
if not pick then
if#options==0 then
Say("Not enough of you here for what's left. Outposts need 4 and keeps need 8.")
return nil
end
if world and P and P.LazyPick then
local okLazy,lazy=pcall(P.LazyPick,world)
if okLazy and type(lazy)=="table" and lazy.pick then pick=lazy.pick end
end
pick=pick or OneOf({Random=Random,lastType=lastType},options)
end
lastKeepId,overrideKeepId=pick.keepId,nil
lastType=TypeOf(pick)
if world and P and P.NoteWay then pcall(P.NoteWay,world,pick)end
local extras=plan and plan.extras
local leg=travel and travel(pick)
local how=leg and(leg.line or leg.ride)
if plan and plan.how then
how=plan.how
elseif leg and sv.showEta then
local eta=LazyCrown.Travel.Eta(leg.seconds)
how=how and(how:gsub("%.$",", " .. eta .. "."))or("It's right there, " .. eta .. ".")
end
if how then
extras={how}
for _,more in ipairs(plan and plan.extras or{})do table.insert(extras,more)end
end
local tail
local streakLine=(sv.streakL or 0)>=3 and P and P.StreakTail and P.StreakTail(personality,mine,sv.insideJokes==true)
if streakLine then tail={streakLine}end
if personality=="diil" and not pick.unscored then
if type(sv.memory)~="table" then sv.memory={}end
if not quickReroll then sv.memory.diilSnackIn=(sv.memory.diilSnackIn or Random(5,10))- 1 end
if(sv.memory.diilSnackIn or 1)<=0 then
sv.memory.diilSnackIn=Random(5,10)
local lines=Random(1,2)==1 and POTATO_HUNGRY or POTATO_SMOKE
tail=tail or{}
table.insert(tail,lines[Random(1,#lines)])
end
end
if sv.mean==true and(sv.streakL or 0)>=5 and PAYING_US[personality] and Random(1,2)==1 then
tail=tail or{}
table.insert(tail,"At this point the enemy should be paying us.")
end
local alt
if pick.x and not pick.defend and not pick.directive then
local best,bestD,sameKind
for _,t in ipairs(options)do
local dx,dy=(t.x or 99)- pick.x,(t.y or 99)- pick.y
local d=math.sqrt(dx*dx+dy*dy)
local same=TypeOf(t)==TypeOf(pick)
if t.keepId~=pick.keepId and not t.defend and d<=0.2 and(not best or(same and not sameKind)or(same==sameKind and d<bestD))then
best,bestD,sameKind=t,d,same
end
end
alt=best and best.name
end
local wording={variants=true,grenade=plan and plan.grenade,seconds=leg and leg.seconds,alt=alt}
local line=Drunk(CallLine(pick,mine,extras,tail,plan and plan.quietTarget,wording),pick.owner)
Say(line)
local steps
if world and P and P.PlanAhead then
local okPlan,ahead=pcall(P.PlanAhead,personality,world,pick,sv.showPlan==false and 2 or nil)
if okPlan and type(ahead)=="table" and#ahead>1 then steps=ahead end
end
local planIds
if steps then
local names={}
planIds={}
for i=2,#steps do table.insert(planIds,steps[i].keepId);table.insert(names,steps[i].name)end
if sv.showPlan~=false then SayPlan(table.concat(names,", then ").. ".")end
end
if not pick.unscored then OpenCall(pick,mine,planIds,personality)end
if wantWaypoint and SetWaypoint(pick.keepId)then
Diag("Waypoint set on your map.")
end
return line
end,needMap)
end
local CHAT_MENU_SCENE="gamepadChatMenu"
local pendingText,pendingRaw=nil,nil
local function FillChatPageBox(line,raw)
local edit=CHAT_MENU_GAMEPAD and CHAT_MENU_GAMEPAD.textEdit
if not edit then return false,"Chat page text box not found" end
if raw then
local ok,err=pcall(function()edit:SetText(line)end)
if not ok then return false,tostring(err)end
return true
end
local okMax,max=pcall(function()return edit:GetMaxInputChars()end)
local room=okMax and type(max)=="number" and max>0 and max -#Tag()or nil
if room and room>0 and#line>room then
line=line:sub(1,room+1):match("^(.*[%.!%?])%s")or line:sub(1,room):gsub("[\192-\255][\128-\191]*$","")
end
local ok,err=pcall(function()
edit:SetText("")
edit:InsertText(Tag())
edit:InsertText(line)
end)
if not ok then return false,tostring(err)end
return true
end
local function IsSendBlocked()
local page=CHAT_MENU_GAMEPAD
local desc=page and page.textInputAreaKeybindDescriptor
if not(desc and IsTrustedFunction)then return false end
for _,button in ipairs(desc)do
if type(button)=="table" and type(button.callback)=="function" then
local ok,trusted=pcall(IsTrustedFunction,button.callback)
if ok and trusted==false then return true end
end
end
return false
end
local function ReportFill(ok,err)
if not ok then
Diag("Could not paste: " .. tostring(err))
elseif IsSendBlocked()then
Diag(Buttons("Send is blocked this session. Reload UI, open Text Chat once, then pick again."))
end
end
local chatHooked=false
local OnChatPageStateChange
local function HookChatPage(on)
if chatHooked==on then return end
local ok,err=pcall(function()
local chatPage=SCENE_MANAGER and SCENE_MANAGER.GetScene and SCENE_MANAGER:GetScene(CHAT_MENU_SCENE)
if not chatPage then return end
if on then chatPage:RegisterCallback("StateChange",OnChatPageStateChange)
else chatPage:UnregisterCallback("StateChange",OnChatPageStateChange)end
chatHooked=on
end)
if not ok then pcall(Diag,"Chat page hookup failed: " .. tostring(err))end
end
OnChatPageStateChange=function(oldState,newState)
if newState==SCENE_SHOWN and pendingText then
local text,raw=pendingText,pendingRaw
pendingText,pendingRaw=nil,nil
HookChatPage(false)
ReportFill(FillChatPageBox(text,raw))
end
end
local function PasteIntoChat(line,raw)
if not(SCENE_MANAGER and SCENE_MANAGER.IsShowing and zo_callLater)then
Diag("Could not paste: chat page API missing")
return
end
if SCENE_MANAGER:IsShowing(CHAT_MENU_SCENE)then
zo_callLater(function()ReportFill(FillChatPageBox(line,raw))end,1)
return
end
if not(CHAT_MENU_GAMEPAD and CHAT_MENU_GAMEPAD.initialized)then
Diag("Open Text Chat once (Main Menu > Text Chat), then pick again.")
return
end
pendingText,pendingRaw=line,raw
FillChatPageBox(line,raw)
HookChatPage(true)
local ok,err=pcall(SCENE_MANAGER.Show,SCENE_MANAGER,CHAT_MENU_SCENE)
if not ok then
pendingText,pendingRaw=nil,nil
HookChatPage(false)
Diag("Could not open the Chat page: " .. tostring(err))
return
end
zo_callLater(function()
if pendingText~=nil then
pendingText,pendingRaw=nil,nil
Diag("Chat page did not open within 3 seconds.")
end
HookChatPage(false)
end,3000)
end
local function PickPrivately()
PickTarget()
end
local function ChatReady()
if not(SCENE_MANAGER and SCENE_MANAGER.IsShowing and zo_callLater)then
Diag("Could not paste: chat page API missing")
return false
end
if SCENE_MANAGER:IsShowing(CHAT_MENU_SCENE)or(CHAT_MENU_GAMEPAD and CHAT_MENU_GAMEPAD.initialized)then
if IsSendBlocked()then
Diag(Buttons("Send is blocked this session. Reload UI, open Text Chat once, then pick again."))
return false
end
return true
end
Diag("Open Text Chat once (Main Menu > Text Chat), then pick again.")
return false
end
local function PickAndShare()
if not(InCyrodiil()and ChatReady())then
if not InCyrodiil()then Say(NOT_IN_CYRODIIL)end
return
end
local line=PickTarget()
if line then PasteIntoChat(line)end
end
local function ShowScoreboard()
SettleIfDecided()
Say(SummaryLine())
if sv.open then Diag(string.format("Still calling: %s.",sv.open.name))end
end
local function ShareScoreboard()
SettleIfDecided()
local line=SummaryLine()
Say(line)
if ChatReady()then PasteIntoChat(line)end
end
local function HistoryText(separator,max)
local night=Night()
local history=night.history or{}
if#history==0 then return nil end
local from=math.max(1,#history - max+1)
local parts={}
for i=from,#history do
local call=history[i]
table.insert(parts,string.format("%s %s%s",call.r,call.n,call.o and " (override)" or ""))
end
return table.concat(parts,separator),#history - from+1,math.max(#history,(night.w or 0)+(night.l or 0))
end
local function ShowHistory()
if InCyrodiil()then SettleIfDecided()end
local text,shown,total=HistoryText(", ",HISTORY_SHOW)
if not text then
Say("No W's or L's yet. History starts with your first one.")
else
Say(string.format("History%s: %s.",shown<total and string.format(" (last %d of %d)",shown,total)or "",text))
end
if sv.open then Diag(string.format("Still calling: %s.",sv.open.name))end
end
local FindTarget,Override,OverrideFromWheel
do
local OVERRIDE_LINE="/lazycrown override "
local OVERRIDE_TYPE="Type where you're going after override and press Send. Send it as is to use your last message."
local OVERRIDE_BACK="Your override is back in the box. Fix it or press Send."
local OVERRIDE_HOW="Type where you're going after /lazycrown override, like /lazycrown override Fort Ash."
local OVERRIDE_NOISE={fort=true,castle=true,keep=true,outpost=true,the=true,of=true,at=true,to=true,
ms=true,ls=true,fs=true,fd=true,front=true,door=true,side=true}
local OVERRIDE_ALIASES={lm="lumbermill",mill="lumbermill",brk="blue road",bb="black boot",bm="bloodmayne",
kc="kingscrest",wp="winters peak",claw="dragonclaw",dclaw="dragonclaw",lessi="alessia",less="alessia",
dlowe="drakelowe",fare="faregyl",roe="roebeck",harl="harluns",carm="carmala",gm="glademist",
ward="warden",ray="rayles",ales="aleswell",brin="brindle",crops="cropsford",vlas="vlastarus",
nik="nikel",sej="sejanus"}
local SIDE_OF={mine=true,lumber=true,lumbermill=true,mill=true,lm=true,farm=true}
local KIND_RANK={Keep=4,Outpost=3,Town=2}
local KIND_WORDS={mine=true,farm=true,lumbermill=true}
local function Words(text)
local words={}
text=text:lower():gsub("|c%x%x%x%x%x%x",""):gsub("|r",""):gsub("'","")
text=text:gsub("(%a+)%s+side",function(word)if SIDE_OF[word] then return " " end end)
for word in text:gmatch("%w+")do
local alias=OVERRIDE_ALIASES[word]
if alias then
for part in alias:gmatch("%a+")do table.insert(words,part)end
elseif not OVERRIDE_NOISE[word] then
table.insert(words,word)
end
end
return words
end
function FindTarget(text,targets)
local number=tonumber(text:match("^%s*#?(%d+)%s*$")or "")
if number then
for _,t in ipairs(targets)do if t.number==number then return t end end
return nil
end
local typed=Words(text)
if#typed==0 then return nil end
local best,bestScore,tied=nil,nil,{}
for _,t in ipairs(targets)do
local words=Words(t.name)
local matched,named=0,false
for _,word in ipairs(words)do
for _,typedWord in ipairs(typed)do
if typedWord==word or(#typedWord>=3 and word:sub(1,#typedWord)==typedWord)
or(#typedWord>=4 and typedWord:sub(-1)=="s" and typedWord:sub(1,-2)==word)then
matched=matched+1
named=named or not KIND_WORDS[word]
break
end
end
end
if matched>0 and named then
local score=matched*100+(matched==#words and 50 or 0)+(KIND_RANK[t.kind] or 1)-#words
if not bestScore or score>bestScore then best,bestScore,tied=t,score,{t.name}
elseif score==bestScore then table.insert(tied,t.name)end
end
end
if#tied>1 then return nil,tied end
return best
end
local function BoxText()
local ok,typed=pcall(function()return CHAT_MENU_GAMEPAD.textEdit:GetText()end)
local text=ok and type(typed)=="string" and typed or ""
if text:lower():find("^%s*/lazycrown")or not text:find("%S")then return nil end
return text
end
local function OverrideText()
local text=BoxText()
if text then return text,false end
local okL,line=pcall(function()
local me=GetDisplayName()
local log=CHAT_MENU_GAMEPAD.messageEntries or{}
for i=#log,math.max(1,#log - 20),-1 do
local data=log[i].data
if data and data.fromDisplayName==me then return data.rawMessageText end
end
end)
if okL and type(line)=="string" and line:find("%S")and not line:find("^%s*/")then return line,true end
end
local function Retype(text,fromLog)
if not(SCENE_MANAGER and SCENE_MANAGER.IsShowing and SCENE_MANAGER:IsShowing(CHAT_MENU_SCENE))then return end
PasteIntoChat(OVERRIDE_LINE ..((not fromLog and text)or ""),true)
end
function Override(text)
local fromLog=false
if not(text and text:find("%S"))then text,fromLog=OverrideText()end
if not(text and text:find("%S"))then Diag(OVERRIDE_HOW);Retype();return end
if text:find("[Lazy Crown",1,true)then Diag("That's Lazy Crown's own call. " .. OVERRIDE_HOW);Retype();return end
local t,couldBe=FindTarget(text,PickTargets())
if not t and couldBe then
local last=table.remove(couldBe)
Diag(string.format("%s could be %s or %s. Type a bit more of the name.",text,table.concat(couldBe,", "),last))
Retype(text,fromLog)
return
elseif not t then
Diag(string.format("Can't find %s. Try a name like Fort Ash or Ash Mine, or a number from /lazycrown list.",text))
Retype(text,fromLog)
return
end
attacked={}
local mine=GetUnitAlliance("player")
local okO,owner=pcall(GetKeepAlliance,t.keepId,Context())
if not(okO and ALLIANCE_NAMES[owner])then
Diag("The map is still loading. Try again in a moment.")
Retype(text,fromLog)
return
end
if owner==mine and not UnderAttack(t.keepId)then
Diag(string.format("We already hold %s and nobody's attacking it.",t.name))
return
end
SettleIfDecided()
local already=sv.open and sv.open.keepId==t.keepId
OnCyrodiilMap(function()
if sv.open and not already then
if Since(sv.open.at)<VOID_SECONDS then
Settle("void","you picked your own target")
elseif not SettleLastCall(PlayerSpot())then
Diag("The map is still loading. Try again in a moment.")
Retype(text,fromLog)
return
end
end
if already then
sv.open.override=true
else
t.defend=(owner==mine)or nil
OpenCall(t,mine,nil,PersonalityKey())
sv.open.override=true
overrideKeepId,lastType=t.keepId,TypeOf(t)
local P=t.parent and not t.defend and Personalities()
if P and P.NoteWay then
local okP,parentOwner=pcall(GetKeepAlliance,t.parent,Context())
if okP and ALLIANCE_NAMES[parentOwner] then
if type(sv.memory)~="table" then sv.memory={}end
pcall(P.NoteWay,{memory=sv.memory,now=Now(),mine=mine,
byId={[t.parent]={keepId=t.parent,owner=parentOwner}}},t)
end
end
end
Say(string.format("Override: %s%s%s. That's the one I'll judge W or L on.",sv.open.defend and "defend " or "",sv.open.name,
fromLog and " (from your last message)" or ""))
if sv.waypoint==true and SetWaypoint(t.keepId)then Diag("Waypoint set on your map.")end
end)
RefreshSettings()
end
function OverrideFromWheel()
local typed=BoxText()
local paste=typed and(typed:find("[Lazy Crown",1,true)or typed:find("^%s*%[[^%]]+%]"))
if typed and not paste then return Override(typed)end
if not ChatReady()then return end
local ok,box=pcall(function()return CHAT_MENU_GAMEPAD.textEdit:GetText()end)
local started=ok and type(box)=="string" and box:lower():find("^%s*/lazycrown%s+override%s+%S")and box
PasteIntoChat(started or OVERRIDE_LINE,true)
Diag(started and OVERRIDE_BACK or OVERRIDE_TYPE)
end
end
local function ListTargets()
local targets,total=BuildTargets()
for _,t in ipairs(targets)do
Diag(string.format("#%d %s (%s side)",t.number,t.name,ALLIANCE_NAMES[t.home] or "middle"))
end
if#targets<total then Diag(string.format("%d of %d targets found.",#targets,total))end
end
local SCROLL_NAMES={[118]="Altadoon",[119]="Mnem",[120]="Ghartok",[121]="Chim",[122]="Ni-Mohk",[123]="Alma Ruma"}
local HOW_TO_USE="First turn on HUD Chat Display in Settings > Social, or you won't see Lazy Crown's lines on screen. In Cyrodiil, pick from the addon quickslot wheel, or type /lazycrown in Text Chat. Lazy Crown randomly picks a keep, lumbermill, farm, mine, town or outpost your alliance doesn't hold, or one of your keeps or outposts that is under attack. Pick who's wearing the crown under Personalities. Functions: Private Command (crown gems): just for you, where to go shows in your chat window only. Crown Command (gold crown): your call-out, it also goes in the Text Chat box on the channel you last used. Note: If you have not opened chat yet, Lazy Crown will remind you to do this instead to prevent a UI error. Make sure you choose the right chat channel! Press X to send. Press A to edit or delete."
local WHEEL_SETUP='Hit start and go to the addons menu. Open LibRadialMenu settings. Ensure the wheel location is set to a value between 1 and 6. Then open Lazy Crown > Wheel slots and press Put on (or Move on each one). Skip LibRadialMenu\'s Assign Slots because it breaks whispers, group invites, Enter Now and respawning until you Reload UI. Hit start to close the menu. Open your quickslot wheel by pressing up on the d-pad. Browse to Addon Entries using LT or RT, then pick! See "How to use" if this is your first time.'
local SCOREBOARD_HELP="Every call is a W or an L, checked when you make your next call. Took it already? Scoreboard counts it right away. Taking: W if it's yours by then, otherwise L. Defending: W if it's still yours and the attack is over, L if it fell. Picking again within 90 seconds, or while a defense is still going, doesn't count against the last call, unless it was a defense that already fell. A call you're nowhere near by your next call doesn't count either, W or L. Following the hammer doesn't count. The scoreboard keeps this run's record until you reset it, even if you change personalities. Scoreboard on the wheel places it in the Text Chat box."
local CHAT_COMMANDS="Where typing in chat is available: /lazycrown picks a target for your chat window only. /lazycrown share is Crown Command: it also places the call in the Text Chat box. /lazycrown scoreboard shows the scoreboard, /lazycrown scoreboard share places it in the Text Chat box, and /lazycrown scoreboard reset resets it. /lazycrown history shows your calls this run. /lazycrown override Fort Ash makes Fort Ash the call Lazy Crown judges W or L on. /lazycrown personality puts the next personality on the crown, or /lazycrown personality chris (or any name) picks one. /lazycrown group shows your group size, roles and big ultimates. /lazycrown list shows every numbered target."
local function WearCrown(key)
local P=Personalities()
if not(P and P.NAMES[key])then return end
sv.personality=key
Say(string.format("%s is wearing the crown now.",P.NAMES[key]))
RefreshSettings()
end
local SCROLL_TEMPLES={[AD]={118,119},[EP]={120,121},[DC]={122,123}}
local POP_WORDS={"0 bars","1 bar","2 bars","full"}
local function Duration(seconds)
local minutes=math.floor(seconds/60)
local days,hours=math.floor(minutes/1440),math.floor(minutes/60)%24
if days>0 then return string.format("%dd %dh",days,hours)end
if hours>0 then return string.format("%dh %dm",hours,minutes%60)end
if minutes==0 then return "under a minute" end
return string.format("%dm",minutes)
end
local function Comma(n)
local ok,text=pcall(ZO_CommaDelimitNumber,n)
return ok and type(text)=="string" and text or tostring(n)
end
local function Who(characterName,displayName)
local name=type(characterName)=="string" and characterName~="" and characterName or nil
if name then
local ok,formatted=pcall(zo_strformat,"<<1>>",name)
name=ok and type(formatted)=="string" and formatted or(name:gsub("%^.*$",""))
end
local at=type(displayName)=="string" and displayName~="" and displayName or nil
if name and at and at~=name then return string.format("%s (%s)",name,at)end
return name or at
end
local function EmperorLine(campaignId)
local ok,has=pcall(DoesCampaignHaveEmperor,campaignId)
if not(ok and has)then return "No emperor right now." end
local okI,alliance,characterName,displayName=pcall(GetCampaignEmperorInfo,campaignId)
local okD,seconds=pcall(GetCampaignEmperorReignDuration,campaignId)
local who=okI and Who(characterName,displayName)or "Someone"
local side=okI and SHORT[alliance]
return string.format("Emperor is %s%s%s.",who,side and(" for " .. side)or "",
okD and type(seconds)=="number" and seconds>0 and(", " .. Duration(seconds).. " so far")or "")
end
local function PopulationLine()
bars=nil
local parts={}
for _,alliance in ipairs(ROTATION)do
local bar=PopulationBars(alliance)
if bar then table.insert(parts,SHORT[alliance] .. " " .. POP_WORDS[bar])end
end
if#parts==0 then return "Population isn't in yet. Check again in a moment." end
return "Population is " .. table.concat(parts,", ").. "."
end
local function ScoreLine(campaignId)
local parts={}
for _,alliance in ipairs(ROTATION)do
local ok,score=pcall(GetCampaignAllianceScore,campaignId,alliance)
if ok and type(score)=="number" then table.insert(parts,string.format("%s %s",SHORT[alliance],Comma(score)))end
end
if#parts==0 then return nil end
local okE,seconds=pcall(GetSecondsUntilCampaignScoreReevaluation,campaignId)
local eval=okE and type(seconds)=="number" and seconds>=0 and string.format(" Next eval in %s.",Duration(seconds))or ""
return "Score is " .. table.concat(parts,", ").. "." .. eval
end
local function NearestPlace(x,y)
if type(x)~="number" or type(y)~="number" or(x==0 and y==0)then return nil end
local best,bestD
for _,t in ipairs(PickTargets())do
if t.kind=="Keep" or t.kind=="Outpost" or t.kind=="Town" then
local tx,ty=PinPosition(t.keepId)
if tx and ty and(tx~=0 or ty~=0)then
local d=(tx - x)^2+(ty - y)^2
if not bestD or d<bestD then best,bestD=t.name,d end
end
end
end
return best
end
local function ScrollsLine(mine)
local away,read,ctx={},0,Context()
for _,temple in ipairs(SCROLL_TEMPLES[mine] or{})do
local name=SCROLL_NAMES[temple]
local okO,objectiveId=pcall(GetKeepArtifactObjectiveId,temple)
local okS,state=pcall(GetObjectiveControlState,temple,objectiveId,ctx)
local known=okO and objectiveId and okS and state~=nil and OBJECTIVE_CONTROL_STATE_FLAG_AT_BASE~=nil
and state~=OBJECTIVE_CONTROL_STATE_UNKNOWN
if known then read=read+1 end
if known and state~=OBJECTIVE_CONTROL_STATE_FLAG_AT_BASE then
local okP,_,x,y=pcall(GetObjectivePinInfo,temple,objectiveId,ctx)
local near=okP and NearestPlace(x,y)or nil
if state==OBJECTIVE_CONTROL_STATE_FLAG_AT_ENEMY_BASE then
local okK,keepId=pcall(GetKeepThatHasCapturedThisArtifactScrollObjective,temple,objectiveId,ctx)
local okA,owner=pcall(GetKeepAlliance,keepId,ctx)
if okK and type(keepId)=="number" and keepId>0 then
table.insert(away,string.format("%s is in %s%s.",name,KeepName(keepId,"an enemy keep"),
okA and SHORT[owner] and(" (" .. SHORT[owner] .. ")")or ""))
else
table.insert(away,string.format("%s is in an enemy keep.",name))
end
elseif state==OBJECTIVE_CONTROL_STATE_FLAG_HELD then
local okC,characterName,displayName=pcall(GetCarryableObjectiveHoldingCharacterInfo,temple,objectiveId,ctx)
local okH,holder=pcall(GetCarryableObjectiveHoldingAllianceInfo,temple,objectiveId,ctx)
if not okH then holder=nil end
local who=okC and Who(characterName,displayName)or nil
table.insert(away,string.format("%s is being %s%s%s.",name,holder==mine and "carried home" or "carried",
who and(" by " .. who ..(holder~=mine and SHORT[holder] and(" (" .. SHORT[holder] .. ")")or ""))or "",
near and(" near " .. near)or ""))
else
table.insert(away,string.format("%s is on the ground%s.",name,near and(" near " .. near)or ""))
end
end
end
if read==0 then return "Can't see our scrolls right now." end
if#away==0 then return read==2 and "Both our scrolls are home." or "The scroll I can see is home." end
return table.concat(away," ")
end
local function GroupCheck()
LoadTheRest()
local G=LazyCrown.Group
if not G then return end
local t=G.Tally()
Say(G.Line(t))
if t.away>0 then
Diag(string.format("%d more in the group %s here.",t.away,t.away==1 and "isn't" or "aren't"))
end
if t.size>1 and not G.Sharing()then
Diag("Only your own ultimates are counted. Install LibGroupCombatStats to see everyone's.")
elseif t.sharing<t.size then
Diag(string.format("Ultimates counted for %d of %d. The rest need LibGroupCombatStats with Hodor Reflexes or Artaeum Group Tool.",
t.sharing,t.size))
end
if not InCyrodiil()then return end
local campaignId=GetCurrentCampaignId and GetCurrentCampaignId()
if not campaignId or campaignId==0 then return end
OnCyrodiilMap(function()
Say(EmperorLine(campaignId))
Say(PopulationLine())
local score=ScoreLine(campaignId)
if score then Say(score)end
Say(ScrollsLine(GetUnitAlliance("player")))
end)
end
local function CyclePersonality()
local P=Personalities()
if not P then return end
local current,order=PersonalityKey(),P.ORDER
for i,key in ipairs(order)do
if key==current then return WearCrown(order[i%#order+1])end
end
WearCrown(order[1])
end
local WHEEL_ORDER={"1share","2persona","3record","4reset","5group","6pick","7history","8override"}
local WHEEL_ROWS={{"2persona","Change Personality"},{"1share","Crown Command"},{"5group","Group Check"},
{"7history","History"},{"8override","Override"},{"6pick","Private Command"},{"4reset","Reset Scoreboard"},
{"3record","Scoreboard"}}
local COLORS={{"Blue","4FA8FF"},{"Cyan","33F0FF"},{"Gold","F2C65A"},{"Green","4CFF4C"},{"Grey","9A9A9A"},
{"Hot pink","FF4FD8"},{"Neon orange","FF5F1F"},{"Purple","B98CFF"},{"Red","FF3333"},{"White","FFFFFF"},
{"Yellow","FFF23F"}}
local function ColorName(name,hex)return string.format("|c%s%s|r",hex,name)end
local COLOR_ITEMS,COLOR_INDEX={},{}
for i,color in ipairs(COLORS)do
COLOR_ITEMS[i]={name=ColorName(color[1],color[2]),data=color[2]}
COLOR_INDEX[color[2]]=i
end
local function Alert(text)
pcall(function()
local alert=ZO_AlertNoSuppression or ZO_Alert
if alert then alert(UI_ALERT_CATEGORY_ALERT,nil,"[Lazy Crown] " .. text)end
end)
end
local function WheelSlots()
local lib=LibRadialMenu
local slots=lib and lib.libRadialWheelEntries
if type(slots)~="table" then return nil end
return slots,(type(lib.vars)=="table" and tonumber(lib.vars.numSlots))or#slots
end
local function SlotOf(slots,n,id)
for i=1,n do
local s=slots[i]
if type(s)=="table" and s.addon==ADDON_NAME and s.entry==id then return i end
end
end
local function FreeSlot(slots,n,after)
for i=(after or 0)+1,n do
local s=slots[i]
if s==nil or(type(s)=="table" and s.addon==nil and s.entry==nil)then return i end
end
end
local function MoveOnWheel(id)
local slots,n=WheelSlots()
if not slots then Alert("LibRadialMenu's wheel isn't loaded.");return end
local at=SlotOf(slots,n,id)
local to=FreeSlot(slots,n,at)
if not(at or to)then Alert("No free wheel slots. Take something off first.");return end
if at then slots[at]={}end
if to then slots[to]={entry=id,addon=ADDON_NAME}end
RefreshSettings()
end
local function LonelySlot(slots,n)
local function free(i)
local s=slots[(i - 1)%n+1]
return s==nil or(type(s)=="table" and s.addon==nil and s.entry==nil)
end
for i=1,n do
if free(i)and free(i - 1)and free(i+1)then return i end
end
return FreeSlot(slots,n)
end
local function AllOnWheel()
local slots,n=WheelSlots()
if not slots then Alert("LibRadialMenu's wheel isn't loaded.");return end
local noRoom=0
for _,id in ipairs(WHEEL_ORDER)do
if id~="4reset" and not SlotOf(slots,n,id)then
local to=FreeSlot(slots,n)
if to then slots[to]={entry=id,addon=ADDON_NAME}else noRoom=noRoom+1 end
end
end
if not SlotOf(slots,n,"4reset")then
local to=LonelySlot(slots,n)
if to then slots[to]={entry="4reset",addon=ADDON_NAME}else noRoom=noRoom+1 end
end
if noRoom>0 then Alert(string.format("No room for %d of them. Take something off the wheel first.",noRoom))end
RefreshSettings()
end
local function SettingsRows()
local lib=LibHarvensAddonSettings
if not(lib and lib.ST_LABEL and lib.ST_SECTION)then return{}end
local LABEL,SECTION,BUTTON,CHECKBOX,DROPDOWN=lib.ST_LABEL,lib.ST_SECTION,lib.ST_BUTTON or 6,lib.ST_CHECKBOX or 1,lib.ST_DROPDOWN or 4
local rows={
{type=SECTION,label="General"},
{type=LABEL,label="How to use",tooltip=function()return Buttons(HOW_TO_USE)end},
{type=LABEL,label="Wheel setup",tooltip=function()return Buttons(WHEEL_SETUP)end},
{type=LABEL,label="Chat commands",tooltip=CHAT_COMMANDS},
}
table.insert(rows,{type=SECTION,label="Wheel slots"})
table.insert(rows,{type=BUTTON,label="All of them",buttonText="Put on",
tooltip="Puts every Lazy Crown entry on a free slot of the Addon Entries wheel. Use this instead of LibRadialMenu's Assign Slots. That one breaks whispers, group invites, Enter Now and respawning until you Reload UI. Wheel Location in LibRadialMenu has to be above 0.",
clickHandler=AllOnWheel})
for _,entry in ipairs(WHEEL_ROWS)do
local id,name=entry[1],entry[2]
table.insert(rows,{
type=BUTTON,buttonText="Move",
label=function()
local slots,n=WheelSlots()
local at=slots and SlotOf(slots,n,id)
return name ..(at and string.format(" (slot %d)",at)or " (off the wheel)")
end,
tooltip=string.format("Moves %s to the next free slot on the Addon Entries wheel. After the last one it comes off.",name),
clickHandler=function()MoveOnWheel(id)end,
})
end
table.insert(rows,{type=SECTION,label="Personalities"})
for _,key in ipairs(CROWN_ORDER)do
table.insert(rows,{
type=BUTTON,buttonText="Wear the crown",
tooltip=function()local P=Personalities();return P and P.TOOLTIPS[key] or "" end,
label=function()
local P=Personalities()
return((P and P.NAMES[key])or key)..(PersonalityKey()==key and " (wearing the crown)" or "")
end,
clickHandler=function()WearCrown(key)end,
})
end
for _,row in ipairs({
{type=SECTION,label="Options"},
{type=CHECKBOX,label="Continuous Attack",
tooltip="Any crown grabs a resource on the way when your Continuous Attack is running low.",
getFunction=function()return sv.continuousAttack~=false end,
setFunction=function(on)sv.continuousAttack=on==true end,default=true},
{type=CHECKBOX,label="Set a waypoint",
tooltip="Puts a waypoint on your map for every call.",
getFunction=function()return sv.waypoint==true end,
setFunction=function(on)sv.waypoint=on==true end,default=false},
{type=CHECKBOX,label="Show the plan",
tooltip="After each call, your chat window shows the next few calls the crown has in mind if this one goes our way. Only you see it.",
getFunction=function()return sv.showPlan~=false end,
setFunction=function(on)sv.showPlan=on==true end,default=true},
{type=CHECKBOX,label="Show travel times",
tooltip="Adds about how long it takes to get there, like 'Ride north, about 45 seconds.'",
getFunction=function()return sv.showEta==true end,
setFunction=function(on)sv.showEta=on==true end,default=false},
{type=CHECKBOX,label="Size up the group",
tooltip="No outposts under 4 people and no keeps under 8. Still calls them if our siege is already up or we're winning a fight there.",
getFunction=function()return sv.groupSize==true end,
setFunction=function(on)sv.groupSize=on==true end,default=false},
{type=SECTION,label="Objectives"},
})do table.insert(rows,row)end
for _,kind in ipairs({
{"Keeps","pickKeeps","keeps"},{"Outposts","pickOutposts","outposts"},
{"Resources","pickResources","lumbermills, farms and mines"},{"Towns","pickTowns","towns"},
})do
local key=kind[2]
table.insert(rows,{type=CHECKBOX,label=kind[1],
tooltip=string.format("Lets the crown pick %s.",kind[3]),
getFunction=function()return sv[key]~=false end,
setFunction=function(on)sv[key]=on==true end,default=true})
end
for _,row in ipairs({
{type=SECTION,label="Tone"},
{type=CHECKBOX,label="Drunk",
tooltip="Same calls, a few drinks in. *hic*",
getFunction=function()return sv.drunk==true end,
setFunction=function(on)sv.drunk=on==true end,default=false},
{type=CHECKBOX,label="Inside jokes",
tooltip="Lines about people from our crew, like Mulliss, sgx and TKL. Leave it off if your group doesn't know them.",
getFunction=function()return sv.insideJokes==true end,
setFunction=function(on)sv.insideJokes=on==true end,default=false},
{type=CHECKBOX,label="Mean",
tooltip="Same calls, worse attitude.",
getFunction=function()return sv.mean==true end,
setFunction=function(on)sv.mean=on==true end,default=false},
{type=CHECKBOX,label="Skooma",
tooltip="Really out of it. Calls anything at random, even what we already have (that's a W, then a break for more skooma). Sometimes sends you across the map, tells everyone to go away, or won't call at all (that's an L). Says weird things.",
getFunction=function()return sv.skooma==true end,
setFunction=function(on)sv.skooma=on==true end,default=false},
})do table.insert(rows,row)end
table.insert(rows,{type=SECTION,label="Colors"})
for _,kind in ipairs({
{"calls","Calls",TEXT_COLOR,"Calls, W and L lines, History and the scoreboard."},
{"plan","Plan",PLAN_COLOR,"The [Lazy Crown - Plan] line after each call."},
{"status","Status",DIAG_COLOR,"Reminders, notes and help."},
})do
local key,fallback=kind[1],kind[3]
table.insert(rows,{type=DROPDOWN,label=kind[2],tooltip=kind[4],items=COLOR_ITEMS,
getFunction=function()return COLOR_ITEMS[COLOR_INDEX[Hex(key,fallback)] or COLOR_INDEX[fallback]].name end,
setFunction=function(_,_,item)
if type(item)=="table" and COLOR_INDEX[item.data] then sv.colors[key]=item.data end
end,
default=COLOR_INDEX[fallback]})
end
for _,row in ipairs({
{type=SECTION,label="Scoreboard"},
{type=LABEL,label=function()return string.format("Scoreboard (%s): %s",PersonalityName(),Tally(Night()))end,
tooltip=SCOREBOARD_HELP},
{type=LABEL,label="History",
tooltip=function()
local text=HistoryText("\n",HISTORY_KEEP)
return "This run's calls, oldest first. Resetting the scoreboard clears them too.\n\n" ..(text or "No W's or L's yet.")
end},
{type=BUTTON,label="Reset scoreboard",
buttonText="Reset",
tooltip="Clears the scoreboard and its history.",clickHandler=ResetScoreboard},
})do table.insert(rows,row)end
for _,row in ipairs(rows)do
for _,field in ipairs({"label","tooltip","getFunction","setFunction","clickHandler"})do
if type(row[field])=="function" then row[field]=Used(row[field])end
end
end
return rows
end
local InCyrodiilCommand=CyrodiilOnly(function(word,args)
if word=="scoreboard" then
local action=(args or ""):lower():match("^%s*%a+%s+(%a+)")
if action=="share" then ShareScoreboard()
elseif action=="reset" then ResetScoreboard()
else ShowScoreboard()end
elseif word=="list" then ListTargets()
elseif word=="override" then Override((args or ""):match("^%s*%a+%s+(.-)%s*$"))
elseif word=="share" then PickAndShare()
elseif word=="" then PickPrivately()end
end)
local COMMANDS={[""]=true,share=true,scoreboard=true,history=true,override=true,personality=true,
group=true,list=true}
local function SlashCommand(args)
local word=(args or ""):lower():match("^%s*(%a*)")
if not COMMANDS[word] then
Diag(string.format("/lazycrown %s isn't a command. Try /lazycrown, share, scoreboard, history, override, personality, group or list.",word))
return
end
if word=="personality" then
local which=(args or ""):lower():match("^%s*%a+%s+(.-)%s*$")
local P=Personalities()
if not(which and which~="")then return CyclePersonality()end
local found
if P then
local wanted=which:gsub("%s","")
for key,name in pairs(P.NAMES)do if name:lower():gsub("%s","")==wanted then found=key end end
end
if found then
WearCrown(found)
elseif P then
local names={}
for _,key in ipairs(P.ORDER)do table.insert(names,P.NAMES[key])end
Diag(string.format("No crown called %s. Pick %s.",which,table.concat(names,", ")))
end
elseif word=="group" then GroupCheck()
elseif word=="history" then ShowHistory()
else InCyrodiilCommand(word,args)end
end
local started=false
Start=function()
if started then return end
pcall(function()
sv=ZO_SavedVars:NewAccountWide("LazyCrownSV",1,nil,{lifetime={},personality="lazy",waypoint=false,mean=false,
pickKeeps=true,pickResources=true,pickTowns=true,pickOutposts=true,streakL=0})
sv.lifetime=sv.lifetime or{}
end)
if type(sv.colors)~="table" then sv.colors={}end
chosenColors=sv.colors
LoadTheRest()
pcall(function()if LazyCrown.Group then LazyCrown.Group.Init()end end)
started=true
end
LazyCrown=LazyCrown or{}
LazyCrown.core={
PickAndShare=Used(PickAndShare),PickPrivately=Used(PickPrivately),CyclePersonality=Used(CyclePersonality),
ShareScoreboard=Used(CyrodiilOnly(ShareScoreboard)),ResetScoreboard=Used(CyrodiilOnly(ResetScoreboard)),
GroupCheck=Used(GroupCheck),SlashCommand=Used(SlashCommand),SettingsRows=SettingsRows,
History=Used(ShowHistory),Override=Used(CyrodiilOnly(OverrideFromWheel)),
}
LazyCrown=LazyCrown or{}
LazyCrown.BuildTargets,LazyCrown.PickTarget=BuildTargets,PickTarget
LazyCrown.Start,LazyCrown.CROWN_ORDER=Start,CROWN_ORDER
LazyCrown.StatusHex=function()return Hex("status",DIAG_COLOR)end
LazyCrown.FindTarget=FindTarget
LazyCrown.SummaryLine,LazyCrown.Record,LazyCrown.CallLine=SummaryLine,function()return sv end,CallLine
LazyCrown.OneOf,LazyCrown.TypeOf=OneOf,TypeOf
LazyCrown.ForgetLastCall=function()lastKeepId,lastType,overrideKeepId=nil,nil,nil end
LazyCrown.ForgetTargets=function()sessionTargets=nil end
LazyCrown.Quip=Quip
]=]})
