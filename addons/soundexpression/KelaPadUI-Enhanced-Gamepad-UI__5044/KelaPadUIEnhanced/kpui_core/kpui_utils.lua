KELA_CLOCK_FORMAT = (GetCVar("Language.2") == "en") and TIME_FORMAT_PRECISION_TWELVE_HOUR or TIME_FORMAT_PRECISION_TWENTY_FOUR_HOUR

-- Text styling helpers.  kpuiConst.TextStyles is the single source of truth for
-- how KelaPadUI text looks, so modules pick a style rather than hardcoding a
-- font or a colour.
function KelaApplyTextStyle(label, style)
	if not label or not style then
		return
	end
	if style.font then
		label:SetFont(style.font)
	end
	if style.color then
		label:SetColor(style.color:UnpackRGBA())
	end
end

-- Gamepad list rows take their label colour from the row's entry data, and the
-- core setup re-applies it on every refresh, so a colour set straight on the
-- label would be overwritten.
function KelaApplyEntryTextStyle(entryData, style)
	if not entryData or not style or not style.color then
		return
	end
	entryData:SetNameColors(style.color, style.color)
	entryData:SetSubLabelColors(style.color, style.color)
end

--local functions
function getStyleHeaderLine(styleIndex)
	local style = zo_strformat("<<1>>", GetItemStyleName(styleIndex))
	local color
		if styleIndex >= ITEMSTYLE_RACIAL_BRETON and styleIndex <= ITEMSTYLE_RACIAL_KHAJIIT then
			color = GetItemQualityColor(ITEM_QUALITY_ARCANE)
		elseif styleIndex == ITEMSTYLE_RACIAL_IMPERIAL
			or styleIndex == ITEMSTYLE_AREA_DWEMER
			or styleIndex == ITEMSTYLE_AREA_XIVKYN
			or styleIndex == ITEMSTYLE_GLASS then
			color = GetItemQualityColor(ITEM_QUALITY_LEGENDARY)
		else
			color = GetItemQualityColor(ITEM_QUALITY_ARTIFACT)
		end 

	return color, style
end
function KelaGetTableCopy(t)
	local t2 = {}
	for k,v in pairs(t) do
		if type(v) == "table" then
			t2[k] = KelaGetTableCopy(v)
		else
			t2[k] = v
		end
	end
	return t2
end
function KelaSetValueIfNil(tab, name, defaultValue)
	if tab[name] == nil then
		tab[name] = defaultValue
		return true
	end
	return false
end


function KelaRemoveValueByKey(tbl, key, byIndex)
    if tbl[key] ~= nil then 		
		if byIndex then 
			table.remove(tbl, key)			
		else
			tbl[key] = nil 
		end
	end
end
function KelaDeepCompare(t1,t2,ignore_mt)
	local ty1 = type(t1)
	local ty2 = type(t2)
	if ty1 ~= ty2 then return false end
	-- non-table types can be directly compared
	if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
	-- as well as tables which have the metamethod __eq
	local mt = getmetatable(t1)
	if not ignore_mt and mt and mt.__eq then return t1 == t2 end
	for k1,v1 in pairs(t1) do
		local v2 = t2[k1]
		if v2 == nil or not KelaDeepCompare(v1,v2) then 
			return false 
		end
	end
	for k2,v2 in pairs(t2) do
		local v1 = t1[k2]
		if v1 == nil or not KelaDeepCompare(v1,v2) then 
			return false 
		end
	end
	return true
end
-- sorting helper for pairs
function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

-- Comparison key for an item link: the link type, item id, subtype and level
-- (the full field list for master writs, whose fields name the writ). The
-- link text and style (|H0: vs |H1:) are ignored, so the same item linked in
-- chat and in a store compares equal. Keys are cached because the trading
-- code compares one link against every saved sale and listing.
local linkKeyCache = {}
local linkKeyCacheSize = 0
local LINK_KEY_CACHE_LIMIT = 4000

local function KelaGetLinkKey(link)
	local key = linkKeyCache[link]
	if key then
		return key
	end
	local maxIndex = GetItemLinkItemType(link) == ITEMTYPE_MASTER_WRIT and 24 or 6
	local params = { ZO_LinkHandler_ParseLink(link) }
	key = table.concat(params, ":", 3, math.min(maxIndex, #params))
	if linkKeyCacheSize >= LINK_KEY_CACHE_LIMIT then
		linkKeyCache = {}
		linkKeyCacheSize = 0
	end
	linkKeyCache[link] = key
	linkKeyCacheSize = linkKeyCacheSize + 1
	return key
end

function KelaCompareLink(l1, l2)
	if not l1 or not l2 then
		return false
	end
	return l1 == l2 or KelaGetLinkKey(l1) == KelaGetLinkKey(l2)
end


local function KelaGetLocalTimeShift()
  local timeShift = GetSecondsSinceMidnight() - (GetTimeStamp() % 86400)

  if (timeShift < -12 * 60 * 60) then
    timeShift = timeShift + 86400
  end

  return timeShift
end
function KelaTimeStampToDateTimeString(timeStamp)
	if timeStamp then
		local timeShift = KelaGetLocalTimeShift()
		-- It looks like GetDateStringFromTimestamp already uses local time zones, so we substract it here --
		local dateString = GetDateStringFromTimestamp(timeStamp - timeShift)
		local timeString = ZO_FormatTime(timeStamp % 86400, TIME_FORMAT_STYLE_CLOCK_TIME, KELA_CLOCK_FORMAT)
		return dateString, timeString
	else
		return "", ""
	end
end


function KelaRoundNumber(number, decimal)
	-- expects numbers and returns a number
	local mult = 10 ^ (decimal or 0)
	if mult == 1 then
	    return math.floor(number)
	end
	return math.floor(number * mult + 0.5) / mult
end

function KelaLocalizedFormatNumber(number, decimal)
	if number == math.huge then
		return "∞"
	end
	if number then 
		if type(number) ~= "number" then return number end --number = tonumber(number) end
		local mult = 10 ^ (decimal or 0)
		local sep = GetString(KELA_THOUSANDS_SEPARATOR) or ","
		local newNum = math.floor(number * mult + 0.5) / mult
		local i, j, minus, int, fraction = tostring(newNum):find('([-]?)(%d+)([.]?%d*)')
		if not decimal or decimal < 1 then
		    fraction = ""
		end
		-- Insert the separator before each group of three digits from the right,
		-- never before the first digit. "%" is escaped for the replacement string.
		local head = #int % 3
		if head == 0 then head = 3 end
		int = int:sub(1, head) .. int:sub(head + 1):gsub("(%d%d%d)", sep:gsub("%%", "%%%%") .. "%1")
		return minus .. int .. fraction
	end
	return "0"
end


-- Base-game alliance zones (zone IDs match LibSets_Data_Zones.lua).
local KELA_ZONE_ALLIANCE =
{
	[41] = ALLIANCE_EBONHEART_PACT, [57] = ALLIANCE_EBONHEART_PACT, [101] = ALLIANCE_EBONHEART_PACT, [103] = ALLIANCE_EBONHEART_PACT, [117] = ALLIANCE_EBONHEART_PACT,
	[3] = ALLIANCE_DAGGERFALL_COVENANT, [19] = ALLIANCE_DAGGERFALL_COVENANT, [20] = ALLIANCE_DAGGERFALL_COVENANT, [92] = ALLIANCE_DAGGERFALL_COVENANT, [104] = ALLIANCE_DAGGERFALL_COVENANT,
	[58] = ALLIANCE_ALDMERI_DOMINION, [108] = ALLIANCE_ALDMERI_DOMINION, [381] = ALLIANCE_ALDMERI_DOMINION, [382] = ALLIANCE_ALDMERI_DOMINION, [383] = ALLIANCE_ALDMERI_DOMINION,
}

function kelaGetAlliance(zoneId)
	return KELA_ZONE_ALLIANCE[zoneId] or ALLIANCE_NONE
end
