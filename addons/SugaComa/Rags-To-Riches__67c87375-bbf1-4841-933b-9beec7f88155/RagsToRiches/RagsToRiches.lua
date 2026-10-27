--------------------------------------------------------------
-- RagsToRiches.lua — Stand-alone v1.5.0-test2 (PS5 + Safe Inventory Automation)
-- Author: SugaComa
--------------------------------------------------------------

local ADDON_NAME = "RagsToRiches"
local EM = EVENT_MANAGER

--------------------------------------------------------------
-- Chat helper
--------------------------------------------------------------
local function chat(msg)
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage("|c00FF99[RagsToRiches]|r " .. msg)
    else
        d("|c00FF99[RagsToRiches]|r " .. msg)
    end
end

--------------------------------------------------------------
-- Currency whitelist + names (top 4 only)
--------------------------------------------------------------
local RTR_ALLOWED_CURRENCIES = {
    [CURT_MONEY]           = true, -- Gold
    [CURT_ALLIANCE_POINTS] = true, -- AP
    [CURT_TELVAR_STONES]   = true, -- Tel Var
    [CURT_WRIT_VOUCHERS]   = true, -- Writ Vouchers
}

local RTR_CURRENCY_NAMES = {
    [CURT_MONEY]           = "gold",
    [CURT_ALLIANCE_POINTS] = "alliance points",
    [CURT_TELVAR_STONES]   = "Tel Var stones",
    [CURT_WRIT_VOUCHERS]   = "writ vouchers",
}

--------------------------------------------------------------
-- Number narration (for accessibility mode)
--------------------------------------------------------------
local ONES = {
    [0]  = "zero",
    [1]  = "one",
    [2]  = "two",
    [3]  = "three",
    [4]  = "four",
    [5]  = "five",
    [6]  = "six",
    [7]  = "seven",
    [8]  = "eight",
    [9]  = "nine",
    [10] = "ten",
    [11] = "eleven",
    [12] = "twelve",
    [13] = "thirteen",
    [14] = "fourteen",
    [15] = "fifteen",
    [16] = "sixteen",
    [17] = "seventeen",
    [18] = "eighteen",
    [19] = "nineteen",
}

local TENS = {
    [2] = "twenty",
    [3] = "thirty",
    [4] = "forty",
    [5] = "fifty",
    [6] = "sixty",
    [7] = "seventy",
    [8] = "eighty",
    [9] = "ninety",
}

local SCALE = { "thousand", "million", "billion" }

local function NarrateNumber(n)
    n = tonumber(n) or 0
    n = math.floor(n + 0.5)

    if n < 0 then
        return "minus " .. NarrateNumber(-n)
    end

    if n < 20 then
        return ONES[n]
    end

    if n < 100 then
        local t = math.floor(n / 10)
        local r = n % 10
        if r == 0 then
            return TENS[t]
        else
            return TENS[t] .. " " .. ONES[r]
        end
    end

    if n < 1000 then
        local h = math.floor(n / 100)
        local r = n % 100
        if r == 0 then
            return ONES[h] .. " hundred"
        else
            return ONES[h] .. " hundred " .. NarrateNumber(r)
        end
    end

    -- thousands, millions, billions
    local words = {}
    local unit = 0

    while n > 0 do
        local chunk = n % 1000
        if chunk > 0 then
            local chunkText = NarrateNumber(chunk)
            if unit > 0 and SCALE[unit] then
                chunkText = chunkText .. " " .. SCALE[unit]
            end
            table.insert(words, 1, chunkText)
        end
        n = math.floor(n / 1000)
        unit = unit + 1
    end

    return table.concat(words, " ")
end

-- FormatAmount: numeric normally, narrated words if accessibility mode is active
local function FormatAmount(amount)
    amount = tonumber(amount) or 0

    if IsAccessibilityModeEnabled and IsAccessibilityModeEnabled() then
        return NarrateNumber(amount)
    elseif ZO_LocalizeDecimalNumber then
        return ZO_LocalizeDecimalNumber(amount)
    else
        return tostring(amount)
    end
end

--------------------------------------------------------------
-- Currency helpers
--------------------------------------------------------------

-- Get character & bank amounts
local function GetCharBank(currency)
    local char = GetCurrencyAmount(currency, CURRENCY_LOCATION_CHARACTER)
    local bank = GetCurrencyAmount(currency, CURRENCY_LOCATION_BANK)
    return char, bank
end

-- Move currency between bank <-> character (all 4 use TransferCurrency on PS5)
local function MoveCurrency(currency, fromBankToChar, amount)
    if not amount or amount <= 0 then return end

    -- Currency MUST be a numeric ESO CURT_* constant (1,2,3,6)
    -- Reject anything else (string, table, nil, narration text)
    if type(currency) ~= "number" 
       or currency <= 0 
       or not RTR_ALLOWED_CURRENCIES[currency] then

        if RagsToRiches and RagsToRiches.SV and RagsToRiches.SV.debug then
            chat("Skipping unsupported currency: " .. tostring(currency))
        end
        return
    end


    local fromLoc = fromBankToChar and CURRENCY_LOCATION_BANK or CURRENCY_LOCATION_CHARACTER
    local toLoc   = fromBankToChar and CURRENCY_LOCATION_CHARACTER or CURRENCY_LOCATION_BANK

    if TransferCurrency then
        TransferCurrency(currency, amount, fromLoc, toLoc)
    else
        -- API not ready yet, retry once
        zo_callLater(function()
            if TransferCurrency then
                TransferCurrency(currency, amount, fromLoc, toLoc)
            elseif RagsToRiches and RagsToRiches.SV and RagsToRiches.SV.debug then
                chat("Could not move currency — API not ready.")
            end
        end, 150)
    end
end

--------------------------------------------------------------
-- Core rebalance logic
--------------------------------------------------------------
local function Rebalance(currency, cfg)
    if not cfg.enabled or cfg.target < 0 then return end

    local charAmt, bankAmt = GetCharBank(currency)
    local target = cfg.target

    if RagsToRiches.SV.debug then
        chat(string.format(
            "%s: char=%s bank=%s target=%s",
            RTR_CURRENCY_NAMES[currency],
            FormatAmount(charAmt),
            FormatAmount(bankAmt),
            FormatAmount(target)
        ))
    end


    -- Deposit excess to bank
    if charAmt > target then
        local deposit = charAmt - target
        MoveCurrency(currency, false, deposit)
        return
    end

    -- Withdraw shortage
    if charAmt < target then
        local need = target - charAmt
        local pull = math.min(need, bankAmt)
        if pull > 0 then
            MoveCurrency(currency, true, pull)
        end
    end
end

--------------------------------------------------------------
-- Rebalance all currencies
--------------------------------------------------------------
local function RebalanceAll()
    if not RagsToRiches.SV.enabled then return end

		Rebalance(CURT_MONEY,           RagsToRiches.SV.gold)
		Rebalance(CURT_ALLIANCE_POINTS, RagsToRiches.SV.ap)
		Rebalance(CURT_WRIT_VOUCHERS,   RagsToRiches.SV.writs)
		Rebalance(CURT_TELVAR_STONES,   RagsToRiches.SV.telvar)


end

local IsFilledSoulGem

--------------------------------------------------------------
-- Item stock control
--------------------------------------------------------------
local bankSessionRunning = false
local stockQueueRunning = false
local lockpickExcessNotified = false

local LOCKPICK_ACTIONS = {
    [1] = "Keep",
    [2] = "Sell",
    [3] = "Notify",
}

local function NormalizeLockpickAction(value)
    if type(value) == "table" then
        value = value.data or value.name or value.value or value.index
    end
    if type(value) == "number" then
        value = LOCKPICK_ACTIONS[value]
    elseif type(value) == "string" then
        local numeric = tonumber(value)
        if numeric and LOCKPICK_ACTIONS[numeric] then
            value = LOCKPICK_ACTIONS[numeric]
        end
    end
    if value == "Keep" or value == "Sell" or value == "Notify" then
        return value
    end
    return "Notify"
end

local function GetLockpickAction()
    local cfg = RagsToRiches and RagsToRiches.SV and RagsToRiches.SV.stock
        and RagsToRiches.SV.stock.lockpicks
    return NormalizeLockpickAction(cfg and cfg.action)
end

local function FindItemSlots(bagId, predicate)
    local slots, total = {}, 0
    for slotIndex = 0, GetBagSize(bagId) - 1 do
        local _, stack = GetItemInfo(bagId, slotIndex)
        if stack and stack > 0 and predicate(bagId, slotIndex) then
            table.insert(slots, { slot = slotIndex, count = stack })
            total = total + stack
        end
    end
    return slots, total
end

local function IsCleanLockpick(bagId, slotIndex)
    return GetItemType(bagId, slotIndex) == ITEMTYPE_LOCKPICK
        and not IsItemStolen(bagId, slotIndex)
end

local function GetCleanBankLockpickCount()
    local total = 0
    for _, bankBag in ipairs({ BAG_BANK, BAG_SUBSCRIBER_BANK }) do
        if bankBag then
            local _, count = FindItemSlots(bankBag, IsCleanLockpick)
            total = total + count
        end
    end
    return total
end

local function NotifyLockpickGuildStoreExcess()
    if lockpickExcessNotified or not bankSessionRunning then return end

    local cfg = RagsToRiches.SV.stock and RagsToRiches.SV.stock.lockpicks
    if not cfg or cfg.enabled == false or GetLockpickAction() ~= "Notify" then return end

    local stackSize = math.max(1, tonumber(cfg.stackSize) or 200)
    local bankStacks = math.max(0, math.floor(tonumber(cfg.bankStacks) or 20))
    local reserve = bankStacks * stackSize
    local bankTotal = GetCleanBankLockpickCount()
    local excess = math.max(0, bankTotal - reserve)
    local completeStacks = math.floor(excess / stackSize)
    if completeStacks < 1 then return end

    lockpickExcessNotified = true
    chat("You have excess clean lockpicks — sell in the guild store for 8g each.")
    chat(string.format("Guild-store stock: %d complete stack%s of %d above your bank reserve.",
        completeStacks, completeStacks == 1 and "" or "s", stackSize))
end

local function QueueMove(queue, bagFrom, slotFrom, bagTo, quantity)
    queue[#queue + 1] = {
        bagFrom = bagFrom,
        slotFrom = slotFrom,
        bagTo = bagTo,
        quantity = quantity,
    }
end

local function SecureMoveItem(bagFrom, slotFrom, bagTo, slotTo, quantity)
    if not CallSecureProtected then return false end
    CallSecureProtected("RequestMoveItem", bagFrom, slotFrom, bagTo, slotTo, quantity)
    return true
end

local function RunStockQueue(queue, onDone)
    if stockQueueRunning then return end
    if not queue or #queue == 0 then
        if onDone then onDone(0, nil) end
        return
    end

    stockQueueRunning = true
    local index, moved = 1, 0
    local handle = ADDON_NAME .. "_STOCK_QUEUE"
    EM:UnregisterForUpdate(handle)
    EM:RegisterForUpdate(handle, 750, function()
        if not bankSessionRunning then
            EM:UnregisterForUpdate(handle)
            stockQueueRunning = false
            if onDone then onDone(moved, "bank closed") end
            return
        end

        local move = queue[index]
        if not move then
            EM:UnregisterForUpdate(handle)
            stockQueueRunning = false
            if onDone then onDone(moved, nil) end
            return
        end

        local destination = GetFreeSlotInBag and GetFreeSlotInBag(move.bagTo)
        if destination == nil and FindFirstEmptySlotInBag then
            destination = FindFirstEmptySlotInBag(move.bagTo)
        end
        if destination == nil then
            EM:UnregisterForUpdate(handle)
            stockQueueRunning = false
            if onDone then onDone(moved, "destination full") end
            return
        end

        if SecureMoveItem(move.bagFrom, move.slotFrom, move.bagTo, destination, move.quantity) then
            moved = moved + move.quantity
        end
        index = index + 1
    end)
end

local function AddFullStackMoves(queue, fromBag, toBag, slots, stacksNeeded, stackSize)
    local added = 0
    for _, entry in ipairs(slots) do
        if added >= stacksNeeded then break end
        -- Stock control deliberately moves complete stacks only.
        if entry.count == stackSize then
            QueueMove(queue, fromBag, entry.slot, toBag, stackSize)
            added = added + 1
        end
    end
    return added
end

local function ProcessStockControl(bankBag)
    local cfg = RagsToRiches.SV.stock
    if not cfg or not cfg.enabled or not CallSecureProtected or stockQueueRunning then return end

    local soulPredicate = function(bagId, slotIndex)
        return IsFilledSoulGem(bagId, slotIndex)
    end

    local queue = {}

    -- Clean lockpick working stock:
    --   * Keep mode touches no lockpicks.
    --   * Sell/Notify withdraw one complete stack when carried stock falls below 50.
    --   * Sell/Notify deposit complete stacks whenever carried stock exceeds 399.
    -- Stolen lockpicks are never banked; their fence action is handled separately.
    local lockRule = cfg.lockpicks
    local lockAction = GetLockpickAction()
    if lockRule and lockRule.enabled ~= false and lockAction ~= "Keep" then
        local bagSlots, bagCount = FindItemSlots(BAG_BACKPACK, IsCleanLockpick)
        local bankSlots, bankCount = FindItemSlots(bankBag, IsCleanLockpick)
        local stackSize = math.max(1, tonumber(lockRule.stackSize) or 200)
        local carryMax = math.max(stackSize, tonumber(lockRule.carryMax) or 399)
        local low = math.max(0, tonumber(lockRule.low) or 50)

        if bagCount < low and bankCount >= stackSize then
            AddFullStackMoves(queue, bankBag, BAG_BACKPACK, bankSlots, 1, stackSize)
        elseif bagCount > carryMax then
            local stacksToDeposit = math.max(0, math.ceil((bagCount - carryMax) / stackSize))
            AddFullStackMoves(queue, BAG_BACKPACK, bankBag, bagSlots, stacksToDeposit, stackSize)
        end
    end

    -- Filled soul gems: keep a configurable number of stacks carried and in
    -- the bank. Only fill unused bank capacity; anything above the combined
    -- allowance stays carried so a merchant can sell complete excess stacks.
    local soulRule = cfg.soulGems
    if soulRule and soulRule.enabled then
        local bagSlots, bagCount = FindItemSlots(BAG_BACKPACK, soulPredicate)
        local bankSlots, bankCount = FindItemSlots(bankBag, soulPredicate)
        local stackSize = math.max(1, tonumber(soulRule.stackSize) or 200)
        local carryStacks = math.max(1, tonumber(soulRule.characterStacks) or 2)
        local bankStacks = math.max(0, tonumber(soulRule.bankStacks) or 5)
        local carryReserve = carryStacks * stackSize
        local bankReserve = bankStacks * stackSize
        local low = math.max(0, tonumber(soulRule.low) or 50)

        if bagCount < low and bankCount >= stackSize then
            AddFullStackMoves(queue, bankBag, BAG_BACKPACK, bankSlots, 1, stackSize)
        elseif bagCount >= carryReserve + stackSize and bankCount < bankReserve then
            local carryExcessStacks = math.floor((bagCount - carryReserve) / stackSize)
            local bankCapacityStacks = math.floor((bankReserve - bankCount) / stackSize)
            local stacksToDeposit = math.max(0, math.min(carryExcessStacks, bankCapacityStacks))
            AddFullStackMoves(queue, BAG_BACKPACK, bankBag, bagSlots, stacksToDeposit, stackSize)
        end
    end

    RunStockQueue(queue, function(moved, reason)
        if RagsToRiches.SV.debug then
            if moved > 0 then chat(string.format("Stock control moved %d item%s in full stacks.", moved, moved == 1 and "" or "s")) end
            if reason then chat("Stock control stopped: " .. reason .. ".") end
        end
        -- Allow the secure inventory moves to settle before counting the bank.
        if GetLockpickAction() == "Notify" then
            zo_callLater(NotifyLockpickGuildStoreExcess, 500)
        end
    end)
end

--------------------------------------------------------------
-- Banking event control — PS5 SAFE VERSION
--------------------------------------------------------------
local hasBalanced = false

local function OnBankOpened(_, bag)
    -- Only react to actual account banks
    if bag ~= BAG_BANK and bag ~= BAG_SUBSCRIBER_BANK then
        return
    end

    bankSessionRunning = true
    if hasBalanced then return end

    local function safeTry()
        if not TransferCurrency then
            zo_callLater(safeTry, 100)
            return
        end

        RebalanceAll()
        ProcessStockControl(bag)
        hasBalanced = true
    end

    zo_callLater(safeTry, 250)
end



local function OnBankClosed()
    bankSessionRunning = false
    stockQueueRunning = false
    lockpickExcessNotified = false
    EM:UnregisterForUpdate(ADDON_NAME .. "_STOCK_QUEUE")
    hasBalanced = false
end


--------------------------------------------------------------
-- Backpack monitor and safe inventory automation
--------------------------------------------------------------
local backpackWarningBand = nil
local merchantBusy = false
local fenceBusy = false
local fencePreviewHooksInstalled = false
local fencePreviewSelections = { sell = {}, launder = {} }
local fencePreviewDeselections = { sell = {}, launder = {} }

-- Accidental theft protection -------------------------------------------------
-- Do not call SetSetting here: ESO treats it as a private/protected function on
-- console. Instead, intercept the interaction before ESO starts it. If the
-- reticle target is owned and the player is not in one of ESO's safe stealth
-- states, the interaction is ignored. This follows the same interaction-level
-- approach used by established auto-loot addons and leaves the player's own
-- base-game settings untouched.
local theftInteractionHookInstalled = false

local function IsPlayerHiddenForTheftProtection()
    local state = GetUnitStealthState("player")
    return state == STEALTH_STATE_HIDDEN
        or state == STEALTH_STATE_HIDDEN_ALMOST_DETECTED
        or state == STEALTH_STATE_STEALTH
        or state == STEALTH_STATE_STEALTH_ALMOST_DETECTED
end

local function IsThievesTroveInteractable()
    if not GetGameCameraInteractableActionInfo then return false end
    local _, name = GetGameCameraInteractableActionInfo()
    if type(name) ~= "string" or name == "" then return false end

    -- Thieves Troves are competitive world containers. Do not hold the player
    -- at the reticle waiting for stealth while another player can take the trove.
    -- The displayed interactable name is the only public target detail that
    -- distinguishes the trove from ordinary owned containers at interaction time.
    local normalizedName = zo_strlower(name)
    return normalizedName:find("thieves trove", 1, true) ~= nil
        or normalizedName:find("thieves' trove", 1, true) ~= nil
end

local function InstallAccidentalTheftProtection()
    if theftInteractionHookInstalled then return end
    if not INTERACTIVE_WHEEL_MANAGER or not INTERACTIVE_WHEEL_MANAGER.StartInteraction then return end

    local originalStartInteraction = INTERACTIVE_WHEEL_MANAGER.StartInteraction

    INTERACTIVE_WHEEL_MANAGER.StartInteraction = function(self, interactionType, ...)
        local enabled = RagsToRiches
            and RagsToRiches.SV
            and RagsToRiches.SV.fence
            and RagsToRiches.SV.fence.preventAccidentalTheftUnlessHidden == true

        if enabled then
            local _, _, _, isOwned = GetGameCameraInteractableActionInfo()
            local thievesTrove = IsThievesTroveInteractable()
            if isOwned and not thievesTrove and not IsPlayerHiddenForTheftProtection() then
                if RagsToRiches.SV.debug then
                    chat("Accidental theft protection: blocked owned interaction while visible/detected.")
                end
                return true
            elseif thievesTrove and RagsToRiches.SV.debug then
                chat("Accidental theft protection: Thieves Trove bypassed stealth requirement.")
            end
        end

        return originalStartInteraction(self, interactionType, ...)
    end

    theftInteractionHookInstalled = true
end
local craftBusy = false
local stolenContainerBusy = false
local deconstructionPreviewPrepared = false
local containerLootPending = false

local ORNATE_TRAITS = {
    [ITEM_TRAIT_TYPE_ARMOR_ORNATE] = true,
    [ITEM_TRAIT_TYPE_WEAPON_ORNATE] = true,
    [ITEM_TRAIT_TYPE_JEWELRY_ORNATE] = true,
}

local INTRICATE_TRAITS = {
    [ITEM_TRAIT_TYPE_ARMOR_INTRICATE] = true,
    [ITEM_TRAIT_TYPE_WEAPON_INTRICATE] = true,
    [ITEM_TRAIT_TYPE_JEWELRY_INTRICATE] = true,
}

local INTRICATE_ACTIONS = {
    [1] = "Keep",
    [2] = "Deconstruct",
    [3] = "Sell",
}

local function NormalizeIntricateAction(value)
    if type(value) == "table" then
        value = value.data or value.name or value.value or value.index
    end
    if type(value) == "number" then
        value = INTRICATE_ACTIONS[value]
    elseif type(value) == "string" then
        local numeric = tonumber(value)
        if numeric and INTRICATE_ACTIONS[numeric] then
            value = INTRICATE_ACTIONS[numeric]
        end
    end
    if value == "Keep" or value == "Deconstruct" or value == "Sell" then
        return value
    end
    return "Keep"
end

local function GetIntricateAction()
    local cfg = RagsToRiches and RagsToRiches.SV and RagsToRiches.SV.deconstruct
    return NormalizeIntricateAction(cfg and cfg.intricateAction)
end

local CATEGORY_ACTIONS = {
    [1] = "Keep",
    [2] = "Deconstruct",
    [3] = "Sell",
}

local function NormalizeCategoryAction(value, fallback)
    if type(value) == "table" then
        value = value.data or value.name or value.value or value.index
    end
    if type(value) == "number" then
        value = CATEGORY_ACTIONS[value]
    elseif type(value) == "string" then
        local numeric = tonumber(value)
        if numeric and CATEGORY_ACTIONS[numeric] then value = CATEGORY_ACTIONS[numeric] end
    end
    if value == "Keep" or value == "Deconstruct" or value == "Sell" then return value end
    return fallback or "Keep"
end

local function GetEquipmentCategory(bagId, slotIndex, itemType)
    itemType = itemType or GetItemType(bagId, slotIndex)
    if itemType == ITEMTYPE_GLYPH_ARMOR
        or itemType == ITEMTYPE_GLYPH_WEAPON
        or itemType == ITEMTYPE_GLYPH_JEWELRY then
        return "enchants", "enchantment"
    end

    local equipType = GetItemEquipType(bagId, slotIndex)
    if equipType == EQUIP_TYPE_RING or equipType == EQUIP_TYPE_NECK then
        return "jewelry", "jewellery"
    end
    if GetItemWeaponType(bagId, slotIndex) ~= WEAPONTYPE_NONE then
        return "weapons", "weapon"
    end
    if itemType == ITEMTYPE_ARMOR then return "armor", "armour" end
    return nil, nil
end

local function GetEquipmentCategoryAction(categoryKey)
    local cfg = RagsToRiches and RagsToRiches.SV and RagsToRiches.SV.deconstruct or {}
    local actionKeys = {
        weapons = "weaponAction",
        armor = "armorAction",
        enchants = "enchantAction",
        jewelry = "jewelryAction",
    }
    return NormalizeCategoryAction(cfg[actionKeys[categoryKey]], "Keep")
end

local function IsLegendaryOrMythic(bagId, slotIndex)
    local displayQuality = GetItemDisplayQuality(bagId, slotIndex)
    local functionalQuality = tonumber(GetItemFunctionalQuality(bagId, slotIndex)) or 0
    local legendaryQuality = tonumber(ITEM_FUNCTIONAL_QUALITY_LEGENDARY)
        or tonumber(ITEM_QUALITY_LEGENDARY) or 5
    if ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE and displayQuality == ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE then
        return true
    end
    return functionalQuality >= legendaryQuality
end


IsFilledSoulGem = function(bagId, slotIndex)
    if GetItemType(bagId, slotIndex) ~= ITEMTYPE_SOUL_GEM then return false end
    if IsItemSoulGem then return IsItemSoulGem(SOUL_GEM_TYPE_FILLED, bagId, slotIndex) end
    local link = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
    if GetItemLinkSoulGemInfo then
        local soulGemType = GetItemLinkSoulGemInfo(link)
        return soulGemType == SOUL_GEM_TYPE_FILLED
    end
    return false
end

local function IsTripot(bagId, slotIndex)
    local itemType = GetItemType(bagId, slotIndex)
    if itemType ~= ITEMTYPE_POTION then return false end
    local name = zo_strlower(GetItemName(bagId, slotIndex) or '')
    return name:find('tri', 1, true) ~= nil
        or name:find('three', 1, true) ~= nil
        or name:find('restoration', 1, true) ~= nil
end

local function LargeAlert(text, sound)
    local chosenSound = (RagsToRiches.SV.backpack.sound and sound) or SOUNDS.NONE
    local CSA = CENTER_SCREEN_ANNOUNCE
    if CSA and CSA.CreateMessageParams then
        local params = CSA:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, chosenSound)
        params:SetText(text)
        params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_BAG_CAPACITY_CHANGED)
        CSA:DisplayMessage(params)
    else
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, chosenSound, text)
    end
end

local function GetBackpackFreeSlots()
    return math.max(0, GetBagSize(BAG_BACKPACK) - GetNumBagUsedSlots(BAG_BACKPACK))
end

local function GetWarningBand(freeSlots)
    local cfg = RagsToRiches.SV.backpack
    local threshold = math.max(0, tonumber(cfg.threshold) or 10)
    local step = math.max(1, tonumber(cfg.repeatStep) or 5)
    if freeSlots > threshold then return nil end
    if freeSlots <= 0 then return 0 end
    return math.floor((freeSlots - 1) / step) * step + 1
end

local function CheckBackpackSpace(force)
    local cfg = RagsToRiches.SV.backpack
    if not cfg.enabled then
        backpackWarningBand = nil
        return
    end

    local freeSlots = GetBackpackFreeSlots()
    local band = GetWarningBand(freeSlots)
    if band == nil then
        backpackWarningBand = nil
        return
    end

    if force or band ~= backpackWarningBand then
        backpackWarningBand = band
        if freeSlots == 0 then
            LargeAlert("BACKPACK FULL", SOUNDS.NEGATIVE_CLICK)
        else
            LargeAlert(string.format("Backpack nearly full — %d spaces remaining", freeSlots), SOUNDS.NEGATIVE_CLICK)
        end
    end
end

local function MatchesDefinedConstant(value, ...)
    for index = 1, select("#", ...) do
        local constant = select(index, ...)
        if constant ~= nil and value == constant then
            return true
        end
    end
    return false
end

local function IsScribingScriptItem(bagId, slotIndex, itemLink, itemType, specializedType)
    itemLink = itemLink or GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
    itemType = itemType or GetItemType(bagId, slotIndex)
    specializedType = specializedType or (GetItemSpecializedType and GetItemSpecializedType(bagId, slotIndex))

    local linkItemType, linkSpecializedType
    if GetItemLinkItemType and itemLink and itemLink ~= "" then
        linkItemType, linkSpecializedType = GetItemLinkItemType(itemLink)
    end
    if not linkSpecializedType and GetItemLinkSpecializedItemType and itemLink and itemLink ~= "" then
        linkSpecializedType = GetItemLinkSpecializedItemType(itemLink)
    end

    if MatchesDefinedConstant(itemType, ITEMTYPE_CRAFTED_ABILITY_SCRIPT)
        or MatchesDefinedConstant(linkItemType, ITEMTYPE_CRAFTED_ABILITY_SCRIPT) then
        return true
    end

    return MatchesDefinedConstant(specializedType,
            SPECIALIZED_ITEMTYPE_CRAFTED_ABILITY_SCRIPT_PRIMARY,
            SPECIALIZED_ITEMTYPE_CRAFTED_ABILITY_SCRIPT_SECONDARY,
            SPECIALIZED_ITEMTYPE_CRAFTED_ABILITY_SCRIPT_TERTIARY
        )
        or MatchesDefinedConstant(linkSpecializedType,
            SPECIALIZED_ITEMTYPE_CRAFTED_ABILITY_SCRIPT_PRIMARY,
            SPECIALIZED_ITEMTYPE_CRAFTED_ABILITY_SCRIPT_SECONDARY,
            SPECIALIZED_ITEMTYPE_CRAFTED_ABILITY_SCRIPT_TERTIARY
        )
end

local function IsGameplayProtectedItem(bagId, slotIndex, itemLink)
    local itemType = GetItemType(bagId, slotIndex)
    local specializedType = GetItemSpecializedType and GetItemSpecializedType(bagId, slotIndex)
        or (GetItemLinkSpecializedItemType and GetItemLinkSpecializedItemType(itemLink))

    -- These are valuable gameplay documents or supplies that are not part of
    -- stock control yet. Lockpicks and filled soul gems are handled separately.
    if MatchesDefinedConstant(itemType,
        ITEMTYPE_REPAIR_KIT,
        ITEMTYPE_GROUP_REPAIR_KIT,
        ITEMTYPE_SIEGE,
        ITEMTYPE_MASTER_WRIT,
        ITEMTYPE_TREASURE_MAP
    ) then return true, "gameplay item" end

    if MatchesDefinedConstant(specializedType,
        SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT,
        SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP,
        SPECIALIZED_ITEMTYPE_TROPHY_KEY_FRAGMENT,
        SPECIALIZED_ITEMTYPE_TROPHY_MUSEUM_PIECE,
        SPECIALIZED_ITEMTYPE_TROPHY_SCROLL,
        SPECIALIZED_ITEMTYPE_TROPHY_MATERIAL_UPGRADER,
        SPECIALIZED_ITEMTYPE_TROPHY_KEY,
        SPECIALIZED_ITEMTYPE_TROPHY_COLLECTIBLE_FRAGMENT,
        SPECIALIZED_ITEMTYPE_TROPHY_UPGRADE_FRAGMENT,
        SPECIALIZED_ITEMTYPE_TROPHY_DUNGEON_BUFF_INGREDIENT,
        SPECIALIZED_ITEMTYPE_TROPHY_TRIBUTE_CLUE,
        SPECIALIZED_ITEMTYPE_REPAIR_KIT_GROUP,
        SPECIALIZED_ITEMTYPE_REPAIR_KIT_CROWN,
        SPECIALIZED_ITEMTYPE_GROUP_REPAIR_KIT
    ) then return true, "gameplay item" end

    if itemType == ITEMTYPE_LOCKPICK then return true, "stock controlled lockpicks" end
    if itemType == ITEMTYPE_SOUL_GEM then return true, "stock controlled soul gems" end
    return false, nil
end

local function IsResearchableEquipment(bagId, slotIndex)
    local protection = RagsToRiches.SV.protection or {}
    if protection.researchable == false then return false end
    local category = GetEquipmentCategory(bagId, slotIndex)
    if not category or category == "enchants" then return false end
    local trait = GetItemTrait(bagId, slotIndex)
    if trait == ITEM_TRAIT_TYPE_NONE or INTRICATE_TRAITS[trait] or ORNATE_TRAITS[trait] then return false end
    -- The bag API needs five arguments; the link API resolves the research indexes.
    if CanItemLinkBeTraitResearched then
        local ok, canResearch = pcall(CanItemLinkBeTraitResearched, GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT))
        if ok and type(canResearch) == "boolean" then return canResearch end
    end
    return true -- Preserve trait-bearing equipment if knowledge cannot be checked.
end

local function IsProtectedItem(bagId, slotIndex, allowStolen)
    local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
    if not itemLink or itemLink == "" then return true, "empty" end
    if IsItemPlayerLocked(bagId, slotIndex) then return true, "locked" end
    if not allowStolen and IsItemStolen(bagId, slotIndex) then return true, "stolen" end
    local protection = RagsToRiches.SV.protection or {}
    if IsResearchableEquipment(bagId, slotIndex) then return true, "researchable trait or unknown research state" end
    local displayQuality = GetItemDisplayQuality(bagId, slotIndex)
    local mythic = ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE and displayQuality == ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE
    if mythic and protection.mythic ~= false then return true, "mythic" end
    if not mythic and protection.legendary ~= false and IsLegendaryOrMythic(bagId, slotIndex) then return true, "legendary" end
    if protection.crafted ~= false and IsItemLinkCrafted(itemLink) then return true, "crafted" end
    if protection.uncollectedSet ~= false then
        if not IsItemLinkSetCollectionPiece then return true, "set collection state unavailable" end
        local ok, isPiece = pcall(IsItemLinkSetCollectionPiece, itemLink)
        if not ok or type(isPiece) ~= "boolean" then return true, "set collection state unavailable" end
        if isPiece then
            if not GetItemLinkItemSetCollectionSlot or not GetItemLinkSetInfo or not IsItemSetCollectionSlotUnlocked then return true, "set collection state unavailable" end
            local slotOK, collectionSlot = pcall(GetItemLinkItemSetCollectionSlot, itemLink)
            local setOK, _, _, _, _, _, setId = pcall(GetItemLinkSetInfo, itemLink, false)
            if not slotOK or not setOK or not collectionSlot or not setId or setId == 0 then return true, "set collection state unavailable" end
            local knownOK, unlocked = pcall(IsItemSetCollectionSlotUnlocked, setId, collectionSlot)
            if not knownOK or unlocked ~= true then return true, "uncollected set piece" end
        end
    end
    if IsTripot(bagId, slotIndex) then return true, "tripot" end
    local gameplayProtected, reason = IsGameplayProtectedItem(bagId, slotIndex, itemLink)
    if gameplayProtected then return true, reason end
    -- Sell All Scripts is the explicit exception to unknown-learnable protection.
    if protection.unknownLearnable ~= false and CanItemBeUsedToLearn(bagId, slotIndex)
        and not (RagsToRiches.SV.merchant.sellScripts == true and IsScribingScriptItem(bagId, slotIndex, itemLink)) then
        return true, "unknown learnable"
    end
    return false, nil
end

-- Shared by merchants, crafting stations and fences; protections are checked first.
local function GetEquipmentAction(bagId, slotIndex)
    local category, label = GetEquipmentCategory(bagId, slotIndex)
    if not category then return nil, nil end
    local trait = GetItemTrait(bagId, slotIndex)
    if INTRICATE_TRAITS[trait] then return GetIntricateAction(), "intricate equipment" end
    if ORNATE_TRAITS[trait] then
        return NormalizeCategoryAction(RagsToRiches.SV.deconstruct.ornateAction, "Keep"), "ornate equipment"
    end
    return GetEquipmentCategoryAction(category), label
end

local function IsKnownLearnableItem(bagId, slotIndex, itemLink, itemType)
    -- Prefer the dedicated knowledge APIs when the client exposes them.
    if itemType == ITEMTYPE_RECIPE and IsItemLinkRecipeKnown then
        return IsItemLinkRecipeKnown(itemLink)
    end
    if itemType == ITEMTYPE_RACIAL_STYLE_MOTIF and IsItemLinkBookKnown then
        return IsItemLinkBookKnown(itemLink)
    end

    -- Conservative fallback: only treat a supported learnable category as known
    -- when ESO no longer reports that inventory item as usable to learn.
    return not CanItemBeUsedToLearn(bagId, slotIndex)
end

local FURNISHING_RECIPE_SPECIALIZED_TYPES = {}
local function AddDefinedSpecializedType(constant)
    if constant ~= nil then FURNISHING_RECIPE_SPECIALIZED_TYPES[constant] = true end
end

-- ESO exposes furnishing plans as ITEMTYPE_RECIPE, so use the dedicated API
-- where available and retain specialized-type guards for client compatibility.
AddDefinedSpecializedType(SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING)
AddDefinedSpecializedType(SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING)
AddDefinedSpecializedType(SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING)
AddDefinedSpecializedType(SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING)
AddDefinedSpecializedType(SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING)
AddDefinedSpecializedType(SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING)
AddDefinedSpecializedType(SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING)

local function IsFurnishingPlan(itemLink, specializedType)
    if IsItemLinkFurnitureRecipe then
        return IsItemLinkFurnitureRecipe(itemLink)
    end
    return FURNISHING_RECIPE_SPECIALIZED_TYPES[specializedType] == true
end

local function IsSetEquipment(itemLink)
    -- GetItemLinkSetInfo is the preferred test because non-collection set items
    -- still belong to a set. If the API is unavailable, fail safe and treat the
    -- item as set equipment so RagsToRiches will not sell it automatically.
    if GetItemLinkSetInfo then
        local hasSet = select(1, GetItemLinkSetInfo(itemLink, false))
        if type(hasSet) == "boolean" then
            return hasSet
        end
    end
    if IsItemLinkSetCollectionPiece then
        return IsItemLinkSetCollectionPiece(itemLink)
    end
    return true
end

local function IsSafeMerchantItem(bagId, slotIndex)
    local protected, reason = IsProtectedItem(bagId, slotIndex)
    if protected then return false, reason end

    local cfg = RagsToRiches.SV.merchant or {}
    local link = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
    local trait = GetItemTrait(bagId, slotIndex)
    local itemType = GetItemType(bagId, slotIndex)
    local specializedType = GetItemSpecializedType and GetItemSpecializedType(bagId, slotIndex)
        or (GetItemLinkSpecializedItemType and GetItemLinkSpecializedItemType(link))
    local quality = tonumber(GetItemFunctionalQuality(bagId, slotIndex)) or 0
    local maxLowValueQuality = ITEM_FUNCTIONAL_QUALITY_ARCANE or 3 -- white/green/blue only

    -- Learnable document categories are handled explicitly so the generic
    -- white-quality rule can never bypass their individual settings.
    if itemType == ITEMTYPE_RECIPE then
        if RagsToRiches.SV.protection.unknownLearnable ~= false and not IsKnownLearnableItem(bagId, slotIndex, link, itemType) then return false, "unknown recipe/plan" end
        if quality > maxLowValueQuality then return false, "valuable recipe/plan quality" end
        if IsFurnishingPlan(link, specializedType) then
            return cfg.knownFurnishingPlans == true, "low-quality furnishing plan"
        end
        return cfg.knownRecipes == true, "low-quality recipe"
    end

    if itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then
        if RagsToRiches.SV.protection.unknownLearnable ~= false and not IsKnownLearnableItem(bagId, slotIndex, link, itemType) then return false, "unknown motif" end
        if quality > maxLowValueQuality then return false, "valuable motif quality" end
        return cfg.knownMotifs == true, "low-quality motif/style"
    end

    if MatchesDefinedConstant(itemType, ITEMTYPE_COMPANION_ARMOR, ITEMTYPE_COMPANION_WEAPON) then
        if cfg.companionGear == true and quality >= (ITEM_FUNCTIONAL_QUALITY_MAGIC or 2) and quality <= maxLowValueQuality then
            return true, "green/blue companion equipment"
        end
        return false, "protected companion equipment"
    end

    local action, label = GetEquipmentAction(bagId, slotIndex)
    if action then return action == "Sell", label .. " set to " .. action end

    -- ESO itself marks merchant-purpose items with the Priority Sell flag.
    -- This is the same underlying flag used for the tooltip text
    -- "Sell to a merchant for gold." Hard protections above still run first.
    if cfg.prioritySell == true and IsItemPrioritySell and IsItemPrioritySell(bagId, slotIndex) then
        return true, "ESO priority-sell item"
    end

    -- Scribing scripts are an explicit opt-in category. Knowledge detection is
    -- intentionally not used: when enabled, every script is sold; when disabled,
    -- every script is kept. This makes the behaviour predictable per settings profile.
    if IsScribingScriptItem(bagId, slotIndex, link, itemType, specializedType) then
        if cfg.sellScripts == true then
            return true, "scribing script (sell all enabled)"
        end
        return false, "scribing scripts kept"
    end

    if cfg.vendorTrash ~= false and IsItemLinkVendorTrash(link) then return true, "vendor trash" end
    if cfg.vendorTrash ~= false and MatchesDefinedConstant(itemType, ITEMTYPE_TRASH, ITEMTYPE_TREASURE) then return true, "trash/treasure" end
    if itemType == ITEMTYPE_POTION then return cfg.basicPotions == true, "basic potion rule" end
    if itemType == ITEMTYPE_POISON then return cfg.basicPoisons == true, "basic poison rule" end
    if cfg.sellJunk == true and IsItemJunk(bagId, slotIndex) then return true, "other junk item" end
    if cfg.whiteItems == true and quality == 1 then return true, "other white-quality item" end
    return false, "not a merchant rule"
end

local function GetFilledSoulGemExcessForSale()
    local cfg = RagsToRiches.SV.stock and RagsToRiches.SV.stock.soulGems
    if not cfg or not cfg.enabled or cfg.sellExcess == false then return 0 end

    local stackSize = math.max(1, tonumber(cfg.stackSize) or 200)
    local carryStacks = math.max(1, tonumber(cfg.characterStacks) or 2)
    local bankStacks = math.max(0, tonumber(cfg.bankStacks) or 5)
    local _, carried = FindItemSlots(BAG_BACKPACK, function(bagId, slotIndex)
        return IsFilledSoulGem(bagId, slotIndex)
    end)

    local bankTotal = 0
    for _, bankBag in ipairs({ BAG_BANK, BAG_SUBSCRIBER_BANK }) do
        if bankBag then
            local _, count = FindItemSlots(bankBag, function(bagId, slotIndex)
                return IsFilledSoulGem(bagId, slotIndex)
            end)
            bankTotal = bankTotal + count
        end
    end

    local allowed = (carryStacks + bankStacks) * stackSize
    return math.max(0, math.floor(((carried + bankTotal) - allowed) / stackSize) * stackSize)
end

local function SellFilledSoulGemExcess()
    local cfg = RagsToRiches.SV.stock and RagsToRiches.SV.stock.soulGems
    if not cfg or cfg.sellExcess == false then return 0, 0 end
    local stackSize = math.max(1, tonumber(cfg.stackSize) or 200)
    local remaining = GetFilledSoulGemExcessForSale()
    local soldStacks, soldItems = 0, 0

    if remaining < stackSize then return 0, 0 end

    for slotIndex = GetBagSize(BAG_BACKPACK) - 1, 0, -1 do
        if remaining < stackSize then break end
        local _, stack = GetItemInfo(BAG_BACKPACK, slotIndex)
        if stack == stackSize and IsFilledSoulGem(BAG_BACKPACK, slotIndex) and not IsItemStolen(BAG_BACKPACK, slotIndex) then
            local sellPrice = GetItemSellValueWithBonuses and GetItemSellValueWithBonuses(BAG_BACKPACK, slotIndex)
                or GetItemSellValue(BAG_BACKPACK, slotIndex)
            if (tonumber(sellPrice) or 0) > 0 then
                SellInventoryItem(BAG_BACKPACK, slotIndex, stackSize)
                soldStacks = soldStacks + 1
                soldItems = soldItems + stackSize
                remaining = remaining - stackSize
            end
        end
    end
    return soldStacks, soldItems
end

local function ClassifyMerchantItems()
    local marked = 0
    for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local _, stack = GetItemInfo(BAG_BACKPACK, slotIndex)
        if stack and stack > 0 and not IsItemStolen(BAG_BACKPACK, slotIndex) then
            local sell, reason = IsSafeMerchantItem(BAG_BACKPACK, slotIndex)
            if sell and CanItemBeMarkedAsJunk(BAG_BACKPACK, slotIndex) and not IsItemJunk(BAG_BACKPACK, slotIndex) then
                SetItemIsJunk(BAG_BACKPACK, slotIndex, true)
                marked = marked + 1
                if RagsToRiches.SV.debug then chat(string.format("Marked %s as junk (%s).", GetItemLink(BAG_BACKPACK, slotIndex), reason)) end
            end
        end
    end
    return marked
end

local function CountSellableJunk()
    local count, value = 0, 0
    if not SHARED_INVENTORY or not SHARED_INVENTORY.GenerateFullSlotData then
        return count, value
    end

    local inventoryData = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
    for _, data in pairs(inventoryData or {}) do
        local stolen = data.stolen
        if stolen == nil and data.slotIndex ~= nil then
            stolen = IsItemStolen(BAG_BACKPACK, data.slotIndex)
        end
        if not stolen and data.isJunk == true then
            local stack = tonumber(data.stackCount) or 1
            local price = tonumber(data.sellPrice) or 0
            if price > 0 then
                count = count + stack
                value = value + (price * stack)
            end
        end
    end
    return count, value
end

local function ProcessMerchant()
    if merchantBusy or not RagsToRiches.SV.enabled or not RagsToRiches.SV.merchant.enabled then return end
    merchantBusy = true
    zo_callLater(function()
        local soldStacks, soldItems = SellFilledSoulGemExcess()
        if RagsToRiches.SV.debug and soldItems > 0 then
            chat(string.format("Sold %d excess filled soul gems in %d full stack%s.", soldItems, soldStacks, soldStacks == 1 and "" or "s"))
        end
        for slotIndex = GetBagSize(BAG_BACKPACK) - 1, 0, -1 do
            local _, stack = GetItemInfo(BAG_BACKPACK, slotIndex)
            if stack and stack > 0 and not IsItemStolen(BAG_BACKPACK, slotIndex) then
                local sell, reason = IsSafeMerchantItem(BAG_BACKPACK, slotIndex)
                local sellPrice = GetItemSellValueWithBonuses and GetItemSellValueWithBonuses(BAG_BACKPACK, slotIndex)
                    or GetItemSellValue(BAG_BACKPACK, slotIndex)
                if sell and (tonumber(sellPrice) or 0) > 0 then
                    SellInventoryItem(BAG_BACKPACK, slotIndex, stack)
                    soldStacks = soldStacks + 1
                    soldItems = soldItems + stack
                    if RagsToRiches.SV.debug then chat(string.format("Sold %s x%d (%s).", GetItemLink(BAG_BACKPACK, slotIndex), stack, reason)) end
                end
            end
        end
        if RagsToRiches.SV.debug then chat(string.format("Merchant workflow sent %d stack%s / %d item%s for sale.", soldStacks, soldStacks == 1 and "" or "s", soldItems, soldItems == 1 and "" or "s")) end
        merchantBusy = false
    end, 350)
end

local function GetFenceRemaining()
    local sellTotal, sellUsed = GetFenceSellTransactionInfo()
    local launderTotal, launderUsed = GetFenceLaunderTransactionInfo()
    return math.max(0, sellTotal - sellUsed), math.max(0, launderTotal - launderUsed)
end

local function IsStolenContainer(bagId, slotIndex)
    if not IsItemStolen(bagId, slotIndex) then return false end
    return GetItemType(bagId, slotIndex) == ITEMTYPE_CONTAINER
end

local function IsUtilityItemForLaundering(bagId, slotIndex)
    local itemType = GetItemType(bagId, slotIndex)
    local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
    local specializedType = GetItemSpecializedType and GetItemSpecializedType(bagId, slotIndex)
        or (GetItemLinkSpecializedItemType and GetItemLinkSpecializedItemType(itemLink))

    -- Useful stolen supplies should be cleaned and kept, never dumped at a fence.
    -- Lockpicks are deliberately excluded: the dedicated lockpick economy rule
    -- always sends eligible stolen lockpicks to the fence sale path.
    if MatchesDefinedConstant(itemType,
        ITEMTYPE_TOOL,
        ITEMTYPE_SOUL_GEM,
        ITEMTYPE_REPAIR_KIT,
        ITEMTYPE_GROUP_REPAIR_KIT
    ) then
        return true
    end

    return MatchesDefinedConstant(specializedType,
        SPECIALIZED_ITEMTYPE_TOOL,
        SPECIALIZED_ITEMTYPE_REPAIR_KIT_GROUP,
        SPECIALIZED_ITEMTYPE_REPAIR_KIT_CROWN,
        SPECIALIZED_ITEMTYPE_GROUP_REPAIR_KIT
    )
end

local function IsPurpleOrGoldFurnishing(bagId, slotIndex)
    local itemType = GetItemType(bagId, slotIndex)
    local link = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
    local specializedType = GetItemSpecializedType and GetItemSpecializedType(bagId, slotIndex)
        or (GetItemLinkSpecializedItemType and GetItemLinkSpecializedItemType(link))
    local quality = tonumber(GetItemFunctionalQuality(bagId, slotIndex)) or 0
    local purpleQuality = tonumber(ITEM_FUNCTIONAL_QUALITY_ARTIFACT)
        or tonumber(ITEM_QUALITY_ARTIFACT) or 4

    if quality < purpleQuality then return false end

    -- Purple/gold furnishing plans and placed-furnishing inventory items are
    -- always preserved by laundering. This applies even when the plan is
    -- already known so it can still be sold to another player afterwards.
    if itemType == ITEMTYPE_RECIPE and IsFurnishingPlan(link, specializedType) then
        return true
    end
    return MatchesDefinedConstant(itemType, ITEMTYPE_FURNISHING)
end


local function GetFenceSelectionKey(bagId, slotIndex)
    if GetItemUniqueId and Id64ToString then
        local itemId = GetItemUniqueId(bagId, slotIndex)
        if itemId then
            local key = Id64ToString(itemId)
            if key and key ~= "0" then return key end
        end
    end
    return string.format("%s:%s:%s", tostring(bagId), tostring(slotIndex), GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT) or "")
end

local QUESTS_WITH_STOLEN_TURNINS = {
    ["the covetous countess"] = true,
    ["a matter of leisure"] = true,
    ["a matter of respect"] = true,
    ["a matter of tributes"] = true,
    ["glitter and gleam"] = true,
}

local function IsKnownStolenTurninQuest(questName)
    if type(questName) ~= "string" then return false end
    local normalized = zo_strlower(questName:gsub("%^.*", ""))
    return QUESTS_WITH_STOLEN_TURNINS[normalized] == true
end

local function IsNeededByJournalQuest(bagId, slotIndex)
    if not RagsToRiches.SV.fence.launderQuestItems then return false, nil end
    if not GetNumJournalQuests or not GetJournalQuestName
        or not GetJournalQuestNumSteps or not GetJournalQuestNumConditions
        or not GetJournalQuestConditionInfo
        or not DoesItemFulfillJournalQuestCondition then
        return false, nil
    end

    for questIndex = 1, GetNumJournalQuests() do
        local questName = GetJournalQuestName(questIndex)
        local knownQuest = IsKnownStolenTurninQuest(questName)
        local stepCount = GetJournalQuestNumSteps(questIndex) or 0

        for stepIndex = 1, stepCount do
            local conditionCount = GetJournalQuestNumConditions(questIndex, stepIndex) or 0
            for conditionIndex = 1, conditionCount do
                local _, _, _, _, isComplete, _, _, conditionType =
                    GetJournalQuestConditionInfo(questIndex, stepIndex, conditionIndex, false)
                local launderCondition = QUEST_CONDITION_TYPE_SELL_LAUNDER_ITEM ~= nil
                    and conditionType == QUEST_CONDITION_TYPE_SELL_LAUNDER_ITEM

                if not isComplete and (knownQuest or launderCondition) then
                    local ok, fulfils = pcall(
                        DoesItemFulfillJournalQuestCondition,
                        bagId,
                        slotIndex,
                        questIndex,
                        stepIndex,
                        conditionIndex
                    )
                    if ok and fulfils == true then return true, questName end
                end
            end
        end
    end
    return false, nil
end

local function GetFenceRecommendedAction(bagId, slotIndex)
    local _, stack = GetItemInfo(bagId, slotIndex)
    if not stack or stack <= 0 then return nil, "empty" end
    if not IsItemStolen(bagId, slotIndex) then return nil, "not stolen" end
    if IsItemPlayerLocked(bagId, slotIndex) then return nil, "locked" end
    if IsStolenContainer(bagId, slotIndex) then return nil, "container" end

    -- Quest demand wins over the ordinary tradeable/non-tradeable fence rules.
    -- Every journal entry is scanned, not only the currently tracked quest.
    local neededForQuest, questName = IsNeededByJournalQuest(bagId, slotIndex)
    if neededForQuest then
        return "launder", "needed by quest: " .. tostring(questName or "journal quest")
    end

    -- Lockpicks have their own economy rule and must be decided before the
    -- generic tradeable-item laundering rule. Keep disables all handling; Sell
    -- and Notify always sell stolen lockpicks rather than laundering them.
    if GetItemType(bagId, slotIndex) == ITEMTYPE_LOCKPICK then
        local lockAction = GetLockpickAction()
        if lockAction == "Sell" or lockAction == "Notify" then
            return "sell", "stolen lockpick economy"
        end
        return nil, "lockpicks set to keep"
    end

    local protected, reason = IsProtectedItem(bagId, slotIndex, true)
    local action, label = GetEquipmentAction(bagId, slotIndex)
    if protected then return "launder", reason end
    if action == "Keep" then return nil, label .. " set to Keep" end
    if action == "Deconstruct" then return "launder", label .. " reserved for deconstruction" end
    if action == "Sell" then
        local tradeable = IsItemSellableOnTradingHouse(bagId, slotIndex)
        if not tradeable and RagsToRiches.SV.fence.sellNonTradeable then return "sell", label .. " set to Sell" end
        if tradeable and RagsToRiches.SV.fence.launderTradeable then return "launder", label .. " for merchant/player sale" end
        return nil, "equipment sale disabled by fence settings"
    end

    local utilityItem = IsUtilityItemForLaundering(bagId, slotIndex)
    local protectedFurnishing = IsPurpleOrGoldFurnishing(bagId, slotIndex)
    if utilityItem or protectedFurnishing then
        return "launder", utilityItem and "utility item" or "purple/gold furnishing"
    end

    local tradeable = IsItemSellableOnTradingHouse(bagId, slotIndex)
    if tradeable and RagsToRiches.SV.fence.launderTradeable then
        return "launder", "tradeable stolen item"
    end
    if not tradeable and RagsToRiches.SV.fence.sellNonTradeable then
        return "sell", "non-tradeable stolen item"
    end
    return nil, "no fence rule"
end

local function ClearFencePreviewSelections()
    -- Fence preview is selected-by-default. We only persist explicit exclusions
    -- made by the player during the current fence visit. This avoids racing the
    -- gamepad fence list build: any recommended row is selected as soon as ESO
    -- renders it, even if the EVENT_OPEN_FENCE callback fired before the list
    -- finished refreshing.
    fencePreviewSelections.sell = {}
    fencePreviewSelections.launder = {}
    fencePreviewDeselections.sell = {}
    fencePreviewDeselections.launder = {}
end

local function IsFencePreviewSelected(action, bagId, slotIndex)
    if not (RagsToRiches and RagsToRiches.SV and RagsToRiches.SV.fence.previewOnly) then return false end
    local recommendedAction = GetFenceRecommendedAction(bagId, slotIndex)
    if recommendedAction ~= action then return false end
    local key = GetFenceSelectionKey(bagId, slotIndex)
    return not (fencePreviewDeselections[action] and fencePreviewDeselections[action][key] == true)
end

local function GetFencePreviewSelectionCount(action)
    local count = 0
    for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if IsFencePreviewSelected(action, BAG_BACKPACK, slotIndex) then
            count = count + 1
        end
    end
    return count
end

local function BuildFencePreviewSelections()
    ClearFencePreviewSelections()
    -- No one-shot population is required. Recommended items are implicitly
    -- selected unless the player explicitly deselects them. Count them here
    -- only for the startup summary.
    local sellCount, launderCount = 0, 0
    for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local action = GetFenceRecommendedAction(BAG_BACKPACK, slotIndex)
        if action == "sell" then
            sellCount = sellCount + 1
        elseif action == "launder" then
            launderCount = launderCount + 1
        end
    end
    return sellCount, launderCount
end

local function RefreshFencePreviewUI()
    if FENCE_SELL_GAMEPAD and FENCE_SELL_GAMEPAD.Refresh then FENCE_SELL_GAMEPAD:Refresh() end
    if FENCE_LAUNDER_GAMEPAD and FENCE_LAUNDER_GAMEPAD.Refresh then FENCE_LAUNDER_GAMEPAD:Refresh() end
end

local function ToggleFencePreviewSelection(component, action)
    if not component or not component.list then return end
    local data = component.list:GetTargetData()
    if not data then return end
    local bagId, slotIndex = data.bagId, data.slotIndex
    if ZO_Inventory_GetBagAndIndex then bagId, slotIndex = ZO_Inventory_GetBagAndIndex(data) end
    if bagId == nil or slotIndex == nil then return end

    local recommendedAction = GetFenceRecommendedAction(bagId, slotIndex)
    if recommendedAction ~= action then
        local warning
        if recommendedAction == "sell" and action == "launder" then
            warning = "This item is recommended for selling and cannot be selected for laundering."
        elseif recommendedAction == "launder" and action == "sell" then
            warning = "This item is recommended for laundering and cannot be selected for sale."
        else
            warning = "This item is not recommended for this fence action."
        end
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, warning)
        return
    end

    local key = GetFenceSelectionKey(bagId, slotIndex)
    if IsFencePreviewSelected(action, bagId, slotIndex) then
        fencePreviewDeselections[action][key] = true
    else
        fencePreviewDeselections[action][key] = nil
    end
    component:Refresh()
    KEYBIND_STRIP:UpdateKeybindButtonGroup(component.keybindStripDescriptor)
end

local function ProcessFencePreviewSelections(action)
    if not RagsToRiches.SV.fence.previewOnly then return end
    local sellRemaining, launderRemaining = GetFenceRemaining()
    local remaining = action == "sell" and sellRemaining or launderRemaining
    local processed = 0

    for slotIndex = GetBagSize(BAG_BACKPACK) - 1, 0, -1 do
        if remaining <= 0 then break end
        local _, stack = GetItemInfo(BAG_BACKPACK, slotIndex)
        if stack and stack > 0 then
            local key = GetFenceSelectionKey(BAG_BACKPACK, slotIndex)
            if IsFencePreviewSelected(action, BAG_BACKPACK, slotIndex) then
                local recommendedAction = GetFenceRecommendedAction(BAG_BACKPACK, slotIndex)
                if recommendedAction == action then
                    local quantity = math.min(stack, remaining)
                    if action == "sell" then SellInventoryItem(BAG_BACKPACK, slotIndex, quantity) else LaunderItem(BAG_BACKPACK, slotIndex, quantity) end
                    processed = processed + quantity
                    remaining = remaining - quantity
                end
                -- The inventory mutation removes or changes this row anyway;
                -- clear any stale exclusion keyed to the old stack identity.
                fencePreviewDeselections[action][key] = nil
            end
        end
    end

    chat(string.format("Fence preview confirmed: %s %d selected item%s.", action == "sell" and "sold" or "laundered", processed, processed == 1 and "" or "s"))
    zo_callLater(RefreshFencePreviewUI, 250)
end

local function UpdateFencePreviewSelectionVisual(component, control, data, action)
    if not component or not control or not data then return end

    local bagId, slotIndex = data.bagId, data.slotIndex
    if ZO_Inventory_GetBagAndIndex then bagId, slotIndex = ZO_Inventory_GetBagAndIndex(data) end
    local selectedForPreview = RagsToRiches and RagsToRiches.SV and RagsToRiches.SV.fence.previewOnly
        and bagId ~= nil and slotIndex ~= nil and IsFencePreviewSelected(action, bagId, slotIndex)

    -- The fence list recycles row controls while scrolling, so use ESO's own
    -- Price currency control as the selection marker instead of injecting a
    -- separate texture/label that can be clipped by the row template.
    -- Native SetupEntry has already restored the normal white currency icon on
    -- every rebuild. For a selected recommendation, render the same currency
    -- again with iconInheritColor enabled; the gold amount colour then also
    -- colours the coin icon. Deselected rows remain in ESO's normal styling.
    if selectedForPreview then
        local priceControl = control:GetNamedChild("Price")
        if priceControl and priceControl.currencyArgs and priceControl.currencyArgs[1] then
            local currencyData = priceControl.currencyArgs[1]
            if currencyData.isUsed and currencyData.type and currencyData.amount ~= nil then
                ZO_CurrencyControl_SetSimpleCurrency(
                    priceControl,
                    currencyData.type,
                    currencyData.amount,
                    component:GetCurrencyOptions(),
                    CURRENCY_SHOW_ALL,
                    currencyData.notEnough,
                    { iconInheritColor = true }
                )
            end
        end
    end
end

local function AddFencePreviewKeybinds(component, action)
    if not component or component.rtrFencePreviewInstalled then return end
    component.rtrFencePreviewInstalled = true

    ZO_PostHook(component, "SetupEntry", function(_, control, data)
        UpdateFencePreviewSelectionVisual(component, control, data, action)
    end)

    -- ESO's fence keybind strip does not automatically re-evaluate addon keybind
    -- names when the highlighted row changes. Refresh it here so Triangle always
    -- reflects the selection flag on the item currently under the cursor.
    ZO_PostHook(component, "OnSelectedItemChanged", function()
        if RagsToRiches.SV.fence.previewOnly == true and not component.confirmationMode then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(component.keybindStripDescriptor)
        end
    end)

    table.insert(component.keybindStripDescriptor, {
        keybind = "UI_SHORTCUT_TERTIARY",
        name = function()
            local data = component.list and component.list:GetTargetData()
            if not data then return "Select Item" end
            local bagId, slotIndex = data.bagId, data.slotIndex
            if ZO_Inventory_GetBagAndIndex then bagId, slotIndex = ZO_Inventory_GetBagAndIndex(data) end
            if bagId ~= nil and slotIndex ~= nil and IsFencePreviewSelected(action, bagId, slotIndex) then
                return "Deselect Item"
            end
            return "Select Item"
        end,
        callback = function() ToggleFencePreviewSelection(component, action) end,
        visible = function() return RagsToRiches.SV.fence.previewOnly == true and not component.confirmationMode end,
    })

    table.insert(component.keybindStripDescriptor, {
        keybind = "UI_SHORTCUT_SECONDARY",
        name = function()
            local count = GetFencePreviewSelectionCount(action)
            if action == "sell" then
                return string.format("Sell Selected (%d)", count)
            end
            return string.format("Launder Selected (%d)", count)
        end,
        callback = function() ProcessFencePreviewSelections(action) end,
        enabled = function() return GetFencePreviewSelectionCount(action) > 0 end,
        visible = function() return RagsToRiches.SV.fence.previewOnly == true and not component.confirmationMode end,
    })
end

local function InstallFencePreviewHooks()
    if fencePreviewHooksInstalled then return end
    if not (FENCE_SELL_GAMEPAD and FENCE_LAUNDER_GAMEPAD) then
        zo_callLater(InstallFencePreviewHooks, 1000)
        return
    end
    fencePreviewHooksInstalled = true
    AddFencePreviewKeybinds(FENCE_SELL_GAMEPAD, "sell")
    AddFencePreviewKeybinds(FENCE_LAUNDER_GAMEPAD, "launder")
end

local function ProcessFenceItems()
    local sellRemaining, launderRemaining = GetFenceRemaining()
    local sold, laundered = 0, 0
    for slotIndex = GetBagSize(BAG_BACKPACK) - 1, 0, -1 do
        local _, stack = GetItemInfo(BAG_BACKPACK, slotIndex)
        if stack and stack > 0 then
            local action, reason = GetFenceRecommendedAction(BAG_BACKPACK, slotIndex)
            if action == "launder" and launderRemaining > 0 then
                local quantity = math.min(stack, launderRemaining)
                LaunderItem(BAG_BACKPACK, slotIndex, quantity)
                launderRemaining = launderRemaining - quantity
                laundered = laundered + quantity
                if RagsToRiches.SV.debug then chat(string.format("Laundered %s x%d (%s).", GetItemLink(BAG_BACKPACK, slotIndex), quantity, reason or "fence rule")) end
            elseif action == "sell" and sellRemaining > 0 then
                local quantity = math.min(stack, sellRemaining)
                SellInventoryItem(BAG_BACKPACK, slotIndex, quantity)
                sellRemaining = sellRemaining - quantity
                sold = sold + quantity
                if RagsToRiches.SV.debug then chat(string.format("Fence-sold %s x%d (%s).", GetItemLink(BAG_BACKPACK, slotIndex), quantity, reason or "fence rule")) end
            end
        end
    end
    if RagsToRiches.SV.debug then chat(string.format("Fence workflow: sold %d, laundered %d.", sold, laundered)) end
    fenceBusy = false
end

local function ArmContainerAutoLoot()
    containerLootPending = true
    -- Safety timeout: only loot a window opened immediately after an RTR-opened
    -- container. This prevents ordinary world/corpse/chest loot from being
    -- auto-collected if no container loot window appears.
    zo_callLater(function() containerLootPending = false end, 1500)
end

local function OnContainerLootUpdated()
    if not containerLootPending then return end
    containerLootPending = false
    zo_callLater(function()
        if LootAll then
            LootAll()
            if RagsToRiches.SV.debug then chat("Auto-looted contents from opened stolen container.") end
        end
    end, 50)
end

local function OpenNextStolenContainer(opened)
    if not RagsToRiches.SV.fence.openStolenContainers then
        ProcessFenceItems()
        return
    end

    -- Opening containers can create new inventory slots and move slot indexes,
    -- so reopen the bag scan after every use instead of caching a list.
    for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local _, stack = GetItemInfo(BAG_BACKPACK, slotIndex)
        if stack and stack > 0 and IsStolenContainer(BAG_BACKPACK, slotIndex) and not IsItemPlayerLocked(BAG_BACKPACK, slotIndex) then
            if GetBackpackFreeSlots() <= 0 then
                if RagsToRiches.SV.debug then chat("Stopped opening stolen containers: backpack is full.") end
                ProcessFenceItems()
                return
            end
            ArmContainerAutoLoot()
            CallSecureProtected("UseItem", BAG_BACKPACK, slotIndex)
            if RagsToRiches.SV.debug then chat("Opened stolen container: " .. GetItemLink(BAG_BACKPACK, slotIndex)) end
            zo_callLater(function() OpenNextStolenContainer((opened or 0) + 1) end, 500)
            return
        end
    end

    if RagsToRiches.SV.debug and (opened or 0) > 0 then
        chat(string.format("Opened %d stolen container%s before fence processing.", opened, opened == 1 and "" or "s"))
    end
    zo_callLater(ProcessFenceItems, 350)
end

local function ProcessFence()
    if fenceBusy or not RagsToRiches.SV.enabled or not RagsToRiches.SV.fence.enabled then return end
    fenceBusy = true

    if RagsToRiches.SV.fence.previewOnly == true then
        zo_callLater(function()
            local sellCount, launderCount = BuildFencePreviewSelections()
            RefreshFencePreviewUI()
            if FENCE_SELL_GAMEPAD then KEYBIND_STRIP:UpdateKeybindButtonGroup(FENCE_SELL_GAMEPAD.keybindStripDescriptor) end
            if FENCE_LAUNDER_GAMEPAD then KEYBIND_STRIP:UpdateKeybindButtonGroup(FENCE_LAUNDER_GAMEPAD.keybindStripDescriptor) end
            chat(string.format("Fence preview: %d sale stack%s and %d laundering stack%s selected by default. Gold coin icons show selected recommendations. Deselect anything you want to keep, then use the bulk action on each fence tab.", sellCount, sellCount == 1 and "" or "s", launderCount, launderCount == 1 and "" or "s"))
            fenceBusy = false
        end, 350)
        return
    end

    zo_callLater(function() OpenNextStolenContainer(0) end, 350)
end

local function GetCraftingSkillRank(craftSkill)
    if not craftSkill or not GetCraftingSkillLineIndices or not GetSkillLineInfo then return nil end
    local skillType, skillLineIndex = GetCraftingSkillLineIndices(craftSkill)
    if not skillType or not skillLineIndex then return nil end
    local _, rank = GetSkillLineInfo(skillType, skillLineIndex)
    return tonumber(rank)
end

local function IsSafeDeconstructionItem(bagId, slotIndex, craftSkill)
    local protected, reason = IsProtectedItem(bagId, slotIndex)
    if protected then return false, reason end
    local action, label = GetEquipmentAction(bagId, slotIndex)
    if action ~= "Deconstruct" then return false, (label or "item") .. " set to " .. (action or "Keep") end
    if not CanItemBeDeconstructed(bagId, slotIndex, craftSkill) then return false, "not deconstructable here" end
    return true, label .. " set to Deconstruct"
end

local function GetActiveDeconstructionPanel(source)
    if source == "Universal" and UNIVERSAL_DECONSTRUCTION_GAMEPAD then return UNIVERSAL_DECONSTRUCTION_GAMEPAD.deconstructionPanel end
    if source == "Smithing" and SMITHING_GAMEPAD then return SMITHING_GAMEPAD.deconstructionPanel end
    if UNIVERSAL_DECONSTRUCTION_GAMEPAD and UNIVERSAL_DECONSTRUCTION_GAMEPAD_SCENE and UNIVERSAL_DECONSTRUCTION_GAMEPAD_SCENE:IsShowing() then
        return UNIVERSAL_DECONSTRUCTION_GAMEPAD.deconstructionPanel
    end
    if SMITHING_GAMEPAD and SMITHING_GAMEPAD.deconstructionPanel then return SMITHING_GAMEPAD.deconstructionPanel end
    return nil
end

local function ProcessDeconstruction(craftSkill, source)
    if craftBusy or not RagsToRiches.SV.enabled or not RagsToRiches.SV.deconstruct.enabled then return end
    craftBusy = true
    zo_callLater(function()
        local rejected = {}

        if RagsToRiches.SV.deconstruct.previewOnly then
            if deconstructionPreviewPrepared then craftBusy = false return end
            local panel = GetActiveDeconstructionPanel(source)
            if not panel or not panel.extractionSlot or not panel.AddItemToCraft then
                if RagsToRiches.SV.debug then chat("Deconstruction preview: native selection panel not ready; will retry on the next panel refresh.") end
                craftBusy = false
                return
            end

            local added = 0
            for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
                if panel.extractionSlot:GetNumItems() >= MAX_ITEM_SLOTS_PER_DECONSTRUCTION then break end
                local _, stack = GetItemInfo(BAG_BACKPACK, slotIndex)
                if stack and stack > 0 then
                    local safe, reason = IsSafeDeconstructionItem(BAG_BACKPACK, slotIndex, craftSkill)
                    if safe then
                        if not panel.extractionSlot:ContainsBagAndSlot(BAG_BACKPACK, slotIndex) then
                            panel:AddItemToCraft(BAG_BACKPACK, slotIndex)
                            if panel.extractionSlot:ContainsBagAndSlot(BAG_BACKPACK, slotIndex) then
                                added = added + 1
                            else
                                rejected["native selection rejected"] = (rejected["native selection rejected"] or 0) + 1
                            end
                        end
                    else
                        reason = reason or "not eligible"
                        rejected[reason] = (rejected[reason] or 0) + 1
                    end
                end
            end

            deconstructionPreviewPrepared = true
            if added > 0 then
                chat(string.format("Deconstruction preview: pre-selected %d safe item%s. Review or deselect items, then use ESO's normal hold-Square confirmation.", added, added == 1 and "" or "s"))
            elseif RagsToRiches.SV.debug then
                chat("Deconstruction preview: no additional safe equipment found to pre-select.")
            end
        else
            PrepareDeconstructMessage()
            local queued = 0
            for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
                if queued >= MAX_ITEM_SLOTS_PER_DECONSTRUCTION then break end
                local _, stack = GetItemInfo(BAG_BACKPACK, slotIndex)
                if stack and stack > 0 then
                    local safe, reason = IsSafeDeconstructionItem(BAG_BACKPACK, slotIndex, craftSkill)
                    if safe then
                        if AddItemToDeconstructMessage(BAG_BACKPACK, slotIndex, 1) then
                            queued = queued + 1
                            if RagsToRiches.SV.debug then chat(string.format("Queued %s for deconstruction (%s).", GetItemLink(BAG_BACKPACK, slotIndex), reason or "safe equipment")) end
                        else
                            rejected["queue rejected"] = (rejected["queue rejected"] or 0) + 1
                        end
                    else
                        reason = reason or "not eligible"
                        rejected[reason] = (rejected[reason] or 0) + 1
                    end
                end
            end
            if queued > 0 then
                SendDeconstructMessage()
                chat(string.format("Sent %d safe equipment item%s for deconstruction.", queued, queued == 1 and "" or "s"))
            elseif RagsToRiches.SV.debug then
                chat("No safe equipment found for deconstruction.")
            end
        end

        if RagsToRiches.SV.debug then
            local parts = {}
            for reason, count in pairs(rejected) do table.insert(parts, string.format("%s=%d", reason, count)) end
            table.sort(parts)
            if #parts > 0 then chat("Deconstruction rejected: " .. table.concat(parts, ", ")) end
        end
        craftBusy = false
    end, 500)
end

local activeCraftSkill = nil
local atCraftingStation = false
local deconstructionHooksInstalled = false

local function TryOpenStolenContainerFromInventory(slotIndex)
    if stolenContainerBusy then return end
    if not RagsToRiches or not RagsToRiches.SV or not RagsToRiches.SV.enabled then return end
    if not RagsToRiches.SV.fence or not RagsToRiches.SV.fence.openStolenContainers then return end
    if RagsToRiches.SV.fence.previewOnly == true then return end

    local _, stack = GetItemInfo(BAG_BACKPACK, slotIndex)
    if not stack or stack <= 0 or not IsStolenContainer(BAG_BACKPACK, slotIndex) then return end
    if IsItemPlayerLocked(BAG_BACKPACK, slotIndex) or GetBackpackFreeSlots() <= 0 then return end
    stolenContainerBusy = true
    zo_callLater(function()
        local _, currentStack = GetItemInfo(BAG_BACKPACK, slotIndex)
        if currentStack and currentStack > 0 and IsStolenContainer(BAG_BACKPACK, slotIndex) and not IsItemPlayerLocked(BAG_BACKPACK, slotIndex) then
            ArmContainerAutoLoot()
            CallSecureProtected("UseItem", BAG_BACKPACK, slotIndex)
            if RagsToRiches.SV.debug then chat("Auto-opened stolen container from backpack: " .. GetItemLink(BAG_BACKPACK, slotIndex)) end
        end
        zo_callLater(function() stolenContainerBusy = false end, 500)
    end, 250)
end

local function OnInventorySlotUpdate(_, bagId, slotIndex)
    if bagId ~= BAG_BACKPACK then return end
    zo_callLater(CheckBackpackSpace, 100)
    TryOpenStolenContainerFromInventory(slotIndex)

    -- Merchant candidates are marked when they enter/change in the backpack,
    -- so the junk flag already exists before a vendor is opened.
    if RagsToRiches and RagsToRiches.SV and RagsToRiches.SV.enabled and RagsToRiches.SV.merchant.enabled then
        zo_callLater(function()
            local _, stack = GetItemInfo(BAG_BACKPACK, slotIndex)
            if stack and stack > 0 and not IsItemStolen(BAG_BACKPACK, slotIndex) then
                local sell, reason = IsSafeMerchantItem(BAG_BACKPACK, slotIndex)
                if sell and CanItemBeMarkedAsJunk(BAG_BACKPACK, slotIndex) and not IsItemJunk(BAG_BACKPACK, slotIndex) then
                    SetItemIsJunk(BAG_BACKPACK, slotIndex, true)
                    if RagsToRiches.SV.debug then
                        chat(string.format("Inventory update: marked %s as junk (%s).", GetItemLink(BAG_BACKPACK, slotIndex), reason or "merchant item"))
                    end
                end
            end
        end, 100)
    end
end

local function RequestPanelDeconstruction(source)
    if not atCraftingStation or craftBusy then return end
    if RagsToRiches.SV.debug then chat(source .. " deconstruction panel detected.") end
    zo_callLater(function()
        if atCraftingStation then ProcessDeconstruction(activeCraftSkill, source) end
    end, (GetLatency and GetLatency() or 0) + 150)
end

local function InstallDeconstructionHooks()
    if deconstructionHooksInstalled then return end
    deconstructionHooksInstalled = true

    if ZO_IsConsoleOrGameCoreUI and ZO_IsConsoleOrGameCoreUI() then
        if UNIVERSAL_DECONSTRUCTION_GAMEPAD and UNIVERSAL_DECONSTRUCTION_GAMEPAD.deconstructionPanel then
            ZO_PostHook(UNIVERSAL_DECONSTRUCTION_GAMEPAD.deconstructionPanel, "RefreshFilter", function()
                RequestPanelDeconstruction("Universal")
            end)
        end
        if SMITHING_GAMEPAD and SMITHING_GAMEPAD.deconstructionPanel then
            ZO_PostHook(SMITHING_GAMEPAD.deconstructionPanel, "RefreshTooltip", function()
                RequestPanelDeconstruction("Smithing")
            end)
        end
    else
        if UNIVERSAL_DECONSTRUCTION and UNIVERSAL_DECONSTRUCTION.deconstructionPanel then
            ZO_PostHook(UNIVERSAL_DECONSTRUCTION.deconstructionPanel, "RefreshAccessibleCraftingTypeFilters", function()
                RequestPanelDeconstruction("Universal")
            end)
        end
        if SMITHING and SMITHING.deconstructionPanel and SMITHING.deconstructionPanel.inventory then
            ZO_PostHook(SMITHING.deconstructionPanel.inventory, "PerformFullRefresh", function()
                RequestPanelDeconstruction("Smithing")
            end)
        end
    end
end

local function OnCraftingStation(_, craftSkill, _, craftMode)
    atCraftingStation = true
    deconstructionPreviewPrepared = false
    if craftMode == CRAFTING_INTERACTION_MODE_UNIVERSAL_DECONSTRUCTION or craftSkill == CRAFTING_TYPE_INVALID then
        activeCraftSkill = nil
    else
        activeCraftSkill = craftSkill
    end
    if RagsToRiches.SV.debug then chat("Crafting interaction detected; waiting for deconstruction panel.") end
end

local function OnEndCraftingStation()
    atCraftingStation = false
    activeCraftSkill = nil
    craftBusy = false
    deconstructionPreviewPrepared = false
end

--------------------------------------------------------------
-- Settings scope
--------------------------------------------------------------
local SETTINGS_SCOPE_ACCOUNT = "Account-wide"
local SETTINGS_SCOPE_CHARACTER = "Per Character"

local function NormalizeSettingsScope(value)
    if type(value) == "table" then
        value = value.data or value.name or value.value
    end
    if type(value) == "number" then
        return value == 2 and SETTINGS_SCOPE_CHARACTER or SETTINGS_SCOPE_ACCOUNT
    end
    local lowered = string.lower(tostring(value or ""))
    if string.find(lowered, "character", 1, true) then
        return SETTINGS_SCOPE_CHARACTER
    end
    return SETTINGS_SCOPE_ACCOUNT
end

local function ApplyActiveSettingsScope()
    local scope = NormalizeSettingsScope(RagsToRiches.ScopeSV and RagsToRiches.ScopeSV.settingsScope)
    if RagsToRiches.ScopeSV then
        RagsToRiches.ScopeSV.settingsScope = scope
    end
    if scope == SETTINGS_SCOPE_CHARACTER and RagsToRiches.CharacterSV then
        RagsToRiches.SV = RagsToRiches.CharacterSV
    else
        RagsToRiches.SV = RagsToRiches.AccountSV
    end
    return scope
end

local function GetActiveSettingsScope()
    return NormalizeSettingsScope(RagsToRiches.ScopeSV and RagsToRiches.ScopeSV.settingsScope)
end

--------------------------------------------------------------
-- Settings menu (LibHarvensAddonSettings)
--------------------------------------------------------------
local function CreateSettings()
    if not LibHarvensAddonSettings then return end
    local LHAS = LibHarvensAddonSettings

    local settings = LHAS:AddAddon("Rags To Riches", {allowDefaults=true, allowRefresh=true})
    if not settings then return end

    -- Console LHAS keeps settings after a normal ST_SECTION inside that
    -- section until another section resets it.  A section with subMenu=false
    -- acts as a top-level visual divider without opening an options page.
    local function AddCategoryHeader(label)
        settings:AddSetting({
            type = LHAS.ST_SECTION,
            subMenu = false,
            label = "|cFFD700-- " .. label .. " --|r",
        })
    end

    local bankTargetTooltip = "This value is the amount your character will always keep after interacting with a bank."

    AddCategoryHeader("MAIN SETTINGS")

    ----------------------------------------------------------
    -- Settings scope (first choice)
    ----------------------------------------------------------
    settings:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "Settings Scope",
        tooltip = "Account-wide shares one RagsToRiches configuration across every character. Per Character gives each character its own independent configuration. Switching scope does not overwrite the other profile.",
        items = {
            { name = SETTINGS_SCOPE_ACCOUNT, data = SETTINGS_SCOPE_ACCOUNT },
            { name = SETTINGS_SCOPE_CHARACTER, data = SETTINGS_SCOPE_CHARACTER },
        },
        getFunction = function() return GetActiveSettingsScope() end,
        setFunction = function(controlOrValue, itemName, itemData)
            local selected = NormalizeSettingsScope(itemData or itemName or controlOrValue)
            RagsToRiches.ScopeSV.settingsScope = selected
            ApplyActiveSettingsScope()
            chat("Settings scope set to " .. selected .. ".")
        end,
        -- Keep Reset to Defaults on the currently selected profile.
        default = GetActiveSettingsScope(),
    })

    ----------------------------------------------------------
    -- Core toggles
    ----------------------------------------------------------
    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Enable RagsToRiches",
        getFunction = function() return RagsToRiches.SV.enabled end,
        setFunction = function(v) RagsToRiches.SV.enabled = v end,
        default = true,
    })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Debug Messages",
        getFunction = function() return RagsToRiches.SV.debug end,
        setFunction = function(v) RagsToRiches.SV.debug = v end,
        default = false,
    })


    ----------------------------------------------------------
    -- Protection
    ----------------------------------------------------------
    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Item Protection (runs first)" })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Protect Mythic Items", getFunction = function() return RagsToRiches.SV.protection.mythic end, setFunction = function(v) RagsToRiches.SV.protection.mythic = v end, default = true })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Protect Legendary Items", getFunction = function() return RagsToRiches.SV.protection.legendary end, setFunction = function(v) RagsToRiches.SV.protection.legendary = v end, default = true })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Protect Researchable Items", tooltip = "Keeps equipment this character can research. Unknown research status is kept. Protected stolen items are laundered and kept.", getFunction = function() return RagsToRiches.SV.protection.researchable end, setFunction = function(v) RagsToRiches.SV.protection.researchable = v end, default = true })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Protect Crafted Items", getFunction = function() return RagsToRiches.SV.protection.crafted end, setFunction = function(v) RagsToRiches.SV.protection.crafted = v end, default = true })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Protect Uncollected Set Pieces", tooltip = "Keeps uncollected set pieces. Unknown collection status is kept. Protected stolen items are laundered and kept.", getFunction = function() return RagsToRiches.SV.protection.uncollectedSet end, setFunction = function(v) RagsToRiches.SV.protection.uncollectedSet = v end, default = true })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Protect Unknown Learnable Items", tooltip = "Keeps unknown learnables before sale rules. Sell All Scribing Scripts is an explicit exception. Turning this off allows enabled recipe, plan and motif sale rules to include unknown items.", getFunction = function() return RagsToRiches.SV.protection.unknownLearnable end, setFunction = function(v) RagsToRiches.SV.protection.unknownLearnable = v end, default = true })

    ----------------------------------------------------------
    -- Backpack warning
    ----------------------------------------------------------
    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Backpack Warning" })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Enable Backpack Warning", getFunction = function() return RagsToRiches.SV.backpack.enabled end, setFunction = function(v) RagsToRiches.SV.backpack.enabled = v CheckBackpackSpace(true) end, default = true })
    settings:AddSetting({ type = LHAS.ST_EDIT, label = "Warn At Spaces Remaining", getFunction = function() return tostring(RagsToRiches.SV.backpack.threshold) end, setFunction = function(v) RagsToRiches.SV.backpack.threshold = math.max(0, tonumber(v) or 10) CheckBackpackSpace(true) end, default = "10" })
    settings:AddSetting({ type = LHAS.ST_EDIT, label = "Repeat Every X Spaces", getFunction = function() return tostring(RagsToRiches.SV.backpack.repeatStep) end, setFunction = function(v) RagsToRiches.SV.backpack.repeatStep = math.max(1, tonumber(v) or 5) end, default = "5" })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Play Warning Sound", getFunction = function() return RagsToRiches.SV.backpack.sound end, setFunction = function(v) RagsToRiches.SV.backpack.sound = v end, default = true })

    AddCategoryHeader("BANKING")

    ----------------------------------------------------------
    -- GOLD
    ----------------------------------------------------------
    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Gold" })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Manage Gold",
        getFunction = function() return RagsToRiches.SV.gold.enabled end,
        setFunction = function(v) RagsToRiches.SV.gold.enabled = v end,
        default = true,
    })

    settings:AddSetting({
        type = LHAS.ST_EDIT,
        label = "Gold Target",
        tooltip = bankTargetTooltip,
        getFunction = function() return tostring(RagsToRiches.SV.gold.target) end,
        setFunction = function(v) RagsToRiches.SV.gold.target = tonumber(v) or 0 end,
        default = "5000",
    })

    ----------------------------------------------------------
    -- ALLIANCE POINTS
    ----------------------------------------------------------
    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Alliance Points" })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Manage AP",
        getFunction = function() return RagsToRiches.SV.ap.enabled end,
        setFunction = function(v) RagsToRiches.SV.ap.enabled = v end,
        default = false,
    })

    settings:AddSetting({
        type = LHAS.ST_EDIT,
        label = "AP Target",
        tooltip = bankTargetTooltip,
        getFunction = function() return tostring(RagsToRiches.SV.ap.target) end,
        setFunction = function(v) RagsToRiches.SV.ap.target = tonumber(v) or 0 end,
        default = "50000",
    })

    ----------------------------------------------------------
    -- TEL VAR STONES
    ----------------------------------------------------------
    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Tel Var Stones" })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Manage Tel Var",
        getFunction = function() return RagsToRiches.SV.telvar.enabled end,
        setFunction = function(v) RagsToRiches.SV.telvar.enabled = v end,
        default = false,
    })

    settings:AddSetting({
        type = LHAS.ST_EDIT,
        label = "Tel Var Target (IC only)",
        tooltip = bankTargetTooltip,
        getFunction = function() return tostring(RagsToRiches.SV.telvar.target) end,
        setFunction = function(v) RagsToRiches.SV.telvar.target = tonumber(v) or 0 end,
        default = "0",
    })

    ----------------------------------------------------------
    -- WRIT VOUCHERS
    ----------------------------------------------------------
    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Writ Vouchers" })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Manage Writ Vouchers",
        getFunction = function() return RagsToRiches.SV.writs.enabled end,
        setFunction = function(v) RagsToRiches.SV.writs.enabled = v end,
        default = false,
    })

    settings:AddSetting({
        type = LHAS.ST_EDIT,
        label = "Writ Target",
        tooltip = bankTargetTooltip,
        getFunction = function() return tostring(RagsToRiches.SV.writs.target) end,
        setFunction = function(v) RagsToRiches.SV.writs.target = tonumber(v) or 0 end,
        default = "0",
    })


    ----------------------------------------------------------
    -- Stock Control
    ----------------------------------------------------------
    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Stock Control (at account bank)" })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Enable Stock Control", getFunction = function() return RagsToRiches.SV.stock.enabled end, setFunction = function(v) RagsToRiches.SV.stock.enabled = v end, default = true })
    settings:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "Lockpick Action",
        tooltip = "Keep touches no lockpicks. Sell manages clean working stock (withdraw 200 below 50 and deposits complete stacks above 399) and always sells stolen lockpicks at fences. Notify does the same and warns when clean banked stock exceeds your reserve. Clean lockpicks are never sold to merchants or laundered.",
        items = {
            { name = "Keep", data = "Keep" },
            { name = "Sell", data = "Sell" },
            { name = "Notify", data = "Notify" },
        },
        getFunction = function() return GetLockpickAction() end,
        setFunction = function(controlOrValue, itemName, itemData)
            RagsToRiches.SV.stock.lockpicks.action = NormalizeLockpickAction(itemData or itemName or controlOrValue)
        end,
        default = "Notify",
    })
    settings:AddSetting({
        type = LHAS.ST_EDIT,
        label = "Clean Lockpick Bank Reserve Stacks",
        tooltip = "Each stack contains 200 lockpicks. In Notify mode, complete clean stacks above this bank reserve trigger guild-store advice. Lockpicks can commonly be listed for 2–8 gold each; RagsToRiches never auto-sells clean lockpicks.",
        getFunction = function() return tostring(RagsToRiches.SV.stock.lockpicks.bankStacks or 20) end,
        setFunction = function(v) RagsToRiches.SV.stock.lockpicks.bankStacks = math.max(0, math.floor(tonumber(v) or 20)) end,
        default = "20",
    })
    settings:AddSetting({ type = LHAS.ST_EDIT, label = "Filled Soul Gem Character Stacks", getFunction = function() return tostring(RagsToRiches.SV.stock.soulGems.characterStacks or 2) end, setFunction = function(v) RagsToRiches.SV.stock.soulGems.characterStacks = math.max(1, math.floor(tonumber(v) or 2)) end, default = "2" })
    settings:AddSetting({ type = LHAS.ST_EDIT, label = "Filled Soul Gem Bank Stacks", getFunction = function() return tostring(RagsToRiches.SV.stock.soulGems.bankStacks or 5) end, setFunction = function(v) RagsToRiches.SV.stock.soulGems.bankStacks = math.max(0, math.floor(tonumber(v) or 5)) end, default = "5" })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Sell Complete Soul Gem Stacks Above Both Reserves", getFunction = function() return RagsToRiches.SV.stock.soulGems.sellExcess ~= false end, setFunction = function(v) RagsToRiches.SV.stock.soulGems.sellExcess = v end, default = true })

    AddCategoryHeader("COMMERCE")

    ----------------------------------------------------------
    -- Merchant
    ----------------------------------------------------------
    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Merchant" })
    settings:AddSetting({ type = LHAS.ST_LABEL, label = "Protections run first. Equipment uses Ornate/Intricate choices, then Weapons/Armour/Enchantments/Jewellery. Keep and Deconstruct prevent merchant sales, including junk items." })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Enable Merchant Automation", getFunction = function() return RagsToRiches.SV.merchant.enabled end, setFunction = function(v) RagsToRiches.SV.merchant.enabled = v end, default = true })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Sell Vendor-Only Items", getFunction = function() return RagsToRiches.SV.merchant.vendorTrash end, setFunction = function(v) RagsToRiches.SV.merchant.vendorTrash = v end, default = true })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Sell All Scribing Scripts", tooltip = "WARNING: When enabled, RagsToRiches will sell ALL scribing scripts at merchants, including scripts this character has not learned. Leave this off on characters that still need to learn scripts.", getFunction = function() return RagsToRiches.SV.merchant.sellScripts == true end, setFunction = function(v) RagsToRiches.SV.merchant.sellScripts = v == true end, default = false })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Sell Green/Blue Companion Equipment", getFunction = function() return RagsToRiches.SV.merchant.companionGear end, setFunction = function(v) RagsToRiches.SV.merchant.companionGear = v end, default = false })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Sell ESO Priority-Sell Items", tooltip = "Automatically sells items ESO explicitly marks with the merchant-purpose flag used for 'Sell to a merchant for gold.' Existing RagsToRiches protection rules still run first.", getFunction = function() return RagsToRiches.SV.merchant.prioritySell end, setFunction = function(v) RagsToRiches.SV.merchant.prioritySell = v end, default = false })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Sell White/Green/Blue Recipes", getFunction = function() return RagsToRiches.SV.merchant.knownRecipes end, setFunction = function(v) RagsToRiches.SV.merchant.knownRecipes = v end, default = false })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Sell White/Green/Blue Motifs/Styles", getFunction = function() return RagsToRiches.SV.merchant.knownMotifs end, setFunction = function(v) RagsToRiches.SV.merchant.knownMotifs = v end, default = false })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Sell White/Green/Blue Furnishing Plans", getFunction = function() return RagsToRiches.SV.merchant.knownFurnishingPlans end, setFunction = function(v) RagsToRiches.SV.merchant.knownFurnishingPlans = v end, default = false })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Sell Basic Potions", tooltip = "Applies after protections and specific category choices. Disabled by default.", getFunction = function() return RagsToRiches.SV.merchant.basicPotions == true end, setFunction = function(v) RagsToRiches.SV.merchant.basicPotions = v == true end, default = false })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Sell Basic Poisons", tooltip = "Applies after protections and specific category choices. Disabled by default.", getFunction = function() return RagsToRiches.SV.merchant.basicPoisons == true end, setFunction = function(v) RagsToRiches.SV.merchant.basicPoisons = v == true end, default = false })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Sell Other White-Quality Items", tooltip = "Applies after protections and specific category choices. Disabled by default.", getFunction = function() return RagsToRiches.SV.merchant.whiteItems == true end, setFunction = function(v) RagsToRiches.SV.merchant.whiteItems = v == true end, default = false })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Sell Other Junk Items", getFunction = function() return RagsToRiches.SV.merchant.sellJunk end, setFunction = function(v) RagsToRiches.SV.merchant.sellJunk = v end, default = true })
    settings:AddSetting({
        type = LHAS.ST_BUTTON,
        label = "Inventory Scan",
        buttonText = "Scan Inventory Now",
        tooltip = "Re-check every item currently in your backpack using the active RagsToRiches merchant rules. Newly recognised sellable items are marked as junk ready for the next merchant visit. This does not sell anything immediately.",
        clickHandler = function()
            if not RagsToRiches.SV.enabled then
                chat("Inventory scan skipped — RagsToRiches is disabled.")
                return
            end
            if not RagsToRiches.SV.merchant.enabled then
                chat("Inventory scan skipped — merchant automation is disabled.")
                return
            end

            local marked = ClassifyMerchantItems()
            CheckBackpackSpace(true)
            if marked > 0 then
                chat(string.format("Inventory scan complete — marked %d new sellable stack%s as junk.", marked, marked == 1 and "" or "s"))
            else
                chat("Inventory scan complete — no new sellable stacks found.")
            end
        end,
    })

    ----------------------------------------------------------
    -- Fence
    ----------------------------------------------------------
    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Fence" })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Enable Fence Automation", getFunction = function() return RagsToRiches.SV.fence.enabled end, setFunction = function(v) RagsToRiches.SV.fence.enabled = v end, default = true })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Fence Preview Only", tooltip = "When enabled, RagsToRiches marks recommended items in the fence Sell and Launder tabs instead of processing them automatically. Deselect anything you want to keep, then use the bulk action on that tab. Stolen containers are not auto-opened in preview mode.", getFunction = function() return RagsToRiches.SV.fence.previewOnly == true end, setFunction = function(v) RagsToRiches.SV.fence.previewOnly = v == true end, default = false })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Open Stolen Containers Before Fence Processing", tooltip = "Opens stolen reward/container boxes first, then processes the stolen contents for laundering or sale. Stops if the backpack is full. Disabled while Fence Preview Only is active.", getFunction = function() return RagsToRiches.SV.fence.openStolenContainers == true end, setFunction = function(v) RagsToRiches.SV.fence.openStolenContainers = v end, default = false })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Prevent Accidental Theft Unless Hidden", tooltip = "Blocks interactions with owned objects while you are visible or detected. Owned interactions are allowed while Hidden or in a stealth state. Does not change ESO's protected game settings.", getFunction = function() return RagsToRiches.SV.fence.preventAccidentalTheftUnlessHidden == true end, setFunction = function(v) RagsToRiches.SV.fence.preventAccidentalTheftUnlessHidden = v == true end, default = false })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Launder Items Needed by Journal Quests", tooltip = "When enabled, stolen items that ESO reports as fulfilling The Covetous Countess or a supported Blackfeather Court item quest are laundered before ordinary fence rules. Every quest in the journal is checked, not only the currently tracked quest.", getFunction = function() return RagsToRiches.SV.fence.launderQuestItems ~= false end, setFunction = function(v) RagsToRiches.SV.fence.launderQuestItems = v ~= false end, default = true })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Launder Tradeable Stolen Items", getFunction = function() return RagsToRiches.SV.fence.launderTradeable end, setFunction = function(v) RagsToRiches.SV.fence.launderTradeable = v end, default = true })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Sell Non-Tradeable Stolen Items", getFunction = function() return RagsToRiches.SV.fence.sellNonTradeable end, setFunction = function(v) RagsToRiches.SV.fence.sellNonTradeable = v end, default = true })

    ----------------------------------------------------------
    -- RagPicker
    ----------------------------------------------------------
    settings:AddSetting({ type = LHAS.ST_SECTION, label = "RagPicker" })
    settings:AddSetting({
        type = LHAS.ST_LABEL,
        label = "|cFFD700Tip:|r Items selected for deconstruction may not be auto-sold. RagsToRiches works best when you deconstruct unwanted equipment before visiting a merchant.",
    })
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Enable Safe Equipment Deconstruction", getFunction = function() return RagsToRiches.SV.deconstruct.enabled end, setFunction = function(v) RagsToRiches.SV.deconstruct.enabled = v end, default = true })
    settings:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "Intricate Equipment",
        tooltip = "Choose what RagsToRiches should do with Intricate-trait equipment. Keep prevents both automatic selling and deconstruction.",
        -- Console LHAS renders dropdown choices from named item tables.
        -- The setter remains tolerant of LHAS callback variants and normalises
        -- the selected table/data/name/index into our canonical action string.
        items = {
            { name = "Keep", data = "Keep" },
            { name = "Deconstruct", data = "Deconstruct" },
            { name = "Sell", data = "Sell" },
        },
        getFunction = function() return GetIntricateAction() end,
        setFunction = function(controlOrValue, itemName, itemData)
            local selected = NormalizeIntricateAction(itemData or itemName or controlOrValue)
            RagsToRiches.SV.deconstruct.intricateAction = selected
            if RagsToRiches.SV.debug then chat("Intricate action set to: " .. selected) end
        end,
        default = "Keep",
    })
    local categoryActionItems = {
        { name = "Keep", data = "Keep" },
        { name = "Deconstruct", data = "Deconstruct" },
        { name = "Sell", data = "Sell" },
    }
    local function AddCategoryActionSetting(label, actionKey)
        settings:AddSetting({
            type = LHAS.ST_DROPDOWN,
            label = label,
            tooltip = "Choose whether this category is kept, selected for deconstruction, or marked for merchant sale. Existing safety protections run first; among eligible items, Ornate and Intricate trait rules take priority over this category choice.",
            items = categoryActionItems,
            getFunction = function()
                return NormalizeCategoryAction(RagsToRiches.SV.deconstruct[actionKey], "Keep")
            end,
            setFunction = function(controlOrValue, itemName, itemData)
                RagsToRiches.SV.deconstruct[actionKey] = NormalizeCategoryAction(
                    itemData or itemName or controlOrValue,
                    "Keep"
                )
            end,
            default = "Deconstruct",
        })
    end
    settings:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "Ornate Equipment",
        tooltip = "Overrides the equipment category after protections. Choose Keep, Deconstruct or Sell.",
        items = categoryActionItems,
        getFunction = function() return NormalizeCategoryAction(RagsToRiches.SV.deconstruct.ornateAction, "Keep") end,
        setFunction = function(controlOrValue, itemName, itemData)
            RagsToRiches.SV.deconstruct.ornateAction = NormalizeCategoryAction(itemData or itemName or controlOrValue, "Keep")
        end,
        default = "Sell",
    })
    AddCategoryActionSetting("Weapons", "weaponAction")
    AddCategoryActionSetting("Armour", "armorAction")
    AddCategoryActionSetting("Enchantments", "enchantAction")
    AddCategoryActionSetting("Jewellery", "jewelryAction")
    settings:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Preview Only (pre-select for review)", tooltip = "Pre-selects RagsToRiches recommendations in ESO's native deconstruction list. Review or deselect items first, then use ESO's normal hold-Square confirmation.", getFunction = function() return RagsToRiches.SV.deconstruct.previewOnly end, setFunction = function(v) RagsToRiches.SV.deconstruct.previewOnly = v end, default = false })

    ----------------------------------------------------------
    -- SugaComa signature and contact
    ----------------------------------------------------------
    settings:AddSetting({
        type = LHAS.ST_SECTION,
        subMenu = false,
        label = "|cFFD700Built on tea, toast and ADHD – tested live on PS5.|r\n" ..
                "|cB427D3Su|c546D6Aga|c889764Co|cDA34CDma|r",
    })
    settings:AddSetting({
        type = LHAS.ST_LABEL,
        label = "Contact",
        tooltip = "Found an error or need to contact me about Rags To Riches?\n\nPlayStation User / PSN: SugaComa\nEmail: eso.addons@rik-sprint.co.uk",
    })
end

--------------------------------------------------------------
-- Initialisation
--------------------------------------------------------------
local function OnLoaded(_, name)
    if name ~= ADDON_NAME then return end

    local defaults = {
        enabled = true,
        debug = false,
        gold   = { enabled = true,  target = 5000  },
        ap     = { enabled = false, target = 50000 },
        telvar = { enabled = false, target = 0     },
        writs  = { enabled = false, target = 0     },
        backpack = { enabled = true, threshold = 10, repeatStep = 5, sound = true },
        protection = { mythic = true, legendary = true, researchable = true, crafted = true, uncollectedSet = true, unknownLearnable = true },
        merchant = { enabled = true, ornate = true, vendorTrash = true, sellScripts = false, companionGear = false, prioritySell = false, nonSetEquipment = false, knownRecipes = false, knownMotifs = false, knownFurnishingPlans = false, sellJunk = true, basicPotions = false, basicPoisons = false, whiteItems = false },
        stock = {
            enabled = true,
            lockpicks = { enabled = true, action = "Notify", low = 50, carryMax = 399, bankStacks = 20, stackSize = 200 },
            soulGems = { enabled = true, low = 50, characterStacks = 2, bankStacks = 5, stackSize = 200, sellExcess = true },
        },
        fence = { enabled = true, previewOnly = false, openStolenContainers = false, preventAccidentalTheftUnlessHidden = false, launderQuestItems = true, launderTradeable = true, sellNonTradeable = true },
        deconstruct = {
            enabled = true,
            previewOnly = false,
            armor = true,
            weapons = true,
            jewelry = true,
            intricateAction = "Keep",
            ornateAction = "Sell",
            weaponAction = "Deconstruct",
            armorAction = "Deconstruct",
            enchantAction = "Deconstruct",
            jewelryAction = "Deconstruct",
        },
    }

    RagsToRiches = RagsToRiches or {}

    -- The scope selector itself is always account-wide so the addon knows which
    -- profile to activate before any feature reads its settings. Existing users
    -- remain on the account-wide profile by default.
    RagsToRiches.ScopeSV = ZO_SavedVars:NewAccountWide("RagsToRiches_ScopeSV", 1, nil, { settingsScope = SETTINGS_SCOPE_ACCOUNT })
    RagsToRiches.AccountSV = ZO_SavedVars:NewAccountWide("RagsToRiches_SV", 3, nil, defaults)
    RagsToRiches.CharacterSV = ZO_SavedVars:NewCharacterIdSettings("RagsToRiches_CharacterSV", 3, nil, defaults)

    local function MigrateSettingsProfile(sv)
        if not sv then return end
        if not sv.schemaVersion or sv.schemaVersion < 139 then
            sv.deconstruct = sv.deconstruct or defaults.deconstruct
            if sv.deconstruct.enabled == nil then sv.deconstruct.enabled = true end
            if sv.deconstruct.previewOnly == nil then sv.deconstruct.previewOnly = false end
            sv.stock = sv.stock or defaults.stock
            sv.protection = sv.protection or defaults.protection
            if sv.protection.researchable == nil then sv.protection.researchable = true end
            if sv.protection.uncollectedSet == nil then sv.protection.uncollectedSet = true end
            sv.stock.soulGems = sv.stock.soulGems or defaults.stock.soulGems
            local oldReserve = tonumber(sv.stock.soulGems.reserve)
            if sv.stock.soulGems.characterStacks == nil then
                sv.stock.soulGems.characterStacks = oldReserve and math.max(1, math.floor(oldReserve / 200)) or 2
            end
            if sv.stock.soulGems.bankStacks == nil then sv.stock.soulGems.bankStacks = 5 end
            if sv.stock.soulGems.sellExcess == nil then sv.stock.soulGems.sellExcess = true end
            sv.merchant = sv.merchant or defaults.merchant
            if sv.merchant.companionGear == nil then sv.merchant.companionGear = false end
            if sv.merchant.prioritySell == nil then
                -- Preserve an existing opt-in to the old trophy rule; otherwise stay safely off.
                sv.merchant.prioritySell = sv.merchant.achievementTrophies == true
            end
            -- The old known-script toggle is intentionally not promoted to Sell All Scripts.
            -- The new option starts safely disabled because it can also sell unknown scripts.
            if sv.merchant.sellScripts == nil then sv.merchant.sellScripts = false end
            sv.deconstruct = sv.deconstruct or defaults.deconstruct
            if sv.deconstruct.intricateAction == nil then sv.deconstruct.intricateAction = "Keep" end
            sv.deconstruct.intricateAction = NormalizeIntricateAction(sv.deconstruct.intricateAction)
            sv.fence = sv.fence or defaults.fence
            if sv.fence.previewOnly == nil then sv.fence.previewOnly = false end
            if sv.fence.openStolenContainers == nil then sv.fence.openStolenContainers = false end
            if sv.fence.preventAccidentalTheftUnlessHidden == nil then sv.fence.preventAccidentalTheftUnlessHidden = false end
            if sv.merchant.nonSetEquipment == nil then sv.merchant.nonSetEquipment = false end
            if sv.merchant.knownRecipes == nil then sv.merchant.knownRecipes = false end
            if sv.merchant.knownMotifs == nil then sv.merchant.knownMotifs = false end
            if sv.merchant.knownFurnishingPlans == nil then sv.merchant.knownFurnishingPlans = false end
            sv.schemaVersion = 139
        end

        if not sv.schemaVersion or sv.schemaVersion < 140 then
            sv.stock = sv.stock or defaults.stock
            sv.stock.lockpicks = sv.stock.lockpicks or defaults.stock.lockpicks
            local lockRule = sv.stock.lockpicks
            if lockRule.enabled == nil then lockRule.enabled = true end
            if lockRule.action == nil then lockRule.action = "Notify" end
            lockRule.action = NormalizeLockpickAction(lockRule.action)
            if lockRule.low == nil then lockRule.low = 50 end
            if lockRule.carryMax == nil then lockRule.carryMax = 399 end
            if lockRule.bankStacks == nil then lockRule.bankStacks = 20 end
            if lockRule.stackSize == nil then lockRule.stackSize = 200 end
            sv.schemaVersion = 140
        end

        if not sv.schemaVersion or sv.schemaVersion < 141 then
            sv.deconstruct = sv.deconstruct or defaults.deconstruct
            local deconstruct = sv.deconstruct

            if deconstruct.weaponAction == nil then
                deconstruct.weaponAction = deconstruct.weapons == false and "Keep" or "Deconstruct"
            end
            if deconstruct.armorAction == nil then
                deconstruct.armorAction = deconstruct.armor == false and "Keep" or "Deconstruct"
            end
            if deconstruct.enchantAction == nil then
                -- Glyphs previously followed the armour include switch.
                deconstruct.enchantAction = deconstruct.armor == false and "Keep" or "Deconstruct"
            end
            if deconstruct.jewelryAction == nil then
                deconstruct.jewelryAction = deconstruct.jewelry == false and "Keep" or "Deconstruct"
            end

            deconstruct.weaponAction = NormalizeCategoryAction(deconstruct.weaponAction, "Keep")
            deconstruct.armorAction = NormalizeCategoryAction(deconstruct.armorAction, "Keep")
            deconstruct.enchantAction = NormalizeCategoryAction(deconstruct.enchantAction, "Keep")
            deconstruct.jewelryAction = NormalizeCategoryAction(deconstruct.jewelryAction, "Keep")

            sv.fence = sv.fence or defaults.fence
            if sv.fence.launderQuestItems == nil then sv.fence.launderQuestItems = true end
            sv.schemaVersion = 141
        end
        if not sv.schemaVersion or sv.schemaVersion < 142 then
            -- Old releases installed unsafe false defaults. Re-enable once on upgrade;
            -- choices made after this migration are preserved on subsequent loads.
            sv.protection = sv.protection or {}
            sv.protection.researchable = true
            sv.protection.uncollectedSet = true
            sv.deconstruct.ornateAction = sv.merchant.ornate == false and "Keep" or "Sell"
            sv.schemaVersion = 142
            chat("Safety update: research and uncollected-set protection enabled for this profile. Review Protections to customise.")
        end
    end

    MigrateSettingsProfile(RagsToRiches.AccountSV)
    MigrateSettingsProfile(RagsToRiches.CharacterSV)
    ApplyActiveSettingsScope()

    EM:RegisterForEvent("RTR_BankOpen",  EVENT_OPEN_BANK,  OnBankOpened)
    EM:RegisterForEvent("RTR_BankClose", EVENT_CLOSE_BANK, OnBankClosed)
    EM:RegisterForEvent("RTR_Inventory", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySlotUpdate)
    EM:RegisterForEvent("RTR_ContainerLoot", EVENT_LOOT_UPDATED, OnContainerLootUpdated)
    EM:RegisterForEvent("RTR_Store", EVENT_OPEN_STORE, ProcessMerchant)
    EM:RegisterForEvent("RTR_Fence", EVENT_OPEN_FENCE, ProcessFence)
    EM:RegisterForEvent("RTR_Crafting", EVENT_CRAFTING_STATION_INTERACT, OnCraftingStation)
    EM:RegisterForEvent("RTR_CraftingEnd", EVENT_END_CRAFTING_STATION_INTERACT, OnEndCraftingStation)
    zo_callLater(InstallDeconstructionHooks, 1000)
    zo_callLater(InstallFencePreviewHooks, 1000)

    CreateSettings()
    InstallAccidentalTheftProtection()
    zo_callLater(function() CheckBackpackSpace(false) end, 1000)

    chat("RagsToRiches v1.5.0-test2 loaded.")
end

EM:RegisterForEvent("RTR_Loaded", EVENT_ADD_ON_LOADED, OnLoaded)
