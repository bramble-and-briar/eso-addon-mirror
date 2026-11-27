-- -----------------------------------------------------------------------------
-- LibEquipmentBonus
-- Author:  g4rr3t
-- Created: Oct 19, 2018
--
-- LibEquipmentBonus.lua
-- -----------------------------------------------------------------------------

local leb = {}

if not LibEquipmentBonus then LibEquipmentBonus = leb
else return end

local libName       = 'LibEquipmentBonus'
local prefix        = '[LibEquipmentBonus] '

-- Shared Data
leb.sets            = leb.sets      or {}
leb.cp              = leb.cp        or {}
leb.perfected       = leb.perfected or {}
leb.items           = leb.items     or {}
leb.addons          = leb.addons    or {}

-- Upvar
local sets          = leb.sets
local perfected     = leb.perfected
local items         = leb.items
local addons        = leb.addons

-- Slots to monitor
local ITEM_SLOTS    = {
    EQUIP_SLOT_HEAD,
    EQUIP_SLOT_NECK,
    EQUIP_SLOT_CHEST,
    EQUIP_SLOT_SHOULDERS,
    EQUIP_SLOT_MAIN_HAND,
    EQUIP_SLOT_OFF_HAND,
    EQUIP_SLOT_WAIST,
    EQUIP_SLOT_LEGS,
    EQUIP_SLOT_FEET,
    EQUIP_SLOT_RING1,
    EQUIP_SLOT_RING2,
    EQUIP_SLOT_HAND,
    EQUIP_SLOT_BACKUP_MAIN,
    EQUIP_SLOT_BACKUP_OFF
}

local PerfectString = { "Perfected ", "Perfect " }

local function RenameWhenPerfectSet(setName)

  if perfected[setName] ~= nil then
    return perfected[setName]
  end

  -- Check for Perfect/Perfected
  local isPerfect = string.find(setName, "Perfect")

  -- Only if a perfect set is suspect do we run through
  -- our table of "Perfect" strings to replace
  if isPerfect ~= nil and isPerfect > 0 then

    -- Normalize Perfect and Non-Perfect variant names
    for _, perfectString in ipairs(PerfectString) do

      -- Find strings related to being Perfect
      local newSetName, count = string.gsub(setName, perfectString, "")

      -- Update name if a perfect version is detected
      if count > 0 then
        perfected[setName] = newSetName
        return newSetName
      end
    end
  end

  -- Return unmodified if perfect could not be matched
  return setName
end

local function GetNumSetBonuses(itemLink)
    local _, _, _, equipType = GetItemLinkInfo(itemLink)
    if equipType == EQUIP_TYPE_TWO_HAND then -- 2H weapons, staves, bows count as two set pieces
        return 2
    else
        return 1
    end
end

local function Trace(addon, debugLevel, ...)
    if debugLevel <= addon.debugMode then
        local message = zo_strformat(...)
        d(prefix .. '[' .. addon.addonId .. '] ' .. message)
    end
end

local function AddSetBonus(slot, itemLink)
    local hasSet, setName, _, _, maxEquipped, total = GetItemLinkSetInfo(itemLink, true)

    local name = RenameWhenPerfectSet(setName)

    -- if name ~= setName then
    --   d(setName .. " updated to " .. name)
    -- end

    if hasSet then
        if leb.sets[name] == nil then  -- Initialize first time encountering a set
            leb.sets[name]             = {}
            leb.sets[name].maxBonus    = maxEquipped
            leb.sets[name].equippedMax = false
            leb.sets[name].bonuses     = {}
        end

        -- Update bonuses
        leb.sets[name].bonuses[slot] = GetNumSetBonuses(itemLink)
    end
end

local function RemoveSetBonus(slot, itemLink)
    local hasSet, setName, _, _, _, _ = GetItemLinkSetInfo(itemLink, true)

    local name = RenameWhenPerfectSet(setName)

    if hasSet then  -- Don't remove bonus if bonus wasn't added to begin with
        if leb.sets[name] ~= nil and leb.sets[name].bonuses[slot] ~= nil then
            leb.sets[name].bonuses[slot] = 0
        end
    end
end

local function UpdateEnabledSets(forceNotify)

    for key, set in pairs(leb.sets) do
        if set ~= nil then
            -- Console-safe dual-bar set check:
            -- Count armor/jewelry on both bars, but never add front- and back-bar
            -- weapons together. The tracker stays enabled when EITHER bar reaches
            -- the set's full bonus (normally 5 pieces).
            local sharedBonus = 0
            local frontBonus = 0
            local backBonus = 0

            for slot, bonus in pairs(set.bonuses) do
                if slot == EQUIP_SLOT_MAIN_HAND or slot == EQUIP_SLOT_OFF_HAND then
                    frontBonus = frontBonus + bonus
                elseif slot == EQUIP_SLOT_BACKUP_MAIN or slot == EQUIP_SLOT_BACKUP_OFF then
                    backBonus = backBonus + bonus
                else
                    sharedBonus = sharedBonus + bonus
                end
            end

            local frontTotal = sharedBonus + frontBonus
            local backTotal = sharedBonus + backBonus
            local hasFullSetOnEitherBar = (frontTotal >= set.maxBonus) or (backTotal >= set.maxBonus)

            local setMaxDidChange = false  -- Establish enabled and changed state
            if hasFullSetOnEitherBar then
                if not leb.sets[key].equippedMax then
                    setMaxDidChange = true
                    leb.sets[key].equippedMax = true
                end
            else
                if leb.sets[key].equippedMax then
                    setMaxDidChange = true
                    leb.sets[key].equippedMax = false
                end
            end

            if setMaxDidChange or forceNotify ~= nil then  -- Notify addons
                for i=1, #addons do
                    if (addons[i].filterBySetName == nil or addons[i].filterBySetName == key) then
                        if (forceNotify ~= nil and forceNotify == addons[i].addonId) or forceNotify == nil then
                            Trace(addons[i], 1, "Notifying set update for: <<1>> (Enabled: <<2>>)", key, tostring(leb.sets[key].equippedMax))
                            addons[i].EquipmentUpdateCallback(key, leb.sets[key].equippedMax)
                        else
                            Trace(addons[i], 2, "Force notify not matched, not notifying for: <<1>> (Enabled: <<2>>)", key, tostring(leb.sets[key].equippedMax))
                        end
                    else
                        Trace(addons[i], 2, "Filter prevents notify: <<1>> (Enabled: <<2>>)", key, tostring(leb.sets[key].equippedMax))
                    end
                end
            end
            setMaxDidChange = false  -- Reset change state
        end
    end
end

local function UpdateSingleSlot(slotId, itemLink)
    local previousLink = leb.items[slotId]

    leb.items[slotId] = itemLink  -- Update equipped item

    if itemLink == previousLink then return  -- Item did not change

    elseif itemLink == '' then RemoveSetBonus(slotId, previousLink) -- Item Removed (slot empty)

    else  -- Item Changed
        RemoveSetBonus(slotId, previousLink)
        AddSetBonus(slotId, itemLink)
    end
    UpdateEnabledSets()
end

local function WornSlotUpdate(eventCode, bagId, slotId, isNewItem, itemSoundCategory, updateReason)
    -- Ignore costume updates
    if slotId == EQUIP_SLOT_COSTUME then return end

    local itemLink = GetItemLink(bagId, slotId)
    UpdateSingleSlot(slotId, itemLink)
end

local function UpdateAllSlots()
    for index, slot in pairs(ITEM_SLOTS) do
        local itemLink = GetItemLink(BAG_WORN, slot)
        if itemLink ~= "" then
            leb.items[slot] = itemLink
            AddSetBonus(slot, itemLink)
        end
    end
end

local function UpdateArmorySlots(e,resultId) -- thanks to @CyberOnESO
	if resultId ~= ARMORY_BUILD_RESTORE_RESULT_SUCCESS then return false end
    for index, slot in pairs(ITEM_SLOTS) do
		local itemLink = GetItemLink(BAG_WORN, slot)
        UpdateSingleSlot(slot, itemLink)
    end
end

-- Handle CP changes
local function UpdateCPSlottables(_, championPurchaseResult)
    if championPurchaseResult == CHAMPION_PURCHASE_SUCCESS then
        local equippedCp = {}
        for i = 1, 12 do
            local cpId = GetSlotBoundId(i, HOTBAR_CATEGORY_CHAMPION)
            local cpName = GetChampionSkillName(cpId)
            equippedCp[cpName] = {}
            equippedCp[cpName].id = cpId
        end
        leb.cp = equippedCp
        for i=1, #addons do
            Trace(addons[i], 1, "Notifying set update for cp change: <<1>>", tostring(leb.cp))
            addons[i].CpUpdateCallback(leb.cp)
        end
    end
end

function leb:SetDebug(debugLevel)
    -- Level of debug output
    -- 1: Low    - Basic debug info, show core functionality
    -- 2: Medium - More information about skills and addon details
    -- 3: High   - Everything
    self.debugMode = debugLevel
    Trace(self, 1, "Setting debug to <<1>>", debugLevel)
end

function leb:FilterBySetName(setName)
    self.filterBySetName = setName
    Trace(self, 1, "Added filter for: <<1>>", setName)
end

function leb:Register(gearCallback, cpCallback)
    if gearCallback == nil then
        Trace(self, 0, 'Callback function required! Aborting register.')
        return
    end
    self.EquipmentUpdateCallback = gearCallback
    self.CpUpdateCallback = cpCallback
    EVENT_MANAGER:RegisterForEvent(libName, EVENT_CHAMPION_PURCHASE_RESULT, UpdateCPSlottables)
    EVENT_MANAGER:RegisterForEvent(libName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, WornSlotUpdate)
    EVENT_MANAGER:AddFilterForEvent(libName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)

    EVENT_MANAGER:RegisterForEvent(libName, EVENT_ARMORY_BUILD_RESTORE_RESPONSE, UpdateArmorySlots)

    if next(leb.items) == nil then
        Trace(self, 2, 'Populating equipped items')
        UpdateAllSlots()
    else
        Trace(self, 2, 'Equipped items already populated')
    end
    UpdateEnabledSets(self.addonId)
end

function leb:IsSetEquipped(setName)
  local isEquipped = false
  local set = leb.sets[setName]
  if set ~= nil then
    isEquipped = set.equippedMax or false
  end
  return isEquipped
end

-- GetItemLinkSetBonusInfo(itemLink, (boolean) equipped, index)
-- Returns: numRequired, bonusDescription
-- GetItemLinkSetInfo(itemLink, (boolean) equipped)
-- Returns: hasSet, setName, numBonuses, numEquipped, maxEquipped, setId, total - (not mentioned, actual numEquipped?)

function leb:Init(addonId)
    if type(addonId) ~= 'string' or string.len(addonId) == 0 then
        PrintLater('[LibEquipmentBonus] Addon ID must be a string! Aborting initialization.')
        return
    end

    local lib = {}
    lib.addonId = addonId
    lib.debugMode = 0

    setmetatable(lib, self)
    self.__index = self

    addons[#leb.addons+1] = lib

    return lib
end
