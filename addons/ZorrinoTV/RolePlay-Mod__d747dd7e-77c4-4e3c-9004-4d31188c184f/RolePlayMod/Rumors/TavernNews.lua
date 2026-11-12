if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- One lead at a time. Wilderness starters stay for exploration.
local B=IHR_Runtime.Beta
local D=B.Dice
function B.IsPublican(npc)
    if B.IsInnkeeper(npc) then return true end
    local role=B.Normalize(npc and npc.caption or '')
    return role:find('brasseur',1,true)~=nil or role:find('brasseuse',1,true)~=nil or role:find('brewer',1,true)~=nil
end
local hospitality=B.HospitalityContext
function B.HospitalityContext(npc)
    if B.IsPublican(npc) then return true,'auberge ou brasserie' end
    return hospitality(npc)
end
local function norm(s) return B.Normalize(s or '') end
local function choice(text,callback) return {text=text,callback=callback} end
function B.UrbanRumor(r)
    if not r or r.object or not r.giver or norm(r.giver)=='une personne dans les environs' or not r.anchor or not r.mapKey then return false end
    local giver=' '..norm(r.giver)..' '
    for _,role in ipairs({'heraut des','heraut de','messager inconnu','une personne'}) do
        if norm(r.giver):find(role,1,true)==1 then return false end
    end
    -- Historical map copies of these starts do not establish a current urban giver.
    if r.quest==4339 then return false end -- Tandarë: outside Scinderacine.
    if r.quest==3918 and (r.mapKey or ''):find('eldenroot',1,true) then return false end

    for _,word in ipairs({'affiche','lettre','panneau','cadavre','journal','note','notice','livre','parchemin','advertisement','letter','book','corpse','scroll','poster'}) do
        if giver:find(' '..word..' ',1,true) then return false end
    end
    local locations=IHR_TavernRumorLocations
    if not locations then return false end
    local rows=locations.starts[r.mapKey]
    local key=string.format('%d:%.5f:%.5f',r.quest,r.anchor.x,r.anchor.y)
    -- Locally discovered starts on an actual city map can extend the catalogue.
    return not not ((rows and rows[key]) or (locations.cityMaps[r.mapKey] and B.rumorDiscoveries and B.rumorDiscoveries.starts[r.mapKey] and B.rumorDiscoveries.starts[r.mapKey][r.quest]))
end
local function standardQuest(r)
    local meta=IHR_QuestRumorDB and IHR_QuestRumorDB.meta[r.quest]
    -- LibQuestData indices: quest type 1, repeatability 2. Unknown repeatability is excluded.
    if not meta or tonumber(meta[2])~=0 then return false end
    if QUEST_TYPE_UNDAUNTED_PLEDGE and tonumber(meta[1])==QUEST_TYPE_UNDAUNTED_PLEDGE then return false end
    return true
end
local function refusalKey(npc,r)
    return (B.RelationKey(npc) or B.Profile(npc).key)..':rumor:'..r.quest
end
function B.MarkRumorRefusal(r,result)
    if not r or not B.npc then return end
    B.saved.tavernRefusals135=B.saved.tavernRefusals135 or {}
    B.saved.tavernRefusals135[refusalKey(B.npc,r)]={time=GetTimeStamp(),confidence=result.confidence or B.Confidence(B.npc)}
end
local function compact(name) return norm(name):gsub('[^a-z0-9]','') end
function B.TavernTown(npc)
    local data=IHR_TavernRumorLocations
    if not data then return end
    local map=B.MapKey() or ''
    local family=(data.familyByMap or {})[map]
    local towns=data.towns or {}
    if not family then
        local base=compact((map:match('([^/]+)$') or ''):gsub('^u%d+_',''))
        for key in pairs(towns) do if base:sub(1,#key)==key and (not family or #key>#family) then family=key end end
    end
    if not family then
        local names={npc and npc.locality or ''}
        for _,fn in ipairs({GetPlayerLocationName or false,GetPlayerActiveSubzoneName or false}) do if type(fn)=='function' then names[#names+1]=fn() end end
        for key,aliases in pairs(towns) do
            for _,alias in ipairs(aliases) do
                for _,name in ipairs(names) do if norm(name)==norm(alias) then family=key end end
            end
        end
    end
    local aliases=family and towns[family]
    return family,aliases and B.Name(aliases[2] or aliases[1]) or nil
end
local function eligibleHere(id)
    -- Logical eligibility is checked in the tavern's context. The starter keeps
    -- its own mapKey, and its coordinates are never compared across floors.
    return B.RumorEligible({quest=id,mapKey=B.MapKey()})
end
local function specificity(map,current)
    local score=map==current and 1 or 0
    for _,part in ipairs({'magesguild','fightersguild','throneroom','outlaw','crafting','services'}) do
        if map:find(part,1,true) then score=score+10 end
    end
    return score
end
function B.TownRumorCandidates(npc)
    SetMapToPlayerLocation()
    local family,town=B.TavernTown(npc)
    local locations=IHR_TavernRumorLocations
    local db=IHR_QuestRumorDB
    if not family or not locations or not locations.familyByMap or not db then return B.UnstartedRumors() end
    local current=B.MapKey()
    local result,byId,eligibility={},{},{}
    for map,mapFamily in pairs(locations.familyByMap) do
        if mapFamily==family then
            for _,row in ipairs(db.maps[map] or {}) do
                local id=tonumber(row[3]);local name=db.givers[tonumber(row[4])]
                if id and type(name)=='string' and name~='' and standardQuest({quest=id}) then
                    local candidate={quest=id,mapKey=map,giver=B.Name(name),object=not not db.objects[id],town=town,townFamily=family,
                        anchor={x=row[1],y=row[2],name=B.Name(name)}}
                    candidate.title='Une piste : '..candidate.giver
                    if id==5531 then
                        -- Official ESO support: Partners in Crime starts with Quen in any Outlaws Refuge.
                        candidate.verifiedText='Quen cherche un partenaire pour une affaire qui demande de la discrétion. Vous la trouverez dans le refuge de hors-la-loi de '..town..'. C’est à elle qu’il faut parler.'
                        candidate.evidence='https://help.elderscrollsonline.com/app/answers/detail/a_id/32372/'
                    end
                    candidate.text='Il paraît que '..candidate.giver..' cherchait un coup de main. Vous pourriez aller voir si votre aide serait utile.'
                    if eligibility[id]==nil then eligibility[id]=eligibleHere(id) end
                    local old=byId[id]
                    if eligibility[id] and B.UrbanRumor(candidate) and (not old or specificity(map,current)>specificity(old.mapKey,current) or (specificity(map,current)==specificity(old.mapKey,current) and map<old.mapKey)) then byId[id]=candidate end
                end
            end
        end
    end
    -- Preserve an existing documented premise when it is on the current map.
    for _,r in ipairs(B.UnstartedRumors()) do
        if (locations.familyByMap[r.mapKey]==family) and B.UrbanRumor(r) then
            r.town=town;r.townFamily=family
            if not byId[r.quest] or specificity(r.mapKey,current)>specificity(byId[r.quest].mapKey,current) then byId[r.quest]=r end
        end
    end
    for _,r in pairs(byId) do result[#result+1]=r end
    return result
end
local session
function B.ResetTavernRumors(silent)
    if not B.saved then return end
    session=nil
    B.saved.rumorsHeard={};B.saved.tavernRefusals135={};B.saved.tavernLastCheck136=nil
    B.saved.tavernReplay139=true
    if not silent and type(d)=='function' then d('Rumeurs réinitialisées. Reprenez la conversation avec un aubergiste ou un brasseur. Votre carnet et vos quêtes sont conservés.') end
end
if SLASH_COMMANDS then SLASH_COMMANDS['/ihrrumeurs']=function() B.ResetTavernRumors(false);if B.npc and B.IsPublican(B.npc) then B.ShowQuestRumors() end end end
local function innSession(npc)
    if not session or session.npc~=npc then session={npc=npc,seen={},givers={}} end
    return session
end
local close=B.Close
function B.Close(...) session=nil;return close(...) end
function B.KnownRumors(npc)
    if B.saved and not B.saved.tavernReplay139 then B.ResetTavernRumors(true) end
    if not B.HospitalityContext(npc) or not B.Willing(npc) then return {} end
    local profile=B.Profile(npc)
    local innkeeper=B.IsPublican(npc)
    local role=norm(npc.caption)
    local staff=role:find('brasseur',1,true) or role:find('chef',1,true) or role:find('cuisin',1,true)
    local chance=innkeeper and 100 or staff and 55 or 30
    local candidates={}
    for _,r in ipairs(B.TownRumorCandidates(npc)) do
        if B.UrbanRumor(r) and standardQuest(r) and (not B.TravelJournal or not B.TravelJournal.Has(r.quest)) and (not B.ReliableTavernLead or B.ReliableTavernLead(r)) then
            local hash=B.Hash(profile.key..':rumeur:'..r.quest)
            if innkeeper or hash%100<chance then candidates[#candidates+1]={rumor=r,order=hash} end
        end
    end
    table.sort(candidates,function(a,b) return a.order<b.order or a.order==b.order and a.rumor.quest<b.rumor.quest end)
    local pool,givers,quests={},{},{}
    for _,candidate in ipairs(candidates) do
        local r=candidate.rumor;local giver=norm(r.giver)
        if not givers[giver] and not quests[r.quest] then
            pool[#pool+1]=r;givers[giver]=true;quests[r.quest]=true
            if not innkeeper and #pool>=2 then break end
        end
    end
    local result={}
    local heard,coolingCount=0,0
    for _,r in ipairs(pool) do
        local refusal=(not (RolePlayMod.Speechcraft and RolePlayMod.Speechcraft.Enabled()) and B.saved.tavernRefusals135 or {})[refusalKey(npc,r)]
        local cooling=refusal and GetTimeStamp()-refusal.time<600 and B.Confidence(npc)<refusal.confidence+12
        local conversation=innkeeper and innSession(npc)
        local wasHeard=conversation and (conversation.seen[r.quest] or conversation.givers[norm(r.giver)]) or (not innkeeper and (B.saved.rumorsHeard or {})[r.quest])
        if wasHeard then heard=heard+1
        elseif not innkeeper and cooling then coolingCount=coolingCount+1
        else result[#result+1]=r end
    end
    B.saved.tavernLastCheck136={map=B.MapKey(),town=select(2,B.TavernTown(npc)),eligible=#pool,heard=heard,cooling=coolingCount,available=#result}
    return result
end
local function valid(x,y)
    return type(x)=='number' and type(y)=='number' and x>0 and x<1 and y>0 and y<1
end
local function mapCue(r)
    local map=r.mapKey or ''
    if map:find('magesguild',1,true) then return 'à la guilde des Mages' end
    if map:find('fightersguild',1,true) then return 'à la guilde des Guerriers' end
    if map:find('throneroom',1,true) then return 'dans la salle du trône' end
    if map:find('outlaw',1,true) then return 'dans le refuge de hors-la-loi' end
    if map:find('eldenrootgroundfloor',1,true) then return 'au niveau inférieur de Faneracine' end
    if map:find('eldenrootcrafting',1,true) then return 'près des ateliers de Faneracine' end
    if map:find('eldenrootservices',1,true) then return 'dans le quartier des services de Faneracine' end
    return r.town and ('à '..r.town) or nil
end
function B.PreciseInnRumor(r)
    if r.verifiedText then return r.verifiedText end
    SetMapToPlayerLocation()
    local text=r.text
    local cue=mapCue(r)
    if cue then text=text..' Cherchez '..r.giver..' '..cue..'.' end
    local px,py=GetMapPlayerPosition('player')
    local sameMap=r.mapKey==B.MapKey()
    if sameMap and valid(px,py) and r.anchor then
        local dx,dy=r.anchor.x-px,r.anchor.y-py
        if dx*dx+dy*dy<.000064 then text=text..' C’est tout près, regardez autour de vous.'
        else text=text..' D’ici, dirigez-vous '..B.Bearing(dx,dy)..'.' end
        -- An innkeeper supplies all available landmark information, regardless of trust.
        local best,nearest
        for _,landmark in ipairs(B.PublicRumorLandmarks()) do
            local d=(r.anchor.x-landmark.x)^2+(r.anchor.y-landmark.y)^2
            if d<.01 and (not best or d<best) then best=d;nearest=landmark end
        end
        if nearest then
            if best<.000064 then text=text..' Cherchez près de '..nearest.name..'.'
            else text=text..' Pour vous repérer, cherchez '..B.Bearing(r.anchor.x-nearest.x,r.anchor.y-nearest.y)..' de '..nearest.name..'.' end
        end
    elseif not sameMap and r.anchor then
        local positions=IHR_TavernRumorLocations and IHR_TavernRumorLocations.globalPositions
        local key=string.format('%d:%.5f:%.5f',r.quest,r.anchor.x,r.anchor.y)
        local point=positions and positions[r.mapKey] and positions[r.mapKey][key]
        local gps=LibGPS3
        if point and gps and type(gps.LocalToGlobal)=='function' and valid(px,py) then
            local ok,gx,gy=pcall(gps.LocalToGlobal,gps,px,py)
            if ok and valid(gx,gy) and valid(point[1],point[2]) then
                local dx,dy=point[1]-gx,point[2]-gy
                -- Shared global projection, not an invalid subtraction between floor maps.
                -- A vertically aligned destination is described by its building/floor instead.
                if dx*dx+dy*dy>1e-10 then text=text..' D’ici, c’est '..B.Bearing(dx,dy)..'.' end
                local nearest,best,nx,ny
                for _,landmark in ipairs(B.PublicRumorLandmarks()) do
                    local converted,lx,ly=pcall(gps.LocalToGlobal,gps,landmark.x,landmark.y)
                    if converted and valid(lx,ly) then
                        local distance=(point[1]-lx)^2+(point[2]-ly)^2
                        if distance<.00000225 and (not best or distance<best) then nearest=landmark;best=distance;nx=lx;ny=ly end
                    end
                end
                if nearest then
                    if best<1e-10 then text=text..' Cherchez près de '..nearest.name..'.'
                    else text=text..' Pour vous repérer, c’est '..B.Bearing(point[1]-nx,point[2]-ny)..' de '..nearest.name..'.' end
                end
            end
        end
    end
    return text
end
local hear=B.HearRumor
function B.HearRumor(r)
    if B.npc and B.IsPublican(B.npc) then
        for _,known in ipairs(B.KnownRumors(B.npc)) do
            if known.quest==r.quest and known.mapKey==r.mapKey and eligibleHere(r.quest) then
                local text=B.PreciseInnRumor(known)
                local conversation=innSession(B.npc)
                conversation.seen[r.quest]=true;conversation.givers[norm(r.giver)]=true
                B.saved.rumorsHeard=B.saved.rumorsHeard or {};B.saved.rumorsHeard[r.quest]=GetTimeStamp()
                return text
            end
        end
        return
    end
    if r.mapKey==B.MapKey() then return hear(r) end
    if not B.npc or not B.HospitalityContext(B.npc) or not B.Willing(B.npc) then return end
    for _,known in ipairs(B.KnownRumors(B.npc)) do
        if known.quest==r.quest and known.mapKey==r.mapKey and eligibleHere(r.quest) then
            B.saved.rumorsHeard=B.saved.rumorsHeard or {};B.saved.rumorsHeard[r.quest]=GetTimeStamp()
            -- A different floor has a different coordinate frame. Give the
            -- verified town and giver, without inventing a compass direction.
            return r.text..(r.town and (' Cherchez '..r.giver..' à '..r.town..'.') or '')
        end
    end
end
function B.ShowQuestRumors()
    if not B.npc then return end
    if not B.HospitalityContext(B.npc) then B.ShowHome();return end
    local rumor=B.KnownRumors(B.npc)[1]
    if not rumor then
        local check=B.saved.tavernLastCheck136
        local line=check and check.cooling>0 and B.DialogueLine('refusal') or B.DialogueLine('no_news')
        B.Show('Les nouvelles du pays',line,{
            choice('Merci. Je vous laisse.',function() B.ShowHome() end),
        },false,B.IsPublican(B.npc) and 'Aubergiste' or nil)
        return
    end
    if B.IsPublican(B.npc) then
        local text=B.HearRumor(rumor)
        if not text then B.ShowHome();return end
        text=B.SpokenAnswer({kind='rumor'},text,B.npc)
        B.Remember({name='Une piste : '..rumor.giver,rumorId=rumor.quest},text,B.npc.name)
        local town=select(2,B.TavernTown(B.npc))
        B.Show('Les nouvelles du pays',text,{
            choice('Noter dans mon carnet.',function() if B.TravelJournal then B.TravelJournal.ShowNoted(rumor,text,B.npc) end end),
            choice('Autre chose ?',function() B.ShowQuestRumors() end),
            choice('Merci pour ces renseignements.',function() B.ShowHome() end),
        },false,town and ('Rumeurs de '..town) or 'Aubergiste')
        return
    end
    D.Ask({kind='rumor',key='rumor:'..rumor.quest,title='Une rumeur',question='Avez-vous entendu parler de quelqu’un qui aurait besoin d’aide ?',answer=rumor.text,level=1,source='Départ en agglomération : base de coordonnées vérifiée',rumor=rumor})
end

function B.PublicRumorLandmarks()
    local result={}
    if type(GetNumFastTravelNodes)~='function' then return result end
    for i=1,GetNumFastTravelNodes() do
        local known,name,x,y,icon,_,kind,shown,locked=GetFastTravelNodeInfo(i)
        local wayshrine=(POI_TYPE_WAYSHRINE and kind==POI_TYPE_WAYSHRINE) or tostring(icon):lower():find('wayshrine',1,true)
        if known and shown and not locked and wayshrine and type(x)=='number' and type(y)=='number' and x>0 and x<1 and y>0 and y<1 then
            result[#result+1]={name=B.Name(name),x=x,y=y}
        end
    end
    return result
end
function B.ReliableTavernLead(r)
    if r.verifiedText and r.evidence then return true end
    local cue=mapCue(r)
    if cue and not (cue=='au niveau inférieur de Faneracine' or cue==('à '..(r.town or ''))) then return true end
    if r.mapKey==B.MapKey() and r.anchor then
        for _,p in ipairs(B.PublicRumorLandmarks()) do
            if (p.x-r.anchor.x)^2+(p.y-r.anchor.y)^2<.0025 then return true end
        end
    end
    -- Inn interiors and streets use different map coordinates. Compare only
    -- after projection into the same global reference, just like the answer.
    local gps=LibGPS3
    local positions=IHR_TavernRumorLocations and IHR_TavernRumorLocations.globalPositions
    local key=r.anchor and string.format('%d:%.5f:%.5f',r.quest,r.anchor.x,r.anchor.y)
    local point=key and positions and positions[r.mapKey] and positions[r.mapKey][key]
    if point and gps and type(gps.LocalToGlobal)=='function' then
        for _,p in ipairs(B.PublicRumorLandmarks()) do
            local ok,x,y=pcall(gps.LocalToGlobal,gps,p.x,p.y)
            if ok and valid(x,y) and valid(point[1],point[2]) and (point[1]-x)^2+(point[2]-y)^2<.00000225 then return true end
        end
    end
    return false
end
