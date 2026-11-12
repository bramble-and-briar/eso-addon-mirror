if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Beta logic: questions follow visible journal text; trust is local to this add-on.
IHR_Runtime = IHR_Runtime or {}
IHR_Runtime.Beta = IHR_Runtime.Beta or {}
local B = IHR_Runtime.Beta
local A = IHR_Runtime.Base
B.VERSION = "0.16.2-beta.1"
B.defaults = { enabled = true, trustEnabled = true, relations = {}, notes = {}, notebook = {} }

function B.Name(text)
    return (zo_strformat("<<C:1>>", text or ""):gsub("%^%a+", ""))
end

local replacements={['à']='a',['â']='a',['ä']='a',['á']='a',['ã']='a',['å']='a',['é']='e',['è']='e',['ê']='e',['ë']='e',
    ['í']='i',['î']='i',['ï']='i',['ì']='i',['ó']='o',['ò']='o',['ô']='o',['ö']='o',['õ']='o',['ù']='u',['ú']='u',
    ['û']='u',['ü']='u',['ç']='c',['ñ']='n',['œ']='oe',['æ']='ae',['’']=' ',['–']=' ',['—']=' ',
    ['\194\160']=' ',['\226\128\175']=' '}
function B.Normalize(text)
    text=zo_strlower(text or ''):gsub('%^%a+',''):gsub('|c%x%x%x%x%x%x',''):gsub('|r','')
    text=text:gsub('[\194-\244][\128-\191]+',replacements)
    -- Locale-dependent %p/%s classes can remove a UTF-8 continuation byte on Windows.
    -- Replace only ASCII punctuation/control bytes; preserve every other character whole.
    text=text:gsub('[\001-\047\058-\064\091-\096\123-\127]',' ')
    return (text:gsub('[ \t\r\n]+',' '):gsub('^ +',''):gsub(' +$',''))
end

function B.QuestKey(name, zoneIndex)
    return tostring(zoneIndex or 0) .. ":" .. B.Normalize(name)
end

function B.ReadQuest(index)
    if not IsValidQuestIndex(index) then return nil end
    local name, background, active, _, override, complete, tracked = GetJournalQuestInfo(index)
    if not name or name == "" then return nil end
    local zoneName, _, zoneIndex = GetJournalQuestLocationInfo(index)
    local q = { index=index, name=B.Name(name), zoneName=B.Name(zoneName), zoneIndex=zoneIndex,
        complete=complete, tracked=tracked, sources={} }
    q.key = B.QuestKey(name, zoneIndex)
    local seen = {}
    local function add(text, kind)
        if type(text) == "string" and text ~= "" then
            local normal = B.Normalize(text)
            if normal ~= "" and not seen[normal] then
                seen[normal] = true
                q.sources[#q.sources+1] = {text=text, kind=kind}
            end
        end
    end
    -- Start with the complete story displayed in the journal, not just its task.
    add(background, "Journal de quête")
    add(active, "Étape actuelle")
    add(override, "Objectif actuel")
    for step = 1, GetJournalQuestNumSteps(index) do
        local journalText, visibility, _, trackerText, conditions = GetJournalQuestStepInfo(index, step)
        if visibility ~= QUEST_STEP_VISIBILITY_HIDDEN then
            add(journalText, "Journal : étape visible")
            add(trackerText, "Objectif actuel")
            for condition = 1, conditions or 0 do
                local text, _, _, fail, done, _, visible = GetJournalQuestConditionInfo(index, step, condition, false)
                if visible and not fail then add(text, done and "Objectif accompli" or "Objectif actuel") end
            end
        end
    end
    local note = B.saved and B.saved.notes[q.key]
    if note and note.text then add(note.text, "Propos de " .. note.npc) end
    return q
end

function B.Quests()
    local quests = {}
    for index = 1, MAX_JOURNAL_QUESTS or 25 do
        local q = B.ReadQuest(index)
        if q then quests[#quests+1] = q end
    end
    local here = GetUnitZoneIndex("player")
    table.sort(quests, function(a,b)
        local aa = (a.zoneIndex==here and 2 or 0) + (a.tracked and 1 or 0)
        local bb = (b.zoneIndex==here and 2 or 0) + (b.tracked and 1 or 0)
        if aa ~= bb then return aa > bb end
        return a.index < b.index
    end)
    return quests
end

function B.CurrentQuest(old)
    local q = B.ReadQuest(old.index)
    if q and q.key == old.key then return q end
    return nil
end

local genericPlaces = {entree=true,sortie=true,maison=true,temple=true,taverne=true,auberge=true,grotte=true,caverne=true,mine=true,crypte=true,portail=true,village=true,ville=true,campement=true,bandits=true,brigands=true,orques=true}
local placePrefixes = {"forteresse de ","forteresse d ","forteresse ","ruines de ","ruines d ","ruines ","village de ","village d ","cite de ","cite d ","chateau de ","chateau d ","fort de ","fort ","temple de ","temple d ","sanctuaire de ","sanctuaire d ","campement de ","camp de ","oratoire de ","oratoire d ","grotte de ","caverne de ","mine de ","crypte de ","tour de ","repaire de ","repaire d "}
function B.PlaceStem(text)
    text=B.Normalize(text):gsub("^les ",""):gsub("^la ",""):gsub("^le ",""):gsub("^l ","")
    for _,prefix in ipairs(placePrefixes) do
        if text:sub(1,#prefix)==prefix then return text:sub(#prefix+1) end
    end
    return text
end
local function GeographicContext(text, normal)
    if text:find(" a "..normal.." ",1,true) or text:find(" au "..normal.." ",1,true) or text:find(" aux "..normal.." ",1,true)
        or text:find(" vers "..normal.." ",1,true) or text:find(" dans "..normal.." ",1,true)
        or text:find(" appele "..normal.." ",1,true) or text:find(" appelee "..normal.." ",1,true)
        or text:find(" nomme "..normal.." ",1,true) or text:find(" nommee "..normal.." ",1,true) then return true end
    for _,prefix in ipairs(placePrefixes) do
        if text:find(" "..prefix..normal.." ",1,true) then return true end
    end
    return false
end
local catalog, catalogZone
local function Catalog()
    local zone=GetUnitZoneIndex("player")
    if catalog and catalogZone==zone then return catalog end
    catalogZone=zone;catalog={}
    local seen={}
    local function add(name,contextual)
        local normal=B.Normalize(name)
        if #normal>=6 and not genericPlaces[normal] and not seen[normal] then
            seen[normal]=true;catalog[#catalog+1]={name=B.Name(name),normal=normal,contextual=contextual}
        end
    end
    for _,name in ipairs(IHR_QuestPlaceNames or {}) do add(name) end
    for _,alias in ipairs(IHR_PlaceAliases or {}) do add(alias.name,alias.contextual) end
    if zone then for index=1,GetNumPOIs(zone) do add(GetPOIInfo(zone,index)) end end
    local originals={};for _,entry in ipairs(catalog) do originals[#originals+1]=entry end
    for _,entry in ipairs(originals) do
        local stem=B.PlaceStem(entry.name)
        if #stem>=6 and stem~=entry.normal and not genericPlaces[stem] and not seen[stem] then
            -- Display the proper place name, preserving accents from the source below when possible.
            seen[stem]=true;catalog[#catalog+1]={name=entry.name,normal=stem,contextual=true}
        end
    end
    table.sort(catalog,function(a,b) return #a.normal>#b.normal end)
    return catalog
end

-- This fallback only recognises explicit geographic wording. A person's name after
-- "Apportez le journal à ..." must not be interpreted as a destination by itself.
function B.ExtractJournalPlaces(text)
    local result,seen={},{}
    local lower=zo_strlower(text or "")
    local markers={"endroit appelé ","endroit nommé ","lieu appelé ","lieu nommé ","ville appelée ","forteresse appelée ","village appelé ","me rendre à ","vous rendre à ","rendez-vous à ","aller à ","allez à ","vit à ","habite à ","se trouve à "}
    local connectors={de=true,du=true,des=true,la=true,le=true,les=true,d=true,l=true,sur=true,sous=true,en=true,et=true,aux=true,au=true}
    local descriptors={forteresse=true,ruines=true,village=true,cite=true,ville=true,hameau=true,temple=true,sanctuaire=true,fort=true,tour=true,oratoire=true,repaire=true,promontoire=true,port=true,bois=true,foret=true,grotte=true,caverne=true,mine=true,crypte=true,tombeau=true,domaine=true,palais=true,chateau=true,campement=true}
    local function take(rest)
        rest=rest:gsub([[^[%s"']+]], ""):gsub("^«%s*", "")
        local words,proper={},false
        for word in rest:gmatch("[^ \t\r\n]+") do
            local bare=word:gsub("[.,;:!?].*$",""):gsub("».*$","")
            local norm=B.Normalize(bare)
            local capital=bare~=zo_strlower(bare)
            if norm=="" then break end
            if not (capital or connectors[norm] or (not proper and descriptors[norm])) then break end
            words[#words+1]=bare
            if capital and not connectors[norm] and not descriptors[norm] then proper=true end
            if #words>=9 or bare~=word then break end
        end
        if not proper then return end
        local name=table.concat(words," "):gsub("^[Ll]a ",""):gsub("^[Ll]e ",""):gsub("^[Ll]es ","")
        local norm=B.Normalize(name)
        if #norm>=4 and not genericPlaces[norm] and not seen[norm] then
            seen[norm]=true;result[#result+1]={name=B.Name(name),normal=norm}
        end
    end
    for _,marker in ipairs(markers) do
        local at=1
        while true do
            local _,finish=lower:find(marker,at,true)
            if not finish then break end
            take(text:sub(finish+1));at=finish+1
        end
    end
    -- Locative prepositions are accepted only when followed by a place descriptor.
    for _,marker in ipairs({"à la ","dans la ","dans les ","au ","aux "}) do
        local at=1
        while true do
            local _,finish=lower:find(marker,at,true)
            if not finish then break end
            local rest=text:sub(finish+1)
            local first=B.Normalize(rest:match("^([^ \t\r\n]+)") or "")
            if descriptors[first] then take(rest) end
            at=finish+1
        end
    end
    return result
end

function B.MatchPlaces(q)
    local found,result={},{}
    for _,source in ipairs(q.sources) do
        local text=" "..B.Normalize(source.text).." "
        local accepted={}
        local function append(place)
            local nested=false
            for _,longer in ipairs(accepted) do
                if (" "..longer.." "):find(" "..place.normal.." ",1,true) then nested=true;break end
            end
            if not nested then
                accepted[#accepted+1]=place.normal
                if not found[place.normal] then
                    found[place.normal]=true
                    result[#result+1]={name=place.name,normal=place.normal,source=source.text,kind=source.kind,quest=q}
                end
            end
        end
        for _,place in ipairs(Catalog()) do
            if text:find(" "..place.normal.." ",1,true) and (not place.contextual or GeographicContext(text,place.normal)) then append(place) end
        end
        for _,place in ipairs(B.ExtractJournalPlaces(source.text)) do append(place) end
    end
    return result
end

function B.FindLocalPOI(name)
    local zone=GetUnitZoneIndex("player")
    local normal=B.Normalize(name)
    local targets={[normal]=true}
    for _,alias in ipairs(IHR_PlaceAliases or {}) do
        if B.Normalize(alias.name)==normal then
            for _,target in ipairs(alias.targets) do targets[B.Normalize(target)]=true end
        end
    end
    local exact,stems={},{}
    for index=1,GetNumPOIs(zone) do
        local poi=B.Normalize(GetPOIInfo(zone,index))
        if targets[poi] then exact[#exact+1]=index
        elseif B.PlaceStem(poi)==B.PlaceStem(name) then stems[#stems+1]=index end
    end
    if #exact==1 then return zone,exact[1] end
    if #exact==0 and #stems==1 then return zone,stems[1] end
    return nil
end

function B.PlaceQuestion(name)
    local first,rest=name:match("^(%S+)(.*)$")
    local descriptor=B.Normalize(first or "")
    local feminine={forteresse=true,tour=true,cite=true,ville=true,mine=true,crypte=true,grotte=true,caverne=true,foret=true,maison=true}
    local masculine={temple=true,fort=true,village=true,hameau=true,sanctuaire=true,campement=true,camp=true,repaire=true,promontoire=true,port=true,chateau=true,oratoire=true,bois=true,domaine=true,palais=true}
    if descriptor=="ruines" then return "Savez-vous où se trouvent les "..zo_strlower(first)..rest.." ?" end
    if feminine[descriptor] then return "Savez-vous où se trouve la "..zo_strlower(first)..rest.." ?" end
    if descriptor=="oratoire" then return "Savez-vous où se trouve l’"..zo_strlower(first)..rest.." ?" end
    if masculine[descriptor] then return "Savez-vous où se trouve le "..zo_strlower(first)..rest.." ?" end
    return "Savez-vous où se trouve "..name.." ?"
end

function B.PlaceDescription(place)
    local zone,index=B.FindLocalPOI(place.name)
    if not zone then return nil end
    local _,_,startText,finishedText=GetPOIInfo(zone,index)
    local _,_,pinType=GetPOIMapInfo(zone,index)
    if pinType==MAP_PIN_TYPE_POI_COMPLETE and finishedText and finishedText~="" then return finishedText end
    return startText and startText~="" and startText or nil
end

function B.PlaceAnswer(place)
    local zone, index = B.FindLocalPOI(place.name)
    if zone then
        A.PrepareMap()
        local x,y,_,_,shown = GetPOIMapInfo(zone,index)
        if shown and type(x)=="number" and type(y)=="number" and (x~=0 or y~=0) then
            -- Base routine calculates directions and supplies the official map description.
            if A.POIDirections then
                local direction,distance=A.POIDirections(index)
                return place.name.." ? C’est "..direction..". "..distance
            end
            return A.Rumor(index)
        end
    end
    -- A recorded place mention is not proof that this NPC knows its location.
    return place.name.." ? Je ne connais pas le chemin. Quelqu’un du coin pourra peut-être vous renseigner."
end

local generic = {citoyen=true,citoyenne=true,garde=true,guerrier=true,guerriere=true,villageois=true,villageoise=true,marchand=true,marchande=true,habitant=true,habitante=true,pecheur=true,pecheuse=true,travailleur=true,travailleuse=true,ouvrier=true,ouvriere=true,refugie=true,refugiee=true}
function B.RelationKey(npc)
    local name, caption = B.Normalize(npc.name), B.Normalize(npc.caption)
    if name=="" or name==caption or generic[name] then return nil end
    -- Zone + locality reduces homonym collisions; there is no asserted permanent NPC ID.
    return tostring(npc.zoneId or npc.zoneIndex or 0)..":"..B.Normalize(npc.locality)..":"..name
end

function B.Relation(npc)
    if not B.saved or not B.saved.trustEnabled then return nil end
    local key = B.RelationKey(npc)
    if not key then return nil end
    if not B.saved.relations[key] then
        B.saved.relations[key] = {score=0, days={}, name=npc.name}
    end
    return B.saved.relations[key]
end

function B.ChangeTrust(npc, action, points)
    local relation = B.Relation(npc)
    if not relation then return false end
    local day = math.floor(GetTimeStamp()/86400)
    if relation.days[action] == day then return false end
    relation.days[action] = day
    relation.score = math.max(0, math.min(20, relation.score + points))
    return true
end

function B.Attitude(npc)
    local r = B.Relation(npc)
    if not r then return "Rencontre de passage" end
    if r.score >= 12 then return "Relation de confiance" end
    if r.score >= 7 then return "Vous êtes un visage familier" end
    if r.score >= 3 then return "Vous faites connaissance" end
    return "Vous vous connaissez à peine"
end

function B.Greeting(npc)
    local r = B.Relation(npc)
    if r and r.score>=12 then return "Ah, vous ! Approchez. Quelles nouvelles ?" end
    if r and r.score>=7 then return "Ah, vous revoilà. Que cherchez-vous aujourd’hui ?" end
    if r and r.score>=3 then return "Ah, bonjour. Qu’est-ce qui vous amène ?" end
    return "Bonjour. Vous cherchez quelque chose ?"
end

function B.Remember(place)
    local entry = {name=place.name, source=place.source, kind=place.kind, questName=place.quest.name, questKey=place.quest.key, time=GetTimeStamp()}
    local entries = B.saved.notebook
    for i=#entries,1,-1 do
        if entries[i].questKey==entry.questKey and B.Normalize(entries[i].name)==place.normal then table.remove(entries,i) end
    end
    table.insert(entries,1,entry)
    while #entries>30 do table.remove(entries) end
end

function B.Initialize()
    if B.saved then return end
    B.saved = RolePlayMod.Storage("conversations", function() return ZO_SavedVars:NewCharacterIdSettings("IHeardARumorBetaSaved", 1, nil, B.defaults, GetWorldName()) end, B.defaults)
    -- Retain the old entry points; the UI module defines Open by the time events fire.
    local previous = IsTargetFriendlyNPC
    IsTargetFriendlyNPC = function()
        if B.saved.enabled then return B.Open() end
        return previous()
    end
    SLASH_COMMANDS["/askforinfo"] = IsTargetFriendlyNPC
    SLASH_COMMANDS["/ihrbeta"] = function()
        B.saved.enabled = not B.saved.enabled
        if B.Close then B.Close() end
        d("[RolePlayMod] Bêta "..(B.saved.enabled and "activée" or "désactivée — dialogue classique rétabli")..".")
    end
    SLASH_COMMANDS["/ihrstatus"] = function()
        local questions=0
        for _,q in ipairs(B.Quests()) do questions=questions+#B.MatchPlaces(q) end
        d(string.format("[RolePlayMod] %s | bêta %s | %d quête(s), %d lieu(x) identifié(s) | confiance %s",B.VERSION,B.saved.enabled and "active" or "inactive",#B.Quests(),questions,B.saved.trustEnabled and "active" or "inactive"))
    end
    SLASH_COMMANDS["/ihrtrust"] = function()
        B.saved.trustEnabled = not B.saved.trustEnabled
        if B.Close then B.Close() end
        d("[RolePlayMod] Confiance "..(B.saved.trustEnabled and "activée" or "désactivée")..".")
    end
    if false and LibAddonMenu2 then
        LibAddonMenu2:RegisterAddonPanel("IHRBetaOptions", {
            type="panel", name="IHeardARumor - Conversations bêta", displayName="Conversations et confiance",
            version=B.VERSION,
            registerForRefresh=true, registerForDefaults=true,
        })
        LibAddonMenu2:RegisterOptionControls("IHRBetaOptions", {
            {type="description", text="Les questions suivent les renseignements déjà présents dans votre journal. Les services et les indications sur les environs restent disponibles."},
            {type="checkbox", name="Activer les conversations bêta", default=true,
                tooltip="Désactivez cette option pour retrouver le dialogue classique sans supprimer vos relations ni vos pistes.",
                getFunc=function() return B.saved.enabled end,
                setFunc=function(value) B.saved.enabled=value;if B.Close then B.Close() end end},
            {type="checkbox", name="Mémoriser une relation de confiance", default=true,
                tooltip="Relation propre à cet addon et à ce personnage. Avec Speechcraft, elle influence l’accueil et la précision des renseignements. Les services restent accessibles. Les rencontres et échanges courtois comptent une fois par jour.",
                getFunc=function() return B.saved.trustEnabled end,
                setFunc=function(value) B.saved.trustEnabled=value;if B.Close then B.Close() end end},
        })
    end
    local function offered()
        local text = GetOfferedQuestInfo()
        local npc = GetUnitName("interact")
        if type(text)=="string" and text~="" and npc and npc~="" then
            B.pendingOffer = {text=text, npc=B.Name(npc), time=GetTimeStamp()}
        else B.pendingOffer=nil end
    end
    EVENT_MANAGER:RegisterForEvent("IHRBetaOffer",EVENT_QUEST_OFFERED,offered)
    EVENT_MANAGER:RegisterForEvent("IHRBetaShared",EVENT_QUEST_SHARED,function() B.pendingOffer=nil end)
    EVENT_MANAGER:RegisterForEvent("IHRBetaAdded",EVENT_QUEST_ADDED,function(_, index)
        local pending = B.pendingOffer
        B.pendingOffer=nil
        if not pending or GetTimeStamp()-pending.time>120 or B.Name(GetUnitName("interact"))~=pending.npc then return end
        local q=B.ReadQuest(index)
        if q then B.saved.notes[q.key]={text=pending.text,npc=pending.npc} end
    end)
    EVENT_MANAGER:RegisterForEvent("IHRBetaRemoved",EVENT_QUEST_REMOVED,function(_, _, _, name, zoneIndex)
        B.saved.notes[B.QuestKey(name,zoneIndex)]=nil
        if B.IsOpen and B.IsOpen() then B.ShowQuests() end
    end)
    EVENT_MANAGER:UnregisterForEvent("IHRBetaInit",EVENT_ADD_ON_LOADED)
end
EVENT_MANAGER:RegisterForEvent("IHRBetaInit",EVENT_ADD_ON_LOADED,function(_,name)
    if name=="RolePlayMod" then B.Initialize() end
end)
