---@diagnostic disable: undefined-field, inject-field -- ESO Control/ZO_* stubs do not describe native UI fields completely
if not SemisPlaygroundCheckAccess() then return end

---@class InventoryPocInspect
local inspect = {}
BattleScrolls.inventoryPocInspect = inspect
local poc = BattleScrolls.inventoryPoc
local UPDATE_NAME = 'BattleScrollsInventoryPocInspect'
local registered = false

-- The native inventory creates its item-action callbacks during deferred
-- initialization. Observe the already-shown scene; never initialize/show it
-- ourselves, wrap its methods, or edit its action/dialog descriptor tables.
local function selectedSlot()
    if not poc.enabled or not IsInGamepadPreferredMode()
        or GAMEPAD_INVENTORY_ROOT_SCENE:GetState() ~= SCENE_SHOWN
        or KEYBIND_STRIP:GetTopKeybindStateIndex() ~= 1 or ZO_Dialogs_IsShowingDialog() then return end
    local inventory = GAMEPAD_INVENTORY
    local list = inventory and inventory.itemList
    if not list or inventory:GetCurrentList() ~= list or not list:IsActive() or inventory:IsHeaderActive() then return end
    local data = list:GetTargetData()
    if data and data.bagId == BAG_BACKPACK and type(data.slotIndex) == 'number'
        and GetItemLink(data.bagId, data.slotIndex, LINK_STYLE_DEFAULT) ~= '' then
        return data.bagId, data.slotIndex
    end
end

-- Plain, addon-owned descriptors. The shared gamepad DialogKeybindStripDescriptor
-- pool creates closures on demand and can retain addon-origin callbacks for
-- later native dialogs. This keybind does not use that pool or open a dialog.
local button = {
    name = GetString(BATTLESCROLLS_IPOC_INSPECT_ITEM),
    keybind = 'UI_SHORTCUT_QUINARY',
    order = 3000,
    disabledDuringSceneHiding = true,
    visible = function() return selectedSlot() ~= nil end,
    callback = function()
        local bag, slot = selectedSlot()
        if bag then poc.inspectItem(bag, slot) end
    end,
}
local group = { alignment = KEYBIND_STRIP_ALIGN_LEFT, button }

local function remove()
    -- State 1 is the inventory's base strip, even while a native dialog has
    -- pushed a temporary state above it. Never remove that dialog's buttons.
    KEYBIND_STRIP:RemoveKeybindButtonGroup(group, 1)
end

local function refresh()
    if not selectedSlot() then remove(); return end
    if KEYBIND_STRIP:HasKeybindButtonGroup(group, 1) then return end
    -- Another addon may already use the otherwise-unused inventory action.
    -- Leave its descriptor alone; the explicit probe remains available.
    if not KEYBIND_STRIP:HasKeybindButton(button, 1) then KEYBIND_STRIP:AddKeybindButtonGroup(group, 1) end
end

local function stop()
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
    remove()
end

local function start()
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
    if not poc.enabled then return end
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, 200, refresh)
    refresh()
end

---@param enabled boolean
function inspect.setEnabled(enabled)
    if not enabled then stop(); return end
    if not registered then
        registered = true
        GAMEPAD_INVENTORY_ROOT_SCENE:RegisterCallback('StateChange', function(_, state)
            if state == SCENE_SHOWN then start()
            elseif state == SCENE_HIDING or state == SCENE_HIDDEN then stop() end
        end)
    end
    if GAMEPAD_INVENTORY_ROOT_SCENE:GetState() == SCENE_SHOWN then start() end
end
