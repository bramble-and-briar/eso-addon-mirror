local PRT = PotionResourceTags
local Overlay = PRT.Overlay
PRT.Hooks = { installed = {}, missing = {} }
local Hooks = PRT.Hooks

local function Hook(target, method, callback, description)
    if type(target) ~= "table" or type(target[method]) ~= "function" then
        Hooks.missing[#Hooks.missing + 1] = description
        return
    end
    SecurePostHook(target, method, callback)
    Hooks.installed[#Hooks.installed + 1] = description
end

local function RowIcon(row)
    local button = row:GetNamedChild("Button")
    return button and button:GetNamedChild("Icon")
end

local function UpdateRow(row, data)
    local link
    if data and data.bagId ~= nil and data.slotIndex ~= nil then
        link = GetItemLink(data.bagId, data.slotIndex, LINK_STYLE_DEFAULT)
    end
    Overlay.Update(RowIcon(row), link)
end

local function WheelLink(slotNum, category)
    if category == HOTBAR_CATEGORY_QUICKSLOT_WHEEL
        and GetSlotType(slotNum, category) == ACTION_TYPE_ITEM then
        return GetSlotItemLink(slotNum, category)
    end
    return nil
end

local function UpdateHUD(button)
    if button and button == ZO_ActionBar_GetButton(nil, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) then
        Overlay.Update(button.icon,
            WheelLink(GetCurrentQuickslot(), HOTBAR_CATEGORY_QUICKSLOT_WHEEL),
            IsInGamepadPreferredMode())
    end
end

function Hooks.Initialize()
    if GetAPIVersion() ~= PRT.SOURCE_API_VERSION then
        Hooks.missing[1] = "UI hooks disabled: API differs from inspected 101051"
        return
    end

    -- Read the registered data type from each inventory, never hardcode type 1.
    -- Its setup callback runs after the bag/slot has been bound to the row.
    local types = { INVENTORY_BACKPACK, INVENTORY_BANK, INVENTORY_HOUSE_BANK, INVENTORY_GUILD_BANK }
    for _, inventoryType in ipairs(types) do
        local inventory = PLAYER_INVENTORY and PLAYER_INVENTORY.inventories[inventoryType]
        local dataType = inventory and inventory.listView
            and ZO_ScrollList_GetDataTypeTable(inventory.listView, inventory.listDataType)
        Hook(dataType, "setupCallback", UpdateRow, "inventory " .. tostring(inventoryType))
    end

    -- These deferred list callbacks resolve the method on each call.
    Hook(ZO_Quickslot_Keyboard, "SetUpQuickSlot", function(_, row, data)
        UpdateRow(row, data)
    end, "quickslot list")
    Hook(ZO_Quickslot_Keyboard, "SetUpQuestItemSlot", function(_, row)
        Overlay.Clear(RowIcon(row))
    end, "quickslot quest row clear")
    Hook(ZO_Quickslot_Keyboard, "SetUpCollectionSlot", function(_, row)
        Overlay.Clear(RowIcon(row))
    end, "quickslot collection row clear")

    Hook(ZO_AssignableUtilityWheel_Keyboard, "DoSlotUpdate", function(wheel, physicalSlot)
        local slot = wheel.slots[physicalSlot]
        if slot then
            Overlay.Update(slot.icon, WheelLink(physicalSlot, wheel:GetHotbarCategory()))
        end
    end, "assignment wheel")
    Hook(ZO_UtilityWheel_Keyboard, "SetupEntryControl", function(wheel, control, data)
        Overlay.Update(control.icon, WheelLink(data.slotNum, wheel:GetHotbarCategory()))
    end, "selection wheel")

    -- HandleSlotChanged is inherited; hook its actual owner and filter identity.
    Hook(ActionButton, "HandleSlotChanged", UpdateHUD, "HUD slot change")
    Hook(QuickslotActionButton, "ApplyStyle", UpdateHUD, "HUD platform style")
    Hook(ActionButton, "Clear", function(button)
        if button == ZO_ActionBar_GetButton(nil, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) then
            Overlay.Clear(button.icon)
        end
    end, "HUD empty clear")
end

function Hooks.RefreshHUD()
    if GetAPIVersion() == PRT.SOURCE_API_VERSION then
        UpdateHUD(ZO_ActionBar_GetButton(nil, HOTBAR_CATEGORY_QUICKSLOT_WHEEL))
    end
end
