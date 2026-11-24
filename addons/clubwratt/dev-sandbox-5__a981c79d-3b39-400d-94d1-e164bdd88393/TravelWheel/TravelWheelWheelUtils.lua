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
        if destination.owner then
            return "Travels into this player's house, as House Tours does. Free."
        end
        return "Travels into the house. Free."
    end
    if destination.kind == "campaign" then
        return "Joins the campaign's queue through the game's own queue flow."
    end
    if destination.kind == "unstuck" then
        return "Opens the game's Get Me Unstuck prompt, the one in the Help menu: confirm there. Costs what the prompt says."
    end
    return "Joins the battleground queues ticked for this entry, in one search, as ticking them in the Activity Finder does. Free."
end

TravelWheel.WheelUtils = TravelWheelWheelUtils
