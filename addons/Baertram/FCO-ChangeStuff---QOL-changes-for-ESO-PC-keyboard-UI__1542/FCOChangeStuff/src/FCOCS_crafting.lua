if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS

local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER

------------------------------------------------------------------------------------------------------------------------
-- Crafting --
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
-- Variables -
------------------------------------------------------------------------------------------------------------------------
--The crafting armor type change button
local craftingCreateChangeArmorTypeButton
local apiVersion = GetAPIVersion()
local apiVersionSmaller100026 = (apiVersion < 100026) or false
local lightArmorType = apiVersionSmaller100026 and SI_TRADING_HOUSE_BROWSE_ARMOR_TYPE_LIGHT or SI_ARMORTYPE_TRADINGHOUSECATEGORY1
local mediumArmorType = apiVersionSmaller100026 and SI_TRADING_HOUSE_BROWSE_ARMOR_TYPE_MEDIUM or SI_ARMORTYPE_TRADINGHOUSECATEGORY2

------------------------------------------------------------------------------------------------------------------------
-- EVENT FUNCTIONS -
------------------------------------------------------------------------------------------------------------------------

-- EVENT_END_CRAFTING_STATION_INTERACT (number eventCode, TradeskillType craftSkill)
function FCOChangeStuff.OnEventCraftingStationClose()
    local settings = FCOChangeStuff.settingsVars.settings
    --Check if the volume should be set to normal values again as you leave the crafting table?
    if settings.changeSoundAtCrafting then
        FCOChangeStuff.resetVolumeLevels(SETTING_TYPE_AUDIO, AUDIO_SETTING_AUDIO_VOLUME)
    end
end

-- EVENT_CRAFTING_STATION_INTERACT (number eventCode, TradeskillType craftSkill, boolean sameStation)
function FCOChangeStuff.OnEventCraftingStationOpened(_, TradeskillType, sameStation)
    --Check if the sound volume should be changed at a crafting station
    FCOChangeStuff.soundLowerAtCraftingCheck()
    --Show or hide the "Switch armor type from light<->medium" button at the clothier station only
    if craftingCreateChangeArmorTypeButton ~= nil then
        if TradeskillType == CRAFTING_TYPE_CLOTHIER then
            craftingCreateChangeArmorTypeButton:SetHidden(false)
        else
            craftingCreateChangeArmorTypeButton:SetHidden(true)
        end
    end
end


------------------------------------------------------------------------------------------------------------------------
-- SOUNDS -
------------------------------------------------------------------------------------------------------------------------
--Reset the last known volume levels from the SavedVars
function FCOChangeStuff.resetVolumeLevels(audioType, audioVolumeId)
    if audioType == nil or audioVolumeId == nil then return false end
    local settings = FCOChangeStuff.settingsVars.settings
    local audioVolumeRestored
    if settings.volumes[audioType] and settings.volumes[audioType][audioVolumeId] then
        audioVolumeRestored = settings.volumes[audioType][audioVolumeId] or 0
    end
    --Reset the volume now to the value from the SavedVariables
    if audioVolumeRestored then
        SetSetting(audioType, audioVolumeId, audioVolumeRestored)
    end
end


--Save the current volume levels to the SavedVars
function FCOChangeStuff.saveVolumeLevels(audioType, audioVolumeId)
    if type == nil then return false end
    local settings = FCOChangeStuff.settingsVars.settings
    --Get the current audi volume for the audioType and audioVolumeId
    local currentAudioVolume = GetSetting(audioType, audioVolumeId) or nil
    if currentAudioVolume ~= nil then
        --Set the volume SavedVars
        settings.volumes = settings.volumes or {}
        settings.volumes[audioType] = settings.volumes[audioType] or {}
        settings.volumes[audioType][audioVolumeId] = currentAudioVolume
    end
end

--Check if the SavedVars got volume levels for e.g. crafting and change to them
function FCOChangeStuff.changeVolumeLevels(type)
    if type == nil then return false end
    local settings = FCOChangeStuff.settingsVars.settings
    --Crafting volume changes
    if type == "crafting" then
        if settings.changeSoundAtCrafting then
            --Get the current volume level
            --Save the current volume levels
            FCOChangeStuff.saveVolumeLevels(SETTING_TYPE_AUDIO, AUDIO_SETTING_AUDIO_VOLUME)
            --Set the volume to 0
            SetSetting(SETTING_TYPE_AUDIO, AUDIO_SETTING_AUDIO_VOLUME, settings.changeSoundAtCraftingVolume)
            --> Registered the event for crafting station leave/close so the volume will be reset again -> See function FCOChangeStuff.OnEventCraftingStationClose()
            return true
        end
    end
end

--Lower the sound if crafting, according to the settings
function FCOChangeStuff.soundLowerAtCraftingCheck()
    --Are we at a crafting table?
    if not ZO_CraftingUtils_IsCraftingWindowOpen() then return false end
    --Change sound volumes at crafting
    if FCOChangeStuff.settingsVars.settings.changeSoundAtCrafting then
        --Then lower the volume levels during crafting
        FCOChangeStuff.changeVolumeLevels("crafting")
        --Enable the event for crafting station leave so the volume will be reset again then
        EM:RegisterForEvent(FCOChangeStuff.addonVars.addonName .. "_SOUND", EVENT_END_CRAFTING_STATION_INTERACT, FCOChangeStuff.OnEventCraftingStationClose)
    else
        --Do not change sound volumes at crafting
        --Get old volume values
        FCOChangeStuff.resetVolumeLevels("crafting")
        --Unregister the event crafting station close
        EM:UnregisterForEvent(FCOChangeStuff.addonVars.addonName .. "_SOUND", EVENT_END_CRAFTING_STATION_INTERACT)
    end
end

function FCOChangeStuff.soundModifications()
    --Set the create mods
    FCOChangeStuff.soundLowerAtCraftingCheck()
end


------------------------------------------------------------------------------------------------------------------------
-- SMITHING -
------------------------------------------------------------------------------------------------------------------------
function FCOChangeStuff.smithingModifications()
    --Set the create mods
    FCOChangeStuff.smithingCreate()
    --Set the improvement mods
    FCOChangeStuff.smithingImprove()
end

-------------------------
-- Creation
-------------------------

local function onCraftingCreateChangeArmorTypeButtonClicked(buttonCtrl)
    --Check if the shift key is pressed: Switch always to the starting indices of light/medium armor
    local isShiftKeyPressed = IsShiftKeyDown()
    --The horizontal scrolllist control
    local ctrlVars = FCOChangeStuff.ctrlVars
    if ctrlVars == nil or ctrlVars.smithingCreatePanelPatternListList == nil then return false end
    if ctrlVars.smithingCreatePanelPatternListList.horizontalScrollList == nil then return false end
    local horizontalScrollList = ctrlVars.smithingCreatePanelPatternListList.horizontalScrollList
    if horizontalScrollList == nil then return false end
    if buttonCtrl == nil or buttonCtrl.armorType == nil then return false end
    ZO_Tooltips_HideTextTooltip()
    local nextArmorTypes = {
        [lightArmorType] =  mediumArmorType,
        [mediumArmorType] = lightArmorType,
    }
    local currentArmorType = buttonCtrl.armorType
    local nextArmorType = nextArmorTypes[currentArmorType]
    if nextArmorType == nil then return false end
    --Get the currently selected index
    local currentSelectedIndex = horizontalScrollList:GetSelectedIndex()
--d(">currentSelectedIndex: " ..tostring(currentSelectedIndex))
    --The info about the horizontal scroll list of light/medium armor
    --Light armor
    local minIndex = 0
    local maxIndex = -14
    local armorPartCount = 8
    local armorsData = {
        [lightArmorType] = {
            ["startIndex"]  = minIndex,
            ["endIndex"]    = -7,
        },
        --Meidum armor
        [mediumArmorType] = {
            ["startIndex"]  = -8,
            ["endIndex"]    = maxIndex,
        },
    }
    local armorData
    if isShiftKeyPressed or currentSelectedIndex == nil then
--d(">nextArmorType: " ..tostring(nextArmorType))
        --Switch to the next armor type start index
        armorData = armorsData[nextArmorType]
    else
        --Get the current armor types start index and add/remove a value
        armorData = armorsData[currentArmorType]
    end
    if armorData == nil then return false end
    if armorData.startIndex == nil then return false end
    local newIndex
    if isShiftKeyPressed or currentSelectedIndex == nil then
        --New index: Start of medium/light armor
        newIndex = armorData.startIndex
    else
        local correctionIndex = 0
        --Light armor got 2 light chest parts (robe, jacket) but medium armor only got 1
        --So this correction factor needs to set the selected index correct
        --Calculate the new index: Currently selected light armor part -> same in medium / medium -> same in light
        if      currentArmorType == lightArmorType then
            --Light jacket (not robe which is index = minIndex) or any else light armor selected?
            if currentSelectedIndex ~= minIndex and currentSelectedIndex <= (minIndex-1) and currentSelectedIndex >= (armorPartCount*-1) then
                correctionIndex = 1
            end
            newIndex = currentSelectedIndex - (armorPartCount - correctionIndex)
        elseif  currentArmorType == mediumArmorType then
            --Medium jacket or any else medium armor selected?
            if currentSelectedIndex ~= minIndex and currentSelectedIndex <= (minIndex-1) and currentSelectedIndex <= (armorPartCount*-1) then
                local correctionVar = 1
                --Is the currently selected item the medium chects?
                if currentSelectedIndex == (minIndex - armorPartCount) then
                    correctionVar = 0
                end
                correctionIndex = correctionVar
            end
            newIndex = currentSelectedIndex + (armorPartCount - correctionIndex)
        end
    end
--d(">>min: " .. tostring(minIndex) .. ", max: " .. tostring(maxIndex))
    if newIndex ~= minIndex and (newIndex*-1) < minIndex then newIndex = minIndex end
    if newIndex ~= minIndex and newIndex ~= maxIndex and (newIndex*-1) > (maxIndex*-1) then newIndex = maxIndex end
    if newIndex == nil then return false end

    --Change the button texture and tooltip
    buttonCtrl.updateTextureAndText(buttonCtrl, nextArmorType)
    --Change the shown armor type in the horizontal list to the first medium/light part
    horizontalScrollList:SetSelectedIndex(newIndex)
end

function FCOChangeStuff.smithingCreateOnLeftOrRight()
    --Call delayed as the Left and right functions are updating the selected index!
    zo_callLater(function()
        --The horizontal scrolllist control
        local ctrlVars = FCOChangeStuff.ctrlVars
        if ctrlVars == nil or ctrlVars.smithingCreatePanelPatternListList == nil then return false end
        if ctrlVars.smithingCreatePanelPatternListList.horizontalScrollList == nil then return false end
        local horizontalScrollList = ctrlVars.smithingCreatePanelPatternListList.horizontalScrollList
        if horizontalScrollList == nil then return false end
        --Get the currently selected index
        local currentSelectedIndex = horizontalScrollList:GetSelectedIndex()
        if currentSelectedIndex == nil then return false end
        local selectedScrollListIndices2AmorType={
            --Light armor
            [0] = lightArmorType,
            [-1] = lightArmorType,
            [-2] = lightArmorType,
            [-3] = lightArmorType,
            [-4] = lightArmorType,
            [-5] = lightArmorType,
            [-6] = lightArmorType,
            [-7] = lightArmorType,
            --Medium armor
            [-8] = mediumArmorType,
            [-9] = mediumArmorType,
            [-10] = mediumArmorType,
            [-11] = mediumArmorType,
            [-12] = mediumArmorType,
            [-13] = mediumArmorType,
            [-14] = mediumArmorType,
        }
        local armorType = selectedScrollListIndices2AmorType[currentSelectedIndex]
        craftingCreateChangeArmorTypeButton.updateTextureAndText(craftingCreateChangeArmorTypeButton, armorType)
    end, 50)
end

local smithingHorizontalScrollListMoveHooked = false
--Add a button to switch directly between light & medium armor
function FCOChangeStuff.smithingCreateAddArmorTypeSwitchButton()
    --Only add if enabled in the settings, or hide it
    if not FCOChangeStuff.settingsVars.settings.smithingCreationAddArmorTypeSwitchButton then
        if craftingCreateChangeArmorTypeButton ~= nil then
            craftingCreateChangeArmorTypeButton:SetHidden(true)
        end
        return false
    end
    --Add a button left to the light/medium armor horizontal scroll list to switch between light and medium armor parts with one click
    if craftingCreateChangeArmorTypeButton ~= nil then
        craftingCreateChangeArmorTypeButton:SetHidden(false)
    end
    if not craftingCreateChangeArmorTypeButton then
        local ctrlVars = FCOChangeStuff.ctrlVars

        craftingCreateChangeArmorTypeButton = WM:CreateControl("FCOCS_ChangeArmorTypeButton", ZO_SmithingTopLevelCreationPanel, CT_BUTTON)
        craftingCreateChangeArmorTypeButton:SetDimensions(32,32)
        craftingCreateChangeArmorTypeButton:SetAnchor(RIGHT, ctrlVars.smithingCreatePanelPatternListTitle, LEFT , -16, 0)
        craftingCreateChangeArmorTypeButton.updateTextureAndText = function(self, armorType)
            armorType = armorType or lightArmorType
            local updateValues = {
                [lightArmorType] = {
                    ["armorType"]           = lightArmorType,
                    ["tooltip"]             = GetString(mediumArmorType),
                    ["NormalTexture"]       = "/esoui/art/icons/crafting_medium_armor_component_005.dds",
                    ["PressedTexture"]      = "/esoui/art/icons/crafting_medium_armor_component_005.dds",
                    ["MouseOverTexture"]    = "/esoui/art/buttons/checkbox_mouseover.dds",
                },
                [mediumArmorType] = {
                    ["armorType"]           = mediumArmorType,
                    ["tooltip"]             = GetString(lightArmorType),
                    ["NormalTexture"]       = "/esoui/art/icons/crafting_light_armor_component_006.dds",
                    ["PressedTexture"]      = "/esoui/art/icons/crafting_light_armor_component_006.dds",
                    ["MouseOverTexture"]    = "/esoui/art/buttons/checkbox_mouseover.dds",
                },
            }
            local updateValue = updateValues[armorType]
            if updateValue == nil then return false end
            self.armorType  = updateValue.armorType
            self.tooltip    = updateValue.tooltip
            self:SetNormalTexture(updateValue.NormalTexture)
            self:SetPressedTexture(updateValue.PressedTexture)
            self:SetMouseOverTexture(updateValue.MouseOverTexture)
        end
        craftingCreateChangeArmorTypeButton.updateTextureAndText(craftingCreateChangeArmorTypeButton, lightArmorType)
        craftingCreateChangeArmorTypeButton:SetHandler("OnClicked", function(self) onCraftingCreateChangeArmorTypeButtonClicked(self) end)
        craftingCreateChangeArmorTypeButton:SetHandler("OnMouseEnter", function(self) ZO_Tooltips_ShowTextTooltip(self, LEFT, self.tooltip) end)
        craftingCreateChangeArmorTypeButton:SetHandler("OnMouseExit", ZO_Tooltips_HideTextTooltip)
        craftingCreateChangeArmorTypeButton:SetHidden(false)


        --PreHook the data changed callback function to get update the button texture's and armorType on manual scrolling the list
        if ctrlVars == nil or ctrlVars.smithingCreatePanelPatternListList == nil then return false end
        if ctrlVars.smithingCreatePanelPatternListList.horizontalScrollList == nil then return false end
        local horizontalScrollList = ctrlVars.smithingCreatePanelPatternListList.horizontalScrollList
        if not horizontalScrollList.onSelectedDataChangedCallback then return false end
        if not smithingHorizontalScrollListMoveHooked then
            ZO_PreHook(horizontalScrollList, "MoveLeft", FCOChangeStuff.smithingCreateOnLeftOrRight)
            ZO_PreHook(horizontalScrollList, "MoveRight", FCOChangeStuff.smithingCreateOnLeftOrRight)
            smithingHorizontalScrollListMoveHooked = true
        end
    end
end

function FCOChangeStuff.smithingCreate()
    FCOChangeStuff.smithingCreateAddArmorTypeSwitchButton()
end

-------------------------
-- Improvement
-------------------------
--Preselect the highest available improvement material count at the crafting stations improvement tab
--[[
function FCOChangeStuff.smithingImproveTrySet100PercentChance()
    if not FCOChangeStuff.settingsVars.settings.improvementWith100Percent then return false end
    local smithingPanels = {
        --Gamepadmode
        [true] = SMITHING_GAMEPAD,
        --Keyboardmode
        [false] = SMITHING,

    }
    local gamePadMode = IsInGamepadPreferredMode() or false
    local smithingPanel = smithingPanels[gamePadMode]
    if smithingPanel == nil or smithingPanel.improvementPanel == nil or smithingPanel.improvementPanel.OnSlotChanged == nil then return false end
    local imprPanel = smithingPanel.improvementPanel
    local origImprovementFunc = imprPanel.OnSlotChanged

    --PostHook the smithing improvement slot changed function at the given panel (keyboard/gamepad)
    --and get the max boosters available and possible, and set the value to the spinner then
    imprPanel.OnSlotChanged = function (...)
        --Call the original InSlotChanged function
        local origRetVar = origImprovementFunc(...)
        --Only run this code if the settings are enabled
        local settings = FCOChangeStuff.settingsVars.settings
        if settings.improvementWith100Percent then
            local hasItem = imprPanel.improvementSlot:HasItem()
            if hasItem then
                local row = imprPanel:GetRowForSelection()
                if row then
                    local max = imprPanel:FindMaxBoostersToApply()
                    if max then
                        local isInGamePadMode = IsInGamepadPreferredMode() or false
                        if isInGamePadMode then
                            --Gamepad mode?
                            zo_callLater(function ()
                                imprPanel.spinner:Activate()
                                imprPanel.spinner:SetValue(max)
                            end, 50) -- slightly delay as the gamepad smithing function needs it somehow
                        else
                            imprPanel.spinner:SetValue(max)
                        end
                    end
                end
            end
        end
        return origRetVar -- Return the result of the original function
    end
end
]]

local function isItemBlockedForImprovement(bagId, slotIndex)
    if not bagId or not slotIndex then return false end
--d("[FCOChangeStuff]isItemBlockedForImprovement:  " ..GetItemLink(bagId, slotIndex))
    local settings = FCOChangeStuff.settingsVars.settings
    local blockedQuality = settings.improvementBlockQuality
    if not blockedQuality or blockedQuality == -1 then return false end
    if settings.improvementBlockQualityExceptionShiftKey == true and IsShiftKeyDown() == true then
--d("<<not blocked - SHIFT key pressed")
        return false
    end

    local currentQuality = GetItemFunctionalQuality(bagId, slotIndex)
--d(">qualityOfItem: " ..tostring(currentQuality))
    if not currentQuality then return false end
    local newQualityAfterImprovement = currentQuality + 1
    if not newQualityAfterImprovement or newQualityAfterImprovement > ITEM_QUALITY_LEGENDARY then
--d("<<not blocked - quality too low")
        return false
    end
    --Is the "current" quality of the item = blocked item quality -1?
    if newQualityAfterImprovement >= blockedQuality then
--d(">curerntQuality: " ..tostring(currentQuality) .. ", newQualityAfterImprovement: " ..tostring(newQualityAfterImprovement) .. ", blockedQuality: " ..tostring(blockedQuality))
        --Abort the improvement
        local itemLink = GetItemLink(bagId, slotIndex)
        if itemLink and itemLink ~= "" then
            --Show chat message
            local alertMsg = "["..FCOChangeStuff.addonVars.addonNameMenuDisplay.."]Improvement of " .. itemLink .. " blocked! Allowed qualities must be < " ..tostring(FCOChangeStuff.qualityChoices[blockedQuality])
            d(alertMsg)
            --Show Alert message -> At the top right corner
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, alertMsg)
        end
        SMITHING.improvementPanel:ClearSelections()
        return true
    end
    return false
end

--Block improvement of items if their quality is >= a chosen "maximum" improvement quality
local smithingImproveDialogHooked = false
function FCOChangeStuff.smithingImproveBlockImprovement()
    local settings = FCOChangeStuff.settingsVars.settings

    --Is the improvement blocked due to a maximum quality set?
    local blockedQuality = settings.improvementBlockQuality
    if not blockedQuality or blockedQuality == -1 then return false end

    --Improve the item and show security dialog before
    if not smithingImproveDialogHooked then
        if ZO_Dialogs_ShowPlatformDialog then
            ZO_PreHook("ZO_Dialogs_ShowPlatformDialog", function(dialogName, itemData, dialogData)
                --d("[FCOChangeStuff]ZO_Dialogs_ShowPlatformDialog-dialogName: " ..tostring(dialogName))
                local improveDialogNames = {
                    ["CONFIRM_IMPROVE_ITEM"] = true,
                    ["CONFIRM_IMPROVE_LOCKED_ITEM"] = true,
                    ["GAMEPAD_CONFIRM_IMPROVE_LOCKED_ITEM"] = true,
                }
                local improveDialogName = improveDialogNames[dialogName] or false
                --Only for the improvement dialog
                if not improveDialogName then return false end
                --d(">dialogName is an allowed improvement dialog!")
                --Check if the item is allowed to be improved and if not suppress the dialog
                if itemData and itemData.bagId and itemData.slotIndex then
                    return isItemBlockedForImprovement(itemData.bagId, itemData.slotIndex)
                end
                return false
            end)
            smithingImproveDialogHooked = true
        end
        --Improve the item via function
        if ImproveSmithingItem then
            --PreHook the improvement of items and check the quality
            ZO_PreHook("ImproveSmithingItem", function(...)
                --d("[FCOChangeStuff]PreHook: ImproveSmithingItem")
                local params = {...}
                local bagId, slotIndex = params.bagId, params.slotIndex
                if not bagId or not slotIndex then return false end
                return isItemBlockedForImprovement(params.bagId, params.slotIndex)
            end)
            smithingImproveDialogHooked = true
        end
    end
end

function FCOChangeStuff.smithingImprove()
    --FCOChangeStuff.smithingImproveTrySet100PercentChance()
    FCOChangeStuff.smithingImproveBlockImprovement()
end


------------------------------------------------------------------------------------------------------------------------
-- Load the crafting modifications
------------------------------------------------------------------------------------------------------------------------
function FCOChangeStuff.craftingModifications()
    --Smithing
    FCOChangeStuff.smithingModifications()
    --Sound modifications
    FCOChangeStuff.soundModifications()
end