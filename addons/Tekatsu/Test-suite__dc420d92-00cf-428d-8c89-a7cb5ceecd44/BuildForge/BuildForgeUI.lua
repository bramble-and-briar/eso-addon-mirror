local BF_HiddenListScreen = ZO_Gamepad_ParametricList_Screen:Subclass()

function BF_HiddenListScreen:New(control)
    return ZO_Gamepad_ParametricList_Screen.New(self, control)
end

function BF_HiddenListScreen:Initialize(control)
    ZO_Gamepad_ParametricList_Screen.Initialize(self, control, false, true, BF.scene)
end

function BF_HiddenListScreen:PerformUpdate()
end

function BF_HiddenListScreen:InitializeKeybindStripDescriptors()
    self.keybindStripDescriptor = {
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = "Record Build",
            keybind = "UI_SHORTCUT_SECONDARY",
            callback = function() BF.RecordCurrentBuild() end,
        },
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = "Compare",
            keybind = "UI_SHORTCUT_TERTIARY",
            callback = function() BF.CompareSelectedBuild() end,
            visible = function() return BF.GetSelectedBuild() ~= nil end,
        },
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = "Apply All",
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function() BF.ApplySelectedBuildAll() end,
            visible = function() return BF.GetSelectedBuild() ~= nil end,
        },
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = "Export",
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            callback = function() BF.ExportSelectedBuild() end,
            visible = function() return BF.GetSelectedBuild() ~= nil end,
        },
    }
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON, function() BF.CloseUI() end)
end

function BF.BuildBuildList()
    BF.ui.sortedBuilds = {}
    if not BF.savedVars or not BF.savedVars.builds then return end
    for id, build in pairs(BF.savedVars.builds) do
        build.id = build.id or id
        table.insert(BF.ui.sortedBuilds, build)
    end
    table.sort(BF.ui.sortedBuilds, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
    if BF.ui.selectedBuildIndex > #BF.ui.sortedBuilds then
        BF.ui.selectedBuildIndex = math.max(1, #BF.ui.sortedBuilds)
    end
end

function BF.GetSelectedBuild()
    return BF.ui.sortedBuilds and BF.ui.sortedBuilds[BF.ui.selectedBuildIndex] or nil
end

function BF.SyncHiddenList()
    if not BF.hiddenList then return end
    BF.hiddenList:Clear()
    BF.BuildBuildList()
    local count = math.max(#BF.ui.sortedBuilds, 1)
    for i = 1, count do
        local build = BF.ui.sortedBuilds[i]
        local entryData = ZO_GamepadEntryData:New(build and build.name or "No saved builds")
        entryData.index = i
        BF.hiddenList:AddEntry("ZO_GamepadItemEntryTemplate", entryData)
    end
    BF.hiddenList:Commit()
    if BF.ui.selectedBuildIndex and BF.ui.selectedBuildIndex <= count then
        BF.hiddenList:SetSelectedIndexWithoutAnimation(BF.ui.selectedBuildIndex)
    end
end

function BF.ScrollBuilds(direction)
    local count = #BF.ui.sortedBuilds
    if count == 0 then return end
    if direction == "up" then
        BF.ui.selectedBuildIndex = math.max(1, BF.ui.selectedBuildIndex - 1)
    else
        BF.ui.selectedBuildIndex = math.min(count, BF.ui.selectedBuildIndex + 1)
    end
    if BF.ui.selectedBuildIndex <= BF.ui.buildScrollOffset then
        BF.ui.buildScrollOffset = BF.ui.selectedBuildIndex - 1
    elseif BF.ui.selectedBuildIndex > BF.ui.buildScrollOffset + BF.ui.maxVisibleBuilds then
        BF.ui.buildScrollOffset = BF.ui.selectedBuildIndex - BF.ui.maxVisibleBuilds
    end
    BF.RefreshUI()
end

function BF.RefreshUI()
    local ui = BF_Main_UI
    if not ui then return end
    BF.BuildBuildList()

    local leftCol = ui:GetNamedChild("LeftCol")
    local centerCol = ui:GetNamedChild("CenterCol")
    local rightCol = ui:GetNamedChild("RightCol")

    if leftCol then
        local list = leftCol:GetNamedChild("List")
        local selection = list and list:GetNamedChild("SelectionFrame")
        if selection then
            local visibleIndex = BF.ui.selectedBuildIndex - BF.ui.buildScrollOffset
            if visibleIndex >= 1 and visibleIndex <= BF.ui.maxVisibleBuilds and #BF.ui.sortedBuilds > 0 then
                selection:ClearAnchors()
                selection:SetAnchor(TOPLEFT, list, TOPLEFT, 5, (visibleIndex - 1) * 55)
                selection:SetHidden(false)
            else
                selection:SetHidden(true)
            end
        end
        for i = 1, BF.ui.maxVisibleBuilds do
            local label = list and list:GetNamedChild("Build" .. i)
            local build = BF.ui.sortedBuilds[BF.ui.buildScrollOffset + i]
            if label then
                if build then
                    local prefix = (BF.ui.buildScrollOffset + i == BF.ui.selectedBuildIndex) and "|cFFD700> |r" or ""
                    label:SetText(string.format("%s|cFFFFFF%s|r\n|c888888%d gear • %s|r", prefix, build.name or "Unnamed", build.gearCount or 0, build.className or "Unknown"))
                else
                    label:SetText(i == 1 and "|c888888No saved builds yet. Press [Y] to record.|r" or "")
                end
            end
        end
        local footer = leftCol:GetNamedChild("Footer")
        if footer then footer:SetText(string.format("%d local builds", #BF.ui.sortedBuilds)) end
    end

    local selected = BF.GetSelectedBuild()
    if centerCol then
        local buildName = centerCol:GetNamedChild("BuildName")
        local character = centerCol:GetNamedChild("Character")
        local stats = centerCol:GetNamedChild("Stats")
        local summary = centerCol:GetNamedChild("Summary")
        local actions = centerCol:GetNamedChild("Actions")
        local warning = centerCol:GetNamedChild("Warning")
        if selected then
            if buildName then buildName:SetText("|c88CCFF" .. (selected.name or "Unnamed Build") .. "|r") end
            if character then character:SetText("|cFFFFFF" .. (selected.characterName or "Unknown Character") .. " • " .. (selected.className or "Unknown Class") .. "|r") end
            if stats then stats:SetText(string.format("|cFFFFAADate:|r %s   |cFFFFAACP:|r %d   |cFFFFAAGear:|r %d", BF.FormatTimestamp(selected.timestamp), selected.championPoints or 0, selected.gearCount or 0)) end
            if summary then
                local compare = BF.ui.lastCompareSummary
                if compare and compare.buildName == selected.name then
                    summary:SetText(string.format("|c00FF00Last Compare|r\nMatched: %d / %d\nMissing: %d\nFailed: %d\nScanned: %d items in %d bags", compare.matched or 0, compare.total or 0, compare.missing or 0, compare.failed or 0, compare.scannedItems or 0, compare.scannedBags or 0))
                else
                    summary:SetText("|cAAAAAARecord your current setup, export creator builds, compare owned gear, and apply every non-private automation path ESO allows.|r")
                end
            end
        else
            if buildName then buildName:SetText("|c88CCFFNo Build Selected|r") end
            if character then character:SetText("|c888888Record your current character build to begin.|r") end
            if stats then stats:SetText("") end
            if summary then summary:SetText("|cAAAAAAUse Record Build to save equipped gear, skills, CP slots, attributes, and Mundus locally.|r") end
        end
        if actions then
            actions:SetText("|cFFFFFF[A]|r Apply all possible\n|cFFFFFF[Y]|r Record current build\n|cFFFFFF[X]|r Compare owned gear\n|cFFFFFF[RB]|r Export build\n|cFFFFFF[B]|r Close")
        end
        if warning then warning:SetText("Skips private functions, attempts normal/protected build automation, and reports failures.") end
    end

    if rightCol then
        local list = rightCol:GetNamedChild("MissingList")
        local combined = {}
        for _, item in ipairs(BF.runtime.missingGear or {}) do table.insert(combined, { item = item, reason = "missing" }) end
        for _, item in ipairs(BF.runtime.failedGear or {}) do table.insert(combined, { item = item.required or item, reason = item.reason or "failed" }) end
        for _, result in ipairs(BF.runtime.automationResults or {}) do table.insert(combined, { automation = result }) end
        for i = 1, 12 do
            local label = list and list:GetNamedChild("Missing" .. i)
            local row = combined[i]
            if label then
                if row and row.automation then
                    label:SetText(string.format("|c%s%s|r\n|c888888%s|r", row.automation.ok and "00FF00" or "FFAA44", row.automation.area or "Automation", row.automation.message or ""))
                elseif row and row.item then
                    label:SetText(string.format("|cFFAA44%s|r\n|c888888%s • %s|r", row.item.itemName or "Unknown", row.item.slotName or "gear", tostring(row.reason)))
                else
                    label:SetText(i == 1 and "|c888888No missing/failed gear from last compare.|r" or "")
                end
            end
        end
        local footer = rightCol:GetNamedChild("Footer")
        if footer then footer:SetText("Gear matching uses item, set, trait, and enchant IDs") end
    end
end

function BF.InitScene()
    if BF.ui.sceneInitialized then return end
    if not BF_Main_UI then return end
    local hiddenControl = WINDOW_MANAGER:CreateControlFromVirtual("BF_HiddenList", GuiRoot, "BF_HiddenList_Screen")
    hiddenControl:SetHidden(true)
    hiddenControl:SetAlpha(0)
    BF.scene = ZO_Scene:New("buildForgeScene", SCENE_MANAGER)
    BF.scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    BF.scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
    BF.scene:AddFragment(ZO_SimpleSceneFragment:New(BF_Main_UI))
    BF.scene:AddFragment(ZO_SimpleSceneFragment:New(hiddenControl))
    BF.hiddenListScreen = BF_HiddenListScreen:New(hiddenControl)
    BF.hiddenList = BF.hiddenListScreen:GetMainList()
    BF.hiddenList:AddDataTemplate("ZO_GamepadItemEntryTemplate", function(control, data) end, ZO_GamepadMenuEntryTemplateParametricListFunction)
    BF.hiddenList.MovePrevious = function() BF.ScrollBuilds("up") end
    BF.hiddenList.MoveNext = function() BF.ScrollBuilds("down") end
    BF.hiddenList:SetOnSelectedDataChangedCallback(function(listControl, selectedData)
        if selectedData and selectedData.index then
            BF.ui.selectedBuildIndex = selectedData.index
            BF.RefreshUI()
        end
    end)
    BF.scene:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            BF.ui.isOpen = true
            BF.SyncHiddenList()
            BF.RefreshUI()
            if KEYBIND_STRIP and BF.hiddenListScreen then KEYBIND_STRIP:AddKeybindButtonGroup(BF.hiddenListScreen.keybindStripDescriptor) end
        elseif newState == SCENE_HIDING then
            if KEYBIND_STRIP and BF.hiddenListScreen then KEYBIND_STRIP:RemoveKeybindButtonGroup(BF.hiddenListScreen.keybindStripDescriptor) end
        elseif newState == SCENE_HIDDEN then
            BF.ui.isOpen = false
        end
    end)
    BF.ui.sceneInitialized = true
end

function BF.OpenUI()
    BF.InitScene()
    if BF.scene then SCENE_MANAGER:Push("buildForgeScene") end
end

function BF.CloseUI()
    if BF.scene then SCENE_MANAGER:Hide("buildForgeScene") end
end

function BF.ToggleUI()
    if BF.ui.isOpen then BF.CloseUI() else BF.OpenUI() end
end

function BF.RecordCurrentBuild()
    local build = BF.BuildRecorder.RecordCurrentBuild()
    if build then
        BF.BuildBuildList()
        for i, saved in ipairs(BF.ui.sortedBuilds) do
            if saved.id == build.id then BF.ui.selectedBuildIndex = i break end
        end
        BF.SyncHiddenList()
        BF.RefreshUI()
    end
end

function BF.CompareSelectedBuild()
    local build = BF.GetSelectedBuild()
    if not build then BF.Chat("No build selected.") return end
    BF.BuildApplier.CompareBuild(build)
end

function BF.ApplySelectedBuildGear()
    local build = BF.GetSelectedBuild()
    if not build then BF.Chat("No build selected.") return end
    BF.BuildApplier.ApplyOwnedGear(build)
end

function BF.ApplySelectedBuildAll()
    local build = BF.GetSelectedBuild()
    if not build then BF.Chat("No build selected.") return end
    BF.BuildAutomation.ApplyAll(build)
end

function BF.ExportSelectedBuild()
    local build = BF.GetSelectedBuild()
    if not build then BF.Chat("No build selected.") return end
    BF.BuildExport.ExportBuild(build)
end

function BF.AddCustomMenuEntry()
    if BF.menuEntryRegistered then return end
    if not MAIN_MENU_GAMEPAD_SCENE or not MAIN_MENU_GAMEPAD or not ZO_MENU_ENTRIES or not ZO_MENU_MAIN_ENTRIES then return end
    local isConsole = IsConsoleUI and IsConsoleUI()
    local isGamepad = IsInGamepadPreferredMode and IsInGamepadPreferredMode()
    if not isConsole and not isGamepad then return end

    local function OnStateChange(oldState, newState)
        if newState ~= SCENE_SHOWING then return end
        MAIN_MENU_GAMEPAD_SCENE:UnregisterCallback("StateChange", OnStateChange)
        if BF.menuEntryRegistered then return end

        local function CreateEntry(id, data)
            local entry = ZO_GamepadEntryData:New(data.name, data.icon, nil, nil, data.isNewCallback)
            entry:SetIconTintOnSelection(true)
            entry:SetIconDisabledTintOnSelection(true)
            if data.subMenu then
                entry.subMenu = {}
                for index, subData in ipairs(data.subMenu) do
                    entry.subMenu[#entry.subMenu + 1] = CreateEntry(index, subData)
                end
            end
            entry.data = data
            entry.id = id
            return entry
        end

        local subItems = {
            { name = "Build Dashboard", icon = "EsoUI/Art/Inventory/gamepad/gp_inventory_icon_equipped.dds", activatedCallback = function() BF.OpenUI() end },
            { name = "Record Current Build", icon = "EsoUI/Art/MenuBar/gamepad/gp_playerMenu_icon_character.dds", activatedCallback = function() BF.RecordCurrentBuild() BF.OpenUI() end },
            { name = "Compare Selected Build", icon = "EsoUI/Art/MenuBar/gamepad/gp_playermenu_icon_journal.dds", activatedCallback = function() BF.CompareSelectedBuild() BF.OpenUI() end },
            { name = "Apply All Possible", icon = "EsoUI/Art/Inventory/gamepad/gp_inventory_icon_quickslot.dds", activatedCallback = function() BF.ApplySelectedBuildAll() BF.OpenUI() end },
            { name = "Apply Owned Gear Only", icon = "EsoUI/Art/Inventory/gamepad/gp_inventory_icon_armor.dds", activatedCallback = function() BF.ApplySelectedBuildGear() BF.OpenUI() end },
            { name = "Export Selected Build", icon = "EsoUI/Art/MenuBar/gamepad/gp_playermenu_icon_mail.dds", activatedCallback = function() BF.ExportSelectedBuild() BF.OpenUI() end },
        }

        local insertPos = 0
        for i = 1, #ZO_MENU_ENTRIES do
            if ZO_MENU_ENTRIES[i].id == ZO_MENU_MAIN_ENTRIES.ACTIVITY_FINDER then insertPos = i break end
        end
        if insertPos == 0 then insertPos = #ZO_MENU_ENTRIES + 1 end

        table.insert(ZO_MENU_ENTRIES, insertPos, CreateEntry("BuildForgeMainEntry", {
            customTemplate = "ZO_GamepadMenuEntryTemplateWithArrow",
            name = "|c88CCFFBuildForge|r",
            icon = "EsoUI/Art/Inventory/gamepad/gp_inventory_icon_equipped.dds",
            subMenu = subItems,
        }))
        BF.menuEntryRegistered = true
        MAIN_MENU_GAMEPAD:RefreshMainList()
    end

    MAIN_MENU_GAMEPAD_SCENE:RegisterCallback("StateChange", OnStateChange)
end
