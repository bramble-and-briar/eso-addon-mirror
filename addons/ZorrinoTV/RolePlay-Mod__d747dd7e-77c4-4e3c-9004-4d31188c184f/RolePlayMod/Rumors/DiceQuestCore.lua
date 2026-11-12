if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- D20 decides cooperation. Geography comes exclusively from current client data or verified records.
local B=IHR_Runtime.Beta
local D={positions={},pending={},requested={}};B.Dice=D
local function norm(s) return B.Normalize(s) end
local function bare(s) return (norm(s):gsub('^les ',''):gsub('^le ',''):gsub('^la ',''):gsub('^l ','')) end
local function validPoint(x,y) return type(x)=='number' and type(y)=='number' and x>0 and x<1 and y>0 and y<1 end
function D.Saved()
    B.saved.diceV1=B.saved.diceV1 or {rolls={},hints={},targets={}}
    return B.saved.diceV1
end
-- Past minigame scores are preserved in saved variables, but no longer decide the difficulty.
function B.EffectiveTrust(npc)
    if B.saved.speechcraftEnabled==false or B.saved.trustEnabled==false then return 0 end
    local profile=B.Profile(npc)
    local personality=({avenant=3,reserve=1,mefiant=-2,presse=-3})[profile.personality] or 0
    return personality+B.Reputation(npc)+B.OriginModifier(npc,profile)+B.CrimePenalty(npc)
end
function B.Confidence(npc) return math.max(0,math.min(100,math.floor(50+B.EffectiveTrust(npc)*5))) end
function B.Willing(npc) return true end -- Cooperation is tested by the die, never by the previous familiarity gate.
function D.Difficulty(npc)
    if B.saved.speechcraftEnabled==false or B.saved.trustEnabled==false then return 12,50 end
    local confidence=B.Confidence(npc)
    local penalty=B.CrimePenalty(npc)
    if penalty<=-9 then return 20,confidence end
    return confidence<20 and 18 or confidence<40 and 15 or confidence<60 and 12 or confidence<80 and 9 or 6,confidence
end
function B.Attitude(npc)
    local dd,c=D.Difficulty(npc)
    local state=c<20 and 'Méfiant' or c<40 and 'Réservé' or c<60 and 'Neutre' or c<80 and 'Bienveillant' or 'Confiant'
    local penalty,label=B.CrimePenalty(npc)
    return string.format('Confiance : %d/100 · %s · DD %d',c,state,dd)..(penalty<0 and (' · '..label) or '')
end
function D.Tasks(index)
    local q=B.ReadQuest(index)
    if not q then return {} end
    local _,_,active,_,activeOverride=GetJournalQuestInfo(index)
    local result={}
    local function add(step,condition,text,task)
        local key=q.key..':'..tostring(B.Hash(norm(text)..'\n'..norm(active)..'\n'..norm(task)))
        result[#result+1]={key=key,questKey=q.key,index=index,step=step,condition=condition,text=task,stepText=text or '',quest=q}
    end
    for step=1,GetJournalQuestNumSteps(index) do
        local text,visibility,_,tracker,count=GetJournalQuestStepInfo(index,step)
        if visibility~=QUEST_STEP_VISIBILITY_HIDDEN then
            local before=#result
            local sawVisible=false
            for condition=1,count or 0 do
                local task,current,maximum,fail,done,_,visible=GetJournalQuestConditionInfo(index,step,condition,false)
                if visible then sawVisible=true end
                local fulfilled=done or (type(current)=='number' and type(maximum)=='number' and maximum>0 and current>=maximum)
                if visible and not fail and not fulfilled and type(task)=='string' and task~='' then add(step,condition,text,task) end
            end
            local override=type(tracker)=='string' and tracker~='' and tracker or step==1 and activeOverride or nil
            if #result==before and not sawVisible and type(override)=='string' and override~='' then
                -- Immersive Quests uses the nil-condition read for the visible tracker override too.
                local ok,task,current,maximum,fail,done,_,visible=pcall(GetJournalQuestConditionInfo,index,step,nil,false)
                local fulfilled=done or (type(current)=='number' and type(maximum)=='number' and maximum>0 and current>=maximum)
                if not ok or (not fail and not fulfilled and visible~=false) then
                    add(step,1,text,ok and type(task)=='string' and task~='' and task or override)
                end
            end
        end
    end
    if #result==0 and q.complete and type(GetJournalQuestEnding)=='function' then
        local goal,_,_,_,_,description=GetJournalQuestEnding(index)
        if type(goal)=='string' and goal~='' then add(QUEST_MAIN_STEP_INDEX or 1,1,description,goal) end
    end
    return result
end

function D.Fresh(task)
    if not task then return end
    for _,current in ipairs(D.Tasks(task.index)) do
        if current.key==task.key and norm(current.text)==norm(task.text) and norm(current.stepText)==norm(task.stepText) then return current end
    end
end
function D.Region(index)
    if not index or index<=0 then return end
    local atlas=B.KnowledgeAtlas()
    if atlas.regions[index] then return atlas.regions[index] end
    local id=type(GetZoneId)=='function' and GetZoneId(index) or nil
    local seen={}
    for _=1,8 do
        if not id or id==0 or seen[id] then break end
        seen[id]=true
        local parent=type(GetZoneStoryZoneIdForZoneId)=='function' and GetZoneStoryZoneIdForZoneId(id) or 0
        local actual=parent and parent>0 and parent or id
        local idx=type(GetZoneIndex)=='function' and GetZoneIndex(actual) or nil
        if idx and atlas.regions[idx] then return atlas.regions[idx] end
        id=type(GetParentZoneId)=='function' and GetParentZoneId(id) or nil
    end
end
-- Read the map of this exact visible condition, then immediately restore the player's map.
function D.Metadata(task)
    local saved=D.Saved()
    local previous=saved.targets[task.key]
    if previous and GetTimeStamp()-previous.time<120 then return previous end
    if type(SetMapToQuestCondition)~='function' or type(GetCurrentMapId)~='function' then return previous end
    if ZO_WorldMap and not ZO_WorldMap:IsHidden() then return previous end
    if type(DoesJournalQuestConditionHavePosition)=='function' and not DoesJournalQuestConditionHavePosition(task.index,task.step,task.condition) then return end
    local ok,data=pcall(function()
        local result=SetMapToQuestCondition(task.index,task.step,task.condition)
        if result==SET_MAP_RESULT_FAILED then return end
        local index=type(GetCurrentMapZoneIndex)=='function' and GetCurrentMapZoneIndex() or nil
        local region=D.Region(index)
        if not region then return end
        return {time=GetTimeStamp(),mapId=GetCurrentMapId(),mapName=B.Name(GetMapName()),zoneIndex=index,region=region.name,regionIndex=region.zoneIndex,source='Client FR : carte de la condition actuelle'}
    end)
    SetMapToPlayerLocation()
    if ok and data then saved.targets[task.key]=data;return data end
    return previous
end
function D.RequestPosition(task)
    if not EVENT_QUEST_POSITION_REQUEST_COMPLETE or type(RequestJournalQuestConditionAssistance)~='function' or type(GetCurrentMapId)~='function' then return end
    if type(DoesJournalQuestConditionHavePosition)=='function' and not DoesJournalQuestConditionHavePosition(task.index,task.step,task.condition) then return end
    SetMapToPlayerLocation()
    local map=GetCurrentMapId()
    local key=task.key..':'..tostring(map)..':progress:'..tostring(B.Hash(norm(task.text)))
    if D.requested[key] and GetTimeStamp()-D.requested[key]<10 then return end
    D.requested[key]=GetTimeStamp()
    for id,entry in pairs(D.pending) do if GetTimeStamp()-entry.time>15 then D.pending[id]=nil end end
    -- MiniMap keeps an original reference; use it without asking MiniMap to draw a new pin.
    local request=type(FyrMM)=='table' and FyrMM.RequestJournalQuestConditionAssistance or RequestJournalQuestConditionAssistance
    local id=request(task.index,task.step,task.condition,false)
    if id then D.pending[id]={task=task,mapId=map,zoneIndex=type(GetCurrentMapZoneIndex)=='function' and GetCurrentMapZoneIndex() or GetUnitZoneIndex('player'),time=GetTimeStamp()} end
end
if EVENT_QUEST_POSITION_REQUEST_COMPLETE then
    EVENT_MANAGER:RegisterForEvent('IHRDicePosition',EVENT_QUEST_POSITION_REQUEST_COMPLETE,function(_,id,_,x,y,radius,inside,breadcrumb,teleportNPCId,waypointId)
        local request=D.pending[id];D.pending[id]=nil
        if not request or GetTimeStamp()-request.time>15 or not inside or not validPoint(x,y) then return end
        if GetCurrentMapId()~=request.mapId or not D.Fresh(request.task) then return end
        D.positions[request.task.key]={taskText=request.task.text,x=x,y=y,radius=tonumber(radius) or 0,mapId=request.mapId,zoneIndex=request.zoneIndex,time=GetTimeStamp(),breadcrumb=not not breadcrumb,teleportNPCId=teleportNPCId,waypointId=waypointId,source=breadcrumb and 'Client FR : prochain passage vers la condition actuelle' or 'Client FR : position de la condition actuelle'}
        if D.OnPosition then D.OnPosition(request.task) end
    end)
end
function D.GeographicDirections(text)
    local value=' '..norm(text)..' '
    for _,direction in ipairs({'nord','sud','est','ouest'}) do
        for _,prefix in ipairs({'au ','a l ','vers le ','vers l ','plein ','direction du ','direction de l ','cote ','partie ','flanc '}) do
            if value:find(' '..prefix..direction..' ',1,true) then return true end
        end
    end
    return false
end
function D.HasDirections(text)
    if D.GeographicDirections(text) then return true end
    local value=' '..norm(text)..' '
    for _,word in ipairs({'derriere','devant','a cote','tout pres','au fond'}) do if value:find(' '..word..' ',1,true) then return true end end
    return false
end
function D.Known(task,family)
    local record=D.Saved().hints[task.key..':'..(family or 'goal')]
    local known=record and record.level or 0
    if family and family~='goal' then return known end
    for _,source in ipairs(task.quest.sources) do
        if source.providedHint and norm(source.objective)==norm(task.text) then
            if D.HasDirections(source.text) then known=math.max(known,2)
            else
                local n=' '..norm(source.text)..' '
                local atlas=B.KnowledgeAtlas()
                for _,place in pairs(atlas.public) do
                    if n:find(' '..norm(place.name)..' ',1,true) then known=math.max(known,place.entityType=='region' and 1 or 2) end
                end
                for _,place in pairs(atlas.sites) do if n:find(' '..norm(place.name)..' ',1,true) then known=math.max(known,2) end end
            end
        end
    end
    local target=bare(task.text:match('^%S+%s+(.+)$') or '')
    if #target>=5 then
        local atlas=B.KnowledgeAtlas()
        for _,source in ipairs(task.quest.sources) do
            if not source.providedHint and source.kind~='Objectif accompli' then
                for sentence in source.text:gmatch('[^.!?\n]+') do
                    local text=' '..norm(sentence)..' '
                    if text:find(target,1,true) then
                        if D.HasDirections(sentence) then known=math.max(known,2) end
                        for _,place in pairs(atlas.public) do
                            if text:find(' '..norm(place.name)..' ',1,true) then known=math.max(known,place.entityType=='region' and 1 or 2) end
                        end
                        for _,place in pairs(atlas.sites) do if text:find(' '..norm(place.name)..' ',1,true) then known=math.max(known,2) end end
                    end
                end
            end
        end
    end
    return known
end
local function nearestLandmark(position)
    local best,distance
    for i=1,GetNumPOIs(position.zoneIndex) do
        local x,y,_,_,shown=GetPOIMapInfo(position.zoneIndex,i)
        if shown and validPoint(x,y) then
            local d=(position.x-x)^2+(position.y-y)^2
            if not distance or d<distance then best={name=B.Name(GetPOIInfo(position.zoneIndex,i)),x=x,y=y};distance=d end
        end
    end
    -- Never present a distant landmark as the camp/building containing the target.
    if distance and distance<.0016 then return best end
end
-- LibGPS provides a map measurement, not a guessed conversion from a fraction
-- of a province. It is optional: unknown distances stay unqualified.
function D.DistanceMetersFR(x,y,tx,ty)
    local gps=LibGPS3
    if not gps or type(gps.GetLocalDistanceInMeters)~='function' then return end
    if type(gps.IsMeasuring)=='function' and gps:IsMeasuring() then return end
    local ok,meters=pcall(gps.GetLocalDistanceInMeters,gps,x,y,tx,ty)
    if ok and type(meters)=='number' and meters==meters and meters>0 and meters<math.huge then return meters end
end
function D.GoalSubject(task)
    local meta=D.Metadata(task)
    D.RequestPosition(task)
    local p=D.positions[task.key]
    local here=D.Region(GetUnitZoneIndex('player'))
    local subject={kind='goal',task=task,key=task.key..':goal',family='goal',title=task.quest.name,level=0}
    subject.question='Pouvez-vous me guider pour « '..task.text..' » ?'
    local person=task.text:match('^[Tt]rouvez%s+(.+)$') or task.text:match('^[Pp]arlez%s+à%s+(.+)$') or (task.text:match('^[Pp]arlez%s+au%s+(.+)$') and ('le '..task.text:match('^[Pp]arlez%s+au%s+(.+)$')))
    if person then
        subject.question=B.Here(person) and 'Pouvez-vous m’aider à trouver ce qu’il me reste à faire ici ?' or ('Savez-vous où je pourrais trouver '..person..' ?')
    end
    if p and norm(p.taskText)==norm(task.text) and type(GetCurrentMapId)=='function' and p.mapId==GetCurrentMapId() and GetTimeStamp()-p.time<20 then
        local x,y=GetMapPlayerPosition('player')
        if validPoint(x,y) then
            subject.nativePosition=true
            subject.nativeBreadcrumb=p.breadcrumb
            local dx,dy=p.x-x,p.y-y
            local distance=math.sqrt(dx*dx+dy*dy)
            local bearing=B.Bearing(dx,dy)
            subject.nativeBearing=bearing;subject.nativeNear=distance<.003;subject.nativeRadius=p.radius
            subject.nativeDistanceMeters=D.DistanceMetersFR(x,y,p.x,p.y)
            if subject.nativeDistanceMeters then subject.nativeNear=subject.nativeDistanceMeters<=12 end
            local voice=B.RouteVoice
            local wording={bearing=bearing,near=subject.nativeNear,distanceMeters=subject.nativeDistanceMeters,
                targetKey=task.key,npc=B.npc}
            subject.level=distance<.025 and p.radius<=0 and 3 or 2
            if p.breadcrumb then
                -- A breadcrumb is the next doorway/transition, not the actor or
                -- object behind it. Never describe it as the exact final goal.
                subject.level=2
                -- The bearing leads to an entrance, never an invented road or
                -- a claim that the actor is standing at the transition pin.
                wording.includeDistance=false
                subject.answer=voice and voice.Format('entrance',wording) or ('L’accès se trouve '..bearing..' d’ici.')
                if subject.nativeNear then subject.answer=subject.answer..' L’entrée est tout près.' end
            elseif subject.level==3 then
                subject.answer=voice and voice.Format(subject.nativeNear and 'near' or 'direction',wording)
                    or (subject.nativeNear and 'C’est juste ici. Regardez autour de vous.' or ('C’est '..bearing..' d’ici.'))
            elseif p.radius>0 then subject.answer=voice and voice.Format('area',wording) or ('Cherchez '..bearing..' d’ici, dans les environs.')
            else
                local landmark=nearestLandmark(p)
                subject.answer=voice and voice.Format('direction',wording) or ('C’est '..bearing..' d’ici.')
                if landmark then subject.answer=subject.answer..' Vous pouvez vous repérer avec « '..landmark.name..' ».' end
            end
            subject.routeVoiced=not not voice
            subject.source=p.source
        end
    end
    if subject.level==0 and meta then
        subject.level=1;subject.source=meta.source
        subject.answer='Cette piste vous mène dans la région « '..meta.region..' ».'
        if here and here.zoneIndex==meta.regionIndex and bare(meta.mapName)~=bare(meta.region) and bare(meta.mapName)~='tamriel' then
            subject.level=2;subject.answer=B.RouteVoice and B.RouteVoice.Format('destination',{destination=meta.mapName,targetKey=task.key})
                or ('Cherchez du côté '..D.OfPlace(meta.mapName)..'.')
            subject.routeVoiced=not not B.RouteVoice
        end
    end
    if subject.level==0 or subject.level<=D.Known(task,'goal') then return end
    return subject
end
function D.PlaceSubject(place,task)
    local public=B.PublicPlace(place.name)
    if not public then return end
    local family='place:'..bare(place.name)
    local subject={kind='place',key=(task and task.key or 'geography')..':'..family,family=family,task=task,place=place,level=1,title=place.name,source='Client FR : atlas géographique'}
    subject.question=public.entityType=='region' and (place.name..', c’est où exactement ?') or ('Comment rejoindre '..place.name..' ?')
    if public.entityType=='region' then
        if public.description=='' and not public.situation then return end
        subject.answer=(public.situation and (public.name..' se situe '..public.situation..'. ') or '')..public.description
    else
        subject.answer=public.name..' se trouve dans la région « '..public.region..' ».'
        if public.zoneIndex==GetUnitZoneIndex('player') then
            SetMapToPlayerLocation()
            local px,py=GetMapPlayerPosition('player')
            local tx,ty,_,_,shown=GetPOIMapInfo(public.zoneIndex,public.poiIndex)
            if shown and validPoint(px,py) and validPoint(tx,ty) then
                subject.level=2;subject.answer=subject.answer..' D’ici, dirigez-vous '..B.Bearing(tx-px,ty-py)..'.'
            end
        end
    end
    if task and subject.level<=D.Known(task,family) then return end
    return subject
end
function D.Subjects(index)
    local subjects,tasks={},D.Tasks(index)
    for _,task in ipairs(tasks) do local subject=D.GoalSubject(task);if subject then subjects[#subjects+1]=subject end end
    local q=B.ReadQuest(index)
    if not q then return subjects end
    local seen={}
    for _,place in ipairs(B.MatchPlaces(q)) do
        local task
        for _,candidate in ipairs(tasks) do if (place.objective and norm(place.objective)==norm(candidate.text)) or (place.kind=='Objectif actuel' and norm(place.source)==norm(candidate.text)) then task=candidate end end
        if place.entityType=='alliance' then
            subjects[#subjects+1]={kind='topic',key=q.key..':topic:'..place.normal,question=place.topic.question,title=place.name,answer=place.topic.answer,level=1,source='Base de contexte politique vérifiée'}
        elseif place.entityType=='region' or place.entityType=='city' then
            -- An authored direction is already visible: do not sell it back as an NPC hint.
            if task and not D.HasDirections(place.source) and not seen[bare(place.name)] then
                local subject=D.PlaceSubject(place,task)
                if subject then subjects[#subjects+1]=subject;seen[bare(place.name)]=true end
            end
        end
    end
    return subjects
end
function D.RefreshSubject(subject)
    if subject.task then
        local task=D.Fresh(subject.task)
        if not task then return end
        if subject.kind=='goal' then return D.GoalSubject(task) end
        if subject.kind=='place' then return D.PlaceSubject(subject.place,task) end
    end
    return subject
end
function D.Roll(subject,npc)
    if not subject or (not subject.unresolved and (not subject.answer or subject.answer=='')) then return nil,'Aucun renseignement supplémentaire vérifié.' end
    if subject.task and not D.Fresh(subject.task) then return nil,'Cet objectif a changé. Relisez votre journal.' end
    local dd,confidence=D.Difficulty(npc)
    local baseDD=dd
    local depth=subject.task and math.max(1,math.floor(tonumber(subject.inquiryDepth) or 1)) or 1
    local bonus=(depth-1)*3
    dd=baseDD+bonus
    local key=(B.RelationKey(npc) or B.Profile(npc).key)..':'..subject.key..':'..subject.level
    local saved=D.Saved()
    local previous=saved.rolls[key]
    if previous and (previous.success or (GetTimeStamp()-previous.time<600 and confidence<previous.confidence+12)) then
        if previous.success and subject.kind=='service' then local copy={};for k,v in pairs(previous) do copy[k]=v end;copy.answer=subject.answer;return copy,nil,true end
        previous.inquiryDepth=previous.inquiryDepth or depth;previous.baseDD=previous.baseDD or baseDD;previous.inquiryBonus=previous.inquiryBonus or bonus
        return previous,nil,true
    end
    local face=math.random(1,20)
    local result={die=face,dd=dd,confidence=confidence,success=(face==20 or face>=dd),inquiryDepth=depth,baseDD=baseDD,inquiryBonus=bonus,time=GetTimeStamp(),npc=npc.name,locality=npc.locality,answer=subject.answer,knowledgeUnavailable=not not subject.unresolved,level=subject.level,source=subject.source}
    saved.rolls[key]=result
    local count=0;for _ in pairs(saved.rolls) do count=count+1 end
    if count>400 then local oldest,oldestTime;for k,r in pairs(saved.rolls) do if k~=key and (not oldestTime or r.time<oldestTime) then oldest=k;oldestTime=r.time end end;if oldest then saved.rolls[oldest]=nil end end
    return result
end
function D.Reveal(subject,result)
    if not result or not result.success or result.knowledgeUnavailable or subject.unresolved then return false end
    if subject.task then
        local task=D.Fresh(subject.task)
        if not task then return false end
        local existing=D.Saved().hints[subject.key]
        if not existing or existing.level<result.level then
            D.Saved().hints[subject.key]={taskKey=task.key,questKey=task.questKey,stepText=task.stepText,taskText=task.text,text=result.answer,npc=result.npc,locality=result.locality,level=result.level,time=GetTimeStamp(),source=result.source}
            B.Remember({name=task.text,quest=task.quest},result.answer,result.npc)
        end
    end
    return true
end
function B.GetAcquiredQuestHint(index,stepText,conditionText)
    if not B.saved or not B.saved.enabled then return '' end
    local matching
    for _,task in ipairs(D.Tasks(index)) do
        if norm(task.stepText)==norm(stepText) and norm(task.text)==norm(conditionText) then matching=task;break end
    end
    if not matching then return '' end
    local entries={}
    for _,hint in pairs(D.Saved().hints) do
        if hint.taskKey==matching.key and norm(hint.stepText)==norm(stepText) and norm(hint.taskText)==norm(conditionText) then entries[#entries+1]=hint end
    end
    table.sort(entries,function(a,b) return a.level>b.level or a.level==b.level and a.time>b.time end)
    local lines={};for i=1,math.min(3,#entries) do lines[#lines+1]='\nRenseignement de '..entries[i].npc..(entries[i].locality and (' — '..entries[i].locality) or '')..' : '..entries[i].text end
    return table.concat(lines)
end
if EVENT_QUEST_REMOVED then
    EVENT_MANAGER:RegisterForEvent('IHRDiceQuestRemoved',EVENT_QUEST_REMOVED,function(_,_,_,name,zoneIndex)
        if not B.saved or not name then return end
        local key=B.QuestKey(name,zoneIndex)
        for k,h in pairs(D.Saved().hints) do if h.questKey==key then D.Saved().hints[k]=nil end end
        for k in pairs(D.Saved().targets) do if k:sub(1,#key+1)==key..':' then D.Saved().targets[k]=nil end end
    end)
end
