---@diagnostic disable: undefined-field, inject-field -- Native trading-house objects expose additional runtime fields
if not SemisPlaygroundCheckAccess() then return end

---@class InventoryPocTradingHouseUI
local ui = {}
BattleScrolls.inventoryPocTradingHouseUI = ui
local poc = BattleScrolls.inventoryPoc
local market = BattleScrolls.inventoryPocMarket
local SCENE_NAME = 'battleScrollsInventoryTradingHouse'
local enabled, registered, deferred, handingOff = false, false, false, false
---@type ZO_Scene|nil
local scene
local listsHooked = false

---@return boolean
function ui.isDeferred()
    return deferred
end

---These objects survive earlier visits. Their presentation callbacks can run
---even while their scenes are hidden. Rebuild from current data at handoff.
local function hookLists()
    if listsHooked or not TRADING_HOUSE_GAMEPAD.isInitialized then return end
    listsHooked = true
    ZO_PreHook(GAMEPAD_TRADING_HOUSE_LISTINGS, 'RefreshData', ui.isDeferred)
    ZO_PreHook(GAMEPAD_TRADING_HOUSE_LISTINGS, 'RequestListUpdate', ui.isDeferred)
    ZO_PreHook(GAMEPAD_TRADING_HOUSE_BROWSE, 'RefreshVisible', ui.isDeferred)
    ZO_PreHook(GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS, 'OnSearchStateChanged', ui.isDeferred)
    ZO_PreHook(GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS, 'OnResponseReceived', ui.isDeferred)
end

local function close()
    market.stop()
    -- The search helper owns the request state for the entire interaction.
    -- Finish its normal close cleanup while presentation is still suspended.
    TRADING_HOUSE_SEARCH:DisassociateWithSearchFeatures()
    deferred, handingOff = false, false
    if SCENE_MANAGER:GetCurrentScene() == scene or SCENE_MANAGER:GetNextScene() == scene then
        SCENE_MANAGER:RequestShowLeaderBaseScene(ZO_BHSCR_INTERACT_ENDED)
    end
    BattleScrolls.inventoryPocWorkUI.refresh()
end

local function handOff()
    -- The player owns the store for the remainder of this visit.
    market.stop()
    deferred, handingOff = false, true
    TRADING_HOUSE_SEARCH:ResetAllSearchData()
    TRADING_HOUSE_GAMEPAD:OpenTradingHouse()
    SYSTEMS:ShowScene(ZO_TRADING_HOUSE_SYSTEM_NAME)
end

---Called by the work panel's update, after the opening event's subscribers.
function ui.update()
    if not deferred or SCENE_MANAGER:GetCurrentScene() ~= scene then return end
    if GetInteractionType() ~= INTERACTION_TRADINGHOUSE or IsUnitInCombat('player') or IsUnitDead('player') then
        close()
        return
    end
    local pending = poc.saved and (poc.saved.pending or poc.saved.batch)
    if not enabled or poc.cancelled or market.stopped or (not poc.dirty and not pending and not market.fiber) then
        handOff()
    end
end

local function initialize()
    registered = true
    -- An independent interaction descriptor gives this scene its own close
    -- callback. Matching interactTypes keeps the server interaction through
    -- the transition into ESO's trading-house scene.
    scene = ZO_InteractScene:New(SCENE_NAME, SCENE_MANAGER, {
        type = ZO_TRADING_HOUSE_INTERACTION.type,
        interactTypes = { INTERACTION_TRADINGHOUSE },
    })
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragment(FRAME_INTERACTION_QUADRANT_4_GAMEPAD_FRAGMENT)
    scene:AddFragment(FRAME_TARGET_BLUR_QUADRANT_4_GAMEPAD_FRAGMENT)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    scene:RegisterCallback('StateChange', function(_, state)
        if state == SCENE_HIDING and deferred then
            deferred = false
            poc.cancelWork()
        end
        BattleScrolls.inventoryPocWorkUI.refresh()
    end)
    ZO_PostHook(scene, 'OnRemovedFromQueue', function()
        if deferred then deferred = false; poc.cancelWork() end
    end)

    ZO_PreHook(TRADING_HOUSE_GAMEPAD, 'OpenTradingHouse', function()
        if enabled and not handingOff and GetInteractionType() == INTERACTION_TRADINGHOUSE then
            deferred = true
            return true
        end
    end)
    ZO_PreHook(SYSTEMS, 'ShowScene', function(_, systemName)
        if deferred and systemName == ZO_TRADING_HOUSE_SYSTEM_NAME then
            SCENE_MANAGER:Show(SCENE_NAME)
            return true
        end
    end)
    ZO_PreHook(TRADING_HOUSE_GAMEPAD, 'CloseTradingHouse', function()
        if deferred then close(); return true end
        handingOff = false
    end)
    ZO_PreHook(TRADING_HOUSE_GAMEPAD, 'LockForInput', ui.isDeferred)
    ZO_PreHook(TRADING_HOUSE_GAMEPAD, 'UnlockForInput', ui.isDeferred)
    ZO_PreHook(TRADING_HOUSE_GAMEPAD, 'OnSelectedGuildChanged', ui.isDeferred)
    ZO_PostHook(TRADING_HOUSE_GAMEPAD, 'PerformDeferredInitialization', hookLists)
    hookLists()

    -- Opening the native scene normally selects the player's remembered guild.
    -- Keep our current guild through handoff: Cancel can leave a sent request
    -- awaiting its response, and even reselecting the same guild hits its guard.
    ZO_PreHook('SelectTradingHouseGuildId', function()
        return handingOff and not market.ownRequest
    end)
    TRADING_HOUSE_GAMEPAD_SCENE:RegisterCallback('StateChange', function(_, state)
        if handingOff and state == SCENE_SHOWN then
            handingOff = false
            if not TRADING_HOUSE_SEARCH:CanDoCommonOperation() then
                TRADING_HOUSE_GAMEPAD:OnAwaitingResponse()
            end
        elseif state == SCENE_HIDDEN then
            handingOff = false
        end
    end)
end

---@param value boolean
function ui.setEnabled(value)
    enabled = value
    if value and not registered then initialize() end
    if not value then ui.update() end
end
