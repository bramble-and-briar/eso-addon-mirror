local NAME = "LibCodesCommonCode"
local VERSION = 40

if (type(_G[NAME]) == "table" and type(_G[NAME].version) == "number" and _G[NAME].version >= VERSION) then return end

local Lib = { version = VERSION }
_G[NAME] = Lib


--------------------------------------------------------------------------------
-- Color functions
--------------------------------------------------------------------------------

do
	local function i2c( n, pos )
		return BitRShift(n, pos) % 0x100 / 255
	end

	local function c2i( n, pos )
		return BitLShift(n * 255 % 0x100, pos)
	end

	function Lib.Int24ToRGB( rgb )
		return i2c(rgb, 16), i2c(rgb, 8), i2c(rgb, 0)
	end

	function Lib.Int24ToRGBA( rgb )
		return i2c(rgb, 16), i2c(rgb, 8), i2c(rgb, 0), 1
	end

	function Lib.Int32ToRGBA( rgba )
		return i2c(rgba, 24), i2c(rgba, 16), i2c(rgba, 8), i2c(rgba, 0)
	end

	function Lib.RGBToInt24( r, g, b )
		return c2i(r, 16) + c2i(g, 8) + c2i(b, 0)
	end

	function Lib.RGBAToInt32( r, g, b, a )
		return c2i(r, 24) + c2i(g, 16) + c2i(b, 8) + c2i(a, 0)
	end

	function Lib.Int24ToInt32( rgb, a )
		return BitLShift(rgb, 8) + BitAnd((a or 1) * 255, 0xFF)
	end

	function Lib.Int32ToInt24( rgba )
		return BitRShift(rgba, 8)
	end

	local function h2c( p, q, t )
		t = t - zo_floor(t)
		if (t < 1/6) then return p + (q - p) * 6 * t end
		if (t < 1/2) then return q end
		if (t < 2/3) then return p + (q - p) * (2/3 - t) * 6 end
		return p
	end

	function Lib.HSLToRGB( h, s, l, a )
		if (s == 0) then
			return l, l, l, a
		else
			local q = (l < 0.5) and (l * (1 + s)) or (l + s - l * s)
			local p = 2 * l - q
			return h2c(p, q, h + 1/3), h2c(p, q, h), h2c(p, q, h - 1/3), a
		end
	end

	function Lib.Int24ToHSL( rgb )
		return ConvertRGBToHSL(Lib.Int24ToRGB(rgb))
	end

	function Lib.Int32ToHSLA( rgba )
		local r, g, b, a = Lib.Int32ToRGBA(rgba)
		local h, s, l = ConvertRGBToHSL(r, g, b)
		return h, s, l, a
	end

	local hslCache
	function Lib.GetGradientRGBA( rgbaStart, rgbaEnd, ratio, reverseColorWheelDirection )
		hslCache = hslCache or { }
		local s = hslCache[rgbaStart] or { Lib.Int32ToHSLA(rgbaStart) }
		local e = hslCache[rgbaEnd] or { Lib.Int32ToHSLA(rgbaEnd) }
		hslCache[rgbaStart] = s
		hslCache[rgbaEnd] = e

		local ehue = e[1]
		if (reverseColorWheelDirection) then
			ehue = ehue + (ehue < s[1] and 1 or -1)
		end

		local er = zo_clamp(ratio, 0, 1)
		local sr = 1 - er
		return Lib.HSLToRGB(
			s[1] * sr + ehue * er,
			s[2] * sr + e[2] * er,
			s[3] * sr + e[3] * er,
			s[4] * sr + e[4] * er
		)
	end

	function Lib.GetGradientInt32( ... )
		return Lib.RGBAToInt32(Lib.GetGradientRGBA(...))
	end
end


--------------------------------------------------------------------------------
-- 6-bit encode/decode
--------------------------------------------------------------------------------

do
	local DICT = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#%"

	local ENCODE = { __index = function( tbl, key )
		local result = string.byte(DICT, key + 1)
		tbl[key] = result
		return result
	end }
	setmetatable(ENCODE, ENCODE)

	local DECODE = { __index = function( tbl, key )
		if (key) then
			local found, pos = zo_plainstrfind(DICT, string.char(key))
			if (found) then
				pos = pos - 1
				tbl[key] = pos
				return pos
			end
		end
	end }
	setmetatable(DECODE, DECODE)

	-- Defined here to avoid repeated creation costs
	local buffer = { }

	function Lib.Encode( number, size )
		-- Values for size:
		-- 0: Pad result to an even number of bytes (the number 0 will encode to an empty string)
		-- n: Pad result to a minimum length of n bytes
		-- nil: Do not pad results (the number 0 will encode to an empty string)

		local i = 1

		while (number > 0) do
			i = i - 1
			buffer[i] = ENCODE[number % 0x40]
			number = zo_floor(number / 0x40)
		end

		-- Pad result as necessary
		if (size == 0) then
			if (-i % 2 == 0) then
				i = i - 1
				buffer[i] = 0x30
			end
		elseif (size and size > 1 - i) then
			local start = 1 - size
			for j = start, i - 1 do
				buffer[j] = 0x30
			end
			i = start
		end

		return string.char(unpack(buffer, i))
	end

	function Lib.Decode( encoded )
		return (Lib.ReadAndDecode(encoded, 1, zo_strlen(encoded)))
	end

	function Lib.ReadAndDecode( encoded, pos, bytes )
		local result = 0
		local newPos = pos + bytes
		for i = pos, newPos - 1 do
			local n = DECODE[string.byte(encoded, i)]
			if (not n) then return 0, newPos end
			result = result * 0x40 + n
		end
		return result, newPos
	end

	function Lib.ReadBitFromEncodedData( data, pos, bitsPerLine )
		-- The byte position is little-endian (lower index is in the lower-order
		-- byte), but within each byte, it is big-endian (lower index is in the
		-- higher-order bit).
		if (pos > 0) then
			pos = pos - 1
			if (type(data) == "table") then
				data = data[zo_floor(pos / bitsPerLine) + 1]
				pos = pos % bitsPerLine
			end
			if (type(data) == "string") then
				return BitRShift(DECODE[string.byte(data, zo_floor(pos / 6) + 1)] or 0, 5 - pos % 6) % 2 == 1
			end
		end
		return false
	end

	function Lib.ReadIndexedIntegerFromEncodedData( data, index, itemsPerLine, bytesPerItem )
		if (index > 0) then
			index = index - 1
			if (type(data) == "table") then
				data = data[zo_floor(index / itemsPerLine) + 1]
				index = index % itemsPerLine
			end
			if (type(data) == "string") then
				return (Lib.ReadAndDecode(data, index * bytesPerItem + 1, bytesPerItem))
			end
		end
		return 0
	end

	function Lib.SetBitInEncodedData( tbl, key, pos, bitsPerLine, boolBitState )
		if (pos > 0) then
			pos = pos - 1
			local data = tbl[key]
			if (type(data) == "table") then
				tbl = data
				key = zo_floor(pos / bitsPerLine) + 1
				data = data[key]
				pos = pos % bitsPerLine
			end
			if (type(data) == "string") then
				local bytePos = zo_floor(pos / 6) + 1
				local value = DECODE[string.byte(data, bytePos)] or 0
				local shift = 5 - pos % 6
				local mask = 2 ^ shift
				local newValue = boolBitState and BitOr(value, mask) or BitAnd(value, BitNot(mask, 8))
				if (newValue ~= value) then
					tbl[key] = Lib.ReplaceSubString(data, bytePos, 1, Lib.Encode(newValue, 1))
				end
			end
		end
	end

	function Lib.SetIndexedIntegerInEncodedData( tbl, key, index, itemsPerLine, bytesPerItem, newValue )
		if (index > 0) then
			index = index - 1
			local data = tbl[key]
			if (type(data) == "table") then
				tbl = data
				key = zo_floor(index / itemsPerLine) + 1
				data = data[key]
				index = index % itemsPerLine
			end
			if (type(data) == "string") then
				local bytePos = index * bytesPerItem + 1
				if (newValue ~= Lib.ReadAndDecode(data, bytePos, bytesPerItem)) then
					tbl[key] = Lib.ReplaceSubString(data, bytePos, bytesPerItem, Lib.Encode(newValue, bytesPerItem))
				end
			end
		end
	end
end


--------------------------------------------------------------------------------
-- Consolidator for 6-bit encoded data
--------------------------------------------------------------------------------

do
	-- 12th bit (0x800) is a flag
	-- Lower 11 bits encode the length, for a maximum of 0x7FF

	local function consolidate( str, char, flag )
		local result = string.gsub(str, string.format("(%s+)", string.rep(char, 4)), function( capture )
			local length = zo_strlen(capture)
			if (length <= 0x7FF) then
				return "~" .. Lib.Encode(0x800 * flag + length, 2)
			else
				local encoded = ""
				repeat
					local chunk = (length <= 0x7FF) and length or 0x7FF
					encoded = encoded .. "~" .. Lib.Encode(0x800 * flag + chunk, 2)
					length = length - chunk
				until length <= 0
				return encoded
			end
		end)
		return result
	end

	function Lib.Implode( str )
		return consolidate(consolidate(str, "0", 0), "%%", 1)
	end

	function Lib.Explode( str )
		local result = string.gsub(str, "~(..)", function( capture )
			local code = Lib.Decode(capture)
			return string.rep((BitRShift(code, 11) == 0) and "0" or "%", code % 0x800)
		end)
		return result
	end
end


--------------------------------------------------------------------------------
-- String chunk/unchunk
-- Accommodation for the 2000-byte limit for strings in saved variables
--------------------------------------------------------------------------------

do
	local DEFAULT_CHUNK_SIZE = 0x600

	function Lib.Chunk( str, chunkSize )
		if (type(chunkSize) ~= "number") then
			chunkSize = DEFAULT_CHUNK_SIZE
		end

		local length = zo_strlen(str)
		if (length <= chunkSize) then
			return str
		else
			local result = { }
			local i, j = 1
			while (i <= length) do
				j = i + chunkSize
				table.insert(result, zo_strsub(str, i, j - 1))
				i = j
			end
			return result
		end
	end

	function Lib.Unchunk( chunked )
		if (type(chunked) == "string") then
			return chunked
		elseif (type(chunked) == "table") then
			return table.concat(chunked, "")
		else
			return ""
		end
	end
end


--------------------------------------------------------------------------------
-- General
--------------------------------------------------------------------------------

Lib.NOP = function() end

-- Concise server name
do
	local name = GetWorldName()
	name = ({
		["NA Megaserver"] = "NA",
		["EU Megaserver"] = "EU",
		["XB1live"] = "NA",
		["XB1live-eu"] = "EU",
		["PS4live"] = "NA",
		["PS4live-eu"] = "EU",
	})[name] or name

	function Lib.GetServerName( )
		return name
	end
end

-- Wrapper for initial EVENT_PLAYER_ACTIVATED
do
	local id = 0

	function Lib.RunAfterInitialLoadscreen( func )
		id = id + 1
		EVENT_MANAGER:RegisterForEvent(string.format("%s%d_%d", NAME, VERSION, id), EVENT_PLAYER_ACTIVATED, func, true)
	end
end

-- Safety wrapper to avoid old un-manifested copies of LibAddonMenu
function Lib.GetLibAddonMenu( )
	if (LibStub and not ZO_IsConsoleOrGameCoreUI()) then
		local version = select(2, LibStub("LibAddonMenu-2.0", true))
		if (version and version < 36) then
			return nil
		end
	end
	return LibAddonMenu2
end


--------------------------------------------------------------------------------
-- Zone functions
--------------------------------------------------------------------------------

do
	local name = string.format("%s%d_ZoneChange", NAME, VERSION)
	local callbacks = { }
	local registered = false
	local zoneId, difficulty

	local function onPlayerActivated( )
		local previousZoneId = zoneId
		local currentZoneId = Lib.GetZoneId()
		local currentDifficulty = GetCurrentZoneDungeonDifficulty()

		if (zoneId ~= currentZoneId or difficulty ~= currentDifficulty) then
			zoneId = currentZoneId
			difficulty = currentDifficulty
			for _ , callback in pairs(callbacks) do
				callback(currentZoneId, previousZoneId or 0)
			end
		end
	end

	-- Omit the callback parameter to unregister
	function Lib.MonitorZoneChanges( id, callback )
		callbacks[id] = callback
		if (not registered and next(callbacks)) then
			registered = true
			EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, onPlayerActivated)
		end
	end

	function Lib.GetZoneId( )
		return GetZoneId(GetUnitZoneIndex("player"))
	end

	function Lib.GetZoneName( zoneId, useFallback )
		local name = GetZoneNameById(zoneId)
		if (useFallback and name == "") then
			return string.format("[#%d]", zoneId)
		else
			return ZO_CachedStrFormat(SI_ZONE_NAME, name)
		end
	end

	local DTA_WHITELIST = {
		[1562] = true, -- Gossamer Crypt
		[1563] = true, -- Mournful Catacomb
		[1564] = true, -- Timeless Wallow
		[1565] = true, -- Opulent Ordeal
	}

	function Lib.IsInDungeonTrialArena( )
		return GetCurrentZoneDungeonDifficulty() ~= DUNGEON_DIFFICULTY_NONE or DTA_WHITELIST[Lib.GetZoneId()] == true
	end
end


--------------------------------------------------------------------------------
-- Slash command helpers
--------------------------------------------------------------------------------

function Lib.RegisterSlashCommands( func, ... )
	for i = 1, select("#", ...) do
		SLASH_COMMANDS[select(i, ...)] = func
	end
	return func
end

function Lib.TokenizeSlashCommandParameters( params )
	local tokens = { }
	if (type(params) == "string") then
		for _, token in ipairs({ zo_strsplit(" ", zo_strlower(params)) }) do
			tokens[token] = true
		end
	end
	return tokens
end


--------------------------------------------------------------------------------
-- Table functions
--------------------------------------------------------------------------------

function Lib.GetSortedKeys( tbl, first, compare )
	local keys = { }
	for key in pairs(tbl) do
		table.insert(keys, key)
	end
	table.sort(keys, function( a, b )
		if (a == first) then
			return true
		elseif (b == first) then
			return false
		elseif (compare) then
			return compare(a, b)
		else
			return a < b
		end
	end)
	return keys
end

function Lib.ProcessNumericTable( tbl, func, ... )
	local index = 0
	local prev = 0
	for _, i in ipairs(tbl) do
		local isNumber = type(i) == "number"
		if (isNumber and i < 0) then
			for j = prev + 1, -i do
				index = index + 1
				func(j, index, ...)
			end
		else
			index = index + 1
			func(i, index, ...)
			if (isNumber) then
				prev = i
			end
		end
	end
end

function Lib.MergeTables( dest, src, overwrite )
	if (type(dest) ~= "table") then
		dest = { }
	end
	for k, v in pairs(src) do
		if (overwrite == 2 or dest[k] == nil) then
			if (type(v) == "table") then
				dest[k] = Lib.MergeTables(dest[k], v, overwrite)
			else
				dest[k] = v
			end
		elseif (overwrite == 1 and type(dest[k]) == "table" and type(v) == "table") then
			Lib.MergeTables(dest[k], v, overwrite)
		end
	end
	return dest
end

function Lib.ConcatTables( dest, src )
	for _, v in ipairs(src) do
		table.insert(dest, v)
	end
	return dest
end

function Lib.PrepareScratchTable( tbl )
	if (not tbl) then return { } end
	ZO_ClearTable(tbl)
	return tbl
end

function Lib.SetupOnDemandDataTable( dataTable, dataFunctions )
	setmetatable(dataTable, { __index = function( tbl, key )
		local func = dataFunctions[key]
		if (func) then
			local result = func()
			tbl[key] = result
			return result
		end
	end })
end

function Lib.ReadOnlyTable( tbl )
	local proxy = { }
	setmetatable(proxy, { __index = tbl, __newindex = Lib.NOP })
	return proxy
end


--------------------------------------------------------------------------------
-- String functions
--------------------------------------------------------------------------------

-- Convert number-like strings to numbers
function Lib.FixNumber( a )
	if (type(a) == "string" and string.find(a, "^[+-]?[%.%d]*%d$")) then
		return tonumber(a)
	else
		return a
	end
end

-- Are two strings identical, ignoring case and formatting flags?
function Lib.MatchStrings( a, b )
	return LocalizeString("<<z:1>>", a) == LocalizeString("<<z:1>>", b)
end

function Lib.ReplaceSubString( origString, pos, bytes, newSubString )
	return zo_strsub(origString, 1, pos - 1) .. newSubString .. zo_strsub(origString, pos + bytes)
end

function Lib.CompareCharIds( a, b )
	return CompareId64s(StringToId64(a), StringToId64(b)) < 0
end


--------------------------------------------------------------------------------
-- Localization functions
--------------------------------------------------------------------------------

function Lib.RegisterString( id, text, version )
	if (_G[id]) then
		SafeAddString(_G[id], text, version or 1)
	else
		ZO_CreateStringId(id, text)
		if (version) then
			SafeAddVersion(_G[id], version)
		end
	end
end

do
	local LANG = GetCVar("Language.2")

	function Lib.GetLocalizedData( data )
		if (type(data) == "table") then
			return data[LANG] or data.default
		end
	end
end


--------------------------------------------------------------------------------
-- Get a list of group members that is sorted by role and name
--------------------------------------------------------------------------------

do
	local ROLE_ORDER = {
		[LFG_ROLE_TANK] = 1,
		[LFG_ROLE_HEAL] = 2,
		[LFG_ROLE_DPS] = 3,
		[LFG_ROLE_INVALID] = 4,
	}

	local function compare( a, b )
		local ra = ROLE_ORDER[a.role]
		local rb = ROLE_ORDER[b.role]
		if (ra == rb) then
			return a.account < b.account
		else
			return ra < rb
		end
	end

	function Lib.GetSortedGroupMembers( )
		local groupSize = GetGroupSize()

		if (groupSize > 0) then
			local units = { }

			for i = 1, groupSize do
				local unitTag = GetGroupUnitTagByIndex(i)
				if (unitTag) then
					table.insert(units, {
						unitTag = unitTag,
						account = GetUnitDisplayName(unitTag),
						name = GetUnitName(unitTag),
						role = GetGroupMemberSelectedRole(unitTag),
						class = GetUnitClassId(unitTag),
					})
				end
			end

			table.sort(units, compare)
			return units
		else
			-- Ungrouped
			return { {
				unitTag = "player",
				account = GetDisplayName(),
				name = GetUnitName("player"),
				role = GetSelectedLFGRole(),
				class = GetUnitClassId("player"),
			} }
		end
	end
end


--------------------------------------------------------------------------------
-- Versioning
--------------------------------------------------------------------------------

function Lib.GetAddOnVersion( name )
	local am = GetAddOnManager()
	for i = 1, am:GetNumAddOns() do
		if (am:GetAddOnInfo(i) == name) then
			return am:GetAddOnVersion(i)
		end
	end
	return nil
end

do
	local fields = { }
	function Lib.FormatVersion( version )
		ZO_ClearTable(fields)
		if (type(version) == "number") then
			for i = 1, 4 do
				local base = (i > 1) and 100 or 10
				fields[5 - i] = version % base
				version = zo_floor(version / base)
			end
			if (fields[4] == 0) then
				fields[4] = nil
			end
		end
		return table.concat(fields, ".")
	end
end


--------------------------------------------------------------------------------
-- Link handling
--------------------------------------------------------------------------------

do
	local callbacks = { }
	local registered = false

	local function linkClicked( _, _, _, _, tag, ... )
		if (type(tag) == "string" and callbacks[tag]) then
			callbacks[tag](...)
			return true
		end
	end

	-- Omit the callback parameter to unregister
	function Lib.RegisterLinkHandler( tag, callback )
		callbacks[tag] = callback
		if (not registered and next(callbacks)) then
			registered = true
			LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_MOUSE_UP_EVENT, linkClicked)
			LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_CLICKED_EVENT, linkClicked)
		end
	end
end


--------------------------------------------------------------------------------
-- Deprecated
--------------------------------------------------------------------------------

Lib.Clamp = zo_clamp
Lib.CountTable = NonContiguousCount
