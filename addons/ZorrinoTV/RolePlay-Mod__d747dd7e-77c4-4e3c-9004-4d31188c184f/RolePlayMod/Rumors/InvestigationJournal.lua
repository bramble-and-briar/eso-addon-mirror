if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Acquired evidence only. Reference data is never automatically learned.
local B=IHR_Runtime.Beta
local D=B.Dice
local J={}
B.Investigation=J
local function norm(s) return B.Normalize(s or '') end
local function canon(s) return D.ObjectiveCanonical and D.ObjectiveCanonical(s or '') or norm(s) end
local function choice(text,callback) return {text=text,callback=callback} end
local function clean(s) return type(s)=='string' and s:gsub('|c%x%x%x%x%x%x',''):gsub('|r',''):gsub('%^%a+','') or '' end
function J.Saved()
    if not B.saved then return end
    B.saved.investigationV1=B.saved.investigationV1 or {entries={},nextId=0}
    return B.saved.investigationV1
end
function J.Record(data)
    local saved=J.Saved();if not saved then return end
    local text=clean(data.text);if norm(text)=='' then return end
    for _,entry in ipairs(saved.entries) do
        if entry.kind==data.kind and norm(entry.text)==norm(text) and norm(entry.speaker)==norm(data.speaker) and norm(entry.title)==norm(data.title) and entry.questKey==data.questKey and entry.taskKey==data.taskKey then return entry end
    end
    saved.nextId=saved.nextId+1
    local entry={id=saved.nextId,time=GetTimeStamp(),text=text}
    for _,key in ipairs({'kind','speaker','title','locality','questKey','questName','taskKey','taskText','stepText','source','factKind','level','destination','originZone','originX','originZ','scopeRadius','relatedObjectives','unverified','inquiryDepth'}) do entry[key]=data[key] end
    -- If this same displayed speech was archived before quest acceptance, bind it.
    if data.questKey and data.kind=='dialogue' then
        for i=#saved.entries,1,-1 do
            local old=saved.entries[i]
            if not old.questKey and old.kind==data.kind and norm(old.text)==norm(text) and norm(old.speaker)==norm(data.speaker) then table.remove(saved.entries,i) end
        end
    end
    saved.entries[#saved.entries+1]=entry
    if J.Refresh then J.Refresh() end
    return entry
end
function J.Entries(key)
    local saved=J.Saved();local entries={}
    for _,entry in ipairs(saved and saved.entries or {}) do if entry.questKey==key then entries[#entries+1]=entry end end
    return entries
end
function J.Excerpt(entry)
    local text=RPM_LOCALE.Text(entry.kind=='renseignement' and D.GeographicNoteFR and D.GeographicNoteFR(entry) or entry.text or '')
    if entry.kind=='renseignement' and D.CleanRouteText then text=D.CleanRouteText(text) end
    if #text<=650 then return text end
    local stop=650
    while text:byte(stop+1) and text:byte(stop+1)>=128 and text:byte(stop+1)<192 do stop=stop-1 end
    local excerpt=text:sub(1,stop)
    return (excerpt:match('^(.*)[ \t\r\n]') or excerpt)..'… (texte complet dans le carnet)'
end
function J.Label(entry)
    return entry.kind=='document' and ('Lecture : '..(entry.title or 'Document')) or ('Propos de '..(entry.speaker or 'un interlocuteur'))
end
function J.Format(entry)
    local location=entry.locality and B.Name(entry.locality) or ''
    local heading=J.Label(entry)..(location~='' and (' — '..location) or '')
    return heading..'\n'..J.Excerpt(entry)
end
function J.ForObjective(entry,stepText,taskText)
    return (entry.taskText and canon(entry.taskText)==canon(taskText) and (not entry.stepText or canon(entry.stepText)==canon(stepText)))
        or (entry.relatedObjectives and entry.relatedObjectives[canon(stepText)..'\n'..canon(taskText)])
end
function J.Lines(q,taskText,stepText,used)
    local lines,seen,facts={},{},{}
    local entries=J.Entries(q.key)
    for i=#entries,1,-1 do
        local entry=entries[i]
        -- Raw conversations/documents remain evidence for follow-up questions,
        -- but only an acquired answer is appended to the native task display.
        local match=(entry.kind=='renseignement' or entry.kind=='temoignage') and (not taskText or J.ForObjective(entry,stepText,taskText)) and not (used and used[entry.id or entry])
        local textKey=norm(entry.text)
        local fact=entry.factKind and entry.destination and (entry.factKind..':'..norm(entry.destination)) or nil
        local superseded=false
        if entry.factKind=='destination' and entry.destination then
            for _,other in ipairs(entries) do
                if other.factKind=='route' and norm(other.destination)==norm(entry.destination) and canon(other.taskText)==canon(entry.taskText) and canon(other.stepText)==canon(entry.stepText) then superseded=true end
            end
        end
        if match and not superseded and not seen[textKey] and (not fact or not facts[fact]) then
            seen[textKey]=true;if fact then facts[fact]=true end
            table.insert(lines,1,J.Format(entry));if used then used[entry.id or entry]=true end
        end
    end
    return #lines>0 and ('\n\n'..table.concat(lines,'\n\n')) or ''
end
function B.GetAcquiredQuestHint(index,stepText,conditionText)
    local q=B.ReadQuest(index);return q and J.Lines(q,conditionText,stepText) or ''
end
local readQuest=B.ReadQuest
function B.ReadQuest(index)
    local q=readQuest(index);if not q then return end
    for _,entry in ipairs(J.Entries(q.key)) do
        local relevant=not entry.taskText
        if entry.taskText then
            for step=1,GetJournalQuestNumSteps(index) do
                local stepText,visibility,_,_,count=GetJournalQuestStepInfo(index,step)
                if visibility~=QUEST_STEP_VISIBILITY_HIDDEN then
                    for c=1,count or 0 do
                        local text,_,_,fail,done,_,visible=GetJournalQuestConditionInfo(index,step,c,false)
                        if visible and not fail and not done and J.ForObjective(entry,stepText,text) then relevant=true end
                    end
                end
            end
        end
        if relevant and not entry.unverified then
            local duplicate=false
            for _,source in ipairs(q.sources) do if norm(source.text)==norm(entry.text) then duplicate=true end end
            if not duplicate then q.sources[#q.sources+1]={text=entry.text,kind=J.Label(entry),objective=entry.taskText,acquired=true,source=entry.source,inquiryDepth=entry.inquiryDepth,factKind=entry.factKind,locality=entry.locality,originZone=entry.originZone,originX=entry.originX,originZ=entry.originZ,scopeRadius=entry.scopeRadius} end
        end
    end
    return q
end
local reveal=D.Reveal
function D.Reveal(subject,result)
    if subject.unresolved then return false end
    if not reveal(subject,result) then return false end
    if subject.task then
        local task=subject.task
        local related
        if subject.relatedTasks and #subject.relatedTasks>1 then
            related={}
            for _,other in ipairs(subject.relatedTasks) do related[canon(other.stepText)..'\n'..canon(other.text)]=true end
        end
        J.Record({kind='renseignement',text=result.answer,speaker=B.Name(result.npc),locality=B.Name(result.locality),questKey=task.questKey,questName=task.quest.name,taskKey=task.key,taskText=task.text,stepText=task.stepText,relatedObjectives=related,source=result.source,factKind=subject.kind,level=result.level,destination=subject.destination,originZone=result.originZone,originX=result.originX,originZ=result.originZ,scopeRadius=subject.scopeRadius})
    end
    return true
end
-- Directional knowledge is tied to the place where it was obtained.
local function origin()
    if type(GetUnitWorldPosition)~='function' then return end
    local zone,x,_,z=GetUnitWorldPosition('player')
    if type(zone)=='number' and type(x)=='number' and type(z)=='number' then return zone,x,z end
end
function D.SameOrigin(entry)
    local zone,x,z=origin()
    if not zone or entry.originZone~=zone or type(entry.originX)~='number' or type(entry.originZ)~='number' then return false end
    local radius=entry.scopeRadius or 10000 -- 100 m in ESO's world coordinates; local details use 25 m.
    return (entry.originX-x)^2+(entry.originZ-z)^2<=radius^2
end
local function geographic(text)
    if D.GeographicDirections(text) then return true end
    text=' '..norm(text)..' '
    for _,word in ipairs({'tout pres','sur place','y etes'}) do if text:find(' '..word..' ',1,true) then return true end end
    return false
end
local inquiryKnowledge=D.InquiryKnowledge
function D.InquiryKnowledge(task,destination,includeAcquired)
    local copy={};for k,v in pairs(task) do copy[k]=v end
    copy.quest={};for k,v in pairs(task.quest) do copy.quest[k]=v end
    copy.quest.sources={}
    for _,source in ipairs(task.quest.sources) do
        if source.acquired and geographic(source.text) and not D.SameOrigin(source) then
            -- Retain the learned identity, but not an old direction from somewhere else.
            copy.quest.sources[#copy.quest.sources+1]={text=destination and destination.name or '',kind=source.kind}
        else copy.quest.sources[#copy.quest.sources+1]=source end
    end
    local known=inquiryKnowledge(copy,destination,false)
    if not destination or includeAcquired==false then return known end
    local function bare(name) return norm(name):gsub('^les ',''):gsub('^le ',''):gsub('^la ',''):gsub('^l ','') end
    for _,hint in pairs(D.Saved().hints) do
        if hint.taskKey==task.key and (not hint.destination or bare(hint.destination)==bare(destination.name)) then
            if hint.factKind=='destination' or hint.factKind=='route' or hint.factKind=='region' or hint.factKind=='spot' then known.identity=true end
            if hint.factKind=='route' and geographic(hint.text) and D.SameOrigin(hint) then known.route=true end
            if hint.factKind=='region' then known.region=true end
            if hint.factKind=='spot' and norm(hint.taskText)==norm(task.text) and D.SameOrigin(hint) then known.exact=true end
            if not hint.factKind and geographic(hint.text) and D.SameOrigin(hint) then known.route=true end
        end
    end
    return known
end
local planTask=D.PlanTask
function D.PlanTask(task)
    local entries=planTask(task)
    local zone,x,z=origin()
    if not zone then return entries end
    local saved=D.Saved();saved.inquiryOrigins=saved.inquiryOrigins or {}
    for _,entry in ipairs(entries) do
        local list=saved.inquiryOrigins[entry.key] or {};saved.inquiryOrigins[entry.key]=list
        local radius=entry.kind=='spot' and 2500 or 10000
        local scope
        for i,point in ipairs(list) do if D.SameOrigin(point) then scope=i;break end end
        if not scope then
            scope=#list+1;list[scope]={originZone=zone,originX=x,originZ=z,scopeRadius=radius}
        end
        entry.key=entry.key..':origin:'..scope
        entry.originZone=zone;entry.originX=x;entry.originZ=z;entry.scopeRadius=radius
    end
    return entries
end
local roll=D.Roll
function D.Roll(subject,npc)
    local result,err,cached=roll(subject,npc)
    -- A menu can be opened at a sector boundary. Validate the actual roll origin,
    -- not just the menu's scope, before reusing a direction or a refusal.
    if result and cached and subject.task and not D.SameOrigin(result) then
        local key=(B.RelationKey(npc) or B.Profile(npc).key)..':'..subject.key..':'..subject.level
        D.Saved().rolls[key]=nil
        result,err,cached=roll(subject,npc)
    end
    if result and not cached then
        result.originZone,result.originX,result.originZ=origin()
        result.scopeRadius=subject.scopeRadius
    end
    return result,err,cached
end
-- Known names and known directions remain separate. No forced review menu.
function D.ReviewSubjects() return {} end
function J.ShowQuestions(q) B.ShowQuest(B.ReadQuest(q.index)) end
function J.ShowSource(entry)
    local choices={}
    if not entry.questKey then
        choices[#choices+1]=choice('(Classer cette information dans une quête.)',function()
            local quests={}
            for _,q in ipairs(B.Quests()) do local target=q
                quests[#quests+1]=choice(target.name,function()
                    local tasks={choice('(Conserver pour cette quête, sans objectif précis.)',function() entry.questKey=target.key;entry.questName=target.name;J.Refresh();J.ShowSource(entry) end)}
                    for _,t in ipairs(D.Tasks(target.index)) do local task=t
                        tasks[#tasks+1]=choice(task.text,function()
                            entry.questKey=target.key;entry.questName=target.name;entry.taskKey=task.key;entry.taskText=task.text;entry.stepText=task.stepText;J.Refresh();J.ShowSource(entry)
                        end)
                    end
                    B.Show('Classer : '..target.name,'À quel objectif rattacher ce texte ?',tasks,true)
                end)
            end
            B.Show('Classer cette information','Choisissez la quête concernée.',quests,true)
        end)
    end
    choices[#choices+1]=choice('Revenir au carnet.',function() B.ShowNotebook() end)
    B.Show(J.Label(entry),(entry.questName and ('Quête : '..entry.questName..'\n\n') or '')..entry.text,choices,true)
end
local previousEvidence=B.ShowEvidence
function B.ShowEvidence(q,selected)
    if selected then return previousEvidence(q,selected) end
    local choices={}
    for _,entry in ipairs(J.Entries(q.key)) do local source=entry
        choices[#choices+1]=choice(J.Label(source)..(source.taskText and (' — '..source.taskText) or ''),function() J.ShowSource(source) end)
    end
    choices[#choices+1]=choice('(Relire le journal original du jeu.)',function() previousEvidence(q,1) end)
    choices[#choices+1]=choice('Revenir aux questions.',function() B.ShowQuest(B.ReadQuest(q.index)) end)
    B.Show(q.name..' · Informations recueillies',#choices>2 and 'Les paroles et lectures recueillies pour cette affaire.' or 'Aucun renseignement recueilli pour cette affaire. Le journal original reste consultable.',choices,true)
end
function B.ShowNotebook()
    local choices,groups={},{}
    for _,entry in ipairs(J.Saved().entries) do if entry.questKey then groups[entry.questKey]=entry.questName or entry.questKey end end
    local keys={};for key in pairs(groups) do keys[#keys+1]=key end;table.sort(keys)
    for _,key in ipairs(keys) do local questKey=key
        choices[#choices+1]=choice(groups[key],function()
            local sources={}
            for _,entry in ipairs(J.Entries(questKey)) do local e=entry;sources[#sources+1]=choice(J.Label(e),function() J.ShowSource(e) end) end
            B.Show(groups[questKey],'Toutes les informations recueillies, y compris celles des étapes précédentes.',sources,true)
        end)
    end
    choices[#choices+1]=choice('Paroles et documents à classer.',function()
        local sources={}
        for _,entry in ipairs(J.Entries(nil)) do local e=entry;sources[#sources+1]=choice(J.Label(e),function() J.ShowSource(e) end) end
        B.Show('Sources à classer',#sources>0 and 'Ces textes ont été entendus ou ouverts. Choisissez une source pour la rattacher à une quête.' or 'Aucune nouvelle source à classer.',sources,true)
    end)
    B.Show('Mon journal d’enquête','Seules les informations réellement obtenues sont consignées ici.',choices,true)
end
function J.Open()
    if not B.npc then
        local zone,x,y,z=GetUnitWorldPosition('player')
        B.npc={name='Mon journal',zoneIndex=GetUnitZoneIndex('player'),zoneId=zone,x=x,y=y,z=z,locality=''}
        B.ownsCursor=not IsGameCameraUIModeActive();SetGameCameraUIMode(true)
    end
    B.ShowNotebook()
end
local function contains(text,name) return #name>=5 and (' '..norm(text)..' '):find(' '..name..' ',1,true)~=nil end
function J.Associate(text,speaker)
    local found={}
    for _,q in ipairs(B.Quests()) do for _,task in ipairs(D.Tasks(q.index)) do
        local hit=speaker and norm(speaker)~='' and contains(task.text,norm(speaker))
        if not hit then
            local position=0
            for token in task.text:gmatch('[^ \t\r\n]+') do
                position=position+1
                token=token:gsub('[,%.:;!?]+$','')
                if position>1 and token~=zo_strlower(token) and contains(text,norm(token)) then hit=true end
            end
        end
        if hit then found[#found+1]={q=q,task=task} end
    end end
    if #found==1 then return found[1].q,found[1].task end
    if #found>1 then local key=found[1].q.key;for _,match in ipairs(found) do if match.q.key~=key then return end end;return found[1].q end
end
function J.Capture(kind,text,speaker,title)
    if not B.saved or not B.saved.enabled or #norm(text)<12 then return end
    local q,task=J.Associate(text,speaker)
    return J.Record({kind=kind,text=text,speaker=speaker,title=title,questKey=q and q.key,questName=q and q.name,taskKey=task and task.key,taskText=task and task.text,stepText=task and task.stepText,source=kind=='document' and 'Document ouvert dans le client' or 'Dialogue affiché dans le client'})
end
function J.CaptureDialogue()
    if not B.saved or not B.saved.enabled then return end
    local speaker=B.Name(GetUnitName('interact'));if speaker=='' then return end
    local handles=ImmersiveData and ImmersiveData.handles
    local label=(handles and handles.TargetAreaBodyText) or ZO_InteractWindowTargetAreaBodyText
    if label and type(label.GetText)=='function' and (not label.IsHidden or not label:IsHidden()) then J.Capture('dialogue',label:GetText(),speaker) end
end
function J.Decorate(index,strings)
    if not B.saved or not RolePlayMod.Enabled('journal') or type(strings)~='table' then return end
    local q=B.ReadQuest(index);if not q then return end
    local used={}
    for _,row in ipairs(strings) do if type(row)=='table' and type(row.name)=='string' and not row.isComplete then
        local base=row.ihrOriginal or row.name;row.ihrOriginal=base
        local step=select(3,GetJournalQuestInfo(index)) or ''
        for _,task in ipairs(D.Tasks(index)) do if canon(task.text)==canon(base) then step=task.stepText;break end end
        row.name=base..J.Lines(q,base,step,used)
        if J.rendered then
            for _,entry in ipairs(J.Entries(q.key)) do
                if used[entry.id or entry] then J.rendered[entry.id or entry]=true end
            end
        end
    end end
end
function J.Refresh()
    if J.refreshing then return end;J.refreshing=true
    local ok,err=pcall(function()
        for _,ui in pairs({ZO_QUEST_JOURNAL_QUESTS_KEYBOARD,ZO_QUEST_JOURNAL_QUESTS_GAMEPAD}) do
            if ui and ui.control and not ui.control:IsHidden() and type(ui.RefreshDetails)=='function' then ui:RefreshDetails() end
        end
    end)
    J.refreshing=false
    if not ok and not J.refreshWarning then
        J.refreshWarning=true
        if type(d)=='function' then d('[RolePlayMod] Le renseignement est enregistré. Rafraîchissement du journal indisponible : '..tostring(err)) end
    end
end
function J.HookJournal()
    if not SecurePostHook or not QUEST_JOURNAL_MANAGER then return end
    if not J.managerHooked then
        local manager=QUEST_JOURNAL_MANAGER
        if type(manager.BuildTextForTasks)=='function' then SecurePostHook(manager,'BuildTextForTasks',function(_,_,index,strings) J.Decorate(index,strings) end) end
        if type(manager.BuildTextForConditions)=='function' then SecurePostHook(manager,'BuildTextForConditions',function(_,index,_,_,strings) J.Decorate(index,strings) end) end
        J.managerHooked=true
    end
    J.uiHooked=J.uiHooked or {}
    for _,ui in pairs({ZO_QUEST_JOURNAL_QUESTS_KEYBOARD,ZO_QUEST_JOURNAL_QUESTS_GAMEPAD}) do
        if type(ui)=='table' and type(ui.RefreshDetails)=='function' and not J.uiHooked[ui] then
            if ZO_PreHook then ZO_PreHook(ui,'RefreshDetails',function() J.rendered={} end) end
            SecurePostHook(ui,'RefreshDetails',function(self)
                local index
                if type(self.GetSelectedQuestData)=='function' then
                    local selected=self:GetSelectedQuestData();index=selected and selected.questIndex
                elseif type(self.GetSelectedQuestIndex)=='function' then index=self:GetSelectedQuestIndex() end
                local q=index and B.ReadQuest(index)
                if q and self.stepText and self.stepText.GetText then
                    -- The native narrative is not an automatic transcript archive.
                    -- Acquired answers are already displayed under their relevant task.
                    local text=self.stepText:GetText() or ''
                    text=text:match('^(.-)\n\nInformations recueillies :') or text
                    self.stepText:SetText(text)
                end
            end)
            J.uiHooked[ui]=true
        end
    end
end
function J.ResetKwamasTestNotes()
    local saved=J.Saved()
    if not saved or B.saved.kwamasCleanup0132 then return end
    local function matches(key)
        return type(key)=='string' and norm(key:match('^%d+:(.+)$') or '')=='elever des kwamas'
    end
    for i=#saved.entries,1,-1 do if matches(saved.entries[i].questKey) then table.remove(saved.entries,i) end end
    for key in pairs(B.saved.notes or {}) do if matches(key) then B.saved.notes[key]=nil end end
    for i=#(B.saved.notebook or {}),1,-1 do if matches(B.saved.notebook[i].questKey) then table.remove(B.saved.notebook,i) end end
    local dice=D.Saved()
    for key,hint in pairs(dice.hints) do if matches(hint.questKey) then dice.hints[key]=nil end end
    for _,bucket in pairs({dice.targets,dice.rolls,dice.inquiryOrigins,D.positions,D.pending,D.requested}) do
        for key in pairs(bucket or {}) do
            if tostring(key):find(':elever des kwamas:',1,true) then bucket[key]=nil end
        end
    end
    B.saved.kwamasCleanup0132=true
end
function J.Initialize()
    local saved=J.Saved();if not saved then return end
    if not saved.migrated then
        for _,hint in pairs(D.Saved().hints) do
            local qname=hint.questKey
            for _,q in ipairs(B.Quests()) do if q.key==hint.questKey then qname=q.name end end
            J.Record({kind='renseignement',text=hint.text,speaker=hint.npc,locality=hint.locality,questKey=hint.questKey,questName=qname,taskKey=hint.taskKey,taskText=hint.taskText,stepText=hint.stepText,source=hint.source,factKind=hint.factKind,level=hint.level,destination=hint.destination})
        end
        for key,note in pairs(B.saved.notes or {}) do J.Record({kind='dialogue',text=note.text,speaker=note.npc,questKey=key,questName=key,source='Dialogue de quête précédemment entendu'}) end
        saved.migrated=true
    end
    J.ResetKwamasTestNotes()
    -- Correct only add-on-generated directions, never original NPC/book quotations.
    if D.CleanRouteText then
        for _,entry in ipairs(saved.entries) do if entry.kind=='renseignement' then entry.text=D.CleanRouteText(entry.text) end end
        for _,hint in pairs(D.Saved().hints) do hint.text=D.CleanRouteText(hint.text) end
        for _,result in pairs(D.Saved().rolls) do result.answer=D.CleanRouteText(result.answer) end
    end
    J.HookJournal()
end
local function event(name,id,callback) if id then EVENT_MANAGER:RegisterForEvent(name,id,callback) end end
local initialized=B.Initialize
function B.Initialize(...) local result=initialized(...);J.Initialize();return result end
-- B.Initialize also works if the SavedVariables initialization callback runs first.
event('IHRJournalActivated',EVENT_PLAYER_ACTIVATED,function() J.Initialize() end)
event('IHRJournalDialogue',EVENT_CONVERSATION_UPDATED,function() if zo_callLater then zo_callLater(J.CaptureDialogue,150) end end)
event('IHRJournalChatter',EVENT_CHATTER_BEGIN,function() if zo_callLater then zo_callLater(J.CaptureDialogue,150) end end)
event('IHRJournalBook',EVENT_SHOW_BOOK,function(_,title,body) J.Capture('document',body,nil,clean(title)) end)
event('IHRJournalOffered',EVENT_QUEST_OFFERED,function()
    if not B.saved or not B.saved.enabled then return end
    J.offer=nil
    local text=GetOfferedQuestInfo();local speaker=B.Name(GetUnitName('interact'))
    if type(text)=='string' and text~='' and speaker~='' then J.offer={text=text,speaker=speaker,time=GetTimeStamp()} end
end)
event('IHRJournalShared',EVENT_QUEST_SHARED,function() J.offer=nil end)
event('IHRJournalAdded',EVENT_QUEST_ADDED,function(_,index)
    local offer=J.offer;J.offer=nil;local q=B.ReadQuest(index)
    if q and offer and GetTimeStamp()-offer.time<120 and B.Name(GetUnitName('interact'))==offer.speaker then J.Record({kind='dialogue',text=offer.text,speaker=offer.speaker,questKey=q.key,questName=q.name,source='Offre de quête acceptée'}) end
end)
if SLASH_COMMANDS then SLASH_COMMANDS['/ihrjournal']=J.Open end
