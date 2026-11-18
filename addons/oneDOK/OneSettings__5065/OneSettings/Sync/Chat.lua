local OS = OneSettings
local Windows = OS.modules.windows

function Windows:CaptureChatLayout()
    local result = {}
    local categories = GetNumChatCategories()
    for index, container in ipairs(KEYBOARD_CHAT_SYSTEM.containers or {}) do
        local saved = { tabs = {}, colors = { GetChatContainerColors(container.id) } }
        for tabIndex = 1, GetNumChatContainerTabs(container.id) do
            local name, locked, interactable, combatLog, timestamps = GetChatContainerTabInfo(container.id, tabIndex)
            local tab = { name = name, locked = locked == true, interactable = interactable == true,
                combatLog = combatLog == true, timestamps = timestamps == true, categories = {} }
            for category = 1, categories do
                tab.categories[category] = IsChatContainerTabCategoryEnabled(container.id, tabIndex, category)
            end
            saved.tabs[tabIndex] = tab
        end
        result[index] = saved
    end
    return result
end

function Windows:ApplyChatLayout(layout)
    local system = KEYBOARD_CHAT_SYSTEM
    local categories = GetNumChatCategories()
    for index, saved in ipairs(layout) do
        local container = system.containers[index] or system:CreateChatContainer()
        for tabIndex, tab in ipairs(saved.tabs) do
            local matched
            local combatLog = tab.combatLog and system.combatLogObject ~= nil
            for candidate = tabIndex, #container.windows do
                if (container:IsCombatLog(candidate) == true) == combatLog then
                    matched = matched or candidate
                    if container:GetTabName(candidate) == tab.name then
                        matched = candidate
                        break
                    end
                end
            end
            if not matched then
                local added
                if combatLog then
                    added = container:AddCombatWindow(tab.name)
                else
                    added = container:AddWindow(tab.name)
                end
                matched = added.tab.index
            end
            if matched ~= tabIndex then
                container.insertIndex = tabIndex
                container:TransferWindow(matched, container)
            end
            container:SetTabName(tabIndex, tab.name)
            container:SetLocked(tabIndex, tab.locked)
            container:SetInteractivity(tabIndex, tab.interactable)
            container:SetTimestampsEnabled(tabIndex, tab.timestamps)
            for category = 1, categories do
                local enabled = tab.categories[category]
                if enabled ~= nil then container:SetWindowFilterEnabled(tabIndex, category, enabled) end
            end
        end
        for tabIndex = #container.windows, #saved.tabs + 1, -1 do
            container:RemoveWindow(tabIndex)
        end
        container:SetBackgroundColor(unpack(saved.colors))
    end
    for index = #system.containers, #layout + 1, -1 do
        local container = system.containers[index]
        for tabIndex = #container.windows, 1, -1 do container:RemoveWindow(tabIndex) end
    end
    system.hasCombatLog = false
    for _, container in ipairs(system.containers) do
        for tabIndex = 1, #container.windows do
            system.hasCombatLog = system.hasCombatLog or container:IsCombatLog(tabIndex)
        end
    end
end
