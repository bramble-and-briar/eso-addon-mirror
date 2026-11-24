local LCCC = LibCodesCommonCode

local Public = { }
LibMultiAccountCollectibles = Public


--------------------------------------------------------------------------------
-- Internal Components
--------------------------------------------------------------------------------

local Internal = {
	name = "LibMultiAccountCollectibles",

	-- Data format parameters
	FORMAT_VERSION = 2,

	scanThrottle = 200, -- 0.2s

	server = LCCC.GetServerName(),
	account = GetDisplayName(),

	currentData = "",
	initialized = false,
}
LibMultiAccountCollectiblesInternal = Internal


--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

local function OnAddOnLoaded( eventCode, addonName )
	if (addonName ~= Internal.name) then return end

	EVENT_MANAGER:UnregisterForEvent(Internal.name, EVENT_ADD_ON_LOADED)

	-- Initialize data store
	if (not LibMultiAccountCollectiblesData or type(LibMultiAccountCollectiblesData.formatVersion) ~= "number" or LibMultiAccountCollectiblesData.formatVersion > Internal.FORMAT_VERSION) then
		LibMultiAccountCollectiblesData = {
			formatVersion = Internal.FORMAT_VERSION,
		}
	end
	Internal.vars = LibMultiAccountCollectiblesData
	Internal.data = Internal.GetVarsTable("data")
	if (not Internal.data[Internal.server]) then Internal.data[Internal.server] = { } end

	-- Remove accounts that should not be saved
	for account in pairs(Internal.data[Internal.server]) do
		if (not Internal.CanSave(account)) then
			Internal.data[Internal.server][account] = nil
		end
	end

	Internal.MigrateData()

	LCCC.RunAfterInitialLoadscreen(function( )
		Internal.RegisterSettingsPanel()
		EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_COLLECTIBLES_UNLOCK_STATE_CHANGED, Internal.Refresh)
		Internal.Refresh()
	end)
end

EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)


--------------------------------------------------------------------------------
-- Scanning and Encoding
--------------------------------------------------------------------------------

local MAX_CONSECUTIVE_INVALID_IDS = 1000 -- Max observed gap: 631

-- Data encoding parameters
local ENCODE_BITS = 6 -- 6-bit encoding
local BLOCK_BITS = 36 -- Block size for single-bit data
local BLOCK_BYTES = 6 -- BLOCK_BITS / ENCODE_BITS

-- Data storage parameters
local CHUNK_BYTES = 0x600 -- Line size for LCCC.Chunk
local CHUNK_BITS = 0x2400 -- CHUNK_BYTES * ENCODE_BITS

function Internal.Refresh( )
	EVENT_MANAGER:UnregisterForUpdate(Internal.name)
	EVENT_MANAGER:RegisterForUpdate(Internal.name, Internal.scanThrottle, Internal.ScanCollection, true)
end

function Internal.Chunk( data )
	return LCCC.Chunk(data, CHUNK_BYTES)
end

function Internal.IsCollectibleOwned( collectibleId )
	if (IsCollectibleOwnedByDefId(collectibleId)) then
		return true
	elseif (GetCollectibleCategoryType(collectibleId) == COLLECTIBLE_CATEGORY_TYPE_COMBINATION_FRAGMENT and not CanCombinationFragmentBeUnlocked(collectibleId)) then
		return true
	else
		return false
	end
end

function Internal.ScanCollection( )
	-- Determine the range of valid IDs
	if (Internal.vars.api ~= GetAPIVersion() or type(Internal.vars.maxId) ~= "number") then
		local currentId = 1
		local invalidCount = 0
		local lastValidId = 0

		repeat
			if (GetCollectibleName(currentId) == "") then
				invalidCount = invalidCount + 1
			else
				invalidCount = 0
				lastValidId = currentId
			end
			currentId = currentId + 1
		until invalidCount >= MAX_CONSECUTIVE_INVALID_IDS

		Internal.vars.api = GetAPIVersion()
		Internal.vars.maxId = lastValidId
	end

	-- Pad the scan to a full block
	local maxScanId = zo_ceil(Internal.vars.maxId / BLOCK_BITS) * BLOCK_BITS

	-- Scan and encode
	local results = Internal.GetScratch(LCCC.Encode(GetTimeStamp(), BLOCK_BYTES))
	local field = 0
	for currentId = 1, maxScanId do
		field = field * 2
		if (Internal.IsCollectibleOwned(currentId)) then
			field = field + 1
		end
		if (currentId % BLOCK_BITS == 0) then
			table.insert(results, LCCC.Encode(field, BLOCK_BYTES))
			field = 0
		end
	end

	-- Save the results
	Internal.currentData = Internal.Chunk(table.concat(results, ""))
	if (Internal.CanSave()) then
		Internal.data[Internal.server][Internal.account] = Internal.currentData
	end

	-- EVENT_COLLECTION_UPDATED should not fire for the initial scan
	if (not Internal.initialized) then
		Internal.initialized = true
	else
		Internal.FireCallbacks(Public.EVENT_COLLECTION_UPDATED)
	end
end

function Internal.ReadTimeStamp( data )
	return LCCC.ReadIndexedIntegerFromEncodedData(data, 1, 1, BLOCK_BYTES)
end

function Internal.ReadId( data, id )
	if (type(id) == "number" and id > 0) then
		-- Offset by BLOCK_BITS for the timestamp
		return LCCC.ReadBitFromEncodedData(data, id + BLOCK_BITS, CHUNK_BITS)
	else
		return false
	end
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

function Internal.GetVarsTable( name )
	if (type(Internal.vars[name]) ~= "table") then
		Internal.vars[name] = { }
	end
	return Internal.vars[name]
end

function Internal.CanSave( account )
	if (Internal.GetVarsTable("noSave")[zo_strlower(account or Internal.account)]) then
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


--------------------------------------------------------------------------------
-- Format Migration
--------------------------------------------------------------------------------

function Internal.MigrateData( )
	if (Internal.vars.formatVersion == 1) then
		Internal.vars.formatVersion = Internal.FORMAT_VERSION
		for _, serverData in pairs(Internal.data) do
			for account in pairs(serverData) do
				local data = LCCC.Unchunk(serverData[account])
				if (string.byte(data, 7) == 0x2C) then
					serverData[account] = Internal.Chunk(LCCC.ReplaceSubString(data, 7, 1, ""))
				end
			end
		end
	end
end
