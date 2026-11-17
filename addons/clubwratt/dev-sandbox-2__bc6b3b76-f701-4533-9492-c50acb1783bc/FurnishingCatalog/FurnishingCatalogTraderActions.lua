-- FurnishingCatalogTraderActions.lua: the shopping lists at a guild trader.
--
-- On the guild trader's Browse tab (gamepad) a Shopping Lists button opens a prompt with every
-- furnishing on the lists, under its list's name. Choosing one searches the trader for it, the
-- way the game's own "search for this item" does (TRADING_HOUSE_SEARCH:LoadSearchItem, then the
-- Browse tab's Search); a second button searches for its plan instead.
-- Set up when the add-on loads: it has to work without the catalog having been opened.
local FC = FurnishingCatalog
local ScanUtils = FC.ScanUtils
local BrowseUtils = FC.BrowseUtils
local Shopping = FC.Shopping
local Plans = FC.Plans

local Trader = {}

Trader.PICK_DIALOG = "FURNISHING_CATALOG_TRADER_PICK"
Trader.KEYBIND = "UI_SHORTCUT_LEFT_STICK" -- free on the stock Browse tab (right stick resets the search)
Trader.SCENE_NAME = "gamepad_trading_house"

local EVENT_NAMESPACE = "FurnishingCatalogTrader"

local hooked = false
local hookState = "not set up yet"
local dialogRegistered = false
local lastPickedId = nil   -- the furnishing searched for last: the prompt opens on it again
local pendingSearch = nil  -- { entry, forPlan } chosen in the prompt, run once the prompt has closed

---@return integer numItems furnishings on all the lists together
local function NumListed()
    local numItems = 0
    for _, list in ipairs(Shopping.Store().lists) do
        numItems = numItems + #list.items
    end
    return numItems
end

---@return boolean showing the guild trader's gamepad screen is up
local function IsAtTrader()
    local scene = SCENE_MANAGER:GetScene(Trader.SCENE_NAME)
    return scene ~= nil and scene:IsShowing()
end

---Search the open guild trader for a furnishing on a list, or for its plan.
---@param entry table a row of the prompt: itemId, itemName, itemLink, planId
---@param forPlan boolean
---@return boolean searched
function Trader.Search(entry, forPlan)
    local link, name = entry.itemLink, entry.itemName
    if forPlan then
        if not entry.planId then
            return false
        end
        link, name = Plans.LinkOf(entry.planId), Plans.NameOf(entry.planId)
    end
    local search = rawget(_G, "TRADING_HOUSE_SEARCH")
    local tradingHouse = rawget(_G, "TRADING_HOUSE_GAMEPAD")
    if not (IsAtTrader() and type(search) == "table" and search.LoadSearchItem and type(tradingHouse) == "table" and tradingHouse.EnterBrowseResults) then
        FC.Log("trader: no search for '%s': the guild trader screen is not up", tostring(name))
        Shopping.Notify("Open a guild trader to search for it.")
        return false
    end
    lastPickedId = entry.itemId
    FC.Log("trader: searching for %s %s '%s'", forPlan and "the plan of" or "furnishing", tostring(entry.itemId), tostring(name))
    -- The item's exact name and category go into the Browse tab's filters; then its Search button.
    search:LoadSearchItem(link)
    tradingHouse:EnterBrowseResults()
    return true
end

local function RegisterDialog()
    if dialogRegistered then
        return true
    end
    if not (rawget(_G, "ZO_Dialogs_RegisterCustomDialog") and rawget(_G, "GAMEPAD_DIALOGS")) then
        return false
    end

    local function Setup(dialog)
        local parametricList = dialog.info.parametricList
        ZO_ClearNumericallyIndexedTable(parametricList)
        local numRows, selectIndex = 0, nil
        for _, list in ipairs(Shopping.Store().lists) do
            for index, itemId in ipairs(list.items) do
                local bareLink = ScanUtils.BareLink(itemId)
                local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(bareLink))
                local quality = GetItemLinkDisplayQuality(bareLink) or 0
                local entryData = ZO_GamepadEntryData:New(name, GetItemLinkIcon(bareLink))
                entryData.itemId = itemId
                entryData.itemName = name
                entryData.itemLink = ScanUtils.Link(itemId, quality)
                entryData.planId = Plans.IdOf(itemId)
                entryData:SetNameColors(entryData:GetColorsBasedOnQuality(quality))
                entryData.setup = ZO_SharedGamepadEntry_OnSetup
                numRows = numRows + 1
                if itemId == lastPickedId and not selectIndex then
                    selectIndex = numRows
                end
                table.insert(parametricList, {
                    template = "ZO_GamepadItemEntryTemplate",
                    entryData = entryData,
                    -- The first furnishing of a list carries the list's name as a section header.
                    header = index == 1 and BrowseUtils.CountLabel(list.name, #list.items) or nil,
                })
            end
        end
        dialog:setupFunc()
        if selectIndex and selectIndex > 1 then
            -- Open where the last search left off; a list that refuses stays on its first row.
            pcall(function()
                local ALLOW_EVEN_IF_DISABLED = true
                dialog.entryList:SetSelectedIndexWithoutAnimation(selectIndex, ALLOW_EVEN_IF_DISABLED)
            end)
        end
        FC.Log("trader: prompt with %d furnishing(s), opened on row %d", numRows, selectIndex or 1)
    end

    local function Choose(forPlan)
        return FC.Guard(forPlan and "TraderChoosePlan" or "TraderChoose", function(dialog)
            local target = dialog.entryList:GetTargetData()
            if target and target.itemId then
                pendingSearch = { entry = target, forPlan = forPlan }
            end
        end)
    end

    ZO_Dialogs_RegisterCustomDialog(Trader.PICK_DIALOG,
    {
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        setup = function(dialog) FC.SafeCall("TraderDialogSetup", Setup, dialog) end,
        title = { text = "Shopping Lists" },
        mainText = { text = "Search this guild trader for a furnishing on your lists, or for its plan." },
        parametricList = {}, -- filled on setup
        -- Called once the prompt has closed and the Browse tab has its buttons back: the search
        -- swaps the tab's buttons for the results', which must not happen under the prompt.
        finishedCallback = FC.Guard("TraderDialogFinished", function()
            local pending = pendingSearch
            pendingSearch = nil
            if pending then
                Trader.Search(pending.entry, pending.forPlan)
            end
        end),
        buttons =
        {
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(SI_DIALOG_CANCEL),
            },
            {
                keybind = "DIALOG_PRIMARY",
                text = "Search",
                callback = Choose(false),
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = "Search Plan",
                visible = function(dialog)
                    local target = dialog.entryList:GetTargetData()
                    return target ~= nil and target.planId ~= nil
                end,
                callback = Choose(true),
            },
        },
    })
    dialogRegistered = true
    return true
end

---Open the prompt (the Shopping Lists button on the guild trader's Browse tab).
---@return boolean shown
function Trader.ShowPicker()
    pendingSearch = nil
    if NumListed() == 0 then
        Shopping.Notify("Your shopping lists are empty. Add furnishings in the catalog: /furn")
        return false
    end
    if not RegisterDialog() then
        FC.Log("trader: the gamepad dialog system is not there; no prompt")
        return false
    end
    ZO_Dialogs_ShowGamepadDialog(Trader.PICK_DIALOG, {})
    return true
end

---Put the Shopping Lists button on the guild trader's Browse tab, once.
---@return boolean hooked
local function HookBrowseKeybinds()
    if hooked then
        return true
    end
    local browse = rawget(_G, "GAMEPAD_TRADING_HOUSE_BROWSE")
    local group = type(browse) == "table" and browse.keybindStripDescriptor
    if type(group) ~= "table" then
        hookState = "the guild trader's Browse tab is not there"
        return false
    end
    for _, descriptor in ipairs(group) do
        if type(descriptor) == "table" and descriptor.keybind == Trader.KEYBIND then
            hookState = "its button is taken on the guild trader's Browse tab"
            return false
        end
    end
    -- A group that is on the strip right now is taken off around the change, so the strip
    -- never holds a group it has not seen whole.
    local onStrip = KEYBIND_STRIP:HasKeybindButtonGroup(group)
    if onStrip then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
    end
    table.insert(group, {
        name = "Shopping Lists",
        keybind = Trader.KEYBIND,
        callback = FC.Guard("TraderShowPicker", function() Trader.ShowPicker() end),
    })
    if onStrip then
        KEYBIND_STRIP:AddKeybindButtonGroup(group)
    end
    hooked = true
    hookState = "Shopping Lists button on the guild trader's Browse tab"
    return true
end

---Set up at load; tried again each time a guild trader opens, until it holds.
function Trader.Initialize()
    HookBrowseKeybinds()
    FC.Log("trader: %s", hookState)
    if not hooked then
        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_OPEN_TRADING_HOUSE, function()
            local ok, isHooked = FC.SafeCall("TraderHook", HookBrowseKeybinds)
            if ok and isHooked then
                EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_OPEN_TRADING_HOUSE)
            end
            FC.Log("trader opened: %s", hookState)
        end)
    end
end

---@return string
function Trader.StateText()
    return hookState
end

FC.Trader = Trader
