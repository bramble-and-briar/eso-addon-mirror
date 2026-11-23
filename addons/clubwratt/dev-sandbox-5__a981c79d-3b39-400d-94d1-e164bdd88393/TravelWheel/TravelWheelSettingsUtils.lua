-- TravelWheelSettingsUtils.lua: Pure helpers for the settings page: what
-- makes two destinations the same, and the names they are saved under.

local TravelWheelSettingsUtils = {}

TravelWheelSettingsUtils.ICON_WAYSHRINE = "/esoui/art/icons/poi/poi_wayshrine_complete.dds"
TravelWheelSettingsUtils.ICON_HOUSE = "/esoui/art/icons/poi/poi_group_house_owned.dds"
TravelWheelSettingsUtils.ICON_CYRODIIL = "EsoUI/Art/LFG/Gamepad/LFG_activityIcon_cyrodiil.dds"
TravelWheelSettingsUtils.ICON_IMPERIAL_CITY = "EsoUI/Art/LFG/Gamepad/LFG_activityIcon_imperialCity.dds"
TravelWheelSettingsUtils.ICON_BATTLEGROUND = "EsoUI/Art/LFG/Gamepad/LFG_menuIcon_battlegrounds.dds"

---Two destinations with one key go to the same place: saving the second
---updates the first.
---@param destination TravelWheelDestination
---@return string
function TravelWheelSettingsUtils.Key(destination)
    if destination.kind == "node" then
        return "node:" .. destination.nodeIndex
    end
    if destination.kind == "house" then
        return string.format("house:%d:%s", destination.houseId, destination.outside and "outside" or "inside")
    end
    if destination.kind == "campaign" then
        return "campaign:" .. destination.campaignId
    end
    return string.format("activity:%d:%s:%d", destination.activityType, destination.isSet and "set" or "one", destination.activityId)
end

---@param node TravelWheelNode
---@return TravelWheelDestination destination Without an id
function TravelWheelSettingsUtils.NodeDestination(node)
    return {
        kind = "node",
        name = node.name,
        icon = (node.icon and node.icon ~= "") and node.icon or TravelWheelSettingsUtils.ICON_WAYSHRINE,
        nodeIndex = node.nodeIndex,
    }
end

---@param house TravelWheelHouse|nil nil is the primary residence
---@param outside boolean
---@return TravelWheelDestination destination Without an id
function TravelWheelSettingsUtils.HouseDestination(house, outside)
    local name = house and house.name or "Primary Residence"
    -- Only an owned house has a front door to arrive at.
    local atDoor = outside and (house == nil or house.owned)
    return {
        kind = "house",
        name = atDoor and (name .. " (outside)") or name,
        icon = (house and house.icon and house.icon ~= "") and house.icon or TravelWheelSettingsUtils.ICON_HOUSE,
        houseId = house and house.houseId or 0,
        outside = atDoor,
    }
end

---@param campaign TravelWheelCampaign|nil nil is the home campaign
---@return TravelWheelDestination destination Without an id
function TravelWheelSettingsUtils.CampaignDestination(campaign)
    return {
        kind = "campaign",
        name = "Queue: " .. (campaign and campaign.name or "Home Campaign"),
        icon = (campaign and campaign.imperialCity) and TravelWheelSettingsUtils.ICON_IMPERIAL_CITY
            or TravelWheelSettingsUtils.ICON_CYRODIIL,
        campaignId = campaign and campaign.campaignId or 0,
    }
end

---@param activity TravelWheelActivity
---@return TravelWheelDestination destination Without an id
function TravelWheelSettingsUtils.ActivityDestination(activity)
    return {
        kind = "activity",
        name = "Queue: " .. activity.name,
        icon = TravelWheelSettingsUtils.ICON_BATTLEGROUND,
        activityType = activity.activityType,
        activityId = activity.activityId,
        isSet = activity.isSet,
    }
end

---@param destinations TravelWheelDestination[]
---@param key string
---@return TravelWheelDestination|nil destination
---@return integer|nil index
function TravelWheelSettingsUtils.FindByKey(destinations, key)
    for index, destination in ipairs(destinations) do
        if TravelWheelSettingsUtils.Key(destination) == key then
            return destination, index
        end
    end
    return nil, nil
end

TravelWheel.SettingsUtils = TravelWheelSettingsUtils
