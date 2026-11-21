KyzderpsDerps = KyzderpsDerps or {}
KyzderpsDerps.AntiSpud = KyzderpsDerps.AntiSpud or {}
local Spud = KyzderpsDerps.AntiSpud

---------------------------------------------------------------------
local spaulderActive = false

---------------------------------------------------------------------
-- If wearing Spaulder of Ruin, show message if it's not toggled on
local function UpdateSpaulderDisplay()
    Spud.Display(nil, Spud.SPAULDER)

    if (not KyzderpsDerps.savedOptions.antispud.equipped.spaulder) then
        return
    end

    local itemLink = GetItemLink(BAG_WORN, EQUIP_SLOT_SHOULDERS)
    if (itemLink == "") then return end
    local _, setName = GetItemLinkSetInfo(itemLink, true)
    if (setName ~= "Spaulder of Ruin") then return end

    if (not spaulderActive) then
        Spud.Display("Spudler is OFF", Spud.SPAULDER)
    else
        Spud.Display(nil, Spud.SPAULDER)
    end
end
Spud.UpdateSpaulderDisplay = UpdateSpaulderDisplay

---------------------------------------------------------------------
-- EVENT_COMBAT_EVENT (number eventCode, number ActionResult result, boolean isError, string abilityName, number abilityGraphic, number ActionSlotType abilityActionSlotType, string sourceName, number CombatUnitType sourceType, string targetName, number CombatUnitType targetType, number hitValue, number CombatMechanicType powerType, number DamageType damageType, boolean log, number sourceUnitId, number targetUnitId, number abilityId, number overflow)
local function OnSpaulderChanged(_, result)
    if (result == ACTION_RESULT_EFFECT_GAINED) then
        spaulderActive = true
        UpdateSpaulderDisplay()
    elseif (result == ACTION_RESULT_EFFECT_FADED) then
        spaulderActive = false
        UpdateSpaulderDisplay()
    end
end

---------------------------------------------------------------------
-- Spaulder turns off upon rezoning
local lastZoneId = 0
local function OnPlayerActivated()
    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
    if (zoneId ~= lastZoneId) then
        spaulderActive = false
        UpdateSpaulderDisplay()
    end
    lastZoneId = zoneId
end

---------------------------------------------------------------------
-- EVENT_INVENTORY_SINGLE_SLOT_UPDATE (number eventCode, Bag bagId, number slotId, boolean isNewItem, ItemUISoundCategory itemSoundCategory, number inventoryUpdateReason, number stackCountChange)
local function OnSlotUpdated(_, bagId, slotId)
    -- Ignore costume updates, poison updates
    if (slotId == EQUIP_SLOT_SHOULDERS) then
        UpdateSpaulderDisplay()
    end
end

---------------------------------------------------------------------
function Spud.InitializeSpaulder()
    KyzderpsDerps:dbg("    Initializing AntiSpud Spaulder...")

    EVENT_MANAGER:RegisterForEvent(KyzderpsDerps.name .. "SpaulderEquipped", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotUpdated)

    EVENT_MANAGER:RegisterForEvent(KyzderpsDerps.name .. "SpaulderActivation", EVENT_COMBAT_EVENT, OnSpaulderChanged)
    EVENT_MANAGER:AddFilterForEvent(KyzderpsDerps.name .. "SpaulderActivation", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 163359)
    EVENT_MANAGER:AddFilterForEvent(KyzderpsDerps.name .. "SpaulderActivation", EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    EVENT_MANAGER:RegisterForEvent(KyzderpsDerps.name .. "SpaulderRezone", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    OnPlayerActivated()

    -- Disable spaulder upon LFG joined, because sometimes we can queue from the same dungeon into a new instance
    EVENT_MANAGER:RegisterForEvent(KyzderpsDerps.name .. "SpaulderLFGJoined", EVENT_GROUPING_TOOLS_LFG_JOINED, function()
        spaulderActive = false
        UpdateSpaulderDisplay()
    end)
end
