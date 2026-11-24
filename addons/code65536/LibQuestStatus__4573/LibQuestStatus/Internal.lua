local LCCC = LibCodesCommonCode
local LSRT = LibServerResetTime

local Public = { }
LibQuestStatus = Public


--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

local Internal = {
	name = "LibQuestStatus",

	scanThrottle = 200, -- 0.2s

	server = LCCC.GetServerName(),
	userId = GetDisplayName(),
	charId = GetCurrentCharacterId(),
	charName = GetUnitName("player"),

	initialized = false,
}
LibQuestStatusInternal = Internal

local function OnAddOnLoaded( eventCode, addonName )
	if (addonName ~= Internal.name) then return end

	EVENT_MANAGER:UnregisterForEvent(Internal.name, EVENT_ADD_ON_LOADED)

	-- Initialize data store
	LibQuestStatusData = LibQuestStatusData or { }
	Internal.vars = LibQuestStatusData
	Internal.vars.data = Internal.vars.data or { }
	Internal.data = Internal.vars.data

	-- Invalidate the cached max quest ID for major updates
	if (Internal.vars.api ~= GetAPIVersion()) then
		Internal.vars.api = GetAPIVersion()
		Internal.vars.maxId = nil
	end

	LCCC.RunAfterInitialLoadscreen(function( )
		Internal.DataHousekeeping()
		Internal.RegisterSettingsPanel()
		if (Internal.CanSave()) then
			-- Listen for quest updates
			EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_QUEST_ADDED, Internal.Refresh)
			EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_QUEST_ADVANCED, Internal.Refresh)
			EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_QUEST_REMOVED, Internal.QuestRemoved)
			Internal.Refresh()
		end
	end)
end

EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)


--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local QUEST_ID_BYTES = 3
local ACTIVE_QUEST_BYTES = 4 -- 24 bits: questId [15b; 0-14], conditionType [8b; 15-22], completed [1b; 23]
local COMPLETION_BLOCK_BYTES = 6
local COMPLETION_BLOCK_BITS = 36
local CHUNK_BYTES = 0x700
local CHUNK_BITS = 0x2A00


--------------------------------------------------------------------------------
-- General
--------------------------------------------------------------------------------

function Internal.Msg( text )
	CHAT_ROUTER:AddSystemMessage(text)
end

function Internal.CanSave( account )
	if (Internal.vars.noSave and Internal.vars.noSave[zo_strlower(account or Internal.userId)]) then
		return false
	else
		return true
	end
end

function Internal.DoesCharacterExist( server, charId )
	local serverData = Internal.data[server]
	return serverData ~= nil and serverData[charId] ~= nil
end

function Internal.GetCharacterField( server, charId, field )
	local serverData = Internal.data[server]
	return serverData and serverData[charId] and serverData[charId][field]
end

function Internal.SetCharacterField( server, charId, field, data, chunk )
	local serverData = Internal.data[server]
	if (not serverData) then
		serverData = { }
		Internal.data[server] = serverData
	end
	if (not serverData[charId]) then
		serverData[charId] = { }
	end
	serverData[charId][field] = chunk and LCCC.Chunk(data, CHUNK_BYTES) or data
end

function Internal.GetCurrentCharacterField( ... )
	return Internal.GetCharacterField(Internal.server, Internal.charId, ...)
end

function Internal.SetCurrentCharacterField( ... )
	Internal.SetCharacterField(Internal.server, Internal.charId, ...)
end

function Internal.GetMaxQuestId( )
	if (not Internal.vars.maxId) then
		local MAX_CONSECUTIVE_INVALID_IDS = 400 -- Highest observed: 201
		local currentId = 1
		local invalidCount = 0
		local lastValidId = 0

		repeat
			if (GetQuestName(currentId) == "") then
				invalidCount = invalidCount + 1
			else
				invalidCount = 0
				lastValidId = currentId
			end
			currentId = currentId + 1
		until invalidCount >= MAX_CONSECUTIVE_INVALID_IDS

		Internal.vars.maxId = lastValidId
	end

	return Internal.vars.maxId
end

function Internal.DataHousekeeping( )
	local server = Internal.server
	local currentTime = GetTimeStamp()

	-- Ensure that names are always current
	for i = 1, GetNumCharacters() do
		local name, _, _, _, _, _, id = GetCharacterInfo(i)
		if (Internal.DoesCharacterExist(server, id)) then
			Internal.SetCharacterField(server, id, "account", Internal.userId)
			Internal.SetCharacterField(server, id, "name", LocalizeString("<<1>>", name))
		end
	end

	-- Check for account exclusions and cooldown cleanup
	local requestedPurges
	for server, serverData in pairs(Internal.data) do
		for charId, charData in pairs(serverData) do
			local account = charData.account
			if (account and not Internal.CanSave(account)) then
				requestedPurges = requestedPurges or { }
				table.insert(requestedPurges, { server, charId })
			else
				Internal.PruneCooldowns(server, charData, currentTime)
			end
		end
	end

	-- Remove excluded accounts
	if (requestedPurges) then
		for _, purge in ipairs(requestedPurges) do
			Internal.data[purge[1]][purge[2]] = nil
		end
	end
end


--------------------------------------------------------------------------------
-- Cooldowns
--------------------------------------------------------------------------------

function Internal.GetCooldownKey( year, month )
	return 12 * (year - 2020) + month - 1
end

function Internal.PruneCooldowns( server, char, currentTime )
	local charData = char
	if (type(char) == "string") then
		charData = Internal.data[server] and Internal.data[server][char]
	end

	if (charData) then
		local requestedPurges

		for key in pairs(charData) do
			if (type(key) == "number") then
				local purge
				if (key == 1) then
					purge = LSRT.GetResetTimestamp(false, false, server, charData.timestamp) <= currentTime
				elseif (key == 7) then
					purge = LSRT.GetResetTimestamp(false, true, server, charData.timestamp) <= currentTime
				else
					purge = key <= Internal.GetCooldownKey(LSRT.GetServerDate(server))
				end
				if (purge) then
					requestedPurges = requestedPurges or { }
					table.insert(requestedPurges, key)
				end
			end
		end

		if (requestedPurges) then
			for _, key in ipairs(requestedPurges) do
				charData[key] = nil
			end
		end
	end
end

function Internal.IsQuestOnCooldown( server, charId, questId )
	local timestamp = Internal.GetCharacterField(server, charId, "timestamp")
	if (timestamp) then
		local repeatType = Public.GetQuestRepeatableType(questId)
		if (repeatType == QUEST_REPEAT_DAILY) then
			if (LSRT.GetResetTimestamp(false, false, server, timestamp) > GetTimeStamp()) then
				return Internal.IsQuestIdInField(server, charId, 1, questId)
			end
		elseif (repeatType == QUEST_REPEAT_WEEKLY) then
			if (LSRT.GetResetTimestamp(false, true, server, timestamp) > GetTimeStamp()) then
				return Internal.IsQuestIdInField(server, charId, 7, questId)
			end
		elseif (repeatType == QUEST_REPEAT_MONTHLY or repeatType == QUEST_REPEAT_REPEATABLE_PER_DURATION) then
			local key = Internal.GetCooldownKey(LSRT.GetServerDate())
			return Internal.IsQuestIdInField(server, charId, key + 1, questId) or Internal.IsQuestIdInField(server, charId, key + 2, questId)
		end
	end
	return false
end


--------------------------------------------------------------------------------
-- Scanning and Encoding
--------------------------------------------------------------------------------

function Internal.Refresh( )
	EVENT_MANAGER:UnregisterForUpdate(Internal.name)
	EVENT_MANAGER:RegisterForUpdate(
		Internal.name,
		Internal.scanThrottle,
		function( )
			EVENT_MANAGER:UnregisterForUpdate(Internal.name)
			Internal.ScanQuests()
		end
	)
end

function Internal.QuestRemoved( _, isCompleted, _, _, _, _, questId )
	if (isCompleted) then
		if (Internal.pendingCooldowns) then
			table.insert(Internal.pendingCooldowns, questId)
		else
			Internal.pendingCooldowns = { questId }
		end
	end
	Internal.Refresh()
end

function Internal.ScanQuests( )
	local currentTime = GetTimeStamp()

	-- Scan for quest completion -----------------------------------------------

	local field = 0
	local completion = { }

	-- Pad the scan to a full block
	local maxScanId = zo_ceil(Internal.GetMaxQuestId() / COMPLETION_BLOCK_BITS) * COMPLETION_BLOCK_BITS

	for questId = 1, maxScanId do
		field = field * 2
		if (HasCompletedQuest(questId)) then
			field = field + 1
		end
		if (questId % COMPLETION_BLOCK_BITS == 0) then
			table.insert(completion, LCCC.Encode(field, COMPLETION_BLOCK_BYTES))
			field = 0
		end
	end

	-- Scan active quests ------------------------------------------------------

	local active = { }

	for i = 1, GetNumJournalQuests() do
		-- See definition of ACTIVE_QUEST_BYTES above
		table.insert(active, LCCC.Encode(
			BitAnd(GetJournalQuestId(i), 0x7FFF) +
			BitLShift(BitAnd(select(8, GetJournalQuestConditionInfo(i, 1, 1)), 0xFF), 15) +
			BitLShift(GetJournalQuestIsComplete(i) and 1 or 0, 23),
			ACTIVE_QUEST_BYTES
		))
	end

	-- Repeatable quest cooldowns-----------------------------------------------

	if (Internal.pendingCooldowns) then
		Internal.PruneCooldowns(Internal.server, Internal.charId, currentTime)

		local cooldowns = { }

		for _, questId in ipairs(Internal.pendingCooldowns) do
			local key = nil

			local repeatType = Public.GetQuestRepeatableType(questId)
			if (repeatType == QUEST_REPEAT_DAILY) then
				key = 1
			elseif (repeatType == QUEST_REPEAT_WEEKLY) then
				key = 7
			elseif (repeatType == QUEST_REPEAT_MONTHLY) then
				key = Internal.GetCooldownKey(LSRT.GetServerDate()) + 1
			elseif (repeatType == QUEST_REPEAT_REPEATABLE_PER_DURATION) then
				key = Internal.GetCooldownKey(LSRT.GetServerDate()) + 2
			end

			if (key) then
				if (not cooldowns[key]) then
					local existing = Internal.GetCurrentCharacterField(key)
					cooldowns[key] = existing and { existing } or { }
				end
				table.insert(cooldowns[key], LCCC.Encode(questId, QUEST_ID_BYTES))
			end
		end

		Internal.pendingCooldowns = nil

		for key, entries in pairs(cooldowns) do
			Internal.SetCurrentCharacterField(key, table.concat(entries, ""))
		end
	end

	-- Store and notify --------------------------------------------------------

	Internal.SetCurrentCharacterField("account", Internal.userId)
	Internal.SetCurrentCharacterField("name", Internal.charName)
	Internal.SetCurrentCharacterField("timestamp", currentTime)
	Internal.SetCurrentCharacterField("completion", table.concat(completion, ""), true)
	Internal.SetCurrentCharacterField("active", table.concat(active, ""))

	-- EVENT_QUEST_STATUS_UPDATED should not fire for the initial scan
	if (not Internal.initialized) then
		Internal.initialized = true
	else
		Internal.FireCallbacks(Public.EVENT_QUEST_STATUS_UPDATED)
	end
end


--------------------------------------------------------------------------------
-- Decoding
--------------------------------------------------------------------------------

function Internal.ReadQuestCompletion( server, charId, questId )
	return LCCC.ReadBitFromEncodedData(Internal.GetCharacterField(server, charId, "completion"), questId, CHUNK_BITS)
end

function Internal.GetActiveQuests( server, charId )
	local results = { }
	local data = Internal.GetCharacterField(server, charId, "active")
	if (data) then
		local length = zo_strlen(data)
		local pos = 1
		local field
		while (pos < length) do
			field, pos = LCCC.ReadAndDecode(data, pos, ACTIVE_QUEST_BYTES)
			results[BitAnd(field, 0x7FFF)] = {
				conditionType = BitAnd(BitRShift(field, 15), 0xFF),
				completed = BitRShift(field, 23) == 1,
			}
		end
	end
	return results
end

function Internal.IsQuestIdInField( server, charId, field, questId )
	local data = Internal.GetCharacterField(server, charId, field)
	if (data) then
		local length = zo_strlen(data)
		local pos = 1
		local field
		while (pos < length) do
			field, pos = LCCC.ReadAndDecode(data, pos, QUEST_ID_BYTES)
			if (field == questId) then
				return true
			end
		end
	end
	return false
end
