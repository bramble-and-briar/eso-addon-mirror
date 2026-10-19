function ConsoleMetrics:OpenFightViewDialog(forceLive)
    -- PC keyboard path: use the custom scrollable window
    if not IsConsoleUI() and not (type(IsGamepadPreferred) == "function" and IsGamepadPreferred()) then
        self:OpenPCDialog(forceLive)
        return
    end

    -- Console / gamepad path: LibConsoleDialogs
    if not LibConsoleDialogs or not LibHarvensAddonSettings then
        self:Print("LibConsoleDialogs not found. Install/enable it in this game folder to use /cm view.")
        return
    end

    if forceLive then
        self.viewFightIndex = 0
        self.dialogPanel    = "main"
    elseif not self.dialogPanel then
        self.dialogPanel = "main"
    end

    if self.ui.root then
        self.ui.root:SetHidden(true)
    end

    if not self.ui.fightViewDialog then
        self.ui.fightViewDialog = LibConsoleDialogs:Create("Console Metrics")
    end

    self:PopulateFightViewDialog(self.ui.fightViewDialog)
    self.ui.fightViewDialog:Show()
    self:ArmDialogAutoHide()
    self.dialogRefreshAtMs    = 0
    self.lastDialogRefreshKey = nil
    self.wasFightViewDialogShowing = true
end

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
            local insertIndex = #dataList + 1

            for i, entry in ipairs(dataList) do
                local data = entry and entry.data
                local text = ToText(data and data.text)

                if text == journalLabel or text == "Journal" then
                    insertIndex = i + 1
                    break
                end
            end

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

function ConsoleMetrics:Print(message)
    d(string.format("|cFF6A00[%s]|r %s", self.name, tostring(message)))
end

function ConsoleMetrics:LinkBuildToChat()
    local frontBarCategory = type(HOTBAR_CATEGORY_PRIMARY) == "number" and HOTBAR_CATEGORY_PRIMARY or nil
    local backBarCategory = type(HOTBAR_CATEGORY_BACKUP) == "number" and HOTBAR_CATEGORY_BACKUP or nil
    local frontBar = BuildActionBarSnapshot(frontBarCategory)
    local backBar = BuildActionBarSnapshot(backBarCategory)
    local championSnapshot = BuildChampionSnapshot()
    local equippedSets = BuildEquippedSetSummary()
    local boons = BuildActiveBoonSnapshot()

    local function ShortName(name, maxLen)
        if type(name) ~= "string" or name == "" then return "?" end
        maxLen = maxLen or 14
        if #name <= maxLen then return name end
        local first = string.match(name, "^(%S+)")
        if first and #first <= maxLen then return first end
        return string.sub(name, 1, maxLen)
    end

    local function BarNames(bar)
        local names = {}
        for i = 1, #bar do
            local name = bar[i].abilityName
            if name and name ~= "Empty" and name ~= "" then
                names[#names + 1] = ShortName(name, 13)
            end
        end
        if #names == 0 then return "-" end
        return table.concat(names, ", ")
    end

    local function BucketText(entries)
        if not entries or #entries == 0 then return nil end
        local parts = {}
        for i = 1, #entries do
            local e = entries[i]
            local pts = (e.points and e.points > 0) and tostring(e.points) or "0"
            local stars = #(e.stars or {}) > 0 and ("[" .. table.concat(e.stars, ",") .. "]") or ""
            parts[#parts + 1] = ShortName(e.name, 10) .. ":" .. pts .. stars
        end
        return table.concat(parts, " ")
    end

    local cp = championSnapshot.totalPoints and NumberText(championSnapshot.totalPoints) or "?"
    local wf = BucketText(championSnapshot.warfare)
    local fn = BucketText(championSnapshot.fitness)
    local cr = BucketText(championSnapshot.craft)

    local cpText = "CP:" .. cp
    if wf then cpText = cpText .. " WF(" .. wf .. ")" end
    if fn then cpText = cpText .. " FN(" .. fn .. ")" end
    if cr then cpText = cpText .. " CR(" .. cr .. ")" end

    local setNames = {}
    for i = 1, #equippedSets do
        local s = equippedSets[i]
        if s.setName and s.setName ~= "" then
            setNames[#setNames + 1] = ShortName(s.setName, 18) .. "(" .. (s.numEquipped or 0) .. ")"
        end
    end
    local setsText = #setNames > 0 and table.concat(setNames, ", ") or "-"

    local boonText = #boons > 0 and ShortName(boons[1], 18) or "-"

    local parts = {
        "[CM Build]",
        cpText,
        "Sets: " .. setsText,
        "F[" .. BarNames(frontBar) .. "]",
        "B[" .. BarNames(backBar) .. "]",
        "Boon: " .. boonText,
    }
    local chatLine = table.concat(parts, " | ")

    if #chatLine > 350 then
        chatLine = string.sub(chatLine, 1, 347) .. "..."
    end

    if type(CHAT_SYSTEM) == "table" and type(CHAT_SYSTEM.StartTextEntry) == "function" then
        CHAT_SYSTEM:StartTextEntry(chatLine)
        self:Print("Chat pre-filled - choose a channel and confirm to send.")
    else
        self:Print(chatLine)
        self:Print("(Copy the line above and paste it into chat.)")
    end
end

function ConsoleMetrics:PrintBuildSnapshotDebug(reason)
    local source = reason or "manual"
    local frontBarCategory = type(HOTBAR_CATEGORY_PRIMARY) == "number" and HOTBAR_CATEGORY_PRIMARY or nil
    local backBarCategory = type(HOTBAR_CATEGORY_BACKUP) == "number" and HOTBAR_CATEGORY_BACKUP or nil
    local frontBar = BuildActionBarSnapshot(frontBarCategory)
    local backBar = BuildActionBarSnapshot(backBarCategory)
    local championSnapshot = BuildChampionSnapshot()
    local equippedSets = BuildEquippedSetSummary()
    local weaponEffects = BuildWeaponEffectSnapshot()
    local procTimers = self:BuildProcTimerSnapshot()
    local boons = BuildActiveBoonSnapshot()

    local function JoinOrFallback(values, fallback)
        if type(values) ~= "table" or #values == 0 then
            return fallback
        end
        return table.concat(values, ", ")
    end

    local function PrintBar(label, entries)
        self:Print(string.format("DEBUGBUILD [%s]", label))
        for i = 1, #entries do
            local entry = entries[i]
            self:Print(string.format(
                "  %s -> %s (id=%d)",
                entry.slotLabel or string.format("Slot %d", i),
                entry.abilityName or "Empty",
                entry.abilityId or 0
            ))
        end
    end

    local function PrintChampionBucket(label, entries)
        self:Print(string.format("DEBUGBUILD [%s]", label))
        if #entries == 0 then
            self:Print("  unavailable")
            return
        end
        for i = 1, #entries do
            local entry = entries[i]
            self:Print(string.format(
                "  %s pts=%s stars=%s",
                entry.name or "Unknown",
                NumberText(entry.points or 0),
                JoinOrFallback(entry.stars, "none")
            ))
            -- Print debug info when stars are missing (even if points show)
            if #(entry.stars or {}) == 0 and type(entry.debug) == "table" then
                self:Print(string.format(
                    "    probe disciplineId=%s index=%s type=%s",
                    tostring(entry.debug.disciplineId),
                    tostring(entry.debug.disciplineIndex),
                    tostring(entry.debug.disciplineType)
                ))
                local pointsProbes = entry.debug.pointsProbes or {}
                if #pointsProbes > 0 then
                    for j = 1, #pointsProbes do
                        self:Print("    " .. tostring(pointsProbes[j]))
                    end
                else
                    self:Print("    no discipline point probe results")
                end

                local skillPointProbes = entry.debug.skillPointProbes or {}
                if #skillPointProbes > 0 then
                    for j = 1, math.min(12, #skillPointProbes) do
                        self:Print("    " .. tostring(skillPointProbes[j]))
                    end
                else
                    self:Print("    no skill point probe results")
                end
            end
        end
        -- Print slot debug info at end of each bucket if any stars are missing
        if type(championSnapshot._slotDebugInfo) == "table" then
            local hasEmptyStars = false
            for i = 1, #entries do
                if #(entries[i].stars or {}) == 0 then
                    hasEmptyStars = true
                    break
                end
            end
            if hasEmptyStars then
                local foundIdsList = {}
                if type(championSnapshot._slotDebugInfo.foundIds) == "table" then
                    for id, _ in pairs(championSnapshot._slotDebugInfo.foundIds) do
                        foundIdsList[#foundIdsList + 1] = tostring(id)
                    end
                end
                self:Print(string.format(
                    "    SLOT DEBUG: numSlots=%s probeMax=%s foundIds=%s",
                    tostring(championSnapshot._slotDebugInfo.resolvedNumSlots),
                    tostring(championSnapshot._slotDebugInfo.probeMax),
                    #foundIdsList > 0 and table.concat(foundIdsList, ",") or "none"
                ))
                local probes = championSnapshot._slotDebugInfo.probes or {}
                if #probes > 0 then
                    for j = 1, math.min(12, #probes) do
                        self:Print("    " .. tostring(probes[j]))
                    end
                else
                    self:Print("    SLOT DEBUG: no probes found any slotted skills")
                end
            end
        end
    end

    self:Print(string.format(
        "DEBUGBUILD[%s] cp=%s sets=%d weapons=%d procs=%d boons=%d",
        source,
        championSnapshot.totalPoints and NumberText(championSnapshot.totalPoints) or "n/a",
        #equippedSets,
        #weaponEffects,
        #procTimers,
        #boons
    ))

    PrintBar("Front Bar", frontBar)
    PrintBar("Back Bar", backBar)
    PrintChampionBucket("Warfare", championSnapshot.warfare)
    PrintChampionBucket("Fitness", championSnapshot.fitness)
    PrintChampionBucket("Craft", championSnapshot.craft)

    self:Print("DEBUGBUILD [Equipped Sets]")
    if #equippedSets == 0 then
        self:Print("  unavailable")
    else
        for i = 1, #equippedSets do
            local entry = equippedSets[i]
            self:Print(string.format(
                "  %s (%d/%d) slots=%s",
                entry.setName or "Unknown Set",
                entry.numEquipped or 0,
                entry.maxEquipped or 0,
                JoinOrFallback(entry.slots, "none")
            ))
        end
    end

    self:Print("DEBUGBUILD [Weapon Effects]")
    if #weaponEffects == 0 then
        self:Print("  unavailable")
    else
        for i = 1, #weaponEffects do
            local entry = weaponEffects[i]
            self:Print(string.format(
                "  %s item=%s enchant=%s poison=%s",
                entry.label or string.format("Weapon %d", i),
                entry.itemText or "Unknown",
                entry.enchantText or "Unavailable",
                entry.poisonText or "None"
            ))
        end
    end

    self:Print("DEBUGBUILD [Proc Timers]")
    if #procTimers == 0 then
        self:Print("  unavailable")
    else
        for i = 1, #procTimers do
            local entry = procTimers[i]
            self:Print(string.format(
                "  %s state=%s cd=%.1fs equipped=%d/%d slots=%s pct=%s cm=%s",
                entry.label or "Unknown Proc",
                entry.stateText or "Ready",
                (entry.cooldownMs or 0) / 1000,
                entry.numEquipped or 0,
                entry.maxEquipped or 0,
                JoinOrFallback(entry.slots, "none"),
                tostring(entry.fromPCT == true),
                tostring(entry.fromCustomRule == true)
            ))
        end
    end

    self:Print("DEBUGBUILD [Boon / Mundus]")
    if #boons == 0 then
        self:Print("  unavailable")
    else
        for i = 1, #boons do
            self:Print(string.format("  %s", boons[i]))
        end
    end
end

