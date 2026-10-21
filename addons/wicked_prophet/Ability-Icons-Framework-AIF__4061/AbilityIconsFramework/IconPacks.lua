-- =============================================================================
-- Ability Icons Framework (AIF) - Icon Packs & Load Order Priority
-- =============================================================================
-- Manages third-party icon pack registration, priority sorting, tie-breaking,
-- and live texture overrides in ESO's engine.
--
-- Why priority sorting?
-- When Player A installs "Cool DK Fire Icons" and "Ultra HD Class Pack", and both
-- packs include a replacement for Molten Whip, there can be only one victor.
-- This module guarantees that the pack placed higher in the settings UI wins every
-- single contested texture without crashing, flickering, or undefined behavior.
-- =============================================================================

--- @class (partial) AbilityIconsFramework
AbilityIconsFramework = AbilityIconsFramework or {}
local AbilityIconsFramework = AbilityIconsFramework

local pairs         = pairs
local ipairs        = ipairs
local tostring      = tostring
local ZO_ClearTable = ZO_ClearTable

--------------------------------------------------------------------------------
-- Icon Pack State Tables
--------------------------------------------------------------------------------

-- Ordered table bound to LibAddonMenuOrderListBox for the settings priority list.
-- Mutated in-place so LAM controls never lose their reference.
AbilityIconsFramework.packSortOrderEntries = AbilityIconsFramework.packSortOrderEntries or {}

--------------------------------------------------------------------------------
-- Helper Routines
--------------------------------------------------------------------------------

--- Extracts a clean, human-readable display name from an icon pack's folder path.
--- E.g., "/MyFancyIcons/art/icons/" -> "MyFancyIcons"
--- @param packDir string The root directory of the icon pack.
--- @return string displayName Clean folder name for settings display.
local function GetPackDisplayName(packDir)
    local packName = packDir:match("/(.*)/")
    if packName then
        return packName:match("(.*)/") or packName
    end
    return packDir
end

--------------------------------------------------------------------------------
-- Priority Sort & Orders
--------------------------------------------------------------------------------

--- Finds the highest numeric loadOrder currently assigned in SavedVariables.
--- Used to assign newly installed packs to the bottom of the priority ladder.
--- @return number highestOrder The highest order number found, or 0.
function AbilityIconsFramework.GetHighestIconPackOrder()
    local max = 0
    local settings = AbilityIconsFramework.GetSettings()
    if settings and settings.iconPacksData then
        for _, packData in pairs(settings.iconPacksData) do
            if packData ~= nil and packData.loadOrder and type(packData.loadOrder) == "number" and packData.loadOrder > max then
                max = packData.loadOrder
            end
        end
    end
    return max
end

--- Ensures a registered icon pack has a valid metadata table in SavedVariables.
--- Handles user-friendly display name extraction, preview texture assignment,
--- and assignation of the next available load order slot.
--- @param settings table Active SavedVariables settings table.
--- @param packDir string Root folder path of the pack.
--- @param packIcons table Array of icon filenames provided by the pack.
--- @return table? packData The validated metadata record.
local function EnsurePackMetadata(settings, packDir, packIcons)
    if not (settings and settings.iconPacksData and packDir) then return nil end
    local packData = settings.iconPacksData[packDir]
    local packName = GetPackDisplayName(packDir)
    local exampleTexture = (packIcons and packIcons[1]) and (packDir .. packIcons[1]) or nil

    if packData ~= nil then
        if packData.packDisplayName == nil or packData.packDisplayName == "" then
            packData.packDisplayName = packName
        end
        if packData.packExampleTexture == nil or packData.packExampleTexture == "" then
            packData.packExampleTexture = exampleTexture
        end
        if not packData.loadOrder then
            packData.loadOrder = AbilityIconsFramework.GetHighestIconPackOrder() + 1
        end
        return packData
    end

    local highestOrder = AbilityIconsFramework.GetHighestIconPackOrder()
    packData = {
        packDisplayName = packName,
        loadOrder = highestOrder + 1,
        packExampleTexture = exampleTexture,
    }
    settings.iconPacksData[packDir] = packData
    return packData
end

--------------------------------------------------------------------------------
-- Public Registration API
--------------------------------------------------------------------------------

--- Public Registration API: Other addons call this function to register their icon packs.
---
--- Example usage from an external pack:
---   AbilityIconsFramework.AddCustomIconPack("/MyPack/icons/", { "ability_mage_001.dds", ... })
---
--- If called while in-game (after initialization), dynamically refreshes sort lists
--- and applies texture overrides without requiring a /reloadui.
---
--- @param PackDirectory string Root folder path to the icon pack assets.
--- @param PackIcons table Array of relative filenames inside the pack directory.
function AbilityIconsFramework.AddCustomIconPack(PackDirectory, PackIcons)
    if PackDirectory == nil or PackIcons == nil or #PackIcons == 0 then
        return
    end

    -- Always mark pack as active in memory
    AbilityIconsFramework.ENABLED_ICON_PACKS[PackDirectory] = PackIcons

    local settings = AbilityIconsFramework.GetSettings()
    if not (settings and settings.iconPacksData) then
        return
    end

    EnsurePackMetadata(settings, PackDirectory, PackIcons)

    if AbilityIconsFramework.isInitialized then
        AbilityIconsFramework.InitializeSortOrderEntries()
        AbilityIconsFramework.ApplyPackLoadOrderChanges()
    end
end

--- Ascending sort comparator for the LibAddonMenu priority list (1 = top priority).
--- Deterministic tie-breakers: loadOrder -> displayName -> directory path.
local function packSortFuncAsc(t, a, b)
    if not (t and t[a] and t[b]) then return false end
    local orderA = t[a].loadOrder or 9999
    local orderB = t[b].loadOrder or 9999
    if orderA ~= orderB then
        return orderA < orderB
    end
    -- Deterministic tie-breakers: display name, then directory path string
    local nameA = t[a].packDisplayName or a
    local nameB = t[b].packDisplayName or b
    if nameA ~= nameB then
        return nameA < nameB
    end
    return tostring(a) < tostring(b)
end

--- Re-indexes and populates the ordered pack list for the LibAddonMenu settings UI.
--- Mutates the existing table in-place so references held by LibAddonMenuOrderListBox remain valid.
function AbilityIconsFramework.InitializeSortOrderEntries()
    local settings = AbilityIconsFramework.GetSettings()
    if not (settings and settings.iconPacksData) then return end

    -- Ensure any enabled packs that might be missing from iconPacksData are added
    if AbilityIconsFramework.ENABLED_ICON_PACKS then
        local missingPacks = {}
        for packDir in pairs(AbilityIconsFramework.ENABLED_ICON_PACKS) do
            if settings.iconPacksData[packDir] == nil then
                table.insert(missingPacks, packDir)
            end
        end
        table.sort(missingPacks)
        for _, packDir in ipairs(missingPacks) do
            EnsurePackMetadata(settings, packDir, AbilityIconsFramework.ENABLED_ICON_PACKS[packDir])
        end
    end

    local keys = {}
    for k in pairs(settings.iconPacksData) do
        if AbilityIconsFramework.ENABLED_ICON_PACKS[k] ~= nil then
            table.insert(keys, k)
        end
    end

    table.sort(keys, function(a, b)
        return packSortFuncAsc(settings.iconPacksData, a, b)
    end)

    -- Mutate existing table in-place so references held by LibAddonMenu controls remain valid
    local entries = AbilityIconsFramework.packSortOrderEntries
    local oldCount = #entries
    local newCount = #keys

    for currentIdx, packDirectoryString in ipairs(keys) do
        local packData = settings.iconPacksData[packDirectoryString]
        if packData ~= nil then
            packData.loadOrder = currentIdx

            local texture = packData.packExampleTexture
            if not texture or texture == "" then
                if AbilityIconsFramework.ENABLED_ICON_PACKS[packDirectoryString] and AbilityIconsFramework.ENABLED_ICON_PACKS[packDirectoryString][1] then
                    texture = packDirectoryString .. AbilityIconsFramework.ENABLED_ICON_PACKS[packDirectoryString][1]
                else
                    texture = "/esoui/art/icons/icon_missing.dds"
                end
            end

            local displayName = packData.packDisplayName or packDirectoryString

            entries[currentIdx] = {
                value = packDirectoryString,
                uniqueKey = currentIdx,
                text = "|t45:45:" .. texture .. "|t " .. displayName,
            }
        end
    end

    -- Clean up any extra trailing elements if packs were removed
    for i = newCount + 1, oldCount do
        entries[i] = nil
    end
end

--- Saves user dragging / priority shifts from the LAM UI back into SavedVariables.
function AbilityIconsFramework.UpdatePackLoadOrderFromSortEntries()
    local settings = AbilityIconsFramework.GetSettings()
    if not (settings and settings.iconPacksData) then return end
    for entryIdx, entryData in ipairs(AbilityIconsFramework.packSortOrderEntries) do
        if entryData and entryData.value and settings.iconPacksData[entryData.value] then
            settings.iconPacksData[entryData.value].loadOrder = entryIdx
        end
    end
end

--------------------------------------------------------------------------------
-- Texture Application & Reverse Priority Iteration
--------------------------------------------------------------------------------

--- Descending priority comparator for ApplyIconPacks.
---
--- WHY REVERSE ORDER?
---   In ApplyIconPacks(), icon packs are applied from lowest priority (highest number)
---   to highest priority (1). This ensures that loadOrder = 1 is applied LAST,
---   cleanly overwriting any identical textures from lower-priority packs!
local packSortFunc = function(t, a, b)
    if not (t and t[a] and t[b]) then return false end
    local orderA = t[a].loadOrder or 9999
    local orderB = t[b].loadOrder or 9999
    if orderA ~= orderB then
        return orderB < orderA
    end
    -- Deterministic tie-breakers: display name, then directory path string
    local nameA = t[a].packDisplayName or a
    local nameB = t[b].packDisplayName or b
    if nameA ~= nameB then
        return nameA > nameB
    end
    return tostring(a) > tostring(b)
end

--- Custom iterator yielding icon pack directories in reverse priority order.
--- Lowest priority packs run first; priority #1 runs last.
--- @return function iterator
function AbilityIconsFramework.packPairs()
    local settings = AbilityIconsFramework.GetSettings()
    if not (settings and settings.iconPacksData) then
        return function() return nil end
    end

    local keys = {}
    for k, _ in pairs(settings.iconPacksData) do
        if AbilityIconsFramework.ENABLED_ICON_PACKS[k] ~= nil then
            keys[#keys + 1] = k
        end
    end

    table.sort(keys, function(a, b) return packSortFunc(settings.iconPacksData, a, b) end)

    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], settings.iconPacksData[keys[i]]
        end
    end
end

--- Registers icon replacements in priority order into BASE_GAME_ICONS_TO_REPLACE.
function AbilityIconsFramework.ApplyIconPacks()
    for PackDirectory, _ in AbilityIconsFramework.packPairs() do
        for _, icon in ipairs(AbilityIconsFramework.ENABLED_ICON_PACKS[PackDirectory]) do
            AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon(icon)] = PackDirectory .. icon
        end
    end
end

--- Compiles the complete replacement dictionary from base assets, packs, and scribed abilities.
function AbilityIconsFramework.GenerateReplacementLists()
    local target = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE
    ZO_ClearTable(target)

    -- Fast copy from precomputed base icons table; eliminates 1,818 runtime string concatenations
    local baseMap = AbilityIconsFramework.GetPrecomputedBaseIcons()
    for k, v in pairs(baseMap) do
        target[k] = v
    end

    AbilityIconsFramework.ApplyIconPacks()
    if AbilityIconsFramework.GenerateScribedSkillsIcons then
        AbilityIconsFramework.GenerateScribedSkillsIcons()
    end
end

--- Flushes all redirects and re-applies textures whenever the user reorders packs.
function AbilityIconsFramework.ApplyPackLoadOrderChanges()
    AbilityIconsFramework.ResetAllTextureRedirects()
    AbilityIconsFramework.GenerateReplacementLists()
    AbilityIconsFramework.ReplaceMismatchedIcons()
    AbilityIconsFramework.UpdateDefaultScribingIcons()
    AbilityIconsFramework.UpdateAllSlots()
end
