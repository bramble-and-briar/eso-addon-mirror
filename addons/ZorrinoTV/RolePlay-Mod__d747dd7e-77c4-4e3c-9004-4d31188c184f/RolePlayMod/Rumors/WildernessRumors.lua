if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Tavern travelers talk about remote overland starts, not quests in the city.
local B=IHR_Runtime.Beta
local D=B.Dice
local W={};B.WildernessRumors=W
W.cityExclusionRadius=.035 -- City centre, not a tenth of the entire region.
local function norm(s) return B.Normalize(s or '') end
local function point(x,y) return type(x)=='number' and type(y)=='number' and x>0 and x<1 and y>0 and y<1 end
local function distance(a,b) return (a.x-b.x)^2+(a.y-b.y)^2 end
local function choice(text,callback) return {text=text,callback=callback} end
local function keysame(a,b) return a.quest==b.quest and a.mapKey==b.mapKey and norm(a.giver)==norm(b.giver) end
-- French city names already present in the client-derived city catalogue.
-- Villages, camps and hamlets remain valid rumor destinations in the Dominion.
local dominionMaps={auridon=true,grahtwood=true,greenshade=true,malabaltor=true,reapersmarch=true}
local majorCities={}
for _,name in ipairs({'Mistral','Guet de Vulkhel','Gardeciel','Prime-Tenure','Faneracine','Marbruk','Foyeraie','Port Vélyn','Silvenar','Comptoir commercial de Baandari',"Rawl’kha",'Dune','Arenthia'}) do majorCities[norm(name)]=true end
function W.IsMajorCity(name,map,detectedCity)
    if dominionMaps[(map or ''):match('^([^/]+)/')] then
        return majorCities[norm(name):gsub('^le ',''):gsub('^la ','')] or false
    end
    return not not detectedCity
end
function W.IsSecondary(id)
    local db=IHR_QuestRumorDB;local meta=db and db.meta[id]
    if not meta then return nil end
    -- LibQuestData schema: type=1, repeatability=2, zone display type=7.
    -- Story-of-zone quests often have QUEST_TYPE_NONE: type alone is not enough.
    local kind,repeatable,display=tonumber(meta[1]),tonumber(meta[2]),tonumber(meta[7])
    if repeatable~=0 or display==(ZONE_DISPLAY_TYPE_ZONE_STORY or 10) then return false end
    if display==nil or display<0 then return false end
    if kind~=0 and kind~=1 and kind~=5 then return false end
    if (db.removed or {})[id] or (db.companionRapport or {})[id] then return false end
    return true
end
local oldHospitality=B.HospitalityContext
function B.HospitalityContext(npc)
    if not npc then return false end
    if B.IsPublican(npc) then
        -- Speaking to the establishment's staff also makes its nearby clientele identifiable.
        if B.saved and B.RegisterVenue then B.RegisterVenue('Auberge ou brasserie : '..npc.name) end
        return true,'auberge ou brasserie'
    end
    return oldHospitality(npc)
end
function W.RegionSnapshot()
    if ZO_WorldMap and not ZO_WorldMap:IsHidden() then return end
    local ok,result=pcall(function()
        local index=GetUnitZoneIndex('player')
        local region=D.Region(index)
        if not region then return end
        index=region.zoneIndex
        SetMapToPlayerLocation()
        local mapIndex=type(GetMapIndexByZoneId)=='function' and type(GetZoneId)=='function' and GetMapIndexByZoneId(GetZoneId(index))
        if not mapIndex or type(SetMapToMapListIndex)~='function' then return end
        if SetMapToMapListIndex(mapIndex)==SET_MAP_RESULT_FAILED then return end
        if type(GetCurrentMapZoneIndex)=='function' and GetCurrentMapZoneIndex()~=index then return end
        if type(GetMapType)=='function' and MAPTYPE_ZONE and GetMapType()~=MAPTYPE_ZONE then return end
        local map=B.MapKey();if not map then return end
        local snapshot={mapKey=map,region=region.name,zoneIndex=index,landmarks={},cities={}}
        local px,py=GetMapPlayerPosition('player')
        if point(px,py) then snapshot.player={x=px,y=py} end
        local atlas=B.KnowledgeAtlas()
        local cities={}
        for _,p in pairs(atlas.public) do if p.entityType=='city' and p.zoneIndex==index then cities[norm(p.name)]=true end end
        for i=1,GetNumPOIs(index) do
            local name=GetPOIInfo(index,i)
            local x,y,_,icon=GetPOIMapInfo(index,i)
            if name and name~='' and point(x,y) then
                icon=type(icon)=='string' and icon:lower() or ''
                local city=cities[norm(name)] or icon:find('poi_city',1,true) or icon:find('poi_town',1,true)
                local item={name=B.Name(name),x=x,y=y,city=not not city}
                if W.IsMajorCity(name,map,city) then snapshot.cities[#snapshot.cities+1]=item end
                -- Do not use private homes as public navigation landmarks.
                if not icon:find('house',1,true) and not icon:find('housing',1,true) then snapshot.landmarks[#snapshot.landmarks+1]=item end
            end
        end
        -- Without city positions, 'far from every city' cannot be established.
        if #snapshot.cities==0 or #snapshot.landmarks==0 then return end
        return snapshot
    end)
    SetMapToPlayerLocation()
    if ok then return result end
end
local function namedPerson(r)
    if r.object or not r.giver or r.giver=='' then return false end
    local name=' '..norm(r.giver)..' '
    for _,word in ipairs({'affiche','lettre','panneau','cadavre','journal','note','notice','livre','parchemin','advertisement','letter','book','corpse','scroll','poster','heraut','messager inconnu','une personne','squelette'}) do
        if name:find(' '..word..' ',1,true) then return false end
    end
    return true
end
function W.IsRemote(r,snapshot)
    if not r or not snapshot or r.mapKey~=snapshot.mapKey or not r.anchor or not point(r.anchor.x,r.anchor.y) then return false end
    if not W.IsSecondary(r.quest) then return false end
    local townData=IHR_TavernRumorLocations
    -- Older city-map copies can be inaccurate. Native regional city positions
    -- establish remoteness; a historical city tag alone cannot override them.
    if townData and townData.cityMaps[r.mapKey] then return false end
    if #snapshot.cities==0 then return false end
    for _,city in ipairs(snapshot.cities) do if distance(r.anchor,city)<W.cityExclusionRadius^2 then return false end end
    return true
end
local function nearby(r,snapshot)
    local found={}
    for _,p in ipairs(snapshot.landmarks) do found[#found+1]={name=p.name,x=p.x,y=p.y,distance=distance(r.anchor,p),city=p.city} end
    table.sort(found,function(a,b) return a.distance<b.distance or a.distance==b.distance and a.name<b.name end)
    return found
end
function W.Between(anchor,a,b)
    local dx,dy=b.x-a.x,b.y-a.y
    local length=dx*dx+dy*dy
    if length<.0025 or length>.16 then return false end
    local t=((anchor.x-a.x)*dx+(anchor.y-a.y)*dy)/length
    if t<.15 or t>.85 then return false end
    local px,py=a.x+t*dx,a.y+t*dy
    return (anchor.x-px)^2+(anchor.y-py)^2<.0004
end
function W.Route(r,snapshot)
    local refs=nearby(r,snapshot);local first=refs[1]
    if not first or first.distance>.04 then return end
    local line
    local function of(name) return B.RouteVoice and B.RouteVoice.Of(name) or ('de '..name) end
    if first.distance<.0001 then line='Cherchez près '..of(first.name)..'.'
    else line='Pour vous repérer, cherchez '..B.Bearing(r.anchor.x-first.x,r.anchor.y-first.y)..' '..of(first.name)..'.' end
    -- 'Between' is a geometric assertion, not a random pair of place names.
    for a=1,math.min(5,#refs) do
        for b=a+1,math.min(6,#refs) do
            if refs[a].name~=refs[b].name and W.Between(r.anchor,refs[a],refs[b]) then
                local function place(name) return name:gsub('^Le ','le '):gsub('^La ','la '):gsub('^Les ','les ') end
                return line..' C’est entre '..place(refs[a].name)..' et '..place(refs[b].name)..'.',first.name
            end
        end
    end
    return line,first.name
end
local function eligible(id)
    return B.RumorEligible({quest=id,mapKey=B.MapKey()})
end
function W.QuestKnown(id)
    local journal=B.saved and B.saved.travelJournalV1
    local note=journal and journal.entries and journal.entries[tostring(id)]
    return note~=nil or (B.TravelJournal and B.TravelJournal.Has(id))
        or (type(HasQuest)=='function' and HasQuest(id))
        or (type(HasCompletedQuest)=='function' and HasCompletedQuest(id))
end
function W.Candidates(npc)
    W.catalogueReady=false
    local snapshot=W.RegionSnapshot();if not snapshot then return {} end
    local db=IHR_QuestRumorDB;if not db then return {} end
    W.catalogueReady=#snapshot.cities>0 and db.maps[snapshot.mapKey]~=nil
    local byId={}
    local function add(row,observedName)
        local id=tonumber(row[3]);local raw=observedName or db.givers[tonumber(row[4])]
        if not id then return end
        local r={quest=id,giver=B.Name(raw or ''),object=not not db.objects[id],mapKey=snapshot.mapKey,
            anchor={x=row[1],y=row[2]},regionName=snapshot.region,regionIndex=snapshot.zoneIndex}
        if not W.IsRemote(r,snapshot) then return end
        r.person=namedPerson(r)
        local route,reference=W.Route(r,snapshot)
        route=route or 'Je sais seulement que ça se passe dans la région.'
        local previous=byId[id]
        -- Deterministic source selection prevents a different 'location' on every reply.
        if previous and (previous.giver<r.giver or previous.giver==r.giver and (previous.anchor.x<r.anchor.x or previous.anchor.x==r.anchor.x and previous.anchor.y<=r.anchor.y)) then return end
        local nearestCity,best
        for _,city in ipairs(snapshot.cities) do local d=distance(r.anchor,city);if not best or d<best then best=d;nearestCity=city end end
        r.town=nearestCity and ('Routes autour de '..nearestCity.name) or 'Hors des villes'
        r.title='Une piste : '..r.giver;r.route=route;r.reference=reference
        local premise=IHR_RumorPremisesFR and IHR_RumorPremisesFR[id]
        if id==4339 then premise='Son équipe de chercheurs a été décimée par les animaux sauvages de Scinderacine. Elle cherche quelqu’un pour retrouver les journaux de ses collègues.' end
        if id==4975 then premise='Cette prêtresse d’Y’ffre cherche à soigner les ruines de Gil-Var-Delle en mêlant des eaux bénies aux cascades de la vallée.' end
        -- A real quest title and a verified start still make a useful lead when
        -- the catalogue has no account of what happened there.
        local title=type(GetQuestName)=='function' and GetQuestName(id) or ''
        if not title or title=='' then title=(db.names or {})[id] end
        r.questName=title and B.Name(title) or nil
        if not r.person then
            if r.questName and r.questName~='' then
                r.title='Une piste : '..r.questName
                r.text='On m’a parlé d’une affaire appelée « '..r.questName..' ».\n\n'..route
            end
        elseif not premise or premise=='' then
            r.text='On m’a dit que vous pourriez vous renseigner auprès de '..r.giver..'.\n\n'..route
        end
        local person=IHR_RumorPeopleFR and IHR_RumorPeopleFR[id]
        if r.person and premise and premise~='' and person and norm(person.name)==norm(r.giver) then
            local lead=(person.female and 'Une ' or 'Un ')..person.race..(person.female and ' nommée ' or ' nommé ')..r.giver..' aurait besoin d’aide.'
            if premise and premise:sub(1,#person.prefix)==person.prefix then
                local rest=premise:sub(#person.prefix+1):gsub('^[ ,]+','')
                r.text=lead..' '..(person.female and 'Elle ' or 'Il ')..rest..'\n\n'..route
            else r.text=lead..(premise and (' '..premise) or '')..'\n\n'..route end
        elseif r.person and premise and premise~='' then r.text='On m’a parlé de '..r.giver..'. '..premise..'\n\n'..route end
        if r.person and premise and premise~='' then r.account=premise end
        r.source='LibQuestData : type, prérequis et coordonnées sur '..snapshot.mapKey..' ; repères géographiques du client'
        if premise and r.person then r.source='Client FR : description initiale '..id..' ; '..r.source end
        byId[id]=r
    end
    for _,row in ipairs(db.maps[snapshot.mapKey] or {}) do add(row) end
    local discovered=B.rumorDiscoveries and B.rumorDiscoveries.starts[snapshot.mapKey]
    for id,entry in pairs(discovered or {}) do
        local numericId=tonumber(id)
        if numericId and not byId[numericId] and type(entry.name)=='string' then
            add({entry.x,entry.y,numericId},entry.name)
        end
    end
    local result,progress={},{total=0,remaining=0}
    for id,r in pairs(byId) do
        local superseded=false
        if type(HasCompletedQuest)=='function' then
            for _,replacement in ipairs((db.breadcrumbs or {})[id] or {}) do
                if HasCompletedQuest(replacement) then superseded=true;break end
            end
        end
        if not superseded then
            progress.total=progress.total+1
            if not W.QuestKnown(id) then
                progress.remaining=progress.remaining+1
                if r.text and eligible(id) then
                    if not r.person then r.anchor=nil end
                    result[#result+1]=r
                end
            end
        end
    end
    return result,progress
end
local session
local function currentSession(npc)
    local map=B.MapKey()
    if not session or session.npc~=npc or session.map~=map then session={npc=npc,map=map,seen={},convinced={}} end
    return session
end
function W.IsConvinced(npc,mode) return currentSession(npc).convinced[mode] or false end
function W.KnowsRumor(npc,r,index)
    -- Knowledge is distinct from the persistent delivery quota applied later.
    local seed=B.Hash(B.Profile(npc).key..':knows-rumor:'..r.quest)
    return B.IsPublican(npc) or index==1 or B.Hash(tostring(seed)..':'..r.quest..':'..B.Profile(npc).key)%3==0
end
function W.RestartRumors(npc)
    -- A replay keeps the trust already earned in this conversation.
    currentSession(npc).seen={}
end
local oldClose=B.Close
function B.Close(...) session=nil;return oldClose(...) end
local oldReset=B.ResetTavernRumors
function B.ResetTavernRumors(silent)
    session=nil
    local rolls=B.saved and B.saved.diceV1 and B.saved.diceV1.rolls
    for key in pairs(rolls or {}) do if key:find(':wilderness-rumor:',1,true) then rolls[key]=nil end end
    return oldReset(silent)
end
if SLASH_COMMANDS then SLASH_COMMANDS['/ihrrumeurs']=function()
    B.ResetTavernRumors(false)
    if B.npc and B.HospitalityContext(B.npc) then B.ShowQuestRumors() end
end end
-- Refusing to talk does not consume a lead. Old refusal caches are deliberately
-- ignored here; the social test owns willingness, the catalogue owns knowledge.
function B.MarkRumorRefusal(r,result) end
function B.KnownRumors(npc)
    if not B.HospitalityContext(npc) then return {} end
    local profile=B.Profile(npc);local pool={}
    for _,r in ipairs(W.Candidates(npc)) do
        -- Mixing the numeric hash again avoids the old additive prefix: sorting
        -- hash(NPC .. quest) alone gave almost everyone the same first quests.
        local seed=B.Hash(profile.key..':voyage:'..r.quest)
        pool[#pool+1]={rumor=r,order=B.Hash(tostring(seed)..':'..r.quest..':'..profile.key)}
    end
    table.sort(pool,function(a,b) return a.order<b.order or a.order==b.order and a.rumor.quest<b.rumor.quest end)
    local result={};local heard,noted,remaining,known=0,0,0,0
    for i,item in ipairs(pool) do
        local r=item.rumor
        local inBook=RolePlayMod.Enabled('travelJournal') and B.TravelJournal.Has(r.quest)
        if inBook then noted=noted+1 else remaining=remaining+1 end
        -- Automatic notes are shared across speakers. They no longer repeat a
        -- recorded rumor, and noting it does not refill a traveler's knowledge.
        if W.KnowsRumor(npc,r,i) then
            known=known+1
            if inBook or currentSession(npc).seen[r.quest] then heard=heard+1
            else result[#result+1]=r end
        end
    end
    W.status={map=B.MapKey(),catalogueReady=W.catalogueReady,eligible=#pool,regionalRemaining=remaining,noted=noted,known=known,available=#result,heard=heard,cooling=0,scope='départs éloignés des villes'}
    B.saved.tavernLastCheck136=W.status
    return result
end
function B.HearRumor(r)
    if not B.npc or not B.HospitalityContext(B.npc) or not eligible(r.quest) then return end
    for _,known in ipairs(B.KnownRumors(B.npc)) do
        if keysame(r,known) then
            currentSession(B.npc).seen[r.quest]=true
            local speech=RolePlayMod.Speechcraft and RolePlayMod.Speechcraft.Enabled()
            currentSession(B.npc).convinced[speech and 'speechcraft' or 'dice']=true
            B.saved.rumorsHeard=B.saved.rumorsHeard or {};B.saved.rumorsHeard[r.quest]=GetTimeStamp()
            local text=W.VoiceRumor and W.VoiceRumor(known,B.npc) or known.text
            if RolePlayMod.Enabled('travelJournal') then B.TravelJournal.Note(known,text,B.npc) end
            return text
        end
    end
end
function B.ShowQuestRumors(continueCycle)
    if not B.npc then return end
    if not B.HospitalityContext(B.npc) then B.ShowHome();return end
    -- Session navigation never clears the persistent establishment stock.
    if continueCycle~=true then W.RestartRumors(B.npc) end
    local r=B.KnownRumors(B.npc)[1]
    if not r then
        if RolePlayMod.Speechcraft then RolePlayMod.Speechcraft.pendingSubject=nil end
        local choices={}
        choices[#choices+1]=choice('Merci. Je vous laisse.',function() B.ShowHome() end)
        B.Show('Les nouvelles de la route',W.EndLine(B.npc,W.status),choices,false,nil)
        return
    end
    D.Ask({kind='rumor',key='wilderness-rumor:'..r.quest,title='Des nouvelles de la route',question='Avez-vous entendu parler de quelqu’un qui aurait besoin d’aide ?',answer=r.text,level=1,source=r.source,rumor=r})
end

-- Ordinary native interactions with the staff identify the venue as well.
local function rememberVenue()
    if not B.saved then return end
    local npc={name=B.Name(GetUnitName('interact')),caption=type(GetUnitCaption)=='function' and GetUnitCaption('interact') or ''}
    if npc.name~='' and B.IsPublican(npc) then B.RegisterVenue('Auberge ou brasserie : '..npc.name) end
end
for _,event in ipairs({EVENT_OPEN_STORE,EVENT_CHATTER_BEGIN}) do
    if event then EVENT_MANAGER:RegisterForEvent('IHRTravelVenue'..event,event,rememberVenue) end
end
