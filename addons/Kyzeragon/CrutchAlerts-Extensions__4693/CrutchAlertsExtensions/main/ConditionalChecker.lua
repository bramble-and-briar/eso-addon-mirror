local CAE = CrutchAlertsExtensions
local Crutch = CrutchAlerts


---------------------------------------------------------------------
-- Ability
---------------------------------------------------------------------
local function IsSlotted(id, activeBarOnly)
    -- If ww, check only ww and not regular bars
    if (IsPlayerInWerewolfForm()) then
        for i = 3, 8 do
            local abilityId = Crutch.GetSlotTrueBoundId(i, HOTBAR_CATEGORY_WEREWOLF)
            if (abilityId == id) then return true end
        end
        return false
    end

    local otherBar = (GetActiveHotbarCategory() == HOTBAR_CATEGORY_PRIMARY) and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
    for i = 3, 8 do
        local abilityId = Crutch.GetSlotTrueBoundId(i, GetActiveHotbarCategory())
        if (abilityId == id) then return true end

        if (not activeBarOnly) then
            local otherBarAbilityId = Crutch.GetSlotTrueBoundId(i, otherBar)
            if (otherBarAbilityId == id) then return true end
        end
    end
    return false
end


---------------------------------------------------------------------
-- Set
---------------------------------------------------------------------
-- This code *would've* been really easy, but GetItemSetInfo only returns the num equipped for the active bar, and I want both bars...
local ITEM_SLOTS_BODY = {
    EQUIP_SLOT_HEAD,
    EQUIP_SLOT_NECK,
    EQUIP_SLOT_CHEST,
    EQUIP_SLOT_SHOULDERS,
    EQUIP_SLOT_WAIST,
    EQUIP_SLOT_LEGS,
    EQUIP_SLOT_FEET,
    EQUIP_SLOT_RING1,
    EQUIP_SLOT_RING2,
    EQUIP_SLOT_HAND,
}

local ITEM_SLOTS_FRONTBAR = {
    EQUIP_SLOT_MAIN_HAND,
    EQUIP_SLOT_OFF_HAND,
}

local ITEM_SLOTS_BACKBAR = {
    EQUIP_SLOT_BACKUP_MAIN,
    EQUIP_SLOT_BACKUP_OFF,
}

local equipped = {}
CAE.equipped = equipped

local function GetNumSetBonuses(itemLink)
    local _, _, _, equipType = GetItemLinkInfo(itemLink)
    -- 2H weapons, staves, bows count as two set pieces
    if equipType == EQUIP_TYPE_TWO_HAND then
        return 2
    else
        return 1
    end
end

-- {[setId] = {body = 3, frontbar = 2, backbar = 0}}
local function AddEquippedSetsInSlots(tab, key)
    for _, slot in ipairs(tab) do
        local itemLink = GetItemLink(BAG_WORN, slot)
        local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(itemLink, true)
        if (hasSet) then
            if (not equipped[setId]) then
                equipped[setId] = {body = 0, frontbar = 0, backbar = 0}
            end
            equipped[setId][key] = equipped[setId][key] + GetNumSetBonuses(itemLink)
        end
    end
end

local function CalculateEquippedSets()
    EVENT_MANAGER:UnregisterForUpdate(CAE.name .. "EquippedTimeout")
    ZO_ClearTable(equipped)

    AddEquippedSetsInSlots(ITEM_SLOTS_BODY, "body")
    AddEquippedSetsInSlots(ITEM_SLOTS_FRONTBAR, "frontbar")
    AddEquippedSetsInSlots(ITEM_SLOTS_BACKBAR, "backbar")

    CAE.UpdateShapes()
end

local function IsEquipped(setId, activeBarOnly)
    if (not equipped[setId]) then return false end
    local _, setName, _, _, _, maxEquipped = GetItemSetInfo(setId)
    if (not activeBarOnly) then
        return (equipped[setId].body + equipped[setId].frontbar >= maxEquipped) or (equipped[setId].body + equipped[setId].backbar >= maxEquipped)
    else
        if (GetHeldWeaponPair() == ACTIVE_WEAPON_PAIR_MAIN) then
            return (equipped[setId].body + equipped[setId].frontbar >= maxEquipped)
        else -- TODO: when can it be NONE?
            return (equipped[setId].body + equipped[setId].backbar >= maxEquipped)
        end
    end
end

local function GetEquippedSetsString()
    local result = ""
    for setId, _ in pairs(equipped) do
        if (IsEquipped(setId, false)) then
            local _, setName = GetItemSetInfo(setId)
            result = string.format("%s\n%d - %s", result, setId, setName)
        end
    end
    return result
end
CAE.GetEquippedSetsString = GetEquippedSetsString

--------------
-- Set updates
local function OnSlotUpdated(_, _, slotId)
    -- Ignore costume updates, poison updates
    if (slotId == EQUIP_SLOT_COSTUME or slotId == EQUIP_SLOT_POISON or slotId == EQUIP_SLOT_BACKUP_POISON) then return end

    EVENT_MANAGER:RegisterForUpdate(CAE.name .. "EquippedTimeout", 1000, CalculateEquippedSets)
end


---------------------------------------------------------------------
-- Buff
---------------------------------------------------------------------
local effects = {}
local trackedEffects = {} -- {[12345] = true,}

local function OnEffectChanged(_, changeType, _, _, _, _, _, _, _, _, _, _, _, _, _, abilityId)
    if (changeType == EFFECT_RESULT_GAINED) then
        effects[abilityId] = true
        CAE.UpdateShapes()
    elseif (changeType == EFFECT_RESULT_FADED) then
        effects[abilityId] = nil
        CAE.UpdateShapes()
    end
end

local function InitEffects()
    -- Unregister previous
    for abilityId, _ in pairs(trackedEffects) do
        EVENT_MANAGER:UnregisterForEvent(CAE.name .. "ConditionalEffect" .. abilityId, EVENT_EFFECT_CHANGED)
    end
    ZO_ClearTable(trackedEffects)

    -- Collect all buffs needed to be tracked from profile
    local profile = CAE.profiles[CAE.csvs.currentProfile]
    for _, shapeData in pairs(profile.circles) do
        for _, id in ipairs(shapeData.conditionalEffectId) do
            trackedEffects[id] = true
        end
    end

    -- Register new
    for abilityId, _ in pairs(trackedEffects) do
        EVENT_MANAGER:RegisterForEvent(CAE.name .. "ConditionalEffect" .. abilityId, EVENT_EFFECT_CHANGED, OnEffectChanged)
        EVENT_MANAGER:AddFilterForEvent(CAE.name .. "ConditionalEffect" .. abilityId, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    end
end

local function CheckEffects()
    -- For first loads etc
    ZO_ClearTable(effects)
    for i = 1, GetNumBuffs("player") do
        local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        if (trackedEffects[abilityId]) then
            effects[abilityId] = true
        end
    end
end

local function HasEffect(abilityId)
    return effects[abilityId]
end


---------------------------------------------------------------------
-- called
---------------------------------------------------------------------
local function IsAnyIdActive(func, ids, activeBarOnly)
    for _, id in ipairs(ids) do
        if (func(id, activeBarOnly)) then return true end
    end
    return false
end

local function ShouldShapeBeShown(shapeData)
    if (#(shapeData.conditionalAbilityId) > 0
        and not IsAnyIdActive(IsSlotted, shapeData.conditionalAbilityId, shapeData.activeBarOnly)) then
        return false
    end

    if (#(shapeData.conditionalSetId) > 0
        and not IsAnyIdActive(IsEquipped, shapeData.conditionalSetId, shapeData.activeBarOnly)) then
        return false
    end

    if (#(shapeData.conditionalEffectId) > 0
        and not IsAnyIdActive(HasEffect, shapeData.conditionalEffectId, shapeData.activeBarOnly)) then
        return false
    end

    return true
end
CAE.ShouldShapeBeShown = ShouldShapeBeShown


---------------------------------------------------------------------
-- Init
---------------------------------------------------------------------
function CAE.InitializeConditionalChecker()
    -- Check skills
    EVENT_MANAGER:RegisterForEvent(CAE.name .. "Conditional", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, CAE.UpdateShapes)
    EVENT_MANAGER:RegisterForEvent(CAE.name .. "ConditionalWW", EVENT_WEREWOLF_STATE_CHANGED, CAE.UpdateShapes)

    -- Check sets
    EVENT_MANAGER:RegisterForEvent(CAE.name .. "Equipped", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotUpdated)
    EVENT_MANAGER:AddFilterForEvent(CAE.name .. "Equipped", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
    EVENT_MANAGER:AddFilterForEvent(CAE.name .. "Equipped", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
    EVENT_MANAGER:RegisterForEvent(CAE.name .. "ArmoryEquipped", EVENT_ARMORY_BUILD_RESTORE_RESPONSE, CalculateEquippedSets)

    -- Both
    EVENT_MANAGER:RegisterForEvent(CAE.name .. "Barswapped", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, CalculateEquippedSets)

    -- Effects
    InitEffects()
    CAE.RegisterProfileChangedListener("CAEConditionalChecker", function(isSame)
        if (not isSame) then
            InitEffects()
        end
    end)
    EVENT_MANAGER:RegisterForEvent(CAE.name .. "ConditionalPlayerActivated", EVENT_PLAYER_ACTIVATED, CheckEffects)

    CalculateEquippedSets()
end
