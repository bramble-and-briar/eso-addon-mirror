-- SatchelExchangeRadialActions.lua: Puts "Open Containers" on the LibRadialMenu
-- wheel. LibRadialMenu is an optional dependency: without it the same action
-- is the button on the settings page.

local SatchelExchangeRadialActions = {}

local ADDON_ID = "SatchelExchange"
local ENTRY_ID = "opencontainers"
local ENTRY_ICON = "EsoUI/Art/Inventory/inventory_tabIcon_container_up.dds"

function SatchelExchangeRadialActions.Initialize()
    local radialMenu = _G["LibRadialMenu"]
    if type(radialMenu) ~= "table" or not radialMenu.RegisterAddon or not radialMenu.RegisterEntry then
        SatchelExchange.Log("LibRadialMenu not available; no wheel entry (the settings page has the button)")
        return
    end

    radialMenu:RegisterAddon(ADDON_ID, "Satchel Exchange")
    radialMenu:RegisterEntry(ADDON_ID, "Open Containers", ENTRY_ID, ENTRY_ICON,
        function()
            SatchelExchange.UnboxActions.UnboxAll()
        end,
        "Open every container in your backpack, one after another, as fast as the game allows.")
end

SatchelExchange.RadialActions = SatchelExchangeRadialActions
