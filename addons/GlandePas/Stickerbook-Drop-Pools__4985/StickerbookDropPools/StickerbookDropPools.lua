--[[
StickerbookDropPools
Summarizes Set Item Collections ("stickerbook") completion per zone, decomposed by
drop pool.

Overland (https://en.uesp.net/wiki/Online:Overland_Sets):
- Delve bosses:          waist, feet, or a unique item piece
- Overland bosses:       head, chest, legs, weapon, or a unique item piece
- Public dungeon bosses: shoulders, hands, weapon, or a unique item piece
- World event chests:    jewelry (except Hew's Bane/Gold Coast, where overland bosses
                          drop jewelry, and Solstice, where public dungeon bosses do)

Instances (group dungeons, arenas, trials):
- Non-final bosses: armor pieces only (head, chest, shoulders, hand, waist, legs, feet)
- Final boss:       50% jewelry, 50% weapon/shield
- Chests:			all

Every instanced pool above is doubled into a "Perfected X" / "X" pair where prefeceted
pools exist, with those listed before their non-perfected counterparts.

Monster sets stand apart into their own "Monster Set Helms" / "Monster Set Shoulders"
pools instead of counting toward Armor/Overland/Dungeon.

Data sources (no re-scraping, no separate database):
- LibItemSets: zone <-> set mapping, set flags (monster, mythic) and zone types
  (dungeon/arena/trial), used to pick which pool split applies.
- The game's native Item Set Collections API for live per-piece completion
]]

local ADDON_NAME = "StickerbookDropPools"

local SDP = {}
StickerbookDropPools = SDP

local LIS = LibItemSets

local PREFIX = "|c70C0DE[Stickerbook]|r "

--------------------------------------------------------------------------------
-- Overland boss pools
--------------------------------------------------------------------------------

-- Zones where jewelry drops from a different pool than the World Event default.
local JEWELRY_POOL_OVERRIDE_BY_ZONE = {
	[816]  = "OVERLAND", -- Hew's Bane
	[823]  = "OVERLAND", -- Gold Coast
	[1502] = "DUNGEON",  -- Solstice
}

-- Zones with fewer overland drop pools
local CYRODIIL_ZONE_ID = 181
local IMPERIAL_CITY_ZONE_ID = 584

local OVERLAND_POOL_ORDER = {
	"DELVE", "OVERLAND", "DUNGEON", "JEWELRY", "OTHER",
	"MONSTER_HELM", "MONSTER_SHOULDER", "SOLO_MONSTER_HELM", "SOLO_MONSTER_SHOULDER",
}
local OVERLAND_POOL_LABEL = {
	DELVE            = "Waist, Feet (Delve Bosses)",
	OVERLAND         = "Head, Chest, Legs, Weapons (Overland Bosses)",
	DUNGEON          = "Shoulders, Hands, Weapons (Public Dungeon Bosses)",
	JEWELRY          = "Jewelry (World Event Chests)",
	OTHER            = "Unique/Other",
	MONSTER_HELM     = "Monster Set Helms",
	MONSTER_SHOULDER = "Monster Set Shoulders",
	SOLO_MONSTER_HELM     = "Solo Monster Set Helms",
	SOLO_MONSTER_SHOULDER = "Solo Monster Set Shoulders",
}

-- Which pool(s) an equip slot drops from
local OVERLAND_EQUIP_TYPE_POOLS = {
	[EQUIP_TYPE_WAIST]     = { "DELVE" },
	[EQUIP_TYPE_FEET]      = { "DELVE" },
	[EQUIP_TYPE_HEAD]      = { "OVERLAND" },
	[EQUIP_TYPE_CHEST]     = { "OVERLAND" },
	[EQUIP_TYPE_LEGS]      = { "OVERLAND" },
	[EQUIP_TYPE_SHOULDERS] = { "DUNGEON" },
	[EQUIP_TYPE_HAND]      = { "DUNGEON" },
	[EQUIP_TYPE_ONE_HAND]  = { "OVERLAND", "DUNGEON" },
	[EQUIP_TYPE_TWO_HAND]  = { "OVERLAND", "DUNGEON" },
	[EQUIP_TYPE_MAIN_HAND] = { "OVERLAND", "DUNGEON" },
	[EQUIP_TYPE_OFF_HAND]  = { "OVERLAND", "DUNGEON" },
	[EQUIP_TYPE_NECK]      = { "JEWELRY" },
	[EQUIP_TYPE_RING]      = { "JEWELRY" },
}

local function GetOverlandPools(equipType, zoneId)
	local pools = OVERLAND_EQUIP_TYPE_POOLS[equipType]
	if not pools then
		return { "OTHER" }
	end

	if pools[1] == "JEWELRY" then
		local override = JEWELRY_POOL_OVERRIDE_BY_ZONE[zoneId]
		if override then
			return { override }
		end
	end

	return pools
end

--------------------------------------------------------------------------------
-- Instanced boss pools (group dungeons, arenas, trials)
--------------------------------------------------------------------------------

local INSTANCED_POOL_ORDER = {
	"PERFECTED_ARMOR", "PERFECTED_JEWELRY", "PERFECTED_WEAPON", "PERFECTED_OTHER",
	"ARMOR", "JEWELRY", "WEAPON", "OTHER", "MONSTER_HELM", "MONSTER_SHOULDER",
	"SOLO_MONSTER_HELM", "SOLO_MONSTER_SHOULDER",
}

local INSTANCED_POOL_LABEL = {
	PERFECTED_ARMOR   = "Perfected Armor (Veteran Non-Final Bosses)",
	PERFECTED_JEWELRY = "Perfected Jewelry (Veteran Final Boss)",
	PERFECTED_WEAPON  = "Perfected Weapons/Shields (Final Boss)",
	PERFECTED_OTHER   = "Perfected Unique/Other",
	ARMOR             = "Armor (Non-Final Bosses)",
	JEWELRY           = "Jewelry (Final Boss)",
	WEAPON            = "Weapons/Shields (Final Boss)",
	OTHER             = "Unique/Other",
	MONSTER_HELM      = "Monster Set Helms",
	MONSTER_SHOULDER  = "Monster Set Shoulders",
	SOLO_MONSTER_HELM     = "Solo Monster Set Helms",
	SOLO_MONSTER_SHOULDER = "Solo Monster Set Shoulders",
}

-- Each final-boss pool is paired with the other half of that same 50/50 drop.
-- Once one side is exhausted, every kill is a guaranteed drop on the other
local FINAL_BOSS_PAIR = {
	JEWELRY           = "WEAPON",
	WEAPON            = "JEWELRY",
	PERFECTED_JEWELRY = "PERFECTED_WEAPON",
	PERFECTED_WEAPON  = "PERFECTED_JEWELRY",
}

-- Returns the label with the potential ", 50%" / ", 100%" suffix for a
-- final-boss pool, given its own and its paired pool's completion state
local function GetFinalBossPoolSuffixed(label, poolId, pools)
	local pairId = FINAL_BOSS_PAIR[poolId]
	local pool, pair = pools[poolId], pairId and pools[pairId]
	if not pair or pair.total == 0 then
		return label
	end

	local thisComplete = pool.unlocked >= pool.total
	local pairComplete = pair.unlocked >= pair.total

	if thisComplete == pairComplete then
		return string.format("%s, %s)", string.sub(label, 1, -2), "50%")
	elseif thisComplete then
		return label -- this side is done, the incomplete side shows the "100%" instead
	else
		-- the other side is exhausted, so every kill here is guaranteed
		return string.format("%s, %s)", string.sub(label, 1, -2), "100%")
	end
end

local INSTANCED_EQUIP_TYPE_POOLS = {
	[EQUIP_TYPE_HEAD]      = { "ARMOR" },
	[EQUIP_TYPE_CHEST]     = { "ARMOR" },
	[EQUIP_TYPE_SHOULDERS] = { "ARMOR" },
	[EQUIP_TYPE_HAND]      = { "ARMOR" },
	[EQUIP_TYPE_WAIST]     = { "ARMOR" },
	[EQUIP_TYPE_LEGS]      = { "ARMOR" },
	[EQUIP_TYPE_FEET]      = { "ARMOR" },
	[EQUIP_TYPE_NECK]      = { "JEWELRY" },
	[EQUIP_TYPE_RING]      = { "JEWELRY" },
	[EQUIP_TYPE_ONE_HAND]  = { "WEAPON" },
	[EQUIP_TYPE_TWO_HAND]  = { "WEAPON" },
	[EQUIP_TYPE_MAIN_HAND] = { "WEAPON" },
	[EQUIP_TYPE_OFF_HAND]  = { "WEAPON" },
}

local function GetInstancedPools(equipType, isPerfected)
	local basePools = INSTANCED_EQUIP_TYPE_POOLS[equipType] or { "OTHER" }
	if not isPerfected then
		return basePools
	end

	local perfectedPools = {}
	for _, poolId in ipairs(basePools) do
		table.insert(perfectedPools, "PERFECTED_" .. poolId)
	end
	return perfectedPools
end

--------------------------------------------------------------------------------
-- Infinite Archive pools (class sets)
--------------------------------------------------------------------------------

local INFINITE_ARCHIVE_ZONE_ID = 1436

-- LibItemSets has no class data, and the game API doesn't expose which class a class
-- set belongs to, so map each class set to its classId by hand (from LibSets' data).
local CLASS_SET_CLASS_ID = {
	[723] = 1,   [776] = 1,   -- Dragonknight: Basalt-Blooded Warrior, Pyrebrand
	[727] = 2,   [779] = 2,   -- Sorcerer: Monolith of Storms, Beacon of Oblivion
	[726] = 3,   [778] = 3,   -- Nightblade: Soulcleaver, Umbral Edge
	[729] = 4,   [781] = 4,   -- Warden: Gardener of Seasons, Aerie's Cry
	[724] = 5,   [777] = 5,   -- Necromancer: Nobility in Decay, Corpseburster
	[728] = 6,   [780] = 6,   -- Templar: Wrathsun, Aetheric Lancer
	[722] = 117, [775] = 117, -- Arcanist: Reawakened Hierophant, Spattering Disjunction
}

-- Tho'at Replicanum and Marauders drop armor on odd-numbered arcs, and a weapon or
-- jewelry piece on even-numbered arcs. Curation hands out the current character's
-- class sets first, so those get their own pools on top of the all-classes ones.
local INFINITE_ARCHIVE_POOL_ORDER = {
	"IA_CLASS_ARMOR", "IA_CLASS_WEAPON_JEWELRY",
	"IA_ALL_ARMOR", "IA_ALL_WEAPON_JEWELRY",
	"OTHER",
}

-- Built at print time, since the class pools are named after the current character's class.
local function GetInfiniteArchivePoolLabels()
	local className = zo_strformat("<<1>>", GetUnitClass("player"))
	return {
		IA_CLASS_ARMOR          = className .. " Armor (Odd Arcs Tho'at and Marauders)",
		IA_CLASS_WEAPON_JEWELRY = className .. " Weapons, Jewelry (Even Arcs Tho'at and Marauders)",
		IA_ALL_ARMOR            = "All Classes Armor (Odd Arcs Tho'at and Marauders)",
		IA_ALL_WEAPON_JEWELRY   = "All Classes Weapons, Jewelry (Even Arcs Tho'at and Marauders)",
		OTHER                   = "Unique/Other",
	}
end

local INFINITE_ARCHIVE_EQUIP_TYPE_POOLS = {
	[EQUIP_TYPE_HEAD]      = "ARMOR",
	[EQUIP_TYPE_CHEST]     = "ARMOR",
	[EQUIP_TYPE_SHOULDERS] = "ARMOR",
	[EQUIP_TYPE_HAND]      = "ARMOR",
	[EQUIP_TYPE_WAIST]     = "ARMOR",
	[EQUIP_TYPE_LEGS]      = "ARMOR",
	[EQUIP_TYPE_FEET]      = "ARMOR",
	[EQUIP_TYPE_NECK]      = "WEAPON_JEWELRY",
	[EQUIP_TYPE_RING]      = "WEAPON_JEWELRY",
	[EQUIP_TYPE_ONE_HAND]  = "WEAPON_JEWELRY",
	[EQUIP_TYPE_TWO_HAND]  = "WEAPON_JEWELRY",
	[EQUIP_TYPE_MAIN_HAND] = "WEAPON_JEWELRY",
	[EQUIP_TYPE_OFF_HAND]  = "WEAPON_JEWELRY",
}

-- Every class set piece counts toward the all-classes pool; the current character's
-- class set pieces also count toward the class pool.
local function GetInfiniteArchivePools(equipType, isOwnClassSet)
	local base = INFINITE_ARCHIVE_EQUIP_TYPE_POOLS[equipType]
	if not base then
		return { "OTHER" }
	end
	if isOwnClassSet then
		return { "IA_CLASS_" .. base, "IA_ALL_" .. base }
	end
	return { "IA_ALL_" .. base }
end

--------------------------------------------------------------------------------
-- "Monster set" pools (2-piece sets: helm + shoulders)
--------------------------------------------------------------------------------

local MONSTER_EQUIP_TYPE_POOLS = {
	[EQUIP_TYPE_HEAD]      = "MONSTER_HELM",
	[EQUIP_TYPE_SHOULDERS] = "MONSTER_SHOULDER",
}

-- Solo dungeons are single-player copies of group dungeons that share the dungeon's sets
-- but have their own monster set (e.g. Tarcyr in March of Sacrifices). Kept apart from
-- the group dungeon's monster set, since it drops from a different instance.
local SOLO_MONSTER_EQUIP_TYPE_POOLS = {
	[EQUIP_TYPE_HEAD]      = "SOLO_MONSTER_HELM",
	[EQUIP_TYPE_SHOULDERS] = "SOLO_MONSTER_SHOULDER",
}

--------------------------------------------------------------------------------
-- Zones
--------------------------------------------------------------------------------

-- LibItemSets keeps some places LibSets treats as one zone as separate sources: solo
-- dungeons have their own zoneId (with the same name as the group dungeon), and Imperial
-- City's Tel Var sets are under Imperial Sewers. Summarize them with the zone they belong
-- to, and keep them out of the search list.
local MERGED_INTO_ZONE = {
	[643]  = IMPERIAL_CITY_ZONE_ID, -- Imperial Sewers
	[1592] = 1055,                  -- March of Sacrifices (solo)
	[1593] = 1052,                  -- Moon Hunter Keep (solo)
}
local SOLO_DUNGEON_ZONE = {
	[1592] = true,
	[1593] = true,
}

-- zoneId -> list of the zoneIds whose sets are summarized under it
local zoneSources = nil
local function GetZoneSources(zoneId)
	if not zoneSources then
		zoneSources = {}
		for mergedZoneId, intoZoneId in pairs(MERGED_INTO_ZONE) do
			zoneSources[intoZoneId] = zoneSources[intoZoneId] or { intoZoneId }
			table.insert(zoneSources[intoZoneId], mergedZoneId)
		end
	end
	return zoneSources[zoneId] or { zoneId }
end

-- Collectible setIds dropping in a zone (including the zones merged into it)
local function GetZoneSetIds(zoneId)
	local setIds, seen = {}, {}
	for _, sourceId in ipairs(GetZoneSources(zoneId)) do
		for _, setId in ipairs(LIS.GetCollectibleItemSetIdsForSource(sourceId)) do
			if not seen[setId] then
				seen[setId] = true
				table.insert(setIds, setId)
			end
		end
	end
	return setIds
end

-- Every zone that has sets, by name, for the zone search
local function GetAllZones()
	local zones, seen = {}, {}
	for _, setId in ipairs(LIS.GetCollectibleItemSetIds()) do
		local info = LIS.GetItemSetInfo(setId)
		for _, sourceId in ipairs(info and info.sourceIds or {}) do
			if sourceId > 0 and not seen[sourceId] and not MERGED_INTO_ZONE[sourceId] then
				seen[sourceId] = true
				table.insert(zones, { id = sourceId, name = LIS.GetSourceName(sourceId) })
			end
		end
	end
	return zones
end

-- LibItemSets doesn't expose zone types directly, but each set's flags carry the
-- types of all the zones it drops in. Some sets drop both in an instance and in the
-- overland zone around it (e.g. Asylum Sanctorium's armor also drops in Clockwork City),
-- so let the sets that drop only in instances, or only in the open world, vote.
local SOURCE_TYPE_INSTANCED = BitOr(BitOr(LIS.SOURCE_TYPE_DUNGEON, LIS.SOURCE_TYPE_TRIAL), LIS.SOURCE_TYPE_ARENA)
local SOURCE_TYPE_OPEN_WORLD = BitOr(LIS.SOURCE_TYPE_OVERLAND, LIS.SOURCE_TYPE_PVP)
local function IsInstancedZone(setIds)
	local instancedVotes, openWorldVotes = 0, 0
	for _, setId in ipairs(setIds) do
		local info = LIS.GetItemSetInfo(setId)
		local flags = info and info.flags or 0
		local isInstanced = BitAnd(flags, SOURCE_TYPE_INSTANCED) ~= 0
		local isOpenWorld = BitAnd(flags, SOURCE_TYPE_OPEN_WORLD) ~= 0
		if isInstanced and not isOpenWorld then
			instancedVotes = instancedVotes + 1
		elseif isOpenWorld and not isInstanced then
			openWorldVotes = openWorldVotes + 1
		end
	end
	return instancedVotes > openWorldVotes
end

local function IsSoloDungeonOnlySet(info, zoneId)
	local inSoloDungeon = false
	for _, sourceId in ipairs(info.sourceIds) do
		if sourceId == zoneId then
			return false
		end
		if SOLO_DUNGEON_ZONE[sourceId] then
			inSoloDungeon = true
		end
	end
	return inSoloDungeon
end

--------------------------------------------------------------------------------
-- Shared logic
--------------------------------------------------------------------------------

local function chatPrint(text)
	CHAT_ROUTER:AddSystemMessage(text)
end

local function ResolveZoneId(searchText)
	if not searchText or searchText == "" then
		local zoneId = GetZoneId(GetUnitZoneIndex("player"))
		zoneId = MERGED_INTO_ZONE[zoneId] or zoneId
		if #GetZoneSetIds(zoneId) == 0 then
			local parentZoneId = GetParentZoneId(zoneId)
			if parentZoneId and parentZoneId ~= 0 and parentZoneId ~= zoneId then
				zoneId = MERGED_INTO_ZONE[parentZoneId] or parentZoneId
			end
		end
		return zoneId
	end

	searchText = zo_strlower(searchText)

	local matches = {}
	for _, zone in ipairs(GetAllZones()) do
		if zo_strlower(zone.name):find(searchText, 1, true) then
			table.insert(matches, zone)
		end
	end

	if #matches == 0 then
		chatPrint(PREFIX .. string.format("No zone matching \"%s\" has any tracked set drops.", searchText))
		return nil
	elseif #matches > 1 then
		-- Prefer the shortest matching name (e.g. "Imperial City" over "Imperial City
		-- Prison") so a name that's a strict substring of another match still resolves
		-- instead of being reported as ambiguous. Only a genuine tie is ambiguous.
		table.sort(matches, function(a, b)
			if #a.name ~= #b.name then
				return #a.name < #b.name
			end
			return a.name < b.name
		end)
		if #matches[1].name < #matches[2].name then
			local otherNames = {}
			for i = 2, #matches do
				table.insert(otherNames, matches[i].name)
			end
			chatPrint(PREFIX .. string.format("\"%s\" also matches %s - using %s.", searchText, table.concat(otherNames, ", "), matches[1].name))
			return matches[1].id
		end

		local names = {}
		for _, match in ipairs(matches) do
			table.insert(names, match.name)
		end
		chatPrint(PREFIX .. string.format("\"%s\" matches multiple zones: %s. Be more specific.", searchText, table.concat(names, ", ")))
		return nil
	end

	return matches[1].id
end

function SDP.PrintSummary(searchText, verbose)
	local zoneId = ResolveZoneId(searchText)
	if not zoneId then
		if searchText and searchText ~= "" then
			return -- ResolveZoneId already reported the problem
		end
		chatPrint(PREFIX .. "This zone has no sets with known drop locations.")
		return
	end

	local zoneName = LIS.GetSourceName(zoneId)
	local setIds = GetZoneSetIds(zoneId)
	if #setIds == 0 then
		chatPrint(PREFIX .. string.format("%s has no sets with known drop locations.", zoneName ~= "" and zoneName or "This zone"))
		return
	end

	local isInfiniteArchive = zoneId == INFINITE_ARCHIVE_ZONE_ID
	local isInstanced = not isInfiniteArchive and IsInstancedZone(setIds)
	local poolOrder, poolLabel
	if isInfiniteArchive then
		poolOrder, poolLabel = INFINITE_ARCHIVE_POOL_ORDER, GetInfiniteArchivePoolLabels()
	elseif isInstanced then
		poolOrder, poolLabel = INSTANCED_POOL_ORDER, INSTANCED_POOL_LABEL
	else
		poolOrder, poolLabel = OVERLAND_POOL_ORDER, OVERLAND_POOL_LABEL
	end

	local pools = {}
	for _, poolId in ipairs(poolOrder) do
		pools[poolId] = { unlocked = 0, total = 0 }
	end

	local includedSetNames = {}
	-- Tallied once per physical piece to avoid double-counting, as a piece can
	-- counts toward several pools
	local zoneUnlocked, zoneTotal = 0, 0
	local playerClassId = isInfiniteArchive and GetUnitClassId("player")

	for _, setId in ipairs(setIds) do
		local info = LIS.GetItemSetInfo(setId)
		if info and not LIS.CheckFlag(info.flags, LIS.SPECIAL_MYTHIC) then
			local numPieces = GetNumItemSetCollectionPieces(setId)
			local isPerfected = isInstanced and GetItemSetUnperfectedSetId(setId) > 0
			local isMonsterSet = LIS.CheckFlag(info.flags, LIS.SPECIAL_MONSTER_SET)
			local isSoloMonsterSet = isMonsterSet and IsSoloDungeonOnlySet(info, zoneId)
			local isOwnClassSet = isInfiniteArchive and CLASS_SET_CLASS_ID[setId] == playerClassId

			if numPieces and numPieces > 0 then
				if verbose then
					table.insert(includedSetNames, info.setName)
				end
				for index = 1, numPieces do
					local pieceId = GetItemSetCollectionPieceInfo(setId, index)
					if pieceId then
						local itemLink = GetItemSetCollectionPieceItemLink(pieceId, LINK_STYLE_DEFAULT, ITEM_TRAIT_TYPE_NONE)
						local equipType = itemLink and GetItemLinkEquipType(itemLink)
						local isUnlocked = IsItemSetCollectionPieceUnlocked(pieceId)

						local monsterPool = (isSoloMonsterSet and SOLO_MONSTER_EQUIP_TYPE_POOLS[equipType])
							or (isMonsterSet and MONSTER_EQUIP_TYPE_POOLS[equipType])
						local piecePools
						if monsterPool then
							piecePools = { monsterPool }
						elseif isInfiniteArchive then
							piecePools = GetInfiniteArchivePools(equipType, isOwnClassSet)
						else
							piecePools = isInstanced and GetInstancedPools(equipType, isPerfected) or GetOverlandPools(equipType, zoneId)
						end

						zoneTotal = zoneTotal + 1
						if isUnlocked then
							zoneUnlocked = zoneUnlocked + 1
						end

						for _, poolId in ipairs(piecePools) do
							local pool = pools[poolId]
							pool.total = pool.total + 1
							if isUnlocked then
								pool.unlocked = pool.unlocked + 1
							end
						end
					end
				end
			end
		end
	end

	local overallPct = (zoneTotal > 0) and math.floor((zoneUnlocked / zoneTotal) * 100) or 0
	chatPrint(PREFIX .. string.format("|cFFFFFF%s|r — %d/%d pieces (%d%%)", zoneName, zoneUnlocked, zoneTotal, overallPct))

	-- Verbose mode: list every set that contributed to the totals above.
	if verbose then
		table.sort(includedSetNames)
		chatPrint(string.format("    |cFF8C00Sets|r: %s", table.concat(includedSetNames, ", ")))
	end

	for _, poolId in ipairs(poolOrder) do
		local pool = pools[poolId]
		local isHidden = false
		if zoneId == CYRODIIL_ZONE_ID then
			isHidden = poolId == "OVERLAND" or poolId == "DUNGEON"
		elseif zoneId == IMPERIAL_CITY_ZONE_ID then
			isHidden = poolId ~= "MONSTER_HELM" and poolId ~= "MONSTER_SHOULDER"
		end
		if pool.total > 0 and not isHidden then
			local pct = math.floor((pool.unlocked / pool.total) * 100)
			local color = (pool.unlocked >= pool.total) and "73C23A" or "C0C0C0"
			local label = GetFinalBossPoolSuffixed(poolLabel[poolId], poolId, pools)
			chatPrint(string.format("  * |c%s%s|r %d / %d (%d%%)", color, label, pool.unlocked, pool.total, pct))
		end
	end
end

local function OnAddOnLoaded(_, addonName)
	if addonName ~= ADDON_NAME then
		return
	end
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

	local function IsVerboseFlag(token)
		local lower = token and zo_strlower(token)
		return lower == "verbose"
	end

	-- A trailing "verbose" argument (e.g. "/setdroppools imperial city
	-- verbose", or just "/setdroppools verbose" for the current zone) switches
	-- on the per-set listing; everything before it is the zone search text.
	SLASH_COMMANDS["/setdroppools"] = function(args)
		args = args or ""
		if IsVerboseFlag(args) then
			SDP.PrintSummary("", true)
			return
		end

		local searchText, verboseFlag = zo_strmatch(args, "^(.-)%s+(%S+)$")
		if verboseFlag and IsVerboseFlag(verboseFlag) then
			SDP.PrintSummary(searchText, true)
		else
			SDP.PrintSummary(args)
		end
	end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
