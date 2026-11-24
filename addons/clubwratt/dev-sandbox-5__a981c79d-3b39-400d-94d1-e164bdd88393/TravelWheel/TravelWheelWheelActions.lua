-- TravelWheelWheelActions.lua: Puts each saved destination on the
-- LibRadialMenu list of entries. The player assigns entries to wheel slots in
-- LibRadialMenu's own settings; a slot keeps the entry's id.

local TravelWheelWheelActions = {}

local Utils = TravelWheel.WheelUtils

-- LibRadialMenu lists the addons in the order of their ids (table.sort, by
-- byte) and shows each by its title. The space puts this one first: it sorts
-- before every digit and letter, where an underscore would sort after the
-- ids that start with a capital. The id is never shown.
local ADDON_ID = " travelwheel"
-- The id before 0.14.0. The library saves a wheel slot as the addon's id and
-- the entry's id, so slots assigned before then still hold this one.
local OLD_ADDON_ID = "travelwheel"

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

---Slots assigned under the old id keep their entry: each is moved to the id
---the entries are registered under now. The slots are the library's saved
---table, read when a wheel opens, so the change is kept.
---@param radialMenu table
---@return integer moved
local function MoveSlots(radialMenu)
    local moved = 0
    for _, slot in pairs(radialMenu.libRadialWheelEntries or {}) do
        if type(slot) == "table" and slot.addon == OLD_ADDON_ID then
            slot.addon = ADDON_ID
            moved = moved + 1
        end
    end
    return moved
end

function TravelWheelWheelActions.Initialize()
    local radialMenu = RadialMenu()
    if not radialMenu then
        TravelWheel.Log("LibRadialMenu not available; no wheel entries (the settings page still travels)")
        return
    end
    radialMenu:RegisterAddon(ADDON_ID, TravelWheel.title)
    local moved = MoveSlots(radialMenu)
    if moved > 0 then
        TravelWheel.Log(string.format("wheel slots from before 0.14.0: %d moved to the new id", moved))
    end
    for _, destination in ipairs(TravelWheel.state.savedVars.destinations) do
        TravelWheelWheelActions.Add(destination)
    end
end

TravelWheel.WheelActions = TravelWheelWheelActions
