--------------------------------------------------------------
-- FashionMount.lua — v1.1.0-test1 (Generic Collectible Categories)
-- Link outfits to selected collectible categories (Console-safe)
-- Author: SugaComa (Rik Sprint)
--------------------------------------------------------------

local ADDON_NAME = "FashionMount"
local EM         = EVENT_MANAGER

FashionMount = FashionMount or {}
local FM      = FashionMount

--------------------------------------------------------------
-- Collectible category definitions
--------------------------------------------------------------

local COLLECTIBLE_OPTIONS = {
    { key = "bodyMarking",     type = COLLECTIBLE_CATEGORY_TYPE_BODY_MARKING,       label = "Body Marking" },
    { key = "costume",         type = COLLECTIBLE_CATEGORY_TYPE_COSTUME,            label = "Costume" },
    { key = "facialAccessory", type = COLLECTIBLE_CATEGORY_TYPE_FACIAL_ACCESSORY,   label = "Facial Accessory" },
    { key = "facialHairHorns", type = COLLECTIBLE_CATEGORY_TYPE_FACIAL_HAIR_HORNS,  label = "Facial Hair / Horns" },
    { key = "hair",            type = COLLECTIBLE_CATEGORY_TYPE_HAIR,               label = "Hair" },
    { key = "hat",             type = COLLECTIBLE_CATEGORY_TYPE_HAT,                label = "Hat" },
    { key = "headMarking",     type = COLLECTIBLE_CATEGORY_TYPE_HEAD_MARKING,       label = "Head Marking" },
    { key = "mount",           type = COLLECTIBLE_CATEGORY_TYPE_MOUNT,              label = "Mount" },
    { key = "outfitStyle",     type = COLLECTIBLE_CATEGORY_TYPE_OUTFIT_STYLE,       label = "Outfit Style" },
    { key = "piercingJewelry", type = COLLECTIBLE_CATEGORY_TYPE_PIERCING_JEWELRY,   label = "Piercing / Jewelry" },
    { key = "polymorph",       type = COLLECTIBLE_CATEGORY_TYPE_POLYMORPH,          label = "Polymorph" },
    { key = "skin",            type = COLLECTIBLE_CATEGORY_TYPE_SKIN,               label = "Skin" },
    { key = "vanityPet",       type = COLLECTIBLE_CATEGORY_TYPE_VANITY_PET,         label = "Vanity Pet" },
}

--------------------------------------------------------------
-- SavedVars & defaults (per character)
--------------------------------------------------------------

local sv
local defaults = {
    enabled = true,
    enabledCategories = {
        [COLLECTIBLE_CATEGORY_TYPE_BODY_MARKING]       = false,
        [COLLECTIBLE_CATEGORY_TYPE_COSTUME]            = false,
        [COLLECTIBLE_CATEGORY_TYPE_FACIAL_ACCESSORY]   = false,
        [COLLECTIBLE_CATEGORY_TYPE_FACIAL_HAIR_HORNS]  = false,
        [COLLECTIBLE_CATEGORY_TYPE_HAIR]               = false,
        [COLLECTIBLE_CATEGORY_TYPE_HAT]                = false,
        [COLLECTIBLE_CATEGORY_TYPE_HEAD_MARKING]       = false,
        [COLLECTIBLE_CATEGORY_TYPE_MOUNT]              = true,
        [COLLECTIBLE_CATEGORY_TYPE_OUTFIT_STYLE]       = false,
        [COLLECTIBLE_CATEGORY_TYPE_PIERCING_JEWELRY]   = false,
        [COLLECTIBLE_CATEGORY_TYPE_POLYMORPH]          = false,
        [COLLECTIBLE_CATEGORY_TYPE_SKIN]               = false,
        [COLLECTIBLE_CATEGORY_TYPE_VANITY_PET]         = true,
    },
    outfits = {}, -- outfitIndex -> { collectibles = { [categoryType] = collectibleId } }
}

local lastOutfitIndex     = 0
local selectedOutfitIndex = 0
local selectedOutfitLabel = "Base appearance (no outfit)"

--------------------------------------------------------------
-- Clean name helper (strip ^suffix)
--------------------------------------------------------------

local function CleanName(raw)
    if not raw or raw == "" then return "" end
    -- remove ESO grammar suffixes like ^Fx, ^Mx, ^N etc.
    return raw:gsub("%^.*", "")
end

--------------------------------------------------------------
-- Helpers
--------------------------------------------------------------

local function chat(msg)
    msg = tostring(msg or "")
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage("|cFF66CC[FashionMount]|r " .. msg)
    else
        d("|cFF66CC[FashionMount]|r " .. msg)
    end
end

local function SafeGetEquippedOutfitIndex()
    if not GetEquippedOutfitIndex then return 0 end

    if GAMEPLAY_ACTOR_CATEGORY_PLAYER then
        local ok, idx = pcall(GetEquippedOutfitIndex, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
        if ok and idx ~= nil then return idx end
    end

    local ok2, idx2 = pcall(GetEquippedOutfitIndex)
    if ok2 and idx2 ~= nil then return idx2 end

    return 0
end

local function SafeGetNumOutfits()
    if not GetNumUnlockedOutfits then return 0 end

    if GAMEPLAY_ACTOR_CATEGORY_PLAYER then
        local ok, num = pcall(GetNumUnlockedOutfits, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
        if ok and num then return num end
    end

    local ok2, num2 = pcall(GetNumUnlockedOutfits)
    if ok2 and num2 then return num2 end

    return 0
end

local function SafeGetOutfitName(index)
    if not GetOutfitName then return nil end

    if GAMEPLAY_ACTOR_CATEGORY_PLAYER then
        local ok, name = pcall(GetOutfitName, GAMEPLAY_ACTOR_CATEGORY_PLAYER, index)
        if ok and name and name ~= "" then
            return CleanName(name)
        end
    end

    local ok2, name2 = pcall(GetOutfitName, index)
    if ok2 and name2 and name2 ~= "" then
        return CleanName(name2)
    end

    return nil
end

local function GetOutfitDisplayName(index)
    if index == 0 then
        return "Base appearance (no outfit)"
    end

    local name = SafeGetOutfitName(index)
    if name then
        return string.format("Outfit %d - %s", index, name)
    end
    return string.format("Outfit %d", index)
end

local function GetCurrentOutfitIndex()
    local idx = SafeGetEquippedOutfitIndex()
    if idx ~= nil then
        return idx
    end
    return lastOutfitIndex or 0
end

local function IsCollectibleValid(id)
    if not id or id == 0 then return false end
    if not IsCollectibleUnlocked or not IsCollectibleUnlocked(id) then return false end
    return true
end

local function GetCollectibleNameOrNone(id)
    if not id or id == 0 then return "None" end
    if not GetCollectibleInfo then return "Unknown" end
    local name = GetCollectibleInfo(id)
    if not name or name == "" then return "Unknown" end
    return CleanName(name)
end

local function GetCategoryLabel(categoryType)
    for _, option in ipairs(COLLECTIBLE_OPTIONS) do
        if option.type == categoryType then
            return option.label
        end
    end
    return tostring(categoryType)
end

local function GetActiveCollectibleSafe(categoryType)
    if not GetActiveCollectibleByType then return 0 end
    local ok, id = pcall(GetActiveCollectibleByType, categoryType)
    if ok and id then
        return id
    end
    return 0
end

--------------------------------------------------------------
-- Mapping helpers
--------------------------------------------------------------

local function GetMappingCollectiblesFor(outfitIndex)
    if not sv or not sv.outfits or not sv.outfits[outfitIndex] then return nil end

    local data = sv.outfits[outfitIndex]

    -- Backwards compatibility for old saved data
    if not data.collectibles then
        data.collectibles = {
            [COLLECTIBLE_CATEGORY_TYPE_MOUNT]       = data.mountId or 0,
            [COLLECTIBLE_CATEGORY_TYPE_VANITY_PET]  = data.petId or 0,
        }
        data.mountId = nil
        data.petId = nil
        data.personalityId = nil
    end

    return data.collectibles
end

local function HasAnySavedCollectibles(outfitIndex)
    local collectibles = GetMappingCollectiblesFor(outfitIndex)
    if not collectibles then return false end

    for _, collectibleId in pairs(collectibles) do
        if collectibleId and collectibleId > 0 then
            return true
        end
    end
    return false
end

--------------------------------------------------------------
-- Core: Apply mapped accessories
--------------------------------------------------------------

local function ApplyForOutfit(outfitIndex)
    if not sv or not sv.enabled then return end

    local idx = outfitIndex or GetCurrentOutfitIndex()
    if idx == 0 then return end

    local collectibles = GetMappingCollectiblesFor(idx)
    if not collectibles then return end

    for _, option in ipairs(COLLECTIBLE_OPTIONS) do
        if sv.enabledCategories and sv.enabledCategories[option.type] then
            local collectibleId = collectibles[option.type]
            if collectibleId and collectibleId > 0 and IsCollectibleValid(collectibleId) then
                local activeId = GetActiveCollectibleSafe(option.type)
                if activeId ~= collectibleId then
                    UseCollectible(collectibleId)
                end
            end
        end
    end
end
FM.ApplyForOutfit = ApplyForOutfit

--------------------------------------------------------------
-- Tooltip helpers (current + saved, cleaned names)
--------------------------------------------------------------

local function GetSavedComboTooltip(outfitIndex)
    if outfitIndex == 0 then
        return "Base appearance is kept vanilla and cannot be accessorised."
    end

    local collectibles = GetMappingCollectiblesFor(outfitIndex)
    if not collectibles then
        return "No accessories saved for this outfit.\n\n"
            .. "Set your desired collectibles in Collections,\n"
            .. "then press \"Save current combo\".\n\n"
            .. "Note: saved combos apply only after zoning or using /reloadui."
    end

    local lines = {
        string.format("Saved accessories for %s:\n", GetOutfitDisplayName(outfitIndex))
    }

    for _, option in ipairs(COLLECTIBLE_OPTIONS) do
        if sv.enabledCategories and sv.enabledCategories[option.type] then
            local name = GetCollectibleNameOrNone(collectibles[option.type])
            table.insert(lines, string.format("%s: |cFFFFFF%s|r", option.label, name))
        end
    end

    table.insert(lines, "\nNote: changes apply on zone load or /reloadui.")
    return table.concat(lines, "\n")
end

local function GetCurrentComboTooltipForSave(outfitIndex)
    if outfitIndex == 0 then
        return "Base appearance is kept vanilla and cannot be accessorised."
    end

    local saved = GetMappingCollectiblesFor(outfitIndex)
    local lines = {
        "Saving to:",
        GetOutfitDisplayName(outfitIndex),
        "",
        "Current cosmetics:"
    }

    for _, option in ipairs(COLLECTIBLE_OPTIONS) do
        if sv.enabledCategories and sv.enabledCategories[option.type] then
            local currentName = GetCollectibleNameOrNone(GetActiveCollectibleSafe(option.type))
            table.insert(lines, string.format("  %s: |cFFFFFF%s|r", option.label, currentName))
        end
    end

    table.insert(lines, "")
    table.insert(lines, "Saved cosmetics:")

    for _, option in ipairs(COLLECTIBLE_OPTIONS) do
        if sv.enabledCategories and sv.enabledCategories[option.type] then
            local savedName = saved and GetCollectibleNameOrNone(saved[option.type]) or "None saved"
            table.insert(lines, string.format("  %s: |cFFFFFF%s|r", option.label, savedName))
        end
    end

    table.insert(lines, "")
    table.insert(lines, "Note: saved accessories only apply after zoning or using /reloadui.")

    return table.concat(lines, "\n")
end

local function GetClearTooltip(outfitIndex)
    if not HasAnySavedCollectibles(outfitIndex) then
        return "No accessories saved for this outfit."
    end

    return string.format(
        "This will remove all saved accessories for:\n%s",
        GetOutfitDisplayName(outfitIndex)
    )
end

--------------------------------------------------------------
-- Actions
--------------------------------------------------------------

local function SaveComboForSelectedOutfit()
    if selectedOutfitIndex == 0 then
        chat("Base appearance cannot be accessorised.")
        return
    end

    local collectibles = {}

    for _, option in ipairs(COLLECTIBLE_OPTIONS) do
        collectibles[option.type] = GetActiveCollectibleSafe(option.type)
    end

    sv.outfits[selectedOutfitIndex] = {
        collectibles = collectibles,
    }

    chat("Saved accessories for " .. GetOutfitDisplayName(selectedOutfitIndex))
end

local function RemoveAccessoriesForSelectedOutfit()
    sv.outfits[selectedOutfitIndex] = nil
    chat("Accessories removed for " .. GetOutfitDisplayName(selectedOutfitIndex))
end

--------------------------------------------------------------
-- Build dropdown
--------------------------------------------------------------

local function BuildOutfitDropdownItems()
    local items = {}

    table.insert(items, { name = GetOutfitDisplayName(0), data = 0 })

    local num = SafeGetNumOutfits()
    for i = 1, num do
        table.insert(items, {
            name = GetOutfitDisplayName(i),
            data = i,
        })
    end

    return items
end

--------------------------------------------------------------
-- LHAS Menu
--------------------------------------------------------------

local function InitSettingsMenu()
    if not LibHarvensAddonSettings then return end
    local LHAS = LibHarvensAddonSettings

    local settings = LHAS:AddAddon("Fashion Mount Settings", { allowDefaults = false })
    if not settings then return end

    selectedOutfitIndex = GetCurrentOutfitIndex()
    selectedOutfitLabel = GetOutfitDisplayName(selectedOutfitIndex)

    local outfitItems = BuildOutfitDropdownItems()

    ----------------------------------------------------------
    -- Info Label
    ----------------------------------------------------------
    settings:AddSetting({
        type  = LHAS.ST_LABEL,
        label = "Saved combos are applied only after a zone change or using /reloadui."
    })

    ----------------------------------------------------------
    -- Toggle: Addon enabled
    ----------------------------------------------------------
    settings:AddSetting({
        type        = LHAS.ST_CHECKBOX,
        label       = "Addon Enabled",
        tooltip     = "Turn FashionMount on or off.",
        default     = defaults.enabled,
        setFunction = function(v) sv.enabled = v end,
        getFunction = function() return sv.enabled end,
    })

    ----------------------------------------------------------
    -- Accessories toggles
    ----------------------------------------------------------
    settings:AddSetting({
        type  = LHAS.ST_SECTION,
        label = "Accessories to change with outfit"
    })

    for _, option in ipairs(COLLECTIBLE_OPTIONS) do
        settings:AddSetting({
            type        = LHAS.ST_CHECKBOX,
            label       = "Enable " .. option.label,
            tooltip     = "If enabled, your " .. string.lower(option.label) .. " will change with your outfit.",
            default     = defaults.enabledCategories[option.type],
            setFunction = function(v)
                sv.enabledCategories[option.type] = v
            end,
            getFunction = function()
                return sv.enabledCategories[option.type]
            end,
        })
    end

    ----------------------------------------------------------
    -- Outfit selector
    ----------------------------------------------------------
    settings:AddSetting({
        type  = LHAS.ST_SECTION,
        label = "Select Outfit Slot",
    })

    settings:AddSetting({
        type        = LHAS.ST_DROPDOWN,
        label       = "Outfit Slot",
        tooltip     = "Use left/right to choose which outfit slot to configure.",
        items       = outfitItems,
        default     = selectedOutfitLabel,
        setFunction = function(_, name, item)
            selectedOutfitIndex = item.data
            selectedOutfitLabel = name
        end,
        getFunction = function()
            return selectedOutfitLabel
        end,
    })

    settings:AddSetting({
        type  = LHAS.ST_LABEL,
        label = function()
            return "Selected: |cFFFFFF" .. GetOutfitDisplayName(selectedOutfitIndex) .. "|r"
        end,
    })

    ----------------------------------------------------------
    -- Buttons with detailed tooltips
    ----------------------------------------------------------
    settings:AddSetting({
        type         = LHAS.ST_BUTTON,
        label        = "Save current combo",
        tooltip      = function()
            return GetCurrentComboTooltipForSave(selectedOutfitIndex)
        end,
        buttonText   = "Save combo",
        clickHandler = SaveComboForSelectedOutfit,
        disable      = function()
            return (selectedOutfitIndex == 0)
        end,
    })

    settings:AddSetting({
        type         = LHAS.ST_BUTTON,
        label        = "Remove accessories",
        tooltip      = function()
            return GetClearTooltip(selectedOutfitIndex)
        end,
        buttonText   = "Remove",
        clickHandler = RemoveAccessoriesForSelectedOutfit,
        disable      = function()
            return not HasAnySavedCollectibles(selectedOutfitIndex)
        end,
    })

    settings:AddSetting({
        type  = LHAS.ST_LABEL,
        label = function()
            return GetSavedComboTooltip(selectedOutfitIndex)
        end,
    })

    ----------------------------------------------------------
    -- Signature
    ----------------------------------------------------------
    settings:AddSetting({
        type  = LHAS.ST_LABEL,
        label = "|cFFD700Built on tea, toast and ADHD – tested live on PS5.|r\n"
              .. "|cB427D3Su|c546D6Aga|c889764Co|cDA34CDma|r",
    })
end

--------------------------------------------------------------
-- REAL outfit change detection (PS5 safe)
--------------------------------------------------------------

local function OnOutfitChanged(_, actorCategory)
    -- Only react to player outfit changes
    if actorCategory ~= GAMEPLAY_ACTOR_CATEGORY_PLAYER then return end

    local idx = GetCurrentOutfitIndex()
    if idx ~= lastOutfitIndex then
        lastOutfitIndex = idx
        ApplyForOutfit(idx)
    end
end

--------------------------------------------------------------
-- Apply after zoning / reload
--------------------------------------------------------------

local function OnPlayerActivated()
    local idx = GetCurrentOutfitIndex()
    lastOutfitIndex = idx
    ApplyForOutfit(idx)
end

--------------------------------------------------------------
-- Addon init
--------------------------------------------------------------

local function OnAddonLoaded(event, name)
    if name ~= ADDON_NAME then return end
    EM:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    sv = ZO_SavedVars:NewCharacterIdSettings("FashionMount_SavedVars", 1, nil, defaults)
    sv.outfits = sv.outfits or {}
    sv.enabledCategories = sv.enabledCategories or {}

    -- Ensure all defaults exist for newly added categories
    for categoryType, enabledByDefault in pairs(defaults.enabledCategories) do
        if sv.enabledCategories[categoryType] == nil then
            sv.enabledCategories[categoryType] = enabledByDefault
        end
    end

    -- Migrate old saved data
    for _, data in pairs(sv.outfits) do
        if data and not data.collectibles then
            data.collectibles = {
                [COLLECTIBLE_CATEGORY_TYPE_MOUNT]       = data.mountId or 0,
                [COLLECTIBLE_CATEGORY_TYPE_VANITY_PET]  = data.petId or 0,
            }
            data.mountId = nil
            data.petId = nil
        end
        if data then
            data.personalityId = nil
            if data.collectibles then
                data.collectibles[COLLECTIBLE_CATEGORY_TYPE_PERSONALITY] = nil
            end
        end
    end
    sv.enabledCategories[COLLECTIBLE_CATEGORY_TYPE_PERSONALITY] = nil

    lastOutfitIndex = GetCurrentOutfitIndex()

    -- Detect outfit changes
    EM:RegisterForEvent(
        ADDON_NAME .. "_OutfitChanged",
        EVENT_OUTFIT_EQUIPMENT_CHANGED,
        OnOutfitChanged
    )

    -- Apply after zone load / login
    EM:RegisterForEvent(
        ADDON_NAME .. "_PlayerActivated",
        EVENT_PLAYER_ACTIVATED,
        OnPlayerActivated
    )

    InitSettingsMenu()
    chat("FashionMount loaded.")
end

EM:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)

--------------------------------------------------------------
-- Slash Command
--------------------------------------------------------------

SLASH_COMMANDS["/fm"] = function()
    local idx = GetCurrentOutfitIndex()
    chat("Current Outfit: " .. GetOutfitDisplayName(idx))
end
