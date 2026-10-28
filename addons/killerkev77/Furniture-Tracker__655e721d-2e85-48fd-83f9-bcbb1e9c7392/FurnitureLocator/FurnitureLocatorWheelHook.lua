--[[
Furniture Locator - Quickslot Wheel entry (Slot 4)

Mirrors the exact pattern used by House Hotkey (a real, working, console
addon already installed and in daily use) for placing a custom entry on
a game utility wheel -- confirmed directly from its public source
(github.com/saranicole/HouseHotkey, HouseHotkey.lua HH.HookWheel).

Rather than needing LibRadialMenu or any new dependency, this hooks the
game's own UTILITY_WHEEL_GAMEPAD.menu.AddEntry function directly: when
the wheel tries to populate our chosen slot, we substitute our own
entry (name/icon/callback) instead of letting it show whatever would
normally go there. The hook chains through the original function for
every other slot, so it composes safely alongside other addons doing
the same thing (like House Hotkey itself).

Hardcoded to Quickslot Wheel (category 10, confirmed empirically --
HOTBAR_CATEGORY_QUICKSLOT_WHEEL was not a reliable constant to reference
by name), slot 4. No settings UI needed for a single fixed slot.
]]

local ADDON_PACKAGE_NAME = "FurnitureLocator"

-- HOTBAR_CATEGORY_QUICKSLOT_WHEEL turned out not to be reliable to
-- reference by name -- SI_HOTBARCATEGORY10 (which it's paired with in
-- House Hotkey's source) is just a LOCALIZATION STRING ID, unrelated to
-- the actual numeric category value. Using the real value confirmed
-- directly from diagnostic output instead: opening the Quickslot Wheel
-- printed "category=10" for every slot.
local WHEEL_CATEGORY = 10
local WHEEL_SLOT_INDEX = 4 -- corrected: confirmed populated slots are 4, 5, 6, 8

-- Confirmed valid icon path (seen resolving correctly for a real item
-- during /flist testing earlier: "Khajiit End Table").
local WHEEL_ICON = "/esoui/art/icons/housing_kha_fur_table002.dds"

local function HookQuickslotWheel()
    if not IsInGamepadPreferredMode() then
        return -- console/gamepad only
    end

    if UTILITY_WHEEL_GAMEPAD == nil or UTILITY_WHEEL_GAMEPAD.menu == nil then
        d("Furniture Locator: UTILITY_WHEEL_GAMEPAD not found -- wheel entry not installed.")
        return
    end

    local ok, err = pcall(function()
        local originalAddEntry = UTILITY_WHEEL_GAMEPAD.menu.AddEntry
        UTILITY_WHEEL_GAMEPAD.menu.AddEntry = function(menuSelf, name, inactiveIcon, activeIcon, callback, data)
            local category = UTILITY_WHEEL_GAMEPAD:GetHotbarCategory()
            local index = tonumber(data and data.slotNum)

            if category == WHEEL_CATEGORY and index == WHEEL_SLOT_INDEX then
                originalAddEntry(menuSelf, "Furniture Locator", WHEEL_ICON, WHEEL_ICON, function()
                    FurnitureLocatorDialogs.ShowCategoryDialog()
                end, data)
            else
                originalAddEntry(menuSelf, name, inactiveIcon, activeIcon, callback, data)
            end
        end
    end)

    if not ok then
        d("Furniture Locator: wheel hook ERROR: " .. tostring(err))
    end
end

local function OnAddOnLoaded(_, addOnName)
    if addOnName ~= ADDON_PACKAGE_NAME then
        return
    end
    EVENT_MANAGER:UnregisterForEvent("FurnitureLocatorWheelHook", EVENT_ADD_ON_LOADED)
    HookQuickslotWheel()
end

EVENT_MANAGER:RegisterForEvent("FurnitureLocatorWheelHook", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
