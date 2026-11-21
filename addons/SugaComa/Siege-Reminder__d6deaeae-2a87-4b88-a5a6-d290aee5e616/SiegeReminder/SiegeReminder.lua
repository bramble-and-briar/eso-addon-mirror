--------------------------------------------------------------
-- SiegeReminder.lua — SiegeMaster v2.1.7
-- Author: SugaComa
--------------------------------------------------------------
local ADDON_NAME = "SiegeReminder"
local EM = EVENT_MANAGER
local Framework = SiegeReminder_Framework
local catalog
local apCatalog
local RefreshItemSettings
local CHECK_INTERVAL_MS = 120000 -- 2 min recheck while low

local isAtSiegeMerchant = false
local isLowOnSiege = false
local remindTimerActive = false
local bankSessionRunning = false

--------------------------------------------------------------
-- Helpers
--------------------------------------------------------------
local function chat(msg)
	if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
		CHAT_SYSTEM:AddMessage("|cFFD700[SiegeMaster]|r " .. msg)
	else
		d("|cFFD700[SiegeMaster]|r " .. msg)
	end
end

local function debugBank(msg)
	if SiegeReminder.SV and SiegeReminder.SV.debug then
		chat("[Bank] " .. tostring(msg))
	end
end

--------------------------------------------------------------
-- Notifications (Chat / Alert / Full Screen)
--------------------------------------------------------------
local function Notify(msg, fullScreenText)
	local mode = (SiegeReminder.SV and SiegeReminder.SV.reminderType) or "Chat"
	local sound = SOUNDS.GENERAL_ALERT_ERROR
	local prefix = "|cFFD700[SiegeMaster]|r "

	if mode == "Chat" then
		chat(msg)

	elseif mode == "Alert" then
		local CSA = CENTER_SCREEN_ANNOUNCE
		if CSA and CSA.CreateMessageParams then
			local p = CSA:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT, sound)
			p:SetText(prefix .. tostring(msg))
			p:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_CHAMPION_POINT_GAINED)
			CSA:DisplayMessage(p)
		else
			ZO_Alert(UI_ALERT_CATEGORY_ALERT, sound, prefix .. tostring(msg))
		end

	elseif mode == "Full Screen" then
		local CSA = CENTER_SCREEN_ANNOUNCE
		if CSA and CSA.CreateMessageParams then
			local p = CSA:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, sound)
			p:SetText(fullScreenText)
			p:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_CHAMPION_POINT_GAINED)
			CSA:DisplayMessage(p)
		else
			ZO_Alert(UI_ALERT_CATEGORY_ALERT, sound, prefix .. tostring(msg))
		end
	end
end



--------------------------------------------------------------
-- Safe AVA Detection
--------------------------------------------------------------
local function IsInAvA()
	-- Always check for the function and handle nil gracefully
	local inAvA = false

	if IsInAvAZone and IsInAvAZone() then
		inAvA = true
	elseif IsPlayerInAvAWorld and IsPlayerInAvAWorld() then
		inAvA = true
	elseif GetCurrentSubZoneName and type(GetCurrentSubZoneName) == "function" then
		local zone = GetCurrentSubZoneName()
		if zone and type(zone) == "string" and zone:lower():find("imperial city") then
			inAvA = true
		end
	end

	return inAvA
end

local function IsInCyrodiil()
	return IsInAvA()
end


--------------------------------------------------------------
-- Siege Inventory
--------------------------------------------------------------
local function IsSupplyType(itemType, specializedType)
    return itemType == ITEMTYPE_SIEGE or itemType == ITEMTYPE_AVA_REPAIR
        or (itemType == ITEMTYPE_RECALL_STONE and specializedType == SPECIALIZED_ITEMTYPE_RECALL_STONE_KEEP)
end

local SIEGE_SPECIALIZATIONS = {
    [SPECIALIZED_ITEMTYPE_SIEGE_BALLISTA] = true,
    [SPECIALIZED_ITEMTYPE_SIEGE_CATAPULT] = true,
    [SPECIALIZED_ITEMTYPE_SIEGE_GRAVEYARD] = true,
    [SPECIALIZED_ITEMTYPE_SIEGE_LANCER] = true,
    [SPECIALIZED_ITEMTYPE_SIEGE_MONSTER] = true,
    [SPECIALIZED_ITEMTYPE_SIEGE_OIL] = true,
    [SPECIALIZED_ITEMTYPE_SIEGE_RAM] = true,
    [SPECIALIZED_ITEMTYPE_SIEGE_TREBUCHET] = true,
    [SPECIALIZED_ITEMTYPE_SIEGE_UNIVERSAL] = true,
}

local function IsSupplyLink(link)
    if not link or link == "" then return false end
    local itemType, specializedType = GetItemLinkItemType(link)
    if IsSupplyType(itemType, specializedType)
        or specializedType == SPECIALIZED_ITEMTYPE_RECALL_STONE_KEEP
        or SIEGE_SPECIALIZATIONS[specializedType] then return true end
    local siegeType = GetItemLinkSiegeType(link)
    return siegeType ~= nil and siegeType ~= SIEGE_TYPE_NONE
end

local function IsSiegeItem(bagId, slotIndex)
    local itemType, specializedType = GetItemType(bagId, slotIndex)
    if IsSupplyType(itemType, specializedType)
        or specializedType == SPECIALIZED_ITEMTYPE_RECALL_STONE_KEEP
        or SIEGE_SPECIALIZATIONS[specializedType] then return true end
    -- Use the same link metadata ESO's tooltips use for siege classification.
    return IsSupplyLink(GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT))
end

-- Ownership, not vendor availability, determines which supplies can be managed.
-- The existing account-wide catalog stays compatible with saved vendor data.
local function DiscoverSupplies(bags)
    local changed, found = false, 0
    for _, bagId in ipairs(bags) do
        for slot = 0, GetBagSize(bagId) - 1 do
            if IsSiegeItem(bagId, slot) then
                found = found + 1
                local id = tostring(GetItemId(bagId, slot))
                local name = GetItemName(bagId, slot)
                if id ~= "0" and name and name ~= "" and catalog[id] ~= name then
                    catalog[id] = name
                    changed = true
                end
            end
        end
    end
    if changed and RefreshItemSettings then RefreshItemSettings() end
    return found
end

local function GetFreeSlotInBag(bagId)
	if FindFirstEmptySlotInBag then
		return FindFirstEmptySlotInBag(bagId)
	end
	for slot = 0, GetBagSize(bagId) - 1 do
		local itemType = GetItemType(bagId, slot)
		if itemType == ITEMTYPE_NONE then
			return slot
		end
	end
	return nil
end

local function CountCarried()
	local counts = {}
	for _, bagId in ipairs({ BAG_BACKPACK, BAG_WORN }) do
		for slot = 0, GetBagSize(bagId) - 1 do
			if IsSiegeItem(bagId, slot) then
				local id = tostring(GetItemId(bagId, slot))
				counts[id] = (counts[id] or 0) + GetSlotStackSize(bagId, slot)
			end
		end
	end
	return counts
end

local function BuildSiegeSlotsByItem(bagId)
	local slotsByItem = {}
	for slot = 0, GetBagSize(bagId) - 1 do
		if IsSiegeItem(bagId, slot) and not IsItemPlayerLocked(bagId, slot)
            and not IsItemStolen(bagId, slot)
            and not (bagId == BAG_BACKPACK and GetItemBindType(bagId, slot) == BIND_TYPE_ON_PICKUP_BACKPACK) then
			local id = tostring(GetItemId(bagId, slot))
			if catalog[id] then
				local slots = slotsByItem[id] or {}
				slotsByItem[id] = slots
				slots[#slots + 1] = { slot = slot, stack = GetSlotStackSize(bagId, slot) }
			end
		end
	end
	for _, slots in pairs(slotsByItem) do
		table.sort(slots, function(a, b) return a.stack > b.stack end)
	end
	return slotsByItem
end

local function GetItemSettings(id)
	local items = SiegeReminder.SV.items
	if not items[id] then
		items[id] = { enabled = false, buyWithAP = false, minCarry = 0, maxCarry = 3 }
	end
	return items[id]
end

-- Inspect the live offer because the same item may have separate AP and gold entries.
local function GetAPOffer(index)
	local _, name, stack, gold, _, canBuy, _, _, _, currency1, cost1,
		currency2, cost2, entryType = GetStoreEntryInfo(index)
	if entryType ~= STORE_ENTRY_TYPE_ITEM or gold ~= 0 or not stack or stack < 1
		or not name or name == "" then return end
	if not cost1 or not cost2 or cost1 < 0 or cost2 < 0 then return end
	if (cost1 > 0 and currency1 ~= CURT_ALLIANCE_POINTS)
		or (cost2 > 0 and currency2 ~= CURT_ALLIANCE_POINTS) or cost1 + cost2 == 0 then return end

	local link = GetStoreItemLink(index, LINK_STYLE_DEFAULT)
	if not link or link == "" then return end
	if not IsSupplyLink(link) then return end
	local id = GetItemLinkItemId(link)
	if not id or id == 0 then return end
	return tostring(id), name, stack, cost1 + cost2, canBuy
end

local storeSession
-- Keep an in-flight purchase across a quick vendor close and reopen.
local pendingPurchase
local purchaseUpdate = ADDON_NAME .. "_APRestock"

local function StopPurchases()
	EM:UnregisterForUpdate(purchaseUpdate)
end

local function RunRestock()
	if not storeSession or not SiegeReminder.SV.automaticAPRestock
		or GetInteractionType() ~= INTERACTION_VENDOR or not IsInAvA() then
		StopPurchases()
		return
	end

	local counts = CountCarried()
	local ap = GetCurrencyAmount(CURT_ALLIANCE_POINTS, CURRENCY_LOCATION_CHARACTER)
	local pending = pendingPurchase
	if pending then
		if (counts[pending.id] or 0) >= pending.expectedCount and ap <= pending.expectedAP then
			pendingPurchase = nil
		elseif GetFrameTimeMilliseconds() >= pending.deadline then
			pendingPurchase = nil
			StopPurchases()
			chat("AP restock stopped while waiting for a purchase. Check your stock before reopening the vendor.")
			return
		else
			return
		end
	end

	for index = 1, GetNumStoreItems() do
		local id, _, stack, cost, canBuy = GetAPOffer(index)
		local cfg = id and SiegeReminder.SV.items[id]
		if canBuy and cfg and cfg.buyWithAP and not storeSession.attempted[id] then
			local have = counts[id] or 0
			-- The store quantity counts bundles. Carry Max counts individual items.
			local quantity = math.min(math.floor((cfg.maxCarry - have) / stack),
				math.floor(ap / (cost * stack)), GetStoreEntryMaxBuyable(index), MAX_STORE_WINDOW_STACK_QUANTITY)
			if quantity > 0 then
				storeSession.attempted[id] = true
				pendingPurchase = {
					id = id, expectedCount = have + quantity * stack, expectedAP = ap - quantity * cost * stack,
					deadline = GetFrameTimeMilliseconds() + 5000,
				}
				BuyStoreItem(index, quantity)
				return
			end
		end
	end
	StopPurchases()
end

local function OnStoreClose()
	StopPurchases()
	storeSession = nil
	isAtSiegeMerchant = false
end

local function OnStoreOpen()
	OnStoreClose()
	if not IsInAvA() then return end
	local session = { attempted = {} }
	storeSession = session
	zo_callLater(function()
		if storeSession ~= session or GetInteractionType() ~= INTERACTION_VENDOR then return end
		local changed = false
		for index = 1, GetNumStoreItems() do
			local id, name = GetAPOffer(index)
			if id then
				isAtSiegeMerchant = true
                if not apCatalog[id] then apCatalog[id] = true; changed = true end
				if catalog[id] ~= name then
					catalog[id] = name
					changed = true
				end
			end
		end
		if changed then RefreshItemSettings() end
		if isAtSiegeMerchant and SiegeReminder.SV.automaticAPRestock then
			if IsProtectedFunction and IsProtectedFunction("BuyStoreItem") then
				chat("Automatic AP restock is unavailable on this client.")
				return
			end
			EM:RegisterForUpdate(purchaseUpdate, 350, RunRestock)
		end
	end, 250)
end

local function GetSiegeInventory()
	local total, list = 0, {}
	for _, bagId in ipairs({ BAG_BACKPACK, BAG_WORN }) do
		for slot = 0, GetBagSize(bagId) - 1 do
			if IsSiegeItem(bagId, slot) then
				local itemName = GetItemName(bagId, slot)
				local stack = GetSlotStackSize(bagId, slot)
				total = total + stack
				list[itemName] = (list[itemName] or 0) + stack
			end
		end
	end
	return total, list
end

local function PrintSiegeBreakdown()
	if not SiegeReminder.SV.debugMode then return end
	local total, list = GetSiegeInventory()
	chat(string.format("Debug: Total siege items = %d", total))
	for name, count in pairs(list) do
		chat(string.format("  %s: %d", name, count))
	end
end

--------------------------------------------------------------
-- Bank Move Queue
--------------------------------------------------------------
local function QueueMove(queue, bagFrom, slotFrom, bagTo, slotTo, qty)
	queue[#queue + 1] = {
		bagFrom = bagFrom,
		slotFrom = slotFrom,
		bagTo = bagTo,
		slotTo = slotTo,
		qty = qty,
        itemId = GetItemId(bagFrom, slotFrom),
        uniqueId = tostring(GetItemUniqueId(bagFrom, slotFrom)),
	}
end

local function SafeRequestMoveItem(bagFrom, slotFrom, bagTo, slotTo, qty)
	if CallSecureProtected then
		CallSecureProtected("RequestMoveItem", bagFrom, slotFrom, bagTo, slotTo, qty)
	elseif RequestMoveItem then
		RequestMoveItem(bagFrom, slotFrom, bagTo, slotTo, qty)
	end
end

local function RunQueue(handleName, queue, delayMs, onDone)
    if not queue or #queue == 0 then
        if onDone then onDone(0, nil) end
        return
    end
    local moved, index, pending = 0, 1, nil
    local function Done(reason)
        EM:UnregisterForUpdate(handleName)
        if onDone then onDone(moved, reason) end
    end
    EM:UnregisterForUpdate(handleName)
    EM:RegisterForUpdate(handleName, tonumber(delayMs) or 700, function()
        if not bankSessionRunning then Done("closed"); return end
        if pending then
            local same = tostring(GetItemUniqueId(pending.bagFrom, pending.slotFrom)) == pending.uniqueId
            local remaining = same and GetSlotStackSize(pending.bagFrom, pending.slotFrom) or 0
            local arrived = GetItemId(pending.bagTo, pending.targetSlot) == pending.itemId
                and GetSlotStackSize(pending.bagTo, pending.targetSlot) >= pending.qty
            if remaining <= pending.before - pending.qty and arrived then
                moved = moved + pending.qty
                pending = nil
                index = index + 1
            elseif GetFrameTimeMilliseconds() >= pending.deadline then
                chat("Bank transfer was not confirmed. Check your supplies and reopen the bank to retry.")
                Done("unconfirmed")
                return
            else return end
        end
        local move = queue[index]
        if not move then Done(); return end
        -- Do not move an unrelated item if inventory slots changed since planning.
        if GetItemId(move.bagFrom, move.slotFrom) ~= move.itemId
            or tostring(GetItemUniqueId(move.bagFrom, move.slotFrom)) ~= move.uniqueId
            or GetSlotStackSize(move.bagFrom, move.slotFrom) < move.qty then
            debugBank("Source changed; skipped queued item.")
            index = index + 1
            return
        end
        if IsItemPlayerLocked(move.bagFrom, move.slotFrom) or IsItemStolen(move.bagFrom, move.slotFrom)
            or (move.bagTo == BAG_BANK and GetItemBindType(move.bagFrom, move.slotFrom) == BIND_TYPE_ON_PICKUP_BACKPACK) then
            debugBank("Skipped locked, stolen or character-bound supply.")
            index = index + 1
            return
        end
        local slotTo = GetFreeSlotInBag(move.bagTo)
        if slotTo == nil and move.bagTo == BAG_BANK and IsESOPlusSubscriber() then
            move.bagTo = BAG_SUBSCRIBER_BANK
            slotTo = GetFreeSlotInBag(move.bagTo)
        end
        if slotTo == nil then Done("full"); return end
        move.targetSlot = slotTo
        move.before = GetSlotStackSize(move.bagFrom, move.slotFrom)
        move.deadline = GetFrameTimeMilliseconds() + 5000
        pending = move
        SafeRequestMoveItem(move.bagFrom, move.slotFrom, move.bagTo, slotTo, move.qty)
    end)
end

--------------------------------------------------------------
-- Bank Automation
--------------------------------------------------------------
local function WithdrawToCarryMax()
	local carried = CountCarried()
	local bankSlots = BuildSiegeSlotsByItem(BAG_BANK)
    for _, slots in pairs(bankSlots) do
        for _, entry in ipairs(slots) do entry.bag = BAG_BANK end
    end
    for id, slots in pairs(BuildSiegeSlotsByItem(BAG_SUBSCRIBER_BANK)) do
        bankSlots[id] = bankSlots[id] or {}
        for _, entry in ipairs(slots) do
            entry.bag = BAG_SUBSCRIBER_BANK
            bankSlots[id][#bankSlots[id] + 1] = entry
        end
    end
	local queue = {}

	for id, cfg in pairs(SiegeReminder.SV.items) do
		if cfg and cfg.enabled then
			local maxCarry = tonumber(cfg.maxCarry) or 0
			if maxCarry > 0 then
				local have = carried[id] or 0
				local need = maxCarry - have
				if need > 0 then
					local slots = bankSlots[id] or {}
					for i = 1, #slots do
						if need <= 0 then break end
						local entry = slots[i]
						local qty = math.min(entry.stack, need)
						QueueMove(queue, entry.bag, entry.slot, BAG_BACKPACK, nil, qty)
						need = need - qty
					end
				end
			end
		end
	end

	RunQueue("SIEGE_BANK_WITHDRAW", queue, SiegeReminder.SV.bankMoveDelayMs, function(moved, reason)
		if moved > 0 then
			Notify("Topped up siege from bank (Cyrodiil).", "Siege restocked")
		end
		if reason == "full" then
			Notify("Backpack full. Siege withdraw stopped.", "Backpack full")
		end
	end)
end

local function DepositAllSiege()
	if not SiegeReminder.SV or SiegeReminder.SV.depositAllOutsideAvA ~= true then return end
	local queue = {}
	local slotsByItem = BuildSiegeSlotsByItem(BAG_BACKPACK)
	for _, slots in pairs(slotsByItem) do
		for i = 1, #slots do
			local entry = slots[i]
			QueueMove(queue, BAG_BACKPACK, entry.slot, BAG_BANK, nil, entry.stack)
		end
	end

	RunQueue("SIEGE_BANK_DEPOSIT", queue, SiegeReminder.SV.bankMoveDelayMs, function(moved, reason)
		if moved > 0 then
			Notify("Deposited siege supplies to bank (outside Cyrodiil).", "Siege banked")
		end
		if reason == "full" then
			Notify("Bank full. Siege deposit stopped.", "Bank full")
		end
	end)
end

local function OnBankOpened(_, bag)
    if bag ~= BAG_BANK and bag ~= BAG_SUBSCRIBER_BANK then return end
    if bankSessionRunning then return end
    bankSessionRunning = true
    debugBank("Bank opened. Discovering supplies.")
    zo_callLater(function()
        if not bankSessionRunning then return end
        DiscoverSupplies({ BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK })
        if not SiegeReminder.SV or SiegeReminder.SV.enabledBankAutomation ~= true then return end
        if IsInCyrodiil() then WithdrawToCarryMax() else DepositAllSiege() end
    end, 250)
end

local function OnBankClosed()
	if not bankSessionRunning then return end
	bankSessionRunning = false
	EM:UnregisterForUpdate("SIEGE_BANK_WITHDRAW")
	EM:UnregisterForUpdate("SIEGE_BANK_DEPOSIT")
	debugBank("Bank closed. Queue cleared.")
end

--------------------------------------------------------------
-- Core Check Logic
--------------------------------------------------------------
local function GetLowSiegeList()
	local counts = CountCarried()
	local lowList = {}
	for id, cfg in pairs(SiegeReminder.SV.items) do
		local have = counts[id] or 0
		if catalog[id] and cfg.enabled and have < cfg.minCarry then
			lowList[#lowList + 1] = string.format("%s (%d/%d)", catalog[id], have, cfg.minCarry)
		end
	end
	table.sort(lowList)
	return lowList
end

local function CheckSiegeStock()
	if not IsInAvA() then return end
	local lowDetected = #GetLowSiegeList() > 0

	if lowDetected then
		if not isLowOnSiege then
			Notify(" You are running low on siege supplies — restock before heading out!", "Low siege supplies")
			isLowOnSiege = true
		end
	else
		if isLowOnSiege then
			chat(" All siege stock replenished!")
		end
		isLowOnSiege = false
	end
end

--------------------------------------------------------------
-- Continuous Reminder Loop
--------------------------------------------------------------
local function StartReminderLoop()
	if remindTimerActive then return end
	remindTimerActive = true

	local function Loop()
		if not IsInAvA() then
			remindTimerActive = false
			return
		end

		CheckSiegeStock()

		if isLowOnSiege and not isAtSiegeMerchant then
			Notify(" You are still running low on siege — visit a merchant to restock!", "Restock siege supplies")
		end

		if not isLowOnSiege then
			remindTimerActive = false
			if SiegeReminder.SV.debugMode then
				chat("All siege levels OK — reminder loop stopped.")
			end
			return
		end

		zo_callLater(Loop, CHECK_INTERVAL_MS)
	end

	zo_callLater(Loop, CHECK_INTERVAL_MS)
end

--------------------------------------------------------------
-- OnPlayerActivated (quiet but informative)
--------------------------------------------------------------
local function OnPlayerActivated()
    DiscoverSupplies({ BAG_BACKPACK, BAG_WORN })
    zo_callLater(function() DiscoverSupplies({ BAG_BACKPACK, BAG_WORN }) end, 2000)
	if not IsInAvA() then return end
	zo_callLater(function()
		CheckSiegeStock()

		-- gather shortages
		local lowList = GetLowSiegeList()
		if #lowList > 0 then
			local msg = "You are running low on siege: " .. table.concat(lowList, ", ") .. "."
			chat(msg)
		elseif SiegeReminder.SV.debugMode then
			local total = select(1, GetSiegeInventory())
			chat(string.format("Debug: Ready check — carrying |cFFFFFF%d|r siege items.", total))
			PrintSiegeBreakdown()
		end

		StartReminderLoop()
	end, 2000)
end

local function OnZoneChanged()
	if IsInAvA() then
		zo_callLater(function()
			CheckSiegeStock()
			StartReminderLoop()
		end, 2000)
	end
end

local function OnInventoryUpdate(_, bagId)
    if bagId == BAG_BACKPACK or bagId == BAG_WORN
        or (bankSessionRunning and (bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK)) then
        DiscoverSupplies({ bagId })
    end
	if bagId ~= BAG_BACKPACK and bagId ~= BAG_WORN then return end
	CheckSiegeStock()
	if isLowOnSiege then StartReminderLoop() end
end

--------------------------------------------------------------
-- Slash Commands
--------------------------------------------------------------
local function ToggleDebug()
	SiegeReminder.SV.debugMode = not SiegeReminder.SV.debugMode
	if SiegeReminder.SV.debugMode then
		chat("Debug mode |c00FF00ENABLED|r — siege details will print.")
	else
		chat("Debug mode |cFF0000DISABLED|r.")
	end
end

local function RescanSupplies()
    local bags = { BAG_BACKPACK, BAG_WORN }
    if bankSessionRunning then
        bags[#bags + 1] = BAG_BANK
        bags[#bags + 1] = BAG_SUBSCRIBER_BANK
    end
    local found = DiscoverSupplies(bags)
    -- Rebuild even if catalog names haven't changed: this repairs a stale menu.
    if RefreshItemSettings then RefreshItemSettings() end
    chat(string.format("v%s: rescan recognised %d supply stacks. Bank scan: %s. Reopen Carry Levels by Item.",
        Framework.version, found, bankSessionRunning and "included" or "open your bank to include it"))
end

local function DiagnoseSupplies()
    RescanSupplies()
    local bags = { BAG_BACKPACK, BAG_WORN }
    if bankSessionRunning then bags[#bags + 1] = BAG_BANK; bags[#bags + 1] = BAG_SUBSCRIBER_BANK end
    local printed = 0
    for _, bag in ipairs(bags) do
        for slot = 0, GetBagSize(bag) - 1 do
            local name = GetItemName(bag, slot) or ""
            local lower = string.lower(name)
            -- Names only select diagnostic output; they never authorise transfers.
            if IsSiegeItem(bag, slot) or lower:find("ballista", 1, true) or lower:find("lancer", 1, true)
                or lower:find("recall", 1, true) or lower:find("trebuchet", 1, true)
                or lower:find("catapult", 1, true) or lower:find("forward camp", 1, true) then
                local t, st = GetItemType(bag, slot)
                local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
                local lt, lst = GetItemLinkItemType(link)
                chat(string.format("%s id=%s bag=%s slot=%d count=%d type=%s/%s link=%s/%s siege=%s tracked=%s locked=%s bind=%s",
                    name, tostring(GetItemId(bag, slot)), tostring(bag), slot, GetSlotStackSize(bag, slot),
                    tostring(t), tostring(st), tostring(lt), tostring(lst), tostring(GetItemLinkSiegeType(link)),
                    tostring(IsSiegeItem(bag, slot)), tostring(IsItemPlayerLocked(bag, slot)), tostring(GetItemBindType(bag, slot))))
                printed = printed + 1
                if printed >= 60 then chat("Diagnostic output limited to 60 stacks."); return end
            end
        end
    end
end

local function ManualCheck()
	CheckSiegeStock()
end

SLASH_COMMANDS["/sgrdebug"] = ToggleDebug
SLASH_COMMANDS["/sgrcheck"] = ManualCheck
SLASH_COMMANDS["/sgrscan"] = RescanSupplies
SLASH_COMMANDS["/sgrdiagnose"] = DiagnoseSupplies


--------------------------------------------------------------
-- LHAS Menu
--------------------------------------------------------------
local function CreateSettingsMenu()
	if not LibHarvensAddonSettings then return end
	local LHAS = LibHarvensAddonSettings
	local options = { allowDefaults = true, allowRefresh = true }
	local settings = LHAS:AddAddon(Framework.displayName, options)
	if not settings then return end
	Framework:AddProfileControls(settings)

    settings:AddSetting({
        type = LHAS.ST_BUTTON, label = "Rescan Supplies",
        tooltip = "Discover owned siege and Keep Recall Stones again. Open your personal bank first to include banked supplies. Does not transfer items.",
        clickHandler = RescanSupplies,
    })
    settings:AddSetting({
        type = LHAS.ST_BUTTON, label = "Print Supply Diagnostics",
        tooltip = "Print recognised supplies and their item classifications to chat, including known siege names that were not recognised. Does not transfer items.",
        clickHandler = DiagnoseSupplies,
    })

	settings:AddSetting({
		type = LHAS.ST_CHECKBOX,
		label = "Enable Debug Mode",
		tooltip = "Print siege inventory breakdowns in chat.",
		default = false,
		getFunction = function() return SiegeReminder.SV.debugMode end,
		setFunction = function(val) SiegeReminder.SV.debugMode = val end,
	})

	settings:AddSetting({ type = LHAS.ST_SECTION, label = "Notification Mode" })
	settings:AddSetting({
		type = LHAS.ST_DROPDOWN,
		label = "Display Alerts As",
		tooltip = "Select how SiegeMaster displays alerts.",
		default = "Chat",
		getFunction = function() return SiegeReminder.SV.reminderType end,
		setFunction = function(_, name) SiegeReminder.SV.reminderType = name end,
		items = {
			{ name = "Chat", data = "Chat" },
			{ name = "Alert", data = "Alert" },
			{ name = "Full Screen", data = "Full Screen" },
		},
	})

	settings:AddSetting({ type = LHAS.ST_SECTION, label = "Bank Automation" })
	settings:AddSetting({
		type = LHAS.ST_CHECKBOX,
		label = "Enable Bank Automation",
		tooltip = "Auto withdraw in AvA and deposit outside AvA when bank opens.",
		default = true,
		getFunction = function() return SiegeReminder.SV.enabledBankAutomation end,
		setFunction = function(val) SiegeReminder.SV.enabledBankAutomation = val end,
	})
	settings:AddSetting({
		type = LHAS.ST_CHECKBOX,
		label = "Deposit Siege Outside AvA",
		tooltip = "When not in Cyrodiil, deposit discovered siege and Keep Recall Stones to bank on open.",
		default = true,
		getFunction = function() return SiegeReminder.SV.depositAllOutsideAvA end,
		setFunction = function(val) SiegeReminder.SV.depositAllOutsideAvA = val end,
	})
	settings:AddSetting({
		type = LHAS.ST_EDIT,
		label = "Move Delay (ms)",
		tooltip = "Delay between each bank move action.",
		default = "700",
		getFunction = function() return tostring(SiegeReminder.SV.bankMoveDelayMs or 700) end,
		setFunction = function(val)
			local v = tonumber(val) or 700
			if v < 200 then v = 200 end
			SiegeReminder.SV.bankMoveDelayMs = v
		end,
	})
	settings:AddSetting({
		type = LHAS.ST_CHECKBOX,
		label = "Enable Bank Debug",
		tooltip = "Print bank automation debug output.",
		default = false,
		getFunction = function() return SiegeReminder.SV.debug end,
		setFunction = function(val) SiegeReminder.SV.debug = val end,
	})

	settings:AddSetting({ type = LHAS.ST_SECTION, label = "Vendor Restock" })
	settings:AddSetting({
		type = LHAS.ST_CHECKBOX, label = "Automatic AP Restock",
		tooltip = "Opening a siege vendor buys selected items up to their Carry Max using Alliance Points.",
		default = false,
		getFunction = function() return SiegeReminder.SV.automaticAPRestock end,
		setFunction = function(value)
			SiegeReminder.SV.automaticAPRestock = value == true
			if not value then StopPurchases() end
		end,
	})
	settings:AddSetting({ type = LHAS.ST_SECTION, label = "Carry Levels by Item" })
	local firstItemControl = #settings.settings + 1
	local itemControlCount = 0

	RefreshItemSettings = function()
		Framework:RemoveFooter(settings)
		if itemControlCount > 0 then
			settings:RemoveSettings(firstItemControl, itemControlCount)
		end
		local ids = {}
		for id in pairs(catalog) do ids[#ids + 1] = id end
		table.sort(ids, function(a, b)
			if catalog[a] == catalog[b] then return a < b end
			return catalog[a] < catalog[b]
		end)
		local controls = {}
		if #ids == 0 then
			controls[1] = { type = LHAS.ST_LABEL, label = "Carry supplies or open your bank to discover reward siege and Keep Recall Stones. AP vendors also add supplies." }
		end
		for _, id in ipairs(ids) do
			local name = catalog[id]
			local cfg = GetItemSettings(id)
			-- A section would end the enclosing carry submenu on console.
			controls[#controls + 1] = { type = LHAS.ST_LABEL, label = "|cFFD700" .. name .. "|r" }
            if apCatalog[id] then
			controls[#controls + 1] = {
				type = LHAS.ST_CHECKBOX, label = "Buy " .. name .. " with AP",
				default = false,
				getFunction = function() return cfg.buyWithAP end,
				setFunction = function(value) cfg.buyWithAP = value == true end,
			}
            end
			controls[#controls + 1] = {
				type = LHAS.ST_CHECKBOX, label = name .. " Reminders and Bank Withdrawals",
				default = false,
				getFunction = function() return cfg.enabled end,
				setFunction = function(value) cfg.enabled = value == true end,
			}
			controls[#controls + 1] = {
				type = LHAS.ST_SLIDER, label = name .. " Carry Min",
				tooltip = "Warn when stock falls below this amount. Raising Carry Min above Carry Max raises both to match.",
				min = 0, max = 200, step = 1, format = "%d", default = 0,
				getFunction = function() return cfg.minCarry end,
				setFunction = function(value)
					cfg.minCarry = value
					cfg.maxCarry = math.max(cfg.maxCarry, value)
				end,
			}
			controls[#controls + 1] = {
				type = LHAS.ST_SLIDER, label = name .. " Carry Max",
				tooltip = "Target for AP purchases and bank withdrawals. Zero disables top-ups.",
				min = 0, max = 200, step = 1, format = "%d", default = 3,
				getFunction = function() return cfg.maxCarry end,
				setFunction = function(value)
					cfg.maxCarry = value
					cfg.minCarry = math.min(cfg.minCarry, value)
				end,
			}
		end
		settings:AddSettings(controls)
		itemControlCount = #controls
		Framework:AddFooter(settings)
	end
	RefreshItemSettings()
end

--------------------------------------------------------------
-- Init
--------------------------------------------------------------
local function OnAddOnLoaded(_, addonName)
	if addonName ~= ADDON_NAME then return end

	local defaults = {
		items = {},
		automaticAPRestock = false,
		reminderType = "Chat",
		debugMode = false,
		enabledBankAutomation = true,
		bankMoveDelayMs = 700,
		depositAllOutsideAvA = true,
		debug = false,
	}

	SiegeReminder = SiegeReminder or {}
	SiegeReminder.SV = Framework:NewAccountWide("SiegeReminder_SV", 1, nil, defaults)
	for _, cfg in pairs(SiegeReminder.SV.items) do
		cfg.maxCarry = math.max(cfg.maxCarry, cfg.minCarry)
	end
	local vendorData = ZO_SavedVars:NewAccountWide("SiegeReminder_VendorSV", 1, nil, { items = {} })
	catalog = vendorData.items
    -- Before 2.1.6 every saved catalog entry came from an AP vendor.
    if not vendorData.apItems then
        vendorData.apItems = {}
        for id in pairs(catalog) do vendorData.apItems[id] = true end
    end
    apCatalog = vendorData.apItems
    DiscoverSupplies({ BAG_BACKPACK, BAG_WORN })
	RefreshItemSettings = function() end

	EM:RegisterForEvent(ADDON_NAME.."_PlayerActivated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
	EM:RegisterForEvent(ADDON_NAME.."_Zone", EVENT_ZONE_CHANGED, OnZoneChanged)
	EM:RegisterForEvent(ADDON_NAME.."_Inv", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventoryUpdate)
	EM:RegisterForEvent(ADDON_NAME.."_StoreOpen", EVENT_OPEN_STORE, OnStoreOpen)
	EM:RegisterForEvent(ADDON_NAME.."_StoreClose", EVENT_CLOSE_STORE, OnStoreClose)
	EM:RegisterForEvent(ADDON_NAME.."_BankOpen", EVENT_OPEN_BANK, OnBankOpened)
	EM:RegisterForEvent(ADDON_NAME.."_BankClose", EVENT_CLOSE_BANK, OnBankClosed)

	EM:RegisterForEvent(ADDON_NAME .. "_StoreFailure", EVENT_STORE_FAILURE, function()
		if pendingPurchase then
			pendingPurchase = nil
			StopPurchases()
			chat("AP restock stopped after the vendor rejected a purchase.")
		end
	end)

	CreateSettingsMenu()
	
	chat(Framework.displayName .. " v" .. Framework.version .. " active.")
end



EM:RegisterForEvent(ADDON_NAME.."_Loaded", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
