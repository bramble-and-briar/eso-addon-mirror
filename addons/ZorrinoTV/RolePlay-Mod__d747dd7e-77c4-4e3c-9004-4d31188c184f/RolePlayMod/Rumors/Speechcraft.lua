if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Speechcraft is an add-on simulation, not the game's hidden NPC disposition.
local B=IHR_Runtime.Beta
local A=IHR_Runtime.Base
local D=IHR_SpeechcraftData
local oldPlaceAnswer=B.PlaceAnswer
local oldGreeting=B.Greeting

function B.Hash(value)
    local hash=7
    for i=1,#value do hash=(hash*31+value:byte(i))%2147483647 end
    return hash
end
local function hasQuest(id)
    if type(HasQuest)=="function" and HasQuest(id) then return true end
    local name=type(GetQuestName)=="function" and B.Normalize(GetQuestName(id)) or ""
    if name~="" then for _,q in ipairs(B.Quests()) do if B.Normalize(q.name)==name then return true end end end
    return false
end
local function completed(id) return type(HasCompletedQuest)=="function" and HasCompletedQuest(id) or false end
local function localQuest(id)
    if type(GetQuestZoneId)~="function" or type(GetZoneIndex)~="function" then return false end
    local zone=GetQuestZoneId(id)
    return zone and zone>0 and GetZoneIndex(zone)==GetUnitZoneIndex("player")
end
local function valid(x,y)
    return type(x)=="number" and type(y)=="number" and x>=0 and x<=1 and y>=0 and y<=1 and (x~=0 or y~=0)
end
local function distance(x,y,tx,ty) return math.sqrt((x-tx)^2+(y-ty)^2) end
function B.Bearing(dx,dy)
    local degrees=(math.deg(math.atan2(dy,dx))+360)%360
    local names={"à l’est","au sud-est","au sud","au sud-ouest","à l’ouest","au nord-ouest","au nord","au nord-est"}
    return names[(math.floor((degrees+22.5)/45)%8)+1]
end
function B.PlayerMap()
    A.PrepareMap()
    local x,y=GetMapPlayerPosition("player")
    if valid(x,y) then return x,y end
end
function B.Landmarks()
    local result={}
    if type(GetNumFastTravelNodes)~="function" then return result end
    for i=1,GetNumFastTravelNodes() do
        local known,name,x,y,_,_,_,shown,locked=GetFastTravelNodeInfo(i)
        if known and shown and not locked and name and name~="" and valid(x,y) then
            result[#result+1]={name=B.Name(name),x=x,y=y}
        end
    end
    return result
end
function B.FindLandmark(name)
    B.PlayerMap()
    local found
    for _,p in ipairs(B.Landmarks()) do
        if B.Normalize(p.name)==B.Normalize(name) then
            if found then return nil end
            found=p
        end
    end
    return found
end
function B.Target(place)
    local zone,index=B.FindLocalPOI(place.name)
    if not zone then return nil end
    B.PlayerMap()
    local x,y,_,_,shown=GetPOIMapInfo(zone,index)
    if shown and valid(x,y) then return {name=place.name,x=x,y=y,index=index,zone=zone} end
end

function B.Profile(npc)
    local key=B.RelationKey(npc) or (npc.name..":"..tostring(npc.zoneId))
    local hash=B.Hash(key)
    local types={"avenant","reserve","mefiant","presse"}
    local role=B.Normalize(npc.caption)
    local informed=role:find("aubergiste",1,true) or role:find("brasseur",1,true) or role:find("navig",1,true)
    return {key=key,hash=hash,personality=types[hash%4+1],informed=not not informed,traditional=hash%4==2}
end
function B.Reputation(npc)
    local points,lines=0,{}
    if not B.saved or not B.saved.reputationEnabled then return 0,lines end
    for _,deed in ipairs(D.deeds) do
        if localQuest(deed.quest) and completed(deed.quest) then
            points=points+deed.points;lines[#lines+1]=deed.text
        end
    end
    for id in pairs(B.saved.rumorsHeard or {}) do
        if localQuest(id) and completed(id) then
            points=points+1
            B.saved.rumorDeeds[id]=true
        end
    end
    return math.min(9,points),lines
end
function B.OriginModifier(npc,profile)
    if not B.saved.originInfluence or not profile.traditional then return 0 end
    local race=type(GetUnitRace)=="function" and B.Normalize(GetUnitRace("player")) or ""
    local zone=type(GetZoneNameByIndex)=="function" and B.Normalize(GetZoneNameByIndex(npc.zoneIndex)) or ""
    -- A configurable fictional prior for some traditional locals, never a universal rule.
    local dunmer=race:find("elfe noir",1,true) or race:find("dark elf",1,true) or race=="dunmer"
    if dunmer and (zone:find("bois de graht",1,true) or zone=="grahtwood") then return -2 end
    local npcRace=B.Normalize(npc.race or "")
    if race~="" and npcRace~="" and race==npcRace then return 1 end
    return 0
end
function B.EffectiveTrust(npc)
    if not B.saved.speechcraftEnabled then return 20 end
    local profile=B.Profile(npc)
    local relation=B.Relation(npc)
    local base={avenant=3,reserve=1,mefiant=-2,presse=-3}
    local reputation=B.Reputation(npc)
    local persuaded=npc.persuaded and 3 or 0
    return (relation and relation.score or 0)+(base[profile.personality] or 0)+reputation+B.OriginModifier(npc,profile)+persuaded
end
function B.Line(key,lines,npc)
    npc=npc or B.npc
    local identity=npc and (B.Profile(npc).key) or "voyageur"
    -- Stable for this NPC/topic/day: reopening cannot reroll a favourable answer.
    return lines[B.Hash(identity..":"..key..":"..math.floor(GetTimeStamp()/86400))%#lines+1]
end
function B.Willing(npc) return not B.saved.speechcraftEnabled or B.EffectiveTrust(npc)>-2 end
function B.Persuade(npc)
    local r=B.Relation(npc)
    if not r then return false,"Je préfère en rester là." end
    local day=math.floor(GetTimeStamp()/86400)
    if r.days.persuasion==day then return npc.persuaded or false,"Nous en avons déjà parlé. N’insistez pas." end
    r.days.persuasion=day
    local rank=math.min(3,math.floor((B.saved.speechExperience or 0)/5))
    if B.EffectiveTrust(npc)+rank>=0 then
        npc.persuaded=true
        B.ChangeTrust(npc,"persuaded",1)
        B.saved.speechExperience=(B.saved.speechExperience or 0)+1
        return true,"Bon… Posez votre question. Je verrai ce que je peux faire."
    end
    return false,"Pas maintenant. Nous ne nous connaissons pas assez."
end

function B.Referral(npc)
    SetMapToPlayerLocation()
    local locality=A.SubZone()
    local choices={}
    for _,entry in pairs(TamrielServiceMap or {}) do
        if type(entry)=="table" and A.SamePlace(entry.subZoneId,locality) and entry.name and entry.name~="" and valid(entry.mapX,entry.mapY)
            and (entry.service=="Innkeeper" or entry.service=="Brewer" or entry.service=="Navigator") then
            local name=(IHR_FR.npcNames and IHR_FR.npcNames[entry.name]) or entry.name
            if B.Normalize(name)~=B.Normalize(npc.name) then
                choices[#choices+1]={name=name,service=entry.service,x=entry.mapX,y=entry.mapY,locality=locality}
            end
        end
    end
    table.sort(choices,function(a,b) return a.name<b.name end)
    return choices[1]
end
function B.Knowledge(place,npc)
    if not B.saved.speechcraftEnabled then return "precis",B.Target(place) end
    local profile=B.Profile(npc)
    local trust=B.EffectiveTrust(npc)
    if trust<=-2 then return "refus" end
    local target=B.Target(place)
    if not target then return "inconnu" end
    local hash=B.Hash(profile.key..":"..B.Normalize(place.name))%100
    local px,py=B.PlayerMap()
    local far=px and distance(px,py,target.x,target.y)>.3
    if not profile.informed and ((far and hash<45) or hash<12) then return "inconnu",target end
    if trust<3 and hash<55 then return "reserve",target end
    if trust<6 then return "vague",target end
    return "precis",target
end
function B.PlaceAnswer(place)
    if not B.saved or not B.saved.speechcraftEnabled or not B.npc then return oldPlaceAnswer(place) end
    local npc=B.npc
    npc.lastReferral=nil
    local tier,target=B.Knowledge(place,npc)
    local name=place.name
    if tier=="refus" then
        return B.Line("refus",{"Je n’ai pas le temps de faire la conversation.","Je ne vous connais pas. Allez donc demander ailleurs.","J’ai assez à faire comme ça. Revenez une autre fois."},npc)
    end
    if tier=="inconnu" then
        local answer=B.Line("inconnu:"..B.Normalize(name),{"Je n’ai jamais entendu parler de cet endroit.",name.." ? Non, ce nom ne me dit rien.","Désolé, je ne connais pas le coin dont vous parlez."},npc)
        local referral=B.Referral(npc)
        if referral then
            npc.lastReferral=referral
            answer=answer.." Demandez plutôt à "..referral.name..". Cette personne pourra peut-être vous aider."
        end
        return answer
    end
    if tier=="reserve" then
        return B.Line("reserve",{"Ce nom me dit quelque chose… mais je n’en sais pas assez pour vous guider.","Vous posez beaucoup de questions pour quelqu’un que je connais à peine.","Peut-être bien. Mais j’aimerais d’abord savoir à qui j’ai affaire."},npc)
    end
    local px,py=B.PlayerMap()
    if not px then return oldPlaceAnswer(place) end
    local bearing=B.Bearing(target.x-px,target.y-py)
    if tier=="vague" then
        return B.Line("vague:"..B.Normalize(name),{name.." ? Il me semble que c’est "..bearing.." d’ici. Je ne pourrais pas être plus précis.","Si ma mémoire est bonne, cherchez "..bearing..". Mais je n’y suis pas allé récemment.","J’en ai entendu parler. C’est "..bearing.." d’ici, à ce qu’on m’a dit."},npc)
    end
    if distance(px,py,target.x,target.y)<.02 then return name.." ? Vous y êtes presque. Regardez autour de vous." end
    local landmark,best
    for _,p in ipairs(B.Landmarks()) do
        local first=distance(px,py,p.x,p.y)
        local second=distance(p.x,p.y,target.x,target.y)
        local direct=distance(px,py,target.x,target.y)
        if B.Normalize(p.name)~=B.Normalize(name) and first>.015 and second>.015 and first+second<=direct*1.25 and (not best or second<best) then
            landmark=p;best=second
        end
    end
    if landmark then
        local direction=B.Bearing(target.x-landmark.x,target.y-landmark.y)
        return name.." ? C’est "..bearing.." d’ici. Pour vous repérer, cherchez "..landmark.name..". De là, votre destination se trouve "..direction.."."
    end
    return name.." ? Oui, c’est "..bearing.." d’ici. "..B.Line("distance",{"Vous avez encore un peu de chemin.","Vous devriez le repérer en approchant.","Gardez cette direction pour vous orienter."},npc)
end
function B.Greeting(npc)
    if not B.saved or not B.saved.speechcraftEnabled then return oldGreeting(npc) end
    local reputation,lines=B.Reputation(npc)
    if reputation>0 and #lines>0 and B.Profile(npc).hash%3~=0 then return B.Line("reputation",lines,npc).." Qu’est-ce qui vous amène ?" end
    if not B.Willing(npc) then return B.Line("accueil-refus",{"Vous vouliez quelque chose ? Faites vite.","Je ne suis pas d’humeur à bavarder.","Nous n’avons pas été présentés, il me semble."},npc) end
    local r=B.Relation(npc)
    if r and r.score>=7 then return B.Line("familier",{"Ah, vous revoilà ! Quelles nouvelles ?","Entrez donc dans la conversation. Je vous écoute.","Tiens, un visage connu. Vous cherchez encore quelque chose ?"},npc) end
    return B.Line("accueil",{"Bonjour. Vous cherchez quelqu’un ?","Oui ? Que puis-je pour vous ?","Je vous écoute. Qu’est-ce qui vous amène ?"},npc)
end

function B.MapKey()
    if type(GetMapTileTexture)~="function" then return nil end
    local texture=zo_strlower(GetMapTileTexture(1) or ""):gsub("\\","/")
    return texture:match("maps/(.-)%.dds$")
end
function B.RumorMap()
    -- Starter coordinates may belong to an interior map. Do not zoom out first.
    SetMapToPlayerLocation()
    local x,y=GetMapPlayerPosition("player")
    if valid(x,y) then return x,y,B.MapKey() end
end
function B.RumorEligible(r)
    local id=r.quest
    if hasQuest(id) or completed(id) then return false end
    local db=IHR_QuestRumorDB
    if not db then return false end
    if db.removed[id] or db.companionRapport[id] then return false end
    for _,required in ipairs(db.prerequisites[id] or {}) do if not completed(required) then return false end end
    for _,superseding in ipairs(db.breadcrumbs[id] or {}) do if completed(superseding) then return false end end
    local meta=db.meta[id]
    if meta and tonumber(meta[1])==9 then return false end
    if r.mapKey and r.mapKey~=B.MapKey() then return false end
    -- A current-map record is sufficient even if the quest API has no zone ID.
    return r.mapKey~=nil or localQuest(id)
end
function B.UnstartedRumors()
    local result,byId={},{}
    local px,py,mapKey=B.RumorMap()
    local db=IHR_QuestRumorDB
    if not px or not db or not mapKey then return result end
    if not db.maps[mapKey] and not (B.rumorDiscoveries and B.rumorDiscoveries.starts[mapKey]) then
        px,py=B.PlayerMap();mapKey=B.MapKey()
        if not px or not mapKey then return result end
    end
    local premises={}
    for _,entry in ipairs(D.rumors) do premises[entry.quest]=entry end
    local function add(row)
        local x,y,id,giverId=row[1],row[2],tonumber(row[3]),tonumber(row[4])
        if not id or not valid(x,y) then return end
        local candidate={quest=id,mapKey=mapKey}
        if not B.RumorEligible(candidate) then return end
        local dist=distance(px,py,x,y)
        if dist>.30 then return end
        local rawName=db.givers[giverId]
        local unnamed=type(rawName)~="string" or rawName==""
        local name=unnamed and "une personne dans les environs" or B.Name(rawName)
        local normalized=B.Normalize(name)
        local object=db.objects[id] or normalized:find("affiche",1,true) or normalized:find("lettre",1,true)
            or normalized:find("panneau",1,true) or normalized:find("cadavre",1,true) or normalized:find("journal",1,true)
            or normalized:find("note ",1,true) or normalized:find("notice",1,true) or normalized:find("livre",1,true)
        local premise=premises[id]
        candidate.giver=name;candidate.object=not not object
        candidate.anchor={name=name,x=x,y=y};candidate.distance=dist
        candidate.title=object and ("Une piste : "..name) or (unnamed and ("Une affaire : "..B.Name((type(GetQuestName)=="function" and GetQuestName(id)) or db.names[id] or tostring(id))) or ("Des nouvelles de "..name.." ?"))
        candidate.text=premise and premise.text or (unnamed and "J’ai entendu parler d’une affaire dans ce coin. Je n’ai pas plus de détails, mais ça vaut peut-être le détour." or (object and ("On m’a parlé de quelque chose à examiner : "..name..". Ça pourrait vous intéresser.") or ("Il paraît que "..name.." cherchait un coup de main. Si vous passez dans le coin, allez voir si votre aide serait encore utile.")))
        candidate.verified=premise~=nil
        local previous=byId[id]
        if not previous or dist<previous.distance then byId[id]=candidate end
    end
    for _,row in ipairs(db.maps[mapKey] or {}) do add(row) end
    -- New accepted quests can extend the public database locally, for other characters.
    local discovered=B.rumorDiscoveries and B.rumorDiscoveries.starts[mapKey]
    for id,entry in pairs(discovered or {}) do
        if entry.name then
            local temporary=-tonumber(id)
            db.givers[temporary]=entry.name
            add({entry.x,entry.y,tonumber(id),temporary})
        end
    end
    for _,entry in pairs(byId) do result[#result+1]=entry end
    table.sort(result,function(a,b)
        if a.distance~=b.distance then return a.distance<b.distance end
        return a.quest<b.quest
    end)
    return result
end
function B.HearRumor(r)
    local px,py,mapKey=B.RumorMap()
    if mapKey~=r.mapKey then px,py=B.PlayerMap();mapKey=B.MapKey() end
    if mapKey~=r.mapKey or not B.RumorEligible(r) then return nil end
    B.saved.rumorsHeard[r.quest]=GetTimeStamp()
    local text=r.text
    if px and r.anchor then
        text=text.." C’est "..B.Bearing(r.anchor.x-px,r.anchor.y-py).." d’ici."
        if B.npc and B.EffectiveTrust(B.npc)>=6 then
            local nearby,best
            for _,landmark in ipairs(B.Landmarks()) do
                local d=distance(r.anchor.x,r.anchor.y,landmark.x,landmark.y)
                if d<.10 and (not best or d<best) then nearby=landmark;best=d end
            end
            if nearby then
                text=text.." Repérez "..nearby.name..". "
                if best<.015 then text=text.."Cherchez tout près."
                else text=text.."De là, cherchez "..B.Bearing(r.anchor.x-nearby.x,r.anchor.y-nearby.y).."." end
            end
        end
    end
    return text
end

EVENT_MANAGER:RegisterForEvent("IHRSpeechInit",EVENT_ADD_ON_LOADED,function(_,name)
    if name~="RolePlayMod" then return end
    if not B.saved then B.Initialize() end
    if B.saved.speechcraftEnabled==nil then B.saved.speechcraftEnabled=true end
    if B.saved.reputationEnabled==nil then B.saved.reputationEnabled=true end
    if B.saved.originInfluence==nil then B.saved.originInfluence=true end
    if B.saved.nativeConversation==nil then B.saved.nativeConversation=true end
    B.saved.rumorsHeard=B.saved.rumorsHeard or {};B.saved.rumorDeeds=B.saved.rumorDeeds or {}
    B.saved.speechExperience=B.saved.speechExperience or 0
    B.rumorDiscoveries=RolePlayMod.WorldStorage("rumorCatalogue", function() return ZO_SavedVars:NewAccountWide("IHeardARumorRumorDiscoveries",1,nil,{starts={}},GetWorldName()) end, {starts={}})
    local pending
    EVENT_MANAGER:RegisterForEvent("IHRCaptureStartOffer",EVENT_QUEST_OFFERED,function()
        local name=GetUnitName("interact")
        if name and name~="" then pending={name=B.Name(name),time=GetTimeStamp()} end
    end)
    EVENT_MANAGER:RegisterForEvent("IHRCaptureStartShared",EVENT_QUEST_SHARED,function() pending=nil end)
    EVENT_MANAGER:RegisterForEvent("IHRCaptureStartAdded",EVENT_QUEST_ADDED,function(_,index)
        local offer=pending;pending=nil
        if not offer or GetTimeStamp()-offer.time>120 or B.Name(GetUnitName("interact"))~=offer.name then return end
        local q=B.ReadQuest(index);if not q then return end
        local id
        for candidate in pairs(IHR_QuestRumorDB.names) do
            local title=type(GetQuestName)=="function" and GetQuestName(candidate) or IHR_QuestRumorDB.names[candidate]
            if B.Normalize(title)==B.Normalize(q.name) and hasQuest(candidate) then
                if id then return end
                id=candidate
            end
        end
        if not id then return end
        local x,y,map=B.RumorMap()
        if x and map then
            local starts=B.rumorDiscoveries.starts
            starts[map]=starts[map] or {}
            starts[map][id]={x=x,y=y,name=offer.name,time=GetTimeStamp()}
        end
    end)
    if false and LibAddonMenu2 then
        LibAddonMenu2:RegisterAddonPanel("IHRSpeechOptions",{type="panel",name="IHeardARumor - Speechcraft",displayName="Speechcraft et rumeurs",version=B.VERSION,registerForDefaults=true})
        local options={}
        for _,entry in ipairs({{"speechcraftEnabled","Faire varier la difficulté du d20 selon la disposition"}, {"reputationEnabled","Tenir compte des services rendus dans la région"}, {"originInfluence","Contexte politique et préjugés de certains habitants"}, {"crimeInfluence","Prime et réputation criminelle dans la région"}, {"nativeConversation","Accès depuis les conversations animées du jeu"}}) do
            local key,label=entry[1],entry[2]
            options[#options+1]={type="checkbox",name=label,default=true,getFunc=function() return B.saved[key] end,setFunc=function(value) B.saved[key]=value;B.Close() end}
        end
        options[#options+1]={type="description",text="Les personnalités et préjugés sont une simulation de l’addon. L’origine n’est pas une règle universelle ; seuls certains profils réagissent. La réputation utilise les quêtes accomplies par ce personnage. Les pistes UESP non vérifiées restent incertaines et peuvent dépendre de prérequis."}
        LibAddonMenu2:RegisterOptionControls("IHRSpeechOptions",options)
    end
    SLASH_COMMANDS["/ihrrumors"]=function()
        local db=IHR_QuestRumorDB
        d(string.format("[RolePlayMod] Rumeurs : %d piste(s) proche(s) ; base %d quêtes / %d positions / %d cartes.",#B.UnstartedRumors(),db.questCount,db.pinCount,db.mapCount))
    end
    SLASH_COMMANDS["/ihrspeech"]=function()
        B.saved.speechcraftEnabled=not B.saved.speechcraftEnabled;B.Close()
        d("[RolePlayMod] Speechcraft "..(B.saved.speechcraftEnabled and "activé" or "désactivé")..".")
    end
    EVENT_MANAGER:UnregisterForEvent("IHRSpeechInit",EVENT_ADD_ON_LOADED)
end)
