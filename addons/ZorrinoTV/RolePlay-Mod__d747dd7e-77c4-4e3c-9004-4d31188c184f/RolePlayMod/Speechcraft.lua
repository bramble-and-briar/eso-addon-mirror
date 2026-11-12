if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Independent trust state. Existing profiles/world facts are read, never rewritten.
local R=RolePlayMod
local B=IHR_Runtime.Beta
local P=B.Personality
local S={};R.Speechcraft=S
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function norm(x) return B.Normalize(x or '') end
S.actions={'Admirer','Plaisanter','Intimider','Se vanter'}
S.reactions={'Adore','Apprécie','Déteste','N’aime pas'}
S.factors={3,1,-3,-1}
S.defaults={baseCap=50,persuasiveBonus=15,intimidationBonus=10,clemencyBonus=5,haggling={3,6,9,12},reputation={5,10,15,20},
 decayInterval=4,persuasiveInterval=7,decayAmount=1,threshold=40}
function S.Enabled() return R.Options().roleplayMode=='speechcraft' end
function S.Saved()
    R.Initialize();R.saved.speechcraftV1=R.saved.speechcraftV1 or {people={},config=R.Copy(S.defaults)}
    local data=R.saved.speechcraftV1;data.people=data.people or {};data.config=data.config or {}
    for k,v in pairs(S.defaults) do
        if data.config[k]==nil then data.config[k]=R.Copy(v)
        elseif type(v)=='table' then for i,value in pairs(v) do if data.config[k][i]==nil then data.config[k][i]=value end end end
    end
    if not data.timer112 then data.config.decayInterval=4;data.config.persuasiveInterval=7;data.timer112=true end
    return data
end
function S.Config() return S.Saved().config end
function S.SetConfig(key,value,rank)
    if S.Wheel then S.Wheel.Hide() end
    if rank then S.Config()[key][rank]=value else S.Config()[key]=value end
    B.Close()
end
-- Client FR ability IDs. Only actually purchased ranks count, not skill-line level.
local ids={persuasive={29061},intimidation={29062},clemency={76451},haggling={76458,76459,76460,76461}}
function S.InvalidateSkills() S.skillFrame=nil;if S.InvalidateSocialReport then S.InvalidateSocialReport() end end
function S.Skills()
    local frame=GetFrameTimeMilliseconds()
    if S.skillFrame==frame and S.skillSnapshot then return S.skillSnapshot end
    local result={available=type(GetSpecificSkillAbilityKeysByAbilityId)=='function' and type(IsSkillAbilityPurchased)=='function'}
    for name,list in pairs(ids) do
        local rank=0
        if result.available then for _,id in ipairs(list) do
            local kind,line,index=GetSpecificSkillAbilityKeysByAbilityId(id)
            if kind and line and index and line>0 and index>0 and IsSkillAbilityPurchased(kind,line,index) then
                local purchased=type(GetSkillAbilityUpgradeInfo)=='function' and GetSkillAbilityUpgradeInfo(kind,line,index) or nil
                rank=math.max(rank,tonumber(purchased) or (name=='haggling' and 0 or 1))
            end
        end end
        result[name]=clamp(rank,0,name=='haggling' and 4 or 1)
    end
    S.skillFrame=frame;S.skillSnapshot=result
    return result
end
local personality={chaleureux=8,jovial=5,professionnel=2,reserve=0,prudent=-5,taciturne=-6,orgueilleux=-6,impatient=-8}
function S.Stubborn(npc,p)
    p=p or P.Profile(npc)
    return P.Kind(p)=='radical'
end
function S.FirstTrust(npc,p)
    p=p or P.Profile(npc)
    -- Fame, completed quests and purchased skills can raise a ceiling, but
    -- never grant an unknown villager an already intimate personal relation.
    local first=({radical=15,amical=30,indifferent=25})[P.Kind(p)] or 25
    local personal=P.PersonalBonus and P.PersonalBonus(npc) or 0
    local help=P.ActivePersonalHelp and P.ActivePersonalHelp(npc) or 0
    local minimum=help>0 and (help>=8 and 40 or 35) or 5
    return clamp(first+math.floor((personality[p.temperament] or 0)/2)+S.ContextReport(npc,p).points*2+B.CrimePenalty(npc)*2+personal/2,minimum,personal>0 and 50 or 35)
end
function S.Report(npc)
    local p=P.Profile(npc);local config=S.Config();local skills=S.Skills()
    local doc=p.doc;local custom=doc and doc.speechcraft or {}
    local sensitivity=custom.reputationSensitivity
    if sensitivity==nil then
        sensitivity=doc and doc.service and doc.service~='' and 1 or p.traditional and .25 or p.neutral and .75 or .5
    end
    if P.ReputationSensitivity then sensitivity=P.ReputationSensitivity(npc) end
    sensitivity=clamp(tonumber(sensitivity) or .5,0,1)
    local regional,fame,guild=P.Reputation(npc)
    if P.Kind(p)=='radical' then fame=0;guild=0 end
    local tier=clamp(math.floor(regional or 0),0,4)
    local raw=tier>0 and config.reputation[tier] or 0
    local progress=P.ReputationProgress and P.ReputationProgress(npc)
    if progress then raw=progress.points end
    local applied=math.floor(raw*sensitivity+.5)
    local contextInfo=S.ContextReport(npc,p)
    local context=contextInfo.points*5
    local crime=B.CrimePenalty(npc)*5
    if p.groups['thieves guild'] or p.groups['dark brotherhood'] then crime=crime*.5 end
    local personal,_,_,_,help
    if P.PersonalBonus then personal,_,_,_,help=P.PersonalBonus(npc) end
    personal=personal or 0
    if help==nil then help=P.ActivePersonalHelp and P.ActivePersonalHelp(npc) or 0 end
    local bonuses={
        persuasive=skills.persuasive>0 and config.persuasiveBonus or 0,
        intimidation=skills.intimidation>0 and config.intimidationBonus or 0,
        clemency=skills.clemency>0 and config.clemencyBonus or 0,
        haggling=skills.haggling>0 and config.haggling[skills.haggling] or 0,
    }
    local before=config.baseCap+context+(personality[p.temperament] or 0)+crime+applied+personal+(fame or 0)*2+(guild or 0)*3
    for _,value in pairs(bonuses) do before=before+value end
    local hard=custom.maxTrust
    local stubborn=S.Stubborn(npc,p)
    local race=B.SocialRace(GetUnitRace('player'))
    if custom.maxTrustByRace and custom.maxTrustByRace[race] then hard=math.min(hard or 100,custom.maxTrustByRace[race]) end
    -- A documented faction plus this individual's established traditionalism justifies
    -- this RP limit. Never fabricate an unnamed NPC's biography or former slavery.
    if p.traditional and p.groups['veiled heritance'] and race~='altmer' then hard=math.min(hard or 100,55) end
    -- Hatred is a persistent attitude, not an impossible persuasion ceiling.
    -- Keep the cooperation threshold reachable through the wheel.
    local reachable=config.threshold+(stubborn and 15 or P.Kind(p)=='amical' and -10 or 0)
    return {cap=clamp(math.floor(math.min(math.max(before,reachable),hard or 100)),0,100),before=before,hardCap=hard,stubborn=stubborn,cooperationFloor=reachable,
        activeHelp=help,base=config.baseCap,context=context,contextInfo=contextInfo,personality=personality[p.temperament] or 0,crime=crime,
        reputationProgress=progress,reputationRaw=raw,reputationSensitivity=sensitivity,reputationApplied=applied,personal=personal,
        fame=(fame or 0)*2,guild=(guild or 0)*3,skills=skills,bonuses=bonuses,profile=p}
end
-- Only the active wheel reuses the expensive world/quest report. Actual trust
-- remains mutable, is saved immediately and is never cached with this report.
function S.InvalidateSocialReport()
    if S.active then S.active.report=nil;S.active.reportAt=nil end
end
local calculateReport=S.Report
function S.Report(npc)
    local active=S.active;local now=GetFrameTimeMilliseconds()
    if active and active.npc==npc and active.report and active.reportAt and now>=active.reportAt and now-active.reportAt<1000 then return active.report end
    local report=calculateReport(npc)
    if active and S.active==active and active.npc==npc then active.report=report;active.reportAt=now end
    return report
end
local orders={chaleureux={1,2,4,3},jovial={2,1,4,3},professionnel={1,4,2,3},reserve={1,2,3,4},
 prudent={1,2,4,3},taciturne={4,1,2,3},orgueilleux={1,3,2,4},impatient={3,4,1,2}}
function S.State(npc)
    local p=P.Profile(npc);local people=S.Saved().people
    if not people[p.id] then
        local order=orders[p.temperament] or orders.reserve;local preferences={}
        -- The middle pair varies by identity while likes/dislikes remain deterministic.
        local copy={unpack(order)};if p.hash%2==1 then copy[2],copy[3]=copy[3],copy[2] end
        local levels={1,2,4,3}
        for i,action in ipairs(copy) do preferences[action]=levels[i] end
        if p.doc and p.doc.speechcraft and p.doc.speechcraft.preferences then
            local custom=p.doc.speechcraft.preferences;local valid,seen=true,{}
            for id=1,4 do local level=custom[id];if type(level)~='number' or level<1 or level>4 or seen[level] then valid=false else seen[level]=true end end
            if valid then preferences=R.Copy(custom) end
        end
        people[p.id]={trust=S.FirstTrust(npc,p),known={},preferences=preferences,rounds=0,personalTrust112=true,activeAid113=P.ActivePersonalHelp and P.ActivePersonalHelp(npc) or 0}
    end
    local state=people[p.id];state.known=state.known or {}
    if not state.personalTrust112 then
        -- Rebase only untouched legacy relations; retain every played wheel.
        if not state.game and (state.rounds or 0)==0 and not next(state.known) then state.trust=S.FirstTrust(npc,p) end
        state.personalTrust112=true
    end
    local report=S.Report(npc)
    local help=report.activeHelp or 0
    local applied=state.activeAid113 or 0
    if help>applied then
        -- Award each relationship milestone once; closing, reopening or
        -- abandoning/reaccepting cannot repair losses from the wheel.
        state.trust=math.max((state.trust or 0)+(help-applied),help>=8 and 40 or 35)
        state.activeAid113=help
    end
    local context=report.contextInfo
    state.communityRecognitions114=state.communityRecognitions114 or {}
    if context.recognitionId and not state.communityRecognitions114[context.recognitionId] then
        state.trust=(state.trust or 0)+(context.recognition or 0)*5
        state.communityRecognitions114[context.recognitionId]=true
    end
    local cap=report.cap
    state.trust=clamp(math.floor(tonumber(state.trust) or 50),0,cap)
    return state,report
end
function S.Current(npc) return S.State(npc).trust end
function S.CanPersuade(npc)
    if not S.Enabled() or not npc then return false end
    local state,report=S.State(npc)
    return state.trust<report.cap
end
function S.Behaviour(npc)
    local kind=P.Kind(P.Profile(npc))
    if kind=='radical' then return 'hostile' end
    if kind=='amical' then return 'amical' end
    if kind=='indifferent' then return 'distant' end
    local personality=P.Profile(npc).temperament
    if personality=='chaleureux' or personality=='jovial' then return 'amical' end
    local value=S.Current(npc)
    if value<20 then return 'hostile' elseif value<40 then return 'mefiant' elseif value<60 then return 'distant' end
    local p=P.Profile(npc)
    return (p.temperament=='chaleureux' or p.temperament=='jovial') and 'amical' or 'cooperatif'
end
function S.Threshold(subject)
    -- Cooperation is a fixed threshold, not a resource spent per question.
    -- Inquiry depth changes only the difficulty in dice mode.
    local report=B.npc and S.Report(B.npc)
    local adjustment=report and (report.stubborn and 15 or P.Kind(report.profile)=='amical' and -10 or 0) or 0
    return clamp(math.min(S.Config().threshold+adjustment,report and report.cap or 100),0,100)
end
function S.Limited(npc)
    local state=S.State(npc);local expires=state.answerExpires
    return R.Enabled('negativeQuota') and expires and expires>GetTimeStamp()
        and (not state.answerTrust or state.trust<state.answerTrust+10) or false
end
function S.Begin(npc)
    if not S.Enabled() or not npc then return end
    local state,report=S.State(npc)
    if state.trust>=report.cap then return nil,'Cette personne n’a plus besoin d’être convaincue.' end
    if not state.game or state.game.turn>4 then
        state.game={turn=1,offset=(P.Profile(npc).hash+(state.rounds or 0))%4,used={},total=0,decayMs=0,cycle=(state.rounds or 0)+1}
    end
    S.active={npc=npc,id=P.Profile(npc).id,game=state.game,ready=false,last=GetFrameTimeMilliseconds()}
    return state.game
end
function S.Valid()
    local a=S.active
    return a and S.Enabled() and B.npc==a.npc and B.IsOpen() and a.game.turn<=4 and S.State(a.npc).game==a.game
end
function S.Tick(now)
    local a=S.active
    if not a or not a.ready then return 0 end
    now=now or GetFrameTimeMilliseconds();local delta=now-a.last;a.last=now
    if not S.Valid() then a.ready=false;return 0 end
    if a.game.turn<=1 then return 0 end -- Observe freely until the first choice.
    -- Long frame gaps/loading are not decision time.
    if delta<0 or delta>1000 then return 0 end
    local state=S.State(a.npc);local config=S.Config()
    local interval=(S.Skills().persuasive>0 and config.persuasiveInterval or config.decayInterval)*1000
    interval=math.max(1000,interval)
    a.game.decayMs=(a.game.decayMs or 0)+delta
    local ticks=math.floor(a.game.decayMs/interval)
    if ticks>0 then
        a.game.decayMs=a.game.decayMs-ticks*interval
        local amount=ticks*config.decayAmount;local old=state.trust
        state.trust=math.max(0,old-amount);a.game.total=a.game.total-(old-state.trust)
        return old-state.trust
    end
    return 0
end
function S.Ready(value)
    if not S.active then return end
    S.Tick();S.active.ready=not not value;S.active.last=GetFrameTimeMilliseconds()
end
function S.Stop()
    if S.active then S.Tick();S.active.ready=false end
    S.active=nil
end
function S.Strength(game,action) return (action-1-game.offset)%4+1 end
function S.Play(action,expected)
    local a=S.active
    if not a or not a.ready or not S.Valid() or action<1 or action>4 or a.game.used[action] or a.game.turn~=expected then return false end
    S.Tick();S.Ready(false)
    local state=S.State(a.npc);local preference=state.preferences[action]
    local strength=S.Strength(a.game,action);local delta=S.factors[preference]*strength
    local old=state.trust;state.trust=clamp(old+delta,0,S.Report(a.npc).cap)
    state.known[action]=preference;a.game.used[action]=true;a.game.turn=a.game.turn+1
    a.game.offset=(a.game.offset+1)%4;a.game.total=a.game.total+(state.trust-old)
    a.game.last={action=action,preference=preference,strength=strength,delta=state.trust-old}
    if a.game.turn>4 then state.rounds=a.game.cycle end
    return true
end
function S.NextDecay()
    local a=S.active;if not a then return nil end
    if a.game.turn<=1 then return nil end
    local interval=(S.Skills().persuasive>0 and S.Config().persuasiveInterval or S.Config().decayInterval)*1000
    return math.max(0,(interval-(a.game.decayMs or 0))/1000)
end
function S.Debug(npc)
    local r=S.Report(npc);local b=r.bonuses
    local result=string.format('Base : %d\nContexte de départ : %+g\nReconnaissance de la communauté : %+g\nContexte actuel retenu : %+g\nTempérament du PNJ : %+g\nPrime / crimes : %+g\nRéputation brute : %+g · sensibilité : %d %%\nRéputation appliquée : %+g\nRenommée hors région : %+g\nRéputation de groupe : %+g\nAide personnelle à ce PNJ : %+g\nVolonté persuasive : %+g\nPrésence intimidante : %+g\nClémence : %+g\nMarchandage (rang %d) : %+g\nAvant restriction : %g\nPlafond personnel : %s\nConfiance : %d / %d',
        r.base,(r.contextInfo.initialPoints or r.contextInfo.points)*5,(r.contextInfo.recognition or 0)*5,r.context,r.personality,r.crime,r.reputationRaw,r.reputationSensitivity*100,r.reputationApplied,r.fame,r.guild,r.personal,
        b.persuasive,b.intimidation,b.clemency,r.skills.haggling,b.haggling,r.before,r.hardCap and tostring(r.hardCap) or 'aucun',S.Current(npc),r.cap)
    local _,completed,active,progressed=P.PersonalBonus(npc)
    result=result..string.format('\nQuêtes accomplies pour ce PNJ : %d\nMissions en cours avec ce PNJ : %d (progression constatée : %d)',completed or 0,active or 0,progressed or 0)
    if P.Kind(r.profile)=='radical' then result=result..'\nRadical hostile : insensible à la réputation collective.' end
    local progress=r.reputationProgress
    if progress then
        local lines={}
        for _,scope in ipairs({'clan','city','region'}) do
            local item=progress[scope]
            if item and item.total>0 then lines[#lines+1]=string.format('%s : %d achevées + %d avancées / %d quêtes · %.1f / 20 points',({clan='Clan',city='Ville',region='Région'})[scope],item.completed,item.advanced or 0,item.total,item.points) end
        end
        result=result..'\n\n'..table.concat(lines,'\n')..'\nLa réputation locale la plus forte est retenue ; ces trois scores ne se cumulent pas.'
    end
    local context=r.contextInfo
    local contextLines=string.format('\nContexte de départ : %+g\nReconnaissance de la communauté : %+g\nBilan contextuel actuel : %+g',
        (context.initialPoints or context.points)*5,(context.recognition or 0)*5,context.points*5)
    if context.recognitionLabel then contextLines=contextLines..'\n'..context.recognitionLabel end
    local info=contextLines..'\nProfil : '..((r.profile.questActor or r.profile.nativeInteraction) and 'personnage de quête / dialogue natif : hors répartition simulée' or r.profile.basis=='adaptation_documentee' and 'adaptation documentée' or 'personnalité simulée')
    info=info..'\nRace joueur (client) : '..context.playerRace..'\nAlliance joueur (client) : '..context.playerAllianceName..'\nRace PNJ : '..context.npcRace..'\nAffiliation PNJ : '..context.npcBanner
    info=info..'\nTempérament : '..r.profile.temperament..' · profil '..P.Kind(r.profile)..'\nMinimum permettant la persuasion : '..math.min(100,r.cooperationFloor)
    info=info..string.format('\nOrigine / préjugés : %+d · communauté : %+d · territoire : %+d · affiliation : %+d (points avant multiplication par 5)',context.race,context.community,context.territory,context.alliance)
    info=info..'\nTotal contextuel retenu : '..context.points..' (limité entre −7 et +3)'
    if context and #context.reasons>0 then info=info..'\n'..table.concat(context.reasons,'\n') end
    if not r.skills.available then info=info..'\nLecture des compétences indisponible : aucun bonus supposé.' end
    local game=S.State(npc).game
    if game and game.turn<=4 then
        local interval=r.skills.persuasive>0 and S.Config().persuasiveInterval or S.Config().decayInterval
        info=info..string.format('\nProchaine perte : %.1f s (timer en pause dans cet écran)',math.max(0,interval-(game.decayMs or 0)/1000))
    else info=info..'\nTimer arrêté.' end
    return result..info
end
