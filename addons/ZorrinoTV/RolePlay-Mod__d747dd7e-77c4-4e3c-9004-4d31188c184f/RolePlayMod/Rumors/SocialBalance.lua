if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Shared social personalities and context for dice and Speechcraft.
local R=RolePlayMod
local B=IHR_Runtime.Beta
local P=B.Personality
local D=B.Dice
local profile,behaviour,origin,confidence,initialize,line=P.Profile,P.Behaviour,B.OriginModifier,B.Confidence,B.Initialize,B.DialogueLine
local temperaments={radical={'orgueilleux','impatient','taciturne'},amical={'chaleureux','jovial'},indifferent={'reserve','professionnel','prudent'}}
local questActors={}
local function actor(name)
    if type(name)=='string' and B.NpcRaces.Find(name) then questActors[B.NpcRaces.NameKey(B.Name(name))]=true end
end
for _,name in pairs(IHR_QuestRumorDB.givers or {}) do actor(name) end
for _,q in pairs(IHR_RegionalKnowledgeData.quests or {}) do
    for _,record in ipairs(q.records or {}) do if record.kind=='person' then actor(record.target) end end
end
local legacy={chaleureux='avenant',jovial='avenant',professionnel='reserve',reserve='reserve',prudent='mefiant',taciturne='mefiant',orgueilleux='mefiant',impatient='presse'}
function P.Kind(p)
    if p.questActor or p.nativeInteraction or p.basis=='adaptation_documentee' or (p.doc and p.doc.voice) then return 'documente' end
    if p.groups and p.groups['veiled heritance'] then return 'radical' end
    return ({'radical','amical','indifferent'})[p.hash%3+1]
end
function P.Profile(npc)
    npc=npc or B.npc;if not npc then return profile(nil) end
    local p=profile(npc)
    p.questActor=not not questActors[B.NpcRaces.NameKey(B.Name(npc.name))]
    p.nativeInteraction=(npc.nativeInteraction==true) or (p.doc and p.doc.service and p.doc.service~='') or (B.saved and B.saved.nativePeople114 and B.saved.nativePeople114[p.id]) or false
    if B.Native and B.Native.IsConversing() and B.Name(GetUnitName('interact'))==npc.name then p.nativeInteraction=true end
    p.socialKind=P.Kind(p)
    if p.socialKind=='documente' and not (p.doc and p.doc.voice) then
        p.temperament='professionnel';p.legacy='reserve';p.traditional=not not (p.groups and p.groups['veiled heritance'])
    end
    local options=temperaments[p.socialKind]
    if options then
        p.temperament=options[math.floor(p.hash/3)%#options+1]
        p.legacy=legacy[p.temperament]
        p.traditional=p.socialKind=='radical'
    end
    return p
end
function P.Behaviour(npc)
    local kind=P.Kind(P.Profile(npc))
    if kind=='radical' then return 'hostile' end
    if kind=='amical' then return 'amical' end
    if kind=='indifferent' then return 'distant' end
    local p=P.Profile(npc)
    if p.temperament=='chaleureux' or p.temperament=='jovial' then return 'amical' end
    return behaviour(npc)
end
function B.OriginModifier(npc,p)
    local S=R.Speechcraft
    if S and S.ContextReport then return S.ContextReport(npc,P.Profile(npc)).points end
    return origin(npc,p)
end
function B.Confidence(npc)
    if not B.saved or B.saved.trustEnabled==false or B.saved.speechcraftEnabled==false then return 50 end
    local S=R.Speechcraft
    if not S or not S.ContextReport then return confidence(npc) end
    local p=P.Profile(npc);local kind=P.Kind(p)
    local initial=({radical=20,amical=50,indifferent=35})[kind] or 40
    local regional,fame,guild=P.Reputation(npc)
    if kind=='radical' then fame=0;guild=0 end
    local known=math.min(8,(regional or 0)*2)+math.min(2,fame or 0)+math.min(4,guild or 0)
    local progress=P.ReputationProgress and P.ReputationProgress(npc)
    if progress then known=math.floor(progress.points*P.ReputationSensitivity(npc)+.5)+math.min(2,fame or 0)+math.min(4,guild or 0) end
    local personal=P.PersonalBonus and P.PersonalBonus(npc) or 0
    local relationship=B.saved.personality160 and B.saved.personality160.people[p.id]
    local affinity=relationship and relationship.affinity or 0
    local help=P.ActivePersonalHelp and P.ActivePersonalHelp(npc) or 0
    -- Entrusting a mission establishes practical cooperation, not friendship.
    if help>0 then initial=math.max(initial,40) end
    local value=initial+S.ContextReport(npc,p).points*4+known+personal+affinity*5+B.CrimePenalty(npc)*4
    return math.max(0,math.min(100,math.floor(value)))
end
function B.DialogueLine(kind,npc)
    npc=npc or B.npc
    local S=R.Speechcraft
    if kind=='greeting' and npc and S and S.CommunityRecognition and S.CommunityRecognition(P.Profile(npc)) and (not P.PersonalBonus or P.PersonalBonus(npc)==0) then
        local mood=P.Behaviour(npc);local cat=B.IsKhajiitSpeaker(npc);local name=B.DialogueFirstName(npc)
        if mood=='hostile' then return cat and (name..' sait ce que vous avez fait pour les siens. Que voulez-vous ?') or 'Oui, je sais ce que vous avez fait pour les nôtres. Que voulez-vous ?' end
        if mood=='amical' then return cat and (name..' a entendu parler de votre aide ! Que peut-il pour vous ?') or 'Ah, c’est vous ! Merci pour votre aide. Que puis-je pour vous ?' end
        return cat and (name..' a entendu parler de votre aide. Que voulez-vous savoir ?') or 'On m’a parlé de votre aide. Que voulez-vous savoir ?'
    end
    if kind=='greeting' and npc and P.PersonalBonus and P.PersonalBonus(npc)>0 then
        local mood=P.Behaviour(npc);local cat=B.IsKhajiitSpeaker(npc);local name=B.DialogueFirstName(npc)
        if mood=='hostile' then return cat and (name..' vous a déjà vu. Qu’est-ce que vous voulez encore ?') or 'Encore vous ? Qu’est-ce qu’il vous faut ?' end
        if mood=='amical' then return cat and (name..' est heureux de vous revoir. Que peut-il pour vous ?') or 'Vous revoilà ! Qu’est-ce que je peux faire pour vous ?' end
        return cat and (name..' se souvient de vous. Que lui voulez-vous ?') or 'Vous aviez besoin d’autre chose ?'
    end
    return line(kind,npc)
end
function B.Initialize(...)
    local result=initialize(...)
    if B.saved and not B.saved.socialBalance112 then
        -- Old dice outcomes used the old DD/context. Keep all acquired clues.
        if B.saved.diceV1 then B.saved.diceV1.rolls={} end
        B.saved.socialBalance112=true
    end
    if B.saved and not B.saved.personalHelpBalance113 then
        -- Previous cached refusals were resolved without active quest cooperation.
        if B.saved.diceV1 then B.saved.diceV1.rolls={} end
        B.saved.personalHelpBalance113=true
    end
    if B.saved and not B.saved.communityBalance114 then
        for _,person in pairs(B.saved.personality160 and B.saved.personality160.people or {}) do person.daily=nil end
        if B.saved.diceV1 then B.saved.diceV1.rolls={} end
        B.saved.communityBalance114=true
    end
    return result
end

if EVENT_CHATTER_BEGIN then EVENT_MANAGER:RegisterForEvent('RPMNativePerson114',EVENT_CHATTER_BEGIN,function()
    if not B.saved or not B.Native or not B.Native.IsConversing() then return end
    local npc={name=B.Name(GetUnitName('interact')),race=GetUnitRace('interact'),zoneIndex=GetUnitZoneIndex('player'),locality=type(GetPlayerLocationName)=='function' and GetPlayerLocationName() or ''}
    local id=P.Profile(npc).id
    B.saved.nativePeople114=B.saved.nativePeople114 or {};B.saved.nativePeople114[id]=true
end) end
