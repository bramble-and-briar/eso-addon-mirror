-- =================================================================================================
-- QuestMap: українські фільтри мапи і розпізнавання розпочатих завдань.
--
-- LibQuestData шукає розпочаті завдання за назвою з журналу в таблиці назв своєї мови.
-- Української таблиці в ній немає (використовується англійська), тож назви не збігаються.
-- Після кожного оновлення LibQuestData перебудовуємо started_quests через GetQuestName(questId),
-- який повертає назву мовою клієнта.
-- =================================================================================================

local DovahMova = DovahMova

local REBUILD_DELAY_MS = 100 -- після власного оновлення LibQuestData

local function RebuildStartedQuests()
	local questNames = LibQuestData.quest_names and LibQuestData.quest_names[LibQuestData.effective_lang]
	if not questNames then
		return
	end

	local journalQuestNames = {}
	for journalIndex = 1, GetNumJournalQuests() do
		if IsValidQuestIndex(journalIndex) then
			journalQuestNames[GetJournalQuestName(journalIndex)] = true
		end
	end

	local startedQuests = {}
	for questId in pairs(questNames) do
		local questName = GetQuestName(questId)
		if questName ~= "" and journalQuestNames[questName] then
			startedQuests[questId] = true
		end
	end
	LibQuestData.started_quests = startedQuests
end

local function ScheduleRebuild()
	zo_callLater(RebuildStartedQuests, REBUILD_DELAY_MS)
end

DovahMova.RegisterIntegration({
	name = "QuestMap",
	IsAvailable = function()
		return QuestMap ~= nil
	end,
	Prepare = function()
		DovahMova.Util.CreateStringIds(DovahMova.IntegrationStrings.QuestMap, 1)
	end,
	Apply = function()
		if LibQuestData then
			local eventName = DovahMova.name .. "_QuestMap"
			EVENT_MANAGER:RegisterForEvent(eventName, EVENT_QUEST_ADDED, ScheduleRebuild)
			EVENT_MANAGER:RegisterForEvent(eventName, EVENT_QUEST_REMOVED, ScheduleRebuild)
			EVENT_MANAGER:RegisterForEvent(eventName, EVENT_PLAYER_ACTIVATED, ScheduleRebuild)
		end
	end,
})
