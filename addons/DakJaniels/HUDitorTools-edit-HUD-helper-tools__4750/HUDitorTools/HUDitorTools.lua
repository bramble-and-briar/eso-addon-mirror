-- -----------------------------------------------------------------------------
-- HUDitorTools
-- Grid overlay + snap-to-grid for the ZOS HUD Editor (settings in info box)
-- and other features
-- -----------------------------------------------------------------------------

-- Global table
HUDitorTools = {}
local HT = HUDitorTools

-- Addon data
local addonWebsite = "https://www.esoui.com/downloads/info4750"
HT.version = "1.3.0"
HT.name = "HUDitor Tools"
HT.displayName = "|c00FF00HUD|cFFFF00itor|r Tools"
HT.eventName = "HUDitorTools"
HT.author = "@dack_janiels[PC], Baertram[PC]"
HT.addonWebsite = addonWebsite
HT.addonFeedback = addonWebsite .. "#comments"
HT.addonDonation = addonWebsite

local string_format = string.format

local GRID_DEFAULT_COLOR =
{
    r = 0.1,
    g = 0.7,
    b = 0.9,
    a = 0.25,
}

-- Colors: copy ZOS defaults once at load, before we mutate the global table
-- Vanilla fill alphas from EsoUI/Ingame/HUD/keyboard/hudeditor_keyboard.lua:
-- selected/unselected centerNormal = "20RRGGBB", centerHover = "50RRGGBB"
local ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD = ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD
local CENTER_NORMAL_ALPHA = 32 / 255
local CENTER_HOVER_ALPHA = 80 / 255
local defaultSelectedEdge = ZO_ColorDef:New(ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.selected.edge:UnpackRGBA())
local defaultSelectedCenterNormal = ZO_ColorDef:New(ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.selected.centerNormal:UnpackRGBA())
local defaultSelectedCenterHover = ZO_ColorDef:New(ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.selected.centerHover:UnpackRGBA())
local defaultUnselectedEdge = ZO_ColorDef:New(ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.unselected.edge:UnpackRGBA())
local defaultUnselectedCenterNormal = ZO_ColorDef:New(ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.unselected.centerNormal:UnpackRGBA())
local defaultUnselectedCenterHover = ZO_ColorDef:New(ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.unselected.centerHover:UnpackRGBA())
local defaultUnselectedFont = ZO_ColorDef:New(ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.unselected.font:UnpackRGBA())
local defaultSelectedHidden = ZO_ColorDef:New("FF0000")
local defaultUnselectedHidden = ZO_ColorDef:New("F00000")

ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.selectedHidden = ZO_ShallowTableCopy(ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.selected)
ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.unselectedHidden = ZO_ShallowTableCopy(ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.unselected)

local function ColorDefFromTable(colorTable)
    return ZO_ColorDef:New(colorTable.r, colorTable.g, colorTable.b, colorTable.a)
end

local function FillColorDefFromTable(colorTable, fillAlpha)
    return ZO_ColorDef:New(colorTable.r, colorTable.g, colorTable.b, colorTable.a * fillAlpha)
end

local function ApplyColorTableToPalette(palette, colorTable, applyFont)
    palette.edge = ColorDefFromTable(colorTable)
    palette.centerNormal = FillColorDefFromTable(colorTable, CENTER_NORMAL_ALPHA)
    palette.centerHover = FillColorDefFromTable(colorTable, CENTER_HOVER_ALPHA)
    if applyFont then
        palette.font = ColorDefFromTable(colorTable)
    end
end

local function ColorTableFromColorDef(colorDef)
    local r, g, b, a = colorDef:UnpackRGBA()
    return { r = r, g = g, b = b, a = a }
end

ApplyColorTableToPalette(ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.selectedHidden, ColorTableFromColorDef(defaultSelectedHidden), true)
ApplyColorTableToPalette(ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.unselectedHidden, ColorTableFromColorDef(defaultUnselectedHidden), true)

HT.COLOR_SLOT_GRID = "gridColor"
HT.COLOR_SLOT_SELECTED = "selectedEdgeColor"
HT.COLOR_SLOT_UNSELECTED = "unselectedEdgeColor"
HT.COLOR_SLOT_HIDDEN = "HUDEditHiddenBorderColor"

-- SavedVariables
HT.Defaults =
{
    -- HUDEditor Grid
    showGrid                           = false,
    gridSnap                           = false,
    gridSize                           = 15,
    gridColor                          = GRID_DEFAULT_COLOR,

    -- HUDEditor other settings
    HUDEditContextMenu                 = false,
    HUDEditHiddenBorderColor           = { r = 1, g = 0, b = 0, a = 1 },
    selectedEdgeColor                  = ColorTableFromColorDef(defaultSelectedEdge),
    unselectedEdgeColor                = ColorTableFromColorDef(defaultUnselectedEdge),
    showColorPicker                    = false,
    HUDEditorShowInfoBoxSettingsButton = false,
    HUDEditorAlwaysShowAllNames        = false,
    HUDEditorHideNamesShorterThan      = 50,
    HUDEditHiddenControls              = {},

    -- Named HUD layouts (snapshots of HUD_MANAGER.savedVars.profiles[1])
    hudLayoutNextId                    = 1,
    hudLayoutsAccount                  = {},
    hudLayoutsCharacter                = {},
    hudLayoutSelectionByCharacter      = {},
    showChatMessages                   = false,

    elementAppearance                  =
    {
        keyboard = {},
        gamepad = {},
    },
    resourceBarGroup                   =
    {
        enabled = false,
        healthWidth = 474,
        preventExpand = false,
    },
}

-- CHAT_ROUTER:AddSystemMessage (EsoUI/Ingame/ChatSystem/ChatHandlers.lua)
function HT.AddChatSystemMessage(message)
    if not HT.SV or not HT.SV.showChatMessages then
        return
    end
    CHAT_ROUTER:AddSystemMessage(message)
end

-- local vanilla ZOs class and manager object variables
--- CLASSES
-- local HM_Class      = ZO_HUDManager
-- local HME_Class = ZO_HUDManager_Element
local HEK_Class_KB = ZO_HUDEditor_Keyboard
local HEEK_Class_KB = ZO_HUDEditorElement_Keyboard
--- OBJECTS
local WM = GetWindowManager()
local EM = GetEventManager()
local SM = SCENE_MANAGER
-- local HM    = HUD_MANAGER
local HE_KB = HUD_EDITOR_KEYBOARD

-- local reference variables to UI controls
local infoBoxSettingsButton


-- local flags
local rebuildOfHUDEditorNeeded = false
local editorShowing = false
-- hook flags
local HUDEditorElementHooksDone = false
local HEEKOnMouseUpFunctionHooked = false
local HEEKRefreshColorsHooked = false
local HEKDropdownLibScrollableMenuHooked = false
local infoBoxShownAtSceneChangeHookDone = false

-- local strings
--- events and updaters
local addonCallbackOnHideName = HT.eventName .. "_LSM_HUDEditorSettings"
--- translated texts
local onText = GetString(SI_SCREEN_NARRATION_TOGGLE_ON)
local offText = GetString(SI_SCREEN_NARRATION_TOGGLE_OFF)
local HUDEditorContextMenuText = GetString(SI_GAME_MENU_EDIT_HUD)
local visibleText = GetString(SI_HUD_EDITOR_CUSTOM_OPTION_VISIBLE)
local resetToDefaultText = GetString(SI_HUD_EDITOR_INFO_BOX_RESET_TO_DEFAULT)


-- Libraries
--- LibScrollableMenu
local LSM = LibScrollableMenu
local LSM_UPDATE_MODE_MAINMENU = LSM_UPDATE_MODE_MAINMENU
local LSM_UPDATE_MODE_SUBMENU = LSM_UPDATE_MODE_SUBMENU
local LSM_UPDATE_MODE_BOTH = LSM_UPDATE_MODE_BOTH
local LSM_ENTRY_TYPE_NORMAL = LSM_ENTRY_TYPE_NORMAL
local LSM_ENTRY_TYPE_CHECKBOX = LSM_ENTRY_TYPE_CHECKBOX
local LSM_ENTRY_TYPE_BUTTON = LSM_ENTRY_TYPE_BUTTON
local LSM_ENTRY_TYPE_DIVIDER = LSM_ENTRY_TYPE_DIVIDER
local addCustomScrollableComboBoxDropdownMenu = AddCustomScrollableComboBoxDropdownMenu
local clearCustomScrollableMenu = ClearCustomScrollableMenu
local addCustomScrollableMenuEntry = AddCustomScrollableMenuEntry
local addCustomScrollableSubMenuEntry = AddCustomScrollableSubMenuEntry
local addCustomScrollableMenuCheckbox = AddCustomScrollableMenuCheckbox
local addCustomScrollableMenuHeader = AddCustomScrollableMenuHeader
local addCustomScrollableMenuSlider = AddCustomScrollableMenuSlider
local showCustomScrollableMenu = ShowCustomScrollableMenu
local sortCustomScrollableMenu = SortCustomScrollableMenu
local refreshCustomScrollableMenu = RefreshCustomScrollableMenu
local runCustomScrollableMenuItemsCallback = RunCustomScrollableMenuItemsCallback
local getCustomScrollableMenuCtrlsInfo = GetCustomScrollableMenuCtrlsInfo
local getValueOrCallback = LSM.Util.getValueOrCallback


------------------------------------------------------------------------------------------------------------------------
--- Local helper functions
------------------------------------------------------------------------------------------------------------------------
local function colorizeString(r, g, b, string)
    if ZO_ColorizeString then return ZO_ColorizeString(r, g, b, string) end -- sometimes this is nil all of sudden?
    return string.format("|c%.2x%.2x%.2x%s|r", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), string)
end


local function getElementObject(elementCtrl)
    return elementCtrl and elementCtrl.object or nil
end
local function getElementData(elementCtrl, elementObject)
    if not elementCtrl and not elementObject then return end
    elementObject = elementObject or getElementObject(elementCtrl)
    return (elementObject and elementObject:GetElementData()) or nil
end

local function getElementDisplayName(elementCtrl, elementObject)
    if not elementCtrl and not elementObject then return "n/a" end
    elementObject = elementObject or getElementObject(elementCtrl)
    local elementData = getElementData(elementCtrl, elementObject)
    if not elementData then return "n/a" end
    return elementData:GetDisplayName()
end

-- Get the saveKey used for saving the element's SavedVariables entry, or use the TLC's name
local function getElementRealTLCName(elementCtrl, elementObject)
    if not elementCtrl and not elementObject then return nil, nil, nil end
    elementObject = elementObject or getElementObject(elementCtrl)
    local elementData = getElementData(elementCtrl, elementObject)
    if elementData == nil or elementObject == nil then return nil, nil, nil end
    local TLCName = ((elementData:GetSaveKey()) or (elementData.control and elementData.control.GetName and elementData.control:GetName())) or nil
    return TLCName, elementObject, elementData
end

local parentsOnEffectivelyShownHooked = {}
local function addButton(myAnchorPoint, relativeTo, relativePoint, offsetX, offsetY, buttonData)
    if not buttonData or not buttonData.parentControl or not buttonData.buttonName or not buttonData.callback then return end
    local button
    -- Does the button already exist?
    local parent = buttonData.parentControl
    local btnName = parent:GetName() .. "_" .. HT.eventName .. "_" .. buttonData.buttonName
    button = WM:GetControlByName(btnName, "")
    if button == nil then
        -- Create the button control at the parent
        button = WM:CreateControl(btnName, buttonData.parentControl, CT_BUTTON)
    end
    -- Button was created?
    if button ~= nil then
        -- d(">button created")
        -- Set the button's size
        button:SetDimensions(buttonData.width or 32, buttonData.height or 32)

        -- SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY)
        button:SetAnchor(myAnchorPoint, relativeTo, relativePoint, offsetX, offsetY)

        -- Textures
        if buttonData.normal then
            button:SetNormalTexture(buttonData.normal)
        end
        if buttonData.pressed then
            button:SetPressedTexture(buttonData.pressed)
        end
        if buttonData.highlight then
            button:SetMouseOverTexture(buttonData.highlight)
        end
        if buttonData.disabled then
            button:SetDisabledTexture(buttonData.disabled)
        end

        button.tooltipText = buttonData.tooltip
        button.tooltipAlign = TOP
        button:SetHandler("OnMouseEnter", function (self)
            ZO_Tooltips_ShowTextTooltip(self, self.tooltipAlign, self.tooltipText)
        end)
        button:SetHandler("OnMouseExit", function (self)
            ZO_Tooltips_HideTextTooltip()
        end)
        -- Set the callback function of the button
        button:SetHandler("OnClicked", function (...)
            buttonData.callback(...)
        end)

        local isHidden = false
        local buttonVisibleType = type(buttonData.visible)
        if buttonVisibleType ~= nil then
            if buttonVisibleType == "function" then
                isHidden = not buttonData.visible()

                if not parentsOnEffectivelyShownHooked[parent] then
                    ZO_PostHookHandler(parent, "OnEffectivelyShown", function ()
                        button:SetHidden(not buttonData.visible())
                    end)
                    parentsOnEffectivelyShownHooked[parent] = true
                end
            elseif buttonVisibleType == "boolean" then
                isHidden = buttonData.visible
            end
        end
        -- Show the button and make it react on mouse input
        button:SetHidden(isHidden)
        button:SetMouseEnabled(true)

        -- Return the button control
        return button
    end
end

------------------------------------------------------------------------------------------------------------------------
--- HUD Grid Snap
------------------------------------------------------------------------------------------------------------------------
function HT.IsEditorShowing()
    return editorShowing
end

local function SnapControlTopLeft(control)
    local sv = HT.SV
    if not sv.gridSnap then
        return
    end
    local left, top = zo_round(control:GetLeft()), zo_round(control:GetTop())
    left, top = HT.ApplySnap(left, top, sv.gridSize)
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
end


------------------------------------------------------------------------------------------------------------------------
--- HUD Editor Other features
------------------------------------------------------------------------------------------------------------------------
local function getHUDElementHiddenState(elementName)
    return (elementName ~= nil and elementName ~= "" and HT.SV.HUDEditHiddenControls[elementName]) or nil
end

local function getNumHUDEditorElementsHidden()
    return NonContiguousCount(HT.SV.HUDEditHiddenControls)
end


local function isAnyHUDEditorElementHidden()
    return getNumHUDEditorElementsHidden() > 0
end

local function getElementControlByName(hiddenHUDElement)
    for _, element in ipairs(HE_KB.elementControls) do
        local elementData = getElementData(element)
        if elementData then
            if elementData:GetSaveKey() == hiddenHUDElement or (elementData.control and elementData.control.GetName and elementData.control:GetName() == hiddenHUDElement) then
                return element
            end
        end
    end
end

local function setHUDElementHiddenState(elementName, newState, elementCtrl)
    if elementName == nil or elementName == "" then return end
    if newState == false then newState = nil end
    HT.SV.HUDEditHiddenControls[elementName] = newState

    --- >todo: 20260810 Attention this will also change the HUD editor popup dialog "Visible" setting and might change the SavedVariables
    -- of ZOs vanilla ZO_Ingame_SavedVariables -> $AccountWide -> ZO_HUDManager too!
    -- > Reason: The IsHidden function maybe returning the default value for the Visible customOptions! So opening the HUD editor for that element
    -- > after using the contextMenu to hide the control, might switch the SVs for that control to "Visible" -> False :-(

    -- > Workaround idea: PreHook into ZO_HUDEditor_Keyboard:ApplyInfoBoxValues(overrideElement), check if "selectedElement" is in the table
    -- > HT.SV.HUDEditHiddenControls[elementCtrl] and skip customOptions update for "Visible" state then
    if elementCtrl then
        elementCtrl:SetHidden(newState)
    end

    return true
end

local function showHiddenHUDElementAgain(hiddenHUDElement, elementCtrl)
    setHUDElementHiddenState(hiddenHUDElement, false, elementCtrl)
end

local function hideElementUIInHUDOrEditor(elementCtrl, hideInHUDEditor)
    -- d("[HT]hideElementUIInHUDEditor - hideInHUDEditor: " ..tostring(hideInHUDEditor))
    if not elementCtrl or hideInHUDEditor == nil then return end
    if hideInHUDEditor == false then hideInHUDEditor = nil end
    local elementName = getElementRealTLCName(elementCtrl, nil)
    if setHUDElementHiddenState(elementName, hideInHUDEditor, elementCtrl) == true then
        HT.AddChatSystemMessage("[HT]HUD Editor element '" .. tostring((hideInHUDEditor == true and SCENE_HIDDEN) or SCENE_SHOWN) .. "': '" .. tostring(getElementDisplayName(elementCtrl) .. "' - " .. tostring(elementName)))
        return true
    end
end

local function updateHUDEditorElementHiddenState(elementCtrl)
    -- local elementObject = elementCtrl.object
    if elementCtrl ~= nil then
        local elementName = getElementRealTLCName(elementCtrl, nil)
        if HT.SV.HUDEditContextMenu == true then
            local HUDEditorUserChosenHiddenState = getHUDElementHiddenState(elementName)
            if HUDEditorUserChosenHiddenState == true then
                -- Hide the elementCtrl now
                elementCtrl:SetHidden(true)
                return true
                -- else do nothing as it is automatically shown
            end
        else
            -- Show the element now
            elementCtrl:SetHidden(false)
        end
    end
end

local function isHUDEditorElementUserHidden(elementObject)
    local optionsDataOfKeyVisible = elementObject:GetCustomOptionValue("Visible")
    if optionsDataOfKeyVisible == nil then
        return false
    end
    local typeOfVisibleOption = type(optionsDataOfKeyVisible)
    if typeOfVisibleOption == "boolean" then
        return optionsDataOfKeyVisible == false
    elseif typeOfVisibleOption == "number" then
        return optionsDataOfKeyVisible == 0
    end
    return false
end

local function getHUDEditorElementColorPalette(elementObject)
    if isHUDEditorElementUserHidden(elementObject) then
        if elementObject.selected then
            return ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.selectedHidden
        end
        return ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.unselectedHidden
    end
    if elementObject.selected then
        return ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.selected
    end
    return ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.unselected
end

local function applyHUDEditorElementColors(elementObject, palette)
    if palette == nil then
        return
    end
    local control = elementObject.control
    control:SetEdgeColor(palette.edge:UnpackRGBA())
    if elementObject.mouseOver then
        control:SetCenterColor(palette.centerHover:UnpackRGBA())
    else
        control:SetCenterColor(palette.centerNormal:UnpackRGBA())
    end
    elementObject.nameControl:SetColor(palette.font:UnpackRGBA())
end

local function updateHUDEditorElementBorderColor(elementObject)
    if elementObject == nil or elementObject.elementData == nil then return end
    -- Vanilla RefreshColors is not called from PopulateElementControls except on the selected
    -- element, so overlays keep XML cyan (edgeColor/centerColor 02E1FF) until we paint them.
    applyHUDEditorElementColors(elementObject, getHUDEditorElementColorPalette(elementObject))

    -- Check if the name should always be shown, or hidden due to the nameControl's width
    local settings = HT.SV
    local nameControl = elementObject.nameControl
    local nameControlWidth = nameControl:GetWidth()
    local alwaysShowAllNames = settings.HUDEditorAlwaysShowAllNames
    local hideNamesShorterThan = settings.HUDEditorHideNamesShorterThan
    local useCustomNameSettings = settings.HUDEditorShowInfoBoxSettingsButton == true
    local hideDueToWidth
    if useCustomNameSettings then
        hideDueToWidth = hideNamesShorterThan > 0 and nameControlWidth <= hideNamesShorterThan
    else
        hideDueToWidth = nameControlWidth <= 50
    end

    local hideElementName
    if useCustomNameSettings then
        if elementObject.mouseOver or elementObject.selected then
            -- Keep the active/hovered name readable while editing
            hideElementName = false
        elseif alwaysShowAllNames then
            hideElementName = hideDueToWidth
        else
            hideElementName = true
        end
    else
        if alwaysShowAllNames then
            hideElementName = false
        elseif elementObject.mouseOver then
            hideElementName = hideDueToWidth
        else
            hideElementName = hideDueToWidth or not elementObject.selected
        end
    end
    nameControl:SetHidden(hideElementName)
end



local function myIsCheckedAnyCheckboxInTheSubmenuCallback(p_comboBox, p_item, entriesFound)
    for k, v in ipairs(entriesFound) do
        -- d("found cbox: " .. tostring(v.label or v.name) .. "; checked = " ..tostring(v.checked))
        if v.checked == true then return true end
    end
    return false
end
local function myCallbackUnhideElementsNamedInSubmenuSame(p_comboBox, p_item, entriesFound)
    local wasAnyEntyDeleted = false
    -- Loop at entriesFound, get it's .data.dataSource etc. and check SavedVariables etc.
    for k, v in ipairs(entriesFound) do
        local name = v.label or v.name
        -- d("[HT]name of entry: " .. tostring(name).. ", checked: " .. tostring(v.checked))
        if v.checked and v.element ~= nil and v.elementCtrl ~= nil then
            -- showHiddenHUDElementAgain(v.element, v.elementCtrl)
            local wasAnyEntyDeletedLoop = hideElementUIInHUDOrEditor(v.elementCtrl, false)
            if not wasAnyEntyDeleted and wasAnyEntyDeletedLoop == true then wasAnyEntyDeleted = true end
        end
    end
    if wasAnyEntyDeleted == true then
        refreshCustomScrollableMenu(p_item, LSM_UPDATE_MODE_SUBMENU, p_comboBox)
    end
end

local function checkIfInfoBoxLSMDropdownVisibleAndUpdateLSM(comboBox, ctrl)
    -- Wait for the current LSM contextMenu to close first, then
    zo_callLater(function ()
                     local infoBoxSelector = HE_KB.infoBoxSelector
                     if not infoBoxSelector or infoBoxSelector:IsHidden() then return end
                     local LSMComboBox = infoBoxSelector.m_comboBox or comboBox
                     if LSMComboBox and ctrl then
                         if LSMComboBox:IsDropdownVisible() == true then
                             -- refresh the LSM there now
                             refreshCustomScrollableMenu(ctrl, LSM_UPDATE_MODE_MAINMENU, LSMComboBox)
                         end
                     end
                 end, 0)
end

local showHUDElementContextMenu
local function buildHiddenHUDElementLSMSubmenuEntry(hiddenHUDElement, elementCtrl, retTab, control)
    if #retTab == 0 then
        retTab[1] =
        {
            label = GetString(SI_HUDITORTOOLS_CNTXT_ELEMENT_UNHIDE),
            entryType = LSM_ENTRY_TYPE_BUTTON,
            callback = function (comboBox, itemName, item, checked, data)
                -- Use LSM API func to get the same submenu's checkboxes
                runCustomScrollableMenuItemsCallback(comboBox, item, myCallbackUnhideElementsNamedInSubmenuSame, { LSM_ENTRY_TYPE_CHECKBOX }, false)
                -- refreshCustomScrollableMenu(moc(), LSM_UPDATE_MODE_BOTH, comboBox) --does not refresh the submenu, why not? Removed entries should be removed from the submenu too!
                -- Workaround: Rebuild the total menu and show it new
                clearCustomScrollableMenu() -- closes the contextMenu
                checkIfInfoBoxLSMDropdownVisibleAndUpdateLSM(comboBox, control)
            end,
            sortPosition = 1,
            doNotFilter = true,
            enabled = function (comboBox, data)
                -- Enabled state based on if any checkbox in the same submenu is checked
                if comboBox == nil or data == nil then
                    comboBox, data = getCustomScrollableMenuCtrlsInfo(moc(), nil)
                end
                local foundItems, callbackFuncResult = runCustomScrollableMenuItemsCallback(comboBox, data, myIsCheckedAnyCheckboxInTheSubmenuCallback, { LSM_ENTRY_TYPE_CHECKBOX }, false)
                return foundItems and callbackFuncResult
            end,
        }
        retTab[2] =
        {
            label = "-",
            entryType = LSM_ENTRY_TYPE_DIVIDER,
            sortPosition = 2,
            doNotFilter = true,
        }
    end
    retTab[#retTab + 1] =
    {
        label = getElementDisplayName(elementCtrl),
        entryType = LSM_ENTRY_TYPE_CHECKBOX,
        checked = false,
        callback = function (comboBox, itemName, item, checked, data)
            refreshCustomScrollableMenu(moc(), LSM_UPDATE_MODE_SUBMENU, comboBox)
        end,
        additionalData =
        {
            element = hiddenHUDElement,
            elementCtrl = elementCtrl,
        },
        buttonGroup = 1,
        contextMenuCallback = function (comboBox, control, data)
            LSM.ButtonGroupDefaultContextMenu(comboBox, control, data, true) -- use ZO_Menu contextMenu!
        end,
    }
end

local function hiddenHUDEditorElementsIteratorFunc(callbackFunc, retTab, sortFunc, control)
    local hiddenHUDElements = HT.SV.HUDEditHiddenControls
    if type(callbackFunc) ~= "function" or not isAnyHUDEditorElementHidden() then return end

    for hiddenHUDElement, isHidden in pairs(hiddenHUDElements) do
        local elementCtrl = getElementControlByName(hiddenHUDElement)
        callbackFunc(hiddenHUDElement, elementCtrl, retTab, control)
    end

    -- Table sorting at the end was requested?
    if not ZO_IsTableEmpty(retTab) and type(sortFunc) == "function" then
        return sortFunc(retTab)
    end
    return retTab
end

local function showAllHiddenHUDEditorElementsAgain(comboBox, control)
    hiddenHUDEditorElementsIteratorFunc(showHiddenHUDElementAgain)
    checkIfInfoBoxLSMDropdownVisibleAndUpdateLSM(comboBox, control)
end

local function buildHiddenHUDElementLSMSubmenu(retTab, sortFunc, control)
    return hiddenHUDEditorElementsIteratorFunc(buildHiddenHUDElementLSMSubmenuEntry, retTab, sortFunc, control)
end

--[[
local function getCustomOptionsByKey(elementObject, keyName)
    if not elementObject then return end
    local options = elementObject:GetCustomOptions()
    if ZO_IsTableEmpty(options) then return end
    for _, optionData in ipairs(options) do
        if optionData.key == keyName then
            return optionData
        end
    end
    return nil
end
]]
local function buildHUDElementUserHiddenContextMenuSubmenu(control)
    if isAnyHUDEditorElementHidden() then
        addCustomScrollableMenuHeader(string_format(GetString(SI_HUDITORTOOLS_CNTXT_HIDDEN_ELEMENTS_COUNT), tostring(getNumHUDEditorElementsHidden())))
        local userHiddenHUDElementsTab = buildHiddenHUDElementLSMSubmenu({}, sortCustomScrollableMenu, control)
        addCustomScrollableSubMenuEntry(GetString(SI_HUDITORTOOLS_CNTXT_HIDDEN_ELEMENTS), userHiddenHUDElementsTab)
        addCustomScrollableMenuEntry(GetString(SI_HUDITORTOOLS_CNTXT_SHOW_ALL_HIDDEN), function (comboBox, itemName, item, selectionChanged, oldItem)
                                         showAllHiddenHUDEditorElementsAgain(comboBox, control)
                                     end, LSM_ENTRY_TYPE_NORMAL
        )
    end
end

function showHUDElementContextMenu(elementCtrl)
    clearCustomScrollableMenu()

    local elementName, elementObject, elementData = getElementRealTLCName(elementCtrl, nil)
    if not elementObject or not elementData then return end

    -- Does not work as element will not be selected via right click with the mouse, only left click as InfoBox dialog opens!
    -- local selectedElement = HUD_EDITOR_KEYBOARD:GetSelectedElement()
    -- if not selectedElement then return end
    --[[
    local optionsDataOfKeyVisible = getCustomOptionsByKey(elementObject, "Visible")
    if optionsDataOfKeyVisible ~= nil then
        visibleText = optionsDataOfKeyVisible.name
    end
    ]]

    -- Hide control in HUD editor (not on real HUD!)
    addCustomScrollableMenuHeader(HUDEditorContextMenuText .. " - " .. elementName)
    local isCurrentlyHiddenInHUDEditor = getHUDElementHiddenState(elementName)
    -- d(">isHiddenInHUDEditor: " ..tostring(isHCurrentlyHiddenInHUDEditor))
    addCustomScrollableMenuEntry(visibleText .. ": " .. ((isCurrentlyHiddenInHUDEditor and onText) or offText),
                                 function () hideElementUIInHUDOrEditor(elementCtrl, not isCurrentlyHiddenInHUDEditor) end, LSM_ENTRY_TYPE_NORMAL)

    addCustomScrollableMenuEntry(resetToDefaultText, function ()
                                     elementCtrl.object:Select()
                                     HE_KB:ResetSelectedToDefault()
                                 end, LSM_ENTRY_TYPE_NORMAL)

    buildHUDElementUserHiddenContextMenuSubmenu(elementCtrl)

    showCustomScrollableMenu()
end

local function onMouseUpShowContextMenuAtHUDEditElementHandler(elementCtrl, button, upInside)
    -- d("[HT]HUDElement_OnMouseUpHook - button: " ..tostring(button) .. ", upInside: " ..tostring(upInside))
    if button == MOUSE_BUTTON_INDEX_RIGHT and upInside then
        showHUDElementContextMenu(elementCtrl)
    end
end

local function getHUDEditorInfoBoxSettingsContextMenu()
    clearCustomScrollableMenu()
    addCustomScrollableMenuHeader(GetString(SI_HUDITORTOOLS_HUD_EDITOR_LAM_HEADER))
    addCustomScrollableMenuCheckbox(GetString(SI_HUDITORTOOLS_CNTXT_SHOW_ALL_ELEMENTS),
                                    function (comboBox, itemName, item, checked, data)
                                        HT.SV.HUDEditorAlwaysShowAllNames = checked
                                        HE_KB:RebuildAllElements()
                                        rebuildOfHUDEditorNeeded = false
                                    end,
                                    function () return HT.SV.HUDEditorAlwaysShowAllNames end, { tooltip = GetString(SI_HUDITORTOOLS_CNTXT_SHOW_ALL_ELEMENTS_TT) }
    )
    local sliderDataHideNamesShortherThan =
    {
        hideLabel = false,                                                  -- optional boolean or function returning a boolean Hide the label at the row
        -- labelWidth = "60%",							-- optional string/number or function returning a string/number	Width of the label at the row
        value = function () return HT.SV.HUDEditorHideNamesShorterThan end, -- optional number or function returning a number Value of the slider (e.g. from SavedVariables)
        min = 0,                                                            -- optional number or function returning a number Minimum value of the slider (e.g. from SavedVariables)
        max = 1000,                                                         -- optional number or function returning a number Maximum value of the slider (e.g. from SavedVariables)
        step = 1,                                                           -- optional number or function returning a number The step of the slider (e.g. from SavedVariables)
        showValueLabel = true,                                              -- optional boolean or function returning a boolean Show the value label at the row, right side of the slider
        valueLabelFont = "ZoFontWinT2",                                     -- optional string or function returning a string The font of the value label
        -- hideValueTooltip = true,					-- optional boolean or function returning a boolean Hide the tooltip showing the actual value, min, max and tooltip of the row at the slider
        width = "60%",                                                      -- optional string/number or function returning a string/number The width of the slider
        -- contextMenuCallback = function(comboBox, p_sliderCtrl, data) end,	-- optional function to open a contextMenu at the slider (if right clicked)
    }
    local specialCallbackData =
    { -- upon close of the LSM contextMenu update the shown element names, based on the slider's maxWidth value
        addonName = addonCallbackOnHideName,
        onHideCallback = function (comboBox, openingControl, specialCallbackData)
            -- d("[FCOCS]onHideCallback")
            if rebuildOfHUDEditorNeeded == true then
                if specialCallbackData and specialCallbackData.checkFunc then
                    if specialCallbackData.checkFunc(comboBox, openingControl, specialCallbackData) == true then
                        HE_KB:RebuildAllElements()
                    end
                end
            end
            rebuildOfHUDEditorNeeded = false
            LSM.Util.getContextMenuReference():UnregisterSpecialCallback(addonCallbackOnHideName, "onHideCallback")
        end,
        checkFunc = function (comboBox, openingControl, specialCallbackData)
            return not ZO_HUDEditor_Keyboard_TLInfoBox:IsHidden() and openingControl == infoBoxSettingsButton
        end,
    }
    addCustomScrollableMenuSlider(GetString(SI_HUDITORTOOLS_CNTXT_HIDE_ELEMENTS_LESS_LENGTH),
                                  function (comboBox, slider, value)
                                      HT.SV.HUDEditorHideNamesShorterThan = value
                                      rebuildOfHUDEditorNeeded = true
                                  end, sliderDataHideNamesShortherThan, { tooltip = GetString(SI_HUDITORTOOLS_CNTXT_HIDE_ELEMENTS_LESS_LENGTH_TT) }
    )
    if isAnyHUDEditorElementHidden() then
        addCustomScrollableMenuHeader(string_format(GetString(SI_HUDITORTOOLS_CNTXT_HIDDEN_ELEMENTS_COUNT), tostring(getNumHUDEditorElementsHidden())))
        addCustomScrollableMenuEntry(GetString(SI_HUDITORTOOLS_CNTXT_SHOW_ALL_HIDDEN_ELEMENTS), function (comboBox, itemName, item, selectionChanged, oldItem)
                                         showAllHiddenHUDEditorElementsAgain(comboBox, nil)
                                     end, LSM_ENTRY_TYPE_NORMAL)
    end

    --Grid
    addCustomScrollableMenuHeader(GetString(SI_HUDITORTOOLS_GRID_LAM_HEADER))
    addCustomScrollableMenuCheckbox(GetString(SI_HUDITORTOOLS_HUD_EDITOR_GRID_LAM),
                                    function (comboBox, itemName, item, checked, data)
                                        HT.SV.showGrid = checked
                                        refreshCustomScrollableMenu(moc(), LSM_UPDATE_MODE_BOTH, comboBox)
                                        HT.RefreshGridOverlay()
                                    end,
                                    function () return HT.SV.showGrid end, { tooltip = GetString(SI_HUDITORTOOLS_HUD_EDITOR_GRID_LAM_TT) }
    )
    addCustomScrollableMenuCheckbox(GetString(SI_HUDITORTOOLS_HUD_EDITOR_GRID_SNAP_LAM),
                                    function (comboBox, itemName, item, checked, data)
                                        refreshCustomScrollableMenu(moc(), LSM_UPDATE_MODE_BOTH, comboBox)
                                        HT.SV.gridSnap = checked
                                    end,
                                    function () return HT.SV.gridSnap end,
                                    {
                                        tooltip = GetString(SI_HUDITORTOOLS_HUD_EDITOR_GRID_SNAP_LAM_TT),
                                        enabled = function () return HT.SV.showGrid end
                                    }
    )
    local sliderDataGridSize =
    {
        hideLabel = false,                             -- optional boolean or function returning a boolean Hide the label at the row
        -- labelWidth = "60%",							-- optional string/number or function returning a string/number	Width of the label at the row
        value = function () return HT.SV.gridSize end, -- optional number or function returning a number Value of the slider (e.g. from SavedVariables)
        min = 2,                                       -- optional number or function returning a number Minimum value of the slider (e.g. from SavedVariables)
        max = 100,                                     -- optional number or function returning a number Maximum value of the slider (e.g. from SavedVariables)
        step = 1,                                      -- optional number or function returning a number The step of the slider (e.g. from SavedVariables)
        showValueLabel = true,                         -- optional boolean or function returning a boolean Show the value label at the row, right side of the slider
        valueLabelFont = "ZoFontWinT2",                -- optional string or function returning a string The font of the value label
        -- hideValueTooltip = true,					-- optional boolean or function returning a boolean Hide the tooltip showing the actual value, min, max and tooltip of the row at the slider
        width = "60%",                                 -- optional string/number or function returning a string/number The width of the slider
        -- contextMenuCallback = function(comboBox, p_sliderCtrl, data) end,	-- optional function to open a contextMenu at the slider (if right clicked)
    }
    addCustomScrollableMenuSlider(GetString(SI_HUDITORTOOLS_HUD_EDITOR_GRID_SIZE_LAM),
                                  function (comboBox, slider, value)
                                      HT.SV.gridSize = value
                                      HT.RefreshGridOverlayDebounced()
                                  end, sliderDataGridSize,
                                  {
                                      tooltip = GetString(SI_HUDITORTOOLS_HUD_EDITOR_GRID_SIZE_LAM_TT),
                                      enabled = function () return HT.SV.showGrid end
                                  }
    )

    --Colors
    addCustomScrollableMenuHeader(GetString(SI_HUDITORTOOLS_CNTXT_COLORS))
    addCustomScrollableMenuCheckbox(GetString(SI_HUDITORTOOLS_CNTXT_SHOW_COLOR_PICKER),
            function (comboBox, itemName, item, checked, data)
                HT.SetColorPickerVisible(checked)
                refreshCustomScrollableMenu(moc(), LSM_UPDATE_MODE_BOTH, comboBox)
            end,
            function () return HT.SV.showColorPicker end,
            { tooltip = GetString(SI_HUDITORTOOLS_CNTXT_SHOW_COLOR_PICKER_TT) }
    )
    local colorSlotSubmenu =
    {
        {
            name = GetString(SI_HUDITORTOOLS_COLOR_GRID),
            callback = function ()
                HT.ShowColorPickerForSlot(HT.COLOR_SLOT_GRID)
            end,
            entryType = LSM_ENTRY_TYPE_NORMAL,
        },
        {
            name = GetString(SI_HUDITORTOOLS_COLOR_SELECTED),
            callback = function ()
                HT.ShowColorPickerForSlot(HT.COLOR_SLOT_SELECTED)
            end,
            entryType = LSM_ENTRY_TYPE_NORMAL,
        },
        {
            name = GetString(SI_HUDITORTOOLS_COLOR_UNSELECTED),
            callback = function ()
                HT.ShowColorPickerForSlot(HT.COLOR_SLOT_UNSELECTED)
            end,
            entryType = LSM_ENTRY_TYPE_NORMAL,
        },
        {
            name = GetString(SI_HUDITORTOOLS_COLOR_HIDDEN),
            callback = function ()
                HT.ShowColorPickerForSlot(HT.COLOR_SLOT_HIDDEN)
            end,
            entryType = LSM_ENTRY_TYPE_NORMAL,
        },
    }
    addCustomScrollableSubMenuEntry(GetString(SI_HUDITORTOOLS_CNTXT_COLORS), colorSlotSubmenu)

    --Layouts
    addCustomScrollableMenuHeader(GetString(SI_HUDITORTOOLS_LAYOUTS))
    addCustomScrollableMenuEntry(GetString(SI_HUDITORTOOLS_LAYOUT_SAVE), function()
                                     HT.SaveActiveLayout()
                                 end, LSM_ENTRY_TYPE_NORMAL, nil, {
                                     tooltip = GetString(SI_HUDITORTOOLS_LAYOUT_SAVE_TOOLTIP),
                                     enabled = function()
                                         return HT.IsLiveLayoutDirty()
                                     end,
                                 })
    addCustomScrollableMenuEntry(GetString(SI_HUDITORTOOLS_LAYOUT_NEW), function()
                                     HT.ShowLayoutNameDialog("new")
                                 end, LSM_ENTRY_TYPE_NORMAL, nil, {
                                     tooltip = GetString(SI_HUDITORTOOLS_LAYOUT_NEW_TOOLTIP),
                                 })
    addCustomScrollableMenuEntry(GetString(SI_HUDITORTOOLS_LAYOUT_IMPORT), function()
                                     HT.ShowLayoutImportDialog()
                                 end, LSM_ENTRY_TYPE_NORMAL, nil, {
                                     tooltip = GetString(SI_HUDITORTOOLS_LAYOUT_IMPORT_TOOLTIP),
                                 })
    addCustomScrollableMenuEntry(GetString(SI_HUDITORTOOLS_LAYOUT_EXPORT), function()
                                     HT.ShowLayoutExportDialog()
                                 end, LSM_ENTRY_TYPE_NORMAL, nil, {
                                     tooltip = GetString(SI_HUDITORTOOLS_LAYOUT_EXPORT_TOOLTIP),
                                 })
    addCustomScrollableMenuEntry(GetString(SI_HUDITORTOOLS_LAYOUT_RENAME), function()
                                     HT.ShowLayoutNameDialog("rename")
                                 end, LSM_ENTRY_TYPE_NORMAL)
    addCustomScrollableMenuEntry(GetString(SI_HUDITORTOOLS_LAYOUT_DELETE), function()
                                     HT.ShowLayoutDeleteConfirmation()
                                 end, LSM_ENTRY_TYPE_NORMAL, nil, {
                                     enabled = function()
                                         return HT.CountAllLayoutsForCharacter() > 1
                                     end,
                                 })
    -----------------------------------------------------------------------------------------
    --Show the LSM menu now
    showCustomScrollableMenu(nil, { minDropdownWidth = 325, visibleRowsDropdown = 25 }, specialCallbackData)
end

local buttonDataHUDEditInfoBoxSettings =
{
    buttonName    = "HUDEditInfoBoxSettingsContextMenu",
    parentControl = HE_KB.infoBox,
    tooltip       = HT.displayName .. " - Settings",
    callback      = function ()
        return getHUDEditorInfoBoxSettingsContextMenu()
    end,
    width         = 32,
    height        = 32,
    normal        = "/esoui/art/chatwindow/chat_options_up.dds",
    pressed       = "/esoui/art/chatwindow/chat_options_down.dds",
    highlight     = "/esoui/art/chatwindow/chat_options_over.dds",
    disabled      = "/esoui/art/chatwindow/chat_options_disabled.dds",
    visible       = function () return HT.SV.HUDEditorShowInfoBoxSettingsButton end
}


------------------------------------------------------------------------------------------------------------------------
--- HUD Editor hooks
------------------------------------------------------------------------------------------------------------------------
local function InstallEditorHooks(fromSceneChange)
    local sv = HT.SV

    ----------------------------
    -- ContextMenu button for settings, top left at the InfoBox
    if fromSceneChange == true and not infoBoxShownAtSceneChangeHookDone then
        if buttonDataHUDEditInfoBoxSettings.parentControl == nil then
            buttonDataHUDEditInfoBoxSettings.parentControl = HE_KB.infoBox
        end

        ZO_PostHookHandler(buttonDataHUDEditInfoBoxSettings.parentControl, "OnEffectivelyShown", function ()
            if not sv.HUDEditorShowInfoBoxSettingsButton then return end
            if infoBoxSettingsButton == nil then
                infoBoxSettingsButton = addButton(TOPLEFT, buttonDataHUDEditInfoBoxSettings.parentControl, TOPLEFT, 5, 5, buttonDataHUDEditInfoBoxSettings)
                infoBoxSettingsButton.type = "settings"
            end
            if infoBoxSettingsButton then
                infoBoxSettingsButton:SetDrawTier(DT_HIGH)
                infoBoxSettingsButton:SetDrawLayer(DL_CONTROLS)
                infoBoxSettingsButton:SetDrawLevel(ZO_HUD_EDITOR_KEYBOARD_INFO_BOX_INTERACTABLE_ELEMENT_LEVEL)
            end
        end)
        infoBoxShownAtSceneChangeHookDone = true
    end


    ----------------------------
    -- LibScrollableMenu usage at InfoBox
    if not HEKDropdownLibScrollableMenuHooked then
        local function customFilterFunc(p_item, p_filterString)
            -- local name = p_item.label or p_item.name
            -- local nameStr = getValueOrCallback(name)
            local tooltip = p_item.tooltip
            local tooltipStr = getValueOrCallback(tooltip)
            if -- (nameStr ~= nil and zo_strlower(nameStr):find(p_filterString) ~= nil) or --tooltip contains the name already
            (tooltipStr ~= nil and zo_strlower(tooltipStr):find(p_filterString) ~= nil) then
                return true
            end
            return false
        end

        -- Add LibScrollableMenu to existing "HUD Edit InfoBox" dropdown, to enable the search editBox header
        -- HEK_KB.infoBoxSelectorDropdown -> ZO_ComboBox_ObjectFromContainer(HEK.infoBoxSelector)
        local options = { enableFilter = true, headerCollapsible = true, visibleRowsDropdown = 15, automaticRefresh = true, customFilterFunc = customFilterFunc }
        addCustomScrollableComboBoxDropdownMenu(HE_KB.infoBox, HE_KB.infoBoxSelector, options)
        HEKDropdownLibScrollableMenuHooked = true

        -- The function to add the entries to the dropdown, in vanilla, is: ZO_HUDEditor_Keyboard:RefreshInfoBox()
        -- > Hook into it to color hidden HUDEditor controls red (and add a [ ] around them, for visually impaired players)
        local function OnElementSelectorDropdownEntryMouseEnter(control)
            control.m_data.object:OnMouseEnter()
        end

        local function OnElementSelectorDropdownEntryMouseExit(control)
            control.m_data.object:OnMouseExit()
        end

        local contextMenuCallbackFunc = function (comboBox, control, data)
            clearCustomScrollableMenu()
            -- Get currently clicked contextMenu opening entry data
            if data ~= nil then
                local elementName = data.name
                local elementCtrl = data._elementCtrl
                local object = data.object
                if object and elementCtrl then
                    local elementNameForSVCHeck = data._elementRealTLCName or getElementRealTLCName(nil, object)
                    if getHUDElementHiddenState(elementNameForSVCHeck) == true then
                        -- Unhide element in HUDEditor again
                        addCustomScrollableMenuEntry(GetString(SI_HUDITORTOOLS_CNTXT_UNHIDE_AT_HUDEDITOR), function ()
                                                         if hideElementUIInHUDOrEditor(elementCtrl, false) == true then
                                                             refreshCustomScrollableMenu(control, LSM_UPDATE_MODE_MAINMENU, comboBox)
                                                         end
                                                     end, LSM_ENTRY_TYPE_NORMAL)
                    else
                        -- Hide element in HUDEditor again
                        addCustomScrollableMenuEntry(GetString(SI_HUDITORTOOLS_CNTXT_HIDE_AT_HUDEDITOR), function ()
                                                         if hideElementUIInHUDOrEditor(elementCtrl, true) == true then
                                                             refreshCustomScrollableMenu(control, LSM_UPDATE_MODE_MAINMENU, comboBox)
                                                         end
                                                     end, LSM_ENTRY_TYPE_NORMAL)
                    end

                    buildHUDElementUserHiddenContextMenuSubmenu(control)

                    showCustomScrollableMenu(nil)
                end
            end
        end
        local selectFunction = function (comboBox, entryText, entry) entry.object:Select() end
        local function CreateItemEntryForLSM(elementCtrl)
            -- local elementNameOrig = getElementDisplayName(elementCtrl, elementCtrl.object) --elementCtrl.object:GetElementData():GetDisplayName()
            local elementNameForSVCheck = getElementRealTLCName(elementCtrl, elementCtrl.object)

            local entry =
            {
                -- ZOs vanilla needed
                object = elementCtrl.object,

                -- LibScrollableMenu needed
                name = function ()                                                                    -- Use function to let RefreshCustomScrollableMenu update the entry directly after the change - via contextMenu
                    local elementNameOrigNow = getElementDisplayName(elementCtrl, elementCtrl.object) -- elementCtrl.object:GetElementData():GetDisplayName()
                    local elementNameForHiddenInHudEditorCheck = getElementRealTLCName(elementCtrl, elementCtrl.object)
                    if getHUDElementHiddenState(elementNameForHiddenInHudEditorCheck) == true then
                        -- Color the hidden entry with the same color as chosen in the settings menu
                        local hiddenHUDElementColor = HT.SV.HUDEditHiddenBorderColor
                        return "- " .. colorizeString(hiddenHUDElementColor.r, hiddenHUDElementColor.g, hiddenHUDElementColor.b, elementNameOrigNow) .. " -"
                    end
                    return elementNameOrigNow
                end,
                -- label = elementNameOrig, --optional, might be nil. If nil name will be used instead
                tooltip = function ()                                                                 -- Use function to let RefreshCustomScrollableMenu update the entry directly after the change - via contextMenu
                    local elementNameOrigNow = getElementDisplayName(elementCtrl, elementCtrl.object) -- elementCtrl.object:GetElementData():GetDisplayName()
                    local elementNameForHiddenInHudEditorCheck = getElementRealTLCName(elementCtrl, elementCtrl.object)
                    return elementNameOrigNow .. " - " .. tostring(elementNameForHiddenInHudEditorCheck)
                end,

                callback = function (comboBox, ...) return selectFunction(comboBox, ...) end,

                -- LSM ContextMenu
                -----Added to determine contextMenu things later
                --- element = element,
                _elementCtrl = elementCtrl,
                _elementRealTLCName = elementNameForSVCheck,

                contextMenuCallback = contextMenuCallbackFunc,
            }
            return entry
        end

        ZO_PostHook(HEK_Class_KB, "RefreshInfoBox", function (selfVar)
            -- For others
            -- Create the comboBox entries via LibScrollableMenu
            local selectedElement = selfVar:GetSelectedElement()
            if selectedElement then
                local itemsTable = {}

                local comboBoxObject = selfVar.infoBoxSelectorDropdown
                comboBoxObject:ClearItems()
                local selectedEntry = nil
                for _, element in ipairs(selfVar.elementControls) do
                    local elementEntry = CreateItemEntryForLSM(element)
                    itemsTable[#itemsTable + 1] = elementEntry

                    if selectedElement == elementEntry.object then
                        selectedEntry = elementEntry
                    end
                    comboBoxObject:SetItemOnEnter(elementEntry, OnElementSelectorDropdownEntryMouseEnter)
                    comboBoxObject:SetItemOnExit(elementEntry, OnElementSelectorDropdownEntryMouseExit)
                end
                if #itemsTable > 0 then
                    comboBoxObject:AddItems(itemsTable)

                    local IGNORE_CALLBACK = true
                    if selectedEntry then
                        comboBoxObject:SelectItem(selectedEntry, IGNORE_CALLBACK)
                    else
                        -- In theory there should always be a selected entry, but have this as a fallback just in case
                        comboBoxObject:SelectFirstItem()
                    end
                end
            end

            -- For the Grid Snap
            HT.UpdateInfoBoxSectionVisibility()
            HT.RefreshLayoutInfoBoxSection()
        end)
    end

    ----------------------------
    -- ContextMenu at HUD Edit elements
    if sv.HUDEditContextMenu == true then
        if not HEEKOnMouseUpFunctionHooked then
            SecurePostHook(HEEK_Class_KB, "OnMouseUp", function (selfVar, elementCtrl, button, upInside)
                local elementData = elementCtrl.object ~= nil and elementCtrl.object:GetElementData()
                if not elementData or not HT.SV.HUDEditContextMenu then return end
                -- d("[HT]HUDElementKeyboard:OnMouseUp - name: " ..tostring(elementData and elementData.displayName or "N/A"))
                onMouseUpShowContextMenuAtHUDEditElementHandler(elementCtrl, button, upInside)
            end)
            HEEKOnMouseUpFunctionHooked = true
        end
    end -- ContextMenu at HUD Editor elements

    if not HEEKRefreshColorsHooked then
        -- Update edge color for element controls in the HUD editor where the mouse is moved over/away
        SecurePostHook(HEEK_Class_KB, "RefreshColors", function (elementObject)
            -- local elementData = elementObject:GetElementData()
            -- d("[HT]RefreshColors - name: " .. tostring(getElementDisplayName(nil, elementObject)))
            updateHUDEditorElementBorderColor(elementObject)
        end)
        -- Update edge color for all looped element controls in the HUD editor -> Looped at Scene Shown via PopulateElementControls
        -- > Only fires if Scene is re-opened, but not on first open of the scene :(
        SecurePostHook(HEK_Class_KB, "PopulateElementControls", function (selfVar, dataToSelect)
            -- d("[HT]PopulateElementControls - dataToSelect: " ..tostring(dataToSelect))
            local HUDEditContextMenu = sv.HUDEditContextMenu
            local numUserHiddenHUDEditorElements = 0
            for _, element in ipairs(selfVar.elementControls) do
                -- Update the edge color for hidden elements in the UI
                updateHUDEditorElementBorderColor(element.object)

                -- Show/Hide elements in the HUD editor, if user chose to
                if updateHUDEditorElementHiddenState(element) == true then
                    numUserHiddenHUDEditorElements = numUserHiddenHUDEditorElements + 1
                end
            end
            if HUDEditContextMenu and numUserHiddenHUDEditorElements > 0 then
                HT.AddChatSystemMessage("[HT]HUD Editor hides '" .. tostring(numUserHiddenHUDEditorElements) .. "' user-hidden elements!")
            end
        end)
        HEEKRefreshColorsHooked = true
    end
end

local function InstallEditorElementHooks()
    if HUDEditorElementHooksDone or not HT.SV.gridSnap then return end

    ZO_PreHook(ZO_HUDEditorElement_Keyboard, "ApplyChanges", function (self)
        if not HT.SV.gridSnap then
            return false
        end
        SnapControlTopLeft(self.control)
        return false
    end)

    ZO_PreHook(ZO_HUDEditorElement_Keyboard, "SetPositionFromTopLeft", function (self, offsetX, offsetY)
        if not HT.SV.gridSnap then
            return false
        end
        offsetX, offsetY = HT.ApplySnap(tonumber(offsetX), tonumber(offsetY), HT.SV.gridSize)
        self.control:ClearAnchors()
        self.control:SetAnchor(TOPLEFT, nil, nil, offsetX, offsetY)
        self:ApplyChanges()
        HE_KB.infoBoxXCoordsEditBox:SetText(tostring(offsetX))
        HE_KB.infoBoxYCoordsEditBox:SetText(tostring(offsetY))
        return true
    end)
    HUDEditorElementHooksDone = true
end

local function InstallHooks()
    InstallEditorHooks()
    InstallEditorElementHooks()
end


------------------------------------------------------------------------------------------------------------------------
--- HUD Editor API functions (called from settings e.g.)
------------------------------------------------------------------------------------------------------------------------
local function CopyColorTableValues(targetColor, sourceColor)
    targetColor.r = sourceColor.r
    targetColor.g = sourceColor.g
    targetColor.b = sourceColor.b
    targetColor.a = sourceColor.a
end

local function CoerceSavedColorTable(colorTable, defaultColor)
    if type(colorTable) ~= "table" then
        return ColorTableFromColorDef(ZO_ColorDef:New(defaultColor.r, defaultColor.g, defaultColor.b, defaultColor.a))
    end
    -- Old default was { r=1, r=0, b=0, a=1 } so g is nil and the last r won
    if colorTable.g == nil then
        CopyColorTableValues(colorTable, defaultColor)
        return colorTable
    end
    colorTable.r = tonumber(colorTable.r) or defaultColor.r
    colorTable.g = tonumber(colorTable.g) or defaultColor.g
    colorTable.b = tonumber(colorTable.b) or defaultColor.b
    colorTable.a = tonumber(colorTable.a)
    if colorTable.a == nil then
        colorTable.a = 1
    end
    return colorTable
end

function HT.HUDUI_RefreshEditorElementColors()
    for _, element in ipairs(HE_KB.elementControls) do
        element.object:RefreshColors()
    end
end

function HT.HUDUI_UpdateColor(svValueName, resetToDefault)
    if svValueName == HT.COLOR_SLOT_HIDDEN then
        local borderColorHiddenHUDElements = HT.SV[svValueName]
        if borderColorHiddenHUDElements ~= nil then
            if resetToDefault == true then
                local hiddenColorTable = ColorTableFromColorDef(defaultSelectedHidden)
                ApplyColorTableToPalette(ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.selectedHidden, hiddenColorTable, true)
                ApplyColorTableToPalette(ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.unselectedHidden, ColorTableFromColorDef(defaultUnselectedHidden), true)
            else
                ApplyColorTableToPalette(ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.selectedHidden, borderColorHiddenHUDElements, true)
                ApplyColorTableToPalette(ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.unselectedHidden, borderColorHiddenHUDElements, true)
            end
            HT.HUDUI_RefreshEditorElementColors()
        end
    elseif svValueName == HT.COLOR_SLOT_SELECTED then
        local selectedPalette = ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.selected
        if resetToDefault == true then
            selectedPalette.edge = defaultSelectedEdge
            selectedPalette.centerNormal = defaultSelectedCenterNormal
            selectedPalette.centerHover = defaultSelectedCenterHover
        else
            local selectedEdgeColor = HT.SV[svValueName]
            if selectedEdgeColor ~= nil then
                ApplyColorTableToPalette(selectedPalette, selectedEdgeColor, false)
            end
        end
        HT.HUDUI_RefreshEditorElementColors()
    elseif svValueName == HT.COLOR_SLOT_UNSELECTED then
        local unselectedPalette = ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.unselected
        if resetToDefault == true then
            unselectedPalette.edge = defaultUnselectedEdge
            unselectedPalette.centerNormal = defaultUnselectedCenterNormal
            unselectedPalette.centerHover = defaultUnselectedCenterHover
            unselectedPalette.font = defaultUnselectedFont
        else
            local unselectedEdgeColor = HT.SV[svValueName]
            if unselectedEdgeColor ~= nil then
                ApplyColorTableToPalette(unselectedPalette, unselectedEdgeColor, true)
            end
        end
        HT.HUDUI_RefreshEditorElementColors()
    elseif svValueName == HT.COLOR_SLOT_GRID then
        if resetToDefault == true then
            CopyColorTableValues(HT.SV.gridColor, HT.Defaults.gridColor)
        end
        HT.RefreshGridOverlayColors()
    end
end

function HT.ResetSavedColor(svValueName)
    local savedColor = HT.SV[svValueName]
    local defaultColor = HT.Defaults[svValueName]
    if savedColor == nil or defaultColor == nil then
        return
    end
    CopyColorTableValues(savedColor, defaultColor)
    HT.HUDUI_UpdateColor(svValueName, true)
end

function HT.HUDUI_ApplySavedColors()
    local defaults = HT.Defaults
    local savedVariables = HT.SV
    savedVariables.HUDEditHiddenBorderColor = CoerceSavedColorTable(savedVariables.HUDEditHiddenBorderColor, defaults.HUDEditHiddenBorderColor)
    savedVariables.gridColor = CoerceSavedColorTable(savedVariables.gridColor, defaults.gridColor)
    savedVariables.selectedEdgeColor = CoerceSavedColorTable(savedVariables.selectedEdgeColor, defaults.selectedEdgeColor)
    savedVariables.unselectedEdgeColor = CoerceSavedColorTable(savedVariables.unselectedEdgeColor, defaults.unselectedEdgeColor)

    HT.HUDUI_UpdateColor(HT.COLOR_SLOT_HIDDEN)
    HT.HUDUI_UpdateColor(HT.COLOR_SLOT_SELECTED)
    HT.HUDUI_UpdateColor(HT.COLOR_SLOT_UNSELECTED)
    HT.HUDUI_UpdateColor(HT.COLOR_SLOT_GRID)
end

-- Lazy check if hooks were done already, and skip, or hook now if settings are enabled
function HT.HUDUIStuff()
    InstallHooks()
end

------------------------------------------------------------------------------------------------------------------------
--- HUD Editor Scene
------------------------------------------------------------------------------------------------------------------------
local function OnEditorSceneStateChange(oldState, newState)
    local isSceneShowing = newState == SCENE_SHOWING
    if isSceneShowing or newState == SCENE_SHOWN then
        editorShowing = true
        if isSceneShowing then
            InstallEditorHooks(true)
        end
        HT.RefreshGridOverlay()
        HT.RefreshColorPickerVisibility()
    elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
        editorShowing = false
        HT.HideGridOverlay()
        HT.RefreshColorPickerVisibility()
        HT.HideLayoutDialogs()
        HT.ApplyAllElementAppearances()
    end
end


------------------------------------------------------------------------------------------------------------------------
--- AddOn loading
------------------------------------------------------------------------------------------------------------------------
local function OnAddOnLoaded(_, addonName)
    if addonName ~= HT.eventName then
        return
    end
    EM:UnregisterForEvent(HT.eventName, EVENT_ADD_ON_LOADED)

    -- SavedVariables
    local worldName = nil -- GetWorldName() no need to split between servers, maybe even "AllAccountsTheSame" as displayName would be a good idea?
    local displayName = GetDisplayName()
    HT.SV = ZO_SavedVars:NewAccountWide("HUDitorToolsSV", 1, worldName, HT.Defaults, nil, displayName)
    HT.HUDUI_ApplySavedColors()

    -- Create LibAddonMenu-2.0 settings panel
    HT.buildSettingsMenu()

    -- Create controls etc.
    HT.InitializeElementAppearance()
    HT.InitializeExtraHudElements()
    HT.InitializeResourceBarGroup()

    HT.InstallInfoBoxControls()
    HT.InstallColorPicker()
    HT.InstallLayoutInfoBoxSection()
    HT.InstallAppearanceInfoBoxSection()
    HT.InitializeHudLayouts()

    -- Scenes and hooks
    SM:GetScene("hud_editor_keyboard"):RegisterCallback("StateChange", OnEditorSceneStateChange)
    InstallHooks()
end
EM:RegisterForEvent(HT.eventName, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
