if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS
FCOChangeStuff.stableSkills = {}
--[[
RidingTrainType
* RIDING_TRAIN_INVALID
* RIDING_TRAIN_CARRYING_CAPACITY
* RIDING_TRAIN_SPEED
* RIDING_TRAIN_STAMINA
]]
local tesoStableFeedTypes = {
    [1] = RIDING_TRAIN_SPEED,
    [2] = RIDING_TRAIN_STAMINA,
    [3] = RIDING_TRAIN_CARRYING_CAPACITY,
}
local tesoStableFeedButtons = {
    [RIDING_TRAIN_SPEED]            = ZO_StablePanelSpeedTrainRowTrainButton,
    [RIDING_TRAIN_STAMINA]          = ZO_StablePanelStaminaTrainRowTrainButton,
    [RIDING_TRAIN_CARRYING_CAPACITY]= ZO_StablePanelCarryTrainRowTrainButton,
}

--Check if all the available table feed types are maxed out
function FCOChangeStuff.checkIfAllStableButtonsAreMaxedOut()
    local retVar = false
    local maxCnt = 0
    for _, stableFeedType in ipairs(tesoStableFeedTypes) do
        if FCOChangeStuff.stableSkills[stableFeedType].maxed == true then
            maxCnt = maxCnt + 1
        end
    end
    if maxCnt >= (#tesoStableFeedTypes) then
        retVar = true
    end
    return retVar
end

--Check if the other stable feed buttons are maxed out already and thus the third button
--doesn't need to be hidden.
--Returns false if all other buttons are maxed out, and the value you put into the parameter hideIt if not
function FCOChangeStuff.checkIfOtherStableButtonsAreMaxedOut(stableFeedType)
    if stableFeedType == nil then return false end
    local retVar = false
    local maxCnt = 0
    for _, otherStableFeedType in ipairs(tesoStableFeedTypes) do
        if otherStableFeedType ~= stableFeedType then
            if FCOChangeStuff.stableSkills[otherStableFeedType].maxed == true then
                maxCnt = maxCnt + 1
            end
        end
    end
    if maxCnt >= (#tesoStableFeedTypes - 1) then
        retVar = true
    end
    return retVar
end

local stableSceneStateChangeRegistered = false
function FCOChangeStuff.hookStableScene()
    --Get the current riding skill infos
    FCOChangeStuff.getRidingTrainInfo()

    if not stableSceneStateChangeRegistered then
        --Set a callback function for the stable scene in order to show/hide the train buttons
        STABLES_SCENE:RegisterCallback("StateChange", function(oldState, newState)
            --The stable scene is shown
            if newState == SCENE_SHOWN then
                --Check the settings and hide the not-wanted feed buttons
                local stableFeedSettings = FCOChangeStuff.settingsVars.settings.stableFeedSettings
                if stableFeedSettings ~= nil then
                    for stableFeedType, hideIt in pairs(stableFeedSettings) do
                        --Check if the other stable train buttons are maxed out and do not hide the button then
                        local allOtherStableButtonsAreMaxedOut = FCOChangeStuff.checkIfOtherStableButtonsAreMaxedOut(stableFeedType)
                        if allOtherStableButtonsAreMaxedOut then
                            hideIt = false
                        end
                        if hideIt == true and tesoStableFeedButtons[stableFeedType] ~= nil then
                            tesoStableFeedButtons[stableFeedType]:SetHidden(true)
                        end
                    end
                end
            end
        end)
        stableSceneStateChangeRegistered = true
    end
end


--* GetRidingStats()
--** _Returns:_ *integer* _inventoryBonus_, *integer* _maxInventoryBonus_, *integer* _staminaBonus_, *integer* _maxStaminaBonus_, *integer* _speedBonus_, *integer* _maxSpeedBonus_
--* GetMaxRidingTraining(*[RidingTrainType|#RidingTrainType]* _trainTypeIndex_)
--** _Returns:_ *integer* _maxValue_
--Get the riding train states
function FCOChangeStuff.getRidingTrainInfo()
    --Build array if needed
    for _, stableFeedType in ipairs(tesoStableFeedTypes) do
        if FCOChangeStuff.stableSkills[stableFeedType] == nil then FCOChangeStuff.stableSkills[stableFeedType] = {} end
    end
    --Local pointer to the settings
    local settings = FCOChangeStuff.settingsVars.settings
    --Are all stable feed types maxed out already?
    if FCOChangeStuff.checkIfAllStableButtonsAreMaxedOut() then
        --Disable the setting to hide the button
        settings.stableFeedSettings[RIDING_TRAIN_CARRYING_CAPACITY] = false
        --Disable the setting to hide the button
        settings.stableFeedSettings[RIDING_TRAIN_STAMINA] = false
        --Disable the setting to hide the button
        settings.stableFeedSettings[RIDING_TRAIN_SPEED] = false
    else
        --Get the trained skills info
        local inventoryBonus, maxInventoryBonus, staminaBonus, maxStaminaBonus, speedBonus, maxSpeedBonus = GetRidingStats()
        --Check if any train skill is maxed out, then do not hide other buttons if only one is left
        if     inventoryBonus >= maxInventoryBonus then
            FCOChangeStuff.stableSkills[RIDING_TRAIN_CARRYING_CAPACITY].maxed = true
            --Disable the setting to hide the button
            settings.stableFeedSettings[RIDING_TRAIN_CARRYING_CAPACITY] = false
        else
            FCOChangeStuff.stableSkills[RIDING_TRAIN_CARRYING_CAPACITY].maxed = false
        end
        if staminaBonus >= maxStaminaBonus then
            FCOChangeStuff.stableSkills[RIDING_TRAIN_STAMINA].maxed = true
            --Disable the setting to hide the button
            settings.stableFeedSettings[RIDING_TRAIN_STAMINA] = false
        else
            FCOChangeStuff.stableSkills[RIDING_TRAIN_STAMINA].maxed = false
        end
        if speedBonus >= maxSpeedBonus then
            FCOChangeStuff.stableSkills[RIDING_TRAIN_SPEED].maxed = true
            --Disable the setting to hide the button
            settings.stableFeedSettings[RIDING_TRAIN_SPEED] = false
        else
            FCOChangeStuff.stableSkills[RIDING_TRAIN_SPEED].maxed = false
        end

    end
end

--Changes related to mounts
function FCOChangeStuff.mountChanges()
    FCOChangeStuff.muteMountSound()
end