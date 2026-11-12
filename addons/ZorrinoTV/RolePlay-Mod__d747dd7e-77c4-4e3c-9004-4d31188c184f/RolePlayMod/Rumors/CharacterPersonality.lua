if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Stable individual temperament, sourced affiliations and simulated disposition.
local B=IHR_Runtime.Beta
local D=B.Dice
local P={};B.Personality=P
local oldProfile,oldReputation,oldOrigin,oldEffective=B.Profile,B.Reputation,B.OriginModifier,B.EffectiveTrust
local oldAttitude,oldLine,oldVoice=B.Attitude,B.DialogueLine,B.SpokenAnswer
local oldRoll,oldAsk,oldOpen,oldHome=D.Roll,D.Ask,B.Open,B.ShowHome
local docs={}
local function norm(s) return B.Normalize(type(s)=='string' and s or '') end
local function bare(s) return norm(s):gsub('^le ',''):gsub('^la ',''):gsub('^les ',''):gsub('^l ','') end
local function nameKey(s) return B.NpcRaces and B.NpcRaces.NameKey(s) or norm(s) end
local previousSocialRace=B.SocialRace
local khajiitForms={alfiq=true,['senche raht']=true,['cathay raht']=true,['pahmar raht']=true}
function B.SocialRace(text) return previousSocialRace(text) or (khajiitForms[norm(text)] and 'khajiit' or nil) end
local function copy(t) local out={};for k,v in pairs(t or {}) do out[k]=v end;return out end
local function enabled() return B.saved and B.saved.speechcraftEnabled~=false and B.saved.trustEnabled~=false end
for _,r in ipairs(IHR_CharacterData.records) do docs[r.source]=r end
local function selected(npc)
    local races=B.NpcRaces
    local context=races.Context(npc)
    local locality,region=bare(context.locality),bare(context.region)
    local best,score,source,ambiguous=nil,-1,nil,false
    for _,r in races.TitledRecords(npc.name) do
        local rank=0
        local localMatch,regionMatch=races.ScopeMatches(r,locality,region)
        if regionMatch then rank=rank+2 end
        if localMatch then rank=rank+3 end
        if rank>score then best=r;score=rank;source=r.source;ambiguous=false
        elseif rank==score and source~=r.source then ambiguous=true end
    end
    if best and not ambiguous then return docs[best.source],best.source end
end
local archetypes={'chaleureux','jovial','professionnel','reserve','prudent','taciturne','orgueilleux','impatient'}
local legacy={chaleureux='avenant',jovial='avenant',professionnel='reserve',reserve='reserve',prudent='mefiant',taciturne='mefiant',orgueilleux='mefiant',impatient='presse'}
local neutralGroups={['mages guild']=true,['fighters guild']=true,['undaunted']=true,['psijic order']=true}
local factionBanner={['aldmeri dominion']='dominion',['eyes of the queen']='dominion',['vinedusk rangers']='dominion',['thalmor']='dominion',['daggerfall covenant']='covenant',['lion guard']='covenant',['ebonheart pact']='pact'}
function P.Profile(npc)
    npc=npc or B.npc;if not npc then return {id='unknown',temperament='reserve',legacy='reserve',hash=0,groups={}} end
    local doc,source=selected(npc)
    local zone=B.SocialZone(npc)
    local generic=doc and doc.generic or not B.RelationKey(npc)
    local identity=source and (source..(generic and (':'..tostring(zone)..':'..bare(npc.locality)) or '')) or ('npc:'..tostring(zone)..':'..nameKey(npc.name)..':'..(generic and bare(npc.locality) or ''))
    local hash=B.Hash(identity)
    local temperament=doc and doc.voice or archetypes[hash%#archetypes+1]
    local groups,neutral,banner={},false,nil
    for _,f in ipairs(doc and doc.factions or {}) do
        local key=norm(f);groups[key]=true
        neutral=neutral or neutralGroups[key] or false;banner=banner or factionBanner[key]
    end
    local service=norm(doc and doc.service)
    if not (doc and doc.voice) and service~='' then temperament=hash%3==0 and 'chaleureux' or 'professionnel' end
    return {id=identity,hash=hash,temperament=temperament,legacy=legacy[temperament] or 'reserve',
        traditional=not neutral and (math.floor(hash/31)%4==0 or ((groups['house telvanni'] or groups['house dres']) and math.floor(hash/17)%3~=0) or groups['veiled heritance']) and not (doc and (doc.voice=='chaleureux' or doc.voice=='jovial') and not groups['veiled heritance']) or false,
        neutral=not not neutral,banner=banner,groups=groups,doc=doc,source=source,
        basis=doc and doc.voice and 'adaptation_documentee' or 'simulation_stable'}
end
function B.Profile(npc)
    local base=copy(oldProfile(npc));local p=P.Profile(npc)
    base.key=p.id;base.hash=p.hash;base.personality=p.legacy;base.traditional=p.traditional;base.temperament=p.temperament
    return base
end
local function state(npc)
    if not B.saved then return end
    B.saved.personality160=B.saved.personality160 or {people={}}
    local id=P.Profile(npc).id
    local people=B.saved.personality160.people
    people[id]=people[id] or {affinity=0,conversations=0}
    return people[id]
end
local repCache,repTime,repZones={},-1000,{}
local function rootForQuest(id)
    if type(GetQuestZoneId)~='function' or type(GetZoneIndex)~='function' then return end
    local zone=GetQuestZoneId(id)
    if not zone or zone<=0 then return end
    if repZones[zone]~=nil then return repZones[zone] or nil end
    local index=GetZoneIndex(zone)
    local root=index and index>0 and B.SocialZone({zoneIndex=index}) or nil
    repZones[zone]=root or false;return root
end
function P.Reputation(npc)
    if not B.saved or B.saved.reputationEnabled==false or type(HasCompletedQuest)~='function' then return 0,0 end
    local now=GetTimeStamp()
    if now-repTime>=60 then
        repCache={groups={}};local total=0
        for id,meta in pairs(IHR_QuestRumorDB.meta or {}) do
            if meta[2]==0 and not (IHR_QuestRumorDB.removed or {})[id] and HasCompletedQuest(id) then
                local zone=rootForQuest(id)
                local group=(IHR_CharacterData.questGroups or {})[id]
                if group then repCache.groups[group]=(repCache.groups[group] or 0)+1
                elseif zone then repCache[zone]=(repCache[zone] or 0)+1;total=total+1 end
            end
        end
        repCache.total=total;repTime=now
    end
    local region=B.SocialZone(npc)
    local localCount=repCache[region] or 0
    local guild=0
    for group,count in pairs(repCache.groups or {}) do
        if P.Profile(npc).groups[group] then guild=math.max(guild,math.min(4,math.floor(count/3))) end
    end
    return math.min(6,math.floor(localCount/4)),math.min(2,math.floor(math.max(0,(repCache.total or 0)-localCount)/60)),guild
end
function P.InvalidateReputation() repTime=-1000 end
function B.Reputation(npc)
    local points,lines=oldReputation(npc)
    if not B.saved or B.saved.reputationEnabled==false then return points,lines end
    local regional,fame,guild=P.Reputation(npc)
    local personal=0;local doc=P.Profile(npc).doc
    for _,id in ipairs(doc and doc.personalDeeds or {}) do if type(HasCompletedQuest)=='function' and HasCompletedQuest(id) then personal=2;break end end
    return math.min(12,math.max(points or 0,regional)+fame+(guild or 0)+personal),lines
end
local function playerBanner()
    local value=type(GetUnitAlliance)=='function' and GetUnitAlliance('player') or 0
    if ALLIANCE_ALDMERI_DOMINION and value==ALLIANCE_ALDMERI_DOMINION then return 'dominion' end
    if ALLIANCE_DAGGERFALL_COVENANT and value==ALLIANCE_DAGGERFALL_COVENANT then return 'covenant' end
    if ALLIANCE_EBONHEART_PACT and value==ALLIANCE_EBONHEART_PACT then return 'pact' end
end
function B.OriginModifier(npc,profile)
    local p=P.Profile(npc)
    if not B.saved or B.saved.originInfluence==false then return 0 end
    if p.neutral then return 0 end
    local originProfile=profile
    if p.banner and profile.hash%3==0 then originProfile=copy(profile);originProfile.hash=profile.hash+1 end
    local value=oldOrigin(npc,originProfile)
    local player=playerBanner()
    if p.banner and player then value=value+(p.banner==player and 1 or -2) end
    if p.groups['veiled heritance'] and B.SocialRace(type(GetUnitRace)=='function' and GetUnitRace('player') or '')~='altmer' then value=value-3 end
    if p.groups['veiled heritance'] and type(HasCompletedQuest)=='function' and HasCompletedQuest(4951) then value=value-3 end
    return math.max(-7,math.min(3,value))
end
function B.EffectiveTrust(npc)
    if not enabled() then return 0 end
    local value=oldEffective(npc)
    local p=P.Profile(npc);local s=state(npc)
    local affinity=s and s.affinity or 0
    -- Criminal ties soften social disapproval; native justice gameplay is untouched.
    local penalty=B.CrimePenalty(npc)
    if (p.groups['thieves guild'] or p.groups['dark brotherhood']) and penalty<0 then value=value-penalty*.5 end
    return value+affinity
end
function P.Behaviour(npc)
    local p=P.Profile(npc);local confidence=B.Confidence(npc)
    if confidence<25 then return (p.temperament=='orgueilleux' or p.temperament=='impatient') and 'hostile' or 'mefiant' end
    if confidence<40 then return p.temperament=='impatient' and 'hostile' or 'mefiant' end
    if confidence<60 then return 'distant' end
    if p.temperament=='chaleureux' or p.temperament=='jovial' then return 'amical' end
    return 'cooperatif'
end
function P.Negative(npc) local b=P.Behaviour(npc);return enabled() and (b=='hostile' or b=='mefiant') end
function P.Limited(npc)
    local s=state(npc);local q=s and s.daily
    return enabled() and q and q.expires>GetTimeStamp() and q.delivered or false
end
function P.CanAsk(npc,subject)
    if subject and subject.kind=='rumor' then return true end
    if not enabled() then return true end
    local s=state(npc);local q=s and s.daily
    if not q or q.expires<=GetTimeStamp() then return true end
    return not q.delivered and subject and q.subject==subject.key
end
function P.FinishAttempt(subject,result,npc)
    local s=state(npc);if not s then return end
    if s.daily and s.daily.subject==subject.key then s.daily.delivered=true end
    if not enabled() or not result or result.automatic then return end
    local now=GetTimeStamp()
    if not s.lastAffinity or now-s.lastAffinity>=86400 then
        local delta=result.success and .2 or P.Negative(npc) and -.2 or 0
        if delta~=0 then s.affinity=math.max(-2,math.min(2,(s.affinity or 0)+delta));s.lastAffinity=now end
    end
end
function D.Roll(subject,npc)
    if not P.CanAsk(npc,subject) then return nil,'Cet interlocuteur ne donnera plus de renseignement avant demain.' end
    local result,err,cached=oldRoll(subject,npc)
    if result then result.socialBehaviour=P.Behaviour(npc) end
    if result and subject.kind~='rumor' and P.Negative(npc) and RolePlayMod.Enabled('negativeQuota') and RolePlayMod.Enabled('dice') then
        local s=state(npc)
        if not s.daily or s.daily.expires<=GetTimeStamp() then s.daily={subject=subject.key,expires=GetTimeStamp()+86400,delivered=false} end
    end
    return result,err,cached
end
local ordinary={
 amical={
  greeting={'Bonjour ! Vous cherchez quelque chose ?','Bonjour. Dites-moi ce qui vous amène.','Vous avez l’air d’avoir une question. Je vous écoute.','Ah, bonjour ! Je peux vous renseigner ?','Vous cherchez votre chemin ?'},
  question={'Dites-moi, je vais essayer de vous aider.','Qu’aimeriez-vous savoir ?','Je vous écoute. Qu’est-ce qui vous manque ?'},
  refusal={'Navré, je ne peux pas vous aider davantage cette fois.','J’aurais aimé vous être plus utile. Essayez auprès de quelqu’un d’autre.','Je ne saurais pas vous guider davantage pour le moment.'},
  unknown={'Je ne connais pas assez cet endroit pour vous guider.','Ce nom ne me dit rien, je suis désolé.','Je n’ai rien entendu qui puisse vous aider là-dessus.'},
  finished={'Bonne route. J’espère que vous trouverez ce que vous cherchez.','Vous vouliez me demander autre chose ?','Prenez soin de vous.'},
  success={'','Bien sûr. ','Oui, regardez. ','Ah oui. ','Écoutez. ',''},
 },
 cooperatif={
  greeting={'Bonjour. De quoi avez-vous besoin ?','Vous avez une question ? Allez-y.','Dites-moi ce que vous cherchez.','Je peux vous renseigner. Que voulez-vous savoir ?'},
  question={'Soyez précis. Que cherchez-vous ?','Que voulez-vous savoir exactement ?','Dites-moi ce dont vous avez besoin.'},
  refusal={'Je préfère ne pas m’engager là-dessus.','Je ne peux pas vous en dire davantage pour l’instant.','Pour cette fois, il faudra demander à quelqu’un d’autre.'},
  unknown={'Je n’ai pas de renseignement fiable à vous donner.','Je ne connais pas cet endroit.','Je ne voudrais pas vous envoyer dans la mauvaise direction.'},
  finished={'Cela devrait vous aider.','Vous avez besoin d’autre chose ?','Bonne continuation.'},
  success={'','Écoutez. ','Oui. ','Bon, regardez. ',''},
 },
 distant={
  greeting={'Oui ?','Vous vouliez quelque chose ?','Je vous écoute.','Qu’y a-t-il ?','Une question ?'},
  question={'De quoi s’agit-il ?','Que cherchez-vous ?','Allez-y.'},
  refusal={'Je préfère garder cela pour moi.','Je n’ai rien à vous dire sur cette affaire.','Demandez ailleurs.'},
  unknown={'Je ne connais pas cet endroit.','Je n’en sais rien.','Ce nom ne me dit rien.'},
  finished={'C’est tout ?','Vous vouliez autre chose ?','Bonne route.'},
  success={'','Oui. ','Bon. ','Regardez. ',''},
 },
 mefiant={
  greeting={'Qu’est-ce que vous me voulez ?','Je ne vous connais pas. Faites vite.','Oui ? Restez-en aux faits.','Nous nous connaissons ?'},
  question={'Et qu’est-ce que vous cherchez, au juste ?','Choisissez bien votre question.','Je vous écoute, mais faites court.'},
  refusal={'Je ne vous connais pas assez pour me mêler de vos affaires.','Vous comprendrez que je garde mes renseignements pour moi.','Je n’ai aucune raison de me confier à vous.'},
  unknown={'Je n’en sais pas assez pour vous guider.','Je ne connais pas ce nom. Adressez-vous à quelqu’un d’autre.','Je ne pourrai pas vous aider sur ce point.'},
  finished={'Nous en avons terminé.','Je vous ai répondu.','Gardez cela pour vous.'},
  success={'Bon. Je vais vous répondre, mais je n’en dirai pas plus. ','Si cela vous suffit : ','Très bien. Écoutez, puis laissez-moi à mes affaires. '},
  daily={'Nous avons assez parlé. Revenez un autre jour.','Je vous ai accordé un renseignement. N’insistez pas davantage aujourd’hui.','Cela suffit pour aujourd’hui.'},
 },
 hostile={
  greeting={'Quoi ?','Qu’est-ce que vous voulez, encore ?','Faites vite. Je n’ai pas de temps pour vous.','Vous avez une bonne raison de me déranger ?'},
  question={'Une question. Pas davantage.','Allez, dites ce que vous voulez.','Qu’est-ce qu’il vous faut ?'},
  refusal={'Je ne vous dirai rien. Adressez-vous à quelqu’un d’autre.','Mes affaires ne vous regardent pas. Laissez-moi tranquille.','Vous n’obtiendrez rien de moi aujourd’hui.'},
  unknown={'Je n’en sais rien. Maintenant, laissez-moi tranquille.','Ce nom ne me dit rien. Cherchez ailleurs.','Je ne peux pas vous renseigner. Vous avez terminé ?'},
  finished={'Maintenant, allez-vous-en.','Nous en avons fini.','Laissez-moi tranquille.'},
  success={'Vous ne me laisserez donc pas tranquille… Très bien. ','Bon, prenez votre renseignement et laissez-moi à mes affaires. ','J’imagine que vous n’allez pas me lâcher sans une réponse. '},
  daily={'Pas un mot de plus aujourd’hui.','Je vous ai dit ce que j’avais à dire. Revenez un autre jour.','Assez. Je ne répondrai plus à vos questions aujourd’hui.'},
 },
}
local khajiit={
 amical={greeting={'{name} vous souhaite le bonjour. Que cherchez-vous ?','Vous avez une question pour {name} ?','{name} vous écoute avec plaisir.'},question={'Dites à {name} ce qui vous manque.','{name} fera de son mieux. Que cherchez-vous ?'},refusal={'{name} regrette de ne pas pouvoir vous aider davantage.','Pour cette fois, {name} ne pourra pas vous être utile.'},unknown={'{name} ne connaît pas cet endroit.','{name} n’a rien entendu à ce sujet.'},finished={'{name} vous souhaite bonne route.','Avez-vous encore besoin de {name} ?'},success={'{name} peut vous aider. ','{name} connaît une piste. '}},
 cooperatif={greeting={'{name} vous écoute. De quoi avez-vous besoin ?','Quelle question amène ce voyageur auprès de {name} ?'},question={'Dites à {name} ce que vous cherchez.','{name} vous écoute. Soyez précis.'},refusal={'{name} préfère ne pas se mêler de cette affaire.','{name} ne peut pas vous en dire davantage.'},unknown={'{name} n’a pas de renseignement sûr à vous donner.','Ce nom ne dit rien à {name}.'},finished={'Voilà ce que {name} peut vous dire.','{name} vous souhaite bonne chance.'},success={'Voici ce que {name} peut vous dire. ','{name} va vous orienter. '}},
 distant={greeting={'Oui ? {name} vous écoute.','Vous vouliez quelque chose à {name} ?'},question={'Que cherchez-vous auprès de {name} ?','{name} vous écoute.'},refusal={'{name} préfère garder cela pour lui.','{name} n’a rien à vous dire sur cette affaire.'},unknown={'{name} ne connaît pas cet endroit.','{name} n’en sait rien.'},finished={'Est-ce tout ce que vous vouliez demander à {name} ?','{name} retourne à ses affaires.'},success={'Très bien. {name} va vous répondre. ','Selon ce que sait {name} : '}},
 mefiant={greeting={'{name} ne vous connaît pas. Faites vite.','Que voulez-vous à {name} ?'},question={'{name} vous écoute. Une question seulement.','Que cherchez-vous, au juste ? {name} attend.'},refusal={'{name} ne vous connaît pas assez pour se confier.','La confiance de {name} ne se gagne pas en quelques mots.'},unknown={'{name} ne connaît pas ce nom. Demandez ailleurs.','{name} ne peut pas vous guider sur ce point.'},finished={'{name} en a assez dit.','Gardez les paroles de {name} pour vous.'},success={'{name} va vous répondre, mais n’en dira pas plus. ','Écoutez {name}, puis laissez-le à ses affaires. '},daily={'{name} a assez parlé pour aujourd’hui.','Ne demandez plus rien à {name} aujourd’hui.'}},
 hostile={greeting={'Quoi ? {name} n’a pas de temps à perdre.','Pourquoi déranger {name} ?'},question={'Une seule question. La patience de {name} est courte.','{name} attend. Faites vite.'},refusal={'{name} ne vous dira rien. Partez.','Vous n’obtiendrez rien de {name} aujourd’hui.'},unknown={'{name} ne sait pas. Cherchez ailleurs.','Ce nom ne dit rien à {name}. Laissez-le tranquille.'},finished={'Maintenant, laissez {name} tranquille.','{name} en a terminé avec vous.'},success={'Vous ne laisserez donc pas {name} tranquille… Écoutez bien. ','Prenez le renseignement de {name}, puis partez. '},daily={'Pas un mot de plus aujourd’hui. {name} en a terminé.','Revenez un autre jour. {name} n’a plus rien à vous dire.'}},
}
local titles={le=true,la=true,les=true,capitaine=true,commandant=true,commandante=true,maitre=true,maitresse=true,roi=true,reine=true,prince=true,princesse=true,seigneur=true,dame=true,grand=true,grande=true,haut=true,haute=true,general=true,generale=true,conservateur=true,conservatrice=true}
function B.DialogueFirstName(npc)
    local words={};for w in B.Name(npc and npc.name or ''):gmatch('[^ \t\r\n]+') do words[#words+1]=w end
    local i=1;while words[i] and titles[norm(words[i])] do i=i+1 end
    return words[i] or 'Ce Khajiit'
end
local function pick(kind,lines,npc,subject)
    local p=P.Profile(npc);local s=state(npc)
    local identity=p.id..':'..kind..':'..math.floor(GetTimeStamp()/86400)..':'..tostring(s and s.conversations or 0)..':'..tostring(subject and subject.key or '')
    return (lines[B.Hash(identity)%#lines+1]:gsub('{name}',B.DialogueFirstName(npc)))
end
local racePlurals={dunmer='Elfes noirs',altmer='Hauts-Elfes',bosmer='Elfes des bois',argonian='Argoniens',khajiit='Khajiits',orc='Orques',breton='Brétons',redguard='Rougegardes',nord='Nordiques',imperial='Impériaux'}
function P.Refusal(npc)
    local khajiitSpeaker=B.IsKhajiitSpeaker(npc)
    local who=B.DialogueFirstName(npc)
    if B.CrimePenalty(npc)<=-6 then
        return khajiitSpeaker and (who..' ne veut pas d’ennuis avec la garde. Demandez ailleurs.') or 'La garde vous cherche. Je ne tiens pas à être mêlé à vos affaires.'
    end
    if not P.Negative(npc) or B.OriginModifier(npc,B.Profile(npc))>=0 then return end
    local p=P.Profile(npc)
    local player=B.SocialRace(type(GetUnitRace)=='function' and GetUnitRace('player') or '')
    local own=B.SocialRace(npc.race or '')
    if p.groups['veiled heritance'] and type(HasCompletedQuest)=='function' and HasCompletedQuest(4951) then
        return khajiitSpeaker and (who..' sait que vous avez servi la reine. Cela ne lui inspire pas confiance.') or 'Vous avez servi la reine. N’attendez pas pour autant ma confiance.'
    end
    if p.groups['veiled heritance'] and player and player~='altmer' then
        return khajiitSpeaker and (who..' ne confie pas les affaires des siens aux '..(racePlurals[player] or 'étrangers')..'.') or ('Je ne confie pas nos affaires aux '..(racePlurals[player] or 'étrangers')..'. Nos traditions ne vous regardent pas.')
    end
    if p.traditional and player=='dunmer' and (own=='argonian' or own=='khajiit') then
        return khajiitSpeaker and (who..' n’oublie pas ce que les razzias ont coûté aux siens. '..who..' préfère se taire.') or 'Les miens n’ont pas oublié l’esclavage. Ma confiance ne se gagne pas en quelques mots.'
    end
    if p.traditional and own=='dunmer' and (player=='argonian' or player=='khajiit') then
        return 'Je garde les affaires des miens pour les miens. Adressez-vous à quelqu’un d’autre.'
    end
    local banner=playerBanner()
    if p.banner and banner and p.banner~=banner then
        return khajiitSpeaker and (who..' ne connaît pas vos intentions. Vos bannières ne sont pas les mêmes.') or 'Votre bannière n’est pas la mienne. Je préfère garder cela pour moi.'
    end
end
function B.DialogueLine(kind,npc)
    npc=npc or B.npc;if not npc then return oldLine(kind,npc) end
    local behaviour=P.Behaviour(npc)
    if kind=='refusal' then local reason=P.Refusal(npc);if reason then return reason end end
    if kind=='greeting' and (behaviour=='amical' or behaviour=='cooperatif' or behaviour=='distant') then
        local temperament=P.Profile(npc).temperament
        if temperament=='jovial' then
            return pick(kind,B.IsKhajiitSpeaker(npc) and {'Une question pour {name} ? Voilà qui change des ennuis ordinaires.','{name} vous écoute. Qu’est-ce qui vous amène par ici ?'} or {'Alors, qu’est-ce qui vous amène par ici ?','Vous avez l’air d’avoir une question. Je me trompe ?','Une question ? Allons, je vous écoute.'},npc)
        elseif temperament=='orgueilleux' then return pick(kind,B.IsKhajiitSpeaker(npc) and {'Vous avez l’attention de {name}. Exposez votre demande.','{name} vous écoute. Soyez précis.'} or {'Vous avez mon attention. Que souhaitez-vous savoir ?','Très bien. Exposez votre demande.'},npc) end
    end
    if kind=='crime' then
        return B.IsKhajiitSpeaker(npc) and (B.DialogueFirstName(npc)..' ne veut pas d’ennuis avec la garde. Faites vite.') or 'La garde vous cherche. Faites vite, je ne tiens pas à avoir des ennuis.'
    end
    if kind=='no_news' then
        local lines=B.IsKhajiitSpeaker(npc) and {'{name} n’a rien entendu d’autre.','C’est tout ce que {name} sait pour le moment.'} or {'Je n’ai rien entendu d’autre.','C’est tout ce que je sais pour le moment.','Non, rien d’autre ne me vient à l’esprit.'}
        return pick(kind,lines,npc)
    end
    local bank=B.IsKhajiitSpeaker(npc) and khajiit or ordinary
    local lines=bank[behaviour][kind] or (kind=='daily' and bank.mefiant.daily) or bank.distant[kind]
    if not lines then return oldLine(kind,npc) end
    return pick(kind,lines,npc)
end
function B.SpokenAnswer(subject,text,npc,result)
    if not text or text=='' then return text end
    if subject and subject.kind=='rumor' and subject.rumorVoiced then return text end
    npc=npc or B.npc
    if not npc then return text end
    -- A documented request for help overrides an old simulated temperament.
    -- The answer is supplied by the quest's knowledge gate, not by this voice.
    if result and result.cooperative then return text end
    local behaviour=result and result.socialBehaviour or P.Behaviour(npc)
    -- A simulated recollection adds everyday life, while the location remains
    -- the sourced answer. Never embellish a known quest speaker's own account.
    local task=subject and subject.task
    local target=task and D.EffectiveGeographicTargetFR and D.EffectiveGeographicTargetFR(task)
    local function entityKey(name)
        return B.Normalize(name or ''):gsub('^les ',''):gsub('^des ',''):gsub('^le ',''):gsub('^la ',''):gsub('^l ','')
    end
    -- The current question may concern a town/person learned from a previous
    -- answer, even though its parent quest condition still says "collect".
    local asksAboutHarvest=subject and target and subject.targetKind=='object'
        and entityKey(subject.target)~='' and entityKey(subject.target)==entityKey(target.name)
    if subject and subject.routeVoiced and asksAboutHarvest and target.kind=='object'
        and ({cueillez=true,recoltez=true,ramassez=true,collectez=true})[target.action]
        and (behaviour=='amical' or behaviour=='cooperatif' or behaviour=='distant') then
        local lines=B.IsKhajiitSpeaker(npc) and {
            '{name} croit en avoir aperçu en passant dans le coin. ',
            'Cela rappelle à {name} une de ses promenades. ',
            '{name} en aurait bien vu au cours de ses allées et venues. ',
        } or {'Il me semble en avoir aperçu lors d’une promenade. ',
            'J’en ai peut-être vu en passant dans le coin. ',
            'Ça me rappelle quelque chose. J’en ai croisé en chemin, je crois. '}
        text=pick('souvenir-recolte',lines,npc,subject)..text
    end
    -- RouteVoice already supplies complete human/Khajiit sentences. A second
    -- introduction is unnecessary, but reluctant people still sound reluctant.
    if subject and subject.routeVoiced then
        local ordinaryEndings={
            mefiant={'C’est tout ce que je vous dirai.','N’en demandez pas davantage.','Gardez cela pour vous.','Voilà. Je n’en dirai pas plus.'},
            hostile={'Maintenant, laissez-moi tranquille.','Voilà. Fichez-moi la paix.','Vous avez votre réponse. Allez.','Et ne venez pas m’importuner davantage.'},
        }
        local khajiitEndings={
            mefiant={'{name} n’en dira pas plus.','Ne demandez rien de plus à {name}.','Gardez les paroles de {name} pour vous.','C’est tout ce que {name} vous dira.'},
            hostile={'Maintenant, laissez {name} tranquille.','{name} vous a répondu. Partez.','Ne venez plus importuner {name}.','Vous avez le renseignement de {name}. Allez.'},
        }
        local lines=(B.IsKhajiitSpeaker(npc) and khajiitEndings or ordinaryEndings)[behaviour]
        return lines and (text..' '..pick('route-close',lines,npc,subject)) or text
    end
    local bank=B.IsKhajiitSpeaker(npc) and khajiit or ordinary
    return pick('success',bank[behaviour].success,npc,subject)..text
end
-- A successful cooperation test does not confer geographical knowledge.
-- Never claim not to know an entire place merely because indoor detail is unavailable.
function P.UnknownResponse(npc,subject,result)
    local behaviour=result and result.socialBehaviour or P.Behaviour(npc)
    -- Ignorance alone provides no destination. Never gesture "over there"
    -- unless we can name a documented contact AND say where to find them.
    local fact=subject and subject.task and D.GeographicHintFR and select(2,D.GeographicHintFR(subject.task))
    local contact=fact and fact.speaker
    local person=contact and B.GeographicKnowledge.Person(contact,subject.task)
    local where=person and (person.city or person.site)
    local same=contact and B.RegionalKnowledge and B.RegionalKnowledge.SamePerson(contact,npc.name)
    if contact and where and not same and B.Normalize(contact)~=B.Normalize(npc.name) and result then
        local place=B.GeographicKnowledge.Place(where,subject.task)
        if place or B.PublicPlace(where) then
            local direction=B.GeographicKnowledge.PlaceAnswer(where,subject.task)
            local location=(B.RouteVoice and B.RouteVoice.At(where)) or ('à '..where)
            result.referral={name=contact,answer=contact..' se trouve '..location..'.'..(direction and (' '..direction) or '')}
            return pick('renvoi-documente',B.IsKhajiitSpeaker(npc) and {
                '{name} ne sait pas. Essayez auprès de '..contact..', '..location..'.',
            } or {'Je ne saurais pas vous dire. Demandez plutôt à '..contact..', '..location..'.'},npc,subject)
        end
    end
    local plain={
        amical={'Je suis désolé, je ne saurais pas vous dire.','J’aimerais vous aider, mais je ne vois pas où chercher.','Ça ne me dit rien, désolé.'},
        cooperatif={'Je ne sais pas où chercher exactement.','Je n’ai jamais rien vu de tel, désolé.','Je ne saurais pas vous renseigner.'},
        distant={'Pas la moindre idée.','Je n’en sais rien.','Ça ne me dit rien.'},
        mefiant={'Je n’en sais pas davantage.','Je ne peux pas vous renseigner.','Je ne sais pas.'},
        hostile={'J’en sais rien. Laissez-moi tranquille.','Aucune idée. Maintenant, laissez-moi.','Je sais pas. Fichez-moi la paix.'},
    }
    local cats={
        amical={'{name} est désolé, mais ne sait pas où chercher.','{name} aimerait vous aider. Hélas, cela ne lui dit rien.'},
        cooperatif={'{name} ne saurait pas vous renseigner.','{name} ne sait pas où chercher exactement.'},
        distant={'{name} n’en sait rien.','Cela ne dit rien à {name}.'},
        mefiant={'{name} ne peut pas vous renseigner.','{name} ne sait pas.'},
        hostile={'{name} n’en sait rien. Laissez-le tranquille.','{name} ne sait pas. Cessez de l’importuner.'},
    }
    return pick('ignorance-sans-destination',(B.IsKhajiitSpeaker(npc) and cats or plain)[behaviour] or plain.distant,npc,subject)
end
function P.FactualAnswer(result,npc,subject)
    if subject and (subject.kind=='service' or subject.kind=='rumor') then return result.answer end
    local text=result.factualAnswer or result.answer
    if not result.factualAnswer and B.IsKhajiitSpeaker(npc) then
        local name=B.DialogueFirstName(npc)
        local legacyName=B.Name(npc.name):match('^([^ ]+)') or name
        for _,prefix in ipairs({name..' connaît le chemin. ',name..' peut vous renseigner. ',legacyName..' connaît le chemin. ',legacyName..' peut vous renseigner. '}) do if text and text:sub(1,#prefix)==prefix then text=text:sub(#prefix+1);break end end
    end
    return text
end
function B.Attitude(npc)
    local dd,confidence=D.Difficulty(npc)
    local labels={amical='Amical',cooperatif='Coopératif',distant='Distant',mefiant='Méfiant',hostile='Hostile'}
    local penalty,crime=B.CrimePenalty(npc)
    return string.format('Confiance : %d/100 · %s · DD %d',confidence,labels[P.Behaviour(npc)],dd)..(penalty<0 and (' · '..crime) or '')
end
function P.EnterConversation()
    if P.newConversation and B.npc then local s=state(B.npc);s.conversations=(s.conversations or 0)+1;P.newConversation=false end
end
function B.ShowHome(...)
    P.EnterConversation()
    if B.npc and P.Limited(B.npc) then
        local choices={}
        if B.IsInnkeeper(B.npc) and B.Lodging.Available() then choices[#choices+1]={text='Je voudrais vous louer une chambre.',callback=function() B.ShowLodging() end} end
        choices[#choices+1]={text='(Consulter mon carnet.)',callback=function() B.ShowNotebook() end}
        B.Show('Conversation',B.DialogueLine('daily'),choices);return
    end
    return oldHome(...)
end
function B.Open(...)
    P.newConversation=true;local result=oldOpen(...);P.newConversation=false;return result
end
function D.Ask(subject)
    if B.npc and not P.CanAsk(B.npc,subject) then
        B.Show('Conversation',B.DialogueLine('daily'),{{text='Très bien. Je vous laisse.',callback=function() B.ShowHome() end}});return
    end
    return oldAsk(subject)
end
if EVENT_MANAGER then
    for _,event in ipairs({EVENT_QUEST_COMPLETE,EVENT_QUEST_ADDED,EVENT_QUEST_REMOVED}) do
        if event then EVENT_MANAGER:RegisterForEvent('IHRPersonalityReputation'..event,event,P.InvalidateReputation) end
    end
end
