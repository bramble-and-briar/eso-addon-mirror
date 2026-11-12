if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Hospitality and social rules. World interactions and gold remain owned by ESO.
local B=IHR_Runtime.Beta
local A=IHR_Runtime.Base
local previousWilling=B.Willing
local previousKnowledge=B.Knowledge
local previousReputation=B.Reputation
local previousHear=B.HearRumor

function B.IsInnkeeper(npc)
    if not npc then return false end
    local role=B.Normalize(npc.caption or "")
    if role:find("aubergiste",1,true) or role:find("innkeeper",1,true) then return true end
    local locality=A.SubZone()
    for _,entry in pairs(TamrielServiceMap or {}) do
        if type(entry)=="table" and entry.service=="Innkeeper" and A.SamePlace(entry.subZoneId,locality) then
            local name=(IHR_FR.npcNames and IHR_FR.npcNames[entry.name]) or entry.name
            if B.Normalize(name)==B.Normalize(npc.name) then return true end
        end
    end
    return false
end
function B.RegisterVenue(title)
    if not B.saved then return false end
    B.saved.hospitalityVenues=B.saved.hospitalityVenues or {}
    local zone,x,y,z=GetUnitWorldPosition("player")
    for _,v in ipairs(B.saved.hospitalityVenues) do
        if v.zone==zone and (v.x-x)^2+(v.y-y)^2+(v.z-z)^2<250000 then return true end
    end
    table.insert(B.saved.hospitalityVenues,{zone=zone,x=x,y=y,z=z,title=title})
    while #B.saved.hospitalityVenues>200 do table.remove(B.saved.hospitalityVenues,1) end
    return true
end
function B.HospitalityContext(npc)
    if B.IsInnkeeper(npc) then return true,"aubergiste" end
    -- Job alone is insufficient: a cook in a market is not proof of a restaurant.
    local texts={}
    for _,fn in ipairs({GetPlayerLocationName or false,GetPlayerActiveSubzoneName or false,GetMapName or false}) do
        if type(fn)=="function" then texts[#texts+1]=B.Normalize(fn()) end
    end
    local text=" "..table.concat(texts," ").." "
    for _,word in ipairs({"auberge","taverne","restaurant","brasserie","cantine","tavern","inn","alehouse"}) do
        if text:find(" "..word.." ",1,true) then return true,word end
    end
    local zone,x,y,z=GetUnitWorldPosition("player")
    for _,v in ipairs(B.saved.hospitalityVenues or {}) do
        if v.zone==zone and (v.x-x)^2+(v.y-y)^2+(v.z-z)^2<=1000000 then return true,v.title end
    end
    return false
end
function B.Willing(npc)
    if not B.saved.speechcraftEnabled then return true end
    local relation=B.Relation(npc)
    local reputation=B.Reputation(npc)
    local familiar=(relation and relation.score>=3) or reputation>=2 or npc.persuaded
    return not not (familiar and B.EffectiveTrust(npc)>=2)
end
function B.Reputation(npc)
    local points,lines=previousReputation(npc)
    if B.saved and B.saved.reputationEnabled then
        B.saved.reputationLedger=B.saved.reputationLedger or {}
        for _,deed in ipairs(IHR_SpeechcraftData.deeds) do
            if type(HasCompletedQuest)=="function" and HasCompletedQuest(deed.quest) then
                B.saved.reputationLedger[deed.quest]={points=deed.points,time=GetTimeStamp(),reason=deed.text}
            end
        end
        for id in pairs(B.saved.rumorsHeard or {}) do
            if type(HasCompletedQuest)=="function" and HasCompletedQuest(id) then
                B.saved.reputationLedger[id]=B.saved.reputationLedger[id] or {points=1,time=GetTimeStamp(),reason="Une piste entendue a été menée à terme."}
            end
        end
    end
    return points,lines
end
function B.Confidence(npc)
    return math.max(0,math.min(100,math.floor((B.EffectiveTrust(npc)+5)*4)))
end
function B.Attitude(npc)
    if not B.saved.speechcraftEnabled then return "Confiance : règles sociales désactivées" end
    local score=B.Confidence(npc)
    local state=not B.Willing(npc) and "Méfiant" or (score>=75 and "Confiant" or score>=45 and "À l’aise" or "Prudent")
    return string.format("Confiance : %d/100 · %s",score,state)
end
function B.Knowledge(place,npc)
    local tier,target=previousKnowledge(place,npc)
    if not B.saved.speechcraftEnabled then return tier,target end
    if not B.Willing(npc) then return "refus",target end
    if tier=="inconnu" or not target then return tier,target end
    local profile=B.Profile(npc)
    local limit=profile.informed and 75 or 45
    if B.Hash(profile.key..":geographie:"..B.Normalize(place.name))%100>=limit then return "inconnu",target end
    return tier,target
end
function B.KnownRumors(npc)
    if not B.HospitalityContext(npc) or not B.Willing(npc) then return {} end
    local result={}
    local profile=B.Profile(npc)
    local innkeeper=B.IsInnkeeper(npc)
    local role=B.Normalize(npc.caption)
    local staff=role:find("brasseur",1,true) or role:find("chef",1,true) or role:find("cuisin",1,true)
    local chance=innkeeper and 75 or staff and 55 or 30
    for _,rumor in ipairs(B.UnstartedRumors()) do
        local hash=B.Hash(profile.key..":rumeur:"..rumor.quest)
        if hash%100<chance then result[#result+1]={rumor=rumor,order=hash} end
    end
    table.sort(result,function(a,b) return a.order<b.order end)
    local known={}
    local maximum=innkeeper and 3 or 2
    for i=1,math.min(maximum,#result) do known[#known+1]=result[i].rumor end
    return known
end
function B.HearRumor(rumor)
    if not B.npc or not B.HospitalityContext(B.npc) or not B.Willing(B.npc) then return nil end
    local known=false
    for _,entry in ipairs(B.KnownRumors(B.npc)) do if entry.quest==rumor.quest then known=true;break end end
    if not known then return nil end
    return previousHear(rumor)
end

function B.Remember(place,answer,informant)
    -- The journal is evidence for the question, never a substitute for the reply.
    if type(answer)~="string" or answer=="" or not informant then return false end
    local name=type(informant)=="table" and informant.name or informant
    local quest=place.quest or {}
    local key=quest.key or (place.rumorId and ("rumor:"..place.rumorId)) or "information"
    local entry={origin="npc",name=place.name,source=answer,response=answer,informant=name,
        kind="Renseignement de "..name,questName=quest.name or "Rumeur entendue",questKey=key,
        rumorId=place.rumorId,time=GetTimeStamp(),locality=B.npc and B.npc.locality or ""}
    local entries=B.saved.notebook
    for i=#entries,1,-1 do
        local previous=entries[i]
        if previous.origin=="npc" and previous.questKey==key and previous.informant==name and B.Normalize(previous.name)==B.Normalize(place.name) then table.remove(entries,i) end
    end
    table.insert(entries,1,entry)
    while #entries>30 do table.remove(entries) end
    return true
end

B.Lodging={}
local L=B.Lodging
function L.Available()
    return type(RolePlayNeeds)=="table" and type(RolePlayNeeds.settings)=="table"
        and RolePlayNeeds.settings.survivalModeOn==true and type(RolePlayNeeds.StartInnRest)=="function"
end
function L.Reserve(npc)
    if not B.IsInnkeeper(npc) or not L.Available() then return false end
    local zone,x,y,z=GetUnitWorldPosition("player")
    B.saved.lodging={npc=npc.name,locality=npc.locality,worldZone=zone,x=x,y=y,z=z,
        expires=GetTimeStamp()+8*3600,realGoldPaid=0,mode="repos RP gratuit"}
    return true
end
function L.Start()
    local lease=B.saved.lodging
    if not L.Available() then return false,"Activez le mode survie et la fatigue de RolePlayMod pour vous reposer." end
    if not lease or lease.consumed or GetTimeStamp()>=lease.expires then return false,"Vous n’avez pas de repos réservé auprès d’un aubergiste." end
    if IsUnitInCombat("player") or (type(IsMounted)=="function" and IsMounted()) then return false,"Vous ne pouvez pas dormir dans cette situation." end
    if type(IsInteracting)=="function" and IsInteracting() then return false,"Quittez d’abord le dialogue, puis installez-vous pour dormir." end
    local zone,x,y,z=GetUnitWorldPosition("player")
    if zone~=lease.worldZone or (x-lease.x)^2+(y-(lease.y or y))^2+(z-lease.z)^2>16000000 then return false,"Revenez près de l’auberge où vous avez demandé à vous reposer." end
    if B.IsOpen() then B.Close() end
    local ok,message=RolePlayNeeds.StartInnRest()
    if ok then lease.consumed=true end
    return ok,message
end

EVENT_MANAGER:RegisterForEvent("IHRHospitalityInit",EVENT_ADD_ON_LOADED,function(_,name)
    if name~="RolePlayMod" then return end
    if not B.saved then B.Initialize() end
    B.saved.reputationLedger=B.saved.reputationLedger or {}
    B.saved.hospitalityVenues=B.saved.hospitalityVenues or {}
    SLASH_COMMANDS["/ihrinn"]=function(args)
        if args=="remove" then
            local zone,x,y,z=GetUnitWorldPosition("player")
            for i=#B.saved.hospitalityVenues,1,-1 do
                local v=B.saved.hospitalityVenues[i]
                if v.zone==zone and (v.x-x)^2+(v.y-y)^2+(v.z-z)^2<=1000000 then table.remove(B.saved.hospitalityVenues,i) end
            end
            d("[RolePlayMod] Zone d’hospitalité manuelle retirée autour de vous.")
            return
        end
        B.RegisterVenue("Auberge ou restaurant enregistré manuellement")
        d("[RolePlayMod] Petite zone d’hospitalité enregistrée autour de vous. Utilisez cette commande uniquement à l’intérieur d’une auberge ou d’un restaurant.")
    end
    for _,entry in ipairs(B.saved.notebook) do
        if not entry.origin then entry.origin="ancien_journal" end
    end
    if B.saved.conversationPresentation==nil then B.saved.conversationPresentation=true end
    SLASH_COMMANDS["/ihrsleep"]=function() local _,text=L.Start();d("[RolePlayMod] "..text) end
    EVENT_MANAGER:UnregisterForEvent("IHRHospitalityInit",EVENT_ADD_ON_LOADED)
end)
