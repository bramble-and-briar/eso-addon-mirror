local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")

local strformat = string.format
local strsub = string.sub
local strfind = string.find
local strlen = string.len

local tos = tostring
local ton = tonumber
local tins = table.insert
local trem = table.remove

local EM = EVENT_MANAGER

local types = tbug.types
local stringType = types.string
local numberType = types.number
local functionType = types.func
local tableType = types.table
local userDataType = types.userdata
local booleanType = types.boolean
local structType = types.struct
local table = table
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort

local searchURLs              = tbug.searchURLs
local tbug_GetDefaultTemplate = tbug.GetDefaultTemplate
local tbug_GetTemplate        = tbug.GetTemplate
--local tbug_getControlName     = tbug.getControlName
local tbug_glookup
local tbugScriptViewerValueForNewWindow = tbug.ScriptsViewer._name

--LibScrollableMenu
local lsm = LibScrollableMenu
local useLibScrollableMenu = lsm ~= nil

--local headerEntryColor = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_GAMEPAD_CATEGORY_HEADER))
local noCallbackFunc = function() end

local constantsSplitSepparator = "_"
local noSoundValue             = SOUNDS["NONE"]

local getGlobalInspectorPanelTabName = tbug.getGlobalInspectorPanelTabName
local isSplittableString = tbug.isSplittableString
local findUpperCaseCharsAndReturnOffsetsTab = tbug.findUpperCaseCharsAndReturnOffsetsTab
local tbug_slashCommand = tbug.slashCommand
local tbug_slashCommandWrapper = tbug.slashCommandWrapper
local tbug_slashCommandSCENEMANAGER = tbug.slashCommandSCENEMANAGER
--local tbug_inspectorSelectTabByName = tbug.inspectorSelectTabByName

local globalInspectorDialogTabKey = getGlobalInspectorPanelTabName("dialogs")
local globalInspectorFunctionsTabKey = getGlobalInspectorPanelTabName("functions")

local isObjectOrClassOrLibrary = tbug.isObjectOrClassOrLibrary

local customKeysForInspectorRows = tbug.customKeysForInspectorRows
--local customKey__Object = customKeysForInspectorRows.object
local lookupTabObject = tbug.LookupTabs["object"]


--local throttledCall = tbug.throttledCall
local valueEdit_CancelThrottled = tbug.valueEdit_CancelThrottled

local DEFAULT_SCALE_PERCENT = 180
local function GetKeyOrTexture(keyCode, textureOptions, scalePercent, useDisabledIcon)
    if textureOptions == KEYBIND_TEXTURE_OPTIONS_EMBED_MARKUP then
        if ZO_Keybindings_ShouldUseIconKeyMarkup(keyCode) then
            return ZO_Keybindings_GenerateIconKeyMarkup(keyCode, scalePercent or DEFAULT_SCALE_PERCENT, useDisabledIcon)
        end
        return ZO_Keybindings_GenerateTextKeyMarkup(GetKeyName(keyCode))
    else
        return GetKeyName(keyCode)
    end
end
local keyShiftStr = GetKeyOrTexture(KEY_SHIFT, KEYBIND_TEXTURE_OPTIONS_EMBED_MARKUP, 100, false)
local keyShiftAndLMBRMB = keyShiftStr .. "+|t100.000000%:100.000000%:/esoui/art/miscellaneous/icon_lmbrmb.dds|t"

local getterOrSetterStr = "%s()"
local getterOrSetterWithControlStr = "%s:%s()"

local searchActionsStr = "Search actions"
local externalUrlGitHubSearchString = "Search %q on \'GitHub\' (ESOUI)"

local checkForSpecialDataEntryAsKey = tbug.checkForSpecialDataEntryAsKey

local DEFAULT_TEXT_COLOR = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
local DEFAULT_TEXT_HIGHLIGHT = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_CONTEXT_HIGHLIGHT))
local DISABLED_TEXT_COLOR = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_DISABLED))

local eventsInspector
local tbug_checkIfInspectorPanelIsShown = tbug.checkIfInspectorPanelIsShown
local tbug_refreshInspectorPanel = tbug.refreshInspectorPanel
local refreshVisibleInspectors = tbug.RefreshVisibleInspectors
local clickToIncludeAgainStr = " (Click to include)"

local tbug_endsWith = tbug.endsWith
--local customKeysForInspectorRows = tbug.customKeysForInspectorRows
--local customKey__Object = customKeysForInspectorRows.object

local RT = tbug.RT
local rtSpecialReturnValues = tbug.RTSpecialReturnValues
local localizationStringKeyText = rtSpecialReturnValues[RT.LOCAL_STRING].replaceName
local globalInspector

local hideContextMenus = tbug.HideContextMenus

local setDrawLevel = tbug.SetDrawLevel
local cleanTitle = tbug.CleanTitle
local getRelevantNameForCall = tbug.getRelevantNameForCall

local defaultScrollableContextMenuOptions = tbug.defaultScrollableContextMenuOptions
local updateTbugGlobalMouseUpHandler = tbug.updateTbugGlobalMouseUpHandler

local tbug_SetAutomaticEventsTrackingFlag


--======================================================================================================================
--= CONTEXT MENU FUNCTIONS                                                                                     -v-
--======================================================================================================================

local function addTextToChat(textToAdd, getName)
    if getName == true then
        textToAdd = getRelevantNameForCall(textToAdd)
    end
    if textToAdd == nil or textToAdd == "" then return end
    StartChatInput(textToAdd, CHAT_CHANNEL_SAY, nil)
end


local function setTemplateFont(template)
    --d("[tbug]setTemplateFont - template: " .. tos(template) .. "; template.font: " .. tos(template.font))

    template = template or tbug_GetDefaultTemplate()
    tbug.savedVars.customTemplate = {
        font = template.font,
        height = template.height,
    }
end

------------------------------------------------------------------------------------------------------------------------
--CONTEXT MENU -> INSPECTOR ROW edit FIELD VALUE
--Custom context menu "OnClick" handling function for inspector row context menu entries
function tbug.setEditValueFromContextMenu(p_self, p_row, p_data, p_oldValue)
--df("tbug:setEditValueFromContextMenu - newValue: " ..tos(p_data.value) .. ", oldValue: " ..tos(p_oldValue))
    if p_self then
        local editBox = p_self.editBox
        if editBox then
            local currentVal = p_data.value
            if p_row and p_data and p_oldValue ~= nil and p_oldValue ~= currentVal then
                p_self.editData = p_data
                local newVal
                if currentVal == nil then
                    newVal = "nil"
                else
                    newVal = tos(currentVal)
                end
                editBox:SetText(newVal)
                p_row.cVal:SetText(newVal)
            end
            if editBox.panel and editBox.panel.valueEditConfirm then
                editBox.panel:valueEditConfirm(editBox)
            end
        end
    end
    hideContextMenus()
end
local setEditValueFromContextMenu = tbug.setEditValueFromContextMenu


------------------------------------------------------------------------------------------------------------------------
--CONTEXT MENU -> CHAT EDIT BOX
--Set the chat's edit box text from a context menu entry
function tbug.setChatEditTextFromContextMenu(p_self, p_row, p_data, copyRawData, copySpecialFuncStr, isKey, isItemLinkSpecialFunc, isRightKey)
--d("[tbug]setChatEditTextFromContextMenu - copySpecialFuncStr: " ..tos(copySpecialFuncStr) .. ", isItemLinkSpecialFunc: " ..tos(isItemLinkSpecialFunc))
    copyRawData = copyRawData or false
    isItemLinkSpecialFunc = isItemLinkSpecialFunc or false
    isKey = isKey or false
    if p_self and p_row and p_data then
        local controlOfInspectorRow = p_self.subject
        local key = p_data.key
        local value = p_data.value
        local prop = p_data.prop
        local dataPropOrKey = (prop ~= nil and prop.name) or key
        local getterName = (prop ~= nil and (prop.getOrig or prop.get))
        local setterName = (prop ~= nil and (prop.setOrig or prop.set))
        local dataEntry = p_data.dataEntry or p_data
        local dataTypeId = dataEntry and dataEntry.typeId

        --For special function strings
        local bagId, slotIndex
        local isBagOrSlotIndex = false
        local itemLink

        --For the editBox text
        local chatMessageText

--d(">got all, self, row, data - dataPropOrKey: " ..tos(dataPropOrKey) .. ", getterName: " ..tos(getterName) ..", setterName: " ..tos(setterName) .. ", dataTypeId: " ..tos(dataTypeId))

--[[
tbug._debug = tbug._debug or {}
tbug._debug.setChatEditTextFromContextMenu = {
    p_self = p_self,
    p_row = p_row,
    p_data = p_data,
    copyRawData = copyRawData,
    copySpecialFuncStr = copySpecialFuncStr,
    isKey = isKey,
    isItemLinkSpecialFunc = isItemLinkSpecialFunc,
    key = key,
    value = value,
    prop = prop,
    dataPropOrKey = dataPropOrKey,
    getterName = getterName,
    getterName = getterName,
    setterName = setterName,
    dataEntry = dataEntry,
    dataTypeId = dataTypeId,
}
]]


        --Copy only raw data?
        if copyRawData == true then
            local valueToCopy = value
--d(">>copyRawData-valueToCopy: " ..tos(valueToCopy))
            --Copy raw value?
            if not isKey then
                local valueType = type(value)
                if valueType == userDataType then
                    --d(">>>value = userdata")
                    --Get name of the userDataType from global table _G
                    local objectName = tbug.glookup(value)
                    if objectName ~= nil and objectName ~= "" and objectName ~= value then
                        valueToCopy = objectName
                    end
                else
                    if dataTypeId == RT.SAVEDINSPECTORS_TABLE then
                        valueToCopy = p_data.tooltipLine
                    end
                end
            end
            chatMessageText = (isKey == true and tos(checkForSpecialDataEntryAsKey(p_data, isRightKey))) or tos(valueToCopy)
--d(">chatMessageText: " .. tos(chatMessageText))
        else
            --Check the row's key value (prop.name)
            if dataPropOrKey ~= nil then
--d(">dataOrPropKey found")
                --Do not use the masterlist as it is not sorted for the non-control insepctor (e.g. table inspector)
                if dataPropOrKey == "bagId" then
                    isBagOrSlotIndex = true
                    bagId = value
                    --Get the slotIndex of the control
                    slotIndex = tbug.getPropOfControlAtIndex(p_self.list.data, p_row.index+1, "slotIndex", true)
                elseif dataPropOrKey == "slotIndex" then
                    isBagOrSlotIndex = true
                    slotIndex = value
                    --Get the bagId of the control
                    bagId = tbug.getPropOfControlAtIndex(p_self.list.data, p_row.index-1, "bagId", true)
                elseif dataPropOrKey == "itemLink" then
                    itemLink = value
                elseif dataPropOrKey == "itemLink plain text" then
                    itemLink = value:gsub("%s+", "") --remove spaces in the possible plain text itemLink
                end
            end
--[[
tbug._debug.setChatEditTextFromContextMenu.isBagOrSlotIndex = isBagOrSlotIndex
tbug._debug.setChatEditTextFromContextMenu.bagId = bagId
tbug._debug.setChatEditTextFromContextMenu.slotIndex = slotIndex
tbug._debug.setChatEditTextFromContextMenu.itemLink = itemLink
]]

--d(">isBagOrSlotIndex: " ..tostring(isBagOrSlotIndex) .. "; isItemLinkSpecialFunc: " ..tos(isItemLinkSpecialFunc))
            --Copy special strings
            if copySpecialFuncStr ~= nil and copySpecialFuncStr ~= "" then
--d(">>copySpecialFuncStr: " ..tos(copySpecialFuncStr))
                if isItemLinkSpecialFunc == true then
                    if isBagOrSlotIndex == true or itemLink ~= nil then
                        if (bagId and slotIndex) or itemLink then
                            itemLink = itemLink or (bagId and slotIndex and GetItemLink(bagId, slotIndex))
                            chatMessageText = "/tb " .. tos(copySpecialFuncStr) .. "('"..itemLink.."')"
                        end
                    end
                else
                    if copySpecialFuncStr == "itemlink" then
                        if isBagOrSlotIndex == true then
                            if bagId and slotIndex then
                                --local itemLink = GetItemLink(bagId, slotIndex)
                                chatMessageText = "/tb GetItemLink("..tos(bagId)..", "..tos(slotIndex)..")"
                            end
                        end
                    elseif copySpecialFuncStr == "itemname" then
                        if isBagOrSlotIndex == true then
                            if bagId and slotIndex then
                                local itemName = GetItemName(bagId, slotIndex)
                                if itemName and itemName ~= "" then
                                    itemName = ZO_CachedStrFormat("<<C:1>>", itemName)
                                end
                                chatMessageText = tos(itemName)
                            end
                        end
                    elseif copySpecialFuncStr == "special" then
                        if isBagOrSlotIndex == true then
                            if bagId and slotIndex then
                                chatMessageText = tos(bagId)..","..tos(slotIndex)
                            end
                        elseif itemLink ~= nil then
                            chatMessageText = "/tb GetItemLinkXXX('"..itemLink.."')"
                        end
                    elseif copySpecialFuncStr == "getterName" then
                        if getterName then chatMessageText = strformat(getterOrSetterStr, tos(getterName)) end
                    elseif copySpecialFuncStr == "setterName" then
                        if setterName then chatMessageText = strformat(getterOrSetterStr, tos(setterName)) end
                    elseif copySpecialFuncStr == "control:getter" then
                        if getterName then
                            local ctrlName = (controlOfInspectorRow.GetName and controlOfInspectorRow:GetName()) or "???"
                            chatMessageText = strformat(getterOrSetterWithControlStr, ctrlName, tos(getterName))
                        end
                    elseif copySpecialFuncStr == "control:setter" then
                        if setterName then
                            local ctrlName = (controlOfInspectorRow.GetName and controlOfInspectorRow:GetName()) or "???"
                            chatMessageText = strformat(getterOrSetterWithControlStr, ctrlName, tos(setterName))
                        end
                    end
                end
            end

        end
        if chatMessageText and chatMessageText ~= "" then
            --CHAT_SYSTEM:StartTextEntry(chatMessageText, CHAT_CHANNEL_SAY, nil, false)
            StartChatInput(chatMessageText, CHAT_CHANNEL_SAY, nil)
        end

        --Right click should stop the value edit at the inspector row?
        local editBox = p_self.editBox
        if editBox then
--d(">editBox.panel.valueEditCancel: " ..tos(editBox.panel.valueEditCancel))
            valueEdit_CancelThrottled(editBox, 0)
        end
        hideContextMenus()
    end
end
local setChatEditTextFromContextMenu = tbug.setChatEditTextFromContextMenu

function tbug.setSearchBoxTextFromContextMenu(p_self, p_row, p_data, searchString)
    if p_self and p_row and p_data and searchString and searchString ~= "" then
        --todo get the search box of the active tab and set the search text now
--d("[tbug]setSearchBoxTextFromContextMenu-searchString: " ..tos(searchString))
        local inspector = p_self.inspector
        if inspector ~= nil then
            local filterEdit = tbug.getFilterEdit(inspector)
            if filterEdit ~= nil then
                local currentFilterMode = tbug.getFilterMode(inspector)
                --Change the filterMode to string (str)
                if currentFilterMode ~= 1 then
                    local filterModeButton = tbug.getFilterModeButton(inspector)
                    inspector.updateFilterModeButton(1, filterModeButton)
                end
                filterEdit:SetText(searchString)
            end
        end
    end
end
local setSearchBoxTextFromContextMenu = tbug.setSearchBoxTextFromContextMenu

function tbug.searchExternalURL(p_self, p_row, p_data, searchString, searchURLType)
    if searchString == nil or searchString == "" or searchURLType == nil or searchURLType == "" then return end
    local searchURLPattern = searchURLs[searchURLType]
    if searchURLPattern == nil then return end
    local searchUrl = strformat(searchURLPattern, searchString)
    RequestOpenUnsafeURL(searchUrl)
end
local searchExternalURL = tbug.searchExternalURL



--Show the "Scripts" tab and put the key/value, and if it's a function an opening and closing () behind it, to the "test script" editbox
local function useForScript(p_self, p_row, p_data, isKey, isFunctionsDataType, isClassOrObjectOrLibrary, showInNewTab, scriptStrIsValue, noDirectExecute)
    if not p_self or not p_row or not p_data or isKey == nil then return end
    isFunctionsDataType = isFunctionsDataType or false
    isClassOrObjectOrLibrary = isClassOrObjectOrLibrary or false
    noDirectExecute = noDirectExecute or false
    if not showInNewTab then
        showInNewTab = IsShiftKeyDown()
    end
    tbug_glookup = tbug_glookup or tbug.glookup

    local key, value = p_data.key, p_data.value
    local scriptStr = ""

    if scriptStrIsValue then
       scriptStr =  tos(value)
       if scriptStr == "" then return end
       if tbug.doDebug then d("[TBUG]useForScript - scriptStrIsValue! scriptStr: " .. tos(scriptStr) .. "; isKey: " .. tos(isKey) .. "; valueType: " .. tos(type(value)) ..", showInNewTab: " ..tos(showInNewTab)) end
    else
        --Key is a number only? No need to run a script on it, try it on the value then!
        if ton(key) == numberType then
            isKey = false
        end

        if isKey then
            --Key
            scriptStr = tos(key)
        else
            --Value
            scriptStr = tos(value)
        end

        if tbug.doDebug then d("[TBUG]useForScript - scriptStr: " .. tos(scriptStr) .. "; isKey: " .. tos(isKey) .. "; valueType: " .. tos(type(value)) ..", showInNewTab: " ..tos(showInNewTab)) end
        if scriptStr == "" then return end

        if not isFunctionsDataType and value ~= nil and type(value) == functionType then
            isFunctionsDataType = true
        end

        if isClassOrObjectOrLibrary == true then
            local lookupName
            local subject = (p_self._parentSubject ~= nil and p_self._parentSubject) or nil
            if subject == nil then
                subject = p_self.subject
                lookupName = ((p_self.subjectName ~= nil and p_self.subjectName) or (subject ~= nil and tbug_glookup(subject))) or nil
            else
                lookupName = tbug_glookup(subject)
            end
            --d(">lookupName1: " ..tos(lookupName))

            if lookupName ~= nil and lookupName ~= "_G" then
                scriptStr = tos(lookupName) .. (isFunctionsDataType and ":" or ".") .. scriptStr
            end
        else
            if isKey and type(value) == tableType then
                local lookupName = tbug_glookup(value)
                --d(">lookupName2: " ..tos(lookupName))
                if lookupName ~= nil and lookupName ~= "_G" and _G[lookupName] ~= nil and _G[lookupName][key] ~= nil then
                    scriptStr = lookupName .. "." .. scriptStr
                end
            end
        end

        if isFunctionsDataType then
            scriptStr = scriptStr .. "()"
        end
    end
    --d("[tbug]useForScript - scriptStr: " .. tos(scriptStr) .. ", isFunction: " .. tos(isFunctionsDataType))

    --Show the global inspector scripts tab, or open a new inspector with scripts viewer window
    if showInNewTab == true then
        local tabTitle = (scriptStrIsValue and scriptStr) or nil
        if noDirectExecute then
            if p_data.scriptStr == nil then p_data.scriptStr = scriptStr end
            if p_data.value == tbugScriptViewerValueForNewWindow then
                --Increase the ScriptsViewer shown counter
                tbug.ScriptsViewer.numScriptViewersShown = tbug.ScriptsViewer.numScriptViewersShown + 1
                tabTitle = "ScriptsViewer#" .. tos(tbug.ScriptsViewer.numScriptViewersShown)
            end
        end

        tbug_slashCommandWrapper(scriptStr, nil, true, {
            specialMasterlistType = "ScriptsViewer",
            title = tabTitle,
            noDirectExecute = noDirectExecute,
            scriptStr = (noDirectExecute == true and p_data.scriptStr) or nil, --We try to open a new ScriptsInspector windw from slash command/keybind -> Pass through the scriptStr for the editbox
        })
    else
        globalInspector = globalInspector or tbug.getGlobalInspector()
        local panels = globalInspector ~= nil and globalInspector.panels
        if panels == nil then return end
        if panels.scriptHistory == nil then return end
        --d(">found scriptHistory panel")

        tbug_slashCommandWrapper("scripts", nil, false, nil)
        --d(">>tab selected - set script to editbox now")
        --Set the script text
        local testScriptEditBox = panels.scriptHistory:testScript(p_row, p_data, isKey, scriptStr, false)
        testScriptEditBox:TakeFocus()
        if isFunctionsDataType then
            testScriptEditBox:SetCursorPosition(strlen(scriptStr) - 1)
        end

        --Bring the scripts tab to the front
        globalInspector.control:SetHidden(false)
        globalInspector.control:BringWindowToTop()
    end
end
tbug.useForScript = useForScript

------------------------------------------------------------------------------------------------------------------------
--CONTROL OUTLINE
local blinksDonePerControl = {}
local function hideOutlineNow(p_controlToOutline, removeAllOutlines)
    removeAllOutlines = removeAllOutlines or false
    if removeAllOutlines == true then
        ControlOutline_ReleaseAllOutlines()
    else
        if ControlOutline_IsControlOutlined(p_controlToOutline) then ControlOutline_ReleaseOutlines(p_controlToOutline) end
    end
end

function tbug.hideOutline(p_self, p_row, p_data, removeAllOutlines)
    local controlToRemoveOutlines = p_self.subject
    if controlToRemoveOutlines ~= nil or removeAllOutlines == true then
        hideOutlineNow(controlToRemoveOutlines, removeAllOutlines)
    end
end
local hideOutline = tbug.hideOutline

local function blinkOutlineNow(p_controlToOutline, p_uniqueBlinkName, p_blinkCountTotal)
    --Hide the outline control at first call, if it is currently shown
    if blinksDonePerControl[p_controlToOutline] == 0 then
        hideOutlineNow(p_controlToOutline)
    end
    --Show/Hide the outline now (toggles on each call to this update function of the RegisterForUpdate event)
    --but only if the control is currently shown (else we cannot see the outline)
    if not p_controlToOutline:IsHidden() then
        ControlOutline_ToggleOutline(p_controlToOutline)
    end

    --Increase blinks done
    blinksDonePerControl[p_controlToOutline] = blinksDonePerControl[p_controlToOutline] + 1

    --End blinking and unregister updater
    if blinksDonePerControl[p_controlToOutline] >= p_blinkCountTotal then
        EM:UnregisterForUpdate(p_uniqueBlinkName)
        blinksDonePerControl[p_controlToOutline] = nil
        hideOutlineNow(p_controlToOutline)
    end
end

local function outlineWithChildControlsNow(control, withChildren)
    withChildren = withChildren or false
    if control == nil then return end
    if withChildren == true then
        hideOutlineNow(control)
        ControlOutline_OutlineParentChildControls(control)
    else
        if ControlOutline_IsControlOutlined(control) then return end
        ControlOutline_ToggleOutline(control)
    end
end
function tbug.outlineControl(p_self, p_row, p_data, withChildren)
    local controlToOutline = p_self.subject
    outlineWithChildControlsNow(controlToOutline, withChildren)
end
local outlineControl = tbug.outlineControl


function tbug.blinkControlOutline(p_self, p_row, p_data, blinkCount)
--d("[TBUG]Blink control outline - blinkCount: " ..tos(blinkCount))
--Debugging
--tbug._blinkControlOutline = {}
--tbug._blinkControlOutline.self = p_self
--tbug._blinkControlOutline.data =p_data
--tbug._blinkControlOutline.row = p_row
    local controlToOutline = p_self.subject
    if controlToOutline ~= nil then
        local controlToOutlineName = controlToOutline.GetName and controlToOutline:GetName()
        if not controlToOutlineName then return end
        local uniqueBlinkName = "TBUG_BlinkOutline_" .. controlToOutlineName
        EM:UnregisterForUpdate(uniqueBlinkName)
        blinksDonePerControl[controlToOutline] = 0
        EM:RegisterForUpdate(uniqueBlinkName, 550, function()
            local blinkCountTotal = blinkCount * 2 --duplicate the blink count to respect each "on AND off" as 1 blink
            blinkOutlineNow(controlToOutline, uniqueBlinkName, blinkCountTotal)
        end)
    end
end
local blinkControlOutline = tbug.blinkControlOutline


------------------------------------------------------------------------------------------------------------------------
--SCRIPT HISTORY
local function refreshScriptHistoryIfShown()
    if tbug_checkIfInspectorPanelIsShown("globalInspector", "scriptHistory") then
        tbug_refreshInspectorPanel("globalInspector", "scriptHistory")
        --TODO: Why does a single data refresh not work directly where a manual click on the update button does work?! Even a delayed update does not work properly...
        tbug_refreshInspectorPanel("globalInspector", "scriptHistory")
    end
end


--Remove a script from the script history by help of the context menu
function tbug.removeScriptHistory(panel, scriptRowId, refreshScriptsTableInspector, clearScriptHistory)
    if not panel or not scriptRowId then return end
    refreshScriptsTableInspector = refreshScriptsTableInspector or false
    clearScriptHistory = clearScriptHistory or false
    hideContextMenus()
    --Check if script is not already in
    if tbug.savedVars and tbug.savedVars.scriptHistory then
        if not clearScriptHistory then
            --Set the column to update to 1
            local editBox = {}
            editBox.updatedColumnIndex = 1
            tbug.changeScriptHistory(scriptRowId, editBox, "", refreshScriptsTableInspector)
            if refreshScriptsTableInspector == true then
                refreshScriptHistoryIfShown()
            end
        else
            --Show security dialog asking if this is correct
            local callbackYes = function()
                --Clear the total script history?
                tbug.savedVars.scriptHistory = {}
                tbug.savedVars.scriptHistoryComments = {}

                refreshScriptHistoryIfShown()
            end
            tbug.ShowConfirmBeforeDialog(nil, "Delete total script history?", callbackYes)
        end
    end
end
local removeScriptHistory = tbug.removeScriptHistory

function tbug.editScriptHistory(panel, p_row, p_data, changeScript)
    hideContextMenus()
    if not panel or not p_row or not p_data then return end
    if changeScript == nil then changeScript = true end
    --Simulate the edit of value 1 (script lua code)
    local cValRow = (changeScript == true and p_row.cVal) or p_row.cVal2
    local columnIndex = (changeScript == true and 1) or 2
    panel:valueEditStart(panel.editBox, p_row, p_data, cValRow, columnIndex)
end
local editScriptHistory = tbug.editScriptHistory

function tbug.testScriptHistory(panel, p_row, p_data, key)
    hideContextMenus()
    if not panel or not key then return end
    panel:testScript(p_row, p_data, key, nil, true)
end
local testScriptHistory = tbug.testScriptHistory


function tbug.getActiveScriptKeybinds()
    local retTab = {}
    for i=1, tbug.maxScriptKeybinds do
        retTab[i] = tbug.savedVars.scriptKeybinds[i]
    end
    return retTab
end
local getActiveScriptKeybinds = tbug.getActiveScriptKeybinds

function tbug.getScriptKeybind(scriptKeybindNumber)
    if scriptKeybindNumber == nil or scriptKeybindNumber < 1 or scriptKeybindNumber > tbug.maxScriptKeybinds then return end
    return tbug.savedVars.scriptKeybinds[scriptKeybindNumber]
end
local getScriptKeybind = tbug.getScriptKeybind

function tbug.setScriptKeybind(scriptKeybindNumber, key, delete)
    delete = delete or false
    if scriptKeybindNumber == nil or scriptKeybindNumber < 1 or scriptKeybindNumber > tbug.maxScriptKeybinds then return end
    if not delete then if key == nil or key > #tbug.savedVars.scriptHistory then return end end
    tbug.savedVars.scriptKeybinds[scriptKeybindNumber] = key
end
local setScriptKeybind = tbug.setScriptKeybind

function tbug.clearScriptKeybinds()
    local activeScriptKeybinds = getActiveScriptKeybinds()
    for scriptKeybindNumber, key in pairs(activeScriptKeybinds) do
         tbug.savedVars.scriptKeybinds[scriptKeybindNumber] = nil
    end
end
local clearScriptKeybinds = tbug.clearScriptKeybinds

function tbug.runScript(scriptKeybindNumber)
    local activeScriptKeybindKey = getScriptKeybind(scriptKeybindNumber)
    if activeScriptKeybindKey == nil then return end
    local command  = tbug.savedVars.scriptHistory[activeScriptKeybindKey]
    if command == nil then return end

    --Run the script saved at the keybind
    tbug_slashCommand(command)
end

function tbug.cleanScriptHistory()
    local alreadyFoundScripts = {}
    local duplicatesFound = {}
    local totalCount = 0
    local duplicateCount = 0

    local scriptHistory = tbug.savedVars.scriptHistory
    for key, scriptStr in pairs(scriptHistory) do
        totalCount = totalCount + 1
        if alreadyFoundScripts[scriptStr] == nil then
            alreadyFoundScripts[scriptStr] = key
        else
            duplicatesFound[key] = alreadyFoundScripts[scriptStr]
            duplicateCount = duplicateCount + 1
        end
    end

    --Clear duplicatesFound key at scriptHistory
    if not ZO_IsTableEmpty(duplicatesFound) then
        local keybindsReassignedStr = ""
        local activeScriptKeybinds = getActiveScriptKeybinds()
        for duplicateKey, originalKey in pairs(duplicatesFound) do
            --Check if duplicate key was assigned to any keybind, then move the keybind to the new key now
            for scriptKeybindNumber, scriptKey in pairs(activeScriptKeybinds) do
                if scriptKey == duplicateKey then
                    tbug.savedVars.scriptKeybinds[scriptKeybindNumber] = originalKey
                    if keybindsReassignedStr == "" then
                        keybindsReassignedStr = tos(scriptKeybindNumber)
                    else
                        keybindsReassignedStr = keybindsReassignedStr .. "," ..tos(scriptKeybindNumber)
                    end
                end
            end
            trem(scriptHistory, duplicateKey)
        end
        --Update the script history UI now if it's currently shown
        refreshScriptHistoryIfShown()

        d("[TBUG]Cleaned duplicate script history entries.")
        d("> total: " .. tos(totalCount) .." / duplicate: " ..tos(duplicateCount) .. " / keybinds reassigned: " ..tos(keybindsReassignedStr))
    end
end
local cleanScriptHistory = tbug.cleanScriptHistory



------------------------------------------------------------------------------------------------------------------------
--SAVED INSPECTORS
local function refreshSavedInspectorsIfShown()
    if tbug_checkIfInspectorPanelIsShown("globalInspector", "savedInsp") then
        tbug_refreshInspectorPanel("globalInspector", "savedInsp")
        --TODO: Why does a single data refresh not work directly where a manual click on the update button does work?! Even a delayed update does not work properly...
        tbug_refreshInspectorPanel("globalInspector", "savedInsp")
    end
end

--Remove a saved inspector by help of the context menu
function tbug.removeSavedInspectors(panel, savedInspectorsRowId, refreshSavedInspectorsTableInspector, clearSavedInspectors)
    if not panel or not savedInspectorsRowId then return end
    refreshSavedInspectorsTableInspector = refreshSavedInspectorsTableInspector or false
    clearSavedInspectors                 = clearSavedInspectors or false
    hideContextMenus()
    --Check if script is not already in
    if tbug.savedVars and tbug.savedVars.savedInspectors then
        if not clearSavedInspectors then
            --Set the column to update to 1
            local editBox = {}
            editBox.updatedColumnIndex = 1
            tbug.changeSavedInspectors(savedInspectorsRowId, editBox, "", refreshSavedInspectorsTableInspector)
            if refreshSavedInspectorsTableInspector == true then
                refreshSavedInspectorsIfShown()
            end
        else
            --Show security dialog asking if this is correct
            local callbackYes = function()
                --Clear the total script history?
                tbug.savedVars.savedInspectors = {}
                tbug.savedVars.savedInspectorsComments = {}

                refreshSavedInspectorsIfShown()
            end
            tbug.ShowConfirmBeforeDialog(nil, "Delete total saved inspectors?", callbackYes)
        end
    end
end
local removeSavedInspectors = tbug.removeSavedInspectors

function tbug.editSavedInspectors(panel, p_row, p_data, changeScript)
    hideContextMenus()
    if not panel or not p_row or not p_data then return end
    if changeScript == nil then changeScript = true end
    --Simulate the edit of value 1 (script lua code)
    local cValRow = (changeScript == true and p_row.cVal) or p_row.cVal2
    local columnIndex = (changeScript == true and 1) or 2
    panel:valueEditStart(panel.editBox, p_row, p_data, cValRow, columnIndex)
end
local editSavedInspectors = tbug.editSavedInspectors


------------------------------------------------------------------------------------------------------------------------
--EVENTS
local function reRegisterAllEvents()
    eventsInspector = eventsInspector or tbug.Events.getEventsTrackerInspectorControl()
    tbug.Events.ReRegisterAllEvents(eventsInspector)
end

local function registerExcludedEventId(eventId)
    eventsInspector = eventsInspector or tbug.Events.getEventsTrackerInspectorControl()
    tbug.Events.UnRegisterSingleEvent(eventsInspector, eventId)
end

local function addToExcluded(eventId)
    table_insert(tbug.Events.eventsTableExcluded, eventId)
end
local function removeFromExcluded(eventId, removeAll)
    removeAll = removeAll or false
    if removeAll == true then
        tbug.Events.eventsTableExcluded = {}
    else
        for idx, eventIdToFind in ipairs(tbug.Events.eventsTableExcluded) do
            if eventIdToFind == eventId then
                table_remove(tbug.Events.eventsTableExcluded, idx)
                return true
            end
        end
    end
end

local function registerOnlyIncludedEvents()
    local events = tbug.Events
    eventsInspector = eventsInspector or events.getEventsTrackerInspectorControl()
    tbug.Events.UnRegisterAllEvents(eventsInspector, events.eventsTableIncluded)
end

local function addToIncluded(eventId, onlyThisEvent)
    onlyThisEvent = onlyThisEvent or false
    if onlyThisEvent == true then
        tbug.Events.eventsTableIncluded = {}
    end
    table_insert(tbug.Events.eventsTableIncluded, eventId)
end
local function removeFromIncluded(eventId, removeAll)
    removeAll = removeAll or false
    if removeAll == true then
        tbug.Events.eventsTableIncluded = {}
    else
        for idx, eventIdToFind in ipairs(tbug.Events.eventsTableIncluded) do
            if eventIdToFind == eventId then
                table_remove(tbug.Events.eventsTableIncluded, idx)
                return true
            end
        end
    end
end

local function enableBecauseEventsListIsNotEmpty()
    return not ZO_IsTableEmpty(tbug.Events.eventsTableInternal)
end

local function showEventsContextMenu(p_self, p_row, p_data, isEventMainUIToggle)
    --Did we right click the main UI's e/E toggle button?
    isEventMainUIToggle = isEventMainUIToggle or false
    if isEventMainUIToggle == true then
        hideContextMenus()
    end
    if not useLibScrollableMenu then return end

    local sv = tbug.savedVars

    local events    = tbug.Events
    eventsInspector = eventsInspector or events.getEventsTrackerInspectorControl()

    AddCustomScrollableMenuEntry("Event tracking actions", noCallbackFunc, LSM_ENTRY_TYPE_HEADER, nil, nil, nil, nil, nil)

    local startOrStopEventTracking = not events.IsEventTracking and "Start Event tracking" or "Stop Event tracking"
    AddCustomScrollableMenuEntry(startOrStopEventTracking, function()
            if tbug.Events.IsEventTracking == true then
                tbug.StopEventTracking()
            else
                tbug.StartEventTracking()
            end
        end, LSM_ENTRY_TYPE_NORMAL, nil)

    --If the events list is not empty
    if eventsInspector ~= nil and enableBecauseEventsListIsNotEmpty() then
        AddCustomScrollableMenuDivider()
        AddCustomScrollableMenuEntry("Clear events list", function()
                events.eventsTableInternal = {}
                tbug.RefreshTrackedEventsList()
                globalInspector = globalInspector or tbug.getGlobalInspector(true)
                local eventsPanel = globalInspector.panels["events"]
                --eventsPanel:populateMasterList(events.eventsTable, RT.EVENTS_TABLE)
                eventsPanel:refreshData()
                eventsPanel:refreshData() --todo: why do we need to call this twice to clear the list?
            end, LSM_ENTRY_TYPE_NORMAL, nil)
    end

    local currentValue
    if p_data == nil then
        if isEventMainUIToggle == true then
            p_data = {
                key = nil,
                value = {
                    _eventName = "Settings",
                    _eventId   = nil
                }
            }
        else
            return
        end
    end
    currentValue = p_data.value
    local eventName = currentValue._eventName
    local eventId   = currentValue._eventId

    local isEventSettingsMenu = eventName == "Settings"

    --Actual event actions
    local eventTrackingSubMenuTable = {}
    local eventTrackingSubMenuTableEntry = {}
    if not isEventMainUIToggle then
        eventTrackingSubMenuTableEntry = {
            label = strformat("Exclude this event"),
            callback = function()
                addToExcluded(eventId)
                removeFromIncluded(eventId, false)
                registerExcludedEventId(eventId)
            end,
        }
        table_insert(eventTrackingSubMenuTable, eventTrackingSubMenuTableEntry)
        eventTrackingSubMenuTableEntry = {
            label = strformat("Include this event"),
            callback = function()
                addToIncluded(eventId, false)
                removeFromExcluded(eventId, false)
                registerOnlyIncludedEvents()
            end,
        }
        table_insert(eventTrackingSubMenuTable, eventTrackingSubMenuTableEntry)
        eventTrackingSubMenuTableEntry = {
            label = strformat("ONLY show this event"),
            callback = function()
                addToIncluded(eventId, true)
                removeFromExcluded(nil, true)
                registerOnlyIncludedEvents()
            end,
        }
        table_insert(eventTrackingSubMenuTable, eventTrackingSubMenuTableEntry)
        eventTrackingSubMenuTableEntry = {
            label = "-",
            callback = noCallbackFunc,
        }
        table_insert(eventTrackingSubMenuTable, eventTrackingSubMenuTableEntry)
    end
    eventTrackingSubMenuTableEntry = {
        label = "Re-register ALL events (clear excluded/included)",
        callback = function()
            reRegisterAllEvents()
        end,
        enabled = function()
            local anyIncluded = not ZO_IsTableEmpty(tbug.Events.eventsTableIncluded)
            if anyIncluded then return true end
            local anyExcluded = not ZO_IsTableEmpty(tbug.Events.eventsTableExcluded)
            if anyExcluded then return true end
            return false
        end,
    }
    table_insert(eventTrackingSubMenuTable, eventTrackingSubMenuTableEntry)
    AddCustomScrollableSubMenuEntry(strformat("Event: \'%s\'", tos(eventName)), eventTrackingSubMenuTable)

    --Included events
    local includedEvents = events.eventsTableIncluded
    if includedEvents and #includedEvents > 0 then
        local eventTrackingIncludedSubMenuTable = {}
        local eventTrackingIncludedSubMenuTableEntry = {}
        for _, eventIdIncluded in ipairs(includedEvents) do
            local eventNameIncluded = events.eventList[eventIdIncluded]
            eventTrackingIncludedSubMenuTableEntry = {
                label = eventNameIncluded,
                callback = function()
                    --Todo Any option needed?
                end,
            }
            table_insert(eventTrackingIncludedSubMenuTable, eventTrackingIncludedSubMenuTableEntry)
        end
        AddCustomScrollableSubMenuEntry("INcluded events",  eventTrackingIncludedSubMenuTable)
    end

    --Excluded events
    local excludedEvents = events.eventsTableExcluded
    if excludedEvents and #excludedEvents > 0 then
        eventsInspector = eventsInspector or tbug.Events.getEventsTrackerInspectorControl()

        local eventTrackingExcludedSubMenuTable = {}
        local eventTrackingExcludedSubMenuTableEntry = {}
        for _, eventIdExcluded in ipairs(excludedEvents) do
            local eventNameExcluded = events.eventList[eventIdExcluded]
            eventTrackingExcludedSubMenuTableEntry = {
                label = eventNameExcluded .. clickToIncludeAgainStr,
                callback = function()
                    --Remove the excluded event again -> Include it again
                    removeFromExcluded(eventIdExcluded, false)
                    tbug.Events.RegisterSingleEvent(eventsInspector, eventIdExcluded)
                end,
            }
            table_insert(eventTrackingExcludedSubMenuTable, eventTrackingExcludedSubMenuTableEntry)
        end
        AddCustomScrollableSubMenuEntry("EXcluded events", eventTrackingExcludedSubMenuTable)
    end


    if isEventSettingsMenu then
        local dividerEventsSaveLoadAdded = false
        if enableBecauseEventsListIsNotEmpty() then
            AddCustomScrollableMenuDivider()
            dividerEventsSaveLoadAdded = true
            AddCustomScrollableMenuEntry("Save currently tracked events", function() tbug.SaveEventsTracked() end, LSM_ENTRY_TYPE_NORMAL, nil, {
                tooltip = "Save the currently tracked events so that you can load them later again.\n\nThis will only work, if you currently got tracked events in the list!"
            })
        end

        local savedEvents = tbug.savedVars.savedEvents
        if not ZO_IsTableEmpty(savedEvents) then
            local eventTrackingSettingsLoadSavedSubmenu = {}
            for k, v in ipairs(savedEvents) do
                local savedEventsIndex = k
                local savedEventsData = v
                local timeStampStr = (savedEventsData._timeStamp ~= nil and os.date("%c", savedEventsData._timeStamp)) or ""
                local loadDetailsStr = tostring(savedEventsIndex) .. ". " .. timeStampStr .. " (#" .. tos(NonContiguousCount(savedEventsData.events)) ..")"
                local eventTrackingSettingsLoadSubmenuEntry = {
                    label = "Load " .. loadDetailsStr,
                    callback = function()
                        tbug.LoadEventsTracked(savedEventsIndex, loadDetailsStr)
                    end,
                    contextMenuCallback = function(self)
                        ClearMenu()
                        AddMenuItem("Delete saved event \'" .. loadDetailsStr  .. "\'", function()
                            tbug.DeleteEventsTracked(savedEventsIndex)
                        end)
                        lsm.preventLSMClosingZO_Menu = true
                        ShowMenu()
                    end,
                }
                table_insert(eventTrackingSettingsLoadSavedSubmenu, eventTrackingSettingsLoadSubmenuEntry)
            end
            if not dividerEventsSaveLoadAdded then
                AddCustomScrollableMenuDivider()
                dividerEventsSaveLoadAdded = true
            end
            AddCustomScrollableSubMenuEntry("Load tracked events", eventTrackingSettingsLoadSavedSubmenu)
        end

        --Enable event tracking at startup of tbug/reloadui
        local eventTrackingAtStartupSettingsSubmenu = {}
        eventTrackingAtStartupSettingsSubmenu[#eventTrackingAtStartupSettingsSubmenu + 1] = {
            name            = "|cFF0000Disable|r the automatic Event tracking",
            checked         = function() return not sv.enableEventTrackerAtStartup and not tbug.activateAutomaticEventTrackingOnNextLogin and not sv.enableEventTrackerAtNextLogin end,
            callback        = function(comboBox, itemName, item, checked, data)
                tbug_SetAutomaticEventsTrackingFlag = tbug_SetAutomaticEventsTrackingFlag or tbug.SetAutomaticEventsTrackingFlag
                --value, doReloadUI, activateNextLogin, chatOutput, onlyFor1ReloadUI, allOff
                tbug_SetAutomaticEventsTrackingFlag(nil, nil, nil, true, nil, true)
            end,
            --entries         = submenuEntries,
            tooltip         = "Disable the automatic event tracking. The global inspector and the events tab wont show automatically.",
            entryType = lsm.LSM_ENTRY_TYPE_RADIOBUTTON,
            buttonGroup = 1,
            --rightClickCallback = function() d("Test context menu")  end
        }
        eventTrackingAtStartupSettingsSubmenu[#eventTrackingAtStartupSettingsSubmenu + 1] = {
            name            = "Automatically enable 1x (after ReloadUI)",
            checked         = function() return sv.enableEventTrackerAtStartupOnlyOnce == true and sv.enableEventTrackerAtStartup == true and not tbug.activateAutomaticEventTrackingOnNextLogin and not sv.enableEventTrackerAtNextLogin end,
            callback        = function(comboBox, itemName, item, checked, data)
                tbug_SetAutomaticEventsTrackingFlag = tbug_SetAutomaticEventsTrackingFlag or tbug.SetAutomaticEventsTrackingFlag
                tbug_SetAutomaticEventsTrackingFlag(checked, false, nil, true, true)
            end,
            --entries         = submenuEntries,
            tooltip         = "Automatically enable the event tracker ONLY for the NEXT ReloadUI (or login, if you logout/quit before the next ReloadUI was done), as the AddOn merTorchbug loads.\nThis will open the global inspector and activate the events tab automatically.",
            entryType = lsm.LSM_ENTRY_TYPE_RADIOBUTTON,
            buttonGroup = 1,
            --rightClickCallback = function() d("Test context menu")  end
        }
        eventTrackingAtStartupSettingsSubmenu[#eventTrackingAtStartupSettingsSubmenu + 1] = {
            name            = "Automatically enable (all ReloadUIs)",
            checked         = function() return not sv.enableEventTrackerAtStartupOnlyOnce and sv.enableEventTrackerAtStartup == true and not tbug.activateAutomaticEventTrackingOnNextLogin and not sv.enableEventTrackerAtNextLogin end,
            callback        = function(comboBox, itemName, item, checked, data)
                tbug_SetAutomaticEventsTrackingFlag = tbug_SetAutomaticEventsTrackingFlag or tbug.SetAutomaticEventsTrackingFlag
                tbug_SetAutomaticEventsTrackingFlag(checked, false, nil, true)
            end,
            --entries         = submenuEntries,
            tooltip         = "Automatically enable the event tracker after each ReloadUI (or login, if you logout/quit before the next ReloadUI was done), as the AddOn merTorchbug loads.\nThis will open the global inspector and activate the events tab automatically.\n\n|cFF0000Attention|r: This will stay active until you manually turn this option here off again or use the slash command /tbe autoff!",
            entryType = lsm.LSM_ENTRY_TYPE_RADIOBUTTON,
            buttonGroup = 1,
            --rightClickCallback = function() d("Test context menu")  end
        }
        eventTrackingAtStartupSettingsSubmenu[#eventTrackingAtStartupSettingsSubmenu + 1] = {
            name            = "Automatically enable (after next Login)",
            checked         = function() return (tbug.activateAutomaticEventTrackingOnNextLogin == true or sv.enableEventTrackerAtNextLogin == true) and not sv.enableEventTrackerAtStartup end,
            callback        = function( comboBox, itemName, item, checked, data)
                tbug_SetAutomaticEventsTrackingFlag = tbug_SetAutomaticEventsTrackingFlag or tbug.SetAutomaticEventsTrackingFlag
                tbug_SetAutomaticEventsTrackingFlag(nil, false, true, true)
            end,
            --entries         = submenuEntries,
            tooltip         = "Automatically enable the event tracker after your 1 next login (character change, or client restart), as the AddOn merTorchbug loads.\nThis will open the global inspector and activate the events tab automatically.\n\n|cFF0000Attention|r: This will reset if you reload the UI or get into a loading screen before logout/quit!",
            entryType = lsm.LSM_ENTRY_TYPE_RADIOBUTTON,
            buttonGroup = 1,
            --rightClickCallback = function() d("Test context menu")  end
        }
        eventTrackingAtStartupSettingsSubmenu[#eventTrackingAtStartupSettingsSubmenu + 1] = {
            name            = "Automatically enable (after ReloadUI) & !|cFF0000Reload the UI Now|r!",
            callback        = function(comboBox, itemName, item)
                tbug_SetAutomaticEventsTrackingFlag = tbug_SetAutomaticEventsTrackingFlag or tbug.SetAutomaticEventsTrackingFlag
                tbug_SetAutomaticEventsTrackingFlag(true, true)
            end,
            --entries         = submenuEntries,
            tooltip         = "|cFF0000Attention:|r Clicking this button will automatically enable the event tracker after the ReloadUI, as the AddOn merTorchbug loads AND |cFF0000it will relod your UI now|r!\nThis will open the global inspector and activate the events tab automatically.",
            entryType = lsm.LSM_ENTRY_TYPE_BUTTON,
            --rightClickCallback = function() d("Test context menu")  end
        }

        AddCustomScrollableMenuDivider()
        AddCustomScrollableSubMenuEntry("!> Event tracking at startup", eventTrackingAtStartupSettingsSubmenu)
    end

    if isEventMainUIToggle == true then
        ShowCustomScrollableMenu(p_self, defaultScrollableContextMenuOptions)
    end
end
tbug.ShowEventsContextMenu = showEventsContextMenu


------------------------------------------------------------------------------------------------------------------------
-- Localization string functions
------------------------------------------------------------------------------------------------------------------------
local function putLocalizationStringToChat(p_self, p_row, p_data, withCounter)
    withCounter = withCounter or false
    if p_row == nil or p_data == nil then return end
    local keyText = p_data and p_data[localizationStringKeyText]
    --local value = p_data and p_data.value
    if keyText == nil then return end

    if not withCounter then
        addTextToChat("GetString(" .. tos(keyText) ..")")
    else
        addTextToChat("GetString('" .. tos(keyText) .."', <id>)")
    end
end


------------------------------------------------------------------------------------------------------------------------
-- Dialog functions
------------------------------------------------------------------------------------------------------------------------
local function openDialog(p_self, p_row, p_data)
    if p_row == nil or p_data == nil then return end
    local key = p_data and p_data.dataEntry and p_data.dataEntry.data and p_data.dataEntry.data.key
    if key == nil then return end
    ZO_Dialogs_ShowPlatformDialog(tos(key), nil, { })
end


------------------------------------------------------------------------------------------------------------------------
-- Sound functions
------------------------------------------------------------------------------------------------------------------------
local isPlayingEndlessly = false
local endlessPlaySoundName
local endlessPlaySoundEventName = "tbugPlaySoundEndlessly"

local function playRepeated(soundId, count)
    if SOUNDS[soundId] == nil then return end
    count = count or 1
    for i=1, count, 1 do
        PlaySound(SOUNDS[soundId])
    end
end


local function playSoundNow(p_self, p_row, p_data, playCount, playEndless, endlessPause)
    if isPlayingEndlessly and playCount == nil and playEndless == false and endlessPause == nil then
        isPlayingEndlessly = false
        EM:UnregisterForUpdate(endlessPlaySoundEventName)
        return
    end
    if p_row == nil or p_data == nil then return end
    local key = p_data and p_data.key
    local value = p_data and p_data.value
    if key == nil or value == nil then return end

    if key == "NONE" or value == noSoundValue then return end
    if not playEndless then
        playRepeated(key, playCount)
    else
        if isPlayingEndlessly == true then return end
        endlessPause = endlessPause or 0
        local endlessPauseInMs = endlessPause * 1000
        EM:UnregisterForUpdate(endlessPlaySoundEventName)
        if SOUNDS[key] == nil then return end

        playRepeated(key, playCount)
        endlessPlaySoundName = key

        EM:RegisterForUpdate(endlessPlaySoundEventName, endlessPauseInMs, function()
            if not isPlayingEndlessly then
                EM:UnregisterForUpdate(endlessPlaySoundEventName)
                return
            end
            playRepeated(key, playCount)
        end)
        isPlayingEndlessly = true
    end
end
tbug.PlaySoundNow = playSoundNow


------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--Itemlink context menu entries - Only build once for all functions -> At first context menu open
local itemLinkPrefixesSubmenuTab = {}
local upperCaseFunctionNamePrefixes = {}
local upperCaseFunctionNameSubmenuEntriesIndex = 0
local upperCaseFunctionNameSubmenuEntries = {}
local upperCaseFunctionNamePrefixesMoreThanMax = {}
local noUpperCaseFunctionNameSubmenuEntries = {}

local maxSubmenuEntries = 30


local function getPrefixOfItemLinkFunctionNames(functionNamesTab, prefixDepth, p_maxSubmenuEntries, p_self, p_row, p_data)
--("========================================")
--d("========================================")
--d("[TBUG]getPrefixOfItemLinkFunctionNames-prefixDepth: " ..tos(prefixDepth) .. ", maxEntries: " ..tos(p_maxSubmenuEntries))
--d("========================================")
--d("========================================")
    for _, itemLinkFuncName in ipairs(functionNamesTab) do
        --Get the prefix of the function name (2nd Uppercase char, to detect e.g. Is or Get or Set or Preview or ZO_ prefix)
        local upperCaseOffsetsTab = findUpperCaseCharsAndReturnOffsetsTab(itemLinkFuncName)
        if not ZO_IsTableEmpty(upperCaseOffsetsTab) then
            local startPos --Start the subString for the submenu at 1st character, until next uppercase character
            local endPos --endPos should be next uppercase char - 1
            local prefixCounter = 0
            if #upperCaseOffsetsTab < prefixDepth then
                startPos = 1
                endPos = strlen(itemLinkFuncName)
            else
                for _, posData in ipairs(upperCaseOffsetsTab) do
                    if startPos == nil or endPos == nil then
                        startPos = 1
                        --Is the first uppercase char the 1st char in the function name?
                        -->Then do not use the endPos (1 in that case), but the next found's upperCase char's startPos - 1
                        if prefixDepth == 1 then
                            if posData.startPos ~= 1 and posData.endPos ~= 1 then
                                endPos = posData.startPos - 1
                                --else
                                --1st char is upperCase
                            end
                        else
                            prefixCounter = prefixCounter + 1
                            if prefixCounter == prefixDepth then
                                endPos = posData.startPos - 1
                            end
                        end
                        if endPos ~= nil and endPos <= 0 then endPos = 1 end
                        if startPos ~= nil and endPos ~= nil then break end
                    end
                end
    --d(">funcName: " ..tos(itemLinkFuncName) .. ", startPos: " ..tos(startPos) .. ",  endPos: " ..tos(endPos))
                if startPos ~= nil and endPos ~= nil then
                    local subStrName = strsub(itemLinkFuncName, startPos, endPos)
    --d(">subStrName: " ..tos(subStrName))
                    if subStrName ~= nil and subStrName ~= "" then
                        if upperCaseFunctionNamePrefixes[subStrName] == nil then
                            upperCaseFunctionNameSubmenuEntriesIndex = upperCaseFunctionNameSubmenuEntriesIndex + 1
                            upperCaseFunctionNamePrefixes[subStrName] = upperCaseFunctionNameSubmenuEntriesIndex
    --d(">>index NEW: " ..tos(upperCaseFunctionNameSubmenuEntriesIndex))
                            local a, b, c = p_self, p_row, p_data
                            upperCaseFunctionNameSubmenuEntries[upperCaseFunctionNameSubmenuEntriesIndex] = {
                                submenuName = subStrName,
                                submenuEntries = {
                                    [1] = {
                                        name = itemLinkFuncName,
                                        label = itemLinkFuncName,
                                        callback = function() --start chat input with that func name and an itemLink of the bagId and slotIndex of the context menu
--d(">callback itemlink func: " ..tos(itemLinkFuncName))
                                            setChatEditTextFromContextMenu(a, b, c, false, itemLinkFuncName, false, true)
                                        end,
                                    }
                                },
                            }
                        else
                            local a, b, c = p_self, p_row, p_data

                            local indexOfSubmenuEntry = upperCaseFunctionNamePrefixes[subStrName]
    --d(">>EXISTING index: " ..tos(indexOfSubmenuEntry))
                            local currentSubmenuEntries = upperCaseFunctionNameSubmenuEntries[indexOfSubmenuEntry].submenuEntries
                            local newEntryCount = #currentSubmenuEntries + 1
                            currentSubmenuEntries[newEntryCount] = {
                                name = itemLinkFuncName,
                                label = itemLinkFuncName,
                                callback = function() --start chat input with that func name and an itemLink of the bagId and slotIndex of the context menu
--d(">callback2 itemlink func: " ..tos(itemLinkFuncName))
                                    setChatEditTextFromContextMenu(a, b, c, false, itemLinkFuncName, false, true)
                                end,
                            }

                            if newEntryCount > p_maxSubmenuEntries then
                                upperCaseFunctionNamePrefixesMoreThanMax[subStrName] = true
                            end
                        end
                    end
                end
            end

        else
--d("!!!! >No Uppercase function name!")
            --No uppercase characters in the function name? Directly add it
            local a, b, c = p_self, p_row, p_data
            noUpperCaseFunctionNameSubmenuEntries[#noUpperCaseFunctionNameSubmenuEntries + 1] = {
                name = itemLinkFuncName,
                label = itemLinkFuncName,
                callback = function() --start chat input with that func name and an itemLink of the bagId and slotIndex of the context menu
--d(">callback3 itemlink func: " ..tos(itemLinkFuncName))
                    setChatEditTextFromContextMenu(a, b, c , false, itemLinkFuncName, false, true)
                end,
            }
        end
    end
end

local function buildItemLinkContextMenuEntries(p_self, p_row, p_data, prefixDepth)
    prefixDepth = prefixDepth or 3
    local functionsItemLinkSorted = tbug.functionsItemLinkSorted
    if ZO_IsTableEmpty(functionsItemLinkSorted) then return end

    --Needs to reset on each call as p_self, p_row and p_data change ... else the itemLink will be the old (first one)
    itemLinkPrefixesSubmenuTab = {}

    if ZO_IsTableEmpty(itemLinkPrefixesSubmenuTab) then
        upperCaseFunctionNamePrefixes = {}
        upperCaseFunctionNameSubmenuEntriesIndex = 0
        upperCaseFunctionNameSubmenuEntries = {}
        upperCaseFunctionNamePrefixesMoreThanMax = {}
        noUpperCaseFunctionNameSubmenuEntries = {}

        --Get itemLink functionNames with prefix 1
        getPrefixOfItemLinkFunctionNames(functionsItemLinkSorted, 1, maxSubmenuEntries, p_self, p_row, p_data)

        --Uppercase function name submenu entries, for each prefix one
        -->Check 5 times for too many entries in submenus -> Would build up to 5 submenu prefixes with longer entries
        -->e.g. GetItemLinkTrait or GetItemLink or GetItem etc.

        --Up to prefixDepth 5
        for i=1, prefixDepth, 1 do
            if not ZO_IsTableEmpty(upperCaseFunctionNameSubmenuEntries) then
                local l_prefixDepth = i + 1

                for idx, upperCaseSubmenuPrefixData in ipairs(upperCaseFunctionNameSubmenuEntries) do
                    --Check which submenuPrefixEntries are more than the allowed max and build new subMenus with a longer prefix
                    local prefixNameOld = upperCaseSubmenuPrefixData.submenuName
                    if upperCaseFunctionNamePrefixesMoreThanMax[prefixNameOld] == true then
                        local currentSubmenuPrefixData = ZO_ShallowTableCopy(upperCaseSubmenuPrefixData)
                        if currentSubmenuPrefixData ~= nil then
--d("<<PREFIX DELETED due to too many entries: " ..tos(prefixNameOld))
                            --Delete the old 1 prefix entry
                            trem(upperCaseFunctionNameSubmenuEntries, idx)
                            upperCaseFunctionNamePrefixes[prefixNameOld] = nil
                            upperCaseFunctionNameSubmenuEntriesIndex = #upperCaseFunctionNameSubmenuEntries

                            --Get function names with the prefix
                            local functionNamesTab = {}
                            for _, submenuEntryData in ipairs(currentSubmenuPrefixData.submenuEntries) do
                                functionNamesTab[#functionNamesTab + 1] = submenuEntryData.label
                            end
                            getPrefixOfItemLinkFunctionNames(functionNamesTab, l_prefixDepth, maxSubmenuEntries, p_self, p_row, p_data)
                        end
                    end

                end

            end
        end --for i=1, prefixDepth, 1 do

        if not ZO_IsTableEmpty(upperCaseFunctionNameSubmenuEntries) then
--d(">found #upperCaseFunctionNameSubmenuEntries: " ..tos(#upperCaseFunctionNameSubmenuEntries))
--tbug._upperCaseFunctionNameSubmenuEntries = upperCaseFunctionNameSubmenuEntries

            for _, upperCaseSubmenuPrefixData in ipairs(upperCaseFunctionNameSubmenuEntries) do
                itemLinkPrefixesSubmenuTab[#itemLinkPrefixesSubmenuTab + 1] = {
                    submenuName    = "\'" .. upperCaseSubmenuPrefixData.submenuName  .. "\'",
                    submenuEntries = upperCaseSubmenuPrefixData.submenuEntries
                }
            end
        end


        --No uppercase function name submenu entries
        if not ZO_IsTableEmpty(noUpperCaseFunctionNameSubmenuEntries) then
--d(">found #noUpperCaseFunctionNameSubmenuEntries: " ..tos(noUpperCaseFunctionNameSubmenuEntries))
            itemLinkPrefixesSubmenuTab[#itemLinkPrefixesSubmenuTab + 1] = {
                submenuName    = "Other",
                submenuEntries = noUpperCaseFunctionNameSubmenuEntries
            }
        end
    end

    --tbug._upperCaseFunctionNameSubmenuEntries = upperCaseFunctionNameSubmenuEntries
    --tbug._noUpperCaseFunctionNameSubmenuEntries = noUpperCaseFunctionNameSubmenuEntries
    --tbug._itemLinkPrefixesSubmenuTab = itemLinkPrefixesSubmenuTab

    if not ZO_IsTableEmpty(itemLinkPrefixesSubmenuTab) then
        table_sort(itemLinkPrefixesSubmenuTab, function(a, b) return a.submenuName < b.submenuName end)

        AddCustomScrollableMenuEntry("ItemLink functions", noCallbackFunc, LSM_ENTRY_TYPE_HEADER, nil, nil)

        for _, data in ipairs(itemLinkPrefixesSubmenuTab) do
            AddCustomScrollableSubMenuEntry(data.submenuName, data.submenuEntries)
        end
    end
--[[
tbug._debug = tbug._debug or {}
tbug._debug.itemLinkContextMenu = {
    itemLinkPrefixesSubmenuTab = itemLinkPrefixesSubmenuTab,
    upperCaseFunctionNameSubmenuEntries = upperCaseFunctionNameSubmenuEntries,
    noUpperCaseFunctionNameSubmenuEntries = noUpperCaseFunctionNameSubmenuEntries,
}
]]
end

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

local function addScriptContextMenuEntriesForClassOrObjectIdentifierKey(p_key, p_self, p_row, p_data, p_isFunctionsDataType)
--d("[tbug]addScriptContextMenuEntriesForClassOrObjectIdentifierKey-key: " ..tos(p_key))
    tbug_glookup = tbug_glookup or tbug.glookup

    local openInNewInspector = IsShiftKeyDown()
    local doAddAsObject, doAddAsClass, doAddAsLibrary, subjectName
    local keyCopy = p_key
    local selfCopy = p_self
    local rowCopy = p_row
    local dataCopy = p_data
    local isFunction = p_isFunctionsDataType

    local retVar = false
    local subject = (p_self._parentSubject ~= nil and p_self._parentSubject) or nil
    if subject == nil then
        subject = p_self.subject
    else
        --Should be an object if a parentSubject was found
        subjectName = tbug_glookup(subject)
        if subjectName ~= nil then
            lookupTabObject[subjectName] = true
            doAddAsObject = true
        end
    end

    if not doAddAsObject then
        if  p_key == nil or subject == nil or subject == EsoStrings or p_key == _G or p_key == "_G" then
            return
        end

        --Check if the currently inspected subject got a parentSubject (.__Object)
        --[[
        if p_self.parentSubject ~= nil and subject ~= _G and tbug_glookup(subject) == nil then
    d(">parentSubject found, tbug_glookup(subject): " .. tostring(tbug_glookup(subject)))
            subject = p_self.parentSubject
        end
        ]]

        doAddAsObject, doAddAsClass, doAddAsLibrary, subjectName = isObjectOrClassOrLibrary(subject, keyCopy)
    end

    if tbug.doDebug then
        tbug._debugAddScriptContextMenu = {
            key = keyCopy,
            self = selfCopy,
            row = rowCopy,
            data = dataCopy,
            isFunction = isFunction,
            doAddAsObject = doAddAsObject,
            doAddAsClass = doAddAsClass,
            doAddAsLibrary = doAddAsLibrary,
        }
    end

    if doAddAsObject == true then
        --(text, callback, entryType, entries, additionalData)
        AddCustomScrollableMenuEntry("Use object[key] as script", function()
            useForScript(selfCopy, rowCopy, dataCopy, true, isFunction, true, openInNewInspector) end, LSM_ENTRY_TYPE_NORMAL, nil, nil
        )
        retVar = true
    elseif doAddAsLibrary == true then
        AddCustomScrollableMenuEntry("Use library[key] as script", function()
            useForScript(selfCopy, rowCopy, dataCopy, true, isFunction, true, openInNewInspector) end, LSM_ENTRY_TYPE_NORMAL, nil, nil
        )
        retVar = true
    elseif doAddAsClass == true then
        AddCustomScrollableMenuEntry("Use class[key] as script", function()
            useForScript(selfCopy, rowCopy, dataCopy, true, isFunction, true, openInNewInspector) end, LSM_ENTRY_TYPE_NORMAL, nil, nil
        )
        retVar = true
    end

    --if retVar == true and isFunction == true then
    --Show an additional context menu entry: Show scripts popup editbox and let us enter parameters directly
    --todo really needed? Better us the scripts tab for that
    --end
    return retVar
end

local function sortEnumsContextMenuTableByValue(entryA, entryB)
    return entryA.enumValue < entryB.enumValue
end

--Row context menu at inspectors
--Custom context menu entry creation for inspector rows / LibScrollableMenu support as of version 1.7
function tbug.buildRowContextMenuData(p_self, p_row, p_data, p_contextMenuForKey, mouseIsOverRightKey)
    p_contextMenuForKey = p_contextMenuForKey or false

--d("[tbug.buildRowContextMenuData]isKey: " ..tos(p_contextMenuForKey) .. ", mouseIsOverRightKey: " .. tos(mouseIsOverRightKey) ..", useLibScrollableMenu: " ..tos(useLibScrollableMenu))
    if useLibScrollableMenu == false or (p_self == nil or p_row == nil or p_data == nil) then return end

    --TODO: for debugging
    local doShowMenu = false
    hideContextMenus()

    RT = tbug.RT
    local dataEntry = p_data.dataEntry
    local dataTypeId = dataEntry and dataEntry.typeId

    local canEditValue = p_self:canEditValue(p_data)
    local key          = p_data.key
    local keyType      = type(key)
    local currentValue = p_data.value
    local valType      = type(currentValue)
    local valueIsTable = (valType == tableType and true) or false
    local prop         = p_data.prop
    local propName = prop and prop.name
    local dataPropOrKey = (propName ~= nil and propName ~= "" and propName) or key
    local keyToEnums = tbug.keyToEnums
    local keyToSpecialEnums = tbug.keyToSpecialEnum
    --d(">canEditValue: " ..tos(canEditValue) .. ", forKey: " .. tos(p_contextMenuForKey) .. ", key: " ..tos(key) ..", keyType: "..tos(keyType) .. ", value: " ..tos(currentValue) .. ", valType: " ..tos(valType) .. ", propName: " .. tos(propName) ..", dataPropOrKey: " ..tos(dataPropOrKey))

    local activeTab = p_self.inspector and p_self.inspector.activeTab

    local subject = activeTab and activeTab.subject
    local subjectName = activeTab and activeTab.subjectName
    local parentSubjectName = activeTab and activeTab.parentSubjectName

    local isScriptHistoryDataType = dataTypeId == RT.SCRIPTHISTORY_TABLE
    local isSoundsDataType = dataTypeId == RT.SOUND_STRING
    local isLocalStringDataType = dataTypeId == RT.LOCAL_STRING
    local isDialogDataType = dataTypeId == RT.GENERIC and activeTab and activeTab.pKeyStr == globalInspectorDialogTabKey --"dialogs"
    local isFunctionsDataType = dataTypeId == RT.GENERIC and activeTab and activeTab.pKeyStr == globalInspectorFunctionsTabKey --"functions"
    local isSavedInspectorsDataType = dataTypeId == RT.SAVEDINSPECTORS_TABLE
    local isEventsDataType = dataTypeId == RT.EVENTS_TABLE

    --for debugging
    --[[
tbug._contextMenuLast = {}
tbug._contextMenuLast.self   =  p_self
tbug._contextMenuLast.row    =  p_row
tbug._contextMenuLast.data   =  p_data
tbug._contextMenuLast.key    =  key
tbug._contextMenuLast.isKey  =  p_contextMenuForKey
tbug._contextMenuLast.dataTypeId =  dataTypeId
tbug._contextMenuLast.propName =  propName
tbug._contextMenuLast.activeTab =  activeTab
tbug._contextMenuLast.canEditValue =  canEditValue
    ]]
    ------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------
    --LibScrollableMenu - Scrollable menuwith nested submenus
    if useLibScrollableMenu == true then

        --Context menu for the key of the row
        if p_contextMenuForKey == true then
            ------------------------------------------------------------------------------------------------------------------------
            ------------------------------------------------------------------------------------------------------------------------
            ------------------------------------------------------------------------------------------------------------------------
            local rightKey = p_row.cKeyRight
            if key == nil and rightKey ~= nil then
                if (mouseIsOverRightKey ~= nil and mouseIsOverRightKey == true) or rightKey.GetText then
                    local rightKeyText = rightKey:GetText()
                    --d(">1right key found - text: " ..tos(rightKeyText))
                    if rightKeyText ~= "" then
                        AddCustomScrollableMenuEntry("Copy right key RAW to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, true, nil, true, nil, true) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                        doShowMenu = true --to show right key entries
                    end
                end


                ------------------------------------------------------------------------------------------------------------------------
                ------------------------------------------------------------------------------------------------------------------------
            elseif key ~= nil then
                local rowActionsSuffix = ""
                local keyNumber = ton(key)
                if numberType == type(keyNumber) then
                    rowActionsSuffix = " - #" .. tos(key)
                end

                --Special dataTypes used (e.g. SavedInspectors where the key is a table!)
                local isSpecialTableKeySoUseKeyNumber = (dataTypeId == RT.SAVEDINSPECTORS_TABLE and true) or false


                --AddCustomScrollableMenuEntry(text, callback, entryType, entries, additionalData)

                --General entries
                AddCustomScrollableMenuEntry("Row actions" .. rowActionsSuffix, noCallbackFunc, LSM_ENTRY_TYPE_HEADER, nil, nil)
                AddCustomScrollableMenuEntry("Copy key RAW to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, true, nil, true) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)

                --Is the left side of the inspector (key area) but the right key right clicked?
                ---if mouseIsOverRightKey then
                if (mouseIsOverRightKey ~= nil and mouseIsOverRightKey == true) or (rightKey ~= nil and rightKey.GetText) then
                    local rightKeyText = rightKey:GetText()
                    --d(">2right key found - text: " ..tos(rightKeyText))
                    if rightKeyText ~= "" then
                        AddCustomScrollableMenuEntry("-", noCallbackFunc, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
                        AddCustomScrollableMenuEntry("Copy right key RAW to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, true, nil, true, nil, true) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                    end
                end

                AddCustomScrollableMenuEntry("-", noCallbackFunc, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
                --Add copy "value" raw to chat
                --Default "copy raw etc." entries
                AddCustomScrollableMenuEntry("Copy value RAW to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, true, nil, nil) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                if tbug.isSpecialEntryAtInspectorList(p_self, p_row, p_data) then
                    AddCustomScrollableMenuEntry("Copy value SPECIAL to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, false, "special", nil) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                end

                --Use as script entries
                AddCustomScrollableMenuEntry("Script actions", noCallbackFunc, LSM_ENTRY_TYPE_HEADER, nil, nil)
                AddCustomScrollableMenuEntry("Use key as script", function() useForScript(p_self, p_row, p_data, true, isFunctionsDataType, false) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                local wasAddedScriptsContextMenus = addScriptContextMenuEntriesForClassOrObjectIdentifierKey(key, p_self, p_row, p_data, isFunctionsDataType)
                --if not wasAddedScriptsContextMenus or isScriptHistoryDataType then
                if rowActionsSuffix == "" or isScriptHistoryDataType then
                    AddCustomScrollableMenuEntry("Show in ScriptViewer", function()
                                    --p_self, p_row, p_data, isKey,                                          isFunctionsDataType, isClassOrObjectOrLibrary, showInNewTab, scriptStrIsValue, noDirectExecute
                        useForScript(p_self, p_row, p_data, (not isScriptHistoryDataType and true) or false, isFunctionsDataType, true, true, isScriptHistoryDataType, true) end, LSM_ENTRY_TYPE_NORMAL, nil, nil
                    )
                end


                --Search entries
                local searchValuesAdded = {}
                local searchSubmenu = {}
                local keyStr = key
                local keyStrType = type(keyStr)
                if keyType == numberType then
                    keyStr = p_data.keyText
                    if keyStr == nil then
                        keyStr = ((isSpecialTableKeySoUseKeyNumber == true and valueIsTable == true) and tos(key)) or nil
                    end
                    if keyStr == nil then
                        if not isSpecialTableKeySoUseKeyNumber then
                            --local dataValue = p_data.value
                            if currentValue ~= nil then
                                if valueIsTable == true then
                                    keyStr = (currentValue.name or (currentValue._timeStamp ~= nil and tbug.formatTimestamp(currentValue._timeStamp))) or nil
                                else
                                    if valType ~= booleanType then
                                        keyStr = currentValue
                                    end
                                end
                            end
                        end
                    end
                    if keyStr == nil then
                        keyStr = tos(key)
                    end
                end

                tins(searchSubmenu,
                        {
                            name =     "Search key",
                            callback =  function() setSearchBoxTextFromContextMenu(p_self, p_row, p_data, keyStr) end,
                        }
                )
                searchValuesAdded[keyStr] = true
                if valType == stringType or valType == numberType then
                    tins(searchSubmenu,
                            {
                                name =     "Search value",
                                callback =  function() setSearchBoxTextFromContextMenu(p_self, p_row, p_data, tos(currentValue)) end,
                            }
                    )
                    searchValuesAdded[tos(currentValue)] = true
                end

                --String and splittable at "_"?
                local isSplittable, splitTab = isSplittableString(keyStr, constantsSplitSepparator)
                if isSplittable == true then
                    tins(searchSubmenu,
                            {
                                name =     "-",
                                callback =  noCallbackFunc,
                            }
                    )

                    local searchString = ""
                    for i=1, #splitTab - 1, 1 do
                        searchString = searchString .. splitTab[i] .. constantsSplitSepparator
                        local searchStringForSubmenu = searchString
                        if not searchValuesAdded[searchStringForSubmenu] then
                            tins(searchSubmenu,
                                    {
                                        name =     "Search '" .. searchStringForSubmenu .. "'",
                                        callback =  function() setSearchBoxTextFromContextMenu(p_self, p_row, p_data, searchStringForSubmenu) end,
                                    }
                            )
                            searchValuesAdded[searchStringForSubmenu] = true
                        end
                    end
                end

                --String and got uppercase characters in there, where we could split it?
                local upperCaseOffsetsTab = findUpperCaseCharsAndReturnOffsetsTab(keyStr)
                if not ZO_IsTableEmpty(upperCaseOffsetsTab) then
                    tins(searchSubmenu,
                            {
                                name =     "-",
                                callback =  noCallbackFunc,
                            }
                    )

                    local stringLength = strlen(keyStr)
                    local searchString = ""
                    local maxEntries = #upperCaseOffsetsTab
                    for idx, offsetData in ipairs(upperCaseOffsetsTab) do
                        local upperCaseString
                        local startPos = offsetData.startPos
                        local endPos = ((idx+1 <= maxEntries) and (upperCaseOffsetsTab[idx + 1].startPos - 1)) or stringLength

                        if startPos ~= nil and endPos ~= nil then
                            upperCaseString = strsub(keyStr, startPos, endPos)
                            --Last entry? Do not add the complete string again as "Search key" covers that already!
                            if idx == maxEntries or stringLength == endPos then
                                --d(">lastEntry!")
                                --Check if last entry ends with digits
                                local digitsFoundStartPos, digitsFoundEndPos = strfind(upperCaseString, "%d+$")
                                --d(">>digitsFoundStartPos: " ..tos(digitsFoundStartPos) .. ", digitsFoundEndPos: " ..tos(digitsFoundEndPos))
                                if digitsFoundStartPos ~= nil then
                                    local upperCaseStringWithoutDigits = strsub(upperCaseString, 1, digitsFoundStartPos - 1)
                                    --d(">>>upperCaseStringWithoutDigits: " ..tos(upperCaseStringWithoutDigits))
                                    if upperCaseStringWithoutDigits ~= "" then
                                        local searchStringWithoutDigits = searchString .. upperCaseStringWithoutDigits
                                        if not searchValuesAdded[searchStringWithoutDigits] then
                                            tins(searchSubmenu,
                                                    {
                                                        name =     "Search '" .. searchStringWithoutDigits .. "'",
                                                        callback =  function() setSearchBoxTextFromContextMenu(p_self, p_row, p_data, searchStringWithoutDigits) end,
                                                    }
                                            )
                                            searchValuesAdded[searchStringWithoutDigits] = true
                                        end
                                    end
                                end
                            end

                            if upperCaseString ~= nil then
                                searchString = searchString .. upperCaseString
                                local searchStringCopy = searchString
                                --d(">searchString: " ..tos(searchString) .. ", upperCaseString: " ..tos(upperCaseString))
                                if not searchValuesAdded[searchStringCopy] then
                                    tins(searchSubmenu,
                                            {
                                                name =     "Search '" .. searchString .. "'",
                                                callback =  function() setSearchBoxTextFromContextMenu(p_self, p_row, p_data, searchStringCopy) end,
                                            }
                                    )
                                    searchValuesAdded[searchStringCopy] = true
                                end
                            end
                        end
                    end
                end

                local searchHeaderAdded = false
                if not ZO_IsTableEmpty(searchSubmenu) then
                    AddCustomScrollableMenuEntry(searchActionsStr, noCallbackFunc, LSM_ENTRY_TYPE_HEADER, nil, nil)
                    searchHeaderAdded = true
                    AddCustomScrollableSubMenuEntry("Search", searchSubmenu)
                end


                --External search in ESOUI GitHub sources
                local externalSearchSubmenu = {}
                if keyStrType ~= "string" then
                    keyStr = tostring(keyStr)
                end
                if keyStr ~= nil and keyStr ~= "" then
                    tins(externalSearchSubmenu,
                            {
                                name =     strformat(externalUrlGitHubSearchString, keyStr),
                                callback =  function() searchExternalURL(p_self, p_row, p_data, keyStr, "github") end,
                            }
                    )
                end
                if subjectName ~= nil and subjectName ~= keyStr and type(subjectName) == stringType then
                    tins(externalSearchSubmenu,
                            {
                                name =     strformat(externalUrlGitHubSearchString, subjectName),
                                callback =  function() searchExternalURL(p_self, p_row, p_data, subjectName, "github") end,
                            }
                    )
                end
                if parentSubjectName ~= nil and parentSubjectName ~= subjectName and parentSubjectName ~= keyStr and type(parentSubjectName) == stringType then
                    tins(externalSearchSubmenu,
                            {
                                name =     strformat(externalUrlGitHubSearchString, parentSubjectName),
                                callback =  function() searchExternalURL(p_self, p_row, p_data, parentSubjectName, "github") end,
                            }
                    )
                end
                if not ZO_IsTableEmpty(externalSearchSubmenu) then
                    if not searchHeaderAdded then
                        AddCustomScrollableMenuEntry(searchActionsStr, noCallbackFunc, LSM_ENTRY_TYPE_HEADER, nil, nil)
                        searchHeaderAdded = true
                    end
                    AddCustomScrollableSubMenuEntry("Search external", externalSearchSubmenu)
                end


                doShowMenu = true --to show general entries
                ------------------------------------------------------------------------------------------------------------------------

                --Is key a string ending on "SCENE_NAME" and the value is a string e.g. "trading_house"
                -->Show a context menu entry "Open scene"
                if type(key) == stringType and valType == stringType and (tbug_endsWith(key, "_SCENE_NAME") == true or tbug_endsWith(key, "_SCENE_IDENTIFIER") == true) then
                    local slashCmdToShowScene = "SCENE_MANAGER:Show(\'" ..tos(currentValue) .. "\')"
                    AddCustomScrollableMenuEntry("Scene actions", noCallbackFunc, LSM_ENTRY_TYPE_HEADER, nil, nil)
                    AddCustomScrollableMenuEntry("Show scene", function() tbug_slashCommand(slashCmdToShowScene) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                    if SCENE_MANAGER:IsShowing(tos(currentValue)) then
                        local slashCmdToHideScene = "SCENE_MANAGER:Hide(\'" ..tos(currentValue) .. "\')"
                        AddCustomScrollableMenuEntry("Hide scene", function() tbug_slashCommand(slashCmdToHideScene) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                    end
                end
                ------------------------------------------------------------------------------------------------------------------------

                --Dialogs
                if isDialogDataType then
                    AddCustomScrollableMenuEntry("Dialog actions", noCallbackFunc, LSM_ENTRY_TYPE_HEADER, nil, nil)
                    AddCustomScrollableMenuEntry("Show platform dialog",
                            function()
                                openDialog(p_self, p_row, p_data)
                            end,
                            LSM_ENTRY_TYPE_NORMAL, nil, nil)

                    --Functions
                    --elseif isFunctionsDataType then


                    --Localization strings
                elseif isLocalStringDataType then
                    AddCustomScrollableMenuEntry("Local. string actions", noCallbackFunc, LSM_ENTRY_TYPE_HEADER, nil, nil)
                    AddCustomScrollableMenuEntry("GetString(<constant>) to chat",
                            function()
                                putLocalizationStringToChat(p_self, p_row, p_data, false)
                            end,
                            LSM_ENTRY_TYPE_NORMAL, nil, nil)
                    AddCustomScrollableMenuEntry("GetString('<constant>', id) to chat",
                            function()
                                putLocalizationStringToChat(p_self, p_row, p_data, true)
                            end,
                            LSM_ENTRY_TYPE_NORMAL, nil, nil)

                    --Sounds
                elseif isSoundsDataType then
                    local soundsHeadlineAdded = false
                    local function addSoundsHeadline()
                        if soundsHeadlineAdded == true then return false end
                        AddCustomScrollableMenuEntry("Sounds actions", noCallbackFunc, LSM_ENTRY_TYPE_HEADER, nil, nil)
                        soundsHeadlineAdded = true
                        return true
                    end
                    if currentValue ~= noSoundValue then
                        addSoundsHeadline()
                        AddCustomScrollableMenuEntry("||> Play sound",
                                function()
                                    playSoundNow(p_self, p_row, p_data, 1, false)
                                end,
                                LSM_ENTRY_TYPE_NORMAL, nil, nil)
                        local playSoundLouderSubmenu = {}
                        for volume=2,10,1 do
                            playSoundLouderSubmenu[#playSoundLouderSubmenu+1] = {
                                name = "Play sound louder ("..tos(volume).."x)",
                                callback = function()
                                    playSoundNow(p_self, p_row, p_data, volume, false)
                                end,
                            }
                        end
                        AddCustomScrollableSubMenuEntry("||> Play sound (choose volume)", playSoundLouderSubmenu)
                    end
                    if isPlayingEndlessly == true then
                        if not addSoundsHeadline() then
                            AddCustomScrollableMenuEntry("-", function()  end)
                        end
                        AddCustomScrollableMenuEntry("[ ] STOP playing non-stop \'" ..tos(endlessPlaySoundName) .. "\'",
                                function()
                                    playSoundNow(p_self, p_row, p_data, nil, false, nil)
                                end,
                                LSM_ENTRY_TYPE_NORMAL, nil, nil)
                    else
                        if currentValue ~= noSoundValue then
                            AddCustomScrollableMenuEntry("-", function()  end)
                            local playSoundEndlesslyVolumeSubmenus = {}
                            for volume=1,10,1 do
                                playSoundEndlesslyVolumeSubmenus[volume] = {}
                                for pause=0,10,1 do
                                    playSoundEndlesslyVolumeSubmenus[volume][#playSoundEndlesslyVolumeSubmenus[volume]+1] = {
                                        name = "Play non-stop ("..tos(pause).."s pause)",
                                        callback = function()
                                            playSoundNow(p_self, p_row, p_data, volume, true, pause)
                                        end,
                                    }
                                end
                                AddCustomScrollableSubMenuEntry("||> Play non-stop (volume "..tos(volume)..")", playSoundEndlesslyVolumeSubmenus[volume])
                            end
                        end
                    end

                    --SavedInspectors KEY context menu
                elseif isSavedInspectorsDataType then
                    AddCustomScrollableMenuEntry("Saved inspectors actions", noCallbackFunc, LSM_ENTRY_TYPE_HEADER, nil, nil)
                    --[[
                    AddCustomScrollableMenuEntry("Edit saved inspector entry",
                            function()
                                editSavedInspectors(p_self, p_row, p_data, true)
                            end,
                            LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
                    ]]
                    AddCustomScrollableMenuEntry("Edit saved inspectors comment",
                            function()
                                editSavedInspectors(p_self, p_row, p_data, false)
                            end,
                            LSM_ENTRY_TYPE_NORMAL, nil, nil)
                    AddCustomScrollableMenuEntry("-", noCallbackFunc, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                    AddCustomScrollableMenuEntry("Delete saved inspectors entry",
                            function()
                                removeSavedInspectors(p_self, key, true, nil)
                            end,
                            LSM_ENTRY_TYPE_NORMAL, nil, nil)
                    AddCustomScrollableMenuEntry("Clear total saved inspectors",
                            function()
                                removeSavedInspectors(p_self, key, true, true)
                            end,
                            LSM_ENTRY_TYPE_NORMAL, nil, nil)

                    --ScriptHistory KEY context menu
                elseif isScriptHistoryDataType then
                    AddCustomScrollableMenuEntry("Script history actions", noCallbackFunc, LSM_ENTRY_TYPE_HEADER, nil, nil)
                    AddCustomScrollableMenuEntry("Edit script history entry",
                            function()
                                editScriptHistory(p_self, p_row, p_data, true)
                            end,
                            LSM_ENTRY_TYPE_NORMAL, nil, nil)
                    AddCustomScrollableMenuEntry("Edit script history comment",
                            function()
                                editScriptHistory(p_self, p_row, p_data, false)
                            end,
                            LSM_ENTRY_TYPE_NORMAL, nil, nil)
                    AddCustomScrollableMenuEntry("Test script history entry",
                            function()
                                testScriptHistory(p_self, p_row, p_data, key)
                            end,
                            LSM_ENTRY_TYPE_NORMAL, nil, nil)
                    AddCustomScrollableMenuEntry("-", noCallbackFunc, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                    AddCustomScrollableMenuEntry("Delete script history entry",
                            function()
                                removeScriptHistory(p_self, key, true, nil)
                            end,
                            LSM_ENTRY_TYPE_NORMAL, nil, nil)
                    AddCustomScrollableMenuEntry("Script history clear & clean", noCallbackFunc, LSM_ENTRY_TYPE_HEADER, nil, nil)
                    AddCustomScrollableMenuEntry("Clean script history (duplicates)",
                            function()
                                tbug.ShowConfirmBeforeDialog(nil, "Clean duplicates from script history\nand reassign keybinds (if assigned)?", cleanScriptHistory)
                            end,
                            LSM_ENTRY_TYPE_NORMAL, nil, nil)
                    AddCustomScrollableMenuEntry("Clear total script history",
                            function()
                                removeScriptHistory(p_self, key, true, true)
                            end,
                            LSM_ENTRY_TYPE_NORMAL, nil, nil)

                    --Script keybinds
                    local submenuScriptKeybinds = {}
                    local submenuScriptKeybindsRemove = {}
                    local activeKeybinds = getActiveScriptKeybinds()
                    for i=1, tbug.maxScriptKeybinds, 1 do
                        local scriptKeybindSubmenuEntry = {
                            name = not activeKeybinds[i] and "Set as Keybind #" .. tos(i) or "Reassign keybind #" .. tos(i) .. ", current script: " ..tos(activeKeybinds[i]),
                            callback = function() setScriptKeybind(i, key) end,
                        }
                        tins(submenuScriptKeybinds, scriptKeybindSubmenuEntry)
                        if activeKeybinds[i] ~= nil then
                            local scriptKeybindRemoveSubmenuEntry = {
                                name = "< Remove Keybind #" .. tos(i) .. ", current script: " ..tos(activeKeybinds[i]),
                                callback = function() setScriptKeybind(i, nil, true) end,
                            }
                            tins(submenuScriptKeybindsRemove, scriptKeybindRemoveSubmenuEntry)
                        end
                    end
                    if not ZO_IsTableEmpty(activeKeybinds) then
                        if not ZO_IsTableEmpty(submenuScriptKeybindsRemove) then
                            local scriptKeybindSubmenuEntry = {
                                name = "-", --divider
                            }
                            tins(submenuScriptKeybindsRemove, scriptKeybindSubmenuEntry)
                        end
                        local scriptKeybindClearAllSubmenuEntry = {
                            name = "Clear all script keybinds",
                            callback = function() clearScriptKeybinds() end,
                        }
                        tins(submenuScriptKeybindsRemove, scriptKeybindClearAllSubmenuEntry)
                    end
                    if not ZO_IsTableEmpty(submenuScriptKeybinds) then
                        AddCustomScrollableMenuEntry("Script keybinds", noCallbackFunc, LSM_ENTRY_TYPE_HEADER, nil, nil)
                        AddCustomScrollableSubMenuEntry("Script keybinds", submenuScriptKeybinds)
                        if not ZO_IsTableEmpty(submenuScriptKeybindsRemove) then
                            AddCustomScrollableSubMenuEntry("Script keybinds - Remove", submenuScriptKeybindsRemove)
                        end
                    end

                    doShowMenu = true
                    ------------------------------------------------------------------------------------------------------------------------
                    --Event tracking KEY context menu
                elseif isEventsDataType then

                    showEventsContextMenu(p_self, p_row, p_data, false)
                    ShowCustomScrollableMenu(p_row, defaultScrollableContextMenuOptions)
                    doShowMenu = false --do not show the LibScrollableMenu context menu now!
                end

            end
            ------------------------------------------------------------------------------------------------------------------------
            --Properties are given?
            if prop ~= nil then
                --Getter and Setter - To chat
                local controlOfInspectorRow = p_self.subject
                if controlOfInspectorRow ~= nil then
                    local getterName = prop.getOrig or prop.get
                    local setterName = prop.setOrig or prop.set
                    local getterOfCtrl = controlOfInspectorRow[getterName]
                    local setterOfCtrl = controlOfInspectorRow[setterName]
                    --d(">prop found - get: " ..tos(getterName) ..", set: " ..tos(setterName))

                    if getterOfCtrl ~= nil or setterOfCtrl ~= nil then
                        AddCustomScrollableMenuEntry("Get & Set", noCallbackFunc, LSM_ENTRY_TYPE_HEADER, nil, nil)
                        if getterOfCtrl ~= nil then
                            --p_self, p_row, p_data, copyRawData, copySpecialFuncStr, isKey
                            AddCustomScrollableMenuEntry("Copy getter name to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, false, "getterName", true) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                            AddCustomScrollableMenuEntry("Copy <control>:Getter() to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, false, "control:getter", true) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                        end
                        if setterOfCtrl ~= nil then
                            AddCustomScrollableMenuEntry("Copy setter name to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, false, "setterName", true) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                            AddCustomScrollableMenuEntry("Copy <control>:Setter() to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, false, "control:setter", true) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                        end
                        doShowMenu = true
                    end
                end

                ------------------------------------------------------------------------------------------------------------------------
                --Boolean value at the key, even if no "key" was provided
                if valType == "boolean" then

                    --Control outline KEY context menu
                    if ControlOutline and dataPropOrKey and dataPropOrKey == "outline" then
                        AddCustomScrollableMenuEntry("Outline actions", noCallbackFunc, LSM_ENTRY_TYPE_HEADER, nil, nil)
                        if not controlOfInspectorRow or controlOfInspectorRow:IsHidden() then
                            AddCustomScrollableMenuEntry("Control is hidden - no outline possible", noCallbackFunc, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                        else
                            AddCustomScrollableMenuEntry("Outline", function() outlineControl(p_self, p_row, p_data, false) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                            AddCustomScrollableMenuEntry("Outline + child controls", function() outlineControl(p_self, p_row, p_data, true) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                            AddCustomScrollableMenuEntry("-", noCallbackFunc, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
                            AddCustomScrollableMenuEntry("Blink outline 1x", function() blinkControlOutline(p_self, p_row, p_data, 1) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                            AddCustomScrollableMenuEntry("Blink outline 3x", function() blinkControlOutline(p_self, p_row, p_data, 3) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                            AddCustomScrollableMenuEntry("Blink outline 5x", function() blinkControlOutline(p_self, p_row, p_data, 5) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)

                            local controlToOutline = p_self.subject
                            local addControlClearOutline = (controlToOutline ~= nil and ControlOutline_IsControlOutlined(controlToOutline) and true) or false
                            local addClearAllOutlines = (#ControlOutline.pool.m_Active > 0 and true) or false
                            local addDividerForClearOutlines = addControlClearOutline or addClearAllOutlines
                            if addDividerForClearOutlines == true then
                                AddCustomScrollableMenuEntry("-", noCallbackFunc, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                            end
                            if addControlClearOutline == true then
                                AddCustomScrollableMenuEntry("Remove control outlines", function() hideOutline(p_self, p_row, p_data, false) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                            end
                            if addClearAllOutlines == true then
                                AddCustomScrollableMenuEntry("Remove all outlines", function() hideOutline(p_self, p_row, p_data, true) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                            end
                        end
                        doShowMenu = true
                    end

                end
            end

            ------------------------------------------------------------------------------------------------------------------------
            ------------------------------------------------------------------------------------------------------------------------
            ------------------------------------------------------------------------------------------------------------------------
            --Context menu for the value of the row
        else
            if currentValue ~= nil then
                ------------------------------------------------------------------------------------------------------------------------
                --boolean entries
                if valType == "boolean" then
                    if canEditValue then
                        if currentValue == false then
                            AddCustomScrollableMenuEntry("+ true",  function() p_data.value = true  setEditValueFromContextMenu(p_self, p_row, p_data, false) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                        else
                            AddCustomScrollableMenuEntry("- false", function() p_data.value = false setEditValueFromContextMenu(p_self, p_row, p_data, true) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                        end
                        AddCustomScrollableMenuEntry("   NIL (Attention!)",  function() p_data.value = nil  setEditValueFromContextMenu(p_self, p_row, p_data, currentValue) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                        doShowMenu = true
                    end
                    ------------------------------------------------------------------------------------------------------------------------
                    --number or string entries
                elseif valType == numberType or valType == stringType then
                    --Do we have a setter function given?
                    --Check if any enumeration is provided and add the givenenum entries to the context menu entries
                    local enumsWereAdded = false
                    local numEnumContextMenuEntries = 0
                    local enumContextMenuEntries = {}
                    if prop == nil then
                        if key ~= nil then
                            --No prop given e.g. at a tableInspector of dataEntry of inventory item
                            --Check if dataPropOrKey == "bagId" e.g. and get the mapped enum for bagId
                            prop = {}
                            prop.enum = keyToEnums[key] or keyToSpecialEnums[key]
--d(">no props found, used key: " ..tos(key) .. " to get: " ..tos(prop.enum))
                            if prop.enum == nil then prop = nil else
                                if strsub(prop.enum, -1) == "_" then
                                    prop.enum = strsub(prop.enum, 1, -2) --remove _ at the end
                                end
                            end
                        end
                    end
                    if prop ~= nil then
                        local enumProp = prop.enum or key
                        --Check for enums e.g. ITEMTYPE_ -> Show contextMenu submenu list with all enumeration entries of the ITEMTYPE_*
                        if enumProp ~= nil then
                            local enumsTab = tbug.enums[enumProp]
                            if enumsTab ~= nil then
                                --for debugging
                                --tbug._contextMenuLast.enumsTab = enumsTab
                                local controlOfInspectorRow = p_self.subject
                                if controlOfInspectorRow then
                                    --Setter control and func are given, enums as well

                                    --Create a enum contextMenu cache with sorted data
                                    local cachedEnumsForContextMenu = tbug.enumsContextMenuCache[enumProp]
                                    if cachedEnumsForContextMenu ~= nil then
                                        enumContextMenuEntries = cachedEnumsForContextMenu
                                    else
                                        --Build cache, sorted
                                        local newCachedEnumsForContextMenuEntry = {}
                                        --Loop all enums now
                                        for enumValue, enumName in pairs(enumsTab) do
                                            newCachedEnumsForContextMenuEntry[#newCachedEnumsForContextMenuEntry +1] = { enumName =enumName, enumValue =enumValue}
                                        end
                                        table_sort(newCachedEnumsForContextMenuEntry, sortEnumsContextMenuTableByValue)
                                        tbug.enumsContextMenuCache[enumProp] = newCachedEnumsForContextMenuEntry
                                        enumContextMenuEntries = newCachedEnumsForContextMenuEntry
                                    end
                                    numEnumContextMenuEntries = #enumContextMenuEntries
                                    enumsWereAdded = numEnumContextMenuEntries > 0

                                    local setterName = prop.setOrig or prop.set
                                    local setterOfCtrl
                                    if setterName then
                                        setterOfCtrl = controlOfInspectorRow[setterName]
                                    end
                                    if setterOfCtrl ~= nil then
                                        canEditValue = true
                                    end
                                end
                            end
                        end
                    end
                    local function insertEnumsToContextMenu(dividerLate)
                        if not dividerLate then
                            --Divider line at the top
                            AddCustomScrollableMenuEntry("-", noCallbackFunc)
                        end
                        --Divider line needed from enums?
                        if enumsWereAdded then
                            local headlineText = ((canEditValue and "Choose value") or "Possible values") .. " (#" .. tos(numEnumContextMenuEntries) ..")"
                            --local entryFont = canEditValue and "ZoFontGame" or "ZoFontGameSmall"
                            --local entryFontColorNormal = canEditValue and DEFAULT_TEXT_COLOR or DISABLED_TEXT_COLOR
                            --local entryFontColorHighlighted = canEditValue and DEFAULT_TEXT_HIGHLIGHT or DISABLED_TEXT_COLOR
                            --AddCustomScrollableMenuEntry(headlineText, noCallbackFunc, LSM_ENTRY_TYPE_HEADER, nil, entryFontColorNormal, entryFontColorHighlighted, nil, nil)
                            AddCustomScrollableMenuEntry(headlineText, noCallbackFunc, LSM_ENTRY_TYPE_HEADER)
                            for _, enumData in ipairs(enumContextMenuEntries) do
                                local funcCalledOnEntrySelected = canEditValue and function() p_data.value = enumData.enumValue  setEditValueFromContextMenu(p_self, p_row, p_data, currentValue) end or noCallbackFunc
                                --(text, callback, entryType, entries, additionalData)
                                AddCustomScrollableMenuEntry(enumData.enumName .. " (" .. tos(enumData.enumValue) .. ")", funcCalledOnEntrySelected, LSM_ENTRY_TYPE_NORMAL, nil, { enabled = canEditValue })
                            end
                            if dividerLate then
                                --Divider line at the bottom
                                AddCustomScrollableMenuEntry("-", noCallbackFunc)
                            end
                        end
                    end
                    if enumsWereAdded and canEditValue then
                        insertEnumsToContextMenu(canEditValue)
                    end
                    --Default "copy raw etc." entries
                    AddCustomScrollableMenuEntry("Copy RAW to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, true, nil, nil) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                    --Special entries for bagId/slotIndex
                    local isSpecialEntry = tbug.isSpecialEntryAtInspectorList(p_self, p_row, p_data)
                    if isSpecialEntry then
                        AddCustomScrollableMenuEntry("Copy SPECIAL to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, false, "special", nil) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                    end
                    --BagId / slotIndex
                    if dataPropOrKey and (dataPropOrKey == "bagId" or dataPropOrKey =="slotIndex") then
                        AddCustomScrollableMenuEntry("Copy ITEMLINK to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, false, "itemlink", nil) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                        AddCustomScrollableMenuEntry("Copy NAME to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, false, "itemname", nil) end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
                    end
                    --d(">dataPropOrKey: " ..tos(dataPropOrKey) .. ", isSpecialEntry: " ..tos(isSpecialEntry))
                    if enumsWereAdded and not canEditValue then
                        insertEnumsToContextMenu(canEditValue)
                    end
                    if dataPropOrKey and (dataPropOrKey == "itemLink") or isSpecialEntry then
                        buildItemLinkContextMenuEntries(p_self, p_row, p_data, 5) -- last param only works with LibScrollableMenu. LibCustomMenu cannot handle the lenght of the menus!
                    end
                    doShowMenu = true
                end
            end

            ------------------------------------------------------------------------------------------------------------------------
        end

    end --if useLibScrollableMenu == true then

    -----------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------
    if doShowMenu == true then
        if useLibScrollableMenu == true then
            --controlToAnchorTo, options
            ShowCustomScrollableMenu(p_row, defaultScrollableContextMenuOptions)
        end
    end
end





------------------------------------------------------------------------------------------------------------------------
-- Context menu for the globalInspector/inspector windows tbug icon
---------------------------------------------------------------------------------------------------------------------------
local function updateSizeOnTabWindowAndCallResizeHandler(p_control, newWidth, newHeight)
    local left = p_control:GetLeft()
    local top = p_control:GetTop()
    p_control:ClearAnchors()
    p_control:SetAnchor(TOPLEFT, nil, TOPLEFT, left, top)
    p_control:SetDimensions(newWidth, newHeight)

    local OnResizeStopHandler = p_control:GetHandler("OnResizeStop")
    if OnResizeStopHandler and type(OnResizeStopHandler) == functionType then
        OnResizeStopHandler(p_control)
    end
end



function tbug.ShowTabWindowContextMenu(selfCtrl, button, upInside, selfInspector)
    setDrawLevel = setDrawLevel or tbug.SetDrawLevel
    --Context menu at headline torchbug icon
    if LibScrollableMenu then
        local toggleSizeButton = selfInspector.toggleSizeButton
        local refreshButton = selfInspector.refreshButton

--tbug._selfInspector = selfInspector
--tbug._selfControl = selfCtrl

        globalInspector = globalInspector or tbug.getGlobalInspector()
        local isGlobalInspectorWindow = (selfInspector == globalInspector) or false
        local owner = selfCtrl:GetOwningWindow()

        local activeTab = selfInspector.activeTab
        local subject = activeTab and activeTab.subject
        local subjectName = activeTab and activeTab.subjectName
        local parentSubjectName = activeTab and activeTab.parentSubjectName

        --Clear the context menu
        hideContextMenus()


        ----------------------------------------------------------------------------------------------------------------
        -- -v-  ALL INSPECTORs                                                                                     -v-
        ----------------------------------------------------------------------------------------------------------------
        --Draw layer
        local dLayer = owner:GetDrawLayer()
        --setDrawLevel(owner, DL_CONTROLS)
        local drawLayerSubMenu = {}
        local drawLayerSubMenuEntry = {
            label = "On top",
            callback = function() setDrawLevel(owner, DL_OVERLAY, true) end,
        }
        if dLayer ~= DL_OVERLAY then
            tins(drawLayerSubMenu, drawLayerSubMenuEntry)
        end
        drawLayerSubMenuEntry = {
            label = "Normal",
            callback = function() setDrawLevel(owner, DL_CONTROLS, true) end,
        }
        if dLayer ~= DL_CONTROLS then
            tins(drawLayerSubMenu, drawLayerSubMenuEntry)
        end
        drawLayerSubMenuEntry = {
            label = "Background",
            callback = function() setDrawLevel(owner, DL_BACKGROUND, true) end,
        }
        if dLayer ~= DL_BACKGROUND then
            tins(drawLayerSubMenu, drawLayerSubMenuEntry)
        end
        AddCustomScrollableSubMenuEntry("DrawLayer", drawLayerSubMenu)

        --Add copy RAW title bar
        local titleBar = selfInspector.title
        if titleBar and titleBar.GetText then
            local titleText = titleBar:GetText()
            if titleText ~= "" then
                AddCustomScrollableMenuEntry("-", noCallbackFunc, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
                AddCustomScrollableMenuEntry("Copy RAW title to chat", function()
                    StartChatInput(titleText, CHAT_CHANNEL_SAY, nil)
                end, LSM_ENTRY_TYPE_NORMAL)
                local titleTextClean = cleanTitle(titleText)
                if titleTextClean ~= titleText then
                    AddCustomScrollableMenuEntry("Copy CLEAN title to chat", function()
                        StartChatInput(titleTextClean, CHAT_CHANNEL_SAY, nil)
                    end, LSM_ENTRY_TYPE_NORMAL)
                end
            end

            --subjectName
            --parentSubjectName
            --.__Object
            if activeTab ~= nil then
                if subjectName ~= nil then
                    AddCustomScrollableMenuEntry("Copy SUBJECT to chat", function()
                        addTextToChat(subjectName)
                    end, LSM_ENTRY_TYPE_NORMAL)
                end
                if parentSubjectName ~= nil and subjectName ~= nil and subjectName ~= parentSubjectName then
                    AddCustomScrollableMenuEntry("Copy PARENT SUBJECT to chat", function()
                        addTextToChat(parentSubjectName)
                    end, LSM_ENTRY_TYPE_NORMAL)
                end

                --[[
                .__Object does not exist at the activeTab directly. It's a custom added entry only visible at the .__index entry of the inspector
                if activeTab[customKey__Object] ~= nil then
                    AddCustomScrollableMenuEntry("Copy OBJECT name to chat", function()
                        addTextToChat(activeTab[customKey__Object], true)
                    end, LSM_ENTRY_TYPE_NORMAL)
                end
                ]]
            end
        end

        --Inspectors
        local inspectorsSubmenu = {}
        if not isGlobalInspectorWindow then
            tins(inspectorsSubmenu, {
                label = "Save opened inspectors",
                callback = function()
                    local savedInspectorsNr, windowCounter, tabsCounter = tbug.saveCurrentInspectorsAndSubjects()
                    if savedInspectorsNr ~= nil then
                        d("[TBUG]Saved '".. tostring(windowCounter) .."' open inspector windows, with '" ..tos(tabsCounter) .. "' tabs, to:   #" ..tos(savedInspectorsNr))
                    end
                end,
            })
        end
        tins(inspectorsSubmenu, {
            label = "Close all inspectors",
            callback = function() tbug.closeAllInspectors(true) end,
        })
        if not isGlobalInspectorWindow then
            tins(inspectorsSubmenu, {
                label = "Close all inspectors (excl. Global)",
                callback = function() tbug.closeAllInspectors(false) end,
            })
        end
        if not ZO_IsTableEmpty(inspectorsSubmenu) then
            AddCustomScrollableMenuEntry("-", noCallbackFunc, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
            AddCustomScrollableSubMenuEntry("Inspectors", inspectorsSubmenu)
        end

        --Tabs
        local tabsSubmenu = {}
        if not isGlobalInspectorWindow and toggleSizeButton.toggleState == false and (selfInspector.tabs and #selfInspector.tabs > 0) then
            --[[
            tins(tabsSubmenu, {
                label = "Close all tabs",
                callback = function() tbug.closeAllTabs(selfInspector) end,
            })
            ]]
            tins(tabsSubmenu, {
                label = "Remove all tabs",
                callback = function() selfInspector:removeAllTabs() end,
            })
        elseif isGlobalInspectorWindow and toggleSizeButton.toggleState == false and (selfInspector.tabs and #selfInspector.tabs < tbug.panelCount ) then
            tins(tabsSubmenu, {
                label = "+ Restore all standard tabs",
                callback = function() tbug_slashCommand("-all-")  end,
            })
        end
        if not ZO_IsTableEmpty(tabsSubmenu) then
            AddCustomScrollableMenuEntry("-", noCallbackFunc, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
            AddCustomScrollableSubMenuEntry("Tabs", tabsSubmenu)
        end
        --[[
        --Not at the global inspector of TBUG itsself, else you'd remove all the libraries, scripts, globals etc. tabs
        if not isGlobalInspectorWindow and toggleSizeButton.toggleState == false and (selfInspector.tabs and #selfInspector.tabs > 0) then
            AddCustomScrollableMenuEntry("-", noCallbackFunc, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
            AddCustomScrollableMenuEntry("Remove all tabs", function() selfInspector:removeAllTabs() end, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
            --Only at the global inspector
        elseif isGlobalInspectorWindow and toggleSizeButton.toggleState == false and (selfInspector.tabs and #selfInspector.tabs < tbug.panelCount ) then
            AddCustomScrollableMenuEntry("-", noCallbackFunc, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
            AddCustomScrollableMenuEntry("+ Restore all standard tabs +", function() tbug.slashCommand("-all-") end, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
        end
        ]]



        --Tools
        local toolsSubmenu = {}
        local isSceneManagerInspectorTab = subject ~= nil and subject == SCENE_MANAGER
        if not isSceneManagerInspectorTab then
            tins(toolsSubmenu, {
                label = "SCENE_MANAGER",
                callback = function() tbug_slashCommandSCENEMANAGER() end,
            })
        end

        tins(toolsSubmenu, {
            label = "Toggle inspector width/height at title",
            callback = function() tbug.toggleTitleSizeInfo(selfInspector) end,
        })
        if not ZO_IsTableEmpty(toolsSubmenu) then
            AddCustomScrollableMenuEntry("-", noCallbackFunc, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
            AddCustomScrollableSubMenuEntry("Tools", toolsSubmenu)
        end

        AddCustomScrollableMenuEntry("-", noCallbackFunc, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
        AddCustomScrollableMenuEntry("Reset size to default", function() updateSizeOnTabWindowAndCallResizeHandler(selfInspector.control, tbug.defaultInspectorWindowWidth, tbug.defaultInspectorWindowHeight) end, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
        AddCustomScrollableMenuEntry("Collapse/Expand", function() toggleSizeButton.onClicked[MOUSE_BUTTON_INDEX_LEFT](toggleSizeButton) end, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
        if toggleSizeButton.toggleState == false then
            AddCustomScrollableMenuEntry("Refresh", function() refreshButton.onClicked[MOUSE_BUTTON_INDEX_LEFT]() end, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
        end
        AddCustomScrollableMenuEntry("-", noCallbackFunc, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
        AddCustomScrollableMenuEntry("Hide", function() owner:SetHidden(true) end, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)

        if isPlayingEndlessly == true then
            AddCustomScrollableMenuEntry("-", noCallbackFunc, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
            AddCustomScrollableMenuEntry("[ ] STOP playing sound \'" ..tos(endlessPlaySoundName) .. "\'", function() playSoundNow(nil, nil, nil, nil, false, nil) end, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
        end

        --Update the other checkboxes that are in the same checkboxUpdateGroup and set their enabled state = checked state of the clicked "main" checkbox
        -->Then visually refresh the other checkbox
        local function checkIfCheckboxEnabledStateNeedsToUpdate(LSM_comboBox, selectedContextMenuItem, openingMenusEntries, customParam1, customParam2)
            local selectedContextMenuItemData = (GetCustomScrollableMenuRowData ~= nil and GetCustomScrollableMenuRowData(selectedContextMenuItem)) or selectedContextMenuItem.m_data.dataSource
            if selectedContextMenuItemData == nil then return end
            local checkboxUpdateGroup = selectedContextMenuItemData.checkboxUpdateGroup
            local isSelectedContextMenuChecked = selectedContextMenuItemData.checked
            for k, v in ipairs(openingMenusEntries) do
                if checkboxUpdateGroup == v.checkboxUpdateGroup and v ~= selectedContextMenuItemData then
                    local name = v.label or v.name
                    if v.enabled ~= isSelectedContextMenuChecked then
                        v.enabled = isSelectedContextMenuChecked
                        --Visually refresh the item now
                        LSM_comboBox.m_dropdownObject:Refresh(v.m_parentControl)
                    end
                end
            end

        end
        ----------------------------------------------------------------------------------------------------------------
        -- -^-  ALL INSPECTORs                                                                                     -^-
        ----------------------------------------------------------------------------------------------------------------


        ----------------------------------------------------------------------------------------------------------------
        -- -v-  GLOBAL INSPECTOR only                                                                              -v-
        ----------------------------------------------------------------------------------------------------------------
        if isGlobalInspectorWindow then
            if GetDisplayName() == "@Baertram" then
                AddCustomScrollableMenuEntry("-", noCallbackFunc, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
                AddCustomScrollableMenuEntry("~ DEBUG MODE ~", function() tbug.doDebug = not tbug.doDebug d("[TBUG]Debugging: " ..tos(tbug.doDebug)) end, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
                AddCustomScrollableMenuCheckbox("~ Enable DEBUG MODE at start ~", function(comboBox, itemName, item, checked, data)
                    tbug.savedVars._doDebug = checked
                end, function()  return tbug.savedVars._doDebug end, nil)
            end


            -- -v-  SETTINGS MENU at GLOBAL INSPECTOR                                                               -v-
            AddCustomScrollableMenuEntry("Settings", noCallbackFunc, LSM_ENTRY_TYPE_HEADER, nil, nil, nil, nil, nil)
            --Mouse settings
            local settingsMouseSubmenu = {
                {
                    label = keyShiftAndLMBRMB .." Inspect control below cursor",
                    callback = function(comboBox, itemName, item, checked)
                        tbug.savedVars.enableMouseRightAndLeftAndSHIFTInspector = checked

                        updateTbugGlobalMouseUpHandler(checked)

                        --Check if the checkbox(es) below need to update it's enabled state!
                        RunCustomScrollableMenuItemsCallback(comboBox, item, checkIfCheckboxEnabledStateNeedsToUpdate, { LSM_ENTRY_TYPE_CHECKBOX }, false)
                    end,
                    entryType = LSM_ENTRY_TYPE_CHECKBOX,
                    checked = function() return tbug.savedVars.enableMouseRightAndLeftAndSHIFTInspector end,
                    checkboxUpdateGroup = 1,
                },
                {
                    label = "Allow " .. keyShiftAndLMBRMB .. " during Combat/Dungeon/Raid/AvA",
                    callback = function(comboBox, itemName, item, checked, checkedData)
                        tbug.savedVars.enableMouseRightAndLeftAndSHIFTInspectorDuringCombat = checked
                    end,
                    entryType = LSM_ENTRY_TYPE_CHECKBOX,
                    checked = function() return tbug.savedVars.enableMouseRightAndLeftAndSHIFTInspectorDuringCombat end,
                    enabled = function() return tbug.savedVars.enableMouseRightAndLeftAndSHIFTInspector end,
                    checkboxUpdateGroup = 1,
                },
            }
            AddCustomScrollableSubMenuEntry("Mouse", settingsMouseSubmenu)

            --Choose which font and size the tBug UI list shsould draw with
			local settingsFontSubmenu = {}

            --Get the currently selected template drom SV, or use default template
            local selectedTemplate = tbug_GetTemplate()

			for _, template in ipairs(tbug.UITemplates) do
                local templateData = template
				tins(settingsFontSubmenu, {
					buttonGroup = 2,
					label		= templateData.name,
					entryType	= LSM_ENTRY_TYPE_RADIOBUTTON,
					checked		= function() return templateData.font == tbug.savedVars.customTemplate.font end,
                    callback	= function(comboBox, itemName, item, checked)
                        --We passed in the additionalData table with the templateData to the item and read it from there now
                        selectedTemplate = item.UItemplate
					end,
					buttonGroupOnSelectionChangedCallback = function(control, previousControl)
                        --d("[tbug]buttonGroupOnSelectionChangedCallback")
						setTemplateFont(selectedTemplate)
                        --Refresh the visible inspectors so the font's update, and the table rows update their height
                        refreshVisibleInspectors(true, true)
					end,
                    additionalData = { UItemplate = templateData } --pass in the currrntly looped templateData to the item
				})
			end
            AddCustomScrollableSubMenuEntry("Font & size" , settingsFontSubmenu)
            -- -^-  SETTINGS MENU at GLOBAL INSPECTOR                                                               -^-
        end
        ----------------------------------------------------------------------------------------------------------------
        -- -^-  GLOBAL INSPECTOR only                                                                               -^-
        ----------------------------------------------------------------------------------------------------------------


        AddCustomScrollableMenuEntry("|cFF0000X Close|r", function() selfInspector:release() end, LSM_ENTRY_TYPE_NORMAL, nil, nil, nil, nil, nil)
        --Fix to show the context menu entries above the window, and make them selectable
        if dLayer == DL_OVERLAY then
            setDrawLevel(owner, DL_CONTROLS)
        end
        ShowCustomScrollableMenu(selfCtrl, defaultScrollableContextMenuOptions) --owner

    end --if LibScrollableMenu then
end




--[[
--For debugging
ZO_PreHook("ClearMenu", function()
    d("[ClearMenu]PreHook called")
end)

ZO_PreHook("ClearCustomScrollableMenu", function()
    d("[ClearCustomScrollableMenu]PreHook called")
end)
]]

