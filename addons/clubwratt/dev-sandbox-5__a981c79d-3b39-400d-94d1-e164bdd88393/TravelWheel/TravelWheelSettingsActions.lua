-- TravelWheelSettingsActions.lua: Gamepad-friendly settings page via
-- LibHarvensAddonSettings. Two of its sections follow what is picked in them
-- (TravelWheelMenuActions): under Add a destination the rows are the ones
-- the picked type has, and under Saved destinations the ones the picked
-- entry has.

local TravelWheelSettingsActions = {}

local Utils = TravelWheel.SettingsUtils
local TravelUtils = TravelWheel.TravelUtils
local WheelUtils = TravelWheel.WheelUtils
local AcceptUtils = TravelWheel.AcceptUtils
local Catalog = TravelWheel.CatalogActions
local Menu = TravelWheel.MenuActions

local KIND_ITEMS = {
    { name = "Wayshrine", data = "node" },
    { name = "House", data = "house" },
    { name = "Cyrodiil or Imperial City", data = "campaign" },
    { name = "Battleground", data = "activity" },
    { name = "Get Me Unstuck", data = "unstuck" },
}

-- Which houses the house list shows.
local HOUSE_GROUP_ITEMS = {
    { name = "Personal", data = "personal" },
    { name = "Favorite", data = "favorite" },
}

-- The types with a list to pick one destination from, and what the list is called.
local CHOICE_LABEL = { node = "Wayshrine", house = "House", campaign = "Campaign" }

local NOTHING = "(nothing to pick)"

-- What the info panel says while the favorites list is empty, by what
-- House Tours is doing.
local NO_FAVORITES = {
    unavailable = "House Tours is not available right now, so your favorites cannot be read. Pick Favorite again in a moment.",
    asking = "Asking House Tours for your favorites. They are listed here when it answers.",
    ready = "House Tours lists no favorites of yours. Favorite a house in House Tours and it is listed here.",
}

local NO_QUEUES = "The Activity Finder lists no battleground queue for this character right now."
local NO_QUEUES_INFO = "A tick row appears here for each battleground queue the Activity Finder lists. Until then the entry joins every queue it lists when you press it."

local NAME_DIALOG = "TRAVEL_WHEEL_ENTRY_NAME"
local MAX_NAME_CHARS = 40

-- The form the player is filling in. A choice is kept by its name: the
-- dropdown reports names, and the lists are read fresh from the game each time.
local form = {
    kind = "node",
    ---@type integer|nil
    zoneId = nil,
    houseGroup = "personal",
    ---@type string|nil
    choiceName = nil,
    outside = false,
    ---@type table<integer, boolean> Battleground queues by set id: false for one the entry leaves out
    queues = {},
    ---@type string|nil The name typed for the entry; nil keeps the destination's own
    customName = nil,
    ---@type string|nil The icon picked for the entry; nil keeps the destination's own
    customIcon = nil,
    ---What Add last did; "" before it is pressed and after the form changes
    status = "",
    ---@type string|nil
    savedId = nil,
    ---What Remove last did
    savedStatus = "",
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
---@return table item
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

---@return table item
local function CurrentHouseGroupItem()
    for _, item in ipairs(HOUSE_GROUP_ITEMS) do
        if item.data == form.houseGroup then
            return item
        end
    end
    return HOUSE_GROUP_ITEMS[1]
end

---@param house TravelWheelHouse|nil nil is the primary residence
---@return table item { name, data = destination without id, detail }
local function HouseItem(house)
    local destination = Utils.HouseDestination(house, form.outside)
    return { name = house and house.name or "Primary Residence", data = destination, detail = Utils.HouseDetail(house) }
end

---The destinations to pick one from, for the types that have a list.
---@return table[] items { name, data = destination without id, detail = lines that tell it apart }
local function ChoiceItems()
    local items = {}
    if form.kind == "node" then
        local zoneId = CurrentZoneItem().data
        for _, node in ipairs(zoneId and Catalog.Nodes(zoneId) or {}) do
            items[#items + 1] = { name = node.name, data = Utils.NodeDestination(node) }
        end
    elseif form.kind == "house" then
        if form.houseGroup == "favorite" then
            for _, house in ipairs(Catalog.FavoriteHouses()) do
                items[#items + 1] = HouseItem(house)
            end
        else
            items[#items + 1] = HouseItem(nil)
            for _, house in ipairs(Catalog.Houses()) do
                items[#items + 1] = HouseItem(house)
            end
        end
    elseif form.kind == "campaign" then
        items[#items + 1] = { name = "Home Campaign", data = Utils.CampaignDestination(nil) }
        for _, campaign in ipairs(Catalog.Campaigns()) do
            items[#items + 1] = { name = campaign.name, data = Utils.CampaignDestination(campaign) }
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

---@param ticks table<integer, boolean>
---@return string[] detail What a battleground entry with these ticks joins
local function QueueDetail(ticks)
    local offered = Catalog.Battlegrounds()
    local ticked = TravelUtils.TickedQueues(offered, ticks)
    if #offered == 0 then
        return { "Joins: every queue the Activity Finder lists when pressed." }
    end
    if #ticked == 0 then
        return { "Joins: nothing. No queue is ticked." }
    end
    return { "Joins: " .. TravelUtils.QueueNames(ticked) }
end

---What the form would add: the destination, and the lines that tell it apart.
---@return TravelWheelDestination|nil destination Without an id; nil when there is nothing to pick
---@return string[]|nil detail
local function FormDestination()
    if form.kind == "activity" then
        return Utils.ActivityDestination(Catalog.Battlegrounds(), form.queues), QueueDetail(form.queues)
    end
    if form.kind == "unstuck" then
        return Utils.UnstuckDestination(), nil
    end
    local item = CurrentChoiceItem()
    return item.data, item.detail
end

---The name and icon the form's entry would get, before the player changes them.
---@return string name
---@return string icon
local function FormDefaults()
    local destination = FormDestination()
    if not destination then
        return "", Utils.ICON_WAYSHRINE
    end
    return destination.name, destination.icon
end

---The player turned to the favorites and the list is empty: ask House Tours
---again, even over a search that was never answered. Called only when the
---form changed, so an answer of "none" is not asked about again by itself.
local function AskForFavoritesWhenEmpty()
    if form.kind == "house" and form.houseGroup == "favorite" and #Catalog.FavoriteHouses() == 0 then
        Catalog.RequestFavoriteHouses("favorites opened in settings", true)
    end
end

---The info panel's text for what the form would add.
---@return string
local function DescribeForm()
    local destination, detail = FormDestination()
    if not destination then
        if form.kind == "house" and form.houseGroup == "favorite" then
            return NO_FAVORITES[Catalog.FavoritesStatus()]
        end
        return "Nothing to pick here."
    end
    return Utils.Describe(form.customName or destination.name, detail, WheelUtils.Description(destination))
end

---@return TravelWheelDestination|nil destination The saved destination picked, else the first
local function CurrentSaved()
    local destinations = GetSettings().destinations
    for _, destination in ipairs(destinations) do
        if destination.id == form.savedId then
            return destination
        end
    end
    return destinations[1]
end

---@return table[] items { name, data = destination id }
local function SavedItems()
    local items = {}
    for _, destination in ipairs(GetSettings().destinations) do
        items[#items + 1] = { name = destination.name, data = destination.id }
    end
    return OrNothing(items)
end

---The info panel's text for the saved destination picked.
---@return string
local function DescribeSaved()
    local destination = CurrentSaved()
    if not destination then
        return "Nothing saved yet."
    end
    local detail = destination.kind == "activity" and QueueDetail(destination.queues or {}) or {}
    if destination.name ~= destination.defaultName then
        table.insert(detail, 1, "Was: " .. destination.defaultName)
    end
    return Utils.Describe(destination.name, detail, WheelUtils.Description(destination))
end

---Show text in the info panel beside the settings, where the library shows
---a row's tooltip: used while a list is scrolled, since the library reads a
---row's tooltip only when the row is selected.
---@param text string
local function ShowInfo(text)
    GAMEPAD_TOOLTIPS:LayoutSettingTooltip(GAMEPAD_LEFT_TOOLTIP, text, "")
end

---@param text string|nil What the player typed
---@return string|nil name nil for nothing typed
local function TypedName(text)
    local name = string.gsub(text or "", "^%s*(.-)%s*$", "%1")
    return name ~= "" and name or nil
end

---Name the entry the form will add; nothing typed goes back to the
---destination's own name.
---@param text string|nil
function TravelWheelSettingsActions.SetFormName(text)
    form.customName = TypedName(text)
end

---Rename the saved destination picked, on the wheel too; nothing typed goes
---back to the name the addon gave it.
---@param text string|nil
function TravelWheelSettingsActions.SetSavedName(text)
    local destination = CurrentSaved()
    if not destination then
        return
    end
    destination.name = TypedName(text) or destination.defaultName
    TravelWheel.WheelActions.Add(destination)
    TravelWheel.Log(string.format("renamed %s to %s", destination.id, destination.name))
end

---Tick or untick a battleground queue for the saved entry picked. The name
---the addon gave the entry follows its queues, and so does the entry's name
---while the player has not typed another.
---@param setId integer
---@param ticked boolean
function TravelWheelSettingsActions.SetSavedQueue(setId, ticked)
    local destination = CurrentSaved()
    if not destination or destination.kind ~= "activity" then
        return
    end
    destination.queues = destination.queues or {}
    -- Kept only for a queue left out: every other is joined.
    if ticked then
        destination.queues[setId] = nil
    else
        destination.queues[setId] = false
    end
    local name = Utils.ActivityName(Catalog.Battlegrounds(), destination.queues)
    if destination.name == destination.defaultName then
        destination.name = name
    end
    destination.defaultName = name
    TravelWheel.WheelActions.Add(destination)
end

---Save what the form shows and put it on the list of wheel entries, under
---the name and icon the form shows. Saving a place already saved updates it
---and keeps its id, so the wheel slot it sits in keeps working.
---@return string status
function TravelWheelSettingsActions.AddCurrent()
    local destination = FormDestination()
    if not destination then
        return "Nothing to add."
    end
    destination.defaultName, destination.defaultIcon = destination.name, destination.icon
    destination.name = form.customName or destination.name
    destination.icon = form.customIcon or destination.icon

    local settings = GetSettings()
    local existing = Utils.FindByKey(settings.destinations, Utils.Key(destination))
    if existing then
        existing.name, existing.icon, existing.outside = destination.name, destination.icon, destination.outside
        existing.defaultName, existing.defaultIcon = destination.defaultName, destination.defaultIcon
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
    local picked = CurrentSaved()
    local settings = GetSettings()
    for index, destination in ipairs(settings.destinations) do
        if destination == picked then
            table.remove(settings.destinations, index)
            TravelWheel.WheelActions.Remove(destination.id)
            form.savedId = nil
            TravelWheel.Log(string.format("removed %s name=%s", destination.id, destination.name))
            return string.format("Removed: %s.", destination.name)
        end
    end
    return "Nothing to remove."
end

-- ---------------------------------------------------------------- the name prompt
--
-- A name is typed in a gamepad dialog with a text field, the flow the game
-- uses for guild rank names: LibHarvensAddonSettings' own edit row does not
-- reliably bring up the console keyboard.

-- What the prompt is editing: the text so far, and where it goes on Accept.
local nameEdit = { text = "", onSave = nil }
local nameDialogRegistered = false

local function EnsureNameDialog()
    if nameDialogRegistered then
        return
    end
    nameDialogRegistered = true
    ZO_Dialogs_RegisterCustomDialog(NAME_DIALOG, {
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
        blockDialogReleaseOnPress = true,
        canQueue = true,
        title = {
            text = "Entry name",
        },
        mainText = {
            text = "The name this entry shows on the wheel. Leave it empty for the destination's own name.",
        },
        setup = function(dialog)
            dialog:setupFunc()
        end,
        parametricList = {
            {
                template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
                templateData = {
                    nameField = true,
                    textChangedCallback = function(control)
                        nameEdit.text = control:GetText()
                    end,
                    setup = function(control, data, selected)
                        control.highlight:SetHidden(not selected)
                        control.editBoxControl.textChangedCallback = data.textChangedCallback
                        control.editBoxControl:SetDefaultText("the destination's own name")
                        control.editBoxControl:SetTextType(TEXT_TYPE_ALL)
                        control.editBoxControl:SetMaxInputChars(MAX_NAME_CHARS)
                        control.editBoxControl:SetText(nameEdit.text)
                    end,
                },
            },
            {
                template = "ZO_GamepadTextFieldSubmitItem",
                templateData = {
                    finishedSelector = true,
                    text = GetString(SI_DIALOG_ACCEPT),
                    setup = ZO_SharedGamepadEntry_OnSetup,
                },
                icon = ZO_GAMEPAD_SUBMIT_ENTRY_ICON,
            },
        },
        buttons = {
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = function()
                    ZO_Dialogs_ReleaseDialogOnButtonPress(NAME_DIALOG)
                end,
            },
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = function(dialog)
                    local targetData = dialog.entryList and dialog.entryList:GetTargetData()
                    local targetControl = dialog.entryList and dialog.entryList:GetTargetControl()
                    if targetData and targetData.nameField and targetControl and targetControl.editBoxControl then
                        targetControl.editBoxControl:TakeFocus()
                    elseif targetData and targetData.finishedSelector then
                        nameEdit.onSave(nameEdit.text)
                        ZO_Dialogs_ReleaseDialogOnButtonPress(NAME_DIALOG)
                    end
                end,
            },
        },
    })
end

---Ask for a name, starting from the current one.
---@param current string
---@param onSave fun(text: string) Called with what was typed when the player accepts
local function AskName(current, onSave)
    EnsureNameDialog()
    nameEdit.text, nameEdit.onSave = current, onSave
    ZO_Dialogs_ShowGamepadDialog(NAME_DIALOG)
end

-- ---------------------------------------------------------------- the page

---@param key string A row key such as "queue:67"
---@return integer|nil setId
local function QueueSetId(key)
    return tonumber(string.match(key, ":(%d+)$"))
end

---Append the tick rows of a battleground entry to a layout: one per queue
---the Activity Finder lists, or a line saying it lists none.
---@param keys string[]
---@param prefix string "queue" for the form, "savedQueue" for a saved entry
local function AppendQueueKeys(keys, prefix)
    local offered = Catalog.Battlegrounds()
    for _, queue in ipairs(offered) do
        keys[#keys + 1] = prefix .. ":" .. queue.setId
    end
    if #offered == 0 then
        keys[#keys + 1] = prefix .. "None"
    end
end

---The rows of Add a destination that apply to the type picked.
---@return string[] keys
local function AddLayout()
    local keys = { "type" }
    if form.kind == "node" then
        keys[#keys + 1] = "zone"
        keys[#keys + 1] = "choice"
    elseif form.kind == "house" then
        keys[#keys + 1] = "houseGroup"
        keys[#keys + 1] = "choice"
        if form.houseGroup == "personal" then
            keys[#keys + 1] = "outside"
        end
    elseif form.kind == "campaign" then
        keys[#keys + 1] = "choice"
    elseif form.kind == "activity" then
        AppendQueueKeys(keys, "queue")
    end
    -- With nothing to pick, as while the favorites are on their way, there
    -- is nothing to name or add.
    if FormDestination() then
        keys[#keys + 1] = "name"
        keys[#keys + 1] = "icon"
        keys[#keys + 1] = "add"
    end
    if form.status ~= "" then
        keys[#keys + 1] = "status"
    end
    return keys
end

---The rows of Saved destinations that apply to the entry picked.
---@return string[] keys
local function SavedLayout()
    local destination = CurrentSaved()
    local keys = {}
    if destination then
        keys[#keys + 1] = "saved"
        keys[#keys + 1] = "savedName"
        keys[#keys + 1] = "savedIcon"
        if destination.kind == "activity" then
            AppendQueueKeys(keys, "savedQueue")
        end
        keys[#keys + 1] = "travel"
        keys[#keys + 1] = "remove"
    else
        keys[#keys + 1] = "savedNone"
    end
    if form.savedStatus ~= "" then
        keys[#keys + 1] = "savedStatus"
    end
    return keys
end

---The info panel's text for a battleground queue's tick row.
---@param setId integer
---@param name string
---@return string
local function DescribeQueue(setId, name)
    local detail = {}
    local offered
    for _, queue in ipairs(Catalog.Battlegrounds()) do
        if queue.setId == setId then
            offered = queue
        end
    end
    if not offered then
        detail[#detail + 1] = "The Activity Finder does not list this queue for this character now."
    else
        if offered.gameTypes ~= "" then
            detail[#detail + 1] = "Game types: " .. offered.gameTypes
        end
        if offered.locked then
            detail[#detail + 1] = "Locked now: " .. offered.lockReason
        end
    end
    return Utils.Describe(name, detail,
        "On: the entry joins this queue, with the others ticked, as ticking them in the Activity Finder does. A queue the game has locked when you press is left out, as a solo queue is in a group.")
end

---@param setId integer
---@return string name The queue's name as the finder lists it now
local function QueueName(setId)
    for _, queue in ipairs(Catalog.Battlegrounds()) do
        if queue.setId == setId then
            return queue.name
        end
    end
    return "Queue " .. setId
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

    ---@type TravelWheelMenuSection, TravelWheelMenuSection
    local addSection, savedSection

    ---The form changed: what Add last said is about another entry.
    ---@param source table|nil The row whose callback is running
    local function FormChanged(source)
        form.status = ""
        addSection:Refresh(source)
    end

    ---A destination or its options changed: it starts from its own name and icon again.
    ---@param source table|nil
    local function DestinationChanged(source)
        form.customName, form.customIcon = nil, nil
        FormChanged(source)
    end

    ---The saved entries, or the one picked, changed.
    ---@param source table|nil
    local function SavedChanged(source)
        savedSection:Refresh(source)
    end

    ---@type table<string, fun(key: string): table> The library's parameters for a row of Add a destination, by key
    local ADD_ROWS = {}

    function ADD_ROWS.type()
        return {
            type = LAS.ST_DROPDOWN,
            label = "Type",
            tooltip = "What kind of trip to add. The rows below are the ones this type has. Each destination you add becomes an entry you can assign to a wheel slot in Lib Radial Menu's settings.",
            items = KIND_ITEMS,
            getFunction = function()
                for _, item in ipairs(KIND_ITEMS) do
                    if item.data == form.kind then
                        return item.name
                    end
                end
            end,
            setFunction = function(_, _, item)
                -- The library also reports the one already shown.
                if item.data ~= form.kind then
                    form.kind = item.data
                    form.choiceName = nil
                    AskForFavoritesWhenEmpty()
                    if form.kind == "activity" then
                        -- What the tick rows are made from, for the log.
                        TravelWheel.Log(string.format("battleground queues: %d listed", #Catalog.Battlegrounds()))
                        for _, line in ipairs(Catalog.DescribeBattlegroundFinder()) do
                            TravelWheel.Log(line)
                        end
                    end
                    DestinationChanged(addSection:Row("type"))
                end
            end,
        }
    end

    function ADD_ROWS.zone()
        return {
            type = LAS.ST_DROPDOWN,
            label = "Zone",
            tooltip = "The zone whose wayshrines are listed below. Starts on the zone you stand in. Only places this character has discovered are listed; dungeon and trial entrances are among them.",
            items = ZoneItems,
            getFunction = function()
                return CurrentZoneItem().name
            end,
            setFunction = function(_, _, item)
                if item.data ~= CurrentZoneItem().data then
                    form.zoneId = item.data
                    form.choiceName = nil
                    DestinationChanged(addSection:Row("zone"))
                end
            end,
        }
    end

    function ADD_ROWS.houseGroup()
        return {
            type = LAS.ST_DROPDOWN,
            label = "Houses",
            tooltip = "Which houses are listed below. Personal: the houses you own, and your primary residence. Favorite: other players' houses you favorited in House Tours.",
            items = HOUSE_GROUP_ITEMS,
            getFunction = function()
                return CurrentHouseGroupItem().name
            end,
            setFunction = function(_, _, item)
                if item.data ~= form.houseGroup then
                    form.houseGroup = item.data
                    form.choiceName = nil
                    AskForFavoritesWhenEmpty()
                    DestinationChanged(addSection:Row("houseGroup"))
                end
            end,
        }
    end

    function ADD_ROWS.choice()
        return {
            type = LAS.ST_DROPDOWN,
            label = function()
                return CHOICE_LABEL[form.kind] or "Destination"
            end,
            tooltip = DescribeForm,
            items = ChoiceItems,
            getFunction = function()
                return CurrentChoiceItem().name
            end,
            setFunction = function(_, name)
                if name ~= CurrentChoiceItem().name then
                    form.choiceName = name
                    DestinationChanged(addSection:Row("choice"))
                    ShowInfo(DescribeForm())
                end
            end,
        }
    end

    function ADD_ROWS.outside()
        return {
            type = LAS.ST_CHECKBOX,
            label = "Arrive outside the house",
            tooltip = "On: arrive at the front door, in the zone the house stands in. Off: arrive inside.",
            getFunction = function()
                return form.outside
            end,
            setFunction = function(value)
                if value ~= form.outside then
                    form.outside = value
                    -- The name carries where you arrive.
                    FormChanged(addSection:Row("outside"))
                end
            end,
        }
    end

    ---A tick row for one battleground queue of the entry the form would add.
    function ADD_ROWS.queue(key)
        local setId = QueueSetId(key)
        local name = QueueName(setId)
        return {
            type = LAS.ST_CHECKBOX,
            label = name,
            tooltip = function()
                return DescribeQueue(setId, name)
            end,
            getFunction = function()
                return TravelUtils.IsQueueTicked(form.queues, setId)
            end,
            setFunction = function(value)
                -- Kept only for a queue left out: every other is joined.
                if value then
                    form.queues[setId] = nil
                else
                    form.queues[setId] = false
                end
                -- The name carries the queues joined.
                FormChanged(addSection:Row(key))
            end,
        }
    end

    function ADD_ROWS.queueNone()
        return { type = LAS.ST_LABEL, label = NO_QUEUES, tooltip = NO_QUEUES_INFO }
    end

    function ADD_ROWS.name()
        return {
            type = LAS.ST_BUTTON,
            label = function()
                return "Name: " .. (form.customName or (FormDefaults()))
            end,
            tooltip = "The name the entry shows on the wheel. It starts as the destination's own; press to type another.",
            buttonText = "Rename",
            clickHandler = function()
                AskName(form.customName or (FormDefaults()), function(text)
                    TravelWheelSettingsActions.SetFormName(text)
                    FormChanged(nil)
                end)
            end,
        }
    end

    function ADD_ROWS.icon()
        return {
            type = LAS.ST_ICONPICKER,
            label = "Icon",
            tooltip = "The icon the entry shows on the wheel. The first one is the destination's own.",
            items = function()
                local _, icon = FormDefaults()
                return Utils.IconItems(icon)
            end,
            getFunction = function()
                local _, icon = FormDefaults()
                return Utils.IconIndex(Utils.IconItems(icon), form.customIcon or icon)
            end,
            setFunction = function(_, index, icon)
                form.customIcon = index ~= 1 and icon or nil
            end,
        }
    end

    function ADD_ROWS.add()
        return {
            type = LAS.ST_BUTTON,
            label = "Add to the wheel entries",
            tooltip = function()
                return DescribeForm() .. "\nAdd saves it; then assign it to a slot in Lib Radial Menu's settings."
            end,
            buttonText = "Add",
            clickHandler = function()
                form.status = TravelWheelSettingsActions.AddCurrent()
                form.savedStatus = ""
                addSection:Refresh(nil)
                SavedChanged(nil)
            end,
        }
    end

    function ADD_ROWS.status()
        return {
            type = LAS.ST_LABEL,
            label = function()
                return form.status
            end,
        }
    end

    addSection = Menu.AddSection(panel, {
        type = LAS.ST_SECTION,
        label = "Add a destination",
        tooltip = "Pick a type of trip and a destination, and add it as an entry for the Lib Radial Menu wheel.",
    }, AddLayout, function(key)
        return ADD_ROWS[string.match(key, "^%a+")](key)
    end)

    ---@type table<string, fun(key: string): table> The library's parameters for a row of Saved destinations, by key
    local SAVED_ROWS = {}

    function SAVED_ROWS.saved()
        return {
            type = LAS.ST_DROPDOWN,
            label = "Destination",
            tooltip = DescribeSaved,
            items = SavedItems,
            getFunction = function()
                local destination = CurrentSaved()
                return destination and destination.name or NOTHING
            end,
            setFunction = function(_, _, item)
                local shown = CurrentSaved()
                if item.data and (not shown or item.data ~= shown.id) then
                    form.savedId = item.data
                    form.savedStatus = ""
                    SavedChanged(savedSection:Row("saved"))
                    ShowInfo(DescribeSaved())
                end
            end,
        }
    end

    function SAVED_ROWS.savedNone()
        -- The tooltip makes the line one the cursor can rest on: it is the only row.
        return {
            type = LAS.ST_LABEL,
            label = "Nothing saved yet. Add one under Add a destination.",
            tooltip = "The entries you add are listed here, to rename, re-icon, try or remove.",
        }
    end

    function SAVED_ROWS.savedName()
        return {
            type = LAS.ST_BUTTON,
            label = function()
                local destination = CurrentSaved()
                return "Name: " .. (destination and destination.name or "")
            end,
            tooltip = "The name this entry shows on the wheel; press to type another. Nothing typed goes back to the name it was added under.",
            buttonText = "Rename",
            clickHandler = function()
                local destination = CurrentSaved()
                if destination then
                    AskName(destination.name, function(text)
                        TravelWheelSettingsActions.SetSavedName(text)
                        SavedChanged(nil)
                    end)
                end
            end,
        }
    end

    function SAVED_ROWS.savedIcon()
        return {
            type = LAS.ST_ICONPICKER,
            label = "Icon",
            tooltip = "The icon this entry shows on the wheel. The first one is the destination's own.",
            items = function()
                local destination = CurrentSaved()
                return Utils.IconItems(destination and destination.defaultIcon or Utils.ICON_WAYSHRINE)
            end,
            getFunction = function()
                local destination = CurrentSaved()
                if not destination then
                    return 1
                end
                return Utils.IconIndex(Utils.IconItems(destination.defaultIcon), destination.icon)
            end,
            setFunction = function(_, _, icon)
                local destination = CurrentSaved()
                if destination and icon ~= destination.icon then
                    destination.icon = icon
                    TravelWheel.WheelActions.Add(destination)
                end
            end,
        }
    end

    ---A tick row for one battleground queue of the saved entry picked.
    function SAVED_ROWS.savedQueue(key)
        local setId = QueueSetId(key)
        local name = QueueName(setId)
        return {
            type = LAS.ST_CHECKBOX,
            label = name,
            tooltip = function()
                return DescribeQueue(setId, name)
            end,
            getFunction = function()
                local destination = CurrentSaved()
                return destination ~= nil and TravelUtils.IsQueueTicked(destination.queues or {}, setId)
            end,
            setFunction = function(value)
                TravelWheelSettingsActions.SetSavedQueue(setId, value)
                SavedChanged(savedSection:Row(key))
            end,
        }
    end

    function SAVED_ROWS.savedQueueNone()
        return { type = LAS.ST_LABEL, label = NO_QUEUES, tooltip = NO_QUEUES_INFO }
    end

    function SAVED_ROWS.travel()
        return {
            type = LAS.ST_BUTTON,
            label = "Travel now",
            tooltip = "Close this menu and make the trip, the same as picking the entry on the wheel.",
            buttonText = "Travel",
            clickHandler = function()
                local destination = CurrentSaved()
                if destination then
                    SCENE_MANAGER:ShowBaseScene()
                    TravelWheel.TravelActions.Go(destination.id)
                end
            end,
        }
    end

    function SAVED_ROWS.remove()
        return {
            type = LAS.ST_BUTTON,
            label = "Remove",
            tooltip = "Delete this destination. A wheel slot that held it shows empty.",
            buttonText = "Remove",
            clickHandler = function()
                form.savedStatus = TravelWheelSettingsActions.RemoveCurrent()
                SavedChanged(nil)
            end,
        }
    end

    function SAVED_ROWS.savedStatus()
        return {
            type = LAS.ST_LABEL,
            label = function()
                return form.savedStatus
            end,
        }
    end

    savedSection = Menu.AddSection(panel, {
        type = LAS.ST_SECTION,
        label = "Saved destinations",
        tooltip = "The entries you added: rename one, give it another icon, change a battleground entry's queues, travel to it now, or remove it.",
    }, SavedLayout, function(key)
        return SAVED_ROWS[string.match(key, "^%a+")](key)
    end)

    -- The rows are laid out once the character is in the world: the game's
    -- lists of wayshrines and queues are not ready while addons load.
    local inWorld = false
    local eventName = TravelWheel.name .. "_Settings"
    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_PLAYER_ACTIVATED)
        inWorld = true
        addSection:Refresh(nil)
        savedSection:Refresh(nil)
    end)

    -- What the game tells later: the favorites arrive, and the Activity
    -- Finder works out its queues.
    Catalog.OnFavorites(function()
        if inWorld and form.kind == "house" and form.houseGroup == "favorite" then
            addSection:Refresh(nil)
        end
    end)
    ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback("OnUpdateLocationData", function()
        if inWorld then
            addSection:Relayout()
            savedSection:Relayout()
        end
    end)

    TravelWheelSettingsActions.sections = { add = addSection, saved = savedSection }

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
        "When to accept a campaign queue that is ready, however it was joined.")
    AddAcceptRule("battleground", "Battlegrounds",
        "When to accept a battleground that is ready. Waiting leaves you time to finish what you are doing.")
    AddAcceptRule("dungeon", "Dungeon finder",
        "When to accept a dungeon finder group that is ready.")
end

---The form, for the offline test; Initialize adds the two sections that follow it.
TravelWheelSettingsActions.form = form

TravelWheel.SettingsActions = TravelWheelSettingsActions
