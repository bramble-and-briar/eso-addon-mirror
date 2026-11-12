if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Typed, evidence-led questions. No remote text generation and no unrevealed quest steps.
local B=IHR_Runtime.Beta
local oldRead,oldMatch,oldAnswer,oldQuestion=B.ReadQuest,B.MatchPlaces,B.PlaceAnswer,B.PlaceQuestion
local function normal(s) return B.Normalize(s):gsub("^les ",""):gsub("^le ",""):gsub("^la ",""):gsub("^l ","") end
local function mentions(text,name) return (" "..B.Normalize(text).." "):find(" "..B.Normalize(name).." ",1,true)~=nil end
-- Only the client journal and actually recorded speech feed this integrated journal.
-- No authored Immersive Quests localization or saved custom hints are imported.
function B.ReadQuest(index) return oldRead(index) end

local atlas,signature
local function cleanDescription(text)
    text=type(text)=="string" and text or ""
    local first=text:match("^(.-[.!?])%s") or text
    if #first>420 then first=first:sub(1,420):match("^(.*)%s") or "" end
    return first
end
function B.KnowledgeAtlas()
    local maps=type(GetNumMaps)=="function" and GetNumMaps() or 0
    local zones=type(GetNumZones)=="function" and GetNumZones() or 0
    local key=tostring(maps)..":"..tostring(zones)..":"..tostring(GetUnitZoneIndex("player"))
    if atlas and signature==key then return atlas end
    signature=key;atlas={public={},regions={},sites={}}
    local function addRegion(name,index,description)
        if type(name)~="string" or name=="" or not index or index<=0 then return end
        local entry=atlas.public[normal(name)] or {name=B.Name(name),entityType="region",zoneIndex=index,description=""}
        local provided=cleanDescription(description)
        if provided~="" then entry.description=provided end
        if entry.description=="" and type(GetZoneDescription)=="function" then entry.description=cleanDescription(GetZoneDescription(index)) end
        atlas.public[normal(name)]=entry;atlas.regions[index]=entry
        return entry
    end
    if MAPTYPE_ZONE and type(GetMapInfoByIndex)=="function" then
        for i=1,maps do
            local name,kind,_,index,description=GetMapInfoByIndex(i)
            if kind==MAPTYPE_ZONE and index and index>0 then
                local actual=GetZoneNameByIndex(index)
                if normal(actual)==normal(name) then
                    local entry=addRegion(actual,index,description)
                    -- Coordinates are compared only under the same explicit world-map parent.
                    if entry and type(GetMapParentCategories)=="function" and type(GetMapIdByIndex)=="function" and type(GetUniversallyNormalizedMapInfo)=="function" then
                        local parents={GetMapParentCategories(i)}
                        for p=1,#parents,2 do
                            local worldName,worldType
                            if type(parents[p+1])=="number" then worldName,worldType=GetMapInfoByIndex(parents[p+1]) end
                            if worldType==MAPTYPE_WORLD and normal(worldName)=="tamriel" then
                                local x,y,w,h=GetUniversallyNormalizedMapInfo(GetMapIdByIndex(i))
                                local wx,wy,ww,wh=GetUniversallyNormalizedMapInfo(GetMapIdByIndex(parents[p+1]))
                                if type(x)=="number" and type(y)=="number" and type(wx)=="number" and type(wy)=="number" and type(w)=="number" and type(h)=="number" and type(ww)=="number" and type(wh)=="number" and w>0 and h>0 and ww>0 and wh>0 then
                                    local dx,dy=(x+w/2-wx-ww/2)/ww,(y+h/2-wy-wh/2)/wh
                                    entry.situation=(dx*dx+dy*dy<.0064) and "au centre de Tamriel" or (B.Bearing(dx,dy).." de Tamriel")
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if type(GetZoneStoryZoneIdForZoneId)=="function" and type(GetZoneId)=="function" then
        for index=1,zones do
            local id=GetZoneId(index)
            if id and id>0 and GetZoneStoryZoneIdForZoneId(id)==id then addRegion(GetZoneNameByIndex(index),index) end
        end
    end
    -- The current region remains useful when optional atlas APIs are unavailable.
    local here=GetUnitZoneIndex("player")
    if not atlas.regions[here] then addRegion(GetZoneNameByIndex(here),here) end
    local towns={}
    for _,aliases in pairs(IHR_FR and IHR_FR.towns or {}) do for _,alias in ipairs(aliases) do towns[normal(alias)]=true end end
    for index,region in pairs(atlas.regions) do
        for poi=1,GetNumPOIs(index) do
            local name=GetPOIInfo(index,poi)
            if type(name)=="string" and name~="" then
                local entry={name=B.Name(name),entityType="site",zoneIndex=index,poiIndex=poi,region=region.name}
                atlas.sites[normal(name)]=entry
                local icon
                if type(GetPOIMapInfo)=="function" then local _,_,_,path=GetPOIMapInfo(index,poi);icon=type(path)=="string" and path:lower() or "" end
                -- Cities are recognised by official city/town icons or existing verified service settlements.
                if towns[normal(name)] or (icon and (icon:find("poi_city",1,true) or icon:find("poi_town",1,true))) then
                    entry.entityType="city"
                    if not atlas.public[normal(name)] then atlas.public[normal(name)]=entry end
                end
            end
        end
    end
    return atlas
end
function B.PublicPlace(name) return B.KnowledgeAtlas().public[normal(name)] end

local factions={
 {name="Domaine aldmeri",aliases={"domaine aldmeri","aldmeri dominion"},question="Que pouvez-vous me dire du Domaine aldmeri ?",answer="Le Domaine aldmeri réunit les Hauts-Elfes, les Elfes des bois et les Khajiits. Ils combattent sous une même bannière."},
 {name="Pacte de Cœurébène",aliases={"pacte de coeurébène","pacte de coeurebene","pacte de cœurébène","ebonheart pact"},question="Que pouvez-vous me dire du Pacte de Cœurébène ?",answer="Le Pacte de Cœurébène unit des Nordiques, des Elfes noirs et des Argoniens. Une alliance n’efface pas toutes les vieilles rancœurs."},
 {name="Alliance de Daguefilante",aliases={"alliance de daguefilante","daggerfall covenant"},question="Que pouvez-vous me dire de l’Alliance de Daguefilante ?",answer="L’Alliance de Daguefilante rassemble les Brétons, les Rougegardes et les Orques. Ils ont choisi de combattre sous une même bannière."},
}
local generic={domaine=true,aldmeri=true,pacte=true,alliance=true,royaume=true,empire=true,region=true,territoire=true,pays=true,ville=true,village=true,temple=true,foret=true,bois=true,ruines=true,artefact=true,relique=true,coeur=true,manteau=true,chef=true,reine=true,roi=true,conservatrice=true}
local function objectContext(place)
    local text=" "..B.Normalize(place.source).." "
    local _,finish=text:find(" "..B.Normalize(place.name).." ",1,true)
    if finish then
        local tail=text:sub(finish,finish+100)
        if tail:find("^ un .-artefact") or tail:find("^ une .-relique") or tail:find("^ un .-objet") then return true end
    end
    local name=normal(place.name)
    if name=="planetaire" and text:find("artefact",1,true) and not text:find(" au planetaire ",1,true) then return true end
    for _,prefix in ipairs({"recuperez ","recuperer ","retirez ","rapportez ","apportez "}) do
        if text:find(" "..prefix.."le "..name.." ",1,true) or text:find(" "..prefix.."la "..name.." ",1,true) then return true end
    end
    return false
end
local function explicitGeography(place)
    local text=" "..B.Normalize(place.source).." "
    local name=normal(place.name)
    for _,prefix in ipairs({"a ","a la ","a l ","au ","aux ","vers ","vers le ","vers la ","vers les ","vers l ","dans ","dans le ","dans la ","dans les ","dans l ","endroit appele ","endroit nomme ","lieu appele ","lieu nomme ","ville de ","ruines de ","forteresse de ","site de ","site hivernal de "}) do
        if text:find(" "..prefix..name.." ",1,true) then return true end
    end
    return false
end
local people={conservatrice=true,conservateur=true,capitaine=true,mage=true,temoin=true,pretre=true,pretresse=true,roi=true,reine=true,prince=true,princesse=true,ambassadeur=true,ambassadrice=true,commandant=true,commandante=true,marchand=true,marchande=true,forgeron=true,forgeronne=true}
local function personTarget(text)
    local target=text:match("^[Pp]arlez%s+à%s+(.+)$") or text:match("^[Pp]arlez%s+au%s+(.+)$") or text:match("^[Pp]arlez%s+avec%s+(.+)$")
    local find=text:match("^[Tt]rouvez%s+(.+)$")
    if not target and find then
        local role=normal(find):match("^(%S+)")
        if people[role] then target=find end
    end
    if not target then return end
    target=target:gsub("[.!?]+$",""):gsub("%s*:%s*%d+.*$","")
    if target==zo_strlower(target) or target:find("%d") then return end
    return target
end
function B.MatchPlaces(q)
    local result,seen={},{}
    local knowledge=B.KnowledgeAtlas()
    local function add(place)
        local n=normal(place.name)
        if place.providedHint then
            local text=" "..B.Normalize(place.source).." "
            for _,direction in ipairs({"nord","sud","est","ouest","nord est","nord ouest","sud est","sud ouest"}) do
                if text:find(" "..direction.." de "..n.." ",1,true) or text:find(" "..direction.." du "..n.." ",1,true) then return end
            end
        end
        if seen[n] or generic[n] or B.Here(place) then return end
        local public=knowledge.public[n]
        local site=knowledge.sites[n]
        if objectContext(place) then return end
        -- Resolve the entity against the whole visible journal, not each line in isolation.
        for _,evidence in ipairs(q.sources) do
            if objectContext({name=place.name,source=evidence.text}) then return end
        end
        -- An untyped catalogue entry is not sufficient proof of a destination.
        if not public and not site and not explicitGeography(place) then return end
        place.entityType=public and public.entityType or "site"
        place.public=public
        seen[n]=true;result[#result+1]=place
    end
    -- Current objectives and their matched hints precede historical background.
    local ordered={}
    for _,s in ipairs(q.sources) do if s.kind=="Objectif actuel" or s.providedHint then ordered[#ordered+1]=s end end
    for _,s in ipairs(q.sources) do if s.kind~="Objectif actuel" and not s.providedHint and s.kind~="Objectif accompli" then ordered[#ordered+1]=s end end
    for _,source in ipairs(ordered) do
        local scoped={sources={source}}
        for _,place in ipairs(oldMatch(scoped)) do place.quest=q;place.objective=source.objective;place.providedHint=source.providedHint;add(place) end
        for _,entry in pairs(knowledge.public) do
            if mentions(source.text,entry.name) then add({name=entry.name,normal=B.Normalize(entry.name),source=source.text,kind=source.kind,quest=q,objective=source.objective,providedHint=source.providedHint}) end
        end
        for _,topic in ipairs(factions) do
            local matched=false
            for _,alias in ipairs(topic.aliases) do if mentions(source.text,alias) then matched=true end end
            if matched and not seen[topic.name] then
                seen[topic.name]=true;result[#result+1]={name=topic.name,normal=B.Normalize(topic.name),source=source.text,kind=source.kind,quest=q,entityType="alliance",topic=topic}
            end
        end
    end
    for _,source in ipairs(q.sources) do
        if source.kind=="Objectif actuel" then
            local person=personTarget(source.text)
            if person then
                local linked=false
                for _,place in ipairs(result) do if place.objective==source.text and place.entityType~="alliance" then linked=true end end
                local key="person:"..normal(person)
                if not linked and not seen[key] then
                    seen[key]=true
                    result[#result+1]={name=person,normal=key,source=source.text,kind=source.kind,quest=q,entityType="person"}
                end
            end
        end
    end
    return result
end
-- Optional typed argument keeps the old one-argument call compatible.
function B.PlaceQuestion(name,place)
    if place and place.entityType=="alliance" then return place.topic.question end
    if place and place.entityType=="person" then return "Savez-vous où je pourrais trouver "..name.." ?" end
    if place and place.objective then
        local person=place.objective:match("^[Tt]rouvez%s+(.+)$")
        local role=person and normal(person):match("^(%S+)")
        if person and people[role] then
            return "Comment rejoindre "..name.." pour retrouver "..person.." ?"
        end
    end
    local public=B.PublicPlace(name)
    if public and public.entityType=="region" then return name..", c’est où exactement ?" end
    if public and public.entityType=="city" then return "Comment rejoindre "..name.." ?" end
    return oldQuestion(name)
end
function B.PlaceAnswer(place)
    if B.Here(place) then return oldAnswer(place) end
    if B.npc then B.npc.lastReferral=nil end
    if B.npc and not B.Willing(B.npc) then
        return B.SocialRefusal(B.npc) or "Je préfère en rester là. Nous ne nous connaissons pas assez."
    end
    if place.entityType=="alliance" and place.topic then return place.topic.answer end
    if place.entityType=="person" then
        if B.npc and mentions(place.name,B.npc.name) then return "C’est moi. Que me voulez-vous ?" end
        local region=place.quest and B.KnowledgeAtlas().regions[place.quest.zoneIndex]
        return "Je ne connais pas cette personne."..(region and (" Vous devriez demander aux habitants de la région « "..region.name.." ».") or " Essayez de vous renseigner auprès des gens du coin.")
    end
    local public=B.PublicPlace(place.name)
    if public then
        if public.entityType=="region" then
            local introduction=public.situation and (public.name.." se situe "..public.situation..". ") or ""
            if public.description~="" then return introduction..public.description end
            if introduction~="" then return introduction end
            return public.name.." est une région. Pour les chemins et les lieux précis, mieux vaut vous adresser aux habitants du pays."
        end
        local text=public.name.." se trouve dans la région « "..public.region.." »."
        -- Public geography is not a secret, but precise routes stay local to the NPC.
        if B.npc and B.npc.zoneIndex==public.zoneIndex then
            local target=B.Target(place)
            local px,py=B.PlayerMap()
            if target and px then
                if (target.x-px)^2+(target.y-py)^2<.0004 then text=text.." Vous y êtes presque. Regardez autour de vous."
                else text=text.." D’ici, cherchez "..B.Bearing(target.x-px,target.y-py).."." end
            end
        end
        return text
    end
    return oldAnswer(place)
end
