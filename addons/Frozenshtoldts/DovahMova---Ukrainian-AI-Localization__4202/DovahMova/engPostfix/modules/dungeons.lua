-- =================================================================================================
-- Назви підземель у пошуку групи (Activity Finder): "Грибний грот I (Fungal Grotto I)".
-- Назви обчислюються один раз; зміна налаштування застосовується після /reloadui.
-- =================================================================================================

local DovahMova = DovahMova
local Util = DovahMova.Util

local Dungeons = {}
DovahMova.Dungeons = Dungeons

local VETERAN_ICON = "|t100%:100%:EsoUI/Art/UnitFrames/target_veteranRank_icon.dds|t "
local VETERAN_GAMEPAD_PREFIX = "Ветеранське підземелля "

local function GetBilingualName(rawName, mode)
	local englishName = DovahMova.StaticData.DungeonNames[Util.ToKey(rawName)]
	if not englishName then
		return nil
	end
	return Util.FormatBilingual(rawName, englishName, mode)
end

local function RenameNormalDungeons(locations, mode)
	for _, location in ipairs(locations) do
		local name = GetBilingualName(location.rawName, mode)
		if name then
			location.nameKeyboard = ZO_CachedStrFormat(SI_ZONE_NAME, name)
			location.nameGamepad = ZO_CachedStrFormat(SI_ZONE_NAME, name)
		end
	end
end

local function RenameVeteranDungeons(locations, mode)
	for _, location in ipairs(locations) do
		local name = GetBilingualName(location.rawName, mode)
		if name then
			if zo_plainstrfind(location.nameKeyboard, "target_veteranRank_icon") then
				location.nameKeyboard = VETERAN_ICON .. ZO_CachedStrFormat(SI_ZONE_NAME, name)
			end
			if string.sub(location.nameGamepad, 1, #VETERAN_GAMEPAD_PREFIX) == VETERAN_GAMEPAD_PREFIX then
				location.nameGamepad = VETERAN_GAMEPAD_PREFIX .. name
			end
		end
	end
end

local installed = false

function Dungeons.Install()
	local mode = DovahMova.settings.ShowLocations
	if installed or mode == DovahMova.MODE_UA then
		return
	end
	installed = true

	local sortedLocations = ZO_ACTIVITY_FINDER_ROOT_MANAGER.sortedLocationsData
	RenameNormalDungeons(sortedLocations[LFG_ACTIVITY_DUNGEON] or {}, mode)
	RenameVeteranDungeons(sortedLocations[LFG_ACTIVITY_MASTER_DUNGEON] or {}, mode)
end
