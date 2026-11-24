-- TravelWheelSettingsUtils.lua: Pure helpers for the settings page: what
-- makes two destinations the same, and the names they are saved under.

local TravelWheelSettingsUtils = {}

local TravelUtils = TravelWheel.TravelUtils

TravelWheelSettingsUtils.ICON_WAYSHRINE = "/esoui/art/icons/poi/poi_wayshrine_complete.dds"
TravelWheelSettingsUtils.ICON_HOUSE = "/esoui/art/icons/poi/poi_group_house_owned.dds"
TravelWheelSettingsUtils.ICON_CYRODIIL = "EsoUI/Art/LFG/Gamepad/LFG_activityIcon_cyrodiil.dds"
TravelWheelSettingsUtils.ICON_IMPERIAL_CITY = "EsoUI/Art/LFG/Gamepad/LFG_activityIcon_imperialCity.dds"
TravelWheelSettingsUtils.ICON_BATTLEGROUND = "EsoUI/Art/LFG/Gamepad/LFG_menuIcon_battlegrounds.dds"
-- The Help menu's own icon for Get Me Unstuck.
TravelWheelSettingsUtils.ICON_UNSTUCK = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_unstuck.dds"

---Two destinations with one key go to the same place: saving the second
---updates the first.
---@param destination TravelWheelDestination
---@return string
function TravelWheelSettingsUtils.Key(destination)
    if destination.kind == "node" then
        return "node:" .. destination.nodeIndex
    end
    if destination.kind == "house" then
        local key = string.format("house:%d:%s", destination.houseId, destination.outside and "outside" or "inside")
        -- Another player's house is its own destination, apart from the player's own house of that kind.
        return destination.owner and (key .. ":" .. destination.owner) or key
    end
    if destination.kind == "campaign" then
        return "campaign:" .. destination.campaignId
    end
    if destination.kind == "unstuck" then
        return "unstuck"
    end
    -- A battleground entry is told from another by the queues it leaves out.
    local left = {}
    for setId, ticked in pairs(destination.queues or {}) do
        if ticked == false then
            left[#left + 1] = setId
        end
    end
    table.sort(left)
    return "activity:" .. table.concat(left, ",")
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
    -- Only a house the player owns has a front door to arrive at: another
    -- player's house is entered inside.
    local atDoor = outside and (house == nil or house.owner == nil)
    return {
        kind = "house",
        name = atDoor and (name .. " (outside)") or name,
        icon = (house and house.icon and house.icon ~= "") and house.icon or TravelWheelSettingsUtils.ICON_HOUSE,
        houseId = house and house.houseId or 0,
        owner = house and house.owner or nil,
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

TravelWheelSettingsUtils.BATTLEGROUNDS_NAME = "Queue: Battlegrounds"

---The name a battleground entry starts with: the queues it joins, or
---Battlegrounds when it joins every queue the finder offers.
---@param offered TravelWheelQueue[] The queues the finder offers this character
---@param ticks table<integer, boolean> By set id: false for a queue left out
---@return string
function TravelWheelSettingsUtils.ActivityName(offered, ticks)
    local ticked = TravelUtils.TickedQueues(offered, ticks)
    if #ticked == 0 or #ticked == #offered then
        return TravelWheelSettingsUtils.BATTLEGROUNDS_NAME
    end
    return "Queue: " .. TravelUtils.QueueNames(ticked)
end

---A battleground entry: it joins the queues ticked for it.
---@param offered TravelWheelQueue[] The queues the finder offers this character
---@param ticks table<integer, boolean> By set id: false for a queue left out
---@return TravelWheelDestination destination Without an id
function TravelWheelSettingsUtils.ActivityDestination(offered, ticks)
    local queues = {}
    for setId, ticked in pairs(ticks) do
        if ticked == false then
            queues[setId] = false
        end
    end
    return {
        kind = "activity",
        name = TravelWheelSettingsUtils.ActivityName(offered, ticks),
        icon = TravelWheelSettingsUtils.ICON_BATTLEGROUND,
        queues = queues,
    }
end

---Bring battleground entries saved by earlier versions to their present
---shape. Before 0.11.0 each named one finder entry, a single arena among
---them, which the game does not queue for: they become one battleground
---entry, the first keeping its id, so the wheel slot it sits in keeps
---working, and the rest are dropped. In 0.11.x the ticks were one set for
---the whole addon: each entry takes that set as its own.
---@param destinations TravelWheelDestination[] Changed in place
---@param sharedTicks table<integer, boolean>|nil The ticks 0.11.x kept for the whole addon
---@return integer dropped
function TravelWheelSettingsUtils.MigrateBattlegroundEntries(destinations, sharedTicks)
    local kept, dropped = false, 0
    local index = 1
    while index <= #destinations do
        local destination = destinations[index]
        local old = destination.kind == "activity" and destination.activityId ~= nil
        if old and kept then
            table.remove(destinations, index)
            dropped = dropped + 1
        else
            if old then
                kept = true
                if destination.name == destination.defaultName then
                    destination.name = TravelWheelSettingsUtils.BATTLEGROUNDS_NAME
                end
                destination.defaultName = TravelWheelSettingsUtils.BATTLEGROUNDS_NAME
                destination.activityType, destination.activityId, destination.isSet = nil, nil, nil
            end
            if destination.kind == "activity" and not destination.queues then
                destination.queues = {}
                for setId, ticked in pairs(sharedTicks or {}) do
                    if ticked == false then
                        destination.queues[setId] = false
                    end
                end
            end
            index = index + 1
        end
    end
    return dropped
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

---@return TravelWheelDestination destination Without an id
function TravelWheelSettingsUtils.UnstuckDestination()
    return {
        kind = "unstuck",
        name = "Get Me Unstuck",
        icon = TravelWheelSettingsUtils.ICON_UNSTUCK,
    }
end

---What tells one house from another, as lines for the info panel.
---@param house TravelWheelHouse|nil nil is the primary residence
---@return string[] lines
function TravelWheelSettingsUtils.HouseDetail(house)
    if not house then
        return { "Whichever house is your primary residence at the time you travel." }
    end
    local lines = {}
    if house.owner then
        lines[#lines + 1] = "Owner: " .. (house.ownerName or house.owner)
        if house.nickname and house.nickname ~= "" then
            lines[#lines + 1] = "Name: " .. house.nickname
        end
        if house.tags and house.tags ~= "" then
            lines[#lines + 1] = "Tags: " .. house.tags
        end
        if house.furnitureCount then
            lines[#lines + 1] = "Furnishings: " .. house.furnitureCount
        end
    end
    return lines
end

---The info panel's text for one thing in a list: what it is, what tells it
---apart, what picking it does.
---@param title string
---@param detail string[]|nil
---@param action string
---@return string
function TravelWheelSettingsUtils.Describe(title, detail, action)
    local lines = { title }
    for _, line in ipairs(detail or {}) do
        lines[#lines + 1] = line
    end
    lines[#lines + 1] = action
    return table.concat(lines, "\n")
end

-- Icons a wheel entry can take instead of its own: every path is one the
-- game's own interface uses.
TravelWheelSettingsUtils.ICONS = {
    -- places
    "/esoui/art/icons/poi/poi_wayshrine_complete.dds",
    "/esoui/art/icons/poi/poi_group_house_owned.dds",
    "/esoui/art/icons/poi/poi_group_house_unowned.dds",
    "/esoui/art/icons/poi/poi_crafting_complete.dds",
    "/esoui/art/icons/mapkey/mapkey_housing.dds",
    "/esoui/art/icons/mapkey/mapkey_dungeon.dds",
    "/esoui/art/icons/mapkey/mapkey_raiddungeon.dds",
    "/esoui/art/icons/mapkey/mapkey_delve.dds",
    "/esoui/art/icons/mapkey/mapkey_groupdelve.dds",
    "/esoui/art/icons/mapkey/mapkey_grouparea.dds",
    "/esoui/art/icons/mapkey/mapkey_groupinstance.dds",
    "/esoui/art/icons/mapkey/mapkey_soloinstance.dds",
    "/esoui/art/icons/mapkey/mapkey_endlessdungeon.dds",
    "/esoui/art/icons/mapkey/mapkey_adventurezone.dds",
    "/esoui/art/icons/mapkey/mapkey_mundus.dds",
    "/esoui/art/icons/mapkey/mapkey_zonestory.dds",
    "/esoui/art/icons/mapkey/mapkey_player.dds",
    "/esoui/art/icons/mapkey/mapkey_groupmember.dds",
    -- the activity finder
    "/esoui/art/lfg/gamepad/lfg_activityicon_cyrodiil.dds",
    "/esoui/art/lfg/gamepad/lfg_activityicon_imperialcity.dds",
    "/esoui/art/lfg/gamepad/lfg_menuicon_battlegrounds.dds",
    "/esoui/art/lfg/gamepad/lfg_menuicon_housetours.dds",
    "/esoui/art/lfg/gamepad/lfg_menuicon_zonestories.dds",
    "/esoui/art/lfg/gamepad/lfg_menuicon_groupfinder.dds",
    "/esoui/art/lfg/gamepad/gp_lfg_menuicon_dungeon.dds",
    "/esoui/art/lfg/gamepad/gp_lfg_menuicon_normaldungeon.dds",
    "/esoui/art/lfg/gamepad/gp_lfg_menuicon_veterandungeon.dds",
    "/esoui/art/lfg/gamepad/gp_lfg_menuicon_random.dds",
    -- the alliance war
    "/esoui/art/campaign/gamepad/gp_campaign_menuicon_travel.dds",
    "/esoui/art/campaign/gamepad/gp_campaign_menuicon_enter.dds",
    "/esoui/art/campaign/gamepad/gp_campaign_menuicon_leave.dds",
    "/esoui/art/campaign/gamepad/gp_overview_menuicon_home.dds",
    "/esoui/art/campaign/gamepad/gp_overview_menuicon_emperor.dds",
    "/esoui/art/campaign/gamepad/gp_overview_keepicon.dds",
    "/esoui/art/campaign/gamepad/gp_overview_outposticon.dds",
    "/esoui/art/campaign/gamepad/gp_overview_resourceicon.dds",
    "/esoui/art/campaign/gamepad/gp_overview_scrollicon.dds",
    "/esoui/art/campaign/gamepad/gp_overview_allianceicon_aldmeri.dds",
    "/esoui/art/campaign/gamepad/gp_overview_allianceicon_daggerfall.dds",
    "/esoui/art/campaign/gamepad/gp_overview_allianceicon_ebonheart.dds",
    -- the player menu
    "/esoui/art/menubar/gamepad/gp_playermenu_icon_unstuck.dds",
    "/esoui/art/menubar/gamepad/gp_playermenu_icon_alliancewar.dds",
    "/esoui/art/menubar/gamepad/gp_playermenu_icon_activityfinder.dds",
    "/esoui/art/menubar/gamepad/gp_playermenu_icon_collections.dds",
    "/esoui/art/menubar/gamepad/gp_playermenu_icon_guilds.dds",
    "/esoui/art/menubar/gamepad/gp_playermenu_icon_groups.dds",
    "/esoui/art/menubar/gamepad/gp_playermenu_icon_inventory.dds",
    "/esoui/art/menubar/gamepad/gp_playermenu_icon_store.dds",
    "/esoui/art/menubar/gamepad/gp_playermenu_icon_mail.dds",
    "/esoui/art/menubar/gamepad/gp_playermenu_icon_quests.dds",
    "/esoui/art/menubar/gamepad/gp_playermenu_icon_character.dds",
    "/esoui/art/menubar/gamepad/gp_playermenu_icon_skills.dds",
    "/esoui/art/menubar/gamepad/gp_playermenu_icon_champion.dds",
    "/esoui/art/menubar/gamepad/gp_playermenu_icon_settings.dds",
    "/esoui/art/menubar/gamepad/gp_playermenu_icon_logout.dds",
    -- crafting and trade
    "/esoui/art/crafting/alchemy_tabicon_reagent_up.dds",
    "/esoui/art/crafting/enchantment_tabicon_potency_up.dds",
    "/esoui/art/crafting/smithing_tabicon_armorset_up.dds",
    "/esoui/art/crafting/smithing_tabicon_weaponset_up.dds",
    "/esoui/art/crafting/provisioner_indexicon_fish_up.dds",
    "/esoui/art/crafting/provisioner_indexicon_furnishings_up.dds",
    "/esoui/art/crafting/gamepad/gp_jewelry_tabicon_icon.dds",
    "/esoui/art/crafting/gamepad/gp_reconstruct_tabicon.dds",
    "/esoui/art/crafting/retrait_tabicon_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_sell_tabicon_up.dds",
    "/esoui/art/vendor/vendor_tabicon_fence_up.dds",
    "/esoui/art/market/keyboard/tabicon_crownstore_up.dds",
}

---Texture paths differ in case and leading slash between sources.
---@param icon string
---@return string
local function IconKey(icon)
    return (string.gsub(string.lower(icon or ""), "^/", ""))
end

---The icons an entry can take: its own first, then the list.
---@param defaultIcon string
---@return string[] icons
function TravelWheelSettingsUtils.IconItems(defaultIcon)
    local icons = { defaultIcon }
    local own = IconKey(defaultIcon)
    for _, icon in ipairs(TravelWheelSettingsUtils.ICONS) do
        if IconKey(icon) ~= own then
            icons[#icons + 1] = icon
        end
    end
    return icons
end

---@param icons string[]
---@param icon string
---@return integer index Where the icon sits in the list; 1, the entry's own, when it is not there
function TravelWheelSettingsUtils.IconIndex(icons, icon)
    local wanted = IconKey(icon)
    for index, candidate in ipairs(icons) do
        if IconKey(candidate) == wanted then
            return index
        end
    end
    return 1
end

TravelWheel.SettingsUtils = TravelWheelSettingsUtils
