-- TravelWheelSettingsActions.lua: Gamepad-friendly settings page via
-- LibHarvensAddonSettings: pick a destination, add it to the wheel entries,
-- try or remove a saved one.

local TravelWheelSettingsActions = {}

local Utils = TravelWheel.SettingsUtils
local ReturnUtils = TravelWheel.ReturnUtils
local AcceptUtils = TravelWheel.AcceptUtils
local Catalog = TravelWheel.CatalogActions

local KIND_ITEMS = {
    { name = "Wayshrine", data = "node" },
    { name = "House", data = "house" },
    { name = "Cyrodiil or Imperial City", data = "campaign" },
    { name = "Battleground", data = "activity" },
}

local NOTHING = "(nothing to pick)"

-- The form the player is filling in. A choice is kept by its name: the
-- dropdown reports names, and the lists are read fresh from the game each time.
local form = {
    kind = "node",
    ---@type integer|nil
    zoneId = nil,
    ---@type string|nil
    choiceName = nil,
    outside = false,
    status = "",
    ---@type string|nil
    savedId = nil,
}

---@return TravelWheelSavedVars
local function GetSettings()
    return TravelWheel.state.savedVars
end

---@param items table[]
---@return table[] items With a placeholder when the game offers nothing
local function OrNothing(items)
    if #items == 0 then
        items[1] = { name = NOTHING }
    end
    return items
end

---@return table[] items { name, data = zoneId }
local function ZoneItems()
    local items = {}
    for _, zone in ipairs(Catalog.Zones()) do
        items[#items + 1] = { name = zone.name, data = zone.zoneId }
    end
    return OrNothing(items)
end

---The zone the wayshrine list shows: the one picked, else where the player
---stands, else the first.
---@return table|nil item
local function CurrentZoneItem()
    local items = ZoneItems()
    local wanted = form.zoneId or Catalog.PlayerZoneId()
    for _, item in ipairs(items) do
        if item.data == wanted then
            return item
        end
    end
    return items[1]
end

---The destinations the picked type offers, each ready to save.
---@return table[] items { name, data = destination without id }
local function ChoiceItems()
    local items = {}
    if form.kind == "node" then
        local zoneItem = CurrentZoneItem()
        for _, node in ipairs(zoneItem and zoneItem.data and Catalog.Nodes(zoneItem.data) or {}) do
            items[#items + 1] = { name = node.name, data = Utils.NodeDestination(node) }
        end
    elseif form.kind == "house" then
        items[#items + 1] = { name = "Primary Residence", data = Utils.HouseDestination(nil, form.outside) }
        for _, house in ipairs(Catalog.Houses()) do
            items[#items + 1] = {
                name = house.owned and house.name or (house.name .. " (preview)"),
                data = Utils.HouseDestination(house, form.outside),
            }
        end
    elseif form.kind == "campaign" then
        items[#items + 1] = { name = "Home Campaign", data = Utils.CampaignDestination(nil) }
        for _, campaign in ipairs(Catalog.Campaigns()) do
            items[#items + 1] = { name = campaign.name, data = Utils.CampaignDestination(campaign) }
        end
    else
        for _, activity in ipairs(Catalog.Battlegrounds()) do
            items[#items + 1] = { name = activity.name, data = Utils.ActivityDestination(activity) }
        end
    end
    return OrNothing(items)
end

---@return table item The picked destination, else the first offered
local function CurrentChoiceItem()
    local items = ChoiceItems()
    for _, item in ipairs(items) do
        if item.name == form.choiceName then
            return item
        end
    end
    return items[1]
end

---@return table[] items { name, data = destination id }
local function SavedItems()
    local items = {}
    for _, destination in ipairs(GetSettings().destinations) do
        items[#items + 1] = { name = destination.name, data = destination.id }
    end
    return OrNothing(items)
end

---@return table item The picked saved destination, else the first
local function CurrentSavedItem()
    local items = SavedItems()
    for _, item in ipairs(items) do
        if item.data == form.savedId then
            return item
        end
    end
    return items[1]
end

---What may follow an instance: nothing, the house the player left, or a
---saved house or wayshrine.
---@return table[] items { name, data = mode }
local function AfterInstanceItems()
    local items = {
        { name = "Nowhere (off)", data = ReturnUtils.MODE_OFF },
        { name = "The house I left", data = ReturnUtils.MODE_HOUSE },
    }
    for _, destination in ipairs(GetSettings().destinations) do
        if ReturnUtils.CanFollowInstance(destination) then
            items[#items + 1] = { name = destination.name, data = destination.id }
        end
    end
    return items
end

---@return table item The picked mode; off when its destination is gone
local function CurrentAfterInstanceItem()
    local items = AfterInstanceItems()
    for _, item in ipairs(items) do
        if item.data == GetSettings().afterInstance then
            return item
        end
    end
    return items[1]
end

---Save the picked destination and put it on the list of wheel entries.
---Saving a place already saved updates it and keeps its id, so the wheel
---slot it sits in keeps working.
---@return string status
function TravelWheelSettingsActions.AddCurrent()
    local item = CurrentChoiceItem()
    local destination = item.data
    if not destination then
        return "Nothing to add."
    end

    local settings = GetSettings()
    local existing = Utils.FindByKey(settings.destinations, Utils.Key(destination))
    if existing then
        existing.name, existing.icon, existing.outside = destination.name, destination.icon, destination.outside
        TravelWheel.WheelActions.Add(existing)
        form.savedId = existing.id
        return string.format("Updated: %s.", existing.name)
    end

    destination.id = TravelWheel.WheelUtils.EntryId(settings.nextId)
    settings.nextId = settings.nextId + 1
    table.insert(settings.destinations, destination)
    TravelWheel.WheelActions.Add(destination)
    form.savedId = destination.id
    TravelWheel.Log(string.format("added %s kind=%s name=%s", destination.id, destination.kind, destination.name))
    return string.format("Added: %s. Assign it to a slot in Lib Radial Menu.", destination.name)
end

---@return string status
function TravelWheelSettingsActions.RemoveCurrent()
    local id = CurrentSavedItem().data
    local settings = GetSettings()
    for index, destination in ipairs(settings.destinations) do
        if destination.id == id then
            table.remove(settings.destinations, index)
            TravelWheel.WheelActions.Remove(id)
            form.savedId = nil
            if settings.afterInstance == id then
                settings.afterInstance = ReturnUtils.MODE_OFF
            end
            TravelWheel.Log(string.format("removed %s name=%s", id, destination.name))
            return string.format("Removed: %s.", destination.name)
        end
    end
    return "Nothing to remove."
end

function TravelWheelSettingsActions.Initialize()
    local LAS = _G["LibHarvensAddonSettings"]
    if not LAS or not LAS.AddAddon then
        TravelWheel.Log("LibHarvensAddonSettings not available; settings page disabled")
        return
    end

    local panel = LAS:AddAddon(TravelWheel.title)
    panel.author = "clubwratt"
    panel.version = "v" .. tostring(TravelWheel.version)

    local function Refresh()
        panel:UpdateControls()
    end

    panel:AddSetting({
        type = LAS.ST_SECTION,
        label = "Add a destination",
    })

    panel:AddSetting({
        type = LAS.ST_DROPDOWN,
        label = "Type",
        tooltip = "What kind of trip to add. Each destination you add becomes an entry you can assign to a wheel slot in Lib Radial Menu's settings.",
        items = KIND_ITEMS,
        getFunction = function()
            for _, item in ipairs(KIND_ITEMS) do
                if item.data == form.kind then
                    return item.name
                end
            end
        end,
        setFunction = function(_, _, item)
            if item.data ~= form.kind then
                form.kind = item.data
                form.choiceName = nil
                Refresh()
            end
        end,
    })

    panel:AddSetting({
        type = LAS.ST_DROPDOWN,
        label = "Zone",
        tooltip = "The zone whose wayshrines are listed below. Starts on the zone you stand in. Only places this character has discovered are listed; dungeon and trial entrances are among them.",
        items = ZoneItems,
        getFunction = function()
            local item = CurrentZoneItem()
            return item and item.name
        end,
        setFunction = function(_, _, item)
            -- The library also reports the zone already shown; only a new
            -- zone clears the destination picked under the old one.
            local shown = CurrentZoneItem()
            local changed = not shown or shown.data ~= item.data
            form.zoneId = item.data
            if changed then
                form.choiceName = nil
                Refresh()
            end
        end,
        disable = function()
            return form.kind ~= "node"
        end,
    })

    panel:AddSetting({
        type = LAS.ST_DROPDOWN,
        label = "Destination",
        tooltip = "Where the entry takes you. Houses list every house in the game: the ones you own first, the rest open as a preview.",
        items = ChoiceItems,
        getFunction = function()
            return CurrentChoiceItem().name
        end,
        setFunction = function(_, name)
            form.choiceName = name
        end,
    })

    panel:AddSetting({
        type = LAS.ST_CHECKBOX,
        label = "Arrive outside the house",
        tooltip = "On: arrive at the front door, in the zone the house stands in. Off: arrive inside. A house you do not own opens as a preview, inside.",
        getFunction = function()
            return form.outside
        end,
        setFunction = function(value)
            form.outside = value
        end,
        disable = function()
            return form.kind ~= "house"
        end,
    })

    panel:AddSetting({
        type = LAS.ST_BUTTON,
        label = "Add to the wheel entries",
        tooltip = "Save this destination. Then open Lib Radial Menu's settings and assign it to a slot.",
        buttonText = "Add",
        clickHandler = function()
            form.status = TravelWheelSettingsActions.AddCurrent()
            Refresh()
        end,
    })

    panel:AddSetting({
        type = LAS.ST_LABEL,
        label = function()
            return form.status
        end,
    })

    panel:AddSetting({
        type = LAS.ST_SECTION,
        label = "Saved destinations",
    })

    panel:AddSetting({
        type = LAS.ST_DROPDOWN,
        label = "Destination",
        tooltip = "The destinations you have added.",
        items = SavedItems,
        getFunction = function()
            return CurrentSavedItem().name
        end,
        setFunction = function(_, _, item)
            form.savedId = item.data
        end,
    })

    panel:AddSetting({
        type = LAS.ST_BUTTON,
        label = "Travel now",
        tooltip = "Close this menu and make the trip, the same as picking the entry on the wheel.",
        buttonText = "Travel",
        clickHandler = function()
            local id = CurrentSavedItem().data
            if id then
                SCENE_MANAGER:ShowBaseScene()
                TravelWheel.TravelActions.Go(id)
            end
        end,
    })

    panel:AddSetting({
        type = LAS.ST_BUTTON,
        label = "Remove",
        tooltip = "Delete this destination. A wheel slot that held it shows empty.",
        buttonText = "Remove",
        clickHandler = function()
            form.status = TravelWheelSettingsActions.RemoveCurrent()
            Refresh()
        end,
    })

    panel:AddSetting({
        type = LAS.ST_SECTION,
        label = "Back where you were",
    })

    panel:AddSetting({
        type = LAS.ST_DROPDOWN,
        label = "After an instance, go to",
        tooltip = "Where to travel, by itself, when a battleground, Cyrodiil, the Imperial City, a dungeon, trial or arena returns you to the main world. The house I left: back inside the house you stood in before, yours or someone else's; the game already puts you back on your spot when you left from the open world. Or pick a saved house or wayshrine (a wayshrine costs the recall fee each time). Landing in a house is left alone.",
        items = AfterInstanceItems,
        getFunction = function()
            return CurrentAfterInstanceItem().name
        end,
        setFunction = function(_, _, item)
            GetSettings().afterInstance = item.data
        end,
    })

    panel:AddSetting({
        type = LAS.ST_CHECKBOX,
        label = "Leave the battleground when the match ends",
        tooltip = "On: about 2 seconds after a match ends, leave the battleground by itself instead of waiting on the scoreboard. The game puts you back where you were, and the settings here then take you into the campaign or house you left. When the trip goes to a house and the game allows travel from the battleground, it travels straight from the scoreboard instead. Off: you stay on the scoreboard until you leave.",
        getFunction = function()
            return GetSettings().fromScoreboard
        end,
        setFunction = function(value)
            GetSettings().fromScoreboard = value
        end,
    })

    panel:AddSetting({
        type = LAS.ST_CHECKBOX,
        label = "Requeue into the campaign I left",
        tooltip = "On: when you go from Cyrodiil or the Imperial City into a battleground or dungeon and it returns you to the main world, join that campaign's queue again by itself, instead of the trip above. That queue is accepted the moment it is ready, whatever the rule for campaign queues below says.",
        getFunction = function()
            return GetSettings().requeueCampaign
        end,
        setFunction = function(value)
            GetSettings().requeueCampaign = value
        end,
    })

    panel:AddSetting({
        type = LAS.ST_SECTION,
        label = "Accept ready queues",
    })

    ---One row per kind of queue: when to accept it once it is ready.
    ---@param kind TravelWheelQueueKind
    ---@param label string
    ---@param tooltip string
    local function AddAcceptRule(kind, label, tooltip)
        local items = AcceptUtils.RuleItems()
        panel:AddSetting({
            type = LAS.ST_DROPDOWN,
            label = label,
            tooltip = tooltip .. " At the last moment accepts 3 seconds before the prompt expires, and so does a wait longer than the prompt lasts. The game's own prompt stays up meanwhile: you can still accept or decline by hand.",
            items = items,
            getFunction = function()
                for _, item in ipairs(items) do
                    if item.data == GetSettings().accept[kind] then
                        return item.name
                    end
                end
                return items[1].name
            end,
            setFunction = function(_, _, item)
                GetSettings().accept[kind] = item.data
            end,
        })
    end

    AddAcceptRule("campaign", "Cyrodiil and Imperial City",
        "When to accept a campaign queue that is ready, however it was joined. The requeue above is separate: it always accepts at once.")
    AddAcceptRule("battleground", "Battlegrounds",
        "When to accept a battleground that is ready. Waiting leaves you time to finish what you are doing.")
    AddAcceptRule("dungeon", "Dungeon finder",
        "When to accept a dungeon finder group that is ready.")
end

---The form, for the offline test.
TravelWheelSettingsActions.form = form

TravelWheel.SettingsActions = TravelWheelSettingsActions
