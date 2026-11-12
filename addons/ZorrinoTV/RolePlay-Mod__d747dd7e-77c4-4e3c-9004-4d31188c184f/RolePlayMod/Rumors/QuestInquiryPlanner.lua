if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Current-task inquiry graph: destination identity -> route to that destination -> local search.
-- Knowledge dimensions are independent: knowing the bottom of a mine is not knowing how to reach it.
local B=IHR_Runtime.Beta
local D=B.Dice
local oldReveal=D.Reveal
local function norm(s) return B.Normalize(s) end
local function bare(s) return (norm(s):gsub('^les ',''):gsub('^le ',''):gsub('^la ',''):gsub('^l ','')) end
local function objectiveKey(text)
    text=type(text)=='string' and text or ''
    text=text:gsub('\194\160',' '):gsub('\226\128\175',' ')
    text=text:gsub(':%s*%d+%s*/%s*%d+%s*$',''):gsub('%(%s*%d+%s*/%s*%d+%s*%)%s*$',''):gsub(':%s*%d+%s*$','')
    return norm(text)
end
D.ObjectiveCanonical=objectiveKey
local previousTasks=D.Tasks
function D.Tasks(index)
    local tasks=previousTasks(index)
    if #tasks==0 then return tasks end
    local _,_,active=GetJournalQuestInfo(index)
    for _,task in ipairs(tasks) do
        task.key=task.questKey..':'..tostring(B.Hash(objectiveKey(task.stepText)..'\n'..objectiveKey(active)..'\n'..objectiveKey(task.text)))
    end
    return tasks
end
local function point(x,y) return type(x)=='number' and type(y)=='number' and x>0 and x<1 and y>0 and y<1 end
local function has(text,name) return (' '..norm(text)..' '):find(' '..bare(name)..' ',1,true)~=nil end
local function sentenceName(s) return (B.Name(s):gsub('^Le ','le '):gsub('^La ','la '):gsub('^Les ','les ')) end
local function atPlace(name)
    name=sentenceName(name)
    if name:sub(1,3)=='le ' then return 'au '..name:sub(4) end
    if name:sub(1,4)=='les ' then return 'aux '..name:sub(5) end
    return 'à '..name
end
local function compass(s) return D.GeographicDirections(s) end
local function interior(s)
    local text=' '..norm(s)..' '
    for _,word in ipairs({'au fond','a l interieur','dans la salle','pres du nid','campement','materiel de recherche','derriere','a cote'}) do if text:find(' '..word..' ',1,true) then return true end end
    return false
end
local siteCache,cacheAtlas={}
function D.SiteForName(name,preferredRegion)
    local atlas=B.KnowledgeAtlas()
    if cacheAtlas~=atlas then siteCache={};cacheAtlas=atlas end
    local wanted=bare(name)
    local key=tostring(preferredRegion or '*')..':'..wanted
    if siteCache[key]~=nil then return siteCache[key] or nil end
    local names={[wanted]=true}
    for _,alias in ipairs(IHR_PlaceAliases or {}) do
        if bare(alias.name)==wanted then for _,target in ipairs(alias.targets) do names[bare(target)]=true end end
    end
    local function stem(text)
        text=bare(B.PlaceStem(text))
        for _,prefix in ipairs({'mine a kwamas de ','mine a kwamas d ','site hivernal de ','site estival de ','site printanier de ','site automnal de '}) do
            if text:sub(1,#prefix)==prefix then text=text:sub(#prefix+1);break end
        end
        return text
    end
    local exact,partial={},{ }
    for index,region in pairs(atlas.regions) do
        if not preferredRegion or index==preferredRegion then
            for poi=1,GetNumPOIs(index) do
                local actual=GetPOIInfo(index,poi)
                if type(actual)=='string' and actual~='' then
                    local candidate={name=B.Name(actual),zoneIndex=index,poiIndex=poi,region=region.name,entityType='site'}
                    if names[bare(actual)] then exact[#exact+1]=candidate
                    elseif #stem(name)>=6 and stem(actual)==stem(name) then partial[#partial+1]=candidate end
                end
            end
        end
    end
    local found=#exact==1 and exact[1] or (#exact==0 and #partial==1 and partial[1]) or nil
    siteCache[key]=found or false
    return found -- Homonyms without a verified region are deliberately unresolved.
end

local genericMaps={tamriel=true,nirn=true,aurbis=true,interieur=true,exterieur=true}
function D.Destination(task,meta)
    meta=meta or D.Saved().targets[task.key]
    if meta and bare(meta.mapName)~='' and bare(meta.mapName)~=bare(meta.region) and not genericMaps[bare(meta.mapName)] then
        return {name=B.Name(meta.mapName),site=D.SiteForName(meta.mapName,meta.regionIndex),relation='in',region=meta.region,source=meta.source}
    end
    local focus=norm(task.text):match('([^ ]+)$') or ''
    local choices={}
    for _,place in ipairs(B.MatchPlaces(task.quest)) do
        if place.entityType~='alliance' and place.entityType~='person' and place.entityType~='region' then
            local linked=place.objective and norm(place.objective)==norm(task.text)
            local about=false
            if #focus>=5 then
                for clause in (place.source or ''):gmatch('[^.!?;,\n]+') do
                    local text=' '..norm(clause)..' '
                    if text:find(' '..focus..' ',1,true) and (has(clause,place.name) or has(clause,B.PlaceStem(place.name))) then about=true end
                end
            end
            if linked or about then
                local site=D.SiteForName(place.name,meta and meta.regionIndex or nil)
                if site then choices[bare(site.name)]={name=B.Name(place.name),site=site,relation='in',region=site.region,source='Client FR : lieu lié à l’objectif visible'} end
            end
        end
    end
    local found,ambiguous
    for _,place in pairs(choices) do if found then ambiguous=true end;found=place end
    if found and not ambiguous then return found end
    local p=D.positions[task.key]
    if p and (not p.taskText or norm(p.taskText)==norm(task.text)) and GetTimeStamp()-p.time<20 and p.mapId==GetCurrentMapId() then
        local best,bestDistance
        for i=1,GetNumPOIs(p.zoneIndex) do
            local x,y,_,_,shown=GetPOIMapInfo(p.zoneIndex,i)
            if shown and point(x,y) then
                local distance=(p.x-x)^2+(p.y-y)^2
                if distance<.0016 and (not bestDistance or distance<bestDistance) then bestDistance=distance;best=B.Name(GetPOIInfo(p.zoneIndex,i)) end
            end
        end
        if best then return {name=best,site=D.SiteForName(best,D.Region(p.zoneIndex) and D.Region(p.zoneIndex).zoneIndex or nil),relation='near',source=p.source} end
    end
end
function D.InquiryKnowledge(task,destination,includeAcquired)
    local known={identity=false,route=false,region=false,interior=false,exact=false}
    if not destination then return known end
    local alternatives={destination.name}
    if destination.site then
        alternatives[#alternatives+1]=destination.site.name
        for _,alias in ipairs(IHR_PlaceAliases or {}) do for _,target in ipairs(alias.targets) do if bare(target)==bare(destination.site.name) then alternatives[#alternatives+1]=alias.name end end end
    end
    for _,source in ipairs(task.quest.sources) do
        if source.kind~='Objectif accompli' then
            local linked=source.objective and norm(source.objective)==norm(task.text)
            local named=false
            for _,name in ipairs(alternatives) do if has(source.text,name) then named=true end end
            if named then known.identity=true end
            if destination.region and has(source.text,destination.region) then known.region=true end
            if linked and interior(source.text) then known.interior=true end
            if linked and compass(source.text) then
                -- Interior directions need an external named anchor before they can locate an entrance.
                local external=named
                for _,city in pairs(B.KnowledgeAtlas().public) do if city.entityType=='city' and has(source.text,city.name) then external=true end end
                if external or not interior(source.text) then known.route=true end
            elseif named then
                for sentence in source.text:gmatch('[^.!?\n]+') do
                    local exactName=false
                    for _,name in ipairs(alternatives) do if has(sentence,name) then exactName=true end end
                    if exactName and compass(sentence) and not interior(sentence) then known.route=true end
                end
            end
        end
    end
    if destination.region and B.Here(destination.region) then known.region=true end
    if B.Here(destination.name) or (destination.site and B.Here(destination.site.name)) then known.identity=true;known.route=true end
    if includeAcquired~=false then
        for _,hint in pairs(D.Saved().hints) do
            if hint.taskKey==task.key then
                local same=not hint.destination or bare(hint.destination)==bare(destination.name)
                if same then
                    if hint.factKind=='destination' then known.identity=true end
                    if hint.factKind=='route' then known.identity=true;known.route=true end
                    if hint.factKind=='region' then known.identity=true;known.region=true end
                    if hint.factKind=='spot' and norm(hint.taskText)==norm(task.text) then known.identity=true;known.exact=true end
                    if not hint.factKind then
                        if has(hint.text,destination.name) then known.identity=true end
                        if compass(hint.text) then known.route=true end
                        -- Legacy level 3 is a UI precision flag, not proof that
                        -- the current person/item was located. Old betas also
                        -- used it for site routes and unrelated landmarks.
                        local target=D.TargetForTask and D.TargetForTask(task)
                        if hint.level==3 and (not target or target.kind=='place') then known.exact=true end
                    end
                end
            end
        end
    end
    return known
end
function D.CleanRouteText(text)
    if type(text)~='string' then return text end
    text=text:gsub(' de [Ll]e ([^ .,!?:;\n]+)',function(noun) return ' du '..zo_strlower(noun) end)
        :gsub(' de [Ll]es ([^ .,!?:;\n]+)',function(noun) return ' des '..zo_strlower(noun) end)
        :gsub(' de La ', ' de la ')
    return (text:gsub('Depuis ([^,\n]+),',function(name)
        local place=B.PublicPlace(name)
        return place and place.entityType=='region' and 'D’ici,' or ('Depuis '..name..',')
    end))
end
function D.ReadRoute(site)
    if not site or not site.poiIndex then return end
    if ZO_WorldMap and not ZO_WorldMap:IsHidden() then return end
    local ok,result=pcall(function()
        SetMapToPlayerLocation()
        local index=type(GetMapIndexByZoneId)=='function' and type(GetZoneId)=='function' and GetMapIndexByZoneId(GetZoneId(site.zoneIndex)) or nil
        if index and type(SetMapToMapListIndex)=='function' then
            if SetMapToMapListIndex(index)==SET_MAP_RESULT_FAILED then return end
        elseif type(GetCurrentMapZoneIndex)=='function' and GetCurrentMapZoneIndex()~=site.zoneIndex then return end
        local tx,ty,_,_,shown=GetPOIMapInfo(site.zoneIndex,site.poiIndex)
        if not shown or not point(tx,ty) then return end
        local route={name=site.name,region=site.region,x=tx,y=ty,origin=B.npc and B.Name(B.npc.locality) or '',source='Client FR : coordonnées du lieu et des repères sur la même carte'}
        local originPlace=B.PublicPlace(route.origin)
        if bare(route.origin)==bare(site.region) or (originPlace and originPlace.entityType=='region') then route.origin='' end
        local px,py=GetMapPlayerPosition('player')
        local here=D.Region(GetUnitZoneIndex('player'))
        local region=D.Region(site.zoneIndex)
        if here and region and here.zoneIndex==region.zoneIndex and point(px,py) then
            local dx,dy=tx-px,ty-py
            route.near=dx*dx+dy*dy<.0004
            route.bearing=B.Bearing(dx,dy)
            route.distanceMeters=D.DistanceMetersFR and D.DistanceMetersFR(px,py,tx,ty)
        end
        local best
        for _,anchor in pairs(B.KnowledgeAtlas().public) do
            if anchor.entityType=='city' and anchor.zoneIndex==site.zoneIndex and bare(anchor.name)~=bare(site.name) then
                local ax,ay,_,_,visible=GetPOIMapInfo(anchor.zoneIndex,anchor.poiIndex)
                if visible and point(ax,ay) then
                    local d=(ax-tx)^2+(ay-ty)^2
                    if d>.000225 and (not best or d<best) then best=d;route.anchor=B.Name(anchor.name);route.anchorBearing=B.Bearing(tx-ax,ty-ay) end
                end
            end
        end
        return route
    end)
    SetMapToPlayerLocation()
    if ok then return result end
end
local function targetQuestion(task)
    local first,rest=task.text:match('^(%S+)%s+(.+)$')
    local action=norm(first)
    if not rest or ({attendez=true,patientez=true,survivez=true,choisissez=true})[action] then return end
    local english={talk=true,find=true,collect=true,kill=true,enter=true,["return"]=true,go=true,retrieve=true,recover=true,search=true,rescue=true}
    local infinitives={trouver=true,parler=true,recuperer=true,chercher=true,rejoindre=true}
    if not action:match('ez$') and not action:match('ez vous$') and not english[action] and not infinitives[action] then return end
    rest=rest:gsub('%s*:%s*%d+.*$',''):gsub('[.!?]+$','')
    if action=='parlez' or action=='parler' or action=='talk' or action=='adressez vous' then
        rest=rest:match('^à%s+(.+)$') or rest:match('^avec%s+(.+)$') or rest:match('^to%s+(.+)$') or (rest:match('^au%s+(.+)$') and ('le '..rest:match('^au%s+(.+)$'))) or (rest:match('^aux%s+(.+)$') and ('les '..rest:match('^aux%s+(.+)$'))) or rest
    end
    if action=='utilisez' then return 'Où dois-je utiliser '..rest..' ?' end
    if action=='placez' or action=='deposez' then return 'Où dois-je déposer '..rest..' ?' end
    if action=='donnez' or action=='apportez' or action=='livrez' or action=='remettez' or action=='rapportez' then
        local recipient=rest:match(' à (.+)$')
        if recipient then return 'Savez-vous où je pourrais trouver '..recipient..' ?' end
        return 'Où dois-je remettre '..rest..' ?'
    end
    if action=='allez' or action=='retournez' or action=='rejoignez' or action=='rendez vous' or action=='entrez' or action=='penetrez' then
        rest=rest:match('^dans%s+(.+)$') or rest:match('^à%s+(.+)$') or rest:match('^vers%s+(.+)$') or (rest:match('^au%s+(.+)$') and ('le '..rest:match('^au%s+(.+)$'))) or rest
        return 'Quel chemin prendre pour rejoindre '..rest..' ?'
    end
    return 'Savez-vous où je pourrais trouver '..rest..' ?'
end
D.QuestionForTask=targetQuestion

local function subject(task,kind,destination,answer,question,level,source)
    return {planner=2,kind=kind,task=task,destination=destination.name,relation=destination.relation,
        family='v2:'..kind..':'..bare(destination.name),key=task.key..':v2:'..kind..':'..bare(destination.name),
        title=task.quest.name,answer=answer,question=question,level=level,source=source or destination.source}
end
function D.NpcOnSite(task,destination)
    if not B.npc or not destination then return false end
    if B.Here(destination.name) or (destination.site and B.Here(destination.site.name)) then return true end
    -- A documented stronghold may use a different name from its map POI.
    for _,alias in ipairs(IHR_PlaceAliases or {}) do
        local matches=bare(alias.name)==bare(destination.name)
        for _,name in ipairs(alias.targets) do if bare(name)==bare(destination.name) then matches=true end end
        if matches then
            if B.Here(alias.name) then return true end
            for _,name in ipairs(alias.targets) do if B.Here(name) then return true end end
        end
    end
    -- Exact client POI membership is stronger evidence than distance to a map marker.
    if destination.site and type(GetCurrentSubZonePOIIndices)=='function' then
        local zone,poi=GetCurrentSubZonePOIIndices()
        if zone==destination.site.zoneIndex and poi==destination.site.poiIndex then return true end
    end
    local meta=task and D.Saved().targets[task.key]
    if meta and meta.mapId==GetCurrentMapId() and bare(meta.mapName)~=bare(meta.region)
        and (bare(meta.mapName)==bare(destination.name) or (destination.site and bare(meta.mapName)==bare(destination.site.name))) then
        return true
    end
    return false
end
function D.PlanTask(task)
    local initialQuestion=targetQuestion(task)
    if not initialQuestion then return {} end
    local meta=D.Metadata(task)
    D.RequestPosition(task)
    local destination=D.Destination(task,meta)
    if not destination then return {} end
    local known=D.InquiryKnowledge(task,destination)
    local result={}
    if not known.identity then
        local question=initialQuestion
        if question then
            local answer=destination.relation=='near' and ('Cherchez près de '..sentenceName(destination.name)..'.') or ('C’est '..atPlace(destination.name)..' que vous devriez chercher.')
            result[#result+1]=subject(task,'destination',destination,answer,question,1)
        end
        return result -- The next question is unlocked only after learning this name.
    end
    if not known.route then
        local route=D.ReadRoute(destination.site)
        if route and (route.bearing or route.anchor) then
            local answer=destination.name..' ? '
            if route.near then answer=answer..'Vous êtes tout près de ce lieu. Regardez autour de vous.'
            elseif route.bearing then answer=answer..(route.origin~='' and ('Depuis '..route.origin..', dirigez-vous ') or 'Depuis ici, dirigez-vous ')..route.bearing..'.'
            else answer=answer..'Ce lieu se trouve dans la région « '..route.region..' ».' end
            if route.anchor and (not route.bearing or bare(route.anchor)~=bare(route.origin)) then answer=answer..' C’est '..route.anchorBearing..' '..D.OfPlace(route.anchor)..', si vous connaissez l’endroit.' end
            result[#result+1]=subject(task,'route',destination,answer,'Comment rejoindre '..sentenceName(destination.name)..' ?',2,route.source)
        elseif not known.region and destination.region then
            result[#result+1]=subject(task,'region',destination,destination.name..' se trouve dans '..sentenceName(destination.region)..'.','Dans quelle région se trouve '..sentenceName(destination.name)..' ?',1)
        end
    end
    local p=D.positions[task.key]
    if not known.exact and D.NpcOnSite(task,destination) and p and (not p.taskText or norm(p.taskText)==norm(task.text)) and p.radius<=0 and GetTimeStamp()-p.time<20 and p.mapId==GetCurrentMapId() then
        local x,y=GetMapPlayerPosition('player')
        if point(x,y) then
            local dx,dy=p.x-x,p.y-y
            do
                local answer
                if dx*dx+dy*dy<.000009 then answer='Vous êtes sur place. Regardez tout autour de vous.'
                elseif dx*dx+dy*dy<.000625 then answer='C’est tout près : regardez '..B.Bearing(dx,dy)..' de nous.'
                else answer='Dans ce lieu, dirigez-vous '..B.Bearing(dx,dy)..' de notre position.' end
                local question=destination.relation=='near' and ('Où chercher exactement près de '..sentenceName(destination.name)..' ?') or ('Où chercher exactement dans '..sentenceName(destination.name)..' ?')
                local precise=subject(task,'spot',destination,answer,question,3,p.source)
                precise.key=precise.key..':progress:'..tostring(B.Hash(norm(task.text)))
                result[#result+1]=precise
            end
        end
    end
    return result
end
function D.Subjects(index)
    local result,seen={},{}
    for _,task in ipairs(D.Tasks(index)) do
        for _,entry in ipairs(D.PlanTask(task)) do
            if not seen[entry.key] then result[#result+1]=entry;seen[entry.key]=true end
        end
    end
    return result -- No political/history filler in a current-task inquiry.
end
local oldRefresh=D.RefreshSubject
function D.RefreshSubject(entry)
    if entry.planner==2 then
        local task=D.Fresh(entry.task)
        if not task then return end
        for _,candidate in ipairs(D.PlanTask(task)) do if candidate.key==entry.key then return candidate end end
        return
    end
    return oldRefresh(entry)
end
function D.Followups(entry)
    if not entry.task then return {} end
    local task=D.Fresh(entry.task)
    if not task then return {} end
    local result={}
    for _,nextQuestion in ipairs(D.PlanTask(task)) do
        if nextQuestion.key~=entry.key then
            local label=nextQuestion.question
            if entry.kind=='destination' and nextQuestion.kind=='route' then
                local name=bare(nextQuestion.destination)
                if name:find('ruines',1,true) then label='Et où se trouvent ces ruines ?'
                elseif name:find('mine',1,true) then label='Comment rejoindre cette mine ?' end
            end
            result[#result+1]={subject=nextQuestion,text=label}
        end
    end
    return result
end
function D.UsefulAcquiredHint(task,hint)
    local destination=D.Destination(task)
    if not destination then return true end
    local base=D.InquiryKnowledge(task,destination,false)
    if hint.factKind=='destination' then return not base.identity end
    if hint.factKind=='route' then return not base.route end
    if hint.factKind=='region' then return not base.region end
    if hint.factKind=='spot' then return norm(hint.taskText)==norm(task.text) end
    -- Retain old records, but hide a legacy map-name answer already present in the journal.
    if not compass(hint.text) and hint.level<3 and (has(hint.text,destination.name) or (destination.region and has(hint.text,destination.region))) then
        if has(hint.text,destination.name) then return not base.identity end
        if destination.region and has(hint.text,destination.region) then return not base.region end
    end
    return true
end
function D.Reveal(entry,roll)
    if entry.planner~=2 then return oldReveal(entry,roll) end
    if not roll or not roll.success then return false end
    local task=D.Fresh(entry.task)
    if not task then return false end
    local saved=D.Saved()
    if not saved.hints[entry.key] or (D.SameOrigin and not D.SameOrigin(saved.hints[entry.key])) then
        saved.hints[entry.key]={taskKey=task.key,questKey=task.questKey,stepText=task.stepText,taskText=task.text,
            text=roll.answer,npc=B.Name(roll.npc),locality=B.Name(roll.locality),level=roll.level,time=GetTimeStamp(),
            originZone=roll.originZone,originX=roll.originX,originZ=roll.originZ,scopeRadius=entry.scopeRadius,source=roll.source,factKind=entry.kind,destination=entry.destination,relation=entry.relation,planner=2}
        B.Remember({name=task.text,quest=task.quest},roll.answer,roll.npc)
    end
    return true
end
function B.GetAcquiredQuestHint(index,stepText,conditionText)
    if not B.saved or not B.saved.enabled then return '' end
    local task
    for _,current in ipairs(D.Tasks(index)) do if objectiveKey(current.stepText)==objectiveKey(stepText) and objectiveKey(current.text)==objectiveKey(conditionText) then task=current;break end end
    if not task then return '' end
    local entries={}
    for _,hint in pairs(D.Saved().hints) do
        if hint.taskKey==task.key and objectiveKey(hint.stepText)==objectiveKey(stepText) and objectiveKey(hint.taskText)==objectiveKey(conditionText) and D.UsefulAcquiredHint(task,hint) then entries[#entries+1]=hint end
    end
    table.sort(entries,function(a,b) return a.level>b.level or a.level==b.level and a.time>b.time end)
    local richer={}
    for _,hint in ipairs(entries) do
        if hint.destination and (hint.factKind=='route' or hint.factKind=='spot') then richer[bare(hint.destination)]=true end
    end
    local lines,seen={},{}
    for _,hint in ipairs(entries) do
        local key=norm(hint.text)
        local superseded=hint.destination and richer[bare(hint.destination)] and (hint.factKind=='destination' or hint.factKind=='region')
        if not seen[key] and not superseded and #lines<4 then
            seen[key]=true
            local location=B.Name(hint.locality)
            lines[#lines+1]='\nRenseignement de '..B.Name(hint.npc)..(location~='' and (' — '..location) or '')..' : '..B.Name(hint.text)
        end
    end
    return table.concat(lines)
end

