local ImmQuests = ImmersiveQuests

ImmQuests.name = "ImmersiveQuests"
ImmQuests.author = "Alianym, @OneSkyGod, Fadosch"
ImmQuests.version = "0.0059"

local addOnName = ImmQuests.name
local localization = ImmQuests.localization
local cr = CHAT_ROUTER

function ImmQuests.GetSavedVarsQuestDataLocal(questId)
    local savedVars = IMMERSIVE_QUESTS_VARS
    local immQuestData = savedVars.immersiveQuestData

    if questId then return immQuestData[questId] end

    return immQuestData
end

----------
-- Core Step Code
----------

local function GetNewStepText(customStepText, stepText)
    local questJournalManager
    -- UPDATE 50 FIX: QUEST_JOURNAL_KEYBOARD was refactored by ZOS. 
    -- It is now just a container. Real quest UI logic moved to ZO_QUEST_JOURNAL_QUESTS_KEYBOARD.
    if not IsInGamepadPreferredMode() then
        questJournalManager = ZO_QUEST_JOURNAL_QUESTS_KEYBOARD
    else
        questJournalManager = ZO_QUEST_JOURNAL_QUESTS_GAMEPAD
    end
    -- UPDATE 50 FIX: Safety check in case gamepad UI isn't loaded yet
    if not questJournalManager then return end

    local journalQuestData = questJournalManager:GetSelectedQuestData()
    if (not journalQuestData) or (not stepText) then return end

    local questIndex = journalQuestData.questIndex

    -----

    local journalQuestName = GetJournalQuestName(questIndex)
    local locQuestData = localization[journalQuestName] or {}

    -- Changed this to loop through an array of steps for the quest, since by this point it is 'scoped' down to steps for one quest,
    -- > that means that the array should never get obscenely large and looping through it won't cause any noticeable delays

    -- If user-input description exists, use that
    local savedVars = IMMERSIVE_QUESTS_VARS

    if savedVars then
        local immQuestData = savedVars.immersiveQuestData

        for questId, questData in pairs(immQuestData) do
            if questData.questName == journalQuestName then
                for step, stepData in ipairs(questData.steps) do
                    if (stepData.stepText == stepText) and
                        stepData.immQuestStepText then
                        customStepText = stepData.immQuestStepText

                        if customStepText and customStepText ~= "" then
                            return zo_strformat("<<1>><<2>>", customStepText,
                                                stepText)
                        end
                    end
                end
            end
        end
    end

    -- If no user-input description exists, see if there is anything in a lang file
    if customStepText == "" or nil then
        -- ipairs only loops through numerically indexed arrays. Since our array is string indexed (keys are surrounded by "") we need to use the pairs command
        for conditionKey, conditionData in pairs(locQuestData) do
            if stepText == conditionData.stepTextKey then
                customStepText = conditionData.appendStepText

                if customStepText and customStepText ~= "" then
                    if type(customStepText) == "table" then
                        customStepText = customStepText[GetUnitAlliance("player")]
                    end

                    return zo_strformat("<<1>><<2>>", customStepText, stepText)
                end 
            end
        end
    end

    return stepText
end

local function GetNewConditionText(questIndex, stepText, conditionText,
                                   maxCount, conditionStep)
    local journalQuestName = GetJournalQuestName(questIndex)
    local locQuestData = localization[journalQuestName] or {}

    local conditionWithoutCounter
    if maxCount and maxCount > 0 then
        conditionWithoutCounter = conditionText:gsub(":.*", "")
    end

    -- Changed this to loop through an array of objectives for the quest, since by this point it is 'scoped' down to objectives for one quest,
    -- > that means that the array should never get obscenely large and looping through it won't cause any noticeable delays

    local customAppendText = ""

    -- If user-input description exists, use that
    local savedVars = IMMERSIVE_QUESTS_VARS
    local immQuestData = savedVars.immersiveQuestData

    for questId, questData in pairs(immQuestData) do
        if questData.questName == journalQuestName then
            for step, stepData in ipairs(questData.steps) do
                if stepData.stepText == stepText then
                    for obj, objData in ipairs(stepData.objectiveTexts) do
                        local objective =
                            objData.objective:gsub("• ", ""):gsub(" %d+", "")

                        if (objective == conditionText or objective ==
                            conditionWithoutCounter) and objData.immQuestDesc then
                            customAppendText = objData.immQuestDesc
                            break
                        end
                    end

                end
            end
            break
        end
    end

    -- If no user-input description exists, see if there is anything in a lang file
    if customAppendText == "" or nil then
        -- ipairs only loops through numerically indexed arrays. Since our array is string indexed (keys are surrounded by "") we need to use the pairs command
        for conditionKey, conditionData in pairs(locQuestData) do
            if type(conditionKey) == "string" then
                -- This below line strips the number off the end of the conditionKey so we can compare it to the conditionText properly
                conditionKey = conditionKey:gsub(" %d", "")

                if conditionKey == (conditionWithoutCounter or conditionText) and
                    conditionData then
                    local stepTextKey = conditionData.stepTextKey

                    -- This below line checks that if we have a stepTextKey, check it matches the stepText before proceeding. Otherwise, just proceed
                    if (stepTextKey and stepTextKey == stepText) or
                        (not stepTextKey) then
                        customAppendText = conditionData.appendText

                        if type(customAppendText) == "table" then
                            customAppendText =
                                customAppendText[GetUnitAlliance("player")]
                        end

                        break
                    end
                end
            end
        end
    end

    return zo_strformat("<<1>><<2>>", conditionText, customAppendText)
end

local function BuildTextHelper(questIndex, stepIndex, conditionStep,
                               questStrings)
    local conditionText, currentCount, maxCount, isFailCondition, isComplete, _,
          isVisible = GetJournalQuestConditionInfo(questIndex, stepIndex,
                                                   conditionStep)

    -- This calls our new code and gets the updated conditionText
    ----------
    local stepText = GetJournalQuestStepInfo(questIndex, stepIndex)
    conditionText = GetNewConditionText(questIndex, stepText, conditionText,
                                        maxCount, conditionStep)
    ----------

    if isVisible and not isFailCondition and conditionText ~= "" then
        if isComplete then
            conditionText = ZO_DISABLED_TEXT:Colorize(conditionText)
        end

        local taskInfo = {name = conditionText, isComplete = isComplete}

        table.insert(questStrings, taskInfo)
    end
end

-- Copied from ZOS' QUEST_JOURNAL_MANAGER:BuildTextForConditions(questIndex, stepIndex, numConditions, questStrings)
local function BuildTextForConditions(questIndex, stepIndex, numConditions,
                                      questStrings)
    for i = 1, numConditions do
        BuildTextHelper(questIndex, stepIndex, i, questStrings)
    end
end

-- Copied from ZOS' QUEST_JOURNAL_MANAGER:BuildTextForTasks(stepOverrideText, questIndex, questStrings)
local function BuildTextForTasks(questJournalManager, stepOverrideText,
                                 questIndex, questStrings)
    if stepOverrideText and (stepOverrideText ~= "") then
        BuildTextHelper(questIndex, QUEST_MAIN_STEP_INDEX, nil, questStrings)
    else
        local conditionCount = GetJournalQuestNumConditions(questIndex,
                                                            QUEST_MAIN_STEP_INDEX)
        BuildTextForConditions(questIndex, QUEST_MAIN_STEP_INDEX,
                               conditionCount, questStrings)
    end

    -- Because we return true in our hook, the original function will be stopped from running (which is what we want)
    return true
end

-- This sets up a "hook" so that our function will intercept QUEST_JOURNAL_MANAGER:BuildTextForTasks and run our code before their code
ZO_PreHook(QUEST_JOURNAL_MANAGER, "BuildTextForTasks", BuildTextForTasks)

-- Simple SecurePostHook function to update stepText with our custom text, we let ZOS handle the logic for getting the right base step text
local function RefreshStepText(self)
    local customStepText = GetNewStepText("", self.stepText:GetText())
    self.stepText:SetText(customStepText)
end

-- This sets up a "post hook" so our function will run after QUEST_JOURNAL_KEYBOARD/QUEST_JOURNAL_GAMEPAD:RefreshDetails and update the stepText in the journal
-- This change is purely 'visual'. We are not changing or overriding any functions, just updating the text that is displayed to the player
-- UPDATE 50 FIX: SecurePostHook now targets ZO_QUEST_JOURNAL_QUESTS_KEYBOARD instead of QUEST_JOURNAL_KEYBOARD
SecurePostHook(ZO_QUEST_JOURNAL_QUESTS_KEYBOARD, "RefreshDetails", RefreshStepText)
-- UPDATE 50 FIX: Wrapped Gamepad hook in nil check to prevent crashes if gamepad UI isn't initialized
if ZO_QUEST_JOURNAL_QUESTS_GAMEPAD then
    SecurePostHook(ZO_QUEST_JOURNAL_QUESTS_GAMEPAD, "RefreshDetails", RefreshStepText)
end

----------
-- Core New Code
----------
local function BuildTextForQuestComplete(questJournalManager)
    local questData = questJournalManager:GetSelectedQuestData()
    if not questData then return end

    local questIndex = questData.questIndex
    local goalCondition, _, _, _, goalBackgroundText, goalDescription =
        GetJournalQuestEnding(questIndex)

    if (not goalCondition) or goalCondition == "" then return end

    goalCondition = GetNewConditionText(questIndex, goalDescription,
                                        goalCondition)

    questJournalManager.conditionTextBulletList:Clear()
    questJournalManager.conditionTextBulletList:AddLine(goalCondition)
end

-- This sets up a "hook" so that our function will securely run after QUEST_JOURNAL_KEYBOARD:RefreshDetails and update the conditionText when the quest is
-- > at the stage just prior to completion
-- UPDATE 50 FIX: Hook targets the new UI object
SecurePostHook(ZO_QUEST_JOURNAL_QUESTS_KEYBOARD, "RefreshDetails",
               BuildTextForQuestComplete)

-- This sets up a "hook" so that our function will securely run after QUEST_JOURNAL_GAMEPAD:RefreshDetails and update the conditionText when the quest is
-- > at the stage just prior to completion
-- UPDATE 50 FIX: Gamepad hook wrapped in nil check
if ZO_QUEST_JOURNAL_QUESTS_GAMEPAD then
    SecurePostHook(ZO_QUEST_JOURNAL_QUESTS_GAMEPAD, "RefreshDetails",
                   BuildTextForQuestComplete)
end

-- On Load of the AddOn
local addOnName = "ImmersiveQuests"

local function onLoad(e, addon)
    -- We only want to run this code if the AddOn being loaded is ours
    if addon ~= addOnName then return end

    -- Create/Load SavedVars
    local defaultVals = {settings = {}, immersiveQuestData = {}}

    IMMERSIVE_QUESTS_VARS_MEGA_CROSS = ZO_SavedVars:NewAccountWide(
                                           "ImmersiveQuestsVars", 0.1, nil,
                                           defaultVals)
    IMMERSIVE_QUESTS_VARS_MEGA = ZO_SavedVars:NewAccountWide(
                                     "ImmersiveQuestsVars", 0.1, nil,
                                     defaultVals, GetWorldName())

    if IMMERSIVE_QUESTS_VARS_MEGA_CROSS.settings.megaVars then
        IMMERSIVE_QUESTS_VARS = IMMERSIVE_QUESTS_VARS_MEGA_CROSS
    else
        IMMERSIVE_QUESTS_VARS = IMMERSIVE_QUESTS_VARS_MEGA
    end

    -- Refreshes the quest journal to include our updated quest steps
    -- UPDATE 50 FIX: Using the new object and adding a nil/type check, because during 
    -- EVENT_ADD_ON_LOADED the journal might not be fully initialized yet, causing a crash.
    if ZO_QUEST_JOURNAL_QUESTS_KEYBOARD and ZO_QUEST_JOURNAL_QUESTS_KEYBOARD.RefreshDetails then
        ZO_QUEST_JOURNAL_QUESTS_KEYBOARD:RefreshDetails()
    end

    -- Load AddOn Settings
    ImmQuests.LoadSettings()

    -- Unregister once we've run it once as we don't need to call it again
    EVENT_MANAGER:UnregisterForEvent(addOnName, EVENT_ADD_ON_LOADED)
end

-- This registers the onLoad() function to be called whenever an AddOn is loaded (which is on login or /reloadui)
EVENT_MANAGER:RegisterForEvent(addOnName, EVENT_ADD_ON_LOADED, onLoad)
