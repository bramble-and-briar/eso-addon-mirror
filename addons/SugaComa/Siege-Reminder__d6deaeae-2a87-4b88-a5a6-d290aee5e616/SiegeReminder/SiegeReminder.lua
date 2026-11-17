--------------------------------------------------------------
-- SiegeReminder.lua — SiegeMaster v2.1.4
-- Author: SugaComa
--------------------------------------------------------------
local ADDON_NAME = "SiegeReminder"
local EM = EVENT_MANAGER
local Framework = SiegeReminder_Framework
local catalog
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
local function Notify(msg)
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
			p:SetText(prefix .. tostring(msg))
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
local function IsSiegeItem(bagId, slotIndex)
	local itemType = GetItemType(bagId, slotIndex)
	return itemType == ITEMTYPE_SIEGE or itemType == ITEMTYPE_AVA_REPAIR
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
		if IsSiegeItem(bagId, slot) then
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
	local itemType = GetItemLinkItemType(link)
	if itemType ~= ITEMTYPE_SIEGE and itemType ~= ITEMTYPE_AVA_REPAIR then return end
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

	local moved = 0
	local index = 1
	local delay = tonumber(delayMs) or 700

	EM:UnregisterForUpdate(handleName)
	EM:RegisterForUpdate(handleName, delay, function()
		if not bankSessionRunning then
			EM:UnregisterForUpdate(handleName)
			if onDone then onDone(moved, "closed") end
			return
		end

		local move = queue[index]
		if not move then
			EM:UnregisterForUpdate(handleName)
			if onDone then onDone(moved, nil) end
			return
		end

		local slotTo = move.slotTo
		if not slotTo then
			slotTo = GetFreeSlotInBag(move.bagTo)
		end
		if not slotTo then
			EM:UnregisterForUpdate(handleName)
			if onDone then onDone(moved, "full") end
			return
		end

		if SafeRequestMoveItem then
			SafeRequestMoveItem(move.bagFrom, move.slotFrom, move.bagTo, slotTo, move.qty)
			moved = moved + (move.qty or 0)
		end

		index = index + 1
	end)
end

--------------------------------------------------------------
-- Bank Automation
--------------------------------------------------------------
local function WithdrawToCarryMax()
	local carried = CountCarried()
	local bankSlots = BuildSiegeSlotsByItem(BAG_BANK)
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
						QueueMove(queue, BAG_BANK, entry.slot, BAG_BACKPACK, nil, qty)
						need = need - qty
					end
				end
			end
		end
	end

	RunQueue("SIEGE_BANK_WITHDRAW", queue, SiegeReminder.SV.bankMoveDelayMs, function(moved, reason)
		if moved > 0 then
			Notify("Topped up siege from bank (Cyrodiil).")
		end
		if reason == "full" then
			Notify("Backpack full. Siege withdraw stopped.")
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
			Notify("Deposited vendor siege supplies to bank (outside Cyrodiil).")
		end
		if reason == "full" then
			Notify("Bank full. Siege deposit stopped.")
		end
	end)
end

local function OnBankOpened(_, bag)
	if not SiegeReminder.SV or SiegeReminder.SV.enabledBankAutomation ~= true then return end
	if bag ~= BAG_BANK and bag ~= BAG_SUBSCRIBER_BANK then return end
	if bankSessionRunning then return end

	bankSessionRunning = true
	debugBank("Bank opened. Running automation.")

	zo_callLater(function()
		if not bankSessionRunning then return end
	if IsInCyrodiil() then
		WithdrawToCarryMax()
	else
		DepositAllSiege()
	end
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
			Notify(" You are running low on siege supplies — restock before heading out!")
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
			Notify(" You are still running low on siege — visit a merchant to restock!")
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

local function ManualCheck()
	CheckSiegeStock()
end

SLASH_COMMANDS["/sgrdebug"] = ToggleDebug
SLASH_COMMANDS["/sgrcheck"] = ManualCheck


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
		tooltip = "When not in Cyrodiil, deposit discovered siege supplies to bank on open.",
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
			controls[1] = { type = LHAS.ST_LABEL, label = "Open a siege vendor to discover items sold for AP." }
		end
		for _, id in ipairs(ids) do
			local name = catalog[id]
			local cfg = GetItemSettings(id)
			-- A section would end the enclosing carry submenu on console.
			controls[#controls + 1] = { type = LHAS.ST_LABEL, label = "|cFFD700" .. name .. "|r" }
			controls[#controls + 1] = {
				type = LHAS.ST_CHECKBOX, label = "Buy " .. name .. " with AP",
				default = false,
				getFunction = function() return cfg.buyWithAP end,
				setFunction = function(value) cfg.buyWithAP = value == true end,
			}
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
