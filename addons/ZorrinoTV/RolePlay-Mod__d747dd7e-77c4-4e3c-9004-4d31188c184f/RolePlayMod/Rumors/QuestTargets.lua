if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Current objective -> person, object or place. Reference facts are not learned clues.
local B=IHR_Runtime.Beta
local D=B.Dice
local function norm(text) return B.Normalize(text or '') end
local function copy(t) local r={};for k,v in pairs(t) do r[k]=v end;return r end
local referenceFacts={
 {quest='Digne de régner',id=4951,objective='Retirez le manteau de Rajhin',kind='object',target='le manteau de Rajhin',place='Le site hivernal de Falinesti',source='ESOAZ — Le site hivernal de Falinesti',url='https://esoaz.com/2019/03/12/le-site-hivernal-de-falinesti/'},
 {quest='Digne de régner',id=4951,objective='Récupérez le cœur d’Anumaril',kind='object',target='le cœur d’Anumaril',place='Le Reliquaire des étoiles',source='ESOAZ — Pointe-Sud, Digne de régner',url='https://esoaz.com/2019/03/12/pointe-sud/'},
 {quest='Digne de régner',id=4951,objective='Trouvez la conservatrice Daraneth',kind='person',target='la conservatrice Daraneth',place='Pointe-Sud',source='ESOAZ — Pointe-Sud, Digne de régner',url='https://esoaz.com/2019/03/12/pointe-sud/'},
}
local personRoles={conservatrice=true,conservateur=true,general=true,generale=true,capitaine=true,roi=true,reine=true,prince=true,princesse=true,chercheuse=true,chercheur=true,garde=true,maire=true,pretre=true,pretresse=true,ambassadeur=true,ambassadrice=true}
local placeRoles={mine=true,ruines=true,fort=true,forteresse=true,village=true,ville=true,camp=true,campement=true,temple=true,oratoire=true,grotte=true,caverne=true,port=true,palais=true,tour=true,site=true}
local personActions={parlez=true,parler=true,talk=true,interrogez=true,rencontrez=true}
local placeActions={allez=true,retournez=true,rejoignez=true,['rendez vous']=true,entrez=true,penetrez=true}
local deliveryActions={donnez=true,apportez=true,livrez=true,remettez=true,rapportez=true}
local localActions={dispensez='verser',versez='verser',deversez='déverser',aspergez='asperger',repandez='répandre',appliquez='appliquer',deposez='déposer',placez='placer',utilisez='utiliser'}
local oldQuestion=D.QuestionForTask
function D.DeliveryRecipient(text)
    local best,recipient=0,nil
    for _,prep in ipairs({' à ',' au ',' aux '}) do
        local start=1
        while true do
            local at,finish=text:find(prep,start,true);if not at then break end
            if at>best then
                best=at;recipient=text:sub(finish+1)
                if prep==' au ' then recipient='le '..recipient elseif prep==' aux ' then recipient='les '..recipient end
            end
            start=finish+1
        end
    end
    return recipient
end
function D.TargetForTask(task)
    if task.text:find('<<',1,true) or not oldQuestion(task) then return end
    local first,target=task.text:match('^([^ \t\r\n]+)[ \t\r\n]+(.+)$')
    if not target then return end
    local action=norm(first)
    target=target:gsub('[ \t]*:[ \t]*%d+.*$',''):gsub('[ \t]*%([ \t]*%d+[ \t]*/[ \t]*%d+[ \t]*%)[ \t]*$',''):gsub('[.!?]+$','')
    local kind,localAction
    if localActions[action] then
        local location=target:match(' à (.+)$') or target:match(' sur (.+)$') or target:match(' dans (.+)$')
        if location then target=location;kind='place';localAction=true
        elseif action=='dispensez' or action=='versez' or action=='deversez' then localAction=true end
    end
    if deliveryActions[action] then local recipient=D.DeliveryRecipient(target);if recipient then target=recipient;kind='person' end end
    if personActions[action] or placeActions[action] then
        target=target:match('^à[ \t]+(.+)$') or target:match('^avec[ \t]+(.+)$') or target:match('^dans[ \t]+(.+)$') or target:match('^vers[ \t]+(.+)$') or target:match('^to[ \t]+(.+)$') or (target:match('^au[ \t]+(.+)$') and ('le '..target:match('^au[ \t]+(.+)$'))) or (target:match('^aux[ \t]+(.+)$') and ('les '..target:match('^aux[ \t]+(.+)$'))) or target
        kind=personActions[action] and 'person' or 'place'
    end
    local base=norm(target):gsub('^les ',''):gsub('^le ',''):gsub('^la ',''):gsub('^l ','')
    local role=base:match('^([^ ]+)')
    if not kind then
        if personRoles[role] then kind='person'
        elseif placeRoles[role] or B.PublicPlace(target) or B.KnowledgeAtlas().sites[base] then kind='place'
        else kind='object' end
    end
    return {name=target,kind=kind,action=action,localAction=localAction}
end
function D.QuestionForTask(task)
    local target=D.TargetForTask(task)
    if not target then return end
    if target.localAction then
        if target.kind=='place' then return 'Savez-vous où se trouve '..target.name..' ?' end
        return 'Où dois-je '..localActions[target.action]..' '..target.name..' ?'
    end
    if target.kind=='person' then return 'Savez-vous où je pourrais trouver '..target.name..' ?' end
    if target.kind=='object' and not deliveryActions[target.action] and target.action~='utilisez' and target.action~='placez' and target.action~='deposez' then
        local plural=norm(target.name):match('^les ') or norm(target.name):match('^des ')
        return 'Savez-vous où se '..(plural and 'trouvent ' or 'trouve ')..target.name..' ?'
    end
    return oldQuestion(task)
end
function D.ContextDestination(task)
    if not task.stepText or task.stepText=='' then return end
    local q=copy(task.quest);q.sources={{text=task.stepText,kind='Étape actuelle'}}
    for _,source in ipairs(task.quest.sources) do if norm(source.text)~=norm(task.stepText) then q.sources[#q.sources+1]=source end end
    local function mentioned(name)
        local text=' '..norm(task.stepText)..' '
        local full=norm(name):gsub('^le ',''):gsub('^la ',''):gsub('^les ','')
        local stem=B.PlaceStem(name)
        return text:find(' '..full..' ',1,true) or (#stem>=5 and text:find(' '..stem..' ',1,true))
    end
    local places={}
    local region=D.Region(task.quest.zoneIndex)
    for _,place in ipairs(B.MatchPlaces(q)) do
        if place.entityType~='person' and place.entityType~='alliance' and place.entityType~='region' then
            local site=D.SiteForName(place.name,region and region.zoneIndex or nil)
            if site and mentioned(place.name) then places[norm(site.name)]={name=site.name,site=site,region=site.region,relation='in',context=true,source='Client FR : lieu nommé dans l’étape actuelle'} end
        end
    end
    -- Native place names are also read directly: a legacy name catalogue may
    -- lack a POI, and MatchPlaces deliberately suppresses the current location.
    local current=' '..norm(task.stepText)..' '
    for key,site in pairs(B.KnowledgeAtlas().sites) do
        if current:find(' '..key..' ',1,true) then
            local object=false
            for _,source in ipairs(task.quest.sources) do
                local text=' '..norm(source.text)..' '
                local _,finish=text:find(' '..key..' ',1,true)
                if finish then
                    local tail=text:sub(finish+1,finish+100)
                    if tail:find('^un .-artefact') or tail:find('^une .-relique') or tail:find('^un .-objet') then object=true end
                end
            end
            if not object then places[key]={name=site.name,site=site,region=site.region,relation='in',context=true,source='Client FR : lieu de la carte nommé dans l’étape'} end
        end
    end
    local found
    for _,place in pairs(places) do if found then return end;found=place end
    return found -- Several distinct places require a task-specific link instead of a guess.
end
local destination=D.Destination
function D.Destination(task,meta)
    local target=D.TargetForTask(task)
    if target and target.localAction then local context=D.ContextDestination(task);if context then return context end end
    local found=destination(task,meta)
    if found then return found end
    local context=D.ContextDestination(task);if context then return context end
    for _,fact in ipairs(referenceFacts) do
        if norm(task.quest.name)==norm(fact.quest) and D.ObjectiveCanonical(task.text)==D.ObjectiveCanonical(fact.objective) then
            local region=D.Region(task.quest.zoneIndex)
            local site=D.SiteForName(fact.place,region and region.zoneIndex or nil)
            return {name=site and site.name or fact.place,site=site,relation='in',region=site and site.region or (region and region.name),source=fact.source..' — '..fact.url}
        end
    end
end
local plan=D.PlanTask
function D.PlanTask(task)
    local target=D.TargetForTask(task)
    if not target then return {} end
    local entries=plan(task)
    if #entries>0 then
        for _,entry in ipairs(entries) do
            entry.targetKind=target.kind;entry.target=target.name
            if target.localAction and entry.kind=='spot' then entry.question=D.QuestionForTask(task)
            elseif entry.kind=='destination' then
                local dest=D.Destination(task)
                entry.question=(target.localAction and dest and dest.context) and ('Savez-vous où se trouve '..dest.name..' ?') or D.QuestionForTask(task)
            end
        end
        return entries
    end
    -- Knowing a city or a route to it does not locate a person/object within it.
    -- Keep the question until an exact current-task clue is actually learned.
    local dest=D.Destination(task,D.Metadata(task))
    if dest then
        local known=D.InquiryKnowledge(task,dest)
        if target.kind=='place' or known.exact then return {} end
    end
    return {{planner=3,unresolved=true,kind='unresolved',task=task,target=target.name,targetKind=target.kind,
        title=task.quest.name,question=D.QuestionForTask(task),key=task.key..':unresolved:'..norm(target.name),level=1}}
end
-- In an application task the named site is the reference for the local action.
-- "Cascades au sud de Gil-Var-Delle" locates the cascades relative to Gil,
-- not Gil relative to the player. Only learned access or being there confirms it.
local knowledge=D.InquiryKnowledge
function D.InquiryKnowledge(task,dest,includeAcquired)
    local known=knowledge(task,dest,includeAcquired)
    if dest and dest.context and not B.Here(dest.name) then
        local scoped=copy(task);scoped.quest=copy(task.quest);scoped.quest.sources={}
        for _,source in ipairs(task.quest.sources) do
            if source.acquired or (source.kind or ''):find('Propos de',1,true) then scoped.quest.sources[#scoped.quest.sources+1]=source end
        end
        known.route=knowledge(scoped,dest,includeAcquired).route
    end
    return known
end
local subjects=D.Subjects
function D.Subjects(index)
    local result,groups={},{}
    for _,entry in ipairs(subjects(index)) do
        local key=(entry.kind=='spot' or entry.unresolved) and entry.key or (entry.kind..':'..norm(entry.destination)..':'..norm(entry.question))
        local previous=groups[key]
        if previous then previous.relatedTasks[#previous.relatedTasks+1]=entry.task
        else
            if entry.task then entry.relatedTasks={entry.task} end
            result[#result+1]=entry;groups[key]=entry
        end
    end
    return result
end
local reveal=D.Reveal
function D.Reveal(entry,result)
    if not reveal(entry,result) then return false end
    if entry.relatedTasks then
        for _,task in ipairs(entry.relatedTasks) do
            if task.key~=entry.task.key and D.Fresh(task) then
                local shared=copy(entry);shared.task=task;shared.relatedTasks=nil
                shared.key=task.key..entry.key:sub(#entry.task.key+1)
                reveal(shared,result)
            end
        end
    end
    return true
end
function D.RefreshSubject(entry)
    if not entry.task then return entry end
    for _,candidate in ipairs(D.Subjects(entry.task.index)) do
        if candidate.key==entry.key or (entry.unresolved and candidate.task and candidate.task.key==entry.task.key) then return candidate end
    end
end
