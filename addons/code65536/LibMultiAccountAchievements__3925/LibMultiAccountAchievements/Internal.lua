local LCCC = LibCodesCommonCode

local Public = { }
LibMultiAccountAchievements = Public


--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

local Internal = {
	name = "LibMultiAccountAchievements",

	scanThrottle = 500, -- 0.5s

	server = LCCC.GetServerName(),
	userId = GetDisplayName(),
	charId = GetCurrentCharacterId(),

	cache = { },
}
LibMultiAccountAchievementsInternal = Internal

local function OnAddOnLoaded( eventCode, addonName )
	if (addonName ~= Internal.name) then return end

	EVENT_MANAGER:UnregisterForEvent(Internal.name, EVENT_ADD_ON_LOADED)

	-- Initialize data store
	if (not LibMultiAccountAchievementsData) then LibMultiAccountAchievementsData = { } end
	Internal.vars = LibMultiAccountAchievementsData

	if (not Internal.vars.data or not Internal.vars.chars or not Internal.vars.accts or not Internal.vars.next) then
		Internal.vars.data = { }
		Internal.vars.chars = { }
		Internal.vars.accts = { }
		Internal.vars.next = 1
	end

	Internal.data = Internal.vars.data
	Internal.chars = Internal.vars.chars
	Internal.accts = Internal.vars.accts

	if (Internal.vars.api ~= GetAPIVersion()) then
		Internal.vars.api = GetAPIVersion()
		Internal.vars.maxId = nil
	end

	LCCC.RunAfterInitialLoadscreen(function( )
		Internal.RemoveExcludedAccounts()
		Internal.RegisterSettingsPanel()
		if (Internal.CanSave()) then
			-- Listen for achievement updates
			EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_ACHIEVEMENTS_UPDATED, Internal.Refresh)
			EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_ACHIEVEMENT_AWARDED, Internal.Refresh)
			EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_ACHIEVEMENT_UPDATED, Internal.Refresh)
			Internal.Refresh()
		end
	end)
end

EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)


--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

local function NeededBits( n )
	return zo_floor(math.log(n) / math.log(2)) + 1
end

local function Pack( str )
	return LCCC.Chunk(LCCC.Implode(str))
end

local function Unpack( str )
	return LCCC.Explode(LCCC.Unchunk(str))
end

local function AccountKey( server, account )
	return string.format("%s,%s", server or Internal.server, account or Internal.userId)
end

local function IsAccountWide( achievementId )
	-- ACHIEVEMENT_PERSISTENCE_UNDEFINED should return true
	return GetAchievementPersistenceLevel(achievementId) ~= ACHIEVEMENT_PERSISTENCE_CHARACTER
end


--------------------------------------------------------------------------------
-- Miscellaneous
--------------------------------------------------------------------------------

function Internal.CanSave( account )
	if (Internal.vars.noSave and Internal.vars.noSave[zo_strlower(account or Internal.userId)]) then
		return false
	else
		return true
	end
end

function Internal.RemoveExcludedAccounts( )
	local purgeIndices = { }
	local purgeCharIds = { }
	for idx, key in pairs(Internal.accts) do
		local _, account = zo_strsplit(",", key)
		if (account and not Internal.CanSave(account)) then
			table.insert(purgeIndices, idx)
			for charId in pairs(Internal.chars) do
				if (idx == Internal.GetAccountIndexFromCharacter(charId)) then
					table.insert(purgeCharIds, charId)
				end
			end
		end
	end
	for _, id in ipairs(purgeIndices) do
		Internal.data[Internal.accts[id]] = nil
		Internal.accts[id] = nil
	end
	for _, id in ipairs(purgeCharIds) do
		Internal.data[id] = nil
		Internal.chars[id] = nil
	end
end

function Internal.GetMaxAchievementId( )
	if (not Internal.vars.maxId) then
		local MAX_CONSECUTIVE_INVALID_IDS = 250 -- Highest observed: 49
		local currentId = 1
		local invalidCount = 0
		local lastValidId = 0

		repeat
			if (GetAchievementNumCriteria(currentId) == 0) then
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

function Internal.GetAccountIndexFromCharacter( charId )
	local idx = zo_strsplit(",", Internal.chars[charId or Internal.charId])
	return idx and tonumber(idx) or nil
end

function Internal.GetAccountIndexFromKey( accountKey )
	for idx, key in pairs(Internal.accts) do
		if (key == accountKey) then
			return idx
		end
	end
	return nil
end

function Internal.UpdateCharacter( )
	local acctKey = AccountKey()
	local acctIndex = Internal.GetAccountIndexFromCharacter() or Internal.GetAccountIndexFromKey(acctKey)
	if (not acctIndex) then
		acctIndex = Internal.vars.next
		Internal.vars.next = Internal.vars.next + 1
	end
	Internal.accts[acctIndex] = acctKey
	Internal.chars[Internal.charId] = string.format("%d,%s", acctIndex, GetUnitName("player"))
end

function Internal.IsOwnerCurrentPlayer( owner )
	if ( (owner == nil) or
	     (owner == Internal.charId) or
	     (type(owner) == "table" and (owner[1] == nil or owner[1] == Internal.server) and (owner[2] == nil or owner[2] == Internal.userId)) ) then
		return true
	else
		return false
	end
end


--------------------------------------------------------------------------------
-- Scanning and Encoding
--------------------------------------------------------------------------------

local BITS = 6
local TIMESTAMP_BYTES = 6
local SIZE_PROGRESS_MASK = 0x1F
local SIZE_TIMESTAMP_FLAG = 0x20
local MAX_SAFE_PROGRESS_BYTES = 7

function Internal.Refresh( )
	EVENT_MANAGER:UnregisterForUpdate(Internal.name)
	EVENT_MANAGER:RegisterForUpdate(Internal.name, Internal.scanThrottle, Internal.ScanAchievements, true)
end

local resultsA = { }
local resultsC = { }
function Internal.ScanAchievements( )
	for id = 1, Internal.GetMaxAchievementId() do
		local progress = ""
		local sum = 0
		local bitsUsed = 0

		local store = function( bytesToStore )
			local bitsToStore = bytesToStore * BITS
			local sumToStore = sum % (2 ^ bitsToStore)
			sum = BitRShift(sum, bitsToStore)
			bitsUsed = bitsUsed - bitsToStore
			return LCCC.Encode(sumToStore, bytesToStore)
		end

		-- Store full multiple-of-6-bit blocks of information
		for i = 1, GetAchievementNumCriteria(id) do
			local _, cur, max = GetAchievementCriterion(id, i)
			sum = sum + BitLShift(cur, bitsUsed)
			bitsUsed = bitsUsed + NeededBits(max)
			if (bitsUsed >= BITS) then
				progress = store(zo_floor(bitsUsed / BITS)) .. progress
			end
		end

		-- Finalize: store any remaining bits and strip off any leading zeros
		progress = store(zo_ceil(bitsUsed / BITS)) .. progress
		progress = string.gsub(progress, "^0+", "")

		-- lower 5 bits: size of progress field
		-- upper bit: 1 for a 6-byte timestamp, 0 for a zero timestamp
		local size = zo_strlen(progress)

		-- For large progress that exceed 42 bits, also store the decimal progress
		local decProgress = ""
		if (size > MAX_SAFE_PROGRESS_BYTES) then
			decProgress = Id64ToString(GetAchievementProgress(id))
			decProgress = LCCC.Encode(zo_strlen(decProgress), 1) .. decProgress
		end

		-- Acquire the timestamp
		local timestamp = GetAchievementTimestamp(id)
		if (timestamp > 0) then
			timestamp = LCCC.Encode(timestamp, TIMESTAMP_BYTES)
			size = BitOr(size, SIZE_TIMESTAMP_FLAG)
		else
			timestamp = ""
		end

		local isAwA = IsAccountWide(id)
		table.insert(isAwA and resultsA or resultsC, string.format("%s%s%s%s", LCCC.Encode(size, 1), progress, timestamp, decProgress))
		table.insert(isAwA and resultsC or resultsA, "0")
	end

	-- Store the data
	Internal.UpdateCharacter()
	Internal.data[AccountKey()] = Pack(table.concat(resultsA, ""))
	Internal.data[Internal.charId] = Pack(table.concat(resultsC, ""))

	-- Invalidate the cache
	Internal.cache[AccountKey()] = nil
	Internal.cache[Internal.charId] = nil

	ZO_ClearTable(resultsA)
	ZO_ClearTable(resultsC)
end


--------------------------------------------------------------------------------
-- Decoding
--------------------------------------------------------------------------------

function Internal.DecodeData( key )
	if (type(key) ~= "string" or not Internal.data[key]) then
		-- Invalid
		return nil
	end

	if (Internal.cache[key]) then
		-- Data already cached
		return Internal.cache[key]
	end

	-- Decode and cache the data
	local decoded = { }
	local encoded = Unpack(Internal.data[key])
	local pos = 1

	for id = 1, Internal.GetMaxAchievementId() do
		local size, progress, timestamp

		-- Extract the encoded size field
		size, pos = LCCC.ReadAndDecode(encoded, pos, 1)
		local progressBytes = BitAnd(size, SIZE_PROGRESS_MASK)

		-- Extract the encoded progress
		local progressStartPos = pos
		if (progressBytes > 0) then
			pos = pos + progressBytes
		end
		local progressEndPos = pos

		-- Extract the timestamp
		if (BitAnd(size, SIZE_TIMESTAMP_FLAG) > 0) then
			timestamp, pos = LCCC.ReadAndDecode(encoded, pos, TIMESTAMP_BYTES)
		else
			timestamp = 0
		end

		-- Extract the decimal progress, if necessary
		if (progressBytes > MAX_SAFE_PROGRESS_BYTES) then
			size, pos = LCCC.ReadAndDecode(encoded, pos, 1)
			progress = zo_strsub(encoded, pos, pos + size - 1)
			pos = pos + size
		else
			progress = LCCC.ReadAndDecode(encoded, progressStartPos, progressBytes)
		end

		-- Initialize data
		decoded[id] = {
			criteria = { },
			timestamp = timestamp,
			progress = StringToId64(progress),
		}

		-- Decode the progress into individual criterion numbers
		local bitsUsed = 0
		for i = 1, GetAchievementNumCriteria(id) do
			local bitPosStart = bitsUsed
			local bitsNeeded = NeededBits(select(3, GetAchievementCriterion(id, i)))
			bitsUsed = bitPosStart + bitsNeeded

			-- Note: bitPos is 0-based, but bytePos is 1-based
			-- These are reverse positions within the progress substring: zo_strsub(encodedProgress, -bytePosEnd, -bytePosStart)
			local bytePosStart = zo_floor(bitPosStart / BITS) + 1
			local bytePosEnd = zo_ceil(bitsUsed / BITS)

			-- Convert to forward positions usable with the overall string: zo_strsub(encoded, overallBytePosStart, overallBytePosEnd)
			local overallBytePosStart = zo_max(progressStartPos, progressEndPos - bytePosEnd)
			local overallBytePosEnd = progressEndPos - bytePosStart

			local cur = LCCC.ReadAndDecode(encoded, overallBytePosStart, overallBytePosEnd - overallBytePosStart + 1)
			cur = BitRShift(cur, bitPosStart - (bytePosStart - 1) * BITS)
			cur = BitAnd(cur, 2 ^ bitsNeeded - 1)

			table.insert(decoded[id].criteria, cur)
		end
	end

	Internal.cache[key] = decoded
	return decoded
end

function Internal.ReadData( owner, achievementId )
	local result = {
		criteria = { },
		timestamp = 0,
		progress = StringToId64("0"),
	}

	local numCriteria = GetAchievementNumCriteria(achievementId)

	if (numCriteria == 0) then
		-- Invalid achievement; do nothing and return the default empty data
	else
		local isAwA = IsAccountWide(achievementId)
		local key

		if (type(owner) == "string") then
			if (isAwA) then
				local acctIndex = Internal.GetAccountIndexFromCharacter(owner)
				key = (acctIndex and Internal.accts[acctIndex]) or "-"
			else
				key = owner
			end
		elseif (type(owner) == "table") then
			key = isAwA and AccountKey(unpack(owner)) or "-"
		else
			key = isAwA and AccountKey() or Internal.charId
		end

		local data = Internal.DecodeData(key)
		if (data and data[achievementId]) then
			-- Valid achievement and character
			result = data[achievementId]
		else
			-- Valid achievement, but invalid character; populate the criteria with zeros
			for i = 1, numCriteria do
				table.insert(result.criteria, 0)
			end
		end
	end

	return result
end
