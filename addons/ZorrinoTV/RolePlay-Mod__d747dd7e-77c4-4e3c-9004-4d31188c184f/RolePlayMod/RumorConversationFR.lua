-- Rumors are true, documented quest starts. Persuasion changes willingness,
-- never the speaker's stock of leads. Ordinary quest testimony keeps its rules.
local R=RolePlayMod
local B=IHR_Runtime.Beta
local D=B.Dice
local W=B.WildernessRumors
local S=R.Speechcraft
local function line(key,human,khajiit,npc)
    local bank=B.IsKhajiitSpeaker(npc) and khajiit or human
    return (B.Line('rumor-'..key,bank,npc):gsub('{name}',B.DialogueFirstName(npc)))
end
function W.VoiceRumor(r,npc)
    if r.person==false and r.questName then
        local affair='une affaire appelée « '..r.questName..' ».'
        local intro=line('affair-'..r.quest,
            {'Un voyageur m’a parlé d’'..affair,'Il paraît qu’on parle d’'..affair},
            {'Un voyageur a parlé à {name} d’'..affair,'{name} a entendu parler d’'..affair},npc)
        return intro..(r.route and ('\n\n'..r.route) or '')
    end
    if r.person and not r.account then
        return line('contact-'..r.quest,
            {'On m’a dit que vous pourriez vous renseigner auprès de '..r.giver..'.'},
            {'On a dit à {name} que vous pourriez vous renseigner auprès de '..r.giver..'.'},npc)..'\n\n'..r.route
    end
    if not r.account or not r.route then
        return B.IsKhajiitSpeaker(npc) and (B.DialogueFirstName(npc)..' a entendu parler de cette affaire. '..r.text) or r.text
    end
    local giver=r.giver:gsub('^Le ','le '):gsub('^La ','la '):gsub('^Les ','les ')
    local ofGiver=B.RouteVoice.Of(giver)
    local intro=line('heard-'..r.quest,{
        'Un voyageur m’a parlé '..ofGiver..'. ',
        'Il paraît que '..giver..' aurait besoin d’un coup de main. ',
        'Une histoire circule à propos '..ofGiver..'. ',
        'J’ai entendu des voyageurs parler '..ofGiver..'. ',
        'On raconte que '..giver..' cherche de l’aide. ',
        'Il se murmure que '..giver..' aurait besoin d’aide. ',
    },{
        '{name} a entendu un voyageur parler '..ofGiver..'. ',
        'Une rumeur est parvenue aux oreilles de {name} : '..giver..' aurait besoin d’un coup de main. ',
        'Des voyageurs ont parlé '..ofGiver..' à {name}. ',
        '{name} a recueilli une histoire sur la route. Elle concerne '..giver..'. ',
    },npc)
    return intro..r.account..'\n\n'..r.route
end
-- Withdraw old story/prologue/repeatable leads from the visible travel journal.
-- Keep their original entries separately rather than destroying personal notes.
local refresh=B.TravelJournal.Refresh
function B.TravelJournal.Refresh()
    local data=B.saved and B.saved.travelJournalV1
    for key,entry in pairs(data and data.entries or {}) do
        if W.IsSecondary(tonumber(entry.quest))==false then
            B.saved.withdrawnRumors22=B.saved.withdrawnRumors22 or {}
            B.saved.withdrawnRumors22[key]=entry;data.entries[key]=nil
        end
    end
    return refresh()
end
function W.EndLine(npc,status)
    -- Absence of catalogue data is not evidence that the game has no quests.
    if not status or not status.catalogueReady then return line('unknown',
        {'Désolé, je ne sais rien de plus. Essayez les autres voyageurs.'},
        {'{name} ne sait rien de plus. Essayez les autres voyageurs.'},npc) end
    if status.regionalComplete then return line('region-finished',{
        'Vous avez fait le tour des affaires de la région. Pour celles que vous avez notées, jetez un œil à votre carnet.',
        'Je n’ai plus d’affaire à vous signaler dans la région. Vous connaissez déjà toutes les pistes dont on parle par ici.',
    },{
        '{name} n’a plus d’affaire à vous signaler dans la région. Vous connaissez déjà toutes les pistes dont les voyageurs lui ont parlé.',
        'Vous avez fait le tour des affaires de la région. {name} vous laisse relire celles que vous avez notées.',
    },npc) end
    if status.regionalRemaining>0 and status.eligible==0 then return line('pending-leads',{
        'D’autres affaires se préparent dans le coin, mais pour l’instant je n’ai rien de précis à vous raconter.',
    },{
        'D’autres histoires circulent dans le coin, mais {name} n’en sait pas encore assez pour vous orienter.',
    },npc) end
    return line('personal-finished',{
        'Désolé, je ne sais rien de plus. Essayez les autres voyageurs ici.',
        'C’est tout ce que j’ai entendu. Faites le tour des autres voyageurs ici ; ils auront peut-être une autre piste.',
        'Je n’ai pas d’autre nouvelle à vous donner. Demandez aux autres clients ici, ils en savent peut-être davantage.',
    },{
        '{name} ne sait rien de plus. Essayez les autres voyageurs ici.',
        'C’est tout ce que {name} a entendu. Demandez aux autres voyageurs ici ; ils auront peut-être une autre piste.',
        '{name} n’a pas d’autre nouvelle à vous donner. Les autres clients ici en savent peut-être davantage.',
    },npc)
end
function W.RefusalLine(npc)
    local behaviour=B.Personality.Behaviour(npc)
    if behaviour=='hostile' or behaviour=='mefiant' then return line('refusal-hostile',{
        'Je ne vous connais pas. Les affaires des autres ne vous regardent pas.',
        'Je préfère garder mes nouvelles pour moi. Vous n’avez pas encore ma confiance.',
    },{
        '{name} ne vous connaît pas assez pour se confier.',
        '{name} préfère garder ses nouvelles pour lui. Gagnez d’abord sa confiance.',
    },npc) end
    return line('refusal',{
        'Pardonnez-moi, je ne vous connais pas assez pour vous raconter cela.',
        'Prenons d’abord le temps de faire connaissance. Je ne voudrais pas mettre quelqu’un dans l’embarras.',
    },{
        '{name} ne vous connaît pas assez pour vous raconter cela.',
        'Prenez d’abord le temps de parler avec {name}. {name} ne voudrait mettre personne dans l’embarras.',
    },npc)
end
local ask=D.Ask
function D.Ask(subject)
    if not subject or subject.kind~='rumor' then return ask(subject) end
    if not B.npc then return end
    if not R.Enabled('rumors') or not B.HospitalityContext(B.npc) then return B.ShowHome() end
    -- Re-read eligibility and current telling after the wheel or a quest update.
    -- A notebook entry may be repeated; an active/completed quest may not.
    local fresh
    for _,r in ipairs(B.KnownRumors(B.npc)) do
        if subject.rumor and r.quest==subject.rumor.quest then fresh=r;break end
    end
    if not fresh then return B.ShowQuestRumors(true) end
    local current={};for k,v in pairs(subject) do current[k]=v end
    subject=current;subject.rumor=fresh;subject.answer=fresh.text;subject.source=fresh.source
    subject.unresolved=nil;subject.rumorVoiced=true
    local speech=S.Enabled()
    local mode=speech and 'speechcraft' or 'dice'
    local convinced=W.IsConvinced(B.npc,mode)
    local trust=speech and S.Current(B.npc) or B.Confidence(B.npc)
    local required=speech and S.Threshold(subject) or select(1,D.Difficulty(B.npc))
    if speech and not convinced and trust<required then
        S.pendingSubject=subject
        local choices={}
        if S.CanPersuade(B.npc) then choices[#choices+1]={text='Prenons le temps de discuter.',callback=S.Wheel.Show} end
        choices[#choices+1]={text='Je vais demander ailleurs.',callback=function() S.pendingSubject=nil;B.ShowHome() end}
        return B.Show(subject.title,W.RefusalLine(B.npc),choices)
    end
    S.pendingSubject=nil
    local result,cached
    if speech or convinced or not R.Enabled('dice') then
        result={automatic=true,speechcraft=speech,die=20,dd=required,confidence=trust,success=true,time=GetTimeStamp(),level=1}
    else
        -- One willingness test for this NPC/region, not a separate roll for
        -- every lead. The versioned key ignores legacy feigned-ignorance results.
        local rollSubject={};for k,v in pairs(subject) do rollSubject[k]=v end
        rollSubject.key='rumor-access-v21:'..tostring(B.MapKey())
        local err
        result,err,cached=D.Roll(rollSubject,B.npc)
        if not result then return B.Show(subject.title,W.RefusalLine(B.npc),{
            {text='Je vais demander ailleurs.',callback=B.ShowHome}}) end
        local copy={};for k,v in pairs(result) do copy[k]=v end;result=copy
    end
    result.answer=fresh.text;result.source=fresh.source;result.npc=B.npc.name;result.locality=B.npc.locality
    result.socialBehaviour=B.Personality.Behaviour(B.npc)
    result.unverified=nil;result.refused=nil;result.factualAnswer=nil;result.knowledgeUnavailable=false
    return D.PresentResult(subject,result,cached)
end
