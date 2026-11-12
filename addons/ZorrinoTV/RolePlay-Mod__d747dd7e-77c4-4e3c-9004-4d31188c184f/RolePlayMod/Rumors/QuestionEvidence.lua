if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Final evidence check shared by regional, native and learned-question producers.
local B=IHR_Runtime.Beta
local D=B.Dice
local C=D.Coherence
local function tag(subject,marker)
    local base=subject.inquiryBaseKey or subject.key
    if not base:find(marker,1,true) then base=base..marker end
    if subject.inquiryBaseKey then
        subject.inquiryBaseKey=base
        B.LearnedQuestions.Decorate(subject,subject.inquiryDepth)
    else subject.key=base end
end
function C.Subject(subject)
    if not subject then return end
    local q=subject.question or ''
    if C.MethodQuestion(q) and not subject.methodVerified then
        local target=subject.target or subject.destination
        local question=D.GeographicQuestion(target,subject.targetKind)
        if not question then return end
        subject.question=question
        tag(subject,':coherence161')
    end
    local text=B.Normalize(subject.question)
    if subject.targetKind=='place' and subject.target and (text:find('^ou se trouv') or text:find('^savez vous ou se trouv')) then
        subject.question=D.GeographicQuestion(subject.target,'place')
        text=B.Normalize(subject.question)
    end
    local where=text:find('^ou se trouv') or text:find('^savez vous ou se trouv') or text:find('^comment rejoindre ')
    if where and subject.targetKind=='place' and B.Here(subject.target) then return end
    if subject.unresolved then
        -- Separate social ignorance from a later verified answer to the same question.
        tag(subject,':unknown162')
    end
    return subject
end
local function filtered(list)
    local result={}
    for _,subject in ipairs(list or {}) do
        local valid=C.Subject(subject)
        if valid then result[#result+1]=valid end
    end
    return result
end
local plan=D.PlanTask
function D.PlanTask(task) return filtered(plan(task)) end
local build=B.LearnedQuestions.Build
function B.LearnedQuestions.Build(task,node,entry) return C.Subject(build(task,node,entry)) end
local subjects=D.Subjects
function D.Subjects(index) return filtered(subjects(index)) end
local followups=D.Followups
function D.Followups(entry)
    local result={}
    for _,item in ipairs(followups(entry) or {}) do
        if not item.subject then result[#result+1]=item
        elseif C.Subject(item.subject) then
            item.text=D.InquiryLabel(item.subject,item.subject.question)
            result[#result+1]=item
        end
    end
    return result
end

-- Remove only the exact erroneous add-on answer superseded by a documented method.
-- Original NPC quotations, documents, other clues and personal notes are preserved.
function C.Migrate()
    if not B.saved or B.saved.coherence161Migrated then return end
    local function obsolete(record,text)
        local id=type(record.source)=='string' and record.source:match('^Référentiel régional : (%d+) ;')
        return id and C.replaced[id] and B.Normalize(text or '')==C.replaced[id]
    end
    local saved=B.saved.investigationV1
    for i=#(saved and saved.entries or {}),1,-1 do
        local entry=saved.entries[i]
        if entry.kind=='renseignement' and obsolete(entry,entry.text) then table.remove(saved.entries,i) end
    end
    local dice=B.saved.diceV1
    for key,hint in pairs(dice and dice.hints or {}) do if obsolete(hint,hint.text) then dice.hints[key]=nil end end
    for key,result in pairs(dice and dice.rolls or {}) do if obsolete(result,result.answer) then dice.rolls[key]=nil end end
    B.saved.coherence161Migrated=true
end
local initialize=B.Initialize
function B.Initialize(...) local result=initialize(...);C.Migrate();return result end
