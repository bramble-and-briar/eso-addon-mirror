local LCCC = LibCodesCommonCode
local LootLog = LootLog

local MAP_IDS = { }
local ZONE_LEADS = { }
local Initialized = false

local function InitializeData( )
	Initialized = true

	local LEADS = {
		18, -59,
		316, -329,
		360, -373,
		416, -429,
		485, -498,
		539, 541,
		602, -607, 609, -611,
		688, -694, 696, -698,
		740, -746,
	}

	local MAPS = {
		-- Daggerfall Covenant -------------------------------------------------
		[   3] = { 43507, 43509, 43525, -43527, 43600 }, -- Glenumbra
		[  19] = { 43601, -43606 }, -- Stormhaven
		[  20] = { 43607, -43612 }, -- Rivenspire
		[ 104] = { 43613, -43618 }, -- Alik'r Desert
		[  92] = { 43619, -43624 }, -- Bangkorai
		[ 534] = { 43691, 43692 }, -- Stros M'Kai
		[ 535] = { 43693, 43694 }, -- Betnikh

		-- Aldmeri Dominion ----------------------------------------------------
		[ 381] = { 43625, -43630 }, -- Auridon
		[ 383] = { 43631, -43636 }, -- Grahtwood
		[ 108] = { 43637, -43642 }, -- Greenshade
		[  58] = { 43643, -43648 }, -- Malabal Tor
		[ 382] = { 43649, -43654 }, -- Reaper's March
		[ 537] = { 43695, -43698 }, -- Khenarthi's Roost

		-- Ebonheart Pact ------------------------------------------------------
		[  41] = { 43655, -43660 }, -- Stonefalls
		[  57] = { 43661, -43666 }, -- Deshaan
		[ 117] = { 43667, -43672 }, -- Shadowfen
		[ 101] = { 43673, -43678 }, -- Eastmarch
		[ 103] = { 43679, -43684 }, -- The Rift
		[ 280] = { 43699, 43700 }, -- Bleakrock Isle
		[ 281] = { 43701, 43702 }, -- Bal Foyen

		-- Neutral -------------------------------------------------------------
		[ 347] = { 43685, -43690 }, -- Coldharbour
		[ 181] = { 43703, -43720 }, -- Cyrodiil
		[ 888] = { 43721, -43726 }, -- Craglorn
		[ 684] = { 43727, -43732 }, -- Wrothgar
		[ 816] = { 43733, 43734 }, -- Hew's Bane
		[ 823] = { 43735, 43736 }, -- The Gold Coast
		[ 849] = { 43737, -43742 }, -- Vvardenfell
		[ 980] = { 43746 ,43747 }, -- The Clockwork City
		[1011] = { 43748, -43753 }, -- Summerset
		[ 726] = { 145510, 145512 }, -- Murkmire
		[1086] = { 151613, -151618 }, -- Northern Elsweyr
		[1133] = { 156715, 156716 }, -- Southern Elsweyr
		[1160] = { 166040, -166043 }, -- Western Skyrim
		[1161] = { 166038, 166039 }, -- Blackreach: Greymoor Caverns
		[1207] = { 171474 }, -- The Reach
		[1208] = { 171475 }, -- Blackreach: Arkthzand Cavern
		[1261] = { 175547, -175552 }, -- Blackwood
		[1286] = { 183005, 183006 }, -- The Deadlands
		[1318] = { 187671, -187676 }, -- High Isle
		[1383] = { 192370, 192371 }, -- Galen
		[1413] = { 198101, 198102 }, -- Apocrypha
		[1414] = { 198097, -198100 }, -- Telvanni Peninsula
		[1443] = { 207964, -207969 }, -- West Weald
		[1502] = { 217926, -217928, 223772, -223774 }, -- Solstice
	}

	local REZONES = {
		[1160] = 1207, -- Western Skyrim -> The Reach
		[1161] = 1207, -- Blackreach: Greymoor Caverns -> The Reach
		[1208] = 1207, -- Blackreach: Arkthzand Cavern -> The Reach
		[1413] = 1414, -- Apocrypha -> Telvanni Peninsula
	}

	LCCC.ProcessNumericTable(LEADS, function( antiquityId )
		local zoneId = GetAntiquityZoneId(antiquityId)
		if (not ZONE_LEADS[zoneId]) then
			ZONE_LEADS[zoneId] = { }
		end
		table.insert(ZONE_LEADS[zoneId], antiquityId)
	end)

	for zoneId, itemIds in pairs(MAPS) do
		zoneId = REZONES[zoneId] or zoneId
		if (not ZONE_LEADS[zoneId]) then
			ZONE_LEADS[zoneId] = { }
		end
		LCCC.ProcessNumericTable(itemIds, function( itemId )
			MAP_IDS[itemId] = zoneId
		end)
	end
end

function LootLog.GetAntiquityIdsForTreasureMap( item )
	if (type(item) == "string") then
		item = GetItemLinkItemId(item)
	end

	local results

	if (type(item) == "number") then
		if (not Initialized) then
			InitializeData()
		end

		local zoneId = MAP_IDS[item]
		if (zoneId) then
			results = ZONE_LEADS[zoneId]
		end
	end

	return results or { }
end
