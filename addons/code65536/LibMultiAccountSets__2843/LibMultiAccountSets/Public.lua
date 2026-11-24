local LCCC = LibCodesCommonCode
local Internal = LibMultiAccountSetsInternal
local Public = LibMultiAccountSets


--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

-- Item collection and tradability status
Public.ITEM_UNCOLLECTIBLE        = nil -- Not a collectible set item
Public.ITEM_COLLECTED            = 1 -- Collected by the specified account
Public.ITEM_UNCOLLECTED_TRADE    = 2 -- Not collected by and tradeable with the specified account
Public.ITEM_UNCOLLECTED_NOTRADE  = 3 -- Not collected by and not tradeable with the specified account
Public.ITEM_UNCOLLECTED_UNKTRADE = 4 -- Not collected by the specified account, with unknown trade eligibility

-- Callback events
Public.EVENT_INITIALIZED = 1
Public.EVENT_COLLECTION_UPDATED = 2


--------------------------------------------------------------------------------
-- Base-Game Analogues (plus IsItemSetCollectionItemLinkUnlocked)
--------------------------------------------------------------------------------

function Public.GetNumItemSetCollectionSlotsUnlockedForAccountEx( server, account, itemSetId )
	if (server == Internal.server and account == Internal.account) then
		return GetNumItemSetCollectionSlotsUnlocked(itemSetId)
	else
		return select("#", GetItemSetCollectionSlotsInMask(NumberToId64(Internal.GetOrSetData(server, account, itemSetId))))
	end
end

function Public.IsItemSetCollectionSlotUnlockedForAccountEx( server, account, itemSetId, slot )
	if (server == Internal.server and account == Internal.account) then
		return IsItemSetCollectionSlotUnlocked(itemSetId, slot)
	else
		local slot = Id64ToNumber(slot)
		return BitAnd(Internal.GetOrSetData(server, account, itemSetId), slot) == slot
	end
end

function Public.IsItemSetCollectionPieceUnlockedForAccountEx( server, account, pieceId )
	if (server == Internal.server and account == Internal.account) then
		return IsItemSetCollectionPieceUnlocked(pieceId)
	else
		return Public.IsItemSetCollectionItemLinkUnlockedForAccountEx(server, account, GetItemSetCollectionPieceItemLink(pieceId, LINK_STYLE_DEFAULT, ITEM_TRAIT_TYPE_NONE))
	end
end

function Public.GetItemReconstructionCurrencyOptionCostForAccountEx( server, account, itemSetId, currencyType )
	if (server == Internal.server and account == Internal.account) then
		return GetItemReconstructionCurrencyOptionCost(itemSetId, currencyType)
	elseif (currencyType == CURT_CHAOTIC_CREATIA) then
		local setSize = GetNumItemSetCollectionPieces(itemSetId)
		local collected = Public.GetNumItemSetCollectionSlotsUnlockedForAccountEx(server, account, itemSetId)
		if (setSize > 0 and collected > 0) then
			local completion = (setSize == 1) and 1 or (collected - 1) / (setSize - 1)
			return zo_floor(75 - 50 * completion)
		end
	end
	return nil
end

function Public.IsItemSetCollectionItemLinkUnlockedForAccountEx( server, account, itemLink )
	if (server == Internal.server and account == Internal.account) then
		return IsItemSetCollectionPieceUnlocked(GetItemLinkItemId(itemLink))
	else
		return Public.IsItemSetCollectionSlotUnlockedForAccountEx(server, account, select(6, GetItemLinkSetInfo(itemLink)), GetItemLinkItemSetCollectionSlot(itemLink))
	end
end


--------------------------------------------------------------------------------
-- Other Functions
--------------------------------------------------------------------------------

function Public.GetAccountList( excludeCurrentAccount )
	local accounts = { }
	local data = Internal.data[Internal.server]
	if (data) then
		for account in pairs(data) do
			if (not (excludeCurrentAccount and account == Internal.account)) then
				table.insert(accounts, account)
			end
		end
		table.sort(accounts)
	end
	return accounts
end

function Public.GetServerAndAccountList( alwaysIncludeCurrentAccount )
	local results = { }
	for _, server in ipairs(LCCC.GetSortedKeys(Internal.data, Internal.server)) do
		local accounts = LCCC.GetSortedKeys(Internal.data[server], Internal.account)
		if (#accounts > 0) then
			table.insert(results, { server = server, accounts = accounts })
		end
	end
	if (alwaysIncludeCurrentAccount) then
		if (not results[1] or results[1].server ~= Internal.server) then
			table.insert(results, 1, { server = Internal.server, accounts = { Internal.account } })
		elseif (results[1].accounts[1] ~= Internal.account) then
			table.insert(results[1].accounts, 1, Internal.account)
		end
	end
	return results
end

do
	local NO_SOURCE = { }
	local singleAccountList

	local function GetStatus( account, itemLink, tradeEligibility )
		if (Public.IsItemSetCollectionItemLinkUnlockedForAccount(account, itemLink)) then
			return Public.ITEM_COLLECTED
		elseif (tradeEligibility[account] == true) then
			return Public.ITEM_UNCOLLECTED_TRADE
		elseif (tradeEligibility[account] == false) then
			return Public.ITEM_UNCOLLECTED_NOTRADE
		else
			return Public.ITEM_UNCOLLECTED_UNKTRADE
		end
	end

	function Public.GetItemCollectionAndTradabilityStatus( accounts, itemLink, itemSource )
		if (type(itemSource) ~= "table") then
			itemSource = NO_SOURCE
		end

		if (not itemLink) then
			if (itemSource.bagId and itemSource.slotIndex) then
				itemLink = GetItemLink(itemSource.bagId, itemSource.slotIndex)
			elseif (itemSource.who and itemSource.tradeIndex) then
				itemLink = GetTradeItemLink(itemSource.who, itemSource.tradeIndex)
			elseif (itemSource.lootId) then
				itemLink = GetLootItemLink(itemSource.lootId)
			else
				return Public.ITEM_UNCOLLECTIBLE
			end
		end

		if (not IsItemLinkSetCollectionPiece(itemLink)) then
			return Public.ITEM_UNCOLLECTIBLE
		end

		if (type(accounts) == "string") then
			-- Single account
			singleAccountList = LCCC.PrepareScratchTable(singleAccountList, accounts)
			return GetStatus(accounts, itemLink, Internal.GetTradeEligibility(itemLink, itemSource, singleAccountList))
		else
			-- Multiple accounts
			if (not accounts) then
				accounts = Public.GetAccountList(true)
				table.insert(accounts, Internal.account)
			end

			local tradeEligibility = Internal.GetTradeEligibility(itemLink, itemSource, accounts)

			local results = { }
			for _, account in ipairs(accounts) do
				results[account] = GetStatus(account, itemLink, tradeEligibility)
			end
			return results
		end
	end
end

function Public.GetLastScanTimeEx( server, account )
	if (server == Internal.server and account == Internal.account) then
		return Internal.DecodeAtIndex(Internal.AccessCurrentData(), 1)
	else
		return Internal.GetOrSetData(server, account, 0)
	end
end

function Public.GetMaxItemSetCollectionId( )
	if (Internal.maxSetId == 0) then
		local setId = GetNextItemSetCollectionId()
		while (setId) do
			Internal.maxSetId = zo_max(Internal.maxSetId, setId)
			setId = GetNextItemSetCollectionId(setId)
		end
	end
	return Internal.maxSetId
end


--------------------------------------------------------------------------------
-- Raw Data Access
--------------------------------------------------------------------------------

function Public.GetRawDataEx( server, account, itemSetId )
	if (type(itemSetId) == "number" and itemSetId > 0 and itemSetId <= Public.GetMaxItemSetCollectionId() and zo_floor(itemSetId) == itemSetId) then
		return Internal.GetOrSetData(server, account, itemSetId)
	else
		return 0
	end
end

function Public.SetRawDataEx( server, account, itemSetId, slots )
	if ( type(itemSetId) == "number" and itemSetId > 0 and itemSetId <= Public.GetMaxItemSetCollectionId() and zo_floor(itemSetId) == itemSetId and
	     type(slots) == "number" and slots >= 0 and slots < 0x1000000000 and zo_floor(slots) == slots ) then
		return Internal.GetOrSetData(server, account, itemSetId, slots)
	else
		return false
	end
end


--------------------------------------------------------------------------------
-- Callbacks
--------------------------------------------------------------------------------

Internal.callbacks = {
	[Public.EVENT_INITIALIZED] = { },
	[Public.EVENT_COLLECTION_UPDATED] = { },
}

function Public.RegisterForCallback( name, eventCode, callback )
	if (type(name) == "string" and type(eventCode) == "number" and type(callback) == "function" and Internal.callbacks[eventCode]) then
		Internal.callbacks[eventCode][name] = callback
		return true
	end
	return false
end

function Public.UnregisterForCallback( name, eventCode )
	if (type(name) == "string" and type(eventCode) == "number" and Internal.callbacks[eventCode]) then
		Internal.callbacks[eventCode][name] = nil
		return true
	end
	return false
end

function Internal.FireCallbacks( eventCode, ... )
	for _, callback in pairs(Internal.callbacks[eventCode]) do
		callback(eventCode, ...)
	end
end


--------------------------------------------------------------------------------
-- Server-Aware API
--------------------------------------------------------------------------------

for _, name in ipairs({
	"GetNumItemSetCollectionSlotsUnlockedForAccount",
	"IsItemSetCollectionSlotUnlockedForAccount",
	"IsItemSetCollectionPieceUnlockedForAccount",
	"GetItemReconstructionCurrencyOptionCostForAccount",
	"IsItemSetCollectionItemLinkUnlockedForAccount",
	"GetLastScanTime",
	"GetRawData",
	"SetRawData",
}) do
	local nameEx = name .. "Ex"

	-- Standardize the server and account input checks as common code across all functions
	local fn = Public[nameEx]
	Public[nameEx] = function( server, account, ... )
		if (not server or server == "") then server = Internal.server end
		if (not account or account == "") then account = Internal.account end
		return fn(server, account, ...)
	end

	-- Re-create the severless functions for backwards compatibility
	Public[name] = function( ... )
		return Public[nameEx](nil, ...)
	end
end


--------------------------------------------------------------------------------
-- Deprecated
--------------------------------------------------------------------------------

Public.AddAccountsCollectionStatusToTooltip = LCCC.NOP
