local ADDON = "AutoUnbox"
local TITLE = "Auto Unbox"

local TICK_MS = 100          -- queue poll interval, only while something is queued
local OPEN_TIMEOUT_MS = 3000 -- no visible result after UseItem within this time = failed try
local LOOT_TIMEOUT_MS = 2000 -- loot still open this long after Take All = leftovers we can't take
local RETRY_DELAY_MS = 1000
local MAX_ATTEMPTS = 3

local CONTAINER_TYPES = {
    [ITEMTYPE_CONTAINER] = true,
    [ITEMTYPE_CONTAINER_CURRENCY] = true,
}
if ITEMTYPE_CONTAINER_STACKABLE then
    CONTAINER_TYPES[ITEMTYPE_CONTAINER_STACKABLE] = true
end

-- Containers that turn into another item. Skipped by auto-open only; Unbox All opens them.
local IGNORE_SURVEYS = {
    [219849] = true, [219850] = true, [219851] = true, -- Unidentified <craft> Survey Report
    [219852] = true, [219853] = true, [219854] = true,
    [224707] = true, -- Sealed Survey Report Stack
}
local IGNORE_WRITS = {
    [217917] = true, [217918] = true, [217919] = true, [217920] = true, -- Unknown <craft> Writ
    [217921] = true, [217922] = true, [217923] = true,
}
local IGNORE_MAPS = {
    [224681] = true, -- Unopened Treasure Map
    [45879] = true, [45880] = true, [45881] = true, [45882] = true, -- old treasure map containers
}

-- Opening these at the cap would waste the crystals.
local TRANSMUTE_GEODES = {
    [134583] = true, [134588] = true, [134590] = true, [134591] = true, [134618] = true,
    [134622] = true, [134623] = true, [171531] = true, [211304] = true, [211305] = true,
}

local defaults = {
    autoOpen = true,
    ignoreSurveys = true,
    ignoreWrits = true,
    ignoreMaps = true,
}

local sv
local queue = {}  -- entries waiting to be opened, in order
local queued = {} -- slotIndex -> entry, for everything queued or in flight
local inFlight    -- { entry, stack, startedMs, lootedMs } for the container being opened now
local ticking = false
local stripShown = false
local Tick, RefreshKeybind

local function Print(message)
    CHAT_ROUTER:AddSystemMessage("|c8FBC8F" .. TITLE .. ":|r " .. message)
end

local function IsAtTransmuteCap()
    return GetCurrencyAmount(CURT_CHAOTIC_CREATIA, CURRENCY_LOCATION_ACCOUNT)
        >= GetMaxPossibleCurrency(CURT_CHAOTIC_CREATIA, CURRENCY_LOCATION_ACCOUNT)
end

local function IsIgnoredForAuto(itemId)
    return (sv.ignoreSurveys and IGNORE_SURVEYS[itemId])
        or (sv.ignoreWrits and IGNORE_WRITS[itemId])
        or (sv.ignoreMaps and IGNORE_MAPS[itemId])
end

-- Can this slot be opened at all (ignoring temporary blockers like combat)?
local function IsOpenable(slot)
    if not CONTAINER_TYPES[GetItemType(BAG_BACKPACK, slot)] then return false end
    local usable, onlyFromActionSlot = IsItemUsable(BAG_BACKPACK, slot)
    if not usable or onlyFromActionSlot then return false end
    local _, _, _, meetsUsageRequirement = GetItemInfo(BAG_BACKPACK, slot)
    if not meetsUsageRequirement then return false end
    if TRANSMUTE_GEODES[GetItemId(BAG_BACKPACK, slot)] and IsAtTransmuteCap() then return false end
    return true
end

local function HasOpenable()
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if IsOpenable(slot) then return true end
    end
    return false
end

-- Things during which using an item fails or would interrupt something.
local function IsBusy()
    return IsUnitInCombat("player")
        or IsUnitSwimming("player")
        or IsUnitDeadOrReincarnating("player")
        or IsLooting()
        or GetInteractionType() ~= INTERACTION_NONE
        or GetHousingEditorMode() ~= HOUSING_EDITOR_MODE_DISABLED
end

local function IsActive()
    return ticking
end

local function StartTicking()
    if ticking then return end
    ticking = true
    EVENT_MANAGER:RegisterForUpdate(ADDON .. "Tick", TICK_MS, Tick)
    RefreshKeybind()
end

local function StopTicking()
    EVENT_MANAGER:UnregisterForUpdate(ADDON .. "Tick")
    ticking = false
    RefreshKeybind()
end

local function Clear()
    if inFlight and IsLooting() then
        EndLooting()
    end
    inFlight = nil
    ZO_ClearNumericallyIndexedTable(queue)
    ZO_ClearTable(queued)
    StopTicking()
end

local function Enqueue(slot, manual)
    local itemId = GetItemId(BAG_BACKPACK, slot)
    local entry = queued[slot]
    if entry then
        -- Already queued or being opened: refresh it instead of adding a duplicate.
        if entry.itemId == itemId then
            entry.manual = entry.manual or manual
        else
            entry.manual = manual
            entry.itemId = itemId
        end
        entry.attempts = 0
        entry.notBeforeMs = 0
        return
    end
    entry = { slot = slot, itemId = itemId, manual = manual, attempts = 0, notBeforeMs = 0 }
    queued[slot] = entry
    queue[#queue + 1] = entry
    StartTicking()
end

local function Retry(entry, now)
    entry.attempts = entry.attempts + 1
    if entry.attempts >= MAX_ATTEMPTS then
        queued[entry.slot] = nil
        Print(zo_strformat("couldn't open <<1>>, skipping it.", GetItemLink(BAG_BACKPACK, entry.slot)))
        return
    end
    entry.notBeforeMs = now + RETRY_DELAY_MS
    queue[#queue + 1] = entry
end

local function CheckInFlight(now)
    local flight = inFlight
    local entry = flight.entry

    if IsLooting() then
        if flight.lootedMs then
            if now - flight.lootedMs > LOOT_TIMEOUT_MS then
                -- Something in it can't be taken (e.g. a unique item we already have).
                EndLooting()
            end
        elseif now - flight.startedMs > OPEN_TIMEOUT_MS then
            -- A loot window that isn't ours; leave it alone and try again later.
            inFlight = nil
            Retry(entry, now)
        end
        return
    end

    local itemId = GetItemId(BAG_BACKPACK, entry.slot)
    local stack = GetSlotStackSize(BAG_BACKPACK, entry.slot)
    if itemId ~= entry.itemId or stack < flight.stack then
        inFlight = nil
        if itemId == entry.itemId and stack > 0 then
            -- One opened, more of the stack left: open the next one right away.
            entry.attempts = 0
            table.insert(queue, 1, entry)
        else
            queued[entry.slot] = nil
        end
    elseif now - flight.startedMs > OPEN_TIMEOUT_MS then
        inFlight = nil
        Retry(entry, now)
    end
end

function Tick()
    local now = GetFrameTimeMilliseconds()

    if inFlight then
        CheckInFlight(now)
        if inFlight then return end
    end

    if #queue == 0 then
        StopTicking()
        return
    end

    if IsBusy() then return end

    local index
    for i, entry in ipairs(queue) do
        if entry.notBeforeMs <= now then
            index = i
            break
        end
    end
    if not index then return end

    local entry = queue[index]
    local slot = entry.slot

    if GetItemId(BAG_BACKPACK, slot) ~= entry.itemId or not IsOpenable(slot) then
        table.remove(queue, index)
        queued[slot] = nil
        return
    end

    -- Containers share a short use cooldown; just wait it out.
    if GetItemCooldownInfo(BAG_BACKPACK, slot) > 0 then return end

    if GetItemType(BAG_BACKPACK, slot) ~= ITEMTYPE_CONTAINER_CURRENCY
       and GetNumBagFreeSlots(BAG_BACKPACK) == 0
    then
        PlaySound(SOUNDS.NEGATIVE_CLICK)
        Print("bag full, unboxing stopped.")
        Clear()
        return
    end

    table.remove(queue, index)

    if not CanInteractWithItem(BAG_BACKPACK, slot) then
        Retry(entry, now)
        return
    end

    inFlight = { entry = entry, stack = GetSlotStackSize(BAG_BACKPACK, slot), startedMs = now }
    if not CallSecureProtected("UseItem", BAG_BACKPACK, slot) then
        inFlight = nil
        Retry(entry, now)
    end
end

local function OnLootUpdated()
    local flight = inFlight
    if not flight or flight.lootedMs then return end
    flight.lootedMs = GetFrameTimeMilliseconds()

    local autoCraftBag = HasCraftBagAccess()
        and GetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_ADD_TO_CRAFT_BAG) == "1"
    local slotsNeeded = 0
    for lootIndex = 1, GetNumLootItems() do
        local lootId = GetLootItemInfo(lootIndex)
        if GetLootItemType(lootId) == LOOT_TYPE_ITEM
           and not (autoCraftBag and CanItemLinkBeVirtual(GetLootItemLink(lootId)))
        then
            slotsNeeded = slotsNeeded + 1
        end
    end
    if not CheckInventorySpaceAndWarn(slotsNeeded) then
        Print("not enough bag space, unboxing stopped.")
        Clear()
        return
    end
    LOOT_SHARED:LootAllItems()
end

-- Keep the loot window from flashing up for containers we open.
local function HookLootWindows()
    local function Suppress()
        return inFlight ~= nil
    end
    for _, getter in ipairs({ "GetKeyboardObject", "GetGamepadObject" }) do
        local lootWindow = SYSTEMS[getter] and SYSTEMS[getter](SYSTEMS, "loot")
        if lootWindow and lootWindow.UpdateLootWindow then
            ZO_PreHook(lootWindow, "UpdateLootWindow", Suppress)
        end
    end
end

local function OnNewItem(_, _, slot)
    if not sv.autoOpen then return end
    if not CONTAINER_TYPES[GetItemType(BAG_BACKPACK, slot)] then return end
    if IsIgnoredForAuto(GetItemId(BAG_BACKPACK, slot)) then return end
    Enqueue(slot, false)
end

function AutoUnbox_UnboxAll()
    if IsActive() then
        Clear()
        return
    end
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if IsOpenable(slot) then
            Enqueue(slot, true)
        end
    end
end

local keybindGroup = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    {
        name = function() return IsActive() and "Cancel Unbox All" or "Unbox All" end,
        keybind = "AUTOUNBOX_UNBOX_ALL",
        order = 100,
        visible = function()
            return IsActive() or (GetInteractionType() == INTERACTION_NONE and HasOpenable())
        end,
        callback = AutoUnbox_UnboxAll,
    },
}

function RefreshKeybind()
    if stripShown then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(keybindGroup)
    end
end

-- Backpack changes come in bursts; refresh the button once after the last one.
local function QueueKeybindRefresh()
    if not stripShown then return end
    EVENT_MANAGER:UnregisterForUpdate(ADDON .. "KeybindRefresh")
    EVENT_MANAGER:RegisterForUpdate(ADDON .. "KeybindRefresh", 100, function()
        EVENT_MANAGER:UnregisterForUpdate(ADDON .. "KeybindRefresh")
        RefreshKeybind()
    end)
end

local function SetupSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end
    LAM:RegisterAddonPanel(ADDON .. "Options", {
        type = "panel",
        name = TITLE,
        author = "Schrodi",
        version = "1.0",
        registerForDefaults = true,
    })
    local function NotAuto() return not sv.autoOpen end
    LAM:RegisterOptionControls(ADDON .. "Options", {
        {
            type = "checkbox",
            name = "Open new containers automatically",
            tooltip = "Opens every container as soon as it lands in your backpack. Unbox All in the inventory works either way.",
            getFunc = function() return sv.autoOpen end,
            setFunc = function(value) sv.autoOpen = value end,
            default = defaults.autoOpen,
        },
        { type = "header", name = "Don't open automatically" },
        {
            type = "description",
            text = "These only affect automatic opening. Unbox All still opens them.",
        },
        {
            type = "checkbox",
            name = "Unidentified survey reports",
            getFunc = function() return sv.ignoreSurveys end,
            setFunc = function(value) sv.ignoreSurveys = value end,
            default = defaults.ignoreSurveys,
            disabled = NotAuto,
        },
        {
            type = "checkbox",
            name = "Unknown writs",
            getFunc = function() return sv.ignoreWrits end,
            setFunc = function(value) sv.ignoreWrits = value end,
            default = defaults.ignoreWrits,
            disabled = NotAuto,
        },
        {
            type = "checkbox",
            name = "Unopened treasure maps",
            getFunc = function() return sv.ignoreMaps end,
            setFunc = function(value) sv.ignoreMaps = value end,
            default = defaults.ignoreMaps,
            disabled = NotAuto,
        },
    })
end

ZO_CreateStringId("SI_AUTOUNBOX", TITLE)
ZO_CreateStringId("SI_BINDING_NAME_AUTOUNBOX_UNBOX_ALL", "Unbox All")

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)

    sv = ZO_SavedVars:NewAccountWide("AutoUnbox_SV", 1, nil, defaults)

    EVENT_MANAGER:RegisterForEvent(ADDON .. "NewItem", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnNewItem)
    EVENT_MANAGER:AddFilterForEvent(ADDON .. "NewItem", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    EVENT_MANAGER:AddFilterForEvent(ADDON .. "NewItem", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_IS_NEW_ITEM, true)
    EVENT_MANAGER:AddFilterForEvent(ADDON .. "NewItem", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)

    EVENT_MANAGER:RegisterForEvent(ADDON .. "Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, QueueKeybindRefresh)
    EVENT_MANAGER:AddFilterForEvent(ADDON .. "Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)

    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_LOOT_UPDATED, OnLootUpdated)

    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED)
        HookLootWindows()
    end)

    BACKPACK_MENU_BAR_LAYOUT_FRAGMENT:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_FRAGMENT_SHOWN then
            KEYBIND_STRIP:AddKeybindButtonGroup(keybindGroup)
            stripShown = true
        elseif newState == SCENE_FRAGMENT_HIDING then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(keybindGroup)
            stripShown = false
        end
    end)

    SetupSettings()
end)
