-- Filter dropdowns (multi-select) in the leads section of the Antiquities journal:
-- - Type: kind of reward (furnishing, treasure, style page, mount, mythic item, ...)
-- - Found status: not found yet / already found (recovered at least once)
-- - Difficulty: the 5 scrying difficulties (Simple ... Ultimate) shown on each lead tile,
--   plus a "Scryable" option that only shows leads the character's scrying skill allows

AntiquityLeadFilter = AntiquityLeadFilter or {}
local ALF = AntiquityLeadFilter

ALF.name = "AntiquityLeadFilter"

local FOUND_STATE_NOT_FOUND = 1
local FOUND_STATE_FOUND = 2

local defaults = {
    hiddenDifficulties = {},   -- [difficulty] = true  -> hide this difficulty
    hiddenFoundStates = {},    -- [foundState] = true  -> hide this found state
    hiddenTypes = {},          -- [typeKey] = true     -> hide this antiquity type
    onlyScryable = false,      -- true -> only leads the character can scry with the current skill
}

local TITLE_OFFSET_X = 40   -- left indent of the journal's category title and section headings
local DROPDOWN_SPACING = 10
local DROPDOWN_RIGHT_MARGIN = 10
local DROPDOWN_FALLBACK_WIDTH = 170
local LIST_OFFSET_Y = 45   -- space between the dropdown row and the lead list

local TYPE_KEY_MYTHIC = "mythic"
local TYPE_KEY_OTHER = "other"

local L = ALF.L

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function GetDifficultyName(difficulty)
    -- Localized by the game (same text as "Difficulty: ..." on the lead tiles)
    local name = GetString("SI_ANTIQUITYDIFFICULTY", difficulty)
    if name == nil or name == "" then
        return tostring(difficulty)
    end
    -- Capitalize the first letter (UTF-8 safe via the game's formatter)
    return zo_strformat("<<C:1>>", name)
end

local function IsDifficultyShown(difficulty)
    -- Difficulty 0 (none) is never filtered
    return difficulty <= 0 or not ALF.sv.hiddenDifficulties[difficulty]
end

local function IsScryableShown(antiquityData)
    -- Same check the journal uses for its "Requires skill" sections
    return not ALF.sv.onlyScryable or antiquityData:MeetsScryingSkillRequirements()
end

local function IsFoundStateShown(antiquityData)
    local foundState = antiquityData:HasRecovered() and FOUND_STATE_FOUND or FOUND_STATE_NOT_FOUND
    return not ALF.sv.hiddenFoundStates[foundState]
end

-- Type of an antiquity, derived from its reward. Set fragments (e.g. mythic items, mounts)
-- use the reward of their set. Returns a stable key and a localized name from the game.
local function GetAntiquityType(antiquityId)
    local rewardId = 0
    local setId = GetAntiquitySetId(antiquityId)
    if setId and setId ~= 0 then
        rewardId = GetAntiquitySetRewardId(setId)
    end
    if not rewardId or rewardId == 0 then
        rewardId = GetAntiquityRewardId(antiquityId)
    end
    if not rewardId or rewardId == 0 then
        return TYPE_KEY_OTHER, L.TYPE_OTHER
    end

    local rewardType = GetRewardType(rewardId)
    if rewardType == REWARD_ENTRY_TYPE_ITEM then
        local itemLink = GetItemRewardItemLink(rewardId, 1)
        if GetItemLinkDisplayQuality(itemLink) == ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE then
            return TYPE_KEY_MYTHIC, GetString("SI_ITEMDISPLAYQUALITY", ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE)
        end
        local itemType = GetItemLinkItemType(itemLink)
        return "item:" .. itemType, GetString("SI_ITEMTYPE", itemType)
    elseif rewardType == REWARD_ENTRY_TYPE_COLLECTIBLE then
        local categoryType = GetCollectibleCategoryType(GetCollectibleRewardCollectibleId(rewardId))
        return "collectible:" .. categoryType, GetString("SI_COLLECTIBLECATEGORYTYPE", categoryType)
    end
    return TYPE_KEY_OTHER, L.TYPE_OTHER
end

-- Type key per antiquity id and the list of all types present (sorted by name, "Other" last)
local function CollectAntiquityTypes()
    local typeByAntiquityId = {}
    local namesByKey = {}
    local antiquityId = GetNextAntiquityId()
    while antiquityId do
        local key, name = GetAntiquityType(antiquityId)
        if name == nil or name == "" then
            key, name = TYPE_KEY_OTHER, L.TYPE_OTHER
        end
        typeByAntiquityId[antiquityId] = key
        namesByKey[key] = zo_strformat("<<C:1>>", name)
        antiquityId = GetNextAntiquityId(antiquityId)
    end

    local types = {}
    for key, name in pairs(namesByKey) do
        types[#types + 1] = { key = key, name = name }
    end
    table.sort(types, function(a, b)
        if (a.key == TYPE_KEY_OTHER) ~= (b.key == TYPE_KEY_OTHER) then
            return b.key == TYPE_KEY_OTHER
        end
        return a.name < b.name
    end)
    return typeByAntiquityId, types
end

local function IsTypeShown(antiquityData)
    local key = ALF.typeByAntiquityId[antiquityData:GetId()] or TYPE_KEY_OTHER
    return not ALF.sv.hiddenTypes[key]
end

local function IsAntiquityShown(antiquityData)
    return IsDifficultyShown(antiquityData:GetDifficulty())
        and IsScryableShown(antiquityData)
        and IsFoundStateShown(antiquityData)
        and IsTypeShown(antiquityData)
end

-- Color per difficulty: the most common antiquity quality color of that difficulty
local function CollectDifficultyColors()
    local qualityCounts = {}
    local antiquityId = GetNextAntiquityId()
    while antiquityId do
        local difficulty = GetAntiquityDifficulty(antiquityId)
        local quality = GetAntiquityQuality(antiquityId)
        if difficulty > 0 and quality > 0 then
            qualityCounts[difficulty] = qualityCounts[difficulty] or {}
            qualityCounts[difficulty][quality] = (qualityCounts[difficulty][quality] or 0) + 1
        end
        antiquityId = GetNextAntiquityId(antiquityId)
    end

    local colors = {}
    for difficulty, counts in pairs(qualityCounts) do
        local bestQuality, bestCount = nil, 0
        for quality, count in pairs(counts) do
            if count > bestCount then
                bestQuality, bestCount = quality, count
            end
        end
        colors[difficulty] = GetAntiquityQualityColor(bestQuality)
    end
    return colors
end

local function RefreshJournal()
    local journal = ANTIQUITY_JOURNAL_KEYBOARD
    if not (journal and journal.scene and journal.scene:IsShowing()) then return end

    -- Same as the journal does on search changes: rebuild the current category
    journal.forceUpdateContentOnCategoryReselect = true
    journal:RefreshCategories()
    journal.forceUpdateContentOnCategoryReselect = false
end

---------------------------------------------------------------------------
-- Dropdowns
---------------------------------------------------------------------------

-- Creates a multi-select dropdown.
-- items: list of { key, label, text }  (label = colored entry text, text = plain name for the summary)
-- hiddenTable: saved variables table, [key] = true for deselected items
-- texts: { none, all, count } summary texts (count is optional)
-- option: optional extra entry shown first, stored separately and not part of the summary count:
--         { text, getValue(), setValue(isSelected) }
local function CreateMultiSelectDropdown(name, parent, width, items, hiddenTable, texts, option)
    local control = CreateControlFromVirtual(name, parent, "ZO_ComboBox")
    control:SetDimensions(width, 31)
    control:SetHidden(true)

    local comboBox = ZO_ComboBox_ObjectFromContainer(control)
    comboBox:SetSortsItems(false)
    comboBox:SetFont("ZoFontWinT1")
    comboBox:SetSpacing(4)
    comboBox:EnableMultiSelect()

    -- Custom display text: "All", individual names or a count; the option is put in front
    local numItems = #items
    function comboBox:RefreshSelectedItemText()
        local selected = {}
        local isOptionSelected = false
        for _, entry in ipairs(self:GetSelectedItemData()) do
            if entry.isOption then
                isOptionSelected = true
            else
                selected[#selected + 1] = entry
            end
        end

        local numSelected = #selected
        local text
        if numSelected == 0 then
            text = texts.none
        elseif numSelected == numItems then
            text = texts.all
        elseif numSelected <= 2 or not texts.count then
            local names = {}
            for i, entry in ipairs(selected) do
                names[i] = entry.plainText
            end
            text = table.concat(names, ", ")
        else
            text = zo_strformat(texts.count, numSelected)
        end

        if isOptionSelected then
            text = numSelected == numItems and option.text or (option.text .. ", " .. text)
        end
        self:SetSelectedItemText(text)
    end

    local function OnEntryToggled(_, _, entry)
        local isSelected = comboBox:IsItemSelected(entry)
        if entry.isOption then
            option.setValue(isSelected)
        else
            hiddenTable[entry.key] = (not isSelected) or nil
        end
        RefreshJournal()
    end

    if option then
        local entry = comboBox:CreateItemEntry(option.text, OnEntryToggled)
        entry.isOption = true
        comboBox:AddItem(entry)
        if option.getValue() then
            comboBox:AddItemToSelected(entry)
        end
    end

    for _, item in ipairs(items) do
        local entry = comboBox:CreateItemEntry(item.label, OnEntryToggled)
        entry.key = item.key
        entry.plainText = item.text
        comboBox:AddItem(entry)
        if not hiddenTable[item.key] then
            comboBox:AddItemToSelected(entry)
        end
    end
    comboBox:RefreshSelectedItemText()

    return control
end

function ALF:CreateDropdowns()
    local categoryInset = ZO_AntiquityJournal_Keyboard_TopLevel:GetNamedChild("Contents"):GetNamedChild("Category")
    local title = categoryInset:GetNamedChild("Title")

    -- Difficulty
    local colors = CollectDifficultyColors()
    local difficultyItems = {}
    for difficulty = 1, ANTIQUITY_DIFFICULTY_MAX_VALUE do
        local difficultyName = GetDifficultyName(difficulty)
        local color = colors[difficulty] or ZO_SELECTED_TEXT
        difficultyItems[#difficultyItems + 1] = { key = difficulty, label = color:Colorize(difficultyName), text = difficultyName }
    end
    local sv = self.sv
    local scryableOption = {
        -- "Scryable": the game's own name of the leads category in the journal
        text = zo_strformat("<<C:1>>", GetString(SI_ANTIQUITY_SCRYABLE)),
        getValue = function() return sv.onlyScryable end,
        setValue = function(isSelected) sv.onlyScryable = isSelected end,
    }
    local difficultyDropdown = CreateMultiSelectDropdown("AntiquityLeadFilterDifficultyDropdown", categoryInset, DROPDOWN_FALLBACK_WIDTH,
        difficultyItems, sv.hiddenDifficulties,
        { none = L.NO_SELECTION, all = L.ALL_SELECTED, count = L.NUM_SELECTED },
        scryableOption)

    -- Found status
    local foundItems = {
        { key = FOUND_STATE_NOT_FOUND, label = L.NOT_FOUND, text = L.NOT_FOUND },
        { key = FOUND_STATE_FOUND,     label = L.FOUND,     text = L.FOUND },
    }
    local foundDropdown = CreateMultiSelectDropdown("AntiquityLeadFilterFoundDropdown", categoryInset, DROPDOWN_FALLBACK_WIDTH,
        foundItems, self.sv.hiddenFoundStates,
        { none = L.FOUND_NONE, all = L.FOUND_ALL })

    -- Type
    local typeItems = {}
    for _, antiquityType in ipairs(self.types) do
        typeItems[#typeItems + 1] = { key = antiquityType.key, label = antiquityType.name, text = antiquityType.name }
    end
    local typeDropdown = CreateMultiSelectDropdown("AntiquityLeadFilterTypeDropdown", categoryInset, DROPDOWN_FALLBACK_WIDTH,
        typeItems, self.sv.hiddenTypes,
        { none = L.TYPE_NONE, all = L.TYPE_ALL, count = L.TYPE_COUNT })

    -- Below the category title, from left to right: type, found status, difficulty.
    -- The row starts flush with the title and section headings; widths are set in LayoutDropdowns.
    typeDropdown:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 5)
    foundDropdown:SetAnchor(LEFT, typeDropdown, RIGHT, DROPDOWN_SPACING, 0)
    difficultyDropdown:SetAnchor(LEFT, foundDropdown, RIGHT, DROPDOWN_SPACING, 0)

    self.categoryInset = categoryInset
    self.dropdowns = { typeDropdown, foundDropdown, difficultyDropdown }
end

-- Equal widths so the row spans from the title's left edge to the right edge of the list
function ALF:LayoutDropdowns()
    local available = self.categoryInset:GetWidth() - TITLE_OFFSET_X - DROPDOWN_RIGHT_MARGIN
    local width = (available - DROPDOWN_SPACING * (#self.dropdowns - 1)) / #self.dropdowns
    if width <= 0 then
        width = DROPDOWN_FALLBACK_WIDTH
    end
    for _, dropdown in ipairs(self.dropdowns) do
        dropdown:SetWidth(width)
    end
end

function ALF:SetDropdownsHidden(hidden)
    for _, dropdown in ipairs(self.dropdowns) do
        dropdown:SetHidden(hidden)
    end
end

---------------------------------------------------------------------------
-- Antiquities journal hooks
---------------------------------------------------------------------------

function ALF:HookJournal()
    local Journal = ZO_AntiquityJournal_Keyboard

    -- 1) Filter lead tiles. Empty sections get no heading.
    local originalAddScryableTiles = Journal.AddScryableAntiquityTiles
    Journal.AddScryableAntiquityTiles = function(journal, previousTileOrHeading, headingText, antiquities, sortFunction)
        local filtered = {}
        for _, antiquityData in ipairs(antiquities) do
            if IsAntiquityShown(antiquityData) then
                filtered[#filtered + 1] = antiquityData
            end
        end
        if #filtered == 0 then
            return previousTileOrHeading
        end
        return originalAddScryableTiles(journal, previousTileOrHeading, headingText, filtered, sortFunction)
    end

    -- 2) Show the dropdowns only in the leads section; show "list empty" when everything is filtered out
    local originalBuildTiles = Journal.BuildCategoryAntiquityTiles
    Journal.BuildCategoryAntiquityTiles = function(journal, categoryData, ...)
        originalBuildTiles(journal, categoryData, ...)

        local isScryable = ZO_IsAntiquityScryableSubcategory(categoryData)
        ALF:SetDropdownsHidden(not isScryable)

        if isScryable then
            ALF:LayoutDropdowns()

            -- Move the list below the dropdowns (the game anchors it higher in this section)
            journal.contentList:ClearAnchors()
            journal.contentList:SetAnchor(TOPLEFT, journal.categoryInset, BOTTOMLEFT, 0, LIST_OFFSET_Y)
            journal.contentList:SetAnchor(BOTTOMRIGHT, nil, nil, -10, -75)
        end

        if isScryable and next(journal.antiquityTilesByAntiquityId) == nil then
            journal.contentList:SetHidden(true)
            journal.contentEmptyLabel:SetHidden(false)
        end
    end

    -- 3) Locked content: hide the dropdowns
    ZO_PostHook(Journal, "ShowLockedContentPanel", function()
        ALF:SetDropdownsHidden(true)
    end)
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------

local function OnAddOnLoaded(_, addOnName)
    if addOnName ~= ALF.name then return end
    EVENT_MANAGER:UnregisterForEvent(ALF.name, EVENT_ADD_ON_LOADED)

    if not (ZO_AntiquityJournal_Keyboard and ZO_AntiquityJournal_Keyboard_TopLevel) then return end

    ALF.sv = ZO_SavedVars:NewAccountWide("AntiquityLeadFilter_SV", 1, nil, defaults)
    ALF.typeByAntiquityId, ALF.types = CollectAntiquityTypes()
    ALF:CreateDropdowns()
    ALF:HookJournal()
end

EVENT_MANAGER:RegisterForEvent(ALF.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
