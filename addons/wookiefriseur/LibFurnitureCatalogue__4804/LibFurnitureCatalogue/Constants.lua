-- DB constants: item-source/version enums + source ranking, NPC/location/event name tables

FurC = FurC or {}

local LFC = LibFurnitureCatalogue

--- Collection of some variables for easier access. Not intended as an API. Some values are constants, while others are generated from string localisation and may change between play sessions or game patches.
local this = {}
LFC.Internal.Constants = this
FurC.Constants = this -- TODO: move alias to LFC.Internal

local getZoneStr = GetZoneNameById
local getCrateStr = GetCrownCrateName
local getSkillLineStr = GetSkillLineNameById
local sFormat = zo_strformat

local function getStr(id)
  return GetString(id)
end

--- Monster Social Classes are the game's strings, not ours (missing one renders empty)
local function getNpcClassStr(id)
  return (id and sFormat("<<1>>", GetString(id))) or ""
end

--- Groups of enemies are rendered plural
local function getNpcGroupStr(id)
  return sFormat("<<m:1>>", GetString(id))
end

--- One resolver per type: stable id -> localised text
this.Resolvers = {
  Zone = getZoneStr,
  Place = getStr,
  Npc = getStr,
  NpcClass = getNpcClassStr,
  NpcGroup = getNpcGroupStr,
  Event = getStr,
  Crate = getCrateStr,
  SkillLine = getSkillLineStr,
}

local idCounter = {}

---Generate consecutive ids for constants
---@param id_type string Type for which to generate an ID
---@return integer nextId Next ID for given type
local function getNextIdFor(id_type)
  idCounter[id_type] = (idCounter[id_type] or 0) + 1
  return idCounter[id_type]
end

---Fill "names" table and its reverse "byName" map from a table of stable ids
--- Resolves them with passed table specific callback function
---@param ids table<string, integer> key -> stable game or string id
---@param resolve fun(id: integer): string Resolver callback, use 1 resolver per table
---@param names table<string, string> key -> localised name, filled in place (mutating)
---@param byName table<string, integer> localised name -> id, filled in place (mutating)
local function deriveNames(ids, resolve, names, byName)
  for key, id in pairs(ids) do
    local name = resolve(id)
    names[key] = name
    if name and name ~= "" then
      byName[name] = id
    end
  end
end

-- Public event names, used in Api.lua as LFC.API.Events
-- here, because DB build fires them and loads before Api.lua
this.ApiEvents = {
  SCAN_STARTED = "LFC_SCAN_STARTED",
  SCAN_COMPLETE = "LFC_SCAN_COMPLETE",
  SCAN_FAILED = "LFC_SCAN_FAILED",
}

-- constants for filtering

-- item sources
this.ItemSources = {
  NONE = getNextIdFor("ITEM_SOURCES"), -- 1
  FAVE = getNextIdFor("ITEM_SOURCES"), -- 2
  CRAFTING = getNextIdFor("ITEM_SOURCES"), -- 3
  CRAFTING_KNOWN = getNextIdFor("ITEM_SOURCES"), -- 4
  CRAFTING_UNKNOWN = getNextIdFor("ITEM_SOURCES"), -- 5
  VENDOR = getNextIdFor("ITEM_SOURCES"), -- 6
  PVP = getNextIdFor("ITEM_SOURCES"), -- 7
  WRIT_VENDOR = getNextIdFor("ITEM_SOURCES"), -- 8
  CROWN = getNextIdFor("ITEM_SOURCES"), -- 9
  RUMOUR = getNextIdFor("ITEM_SOURCES"), -- 10
  LUXURY = getNextIdFor("ITEM_SOURCES"), -- 11
  OTHER = getNextIdFor("ITEM_SOURCES"), -- 12
  ROLIS = getNextIdFor("ITEM_SOURCES"), -- 13
  DROP = getNextIdFor("ITEM_SOURCES"), -- 14
  JUSTICE = getNextIdFor("ITEM_SOURCES"), -- 15
  FISHING = getNextIdFor("ITEM_SOURCES"), -- 16
  GUILDSTORE = getNextIdFor("ITEM_SOURCES"), -- 17
  FESTIVAL_DROP = getNextIdFor("ITEM_SOURCES"), -- 18
  BAZAAR = getNextIdFor("ITEM_SOURCES"), -- 19
  TOMES = getNextIdFor("ITEM_SOURCES"), -- 20
  TELVAR = getNextIdFor("ITEM_SOURCES"), -- 21
  COLL_MERCH = getNextIdFor("ITEM_SOURCES"), -- 22
  EDITOR = getNextIdFor("ITEM_SOURCES"), -- 23
  ANTIQUITY = getNextIdFor("ITEM_SOURCES"), -- 24
  DUNGEON = getNextIdFor("ITEM_SOURCES"), -- 25
  HARVEST = getNextIdFor("ITEM_SOURCES"), -- 26
  CHEST = getNextIdFor("ITEM_SOURCES"), -- 27
  QUEST = getNextIdFor("ITEM_SOURCES"), -- 28
  PICKPOCKET = getNextIdFor("ITEM_SOURCES"), -- 29
  STEAL_CONTAINER = getNextIdFor("ITEM_SOURCES"), -- 30
  IGNORED = getNextIdFor("ITEM_SOURCES"), -- 31
  HOME_GOODS = getNextIdFor("ITEM_SOURCES"), -- 32
  ACHIEVEMENT = getNextIdFor("ITEM_SOURCES"), -- 33
}

-- value -> name
this.SourceNames = {}
for name, value in pairs(this.ItemSources) do
  this.SourceNames[value] = name
end

---@alias FurCItemSource integer # FurC.Constants.ItemSources values

-- Ranking for multi-source
do
  local src = this.ItemSources
  this.SOURCE_PRIORITY = {
    [src.IGNORED] = 0, -- deliberate exclusion overrides acquisition sources
    [src.CRAFTING] = 10,
    -- purchased (in-game currencies)
    [src.HOME_GOODS] = 18, -- gold, no achievements
    [src.VENDOR] = 19,
    [src.ACHIEVEMENT] = 20,
    [src.WRIT_VENDOR] = 21,
    [src.ROLIS] = 22,
    [src.TOMES] = 23,
    [src.PVP] = 30,
    [src.TELVAR] = 31,
    [src.COLL_MERCH] = 32,
    [src.BAZAAR] = 61,
    -- drop / harvest / steal
    -- fine-grained sources rank higher than their parent
    [src.DUNGEON] = 33,
    [src.HARVEST] = 34,
    [src.CHEST] = 35,
    [src.QUEST] = 36,
    [src.PICKPOCKET] = 37,
    [src.STEAL_CONTAINER] = 38,
    [src.DROP] = 40,
    [src.JUSTICE] = 41,
    [src.FISHING] = 42,
    -- excavation / scrying
    [src.ANTIQUITY] = 45,
    -- time-limited / rotating stock
    [src.LUXURY] = 50,
    [src.FESTIVAL_DROP] = 51,
    -- real money
    [src.EDITOR] = 60,
    [src.CROWN] = 62,
    -- other
    [src.OTHER] = 70,
    [src.GUILDSTORE] = 98, -- do we even use this?
    [src.RUMOUR] = 99,
  }
end

-- Stable English names for the source types (because the enum meaning might not be obvious)
-- Those are not and will not be locale strings
do
  local src = this.ItemSources
  this.SourceLabels = {
    [src.IGNORED] = "Ignored",
    [src.NONE] = "Unknown",
    [src.FAVE] = "Favourite",
    [src.CRAFTING] = "Crafting",
    [src.CRAFTING_KNOWN] = "Crafting",
    [src.CRAFTING_UNKNOWN] = "Crafting",
    [src.VENDOR] = "Vendor",
    [src.HOME_GOODS] = "Home Goods Furnisher",
    [src.ACHIEVEMENT] = "Achievement Furnisher",
    [src.PVP] = "PvP Vendor",
    [src.WRIT_VENDOR] = "Master Writ Vendor",
    [src.CROWN] = "Crown Store",
    [src.RUMOUR] = "Datamined, unconfirmed",
    [src.LUXURY] = "Luxury Furnisher",
    [src.OTHER] = "Other",
    [src.ROLIS] = "Rolis Hlaalu",
    [src.DROP] = "Drop",
    [src.JUSTICE] = "Justice",
    [src.FISHING] = "Fishing",
    [src.GUILDSTORE] = "Guild Store",
    [src.FESTIVAL_DROP] = "Event",
    [src.BAZAAR] = "Gold Coast Bazaar",
    [src.TOMES] = "Tamriel Tomes",
    [src.TELVAR] = "Tel Var Merchant",
    [src.COLL_MERCH] = "Collectibles Merchant",
    [src.EDITOR] = "Housing Editor",
    [src.ANTIQUITY] = "Antiquity",
    [src.DUNGEON] = "Dungeon",
    [src.HARVEST] = "Harvesting",
    [src.CHEST] = "Treasure Chest",
    [src.QUEST] = "Quest Reward",
    [src.PICKPOCKET] = "Pickpocketing",
    [src.STEAL_CONTAINER] = "Stealing-marked Container",
  }

  -- Enum values that just exist for filtering, not as an item source
  -- TODO: mv those into FC only
  this.NotASource = {
    [src.FAVE] = true,
    [src.CRAFTING_KNOWN] = true,
    [src.CRAFTING_UNKNOWN] = true,
  }
end

-- Symbol -> one metadata field of a vocabulary the webinterface can extend. A hand-kept copy here missed every value added there.
local generated = assert(LFCGeneratedConstants)
local function fromVocabulary(key, field)
  local out = {}
  for name, ordinal in pairs(generated.ids[key]) do
    out[name] = generated.metadata[key][ordinal][field]
  end
  return out
end

-- Symbol -> the string id its `si` names (SI_* constants exist once the locale has loaded)
local function stringsOf(key)
  local out = {}
  for name, si in pairs(fromVocabulary(key, "si")) do
    out[name] = _G[si]
  end
  return out
end

this.Versioning = {}
this.VersionNames = {}
local latestVersion = 0
for name, value in pairs(generated.ids.versions) do
  this.Versioning[name] = value
  this.VersionNames[value] = name
  latestVersion = math.max(latestVersion, value)
end
this.Versioning.LATEST = latestVersion

---@deprecated Version smushing related compatibility workaround. Currently required by FC 7.0.0
--- Delete at next main version update.
this.Versioning.ZERO2 = this.Versioning.THIEVES

-- Game zones, translated by the game
--  Careful: the ids may change with expansions, use FurCDev.FindZone to fix any broken ones
this.ZoneIds = fromVocabulary("locations", "zone")

-- Places the game has no zone ids for
this.PlaceIds = stringsOf("places")

-- Localised names, keyed as before. Zones and places share the namespace
this.Locations = {}
this.ZoneByName = {}
this.PlaceByName = {}
deriveNames(this.ZoneIds, getZoneStr, this.Locations, this.ZoneByName)
deriveNames(this.PlaceIds, getStr, this.Locations, this.PlaceByName)

this.IsZoneId = {}
for _, id in pairs(this.ZoneIds) do
  this.IsZoneId[id] = true
end
this.IsPlaceId = {}
for _, id in pairs(this.PlaceIds) do
  this.IsPlaceId[id] = true
end

-- NPC ids, for better readability and more control of the string sources
-- Names keep the game's grammar markup; the formatter resolves it
this.NpcIds = stringsOf("vendors")

-- Default vendor locations
--
-- A vendor's location belongs to a vendor, not to the item (LuxuryFurnisher and writ-vendor items carry no location on their rows because their place is the same across all items)
--
-- An item can name its own location to override the default
--
-- Each vendor holds a LIST, because a vendor can stand in more than one place, and each entry names a `location` (game zone) or a `place`
this.VendorLocations = {
  [this.NpcIds.LUXF] = { { location = this.ZoneIds.COLDH }, { location = this.ZoneIds.CRAGLORN } },
  [this.NpcIds.ROLIS] = { { place = this.PlaceIds.ANY_CAPITAL } },
  [this.NpcIds.FAUSTINA] = { { place = this.PlaceIds.ANY_CAPITAL } },
}

-- Social classes (pickpocketing), rendered singular
-- NOTE: Extra lookup table for better testing, and because we don't own those strings (nil str would drop the whole row)
local SOCIAL_CLASS_STRINGS = {
  CLASS_ALCHEMIST = "SI_MONSTERSOCIALCLASS2",
  CLASS_ARTISAN = "SI_MONSTERSOCIALCLASS3",
  CLASS_ASSASSIN = "SI_MONSTERSOCIALCLASS4",
  CLASS_BARD = "SI_MONSTERSOCIALCLASS5",
  CLASS_BEGGAR = "SI_MONSTERSOCIALCLASS6",
  CLASS_CHEF = "SI_MONSTERSOCIALCLASS7",
  CLASS_CIVIL_SERVANT = "SI_MONSTERSOCIALCLASS8",
  CLASS_CLOTHIER = "SI_MONSTERSOCIALCLASS9",
  CLASS_COMMONER = "SI_MONSTERSOCIALCLASS10",
  CLASS_CRAFTER = "SI_MONSTERSOCIALCLASS11",
  CLASS_CULTIST = "SI_MONSTERSOCIALCLASS12",
  CLASS_DAEDRA = "SI_MONSTERSOCIALCLASS47",
  CLASS_DRUNKARD = "SI_MONSTERSOCIALCLASS13",
  CLASS_FARMER = "SI_MONSTERSOCIALCLASS14",
  CLASS_FIGHTER = "SI_MONSTERSOCIALCLASS15",
  CLASS_FISHER = "SI_MONSTERSOCIALCLASS16",
  CLASS_GATHERER = "SI_MONSTERSOCIALCLASS17",
  CLASS_GHOST = "SI_MONSTERSOCIALCLASS18",
  CLASS_GUARD = "SI_MONSTERSOCIALCLASS19",
  CLASS_HEALER = "SI_MONSTERSOCIALCLASS20",
  CLASS_HUNTER = "SI_MONSTERSOCIALCLASS21",
  CLASS_LABORER = "SI_MONSTERSOCIALCLASS22",
  CLASS_MAGE = "SI_MONSTERSOCIALCLASS23",
  CLASS_MERCHANT = "SI_MONSTERSOCIALCLASS24",
  CLASS_NOBLE = "SI_MONSTERSOCIALCLASS25",
  CLASS_NUDE = "SI_MONSTERSOCIALCLASS26",
  CLASS_ORDINATOR = "SI_MONSTERSOCIALCLASS27",
  CLASS_OUTLAW = "SI_MONSTERSOCIALCLASS28",
  CLASS_PILGRIM = "SI_MONSTERSOCIALCLASS29",
  CLASS_PRIEST = "SI_MONSTERSOCIALCLASS30",
  CLASS_PRISONER = "SI_MONSTERSOCIALCLASS31",
  CLASS_PROVISIONER = "SI_MONSTERSOCIALCLASS32",
  CLASS_SAILOR = "SI_MONSTERSOCIALCLASS33",
  CLASS_SCHOLAR = "SI_MONSTERSOCIALCLASS34",
  CLASS_SERVANT = "SI_MONSTERSOCIALCLASS35",
  CLASS_SKELETON = "SI_MONSTERSOCIALCLASS36",
  CLASS_SLAVE = "SI_MONSTERSOCIALCLASS37",
  CLASS_SMITH = "SI_MONSTERSOCIALCLASS38",
  CLASS_SOLDIER = "SI_MONSTERSOCIALCLASS39",
  CLASS_STUDENT = "SI_MONSTERSOCIALCLASS40",
  CLASS_THIEF = "SI_MONSTERSOCIALCLASS41",
  CLASS_VAMPIRE = "SI_MONSTERSOCIALCLASS42",
  CLASS_WARRIOR = "SI_MONSTERSOCIALCLASS43",
  CLASS_WATCHMEN = "SI_MONSTERSOCIALCLASS44",
  CLASS_WEREWOLF = "SI_MONSTERSOCIALCLASS45",
  CLASS_WOODWORKER = "SI_MONSTERSOCIALCLASS46",
}

this.NpcClassIds = {}
for key, stringId in pairs(SOCIAL_CLASS_STRINGS) do
  this.NpcClassIds[key] = _G[stringId]
end

-- Groups of enemies, rendered plural
this.NpcGroupIds = stringsOf("npc_groups")

this.NPC = {}
this.NpcByName = {}
deriveNames(this.NpcIds, getStr, this.NPC, this.NpcByName)
deriveNames(SOCIAL_CLASS_STRINGS, function(stringId)
  return getNpcClassStr(_G[stringId])
end, this.NPC, this.NpcByName)
deriveNames(this.NpcGroupIds, getNpcGroupStr, this.NPC, this.NpcByName)

this.AchievementIds = { UNKNOWN = 0 }

-- Crate ids per season: https://en.uesp.net/wiki/Online:Crown_Crates. UNKNOWN (0) is a crate row that does not say which crate.
this.CrownCrateIds = fromVocabulary("crates", "crate")

this.CrownCrates = {}
this.CrownCrateByName = {}
deriveNames(this.CrownCrateIds, getCrateStr, this.CrownCrates, this.CrownCrateByName)

-- Book containers
-- Source: manual lookup + https://en.uesp.net (minedItemSummary, ITEMTYPE_CONTAINER)
this.BookContainers = {
  -- Mages Guild reprints
  REPRINT_ALIKR = 120381, -- Guild Reprint: Alik'r Desert Lore
  REPRINT_AURIDON = 120401, -- Guild Reprint: Auridon Lore
  REPRINT_BANGKORAI = 120380, -- Guild Reprint: Bangkorai Lore
  REPRINT_BIOGRAPHIES = 120385, -- Guild Reprint: Biographies
  REPRINT_COLDHARBOUR = 120405, -- Guild Reprint: Coldharbour Lore
  REPRINT_DAEDRIC_PRINCES = 120384, -- Guild Reprint: Daedric Princes
  REPRINT_DESHAAN = 120399, -- Guild Reprint: Deshaan Lore
  REPRINT_DIVINES = 120386, -- Guild Reprint: Divines and Deities
  REPRINT_DUNGEON_LORE = 120387, -- Guild Reprint: Dungeon Lore
  REPRINT_DWEMER = 120388, -- Guild Reprint: Dwemer
  REPRINT_EASTMARCH = 120398, -- Guild Reprint: Eastmarch Lore
  REPRINT_EYEVEA = 120383, -- Guild Reprint: The Trial of Eyevea
  REPRINT_GLENUMBRA = 120377, -- Guild Reprint: Glenumbra Lore
  REPRINT_GRAHTWOOD = 120402, -- Guild Reprint: Grahtwood Lore
  REPRINT_GREENSHADE = 120403, -- Guild Reprint: Greenshade Lore
  REPRINT_LEGENDS_OF_NIRN = 120389, -- Guild Reprint: Legends of Nirn
  REPRINT_LITERATURE = 120390, -- Guild Reprint: Literature
  REPRINT_MAGIC_MAGICKA = 120391, -- Guild Reprint: Magic and Magicka
  REPRINT_MALABAL_TOR = 120397, -- Guild Reprint: Malabal Tor Lore
  REPRINT_MYTHS_MUNDUS = 120392, -- Guild Reprint: Myths of the Mundus
  REPRINT_OBLIVION_LORE = 120393, -- Guild Reprint: Oblivion Lore
  REPRINT_POETRY_SONG = 120394, -- Guild Reprint: Poetry and Song
  REPRINT_REAPERS_MARCH = 120404, -- Guild Reprint: Reaper's March Lore
  REPRINT_RIFT = 120400, -- Guild Reprint: The Rift Lore
  REPRINT_RIVENSPIRE = 120379, -- Guild Reprint: Rivenspire Lore
  REPRINT_SHADOWFEN = 120382, -- Guild Reprint: Shadowfen Lore
  REPRINT_STONEFALLS = 120396, -- Guild Reprint: Stonefalls Lore
  REPRINT_STORMHAVEN = 120378, -- Guild Reprint: Stormhaven Lore
  REPRINT_TAMRIEL_HISTORY = 120395, -- Guild Reprint: Tamriel History

  -- lore collections, sold by achievement furnishers
  TEMPLE_DOCTRINE = 126792, -- Temple Doctrine: The 36 Lessons (Vvardenfell)
  TRUTH_IN_SEQUENCE = 134547, -- The Truth in Sequence (Clockwork City)
  NOTHING_EYES = 145596, -- Look Upon Their Nothing Eyes (Murkmire)
}

this.ItemPacks = fromVocabulary("packs", "item")

--- Tamriel Tomes item packs. We don't have ids for those, so we use the strings
this.TomesPacks = {
  ARMOR = SI_FURC_TOMESPACK_ARMOR,
  DAWN = SI_FURC_TOMESPACK_DAWN,
  LOGIC = SI_FURC_TOMESPACK_LOGIC,
}

--- Crown Store bundles without itemlink, mv to ItemPacks when you get an ID
this.ItemBundles = stringsOf("bundles")

-- The game's guilds are skill lines, so a vendor row uses this table to say which guild sells the item
-- Guild source can be Mages, Fighters, Psijic, Thieves, Antiquariats (Thieves are connected to LEGERDEMAIN skill line; mages, fighters, antiquariats and psijic have their own)
-- Finding a new id: /script for i=1, 1000 do if (string.find(LocaleAwareToLower(GetSkillLineNameById(i)), "psijic")) then d(string.format("%d: %s", i, GetSkillLineNameById(i))) end end
this.SkillLineIds = fromVocabulary("skill_lines", "skill_line")

this.SkillLines = {}
this.SkillLineByName = {}
deriveNames(this.SkillLineIds, getSkillLineStr, this.SkillLines, this.SkillLineByName)

this.EventIds = stringsOf("events")

this.Events = {}
this.EventByName = {}
deriveNames(this.EventIds, getStr, this.Events, this.EventByName)

-- Source key for an event row the event itself drops (no vendor, no container)
this.EVENT_DROP = 0

this.Containers = {
  BOONBOX = "|H0:item:121526:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- during Whitestrake's Mayhem
  ELSWEYRCOFFER = "|H0:item:175580:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- during Season of the Dragon
  JESTERBOX = "|H0:item:194414:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- during Jester's Festival
  JUBILEEBOX = "|H0:item:134797:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- during Anniversary Jubilee
  LEGIONZEROBOX = "|H0:item:167210:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- during Imperial City Celebration
  NEWLIFEBOX = "|H0:item:96390:367:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- during New Life Festival
  PLUNDERSKULL = "|H0:item:84521:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- during Witches' Festival
  UNDAUNTEDBOX = "|H0:item:171267:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- during Undaunted Celebration
  ZENITHARPARCEL = "|H0:item:187701:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- during Zenithar's Zeal
  POUCH = "|H0:item:214263:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- during Crime Wave
  TRIBAL_TREASURE_CRATE = "|H0:item:145568:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Murkmire daily reward coffer
  ASHLANDER_COFFER = "|H0:item:126030:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Vvardenfell daily reward coffer
  SUMMERSET_FOLIO = "|H1:item:171572:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
  SKYRIM_FOLIO = "|H1:item:171808:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
  DRAGONHOLD_FOLIO = "|H1:item:171778:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
  TOMEHOLD_FOLIO = "|H1:item:214255:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
  ELSWEYR_FOLIO = "|H1:item:171574:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
  NECROM_FOLIO = "|H1:item:211090:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
  WEALD2_FOLIO = "|H1:item:223978:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
  WEALD_FOLIO = "|H1:item:219721:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
  MORROWIND_FOLIO = "|H1:item:171569:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
  MARKARTH_FOLIO = "|H1:item:184192:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
  HIGHISLE_FOLIO = "|H1:item:198597:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
  GALEN_FOLIO = "|H0:item:204499:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
  BLACKWOOD_FOLIO = "|H1:item:190121:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
  DEADLANDS_FOLIO = "|H1:item:194429:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
  EBONHEART_FOLIO = "|H1:item:171573:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
  CRAFTER_FOLIO = "|H1:item:171568:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
  DARKELF_FOLIO = "|H1:item:171571:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
  SOLSTICE_FOLIO = "|H1:item:226916:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
}

-- TODO: allow customisable colours, getting from options
local colours = {
  AP = "5EA4FF",
  Gold = "E5DA40",
  House = "40D0C0",
  Location = "CF6D00",
  Quest = "E5DA40",
  TelVar = "82BCFF",
  Vendor = "72DB00",
  Voucher = "25C31E",
}
this.Colours = colours

-- Old Constants as a fallback for other AddOns that use them
-- ToDo: required functionality will be moved to an API in the future

-- fallback item sources

-- @warning deprecated
FURC_NONE = this.ItemSources.NONE -- 1

-- @warning deprecated
FURC_FAVE = this.ItemSources.FAVE -- 2

-- @warning deprecated
FURC_CRAFTING = this.ItemSources.CRAFTING -- 3

-- @warning deprecated
FURC_CRAFTING_KNOWN = this.ItemSources.CRAFTING_KNOWN -- 4

-- @warning deprecated
FURC_CRAFTING_UNKNOWN = this.ItemSources.CRAFTING_UNKNOWN -- 5

-- @warning deprecated
FURC_VENDOR = this.ItemSources.VENDOR -- 6

-- @warning deprecated
FURC_PVP = this.ItemSources.PVP -- 7

-- @warning deprecated
FURC_WRIT_VENDOR = this.ItemSources.WRIT_VENDOR -- 8

-- @warning deprecated
FURC_CROWN = this.ItemSources.CROWN -- 9

-- @warning deprecated
FURC_RUMOUR = this.ItemSources.RUMOUR -- 10

-- @warning deprecated
FURC_LUXURY = this.ItemSources.LUXURY -- 11

-- @warning deprecated
FURC_OTHER = this.ItemSources.OTHER -- 12

-- @warning deprecated
FURC_ROLIS = this.ItemSources.ROLIS -- 13

-- @warning deprecated
FURC_DROP = this.ItemSources.DROP -- 14

-- @warning deprecated
FURC_JUSTICE = this.ItemSources.JUSTICE -- 15

-- @warning deprecated
FURC_FISHING = this.ItemSources.FISHING -- 16

-- @warning deprecated
FURC_GUILDSTORE = this.ItemSources.GUILDSTORE -- 17

-- @warning deprecated
FURC_FESTIVAL_DROP = this.ItemSources.FESTIVAL_DROP -- 18

-- fallback versions

-- @warning deprecated
FURC_HOMESTEAD = this.Versioning.HOMESTEAD -- 2 Homestead

-- @warning deprecated
FURC_MORROWIND = this.Versioning.MORROWIND -- 3 Morrowind

-- @warning deprecated
FURC_REACH = this.Versioning.REACH -- 4 Horns of the Reach

-- @warning deprecated
FURC_CLOCKWORK = this.Versioning.CLOCKWORK -- 5 Clockwork City

-- @warning deprecated
FURC_DRAGONS = this.Versioning.DRAGONS -- 6 Dragon Bones

-- @warning deprecated
FURC_ALTMER = this.Versioning.ALTMER -- 7 Summerset

-- @warning deprecated
FURC_SLAVES = this.Versioning.SLAVES -- 8 Murkmire

-- @warning deprecated
FURC_WEREWOLF = this.Versioning.WEREWOLF -- 9 Wolfhunter

-- @warning deprecated
FURC_WOTL = this.Versioning.WOTL -- 10 Wrathstone

-- @warning deprecated
FURC_KITTY = this.Versioning.KITTY -- 11 Elsweyr

-- @warning deprecated
FURC_SCALES = this.Versioning.SCALES -- 12 Scalebreaker

-- @warning deprecated
FURC_DRAGON2 = this.Versioning.DRAGON2 -- 13 Dragonhold

-- @warning deprecated
FURC_HARROW = this.Versioning.HARROW -- 14 Harrowstorm

-- @warning deprecated
FURC_SKYRIM = this.Versioning.SKYRIM -- 15 Greymoor

-- @warning deprecated
FURC_STONET = this.Versioning.STONET -- 16 Stonethorn

-- @warning deprecated
FURC_MARKAT = this.Versioning.MARKAT -- 17 Markarth

-- @warning deprecated
FURC_FLAMES = this.Versioning.FLAMES -- 18 Flames of Ambition

-- @warning deprecated
FURC_BLACKW = this.Versioning.BLACKW -- 19 Blackwood

-- @warning deprecated
FURC_DEADL = this.Versioning.DEADL -- 20 Deadlands

-- @warning deprecated
FURC_TIDES = this.Versioning.TIDES -- 21 Ascending Tide

-- @warning deprecated
FURC_BRETON = this.Versioning.BRETON -- 22 High Isle

-- @warning deprecated
FURC_DEPTHS = this.Versioning.DEPTHS -- 23 Lost Depths

-- @warning deprecated
FURC_DRUID = this.Versioning.DRUID -- 24 Firesong

-- @warning deprecated
FURC_SCRIBE = this.Versioning.SCRIBE -- 25 Scribes of Fate

-- @warning deprecated
FURC_NECROM = this.Versioning.NECROM -- 26 Necrom

-- @warning deprecated
FURC_BASED = this.Versioning.BASED -- 27 Base Game Patch

-- @warning deprecated
FURC_ENDLESS = this.Versioning.ENDLESS -- 28 Secrets of the Telvanni

-- @warning deprecated
FURC_SCIONS = this.Versioning.SCIONS -- 29 Scions of Ithelia

-- @warning deprecated
FURC_WEALD = this.Versioning.WEALD -- 30 Gold Road

-- @warning deprecated
FURC_BASE43 = this.Versioning.BASE43 -- 31 Update 43 Base Game Patch

-- @warning deprecated
FURC_BASE44 = this.Versioning.BASE44 -- 32 Update 44 Base Game Patch

-- @warning deprecated
FURC_LATEST = this.Versioning.LATEST
