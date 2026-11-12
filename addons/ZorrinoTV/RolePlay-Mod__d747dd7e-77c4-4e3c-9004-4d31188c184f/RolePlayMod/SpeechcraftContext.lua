if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- A territory is not proof that its inhabitants belong to its ruling alliance.
local B=IHR_Runtime.Beta
local S=RolePlayMod.Speechcraft
local function bare(s) return B.Normalize(s or ''):gsub('^le ',''):gsub('^la ',''):gsub('^les ','') end
local function banner(id)
    if ALLIANCE_ALDMERI_DOMINION and id==ALLIANCE_ALDMERI_DOMINION then return 'dominion' end
    if ALLIANCE_DAGGERFALL_COVENANT and id==ALLIANCE_DAGGERFALL_COVENANT then return 'covenant' end
    if ALLIANCE_EBONHEART_PACT and id==ALLIANCE_EBONHEART_PACT then return 'pact' end
end
local bannerNames={dominion='Domaine aldmeri',covenant='Alliance de Daguefilante',pact='Pacte de Cœurébène'}
local territories={
    dominion={'auridia','auridon','bois de graht','grahtwood','prasin','greenshade','malabal tor','marche de la camarde','reaper s march','perchoir de khenarthi','khenarthi s roost','couchant','summerset'},
    covenant={'glenumbrie','glenumbra','havre tempete','stormhaven','fendretour','rivenspire','desert d alik r','alik r desert','bangkorai','stros m kai','betnikh'},
    pact={'eboulis','stonefalls','deshaan','fangeombre','shadowfen','estemarche','eastmarch','breche','rift','the rift','morneroc','bleakrock isle','bal foyen'},
}
local nativeRaces={dominion={altmer=true,bosmer=true,khajiit=true},covenant={breton=true,redguard=true,orc=true},pact={dunmer=true,nord=true,argonian=true}}
-- Explicit, source-backed group recognition. No racial or proximity guessing.
-- The native dialogue after 4395 welcomes the player among the Barkbite clan;
-- 4397/4398 are its direct sequels (ESOAZ north Grahtwood quest guide).
S.CommunityRecognitionRules={
    {id='barkbite-welcome',group='barkbite clan',label='Reconnu comme ami du clan Mordécorce',quests={4395,4397,4398},
     source='https://esoaz.com/2025/01/10/quetes-secondaires-bois-graht-nord-teso/'},
}
function S.CommunityRecognition(p)
    if p.socialKind=='radical' then return end -- Simulated hardliners reject collective recognition.
    if type(HasCompletedQuest)~='function' then return end
    for _,rule in ipairs(S.CommunityRecognitionRules) do
        if p.groups and p.groups[rule.group] then
            for _,id in ipairs(rule.quests) do if HasCompletedQuest(id) then return rule end end
        end
    end
end
function S.ContextReport(npc,p,traditional)
    local playerRace=type(GetUnitRace)=='function' and GetUnitRace('player') or ''
    local playerAlliance=type(GetUnitAlliance)=='function' and GetUnitAlliance('player') or 0
    local player=B.SocialRace(playerRace);local other=B.SocialRace(npc.race or '')
    local playerBanner=banner(playerAlliance)
    local _,zone=B.SocialZone(npc);zone=bare(zone)
    local r={points=0,initialPoints=0,recognition=0,race=0,alliance=0,community=0,territory=0,reasons={},playerRace=playerRace,
        playerAllianceId=playerAlliance,playerAllianceName=bannerNames[playerBanner] or ('non renseignée ('..tostring(playerAlliance)..')'),
        npcRace=npc.race or '',npcBanner=bannerNames[p.banner] or 'aucune appartenance documentée'}
    if not B.saved.originInfluence or p.neutral then return r end
    local function add(kind,value,reason) r[kind]=r[kind]+value;r.reasons[#r.reasons+1]=reason end
    if p.banner and playerBanner then
        if p.banner==playerBanner then add('alliance',1,'Appartenance commune documentée.')
        else add('alliance',-2,'Alliances opposées : appartenance du PNJ documentée.') end
    end
    local territory
    for key,names in pairs(territories) do for _,name in ipairs(names) do if zone==name then territory=key end end end
    if territory and player and not nativeRaces[territory][player] then
        add('territory',-1,'Réserve simulée envers une origine extérieure aux peuples locaux.')
    end
    if player and other then
        if player==other then add('race',1,'Une origine commune facilite le contact.') end
        local clan=false
        for group in pairs(p.groups or {}) do if group:find('clan',1,true) then clan=true end end
        local locality=bare(npc.locality)
        if other=='orc' and player~='orc' and (clan or locality=='mordecorce' or locality=='promontoire de reman') then
            add('community',-1,'Réserve de cette communauté orque envers un étranger au clan.')
        end
        if traditional or p.traditional then
            if (other=='argonian' or other=='khajiit') and player=='dunmer' then add('race',-3,'Préjugés liés à l’histoire de l’esclavage.') end
            if other=='dunmer' and (player=='argonian' or player=='khajiit') then add('race',-3,'Préjugés hérités de l’esclavage.') end
            if (other=='orc' and player=='breton') or (other=='breton' and player=='orc') then add('race',-2,'Anciennes rivalités entre Orques et Brétons.') end
            if (other=='nord' and player=='dunmer') or (other=='dunmer' and player=='nord') then add('race',-1,'Anciennes rancœurs entre Nordiques et Dunmers.') end
            if other=='altmer' and player~='altmer' and (zone=='couchant' or zone=='summerset') then add('race',-2,'Réserve traditionaliste face à l’ouverture du Couchant.') end
        end
    end
    if p.groups and p.groups['veiled heritance'] and player~='altmer' then add('community',-3,'Hostilité de l’Héritage voilé envers les étrangers.') end
    if p.groups and p.groups['veiled heritance'] and type(HasCompletedQuest)=='function' and HasCompletedQuest(4951) then
        add('community',-2,'L’Héritage voilé désapprouve votre soutien à la reine Ayrenn.')
    end
    local initial=r.race+r.alliance+r.community+r.territory
    r.initialPoints=math.max(-7,math.min(3,initial))
    local recognition=S.CommunityRecognition(p)
    if recognition then
        -- Explicit acceptance overrides the initial racial/community outsider
        -- assumptions here; it does not erase crime or an opposed political oath.
        r.recognition=-math.min(0,r.race)-math.min(0,r.community)-math.min(0,r.territory)
        r.recognitionId=recognition.id;r.recognitionLabel=recognition.label
        r.reasons[#r.reasons+1]=recognition.label..' : la méfiance initiale envers l’étranger est levée pour les membres documentés du clan.'
    end
    r.points=math.max(-7,math.min(3,initial+r.recognition))
    return r
end
