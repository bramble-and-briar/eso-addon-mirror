QuestCycleHotKeys = {
	Name = "QuestCycleHotKeys",
	SettingsName = "QuestCycleHotKeys_SavedVariables",
	SettingsVersion = 1.0,
	--DisplayName = "OptionalOverideName"
}
local this = QuestCycleHotKeys
----------------------------------
--			Defaults			--
----------------------------------
this.defaultsAccount = {		
	debugEnabled = false, 
}

this.defaultsCharacter = {
	someProperty = true,
}

----------------------------------
--			Previous Quest		--
----------------------------------
local function GetPreviousQuestIndex(currentQuestIndex)
    local quests = QUEST_JOURNAL_MANAGER.quests
    local numQuests = #quests

    for i = 1, numQuests do
        if quests[i].questIndex == currentQuestIndex then
            local previous = (i == 1) and numQuests or (i - 1)
            return quests[previous].questIndex
        end
    end
end



local function Initialize()
	this.accountWide = ZO_SavedVars:NewAccountWide(this.SettingsName,this.SettingsVersion,"Account",this.defaultsAccount)
	this.character = ZO_SavedVars:NewCharacterNameSettings(this.SettingsName,this.SettingsVersion,"Character",this.defaultsCharacter)
	
	--CreateSettingsPanel()
    
	ZO_CreateStringId("SI_BINDING_NAME_QuestCycleHotKeys_Debug", "Debug Key")
	ZO_CreateStringId("SI_BINDING_NAME_QuestCycleHotKeys_NextQuest", "Next Quest")
	ZO_CreateStringId("SI_BINDING_NAME_QuestCycleHotKeys_PreviousQuest", "Previous Quest")
	
	
	-- Set up initial state 
	--e.g. GetState()
	
	--any event registrations
    
	--ZO_PreHook("ZO_InventorySlot_ShowContextMenu", AddContextMenuItemWithDelay)	
end

local function OnAddOnLoaded(event, addonName)
    if addonName == this.Name then
        EVENT_MANAGER:UnregisterForEvent(this.Name, EVENT_ADD_ON_LOADED)
        Initialize()
    end
end

EVENT_MANAGER:RegisterForEvent(this.Name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

function this.NextQuest()
	FOCUSED_QUEST_TRACKER:AssistNext()	
end

function this.PreviousQuest()
    local tracker = FOCUSED_QUEST_TRACKER
    local assisted = tracker.assistedData

    if assisted then
        local currentQuestIndex = assisted.arg1
        local previousQuestIndex = GetPreviousQuestIndex(currentQuestIndex)

        if previousQuestIndex then
            if tracker:BeginTracking(TRACK_TYPE_QUEST, previousQuestIndex) then
                CALLBACK_MANAGER:FireCallbacks("QuestTrackerUpdatedOnScreen")
            end
        end
    end
end


function this.Debug()
	d("Debug Pressed")
end