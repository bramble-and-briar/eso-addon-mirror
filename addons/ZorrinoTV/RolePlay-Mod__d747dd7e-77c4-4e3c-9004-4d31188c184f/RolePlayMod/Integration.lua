if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
local R=RolePlayMod
local B=IHR_Runtime.Beta
local D=B.Dice
local S=RolePlayNeeds
-- Original engines remain internal modules. Only the combined settings panel is registered.
S.MakeMenu=function() end
function R.Apply(close)
    if not R.saved or not B.saved or not S.settings then return end
    local o=R.Options();local s=S.settings
    s.survivalModeOn=R.Enabled('survival');s.diseasesMechanicEnabled=R.Enabled('disease')
    B.saved.enabled=R.Enabled('questions') or R.Enabled('services') or R.Enabled('rumors') or R.Enabled('rooms') or R.Enabled('travelJournal')
    local trust=R.Enabled('trust')
    B.saved.speechcraftEnabled=trust;B.saved.trustEnabled=trust
    B.saved.reputationEnabled=trust and o.reputation;B.saved.originInfluence=trust and o.origins;B.saved.crimeInfluence=trust and o.crime
    B.saved.nativeConversation=o.nativeConversation
    B.DiceVisual.duration=math.max(1000,math.min(15000,(tonumber(o.diceSeconds) or 5)*1000))
    if S.FatigueRules then S.FatigueRules.UpdateRestrictions() end
    if not R.Enabled('fatigue') then S.isResting=false end
    for i=1,3 do local c=_G['DiseaseOverlay'..i];if c then c:SetAlpha(s['diseaseOverlayalpha'..i] or .75) end end
    S.ShowDiseaseOverlay(R.Enabled('disease') and S.hasDisease or false,R.Enabled('disease') and S.diseaseLv or -1)
    if S.NeedsHUD then
        if S.NeedsHUD.editing and (not R.Enabled('survival') or (s.needsHUD and s.needsHUD.enabled==false)) then S.NeedsHUD.EndEdit() end
        S.NeedsHUD.Update()
    end
    if B.Personality then B.Personality.InvalidateReputation() end
    if B.Investigation then B.Investigation.Refresh() end
    if close and B.Close then B.Close() end
    if R.RefreshWheel then R.RefreshWheel() end
end
-- Independent need controls freeze the disabled reserve and remove its consequences.
local needFunctions={hunger={'IncreaseHunger','IncreaseHungerNeutral','ResetHunger'},water={'IncreaseWater','IncreaseWaterNeutral','IncreaseWater2','IncreaseWater3','IncreaseWaterSit','ResetWater'},alcohol={'IncreaseAlcohol','ResetAlcohol'},disease={'ApplyDisease'}}
for key,names in pairs(needFunctions) do
    for _,name in ipairs(names) do
        local fn=S[name];local option=key
        S[name]=function(...) if R.Enabled(option) then return fn(...) end end
    end
end
local overlay=S.ShowDiseaseOverlay
function S.ShowDiseaseOverlay(state,level)
    if not R.Enabled('disease') then return overlay(false,-1) end
    return overlay(state,level)
end
local cureButton=S.ShowCureButton
function S.ShowCureButton(show) return cureButton(show and R.Enabled('disease')) end
-- The old icon loop must never reveal a disabled need.
local update=S.OnUpdateFunction
function S.OnUpdateFunction(...)
    local result=update(...)
    for _,key in ipairs({'hunger','water','fatigue','alcohol'}) do
        if not R.Enabled(key) and S[key] and S[key].texture then S[key].texture:SetAlpha(0) end
    end
    return result
end
local lodging=B.Lodging.Available
function B.Lodging.Available() return R.Enabled('rooms') and lodging() end
local function choice(text,fn) return {text=text,callback=fn} end
function B.ShowHome()
    if not B.npc or not B.saved then return end
    B.Personality.EnterConversation()
    local choices={};local limited=B.Personality and B.Personality.Limited(B.npc)
    if not limited then
        if R.Enabled('questions') then choices[#choices+1]=choice('J’aurais besoin d’un renseignement.',B.ShowQuests) end
        if R.Enabled('services') then choices[#choices+1]=choice('Je cherche un marchand ou un service.',B.ShowServices) end
        if R.Enabled('questions') and R.Enabled('travelJournal') and B.TravelJournal.ShowInquiries then
            choices[#choices+1]=choice('Carnet de voyage',B.TravelJournal.ShowInquiries)
        end
    end
    if R.Enabled('rumors') and B.HospitalityContext(B.npc) then choices[#choices+1]=choice('Avez-vous entendu parler de quelqu’un qui aurait besoin d’aide ?',B.ShowQuestRumors) end
    if R.Enabled('rooms') and B.IsInnkeeper(B.npc) and B.Lodging.Available() then choices[#choices+1]=choice('Je voudrais vous louer une chambre.',B.ShowLodging) end
    if R.Enabled('travelJournal') then choices[#choices+1]=choice('(Consulter mon carnet de voyage.)',B.ShowNotebook) end
    B.Show('Conversation',B.DialogueLine(limited and 'daily' or 'greeting'),choices)
end
for _,entry in ipairs({{'ShowQuests','questions'},{'ShowQuest','questions'},{'ShowServices','services'},{'ShowQuestRumors','rumors'}}) do
    local name,key=entry[1],entry[2];local fn=B[name]
    B[name]=function(...) if not R.Enabled(key) then return B.ShowHome() end;return fn(...) end
end
local open=B.Open
function B.Open(...) if not B.saved or not B.saved.enabled then return false end;return open(...) end
local ask=D.Ask
function D.Ask(subject)
    local key=subject and (subject.kind=='rumor' and 'rumors' or subject.kind=='service' and 'services' or 'questions')
    if not key or not R.Enabled(key) then return B.ShowHome() end
    return ask(subject)
end
local P=B.Personality
local negative,limited,canAsk=P.Negative,P.Limited,P.CanAsk
function P.Limited(npc) return R.Enabled('negativeQuota') and R.Enabled('dice') and limited(npc) end
function P.CanAsk(npc,subject) return not R.Enabled('negativeQuota') or not R.Enabled('dice') or canAsk(npc,subject) end
local roll=D.Roll
function D.Roll(subject,npc)
    if R.Enabled('dice') then return roll(subject,npc) end
    if not subject or (not subject.unresolved and (not subject.answer or subject.answer=='')) then return end
    if subject.task and not D.Fresh(subject.task) then return end
    local dd,confidence=D.Difficulty(npc)
    local zone,x,_,z=GetUnitWorldPosition('player')
    return {originZone=zone,originX=x,originZ=z,scopeRadius=subject.scopeRadius,automatic=true,die=20,dd=dd,confidence=confidence,success=true,answer=subject.answer,knowledgeUnavailable=not not subject.unresolved,
        source=subject.source,level=subject.level,npc=npc.name,locality=npc.locality,time=GetTimeStamp(),inquiryDepth=subject.inquiryDepth,
        socialBehaviour=P.Behaviour(npc)}
end
-- Disabling journal decoration hides it; acquired evidence is preserved for reactivation.
local lines=B.Investigation.Lines
function B.Investigation.Lines(...) if not R.Enabled('journal') then return '' end;return lines(...) end
local decorate=B.Investigation.Decorate
function B.Investigation.Decorate(index,strings)
    if not R.Enabled('journal') then
        for _,row in ipairs(type(strings)=='table' and strings or {}) do if row.ihrOriginal then row.name=row.ihrOriginal end end
        return
    end
    return decorate(index,strings)
end
local T=B.TravelJournal
local has,note,book,noted=T.Has,T.Note,T.Open,T.ShowNoted
function T.Has(...) return R.Enabled('travelJournal') and has(...) end
function T.Note(...) if not R.Enabled('travelJournal') then return false end;return note(...) end
function T.Open(...) if not R.Enabled('travelJournal') then return end;return book(...) end
function T.ShowNoted(...) if not R.Enabled('travelJournal') then return end;return noted(...) end
B.ShowNotebook=T.Open
-- Visible wheel entries follow the same switches; saved shortcuts themselves are retained.
function R.RefreshWheel()
    local root=MyFakeRadial;if not root then return end
    local visibility={R.Enabled('hunger'),R.Enabled('water'),R.Enabled('fatigue'),R.Enabled('partialRests'),true,B.saved and B.saved.enabled,
        type(TamrielBooks)=='table',type(ImmersivePets)=='table'}
    for i=1,8 do local button=root:GetNamedChild('Button'..i);if button then button:SetHidden(not visibility[i]) end end
end
local wheel=InitializeWheel
function InitializeWheel(...) local result=wheel(...);R.RefreshWheel();return result end
EVENT_MANAGER:RegisterForEvent('RPMIntegration',EVENT_ADD_ON_LOADED,function(_,name)
    if name~=R.name then return end
    R.Apply()
    SLASH_COMMANDS['/togglesurvival']=function() R.Set('survival',not R.Options().survival) end
    SLASH_COMMANDS['/ihrbeta']=function() R.Set('conversations',not R.Options().conversations) end
    SLASH_COMMANDS['/ihrspeech']=function() R.Set('trust',not R.Options().trust) end
    SLASH_COMMANDS['/carnet']=T.Open;SLASH_COMMANDS['/ihrvoyage']=T.Open
    local commands={['/eatfood']='hunger',['/drinkwater']='water',['/takeanap']='partialRests',['/rest']='fatigue'}
    for command,key in pairs(commands) do local fn,option=SLASH_COMMANDS[command],key
        if fn then SLASH_COMMANDS[command]=function(...) if R.Enabled(option) then return fn(...) end end end
    end
    EVENT_MANAGER:UnregisterForEvent('RPMIntegration',EVENT_ADD_ON_LOADED)
end)
