--[[
    PatchBanditsUI4SelectDangeons
    Author: alezhu
    Description: Patches Bandits User Interface dungeon selection based on Group difficulty
                 and adds an Uncompleted quests selector button.
]]--

PatchBUI = PatchBUI or {}
PatchBUI.name = "PatchBanditsUI4SelectDangeons"
PatchBUI.version = "1.0.0"

-- Deselect all currently selected activities in the finder
function PatchBUI.DeselectAll()
    if ZO_ACTIVITY_FINDER_ROOT_MANAGER and type(ZO_ACTIVITY_FINDER_ROOT_MANAGER.ClearSelections) == "function" then
        pcall(function() ZO_ACTIVITY_FINDER_ROOT_MANAGER:ClearSelections() end)
    end

    for c = 2, 3 do
        local parent = _G["ZO_DungeonFinder_KeyboardListSectionScrollChildContainer" .. c]
        if parent then
            for i = 1, parent:GetNumChildren() do
                local obj = parent:GetChild(i)
                if obj and obj.check then
                    if obj.check:GetState() ~= BSTATE_NORMAL then
                        obj.check:SetState(BSTATE_NORMAL, false)
                    end
                end
            end
        end
    end
end

-- Select a single row in the dungeon finder
function PatchBUI.SelectLocation(data, obj)
    if not data then return end

    local isSelected = false
    if type(data.IsSelected) == "function" then
        local ok, sel = pcall(data.IsSelected, data)
        if ok then isSelected = sel end
    elseif obj and obj.check then
        isSelected = (obj.check:GetState() == BSTATE_PRESSED)
    end

    if not isSelected then
        if obj and obj.check then
            obj.check:SetState(BSTATE_PRESSED, true)
        end
        if ZO_ACTIVITY_FINDER_ROOT_MANAGER then
            if type(ZO_ACTIVITY_FINDER_ROOT_MANAGER.SetLocationSelected) == "function" then
                pcall(ZO_ACTIVITY_FINDER_ROOT_MANAGER.SetLocationSelected, ZO_ACTIVITY_FINDER_ROOT_MANAGER, data, true)
            elseif type(ZO_ACTIVITY_FINDER_ROOT_MANAGER.ToggleLocationSelected) == "function" then
                pcall(ZO_ACTIVITY_FINDER_ROOT_MANAGER.ToggleLocationSelected, ZO_ACTIVITY_FINDER_ROOT_MANAGER, data)
            end
        end
    end
end

-- Expand target difficulty container section if collapsed
function PatchBUI.ExpandSection(c)
    local parent = _G["ZO_DungeonFinder_KeyboardListSectionScrollChildContainer" .. c]
    if parent and parent:IsHidden() then
        local headerIndex = c - 1
        local header = _G["ZO_DungeonFinder_KeyboardListSectionScrollChildZO_ActivityFinderTemplateNavigationHeader_Keyboard" .. headerIndex]
        if header and header.OnMouseUp then
            pcall(header.OnMouseUp, header, true)
        end
    end
end

-- Count uncompleted accessible quests for difficulty container c
function PatchBUI.GetUncompletedCount(c)
    local count = 0
    local parent = _G["ZO_DungeonFinder_KeyboardListSectionScrollChildContainer" .. c]
    if parent then
        for i = 1, parent:GetNumChildren() do
            local obj = parent:GetChild(i)
            if obj and obj.node and obj.node.data then
                local data = obj.node.data
                if PatchBUI.IsDungeonAvailable(data) then
                    local zoneId = data.zoneId
                    if obj.needDungeonQuest or PatchBUI.IsQuestUncompleted(zoneId) then
                        count = count + 1
                    end
                end
            end
        end
    end
    return count
end

-- Count active pledges for difficulty container c
function PatchBUI.GetPledgesCount(c)
    local count = 0
    local parent = _G["ZO_DungeonFinder_KeyboardListSectionScrollChildContainer" .. c]
    local pledges, haveQuest = PatchBUI.GetJournalPledges()
    if parent then
        for i = 1, parent:GetNumChildren() do
            local obj = parent:GetChild(i)
            if obj and obj.node and obj.node.data then
                local data = obj.node.data
                if PatchBUI.IsDungeonAvailable(data) then
                    local zoneId = data.zoneId
                    local info = PatchBUI.DungeonData[zoneId]
                    local isPledge = obj.pledge or (info and info.pledge and pledges[GetQuestName(info.pledge)] == false)
                    if isPledge then
                        count = count + 1
                    end
                end
            end
        end
    end
    return count
end

-- Handler for "Выбрать активные задания" (Active Pledges)
function PatchBUI.SelectActivePledges()
    -- Difficulty determined strictly by Group settings
    local c = PatchBUI.GetTargetContainerIndex()
    local isVet = (c == 3)
    local diffName = isVet and GetString(SI_PATCHBUI_DIFF_VETERAN) or GetString(SI_PATCHBUI_DIFF_NORMAL)

    -- Deselect all currently selected activities first
    PatchBUI.DeselectAll()

    local parent = _G["ZO_DungeonFinder_KeyboardListSectionScrollChildContainer" .. c]
    local pledges, haveQuest = PatchBUI.GetJournalPledges()
    local selectedCount = 0

    if parent then
        for i = 1, parent:GetNumChildren() do
            local obj = parent:GetChild(i)
            if obj and obj.node and obj.node.data then
                local data = obj.node.data
                if PatchBUI.IsDungeonAvailable(data) then
                    local zoneId = data.zoneId
                    local info = PatchBUI.DungeonData[zoneId]
                    local isPledge = obj.pledge or (info and info.pledge and pledges[GetQuestName(info.pledge)] == false)
                    if isPledge then
                        PatchBUI.SelectLocation(data, obj)
                        selectedCount = selectedCount + 1
                    end
                end
            end
        end
    end

    -- Ensure the section is expanded
    PatchBUI.ExpandSection(c)

    -- Feedback message in chat
    if selectedCount > 0 then
        local msg = zo_strformat(GetString(SI_PATCHBUI_PLEDGES_SELECTED), selectedCount, diffName)
        d("|c4B8BFE[PatchBUI]|r " .. msg)
    else
        local msg = zo_strformat(GetString(SI_PATCHBUI_PLEDGES_NONE), diffName)
        d("|c4B8BFE[PatchBUI]|r " .. msg)
    end
end

-- Handler for "Непройденные" (Uncompleted Dungeons)
function PatchBUI.SelectUncompletedQuests()
    -- Difficulty determined strictly by Group settings
    local c = PatchBUI.GetTargetContainerIndex()
    local isVet = (c == 3)
    local diffName = isVet and GetString(SI_PATCHBUI_DIFF_VETERAN) or GetString(SI_PATCHBUI_DIFF_NORMAL)

    -- Deselect all currently selected activities first
    PatchBUI.DeselectAll()

    local parent = _G["ZO_DungeonFinder_KeyboardListSectionScrollChildContainer" .. c]
    local selectedCount = 0

    if parent then
        for i = 1, parent:GetNumChildren() do
            local obj = parent:GetChild(i)
            if obj and obj.node and obj.node.data then
                local data = obj.node.data
                -- Only select if dungeon is available (purchased / unlocked)
                if PatchBUI.IsDungeonAvailable(data) then
                    local zoneId = data.zoneId
                    local isUncompleted = obj.needDungeonQuest or PatchBUI.IsQuestUncompleted(zoneId)
                    if isUncompleted then
                        PatchBUI.SelectLocation(data, obj)
                        selectedCount = selectedCount + 1
                    end
                end
            end
        end
    end

    -- Ensure the section is expanded
    PatchBUI.ExpandSection(c)

    -- Feedback message in chat
    if selectedCount > 0 then
        local msg = zo_strformat(GetString(SI_PATCHBUI_UNCOMPLETED_SELECTED), selectedCount, diffName)
        d("|c4B8BFE[PatchBUI]|r " .. msg)
    else
        local msg = zo_strformat(GetString(SI_PATCHBUI_UNCOMPLETED_NONE), diffName)
        d("|c4B8BFE[PatchBUI]|r " .. msg)
    end
end

-- Hook BanditsUI pledges button to redirect click logic
function PatchBUI.HookPledgesButton()
    local btn = _G["BUI_PledgesCheck"]
    if btn then
        if not btn.__PatchBUI_Hooked then
            btn.__PatchBUI_Hooked = true

            -- Intercept future calls to SetHandler("OnClicked") from BUI's MarkPledges
            local origSetHandler = btn.SetHandler
            btn.SetHandler = function(self, handlerName, handlerFn, ...)
                if handlerName == "OnClicked" then
                    return origSetHandler(self, handlerName, function(...)
                        PatchBUI.SelectActivePledges()
                    end, ...)
                end
                return origSetHandler(self, handlerName, handlerFn, ...)
            end
        end

        -- Ensure current click handler points to our function
        btn:SetHandler("OnClicked", function()
            PatchBUI.SelectActivePledges()
        end)

        -- Tooltip on hover
        btn:SetHandler("OnMouseEnter", function(self)
            InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -5)
            local isVet = PatchBUI.IsVeteranGroupDifficulty()
            local diffName = isVet and GetString(SI_PATCHBUI_DIFF_VETERAN) or GetString(SI_PATCHBUI_DIFF_NORMAL)
            local count = PatchBUI.GetPledgesCount(isVet and 3 or 2)
            InformationTooltip:AddLine(zo_strformat(GetString(SI_PATCHBUI_PLEDGES_TOOLTIP), diffName, count))
        end)
        btn:SetHandler("OnMouseExit", function(self)
            ClearTooltip(InformationTooltip)
        end)
    end
end

-- Create or update the "Непройденные" button next to BUI_PledgesCheck
function PatchBUI.UpdateUncompletedButton()
    local parent = ZO_DungeonFinder_Keyboard
    if not parent then return end

    local btn = _G["PatchBUI_UncompletedCheck"]
    if not btn then
        btn = WINDOW_MANAGER:CreateControlFromVirtual("PatchBUI_UncompletedCheck", parent, "ZO_DefaultButton")
        btn:SetWidth(150, 28)
        btn:SetText(GetString(SI_PATCHBUI_UNCOMPLETED_BUTTON))
        btn:SetClickSound("Click")
        btn:SetDrawTier(2)

        btn:SetHandler("OnClicked", function()
            PatchBUI.SelectUncompletedQuests()
        end)

        btn:SetHandler("OnMouseEnter", function(self)
            InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -5)
            local isVet = PatchBUI.IsVeteranGroupDifficulty()
            local diffName = isVet and GetString(SI_PATCHBUI_DIFF_VETERAN) or GetString(SI_PATCHBUI_DIFF_NORMAL)
            local count = PatchBUI.GetUncompletedCount(isVet and 3 or 2)
            InformationTooltip:AddLine(zo_strformat(GetString(SI_PATCHBUI_UNCOMPLETED_TOOLTIP), diffName, count))
        end)

        btn:SetHandler("OnMouseExit", function(self)
            ClearTooltip(InformationTooltip)
        end)
    end

    -- Positioning: Anchor to the left of BUI_PledgesCheck
    btn:ClearAnchors()
    local pledgesBtn = _G["BUI_PledgesCheck"]
    if pledgesBtn and not pledgesBtn:IsHidden() then
        btn:SetAnchor(RIGHT, pledgesBtn, LEFT, -8, 0)
    else
        btn:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, 0)
    end

    -- Update state (enabled if uncompleted quests exist for current difficulty)
    local isVet = PatchBUI.IsVeteranGroupDifficulty()
    local uncompletedCount = PatchBUI.GetUncompletedCount(isVet and 3 or 2)
    btn:SetState(uncompletedCount > 0 and BSTATE_NORMAL or BSTATE_DISABLED)
    btn:SetHidden(false)

    -- Hide old buggy BUI dungeon quest button if present
    if BUI_DungeonQuestCheck then
        BUI_DungeonQuestCheck:SetHidden(true)
    end
end

-- Refresh both buttons
function PatchBUI.UpdateAllButtons()
    PatchBUI.HookPledgesButton()
    PatchBUI.UpdateUncompletedButton()
end

-- Addon loaded event
local function OnAddOnLoaded(event, addonName)
    if addonName ~= PatchBUI.name then return end
    EVENT_MANAGER:UnregisterForEvent(PatchBUI.name, EVENT_ADD_ON_LOADED)

    -- Hook Dungeon Finder list section OnEffectivelyShown
    if ZO_DungeonFinder_KeyboardListSection then
        ZO_PostHookHandler(ZO_DungeonFinder_KeyboardListSection, "OnEffectivelyShown", function()
            -- BanditsUI runs MarkPledges 200ms after show; we run right after to apply our patch
            zo_callLater(PatchBUI.UpdateAllButtons, 280)
            zo_callLater(PatchBUI.UpdateAllButtons, 450)
        end)
    end

    -- Register difficulty change events to refresh buttons and states
    EVENT_MANAGER:RegisterForEvent(PatchBUI.name, EVENT_GROUP_VETERAN_DIFFICULTY_CHANGED, function()
        PatchBUI.UpdateAllButtons()
    end)

    d("|c4B8BFE[PatchBUI]|r PatchBanditsUI4SelectDangeons v" .. PatchBUI.version .. " loaded.")
end

EVENT_MANAGER:RegisterForEvent(PatchBUI.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
