-- Scryer's Ledger 1.0.3
local ADDON_NAME = "ScryersLedger"
local OPTIONS_DIALOG = "GAMEPAD_SCRYABLE_ANTIQUITY_OPTIONS"
local CHOICE_DIALOG = "SCRYERS_LEDGER_CHOICE"
local EMPTY_TEXT = "No leads match your filters.\nPress Triangle to change or reset them."

local SORT_CHOICES = {
    { value = "default", label = "Default" },
    { value = "zone", label = "Zone (A–Z)" },
    { value = "quality", label = "Quality (highest first)" },
    { value = "expiration", label = "Expiration (soonest first)" },
}

local QUALITIES = {
    { value = ANTIQUITY_QUALITY_ORANGE, label = "Orange" },
    { value = ANTIQUITY_QUALITY_GOLD, label = "Gold" },
    { value = ANTIQUITY_QUALITY_PURPLE, label = "Purple" },
    { value = ANTIQUITY_QUALITY_BLUE, label = "Blue" },
    { value = ANTIQUITY_QUALITY_GREEN, label = "Green" },
    { value = ANTIQUITY_QUALITY_WHITE, label = "White" },
}

local function GetPage(category)
    local id = category and category:GetId()
    if id == ZO_SCRYABLE_ANTIQUITY_ALL_LEADS_SUBCATEGORY_ID then
        return "allLeads"
    elseif id == ZO_SCRYABLE_ANTIQUITY_CURRENT_ZONE_SUBCATEGORY_ID then
        return "currentZone"
    end
end

local function GetZoneName(zoneId)
    local name = GetZoneNameById(zoneId)
    if name and name ~= "" then
        return zo_strformat(SI_ZONE_NAME, name)
    end
    return "Unknown Zone"
end

local function HasFilters(page, preferences)
    return preferences.hideNoExpiration or preferences.quality ~= false
        or (page == "allLeads" and preferences.zone ~= false)
end

local function GetChoiceLabel(choices, value)
    for _, choice in ipairs(choices) do
        if choice.value == value then
            return choice.label
        end
    end
end

local function MakeComparator(context)
    local sort = context.preferences.sort
    return function(left, right)
        local leftKey = context.sortKeys[left]
        local rightKey = context.sortKeys[right]
        if leftKey ~= rightKey then
            if sort == "quality" then
                return leftKey > rightKey
            end
            return leftKey < rightKey
        end

        local leftName, rightName = left:GetName(), right:GetName()
        if leftName ~= rightName then
            return leftName < rightName
        end
        return left:GetId() < right:GetId()
    end
end

local function MatchesFilters(context, antiquity)
    local preferences = context.preferences
    local zone = antiquity:GetZoneId()
    local quality = antiquity:GetQuality()
    if (context.page == "allLeads" and preferences.zone and preferences.zone ~= zone)
        or (preferences.quality and preferences.quality ~= quality) then
        return false
    end

    local remaining = antiquity:GetLeadTimeRemainingS()
    if remaining > 0 then
        context.nextExpiration = math.min(context.nextExpiration, context.now + remaining)
    elseif preferences.hideNoExpiration then
        return false
    end

    if preferences.sort == "zone" then
        context.sortKeys[antiquity] = GetZoneName(zone)
    elseif preferences.sort == "quality" then
        context.sortKeys[antiquity] = quality
    elseif preferences.sort == "expiration" then
        context.sortKeys[antiquity] = remaining > 0 and remaining or math.huge
    end
    return true
end

local function GetZoneChoices(category)
    local choices = {}
    local seen = {}
    for _, antiquity in category:AntiquityIterator({ ZO_Antiquity.IsVisible }) do
        local id = antiquity:GetZoneId()
        if not seen[id] then
            seen[id] = true
            choices[#choices + 1] = { value = id, label = GetZoneName(id) }
        end
    end
    table.sort(choices, function(left, right)
        if left.label == right.label then
            return left.value < right.value
        end
        return left.label < right.label
    end)
    table.insert(choices, 1, { value = false, label = "All Zones" })
    return choices
end

local function GroupByCodexSet(scrollData, context)
    local nativeSections, groups, groupsById = {}, {}, {}
    local section, headerType
    for _, row in ipairs(scrollData) do
        local antiquity = row.data.dataSource
        if antiquity and section then
            local set = antiquity:GetAntiquitySetData()
            if set then
                local id = set:GetId()
                local group = groupsById[id]
                if not group then
                    group = { id = id, label = set:GetFormattedName(), readyToDig = {}, needsScrying = {} }
                    groupsById[id] = group
                    groups[#groups + 1] = group
                end
                local rows = antiquity:HasDiscoveredDigSites() and group.readyToDig or group.needsScrying
                rows[#rows + 1] = row
            else
                section.rows[#section.rows + 1] = row
            end
        elseif not antiquity and row.data.label then
            section = { header = row, label = row.data.label, rows = {} }
            nativeSections[#nativeSections + 1] = section
            headerType = row.typeId
        else
            -- Leave the list intact if a future client changes the row layout.
            return
        end
    end

    if #groups == 0 then
        return
    end
    table.sort(groups, function(left, right)
        if left.label ~= right.label then
            return left.label < right.label
        end
        return left.id < right.id
    end)

    local comparator = context.preferences.sort ~= "default" and MakeComparator(context)
    ZO_ClearNumericallyIndexedTable(scrollData)

    local function AppendSection(header, label, rows)
        scrollData[#scrollData + 1] = header
        for i, row in ipairs(rows) do
            row.data.headerNarrationText = i == 1 and label or nil
            scrollData[#scrollData + 1] = row
        end
    end

    local function AppendStatus(group, status, rows)
        if #rows == 0 then
            return
        end
        if comparator then
            table.sort(rows, function(left, right)
                return comparator(left.data.dataSource, right.data.dataSource)
            end)
        end
        local label = group.label .. " — " .. status
        local header = ZO_ScrollList_CreateDataEntry(headerType, { label = label })
        AppendSection(header, label, rows)
    end

    for _, group in ipairs(groups) do
        AppendStatus(group, "Ready to Dig", group.readyToDig)
        AppendStatus(group, "Needs Scrying", group.needsScrying)
    end
    for _, nativeSection in ipairs(nativeSections) do
        if #nativeSection.rows > 0 then
            AppendSection(nativeSection.header, nativeSection.label, nativeSection.rows)
        end
    end
end

local function RegisterChoiceDialog()
    ZO_Dialogs_RegisterCustomDialog(CHOICE_DIALOG, {
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title = { text = function(dialog) return dialog.data.title end },
        parametricList = {},
        setup = function(dialog, data)
            local entries = dialog.info.parametricList
            ZO_ClearNumericallyIndexedTable(entries)
            for _, choice in ipairs(data.choices) do
                local label = choice.label
                if choice.value == data.selected then
                    label = label .. " (selected)"
                end
                local entry = ZO_GamepadEntryData:New(label)
                entry.setup = ZO_SharedGamepadEntry_OnSetup
                entry.ledgerChoice = choice
                entries[#entries + 1] = { template = "ZO_GamepadItemEntryTemplate", entryData = entry }
            end
            dialog:setupFunc()
        end,
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = function(dialog)
                    local entry = dialog.entryList:GetTargetData()
                    if entry then
                        dialog.data.apply(entry.ledgerChoice.value)
                    end
                end,
            },
            { keybind = "DIALOG_NEGATIVE", text = SI_GAMEPAD_BACK_OPTION },
        },
    })
end

local function Install(journal, list, saved)
    local activeRefresh
    local nextExpiration = math.huge
    local leadUpdatePending = false

    -- Only the native gamepad journal rebuild receives the extra predicates.
    for _, category in ipairs({
        ZO_SCRYABLE_ANTIQUITY_CURRENT_ZONE_SUBCATEGORY_DATA,
        ZO_SCRYABLE_ANTIQUITY_ALL_LEADS_SUBCATEGORY_DATA,
    }) do
        local nativeIterator = category.AntiquityIterator
        category.AntiquityIterator = function(self, predicates)
            local context = activeRefresh
            if not context or GetPage(self) ~= context.page then
                return nativeIterator(self, predicates)
            end
            local combined = {}
            for _, predicate in ipairs(predicates or {}) do
                combined[#combined + 1] = predicate
            end
            combined[#combined + 1] = function(antiquity)
                return MatchesFilters(context, antiquity)
            end
            return nativeIterator(self, combined)
        end
    end

    local nativeSections = ANTIQUITY_MANAGER.GetOrCreateAntiquitySectionList
    ANTIQUITY_MANAGER.GetOrCreateAntiquitySectionList = function(self)
        local sections = nativeSections(self)
        if not activeRefresh or activeRefresh.preferences.sort == "default" then
            return sections
        end

        -- The keyboard journal uses the same manager. Leave its descriptors intact.
        local copies = {}
        local comparator = MakeComparator(activeRefresh)
        for i, section in ipairs(sections) do
            local copy = {}
            for key, value in pairs(section) do
                copy[key] = value
            end
            copy.list = {}
            copy.sortFunction = comparator
            copies[i] = copy
        end
        return copies
    end

    local nativeRefresh = list.RefreshAntiquities
    local nativeCommit = list.CommitScrollList
    list.CommitScrollList = function(self)
        if activeRefresh and activeRefresh.preferences.groupBySet then
            local scrollData = ZO_ScrollList_GetDataList(self.list)
            -- The native refresh calculated its selection index before grouping.
            GroupByCodexSet(scrollData, activeRefresh)
            ZO_ScrollList_SetAutoSelectToMatchingDataEntry(self.list, self.lastSelectedData)
        end
        nativeCommit(self)
    end

    list.RefreshAntiquities = function(self)
        local page = GetPage(self:GetCurrentSubcategoryData())
        local previousRefresh = activeRefresh
        local context
        if page then
            context = {
                page = page,
                preferences = saved[page],
                sortKeys = {},
                now = GetFrameTimeSeconds(),
                nextExpiration = math.huge,
            }
        end

        activeRefresh = context
        local success, errorMessage = pcall(nativeRefresh, self)
        activeRefresh = previousRefresh
        if not success then
            error(errorMessage, 0)
        end

        nextExpiration = context and context.nextExpiration or math.huge
        leadUpdatePending = false
        local emptyFiltered = page and HasFilters(page, saved[page])
            and not ZO_ScrollList_HasVisibleData(self.list)
        self.emptyLabel:SetText(emptyFiltered and EMPTY_TEXT or GetString(SI_ANTIQUITY_EMPTY_LIST))
        self:UpdateKeybinds()
    end

    local function Refresh()
        list:RefreshAntiquities()
    end

    local nativeActions = list.CreateOptionsDialogActions
    list.CreateOptionsDialogActions = function(self)
        local category = self:GetCurrentSubcategoryData()
        local page = GetPage(category)
        if not page then
            return nativeActions(self)
        end

        local actions = self:GetCurrentAntiquityData() and nativeActions(self) or {}
        local preferences = saved[page]
        local function AddChoice(title, key, choices, currentLabel)
            actions[#actions + 1] = {
                text = title .. " — " .. currentLabel,
                callback = function()
                    ZO_Dialogs_ReleaseDialogOnButtonPress(OPTIONS_DIALOG)
                    ZO_Dialogs_ShowGamepadDialog(CHOICE_DIALOG, {
                        title = title,
                        choices = choices(),
                        selected = preferences[key],
                        apply = function(value)
                            preferences[key] = value
                            Refresh()
                        end,
                    })
                end,
            }
        end

        AddChoice("Sort by", "sort", function() return SORT_CHOICES end,
            GetChoiceLabel(SORT_CHOICES, preferences.sort) or SORT_CHOICES[1].label)
        if page == "allLeads" then
            AddChoice("Filter by Zone", "zone", function() return GetZoneChoices(category) end,
                preferences.zone and GetZoneName(preferences.zone) or "All Zones")
        end
        AddChoice("Filter by Quality", "quality", function()
            local choices = { { value = false, label = "All Qualities" } }
            for _, choice in ipairs(QUALITIES) do
                choices[#choices + 1] = choice
            end
            return choices
        end, GetChoiceLabel(QUALITIES, preferences.quality) or "All Qualities")
        actions[#actions + 1] = {
            text = "Hide Leads With No Expiration — " .. (preferences.hideNoExpiration and "On" or "Off"),
            callback = function()
                preferences.hideNoExpiration = not preferences.hideNoExpiration
                Refresh()
            end,
        }
        actions[#actions + 1] = {
            text = "Group by Codex Set — " .. (preferences.groupBySet and "On" or "Off"),
            callback = function()
                preferences.groupBySet = not preferences.groupBySet
                Refresh()
            end,
        }
        actions[#actions + 1] = {
            text = "Reset Sort and Filters",
            callback = function()
                preferences.sort = "default"
                preferences.zone = false
                preferences.quality = false
                preferences.hideNoExpiration = false
                preferences.groupBySet = false
                Refresh()
            end,
        }
        return actions
    end

    -- Stock Triangle is tied to selection. Keep that same action usable after
    -- a filter removes the last row, while the list still owns controller focus.
    for _, descriptor in ipairs(list.keybindStripDescriptor) do
        if descriptor.keybind == "UI_SHORTCUT_TERTIARY" then
            local nativeVisible = descriptor.visible
            descriptor.visible = function()
                local page = GetPage(list:GetCurrentSubcategoryData())
                return nativeVisible() or (page ~= nil and HasFilters(page, saved[page])
                    and not ZO_ScrollList_HasVisibleData(list.list))
            end
            break
        end
    end

    local function OnLeadAcquired()
        leadUpdatePending = true
    end
    ANTIQUITY_DATA_MANAGER:RegisterCallback("SingleAntiquityLeadAcquired", OnLeadAcquired)

    ANTIQUITY_JOURNAL_SCENE_GAMEPAD:RegisterCallback("StateChange", function(_, state)
        if state == SCENE_SHOWN then
            EVENT_MANAGER:RegisterForUpdate(ADDON_NAME, 1000, function()
                local page = GetPage(journal:GetCurrentSubcategoryData())
                if page and not ZO_ANTIQUITY_JOURNAL_LIST_GAMEPAD_FRAGMENT:IsHidden()
                    and not ZO_Dialogs_IsShowingDialog()
                    and (leadUpdatePending or GetFrameTimeSeconds() >= nextExpiration) then
                    Refresh()
                end
            end)
        elseif state == SCENE_HIDING then
            EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME)
        end
    end)
end

local function OnAddonLoaded(_, name)
    if name ~= ADDON_NAME then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    local journal = ANTIQUITY_JOURNAL_GAMEPAD
    local list = ANTIQUITY_JOURNAL_LIST_GAMEPAD
    if not journal or not list then
        return
    end

    local defaults = {
        allLeads = { sort = "default", zone = false, quality = false, hideNoExpiration = false, groupBySet = false },
        currentZone = { sort = "default", zone = false, quality = false, hideNoExpiration = false, groupBySet = false },
    }
    local saved = ZO_SavedVars:NewAccountWide("ScryersLedger_SV", 1, nil, defaults)
    RegisterChoiceDialog()
    Install(journal, list, saved)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
