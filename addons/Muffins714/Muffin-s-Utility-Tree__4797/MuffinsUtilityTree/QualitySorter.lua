-- Create a local shortcut for global
local MUT = MuffinsUtilityTree

--[[ TODO
See if it's possible to add quality sorter to the listing page
so when we sell something in the Guild Trader we can organize it by quality
]]
---------------------------------------------------------------------------------------------
-- Craft Bag quality sort
---------------------------------------------------------------------------------------------
-- Sort by quality craft bag only uses these 5 tiers
local QUALITY_RANK = {
    [ITEM_DISPLAY_QUALITY_NORMAL]    = 1, -- White
    [ITEM_DISPLAY_QUALITY_MAGIC]     = 2, -- Green
    [ITEM_DISPLAY_QUALITY_ARCANE]    = 3, -- Blue
    [ITEM_DISPLAY_QUALITY_ARTIFACT]  = 4, -- Purple
    [ITEM_DISPLAY_QUALITY_LEGENDARY] = 5, -- Gold
}

local function QualitySortFuncDescending(item1, item2)
    local q1 = QUALITY_RANK[item1.displayQuality] or 0
    local q2 = QUALITY_RANK[item2.displayQuality] or 0

    if q1 ~= q2 then
        return q1 > q2 -- Legendary first
    end

    -- If same quality sort by name
    local name1 = item1.name or ""
    local name2 = item2.name or ""
    return name1 < name2
end

local function QualitySortFuncAscending(item1, item2)
    local q1 = QUALITY_RANK[item1.displayQuality] or 0
    local q2 = QUALITY_RANK[item2.displayQuality] or 0

    if q1 ~= q2 then
        return q1 < q2 -- Legendary last
    end

    local name1 = item1.name or ""
    local name2 = item2.name or ""
    return name1 < name2
end

-- Temporary sort state so it resets when leaving craft bag
local currentSortDirection = nil

local function ApplySort(direction)
    if not GAMEPAD_INVENTORY or not GAMEPAD_INVENTORY.craftBagList then return end

    currentSortDirection = direction

    if direction == true then
        GAMEPAD_INVENTORY.craftBagList:SetSortFunction(QualitySortFuncDescending)
    elseif direction == false then
        GAMEPAD_INVENTORY.craftBagList:SetSortFunction(QualitySortFuncAscending)
    else
        GAMEPAD_INVENTORY.craftBagList:SetSortFunction(nil)
    end
end

local function CycleQualitySort()
    if currentSortDirection == nil then
        ApplySort(true)
    elseif currentSortDirection == true then
        ApplySort(false)
    else
        ApplySort(nil)
    end
end

---------------------------------------------------------------------------------------------
-- Keybind
---------------------------------------------------------------------------------------------
-- Adds the sort button to the craft bag keybind strip
--TODO Add option to change keybind?
local function GetKeybindLabel()
    if currentSortDirection == true then
        return GetString(MUT_QUALITY_SORTER_KEYBIND_DESC)
    elseif currentSortDirection == false then
        return GetString(MUT_QUALITY_SORTER_KEYBIND_ASC)
    else
        return GetString(MUT_QUALITY_SORTER_KEYBIND_OFF)
    end
end

local qualitySortKeybindEntry = {
    name = GetKeybindLabel,
    keybind = "UI_SHORTCUT_QUATERNARY",
    callback = function()
        CycleQualitySort()
        KEYBIND_STRIP:UpdateKeybindButtonGroup(GAMEPAD_INVENTORY.craftBagKeybindStripDescriptor)
    end,
}

local isKeybindInjected = false

local function RemoveKeybind()
    if not isKeybindInjected then return end
    if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.craftBagKeybindStripDescriptor then
        for i, entry in ipairs(GAMEPAD_INVENTORY.craftBagKeybindStripDescriptor) do
            if entry == qualitySortKeybindEntry then
                table.remove(GAMEPAD_INVENTORY.craftBagKeybindStripDescriptor, i)
                break
            end
        end
        if GAMEPAD_INVENTORY.craftBagList and GAMEPAD_INVENTORY.craftBagList:IsActive() then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(GAMEPAD_INVENTORY.craftBagKeybindStripDescriptor)
        end
    end
    isKeybindInjected = false
end

---------------------------------------------------------------------------------------------
-- Hooks and Handlers
---------------------------------------------------------------------------------------------
-- Retry till inventory exists, if fails recheck when opened
local function EnsureKeybindInjected(attempt)
    if isKeybindInjected then return end
    -- Stop retrying if the setting gets turned off
    if not MUT.GetSettings().qualitySortEnabled then return end
    attempt = attempt or 1

    if not GAMEPAD_INVENTORY or not GAMEPAD_INVENTORY.craftBagKeybindStripDescriptor then
        if attempt < 10 then -- Try 10 times within 2 sec
            zo_callLater(function() EnsureKeybindInjected(attempt + 1) end, 200)
        end
        return
    end

    table.insert(GAMEPAD_INVENTORY.craftBagKeybindStripDescriptor, qualitySortKeybindEntry)
    isKeybindInjected = true
end

-- Recheck keybind whenever entering craft bag so it always appears, even if initial load attempt failed
local function OnSwitchActiveList(inventory, listDescriptor)
    if listDescriptor == "craftBagList" then
        EnsureKeybindInjected()
    elseif currentSortDirection ~= nil then
        ApplySort(nil)
    end
end

local isHooked = false

local function EnsureHooked(attempt)
    if isHooked then return end
    attempt = attempt or 1

    if not GAMEPAD_INVENTORY then
        if attempt < 10 then
            zo_callLater(function() EnsureHooked(attempt + 1) end, 200)
        end
        return
    end

    SecurePostHook(GAMEPAD_INVENTORY, "SwitchActiveList", OnSwitchActiveList)
    isHooked = true
end

---------------------------------------------------------------------------------------------
-- Enable / disable
---------------------------------------------------------------------------------------------
function MUT.SetQualitySortEnabled(isEnabled)
    if isEnabled then
        EnsureKeybindInjected()
    else
        if currentSortDirection ~= nil then
            ApplySort(nil)
        end
        RemoveKeybind()
    end
end

---------------------------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------------------------
function MUT.Initialize_QualitySorter()
    -- Always hook this so reset on leave works even if enabled mid session
    EnsureHooked()

    local settings = MUT.GetSettings()
    if settings.qualitySortEnabled then
        EnsureKeybindInjected()
    end
end
