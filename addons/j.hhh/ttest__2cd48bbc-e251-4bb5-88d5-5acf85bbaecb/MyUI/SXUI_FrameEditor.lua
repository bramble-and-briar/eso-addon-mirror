-- Controller-safe wrapper for Bandit's movable-frame mode. The ESO settings
-- list is suspended and hidden while an editor-only keybind group owns D-Pad,
-- A and B. Mouse/pointer dragging remains available on the original controls.
BUI.FrameEditor = BUI.FrameEditor or {}
local Editor = BUI.FrameEditor
local Guard = { state = nil }
local MOVE_STEP = 8
local DUPLICATE_INPUT_WINDOW_MS = 60
local LINKED_FRAMES = {
    BUI_PlayerFrame = {"BUI_BuffsP", "BUI_BuffsPas"},
    BUI_TargetFrame = {"BUI_BuffsT"},
}

local function OptionsAreShowing(options)
    if not options or type(options.IsShowing) ~= "function" then return false end
    local ok, showing = pcall(options.IsShowing, options)
    return ok and showing == true
end

local function KeyIs(key, name)
    local expected = rawget(_G, name)
    return expected ~= nil and key == expected
end

local function NowMilliseconds()
    local clock = rawget(_G, "GetFrameTimeMilliseconds") or rawget(_G, "GetGameTimeMilliseconds")
    if type(clock) == "function" then return tonumber(clock()) or 0 end
    return 0
end

local function SnapshotAnchors(control)
    local anchors = {}
    local count = control.GetNumAnchors and control:GetNumAnchors() or 0
    for index = 0, count - 1 do
        local anchor = {control:GetAnchor(index)}
        if type(anchor[1]) == "boolean" then table.remove(anchor, 1) end
        if anchor[1] then anchors[#anchors + 1] = anchor end
    end
    if #anchors == 0 then
        local anchor = {control:GetAnchor()}
        if type(anchor[1]) == "boolean" then table.remove(anchor, 1) end
        if anchor[1] then anchors[1] = anchor end
    end
    return anchors
end

local function RestoreAnchors(control, anchors)
    if not control or not anchors then return end
    control:ClearAnchors()
    for _, anchor in ipairs(anchors) do control:SetAnchor(unpack(anchor)) end
end

local function MoveControl(control, dx, dy)
    if not control or type(control.GetCenter) ~= "function" then return end
    local x, y = control:GetCenter()
    local rootX, rootY = GuiRoot:GetCenter()
    if not x or not y or not rootX or not rootY then return end
    control:ClearAnchors()
    control:SetAnchor(CENTER, GuiRoot, CENTER, x - rootX + dx, y - rootY + dy)
end

local function EntryName(entry)
    if not entry then return "Frame" end
    if entry.saveName then return tostring(entry.saveName) end
    local control = entry.control
    local name = control and type(control.GetName) == "function" and control:GetName() or "Frame"
    name = string.gsub(tostring(name), "^BUI_", "")
    name = string.gsub(name, "_", " ")
    return name
end

local function RefreshEditorKeybinds()
    local strip = rawget(_G, "KEYBIND_STRIP")
    if strip and type(strip.UpdateKeybindButtonGroup) == "function" and Editor.keybindDescriptor then
        strip:UpdateKeybindButtonGroup(Editor.keybindDescriptor)
    end
end

local function CloseEditor()
    if BUI.move and BUI.Menu and type(BUI.Menu.MoveFrames) == "function" then
        BUI.Menu.MoveFrames(false)
    end
end

local editorKeybindDescriptor = {
    alignment = rawget(_G, "KEYBIND_STRIP_ALIGN_LEFT"),
    {
        name = function() return Editor.mode == "move" and "Place Frame" or "Move Frame" end,
        keybind = "UI_SHORTCUT_PRIMARY",
        visible = function() return Editor.active == true end,
        callback = function() Editor:PrimaryAction() end,
    },
    {
        name = function() return Editor.mode == "move" and "Cancel Move" or "Exit Move Frames" end,
        keybind = "UI_SHORTCUT_NEGATIVE",
        visible = function() return Guard.state ~= nil end,
        callback = function()
            if Editor.mode == "move" then Editor:CancelMove() else CloseEditor() end
        end,
    },
    {
        name = "Frame Editor Up",
        keybind = "UI_SHORTCUT_INPUT_UP",
        ethereal = true,
        visible = function() return Editor.active == true end,
        callback = function() Editor:Direction(0, -1) end,
    },
    {
        name = "Frame Editor Down",
        keybind = "UI_SHORTCUT_INPUT_DOWN",
        ethereal = true,
        visible = function() return Editor.active == true end,
        callback = function() Editor:Direction(0, 1) end,
    },
    {
        name = "Frame Editor Left",
        keybind = "UI_SHORTCUT_INPUT_LEFT",
        ethereal = true,
        visible = function() return Editor.active == true end,
        callback = function() Editor:Direction(-1, 0) end,
    },
    {
        name = "Frame Editor Right",
        keybind = "UI_SHORTCUT_INPUT_RIGHT",
        ethereal = true,
        visible = function() return Editor.active == true end,
        callback = function() Editor:Direction(1, 0) end,
    },
}
Editor.keybindDescriptor = editorKeybindDescriptor

function Editor:CreateHighlight()
    if self.highlightWindow then return end
    local window = WINDOW_MANAGER:CreateTopLevelWindow("SXUI_FrameEditorSelection")
    window:SetDrawTier(DT_HIGH)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawLevel(20)
    window:SetMouseEnabled(false)
    window:SetHidden(true)
    local backdrop = WINDOW_MANAGER:CreateControl("SXUI_FrameEditorSelectionBackdrop", window, CT_BACKDROP)
    backdrop:SetAnchorFill(window)
    backdrop:SetCenterColor(0.9, 0.75, 0.1, 0.08)
    backdrop:SetEdgeColor(1, 0.82, 0.15, 1)
    if backdrop.SetEdgeTexture then backdrop:SetEdgeTexture("", 8, 2, 2) end
    self.highlightWindow = window
    self.highlightBackdrop = backdrop
end

function Editor:GetSelectedEntry()
    return self.frames and self.selection and self.frames[self.selection]
end

function Editor:GetLinkedControls(entry)
    local controls = {}
    local control = entry and entry.control
    local name = control and type(control.GetName) == "function" and control:GetName()
    for _, linkedName in ipairs(name and LINKED_FRAMES[name] or {}) do
        local linked = rawget(_G, linkedName)
        if linked and type(linked.IsHidden) == "function" and not linked:IsHidden() then
            controls[#controls + 1] = linked
        end
    end
    return controls
end

function Editor:RefreshHighlight()
    local entry = self:GetSelectedEntry()
    local window = self.highlightWindow
    if not self.active or not entry or not window then
        if window then window:SetHidden(true) end
        return
    end

    local control = entry.control
    window:ClearAnchors()
    window:SetAnchor(TOPLEFT, control, TOPLEFT, -6, -6)
    window:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 6, 6)
    self.highlightBackdrop:SetEdgeColor(self.mode == "move" and 1 or 1, self.mode == "move" and 0.25 or 0.82, 0.12, 1)
    window:SetHidden(false)

    local hint = rawget(_G, "SXUI_MoveModeHintText")
    if hint and type(hint.SetText) == "function" then
        local name = EntryName(entry)
        if self.mode == "move" then
            hint:SetText("MOVE: " .. name .. "\nD-Pad = move  •  A = place  •  B = cancel move  •  View = exit and save")
        else
            hint:SetText("SELECT: " .. name .. "\nD-Pad = select frame  •  A = move  •  B or View = exit and save")
        end
    end
    RefreshEditorKeybinds()
end

function Editor:Activate(source)
    self.frames = {}
    local seen = {}
    for _, sourceEntry in ipairs(source or {}) do
        local entry = type(sourceEntry) == "table" and sourceEntry or {control = sourceEntry}
        local control = entry.control
        if control and not seen[control] and type(control.GetCenter) == "function"
            and type(control.GetDimensions) == "function" then
            local x, y = control:GetCenter()
            local width, height = control:GetDimensions()
            if x and y and (tonumber(width) or 0) > 0 and (tonumber(height) or 0) > 0 then
                seen[control] = true
                self.frames[#self.frames + 1] = entry
            end
        end
    end
    if #self.frames == 0 then
        self.active = false
        return false
    end
    self:CreateHighlight()
    self.active = true
    self.mode = "select"
    self.selection = 1
    self.lastDirectionTime = nil
    self.lastDirectionX = nil
    self.lastDirectionY = nil
    self:RefreshHighlight()
    return true
end

function Editor:Deactivate(confirmCurrentMove)
    if self.mode == "move" then
        if confirmCurrentMove then self:ConfirmMove() else self:CancelMove() end
    end
    self.active = false
    self.mode = nil
    self.selection = nil
    self.frames = nil
    self.moveSnapshot = nil
    if self.highlightWindow then self.highlightWindow:SetHidden(true) end
end

function Editor:SelectDirection(dx, dy)
    if self.mode ~= "select" then return end
    local current = self:GetSelectedEntry()
    if not current then return end
    local cx, cy = current.control:GetCenter()
    local best, bestScore
    for index, entry in ipairs(self.frames) do
        if index ~= self.selection then
            local x, y = entry.control:GetCenter()
            if x and y and cx and cy then
                local horizontal, vertical = x - cx, y - cy
                local along = horizontal * dx + vertical * dy
                local cross = math.abs(horizontal * dy - vertical * dx)
                if along > 1 then
                    local score = along + cross * 2
                    if not bestScore or score < bestScore then best, bestScore = index, score end
                end
            end
        end
    end
    if not best then
        local delta = (dx + dy) > 0 and 1 or -1
        best = ((self.selection - 1 + delta) % #self.frames) + 1
    end
    self.selection = best
    self:RefreshHighlight()
end

function Editor:BeginMove()
    if self.mode ~= "select" then return end
    local entry = self:GetSelectedEntry()
    if not entry then return end
    local snapshot = {}
    snapshot[#snapshot + 1] = {control = entry.control, anchors = SnapshotAnchors(entry.control)}
    for _, control in ipairs(self:GetLinkedControls(entry)) do
        snapshot[#snapshot + 1] = {control = control, anchors = SnapshotAnchors(control)}
    end
    self.moveSnapshot = snapshot
    self.mode = "move"
    self:RefreshHighlight()
end

function Editor:Nudge(dx, dy)
    local entry = self:GetSelectedEntry()
    if self.mode ~= "move" or not entry then return end
    local amountX, amountY = dx * MOVE_STEP, dy * MOVE_STEP
    MoveControl(entry.control, amountX, amountY)
    for _, control in ipairs(self:GetLinkedControls(entry)) do MoveControl(control, amountX, amountY) end
    self:RefreshHighlight()
end

function Editor:ConfirmMove()
    local entry = self:GetSelectedEntry()
    if self.mode ~= "move" or not entry then return end
    if type(entry.onConfirm) == "function" then
        entry.onConfirm(entry.control)
    elseif BUI.Menu and type(BUI.Menu.SaveAnchor) == "function" then
        BUI.Menu:SaveAnchor(entry.control, nil, entry.saveName, entry.anchorPoint)
        for _, control in ipairs(self:GetLinkedControls(entry)) do BUI.Menu:SaveAnchor(control) end
    end
    if entry.isDefault and BUI.Frames and type(BUI.Frames.ZO_Frame_reposition) == "function" then
        BUI.Frames.ZO_Frame_reposition()
    end
    self.moveSnapshot = nil
    self.mode = "select"
    self:RefreshHighlight()
end

function Editor:CancelMove()
    if self.mode ~= "move" then return end
    local entry = self:GetSelectedEntry()
    for _, snapshot in ipairs(self.moveSnapshot or {}) do RestoreAnchors(snapshot.control, snapshot.anchors) end
    if entry and type(entry.onCancel) == "function" then entry.onCancel(entry.control) end
    self.moveSnapshot = nil
    self.mode = "select"
    self:RefreshHighlight()
end

function Editor:PrimaryAction()
    if not self.active then return end
    if self.mode == "move" then self:ConfirmMove() else self:BeginMove() end
end

function Editor:Direction(dx, dy)
    if not self.active then return end
    local now = NowMilliseconds()
    if now > 0 and self.lastDirectionTime and dx == self.lastDirectionX and dy == self.lastDirectionY
        and now - self.lastDirectionTime < DUPLICATE_INPUT_WINDOW_MS then
        return
    end
    self.lastDirectionTime, self.lastDirectionX, self.lastDirectionY = now, dx, dy
    if self.mode == "move" then self:Nudge(dx, dy) else self:SelectDirection(dx, dy) end
end

function Editor:HandleKeyDown(key)
    if not self.active then return false end
    if KeyIs(key, "KEY_UPARROW") or KeyIs(key, "KEY_GAMEPAD_DPAD_UP") then
        self:Direction(0, -1)
        return true
    elseif KeyIs(key, "KEY_DOWNARROW") or KeyIs(key, "KEY_GAMEPAD_DPAD_DOWN") then
        self:Direction(0, 1)
        return true
    elseif KeyIs(key, "KEY_LEFTARROW") or KeyIs(key, "KEY_GAMEPAD_DPAD_LEFT") then
        self:Direction(-1, 0)
        return true
    elseif KeyIs(key, "KEY_RIGHTARROW") or KeyIs(key, "KEY_GAMEPAD_DPAD_RIGHT") then
        self:Direction(1, 0)
        return true
    elseif KeyIs(key, "KEY_ESCAPE") or KeyIs(key, "KEY_GAMEPAD_BACK") or KeyIs(key, "KEY_GAMEPAD_BACK_HOLD") then
        CloseEditor()
        return true
    end
    -- A and B must reach the editor keybind descriptor. Returning false here
    -- avoids the raw-key interception that previously prevented A callbacks.
    return false
end

function Guard:Suspend()
    if self.state then return end

    local state = {strip = rawget(_G, "KEYBIND_STRIP")}
    self.state = state
    local options = rawget(_G, "GAMEPAD_OPTIONS")
    if not OptionsAreShowing(options) or type(options.GetCurrentList) ~= "function" then return end

    local list = options:GetCurrentList()
    if not list then return end
    state.options = options
    state.list = list
    state.primaryWasActive = options.isPrimaryActionActive == true

    if state.strip and type(state.strip.RemoveKeybindButtonGroup) == "function" then
        if options.keybindStripDescriptor then
            state.strip:RemoveKeybindButtonGroup(options.keybindStripDescriptor)
            state.baseRemoved = true
        end
        if state.primaryWasActive and options.primaryActionDescriptor then
            state.strip:RemoveKeybindButtonGroup(options.primaryActionDescriptor)
            state.primaryRemoved = true
        end
        if options.panelKeybindDescriptor then
            state.strip:RemoveKeybindButtonGroup(options.panelKeybindDescriptor)
            state.panelRemoved = true
        end
    end

    if type(options.DeactivateSelectedControl) == "function" then
        options:DeactivateSelectedControl()
    else
        options.isPrimaryActionActive = false
    end
    if type(options.DeactivateCurrentList) == "function" then
        options:DeactivateCurrentList()
        state.listDeactivated = true
    end

    local optionsControl = options.control
    if optionsControl and type(optionsControl.IsHidden) == "function"
        and type(optionsControl.SetHidden) == "function" then
        state.optionsControl = optionsControl
        state.optionsControlWasHidden = optionsControl:IsHidden()
        optionsControl:SetHidden(true)
    end

    local quadrantBackground = rawget(_G, "ZO_SharedGamepadNavQuadrant_1_Background")
    if quadrantBackground and type(quadrantBackground.IsHidden) == "function"
        and type(quadrantBackground.SetHidden) == "function" then
        state.quadrantBackground = quadrantBackground
        state.quadrantBackgroundWasHidden = quadrantBackground:IsHidden()
        quadrantBackground:SetHidden(true)
    end

    local tooltips = rawget(_G, "GAMEPAD_TOOLTIPS")
    local leftTooltip = rawget(_G, "GAMEPAD_LEFT_TOOLTIP")
    if tooltips and leftTooltip and type(tooltips.Reset) == "function" then tooltips:Reset(leftTooltip) end

    if state.strip and type(state.strip.AddKeybindButtonGroup) == "function" then
        state.strip:AddKeybindButtonGroup(editorKeybindDescriptor)
        state.editorKeybindAdded = true
    end
end

function Guard:Restore()
    local state = self.state
    self.state = nil
    if not state then return end

    local strip = state.strip
    if state.editorKeybindAdded and strip and type(strip.RemoveKeybindButtonGroup) == "function" then
        strip:RemoveKeybindButtonGroup(editorKeybindDescriptor)
    end

    local options = state.options
    if not options or not OptionsAreShowing(options) then return end
    if type(options.GetCurrentList) ~= "function" or options:GetCurrentList() ~= state.list then return end

    if state.optionsControl then state.optionsControl:SetHidden(state.optionsControlWasHidden) end
    if state.quadrantBackground then state.quadrantBackground:SetHidden(state.quadrantBackgroundWasHidden) end

    if state.baseRemoved and strip and type(strip.AddKeybindButtonGroup) == "function" then
        strip:AddKeybindButtonGroup(options.keybindStripDescriptor)
    end
    if state.panelRemoved and strip and type(strip.AddKeybindButtonGroup) == "function" then
        strip:AddKeybindButtonGroup(options.panelKeybindDescriptor)
    end

    options.isPrimaryActionActive = false
    if state.listDeactivated and type(options.ActivateCurrentList) == "function" then options:ActivateCurrentList() end
    if type(options.OnSelectionChanged) == "function" then
        options:OnSelectionChanged(state.list)
    elseif state.primaryWasActive and state.primaryRemoved and not options.isPrimaryActionActive
        and strip and type(strip.AddKeybindButtonGroup) == "function" then
        strip:AddKeybindButtonGroup(options.primaryActionDescriptor)
        options.isPrimaryActionActive = true
    end
end

Editor.inputGuard = Guard
Editor.active = false

if BUI.Menu and type(BUI.Menu.MoveFrames) == "function" and not BUI.Menu.SXUIFrameMoveGuardInstalled then
    local OriginalMoveFrames = BUI.Menu.MoveFrames
    BUI.Menu.SXUIFrameMoveGuardInstalled = true

    function BUI.Menu.MoveFrames(move)
        if move then
            Guard:Suspend()
        else
            Editor:Deactivate(true)
        end

        local ok, result = pcall(OriginalMoveFrames, move)
        if not ok then
            Editor:Deactivate(false)
            Guard:Restore()
            error(result)
        end

        if move and BUI.move == true then
            local editorOk, editorResult = pcall(Editor.Activate, Editor, BUI.SXUI_MovableFrames)
            if not editorOk then
                pcall(OriginalMoveFrames, false)
                Editor:Deactivate(false)
                Guard:Restore()
                error(editorResult)
            end
        else
            Editor:Deactivate(true)
            Guard:Restore()
        end
        return result
    end
end

function Editor:Open()
    if self.active or BUI.move or not BUI.Menu or type(BUI.Menu.MoveFrames) ~= "function" then return false end
    BUI.Menu.MoveFrames(true)
    return BUI.move == true
end

function Editor:Close()
    CloseEditor()
end
