local A = OneChat

function A:GetTabState(container, window)
    if not window.tab.oneChatCursorHook then
        window.tab.oneChatCursorHook = true
        ZO_PostHookHandler(window.tab, "OnMouseEnter", function()
            WINDOW_MANAGER:SetMouseCursor(MOUSE_CURSOR_DO_NOT_CARE)
        end)
    end
    local state = self.windows[window]
    if state then return state end
    local saved = self.loadingTabs and self.character.tabs[container.id]
    saved = saved and saved[window.tab.index]
    -- Runtime object identity follows rename/reorder/transfer. Across sessions
    -- vanilla only exposes positions and names; reject mismatched snapshots.
    if saved and saved.name == container:GetTabName(window.tab.index) then
        state = saved
    else
        state = { incoming = {}, outgoing = {} }
    end
    state.incoming, state.outgoing = state.incoming or {}, state.outgoing or {}
    self.windows[window] = state
    for _, t in ipairs(self.tokens) do
        if state.incoming[t.key] == nil then
            state.incoming[t.key] = IsChatContainerTabCategoryEnabled(container.id, window.tab.index, t.category)
        else
            container:SetWindowFilterEnabled(window.tab.index, t.category, state.incoming[t.key])
        end
        if not t.incomingOnly and state.outgoing[t.key] == nil then state.outgoing[t.key] = true end
    end
    self:NormalizeZoneState(container, window, state)
    return state
end

function A:SnapshotTabs()
    if self.loadingTabs or self.resettingTabs then return end
    local tabs = {}
    for _, container in ipairs(self.chat.containers) do
        local records = {}
        tabs[container.id] = records
        for index, window in ipairs(container.windows) do
            if not window.combatLog then
                local state = self:GetTabState(container, window)
                state.name = container:GetTabName(index)
                records[index] = state
            end
        end
    end
    self.character.tabs = tabs
end

function A:ActivateTab(container, window)
    -- The first tab of a new native container is clicked before its C-side
    -- category record exists. LoadWindowSettings will activate it afterward.
    if window and not self.windows[window]
        and window.tab.index > GetNumChatContainerTabs(container.id) then return end
    if window and not window.combatLog then
        self.activeContainer, self.activeWindow = container, window
        self:GetTabState(container, window)
        self:RestoreSelection()
    end
end

function A:InstallTabs()
    self.loadingTabs = true
    for _, container in ipairs(self.chat.containers) do
        for _, window in ipairs(container.windows) do
            if not window.combatLog then self:GetTabState(container, window) end
        end
    end
    self.loadingTabs = false
    SecurePostHook(SharedChatContainer, "HandleTabClick", function(container, tab)
        if container.system == A.chat then A:ActivateTab(container, container.windows[tab.index]) end
    end)
    SecurePostHook(SharedChatContainer, "LoadWindowSettings", function(container, window)
        if container.system == A.chat and not window.combatLog then
            A:GetTabState(container, window)
            if container.currentBuffer == window.buffer then A:ActivateTab(container, window) end
            A:SnapshotTabs()
        end
    end)
    -- Pooled controls must not inherit a deleted tab's preferences/history.
    ZO_PreHook(SharedChatContainer, "RemoveWindow", function(container, index, freeOption)
        local window = container.windows[index]
        -- Vanilla's local DONT_FREE sentinel is true; false/nil mean deletion.
        if container.system == A.chat and window and freeOption ~= true then
            A.windows[window] = nil
            if A.ReleaseMessages then A:ReleaseMessages(window) end
        end
    end)
    for _, method in ipairs({ "SetTabName", "RemoveWindow", "ForceWindowIntoView" }) do
        SecurePostHook(SharedChatContainer, method, function(container)
            if container.system == A.chat and not A.chat.isTransferring then
                if A.activeWindow and not A.windows[A.activeWindow] then
                    local primary = A.chat.primaryContainer
                    local tab = primary.tabGroup:GetClickedButton()
                    A:ActivateTab(primary, tab and primary.windows[tab.index] or primary.windows[1])
                end
                A:SnapshotTabs()
            end
        end)
    end
    SecurePostHook(self.chat, "TransferWindow", function() A:SnapshotTabs() end)
    ZO_PreHook(self.chat, "ResetChat", function()
        A.resettingTabs = true
        for window in pairs(A.windows) do
            if A.ReleaseMessages then A:ReleaseMessages(window) end
        end
        A.windows = setmetatable({}, { __mode = "k" })
        A.character.tabs = {}
        A.activeWindow, A.activeContainer = nil, nil
    end)
    SecurePostHook(self.chat, "ResetChat", function()
        A.resettingTabs = false
        local primary = A.chat.primaryContainer
        local tab = primary.tabGroup:GetClickedButton()
        A:ActivateTab(primary, tab and primary.windows[tab.index] or primary.windows[1])
        A:SnapshotTabs()
    end)
    local container = self.chat.primaryContainer
    local tab = container.tabGroup:GetClickedButton()
    self:ActivateTab(container, tab and container.windows[tab.index] or container.windows[1])
    self:SnapshotTabs()
end

function A:RefreshMembership()
    self:BuildChannels()
    for _, container in ipairs(self.chat.containers) do
        for _, window in ipairs(container.windows) do
            local state = self.windows[window]
            if state then
                for _, t in ipairs(self.tokens) do
                    if state.incoming[t.key] == nil then state.incoming[t.key] = true end
                    if not t.incomingOnly and state.outgoing[t.key] == nil then state.outgoing[t.key] = true end
                    container:SetWindowFilterEnabled(window.tab.index, t.category, state.incoming[t.key])
                end
            end
        end
    end
    -- Keep a draft's temporary channel intact during roster/permission events.
    if not self.temporary then self:RestoreSelection() end
    if self.RefreshOptions then self:RefreshOptions() end
end
