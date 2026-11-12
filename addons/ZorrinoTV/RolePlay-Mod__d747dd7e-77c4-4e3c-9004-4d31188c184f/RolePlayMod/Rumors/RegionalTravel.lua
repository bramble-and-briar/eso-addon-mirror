if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Public inter-region journeys. No waypoint is inferred from a compass bearing.
local B=IHR_Runtime.Beta
local D=B.Dice
local G=B.GeographicKnowledge
local E=B.LearnedQuestions
local T={};B.RegionalTravel=T
local function norm(s) return B.Normalize(type(s)=='string' and s or '') end
local function bare(s) return norm(s):gsub('^le ',''):gsub('^la ',''):gsub('^les ',''):gsub('^l ','') end
local function mentions(text,name) return (' '..norm(text)..' '):find(' '..bare(name)..' ',1,true)~=nil end
local sources={
 ad='https://elderscrolls.fandom.com/wiki/Selandilwen',
 dc='https://en.uesp.net/wiki/Online:Azoufah',
 ep='https://en.uesp.net/wiki/Online:Falvis_Raram',
 roost='https://en.uesp.net/wiki/Online:Sugar-Claws',
}
-- Only documented regional transport hubs; Marbruk is not a navigator arrival.
local rings={
 ad={{'Auridia','Guet de Vulkhel','aux quais'},{'Le bois de Graht','Faneracine','près des caravanes'},{'Prasin','Foyeraie','aux quais'},{'Malabal Tor','Vulkwasten','près des caravanes'},{'La marche de la Camarde','Rawl’kha','près des caravanes'}},
 dc={{'Glenumbrie','Daguefilante'},{'Havre-tempête','Haltevoie'},{'Fendretour','Taillemont'},{"Désert d’Alik’r",'Sentinelle'},{'Bangkorai','Abondance'}},
 ep={{'Éboulis','Guet de Davon','aux quais'},{'Deshaan','Longsanglot','derrière la Guilde des mages'},{'Fangeombre','Fort-Tempête','au nord des marchés de la rivière'},{'Estemarche','Vendeaume','aux quais'},{'La Brèche','Faillaise','aux quais'}},
}
local guides={ad='Selandilwën',dc='Azoufah',ep='Falvis Raram'}
local nodes,byRegion,edges,departures={},{},{},{}
local aliases={auridon='auridia',grahtwood='bois de graht',greenshade='prasin',glenumbra='glenumbrie',stormhaven='havre tempete',rivenspire='fendretour',["alik r desert"]='desert d alik r',stonefalls='eboulis',shadowfen='fangeombre',eastmarch='estemarche',['the rift']='breche',["reaper s march"]='marche de la camarde',["khenarthi s roost"]='perchoir de khenarthi'}
local function regionKey(s) local k=bare(s);return aliases[k] or k end
for faction,ring in pairs(rings) do
 for index,row in ipairs(ring) do
  local id=faction..index;local node={id=id,region=row[1],town=row[2],where=row[3],person=guides[faction],source=sources[faction]}
  nodes[id]=node;byRegion[regionKey(row[1])]=node;edges[id]={}
 end
end
for faction,ring in pairs(rings) do for i=1,#ring do
 local id=faction..i
 edges[id][#edges[id]+1]=faction..(i%#ring+1)
 edges[id][#edges[id]+1]=faction..((i-2)%#ring+1)
 for other in pairs(rings) do if other~=faction then edges[id][#edges[id]+1]=other..i end end
end end
local roost={id='roost',region='Perchoir de Khenarthi',town='détroit de l’Aigle',where='sur la plage, près de son bateau',person='Sucregriffes',source=sources.roost}
nodes.roost=roost;byRegion[regionKey(roost.region)]=roost;edges.roost={'ad1'};edges.ad1[#edges.ad1+1]='roost'
-- Additional documented routes use their own carrier; never borrow the
-- base-game navigator's name for an unrelated DLC boat.
local function hub(id,region,town)
 local node={id=id,region=region,town=town};nodes[id]=node;byRegion[regionKey(region)]=node;edges[id]={};return node
end
local function connect(a,b,service)
 edges[a][#edges[a]+1]=b;departures[a..'>'..b]=service
end
hub('hews','Trépas des Cognées',"le débarcadère d’Abah")
for _,from in ipairs({'ad3','dc2','ep4'}) do
 local source='https://forums.elderscrollsonline.com/en-gb/discussion/263981/useful-map-markers-to-add'
 connect(from,'hews',{boat=true,source=source});connect('hews',from,{boat=true,source=source})
end
hub('summerset','Couchant','Alinor')
for _,from in ipairs({'ad2','dc2','ep2'}) do
 local service={person='Ciryelda',source='https://en.uesp.net/wiki/Online:Ciryelda'}
 connect(from,'summerset',service);connect('summerset',from,service)
end
hub('vvardenfell','Vvardenfell','Seyda Neen')
for _,from in ipairs({'ad2','dc1','ep1','ep3'}) do connect(from,'vvardenfell',{person='la capitaine Jenassa',source='https://en.uesp.net/wiki/Online:Captain_Jenassa'}) end
connect('roost','vvardenfell',{person='Sathasa Falen',where='sur la plage, près du bateau',source='https://en.uesp.net/wiki/Online:Sathasa_Falen'})
connect('vvardenfell','roost',{person='Taros Evosa',where='aux quais',source='https://en.uesp.net/wiki/Online:Taros_Evosa'})
hub('solstice','Solstice','Hélioport')
for _,from in ipairs({'ad2','dc2','ep2'}) do
 local service={person='Kimazia',source='https://en.uesp.net/wiki/Online:Kimazia'}
 connect(from,'solstice',service);connect('solstice',from,service)
end
function T.Path(origin,destination)
 local a,b=byRegion[regionKey(origin)],byRegion[regionKey(destination)]
 if not a or not b or a==b then return end
 local queue={{a}};local seen={[a.id]=true};local index=1
 while queue[index] do
  local path=queue[index];index=index+1;local last=path[#path]
  if last==b then return path end
  for _,id in ipairs(edges[last.id]) do if not seen[id] then
   seen[id]=true;local next={unpack(path)};next[#next+1]=nodes[id];queue[#queue+1]=next
  end end
 end
end
local cityTrie={}
for _,p in ipairs(IHR_GeographicData.places) do if p.city then
 for _,name in ipairs(p.names) do
  local key=bare(name);local node=cityTrie
  for word in key:gmatch('[^ ]+') do node[word]=node[word] or {};node=node[word] end
  node.name=name
 end
end end
local function originRegion() local _,name=B.SocialZone({zoneIndex=GetUnitZoneIndex('player')});return name end
local function native(source)
 return not source.acquired and (source.kind=='Journal de quête' or source.kind=='Étape actuelle' or source.kind=='Objectif actuel' or source.kind=='Journal : étape visible')
end
function T.Goal(task)
 local own=regionKey(originRegion());local q=task.quest
 local expected=''
 if type(q.zoneIndex)=='number' and q.zoneIndex>0 then expected=regionKey(select(2,B.SocialZone({zoneIndex=q.zoneIndex}))) end
 local best,rank
 for _,source in ipairs(q.sources or {}) do
  if not source.unverified and (native(source) or source.acquired) and not (source.source or ''):find('Transports documentés :',1,true) then
   local words={};for word in norm(source.text):gmatch('[^ ]+') do words[#words+1]=word end
   for i=1,#words do
    local node=cityTrie
    for j=i,math.min(i+12,#words) do
     node=node[words[j]];if not node then break end
     if node.name then
      local place=G.Place(node.name,task)
      if place and place.zone and regionKey(place.zone)~=own and (expected=='' or regionKey(place.zone)==expected) then
       local score=native(source) and (source.kind=='Journal de quête' and 3 or 5) or 1
       if not rank or score>rank then best={name=D.PlaceName(place.name),region=place.zone,source=source};rank=score end
      end
     end
    end
   end
  end
 end
 if best then return best end
 local targetRegion=q.zoneName
 if targetRegion and byRegion[regionKey(targetRegion)] and regionKey(targetRegion)~=own then
  for _,source in ipairs(q.sources or {}) do if native(source) and mentions(source.text,targetRegion) then return {name=D.PlaceName(targetRegion),region=targetRegion,source=source} end end
 end
end
local function prefix(task,goal,origin) return 'Transports documentés : '..regionKey(origin)..'>'..regionKey(goal.region)..':'..bare(goal.name)..' ; ' end
function T.Subject(task)
 local goal=T.Goal(task);if not goal then return end
 local origin=originRegion();local path=T.Path(origin,goal.region)
 local head=prefix(task,goal,origin);local nextLeg=1
 for _,entry in ipairs(B.Investigation.Entries(task.questKey)) do
  if not entry.unverified and entry.kind=='renseignement' and entry.taskKey==task.key and (entry.source or ''):sub(1,#head)==head then
   local leg=tonumber(entry.source:sub(#head+1):match('^étape (%d+)'))
   if leg then nextLeg=math.max(nextLeg,leg+1) end
  end
 end
 if path and nextLeg>=#path then return nil,goal end
 local answer,source
 if path then
  local from,to=path[nextLeg],path[nextLeg+1]
  local service=departures[from.id..'>'..to.id]
  local person=service and service.person or from.person
  if from.id=='ad1' and to.id=='roost' then person=roost.person end
  local where=service and service.where or (not service and from.where)
  where=where and (' '..where) or ''
  local town=D.PlaceName(from.town)
  local at=bare(town)==bare(roost.town) and 'au détroit de l’Aigle' or 'à '..town
  if service and service.boat then
   answer='Rejoignez les quais '..D.OfPlace(from.town)..'. Cherchez le bateau à destination '..D.OfPlace(to.town)..'.'
  else
   answer='Allez voir '..person..' '..at..where..'. Demandez un passage pour '..to.town..', '..(regionKey(to.region)=='prasin' and 'en Prasin' or 'dans la région '..D.OfPlace(to.region))..'.'
  end
  if nextLeg+1<#path then answer=answer..' Vous pourrez y chercher une correspondance.'
  elseif bare(goal.name)~=bare(to.town) and regionKey(goal.name)~=regionKey(to.region) then answer=answer..' Une fois sur place, renseignez-vous sur le chemin pour '..goal.name..'.' end
  source=head..'étape '..nextLeg..' ; '..(service and service.source or from.source)
 end
 local subject={task=task,title=task.quest.name,kind='transport',targetKind='place',target=goal.name,destination=goal.name,
  question=(nextLeg>1 and 'Et ensuite, comment rejoindre ' or 'Comment rejoindre ')..goal.name..' ?',
  answer=answer,unresolved=not answer,source=source,key=task.key..':travel:'..regionKey(origin)..':'..bare(goal.name)..':'..nextLeg,
  level=1,transport=true,methodVerified=not not answer}
 local depth=(native(goal.source) and 0 or E.SourceDepth(goal.source))+nextLeg
 E.Decorate(subject,depth)
 return subject,goal
end
local subjects=D.Subjects
function D.Subjects(index)
 local original=subjects(index);local replacements,goals={},{}
 for _,task in ipairs(D.Tasks(index)) do local entry,goal=T.Subject(task);if goal then goals[task.key]=goal;if entry then replacements[#replacements+1]=entry end end end
 local result={}
 for _,entry in ipairs(original) do
  local goal=entry.task and goals[entry.task.key]
  -- Do not replace a genuinely documented local action/method with geography.
  local redundant=goal and not entry.methodVerified and (entry.targetKind=='person' or entry.targetKind=='place' or entry.kind=='region' or entry.kind=='destination' or entry.kind=='route')
  if not redundant then result[#result+1]=entry end
 end
 for _,entry in ipairs(replacements) do result[#result+1]=entry end
 return result
end
local refresh=D.RefreshSubject
function D.RefreshSubject(subject)
 if subject.transport then
  local task=D.Fresh(subject.task);if not task then return end
  local current=T.Subject(task);if current and current.key==subject.key then return current end
  return
 end
 return refresh(subject)
end
local followups=D.Followups
function D.Followups(subject)
 local result=followups(subject) or {}
 if subject.task then
  local task=D.Fresh(subject.task)
  local entry,goal;if task then entry,goal=T.Subject(task) end
  if goal then
   local filtered={}
   for _,f in ipairs(result) do
    if not f.subject or f.subject.methodVerified or (f.subject.targetKind~='place' and f.subject.targetKind~='person') then filtered[#filtered+1]=f end
   end
   if entry and entry.key~=subject.key then filtered[#filtered+1]={subject=entry,text=D.InquiryLabel(entry,entry.question)} end
   return filtered
  end
 end
 return result
end
local extract=E.Extract
function E.Extract(entry,task)
 if (entry.source or ''):find('^Transports documentés :') then return {} end
 return extract(entry,task)
end
local placeAnswer=G.PlaceAnswer
function G.PlaceAnswer(name,task)
 local p=G.Place(name,task)
 if p and p.city and p.zone and regionKey(p.zone)~=regionKey(originRegion()) then
  local voice=B.RouteVoice
  local answer=voice and voice.Format('relative',{region=p.zone,npc=B.npc,targetKey=task and task.key or name})
   or (D.PlaceName(p.name)..' se trouve dans la région '..D.OfPlace(p.zone)..'.')
  return answer,p.source,p.name,'region'
 end
 return placeAnswer(name,task)
end
