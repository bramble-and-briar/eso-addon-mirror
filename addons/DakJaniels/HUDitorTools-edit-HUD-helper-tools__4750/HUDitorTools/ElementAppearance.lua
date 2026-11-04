-- -----------------------------------------------------------------------------
-- HUDitorTools - per-element scale and font for HUD_MANAGER elements
-- Scale: Control:SetScale. Font: LabelControl:SetFont / GetFont.
-- Reapply after ZO_HUDManager:PropagateSettings (hudmanager.lua) and when
-- the hud_editor_keyboard scene hides. SetScale is only on the HUD control.
-- RefreshAnchors copies hudElementRef:GetDimensions(). That value includes
-- the control scale, same as GetHeight in ZO_Scroll_UpdateScrollBar. Divide
-- by the HUD control GetScale once. The anchor from
-- ZO_GetControlPointOffsetFromGuiRoot is left as RefreshAnchors set it.
-- -----------------------------------------------------------------------------
local HT = HUDitorTools
local eventManager = GetEventManager()

HT.APPEARANCE_SCALE_STEP = 0.01
HT.APPEARANCE_FONT_SIZE_DEFAULT = 18
HT.APPEARANCE_FONT_OUTLINE_WITH_MEDIA = "soft-shadow-thick"
HT.APPEARANCE_FONT_OUTLINE_GAME = "soft-shadow-thin"

HT.APPEARANCE_FONT_OUTLINES =
{
    "none",
    "outline",
    "thin-outline",
    "thick-outline",
    "shadow",
    "soft-shadow-thin",
    "soft-shadow-thick",
}

local GAME_FONT_FACE_CHOICES =
{
    { face = "$(MEDIUM_FONT)", stringId = "SI_HUDITORTOOLS_APPEARANCE_FONT_MEDIUM" },
    { face = "$(BOLD_FONT)", stringId = "SI_HUDITORTOOLS_APPEARANCE_FONT_BOLD" },
    { face = "$(ANTIQUE_FONT)", stringId = "SI_HUDITORTOOLS_APPEARANCE_FONT_ANTIQUE" },
    { face = "$(GAMEPAD_MEDIUM_FONT)", stringId = "SI_HUDITORTOOLS_APPEARANCE_FONT_GAMEPAD_MEDIUM" },
    { face = "$(GAMEPAD_BOLD_FONT)", stringId = "SI_HUDITORTOOLS_APPEARANCE_FONT_GAMEPAD_BOLD" },
}

local editorScaleHooksInstalled = false
local applyingAllAppearances = false
local saveKeysWithFontApplied = {}
local appliedFontLabelsBySaveKey = {}
local controlsApplyingAppearance = {}
local shownHookInstalled = {}
local styledResourceNumberLabels = {}
local resourceNumbersWidthHookInstalled = false
local barFontCanvasResizeInstalled = false
local nestedHudDetachInstalled = false

-- GetStringWidth is pixels. SetWidth and anchor offsets are UI units
-- (LuiExtended/src/Functions.lua 237-250). "0ui" stays put when custom UI scale changes.
local FONT_OUTLINE_STYLE =
{
    ["none"] = FONT_STYLE_NORMAL,
    ["outline"] = FONT_STYLE_OUTLINE,
    ["thin-outline"] = FONT_STYLE_OUTLINE,
    ["thick-outline"] = FONT_STYLE_OUTLINE_THICK,
    ["shadow"] = FONT_STYLE_SHADOW,
    ["soft-shadow-thin"] = FONT_STYLE_SOFT_SHADOW_THIN,
    ["soft-shadow-thick"] = FONT_STYLE_SOFT_SHADOW_THICK,
}

-- Labels already created on this element. Not a walk of every HUD control.
local MAX_FONT_LABEL_VISITS = 80
local TRACKERS_SAVE_KEY = "ZO_HUDTrackers"

local function ReadScale(scale)
    scale = tonumber(scale)
    if scale == nil or scale <= 0 then
        return 1
    end
    return scale
end

local function ReadFontSize(fontSize)
    fontSize = tonumber(fontSize)
    if fontSize == nil then
        return HT.APPEARANCE_FONT_SIZE_DEFAULT
    end
    fontSize = zo_floor(fontSize)
    if fontSize < 1 then
        return 1
    end
    return fontSize
end

function HT.GetAppearanceInputModeKey()
    if IsInGamepadPreferredMode() then
        return "gamepad"
    end
    return "keyboard"
end

function HT.GetDefaultFontOutline()
    if LibMediaProvider then
        return HT.APPEARANCE_FONT_OUTLINE_WITH_MEDIA
    end
    return HT.APPEARANCE_FONT_OUTLINE_GAME
end

function HT.CopyElementAppearance(sourceAppearance)
    local copiedAppearance =
    {
        keyboard = {},
        gamepad = {},
    }
    if type(sourceAppearance) ~= "table" then
        return copiedAppearance
    end
    for _, inputModeKey in ipairs({ "keyboard", "gamepad" }) do
        local sourceMap = sourceAppearance[inputModeKey]
        if type(sourceMap) == "table" then
            for saveKey, row in pairs(sourceMap) do
                if type(row) == "table" then
                    copiedAppearance[inputModeKey][saveKey] =
                    {
                        scale = tonumber(row.scale) or 1,
                        fontFace = row.fontFace or "",
                        fontSize = tonumber(row.fontSize) or HT.APPEARANCE_FONT_SIZE_DEFAULT,
                        fontOutline = row.fontOutline or "",
                    }
                end
            end
        end
    end
    return copiedAppearance
end

local function GetAppearanceRoot()
    local appearance = HT.SV.elementAppearance
    if type(appearance) ~= "table" then
        appearance = HT.CopyElementAppearance(nil)
        HT.SV.elementAppearance = appearance
    end
    if type(appearance.keyboard) ~= "table" then
        appearance.keyboard = {}
    end
    if type(appearance.gamepad) ~= "table" then
        appearance.gamepad = {}
    end
    return appearance
end

function HT.GetAppearanceMap(inputModeKey)
    local appearance = GetAppearanceRoot()
    inputModeKey = inputModeKey or HT.GetAppearanceInputModeKey()
    return appearance[inputModeKey]
end

function HT.GetAppearanceRow(saveKey, inputModeKey)
    if not saveKey then
        return nil
    end
    return HT.GetAppearanceMap(inputModeKey)[saveKey]
end

function HT.IsAppearanceRowDefault(row)
    if type(row) ~= "table" then
        return true
    end
    local scale = tonumber(row.scale) or 1
    local fontFace = row.fontFace or ""
    if zo_abs(scale - 1) >= 0.001 then
        return false
    end
    if fontFace ~= "" then
        return false
    end
    return true
end

function HT.SetAppearanceRow(saveKey, row, inputModeKey)
    if not saveKey then
        return
    end
    local modeMap = HT.GetAppearanceMap(inputModeKey)
    if HT.IsAppearanceRowDefault(row) then
        modeMap[saveKey] = nil
        return
    end
    modeMap[saveKey] =
    {
        scale = ReadScale(row.scale),
        fontFace = row.fontFace or "",
        fontSize = ReadFontSize(row.fontSize),
        fontOutline = row.fontOutline or HT.GetDefaultFontOutline(),
    }
end

--- @param layoutValue number
--- @return string
local function FormatUiLayoutMeasurement(layoutValue)
    return string.format("%dui", zo_round(layoutValue))
end

--- @param label LabelControl
--- @param text string|nil
--- @return number
local function GetLabelStringWidthUI(label, text)
    if text == nil or text == "" then
        return 0
    end
    return label:GetStringWidth(text) / GetUIGlobalScale()
end

--- @param label LabelControl
--- @return boolean
local function IsResourceNumbersLabel(label)
    return string.find(label:GetName(), "ResourceNumbers", 1, true) ~= nil
end

--- ZO_PlayerAttributeBar is local (PlayerAttributeBars.lua 132). New() stores each
--- bar on PLAYER_ATTRIBUTE_BARS.bars (lines 489-545, assigned at 899).
local function OnResourceNumbersUpdated(attributeBar)
    local label = attributeBar.control.resourceNumbersLabel
    if not label or not styledResourceNumberLabels[label] then
        return
    end
    local textWidth = GetLabelStringWidthUI(label, label:GetText())
    if textWidth > 0 then
        label:SetWidth(textWidth)
    end
end

local function InstallResourceNumbersWidthHook()
    if resourceNumbersWidthHookInstalled then
        return
    end
    resourceNumbersWidthHookInstalled = true
    for _, attributeBar in ipairs(PLAYER_ATTRIBUTE_BARS.bars) do
        SecurePostHook(attributeBar, "UpdateResourceNumbersLabel", OnResourceNumbersUpdated)
    end
end

--- ResourceNumbers is CENTER in PlayerAttributeBarTemplates.xml 10-14.
--- Width is UI units so the glyphs stay in the middle of the bar.
--- @param label LabelControl
local function CenterResourceNumbersLabel(label)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    local parentControl = label:GetParent()
    label:ClearAnchors()
    label:SetAnchor(CENTER, parentControl, CENTER, FormatUiLayoutMeasurement(0), FormatUiLayoutMeasurement(0))
    local textWidth = GetLabelStringWidthUI(label, label:GetText())
    if textWidth > 0 then
        label:SetWidth(textWidth)
    end
    styledResourceNumberLabels[label] = true
end

local function RemeasureStyledResourceNumberLabels()
    for label in pairs(styledResourceNumberLabels) do
        local textWidth = GetLabelStringWidthUI(label, label:GetText())
        if textWidth > 0 then
            label:SetWidth(textWidth)
        end
    end
end

local function InstallBarFontCanvasResize()
    if barFontCanvasResizeInstalled then
        return
    end
    barFontCanvasResizeInstalled = true
    -- EVENT_ALL_GUI_SCREENS_RESIZED is the finished canvas (Functions.lua 285-288).
    eventManager:RegisterForEvent(HT.eventName .. "_BarFontCanvas", EVENT_ALL_GUI_SCREENS_RESIZED, RemeasureStyledResourceNumberLabels)
end

function HT.BuildAppearanceFontString(fontFace, fontSize, fontOutline)
    if fontFace == nil or fontFace == "" then
        return nil
    end
    fontSize = ReadFontSize(fontSize)
    local faceName = fontFace
    if LibMediaProvider and not string.find(fontFace, "$(", 1, true) then
        local fontPath = LibMediaProvider:Fetch("font", fontFace)
        if not fontPath then
            return nil
        end
        faceName = fontPath
    elseif not string.find(fontFace, "$(", 1, true) then
        return nil
    end
    local fontStyle = FONT_OUTLINE_STYLE[fontOutline]
    if fontStyle == nil then
        if string.find(fontFace, "$(", 1, true) then
            fontStyle = FONT_STYLE_SOFT_SHADOW_THIN
        else
            fontStyle = FONT_STYLE_SOFT_SHADOW_THICK
        end
    end
    -- globalapi.lua 766-772. Size is the slider value.
    return ZO_CreateFontString(faceName, fontSize, fontStyle)
end

function HT.GetFontFaceChoices()
    local choices = {}
    local choiceLabels = {}
    choices[1] = ""
    choiceLabels[1] = GetString(SI_HUDITORTOOLS_APPEARANCE_FONT_DEFAULT)
    if LibMediaProvider then
        local mediaNames = LibMediaProvider:List("font")
        if mediaNames then
            local sortedNames = {}
            for _, mediaName in ipairs(mediaNames) do
                sortedNames[#sortedNames + 1] = mediaName
            end
            table.sort(sortedNames)
            for _, mediaName in ipairs(sortedNames) do
                choices[#choices + 1] = mediaName
                choiceLabels[#choiceLabels + 1] = mediaName
            end
        end
        return choices, choiceLabels
    end
    for _, gameFace in ipairs(GAME_FONT_FACE_CHOICES) do
        choices[#choices + 1] = gameFace.face
        choiceLabels[#choiceLabels + 1] = GetString(_G[gameFace.stringId])
    end
    return choices, choiceLabels
end

local function VisitLabels(control, onLabel)
    local pendingControls = { control }
    local visitedControls = {}
    local pendingCount = 1
    local visitedCount = 0
    while pendingCount > 0 and visitedCount < MAX_FONT_LABEL_VISITS do
        local currentControl = pendingControls[pendingCount]
        pendingControls[pendingCount] = nil
        pendingCount = pendingCount - 1
        if currentControl and not visitedControls[currentControl] then
            visitedControls[currentControl] = true
            visitedCount = visitedCount + 1
            if currentControl:GetType() == CT_LABEL then
                onLabel(currentControl)
            else
                local childCount = currentControl:GetNumChildren()
                if childCount > MAX_FONT_LABEL_VISITS then
                    childCount = MAX_FONT_LABEL_VISITS
                end
                for childIndex = 1, childCount do
                    if visitedCount + pendingCount >= MAX_FONT_LABEL_VISITS then
                        break
                    end
                    local childControl = currentControl:GetChild(childIndex)
                    if childControl then
                        pendingCount = pendingCount + 1
                        pendingControls[pendingCount] = childControl
                    end
                end
            end
        end
    end
end

local function SetLabelFont(label, fontString)
    if not label.huditorToolsOriginalFont then
        label.huditorToolsOriginalFont = label:GetFont()
    end
    label:SetFont(fontString)
    if IsResourceNumbersLabel(label) then
        CenterResourceNumbersLabel(label)
    end
end

local function FontStringFromAppearanceRow(row)
    if type(row) ~= "table" then
        return nil
    end
    local fontFace = row.fontFace or ""
    if fontFace == "" then
        return nil
    end
    return HT.BuildAppearanceFontString(fontFace, ReadFontSize(row.fontSize), row.fontOutline or HT.GetDefaultFontOutline())
end

local function TrackerHasOwnFont(trackerControl)
    return FontStringFromAppearanceRow(HT.GetAppearanceRow(trackerControl:GetName())) ~= nil
end

-- Combined trackers live under the scroll child. SeparatedTrackers reparents
-- that same control onto ZO_HUDTrackers (HUDTracker_Manager:RefreshLayout).
local function ApplyFontToRegisteredTrackers(fontString)
    for _, trackerData in ipairs(HUD_TRACKER_MANAGER.trackers) do
        if not TrackerHasOwnFont(trackerData.control) then
            VisitLabels(trackerData.control, function (label)
                SetLabelFont(label, fontString)
            end)
        end
    end
end

local function RestoreFontOnRegisteredTrackers()
    for _, trackerData in ipairs(HUD_TRACKER_MANAGER.trackers) do
        if not TrackerHasOwnFont(trackerData.control) then
            VisitLabels(trackerData.control, function (label)
                local originalFont = label.huditorToolsOriginalFont
                if originalFont then
                    label:SetFont(originalFont)
                end
            end)
        end
    end
end

-- Quest lines take FONT_HEADER, FONT_GENERAL, and FONT_SUBCATEGORY when the
-- header, condition, and step pools acquire them (QuestTracker.lua).
local function FontStringForTracker(trackerOwner)
    local fontString = FontStringFromAppearanceRow(HT.GetAppearanceRow(trackerOwner.control:GetName()))
    if not fontString and not trackerOwner:IsDetached() then
        fontString = FontStringFromAppearanceRow(HT.GetAppearanceRow(TRACKERS_SAVE_KEY))
    end
    return fontString
end

local function ReapplyFontOnTracker(trackerOwner)
    local fontString = FontStringForTracker(trackerOwner)
    if not fontString then
        return
    end
    VisitLabels(trackerOwner.control, function (label)
        SetLabelFont(label, fontString)
    end)
end

local trackerHeaderFontHookInstalled = false

local function InstallTrackerPlatformStyleHook()
    if trackerHeaderFontHookInstalled then
        return
    end
    trackerHeaderFontHookInstalled = true
    SecurePostHook(ZO_HUDTracker_Base, "ApplyPlatformStyle", function (trackerOwner)
        ReapplyFontOnTracker(trackerOwner)
    end)
    -- ZO_Tracker:ApplyPlatformStyle sets the stock quest fonts after the base call.
    SecurePostHook(ZO_Tracker, "ApplyPlatformStyle", function (trackerOwner)
        ReapplyFontOnTracker(trackerOwner)
    end)
    SecurePostHook(ZO_Tracker, "AddQuest", function (trackerOwner)
        ReapplyFontOnTracker(trackerOwner)
    end)
    SecurePostHook(ZO_Tracker, "RebuildConditions", function (trackerOwner)
        ReapplyFontOnTracker(trackerOwner)
    end)
end

local function ApplyFontStringToLabels(control, fontString, saveKey)
    local knownLabels = appliedFontLabelsBySaveKey[saveKey]
    if knownLabels and #knownLabels > 0 then
        for labelIndex = 1, #knownLabels do
            knownLabels[labelIndex]:SetFont(fontString)
        end
        if saveKey == TRACKERS_SAVE_KEY then
            ApplyFontToRegisteredTrackers(fontString)
        end
        return
    end
    local foundLabels = {}
    VisitLabels(control, function (label)
        SetLabelFont(label, fontString)
        foundLabels[#foundLabels + 1] = label
    end)
    if saveKey == TRACKERS_SAVE_KEY then
        ApplyFontToRegisteredTrackers(fontString)
    end
    if #foundLabels > 0 then
        appliedFontLabelsBySaveKey[saveKey] = foundLabels
    end
end

local function RestoreFontStringOnLabels(control, saveKey)
    local knownLabels = appliedFontLabelsBySaveKey[saveKey]
    if knownLabels and #knownLabels > 0 then
        for labelIndex = 1, #knownLabels do
            local label = knownLabels[labelIndex]
            local originalFont = label.huditorToolsOriginalFont
            if originalFont then
                label:SetFont(originalFont)
                if IsResourceNumbersLabel(label) then
                    CenterResourceNumbersLabel(label)
                end
            end
        end
        appliedFontLabelsBySaveKey[saveKey] = nil
        if saveKey == TRACKERS_SAVE_KEY then
            RestoreFontOnRegisteredTrackers()
        end
        return
    end
    VisitLabels(control, function (label)
        local originalFont = label.huditorToolsOriginalFont
        if originalFont then
            label:SetFont(originalFont)
            if IsResourceNumbersLabel(label) then
                CenterResourceNumbersLabel(label)
            end
        end
    end)
    if saveKey == TRACKERS_SAVE_KEY then
        RestoreFontOnRegisteredTrackers()
    end
end

local function InstallShownHook(control, element)
    local controlName = control:GetName()
    if controlName == "" or shownHookInstalled[controlName] then
        return
    end
    shownHookInstalled[controlName] = true
    ZO_PostHookHandler(control, "OnEffectivelyShown", function ()
        HT.ApplyElementAppearance(element)
    end)
end

--- Target buffs are SetParent'd onto the target frame (BuffDebuff.lua 388-389).
--- That is the only registered HUD element ZOS parents onto a different HUD element.
--- Health, magicka, and stamina stay children of ZO_PlayerAttribute
--- (PlayerAttributeBars.xml 85, 132, 197). Combined Resources and the pyramid
--- layout (ResourceBarGroup.lua 149-159) depend on that parent.
--- Trackers stay under ZO_HUDTrackers (HUDTracker_Manager.lua 244-255).
function HT.DetachTargetBuffsFromTargetFrame()
    local targetContainer = ZO_BuffDebuffTopLevelTargetContainer
    local parentControl = targetContainer:GetParent()
    if parentControl ~= ZO_BuffDebuffTopLevel and parentControl ~= GuiRoot then
        targetContainer:SetParent(GuiRoot)
    end
end

local function InstallTargetBuffDetach()
    if nestedHudDetachInstalled then
        return
    end
    nestedHudDetachInstalled = true
    -- Runs after BuffDebuff.lua 487, which registered this callback first.
    CALLBACK_MANAGER:RegisterCallback("TargetFrameCreated", function ()
        HT.DetachTargetBuffsFromTargetFrame()
    end)
end

function HT.ApplyElementAppearance(element)
    local control = element:GetControl()
    if controlsApplyingAppearance[control] then
        return
    end
    controlsApplyingAppearance[control] = true
    local saveKey = element:GetSaveKey()
    local row = HT.GetAppearanceRow(saveKey)
    local scale = 1
    local fontFace = ""
    local fontSize = HT.APPEARANCE_FONT_SIZE_DEFAULT
    local fontOutline = HT.GetDefaultFontOutline()
    if row then
        scale = ReadScale(row.scale)
        fontFace = row.fontFace or ""
        fontSize = ReadFontSize(row.fontSize)
        fontOutline = row.fontOutline or fontOutline
    end
    local currentScale = control:GetScale()
    if zo_abs(currentScale - scale) >= 0.001 then
        control:SetScale(scale)
    end
    if fontFace ~= "" then
        local fontString = HT.BuildAppearanceFontString(fontFace, fontSize, fontOutline)
        if fontString then
            ApplyFontStringToLabels(control, fontString, saveKey)
            saveKeysWithFontApplied[saveKey] = true
        end
    elseif saveKeysWithFontApplied[saveKey] then
        RestoreFontStringOnLabels(control, saveKey)
        saveKeysWithFontApplied[saveKey] = nil
    end
    if row and not HT.IsAppearanceRowDefault(row) then
        InstallShownHook(control, element)
    end
    controlsApplyingAppearance[control] = nil
end

function HT.ApplyAllElementAppearances()
    if applyingAllAppearances then
        return
    end
    applyingAllAppearances = true
    HT.ApplyResourceBarGroup()
    local modeMap = HT.GetAppearanceMap()
    for saveKey, row in pairs(modeMap) do
        if not HT.IsAppearanceRowDefault(row) then
            local control = _G[saveKey]
            if type(control) == "userdata" then
                local element
                if IsInGamepadPreferredMode() then
                    element = HUD_MANAGER:GetGamepadElementForControl(control)
                else
                    element = HUD_MANAGER:GetKeyboardElementForControl(control)
                end
                if element then
                    HT.ApplyElementAppearance(element)
                end
            end
        end
    end
    applyingAllAppearances = false
end

function HT.StepSelectedElementScale(editorElement, direction)
    local elementData = editorElement:GetElementData()
    if not elementData then
        return
    end
    local saveKey = elementData:GetSaveKey()
    local row = HT.GetAppearanceRow(saveKey) or {}
    local scale = (tonumber(row.scale) or 1) + (direction * HT.APPEARANCE_SCALE_STEP)
    if scale <= 0 then
        scale = HT.APPEARANCE_SCALE_STEP
    end
    scale = zo_roundToNearest(scale, HT.APPEARANCE_SCALE_STEP)
    HT.SetAppearanceRow(saveKey, {
        scale = scale,
        fontFace = row.fontFace,
        fontSize = row.fontSize,
        fontOutline = row.fontOutline,
    })
    HT.ApplyElementAppearance(elementData)
    editorElement:RefreshAnchors()
    HT.RefreshAppearanceInfoBox()
    HT.RefreshLayoutInfoBoxSection()
end

local function OnEditorElementMouseWheel(editorControl, delta)
    local editorElement = editorControl.object
    if HUD_EDITOR_KEYBOARD:GetSelectedElement() ~= editorElement then
        return
    end
    local direction = 1
    if delta < 0 then
        direction = -1
    end
    HT.StepSelectedElementScale(editorElement, direction)
end

function HT.InstallElementScaleMouseWheel(editor)
    for _, elementControl in ipairs(editor.elementControls) do
        if not elementControl.huditorToolsScaleWheelInstalled then
            elementControl.huditorToolsScaleWheelInstalled = true
            if not elementControl:GetHandler("OnMouseWheel") then
                elementControl:SetHandler("OnMouseWheel", OnEditorElementMouseWheel)
            end
        end
    end
end

local function ApplyEditorSelectorLayoutSize(editorElement)
    local hudControl = editorElement:GetElementData():GetControl()
    local scale = hudControl:GetScale()
    if zo_abs(scale - 1) < 0.001 then
        return
    end
    local editorControl = editorElement:GetControl()
    local width, height = editorControl:GetDimensions()
    editorControl:SetDimensions(width / scale, height / scale)
end

function HT.InstallElementAppearanceEditorHooks()
    if editorScaleHooksInstalled then
        return
    end
    editorScaleHooksInstalled = true
    SecurePostHook(ZO_HUDEditor_Keyboard, "PopulateElementControls", function (editor)
        HT.InstallElementScaleMouseWheel(editor)
    end)
    SecurePostHook(ZO_HUDEditorElement_Keyboard, "RefreshAnchors", function (editorElement)
        ApplyEditorSelectorLayoutSize(editorElement)
    end)
end

function HT.NormalizeLayoutPayload(payload)
    payload = payload or {}
    local normalizedPayload =
    {
        keyboardElements = {},
        gamepadElements = {},
        elementAppearance = HT.CopyElementAppearance(payload.elementAppearance),
        resourceBarGroup = HT.CopyResourceBarGroup(payload.resourceBarGroup),
    }
    if type(payload.keyboardElements) == "table" then
        ZO_DeepTableCopy(payload.keyboardElements, normalizedPayload.keyboardElements)
    end
    if type(payload.gamepadElements) == "table" then
        ZO_DeepTableCopy(payload.gamepadElements, normalizedPayload.gamepadElements)
    end
    return normalizedPayload
end

function HT.InitializeElementAppearance()
    GetAppearanceRoot()
    HT.InstallElementAppearanceEditorHooks()
    InstallTrackerPlatformStyleHook()
    InstallResourceNumbersWidthHook()
    InstallBarFontCanvasResize()
    InstallTargetBuffDetach()
    HT.DetachTargetBuffsFromTargetFrame()
    HUD_MANAGER:RegisterCallback("PropagateSettings", function ()
        HT.ApplyAllElementAppearances()
    end)
    HT.ApplyAllElementAppearances()
    eventManager:RegisterForEvent(HT.eventName .. "_Appearance", EVENT_PLAYER_ACTIVATED, function ()
        zo_callLater(HT.ApplyAllElementAppearances, 0)
    end)
end
