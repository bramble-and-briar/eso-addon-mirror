--[[
-------------------------------------------------------------------------------
-- BankManager, by Ayantir
-------------------------------------------------------------------------------
This software is under : CreativeCommons CC BY-NC-SA 4.0
Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)

You are free to:

    Share — copy and redistribute the material in any medium or format
    Adapt — remix, transform, and build upon the material
    The licensor cannot revoke these freedoms as long as you follow the license terms.


Under the following terms:

    Attribution — You must give appropriate credit, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.
    NonCommercial — You may not use the material for commercial purposes.
    ShareAlike — If you remix, transform, or build upon the material, you must distribute your contributions under the same license as the original.
    No additional restrictions — You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.


Please read full licence at : 
http://creativecommons.org/licenses/by-nc-sa/4.0/legalcode
]]
 
-- Global Vars
BMR = {}
BMR.Console = { registeredScenes = {}, registeredSceneNames = {} }
db = {}
local ADDON_NAME					= "BankManagerRevived"
local displayName					= "|c3366FFBank|r Manager |c990000Revived|r |cFF0000(AI Updated)|r"
local ADDON_AUTHOR				= "Ayantir & SnowmanDK & Lexynide & Gamer1986PAN & @DeadSoon"
-- Read the numeric ##AddOnVersion from the addon manifest through ESO's AddOnManager.
-- GetAddOnVersion() is not a global ESO API function.
local function GetAddonVersionFromManifest()
	local addOnManager = GetAddOnManager()
	if not addOnManager then return -1 end
	for i = 1, addOnManager:GetNumAddOns() do
		local addOnName = addOnManager:GetAddOnInfo(i)
		if addOnName == ADDON_NAME then
			return addOnManager:GetAddOnVersion(i)
		end
	end
	return -1 -- Fallback if the AddOnManager could not find BMR.
end

local ADDON_VERSION = tostring(GetAddonVersionFromManifest())
local ADDON_WEBSITE				= "https://www.esoui.com/downloads/fileinfo.php?id=2333"
local isBanking					= false
local actualProfile				= 1
local inProgress					= false
local panel
local guildList
local checkingGBank
local activeRuleRunPhase = nil -- nil, "building", or "moving"
local currentGBank
local restartFromAtGBank
local hasAnyPullToDo
local hasAnySpecialPullToDo
local qtyMovedToGBank			= 0
local countMovedToGBank			= 0
local dataSorted
local isESOPlusSubscriber
local activeHouseStorageBagId = nil
-- Some backpack items can become visible to BMR only after ESO/LibSharedInventory
-- has settled the previous housing transfer batch. Re-scan automatically after
-- successful house-storage batches so these items do not require a second icon click.
local housingAutoRescanPasses = 0
local MAX_HOUSING_AUTO_RESCANS = 3
local CustomRuleDebug -- forward declaration used by housing-container context helpers

-- Temporary diagnostics for profile initialization and the in-game profile switcher.
-- The in-memory pre-init buffer lets us retain early startup checkpoints if diagnostics
-- were enabled in SavedVariables on the previous session.
BMR._profileDebugSavedVarsReady = false
BMR._profileDebugPreInitLog = {}
BMR._profileDebugLogLimit = 120
BMR._profileDebugPreInitLimit = 30

function BMR.ProfileDebugSafeGetter(getterName)
	local getter = _G and _G[getterName]
	if type(getter) ~= "function" then return "n/a" end
	local ok, value = pcall(getter)
	if not ok or value == nil then return "n/a" end
	return tostring(value)
end

function BMR.ProfileDebugNow()
	local ok, value = pcall(function()
		if type(GetTimeString) == "function" then return GetTimeString() end
		if type(GetTimeStamp) == "function" then return GetTimeStamp() end
		return "time-n/a"
	end)
	return ok and tostring(value) or "time-n/a"
end

function BMR.ProfileDebugAppendBounded(target, record, limit)
	target[#target + 1] = record
	while #target > limit do table.remove(target, 1) end
end

function BMR.ProfileDiagnostic(stage, details)
	local account = BMR.ProfileDebugSafeGetter("GetDisplayName")
	local character = BMR.ProfileDebugSafeGetter("GetUnitName")
	-- GetUnitName requires a unit tag in ESO; use a protected direct player lookup instead.
	local unitGetter = _G and _G.GetUnitName
	if type(unitGetter) == "function" then
		local ok, value = pcall(unitGetter, "player")
		if ok and value ~= nil then character = tostring(value) end
	end
	local world = BMR.ProfileDebugSafeGetter("GetWorldName")
	local detail = tostring(details or "")	:gsub("[\r\n]+", " ")
	if #detail > 700 then detail = string.sub(detail, 1, 700) .. "…" end
	local record = string.format("%s | stage=%s | account=%s | character=%s | world=%s%s",
		BMR.ProfileDebugNow(), tostring(stage or "unknown"), account, character, world,
		detail ~= "" and (" | " .. detail) or "")

	if BMR._profileDebugSavedVarsReady and type(db) == "table" then
		if db.profileDebugEnabled == true then
			if type(db.profileDebugLog) ~= "table" then db.profileDebugLog = {} end
			BMR.ProfileDebugAppendBounded(db.profileDebugLog, record, BMR._profileDebugLogLimit)
		end
	elseif not BMR._profileDebugSavedVarsReady then
		BMR.ProfileDebugAppendBounded(BMR._profileDebugPreInitLog, record, BMR._profileDebugPreInitLimit)
		-- SavedVariables are available globally before BMR constructs its account-wide db.
		-- If diagnostics were already enabled, persist early checkpoints even when startup
		-- fails before buildLAMPanel() reaches ZO_SavedVars:NewAccountWide().
		local accountStore = BMVars and BMVars.Default
		local displayName = BMR.ProfileDebugSafeGetter("GetDisplayName")
		local noAt = string.gsub(displayName, "^@", "")
		local rawAccount = type(accountStore) == "table" and (accountStore[displayName] or accountStore["@" .. noAt] or accountStore[noAt]) or nil
		local rawAccountWide = type(rawAccount) == "table" and rawAccount["$AccountWide"] or nil
		if type(rawAccountWide) == "table" and rawAccountWide.profileDebugEnabled == true then
			if type(rawAccountWide.profileDebugLog) ~= "table" then rawAccountWide.profileDebugLog = {} end
			BMR.ProfileDebugAppendBounded(rawAccountWide.profileDebugLog, record, BMR._profileDebugLogLimit)
		end
	end
	return record
end

function BMR.ProfileDiagnosticFlushPreInit()
	if type(db) ~= "table" or db.profileDebugEnabled ~= true then return end
	if type(db.profileDebugLog) ~= "table" then db.profileDebugLog = {} end
	for _, record in ipairs(BMR._profileDebugPreInitLog) do
		BMR.ProfileDebugAppendBounded(db.profileDebugLog, record, BMR._profileDebugLogLimit)
	end
	BMR._profileDebugPreInitLog = {}
end

-- CHAT_SYSTEM is not available in every controller/console flow. Keep the
-- keyboard chat path first, then use the shared chat router which also services
-- the console chat implementation. An optional LibAPH raw-line helper is a final
-- console-specific fallback for environments where neither object is exposed.
-- Output is best-effort and must never interrupt transfer verification/cleanup.
local function TrySendChatLine(target, methodName, message)
	if not target then return false end
	local method = target[methodName]
	if type(method) ~= "function" then return false end
	local ok = pcall(method, target, message)
	return ok
end

function BMR.SafeAddChatMessage(message)
	local text = tostring(message or "")
	if TrySendChatLine(CHAT_SYSTEM, "AddMessage", text) then return true end

	-- CHAT_SYSTEM is intentionally nil on console. CHAT_ROUTER:AddSystemMessage
	-- is the normal UI entry point for system messages and works without the
	-- keyboard chat-system object.
	if TrySendChatLine(CHAT_ROUTER, "AddSystemMessage", text) then return true end

	-- Some console-oriented libraries expose a raw-line adapter. Do not make it a
	-- dependency: use it only when present, and retain native fallbacks otherwise.
	local libAPH = _G and _G.LibAPH
	if libAPH and type(libAPH.SendRawChatLine) == "function" then
		local ok = pcall(libAPH.SendRawChatLine, text)
		if ok then return true end
	end

	-- Last resort: ESO's debug output is routed through the system-message path
	-- on supported clients, including controller flows.
	if type(d) == "function" then
		local ok = pcall(d, text)
		if ok then return true end
	end
	return false
end

function BMR.ProfileDiagnosticChat(message)
	local text = "|c66CCFF[BMR Profil-Debug]|r " .. tostring(message or "")
	if not BMR.SafeAddChatMessage(text) and type(d) == "function" then
		d(text)
	end
end

-- Wrap event callbacks only when diagnostics are enabled. This records entry, completion,
-- and caught Lua errors without adding event-log noise during normal BMR use.
function BMR.ProfileDebugWrapEvent(eventName, callback)
	return function(...)
		if type(db) ~= "table" or db.profileDebugEnabled ~= true then
			return callback(...)
		end
		local args = {}
		for index = 1, select("#", ...) do args[#args + 1] = tostring(select(index, ...)) end
		BMR.ProfileDiagnostic(tostring(eventName) .. "_ENTER", "args=[" .. table.concat(args, ",") .. "]; " .. BMR.ProfileDebugSnapshot())
		local ok, err = pcall(callback, ...)
		if not ok then
			BMR.ProfileDiagnostic(tostring(eventName) .. "_ERROR", tostring(err) .. "; " .. BMR.ProfileDebugSnapshot())
			BMR.ProfileDiagnosticChat("Fehler in " .. tostring(eventName) .. ": " .. tostring(err) .. ". /bmr/profiledebug ausgeben.")
		else
			BMR.ProfileDiagnostic(tostring(eventName) .. "_EXIT", BMR.ProfileDebugSnapshot())
		end
	end
end

-- Schedule another housing-storage pass even when the previous pass found no
-- queued moves. ESO/LibSharedInventory can expose newly moved or newly visible
-- items only after more than one refresh interval, so a single empty scan must
-- not cancel the bounded follow-up sequence.
local function ScheduleHousingAutoRescan(itemsMovedInPass, reason, delayMs)
	if not activeHouseStorageBagId or not isBanking or checkingGBank then
		housingAutoRescanPasses = 0
		return false
	end

	if housingAutoRescanPasses >= MAX_HOUSING_AUTO_RESCANS then
		CustomRuleDebug(string.format("HOUSE STORAGE AUTO-RESCAN limit reached passes=%d max=%d; stopping automatic follow-up scans", housingAutoRescanPasses, MAX_HOUSING_AUTO_RESCANS))
		housingAutoRescanPasses = 0
		return false
	end

	housingAutoRescanPasses = housingAutoRescanPasses + 1
	local rescanPass = housingAutoRescanPasses
	local rescanBag = activeHouseStorageBagId
	local delay = delayMs or 500
	CustomRuleDebug(string.format("HOUSE STORAGE AUTO-RESCAN scheduled pass=%d/%d movedItems=%d bag=%s delay=%dms reason=%s", rescanPass, MAX_HOUSING_AUTO_RESCANS, itemsMovedInPass or 0, tostring(rescanBag), delay, tostring(reason)))
	zo_callLater(function()
		if isBanking and activeHouseStorageBagId == rescanBag and not checkingGBank then
			CustomRuleDebug(string.format("HOUSE STORAGE AUTO-RESCAN execute pass=%d/%d bag=%s", rescanPass, MAX_HOUSING_AUTO_RESCANS, tostring(rescanBag)))
			BankManagerRevived_executeRule(true)
		else
			CustomRuleDebug(string.format("HOUSE STORAGE AUTO-RESCAN cancelled pass=%d/%d reason=storage context changed", rescanPass, MAX_HOUSING_AUTO_RESCANS))
			housingAutoRescanPasses = 0
		end
	end, delay)
	return true
end

-- Optional external transfer providers. Kept empty when no provider is registered.
local transferProviders = {}

local ACTION_NOTSET				= 1
local ACTION_PUSH					= 2
local ACTION_PULL					= 3
local ACTION_PUSH_GBANK			= 4
local ACTION_PUSH_BOTH			= 5
local ACTION_KEEP_ONE_STACK	= 6
local ACTION_KEEP_ONE_STACK_BANK = 7
local ACTION_PUSH_FURNITURE = 8
local ACTION_PUSH_ALL_STACKS = 9
local ACTION_PULL_ALL_STACKS = 10

-- Compact scan telemetry used only while the profile diagnostic switch is enabled.
function BMR.ProfileDebugBeginScan(label)
	if type(db) ~= "table" or db.profileDebugEnabled ~= true then BMR._profileDebugScanStats = nil; return end
	BMR._profileDebugScanStats = {label = tostring(label or "scan"), scanned = 0, stolen = 0, protected = 0, pickupPersonal = 0, pickupGuild = 0, activeExact = 0, matched = 0, queued = 0, bankOnly = 0, noRuleMatch = 0, oneStack = 0, customFilterMatched = 0}
end

function BMR.ProfileDebugScanIncrement(key, amount)
	local stats = BMR._profileDebugScanStats
	if type(db) ~= "table" or db.profileDebugEnabled ~= true or type(stats) ~= "table" then return end
	stats[key] = (tonumber(stats[key]) or 0) + (tonumber(amount) or 1)
end

function BMR.ProfileDebugScanSummary()
	local stats = BMR._profileDebugScanStats
	if type(stats) ~= "table" then return "scanStats=disabled" end
	return string.format("scan=%s scanned=%d stolen=%d protected=%d pickupPersonal=%d pickupGuild=%d activeExact=%d customFilterMatched=%d oneStack=%d matched=%d queued=%d bankOnly=%d noRuleMatch=%d",
		tostring(stats.label), tonumber(stats.scanned) or 0, tonumber(stats.stolen) or 0, tonumber(stats.protected) or 0,
		tonumber(stats.pickupPersonal) or 0, tonumber(stats.pickupGuild) or 0, tonumber(stats.activeExact) or 0,
		tonumber(stats.customFilterMatched) or 0, tonumber(stats.oneStack) or 0, tonumber(stats.matched) or 0,
		tonumber(stats.queued) or 0, tonumber(stats.bankOnly) or 0, tonumber(stats.noRuleMatch) or 0)
end

function BMR.ProfileDebugRuleActionSummary()
	if type(db) ~= "table" or db.profileDebugEnabled ~= true then return "ruleActionSummary=disabled" end
	local profile = type(db.profiles) == "table" and db.profiles[actualProfile] or nil
	local rules = type(profile) == "table" and type(profile.rules) == "table" and profile.rules or {}
	local counts, total, active = {}, 0, 0
	for action = 1, 10 do counts[action] = 0 end
	for _, rule in pairs(rules) do
		if type(rule) == "table" then
			total = total + 1
			local action = tonumber(rule.action) or 1
			if counts[action] ~= nil then counts[action] = counts[action] + 1 end
			if action ~= ACTION_NOTSET then active = active + 1 end
		end
	end
	return string.format("rules=%d active=%d actions[unset=%d,push=%d,pull=%d,guild=%d,both=%d,oneInv=%d,oneBank=%d,furniture=%d,pushAll=%d,pullAll=%d] globalAddonProfile=%s",
		total, active, counts[1], counts[2], counts[3], counts[4], counts[5], counts[6], counts[7], counts[8], counts[9], counts[10], tostring(type(db) == "table" and db.globalAddonProfile))
end

function BMR.ProfileDebugBagCacheSummary(bagId)
	if type(db) ~= "table" or db.profileDebugEnabled ~= true then return "bagCacheSummary=disabled" end
	local cache = SHARED_INVENTORY and SHARED_INVENTORY.bagCache and SHARED_INVENTORY.bagCache[bagId]
	local cachedSlots, liveItems = 0, 0
	if type(cache) == "table" then
		for slotId in pairs(cache) do
			cachedSlots = cachedSlots + 1
			local link = type(GetItemLink) == "function" and GetItemLink(bagId, slotId) or nil
			if link and link ~= "" then liveItems = liveItems + 1 end
		end
	end
	return string.format("bag=%s cachedSlots=%d liveItems=%d", tostring(bagId), cachedSlots, liveItems)
end

-- Housing storage has two distinct kinds of bags: the ten general-purpose
-- house chests and the furnishings-only Furniture Vault. Keep those predicates
-- separate so routing and user-facing messages always describe the actual target.
local HOUSE_BANK_BAGS = {BAG_HOUSE_BANK_ONE, BAG_HOUSE_BANK_TWO, BAG_HOUSE_BANK_THREE, BAG_HOUSE_BANK_FOUR, BAG_HOUSE_BANK_FIVE, BAG_HOUSE_BANK_SIX, BAG_HOUSE_BANK_SEVEN, BAG_HOUSE_BANK_EIGHT, BAG_HOUSE_BANK_NINE, BAG_HOUSE_BANK_TEN}

local function IsHouseBankChestBag(bagId)
	if not bagId then return false end
	for _, houseBag in pairs(HOUSE_BANK_BAGS) do
		if houseBag and bagId == houseBag then return true end
	end
	return false
end

local function IsFurnitureVaultBag(bagId)
	return BAG_FURNITURE_VAULT ~= nil and bagId == BAG_FURNITURE_VAULT
end

local function IsFurnitureStorageBag(bagId)
	return IsHouseBankChestBag(bagId) or IsFurnitureVaultBag(bagId)
end

-- EVENT_OPEN_BANK supplies the active bag, but resync from ESO's live API when
-- BMR's profile icon is clicked or an automatic transfer run begins. This guards
-- against stale/nil context when the bank scene stays open while the active house
-- container changes. A house bag must never be mistaken for the personal bank
-- (notably for currency transfers, which are not supported by housing storage).
local function RefreshActiveHouseStorageBagContext(source, eventBagId)
	local bankingBag = eventBagId
	local resolvedBy = eventBagId ~= nil and "EVENT_OPEN_BANK" or "GetBankingBag"
	if bankingBag == nil and type(GetBankingBag) == "function" then
		local ok, result = pcall(GetBankingBag)
		if ok and result ~= nil then bankingBag = result end
	end
	if bankingBag ~= nil then
		local previousBag = activeHouseStorageBagId
		if IsFurnitureStorageBag(bankingBag) then
			activeHouseStorageBagId = bankingBag
		elseif bankingBag == BAG_BANK or bankingBag == BAG_SUBSCRIBER_BANK then
			activeHouseStorageBagId = nil
		else
			activeHouseStorageBagId = nil
		end
		local kind = IsFurnitureVaultBag(bankingBag) and "FURNITURE_VAULT" or (IsHouseBankChestBag(bankingBag) and "HOUSE_CHEST" or (bankingBag == BAG_SUBSCRIBER_BANK and "SUBSCRIBER_BANK" or (bankingBag == BAG_BANK and "PERSONAL_BANK" or "OTHER")))
		CustomRuleDebug(string.format("STORAGE CONTEXT source=%s resolvedBy=%s liveBag=%s kind=%s previousHouseBag=%s activeHouseBag=%s", tostring(source), tostring(resolvedBy), tostring(bankingBag), kind, tostring(previousBag), tostring(activeHouseStorageBagId)))
	else
		CustomRuleDebug(string.format("STORAGE CONTEXT source=%s unresolved=true; preserving previousHouseBag=%s", tostring(source), tostring(activeHouseStorageBagId)))
	end
	return bankingBag
end

local function IsCurrentStorageSourceBag(bagId)
	if activeHouseStorageBagId then return bagId == activeHouseStorageBagId end
	return bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK
end

local function GetCurrentStorageSourceBags()
	if activeHouseStorageBagId then return {activeHouseStorageBagId} end
	return {BAG_BANK, BAG_SUBSCRIBER_BANK}
end

local function GetCurrentDepositBag()
	return activeHouseStorageBagId or BAG_BANK
end

local function IsBankDestinationBag(bagId)
	return bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK or IsFurnitureStorageBag(bagId)
end

local function CountItemLinkInBag(itemLink, bagId)
	local total = 0
	if not itemLink or not bagId then return total end
	local bagSize = GetBagSize(bagId) or 0
	for slotId = 0, bagSize - 1 do
		if GetItemLink(bagId, slotId) == itemLink then
			total = total + (GetSlotStackSize(bagId, slotId) or 0)
		end
	end
	return total
end

-- Housing transfers can return a localized/formatted link that isn't byte-for-byte
-- identical to the source link, and some storage slots may be auto-assigned by ESO.
-- Count by item ID as a second confirmation path while also requiring source change.
local function CountItemIdInBag(itemId, bagId)
	local total = 0
	if not itemId or not bagId then return total end
	local bagSize = GetBagSize(bagId) or 0
	for slotId = 0, bagSize - 1 do
		local link = GetItemLink(bagId, slotId)
		if link and link ~= "" then
			local ok, candidateItemId = pcall(GetItemLinkItemId, link)
			if ok and candidateItemId == itemId then
				total = total + (GetSlotStackSize(bagId, slotId) or 0)
			end
		end
	end
	return total
end

local BMR_RULEWRITER_VALUE_OPTIONAL_KEYWORD = 1
local BMR_RULEWRITER_VALUE_WITH_OPERATOR = 2
local BMR_RULEWRITER_VALUE_WITHOUT_OPERATOR = 3

local BMR_ITEMLINK				= 1
local BMR_BAG_AND_SLOT			= 2
--local startTimeInMs			= 0

-- Array of queues for moving items to handle bag/bank capacity limits
local pushQueue = {}
local pullQueue = {}
local movedItems = {
	[BAG_BACKPACK] = {},
	[BAG_BANK] = {},
	[BAG_SUBSCRIBER_BANK] = {},
}

-- Items explicitly configured to keep exactly one stack in the backpack.
local oneStackRequests = {}

-- PvP movement tracing: expected addon transfers are matched against slot-update events.
-- Unmatched PvP slot changes are reported as external/unattributed candidates; they can be
-- manual player moves or actions from another addon and are not claimed to be manual with certainty.
local RegisterExpectedPvpMoveTrace
local CancelExpectedPvpMoveTrace
local pvpMovementTraceEventName = ADDON_NAME .. "_PvPMoveTrace"
local pvpMovementTraceActive = false
local pvpMovementTraceBaseline = {}
local pvpExpectedMoveTraces = {}
local pvpExpectedMoveTraceSerial = 0
-- Current asynchronous transfer verification for profile-icon diagnostics.
local activeTransferVerificationDebug = nil
-- Distinguish synchronous queue-building from the actual asynchronous move loop.
local profileIconRerunRequested = false

-- Optional diagnostics for custom item rules and one-stack selection.
CustomRuleDebug = function(message)
	if db and db.customRulesDebug == true then
		d("[BMR Custom Rules] " .. tostring(message))
	end
end

-- ESO item names may carry grammatical markers such as ^m, ^f, ^n or ^p.
-- Format the localized item name through ESO instead of saving/displaying those markers.
-- Prefer the current item-link name so existing saved rules are also corrected and localized.
local function FormatCustomItemName(itemLink, fallbackName)
	local itemName = fallbackName
	if itemLink and itemLink ~= "" and GetItemLinkName then
		local ok, name = pcall(GetItemLinkName, itemLink)
		if ok and type(name) == "string" and name ~= "" then
			itemName = name
		end
	end
	if type(itemName) ~= "string" or itemName == "" then return nil end
	if ZO_CachedStrFormat then
		local ok, formattedName = pcall(ZO_CachedStrFormat, "<<C:1>>", itemName)
		if ok and type(formattedName) == "string" and formattedName ~= "" then
			return formattedName
		end
	end
	-- Fallback for contexts where ESO's string formatter is unavailable.
	return (itemName:gsub("%^[mMfFnNpP]+$", ""))
end

-- Remember occupied PvP stack targets that rejected a transfer during this bank
-- session. When a move to an occupied stack is not confirmed and neither slot
-- changed, do not retry the same destination on the next profile-icon click.
local rejectedPvpStackTargets = {}
-- If a one-stack action cannot merge an item into its chosen destination stack,
-- remember that exact occupied target for this bank session. Do not work around
-- the rejection by creating a second physical stack in the target container.
local rejectedOneStackDestinations = {}
local function GetRejectedPvpStackTargetKey(bagId, slotId, itemLink)
	return tostring(bagId) .. ":" .. tostring(slotId) .. ":" .. tostring(itemLink)
end
local function GetOneStackDestinationKey(itemLink, bagIdTo)
	local itemId = itemLink and GetItemLinkItemId(itemLink)
	local destination = (bagIdTo == BAG_BACKPACK) and "backpack" or ((bagIdTo == BAG_BANK or bagIdTo == BAG_SUBSCRIBER_BANK) and "bank" or tostring(bagIdTo))
	return tostring(itemId) .. ":" .. destination
end
local function ClearRejectedPvpStackTargetsForSlot(bagId, slotId)
	local prefix = tostring(bagId) .. ":" .. tostring(slotId) .. ":"
	for key in pairs(rejectedPvpStackTargets) do
		if string.sub(key, 1, #prefix) == prefix then
			rejectedPvpStackTargets[key] = nil
		end
	end
	for key, target in pairs(rejectedOneStackDestinations) do
		if target.bagId == bagId and target.slotId == slotId then
			rejectedOneStackDestinations[key] = nil
		end
	end
end

SLASH_COMMANDS["/bmr/custom/debug"] = function()
	if not db then
		d("[BMR Custom Rules] Einstellungen sind noch nicht geladen.")
		return
	end
	db.customRulesDebug = not (db.customRulesDebug == true)
	d("[BMR Custom Rules] Debugmodus " .. (db.customRulesDebug and "aktiviert." or "deaktiviert."))
end


local function GetCustomRuleSlotDebugInfo(bagId, slotId)
	local details = {}
	local ok, condition = pcall(GetItemCondition, bagId, slotId)
	if ok and condition ~= nil then table.insert(details, "condition=" .. tostring(condition)) end
	local chargeOk, charges, maxCharges = pcall(GetChargeInfoForItem, bagId, slotId)
	if chargeOk and charges ~= nil then table.insert(details, "charge=" .. tostring(charges) .. "/" .. tostring(maxCharges)) end
	local count, maximum = GetSlotStackSize(bagId, slotId)
	if count ~= nil then table.insert(details, "stack=" .. tostring(count) .. "/" .. tostring(maximum)) end
	return table.concat(details, ", ")
end

local BMR_PVP_ITEM_CATALOG

-- Siege item links can contain remaining-energy data that ESO does not expose
-- consistently through condition/charge APIs. The payload field is only trusted
-- for catalogued PvP siege items; unknown formats safely fall back to normal order.
local function GetSiegeRemainingEnergy(itemLink)
	if not itemLink then return nil end
	local itemId = GetItemLinkItemId(itemLink)
	if not itemId or not BMR_PVP_ITEM_CATALOG or not BMR_PVP_ITEM_CATALOG[itemId] then return nil end
	local payload = string.match(tostring(itemLink), "|H%d:item:([^|]+)|h")
	if not payload then return nil end
	local fields = {}
	for field in string.gmatch(payload, "([^:]+)") do fields[#fields + 1] = field end
	local energy = tonumber(fields[20])
	if energy == nil then return nil end
	-- ESO represents a fully charged siege item with zero in this link field.
	-- Treat zero as the full/unused sentinel, not as the lowest possible energy:
	-- otherwise a fresh stack wins when the profile prefers used siege items.
	if energy == 0 then
		if itemId == 30359 then return 100000 end
		return 1000000
	end
	return energy
end
local GetBrandOilRemainingEnergy = GetSiegeRemainingEnergy -- compatibility for existing diagnostics

-- Resolve whether a PvP siege item is used from its link energy where possible.
-- The zero-energy payload sentinel is already mapped to the item's full/unused
-- sentinel by GetSiegeRemainingEnergy above. Fall back to the game's condition API
-- only for catalogued items whose links do not expose a readable energy value.
local function GetPvpUsedState(itemId, itemLink, bagId, slotId)
	local energy = GetSiegeRemainingEnergy(itemLink)
	if energy ~= nil then
		local fullEnergySentinel = itemId == 30359 and 100000 or 1000000
		return energy < fullEnergySentinel, true, energy
	end
	if bagId ~= nil and slotId ~= nil then
		local ok, condition = pcall(GetItemCondition, bagId, slotId)
		if ok and type(condition) == "number" and condition >= 0 and condition <= 100 then
			return condition < 100, true, nil
		end
	end
	return nil, false, nil
end

-- Focused snapshot for diagnosing automatic-storage vs. sync-command differences.
-- Runs only while custom-rule debug is enabled; it never moves items.
-- It prints the category defaults, configured PvP actions, and the effective
-- rule resolved for each present item so logs can be compared 1:1 with options.
local function BMR_DumpPvpStorageSnapshot(source)
	if not (db and db.customRulesDebug == true) then return end
	local profile = db.profiles and db.profiles[actualProfile]
	if not profile then d("[BMR PvP SNAPSHOT] Kein aktives Profil verfügbar."); return end
	profile.rules = profile.rules or {}
	local rules = profile.rules
	local bags = {
		{ id = BAG_BACKPACK, label = "INVENTAR" },
	}
	if activeHouseStorageBagId then
		local storageLabel = IsFurnitureVaultBag(activeHouseStorageBagId) and "FURNITURE VAULT" or "HOUSE CHEST"
		table.insert(bags, { id = activeHouseStorageBagId, label = storageLabel })
	else
		table.insert(bags, { id = BAG_BANK, label = "BANK" })
		table.insert(bags, { id = BAG_SUBSCRIBER_BANK, label = "ESO+ BANK" })
	end
	local preferredUsed = (profile.pvpPriorityState or "unused") == "used"
	local function actionLabel(action)
		local labels = {
			[ACTION_NOTSET] = GetString(BMR_ACTION_NOTSET),
			[ACTION_PUSH] = GetString(BMR_ACTION_PUSH),
			[ACTION_PULL] = GetString(BMR_ACTION_PULL),
			[ACTION_PUSH_GBANK] = GetString(BMR_ACTION_PUSH_GBANK),
			[ACTION_PUSH_BOTH] = GetString(BMR_ACTION_PUSH_BOTH),
			[ACTION_KEEP_ONE_STACK] = GetString(BMR_ACTION_KEEP_ONE_STACK),
			[ACTION_KEEP_ONE_STACK_BANK] = GetString(BMR_ACTION_KEEP_ONE_STACK_BANK),
			[ACTION_PUSH_FURNITURE] = GetString(BMR_ACTION_PUSH_FURNITURE),
			[ACTION_PUSH_ALL_STACKS] = GetString(BMR_ACTION_PUSH_ALL_STACKS),
			[ACTION_PULL_ALL_STACKS] = GetString(BMR_ACTION_PULL_ALL_STACKS),
		}
		return tostring(labels[action] or ("UNKNOWN(" .. tostring(action) .. ")"))
	end
	local function boolLabel(value, defaultValue)
		if value == nil then value = defaultValue end
		if value == nil then return "unset" end
		return value and "true" or "false"
	end
	local function logRule(prefix, name, rule)
		rule = rule or {}
		local action = rule.action or ACTION_NOTSET
		d(string.format("[BMR PvP SNAPSHOT] %s rule=%s action=%s(%s) configured=%s associatedGuild=%s onlyIfNotFullStack=%s onlyStacks=%s",
			tostring(prefix), tostring(name), tostring(action), actionLabel(action), tostring(action ~= ACTION_NOTSET),
			tostring(rule.associatedGuild or "<unset>"), boolLabel(rule.onlyIfNotFullStack, true), tostring(rule.onlyStacks or "<unset>")))
	end
	local categoryOnlyIf = rules.MiscPvpAll and rules.MiscPvpAll.onlyIfNotFullStack
	local categoryStacks = rules.MiscPvpStacks and rules.MiscPvpStacks.onlyStacks
	local categoryGuild = rules.MiscPvpGBank and rules.MiscPvpGBank.associatedGuild
	d(string.format("[BMR PvP SNAPSHOT] START source=%s profile=%s preferredInventoryState=%s customDebug=true",
		tostring(source), tostring(actualProfile), preferredUsed and "used" or "unused"))
	d(string.format("[BMR PvP SNAPSHOT] CATEGORY rule=MiscPvpAll onlyIfNotFullStack=%s maxStacksRule=MiscPvpStacks maxStacks=%s maxStacksEffective=%s guildBankRule=MiscPvpGBank guildBank=%s",
		boolLabel(categoryOnlyIf, true), tostring(categoryStacks or 1), tostring(categoryOnlyIf == false and (categoryStacks or 1) or 1), tostring(categoryGuild or GetString(BMR_ACTION_NOTSET))))
	logRule("MASTER", "MiscPvpSiege", rules.MiscPvpSiege)
	-- Always show all three faction dropdowns, including inactive '-' values. This
	-- makes inherited actions and omissions visible in a text log.
	for _, alliance in ipairs({"AD", "EP", "DC"}) do
		logRule("ALLIANCE", "pvpAlliance_" .. alliance, rules["pvpAlliance_" .. alliance])
	end
	-- Individual PvP item rules are only noisy/useful when the dropdown is not '-'.
	local configuredItems = {}
	for itemId, itemData in pairs(BMR_PVP_ITEM_CATALOG or {}) do
		local ruleName = "pvpItem_" .. tostring(itemId)
		local rule = rules[ruleName]
		if rule and rule.action and rule.action ~= ACTION_NOTSET then
			table.insert(configuredItems, {id = tonumber(itemId) or itemId, name = itemData.name, category = itemData.category, alliance = itemData.alliance, ruleName = ruleName, rule = rule})
		end
	end
	table.sort(configuredItems, function(a, b) return a.id < b.id end)
	for _, item in ipairs(configuredItems) do
		d(string.format("[BMR PvP SNAPSHOT] INDIVIDUAL itemId=%s name=%s category=%s alliance=%s rule=%s action=%s(%s) configured=true associatedGuild=%s onlyIfNotFullStack=%s onlyStacks=%s",
			tostring(item.id), tostring(item.name), tostring(item.category), tostring(item.alliance), item.ruleName,
			tostring(item.rule.action), actionLabel(item.rule.action), tostring(item.rule.associatedGuild or "<unset>"),
			boolLabel(item.rule.onlyIfNotFullStack, categoryOnlyIf == nil and true or categoryOnlyIf), tostring(item.rule.onlyStacks or categoryStacks or 1)))
	end

	local found = 0
	for _, bag in ipairs(bags) do
		local size = GetBagSize(bag.id) or 0
		local scanned = 0
		for slot = 0, size - 1 do
			local link = GetItemLink(bag.id, slot)
			local itemId = link and GetItemLinkItemId(link)
			if itemId and (BMR_PVP_ITEM_CATALOG[itemId] or itemId == 30359) then
				scanned = scanned + 1; found = found + 1
				local count, maxStack = GetSlotStackSize(bag.id, slot)
				local payload = string.match(tostring(link), "|H%d:item:([^|]+)|h") or "NO_PAYLOAD"
				local fields = {}; for field in string.gmatch(payload, "([^:]+)") do fields[#fields + 1] = field end
				local rawEnergy = tonumber(fields[20])
				local energy = GetSiegeRemainingEnergy(link)
				local ok, condition = pcall(GetItemCondition, bag.id, slot)
				local name = GetItemLinkName(link)
				local catalog = BMR_PVP_ITEM_CATALOG[itemId]
				local alliance = catalog and catalog.alliance or "-"
				local exactName = "pvpItem_" .. tostring(itemId)
				local exact = rules[exactName]
				local allianceName = catalog and catalog.alliance and ("pvpAlliance_" .. catalog.alliance) or nil
				local allianceRule = allianceName and rules[allianceName]
				local customName = "customItem_" .. tostring(itemId)
				local custom = rules[customName]
				local master = rules.MiscPvpSiege
				local chosenName, chosen, resolveReason = "NONE", nil, "no active PvP action"
				if custom and custom.action and custom.action ~= ACTION_NOTSET then chosenName, chosen, resolveReason = customName, custom, "exact custom rule"
				elseif exact and exact.action and exact.action ~= ACTION_NOTSET then chosenName, chosen, resolveReason = exactName, exact, "exact PvP item rule"
				elseif allianceRule and allianceRule.action and allianceRule.action ~= ACTION_NOTSET then chosenName, chosen, resolveReason = allianceName, allianceRule, "alliance rule inherited"
				elseif master and master.action and master.action ~= ACTION_NOTSET then chosenName, chosen, resolveReason = "MiscPvpSiege", master, "master rule inherited" end
				local effectiveOnlyIf = chosen and chosen.onlyIfNotFullStack
				if effectiveOnlyIf == nil then effectiveOnlyIf = categoryOnlyIf end
				local effectiveStacks = chosen and chosen.onlyStacks
				if effectiveStacks == nil then effectiveStacks = categoryStacks end
				local effectiveGuild = chosen and chosen.associatedGuild
				if effectiveGuild == nil then effectiveGuild = categoryGuild end
				local effectiveAction = chosen and chosen.action or ACTION_NOTSET
				local effectiveMaxStacks, stackLimitReason
				if effectiveAction == ACTION_KEEP_ONE_STACK or effectiveAction == ACTION_KEEP_ONE_STACK_BANK then
					effectiveMaxStacks, stackLimitReason = 1, "special one-stack action"
				elseif effectiveOnlyIf == true then
					effectiveMaxStacks, stackLimitReason = 1, "only-if-no-stack enabled"
				else
					effectiveMaxStacks = math.max(1, math.floor(tonumber(effectiveStacks) or 1))
					stackLimitReason = "configured maximum stacks"
				end
				local used, stateKnown, stateEnergy = GetPvpUsedState(itemId, link, bag.id, slot)
				local observedState = stateKnown and (used and "used" or "unused") or "unknown"
				d(string.format("[BMR PvP SNAPSHOT] ITEM bag=%s bagId=%s slot=%d id=%d name=%s alliance=%s category=%s count=%s/%s rawEnergy=%s parsedEnergy=%s observedState=%s stateEnergy=%s condition=%s conditionOK=%s effectiveRule=%s effectiveAction=%s(%s) resolution=%s effectiveOnlyIfNotFullStack=%s configuredMaxStacks=%s effectiveMaxStacks=%s stackLimitReason=%s effectiveGuildBank=%s exactRuleAction=%s allianceRuleAction=%s masterRuleAction=%s link=%s",
					bag.label, tostring(bag.id), slot, itemId, tostring(name), alliance, tostring(catalog and catalog.category or "Öl/other"), tostring(count), tostring(maxStack), tostring(rawEnergy), tostring(energy), observedState, tostring(stateEnergy), tostring(condition), tostring(ok), chosenName,
				tostring(effectiveAction), actionLabel(effectiveAction), resolveReason,
				boolLabel(effectiveOnlyIf, true), tostring(effectiveStacks or 1), tostring(effectiveMaxStacks), tostring(stackLimitReason), tostring(effectiveGuild or GetString(BMR_ACTION_NOTSET)),
				tostring(exact and exact.action or ACTION_NOTSET), tostring(allianceRule and allianceRule.action or ACTION_NOTSET), tostring(master and master.action or ACTION_NOTSET), tostring(link)))
			end
		end
		d(string.format("[BMR PvP SNAPSHOT] BAG bag=%s scanned=%d bagSize=%d", bag.label, scanned, size))
	end
	d(string.format("[BMR PvP SNAPSHOT] END total=%d; snapshot only, no transfers requested.", found))
end

SLASH_COMMANDS["/bmr/pvp/snapshot"] = function()
	if not db then d("[BMR PvP SNAPSHOT] Einstellungen sind noch nicht geladen."); return end
	BMR_DumpPvpStorageSnapshot("manual command")
end

local function GetBrandOilDiagnosticInfo(bagId, slotId, itemLink)
	if not (db and db.customRulesDebug == true) then return "" end
	local slotLink = GetItemLink(bagId, slotId)
	local itemId = GetItemLinkItemId(slotLink or itemLink)
	if itemId ~= 30359 then return "" end
	local details = {}
	-- Prefer the actual link returned for this slot. ESO link types vary (H0/H1),
	-- so accept any numeric type instead of assuming H1. The game chat renders
	-- link markup as its visible item name; the extracted payload below is plain text.
	local rawLink = tostring(slotLink or itemLink or "")
	local passedLink = tostring(itemLink or "")
	table.insert(details, "rawLink=" .. rawLink)
	if passedLink ~= rawLink then table.insert(details, "passedLink=" .. passedLink) end
	local payload = string.match(rawLink, "|H%d:item:([^|]+)|h")
	if not payload then payload = string.match(passedLink, "|H%d:item:([^|]+)|h") end
	if payload then
		table.insert(details, "linkPayload=" .. payload)
		local fields = {}
		for field in string.gmatch(payload, "([^:]+)") do table.insert(fields, field) end
		for i, field in ipairs(fields) do table.insert(details, "linkField" .. tostring(i) .. "=" .. field) end
	else
		table.insert(details, "linkPayload=NOT_PARSED")
	end
	local apiNames = {
		"GetItemLinkRequiredLevel", "GetItemLinkRequiredChampionPoints", "GetItemLinkQuality",
		"GetItemLinkValue", "GetItemLinkWeaponPower", "GetItemLinkArmor", "GetItemLinkTraitInfo",
		"GetItemLinkEnchantInfo", "GetItemLinkItemType", "GetItemLinkSpecializedType",
		"GetItemLinkSetInfo", "GetItemLinkOnUseAbilityInfo", "GetItemLinkFlavorText",
		"GetItemLinkFunctionalQuality",
	}
	for _, apiName in ipairs(apiNames) do
		local api = _G and _G[apiName]
		if type(api) == "function" then
			local ok, a, b, c, d, e = pcall(api, slotLink or itemLink)
			if ok then
				local values = {}
				local returned = {a, b, c, d, e}
				for i = 1, 5 do
					if returned[i] ~= nil then table.insert(values, tostring(returned[i])) end
				end
				table.insert(details, apiName .. "=" .. (#values > 0 and table.concat(values, "/") or "nil"))
			else
				table.insert(details, apiName .. "=ERROR:" .. tostring(a))
			end
		end
	end
	return table.concat(details, ", ")
end

-- Resolve item names from ESO's own localized item database. The synthetic item
-- link deliberately contains the item ID and neutral values; GetItemLinkName
-- returns the client's localized display name. The English item name is kept
-- as a source comment on each catalog row for maintainer readability.
local function GetPvpCatalogItemName(itemId)
	local fallback = "Item " .. tostring(itemId)
	if type(GetItemLinkName) ~= "function" then return fallback end
	local itemLink = string.format("|H1:item:%d:1:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", tonumber(itemId) or 0)
	return FormatCustomItemName(itemLink, fallback) or fallback
end

-- PvP siege equipment catalog generated from the ItemFinder scan (2026-10-16).
BMR_PVP_ITEM_CATALOG = {
	[27970] = {category = "Ballisten", alliance = "AD", name = GetPvpCatalogItemName(27970), specializedType = 401}, -- Aldmeri Dominion Fire Bolt Ballista
	[27971] = {category = "Ballisten", alliance = "EP", name = GetPvpCatalogItemName(27971), specializedType = 401}, -- Ebonheart Pact Fire Bolt Ballista
	[27972] = {category = "Ballisten", alliance = "DC", name = GetPvpCatalogItemName(27972), specializedType = 401}, -- Daggerfall Covenant Fire Bolt Ballista
	[27973] = {category = "Ballisten", alliance = "AD", name = GetPvpCatalogItemName(27973), specializedType = 401}, -- Aldmeri Dominion Lightning Ballista
	[27974] = {category = "Ballisten", alliance = "EP", name = GetPvpCatalogItemName(27974), specializedType = 401}, -- Ebonheart Pact Lightning Ballista
	[27975] = {category = "Ballisten", alliance = "DC", name = GetPvpCatalogItemName(27975), specializedType = 401}, -- Daggerfall Covenant Lightning Ballista
	[36567] = {category = "Ballisten", alliance = "AD", name = GetPvpCatalogItemName(36567), specializedType = 401}, -- Aldmeri Dominion Ballista
	[36568] = {category = "Ballisten", alliance = "EP", name = GetPvpCatalogItemName(36568), specializedType = 401}, -- Ebonheart Pact Ballista
	[36569] = {category = "Ballisten", alliance = "DC", name = GetPvpCatalogItemName(36569), specializedType = 401}, -- Daggerfall Covenant Ballista
	[64515] = {category = "Ballisten", alliance = "AD", name = GetPvpCatalogItemName(64515), specializedType = 401}, -- Aldmeri Dominion Cold Fire Ballista
	[64516] = {category = "Ballisten", alliance = "EP", name = GetPvpCatalogItemName(64516), specializedType = 401}, -- Ebonheart Pact Cold Fire Ballista
	[64517] = {category = "Ballisten", alliance = "DC", name = GetPvpCatalogItemName(64517), specializedType = 401}, -- Daggerfall Covenant Cold Fire Ballista
	[214323] = {category = "Ballisten", alliance = "AD", name = GetPvpCatalogItemName(214323), specializedType = 401}, -- Aldmeri Dominion Ballista of Vengeance
	[214324] = {category = "Ballisten", alliance = "EP", name = GetPvpCatalogItemName(214324), specializedType = 401}, -- Ebonheart Pact Ballista of Vengeance
	[214325] = {category = "Ballisten", alliance = "DC", name = GetPvpCatalogItemName(214325), specializedType = 401}, -- Daggerfall Covenant Ballista of Vengeance
	[223697] = {category = "Ballisten", alliance = "AD", name = GetPvpCatalogItemName(223697), specializedType = 401}, -- Aldmeri Dominion Cold Fire Ballista of Vengeance
	[223768] = {category = "Ballisten", alliance = "EP", name = GetPvpCatalogItemName(223768), specializedType = 401}, -- Ebonheart Pact Cold Fire Ballista of Vengeance
	[223770] = {category = "Ballisten", alliance = "DC", name = GetPvpCatalogItemName(223770), specializedType = 401}, -- Daggerfall Covenant Cold Fire Ballista of Vengeance
	[225005] = {category = "Ballisten", alliance = "AD", name = GetPvpCatalogItemName(225005), specializedType = 401}, -- Devastating Aldmeri Dominion Fire Bolt Ballista
	[225006] = {category = "Ballisten", alliance = "AD", name = GetPvpCatalogItemName(225006), specializedType = 401}, -- Annihilating Aldmeri Dominion Fire Bolt Ballista
	[225007] = {category = "Ballisten", alliance = "AD", name = GetPvpCatalogItemName(225007), specializedType = 401}, -- Deadly Aldmeri Dominion Fire Bolt Ballista
	[225008] = {category = "Ballisten", alliance = "EP", name = GetPvpCatalogItemName(225008), specializedType = 401}, -- Devastating Ebonheart Pact Fire Bolt Ballista
	[225009] = {category = "Ballisten", alliance = "EP", name = GetPvpCatalogItemName(225009), specializedType = 401}, -- Annihilating Ebonheart Pact Fire Bolt Ballista
	[225010] = {category = "Ballisten", alliance = "EP", name = GetPvpCatalogItemName(225010), specializedType = 401}, -- Deadly Ebonheart Pact Fire Bolt Ballista
	[225011] = {category = "Ballisten", alliance = "DC", name = GetPvpCatalogItemName(225011), specializedType = 401}, -- Devastating Daggerfall Covenant Fire Bolt Ballista
	[225012] = {category = "Ballisten", alliance = "DC", name = GetPvpCatalogItemName(225012), specializedType = 401}, -- Annihilating Daggerfall Covenant Fire Bolt Ballista
	[225013] = {category = "Ballisten", alliance = "DC", name = GetPvpCatalogItemName(225013), specializedType = 401}, -- Deadly Daggerfall Covenant Fire Bolt Ballista
	[225456] = {category = "Ballisten", alliance = "AD", name = GetPvpCatalogItemName(225456), specializedType = 401}, -- Aldmeri Dominion Fire Bolt Ballista of Vengeance
	[225457] = {category = "Ballisten", alliance = "EP", name = GetPvpCatalogItemName(225457), specializedType = 401}, -- Ebonheart Pact Fire Bolt Ballista of Vengeance
	[225458] = {category = "Ballisten", alliance = "DC", name = GetPvpCatalogItemName(225458), specializedType = 401}, -- Daggerfall Covenant Fire Bolt Ballista of Vengeance
	[29533] = {category = "Feldlager", alliance = "AD", name = GetPvpCatalogItemName(29533), specializedType = 405}, -- Aldmeri Dominion Forward Camp
	[29534] = {category = "Feldlager", alliance = "EP", name = GetPvpCatalogItemName(29534), specializedType = 405}, -- Ebonheart Pact Forward Camp
	[29535] = {category = "Feldlager", alliance = "DC", name = GetPvpCatalogItemName(29535), specializedType = 405}, -- Daggerfall Covenant Forward Camp
	[44920] = {category = "Feldlager", alliance = "AD", name = GetPvpCatalogItemName(44920), specializedType = 405}, -- Limited Aldmeri Dominion Forward Camp
	[44921] = {category = "Feldlager", alliance = "EP", name = GetPvpCatalogItemName(44921), specializedType = 405}, -- Limited Ebonheart Pact Forward Camp
	[44922] = {category = "Feldlager", alliance = "DC", name = GetPvpCatalogItemName(44922), specializedType = 405}, -- Limited Daggerfall Covenant Forward Camp
	[214346] = {category = "Feldlager", alliance = "AD", name = GetPvpCatalogItemName(214346), specializedType = 405}, -- Aldmeri Dominion Forward Camp of Vengeance
	[214347] = {category = "Feldlager", alliance = "EP", name = GetPvpCatalogItemName(214347), specializedType = 405}, -- Ebonheart Pact Forward Camp of Vengeance
	[214348] = {category = "Feldlager", alliance = "DC", name = GetPvpCatalogItemName(214348), specializedType = 405}, -- Daggerfall Covenant Forward Camp of Vengeance
	[27964] = {category = "Katapult", alliance = "AD", name = GetPvpCatalogItemName(27964), specializedType = 404}, -- Aldmeri Dominion Meatbag Catapult
	[27965] = {category = "Katapult", alliance = "EP", name = GetPvpCatalogItemName(27965), specializedType = 404}, -- Ebonheart Pact Meatbag Catapult
	[27966] = {category = "Katapult", alliance = "DC", name = GetPvpCatalogItemName(27966), specializedType = 404}, -- Daggerfall Covenant Meatbag Catapult
	[27967] = {category = "Katapult", alliance = "AD", name = GetPvpCatalogItemName(27967), specializedType = 404}, -- Aldmeri Dominion Oil Catapult
	[27968] = {category = "Katapult", alliance = "EP", name = GetPvpCatalogItemName(27968), specializedType = 404}, -- Ebonheart Pact Oil Catapult
	[27969] = {category = "Katapult", alliance = "DC", name = GetPvpCatalogItemName(27969), specializedType = 404}, -- Daggerfall Covenant Oil Catapult
	[44770] = {category = "Katapult", alliance = "AD", name = GetPvpCatalogItemName(44770), specializedType = 404}, -- Aldmeri Dominion Scattershot Catapult
	[44773] = {category = "Katapult", alliance = "DC", name = GetPvpCatalogItemName(44773), specializedType = 404}, -- Daggerfall Covenant Scattershot Catapult
	[44777] = {category = "Katapult", alliance = "EP", name = GetPvpCatalogItemName(44777), specializedType = 404}, -- Ebonheart Pact Scattershot Catapult
	[219145] = {category = "Katapult", alliance = "AD", name = GetPvpCatalogItemName(219145), specializedType = 404}, -- Aldmeri Dominion Meatbag Catapult of Vengeance
	[219146] = {category = "Katapult", alliance = "EP", name = GetPvpCatalogItemName(219146), specializedType = 404}, -- Ebonheart Pact Meatbag Catapult of Vengeance
	[219147] = {category = "Katapult", alliance = "DC", name = GetPvpCatalogItemName(219147), specializedType = 404}, -- Daggerfall Covenant Meatbag Catapult of Vengeance
	[223688] = {category = "Katapult", alliance = "AD", name = GetPvpCatalogItemName(223688), specializedType = 404}, -- Aldmeri Dominion Oil Catapult of Vengeance
	[223689] = {category = "Katapult", alliance = "EP", name = GetPvpCatalogItemName(223689), specializedType = 404}, -- Ebonheart Pact Oil Catapult of Vengeance
	[223690] = {category = "Katapult", alliance = "DC", name = GetPvpCatalogItemName(223690), specializedType = 404}, -- Daggerfall Covenant Oil Catapult of Vengeance
	[223694] = {category = "Katapult", alliance = "AD", name = GetPvpCatalogItemName(223694), specializedType = 404}, -- Aldmeri Dominion Scattershot Catapult of Vengeance
	[223695] = {category = "Katapult", alliance = "DC", name = GetPvpCatalogItemName(223695), specializedType = 404}, -- Daggerfall Covenant Scattershot Catapult of Vengeance
	[223696] = {category = "Katapult", alliance = "EP", name = GetPvpCatalogItemName(223696), specializedType = 404}, -- Ebonheart Pact Scattershot Catapult of Vengeance
	[225065] = {category = "Katapult", alliance = "AD", name = GetPvpCatalogItemName(225065), specializedType = 404}, -- Devastating Aldmeri Dominion Meatbag Catapult
	[225066] = {category = "Katapult", alliance = "AD", name = GetPvpCatalogItemName(225066), specializedType = 404}, -- Annihilating Aldmeri Dominion Meatbag Catapult
	[225067] = {category = "Katapult", alliance = "AD", name = GetPvpCatalogItemName(225067), specializedType = 404}, -- Deadly Aldmeri Dominion Meatbag Catapult
	[225068] = {category = "Katapult", alliance = "EP", name = GetPvpCatalogItemName(225068), specializedType = 404}, -- Devastating Ebonheart Pact Meatbag Catapult
	[225069] = {category = "Katapult", alliance = "EP", name = GetPvpCatalogItemName(225069), specializedType = 404}, -- Devastating Ebonheart Pact Meatbag Catapult
	[225072] = {category = "Katapult", alliance = "DC", name = GetPvpCatalogItemName(225072), specializedType = 404}, -- Annihilating Daggerfall Covenant Meatbag Catapult
	[225073] = {category = "Katapult", alliance = "DC", name = GetPvpCatalogItemName(225073), specializedType = 404}, -- Deadly Daggerfall Covenant Meatbag Catapult
	[160528] = {category = "Lancier", alliance = "AD", name = GetPvpCatalogItemName(160528), specializedType = 409}, -- Aldmeri Dominion Fire Lancer
	[160529] = {category = "Lancier", alliance = "EP", name = GetPvpCatalogItemName(160529), specializedType = 409}, -- Ebonheart Pact Fire Lancer
	[160530] = {category = "Lancier", alliance = "DC", name = GetPvpCatalogItemName(160530), specializedType = 409}, -- Daggerfall Covenant Fire Lancer
	[160531] = {category = "Lancier", alliance = "AD", name = GetPvpCatalogItemName(160531), specializedType = 409}, -- Aldmeri Dominion Shock Lancer
	[160532] = {category = "Lancier", alliance = "EP", name = GetPvpCatalogItemName(160532), specializedType = 409}, -- Ebonheart Pact Shock Lancer
	[160533] = {category = "Lancier", alliance = "DC", name = GetPvpCatalogItemName(160533), specializedType = 409}, -- Daggerfall Covenant Shock Lancer
	[160534] = {category = "Lancier", alliance = "AD", name = GetPvpCatalogItemName(160534), specializedType = 409}, -- Aldmeri Dominion Frost Lancer
	[160535] = {category = "Lancier", alliance = "EP", name = GetPvpCatalogItemName(160535), specializedType = 409}, -- Ebonheart Pact Frost Lancer
	[160536] = {category = "Lancier", alliance = "DC", name = GetPvpCatalogItemName(160536), specializedType = 409}, -- Daggerfall Covenant Frost Lancer
	[30359] = {category = "Öl", alliance = "fraktionsunabhängig", name = GetPvpCatalogItemName(30359), specializedType = 407}, -- Siege Oil
	[214329] = {category = "Öl", alliance = "fraktionsunabhängig", name = GetPvpCatalogItemName(214329), specializedType = 407}, -- Flaming Oil of Vengeance
	[27136] = {category = "Rammbock", alliance = "AD", name = GetPvpCatalogItemName(27136), specializedType = 402}, -- Aldmeri Dominion Battering Ram
	[27835] = {category = "Rammbock", alliance = "DC", name = GetPvpCatalogItemName(27835), specializedType = 402}, -- Daggerfall Covenant Battering Ram
	[27850] = {category = "Rammbock", alliance = "EP", name = GetPvpCatalogItemName(27850), specializedType = 402}, -- Ebonheart Pact Battering Ram
	[214326] = {category = "Rammbock", alliance = "AD", name = GetPvpCatalogItemName(214326), specializedType = 402}, -- Aldmeri Dominion Battering Ram of Vengeance
	[214327] = {category = "Rammbock", alliance = "DC", name = GetPvpCatalogItemName(214327), specializedType = 402}, -- Daggerfall Covenant Battering Ram of Vengeance
	[214328] = {category = "Rammbock", alliance = "EP", name = GetPvpCatalogItemName(214328), specializedType = 402}, -- Ebonheart Pact Battering Ram of Vengeance
	[27105] = {category = "Tribok", alliance = "AD", name = GetPvpCatalogItemName(27105), specializedType = 400}, -- Aldmeri Dominion Firepot Trebuchet
	[27114] = {category = "Tribok", alliance = "EP", name = GetPvpCatalogItemName(27114), specializedType = 400}, -- Ebonheart Pact Firepot Trebuchet
	[27115] = {category = "Tribok", alliance = "DC", name = GetPvpCatalogItemName(27115), specializedType = 400}, -- Daggerfall Covenant Firepot Trebuchet
	[44768] = {category = "Tribok", alliance = "AD", name = GetPvpCatalogItemName(44768), specializedType = 400}, -- Aldmeri Dominion Iceball Trebuchet
	[44769] = {category = "Tribok", alliance = "AD", name = GetPvpCatalogItemName(44769), specializedType = 400}, -- Aldmeri Dominion Stone Trebuchet
	[44771] = {category = "Tribok", alliance = "DC", name = GetPvpCatalogItemName(44771), specializedType = 400}, -- Daggerfall Covenant Iceball Trebuchet
	[44772] = {category = "Tribok", alliance = "DC", name = GetPvpCatalogItemName(44772), specializedType = 400}, -- Daggerfall Covenant Stone Trebuchet
	[44775] = {category = "Tribok", alliance = "EP", name = GetPvpCatalogItemName(44775), specializedType = 400}, -- Ebonheart Pact Iceball Trebuchet
	[44776] = {category = "Tribok", alliance = "EP", name = GetPvpCatalogItemName(44776), specializedType = 400}, -- Ebonheart Pact Stone Trebuchet
	[64512] = {category = "Tribok", alliance = "AD", name = GetPvpCatalogItemName(64512), specializedType = 400}, -- Aldmeri Dominion Cold Fire Trebuchet
	[64513] = {category = "Tribok", alliance = "EP", name = GetPvpCatalogItemName(64513), specializedType = 400}, -- Ebonheart Pact Cold Fire Trebuchet
	[64514] = {category = "Tribok", alliance = "DC", name = GetPvpCatalogItemName(64514), specializedType = 400}, -- Daggerfall Covenant Cold Fire Trebuchet
	[64518] = {category = "Tribok", alliance = "DC", name = GetPvpCatalogItemName(64518), specializedType = 400}, -- Daggerfall Covenant Cold Stone Trebuchet
	[64519] = {category = "Tribok", alliance = "EP", name = GetPvpCatalogItemName(64519), specializedType = 400}, -- Ebonheart Pact Cold Stone Trebuchet
	[64520] = {category = "Tribok", alliance = "AD", name = GetPvpCatalogItemName(64520), specializedType = 400}, -- Aldmeri Dominion Cold Stone Trebuchet
	[214296] = {category = "Tribok", alliance = "EP", name = GetPvpCatalogItemName(214296), specializedType = 400}, -- Ebonheart Pact Firepot Trebuchet
	[214318] = {category = "Tribok", alliance = "AD", name = GetPvpCatalogItemName(214318), specializedType = 400}, -- Aldmeri Dominion Stone Trebuchet of Vengeance
	[214319] = {category = "Tribok", alliance = "EP", name = GetPvpCatalogItemName(214319), specializedType = 400}, -- Ebonheart Pact Stone Trebuchet of Vengeance
	[214320] = {category = "Tribok", alliance = "DC", name = GetPvpCatalogItemName(214320), specializedType = 400}, -- Daggerfall Covenant Stone Trebuchet of Vengeance
	[223714] = {category = "Tribok", alliance = "AD", name = GetPvpCatalogItemName(223714), specializedType = 400}, -- Aldmeri Dominion Cold Fire Trebuchet of Vengeance
	[223769] = {category = "Tribok", alliance = "EP", name = GetPvpCatalogItemName(223769), specializedType = 400}, -- Ebonheart Pact Cold Fire Trebuchet of Vengeance
	[223771] = {category = "Tribok", alliance = "DC", name = GetPvpCatalogItemName(223771), specializedType = 400}, -- Daggerfall Covenant Cold Fire Trebuchet of Vengeance
	[224990] = {category = "Tribok", alliance = "AD", name = GetPvpCatalogItemName(224990), specializedType = 400}, -- Devastating Aldmeri Dominion Stone Trebuchet
	[224991] = {category = "Tribok", alliance = "AD", name = GetPvpCatalogItemName(224991), specializedType = 400}, -- Annihilating Aldmeri Dominion Stone Trebuchet
	[224992] = {category = "Tribok", alliance = "AD", name = GetPvpCatalogItemName(224992), specializedType = 400}, -- Deadly Aldmeri Dominion Stone Trebuchet
	[224993] = {category = "Tribok", alliance = "EP", name = GetPvpCatalogItemName(224993), specializedType = 400}, -- Devastating Ebonheart Pact Stone Trebuchet
	[224994] = {category = "Tribok", alliance = "EP", name = GetPvpCatalogItemName(224994), specializedType = 400}, -- Annihilating Ebonheart Pact Stone Trebuchet
	[224995] = {category = "Tribok", alliance = "EP", name = GetPvpCatalogItemName(224995), specializedType = 400}, -- Deadly Ebonheart Pact Stone Trebuchet
	[224996] = {category = "Tribok", alliance = "DC", name = GetPvpCatalogItemName(224996), specializedType = 400}, -- Devastating Daggerfall Covenant Stone Trebuchet
	[224997] = {category = "Tribok", alliance = "DC", name = GetPvpCatalogItemName(224997), specializedType = 400}, -- Annihilating Daggerfall Covenant Stone Trebuchet
	[224998] = {category = "Tribok", alliance = "DC", name = GetPvpCatalogItemName(224998), specializedType = 400}, -- Deadly Daggerfall Covenant Stone Trebuchet
	[225459] = {category = "Tribok", alliance = "AD", name = GetPvpCatalogItemName(225459), specializedType = 400}, -- Aldmeri Dominion Firepot Trebuchet of Vengeance
	[225460] = {category = "Tribok", alliance = "EP", name = GetPvpCatalogItemName(225460), specializedType = 400}, -- Ebonheart Pact Firepot Trebuchet of Vengeance
	[225461] = {category = "Tribok", alliance = "DC", name = GetPvpCatalogItemName(225461), specializedType = 400}, -- Daggerfall Covenant Firepot Trebuchet of Vengeance
}

-- Category labels use ESO's localized specialized-item-type strings. Oil is a
-- named group rather than an item subtype, so its heading is the localized name
-- for the familiar Brand Oil item itself.
local BMR_PVP_CATEGORY_SPECIALIZED_TYPES = {
	["Ballisten"] = 401,
	["Feldlager"] = 405,
	["Katapult"] = 404,
	["Lancier"] = 409,
	["Rammbock"] = 402,
	["Tribok"] = 400,
}
local BMR_PVP_CATEGORY_ENGLISH_FALLBACKS = {
	["Ballisten"] = "Ballistae",
	["Feldlager"] = "Forward Camps",
	["Katapult"] = "Catapults",
	["Lancier"] = "Lancers",
	["Rammbock"] = "Battering Rams",
	["Tribok"] = "Trebuchets",
}
local function GetPvpCategoryDisplayName(categoryName)
	if categoryName == "Öl" then return GetPvpCatalogItemName(30359) end
	local specializedType = BMR_PVP_CATEGORY_SPECIALIZED_TYPES[categoryName]
	if specializedType and type(GetString) == "function" then
		local ok, localizedName = pcall(GetString, "SI_SPECIALIZEDITEMTYPE", specializedType)
		if ok and type(localizedName) == "string" and localizedName ~= "" then
			return localizedName
		end
	end
	return BMR_PVP_CATEGORY_ENGLISH_FALLBACKS[categoryName] or tostring(categoryName)
end

-- Count individual siege item rules with an action other than "-". This is
-- used by each collapsible category header so the summary stays visible while
-- the category is closed and updates whenever LAM refreshes after a selection.
local function GetPvpCategoryRuleCounts(categoryName)
	local activeCount, totalCount = 0, 0
	local profile = db and db.profiles and db.profiles[actualProfile]
	local profileRules = profile and profile.rules or {}
	for itemId, itemData in pairs(BMR_PVP_ITEM_CATALOG or {}) do
		if itemData.category == categoryName then
			totalCount = totalCount + 1
			local rule = profileRules["pvpItem_" .. tostring(itemId)]
			if rule and rule.action ~= nil and rule.action ~= ACTION_NOTSET then
				activeCount = activeCount + 1
			end
		end
	end
	return activeCount, totalCount
end

local function GetPvpCategoryRuleCountText(categoryName)
	local activeCount, totalCount = GetPvpCategoryRuleCounts(categoryName)
	return zo_strformat(GetString(BMR_PVP_RULES_ACTIVE), activeCount, totalCount)
end

-- Defaults structure for SavedVariables.
-- Profiles are created on demand instead of keeping dozens of empty profile
-- definitions in the defaults table.
local PROFILE_MIN = 1
local PROFILE_DEFAULT_COUNT = 1
local PROFILE_MAX = 100

local function NewProfile(defined)
	return {
		name = "",
		defined = defined == true,
		autoTransfert = true,
		detailledDisplay = true,
		summary = true,
		protected = true,
		moved = true,
		detailledNotMoved = true,
		initialWaitInSecs = 2,
		overfill = 0,
		pauseInMs = 0,
		userRules = "",
		userRulesAfter = false,
		pvpPriorityState = "unused",
	}
end

local defaults = {
	worldname = GetWorldName(),
	actualProfile = {},
	globalAddonProfile = 1,
	pvpSortMode = "weaponType",
	gui_x = -600,
	gui_y = -400,
	profileCount = PROFILE_DEFAULT_COUNT,
	profileCountInitialized = false,
	customItemRules = {},
	customFilterRules = {},
	customFilterDraft = {searchString = "", specifications = {}},
	customItemTagCatalog = {},
	customItemTagScan = {nextId = 1, maxId = 400000, completed = false},
	profileDebugEnabled = false,
	profileDebugLog = {},
	hideSetAsBmrRule = false,
	scriptTracker = {
		enabled = true,
		depositKnown = true,
		withdrawUnknown = true,
		withdrawOneOnly = true,
		debug = false,
	},
	profiles = {
		[1] = NewProfile(true),
	}
}

local function DeepCopy(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = DeepCopy(child)
	end
	return copy
end

local function EnsureProfile(profileIndex, defined)
	if profileIndex < PROFILE_MIN or profileIndex > PROFILE_MAX then return nil end
	if not db.profiles[profileIndex] then
		db.profiles[profileIndex] = NewProfile(defined)
	end
	local profile = db.profiles[profileIndex]
	local template = NewProfile(false)
	for key, value in pairs(template) do
		if profile[key] == nil then
			profile[key] = value
		end
	end
	if defined == true then
		profile.defined = true
	end
	if BankManagerRules and BankManagerRules.defaults and not profile.rules then
		profile.rules = DeepCopy(BankManagerRules.defaults)
	end
	profile.rules = profile.rules or {}
	profile.pvpPriorityState = profile.pvpPriorityState or "unused"
	profile.rules.pvpAlliance_AD = profile.rules.pvpAlliance_AD or {action = ACTION_NOTSET, associatedGuild = GetString(BMR_ACTION_NOTSET), onlyIfNotFullStack = true, onlyStacks = 1}
	profile.rules.pvpAlliance_EP = profile.rules.pvpAlliance_EP or {action = ACTION_NOTSET, associatedGuild = GetString(BMR_ACTION_NOTSET), onlyIfNotFullStack = true, onlyStacks = 1}
	profile.rules.pvpAlliance_DC = profile.rules.pvpAlliance_DC or {action = ACTION_NOTSET, associatedGuild = GetString(BMR_ACTION_NOTSET), onlyIfNotFullStack = true, onlyStacks = 1}
	profile.rules.customItemsAll = profile.rules.customItemsAll or {
		action = ACTION_NOTSET,
		associatedGuild = GetString(BMR_ACTION_NOTSET),
		onlyIfNotFullStack = true,
		onlyStacks = 1,
	}
	profile.rules.customFilterAll = profile.rules.customFilterAll or {
		action = ACTION_NOTSET,
		associatedGuild = GetString(BMR_ACTION_NOTSET),
		onlyIfNotFullStack = true,
		onlyStacks = 1,
	}
	for filterId, filterData in pairs(db.customFilterRules or {}) do
		local ruleName = "customFilter_" .. tostring(filterId)
		if profile.rules[ruleName] == nil then
			profile.rules[ruleName] = {
				action = ACTION_NOTSET,
				associatedGuild = profile.rules.customFilterAll.associatedGuild or GetString(BMR_ACTION_NOTSET),
				onlyIfNotFullStack = profile.rules.customFilterAll.onlyIfNotFullStack ~= false,
				onlyStacks = tonumber(profile.rules.customFilterAll.onlyStacks) or 1,
			}
		end
	end
	for itemId, itemData in pairs(db.customItemRules or {}) do
		local ruleName = "customItem_" .. tostring(itemId)
		if profile.rules[ruleName] == nil then
			profile.rules[ruleName] = {
				action = ACTION_NOTSET,
				associatedGuild = profile.rules.customItemsAll.associatedGuild or GetString(BMR_ACTION_NOTSET),
				onlyIfNotFullStack = profile.rules.customItemsAll.onlyIfNotFullStack ~= false,
				onlyStacks = tonumber(profile.rules.customItemsAll.onlyStacks) or 1,
			}
		end
	end
	return profile
end

local function EnsureProfiles()
	db.profileCount = tonumber(db.profileCount) or PROFILE_DEFAULT_COUNT
	db.profileCount = math.max(PROFILE_MIN, math.min(PROFILE_MAX, db.profileCount))

	-- One-time migration: if an older installation had profiles beyond the
	-- former hard-coded range, keep them visible automatically.
	if db.profileCountInitialized ~= true then
		local highestDefined = 1
		for index, profile in pairs(db.profiles or {}) do
			index = tonumber(index)
			if index and index >= 1 and index <= PROFILE_MAX and type(profile) == "table" and profile.defined then
				highestDefined = math.max(highestDefined, index)
			end
		end
		db.profileCount = math.max(db.profileCount, highestDefined)
		db.profileCountInitialized = true
	end

	for index = 1, db.profileCount do
		EnsureProfile(index, index == 1)
	end
end

-- Core state must not depend on LAM/LHAS registration succeeding. In Forced
-- Console Flow, a settings adapter can fail before the normal settings builder
-- reaches its old SavedVariables block; bank events/profile selection still need
-- valid SavedVariables and profile 1 in that case.
local function InitializeCoreProfileStore()
	if BMR._coreProfileStoreReady == true and type(db) == "table" and type(db.profiles) == "table" then return true end
	BMR._profileStartupPhase = "savedvariables-init"
	ZO_SavedVars:NewCharacterIdSettings("BMVars", 5, nil, nil, nil)
	local loadedDb = ZO_SavedVars:NewAccountWide("BMVars", 1, nil, defaults, nil)
	if type(loadedDb) ~= "table" then error("ZO_SavedVars:NewAccountWide did not return a table") end
	db = loadedDb
	BMR._profileDebugSavedVarsReady = true
	db.profileDebugEnabled = db.profileDebugEnabled == true
	db.profileDebugLog = type(db.profileDebugLog) == "table" and db.profileDebugLog or {}
	BMR.ProfileDiagnosticFlushPreInit()
	db.actualProfile = type(db.actualProfile) == "table" and db.actualProfile or {}
	db.profiles = type(db.profiles) == "table" and db.profiles or {}
	db.customItemRules = type(db.customItemRules) == "table" and db.customItemRules or {}
	db.customFilterRules = type(db.customFilterRules) == "table" and db.customFilterRules or {}
	db.customFilterDraft = type(db.customFilterDraft) == "table" and db.customFilterDraft or {searchString = "", specifications = {}}
	db.customFilterDraft.specifications = type(db.customFilterDraft.specifications) == "table" and db.customFilterDraft.specifications or {}
	db.customFilterDraft.editingId = tonumber(db.customFilterDraft.editingId)
	db.hideSetAsBmrRule = db.hideSetAsBmrRule == true
	db.scriptTracker = type(db.scriptTracker) == "table" and db.scriptTracker or {}
	db.scriptTracker.enabled = db.scriptTracker.enabled ~= false
	db.scriptTracker.depositKnown = db.scriptTracker.depositKnown ~= false
	db.scriptTracker.withdrawUnknown = db.scriptTracker.withdrawUnknown ~= false
	db.scriptTracker.withdrawOneOnly = db.scriptTracker.withdrawOneOnly ~= false
	db.scriptTracker.debug = db.scriptTracker.debug == true
	db.pvpSortMode = (db.pvpSortMode == "alliance") and "alliance" or "weaponType"
	EnsureProfiles()
	local characterName = GetUnitName("player")
	if type(characterName) ~= "string" or characterName == "" then characterName = nil end
	if characterName and db.actualProfile[characterName] == nil then db.actualProfile[characterName] = 1 end
	actualProfile = characterName and (tonumber(db.actualProfile[characterName]) or 1) or 1
	if actualProfile < PROFILE_MIN or actualProfile > db.profileCount then
		actualProfile = 1
		if characterName then db.actualProfile[characterName] = 1 end
	end
	EnsureProfile(actualProfile, false)
	BMR._coreProfileStoreReady = true
	BMR._profileStartupPhase = "core-profile-store-ready"
	BMR.ProfileDiagnostic("CORE_PROFILE_STORE_READY", BMR.ProfileDebugSnapshot())
	return true
end

function BMR.ProfileDebugControlState(controlName)
	if not BankManager or type(BankManager.GetNamedChild) ~= "function" then return "parent-missing" end
	local ok, control = pcall(BankManager.GetNamedChild, BankManager, controlName)
	if not ok then return "lookup-error" end
	if not control then return "missing" end
	local hidden = "unknown"
	if type(control.IsHidden) == "function" then
		local hiddenOk, hiddenValue = pcall(control.IsHidden, control)
		if hiddenOk then hidden = tostring(hiddenValue) end
	end
	local textValue = ""
	if type(control.GetText) == "function" then
		local textOk, value = pcall(control.GetText, control)
		if textOk then textValue = tostring(value or "") end
	end
	return "exists(hidden=" .. hidden .. (textValue ~= "" and ",text=" .. textValue or "") .. ")"
end

function BMR.ProfileDebugSnapshot()
	local currentCharacter = BMR.ProfileDebugSafeGetter("GetUnitName")
	if type(GetUnitName) == "function" then
		local ok, value = pcall(GetUnitName, "player")
		if ok and value ~= nil then currentCharacter = tostring(value) end
	end
	local count = tonumber(db and db.profileCount) or 0
	local defined = {}
	local profileStore = type(db) == "table" and type(db.profiles) == "table" and db.profiles or {}
	for index = 1, PROFILE_MAX do
		local profile = profileStore[index] or profileStore[tostring(index)]
		if type(profile) == "table" and profile.defined == true then
			defined[#defined + 1] = tostring(index) .. (type(profile.name) == "string" and profile.name ~= "" and (":" .. profile.name) or "")
		end
	end
	local current = tonumber(actualProfile) or -1
	local activeProfile = profileStore[current] or profileStore[tostring(current)]
	local activeRuleCount = 0
	if type(activeProfile) == "table" and type(activeProfile.rules) == "table" then
		for _ in pairs(activeProfile.rules) do activeRuleCount = activeRuleCount + 1 end
	end
	local mapped = type(db) == "table" and type(db.actualProfile) == "table" and db.actualProfile[currentCharacter] or nil
	local rootHidden = "unknown"
	if BankManager and type(BankManager.IsHidden) == "function" then
		local ok, value = pcall(BankManager.IsHidden, BankManager)
		if ok then rootHidden = tostring(value) end
	end
	return string.format("account=%s character=%s world=%s db=%s profileCount=%s countInitialized=%s defined=[%s] actualProfile=%s mappedProfile=%s activeExists=%s activeDefined=%s activeName=%s activeRuleCount=%d autoTransfert=%s initialWaitInSecs=%s isBanking=%s checkingGBank=%s inProgress=%s transferPhase=%s BankManager(hidden=%s) Before=%s After=%s RuleName=%s",
		BMR.ProfileDebugSafeGetter("GetDisplayName"), currentCharacter, BMR.ProfileDebugSafeGetter("GetWorldName"),
		tostring(type(db) == "table"), tostring(count), tostring(type(db) == "table" and db.profileCountInitialized),
		table.concat(defined, ","), tostring(current), tostring(mapped), tostring(type(activeProfile) == "table"),
		tostring(type(activeProfile) == "table" and activeProfile.defined),
		tostring(type(activeProfile) == "table" and activeProfile.name or "<nil>"), activeRuleCount,
		tostring(type(activeProfile) == "table" and activeProfile.autoTransfert),
		tostring(type(activeProfile) == "table" and activeProfile.initialWaitInSecs),
		tostring(isBanking), tostring(checkingGBank), tostring(inProgress), tostring(activeRuleRunPhase),
		rootHidden, BMR.ProfileDebugControlState("Before"), BMR.ProfileDebugControlState("After"), BMR.ProfileDebugControlState("RuleName"))
end

function BMR.ProfileDiagnosticDump()
	if type(db) == "table" and db.profileDebugEnabled == true then
		BMR.ProfileDiagnostic("MANUAL_DUMP", BMR.ProfileDebugSnapshot())
	end
	BMR.ProfileDiagnosticChat("Status: " .. BMR.ProfileDebugSnapshot())
	local log = type(db) == "table" and type(db.profileDebugLog) == "table" and db.profileDebugLog or {}
	if #log == 0 then
		BMR.ProfileDiagnosticChat("Noch keine gespeicherten Ereignisse. Diagnose aktivieren und /reloadui ausführen.")
		return
	end
	local first = math.max(1, #log - 39)
	BMR.ProfileDiagnosticChat(string.format("Letzte %d von %d gespeicherten Ereignissen:", #log - first + 1, #log))
	for index = first, #log do BMR.ProfileDiagnosticChat(log[index]) end
end

-- Filter matching and rule registration live in BankManagerCustomRules.lua.

-- Add exact-item custom rules to the same rule registry used by the normal transfer engine.
local function SyncCustomItemRuleDefinitions()
	if BMR.CustomRules then
		BMR.CustomRules.SyncExactItemRuleDefinitions()
	end
-- Register every scanned PvP siege item as an exact-ID rule. These remain
	-- separate from user-added custom items and are shown under their PvP subcategory.
	for itemId, itemData in pairs(BMR_PVP_ITEM_CATALOG) do
		local ruleName = "pvpItem_" .. tostring(itemId)
		BankManagerRules.data[ruleName] = {
			params = {{func = GetItemLinkItemId, funcArgs = BMR_ITEMLINK, values = {itemId}}},
			position = 9998,
			name = itemData.name,
			tooltip = itemData.name .. " (" .. itemData.category .. ", ID " .. tostring(itemId) .. ")",
		}
		BankManagerRules.defaults[ruleName] = BankManagerRules.defaults[ruleName] or {
			action = ACTION_NOTSET, associatedGuild = GetString(BMR_ACTION_NOTSET),
			onlyIfNotFullStack = true, onlyStacks = 1,
		}
		for _, profile in pairs(db.profiles or {}) do
			if type(profile) == "table" then
				profile.rules = profile.rules or {}
				if profile.rules[ruleName] == nil then
					profile.rules[ruleName] = {action = ACTION_NOTSET, associatedGuild = GetString(BMR_ACTION_NOTSET), onlyIfNotFullStack = true, onlyStacks = 1}
				end
			end
		end
	end

	if BMR.CustomRules then BMR.CustomRules.SyncFilterRuleDefinitions() end
end

-- BMR code

-- Display a movement
local function GetMovementDestinationText(bagIdTo)
	if IsFurnitureVaultBag(bagIdTo) then return GetString(BMR_ACTION_ITEMS_MOVED_TO_FURNITURE) end
	if IsHouseBankChestBag(bagIdTo) then return GetString(BMR_ACTION_ITEMS_MOVED_TO_HOUSE_STORAGE) end
	return GetString("BMR_ACTION_ITEMS_MOVED_TO", bagIdTo)
end

local function PrintItemsToBag(itemLink, itemIcon, bagIdTo, qty, currentGBankName)
	BMR.SafeAddChatMessage(zo_strformat(BMR_ACTION_ITEMS_MOVED, zo_strformat(SI_TOOLTIP_ITEM_NAME, itemLink), itemIcon, qty, GetMovementDestinationText(bagIdTo), currentGBankName))
end

local function PrintItemsNotMovedToBag(itemLink, itemIcon, bagIdTo, qty, currentGBankName)
	BMR.SafeAddChatMessage(zo_strformat(BMR_ACTION_ITEMS_NOT_MOVED, zo_strformat(SI_TOOLTIP_ITEM_NAME, itemLink), itemIcon, qty, GetMovementDestinationText(bagIdTo), currentGBankName))
end

-- Display movement summary
local function PrintSummaryToBag(bagIdTo, countMoved, qtyMoved, currentGBankName)
	BMR.SafeAddChatMessage(zo_strformat(BMR_ACTION_ITEMS_SUMMARY, countMoved, qtyMoved, GetMovementDestinationText(bagIdTo), currentGBankName))
end

-- Display currency movement
local function PrintCurrencyToBank(currencyType, qtyMoved)
	if type(ZO_CurrencyControl_FormatCurrencyAndAppendIcon) == "function" then BMR.SafeAddChatMessage(zo_strformat(BMR_ACTION_CURRENCY_SUMMARY, ZO_CurrencyControl_FormatCurrencyAndAppendIcon(qtyMoved, true, currencyType), GetString(BMR_ACTION_ITEMS_MOVED_TO2))) end
end

-- Display currency movement
local function PrintCurrencyToBag(currencyType, qtyMoved)
	if type(ZO_CurrencyControl_FormatCurrencyAndAppendIcon) == "function" then BMR.SafeAddChatMessage(zo_strformat(BMR_ACTION_CURRENCY_SUMMARY, ZO_CurrencyControl_FormatCurrencyAndAppendIcon(qtyMoved, true, currencyType), GetString(BMR_ACTION_ITEMS_MOVED_TO1))) end
end

local function Sanitize(value)
	return value:gsub("[-*+?^$().[%]%%]", "%%%0") -- escape meta characters
end

local function BuildWritsItems()
	
	local shouldBeWatched
	
	BankManagerRules.static.special.writsQuests = {}
	BankManagerRules.static.special.writsQuestsGlyphs = {}  -- Bit dirty, see how to improve - BankManagerRules.lua#271
	BankManagerRules.static.special.writsQuestsPots = {}	
	
	for journalQuestIndex = 1, GetNumJournalQuests() do
		if GetJournalQuestType(journalQuestIndex) == QUEST_TYPE_CRAFTING then
			if GetJournalQuestNumSteps(journalQuestIndex) == QUEST_MAIN_STEP_INDEX then
				for numConditions = 1, GetJournalQuestNumConditions(journalQuestIndex, QUEST_MAIN_STEP_INDEX) do
					local conditionText, current, max, _, isComplete = GetJournalQuestConditionInfo(journalQuestIndex, QUEST_MAIN_STEP_INDEX, numConditions)
					if conditionText ~= "" and current < max then
						conditionText = string.gsub(conditionText, " ", " ") -- First is a NO-BREAK SPACE, 2nd a SPACE, found somes.
						conditionText = Sanitize(conditionText)
						table.insert(BankManagerRules.static.special.writsQuests, {text = conditionText, qtyToMove = max})
						table.insert(BankManagerRules.static.special.writsQuestsGlyphs, {text = conditionText, qtyToMove = max})
						table.insert(BankManagerRules.static.special.writsQuestsPots, {text = conditionText, qtyToMove = max})
						shouldBeWatched = true
					end
				end
			end
		end
	end
	
	if not shouldBeWatched then
		hasAnySpecialPullToDo = false
	end
	
end

-- Reset all vars when finishing a GBank move
local function OnCloseProcessAtGBank()

	restartFromAtGBank = nil
	qtyMovedToGBank = 0
	countMovedToGBank = 0
	inProgress = false
	activeRuleRunPhase = nil
	pushQueue = {}
	
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_GUILD_BANK_TRANSFER_ERROR)
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_GUILD_BANK_ITEM_ADDED)
	
end

-- Build the push/pull array
local function queueAction(ruleName, bagId, slotId)
	
	local whichAction = db.profiles[actualProfile].rules[ruleName].action
	if (whichAction == ACTION_PUSH or whichAction == ACTION_PUSH_GBANK or whichAction == ACTION_PUSH_BOTH or whichAction == ACTION_PUSH_ALL_STACKS) and bagId == BAG_BACKPACK then
		-- Push item to the active destination: personal bank, or the currently opened house storage.
		table.insert(pushQueue, {ruleName = ruleName, bagId = bagId, slotId = slotId, itemLink = GetItemLink(bagId, slotId), itemIcon = GetItemLinkInfo(GetItemLink(bagId, slotId))})
	elseif whichAction == ACTION_PUSH_FURNITURE and bagId == BAG_BACKPACK and activeHouseStorageBagId then
		table.insert(pushQueue, {ruleName = ruleName, bagId = bagId, slotId = slotId, itemLink = GetItemLink(bagId, slotId), itemIcon = GetItemLinkInfo(GetItemLink(bagId, slotId))})
	elseif (whichAction == ACTION_PULL or whichAction == ACTION_PULL_ALL_STACKS) and IsCurrentStorageSourceBag(bagId) then
		-- Pull item to bank
		--d("ACTION_PULL " .. ruleName .. " " .. bagId .. " " .. slotId)
		table.insert(pullQueue, {ruleName = ruleName, bagId = bagId, slotId = slotId, itemLink = GetItemLink(bagId, slotId), itemIcon = GetItemLinkInfo(GetItemLink(bagId, slotId))})
	end
	
end

-- return true if item is protected
local function IsItemProtected(bagId, slotId)

	-- ESOUI
	if IsItemPlayerLocked(bagId, slotId) then
		return true
	end

	--Item Saver support
	if ItemSaver_IsItemSaved and ItemSaver_IsItemSaved(bagId, slotId) then
		return true
	end

	--FCO ItemSaver support
	if FCOIS and FCOIS.IsLocked then
		return FCOIS.IsLocked(bagId, slotId)
	end

	--FilterIt support
	if FilterIt and FilterIt.AccountSavedVariables and FilterIt.AccountSavedVariables.FilteredItems then
		local sUniqueId = Id64ToString(GetItemUniqueId(bagId, slotId))
		if FilterIt.AccountSavedVariables.FilteredItems[sUniqueId] then
			return FilterIt.AccountSavedVariables.FilteredItems[sUniqueId] ~= FILTERIT_VENDOR
		end
	end

	return false
	
end

-- To sort array
local function sortByKeyAndPosition(array)

	local arrayTemp = {}
	for key, data in pairs(array) do table.insert(arrayTemp, {key=key, data=data}) end

	local function sortByPosition(a, b)

		if not a.data.position and not b.data.position then return a.data.ruleName < b.data.ruleName end
		if not a.data.position and b.data.position then return true end
		if a.data.position and not b.data.position then return false end
		if a.data.position and b.data.position then
			return a.data.position < b.data.position
		end

	end

	table.sort(arrayTemp, sortByPosition)
	return arrayTemp
	
end

local function pairsByKeysAndPosition(array)

	local i = 0
	local iter = function()
		i = i + 1
		if array and array[i] then
			return array[i].key, array[i].data
		else
			return
		end
	end
	
	return iter
	
end

-- Match one rule using the same AND-between-parameters / OR-within-values logic as prepareItem.
local function DoesRuleMatchItem(ruleData, itemLink, bagId, slotId)
	if not ruleData or not ruleData.params or #ruleData.params == 0 then return false end
	for _, ruleParamData in ipairs(ruleData.params) do
		local funcToUse = ruleParamData.func
		local matched = false
		if funcToUse then
			if ruleParamData.funcArgs == BMR_ITEMLINK then
				for _, expected in ipairs(ruleParamData.values or {}) do
					if funcToUse(itemLink) == expected then matched = true break end
				end
			elseif ruleParamData.funcArgs == BMR_BAG_AND_SLOT then
				for _, expected in ipairs(ruleParamData.values or {}) do
					if funcToUse(bagId, slotId) == expected then matched = true break end
				end
			end
		end
		if not matched then return false end
	end
	return true
end

local function QueueOneStackSlot(ruleName, itemLink, bagId, slotId, targetBank)
	local request = oneStackRequests[itemLink]
	if not request then
		request = {ruleName = ruleName, itemLink = itemLink, backpackSlots = {}, bankSlots = {}, targetBank = targetBank == true, isCustomRule = string.find(ruleName, "^custom") ~= nil}
		oneStackRequests[itemLink] = request
	elseif string.find(ruleName, "^custom") then
		request.isCustomRule = true
	end
	if targetBank then request.targetBank = true end
	-- Prefer the most specific matching rule name if more than one rule matches.
	if string.find(ruleName, "AllWrit") or string.find(ruleName, "AllSurvey") then
		request.ruleName = request.ruleName or ruleName
	else
		request.ruleName = ruleName
	end
	local slots = (bagId == BAG_BACKPACK) and request.backpackSlots or request.bankSlots
	table.insert(slots, {bagId = bagId, slotId = slotId})
end

-- Check if slotId match a rule
local function prepareItem(bagId, slotId, checkingGBank)

	-- Inits
	BMR.ProfileDebugScanIncrement("scanned")
	if IsItemStolen(bagId, slotId) then BMR.ProfileDebugScanIncrement("stolen"); return end
	if db.profiles[actualProfile].protected and IsItemProtected(bagId, slotId) then BMR.ProfileDebugScanIncrement("protected"); return end
	
	local itemLink = GetItemLink(bagId, slotId)
	local itemId = GetItemLinkItemId(itemLink)
	local customRuleName = itemId and ("customItem_" .. tostring(itemId)) or nil
	local pvpRuleName = itemId and BMR_PVP_ITEM_CATALOG[itemId] and ("pvpItem_" .. tostring(itemId)) or nil
	local exactRuleName = customRuleName and db.profiles[actualProfile].rules[customRuleName] and db.profiles[actualProfile].rules[customRuleName].action ~= ACTION_NOTSET and customRuleName or nil
	if not exactRuleName and pvpRuleName and db.profiles[actualProfile].rules[pvpRuleName] and db.profiles[actualProfile].rules[pvpRuleName].action ~= ACTION_NOTSET then exactRuleName = pvpRuleName end
	-- Filter-based custom rules act like a specific rule for every matching item.
	-- Explicit exact-item and exact-PvP settings above still take precedence.
	if not exactRuleName then
		local filterRuleName = BankManagerRules.FindActiveCustomFilterRule(itemLink, db.profiles[actualProfile].rules)
		if filterRuleName then exactRuleName = filterRuleName; BMR.ProfileDebugScanIncrement("customFilterMatched") end
	end
	-- Alliance-wide PvP settings apply when no exact item or filter rule has been selected.
	if not exactRuleName and itemId and BMR_PVP_ITEM_CATALOG[itemId] then
		local alliance = BMR_PVP_ITEM_CATALOG[itemId].alliance
		local allianceRuleName = alliance and ("pvpAlliance_" .. alliance) or nil
		local allianceSettings = allianceRuleName and db.profiles[actualProfile].rules[allianceRuleName]
		if allianceSettings and allianceSettings.action and allianceSettings.action ~= ACTION_NOTSET then
			exactRuleName = allianceRuleName
			CustomRuleDebug(string.format("PVP-ALLIANCE MATCH itemId=%s alliance=%s rule=%s action=%s bag=%s slot=%s", tostring(itemId), tostring(alliance), tostring(allianceRuleName), tostring(allianceSettings.action), tostring(bagId), tostring(slotId)))
		end
	end
	local customRuleName = exactRuleName or customRuleName
	local customRuleSettings = customRuleName and db.profiles[actualProfile].rules[customRuleName] or nil
	local customRuleActive = customRuleSettings and customRuleSettings.action and customRuleSettings.action ~= ACTION_NOTSET
	if customRuleActive then
		BMR.ProfileDebugScanIncrement("activeExact")
		CustomRuleDebug(string.format("MATCH name=%s itemId=%s action=%s bag=%s slot=%s %s link=%s%s", tostring(GetItemLinkName(itemLink)), tostring(itemId), tostring(customRuleSettings.action), tostring(bagId), tostring(slotId), GetCustomRuleSlotDebugInfo(bagId, slotId), tostring(itemLink), GetBrandOilDiagnosticInfo(bagId, slotId, itemLink)))
	end
	if customRuleActive and (customRuleSettings.action == ACTION_PULL or customRuleSettings.action == ACTION_PULL_ALL_STACKS) then
		hasAnyPullToDo = true
	end
	
	-- Cannot be moved to bank
	if bagId == BAG_BACKPACK and GetItemLinkBindType(itemLink) == BIND_TYPE_ON_PICKUP_BACKPACK then BMR.ProfileDebugScanIncrement("pickupPersonal"); return end
	
	-- Cannot be moved to GBank
	if checkingGBank and GetItemLinkBindType(itemLink) == BIND_TYPE_ON_PICKUP then BMR.ProfileDebugScanIncrement("pickupGuild"); return end

	-- A custom one-stack rule must be queued before broader category rules are
	-- examined, so it always takes precedence for this exact item.
	if customRuleActive and (customRuleSettings.action == ACTION_KEEP_ONE_STACK or customRuleSettings.action == ACTION_KEEP_ONE_STACK_BANK) then
		BMR.ProfileDebugScanIncrement("oneStack")
		if not checkingGBank then
			QueueOneStackSlot(customRuleName, itemLink, bagId, slotId, customRuleSettings.action == ACTION_KEEP_ONE_STACK_BANK)
			hasAnyPullToDo = true
		end
		return
	end

	-- This per-rule action takes precedence over all broader category rules and
	-- normal push/pull actions. It is handled after the full backpack/bank scan.
	-- Reverse order favors individual rules over category master rules.
	if not customRuleActive then
		for index = #dataSorted, 1, -1 do
			local entry = dataSorted[index]
			local candidateName, candidateData = entry.key, entry.data
			local candidateSettings = db.profiles[actualProfile].rules[candidateName]
			if candidateSettings and (candidateSettings.action == ACTION_KEEP_ONE_STACK or candidateSettings.action == ACTION_KEEP_ONE_STACK_BANK) and DoesRuleMatchItem(candidateData, itemLink, bagId, slotId) then
				if not checkingGBank then
					QueueOneStackSlot(candidateName, itemLink, bagId, slotId, candidateSettings.action == ACTION_KEEP_ONE_STACK_BANK)
					hasAnyPullToDo = true -- also scan bank items when the item is currently only in the bank
				end
				return
			end
		end
	end
	if checkingGBank and not customRuleActive then
		-- Do not let a different category action send an explicitly configured
		-- one-stack item to a guild bank.
		for index = #dataSorted, 1, -1 do
			local entry = dataSorted[index]
			local candidateName, candidateData = entry.key, entry.data
			local candidateSettings = db.profiles[actualProfile].rules[candidateName]
			if candidateSettings and (candidateSettings.action == ACTION_KEEP_ONE_STACK or candidateSettings.action == ACTION_KEEP_ONE_STACK_BANK) and DoesRuleMatchItem(candidateData, itemLink, bagId, slotId) then return end
		end
	end
	
	local itemMatch = false
	local ruleMatch
	local forBankOnly = not checkingGBank
	if customRuleActive then
		itemMatch = true
		ruleMatch = customRuleName
		if checkingGBank and (customRuleSettings.action == ACTION_PUSH or customRuleSettings.action == ACTION_PUSH_ALL_STACKS) then
			forBankOnly = true
		end
	end
	
	-- Container master actions override the individual writ/survey actions when
	-- selected. When the master action is '-', normal per-item rules are used.
	-- Apply this regardless of the current bag so an opposite individual action
	-- cannot accidentally move an item against the selected group action.
	local containerItemId = tonumber(itemLink:match("|H%d:item:(%d+)") or itemLink:match("|Hitem:(%d+)"))
	local masterRuleName
	if containerItemId then
		if containerItemId == 217917 or containerItemId == 217918 or containerItemId == 217919
			or containerItemId == 217920 or containerItemId == 217921 or containerItemId == 217922
			or containerItemId == 217923 then
			masterRuleName = "MiscContainerUnknownAllWrit"
		elseif containerItemId == 219849 or containerItemId == 219850 or containerItemId == 219851
			or containerItemId == 219852 or containerItemId == 219853 or containerItemId == 219854 then
			masterRuleName = "MiscContainerUnidentifiedAllSurvey"
		end
		-- Antiquity Leads use name-based matching because some IDs are missing or
		-- mislabeled by ZOS; the lead master rule is deliberately independent from
		-- the explicit unopened-treasure-map rule.
		if not masterRuleName and BankManagerRules.data["MiscContainerAntiquityLead"]
			and DoesRuleMatchItem(BankManagerRules.data["MiscContainerAntiquityLead"], itemLink, bagId, slotId) then
			masterRuleName = "MiscContainerAntiquityLead"
		end
	end
	if not itemMatch and masterRuleName then
		local masterSettings = db.profiles[actualProfile].rules[masterRuleName]
		if masterSettings and masterSettings.action and masterSettings.action ~= ACTION_NOTSET then
			itemMatch = true
			ruleMatch = masterRuleName
			if checkingGBank and (masterSettings.action == ACTION_PUSH or masterSettings.action == ACTION_PUSH_ALL_STACKS) then
				forBankOnly = true
			end
		elseif masterRuleName == "MiscContainerAntiquityLead" then
			-- When the master action is '-', an explicitly configured quality rule
			-- must take precedence over the broad generic Containers category.
			for _, qualityRuleName in ipairs({
				"MiscContainerAntiquityLeadGreen",
				"MiscContainerAntiquityLeadBlue",
				"MiscContainerAntiquityLeadPurple",
				"MiscContainerAntiquityLeadGold",
			}) do
				local qualitySettings = db.profiles[actualProfile].rules[qualityRuleName]
				if qualitySettings and qualitySettings.action and qualitySettings.action ~= ACTION_NOTSET
					and BankManagerRules.data[qualityRuleName]
					and DoesRuleMatchItem(BankManagerRules.data[qualityRuleName], itemLink, bagId, slotId) then
					itemMatch = true
					ruleMatch = qualityRuleName
					if checkingGBank and (qualitySettings.action == ACTION_PUSH or qualitySettings.action == ACTION_PUSH_ALL_STACKS) then
						forBankOnly = true
					end
					break
				end
			end
		end
	end
	
	-- For each item in bag, look all rules
	for ruleName, ruleData in pairsByKeysAndPosition(dataSorted) do
	
		local profileRules = db.profiles[actualProfile].rules or {}
		local ruleSettings = profileRules[ruleName]
		if not ruleSettings then
			-- Safety fallback for incomplete/older saved variables.
			ruleSettings = BankManagerRules.defaults and BankManagerRules.defaults[ruleName] or {}
			profileRules[ruleName] = ruleSettings
			db.profiles[actualProfile].rules = profileRules
		end
		local action = ruleSettings.action
		local associatedGuild = ruleSettings.associatedGuild
		
		-- Check first if item didn't matched a previous rule
		if not itemMatch then
		
			local shouldMove
			
			if checkingGBank then -- the 3rd is here to allow easy rules, see under
				shouldMove = (currentGBankName == associatedGuild) and ((bagId == BAG_BACKPACK and action == ACTION_PUSH_GBANK) or (bagId == BAG_BACKPACK and action == ACTION_PUSH_BOTH) or (bagId == BAG_BACKPACK and action == ACTION_PUSH))
			else
				if action == ACTION_PULL or action == ACTION_PULL_ALL_STACKS then
					if ruleSettings.specialEnabled then
						hasAnySpecialPullToDo = true
					else
						hasAnyPullToDo = true
					end
				end
				shouldMove = (bagId == BAG_BACKPACK and (action == ACTION_PUSH or action == ACTION_PUSH_FURNITURE or action == ACTION_PUSH_ALL_STACKS)) or (IsCurrentStorageSourceBag(bagId) and (action == ACTION_PULL or action == ACTION_PULL_ALL_STACKS)) or (bagId == BAG_BACKPACK and action == ACTION_PUSH_BOTH)
			end
			
			-- If rule is well writen and set to do something
			if ruleData.params and shouldMove then

				for ruleParamIndex, ruleParamData in ipairs(ruleData.params) do
					
					local funcToUse = ruleParamData.func -- Our fonction stored
					local itemMatchValue
					
					if funcToUse then
						if ruleParamData.funcArgs == BMR_ITEMLINK then
							
							-- Is item matching values ?
							for funcChoices, funcMatches in ipairs(ruleParamData.values) do
								if funcToUse(itemLink) == funcMatches then
									itemMatchValue = true
								end
							end
							
						elseif ruleParamData.funcArgs == BMR_BAG_AND_SLOT then
							for funcChoices, funcMatches in ipairs(ruleParamData.values) do
								if funcToUse(bagId, slotId) == funcMatches then
									itemMatchValue = true
								end
							end
						
						end
					end
					
					-- The item didn't match our filter, don't try other params, go to next rule
					if not itemMatchValue then
						itemMatch = false
						ruleMatch = nil
						break
					else
						-- The item match our filter .. for now
						itemMatch = true
						ruleMatch = ruleName
						--d(itemLink .. " (" .. bagId .. " " .. slotId.. ") ruleMatch:" .. ruleName .. " #" .. ruleParamIndex)
					end
					
				end

				-- Our item matched a rule - was it an ACTION_PUSH + checkingGBank ?
				if itemMatch and checkingGBank and action == ACTION_PUSH then
					-- this item must not be queued, it has been flagged to go to bank only
					forBankOnly = true
					--d(itemLink .. " (" .. bagId .. " " .. slotId.. ") ruleMatch:" .. ruleMatch .. " set flag 'For Bank Only' ")
				end
			
			end
		else
			break
		end
	end
	
	if itemMatch then
		BMR.ProfileDebugScanIncrement("matched")
		if customRuleActive and string.find(tostring(ruleMatch or ""), "^pvpAlliance_") then
			CustomRuleDebug(string.format("PVP-ALLIANCE QUEUE itemId=%s rule=%s action=%s bag=%s slot=%s", tostring(itemId), tostring(ruleMatch), tostring(db.profiles[actualProfile].rules[ruleMatch] and db.profiles[actualProfile].rules[ruleMatch].action), tostring(bagId), tostring(slotId)))
		end
		if checkingGBank then
			if not forBankOnly then
				--d(itemLink .. " (" .. bagId .. " " .. slotId.. ") ruleMatch:" .. ruleMatch .. " is not flagged for Bank Only. Will move")
				local pushBefore = #pushQueue
				local pullBefore = #pullQueue
				queueAction(ruleMatch, bagId, slotId)
				if #pushQueue > pushBefore or #pullQueue > pullBefore then BMR.ProfileDebugScanIncrement("queued") end
			else
				BMR.ProfileDebugScanIncrement("bankOnly")
				--d(itemLink .. " (" .. bagId .. " " .. slotId.. ") ruleMatch:" .. ruleMatch .. " is flagged for Bank Only. Don't move")
			end
		else
			local pushBefore = #pushQueue
			local pullBefore = #pullQueue
			queueAction(ruleMatch, bagId, slotId)
			if #pushQueue > pushBefore or #pullQueue > pullBefore then BMR.ProfileDebugScanIncrement("queued") end
		end
	else
		BMR.ProfileDebugScanIncrement("noRuleMatch")
	end

end

-- Move all items defined in push/pull arrays
local function moveItems(atGBank, errorReasonAtGBank)

	-- Our bagcache, because game don't have it in realtime
	local tinyBagCache = {
		[BAG_BACKPACK] = {},
		[BAG_BANK] = {},
		[BAG_SUBSCRIBER_BANK] = {},
	}
	local pushTargetBag = (not atGBank and GetCurrentDepositBag()) or BAG_BANK
	if activeHouseStorageBagId then tinyBagCache[activeHouseStorageBagId] = {} end
	
	-- Our bagcache for qty, because game don't have it in realtime
	local qtyBagCache = {}
	-- Custom, PvP, and housing transfers are asynchronous. Defer accounting and
	-- success messages until both source and destination slots reflect the move.
	local pendingMoveVerification = nil
	
	-- Avoid checking first 230 slots if we already did it.
	local tinyBagCacheFirstSlot = {
		[BAG_BACKPACK] = 0,
		[BAG_BANK] = 0,
		[BAG_SUBSCRIBER_BANK] = 0,
	}
	if activeHouseStorageBagId then tinyBagCacheFirstSlot[activeHouseStorageBagId] = 0 end
	
	local freeSlots = {
		[BAG_BACKPACK] = 0,
		[BAG_BANK] = 0,
		[BAG_SUBSCRIBER_BANK] = 0,
	}
	if activeHouseStorageBagId then freeSlots[activeHouseStorageBagId] = GetNumBagFreeSlots(activeHouseStorageBagId) end
	
	-- Items moved in psuh + pull actions
	local itemsMoved = 0
	local qtyMoved = 0
	local countMoved = 0
	local pushInProgress = true
	-- A one-stack rule may try to fill the existing target stack with several
	-- source slots. If the game refuses to merge one of those items, do not let
	-- the generic PvP retry place it into a second empty slot for the same item.
	local function IsOneStackTarget(ruleName, bagIdTo, itemLink)
		local rule = ruleName and db.profiles[actualProfile].rules[ruleName]
		local action = rule and rule.action
		-- Queue metadata can be stale or inherited from a broader rule. For PvP items,
		-- resolve the active exact-item rule first, then the item's alliance rule.
		if action ~= ACTION_KEEP_ONE_STACK and action ~= ACTION_KEEP_ONE_STACK_BANK and itemLink then
			local itemId = GetItemLinkItemId(itemLink)
			local exactName = itemId and ("pvpItem_" .. tostring(itemId)) or nil
			local exact = exactName and db.profiles[actualProfile].rules[exactName]
			if exact and exact.action and exact.action ~= ACTION_NOTSET then
				action = exact.action
			elseif itemId and BMR_PVP_ITEM_CATALOG and BMR_PVP_ITEM_CATALOG[itemId] then
				local alliance = BMR_PVP_ITEM_CATALOG[itemId].alliance
				local allianceName = alliance and ("pvpAlliance_" .. alliance) or nil
				local allianceRule = allianceName and db.profiles[actualProfile].rules[allianceName]
				if allianceRule and allianceRule.action then action = allianceRule.action end
			end
		end
		return (action == ACTION_KEEP_ONE_STACK and bagIdTo == BAG_BACKPACK)
			or (action == ACTION_KEEP_ONE_STACK_BANK and IsBankDestinationBag(bagIdTo))
	end
	
	-- Thanks Merlight & circonian, FindFirstEmptySlotInBag don't refresh in realtime.
	local function FindEmptySlotInBag(bagId)
		
		if isESOPlusSubscriber and bagId == BAG_BANK and freeSlots[bagId] == 0 then
			bagId = BAG_SUBSCRIBER_BANK
		end
		
		--d("FindEmptySlotInBag (" .. bagId .. ")" .. " ; isESOPlusSubscriber=" .. tostring(isESOPlusSubscriber))
		tinyBagCache[bagId] = tinyBagCache[bagId] or {}
		tinyBagCacheFirstSlot[bagId] = tinyBagCacheFirstSlot[bagId] or 0
		if freeSlots[bagId] == nil then freeSlots[bagId] = GetNumBagFreeSlots(bagId) or 0 end
		local hasSpace = atGBank or (IsFurnitureStorageBag(bagId) and freeSlots[bagId] > 0) or (bagId == BAG_BANK and not isESOPlusSubscriber and freeSlots[bagId] > db.profiles[actualProfile].overfill) or (isESOPlusSubscriber and (bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK) and freeSlots[BAG_SUBSCRIBER_BANK] > db.profiles[actualProfile].overfill) or (bagId == BAG_BACKPACK and freeSlots[bagId] > db.profiles[actualProfile].overfill)
		if hasSpace then
			for slotIndex = tinyBagCacheFirstSlot[bagId], ((GetBagSize(bagId) or 0) - 1) do
				-- Housing storage bags may not be fully represented in LibSharedInventory.
				-- Query ESO's live slot state for these bags so an occupied slot is never
				-- mistaken for an empty destination.
				local occupied
				if IsFurnitureStorageBag(bagId) then
					occupied = GetItemType(bagId, slotIndex) ~= ITEMTYPE_NONE
				else
					occupied = (SHARED_INVENTORY.bagCache[bagId] or {})[slotIndex] ~= nil
				end
				if not occupied and not tinyBagCache[bagId][slotIndex] then
					--d("tinyBagCache -> " .. bagId .. " " .. slotIndex)
					tinyBagCache[bagId][slotIndex] = true
					tinyBagCacheFirstSlot[bagId] = slotIndex + 1
					freeSlots[bagId] = freeSlots[bagId] - 1
					return bagId, slotIndex
				end
			end
		end
		return bagId
	end
	
	-- Return a compatible stack slot, or a new empty slot. itemInstanceId alone
	-- is not enough for PvP siege items: different remaining-energy variants can
	-- share it while their complete item links (and stacking compatibility) differ.
	local function FindItemInBag(bagIdTo, bagIdFrom, slotIdFrom, maxStack, sourceItemLink)
		--d("FindItemInBag")
		local sourceData = SHARED_INVENTORY.bagCache[bagIdFrom] and SHARED_INVENTORY.bagCache[bagIdFrom][slotIdFrom]
		local itemInstanceId = sourceData and sourceData.itemInstanceId
		sourceItemLink = sourceItemLink or GetItemLink(bagIdFrom, slotIdFrom)
		if not sourceItemLink or (not itemInstanceId and not IsFurnitureStorageBag(bagIdFrom)) then
			return FindEmptySlotInBag(bagIdTo)
		end
		local sourceItemId = GetItemLinkItemId(sourceItemLink)
		local function findMatchingStack(candidateBagId)
			for _, data in pairs(SHARED_INVENTORY.bagCache[candidateBagId] or {}) do
				if (data.itemInstanceId == itemInstanceId or (not itemInstanceId and GetItemLink(candidateBagId, data.slotIndex) == sourceItemLink)) and data.stackCount < maxStack then
					local candidateLink = GetItemLink(candidateBagId, data.slotIndex)
					if candidateLink == sourceItemLink then
						local rejectedKey = GetRejectedPvpStackTargetKey(candidateBagId, data.slotIndex, sourceItemLink)
						if rejectedPvpStackTargets[rejectedKey] then
							CustomRuleDebug(string.format("STACK TARGET SKIP itemId=%s source=%s candidateBag=%s candidateSlot=%s reason=previous transfer to this occupied target was not confirmed; use empty slot", tostring(sourceItemId), tostring(sourceItemLink), tostring(candidateBagId), tostring(data.slotIndex)))
						else
							return candidateBagId, data.slotIndex
						end
					elseif sourceItemId and BMR_PVP_ITEM_CATALOG and BMR_PVP_ITEM_CATALOG[sourceItemId] then
						CustomRuleDebug(string.format("STACK TARGET SKIP itemId=%s source=%s candidateBag=%s candidateSlot=%s candidate=%s reason=same itemInstanceId but different full itemLink", tostring(sourceItemId), tostring(sourceItemLink), tostring(candidateBagId), tostring(data.slotIndex), tostring(candidateLink)))
					end
				end
			end
			if IsFurnitureStorageBag(candidateBagId) then
				for slotId = 0, (GetBagSize(candidateBagId) or 0) - 1 do
					local candidateLink = GetItemLink(candidateBagId, slotId)
					local count = GetSlotStackSize(candidateBagId, slotId) or 0
					local candidateData = SHARED_INVENTORY.bagCache[candidateBagId] and SHARED_INVENTORY.bagCache[candidateBagId][slotId]
					local sameInstance = itemInstanceId and candidateData and candidateData.itemInstanceId == itemInstanceId
					local cacheMissingButExactLink = not candidateData and candidateLink == sourceItemLink
					if candidateLink == sourceItemLink and count > 0 and count < maxStack and (sameInstance or cacheMissingButExactLink or (not itemInstanceId and candidateLink == sourceItemLink)) then
						local rejectedKey = GetRejectedPvpStackTargetKey(candidateBagId, slotId, sourceItemLink)
						if not rejectedPvpStackTargets[rejectedKey] then return candidateBagId, slotId end
					end
				end
			end
		end
		local matchBag, matchSlot = findMatchingStack(bagIdTo)
		if matchSlot then return matchBag, matchSlot end
		if bagIdTo == BAG_BANK then
			matchBag, matchSlot = findMatchingStack(BAG_SUBSCRIBER_BANK)
			if matchSlot then return matchBag, matchSlot end
		end
		
		-- No compatible stack: use an empty slot instead of targeting a different variant.
		return FindEmptySlotInBag(bagIdTo)
		
	end
	
	local function FindDestSlotInBag(stackCountTo, bagIdTo, bagIdFrom, slotIdFrom, maxStack, sourceItemLink)
		--d("FindDestSlotInBag " .. bagIdFrom .. " " .. slotIdFrom)
		if stackCountTo > 0 then
			return FindItemInBag(bagIdTo, bagIdFrom, slotIdFrom, maxStack, sourceItemLink)
		else
			return FindEmptySlotInBag(bagIdTo)
		end
		
	end
	
	local function moveItemInSlot(bagIdFrom, slotIdFrom, bagIdTo, slotIdTo, qtyToMove, itemLink, verifyTransfer)
		local sourceItemId
		if itemLink and itemLink ~= "" then
			local itemIdOk, resolvedItemId = pcall(GetItemLinkItemId, itemLink)
			if itemIdOk then sourceItemId = resolvedItemId end
		end
		local isPvpTransfer = sourceItemId and ((BMR_PVP_ITEM_CATALOG and BMR_PVP_ITEM_CATALOG[sourceItemId]) or sourceItemId == 30359)
		-- PvP priority depends on exact item-link variants, so every cross-bag PvP move must
		-- be confirmed before it is counted or announced as successful, not just moveData.custom.
		-- Housing storage transfers can be accepted asynchronously by ESO. Verify
		-- both slots before reporting success or continuing to the next queued item;
		-- otherwise a rejected request can look successful and require a second click.
		local isHousingTransfer = IsFurnitureStorageBag(bagIdFrom) or IsFurnitureStorageBag(bagIdTo)
		local deferVerification = bagIdFrom ~= bagIdTo and (verifyTransfer == true or isPvpTransfer or isHousingTransfer)
		local request = nil
		if deferVerification then
			if pendingMoveVerification then
				CustomRuleDebug("TRANSFER REQUEST BLOCKED reason=previous cross-bag transfer is still awaiting verification")
				return false
			end
			local sourceCountBefore = GetSlotStackSize(bagIdFrom, slotIdFrom) or 0
			local destCountBefore = GetSlotStackSize(bagIdTo, slotIdTo) or 0
			request = {
				fromBag = bagIdFrom, fromSlot = slotIdFrom, toBag = bagIdTo, toSlot = slotIdTo,
				qty = qtyToMove, itemLink = itemLink, sourceItemId = sourceItemId,
				sourceLinkBefore = GetItemLink(bagIdFrom, slotIdFrom),
			sourceCountBefore = sourceCountBefore,
				destLinkBefore = GetItemLink(bagIdTo, slotIdTo),
				destCountBefore = destCountBefore,
				destItemIdCountBefore = isHousingTransfer and sourceItemId and CountItemIdInBag(sourceItemId, bagIdTo) or nil,
			}
		end
		
		if deferVerification then
			local callOk, callError
			if IsProtectedFunction and IsProtectedFunction("RequestMoveItem") then
				callOk, callError = CallSecureProtected("RequestMoveItem", bagIdFrom, slotIdFrom, bagIdTo, slotIdTo, qtyToMove)
			else
				callOk, callError = pcall(RequestMoveItem, bagIdFrom, slotIdFrom, bagIdTo, slotIdTo, qtyToMove)
			end
			if not callOk then
				CustomRuleDebug(string.format("TRANSFER API REJECTED sourceBag=%s sourceSlot=%s targetBag=%s targetSlot=%s qty=%s error=%s", tostring(bagIdFrom), tostring(slotIdFrom), tostring(bagIdTo), tostring(slotIdTo), tostring(qtyToMove), tostring(callError)))
				return false
			end
			pendingMoveVerification = request
			activeTransferVerificationDebug = request
			CustomRuleDebug(string.format("TRANSFER REQUEST sourceBag=%s sourceSlot=%s sourceCount=%s targetBag=%s targetSlot=%s targetLink=%s targetCount=%s qty=%s itemLink=%s", tostring(bagIdFrom), tostring(slotIdFrom), tostring(request.sourceCountBefore), tostring(bagIdTo), tostring(slotIdTo), tostring(request.destLinkBefore), tostring(request.destCountBefore), tostring(qtyToMove), tostring(itemLink)))
			if RegisterExpectedPvpMoveTrace then request.traceEntry = RegisterExpectedPvpMoveTrace(bagIdFrom, slotIdFrom, bagIdTo, slotIdTo, qtyToMove, itemLink) end
		else
			if IsProtectedFunction("RequestMoveItem") then
				CallSecureProtected("RequestMoveItem", bagIdFrom, slotIdFrom, bagIdTo, slotIdTo, qtyToMove)
			else
				RequestMoveItem(bagIdFrom, slotIdFrom, bagIdTo, slotIdTo, qtyToMove)
			end
			if RegisterExpectedPvpMoveTrace then RegisterExpectedPvpMoveTrace(bagIdFrom, slotIdFrom, bagIdTo, slotIdTo, qtyToMove, itemLink) end
			-- Same-bag moves used by the guild-bank partial-stack helper retain the
			-- existing immediate accounting path.
			if qtyBagCache[itemLink][bagIdTo] == nil then qtyBagCache[itemLink][bagIdTo] = IsFurnitureStorageBag(bagIdTo) and CountItemLinkInBag(itemLink, bagIdTo) or 0 end
			if qtyBagCache[itemLink][bagIdFrom] == nil then qtyBagCache[itemLink][bagIdFrom] = IsFurnitureStorageBag(bagIdFrom) and CountItemLinkInBag(itemLink, bagIdFrom) or 0 end
			qtyBagCache[itemLink][bagIdTo] = qtyBagCache[itemLink][bagIdTo] + qtyToMove
			qtyBagCache[itemLink][bagIdFrom] = qtyBagCache[itemLink][bagIdFrom] - qtyToMove
		end
		return true
	end
	
	-- Move a slot or a partial slot to GBank
	local function moveItemInGBank(bagIdFrom, slotIdFrom, qtyToMove, itemLink)
		
		--d("moveItemInGBank")
		if qtyToMove then
			--Partial slot, we need an empty slot
			local emptySlot = FindEmptySlotInBag(bagIdFrom)
			-- Local bag can be full
			if emptySlot then
				moveItemInSlot(bagIdFrom, slotIdFrom, bagIdFrom, emptySlot, qtyToMove, itemLink)
				TransferToGuildBank(bagIdFrom, emptySlot)
			end
		else
			TransferToGuildBank(bagIdFrom, slotIdFrom)
		end
		
		-- Temporary
		return true
		
	end

	local function StackInfoInBag(bagToCheck, slotIdFrom, bagIdFrom, itemLink)
		
		local stackCountBackpack, stackCountBank
		
		if not qtyBagCache[itemLink] then
			stackCountBackpack, stackCountBank = GetItemLinkStacks(itemLink) -- Not updated in realtime
			qtyBagCache[itemLink] = {}
			qtyBagCache[itemLink][BAG_BACKPACK] = stackCountBackpack or 0
			qtyBagCache[itemLink][BAG_BANK] = stackCountBank or 0
			qtyBagCache[itemLink][BAG_SUBSCRIBER_BANK] = stackCountBank or 0
			if activeHouseStorageBagId then qtyBagCache[itemLink][activeHouseStorageBagId] = CountItemLinkInBag(itemLink, activeHouseStorageBagId) end
		else
			stackCountBackpack = qtyBagCache[itemLink][BAG_BACKPACK] or 0
			stackCountBank = (qtyBagCache[itemLink][BAG_BANK] or 0) + (qtyBagCache[itemLink][BAG_SUBSCRIBER_BANK] or 0)
		end
		
		local stackSize, maxStack = GetSlotStackSize(bagIdFrom, slotIdFrom)
		if bagToCheck == BAG_BACKPACK then
			if activeHouseStorageBagId then stackCountBank = qtyBagCache[itemLink][activeHouseStorageBagId] or CountItemLinkInBag(itemLink, activeHouseStorageBagId) end
			return stackCountBackpack >= maxStack, stackSize, maxStack, stackCountBackpack, stackCountBank
		elseif IsFurnitureStorageBag(bagToCheck) then
			if qtyBagCache[itemLink][bagToCheck] == nil then qtyBagCache[itemLink][bagToCheck] = CountItemLinkInBag(itemLink, bagToCheck) end
			stackCountBank = qtyBagCache[itemLink][bagToCheck] or 0
			return stackCountBank >= maxStack, stackSize, maxStack, stackCountBackpack, stackCountBank
		elseif bagToCheck == BAG_BANK or bagToCheck == BAG_SUBSCRIBER_BANK then
			return stackCountBank >= maxStack, stackSize, maxStack, stackCountBackpack, stackCountBank
		end
	end
	
	local function RestackBags()
		-- Sometimes needed (2 stacks, first 79, 2nd 200, but limit is 200 -> will push 79 , then 121, resulting 2 stacks), maybe need to optimize tinyBagCache
		if activeHouseStorageBagId then
			StackBag(activeHouseStorageBagId)
		else
			StackBag(BAG_BANK)
			StackBag(BAG_SUBSCRIBER_BANK)
		end
		StackBag(BAG_BACKPACK)
	end
	
	local function FinishBankMoves()
	
		hasAnyPullToDo = nil
		pushQueue = {}
		pullQueue = {}
		movedItems = {
			[BAG_BACKPACK] = {},
			[BAG_BANK] = {},
			[BAG_SUBSCRIBER_BANK] = {},
		}
		
		inProgress = false
		activeRuleRunPhase = nil
		if profileIconRerunRequested then
			profileIconRerunRequested = false
			if isBanking then
				CustomRuleDebug("PROFILE ICON DEFERRED RERUN released reason=previous move loop finished; re-snapshot and rebuild rules in 150ms")
				zo_callLater(function()
					if isBanking and not checkingGBank then
						BankManagerRevived_executeRule()
					else
						CustomRuleDebug(string.format("PROFILE ICON DEFERRED RERUN CANCELLED reason=bank context changed isBanking=%s checkingGBank=%s", tostring(isBanking), tostring(checkingGBank)))
					end
				end, 150)
			else
				CustomRuleDebug("PROFILE ICON DEFERRED RERUN CANCELLED reason=bank already closed")
			end
		elseif activeHouseStorageBagId and isBanking and not checkingGBank then
			-- Continue the bounded refresh sequence after successful moves. If a pass
			-- itself moved nothing, also retry once more after a longer cache-settle delay.
			if itemsMoved > 0 then
				ScheduleHousingAutoRescan(itemsMoved, "refresh remaining inventory after successful batch", 500)
			elseif housingAutoRescanPasses > 0 then
				ScheduleHousingAutoRescan(0, "follow-up pass finished without confirmed transfers", 1000)
			end
		elseif not activeHouseStorageBagId or not isBanking then
			housingAutoRescanPasses = 0
		end
	
	end

	local function tryMoveSlots(data, bagIdTo, restartAt)
		
		-- Need to push/pull?
		if not restartAt then restartAt = 1 end
		local moveData = data[restartAt]
		
		if moveData then
			if IsFurnitureVaultBag(bagIdTo) and GetItemType(moveData.bagId, moveData.slotId) ~= ITEMTYPE_FURNISHING then
				CustomRuleDebug(string.format("FURNITURE VAULT SKIP itemId=%s sourceBag=%s sourceSlot=%s reason=only furnishing items can be stored", tostring(GetItemLinkItemId(moveData.itemLink)), tostring(moveData.bagId), tostring(moveData.slotId)))
				zo_callLater(function() tryMoveSlots(data, bagIdTo, restartAt + 1) end, db.profiles[actualProfile].pauseInMs)
				return
			end
			local oneStackTarget = IsOneStackTarget(moveData.ruleName, bagIdTo, moveData.itemLink)
			local blockedOneStackKey = oneStackTarget and GetOneStackDestinationKey(moveData.itemLink, bagIdTo) or nil
			local rejectedOneStackTarget = blockedOneStackKey and rejectedOneStackDestinations[blockedOneStackKey] or nil
			if rejectedOneStackTarget then
				CustomRuleDebug(string.format("ONE-STACK MOVE SKIP itemId=%s sourceBag=%s sourceSlot=%s targetBag=%s rejectedTargetBag=%s rejectedTargetSlot=%s reason=target stack previously refused merge; preserve one physical target stack", tostring(GetItemLinkItemId(moveData.itemLink)), tostring(moveData.bagId), tostring(moveData.slotId), tostring(bagIdTo), tostring(rejectedOneStackTarget.bagId), tostring(rejectedOneStackTarget.slotId)))
				zo_callLater(function() tryMoveSlots(data, bagIdTo, restartAt + 1) end, db.profiles[actualProfile].pauseInMs)
				return
			end
		
			-- Should not exceed 100 in a move or game will kick you
			if db.profiles[actualProfile].pauseInMs >= 100 or (itemsMoved < 98 and db.profiles[actualProfile].pauseInMs < 100) then
				--d(moveData.ruleName .. " will check qty and if, move " .. GetItemName(moveData.bagId, moveData.slotId))
				
				-- Is slot at max size in bank ?
				local isFullStack, stackSize, maxStack, stackCountBackpack, stackCountBank = StackInfoInBag(bagIdTo, moveData.slotId, moveData.bagId, moveData.itemLink)
				local itemMoved = false
				local qtyToMove, destSlot
				local ruleSettings = db.profiles[actualProfile].rules[moveData.ruleName] or {}
				local forceAllStacks = ruleSettings.action == ACTION_PUSH_ALL_STACKS or ruleSettings.action == ACTION_PULL_ALL_STACKS
				
				if moveData.custom then
					qtyToMove = math.min(stackSize, tonumber(moveData.maxQty) or stackSize)
					local currentStackCount = bagIdTo == BAG_BACKPACK and stackCountBackpack or stackCountBank
					bagIdTo, destSlot = FindDestSlotInBag(currentStackCount, bagIdTo, moveData.bagId, moveData.slotId, maxStack, moveData.itemLink)
					if destSlot then
						itemMoved = moveItemInSlot(moveData.bagId, moveData.slotId, bagIdTo, destSlot, qtyToMove, moveData.itemLink, true)
					elseif db.profiles[actualProfile].detailledNotMoved then
						PrintItemsNotMovedToBag(moveData.itemLink, moveData.itemIcon, bagIdTo, qtyToMove)
					end
					
				elseif not forceAllStacks and BankManagerRules.data[moveData.ruleName] and BankManagerRules.data[moveData.ruleName].isSpecial then
				
					if bagIdTo == BAG_BACKPACK then
						qtyToMove = BankManagerRules.static.special[moveData.ruleName][moveData.itemLink]
						bagIdTo, destSlot = FindDestSlotInBag(stackCountBackpack, bagIdTo, moveData.bagId, moveData.slotId, maxStack, moveData.itemLink)
					end
					
					--d("qtyToMove " .. qtyToMove .. " destSlot " .. tostring(destSlot))
					if destSlot then
						--d(moveData.ruleName .. " is moving " .. GetItemName(moveData.bagId, moveData.slotId) .. " (not full stack)")
						itemMoved = moveItemInSlot(moveData.bagId, moveData.slotId, bagIdTo, destSlot, qtyToMove, moveData.itemLink)
					elseif db.profiles[actualProfile].detailledNotMoved then
						PrintItemsNotMovedToBag(moveData.itemLink, moveData.itemIcon, bagIdTo, qtyToMove)
					end
					
				elseif not forceAllStacks and not isFullStack and ruleSettings.onlyIfNotFullStack then
					
					if bagIdTo == BAG_BACKPACK then
						qtyToMove = math.min(stackSize, (maxStack - stackCountBackpack))
						bagIdTo, destSlot = FindDestSlotInBag(stackCountBackpack, bagIdTo, moveData.bagId, moveData.slotId, maxStack, moveData.itemLink)
					elseif IsBankDestinationBag(bagIdTo) then
						qtyToMove = math.min(stackSize, (maxStack - stackCountBank))
						bagIdTo, destSlot = FindDestSlotInBag(stackCountBank, bagIdTo, moveData.bagId, moveData.slotId, maxStack, moveData.itemLink) -- bagIdTo can change because of BAG_SUBSCRIBER_BANK
					end
					
					--d("qtyToMove " .. tostring(qtyToMove) .. " destSlot " .. tostring(bagIdTo) .. "/" .. tostring(destSlot))
					if destSlot then
						--d(moveData.ruleName .. " is moving " .. GetItemName(moveData.bagId, moveData.slotId) .. " (not full stack)")
						itemMoved = moveItemInSlot(moveData.bagId, moveData.slotId, bagIdTo, destSlot, qtyToMove, moveData.itemLink)
					elseif db.profiles[actualProfile].detailledNotMoved then
						PrintItemsNotMovedToBag(moveData.itemLink, moveData.itemIcon, bagIdTo, qtyToMove)
					end
				
				elseif forceAllStacks or not ruleSettings.onlyIfNotFullStack then
					
					-- All-stacks actions deliberately bypass both the numeric stack cap and
					-- the merge-only mode; ordinary actions retain the existing behavior.
					if not forceAllStacks and type(db.profiles[actualProfile].rules[moveData.ruleName].onlyStacks) == "boolean" then
						db.profiles[actualProfile].rules[moveData.ruleName].onlyStacks = 1
					end
					
					local stackCountInBag
					-- got 80 to push, bank got 350, stack is 200, 1st stack will receive 50, 2nd stack: 30 if maxStack = 3, or 50 and 0 because of maxStack = 2
					if bagIdTo == BAG_BACKPACK then
						stackCountInBag = stackCountBackpack
					elseif IsBankDestinationBag(bagIdTo) then
						stackCountInBag = stackCountBank
					end
					
					local maxQtyAuthorized = forceAllStacks and math.huge or ((tonumber(ruleSettings.onlyStacks) or 1) * maxStack)
					qtyToMove = math.min(stackSize, maxStack - (stackCountInBag % maxStack))
					
					if qtyToMove + stackCountInBag <= maxQtyAuthorized then
						bagIdTo, destSlot = FindDestSlotInBag(stackCountInBag, bagIdTo, moveData.bagId, moveData.slotId, maxStack, moveData.itemLink)
						--d("maxQtyAuthorized: " .. maxQtyAuthorized .. " stackCountInBag: " .. stackCountInBag)
						if qtyToMove == stackSize or (qtyToMove < stackSize and qtyToMove + stackCountInBag == maxQtyAuthorized) then
							
							-- 1 push to do
							--d("1 push to do")
							--d("qtyToMove " .. qtyToMove .. " destSlot " .. tostring(destSlot))
							if stackCountInBag + qtyToMove <= maxQtyAuthorized then
								if destSlot then
									itemMoved = moveItemInSlot(moveData.bagId, moveData.slotId, bagIdTo, destSlot, qtyToMove, moveData.itemLink)
								elseif db.profiles[actualProfile].detailledNotMoved then
									PrintItemsNotMovedToBag(moveData.itemLink, moveData.itemIcon, bagIdTo, qtyToMove)
								end
							end
							
						else
							
							--d("2 push to do?")
							--d("qtyToMove " .. qtyToMove .. " destSlot " .. tostring(destSlot))
							-- 2 push to do, first will fulfil, 2nd will take the modulo
							if stackCountInBag + qtyToMove <= maxQtyAuthorized then --Already too late!
								if destSlot then
									--d("2 push to do -> destSlot1:" .. destSlot)
									itemMoved = moveItemInSlot(moveData.bagId, moveData.slotId, bagIdTo, destSlot, qtyToMove, moveData.itemLink)
								elseif db.profiles[actualProfile].detailledNotMoved then
									PrintItemsNotMovedToBag(moveData.itemLink, moveData.itemIcon, bagIdTo, qtyToMove)
								end
								
								-- Maybe move1 hit the limit?
								if stackCountInBag + qtyToMove < maxQtyAuthorized then
									destSlot = FindEmptySlotInBag(bagIdTo)
									if destSlot then
										--d("2 push to do -> destSlot2:" .. destSlot)
										itemMoved = moveItemInSlot(moveData.bagId, moveData.slotId, bagIdTo, destSlot, stackSize - qtyToMove, moveData.itemLink)
										qtyToMove = stackSize -- to Display the correct value
									elseif db.profiles[actualProfile].detailledNotMoved then
										PrintItemsNotMovedToBag(moveData.itemLink, moveData.itemIcon, bagIdTo, qtyToMove)
									end
								end
							end
						end
						
					end
				
				end
				
				if itemMoved and pendingMoveVerification then
					-- Do not report an asynchronous custom transfer as successful merely
					-- because RequestMoveItem was called. Verify both source and destination
					-- before updating quantities, counters, or the chat message.
					local verification = pendingMoveVerification
					verification.displayLink = moveData.itemLink
					verification.displayIcon = moveData.itemIcon
					verification.displayBag = bagIdTo
					verification.queueData = data
					verification.moveData = moveData
					verification.nextRestartAt = restartAt + 1
					local attempts = 0
					local function verifyCustomTransfer()
						if pendingMoveVerification ~= verification then return end
						attempts = attempts + 1
						local sourceLinkAfter = GetItemLink(verification.fromBag, verification.fromSlot)
						local sourceCountAfter = GetSlotStackSize(verification.fromBag, verification.fromSlot) or 0
						local destLinkAfter = GetItemLink(verification.toBag, verification.toSlot)
						local destCountAfter = GetSlotStackSize(verification.toBag, verification.toSlot) or 0
						local sourceChanged = sourceLinkAfter ~= verification.sourceLinkBefore or sourceCountAfter <= (verification.sourceCountBefore - verification.qty)
						local destChanged = destLinkAfter == verification.itemLink and destCountAfter >= (verification.destCountBefore + verification.qty)
						local housingTransfer = IsFurnitureStorageBag(verification.fromBag) or IsFurnitureStorageBag(verification.toBag)
						local targetItemIdCountAfter
						local targetBagItemIncrease = false
						if housingTransfer and verification.sourceItemId then
							targetItemIdCountAfter = CountItemIdInBag(verification.sourceItemId, verification.toBag)
							local targetCountBefore = verification.destItemIdCountBefore
							if targetCountBefore ~= nil and targetItemIdCountAfter >= targetCountBefore + verification.qty then
								targetBagItemIncrease = true
								destChanged = true
							end
						end
						if sourceChanged and destChanged then
							if not qtyBagCache[verification.itemLink] then
								local stackCountBackpack, stackCountBank = GetItemLinkStacks(verification.itemLink)
								qtyBagCache[verification.itemLink] = {
									[BAG_BACKPACK] = stackCountBackpack or 0,
									[BAG_BANK] = stackCountBank or 0,
									[BAG_SUBSCRIBER_BANK] = stackCountBank or 0,
								}
							end
							if qtyBagCache[verification.itemLink][verification.toBag] == nil then qtyBagCache[verification.itemLink][verification.toBag] = IsFurnitureStorageBag(verification.toBag) and CountItemLinkInBag(verification.itemLink, verification.toBag) or 0 end
							if qtyBagCache[verification.itemLink][verification.fromBag] == nil then qtyBagCache[verification.itemLink][verification.fromBag] = IsFurnitureStorageBag(verification.fromBag) and CountItemLinkInBag(verification.itemLink, verification.fromBag) or 0 end
							qtyBagCache[verification.itemLink][verification.toBag] = qtyBagCache[verification.itemLink][verification.toBag] + verification.qty
							qtyBagCache[verification.itemLink][verification.fromBag] = qtyBagCache[verification.itemLink][verification.fromBag] - verification.qty
							qtyMoved = qtyMoved + verification.qty
							countMoved = countMoved + 1
							itemsMoved = itemsMoved + 1
							CustomRuleDebug(string.format("TRANSFER CONFIRMED sourceBag=%s sourceSlot=%s sourceCount=%s->%s targetBag=%s targetSlot=%s targetCount=%s->%s housingItemIdCount=%s->%s confirmation=%s qty=%s itemLink=%s", tostring(verification.fromBag), tostring(verification.fromSlot), tostring(verification.sourceCountBefore), tostring(sourceCountAfter), tostring(verification.toBag), tostring(verification.toSlot), tostring(verification.destCountBefore), tostring(destCountAfter), tostring(verification.destItemIdCountBefore), tostring(targetItemIdCountAfter), targetBagItemIncrease and "target bag itemId total increased" or "exact target slot confirmed", tostring(verification.qty), tostring(verification.itemLink)))
							if db.profiles[actualProfile].detailledDisplay then
								PrintItemsToBag(verification.displayLink, verification.displayIcon, verification.displayBag, verification.qty)
							end
							pendingMoveVerification = nil
							activeTransferVerificationDebug = nil
							zo_callLater(function() tryMoveSlots(data, bagIdTo, restartAt + 1) end, db.profiles[actualProfile].pauseInMs)
						elseif attempts < 6 then
							zo_callLater(verifyCustomTransfer, 250)
						else
							local transferItemId = GetItemLinkItemId(verification.itemLink)
							local isPvpItem = transferItemId and ((BMR_PVP_ITEM_CATALOG and BMR_PVP_ITEM_CATALOG[transferItemId]) or transferItemId == 30359)
							local sourceUnchanged = sourceLinkAfter == verification.sourceLinkBefore and sourceCountAfter == verification.sourceCountBefore
							local destinationUnchanged = destLinkAfter == verification.destLinkBefore and destCountAfter == verification.destCountBefore
							local retryCurrentMove = false
							local oneStackTargetRejected = false
							local housingTransfer = IsFurnitureStorageBag(verification.fromBag) or IsFurnitureStorageBag(verification.toBag)
							if isPvpItem and sourceUnchanged and destinationUnchanged and verification.destCountBefore > 0 and verification.destLinkBefore == verification.itemLink then
								local rejectedKey = GetRejectedPvpStackTargetKey(verification.toBag, verification.toSlot, verification.itemLink)
								rejectedPvpStackTargets[rejectedKey] = true
								local ruleName = verification.moveData and verification.moveData.ruleName or (verification.queueData and verification.queueData.ruleName)
								if IsOneStackTarget(ruleName, verification.toBag, verification.itemLink) then
									oneStackTargetRejected = true
									rejectedOneStackDestinations[GetOneStackDestinationKey(verification.itemLink, verification.toBag)] = {bagId = verification.toBag, slotId = verification.toSlot, itemLink = verification.itemLink}
									CustomRuleDebug(string.format("ONE-STACK TARGET REJECTED itemId=%s bag=%s slot=%s rule=%s reason=destination stack refused merge; keep a single physical target stack and leave excess in source", tostring(transferItemId), tostring(verification.toBag), tostring(verification.toSlot), tostring(ruleName)))
								else
									retryCurrentMove = true
									CustomRuleDebug(string.format("STACK TARGET REJECTED remembered bag=%s slot=%s itemLink=%s reason=occupied target did not accept transfer; retry current item using another slot", tostring(verification.toBag), tostring(verification.toSlot), tostring(verification.itemLink)))
								end
							end
							-- A housing transfer that made no observable change should be retried
							-- inside this run using a different target. Cap retries per queued item
							-- so an item the game rejects cannot trap the whole queue indefinitely.
							if housingTransfer and sourceUnchanged and destinationUnchanged and not retryCurrentMove and not oneStackTargetRejected then
								local moveDataForRetry = verification.moveData
								local retries = tonumber(moveDataForRetry and moveDataForRetry.housingRetryCount) or 0
								if moveDataForRetry and retries < 2 then
									moveDataForRetry.housingRetryCount = retries + 1
									local rejectedKey = GetRejectedPvpStackTargetKey(verification.toBag, verification.toSlot, verification.itemLink)
									rejectedPvpStackTargets[rejectedKey] = true
									tinyBagCache[verification.toBag] = tinyBagCache[verification.toBag] or {}
									tinyBagCache[verification.toBag][verification.toSlot] = true
									retryCurrentMove = true
									CustomRuleDebug(string.format("HOUSE STORAGE RETRY itemId=%s sourceBag=%s sourceSlot=%s targetBag=%s targetSlot=%s retry=%d/2 reason=source and destination unchanged", tostring(transferItemId), tostring(verification.fromBag), tostring(verification.fromSlot), tostring(verification.toBag), tostring(verification.toSlot), retries + 1))
								else
									CustomRuleDebug(string.format("HOUSE STORAGE RETRY EXHAUSTED itemId=%s sourceBag=%s sourceSlot=%s targetBag=%s targetSlot=%s retries=%d reason=transfer remained unchanged", tostring(transferItemId), tostring(verification.fromBag), tostring(verification.fromSlot), tostring(verification.toBag), tostring(verification.toSlot), retries))
								end
							end
							CustomRuleDebug(string.format("TRANSFER NOT CONFIRMED sourceBag=%s sourceSlot=%s sourceLinkBefore=%s sourceLinkAfter=%s sourceCount=%s->%s targetBag=%s targetSlot=%s targetLinkBefore=%s targetLinkAfter=%s targetCount=%s->%s qty=%s itemLink=%s; success message suppressed", tostring(verification.fromBag), tostring(verification.fromSlot), tostring(verification.sourceLinkBefore), tostring(sourceLinkAfter), tostring(verification.sourceCountBefore), tostring(sourceCountAfter), tostring(verification.toBag), tostring(verification.toSlot), tostring(verification.destLinkBefore), tostring(destLinkAfter), tostring(verification.destCountBefore), tostring(destCountAfter), tostring(verification.qty), tostring(verification.itemLink)))
							-- A failed transfer can be retried from the same source slot with a new target.
							-- Remove its trace first so the retry's source update cannot be paired with the failed attempt.
							if CancelExpectedPvpMoveTrace and verification.traceEntry then
								CancelExpectedPvpMoveTrace(verification.traceEntry, retryCurrentMove and "target rejected; retrying with a different slot" or "transfer not confirmed")
							end
							if db.profiles[actualProfile].detailledNotMoved and not retryCurrentMove and not oneStackTargetRejected then
								PrintItemsNotMovedToBag(verification.displayLink, verification.displayIcon, verification.displayBag, verification.qty)
							end
							pendingMoveVerification = nil
							activeTransferVerificationDebug = nil
							local nextIndex = retryCurrentMove and restartAt or (restartAt + 1)
							zo_callLater(function() tryMoveSlots(data, bagIdTo, nextIndex) end, db.profiles[actualProfile].pauseInMs)
						end
					end
					zo_callLater(verifyCustomTransfer, 250)
					return
				elseif itemMoved then
					qtyMoved = qtyMoved + qtyToMove
					countMoved = countMoved + 1
					itemsMoved = itemsMoved + 1
					if db.profiles[actualProfile].detailledDisplay then
						PrintItemsToBag(moveData.itemLink, moveData.itemIcon, bagIdTo, qtyToMove)
					end
				end
				
				zo_callLater(function() tryMoveSlots(data, bagIdTo, restartAt + 1) end, db.profiles[actualProfile].pauseInMs)
				
			else
				
				BMR.SafeAddChatMessage(GetString(BMR_ZOS_LIMITATIONS))
				pushInProgress = false -- Don't do pull
				
				-- End of moves
				if qtyMoved > 0 then
					if db.profiles[actualProfile].summary then
						PrintSummaryToBag(bagIdTo, countMoved, qtyMoved)
					end
					RestackBags()
				end
				
				FinishBankMoves()
				return
				
			end
		elseif pushInProgress then
			
			-- End of push
			pushInProgress = false
			
			if qtyMoved > 0 then
				if db.profiles[actualProfile].summary then
					PrintSummaryToBag(bagIdTo, countMoved, qtyMoved)
				end
			end
			
			qtyMoved = 0
			countMoved = 0
			
			freeSlots[BAG_BACKPACK] = GetNumBagFreeSlots(BAG_BACKPACK)
			zo_callLater(function() tryMoveSlots(pullQueue, BAG_BACKPACK) end, db.profiles[actualProfile].pauseInMs)
			
		else
			
			-- End of pull
			if qtyMoved > 0 then
				if db.profiles[actualProfile].summary then
					PrintSummaryToBag(bagIdTo, countMoved, qtyMoved)
				end
				RestackBags()
			end
			
			FinishBankMoves()
			
		end
	
	end
	
	local function doSingleMove(moveData)
		
		if db.profiles[actualProfile].rules[moveData.ruleName].associatedGuild and db.profiles[actualProfile].rules[moveData.ruleName].associatedGuild == currentGBankName then
		
			--d(moveData.ruleName .. " will check qty and if, move " .. GetItemName(moveData.bagId, moveData.slotId))
					
			-- Is slot at max size in bank ?
			local isFullStack, stackSize, maxStack, stackCountBackpack, stackCountBank = StackInfoInBag(BAG_BANK, moveData.slotId, moveData.bagId, moveData.itemLink)
			local itemMoved = false
			local qtyToMove
			
			if db.profiles[actualProfile].rules[moveData.ruleName].onlyStacks == true
			or db.profiles[actualProfile].rules[moveData.ruleName].onlyStacks == false then
				db.profiles[actualProfile].rules[moveData.ruleName].onlyStacks = 1
			end
			
			if db.profiles[actualProfile].rules[moveData.ruleName].action == ACTION_PUSH_GBANK then
				
				--d(moveData.ruleName .. " is set to push everything to GBank (ACTION_PUSH_GBANK)")
				
				qtyToMove = stackSize
				if GetNumBagFreeSlots(BAG_GUILDBANK) > 0 then
					itemMoved = moveItemInGBank(moveData.bagId, moveData.slotId)
				elseif db.profiles[actualProfile].detailledNotMoved then
					PrintItemsNotMovedToBag(moveData.itemLink, moveData.itemIcon, BAG_GUILDBANK, qtyToMove, currentGBankName)
				end
			
			elseif db.profiles[actualProfile].rules[moveData.ruleName].onlyIfNotFullStack and stackSize + stackCountBank > maxStack then
				
				qtyToMove = math.min(stackSize, stackCountBank + stackSize - maxStack)
				
				--d("qtyToMove " .. qtyToMove)
				if GetNumBagFreeSlots(BAG_GUILDBANK) > 0 then
					if qtyToMove == stackSize then
						itemMoved = moveItemInGBank(moveData.bagId, moveData.slotId)
					else
						-- Qty is not available when transfering to GBank, it's a full slot
						itemMoved = moveItemInGBank(moveData.bagId, moveData.slotId, qtyToMove, moveData.itemLink)
					end
				elseif db.profiles[actualProfile].detailledNotMoved then
					PrintItemsNotMovedToBag(moveData.itemLink, moveData.itemIcon, BAG_GUILDBANK, qtyToMove, currentGBankName)
				end
			
			elseif not db.profiles[actualProfile].rules[moveData.ruleName].onlyIfNotFullStack and stackSize + stackCountBank > db.profiles[actualProfile].rules[moveData.ruleName].onlyStacks * maxStack then
				
				qtyToMove = math.min(stackSize, stackCountBank + stackSize - maxStack)
				
				--d("qtyToMove " .. qtyToMove)
				if GetNumBagFreeSlots(BAG_GUILDBANK) > 0 then
					if qtyToMove == stackSize then
						itemMoved = moveItemInGBank(moveData.bagId, moveData.slotId)
					else
						-- Qty is not available when transfering to GBank, it's a full slot
						itemMoved = moveItemInGBank(moveData.bagId, moveData.slotId, qtyToMove, moveData.itemLink)
					end
				elseif db.profiles[actualProfile].detailledNotMoved then
					PrintItemsNotMovedToBag(moveData.itemLink, moveData.itemIcon, BAG_GUILDBANK, qtyToMove, currentGBankName)
				end
			
			end
			
			if itemMoved then
				if db.profiles[actualProfile].detailledDisplay then
					PrintItemsToBag(moveData.itemLink, moveData.itemIcon, BAG_GUILDBANK, qtyToMove, currentGBankName)
				end
			else
				--d("Nothing moved for " .. GetItemName(moveData.bagId, moveData.slotId))
			end
			
			return itemMoved, qtyToMove
			
		else
			--d("Incorrect GBank for rule " .. moveData.ruleName)
		end
		
		return false
		
	end
	
	local function tryMoveSlotsToGBank()
		
		-- Need to push/pull?
		if #pushQueue > 0 then
			--d("#pushQueue " .. tostring(restartFromAtGBank) .. "/" .. tostring(#pushQueue))
			
			-- We can't loop for GBank, because we need to wait for server response, so use next()
			local moveIndex, moveData = next(pushQueue, restartFromAtGBank)
			--d("moveIndex = " .. tostring(moveIndex))
			
			if moveIndex then
				
				local itemMoved
				-- Even if itemMoved is true, it does not garantee that it has been really moved. It has just been Transfered to GBank
				local itemMoved, qtyMoved = doSingleMove(moveData)
				
				-- It will make the loop
				restartFromAtGBank = moveIndex
				
				-- If we didn't moved our item, EVENT_MANAGER won't send anything.
				if not itemMoved then
					tryMoveSlotsToGBank()
				else
					qtyMovedToGBank = qtyMovedToGBank + qtyMoved
					countMovedToGBank = countMovedToGBank + 1
				end

			else

				if qtyMovedToGBank > 0 then
					
					if db.profiles[actualProfile].summary then
						PrintSummaryToBag(BAG_GUILDBANK, countMovedToGBank, qtyMovedToGBank, currentGBankName)
					end
					
					-- Do a Roomba if the Addon is detected
					if Roomba and Roomba.BeginStackingProcess then Roomba.BeginStackingProcess() end
					
				end
				
				--d("End of loop")
				OnCloseProcessAtGBank()
				
			end
			
		end
	
	end
	
	if atGBank then
		
		freeSlots[BAG_BACKPACK] = GetNumBagFreeSlots(BAG_BACKPACK)
		
		if not errorReasonAtGBank then
			tryMoveSlotsToGBank(errorReasonAtGBank)
		elseif errorReasonAtGBank == GUILD_BANK_TRANSFER_PENDING then -- Bank is busy, retry
			restartFromAtGBank = restartFromAtGBank - 1
			tryMoveSlotsToGBank()
		elseif errorReasonAtGBank == GUILD_BANK_NO_SPACE_LEFT then -- While we are interacting, other move can be done simultaneously
			OnCloseProcessAtGBank()
		else
			tryMoveSlotsToGBank()
		end
		
	else
		
		freeSlots[BAG_BANK] = GetNumBagFreeSlots(BAG_BANK)
		freeSlots[BAG_SUBSCRIBER_BANK] = GetNumBagFreeSlots(BAG_SUBSCRIBER_BANK)
		if IsFurnitureStorageBag(pushTargetBag) then freeSlots[pushTargetBag] = GetNumBagFreeSlots(pushTargetBag) or 0 end
		tryMoveSlots(pushQueue, pushTargetBag)
		
	end
	
end

-- Currency API adapter.
-- The deprecated GetCarriedCurrencyAmount/GetBankedCurrencyAmount and
-- DepositCurrencyIntoBank/WithdrawCurrencyFromBank aliases are PC-only on some
-- clients (including Forced Console Flow). Prefer the supported location-based API.
local function GetBMRCurrencyApiMode()
	if type(GetCurrencyAmount) == "function"
		and type(TransferCurrency) == "function"
		and CURRENCY_LOCATION_CHARACTER ~= nil
		and CURRENCY_LOCATION_BANK ~= nil then
		return "modern"
	end
	if type(GetCarriedCurrencyAmount) == "function"
		and type(GetBankedCurrencyAmount) == "function"
		and type(DepositCurrencyIntoBank) == "function"
		and type(WithdrawCurrencyFromBank) == "function" then
		return "legacy"
	end
	return nil
end

local function ReadBMRCurrencyAmount(apiMode, currencyType, isBank)
	local ok, amount
	if apiMode == "modern" then
		local location = isBank and CURRENCY_LOCATION_BANK or CURRENCY_LOCATION_CHARACTER
		ok, amount = pcall(GetCurrencyAmount, currencyType, location)
	else
		local currencyFunction = isBank and GetBankedCurrencyAmount or GetCarriedCurrencyAmount
		if type(currencyFunction) ~= "function" then return nil end
		ok, amount = pcall(currencyFunction, currencyType)
	end
	if ok and type(amount) == "number" then return amount end
	if not ok and type(BMR.ProfileDiagnostic) == "function" then
		BMR.ProfileDiagnostic("CURRENCY_READ_ERROR", tostring(amount))
	end
	return nil
end

local function TransferBMRCurrency(apiMode, currencyType, amount, toBank)
	if type(amount) ~= "number" or amount <= 0 then return false end
	local ok, err
	if apiMode == "modern" then
		local fromLocation = toBank and CURRENCY_LOCATION_CHARACTER or CURRENCY_LOCATION_BANK
		local toLocation = toBank and CURRENCY_LOCATION_BANK or CURRENCY_LOCATION_CHARACTER
		ok, err = pcall(TransferCurrency, currencyType, amount, fromLocation, toLocation)
	else
		local currencyFunction = toBank and DepositCurrencyIntoBank or WithdrawCurrencyFromBank
		if type(currencyFunction) ~= "function" then return false end
		ok, err = pcall(currencyFunction, currencyType, amount)
	end
	if not ok and type(BMR.ProfileDiagnostic) == "function" then
		BMR.ProfileDiagnostic("CURRENCY_TRANSFER_ERROR", tostring(err))
	end
	return ok
end

-- Move a currency.
local function moveCurrency(ruleName, currencyType, apiMode)
	if currencyType == nil or apiMode == nil then return nil, nil end
	local profile = db and db.profiles and db.profiles[actualProfile]
	local rule = profile and profile.rules and profile.rules[ruleName]
	if type(rule) ~= "table" then return nil, nil end

	local currentCurrencyInInventory = ReadBMRCurrencyAmount(apiMode, currencyType, false)
	local currentCurrencyInBank = ReadBMRCurrencyAmount(apiMode, currencyType, true)
	if currentCurrencyInInventory == nil or currentCurrencyInBank == nil then return nil, nil end

	local inverted = rule.keepInBank
	local currencyActionDone
	local currencyAmountMoved

	if inverted then
		-- Keep the configured amount in the bank instead of in inventory.
		local pushCurrency = currentCurrencyInBank > rule.qtyToPush and (rule.qtyToPush > 0 or (rule.keepNothing and rule.qtyToPush == 0))
		local pullCurrency = rule.qtyToPull > 0 and currentCurrencyInBank < rule.qtyToPull and currentCurrencyInInventory > 0

		if pullCurrency then
			currencyAmountMoved = math.min(rule.qtyToPull - currentCurrencyInBank, currentCurrencyInInventory)
			if currencyAmountMoved > 0 and TransferBMRCurrency(apiMode, currencyType, currencyAmountMoved, true) then
				if profile.detailledDisplay then PrintCurrencyToBank(currencyType, currencyAmountMoved) end
				currencyActionDone = ACTION_PUSH
			end
		elseif pushCurrency then
			currencyAmountMoved = currentCurrencyInBank - rule.qtyToPush
			if currencyAmountMoved > 0 and TransferBMRCurrency(apiMode, currencyType, currencyAmountMoved, false) then
				if profile.detailledDisplay then PrintCurrencyToBag(currencyType, currencyAmountMoved) end
				currencyActionDone = ACTION_PULL
			end
		end
	else
		-- Keep the configured amount in inventory, optionally topping it up from the bank.
		local pushCurrency = currentCurrencyInInventory > rule.qtyToPush and (rule.qtyToPush > 0 or (rule.keepNothing and rule.qtyToPush == 0))
		local pullCurrency = rule.qtyToPull > 0 and currentCurrencyInInventory < rule.qtyToPull and currentCurrencyInBank > 0

		if pullCurrency then
			currencyAmountMoved = math.min(rule.qtyToPull - currentCurrencyInInventory, currentCurrencyInBank)
			if currencyAmountMoved > 0 and TransferBMRCurrency(apiMode, currencyType, currencyAmountMoved, false) then
				if profile.detailledDisplay then PrintCurrencyToBag(currencyType, currencyAmountMoved) end
				currencyActionDone = ACTION_PULL
			end
		elseif pushCurrency then
			currencyAmountMoved = currentCurrencyInInventory - rule.qtyToPush
			if currencyAmountMoved > 0 and TransferBMRCurrency(apiMode, currencyType, currencyAmountMoved, true) then
				if profile.detailledDisplay then PrintCurrencyToBank(currencyType, currencyAmountMoved) end
				currencyActionDone = ACTION_PUSH
			end
		end
	end

	return currencyActionDone, currencyAmountMoved
end

-- Move currencies. Do not let one unavailable currency constant prevent gold from moving.
local function moveCurrencies()
	if activeHouseStorageBagId then
		CustomRuleDebug("CURRENCY MOVE SKIP reason=active house storage cannot receive bank currencies")
		return
	end

	local apiMode = GetBMRCurrencyApiMode()
	if not apiMode then
		if not BMR._currencyApiWarningShown then
			BMR._currencyApiWarningShown = true
			local missing = {}
			if type(GetCurrencyAmount) ~= "function" then missing[#missing + 1] = "GetCurrencyAmount" end
			if type(TransferCurrency) ~= "function" then missing[#missing + 1] = "TransferCurrency" end
			if CURRENCY_LOCATION_CHARACTER == nil then missing[#missing + 1] = "CURRENCY_LOCATION_CHARACTER" end
			if CURRENCY_LOCATION_BANK == nil then missing[#missing + 1] = "CURRENCY_LOCATION_BANK" end
			if type(GetCarriedCurrencyAmount) ~= "function" then missing[#missing + 1] = "GetCarriedCurrencyAmount" end
			if type(GetBankedCurrencyAmount) ~= "function" then missing[#missing + 1] = "GetBankedCurrencyAmount" end
			if type(DepositCurrencyIntoBank) ~= "function" then missing[#missing + 1] = "DepositCurrencyIntoBank" end
			if type(WithdrawCurrencyFromBank) ~= "function" then missing[#missing + 1] = "WithdrawCurrencyFromBank" end
			BMR.ProfileDiagnostic("CURRENCY_AUTOMATION_UNAVAILABLE", table.concat(missing, ", "))
			if BMR.Console and type(BMR.Console.IsControllerFlowActive) == "function" and BMR.Console.IsControllerFlowActive() then
				BMR.ProfileDiagnosticChat("BMR: Währungsautomatik nicht verfügbar; normale Gegenstandsregeln laufen weiter.")
			end
		end
		return
	end

	local moves = {}
	local amounts = {}
	local currencyTypes = {}
	if CURT_MONEY ~= nil then currencyTypes[#currencyTypes + 1] = CURT_MONEY end
	if CURT_TELVAR_STONES ~= nil then currencyTypes[#currencyTypes + 1] = CURT_TELVAR_STONES end
	if CURT_ALLIANCE_POINTS ~= nil then currencyTypes[#currencyTypes + 1] = CURT_ALLIANCE_POINTS end
	if CURT_WRIT_VOUCHERS ~= nil then currencyTypes[#currencyTypes + 1] = CURT_WRIT_VOUCHERS end

	for _, currencyType in ipairs(currencyTypes) do
		moves[currencyType], amounts[currencyType] = moveCurrency("currency" .. currencyType, currencyType, apiMode)
	end

	-- Some controller/console UI flows lack the keyboard currency formatter. A
	-- missing summary formatter must not undo or interrupt a currency transfer.
	if type(ZO_CurrencyControl_FormatCurrencyAndAppendIcon) == "function"
		and type(zo_strformat) == "function"
		and db and db.profiles and db.profiles[actualProfile]
		and db.profiles[actualProfile].summary
		and (NonContiguousCount(moves) > 1 or (not db.profiles[actualProfile].detailledDisplay and NonContiguousCount(moves) == 1)) then
		local ok, message = pcall(function()
			local output
			for currencyType, side in pairs(moves) do
				if side ~= nil and amounts[currencyType] ~= nil then
					local line = GetString(BMR_ACTION_HAS_MOVED) .. zo_strformat(BMR_ACTION_CURRENCY_GSUMMARY, ZO_CurrencyControl_FormatCurrencyAndAppendIcon(amounts[currencyType], true, currencyType), GetString("BMR_ACTION_CURRENCY_MOVED_TO", side))
					if not output then output = line else output = table.concat({output, line}, GetString(SI_LIST_COMMA_SEPARATOR)) end
				end
			end
			return output
		end)
		if ok and message then BMR.SafeAddChatMessage(message) end
	end
end

local function ScriptDebug(message)
	if db and db.scriptTracker and db.scriptTracker.debug then
		d(string.format("[BMR ScriptTracker DEBUG] %s", tostring(message)))
	end
end

local function RunTransferProviders()
	ScriptDebug("RunTransferProviders() entered")
	ScriptDebug("ScriptTracker global: " .. tostring(ScriptTracker ~= nil))
	ScriptDebug("db.scriptTracker: " .. tostring(db.scriptTracker ~= nil))
	if db.scriptTracker then
		ScriptDebug(string.format("settings enabled=%s depositKnown=%s withdrawUnknown=%s withdrawOneOnly=%s", tostring(db.scriptTracker.enabled), tostring(db.scriptTracker.depositKnown), tostring(db.scriptTracker.withdrawUnknown), tostring(db.scriptTracker.withdrawOneOnly)))
	end
	local function addCustomMove(bagId, slotId, direction, maxQty)
		if not bagId or not slotId or (movedItems[bagId] and movedItems[bagId][slotId]) then return end
		local itemLink = GetItemLink(bagId, slotId)
		if not itemLink or itemLink == "" then return end
		local itemId = GetItemId(bagId, slotId)
		if not itemId or itemId == 0 then return end

		local moveData = {
			ruleName = "__BMR_CUSTOM__",
			bagId = bagId,
			slotId = slotId,
			itemLink = itemLink,
			itemIcon = GetItemLinkInfo(itemLink),
			custom = true,
			maxQty = maxQty,
		}

		if direction == "push" and bagId == BAG_BACKPACK then
			table.insert(pushQueue, moveData)
			movedItems[bagId] = movedItems[bagId] or {}
			movedItems[bagId][slotId] = true
		elseif direction == "pull" and IsCurrentStorageSourceBag(bagId) then
			table.insert(pullQueue, moveData)
			movedItems[bagId] = movedItems[bagId] or {}
			movedItems[bagId][slotId] = true
			hasAnyPullToDo = true
		end
	end

	-- Built-in ScriptTracker integration.
	if db.scriptTracker and db.scriptTracker.enabled and ScriptTracker then
		local charId = GetCurrentCharacterId()
		ScriptDebug("Current character ID: " .. tostring(charId))
		ScriptDebug("API GetScriptId=" .. tostring(type(ScriptTracker.GetScriptId)) .. ", DoesCharHaveScriptUnlocked=" .. tostring(type(ScriptTracker.DoesCharHaveScriptUnlocked)) .. ", ScanCharacter=" .. tostring(type(ScriptTracker.ScanCharacter)))
		if ScriptTracker.ScanCharacter then
			local ok, err = pcall(ScriptTracker.ScanCharacter)
			ScriptDebug("ScanCharacter result: " .. tostring(ok) .. (err and (" / " .. tostring(err)) or ""))
		end

		local function isScriptKnown(scriptId)
			if not scriptId or scriptId == 0 then return false end
			if ScriptTracker.DoesCharHaveScriptUnlocked then
				local known = ScriptTracker.DoesCharHaveScriptUnlocked(charId, scriptId)
				if known ~= nil then return known == true end
			end
			return ScriptTracker.GetScriptUnlocked and ScriptTracker.GetScriptUnlocked(scriptId) == true
		end

		local seenUnknown = {}
		local inventoryScripts = {}

		-- Scan the current inventory once. Besides finding known scripts to deposit,
		-- this also prevents withdrawing a second copy of a script already carried.
		if (db.scriptTracker.depositKnown or db.scriptTracker.withdrawUnknown) and ScriptTracker.GetScriptId then
			local scanned, recognized, known, queued, inventoryCount = 0, 0, 0, 0, 0
			local size = GetBagSize(BAG_BACKPACK)
			ScriptDebug("Scanning backpack, size=" .. tostring(size))
			for slotIndex = 0, size - 1 do
				local itemId = GetItemId(BAG_BACKPACK, slotIndex)
				if itemId and itemId ~= 0 then
					scanned = scanned + 1
					local scriptId = ScriptTracker.GetScriptId(itemId)
					if scriptId and scriptId ~= 0 then
						recognized = recognized + 1
						if not inventoryScripts[scriptId] then inventoryCount = inventoryCount + 1 end
						inventoryScripts[scriptId] = true
						local knownState = isScriptKnown(scriptId)
						ScriptDebug(string.format("BACKPACK slot=%d itemId=%d scriptId=%s known=%s item=%s", slotIndex, itemId, tostring(scriptId), tostring(knownState), tostring(GetItemName(BAG_BACKPACK, slotIndex))))
						if db.scriptTracker.depositKnown and knownState then
							known = known + 1
							addCustomMove(BAG_BACKPACK, slotIndex, "push")
							queued = queued + 1
						end
					end
				end
			end
			ScriptDebug(string.format("Backpack result: scanned=%d recognized=%d known=%d queued=%d inventoryScripts=%d", scanned, recognized, known, queued, inventoryCount))
		end

		if db.scriptTracker.withdrawUnknown and ScriptTracker.GetScriptId then
			local function scanBank(bagId, bagName)
				local scanned, recognized, unknown, queued = 0, 0, 0, 0
				local size = GetBagSize(bagId)
				ScriptDebug("Scanning " .. bagName .. ", size=" .. tostring(size))
				for slotIndex = 0, size - 1 do
					local itemId = GetItemId(bagId, slotIndex)
					if itemId and itemId ~= 0 then
						scanned = scanned + 1
						local scriptId = ScriptTracker.GetScriptId(itemId)
						if scriptId and scriptId ~= 0 then
							recognized = recognized + 1
							local knownState = isScriptKnown(scriptId)
							ScriptDebug(string.format("%s slot=%d itemId=%d scriptId=%s known=%s item=%s", bagName, slotIndex, itemId, tostring(scriptId), tostring(knownState), tostring(GetItemName(bagId, slotIndex))))
							if not knownState and not inventoryScripts[scriptId] and not seenUnknown[scriptId] then
								unknown = unknown + 1
								addCustomMove(bagId, slotIndex, "pull", db.scriptTracker.withdrawOneOnly and 1 or nil)
								queued = queued + 1
								seenUnknown[scriptId] = true
							end
						end
					end
				end
				ScriptDebug(string.format("%s result: scanned=%d recognized=%d unknown=%d queued=%d", bagName, scanned, recognized, unknown, queued))
			end
			for _, sourceBag in ipairs(GetCurrentStorageSourceBags()) do
			scanBank(sourceBag, activeHouseStorageBagId and "HOUSE_STORAGE" or (sourceBag == BAG_SUBSCRIBER_BANK and "SUBSCRIBER_BANK" or "BANK"))
		end
		end
	end

	ScriptDebug(string.format("Queues after ScriptTracker: push=%d pull=%d", #pushQueue, #pullQueue))

	-- External integrations can register additional transfer providers.
	for name, provider in pairs(transferProviders or {}) do
		if type(provider) == "function" then
			local ok, err = pcall(provider, addCustomMove, actualProfile, db.profiles[actualProfile])
			if not ok then
				d(string.format("[BMR] Transfer provider '%s' failed: %s", tostring(name), tostring(err)))
			end
		end
	end
end

-- Convert one-stack requests into partial transfers. The configured target container
-- (backpack or bank) retains up to one compatible stack; the opposite container holds
-- any excess or incompatible link variants.
local function BuildOneStackQueues()
	-- Remove any already queued provider moves for an explicitly configured item:
	-- the one-stack rule has priority over every other action for that item.
	for index = #pushQueue, 1, -1 do
		if oneStackRequests[pushQueue[index].itemLink] then table.remove(pushQueue, index) end
	end
	for index = #pullQueue, 1, -1 do
		if oneStackRequests[pullQueue[index].itemLink] then table.remove(pullQueue, index) end
	end
	-- A one-stack rule is per item ID, not per full item-link variant. Some items
	-- (for example Brand Oil) have hidden item data that makes otherwise identical
	-- looking links incompatible for stacking. Process exactly one compatible link
	-- variant per item ID. When readable PvP energy exists, the configured used/unused
	-- priority selects the preferred variant; otherwise use the existing location/count fallback.
	local variantsByItemId = {}
	for itemLink, request in pairs(oneStackRequests) do
		local itemId = GetItemLinkItemId(itemLink)
		if itemId then
			local stats = {itemLink = itemLink, request = request, backpackCount = 0, bankCount = 0, maxBankStack = 0}
			for _, slot in ipairs(request.backpackSlots) do
				if GetItemLink(slot.bagId, slot.slotId) == itemLink then
					local count = GetSlotStackSize(slot.bagId, slot.slotId)
					if count and count > 0 then stats.backpackCount = stats.backpackCount + count end
				end
			end
			for _, slot in ipairs(request.bankSlots) do
				if GetItemLink(slot.bagId, slot.slotId) == itemLink then
					local count = GetSlotStackSize(slot.bagId, slot.slotId)
					if count and count > 0 then
						stats.bankCount = stats.bankCount + count
						stats.maxBankStack = math.max(stats.maxBankStack, count)
					end
				end
			end
			variantsByItemId[itemId] = variantsByItemId[itemId] or {}
			table.insert(variantsByItemId[itemId], stats)
		end
	end
	local selectedLinkByItemId = {}
	for itemId, variants in pairs(variantsByItemId) do
		local selected, hasBackpackVariant
		-- For siege items with readable energy, select the variant matching the
		-- configured preference (used = lowest energy, unused = highest energy).
		-- Only compare when every candidate has a reliable value.
		local allHaveEnergy, preferredUsed = true, (db.profiles[actualProfile].pvpPriorityState or "unused") == "used"
		-- Do not rank a variant from its table key alone. Some ESO links differ by
		-- hidden payload fields; rank the actual slot links which will be transferred.
		for _, stats in ipairs(variants) do
			stats.bestEnergy = nil
			local function considerSlot(slot)
				if GetItemLink(slot.bagId, slot.slotId) == stats.itemLink then
					local energy = GetSiegeRemainingEnergy(GetItemLink(slot.bagId, slot.slotId))
					if energy == nil then allHaveEnergy = false
					elseif stats.bestEnergy == nil or (preferredUsed and energy < stats.bestEnergy) or (not preferredUsed and energy > stats.bestEnergy) then stats.bestEnergy = energy end
				end
			end
			for _, request in pairs(oneStackRequests) do
				if request == stats.request then
					for _, slot in ipairs(request.backpackSlots) do considerSlot(slot) end
					for _, slot in ipairs(request.bankSlots) do considerSlot(slot) end
					break
				end
			end
			if stats.bestEnergy == nil then allHaveEnergy = false end
		end
		if #variants > 1 and allHaveEnergy then
			for _, stats in ipairs(variants) do
				if not selected or (preferredUsed and stats.bestEnergy < selected.bestEnergy) or (not preferredUsed and stats.bestEnergy > selected.bestEnergy) then selected = stats end
			end
			if selected then hasBackpackVariant = selected.backpackCount > 0 end
		end
		if not ( #variants > 1 and allHaveEnergy ) then
		for _, stats in ipairs(variants) do
			if stats.backpackCount > 0 then
				if not selected or not hasBackpackVariant or (stats.backpackCount + stats.bankCount) > (selected.backpackCount + selected.bankCount) then
					selected, hasBackpackVariant = stats, true
				end
			end
		end
		if not selected then
			for _, stats in ipairs(variants) do
				if not selected or stats.bankCount > selected.bankCount or (stats.bankCount == selected.bankCount and stats.maxBankStack > selected.maxBankStack) then selected = stats end
			end
		end
		end -- no reliable energy priority
		if selected then
			selectedLinkByItemId[itemId] = selected.itemLink
			if #variants > 1 then
				local selectionReason
				if allHaveEnergy then
					selectionReason = preferredUsed and "lowest remaining energy (used preferred)" or "highest remaining energy (unused preferred)"
				else
					selectionReason = hasBackpackVariant and "fallback: prefer existing backpack variant" or "fallback: largest bank variant"
				end
				CustomRuleDebug(string.format("LINK VARIANTS itemId=%s count=%d selected=%s backpack=%d bank=%d reason=%s", tostring(itemId), #variants, tostring(selected.itemLink), selected.backpackCount, selected.bankCount, selectionReason))
				for _, stats in ipairs(variants) do
					CustomRuleDebug(string.format("  variant=%s backpack=%d bank=%d %s", tostring(stats.itemLink), stats.backpackCount, stats.bankCount, stats.itemLink == selected.itemLink and "SELECTED" or "IGNORED"))
				end
			end
		end
	end
	for itemLink, request in pairs(oneStackRequests) do
		local itemId = GetItemLinkItemId(itemLink)
		local selectedLink = itemId and selectedLinkByItemId[itemId]
		if selectedLink and selectedLink ~= itemLink then
			-- Keep incompatible variants outside the container targeted by the one-stack
			-- rule. For the backpack target, deposit ignored backpack variants; for the
			-- bank target, withdraw ignored bank variants. This is deliberately symmetric.
			if request.targetBank then
				local ignoredBank = request.bankSlots
				for index = #ignoredBank, 1, -1 do
					local slot = ignoredBank[index]
					if GetItemLink(slot.bagId, slot.slotId) == itemLink then
						local count = GetSlotStackSize(slot.bagId, slot.slotId)
						if count and count > 0 then
							table.insert(pullQueue, {ruleName = request.ruleName, bagId = slot.bagId, slotId = slot.slotId, itemLink = itemLink, itemIcon = GetItemLinkInfo(itemLink), custom = true, maxQty = count})
							CustomRuleDebug(string.format("  selected WITHDRAW incompatible variant itemId=%s bag=%s slot=%s qty=%d reason=one-stack target is BANK; keep ignored link variant outside bank", tostring(itemId), tostring(slot.bagId), tostring(slot.slotId), count))
						end
					end
				end
			else
				local ignoredBackpack = request.backpackSlots
				for index = #ignoredBackpack, 1, -1 do
					local slot = ignoredBackpack[index]
					if GetItemLink(slot.bagId, slot.slotId) == itemLink then
						local count = GetSlotStackSize(slot.bagId, slot.slotId)
						if count and count > 0 then
							table.insert(pushQueue, {ruleName = request.ruleName, bagId = slot.bagId, slotId = slot.slotId, itemLink = itemLink, itemIcon = GetItemLinkInfo(itemLink), custom = true, maxQty = count})
							CustomRuleDebug(string.format("  selected DEPOSIT incompatible variant itemId=%s bag=%s slot=%s qty=%d reason=one-stack target is INVENTORY; keep ignored link variant outside backpack", tostring(itemId), tostring(slot.bagId), tostring(slot.slotId), count))
						end
					end
				end
			end
		else
		local ruleSource = request.isCustomRule and "CUSTOM ITEM RULE" or "NORMAL CATEGORY RULE"
		CustomRuleDebug(string.format("ONE-STACK candidates source=%s name=%s itemId=%s rule=%s link=%s", ruleSource, tostring(GetItemLinkName(itemLink)), tostring(GetItemLinkItemId(itemLink)), tostring(request.ruleName), tostring(itemLink)))
		local backpackCount, bankCount, maxStack = 0, 0, nil
		local validBackpack, validBank = {}, {}
		for _, slot in ipairs(request.backpackSlots) do
			if GetItemLink(slot.bagId, slot.slotId) == itemLink then
				local count, maximum = GetSlotStackSize(slot.bagId, slot.slotId)
				if count and count > 0 then
					backpackCount = backpackCount + count; maxStack = maximum or maxStack
					table.insert(validBackpack, {bagId = slot.bagId, slotId = slot.slotId, count = count})
					CustomRuleDebug("  inventory candidate bag=" .. tostring(slot.bagId) .. " slot=" .. tostring(slot.slotId) .. " " .. GetCustomRuleSlotDebugInfo(slot.bagId, slot.slotId) .. GetBrandOilDiagnosticInfo(slot.bagId, slot.slotId, itemLink))
				end
			end
		end
		for _, slot in ipairs(request.bankSlots) do
			if GetItemLink(slot.bagId, slot.slotId) == itemLink then
				local count, maximum = GetSlotStackSize(slot.bagId, slot.slotId)
				if count and count > 0 then
					bankCount = bankCount + count; maxStack = maximum or maxStack
					table.insert(validBank, {bagId = slot.bagId, slotId = slot.slotId, count = count})
					CustomRuleDebug("  bank candidate bag=" .. tostring(slot.bagId) .. " slot=" .. tostring(slot.slotId) .. " " .. GetCustomRuleSlotDebugInfo(slot.bagId, slot.slotId) .. GetBrandOilDiagnosticInfo(slot.bagId, slot.slotId, itemLink))
				end
			end
		end
		if itemId and BMR_PVP_ITEM_CATALOG and BMR_PVP_ITEM_CATALOG[itemId] then
			-- PvP siege items can expose a generic maxStack (often 20) even when
			-- the game refuses to merge two physical siege slots that have the same
			-- visible/full item link. For the special one-stack actions, count physical
			-- slots rather than item quantity: retain one slot in the requested target
			-- container and leave additional physical stacks in the opposite container.
			local function pickKeeperSlot(slots)
				local keep
				for _, slot in ipairs(slots) do
					if not keep or (slot.count or 0) > (keep.count or 0) then keep = slot end
				end
				return keep
			end
			local function queuePvPPhysicalMove(queue, slot, reason)
				if not slot then return end
				table.insert(queue, {ruleName = request.ruleName, bagId = slot.bagId, slotId = slot.slotId, itemLink = itemLink, itemIcon = GetItemLinkInfo(itemLink), custom = true, maxQty = slot.count})
				CustomRuleDebug(string.format("  selected %s itemId=%s bag=%s slot=%s qty=%d reason=%s", queue == pushQueue and "DEPOSIT" or "WITHDRAW", tostring(itemId), tostring(slot.bagId), tostring(slot.slotId), tonumber(slot.count) or 0, reason))
			end
			if request.targetBank then
				local keep = pickKeeperSlot(validBank)
				if keep then
					CustomRuleDebug(string.format("  decision PvP physical stacks target=BANK backpackSlots=%d bankSlots=%d keepBankSlot=%s excessBankSlots=%d", #validBackpack, #validBank, tostring(keep.slotId), math.max(0, #validBank - 1)))
					for _, slot in ipairs(validBank) do
						if slot ~= keep then queuePvPPhysicalMove(pullQueue, slot, "keep exactly one physical stack in BANK; move duplicate target stack out") end
					end
				else
					local source = pickKeeperSlot(validBackpack)
					CustomRuleDebug(string.format("  decision PvP physical stacks target=BANK backpackSlots=%d bankSlots=0; take one physical source stack", #validBackpack))
					if source then queuePvPPhysicalMove(pushQueue, source, "BANK has no selected stack; deposit one physical stack only") end
				end
			else
				local keep = pickKeeperSlot(validBackpack)
				if keep then
					CustomRuleDebug(string.format("  decision PvP physical stacks target=INVENTORY backpackSlots=%d bankSlots=%d keepBackpackSlot=%s excessBackpackSlots=%d", #validBackpack, #validBank, tostring(keep.slotId), math.max(0, #validBackpack - 1)))
					for _, slot in ipairs(validBackpack) do
						if slot ~= keep then queuePvPPhysicalMove(pushQueue, slot, "keep exactly one physical stack in INVENTORY; deposit duplicate target stack") end
					end
				else
					local source = pickKeeperSlot(validBank)
					CustomRuleDebug(string.format("  decision PvP physical stacks target=INVENTORY backpackSlots=0 bankSlots=%d; take one physical source stack only", #validBank))
					if source then queuePvPPhysicalMove(pullQueue, source, "INVENTORY has no selected stack; withdraw one physical stack only") end
				end
			end
		elseif maxStack and maxStack > 0 then
			local targetCount = math.min(backpackCount + bankCount, maxStack)
			if request.targetBank then
				local excessBank = math.max(0, bankCount - targetCount)
				CustomRuleDebug(string.format("  decision target=BANK backpack=%d bank=%d maxStack=%d targetBank=%d excessBank=%d neededFromInventory=%d", backpackCount, bankCount, maxStack, targetCount, excessBank, math.max(0, targetCount - bankCount)))
				-- Mirror the inventory-target behavior: rank the destination's existing
				-- stacks by the configured PvP preference and withdraw least-preferred
				-- stacks first. If energy is unavailable, keep the legacy reverse-slot order.
				local preferredUsed = (db.profiles[actualProfile].pvpPriorityState or "unused") == "used"
				local rankedBank = {}
				for index, slot in ipairs(validBank) do
					local link = GetItemLink(slot.bagId, slot.slotId)
					local energy = GetSiegeRemainingEnergy(link)
					table.insert(rankedBank, {slot = slot, index = index, energy = energy})
				end
				local hasBankEnergy = #rankedBank > 0
				for _, entry in ipairs(rankedBank) do if entry.energy == nil then hasBankEnergy = false; break end end
				if hasBankEnergy then
					table.sort(rankedBank, function(a, b)
						if a.energy ~= b.energy then return preferredUsed and a.energy < b.energy or (not preferredUsed and a.energy > b.energy) end
						return a.index < b.index
					end)
				else
					table.sort(rankedBank, function(a, b) return a.index < b.index end)
				end
				for index = #rankedBank, 1, -1 do
					if excessBank <= 0 then break end
					local slot = rankedBank[index].slot
					local amount = math.min(slot.count, excessBank)
					table.insert(pullQueue, {ruleName = request.ruleName, bagId = slot.bagId, slotId = slot.slotId, itemLink = itemLink, itemIcon = GetItemLinkInfo(itemLink), custom = true, maxQty = amount})
					CustomRuleDebug(string.format("  selected WITHDRAW bag=%s slot=%s qty=%d reason=BANK exceeds one target stack; preserve preferred PvP energy", tostring(slot.bagId), tostring(slot.slotId), amount))
					excessBank = excessBank - amount
				end
				local needBank = math.max(0, targetCount - bankCount)
				for _, slot in ipairs(validBackpack) do
					if needBank <= 0 then break end
					local amount = math.min(slot.count, needBank)
					table.insert(pushQueue, {ruleName = request.ruleName, bagId = slot.bagId, slotId = slot.slotId, itemLink = itemLink, itemIcon = GetItemLinkInfo(itemLink), custom = true, maxQty = amount})
					needBank = needBank - amount
				end
			else
			local excess = math.max(0, backpackCount - targetCount)
			CustomRuleDebug(string.format("  decision backpack=%d bank=%d maxStack=%d targetInventory=%d excessToDeposit=%d neededFromBank=%d", backpackCount, bankCount, maxStack, targetCount, excess, math.max(0, targetCount - backpackCount)))
			-- Preserve the stack matching the configured PvP state. For used-priority
			-- keep the lowest-energy stack; for unused-priority keep the highest-energy
			-- stack. Non-PvP items retain the legacy reverse-slot ordering.
			local preferredUsed = (db.profiles[actualProfile].pvpPriorityState or "unused") == "used"
			local rankedBackpack = {}
			for index, slot in ipairs(validBackpack) do
				local link = GetItemLink(slot.bagId, slot.slotId)
				local energy = GetSiegeRemainingEnergy(link)
				table.insert(rankedBackpack, {slot = slot, index = index, energy = energy})
			end
			local hasEnergy = #rankedBackpack > 0
			for _, entry in ipairs(rankedBackpack) do if entry.energy == nil then hasEnergy = false; break end end
			if hasEnergy then
				table.sort(rankedBackpack, function(a, b)
					if a.energy ~= b.energy then return preferredUsed and a.energy < b.energy or (not preferredUsed and a.energy > b.energy) end
					return a.index < b.index
				end)
			else
				table.sort(rankedBackpack, function(a, b) return a.index > b.index end)
			end
			-- First sorted slot is retained; deposits consume the least-preferred stacks first.
			for index = #rankedBackpack, 1, -1 do
				if excess <= 0 then break end
				local slot = rankedBackpack[index].slot
				local amount = math.min(slot.count, excess)
				table.insert(pushQueue, {ruleName = request.ruleName, bagId = slot.bagId, slotId = slot.slotId, itemLink = itemLink, itemIcon = GetItemLinkInfo(itemLink), custom = true, maxQty = amount})
				CustomRuleDebug(string.format("  selected DEPOSIT bag=%s slot=%s qty=%d reason=inventory exceeds one target stack; preserve preferred PvP energy", tostring(slot.bagId), tostring(slot.slotId), amount))
				excess = excess - amount
			end
			local need = math.max(0, targetCount - backpackCount)
			for _, slot in ipairs(validBank) do
				if need <= 0 then break end
				local amount = math.min(slot.count, need)
				table.insert(pullQueue, {ruleName = request.ruleName, bagId = slot.bagId, slotId = slot.slotId, itemLink = itemLink, itemIcon = GetItemLinkInfo(itemLink), custom = true, maxQty = amount})
				CustomRuleDebug(string.format("  selected WITHDRAW bag=%s slot=%s qty=%d reason=fill inventory toward one target stack", tostring(slot.bagId), tostring(slot.slotId), amount))
				need = need - amount
			end
			end -- target inventory
		else
			CustomRuleDebug("  decision skipped: maximum stack size could not be determined")
		end
		end -- selected compatible variant
	end
end

-- move currencies, prepare items, build push/pull queue and move items
local function interactWithBank()
	-- Refresh live context before any currency or item rule is evaluated.
	-- The house storage bag is the destination/source, not the personal bank.
	if isBanking then RefreshActiveHouseStorageBagContext("INTERACT_WITH_BANK") end
	if activeHouseStorageBagId then movedItems[activeHouseStorageBagId] = movedItems[activeHouseStorageBagId] or {} end
	
	CustomRuleDebug(string.format("INTERACT BANK ENTER isBanking=%s inProgress=%s phase=%s profile=%s pushQueue=%d pullQueue=%d hasAnyPullToDo=%s hasAnySpecialPullToDo=%s pendingVerification=%s expectedTraceCount=%d", tostring(isBanking), tostring(inProgress), tostring(activeRuleRunPhase), tostring(actualProfile), #pushQueue, #pullQueue, tostring(hasAnyPullToDo), tostring(hasAnySpecialPullToDo), tostring(activeTransferVerificationDebug ~= nil), #pvpExpectedMoveTraces))
	BMR.ProfileDiagnostic("PERSONAL_BANK_SCAN_ENTRY", BMR.ProfileDebugRuleActionSummary() .. "; " .. BMR.ProfileDebugBagCacheSummary(BAG_BACKPACK) .. "; " .. BMR.ProfileDebugSnapshot())
	if inProgress and activeRuleRunPhase ~= "moving" and activeTransferVerificationDebug == nil then
		-- Queue building is synchronous. If another click can run while the phase is
		-- still building (or nil), the previous run has unwound and stale state can be cleared.
		CustomRuleDebug(string.format("INTERACT BANK RECOVERY reason=stale non-moving phase (%s); previous run did not keep an active move loop", tostring(activeRuleRunPhase)))
		inProgress = false
		pushQueue = {}
		pullQueue = {}
		oneStackRequests = {}
		movedItems = {[BAG_BACKPACK] = {}, [BAG_BANK] = {}, [BAG_SUBSCRIBER_BANK] = {}}
		activeRuleRunPhase = nil
	elseif inProgress and #pushQueue == 0 and #pullQueue == 0 and activeTransferVerificationDebug == nil then
		-- No queued work and no async transfer can still be running.
		CustomRuleDebug("INTERACT BANK RECOVERY reason=inProgress=true but queues empty and no transfer verification; clearing stale busy flag")
		inProgress = false
		activeRuleRunPhase = nil
		hasAnyPullToDo = nil
		hasAnySpecialPullToDo = nil
		oneStackRequests = {}
		movedItems = {[BAG_BACKPACK] = {}, [BAG_BANK] = {}, [BAG_SUBSCRIBER_BANK] = {}}
	end
	if not inProgress then
		inProgress = true
		activeRuleRunPhase = "building"
		BMR.ProfileDebugBeginScan("personal-bank")
		CustomRuleDebug(string.format("INTERACT BANK START profile=%s preferredState=%s", tostring(actualProfile), tostring(db.profiles[actualProfile] and db.profiles[actualProfile].pvpPriorityState)))
		
		if not activeHouseStorageBagId then moveCurrencies() end
		dataSorted = sortByKeyAndPosition(BankManagerRules.data)
		oneStackRequests = {}
		-- If any rule uses the one-stack action, scan the bank even when no ordinary
		-- pull rule is active; a matching item may exist only in the bank.
		for _, ruleSettings in pairs(db.profiles[actualProfile].rules or {}) do
			if type(ruleSettings) == "table" and (ruleSettings.action == ACTION_KEEP_ONE_STACK or ruleSettings.action == ACTION_KEEP_ONE_STACK_BANK or ruleSettings.action == ACTION_PULL_ALL_STACKS) then
				hasAnyPullToDo = true
				break
			end
		end

		RunTransferProviders()
		BMR.ProfileDiagnostic("PERSONAL_BANK_AFTER_TRANSFER_PROVIDERS", string.format("push=%d pull=%d; %s", #pushQueue, #pullQueue, BMR.ProfileDebugRuleActionSummary()))
		ScriptDebug(string.format("Queues before normal BMR scan: push=%d pull=%d", #pushQueue, #pullQueue))
		
		-- Prepare items, check if they must be moved and queue them
		for slotIndex in pairs(SHARED_INVENTORY.bagCache[BAG_BACKPACK]) do
			if not movedItems[BAG_BACKPACK][slotIndex] then
				prepareItem(BAG_BACKPACK, slotIndex)
			else
				CustomRuleDebug(string.format("SCAN SKIP bag=INVENTAR slot=%s reason=movedItems flag is set", tostring(slotIndex)))
			end
		end
		--d(GetGameTimeMilliseconds() - startTimeInMs)
		
		if not activeHouseStorageBagId and db.profiles[actualProfile].rules["writsQuests"].specialEnabled then
			BuildWritsItems()
		end
		
		-- Prepare items, check if they must be moved and queue them.
		local shouldScanBanks = hasAnyPullToDo or hasAnySpecialPullToDo
		CustomRuleDebug(string.format("BANK SCAN GATE shouldScanBanks=%s hasAnyPullToDo=%s hasAnySpecialPullToDo=%s", tostring(not not shouldScanBanks), tostring(hasAnyPullToDo), tostring(hasAnySpecialPullToDo)))
		if shouldScanBanks then -- Has already been checked in the first loop
			for _, sourceBag in ipairs(GetCurrentStorageSourceBags()) do
				movedItems[sourceBag] = movedItems[sourceBag] or {}
				if activeHouseStorageBagId then
					-- Housing bags are not guaranteed to be present in LibSharedInventory's cache.
					for slotIndex = 0, (GetBagSize(sourceBag) or 0) - 1 do
						local link = GetItemLink(sourceBag, slotIndex)
						if link and link ~= "" then
							if not movedItems[sourceBag][slotIndex] then prepareItem(sourceBag, slotIndex)
							else CustomRuleDebug(string.format("SCAN SKIP bag=HOUSE STORAGE slot=%s reason=movedItems flag is set", tostring(slotIndex))) end
						end
					end
				else
					for slotIndex in pairs(SHARED_INVENTORY.bagCache[sourceBag] or {}) do
						if not movedItems[sourceBag][slotIndex] then prepareItem(sourceBag, slotIndex)
						else CustomRuleDebug(string.format("SCAN SKIP bag=%s slot=%s reason=movedItems flag is set", sourceBag == BAG_SUBSCRIBER_BANK and "ESO+ BANK" or "BANK", tostring(slotIndex))) end
					end
				end
			end
		else
			CustomRuleDebug("BANK SCAN SKIP reason=no pull/special-pull rule currently requires bank scanning")
		end
		--d(GetGameTimeMilliseconds() - startTimeInMs)

		BuildOneStackQueues()

		-- Reconcile PvP item state before moving: when the same item ID exists in
		-- both states across backpack/bank, move non-preferred backpack stacks out
		-- and preferred bank stacks in. Require both states to be observed for that
		-- ID; this avoids treating a missing/unreliable ESO condition value as proof.
		local preference = db.profiles[actualProfile].pvpPriorityState or "unused"
		local preferredUsed = preference == "used"
		local function getActivePvpRuleName(itemData)
			local profileRules = db.profiles[actualProfile].rules or {}
			local customName = "customItem_" .. tostring(itemData.itemId)
			local custom = profileRules[customName]
			if custom and custom.action and custom.action ~= ACTION_NOTSET then return customName end
			local exactName = "pvpItem_" .. tostring(itemData.itemId)
			local exact = profileRules[exactName]
			if exact and exact.action and exact.action ~= ACTION_NOTSET then return exactName end
			local allianceName = itemData.alliance and ("pvpAlliance_" .. itemData.alliance) or nil
			local alliance = allianceName and profileRules[allianceName]
			if alliance and alliance.action and alliance.action ~= ACTION_NOTSET then return allianceName end
			local master = profileRules.MiscPvpSiege
			if master and master.action and master.action ~= ACTION_NOTSET then return "MiscPvpSiege" end
			return nil
		end
		-- Items governed by a one-stack rule must be controlled exclusively by
		-- BuildOneStackQueues. Rebuilding PvP state queues for these IDs would
		-- re-add every matching bank stack (notably Brand Oil, whose energy values
		-- can make the same item ID appear both "used" and "unused") and undo the
		-- one-stack/energy-priority selection.
		local oneStackPvpItemIds = {}
		for itemLink in pairs(oneStackRequests) do
			local itemId = GetItemLinkItemId(itemLink)
			if itemId and BMR_PVP_ITEM_CATALOG[itemId] then
				oneStackPvpItemIds[itemId] = true
			end
		end
		for itemId in pairs(oneStackPvpItemIds) do
			CustomRuleDebug(string.format("PVP-STATE RECONCILE SKIP itemId=%s reason=one-stack rule owns item selection", tostring(itemId)))
		end

		local statesById = {}
		local function collectPvpStates(bagId)
			local bagSize = GetBagSize(bagId) or 0
			for slotIndex = 0, bagSize - 1 do
				local link = GetItemLink(bagId, slotIndex)
				local itemId = link and link ~= "" and GetItemLinkItemId(link)
				local catalog = itemId and BMR_PVP_ITEM_CATALOG[itemId]
				local activeRuleName = catalog and getActivePvpRuleName({itemId = itemId, alliance = catalog.alliance})
				if catalog and activeRuleName and not oneStackPvpItemIds[itemId] then
					local used, stateKnown, energy = GetPvpUsedState(itemId, link, bagId, slotIndex)
					if stateKnown then
						statesById[itemId] = statesById[itemId] or {used = false, unused = false, slots = {}, ruleName = activeRuleName}
						local state = statesById[itemId]
						state[used and "used" or "unused"] = true
						local count = GetSlotStackSize(bagId, slotIndex)
						table.insert(state.slots, {bagId = bagId, slotId = slotIndex, itemLink = link, used = used, ruleName = activeRuleName, energy = energy, count = count or 1})
					end
				end
			end
		end
		collectPvpStates(BAG_BACKPACK)
		for _, sourceBag in ipairs(GetCurrentStorageSourceBags()) do collectPvpStates(sourceBag) end

		local function removeQueuedPvpItem(itemId)
			for i = #pushQueue, 1, -1 do
				if GetItemLinkItemId(pushQueue[i].itemLink) == itemId then table.remove(pushQueue, i) end
			end
			for i = #pullQueue, 1, -1 do
				if GetItemLinkItemId(pullQueue[i].itemLink) == itemId then table.remove(pullQueue, i) end
			end
		end

		local function sortPvpSlotsByPreference(slots)
			table.sort(slots, function(a, b)
				if a.energy ~= nil and b.energy ~= nil and a.energy ~= b.energy then
					return preferredUsed and a.energy < b.energy or (not preferredUsed and a.energy > b.energy)
				elseif a.energy ~= nil and b.energy == nil then
					return true
				elseif a.energy == nil and b.energy ~= nil then
					return false
				elseif a.used ~= b.used and a.used ~= nil and b.used ~= nil then
					return a.used == preferredUsed
				end
				-- Keep already-correct inventory stacks on ties to avoid needless movement.
				local aBackpack, bBackpack = a.bagId == BAG_BACKPACK, b.bagId == BAG_BACKPACK
				if aBackpack ~= bBackpack then return aBackpack end
				if a.bagId ~= b.bagId then return a.bagId < b.bagId end
				return a.slotId < b.slotId
			end)
		end

		local profileRules = db.profiles[actualProfile].rules or {}
		for itemId, state in pairs(statesById) do
			if #state.slots > 0 then
				local ruleName = getActivePvpRuleName({itemId = itemId, alliance = BMR_PVP_ITEM_CATALOG[itemId].alliance})
				local rule = ruleName and profileRules[ruleName]
				local action = rule and rule.action
				-- One-stack actions are exclusively handled by BuildOneStackQueues above.
				if action == ACTION_PULL then
					-- When the configured destination is the backpack, the category's
					-- existing stack settings determine how many energy-ranked variants
					-- may be kept there. Rebuild both directions for this item ID so a
					-- rule change works without first emptying the backpack.
					local maxPreferredStacks = 1
					if rule.onlyIfNotFullStack == false then
						maxPreferredStacks = math.max(1, math.floor(tonumber(rule.onlyStacks) or 1))
					end
					removeQueuedPvpItem(itemId)
					local ranked = {}
					for _, slot in ipairs(state.slots) do ranked[#ranked + 1] = slot end
					sortPvpSlotsByPreference(ranked)
					local selectedSlots = {}
					for index = 1, math.min(maxPreferredStacks, #ranked) do
						local slot = ranked[index]
						selectedSlots[tostring(slot.bagId) .. ":" .. tostring(slot.slotId)] = true
					end
					for _, slot in ipairs(state.slots) do
						local key = tostring(slot.bagId) .. ":" .. tostring(slot.slotId)
						if slot.bagId == BAG_BACKPACK and not selectedSlots[key] then
							CustomRuleDebug(string.format("PVP-STATE MOVE OUT itemId=%s bag=%s slot=%s energy=%s reason=not among top %d preferred inventory stacks", tostring(itemId), tostring(slot.bagId), tostring(slot.slotId), tostring(slot.energy), maxPreferredStacks))
							table.insert(pushQueue, {ruleName = ruleName, bagId = slot.bagId, slotId = slot.slotId, itemLink = slot.itemLink, itemIcon = GetItemLinkInfo(slot.itemLink), custom = true, maxQty = slot.count})
						elseif IsCurrentStorageSourceBag(slot.bagId) and selectedSlots[key] then
							CustomRuleDebug(string.format("PVP-STATE MOVE IN itemId=%s bag=%s slot=%s energy=%s reason=top %d preferred inventory stacks", tostring(itemId), tostring(slot.bagId), tostring(slot.slotId), tostring(slot.energy), maxPreferredStacks))
							table.insert(pullQueue, {ruleName = ruleName, bagId = slot.bagId, slotId = slot.slotId, itemLink = slot.itemLink, itemIcon = GetItemLinkInfo(slot.itemLink), custom = true, maxQty = slot.count})
						end
					end
				elseif action == ACTION_PUSH or action == ACTION_PUSH_GBANK or action == ACTION_PUSH_BOTH then
					-- The preference describes the backpack, not the bank. For an action
					-- directed away from the backpack, do not send preferred-state stacks
					-- out merely because the dropdown points at a bank. The regular queue
					-- still applies the chosen category stack limits to non-preferred items.
					for index = #pushQueue, 1, -1 do
						local move = pushQueue[index]
						if GetItemLinkItemId(move.itemLink) == itemId and move.bagId == BAG_BACKPACK then
							local used, known = GetPvpUsedState(itemId, GetItemLink(move.bagId, move.slotId) or move.itemLink, move.bagId, move.slotId)
							if known and used == preferredUsed then
								CustomRuleDebug(string.format("PVP-STATE KEEP INVENTORY itemId=%s slot=%s energy=%s reason=preferred state stays in inventory", tostring(itemId), tostring(move.slotId), tostring(GetSiegeRemainingEnergy(move.itemLink))))
								table.remove(pushQueue, index)
							end
						end
					end
				end
			end
		end

		-- Prefer desired-state PvP stacks earlier in queues where their state can be read.
		local function ApplyPvpMovePriority(queue)
			local decorated = {}
			for index, moveData in ipairs(queue) do
				local rank = 1
				local energyRank = nil
				local itemId = moveData.itemLink and GetItemLinkItemId(moveData.itemLink)
				if itemId and BMR_PVP_ITEM_CATALOG[itemId] then
					local energy = GetSiegeRemainingEnergy(moveData.itemLink or GetItemLink(moveData.bagId, moveData.slotId))
					if energy ~= nil then
						energyRank = preferredUsed and energy or -energy
						if queue == pushQueue then energyRank = -energyRank end
					end
					local isUsed, stateKnown = GetPvpUsedState(itemId, moveData.itemLink or GetItemLink(moveData.bagId, moveData.slotId), moveData.bagId, moveData.slotId)
					if stateKnown then
						local matchesPreference = isUsed == preferredUsed
						if queue == pushQueue then rank = matchesPreference and 2 or 0
						else rank = matchesPreference and 0 or 2 end
					end
				end
				table.insert(decorated, {data = moveData, rank = rank, energyRank = energyRank, index = index})
			end
			table.sort(decorated, function(a, b) if a.rank ~= b.rank then return a.rank < b.rank end if a.energyRank ~= nil and b.energyRank ~= nil and a.energyRank ~= b.energyRank then return a.energyRank < b.energyRank end return a.index < b.index end)
			for index, entry in ipairs(decorated) do queue[index] = entry.data end
		end
		ApplyPvpMovePriority(pushQueue)
		ApplyPvpMovePriority(pullQueue)

		-- items have been queued
		BMR.ProfileDiagnostic("PERSONAL_BANK_QUEUES_READY", string.format("push=%d pull=%d hasAnyPullToDo=%s hasAnySpecialPullToDo=%s; %s; %s", #pushQueue, #pullQueue, tostring(hasAnyPullToDo), tostring(hasAnySpecialPullToDo), BMR.ProfileDebugScanSummary(), BMR.ProfileDebugRuleActionSummary()))
		CustomRuleDebug(string.format("INTERACT BANK QUEUES READY push=%d pull=%d hasAnyPullToDo=%s hasAnySpecialPullToDo=%s", #pushQueue, #pullQueue, tostring(hasAnyPullToDo), tostring(hasAnySpecialPullToDo)))
		ScriptDebug(string.format("Final queues before moveItems: push=%d pull=%d", #pushQueue, #pullQueue))
		if #pushQueue > 0 or #pullQueue > 0 then
			ScriptDebug("Calling moveItems()")
			CustomRuleDebug("INTERACT BANK DISPATCH action=moveItems; phase building -> moving")
			activeRuleRunPhase = "moving"
			moveItems() -- zo_CallLater inside, nothing behind this line should be run, but inside it.
		else
			BMR.ProfileDiagnostic("PERSONAL_BANK_NO_QUEUES", BMR.ProfileDebugScanSummary() .. "; " .. BMR.ProfileDebugRuleActionSummary() .. "; " .. BMR.ProfileDebugBagCacheSummary(BAG_BACKPACK))
			-- The old code left inProgress=true when a scan produced no queued moves,
			-- silently blocking subsequent profile-icon clicks until the bank was closed.
			local continueHousingRescan = activeHouseStorageBagId and isBanking and not checkingGBank and housingAutoRescanPasses > 0
			CustomRuleDebug("INTERACT BANK FINISH reason=no transfers queued; reset inProgress, queues, and movedItems flags")
			inProgress = false
			activeRuleRunPhase = nil
			hasAnyPullToDo = nil
			hasAnySpecialPullToDo = nil
			pushQueue = {}
			pullQueue = {}
			oneStackRequests = {}
			movedItems = {[BAG_BACKPACK] = {}, [BAG_BANK] = {}, [BAG_SUBSCRIBER_BANK] = {}}
			if continueHousingRescan then
				ScheduleHousingAutoRescan(0, "empty scan; retry after inventory/cache settles", 1000)
			else
				housingAutoRescanPasses = 0
			end
		end
	else
		CustomRuleDebug(string.format("INTERACT BANK BLOCKED reason=inProgress=true phase=%s activeQueues push=%d pull=%d pendingVerification=%s expectedTraceCount=%d; no second queue dispatched", tostring(activeRuleRunPhase), #pushQueue, #pullQueue, tostring(activeTransferVerificationDebug ~= nil), #pvpExpectedMoveTraces))
	end
	
end

-- Display UI with arrows if needed
local function displayUI(multipleProfiles)
	BMR.ProfileDiagnostic("DISPLAY_UI_BEGIN", string.format("multipleProfiles=%s banking=%s %s", tostring(multipleProfiles), tostring(isBanking), BMR.ProfileDebugSnapshot()))
	local currentProfile = db and db.profiles and db.profiles[actualProfile]
	if type(currentProfile) ~= "table" then
		BMR.ProfileDiagnostic("DISPLAY_UI_ABORT", "active profile table is missing; " .. BMR.ProfileDebugSnapshot())
		return
	end
	local ruleName = currentProfile.name
	if ruleName == "" then ruleName = zo_strformat(BMR_PROFILE, actualProfile) end

	local controllerMode = BMR.Console and type(BMR.Console.IsAvailable) == "function"
		and (BMR.Console.IsAvailable() == true or (type(BMR.Console.IsBankSceneOpen) == "function" and BMR.Console.IsBankSceneOpen() == true))
	if controllerMode and type(BMR.Console.GetDefinedProfiles) == "function" then
		local definedProfiles = BMR.Console.GetDefinedProfiles()
		local profilePosition = type(BMR.Console.GetProfilePosition) == "function" and BMR.Console.GetProfilePosition(actualProfile) or actualProfile
		ruleName = string.format("%s  [%d/%d]", tostring(ruleName), tonumber(profilePosition) or actualProfile, #definedProfiles)
	end

	local beforeControl = BankManager and BankManager:GetNamedChild("Before")
	local afterControl = BankManager and BankManager:GetNamedChild("After")
	if BankManager and type(BankManager.SetDimensions) == "function" then
		BankManager:SetDimensions(controllerMode and 310 or 230, controllerMode and 220 or 200)
	end
	local executeControl = BankManager and BankManager:GetNamedChild("Execute")
	if executeControl and type(executeControl.SetDimensions) == "function" then
		executeControl:SetDimensions(controllerMode and 140 or 120, controllerMode and 140 or 120)
	end
	if beforeControl and type(beforeControl.SetHidden) == "function" then
		beforeControl:SetHidden(controllerMode or not multipleProfiles)
	else
		BMR.ProfileDiagnostic("PROFILE_SWITCH_CONTROL_MISSING", "control=Before; " .. BMR.ProfileDebugSnapshot())
	end
	if afterControl and type(afterControl.SetHidden) == "function" then
		afterControl:SetHidden(controllerMode or not multipleProfiles)
	else
		BMR.ProfileDiagnostic("PROFILE_SWITCH_CONTROL_MISSING", "control=After; " .. BMR.ProfileDebugSnapshot())
	end

	local title = BankManager and BankManager:GetNamedChild("Title")
	if title and type(title.SetText) == "function" then
		title:SetText(controllerMode and GetString(BMR_CONSOLE_WIDGET_TITLE) or "BankManagerRevived")
		if type(title.SetDimensions) == "function" then title:SetDimensions(controllerMode and 285 or 185, 28) end
	end
	local label = BankManager and BankManager:GetNamedChild("RuleName")
	if not label then BMR.ProfileDiagnostic("PROFILE_SWITCH_CONTROL_MISSING", "control=RuleName; " .. BMR.ProfileDebugSnapshot()) end
	if label and type(label.SetText) == "function" then
		if type(label.SetDimensions) == "function" then label:SetDimensions(controllerMode and 285 or 185, controllerMode and 34 or 28) end
		label:SetText(ruleName)
	end
	if BankManager and type(BankManager.SetHidden) == "function" then BankManager:SetHidden(false) end
	if controllerMode and BMR.Console and type(BMR.Console.RegisterSceneKeybinds) == "function" then
		BMR.Console.RegisterSceneKeybinds()
	end
	BMR.ProfileDiagnostic("DISPLAY_UI_END", string.format("multipleProfiles=%s controllerMode=%s ruleName=%s Before=%s After=%s", tostring(multipleProfiles), tostring(controllerMode), tostring(ruleName), BMR.ProfileDebugControlState("Before"), BMR.ProfileDebugControlState("After")))
end

-- Move to previous/next rule
local function nextRule(step)
	BMR.ProfileDiagnostic("PROFILE_ARROW_CLICK", string.format("step=%s before=%s", tostring(step), BMR.ProfileDebugSnapshot()))
	local changed
	for i=actualProfile+step, db.profileCount, step do
		local candidate = db.profiles and db.profiles[i]
		if type(candidate) == "table" and candidate.defined then
			changed = true
			actualProfile = i
			break
		end
	end
	
	if not changed then
		actualProfile = 1
	end
	
	db.actualProfile[GetUnitName("player")] = actualProfile
	
	-- Sync LAM
	CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)
		
	local ruleName = db.profiles[actualProfile].name
	
	if ruleName == "" then
		ruleName = zo_strformat(BMR_PROFILE, actualProfile)
	end
	
	local label = BankManager and BankManager:GetNamedChild("RuleName")
	if label and type(label.SetText) == "function" then label:SetText(ruleName) end
	BMR.ProfileDiagnostic("PROFILE_ARROW_RESULT", string.format("step=%s changed=%s after=%s", tostring(step), tostring(changed), BMR.ProfileDebugSnapshot()))

end


-- Controller-first console preview.
-- Important: scene hooks are installed independently of the floating BankManager control.
-- In ForceConsoleFlow, a top-level mouse-oriented control may not be visible; keybinds must
-- therefore be registered when the gamepad bank scenes appear, not only from displayUI().
-- LibConsoleDialogs allocates available controller keys on demand. A native KEYBIND_STRIP
-- fallback is used on PC when the console-only library is not loaded.
BMR.Console.bankSceneNames = { "gamepad_banking", "gamepad_guild_bank" }
BMR.Console.sceneHooks = BMR.Console.sceneHooks or {}

BMR.Console.GetScene = function(sceneName)
	if not SCENE_MANAGER or type(SCENE_MANAGER.GetScene) ~= "function" then return nil end
	local ok, scene = pcall(function() return SCENE_MANAGER:GetScene(sceneName) end)
	return ok and scene or nil
end

BMR.Console.IsSceneShowing = function(sceneName)
	local scene = BMR.Console.GetScene(sceneName)
	if not scene then return false end
	if type(scene.IsShowing) == "function" then
		local ok, result = pcall(function() return scene:IsShowing() end)
		if ok and result == true then return true end
	end
	local ok, state = pcall(function() return scene:GetState() end)
	return ok and (state == SCENE_SHOWING or state == SCENE_SHOWN) or false
end

BMR.Console.GetCurrentSceneName = function()
	if SCENE_MANAGER and type(SCENE_MANAGER.GetCurrentScene) == "function" then
		local ok, scene = pcall(function() return SCENE_MANAGER:GetCurrentScene() end)
		if ok and scene and type(scene.GetName) == "function" then
			local nameOk, name = pcall(function() return scene:GetName() end)
			if nameOk then return tostring(name or "") end
		end
	end
	return ""
end

-- Do not equate the platform with the active UI flow: ForceConsoleFlow.2 can
-- activate the controller UI on PC, where IsKeyboardUISupported() may differ
-- from the platform-specific console result.
BMR.Console.IsControllerFlowActive = function()
	if type(IsKeyboardUISupported) == "function" then
		local ok, value = pcall(IsKeyboardUISupported)
		if ok and value == false then return true end
	end
	if type(IsConsoleUI) == "function" then
		local ok, value = pcall(IsConsoleUI)
		if ok and value == true then return true end
	end
	if type(GetCVar) == "function" then
		local ok, value = pcall(GetCVar, "ForceConsoleFlow.2")
		if ok and (value == "1" or value == 1 or value == true) then return true end
	end
	if type(IsInGamepadPreferredMode) == "function" then
		local ok, value = pcall(IsInGamepadPreferredMode)
		if ok and value == true then return true end
	end
	return false
end

BMR.Console.IsCurrentGamepadBankScene = function()
	local name = string.lower(BMR.Console.GetCurrentSceneName())
	if name == "" or not string.find(name, "bank", 1, true) then return false end
	-- The active scene may be named simply "banking" under Forced Console Flow.
	return string.find(name, "gamepad", 1, true) ~= nil or BMR.Console.IsControllerFlowActive()
end

BMR.Console.IsBankSceneOpen = function()
	if BMR.Console.IsSceneShowing("gamepad_banking") or BMR.Console.IsSceneShowing("gamepad_guild_bank") then return true end
	if BMR.Console.IsCurrentGamepadBankScene() then return true end
	-- ForceConsoleFlow can leave the root scene named "hudui" even while a bank
	-- interaction is active. The banking API is a useful additional signal.
	if type(GetBankingInteractionType) == "function" then
		local ok, interactionType = pcall(GetBankingInteractionType)
		local noneType = _G.BANKING_TYPE_NONE
		if ok and interactionType ~= nil and interactionType ~= 0 and (noneType == nil or interactionType ~= noneType) then
			return true
		end
	end
	-- EVENT_OPEN_BANK and guild-bank selection are authoritative even when the
	-- game's current scene object is a parent/root scene with a non-bank name.
	return BMR.Console.IsControllerFlowActive() and (isBanking == true or checkingGBank == true or currentGBank ~= nil)
end

BMR.Console.IsStableKeybindSceneName = function(sceneName)
	local name = string.lower(tostring(sceneName or ""))
	-- Known bank scenes plus the stable HUD root used by Forced Console Flow.
	-- Transient overflow/dialog scenes must not get another set of keybinds on each open.
	return name == "hudui" or name == "banking" or name == "guild_bank"
		or name == "gamepad_banking" or name == "gamepad_guild_bank"
end

BMR.Console.GetEffectiveBankSceneNames = function()
	local names, seen = {}, {}
	for _, name in ipairs(BMR.Console.bankSceneNames or {}) do
		if not seen[name] then names[#names + 1] = name; seen[name] = true end
	end
	local currentName = BMR.Console.GetCurrentSceneName()
	if currentName ~= "" and BMR.Console.IsStableKeybindSceneName(currentName)
		and BMR.Console.IsControllerFlowActive()
		and (BMR.Console.IsCurrentGamepadBankScene() or BMR.Console.IsBankSceneOpen() or isBanking == true or checkingGBank == true or currentGBank ~= nil)
		and not seen[currentName] then
		names[#names + 1] = currentName
	end
	return names
end

BMR.Console.IsModeActive = function()
	-- Use ESO's own keyboard-UI capability signal too. On ForceConsoleFlow the
	-- current scene and CVar can disagree briefly while the gamepad UI initializes.
	if type(IsKeyboardUISupported) == "function" then
		local ok, keyboardSupported = pcall(IsKeyboardUISupported)
		if ok and keyboardSupported == false then return true end
	end
	if type(IsConsoleUI) == "function" then
		local ok, result = pcall(IsConsoleUI)
		if ok and result == true then return true end
	end
	if type(GetCVar) == "function" then
		local ok, value = pcall(GetCVar, "ForceConsoleFlow.2")
		if ok and (value == "1" or value == 1 or value == true) then return true end
	end
	-- Some PC builds do not expose the force-flow CVar consistently through GetCVar.
	-- The actual bank scene is a reliable fallback once the player opens a gamepad bank.
	if BMR.Console.IsBankSceneOpen() then return true end
	if type(IsInGamepadPreferredMode) == "function" then
		local ok, result = pcall(IsInGamepadPreferredMode)
		if ok and result == true then return true end
	end
	return false
end

BMR.Console.IsAvailable = function()
	return BMR.Console.IsModeActive() == true
end

BMR.Console.HasDialogSupport = function()
	return type(LibConsoleDialogs) == "table"
		and type(LibConsoleDialogs.RegisterKeybind) == "function"
		and type(LibConsoleDialogs.Create) == "function"
		and type(LibHarvensAddonSettings) == "table"
end

BMR.Console.GetDefinedProfiles = function()
	local result = {}
	if type(db) ~= "table" or type(db.profiles) ~= "table" then return result end
	local limit = math.max(1, tonumber(db.profileCount) or 1)
	for index = 1, limit do
		local profile = db.profiles[index]
		if type(profile) == "table" and profile.defined == true then result[#result + 1] = index end
	end
	return result
end

BMR.Console.GetProfilePosition = function(profileIndex)
	local list = BMR.Console.GetDefinedProfiles()
	for position, index in ipairs(list) do if index == profileIndex then return position end end
	return 1
end

BMR.Console.GetProfileLabel = function(profileIndex)
	local profile = db and db.profiles and db.profiles[profileIndex]
	if type(profile) ~= "table" or profile.defined ~= true then return tostring(profileIndex) end
	local name = tostring(profile.name or "")
	if name == "" then name = zo_strformat(BMR_PROFILE, profileIndex) end
	return string.format("%d - %s", profileIndex, name)
end

-- Recover only the stale state that the normal bank scanner itself already treats as
-- abandoned: no queued moves, no pending verification, and no active mover phase.
-- This is needed because a console API can throw during queue construction before the
-- normal cleanup is reached. Never clear a live move loop or an outstanding verification.
BMR.Console.RecoverStaleRunState = function(source)
	if not inProgress then return false end
	local pushEmpty = type(pushQueue) == "table" and #pushQueue == 0
	local pullEmpty = type(pullQueue) == "table" and #pullQueue == 0
	if pushEmpty and pullEmpty and activeTransferVerificationDebug == nil and activeRuleRunPhase ~= "moving" then
		BMR.ProfileDiagnostic("CONSOLE_STALE_RUN_RECOVERED", "source=" .. tostring(source) .. "; phase=" .. tostring(activeRuleRunPhase))
		inProgress = false
		activeRuleRunPhase = nil
		hasAnyPullToDo = nil
		hasAnySpecialPullToDo = nil
		pushQueue, pullQueue, oneStackRequests = {}, {}, {}
		profileIconRerunRequested = false
		return true
	end
	return false
end

-- Use the strongest state exposed by the client to restore the bank flags if the
-- EVENT_OPEN_BANK callback was missed by the Forced Console Flow transition.
BMR.Console.SyncBankRuntimeState = function(source)
	if isBanking or checkingGBank then return true end
	local interactionType
	if type(GetBankingInteractionType) == "function" then
		local ok, value = pcall(GetBankingInteractionType)
		if ok then interactionType = value end
	end
	local sceneName = string.lower(tostring(BMR.Console.GetCurrentSceneName() or ""))
	if string.find(sceneName, "guild", 1, true) then
		if currentGBank ~= nil then checkingGBank = true; return true end
		return false -- do not guess a guild-bank target when its selection event was missed
	end
	local personalBankType = _G.BANKING_TYPE_BANK or _G.BANKING_TYPE_PERSONAL_BANK
	if interactionType ~= nil and personalBankType ~= nil and interactionType == personalBankType then
		isBanking = true
		BMR.ProfileDiagnostic("CONSOLE_BANK_STATE_RECOVERED", "source=" .. tostring(source) .. "; interactionType=" .. tostring(interactionType) .. "; inferred=personal")
		return true
	end
	-- If the current scene itself is explicitly a non-guild bank scene, that is also
	-- sufficient to establish the target. Do not infer a personal bank from an unknown
	-- interaction type while the root scene is only "hudui".
	if string.find(sceneName, "bank", 1, true) and not string.find(sceneName, "guild", 1, true)
		and BMR.Console.IsCurrentGamepadBankScene() then
		isBanking = true
		BMR.ProfileDiagnostic("CONSOLE_BANK_STATE_RECOVERED", "source=" .. tostring(source) .. "; scene=" .. sceneName .. "; inferred=personal")
		return true
	end
	return false
end

BMR.Console.SelectProfile = function(profileIndex, runImmediately)
	BMR.Console.RecoverStaleRunState("select-profile")
	if inProgress then
		BMR.ProfileDiagnostic("CONSOLE_PROFILE_SELECT_BLOCKED", "transfer still active; phase=" .. tostring(activeRuleRunPhase) .. "; push=" .. tostring(#pushQueue) .. "; pull=" .. tostring(#pullQueue))
		BMR.ProfileDiagnosticChat("BMR: Profilwechsel blockiert, solange ein echter Gegenstandstransfer läuft. Bitte den Transfer abschließen lassen.")
		return false
	end
	profileIndex = tonumber(profileIndex)
	local profile = profileIndex and db and db.profiles and db.profiles[profileIndex]
	if type(profile) ~= "table" or profile.defined ~= true then return false end
	actualProfile = profileIndex
	db.actualProfile[GetUnitName("player")] = profileIndex
	if CALLBACK_MANAGER and type(CALLBACK_MANAGER.FireCallbacks) == "function" and panel ~= nil then
		CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)
	end
	-- Always refresh the floating label when the UI is in controller mode. The
	-- bank scene can be live even when EVENT_OPEN_BANK did not set the legacy flags.
	if BMR.Console.IsAvailable() or BMR.Console.IsBankSceneOpen() or isBanking or checkingGBank or currentGBank ~= nil then
		local shown, showError = pcall(displayUI, #BMR.Console.GetDefinedProfiles() > 1)
		if not shown then BMR.ProfileDiagnostic("CONSOLE_PROFILE_DISPLAY_FAILED", tostring(showError)) end
	end
	BMR._consoleLastAction = "profile-selected:" .. tostring(profileIndex)
	BMR.ProfileDiagnostic("CONSOLE_PROFILE_SELECTED", "profile=" .. tostring(profileIndex) .. "; runImmediately=" .. tostring(runImmediately == true) .. "; " .. BMR.ProfileDebugSnapshot())
	if runImmediately == true then BMR.Console.RunSelectedProfile("profile-select") end
	return true
end

BMR.Console.CycleProfile = function(step)
	BMR.Console.RecoverStaleRunState("cycle-profile")
	if inProgress then
		BMR._consoleLastAction = "cycle-blocked-live-transfer"
		BMR.ProfileDiagnostic("CONSOLE_PROFILE_CYCLE_BLOCKED", "live transfer phase=" .. tostring(activeRuleRunPhase))
		return false
	end
	local list = BMR.Console.GetDefinedProfiles()
	if #list <= 1 then
		BMR._consoleLastAction = "cycle-no-alternate-profile"
		BMR.ProfileDiagnostic("CONSOLE_PROFILE_CYCLE_NO_ALTERNATE", "defined=" .. tostring(#list))
		BMR.ProfileDiagnosticChat("BMR: Es ist nur " .. tostring(#list) .. " definiertes Profil vorhanden. Weitere Profile müssen in den Einstellungen definiert werden.")
		return false
	end
	local position = BMR.Console.GetProfilePosition(actualProfile)
	local direction = (tonumber(step) or 1) < 0 and -1 or 1
	position = ((position - 1 + direction) % #list) + 1
	BMR._consoleLastAction = "cycle-profile:" .. tostring(list[position])
	BMR.Console.SelectProfile(list[position], false)
	return true
end

BMR.Console.BuildProfileItems = function()
	local items = {}
	for _, index in ipairs(BMR.Console.GetDefinedProfiles()) do
		items[#items + 1] = { name = BMR.Console.GetProfileLabel(index), data = index }
	end
	return items
end

BMR.Console.OpenProfileDialog = function()
	if not BMR.Console.IsAvailable() or type(LibHarvensAddonSettings) ~= "table" or type(LibConsoleDialogs) ~= "table" or type(LibConsoleDialogs.Create) ~= "function" then
		BMR.ProfileDiagnosticChat("Controller-Profilmenü nicht verfügbar: LibConsoleDialogs/LibHarvensAddonSettings fehlt.")
		return
	end
	local items = BMR.Console.BuildProfileItems()
	if #items == 0 then BMR.ProfileDiagnosticChat(GetString(BMR_CONSOLE_NO_PROFILES)); return end
	if not BMR.Console.profileDialog then
		BMR.Console.profileDialog = LibConsoleDialogs:Create(GetString(BMR_CONSOLE_PROFILE_DIALOG_TITLE))
		BMR.Console.profileChoiceSetting = {
			type = LibHarvensAddonSettings.ST_DROPDOWN,
			label = GetString(BMR_CONSOLE_PROFILE_SELECT_LABEL),
			tooltip = GetString(BMR_CONSOLE_CHOOSE_PROFILE_TOOLTIP),
			items = items,
			getFunction = function() return BMR.Console.GetProfileLabel(actualProfile) end,
			setFunction = function(control, selectedName, item)
				local selectedIndex = type(item) == "table" and tonumber(item.data) or nil
				-- Some console dropdown implementations pass only the selected text.
				if not selectedIndex and selectedName ~= nil then
					for _, candidate in ipairs(BMR.Console.GetDefinedProfiles()) do
						if BMR.Console.GetProfileLabel(candidate) == tostring(selectedName) then selectedIndex = candidate; break end
					end
				end
				BMR._consoleLastAction = "profile-dropdown:" .. tostring(selectedIndex or selectedName or "nil")
				BMR.ProfileDiagnostic("CONSOLE_PROFILE_DROPDOWN_SELECTED", "selectedName=" .. tostring(selectedName) .. "; item=" .. tostring(type(item) == "table" and item.data or nil) .. "; resolved=" .. tostring(selectedIndex))
				if selectedIndex then BMR.Console.SelectProfile(selectedIndex, false)
				else BMR.ProfileDiagnosticChat("BMR: Profil-Auswahl lieferte keinen gültigen Eintrag; bitte /bmr/consoledebug ausführen.") end
			end,
		}
		BMR.Console.profileDialog:AddSetting(BMR.Console.profileChoiceSetting)
		BMR.Console.profileDialog:AddSetting({
			type = LibHarvensAddonSettings.ST_BUTTON,
			label = GetString(BMR_CONSOLE_RUN_PROFILE),
			tooltip = GetString(BMR_CONSOLE_RUN_PROFILE_TOOLTIP),
			buttonText = GetString(BMR_CONSOLE_RUN_PROFILE),
			clickHandler = function()
				BMR._consoleLastAction = "profile-dialog-run-pressed"
				BMR.ProfileDiagnostic("CONSOLE_PROFILE_DIALOG_RUN_PRESSED", BMR.ProfileDebugSnapshot())
				if LibConsoleDialogs and type(LibConsoleDialogs.Close) == "function" then pcall(function() LibConsoleDialogs:Close() end) end
				BMR.Console.RunSelectedProfile("profile-dialog-button")
			end,
		})
	else
		BMR.Console.profileChoiceSetting.items = items
	end
	BMR.Console.profileDialog:Show()
end

-- Register on the actual gamepad bank scenes, not whichever scene happens to be
-- current while EVENT_OPEN_BANK / guild-bank readiness is being processed.
BMR.Console.RunSelectedProfile = function(source)
	BMR._consoleLastAction = "run-request:" .. tostring(source or "keybind")
	BMR.ProfileDiagnostic("CONSOLE_RUN_REQUEST", "source=" .. tostring(source or "keybind") .. "; " .. BMR.ProfileDebugSnapshot())
	BMR.Console.RecoverStaleRunState("run-selected-profile")
	local bankReady = BMR.Console.SyncBankRuntimeState(source or "run-selected-profile")
	if inProgress then
		BMR._consoleLastAction = "run-blocked-live-transfer"
		BMR.ProfileDiagnostic("CONSOLE_RUN_BLOCKED_BUSY", "phase=" .. tostring(activeRuleRunPhase) .. "; push=" .. tostring(#pushQueue) .. "; pull=" .. tostring(#pullQueue) .. "; verification=" .. tostring(activeTransferVerificationDebug ~= nil))
		BMR.ProfileDiagnosticChat("BMR: Ausführen blockiert, weil noch eine Bankbewegung läuft. Bitte den laufenden Transfer abschließen lassen.")
		return false
	end
	if not bankReady then
		local interaction = "n/a"
		if type(GetBankingInteractionType) == "function" then local ok, value = pcall(GetBankingInteractionType); if ok then interaction = tostring(value) end end
		BMR._consoleLastAction = "run-blocked-bank-state-undetected"
		BMR.ProfileDiagnostic("CONSOLE_RUN_BLOCKED_NO_BANK_STATE", "source=" .. tostring(source) .. "; interactionType=" .. interaction .. "; scene=" .. tostring(BMR.Console.GetCurrentSceneName()))
		BMR.ProfileDiagnosticChat("BMR: Bankkontext nicht sicher erkannt; Ausführen abgebrochen, um keine Gegenstände in der falschen Bank zu bewegen. /bmr/consoledebug zeigt den Zustand.")
		return false
	end
	local ok, err = pcall(BankManagerRevived_executeRule)
	if not ok then
		BMR._consoleLastAction = "run-error"
		BMR.ProfileDiagnostic("CONSOLE_RUN_FAILED", tostring(err))
		BMR.ProfileDiagnosticChat("BMR: Profil konnte nicht ausgeführt werden: " .. tostring(err):gsub("[\r\n]+", " "):sub(1, 150))
		return false
	end
	BMR._consoleLastAction = "run-dispatched"
	return true
end

-- Profile navigation uses LibConsoleDialogs so the library can allocate the D-pad-right
-- overflow key without replacing controls already owned by the bank UI.
-- Important: register against the actual active gamepad bank scene, never the hudui root.
BMR.Console.RemoveNativeProfileKeybindGroup = function(source)
	-- Cleanup for installations upgrading from 15.16.36, which temporarily used a
	-- native KEYBIND_STRIP group with fixed keys that may conflict with ESO bank actions.
	local group = BMR.Console.nativeKeybindGroup
	if group and KEYBIND_STRIP and type(KEYBIND_STRIP.RemoveKeybindButtonGroup) == "function" then
		local present = BMR.Console.nativeKeybindGroupAdded == true
		if type(KEYBIND_STRIP.HasKeybindButtonGroup) == "function" then
			local ok, value = pcall(KEYBIND_STRIP.HasKeybindButtonGroup, KEYBIND_STRIP, group)
			if ok then present = value == true end
		end
		if present then pcall(KEYBIND_STRIP.RemoveKeybindButtonGroup, KEYBIND_STRIP, group) end
	end
	BMR.Console.nativeKeybindGroupAdded = false
end

BMR.Console.GetProfileKeybindTargetScene = function()
	local currentName = string.lower(tostring(BMR.Console.GetCurrentSceneName() or ""))
	local guildNames = {"gamepad_guild_bank", "guild_bank"}
	local personalNames = {"gamepad_banking", "banking"}
	local function Resolve(name)
		local scene = BMR.Console.GetScene(name)
		if scene then return scene, name end
		return nil, nil
	end
	local function IsGuildName(name)
		return name == "gamepad_guild_bank" or name == "guild_bank"
	end
	local function IsPersonalName(name)
		return name == "gamepad_banking" or name == "banking"
	end

	-- Forced Console Flow can expose either the regular gamepad scene name or the
	-- shorter banking/guild_bank scene. Bind to the scene that is actually current
	-- first; do not register the same profile actions on both aliases.
	if IsGuildName(currentName) then
		local scene, name = Resolve(currentName)
		if scene then return scene, name, "guild" end
	elseif IsPersonalName(currentName) then
		local scene, name = Resolve(currentName)
		if scene then return scene, name, "personal" end
	end

	local preferGuild = checkingGBank == true or (isBanking ~= true and currentGBank ~= nil)
	local preferred = preferGuild and guildNames or personalNames
	local secondary = preferGuild and personalNames or guildNames
	for _, names in ipairs({preferred, secondary}) do
		for _, name in ipairs(names) do
			if BMR.Console.IsSceneShowing(name) then
				local scene, resolvedName = Resolve(name)
				if scene then return scene, resolvedName, IsGuildName(resolvedName) and "guild" or "personal" end
			end
		end
	end

	-- When the scene manager still reports its parent scene during the opening
	-- transition, use the corresponding bank scene object. The library attaches
	-- the keybind to the scene object itself and shows it only while that scene is
	-- active; this is not a permanent HUD-root registration.
	local fallbackNames = (checkingGBank == true or (isBanking ~= true and currentGBank ~= nil)) and guildNames or personalNames
	for _, name in ipairs(fallbackNames) do
		local scene, resolvedName = Resolve(name)
		if scene then return scene, resolvedName, IsGuildName(resolvedName) and "guild" or "personal" end
	end
	return nil, nil, nil
end

local function GetBMRPersistentProfileRegistrationRegistry()
	-- LibConsoleDialogs keeps its registrations for the life of the client session and
	-- has no unregister API. Store successful-registration markers on the library object
	-- too, so /reloadui cannot add another copy to the same scene while it remains loaded.
	if type(LibConsoleDialogs) == "table" then
		local ok, registry = pcall(function()
			if type(LibConsoleDialogs._BankManagerRevivedProfileKeybinds) ~= "table" then
				LibConsoleDialogs._BankManagerRevivedProfileKeybinds = {}
			end
			return LibConsoleDialogs._BankManagerRevivedProfileKeybinds
		end)
		if ok and type(registry) == "table" then return registry end
	end

	-- Fallback for library builds that reject addon-owned fields.
	local state = BMR.Console.profileDialogRegistration
	if type(state) ~= "table" or state.apiVersion ~= 2 then
		state = {apiVersion = 2, registeredByScene = {}}
		BMR.Console.profileDialogRegistration = state
	end
	state.registeredByScene = state.registeredByScene or {}
	return state.registeredByScene
end

BMR.Console.RegisterSceneKeybinds = function()
	BMR.Console.RemoveNativeProfileKeybindGroup("replace-fixed-bank-keybinds")
	if (not BMR.Console.IsAvailable() and not BMR.Console.IsBankSceneOpen()) then return false end

	if not BMR.Console.HasDialogSupport() then
		if not BMR.Console.profileKeybindMissingDependencyReported then
			BMR.Console.profileKeybindMissingDependencyReported = true
			BMR.ProfileDiagnosticChat("BMR: Profilsteuerung benötigt LibConsoleDialogs und LibHarvensAddonSettings. Es werden bewusst keine festen Banktasten überschrieben.")
		end
		BMR.ProfileDiagnostic("CONSOLE_PROFILE_KEYBINDS_UNAVAILABLE", "LibConsoleDialogs/LibHarvensAddonSettings missing; fixed native keys are disabled")
		return false
	end

	local scene, sceneName, bankKind = BMR.Console.GetProfileKeybindTargetScene()
	if not scene or not sceneName then
		BMR.ProfileDiagnostic("CONSOLE_PROFILE_KEYBINDS_WAITING_BANK_SCENE", "no active personal/guild bank scene; current=" .. tostring(BMR.Console.GetCurrentSceneName()))
		return false
	end

	local registry = GetBMRPersistentProfileRegistrationRegistry()
	local registration = registry[sceneName]
	if type(registration) ~= "table" then registration = {}; registry[sceneName] = registration end
	local dialogState = BMR.Console.profileDialogRegistration
	if type(dialogState) ~= "table" or dialogState.apiVersion ~= 2 then
		dialogState = {apiVersion = 2, registeredByScene = registry}
		BMR.Console.profileDialogRegistration = dialogState
	end
	dialogState.targetSceneName = sceneName
	dialogState.registeredByScene = registry
	if registration.complete == true then
		BMR.ProfileDiagnostic("CONSOLE_PROFILE_KEYBINDS_ALREADY_REGISTERED", "scene=" .. tostring(sceneName))
		return true
	end

	local failed = {}
	local function Register(key, buttonInfo)
		if registration[key] == true then return true end
		local ok, err = pcall(function()
			-- Pass the resolved scene object. This is supported by the library API and
			-- avoids a string-name lookup resolving to a different scene alias.
			LibConsoleDialogs:RegisterKeybind(scene, buttonInfo)
		end)
		if ok then
			registration[key] = true
			return true
		end
		failed[#failed + 1] = key .. ": " .. tostring(err)
		return false
	end

	local function IsTargetBankActive()
		if not BMR.Console.IsBankSceneOpen() then return false end
		local currentName = string.lower(tostring(BMR.Console.GetCurrentSceneName() or ""))
		if currentName == sceneName or BMR.Console.IsSceneShowing(sceneName) then return true end
		if bankKind == "guild" then return checkingGBank == true or currentGBank ~= nil end
		return isBanking == true and checkingGBank ~= true
	end

	Register("previous", {
		name = GetString(BMR_CONSOLE_PREVIOUS_PROFILE),
		tooltip = GetString(BMR_CONSOLE_PREVIOUS_PROFILE_TOOLTIP),
		alignment = KEYBIND_STRIP_ALIGN_LEFT or KEYBIND_STRIP_ALIGN_CENTER,
		order = 80,
		visible = function() return IsTargetBankActive() and not inProgress and #BMR.Console.GetDefinedProfiles() > 1 end,
		callback = function() BMR._consoleLastAction = "keybind-previous-fired"; BMR.Console.CycleProfile(-1) end,
	})
	Register("next", {
		name = GetString(BMR_CONSOLE_NEXT_PROFILE),
		tooltip = GetString(BMR_CONSOLE_NEXT_PROFILE_TOOLTIP),
		alignment = KEYBIND_STRIP_ALIGN_LEFT or KEYBIND_STRIP_ALIGN_CENTER,
		order = 81,
		visible = function() return IsTargetBankActive() and not inProgress and #BMR.Console.GetDefinedProfiles() > 1 end,
		callback = function() BMR._consoleLastAction = "keybind-next-fired"; BMR.Console.CycleProfile(1) end,
	})
	Register("choose", {
		name = GetString(BMR_CONSOLE_CHOOSE_PROFILE),
		tooltip = GetString(BMR_CONSOLE_CHOOSE_PROFILE_TOOLTIP),
		alignment = KEYBIND_STRIP_ALIGN_LEFT or KEYBIND_STRIP_ALIGN_CENTER,
		order = 82,
		visible = function() return IsTargetBankActive() and not inProgress and #BMR.Console.GetDefinedProfiles() > 0 end,
		callback = function() BMR._consoleLastAction = "keybind-open-profile-dialog-fired"; BMR.Console.OpenProfileDialog() end,
	})
	Register("run", {
		name = GetString(BMR_CONSOLE_RUN_PROFILE),
		tooltip = GetString(BMR_CONSOLE_RUN_PROFILE_TOOLTIP),
		alignment = KEYBIND_STRIP_ALIGN_RIGHT or KEYBIND_STRIP_ALIGN_CENTER,
		order = 83,
		visible = function() return IsTargetBankActive() and (isBanking or checkingGBank) and not inProgress end,
		callback = function() BMR.Console.RunSelectedProfile("keybind") end,
	})

	registration.complete = registration.previous == true and registration.next == true
		and registration.choose == true and registration.run == true
	BMR.ProfileDiagnostic(registration.complete and "CONSOLE_PROFILE_KEYBINDS_REGISTERED_ON_BANK_SCENE" or "CONSOLE_PROFILE_KEYBINDS_PARTIAL",
		"scene=" .. tostring(sceneName) .. "; registered=" .. tostring(registration.previous) .. "/" .. tostring(registration.next) .. "/" .. tostring(registration.choose) .. "/" .. tostring(registration.run)
		.. (#failed > 0 and "; failed=" .. table.concat(failed, " | ") or ""))
	if #failed > 0 then
		BMR.ProfileDiagnosticChat("BMR: Profil-Keybind-Registrierung teilweise fehlgeschlagen: " .. table.concat(failed, "; "):sub(1, 180))
	end
	return registration.complete == true
end

-- Dedicated controller shortcut for creating/removing exact-item BMR rules.
-- This is an independent keybind group, not an item in the game's Y/Actions menu.
-- That keeps the action available even when LibGamepadContextMenuBridge is absent.
BMR.Console.InstallInventoryRuleKeybindHooks = function()
	local inventoryClass = _G.ZO_GamepadInventoryList
	if type(inventoryClass) ~= "table" then
		BMR.ProfileDiagnostic("CONSOLE_INVENTORY_RULE_HOOK_WAITING", "ZO_GamepadInventoryList not available yet")
		return false
	end
	if BMR.Console.inventoryRuleListHooksInstalled then return true end
	BMR.Console.inventoryRuleActiveLists = BMR.Console.inventoryRuleActiveLists or {}
	BMR.Console.inventoryRuleActivationCounter = BMR.Console.inventoryRuleActivationCounter or 0

	local updateName = ADDON_NAME .. "_InventoryRuleKeybindRefresh"
	local function listHasBackpack(list)
		if type(list) ~= "table" or type(list.inventoryTypes) ~= "table" or type(BAG_BACKPACK) ~= "number" then return false end
		for _, bagId in ipairs(list.inventoryTypes) do
			if bagId == BAG_BACKPACK then return true end
		end
		return false
	end

	local function getSelectedBackpackItem(list)
		if not list or type(list.GetTargetData) ~= "function" then return nil end
		if type(list.IsActive) == "function" then
			local ok, active = pcall(list.IsActive, list)
			if not ok or not active then return nil end
		end
		local ok, targetData = pcall(list.GetTargetData, list)
		if not ok or type(targetData) ~= "table" then return nil end
		-- GetTargetData() returns ZO_GamepadEntryData. Its itemData is the exact
		-- SHARED_INVENTORY slot record with bagId and slotIndex.
		local itemData = type(targetData.itemData) == "table" and targetData.itemData
			or (type(targetData.data) == "table" and targetData.data)
			or targetData
		local bagId = itemData.bagId or targetData.bagId
		local slotIndex = itemData.slotIndex or targetData.slotIndex
		if bagId ~= BAG_BACKPACK or slotIndex == nil then return nil end
		local custom = BMR.CustomRules
		if type(custom) ~= "table" or type(custom.GetCustomRuleItemIdFromSlot) ~= "function" then return nil end
		local itemId = custom.GetCustomRuleItemIdFromSlot(bagId, slotIndex)
		if not itemId then return nil end
		return {
			bagId = bagId,
			slotIndex = slotIndex,
			itemId = itemId,
			hasRule = type(custom.HasCustomItemRule) == "function" and custom.HasCustomItemRule(itemId) or false,
		}
	end

	local function getNewestActiveList()
		local newestOrder, newestList = -1, nil
		for activeList, order in pairs(BMR.Console.inventoryRuleActiveLists) do
			if order > newestOrder then newestOrder, newestList = order, activeList end
		end
		return newestList
	end

	local function removeListKeybind(list)
		local group = list and list.bmrInventoryRuleKeybindGroup
		if not group or not KEYBIND_STRIP then return end
		local hasGroup = false
		if type(KEYBIND_STRIP.HasKeybindButtonGroup) == "function" then
			local ok, value = pcall(KEYBIND_STRIP.HasKeybindButtonGroup, KEYBIND_STRIP, group)
			hasGroup = ok and value == true
		else
			hasGroup = list.bmrInventoryRuleKeybindGroupAdded == true
		end
		if hasGroup and type(KEYBIND_STRIP.RemoveKeybindButtonGroup) == "function" then
			pcall(KEYBIND_STRIP.RemoveKeybindButtonGroup, KEYBIND_STRIP, group)
		end
		list.bmrInventoryRuleKeybindGroupAdded = false
	end

	local function addListKeybind(list)
		local group = list and list.bmrInventoryRuleKeybindGroup
		if not group or not KEYBIND_STRIP or type(KEYBIND_STRIP.AddKeybindButtonGroup) ~= "function" then return false end
		local alreadyAdded = false
		if type(KEYBIND_STRIP.HasKeybindButtonGroup) == "function" then
			local ok, value = pcall(KEYBIND_STRIP.HasKeybindButtonGroup, KEYBIND_STRIP, group)
			alreadyAdded = ok and value == true
		else
			alreadyAdded = list.bmrInventoryRuleKeybindGroupAdded == true
		end
		if not alreadyAdded then
			local ok = pcall(KEYBIND_STRIP.AddKeybindButtonGroup, KEYBIND_STRIP, group)
			list.bmrInventoryRuleKeybindGroupAdded = ok
			if ok then BMR.ProfileDiagnostic("CONSOLE_INVENTORY_RULE_KEYBIND_GROUP_ADDED", "key=UI_SHORTCUT_RIGHT_STICK") end
			return ok
		end
		return true
	end

	local function refreshListKeybind(list, forceRefresh)
		local descriptor = list and list.bmrInventoryRuleDescriptor
		if not descriptor then return end
		local selection = getSelectedBackpackItem(list)
		local newestList = getNewestActiveList()
		local isCurrent = newestList == list
		local shouldShow = isCurrent and selection ~= nil
		if shouldShow and not selection.hasRule then
			local custom = BMR.CustomRules
			shouldShow = type(custom) == "table" and type(custom.ShouldShowSetCustomRuleAction) == "function"
				and custom.ShouldShowSetCustomRuleAction() == true
		end
		local desiredName = selection and selection.hasRule and GetString(BMR_CUSTOM_RULE_REMOVE_MENU) or GetString(BMR_CUSTOM_RULE_SET)
		descriptor.name = desiredName
		local signature = tostring(shouldShow) .. ":" .. tostring(selection and selection.itemId or "none") .. ":" .. tostring(selection and selection.hasRule or false) .. ":" .. tostring(desiredName)
		if forceRefresh or signature ~= list.bmrInventoryRuleKeybindSignature then
			list.bmrInventoryRuleKeybindSignature = signature
			-- Remove/re-add is supported by the actual KEYBIND_STRIP API and forces
			-- visibility/name evaluation; UpdateKeybindButtonGroup is not universal.
			if list.bmrInventoryRuleKeybindGroupAdded then removeListKeybind(list) end
			if isCurrent then addListKeybind(list) end
		end
	end

	local function attachDescriptor(list)
		if not listHasBackpack(list) then return false end
		if list.bmrInventoryRuleDescriptor then return true end
		local descriptor = {
			name = GetString(BMR_CUSTOM_RULE_SET),
			keybind = "UI_SHORTCUT_RIGHT_STICK",
			visible = function()
				local selection = getSelectedBackpackItem(list)
				if not selection or getNewestActiveList() ~= list then return false end
				if selection.hasRule then return true end
				local custom = BMR.CustomRules
				return type(custom) == "table" and type(custom.ShouldShowSetCustomRuleAction) == "function"
					and custom.ShouldShowSetCustomRuleAction() == true
			end,
			callback = function()
				local selection = getSelectedBackpackItem(list)
				local custom = BMR.CustomRules
				if not selection or type(custom) ~= "table" then
					BMR.ProfileDiagnosticChat("BMR: Keine gültige Inventarauswahl für die Regelaktion.")
					return
				end
				local ok, result, reason
				if selection.hasRule then
					ok, result, reason = pcall(custom.RemoveCustomItemRuleById, selection.itemId)
				else
					ok, result, reason = pcall(custom.AddCustomItemRuleFromSlot, selection.bagId, selection.slotIndex)
				end
				if not ok then
					local message = tostring(result):gsub("[\r\n]+", " "):sub(1, 120)
					BMR.ProfileDiagnosticChat("BMR: Inventar-Regelaktion fehlgeschlagen: " .. message)
					BMR.ProfileDiagnostic("CONSOLE_INVENTORY_RULE_ACTION_ERROR", tostring(result))
				elseif result == false then
					BMR.ProfileDiagnosticChat("BMR: Inventar-Regelaktion nicht ausgeführt (" .. tostring(reason or "unbekannter Grund") .. ").")
					BMR.ProfileDiagnostic("CONSOLE_INVENTORY_RULE_ACTION_SKIPPED", tostring(reason or "operation returned false"))
				elseif selection.hasRule then
					BMR.ProfileDiagnosticChat("BMR: Gegenstandsregel entfernt.")
				else
					BMR.ProfileDiagnosticChat("BMR: Gegenstandsregel erstellt.")
				end
				refreshListKeybind(list, true)
			end,
		}
		list.bmrInventoryRuleDescriptor = descriptor
		list.bmrInventoryRuleKeybindGroup = {
			alignment = KEYBIND_STRIP_ALIGN_CENTER or KEYBIND_STRIP_ALIGN_LEFT,
			descriptor,
		}
		BMR.ProfileDiagnostic("CONSOLE_INVENTORY_RULE_DESCRIPTOR_CREATED", "key=UI_SHORTCUT_RIGHT_STICK; mode=independent-keybind-group")
		return true
	end

	local function updateActiveLists()
		local newestList = getNewestActiveList()
		local anyActive = false
		for list in pairs(BMR.Console.inventoryRuleActiveLists) do
			local active = true
			if type(list.IsActive) == "function" then
				local ok, result = pcall(list.IsActive, list)
				active = ok and result == true
			end
			if active then
				anyActive = true
				attachDescriptor(list)
				if list == newestList then
					refreshListKeybind(list, false)
				else
					removeListKeybind(list)
				end
			else
				removeListKeybind(list)
				BMR.Console.inventoryRuleActiveLists[list] = nil
			end
		end
		if anyActive then
			if not BMR.Console.inventoryRuleUpdateActive then
				BMR.Console.inventoryRuleUpdateActive = true
				EVENT_MANAGER:RegisterForUpdate(updateName, 250, updateActiveLists)
			end
		elseif BMR.Console.inventoryRuleUpdateActive then
			BMR.Console.inventoryRuleUpdateActive = false
			EVENT_MANAGER:UnregisterForUpdate(updateName)
		end
	end

	local function installPostHook(methodName, callback)
		if type(inventoryClass[methodName]) ~= "function" then return false end
		if type(ZO_PostHook) == "function" then
			local ok = pcall(ZO_PostHook, inventoryClass, methodName, callback)
			return ok
		end
		local original = inventoryClass[methodName]
		inventoryClass[methodName] = function(self, ...)
			local result = original(self, ...)
			callback(self)
			return result
		end
		return true
	end

	local activateOk = installPostHook("Activate", function(list)
		if listHasBackpack(list) then
			BMR.Console.inventoryRuleActivationCounter = BMR.Console.inventoryRuleActivationCounter + 1
			BMR.Console.inventoryRuleActiveLists[list] = BMR.Console.inventoryRuleActivationCounter
			attachDescriptor(list)
			updateActiveLists()
		end
	end)
	local deactivateOk = installPostHook("Deactivate", function(list)
		removeListKeybind(list)
		BMR.Console.inventoryRuleActiveLists[list] = nil
		updateActiveLists()
	end)
	if activateOk and deactivateOk then
		BMR.Console.inventoryRuleListHooksInstalled = true
		BMR.ProfileDiagnostic("CONSOLE_INVENTORY_RULE_HOOKS_INSTALLED", "Activate/Deactivate; independent keybind group; key=UI_SHORTCUT_RIGHT_STICK")
		return true
	end
	BMR.ProfileDiagnostic("CONSOLE_INVENTORY_RULE_HOOKS_FAILED", "Activate=" .. tostring(activateOk) .. "; Deactivate=" .. tostring(deactivateOk))
	return false
end

-- Wire the console/gamepad scenes before any bank event tries to display the classic
-- floating control. This avoids a circular dependency in ForceConsoleFlow: the control can be
-- hidden by the console UI flow, and previously that prevented keybind registration altogether.
BMR.Console.InstallSceneHooks = function()
	if not SCENE_MANAGER or type(SCENE_MANAGER.GetScene) ~= "function" then return false end
	BMR.Console.sceneHooks = BMR.Console.sceneHooks or {}
	local installed = 0
	for _, sceneName in ipairs(BMR.Console.GetEffectiveBankSceneNames()) do
		local hookedSceneName = sceneName -- capture the scene-specific name for Lua 5.1 closures
		local scene = BMR.Console.GetScene(hookedSceneName)
		if scene then
			if not BMR.Console.sceneHooks[scene] and type(scene.RegisterCallback) == "function" then
				local callback = function(_, newState)
					if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
						BMR.ProfileDiagnostic("CONSOLE_BANK_SCENE_ENTER", "scene=" .. tostring(hookedSceneName) .. "; mode=" .. tostring(BMR.Console.IsModeActive()) .. "; " .. BMR.ProfileDebugSnapshot())
						if BMR.Console.IsAvailable() or BMR.Console.IsBankSceneOpen() then
							-- Register the scene keybinds independently of EVENT_OPEN_BANK and
							-- displayUI. The latter remains the normal route for transfers.
							BMR.Console.RegisterSceneKeybinds()
							zo_callLater(function()
								if BMR.Console.IsBankSceneOpen() and db and db.profiles and type(db.profiles[actualProfile]) == "table" then
									displayUI(#BMR.Console.GetDefinedProfiles() > 1)
								end
							end, 50)
						end
					elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
						BMR.ProfileDiagnostic("CONSOLE_BANK_SCENE_EXIT", "scene=" .. tostring(hookedSceneName))
					end
				end
				local ok = pcall(function() scene:RegisterCallback("StateChange", callback) end)
				if ok then
					BMR.Console.sceneHooks[scene] = sceneName
					installed = installed + 1
				end
			end
		end
	end
	if installed > 0 then BMR.ProfileDiagnostic("CONSOLE_SCENE_HOOKS_INSTALLED", "newHooks=" .. tostring(installed)) end
	return installed > 0
end

BMR.Console.RefreshForScene = function()
	BMR.Console.InstallInventoryRuleKeybindHooks()
	BMR.Console.InstallSceneHooks()
	if BMR.Console.IsAvailable() or BMR.Console.IsBankSceneOpen() then BMR.Console.RegisterSceneKeybinds() end
	if BMR.Console.IsBankSceneOpen() and db and db.profiles and type(db.profiles[actualProfile]) == "table" then
		displayUI(#BMR.Console.GetDefinedProfiles() > 1)
	end
end

BMR.Console.PrintDebugStatus = function()
	local cvar = "n/a"
	if type(GetCVar) == "function" then
		local ok, value = pcall(GetCVar, "ForceConsoleFlow.2")
		if ok then cvar = tostring(value) end
	end
	local consoleUI = "n/a"
	if type(IsConsoleUI) == "function" then
		local ok, value = pcall(IsConsoleUI)
		if ok then consoleUI = tostring(value) end
	end
	local gamepad = "n/a"
	if type(IsInGamepadPreferredMode) == "function" then
		local ok, value = pcall(IsInGamepadPreferredMode)
		if ok then gamepad = tostring(value) end
	end
	local currentScene = "n/a"
	if SCENE_MANAGER and type(SCENE_MANAGER.GetCurrentScene) == "function" then
		local ok, scene = pcall(function() return SCENE_MANAGER:GetCurrentScene() end)
		if ok and scene and type(scene.GetName) == "function" then
			local nameOk, name = pcall(function() return scene:GetName() end)
			if nameOk then currentScene = tostring(name) end
		end
	end
	local bankSceneStates = {}
	for _, name in ipairs(BMR.Console.bankSceneNames or {}) do
		bankSceneStates[#bankSceneStates + 1] = name .. "=" .. tostring(BMR.Console.IsSceneShowing(name))
	end
	BMR.Console.RefreshForScene()
	local profileCount = tonumber(db and db.profileCount) or 0
	local activeProfile = tonumber(actualProfile) or -1
	local definedProfiles = BMR.Console.GetDefinedProfiles()
	local rootHidden = "unknown"
	if BankManager and type(BankManager.IsControlHidden) == "function" then
		local ok, value = pcall(BankManager.IsControlHidden, BankManager)
		if ok then rootHidden = tostring(value) end
	end
	local keyboardSupported = "n/a"
	if type(IsKeyboardUISupported) == "function" then
		local ok, value = pcall(IsKeyboardUISupported)
		if ok then keyboardSupported = tostring(value) end
	end
	local lhaPresent = type(LibHarvensAddonSettings) == "table" and type(LibHarvensAddonSettings.AddAddon) == "function"
	local libGamepadPresent = type(IsAddOnLoaded) == "function" and IsAddOnLoaded("LibGamepad") == true
	local gamepadContextBridgePresent = type(IsAddOnLoaded) == "function" and IsAddOnLoaded("LibGamepadContextMenuBridge") == true
	local libCustomMenuPresent = type(LibCustomMenu) == "table" and type(LibCustomMenu.RegisterContextMenu) == "function"
	local contextMenuCallbackRegistered = BMR.customItemActionsRegistered == true
	local activeInventoryRuleLists = 0
	local inventoryRuleDescriptors = 0
	local inventoryRuleTriggerGroups = 0
	for list in pairs(BMR.Console.inventoryRuleActiveLists or {}) do
		activeInventoryRuleLists = activeInventoryRuleLists + 1
		if list.bmrInventoryRuleDescriptor then inventoryRuleDescriptors = inventoryRuleDescriptors + 1 end
		local group = list.bmrInventoryRuleKeybindGroup
		if group and KEYBIND_STRIP and type(KEYBIND_STRIP.HasKeybindButtonGroup) == "function" then
			local ok, present = pcall(KEYBIND_STRIP.HasKeybindButtonGroup, KEYBIND_STRIP, group)
			if ok and present then inventoryRuleTriggerGroups = inventoryRuleTriggerGroups + 1 end
		end
	end
	local hookCount, sceneCount = 0, 0
	for _ in pairs(BMR.Console.sceneHooks or {}) do hookCount = hookCount + 1 end
	for _, name in ipairs(BMR.Console.GetEffectiveBankSceneNames()) do if BMR.Console.GetScene(name) then sceneCount = sceneCount + 1 end end
	local lam = BMR._lamInstance
	local lamPresent = type(lam) == "table" and type(lam.RegisterAddonPanel) == "function"
	local settingsBackend = tostring(BMR._consoleSettingsAdapter or (BMR._consoleSettingsPanel and "LHA-panel" or "LAM-panel-or-none"))
	local profileStoreReady = type(db) == "table" and type(db.profiles) == "table"
	local dialogSupport = BMR.Console.HasDialogSupport and BMR.Console.HasDialogSupport() or false
	local ruleModule = type(BankManagerRules) == "table"
	local ruleFunctions = ruleModule and (type(BankManagerRules.addFilters) == "function") and (type(BankManagerRules.addFiltersTaggedAll) == "function") and (type(BankManagerRules.addDefaultFilters) == "function")
	BMR.ProfileDiagnosticChat("BMR-CD flow=" .. tostring(BMR.Console.IsControllerFlowActive()) .. " kb=" .. keyboardSupported .. " c=" .. cvar .. " scene=" .. currentScene .. " bankScene=" .. tostring(BMR.Console.IsBankSceneOpen()))
	local profileKeybindState = type(BMR.Console.profileDialogRegistration) == "table" and BMR.Console.profileDialogRegistration or {}
	BMR.ProfileDiagnosticChat("bankState=" .. tostring(isBanking) .. "/" .. tostring(checkingGBank) .. " eventsRegistered=" .. tostring(BMR._bankEventsRegistered) .. " hooks=" .. hookCount .. " scenes=" .. sceneCount .. " dialogs=" .. tostring(dialogSupport) .. " profileKeybindScene=" .. tostring(profileKeybindState.targetSceneName or "pending") .. " registeredOnce=" .. tostring(profileKeybindState.complete == true))
	BMR.ProfileDiagnosticChat("db=" .. tostring(profileStoreReady) .. " count=" .. tostring(db and db.profileCount) .. " defs=" .. table.concat(definedProfiles, ",") .. " LAM=" .. tostring(lamPresent) .. " LHA=" .. tostring(lhaPresent) .. " LibGamepad=" .. tostring(libGamepadPresent) .. " LCM=" .. tostring(libCustomMenuPresent) .. " BMRContext=" .. tostring(contextMenuCallbackRegistered) .. " ContextBridge=" .. tostring(gamepadContextBridgePresent) .. " settings=" .. settingsBackend .. " hidden=" .. rootHidden)
	BMR.ProfileDiagnosticChat("InventoryRuleKeybindHooks=" .. tostring(BMR.Console.inventoryRuleListHooksInstalled == true) .. " activeLists=" .. tostring(activeInventoryRuleLists) .. " descriptors=" .. tostring(inventoryRuleDescriptors) .. " dedicatedGroups=" .. tostring(inventoryRuleTriggerGroups) .. " key=UI_SHORTCUT_RIGHT_STICK")
	BMR.ProfileDiagnosticChat("RuleBuilder=live tooltips (LHA settings refresh)")
	BMR.ProfileDiagnosticChat("Startup matched=" .. tostring(BMR._addonLoadEventMatched) .. " phase=" .. tostring(BMR._startupPhase) .. " rulesAPI=" .. tostring(ruleFunctions) .. " rulesBuild=" .. tostring(BMR._ruleBuildOk) .. " core=" .. tostring(BMR._coreProfileStoreInitOk) .. " Build=" .. tostring(BMR._panelBuildOk))
	if BMR._ruleBuildError then BMR.ProfileDiagnosticChat("Rules error=" .. string.gsub(tostring(BMR._ruleBuildError), "[\r\n]+", " "):sub(1, 190)) end
	if BMR._panelBuildError then BMR.ProfileDiagnosticChat("Build error=" .. string.gsub(tostring(BMR._panelBuildError), "[\r\n]+", " "):sub(1, 190)) end
	if type(BMR._consoleSubmenuErrors) == "table" then
		local names = {}
		for name in pairs(BMR._consoleSubmenuErrors) do names[#names + 1] = tostring(name) end
		table.sort(names)
		if #names > 0 then BMR.ProfileDiagnosticChat("Submenus skipped=" .. table.concat(names, ",")) end
	end
	BMR.ProfileDiagnosticChat("Settings controls=" .. tostring(BMR._consoleSettingsControlsAdded or 0) .. " regmode=" .. tostring(BMR._consoleSettingsRegistrationMode or "n/a") .. " LHA=" .. tostring(LibHarvensAddonSettings and LibHarvensAddonSettings.version or "unknown") .. " adapter=" .. tostring(BMR._consoleSettingsAdapter or "none"))
	if type(BMR._consoleSettingsCategoryCounts) == "table" then
		local function ReadSettingsCategoryLabel(stringId)
			if type(GetString) ~= "function" or stringId == nil then return nil end
			local ok, value = pcall(GetString, stringId)
			return ok and tostring(value or "") or nil
		end
		local labels = {
			ReadSettingsCategoryLabel(BMR_CONTAINERS),
			ReadSettingsCategoryLabel(SI_INVENTORY_CURRENCIES),
			ReadSettingsCategoryLabel(BMR_CUSTOM_RULES),
			ReadSettingsCategoryLabel(BMR_PVP_CATEGORY),
			ReadSettingsCategoryLabel(SI_HOUSING_BOOK_TITLE),
		}
		local parts = {}
		for _, label in ipairs(labels) do
			if label and label ~= "" then
				parts[#parts + 1] = label .. "=" .. tostring(BMR._consoleSettingsCategoryCounts[label] or 0)
			end
		end
		if #parts > 0 then BMR.ProfileDiagnosticChat("Menu controls " .. table.concat(parts, "; ")) end
		-- Print every LHA page/count as well; localized names can differ from
		-- our compact labels above and must not be guessed from English/German.
		local allLabels = {}
		for label in pairs(BMR._consoleSettingsCategoryCounts) do
			if type(label) == "string" and label ~= "" then allLabels[#allLabels + 1] = label end
		end
		table.sort(allLabels)
		local batch = {}
		for _, label in ipairs(allLabels) do
			batch[#batch + 1] = label .. "=" .. tostring(BMR._consoleSettingsCategoryCounts[label] or 0)
			if #batch == 3 then
				BMR.ProfileDiagnosticChat("LHA-Seiten " .. table.concat(batch, "; "))
				batch = {}
			end
		end
		if #batch > 0 then BMR.ProfileDiagnosticChat("LHA-Seiten " .. table.concat(batch, "; ")) end
	end
	if type(BMR._consoleSubmenuControlCounts) == "table" then
		local order = {"trophies", "misc", "special", "pvp", "containers", "housing"}
		local names = {trophies = "Trophäe", misc = "Verschiedenes", special = "Quest-Handwerk", pvp = "PvP", containers = "Behälter", housing = "Wohnen"}
		local parts = {}
		for _, key in ipairs(order) do
			if BMR._consoleSubmenuControlCounts[key] ~= nil then
				parts[#parts + 1] = names[key] .. "=" .. tostring(BMR._consoleSubmenuControlCounts[key])
			end
		end
		if #parts > 0 then BMR.ProfileDiagnosticChat("LAM erzeugte Zeilen " .. table.concat(parts, "; ")) end
	end
	local interaction = "n/a"
	if type(GetBankingInteractionType) == "function" then local ok, value = pcall(GetBankingInteractionType); if ok then interaction = tostring(value) end end
	BMR.ProfileDiagnosticChat("Input last=" .. tostring(BMR._consoleLastAction or "none") .. " busy=" .. tostring(inProgress) .. "/" .. tostring(activeRuleRunPhase) .. " queues=" .. tostring(#pushQueue) .. "/" .. tostring(#pullQueue) .. " interaction=" .. interaction)
	BMR.ProfileDiagnosticChat("Bank API constants: bank=" .. tostring(_G.BANKING_TYPE_BANK or _G.BANKING_TYPE_PERSONAL_BANK or "nil") .. " guild=" .. tostring(_G.BANKING_TYPE_GUILD_BANK or "nil") .. " none=" .. tostring(_G.BANKING_TYPE_NONE or "nil"))
	if BMR._coreProfileStoreInitError then BMR.ProfileDiagnosticChat("Core error=" .. string.gsub(tostring(BMR._coreProfileStoreInitError), "[\r\n]+", " "):sub(1, 190)) end

end

SLASH_COMMANDS["/bmr/consoledebug"] = function() BMR.Console.PrintDebugStatus() end
-- Direct test entry points bypass the scene keybind layer but use the same guarded handlers.
SLASH_COMMANDS["/bmr/profile/next"] = function() BMR.Console.CycleProfile(1) end
SLASH_COMMANDS["/bmr/profile/previous"] = function() BMR.Console.CycleProfile(-1) end
SLASH_COMMANDS["/bmr/profile/run"] = function() BMR.Console.RunSelectedProfile("slash-command") end

-- PvP movement trace helpers. The inventory event itself does not identify the actor, so only
-- slot updates matched to a recorded BMR RequestMoveItem are labelled BMR_EXPECTED. Everything
-- else affecting a tracked PvP item is marked UNMATCHED_EXTERNAL (manual move/other addon possible).
local function IsTrackedPvpItemLink(link)
	if not link or link == "" then return false end
	local ok, itemId = pcall(GetItemLinkItemId, link)
	return ok and itemId ~= nil and ((BMR_PVP_ITEM_CATALOG and BMR_PVP_ITEM_CATALOG[itemId]) or itemId == 30359) or false
end

local function GetPvpTraceSlotState(bagId, slotId)
	local link = GetItemLink(bagId, slotId)
	if not IsTrackedPvpItemLink(link) then link = nil end
	local count = link and (GetSlotStackSize(bagId, slotId) or 0) or 0
	return { link = link, count = count }
end

local function CapturePvpMovementTraceBaseline()
	pvpMovementTraceBaseline = {}
	local bags = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }
	if activeHouseStorageBagId then table.insert(bags, activeHouseStorageBagId) end
	local total = 0
	for _, bagId in ipairs(bags) do
		pvpMovementTraceBaseline[bagId] = {}
		local size = GetBagSize(bagId) or 0
		for slotId = 0, size - 1 do
			pvpMovementTraceBaseline[bagId][slotId] = GetPvpTraceSlotState(bagId, slotId)
			if pvpMovementTraceBaseline[bagId][slotId].link then total = total + 1 end
		end
	end
	CustomRuleDebug(string.format("MOVE TRACE BASELINE captured trackedSlots=%d", total))
end

RegisterExpectedPvpMoveTrace = function(fromBag, fromSlot, toBag, toSlot, qty, itemLink)
	if not (db and db.customRulesDebug == true and pvpMovementTraceActive) then return nil end
	if fromBag == toBag or not IsTrackedPvpItemLink(itemLink) then return nil end
	pvpExpectedMoveTraceSerial = pvpExpectedMoveTraceSerial + 1
	local entry = { id = pvpExpectedMoveTraceSerial, fromBag = fromBag, fromSlot = fromSlot, toBag = toBag, toSlot = toSlot, qty = qty, itemLink = itemLink, sourceSeen = false, destSeen = false }
	table.insert(pvpExpectedMoveTraces, entry)
	CustomRuleDebug(string.format("MOVE TRACE EXPECTED id=%d sourceBag=%s sourceSlot=%s targetBag=%s targetSlot=%s qty=%s itemLink=%s", entry.id, tostring(fromBag), tostring(fromSlot), tostring(toBag), tostring(toSlot), tostring(qty), tostring(itemLink)))
	zo_callLater(function()
		for index, pending in ipairs(pvpExpectedMoveTraces) do
			if pending == entry then
				CustomRuleDebug(string.format("MOVE TRACE TIMEOUT id=%d sourceUpdateSeen=%s targetUpdateSeen=%s sourceBag=%s sourceSlot=%s targetBag=%s targetSlot=%s qty=%s itemLink=%s", entry.id, tostring(entry.sourceSeen), tostring(entry.destSeen), tostring(entry.fromBag), tostring(entry.fromSlot), tostring(entry.toBag), tostring(entry.toSlot), tostring(entry.qty), tostring(entry.itemLink)))
				table.remove(pvpExpectedMoveTraces, index)
				break
			end
		end
	end, 2500)
	return entry
end

CancelExpectedPvpMoveTrace = function(entry, reason)
	if not entry then return end
	for index, pending in ipairs(pvpExpectedMoveTraces) do
		if pending == entry then
			CustomRuleDebug(string.format("MOVE TRACE CANCELLED id=%d sourceUpdateSeen=%s targetUpdateSeen=%s reason=%s", entry.id, tostring(entry.sourceSeen), tostring(entry.destSeen), tostring(reason or "no longer expected")))
			table.remove(pvpExpectedMoveTraces, index)
			return
		end
	end
end

local function FindExpectedPvpMoveUpdate(bagId, slotId)
	for _, entry in ipairs(pvpExpectedMoveTraces) do
		if entry.fromBag == bagId and entry.fromSlot == slotId and not entry.sourceSeen then return entry, "SOURCE" end
		if entry.toBag == bagId and entry.toSlot == slotId and not entry.destSeen then return entry, "DESTINATION" end
	end
	return nil, nil
end

local function onPvpMovementTraceSlotUpdate(_, bagId, slotId, isNewItem, itemSoundCategory, updateReason, stackCountChange)
	if not pvpMovementTraceActive or not (db and db.customRulesDebug == true) then return end
	local current = GetPvpTraceSlotState(bagId, slotId)
	local old = pvpMovementTraceBaseline[bagId] and pvpMovementTraceBaseline[bagId][slotId] or { link = nil, count = 0 }
	local tracked = IsTrackedPvpItemLink(old.link) or IsTrackedPvpItemLink(current.link)
	if tracked and (old.link ~= current.link or old.count ~= current.count) then
		ClearRejectedPvpStackTargetsForSlot(bagId, slotId)
	end
	if tracked then
		local expected, role = FindExpectedPvpMoveUpdate(bagId, slotId)
		if expected then
			if role == "SOURCE" then expected.sourceSeen = true else expected.destSeen = true end
			CustomRuleDebug(string.format("MOVE SLOT UPDATE origin=BMR_EXPECTED transferId=%d role=%s bag=%s slot=%s beforeLink=%s beforeCount=%s afterLink=%s afterCount=%s isNewItem=%s updateReason=%s stackCountChange=%s", expected.id, role, tostring(bagId), tostring(slotId), tostring(old.link), tostring(old.count), tostring(current.link), tostring(current.count), tostring(isNewItem), tostring(updateReason), tostring(stackCountChange)))
			if expected.sourceSeen and expected.destSeen then
				CustomRuleDebug(string.format("MOVE TRACE EVENT PAIR OBSERVED id=%d qty=%s itemLink=%s", expected.id, tostring(expected.qty), tostring(expected.itemLink)))
				for index, pending in ipairs(pvpExpectedMoveTraces) do if pending == expected then table.remove(pvpExpectedMoveTraces, index); break end end
			end
		else
			CustomRuleDebug(string.format("MOVE SLOT UPDATE origin=UNMATCHED_EXTERNAL possibleManualOrOtherAddon=true bag=%s slot=%s beforeLink=%s beforeCount=%s afterLink=%s afterCount=%s isNewItem=%s updateReason=%s stackCountChange=%s", tostring(bagId), tostring(slotId), tostring(old.link), tostring(old.count), tostring(current.link), tostring(current.count), tostring(isNewItem), tostring(updateReason), tostring(stackCountChange)))
		end
	end
	if not pvpMovementTraceBaseline[bagId] then pvpMovementTraceBaseline[bagId] = {} end
	pvpMovementTraceBaseline[bagId][slotId] = current
end

-- onSingleSlotUpdate (only between onOpenBank and onOpenBank+2s)
local function onSingleSlotUpdate(_, bagId, slotId)
	
	-- if not, item has been moved elsewhere? We can't use SHARED_INVENTORY, it's still not updated.
	if GetItemType(bagId, slotId) ~= ITEMTYPE_NONE then
		if not movedItems[bagId] then movedItems[bagId] = {} end -- Handle other moves. BAG_WORN per exemple
		movedItems[bagId][slotId] = true
	end
	
end

-- onOpenBank
local function onOpenBank(eventCode, bagId)
		BMR.ProfileDiagnostic("PERSONAL_BANK_HANDLER_BEGIN", "eventCode=" .. tostring(eventCode) .. "; bagId=" .. tostring(bagId) .. "; " .. BMR.ProfileDebugSnapshot())
		local bankingBag = RefreshActiveHouseStorageBagContext("EVENT_OPEN_BANK", bagId)
		if activeHouseStorageBagId then
			movedItems[activeHouseStorageBagId] = movedItems[activeHouseStorageBagId] or {}
			CustomRuleDebug(string.format("HOUSE STORAGE OPEN bag=%s furnitureVault=%s; auto transfers target this bag and source scans are limited to it", tostring(activeHouseStorageBagId), tostring(IsFurnitureVaultBag(activeHouseStorageBagId))))
		else
			CustomRuleDebug(string.format("BANK OPEN bag=%s; use normal bank routing", tostring(bankingBag)))
		end
		isBanking = true
		BMR.ProfileDiagnostic("PERSONAL_BANK_STATE_SET", "bankingBag=" .. tostring(bankingBag) .. "; activeHouseStorageBagId=" .. tostring(activeHouseStorageBagId) .. "; " .. BMR.ProfileDebugSnapshot())
		-- In ForceConsoleFlow some builds do not expose a stable named gamepad bank
		-- scene callback. The bank-open event itself is reliable, so use it to show
		-- the current profile name and bind the native keybind strip immediately.
		if BMR.Console and BMR.Console.IsControllerFlowActive and BMR.Console.IsControllerFlowActive() then
		pcall(function() BMR.Console.RefreshForScene() end)
		if db and db.profiles and type(db.profiles[actualProfile]) == "table" then
			pcall(function() displayUI(BMR.Console.GetDefinedProfiles and #BMR.Console.GetDefinedProfiles() > 1 or false) end)
		end
		-- Allow the scene transition to settle, then hook the now-current bank scene
		-- as well. This is needed when ForceConsoleFlow temporarily reports the HUD
		-- as current at EVENT_OPEN_BANK time.
		zo_callLater(function()
			if isBanking and BMR.Console.IsControllerFlowActive() then
				pcall(function() BMR.Console.RefreshForScene() end)
				if db and db.profiles and type(db.profiles[actualProfile]) == "table" then
					pcall(function() displayUI(BMR.Console.GetDefinedProfiles and #BMR.Console.GetDefinedProfiles() > 1 or false) end)
				end
			end
		end, 150)
	end
	
	-- Trace all items moved by another addon while BMR waits
	if db.profiles[actualProfile].moved then
		EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, onSingleSlotUpdate)
	end
	
	-- CallLater to let the bagCache be refreshed by core UI
	zo_callLater(BMR.ProfileDebugWrapEvent("PERSONAL_BANK_DELAYED_WORK", function()
		BMR.ProfileDiagnostic("PERSONAL_BANK_DELAYED_BEGIN", "isBanking=" .. tostring(isBanking) .. "; " .. BMR.ProfileDebugSnapshot())
		-- Snapshot after the personal bank has had time to populate its slot cache.
		BMR_DumpPvpStorageSnapshot("EVENT_OPEN_BANK delayed")
		if db and db.customRulesDebug == true then
			CapturePvpMovementTraceBaseline()
			if not pvpMovementTraceActive then
				pvpMovementTraceActive = true
				EVENT_MANAGER:RegisterForEvent(pvpMovementTraceEventName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, onPvpMovementTraceSlotUpdate)
				CustomRuleDebug("MOVE TRACE ACTIVE; unmatched PvP slot changes are external/unattributed, not proof of a manual action")
			end
		end
		
		-- Stop legacy moved-slot tracing (the PvP trace remains active until the bank closes).
		if db.profiles[actualProfile].moved then
			EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
		end
		
		if isBanking then
		
			local multipleProfiles = false
			
			for i=2, db.profileCount do
				if db.profiles[i].defined == true then
					multipleProfiles = true
					break
				end
			end
			
			-- Keep the central BMR profile icon visible for a single auto-transfer profile.
			-- displayUI(false) hides only the profile arrows when no alternate profile exists.
			local activeProfile = db.profiles and db.profiles[actualProfile]
			local shouldDisplayProfileUI = type(activeProfile) == "table"
			BMR.ProfileDiagnostic("BANK_OPEN_PROFILE_SWITCH_DECISION", string.format("multipleProfiles=%s shouldDisplay=%s autoTransfer=%s %s", tostring(multipleProfiles), tostring(shouldDisplayProfileUI), tostring(type(activeProfile) == "table" and activeProfile.autoTransfert), BMR.ProfileDebugSnapshot()))
			if shouldDisplayProfileUI then
				displayUI(multipleProfiles)
			else
				BMR.ProfileDiagnostic("PROFILE_UI_SUPPRESSED", "active profile table is missing")
			end
			
			if type(activeProfile) == "table" and activeProfile.autoTransfert then
				BMR.ProfileDiagnostic("PERSONAL_BANK_AUTOSTART_CALL", BMR.ProfileDebugSnapshot())
				local controllerFlow = BMR.Console and type(BMR.Console.IsControllerFlowActive) == "function" and BMR.Console.IsControllerFlowActive()
				if controllerFlow then
					local transferOk, transferError = pcall(interactWithBank)
					if not transferOk then
						BMR.ProfileDiagnostic("CONSOLE_BANK_TRANSFER_START_FAILED", tostring(transferError))
						BMR.ProfileDiagnosticChat("BMR: Bankregeln konnten nicht gestartet werden: " .. tostring(transferError):gsub("[\r\n]+", " " ):sub(1, 140))
					end
					-- Re-show after the transfer dispatcher as a defensive measure against
					-- optional console API failures in bank-open processing.
					local showOk, showError = pcall(displayUI, #BMR.Console.GetDefinedProfiles() > 1)
					if not showOk then BMR.ProfileDiagnostic("CONSOLE_PROFILE_UI_RESHOW_FAILED", tostring(showError)) end
				else
					interactWithBank()
				end
				BMR.ProfileDiagnostic("PERSONAL_BANK_AUTOSTART_RETURN", BMR.ProfileDebugSnapshot())
			else
				BMR.ProfileDiagnostic("PERSONAL_BANK_AUTOSTART_SKIPPED", "activeProfileMissingOrAutoTransfertDisabled; " .. BMR.ProfileDebugSnapshot())
			end
		
		else
			BMR.ProfileDiagnostic("PERSONAL_BANK_DELAYED_ABORT", "bank open state was false before transfer could start; " .. BMR.ProfileDebugSnapshot())
		end
	end), (db.profiles[actualProfile].initialWaitInSecs * 1000))
	
end

-- onCloseBank, resets
local function onCloseBank()
		BMR.ProfileDiagnostic("PERSONAL_BANK_CLOSE_HANDLER", BMR.ProfileDebugSnapshot())
		isBanking = false
		activeHouseStorageBagId = nil
		housingAutoRescanPasses = 0
	if pvpMovementTraceActive then
		EVENT_MANAGER:UnregisterForEvent(pvpMovementTraceEventName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
		CustomRuleDebug(string.format("MOVE TRACE STOPPED pendingExpectedMoves=%d", #pvpExpectedMoveTraces))
	end
	pvpMovementTraceActive = false
	pvpMovementTraceBaseline = {}
	pvpExpectedMoveTraces = {}
	rejectedPvpStackTargets = {}
	rejectedOneStackDestinations = {}
	activeTransferVerificationDebug = nil
	activeRuleRunPhase = nil
	profileIconRerunRequested = false
	hasAnyPullToDo = nil
	pushQueue = {}
	pullQueue = {}
	movedItems = {
		[BAG_BACKPACK] = {},
		[BAG_BANK] = {},
		[BAG_SUBSCRIBER_BANK] = {},
	}
	
	inProgress = false	
	BankManager:SetHidden(true)
	
end

local function doInteractionWithGBank()
	
	CustomRuleDebug(string.format("INTERACT GUILD BANK ENTER inProgress=%s phase=%s pushQueue=%d pullQueue=%d checkingGBank=%s currentGuild=%s", tostring(inProgress), tostring(activeRuleRunPhase), #pushQueue, #pullQueue, tostring(checkingGBank), tostring(currentGBankName)))
	if not inProgress then
		inProgress = true
		activeRuleRunPhase = "building"
		BMR.ProfileDebugBeginScan("guild-bank")
		BMR.ProfileDiagnostic("GUILD_BANK_SCAN_ENTRY", BMR.ProfileDebugRuleActionSummary() .. "; " .. BMR.ProfileDebugBagCacheSummary(BAG_BACKPACK) .. "; guild=" .. tostring(currentGBankName))
		
		dataSorted = sortByKeyAndPosition(BankManagerRules.data)
		
		-- Prepare items, check if they must be moved and queue them
		for slotIndex, slotdata in pairs(SHARED_INVENTORY.bagCache[BAG_BACKPACK]) do
			if not movedItems[BAG_BACKPACK][slotIndex] then
				prepareItem(BAG_BACKPACK, slotIndex, checkingGBank)
			end
		end
		
		-- items have been queued
		BMR.ProfileDiagnostic("GUILD_BANK_QUEUES_READY", string.format("push=%d; %s; %s", #pushQueue, BMR.ProfileDebugScanSummary(), BMR.ProfileDebugRuleActionSummary()))
		if #pushQueue > 0 then
			
			--d("Registering events")
			-- This will make the loop, because GBank cannot be looped
			EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GUILD_BANK_TRANSFER_ERROR, function() moveItems(true) end)
			EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GUILD_BANK_ITEM_ADDED, function(_, errorReason) moveItems(true, errorReason) end)
		
			activeRuleRunPhase = "moving"
			moveItems(true)
		else
			BMR.ProfileDiagnostic("GUILD_BANK_NO_QUEUES", BMR.ProfileDebugScanSummary() .. "; " .. BMR.ProfileDebugRuleActionSummary() .. "; guild=" .. tostring(currentGBankName))
			inProgress = false
			CustomRuleDebug("INTERACT GUILD BANK FINISH reason=no transfers queued; resetting inProgress")
			activeRuleRunPhase = nil
		end

	else
		CustomRuleDebug(string.format("INTERACT GUILD BANK BLOCKED reason=inProgress=true phase=%s pushQueue=%d pullQueue=%d", tostring(activeRuleRunPhase), #pushQueue, #pullQueue))
	end
	
end

-- interactWithGBank
local function interactWithGBank()
	BMR.ProfileDiagnostic("GUILD_BANK_INTERACT_BEGIN", "guildId=" .. tostring(currentGBank) .. "; guildName=" .. tostring(currentGBankName) .. "; checkingGBank=" .. tostring(checkingGBank) .. "; " .. BMR.ProfileDebugSnapshot())

	-- The permission is maybe not allowed
	if DoesPlayerHaveGuildPermission(currentGBank, GUILD_PERMISSION_BANK_DEPOSIT) then
		
		local multipleProfiles = false
		
		for i=2, db.profileCount do
			if db.profiles[i].defined == true then
				multipleProfiles = true
				break
			end
		end
		
		-- Keep the central BMR profile icon visible; displayUI hides arrows when there's one profile.
		displayUI(multipleProfiles)
		
		if db.profiles[actualProfile].autoTransfert then
			BMR.ProfileDiagnostic("GUILD_BANK_AUTOSTART_CALL", "permission=true; " .. BMR.ProfileDebugSnapshot())
			doInteractionWithGBank()
			BMR.ProfileDiagnostic("GUILD_BANK_AUTOSTART_RETURN", BMR.ProfileDebugSnapshot())
		else
			BMR.ProfileDiagnostic("GUILD_BANK_AUTOSTART_SKIPPED", "autoTransfert=false; " .. BMR.ProfileDebugSnapshot())
		end
	else
		BMR.ProfileDiagnostic("GUILD_BANK_AUTOSTART_BLOCKED_PERMISSION", "guildId=" .. tostring(currentGBank) .. "; " .. BMR.ProfileDebugSnapshot())
	end
	BMR.ProfileDiagnostic("GUILD_BANK_INTERACT_END", BMR.ProfileDebugSnapshot())
	
end

-- onGuildBankItemsReallyReady
local function onGuildBankItemsReallyReady()
	BMR.ProfileDiagnostic("GUILD_BANK_ITEMS_REALLY_READY", "checkingGBank=" .. tostring(checkingGBank) .. "; " .. BMR.ProfileDebugSnapshot())
	-- Because EVENT_GUILD_BANK_ITEMS_READY fires multiple times
	if not checkingGBank then
		checkingGBank = true
		interactWithGBank()
	else
		BMR.ProfileDiagnostic("GUILD_BANK_ITEMS_READY_IGNORED", "already checking this guild bank; " .. BMR.ProfileDebugSnapshot())
	end
end

-- onGuildBankItemsReady
local function onGuildBankItemsReady()
	BMR.ProfileDiagnostic("GUILD_BANK_ITEMS_READY", "scheduling delayed readiness; " .. BMR.ProfileDebugSnapshot())
	-- Guild bank is evented to be ready, but wait a short while before processing. (multiple readys for big banks ~3/4)
	zo_callLater(BMR.ProfileDebugWrapEvent("GUILD_BANK_DELAYED_READY", onGuildBankItemsReallyReady), (db.profiles[actualProfile].initialWaitInSecs * 1000))
end

-- onGuildBankSelected
local function onGuildBankSelected(_, guildId)
	BMR.ProfileDiagnostic("GUILD_BANK_SELECTED", "guildId=" .. tostring(guildId) .. "; " .. BMR.ProfileDebugSnapshot())
	BankManager:SetHidden(true)
	checkingGBank = false
	currentGBank = guildId
	currentGBankName = GetGuildName(currentGBank)
	if BMR.Console and BMR.Console.IsControllerFlowActive and BMR.Console.IsControllerFlowActive() then
		pcall(function() BMR.Console.RefreshForScene() end)
		zo_callLater(function()
			if currentGBank ~= nil and BMR.Console.IsControllerFlowActive() then
				pcall(function() BMR.Console.RefreshForScene() end)
				if db and db.profiles and type(db.profiles[actualProfile]) == "table" then
					pcall(function() displayUI(BMR.Console.GetDefinedProfiles and #BMR.Console.GetDefinedProfiles() > 1 or false) end)
				end
			end
		end, 150)
	end
	
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_GUILD_BANK_TRANSFER_ERROR)
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_GUILD_BANK_ITEM_ADDED)
	
end

-- onCloseGuildBank
local function onCloseGuildBank()
	BMR.ProfileDiagnostic("GUILD_BANK_CLOSE_HANDLER", BMR.ProfileDebugSnapshot())
	checkingGBank = false
	currentGBank = nil
	currentGBankName = nil
	OnCloseProcessAtGBank()
	BankManager:SetHidden(true)
	
end

-- Resolve a currency display name without assuming the keyboard-flow API exists.
local function GetBmrCurrencyName(currencyType)
	if type(GetCurrencyName) == "function" then
		local ok, value = pcall(GetCurrencyName, currencyType, false, false)
		if ok and value ~= nil and tostring(value) ~= "" then return tostring(value) end
	end
	if type(GetString) == "function" and currencyType ~= nil then
		local ok, value = pcall(GetString, "SI_CURRENCYTYPE", currencyType)
		if ok and value ~= nil and tostring(value) ~= "" then return tostring(value) end
	end
	return "Währung " .. tostring(currencyType or "?")
end

-- Build 1 currency Panel for LAM
local function panelCurrencyPush(ruleName)

	local optionPanel = {
		type = "slider",
		name = GetString(BMR_CURRENCY_PUSH),
		tooltip = GetString(BMR_CURRENCY_PUSH_TOOLTIP),
		min = BankManagerRules.data[ruleName].min,
		max = BankManagerRules.data[ruleName].max,
		step = BankManagerRules.data[ruleName].step,
		getFunc = function() return db.profiles[actualProfile].rules[ruleName].qtyToPush end,
		setFunc = function(newValue) db.profiles[actualProfile].rules[ruleName].qtyToPush = newValue end,
		default = 0,
	}
	
	return optionPanel

end

-- Build 1 currency Panel for LAM
local function panelCurrencyPull(ruleName)

	local optionPanel = {
		type = "slider",
		name = GetString(BMR_CURRENCY_PULL),
		tooltip = GetString(BMR_CURRENCY_PULL_TOOLTIP),
		min = BankManagerRules.data[ruleName].min,
		max = BankManagerRules.data[ruleName].max,
		step = BankManagerRules.data[ruleName].step,
		getFunc = function() return db.profiles[actualProfile].rules[ruleName].qtyToPull end,
		setFunc = function(newValue) db.profiles[actualProfile].rules[ruleName].qtyToPull = newValue end,
		default = 0,
	}
	
	return optionPanel

end

-- Build 1 currency "Keep Nothing currency" for LAM
local function panelCurrencyNothing(ruleName, currencyType)

	local optionPanel = {
		type = "checkbox",
		name = zo_strformat(BMR_CURRENCY_NOTHING, GetBmrCurrencyName(currencyType)),
		tooltip = zo_strformat(BMR_CURRENCY_NOTHING_TOOLTIP, GetBmrCurrencyName(currencyType)),
		getFunc = function() return db.profiles[actualProfile].rules[ruleName].keepNothing end,
		setFunc = function(newValue) db.profiles[actualProfile].rules[ruleName].keepNothing = newValue end,
		default = false,
		disabled = function()
			-- db is not yet initialized
			if not db.profiles[actualProfile].rules[ruleName].qtyToPush then
				return false
			else
				return db.profiles[actualProfile].rules[ruleName].qtyToPush > 0
			end
		end,
	}
	
	return optionPanel

end

-- Build 1 currency "Keep in Bank Instead" for LAM
local function panelCurrencyKeepInBankInstead(ruleName, currencyType)

	local optionPanel = {
		type = "checkbox",
		name = zo_strformat(BMR_CURRENCY_KEEP_IN_BANK, GetString("SI_CURRENCYTYPE", currencyType)),
		tooltip = zo_strformat(BMR_CURRENCY_KEEP_IN_BANK_TOOLTIP, GetString("SI_CURRENCYTYPE", currencyType)),
		getFunc = function() return db.profiles[actualProfile].rules[ruleName].keepInBank end,
		setFunc = function(newValue) db.profiles[actualProfile].rules[ruleName].keepInBank = newValue end,
		default = false,
	}
	
	return optionPanel

end

-- Notify the header summaries immediately when an action selection changes.
local function FireBmrRuleCountRefresh()
	if CALLBACK_MANAGER and CALLBACK_MANAGER.FireCallbacks then
		CALLBACK_MANAGER:FireCallbacks("BMR-RuleCountRefresh")
	end
end

BMR._RuleUi = BMR._RuleUi or {}
function BMR._RuleUi.GetBmrGuildChoices()
	local choices = {{name = GetString(BMR_ACTION_NOTSET), value = GetString(BMR_ACTION_NOTSET), slot = 0}}
	local count = 0
	if type(GetNumGuilds) == "function" and type(GetGuildId) == "function" and type(GetGuildName) == "function" then
		local ok, guildCount = pcall(GetNumGuilds)
		if ok then count = tonumber(guildCount) or 0 end
	end
	for slot = 1, count do
		local okId, guildId = pcall(GetGuildId, slot)
		local guildName
		if okId then
			local nameOk, resolvedName = pcall(GetGuildName, guildId)
			if nameOk then guildName = resolvedName end
		end
		if type(guildName) ~= "string" or guildName == "" then guildName = "Guild " .. tostring(guildId or slot) end
		if okId then choices[#choices + 1] = {name = tostring(slot) .. " - " .. guildName, value = guildName, slot = slot} end
	end
	return choices
end

function BMR._RuleUi.GetBmrGuildSlotLabel(guildName)
	if guildName == nil or guildName == "" or guildName == GetString(BMR_ACTION_NOTSET) then return "-" end
	for _, choice in ipairs(BMR._RuleUi.GetBmrGuildChoices()) do
		if choice.value == guildName then return tostring(choice.slot) end
	end
	return "?"
end

function BMR._RuleUi.GetOrCreateBmrProfileRule(ruleName)
	local profile = db and db.profiles and db.profiles[actualProfile]
	if not profile then profile = EnsureProfile(actualProfile, false) end
	if not profile then return nil end
	profile.rules = profile.rules or {}
	profile.rules[ruleName] = profile.rules[ruleName] or {action = ACTION_NOTSET, associatedGuild = GetString(BMR_ACTION_NOTSET), onlyIfNotFullStack = true, onlyStacks = 1}
	return profile.rules[ruleName]
end

function BMR._RuleUi.SetBmrRuleGuild(ruleName, guildName)
	local rule = BMR._RuleUi.GetOrCreateBmrProfileRule(ruleName)
	if not rule then return end
	rule.associatedGuild = guildName or GetString(BMR_ACTION_NOTSET)
	FireBmrRuleCountRefresh()
end

BMR._RuleUi.RuleActionChoices = {
	{labelId = BMR_ACTION_NOTSET, value = ACTION_NOTSET},
	{labelId = BMR_ACTION_PUSH, value = ACTION_PUSH},
	{labelId = BMR_ACTION_PULL, value = ACTION_PULL},
	{labelId = BMR_ACTION_PUSH_ALL_STACKS, value = ACTION_PUSH_ALL_STACKS},
	{labelId = BMR_ACTION_PULL_ALL_STACKS, value = ACTION_PULL_ALL_STACKS},
	{labelId = BMR_ACTION_PUSH_GBANK, value = ACTION_PUSH_GBANK},
	{labelId = BMR_ACTION_PUSH_BOTH, value = ACTION_PUSH_BOTH},
	{labelId = BMR_ACTION_KEEP_ONE_STACK, value = ACTION_KEEP_ONE_STACK},
	{labelId = BMR_ACTION_KEEP_ONE_STACK_BANK, value = ACTION_KEEP_ONE_STACK_BANK},
	{labelId = BMR_ACTION_PUSH_FURNITURE, value = ACTION_PUSH_FURNITURE},
}

function BMR._RuleUi.GetBmrRuleColumnLayout(width)
	width = math.max(400, tonumber(width) or 585)
	local actionWidth = width * 0.44
	local gap = 8
	-- Keep enough room for a one-digit guild slot and the combo-box arrow.
	local guildWidth = math.max(48, math.min(52, width * 0.08))
	local guildPopupWidth = math.max(92, width * 0.22)
	local guildX = width - guildWidth
	local actionX = guildX - gap - actionWidth
	local labelWidth = math.max(120, actionX - gap)
	return {
		width = width, gap = gap,
		labelWidth = labelWidth, actionWidth = actionWidth, actionX = actionX,
		guildWidth = guildWidth, guildPopupWidth = guildPopupWidth, guildX = guildX,
	}
end

function BMR._RuleUi.LayoutBmrRuleRow(control)
	if not control or not control.bmrItemLabel then return end
	local columns = BMR._RuleUi.GetBmrRuleColumnLayout(control:GetWidth())
	control:SetHeight(40)
	control.bmrItemLabel:ClearAnchors()
	control.bmrItemLabel:SetAnchor(LEFT, control, LEFT, 0, 0)
	control.bmrItemLabel:SetDimensions(columns.labelWidth, 36)
	control.bmrActionContainer:ClearAnchors()
	control.bmrActionContainer:SetAnchor(LEFT, control, LEFT, columns.actionX, 0)
	control.bmrActionContainer:SetDimensions(columns.actionWidth, 28)
	control.bmrActionDropdown.m_containerWidth = columns.actionWidth
	control.bmrGuildContainer:ClearAnchors()
	control.bmrGuildContainer:SetAnchor(RIGHT, control, RIGHT, 0, 0)
	control.bmrGuildContainer:SetDimensions(columns.guildWidth, 28)
	control.bmrGuildDropdown.m_containerWidth = columns.guildPopupWidth
	if control.bmrGuildDropdown.m_dropdown and control.bmrGuildDropdown.m_dropdown.SetWidth then
		control.bmrGuildDropdown.m_dropdown:SetWidth(columns.guildPopupWidth)
	end
end

function BMR._RuleUi.RefreshBmrRuleRow(control, ruleName)
	if not control then return end
	if not control.bmrItemLabel then
		BMR.ruleTableControlSerial = (BMR.ruleTableControlSerial or 0) + 1
		local uniqueId = tostring(BMR.ruleTableControlSerial)
		control.bmrItemLabel = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
		control.bmrItemLabel:SetFont("ZoFontGame")
		control.bmrItemLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
		control.bmrActionContainer = WINDOW_MANAGER:CreateControlFromVirtual("BMRRuleActionCombo_" .. uniqueId, control, "ZO_ComboBox")
		control.bmrActionDropdown = ZO_ComboBox_ObjectFromContainer(control.bmrActionContainer)
		control.bmrActionDropdown:SetSortsItems(false)
		control.bmrGuildContainer = WINDOW_MANAGER:CreateControlFromVirtual("BMRRuleGuildCombo_" .. uniqueId, control, "ZO_ComboBox")
		control.bmrGuildDropdown = ZO_ComboBox_ObjectFromContainer(control.bmrGuildContainer)
		control.bmrGuildDropdown:SetSortsItems(false)
		control.bmrGuildContainer:SetMouseEnabled(true)
		control.bmrGuildContainer:SetHandler("OnMouseEnter", function(self)
			if InformationTooltip and InitializeTooltip then
				InitializeTooltip(InformationTooltip, self, TOPRIGHT, 0, 0)
				if InformationTooltip.AddLine then InformationTooltip:AddLine(GetString(BMR_GUILD_LIST_TOOLTIP)) end
			end
		end)
		control.bmrGuildContainer:SetHandler("OnMouseExit", function() if InformationTooltip and ClearTooltip then ClearTooltip(InformationTooltip) end end)
		control.bmrItemLabel:SetMouseEnabled(true)
		control.bmrItemLabel:SetHandler("OnMouseEnter", function(self)
			local name = control.bmrRuleName
			local data = BankManagerRules and BankManagerRules.data and BankManagerRules.data[name]
			if data and data.tooltip and InformationTooltip and InitializeTooltip then
				InitializeTooltip(InformationTooltip, self, TOPRIGHT, 0, 0)
				InformationTooltip:AddLine(tostring(data.tooltip))
			end
		end)
		control.bmrItemLabel:SetHandler("OnMouseExit", function() if InformationTooltip and ClearTooltip then ClearTooltip(InformationTooltip) end end)
		control:SetHandler("OnSizeChanged", function(self)
			BMR._RuleUi.LayoutBmrRuleRow(self)
		end)
	end
	control.bmrRuleName = ruleName
	local ruleData = BankManagerRules and BankManagerRules.data and BankManagerRules.data[ruleName]
	if not ruleData and not control.bmrRuleDisplayName then control:SetHeight(1); return end
	control.bmrItemLabel:SetText(tostring(control.bmrRuleDisplayName or (ruleData and ruleData.name) or ruleName))
	control.bmrActionDropdown:ClearItems()
	local profileRule = BMR._RuleUi.GetOrCreateBmrProfileRule(ruleName)
	local selectedAction = GetString(BMR_ACTION_NOTSET)
	for _, actionData in ipairs(BMR._RuleUi.RuleActionChoices) do
		local actionLabel = GetString(actionData.labelId)
		local actionValue = actionData.value
		local entry = control.bmrActionDropdown:CreateItemEntry(actionLabel, function()
			local rule = BMR._RuleUi.GetOrCreateBmrProfileRule(control.bmrRuleName)
			if rule then rule.action = actionValue; FireBmrRuleCountRefresh() end
		end)
		control.bmrActionDropdown:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
		if profileRule and tonumber(profileRule.action) == tonumber(actionValue) then selectedAction = actionLabel end
	end
	control.bmrActionDropdown:SetSelectedItem(selectedAction)

	control.bmrGuildDropdown:ClearItems()
	local selectedGuildLabel = "-"
	local selectedGuildName = profileRule and profileRule.associatedGuild
	local selectedGuildItem = GetString(BMR_ACTION_NOTSET)
	for _, guildData in ipairs(BMR._RuleUi.GetBmrGuildChoices()) do
		local label, guildValue, slot = guildData.name, guildData.value, guildData.slot
		local selectedGuildValue, selectedGuildSlot = guildValue, slot
		local entry = control.bmrGuildDropdown:CreateItemEntry(label, function()
			BMR._RuleUi.SetBmrRuleGuild(control.bmrRuleName, selectedGuildValue)
			if control.bmrGuildDropdown.SetSelectedItemText then control.bmrGuildDropdown:SetSelectedItemText(selectedGuildSlot == 0 and "-" or tostring(selectedGuildSlot)) end
		end)
		control.bmrGuildDropdown:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
		if selectedGuildName == guildValue then
			selectedGuildLabel = slot == 0 and "-" or tostring(slot)
			selectedGuildItem = label
		end
	end
	control.bmrGuildDropdown:SetSelectedItem(selectedGuildItem)
	if control.bmrGuildDropdown.SetSelectedItemText then control.bmrGuildDropdown:SetSelectedItemText(selectedGuildLabel) end
	BMR._RuleUi.LayoutBmrRuleRow(control)
end

function BMR._RuleUi.LayoutBmrRuleHeader(control)
	if not control or not control.bmrHeaderLabels then return end
	local columns = BMR._RuleUi.GetBmrRuleColumnLayout(control:GetWidth())
	local labels = control.bmrHeaderLabels
	labels[1]:ClearAnchors(); labels[1]:SetAnchor(LEFT, control, LEFT, 0, 0); labels[1]:SetDimensions(columns.labelWidth, 24)
	labels[2]:ClearAnchors(); labels[2]:SetAnchor(LEFT, control, LEFT, columns.actionX, 0); labels[2]:SetDimensions(columns.actionWidth, 24)
	labels[3]:ClearAnchors(); labels[3]:SetAnchor(RIGHT, control, RIGHT, 0, 0); labels[3]:SetDimensions(columns.guildWidth, 24)
end

function BMR._RuleUi.CreateBmrRuleHeader(control)
	if not control or control.bmrHeaderCreated then return end
	control.bmrHeaderCreated = true
	control:SetHeight(26)
	local function makeLabel(text)
		local label = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
		label:SetFont("ZoFontWinH4")
		label:SetText(text)
		label:SetDimensions(100, 24)
		label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
		return label
	end
	control.bmrHeaderLabels = {
		makeLabel(GetString(BMR_RULE_TABLE_ITEM)),
		makeLabel(GetString(BMR_RULE_TABLE_ACTION)),
		makeLabel(GetString(BMR_GUILD_LIST_SHORT)),
	}
	control.bmrHeaderLabels[3]:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	local guildHeader = control.bmrHeaderLabels[3]
	guildHeader:SetMouseEnabled(true)
	guildHeader:SetHandler("OnMouseEnter", function(self)
		if InformationTooltip and InitializeTooltip then
			InitializeTooltip(InformationTooltip, self, TOPRIGHT, 0, 0)
			if InformationTooltip.AddLine then InformationTooltip:AddLine(GetString(BMR_GUILD_LIST_TOOLTIP)) end
		end
	end)
	guildHeader:SetHandler("OnMouseExit", function() if InformationTooltip and ClearTooltip then ClearTooltip(InformationTooltip) end end)
	BMR._RuleUi.LayoutBmrRuleHeader(control)
	control:SetHandler("OnSizeChanged", function(self) BMR._RuleUi.LayoutBmrRuleHeader(self) end)
end

function BMR._RuleUi.MakeBmrRuleHeaderOption()
	BMR.ruleTableHeaderSerial = (BMR.ruleTableHeaderSerial or 0) + 1
	return {
		type = "custom", reference = "BMRRuleTableHeader_" .. tostring(BMR.ruleTableHeaderSerial),
		width = "full", minHeight = 26, maxHeight = 26,
		createFunc = BMR._RuleUi.CreateBmrRuleHeader, refreshFunc = BMR._RuleUi.CreateBmrRuleHeader,
		bmrRuleTableHeader = true,
	}
end

-- Build 1 optionPanel for LAM
local function panelRule(ruleName)
	if not (BankManagerRules and type(BankManagerRules.data) == "table" and BankManagerRules.data[ruleName]) then
		BMR.ProfileDiagnostic("SETTINGS_RULE_CONTROL_MISSING", tostring(ruleName))
		return {type = "divider", width = "full", bmrMissingRuleName = tostring(ruleName)}
	end
	return {
		type = "custom",
		reference = "BMRRuleRow:" .. tostring(ruleName),
		width = "full", minHeight = 40, maxHeight = 40,
		createFunc = function(control) BMR._RuleUi.RefreshBmrRuleRow(control, ruleName) end,
		refreshFunc = function(control) BMR._RuleUi.RefreshBmrRuleRow(control, ruleName) end,
		bmrRuleName = ruleName,
		bmrRuleTableRow = true,
	}
end

-- Build the "Only if not full stack" optionPanel
local function GetCurrentProfileRule(ruleName)
	local profile = db and db.profiles and db.profiles[actualProfile]
	if not profile then profile = EnsureProfile(actualProfile, false) end
	if not profile then return nil end
	profile.rules = profile.rules or {}
	profile.rules[ruleName] = profile.rules[ruleName] or {action = ACTION_NOTSET, associatedGuild = GetString(BMR_ACTION_NOTSET), onlyIfNotFullStack = true, onlyStacks = 1}
	return profile.rules[ruleName]
end

-- Alliance-wide PvP action. Exact per-item actions take precedence over this setting.
local function panelPvpAllianceAction(alliance, label)
	local ruleName = "pvpAlliance_" .. alliance
	local allianceStringId = ({AD = BMR_PVP_ALLIANCE_AD, EP = BMR_PVP_ALLIANCE_EP, DC = BMR_PVP_ALLIANCE_DC})[alliance]
	local displayName = (label and label ~= " ") and label or GetString(allianceStringId)
	return {
		type = "custom",
		reference = "BMRRuleRow:" .. ruleName,
		width = "full", minHeight = 40, maxHeight = 40,
		createFunc = function(control)
			control.bmrRuleDisplayName = displayName
			BMR._RuleUi.RefreshBmrRuleRow(control, ruleName)
		end,
		refreshFunc = function(control)
			control.bmrRuleDisplayName = displayName
			BMR._RuleUi.RefreshBmrRuleRow(control, ruleName)
		end,
		bmrRuleName = ruleName,
		bmrRuleDisplayName = displayName,
		bmrRuleTableRow = true,
	}
end
-- Build the "Only if not full stack" optionPanel
local function panelOnlyIfNotFullStack(ruleNamePatern, ruleNameToFollow)
	return {
		type = "checkbox", name = GetString(BMR_ONLY_IF_NOT_FULL_STACK), tooltip = GetString(BMR_ONLY_IF_NOT_FULL_STACK_TOOLTIP),
		getFunc = function() local rule = GetCurrentProfileRule(ruleNameToFollow); return rule and rule.onlyIfNotFullStack ~= false or false end,
		setFunc = function(value)
			local profile = db.profiles and db.profiles[actualProfile]; if not profile then return end
			profile.rules = profile.rules or {}
			local patterns = type(ruleNamePatern) == "table" and ruleNamePatern or {ruleNamePatern}
			for optionName, optionData in pairs(profile.rules) do
				if type(optionData) == "table" then
					local matches = false
					for _, pattern in ipairs(patterns) do
						if type(pattern) == "string" and string.find(optionName, pattern) then matches = true; break end
					end
					if matches or (ruleNamePatern == "MiscPvp" and (string.find(optionName, "^pvpItem_") or string.find(optionName, "^pvpAlliance_"))) then optionData.onlyIfNotFullStack = value end
				end
			end
			local rule = GetCurrentProfileRule(ruleNameToFollow); if rule then rule.onlyIfNotFullStack = value end
		end,
		width = "full", default = true,
	}
end

-- Build the "Max Stacks" optionPanel
local function panelMaxStacks(ruleNamePatern, onlyIfNotFullStackToFollow, ruleNameToFollow)
	return {
		type = "slider", name = GetString(BMR_MAX_STACK), tooltip = GetString(BMR_MAX_STACK_TOOLTIP), min = 1, max = 500,
		getFunc = function() local rule = GetCurrentProfileRule(ruleNameToFollow); return tonumber(rule and rule.onlyStacks) or 1 end,
		setFunc = function(value)
			local profile = db.profiles and db.profiles[actualProfile]; if not profile then return end
			profile.rules = profile.rules or {}
			local patterns = type(ruleNamePatern) == "table" and ruleNamePatern or {ruleNamePatern}
			for optionName, optionData in pairs(profile.rules) do
				if type(optionData) == "table" then
					local matches = false
					for _, pattern in ipairs(patterns) do
						if type(pattern) == "string" and string.find(optionName, pattern) then matches = true; break end
					end
					if matches or (ruleNamePatern == "MiscPvp" and (string.find(optionName, "^pvpItem_") or string.find(optionName, "^pvpAlliance_"))) then optionData.onlyStacks = value end
				end
			end
			local rule = GetCurrentProfileRule(ruleNameToFollow); if rule then rule.onlyStacks = value end
		end,
		default = 1,
		disabled = function() local rule = GetCurrentProfileRule(onlyIfNotFullStackToFollow); return rule and rule.onlyIfNotFullStack or false end,
		width = "full",
	}
end

-- List all active guilds
local function listOfActiveGuilds()

	guildList = {GetString(BMR_ACTION_NOTSET)}
	if GetNumGuilds() > 0 then
		for guild = 1, GetNumGuilds() do
			local guildId = GetGuildId(guild)
			local guildName = GetGuildName(guildId)
			if(not guildName or (guildName):len() < 1) then
				guildName = "Guild " .. guildId
			end
			table.insert(guildList, guildName)
		end
	end
	
end

-- Will change the name of the associatedGuild for all rules who match ruleNamePatern
local function panelGuildBank(ruleNamePatern, ruleNameToFollow)
	return {
		type = "dropdown", name = GetString(BMR_GUILD_LIST), tooltip = GetString(BMR_GUILD_LIST_TOOLTIP), choices = guildList or {GetString(BMR_ACTION_NOTSET)},
		getFunc = function() local rule = GetCurrentProfileRule(ruleNameToFollow); return rule and rule.associatedGuild or GetString(BMR_ACTION_NOTSET) end,
		setFunc = function(value)
			local profile = db.profiles and db.profiles[actualProfile]; if not profile then return end
			profile.rules = profile.rules or {}
			local patterns = type(ruleNamePatern) == "table" and ruleNamePatern or {ruleNamePatern}
			for optionName, optionData in pairs(profile.rules) do
				if type(optionData) == "table" then
					local matches = false
					for _, pattern in ipairs(patterns) do
						if type(pattern) == "string" and string.find(optionName, pattern) then matches = true; break end
					end
					if ruleNamePatern == "MiscPvp" and (string.find(optionName, "^pvpItem_") or string.find(optionName, "^pvpAlliance_")) then matches = true end
					if matches then optionData.associatedGuild = value end
				end
			end
			local rule = GetCurrentProfileRule(ruleNameToFollow); if rule then rule.associatedGuild = value end
		end,
		width = "half", default = GetString(BMR_ACTION_NOTSET),
		bmrLegacyGroupGuildBank = true,
		bmrGuildPattern = ruleNamePatern,
		bmrGuildMasterRule = ruleNameToFollow,
	}
end

local function panelSpecialFilter(ruleName)
	local specialConvert = {
		writsQuests = {writsQuests = true, writsQuestsGlyphs = true, writsQuestsPots = true}
	}
	local ruleData = BankManagerRules and BankManagerRules.data and BankManagerRules.data[ruleName]
	if type(ruleData) ~= "table" then
		BMR.ProfileDiagnostic("SPECIAL_FILTER_RULE_MISSING", tostring(ruleName))
		return nil
	end
	local optionPanel = {
		type = "checkbox",
		name = ruleData.name or tostring(ruleName),
		tooltip = ruleData.tooltip or ruleData.name or tostring(ruleName),
		getFunc = function()
			local rule = GetCurrentProfileRule(ruleName)
			return rule and rule.specialEnabled == true or false
		end,
		setFunc = function(newValue)
			local profile = db.profiles and db.profiles[actualProfile]
			if not profile then return end
			profile.rules = profile.rules or {}
			local rule = GetCurrentProfileRule(ruleName)
			if rule then rule.specialEnabled = newValue == true end
			for ruleNameToFollow, rulesData in pairs(specialConvert) do
				if ruleNameToFollow == ruleName and type(rulesData) == "table" then
					for realRule in pairs(rulesData) do
						local childRule = GetCurrentProfileRule(realRule)
						if childRule then
							childRule.action = newValue and ACTION_PULL or ACTION_NOTSET
							childRule.specialEnabled = newValue == true
						end
					end
				end
			end
		end,
		default = false,
	}
	return optionPanel
end

local function Explode(div, str)
	if div == "" then return false end
	local pos,arr = 0,{}
	for st,sp in function() return string.find(str,div,pos,true) end do
		table.insert(arr,string.sub(str,pos,st-1))
		pos = sp + 1
	end
	table.insert(arr,string.sub(str,pos))
	return arr
end

local BMR_RULEWRITER_VALUE_SPECIAL_KEYWORD = "acceptOptionalParam"
local BMR_RULEWRITER_VALUE_WITH_OPERATOR = "requireParamWithOperator"

local function GetValuesForCondition(keywordCondition, values, arg1, arg2)

	local acceptedValues = keywordCondition[values]
	
	if acceptedValues == BMR_RULEWRITER_VALUE_WITHOUT_OPERATOR then
		local numberConverted = tonumber(arg2)
		if type(numberConverted) == "number" and numberConverted >= 1 and numberConverted <= 10000 then
			return true, numberConverted
		end
	elseif acceptedValues == BMR_RULEWRITER_VALUE_NOTHING then
		if not arg1 and not arg2 then
			return true, "xxx"
		end
	elseif acceptedValues == BMR_RULEWRITER_VALUE_OPTIONAL_KEYWORD then
		if keywordCondition.acceptedKeyword[arg1] then
			return true, "xxx"
		end
	elseif acceptedValues == BMR_RULEWRITER_VALUE_WITH_OPERATOR then
		if keywordCondition.acceptedKeyword[arg1] then
			return true, "xxx"
		end
	end

end

local function IsValidRuleWriterOperator(rawOperator)
	if rawOperator == "<" or rawOperator == ">" or rawOperator == "<=" or rawOperator == ">=" or rawOperator == "==" or rawOperator == "~=" then
		return true
	end
end

local function GetRuleWriterFuncForMainKeyword(keywordCondition)
	return keywordCondition.func
end

local function GetRuleWriterArgsForMainKeyword(keywordCondition)
	return keywordCondition.args
end

local function GetRuleWriterCondition(conditionTable)

	local mainKeyword = string.lower(conditionTable[1])
	local keywordCondition = BankManagerRules.keywordConditionTable[mainKeyword]

	local conditionData
	
	if keywordCondition then
		
		if keywordCondition[BMR_RULEWRITER_VALUE_WITH_OPERATOR] then
			
			local rawOperator = conditionTable[2]
			local rawValues = conditionTable[3]
			
			if IsValidRuleWriterOperator(rawOperator) and rawValues then
				local isValidValuesForCondition, builtValues = GetValuesForCondition(keywordCondition, BMR_RULEWRITER_VALUE_WITH_OPERATOR, rawOperator, rawValues)
				if isValidValuesForCondition then
					conditionData = {	func = GetRuleWriterFuncForMainKeyword(keywordCondition), funcArgs = GetRuleWriterArgsForMainKeyword(keywordCondition), operator = rawOperator, values = builtValues }
				end
			end
		end
		
	end
	
	return conditionData
					
end

local function EvaluateRuleWriterParams(paramString)
	
	local conditions = Explode("+", paramString)
	
	if #conditions >= 1 then
	
		local validParams = {}
		
		for conditionIndex, conditionData in ipairs(conditions) do
			local conditionText = string.gsub(conditionData,"^%s*(.-)%s*$", "%1")
			local conditionKeywords = Explode(" ", conditionText)
			local isValidCondition, params = GetRuleWriterCondition(conditionKeywords)
			if isValidCondition then
				table.insert(validParams, params)
			else
				return
			end
			
		end
		
		return validParams
		
	end

end

local function EvaluateRuleWriterAction(actionString)

end

local function AddRuleToUserList(params, action)
	
	local ruleName = GenerateRuleShortNameFromParams(params)
	
	BankManagerRules.data[ruleName] = {
		params = { params },
		action = { action },
		name = GenerateRuleLongNameFromParams(params),
	}

end

local function CheckAndAddRule(ruleString, fromLAM)
	
	local lines = Explode("\n", ruleString) -- Only line 1
	local newRule = lines[1]
	
	local line = Explode("=", newRule) -- Check presence of the result
	
	if line[1] and line[2] and not line[3] then
	
		local isParameterValid, params = EvaluateRuleWriterParams(line[1])
		local isActionValid, action = EvaluateRuleWriterAction(line[2])
		
		if isParameterValid and isActionValid then
			AddRuleToUserList(params, action)
		end
		
	else
		db.userRule = "" -- Strip the text
	end
	
	if lamCall then
		CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)
	end
		
end

-- Build the Rule Writer engine. it permit to the user to write its own rules
local function RuleWriterPanel()

	local optionPanel = {
		{
			type = "header",
			name = GetString(BMR_RULE_WRITER),
			width = "full",
		},
		{
			type = "description",
			text = GetString(BMR_RULE_WRITER_DESC),
			width = "full",
		}
	}
	
	local correctUserRules = {}
	for correctUserRuleIndex, correctUserRuleData in ipairs(correctUserRules) do
		table.insert(optionPanel, correctUserRuleData)
	end
	
	table.insert(optionPanel,
	{
		type = "editbox",
		name = GetString(BMR_RULE_WRITER_ADDNEWRULE),
		tooltip = GetString(BMR_RULE_WRITER_ADDNEWRULE_TOOLTIP),
		isMultiline = true,
		isExtraWide = true,
		getFunc = function() return db.userRule end,
		setFunc = function(newValue)
			CheckAndAddRule(newValue, true) -- Rebuild the control if data is invalid
		end,
		width = "full",
		default = "",
	})
	
	table.insert(optionPanel,
	{
		type = "checkbox",
		name = GetString(BMR_RULE_WRITER_RUNAFTER),
		tooltip = GetString(BMR_RULE_WRITER_RUNAFTER_TOOLTIP),
		getFunc = function() return db.profiles[actualProfile].userRulesAfter end,
		setFunc = function(value)
			db.profiles[actualProfile].userRulesAfter = value
		end,
		width = "full",
		default = false,
	})
	
	return optionPanel

end

-- Custom-rule list controls are implemented in BankManagerCustomRules.lua.

-- Custom-filter editor and list controls are implemented in BankManagerCustomRules.lua.

-- Exact custom-item list control is implemented in BankManagerCustomRules.lua.

-- PvP diagnostic: list siege items currently visible in the character's bags.
-- This does not enumerate ESO's entire item database; it reports matching items
-- found in backpack/bank containers so their item IDs and link payloads can be collected.
local function DebugDumpPvpSiegeItems()
	local categories = {
		{key = "Ballisten", terms = {"balliste", "ballista"}},
		{key = "Tribok", terms = {"tribok", "trebuchet"}},
		{key = "Katapult", terms = {"katapult", "catapult"}},
		{key = "Lancier", terms = {"lancier", "lancer"}},
		{key = "Öl", terms = {"brandöl", "belagerungsöl", "siege oil", "oil"}},
		{key = "Feldlager", terms = {"feldlager", "forward camp"}},
		{key = "Rammbock", terms = {"rammbock", "battering ram"}},
	}
	local specialLancierIds = {[160528]=true,[160529]=true,[160530]=true,[160531]=true,[160532]=true,[160533]=true,[160534]=true,[160535]=true,[160536]=true}
	local bags = {
		{ id = BAG_BACKPACK, name = "Inventar" },
		{ id = BAG_BANK, name = "Bank" },
		{ id = BAG_SUBSCRIBER_BANK, name = "ESO+-Bank" },
	}
	if BAG_GUILDBANK ~= nil then table.insert(bags, {id = BAG_GUILDBANK, name = "Gildenbank"}) end

	local found = {}
	local function classify(name)
		local lower = zo_strlower(tostring(name or ""))
		for _, category in ipairs(categories) do
			for _, term in ipairs(category.terms) do
				if string.find(lower, term, 1, true) then return category.key end
			end
		end
		return "Sonstige Belagerung"
	end
	local function safeBagSize(bagId)
		local ok, size = pcall(GetBagSize, bagId)
		if ok then return tonumber(size) or 0 end
		return 0
	end

	for _, bag in ipairs(bags) do
		local size = safeBagSize(bag.id)
		for slot = 0, size - 1 do
			local ok, itemLink = pcall(GetItemLink, bag.id, slot)
			if ok and itemLink and itemLink ~= "" then
				local itemId = GetItemLinkItemId(itemLink)
				local itemType, specializedItemType = GetItemLinkItemType(itemLink)
				local name = GetItemLinkName(itemLink) or "?"
				-- Siege is the reliable category gate. The known excavation Lancier
				-- IDs are also included in case ESO assigns them a different item type.
				if itemType == ITEMTYPE_SIEGE or specialLancierIds[itemId] then
					local payload = string.match(itemLink, "|H%d:item:([^|]+)|h") or "UNPARSED"
					local key = tostring(itemId) .. "|" .. payload
					local entry = found[key]
					if not entry then
						entry = {
							itemId = tonumber(itemId) or 0, name = name, link = itemLink,
							category = classify(name), itemType = itemType,
							specializedItemType = specializedItemType,
							specializedType = specializedItemType or "n/a",
							payload = payload, stackCount = 0, locations = {},
						}
						found[key] = entry
					end
					local stack = GetSlotStackSize(bag.id, slot) or 0
					entry.stackCount = entry.stackCount + stack
					table.insert(entry.locations, bag.name .. ":" .. tostring(slot) .. "x" .. tostring(stack))
				end
			end
		end
	end

	local list = {}
	for _, entry in pairs(found) do table.insert(list, entry) end
	table.sort(list, function(a, b)
		if a.category ~= b.category then return a.category < b.category end
		if a.itemId ~= b.itemId then return a.itemId < b.itemId end
		return a.payload < b.payload
	end)
	d("[BMR PvP DEBUG] Belagerungsausrüstung: " .. tostring(#list) .. " unterschiedliche Varianten in zugänglichen Taschen gefunden.")
	if #list == 0 then
		d("[BMR PvP DEBUG] Keine passenden Gegenstände gefunden. Öffne ggf. Bank/Gildenbank und führe den Scan erneut aus.")
		return
	end
	local lastCategory
	for _, entry in ipairs(list) do
		if entry.category ~= lastCategory then
			lastCategory = entry.category
			d("[BMR PvP DEBUG] === " .. lastCategory .. " ===")
		end
		d(string.format("[BMR PvP DEBUG] ID=%d name=%s itemType=%s specialized=%s stackTotal=%d locations=%s linkPayload=%s link=%s",
			entry.itemId, tostring(entry.name), tostring(entry.itemType), tostring(entry.specializedItemType),
			entry.stackCount, table.concat(entry.locations, ","), tostring(entry.payload), tostring(entry.link)))
	end
	d("[BMR PvP DEBUG] Ende. Bitte Chat-Log ab diesem Header kopieren; linkPayload enthält die Item-Link-Felder.")
end

-- PvP diagnostic: ask the optional Item Finder addon to enumerate siege item IDs
-- that are not necessarily present in the player's inventory or bank.
-- Prefer ESO's specialized item type over localized item names. This avoids
-- misclassifying localized/renamed variants such as Flammendes Öl der Vergeltung.
local function PvpClassifyItemName(name, specializedItemType)
	local specialized = tonumber(specializedItemType)
	local specializedCategories = {
		[400] = "Tribok",
		[401] = "Ballisten",
		[402] = "Rammbock",
		[404] = "Katapult",
		[405] = "Feldlager",
		[406] = "Söldnerverträge",
		[407] = "Öl",
		[409] = "Lancier",
	}
	if specializedCategories[specialized] then return specializedCategories[specialized] end

	local lower = zo_strlower(tostring(name or ""))
	if string.find(lower, "balliste", 1, true) or string.find(lower, "ballista", 1, true) then return "Ballisten" end
	if string.find(lower, "tribok", 1, true) or string.find(lower, "trebuchet", 1, true) then return "Tribok" end
	if string.find(lower, "katapult", 1, true) or string.find(lower, "catapult", 1, true) then return "Katapult" end
	if string.find(lower, "lancier", 1, true) or string.find(lower, "lancer", 1, true) then return "Lancier" end
	if string.find(lower, "öl", 1, true) or string.find(lower, "oil", 1, true) then return "Öl" end
	if string.find(lower, "feldlager", 1, true) or string.find(lower, "forward camp", 1, true) then return "Feldlager" end
	if string.find(lower, "rammbock", 1, true) or string.find(lower, "battering ram", 1, true) then return "Rammbock" end
	return "Sonstige Belagerung"
end

local function PvpAllianceHint(name, specializedItemType)
	local lower = zo_strlower(tostring(name or ""))
	if string.find(lower, "pakt-", 1, true) or string.find(lower, "pact-", 1, true) or string.find(lower, "pact ", 1, true) then return "EP" end
	if string.find(lower, "dominion-", 1, true) or string.find(lower, "dominion ", 1, true) then return "AD" end
	if string.find(lower, "bündnis-", 1, true) or string.find(lower, "covenant-", 1, true) or string.find(lower, "covenant ", 1, true) then return "DC" end
	if tonumber(specializedItemType) == 407 or string.find(lower, "brandöl", 1, true) or string.find(lower, "belagerungsöl", 1, true) or string.find(lower, "siege oil", 1, true) then return "fraktionsunabhängig" end
	return "nicht erkannt"
end

local function DebugDumpPvpItemFinderResults(entries)
	if type(entries) ~= "table" then
		d("[BMR PvP DATABASE] ItemFinder lieferte keine gültige Ergebnisliste.")
		return
	end
	table.sort(entries, function(a, b)
		local ca, cb = PvpClassifyItemName(a.name, a.specializedItemType), PvpClassifyItemName(b.name, b.specializedItemType)
		if ca ~= cb then return ca < cb end
		if (tonumber(a.itemId) or 0) ~= (tonumber(b.itemId) or 0) then return (tonumber(a.itemId) or 0) < (tonumber(b.itemId) or 0) end
		return tostring(a.payload or "") < tostring(b.payload or "")
	end)
	d("[BMR PvP DATABASE] ItemFinder-Datenbanksuche abgeschlossen: " .. tostring(#entries) .. " passende Gegenstands-IDs/Varianten.")
	d("[BMR PvP DATABASE] Felder: Kategorie | Allianz-Hinweis | ID | Name | itemType | specializedType | maxStack | level | CP | value | linkPayload | Link")
	local index = 1
	local eventName = "BMR_PvPDatabaseDumpOutput"
	EVENT_MANAGER:UnregisterForUpdate(eventName)
	EVENT_MANAGER:RegisterForUpdate(eventName, 100, function()
		local last = math.min(index + 2, #entries)
		while index <= last do
			local e = entries[index]
			d(string.format("[BMR PvP DATABASE] %s | %s | ID=%s | name=%s | itemType=%s | specializedType=%s | maxStack=%s | level=%s | CP=%s | value=%s | linkPayload=%s | link=%s",
				tostring(PvpClassifyItemName(e.name, e.specializedItemType)), tostring(PvpAllianceHint(e.name, e.specializedItemType)), tostring(e.itemId), tostring(e.name),
				tostring(e.itemType), tostring(e.specializedItemType), tostring(e.maxStack), tostring(e.requiredLevel),
				tostring(e.requiredChampionPoints), tostring(e.value), tostring(e.payload), tostring(e.link)))
			index = index + 1
		end
		if index > #entries then
			d("[BMR PvP DATABASE] Ende der Datenbanksuche.")
			EVENT_MANAGER:UnregisterForUpdate(eventName)
		end
	end)
end

local function DebugScanPvpItemFinderDatabase()
	local finder = _G.ItemFinder
	if not finder or type(finder.ScanForBMRPvPItems) ~= "function" then
		d("[BMR PvP DATABASE] ItemFinder nicht gefunden oder nicht kompatibel. Installiere die mitgelieferte ItemFinder-1.32-Erweiterung und lade UI neu. Der normale Taschen-Scan bleibt verfügbar.")
		return
	end
	d("[BMR PvP DATABASE] Starte langsame Item-ID-Suche über ItemFinder. Sie läuft in kleinen Abschnitten; bitte warten und währenddessen keine zweite Suche starten.")
	local ok, err = pcall(finder.ScanForBMRPvPItems, DebugDumpPvpItemFinderResults)
	if not ok then d("[BMR PvP DATABASE] Start fehlgeschlagen: " .. tostring(err)) end
end

-- Build a LAM SubMenu with a list of filters
local function LAMSubmenu(subMenu)

	local submenuControls = {}
	
	if subMenu == "currencies" then
		
		table.insert(submenuControls, {type = "description", text = zo_strformat("<<1>> :", GetBmrCurrencyName(CURT_MONEY))})
		table.insert(submenuControls, panelCurrencyPush("currency" .. CURT_MONEY))
		table.insert(submenuControls, panelCurrencyPull("currency" .. CURT_MONEY))
		table.insert(submenuControls, panelCurrencyNothing("currency" .. CURT_MONEY, CURT_MONEY))
		table.insert(submenuControls, panelCurrencyKeepInBankInstead("currency" .. CURT_MONEY, CURT_MONEY))
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		
		table.insert(submenuControls, {type = "description", text = zo_strformat("<<1>> :", GetBmrCurrencyName(CURT_TELVAR_STONES))})
		table.insert(submenuControls, panelCurrencyPush("currency" .. CURT_TELVAR_STONES))
		table.insert(submenuControls, panelCurrencyPull("currency" .. CURT_TELVAR_STONES))
		table.insert(submenuControls, panelCurrencyNothing("currency" .. CURT_TELVAR_STONES, CURT_TELVAR_STONES))
		table.insert(submenuControls, panelCurrencyKeepInBankInstead("currency" .. CURT_TELVAR_STONES, CURT_TELVAR_STONES))
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		
		table.insert(submenuControls, {type = "description", text = zo_strformat("<<1>> :", GetBmrCurrencyName(CURT_ALLIANCE_POINTS))})
		table.insert(submenuControls, panelCurrencyPush("currency" .. CURT_ALLIANCE_POINTS))
		table.insert(submenuControls, panelCurrencyPull("currency" .. CURT_ALLIANCE_POINTS))
		table.insert(submenuControls, panelCurrencyNothing("currency" .. CURT_ALLIANCE_POINTS, CURT_ALLIANCE_POINTS))
		table.insert(submenuControls, panelCurrencyKeepInBankInstead("currency" .. CURT_ALLIANCE_POINTS, CURT_ALLIANCE_POINTS))
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		
		table.insert(submenuControls, {type = "description", text = zo_strformat("<<1>> :", GetBmrCurrencyName(CURT_WRIT_VOUCHERS))})
		table.insert(submenuControls, panelCurrencyPush("currency" .. CURT_WRIT_VOUCHERS))
		table.insert(submenuControls, panelCurrencyPull("currency" .. CURT_WRIT_VOUCHERS))
		table.insert(submenuControls, panelCurrencyNothing("currency" .. CURT_WRIT_VOUCHERS, CURT_WRIT_VOUCHERS))
		table.insert(submenuControls, panelCurrencyKeepInBankInstead("currency" .. CURT_WRIT_VOUCHERS, CURT_WRIT_VOUCHERS))
	
	-- Traits
	elseif subMenu == "traits" and db.globalAddonProfile >= 3 then
		
		-- Adding our toplevel LAM controls
		table.insert(submenuControls, panelOnlyIfNotFullStack("trait", "traitAll"))
		table.insert(submenuControls, panelGuildBank("trait", "traitGBank"))
		
		table.insert(submenuControls, panelMaxStacks("trait", "traitAll", "traitStacks"))
		table.insert(submenuControls, panelRule("traitAll"))
		
		-- Horizontal Divider
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		
		-- Courtesy of Dustman (Garkin)
		for traitItemIndex = 1, GetNumSmithingTraitItems() do
			local traitType, itemName = GetSmithingTraitItemInfo(traitItemIndex)
			local itemLink = GetSmithingTraitItemLink(traitItemIndex, LINK_STYLE_DEFAULT)
			local itemType = GetItemLinkItemType(itemLink)
			if itemType ~= ITEMTYPE_NONE and traitType ~= ITEM_TRAIT_TYPE_NONE then
				table.insert(submenuControls, panelRule("trait" .. traitType))
			end
		end
		
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		for traitId, data in pairs(BankManagerRules.static.jewelrycraftingRawTraits) do
			table.insert(submenuControls, panelRule("jewelTraitRaw" .. traitId))
		end
	
	-- Styles
	elseif subMenu == "styles" and db.globalAddonProfile >= 3 then
	
		table.insert(submenuControls, panelOnlyIfNotFullStack("style", "styleAll"))
		table.insert(submenuControls, panelGuildBank("style", "styleGBank"))
		
		table.insert(submenuControls, panelMaxStacks("style", "styleAll", "styleStacks"))
		table.insert(submenuControls, panelRule("styleAll"))
		
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		for styleId, data in pairs(BankManagerRules.static.rawStyles) do
			table.insert(submenuControls, panelRule("styleRaw" .. styleId))
		end
		
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		for stylesItemIndex = 1, GetNumSmithingStyleItems() do
			local _, _, _, meetsUsageRequirement, itemStyle = GetSmithingStyleItemInfo(stylesItemIndex)
			if meetsUsageRequirement and itemStyle ~= ITEMSTYLE_UNIVERSAL then
				table.insert(submenuControls, panelRule("style" .. itemStyle))
			end
		end
	
	-- Blacksmithing
	elseif subMenu == "blacksmithing" and db.globalAddonProfile >= 2 then
		-- Blacksmithing equipment controls (weapons + heavy armor), matching the woodworking layout.
		if db.globalAddonProfile == 2 or db.globalAddonProfile == 4 then
			table.insert(submenuControls, panelOnlyIfNotFullStack({
				"armorTypeWeight" .. ARMORTYPE_HEAVY,
				"armorTypeTrait" .. ITEM_TRAIT_TYPE_ARMOR_INTRICATE .. "Weight" .. ARMORTYPE_HEAVY,
				"armorTypeResearchableWeight" .. ARMORTYPE_HEAVY,
				"weaponType" .. CRAFTING_TYPE_BLACKSMITHING,
				"weaponTypeResearchable" .. CRAFTING_TYPE_BLACKSMITHING,
			}, "blacksmithingEquipmentAll" .. CRAFTING_TYPE_BLACKSMITHING))
			table.insert(submenuControls, panelGuildBank({
				"armorTypeWeight" .. ARMORTYPE_HEAVY,
				"armorTypeTrait" .. ITEM_TRAIT_TYPE_ARMOR_INTRICATE .. "Weight" .. ARMORTYPE_HEAVY,
				"armorTypeResearchableWeight" .. ARMORTYPE_HEAVY,
				"weaponType" .. CRAFTING_TYPE_BLACKSMITHING,
				"weaponTypeResearchable" .. CRAFTING_TYPE_BLACKSMITHING,
			}, "weaponType" .. CRAFTING_TYPE_BLACKSMITHING))
			table.insert(submenuControls, panelMaxStacks({
				"armorTypeWeight" .. ARMORTYPE_HEAVY,
				"armorTypeTrait" .. ITEM_TRAIT_TYPE_ARMOR_INTRICATE .. "Weight" .. ARMORTYPE_HEAVY,
				"armorTypeResearchableWeight" .. ARMORTYPE_HEAVY,
				"weaponType" .. CRAFTING_TYPE_BLACKSMITHING,
				"weaponTypeResearchable" .. CRAFTING_TYPE_BLACKSMITHING,
			}, "blacksmithingEquipmentAll" .. CRAFTING_TYPE_BLACKSMITHING, "blacksmithingEquipmentStacks" .. CRAFTING_TYPE_BLACKSMITHING))
			table.insert(submenuControls, panelRule("armorTypeWeight" .. ARMORTYPE_HEAVY))
			table.insert(submenuControls, panelRule("armorTypeTrait" .. ITEM_TRAIT_TYPE_ARMOR_INTRICATE .. "Weight" .. ARMORTYPE_HEAVY))
			table.insert(submenuControls, panelRule("armorTypeResearchableWeight" .. ARMORTYPE_HEAVY))
			table.insert(submenuControls, panelRule("weaponType" .. CRAFTING_TYPE_BLACKSMITHING))
			table.insert(submenuControls, panelRule("weaponType" .. CRAFTING_TYPE_BLACKSMITHING .. "Trait" .. ITEM_TRAIT_TYPE_WEAPON_INTRICATE))
			table.insert(submenuControls, panelRule("weaponTypeResearchable" .. CRAFTING_TYPE_BLACKSMITHING))
			table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		end
		if db.globalAddonProfile >= 3 then
			-- Improvement-material controls are deliberately between equipment and ordinary materials.
			table.insert(submenuControls, panelOnlyIfNotFullStack("improvement" .. CRAFTING_TYPE_BLACKSMITHING, "improvementAll" .. CRAFTING_TYPE_BLACKSMITHING))
			table.insert(submenuControls, panelGuildBank("improvement" .. CRAFTING_TYPE_BLACKSMITHING, "improvementGBank" .. CRAFTING_TYPE_BLACKSMITHING))
			table.insert(submenuControls, panelMaxStacks("improvement" .. CRAFTING_TYPE_BLACKSMITHING, "improvementAll" .. CRAFTING_TYPE_BLACKSMITHING, "improvementStacks" .. CRAFTING_TYPE_BLACKSMITHING))
			for improvementItemIndex = 1, GetNumSmithingImprovementItems() do
				table.insert(submenuControls, panelRule("improvement" .. CRAFTING_TYPE_BLACKSMITHING .. improvementItemIndex))
			end
			table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
			table.insert(submenuControls, panelOnlyIfNotFullStack("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_BLACKSMITHING, "MaterialAll" .. CRAFTING_TYPE_BLACKSMITHING))
			table.insert(submenuControls, panelGuildBank("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_BLACKSMITHING, "MaterialGBank" .. CRAFTING_TYPE_BLACKSMITHING))
			table.insert(submenuControls, panelMaxStacks("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_BLACKSMITHING, "MaterialAll" .. CRAFTING_TYPE_BLACKSMITHING, "MaterialStacks" .. CRAFTING_TYPE_BLACKSMITHING))
			table.insert(submenuControls, panelRule("MaterialAll" .. CRAFTING_TYPE_BLACKSMITHING))
			table.insert(submenuControls, panelRule("refinedMaterialAll" .. CRAFTING_TYPE_BLACKSMITHING))
			table.insert(submenuControls, panelRule("rawMaterialAll" .. CRAFTING_TYPE_BLACKSMITHING))
			for materialIndex = 1, #BankManagerRules.static.refinedMaterial[CRAFTING_TYPE_BLACKSMITHING] do
				if BankManagerRules.static.refinedMaterial[CRAFTING_TYPE_BLACKSMITHING][materialIndex] ~= "" then
					table.insert(submenuControls, panelRule("refinedMaterial" .. CRAFTING_TYPE_BLACKSMITHING .. materialIndex))
				end
				if BankManagerRules.static.rawMaterial[CRAFTING_TYPE_BLACKSMITHING][materialIndex] ~= "" then
					table.insert(submenuControls, panelRule("rawMaterial" .. CRAFTING_TYPE_BLACKSMITHING .. materialIndex))
				end
			end
		end
	-- Clothier
	elseif subMenu == "clothier" and db.globalAddonProfile >= 2 then
		-- Clothing equipment controls (light + medium armor), separate from improvement materials.
		if db.globalAddonProfile == 2 or db.globalAddonProfile == 4 then
			table.insert(submenuControls, panelOnlyIfNotFullStack({
				"armorTypeWeight" .. ARMORTYPE_LIGHT,
				"armorTypeTrait" .. ITEM_TRAIT_TYPE_ARMOR_INTRICATE .. "Weight" .. ARMORTYPE_LIGHT,
				"armorTypeResearchableWeight" .. ARMORTYPE_LIGHT,
				"armorTypeWeight" .. ARMORTYPE_MEDIUM,
				"armorTypeTrait" .. ITEM_TRAIT_TYPE_ARMOR_INTRICATE .. "Weight" .. ARMORTYPE_MEDIUM,
				"armorTypeResearchableWeight" .. ARMORTYPE_MEDIUM,
			}, "clothierEquipmentAll" .. CRAFTING_TYPE_CLOTHIER))
			table.insert(submenuControls, panelGuildBank({
				"armorTypeWeight" .. ARMORTYPE_LIGHT,
				"armorTypeTrait" .. ITEM_TRAIT_TYPE_ARMOR_INTRICATE .. "Weight" .. ARMORTYPE_LIGHT,
				"armorTypeResearchableWeight" .. ARMORTYPE_LIGHT,
				"armorTypeWeight" .. ARMORTYPE_MEDIUM,
				"armorTypeTrait" .. ITEM_TRAIT_TYPE_ARMOR_INTRICATE .. "Weight" .. ARMORTYPE_MEDIUM,
				"armorTypeResearchableWeight" .. ARMORTYPE_MEDIUM,
			}, "armorTypeWeight" .. ARMORTYPE_LIGHT))
			table.insert(submenuControls, panelMaxStacks({
				"armorTypeWeight" .. ARMORTYPE_LIGHT,
				"armorTypeTrait" .. ITEM_TRAIT_TYPE_ARMOR_INTRICATE .. "Weight" .. ARMORTYPE_LIGHT,
				"armorTypeResearchableWeight" .. ARMORTYPE_LIGHT,
				"armorTypeWeight" .. ARMORTYPE_MEDIUM,
				"armorTypeTrait" .. ITEM_TRAIT_TYPE_ARMOR_INTRICATE .. "Weight" .. ARMORTYPE_MEDIUM,
				"armorTypeResearchableWeight" .. ARMORTYPE_MEDIUM,
			}, "clothierEquipmentAll" .. CRAFTING_TYPE_CLOTHIER, "clothierEquipmentStacks" .. CRAFTING_TYPE_CLOTHIER))
			table.insert(submenuControls, panelRule("armorTypeWeight" .. ARMORTYPE_LIGHT))
			table.insert(submenuControls, panelRule("armorTypeTrait" .. ITEM_TRAIT_TYPE_ARMOR_INTRICATE .. "Weight" .. ARMORTYPE_LIGHT))
			table.insert(submenuControls, panelRule("armorTypeResearchableWeight" .. ARMORTYPE_LIGHT))
			table.insert(submenuControls, panelRule("armorTypeWeight" .. ARMORTYPE_MEDIUM))
			table.insert(submenuControls, panelRule("armorTypeTrait" .. ITEM_TRAIT_TYPE_ARMOR_INTRICATE .. "Weight" .. ARMORTYPE_MEDIUM))
			table.insert(submenuControls, panelRule("armorTypeResearchableWeight" .. ARMORTYPE_MEDIUM))
			table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		end
		if db.globalAddonProfile >= 3 then
			table.insert(submenuControls, panelOnlyIfNotFullStack("improvement" .. CRAFTING_TYPE_CLOTHIER, "improvementAll" .. CRAFTING_TYPE_CLOTHIER))
			table.insert(submenuControls, panelGuildBank("improvement" .. CRAFTING_TYPE_CLOTHIER, "improvementGBank" .. CRAFTING_TYPE_CLOTHIER))
			table.insert(submenuControls, panelMaxStacks("improvement" .. CRAFTING_TYPE_CLOTHIER, "improvementAll" .. CRAFTING_TYPE_CLOTHIER, "improvementStacks" .. CRAFTING_TYPE_CLOTHIER))
			for improvementItemIndex = 1, GetNumSmithingImprovementItems() do
				table.insert(submenuControls, panelRule("improvement" .. CRAFTING_TYPE_CLOTHIER .. improvementItemIndex))
			end
			table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
			table.insert(submenuControls, panelOnlyIfNotFullStack("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_CLOTHIER, "MaterialAll" .. CRAFTING_TYPE_CLOTHIER))
			table.insert(submenuControls, panelGuildBank("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_CLOTHIER, "MaterialGBank" .. CRAFTING_TYPE_CLOTHIER))
			table.insert(submenuControls, panelMaxStacks("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_CLOTHIER, "MaterialAll" .. CRAFTING_TYPE_CLOTHIER, "MaterialStacks" .. CRAFTING_TYPE_CLOTHIER))
			table.insert(submenuControls, panelRule("MaterialAll" .. CRAFTING_TYPE_CLOTHIER))
			table.insert(submenuControls, panelRule("refinedMaterialAll" .. CRAFTING_TYPE_CLOTHIER))
			table.insert(submenuControls, panelRule("rawMaterialAll" .. CRAFTING_TYPE_CLOTHIER))
			for materialIndex = 1, #BankManagerRules.static.refinedMaterial[CRAFTING_TYPE_CLOTHIER] do
				if BankManagerRules.static.refinedMaterial[CRAFTING_TYPE_CLOTHIER][materialIndex] ~= "" then
					table.insert(submenuControls, panelRule("refinedMaterial" .. CRAFTING_TYPE_CLOTHIER .. materialIndex))
				end
				if BankManagerRules.static.rawMaterial[CRAFTING_TYPE_CLOTHIER][materialIndex] ~= "" then
					table.insert(submenuControls, panelRule("rawMaterial" .. CRAFTING_TYPE_CLOTHIER .. materialIndex))
				end
			end
			for materialIndex = 1, #BankManagerRules.static.refinedMaterial[CRAFTING_TYPE_CLOTHIER * 100] do
				if BankManagerRules.static.refinedMaterial[CRAFTING_TYPE_CLOTHIER * 100][materialIndex] ~= "" then
					table.insert(submenuControls, panelRule("refinedMaterial" .. (CRAFTING_TYPE_CLOTHIER * 100) .. materialIndex))
				end
				if BankManagerRules.static.rawMaterial[CRAFTING_TYPE_CLOTHIER * 100][materialIndex] ~= "" then
					table.insert(submenuControls, panelRule("rawMaterial" .. (CRAFTING_TYPE_CLOTHIER * 100) .. materialIndex))
				end
			end
		end
	-- Woodworking
	elseif subMenu == "woodworking" and db.globalAddonProfile >= 2 then
	-- Inserting woodworking items
		if db.globalAddonProfile == 2 or db.globalAddonProfile == 4 then
		table.insert(submenuControls, panelOnlyIfNotFullStack("weaponType" .. CRAFTING_TYPE_WOODWORKING, "woodworkingAll" .. CRAFTING_TYPE_WOODWORKING))
		table.insert(submenuControls, panelGuildBank("weaponType" .. CRAFTING_TYPE_WOODWORKING, "woodworkingGBank" .. CRAFTING_TYPE_WOODWORKING))
		table.insert(submenuControls, panelMaxStacks("weaponType" .. CRAFTING_TYPE_WOODWORKING, "woodworkingAll" .. CRAFTING_TYPE_WOODWORKING, "woodworkingStacks" .. CRAFTING_TYPE_WOODWORKING))
		
		table.insert(submenuControls, panelRule("weaponType" .. CRAFTING_TYPE_WOODWORKING))
		table.insert(submenuControls, panelRule("weaponType" .. CRAFTING_TYPE_WOODWORKING .. "Trait" .. ITEM_TRAIT_TYPE_ARMOR_INTRICATE))
		table.insert(submenuControls, panelRule("weaponTypeResearchable" .. CRAFTING_TYPE_WOODWORKING))
		
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})

		end
		if db.globalAddonProfile >= 3 then
			table.insert(submenuControls, panelOnlyIfNotFullStack("improvement" .. CRAFTING_TYPE_WOODWORKING, "improvementAll" .. CRAFTING_TYPE_WOODWORKING))
			table.insert(submenuControls, panelGuildBank("improvement" .. CRAFTING_TYPE_WOODWORKING, "improvementGBank" .. CRAFTING_TYPE_WOODWORKING))
			table.insert(submenuControls, panelMaxStacks("improvement" .. CRAFTING_TYPE_WOODWORKING, "improvementAll" .. CRAFTING_TYPE_WOODWORKING, "improvementStacks" .. CRAFTING_TYPE_WOODWORKING))

			--table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		--end
	--[[	if db.globalAddonProfile == 2 or db.globalAddonProfile == 4 then
		table.insert(submenuControls, panelRule("weaponType" .. CRAFTING_TYPE_WOODWORKING))
		table.insert(submenuControls, panelRule("weaponType" .. CRAFTING_TYPE_WOODWORKING .. "Trait" .. ITEM_TRAIT_TYPE_ARMOR_INTRICATE))	
		table.insert(submenuControls, panelRule("weaponTypeResearchable" .. CRAFTING_TYPE_WOODWORKING))
		end]]
		--if db.globalAddonProfile >= 3 then
			for improvementItemIndex = 1, GetNumSmithingImprovementItems() do
				table.insert(submenuControls, panelRule("improvement" .. CRAFTING_TYPE_WOODWORKING .. improvementItemIndex))
			end
			
			table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
			
			table.insert(submenuControls, panelOnlyIfNotFullStack("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_WOODWORKING, "MaterialAll" .. CRAFTING_TYPE_WOODWORKING))
			table.insert(submenuControls, panelGuildBank("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_WOODWORKING, "MaterialGBank" .. CRAFTING_TYPE_WOODWORKING))
			table.insert(submenuControls, panelMaxStacks("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_WOODWORKING, "MaterialAll" .. CRAFTING_TYPE_WOODWORKING, "MaterialStacks" .. CRAFTING_TYPE_WOODWORKING))
			table.insert(submenuControls, panelRule("MaterialAll" .. CRAFTING_TYPE_WOODWORKING))
			table.insert(submenuControls, panelRule("refinedMaterialAll" .. CRAFTING_TYPE_WOODWORKING))
			table.insert(submenuControls, panelRule("rawMaterialAll" .. CRAFTING_TYPE_WOODWORKING))
			
			for materialIndex = 1, #BankManagerRules.static.refinedMaterial[CRAFTING_TYPE_WOODWORKING] do
				if BankManagerRules.static.refinedMaterial[CRAFTING_TYPE_WOODWORKING][materialIndex] ~= "" then
					table.insert(submenuControls, panelRule("refinedMaterial" .. CRAFTING_TYPE_WOODWORKING .. materialIndex))
				end
				if BankManagerRules.static.rawMaterial[CRAFTING_TYPE_WOODWORKING][materialIndex] ~= "" then
					table.insert(submenuControls, panelRule("rawMaterial" .. CRAFTING_TYPE_WOODWORKING .. materialIndex))
				end
			end
		end
	-- Jewelrycrafting
	elseif subMenu == "jewelrycrafting" and db.globalAddonProfile >= 2 then
-- Inserting jewelry
		if db.globalAddonProfile == 2 or db.globalAddonProfile == 4 then
		table.insert(submenuControls, panelOnlyIfNotFullStack("jewelry", "jewelryAll"))
		table.insert(submenuControls, panelGuildBank("jewelry", "jewelryGBank"))
		table.insert(submenuControls, panelMaxStacks("jewelry", "jewelryAll", "jewelryStacks"))
		
		--table.insert(submenuControls, panelRule("jewelry"))  -- not working moves more items as it should if its working as it should its perfect to place all jewelry without set in bank e.g. the trait jewelry items.
		table.insert(submenuControls, panelRule("jewelryIntricate"))
		--table.insert(submenuControls, panelRule("jewelryResearchable")) -- not working aa intended, takes out all non set armor you are able to research
		
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})

		end
-- End of new Jewelry block
		
		if db.globalAddonProfile >= 3 then -- relocating nonESO+ Crafting profile here
			table.insert(submenuControls, panelOnlyIfNotFullStack("improvement" .. CRAFTING_TYPE_JEWELRYCRAFTING, "improvementAll" .. CRAFTING_TYPE_JEWELRYCRAFTING))
			table.insert(submenuControls, panelGuildBank("improvement" .. CRAFTING_TYPE_JEWELRYCRAFTING, "improvementGBank" .. CRAFTING_TYPE_JEWELRYCRAFTING))
			table.insert(submenuControls, panelMaxStacks("improvement" .. CRAFTING_TYPE_JEWELRYCRAFTING, "improvementAll" .. CRAFTING_TYPE_JEWELRYCRAFTING, "improvementStacks" .. CRAFTING_TYPE_JEWELRYCRAFTING))
		
			for improvementItemIndex = 1, GetNumSmithingImprovementItems() do
				table.insert(submenuControls, panelRule("improvement" .. CRAFTING_TYPE_JEWELRYCRAFTING .. improvementItemIndex))
			end
	
			table.insert(submenuControls, panelOnlyIfNotFullStack("improvement" .. (CRAFTING_TYPE_JEWELRYCRAFTING * 100), "improvementAll" .. (CRAFTING_TYPE_JEWELRYCRAFTING * 100)))
			table.insert(submenuControls, panelGuildBank("improvement" .. (CRAFTING_TYPE_JEWELRYCRAFTING * 100), "improvementGBank" .. (CRAFTING_TYPE_JEWELRYCRAFTING * 100)))
			table.insert(submenuControls, panelMaxStacks("improvement" .. (CRAFTING_TYPE_JEWELRYCRAFTING * 100), "improvementAll" .. (CRAFTING_TYPE_JEWELRYCRAFTING * 100), "improvementStacks" .. (CRAFTING_TYPE_JEWELRYCRAFTING * 100)))
			for improvementItemIndex = 1, GetNumSmithingImprovementItems() do
				table.insert(submenuControls, panelRule("improvement" .. (CRAFTING_TYPE_JEWELRYCRAFTING * 100) .. improvementItemIndex))
			end
		
			table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
			
			table.insert(submenuControls, panelOnlyIfNotFullStack("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_JEWELRYCRAFTING, "MaterialAll" .. CRAFTING_TYPE_JEWELRYCRAFTING))
			table.insert(submenuControls, panelGuildBank("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_JEWELRYCRAFTING, "MaterialGBank" .. CRAFTING_TYPE_JEWELRYCRAFTING))
			table.insert(submenuControls, panelMaxStacks("Material[A]?[l]?[l]?" .. CRAFTING_TYPE_JEWELRYCRAFTING, "MaterialAll" .. CRAFTING_TYPE_JEWELRYCRAFTING, "MaterialStacks" .. CRAFTING_TYPE_JEWELRYCRAFTING))
			table.insert(submenuControls, panelRule("MaterialAll" .. CRAFTING_TYPE_JEWELRYCRAFTING))
			table.insert(submenuControls, panelRule("refinedMaterialAll" .. CRAFTING_TYPE_JEWELRYCRAFTING))
			table.insert(submenuControls, panelRule("rawMaterialAll" .. CRAFTING_TYPE_JEWELRYCRAFTING))
			
			for materialIndex = 1, #BankManagerRules.static.refinedMaterial[CRAFTING_TYPE_JEWELRYCRAFTING] do
				if BankManagerRules.static.refinedMaterial[CRAFTING_TYPE_JEWELRYCRAFTING][materialIndex] ~= "" then
					table.insert(submenuControls, panelRule("refinedMaterial" .. CRAFTING_TYPE_JEWELRYCRAFTING .. materialIndex))
				end
				if BankManagerRules.static.rawMaterial[CRAFTING_TYPE_JEWELRYCRAFTING][materialIndex] ~= "" then
					table.insert(submenuControls, panelRule("rawMaterial" .. CRAFTING_TYPE_JEWELRYCRAFTING .. materialIndex))
				end
			end
		end
	-- Cooking
	elseif subMenu == "cooking" then
		--if db.globalAddonProfile >= 3 then
			table.insert(submenuControls, panelOnlyIfNotFullStack("cookingIngredients", "cookingIngredientsAll"))
			table.insert(submenuControls, panelGuildBank("cookingIngredients", "cookingIngredientsGBank"))
			table.insert(submenuControls, panelMaxStacks("cookingIngredients", "cookingIngredientsAll", "cookingIngredientsStacks"))
			if db.globalAddonProfile >= 3 then
			table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
			
			table.insert(submenuControls, panelRule("cookingIngredientsFood"))
			table.insert(submenuControls, panelRule("cookingIngredientsDrink"))
			table.insert(submenuControls, panelRule("cookingIngredientsRare"))
			table.insert(submenuControls, panelRule("cookingAmbrosia"))
			table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		end
		
		table.insert(submenuControls, {type = "description", text="", width="half"}) -- Placeholder for next line
		table.insert(submenuControls, panelGuildBank("cookingRecipe", "cookingRecipeGBank"))
		table.insert(submenuControls, panelRule("cookingRecipeKnown"))
		table.insert(submenuControls, panelRule("cookingRecipeUnknown"))
	
	-- Alchemy
	elseif subMenu == "alchemy" and db.globalAddonProfile >= 3 then
		table.insert(submenuControls, panelOnlyIfNotFullStack("alchemy", "alchemyAll"))
		table.insert(submenuControls, panelGuildBank("alchemy", "alchemyGBank"))
		table.insert(submenuControls, panelMaxStacks("alchemy", "alchemyAll", "alchemyStacks"))
		
		table.insert(submenuControls, panelRule("alchemyAll"))
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		table.insert(submenuControls, panelRule("alchemyReagent"))
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		local MAX_ALCHEMY_SKILL = 8
		for alchemySkill=1, MAX_ALCHEMY_SKILL do
			table.insert(submenuControls, panelRule("alchemySolvent" .. alchemySkill))
		end
		
	-- Inserting Poison Solvents with divider
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		table.insert(submenuControls, panelRule("alchemyPoisonSolvent")) -- New string for Poison Solvents

	
	-- Enchanting
	elseif subMenu == "enchanting" then
		table.insert(submenuControls, {type = "description", text="", width="half"}) -- Placeholder for next line
		table.insert(submenuControls, panelGuildBank("enchantingGlyphs", "enchantingGlyphsGBank"))							--move "Glyphs" into this guildbank
		table.insert(submenuControls, panelRule("enchantingGlyphs"))
		
		table.insert(submenuControls, panelOnlyIfNotFullStack("enchanting", "enchantingAll"))
		--if db.globalAddonProfile >= 3 then 
			table.insert(submenuControls, panelGuildBank("enchanting", "enchantingAll"))
		--end
		table.insert(submenuControls, panelMaxStacks("enchanting", "enchantingAll", "enchantingStacks"))
		table.insert(submenuControls, panelRule("enchantingAll"))
		
		if db.globalAddonProfile >= 3 then
		
			table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
			
			table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
			table.insert(submenuControls, panelOnlyIfNotFullStack("enchantingEssence", "enchantingEssence"))
			table.insert(submenuControls, panelGuildBank("enchantingEssence", "enchantingEssence"))							--move "all essence" into this guildbank
			table.insert(submenuControls, panelMaxStacks("enchantingEssence", "enchantingEssence", "enchantingEssence"))
			table.insert(submenuControls, panelRule("enchantingEssence"))
			table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
			
			table.insert(submenuControls, panelOnlyIfNotFullStack("enchantingPotency", "enchantingPotency"))
			table.insert(submenuControls, panelGuildBank("enchantingPotency", "enchantingPotency"))							--move "all potency" into this guildbank
			table.insert(submenuControls, panelMaxStacks("enchantingPotency", "enchantingPotency", "enchantingPotency"))
			--local MAX_ENCHANTING_SKILL = 10
		--	for enchantingSkill=1, MAX_ENCHANTING_SKILL do
			table.insert(submenuControls, panelRule("enchantingPotency"))
		--	end
			table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})

	--		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
			table.insert(submenuControls, panelOnlyIfNotFullStack("enchantingAspect", "enchantingAspect"))
			table.insert(submenuControls, panelGuildBank("enchantingAspect", "enchantingAspect"))							--move "all aspect" into this guildbank
			table.insert(submenuControls, panelMaxStacks("enchantingAspect", "enchantingAspect", "enchantingAspect"))
			table.insert(submenuControls, panelRule("enchantingAspect"))
			
			table.insert(submenuControls, panelOnlyIfNotFullStack("enchantingTa", "enchantingTa"))
			table.insert(submenuControls, panelGuildBank("enchantingTa", "enchantingTa"))									--move "Ta only" into this guildbank
			table.insert(submenuControls, panelMaxStacks("enchantingTa", "enchantingTa", "enchantingTa"))
			table.insert(submenuControls, panelRule("enchantingTa"))
		end
		
		
	-- Diverse
	elseif subMenu == "trophies" then
		table.insert(submenuControls, panelOnlyIfNotFullStack("trophy", "trophyAll"))
		table.insert(submenuControls, panelGuildBank("trophy", "trophyGBank"))
		table.insert(submenuControls, panelMaxStacks("trophy", "trophyAll", "trophyStacks"))
		
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		
		table.insert(submenuControls, panelRule("trophyTreasureMaps"))
		table.insert(submenuControls, panelRule("trophySurveys"))
		table.insert(submenuControls, panelRule("trophyFragMotifs"))
		table.insert(submenuControls, panelRule("trophyFragRecipe"))
		table.insert(submenuControls, panelRule("trophyICPVE"))
	
	-- PvP / Siege equipment
	elseif subMenu == "pvp" then
		table.insert(submenuControls, {type = "description", text = GetString(BMR_PVP_DESC), width = "full"})
		-- Use a separate description label: LAM2 may not render dropdown names in nested submenus.
		table.insert(submenuControls, {type = "description", text = GetString(BMR_PVP_PRIORITY_STATE), width = "full"})
		table.insert(submenuControls, {
			type = "dropdown", name = " ", tooltip = GetString(BMR_PVP_PRIORITY_STATE_TOOLTIP),
			choices = {GetString(BMR_PVP_PRIORITY_UNUSED), GetString(BMR_PVP_PRIORITY_USED)}, width = "full",
			getFunc = function() local p = db.profiles and db.profiles[actualProfile]; return (p and p.pvpPriorityState == "used") and GetString(BMR_PVP_PRIORITY_USED) or GetString(BMR_PVP_PRIORITY_UNUSED) end,
			setFunc = function(value) local p = db.profiles and db.profiles[actualProfile]; if p then p.pvpPriorityState = (value == GetString(BMR_PVP_PRIORITY_USED)) and "used" or "unused" end end,
			default = GetString(BMR_PVP_PRIORITY_UNUSED),
		})
		-- Optional diagnostic buttons intentionally disabled for normal use.
		-- Uncomment this block when new ESO siege items need to be scanned.
		--[[
		table.insert(submenuControls, {
			type = "button", name = GetString(BMR_PVP_DATABASE_DUMP), tooltip = GetString(BMR_PVP_DATABASE_DUMP_TOOLTIP), width = "full",
			func = DebugScanPvpItemFinderDatabase,
		})
		table.insert(submenuControls, {
			type = "button", name = GetString(BMR_PVP_DEBUG_DUMP), tooltip = GetString(BMR_PVP_DEBUG_DUMP_TOOLTIP), width = "full",
			func = DebugDumpPvpSiegeItems,
		})
		]]
		table.insert(submenuControls, panelOnlyIfNotFullStack("MiscPvp", "MiscPvpAll"))
		table.insert(submenuControls, panelGuildBank("MiscPvp", "MiscPvpGBank"))
		table.insert(submenuControls, panelMaxStacks("MiscPvp", "MiscPvpAll", "MiscPvpStacks"))
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		table.insert(submenuControls, panelRule("MiscPvpSiege"))

		-- The view is a UI preference, not a transfer profile setting. It is stored
		-- account-wide and can be changed without losing any configured rules.
		table.insert(submenuControls, {
			type = "dropdown",
			name = GetString(BMR_PVP_SORT_MODE),
			tooltip = GetString(BMR_PVP_SORT_MODE_TOOLTIP),
			choices = {GetString(BMR_PVP_SORT_WEAPONTYPE), GetString(BMR_PVP_SORT_ALLIANCE)},
			width = "full",
			getFunc = function()
				return (db.pvpSortMode == "alliance") and GetString(BMR_PVP_SORT_ALLIANCE) or GetString(BMR_PVP_SORT_WEAPONTYPE)
			end,
			setFunc = function(value)
				local newMode = (value == GetString(BMR_PVP_SORT_ALLIANCE)) and "alliance" or "weaponType"
				if db.pvpSortMode == newMode then return end
				db.pvpSortMode = newMode
			end,
			requiresReload = true,
			default = GetString(BMR_PVP_SORT_WEAPONTYPE),
		})

		-- Build sorted categories once so both display modes use the same localized order.
		local function IsKnownPvpAlliance(alliance)
			return alliance == "AD" or alliance == "EP" or alliance == "DC"
		end

		local function BuildPvpCategoryControls(categoryName, allianceFilter, nonAllianceOnly)
			local categoryItems = {}
			for itemId, itemData in pairs(BMR_PVP_ITEM_CATALOG) do
				local allianceMatches = true
				if allianceFilter then
					allianceMatches = itemData.alliance == allianceFilter
				elseif nonAllianceOnly then
					allianceMatches = not IsKnownPvpAlliance(itemData.alliance)
				end
				if itemData.category == categoryName and allianceMatches then
					table.insert(categoryItems, {id = itemId, name = itemData.name})
				end
			end
			table.sort(categoryItems, function(a, b)
				if a.name == b.name then return a.id < b.id end
				return a.name < b.name
			end)
			local categoryControls = {}
			for _, item in ipairs(categoryItems) do
				local ruleControl = panelRule("pvpItem_" .. tostring(item.id))
				if ruleControl then
					ruleControl.bmrPvpCategory = categoryName
					ruleControl.bmrPvpAlliance = allianceFilter
					table.insert(categoryControls, ruleControl)
				end
			end
			return categoryControls, #categoryItems
		end

		local pvpCategoryOrder = {"Ballisten", "Feldlager", "Katapult", "Lancier", "Rammbock", "Tribok"}
		table.sort(pvpCategoryOrder, function(a, b)
			local localizedA = string.lower(GetPvpCategoryDisplayName(a) or a)
			local localizedB = string.lower(GetPvpCategoryDisplayName(b) or b)
			if localizedA == localizedB then return a < b end
			return localizedA < localizedB
		end)

		local function AddPvpCategorySubmenu(targetControls, categoryName, allianceFilter, nonAllianceOnly)
			local controls, itemCount = BuildPvpCategoryControls(categoryName, allianceFilter, nonAllianceOnly)
			if itemCount > 0 then
				-- Function arguments have their own closure scope per submenu.
				local categoryNameForLabel = categoryName
				table.insert(targetControls, {
					type = "submenu",
					name = function() return GetPvpCategoryDisplayName(categoryNameForLabel) end,
					bmrPvpCategory = categoryName,
					bmrPvpAlliance = allianceFilter,
					bmrPvpNonAlliance = nonAllianceOnly == true,
					controls = controls,
				})
			end
		end

		local function BuildPvpAllianceControls(alliance, includeIndividualItems)
			local allianceControls = {}
			-- The alliance submenu already carries this label. Do not add a duplicate
			-- description: the editable dropdown below is the single rule entry.
			-- This must remain the first actionable rule in the alliance group.
			table.insert(allianceControls, panelPvpAllianceAction(alliance, " "))
			table.insert(allianceControls, panelGuildBank("^pvpAlliance_" .. alliance .. "$", "pvpAlliance_" .. alliance))
			if includeIndividualItems then
				for _, categoryName in ipairs(pvpCategoryOrder) do
					AddPvpCategorySubmenu(allianceControls, categoryName, alliance)
				end
			end
			return allianceControls
		end

		-- Keep Brand Oil first in Weapon Type mode. In Alliance mode all items
		-- whose alliance cannot be reliably identified live in their own first
		-- collapsible group, ahead of the three alliance-specific groups.
		if db.pvpSortMode == "alliance" then
			local nonAllianceCategories = {}
			for _, itemData in pairs(BMR_PVP_ITEM_CATALOG) do
				if not IsKnownPvpAlliance(itemData.alliance) then nonAllianceCategories[itemData.category] = true end
			end
			local nonAllianceCategoryOrder = {}
			for categoryName in pairs(nonAllianceCategories) do table.insert(nonAllianceCategoryOrder, categoryName) end
			table.sort(nonAllianceCategoryOrder, function(a, b)
				local localizedA = string.lower(GetPvpCategoryDisplayName(a) or a)
				local localizedB = string.lower(GetPvpCategoryDisplayName(b) or b)
				if localizedA == localizedB then return a < b end
				return localizedA < localizedB
			end)

			local nonAllianceControls = {}
			for _, categoryName in ipairs(nonAllianceCategoryOrder) do
				AddPvpCategorySubmenu(nonAllianceControls, categoryName, nil, true)
			end
			if #nonAllianceControls > 0 then
				table.insert(submenuControls, {
					type = "submenu",
					name = GetString(BMR_PVP_NOT_ALLIANCE_SPECIFIC),
					bmrPvpNonAlliance = true,
					controls = nonAllianceControls,
				})
			end
		else
			-- Brand Oil remains the first individual-item category in this view.
			AddPvpCategorySubmenu(submenuControls, "Öl", nil)
		end
		table.insert(submenuControls, {type = "description", text = GetString(BMR_PVP_ALLIANCE_DESC), width = "full"})
		table.insert(submenuControls, {type = "description", text = GetString(BMR_PVP_INDIVIDUAL_DESC), width = "full"})

		local alliances = {"AD", "EP", "DC"}
		for _, alliance in ipairs(alliances) do
			local allianceKey = alliance
			local allianceStringId = ({AD = BMR_PVP_ALLIANCE_AD, EP = BMR_PVP_ALLIANCE_EP, DC = BMR_PVP_ALLIANCE_DC})[allianceKey]
			local includeItems = db.pvpSortMode == "alliance"
			table.insert(submenuControls, {
				type = "submenu",
				name = function() return GetString(allianceStringId) end,
				bmrPvpAlliance = allianceKey,
				controls = BuildPvpAllianceControls(allianceKey, includeItems),
			})
		end

		-- In Weapon Type mode the categories are peers of the alliance-wide rules;
		-- in Alliance mode they live inside the relevant alliance submenu instead.
		if db.pvpSortMode ~= "alliance" then
			for _, categoryName in ipairs(pvpCategoryOrder) do
				AddPvpCategorySubmenu(submenuControls, categoryName, nil)
			end
		end

	-- Diverse
	elseif subMenu == "misc" then
		table.insert(submenuControls, panelOnlyIfNotFullStack("Misc", "MiscAll"))
		table.insert(submenuControls, panelGuildBank("Misc", "MiscGBank"))
		table.insert(submenuControls, panelMaxStacks("Misc", "MiscAll", "MiscStacks"))
		
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		
		table.insert(submenuControls, panelRule("MiscAvaRepair"))
		table.insert(submenuControls, panelRule("MiscDisguises"))
		table.insert(submenuControls, panelRule("MiscLockpick"))
		if db.globalAddonProfile >= 3 then
			table.insert(submenuControls, panelRule("MiscLure"))
		end
		table.insert(submenuControls, panelRule("MiscPotion"))
		table.insert(submenuControls, panelRule("MiscPoison"))
		table.insert(submenuControls, panelRule("MiscRacial"))
		table.insert(submenuControls, panelRule("MiscContainer"))
		table.insert(submenuControls, panelRule("MiscRepair"))
		table.insert(submenuControls, panelRule("MiscCrownRepair"))
		table.insert(submenuControls, panelRule("MiscSoulGemsEmpty"))
		table.insert(submenuControls, panelRule("MiscSoulGemsFulfilled"))
		table.insert(submenuControls, panelRule("MiscSoulGemsCrown"))
		--table.insert(submenuControls, panelRule("MiscMasterWrit"))
	
	-- Containers: group controls affect only their own item families.
	-- Individual item actions remain independently configurable below.
	elseif subMenu == "containers" then
		table.insert(submenuControls, {type = "description", text = GetString(BMR_CONTAINER_GROUP_WRITS), width = "full"})
		-- This master action overrides all seven individual writ actions unless set to '-'.
		table.insert(submenuControls, panelRule("MiscContainerUnknownAllWrit"))
		table.insert(submenuControls, panelOnlyIfNotFullStack("MiscContainerUnknown.*Writ", "MiscContainerUnknownBlacksmithingWrit"))
		table.insert(submenuControls, panelGuildBank("MiscContainerUnknown.*Writ", "MiscContainerUnknownBlacksmithingWrit"))
		table.insert(submenuControls, panelMaxStacks("MiscContainerUnknown.*Writ", "MiscContainerUnknownBlacksmithingWrit", "MiscContainerUnknownBlacksmithingWrit"))
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		table.insert(submenuControls, {type = "description", text = GetString(BMR_CONTAINER_GROUP_SURVEYS), width = "full"})
		-- This master action overrides all six individual survey actions unless set to '-'.
		table.insert(submenuControls, panelRule("MiscContainerUnidentifiedAllSurvey"))
		table.insert(submenuControls, panelOnlyIfNotFullStack("MiscContainerUnidentified.*Survey", "MiscContainerUnidentifiedBlacksmithingSurvey"))
		table.insert(submenuControls, panelGuildBank("MiscContainerUnidentified.*Survey", "MiscContainerUnidentifiedBlacksmithingSurvey"))
		table.insert(submenuControls, panelMaxStacks("MiscContainerUnidentified.*Survey", "MiscContainerUnidentifiedBlacksmithingSurvey", "MiscContainerUnidentifiedBlacksmithingSurvey"))
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		table.insert(submenuControls, panelRule("MiscContainerUnknownBlacksmithingWrit"))
		table.insert(submenuControls, panelRule("MiscContainerUnknownClothingWrit"))
		table.insert(submenuControls, panelRule("MiscContainerUnknownWoodworkingWrit"))
		table.insert(submenuControls, panelRule("MiscContainerUnknownEnchantingWrit"))
		table.insert(submenuControls, panelRule("MiscContainerUnknownProvisioningWrit"))
		table.insert(submenuControls, panelRule("MiscContainerUnknownAlchemyWrit"))
		table.insert(submenuControls, panelRule("MiscContainerUnknownJewelryWrit"))
		table.insert(submenuControls, panelRule("MiscContainerTreasureMap"))
		table.insert(submenuControls, panelRule("MiscContainerUnidentifiedBlacksmithingSurvey"))
		table.insert(submenuControls, panelRule("MiscContainerUnidentifiedClothingSurvey"))
		table.insert(submenuControls, panelRule("MiscContainerUnidentifiedWoodworkingSurvey"))
		table.insert(submenuControls, panelRule("MiscContainerUnidentifiedEnchantingSurvey"))
		table.insert(submenuControls, panelRule("MiscContainerUnidentifiedAlchemySurvey"))
		table.insert(submenuControls, panelRule("MiscContainerUnidentifiedJewelrySurvey"))
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		-- The master action above applies to every Antiquity Lead unless set to '-'.
		-- Other settings are shared across all four qualities; each quality has its own action.
		table.insert(submenuControls, panelRule("MiscContainerAntiquityLead"))
		table.insert(submenuControls, panelOnlyIfNotFullStack("MiscContainerAntiquityLead", "MiscContainerAntiquityLeadGreen"))
		table.insert(submenuControls, panelGuildBank("MiscContainerAntiquityLead", "MiscContainerAntiquityLeadGreen"))
		table.insert(submenuControls, panelMaxStacks("MiscContainerAntiquityLead", "MiscContainerAntiquityLeadGreen", "MiscContainerAntiquityLeadGreen"))
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		table.insert(submenuControls, panelRule("MiscContainerAntiquityLeadGreen"))
		table.insert(submenuControls, panelRule("MiscContainerAntiquityLeadBlue"))
		table.insert(submenuControls, panelRule("MiscContainerAntiquityLeadPurple"))
		table.insert(submenuControls, panelRule("MiscContainerAntiquityLeadGold"))

	-- Housing
	elseif subMenu == "housing" then
		table.insert(submenuControls, panelOnlyIfNotFullStack("Housing", "HousingAll"))
		table.insert(submenuControls, panelGuildBank("Housing", "HousingGBank"))
		table.insert(submenuControls, panelMaxStacks("Housing", "HousingAll", "HousingStacks"))
		
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		
		table.insert(submenuControls, panelRule("HousingRecipeKnown"))
		table.insert(submenuControls, panelRule("HousingRecipeUnknown"))
		table.insert(submenuControls, panelRule("HousingFurnitures"))
		if db.globalAddonProfile >= 3 then
			table.insert(submenuControls, panelRule("HousingIngredients"))
		end
		
	-- Exact-item rules created from an inventory context menu.
	elseif subMenu == "custom" then
		table.insert(submenuControls, {type = "description", text = GetString(BMR_CUSTOM_RULES_DESC), width = "full"})
		table.insert(submenuControls, {
			type = "button", name = GetString(BMR_CUSTOM_RULES_RELOAD), tooltip = GetString(BMR_CUSTOM_RULES_RELOAD_TOOLTIP), width = "full",
			func = function()
				SyncCustomItemRuleDefinitions()
				BMR.CustomRules.SyncFilterRuleDefinitions()
				if BMR.refreshCustomRuleOptions then BMR.refreshCustomRuleOptions() end
			end,
		})
		table.insert(submenuControls, {type = "header", name = GetString(BMR_CUSTOM_FILTER_TITLE)})
		table.insert(submenuControls, {type = "description", text = GetString(BMR_CUSTOM_FILTER_DESC), width = "full"})
		-- The full catalog sweep is a maintenance tool for the designated account.
		-- The shipped static tag catalog gives every other account the same filter values.
		if BMR.CustomRules and BMR.CustomRules.CanStartItemTagCatalogScan
			and BMR.CustomRules.CanStartItemTagCatalogScan() then
			table.insert(submenuControls, {
				type = "button", name = GetString(BMR_CUSTOM_FILTER_SCAN_TAGS), tooltip = GetString(BMR_CUSTOM_FILTER_SCAN_TAGS_TOOLTIP), width = "full",
				func = function() if BMR.CustomRules then BMR.CustomRules.StartItemTagCatalogScan(500000) end end,
			})
		end
		table.insert(submenuControls, {
			type = "custom", reference = "BMRCustomFilterRuleEditor", width = "full", minHeight = 204, maxHeight = 270,
			createFunc = BMR.CustomRules.CreateCustomFilterRuleEditor, refreshFunc = BMR.CustomRules.RefreshCustomFilterRuleEditor,
		})
		table.insert(submenuControls, {
			type = "custom", reference = "BMRCustomFilterRuleDynamicList", width = "full", minHeight = 30, maxHeight = 1200,
			bmrCountCustomFilterRules = true,
			createFunc = BMR.CustomRules.CreateCustomFilterRuleList, refreshFunc = BMR.CustomRules.RefreshCustomFilterRuleList,
		})
		table.insert(submenuControls, panelOnlyIfNotFullStack("customFilter_", "customFilterAll"))
		table.insert(submenuControls, panelGuildBank("customFilter_", "customFilterAll"))
		table.insert(submenuControls, panelMaxStacks("customFilter_", "customFilterAll", "customFilterAll"))
		table.insert(submenuControls, {
			type = "checkbox", name = GetString(BMR_CUSTOM_FILTER_HIDE_CONTEXT_MENU), tooltip = GetString(BMR_CUSTOM_FILTER_HIDE_CONTEXT_MENU_TOOLTIP), width = "full",
			getFunc = function() return db.hideSetAsBmrRule == true end,
			setFunc = function(value) db.hideSetAsBmrRule = value == true end,
			default = false,
		})
		table.insert(submenuControls, {
			type = "checkbox", name = GetString(BMR_CUSTOM_RULES_DEBUG), tooltip = GetString(BMR_CUSTOM_RULES_DEBUG_TOOLTIP), width = "full",
			getFunc = function() return db.customRulesDebug == true end,
			setFunc = function(value) db.customRulesDebug = value == true; CustomRuleDebug("debug mode enabled") end,
			default = false,
		})
		table.insert(submenuControls, panelOnlyIfNotFullStack("customItem_", "customItemsAll"))
		table.insert(submenuControls, panelGuildBank("customItem_", "customItemsAll"))
		table.insert(submenuControls, panelMaxStacks("customItem_", "customItemsAll", "customItemsAll"))
		table.insert(submenuControls, {type = "texture", image="EsoUI/Art/Miscellaneous/horizontalDivider.dds", imageWidth=510, imageHeight=4})
		table.insert(submenuControls, {
			type = "custom", reference = "BMRCustomRuleDynamicList", width = "full", minHeight = 30, maxHeight = 2000,
			bmrCountCustomItemRules = true,
			createFunc = BMR.CustomRules.CreateCustomRuleList, refreshFunc = BMR.CustomRules.RefreshCustomRuleList,
		})
	-- Special
	elseif subMenu == "special" then
		table.insert(submenuControls, panelSpecialFilter("writsQuests"))	-- Special
		table.insert(submenuControls, panelOnlyIfNotFullStack("quest", "questAll"))
		table.insert(submenuControls, panelGuildBank("quest", "questGBank"))
		table.insert(submenuControls, panelMaxStacks("quest", "questAll", "questStacks"))
		table.insert(submenuControls, panelRule("questMasterWrit"))
		end
--[[	elseif subMenu == "ruleWriter" then
		submenuControls = RuleWriterPanel() -- Rule Writer Panel
	end]]
	
	return submenuControls

end

local function NamesToIDSavedVars()

	if not db.namesToIDSavedVars then
		
		local displayName = GetDisplayName()
		local name = GetUnitName("player")
		
		if BMVars.Default[displayName][name] then
			db = BMVars.Default[displayName][name]
			db.namesToIDSavedVars = true -- should not be necessary because data don't exist anymore in BMVars.Default[displayName][name]
		end
		
	end

end

-- Build LAM panel
-- Safe JSON import/export for portable BMR profile backups. The parser handles data only;
-- it never evaluates pasted Lua or executes imported text.
local function BMRJsonEscape(value)
	local out = {"\""}
	local replacements = {['"']='\\"', ['\\']='\\\\', ['\b']='\\b', ['\f']='\\f', ['\n']='\\n', ['\r']='\\r', ['\t']='\\t'}
	for index = 1, #value do
		local char = string.sub(value, index, index)
		local byte = string.byte(char)
		if replacements[char] then out[#out + 1] = replacements[char]
		elseif byte < 32 then out[#out + 1] = string.format("\\u%04x", byte)
		else out[#out + 1] = char end
	end
	out[#out + 1] = "\""
	return table.concat(out)
end

local function BMRJsonArrayLength(value)
	local count, maxIndex = 0, 0
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return nil end
		count = count + 1
		if key > maxIndex then maxIndex = key end
	end
	if count > 0 and count == maxIndex then return maxIndex end
	return nil
end

local function BMRJsonEncode(value, stack, depth)
	stack, depth = stack or {}, depth or 0
	if depth > 64 then error("profile data exceeds maximum nesting depth") end
	local valueType = type(value)
	if valueType == "nil" then return "null"
	elseif valueType == "boolean" then return value and "true" or "false"
	elseif valueType == "number" then
		if value ~= value or value == math.huge or value == -math.huge then error("profile contains an invalid number") end
		return tostring(value)
	elseif valueType == "string" then return BMRJsonEscape(value)
	elseif valueType ~= "table" then error("profile contains an unsupported value") end
	if stack[value] then error("profile data contains a cyclic table") end
	stack[value] = true
	local arrayLength = BMRJsonArrayLength(value)
	local pieces = {}
	if arrayLength ~= nil then
		for index = 1, arrayLength do pieces[#pieces + 1] = BMRJsonEncode(value[index], stack, depth + 1) end
		stack[value] = nil
		return "[" .. table.concat(pieces, ",") .. "]"
	end
	local normalizedKeys = {}
	for key in pairs(value) do
		if type(key) ~= "string" and type(key) ~= "number" then error("profile contains an unsupported table key") end
		local textKey = tostring(key)
		local existingKey = normalizedKeys[textKey]
		-- SavedVariables can contain both [123] and ["123"] for the same logical
		-- ID. Prefer the string-keyed value (the canonical form in BMR exports).
		if not existingKey or type(key) == "string" then normalizedKeys[textKey] = {raw = key, text = textKey} end
	end
	local keys = {}
	for _, key in pairs(normalizedKeys) do keys[#keys + 1] = key end
	table.sort(keys, function(left, right) return left.text < right.text end)
	for _, key in ipairs(keys) do
		pieces[#pieces + 1] = BMRJsonEscape(key.text) .. ":" .. BMRJsonEncode(value[key.raw], stack, depth + 1)
	end
	stack[value] = nil
	return "{" .. table.concat(pieces, ",") .. "}"
end

local function BMRJsonDecode(input)
	if type(input) ~= "string" then error("import text is missing") end
	if #input == 0 then error("import text is empty") end
	if #input > 5000000 then error("import text is larger than 5 MB") end
	local position, length = 1, #input
	local function skipWhitespace()
		while position <= length and string.match(string.sub(input, position, position), "%s") do position = position + 1 end
	end
	local function utf8FromCodepoint(codepoint)
		if codepoint <= 0x7F then return string.char(codepoint)
		elseif codepoint <= 0x7FF then return string.char(0xC0 + math.floor(codepoint / 0x40), 0x80 + (codepoint % 0x40))
		elseif codepoint <= 0xFFFF then return string.char(0xE0 + math.floor(codepoint / 0x1000), 0x80 + (math.floor(codepoint / 0x40) % 0x40), 0x80 + (codepoint % 0x40))
		else return string.char(0xF0 + math.floor(codepoint / 0x40000), 0x80 + (math.floor(codepoint / 0x1000) % 0x40), 0x80 + (math.floor(codepoint / 0x40) % 0x40), 0x80 + (codepoint % 0x40)) end
	end
	local function parseString()
		if string.sub(input, position, position) ~= '"' then error("expected string") end
		position = position + 1
		local pieces = {}
		while position <= length do
			local char = string.sub(input, position, position)
			position = position + 1
			if char == '"' then return table.concat(pieces) end
			if char == "\\" then
				local escape = string.sub(input, position, position)
				position = position + 1
				local map = {['"']='"', ['\\']='\\', ['/']='/', ['b']='\b', ['f']='\f', ['n']='\n', ['r']='\r', ['t']='\t'}
				if map[escape] then pieces[#pieces + 1] = map[escape]
				elseif escape == "u" then
					local hex = string.sub(input, position, position + 3)
					if not string.match(hex, "^%x%x%x%x$") then error("invalid unicode escape") end
					position = position + 4
					local cp = tonumber(hex, 16)
					if cp >= 0xD800 and cp <= 0xDBFF and string.sub(input, position, position + 1) == "\\u" then
						local lowHex = string.sub(input, position + 2, position + 5)
						local low = tonumber(lowHex, 16)
						if low and low >= 0xDC00 and low <= 0xDFFF then
							cp = 0x10000 + (cp - 0xD800) * 0x400 + (low - 0xDC00)
							position = position + 6
						end
					end
					pieces[#pieces + 1] = utf8FromCodepoint(cp)
				else error("invalid string escape") end
			else
				if string.byte(char) < 32 then error("unescaped control character") end
				pieces[#pieces + 1] = char
			end
		end
		error("unterminated string")
	end
	local parseValue
	parseValue = function(depth)
		if depth > 64 then error("import data exceeds maximum nesting depth") end
		skipWhitespace()
		local char = string.sub(input, position, position)
		if char == '"' then return parseString()
		elseif char == "{" then
			position = position + 1
			local object = {}
			skipWhitespace()
			if string.sub(input, position, position) == "}" then position = position + 1; return object end
			while true do
				skipWhitespace()
				local key = parseString()
				skipWhitespace()
				if string.sub(input, position, position) ~= ":" then error("expected colon") end
				position = position + 1
				object[key] = parseValue(depth + 1)
				skipWhitespace()
				local separator = string.sub(input, position, position)
				position = position + 1
				if separator == "}" then break end
				if separator ~= "," then error("expected comma or closing brace") end
			end
			return object
		elseif char == "[" then
			position = position + 1
			local array = {}
			skipWhitespace()
			if string.sub(input, position, position) == "]" then position = position + 1; return array end
			while true do
				array[#array + 1] = parseValue(depth + 1)
				skipWhitespace()
				local separator = string.sub(input, position, position)
				position = position + 1
				if separator == "]" then break end
				if separator ~= "," then error("expected comma or closing bracket") end
			end
			return array
		elseif string.sub(input, position, position + 3) == "true" then position = position + 4; return true
		elseif string.sub(input, position, position + 4) == "false" then position = position + 5; return false
		elseif string.sub(input, position, position + 3) == "null" then error("null values are not supported in profile data")
		else
			local startPosition = position
			while position <= length and string.match(string.sub(input, position, position), "[%d%+%-%.eE]") do position = position + 1 end
			if startPosition == position then error("unexpected character at position " .. tostring(position)) end
			local number = tonumber(string.sub(input, startPosition, position - 1))
			if not number or number ~= number or number == math.huge or number == -math.huge then error("invalid number") end
			return number
		end
	end
	local result = parseValue(0)
	skipWhitespace()
	if position <= length then error("unexpected trailing data") end
	return result
end

-- Compact, printable and chunked profile exports. These routines intentionally avoid
-- optional libraries so a backup can be imported on another account without extra dependencies.
local function BMRLZWCompress(input)
	if type(input) ~= "string" then error("compression input must be text") end
	local dictionary = {}
	for code = 0, 255 do dictionary[string.char(code)] = code end
	local nextCode, output = 256, {}
	local function writeCode(code)
		output[#output + 1] = string.char(math.floor(code / 256), code % 256)
	end
	if #input == 0 then return "" end
	local phrase = string.sub(input, 1, 1)
	for index = 2, #input do
		local char = string.sub(input, index, index)
		local combined = phrase .. char
		if dictionary[combined] ~= nil then
			phrase = combined
		else
			writeCode(dictionary[phrase])
			if nextCode < 65536 then dictionary[combined] = nextCode; nextCode = nextCode + 1 end
			phrase = char
		end
	end
	writeCode(dictionary[phrase])
	return table.concat(output)
end

local function BMRLZWDecompress(input)
	if type(input) ~= "string" or (#input % 2) ~= 0 then error("invalid compressed data length") end
	if #input > 7000000 then error("compressed data exceeds 7 MB") end
	local dictionary = {}
	for code = 0, 255 do dictionary[code] = string.char(code) end
	local nextCode, previous, output, outputLength = 256, nil, {}, 0
	for position = 1, #input, 2 do
		local code = string.byte(input, position) * 256 + string.byte(input, position + 1)
		local entry
		if dictionary[code] ~= nil then
			entry = dictionary[code]
		elseif code == nextCode and previous ~= nil then
			entry = previous .. string.sub(previous, 1, 1)
		else
			error("invalid compressed dictionary code")
		end
		output[#output + 1] = entry
		outputLength = outputLength + #entry
		if outputLength > 5000000 then error("decompressed profile data exceeds 5 MB") end
		if previous ~= nil and nextCode < 65536 then
			dictionary[nextCode] = previous .. string.sub(entry, 1, 1)
			nextCode = nextCode + 1
		end
		previous = entry
	end
	return table.concat(output)
end

local function BMRBase64Encode(input)
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local output = {}
	for position = 1, #input, 3 do
		local first = string.byte(input, position)
		local second = string.byte(input, position + 1)
		local third = string.byte(input, position + 2)
		local a = math.floor(first / 4)
		local b = (first % 4) * 16 + math.floor((second or 0) / 16)
		local c = second and ((second % 16) * 4 + math.floor((third or 0) / 64)) or nil
		local d = third and (third % 64) or nil
		output[#output + 1] = string.sub(alphabet, a + 1, a + 1)
		output[#output + 1] = string.sub(alphabet, b + 1, b + 1)
		output[#output + 1] = c and string.sub(alphabet, c + 1, c + 1) or "="
		output[#output + 1] = d and string.sub(alphabet, d + 1, d + 1) or "="
	end
	return table.concat(output)
end

local function BMRBase64Decode(input)
	if type(input) ~= "string" then error("base64 input is missing") end
	input = string.gsub(input, "%s", "")
	if #input == 0 or (#input % 4) ~= 0 then error("invalid base64 length") end
	if #input > 10000000 then error("base64 data exceeds 10 MB") end
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local values = {}
	for index = 1, #alphabet do values[string.sub(alphabet, index, index)] = index - 1 end
	local output = {}
	for position = 1, #input, 4 do
		local c1 = string.sub(input, position, position)
		local c2 = string.sub(input, position + 1, position + 1)
		local c3 = string.sub(input, position + 2, position + 2)
		local c4 = string.sub(input, position + 3, position + 3)
		local v1, v2 = values[c1], values[c2]
		if v1 == nil or v2 == nil then error("invalid base64 character") end
		local lastBlock = position + 3 == #input
		if c3 == "=" then
			if c4 ~= "=" or not lastBlock then error("invalid base64 padding") end
			output[#output + 1] = string.char(v1 * 4 + math.floor(v2 / 16))
		elseif c4 == "=" then
			local v3 = values[c3]
			if v3 == nil or not lastBlock then error("invalid base64 padding") end
			output[#output + 1] = string.char(v1 * 4 + math.floor(v2 / 16), (v2 % 16) * 16 + math.floor(v3 / 4))
		else
			local v3, v4 = values[c3], values[c4]
			if v3 == nil or v4 == nil then error("invalid base64 character") end
			output[#output + 1] = string.char(v1 * 4 + math.floor(v2 / 16), (v2 % 16) * 16 + math.floor(v3 / 4), (v3 % 4) * 64 + v4)
		end
	end
	return table.concat(output)
end

local function BMRParseProfileExportChunk(text)
	if type(text) ~= "string" then return nil end
	text = string.gsub(text, "%s", "")
	local index, total, data = string.match(text, "^BMRZ1|(%d+)|(%d+)|([A-Za-z0-9+/=]+)$")
	if not index then return nil end
	index, total = tonumber(index), tonumber(total)
	if not index or not total or index < 1 or total < 1 or index > total or total > 1000 then error("invalid export part header") end
	return index, total, data
end

local function BMRDecodeCompressedProfileExport(encoded)
	local compressed = BMRBase64Decode(encoded)
	local json = BMRLZWDecompress(compressed)
	return BMRJsonDecode(json)
end

local function BMRProfileTransferMessage(stringId, ...)
	if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
		local message = GetString(stringId)
		local arguments = {...}
		if #arguments > 0 then
			for index = 1, #arguments do arguments[index] = tostring(arguments[index]) end
			message = zo_strformat(message, unpack(arguments))
		end
		BMR.SafeAddChatMessage(message)
	end
end

function BMR._RuleUi.FindLamChildBySuffix(parent, suffix)
	if not parent or type(suffix) ~= "string" then return nil end
	if parent.GetNumChildren and parent.GetChild then
		for index = 1, parent:GetNumChildren() do
			local child = parent:GetChild(index)
			local name = child and child.GetName and child:GetName() or ""
			if name ~= "" and string.sub(name, -#suffix) == suffix then return child end
			local nested = BMR._RuleUi.FindLamChildBySuffix(child, suffix)
			if nested then return nested end
		end
	end
	return nil
end


function BMR._RuleUi.RuleNameMatchesGuildPattern(ruleName, pattern)
	if type(pattern) ~= "string" or pattern == "" then return false end
	local ok, matched = pcall(string.find, ruleName, pattern)
	return ok and matched ~= nil
end

function BMR._RuleUi.NormalizeBmrRuleOptionTree(entries, allMigrationControls)
	local isRootCall = allMigrationControls == nil
	allMigrationControls = allMigrationControls or {}
	if type(entries) ~= "table" then return entries end
	local indices = {}
	for index, option in pairs(entries) do
		if type(index) == "number" and index >= 1 and index % 1 == 0 and type(option) == "table" then indices[#indices + 1] = index end
	end
	table.sort(indices)
	local compact = {}
	local inRuleBlock = false
	for _, index in ipairs(indices) do
		local option = entries[index]
		if type(option.controls) == "table" then option.controls = BMR._RuleUi.NormalizeBmrRuleOptionTree(option.controls, allMigrationControls) end
		if option.bmrLegacyGroupGuildBank then
			allMigrationControls[#allMigrationControls + 1] = option
		elseif option.bmrRuleTableRow then
			if not inRuleBlock then compact[#compact + 1] = BMR._RuleUi.MakeBmrRuleHeaderOption() end
			compact[#compact + 1] = option
			inRuleBlock = true
		else
			if option.type == "texture" or option.type == "divider" or option.type == "description" or option.type == "header" or option.type == "submenu" or option.type == "custom" then inRuleBlock = false end
			compact[#compact + 1] = option
		end
	end
	if isRootCall and #allMigrationControls > 0 then
		for _, profile in pairs(db and db.profiles or {}) do
			if type(profile) == "table" and profile.bmrGuildAssignmentMigrationVersion ~= 1 then
				profile.rules = profile.rules or {}
				local migratedRuleGuildSpecificity = {}
				for _, legacyControl in ipairs(allMigrationControls) do
					local masterRule = profile.rules[legacyControl.bmrGuildMasterRule]
					local guildName = masterRule and masterRule.associatedGuild
					if guildName and guildName ~= "" and guildName ~= GetString(BMR_ACTION_NOTSET) then
						local patterns = type(legacyControl.bmrGuildPattern) == "table" and legacyControl.bmrGuildPattern or {legacyControl.bmrGuildPattern}
						for ruleName, ruleData in pairs(profile.rules) do
							local matches = legacyControl.bmrGuildPattern == "MiscPvp" and (string.find(ruleName, "^pvpItem_") or string.find(ruleName, "^pvpAlliance_")) ~= nil
							local specificity = 0
							if not matches then
								for _, pattern in ipairs(patterns) do
									if BMR._RuleUi.RuleNameMatchesGuildPattern(ruleName, pattern) then
										matches = true
										specificity = math.max(specificity, #pattern)
									end
								end
							end
							if matches and type(ruleData) == "table" then
								local currentGuild = ruleData.associatedGuild
								local isUnassigned = currentGuild == nil or currentGuild == "" or currentGuild == GetString(BMR_ACTION_NOTSET)
								local previousSpecificity = migratedRuleGuildSpecificity[ruleName]
								-- Existing per-item choices always win. When an old per-item value
								-- was absent, migrate the most specific matching legacy group;
								-- this matters for nested PvP alliance groups versus the old PvP-wide value.
								if isUnassigned or (previousSpecificity ~= nil and specificity > previousSpecificity) then
									ruleData.associatedGuild = guildName
									migratedRuleGuildSpecificity[ruleName] = specificity
								end
							end
						end
					end
				end
				profile.bmrGuildAssignmentMigrationVersion = 1
			end
		end
	end
	return compact
end

local function buildLAMPanel()
	BMR._panelBuildPhase = "build-start"
	BMR.ProfileDiagnostic("LAM_BUILD_BEGIN", "LAM panel build started")
	BMR._panelBuildPhase = "resolve-settings-libraries"
	local function GetIdFromName(choice)

		local charName, server = zo_strsplit("@", choice)
		local data = BMVars.Default[GetDisplayName()]
		for entryIndex, entryData in pairs(data) do
			local name = entryData["$LastCharacterName"]
			if charName == name and server == entryData.worldname then
				return entryIndex
			end
		end
	end

	local LAM2 = LibAddonMenu2
	if not LAM2 and LibStub then LAM2 = LibStub:GetLibrary("LibAddonMenu-2.0", true) end
	BMR._lamInstance = LAM2
	-- LibHarvensAddonSettings is still the in-game runtime name of the library;
	-- LibVotans is the console-store package name used for delivery.
	if type(LibHarvensAddonSettings) ~= "table" and type(LibVotansAddonSettings) == "table" then
		_G.LibHarvensAddonSettings = LibVotansAddonSettings
		LibHarvensAddonSettings = LibVotansAddonSettings
	end
	local consoleSettingsFrontend = false
	local lamConsoleConverterUsable = false
	if type(IsKeyboardUISupported) == "function" then
		local ok, keyboardSupported = pcall(IsKeyboardUISupported)
		if ok then
			consoleSettingsFrontend = (keyboardSupported == false)
			lamConsoleConverterUsable = (keyboardSupported == false)
		end
	else
		consoleSettingsFrontend = BMR.Console and type(BMR.Console.IsModeActive) == "function" and BMR.Console.IsModeActive() == true
	end
	-- ForceConsoleFlow is used on PC for testing; treat an explicit CVar activation
	-- as the console frontend even if the keyboard-capability query is inconsistent.
	if type(GetCVar) == "function" then
		local ok, value = pcall(GetCVar, "ForceConsoleFlow.2")
		if ok and (value == "1" or value == 1 or value == true) then consoleSettingsFrontend = true end
	end

	-- LibGamepad injects ordinary LAM addon panels into ESO's native gamepad
	-- Options UI and creates real nested menu pages from LAM submenus. When it
	-- is installed, prefer the untouched LAM option tree over BMR's legacy flat
	-- LibHarvensAddonSettings converter. This is particularly useful in
	-- ForceConsoleFlow on PC, where the normal keyboard frontend is not active.
	local libGamepadLoaded = false
	if type(IsAddOnLoaded) == "function" then
		local ok, loaded = pcall(IsAddOnLoaded, "LibGamepad")
		libGamepadLoaded = ok and loaded == true
	end
	-- LibGamepad groups LAM submenu sections into separate gamepad menus, but it
	-- does not preserve BMR's required multi-level parent/child PvP hierarchy.
	-- Keep the direct LHA adapter active until a verified nested adapter exists.
	local useLibGamepadFrontend = false
	if consoleSettingsFrontend and libGamepadLoaded then
		BMR.ProfileDiagnostic("LIBGAMEPAD_BYPASSED_FOR_NESTED_TREE", "LibGamepad detected; direct LHA adapter selected for BMR PvP page grouping")
	end

	BMR._consoleSettingsFrontend = consoleSettingsFrontend
	BMR._lamConsoleConverterUsable = lamConsoleConverterUsable
	BMR._libGamepadFrontend = useLibGamepadFrontend
	-- Compatibility guard for outdated LibAddonMenu copies embedded in other addons.
	-- Older LAM versions call lam.applyButton:SetHidden() unconditionally from
	-- RequestRefreshIfNeeded(), even before the settings window has created that button.
	-- Install a harmless placeholder only while the real control is absent. LAM's own
	-- CreateAddonSettingsWindow assigns the actual control later and replaces this stub.
	local function EnsureLAMApplyButtonCompatibility()
		if not LAM2 or LAM2.applyButton ~= nil then return end
		local placeholder = { bmrCompatibilityPlaceholder = true, hidden = true }
		function placeholder:SetHidden(hidden)
			self.hidden = (hidden == true)
		end
		function placeholder:IsHidden()
			return self.hidden ~= false
		end
		LAM2.applyButton = placeholder
	end

	BMR._panelBuildPhase = "install-lam-compatibility"
	-- This mouse/keyboard-only workaround is irrelevant in Forced Console Flow.
	-- Avoid touching the keyboard LAM control tree when the console frontend is active.
	if not consoleSettingsFrontend then EnsureLAMApplyButtonCompatibility() end
	-- Some controls invoke LAM-RefreshPanel before the legacy library reaches its
	-- unguarded RefreshReloadUIButton call. Restore the placeholder if it is still nil.
	if not consoleSettingsFrontend and CALLBACK_MANAGER and CALLBACK_MANAGER.RegisterCallback and not BMR.legacyLAMApplyButtonGuardRegistered then
		CALLBACK_MANAGER:RegisterCallback("LAM-RefreshPanel", EnsureLAMApplyButtonCompatibility)
		BMR.legacyLAMApplyButtonGuardRegistered = true
	end

	local panelData = {
		type = "panel",
		name = ADDON_NAME,
		displayName = displayName,
		author = ADDON_AUTHOR,
		version = ADDON_VERSION,
		website = ADDON_WEBSITE,
		registerForRefresh = true,
		registerForDefaults = true,
		slashCommand = "/bmr",
		-- Reconcile custom item rules whenever the BMR settings panel is opened.
		callback = function()
			BMR.ProfileDiagnostic("LAM_PANEL_OPEN", BMR.ProfileDebugSnapshot())
			if BMR.refreshCustomRuleOptions then
				local refreshOk, refreshError = pcall(BMR.refreshCustomRuleOptions)
				if not refreshOk then BMR.ProfileDiagnostic("CUSTOM_RULE_OPTIONS_REFRESH_ERROR", tostring(refreshError)); BMR.ProfileDiagnosticChat("Fehler beim Aktualisieren der Regel-Einstellungen: " .. tostring(refreshError)) end
			end
		end,
	}

	-- SavedVariables/profile state is now initialized before any LAM-specific work.
	-- Keep this idempotent for callers that use buildLAMPanel() directly.
	BMR._panelBuildPhase = "savedvariables-and-profile-migration"
	InitializeCoreProfileStore()
	BMR.ProfileDiagnostic("SAVEDVARS_LOADED", "profileDebugEnabled=" .. tostring(db.profileDebugEnabled) .. "; " .. BMR.ProfileDebugSnapshot())

	-- Ensure nested ScriptTracker settings exist for older saved-variable files.
	db.scriptTracker = db.scriptTracker or {}
	db.scriptTracker.enabled = db.scriptTracker.enabled ~= false
	db.scriptTracker.depositKnown = db.scriptTracker.depositKnown ~= false
	db.scriptTracker.withdrawUnknown = db.scriptTracker.withdrawUnknown ~= false
	db.scriptTracker.withdrawOneOnly = db.scriptTracker.withdrawOneOnly ~= false
	db.scriptTracker.debug = db.scriptTracker.debug == true
	db.pvpSortMode = (db.pvpSortMode == "alliance") and "alliance" or "weaponType"

	EnsureProfiles()
	BMR.ProfileDiagnostic("PROFILES_ENSURED_FIRST_PASS", BMR.ProfileDebugSnapshot())
	SyncCustomItemRuleDefinitions()
	BMR.ProfileDiagnostic("CUSTOM_RULE_DEFINITIONS_SYNCED_FIRST_PASS", "")

	NamesToIDSavedVars()
	db.customItemRules = db.customItemRules or {}
	db.customFilterRules = db.customFilterRules or {}
	db.customFilterDraft = db.customFilterDraft or {searchString = "", specifications = {}}
	db.customFilterDraft.specifications = type(db.customFilterDraft.specifications) == "table" and db.customFilterDraft.specifications or {}
	db.customFilterDraft.editingId = tonumber(db.customFilterDraft.editingId)
	db.hideSetAsBmrRule = db.hideSetAsBmrRule == true
	EnsureProfiles()
	BMR.ProfileDiagnostic("PROFILES_ENSURED_SECOND_PASS", BMR.ProfileDebugSnapshot())
	SyncCustomItemRuleDefinitions()
	BMR.CustomRules.SyncFilterRuleDefinitions()
	local customFilterCount = 0
	for _ in pairs(db.customFilterRules or {}) do customFilterCount = customFilterCount + 1 end
	BMR.ProfileDiagnostic("FILTER_RULE_DEFINITIONS_SYNCED", "customFilterRules=" .. tostring(customFilterCount))

	-- Load profile
	local characterName = GetUnitName("player")
	if type(characterName) ~= "string" or characterName == "" then characterName = nil end
	if characterName and db.actualProfile[characterName] == nil then db.actualProfile[characterName] = 1 end

	actualProfile = characterName and (tonumber(db.actualProfile[characterName]) or 1) or 1
	if actualProfile < PROFILE_MIN or actualProfile > db.profileCount then
		actualProfile = 1
		if characterName then db.actualProfile[characterName] = 1 end
	end
	EnsureProfile(actualProfile, false)
	BMR.ProfileDiagnostic("ACTIVE_PROFILE_SELECTED", BMR.ProfileDebugSnapshot())

	-- LAM's normal RegisterAddonPanel only registers the keyboard frontend. In
	-- gamepad/ForceConsoleFlow, current LAM exposes a separate converter to
	-- LibHarvensAddonSettings. Older LAM builds get the equivalent small fallback
	-- converter further below. Do not silently skip the settings panel in console UI.
	local settingsPanelId = ADDON_NAME .. "LAM2Options"
	BMR._panelBuildPhase = "register-settings-panel"
	if consoleSettingsFrontend and not useLibGamepadFrontend and (type(LibHarvensAddonSettings) ~= "table" or type(LibHarvensAddonSettings.AddAddon) ~= "function") then
		BMR.ProfileDiagnostic("CONSOLE_SETTINGS_LIBRARY_MISSING", "LibHarvensAddonSettings runtime table/AddAddon missing; falling back to standard LAM registration")
		BMR.ProfileDiagnosticChat("BMR: LibHarvensAddonSettings fehlt; Konsolen-Einstellungsseite nicht verfügbar. Standard-LAM-Seite wird dennoch registriert.")
		consoleSettingsFrontend = false
		lamConsoleConverterUsable = false
	end
	if not consoleSettingsFrontend or useLibGamepadFrontend then
		if type(LAM2) ~= "table" or type(LAM2.RegisterAddonPanel) ~= "function" or type(LAM2.RegisterOptionControls) ~= "function" then
			BMR._panelBuildPhase = "early-return-lam-unavailable"
			BMR.ProfileDiagnostic("LAM_UNAVAILABLE", "SavedVariables and profiles initialized; keyboard settings panel skipped")
			BMR.ProfileDiagnosticChat("BMR: LibAddonMenu ist nicht verfügbar. Bank-/Profilfunktionen werden trotzdem initialisiert.")
			return
		end
	end

	local panelRegisterOk, panelResult = pcall(function()
		if consoleSettingsFrontend and not useLibGamepadFrontend then
			if lamConsoleConverterUsable and type(LAM2) == "table" and type(LAM2.registerConsoleAddonPanel) == "function" then
				LAM2:registerConsoleAddonPanel(settingsPanelId, panelData)
				local stored = LAM2.LHASConversion and LAM2.LHASConversion.settingTables and LAM2.LHASConversion.settingTables[settingsPanelId]
				if stored then return stored end
			end
			-- Fallback when the installed LAM predates its console converter.
			return LibHarvensAddonSettings:AddAddon(panelData.name, {
				allowDefaults = panelData.registerForDefaults,
				allowRefresh = panelData.registerForRefresh,
			})
		end
		return LAM2:RegisterAddonPanel(settingsPanelId, panelData)
	end)
	if not panelRegisterOk or (consoleSettingsFrontend and not useLibGamepadFrontend and type(panelResult) ~= "table") then
		local errorText = tostring(panelRegisterOk and "console settings API returned no panel" or panelResult)
		BMR._panelBuildPhase = "settings-panel-registration-failed"
		BMR.ProfileDiagnostic(consoleSettingsFrontend and "CONSOLE_SETTINGS_REGISTER_FAILED" or "LAM_PANEL_REGISTER_FAILED", errorText)
		BMR.ProfileDiagnosticChat("BMR: Einstellungsfenster konnte nicht registriert werden: " .. errorText)
		return
	end
	if consoleSettingsFrontend and not useLibGamepadFrontend then panel = nil else panel = panelResult end
	BMR._consoleSettingsPanel = (consoleSettingsFrontend and not useLibGamepadFrontend) and panelResult or nil
	if not consoleSettingsFrontend and panel and CALLBACK_MANAGER and CALLBACK_MANAGER.RegisterCallback and not BMR.lamPanelLayoutCallbacksRegistered then
		BMR.lamPanelLayoutCallbacksRegistered = true
		local bmrPanelControl = panel
		BMR._lamPanel = panel
		local function HandleLamPanelLayout(openedPanel)
			if openedPanel == bmrPanelControl and BMR._RuleUi.ReflowBmrLamControls then
				-- Keep the original LAM window size. Only normalize the controls and
				-- submenu scroll areas to the panel's existing, fixed content width.
				BMR._RuleUi.ReflowBmrLamControls(bmrPanelControl)
			end
		end
		CALLBACK_MANAGER:RegisterCallback("LAM-BeforePanelControlsCreated", HandleLamPanelLayout)
		CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", HandleLamPanelLayout)
		CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", HandleLamPanelLayout)
	end
	BMR._panelBuildPhase = "settings-panel-registered-build-options"
	BMR.ProfileDiagnostic(consoleSettingsFrontend and "CONSOLE_SETTINGS_PANEL_REGISTERED" or "LAM_PANEL_REGISTERED", "settings panel created")

	-- Remove obsolete SavedVariables from the retired settings-window width option.
	db.settingsWindowWidth = nil
	db.settingsWindowWidthDefaultMigrationVersion = nil

	-- Creating LAM optionPanel following the rules.
	-- Keep console settings usable if a single category calls an unavailable API.
	local function CountOptionControls(controls)
		local count = 0
		if type(controls) == "table" then
			for index, control in pairs(controls) do
				if type(index) == "number" and type(control) == "table" then count = count + 1 end
			end
		end
		return count
	end
	BMR._consoleSubmenuControlCounts = {}
	local function BuildSettingsSubmenu(subMenuName)
		local ok, controls = pcall(LAMSubmenu, subMenuName)
		if ok and type(controls) == "table" then
			BMR._consoleSubmenuControlCounts[subMenuName] = CountOptionControls(controls)
			BMR.ProfileDiagnostic("SETTINGS_SUBMENU_BUILT", subMenuName .. ": controls=" .. tostring(BMR._consoleSubmenuControlCounts[subMenuName]))
			return controls
		end
		local err = tostring(controls or "submenu returned no table")
		if type(BMR._consoleSubmenuErrors) ~= "table" then BMR._consoleSubmenuErrors = {} end
		BMR._consoleSubmenuErrors[subMenuName] = err
		BMR._consoleSubmenuControlCounts[subMenuName] = -1
		BMR.ProfileDiagnostic("CONSOLE_SUBMENU_BUILD_FAILED", subMenuName .. ": " .. err)
		BMR.ProfileDiagnosticChat("BMR: Konsolen-Untermenü '" .. tostring(subMenuName) .. "' übersprungen: " .. err:gsub("[\r\n]+", " "):sub(1, 100))
		return {}
	end
	local currenciesSubmenuControls = BuildSettingsSubmenu("currencies")
	if db.globalAddonProfile >= 2 then
		BMR.traitSubmenuControls = BuildSettingsSubmenu("traits")
		BMR.styleSubmenuControls = BuildSettingsSubmenu("styles")
	end
	if db.globalAddonProfile >= 2 then
		BMR.jewelrycraftingSubmenuControls = BuildSettingsSubmenu("jewelrycrafting")
		BMR.blacksmithingSubmenuControls = BuildSettingsSubmenu("blacksmithing")
		BMR.clothierSubmenuControls = BuildSettingsSubmenu("clothier")
		BMR.woodworkingSubmenuControls = BuildSettingsSubmenu("woodworking")
		BMR.alchemySubmenuControls = BuildSettingsSubmenu("alchemy")
	end
	local cookingSubmenuControls = BuildSettingsSubmenu("cooking")
	local enchantmentSubmenuControls = BuildSettingsSubmenu("enchanting")
	local trophiesSubmenuControls = BuildSettingsSubmenu("trophies")
	local diverseSubmenuControls = BuildSettingsSubmenu("misc")
	local pvpSubmenuControls = BuildSettingsSubmenu("pvp")
	local containersSubmenuControls = BuildSettingsSubmenu("containers")
	local customRulesSubmenuControls = BuildSettingsSubmenu("custom")
	local housingSubmenuControls = BuildSettingsSubmenu("housing")
	local specialFiltersControls = BuildSettingsSubmenu("special")
	local ruleWriterControls = BuildSettingsSubmenu("ruleWriter")


	local charactersKnown = {}
	if BMVars and BMVars.Default and BMVars.Default[GetDisplayName()] then
		for id, data in pairs(BMVars.Default[GetDisplayName()]) do
			if data.worldname then
				if not (data.worldname == GetWorldName() and data["$LastCharacterName"] == GetUnitName("player")) then
					--table.insert(charactersKnown, data["$LastCharacterName"].."@"..data.worldname)
				end
			end
		end
	end


	local listOfProfiles = {}
	for i=1, db.profileCount do
		listOfProfiles[i] = i
	end

	-- Addon Profil dropdown choices/values
	local dropdownGlobalAddonProfileChoices = {"ESO+ no crafting", "ESO+ with crafting", "no ESO+ no crafting", "no ESO+ with crafting"}
	local dropdownGlobalAddonProfileValues = {1, 2, 3, 4}

	-- Profile transfer editor state is deliberately transient; export text is copied by
	-- the user and is not persisted in SavedVariables.
	local profileTransferText = ""
	local profileExportScope = "single"
	local profileExportChunks = {}
	local profileExportChunkIndex = 1
	local profileExportChunkChoices = {GetString(BMR_PROFILE_TRANSFER_NO_EXPORT)}
	local profileExportChunkValues = {1}
	local profileImportParts = {}
	local profileImportPartTotal = nil
	local profileImportReadyPayload = nil
	-- Resetting collected import data is guarded by a two-click confirmation so a
	-- near-miss on the adjacent Import button cannot discard a validated backup.
	local profileImportResetArmed = false
	local profileImportMode = "choose"
	local profileImportTarget = tonumber(actualProfile) or 1
	local profileImportTargetChoices = {}
	local profileImportTargetValues = {}
	local PROFILE_TRANSFER_CHUNK_SIZE = 8000
	local profileTransferTextOrigin = "none"
	local function RefreshProfileExportChunkDropdownControl()
		-- LAM builds dropdown entries only when UpdateChoices is called. Mutating the
		-- original choices arrays and refreshing the panel alone can leave the
		-- combobox stuck on "No export generated yet". Update the live control too.
		local control = _G and _G["BMRProfileExportChunkDropdown"]
		if control and type(control.UpdateChoices) == "function" and type(control.UpdateValue) == "function" then
			control:UpdateChoices(profileExportChunkChoices, profileExportChunkValues)
			control:UpdateValue()
		end
	end
	local function RefreshProfileExportChunkChoices(total)
		for index = #profileExportChunkChoices, 1, -1 do profileExportChunkChoices[index] = nil end
		for index = #profileExportChunkValues, 1, -1 do profileExportChunkValues[index] = nil end
		if not total or total < 1 then
			profileExportChunkChoices[1] = GetString(BMR_PROFILE_TRANSFER_NO_EXPORT)
			profileExportChunkValues[1] = 1
			profileExportChunkIndex = 1
			RefreshProfileExportChunkDropdownControl()
			return
		end
		for index = 1, total do
			profileExportChunkChoices[#profileExportChunkChoices + 1] = zo_strformat(GetString(BMR_PROFILE_TRANSFER_PART_CHOICE), tostring(index), tostring(total))
			profileExportChunkValues[#profileExportChunkValues + 1] = index
		end
		RefreshProfileExportChunkDropdownControl()
	end
	local function RefreshProfileImportTargetDropdownControl()
		-- Update the live LAM combobox as well as its backing arrays. This is needed
		-- when profile names change while the settings panel is already open.
		local control = _G and _G["BMRProfileImportTargetDropdown"]
		if control and type(control.UpdateChoices) == "function" and type(control.UpdateValue) == "function" then
			control:UpdateChoices(profileImportTargetChoices, profileImportTargetValues)
			control:UpdateValue()
		end
	end
	local function RefreshProfileImportTargetChoices()
		-- All numbered slots up to profileCount are valid targets, including empty
		-- profiles. Keep blank slots in the list so they can receive a test import.
		for i = #profileImportTargetChoices, 1, -1 do profileImportTargetChoices[i] = nil end
		for i = #profileImportTargetValues, 1, -1 do profileImportTargetValues[i] = nil end
		local maximum = math.max(1, math.min(tonumber(db.profileCount) or PROFILE_DEFAULT_COUNT, PROFILE_MAX))
		for index = 1, maximum do
			local profile = db.profiles and db.profiles[index]
			local name = type(profile) == "table" and tostring(profile.name or "") or ""
			local label = name ~= "" and (tostring(index) .. " - " .. name) or tostring(index)
			profileImportTargetChoices[#profileImportTargetChoices + 1] = label
			profileImportTargetValues[#profileImportTargetValues + 1] = index
		end
		profileImportTarget = math.max(1, math.min(tonumber(profileImportTarget) or tonumber(actualProfile) or 1, maximum))
		RefreshProfileImportTargetDropdownControl()
	end
	RefreshProfileImportTargetChoices()
	local PROFILE_TRANSFER_MAX_PROFILES = PROFILE_MAX
	local function MakeProfileTransferPayload(scope)
		local payload = {
			format = "BMR_PROFILE_EXPORT", version = 1, scope = scope, profiles = {},
			activeProfile = actualProfile,
			-- These definitions are account-wide rather than profile-owned, but must
			-- travel with the profile backup to recover after SavedVariables are deleted.
			definitions = {
				customItemRules = DeepCopy(db.customItemRules or {}),
				customFilterRules = DeepCopy(db.customFilterRules or {}),
			},
		}
		local firstIndex, lastIndex = actualProfile, actualProfile
		if scope == "all" then firstIndex, lastIndex = 1, db.profileCount end
		for index = firstIndex, lastIndex do
			local profile = db.profiles[index]
			if type(profile) == "table" then
				payload.profiles[#payload.profiles + 1] = {index = index, name = tostring(profile.name or ""), data = DeepCopy(profile)}
			end
		end
		return payload
	end
	local function ValidateProfileTransferPayload(payload)
		if type(payload) ~= "table" or payload.format ~= "BMR_PROFILE_EXPORT" or tonumber(payload.version) ~= 1 then
			return false, BMR_PROFILE_TRANSFER_INVALID
		end
		if payload.scope ~= "single" and payload.scope ~= "all" then return false, BMR_PROFILE_TRANSFER_INVALID end
		if type(payload.profiles) ~= "table" then return false, BMR_PROFILE_TRANSFER_INVALID end
		if payload.definitions ~= nil then
			if type(payload.definitions) ~= "table"
				or (payload.definitions.customItemRules ~= nil and type(payload.definitions.customItemRules) ~= "table")
				or (payload.definitions.customFilterRules ~= nil and type(payload.definitions.customFilterRules) ~= "table") then
				return false, BMR_PROFILE_TRANSFER_INVALID
			end
		end
		local count = #payload.profiles
		if count < 1 or count > PROFILE_TRANSFER_MAX_PROFILES then return false, BMR_PROFILE_TRANSFER_INVALID end
		if payload.scope == "single" and count ~= 1 then return false, BMR_PROFILE_TRANSFER_INVALID end
		local seenIndices = {}
		for _, record in ipairs(payload.profiles) do
			if type(record) ~= "table" or type(record.data) ~= "table" then return false, BMR_PROFILE_TRANSFER_INVALID end
			local index = tonumber(record.index)
			if payload.scope == "all" then
				if not index or index < 1 or index > PROFILE_TRANSFER_MAX_PROFILES or index % 1 ~= 0 or seenIndices[index] then return false, BMR_PROFILE_TRANSFER_INVALID end
				seenIndices[index] = true
			end
			if type(record.data.rules) ~= "table" then return false, BMR_PROFILE_TRANSFER_INVALID end
		end
		return true
	end
	local function QueueProfileTransferReload(messageStringId, detail)
		BMRProfileTransferMessage(messageStringId, detail)
		if type(zo_callLater) == "function" then zo_callLater(function() ReloadUI() end, 700) else ReloadUI() end
	end
	local function GenerateProfileExport()
		local ok, result = pcall(function() return BMRJsonEncode(MakeProfileTransferPayload(profileExportScope)) end)
		if not ok then BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_EXPORT_FAILED, result); return end
		local compressedOk, compressedOrError = pcall(function() return BMRBase64Encode(BMRLZWCompress(result)) end)
		if not compressedOk then BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_EXPORT_FAILED, tostring(compressedOrError)); return end
		profileExportChunks = {}
		local encoded = compressedOrError
		local total = math.max(1, math.ceil(#encoded / PROFILE_TRANSFER_CHUNK_SIZE))
		for index = 1, total do
			local first = (index - 1) * PROFILE_TRANSFER_CHUNK_SIZE + 1
			local part = string.sub(encoded, first, first + PROFILE_TRANSFER_CHUNK_SIZE - 1)
			profileExportChunks[index] = "BMRZ1|" .. tostring(index) .. "|" .. tostring(total) .. "|" .. part
		end
		profileImportParts, profileImportPartTotal, profileImportReadyPayload = {}, nil, nil
		RefreshProfileExportChunkChoices(total)
		profileExportChunkIndex = 1
		profileTransferText = profileExportChunks[1] or ""
		profileTransferTextOrigin = "export"
		RefreshProfileExportChunkDropdownControl()
		CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)
		BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_EXPORTED_PARTS, tostring(#result), tostring(total))
	end
	local function CollectProfileImportPart()
		profileImportResetArmed = false
		local ok, index, total, partData = pcall(BMRParseProfileExportChunk, profileTransferText)
		if not ok then BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_IMPORT_FAILED, tostring(index)); return end
		if not index then
			BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_PART_REQUIRED)
			return
		end
		-- Starting again with part 1 of a different backup must not mix it with a
		-- partially collected backup left in the UI session.
		if profileImportReadyPayload then
			if index ~= 1 then
				BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_PARTS_RESET_REQUIRED)
				return
			end
			profileImportParts, profileImportPartTotal, profileImportReadyPayload = {}, nil, nil
		end
		if index == 1 and profileImportPartTotal ~= nil then
			local previousFirst = profileImportParts[1]
			if profileImportPartTotal ~= total or (previousFirst and previousFirst ~= partData) then
				profileImportParts, profileImportPartTotal = {}, nil
			end
		end
		if profileImportPartTotal and profileImportPartTotal ~= total then
			BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_PART_TOTAL_MISMATCH, tostring(profileImportPartTotal), tostring(total))
			return
		end
		profileImportPartTotal = total
		profileImportParts[index] = partData
		profileTransferText = ""
		profileTransferTextOrigin = "none"
		local received = 0
		for partIndex = 1, total do if profileImportParts[partIndex] then received = received + 1 end end
		if received == total then
			local encodedParts = {}
			for partIndex = 1, total do
				if not profileImportParts[partIndex] then
					BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_PARTS_MISSING)
					CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)
					return
				end
				encodedParts[#encodedParts + 1] = profileImportParts[partIndex]
			end
			local decodeOk, payload = pcall(BMRDecodeCompressedProfileExport, table.concat(encodedParts))
			if not decodeOk then BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_IMPORT_FAILED, tostring(payload)); CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel); return end
			local valid, errorStringId = ValidateProfileTransferPayload(payload)
			if not valid then BMRProfileTransferMessage(errorStringId); CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel); return end
			profileImportReadyPayload = payload
			BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_PARTS_READY, tostring(total))
		else
			BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_PART_RECEIVED, tostring(index), tostring(total), tostring(received))
		end
		CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)
	end
	local function ResetProfileImportParts()
		local hasPendingData = profileImportPartTotal ~= nil
			or profileImportReadyPayload ~= nil
			or (type(profileTransferText) == "string" and string.match(profileTransferText, "%S") ~= nil)
		if hasPendingData and not profileImportResetArmed then
			profileImportResetArmed = true
			BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_RESET_CONFIRM)
			CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)
			return
		end
		profileImportResetArmed = false
		profileImportParts, profileImportPartTotal, profileImportReadyPayload = {}, nil, nil
		profileTransferText = ""
		profileTransferTextOrigin = "none"
		CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)
		BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_PARTS_RESET)
	end
	local function GetProfileTransferTextStatus()
		if profileTransferTextOrigin == "export" and #profileExportChunks > 0 then
			return zo_strformat(GetString(BMR_PROFILE_TRANSFER_EXPORT_ACTIVE_STATUS), tostring(profileExportChunkIndex), tostring(#profileExportChunks))
		end
		local parseOk, partIndex, partTotal = pcall(BMRParseProfileExportChunk, profileTransferText)
		if profileTransferTextOrigin == "input" and parseOk and partIndex then
			return zo_strformat(GetString(BMR_PROFILE_TRANSFER_IMPORT_PART_DETECTED), tostring(partIndex), tostring(partTotal))
		end
		if profileImportPartTotal then
			local received = 0
			for index = 1, profileImportPartTotal do if profileImportParts[index] then received = received + 1 end end
			return zo_strformat(GetString(BMR_PROFILE_TRANSFER_IMPORT_PROGRESS), tostring(received), tostring(profileImportPartTotal))
		end
		return GetString(BMR_PROFILE_TRANSFER_TEXT_DESC)
	end
	local function ImportProfileTransfer()
		-- Importing takes precedence over an armed reset confirmation. This is important
		-- when the user has already collected all parts and the text box is empty by design.
		profileImportResetArmed = false
		if profileImportReadyPayload and tostring(profileTransferText or "") ~= "" then
			BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_PARTS_RESET_REQUIRED)
			return
		end
		local payload = profileImportReadyPayload
		if not payload then
			if type(profileTransferText) ~= "string" or string.match(profileTransferText, "%S") == nil then
				BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_PART_REQUIRED)
				return
			end
			local chunkOk, chunkIndex, chunkTotal, chunkData = pcall(BMRParseProfileExportChunk, profileTransferText)
			if not chunkOk then BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_IMPORT_FAILED, tostring(chunkIndex)); return end
			if chunkIndex then
				if chunkTotal ~= 1 then BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_PARTS_REQUIRED); return end
				local ok, decoded = pcall(BMRDecodeCompressedProfileExport, chunkData)
				if not ok then BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_IMPORT_FAILED, tostring(decoded)); return end
				payload = decoded
			else
				local ok, decoded = pcall(BMRJsonDecode, profileTransferText)
				if not ok then BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_IMPORT_FAILED, tostring(decoded)); return end
				payload = decoded
			end
		end
		local valid, errorStringId = ValidateProfileTransferPayload(payload)
		if not valid then BMRProfileTransferMessage(errorStringId); return end
		if profileImportMode ~= "overwrite" and profileImportMode ~= "append" and profileImportMode ~= "restoreAll" then
			BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_CHOOSE_ACTION_REQUIRED)
			return
		end
		if payload.scope == "all" and profileImportMode ~= "restoreAll" then
			BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_ALL_NEEDS_RESTORE)
			return
		end
		if payload.scope == "single" and profileImportMode == "restoreAll" then
			BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_RESTORE_NEEDS_ALL)
			return
		end
		local function DefinitionEquals(left, right)
			if type(left) ~= "table" or type(right) ~= "table" then return false end
			local leftOk, leftText = pcall(BMRJsonEncode, left)
			local rightOk, rightText = pcall(BMRJsonEncode, right)
			return leftOk and rightOk and leftText == rightText
		end
		local function MergeImportedDefinitions(definitions)
			local filterIdRemap = {}
			definitions = type(definitions) == "table" and definitions or {}
			db.customItemRules = type(db.customItemRules) == "table" and db.customItemRules or {}
			db.customFilterRules = type(db.customFilterRules) == "table" and db.customFilterRules or {}

			-- Exact-item definitions are account-wide. Merge by item ID without changing
			-- any existing profile's action settings.
			for itemId, itemData in pairs(definitions.customItemRules or {}) do
				if type(itemData) == "table" then
					local numericId = tonumber(itemData.itemId or itemId)
					if numericId and numericId > 0 then
						db.customItemRules[tostring(numericId)] = DeepCopy(itemData)
					end
				end
			end

			local nextFilterId = 0
			for key, data in pairs(db.customFilterRules) do
				nextFilterId = math.max(nextFilterId, tonumber(key) or 0)
				if type(data) == "table" then
					nextFilterId = math.max(nextFilterId, tonumber(data.id) or 0)
				end
			end

			for sourceKey, sourceData in pairs(definitions.customFilterRules or {}) do
				if type(sourceData) == "table" then
					local sourceId = tonumber(sourceData.id) or tonumber(sourceKey)
					if sourceId and sourceId >= 1 and sourceId % 1 == 0 then
						local sourceIdString = tostring(sourceId)
						local existing = db.customFilterRules[sourceIdString] or db.customFilterRules[sourceId]
						local destinationId = sourceId
						if existing and not DefinitionEquals(existing, sourceData) then
							repeat
								nextFilterId = nextFilterId + 1
							until not db.customFilterRules[tostring(nextFilterId)] and not db.customFilterRules[nextFilterId]
							destinationId = nextFilterId
						end
						filterIdRemap[sourceIdString] = destinationId
						if not existing or destinationId ~= sourceId then
							local importedDefinition = DeepCopy(sourceData)
							importedDefinition.id = destinationId
							db.customFilterRules[tostring(destinationId)] = importedDefinition
							db.customFilterRules[destinationId] = nil
						end
					end
				end
			end
			return filterIdRemap
		end

		local function CopyImportedProfile(record, filterIdRemap)
			local copied = DeepCopy(record.data)
			copied.name = tostring(copied.name or record.name or "")
			copied.defined = true
			copied.rules = type(copied.rules) == "table" and copied.rules or {}
			for ruleName, ruleData in pairs(DeepCopy(copied.rules)) do
				local oldId = string.match(tostring(ruleName), "^customFilter_(%d+)$")
				local newId = oldId and filterIdRemap and filterIdRemap[oldId]
				if newId and tostring(newId) ~= oldId then
					copied.rules["customFilter_" .. tostring(newId)] = DeepCopy(ruleData)
					copied.rules[ruleName] = nil
				end
			end
			return copied
		end
		if payload.scope == "all" and profileImportMode == "restoreAll" then
			local importedProfiles, highest = {}, 1
			for _, record in ipairs(payload.profiles) do
				local index = tonumber(record.index)
				importedProfiles[index] = CopyImportedProfile(record)
				if index > highest then highest = index end
			end
			db.profiles = importedProfiles
			db.customItemRules = DeepCopy((payload.definitions and payload.definitions.customItemRules) or {})
			db.customFilterRules = DeepCopy((payload.definitions and payload.definitions.customFilterRules) or {})
			db.profileCount = highest
			db.profileCountInitialized = true
			for index = 1, highest do if not db.profiles[index] then db.profiles[index] = NewProfile(index == 1) end end
			EnsureProfiles()
			SyncCustomItemRuleDefinitions()
			if BMR.CustomRules and BMR.CustomRules.SyncFilterRuleDefinitions then BMR.CustomRules.SyncFilterRuleDefinitions() end
			actualProfile = math.max(1, math.min(tonumber(payload.activeProfile) or actualProfile, db.profileCount))
			db.actualProfile[characterName] = actualProfile
			QueueProfileTransferReload(BMR_PROFILE_TRANSFER_RESTORED_ALL, tostring(highest))
		elseif profileImportMode == "append" then
			if db.profileCount >= PROFILE_TRANSFER_MAX_PROFILES then BMRProfileTransferMessage(BMR_PROFILE_TRANSFER_PROFILE_LIMIT); return end
			local filterIdRemap = MergeImportedDefinitions(payload.definitions)
			local newIndex = db.profileCount + 1
			db.profileCount = newIndex
			db.profileCountInitialized = true
			db.profiles[newIndex] = CopyImportedProfile(payload.profiles[1], filterIdRemap)
			EnsureProfile(newIndex, true)
			SyncCustomItemRuleDefinitions()
			if BMR.CustomRules and BMR.CustomRules.SyncFilterRuleDefinitions then BMR.CustomRules.SyncFilterRuleDefinitions() end
			actualProfile = newIndex
			db.actualProfile[characterName] = newIndex
			QueueProfileTransferReload(BMR_PROFILE_TRANSFER_IMPORTED_NEW, tostring(newIndex))
		else
			local filterIdRemap = MergeImportedDefinitions(payload.definitions)
			local targetIndex = math.max(1, math.min(tonumber(profileImportTarget) or tonumber(actualProfile) or 1, db.profileCount))
			db.profiles[targetIndex] = CopyImportedProfile(payload.profiles[1], filterIdRemap)
			EnsureProfile(targetIndex, true)
			SyncCustomItemRuleDefinitions()
			if BMR.CustomRules and BMR.CustomRules.SyncFilterRuleDefinitions then BMR.CustomRules.SyncFilterRuleDefinitions() end
			actualProfile = targetIndex
			db.actualProfile[characterName] = targetIndex
			QueueProfileTransferReload(BMR_PROFILE_TRANSFER_IMPORTED_OVERWRITE, tostring(targetIndex))
		end
	end

	-- Build panel
	local optionsTable = {
		{
			type = "dropdown",
			name = GetString(BMR_GLOBAL_ADDON_PROFILE),
			tooltip = zo_strformat(GetString(BMR_GLOBAL_ADDON_PROFILE_TOOLTIP), defaults["globalAddonProfile"]),
			choices = dropdownGlobalAddonProfileChoices,
			choicesValues = dropdownGlobalAddonProfileValues,
			getFunc = function() return db.globalAddonProfile end,
			setFunc = function(value)
				BMR.ProfileDiagnostic("GLOBAL_ADDON_PROFILE_CHANGED", "old=" .. tostring(db.globalAddonProfile) .. "; new=" .. tostring(value))
				db.globalAddonProfile = value
				ReloadUI();
			end,
			default = defaults["globalAddonProfile"],
		},
		{
			type = "slider",
			name = GetString(BMR_PROFILE_COUNT),
			tooltip = GetString(BMR_PROFILE_COUNT_TOOLTIP),
			min = PROFILE_MIN,
			max = PROFILE_MAX,
			step = 1,
			getFunc = function() return db.profileCount end,
			setFunc = function(value)
				BMR.ProfileDiagnostic("PROFILE_COUNT_CHANGE_BEGIN", "old=" .. tostring(db.profileCount) .. "; requested=" .. tostring(value))
				value = math.max(PROFILE_MIN, math.min(PROFILE_MAX, math.floor(tonumber(value) or PROFILE_DEFAULT_COUNT)))
				db.profileCount = value
				EnsureProfiles()
				BMR.ProfileDiagnostic("PROFILE_COUNT_CHANGE_END", BMR.ProfileDebugSnapshot())
				if actualProfile > value then
					actualProfile = 1
					db.actualProfile[characterName] = 1
				end
				ReloadUI()
			end,
			default = PROFILE_DEFAULT_COUNT,
		},
		{
			type = "button",
			name = GetString(BMR_GUI_POSITION_RESET),
			tooltip = GetString(BMR_GUI_POSITION_RESET_TOOLTIP),
			width = "full",
			func = function()
				-- Restore the profile-switch UI to the safe default position.
				db.gui_x = defaults.gui_x
				db.gui_y = defaults.gui_y
				BankManager:ClearAnchors()
				BankManager:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, db.gui_x, db.gui_y)
				BMR.ProfileDiagnostic("GUI_POSITION_RESET", "gui_x=" .. tostring(db.gui_x) .. "; gui_y=" .. tostring(db.gui_y))
			end,
		},
		{	-- Profile list
			type = "submenu",
			name = zo_strformat(GetString(BMR_PROFILES)),
			controls = {
				{
					type = "dropdown",
					name = GetString(BMR_PROFILE_LIST),
					tooltip = GetString(BMR_PROFILE_LIST_TOOLTIP),
					choices = listOfProfiles,
					width = "full",
					getFunc = function() return db.actualProfile[characterName] end,
					setFunc = function(choice)
						BMR.ProfileDiagnostic("SETTINGS_PROFILE_DROPDOWN_BEGIN", "choice=" .. tostring(choice) .. "; " .. BMR.ProfileDebugSnapshot())
						actualProfile = tonumber(choice)
						if not actualProfile or actualProfile < PROFILE_MIN or actualProfile > db.profileCount then
							BMR.ProfileDiagnostic("SETTINGS_PROFILE_DROPDOWN_INVALID", "choice=" .. tostring(choice) .. "; profileCount=" .. tostring(db.profileCount))
							actualProfile = 1
						end
						EnsureProfile(actualProfile, true)
						db.actualProfile[characterName] = actualProfile
						profileImportTarget = actualProfile
						local refreshOk, refreshError = pcall(CALLBACK_MANAGER.FireCallbacks, CALLBACK_MANAGER, "LAM-RefreshPanel", panel)
						if not refreshOk then BMR.ProfileDiagnostic("SETTINGS_PROFILE_REFRESH_ERROR", tostring(refreshError)); BMR.ProfileDiagnosticChat("Fehler bei Profil-Aktualisierung: " .. tostring(refreshError)) end
						BMR.ProfileDiagnostic("SETTINGS_PROFILE_DROPDOWN_END", BMR.ProfileDebugSnapshot())
					end,
				},
				{
					type = "editbox",
					name = GetString(BMR_PROFILE_NAME),
					tooltip = GetString(BMR_PROFILE_NAME_TOOLTIP),
					width = "full",
					getFunc = function() return db.profiles[actualProfile].name end,
					setFunc = function(choice)
						db.profiles[actualProfile].name = choice
						RefreshProfileImportTargetChoices()
						CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)
					end,
				},
				{
					type = "button",
					name = GetString(BMR_PROFILE_RESET),
					tooltip = GetString(BMR_PROFILE_RESET_TOOLTIP),
					width = "full",
					func = function()
						local profileToDelete = actualProfile
						actualProfile = 1
						db.actualProfile[characterName] = "1"
						db.profiles[profileToDelete] = NewProfile(false)
					EnsureProfile(profileToDelete, false)
					end,
				},
				{
					type = "submenu",
					name = GetString(BMR_PROFILE_TRANSFER_TITLE),
					controls = {
						{
							type = "dropdown",
							name = GetString(BMR_PROFILE_TRANSFER_EXPORT_SCOPE),
							choices = {GetString(BMR_PROFILE_TRANSFER_CURRENT), GetString(BMR_PROFILE_TRANSFER_ALL)},
							choicesValues = {"single", "all"},
							getFunc = function() return profileExportScope end,
							setFunc = function(value) profileExportScope = value end,
							width = "full",
						},
						{
							type = "button",
							name = GetString(BMR_PROFILE_TRANSFER_EXPORT_BUTTON),
							tooltip = GetString(BMR_PROFILE_TRANSFER_EXPORT_TOOLTIP),
							width = "full",
							func = GenerateProfileExport,
						},
						{
							type = "dropdown",
							name = GetString(BMR_PROFILE_TRANSFER_EXPORT_PART),
							tooltip = GetString(BMR_PROFILE_TRANSFER_EXPORT_PART_TOOLTIP),
							reference = "BMRProfileExportChunkDropdown",
							choices = profileExportChunkChoices,
							choicesValues = profileExportChunkValues,
							getFunc = function() return profileExportChunkIndex end,
							setFunc = function(value)
								profileExportChunkIndex = tonumber(value) or 1
								profileTransferText = profileExportChunks[profileExportChunkIndex] or ""
								profileTransferTextOrigin = #profileExportChunks > 0 and "export" or "none"
								CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)
							end,
							width = "full",
						},
						{
							type = "description",
							text = GetProfileTransferTextStatus,
						},
						{
							type = "editbox",
							name = GetString(BMR_PROFILE_TRANSFER_TEXT),
							tooltip = GetString(BMR_PROFILE_TRANSFER_TEXT_TOOLTIP),
							width = "full",
							isMultiline = true,
							-- LAM's editbox option is maxChars (maxInputChars is the lower-level ESO API name).
							maxChars = 5000000,
							maxInputChars = 5000000,
							getFunc = function() return profileTransferText end,
							setFunc = function(value)
								profileTransferText = tostring(value or "")
								profileTransferTextOrigin = profileTransferText ~= "" and "input" or "none"
								profileImportResetArmed = false
							end,
						},
						{
							type = "dropdown",
							name = GetString(BMR_PROFILE_TRANSFER_TARGET),
							tooltip = GetString(BMR_PROFILE_TRANSFER_TARGET_TOOLTIP),
							reference = "BMRProfileImportTargetDropdown",
							choices = profileImportTargetChoices,
							choicesValues = profileImportTargetValues,
							getFunc = function() return profileImportTarget end,
							setFunc = function(value)
								profileImportTarget = tonumber(value) or tonumber(actualProfile) or 1
							end,
							-- Keep target selection enabled even while the user is still choosing an
							-- import mode. Previously this dropdown started disabled (mode="choose")
							-- and LAM did not reliably refresh its enabled state after mode selection.
							width = "full",
						},
						{
							type = "dropdown",
							name = GetString(BMR_PROFILE_TRANSFER_IMPORT_MODE),
							choices = {GetString(BMR_PROFILE_TRANSFER_OVERWRITE), GetString(BMR_PROFILE_TRANSFER_APPEND), GetString(BMR_PROFILE_TRANSFER_RESTORE_ALL)},
							choicesValues = {"overwrite", "append", "restoreAll"},
							getFunc = function() return profileImportMode end,
							setFunc = function(value)
								profileImportMode = value
								CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)
							end,
							width = "full",
						},
						{
							type = "button",
							name = GetString(BMR_PROFILE_TRANSFER_COLLECT_PART),
							tooltip = GetString(BMR_PROFILE_TRANSFER_COLLECT_PART_TOOLTIP),
							width = "full",
							func = CollectProfileImportPart,
						},
						{
							type = "button",
							name = GetString(BMR_PROFILE_TRANSFER_IMPORT_BUTTON),
							tooltip = GetString(BMR_PROFILE_TRANSFER_IMPORT_TOOLTIP),
							width = "full",
							func = ImportProfileTransfer,
						},
						{
							type = "button",
							name = GetString(BMR_PROFILE_TRANSFER_RESET_PARTS),
							tooltip = GetString(BMR_PROFILE_TRANSFER_RESET_PARTS_TOOLTIP),
							width = "full",
							func = ResetProfileImportParts,
						},
					},
				},
				{
					type = "submenu",
					name = GetString(BMR_PROFILE_DEBUG_TITLE),
					controls = {
						{
							type = "checkbox",
							name = GetString(BMR_PROFILE_DEBUG_ENABLE),
							tooltip = GetString(BMR_PROFILE_DEBUG_ENABLE_TOOLTIP),
							getFunc = function() return db.profileDebugEnabled == true end,
							setFunc = function(value)
								local enable = value == true
								if enable then
									db.profileDebugEnabled = true
									BMR.ProfileDiagnosticFlushPreInit()
									BMR.ProfileDiagnostic("DIAGNOSTICS_ENABLED", BMR.ProfileDebugSnapshot())
									BMR.ProfileDiagnosticChat("Diagnose aktiviert. Jetzt /reloadui ausführen, den Fehler reproduzieren und anschließend den Diagnosebericht ausgeben.")
								else
									BMR.ProfileDiagnostic("DIAGNOSTICS_DISABLED", BMR.ProfileDebugSnapshot())
								db.profileDebugEnabled = false
									BMR.ProfileDiagnosticChat("Diagnose deaktiviert; vorhandene Protokolle bleiben gespeichert.")
								end
							end,
						},
						{
							type = "description",
							text = GetString(BMR_PROFILE_DEBUG_DESC),
						},
						{
							type = "button",
							name = GetString(BMR_PROFILE_DEBUG_DUMP),
							tooltip = GetString(BMR_PROFILE_DEBUG_DUMP_TOOLTIP),
							width = "full",
							func = function() BMR.ProfileDiagnosticDump() end,
						},
						{
							type = "button",
							name = GetString(BMR_PROFILE_DEBUG_CLEAR),
							tooltip = GetString(BMR_PROFILE_DEBUG_CLEAR_TOOLTIP),
							width = "full",
							func = function()
								db.profileDebugLog = {}
								BMR.ProfileDiagnostic("DIAGNOSTIC_LOG_CLEARED", BMR.ProfileDebugSnapshot())
								BMR.ProfileDiagnosticChat("Protokoll geleert.")
							end,
						},
					},
				},
			},
		},
		{
			type = "submenu",
			name = GetString(BMR_SETTINGS),
			controls = {
				{	-- Auto Transfer
					type = "checkbox",
					name = GetString(BMR_AUTO_TRANSFERT),
					tooltip = GetString(BMR_AUTO_TRANSFERT_TOOLTIP),
					getFunc = function() return db.profiles[actualProfile].autoTransfert end,
					setFunc = function(value) db.profiles[actualProfile].autoTransfert = value end,
					default = true,
				},
				{	-- Detailed move/stack
					type = "checkbox",
					name = GetString(BMR_STACK_DETAILLED),
					tooltip = GetString(BMR_STACK_DETAILLED_TOOLTIP),
					getFunc = function() return db.profiles[actualProfile].detailledDisplay end,
					setFunc = function(value) db.profiles[actualProfile].detailledDisplay = value end,
					default = true,
				},
				{	-- Detailed non moved
					type = "checkbox",
					name = GetString(BMR_STACK_DETAILLED_NOTMOVED),
					tooltip = GetString(BMR_STACK_DETAILLED_NOTMOVED_TOOLTIP),
					getFunc = function() return db.profiles[actualProfile].detailledNotMoved end,
					setFunc = function(value) db.profiles[actualProfile].detailledNotMoved = value end,
					default = true,
				},
				{	-- Display Summary
					type = "checkbox",
					name = GetString(BMR_DISPLAY_SUMMARY),
					tooltip = GetString(BMR_DISPLAY_SUMMARY_TOOLTIP),
					getFunc = function() return db.profiles[actualProfile].summary end,
					setFunc = function(value) db.profiles[actualProfile].summary = value end,
					default = true,
				},
				{	-- Display Summary
					type = "checkbox",
					name = GetString(BMR_DONT_MOVE_PROTECTED_ITEMS),
					tooltip = GetString(BMR_DONT_MOVE_PROTECTED_ITEMS_TOOLTIP),
					getFunc = function() return db.profiles[actualProfile].protected end,
					setFunc = function(value) db.profiles[actualProfile].protected = value end,
					default = true,
				},
				{	-- Protect 3rd party moves
					type = "checkbox",
					name = GetString(BMR_DONT_MOVE_MOVED_ITEMS),
					tooltip = GetString(BMR_DONT_MOVE_MOVED_ITEMS_TOOLTIP),
					getFunc = function() return db.profiles[actualProfile].moved end,
					setFunc = function(value) db.profiles[actualProfile].moved = value end,
					default = true,
				},
				{	-- Wait at startup
					type = "slider",
					name = GetString(BMR_WAIT_AT_STARTUP),
					tooltip = GetString(BMR_WAIT_AT_STARTUP_TOOLTIP),
					step = 0.5,
					min = 1,
					max = 4,
					getFunc = function() return db.profiles[actualProfile].initialWaitInSecs end,
					setFunc = function(value) db.profiles[actualProfile].initialWaitInSecs = value end,
					default = 2,
				},
				{	-- Don't overfill bags
					type = "slider",
					name = GetString(BMR_NO_OVERFILL),
					tooltip = GetString(BMR_NO_OVERFILL_TOOLTIP),
					step = 1,
					min = 0,
					max = 20,
					getFunc = function() return db.profiles[actualProfile].overfill end,
					setFunc = function(value) db.profiles[actualProfile].overfill = value end,
					default = 0,
				},
				{	-- Pause in Ms between moves
					type = "slider",
					name = GetString(BMR_DELAY_BETWEEN_MOVES),
					tooltip = GetString(BMR_DELAY_BETWEEN_MOVES_TOOLTIP),
					step = 10,
					min = 0,
					max = 110,
					getFunc = function() return db.profiles[actualProfile].pauseInMs end,
					setFunc = function(value) db.profiles[actualProfile].pauseInMs = value end,
					default = 0,
				},
			},
		},
		{
			type = "submenu",
			name = zo_strformat(GetString(SI_INVENTORY_CURRENCIES)),
			controls = currenciesSubmenuControls,
		},
		{
			type = "submenu",
			name = GetString(BMR_CUSTOM_RULES),
			controls = customRulesSubmenuControls,
		},
		{
			type = "submenu",
			name = GetString(BMR_SCRIPTTRACKER),
			controls = {
				{
					type = "description",
					text = GetString(BMR_SCRIPTTRACKER_DESC),
					width = "full",
				},
				{
					type = "checkbox",
					name = GetString(BMR_SCRIPTTRACKER_ENABLE),
					tooltip = GetString(BMR_SCRIPTTRACKER_ENABLE_TOOLTIP),
					getFunc = function() return db.scriptTracker.enabled end,
					setFunc = function(v) db.scriptTracker.enabled = v end,
					default = true,
					disabled = function() return ScriptTracker == nil end,
				},
				{
					type = "checkbox",
					name = GetString(BMR_SCRIPTTRACKER_DEPOSIT_KNOWN),
					getFunc = function() return db.scriptTracker.depositKnown end,
					setFunc = function(v) db.scriptTracker.depositKnown = v end,
					default = true,
				},
				{
					type = "checkbox",
					name = GetString(BMR_SCRIPTTRACKER_WITHDRAW_UNKNOWN),
					getFunc = function() return db.scriptTracker.withdrawUnknown end,
					setFunc = function(v) db.scriptTracker.withdrawUnknown = v end,
					default = true,
				},
				{
					type = "checkbox",
					name = GetString(BMR_SCRIPTTRACKER_ONE_ONLY),
					tooltip = GetString(BMR_SCRIPTTRACKER_ONE_ONLY_TOOLTIP),
					getFunc = function() return db.scriptTracker.withdrawOneOnly end,
					setFunc = function(v) db.scriptTracker.withdrawOneOnly = v end,
					default = true,
				},
				{
					type = "checkbox",
					name = GetString(BMR_SCRIPTTRACKER_DEBUG),
					tooltip = GetString(BMR_SCRIPTTRACKER_DEBUG_TOOLTIP),
					getFunc = function() return db.scriptTracker.debug end,
					setFunc = function(v) db.scriptTracker.debug = v end,
					default = false,
				},
			},
		},
		{
			type = "submenu",
			name = GetString(BMR_CONTAINERS),
			controls = containersSubmenuControls,
		},
		{
			type = "submenu",
			name =  GetString("SI_ITEMTYPE", ITEMTYPE_TROPHY),
			controls = trophiesSubmenuControls,
		},
		{
			type = "submenu",
			name = GetString(SI_PLAYER_MENU_MISC),
			controls = diverseSubmenuControls,
		},
		{
			type = "submenu",
			name = zo_strformat("<<1>> : <<2>>", GetString(SI_JOURNAL_MENU_QUESTS), GetString("SI_QUESTTYPE", QUEST_TYPE_CRAFTING)),
			controls = specialFiltersControls,
		},
		{
			type = "submenu",
			name = GetString(BMR_PVP_CATEGORY),
			-- LHA has one drill-down level. Keep child groups inside this page as
			-- headings instead of registering them as independent main categories.
			bmrConsoleFlattenChildren = true,
			controls = pvpSubmenuControls,
		},
		{
			type = "submenu",
			name =  GetString(SI_HOUSING_BOOK_TITLE),
			controls = housingSubmenuControls,
		},

		--[[
          {
              type = "submenu",
              name = GetString(BMR_PROFILES),
              controls = ruleWriterControls,
          },

        ]]
		--[[
          {
              type = "dropdown",
              name = GetString(BMR_IMPORT),
              tooltip = GetString(BMR_IMPORT_DESC),
              choices = charactersKnown,
              width = "full",
              getFunc = function() return GetUnitName('player') end,
              warning = "ReloadUI",
              setFunc = function(choice)

                  local playerId = GetCurrentCharacterId()
                  local referenceId = GetIdFromName(choice)

                  if referenceId then

                      for entryIndex, entryData in pairs(BMVars.Default[GetDisplayName()][referenceId]) do
                          if entryIndex ~= "$LastCharacterName" then
                              db[entryIndex] = entryData
                              BMVars.Default[GetDisplayName()][playerId][entryIndex] = entryData
                          end
                      end

                      SCENE_MANAGER:ShowBaseScene()
                      BMR.SafeAddChatMessage(zo_strformat(BMR_IMPORTED, choice))

                      zo_callLater(function() ReloadUI() end, 2000)

                  end
              end
          },
          --]]
	}

	-- Append crafting categories in the same order as the settings panel layout requested by the user.
	if db.globalAddonProfile >= 3 then
		table.insert(optionsTable, {
			type = "submenu",
			name = zo_strformat("<<1>> & <<2>> & <<3>>", GetString("SI_ITEMTYPE", ITEMTYPE_ARMOR_TRAIT), GetString("SI_ITEMTYPE", ITEMTYPE_WEAPON_TRAIT), GetString("SI_ITEMTYPE", ITEMTYPE_JEWELRY_TRAIT)),
			controls = BMR.traitSubmenuControls,
		})
		table.insert(optionsTable, {
			type = "submenu",
			name = zo_strformat("<<1>>", GetString("SI_ITEMTYPE", ITEMTYPE_STYLE_MATERIAL)),
			controls = BMR.styleSubmenuControls,
		})
		table.insert(optionsTable, {
			type = "submenu",
			name = zo_strformat("<<1>>", GetString(BMR_TRADESKILL_ALCHEMY)),
			controls = BMR.alchemySubmenuControls,
		})
	end
	if db.globalAddonProfile >= 2 then
		table.insert(optionsTable, {
			type = "submenu",
			name = zo_strformat("<<1>>", GetString(BMR_TRADESKILL_BLACKSMITHING)),
			controls = BMR.blacksmithingSubmenuControls,
		})
		table.insert(optionsTable, {
			type = "submenu",
			name = zo_strformat("<<1>>", GetString(BMR_TRADESKILL_CLOTHIER)),
			controls = BMR.clothierSubmenuControls,
		})
		table.insert(optionsTable, {
			type = "submenu",
			name = zo_strformat("<<1>>", GetString(BMR_TRADESKILL_WOODWORKING)),
			controls = BMR.woodworkingSubmenuControls,
		})
		table.insert(optionsTable, {
			type = "submenu",
			name = zo_strformat("<<1>>", GetString(BMR_TRADESKILL_JEWELRYCRAFTING)),
			controls = BMR.jewelrycraftingSubmenuControls,
		})
	end
	table.insert(optionsTable, {
		type = "submenu",
		name = zo_strformat("<<1>>", GetString(BMR_TRADESKILL_PROVISIONING)),
		controls = cookingSubmenuControls,
	})
	table.insert(optionsTable, {
		type = "submenu",
		name = zo_strformat("<<1>>", GetString(BMR_TRADESKILL_ENCHANTING)),
		controls = enchantmentSubmenuControls,
	})

	-- Item-level guild routing reuses each rule's existing associatedGuild field.
	-- The old group selectors are hidden after their previous values have been
	-- migrated into individual rules, so SavedVariables grow only by one migration flag.
	optionsTable = BMR._RuleUi.NormalizeBmrRuleOptionTree(optionsTable)
	BMR.refreshCustomRuleOptions = function()
		EnsureLAMApplyButtonCompatibility()
		if BMR.refreshingCustomRuleOptions then
			BMR.ProfileDiagnostic("CUSTOM_RULE_REFRESH_SKIPPED", "refresh already in progress")
			return
		end
		BMR.refreshingCustomRuleOptions = true
		BMR.ProfileDiagnostic("CUSTOM_RULE_REFRESH_BEGIN", BMR.ProfileDebugSnapshot())
		local refreshOk, refreshError = pcall(function()
			SyncCustomItemRuleDefinitions()
			-- LAM keeps its control tree after the first open. Refresh the custom list widget
			-- directly, then refresh existing profile/shared controls through LAM.
			local dynamicList = _G.BMRCustomRuleDynamicList
			if dynamicList and dynamicList.UpdateValue then dynamicList:UpdateValue() elseif dynamicList then BMR.CustomRules.RefreshCustomRuleList(dynamicList) end
			local filterEditor = _G.BMRCustomFilterRuleEditor
			if filterEditor and filterEditor.bmrDraftSummary then BMR.CustomRules.RefreshCustomFilterRuleEditor(filterEditor) end
			local filterList = _G.BMRCustomFilterRuleDynamicList
			if filterList and filterList.UpdateValue then filterList:UpdateValue() elseif filterList then BMR.CustomRules.RefreshCustomFilterRuleList(filterList) end
			CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)
			local consoleSettings = BMR._consoleSettingsPanel
			if consoleSettings then
				if type(consoleSettings.RefreshSettings) == "function" then
					consoleSettings:RefreshSettings()
				elseif type(consoleSettings.UpdateControls) == "function" then
					consoleSettings:UpdateControls()
				end
			end
		end)
		BMR.refreshingCustomRuleOptions = false
		if not refreshOk then
			BMR.ProfileDiagnostic("CUSTOM_RULE_REFRESH_ERROR", tostring(refreshError) .. "; " .. BMR.ProfileDebugSnapshot())
			BMR.ProfileDiagnosticChat("Fehler beim Aktualisieren eigener Regeln: " .. tostring(refreshError) .. ". Bitte Diagnosebericht sichern.")
		else
			BMR.ProfileDiagnostic("CUSTOM_RULE_REFRESH_END", BMR.ProfileDebugSnapshot())
		end
	end

	if consoleSettingsFrontend and not useLibGamepadFrontend then
		BMR._panelBuildPhase = "register-console-option-controls"
		local optionsRegisterOk, optionsRegisterError = pcall(function()
			-- Normalize LAM option arrays before conversion. Both LAM's console converter
			-- and ESO's Lua 5.1 ipairs() stop at the first missing numeric index. Some
			-- dynamic rule builders may return nil for unavailable rules; if one such nil
			-- leaves a sparse controls table, all later controls in that category vanish.
			local function CompactConsoleOptionTree(entries)
				if type(entries) ~= "table" then return {} end
				local indices = {}
				for index, option in pairs(entries) do
					if type(index) == "number" and index >= 1 and index % 1 == 0 and type(option) == "table" then
						indices[#indices + 1] = index
					end
				end
				table.sort(indices)
				local compact = {}
				for _, index in ipairs(indices) do
					local option = entries[index]
					if type(option.controls) == "table" then option.controls = CompactConsoleOptionTree(option.controls) end
					compact[#compact + 1] = option
				end
				return compact
			end
			optionsTable = CompactConsoleOptionTree(optionsTable)

			-- Use BMR's local LAM->LHAS converter here rather than LAM's built-in
			-- registerConsoleOptionControls. The library converter also iterates with
			-- ipairs(), and cannot recover sparse lists itself. The panel registration
			-- has already created/returned the same LHAS settings object above.
			local settings = BMR._consoleSettingsPanel
			if type(settings) ~= "table" or type(settings.AddSetting) ~= "function" then
				error("LibHarvensAddonSettings AddAddon() did not return a settings object")
			end
			local LHA = LibHarvensAddonSettings
			local function ResolveConsoleLabel(value)
				if type(value) == "number" and type(GetString) == "function" then
					local ok, resolved = pcall(GetString, value)
					if ok then return tostring(resolved) end
				end
				if type(value) == "function" then
					local ok, resolved = pcall(value)
					if ok then return tostring(resolved or "") end
				end
				return tostring(value or "")
			end
			local pendingConsoleSettings = {}
			local addedByCategory = {}
			local function SafeAddConsoleSetting(setting, optionKind, optionName, rootCategory)
				-- Build the complete ordered setting tree first. LHA's AddSettings() performs
				-- section/page setup as a batch; adding ST_SECTION entries one by one can leave
				-- later dynamic pages without their controls in some library builds.
				if type(setting) ~= "table" then
					BMR.ProfileDiagnostic("CONSOLE_ADD_SETTING_SKIPPED", tostring(rootCategory or "root") .. "/" .. tostring(optionKind) .. ": " .. tostring(optionName) .. ": invalid setting")
					return false
				end
				pendingConsoleSettings[#pendingConsoleSettings + 1] = setting
				if rootCategory then addedByCategory[rootCategory] = (addedByCategory[rootCategory] or 0) + 1 end
				return true
			end

			local function AddConsoleCustomRuleSettings(reference, rootCategory, sourceOption)
				local custom = BMR.CustomRules
				if type(custom) ~= "table" then return false end
				local function add(setting, label)
					if not setting.type then return false end
					return SafeAddConsoleSetting(setting, "custom-native", label or setting.label, rootCategory)
				end
				local function button(labelId, callback, disabled, tooltip)
					return {type = LHA.ST_BUTTON, label = GetString(labelId), buttonText = GetString(labelId), clickHandler = callback, disable = disabled, tooltip = tooltip}
				end
				-- LibHarvensAddonSettings calls dropdown setters as
				-- setFunction(combobox, selectedName, itemEntry). The actual value is
				-- itemEntry.data, not itemEntry itself. Keep fallbacks for library forks
				-- that pass the data directly or only provide the selected label.
				local function resolveDropdownValue(selectedName, itemEntry, itemsSource)
					if type(itemEntry) == "table" then
						if itemEntry.data ~= nil then return itemEntry.data end
						if itemEntry.field ~= nil or itemEntry.value ~= nil then return itemEntry end
					end
					if type(selectedName) == "table" then
						if selectedName.data ~= nil then return selectedName.data end
						if selectedName.field ~= nil or selectedName.value ~= nil then return selectedName end
					end
					-- Some LHA/LibVotans versions pass the selected label rather than
					-- the option's data object. Resolve by name before accepting a scalar.
					if selectedName ~= nil then
						local items = itemsSource
						if type(items) == "function" then
							local ok, resolved = pcall(items)
							items = ok and resolved or nil
						end
						for _, candidate in ipairs(type(items) == "table" and items or {}) do
							if tostring(candidate.name) == tostring(selectedName) then return candidate.data end
						end
					end
					if itemEntry ~= nil and type(itemEntry) ~= "table" then return itemEntry end
					return nil
				end
				local function actionDropdown(labelId, getter, setter, disabled, tooltip)
					return {
						type = LHA.ST_DROPDOWN,
						label = GetString(labelId),
						tooltip = tooltip,
						items = custom.GetConsoleActionOptions,
						getFunction = function() return (function()
							local current = getter()
							for _, item in ipairs(custom.GetConsoleActionOptions()) do if tonumber(item.data) == tonumber(current) then return item.name end end
							return GetString(BMR_ACTION_NOTSET)
						end)() end,
						setFunction = function(_, selectedName, itemEntry)
							local value = resolveDropdownValue(selectedName, itemEntry, custom.GetConsoleActionOptions)
							if value ~= nil then setter(value) end
						end,
						disable = disabled,
					}
				end
				local function selectedDropdown(labelId, itemsFunc, getter, setter, disabled, tooltip)
					return {
						type = LHA.ST_DROPDOWN,
						label = GetString(labelId),
						tooltip = tooltip,
						items = itemsFunc,
						getFunction = getter,
						setFunction = function(_, selectedName, itemEntry)
							local value = resolveDropdownValue(selectedName, itemEntry, itemsFunc)
							if value ~= nil then setter(value) end
						end,
						disable = disabled,
					}
				end
				local function noSelection(getter)
					return function() return getter() == nil end
				end
				local function filterBuilderTooltip()
					return custom.GetConsoleFilterRuleBuilderTooltip(false)
				end
				local function filterBuilderGuildTooltip()
					return custom.GetConsoleFilterRuleBuilderTooltip(true)
				end
				local function selectedFilterRuleTooltip()
					return custom.GetConsoleSelectedFilterRuleTooltip(false)
				end
				local function selectedFilterRuleGuildTooltip()
					return custom.GetConsoleSelectedFilterRuleTooltip(true)
				end
				local function consoleGuildOptions()
					local options = {{name = GetString(BMR_ACTION_NOTSET), data = GetString(BMR_ACTION_NOTSET)}}
					for _, guild in ipairs(BMR._RuleUi.GetBmrGuildChoices()) do
						if guild.slot and guild.slot > 0 then options[#options + 1] = {name = guild.name, data = guild.value} end
					end
					return options
				end
				local function getRuleGuild(ruleName)
					local rule = BMR._RuleUi.GetOrCreateBmrProfileRule(ruleName)
					local guildName = rule and rule.associatedGuild or GetString(BMR_ACTION_NOTSET)
					for _, item in ipairs(consoleGuildOptions()) do if item.data == guildName then return item.name end end
					return GetString(BMR_ACTION_NOTSET)
				end
				local function setRuleGuild(ruleName, guildName)
					BMR._RuleUi.SetBmrRuleGuild(ruleName, guildName)
				end

				local ruleNameFromReference = type(reference) == "string" and string.match(reference, "^BMRRuleRow:(.+)$") or nil
				if ruleNameFromReference then
					local ruleName = ruleNameFromReference
					local ruleData = BankManagerRules and BankManagerRules.data and BankManagerRules.data[ruleName]
					local displayName = sourceOption and sourceOption.bmrRuleDisplayName or (ruleData and ruleData.name) or ruleName
					add({type = LHA.ST_LABEL, label = tostring(displayName)}, "Rule item " .. ruleName)
					add(actionDropdown(BMR_RULE_TABLE_ACTION, function()
						local rule = BMR._RuleUi.GetOrCreateBmrProfileRule(ruleName)
						return rule and rule.action or ACTION_NOTSET
					end, function(value)
						local rule = BMR._RuleUi.GetOrCreateBmrProfileRule(ruleName)
						if rule then rule.action = tonumber(value) or ACTION_NOTSET; FireBmrRuleCountRefresh() end
					end), "Rule action " .. ruleName)
					add(selectedDropdown(BMR_GUILD_LIST, consoleGuildOptions,
						function() return getRuleGuild(ruleName) end,
						function(value) setRuleGuild(ruleName, value) end, nil, GetString(BMR_GUILD_LIST_TOOLTIP)), "Rule guild " .. ruleName)
					return true
				elseif type(reference) == "string" and string.match(reference, "^BMRRuleTableHeader_") then
					add({type = LHA.ST_LABEL, label = GetString(BMR_RULE_TABLE_ITEM) .. "    |    " .. GetString(BMR_RULE_TABLE_ACTION) .. "    |    " .. GetString(BMR_GUILD_LIST), tooltip = GetString(BMR_GUILD_LIST_TOOLTIP)}, "Rule table header")
					return true
				end

				if reference == "BMRCustomFilterRuleEditor" then
					-- LHA displays the focused setting's tooltip in its shared description area.
					-- Put the live rule builder there so it stays visible during selection and
					-- after adding/removing criteria, instead of adding easily missed label rows.
					add({type = LHA.ST_LABEL, label = GetString(BMR_CUSTOM_FILTER_DESC), tooltip = filterBuilderTooltip}, "Filter description")
					add({type = LHA.ST_EDIT, label = GetString(BMR_CUSTOM_FILTER_SEARCH_STRING), maxChars = 100,
						getFunction = custom.GetConsoleFilterSearchString,
						setFunction = custom.SetConsoleFilterSearchString, tooltip = filterBuilderTooltip}, "Filter search text")
					add({type = LHA.ST_DROPDOWN, label = GetString(BMR_CUSTOM_FILTER_FIELD), items = custom.GetConsoleFilterFieldOptions,
						getFunction = custom.GetConsoleFilterFieldLabel,
						setFunction = function(_, selectedName, itemEntry)
							local fieldKey = resolveDropdownValue(selectedName, itemEntry, custom.GetConsoleFilterFieldOptions)
							if fieldKey then custom.SetConsoleFilterField(fieldKey) end
						end, tooltip = filterBuilderTooltip}, "Filter field")
					add({type = LHA.ST_EDIT, label = GetString(BMR_CUSTOM_FILTER_VALUE_SEARCH), maxChars = 100,
						getFunction = custom.GetConsoleFilterValueSearch,
						setFunction = custom.SetConsoleFilterValueSearch, tooltip = filterBuilderTooltip}, "Filter value search")
					add({type = LHA.ST_DROPDOWN, label = GetString(BMR_CUSTOM_FILTER_VALUE), items = custom.GetConsoleFilterValueOptions,
						getFunction = custom.GetConsoleFilterValueLabel,
						setFunction = function(_, selectedName, itemEntry)
							local valueData = resolveDropdownValue(selectedName, itemEntry, custom.GetConsoleFilterValueOptions)
							if valueData then custom.SetConsoleFilterValue(valueData) end
						end, tooltip = filterBuilderTooltip}, "Filter value")
					add(button(BMR_CUSTOM_FILTER_ADD_SPEC, custom.AddConsoleFilterDraftSpecification, nil, filterBuilderTooltip), "Add filter specification")
					add(button(BMR_CUSTOM_FILTER_REMOVE_LAST, custom.RemoveConsoleFilterDraftSpecification, nil, filterBuilderTooltip), "Remove last filter specification")
					add(button(BMR_CUSTOM_FILTER_CLEAR, custom.ClearConsoleFilterDraft, nil, filterBuilderTooltip), "Clear filter draft")
					add(button(BMR_CUSTOM_FILTER_SAVE_NEW, function() custom.SaveCustomFilterDraft(false) end, nil, filterBuilderTooltip), "Save new filter rule")
					add(button(BMR_CUSTOM_FILTER_OVERWRITE, function() custom.SaveCustomFilterDraft(true) end,
						function() return not (db.customFilterDraft and tonumber(db.customFilterDraft.editingId)) end, filterBuilderTooltip), "Overwrite filter rule")
					return true
				elseif reference == "BMRCustomFilterRuleDynamicList" then
					add({type = LHA.ST_LABEL, label = GetString(BMR_CUSTOM_FILTER_RULE_SELECT)}, "Saved filter rules")
					add(selectedDropdown(BMR_CUSTOM_FILTER_RULE_SELECT, custom.GetConsoleFilterRuleOptions,
						function()
							local id = custom.GetConsoleSelectedFilterId()
							if not id then return nil end
							for _, item in ipairs(custom.GetConsoleFilterRuleOptions()) do if tonumber(item.data) == tonumber(id) then return item.name end end
						end,
						custom.SetConsoleSelectedFilterId, noSelection(custom.GetConsoleSelectedFilterId), selectedFilterRuleTooltip), "Select filter rule")
					add(actionDropdown(BMR_CUSTOM_FILTER_RULE_ACTION, custom.GetConsoleFilterAction, custom.SetConsoleFilterAction, noSelection(custom.GetConsoleSelectedFilterId), selectedFilterRuleTooltip), "Filter profile action")
					add(selectedDropdown(BMR_GUILD_LIST, custom.GetConsoleGuildOptions, custom.GetConsoleFilterGuildLabel, custom.SetConsoleFilterGuild, noSelection(custom.GetConsoleSelectedFilterId), selectedFilterRuleGuildTooltip), "Filter guild bank")
					add(button(BMR_CUSTOM_FILTER_RULE_LOAD, function()
						local id = custom.GetConsoleSelectedFilterId()
						if id then custom.LoadCustomFilterRuleIntoDraft(id) end
					end, noSelection(custom.GetConsoleSelectedFilterId), selectedFilterRuleTooltip), "Load filter rule for editing")
					add({type = LHA.ST_EDIT, label = GetString(BMR_CUSTOM_FILTER_RENAME), maxChars = 64,
						getFunction = custom.GetConsoleFilterRenameDraft,
						setFunction = custom.SetConsoleFilterRenameDraft,
						disable = noSelection(custom.GetConsoleSelectedFilterId), tooltip = selectedFilterRuleTooltip}, "Filter display name")
					add(button(BMR_CUSTOM_FILTER_RENAME, custom.ApplyConsoleFilterRename, noSelection(custom.GetConsoleSelectedFilterId), selectedFilterRuleTooltip), "Rename filter rule")
					add(button(BMR_CUSTOM_FILTER_RULE_DELETE, function()
						local id = custom.GetConsoleSelectedFilterId()
						if id then custom.DeleteCustomFilterRuleById(id) end
					end, noSelection(custom.GetConsoleSelectedFilterId), selectedFilterRuleTooltip), "Delete filter rule")
					return true
				elseif reference == "BMRCustomRuleDynamicList" then
					add(selectedDropdown(BMR_CUSTOM_RULE_ITEM_SELECT, custom.GetConsoleCustomItemOptions,
						function()
							local id = custom.GetConsoleSelectedCustomItemId()
							if not id then return nil end
							for _, item in ipairs(custom.GetConsoleCustomItemOptions()) do if tonumber(item.data) == tonumber(id) then return item.name end end
						end,
						custom.SetConsoleSelectedCustomItemId, noSelection(custom.GetConsoleSelectedCustomItemId)), "Select exact item rule")
					add(actionDropdown(BMR_CUSTOM_RULE_ITEM_ACTION, custom.GetConsoleCustomItemAction, custom.SetConsoleCustomItemAction, noSelection(custom.GetConsoleSelectedCustomItemId)), "Exact item profile action")
					add(selectedDropdown(BMR_GUILD_LIST, custom.GetConsoleGuildOptions, custom.GetConsoleCustomItemGuildLabel, custom.SetConsoleCustomItemGuild, noSelection(custom.GetConsoleSelectedCustomItemId), GetString(BMR_GUILD_LIST_TOOLTIP)), "Exact item guild bank")
					add({type = LHA.ST_EDIT, label = GetString(BMR_CUSTOM_ITEM_RENAME), maxChars = 64,
						getFunction = custom.GetConsoleCustomItemRenameDraft,
						setFunction = custom.SetConsoleCustomItemRenameDraft,
						disable = noSelection(custom.GetConsoleSelectedCustomItemId)}, "Exact item display name")
					add(button(BMR_CUSTOM_ITEM_RENAME, custom.ApplyConsoleCustomItemRename, noSelection(custom.GetConsoleSelectedCustomItemId)), "Rename exact item rule")
					add(button(BMR_CUSTOM_RULE_ITEM_REMOVE, function()
						local id = custom.GetConsoleSelectedCustomItemId()
						if id then custom.RemoveCustomItemRuleById(id) end
					end, noSelection(custom.GetConsoleSelectedCustomItemId)), "Remove exact item rule")
					return true
				end
				return false
			end
			local function AddConsoleSettings(entries, rootCategory, flattenNestedSubmenus)
				-- `entries` is normalized, but compact again for callback-built nested lists.
				local sequence = CompactConsoleOptionTree(entries)
				for _, option in ipairs(sequence) do
					if type(option) == "table" then
						local kind = option.type
						if kind == "submenu" then
							local sectionLabel = ResolveConsoleLabel(option.name)
							local category = rootCategory or sectionLabel
							-- ST_SECTION creates a navigable page in the console frontend.
							-- Preserve nested LAM submenus so weapon types can be opened from
							-- an alliance page instead of flattening every rule into PvP.
							local isNestedFlatSection = rootCategory ~= nil and flattenNestedSubmenus == true
							local sectionType = (isNestedFlatSection and LHA.ST_LABEL) or LHA.ST_SECTION or LHA.ST_LABEL
							local sectionAdded = false
							if sectionType then
								sectionAdded = SafeAddConsoleSetting({type = sectionType, label = sectionLabel}, kind, sectionLabel, category)
							end
							-- Some library builds expose only ST_LABEL or reject ST_SECTION.
							if not sectionAdded and LHA.ST_LABEL and sectionType ~= LHA.ST_LABEL then
								SafeAddConsoleSetting({type = LHA.ST_LABEL, label = sectionLabel}, kind .. "-label-fallback", sectionLabel, category)
							end
							local flattenChildren = flattenNestedSubmenus or option.bmrConsoleFlattenChildren == true
							AddConsoleSettings(option.controls, category, flattenChildren)
						elseif kind == "dropdown" then
							if LHA.ST_DROPDOWN then
								-- Lua 5.1 reuses generic-for variables. Capture this option per dropdown.
								local currentOption = option
								local choices = currentOption.choices
								if type(choices) == "function" then local ok, value = pcall(choices); choices = ok and value or {} end
								local values = currentOption.choicesValues or choices or {}
								local items, labels = {}, {}
								for i, choice in ipairs(choices or {}) do
									local data = values[i]
									local name = ResolveConsoleLabel(choice)
									items[#items + 1] = {name = name, data = data}
									if data ~= nil then labels[data] = name end
								end
								SafeAddConsoleSetting({
									type = LHA.ST_DROPDOWN,
									label = ResolveConsoleLabel(currentOption.bmrConsoleName or currentOption.name),
									tooltip = currentOption.tooltip,
									items = items,
									disable = currentOption.disabled,
									getFunction = function()
										local ok, value = pcall(currentOption.getFunc or function() return nil end)
										return labels[ok and value or nil]
									end,
									setFunction = function(_, _, item)
										if item and currentOption.setFunc then currentOption.setFunc(item.data) end
									end,
								}, kind, currentOption.name, rootCategory)
							else
								BMR.ProfileDiagnostic("CONSOLE_SETTING_TYPE_UNAVAILABLE", tostring(rootCategory) .. "/dropdown: " .. tostring(option.name))
								if LHA.ST_LABEL then SafeAddConsoleSetting({type = LHA.ST_LABEL, label = ResolveConsoleLabel(option.name) .. " (Auswahl nicht unterstützt)"}, kind .. "-fallback", option.name, rootCategory) end
							end
						elseif kind == "description" then
							if LHA.ST_LABEL then
								local title = ResolveConsoleLabel(option.title)
								local body = ResolveConsoleLabel(option.text)
								if title ~= "" then SafeAddConsoleSetting({type = LHA.ST_LABEL, label = title, tooltip = option.tooltip}, kind .. "-title", title, rootCategory) end
								if body ~= "" then SafeAddConsoleSetting({type = LHA.ST_LABEL, label = body, tooltip = option.tooltip}, kind, body, rootCategory) end
							end
						elseif kind == "checkbox" or kind == "slider" or kind == "editbox" or kind == "colorpicker" or kind == "button" or kind == "header" or kind == "divider" then
							local typeMap = {
								checkbox = LHA.ST_CHECKBOX, slider = LHA.ST_SLIDER, editbox = LHA.ST_EDIT,
								colorpicker = LHA.ST_COLOR, button = LHA.ST_BUTTON, header = LHA.ST_LABEL, divider = LHA.ST_LABEL,
							}
							local settingType = typeMap[kind]
							local label = ResolveConsoleLabel(option.name or option.title or option.text)
							if settingType then
								local setting = {type = settingType, label = kind == "divider" and "----------------" or label,
									tooltip = option.tooltip, default = option.default, min = option.min, max = option.max,
									step = option.step, maxChars = option.maxChars, setFunction = option.setFunc,
									getFunction = option.getFunc, disable = option.disabled, clickHandler = option.func,
									buttonText = ResolveConsoleLabel(option.name)}
								SafeAddConsoleSetting(setting, kind, label, rootCategory)
							else
								BMR.ProfileDiagnostic("CONSOLE_SETTING_TYPE_UNAVAILABLE", tostring(rootCategory) .. "/" .. tostring(kind) .. ": " .. tostring(label))
								if LHA.ST_LABEL then SafeAddConsoleSetting({type = LHA.ST_LABEL, label = label .. " (nicht unterstützt)"}, kind .. "-fallback", label, rootCategory) end
							end
						elseif kind == "custom" then
							local customAdded = AddConsoleCustomRuleSettings(option.reference, rootCategory, option)
							if not customAdded and LHA.ST_LABEL then SafeAddConsoleSetting({type = LHA.ST_LABEL, label = ResolveConsoleLabel(option.reference) .. " (nicht unterstützt)"}, kind, option.reference, rootCategory) end
						elseif kind == "texture" then
							if LHA.ST_LABEL then SafeAddConsoleSetting({type = LHA.ST_LABEL, label = "----------------"}, kind, "divider", rootCategory) end
						end
					end
				end
			end

			AddConsoleSettings(optionsTable)
			local addedControls = 0
			local registrationMode = "single-setting-fallback"
			local returnedControls = nil
			local canUseSingleSettingFallback = type(settings.AddSettings) ~= "function"
			if type(settings.AddSettings) == "function" and #pendingConsoleSettings > 0 then
				local batchOk, batchError = pcall(function() returnedControls = settings:AddSettings(pendingConsoleSettings) end)
				if batchOk then
					addedControls = #pendingConsoleSettings
					registrationMode = "batch-AddSettings"
				else
					BMR.ProfileDiagnostic("CONSOLE_ADD_SETTINGS_BATCH_FAILED", tostring(batchError))
					-- A failed batch may already have partially registered controls. Only retry
					-- through AddSetting when Clear() definitely succeeded.
					if type(settings.Clear) == "function" then
						local clearOk, clearError = pcall(function() settings:Clear() end)
						canUseSingleSettingFallback = clearOk
						if not clearOk then BMR.ProfileDiagnostic("CONSOLE_SETTINGS_CLEAR_FAILED", tostring(clearError)) end
					end
					registrationMode = canUseSingleSettingFallback and "single-setting-fallback" or "batch-failed"
				end
			end
			if addedControls == 0 and #pendingConsoleSettings > 0 and canUseSingleSettingFallback then
				for _, setting in ipairs(pendingConsoleSettings) do
					local createdControl = nil
					local addOk, addError = pcall(function() createdControl = settings:AddSetting(setting) end)
					if addOk then
						addedControls = addedControls + 1
					else
						BMR.ProfileDiagnostic("CONSOLE_ADD_SETTING_FAILED", tostring(addError))
					end
				end
			end
			BMR._consoleSettingsControlsAdded = addedControls
			BMR._consoleSettingsCategoryCounts = addedByCategory
			BMR._consoleSettingsRegistrationMode = registrationMode
			BMR.ProfileDiagnostic("CONSOLE_FILTER_BUILDER_TOOLTIPS", "dynamic tooltip callbacks registered on editor and assigned-guild controls; mode=" .. registrationMode)
			BMR.ProfileDiagnostic("CONSOLE_SETTINGS_CONTROL_COUNT", "added=" .. tostring(addedControls) .. "; queued=" .. tostring(#pendingConsoleSettings) .. "; mode=" .. registrationMode .. "; rootOptions=" .. tostring(#optionsTable) .. "; categories=" .. tostring((function() local n=0 for _ in pairs(addedByCategory) do n=n+1 end return n end)()))
			BMR._consoleSettingsAdapter = "BMR direct LibHarvensAddonSettings converter (" .. registrationMode .. "; normalized LAM options)"
		end)
		BMR.ProfileDiagnostic(optionsRegisterOk and "CONSOLE_SETTINGS_OPTIONS_REGISTERED" or "CONSOLE_SETTINGS_OPTIONS_FAILED", tostring(optionsRegisterError or "ok") .. "; optionsCount=" .. tostring(#optionsTable))
		if not optionsRegisterOk then BMR.ProfileDiagnosticChat("BMR: Konsolen-Einstellungen konnten nicht registriert werden: " .. tostring(optionsRegisterError)) end
		-- The remaining code patches mouse/keyboard LAM control factories and is not
		-- applicable to the LibHarvensAddonSettings frontend.
		BMR._panelBuildPhase = optionsRegisterOk and "console-settings-ready" or "console-options-registration-failed"
		return
	end

	BMR._panelBuildPhase = "register-keyboard-option-controls"
	LAM2:RegisterOptionControls(settingsPanelId, optionsTable)
	if useLibGamepadFrontend then
		BMR._consoleSettingsAdapter = "LibGamepad (native LAM submenu adapter)"
		BMR._panelBuildPhase = "gamepad-settings-ready"
		BMR.ProfileDiagnostic("LIBGAMEPAD_OPTIONS_REGISTERED", "optionsCount=" .. tostring(#optionsTable) .. "; native LAM tree handed to LibGamepad")
		return
	end
	BMR._consoleSettingsAdapter = "keyboard LAM"
	BMR._panelBuildPhase = "keyboard-settings-ready"
	BMR.ProfileDiagnostic("LAM_OPTIONS_REGISTERED", "optionsCount=" .. tostring(#optionsTable) .. "; " .. BMR.ProfileDebugSnapshot())

	-- Resize LAM dropdowns at the point where each control is created. The
	-- earlier post-creation tree walk did not reliably reach controls nested in
	-- LAM submenus, so many category dropdowns retained LAM's default 1/3 width.
	local dropdownMeasureLabel
	local function MeasureDropdownChoice(textValue)
		if not dropdownMeasureLabel then
			dropdownMeasureLabel = WINDOW_MANAGER:CreateControl(nil, GuiRoot, CT_LABEL)
			dropdownMeasureLabel:SetFont("ZoFontGame")
			dropdownMeasureLabel:SetDimensions(1400, 28)
			dropdownMeasureLabel:SetHidden(true)
		end
		dropdownMeasureLabel:SetText(tostring(textValue or ""))
		if dropdownMeasureLabel.GetTextWidth then
			local ok, width = pcall(dropdownMeasureLabel.GetTextWidth, dropdownMeasureLabel)
			if ok and tonumber(width) and width > 0 then return width end
		end
		return #tostring(textValue or "") * 8.5
	end

	local function GetDropdownChoiceText(choice)
		if type(choice) == "number" and type(GetString) == "function" then
			local ok, value = pcall(GetString, choice)
			if ok and type(value) == "string" then return value end
		elseif type(choice) == "function" then
			local ok, value = pcall(choice)
			if ok and type(value) == "string" then return value end
		end
		return tostring(choice or "")
	end

	local checkboxMeasureLabel
	local function MeasureCheckboxStatusText(textValue)
		if not checkboxMeasureLabel then
			checkboxMeasureLabel = WINDOW_MANAGER:CreateControl(nil, GuiRoot, CT_LABEL)
			checkboxMeasureLabel:SetFont("ZoFontGameBold")
			checkboxMeasureLabel:SetDimensions(500, 28)
			checkboxMeasureLabel:SetHidden(true)
		end
		checkboxMeasureLabel:SetText(tostring(textValue or ""))
		if checkboxMeasureLabel.GetTextWidth then
			local ok, measured = pcall(checkboxMeasureLabel.GetTextWidth, checkboxMeasureLabel)
			if ok and tonumber(measured) and measured > 0 then return measured end
		end
		return #tostring(textValue or "") * 9
	end

	-- LAM normally reserves one third of every checkbox row for its ON/OFF text.
	-- The status itself is much narrower: keep only the localized status width on
	-- the right, so the setting label can use almost the complete row.
	local function ResizeLamCheckbox(control)
		if not control or not control.data or control.data.type ~= "checkbox" then return end
		if not control.container or not control.checkbox then return end
		local onText = type(GetString) == "function" and GetString(SI_CHECK_BUTTON_ON) or "ON"
		local offText = type(GetString) == "function" and GetString(SI_CHECK_BUTTON_OFF) or "OFF"
		onText = tostring(onText or "ON"):upper()
		offText = tostring(offText or "OFF"):upper()
		local statusWidth = math.max(MeasureCheckboxStatusText(onText), MeasureCheckboxStatusText(offText))
		local warningWidth = 0
		if control.warning and control.warning.GetWidth then
			local ok, measured = pcall(control.warning.GetWidth, control.warning)
			if ok and tonumber(measured) then warningWidth = math.max(0, measured) + 5 end
		end
		control.container:SetWidth(math.max(54, math.ceil(statusWidth + warningWidth + 14)))
		control.checkbox:ClearAnchors()
		control.checkbox:SetAnchor(RIGHT, control.container, RIGHT, 0, 0)
		control.bmrCheckboxRightAligned = true
	end

	local function ResizeLamDropdown(control)
		if not control or not control.data or control.data.type ~= "dropdown" then return end
		if not control.container or not control.combobox or not control.dropdown then return end
		local choices = control.data.choices
		if type(choices) == "function" then
			local ok, result = pcall(choices)
			choices = ok and result or nil
		end
		local longestWidth = 0
		if type(choices) == "table" then
			for _, choice in ipairs(choices) do
				longestWidth = math.max(longestWidth, MeasureDropdownChoice(GetDropdownChoiceText(choice)))
			end
		end
		local availableWidth = tonumber(control:GetWidth()) or 510
		-- The dropdown is anchored to the right side of its row. Leave enough
		-- room for the row label, but size the dropdown from its longest option.
		local desiredWidth = longestWidth + 48
		local maxWidth = math.max(140, availableWidth - 145)
		desiredWidth = math.max(180, math.min(desiredWidth, maxWidth))
		control.container:SetWidth(desiredWidth)
		control.combobox:SetWidth(desiredWidth)
		-- ComboBox uses this width for its popup menu on standard LAM dropdowns.
		control.dropdown.m_containerWidth = desiredWidth
		if control.dropdown.m_dropdown and control.dropdown.m_dropdown.SetWidth then
			control.dropdown.m_dropdown:SetWidth(desiredWidth)
		end
		control.bmrDropdownWidthApplied = true
	end

	-- Normalize controls and submenu scroll areas to LAM's existing fixed
	-- content width. The outer settings window is no longer resized.
	function BMR._RuleUi.ReflowBmrLamControls(panelControl)
		local rootPanel = panelControl or BMR._lamPanel
		if not rootPanel or not rootPanel.GetWidth then return false end
		local function GetPanelWidth(controlPanel)
			-- LAM fixes submenu scroll constraints when controls are created. Use
			-- the existing PanelContainer width, without resizing the outer window.
			if controlPanel == rootPanel then
				local window = _G.LAMAddonSettingsWindow
				local panelContainer = window and ((window.GetNamedChild and window:GetNamedChild("PanelContainer")) or BMR._RuleUi.FindLamChildBySuffix(window, "PanelContainer"))
				if panelContainer and panelContainer.GetWidth then
					local liveWidth = tonumber(panelContainer:GetWidth())
					if liveWidth and liveWidth > 0 then return liveWidth end
				end
			end
			local width = controlPanel and controlPanel.GetWidth and tonumber(controlPanel:GetWidth())
			if width and width > 0 then return width end
			return tonumber(rootPanel:GetWidth()) or 645
		end
		local visited = {}
		local function Visit(parent)
			if not parent or visited[parent] then return end
			visited[parent] = true
			if not parent.GetNumChildren or not parent.GetChild then return end
			local okCount, childCount = pcall(parent.GetNumChildren, parent)
			if not okCount then return end
			for index = 1, tonumber(childCount) or 0 do
				local okChild, child = pcall(parent.GetChild, parent, index)
				if okChild and child then
					local data = child.data
					if type(data) == "table" and type(data.type) == "string" and child.SetWidth then
						local controlPanel = child.panel or rootPanel
						local panelWidth = GetPanelWidth(controlPanel)
						if data.type == "submenu" then
							-- LAM creates each submenu scroll with an exact X constraint
							-- based on the parent's width at creation time. Resizing only
							-- its child controls cannot overcome that clipping boundary.
							local submenuWidth = math.max(300, panelWidth - 45)
							local scrollWidth = submenuWidth + 5
							child:SetWidth(submenuWidth)
							if child.scroll then
								child.scroll:SetDimensionConstraints(scrollWidth, 0, scrollWidth, 0)
								child.scroll:SetWidth(scrollWidth)
							end
						else
							local contentWidth = math.max(300, panelWidth - 60)
							local targetWidth = data.width == "half" and contentWidth / 2 or contentWidth
							local parentData = child.GetParent and child:GetParent() and child:GetParent().data
							if data.width == "half" and type(parentData) == "table" and parentData.type == "container" then
								targetWidth = targetWidth - 2.5 -- preserve LAM's TwinOptionsContainer spacing
							end
							child:SetWidth(targetWidth)
							if type(child.bmrResizeLayout) == "function" then
								pcall(child.bmrResizeLayout, targetWidth)
							end
							if child.container and child.container.SetWidth then
								if data.type == "dropdown" then
									ResizeLamDropdown(child)
								elseif data.type == "checkbox" then
									ResizeLamCheckbox(child)
								else
									child.container:SetWidth(targetWidth / 3)
								end
							end
						end
					end
					Visit(child)
				end
			end
		end
		Visit(rootPanel)
		-- Refresh the named custom controls directly as a fallback for LAM builds
		-- whose nested child enumeration does not expose all submenu descendants.
		local function ResizeCustomList(name, refreshFunction)
			local control = _G[name]
			if not control then return end
			local controlPanel = control.panel or rootPanel
			local contentWidth = math.max(300, GetPanelWidth(controlPanel) - 60)
			if control.SetWidth then control:SetWidth(contentWidth) end
			if type(control.bmrResizeLayout) == "function" then pcall(control.bmrResizeLayout, contentWidth) end
			if refreshFunction then pcall(refreshFunction, control) end
		end
		if BMR.CustomRules then
			ResizeCustomList("BMRCustomRuleDynamicList", BMR.CustomRules.RefreshCustomRuleList)
			ResizeCustomList("BMRCustomFilterRuleDynamicList", BMR.CustomRules.RefreshCustomFilterRuleList)
		end
		local filterEditor = _G.BMRCustomFilterRuleEditor
		if filterEditor and filterEditor.panel then
			local editorWidth = math.max(300, GetPanelWidth(filterEditor.panel) - 60)
			if filterEditor.SetWidth then filterEditor:SetWidth(editorWidth) end
			if type(filterEditor.bmrResizeLayout) == "function" then pcall(filterEditor.bmrResizeLayout, editorWidth) end
		end
		return true
	end

	-- Wrap LAM checkboxes so their localized ON/OFF status is right-aligned and
	-- reserves only the width it actually needs, across all nested settings pages.
	if type(LAMCreateControl) == "table" and type(LAMCreateControl.checkbox) == "function" then
		LAMCreateControl.BMROriginalCheckboxCreator = LAMCreateControl.BMROriginalCheckboxCreator or LAMCreateControl.checkbox
		local originalCheckboxCreator = LAMCreateControl.BMROriginalCheckboxCreator
		LAMCreateControl.checkbox = function(parent, checkboxData, controlName)
			local control = originalCheckboxCreator(parent, checkboxData, controlName)
			ResizeLamCheckbox(control)
			return control
		end
	end

	-- Wrap the LAM dropdown factory so all standard dropdowns get the sizing,
	-- including those nested several levels deep in the settings panel.
	if type(LAMCreateControl) == "table" and type(LAMCreateControl.dropdown) == "function" then
		-- Store the unwrapped factory on LAM itself so a UI reload does not stack
		-- wrappers on top of a previously patched function.
		LAMCreateControl.BMROriginalDropdownCreator = LAMCreateControl.BMROriginalDropdownCreator or LAMCreateControl.dropdown
		local originalDropdownCreator = LAMCreateControl.BMROriginalDropdownCreator
		LAMCreateControl.dropdown = function(parent, dropdownData, controlName)
			local control = originalDropdownCreator(parent, dropdownData, controlName)
			ResizeLamDropdown(control)
			return control
		end
	end

	-- Every action dropdown advertises its rule key in bmrRuleName. Recursively
	-- collect those keys so parent categories include direct rules and nested ones.
	BMR.ruleCountLabels = {}
	BMR.pvpCategoryRuleCountLabels = {} -- legacy callback compatibility

	local function GetRuleCountsFromControlTree(controls)
		local ruleNames = {}
		local includeCustomItems = false
		local includeCustomFilters = false
		local function Visit(entries)
			for _, entry in ipairs(entries or {}) do
				if type(entry) == "table" then
					if type(entry.bmrRuleName) == "string" then
						ruleNames[entry.bmrRuleName] = true
					end
					if entry.bmrCountCustomItemRules then includeCustomItems = true end
					if entry.bmrCountCustomFilterRules then includeCustomFilters = true end
					if type(entry.controls) == "table" then Visit(entry.controls) end
				end
			end
		end
		Visit(controls)

		if includeCustomItems then
			local customIds = {}
			for itemId in pairs(db.customItemRules or {}) do
				local numericId = tonumber(itemId)
				if numericId then customIds[numericId] = true end
			end
			for numericId in pairs(customIds) do
				ruleNames["customItem_" .. tostring(numericId)] = true
			end
		end
		if includeCustomFilters then
			for filterId in pairs(db.customFilterRules or {}) do
				local numericId = tonumber(filterId)
				if numericId then ruleNames["customFilter_" .. tostring(numericId)] = true end
			end
		end

		local activeCount, totalCount = 0, 0
		local profile = db.profiles and db.profiles[actualProfile]
		local profileRules = profile and profile.rules or {}
		for ruleName in pairs(ruleNames) do
			totalCount = totalCount + 1
			local rule = profileRules[ruleName]
			if rule and rule.action ~= nil and rule.action ~= ACTION_NOTSET then
				activeCount = activeCount + 1
			end
		end
		return activeCount, totalCount
	end

	local function UpdateRuleCountLabels()
		for _, row in ipairs(BMR.ruleCountLabels or {}) do
			if row.label and row.data then
				local activeCount, totalCount = GetRuleCountsFromControlTree(row.data.controls)
				row.label:SetText(zo_strformat(GetString(BMR_PVP_RULES_ACTIVE), activeCount, totalCount))
				row.label:SetHidden(false)
			end
		end
	end
	-- A stable dispatcher lets this function be replaced by later /reloadui loads.
	BMR.UpdateRuleCountLabels = UpdateRuleCountLabels
	local function DispatchRuleCountUpdate()
		if type(BMR.UpdateRuleCountLabels) == "function" then BMR.UpdateRuleCountLabels() end
	end

	if type(LAMCreateControl) == "table" and type(LAMCreateControl.submenu) == "function" then
		-- Preserve the original LAM factory and reapply the latest wrapper on reload.
		LAMCreateControl.BMROriginalSubmenuCreator = LAMCreateControl.BMROriginalSubmenuCreator or LAMCreateControl.submenu
		local originalSubmenuCreator = LAMCreateControl.BMROriginalSubmenuCreator
		LAMCreateControl.submenu = function(parent, submenuData, controlName)
			local control = originalSubmenuCreator(parent, submenuData, controlName)
			if control and submenuData and type(submenuData.controls) == "table" and control.label and control.arrow then
				-- LAM2 attaches its stock toggle handler to the label. Since this wrapper
				-- disables the label to let the count area behave as part of the row, we
				-- must supply a real clickable hit target for the full header.
				if not control.bmrHeaderClickTarget then
					local clickTarget = WINDOW_MANAGER:CreateControl(nil, control, CT_CONTROL)
					control.bmrHeaderClickTarget = clickTarget
					clickTarget:SetAnchor(TOPLEFT, control.label, TOPLEFT, -5, -5)
					clickTarget:SetAnchor(TOPRIGHT, control.arrow, TOPRIGHT, 5, 0)
					clickTarget:SetHeight(36)
					clickTarget:SetAlpha(0)
					clickTarget:SetMouseEnabled(true)
					if control.label.data and control.label.data.tooltipText then
						clickTarget.data = control.label.data
						clickTarget:SetHandler("OnMouseEnter", ZO_Options_OnMouseEnter)
						clickTarget:SetHandler("OnMouseExit", ZO_Options_OnMouseExit)
					end
					clickTarget:SetHandler("OnMouseUp", function(_, button, upInside)
						if button ~= MOUSE_BUTTON_INDEX_LEFT or not upInside or control.disabled then return end
						control.open = not control.open
						if control.open then
							control.animation:PlayFromStart()
						else
							control.animation:PlayFromEnd()
						end
					end)
				end
				-- Make the new hit target the only click recipient on the header row.
				-- The count label remains mouse-disabled so its area falls through to it.
				control.label:SetMouseEnabled(false)
				if control.arrow.SetMouseEnabled then control.arrow:SetMouseEnabled(false) end

				local activeCount, totalCount = GetRuleCountsFromControlTree(submenuData.controls)
				-- Do not add counters to purely informational submenus.
				if totalCount > 0 then
					local countWidth = 155
					local countLabel = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
					countLabel:SetFont("ZoFontWinH4")
					countLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
					countLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
					countLabel:SetDimensions(countWidth, 30)
					countLabel:SetAnchor(TOPRIGHT, control.arrow, TOPLEFT, -8, 0)
					countLabel:SetDrawLayer(DL_OVERLAY)
					countLabel:SetHidden(false)
					countLabel:SetMouseEnabled(false)
					control.label:SetWidth(math.max(140, (control.label:GetWidth() or 450) - countWidth - 8))
					local row = {label = countLabel, data = submenuData, control = control}
					table.insert(BMR.ruleCountLabels, row)
					countLabel:SetText(zo_strformat(GetString(BMR_PVP_RULES_ACTIVE), activeCount, totalCount))
				end
			end
			return control
		end
	end

	if CALLBACK_MANAGER and CALLBACK_MANAGER.RegisterCallback and not BMR.bmrRuleCountCallbacksRegisteredV2 then
		BMR.bmrRuleCountCallbacksRegisteredV2 = true
		CALLBACK_MANAGER:RegisterCallback("BMR-RuleCountRefresh", DispatchRuleCountUpdate)
		CALLBACK_MANAGER:RegisterCallback("LAM-RefreshPanel", DispatchRuleCountUpdate)
		CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", DispatchRuleCountUpdate)
		CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", DispatchRuleCountUpdate)
	end
	UpdateRuleCountLabels()


end

-- Move UI to its place
local function RebuildAnchorsGUI()
	BankManager:ClearAnchors()
	BankManager:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, db.gui_x, db.gui_y)
end

-- Item context-menu and exact custom-rule helpers are implemented in BankManagerCustomRules.lua.
BMR.CustomRulesContext = {
	ACTION_NOTSET = ACTION_NOTSET,
	ACTION_PUSH = ACTION_PUSH,
	ACTION_PULL = ACTION_PULL,
	ACTION_PUSH_GBANK = ACTION_PUSH_GBANK,
	ACTION_PUSH_BOTH = ACTION_PUSH_BOTH,
	ACTION_KEEP_ONE_STACK = ACTION_KEEP_ONE_STACK,
	ACTION_KEEP_ONE_STACK_BANK = ACTION_KEEP_ONE_STACK_BANK,
	ACTION_PUSH_FURNITURE = ACTION_PUSH_FURNITURE,
	ACTION_PUSH_ALL_STACKS = ACTION_PUSH_ALL_STACKS,
	ACTION_PULL_ALL_STACKS = ACTION_PULL_ALL_STACKS,
	ITEMLINK = BMR_ITEMLINK,
	GetActualProfile = function() return actualProfile end,
	DeepCopy = DeepCopy,
	FormatCustomItemName = FormatCustomItemName,
	CustomRuleDebug = function(message) CustomRuleDebug(message) end,
	FireRuleCountRefresh = function() FireBmrRuleCountRefresh() end,
}
BMR.SyncCustomItemRuleDefinitions = function() SyncCustomItemRuleDefinitions() end

--Load Addon
local function onAddonLoaded(_, addon)
	if addon == ADDON_NAME then
		BMR.ProfileDiagnostic("ADDON_LOADED_EVENT", "eventAddon=" .. tostring(addon))
		BMR.ProfileDiagnostic("BMR_ADDON_INITIALIZATION_BEGIN", "BankManagerRules=" .. tostring(type(BankManagerRules)))
		BMR._addonLoadEventMatched = true
		if BMR._bmrInitializationComplete or BMR._bmrInitializationRunning then return end

		-- On the .addon/ForceConsoleFlow loader the add-on loaded callback can
		-- arrive before all later manifest scripts have populated BankManagerRules.
		-- Retry on the next UI tick instead of permanently continuing with no rule API.
		local rulesReady = type(BankManagerRules) == "table"
			and type(BankManagerRules.addFilters) == "function"
			and type(BankManagerRules.addFiltersTaggedAll) == "function"
			and type(BankManagerRules.addDefaultFilters) == "function"
		if not rulesReady and (BMR._startupRetryCount or 0) < 4 then
			BMR._startupRetryCount = (BMR._startupRetryCount or 0) + 1
			BMR._startupPhase = "wait-for-rule-definitions-" .. tostring(BMR._startupRetryCount)
			zo_callLater(function() onAddonLoaded(nil, ADDON_NAME) end, 100)
			return
		end

		BMR._bmrInitializationRunning = true
		BMR._startupPhase = "initialize-core-profile-store"
		local coreStoreOk, coreStoreError = pcall(InitializeCoreProfileStore)
		BMR._coreProfileStoreInitOk = coreStoreOk
		BMR._coreProfileStoreInitError = nil
		if not coreStoreOk then
			BMR._coreProfileStoreInitError = tostring(coreStoreError)
			BMR.ProfileDiagnosticChat("BMR core profile init failed: " .. tostring(coreStoreError))
			BMR.ProfileDiagnostic("CORE_PROFILE_STORE_FAILED", tostring(coreStoreError))
			BMR._bmrInitializationRunning = false
			return
		end

		BMR.ProfileDiagnostic("ADDON_LOADED_EVENT", "eventAddon=" .. tostring(addon))
		BMR.ProfileDiagnostic("BMR_ADDON_INITIALIZATION_BEGIN", "BankManagerRules=" .. tostring(type(BankManagerRules)) .. "; addFilters=" .. tostring(type(BankManagerRules) == "table" and type(BankManagerRules.addFilters) or "missing"))
		if BankManagerRules then
			local ruleBuildOk = true
			local function RunRuleBuildPhase(phaseName, callback)
				BMR._startupPhase = phaseName
				local ok, err = pcall(callback)
				BMR.ProfileDiagnostic(ok and (string.upper(phaseName:gsub("%-", "_")) .. "_OK") or (string.upper(phaseName:gsub("%-", "_")) .. "_FAILED"), tostring(err or "ok"))
				if not ok then
					ruleBuildOk = false
					BMR._ruleBuildError = phaseName .. ": " .. tostring(err)
					BMR.ProfileDiagnosticChat("BMR Regelaufbau fehlgeschlagen (" .. phaseName .. "): " .. tostring(err):gsub("[\r\n]+", " "):sub(1, 180))
				end
				return ok
			end

			-- Keep each rule-building phase isolated so a console-only missing API
			-- is reported by name and cannot prevent the core profile UI from loading.
			RunRuleBuildPhase("add-filters", function() BankManagerRules.addFilters() end)
			RunRuleBuildPhase("add-tagged-filters", function() BankManagerRules.addFiltersTaggedAll() end)
			RunRuleBuildPhase("add-default-filters", function()
				BankManagerRules.defaults = BankManagerRules.addDefaultFilters(BankManagerRules.data, BankManagerRules.defaults)
			end)
			BMR._ruleBuildOk = ruleBuildOk
			if ruleBuildOk then
				BMR.ProfileDiagnostic("RULE_DEFAULTS_READY", "ruleDefinitions=" .. tostring((function() local n = 0; for _ in pairs(BankManagerRules.data or {}) do n = n + 1 end; return n end)()))
			end

			-- Migrate existing saved profiles when new rules are added in an update.
			-- Without this, a new rule (for example MiscContainers) may exist in
			-- BankManagerRules.data but be absent from older profile.rules tables,
			-- causing prepareItem() to index nil when scanning inventory/bank items.
			if db and db.profiles then
				-- The four global addon profiles only control which crafting-related
				-- categories are relevant for the account. Container rules are always
				-- relevant (ESO+ does not make these items obsolete), so make sure
				-- every container rule exists in every saved BMR profile, regardless
				-- of the selected global addon profile. Existing user choices are kept.
				local alwaysAvailableContainerRules = {
					"MiscContainerUnknownAllWrit",
					"MiscContainerUnidentifiedAllSurvey",
					"MiscContainerUnknownBlacksmithingWrit",
					"MiscContainerUnknownClothingWrit",
					"MiscContainerUnknownWoodworkingWrit",
					"MiscContainerUnknownEnchantingWrit",
					"MiscContainerUnknownProvisioningWrit",
					"MiscContainerUnknownAlchemyWrit",
					"MiscContainerUnknownJewelryWrit",
					"MiscContainerTreasureMap",
					"MiscContainerUnidentifiedBlacksmithingSurvey",
					"MiscContainerUnidentifiedClothingSurvey",
					"MiscContainerUnidentifiedWoodworkingSurvey",
					"MiscContainerUnidentifiedEnchantingSurvey",
					"MiscContainerUnidentifiedAlchemySurvey",
					"MiscContainerUnidentifiedJewelrySurvey",
					"MiscContainerAntiquityLead",
					"MiscContainerAntiquityLeadGreen",
					"MiscContainerAntiquityLeadBlue",
					"MiscContainerAntiquityLeadPurple",
					"MiscContainerAntiquityLeadGold",
				}
				for profileIndex, profile in pairs(db.profiles) do
					if type(profile) == "table" then
						profile.rules = profile.rules or {}
						-- The former combined repair rule also included Crown Repair Kits.
						-- Seed the new independent rule from the old setting once, while
						-- keeping the ordinary repair-kit rule and its settings intact.
						if profile.rules.MiscCrownRepair == nil and type(profile.rules.MiscRepair) == "table" then
							profile.rules.MiscCrownRepair = DeepCopy(profile.rules.MiscRepair)
						end
						-- General migration for any rules added by this update.
						for ruleName, defaultRule in pairs(BankManagerRules.defaults) do
							if profile.rules[ruleName] == nil then
								profile.rules[ruleName] = DeepCopy(defaultRule)
							end
						end
						-- Explicitly ensure every container rule has its own saved action.
						for _, ruleName in ipairs(alwaysAvailableContainerRules) do
							if profile.rules[ruleName] == nil and BankManagerRules.defaults[ruleName] then
								profile.rules[ruleName] = DeepCopy(BankManagerRules.defaults[ruleName])
							end
						end
					end
				end
			end
			
			-- Build it a single time to avoid unneeded loops; a console-only guild API gap must not block profile UI.
			BMR._startupPhase = "list-active-guilds"
			local guildCacheOk, guildCacheError = pcall(listOfActiveGuilds)
			if not guildCacheOk then BMR.ProfileDiagnosticChat("BMR Guild-Liste nicht verfügbar: " .. tostring(guildCacheError):gsub("[\r\n]+", " "):sub(1, 150)) end
			BMR.ProfileDiagnostic(guildCacheOk and "ACTIVE_GUILDS_READY" or "ACTIVE_GUILDS_FAILED", tostring(guildCacheError or "guild cache initialized"))

			-- Build LAM/LHAS. Record both the error and stage for compact in-game diagnosis.
			BMR._startupPhase = "build-settings-panel"
			BMR._panelBuildPhase = "calling-buildLAMPanel"
			local panelBuildOk, panelBuildError = pcall(buildLAMPanel)
			BMR._panelBuildOk = panelBuildOk
			BMR._panelBuildError = nil
			if not panelBuildOk then BMR._panelBuildError = tostring(panelBuildError) end
			BMR.ProfileDiagnostic(panelBuildOk and "LAM_BUILD_COMPLETE" or "LAM_BUILD_FAILED", tostring(panelBuildError or "ok") .. "; phase=" .. tostring(BMR._panelBuildPhase) .. "; " .. BMR.ProfileDebugSnapshot())
			if not panelBuildOk then
				BMR.ProfileDiagnosticChat("LAM-/Einstellungsaufbau fehlgeschlagen: " .. tostring(panelBuildError) .. ". Bank-/Profilfunktionen werden weiter initialisiert; Einstellungen können fehlen.")
				-- Do not abort all BMR startup because the settings UI failed in
				-- ForceConsoleFlow. Continue only when SavedVariables and profiles exist.
				if not coreStoreOk or type(db) ~= "table" or type(db.profiles) ~= "table" then
					BMR.ProfileDiagnostic("BMR_RUNTIME_INITIALIZATION_ABORTED", "SavedVariables/profile store unavailable after settings build failure")
					return
				end
			end
			local contextMenuCallOk, contextMenuRegistered, contextMenuMessage = pcall(BMR.CustomRules.RegisterCustomItemContextMenuActions)
			local contextMenuReady = contextMenuCallOk and contextMenuRegistered == true
			local contextMenuStatus = contextMenuCallOk and (contextMenuMessage or (contextMenuRegistered and "registered" or "not registered")) or tostring(contextMenuRegistered)
			BMR.ProfileDiagnostic(contextMenuReady and "CONTEXT_MENU_REGISTERED" or "CONTEXT_MENU_REGISTER_FAILED", tostring(contextMenuStatus))
			local gamepadBridgeLoaded = type(IsAddOnLoaded) == "function" and IsAddOnLoaded("LibGamepadContextMenuBridge") == true
			local libCustomMenuLoaded = type(LibCustomMenu) == "table" and type(LibCustomMenu.RegisterContextMenu) == "function"
			local controllerFlow = BMR.Console and type(BMR.Console.IsControllerFlowActive) == "function" and BMR.Console.IsControllerFlowActive()
			if controllerFlow and (not gamepadBridgeLoaded or not libCustomMenuLoaded or not contextMenuReady) then
				BMR.ProfileDiagnostic("GAMEPAD_CONTEXT_ACTION_DEPENDENCY_MISSING", "LibCustomMenu=" .. tostring(libCustomMenuLoaded) .. "; LibGamepadContextMenuBridge=" .. tostring(gamepadBridgeLoaded) .. "; BMR callback=" .. tostring(contextMenuReady))
				BMR.ProfileDiagnosticChat("BMR: Y/Aktionen benötigt LibCustomMenu 7.3.0+ und LibGamepadContextMenuBridge 1.5.1+. Registrierung: " .. tostring(contextMenuStatus))
			end
			
			-- Move GUI to its saved position
			local anchorsOk, anchorsError = pcall(RebuildAnchorsGUI)
			BMR.ProfileDiagnostic(anchorsOk and "GUI_ANCHORS_REBUILT" or "GUI_ANCHOR_REBUILD_FAILED", tostring(anchorsError or "ok") .. "; " .. BMR.ProfileDebugSnapshot())
			if not anchorsOk then BMR.ProfileDiagnosticChat("BMR Profilwechsler-Position konnte nicht gesetzt werden: " .. tostring(anchorsError)) end
			
			local esoPlusOk, esoPlusValue = pcall(IsESOPlusSubscriber)
			isESOPlusSubscriber = esoPlusOk and esoPlusValue or false
			if not esoPlusOk then BMR.ProfileDiagnosticChat("BMR: ESO-Plus-Status nicht verfügbar: " .. tostring(esoPlusValue):gsub("[\r\n]+", " "):sub(1, 130)) end
			
			-- Register / Unregister
			BMR._startupPhase = "register-bank-events"
			BMR.ProfileDiagnostic("BANK_EVENTS_REGISTERING", "personal and guild bank callbacks; " .. BMR.ProfileDebugSnapshot())
			EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_OPEN_BANK, BMR.ProfileDebugWrapEvent("EVENT_OPEN_BANK", onOpenBank))
			EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CLOSE_BANK, BMR.ProfileDebugWrapEvent("EVENT_CLOSE_BANK", onCloseBank))
			
			EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GUILD_BANK_SELECTED, BMR.ProfileDebugWrapEvent("EVENT_GUILD_BANK_SELECTED", onGuildBankSelected))
			EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GUILD_BANK_ITEMS_READY, BMR.ProfileDebugWrapEvent("EVENT_GUILD_BANK_ITEMS_READY", onGuildBankItemsReady))
			EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CLOSE_GUILD_BANK, BMR.ProfileDebugWrapEvent("EVENT_CLOSE_GUILD_BANK", onCloseGuildBank))
			BMR._bankEventsRegistered = true
			BMR.ProfileDiagnostic("BANK_EVENTS_REGISTERED", BMR.ProfileDebugSnapshot())

			-- Bind the controller UI proactively: do not wait for displayUI() to run first.
			BMR.Console.InstallSceneHooks()
			BMR.Console.RefreshForScene()
			if not BMR.Console.modeEventHooksRegistered then
				BMR.Console.modeEventHooksRegistered = true
				EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ConsoleModeChanged", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
					BMR.ProfileDiagnostic("CONSOLE_GAMEPAD_MODE_CHANGED", "mode=" .. tostring(BMR.Console.IsModeActive()))
					BMR.Console.RefreshForScene()
				end)
				EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ConsolePlayerActivated", EVENT_PLAYER_ACTIVATED, function()
					BMR.Console.RefreshForScene()
					if not BMR.customItemActionsRegistered and BMR.CustomRules and type(BMR.CustomRules.RegisterCustomItemContextMenuActions) == "function" then
						local retryOk, retryRegistered, retryMessage = pcall(BMR.CustomRules.RegisterCustomItemContextMenuActions)
						BMR.ProfileDiagnostic(retryOk and retryRegistered and "CONTEXT_MENU_RETRY_REGISTERED" or "CONTEXT_MENU_RETRY_FAILED", tostring(retryMessage or retryRegistered))
					end
				end)
			end
			
			EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
			BMR._startupPhase = "complete"
			BMR._bmrInitializationComplete = true
			BMR._bmrInitializationRunning = false
			BMR.ProfileDiagnostic("BMR_ADDON_INITIALIZATION_COMPLETE", BMR.ProfileDebugSnapshot())
		else
			BMR._startupPhase = "rule-module-missing-after-retries"
			BMR._ruleBuildOk = false
			BMR._ruleBuildError = "BankManagerRules module missing after deferred startup retries"
			BMR.ProfileDiagnosticChat("BMR: BankManagerRules wurde nicht geladen; Einstellungen/Regeln sind unvollständig.")
			BMR.ProfileDiagnostic("INITIALIZATION_ABORTED", "BankManagerRules is missing")
			BMR._bmrInitializationRunning = false
		end
	end
	
end

-- Called by UI
function BankManagerRevived_nextRule(_, step)
	local ok, err = pcall(nextRule, step)
	if not ok then
		BMR.ProfileDiagnostic("PROFILE_ARROW_ERROR", "step=" .. tostring(step) .. "; error=" .. tostring(err) .. "; " .. BMR.ProfileDebugSnapshot())
		BMR.ProfileDiagnosticChat("Fehler beim Wechseln des Profils: " .. tostring(err))
	end
end

-- Called by UI
function BankManagerRevived_executeRule(isHousingAutoRescan)
	if BMR._ruleBuildOk == false then
		BMR.ProfileDiagnostic("RULE_EXECUTION_BLOCKED", "rule build failed; " .. tostring(BMR._ruleBuildError or "unknown error"))
		if not BMR._ruleExecutionBlockedNoticeShown then
			BMR._ruleExecutionBlockedNoticeShown = true
			BMR.ProfileDiagnosticChat("BMR: Regelaufbau fehlgeschlagen; automatische Transfers sind bis zur Fehlerbehebung gesperrt. /bmr/consoledebug zeigt den Fehler.")
		end
		return
	end
	if isHousingAutoRescan ~= true and not inProgress then
		housingAutoRescanPasses = 0
	end
	-- Resync the active bank bag before deciding where this profile run should go.
	if isBanking and not checkingGBank then RefreshActiveHouseStorageBagContext("PROFILE_ICON_CLICK") end
	-- Invoked by the central profile icon: log every gate and capture a fresh,
	-- read-only PvP snapshot before applying the selected rules.
	CustomRuleDebug(string.format("PROFILE ICON CLICK profile=%s isBanking=%s checkingGBank=%s inProgress=%s runPhase=%s autoTransfert=%s activeHouseStorageBag=%s pushQueue=%d pullQueue=%d activeVerification=%s expectedTraceCount=%d", tostring(actualProfile), tostring(isBanking), tostring(checkingGBank), tostring(inProgress), tostring(activeRuleRunPhase), tostring(db and db.profiles and db.profiles[actualProfile] and db.profiles[actualProfile].autoTransfert), tostring(activeHouseStorageBagId), #pushQueue, #pullQueue, tostring(activeTransferVerificationDebug ~= nil), #pvpExpectedMoveTraces))
	if db and db.customRulesDebug == true then
		if isBanking and not checkingGBank then
			BMR_DumpPvpStorageSnapshot("PROFILE_ICON_CLICK pre-rule execution")
		else
			CustomRuleDebug(string.format("PROFILE ICON SNAPSHOT SKIP reason=isBanking:%s checkingGBank:%s", tostring(isBanking), tostring(checkingGBank)))
		end
	end
	if checkingGBank then
		CustomRuleDebug(string.format("PROFILE ICON ROUTE target=GUILD_BANK inProgress=%s currentGuild=%s", tostring(inProgress), tostring(currentGBankName)))
		doInteractionWithGBank()
	elseif inProgress and activeRuleRunPhase == "moving" then
		profileIconRerunRequested = true
		CustomRuleDebug(string.format("PROFILE ICON RERUN DEFERRED reason=current move loop is active phase=%s pushQueue=%d pullQueue=%d activeVerification=%s; one fresh run will start after completion", tostring(activeRuleRunPhase), #pushQueue, #pullQueue, tostring(activeTransferVerificationDebug ~= nil)))
	else
		local routeTarget = activeHouseStorageBagId and (IsFurnitureVaultBag(activeHouseStorageBagId) and "FURNITURE_VAULT" or "HOUSE_STORAGE_CHEST") or "PERSONAL_BANK"
		local routeBag = activeHouseStorageBagId or BAG_BANK
		CustomRuleDebug(string.format("PROFILE ICON ROUTE target=%s bag=%s; calling interactWithBank", routeTarget, tostring(routeBag)))
		interactWithBank()
	end
	CustomRuleDebug(string.format("PROFILE ICON CLICK RETURN inProgress=%s runPhase=%s pushQueue=%d pullQueue=%d activeVerification=%s deferredRerun=%s", tostring(inProgress), tostring(activeRuleRunPhase), #pushQueue, #pullQueue, tostring(activeTransferVerificationDebug ~= nil), tostring(profileIconRerunRequested)))
	
end

-- Called by UI
function BankManagerRevived_saveGuiPosition()

	local _, _, rightScreen, bottomScreen = GuiRoot:GetScreenRect()
	local _, _, right, bottom = BankManager:GetScreenRect()

	db.gui_x = math.floor(right-rightScreen)
	db.gui_y = math.floor(bottom-bottomScreen)
	
end

-- Called by Bindings
function BankManagerRevived_runProfile(profile)
	BMR.ProfileDiagnostic("PROFILE_HOTKEY_REQUEST", "profile=" .. tostring(profile) .. "; " .. BMR.ProfileDebugSnapshot())
	local requestedProfile = db and db.profiles and db.profiles[profile]
	if type(requestedProfile) == "table" and requestedProfile.defined then
		
		actualProfile = profile
		db.actualProfile[GetUnitName("player")] = profile
		
		-- Sync LAM
		CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)
		
		if isBanking then
		
			for i=2, db.profileCount do
				if db.profiles[i].defined == true then
					multipleProfiles = true
					break
				end
			end
			
			-- Display UI only if 2 profiles are defined or if actual is on manual mode
			if not db.profiles[actualProfile].autoTransfert or multipleProfiles then
				displayUI(multipleProfiles)
			end
			
			if checkingGBank then
				doInteractionWithGBank()
			else
				interactWithBank()
			end
			
		end
		
	end

end

-- For API
function BankManagerRevived_inProgress()
	return inProgress
end

-- TEMPORARY Brand Oil diagnostics. This deliberately does not move items:
-- first identify the actual remaining-energy field before testing transfer logic.
SLASH_COMMANDS["/bmr/brandoil/debug"] = function()
	local bags = {
		{ id = BAG_BACKPACK, label = "Inventar" },
		{ id = BAG_BANK, label = "Bank" },
		{ id = BAG_SUBSCRIBER_BANK, label = "ESO+-Bank" },
	}
	local found = 0
	for _, bag in ipairs(bags) do
		for slot = 0, (GetBagSize(bag.id) or 0) - 1 do
			local link = GetItemLink(bag.id, slot)
			local itemId = link and GetItemLinkItemId(link)
			if itemId == 30359 or itemId == 214329 then
				found = found + 1
				local stack = GetSlotStackSize(bag.id, slot) or 1
				local okCondition, condition = pcall(GetItemCondition, bag.id, slot)
				local okCharge, charges, maxCharges = pcall(GetChargeInfoForItem, bag.id, slot)
				local raw = tostring(link or "")
				local payload = string.match(raw, "|H%d:item:([^|]+)|h") or "NOT_PARSED"
				d(string.format("[BMR Brandöl-Debug] %s Slot=%d ID=%d Stack=%d Condition=%s Charge=%s/%s LinkPayload=%s",
					bag.label, slot, itemId, stack,
					(okCondition and tostring(condition) or "ERROR:" .. tostring(condition)),
					(okCharge and tostring(charges) or "ERROR:" .. tostring(charges)),
					(okCharge and tostring(maxCharges) or "?"), payload))
				d("[BMR Brandöl-Debug] Zusatzwerte: " .. GetBrandOilDiagnosticInfo(bag.id, slot, link))
			end
		end
	end
	if found == 0 then
		d("[BMR Brandöl-Debug] Keine Brandöl-Stacks gefunden. Bitte persönliche Bank öffnen und prüfen, dass Brandöl in Inventar oder Bank liegt.")
	else
		d(string.format("[BMR Brandöl-Debug] Fertig. %d Stack(s) untersucht; es wurden keine Gegenstände bewegt.", found))
	end
end


-- TEMPORARY Brand Oil one-stack test: rank stacks by the energy value in item-link payload field 20.
-- For observed Brand Oil links, 0 denotes a full/unused item; nonzero values are remaining energy.
local function BMR_BrandOilReadStacks()
	local results = { backpack = {}, bank = {} }
	local bags = {
		{ id = BAG_BACKPACK, label = "Inventar", group = "backpack" },
		{ id = BAG_BANK, label = "Bank", group = "bank" },
		{ id = BAG_SUBSCRIBER_BANK, label = "ESO+-Bank", group = "bank" },
	}
	for _, bag in ipairs(bags) do
		for slot = 0, (GetBagSize(bag.id) or 0) - 1 do
			local link = GetItemLink(bag.id, slot)
			if link and GetItemLinkItemId(link) == 30359 then
				local payload = string.match(tostring(link), "|H%d:item:([^|]+)|h")
				local fields = {}
				if payload then for field in string.gmatch(payload, "([^:]+)") do fields[#fields + 1] = field end end
				local rawEnergy = tonumber(fields[20])
				if rawEnergy ~= nil then
					local energy = rawEnergy == 0 and 100000 or rawEnergy
					results[bag.group][#results[bag.group] + 1] = {
						bagId = bag.id, bagLabel = bag.label, slot = slot, link = link,
						payload = payload, energy = energy, rawEnergy = rawEnergy,
						stack = GetSlotStackSize(bag.id, slot) or 1,
					}
				else
					d(string.format("[BMR Brandöl-Sync] Kann Energie nicht auslesen: %s Slot=%d Link=%s", bag.label, slot, tostring(link)))
				end
			end
		end
	end
	return results
end

local function BMR_BrandOilFindEmptySlot(bagId)
	-- Use the same occupancy source as BMR's normal mover. IsSlotUsed/GetItemLink
	-- can disagree with the shared inventory cache, which led to choosing an
	-- occupied destination slot and RequestMoveItem silently doing nothing.
	local bagCache = SHARED_INVENTORY and SHARED_INVENTORY.bagCache and SHARED_INVENTORY.bagCache[bagId]
	if not bagCache then
		d(string.format("[BMR Brandöl-Sync] Inventarcache für Ziel-Bag=%s fehlt; kein Transfer gestartet.", tostring(bagId)))
		return nil
	end
	for slot = 0, (GetBagSize(bagId) or 0) - 1 do
		if not bagCache[slot] then
			-- Extra guard: never choose a slot that currently reports an item link/ID.
			local link = GetItemLink(bagId, slot)
			local itemId = link and GetItemLinkItemId(link) or 0
			if not link or link == "" or itemId == 0 then
				return slot
			end
		end
	end
	return nil
end

local function BMR_BrandOilMove(entry, destBag, destLabel, callback)
	local destSlot = BMR_BrandOilFindEmptySlot(destBag)
	if destSlot == nil then
		d(string.format("[BMR Brandöl-Sync] Kein freier Slot in %s gefunden (Bag=%s Größe=%s). IsSlotUsed=%s. Abbruch.", destLabel, tostring(destBag), tostring(GetBagSize(destBag)), tostring(type(IsSlotUsed))))
		return false
	end
	d(string.format("[BMR Brandöl-Sync] Bewegungsauftrag: Stack=%d Energie=%d von %s Slot=%d nach %s Slot=%d",
		entry.stack, entry.energy, entry.bagLabel, entry.slot, destLabel, destSlot))
	local sourceLinkBefore = GetItemLink(entry.bagId, entry.slot)
	local sourceStackBefore = GetSlotStackSize(entry.bagId, entry.slot) or 0

	-- Schedule the protected move on the next UI tick and inspect CallSecureProtected's
	-- return value. Previously the return value was ignored, so a rejected API call looked
	-- like a valid move request and the sync could only notice later that nothing happened.
	zo_callLater(function()
		local callOk, callError
		if IsProtectedFunction and IsProtectedFunction("RequestMoveItem") then
			callOk, callError = CallSecureProtected("RequestMoveItem", entry.bagId, entry.slot, destBag, destSlot, entry.stack)
		else
			RequestMoveItem(entry.bagId, entry.slot, destBag, destSlot, entry.stack)
			callOk = true
		end
		if not callOk then
			d(string.format("[BMR Brandöl-Sync] API-Aufruf fehlgeschlagen: RequestMoveItem wurde nicht angenommen. Rückgabe=%s", tostring(callError)))
			d("[BMR Brandöl-Sync] Synchronisierung gestoppt; es wird kein weiterer Bewegungsauftrag gesendet.")
			return
		end
		if RegisterExpectedPvpMoveTrace then RegisterExpectedPvpMoveTrace(entry.bagId, entry.slot, destBag, destSlot, entry.stack, sourceLinkBefore) end
		-- A successful secure API call only means it was accepted, not that the item moved.
		-- Verify the actual source slot before continuing with the next item.
		zo_callLater(function()
			local sourceLinkAfter = GetItemLink(entry.bagId, entry.slot)
			local sourceStackAfter = GetSlotStackSize(entry.bagId, entry.slot) or 0
			local sourceUnchanged = sourceLinkAfter == sourceLinkBefore and sourceStackAfter == sourceStackBefore
			if sourceUnchanged then
				d(string.format("[BMR Brandöl-Sync] API-Aufruf angenommen, aber Bewegung NICHT bestätigt; Quelle %s Slot=%d ist unverändert. Synchronisierung gestoppt.", entry.bagLabel, entry.slot))
				return
			end
			d(string.format("[BMR Brandöl-Sync] Bewegung bestätigt: Quelle %s Slot=%d hat sich geändert.", entry.bagLabel, entry.slot))
			if callback then callback() end
		end, 1200)
	end, 0)
	return true
end

SLASH_COMMANDS["/bmr/brandoil/preview"] = function()
	local all = BMR_BrandOilReadStacks()
	local candidates = {}
	for _, e in ipairs(all.backpack) do candidates[#candidates + 1] = e end
	for _, e in ipairs(all.bank) do candidates[#candidates + 1] = e end
	table.sort(candidates, function(a, b) if a.energy ~= b.energy then return a.energy < b.energy end; if a.bagId ~= b.bagId then return a.bagId == BAG_BACKPACK end; return a.slot < b.slot end)
	d("[BMR Brandöl-Sync] Vorschau – keine Gegenstände bewegt; Reihenfolge nach Restenergie:")
	for _, e in ipairs(candidates) do d(string.format("[BMR Brandöl-Sync] %s Slot=%d Stack=%d Energie=%d Rohwert=%d", e.bagLabel, e.slot, e.stack, e.energy, e.rawEnergy)) end
end

SLASH_COMMANDS["/bmr/brandoil/sync"] = function()
	if type(GetBankingInteractionType) == "function" and GetBankingInteractionType() == 0 then
		d("[BMR Brandöl-Sync] Bitte zuerst die persönliche Bank öffnen.")
		return
	end
	local all = BMR_BrandOilReadStacks()
	local candidates = {}
	for _, e in ipairs(all.backpack) do candidates[#candidates + 1] = e end
	for _, e in ipairs(all.bank) do candidates[#candidates + 1] = e end
	if #candidates == 0 then d("[BMR Brandöl-Sync] Keine Brandöl-Stacks (ID 30359) gefunden."); return end
	table.sort(candidates, function(a, b) if a.energy ~= b.energy then return a.energy < b.energy end; if a.bagId ~= b.bagId then return a.bagId == BAG_BACKPACK end; return a.slot < b.slot end)
	local best = candidates[1]
	d(string.format("[BMR Brandöl-Sync] Zielstack: %s Slot=%d Energie=%d Stack=%d", best.bagLabel, best.slot, best.energy, best.stack))
	-- Keep an inventory stack if it ties for the lowest energy; otherwise empty the backpack first,
	-- then re-scan the bank and pull the lowest-energy stack. One transfer is issued per rescan.
	local keepInBackpack = nil
	for _, e in ipairs(all.backpack) do if e.energy == best.energy then keepInBackpack = e; break end end
	local function pushOtherInventoryStacks()
		local current = BMR_BrandOilReadStacks()
		local keepPayload = keepInBackpack and keepInBackpack.payload or nil
		local keepEnergy = keepInBackpack and keepInBackpack.energy or nil
		local keptOne = false
		local toMove = nil
		table.sort(current.backpack, function(a,b) return a.slot > b.slot end)
		for _, e in ipairs(current.backpack) do
			if keepPayload and not keptOne and e.payload == keepPayload and e.energy == keepEnergy then
				keptOne = true
			else
				toMove = e; break
			end
		end
		if toMove then
			BMR_BrandOilMove(toMove, BAG_BANK, "Bank", pushOtherInventoryStacks)
			return
		end
		if not keepInBackpack then
			local refreshed = BMR_BrandOilReadStacks()
			table.sort(refreshed.bank, function(a,b) if a.energy ~= b.energy then return a.energy < b.energy end; return a.slot < b.slot end)
			local pull = refreshed.bank[1]
			if pull then BMR_BrandOilMove(pull, BAG_BACKPACK, "Inventar", function() d("[BMR Brandöl-Sync] Entnahme des Zielstacks bestätigt.") end) else d("[BMR Brandöl-Sync] Kein Brandöl-Stack mehr in der Bank zum Entnehmen.") end
		else
			d("[BMR Brandöl-Sync] Fertig: niedrigste Restenergie bleibt im Inventar; übrige Brandöle wurden eingelagert.")
		end
	end
	pushOtherInventoryStacks()
end



-- Temporary Pakt-Kaltflammentribok sync test (item ID 64519).
-- Mirrors the proven Brand Oil sync: keep the stack with the least remaining
-- energy in the backpack and move all other stacks to the personal bank.
-- As with Brand Oil, payload energy 0 denotes a full/unused item for this item.
local PCFT_ITEM_ID = 64519
local function BMR_PCFTReadStacks()
	local results = { backpack = {}, bank = {} }
	local bags = {
		{ id = BAG_BACKPACK, label = "Inventar", group = "backpack" },
		{ id = BAG_BANK, label = "Bank", group = "bank" },
		{ id = BAG_SUBSCRIBER_BANK, label = "ESO+-Bank", group = "bank" },
	}
	for _, bag in ipairs(bags) do
		for slot = 0, (GetBagSize(bag.id) or 0) - 1 do
			local link = GetItemLink(bag.id, slot)
			if link and GetItemLinkItemId(link) == PCFT_ITEM_ID then
				local payload = string.match(tostring(link), "|H%d:item:([^|]+)|h")
				local fields = {}
				if payload then for field in string.gmatch(payload, "([^:]+)") do fields[#fields + 1] = field end end
				local rawEnergy = tonumber(fields[20])
				local energy = rawEnergy
				-- Like Brand Oil, a raw zero is the fully charged/unused state,
				-- not the least-energy stack. Use a high sortable sentinel.
				if energy == 0 then energy = 1000000 end
				if energy ~= nil then
					results[bag.group][#results[bag.group] + 1] = {
						bagId = bag.id, bagLabel = bag.label, slot = slot, link = link,
						payload = payload, energy = energy, rawEnergy = rawEnergy,
						stack = GetSlotStackSize(bag.id, slot) or 1,
					}
				else
					d(string.format("[BMR PCFT-Sync] Kann Energie nicht auslesen: %s Slot=%d Link=%s", bag.label, slot, tostring(link)))
				end
			end
		end
	end
	return results
end

local function BMR_PCFTFindEmptySlot(bagId)
	-- Same destination-slot validation as the Brand Oil sync.
	local bagCache = SHARED_INVENTORY and SHARED_INVENTORY.bagCache and SHARED_INVENTORY.bagCache[bagId]
	if not bagCache then
		d(string.format("[BMR PCFT-Sync] Inventarcache für Ziel-Bag=%s fehlt; kein Transfer gestartet.", tostring(bagId)))
		return nil
	end
	for slot = 0, (GetBagSize(bagId) or 0) - 1 do
		if not bagCache[slot] then
			local link = GetItemLink(bagId, slot)
			local itemId = link and GetItemLinkItemId(link) or 0
			if not link or link == "" or itemId == 0 then return slot end
		end
	end
	return nil
end

local function BMR_PCFTMove(entry, destBag, destLabel, callback)
	local destSlot = BMR_PCFTFindEmptySlot(destBag)
	if destSlot == nil then
		d(string.format("[BMR PCFT-Sync] Kein freier Slot in %s gefunden (Bag=%s Größe=%s). Abbruch.", destLabel, tostring(destBag), tostring(GetBagSize(destBag))))
		return false
	end
	d(string.format("[BMR PCFT-Sync] Bewegungsauftrag: Stack=%d Energie=%s (Rohwert=%s) von %s Slot=%d nach %s Slot=%d",
		entry.stack, tostring(entry.energy), tostring(entry.rawEnergy), entry.bagLabel, entry.slot, destLabel, destSlot))
	local sourceLinkBefore = GetItemLink(entry.bagId, entry.slot)
	local sourceStackBefore = GetSlotStackSize(entry.bagId, entry.slot) or 0
	zo_callLater(function()
		local callOk, callError
		if IsProtectedFunction and IsProtectedFunction("RequestMoveItem") then
			callOk, callError = CallSecureProtected("RequestMoveItem", entry.bagId, entry.slot, destBag, destSlot, entry.stack)
		else
			RequestMoveItem(entry.bagId, entry.slot, destBag, destSlot, entry.stack)
			callOk = true
		end
		if not callOk then
			d(string.format("[BMR PCFT-Sync] API-Aufruf fehlgeschlagen: RequestMoveItem wurde nicht angenommen. Rückgabe=%s", tostring(callError)))
			d("[BMR PCFT-Sync] Synchronisierung gestoppt; es wird kein weiterer Bewegungsauftrag gesendet.")
			return
		end
		if RegisterExpectedPvpMoveTrace then RegisterExpectedPvpMoveTrace(entry.bagId, entry.slot, destBag, destSlot, entry.stack, sourceLinkBefore) end
		zo_callLater(function()
			local sourceLinkAfter = GetItemLink(entry.bagId, entry.slot)
			local sourceStackAfter = GetSlotStackSize(entry.bagId, entry.slot) or 0
			if sourceLinkAfter == sourceLinkBefore and sourceStackAfter == sourceStackBefore then
				d(string.format("[BMR PCFT-Sync] API-Aufruf angenommen, aber Bewegung NICHT bestätigt; Quelle %s Slot=%d ist unverändert. Synchronisierung gestoppt.", entry.bagLabel, entry.slot))
				return
			end
			d(string.format("[BMR PCFT-Sync] Bewegung bestätigt: Quelle %s Slot=%d hat sich geändert.", entry.bagLabel, entry.slot))
			if callback then callback() end
		end, 1200)
	end, 0)
	return true
end

local function BMR_PCFTSortByLeastEnergy(entries)
	table.sort(entries, function(a, b)
		if a.energy ~= b.energy then return a.energy < b.energy end
		if a.bagId ~= b.bagId then return a.bagId == BAG_BACKPACK end
		return a.slot < b.slot
	end)
end

SLASH_COMMANDS["/bmr/pcft/preview"] = function()
	local all = BMR_PCFTReadStacks()
	local candidates = {}
	for _, e in ipairs(all.backpack) do candidates[#candidates + 1] = e end
	for _, e in ipairs(all.bank) do candidates[#candidates + 1] = e end
	BMR_PCFTSortByLeastEnergy(candidates)
	d("[BMR PCFT-Sync] Vorschau – keine Gegenstände bewegt; Reihenfolge nach Restenergie wie beim Brandöl-Sync:")
	for _, e in ipairs(candidates) do
		d(string.format("[BMR PCFT-Sync] %s Slot=%d Stack=%d Energie=%d Rohwert=%s Link=%s", e.bagLabel, e.slot, e.stack, e.energy, tostring(e.rawEnergy), tostring(e.link)))
	end
end

SLASH_COMMANDS["/bmr/pcft/sync"] = function()
	if type(GetBankingInteractionType) == "function" and GetBankingInteractionType() == 0 then
		d("[BMR PCFT-Sync] Bitte zuerst die persönliche Bank öffnen.")
		return
	end
	local all = BMR_PCFTReadStacks()
	local candidates = {}
	for _, e in ipairs(all.backpack) do candidates[#candidates + 1] = e end
	for _, e in ipairs(all.bank) do candidates[#candidates + 1] = e end
	if #candidates == 0 then d("[BMR PCFT-Sync] Keine Pakt-Kaltflammentriboks (ID 64519) mit lesbarem Energiewert gefunden."); return end
	BMR_PCFTSortByLeastEnergy(candidates)
	local best = candidates[1]
	d(string.format("[BMR PCFT-Sync] Zielstack: %s Slot=%d Energie=%d Rohwert=%s Stack=%d", best.bagLabel, best.slot, best.energy, tostring(best.rawEnergy), best.stack))
	-- Match the Brand Oil sync exactly: if a lowest-energy stack is already in
	-- inventory, keep one such stack and bank every other inventory stack.
	local keepInBackpack = nil
	for _, e in ipairs(all.backpack) do
		if e.energy == best.energy then keepInBackpack = e; break end
	end
	local function pushOtherInventoryStacks()
		local current = BMR_PCFTReadStacks()
		local keepPayload = keepInBackpack and keepInBackpack.payload or nil
		local keepEnergy = keepInBackpack and keepInBackpack.energy or nil
		local keptOne = false
		local toMove = nil
		table.sort(current.backpack, function(a, b) return a.slot > b.slot end)
		for _, e in ipairs(current.backpack) do
			if keepPayload and not keptOne and e.payload == keepPayload and e.energy == keepEnergy then
				keptOne = true
			else
				toMove = e; break
			end
		end
		if toMove then
			BMR_PCFTMove(toMove, BAG_BANK, "Bank", pushOtherInventoryStacks)
			return
		end
		if not keepInBackpack then
			local refreshed = BMR_PCFTReadStacks()
			BMR_PCFTSortByLeastEnergy(refreshed.bank)
			local pull = refreshed.bank[1]
			if pull then
				BMR_PCFTMove(pull, BAG_BACKPACK, "Inventar", function() d("[BMR PCFT-Sync] Entnahme des Zielstacks bestätigt.") end)
			else
				d("[BMR PCFT-Sync] Kein Tribok-Stack mehr in der Bank zum Entnehmen.")
			end
		else
			d("[BMR PCFT-Sync] Fertig: Stack mit der niedrigsten Restenergie bleibt im Inventar; übrige Triboks wurden eingelagert.")
		end
	end
	pushOtherInventoryStacks()
end


SLASH_COMMANDS["/bmr/profiledebug"] = function(argument)
	local command = string.lower(tostring(argument or ""))
	if string.find(command, "clear", 1, true) then
		if type(db) == "table" then db.profileDebugLog = {} end
		BMR.ProfileDiagnosticChat("Protokoll geleert.")
		return
	end
	BMR.ProfileDiagnosticDump()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, onAddonLoaded)
-- Defensive fallback for ForceConsoleFlow/.addon loading variants that do not dispatch
-- EVENT_ADD_ON_LOADED to this handler at the expected point. The handler is idempotent.
zo_callLater(function()
	if not BMR._addonLoadEventMatched and not BMR._bmrInitializationComplete and not BMR._bmrInitializationRunning then
		onAddonLoaded(nil, ADDON_NAME)
	end
end, 250)
