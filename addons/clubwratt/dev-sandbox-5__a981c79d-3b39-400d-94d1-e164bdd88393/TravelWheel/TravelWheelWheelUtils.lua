-- TravelWheelWheelUtils.lua: Pure helpers for the wheel entries.

local TravelWheelWheelUtils = {}

---LibRadialMenu lists an addon's entries sorted by id, so the ids are
---zero-padded to keep the order they were added in.
---@param number integer
---@return string
function TravelWheelWheelUtils.EntryId(number)
    return string.format("d%04d", number)
end

---The text LibRadialMenu shows when the entry is assigned to a slot.
---@param destination TravelWheelDestination
---@return string
function TravelWheelWheelUtils.Description(destination)
    if destination.kind == "node" then
        return "Pays the recall fee and arrives at this exact spot."
    end
    if destination.kind == "house" then
        if destination.outside then
            return "Travels to the front door of the house. Free."
        end
        return "Travels into the house; a house you do not own opens as a preview. Free."
    end
    if destination.kind == "campaign" then
        return "Joins the campaign's queue through the game's own queue flow."
    end
    return "Joins the queue through the game's own activity finder."
end

TravelWheel.WheelUtils = TravelWheelWheelUtils
