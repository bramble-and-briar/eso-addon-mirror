local C=CompanionSidekick
local EM=EVENT_MANAGER
local pairs,ipairs,type,tonumber,tostring=pairs,ipairs,type,tonumber,tostring
local sort,concat=table.sort,table.concat
local GetItemLink,GetItemLinkName=GetItemLink,GetItemLinkName
local GetCollectibleInfo,IsCollectibleUnlocked=GetCollectibleInfo,IsCollectibleUnlocked
local GetQuestName,HasCompletedQuest=GetQuestName,HasCompletedQuest
local function now()return GetTimeStamp()end
function C.Say(text)d("|c83d7bcCompanion Sidekick:|r "..text)end
function C.Age(stamp)
    if not stamp then return "Not scanned" end
    local minutes=math.max(0,math.floor((now()-stamp)/60))
    if minutes<1 then return "Just now" elseif minutes<60 then return minutes.."m ago" end
    return math.floor(minutes/60).."h ago"
end
function C.Discover()
    C.catalog={};C.byId={}
    local seen={}
    local function add(cid)
        if not cid or cid==0 or seen[cid] then return end
        seen[cid]=true
        local name,_,icon,_,_,_,_,kind=GetCollectibleInfo(cid)
        if name=="" or kind~=COLLECTIBLE_CATEGORY_TYPE_COMPANION then return end
        local id=GetCollectibleReferenceId(cid)
        if not id or id==0 or GetCompanionCollectibleId(id)~=cid then return end
        local perkId=GetCompanionPassivePerkAbilityId(id)
        local e={id=id,collectible=cid,name=C.Clean(GetCompanionName(id)),icon=icon,
            perkId=perkId,intro=GetCompanionIntroQuestId(id)}
        if e.name=="" then e.name=C.Clean(name)end
        C.catalog[#C.catalog+1]=e;C.byId[id]=e
    end
    for _,cid in ipairs(C.seeds)do add(cid)end
    for i=1,GetTotalCollectiblesByCategoryType(COLLECTIBLE_CATEGORY_TYPE_COMPANION)do
        add(GetCollectibleIdFromType(COLLECTIBLE_CATEGORY_TYPE_COMPANION,i))
    end
    sort(C.catalog,function(a,b)return a.name<b.name end)
end
local function QuestIds(name)
    return C.db.questIndex and C.db.questIndex[name] or (C.knownQuestIds[name] and {C.knownQuestIds[name]})
end
function C.QuestList(entry,journal)
    local result={}
    local function add(name,ids)
        local q={name=name,ids=ids}
        for _,id in ipairs(ids or {})do
            if HasCompletedQuest(id)then q.complete=true;q.name=C.Clean(GetQuestName(id));break end
        end
        if ids and not q.complete then q.complete=false end
        for _,id in ipairs(ids or {})do
            local active=journal[id]
            if active then q.active=true;q.objective=active.objective;q.name=active.name;break end
        end
        result[#result+1]=q
    end
    if entry.intro and entry.intro>0 then add(C.Clean(GetQuestName(entry.intro)),{entry.intro})
    else result[1]={name="Recruitment (not identified)"}end
    local stories=C.stories[entry.collectible]
    for _,name in ipairs(stories or {})do add(name,QuestIds(name))end
    if not stories then result[#result+1]={name="Personal quests (not indexed)"}end
    return result
end
function C.ReadJournal()
    local journal={}
    -- Quest slots can have holes, so do not stop at GetNumJournalQuests().
    for i=1,MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(i)then
            local id=GetJournalQuestId(i)
            local name,_,step,_,override=GetJournalQuestInfo(i)
            local objectives={}
            for n=1,GetJournalQuestNumConditions(i,1)do
                local text,_,_,fail,complete,_,visible=GetJournalQuestConditionInfo(i,1,n)
                if visible and not fail and text~="" then objectives[#objectives+1]=(complete and "[Done] " or "")..text end
            end
            journal[id]={name=C.Clean(name),objective=#objectives>0 and concat(objectives,"\n") or (override~="" and override or step)}
        end
    end
    return journal
end
function C.ScanCharacter()
    local char=C.Character(C.characterId,C.characterName)
    local journal=C.ReadJournal()
    for _,e in ipairs(C.catalog)do
        local r=C.GetCharacterCompanion(char,e.id)
        if e.intro and e.intro>0 then
            r.unlocked=HasCompletedQuest(e.intro)
        else r.unlocked=nil end
        if e.id==GetActiveCompanionDefId()then r.unlocked=true end
        r.quests=C.QuestList(e,journal);r.seen=now()
        if e.keepsake then e.keepsakeUnlocked=IsCollectibleUnlocked(e.keepsake)end
    end
    char.seen=now()
end
function C.ScanActive()
    local id=GetActiveCompanionDefId()
    local entry=C.byId[id]
    if not entry then return end
    local level,xp=GetActiveCompanionLevelInfo()
    if not level or level<1 then return end
    local shared=C.db.shared[id] or {};C.db.shared[id]=shared
    local r=C.GetCharacterCompanion(C.db.characters[C.characterId],id)
    r.unlocked=true;r.rapport=GetActiveCompanionRapport();r.rapportLevel=GetActiveCompanionRapportLevel()
    r.rapportName=GetString("SI_COMPANIONRAPPORTLEVEL",r.rapportLevel)
    r.rapportMin=GetMinimumRapport();r.rapportMax=GetMaximumRapport();r.rapportSeen=now()
    shared.level=level;shared.xp=xp;shared.seen=now()
    local gear={}
    for _,slot in ipairs(C.equipmentSlots)do
        local link=GetItemLink(BAG_COMPANION_WORN,slot,LINK_STYLE_DEFAULT)
        local item={slot=slot,link=link}
        if link~="" then
            item.name=C.Clean(GetItemLinkName(link));item.quality=GetItemLinkDisplayQuality(link)
            item.trait=GetItemLinkTraitInfo(link);item.armor=GetItemLinkArmorType(link);item.weapon=GetItemLinkWeaponType(link)
        end
        gear[#gear+1]=item
    end
    if GetActiveCompanionDefId()~=id then return end
    shared.gear=gear;shared.gearSeen=now()
    if AreCompanionSkillsInitialized()then
        local bar,lines={},{}
        for slot=3,8 do
            local ability=GetSlotBoundId(slot,HOTBAR_CATEGORY_COMPANION)
            bar[#bar+1]={slot=slot,id=ability,name=ability>0 and C.Clean(GetAbilityName(ability)) or "Empty",
                icon=ability>0 and GetAbilityIcon(ability) or nil}
        end
        for skillType=1,GetNumSkillTypes()do
            for i=1,GetNumCompanionSkillLines(skillType)do
                local lineId=GetCompanionSkillLineId(skillType,i)
                local rank,active,discovered=GetCompanionSkillLineDynamicInfo(lineId)
                local lastXP,nextXP,currentXP=GetCompanionSkillLineXPInfo(lineId)
                local line={id=lineId,name=C.Clean(GetCompanionSkillLineNameById(lineId)),rank=rank,active=active,
                    discovered=discovered,lastXP=lastXP,nextXP=nextXP,xp=currentXP,abilities={}}
                for n=1,GetNumAbilitiesInCompanionSkillLine(lineId)do
                    local a=GetCompanionAbilityId(lineId,n)
                    line.abilities[#line.abilities+1]={id=a,name=C.Clean(GetAbilityName(a)),
                        unlocked=IsCompanionAbilityUnlocked(a),passive=IsAbilityPassive(a),required=GetCompanionAbilityRankRequired(a)}
                end
                lines[#lines+1]=line
            end
        end
        if GetActiveCompanionDefId()==id then shared.bar=bar;shared.lines=lines;shared.skillsSeen=now()end
    end
end
function C.Refresh()
    if not C.db then return end
    C.ScanCharacter();C.ScanActive()
    if C.Render then C.Render()end
end
function C.Schedule()
    EM:UnregisterForUpdate(C.name.."Refresh")
    EM:RegisterForUpdate(C.name.."Refresh",350,function()
        EM:UnregisterForUpdate(C.name.."Refresh");C.Refresh()
    end)
end
-- Build optional data indexes once per client language/API. Work is spread
-- over frames; no library, English quest-name API, or guessed numeric IDs needed.
function C.BuildIndexes()
    local language=GetCVar("language.2")
    local key=tostring(GetAPIVersion())..":"..language
    C.db.questIndex=C.db.questIndex or {}
    C.db.perkIndex=C.db.perkIndex or {}
    for _,e in ipairs(C.catalog)do
        local cache=C.db.perkIndex[e.id]
        if cache then e.keepsake=cache.collectible;e.achievement=cache.achievement end
    end
    if C.db.indexKey==key then C.indexing=false;return end
    C.indexing=true;C.db.questIndex={};C.db.perkIndex={}
    local wanted={}
    for _,list in pairs(C.stories)do for _,name in ipairs(list)do wanted[string.lower(name)]=name end end
    for alias,name in pairs(C.aliases)do wanted[string.lower(alias)]=name end
    local jobs={};local nextQuest=1
    -- Index collections for keepsakes using the exact localized passive name in
    -- the game's collectible description. Ambiguous matches remain unknown.
    for cat=1,GetNumCollectibleCategories()do
        local _,subCount,count=GetCollectibleCategoryInfo(cat)
        for i=1,count do jobs[#jobs+1]={cat,nil,i}end
        for sub=1,subCount do
            local _,n=GetCollectibleSubCategoryInfo(cat,sub)
            for i=1,n do jobs[#jobs+1]={cat,sub,i}end
        end
    end
    local cursor=1;local rewards={};local achievementJobs={}
    for cat=1,GetNumAchievementCategories()do
        local _,subCount,count=GetAchievementCategoryInfo(cat)
        for i=1,count do achievementJobs[#achievementJobs+1]=GetAchievementId(cat,nil,i)end
        for sub=1,subCount do
            local _,n=GetAchievementSubCategoryInfo(cat,sub)
            for i=1,n do achievementJobs[#achievementJobs+1]=GetAchievementId(cat,sub,i)end
        end
    end
    local achievementCursor=1;local candidates={}
    EM:RegisterForUpdate(C.name.."Index",20,function()
        for _=1,150 do
            if nextQuest<=15000 then
                local id=nextQuest;nextQuest=nextQuest+1
                local raw=string.lower(C.Clean(GetQuestName(id)))
                local name=wanted[raw]
                if name then
                    C.db.questIndex[name]=C.db.questIndex[name] or {}
                    table.insert(C.db.questIndex[name],id)
                end
            elseif cursor<=#jobs then
                local job=jobs[cursor];cursor=cursor+1
                local cid=GetCollectibleId(job[1],job[2],job[3])
                local description=string.lower(C.Clean(GetCollectibleDescription(cid)))
                for _,e in ipairs(C.catalog)do
                    local perk=string.lower(C.Clean(GetAbilityName(e.perkId)))
                    if perk~="" and description:find(perk,1,true) and cid~=e.collectible then
                        candidates[e.id]=candidates[e.id] or {};candidates[e.id][cid]=true
                    end
                end
            elseif achievementCursor<=#achievementJobs then
                local aid=achievementJobs[achievementCursor];achievementCursor=achievementCursor+1
                local has,cid=GetAchievementRewardCollectible(aid)
                if has then rewards[cid]=aid end
            else
                for _,e in ipairs(C.catalog)do
                    local chosen
                    for cid in pairs(candidates[e.id] or {})do
                        if rewards[cid]then if chosen then chosen=nil;break else chosen=cid end end
                    end
                    if chosen then
                        e.keepsake=chosen;e.achievement=rewards[chosen]
                        C.db.perkIndex[e.id]={collectible=chosen,achievement=e.achievement}
                    end
                end
                C.indexing=false;C.db.indexKey=key
                EM:UnregisterForUpdate(C.name.."Index");C.Refresh();return
            end
        end
    end)
end
function C.KeepsakeText(e)
    if not e.keepsake then return C.indexing and "Checking..." or "Unknown" end
    return e.keepsakeUnlocked and "Permanent" or "Not earned"
end
function C.Requirements(e)
    local rows={}
    if not e.achievement then return {"Keepsake requirements not identified by this client's collection data."}end
    local name=GetAchievementInfo(e.achievement)
    rows[#rows+1]=C.Clean(name)
    for i=1,GetAchievementNumCriteria(e.achievement)do
        local text,done,total=GetAchievementCriterion(e.achievement,i)
        rows[#rows+1]=string.format("%s %s (%d/%d)",done>=total and "[Done]" or "[ ]",C.Clean(text),done,total)
    end
    return rows
end
function C.Init(_,name)
    if name~=C.name then return end
    EM:UnregisterForEvent(C.name,EVENT_ADD_ON_LOADED)
    C.InitStore(ZO_SavedVars:NewAccountWide("CompanionSidekickSavedVariables",1,nil,
        {characters={},shared={},settings={scale=.85}},GetWorldName()))
    C.characterId=GetCurrentCharacterId();C.characterName=C.Clean(GetUnitName("player"))
    for i=1,GetNumCharacters()do
        local n,_,_,_,_,_,id=GetCharacterInfo(i);C.Character(id,C.Clean(n))
    end
    C.equipmentSlots={EQUIP_SLOT_HEAD,EQUIP_SLOT_SHOULDERS,EQUIP_SLOT_CHEST,EQUIP_SLOT_HAND,
        EQUIP_SLOT_WAIST,EQUIP_SLOT_LEGS,EQUIP_SLOT_FEET,EQUIP_SLOT_NECK,EQUIP_SLOT_RING1,EQUIP_SLOT_RING2,
        EQUIP_SLOT_MAIN_HAND,EQUIP_SLOT_OFF_HAND}
    C.Discover();C.CreateUI();C.BuildIndexes()
    local function command(arg)
        arg=string.lower(arg or "")
        if arg=="refresh" then C.Refresh();return end
        if arg=="help" then C.ShowHelp();return end
        if arg=="colors" or arg=="size" then C.ShowAppearance();return end
        local scale=tonumber(arg:match("^scale%s+(%d+)$"))
        if scale then
            C.SetScalePercent(scale);return
        end
        C.window:SetHidden(not C.window:IsHidden())
        if not C.window:IsHidden()then C.Refresh()end
    end
    SLASH_COMMANDS["/csidekick"]=command
    if not SLASH_COMMANDS["/companions"]then SLASH_COMMANDS["/companions"]=command end
    local events={EVENT_PLAYER_ACTIVATED,EVENT_COMPANION_ACTIVATED,EVENT_COMPANION_DEACTIVATED,
        EVENT_COMPANION_RAPPORT_UPDATE,EVENT_COMPANION_EXPERIENCE_GAIN,EVENT_COMPANION_SKILLS_FULL_UPDATE,
        EVENT_COMPANION_SKILL_RANK_UPDATE,EVENT_COMPANION_SKILL_XP_UPDATE,
        EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED,EVENT_QUEST_ADDED,EVENT_QUEST_ADVANCED,
        EVENT_QUEST_REMOVED,EVENT_QUEST_COMPLETE,EVENT_COLLECTIBLE_UPDATED,EVENT_ACHIEVEMENT_UPDATED}
    for _,event in ipairs(events)do EM:RegisterForEvent(C.name,event,C.Schedule)end
    EM:RegisterForEvent(C.name,EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function(_,bag)
        if bag==BAG_COMPANION_WORN then C.Schedule()end
    end)
    C.Refresh()
end
EM:RegisterForEvent(C.name,EVENT_ADD_ON_LOADED,C.Init)
