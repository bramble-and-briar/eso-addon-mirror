-- SatchelExchangeBagUtils.lua: Pure helpers for backpack and item-use
-- readiness inspection.

local SatchelExchangeBagUtils = {}

---Find the first backpack slot holding the given item id
---@param itemId integer
---@return integer|nil slotIndex
function SatchelExchangeBagUtils.FindItemInBackpack(itemId)
    for slotIndex in ZO_IterateBagSlots(BAG_BACKPACK) do
        if GetItemId(BAG_BACKPACK, slotIndex) == itemId then
            return slotIndex
        end
    end
    return nil
end

---What kind of openable container a backpack slot holds, or nil. Style pages
---are containers to the game but using one learns the style, so they are
---never openable here.
---@param slotIndex integer
---@return string|nil kind "container" | "stackable" | "geode"
function SatchelExchangeBagUtils.GetContainerKind(slotIndex)
    local itemType, specializedItemType = GetItemType(BAG_BACKPACK, slotIndex)
    if specializedItemType == SPECIALIZED_ITEMTYPE_CONTAINER_STYLE_PAGE then
        return nil
    end
    if itemType == ITEMTYPE_CONTAINER then
        return "container"
    elseif itemType == ITEMTYPE_CONTAINER_STACKABLE then
        return "stackable"
    elseif itemType == ITEMTYPE_CONTAINER_CURRENCY then
        return "geode"
    end
    return nil
end

---Identity of what a backpack slot holds right now: the item instance and how
---many of it. An empty slot reads as "" and 0.
---@param slotIndex integer
---@return string uniqueId
---@return integer stack
function SatchelExchangeBagUtils.GetSlotSignature(slotIndex)
    local uniqueId = GetItemUniqueId(BAG_BACKPACK, slotIndex)
    local stack = GetSlotStackSize(BAG_BACKPACK, slotIndex)
    return uniqueId and Id64ToString(uniqueId) or "", stack
end

---Whether the player is back on the plain HUD. The game silently drops
---UseItem requests sent while any other scene (store, loot, a menu) is still
---up or fading out -- the reference autoloot addon gates on exactly this.
---@return boolean
function SatchelExchangeBagUtils.IsHudSceneShowing()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetCurrentScene()
    local sceneName = scene and scene:GetName()
    return sceneName == "hud" or sceneName == "hudui"
end

---Snapshot everything that gates using (unboxing) a backpack item right now.
---Fills and returns `into` when given, so a polling caller allocates nothing.
---@param slotIndex integer
---@param into SatchelExchangeUseReadiness|nil
---@return SatchelExchangeUseReadiness
function SatchelExchangeBagUtils.GetUseReadiness(slotIndex, into)
    local readiness = into or {}
    readiness.usable, readiness.usableOnlyFromActionSlot = IsItemUsable(BAG_BACKPACK, slotIndex)
    readiness.canInteract = CanInteractWithItem(BAG_BACKPACK, slotIndex)
    readiness.cooldownRemainMs = GetItemCooldownInfo(BAG_BACKPACK, slotIndex)
    readiness.hudScene = SatchelExchangeBagUtils.IsHudSceneShowing()
    readiness.interactionType = GetInteractionType()
    readiness.inCombat = IsUnitInCombat("player")
    readiness.dead = IsUnitDead("player")
    readiness.swimming = IsUnitSwimming("player")
    readiness.looting = IsLooting()
    return readiness
end

---Every gate that is about what the player is doing rather than about the
---particular item.
---@param readiness SatchelExchangeUseReadiness
---@return boolean
local function IsPlayerStateReady(readiness)
    return readiness.hudScene
        and readiness.interactionType == INTERACTION_NONE
        and not readiness.inCombat
        and not readiness.dead
        and not readiness.swimming
        and not readiness.looting
end

---The item's own gates, the cooldown aside. CanInteractWithItem is false for
---every item during an interaction, so it only says something about the item
---once the player's state is ready (see IsBlockedByItem).
---@param readiness SatchelExchangeUseReadiness
---@return boolean
local function IsItemReady(readiness)
    return readiness.usable
        and not readiness.usableOnlyFromActionSlot
        and readiness.canInteract
end

---@param readiness SatchelExchangeUseReadiness
---@return boolean
function SatchelExchangeBagUtils.IsReadyToUse(readiness)
    return IsItemReady(readiness)
        and IsPlayerStateReady(readiness)
        and readiness.cooldownRemainMs == 0
end

---Only the item cooldown stands in the way: the one gate whose end is known.
---@param readiness SatchelExchangeUseReadiness
---@return boolean
function SatchelExchangeBagUtils.IsBlockedByCooldownOnly(readiness)
    return readiness.cooldownRemainMs > 0
        and IsItemReady(readiness)
        and IsPlayerStateReady(readiness)
end

---The item itself refuses use while the player could use items.
---@param readiness SatchelExchangeUseReadiness
---@return boolean
function SatchelExchangeBagUtils.IsBlockedByItem(readiness)
    return not IsItemReady(readiness)
        and IsPlayerStateReady(readiness)
        and readiness.cooldownRemainMs == 0
end

---A number that changes exactly when the set of blocking gates does (the
---cooldown counts as on or off, not by how much is left).
---@param readiness SatchelExchangeUseReadiness
---@return integer
function SatchelExchangeBagUtils.GetBlockKey(readiness)
    return (readiness.usable and 0 or 1)
        + (readiness.usableOnlyFromActionSlot and 2 or 0)
        + (readiness.canInteract and 0 or 4)
        + (readiness.cooldownRemainMs > 0 and 8 or 0)
        + (readiness.hudScene and 0 or 16)
        + (readiness.inCombat and 32 or 0)
        + (readiness.dead and 64 or 0)
        + (readiness.looting and 128 or 0)
        + (readiness.swimming and 256 or 0)
        + readiness.interactionType * 512
end

---@param readiness SatchelExchangeUseReadiness
---@return string
function SatchelExchangeBagUtils.FormatUseReadiness(readiness)
    return string.format("usable=%s onlyFromActionSlot=%s canInteract=%s cooldownMs=%d hudScene=%s interaction=%d inCombat=%s dead=%s swimming=%s looting=%s",
        tostring(readiness.usable),
        tostring(readiness.usableOnlyFromActionSlot),
        tostring(readiness.canInteract),
        readiness.cooldownRemainMs,
        tostring(readiness.hudScene),
        readiness.interactionType,
        tostring(readiness.inCombat),
        tostring(readiness.dead),
        tostring(readiness.swimming),
        tostring(readiness.looting))
end

SatchelExchange.BagUtils = SatchelExchangeBagUtils
