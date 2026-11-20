local MCH = MonsterCofferHelper

local Guard = {}
MCH.Guard = Guard

--------------------------------------------------------------------------------
-- Asking before a purchase that isn't the best buy
--------------------------------------------------------------------------------
--
-- Every way of buying from a store -- right-click Buy, the buy-multiple dialog,
-- the gamepad store, the large-purchase confirmation -- ends in the global
-- BuyStoreItem. It is not a protected function, so a pre-hook sees every
-- purchase. When the entry is the costlier coffer, or one that can only hand
-- over a duplicate, the purchase is held and a dialog asks first; "Buy anyway"
-- calls the original function, which the hook does not see.
--------------------------------------------------------------------------------

local DIALOG_NAME = "MONSTER_COFFER_HELPER_BUY_ANYWAY"

Guard.REASON_DUPLICATE     = "duplicate"
Guard.REASON_MYSTERY_WORSE = "mysteryWorse"
Guard.REASON_CURATED_WORSE = "curatedWorse"

-- Why buying store entry `entryIndex` is not the best buy, or nil when it is
-- fine or is not a coffer this addon knows about. `scan` is Store.current and
-- `result` the advisor's result for that vendor.
-- Pure, so it can be tested outside the game.
function Guard.Check(scan, result, entryIndex)
    if not scan or not result then return nil end

    if entryIndex == scan.mysteryIndex then
        if result.verdict == MCH.VERDICT_DONE then return Guard.REASON_DUPLICATE end
        if result.verdict == MCH.VERDICT_CURATED then return Guard.REASON_MYSTERY_WORSE end
        return nil
    end

    local setIds = scan.curatedIndexToSetIds and scan.curatedIndexToSetIds[entryIndex]
    if not setIds then return nil end

    -- A curated coffer whose sets are all complete is a duplicate whatever the
    -- verdict says, so that is checked first.
    local missing = MCH.Advisor.CofferCounts(result.pool, setIds)
    if missing == 0 then return Guard.REASON_DUPLICATE end
    if result.verdict == MCH.VERDICT_MYSTERY then return Guard.REASON_CURATED_WORSE end
    return nil
end

local function Message(reason, result)
    local Num = MCH.Format.Num
    if reason == Guard.REASON_MYSTERY_WORSE then
        return zo_strformat(SI_MCH_GUARD_MYSTERY_WORSE, Num(result.curatedPerNew), Num(result.mysteryPerNew))
    elseif reason == Guard.REASON_CURATED_WORSE then
        return zo_strformat(SI_MCH_GUARD_CURATED_WORSE, Num(result.mysteryPerNew), Num(result.curatedPerNew))
    end
    return GetString(SI_MCH_GUARD_DUPLICATE)
end

--------------------------------------------------------------------------------
-- Hook and dialog
--------------------------------------------------------------------------------

local originalBuyStoreItem

-- Some callers pass only the entry index, so the quantity is forwarded only
-- when there was one.
local function Buy(entryIndex, quantity)
    if quantity ~= nil then
        originalBuyStoreItem(entryIndex, quantity)
    else
        originalBuyStoreItem(entryIndex)
    end
end

-- Returning true holds the purchase; anything else lets it through untouched.
local function OnBuyStoreItem(entryIndex, quantity)
    if not MCH.db.confirmPurchases then return false end

    local scan = MCH.Store.current
    if not scan then return false end

    local result = MCH.Advisor.ForVendor(scan.vendorId)
    local reason = Guard.Check(scan, result, entryIndex)
    if not reason then return false end

    ZO_Dialogs_ShowPlatformDialog(DIALOG_NAME,
        { entryIndex = entryIndex, quantity = quantity },
        { mainTextParams = { Message(reason, result) } })
    return true
end

-- A held purchase belongs to the store it was made in.
local function OnCloseStore()
    ZO_Dialogs_ReleaseDialog(DIALOG_NAME)
end

function Guard.Initialize()
    ZO_Dialogs_RegisterCustomDialog(DIALOG_NAME, {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title       = { text = SI_MCH_GUARD_TITLE },
        mainText    = { text = "<<1>>" },
        buttons     = {
            {
                keybind  = "DIALOG_PRIMARY",
                text     = GetString(SI_MCH_GUARD_BUY),
                callback = function(dialog)
                    Buy(dialog.data.entryIndex, dialog.data.quantity)
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text    = GetString(SI_DIALOG_CANCEL),
            },
        },
    })

    originalBuyStoreItem = ZO_PreHook("BuyStoreItem", OnBuyStoreItem)
    EVENT_MANAGER:RegisterForEvent(MCH.name .. "Guard", EVENT_CLOSE_STORE, OnCloseStore)
end
