local ADDON_NAME = "MovableHUD"
local SAVED_VARIABLES_NAME = "MovableHUDSavedVariables"
local SAVED_VARIABLES_VERSION = 1

local MH = {
    name = ADDON_NAME,
    version = "2.4.11",
    runtime = {},
    targetOrder = { "chat", "quest", "group" },
}

MovableHUD = MH

local DEFAULTS = {
    schemaVersion = 4,
    previewEnabled = true,
    selectedTarget = "chat",
    selectedRow = 2,
    elements = {
        chat = {
            enabled = true,
            initialized = false,
            x = 0,
            y = 0,
            width = 490,
            height = 280,
            scale = 1,
        },
        quest = {
            enabled = true,
            initialized = false,
            x = 0,
            y = 0,
            width = 480,
            height = 600,
            scale = 1,
        },
        group = {
            enabled = true,
            initialized = true,
            x = 0,
            y = 0,
            width = 0,
            height = 0,
            scale = 1,
        },
    },
}

local TARGET_NAMES = {
    chat = "Chat Box",
    quest = "Quest Tracker",
    group = "Group & Companion Frames",
}

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then
        return minimum
    elseif value > maximum then
        return maximum
    end
    return value
end

local function Round(value)
    value = tonumber(value) or 0
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function ShallowCopy(source)
    local result = {}
    for key, value in pairs(source or {}) do
        result[key] = value
    end
    return result
end

local function Tokenize(text)
    local tokens = {}
    for token in string.gmatch(text or "", "%S+") do
        tokens[#tokens + 1] = token
    end
    return tokens
end

local function IsControl(value)
    return value ~= nil
        and value.ClearAnchors ~= nil
        and value.SetAnchor ~= nil
        and value.GetLeft ~= nil
end

local function AddUniqueControl(output, seen, value)
    local control = value
    if value and not IsControl(value) then
        control = value.control or value.container or value.panel
        if not IsControl(control) and value.GetControl then
            local ok, resolved = pcall(value.GetControl, value)
            if ok then
                control = resolved
            end
        end
    end

    if IsControl(control) and not seen[control] then
        seen[control] = true
        output[#output + 1] = control
    end
end

local function Print(message)
    local formatted = string.format("|c7AD7F0Movable HUD:|r %s", tostring(message))
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage(formatted)
    else
        d(formatted)
    end
end

function MH:GetTargetName(targetKey)
    return TARGET_NAMES[targetKey] or tostring(targetKey)
end

function MH:Print(message)
    Print(message)
end

function MH:GetElementSettings(targetKey)
    return self.saved and self.saved.elements and self.saved.elements[targetKey]
end

function MH:GetRuntime(targetKey)
    local runtime = self.runtime[targetKey]
    if not runtime then
        runtime = {
            controlStates = {},
            groupBaseStates = {},
        }
        self.runtime[targetKey] = runtime
    end
    return runtime
end

function MH:GetChatControls()
    local output, seen = {}, {}
    local system = GAMEPAD_CHAT_SYSTEM
    local container = system and system.primaryContainer
    AddUniqueControl(output, seen, container and container.control)
    return output
end

function MH:GetQuestControls()
    local output, seen = {}, {}

    AddUniqueControl(output, seen, _G["ZO_FocusedQuestTrackerPanel"])
    AddUniqueControl(output, seen, _G["ZO_FocusedQuestTracker"])
    AddUniqueControl(output, seen, _G["ZO_QuestTrackerPanel"])
    AddUniqueControl(output, seen, _G["ZO_QuestTracker"])

    AddUniqueControl(output, seen, _G["FOCUSED_QUEST_TRACKER"])
    AddUniqueControl(output, seen, _G["QUEST_TRACKER"])

    return output
end

function MH:GetGroupControls(includeHidden)
    local output, seen = {}, {}
    local manager = UNIT_FRAMES

    local function AddFrameTable(frameTable)
        for _, frameObject in pairs(frameTable or {}) do
            local control = frameObject and (frameObject.control or frameObject.frame or frameObject)
            if IsControl(control) and (includeHidden or not control:IsHidden()) then
                AddUniqueControl(output, seen, control)
            end
        end
    end

    if manager then
        local combinedSize
        if manager.GetCombinedGroupSize then
            combinedSize = manager:GetCombinedGroupSize()
        else
            combinedSize = (GetGroupSize and GetGroupSize() or 0)
                + (GetNumCompanionsInGroup and GetNumCompanionsInGroup() or 0)
        end

        local standardGroupThreshold = STANDARD_GROUP_SIZE_THRESHOLD or 4
        if combinedSize > standardGroupThreshold then
            AddFrameTable(manager.raidFrames)
            AddFrameTable(manager.companionRaidFrames)
        else
            AddFrameTable(manager.groupFrames)
        end

        -- ESO keeps the player's solo companion in the static unit-frame table
        -- under the unit tag "companion". It is separate from groupFrames, so it
        -- must be included explicitly for the Group settings to move it while solo.
        -- The frame is hidden while grouped; excluding it then prevents a hidden
        -- control from affecting the visible group's calculated origin or preview.
        local hasLocalCompanion = (HasActiveCompanion and HasActiveCompanion())
            or (HasPendingCompanion and HasPendingCompanion())
        if hasLocalCompanion and not (IsUnitGrouped and IsUnitGrouped("player")) then
            local companionFrame = manager.GetFrame and manager:GetFrame("companion")
            local companionControl = companionFrame
                and (companionFrame.control or companionFrame.frame or companionFrame)
            if IsControl(companionControl)
                and (includeHidden or not companionControl:IsHidden()) then
                AddUniqueControl(output, seen, companionControl)
            end
        end
    end

    -- Fallback for clients where the active manager table is not exposed yet.
    if #output == 0 then
        for index = 1, 24 do
            local unitTag = GetGroupUnitTagByIndex and GetGroupUnitTagByIndex(index) or string.format("group%d", index)
            if unitTag and manager and manager.GetFrame then
                local frameObject = manager:GetFrame(unitTag)
                local control = frameObject and (frameObject.control or frameObject.frame or frameObject)
                if IsControl(control) and (includeHidden or not control:IsHidden()) then
                    AddUniqueControl(output, seen, control)
                end
            end
        end
    end

    return output
end

function MH:GetTargetControls(targetKey, includeHidden)
    if targetKey == "chat" then
        return self:GetChatControls()
    elseif targetKey == "quest" then
        return self:GetQuestControls()
    elseif targetKey == "group" then
        return self:GetGroupControls(includeHidden)
    end
    return {}
end

function MH:CaptureControlState(targetKey, control)
    local runtime = self:GetRuntime(targetKey)
    local existing = runtime.controlStates[control]
    if existing then
        return existing
    end

    local state = {
        left = tonumber(control:GetLeft()) or 0,
        top = tonumber(control:GetTop()) or 0,
        width = math.max(1, tonumber(control:GetWidth()) or 1),
        height = math.max(1, tonumber(control:GetHeight()) or 1),
        scale = tonumber(control:GetScale()) or 1,
        anchors = {},
    }

    if control.GetNumAnchors and control.GetAnchor then
        local numAnchors = control:GetNumAnchors() or 0
        for anchorIndex = 0, numAnchors - 1 do
            local valid, point, relativeTo, relativePoint, offsetX, offsetY, constraints = control:GetAnchor(anchorIndex)
            if valid then
            state.anchors[#state.anchors + 1] = {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                offsetX = offsetX,
                offsetY = offsetY,
                constraints = constraints,
            }
            end
        end
    end

    runtime.controlStates[control] = state
    return state
end

function MH:RestoreControlState(targetKey, control)
    local runtime = self:GetRuntime(targetKey)
    local state = runtime.controlStates[control]
    if not state then
        return false
    end

    control:ClearAnchors()
    if #state.anchors > 0 then
        for _, anchor in ipairs(state.anchors) do
            control:SetAnchor(
                anchor.point,
                anchor.relativeTo,
                anchor.relativePoint,
                anchor.offsetX,
                anchor.offsetY,
                anchor.constraints
            )
        end
    else
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, state.left, state.top)
    end

    control:SetDimensions(state.width, state.height)
    control:SetScale(state.scale)
    return true
end

function MH:InitializeElementFromControl(targetKey, control)
    local settings = self:GetElementSettings(targetKey)
    if not settings or settings.initialized then
        return
    end

    local state = self:CaptureControlState(targetKey, control)
    settings.x = Round(state.left)
    settings.y = Round(state.top)
    settings.width = Round(state.width)
    settings.height = Round(state.height)
    settings.scale = Clamp(state.scale, 0.25, 3)
    settings.initialized = true
end

function MH:NormalizeSavedVariables()
    self.saved.schemaVersion = 4
    if self.saved.previewEnabled == nil then
        self.saved.previewEnabled = true
    else
        self.saved.previewEnabled = self.saved.previewEnabled ~= false
    end
    self.saved.elements = self.saved.elements or {}

    for targetKey, targetDefaults in pairs(DEFAULTS.elements) do
        local settings = self.saved.elements[targetKey]
        if type(settings) ~= "table" then
            settings = ShallowCopy(targetDefaults)
            self.saved.elements[targetKey] = settings
        end

        for key, defaultValue in pairs(targetDefaults) do
            if settings[key] == nil then
                settings[key] = defaultValue
            end
        end

        settings.enabled = settings.enabled ~= false
        settings.initialized = settings.initialized == true
        settings.x = Round(settings.x)
        settings.y = Round(settings.y)
        settings.width = Clamp(Round(settings.width), 100, 2200)
        settings.height = Clamp(Round(settings.height), 60, 1600)
        settings.scale = Clamp(tonumber(settings.scale) or 1, 0.25, 3)
    end

    if not TARGET_NAMES[self.saved.selectedTarget] then
        self.saved.selectedTarget = DEFAULTS.selectedTarget
    end
    self.saved.selectedRow = Clamp(Round(self.saved.selectedRow or 2), 1, 6)
end

function MH:ApplyStandardTarget(targetKey)
    local settings = self:GetElementSettings(targetKey)
    if not settings then
        return false
    end

    local controls = self:GetTargetControls(targetKey, true)
    local control = controls[1]
    if not control then
        return false
    end

    self:CaptureControlState(targetKey, control)
    self:InitializeElementFromControl(targetKey, control)

    if not settings.enabled then
        return self:RestoreControlState(targetKey, control)
    end

    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, settings.x, settings.y)
    control:SetDimensions(settings.width, settings.height)
    control:SetScale(settings.scale)
    return true
end

function MH:CaptureGroupBaseState(control, settings)
    local runtime = self:GetRuntime("group")
    local state = runtime.groupBaseStates[control]
    if state then
        return state
    end

    local nativeState = self:CaptureControlState("group", control)
    state = {
        -- Group controls are never moved through their native anchor containers,
        -- so their first observed screen position is the unmodified base position.
        left = nativeState.left,
        top = nativeState.top,
        width = nativeState.width,
        height = nativeState.height,
        scale = nativeState.scale,
    }
    runtime.groupBaseStates[control] = state
    return state
end

function MH:ApplyGroupTarget()
    local settings = self:GetElementSettings("group")
    if not settings then
        return false
    end

    local controls = self:GetGroupControls(true)
    if #controls == 0 then
        return false
    end

    if not settings.enabled then
        for _, control in ipairs(controls) do
            self:RestoreControlState("group", control)
        end
        return true
    end

    local baseStates = {}
    local originX, originY
    for _, control in ipairs(controls) do
        local baseState = self:CaptureGroupBaseState(control, settings)
        baseStates[control] = baseState
        originX = originX and math.min(originX, baseState.left) or baseState.left
        originY = originY and math.min(originY, baseState.top) or baseState.top
    end

    local scale = settings.scale
    for _, control in ipairs(controls) do
        local baseState = baseStates[control]
        local targetLeft = originX + settings.x + ((baseState.left - originX) * scale)
        local targetTop = originY + settings.y + ((baseState.top - originY) * scale)

        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, targetLeft, targetTop)
        control:SetScale(baseState.scale * scale)
    end

    return true
end

function MH:ApplyTarget(targetKey)
    if targetKey == "group" then
        return self:ApplyGroupTarget()
    elseif targetKey == "chat" or targetKey == "quest" then
        return self:ApplyStandardTarget(targetKey)
    end
    return false
end

function MH:ApplyAll()
    local anyApplied = false
    for _, targetKey in ipairs(self.targetOrder) do
        anyApplied = self:ApplyTarget(targetKey) or anyApplied
    end
    return anyApplied
end

function MH:ApplySoon(delayMs, targetKey)
    zo_callLater(function()
        if targetKey then
            self:ApplyTarget(targetKey)
        else
            self:ApplyAll()
        end
    end, delayMs or 0)
end

function MH:SetElementEnabled(targetKey, enabled)
    local settings = self:GetElementSettings(targetKey)
    if not settings then
        return
    end
    settings.enabled = enabled ~= false
    self:ApplyTarget(targetKey)
    self:UpdatePreviews()
end

function MH:SetElementValue(targetKey, property, value)
    local settings = self:GetElementSettings(targetKey)
    if not settings then
        return false
    end

    if property == "x" or property == "y" then
        settings[property] = Clamp(Round(value), -2500, 3500)
    elseif property == "width" then
        if targetKey == "group" then
            return false
        end
        settings.width = Clamp(Round(value), 100, 2200)
    elseif property == "height" then
        if targetKey == "group" then
            return false
        end
        settings.height = Clamp(Round(value), 60, 1600)
    elseif property == "scale" then
        local numericValue = tonumber(value) or settings.scale
        if numericValue > 10 then
            numericValue = numericValue / 100
        end
        settings.scale = Clamp(numericValue, 0.25, 3)
    elseif property == "enabled" then
        local lowered = string.lower(tostring(value))
        settings.enabled = not (lowered == "false" or lowered == "off" or lowered == "0" or lowered == "no")
    else
        return false
    end

    settings.initialized = true
    self:ApplyTarget(targetKey)
    self:UpdatePreviews()
    return true
end

function MH:ResetTarget(targetKey)
    local settings = self:GetElementSettings(targetKey)
    if not settings then
        return false
    end

    if targetKey == "group" then
        settings.enabled = true
        settings.initialized = true
        settings.x = 0
        settings.y = 0
        settings.scale = 1
    else
        local controls = self:GetTargetControls(targetKey, true)
        local control = controls[1]
        local runtime = self:GetRuntime(targetKey)
        local state = control and runtime.controlStates[control]

        settings.enabled = true
        if state then
            settings.initialized = true
            settings.x = Round(state.left)
            settings.y = Round(state.top)
            settings.width = Round(state.width)
            settings.height = Round(state.height)
            settings.scale = state.scale
        else
            settings.initialized = false
        end
    end

    self:ApplyTarget(targetKey)
    self:UpdatePreviews()
    return true
end

function MH:ResetAll()
    for _, targetKey in ipairs(self.targetOrder) do
        self:ResetTarget(targetKey)
    end
end

function MH:GetTargetStatus(targetKey)
    local settings = self:GetElementSettings(targetKey)
    if not settings then
        return "unknown"
    end

    if targetKey == "group" then
        return string.format(
            "%s: enabled=%s, x=%d, y=%d, scale=%d%%",
            self:GetTargetName(targetKey),
            tostring(settings.enabled),
            settings.x,
            settings.y,
            Round(settings.scale * 100)
        )
    end

    return string.format(
        "%s: enabled=%s, x=%d, y=%d, width=%d, height=%d, scale=%d%%",
        self:GetTargetName(targetKey),
        tostring(settings.enabled),
        settings.x,
        settings.y,
        settings.width,
        settings.height,
        Round(settings.scale * 100)
    )
end

function MH:PrintStatus(targetKey)
    if targetKey and TARGET_NAMES[targetKey] then
        Print(self:GetTargetStatus(targetKey))
        return
    end

    for _, key in ipairs(self.targetOrder) do
        Print(self:GetTargetStatus(key))
    end
end

function MH:PrintHelp()
    Print("Settings: Options > Settings > Addons > Movable HUD")
    Print("/hudmover status [chat|quest|group]")
    Print("/hudmover set <element> <x|y|width|height|scale|enabled> <value>")
    Print("/hudmover reset <chat|quest|group|all>")
end

function MH:HandleCommand(text)
    local args = Tokenize(text)
    local command = string.lower(args[1] or "")

    if command == "" or command == "open" or command == "settings" then
        Print("Open Options > Settings > Addons > Movable HUD.")
    elseif command == "help" then
        self:PrintHelp()
    elseif command == "status" or command == "show" then
        local targetKey = string.lower(args[2] or "")
        self:PrintStatus(TARGET_NAMES[targetKey] and targetKey or nil)
    elseif command == "set" then
        local targetKey = string.lower(args[2] or "")
        local property = string.lower(args[3] or "")
        local value = args[4]
        if not TARGET_NAMES[targetKey] or not value or not self:SetElementValue(targetKey, property, value) then
            Print("Usage: /hudmover set <chat|quest|group> <x|y|width|height|scale|enabled> <value>")
            return
        end
        Print(self:GetTargetStatus(targetKey))
    elseif command == "reset" then
        local targetKey = string.lower(args[2] or "")
        if targetKey == "all" then
            self:ResetAll()
            Print("All supported HUD elements reset.")
        elseif TARGET_NAMES[targetKey] then
            self:ResetTarget(targetKey)
            Print(string.format("%s reset.", self:GetTargetName(targetKey)))
        else
            Print("Usage: /hudmover reset <chat|quest|group|all>")
        end
    else
        self:PrintHelp()
    end
end


local function GetControlRect(control)
    if not IsControl(control) then
        return nil
    end

    -- GetScreenRect reports the control's final on-screen rectangle, including
    -- parent transforms and scale. Fall back to the standard edge methods for
    -- clients where GetScreenRect is unavailable.
    if control.GetScreenRect then
        local ok, left, top, right, bottom = pcall(control.GetScreenRect, control)
        left = tonumber(left)
        top = tonumber(top)
        right = tonumber(right)
        bottom = tonumber(bottom)
        if ok and left and top and right and bottom and right > left and bottom > top then
            return left, top, right, bottom
        end
    end

    local left = tonumber(control:GetLeft())
    local top = tonumber(control:GetTop())
    local right = control.GetRight and tonumber(control:GetRight()) or nil
    local bottom = control.GetBottom and tonumber(control:GetBottom()) or nil

    if left and top and right and bottom and right > left and bottom > top then
        return left, top, right, bottom
    end

    if not left or not top then
        return nil
    end

    local width = math.max(1, tonumber(control:GetWidth()) or 1)
    local height = math.max(1, tonumber(control:GetHeight()) or 1)
    local scale = 1
    if control.GetEffectiveScale then
        scale = tonumber(control:GetEffectiveScale()) or 1
    elseif control.GetScale then
        scale = tonumber(control:GetScale()) or 1
    end

    return left, top, left + (width * scale), top + (height * scale)
end

function MH:CreatePreviewControl(targetKey)
    self.previewControls = self.previewControls or {}
    if self.previewControls[targetKey] then
        return self.previewControls[targetKey]
    end

    local controlName = "MovableHUDPreview" .. string.upper(string.sub(targetKey, 1, 1)) .. string.sub(targetKey, 2)
    local root = WINDOW_MANAGER:CreateTopLevelWindow(controlName)
    root:SetMouseEnabled(false)
    root:SetMovable(false)
    root:SetClampedToScreen(false)
    root:SetDrawTier(DT_HIGH)
    root:SetDrawLayer(DL_OVERLAY)
    root:SetDrawLevel(10000)
    root:SetHidden(true)

    local fill = WINDOW_MANAGER:CreateControl(controlName .. "Fill", root, CT_TEXTURE)
    fill:SetAnchorFill(root)
    fill:SetColor(0.10, 0.55, 0.85, 0.10)

    local borders = {}
    for index = 1, 4 do
        local border = WINDOW_MANAGER:CreateControl(controlName .. "Border" .. tostring(index), root, CT_TEXTURE)
        border:SetColor(0.35, 0.85, 1.00, 0.95)
        borders[index] = border
    end
    borders[1]:SetAnchor(TOPLEFT, root, TOPLEFT, 0, 0)
    borders[1]:SetAnchor(TOPRIGHT, root, TOPRIGHT, 0, 0)
    borders[1]:SetHeight(3)
    borders[2]:SetAnchor(BOTTOMLEFT, root, BOTTOMLEFT, 0, 0)
    borders[2]:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, 0, 0)
    borders[2]:SetHeight(3)
    borders[3]:SetAnchor(TOPLEFT, root, TOPLEFT, 0, 0)
    borders[3]:SetAnchor(BOTTOMLEFT, root, BOTTOMLEFT, 0, 0)
    borders[3]:SetWidth(3)
    borders[4]:SetAnchor(TOPRIGHT, root, TOPRIGHT, 0, 0)
    borders[4]:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, 0, 0)
    borders[4]:SetWidth(3)

    local label = WINDOW_MANAGER:CreateControl(controlName .. "Label", root, CT_LABEL)
    label:SetAnchor(CENTER, root, CENTER, 0, 0)
    label:SetFont("ZoFontGamepadBold34")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(1, 1, 1, 1)
    label:SetText(self:GetTargetName(targetKey) .. " Preview")
    root.movableHUDPreviewLabel = label

    root.movableHUDColorParts = { fill = fill, borders = borders }
    self.previewControls[targetKey] = root
    return root
end

function MH:GetPrimaryPreviewControl(targetKey)
    local controls = self:GetTargetControls(targetKey, true)
    local bestControl
    local bestArea = 0

    for _, control in ipairs(controls) do
        local left, top, right, bottom = GetControlRect(control)
        if left and top and right and bottom then
            local area = math.max(0, right - left) * math.max(0, bottom - top)
            if area > bestArea then
                bestArea = area
                bestControl = control
            end
        end
    end

    return bestControl
end

function MH:AnchorPreviewToControl(preview, control)
    if not preview or not control then
        return false
    end

    local left, top, right, bottom = GetControlRect(control)
    if not left or not top or not right or not bottom then
        return false
    end

    -- Two direct anchors make the outline follow the real control instead of a
    -- separately calculated approximation. This keeps it aligned through UI
    -- scale, safe-zone, and parent-transform differences.
    preview:ClearAnchors()
    preview:SetScale(1)
    preview:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
    preview:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0)
    return true
end

function MH:GetGroupPreviewGeometry()
    local controls = self:GetGroupControls(true)
    local left, top, right, bottom

    for _, control in ipairs(controls) do
        local controlLeft, controlTop, controlRight, controlBottom = GetControlRect(control)
        if controlLeft and controlTop and controlRight and controlBottom then
            left = left and math.min(left, controlLeft) or controlLeft
            top = top and math.min(top, controlTop) or controlTop
            right = right and math.max(right, controlRight) or controlRight
            bottom = bottom and math.max(bottom, controlBottom) or controlBottom
        end
    end

    if left and top and right and bottom then
        local runtime = self:GetRuntime("group")
        runtime.lastPreviewRect = {
            left = left,
            top = top,
            right = right,
            bottom = bottom,
        }
        return left, top, right, bottom
    end

    -- Do not invent a fallback position. An arbitrary group rectangle was the
    -- reason previews could appear in the wrong part of the settings screen.
    -- Reuse the last exact group bounds from this session when available.
    local runtime = self:GetRuntime("group")
    local previous = runtime.lastPreviewRect
    if previous then
        return previous.left, previous.top, previous.right, previous.bottom
    end

    return nil
end

function MH:InstallPreviewVisibilityTracking()
    if self.previewVisibilityInstalled then return end
    self.previewVisibilityInstalled = true
    if CALLBACK_MANAGER then
        CALLBACK_MANAGER:RegisterCallback("LibHarvensAddonSettings_AddonSelected", function(_, panel)
            MH.previewPanelOwner = panel
            if panel ~= MH.settingsPanel then
                MH:ClearElementPreview()
            end
        end)
    end
end

function MH:IsSettingsPanelVisible(ignorePreviewPreference)
    if not self.saved or (not ignorePreviewPreference and self.saved.previewEnabled == false) then return false end
    local library = LibHarvensAddonSettings
    local scene = library and library.scene
    -- Console owns a dedicated scene. General options visibility and the library's
    -- sticky panel.selected flag do not establish ownership of the displayed page.
    if not scene or not scene.GetState then return false end
    if self.previewTrackedScene ~= scene then
        self.previewTrackedScene = scene
        if scene.RegisterCallback then
            scene:RegisterCallback("StateChange", function(_, state)
                if state ~= SCENE_SHOWING and state ~= SCENE_SHOWN then
                    MH:ClearElementPreview()
                end
            end)
        end
    end
    if self.previewPanelOwner ~= self.settingsPanel or not self.settingsPanel then return false end
    local state = scene:GetState()
    return state == SCENE_SHOWING or state == SCENE_SHOWN
end
function MH:HidePreviews()
    for _, control in pairs(self.previewControls or {}) do
        control:SetHidden(true)
    end
end

function MH:UpdatePreviews()
    if not self:IsSettingsPanelVisible() then
        self:HidePreviews()
        return
    end

    for _, targetKey in ipairs(self.targetOrder) do
        local settings = self:GetElementSettings(targetKey)
        local preview = self:CreatePreviewControl(targetKey)
        local positioned = false

        if settings and settings.enabled then
            if targetKey == "group" then
                local left, top, right, bottom = self:GetGroupPreviewGeometry()
                if left and top and right and bottom then
                    preview:ClearAnchors()
                    preview:SetScale(1)
                    preview:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
                    preview:SetDimensions(
                        math.max(1, right - left),
                        math.max(1, bottom - top)
                    )
                    positioned = true
                end
            else
                local targetControl = self:GetPrimaryPreviewControl(targetKey)
                positioned = self:AnchorPreviewToControl(preview, targetControl)
            end
        end

        preview:SetHidden(not positioned)
    end
end

function MH:SetPreviewEnabled(enabled)
    if not self.saved then
        return
    end
    self.saved.previewEnabled = enabled ~= false
    self:UpdatePreviews()
end

function MH:InstallHooks()
    if SecurePostHook and GamepadChatContainer and GamepadChatContainer.LoadSettings then
        SecurePostHook(GamepadChatContainer, "LoadSettings", function(container)
            if GAMEPAD_CHAT_SYSTEM and container == GAMEPAD_CHAT_SYSTEM.primaryContainer then
                MH:ApplySoon(0, "chat")
            end
        end)
    end

    if CALLBACK_MANAGER then
        CALLBACK_MANAGER:RegisterCallback("GamepadChatSystemActiveOnScreen", function()
            MH:ApplySoon(0, "chat")
        end)
    end

    if SecurePostHook and ZO_UnitFrames_Manager and ZO_UnitFrames_Manager.CreateFrame then
        SecurePostHook(ZO_UnitFrames_Manager, "CreateFrame", function(manager, unitTag)
            -- CreateFrame also reanchors an existing frame. Forget its old native
            -- snapshot so the next apply uses the current small-group/raid layout.
            local frameObject = manager and manager.GetFrame and manager:GetFrame(unitTag)
            local control = frameObject and (frameObject.control or frameObject.frame or frameObject)
            if IsControl(control) then
                local runtime = MH:GetRuntime("group")
                runtime.controlStates[control] = nil
                runtime.groupBaseStates[control] = nil
            end

            MH:ApplySoon(0, "group")
            MH:ApplySoon(100, "group")
        end)
    end
end

function MH:RegisterSafeEvent(eventCode, suffix, callback)
    if eventCode then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. suffix, eventCode, callback)
    end
end

function MH:Initialize()
    self.saved = ZO_SavedVars:NewAccountWide(
        SAVED_VARIABLES_NAME,
        SAVED_VARIABLES_VERSION,
        nil,
        DEFAULTS
    )
    self:NormalizeSavedVariables()

    if self.RegisterSettingsPanel then
        self:RegisterSettingsPanel()
    end

    self:InstallHooks()

    SLASH_COMMANDS["/hudmover"] = function(text)
        MH:HandleCommand(text)
    end
    SLASH_COMMANDS["/movablehud"] = SLASH_COMMANDS["/hudmover"]
    SLASH_COMMANDS["/mcb"] = SLASH_COMMANDS["/hudmover"]

    self:RegisterSafeEvent(EVENT_PLAYER_ACTIVATED, "_PlayerActivated", function()
        MH:ApplySoon(0)
        MH:ApplySoon(250)
        MH:ApplySoon(1000)
    end)

    self:RegisterSafeEvent(EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, "_GamepadMode", function()
        -- Keep the original snapshots intact; clearing them here could accidentally
        -- treat an already-moved control as its new default position.
        MH:ApplySoon(0)
        MH:ApplySoon(500)
    end)

    self:RegisterSafeEvent(EVENT_GROUP_UPDATE, "_GroupUpdate", function()
        MH:ApplySoon(0, "group")
        MH:ApplySoon(150, "group")
    end)
    self:RegisterSafeEvent(EVENT_GROUP_MEMBER_JOINED, "_GroupJoined", function()
        MH:ApplySoon(100, "group")
    end)
    self:RegisterSafeEvent(EVENT_GROUP_MEMBER_LEFT, "_GroupLeft", function()
        MH:ApplySoon(100, "group")
        MH:ApplySoon(500, "group")
    end)

    self:RegisterSafeEvent(EVENT_ACTIVE_COMPANION_STATE_CHANGED, "_CompanionState", function()
        -- ESO may create, hide, or re-anchor the local companion frame after the
        -- state event. Reapply twice so the saved group offset wins afterward.
        MH:ApplySoon(0, "group")
        MH:ApplySoon(250, "group")
    end)

    self:RegisterSafeEvent(EVENT_QUEST_ADDED, "_QuestAdded", function()
        MH:ApplySoon(0, "quest")
    end)
    self:RegisterSafeEvent(EVENT_QUEST_REMOVED, "_QuestRemoved", function()
        MH:ApplySoon(0, "quest")
    end)
    self:RegisterSafeEvent(EVENT_QUEST_ADVANCED, "_QuestAdvanced", function()
        MH:ApplySoon(0, "quest")
    end)

    -- A low-frequency guard catches native re-anchoring paths without hard-coding
    -- every internal callback used by the three HUD systems.
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_PersistenceGuard", 1000, function()
        MH:ApplyAll()
    end)

    -- The native settings library owns controller focus. This lightweight guard
    -- only shows or hides passive placement outlines while our page is selected.
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_PreviewGuard", 100, function()
        MH:UpdatePreviews()
    end)

    self:ApplySoon(0)
    self:ApplySoon(500)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    MH:Initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)










