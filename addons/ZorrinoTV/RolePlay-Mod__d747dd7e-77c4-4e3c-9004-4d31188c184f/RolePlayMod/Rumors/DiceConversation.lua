if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Conversation frontend for acquired information. No random sightseeing or social minigame.
local B=IHR_Runtime.Beta
local A=IHR_Runtime.Base
local D=B.Dice
local previousShow,previousClose=B.Show,B.Close
local sequence=0
local diceRoot
local questView
local function choice(text,callback) return {text=text,callback=callback} end
local function cancel()
    sequence=sequence+1;questView=nil
    EVENT_MANAGER:UnregisterForUpdate('IHRD20Animation')
    if diceRoot then diceRoot:SetHidden(true) end
end
function B.Show(...) cancel();return previousShow(...) end
function B.Close() cancel();return previousClose() end
function B.ShowHome()
    if not B.npc then return end
    local choices={
        choice('J’aurais besoin d’un renseignement.',function() B.ShowQuests() end),
        choice('Je cherche un marchand ou un service.',function() B.ShowServices() end),
    }
    if B.HospitalityContext(B.npc) then choices[#choices+1]=choice('Avez-vous entendu parler de quelqu’un qui aurait besoin d’aide ?',function() B.ShowQuestRumors() end) end
    if B.IsInnkeeper(B.npc) and B.Lodging.Available() then choices[#choices+1]=choice('Je voudrais vous louer une chambre.',function() B.ShowLodging() end) end
    choices[#choices+1]=choice('(Consulter mon carnet.)',function() B.ShowNotebook() end)
    B.Show('Conversation',B.DialogueLine(B.CrimePenalty(B.npc)<=-6 and 'crime' or 'greeting'),choices)
end
-- Retired entry points cannot grant old conversation/minigame trust bonuses.
function B.ShowSocial() B.ShowHome() end
function B.ShowSocialGame() B.ShowHome() end
function B.ShowPersuasion() B.ShowHome() end
function B.ShowReputation() B.ShowHome() end
function B.ShowRumor() B.ShowHome() end
local function resultScreen(subject,result,cached)
    if not B.npc then return end
    if subject.kind~='rumor' and B.Personality and B.Personality.MaybeFalseAnswer then B.Personality.MaybeFalseAnswer(subject,result) end
    local text=string.format('D20 : %d · Difficulté : %d — %s%s\n\n',result.die,result.dd,result.success and 'Réussite' or 'Échec',cached and ' (résultat conservé)' or '')
    if result.automatic then text='' end
    if result.success and result.knowledgeUnavailable then
        text=text..(B.Personality and B.Personality.UnknownResponse(B.npc,subject,result) or (B.DialogueLine('unknown')..' Demandez aux gens sur place.'))
    elseif result.success then
        if subject.kind=='rumor' then
            local heard=B.HearRumor(subject.rumor)
            if not heard then B.ShowQuestRumors(true);return end
            result.answer=heard
            B.Remember({name=subject.rumor.title,rumorId=subject.rumor.quest},heard,result.npc)
        end
        local factual=B.Personality and B.Personality.FactualAnswer(result,B.npc,subject) or result.answer
        if subject.task then factual=D.CleanRouteText(factual) end
        result.factualAnswer=factual;result.answer=factual
        local spoken=B.SpokenAnswer(subject,factual,B.npc,result)
        if result.unverified then B.Personality.RecordTestimony(subject,result)
        elseif not D.Reveal(subject,result) then B.Show('Objectif modifié','Cet objectif a changé. Relisez votre journal.',{});return end
        text=text..spoken
        if not subject.task and subject.kind~='rumor' then B.Remember({name=subject.title},result.answer,result.npc) end

    else
        if subject.kind=='rumor' and B.MarkRumorRefusal then B.MarkRumorRefusal(subject.rumor,result) end
        text=text..(subject.kind=='rumor' and B.WildernessRumors.RefusalLine(B.npc) or B.DialogueLine('refusal'))

    end
    if subject.kind~='rumor' and B.Personality then B.Personality.FinishAttempt(subject,result,B.npc) end
    local canContinue=subject.kind=='rumor' or not (B.Personality and B.Personality.Limited(B.npc))
    local choices={}
    if result.referral then
        local referral=result.referral
        choices[#choices+1]=choice('Où puis-je trouver '..referral.name..' ?',function()
            B.Show('Trouver '..referral.name,referral.answer,{
                choice('Revenir à ma question.',function()
                    local quest=B.ReadQuest(subject.task.index)
                    if quest then B.ShowQuest(quest) else B.ShowHome() end
                end)})
        end)
    end
    if canContinue and result.success and not result.knowledgeUnavailable and not result.unverified and D.Followups then
        for _,followup in ipairs(D.Followups(subject)) do
            local nextQuestion=followup.subject
            choices[#choices+1]=choice(followup.text,function() D.Ask(nextQuestion) end)
        end
    end
    if canContinue and subject.task and #D.Subjects(subject.task.index)>0 then choices[#choices+1]=choice('J’aurais une autre question.',function() B.ShowQuest(B.ReadQuest(subject.task.index)) end) end
    if subject.kind=='rumor' then
        if result.success and B.TravelJournal and RolePlayMod.Enabled('travelJournal') then choices[#choices+1]=choice('Relire cette rumeur dans mon carnet.',B.TravelJournal.Open) end
        if canContinue then choices[#choices+1]=choice('Autre chose ?',function() B.ShowQuestRumors(true) end) end
    end
    if canContinue and subject.kind=='service' then choices[#choices+1]=choice('Demander un autre service.',function() B.ShowServices() end) end
    choices[#choices+1]=choice(result.success and (result.knowledgeUnavailable and 'Merci quand même.' or 'Merci pour votre aide.') or 'Très bien. Je vous laisse.',function() B.ShowHome() end)
    B.Show(subject.title,text,choices)
end
-- Shared factual delivery; the dice path and its animation remain unchanged.
function D.DeliverResult(subject,result,cached) return resultScreen(subject,result,cached) end
local function animate(subject,result,cached)
    local npc=B.npc
    local visual=B.DiceVisual
    local parent=B.ShowCustomContent('Convaincre son interlocuteur',470,{kind='dice',contentTop=44})
    if not diceRoot then diceRoot=visual.Create(parent) end
    diceRoot:SetHidden(false)
    visual.Paint(diceRoot,cached and visual.duration or 0,result)
    local started=GetFrameTimeMilliseconds()
    local token=sequence
    local complete=not not cached
    diceRoot.continueButton:SetHandler('OnClicked',function()
        if not complete or token~=sequence or B.npc~=npc or not B.IsOpen() then return end
        complete=false
        if subject.task and not D.Fresh(subject.task) then B.Show('Objectif modifié','Cet objectif a changé pendant la conversation.',{},true);return end
        resultScreen(subject,result,cached)
    end)
    if cached then return end
    EVENT_MANAGER:RegisterForUpdate('IHRD20Animation',30,function()
        if token~=sequence or B.npc~=npc or not B.IsOpen() then EVENT_MANAGER:UnregisterForUpdate('IHRD20Animation');return end
        local elapsed=GetFrameTimeMilliseconds()-started
        -- Animation never draws another random result.
        visual.Paint(diceRoot,elapsed,result)
        if elapsed>=visual.duration then
            EVENT_MANAGER:UnregisterForUpdate('IHRD20Animation')
            complete=true
            -- Keep the landed die, result and difficulty visible until Continue.
        end
    end)
end
-- Shared animation entry point: the rumor policy tests willingness separately
-- from ordinary quest answers, without duplicating the controller/keyboard UI.
function D.PresentResult(subject,result,cached)
    if result.automatic then return resultScreen(subject,result,cached) end
    return animate(subject,result,cached)
end
function D.Ask(subject)
    if not B.npc then return end
    subject=D.RefreshSubject(subject)
    if not subject then B.ShowHome();return end
    local result,errorText,cached=D.Roll(subject,B.npc)
    if not result then B.ShowHome();return end
    return D.PresentResult(subject,result,cached)
end
function B.ShowQuest(q)
    if not q or not B.npc then return end
    local current=B.ReadQuest(q.index)
    if not current or current.key~=q.key then B.ShowQuests();return end
    local subjects=D.Subjects(current.index)
    local choices={}
    for _,entry in ipairs(subjects) do local subject=entry;choices[#choices+1]=choice(D.InquiryLabel and D.InquiryLabel(subject,subject.question) or subject.question,function() D.Ask(subject) end) end
    choices[#choices+1]=choice('(Relire mes notes sur cette affaire.)',function() B.ShowEvidence(current) end)
    choices[#choices+1]=choice('Je cherche aussi autre chose.',function() B.ShowQuests() end)
    B.Show(current.name,B.DialogueLine(#subjects>0 and 'question' or 'finished'),choices)
    if B.ConversationUI then B.ConversationUI.SetRoute({kind='quest',index=current.index,key=current.key}) end
    questView={index=current.index,key=current.key,npc=B.npc}
end
function D.OnPosition(task)
    if questView and questView.index==task.index and questView.key==task.questKey and B.npc==questView.npc and B.IsOpen() then
        local q=B.ReadQuest(task.index);if q then B.ShowQuest(q) end
    end
end
local function refreshQuestQuestions(_,index)
    if questView and questView.index==index and B.npc==questView.npc and B.IsOpen() then
        local q=B.ReadQuest(index)
        if q then B.ShowQuest(q) end
    end
end
if EVENT_QUEST_CONDITION_COUNTER_CHANGED then EVENT_MANAGER:RegisterForEvent('IHRQuestQuestionsCounter',EVENT_QUEST_CONDITION_COUNTER_CHANGED,refreshQuestQuestions) end
if EVENT_QUEST_CONDITION_OVERRIDE_TEXT_CHANGED then EVENT_MANAGER:RegisterForEvent('IHRQuestQuestionsOverride',EVENT_QUEST_CONDITION_OVERRIDE_TEXT_CHANGED,refreshQuestQuestions) end
function B.ShowPlace(place)
    if place.entityType=='alliance' and place.topic then
        D.Ask({kind='topic',key='topic:'..place.normal,title=place.name,question=place.topic.question,answer=place.topic.answer,source='Contexte politique vérifié',level=1});return
    end
    local subject=D.PlaceSubject(place,nil)
    if subject then D.Ask(subject) else B.Show('Se renseigner','Aucune indication géographique supplémentaire n’est vérifiée pour cet endroit.',{}) end
end
function B.ShowServices()
    if not B.npc then return end
    SetMapToPlayerLocation()
    local locality=A.SubZone()
    local services=A.GetServices(locality)
    table.sort(services,function(a,b) return A.ServiceLabel(a)<A.ServiceLabel(b) end)
    local choices={}
    for _,service in ipairs(services) do
        local name=service
        choices[#choices+1]=choice('Où trouver : '..A.ServiceLabel(name)..' ?',function()
            SetMapToPlayerLocation()
            if not A.SamePlace(locality,A.SubZone()) then B.ShowServices();return end
            local entry=A.GetService(name,locality)
            if not entry then B.Show('Services','Aucun emplacement vérifié pour ce service dans cette localité.',{},true);return end
            local direction,range,distance=A.ServiceDirections(entry.mapX,entry.mapY)
            local answer=distance<.045 and 'C’est tout près d’ici. Regardez autour de vous.' or (A.ServiceLabel(name)..' ? Cherchez vers le '..direction..'. '..range)
            D.Ask({kind='service',key='service:'..B.Normalize(locality)..':'..name,title=A.ServiceLabel(name),question='Pouvez-vous m’indiquer où trouver ce service ?',answer=answer,level=1,source='Base de services et coordonnées vérifiées'})
        end)
    end
    B.Show('Services',#choices>0 and 'Que cherchez-vous ?' or 'Aucun service n’est répertorié ici dans les données disponibles.',choices)
    if B.ConversationUI then B.ConversationUI.SetRoute({kind='services'}) end
end
function B.ShowQuestRumors()
    if not B.npc then return end
    if not B.HospitalityContext(B.npc) then B.Show('Les nouvelles du pays','Essayez dans une auberge ou un restaurant.',{});return end
    local choices={}
    for _,entry in ipairs(B.KnownRumors(B.npc)) do
        local rumor=entry
        choices[#choices+1]=choice(rumor.title,function()
            if not B.RumorEligible(rumor) then B.ShowQuestRumors();return end
            local text=rumor.text
            D.Ask({kind='rumor',key='rumor:'..rumor.quest,title='Une rumeur',question='Avez-vous entendu quelque chose à ce sujet ?',answer=text,level=1,source='Départ de quête documenté',rumor=rumor})
        end)
    end
    B.Show('Les nouvelles du pays',#choices>0 and 'Vous cherchez des nouvelles ?' or 'Je n’ai pas de nouvelle à vous donner. Essayez de parler à quelqu’un d’autre ici.',choices)
end
