-- French geographical conversations, rebuilt on the 1.2.2 baseline.
local B=IHR_Runtime.Beta
local D=B.Dice
local G=B.GeographicKnowledge
local P=B.Personality
local V=B.RouteVoice
local function norm(s)
 s=(s or ''):gsub('\\r\\n','\n'):gsub('\\n','\n'):gsub('\\r','\n')
 return B.Normalize(s)
end
local function cleanObjective(s)
 s=(s or ''):gsub('\194\160',' '):gsub('\226\128\175',' '):gsub('|c%x%x%x%x%x%x',''):gsub('|r','')
 s=s:gsub('%s+$',''):gsub('[%.!?]+$','')
 return (s:gsub('%s*:%s*%d+%s*/%s*%d+%s*$',''):gsub('%s*%(%s*%d+%s*/%s*%d+%s*%)%s*$',''):gsub('%s+$',''))
end
D.CleanObjectiveFR=cleanObjective
-- The older reference catalogues build their indexes before this module; make
-- their runtime lookups accept the same client formatting as the final planner.
if B.RegionalKnowledge and B.RegionalKnowledge.ObjectiveKey then
 local previousKey=B.RegionalKnowledge.ObjectiveKey
 function B.RegionalKnowledge.ObjectiveKey(text) return previousKey(cleanObjective(text)) end
end
local function objectiveKey(s)
 return norm(cleanObjective(s))
end
local function bare(s) return norm(s):gsub('^le ',''):gsub('^la ',''):gsub('^les ',''):gsub('^l ','') end
local function copy(s) local r={};for k,v in pairs(s) do r[k]=v end;return r end
local function knownRegion(name,task)
 local key=bare(name)
 local story=task and task.quest and D.Region(task.quest.zoneIndex)
 if story and bare(story.name)==key then return story.name end
 for _,region in pairs(B.KnowledgeAtlas().regions or {}) do
  if bare(region.name)==key then return region.name end
 end
end
local function splitDestination(name,task)
 local head,tail=name:match('^(.-),%s*à%s+(.+)$')
 if not head then head,tail=name:match('^(.-),%s*en%s+(.+)$') end
 if not head then head,tail=name:match('^(.-),%s*dans%s+(.+)$') end
 if not head then return name end
 local region=knownRegion(tail,task)
 local destination=G.Place(head,task)
 if not region and destination and bare(destination.zone)==bare(tail) then region=destination.zone end
 if region or G.Place(tail,task) or B.PublicPlace(tail) then return head,tail,region end
 return name
end
local function valid(name)
 if type(name)~='string' or #name<3 then return false end
 if ({le=true,la=true,les=true,l=true,un=true,une=true,des=true,de=true,du=true,au=true,aux=true,a=true})[norm(name)] then return false end
 local n=norm(name):gsub('^le ',''):gsub('^la ',''):gsub('^les ',''):gsub('^l ','')
 if ({vos=true,votre=true,voleurs=true,ennemis=true,bandits=true,gardes=true,gens=true,eau=true,passant=true,passants=true,villageois=true,habitants=true,habitant=true})[n] then return false end
 local first=n:match('^([^ ]+)')
 if ({que=true,si=true,comment=true,afin=true})[first] then return false end
 if ({mon=true,ma=true,mes=true,ton=true,ta=true,tes=true,son=true,sa=true,ses=true,notre=true,nos=true,votre=true,vos=true,leur=true,leurs=true})[first] then return false end
 return not n:find('jusqu') and not n:find('<<',1,true)
end
function D.TargetForTask(task)
 if not task or type(task.text)~='string' then return end
 local verb,name=cleanObjective(task.text):match('^(%S+)%s+(.+)$')
 if not name then return end
 verb=norm(verb)
 name=name:gsub('%s*:%s*%d+%s*/%s*%d+%s*$',''):gsub('%s*%(%s*%d+%s*/%s*%d+%s*%)$',''):gsub('[%.!?]+$','')
 local followingPersonAction
 for _,action in ipairs({'donnez%-lui','remettez%-lui','obtenez','demandez%-lui','rapportez%-lui'}) do
  local first=name:match('^(.-)%s+et%s+'..action..'%s+')
  if first then name=first;followingPersonAction=true;break end
 end
 local people={parlez=true,rencontrez=true,interrogez=true,['adressez vous']=true,discutez=true,sauvez=true,liberez=true,expulsez=true,tuez=true,vainquez=true,combattez=true,affrontez=true,battez=true,pourchassez=true}
 local places={rejoignez=true,entrez=true,penetrez=true,atteignez=true,retournez=true,rentrez=true,allez=true,explorez=true,franchissez=true,passez=true,traversez=true,escaladez=true,['presentez vous']=true,['rendez vous']=true,voyagez=true}
 local objects={trouvez=true,cherchez=true,recuperez=true,ramassez=true,cueillez=true,recoltez=true,prenez=true,lisez=true,allumez=true,obtenez=true,rapportez=true,retrouvez=true,activez=true,retirez=true,collectez=true,detruisez=true,utilisez=true,actionnez=true,ouvrez=true,fermez=true,refermez=true,examinez=true,inspectez=true,fouillez=true,purifiez=true,touchez=true,eteignez=true}
 local kind,exit
 if verb=='apportez' or verb=='livrez' or verb=='remettez' or verb=='rapportez' or verb=='donnez' or verb=='rendez' then
  local recipient=D.DeliveryRecipient(name)
  if recipient then name=recipient;kind='person' elseif verb=='rapportez' then kind='object' else return end
 elseif verb=='faites' and name:find('^votre rapport ') then
  name=D.DeliveryRecipient(name);kind='person'
 elseif verb=='suivez' then
  local actor=G.Person(name,task) or (B.NpcRaces and B.NpcRaces.Find(name))
  if actor then kind='person' elseif G.Place(name,task) then kind='place' else return end
 elseif people[verb] then kind='person'
 elseif places[verb] then kind='place'
 elseif objects[verb] then kind='object'
 elseif verb=='quittez' or verb=='sortez' then
  name=name:gsub('^de%s+',''):gsub('^du%s+','le '):gsub('^des%s+','les ');kind='place';exit=true
 elseif verb=='amenez' or verb=='emmenez' or verb=='escortez' or verb=='accompagnez' then
  name=name:match('^(.-)%s+jusqu') or name:match('^(.-)%s+à%s+') or name
  name=name:gsub('%s+en lieu sûr$',''):gsub('%s+en sécurité$','');kind='person'
 elseif verb=='dispensez' or verb=='versez' or verb=='deposez' or verb=='placez' or verb=='posez' or verb=='inserez' or verb=='plantez' or verb=='semez' then
  name=name:match('%s+à%s+(.+)$') or name:match('%s+sur%s+(.+)$') or name:match('%s+dans%s+(.+)$');kind='place'
 else return end
 if not name then return end
 if (verb=='retournez' or verb=='allez') and name:find('^voir ') then
  kind='person';name=name:gsub('^voir%s+',''):gsub('^si%s+',''):gsub('%s+vont bien$',''):gsub('%s+va bien$','')
 elseif (verb=='retournez' or verb=='allez') and name:find('^auprès ') then
  kind='person';name=name:gsub('^auprès du%s+','le '):gsub('^auprès des%s+','les '):gsub('^auprès de%s+','')
 elseif verb=='allez' and name:find('^trouver ') then
  name=name:gsub('^trouver%s+','');kind='object'
  local word=name:match('^([^ ]+)') or ''
  if word~=zo_strlower(word) and not ({le=true,la=true,les=true,un=true,une=true,des=true})[zo_strlower(word)] then kind='person' end
 end
 if followingPersonAction then kind='person' end
 if verb=='utilisez' and not G.Object(name,task) then
  local item,purpose=name:match('^(.-)%s+pour%s+(%S+)')
  if item and ({activer=true,ouvrir=true,plonger=true,appeler=true,fermer=true,detruire=true,bruler=true,entrer=true,invoquer=true,controler=true})[norm(purpose)] then name=item end
 end
 name=name:gsub('^à%s+',''):gsub('^avec%s+',''):gsub('^dans%s+',''):gsub('^vers%s+',''):gsub('^au%s+','le '):gsub('^aux%s+','les ')
 if kind=='place' then name=name:gsub('^en%s+','') end
 local location,region
 name,location,region=splitDestination(name,task)
 local initial=name:match('^([^ ]+)') or ''
 local proper=initial~=zo_strlower(initial)
 if kind=='person' or ((verb=='retrouvez' or verb=='trouvez') and proper and not G.Place(name,task)) then
  if not G.Person(name,task) then
   local head,tail=name:match('^(.-)%s+dans%s+(.+)$')
   if not head then head,tail=name:match('^(.-)%s+à%s+(.+)$') end
   if not head then head,tail=name:match('^(.-)%s+au%s+(.+)$');if head then tail='le '..tail end end
   if head and head~='' then name=head;location=location or tail;kind='person' end
  end
 end
 if kind=='object' and not location then
  for _,pattern in ipairs({'^(.-)%s+dans%s+(.+)$','^(.-)%s+à%s+(.+)$','^(.-)%s+au%s+(.+)$','^(.-)%s+aux%s+(.+)$'}) do
   local head,tail=name:match(pattern)
   if head and (G.Place(tail,task) or B.PublicPlace(tail)) then name=head;location=tail;break end
  end
 end
 if not valid(name) then return end
 local person=G.Person(name,task);local place=G.Place(name,task)
 if person then kind='person' elseif place then kind='place' end
 local shape=bare(name)
 if shape:find('^ruines de ') or shape:find('^site ') or shape:find('^mine ') or shape:find('^grotte ') then kind='place' end
 if name:find(' et ',1,true) and not place then
  local a,b=name:match('^(.-) et (.+)$')
  local function actor(n) return G.Person(n,task) or (B.NpcRaces and B.NpcRaces.Find(n)) end
  if a and actor(a) and actor(b) then kind='person' end
 end
 if region and kind~='person' then kind='place' end
 -- Preserve the complete spelling supplied by the French client. An older
 -- atlas alias must not remove accents or replace a native display name.
 return {name=name,kind=kind,action=verb,location=location,region=region,exit=exit}
end
local function towards(name)
 local key=norm(name)
 if key:find('^le ') then return 'au '..name:sub(4) end
 if key:find('^les ') then return 'aux '..name:sub(5) end
 return 'à '..name
end
local function question(t)
 if t.kind=='object' and ({cueillez=true,recoltez=true,ramassez=true,collectez=true})[t.action] then
  local noun=t.name:gsub('^les ','des ')
  local verb=({cueillez='cueillir',recoltez='récolter',ramassez='ramasser',collectez='trouver'})[t.action]
  return 'Savez-vous où je pourrais '..verb..' '..noun..' ?'
 end
 if t.question then return t.question end
 if t.kind=='person' then return 'Où puis-je trouver '..t.name..' ?' end
 if t.exit then return 'Comment sortir '..D.OfPlace(t.name)..' ?' end
 if t.kind=='place' and not B.Here(t.name) then return 'Comment se rendre '..towards(t.name)..' ?' end
 local plural=norm(t.name):find('^les ') or norm(t.name):find('^des ')
 return 'Où se '..(plural and 'trouvent ' or 'trouve ')..t.name..' ?'
end
D.GeographicQuestionFR=question
D.GeographicTargetFR=D.TargetForTask
local hints={}
local nativeSpeakers={}
local reviewedDefaults={}
local reviewedGuilds={}
for _,id in ipairs(RPM_GuildReviewedQuestIds or {}) do reviewedGuilds[id]=true end
for _,id in ipairs(RPM_VestigeReviewedQuestIds or {}) do reviewedGuilds[id]=true end
for _,rows in ipairs({RPM_AldmeriGeographyFR or {},RPM_GuildGeographyFR or {}}) do
 for _,r in ipairs(rows) do
  if r.quest and r.binding=='iq_goal_rule' and not r.step then reviewedDefaults[r.quest..':'..objectiveKey(r.objective)]=true end
 end
end
local function indexHints(rows,priority)
for _,r in ipairs(rows or {}) do
 r.localSourcePriority=priority
 for _,questId in ipairs(r.quest and {r.quest} or r.scopeQuests or {}) do
 local key=questId..':'..objectiveKey(r.objective)
 -- These newly reviewed defaults were checked against *every* author phase.
 -- Discard old generated reductions for that goal so their wording cannot
 -- override the corrected common geography merely by carrying an old phase.
 if (priority~=1 or not reviewedDefaults[key]) and not (priority<4 and reviewedGuilds[questId]) then
 hints[key]=hints[key] or {};hints[key][#hints[key]+1]=r
 if r.speaker then nativeSpeakers[questId]=nativeSpeakers[questId] or {};nativeSpeakers[questId][bare(r.speaker)]=true end
 end
 end
end
end
indexHints(RPM_GeographyHintsFR,1)
indexHints(RPM_AldmeriGeographyFR,2)
indexHints(RPM_NativeGeographyFR,3)
indexHints(RPM_GuildGeographyFR,4)
indexHints(RPM_GuildNativeContextFR,5)
indexHints(RPM_VestigeGeographyFR,4)
indexHints(RPM_VestigeNativeContextFR,5)
RPM_GeographyHintsFR=nil;RPM_AldmeriGeographyFR=nil;RPM_NativeGeographyFR=nil
local function hintText(task)
 local id=type(GetJournalQuestId)=='function' and GetJournalQuestId(task.index)
 local candidates=hints[tostring(id)..':'..objectiveKey(task.text)] or {}
 local selected,record,fallback,fallbackRecord,conflictingFallback,priority,conflictingSelected
 for _,r in ipairs(candidates) do
  local phaseMatches=(r.step and norm(r.step)==norm(task.stepText)) or
    (r.stepTemplate and D.MatchNativePhaseFR and D.MatchNativePhaseFR(task,r))
  local isDefault=r.binding=='iq_goal_rule' and not r.step
  local allowed=(phaseMatches or isDefault) and
    (not D.LocalGeographyRouteMatchesFR or D.LocalGeographyRouteMatchesFR(task,r))
  if allowed and phaseMatches then
   if not priority or r.localSourcePriority>priority then
    selected=r.text;record=r;priority=r.localSourcePriority;conflictingSelected=false
   elseif r.localSourcePriority==priority then
    if selected and selected~=r.text then conflictingSelected=true end
    selected=r.text;record=r
   end
  elseif allowed and isDefault then
   if not fallbackRecord or r.localSourcePriority>fallbackRecord.localSourcePriority then
    fallback=r.text;fallbackRecord=r;conflictingFallback=false
   elseif r.localSourcePriority==fallbackRecord.localSourcePriority then
    if fallback and fallback~=r.text then conflictingFallback=true end
    fallback=r.text;fallbackRecord=r
   end
  end
 end
 if selected then if not conflictingSelected then return selected,record end;return end
 if not conflictingFallback then return fallback,fallbackRecord end
end
D.GeographicHintFR=hintText
local function onSite(task,name)
 if not name or name=='' then return false end
 if knownRegion(name,task) then return false end
 local meta=D.Metadata(task)
 if meta and bare(name)==bare(meta.region) then return false end
 local _,authored=hintText(task)
 if authored and bare(authored.knownDestination or authored.routeCity)==bare(name) and meta
  and meta.mapId and type(GetCurrentMapId)=='function' and meta.mapId==GetCurrentMapId()
  and bare(meta.mapName)~=bare(meta.region) and bare(meta.mapName)~='tamriel' then return true end
 return D.NpcOnSite(task,{name=name,site=D.SiteForName(name)})
end
local function pattern(s) return (s:gsub('([^%w])','%%%1')) end
local scopedPlaces={
 {name='la salle d’audience',aliases={'salle d’audience',"salle d'audience"}},
 {name='la salle du trône',aliases={'salle du trône'}},
 {name='la salle du conseil',aliases={'salle du conseil'}},
 {name='la salle des archives',aliases={'salle des archives'}},
 {name='la longère du chef',aliases={'longère du chef','maison longue du chef'}},
}
local function scopedPlace(name)
 for _,p in ipairs(scopedPlaces) do
  if bare(name)==bare(p.name) then return p end
  for _,alias in ipairs(p.aliases) do if bare(name)==bare(alias) then return p end end
 end
end
local function answerPlaces(task,text)
 local out,seen={},{}
 for _,p in ipairs(G.AnswerPlaces and G.AnswerPlaces(text,task) or {}) do
  local scoped=scopedPlace(p.name)
  local name=scoped and scoped.name or p.name
  out[#out+1]=name;seen[bare(name)]=true
 end
 local normalized=' '..norm(text)..' '
 for _,p in ipairs(scopedPlaces) do
  for _,alias in ipairs(p.aliases) do
   local at=normalized:find(' '..norm(alias)..' ',1,true)
   if at and not seen[bare(p.name)] and not B.LearnedQuestions.ReferenceOnly(text,alias) then
    local prefix=normalized:sub(math.max(1,at-65),at)
    local locative=prefix:find(' dans ') or prefix:find(' pres ') or prefix:find(' approcher de ') or prefix:find(' a ') or prefix:find(' au ') or prefix:find(' cote de ')
    if locative and not prefix:find(' pas ') and not prefix:find(' jamais ') then out[#out+1]=p.name;seen[bare(p.name)]=true end
   end
  end
 end
 return out
end
D.AnswerDestinationsFR=answerPlaces
local function naturalWords(text)
 return (text:gsub('Pour poursuivre votre chemin, cherchez le passage','Prenez le passage')
  :gsub('Le passage pour poursuivre votre chemin est','Le passage est')
  :gsub('Il faudra fouiller les environs ; je ne peux pas vous montrer un point exact%.','Regardez dans les environs.'))
end
local function spokenHere(task,text)
 local result=naturalWords(text)
 for _,p in ipairs(G.AnswerPlaces and G.AnswerPlaces(text,task) or {}) do
  if B.Here(p.name) or task and onSite(task,p.name) then
   local names={p.name};for _,alias in ipairs(p.names or {}) do names[#names+1]=alias end
   for _,name in ipairs(names) do
    for _,prep in ipairs({' en ',' à ',' au ',' dans '}) do
     local part=prep..name
     if result:find(part,1,true) then
      -- An apposition describing the town is redundant here. It is not an
      -- indoor direction and must not be glued to the next native bearing.
      result=result:gsub(pattern(part)..',%s*un village[^%.]*','')
      result=result:gsub(pattern(part)..',%s*une ville[^%.]*','')
      result=result:gsub(pattern(part),'')
     end
    end
   end
  end
 end
 return (result:gsub('%s+([%.!,;])','%1'):gsub('%s+$',''))
end
D.GeographicNoteFR=function(entry)
 local text=naturalWords(entry.text or '')
 if D.SameOrigin(entry) then text=spokenHere(nil,text) end
 return text
end
local function composeLocal(task,record,text,native)
 local short=spokenHere(task,text)
 local simple=norm(short):gsub('^cherchez ',''):gsub('[%.!?]+$','')
 if simple=='dans sa maison' or simple=='dans son logement' then
  if native and native.nativePosition and not native.nativeBreadcrumb and native.nativeBearing then
   if V then return V.Format('direction',{subject='Sa maison',bearing=native.nativeBearing,npc=B.npc,
    targetKey=task.key,near=native.nativeNear,distanceMeters=native.nativeDistanceMeters}) end
   return 'Sa maison se trouve '..native.nativeBearing..' d’ici.'
  end
  short='Dans sa maison.'
 end
 if not short:find('[.!?]$') then short=short..'.' end
 if native and native.nativePosition then short=short..' '..native.answer end
 return short
end
local function localHint(task,t,site)
 local selected,record=hintText(task)
 if not selected then return end
 if record.routeCity and B.GuildRoutesFR and not B.GuildRoutesFR.WitnessOnRoute(task,record)
  and not (G.NearObjective and G.NearObjective(task)) then return end
 if record.hintScope=='access' or record.hintScope=='context' then return end
 if record.localText and (record.hintScope=='mixed' or record.hintScope=='local') then selected=record.localText end
 if record.hintScope=='mixed' and not record.localText then return end
 local meta=D.Metadata(task)
 if record.site and meta and meta.mapName and bare(meta.mapName)~=bare(meta.region) and bare(meta.mapName)~='tamriel'
  and bare(record.site)~=bare(meta.mapName) then
  local place=G.Place(meta.mapName,task);local seen={};local compatible=false
  local authoredPlace=G.Place(record.site,task)
  if place and authoredPlace and bare(place.name)==bare(authoredPlace.name) then compatible=true end
  while place and not seen[place] do
   seen[place]=true
   if bare(place.name)==bare(record.site) or bare(place.parent)==bare(record.site) then compatible=true;break end
   place=place.parent and G.Place(place.parent,task)
  end
  -- The client may name the room/house map while the witness is in its
  -- documented village. That is a local witness, not someone in another zone.
  if not compatible and not onSite(task,record.site) then return end
 end
 -- A region is not a local site. Only give indoor detail when the condition's
 -- named site is actually the player's current site.
 local documentedSpeaker=record.speaker and B.npc and (bare(record.speaker)==bare(B.npc.name)
  or B.RegionalKnowledge and B.RegionalKnowledge.SamePerson(record.speaker,B.npc.name))
 if not documentedSpeaker and not onSite(task,site) and not onSite(task,record.site) and not (G.NearObjective and G.NearObjective(task)) then return end
 local text=' '..norm(selected)..' '
 local precise=false
 for _,word in ipairs({'devant','derriere','a cote','pres','au pied','sous','etage','fond','salle','chambre','nord','sud','est','ouest','entree','centre','autour'}) do
  if text:find(' '..word..' ',1,true) then precise=true;break end
 end
 local answer=(record.localText and record.localAnswerComplete or not record.localText and record.answerComplete) and selected or ('Cherchez '..selected)
 local rawAnswer=answer
 answer=composeLocal(task,record,answer)
 if not answer:find('[.!?]$') and answer:sub(-3)~='…' then answer=answer..'.' end
 return {task=task,title=task.quest.name,key=task.key..':fr-local',family='goal',kind='spot',
  target=t.name,targetKind=t.kind,question=question(t),answer=answer,
  factSignature=B.Hash(selected..'|'..(record.binding or 'phase')..'|'..(record.site or '')),
  localRecord=record,localRawText=rawAnswer,routeVoiced=true,
  level=precise and 3 or 2,source=record.source or 'Indication géographique FR : objectif et étape actuels',destination=site}
end
local function siteFor(task,t)
 local _,authored=hintText(task)
 if authored and authored.routeCity and B.GuildRoutesFR and not B.GuildRoutesFR.WitnessOnRoute(task,authored) then
  return authored.routeCity,authored.source
 end
 local meta=D.Metadata(task)
 if meta and bare(meta.mapName)~=bare(meta.region) and bare(meta.mapName)~='tamriel' then return meta.mapName,meta.source end
 if t.location then return t.location,'Journal FR : destination de l’objectif actif' end
 if authored and authored.site and not knownRegion(authored.site,task) then return authored.site,authored.source or 'Indication locale du fichier français' end
 local reference=G.TaskReference(task)
 if reference and not knownRegion(reference.place,task) and (reference.relation=='in' or reference.relation=='inside' or reference.relation=='part') then return reference.place,reference.source end
 if D.RestrictGeographicBiographyFR and D.RestrictGeographicBiographyFR(task,t) then return end
 local p=t.kind=='person' and G.Person(t.name,task) or nil
 if p then
  if p.city and not knownRegion(p.city,task) and not onSite(task,p.city) then return p.city,p.source end
  if not knownRegion(p.site,task) then return p.site,p.source end
 end
 local object=t.kind=='object' and G.Object(t.name,task) or nil
 if object and not knownRegion(object.site,task) then return object.site,object.source end
 if t.kind=='place' and G.Place(t.name,task) then return t.name,'Atlas géographique' end
end
local function effectiveTarget(task)
 local t=D.TargetForTask(task)
 local _,authored=hintText(task)
 if authored and authored.target and authored.targetKind then
  t={name=authored.target,kind=authored.targetKind,location=t and t.location,region=t and t.region,action=t and t.action}
 end
 if t and authored and authored.question then t.question=authored.question end
 return t
end
D.EffectiveGeographicTargetFR=effectiveTarget
local function plan(task)
 local t=effectiveTarget(task)
 -- An unsupported/abstract instruction is not a place. Only an explicitly
 -- reviewed target may replace it; a nearby named site cannot supply a noun.
 if not t or (not t.exit and (t.kind=='person' or t.kind=='place') and B.Here(t.name)) then return {} end
 if t.kind=='person' and B.npc and bare(t.name)==bare(B.npc.name) then return {} end
 local site,siteSource=siteFor(task,t)
 local s=D.GoalSubject(task)
 local detail=localHint(task,t,site)
 if detail then
  if s and s.nativePosition and (onSite(task,site) or onSite(task,detail.localRecord.site) or (G.NearObjective and G.NearObjective(task))) then
   detail.answer=composeLocal(task,detail.localRecord,detail.localRawText,s);detail.level=math.max(detail.level,s.level)
   detail.source=detail.source..' ; '..(s.source or 'position native')
  end
  return {detail}
 end
 local seed={task=task,title=task.quest.name,key=task.key..':geo-only',family='goal',kind='goal',
  target=t.name,targetKind=t.kind,question=question(t),level=1,unresolved=true,
  factSignature=site and B.Hash(site..'|'..(siteSource or '')) or nil}
 local _,authored=hintText(task)
 if t.kind=='place' and authored and authored.hintScope=='access' and authored.accessText
  and bare(authored.accessDestination)==bare(t.name) then
  seed.kind='destination';seed.answer=authored.accessText;seed.source=authored.source
  seed.destination=t.name;seed.level=2;seed.unresolved=false
  return {seed}
 end
 -- ESO supplies the position of this exact unfinished condition. It never
 -- supplies a fabricated room, mechanism, puzzle solution or generic noun.
 local localWitness=onSite(task,site)
 if s and s.nativePosition and not localWitness then
  -- A moving quest actor may have left the static town in the old directory.
  -- The client pin is authoritative. Only its own named target map may be
  -- added here; a generic NPC biography must not replace that current pin.
  local meta=D.Metadata(task)
  local nativeSite=meta and bare(meta.mapName)~=bare(meta.region) and bare(meta.mapName)~='tamriel' and meta.mapName or nil
  local answer=s.answer
  if s.level==3 and s.answer:find('de nous',1,true) then answer=s.answer:gsub('C’est tout près : regardez ','Cherchez '):gsub(' de nous%.',' d’ici.') end
  s.kind='destination';s.level=2;s.target=t.name;s.targetKind=t.kind;s.question=question(t)
  s.destination=nativeSite
  s.answer=(nativeSite and ((V and V.Format('destination',{destination=nativeSite,targetKey=task.key}) or ('Cherchez du côté '..D.OfPlace(nativeSite)..'.'))..' ') or '')..answer
  s.routeVoiced=not not V
  return {s}
 end
 if site and not localWitness then
  seed.kind='destination';seed.destination=site;seed.source=siteSource;seed.unresolved=false
  seed.answer=(V and V.Format('destination',{destination=site,targetKey=task.key}) or ('Cherchez du côté '..D.OfPlace(site)..'.'))..' Les gens sur place pourront vous guider.'
  if s and s.answer and s.level==2 and s.answer:find('d’ici',1,true) then seed.answer=(V and V.Format('destination',{destination=site,targetKey=task.key}) or ('Cherchez du côté '..D.OfPlace(site)..'.'))..' '..s.answer end
  seed.routeVoiced=not not V
  return {seed}
 end
 if s and s.nativePosition and localWitness then
  s.question=question(t);s.target=t.name;s.targetKind=t.kind;s.destination=site;return {s}
 end
 if t.kind=='place' then
  local answer,source,destination=G.PlaceAnswer(t.name,task)
  if answer then seed.answer=answer;seed.source=source;seed.destination=destination;seed.unresolved=false;seed.kind='destination';seed.routeVoiced=not not V;return {seed} end
 end
 if s and not site then
  local here=type(GetUnitZoneIndex)=='function' and D.Region(GetUnitZoneIndex('player'))
  local meta=D.Metadata(task)
  if s.level>1 or not here or not meta or bare(here.name)~=bare(meta.region) then
   s.question=question(t);s.target=t.name;s.targetKind=t.kind;return {s}
  end
 end
 seed.answer=nil;return {seed}
end
local known=D.Known
function D.Known(task,family)
 if family=='goal' then return -1 end -- Origin-aware suppression is applied below.
 return known(task,family)
end
function D.GeographicScopeFR(s,depth)
 if s.factSignature then s.key=s.key..':fact:'..tostring(s.factSignature) end
 local zone,x,_,z
 if type(GetUnitWorldPosition)=='function' then zone,x,_,z=GetUnitWorldPosition('player') end
 if type(zone)=='number' and type(x)=='number' and type(z)=='number' then
   local radius=s.kind=='spot' and 2500 or 10000
   local saved=D.Saved();saved.geoOrigins122=saved.geoOrigins122 or {}
   local points=saved.geoOrigins122[s.key] or {};saved.geoOrigins122[s.key]=points
   local sector
   for i,p in ipairs(points) do if p.scopeRadius==radius and D.SameOrigin(p) then sector=i;break end end
   if not sector then sector=#points+1;points[sector]={originZone=zone,originX=x,originZ=z,scopeRadius=radius} end
   s.key=s.key..':origin:'..sector;s.originZone=zone;s.originX=x;s.originZ=z;s.scopeRadius=radius
 end
 local E=B.LearnedQuestions
 if E then E.Decorate(s,depth or E.BaseDepth(s)) end
 return s
end
-- The journal already supplies the meeting place: locate that place first.
-- Keep the original actor/object question as a secondary inquiry, independently
-- learned, so reaching a town never counts as having found its occupant.
local function journalDestination(task,t)
 local function usable(name)
  if not name then return end
  local key=bare(name)
  if ({nord=true,sud=true,est=true,ouest=true,['nord est']=true,['nord ouest']=true,['sud est']=true,['sud ouest']=true,
   champ=true,jardin=true,['jardin du manoir']=true,salle=true,camp=true,campement=true,entree=true})[key] then return end
  local p=G.Place(name,task) or B.PublicPlace(name) or scopedPlace(name)
  if p then return name end
 end
 local primary=usable(t.location)
 local _,authored=hintText(task)
 if not primary and authored and authored.knownDestination then primary=usable(authored.knownDestination) end
 -- Only a future/required action clause can supply a new journal destination.
 -- Past locations in the recap must not redirect the next inquiry.
 for clause in (task.stepText or ''):gmatch('[^%.!%?\n]+') do
  local relates=(task.inquirySiblingCount or 1)<=1 or (' '..norm(clause)..' '):find(' '..bare(t.name)..' ',1,true)
  -- A place in the subject of a future conversation is not its destination:
  -- "parler pour découvrir ce qui s'est passé à Lunehenge" is not a journey.
  local stop
  for _,suffix in ipairs({' pour ',' afin de ',' afin que ',' parce que ',' avant ',' après ',' lorsque ',' ce qui ',' ce que '}) do
   local at=clause:find(suffix,1,true);if at and (not stop or at<stop) then stop=at end
  end
  if stop then clause=clause:sub(1,stop-1) end
  local n=norm(clause)
  if (relates or task.inquiryCommonSite) and not primary and (n:find('je dois ',1,true) or n:find('je devrais ',1,true) or n:find('il faut que ',1,true)
   or n:find('je vais ',1,true) or n:find('je compte ',1,true) or n:find('il me faut ',1,true)
   or n:find('j ai propose de ',1,true) or n:find('j ai accepte de ',1,true)
   or n:find('nous devons ',1,true) or n:find('nous devrions ',1,true)) then
   for _,pattern in ipairs({'%s+à%s+(.+)$','%s+au%s+(.+)$','%s+aux%s+(.+)$','%s+dans%s+(.+)$','%s+en%s+(.+)$'}) do
    local name=clause:match(pattern)
    if name then
     name=name:gsub('%s+$','')
     local known=usable(name)
     if known and (relates or bare(known)==bare(task.inquiryCommonSite)) then primary=known;break end
    end
   end
  end
 end
 -- First reach the explicit meeting place. Once there, a place actually named
 -- by a witnessed answer may open the next independent geographical question.
 if primary and not B.Here(primary) and not onSite(task,primary) then return primary end
 local J=B.Investigation
 if J then
  local entries=J.Entries(task.questKey)
  for i=#entries,1,-1 do
   local e=entries[i]
   if e.kind=='renseignement' and not e.unverified and J.ForObjective(e,task.stepText,task.text) then
    for _,fromAnswer in ipairs(answerPlaces(task,e.text)) do
     local named=usable(fromAnswer)
     if named and bare(named)~=bare(t.name) and not B.Here(named) and not onSite(task,named) then return named end
    end
    local named=usable(e.destination)
    if named and bare(named)~=bare(t.name) and not B.Here(named) and not onSite(task,named) then
     local spoken=' '..norm(e.text)..' '
     if spoken:find(' '..bare(named)..' ',1,true) or (e.factKind=='destination' or e.factKind=='transport') then return named end
    end
   end
  end
 end
 return primary
end
local function destinationInquiry(task,t,name)
 local answer,source,destination=G.PlaceAnswer(name,task)
 local place=G.Place(name,task)
 if place and not place.bearing and not place.part and (not place.parent or knownRegion(place.parent,task)) then answer=nil end
 local _,authored=hintText(task)
 if authored and authored.accessDestination and bare(authored.accessDestination)==bare(name) and authored.accessText then
  answer=authored.accessText;source=authored.source;destination=name
 end
 local route=D.ReadRoute(D.SiteForName(name))
 if route and route.bearing then
  answer=V and V.Format('destination',{destination=name,bearing=route.bearing,near=route.near,distanceMeters=route.distanceMeters,targetKey=task.key})
   or (route.near and 'C’est tout près d’ici. Regardez autour de vous.' or ('D’ici, dirigez-vous '..route.bearing..'.'))
  if route.anchor and route.anchorBearing and not B.Here(route.anchor)
   and (not B.npc or bare(route.anchor)~=bare(B.npc.locality)) then
   answer=answer..' C’est '..route.anchorBearing..' '..D.OfPlace(route.anchor)..'.'
  end
  source=route.source;destination=name
 end
 return {task=task,title=task.quest.name,key=task.key..':journal-destination:'..bare(name),family='goal',
  kind='destination',target=name,targetKind='place',destination=destination or name,
  question=question({name=name,kind='place'}),answer=answer,source=source,
  level=2,unresolved=not answer,journalDestination=true,routeVoiced=not not V,
  factSignature=B.Hash(name..'|'..(source or 'journal'))}
end
D.JournalDestinationFR=journalDestination
function D.PlanTask(task)
 local out=plan(task)
 local t=effectiveTarget(task)
 local name=t and t.kind~='place' and journalDestination(task,t)
 if name and not B.Here(name) and not onSite(task,name) then
  -- Keep the local target independent, but do not sell its already-known town
  -- as another answer while the traveller still needs directions to that town.
  out={destinationInquiry(task,t,name)}
 end
 for _,s in ipairs(out) do D.GeographicScopeFR(s) end
 local filtered={}
 for _,s in ipairs(out) do
  local previous=D.Saved().hints[s.key]
  if not previous or (previous.level or 0)<s.level then filtered[#filtered+1]=s end
 end
 return filtered
end
function D.Subjects(index)
 local out,shared={},{}
 local tasks=D.Tasks(index)
 local common,all=true,true
 if #tasks>1 then
  for _,task in ipairs(tasks) do
   local target=effectiveTarget(task)
   local site=target and siteFor(task,target)
   if not site or knownRegion(site,task) then all=false;break end
   if common==true then common=site elseif bare(common)~=bare(site) then all=false;break end
  end
 else all=false end
 for _,task in ipairs(tasks) do
  task.inquirySiblingCount=#tasks
  task.inquiryCommonSite=all and common or nil
  for _,s in ipairs(D.PlanTask(task)) do
   local visible=' '..norm(task.stepText)..' '
   local group=s.kind=='destination' and not s.localTargetInquiry and not s.nativePosition and not s.unresolved and s.destination
    and not knownRegion(s.destination,task) and visible:find(' '..bare(s.destination)..' ',1,true)
   local signature=group and (task.questKey..'|'..norm(task.stepText)..'|'..bare(s.destination)..'|'..s.level..'|'..tostring(s.inquiryDepth)..'|'..norm(s.answer))
   if signature and shared[signature] then
    local first=shared[signature]
    first.relatedTasks[#first.relatedTasks+1]=task
    first.relatedSubjects[#first.relatedSubjects+1]=s
   else
    if signature then
     s.relatedTasks={task};s.relatedSubjects={};shared[signature]=s
    end
    out[#out+1]=s
   end
  end
 end
 for _,s in ipairs(out) do
  if s.relatedTasks and #s.relatedTasks>1 then
   s.question=question({name=s.destination,kind='place'});s.target=s.destination;s.targetKind='place'
  end
 end
 local ordered={}
 for _,s in ipairs(out) do if s.journalDestination then ordered[#ordered+1]=s end end
 for _,s in ipairs(out) do if not s.journalDestination then ordered[#ordered+1]=s end end
 return ordered
end
-- Follow only a complete geographical name actually supplied in the answer.
local function followSubject(task,name,depth)
 local place=G.Place(name,task) or scopedPlace(name)
 if not place or B.Here(place.name) then return end
 local answer,source,destination,kind=G.PlaceAnswer(place.name,task)
 if not place.bearing and not place.part and (not place.parent or knownRegion(place.parent,task)) then answer=nil end
 local route=D.ReadRoute(D.SiteForName(place.name))
 if route and route.bearing then
  answer=V and V.Format('destination',{destination=place.name,bearing=route.bearing,near=route.near,distanceMeters=route.distanceMeters,targetKey=task.key})
   or (route.near and 'C’est tout près d’ici. Regardez autour de vous.' or ('D’ici, dirigez-vous '..route.bearing..'.'))
  if route.anchor and route.anchorBearing and not B.Here(route.anchor)
   and (not B.npc or bare(route.anchor)~=bare(B.npc.locality)) then
   answer=answer..' C’est '..route.anchorBearing..' '..D.OfPlace(route.anchor)..'.'
  end
  source=route.source;destination=place.name;kind='destination'
 end
 if not answer and not scopedPlace(name) then return end
 local s={task=task,title=task.quest.name,key=task.key..':geo-follow:'..norm(name),
  target=name,targetKind='place',kind=kind or 'destination',destination=destination or name,
  question=question({kind='place',name=name}),answer=answer,source=source,level=2,unresolved=not answer,routeVoiced=not not V,
  requiredSite=siteFor(task,D.TargetForTask(task) or {kind='place',name=name})}
 return D.GeographicScopeFR(s,depth)
end
function D.Followups(entry)
 if entry and entry.journalDestination then return {} end
 if not entry or not entry.task or not entry.destination then return {} end
 local task=D.Fresh(entry.task);if not task then return {} end
 local destination=entry.destination
 for _,name in ipairs(answerPlaces(task,entry.answer or entry.text or '')) do
  if not B.Here(name) and not onSite(task,name) and bare(name)~=bare(entry.target) then destination=name;break end
 end
 local s=followSubject(task,destination,(entry.inquiryDepth or 1)+1)
 if not s or norm(s.answer)==norm(entry.answer) then return {} end
 local previous=D.Saved().hints[s.key]
 if previous and D.SameOrigin(previous) then return {} end
 return {{subject=s,text=D.InquiryLabel(s,s.question)}}
end
local reveal=D.Reveal
function D.Reveal(s,result)
 if s and result and type(GetUnitWorldPosition)=='function' then
  local zone,x,_,z=GetUnitWorldPosition('player')
  result.originZone=zone;result.originX=x;result.originZ=z
 end
 if not reveal(s,result) then return false end
 local hint=s and D.Saved().hints[s.key]
 if hint and result then
  -- A newly obtained bearing at another origin must replace the old answer,
  -- including when it has the same precision level.
  hint.text=result.answer;hint.npc=result.npc;hint.locality=result.locality
  hint.source=result.source;hint.level=result.level;hint.time=GetTimeStamp()
 end
 if hint and type(GetUnitWorldPosition)=='function' then
  local zone,x,_,z=GetUnitWorldPosition('player')
  hint.originZone=zone;hint.originX=x;hint.originZ=z;hint.scopeRadius=s.scopeRadius or 10000
 end
 if hint then
  for _,other in ipairs(s.relatedSubjects or {}) do
   if other.task and D.Fresh(other.task) then
    local acquired=copy(hint)
    acquired.taskKey=other.task.key;acquired.questKey=other.task.questKey
    acquired.taskText=other.task.text;acquired.stepText=other.task.stepText
    D.Saved().hints[other.key]=acquired
   end
  end
 end
 return true
end
local refresh=D.RefreshSubject
function D.RefreshSubject(s)
 if s and s.task then
  local task=D.Fresh(s.task);if not task then return end
  if s.key:find(':geo-follow:',1,true) then
   return followSubject(task,s.target,s.inquiryDepth)
  end
  for _,candidate in ipairs(D.Subjects(task.index)) do
   if candidate.key==s.key then return candidate end
   -- The native position arrives asynchronously. Rebuild the same whole
   -- target if its verified position became available after opening the menu.
   if candidate.task and candidate.task.key==task.key and candidate.targetKind==s.targetKind and bare(candidate.target)==bare(s.target) then return candidate end
  end
  return
 end
 return refresh(s)
end
local givers={}
local db=IHR_QuestRumorDB
for _,rows in pairs(db.maps) do for _,r in ipairs(rows) do
 local id=tonumber(r[3]);local name=db.givers[tonumber(r[4])]
 if id and name then givers[id]=givers[id] or {};givers[id][bare(name)]=true end
end end
local function cooperating(npc,s)
 if not npc or not s or not s.task then return false end
 if s.cooperation==false then return false end -- Explicit authored exception.
 if P.QuestCooperation and P.QuestCooperation(npc,s) then return true end
 -- Active help alone can concern another quest: require its documented giver
 -- or an observed offer for this exact quest, never mere regional reputation.
 local id=type(GetJournalQuestId)=='function' and GetJournalQuestId(s.task.index)
 local function includes(names)
  if not names then return false end
  if names[bare(npc.name)] then return true end
  if B.RegionalKnowledge then
   for name in pairs(names) do if B.RegionalKnowledge.SamePerson(name,npc.name) then return true end end
  end
  return false
 end
 if id and includes(nativeSpeakers[id]) then return true end
 if id and includes(givers[id]) then return true end
 local saved=B.saved.personalDeeds112
 for _,offer in pairs(saved and saved.offers or {}) do
  if offer.npc and norm(offer.npc.name)==norm(npc.name) and id and id>0 and offer.id==id then return true end
 end
 return false
end
D.CooperativeQuestSpeaker=cooperating
local roll=D.Roll
function D.Roll(s,npc)
 if cooperating(npc,s) then
  return {automatic=true,die=20,dd=0,success=true,confidence=100,answer=s.answer,
   knowledgeUnavailable=not not s.unresolved,source=s.source,level=s.level,npc=npc.name,
   locality=npc.locality,time=GetTimeStamp(),cooperative=true,socialBehaviour='cooperatif'}
 end
 return roll(s,npc)
end
local ask=D.Ask
function D.Ask(s)
 if cooperating(B.npc,s) then
  s=D.RefreshSubject(s);if not s then return B.ShowHome() end
  return D.DeliverResult(s,D.Roll(s,B.npc),false)
 end
 return ask(s)
end
local function activeGiver(npc)
 if not npc or type(IsValidQuestIndex)~='function' or type(GetJournalQuestId)~='function' then return false end
 for index=1,MAX_JOURNAL_QUESTS or 25 do
  if IsValidQuestIndex(index) and cooperating(npc,{task={index=index}}) then return true end
 end
 return false
end
local confidence=B.Confidence
function B.Confidence(npc)
 if activeGiver(npc) then return math.max(80,confidence(npc)) end
 return confidence(npc)
end
local speechCurrent=RolePlayMod.Speechcraft.Current
local speechReport=RolePlayMod.Speechcraft.Report
function RolePlayMod.Speechcraft.Report(npc)
 local report=speechReport(npc)
 if activeGiver(npc) then report=copy(report);report.cap=math.max(80,report.cap);report.questCooperation=true end
 return report
end
function RolePlayMod.Speechcraft.Current(npc)
 if activeGiver(npc) then return math.max(80,speechCurrent(npc)) end
 return speechCurrent(npc)
end
local canPersuade=RolePlayMod.Speechcraft.CanPersuade
function RolePlayMod.Speechcraft.CanPersuade(npc)
 if activeGiver(npc) then return false end
 return canPersuade(npc)
end
local lie=P.MaybeFalseAnswer
function P.MaybeFalseAnswer(s,r)
 if r and r.cooperative then return end
 if lie then return lie(s,r) end
end
local limited=P.Limited
function P.Limited(npc)
 if activeGiver(npc) then return false end
 return limited(npc)
end
