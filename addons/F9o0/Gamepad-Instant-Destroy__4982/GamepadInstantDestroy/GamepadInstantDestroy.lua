local ADDON_NAME = "GamepadInstantDestroy"

-- Only the game's own (vanilla) gamepad destroy dialogs.
-- Dialogs from other addons are never touched.
local DESTROY_DIALOGS =
{
    "GAMEPAD_CONFIRM_DESTROY_ITEM_PROMPT",          -- normal items
    "GAMEPAD_CONFIRM_DESTROY_ARMORY_ITEM_PROMPT",   -- items saved in an Armory build
}

-- Removes the button wait timer (onShowCooldown) from those dialogs.
local function RemoveDelay()
    for _, dialogName in ipairs(DESTROY_DIALOGS) do
        local dialog = ESO_Dialogs[dialogName]
        if dialog and dialog.buttons then
            for _, button in ipairs(dialog.buttons) do
                button.onShowCooldown = nil
            end
        end
    end
end

local function OnAddOnLoaded(_, addOnName)
    if addOnName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    RemoveDelay()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
