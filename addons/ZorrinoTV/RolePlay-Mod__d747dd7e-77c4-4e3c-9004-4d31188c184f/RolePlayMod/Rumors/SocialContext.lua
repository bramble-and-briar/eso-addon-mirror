if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Contextual disposition: lore is sourced in the release notes; numbers and personalities are RP simulation.
local B=IHR_Runtime.Beta
local oldTrust,oldWilling,oldAttitude=B.EffectiveTrust,B.Willing,B.Attitude
local oldSocial,oldGreeting,oldPersuade=B.ShowSocial,B.Greeting,B.Persuade
local function choice(text,callback) return {text=text,callback=callback} end
local races={
    dunmer={"dunmer","elfe noir","elfe noire","dark elf"},
    altmer={"altmer","haut elfe","haute elfe","high elf"},
    bosmer={"bosmer","elfe des bois","wood elf"},
    argonian={"argonian","argonian female","argonien","argonienne"},
    khajiit={"khajiit","khajiite"},orc={"orc","orque","orsimer"},
    breton={"breton","bretonne"},redguard={"redguard","rougegarde"},
    nord={"nord","nordique"},imperial={"imperial","imperiale"},
}
function B.SocialRace(text)
    text=B.Normalize(text)
    for key,aliases in pairs(races) do for _,alias in ipairs(aliases) do if text==alias then return key end end end
end
-- Only the original alliance territories are inferred. DLC/neutral territories are not assigned by race.
local territories={
    dominion={"auridia","auridon","bois de graht","grahtwood","prasin","greenshade","malabal tor","marche de la camarde","reaper s march","perchoir de khenarthi","khenarthi s roost"},
    covenant={"glenumbrie","glenumbra","havre tempete","stormhaven","fendretour","rivenspire","desert d alik r","alik r desert","bangkorai","stros m kai","betnikh"},
    pact={"eboulis","stonefalls","deshaan","fangeombre","shadowfen","estemarche","eastmarch","la breche","the rift","morneroc","bleakrock isle","bal foyen"},
}
local function allianceKey(value)
    if ALLIANCE_ALDMERI_DOMINION and value==ALLIANCE_ALDMERI_DOMINION then return "dominion" end
    if ALLIANCE_DAGGERFALL_COVENANT and value==ALLIANCE_DAGGERFALL_COVENANT then return "covenant" end
    if ALLIANCE_EBONHEART_PACT and value==ALLIANCE_EBONHEART_PACT then return "pact" end
end
function B.SocialZone(npc)
    local index=npc and npc.zoneIndex or GetUnitZoneIndex("player")
    local id=type(GetZoneId)=="function" and GetZoneId(index) or index
    for _=1,5 do
        local story=type(GetZoneStoryZoneIdForZoneId)=="function" and GetZoneStoryZoneIdForZoneId(id) or 0
        if story and story>0 then id=story;break end
        local parent=type(GetParentZoneId)=="function" and GetParentZoneId(id) or 0
        if not parent or parent==0 or parent==id then break end
        id=parent
    end
    local name=type(GetZoneNameById)=="function" and GetZoneNameById(id) or ""
    if name=="" and type(GetZoneNameByIndex)=="function" then name=GetZoneNameByIndex(index) end
    return tostring(id),B.Normalize(name)
end
function B.Context(npc,profile)
    local result={points=0,reasons={}}
    if not B.saved.originInfluence then return result end
    local playerRace=B.SocialRace(type(GetUnitRace)=="function" and GetUnitRace("player") or "")
    local npcRace=B.SocialRace(npc.race or "")
    local _,zone=B.SocialZone(npc)
    local faction=allianceKey(npc.alliance)
    if not faction then
        for key,names in pairs(territories) do for _,name in ipairs(names) do if zone==name then faction=key end end end
    end
    local playerFaction=allianceKey(type(GetUnitAlliance)=="function" and GetUnitAlliance("player") or 0)
    local function add(points,reason) result.points=result.points+points;result.reasons[#result.reasons+1]=reason end
    if profile.hash%3==0 and faction and playerFaction then
        if faction~=playerFaction then add(-2,"Réserve envers une autre bannière.")
        else add(1,"Une bannière commune rassure cet interlocuteur.") end
    end
    if profile.traditional and playerRace and npcRace then
        if npcRace=="altmer" and playerRace~="altmer" and (zone=="le couchant" or zone=="summerset") then
            add(-2,"Cet habitant accepte mal l’ouverture de l’île aux étrangers.")
        end
        if playerRace==npcRace then add(1,"Une origine commune facilite ce premier contact.") end
        if npcRace=="argonian" and playerRace=="dunmer" then add(-3,"Le souvenir de l’esclavage pèse encore sur cet interlocuteur.") end
        if npcRace=="dunmer" and (playerRace=="argonian" or playerRace=="khajiit") then add(-3,"Cet interlocuteur conserve des préjugés hérités de l’esclavage.") end
        if npcRace=="khajiit" and playerRace=="dunmer" then add(-2,"Les razzias et l’esclavage ont laissé de la méfiance.") end
        if (npcRace=="orc" and playerRace=="breton") or (npcRace=="breton" and playerRace=="orc") then
            add(-2,"Les anciennes rivalités ne sont pas oubliées par tout le monde.")
        end
        if (npcRace=="nord" and playerRace=="dunmer") or (npcRace=="dunmer" and playerRace=="nord") then
            add(-1,"L’alliance n’a pas effacé toutes les anciennes rancœurs.")
        end
    end
    result.points=math.max(-5,math.min(2,result.points))
    return result
end
-- Replace the earlier special case for Dunmer in Grahtwood entirely.
function B.OriginModifier(npc,profile) return B.Context(npc,profile).points end

local lastBounty
function B.JusticeState()
    local legal=type(IsJusticeEnabledForZone)~="function" or IsJusticeEnabledForZone(GetUnitZoneIndex("player"))
    if type(IsJusticeEnabled)=="function" and not IsJusticeEnabled() then legal=false end
    local gold=type(GetFullBountyPayoffAmount)=="function" and GetFullBountyPayoffAmount() or 0
    local heat=type(GetPlayerInfamyData)=="function" and GetPlayerInfamyData() or 0
    local kill=type(IsKillOnSight)=="function" and IsKillOnSight() or false
    return {legal=legal,gold=math.max(0,tonumber(gold) or 0),heat=math.max(0,tonumber(heat) or 0),kill=kill}
end
function B.ObserveJustice()
    if not B.saved then return end
    local state=B.JusticeState()
    B.saved.socialCrime=B.saved.socialCrime or {}
    -- First observation is a baseline: an existing bounty is not falsely attributed to this region.
    if B.saved.enabled and B.saved.crimeInfluence~=false and lastBounty and state.legal and state.gold>lastBounty then
        local key=B.SocialZone()
        local now=GetTimeStamp()
        local entry=B.saved.socialCrime[key]
        local points=entry and math.max(0,entry.points-math.floor((now-entry.time)/21600)) or 0
        B.saved.socialCrime[key]={points=math.min(6,points+(state.gold-lastBounty>=1000 and 3 or 1)),time=now}
    end
    lastBounty=state.gold
end
function B.CrimePenalty(npc)
    if not B.saved or B.saved.crimeInfluence==false then return 0,"" end
    local role=B.Normalize(npc.caption or "")
    if role:find("receleur",1,true) or role:find("fence",1,true) then return 0,"" end
    local state=B.JusticeState()
    if not state.legal then return 0,"" end
    local active=state.kill and 9 or state.gold>=1000 and 6 or state.gold>=100 and 4 or state.gold>0 and 2 or 0
    if state.heat>0 then active=math.max(active,6) end
    local key=B.SocialZone(npc)
    local entry=B.saved.socialCrime and B.saved.socialCrime[key]
    local memory=entry and math.max(0,entry.points-math.floor((GetTimeStamp()-entry.time)/21600)) or 0
    return -math.max(active,memory),active>0 and "Recherché" or memory>0 and "Réputation ternie" or ""
end
function B.EffectiveTrust(npc)
    if not B.saved.speechcraftEnabled then return 20 end
    local penalty=B.CrimePenalty(npc)
    return oldTrust(npc)+penalty
end
function B.Willing(npc)
    if not B.saved.speechcraftEnabled then return true end
    local penalty=B.CrimePenalty(npc)
    if penalty<=-9 then return false end
    return oldWilling(npc)
end
function B.Attitude(npc)
    local text=oldAttitude(npc)
    local penalty,label=B.CrimePenalty(npc)
    return text..(B.saved.speechcraftEnabled and penalty<0 and (" · "..label) or "")
end
function B.ChangeTrust(npc,action,points)
    local relation=B.Relation(npc)
    if not relation then return false end
    local day=math.floor(GetTimeStamp()/86400)
    if relation.days[action]==day then return false end
    relation.days[action]=day
    relation.score=math.max(-20,math.min(20,relation.score+points))
    return true
end
function B.Persuade(npc)
    local success,text=oldPersuade(npc)
    if not success then B.ChangeTrust(npc,"failed-persuasion",-2) end
    return success,text
end
function B.SocialRefusal(npc)
    local penalty=B.CrimePenalty(npc)
    if penalty<=-6 then return "La garde vous cherche. Je ne tiens pas à être mêlé à vos affaires." end
    if penalty<0 then return "Avec ce qu’on raconte sur vous, je préfère garder mes distances." end
end
function B.Greeting(npc)
    local penalty=B.CrimePenalty(npc)
    if penalty<=-6 then return "Ne restez pas là. Je ne veux pas d’ennuis avec la garde." end
    return oldGreeting(npc)
end

local approaches={"Faire un compliment","Raconter une anecdote","Vanter ses exploits","Prendre un ton intimidant"}
local hints={"Semble apprécier cette approche.","Semble assez réceptif.","Semble peu réceptif.","Cette approche semble l’agacer."}
local reactions={
    {"Voilà qui fait plaisir à entendre.","Vous savez parler aux gens, vous."},
    {"Ma foi… pourquoi pas.","Je vois ce que vous voulez dire."},
    {"Vous pourriez changer de sujet ?","Ça ne m’intéresse pas vraiment."},
    {"Surveillez votre ton.","Vous commencez à me fatiguer."},
}
local function preferences(npc)
    local order={1,2,3,4}
    local h=B.Profile(npc).hash
    for i=4,2,-1 do local j=h%i+1;order[i],order[j]=order[j],order[i];h=math.floor(h/i) end
    return order
end
function B.SocialGame(npc,start)
    local r=B.Relation(npc)
    if not r then return nil end
    local day=math.floor(GetTimeStamp()/86400)
    if r.socialGame and r.socialGame.day==day then return r.socialGame end
    if not start then return nil end
    r.socialGame={day=day,turn=1,used={},total=0}
    return r.socialGame
end
function B.SocialOptions(npc,game)
    local result={};local pref=preferences(npc)
    for i=1,4 do
        if not game.used[i] then
            local strength=(i+game.turn+B.Profile(npc).hash%4)%4+1
            result[#result+1]={id=i,strength=strength,preference=pref[i],text=approaches[i].." — intensité "..strength.."/4. ("..hints[pref[i]]..")"}
        end
    end
    return result
end
function B.PlaySocial(npc,id,turn)
    if not B.saved.speechcraftEnabled or not B.saved.trustEnabled then return false end
    local game=B.SocialGame(npc,false)
    if not game or game.turn~=turn or game.turn>4 or game.used[id] or IsUnitInCombat("player") then return false end
    local selected
    for _,option in ipairs(B.SocialOptions(npc,game)) do if option.id==id then selected=option end end
    if not selected then return false end
    local weight=({2,1,-1,-2})[selected.preference]
    local magnitude=math.ceil(math.abs(weight)*selected.strength/2)
    local delta=weight>0 and magnitude or -magnitude
    local r=B.Relation(npc)
    local before=r.score
    r.score=math.max(-20,math.min(20,r.score+delta))
    delta=r.score-before
    game.used[id]=true;game.turn=game.turn+1;game.total=game.total+delta
    game.last=B.Line("social-"..id,reactions[selected.preference],npc)
    return true,delta
end
function B.ShowSocialGame(start)
    local npc=B.npc
    if not npc then return end
    if not B.saved.speechcraftEnabled or not B.saved.trustEnabled then
        B.Show("Faire connaissance","Activez les règles sociales et la confiance pour jouer.",{},true);return
    end
    local game=B.SocialGame(npc,start)
    if not game then
        B.Show("Prendre le temps de discuter","Un échange en quatre approches, chacune utilisable une fois. Observez ce qui semble plaire à votre interlocuteur : une approche forte peut autant le gagner que l’irriter. Les intensités tournent après chaque choix. Votre relation peut monter ou descendre.\n\nUn échange par PNJ et par jour réel. Vous pouvez l’interrompre et le reprendre, mais pas recommencer les choix déjà faits.",{
            choice("Engager l’échange.",function() B.ShowSocialGame(true) end),choice("Une autre fois.",function() B.ShowSocial() end),
        },true);return
    end
    local choices={}
    if game.turn<=4 then
        local turn=game.turn
        for _,option in ipairs(B.SocialOptions(npc,game)) do
            local id=option.id
            choices[#choices+1]=choice(option.text,function()
                if B.PlaySocial(npc,id,turn) then B.ShowSocialGame(false) end
            end)
        end
    end
    choices[#choices+1]=choice("Revenir à la conversation.",function() B.ShowHome() end)
    local text=game.last or "Je vous écoute."
    if game.turn>4 then text=text.."\n\n(Échange terminé. Bilan de relation : "..string.format("%+d",game.total)..".)"
    else text=text.."\n\n(Approche "..game.turn.."/4. Choisissez ce que vous voulez tenter.)" end
    B.Show("Faire connaissance",text,choices)
end
function B.ShowSocial()
    if not B.npc then return end
    -- Preserve the existing conversation tree and add the game before it.
    B.Show("Faire connaissance","Nous pouvons échanger quelques mots. À vous de voir comment aborder la conversation.",{
        choice("(Prendre le temps de discuter — mini-jeu.)",function() B.ShowSocialGame(false) end),
        choice("J’aimerais simplement me présenter.",function() oldSocial() end),
        choice("(Comprendre sa disposition.)",function()
            local context=B.Context(B.npc,B.Profile(B.npc))
            local penalty,label=B.CrimePenalty(B.npc)
            local lines={"Ces indications décrivent la simulation sociale de l’addon."}
            for _,reason in ipairs(context.reasons) do lines[#lines+1]=reason end
            if penalty<0 then lines[#lines+1]=label.." : la garde ou les nouvelles de vos méfaits rendent les gens prudents." end
            if #lines==1 then lines[#lines+1]="Aucun facteur d’origine ou de criminalité particulier n’intervient actuellement." end
            B.Show("Sa disposition",table.concat(lines,"\n\n"),{},true)
        end),
        choice("Je vous laisse.",function() B.ShowHome() end),
    })
end
EVENT_MANAGER:RegisterForEvent("IHRSocialContextInit",EVENT_ADD_ON_LOADED,function(_,name)
    if name~="RolePlayMod" then return end
    if not B.saved then B.Initialize() end
    if B.saved.crimeInfluence==nil then B.saved.crimeInfluence=true end
    B.ObserveJustice()
    if EVENT_JUSTICE_BOUNTY_PAYOFF_AMOUNT_UPDATED then
        EVENT_MANAGER:RegisterForEvent("IHRSocialCrime",EVENT_JUSTICE_BOUNTY_PAYOFF_AMOUNT_UPDATED,B.ObserveJustice)
    end
    EVENT_MANAGER:UnregisterForEvent("IHRSocialContextInit",EVENT_ADD_ON_LOADED)
end)
EVENT_MANAGER:RegisterForUpdate("IHRSocialCrimeWatch",1000,function() B.ObserveJustice() end)
