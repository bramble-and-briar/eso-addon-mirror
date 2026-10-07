local appName = "LibTrack"

LibTrack = {}

LibTrack.sets = {
    setList = {}, --format: [setId] = totalPieces
}

local allGearSlots = {
    0,  -- head
    2,  -- chest
    3,  -- shoulders
    6,  -- waist
    16, -- hands
    8,  -- legs
    9,  -- feet
    1,  -- neck
    11, -- ring1
    12, -- ring2
    4,  --front bar 1
    5,  --front bar 2
    20, --back bar 1
    21, --back bar 2
}

local TWO_HANDED_WEAPONS = {
    [WEAPONTYPE_TWO_HANDED_AXE]    = true,
    [WEAPONTYPE_TWO_HANDED_HAMMER] = true,
    [WEAPONTYPE_TWO_HANDED_SWORD]  = true,
    [WEAPONTYPE_BOW]               = true,
    [WEAPONTYPE_FIRE_STAFF]        = true,
    [WEAPONTYPE_FROST_STAFF]       = true,
    [WEAPONTYPE_LIGHTNING_STAFF]   = true,
    [WEAPONTYPE_HEALING_STAFF]     = true,
}


--print message to chat box
local function printMessage(msg)
	local chat = LibChatMessage(appName, "MA")
	chat:Print(msg)
end

function LibTrack.getSet(setId, setCount)

    if (LibTrack.sets.setList[setId] or 0) == setCount then
        return true
    else
        return false
    end
end

local function checkCurrentSets()
    --reset for a clean scan
    LibTrack.sets.setList = {}

    for _, slotIndex in ipairs(allGearSlots) do
        local itemLink = GetItemLink(BAG_WORN, slotIndex)

        if itemLink ~= "" then
            local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(itemLink, false)

            if hasSet and setId then
                local weight = 1

                --account for 2-handed weapons on front or back bar main-hand slot
                if slotIndex == 4 or slotIndex == 20 then
                    local weaponType = GetItemWeaponType(BAG_WORN, slotIndex)
                    if weaponType and TWO_HANDED_WEAPONS[weaponType] then
                        weight = 2
                    end
                end

                --add to total piece count
                LibTrack.sets.setList[setId] = (LibTrack.sets.setList[setId] or 0) + weight
            end
        end
    end
end

local function onEquipmentChanged(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason)
    --bagId
    --BAG_BACKPACK
    --BAG_WORN
    --BAG_BANK
    --BAG_VIRTUAL for the Craft Bag

    --run set check
    checkCurrentSets()
    --2 seconds after sets are checked check for specific set
    
    --updateReason
    --INVENTORY_UPDATE_REASON_DEFAULT
    --INVENTORY_UPDATE_REASON_DURABILITY_CHANGE

    local itemLink = GetItemLink(bagId, slotIndex)
    local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(itemLink, false)

    if hasSet and setId ~= nil then

        printMessage(zo_strformat("setName- <<1>>", setName))
        printMessage(zo_strformat("setId- <<1>>", setId))
        printMessage(zo_strformat("slotIndex- <<1>>", slotIndex))
    end
end


local function enableCallbacksGear()
    EVENT_MANAGER:RegisterForEvent("callback", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, onEquipmentChanged)
    EVENT_MANAGER:AddFilterForEvent("callback", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
end


--add-on loaded
local function libLoaded(event, name)
    --if add-on loaded was not this add-on quit
    if name ~= appName then return end
    --unregister for notifications of add-on loaded
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_ADD_ON_LOADED)
    --register for callbacks when an equiped piece of gear is added or removed
    enableCallbacksGear()
    --check what sets are currently equiped
    checkCurrentSets()

    zo_callLater(function () if LibTrack.getSet(771, 5) then printMessage("PLE is active") end end, 2000)
    zo_callLater(function () if LibTrack.getSet(589, 5) then printMessage("PSC is active") end end, 2200)
    zo_callLater(function () if LibTrack.getSet(564, 2) then printMessage("PVB is active") end end, 2300)
    zo_callLater(function () if LibTrack.getSet(596, 1) then printMessage("DDF is active") end end, 2400)
end


--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, libLoaded)