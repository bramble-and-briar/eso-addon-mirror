local LCCC = LibCodesCommonCode

local Public = { }
LibMultiAccountSets = Public


--------------------------------------------------------------------------------
-- Internal Components
--------------------------------------------------------------------------------

local Internal = {
	name = "LibMultiAccountSets",

	-- Default settings
	defaults = {
		chatUpdates = true,
		noSave = { },
		exportSelection = { },
	},

	scanThrottle = 1500, -- 1.5s, for the initial scan
	scanThrottleInitialized = 200, -- 0.2s, for subsequent update scans

	server = LCCC.GetServerName(),
	account = GetDisplayName(),
	maxSetId = 0,
	previousFound = 0,
	initialized = false,
}
LibMultiAccountSetsInternal = Internal


--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

local function OnAddOnLoaded( eventCode, addonName )
	if (addonName ~= Internal.name) then return end

	EVENT_MANAGER:UnregisterForEvent(Internal.name, EVENT_ADD_ON_LOADED)

	Internal.vars = ZO_SavedVars:NewAccountWide("LibMultiAccountSetsSavedVariables", 1, nil, Internal.defaults, nil, "$InstallationWide")
	Internal.MigrateData()

	-- Initialize data store
	if (not LibMultiAccountSetsData2) then LibMultiAccountSetsData2 = { } end
	Internal.data = LibMultiAccountSetsData2
	if (not Internal.data[Internal.server]) then Internal.data[Internal.server] = { } end
	Internal.serverData = Internal.data[Internal.server]

	-- Remove accounts that should not be saved
	for account in pairs(Internal.serverData) do
		if (not Internal.CanSave(account)) then
			Internal.serverData[account] = nil
		end
	end

	-- Prepare the data store for the current account
	if (Internal.CanSave()) then
		if (not Internal.serverData[Internal.account]) then
			Internal.serverData[Internal.account] = { }
		end
	else
		Internal.savelessData = { }
	end

	LCCC.RunAfterInitialLoadscreen(function( )
		Internal.RegisterSettingsPanel()
		EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_ITEM_SET_COLLECTIONS_UPDATED, Internal.RefreshCollections)
		EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_ITEM_SET_COLLECTION_UPDATED, Internal.RefreshCollections)
		Internal.RefreshCollections()
	end)
end

EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)


--------------------------------------------------------------------------------
-- Data Access
--------------------------------------------------------------------------------

local ENTRY_BYTES = 6
local CHUNK_ENTRIES = 256
local CHUNK_BYTES = ENTRY_BYTES * CHUNK_ENTRIES
Internal.ENTRY_BYTES = ENTRY_BYTES
Internal.CHUNK_BYTES = CHUNK_BYTES

local function EncodeEntry( val )
	return LCCC.Encode(val or 0, ENTRY_BYTES)
end

function Internal.Chunk( data )
	return LCCC.Chunk(data, CHUNK_BYTES)
end

function Internal.DecodeAtIndex( data, index )
	return LCCC.ReadIndexedIntegerFromEncodedData(data, index, CHUNK_ENTRIES, ENTRY_BYTES)
end

function Internal.GetOrSetData( server, account, itemSetId, slots )
	local serverData = Internal.data[server]
	local accountData = serverData and serverData[account]
	local index = itemSetId + 1
	if (not slots) then
		return Internal.DecodeAtIndex(accountData, index)
	elseif (accountData) then
		LCCC.SetIndexedIntegerInEncodedData(serverData, account, index, CHUNK_ENTRIES, ENTRY_BYTES, slots)
		return true
	else
		return false
	end
end

function Internal.AccessCurrentData( newData )
	if (not newData) then
		return Internal.savelessData or Internal.serverData[Internal.account]
	elseif (Internal.savelessData) then
		Internal.savelessData = newData
	else
		Internal.serverData[Internal.account] = newData
	end
end


--------------------------------------------------------------------------------
-- Scanning
--------------------------------------------------------------------------------

function Internal.RefreshCollections( )
	EVENT_MANAGER:UnregisterForUpdate(Internal.name)
	EVENT_MANAGER:RegisterForUpdate(Internal.name, Internal.scanThrottle, Internal.ScanSets, true)
end

function Internal.ScanSets( )
	local results = Internal.GetScratch(GetTimeStamp())
	local maxSetId = 0
	local found = 0
	local total = 0

	local setId = GetNextItemSetCollectionId()
	while (setId and setId > 0) do
		local setSize = GetNumItemSetCollectionPieces(setId)

		if (setSize > 0) then
			local result = 0

			for i = 1, setSize do
				local _, slot = GetItemSetCollectionPieceInfo(setId, i)

				if (IsItemSetCollectionSlotUnlocked(setId, slot)) then
					result = result + Id64ToNumber(slot)
					found = found + 1
				end
			end

			results[setId + 1] = result -- Item sets start at index 2
			maxSetId = zo_max(maxSetId, setId)
			total = total + setSize
		end

		setId = GetNextItemSetCollectionId(setId)
	end

	for i = 1, maxSetId + 1 do
		results[i] = EncodeEntry(results[i])
	end

	Internal.maxSetId = maxSetId
	Internal.AccessCurrentData(Internal.Chunk(table.concat(results, "")))

	if (not Internal.initialized) then
		Internal.initialized = true
		Internal.scanThrottle = Internal.scanThrottleInitialized
		Internal.FireCallbacks(Public.EVENT_INITIALIZED)
	else
		Internal.FireCallbacks(Public.EVENT_COLLECTION_UPDATED, false)
		if (Internal.vars.chatUpdates) then
			Internal.MsgTag(string.format(GetString(SI_LMAS_SCAN_STATUS), found, total, found - Internal.previousFound))
		end
	end

	Internal.previousFound = found
end


--------------------------------------------------------------------------------
-- Other Utilities
--------------------------------------------------------------------------------

function Internal.Msg( text )
	CHAT_ROUTER:AddSystemMessage(text)
end

function Internal.MsgTag( text )
	CHAT_ROUTER:AddSystemMessage(string.format("[%s] %s", Internal.name, text))
end

function Internal.CanSave( account )
	if (Internal.vars.noSave and Internal.vars.noSave[zo_strlower(account or Internal.account)]) then
		return false
	else
		return true
	end
end

do
	local scratch
	function Internal.GetScratch( ... )
		scratch = LCCC.PrepareScratchTable(scratch, ...)
		return scratch
	end
end

function Internal.GetTradeEligibility( itemLink, itemSource, accounts )
	-- Returns:
	-- false: not eligible
	-- true: eligible
	-- 0: unknown eligibility

	local results = Internal.GetScratch()

	local FillResults = function( value )
		for _, account in ipairs(accounts) do
			results[account] = value
		end
	end

	if (IsItemLinkBound(itemLink)) then
		FillResults(false)
	elseif (GetItemLinkBindType(itemLink) == BIND_TYPE_ON_PICKUP) then
		if (itemSource.bagId and itemSource.slotIndex) then
			-- Inventory and banks
			for _, account in ipairs(accounts) do
				results[account] = IsDisplayNameInItemBoPAccountTable(itemSource.bagId, itemSource.slotIndex, UndecorateDisplayName(account))
			end
		elseif (itemSource.slotIndex) then
			-- Vendor windows
			for _, account in ipairs(accounts) do
				results[account] = account == Internal.account
			end
		elseif (itemSource.who and itemSource.tradeIndex) then
			-- Trade slots
			local names = GetTradeItemBoPTradeableDisplayNamesString(itemSource.who, itemSource.tradeIndex) .. " "
			for _, account in ipairs(accounts) do
				results[account] = string.find(names, account .. "[%s,]") ~= nil
			end
		elseif (itemSource.lootId) then
			-- Loot windows
			local eligible = { [Internal.account] = true }
			if (LCCC.IsInDungeonTrialArena() and select(2, GetLootTargetInfo()) ~= INTERACT_TARGET_TYPE_ITEM) then
				-- Inside a group instance looting something that's not an inventory container
				for i = 1, GetGroupSize() do
					local unitTag = GetGroupUnitTagByIndex(i)
					local account = GetUnitDisplayName(unitTag)
					if (account) then
						eligible[account] = IsUnitOnline(unitTag) and IsGroupMemberInSameInstanceAsPlayer(unitTag)
					end
				end
			end

			for _, account in ipairs(accounts) do
				results[account] = eligible[account] == true
			end
		else
			-- All other scenarios
			FillResults(0)
		end
	else
		FillResults(true)
	end

	return results
end


--------------------------------------------------------------------------------
-- Format Migration
--------------------------------------------------------------------------------

function Internal.MigrateData( )
	if (LibMultiAccountSetsData and not LibMultiAccountSetsData2) then
		local newData = { }
		for server, serverData in pairs(LibMultiAccountSetsData) do
			newData[server] = { }
			for account, accountData in pairs(serverData) do
				local results = { EncodeEntry(accountData.timestamp) }
				for i = 1, Public.GetMaxItemSetCollectionId() do
					results[i + 1] = EncodeEntry(accountData[i])
				end
				newData[server][account] = Internal.Chunk(table.concat(results, ""))
			end
		end
		LibMultiAccountSetsData = nil
		LibMultiAccountSetsData2 = newData
	end
end
