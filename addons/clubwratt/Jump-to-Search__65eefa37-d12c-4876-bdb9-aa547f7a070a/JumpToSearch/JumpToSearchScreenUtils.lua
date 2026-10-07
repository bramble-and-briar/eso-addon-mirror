-- JumpToSearchScreenUtils.lua: which gamepad screens have a text-search header, and how to
-- reach their screen object and active list. Pure lookups; no side effects.
--
-- Every target derives from ZO_Gamepad_ParametricList_Screen (or mirrors its header API, like
-- the guild store), so the same calls work on each: RequestEnterHeader / RequestLeaveHeader,
-- IsHeaderActive, IsTextSearchEntryHidden, SetTextSearchFocused, plus the fields headerFocus,
-- textSearchHeaderFocus and movementController (listMovementController on the trade window).

local ScreenUtils = {}

---@param globalName string
---@return fun(): table|nil
local function Global(globalName)
    return function()
        local value = _G[globalName]
        if type(value) == "table" then
            return value
        end
        return nil
    end
end

---@param screen table
---@return table|nil
local function CurrentList(screen)
    if screen.GetCurrentList then
        return screen:GetCurrentList()
    end
    return nil
end

---Guild store keeps its list on currentListObject.itemList rather than _currentList.
---@param screen table
---@return table|nil
local function TradingHouseList(screen)
    local listObject = screen.currentListObject
    if listObject then
        return listObject.itemList
    end
    return nil
end

---@type JumpToSearchScreenTarget[]
ScreenUtils.TARGETS = {
    { name = "inventory",  sceneName = "gamepad_inventory_root",           getScreen = Global("GAMEPAD_INVENTORY"),                 getList = CurrentList },
    { name = "bank",       sceneName = "gamepad_banking",                  getScreen = Global("GAMEPAD_BANKING"),                   getList = CurrentList },
    { name = "guildbank",  sceneName = "gamepad_guild_bank",               getScreen = Global("GAMEPAD_GUILD_BANK"),                getList = CurrentList },
    { name = "store",      sceneName = "gamepad_store",                    getScreen = Global("STORE_WINDOW_GAMEPAD"),              getList = CurrentList },
    { name = "guildstore", sceneName = "gamepad_trading_house",            getScreen = Global("TRADING_HOUSE_GAMEPAD"),             getList = TradingHouseList },
    { name = "trade",      sceneName = "gamepadTrade",                     getScreen = Global("GAMEPAD_TRADE"),                     getList = CurrentList },
    { name = "mail",       sceneName = "mailGamepad",                      getScreen = Global("MAIL_GAMEPAD"),                      getList = CurrentList },
    { name = "companion",  sceneName = "companionEquipmentGamepad",        getScreen = Global("COMPANION_EQUIPMENT_GAMEPAD"),       getList = CurrentList },
    { name = "furniture",  sceneName = "gamepad_housing_furniture_scene",  getScreen = Global("GAMEPAD_HOUSING_FURNITURE_BROWSER"), getList = CurrentList },
}

---@param sceneName string
---@return JumpToSearchScreenTarget|nil
function ScreenUtils.FindTargetBySceneName(sceneName)
    for _, target in ipairs(ScreenUtils.TARGETS) do
        if target.sceneName == sceneName then
            return target
        end
    end
    return nil
end

---A screen can take the jump when it has a visible text-search header and is not already in it.
---@param screen table|nil
---@return boolean canJump
---@return string reason
function ScreenUtils.CanJump(screen)
    if not screen then
        return false, "no screen"
    end
    if not (screen.RequestEnterHeader and screen.IsHeaderActive and screen.IsTextSearchEntryHidden) then
        return false, "screen lacks header API"
    end
    if not screen.textSearchHeaderFocus then
        return false, "no text search header"
    end
    if screen:IsTextSearchEntryHidden() then
        return false, "search header hidden"
    end
    if screen:IsHeaderActive() then
        return false, "header already active"
    end
    return true, "ok"
end

---Movement controllers whose CheckMovement drives the screen's UpdateDirectionalInput.
---@param screen table
---@return table[]
function ScreenUtils.GetMovementControllers(screen)
    local controllers = {}
    if screen.movementController then
        table.insert(controllers, screen.movementController)
    end
    if screen.listMovementController and screen.listMovementController ~= screen.movementController then
        table.insert(controllers, screen.listMovementController)
    end
    return controllers
end

---@param list table|nil
---@return integer|nil
function ScreenUtils.GetSelectedIndex(list)
    if list and list.GetSelectedIndex then
        return list:GetSelectedIndex()
    end
    return nil
end

---@param list table|nil
---@return integer|nil
function ScreenUtils.GetNumItems(list)
    if list then
        local getNum = list.GetNumItems or list.GetNumEntries
        if getNum then
            return getNum(list)
        end
    end
    return nil
end

JumpToSearch.ScreenUtils = ScreenUtils
