-- Decluttered Scrying Leads
--
-- Adds a multi-select filter dropdown to the Antiquities journal's Scryable -> All Leads
-- list, like the filter dropdown in the housing furniture browser. Pick which antiquities
-- you want to see: never recovered, in progress, codex not complete, or already recovered
-- ones by the kind of reward they give. Nothing selected shows the game's full list.
-- The choice is saved account-wide.

local ADDON_NAME = "DeclutteredScryingLeads"

local REWARD_MOTIF, REWARD_CONTAINER, REWARD_FURNISHING, REWARD_OTHER = "motifs", "containers", "furnishings", "other"

-- Dropdown entries, in display order. key = saved variable key.
local FILTERS =
{
    { key = "new", name = "Never recovered" },
    { key = "inProgress", name = "In progress" },
    { key = "missingCodex", name = "Missing codex entries" },
    { key = REWARD_MOTIF, name = "Recovered: motif chapters" },
    { key = REWARD_CONTAINER, name = "Recovered: containers" },
    { key = REWARD_FURNISHING, name = "Recovered: furnishings" },
    { key = REWARD_OTHER, name = "Recovered: other rewards" },
}

local defaults =
{
    show =
    {
        new = true,
        inProgress = true,
        missingCodex = false,
        [REWARD_MOTIF] = true,
        [REWARD_CONTAINER] = true,
        [REWARD_FURNISHING] = false,
        [REWARD_OTHER] = false,
    },
}

local sv = nil

-- Language-independent: decided from the reward item's type, not the reward's display text.
-- Rewards don't change, so each one is looked up once per session.
local rewardKindCache = {}

local function GetRewardKind(antiquityData)
    local rewardId = antiquityData:GetRewardId() or 0
    local kind = rewardKindCache[rewardId]
    if kind then return kind end

    kind = REWARD_OTHER
    if rewardId ~= 0 and GetRewardType(rewardId) == REWARD_ENTRY_TYPE_ITEM then
        local itemType, specializedItemType = GetItemLinkItemType(GetItemRewardItemLink(rewardId, 1))
        if itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then
            kind = REWARD_MOTIF
        elseif itemType == ITEMTYPE_CONTAINER or specializedItemType == SPECIALIZED_ITEMTYPE_CONTAINER then
            kind = REWARD_CONTAINER
        elseif itemType == ITEMTYPE_FURNISHING then
            kind = REWARD_FURNISHING
        end
    end
    rewardKindCache[rewardId] = kind
    return kind
end

local function IsAnyFilterSelected()
    for _, filter in ipairs(FILTERS) do
        if sv.show[filter.key] then
            return true
        end
    end
    return false
end

local function PassesFilter(antiquityData)
    local show = sv.show
    if show.inProgress and antiquityData:IsInProgress() then
        return true
    end
    if show.missingCodex and antiquityData:GetNumUnlockedLoreEntries() < antiquityData:GetNumLoreEntries() then
        return true
    end
    if not antiquityData:HasRecovered() then
        return show.new == true
    end
    return show[GetRewardKind(antiquityData)] == true
end

-- The filter only runs while the journal builds the All Leads tiles. It is added to every
-- section of the Scryable list (the game puts an antiquity into the first section whose
-- filters it passes, so a filter in just one section would only move it to the next one).
-- During a build each antiquity is checked once; the result is reused by every section.
local filterDuringBuild = false
local buildResults = {}

local function SectionFilter(antiquityData)
    if not filterDuringBuild then
        return true
    end
    local id = antiquityData:GetId()
    local passes = buildResults[id]
    if passes == nil then
        passes = PassesFilter(antiquityData)
        buildResults[id] = passes
    end
    return passes
end

local function InstallSectionFilter()
    for _, section in ipairs(ANTIQUITY_MANAGER:GetOrCreateAntiquitySectionList()) do
        if not section.dslFilterInstalled then
            table.insert(section.filterFunctions, SectionFilter)
            section.dslFilterInstalled = true
        end
    end
end

local function IsAllLeads(categoryData)
    return categoryData ~= nil and categoryData:GetId() == ZO_SCRYABLE_ANTIQUITY_ALL_LEADS_SUBCATEGORY_ID
end

--------------------------------------------------------------------------------
-- Dropdown in the keyboard Antiquities journal
--------------------------------------------------------------------------------

local dropdown = nil

local function SaveSelection(comboBox)
    local changed = false
    for _, filter in ipairs(FILTERS) do
        local selected = comboBox:IsItemSelected(filter.entry)
        if (sv.show[filter.key] == true) ~= selected then
            sv.show[filter.key] = selected
            changed = true
        end
    end
    if changed then
        ANTIQUITY_JOURNAL_KEYBOARD:RefreshVisibleCategoryFilter()
    end
end

-- The journal builds its controls on first show, so the dropdown is created then.
local function CreateDropdown(journal)
    local inset = journal.categoryInset
    if not inset then return end

    dropdown = CreateControlFromVirtual(ADDON_NAME .. "Filter", inset, "ZO_ComboBox")
    dropdown:SetDimensions(180, 31)
    dropdown:SetAnchor(TOPRIGHT, inset, TOPRIGHT, 0, -4)

    local comboBox = ZO_ComboBox_ObjectFromContainer(dropdown)
    comboBox:SetFont("ZoFontWinT1")
    comboBox:SetSortsItems(false)
    comboBox:SetSpacing(4)
    comboBox:EnableMultiSelect(SI_HOUSING_FURNITURE_FILTER_DROPDOWN_TEXT, zo_strformat(SI_HOUSING_FURNITURE_FILTER_DROPDOWN_TEXT, 0))

    for _, filter in ipairs(FILTERS) do
        filter.entry = comboBox:CreateItemEntry(filter.name)
        comboBox:AddItem(filter.entry)
    end
    local IGNORE_CALLBACK = true
    for _, filter in ipairs(FILTERS) do
        if sv.show[filter.key] then
            comboBox:SelectItem(filter.entry, IGNORE_CALLBACK)
        end
    end
    comboBox:RefreshSelectedItemText()

    -- Applied when the dropdown closes, like the furniture browser filters.
    comboBox:SetHideDropdownCallback(function() SaveSelection(comboBox) end)
end

-- tim99's Colored Lists adds its own "Missing Codex" checkbox to All Leads. Its option is
-- part of this dropdown, so hide that checkbox. If it was left ticked, untick it through
-- its own handler first, otherwise its hidden filter would keep hiding leads.
local function HideColoredListsCodexCheckbox()
    local checkbox = TCL_AntiquityMissingCodex
    if not checkbox then return end
    if ZO_CheckButton_IsChecked(checkbox) then
        local NO_SOUND = true
        ZO_CheckButton_OnClicked(checkbox, MOUSE_BUTTON_INDEX_LEFT, NO_SOUND)
    end
    checkbox:SetHidden(true)
end

local function OnCategorySelected(journal, categoryData)
    HideColoredListsCodexCheckbox()

    if not dropdown then
        CreateDropdown(journal)
        if not dropdown then return end
    end
    dropdown:SetHidden(not (IsAllLeads(categoryData) and ZO_IsScryingUnlocked()))
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    sv = ZO_SavedVars:NewAccountWide("DeclutteredScryingLeads_SV", 2, nil, defaults)
    if ANTIQUITY_JOURNAL_KEYBOARD then
        SecurePostHook(ANTIQUITY_JOURNAL_KEYBOARD, "OnCategorySelected", OnCategorySelected)
        ZO_PreHook(ANTIQUITY_JOURNAL_KEYBOARD, "BuildCategoryAntiquityTiles", function(_, categoryData)
            InstallSectionFilter()
            ZO_ClearTable(buildResults)
            filterDuringBuild = IsAllLeads(categoryData) and IsAnyFilterSelected()
        end)
        SecurePostHook(ANTIQUITY_JOURNAL_KEYBOARD, "BuildCategoryAntiquityTiles", function()
            filterDuringBuild = false
        end)
    end
end)
