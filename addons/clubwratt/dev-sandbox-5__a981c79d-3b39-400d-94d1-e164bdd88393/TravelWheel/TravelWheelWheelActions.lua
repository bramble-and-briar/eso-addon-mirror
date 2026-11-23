-- TravelWheelWheelActions.lua: Puts each saved destination on the
-- LibRadialMenu list of entries. The player assigns entries to wheel slots in
-- LibRadialMenu's own settings; a slot keeps the entry's id.

local TravelWheelWheelActions = {}

local Utils = TravelWheel.WheelUtils

local ADDON_ID = "travelwheel"

---@return table|nil
local function RadialMenu()
    local radialMenu = _G["LibRadialMenu"]
    if type(radialMenu) == "table" and radialMenu.RegisterAddon and radialMenu.RegisterEntry then
        return radialMenu
    end
    return nil
end

---@param destination TravelWheelDestination
function TravelWheelWheelActions.Add(destination)
    local radialMenu = RadialMenu()
    if not radialMenu then
        return
    end
    local id = destination.id
    radialMenu:RegisterEntry(ADDON_ID, destination.name, id, destination.icon, function()
        TravelWheel.TravelActions.Go(id)
    end, Utils.Description(destination))
end

---LibRadialMenu has no call to take an entry back; its table of entries is
---the one it reads when a wheel opens, and a slot whose entry is gone shows empty.
---@param id string
function TravelWheelWheelActions.Remove(id)
    local radialMenu = RadialMenu()
    local entries = radialMenu and radialMenu.registeredEntries and radialMenu.registeredEntries[ADDON_ID]
    if entries then
        entries[id] = nil
    end
end

function TravelWheelWheelActions.Initialize()
    local radialMenu = RadialMenu()
    if not radialMenu then
        TravelWheel.Log("LibRadialMenu not available; no wheel entries (the settings page still travels)")
        return
    end
    radialMenu:RegisterAddon(ADDON_ID, TravelWheel.title)
    for _, destination in ipairs(TravelWheel.state.savedVars.destinations) do
        TravelWheelWheelActions.Add(destination)
    end
end

TravelWheel.WheelActions = TravelWheelWheelActions
