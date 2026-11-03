-- ConsoleMetrics_Integration.lua
-- Gamepad main-menu (Journal) integration: adds a "Console Metrics" entry and
-- keybinds to the journal scenes so the dialog can be opened without slash commands.

function ConsoleMetrics:RegisterJournalSceneKeybinds()
    if not LibConsoleDialogs or not SCENE_MANAGER then
        return 0
    end

    self.registeredJournalScenes = self.registeredJournalScenes or {}
    local candidateScenes = {
        "gamepad_journal_root",
        "gamepad_journal",
        "journal",
        "gamepad_quest_journal",
        "gamepad_activities",
    }

    local function TryRegisterScene(sceneName, scene)
        if not sceneName or not scene or self.registeredJournalScenes[sceneName] then
            return false
        end

        LibConsoleDialogs:RegisterKeybind(scene, {
            name = function()
                return "Console Metrics"
            end,
            tooltip = function()
                return "Open Console Metrics"
            end,
            callback = function()
                self:OpenFightViewDialog(true)
            end,
            visible = function()
                return true
            end,
            enabled = function()
                return true
            end,
            order = 2200,
        })

        self.registeredJournalScenes[sceneName] = true
        return true
    end

    local added = 0
    for i = 1, #candidateScenes do
        local sceneName = candidateScenes[i]
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if TryRegisterScene(sceneName, scene) then
            added = added + 1
        end
    end

    if SCENE_MANAGER.scenes then
        for sceneName, scene in pairs(SCENE_MANAGER.scenes) do
            local nameLower = string.lower(tostring(sceneName))
            if string.find(nameLower, "journal", 1, true) ~= nil then
                if TryRegisterScene(sceneName, scene) then
                    added = added + 1
                end
            end
        end
    end

    return added
end

function ConsoleMetrics:InsertIntoJournalMenu()
    local openDialog = function()
        self:OpenFightViewDialog(true)
    end

    local function ToText(value)
        if type(value) == "number" then
            return tostring(GetString(value))
        end
        if value == nil then
            return ""
        end
        return tostring(value)
    end

    local function AddSubmenuEntry(subMenu)
        for _, subItem in ipairs(subMenu) do
            if subItem and (subItem.consoleMetricsEntry or subItem.name == "Console Metrics") then
                return false
            end
        end

        subMenu[#subMenu + 1] = {
            name = "Console Metrics",
            icon = "EsoUI/Art/Journal/journal_tabicon_log_up.dds",
            activatedCallback = openDialog,
            callback = openDialog,
            enabled = function()
                return true
            end,
            consoleMetricsEntry = true,
        }
        return true
    end

    local injected = false
    local journalLabel = SI_MAIN_MENU_JOURNAL and GetString(SI_MAIN_MENU_JOURNAL) or "Journal"

    -- Preferred path: patch live gamepad menu data and add an item into Journal's submenu.
    if MAIN_MENU_GAMEPAD and MAIN_MENU_GAMEPAD.categoryList and MAIN_MENU_GAMEPAD.categoryList.dataList then
        local list = MAIN_MENU_GAMEPAD.categoryList
        local dataList = list.dataList

        for _, entry in ipairs(dataList) do
            local data = entry and entry.data
            local idText = string.lower(ToText(entry and entry.id))
            local textLower = string.lower(ToText(data and data.text))
            local nameLower = string.lower(ToText(data and data.name))

            local isJournal = idText:find("journal", 1, true) ~= nil
                or textLower == string.lower(journalLabel)
                or nameLower == string.lower(journalLabel)
                or textLower == "journal"
                or nameLower == "journal"

            if isJournal and data and type(data.subMenu) == "table" then
                AddSubmenuEntry(data.subMenu)
                if list.Commit then
                    list:Commit()
                end
                injected = true
                break
            end
        end
    end

    if not injected and type(ZO_MENU_ENTRIES) == "table" then
        for _, entry in ipairs(ZO_MENU_ENTRIES) do
            local data = entry and entry.data
            local idText = entry and entry.id and string.lower(tostring(entry.id)) or ""

            local nameText = ToText(data and data.name)
            local nameLower = string.lower(nameText)

            local isJournal = idText:find("journal", 1, true) ~= nil
                or nameText == journalLabel
                or nameLower == "journal"

            if isJournal and data then
                data.subMenu = data.subMenu or {}
                AddSubmenuEntry(data.subMenu)

                injected = true
                break
            end
        end
    end

    -- Last-resort fallback for builds with no Journal submenu structure.
    if not injected and MAIN_MENU_GAMEPAD and MAIN_MENU_GAMEPAD.categoryList then
        local list = MAIN_MENU_GAMEPAD.categoryList
        local dataList = list.dataList
        if dataList then
            local alreadyPresent = false
            local insertIndex = #dataList + 1

            for i, entry in ipairs(dataList) do
                local data = entry and entry.data
                if data and data.consoleMetricsEntry then
                    alreadyPresent = true
                    break
                end
                local text = ToText(data and data.text)
                if text == journalLabel or text == "Journal" then
                    insertIndex = i + 1
                end
            end

            -- RefreshJournalIntegration runs on every main-menu show; never insert twice.
            if not alreadyPresent then
                local entryData = ZO_GamepadEntryData:New("Console Metrics", "EsoUI/Art/Journal/journal_tabicon_log_up.dds")
                entryData.consoleMetricsEntry = true
                entryData.callback = openDialog

                if entryData.SetIconTintOnSelection then
                    entryData:SetIconTintOnSelection(true)
                end

                table.insert(dataList, insertIndex, { template = "ZO_GamepadMenuEntryTemplate", data = entryData })
                if list.Commit then
                    list:Commit()
                end
            end
            injected = true
        end
    end

    if injected and MAIN_MENU_GAMEPAD and MAIN_MENU_GAMEPAD.RefreshMainList then
        MAIN_MENU_GAMEPAD:RefreshMainList()
    end

    self.journalMenuInserted = injected
    return injected
end

function ConsoleMetrics:RefreshJournalIntegration(showStatus)
    local menuReady = self:InsertIntoJournalMenu()
    local sceneHooks = self:RegisterJournalSceneKeybinds()

    if showStatus then
        if menuReady then
            self:Print(string.format("Journal menu item ready (scene hooks: %d)", sceneHooks))
        else
            self:Print("Journal menu item still unavailable in current menu state")
        end
    end

    return menuReady, sceneHooks
end

-- Registers the one-shot injection on player activation (with retries) and the
-- main-menu scene callback that keeps the entry present.
function ConsoleMetrics:RegisterJournalIntegrationHooks()
    local injectName = self.name .. "JournalMenuInject"
    EVENT_MANAGER:RegisterForEvent(injectName, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(injectName, EVENT_PLAYER_ACTIVATED)

        local initialMenuReady, initialSceneCount = self:RefreshJournalIntegration(false)
        if initialMenuReady then
            self:DebugPrint(string.format("Journal menu item ready (scene hooks: %d)", initialSceneCount))
            return
        end

        local retryName = self.name .. "JournalMenuRetry"
        local attempts = 0
        EVENT_MANAGER:RegisterForUpdate(retryName, 1500, function()
            attempts = attempts + 1
            local menuReady, hookedScenes = self:RefreshJournalIntegration(false)
            if menuReady then
                self:DebugPrint(string.format("Journal menu item ready (scene hooks: %d)", hookedScenes))
                EVENT_MANAGER:UnregisterForUpdate(retryName)
            elseif attempts >= 20 then
                self:DebugPrint("Journal menu item not ready yet. Open Main Menu, highlight Journal, then /reloadui.")
                EVENT_MANAGER:UnregisterForUpdate(retryName)
            end
        end)
    end)

    if MAIN_MENU_GAMEPAD_SCENE and MAIN_MENU_GAMEPAD_SCENE.RegisterCallback then
        MAIN_MENU_GAMEPAD_SCENE:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                self:RefreshJournalIntegration(false)
            end
        end)
    end
end
