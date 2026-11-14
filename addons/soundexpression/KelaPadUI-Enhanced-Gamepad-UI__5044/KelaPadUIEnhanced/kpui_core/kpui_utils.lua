KELA_CLOCK_FORMAT = (GetCVar("Language.2") == "en") and TIME_FORMAT_PRECISION_TWELVE_HOUR or TIME_FORMAT_PRECISION_TWENTY_FOUR_HOUR

local WEAPON_TYPE_TO_CATEGORY_MAP = {
    [WEAPONTYPE_AXE] = GAMEPAD_ITEM_CATEGORY_AXE,
    [WEAPONTYPE_TWO_HANDED_AXE] = GAMEPAD_ITEM_CATEGORY_AXE,
    [WEAPONTYPE_BOW] = GAMEPAD_ITEM_CATEGORY_BOW,
    [WEAPONTYPE_DAGGER] = GAMEPAD_ITEM_CATEGORY_DAGGER,
    [WEAPONTYPE_HAMMER] = GAMEPAD_ITEM_CATEGORY_HAMMER,
    [WEAPONTYPE_TWO_HANDED_HAMMER] = GAMEPAD_ITEM_CATEGORY_HAMMER,
    [WEAPONTYPE_SHIELD] = GAMEPAD_ITEM_CATEGORY_SHIELD,
    [WEAPONTYPE_HEALING_STAFF] = GAMEPAD_ITEM_CATEGORY_STAFF,
    [WEAPONTYPE_FIRE_STAFF] = GAMEPAD_ITEM_CATEGORY_STAFF,
    [WEAPONTYPE_FROST_STAFF] = GAMEPAD_ITEM_CATEGORY_STAFF,
    [WEAPONTYPE_LIGHTNING_STAFF] = GAMEPAD_ITEM_CATEGORY_STAFF,
    [WEAPONTYPE_SWORD] = GAMEPAD_ITEM_CATEGORY_SWORD,
    [WEAPONTYPE_TWO_HANDED_SWORD] = GAMEPAD_ITEM_CATEGORY_SWORD,
}
local ARMOR_EQUIP_TYPE_TO_CATEGORY_MAP = {
    [EQUIP_TYPE_CHEST] = GAMEPAD_ITEM_CATEGORY_CHEST,
    [EQUIP_TYPE_FEET] = GAMEPAD_ITEM_CATEGORY_FEET,
    [EQUIP_TYPE_HAND] = GAMEPAD_ITEM_CATEGORY_HANDS,
    [EQUIP_TYPE_HEAD] = GAMEPAD_ITEM_CATEGORY_HEAD,
    [EQUIP_TYPE_LEGS] = GAMEPAD_ITEM_CATEGORY_LEGS,
    [EQUIP_TYPE_NECK] = GAMEPAD_ITEM_CATEGORY_AMULET,
    [EQUIP_TYPE_RING] = GAMEPAD_ITEM_CATEGORY_RING,
    [EQUIP_TYPE_SHOULDERS] = GAMEPAD_ITEM_CATEGORY_SHOULDERS,
    [EQUIP_TYPE_WAIST] = GAMEPAD_ITEM_CATEGORY_WAIST,
}

local colors = kpuiConst.Colors	

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
	local color = ZO_TOOLTIP_DEFAULT_COLOR
	
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

function KelaCompareLink(l1,l2)
	if not l1 or not l2 then
		return false
	end

	local isSimilar = true

	local isWrit = GetItemLinkItemType(l1) == ITEMTYPE_MASTER_WRIT or GetItemLinkItemType(l2) == ITEMTYPE_MASTER_WRIT


	local maxIndex = isWrit and 24 or 6


	local itemLinkParams1 = {ZO_LinkHandler_ParseLink(l1)}	
	local itemLinkParams2 = {ZO_LinkHandler_ParseLink(l2)}
	
	for i = 1, maxIndex do
		if itemLinkParams1[i] ~= itemLinkParams2[i] then
			isSimilar = false
			break
		end
	end
	
	return isSimilar
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
		-- add separator
		int = int:reverse():gsub("(%d%d%d)", "%1"..sep)
		return minus .. int:reverse():gsub("^,", "") .. fraction
	end
	return "0"
end


function kelaGetAlliance(zoneId)
	if zoneId==ID_STONEFALLS or zoneId==ID_DESHAAN or zoneId==ID_EASTMARCH or zoneId==ID_THERIFT or zoneId==ID_SHADOWFEN then
		return ALLIANCE_EBONHEART_PACT
	elseif zoneId==ID_GLENUMBRA or zoneId==ID_STORMHAVEN or zoneId==ID_RIVENSPIRE or zoneId==ID_BANGKORAI or zoneId==ID_ALIKRDESERT then
		return ALLIANCE_DAGGERFALL_COVENANT
	elseif zoneId==ID_MALABALTOR or zoneId==ID_GREENSHADE or zoneId==ID_AURIDON or zoneId==ID_REAPERSMARCH or zoneId==ID_GRAHTWOOD then
		return ALLIANCE_ALDMERI_DOMINION
	else
		return ALLIANCE_NONE
	end
end
