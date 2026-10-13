if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS

local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER

------------------------------------------------------------------------------------------------------------------------
-- Skills --
------------------------------------------------------------------------------------------------------------------------

--Constant values

--The global variable for the skills
--SKILLS_WINDOW

--Categories in the skills window (left side -> Top labels with the categories which one can expand/collapse)
--SKILLS_WINDOW.navigationTree.rootNode.children

--Entries below the categories
--SKILLS_WINDOW.navigationTree.rootNode.children[n].children[n].control

--Entry can be made disabled:
--SKILLS_WINDOW.navigationTree.rootNode.children[n].children[n].control:SetEnabled(false)
--SKILLS_WINDOW.navigationTree.rootNode.children[n].children[n].control:SetMouseEnabled(false)
-->But this needs to be checked and done each time the parent node get's expanded
-->How is one able to enable/disable the entries (context mouse menu is not working if MouseEnabled(false)


--Abilities selected by help of the navigation tree on the left
--SKILLS_WINDOW.abilityList


local function changeSkillLineTypeEntry(ctrl, newStatus, isContextMenu)
    isContextMenu = isContextMenu or false
    if ctrl == nil then return false end
    if newStatus == nil and isContextMenu then return false end
    --Save the enabled state of the skilllineindex now
    local settings = FCOChangeStuff.settingsVars.settings
    if not settings.enableSkillLineContextMenu then return false end

    --Get the data of the entry
    local data = ctrl.node.data or ctrl.data
    --Check the data
    if data ~= nil then
        local foundError = false
        if not data.isSubclassingNode then
            local skillLineTypeData = data
            local skillLineIndex = skillLineTypeData.skillLineIndex
            local skillType = skillLineTypeData.skillTypeData.skillType
            if skillLineIndex ~= nil and skillType ~= nil then

                --Called from the context menu? Change the savedvars
                if isContextMenu then
                    --Enable/Disable the control (SkillLineType)
                    ctrl:SetEnabled(newStatus)
                    --Update the savedvars
                    if settings.skillLineIndexState[skillLineIndex] == nil then
                        settings.skillLineIndexState[skillLineIndex] = {}
                    end
                    local newStatusSavedVars = nil
                    if newStatus == false then
                        newStatusSavedVars = false
                    end
                    settings.skillLineIndexState[skillLineIndex][skillType] = newStatusSavedVars


                    --Not called from the context menu? Read the savedvars and change the visible controls in teh skills_window
                else
                    --Get the skillineindex
                    local skillLineIndexSavedData = settings.skillLineIndexState[skillLineIndex]
                    if skillLineIndexSavedData ~= nil then
                        local skillLineIndexState = skillLineIndexSavedData[skillType]
                        if skillLineIndexState ~= nil then
                            --Set the enabled state of the entry according to the settings
                            ctrl:SetEnabled(skillLineIndexState)
                            newStatus = skillLineIndexState
                        else
                            foundError = true
                        end
                    else
                        foundError = true
                    end
                    --Fallback: Enable the skill line type entry
                    if foundError then
                        ctrl:SetEnabled(true)
                        if newStatus == nil then
                            newStatus = false
                        end
                    end
                end
            end
        else
           foundError = true
        end

        --Set the status icon of the control
        if not foundError and newStatus ~= nil and ctrl.statusIcon ~= nil then
            local statusIcon = ctrl.statusIcon
            --Only if the status icon is not showing a special status texture already!
            if not statusIcon:HasIcon() then
                local statusIconTextureVar = "/esoui/art/buttons/cancel_up.dds"
                if newStatus == true then
                    statusIcon:ClearIcons()
                    statusIcon:SetColor(0, 0, 0, 1)
                    statusIcon:Hide()
                else
                    statusIcon:AddIcon(statusIconTextureVar)
                    statusIcon:SetColor(1, 0, 0, 1)
                    statusIcon:Show()
                end

            end
        end
    end
end

    --Set the skillline type's status (enabled/disabled) now and update icons etc.
local function FCOCS_SetSkillLineTypeStatus(ctrl, status)
    if ctrl == nil or status == nil then return false end
    local contextMenuEntryText = ""
    local newStatus = not status
    if status then
        contextMenuEntryText = "Mark skill line as \'non relevant\'"
    else
        contextMenuEntryText = "Mark skill line as \'relevant\' again"
    end
    --Add the context menu entry
    AddCustomScrollableMenuEntry(contextMenuEntryText,
        function()
            changeSkillLineTypeEntry(ctrl, newStatus, true)
        end)
end

--Add the new context menu entry to the skill category subitem entries (e.g. Bow)
local function FCOCS_AddSkillTypeContextMenuEntry(ctrl)
    local settings = FCOChangeStuff.settingsVars.settings
    if not settings.enableSkillLineContextMenu then return false end
    if SKILLS_WINDOW.control:IsHidden() then return end
    if ctrl ~= nil then
--d("FCOCS_AddSkillTypeContextMenuEntry - Control name: " .. ctrl:GetName())
    --Is the skills window shown?
        --Call this function later as the original menu will be build in OnMouseUp function and we are in the PreHook of this function here!
        --So all menu entries will be overwritten again and we must add this entry later
        --zo_callLater(function()
            ClearCustomScrollableMenu(ctrl)
            --Add context menu entry now
            --AddMenuItem(localizationVars.fco_notes_loc["context_menu_add_personal_guild_note"],
            if ctrl.enabled ~= nil then
                FCOCS_SetSkillLineTypeStatus(ctrl, ctrl.enabled)
                ShowCustomScrollableMenu(ctrl)
            end
        --end, 50)
    end
end

--PreHook the skill lines on mouse click event
local preHookedSkillTypeEntryCtrls = {}
function FCOChangeStuff.preHookSkillLinesOnMouseDown()
    local settings = FCOChangeStuff.settingsVars.settings
    --Get each header entry of the skills window and prehook the mouse button click on it
    if SKILLS_WINDOW and SKILLS_WINDOW.skillLinesTree and SKILLS_WINDOW.skillLinesTree.rootNode and SKILLS_WINDOW.skillLinesTree.rootNode.children then
        local skillsWindowSkillTypesHeader = SKILLS_WINDOW.skillLinesTree.rootNode.children
        for skillTypesHeaderIndex, skillTypeHeaderData in ipairs(skillsWindowSkillTypesHeader) do
            --Get each entry below the skilltype
            if skillTypeHeaderData and skillTypeHeaderData.children then
                --Get each skilltype entry below the skilltype header
                for skillTypeIndex, skillTypeData in ipairs(skillTypeHeaderData.children) do
                    if skillTypeData and skillTypeData.control and skillTypeData.enabled then
                        local skillTypeEntryCtrl = skillTypeData.control
                        local data = skillTypeEntryCtrl.node.data or skillTypeEntryCtrl.data
                        if data and not data.isSubclassingNode then
                            if not preHookedSkillTypeEntryCtrls[skillTypeEntryCtrl] then
                                --d(">skillTypeEntryCtrl: " ..tostring(skillTypeEntryCtrl:GetName()))
                                --PreHook the OnMouseUp event now
                                ZO_PostHookHandler(skillTypeEntryCtrl, "OnMouseUp", function(ctrl, button, upInside)
                                    if button == MOUSE_BUTTON_INDEX_RIGHT and upInside then
                                        FCOCS_AddSkillTypeContextMenuEntry(ctrl)
                                    end
                                end)
                                preHookedSkillTypeEntryCtrls[skillTypeEntryCtrl] = true
                            end
                            --Change the visible controls now
                            changeSkillLineTypeEntry(skillTypeEntryCtrl, nil, false)
                        end
                    end
                end
            end
        end
    end
end


--Overwrite the original functions of the actin bar timers of the backRow
do
    --https://github.com/esoui/esoui/blob/8af014ab2db2fa23b14a7a268d58b9bcdd3b3818/esoui/ingame/actionbar/actionbar.lua#L232
    local GAMEPAD_CONSTANTS =
    {
        backRowSlotOffsetY = -17,
        backRowUltimateSlotOffsetY = -30,
    }
    local KEYBOARD_CONSTANTS =
    {
        backRowSlotOffsetY = -17,
        backRowUltimateSlotOffsetY = -20,
    }

    local fillBarUpdateFCOCSHandlerOnUpdateName = "FCOCS_FillBarUpdate"


    local function myUpdateFillBarAddition(selfActionBarTimer, activeDuration)
        activeDuration = activeDuration or selfActionBarTimer:HasValidDuration()
        --d("[FCOCS]myUpdateFillBarAddition - activeDuration: " ..tostring(activeDuration))
        local timeLeftLabelControl = selfActionBarTimer.timeLeftLabelControl
        if not timeLeftLabelControl then return end
        local function disableTimeLeftLabel()
            --d("<disableTimeLeftLabel!")
            --Unregister the FCOCS handler after the original one
            selfActionBarTimer.slot:SetHandler("OnUpdate", nil, fillBarUpdateFCOCSHandlerOnUpdateName)
            timeLeftLabelControl:SetHidden(true)
            timeLeftLabelControl:SetText("")
        end
        if not activeDuration then
            disableTimeLeftLabel()
            return
        end
        local nowInMS = GetFrameTimeMilliseconds()
        local endTimeInMS = selfActionBarTimer.endTimeMS
        local secondsLeft = 0
        if endTimeInMS > nowInMS then
            secondsLeft = (endTimeInMS - nowInMS) / 1000
        end
        if secondsLeft > 0 then
            local SHOW_UNIT_OVER_THRESHOLD_S = ZO_ONE_MINUTE_IN_SECONDS
            local SHOW_DECIMAL_UNDER_THRESHOLD_S = ZO_EFFECT_EXPIRATION_IMMINENCE_THRESHOLD_S
            local timeLeftString = ZO_FormatTimeShowUnitOverThresholdShowDecimalUnderThreshold(secondsLeft, SHOW_UNIT_OVER_THRESHOLD_S, SHOW_DECIMAL_UNDER_THRESHOLD_S, TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT)
            timeLeftLabelControl:SetHidden(false)
            timeLeftLabelControl:SetText(timeLeftString)
        else
            disableTimeLeftLabel()
        end
    end

    local function CreateTimeLeftLabelControl(selfButtonTimer)
        local slotNum = selfButtonTimer:GetSlot()
--d("[FCOCS]CreateTimeLeftLabelControl - slotNum: " ..tostring(slotNum))
        local timeLeftLabelSuffix = "TimeLeftLabel"
        local iconTexture = selfButtonTimer.iconTexture
        local timeLeftLabelControl = GetControl(iconTexture, timeLeftLabelSuffix)
        if not timeLeftLabelControl then
            timeLeftLabelControl = WM:CreateControl(iconTexture:GetName() .. timeLeftLabelSuffix, iconTexture, CT_LABEL)
            timeLeftLabelControl:SetFont(IsInGamepadPreferredMode() and "ZoFontGamepadBold27" or "ZoFontGameShadow")
            timeLeftLabelControl:SetScale(0.8)
            timeLeftLabelControl:SetWrapMode(TEX_MODE_CLAMP)
            timeLeftLabelControl:SetText("")
            timeLeftLabelControl:ClearAnchors()
            timeLeftLabelControl:SetDimensions(iconTexture:GetWidth() - 8, 18)
            timeLeftLabelControl:SetAnchor(CENTER, iconTexture, CENTER, 0, 0)
            timeLeftLabelControl:SetHidden(true)
            timeLeftLabelControl:SetMouseEnabled(false)
            timeLeftLabelControl:SetDrawLevel(5)
            timeLeftLabelControl:SetDrawTier(DT_HIGH)
            timeLeftLabelControl:SetDrawLayer(DL_OVERLAY)
            timeLeftLabelControl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            myUpdateFillBarAddition(selfButtonTimer, nil)
        end
        return timeLeftLabelControl
    end

    SecurePostHook(ZO_ActionBarTimer, "SetupBackRowSlot", function(selfButtonTimer, slotId, barType)
        local isValidBarType = barType == HOTBAR_CATEGORY_BACKUP or barType == HOTBAR_CATEGORY_PRIMARY
        if not isValidBarType then return end
        local settings = FCOChangeStuff.settingsVars and FCOChangeStuff.settingsVars.settings
        if settings and settings.repositionActionSlotTimers == true then
            local isUltimateSlot = selfButtonTimer:GetSlot() == ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
            local isGamePadMode = IsInGamepadPreferredMode()
            local offsetX = 0
            local offsetY
            if isUltimateSlot == false then
                offsetY = isGamePadMode and GAMEPAD_CONSTANTS.backRowSlotOffsetY or KEYBOARD_CONSTANTS.backRowSlotOffsetY
            else
                offsetY = isGamePadMode and GAMEPAD_CONSTANTS.backRowUltimateSlotOffsetY or KEYBOARD_CONSTANTS.backRowUltimateSlotOffsetY
            end

            local offsetSettings = settings.repositionActionSlotTimersOffset
            offsetX = offsetSettings.x
            offsetY = offsetY + offsetSettings.y

            local shown = isValidBarType and GetSlotType(slotId, barType) ~= ACTION_TYPE_NOTHING and selfButtonTimer.active and selfButtonTimer.showBackRowSlot
--d(string.format("~~~~~~~~~~~~~~~~~~~~\n[FCOCS]ZO_ActionBarTimer:SetupBackRowSlot-slotId: %s, name: %s, shown: %s, offsetX: %s, offsetY: %s", tostring(slotId), tostring(selfButtonTimer.slot:GetName()), tostring(shown), tostring(offsetX), tostring(offsetY)))
            if shown == true then
                --[[
                --Add the seconds left label to the texture, centured
                if settings.showActionSlotTimersTimeLeftNumber == true then
                    if selfButtonTimer.timeLeftLabelControl == nil then
                        selfButtonTimer.timeLeftLabelControl = CreateTimeLeftLabelControl(selfButtonTimer)
                    end
                end
                ]]

                --Reposition the action bar timer control
                local timerSlotControl = selfButtonTimer.slot
                local _, _, target = timerSlotControl:GetAnchor(0)
                if target ~= nil then
                    ZO_ActionBarTimer.ApplyAnchor(selfButtonTimer, target, offsetY, offsetX)
                end
            end
        end
    end)

    SecurePostHook(ZO_ActionBarTimer, "ApplyAnchor", function(selfButtonTimer, target, offsetY, offsetX)
        local settings = FCOChangeStuff.settingsVars and FCOChangeStuff.settingsVars.settings
        if not settings or not settings.repositionActionSlotTimers then return end
        local offsetSettings = settings.repositionActionSlotTimersOffset
--d(string.format("[FCOCS]ZO_ActionBarTimer.ApplyAnchor-offsetX: %s, offsetY: %s", tostring(offsetX), tostring(offsetY)))
        selfButtonTimer.slot:ClearAnchors()
        selfButtonTimer.slot:SetAnchor(CENTER, target, CENTER, offsetX, offsetY)
        selfButtonTimer:ApplySwapAnimationStyle(offsetY, offsetY - offsetSettings.y)
    end)

    ZO_PreHook(ZO_ActionBarTimer, "ApplySwapAnimationStyle", function(selfButtonTimer, offsetY, offsetYOrig)
        if not offsetYOrig then return false end
        local settings = FCOChangeStuff.settingsVars and FCOChangeStuff.settingsVars.settings
        if not settings or not settings.repositionActionSlotTimers then return false end

--d(string.format("[FCOCS]ZO_ActionBarTimer.ApplySwapAnimationStyle-offsetY: %s, offsetYOrig: %s", tostring(offsetY), tostring(offsetYOrig)))
        local translateDownAnimation = selfButtonTimer.backBarSwapAnimation:GetAnimation(1)
        local frameSizeDownAnimation = selfButtonTimer.backBarSwapAnimation:GetAnimation(2)
        local iconSizeDownAnimation = selfButtonTimer.backBarSwapAnimation:GetAnimation(3)
        local translateUpAnimation = selfButtonTimer.backBarSwapAnimation:GetAnimation(4)
        local frameSizeUpAnimation = selfButtonTimer.backBarSwapAnimation:GetAnimation(5)
        local iconSizeUpAnimation = selfButtonTimer.backBarSwapAnimation:GetAnimation(6)

        translateDownAnimation:SetStartOffsetY(offsetY)
        translateDownAnimation:SetEndOffsetY(0)
        translateUpAnimation:SetStartOffsetY(0)
        translateUpAnimation:SetEndOffsetY(offsetY)

        local width, height = selfButtonTimer.slot:GetDimensions()
        frameSizeDownAnimation:SetStartAndEndWidth(width, width)
        frameSizeDownAnimation:SetStartAndEndHeight(height, 0)
        frameSizeUpAnimation:SetStartAndEndWidth(width, width)
        frameSizeUpAnimation:SetStartAndEndHeight(0, height)

        width, height = selfButtonTimer.iconTexture:GetDimensions()
--d(string.format(">ApplySwapAnimationStyle-icontexture width: %s, height: %s", tostring(width), tostring(height)))
        if height < width then height = width end
        iconSizeDownAnimation:SetStartAndEndWidth(width, width)
        iconSizeDownAnimation:SetStartAndEndHeight(height, 0)
        iconSizeUpAnimation:SetStartAndEndWidth(width, width)
        iconSizeUpAnimation:SetStartAndEndHeight(0, height)

        return true
    end)

    local registerForUpdateClearStackLabelEventPrefix = "FCOCS_ActionButton_SetStackCount_ClearStackLabel_Slot"
    SecurePostHook(ActionButton, "SetStackCount", function(selfActionButton, stackCount)
        if stackCount == 0 then return end
        local hotBarCategory = GetActiveHotbarCategory()
        local endTimeMS = selfActionButton.endTimeMS
        local slotNum = selfActionButton:GetSlot()
        --local remainingEffectTimeMS = endTimeMS - currentTime
        local remainingEffectTimeMS = GetActionSlotEffectTimeRemaining(slotNum, hotBarCategory)
        local stackCountChecked = GetActionSlotEffectStackCount(slotNum, hotBarCategory)
--d("[SetStackCount] slotNum: " ..tostring(slotNum) ..", showTimer: " ..tostring(selfActionButton.showTimer) ..", remainingEffectTimeMS: " ..tostring(remainingEffectTimeMS) .. ", endTimeMS: " ..tostring(endTimeMS) .. ", stackCount/checked: " ..tostring(stackCount) .. "/" ..tostring(stackCountChecked))
        if stackCountChecked <= 0 or not selfActionButton.showTimer or endTimeMS == nil then return end

        local function clearStackLabelNow()
            EM:UnregisterForUpdate(registerForUpdateClearStackLabelEventPrefix..slotNum)
            selfActionButton.stackCountText:SetHidden(true)
        end
        --No timer left, but stackCount is still shown? Hide it
        if remainingEffectTimeMS <= 0 then
            clearStackLabelNow()
        else
            EM:UnregisterForUpdate(registerForUpdateClearStackLabelEventPrefix..slotNum)
            EM:RegisterForUpdate(registerForUpdateClearStackLabelEventPrefix..slotNum, remainingEffectTimeMS, clearStackLabelNow)
        end
    end)

    --Add the time left as seconds to the slot texture, centered
    SecurePostHook(ZO_ActionBarTimer, "SetFillBar", function(selfActionBarTimer)
        local settings = FCOChangeStuff.settingsVars and FCOChangeStuff.settingsVars.settings
        if not settings or not settings.showActionSlotTimersTimeLeftNumber == true then return false end

        --local slotNum = selfActionBarTimer:GetSlot()
--d("[FCOCS]ZO_ActionBarTimer:SetFillBar - slotNum: " .. tostring(slotNum))
        if not selfActionBarTimer.timeLeftLabelControl then
            selfActionBarTimer.timeLeftLabelControl = CreateTimeLeftLabelControl(selfActionBarTimer)
        end
        if not selfActionBarTimer:HasValidDuration() then
            myUpdateFillBarAddition(selfActionBarTimer, false)
            return
        else
            --Register a handler after the original one
            myUpdateFillBarAddition(selfActionBarTimer, true)
            selfActionBarTimer.slot:SetHandler("OnUpdate", function() myUpdateFillBarAddition(selfActionBarTimer) end, fillBarUpdateFCOCSHandlerOnUpdateName, CONTROL_HANDLER_ORDER_AFTER, "FillBarUpdate")
        end
    end)

    --[[
    local function OnActionSlotEffectUpdated(_, hotbarCategory, actionSlotIndex)
        local physicalSlot = ZO_ActionBar_GetButton(actionSlotIndex, hotbarCategory)
        local remainingEffectTimeMS = GetActionSlotEffectTimeRemaining(actionSlotIndex, hotbarCategory)
        d("[EVENT_ACTION_SLOT_EFFECT_UPDATE]hotbarCategory: " ..tostring(hotbarCategory) .. ", actionSlotIndex: " ..tostring(actionSlotIndex) .. ", remainingTime: " ..tostring(remainingEffectTimeMS))
    end
    local function OnActionSlotEffectCleared(_)
        d("[EVENT_ACTION_SLOT_EFFECTS_CLEARED")
    end
    EM:RegisterForEvent("FCOCS_TEST", EVENT_ACTION_SLOT_EFFECT_UPDATE, OnActionSlotEffectUpdated)
    EM:RegisterForEvent("FCOCS_TEST", EVENT_ACTION_SLOT_EFFECTS_CLEARED, OnActionSlotEffectCleared)
    ]]
end

local skillsOnEffectivelyShownHooked =false
function FCOChangeStuff.skillChanges()
    if not skillsOnEffectivelyShownHooked then
        --Enable the context menu at the skills, if enabled in the settings
        ZO_PreHook("ZO_Skills_OnEffectivelyShown", function(ctrl)
            if not FCOChangeStuff.settingsVars.settings.enableSkillLineContextMenu then return false end
            --d("[ZO_Skills_OnEffectivelyShown]ctrl: " .. tostring(ctrl:GetName()))
            zo_callLater(function() FCOChangeStuff.preHookSkillLinesOnMouseDown() end, 150)
        end)
        skillsOnEffectivelyShownHooked = true
    end
end