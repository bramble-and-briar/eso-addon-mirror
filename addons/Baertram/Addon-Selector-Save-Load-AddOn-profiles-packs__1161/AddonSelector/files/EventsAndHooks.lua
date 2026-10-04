local AS = AddonSelectorGlobal
local constants = AS.constants
local utility = AS.utility
local utilityOtherAddOns = utility.otherAddOns
local narration = AS.narration
local ZOsControls = constants.ZOsControls
local otherAddonsFlags = AS.flags.otherAddons
local stringConstants = constants.strings

local SEARCH_TYPE_NAME = constants.SEARCH_TYPE_NAME

local ADDON_NAME = AS.name

local GLOBAL_PACK_NAME = constants.GLOBAL_PACK_NAME

--local currentCharIdNum = constants.currentCharIdNum
local currentCharId = constants.currentCharId
local currentCharName = constants.currentCharName
--local isExcludedFromChangeEnabledState = constants.isExcludedFromChangeEnabledState

local string_gsub = string.gsub

local booleanToOnOff = stringConstants.booleanToOnOff

--Flags
local flags = AS.flags

--Functions
local checkIfMenuOwnerIsZOAddOns = utility.checkIfMenuOwnerIsZOAddOns
local OnUpdateDoNarrate = narration.OnUpdateDoNarrate
local IsAccessibilityUIReaderEnabled = narration.IsAccessibilityUIReaderEnabled
local enableZO_AddOnsUI_controlNarration = narration.enableZO_AddOnsUI_controlNarration
local AddNewChatNarrationText = narration.AddNewChatNarrationText

local getOwnerPrefixStr = utility.getOwnerPrefixStr
local updateAddonsEnabledCountThrottled = utility.updateAddonsEnabledCountThrottled
local updateDDLThrottled = utility.updateDDLThrottled
local AddonSelectorUpdateCount = utility.AddonSelectorUpdateCount
local unregisterOldEventUpdater = utility.unregisterOldEventUpdater
local BuildAddOnReverseLookUpTable = utility.BuildAddOnReverseLookUpTable
local updateEnableAllAddonsCtrls = utility.updateEnableAllAddonsCtrls
local updateDDL = utility.updateDDL
local areAllAddonsEnabled = utility.areAllAddonsEnabled

local getCharactersOfAccount = utility.getCharactersOfAccount
local getAddonNameAndData = utility.getAddonNameAndData
local checkIfGlobalPacksShouldBeShown = utility.checkIfGlobalPacksShouldBeShown

local isAddonCategoryAddOnEnabled = utilityOtherAddOns.isAddonCategoryAddOnEnabled
local getAddonCategoryCategories = utilityOtherAddOns.getAddonCategoryCategories

local ADDON_MANAGER =           utility.GetAddonManager()
local ADDON_MANAGER_OBJECT =    utility.GetAddonManagerObject()

local AddonSelector_GetLocalizedText = AddonSelector_GetLocalizedText
local packNameGlobal = AddonSelector_GetLocalizedText("packNameGlobal")


--ZOs reference variables
local tos = tostring
local strfor = string.format
local strlow = string.lower

local EM = EVENT_MANAGER
local SM = SCENE_MANAGER

--======================================================================================================================
-- Events and Hooks
--======================================================================================================================


------------------------------------------------------------------------------------------------------------------------
-- ZO_Menu
--------------------------------------------------------------------------------------------------------------------------
--todo



------------------------------------------------------------------------------------------------------------------------
-- GameMenu
--------------------------------------------------------------------------------------------------------------------------
local function TreeEntryOnSelected(control, data, selected, reselectingDuringRebuild)
    control:SetSelected(selected)
    if not reselectingDuringRebuild then
        if selected then
            if data.callback then
                data.callback(control)
            end
        else
            if data.unselectedCallback then
                data.unselectedCallback(control)
            end
        end
    end
end

local gameMenuHeadersHooked = false
local function hideAddonMenu()
    --Hide the addon's fragment again if it was added by AddonSelector!
    if AS.flags.AddedAddonsFragment == true then
        SM:RemoveFragment(ADDONS_FRAGMENT)
        AS.flags.AddedAddonsFragment = false
    end
end

local function showAddOnsList()
    AS.flags.addonListWasOpenedByAddonSelector = false
    if not SM then return end
    if not ADDONS_FRAGMENT then return end
    if ADDONS_FRAGMENT and ADDONS_FRAGMENT.control and not ADDONS_FRAGMENT.control:IsHidden() then return true end
    --Show the game menu (as if you have pressed ESC key)
    if not SM:IsShowing("gameMenuInGame") then
        ZO_SceneManager_ToggleGameMenuBinding()
    end
    --Show the addons fragment -> Adding the fragment will keep the fragment shown if we change the menus (in gamepad mode), so we need to remove the fragment on
    --game menu change again!
    --SM:AddFragment(ADDONS_FRAGMENT)
    --Call the callback of the game menu entry of "AddOns"
    --ZO_GameMenu_InGameNavigationContainerScrollChildZO_GameMenu_ChildlessHeader_WithSelectedState1.callback()
    local headerControls = ZO_GameMenu_InGame.gameMenu.headerControls
    if headerControls ~= nil then
        local headersHookedCount = 0
        for headerControlText, headerControlData in pairs(headerControls) do
            if headerControlText == AddonSelector_GetLocalizedText("addons") then
                if headerControlData.data and headerControlData.data.callback then
                    --Is the addnons fragment already added to the current scene?
                    if not SM:GetCurrentScene():HasFragment(ADDONS_FRAGMENT) then
                        TreeEntryOnSelected(headerControlData.control, headerControlData.data, true, nil)
                    end
                    AS.flags.addonListWasOpenedByAddonSelector = true
                    AS.flags.AddedAddonsFragment            = true
                end
            else
                if not gameMenuHeadersHooked then
                    local menuEntryToHook = (headerControlData.data and headerControlData.data.callback) or (headerControlData.control and headerControlData.control.SetSelected)
                    if menuEntryToHook ~= nil then
                        local origHeaderCallback = menuEntryToHook
                        if headerControlData.data.callback ~= nil then
                            headersHookedCount = headersHookedCount + 1
                            headerControlData.data.callback = function(...)
                                hideAddonMenu()
                                return origHeaderCallback(...)
                            end
                        else
                            headersHookedCount = headersHookedCount + 1
                            headerControlData.control.SetSelected = function(...)
                                hideAddonMenu()
                                return origHeaderCallback(...)
                            end
                        end
                    end
                end
            end
        end
        if AS.flags.addonListWasOpenedByAddonSelector == true then
            if headersHookedCount > 0 then gameMenuHeadersHooked = true end
            return true
        end
    end
    return
end
AS.showAddOnsList = showAddOnsList

local function openGameMenuAndAddOnsAndThenLoadPack(args, doNotShowAddOnsScene, noReloadUI, charName, wasCalledFromLogout)
--d("[AS]openGameMenuAndAddOnsAndThenLoadPack - args: " .. tos(args) .. ", doNotShowAddOnsScene: " ..tos(doNotShowAddOnsScene) .. ", noReloadUI: " ..tos(noReloadUI) .. ", charName: " ..tos(charName) .. ", wasCalledFromLogout: " ..tos(wasCalledFromLogout))
    if not args or args == "" then return  end
    doNotShowAddOnsScene = doNotShowAddOnsScene or false
    wasCalledFromLogout = wasCalledFromLogout or false
    if noReloadUI == nil then noReloadUI = true end

    local packNameLower
    local isCharacterPack = false
    local svForPacks, charId, characterName

    --Parse the arguments string
    local options = {}
    --[[ -- Split only at spaces
    --local searchResult = {} --old: searchResult = { string.match(args, "^(%S*)%s*(.-)$") }
    for param in strgma(args, "([^%s]+)%s*") do
        if (param ~= nil and param ~= "") then
            options[#options+1] = strlow(param)
        end
    end
    ]]
    local charNameForMsg = charName

    --Split and respect quotes and double quotes
    options = utility.splitStringAndRespectQuotes(args)
    if ZO_IsTableEmpty(options) then return end
    local numOptions = #options
    --d(">got here, #options: " .. tos(numOptions))
    if numOptions >= 1 then

        local characterIdForSV, charNameForSV = currentCharId, GLOBAL_PACK_NAME

        if numOptions == 1 then
            --Save character packs is enabled at the settings? Assume we load a character pack then
            --if not: Assume we load a global pack then
            isCharacterPack = (not wasCalledFromLogout and charName ~= nil and charName ~= GLOBAL_PACK_NAME and true)
                    or (wasCalledFromLogout == true and ( (charName ~= nil and charName ~= GLOBAL_PACK_NAME and true) or (charName ~= nil and charName == GLOBAL_PACK_NAME and false) ))
                    or AS.acwsv.saveGroupedByCharacterName
            packNameLower = options[1]
        else
            --2 or more params have been enered at the chat.
            --1st param == "string": Character name
            --or 1st param == "number": 1 = global, 2 = character pack
            --2nd param == string: Addon pack
            if charName == nil or charName == "" then
                local firstParamIsNumber = tonumber(options[1])
                local firstParamType = type(firstParamIsNumber)
                --d("> " .. options[1] .. ", firstParamType: " ..tos(firstParamType))
                if firstParamType ~= "number" then
                    charName = tos(options[1])
                    charNameForMsg = charName
                end
            end

            isCharacterPack = (((charName ~= nil and charName ~= GLOBAL_PACK_NAME) or tos(options[1]) == "2") and true) or AS.acwsv.saveGroupedByCharacterName
            packNameLower = table.concat(options, " ", 2)
        end

        --d(">charName: " .. tos(charName) .. ", packName: " ..tos(packNameLower) .. ", isCharacterPack: " ..tos(isCharacterPack))

        if packNameLower ~= nil then
            --Character is the currentlyLoggedIn or any other?
            if isCharacterPack == true then
                characterIdForSV, charNameForSV = AS.getCharacterIdAndNameForSV(charName)
                charNameForMsg = charNameForSV
            end

            --Search the packname now as character or global pack
            svForPacks, charId, characterName = AS.getSVTableForPackBySavedType((not isCharacterPack and GLOBAL_PACK_NAME) or nil, (isCharacterPack and characterIdForSV) or nil)

            --[[
AS._debugSlashLoadPack = {
    __doNotShowAddOnsScene = doNotShowAddOnsScene,
    __saveGroupedByCharacterName = AS.acwsv.saveGroupedByCharacterName,
    _charName = charName,
    _packNameLower = packNameLower,
    ___options = options,
    _isCharacterPack = isCharacterPack,
    svForPacks = svForPacks,
    charId = charId,
    characterName = characterName,
    characterIdForSV = characterIdForSV,
    charNameForSV = charNameForSV,
}
            ]]

            if svForPacks ~= nil then
                packNameLower = strlow(packNameLower)

                charNameForMsg = characterName
                local addOnsUIwasNotOpened = false
                --Now check if the packname is in the list
                for packName, addonsInPack in pairs(svForPacks) do
                    if strlow(packName) == packNameLower then
                        --Show the game menu and open the AddOns manager now (if not suppressed)
                        if not addOnsUIwasNotOpened and not doNotShowAddOnsScene then
                            if not showAddOnsList() then
                                return
                            end
                            addOnsUIwasNotOpened = true
                        end

                        --d(">pack found -> loading it now!")
                        local packData = ZO_ShallowTableCopy(addonsInPack)
                        packData.charName = packData.charName or ((isCharacterPack == true and characterName) or GLOBAL_PACK_NAME)

                        --Clear the dropdown selected entry
                        AS.flags.doNotReloadUI = noReloadUI
                        --AS.flags.skipOnAddonPackSelected = true
                        --Select this pack now at the dropdown
                        AS.loadAddonPack(packName, packData, false, doNotShowAddOnsScene, isCharacterPack)
                        --AS.flags.skipOnAddonPackSelected = false
                        AS.flags.doNotReloadUI = noReloadUI

                        --We only get here if auto reloadUI pack is disabled
                        if not wasCalledFromLogout and not AS.flags.doNotReloadUI and AS.acwsv.autoReloadUI == false then
                            ReloadUI("ingame")
                        end

                        utility.clearAndUpdateDDL()

                        local textForChat = wasCalledFromLogout and AddonSelector_GetLocalizedText("packNameLoadAtLogoutFound") or AddonSelector_GetLocalizedText("packNameLoadFound")

                        d(string.format(textForChat, tos(packName), tos(not isCharacterPack and packNameGlobal or characterName), (wasCalledFromLogout and currentCharName) or nil))
                        return true
                    end
                end
            end
        end
    end
    d(string.format(AddonSelector_GetLocalizedText("packNameLoadNotFound"), tos(packNameLower), tos((not isCharacterPack and packNameGlobal) or charNameForMsg)))
    return false
end
AS.OpenGameMenuAndAddOnsAndThenLoadPack = openGameMenuAndAddOnsAndThenLoadPack

local function openGameMenuAndAddOnsAndThenSearch(addonName, doNotShowAddOnsScene, isAddonCategorySearched)
--d("[AS]openGameMenuAndAddOnsAndThenSearch-addonName: " ..tos(addonName) .. ", doNotShowAddOnsScene: " ..tos(doNotShowAddOnsScene) .. ", isAddonCategorySearched: " ..tos(isAddonCategorySearched))
    if not addonName or addonName == "" then return end
    doNotShowAddOnsScene = doNotShowAddOnsScene or false
    isAddonCategorySearched = isAddonCategorySearched or false
    if not doNotShowAddOnsScene then
        --Show the game menu and open the AddOns
        if not showAddOnsList() then
--d("<aborted addon search!")
            return
        end
    end
    --Set the focus to the addon search box
    local searchBox = AS.controls.searchBox
    if not isAddonCategorySearched then
        if searchBox then
            searchBox:SetText(addonName)
            searchBox:TakeFocus()
        end
    else
        --Do not add the searched category to the search history
        if searchBox then
            searchBox:SetText("")
        end
    end
    --Search for the addonName or category
    AddonSelector_SearchAddon(SEARCH_TYPE_NAME, addonName, false, isAddonCategorySearched)
    AS.flags.addonListWasOpenedByAddonSelector = false
end
AS.OpenGameMenuAndAddOnsAndThenSearch = openGameMenuAndAddOnsAndThenSearch



------------------------------------------------------------------------------------------------------------------------
-- Multi select of addon rows via SHIFT key
--------------------------------------------------------------------------------------------------------------------------
local alreadyAddedMultiSelectByShiftKeyHandlers = {}

local function AddonSelector_MultiSelect(control, addonEnabledCBox, button)
--d("AddonSelector_MultiSelect")
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return false end
    if addonEnabledCBox == nil then return false end
    --Get the current's row data
    --local addonRowControl = addonEnabledCBox:GetParent()
    local addonRowControl = control
    if addonRowControl == nil or addonRowControl.data == nil
            or addonRowControl.data.sortIndex == nil or addonRowControl.data.index == nil then return false end
    --Is the shift key pressed on the keyboard?
    local isShiftDown = IsShiftKeyDown()
    --local isAddonEnabled = addonEnabledCBox.checkState
--d("[AddonSelector]AddonSelector_MultiSelect(" .. addonRowControl:GetName() .. ", button: " .. tos(button) .. "), isShiftDown: " ..tos(isShiftDown) .. ", enabled: " .. tos(isAddonEnabled))
    --Shift not pressed: Remember the currently clicked control as first one + remember it's data as table copy so it won't change with the next "scroll" indside the addonlist,
    --as the addon list rows are re-used during scroll (they belong to a control pool)!
    if not isShiftDown then
        --Save the currently enabled addons as a special "backup pack" so we can restore it later
        AS.saveAddonsAsPackBeforeMassMarking()

        AS.controls.controlData.firstControl     = addonRowControl
        local currentAddonRowData       = ZO_ShallowTableCopy(addonRowControl.data)
        AS.controls.controlData.firstControlData = currentAddonRowData
--d(">no shift key pressed -> First control was set to: " ..tos(ZOsControls.ZOAddOnsList.data[currentAddonRowData.sortIndex].data.strippedAddOnName))
        return false
    end

    local firstClickedControl = AS.controls.controlData.firstControl
    --Not the current row clicked and shift key was pressed: The actually clicked row is the "to" range row
    if isShiftDown and (firstClickedControl and addonRowControl ~= firstClickedControl) then
--d(">Shift key was pressed and addonRow is not the same as the first pressed one")
        local firstRowData = AS.controls.controlData.firstControlData
        if firstRowData == nil or firstRowData.sortIndex == nil then return false end
        --local firstControlAddonName     = ZOsControls.ZOAddOnsList.data[firstRowData.sortIndex].data.strippedAddOnName
        local currentRowData = addonRowControl.data
        --local currentControlAddonName   = ZOsControls.ZOAddOnsList.data[currentRowData.sortIndex].data.strippedAddOnName
--d(">Trying to mark from \"" .. tos(firstControlAddonName) .. "\" to \"" .. tos(currentControlAddonName).."\"")

        local step = ((firstRowData.sortIndex - currentRowData.sortIndex < 0) and 1) or -1
        --is the reverse addonIndex lookup table empty? Build it.
        if AS.ReverseLookup == nil then
            BuildAddOnReverseLookUpTable()
        end
        --From the first selected row to the currently selected row with SHIFT key pressed:
        -- loop forwards/backwards and simulate the click on the enable/disable checkbox
        local checkBoxNewState = true
        if firstRowData.addOnEnabled == true then checkBoxNewState = false end
--d(">From sortIndex: " .. tos(firstRowData.sortIndex) .. " to sortindex: " .. tos(currentRowData.sortIndex) .. ", step: " .. tos(step) .. ", enabledNew: " .. tos(checkBoxNewState))
        --Disable the update of the addon count during the loop, to avoid lags
        AS.flags.noAddonNumUpdate     = true

        --local checkState = (firstRowData.addOnEnabled == true and TRISTATE_CHECK_BUTTON_CHECKED) or TRISTATE_CHECK_BUTTON_UNCHECKED
        AS.lastData.lastChangedAddOnVars = {}
        for addonSortIndex = firstRowData.sortIndex, currentRowData.sortIndex, step do
            local currentAddonListRowData = ZOsControls.ZOAddOnsList.data[addonSortIndex].data
            if currentAddonListRowData then
--d(">>currentRowData: " ..tos(currentAddonListRowData.sortIndex) .. ", name: "..tos(currentAddonListRowData.strippedAddOnName))
                --Get the addon index
                local addonIndex = AS.ReverseLookup[addonSortIndex]
                if addonIndex ~= nil and addonIndex >= 0 then
                    --d(">>sortIndex: " .. tos(addonSortIndex) .. ", addonIndex: " .. tos(addonIndex))
                    --Check if the addon got dependencies that need to be enabled if the addon will be enabled
                    local changeCheckboxNow = false
                    --Only if not the last clicked entry was met: Will be always checked and updated after the addonManager data was refreshed as the click on the
                    --name / checkbox changes the row already manually
                    if addonSortIndex ~= currentRowData.sortIndex then
                        if checkBoxNewState == true then
                            if currentAddonListRowData.addOnState ~= ADDON_STATE_ENABLED and not currentAddonListRowData.missing then
                                changeCheckboxNow = true
                                --checkDependsOn(currentAddonListRowData)
                            end
                        else
                            if currentAddonListRowData.addOnState == ADDON_STATE_ENABLED and not currentAddonListRowData.missing then
                                changeCheckboxNow = true
                            end
                        end
                    else
                        changeCheckboxNow = true
                    end
                    --Set the state off the addon's enable/disable checkbox the same like first row state
                    if changeCheckboxNow == true then
                        ADDON_MANAGER:SetAddOnEnabled(addonIndex, checkBoxNewState)
                    end
                    --Variables for the check if the last changed AddOn's state is the same as the wished one. If not: Change it accordingly.
                    if changeCheckboxNow == true and addonSortIndex == currentRowData.sortIndex then
--d(">>>lastChangdAddOnVars: " .. tos(addonSortIndex) .. ", addonIndex: " .. tos(addonIndex))
                        AS.lastData.lastChangedAddOnVars.sortIndex     = addonSortIndex
                        AS.lastData.lastChangedAddOnVars.addonIndex    = addonIndex
                        AS.lastData.lastChangedAddOnVars.addonNewState = checkBoxNewState
                    end
                end
            end
        end
        --Enable the update of the addon count after the loop again
        AS.flags.noAddonNumUpdate = false
        --Refresh the visible data
--d("[AS]AddonSelector_MultiSelect - RefreshData()")
        ADDON_MANAGER_OBJECT:RefreshData()
        ZO_ScrollList_RefreshVisible(ZOsControls.ZOAddOnsList)
        return true
    else
        --Reset the first clicked data if the SHIFT key was pressed
        if isShiftDown then
--d(">Clicked with SHIFT key. Resetting first clicked data")
            AS.controls.controlData.firstControlData    = nil
            AS.firstClickedControl = nil
        end
    end
    return false
end

--Function to check if the last changed AddOn's state is the same as the wished one. If not: Change it accordingly.
local function AddonSelector_CheckLastChangedMultiSelectAddOn(rowControl)
--d("[AddonSelector]AddonSelector_CheckLastChangedMultiSelectAddOn")
    AS.lastData.lastChangedAddOnVars = AS.lastData.lastChangedAddOnVars
    if AS.lastData.lastChangedAddOnVars ~= nil and AS.lastData.lastChangedAddOnVars.addonIndex ~= nil and AS.lastData.lastChangedAddOnVars.addonNewState ~= nil and AS.lastData.lastChangedAddOnVars.sortIndex ~= nil then
--d(">addonIndex: " .. tos(AS.lastData.lastChangedAddOnVars.addonIndex) .. ", newState: " .. tos(AS.lastData.lastChangedAddOnVars.addonNewState))
        local preventerVarsWereSet = (AS.flags.noAddonNumUpdate or AS.flags.noAddonCheckBoxUpdate) or false
        if not preventerVarsWereSet then
            AS.flags.noAddonNumUpdate      = true
            AS.flags.noAddonCheckBoxUpdate = true
        end
        local newState = AS.lastData.lastChangedAddOnVars.addonNewState
        local currentAddonListRowData = ZOsControls.ZOAddOnsList.data[AS.lastData.lastChangedAddOnVars.sortIndex].data
        if not currentAddonListRowData then return end
--AS._currentAddonListRowData = currentAddonListRowData

        local changeCheckboxNow = false
        if newState == true then
--d(">newState: true")
            if currentAddonListRowData.addOnState ~= ADDON_STATE_ENABLED and not currentAddonListRowData.missing then
                changeCheckboxNow = true
                --checkDependsOn(currentAddonListRowData)
            end
        else
--d(">newState: false")
            if currentAddonListRowData.addOnState == ADDON_STATE_ENABLED and not currentAddonListRowData.missing then
                changeCheckboxNow = true
            end
        end
        if changeCheckboxNow == true then
--d(">Changing last addon now: " ..tos(currentAddonListRowData.strippedAddOnName))
            ADDON_MANAGER:SetAddOnEnabled(AS.lastData.lastChangedAddOnVars.addonIndex, newState)
            --Addon_Toggle_Enabled(rowControl)
            if not preventerVarsWereSet then
                AS.flags.noAddonNumUpdate      = false
                AS.flags.noAddonCheckBoxUpdate = false
            end
        end
        --Refresh the visible data
--d("[AS]AddonSelector_CheckLastChangedMultiSelectAddOn - RefreshData()")
        ADDON_MANAGER_OBJECT:RefreshData()
        ZO_ScrollList_RefreshVisible(ZOsControls.ZOAddOnsList)
        --Update the active addons count
        if not AS.flags.noAddonNumUpdate then
            AddonSelectorUpdateCount(50)
        end
    end
end

local function AddonSelector_HookSingleControlForMultiSelectByShiftKey(control)--eventCode, layerIndex, activeLayerIndex)
    if not control or not control.GetName then return end
    local controlName = control:GetName()
    if alreadyAddedMultiSelectByShiftKeyHandlers[controlName] then return end
    alreadyAddedMultiSelectByShiftKeyHandlers[controlName] = true

--d("[AddonSelector]AddonSelector_HookSingleControlForMultiSelectByShiftKey: " ..tos(controlName))
    local name = control:GetNamedChild("Name")
    if name ~= nil then
        local enabled = control:GetNamedChild("Enabled")
        if enabled ~= nil then
            ZO_PreHookHandler(enabled, "OnClicked", function(selfVar, button)
    --d("[AS]Enabled checkbox - OnClicked")
                --Do not run the same code (AddonSelector_MultiSelect) again if we come from the left mouse click on the name control
                if button ~= MOUSE_BUTTON_INDEX_LEFT then return false end
                if not areAllAddonsEnabled(true) then return end

                --Check shift key, or not. If yes: Mark/unmark all addons from first clicked row to SHIFT + clicked row.
                -- Else save clicked name sortIndex + addonIndex
                --[[
                local retVar = AddonSelector_MultiSelect(control, self, button)
                if retVar == true then
                    zo_callLater(function()
                        AddonSelector_CheckLastChangedMultiSelectAddOn(control)
                    end, 150)
                end
                ]]
                local isShiftKeyPressed = IsShiftKeyDown()
--d("Enabled_Clicked-shiftKey: " ..tos(isShiftKeyPressed))
                --Accessibility
                --Do not narrate if SHIFT key is pressed to "multi-select" addons (set end spot to enable/disable)?
                if not isShiftKeyPressed then
                    narration.OnAddonRowClickedNarrateNewState(control, nil)
                end

                --If the shift key was pressed do not enable the addon's checkbox by the normal function here but via function
                --AddonSelector_MultiSelect())
                return isShiftKeyPressed
            end)
            local enabledClick = enabled:GetHandler("OnClicked")
            name:SetMouseEnabled(true)
            name:SetHandler("OnMouseDown", nil)
            name:SetHandler("OnMouseDown", function(selfVar, button)
                if button ~= MOUSE_BUTTON_INDEX_LEFT then return false end
                if not areAllAddonsEnabled(true) then return end
--d("[AS]Clicked addon name")
                --Check shift key, or not. If yes: Mark/unmark all addons from first clicked row to SHIFT + clicked row.
                -- Else save clicked name sortIndex + addonIndex
                local retVar = AddonSelector_MultiSelect(control, enabled, button)

                --Set preventer variables in order to suppress duplicate code run at the checkbox
                AS.flags.noAddonNumUpdate      = true
                AS.flags.noAddonCheckBoxUpdate = true
                --Simulate a click on the checkbox left to the addon's name
                enabledClick(enabled, button)
                if retVar == true then
                    zo_callLater(function()
                        AddonSelector_CheckLastChangedMultiSelectAddOn(control)
                    end, 150)
                end
                AS.flags.noAddonCheckBoxUpdate = false
                AS.flags.noAddonNumUpdate      = false
                AddonSelectorUpdateCount(50)
            end)
        end
    end
end


------------------------------------------------------------------------------------------------------------------------
-- Load Hooks from AddonSelector Init
--------------------------------------------------------------------------------------------------------------------------
-- Toggles Enabled state when a row is clicked
-->Using  Votans Addon List function ADD_ON_MANAGER:OnEnabledButtonClicked so that dependencies are enabled too
local function Addon_Toggle_Enabled(rowControl, addonData)
--d("Addon_Toggle_Enabled")
    if not areAllAddonsEnabled(true) then return end

    --local addonIndex 	= rowControl.data.index
    local enabledBtn 	= rowControl:GetNamedChild("Enabled")
    local state 		= ZO_TriStateCheckButton_GetState(enabledBtn)
    local newState

    if state == TRISTATE_CHECK_BUTTON_CHECKED then
        -- changed so it automatically refreshes the multiButton (reload UI)
        --ADDON_MANAGER_OBJECT:ChangeEnabledState(addonIndex, TRISTATE_CHECK_BUTTON_UNCHECKED)
        newState = TRISTATE_CHECK_BUTTON_UNCHECKED
    else
        --ADDON_MANAGER_OBJECT:ChangeEnabledState(addonIndex, TRISTATE_CHECK_BUTTON_CHECKED)
        newState = TRISTATE_CHECK_BUTTON_CHECKED
    end
--d(">newState: " ..tos(newState))
    ADDON_MANAGER_OBJECT:OnEnabledButtonClicked(enabledBtn, newState)

--d(">1")

    --Accessibility
    --Do not narrate if SHIFT key is pressed to "multi-select" addons (set end spot to enable/disable)?
    if not IsShiftKeyDown() then
        narration.OnAddonRowClickedNarrateNewState(rowControl, newState, addonData)
    end
end
AS.Addon_Toggle_Enabled = Addon_Toggle_Enabled

local OrigAddonGetRowSetupFunc = ZO_AddOnManager.GetRowSetupFunction
function ZO_AddOnManager:GetRowSetupFunction()
--d("Manual PreHook ZO_AddOnManager:GetRowSetupFunction")
	local func = OrigAddonGetRowSetupFunc(self)

    return function(control, data)
        control:SetMouseEnabled(areAllAddonsEnabled(true))
        control:SetHandler("OnMouseUp", function(ctrl) Addon_Toggle_Enabled(ctrl, nil) end)

        --Accessibility
        if control:GetHandler("OnMouseEnter") ~= nil then
            ZO_PostHookHandler(control, "OnMouseEnter", function(ctrl) narration.OnAddonRowMouseEnterStartNarrate(ctrl) end)
        else
            control:SetHandler("OnMouseEnter", function(ctrl) narration.OnAddonRowMouseEnterStartNarrate(ctrl) end,   "AddonSelectorAddonRowOnMouseEnter")
        end
        --[[
                if control:GetHandler("OnMouseExit") ~= nil then
                    ZO_PostHookHandler(control, "OnMouseExit", function(ctrl) OnAddonRowMouseExitStopNarrate(ctrl) end)
                else
                    control:SetHandler("OnMouseExit", function(ctrl) OnAddonRowMouseExitStopNarrate(ctrl) end,      "AddonSelectorAddonRowOnMouseExit")
                end
        ]]

        local retVar
        local expandButton = control:GetNamedChild("ExpandButton")
        if expandButton == nil then
            local addonName, _ = getAddonNameAndData(control)
            d(string.format("[AddonSelector]ExpandButton missing: addon: %q, row: %s", tos(addonName), tos(control:GetName())))

            --Do not call the original setupFunction now as expandButton is missing and would lead to a nil error!
            -->zo_addonmanager.lua, row 174: expandButton:SetHidden(not data.expandable)
            --e.g. after selection of an addon, then ALT+TAB to desktop and see another monitor, then switch back to the addon manager of ESO
            --and move the mouse above an addon > Error message (maybe only if VotansAddonList is enabled too!).
        elseif data == nil then
            local addonName, _ = getAddonNameAndData(control)
            d(string.format("[AddonSelector]Data missing: addon: %q, row: %s", tos(addonName), tos(control:GetName())))
        else
            --Call original setupFunction: ZO_AddOnManager.GetRowSetupFunction
            retVar = func(control, data)
        end
        AddonSelector_HookSingleControlForMultiSelectByShiftKey(control)

        return retVar
    end
end

local function myLogoutCallback()
    local charSettings = AS.acwsvChar
    if charSettings == nil then return end
    local addonPackToLoad = charSettings.loadAddonPackOnLogout
    if addonPackToLoad == nil then return end
    --Skip tthe current logout/quit addon pack loading?
    if charSettings.skipLoadAddonPackOnLogout == true then return end

    AS.loadAddonPackNow(addonPackToLoad.packName, addonPackToLoad.charName, true, true, true)

    --return true --todo: Comment again after debugging! For debugging abort logout and quit!
end


--Load the hooks now
local wasLogoutPrehooked = flags.wasLogoutPrehooked
function AS.LoadHooks()
    -- Very hacky, but easiest method: Wipe out the game's TYPE_ID = 1 dataType and recreate it using my own template.
    -- Done to make the row controls mouseEnabled
    --[[ Disabled on advice by Votan, 31.08.2018, Exchanged with code lines below
    ADDON_MANAGER_OBJECT.list.dataTypes = {}
    ZO_ScrollList_AddDataType(ADDON_MANAGER_OBJECT.list, 1, "ZO_AddOnRow", 30, ADDON_MANAGER_OBJECT:GetRowSetupFunction())
    ]]
    if ADDON_MANAGER_OBJECT.list.dataTypes[1] then
        ADDON_MANAGER_OBJECT.list.dataTypes[1].setupCallback = ADDON_MANAGER_OBJECT:GetRowSetupFunction()
    else
        ZO_ScrollList_AddDataType(ADDON_MANAGER_OBJECT.list, 1, "ZO_AddOnRow", 30, ADDON_MANAGER_OBJECT:GetRowSetupFunction())
    end


    --PreHook the ChangeEnabledState function for the addon entries, in order to update the enabled addons number
    ZO_PreHook(ADDON_MANAGER_OBJECT, "ChangeEnabledState", function(ctrl, index, checkState)
        if not AS.flags.noAddonNumUpdate then
            AddonSelectorUpdateCount(50)
        end
    end)
    if ADDON_MANAGER ~= nil then
        --PreHook the SetAddOnEnabled function for the addon entries, in order to update the enabled addons number
        ZO_PreHook(ADDON_MANAGER, "SetAddOnEnabled", function(ctrl)
            --d("[AddonSelector]PreHook SetAddOnEnabled")
            if not AS.flags.noAddonNumUpdate then
                updateAddonsEnabledCountThrottled(50)
                --AddonSelectorUpdateCount(50)
                --Rebuild the Dropdown's entry data so the enabled addon state is reflected correctly
                -->After loading a pack this will lead to deselected packname from dropdoen box! So we need to skip this here if a pack was "loaded"
                if not AS.flags.skipUpdateDDL then
                    updateDDLThrottled(250)
                end
            end
            --if AddonSelector.AS.flags.noAddonCheckBoxUpdate then return true end
        end)
        --EM:RegisterForEvent("AddonSelectorMultiselectHookOnShow", EVENT_ACTION_LAYER_PUSHED, function(...) AddonSelector_HookForMultiSelectByShiftKey(...) end)

        --Make the AddOns list movable
        if ZOsControls.ZOAddOns ~= nil then
            ZOsControls.ZOAddOns:SetMouseEnabled(true)
            ZOsControls.ZOAddOns:SetMovable(true)
        end
    end

    --PreHook the Addonmanagers OnShow function
    ZO_PreHook(ADDON_MANAGER_OBJECT, "OnShow", function(addonManagerObject)
        --d("ADD_ON_MANAGER:OnShow")
        --Hide other controls/keybinds
        AS.OnShow_HideStuff()

        --Update the count/total number at the addon manager titel
        if not AS.flags.noAddonNumUpdate then
            AddonSelectorUpdateCount(250, true)
        end
        --Clear the search text editbox
        AS.controls.searchBox:SetText("")
        --Reset the searched table completely
        AS.searchAndFoundData.alreadyFound = {}
        --Clear the previously searched data and unregister the events
        unregisterOldEventUpdater()

        zo_callLater(function()
            --Reset variables
            AS.controls.controlData.firstControl     = nil
            AS.controls.controlData.firstControlData = nil
            --Build the lookup table for the sortIndex to row index of addon rows
            BuildAddOnReverseLookUpTable()
            --Hook the visible addon rows (controls) to set a hanlder for OnMouseDown
            --AddonSelector_HookForMultiSelectByShiftKey()

            --Refresh the dropdown contents once so the libraries and addons are split up into proper tables
            updateDDL()

            --PostHook the new Enable All addons checkbox function so that the controls of Circonians Addon Selector get disabled/enabled
            updateEnableAllAddonsCtrls()
            if not flags.enableAllAddonsCheckboxHooked and ZOsControls.enableAllAddonsCheckboxCtrl ~= nil then
                ZO_PostHookHandler(ZOsControls.enableAllAddonsCheckboxCtrl, "OnMouseUp", function(checkboxCtrl, mouseButton, isUpInside)
                    if not isUpInside or mouseButton ~= MOUSE_BUTTON_INDEX_LEFT then return end
                    areAllAddonsEnabled(false)
                end)
                local disableAllAddonsToggleFunc = ZOsControls.enableAllAddonsCheckboxCtrl.toggleFunction
                ZOsControls.enableAllAddonTextCtrl:SetMouseEnabled(true)
                ZOsControls.enableAllAddonTextCtrl:SetHandler("OnMouseUp", function(textCtrl, mouseButton, isUpInside)
                    if not isUpInside or mouseButton ~= MOUSE_BUTTON_INDEX_LEFT then return end
                    local currentState = ZOsControls.enableAllAddonsCheckboxCtrl:GetState()
                    local isBoxChecked = true
                    if currentState == BSTATE_PRESSED then
                        isBoxChecked = false
                    end
                    disableAllAddonsToggleFunc(ZOsControls.enableAllAddonsCheckboxCtrl, isBoxChecked)
                end)

                flags.enableAllAddonsCheckboxHooked = true
            end

            --Add narration to all controls
            enableZO_AddOnsUI_controlNarration()

        end, 500) -- Attention: Delay needs to be 500 as AddonSelector_HookForMultiSelectByShiftKey was enabled!!!
    end)

    --20261003 PostHook the Addonmanagers' OnCharacterChanged function (selection of the dropdown entry of any character -> At the addon manager)
    -- to fix the Update 51 introduced character name with apostrophe bug --> ESO vanilla code adds an escape \ in front of the apostrophe.
    --> Remove the backslashes here and update the entry
    SecurePostHook(ZO_AddOnManager, "OnCharacterChanged", function(selfVar, name, entry)
        if entry == nil or entry.allCharacters == true or entry.name == nil then return end
        entry.name = string_gsub(entry.name, "\\", "") --remove any leading backslash from the character name & update the name to the currently selected entry again
        selfVar.selectedCharacterEntry = entry
        selfVar:RefreshData()
    end)

    --PreHook the Addonmanagers OnEffectivelyHidden function
    if ADDON_MANAGER_OBJECT.control:GetHandler("OnHide") == nil then
        ADDON_MANAGER_OBJECT.control:SetHandler("OnHide", function(ctrl)
            AddNewChatNarrationText("[" ..GetString(SI_WINDOW_TITLE_ADDON_MANAGER) .. "] " .. AddonSelector_GetLocalizedText("closedStr"), true)
        end)
    else
        ZO_PostHookHandler(ADDON_MANAGER_OBJECT.control, "OnHide", function(ctrl)
            AddNewChatNarrationText("[" ..GetString(SI_WINDOW_TITLE_ADDON_MANAGER) .. "] " .. AddonSelector_GetLocalizedText("closedStr"), true)
        end)
    end

    --[[ Old until 2025-10-19 -> LibCustomMenu - Now using: LibScrollableMenu and it's narration features
   --Narrate ZO_Menu.items + submenus of LibCustomMenu
    --Trying via LibCustomMenu.submenu:SetSelectedIndex(control.index) hook as this will be called OnMouseEnter
    local function getNarratableZO_MenuItemText(itemCtrl, isSubMenuEntry)
        isSubMenuEntry = isSubMenuEntry or false
        local textToNarrate
        local isCheckbox = false
        local isSubmenu = false

        local prefixStr = getOwnerPrefixStr(GetMenuOwner())

        --d("[AddonSelector]ZO_Menu_EnterItem - itemCtrl: " .. tos(itemCtrl))
        local currentMenuItemText = (isSubMenuEntry == false and ZO_Menu_GetSelectedText()) or (itemCtrl.nameLabel ~= nil and itemCtrl.nameLabel:GetText())
        if currentMenuItemText ~= nil then
            --Find out if a submenu exists or if the entry in the ZO_Menu is a checkbox or normal text
            --It got a submenu? Check that first as the .checkbox will be "reused" for a submenu! But the control name won't be "Arror" at the suffix then
            if GetControl(itemCtrl, "Arrow") ~= nil then
                textToNarrate = "[" .. AddonSelector_GetLocalizedText("submenu") .. "]   " .. strfor(prefixStr, currentMenuItemText)
                isSubmenu = true
                --Checkbox?
            else
                --Checkbox is not a control of the item at the CustomMenu (only at submenus...)
                --How to determine the checkbox? Via the name of the label: " |u16:0::|uTooltip zu Pack in Auswahlbox hinzufügen"
                if (itemCtrl.checkbox ~= nil and itemCtrl.checkbox.GetState ~= nil and itemCtrl.checkbox:IsHidden() == false) or zo_plainstrfind(currentMenuItemText, "|u") == true then
                    isCheckbox = true
                else
                    --Normal
                    textToNarrate = strfor(prefixStr, currentMenuItemText)
                end
            end
            if isCheckbox == true and isSubmenu == false then
                --Get the checkbox via .checkBox or via the anchorTo
                local checkBoxCtrl, currentCbState
                if itemCtrl.checkbox ~= nil then
                    checkBoxCtrl = itemCtrl.checkbox
                else
                    checkBoxCtrl = select(3, itemCtrl:GetAnchor()) --Get the relativeTo anchor control
                end
                if checkBoxCtrl ~= nil and checkBoxCtrl.GetState ~= nil then
                    currentCbState = ZO_CheckButton_IsChecked(checkBoxCtrl)
                end
                textToNarrate = "[" .. AddonSelector_GetLocalizedText("checkBox") .."]   " .. strfor(prefixStr, currentMenuItemText .. " ["..AddonSelector_GetLocalizedText("currently").."]: " ..tos(booleanToOnOff[currentCbState]))
            end
        end
        return textToNarrate, isCheckbox, isSubmenu
    end

    --Normal entries -> Settings menu
    SecurePostHook("ZO_Menu_EnterItem", function(itemCtrl)
        if checkIfMenuOwnerIsZOAddOns() == false or IsAccessibilityUIReaderEnabled() == false then return end
        --d("[AddonSelector]ZO_Menu_EnterItem")
        local textToNarrate = getNarratableZO_MenuItemText(itemCtrl, false)
        OnUpdateDoNarrate("OnAddonSelectorSettingsZOMenuItemEnter", 25, function() AddNewChatNarrationText(textToNarrate, true)  end)
    end)
    --Submenu entries -> Settings menu
    SecurePostHook(AS.LCM.submenu, "SetSelectedIndex", function(submenuTab, index)
        if submenuTab == nil or index == nil or checkIfMenuOwnerIsZOAddOns() == false or IsAccessibilityUIReaderEnabled() == false then return end
        --d("[AddonSelector]LCM.submenu.SetSelectedIndex - index: " .. tos(index))
        local textToNarrate = getNarratableZO_MenuItemText(submenuTab.items[index], true)
        OnUpdateDoNarrate("OnAddonSelectorSettingsZOMenuItemEnter", 25, function() AddNewChatNarrationText(textToNarrate, true)  end)
    end)
    --Narrate a checkbox againa fter it was clicked
    SecurePostHook("ZO_Menu_ClickItem", function(itemCtrl, button)
        if checkIfMenuOwnerIsZOAddOns() == false or IsAccessibilityUIReaderEnabled() == false then return end
        --d("[AddonSelector]ZO_Menu_ClickItem")
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        local textToNarrate, isCheckbox = getNarratableZO_MenuItemText(itemCtrl, false)
        if textToNarrate ~= nil and isCheckbox == true then
            OnUpdateDoNarrate("OnAddonSelectorSettingsZOMenuItemEnter", 25, function() AddNewChatNarrationText(textToNarrate, true)  end)
        end
    end)
    ]]


    --====================================--
    --====  Logout / Quit ====--
    --====================================--
    --Prehook the logout and quit functions to check if any addon pack should be loaded now
    if not wasLogoutPrehooked then
        ZO_PreHook("Logout",    myLogoutCallback)
        ZO_PreHook("Quit",      myLogoutCallback)
        wasLogoutPrehooked = true
    end
end




-------------------------------------------------------------------
--  AddOnSelector - OnAddOnLoaded  --
-------------------------------------------------------------------

--====================================--
--====  Other addons ====--
--====================================--

function AS.OtherAddonsChecks()
    --Addon "AddonCategory" is enabled?
    otherAddonsFlags.isAddonCategoryEnabled = isAddonCategoryAddOnEnabled()
    if otherAddonsFlags.isAddonCategoryEnabled == true then
        getAddonCategoryCategories()
    end
end


--====================================--
--====  Initialize ====--
--====================================--
local function AS_Initialize()
    --Libraries
    AS.LSM     = LibScrollableMenu -- The update of the LibScrollableMenu entries in the dropdown happens in file controls.lua, function AS.UpdateDDL


    --Get the addon manager and object
    ADDON_MANAGER =           utility.GetAddonManager()
    ADDON_MANAGER_OBJECT =    utility.GetAddonManagerObject()

    --Fill the characters of the account tables -> Should have been prefilled at Utility.lua already
    if AS.charactersOfAccount == nil or AS.characterIdsOfAccount == nil or AS.charactersOfAccountLower == nil or AS.characterIdsOfAccountLower == nil then
        AS.charactersOfAccount, AS.charactersOfAccountLower     = getCharactersOfAccount(false)
        AS.characterIdsOfAccount, AS.characterIdsOfAccountLower = getCharactersOfAccount(true)
    end

    --Load the SavedVariables and do "after SV loaded checks"
    AS.LoadSaveVariables()

    --Load the keybinds
    AS.LoadKeybinds()

    --Check for other addons
    AS.OtherAddonsChecks()

    --Create the controls, and update them
    AS.CreateControlReferences()
    updateDDL() --Add the entries to the packs dropdown list / combobox -> Uses LibScrollableMenu now
    AS.ChangeLayout() --Change the layout of the Addon's list and controls so that AddonSelector got space to be inserted

    --Load all the needed hooks now
    AS.LoadHooks()


    --Get the currently loaded packname of the char, if it was changed before reloadUI
    if AS.acwsv.packChangedBeforeReloadUI == true then
        local currentPackOfchar = AS.GetCurrentCharacterSelectedPackname()
        if currentPackOfchar ~= nil then
            --Set the last loaded pack data
            AS.acwsv.lastLoadedPackNameForCharacters[currentCharId] = currentPackOfchar
        end
    end
    AS.acwsv.packChangedBeforeReloadUI = false
end


function AS.OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
	EM:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    ADDON_MANAGER =         utility.GetAddonManager()
    ADDON_MANAGER_OBJECT =  utility.GetAddonManagerObject()

    --The update of the LibScrollableMenu entries in the dropdown happens in file controls.lua, function AS.UpdateDDL

    --Save the currently logged in @account's characterId = characterName table
    AS.charactersOfAccount, AS.charactersOfAccountLower     = getCharactersOfAccount(false)
    AS.characterIdsOfAccount, AS.characterIdsOfAccountLower = getCharactersOfAccount(true)

---------------------------------------------------------------------
    --Load SavedVariables, create and update controls etc.
    AS_Initialize()
---------------------------------------------------------------------

    --Load the SlashCommands
    AS.RegisterSlashCommands()

    --Load the global packs now?
    checkIfGlobalPacksShouldBeShown()
end
