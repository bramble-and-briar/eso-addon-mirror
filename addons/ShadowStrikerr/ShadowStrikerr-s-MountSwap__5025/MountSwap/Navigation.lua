local M = MountSwap

function M:HookControl(control, event, callback)
    local previous = control:GetHandler(event)
    control:SetHandler(event, function(...)
        if previous then previous(...) end
        callback(...)
    end)
end

function M:ManageWindow(window, width, height)
    window.mountSwapWidth, window.mountSwapHeight = width, height
    -- A shown registered top level already keeps ESO's UI cursor alive.
    -- locksUIMode=true also blocks OnToggleGameMenuBinding before HideTopLevels,
    -- trapping Escape instead of letting native dismissal/menu routing run.
    SCENE_MANAGER:RegisterTopLevel(window, false)
    self:HookControl(window, 'OnShow', function() self:SyncGamepad() end)
    self:HookControl(window, 'OnHide', function()
        if self.editingControl and self.editingControl.mountSwapRoot == window then
            self.cancelText = true
            self.editingControl:LoseFocus()
        end
        self:SyncGamepad()
    end)
end

function M:SetWindowHidden(window, hidden)
    if not window then return end
    self.visibilityDepth = (self.visibilityDepth or 0) + 1
    if hidden then SCENE_MANAGER:HideTopLevel(window) else SCENE_MANAGER:ShowTopLevel(window) end
    self.visibilityDepth = self.visibilityDepth - 1
    -- Wait until ESO has acquired/released its UI input layer before acquiring ours.
    if self.visibilityDepth == 0 then
        self:SyncGamepad()
        if not hidden then
            self.gamepadShowToken=(self.gamepadShowToken or 0)+1
            local token=self.gamepadShowToken
            -- Scene/UI mode activation can push its layer after ShowTopLevel
            -- returns. Acquire ours once after that transition has completed.
            zo_callLater(function()
                if self.gamepadShowToken~=token or window:IsHidden() then return end
                if self.gamepadLayerActive then
                    RemoveActionLayerByName('MountSwapGamepad');self.gamepadLayerActive=false
                end
                self:SyncGamepad()
            end,0)
        end
    end
end

function M:CloseWindows()
    self.visibilityDepth = (self.visibilityDepth or 0) + 1
    self.cancelText = true
    if self.editingControl and self.editingControl.mountSwapRoot then self.editingControl:LoseFocus() end
    for _, window in pairs({self.textWindow, self.controllerMenu, self.picker, self.window}) do
        self:SetWindowHidden(window, true)
    end
    self.menuStack, self.menuState = {}, nil
    self.visibilityDepth = self.visibilityDepth - 1
    self:SyncGamepad()
end

function M:HookTextEntry(edit, root, native)
    if edit.mountSwapFocusHooked then return end
    edit.mountSwapFocusHooked, edit.mountSwapRoot = true, root
    self:HookControl(edit, 'OnFocusGained', function(control)
        self.editingControl = control
        self:SyncGamepad()
        if native and IsInGamepadPreferredMode() and ZO_GamepadEditBox_FocusGained then
            control.mountSwapNativeEditing = true
            ZO_GamepadEditBox_FocusGained(control)
        end
    end)
    self:HookControl(edit, 'OnFocusLost', function(control)
        if control.mountSwapNativeEditing and ZO_GamepadEditBox_FocusLost then ZO_GamepadEditBox_FocusLost(control) end
        control.mountSwapNativeEditing = nil
        if self.editingControl == control then self.editingControl = nil end
        self:SyncGamepad()
        -- Focus ownership may be cleared by ESO after the handler returns.
        zo_callLater(function() self:SyncGamepad() end, 0)
    end)
end

function M:InitializeNavigation()
    if self.navigationInitialized then return end
    self.navigationInitialized = true
    for _, event in pairs({EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, EVENT_KEYBINDING_SET,
        EVENT_KEYBINDING_CLEARED, EVENT_INPUT_TYPE_CHANGED, EVENT_SCREEN_RESIZED}) do
        EVENT_MANAGER:RegisterForEvent('MountSwapNavigation', event, function()
            if self:GamepadRoot() or self.gamepadLayerActive then self:SyncGamepad() end
        end)
    end
    EVENT_MANAGER:RegisterForEvent('MountSwapNavigation', EVENT_PLAYER_DEACTIVATED, function()
        self.navigationSuspended = true
        self:SyncGamepad()
    end)
    EVENT_MANAGER:RegisterForEvent('MountSwapNavigation', EVENT_PLAYER_ACTIVATED, function()
        self.navigationSuspended = false
        if self:GamepadRoot() then self:SyncGamepad() end
    end)
    -- Chat is an external edit control; suspend navigation while the player types.
    for _, system in pairs({KEYBOARD_CHAT_SYSTEM, GAMEPAD_CHAT_SYSTEM}) do
        local entry = system.textEntry and system.textEntry.editControl
        if entry then self:HookTextEntry(entry, nil, false) end
    end
end
