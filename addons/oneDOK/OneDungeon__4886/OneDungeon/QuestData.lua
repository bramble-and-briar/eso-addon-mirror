local A = OneDungeon

function A:ReadQuests()
    if self.questCache then return self.questCache end
    local state = { today = {}, active = {}, scheduleKnown = false }
    for index = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(index) and GetJournalQuestType(index) == QUEST_TYPE_UNDAUNTED_PLEDGE then
            local id = GetJournalQuestId(index)
            state.active[id] = true
        end
    end
    local today = self:Optional("daily pledges", function() return self:ReadTodaysPledges() end)
    if today then state.today, state.scheduleKnown = today, true end
    self.questCache = state
    return state
end

function A:GetQuestState(row)
    local state = self:ReadQuests()
    local result = { story = "unknown", today = "unknown", active = "unknown" }
    local entry = self.catalog[row.zoneId] or {}
    local questId = entry.storyQuestId or self.storyQuests[row.normalActivityId] or self.storyQuests[row.veteranActivityId]
    -- Curated identity is authoritative here: quest starting zones may be outside
    -- the dungeon. Reject missing client quest records, not differing starting zones.
    local questName = questId and GetQuestName(questId)
    if questName and questName ~= "" then
        result.storyQuestId = questId
        if HasQuest(questId) then result.story = "active"
        elseif HasCompletedQuest(questId) then result.story = "completed"
        else result.story = "unfinished" end
    end
    if entry.pledgeQuestId then
        result.pledgeQuestId = entry.pledgeQuestId
        result.active = state.active[entry.pledgeQuestId] == true
        if state.scheduleKnown then result.today = state.today[row.zoneId] == true end
    end
    return result
end

function A:QuestPresentation(state)
    local labels, tips = {}, {}
    if state.story == "active" then
        labels[#labels + 1] = GetString(ONEDUNGEON_STORY_ACTIVE)
        tips[#tips + 1] = GetString(ONEDUNGEON_STORY_ACTIVE_TIP)
    elseif state.story == "unfinished" then
        labels[#labels + 1] = GetString(ONEDUNGEON_STORY_UNFINISHED)
        tips[#tips + 1] = GetString(ONEDUNGEON_STORY_UNFINISHED_TIP)
    elseif state.story == "unknown" then tips[#tips + 1] = GetString(ONEDUNGEON_QUEST_UNKNOWN) end
    if state.today == true then
        labels[#labels + 1] = GetString(ONEDUNGEON_TODAY)
        tips[#tips + 1] = GetString(ONEDUNGEON_TODAY_TIP)
    elseif state.today == "unknown" then tips[#tips + 1] = GetString(ONEDUNGEON_PLEDGE_UNKNOWN) end
    if state.active == true then
        labels[#labels + 1] = GetString(ONEDUNGEON_ACTIVE)
        tips[#tips + 1] = GetString(ONEDUNGEON_ACTIVE_TIP)
    elseif state.active == "unknown" then tips[#tips + 1] = GetString(ONEDUNGEON_ACTIVE_UNKNOWN) end
    return table.concat(labels, " · "), table.concat(tips, "\n\n")
end
