if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS

------------------------------------------------------------------------------------------------------------------------
-- Quest --
------------------------------------------------------------------------------------------------------------------------
local questTrackerHeader1 = nil --ZO_FocusedQuestTrackerPanelContainerQuestContainerTrackedHeader1
local questTrackerOnMoveHooked = false

function FCOChangeStuff.QuestTrackerLoadPosition(onInit)
    if questTrackerHeader1 == nil then return end

    local settings = FCOChangeStuff.settingsVars.settings
    if onInit == true or settings.questTrackerMovable then
        local questTrackerSavedPosition = settings.questTrackerPos
        if questTrackerSavedPosition.x > -1  and questTrackerSavedPosition.y > -1 then
            questTrackerHeader1:ClearAnchors()
            questTrackerHeader1:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, questTrackerSavedPosition.x, questTrackerSavedPosition.y)
        end
    end
end

function FCOChangeStuff.QuestTrackerMovable(isMovable, loadPos)
    isMovable = isMovable or false
    if questTrackerHeader1 == nil then return end

    questTrackerHeader1:SetMouseEnabled(isMovable)
    questTrackerHeader1:SetMovable(isMovable)

    if not questTrackerOnMoveHooked then
        local doNotSaveMovedPos = false
        questTrackerHeader1:SetHandler("OnMoveStop", function(questTrackerCtrl)
            --d("[FCOCS]questTrackerHeader1:OnMoveStop")
            --if not isMoving then return end
            if doNotSaveMovedPos then
                doNotSaveMovedPos = false
                return
            end
            local settings = FCOChangeStuff.settingsVars.settings
            if settings.questTrackerMovable then
                settings.questTrackerPos.x =  questTrackerCtrl:GetLeft()
                settings.questTrackerPos.y =  questTrackerCtrl:GetTop()
            end
        end)

        ZO_PreHook(FOCUSED_QUEST_TRACKER, "AssistNext", function()
            doNotSaveMovedPos = true
        end)

        --Set callback function for quest tracker updated (e.g. if AssistNext function was called) and load the saved position again
        CALLBACK_MANAGER:RegisterCallback("QuestTrackerUpdatedOnScreen", function()
            --d("[FCOCS]CALLBACK_MANAGER fired QuestTrackerUpdatedOnScreen")
            doNotSaveMovedPos = false
            FCOChangeStuff.QuestTrackerLoadPosition(true)
        end)

        --Register a scene manager callback for the SetInUIMode function so any menu closed updates the quest tracker visually
        SecurePostHook(SCENE_MANAGER, 'SetInUIMode', function(self, inUIMode, bypassHideSceneConfirmationReason)
            if not inUIMode then
                doNotSaveMovedPos = false
                FCOChangeStuff.QuestTrackerLoadPosition(true)
            end
        end)

        questTrackerOnMoveHooked = true
    end

    if loadPos == true then
        FCOChangeStuff.QuestTrackerLoadPosition()
    end
end

function FCOChangeStuff.QuestTrackerChanges()
--d("[FCOCS]QuestTrackerChanges")
    questTrackerHeader1 = questTrackerHeader1 or ZO_FocusedQuestTrackerPanelContainerQuestContainerTrackedHeader1

    FCOChangeStuff.QuestTrackerMovable(FCOChangeStuff.settingsVars.settings.questTrackerMovable)
end

------------------------------------------------------------------------------------------------------------------------
--Enable the quest modifications
function FCOChangeStuff.questChanges()
    FCOChangeStuff.QuestTrackerChanges()
    FCOChangeStuff.QuestTrackerLoadPosition(true)
end
