if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Read the current native quest page instead of rebuilding it as an NPC reply.
-- UI methods verified in the local ESO questjournal_keyboard/gamepad sources.
local B=IHR_Runtime.Beta
local J={};B.QuestJournalNavigation=J
local serial=0

local function questId(index)
    if type(GetJournalQuestId)~='function' then return end
    local id=GetJournalQuestId(index)
    if type(id)=='number' and id>0 then return id end
end
local function requestedId(q)
    local id=q and (q.journalQuestId or q.questId or q.id)
    return type(id)=='number' and id>0 and id or nil
end
-- Keep the stable native ID on every newly displayed quest. An index can be
-- reused after abandoning or finishing another quest while a menu is open.
local readQuest=B.ReadQuest
function B.ReadQuest(index,...)
    local q=readQuest(index,...)
    if q then q.journalQuestId=questId(index) end
    return q
end
local function same(q,candidate)
    if not candidate then return false end
    local id=requestedId(q)
    if id and type(GetJournalQuestId)=='function' then return questId(candidate.index)==id end
    if type(q.key)=='string' and q.key~='' then return candidate.key==q.key end
    -- Name alone is insufficient: repeated quest titles can coexist.
    return false
end
function J.Resolve(q)
    if type(q)~='table' then return nil,'invalid-quest' end
    if not requestedId(q) and (type(q.key)~='string' or q.key=='') then return nil,'invalid-quest' end
    local found
    for index=1,MAX_JOURNAL_QUESTS or 25 do
        local candidate=B.ReadQuest(index)
        if same(q,candidate) then
            if found then return nil,'ambiguous-quest' end
            found=candidate
        end
    end
    if not found then return nil,'quest-missing' end
    return found
end
local function journal()
    local owner=QUEST_JOURNAL_GAMEPAD
    local panel=ZO_QUEST_JOURNAL_QUESTS_GAMEPAD
    if owner and type(owner.OpenQuestJournalToQuest)=='function' then return owner,panel end
end
local function tell(reason)
    if type(ZO_Alert)~='function' then return end
    local missing=reason=='quest-missing' or reason=='ambiguous-quest' or reason=='invalid-quest'
    local text=missing and 'Cette quête ne peut plus être retrouvée dans votre journal.' or 'Le journal de quêtes ne peut pas être ouvert pour le moment.'
    -- Keep a navigation status out of the NPC's fictional speech.
    ZO_Alert(UI_ALERT_CATEGORY_ALERT,nil,text)
end
function J.Open(q)
    local fresh,reason=J.Resolve(q)
    if not fresh then tell(reason);return false,reason end
    if not journal() then tell('journal-unavailable');return false,'journal-unavailable' end
    local interacting=type(IsInteracting)=='function' and IsInteracting()
    local interaction=interacting and type(GetInteractionType)=='function' and GetInteractionType() or nil
    local closeNative=interaction and (interaction==INTERACTION_CONVERSATION or interaction==INTERACTION_QUEST)
    if closeNative and type(EndInteraction)~='function' then tell('interaction-unavailable');return false,'interaction-unavailable' end
    local identity={index=fresh.index,key=fresh.key,journalQuestId=fresh.journalQuestId}
    serial=serial+1;local request=serial
    B.Close() -- Restore native controls/cursor/camera through all existing hooks.
    if closeNative then
        -- Public native API, unlike selecting/accepting a quest or chatter option.
        -- The local API documentation explicitly lists EndInteraction as public.
        local ok=pcall(EndInteraction,interaction)
        if not ok then tell('interaction-error');return false,'interaction-error' end
    end
    local function open()
        if request~=serial then return end
        local current,why=J.Resolve(identity)
        if not current then tell(why);return end
        local owner,panel=journal()
        if not owner then tell('journal-unavailable');return end
        -- Queue before showing as well: an already-created native panel may
        -- receive its SHOWING callback synchronously during a scene transition.
        if panel and type(panel.QueuePendingJournalQuestIndex)=='function' then panel:QueuePendingJournalQuestIndex(current.index) end
        owner:OpenQuestJournalToQuest(current.index)
    end
    -- Let EVENT_CHATTER_END and its scene teardown complete before showing the
    -- journal, so it cannot be replaced by the native conversation's close.
    if type(zo_callLater)=='function' then zo_callLater(open,0) else open() end
    return true
end
function B.ShowEvidence(q,...) return J.Open(q) end
