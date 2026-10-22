---@diagnostic disable: undefined-field, inject-field -- Native HUD controls and scene methods
if not SemisPlaygroundCheckAccess() then return end

---@class InventoryPocHUD
local hud = {}
BattleScrolls.inventoryPocHUD = hud
local poc = BattleScrolls.inventoryPoc
local facts = BattleScrolls.inventoryPocFacts
local EVENT_NAME = 'BattleScrollsInventoryPocHUD'
local LIMIT = 10
local enabled, registered, revision = false, false, 0
---@type Control|nil
local equipmentStatus
---@type TextureControl|nil
local weaponIndicator, armorIndicator
---@type Fiber|nil
local fiber
---@type InventoryPocSpaceSummary|nil
local lastSummary
local ICONS = {
    sell = 'EsoUI/Art/Icons/ServiceTooltipIcons/Gamepad/gp_serviceTooltipIcon_generalgoods.dds',
    bank = 'EsoUI/Art/Icons/ServiceTooltipIcons/Gamepad/gp_serviceTooltipIcon_banker.dds',
    deconstruct = 'EsoUI/Art/Crafting/Gamepad/gp_crafting_menuIcon_deconstruct.dds',
    list = 'EsoUI/Art/Icons/ServiceTooltipIcons/Gamepad/gp_serviceTooltipIcon_guildkiosk.dds',
}
-- Optical spacing after the word, measured at a 48-unit warning height.
local FALLBACK_WORD_SPACING = { deconstruct = 0, bank = 1, sell = 1 }

---@param icon TextureControl
---@param action InventoryPocSpaceAction
---@param size number
local function setActionIcon(icon, action, size)
    icon:SetTexture(ICONS[action])
    icon:SetDimensions(size, size)
    -- Service-tooltip textures include extra padding around their symbols.
    local inset = action == 'deconstruct' and 0 or 0.125
    icon:SetTextureCoords(inset, 1 - inset, inset, 1 - inset)
end

local function render()
    local control = BattleScrollsInventoryPocHUD
    local best = lastSummary and lastSummary.best
    local visible = enabled and GetNumBagFreeSlots(BAG_BACKPACK) < LIMIT and best ~= nil
        and weaponIndicator:IsControlHidden() and armorIndicator:IsControlHidden()
    control:SetHidden(not visible)
    if not visible then return end
    local fallback = best.action == 'list' and lastSummary.assistant
    local size = equipmentStatus:GetHeight()
    local actionSize, smallSize, gap = size * 3 / 4, size * 7 / 12, size / 12
    local warning, badge = control:GetNamedChild('Pack'), control:GetNamedChild('Warning')
    local primary, secondary = control:GetNamedChild('Action'), control:GetNamedChild('Fallback')
    local alternative = control:GetNamedChild('Or')
    warning:SetDimensions(size, size)
    badge:SetDimensions(size * 5 / 12, size * 5 / 12)
    setActionIcon(primary, best.action, actionSize)
    primary:ClearAnchors()
    primary:SetAnchor(LEFT, control, LEFT, 0, 0)
    alternative:SetHidden(not fallback)
    secondary:SetHidden(not fallback)
    local width = actionSize
    if fallback then
        alternative:SetScale(size / 48)
        alternative:ClearAnchors()
        alternative:SetAnchor(LEFT, primary, RIGHT, -gap, 0)
        local textRight = actionSize - gap + alternative:GetTextWidth() * size / 48
        local fallbackGap = FALLBACK_WORD_SPACING[fallback.action] * size / 48
        setActionIcon(secondary, fallback.action, smallSize)
        secondary:ClearAnchors()
        secondary:SetAnchor(LEFT, control, LEFT, textRight + fallbackGap, 0)
        width = textRight + fallbackGap + smallSize
    end
    -- Overlap the bag texture's clear margin to keep the symbols close together.
    control:SetDimensions(width + size - gap, size)
end

local function refresh()
    if not enabled then return end
    revision = revision + 1
    if GetNumBagFreeSlots(BAG_BACKPACK) >= LIMIT then
        if fiber then fiber:Cancel(); fiber = nil end
        lastSummary = nil
        render()
        return
    end
    render()
    if fiber then return end
    fiber = LibEffect.Async(function()
        local version
        repeat
            version = revision
            LibEffect.Sleep(350):Await()
        until version == revision
        repeat
            version = revision
            local _, reserved = facts.wardrobe(true)
            local items = facts.bag(BAG_BACKPACK, reserved)
            local slots = BattleScrolls.inventoryPocMarket.availableListingSlots(facts.guildIds())
            local deposits = BattleScrolls.inventoryPocBuilds.depositIds(reserved, items)
            local summary = BattleScrolls.inventoryPocSpace.summarize(items, slots, deposits)
            if version == revision then lastSummary = summary; render() end
            if version ~= revision then LibEffect.Sleep(350):Await() end
        until version == revision
    end):Ensure(function() fiber = nil; BattleScrolls.gc:RequestGC(2) end):Run()
end

---@param value boolean
function hud.setEnabled(value)
    enabled = value
    if value and not registered then
        registered = true
        local control = BattleScrollsInventoryPocHUD
        equipmentStatus = ZO_HUDEquipmentStatus
        weaponIndicator = equipmentStatus:GetNamedChild('WeaponIndicator')
        armorIndicator = equipmentStatus:GetNamedChild('ArmorIndicator')
        -- Inherit the live warning area's position, scale and scene visibility.
        control:SetParent(equipmentStatus)
        control:ClearAnchors()
        control:SetAnchor(RIGHT, equipmentStatus, RIGHT, 0, 0)
        control:GetNamedChild('Or'):SetText(GetString(BATTLESCROLLS_IPOC_HUD_OR))
        -- Named handlers coexist with ESO's handlers and other add-ons' handlers.
        for _, indicator in ipairs({ weaponIndicator, armorIndicator }) do
            indicator:SetHandler('OnEffectivelyShown', render, EVENT_NAME, CONTROL_HANDLER_ORDER_AFTER)
            indicator:SetHandler('OnEffectivelyHidden', render, EVENT_NAME, CONTROL_HANDLER_ORDER_AFTER)
        end
        equipmentStatus:SetHandler('OnEffectivelyShown', render, EVENT_NAME, CONTROL_HANDLER_ORDER_AFTER)
        equipmentStatus:SetHandler('OnRectChanged', render, EVENT_NAME, CONTROL_HANDLER_ORDER_AFTER)
        local function inventoryChanged(_, bag, _, _, _, reason)
            if bag ~= BAG_BACKPACK and bag ~= BAG_WORN and bag ~= BAG_COMPANION_WORN then return end
            if reason == INVENTORY_UPDATE_REASON_DURABILITY_CHANGE or reason == INVENTORY_UPDATE_REASON_ITEM_CHARGE
                or reason == INVENTORY_UPDATE_REASON_DYE_CHANGE then return end
            refresh()
        end
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, inventoryChanged)
        for _, event in ipairs({ EVENT_INVENTORY_FULL_UPDATE, EVENT_INVENTORY_BAG_CAPACITY_CHANGED,
            EVENT_PLAYER_ACTIVATED, EVENT_COMPANION_ACTIVATED, EVENT_TRADING_HOUSE_STATUS_RECEIVED,
            EVENT_TRADING_HOUSE_RESPONSE_RECEIVED }) do
            EVENT_MANAGER:RegisterForEvent(EVENT_NAME, event, refresh)
        end
        local function onHud(_, state)
            if enabled and state == SCENE_SHOWN then poc.wake(); refresh() end
        end
        HUD_SCENE:RegisterCallback('StateChange', onHud)
        HUD_UI_SCENE:RegisterCallback('StateChange', onHud)
    end
    if value then refresh()
    elseif registered then
        revision = revision + 1
        if fiber then fiber:Cancel(); fiber = nil end
        lastSummary = nil
        render()
    end
end
