-- BTV Tools, the Wizard's Wardrobe companion addon (btvtools issue #393).
--
-- One paste per player. The roster builder emits a single payload carrying every setup
-- for the run; this addon resolves each one against the player's real bags and writes
-- the finished setups straight into Wizard's Wardrobe, with the boss auto-swap
-- conditions already attached. WW's own gear matcher never runs (#345).
--
-- The site proposes, the client decides. What the roster asks of a SLOT (trait, weight,
-- weapon type) belongs to the slot; what it asks of a SET (how many pieces) belongs to
-- the set. The eight matcher rules below were each learned from a real in-game failure
-- during the spike (#346) and are binding.
--
-- SavedVariables hold the settings and the import record (#463, #467): which import is in
-- progress, where it landed, and a rolling history of done ones. `/btv missing` reprints
-- the last import's misses from memory.

BTVTools = {}
local BTV = BTVTools
-- Must equal the addon folder name: that is what EVENT_ADD_ON_LOADED hands back.
BTV.name = "BTVToolsRosterImporter"

-- The newest payload shape this addon can read; v1 still reads (BTV.Decode). A payload
-- stamped with anything else is refused outright: a half-import is worse than no import (#345).
BTV.PAYLOAD_VERSION = 2

-- How much the paste box is told to hold. The edit box drops everything past this SILENTLY, so a
-- payload one character over arrives as broken JSON and reads as "not a BTV payload" (#413).
-- A 23 setup Ossein Cage run is 20,275 characters, which is what blew the old 20,000 ceiling.
-- The game caps the box near 29,900 anyway (2026-10-15), so the site splits anything
-- longer into parts (BTV:k/N:) and the /btv window joins them.
BTV.PASTE_LIMIT = 200000

local WW = WizardsWardrobe

-- Slot -> the one equip type that slot accepts.
local ARMOR_SLOTS = {
	[ EQUIP_SLOT_HEAD ] = EQUIP_TYPE_HEAD,
	[ EQUIP_SLOT_CHEST ] = EQUIP_TYPE_CHEST,
	[ EQUIP_SLOT_SHOULDERS ] = EQUIP_TYPE_SHOULDERS,
	[ EQUIP_SLOT_WAIST ] = EQUIP_TYPE_WAIST,
	[ EQUIP_SLOT_LEGS ] = EQUIP_TYPE_LEGS,
	[ EQUIP_SLOT_FEET ] = EQUIP_TYPE_FEET,
	[ EQUIP_SLOT_HAND ] = EQUIP_TYPE_HAND,
}
local JEWELRY_SLOTS = {
	[ EQUIP_SLOT_NECK ] = EQUIP_TYPE_NECK,
	[ EQUIP_SLOT_RING1 ] = EQUIP_TYPE_RING,
	[ EQUIP_SLOT_RING2 ] = EQUIP_TYPE_RING,
}
-- Weapons never trade with body (rule 3), and they stay on the bar the roster put them
-- on, so a weapon demand only ever competes for its own slot.
local WEAPON_SLOTS = {
	[ EQUIP_SLOT_MAIN_HAND ] = { [ EQUIP_TYPE_ONE_HAND ] = true, [ EQUIP_TYPE_TWO_HAND ] = true, [ EQUIP_TYPE_MAIN_HAND ] = true },
	[ EQUIP_SLOT_OFF_HAND ] = { [ EQUIP_TYPE_ONE_HAND ] = true, [ EQUIP_TYPE_OFF_HAND ] = true },
	[ EQUIP_SLOT_BACKUP_MAIN ] = { [ EQUIP_TYPE_ONE_HAND ] = true, [ EQUIP_TYPE_TWO_HAND ] = true, [ EQUIP_TYPE_MAIN_HAND ] = true },
	[ EQUIP_SLOT_BACKUP_OFF ] = { [ EQUIP_TYPE_ONE_HAND ] = true, [ EQUIP_TYPE_OFF_HAND ] = true },
}

-- Which bar a weapon slot is on. Set bonuses are counted per ACTIVE bar (rule 12), so the
-- two bars are alternatives rather than additions and each one is measured on its own.
local WEAPON_BAR = {
	[ EQUIP_SLOT_MAIN_HAND ] = 1, [ EQUIP_SLOT_OFF_HAND ] = 1,
	[ EQUIP_SLOT_BACKUP_MAIN ] = 2, [ EQUIP_SLOT_BACKUP_OFF ] = 2,
}

-- The off hand a two-hander would otherwise have filled, for rule 14's shape swap.
local OFF_HAND_OF = {
	[ EQUIP_SLOT_MAIN_HAND ] = EQUIP_SLOT_OFF_HAND,
	[ EQUIP_SLOT_BACKUP_MAIN ] = EQUIP_SLOT_BACKUP_OFF,
}

-- Base armor resistance per slot and weight, mirrored from `ARMOR_BASE` in
-- `src/lib/resistanceCalculator.ts`. Only the differences matter here (rule 13): head,
-- shoulders, legs and feet are worth the same, so a weight moving between them costs
-- nothing, while chest, hands and waist each differ. Trait is left out on purpose, because
-- Reinforced multiplies and Nirnhoned adds a flat amount, so neither can change whether a
-- move is free, and trait is reported on its own line anyway.
local RESIST_LARGE = { [ ARMORTYPE_HEAVY ] = 2425, [ ARMORTYPE_MEDIUM ] = 1823, [ ARMORTYPE_LIGHT ] = 1221 }
local ARMOR_RESIST = {
	[ EQUIP_SLOT_HEAD ] = RESIST_LARGE,
	[ EQUIP_SLOT_SHOULDERS ] = RESIST_LARGE,
	[ EQUIP_SLOT_LEGS ] = RESIST_LARGE,
	[ EQUIP_SLOT_FEET ] = RESIST_LARGE,
	[ EQUIP_SLOT_CHEST ] = { [ ARMORTYPE_HEAVY ] = 2772, [ ARMORTYPE_MEDIUM ] = 2084, [ ARMORTYPE_LIGHT ] = 1396 },
	[ EQUIP_SLOT_HAND ] = { [ ARMORTYPE_HEAVY ] = 1386, [ ARMORTYPE_MEDIUM ] = 1042, [ ARMORTYPE_LIGHT ] = 698 },
	[ EQUIP_SLOT_WAIST ] = { [ ARMORTYPE_HEAVY ] = 1039, [ ARMORTYPE_MEDIUM ] = 781, [ ARMORTYPE_LIGHT ] = 523 },
}

-- One pool. A set may be dealt into any body slot the player owns a piece for (rule 2).
local BODY_ORDER = { EQUIP_SLOT_HEAD, EQUIP_SLOT_CHEST, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS,
	EQUIP_SLOT_FEET, EQUIP_SLOT_HAND, EQUIP_SLOT_NECK, EQUIP_SLOT_RING1, EQUIP_SLOT_RING2 }

local SLOT_NAME = {
	[ EQUIP_SLOT_HEAD ] = "head", [ EQUIP_SLOT_CHEST ] = "chest", [ EQUIP_SLOT_SHOULDERS ] = "shoulders",
	[ EQUIP_SLOT_WAIST ] = "waist", [ EQUIP_SLOT_LEGS ] = "legs", [ EQUIP_SLOT_FEET ] = "feet",
	[ EQUIP_SLOT_HAND ] = "hands", [ EQUIP_SLOT_NECK ] = "neck", [ EQUIP_SLOT_RING1 ] = "ring 1",
	[ EQUIP_SLOT_RING2 ] = "ring 2", [ EQUIP_SLOT_MAIN_HAND ] = "main hand", [ EQUIP_SLOT_OFF_HAND ] = "off hand",
	[ EQUIP_SLOT_BACKUP_MAIN ] = "backup main", [ EQUIP_SLOT_BACKUP_OFF ] = "backup off",
}
-- The window's gear grid labels its cells with the same words the report uses (#477).
BTV.SLOT_NAME = SLOT_NAME

-- Payload speaks names, the addon owns the game's numbers.
local WEIGHTS = { light = ARMORTYPE_LIGHT, medium = ARMORTYPE_MEDIUM, heavy = ARMORTYPE_HEAVY }
local WEAPONS = {
	sword = WEAPONTYPE_SWORD, axe = WEAPONTYPE_AXE, mace = WEAPONTYPE_HAMMER, dagger = WEAPONTYPE_DAGGER,
	greatsword = WEAPONTYPE_TWO_HANDED_SWORD, battleaxe = WEAPONTYPE_TWO_HANDED_AXE, maul = WEAPONTYPE_TWO_HANDED_HAMMER,
	bow = WEAPONTYPE_BOW, fire = WEAPONTYPE_FIRE_STAFF, frost = WEAPONTYPE_FROST_STAFF,
	lightning = WEAPONTYPE_LIGHTNING_STAFF, restoration = WEAPONTYPE_HEALING_STAFF, shield = WEAPONTYPE_SHIELD,
}

-- Glyph names the payload may carry -> the game's enchant search category. A preference
-- only, never a demand: it breaks the tie between two copies of the same piece wearing
-- different glyphs (the tester's stamina and magicka Null Arca sets). Categories rather
-- than enchant ids, so a Truly Superb glyph matches a demand written from a lesser one.
local GLYPHS = {
	[ "absorb health" ] = ENCHANTMENT_SEARCH_CATEGORY_ABSORB_HEALTH,
	[ "absorb magicka" ] = ENCHANTMENT_SEARCH_CATEGORY_ABSORB_MAGICKA,
	[ "absorb stamina" ] = ENCHANTMENT_SEARCH_CATEGORY_ABSORB_STAMINA,
	[ "befouled weapon" ] = ENCHANTMENT_SEARCH_CATEGORY_BEFOULED_WEAPON,
	[ "berserker" ] = ENCHANTMENT_SEARCH_CATEGORY_BERSERKER,
	[ "charged weapon" ] = ENCHANTMENT_SEARCH_CATEGORY_CHARGED_WEAPON,
	[ "damage health" ] = ENCHANTMENT_SEARCH_CATEGORY_DAMAGE_HEALTH,
	[ "damage shield" ] = ENCHANTMENT_SEARCH_CATEGORY_DAMAGE_SHIELD,
	[ "decrease physical damage" ] = ENCHANTMENT_SEARCH_CATEGORY_DECREASE_PHYSICAL_DAMAGE,
	[ "decrease spell damage" ] = ENCHANTMENT_SEARCH_CATEGORY_DECREASE_SPELL_DAMAGE,
	[ "disease resistant" ] = ENCHANTMENT_SEARCH_CATEGORY_DISEASE_RESISTANT,
	[ "fiery weapon" ] = ENCHANTMENT_SEARCH_CATEGORY_FIERY_WEAPON,
	[ "fire resistant" ] = ENCHANTMENT_SEARCH_CATEGORY_FIRE_RESISTANT,
	[ "frost resistant" ] = ENCHANTMENT_SEARCH_CATEGORY_FROST_RESISTANT,
	[ "frozen weapon" ] = ENCHANTMENT_SEARCH_CATEGORY_FROZEN_WEAPON,
	[ "health" ] = ENCHANTMENT_SEARCH_CATEGORY_HEALTH,
	[ "health regen" ] = ENCHANTMENT_SEARCH_CATEGORY_HEALTH_REGEN,
	[ "increase bash damage" ] = ENCHANTMENT_SEARCH_CATEGORY_INCREASE_BASH_DAMAGE,
	[ "increase physical damage" ] = ENCHANTMENT_SEARCH_CATEGORY_INCREASE_PHYSICAL_DAMAGE,
	[ "increase potion effectiveness" ] = ENCHANTMENT_SEARCH_CATEGORY_INCREASE_POTION_EFFECTIVENESS,
	[ "increase spell damage" ] = ENCHANTMENT_SEARCH_CATEGORY_INCREASE_SPELL_DAMAGE,
	[ "magicka" ] = ENCHANTMENT_SEARCH_CATEGORY_MAGICKA,
	[ "magicka regen" ] = ENCHANTMENT_SEARCH_CATEGORY_MAGICKA_REGEN,
	[ "poisoned weapon" ] = ENCHANTMENT_SEARCH_CATEGORY_POISONED_WEAPON,
	[ "poison resistant" ] = ENCHANTMENT_SEARCH_CATEGORY_POISON_RESISTANT,
	[ "prismatic defense" ] = ENCHANTMENT_SEARCH_CATEGORY_PRISMATIC_DEFENSE,
	[ "prismatic onslaught" ] = ENCHANTMENT_SEARCH_CATEGORY_PRISMATIC_ONSLAUGHT,
	[ "reduce armor" ] = ENCHANTMENT_SEARCH_CATEGORY_REDUCE_ARMOR,
	[ "reduce block and bash" ] = ENCHANTMENT_SEARCH_CATEGORY_REDUCE_BLOCK_AND_BASH,
	[ "reduce feat cost" ] = ENCHANTMENT_SEARCH_CATEGORY_REDUCE_FEAT_COST,
	[ "reduce potion cooldown" ] = ENCHANTMENT_SEARCH_CATEGORY_REDUCE_POTION_COOLDOWN,
	[ "reduce power" ] = ENCHANTMENT_SEARCH_CATEGORY_REDUCE_POWER,
	[ "reduce spell cost" ] = ENCHANTMENT_SEARCH_CATEGORY_REDUCE_SPELL_COST,
	[ "shock resistant" ] = ENCHANTMENT_SEARCH_CATEGORY_SHOCK_RESISTANT,
	[ "stamina" ] = ENCHANTMENT_SEARCH_CATEGORY_STAMINA,
	[ "stamina regen" ] = ENCHANTMENT_SEARCH_CATEGORY_STAMINA_REGEN,
	-- "prismatic regen" has no search category the game exposes, so it stays a name the
	-- addon does not know and simply never scores.
}

-- The glyph a piece is wearing, as a search category, or nil when it wears none. A player
-- glyph overwrites the drop's built-in one, so the applied id wins over the default.
-- The two jewelry damage glyphs are one glyph to every comparison (owner, 2026-09-18): both
-- give the same weapon and spell damage, so neither is worth a trip over the other.
local GLYPH_TWIN = { [ ENCHANTMENT_SEARCH_CATEGORY_INCREASE_SPELL_DAMAGE ] = ENCHANTMENT_SEARCH_CATEGORY_INCREASE_PHYSICAL_DAMAGE }
local function SameGlyph( a, b )
	return ( GLYPH_TWIN[ a ] or a ) == ( GLYPH_TWIN[ b ] or b )
end

local GLYPH_WORD = {}
for word, category in pairs( GLYPHS ) do GLYPH_WORD[ category ] = word end
local function GlyphOf( link )
	local enchantId = GetItemLinkAppliedEnchantId( link )
	if enchantId == 0 then enchantId = GetItemLinkDefaultEnchantId( link ) end
	if enchantId == 0 then return nil end
	local category = GetEnchantSearchCategoryType( enchantId )
	if category == ENCHANTMENT_SEARCH_CATEGORY_NONE then return nil end
	return category
end

-- The same physical piece is one link in a bag (|H0:, LINK_STYLE_DEFAULT) and another in
-- IIfA's cache (|H1:, with the name in brackets), so links are compared by their item
-- data alone (owner hand test 2026-09-09: a withdrawn piece vanished from the plan
-- instead of ticking).
local function LinkKey( link )
	return link and link:match( "item:[^|]+" ) or link
end
BTV.LinkKey = LinkKey

-- Read back the other way, so a shape the player owns is named with the same word the
-- leader wrote in the roster (#402).
local function NameOf( map, value )
	for name, id in pairs( map ) do
		if id == value then return name end
	end
	return "an unknown shape"
end

-- Everything the last import had to tell the player, kept in memory for `/btv missing`, and
-- the wrong-trait pieces it only counted (rule 10), listed inline at full verbosity. Both go
-- when the player logs out; only the import record below survives.
BTV.lastReport = {}
BTV.lastTraits = {}

-- ------------------------------------------------------ settings and the record

-- The seven settings (#463, amended by #467, #472, #473). `accountWide` itself always
-- lives account-wide, or nothing could find its way to the per-character table.
local DEFAULTS = {
	accountWide = true,
	autoOpen = true,        -- read by the banker/coffer window, increment 7 of #474
	verbosity = "line",     -- silent / line / full
	autoOverwrite = false,
	exactTraits = false,    -- never wear an off-trait piece; the plan creates one instead (owner, 2026-09-08)
	autoDeposit = false,    -- auto deposit/withdraw, read by the fetch window, increment 7 of #474
	autoCraft = false,      -- run queued craft and reconstruct lines at an open station (#482); off since step tips (2026-10-14)
	historySize = 10,
	debugTrace = false,     -- arms the match trace for one import (#483)
	usePlacements = true,   -- put each skill in the player's saved slot at write (ADR 0020)
	hudIcon = "import",     -- HUD icon: never / always / import, only while an import is in progress (owner, 2026-10-29)
}

function BTV.Setting( key )
	if key == "accountWide" or BTV.svAccount.settings.accountWide then
		return BTV.svAccount.settings[ key ]
	end
	return BTV.svChar.settings[ key ]
end

-- A setting toggled anywhere shows everywhere at once (owner, 2026-09-15): the plan's
-- rows and the settings panel are two views of this one value, so both redraw.
function BTV.SetSetting( key, value )
	if key == "accountWide" or BTV.svAccount.settings.accountWide then
		BTV.svAccount.settings[ key ] = value
	else
		BTV.svChar.settings[ key ] = value
	end
	if BTV.settingsPanel and CALLBACK_MANAGER then CALLBACK_MANAGER:FireCallbacks( "LAM-RefreshPanel", BTV.settingsPanel ) end
	if BTV.OnSettingChanged then BTV.OnSettingChanged() end
end

-- The import record (#467, #472): one active import per account, plus a rolling history of
-- done ones. Always account-wide, whatever the settings toggle says: the fetch list and the
-- plan are recomputed from it on whichever character is logged in.
function BTV.SaveRecord( record )
	BTV.svAccount.record = record
	if BTV.OnRecordChanged then BTV.OnRecordChanged() end
end

function BTV.GetRecord()
	return BTV.svAccount.record
end

-- Newest first, capped by the setting. A replaced import lands here unstamped, so it can
-- be picked up again from Past imports (#472, #480).
local function PushHistory( record )
	table.insert( BTV.svAccount.history, 1, record )
	for i = #BTV.svAccount.history, BTV.Setting( "historySize" ) + 1, -1 do
		table.remove( BTV.svAccount.history, i )
	end
end

function BTV.FinishRecord()
	local record = BTV.svAccount.record
	if not record then return end
	-- A reactivated done import keeps its first done stamp.
	record.doneAt = record.doneAt or GetTimeStamp()
	PushHistory( record )
	BTV.svAccount.record = nil
	if BTV.OnRecordChanged then BTV.OnRecordChanged() end
end

-- Opening a past import makes it active again (#472); whatever was active takes its place
-- in the history, so nothing is lost either way.
function BTV.Reactivate( index )
	local record = table.remove( BTV.svAccount.history, index )
	if not record then return nil end
	local active = BTV.svAccount.record
	if active then PushHistory( active ) end
	BTV.svAccount.record = record
	if BTV.OnRecordChanged then BTV.OnRecordChanged() end
	return record
end

-- ----------------------------------------------------------------- chat lines

local function Say( msg )
	d( "|c7B68EE[BTV]|r " .. msg )
end

-- Remembered for `/btv missing`; said now only at full verbosity (#473). The svAccount
-- guard is for anything that runs before ADD_ON_LOADED, where full is the honest default.
local function Remember( msg )
	table.insert( BTV.lastReport, msg )
	if not BTV.svAccount or BTV.Setting( "verbosity" ) == "full" then Say( msg ) end
end

-- A swap or a miss is nearly always the same news in several setups, so it is gathered
-- across the whole import and said once, naming the builds it applies to (#402). Repeating
-- it per build buries it, and saying it once with no attribution leaves the player unable to
-- tell whether it cost them one setup or all of them.
local function Gather( into, order, text, build )
	local hit = into[ text ]
	if not hit then
		hit = { text = text, builds = {}, seen = {} }
		into[ text ] = hit
		table.insert( order, hit )
	end
	if not hit.seen[ build ] then
		hit.seen[ build ] = true
		table.insert( hit.builds, build )
	end
end

local function Attributed( hit, total )
	if total <= 1 then return hit.text end
	if #hit.builds >= total then return hit.text .. " (all setups)" end
	return hit.text .. " (" .. table.concat( hit.builds, ", " ) .. ")"
end

local function SlotKind( slotId )
	if ARMOR_SLOTS[ slotId ] or JEWELRY_SLOTS[ slotId ] then return "body" end
	if WEAPON_SLOTS[ slotId ] then return "weapon" end
	return nil
end

-- The game hands back names with their grammatical-gender markup still attached ("The
-- Maelstrom's Battle Axe^n"), which is for the language layer and not for a player to read
-- (#405). zo_strformat with the game's own item-name format is what strips it, and it is
-- the same call every ESO tooltip goes through. Display only: nothing here is ever matched
-- on, so this changes what is printed and nothing else.
local function CleanName( name )
	if not name or name == "" then return name end
	return zo_strformat( SI_TOOLTIP_ITEM_NAME, name )
end

-- The game names a set from its id alone, so a set the player has never owned still
-- reads as a set rather than a number.
local function SetLabel( setId )
	local name = CleanName( GetItemSetName( setId ) )
	if name and name ~= "" then return name end
	return "set " .. tostring( setId )
end

-- An arena weapon is named after the arena while its set is named after the effect, so
-- "Merciless Charge" alone does not tell a player what to go and get. #350 wants the set
-- name and the game's piece name, always both. The game can name a set's pieces without
-- the player owning any of them.
local function PieceNames( setId, want )
	local names, seen = {}, {}
	for i = 1, GetNumItemSetCollectionPieces( setId ) do
		local pieceId = GetItemSetCollectionPieceInfo( setId, i )
		local link = pieceId and GetItemSetCollectionPieceItemLink( pieceId, LINK_STYLE_DEFAULT )
		if link and link ~= "" and not ( want and want.eq and GetItemLinkEquipType( link ) ~= want.eq ) then
			local name = CleanName( GetItemLinkName( link ) )
			if name and name ~= "" and not seen[ name ] then
				seen[ name ] = true
				table.insert( names, name )
			end
		end
	end
	return names
end

-- Set name plus the game's own piece names (#350).
local function DemandLabel( demand, req )
	local label = SetLabel( demand.set )
	local pieces = PieceNames( demand.set, demand.slot and req[ demand.slot ] )
	if #pieces > 0 and #pieces <= 4 then
		label = label .. " (" .. table.concat( pieces, " / " ) .. ")"
	end
	if demand.slot then
		label = label .. " (" .. ( SLOT_NAME[ demand.slot ] or tostring( demand.slot ) ) .. ")"
	end
	return label
end

-- A perfected piece carries the plain set's bonus as well as its own, so it satisfies a
-- demand for the plain set (rule 7). The game holds the pairing, so neither the payload
-- nor the site has to.
local function IsPerfectedFormOf( itemSetId, wantedSetId )
	return itemSetId ~= wantedSetId and GetItemSetUnperfectedSetId( itemSetId ) == wantedSetId
end

-- And the other way round (#401). A plain piece is everything its perfected form is bar
-- the extra bonus, so a roster asking for Perfected Thunderous Volley is better served by
-- the plain bow the player owns than by a miss it can do nothing about. A downgrade, so
-- ScoreItem ranks it under both an exact match and a perfected one.
local function IsPlainFormOf( itemSetId, wantedSetId )
	return itemSetId ~= wantedSetId and GetItemSetUnperfectedSetId( wantedSetId ) == itemSetId
end

-- The game has no name-from-item-id call, but every name lookup works off a link and a link
-- can be built from the id alone, which is what WW does for its own food preview
-- (WizardsWardrobePreview.lua:443). Used to name the recipe the roster asked for when the
-- player ate a different member of the same buff class (#402).
local function ItemName( itemId )
	if not itemId or itemId == 0 then return "nothing" end
	local link = string.format( "|H0:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId )
	local name = CleanName( GetItemLinkName( link ) )
	if name and name ~= "" then return name end
	return "item " .. tostring( itemId )
end

local function TraitName( trait )
	local name = GetString( "SI_ITEMTRAITTYPE", trait or 0 )
	if name and name ~= "" then return name end
	return "trait " .. tostring( trait )
end
-- The window's Missing gear rows say sets and traits in the report's words (#479).
BTV.SetLabel, BTV.TraitName = SetLabel, TraitName

-- Remembered per pair: which set is the perfected form of which is game data, fixed for the
-- session, and the missing-gear plan asks the same pairs millions of times (a 23 setup
-- roster spent most of a freeze long enough to disconnect here, 2026-10-15).
local setMatches = {}
local function SetMatches( itemSetId, wantedSetId )
	if itemSetId == wantedSetId then return true end
	if itemSetId == nil or wantedSetId == nil then return false end
	local row = setMatches[ itemSetId ]
	if not row then
		row = {}
		setMatches[ itemSetId ] = row
	end
	local hit = row[ wantedSetId ]
	if hit == nil then
		hit = IsPerfectedFormOf( itemSetId, wantedSetId ) or IsPlainFormOf( itemSetId, wantedSetId )
		row[ wantedSetId ] = hit
	end
	return hit
end

-- Location keys out of IIfA are character ids, sometimes as strings and sometimes as
-- numbers, so both get flattened the same way before they are matched to a name.
local function LocationKey( id )
	if type( id ) == "number" then return string.format( "%.0f", id ) end
	return tostring( id )
end

-- IIfA keys a location by character id for a bag, by a fixed string for the bank and the
-- furniture vault, by guild name for a guild bank and by house collectible id for house
-- storage (getDatabaseItemLocation, InventoryInsight_DataCollection.lua:67). Only the
-- character case was ever named, so a piece in the bank read out as the raw key (#402).
local function ContainerName( key )
	if key == ( IIFA_LOCATION_KEY_BANK or "Bank" ) then return "your bank" end
	if key == ( IIFA_LOCATION_KEY_FURNITURE_VAULT or "FurnitureVault" ) then return "your furniture vault" end
	return nil
end

local characterNames
local function PlaceName( key )
	if not characterNames then
		characterNames = {}
		for i = 1, GetNumCharacters() do
			local name, _, _, _, _, _, id = GetCharacterInfo( i )
			-- Character names arrive with the same gender markup item names do ("Balltongue^Mx"),
			-- and this one is printed straight at the player (#413).
			characterNames[ LocationKey( id ) ] = CleanName( name )
		end
	end
	if characterNames[ key ] then return characterNames[ key ] end
	local container = ContainerName( key )
	if container then return container end
	-- Anything else numeric is a house collectible id, named the way IIfA names it itself
	-- (InventoryInsight_Backpack.lua:1154). Anything else is already a guild name.
	local collectible = tonumber( key )
	if collectible then
		local name = GetCollectibleNickname( collectible )
		if not name or name == "" then name = GetCollectibleName( collectible ) end
		if name and name ~= "" then return name end
	end
	return key
end

-- What kind of place an IIfA key names, for the plan's groups (#480): a character to
-- deposit from, a house coffer to fetch from, the bank to withdraw at, or a guild bank
-- (which BTV never touches, #467).
function BTV.PlaceKind( key )
	if not key then return "unknown" end
	PlaceName( key ) -- fills the character cache
	if characterNames[ key ] then return "character" end
	if ContainerName( key ) then return "bank" end
	if tonumber( key ) then return "house" end
	return "guild"
end

-- ---------------------------------------------------------------- item pool

local function ReadItem( bag, slot, rank )
	local link = GetItemLink( bag, slot, LINK_STYLE_DEFAULT )
	if not link or link == "" then return nil end
	local hasSet, setName, _, _, maxEquipped, setId = GetItemLinkSetInfo( link, false )
	if not hasSet or not setId or setId == 0 then return nil end
	return {
		bag = bag,
		slot = slot,
		link = link,
		setId = setId,
		setName = setName,
		maxEquipped = maxEquipped, -- the game's own cap: 5 for most, 2 for a monster set, 1 for a mythic
		equipType = GetItemLinkEquipType( link ),
		trait = GetItemLinkTraitInfo( link ),
		-- A preference only (#401), never a floor: the roster carries no quality field, so
		-- this only ever breaks a tie between the player's own copies of the same piece.
		quality = GetItemLinkDisplayQuality( link ),
		armorType = GetItemLinkArmorType( link ),
		weaponType = GetItemLinkWeaponType( link ),
		glyph = GlyphOf( link ),
		mythic = WW.IsMythic( bag, slot ),
		rank = rank,
	}
end

-- Worn and backpack are always readable; the bank only while it is open (#344).
function BTV.ScanBags()
	local pool = {}
	local bags = { { BAG_WORN, 10 }, { BAG_BACKPACK, 5 } }
	local bankBag = GetBankingBag()
	if IsBankOpen() and not WW.DISABLEDBAGS[ bankBag ] then
		table.insert( bags, { bankBag, 0 } )
		if bankBag == BAG_BANK and IsESOPlusSubscriber() then
			table.insert( bags, { BAG_SUBSCRIBER_BANK, 0 } )
		end
	end
	for _, entry in ipairs( bags ) do
		for slot = 0, GetBagSize( entry[ 1 ] ) do
			local item = ReadItem( entry[ 1 ], slot, entry[ 2 ] )
			if item then table.insert( pool, item ) end
		end
	end
	return pool
end

-- --------------------------------------------------------- the remote pool

-- "Owned but on another character" is only answerable from a cache (#344), and IIfA is a
-- hard dependency so its cache is the one we read (#350).
--
-- These come back shaped exactly like bag items, carrying `remote`, so the matcher ranks
-- them alongside real ones instead of answering the same question down a second path
-- (#413). A remote piece is written into the setup and never equipped: the addon's job is
-- to produce the template, and moving the gear is the player's.
--
-- No mythic flag. IIfA holds links, not bag slots, and WW.IsMythic needs a bag slot, so a
-- remote mythic ranks as ordinary armor and can still miss on weight (rule 5 never fires
-- for it). It is also never written as the setup's mythic slot, which is the half that
-- would hurt: WW's mythic path unequips the worn one to make room.
--
-- The loud "obtain or craft it" tier is EARNED, not assumed: telling a player to go and
-- craft a piece they already own is the failure mode #346 called out. It is only used when
-- IIfA holds something from every character on the account. Anything less and it hedges.
function BTV.RemotePool()
	local pool, seen = {}, {}
	local ok, db = pcall( function() return IIfA:GetInventoryDB() end )
	if not ok or type( db ) ~= "table" then return nil, false end

	-- IIfA caches this character and the bank too. Both are already in the bag pool with
	-- real unique ids, so counting them again would double the same physical piece and put
	-- gear the player is wearing on the list of things to go and fetch.
	local skip = {}
	skip[ LocationKey( GetCurrentCharacterId() ) ] = true
	if IsBankOpen() then skip[ IIFA_LOCATION_KEY_BANK or "Bank" ] = true end

	for key, entry in pairs( db ) do
		if type( key ) == "string" and key:find( "|H", 1, true ) then
			local hasSet, _, _, _, maxEquipped, setId = GetItemLinkSetInfo( key, false )
			if hasSet and setId and setId > 0 then
				-- One IIfA entry is one item LINK, however many copies the account holds, so
				-- the copies have to be counted out or two demands would fight over one entry.
				-- Two Ansuul's Perfected Rings in one coffer are a single entry with two
				-- bagSlot rows (#413).
				local named, copies = {}, 0
				if type( entry ) == "table" and type( entry.locations ) == "table" then
					for location, held in pairs( entry.locations ) do
						local locationKey = LocationKey( location )
						seen[ locationKey ] = true
						if not skip[ locationKey ] then
							local here = 0
							if type( held ) == "table" and type( held.bagSlot ) == "table" then
								for _, n in pairs( held.bagSlot ) do here = here + ( tonumber( n ) or 1 ) end
							end
							copies = copies + math.max( here, 1 )
							table.insert( named, { name = PlaceName( locationKey ), key = locationKey } )
						end
					end
				end
				-- pairs order is not stable and this ends up in a printed report. The keys ride
				-- along so the plan can tell a character from a coffer from the bank (#480).
				table.sort( named, function( a, b ) return a.name < b.name end )
				local places, placeKeys = {}, {}
				for i, place in ipairs( named ) do places[ i ], placeKeys[ i ] = place.name, place.key end
				-- ponytail: no build can wear more than the equip slots, so a hoard of 40 is
				-- capped rather than dragged through the matcher.
				for _ = 1, math.min( copies, #BODY_ORDER + 4 ) do
					table.insert( pool, {
						link = key,
						setId = setId,
						maxEquipped = maxEquipped,
						equipType = GetItemLinkEquipType( key ),
						trait = GetItemLinkTraitInfo( key ),
						quality = GetItemLinkDisplayQuality( key ),
						armorType = GetItemLinkArmorType( key ),
						weaponType = GetItemLinkWeaponType( key ),
						glyph = GlyphOf( key ),
						remote = true,
						places = places,
						placeKeys = placeKeys,
					} )
				end
			end
		end
	end

	local characters = GetNumCharacters()
	local complete = characters > 0
	for i = 1, characters do
		local _, _, _, _, _, _, id = GetCharacterInfo( i )
		if not seen[ LocationKey( id ) ] then complete = false end
	end
	return pool, complete
end

-- The tester's two Null Arca sets sat on two characters, and the import sent him to both
-- when either alone could dress the build. Every remote piece learns how many pieces this
-- import wants that its place holds, and ScoreItem prefers the fuller place, so the picks
-- converge on the one character worth the trip.
--
-- ponytail: copies of one link share one `places` list, so a copy credits every place it
-- might be at. Close enough: the count only ranks characters against each other.
function BTV.ClusterPool( remote, wanted )
	local function Wanted( setId )
		if wanted[ setId ] then return true end
		for id in pairs( wanted ) do if SetMatches( setId, id ) then return true end end
		return false
	end
	local rich = {}
	for _, item in ipairs( remote ) do
		if Wanted( item.setId ) then
			for _, place in ipairs( item.places or {} ) do rich[ place ] = ( rich[ place ] or 0 ) + 1 end
		end
	end
	for _, item in ipairs( remote ) do
		local best = 0
		for _, place in ipairs( item.places or {} ) do
			if ( rich[ place ] or 0 ) > best then best = rich[ place ] end
		end
		item.cluster = best
	end
end

-- ------------------------------------------------------------- the matching

-- The roster names ONE set where the leader often meant any of several: a monster set
-- asked for at a single piece is worn for its 1 piece bonus, and every set granting that
-- same bonus does the job (#399). The site ships the rest of the class as `alt`, so the
-- only thing that widens is which set ids are looked at. Weight, trait and weapon type
-- belong to the slot and are never swapped.
local function SetOk( demand, itemSetId )
	if SetMatches( itemSetId, demand.set ) then return true end
	for _, altId in ipairs( demand.alt or {} ) do
		if SetMatches( itemSetId, altId ) then return true end
	end
	return false
end

-- What the roster asks of a slot (trait, weight, weapon type) belongs to the SLOT. What
-- it asks of a set (how many pieces) belongs to the set. The sets are then dealt into
-- whatever slots the player actually owns, keeping the counts intact.
-- A refusal names its reason, which only the debug trace (#483) reads.
local function CandidateOk( demand, slotId, item, req )
	if not SetOk( demand, item.setId ) then return false, "not that set" end
	local want = req[ slotId ]
	-- Exact traits (owner, 2026-09-08): follow the roster to the letter, so an off-trait
	-- piece is a miss and the plan creates the right one. A mythic has one trait only.
	if want and want.trait and BTV.Setting( "exactTraits" ) and not item.mythic and item.trait ~= want.trait then
		return false, "off trait and exact traits is on"
	end

	if demand.kind == "weapon" then
		-- A weapon slot the sheet does not name stays empty. What is on a bar decides which
		-- skills work, so putting a weapon somewhere the leader left blank breaks the build
		-- rather than completing it. Body slots are the opposite case, below.
		if not want then return false, "the sheet left this weapon slot empty" end
		local accepts = WEAPON_SLOTS[ slotId ]
		if not accepts or not accepts[ item.equipType ] then return false, "this weapon does not fit that hand" end
		if want.eq and item.equipType ~= want.eq then return false, "one hander / two hander does not match the sheet" end
		if want.weapon and item.weaponType ~= WEAPONS[ want.weapon ] then return false, "not the weapon type the sheet asked for" end
		return true
	end

	-- rule 11: a body slot the sheet never named is still a body slot, and a set bonus counts
	-- PIECES, not positions (#413 W2). A sheet that seats twelve while the counts add to
	-- thirteen used to leave the thirteenth piece homeless with an empty waist right there,
	-- so an unnamed slot is now usable and simply carries no trait or weight requirement.
	-- Nothing is stolen by this: `order` tries a demand's own slot first, so the leader's
	-- intent still wins, and Solve only reaches an unnamed slot when a piece would otherwise
	-- go unworn.
	local equipType = ARMOR_SLOTS[ slotId ] or JEWELRY_SLOTS[ slotId ]
	if not equipType or item.equipType ~= equipType then return false, "does not go on that slot" end
	-- rule 5: a mythic's trait and weight are fixed by the game and there is only ever one
	-- of it, so the roster cannot ask anything of them. (Bag items only: the remote pool has
	-- links, not bag slots, so a missing mythic can still mis-tier.)
	if item.mythic then return true end
	-- rule 4 is overturned by #401: jewelry trait is a preference now and not a demand, so
	-- nothing is left to reject a piece of jewelry on. ScoreItem still puts the ring in the
	-- trait the leader asked for ahead of one that is not, and because Solve is a global
	-- max-weight matching rather than first-fit, a wrong trait only lands when nothing else
	-- fits. Accepted consequence: pieces of one set trade freely across neck and both rings.
	if JEWELRY_SLOTS[ slotId ] then return true end
	-- rule 1 is narrowed by rule 13: weight no longer rejects a piece HERE, because which slot
	-- a weight sits on is free to move. How MANY of each weight the build wears is not, and
	-- that is enforced as a budget on the item pick in Solve rather than slot by slot. An
	-- unnamed slot states no weight, so it neither asks for one nor spends the budget.
	return true
end

-- rule 13: the build keeps the same NUMBER of heavy, medium and light pieces the sheet asked
-- for. Seven medium on a tank is worse than any trait mistake, and total resistance, the
-- armor passives and Undaunted Mettle all count pieces rather than positions. What may move
-- is which slot each weight lands on.
local function WeightBudget( req )
	local budget = {}
	for slotId in pairs( ARMOR_SLOTS ) do
		local want = req[ slotId ]
		local weight = want and want.weight and WEIGHTS[ want.weight ]
		if weight then budget[ weight ] = ( budget[ weight ] or 0 ) + 1 end
	end
	return budget
end

-- The weight a placement would spend, or nil when it spends nothing. A mythic's weight is
-- the game's and not the roster's (rule 5), so it neither spends the budget nor can be
-- blocked by it; nor can an armor slot the sheet never named (rule 11), which states no
-- weight to spend against.
local function WeightCost( slotId, item, req )
	if not ARMOR_SLOTS[ slotId ] or item.mythic then return nil end
	local want = req[ slotId ]
	if not ( want and want.weight ) then return nil end
	return item.armorType
end

-- The slots a demand may occupy: its own, plus the ones it may re-slot into. Body and
-- weapons never trade (rule 3), and a weapon stays on its own bar.
local function GroupSlots( demand )
	if demand.kind == "body" then return BODY_ORDER end
	if demand.slot then return { demand.slot } end
	return {}
end

-- The ladder, widest rung first: the set the leader named (a stand in from its bonus class
-- scores nothing here, so an owned Valkyn Skoria is never passed over for a Kra'gh, #399),
-- then the slot's weight, then its trait, then its glyph, then item quality, then bag
-- priority. Each rung is spaced clear of everything below it, so a lower one only ever
-- breaks a tie among equals on the higher.
--
-- Trait and quality are preferences and never rejects (#401): a piece that is there gets
-- slotted, and this ranking is the whole of what keeps the right one from being passed over.
local function ScoreItem( demand, slotId, item, req )
	local score = ( item.rank or 0 )                  -- bag priority, 0 bank / 5 backpack / 10 worn
		+ ( item.quality or 0 ) * 200                 -- 0 trash .. 1000 legendary, over bag priority AND reach
	local want = req[ slotId ]
	-- rule 13: the weight the sheet asked for on THIS slot, ranked above trait because weight
	-- is resistance and trait is a few percent. The budget below guarantees the totals hold
	-- either way, so this is only about landing each weight where the leader put it.
	if want and want.weight and item.armorType == WEIGHTS[ want.weight ] then score = score + 30000 end
	if want and item.trait == want.trait then score = score + 10000 end
	-- The glyph the sheet asked for, under trait: a glyph is replaceable at a bench, a
	-- trait is not. A name the addon does not know scores nothing, so an old addon and a
	-- new payload (or the reverse) just fall back to not caring.
	local wantGlyph = want and want.glyph and GLYPHS[ want.glyph ]
	if wantGlyph and SameGlyph( item.glyph, wantGlyph ) then score = score + 5000 end
	if IsPerfectedFormOf( item.setId, demand.set ) then
		score = score + 105000                        -- an upgrade on what was asked for
	elseif item.setId == demand.set then
		score = score + 100000
	elseif IsPlainFormOf( item.setId, demand.set ) then
		score = score + 50000                         -- a downgrade, but better than a miss
	end
	-- Reach is the LOWEST rung now (owner, 2026-09-09: a purple in the open coffer was
	-- taken over the gold on an alt). The best piece wins wherever it sits; only between
	-- equal pieces does the one already in a bag win, and among remote pieces the place
	-- holding the most gear this import wants (ClusterPool): the fewest trips. #413's
	-- "never fetch what a bag already covers" holds only for equals.
	if item.remote then score = score - 100 + math.min( item.cluster or 0, 14 ) end
	-- A piece the plan would CREATE (#479) is under everything the player owns anywhere:
	-- it only ever fills a slot nothing owned could.
	if item.created then score = score - 3000000 end
	return score
end

-- What the debug trace (#483) calls a piece: its link and where it sits.
local function TraceName( item )
	return string.format( "%s (%s)", item.link or "?", item.remote and "elsewhere" or ( "bag " .. tostring( item.bag ) ) )
end

-- rule 8: global assignment, never first-fit. Left: the roster's demands. Right: the
-- physical slots those demands may occupy. Augmenting-path matching, with each demand's
-- proposed slot tried first so the roster's intent wins ties.
--
-- `trace`, when given, is filled with one entry per demand: every piece of that set the
-- matcher looked at per slot, with the reason it was refused or the score it got, and what
-- was placed (#483). Pieces of other sets are left out: "not that set" is the whole reason.
function BTV.Solve( demands, pool, req, trace )
	local order, cand = {}, {}
	for di, demand in ipairs( demands ) do
		order[ di ] = {}
		if demand.slot then table.insert( order[ di ], demand.slot ) end
		for _, slotId in ipairs( GroupSlots( demand ) ) do
			if slotId ~= demand.slot then table.insert( order[ di ], slotId ) end
		end

		local tried = trace and {}
		cand[ di ] = {}
		for _, slotId in ipairs( order[ di ] ) do
			local list = {}
			for _, item in ipairs( pool ) do
				local ok, why = CandidateOk( demand, slotId, item, req )
				if ok then table.insert( list, item ) end
				if tried and why ~= "not that set" then
					table.insert( tried, string.format( "%s: %s: %s", SLOT_NAME[ slotId ] or tostring( slotId ), TraceName( item ),
						ok and ( "score " .. ScoreItem( demand, slotId, item, req ) ) or why ) )
				end
			end
			table.sort( list, function( a, b ) return ScoreItem( demand, slotId, a, req ) > ScoreItem( demand, slotId, b, req ) end )
			cand[ di ][ slotId ] = list
		end
		if trace then trace[ di ] = { demand = DemandLabel( demand, req ), tried = tried, placed = "nothing" } end
	end

	local ofSlot = {}
	local function Augment( di, seen )
		for _, slotId in ipairs( order[ di ] ) do
			if not seen[ slotId ] and #cand[ di ][ slotId ] > 0 then
				seen[ slotId ] = true
				if ofSlot[ slotId ] == nil or Augment( ofSlot[ slotId ], seen ) then
					ofSlot[ slotId ] = di
					return true
				end
			end
		end
		return false
	end

	-- rule 6: a piece beyond the set's own cap buys the player nothing, so it must never
	-- take a slot another set still needs for a bonus it can actually reach. Everything
	-- within cap is matched first; the surplus takes what is left, if anything.
	local cap, nth, core, surplus, isSurplus = {}, {}, {}, {}, {}
	-- A created piece (#479) has no link to read a cap from, so it neither sets nor erases one.
	for _, item in ipairs( pool ) do
		if item.maxEquipped then cap[ item.setId ] = item.maxEquipped end
	end
	for di, demand in ipairs( demands ) do
		nth[ demand.set ] = ( nth[ demand.set ] or 0 ) + 1
		if cap[ demand.set ] and nth[ demand.set ] > cap[ demand.set ] then
			isSurplus[ di ] = true
			table.insert( surplus, di )
		else
			table.insert( core, di )
		end
	end

	-- rule 9: most constrained first. A monster set fits two slots and a mythic one, so
	-- they choose before a five-piece set that has the whole body to go at.
	local reach = {}
	for di = 1, #demands do
		reach[ di ] = 0
		for _, slotId in ipairs( order[ di ] ) do
			if #cand[ di ][ slotId ] > 0 then reach[ di ] = reach[ di ] + 1 end
		end
	end
	table.sort( core, function( a, b )
		if reach[ a ] ~= reach[ b ] then return reach[ a ] < reach[ b ] end
		return a < b
	end )

	for _, di in ipairs( core ) do Augment( di, {} ) end
	for _, di in ipairs( surplus ) do Augment( di, {} ) end

	local slotOf = {}
	for slotId, di in pairs( ofSlot ) do slotOf[ di ] = slotId end

	-- rule 10: two 1 piece demands whose classes overlap must resolve to two DIFFERENT
	-- sets. Two pieces of one monster set is that set's 2 piece proc, not the two separate
	-- 1 piece bonuses the roster asked for, so the second demand goes without rather than
	-- quietly buying the player nothing (#399).
	--
	-- ponytail: greedy pick of the concrete item once the slot is decided. Only ring 1 /
	-- ring 2 and the two weapon bars can want the same item, and a class can only ever hold
	-- two demands (a monster head and a monster shoulder), so first-fit inside a pair is
	-- enough. The slot matching upstream does not know about either rule, so a pathological
	-- bag can still lose a piece it could in principle have placed. Upgrade to min-cost
	-- flow if a real bag ever proves otherwise.
	--
	-- rule 13 rides here too: the weight budget is spent as each concrete piece is chosen, so
	-- the build can never wear more of a weight than the sheet asked for. Every named armor
	-- slot that fills spends exactly one, so filling them all reproduces the asked-for totals
	-- exactly; a slot left empty is a shortfall, and MissLine says the weight ran out.
	local budget = WeightBudget( req )
	local used, placed, claimedSet = {}, {}, {}
	-- Spent with the rest of the build in mind (owner trace, 2026-09-15): a demand re-slotted
	-- onto a slot whose asked weight is not its own scores its copy in THAT weight first, and
	-- taking it can leave a later piece with no allowance while another weight sits unused.
	-- So a pick only stands if the demands still to place can each find a weight that is
	-- left: a demand whose every unused candidate costs one weight claims one of that weight.
	-- ponytail: counts only single-weight demands; a demand with copies in two scarce
	-- weights can still be missed. Upgrade to a real matching over weights if a bag shows it.
	local function LeavesEnough( after )
		local claims = {}
		for dj = after + 1, #demands do
			local slotJ = slotOf[ dj ]
			if slotJ then
				local only, several = nil, false
				for _, item in ipairs( cand[ dj ][ slotJ ] ) do
					if not used[ item ] then
						local cost = WeightCost( slotJ, item, req )
						if not cost then several = true break end
						if only and only ~= cost then several = true break end
						only = cost
					end
				end
				if only and not several then claims[ only ] = ( claims[ only ] or 0 ) + 1 end
			end
		end
		for weight, count in pairs( claims ) do
			if count > ( budget[ weight ] or 0 ) then return false end
		end
		return true
	end
	for di = 1, #demands do
		local slotId = slotOf[ di ]
		if slotId then
			local demand = demands[ di ]
			-- A shortfall that is there before this pick is not this pick's doing, and refusing
			-- it cures nothing: it only empties the rest of the setup (owner, 2026-09-18).
			local shortAlready = not LeavesEnough( di )
			for _, item in ipairs( cand[ di ][ slotId ] ) do
				local cost = WeightCost( slotId, item, req )
				local fits = false
				if not used[ item ] and not ( demand.alt and claimedSet[ item.setId ] )
					and ( not cost or ( budget[ cost ] or 0 ) > 0 ) then
					-- Spent for the look-ahead; given back when the pick does not stand.
					used[ item ] = true
					if cost then budget[ cost ] = budget[ cost ] - 1 end
					fits = shortAlready or LeavesEnough( di )
					if not fits then
						used[ item ] = nil
						if cost then budget[ cost ] = budget[ cost ] + 1 end
					end
				end
				if fits then
					if demand.alt then claimedSet[ item.setId ] = true end
					placed[ di ] = { slot = slotId, item = item }
					break
				end
			end
		end
	end
	-- rule 16: rule 11 promises the leader's layout wins, but the matching counts slots and
	-- not the weight budget, so it can move a demand off its own slot to a re-slot the budget
	-- then refuses (owner trace, 2026-10-28: one Trainee took the chest the sheet gave
	-- Sergeant's Mail, Sergeant's heavy legs found no heavy left, and the plan then made a
	-- second Trainee). So a demand that went without takes its own slot back from one that
	-- only re-slotted there: one in, one out, and the one out is the plan's to create.
	-- ponytail: one swap per demand, no chains; a budget-aware matching if a bag ever needs it.
	local holder = {}
	for dj, hit in pairs( placed ) do holder[ hit.slot ] = dj end
	for di, demand in ipairs( demands ) do
		local own = demand.slot
		local dj = own and holder[ own ]
		if dj and not placed[ di ] and not isSurplus[ di ] and demand.kind == "body" and not demand.alt
			and demands[ dj ].slot ~= own and not demands[ dj ].alt then
			local out = placed[ dj ].item
			local refund = WeightCost( own, out, req )
			if refund then budget[ refund ] = budget[ refund ] + 1 end
			for _, item in ipairs( cand[ di ][ own ] ) do
				local cost = WeightCost( own, item, req )
				if not used[ item ] and ( not cost or ( budget[ cost ] or 0 ) > 0 ) then
					if cost then budget[ cost ] = budget[ cost ] - 1 end
					used[ out ], used[ item ] = nil, true
					placed[ di ], placed[ dj ], holder[ own ] = { slot = own, item = item }, nil, di
					break
				end
			end
			if placed[ dj ] and refund then budget[ refund ] = budget[ refund ] - 1 end
		end
	end
	-- rule 15: two sets trade slots for quality alone (owner, 2026-09-15). The sheet's
	-- layout is the deal the matching found, and the pick takes the best copy per slot, but
	-- nothing above adds quality up across the build: set X's purple hands stay on when set
	-- Y's gold hands and set X's gold ring are both owned. So placed body and jewelry pieces
	-- are tried in pairs, and the pair trades slots when the piece entering each slot has
	-- the same weight, trait and glyph as the piece leaving it (the budget, the traits and
	-- the glyphs the build gets are untouched) and the two together gain quality. Mythics
	-- and stand-in demands (alt) stay put: one is game-fixed, the other has its own claims.
	-- ponytail: pairs only; a trade that needs three pieces to rotate is missed.
	local function Same( a, b )
		return a.armorType == b.armorType and a.trait == b.trait and a.glyph == b.glyph
	end
	local function Better( di, slotId, leaving )
		for _, item in ipairs( cand[ di ][ slotId ] or {} ) do
			if not used[ item ] and not item.mythic and Same( item, leaving ) then return item end
		end
		return nil
	end
	local swapped = true
	while swapped do
		swapped = false
		for di = 1, #demands do
			local a = placed[ di ]
			if a and demands[ di ].kind == "body" and not demands[ di ].alt and not a.item.mythic and not a.pair then
				for dj = di + 1, #demands do
					local b = placed[ dj ]
					if b and demands[ dj ].kind == "body" and not demands[ dj ].alt and not b.item.mythic and not b.pair then
						local intoB, intoA = Better( di, b.slot, b.item ), Better( dj, a.slot, a.item )
						if intoB and intoA and intoB ~= intoA
							and ( intoB.quality or 0 ) + ( intoA.quality or 0 ) > ( a.item.quality or 0 ) + ( b.item.quality or 0 ) then
							used[ a.item ], used[ b.item ] = nil, nil
							used[ intoB ], used[ intoA ] = true, true
							placed[ di ], placed[ dj ] = { slot = b.slot, item = intoB }, { slot = a.slot, item = intoA }
							swapped = true
							break
						end
					end
				end
			end
		end
	end
	-- rule 14: the one shape the client may fall back on, and only where the site said it may.
	-- A two-handed staff is two set pieces on its bar and so is a one-hander plus a shield, so
	-- the counts are untouched; the site has already read that bar's skills and will not set
	-- `shieldOk` where they need the staff in hand. Run after the pick rather than inside it,
	-- because the staff is always the better answer wherever the player owns one, and this is
	-- the last thing tried before a bar goes empty.
	local taken = {}
	for _, hit in pairs( placed ) do taken[ hit.slot ] = true end
	for di, demand in ipairs( demands ) do
		local want = demand.slot and req[ demand.slot ]
		local off = OFF_HAND_OF[ demand.slot or 0 ]
		if not placed[ di ] and demand.kind == "weapon" and want and want.shieldOk and off and not taken[ off ] then
			local main, shield
			for _, item in ipairs( pool ) do
				if not used[ item ] and SetOk( demand, item.setId ) then
					if not main and item.equipType == EQUIP_TYPE_ONE_HAND then main = item
					elseif not shield and item.weaponType == WEAPONTYPE_SHIELD then shield = item end
				end
			end
			if main and shield then
				used[ main ], used[ shield ] = true, true
				taken[ demand.slot ], taken[ off ] = true, true
				-- One demand, two pieces: the pair rides on the placement rather than becoming a
				-- placement of its own, so "N of M placed" still counts demands.
				placed[ di ] = { slot = demand.slot, item = main, pair = { slot = off, item = shield } }
			end
		end
	end

	if trace then
		for di, hit in pairs( placed ) do
			trace[ di ].placed = string.format( "%s in %s%s", TraceName( hit.item ), SLOT_NAME[ hit.slot ] or tostring( hit.slot ),
				hit.pair and ( " with " .. TraceName( hit.pair.item ) .. " in " .. ( SLOT_NAME[ hit.pair.slot ] or "?" ) ) or "" )
		end
		for di in pairs( isSurplus ) do trace[ di ].placed = trace[ di ].placed .. " (beyond the set's cap)" end
	end

	-- `used` goes back too: the miss lines have to tell "you own no more" apart from "you own
	-- more, and this build is already wearing them" (#413 W2). `budget` goes back as what is
	-- LEFT, which is what tells a lost slot contest apart from a spent weight allowance.
	return placed, isSurplus, used, budget
end

-- ------------------------------------------------------- payload -> demands

-- The payload keeps the two halves apart on purpose (#337): `gear` is the leader's
-- per-slot proposal and `sets` is what actually has to be worn. Counts are canonical, the
-- sheet is a hint (#352).
--
-- A hint past its set's count still leaves its requirement on the slot, so whatever
-- re-slots in there inherits the trait and weight the leader asked for. A count with no
-- hint left to claim becomes an unpinned body demand: it may take any body slot the
-- roster uses, which is the most the addon can honestly say about it.
function BTV.ParseSetup( entry, warn )
	local req, hintsOf = {}, {}
	for _, hint in ipairs( entry.gear or {} ) do
		local slotId = hint.slot
		if not SlotKind( slotId ) then
			warn( string.format( "unknown slot %s, hint skipped", tostring( slotId ) ) )
		elseif hint.weight and not WEIGHTS[ hint.weight ] then
			warn( string.format( "unknown weight '%s', hint skipped", tostring( hint.weight ) ) )
		elseif hint.weapon and not WEAPONS[ hint.weapon ] then
			warn( string.format( "unknown weapon '%s', hint skipped", tostring( hint.weapon ) ) )
		else
			-- `set` is the sheet's literal ask for the slot, which the missing-gear plan
			-- names where it departs from it (#479). The matcher never reads it.
			req[ slotId ] = { trait = hint.trait, weight = hint.weight, weapon = hint.weapon, eq = hint.eq,
				shieldOk = hint.shieldOk, glyph = hint.glyph, set = hint.set }
			hintsOf[ hint.set ] = hintsOf[ hint.set ] or {}
			table.insert( hintsOf[ hint.set ], slotId )
		end
	end

	local demands = {}
	for _, want in ipairs( entry.sets or {} ) do
		local hints = hintsOf[ want.id ] or {}
		-- A count is set-bonus PIECES, not items, and a two-handed weapon (greatsword,
		-- bow, staff) is worth two of them. So one bow already satisfies a count of 2, and
		-- counting demands as items invents a second piece the player can never own: it
		-- has no hint left, becomes an unpinned body demand, and for a weapon-only set
		-- there is no body piece in existence to satisfy it.
		-- The bonus class rides on every demand for the set, so an unpinned one can stand a
		-- class member in just as a hinted one can (#399). The site only sends `alt` for a
		-- monster set asked for at a single piece, so there is only ever one of them.
		-- rule 12, from the alpha's Ossein Cage run. Only the bar you are STANDING on grants a
		-- weapon's set bonus, so the two bars are alternatives and not additions: three body
		-- pieces plus an ice staff on each bar is five on whichever bar you are on, not seven.
		-- Body and jewellery plus ONE bar is what the count caps; the second bar is free to
		-- take the total past it, which is the whole reason a support runs a set on both bars
		-- instead of an arena weapon. Summing the pair silently dropped the back bar copy of
		-- every such set, and the sheet-seats warning below then blamed the leader for it.
		local body, bar, used = 0, { 0, 0 }, 0
		for _, slotId in ipairs( hints ) do
			local barId = WEAPON_BAR[ slotId ]
			-- A weapon is measured against its own bar. A body piece counts on both, so it is
			-- measured against the fuller one: it is what that bar still needs that decides.
			local have = body + ( barId and bar[ barId ] or math.max( bar[ 1 ], bar[ 2 ] ) )
			-- Skipped rather than `break`: a body hint the count has no room for must not cut
			-- off the back bar weapon hint that comes after it in slot order.
			if have < want.count then
				table.insert( demands, { set = want.id, alt = want.alt, slot = slotId, kind = SlotKind( slotId ) } )
				local worth = ( req[ slotId ].eq == EQUIP_TYPE_TWO_HAND and 2 or 1 )
				if barId then bar[ barId ] = bar[ barId ] + worth else body = body + worth end
				used = used + 1
			end
		end
		-- Whatever the sheet did not seat still travels, unpinned (#352). Counted across
		-- BOTH bars: a lead writes "Torug's Pact 4" for two daggers and a greatsword, items
		-- not bonus reach, and reading that as one bar's reach invented two body demands
		-- the plan then created (owner hand test 2026-09-08). Only pieces the sheet never
		-- seated at all are a shortfall.
		local covered = body + bar[ 1 ] + bar[ 2 ]
		for _ = covered + 1, want.count do
			table.insert( demands, { set = want.id, alt = want.alt, slot = nil, kind = "body" } )
		end
		if #hints > used then
			-- A stale or over-seated sheet (#355). The count wins.
			warn( string.format( "%s: sheet seats %d, roster asks %d, using %d",
				SetLabel( want.id ), #hints, want.count, used ) )
		end
	end
	return demands, req
end

-- ----------------------------------------------------------- payload -> WW

-- WW keys a setup's auto-swap on a boss NAME string, localized at load. The payload
-- carries the INDEX and the addon resolves the live name, so the condition is correct in
-- every language by construction (#349).
--
-- One row can bind to more than one WW entry: our Yokedas is two of WW's. WW's condition
-- holds a single boss, so each binding gets its own WW row.
local function ConditionsFor( zone, condition )
	local out = {}
	if not condition then return out end
	for _, bossIndex in ipairs( condition.bosses or {} ) do
		local boss = zone.bosses[ bossIndex ]
		if boss then table.insert( out, { boss = boss.name } ) end
	end
	if condition.trash then
		local trash = zone.bosses[ condition.trash ]
		-- WW recognises a trash condition by the boss name being its own trash string, and
		-- scopes it by `trash`, which is the NAME of the boss you last fought. `after` names
		-- that boss by index, so several trash setups coexist, one per stretch of the run
		-- (#403). No `after` is the trash before the first boss: the everywhere scope, which
		-- is also what WW falls back to for any boss no trash setup claims.
		if trash and not condition.after then
			table.insert( out, { boss = trash.name, trash = WW.CONDITIONS.EVERYWHERE } )
		elseif trash then
			-- An index we cannot resolve is dropped rather than falling back to everywhere,
			-- which would put this trash on a scope another setup already owns.
			for _, bossIndex in ipairs( condition.after ) do
				local boss = zone.bosses[ bossIndex ]
				if boss then table.insert( out, { boss = trash.name, trash = boss.name } ) end
			end
		end
	end
	return out
end

-- A scribed grimoire's ability id changes with the scripts scribed into it, so the id the
-- site recorded is one player's variant and WW refuses to slot anyone else's: its
-- SKILLS_DATA_MANAGER lookup returns nothing and it logs "Scribed Skill not switched".
-- The game maps any variant back to the grimoire and the grimoire to this player's own
-- version, so the payload never has to know about scripts at all (#348).
local function ResolveScribed( abilityId )
	if not abilityId or abilityId == 0 then return abilityId end
	local grimoire = GetAbilityCraftedAbilityId( abilityId )
	if grimoire == 0 then return abilityId end
	-- 0 means the player has not unlocked it. Keep the site's id so WW says so itself.
	local mine = GetAbilityIdForCraftedAbilityId( grimoire )
	if mine == 0 then return abilityId end
	return mine
end

-- Whether the player can actually slot this ability (#478): the import never writes a
-- skill they do not own. A scribed variant counts as learned once its grimoire is
-- unlocked, because ResolveScribed swaps in the player's own version at write. Everything
-- else goes through SKILLS_DATA_MANAGER, the same surface WW slots from: the skill is
-- purchased and this id is the morph the player chose. The exact morph/rank semantics
-- are this increment's hand-test item in game.
function BTV.IsAbilityLearned( abilityId )
	if not abilityId or abilityId == 0 then return false end
	local grimoire = GetAbilityCraftedAbilityId( abilityId )
	if grimoire ~= 0 then return GetAbilityIdForCraftedAbilityId( grimoire ) ~= 0 end
	local data = SKILLS_DATA_MANAGER and SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId( abilityId )
	if not data then return false end
	local skill = data:GetSkillData()
	if not skill:IsPurchased() then return false end
	local current = skill:GetCurrentProgressionData()
	return current == data or ( current ~= nil and current:GetAbilityId() == abilityId )
end

-- One flex slot's identity is its CONTENT, not its position (#478): one pick fills every
-- setup whose flex slot carries the same note and options.
local function FlexKey( spec )
	return ( spec.note or "" ) .. "\1" .. table.concat( spec.options or {}, "," )
end

-- The payload keys flex like skills, by string bar and slot. pairs() order is not
-- stable and the blocks end up on screen, so they are walked in bar/slot order.
local FLEX_BARS = { "0", "1" }
local FLEX_SLOTS = { "3", "4", "5", "6", "7", "8" }

local function BuildSetup( entry, name, placed, warn, depart )
	local setup = Setup:New()
	setup:SetName( name or "BTV" )

	local skills = { [ 0 ] = {}, [ 1 ] = {} }
	for hotbar = 0, 1 do
		local bar = entry.skills and entry.skills[ tostring( hotbar ) ] or {}
		for slot = 3, 8 do
			skills[ hotbar ][ slot ] = ResolveScribed( bar[ tostring( slot ) ] )
		end
	end
	setup:SetSkills( skills )

	-- Concrete {id, link} gear, so WW never has to guess (#345).
	--
	-- A piece that is not in a bag this client can address has no unique id, so its slot
	-- carries the real link and a placeholder (#413). WW then fails its inventory lookup and
	-- logs its own "Could not find <item> in your inventory!" at swap time, which is the
	-- truth, and which an empty slot never said: WW skips a slot it holds nothing for, and
	-- with "unequip empty slots" on it strips whatever was there instead.
	--
	-- Never "0". WW.GetItemLocation has no empty-slot check, so every empty bag slot maps to
	-- id "0" and WW would equip whatever the last empty slot resolves to. Id64ToString only
	-- ever returns digits, so a non-numeric id cannot collide with a real one.
	local gearTable = { mythic = nil }
	local function Wear( hit )
		gearTable[ hit.slot ] = {
			id = hit.item.remote and ( "btv-elsewhere-" .. hit.slot )
				or Id64ToString( GetItemUniqueId( hit.item.bag, hit.item.slot ) ),
			link = hit.item.link,
		}
		-- Only ever a bag item: a remote piece carries no mythic flag, and recording one as
		-- the setup's mythic would have WW unequip the worn mythic to make room for a piece
		-- that is not there.
		if hit.item.mythic then gearTable.mythic = hit.slot end
	end
	for _, hit in pairs( placed ) do
		Wear( hit )
		-- rule 14: the shield half of a shape swap. One demand, two hands.
		if hit.pair then Wear( hit.pair ) end
	end
	setup:SetGear( gearTable )

	-- CP is not in the payload (out of scope on #334), so the slot stays the player's.
	setup:SetCP( {} )

	local foodId = 0
	if entry.food then
		-- The payload names ONE item, but it means that item's whole buff class (#400):
		-- WW already groups every recipe granting the same food buff, and FindFood takes
		-- the list and eats whichever the player actually carries.
		local foodIndex = WW.FindFood( WW.lookupBuffFood[ WW.BUFFFOOD[ entry.food ] ] or { entry.food } )
		if foodIndex then
			local foodLink = GetItemLink( BAG_BACKPACK, foodIndex, LINK_STYLE_DEFAULT )
			local eaten = GetItemLinkItemId( foodLink )
			foodId = eaten
			setup:SetFood( { link = foodLink, id = eaten } )
			-- The buff class was what the leader meant, but the recipe in the bag is not the
			-- one the roster named, so say which one is actually being eaten (#402).
			if eaten ~= entry.food then
				depart( string.format( "%s -> %s", ItemName( entry.food ), CleanName( GetItemLinkName( foodLink ) ) ) )
			end
		else
			warn( "food not in backpack, none set" )
		end
	end

	-- The raw tables ride back beside the Setup object: the page fingerprint is computed
	-- from them (#477), so it never has to read another addon's class internals back.
	return setup, { gear = gearTable, skills = skills, food = foodId }
end

-- What the client did instead of what the roster said (#402). Four departures are successes
-- rather than misses, and the player is owed a line for each: a set stood in from its 1
-- piece bonus class (#399), a plain piece for a perfected demand (#401), an off-trait piece
-- (#401), and the food case, which is raised from BuildSetup because only WW knows which
-- recipe it found. A perfected piece standing in for a plain demand is an upgrade and is not
-- reported. Quality is never reported: the roster has no quality field, so a quality choice
-- can never be a departure from it.
local function DepartureLine( demand, hit, req )
	local item = hit.item
	if IsPlainFormOf( item.setId, demand.set ) then
		return string.format( "%s -> %s, not perfected", SetLabel( demand.set ), SetLabel( item.setId ) )
	end
	if item.setId ~= demand.set and not IsPerfectedFormOf( item.setId, demand.set ) then
		return string.format( "%s -> %s, same 1 piece bonus", SetLabel( demand.set ), SetLabel( item.setId ) )
	end
	-- rule 5: a mythic's trait is the game's, not the roster's to ask for, so a mismatch
	-- there is not a departure from anything.
	local want = req[ hit.slot ]
	if want and want.trait and want.trait > 0 and item.trait ~= want.trait and not item.mythic then
		-- Tagged, because trait is the cheap departure and the noisy one: the alpha's Ossein
		-- Cage run had 32 of these against 1 of everything else, and they buried the misses.
		-- Counted in the report and listed on demand instead.
		return string.format( "%s %s: asked %s, used %s", SetLabel( item.setId ),
			SLOT_NAME[ hit.slot ] or tostring( hit.slot ), TraitName( want.trait ), TraitName( item.trait ) ), "trait"
	end
	return nil
end

-- rule 13's report. A weight that moved between two slots worth the same resistance costs the
-- build nothing, so it is silent: head to feet is the same number either way. One that changes
-- the build's TOTAL resistance is the last resort before an empty slot, and it is said with
-- the number, per slot, so the player can judge it rather than take our word for it.
local function WeightMoves( demands, placed, req )
	local moved, net = {}, 0
	for di = 1, #demands do
		local hit = placed[ di ]
		local resist = hit and ARMOR_RESIST[ hit.slot ]
		local want = hit and req[ hit.slot ]
		local asked = want and want.weight and WEIGHTS[ want.weight ]
		if resist and asked and not hit.item.mythic and hit.item.armorType ~= asked then
			local delta = ( resist[ hit.item.armorType ] or 0 ) - ( resist[ asked ] or 0 )
			net = net + delta
			table.insert( moved, string.format( "|cF8FF70Risky weight|r %s %s: asked %s, used %s, %s%d resistance",
				SetLabel( hit.item.setId ), SLOT_NAME[ hit.slot ] or tostring( hit.slot ),
				NameOf( WEIGHTS, asked ), NameOf( WEIGHTS, hit.item.armorType ),
				delta > 0 and "+" or "", delta ) )
		end
	end
	-- The moves cancelled out, so the build wears exactly the resistance the leader wrote and
	-- there is nothing to tell anyone about (rule 13, the free case).
	if net == 0 then return {} end
	return moved
end

-- rule 13: the piece is there and it fits, but wearing it would cost the build a weight it has
-- none of left to give. The slots did not run out, the weight allowance did, and saying "no
-- free slot" for that would send the player looking in the wrong place. Only reached when
-- EVERY slot the piece fits is blocked that way: one free option anywhere means it lost an
-- ordinary contest instead.
local function WeightBlocked( demand, req, items, budget )
	local blocked
	for _, item in ipairs( items ) do
		for _, slotId in ipairs( GroupSlots( demand ) ) do
			if CandidateOk( demand, slotId, item, req ) then
				local cost = WeightCost( slotId, item, req )
				if not cost or ( budget[ cost ] or 0 ) > 0 then return nil end
				blocked = blocked or cost
			end
		end
	end
	return blocked
end

local function Fits( demand, req, items )
	for _, item in ipairs( items ) do
		for _, slotId in ipairs( GroupSlots( demand ) ) do
			if CandidateOk( demand, slotId, item, req ) then return item end
		end
	end
	return nil
end

-- A demand can fail on SHAPE rather than on ownership, and until #402 nothing said so: the
-- ownership tiers re-asked IIfA the same question with the same requirement, so a piece
-- sitting in the player's own backpack in the wrong armor weight fell all the way through to
-- "not on any of your characters". Weight and weapon type are the two axes worth saying out
-- loud, because both mean the player owns the right thing in the wrong form. A mismatched
-- equip type just means they own a different piece of the set, which is the ordinary miss.
-- Trait is not here: #401 made it a preference, so it can no longer fail a demand.
-- rule 9: the CLOSEST shape owned, not the first one that turns up. The alpha's Ossein Cage
-- run said "have sword, need frost" at a player who owned a Lightning Staff of Alkosh in the
-- same bag: the staff is one drop away and would still be two set pieces on that bar, the
-- sword is neither, and the report named the less useful of the two truths because it walked
-- the bag in bag order. A piece that at least fills the hand the same way ranks first.
local function ShapeMiss( demand, req, items )
	local best, bestScore
	for _, item in ipairs( items ) do
		if SetOk( demand, item.setId ) and not item.mythic then
			for _, slotId in ipairs( GroupSlots( demand ) ) do
				local want = req[ slotId ]
				-- Equip type is deliberately NOT filtered here (#413 W2). A player who owns the
				-- set only as a dagger, on a bar asking for a greatsword, owns the right set in
				-- the wrong form, which is exactly this message. Filtering on it dropped that
				-- case through to "on no character", which is a lie about a piece in their bag.
				if want and demand.kind == "weapon" and ( WEAPON_SLOTS[ slotId ] or {} )[ item.equipType ]
					and want.weapon and item.weaponType ~= WEAPONS[ want.weapon ] then
					local score = ( want.eq and item.equipType == want.eq ) and 1 or 0
					if not bestScore or score > bestScore then
						best, bestScore = string.format( "|cF8FF70Wrong shape|r %s (%s): have %s, need %s",
							SetLabel( item.setId ), SLOT_NAME[ slotId ] or tostring( slotId ),
							NameOf( WEAPONS, item.weaponType ), want.weapon ), score
					end
				end
				-- The armor-weight half of this is gone with rule 13: a piece in a weight the
				-- slot did not ask for is placeable now, so it is either worn or blocked by the
				-- weight budget, and `WeightBlocked` says so in the budget's own words.
			end
		end
	end
	return best
end

-- The failure kinds get different answers (#350, widened by #402). A setup always gets built
-- whatever could not be placed, so none of these stops anything.
--
-- "It is elsewhere" is no longer one of them (#413): a piece IIfA knows about is in the pool
-- like any other, so it gets PLACED and reported as something to fetch rather than missed.
-- Everything reaching here failed on shape or is genuinely nowhere.
local function MissLine( demand, req, pool, used, budget, known, complete, got, need )
	local label = DemandLabel( demand, req )

	-- Only pieces this build is not already wearing can answer for this demand. Asking the
	-- whole pool was the bug behind "4/5 owned, no more anywhere" printed at a player holding
	-- six of the set: the other five fit, they were just already on (#413 W2).
	local spare = {}
	for _, item in ipairs( pool ) do
		if not used[ item ] then table.insert( spare, item ) end
	end

	-- Asked before the slot contest, because a budget-blocked piece still "fits" as far as
	-- CandidateOk is concerned since rule 13 took weight out of it, and "no free slot" would
	-- send the player looking at their slots instead of their weights.
	local weight = WeightBlocked( demand, req, spare, budget )
	if weight then
		return string.format( "|cFF7070Weight full|r %s: you own it in %s, and this build has no %s left to give.",
			label, NameOf( WEIGHTS, weight ), NameOf( WEIGHTS, weight ) ), "weight"
	end

	-- A spare piece that fits somewhere means the slots ran out, not the gear.
	if Fits( demand, req, spare ) then
		return string.format( "|cF8FF70No free slot|r %s: you own another, every slot it fits is taken.", label ), "noslot"
	end
	local shape = ShapeMiss( demand, req, spare )
	if shape then return shape, "shape" end

	if known and complete then
		if got > 0 then
			return string.format( "|cFF7070Missing|r %s: %d/%d owned, |cFF0000no more anywhere|r. Obtain or craft.",
				label, got, need ), "nowhere"
		end
		return string.format( "|cFF7070Missing|r %s: |cFF0000on no character|r. Obtain or craft.", label ), "nowhere"
	end
	if got > 0 then
		return string.format( "|cF8FF70Unknown|r %s: %d/%d owned, rest unknown. IIfA has not seen every character.",
			label, got, need ), "unknown"
	end
	return string.format( "|cF8FF70Unknown|r %s: not in your bags. IIfA has not seen every character.",
		label ), "unknown"
end

-- ------------------------------------------------------ the missing-gear plan

-- A piece nobody on the account owns gets a plan instead of "obtain or craft it" (#479,
-- decided in #468, #469, #470). The site ships, per setup, the substitution space: which
-- slots and weights a piece of each set may legally be created in. The addon runs a small
-- generic solver over it against the bags: add created pieces to the shared pool until
-- every setup places everything, creating as FEW pieces as possible roster-wide, because
-- a created piece exists once and serves every setup that can seat it. Per setup the
-- matcher's own rules still hold (weights fixed in total, weapon shapes as written,
-- counts per bar), since the plan is nothing but BTV.Solve run with extra pool items.
--
-- The four ways to get a piece, ranked for the tie-break #469 locked: craft, then a
-- reconstruction the player can pay for, then farm, then a craft this character lacks
-- the research for, then a reconstruction they cannot pay for. Buy is never pre-picked,
-- so it ranks last and only ever shows as an alternative.
local PATH_RANK = { craft = 1, reconstruct = 2, farm = 3, craftPoor = 4, reconstructPoor = 5, buy = 9 }

-- Which research line a piece sits on, per crafting type. Trait research is readable
-- anywhere (#468) but only by line index, and the game names lines in the client's
-- language, so the index is the honest key. The order is the game's fixed one, verified
-- against two independent addons that hard-code the same tables (CarosSkillPointSaver
-- csps_gearcraft.lua, WritWorthy WritWorthy_Smithing.lua); the in-game hand test
-- confirms it once more.
local WEAPON_LINE = {
	[ WEAPONTYPE_AXE ] = { CRAFTING_TYPE_BLACKSMITHING, 1 }, [ WEAPONTYPE_HAMMER ] = { CRAFTING_TYPE_BLACKSMITHING, 2 },
	[ WEAPONTYPE_SWORD ] = { CRAFTING_TYPE_BLACKSMITHING, 3 }, [ WEAPONTYPE_TWO_HANDED_AXE ] = { CRAFTING_TYPE_BLACKSMITHING, 4 },
	[ WEAPONTYPE_TWO_HANDED_HAMMER ] = { CRAFTING_TYPE_BLACKSMITHING, 5 }, [ WEAPONTYPE_TWO_HANDED_SWORD ] = { CRAFTING_TYPE_BLACKSMITHING, 6 },
	[ WEAPONTYPE_DAGGER ] = { CRAFTING_TYPE_BLACKSMITHING, 7 },
	[ WEAPONTYPE_BOW ] = { CRAFTING_TYPE_WOODWORKING, 1 }, [ WEAPONTYPE_FIRE_STAFF ] = { CRAFTING_TYPE_WOODWORKING, 2 },
	[ WEAPONTYPE_FROST_STAFF ] = { CRAFTING_TYPE_WOODWORKING, 3 }, [ WEAPONTYPE_LIGHTNING_STAFF ] = { CRAFTING_TYPE_WOODWORKING, 4 },
	[ WEAPONTYPE_HEALING_STAFF ] = { CRAFTING_TYPE_WOODWORKING, 5 }, [ WEAPONTYPE_SHIELD ] = { CRAFTING_TYPE_WOODWORKING, 6 },
}
-- Armor lines run chest, feet, hands, head, legs, shoulders, waist in every weight: light
-- is lines 1 to 7 at the clothier, medium the next seven there, heavy 8 to 14 at the
-- blacksmith (the first seven are its weapons).
local ARMOR_LINE = { [ EQUIP_TYPE_CHEST ] = 1, [ EQUIP_TYPE_FEET ] = 2, [ EQUIP_TYPE_HAND ] = 3, [ EQUIP_TYPE_HEAD ] = 4,
	[ EQUIP_TYPE_LEGS ] = 5, [ EQUIP_TYPE_SHOULDERS ] = 6, [ EQUIP_TYPE_WAIST ] = 7 }
local ARMOR_CRAFT = {
	[ ARMORTYPE_LIGHT ] = { CRAFTING_TYPE_CLOTHIER, 0 },
	[ ARMORTYPE_MEDIUM ] = { CRAFTING_TYPE_CLOTHIER, 7 },
	[ ARMORTYPE_HEAVY ] = { CRAFTING_TYPE_BLACKSMITHING, 7 },
}

local function ResearchLine( cand )
	if cand.weaponType then
		local line = WEAPON_LINE[ cand.weaponType ]
		if line then return line[ 1 ], line[ 2 ] end
	elseif cand.equipType == EQUIP_TYPE_RING then return CRAFTING_TYPE_JEWELRYCRAFTING, 1
	elseif cand.equipType == EQUIP_TYPE_NECK then return CRAFTING_TYPE_JEWELRYCRAFTING, 2
	else
		local craft, line = ARMOR_CRAFT[ cand.armorType ], ARMOR_LINE[ cand.equipType ]
		if craft and line then return craft[ 1 ], craft[ 2 ] + line end
	end
end

-- Trait research is per character, and the crafter is usually an alt (owner, 2026-09-08),
-- so every character's research is snapshotted into the account-wide SavedVariables when
-- it logs in, and a piece is judged against the best crafter the account has.
local CRAFTS = { CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_WOODWORKING, CRAFTING_TYPE_JEWELRYCRAFTING }
-- The material passive per craft (GetNonCombatBonus, as Dolgubon's writ creator reads it):
-- 10 is the top tier, the one that makes CP160 gear. And the improvement passive, read as
-- the tempers a guaranteed gold upgrade costs: 8 when maxed, up to 20 without it (the way
-- CarosSkillPointSaver judges it). Both are per character, so both are snapshotted with
-- the trait research (owner hand test 2026-09-09).
local TIER_BONUS = {
	[ CRAFTING_TYPE_BLACKSMITHING ] = NON_COMBAT_BONUS_BLACKSMITHING_LEVEL,
	[ CRAFTING_TYPE_CLOTHIER ] = NON_COMBAT_BONUS_CLOTHIER_LEVEL,
	[ CRAFTING_TYPE_WOODWORKING ] = NON_COMBAT_BONUS_WOODWORKING_LEVEL,
	[ CRAFTING_TYPE_JEWELRYCRAFTING ] = NON_COMBAT_BONUS_JEWELRYCRAFTING_LEVEL,
}
local TOP_TIER, GOLD_TEMPERS = 10, 8
-- Jewelry's material passive stops at 5: a crafter with every passive read 5 there and 10
-- on the other three (owner's SavedVariables, 2026-09-18).
local TOP_TIER_OF = { [ CRAFTING_TYPE_JEWELRYCRAFTING ] = 5 }

-- Why this character must not auto craft at a station, read live, or nil when it may: a
-- short material passive makes a piece under CP160, a short improvement passive burns tempers.
function BTV.CraftBlock( craft )
	if not craft or not TIER_BONUS[ craft ] then return nil end
	if ( GetNonCombatBonus( TIER_BONUS[ craft ] ) or 0 ) < ( TOP_TIER_OF[ craft ] or TOP_TIER ) then
		return "this character lacks the top material passive (CP160)"
	end
	local tempers = GetSmithingGuaranteedImprovementItemAmount( craft, ITEM_FUNCTIONAL_QUALITY_ARTIFACT or 4 ) or GOLD_TEMPERS
	if tempers > GOLD_TEMPERS then
		return string.format( "this character's improvement passive is not maxed (gold costs %d tempers, not %d)", tempers, GOLD_TEMPERS )
	end
end

function BTV.SnapshotResearch()
	if not BTV.svAccount then return end
	local snap = { name = CleanName( GetUnitName( "player" ) ), lines = {}, tier = {}, upgrade = {} }
	for _, craft in ipairs( CRAFTS ) do
		snap.tier[ craft ] = GetNonCombatBonus( TIER_BONUS[ craft ] ) or 0
		-- The game answers for the quality being improved FROM, so purple is what a gold
		-- upgrade costs (a maxed crafter read 0 tempers asked about gold, owner 2026-09-09).
		snap.upgrade[ craft ] = GetSmithingGuaranteedImprovementItemAmount( craft, ITEM_FUNCTIONAL_QUALITY_ARTIFACT or 4 ) or GOLD_TEMPERS
		for line = 1, GetNumSmithingResearchLines( craft ) or 0 do
			local _, _, numTraits = GetSmithingResearchLineInfo( craft, line )
			local known = {}
			for i = 1, numTraits or 0 do
				local traitType, _, isKnown = GetSmithingResearchLineTraitInfo( craft, line, i )
				if isKnown and traitType then known[ traitType ] = true end
			end
			snap.lines[ craft .. ":" .. line ] = known
		end
	end
	BTV.svAccount.research = BTV.svAccount.research or {}
	BTV.svAccount.research[ LocationKey( GetCurrentCharacterId() ) ] = snap
end

-- The best crafter for a piece: how many traits that character knows on the piece's
-- line, whether the asked trait is one of them (nil when none was asked), and the
-- character's name when it is not the one logged in. A character knowing the trait
-- beats one that does not, then one with enough traits for the set, then this
-- character, then the most traits.
local function Research( cand, needed )
	local craft, line = ResearchLine( cand )
	local asked = cand.trait and cand.trait > 0
	local canOn = {}
	if not craft or not line then return 0, asked and false or nil, nil, canOn end
	local key, here = craft .. ":" .. line, LocationKey( GetCurrentCharacterId() )
	local best, bestScore
	-- Characters with the research but not the top material passive: they would make a
	-- piece under CP160, so they are named instead of picked.
	local tierShort = {}
	for charId, snap in pairs( BTV.svAccount and BTV.svAccount.research or {} ) do
		local known = snap.lines and snap.lines[ key ] or {}
		local count = 0
		for _ in pairs( known ) do count = count + 1 end
		local traitKnown = nil
		if asked then traitKnown = known[ cand.trait ] == true end
		-- An older snapshot has no tier; it is read as fine until the character logs in
		-- again, and the craft line says so (block.crafter.unread).
		local tierOk = not ( snap.tier and snap.tier[ craft ] ) or snap.tier[ craft ] >= ( TOP_TIER_OF[ craft ] or TOP_TIER )
		-- Every character who could craft this piece today, for the one-crafter pick per set.
		if count >= ( needed or 0 ) and traitKnown ~= false then
			if tierOk then canOn[ charId ] = snap.name else tierShort[ charId ] = snap.name end
		end
		local score = ( traitKnown and 1000 or 0 ) + ( count >= ( needed or 0 ) and 100 or 0 )
			+ ( tierOk and 50 or 0 ) + ( charId == here and 10 or 0 ) + count
		if not bestScore or score > bestScore then
			best, bestScore = { count = count, traitKnown = traitKnown, name = charId ~= here and snap.name or nil, tierOk = tierOk }, score
		end
	end
	if not best then return 0, asked and false or nil, nil, canOn, tierShort end
	return best.count, best.traitKnown, best.name, canOn, tierShort, best.tierOk
end

-- Every collection piece of a set, read once: the game links a set's pieces without the
-- player owning any (PieceNames leans on the same call), and it is the one way to reach
-- the sticker book from a set and a shape.
local piecesOf = {}
local function CollectionPieces( setId )
	if piecesOf[ setId ] then return piecesOf[ setId ] end
	local pieces = {}
	for i = 1, GetNumItemSetCollectionPieces( setId ) do
		local pieceId = GetItemSetCollectionPieceInfo( setId, i )
		local link = pieceId and GetItemSetCollectionPieceItemLink( pieceId, LINK_STYLE_DEFAULT )
		if link and link ~= "" then
			table.insert( pieces, { pieceId = pieceId, link = link, equipType = GetItemLinkEquipType( link ),
				armorType = GetItemLinkArmorType( link ), weaponType = GetItemLinkWeaponType( link ) } )
		end
	end
	piecesOf[ setId ] = pieces
	return pieces
end

local function CollectionPiece( cand )
	for _, piece in ipairs( CollectionPieces( cand.setId ) ) do
		if piece.equipType == cand.equipType
			and ( not cand.armorType or piece.armorType == cand.armorType )
			and ( not cand.weaponType or piece.weaponType == cand.weaponType ) then
			return piece
		end
	end
end

local EQUIP_WORD = {
	[ EQUIP_TYPE_HEAD ] = "head", [ EQUIP_TYPE_CHEST ] = "chest", [ EQUIP_TYPE_SHOULDERS ] = "shoulders",
	[ EQUIP_TYPE_WAIST ] = "waist", [ EQUIP_TYPE_LEGS ] = "legs", [ EQUIP_TYPE_FEET ] = "feet",
	[ EQUIP_TYPE_HAND ] = "hands", [ EQUIP_TYPE_NECK ] = "neck", [ EQUIP_TYPE_RING ] = "ring",
}

-- The payload's weapon words, said the way the game names them (owner hand test
-- 2026-09-09: "Mechanical Acuity fire" read as nothing).
local WEAPON_WORD = {
	fire = "inferno staff", frost = "ice staff", lightning = "lightning staff", restoration = "restoration staff",
	greatsword = "greatsword", battleaxe = "battle axe", maul = "maul", bow = "bow", shield = "shield",
	sword = "sword", axe = "axe", mace = "mace", dagger = "dagger",
}

-- "head, medium" / "ring" / "inferno staff": the shape of a created piece in the roster's words.
local function ShapeWords( cand )
	if cand.weaponType then
		local word = NameOf( WEAPONS, cand.weaponType )
		return WEAPON_WORD[ word ] or word
	end
	local words = EQUIP_WORD[ cand.equipType ] or "piece"
	if cand.armorType then words = words .. ", " .. NameOf( WEIGHTS, cand.armorType ) end
	return words
end
BTV.ShapeWords = ShapeWords

-- Where a dropped set comes from, in LibSets' words: its zones, then the boss or the
-- drop mechanic per zone.
local function DropWhere( lib, setId )
	-- LibSets repeats a zone per drop mechanic and a mechanic per boss, so both lists are
	-- deduped or a trial set reads "Dreadsail Reef, Dreadsail Reef, Dreadsail Reef".
	local zones, how, seen = {}, {}, {}
	local function Once( list, text )
		if text and text ~= "" and not seen[ text ] then
			seen[ text ] = true
			table.insert( list, text )
		end
	end
	for _, zoneId in ipairs( lib.GetZoneIds( setId ) or {} ) do Once( zones, lib.GetZoneName( zoneId ) ) end
	local lang = lib.LangAllowedCheck and lib.LangAllowedCheck() or "en"
	local _, names, _, places = lib.GetDropMechanic( setId, true, lang )
	for i, entry in ipairs( names or {} ) do
		local place = places and places[ i ] and places[ i ][ lang ]
		if type( place ) == "table" then place = table.concat( place, ", " ) end
		local name = type( entry ) == "table" and entry[ lang ] or entry
		if place and place ~= "" then Once( how, place ) else Once( how, name ) end
	end
	local where = table.concat( zones, ", " )
	if #how > 0 then where = where .. ( where ~= "" and ": " or "" ) .. table.concat( how, ", " ) end
	if where == "" then return nil end
	return where
end

-- Where a crafted set's station is: the zone of each station wayshrine LibSets lists
-- (base-game sets have one per alliance). Not GetZoneIds: on the base-game sets it holds
-- a 4th zone with no station (UESP, 2026-10-14). A station with no wayshrine (Earth Forge,
-- Eyevea, Imperial City, Cyrodiil armories) or one LibSets maps to zone 0 (Blackreach)
-- falls back to the set's first zone.
local function StationWhere( lib, setId )
	local zones, seen = {}, {}
	for _, node in ipairs( lib.GetWayshrineIds( setId ) or {} ) do
		local zoneId = node > 0 and lib.GetWayshrinesZoneId( node ) or 0
		if zoneId == 0 then zoneId = ( lib.GetZoneIds( setId ) or {} )[ 1 ] or 0 end
		local name = zoneId ~= 0 and lib.GetZoneName( zoneId ) or ""
		if name ~= "" and not seen[ name ] then
			seen[ name ] = true
			table.insert( zones, name )
		end
	end
	if #zones == 0 then return nil end
	if #zones == 1 then return zones[ 1 ] end
	return table.concat( zones, ", ", 1, #zones - 1 ) .. " or " .. zones[ #zones ]
end

-- Everything a row on the Missing gear step says about one created piece (#468, #470),
-- all readable anywhere in the world: crafted or dropped and where it drops (LibSets),
-- whether the sticker book holds it, the live reconstruction cost against the crystal
-- balance, and this character's trait research. Paths come back in tie-break order.
local function Facts( cand )
	local lib = LibSets and LibSets.AreSetsLoaded() and LibSets or nil
	local setId = cand.setId
	local facts = { paths = {}, ranks = {} }
	local piece = CollectionPiece( cand )
	facts.name = piece and CleanName( GetItemLinkName( piece.link ) ) or nil
	if not facts.name or facts.name == "" then facts.name = SetLabel( setId ) .. " " .. ShapeWords( cand ) end
	local crafted = lib and lib.IsCraftedSet( setId ) or false
	if crafted then
		facts.traitsNeeded = lib.GetTraitsNeeded( setId ) or 0
		facts.station = StationWhere( lib, setId )
	end
	facts.known, facts.traitKnown, facts.crafter, facts.canOn, facts.tierShort, facts.tierOk = Research( cand, facts.traitsNeeded )
	if crafted then
		facts.canCraft = facts.known >= facts.traitsNeeded and facts.traitKnown ~= false and facts.tierOk ~= false
		table.insert( facts.paths, "craft" )
	end
	if piece then
		facts.unlocked = IsItemSetCollectionPieceUnlocked( piece.pieceId ) and true or false
		if facts.unlocked then
			facts.cost = GetItemReconstructionCurrencyOptionCost( setId, CURT_CHAOTIC_CREATIA ) or 0
			facts.balance = GetCurrencyAmount( CURT_CHAOTIC_CREATIA, GetCurrencyPlayerStoredLocation( CURT_CHAOTIC_CREATIA ) ) or 0
			facts.affordable = facts.balance >= facts.cost
			table.insert( facts.paths, "reconstruct" )
		end
	end
	if not crafted then
		facts.where = lib and DropWhere( lib, setId ) or nil
		table.insert( facts.paths, "farm" )
	end
	if crafted or ( lib and lib.IsOverlandSet( setId ) ) then table.insert( facts.paths, "buy" ) end
	for _, path in ipairs( facts.paths ) do
		local rank = PATH_RANK[ path ]
		if path == "reconstruct" and not facts.affordable then rank = PATH_RANK.reconstructPoor end
		if path == "craft" and not facts.canCraft then rank = PATH_RANK.craftPoor end
		facts.ranks[ path ] = rank
	end
	table.sort( facts.paths, function( a, b ) return facts.ranks[ a ] < facts.ranks[ b ] end )
	facts.path = facts.paths[ 1 ]
	facts.rank = facts.ranks[ facts.path ]
	return facts
end

-- One created piece a demand could be met with, at one slot in one weight. Its key is
-- its identity roster-wide: the same shape of the same set is one piece however many
-- setups want it.
local function Candidate( demand, setId, slotId, req, armorType, weaponType )
	local want = req[ slotId ]
	local equipType = ARMOR_SLOTS[ slotId ] or JEWELRY_SLOTS[ slotId ] or ( want and want.eq )
	if not equipType then return nil end
	-- `forSets` is the demand set(s) this piece answers, so a gap only ever offers pieces
	-- that stand in for the same demand, never one that fills a different gap.
	local cand = { setId = setId, slot = slotId, equipType = equipType, armorType = armorType, weaponType = weaponType,
		trait = want and want.trait, glyph = want and want.glyph, named = want ~= nil, forSets = { [ demand.set ] = true } }
	-- The sheet's own ask: this demand's set, on its own slot, in the weight it wrote.
	cand.literal = setId == demand.set and slotId == demand.slot
		and ( not armorType or ( want and want.weight and WEIGHTS[ want.weight ] == armorType ) ) or false
	cand.key = table.concat( { setId, equipType, armorType or 0, weaponType or 0 }, "|" )
	-- Two daggers of one set most often differ in trait and enchant (owner, 2026-09-14),
	-- so a weapon is keyed by those too: two pieces, two lines, each made in its own trait.
	if weaponType and weaponType > 0 then
		cand.key = cand.key .. "|" .. tostring( cand.trait or 0 ) .. "|" .. tostring( cand.glyph or "" )
	end
	return cand
end

-- Every legal created piece for one entry: for each demand, its set (or a class
-- member, #399), every slot the site's substitution space allows that the matcher would
-- let the demand take, every weight the set drops in. A weapon only as the sheet wrote
-- it, because what is on a bar decides which skills work. A set with no substitution
-- space (an older payload, or a set UESP does not list) offers only the sheet's own ask,
-- which is all "obtain or craft it" ever meant.
local function Candidates( review, into, byKey )
	local sub = review.entry and review.entry.sub or {}
	local function Keep( cand )
		if not cand then return end
		local held = byKey[ cand.key ]
		if held then
			held.literal = held.literal or cand.literal
			held.named = held.named or cand.named
			for setId in pairs( cand.forSets ) do held.forSets[ setId ] = true end
			return
		end
		byKey[ cand.key ] = cand
		table.insert( into, cand )
	end
	for di, demand in ipairs( review.demands ) do
		if not review.isSurplus[ di ] then
			local sets = { demand.set }
			for _, altId in ipairs( demand.alt or {} ) do table.insert( sets, altId ) end
			for _, setId in ipairs( sets ) do
				local space = sub[ tostring( setId ) ]
				if demand.kind == "weapon" then
					local want = demand.slot and review.req[ demand.slot ]
					if setId == demand.set and want and want.eq and want.weapon and WEAPONS[ want.weapon ] then
						Keep( Candidate( demand, setId, demand.slot, review.req, nil, WEAPONS[ want.weapon ] ) )
					end
				else
					local slots = {}
					if space then
						local allowed = {}
						for _, slotId in ipairs( space.slots or {} ) do allowed[ slotId ] = true end
						for _, slotId in ipairs( BODY_ORDER ) do
							if allowed[ slotId ] then table.insert( slots, slotId ) end
						end
					elseif demand.slot then
						slots = { demand.slot }
					end
					for _, slotId in ipairs( slots ) do
						if ARMOR_SLOTS[ slotId ] then
							-- The sheet's weight on a named slot is kept (owner, 2026-09-08: the lead
							-- chose heavy there for a reason); an unnamed slot takes any weight the
							-- set drops in. A set that never drops in the slot's weight offers nothing.
							local weights = {}
							local want = review.req[ slotId ]
							local asked = want and want.weight and WEIGHTS[ want.weight ]
							if space and space.weights then
								for _, name in ipairs( space.weights ) do
									if WEIGHTS[ name ] and ( not asked or WEIGHTS[ name ] == asked ) then table.insert( weights, WEIGHTS[ name ] ) end
								end
							elseif asked then
								weights = { asked }
							end
							for _, armorType in ipairs( weights ) do
								Keep( Candidate( demand, setId, slotId, review.req, armorType, nil ) )
							end
						else
							Keep( Candidate( demand, setId, slotId, review.req, nil, nil ) )
						end
					end
				end
			end
		end
	end
end

-- A created piece as the matcher sees it: no link, no bag, no cap, and never written.
local function CreatedItem( cand )
	return { setId = cand.setId, equipType = cand.equipType, armorType = cand.armorType, weaponType = cand.weaponType,
		trait = cand.trait, glyph = cand.glyph and GLYPHS[ cand.glyph ], quality = 0, created = true, key = cand.key, cand = cand }
end

-- How many non-surplus demands an entry places out of a pool, and which pool items it
-- wears where.
-- Whether any demand of an entry could wear a set at all, memoised per entry (#490).
local function Wants( review, setId )
	review.wants = review.wants or {}
	local ok = review.wants[ setId ]
	if ok == nil then
		ok = false
		for _, demand in ipairs( review.demands ) do
			if SetOk( demand, setId ) then ok = true break end
		end
		review.wants[ setId ] = ok
	end
	return ok
end

local function Placed( review, pool )
	-- #490: the pool is bags plus the whole IIfA cache; this entry can only ever wear the
	-- handful of sets it asks for, so every solve walks those alone.
	local mine = {}
	for _, item in ipairs( pool ) do
		if Wants( review, item.setId ) then table.insert( mine, item ) end
	end
	local placed = BTV.Solve( review.demands, mine, review.req )
	local count, worn = 0, {}
	for di, hit in pairs( placed ) do
		if not review.isSurplus[ di ] then
			count = count + 1
			worn[ hit.item ] = hit.slot
			if hit.pair then worn[ hit.pair.item ] = hit.pair.slot end
		end
	end
	return count, worn
end

-- The tie-break: the piece serving more setups, then the cheaper path (craft > affordable
-- reconstruct > farm), then the sheet's own ask, then a slot the sheet named at all,
-- then whichever came first.
local function Better( cand, gain, fit, best, bestGain, bestFit )
	if gain ~= bestGain then return gain > bestGain end
	-- Two created daggers fill the same two slots either way; the one made in the trait
	-- its slot asked for wins, or both end up in the first one's trait (owner, 2026-09-14).
	if fit ~= bestFit then return fit > bestFit end
	if cand.facts.rank ~= best.facts.rank then return cand.facts.rank < best.facts.rank end
	if cand.literal ~= best.literal then return cand.literal end
	if cand.named ~= best.named then return cand.named end
	return false
end

-- Lua runs on the game's frame, and a 23 setup roster planned long enough that the server
-- dropped the player (error 303, 2026-10-15). Run from a coroutine (BTV.RunSliced), the
-- plan hands the frame back every SLICE_MS with how far it got; called directly, as the
-- self check does, it never yields.
local SLICE_MS = 12
local sliceStart = 0
local function Pause( progress )
	local co, main = coroutine.running()
	if not co or main then return end
	if GetGameTimeMilliseconds() - sliceStart < SLICE_MS then return end
	coroutine.yield( progress )
end

-- Steps `work` one slice per frame: `onProgress( 0..1 )` after each slice, then
-- `onDone( ... )` with what `work` returned, or `( nil, why )` when it threw. One run at a
-- time: a new run, or BTV.CancelSliced, drops the last.
local SLICED = "BTVToolsSliced"
function BTV.CancelSliced()
	EVENT_MANAGER:UnregisterForUpdate( SLICED )
	BTV.sliced = nil
end

function BTV.RunSliced( work, onProgress, onDone )
	BTV.CancelSliced()
	local co = coroutine.create( work )
	BTV.sliced = co
	EVENT_MANAGER:RegisterForUpdate( SLICED, 0, function()
		if BTV.sliced ~= co then return end
		sliceStart = GetGameTimeMilliseconds()
		local ok, a, b = coroutine.resume( co )
		if not ok then
			BTV.CancelSliced()
			onDone( nil, "|cFF7070the import stopped on an error: " .. tostring( a ) .. "|r" )
		elseif coroutine.status( co ) == "dead" then
			BTV.CancelSliced()
			onDone( a, b )
		else
			onProgress( a or 0 )
		end
	end )
end

-- The solver. `forced` is the player's own picks, `{ key, path, quality }` in gap order:
-- they go into the pool first so an edit keeps every other pick where it was, and the
-- greedy only fills what the edit left open. A forced piece worn nowhere is dropped.
--
-- ponytail: greedy set cover, one BTV.Solve per candidate per open entry per round. A
-- roster is a handful of distinct builds and a plan a handful of pieces, so this is a
-- few hundred small solves; exact cover if a real roster ever proves the greedy short.
local Blocks
function BTV.PlanMissing( analysis, forced )
	local pool = {}
	for _, item in ipairs( analysis.pool or {} ) do table.insert( pool, item ) end
	local entries = analysis.entries or {}

	-- Round 0, against what is owned alone: which entries are short, and what every
	-- candidate does for each of them. The alternatives a picker may offer are read from
	-- here, so a pick can only ever be a piece that fills something.
	local open, base, candidates, byKey = {}, {}, {}, {}
	for ei, review in ipairs( entries ) do
		base[ ei ] = Placed( review, pool )
		if base[ ei ] < review.demandCount then
			table.insert( open, ei )
			Candidates( review, candidates, byKey )
		end
	end
	-- Facts read LibSets, the sticker book and the research snapshot; the same piece keeps
	-- them across re-plans (#490).
	analysis.factsOf = analysis.factsOf or {}
	-- Progress: this round is the first tenth, then the share of the missing demands filled.
	-- ponytail: a round fills at least one demand, so it reads as one step; it can jump
	-- when a round fills several, or reach the end early when nothing more can be filled.
	local missing = 0
	for _, ei in ipairs( open ) do missing = missing + entries[ ei ].demandCount - base[ ei ] end
	for ci, cand in ipairs( candidates ) do
		Pause( 0.1 * ci / #candidates )
		analysis.factsOf[ cand.key ] = analysis.factsOf[ cand.key ] or Facts( cand )
		cand.facts = analysis.factsOf[ cand.key ]
		cand.gains = {}
		local item = CreatedItem( cand )
		table.insert( pool, item )
		for _, ei in ipairs( open ) do
			cand.gains[ ei ] = 0
			if Wants( entries[ ei ], cand.setId ) then
				local count = Placed( entries[ ei ], pool )
				cand.gains[ ei ] = count - base[ ei ]
			end
		end
		table.remove( pool )
	end

	local created = {}
	local function Add( cand, path, quality )
		local item = CreatedItem( cand )
		item.path, item.quality = path, quality
		table.insert( pool, item )
		table.insert( created, item )
	end
	for _, pick in ipairs( forced or {} ) do
		if byKey[ pick.key ] then Add( byKey[ pick.key ], nil, pick.quality ) end
	end

	while true do
		local counts, short, filled = {}, {}, 0
		for _, ei in ipairs( open ) do
			counts[ ei ] = Placed( entries[ ei ], pool )
			filled = filled + counts[ ei ] - base[ ei ]
			if counts[ ei ] < entries[ ei ].demandCount then table.insert( short, ei ) end
		end
		if #short == 0 then break end
		local best, bestGain, bestFit
		for ci, cand in ipairs( candidates ) do
			Pause( 0.1 + 0.9 * math.min( 1, ( filled + ci / #candidates ) / math.max( missing, 1 ) ) )
			local gain, fit = 0, 0
			for _, ei in ipairs( short ) do
				local delta = cand.gains[ ei ]
				if #created > 0 and Wants( entries[ ei ], cand.setId ) then
					table.insert( pool, CreatedItem( cand ) )
					local count, worn = Placed( entries[ ei ], pool )
					delta = count - counts[ ei ]
					-- Created pieces worn in the trait their slot asked for, then in its glyph
					-- (owner, 2026-09-19): worth a hundredth of a trait, so it only breaks a tie.
					for item, slotId in pairs( worn ) do
						local want = entries[ ei ].req[ slotId ]
						if item.created and want and want.trait and item.trait == want.trait then fit = fit + 100 end
						if item.created and want and want.glyph and item.glyph and SameGlyph( item.glyph, GLYPHS[ want.glyph ] ) then fit = fit + 1 end
					end
					table.remove( pool )
				end
				if delta > 0 then gain = gain + 1 end
			end
			if gain > 0 and ( not best or Better( cand, gain, fit, best, bestGain, bestFit ) ) then best, bestGain, bestFit = cand, gain, fit end
		end
		if not best then break end
		Add( best )
	end

	-- One gap per created piece that is actually worn somewhere: the entries it serves,
	-- the WW rows it fills, the slot it takes in each.
	local gaps, gapOf = {}, {}
	for _, item in ipairs( created ) do
		gapOf[ item ] = { key = item.key, cand = item.cand, path = item.path or item.cand.facts.path,
			quality = item.quality, serves = {}, fills = 0, slots = {} }
	end
	for _, ei in ipairs( open ) do
		local _, worn = Placed( entries[ ei ], pool )
		for item, slotId in pairs( worn ) do
			local gap = gapOf[ item ]
			if gap then
				table.insert( gap.serves, ei )
				gap.fills = gap.fills + ( entries[ ei ].rows or 1 )
				gap.slots[ ei ] = slotId
			end
		end
	end
	for _, item in ipairs( created ) do
		local gap = gapOf[ item ]
		if #gap.serves > 0 then
			table.sort( gap.serves )
			table.insert( gaps, gap )
		end
	end

	-- The picker per gap: its own piece first, then the sheet's own ask where the plan
	-- departs from it (the set the sheet put on the slot this piece takes: pick it and the
	-- greedy adds whatever that then leaves short), then every other candidate that fills
	-- something for the same demand. Pieces only: the way to get them is picked per set.
	for _, gap in ipairs( gaps ) do
		gap.options = {}
		local seen = {}
		local function Offer( cand, sheet )
			if seen[ cand.key ] then return end
			seen[ cand.key ] = true
			table.insert( gap.options, { cand = cand, sheet = sheet } )
		end
		Offer( gap.cand )
		for _, ei in ipairs( gap.serves ) do
			local want = entries[ ei ].req[ gap.slots[ ei ] ]
			if want and want.set and want.set ~= gap.cand.setId then
				gap.sheet = gap.sheet or { set = want.set, slot = gap.slots[ ei ] }
				for _, cand in ipairs( candidates ) do
					if cand.setId == want.set and cand.slot == gap.slots[ ei ]
						and ( not cand.armorType or ( want.weight and WEIGHTS[ want.weight ] == cand.armorType ) ) then
						Offer( cand, true )
					end
				end
			end
		end
		local function SameDemand( cand )
			for setId in pairs( gap.cand.forSets ) do
				if cand.forSets[ setId ] then return true end
			end
			return false
		end
		-- Another set only (a class member): the same set in another slot or weight is
		-- the solver's own call, and listing every one of those buried the plan (owner
		-- hand test 2026-09-08).
		for _, cand in ipairs( candidates ) do
			if SameDemand( cand ) and cand.setId ~= gap.cand.setId then
				for _, ei in ipairs( gap.serves ) do
					if ( cand.gains[ ei ] or 0 ) > 0 then
						Offer( cand )
						break
					end
				end
			end
		end
		gap.pick = 1
	end

	local missing = analysis.missing or {}
	missing.gaps = gaps
	missing.quality = missing.quality or ITEM_DISPLAY_QUALITY_LEGENDARY -- gold by default (owner, 2026-09-08)
	missing.pathOf = missing.pathOf or {}
	analysis.missing = missing
	return Blocks( analysis )
end

-- The set blocks over the current gaps: the way to get each set, its crafter, its cost.
-- Its own step so a path pick only rebuilds these (the re-solve froze the game, owner
-- 2026-09-08).
Blocks = function( analysis )
	local missing, gaps = analysis.missing, analysis.missing.gaps
	-- One block per set, in the order its first piece was created (owner, 2026-09-08): the
	-- way to get the set is picked once for all its pieces, each piece keeping its own
	-- facts. A way a piece cannot take (a locked sticker-book piece under Reconstruct)
	-- falls back to that piece's own best. The crystal total is what the picks add up to.
	missing.sets = {}
	local blockOf = {}
	for _, gap in ipairs( gaps ) do
		local block = blockOf[ gap.cand.setId ]
		if not block then
			block = { setId = gap.cand.setId, gaps = {}, paths = {}, ranks = {} }
			blockOf[ gap.cand.setId ] = block
			table.insert( missing.sets, block )
		end
		table.insert( block.gaps, gap )
		for _, path in ipairs( gap.cand.facts.paths ) do
			local rank = gap.cand.facts.ranks[ path ]
			if not block.ranks[ path ] or rank < block.ranks[ path ] then block.ranks[ path ] = rank end
		end
	end
	missing.crystals = 0
	missing.balance = GetCurrencyAmount( CURT_CHAOTIC_CREATIA, GetCurrencyPlayerStoredLocation( CURT_CHAOTIC_CREATIA ) ) or 0
	for _, block in ipairs( missing.sets ) do
		for path in pairs( block.ranks ) do table.insert( block.paths, path ) end
		table.sort( block.paths, function( a, b ) return block.ranks[ a ] < block.ranks[ b ] end )
		local chosen = missing.pathOf[ block.setId ]
		block.path = ( chosen and block.ranks[ chosen ] ) and chosen or block.paths[ 1 ]
		-- One crafter for the whole set (owner, 2026-09-08): the character who can craft
		-- the most of its pieces, this one on a tie, so nobody hops characters per piece.
		if block.ranks.craft then
			local here, counts, names = LocationKey( GetCurrentCharacterId() ), {}, {}
			for _, gap in ipairs( block.gaps ) do
				for charId, name in pairs( gap.cand.facts.canOn or {} ) do
					counts[ charId ], names[ charId ] = ( counts[ charId ] or 0 ) + 1, name
				end
			end
			for charId, count in pairs( counts ) do
				if not block.crafter or count > block.crafter.count
					or ( count == block.crafter.count and charId == here ) then
					local snap = BTV.svAccount.research[ charId ]
					local craft = ResearchLine( block.gaps[ 1 ].cand )
					block.crafter = { id = charId, name = names[ charId ], count = count, here = charId == here,
						-- Tempers a guaranteed gold upgrade costs on this crafter; 8 means the passive is maxed.
						tempers = snap and snap.upgrade and craft and snap.upgrade[ craft ] or GOLD_TEMPERS,
						-- Snapshotted before the passives were read: log in there once.
						unread = not ( snap and snap.tier and craft and snap.tier[ craft ] ) }
				end
			end
		end
		block.cost = 0
		for _, gap in ipairs( block.gaps ) do
			local facts = gap.cand.facts
			gap.path = facts.ranks[ block.path ] and block.path or facts.path
			if gap.path == "reconstruct" then block.cost = block.cost + ( facts.cost or 0 ) end
		end
		missing.crystals = missing.crystals + block.cost
	end
	return missing
end

-- The current picks as PlanMissing takes them back.
local function ForcedPicks( analysis, swap, key )
	local forced = {}
	for _, held in ipairs( analysis.missing.gaps ) do
		table.insert( forced, { key = held == swap and key or held.key, quality = held.quality } )
	end
	return forced
end

-- A piece pick on the Missing gear step: re-plan with every current pick forced, this one
-- swapped for the option chosen, so no edit can produce an illegal plan.
function BTV.PickMissing( analysis, gap, index )
	local option = gap.options and gap.options[ index ]
	if not option then return end
	BTV.PlanMissing( analysis, ForcedPicks( analysis, gap, option.cand.key ) )
end

-- The way to get a set, for every piece of it.
function BTV.PickPath( analysis, setId, path )
	analysis.missing.pathOf[ setId ] = path
	Blocks( analysis )
end

-- What the record keeps of the plan (#467): one readable line per created piece, so Edit
-- picks and the plan checklist (increment 6 of #474) can rebuild it without a re-paste.
local function MissingPicks( analysis )
	local picks = {}
	for _, gap in ipairs( analysis.missing and analysis.missing.gaps or {} ) do
		local cand = gap.cand
		table.insert( picks, { key = gap.key, set = cand.setId, eq = cand.equipType, armor = cand.armorType,
			weapon = cand.weaponType, trait = cand.trait, path = gap.path,
			quality = gap.quality or analysis.missing.quality, name = cand.facts.name } )
	end
	return picks
end

-- ---------------------------------------------------------------- the import

-- The zone every setup in this payload lands in. One payload is one run, so one zone;
-- setups the generator could not bind (a second trash setup, #384) ride along with it.
-- A payload naming no trial at all (a roster built without a trial template, or for a
-- place the builder has none for, like the Infinite Archive) lands wherever the player
-- chose on the Paste step, and in WW's General zone by default (owner, 2026-09-04).
local function TargetZone( payload, chosenTag )
	for _, entry in ipairs( payload.setups ) do
		for _, row in ipairs( entry.rows or {} ) do
			local tag = row.condition and row.condition.tag
			if tag and tag ~= "" then
				local zone = WW.zones[ tag ]
				if zone then return zone end
				return nil, string.format( "unknown zone '%s'. Update Wizard's Wardrobe.", tag )
			end
		end
	end
	local zone = WW.zones[ chosenTag or "GEN" ]
	if zone then return zone end
	return nil, string.format( "no setup names a trial, and Wizard's Wardrobe has no '%s' zone to write it to.", tostring( chosenTag or "GEN" ) )
end

-- Payload v2 is v1 packed to fit the game's paste box, which holds about 29,900
-- characters whatever SetMaxInputChars says (Alan's 23 setup Ossein Cage run was 35,262
-- and arrived cut, 2026-10-15): `sub` once for the roster instead of once per setup, and
-- each gear hint a list in GEAR_FIELDS order, 0 standing for "absent" past the first two.
-- Unpacked into exactly the v1 tables, so nothing after the read can tell them apart.
local GEAR_FIELDS = { "slot", "set", "trait", "weight", "eq", "weapon", "glyph", "shieldOk" }
local WEIGHT_NAMES = { "light", "medium", "heavy" }

local function Unpack( payload )
	local sub = type( payload.sub ) == "table" and payload.sub or {}
	payload.sub = nil
	for _, entry in ipairs( type( payload.setups ) == "table" and payload.setups or {} ) do
		-- Each setup gets back the entries for its own sets and their stand-ins, as v1 had.
		local mine = {}
		local function Take( id )
			local space = sub[ tostring( id ) ]
			if space then mine[ tostring( id ) ] = space end
		end
		for _, set in ipairs( entry.sets or {} ) do
			Take( set.id )
			for _, altId in ipairs( set.alt or {} ) do Take( altId ) end
		end
		if next( mine ) then entry.sub = mine end
		for i, hint in ipairs( entry.gear or {} ) do
			local gear = { slot = hint[ 1 ], set = hint[ 2 ] }
			for f = 3, #GEAR_FIELDS do
				if hint[ f ] ~= nil and hint[ f ] ~= 0 then gear[ GEAR_FIELDS[ f ] ] = hint[ f ] end
			end
			if gear.weight then gear.weight = WEIGHT_NAMES[ gear.weight ] end
			if gear.shieldOk then gear.shieldOk = true end
			entry.gear[ i ] = gear
		end
	end
end

-- The paste as a v1 shaped table, or nil when it is not one. Every read goes through here.
function BTV.Decode( text )
	local ok, payload = pcall( json.decode, text )
	if not ok or type( payload ) ~= "table" then return nil end
	if payload.v == 2 and not pcall( Unpack, payload ) then return nil end
	return payload
end

-- Whether the Paste step has to ask where to write (#477 amendment): the payload reads
-- and names no trial.
function BTV.PeekNeedsZone( text )
	local payload = BTV.Decode( text )
	if not payload or type( payload.setups ) ~= "table" then return false end
	for _, entry in ipairs( payload.setups ) do
		for _, row in ipairs( type( entry ) == "table" and entry.rows or {} ) do
			local tag = row.condition and row.condition.tag
			if tag and tag ~= "" then return false end
		end
	end
	return true
end

-- Our own page, reused on re-paste so a leader's fifth revision does not leave five
-- pages behind. Pages the player made themselves are never touched. Finding is split
-- from creating so a cancelled overwrite does not leave an empty page behind. On BTV
-- rather than local: the window's overwrite prompt asks the same question (#477).
function BTV.FindPage( zone, pageName )
	for pageId, page in ipairs( WW.pages[ zone.tag ] or {} ) do
		if page.name == pageName then return pageId end
	end
end

-- Every path this addon reaches for inside Wizard's Wardrobe. `DependsOn` can only state a
-- floor, so a WW release that moved one of these still loads us and then fails somewhere
-- deep and unattributable (#395). Checked at import rather than at load, because WW builds
-- several of these with its own UI and they are legitimately absent before then.
--
-- `transfer.ShowImportDialog` is deliberately absent: it is how `/btv` opens the paste box
-- in the first place, so its loss is visible long before an import.
local WW_SURFACE = {
	"zones", "pages", "setups", "selection",
	"CONDITIONS", "DISABLEDBAGS", "BUFFFOOD", "lookupBuffFood",
	"IsMythic", "FindFood",
	"markers.BuildGearList",
	"gui.OnZoneSelect", "gui.CreatePage", "gui.BuildPage", "gui.ShowConfirmationDialog", "gui.tree",
}

-- The first WW path that is no longer there, or nil while they all are.
local function MovedWwPath()
	if type( WW ) ~= "table" then return "WizardsWardrobe" end
	for _, path in ipairs( WW_SURFACE ) do
		local node = WW
		for key in string.gmatch( path, "[^.]+" ) do
			node = type( node ) == "table" and node[ key ] or nil
			if node == nil then return "WizardsWardrobe." .. path end
		end
	end
	-- Setup is WW's own class, reached as a bare global rather than through the table.
	if type( Setup ) ~= "table" or Setup.New == nil or Setup.ToStorage == nil then return "Setup" end
end

-- "BTV <roster> <player>" (#410): the leader's roster name in the middle, so a second
-- roster for the same trial gets its own page instead of overwriting the first. An
-- older payload carries no roster name and keeps the plain "BTV <player>".
local function PageNameFor( payload )
	return "BTV " .. ( payload.roster and payload.roster .. " " or "" ) .. ( payload.player or "run" )
end

-- What the Paste step shows before Next is ever pressed (#477): the page this payload
-- would write, or nil while the box holds something unreadable.
function BTV.PeekPageName( text )
	local payload = BTV.Decode( text )
	if not payload then return nil end
	return PageNameFor( payload )
end

-- The read half of an import (#477): validate the paste, match it against the bags, and
-- come back with everything the window's Review step and the write both need. Touches no
-- WW page, saves no record, prints nothing; the report lines are collected instead. The
-- error second return is already coloured, ready for chat.
function BTV.Analyze( text, chosenTag )
	local moved = MovedWwPath()
	if moved then
		return nil, string.format( "|cFF7070%s is gone from Wizard's Wardrobe. Nothing written, BTV Tools needs an update.|r", moved )
	end

	-- One part of a long roster: only the /btv window collects and joins parts (Wizard.PasteText).
	local _, parts = text:match( "^BTV:(%d+)/(%d+):" )
	if parts then
		return nil, string.format( "|cFF7070this roster comes in %s parts. Open |c7B68EE/btv|cFF7070 and paste them one after the other.|r", parts )
	end

	local payload = BTV.Decode( text )
	if not payload then
		-- A paste the box cut short looks exactly like a garbage paste, so name the real
		-- cause rather than sending the player back to copy the same too-long string (#413).
		-- The box stops near 29,900 characters however high SetMaxInputChars goes.
		if text:find( '^{"v":' ) then
			return nil, "|cFF7070your roster arrived cut short: it is longer than the game's paste box. Update BTV Tools Roster Importer, then copy it again from the share page.|r"
		end
		return nil, "|cFF7070not a BTV payload. Copy it again from the share page.|r"
	end
	if payload.v ~= 1 and payload.v ~= BTV.PAYLOAD_VERSION then
		return nil, string.format( "|cFF7070payload is v%s, this addon reads up to v%d. Update the addon or re-export.|r",
			tostring( payload.v ), BTV.PAYLOAD_VERSION )
	end
	if type( payload.setups ) ~= "table" or #payload.setups == 0 then
		return nil, "|cFF7070payload has no setups.|r"
	end
	-- Rows arrived after the first payloads went out under the same version number, so a
	-- string copied before then parses cleanly and would write nothing at all. Refuse it.
	if type( payload.setups[ 1 ].rows ) ~= "table" then
		return nil, "|cFF7070payload predates rows. Copy it again from the share page.|r"
	end
	return BTV.AnalyzePayload( payload, chosenTag, text )
end

-- The match itself, from a decoded payload: the plan and Edit picks run it again from the
-- record's stored payload, with no paste to decode (#480).
function BTV.AnalyzePayload( payload, chosenTag, text )
	local zone, why = TargetZone( payload, chosenTag )
	if not zone then
		return nil, "|cFF7070" .. why .. "|r"
	end

	local pageName = PageNameFor( payload )

	-- Everything the write and the window read: the report lines in the order chat says
	-- them, the finished setups in run order, and the review model the Review step draws.
	local analysis = {
		text = text, payload = payload, zone = zone, pageName = pageName,
		report = {}, traits = {}, writes = {},
		entries = {}, misses = {},
		found = { here = {}, bank = {}, away = {} },
	}
	-- Not the global Remember: nothing may print or touch BTV.lastReport until the write.
	local function collect( msg ) table.insert( analysis.report, msg ) end

	-- One pool, in reachability order (#413): worn, backpack, the bank while it is open, then
	-- everything IIfA has seen that this client cannot touch. ScoreItem keeps that order.
	local pool = BTV.ScanBags()
	local remote, complete = BTV.RemotePool()
	for _, item in ipairs( remote or {} ) do table.insert( pool, item ) end
	-- The missing-gear plan solves against this same pool (#479), and judges crafting
	-- against every character's research, this one's read fresh.
	analysis.pool = pool
	-- The debug trace (#483): armed by /btv debug or the setting, saved by the write.
	if BTV.debugArmed or ( BTV.svAccount and BTV.Setting( "debugTrace" ) ) then
		analysis.trace = { bags = {}, setups = {} }
		for _, item in ipairs( pool ) do
			table.insert( analysis.trace.bags, string.format( "%s: set %s, equip type %s, trait %s, armor %s, weapon %s",
				TraceName( item ), tostring( item.setId ), tostring( item.equipType ), tostring( item.trait ),
				tostring( item.armorType ), tostring( item.weaponType ) ) )
		end
	end
	BTV.SnapshotResearch()
	-- Rank each remote piece's place by how much wanted gear it holds, so the fetch list
	-- converges on the one character worth the trip.
	if remote and #remote > 0 then
		local wanted = {}
		for _, entry in ipairs( payload.setups ) do
			for _, want in ipairs( entry.sets or {} ) do
				wanted[ want.id ] = true
				for _, altId in ipairs( want.alt or {} ) do wanted[ altId ] = true end
			end
		end
		BTV.ClusterPool( remote, wanted )
	end

	local builds = #payload.setups
	-- One block per DISTINCT flex slot, keyed by content (#478): the same note and
	-- options in fourteen setups is one question, answered once. `pick` starts on the
	-- first LEARNED option, which is what /btvpaste applies silently and what the Flex
	-- step pre-selects; nil when nothing is learned or the slot ships no options.
	local flexOf, flexOrder = {}, {}
	-- Both blocks are gathered across the whole import and said once at the end, naming the
	-- builds each line applies to (#402).
	local swapOf, swapOrder = {}, {}
	local missOf, missOrder = {}, {}
	-- Trait swaps are gathered apart from the rest and only counted in the report, because
	-- they are the cheap departure and there are always far more of them (rule 10). The list
	-- itself waits for `/btv trait`.
	local traitOf, traitOrder = {}, {}
	-- What was written into the setups but is not on this character, grouped by where it
	-- actually is (#413). One list for the whole import rather than per build: a piece fetched
	-- once serves every setup that wanted it, so the builds are not worth naming here.
	-- Deduped by physical copy, since the same pool item can be placed in several builds.
	local fetchAt, fetchPlaces, fetched, toFetch = {}, {}, {}, 0
	local function Fetch( item )
		if fetched[ item ] then return end
		fetched[ item ] = true
		toFetch = toFetch + 1
		local where = #item.places > 0 and table.concat( item.places, " or " ) or "a place IIfA did not name"
		local at = fetchAt[ where ]
		if not at then
			at = { names = {}, count = {} }
			fetchAt[ where ] = at
			table.insert( fetchPlaces, where )
		end
		local name = CleanName( GetItemLinkName( item.link ) )
		if not at.count[ name ] then table.insert( at.names, name ) end
		at.count[ name ] = ( at.count[ name ] or 0 ) + 1
	end
	-- The Review step's found-gear groups (#477): every placed physical piece once, filed
	-- by where it is. "Here" is what collapses to a count line; the rest is what the
	-- player still has to move.
	local seenFound = {}
	local function Found( item )
		if seenFound[ item ] then return seenFound[ item ] end
		local piece = { link = item.link, name = CleanName( GetItemLinkName( item.link ) ) }
		seenFound[ item ] = piece
		if item.remote then
			piece.where = #item.places > 0 and table.concat( item.places, " or " ) or "a place IIfA did not name"
			-- The plan groups by the first place, and by what kind of place it is (#480).
			piece.place = item.places[ 1 ] or piece.where
			piece.kind = BTV.PlaceKind( item.placeKeys and item.placeKeys[ 1 ] )
			table.insert( analysis.found.away, piece )
		elseif ( item.rank or 0 ) >= 5 then
			piece.where = item.rank >= 10 and "worn" or "backpack"
			table.insert( analysis.found.here, piece )
		else
			-- The open container: the bank, or the coffer the player is standing at (which
			-- the game hands over as the banking bag while it is open).
			if IsHouseBankBag and IsHouseBankBag( item.bag ) then
				piece.kind = "house"
				piece.place = PlaceName( LocationKey( GetCollectibleForBag( item.bag ) ) )
			else
				piece.kind, piece.place = "bank", nil
			end
			piece.where = piece.place or "bank"
			table.insert( analysis.found.bank, piece )
		end
		return piece
	end
	-- Demands that landed on nothing at all, which is not the same as the number of lines
	-- below: one line can be the same news in several builds (#413).
	local unplaced = 0
	-- The payload groups its rows by build, so writing them as they arrive would put every
	-- boss after every trash. Each row carries its place in the leader's run order, and the
	-- page is written in that order instead.
	local ordered = {}
	for _, entry in ipairs( payload.setups ) do
		local rows = entry.rows or {}
		-- Identical sections share one payload entry, so the gear is solved once and every
		-- section it covers is written from that one answer. The report names the build
		-- after its first section and counts the rest, rather than repeating itself.
		local label = rows[ 1 ] and rows[ 1 ].name or "setup"
		if #rows > 1 then label = string.format( "%s and %d more", label, #rows - 1 ) end

		local warned = {}
		local function warn( msg )
			if warned[ msg ] then return end
			warned[ msg ] = true
			collect( string.format( "  |cF8FF70%s|r: %s", label, msg ) )
		end
		local function depart( msg ) Gather( swapOf, swapOrder, msg, label ) end

		-- This entry's flex slots, folded into the import-wide blocks. "Fills N setups"
		-- counts WW rows, since a row is what lands in Wizard's Wardrobe; two slots with
		-- the same content in one entry are still that entry's rows once.
		local flexSeen = {}
		for _, barKey in ipairs( FLEX_BARS ) do
			for _, slotKey in ipairs( FLEX_SLOTS ) do
				local spec = entry.flex and entry.flex[ barKey ] and entry.flex[ barKey ][ slotKey ]
				if spec then
					local key = FlexKey( spec )
					local block = flexOf[ key ]
					if not block then
						block = { key = key, note = spec.note, positions = {}, seenPos = {}, options = {}, fills = 0 }
						for _, id in ipairs( spec.options or {} ) do
							table.insert( block.options, { id = id, learned = BTV.IsAbilityLearned( id ) } )
						end
						for i, option in ipairs( block.options ) do
							if option.learned then block.pick = i break end
						end
						flexOf[ key ] = block
						table.insert( flexOrder, block )
					end
					-- Matching by content can merge slots in different positions, and the
					-- block's header has to name every one of them, not just the first.
					if not block.seenPos[ barKey .. slotKey ] then
						block.seenPos[ barKey .. slotKey ] = true
						table.insert( block.positions, { bar = barKey, slot = slotKey } )
					end
					if not flexSeen[ key ] then
						flexSeen[ key ] = true
						block.fills = block.fills + #rows
					end
				end
			end
		end

		local demands, req = BTV.ParseSetup( entry, warn )
		local solved = analysis.trace and {}
		local placed, isSurplus, used, budget = BTV.Solve( demands, pool, req, solved )
		if solved then table.insert( analysis.trace.setups, { setup = label, demands = solved } ) end
		-- Silent when the weights that moved cost the build nothing (rule 13).
		for _, move in ipairs( WeightMoves( demands, placed, req ) ) do depart( move ) end
		-- rule 14: the bar is wearing something other than what the leader drew on it, which is
		-- never silent. A frost staff traded away costs the whole group Minor Brittle, so that
		-- is said as its own line rather than left for the player to work out.
		for di = 1, #demands do
			local hit = placed[ di ]
			local want = hit and hit.pair and req[ hit.slot ]
			if want then
				depart( string.format( "|cF8FF70Shape swap|r %s %s: no %s owned, wearing a one hander and shield",
					SetLabel( hit.item.setId ), SLOT_NAME[ hit.slot ] or tostring( hit.slot ), want.weapon ) )
				if want.weapon == "frost" then
					depart( "|cF8FF70Minor Brittle|r: that bar has no ice staff now, so chilled no longer applies it for the group." )
				end
			end
		end

		for _, row in ipairs( rows ) do
			table.insert( ordered, { entry = entry, row = row, placed = placed, warn = warn, depart = depart, seq = #ordered + 1 } )
		end

		local count = 0
		for _ in pairs( placed ) do count = count + 1 end
		collect( string.format( "|cC5C29E%s|r: |cFFFFFF%d/%d|r placed", label, count, #demands ) )

		-- What the Review step draws for this entry: one rail box, and a per-slot grid a
		-- boss setup zooms into (#477). An entry with several rows is the bunched-trash
		-- case: one box, one grid, however many WW rows it becomes.
		local review = { label = label, rows = #rows, name = rows[ 1 ] and rows[ 1 ].name or "setup",
			placedCount = 0, demandCount = 0, grid = {}, extra = {},
			-- What the missing-gear plan re-solves from (#479).
			entry = entry, demands = demands, req = req, isSurplus = isSurplus }
		table.insert( analysis.entries, review )

		-- Per set: how many of its demands landed. "not on any of your characters" is a lie
		-- when the player owns three of the five and only needs two more (#402).
		local got, need = {}, {}
		for di, demand in ipairs( demands ) do
			-- A surplus piece is rule 6 doing its job, so it is neither a miss nor a swap.
			if not isSurplus[ di ] then
				need[ demand.set ] = ( need[ demand.set ] or 0 ) + 1
				review.demandCount = review.demandCount + 1
				if placed[ di ] then
					got[ demand.set ] = ( got[ demand.set ] or 0 ) + 1
					review.placedCount = review.placedCount + 1
					local hit = placed[ di ]
					-- One worn piece: its grid cell, its found group, and the fetch list if
					-- it is not in a bag here. The pair is rule 14's shield half.
					local function Wear( slot, item )
						review.grid[ slot ] = { link = item.link, remote = item.remote, places = item.places }
						local piece = Found( item )
						-- The glyphs its slots asked for (owner, 2026-09-19): a piece wearing none
						-- of them gets a row in the plan. One piece can sit in several builds, so
						-- it is only short when it answers no ask at all.
						local word = req[ slot ] and req[ slot ].glyph
						if word and GLYPHS[ word ] then
							piece.glyphs = piece.glyphs or {}
							if not piece.glyphs[ word ] then
								piece.glyphs[ word ] = true
								table.insert( piece.glyphs, word )
							end
							if SameGlyph( item.glyph, GLYPHS[ word ] ) then piece.glyphOk = true end
						end
						if item.remote then Fetch( item ) end
					end
					Wear( hit.slot, hit.item )
					if hit.pair then Wear( hit.pair.slot, hit.pair.item ) end
					local swap, kind = DepartureLine( demand, hit, req )
					if swap and kind == "trait" then Gather( traitOf, traitOrder, swap, label )
					elseif swap then depart( swap ) end
				end
			end
		end

		for di, demand in ipairs( demands ) do
			if not placed[ di ] and not isSurplus[ di ] then
				unplaced = unplaced + 1
				local line, tier = MissLine( demand, req, pool, used, budget, remote ~= nil, complete,
					got[ demand.set ] or 0, need[ demand.set ] or 0 )
				Gather( missOf, missOrder, line, label )
				missOf[ line ].tier = missOf[ line ].tier or tier
				-- A pinned miss marks its own cell; an unpinned one has no cell to mark.
				if demand.slot then
					review.grid[ demand.slot ] = { miss = line, tier = tier }
				else
					table.insert( review.extra, line )
				end
			end
		end
	end

	table.sort( ordered, function( a, b )
		local ai, bi = a.row.i or a.seq, b.row.i or b.seq
		if ai == bi then return a.seq < b.seq end
		return ai < bi
	end )
	for _, item in ipairs( ordered ) do
		-- A section the generator could not bind still gets a row, the player picks it by
		-- hand. One that binds to two fights becomes two rows, each named after the fight it
		-- actually fires on rather than repeating one name twice.
		local conditions = ConditionsFor( zone, item.row.condition )
		for i = 1, math.max( #conditions, 1 ) do
			local condition = conditions[ i ]
			local setup, raw = BuildSetup( item.entry, item.row.name, item.placed, item.warn, item.depart )
			local name = item.row.name or "BTV"
			-- Two boss rows read better named after the fight each fires on than as the same
			-- name twice. Two TRASH rows share one name ("Trash"), so renaming would only
			-- lose the leader's own label: the trash after a two-entry boss keeps it (#403).
			if #conditions > 1 and condition and condition.boss and not condition.trash then
				setup:SetName( condition.boss )
				name = condition.boss
			end
			if condition then setup:SetCondition( condition ) end
			-- Built now, stored by WriteAnalysis: Review has to show the answer before
			-- anything lands in Wizard's Wardrobe (#477).
			-- The entry's flex rides on the write so the picks can be applied at write
			-- time, after the wizard's Flex step has had its say (#478).
			table.insert( analysis.writes, { setup = setup, raw = raw, name = name, condition = condition, flex = item.entry.flex, entry = item.entry } )
		end
	end

	analysis.flex = flexOrder
	-- The plan for every demand nothing owned could fill (#479): what to create, pre-picked.
	BTV.PlanMissing( analysis )
	-- A flex slot with options none of which the player has learned is left alone, with
	-- one line saying so (#478). Reported here so /btv missing and full verbosity carry
	-- it; WriteAnalysis says it once more at "line" verbosity, where the report is silent.
	analysis.flexWarnings = {}
	for _, block in ipairs( flexOrder ) do
		if #block.options > 0 and not block.pick then
			local what = block.note and string.format( '"%s"', block.note ) or "a flex slot"
			table.insert( analysis.flexWarnings,
				string.format( "|cF8FF70Flex|r %s: none of its options learned, slot left open.", what ) )
			collect( analysis.flexWarnings[ #analysis.flexWarnings ] )
		end
	end

	-- Once a piece can be swapped rather than missed, a success can still differ from what the
	-- leader wrote, and the player is owed that separately from the misses (#402).
	if #swapOrder > 0 then
		collect( string.format( "|cFFFFFF%d|r substituted:", #swapOrder ) )
		for _, hit in ipairs( swapOrder ) do collect( "  " .. Attributed( hit, builds ) ) end
	end

	-- Counted only (rule 10, amended by #473): the /btv trait command is gone and chat is
	-- not the place for lists, so the list itself waits for the window's Review step. It
	-- rides on the analysis (and lands on BTV.lastTraits at write). Every piece is
	-- slotted either way.
	for _, hit in ipairs( traitOrder ) do table.insert( analysis.traits, Attributed( hit, builds ) ) end
	if #traitOrder > 0 then
		collect( string.format( "|cFFFFFF%d|r slotted in the wrong trait.", #traitOrder ) )
	end

	-- The gear the setups were written with that this character cannot reach. It is in the
	-- setups, so the page is complete and WW says the piece's name itself at swap time, but
	-- WW only equips out of the backpack, so it has to be carried here first (#413).
	if toFetch > 0 then
		table.sort( fetchPlaces )
		collect( string.format( "|cF8FF70%d|r written but not on this character. Bring to your backpack:", toFetch ) )
		local bank = ContainerName( IIFA_LOCATION_KEY_BANK or "Bank" )
		local fromBank = false
		for _, where in ipairs( fetchPlaces ) do
			local at = fetchAt[ where ]
			table.sort( at.names )
			local parts = {}
			for _, name in ipairs( at.names ) do
				table.insert( parts, at.count[ name ] > 1 and string.format( "%s x%d", name, at.count[ name ] ) or name )
			end
			collect( string.format( "  |cFFFFFF%s|r: %s", where, table.concat( parts, ", " ) ) )
			if bank and where:find( bank, 1, true ) then fromBank = true end
		end
		-- The bank is only readable while it is open (#344), so gear sitting in it lands here
		-- rather than being placed properly. Pasting again at a banker moves it out of this
		-- list and into real slots, which WW can then withdraw for the whole page in one click.
		if fromBank and not IsBankOpen() then
			collect( "  Bank was shut. Re-paste at a banker and Wizard's Wardrobe can withdraw it for you." )
		end
	end

	-- Each miss line goes to chat and, tiered, to the Review step's grouped blocks (#477).
	for _, hit in ipairs( missOrder ) do
		local line = Attributed( hit, builds )
		collect( "  " .. line )
		table.insert( analysis.misses, { line = line, tier = hit.tier or "unknown" } )
	end

	-- The footer numbers (#477). Placed and total count non-surplus demands over all
	-- entries; toFetch and unplaced are what the one-liner already counted.
	local placedTotal, demandTotal = 0, 0
	for _, review in ipairs( analysis.entries ) do
		placedTotal = placedTotal + review.placedCount
		demandTotal = demandTotal + review.demandCount
	end
	analysis.summary = { builds = builds, placed = placedTotal, total = demandTotal,
		toFetch = toFetch, unplaced = unplaced, traitCount = #traitOrder }

	return analysis
end

-- A stable digest of a page's content: each row's name, condition, gear links, skills and
-- food. Stored on the record at write (#477) and computed again from the live WW page at
-- the next rewrite, so "still ours" can be told from "the player hand-edited it" (#480).
-- The condition part is always written now, so a record from before #480 fingerprints
-- differently and its first rewrite asks once more; nothing else changes.
local function Fingerprint( rows )
	local parts = {}
	for _, row in ipairs( rows ) do
		table.insert( parts, row.name or "" )
		local condition = row.condition or {}
		table.insert( parts, tostring( condition.boss ) .. "/" .. tostring( condition.trash ) )
		local gear, slots = row.gear or {}, {}
		for slot in pairs( gear ) do
			if slot ~= "mythic" then table.insert( slots, slot ) end
		end
		table.sort( slots )
		for _, slot in ipairs( slots ) do
			table.insert( parts, slot .. "=" .. tostring( gear[ slot ].link ) )
		end
		table.insert( parts, "mythic=" .. tostring( gear.mythic ) )
		local skills = row.skills or {}
		for hotbar = 0, 1 do
			for slot = 3, 8 do
				table.insert( parts, tostring( skills[ hotbar ] and skills[ hotbar ][ slot ] or 0 ) )
			end
		end
		table.insert( parts, tostring( row.food or 0 ) )
	end
	local text = table.concat( parts, ";" )
	local hash = 5381
	for i = 1, #text do hash = ( hash * 33 + text:byte( i ) ) % 4294967296 end
	-- %.0f, not %d: same digits in game, but the harness's Lua promotes the hash to a
	-- float past 2^31 and its %d refuses floats. The printed form never changes.
	return string.format( "%d:%.0f", #text, hash )
end

local function WriteFingerprint( writes )
	local rows = {}
	for _, write in ipairs( writes ) do
		table.insert( rows, { name = write.name, condition = write.condition, gear = write.raw.gear,
			skills = write.raw.skills, food = write.raw.food } )
	end
	return Fingerprint( rows )
end

-- The page as Wizard's Wardrobe holds it now. WW stores a setup as a plain table with the
-- same fields the write built (WizardsWardrobeSetup.lua, Setup:GetData).
local function LiveFingerprint( zone, pageId )
	local rows = {}
	for _, stored in ipairs( WW.setups[ zone.tag ] and WW.setups[ zone.tag ][ pageId ] or {} ) do
		table.insert( rows, { name = stored.name, condition = stored.condition, gear = stored.gear,
			skills = stored.skills, food = stored.food and stored.food.id } )
	end
	return Fingerprint( rows )
end

-- The silent-rewrite gate (#480), for Edit picks: the page the active record owns still
-- reads exactly as the record last wrote it, so rewriting it eats nothing of the
-- player's. A paste over an existing page asks as it always did (owner, 2026-09-09).
function BTV.PageMatchesRecord( zone, pageName )
	local record = BTV.GetRecord()
	if not record or record.pageName ~= pageName or record.zoneTag ~= zone.tag or not record.fingerprint then
		return false
	end
	local pageId = BTV.FindPage( zone, pageName )
	return pageId ~= nil and LiveFingerprint( zone, pageId ) == record.fingerprint
end

-- The flex picks, written into the setups (#478). One pick fills every setup whose flex
-- slot matches by content; a block with no pick (nothing learned, or no options) leaves
-- its slot alone, so the player fills it in game. Run before the fingerprint so a
-- different pick fingerprints differently, and idempotent, so a re-entry through the
-- overwrite prompt costs nothing.
local function ApplyFlex( analysis )
	local byKey = {}
	for _, block in ipairs( analysis.flex or {} ) do byKey[ block.key ] = block end
	for _, write in ipairs( analysis.writes ) do
		if write.flex then
			for barKey, slots in pairs( write.flex ) do
				for slotKey, spec in pairs( slots ) do
					local block = byKey[ FlexKey( spec ) ]
					if block and block.pick then
						write.raw.skills[ tonumber( barKey ) ][ tonumber( slotKey ) ] = ResolveScribed( block.options[ block.pick ].id )
					end
				end
			end
			write.setup:SetSkills( write.raw.skills )
		end
	end
end

-- ---- Skill placement (docs/plans/2026-10-14-skill-placement.md, ADR 0020) ----
-- svAccount.placements[ key ] = { id = an ability id to draw it by, [ hotbar ] = { slot, seq } },
-- slot being WW's 3..7 (the player's 1..5). The ultimate is never placed.

-- One key per skill whatever its morph, and per grimoire whatever its scripts.
function BTV.SkillKey( abilityId )
	local grimoire = GetAbilityCraftedAbilityId( abilityId )
	if grimoire ~= 0 then return "g" .. grimoire end
	local data = SKILLS_DATA_MANAGER and SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId( abilityId )
	local skill = data and data:GetSkillData()
	local base = skill and skill.GetMorphData and skill:GetMorphData( MORPH_SLOT_BASE )
	return "s" .. ( base and base:GetAbilityId() or abilityId )
end

-- A counter, not a timestamp: two drops in the same second still have an order.
function BTV.NextPlacementSeq()
	BTV.svAccount.placementSeq = ( BTV.svAccount.placementSeq or 0 ) + 1
	return BTV.svAccount.placementSeq
end

function BTV.SavePlacement( abilityId, hotbar, slot, seq )
	local key = BTV.SkillKey( abilityId )
	local saved = BTV.svAccount.placements[ key ] or {}
	saved.id = abilityId
	saved[ hotbar ] = { slot = slot, seq = seq or BTV.NextPlacementSeq() }
	BTV.svAccount.placements[ key ] = saved
end

-- One bar of one setup in the player's order, slots 3..7 only. A slot saved for this bar
-- beats a backup from the other bar, then the newer save wins; the loser, skills with no
-- slot and empty slots fill what is left in the leader's order.
function BTV.SortBar( bar, hotbar )
	local placements, wants = BTV.svAccount.placements, {}
	for slot = 3, 7 do
		local saved = bar[ slot ] and bar[ slot ] ~= 0 and placements[ BTV.SkillKey( bar[ slot ] ) ]
		local own = saved and saved[ hotbar ]
		local pick = own or ( saved and saved[ 1 - hotbar ] )
		if pick then table.insert( wants, { from = slot, to = pick.slot, own = own ~= nil, seq = pick.seq } ) end
	end
	table.sort( wants, function( a, b )
		if a.own ~= b.own then return a.own end
		return a.seq > b.seq
	end )
	local sorted, filled, moved = {}, {}, {}
	for _, want in ipairs( wants ) do
		if not filled[ want.to ] then
			sorted[ want.to ], filled[ want.to ], moved[ want.from ] = bar[ want.from ], true, true
		end
	end
	local free = 3
	for slot = 3, 7 do
		if not moved[ slot ] then
			while filled[ free ] do free = free + 1 end
			sorted[ free ], filled[ free ] = bar[ slot ], true
		end
	end
	for slot = 3, 7 do bar[ slot ] = sorted[ slot ] end
end

-- After ApplyFlex, which writes by the leader's positions, so this runs once per analysis:
-- the fast path's overwrite prompt re-analyzes, and the window commits once.
local function ApplyPlacements( analysis )
	if not BTV.Setting( "usePlacements" ) then return end
	for _, write in ipairs( analysis.writes ) do
		for hotbar = 0, 1 do BTV.SortBar( write.raw.skills[ hotbar ], hotbar ) end
		write.setup:SetSkills( write.raw.skills )
	end
end

-- The skills an import puts on each bar, flex picks in, for the window's Skill placements
-- step: `bars[ hotbar ]` lists each once as { key, id }, and `writes[ i ][ hotbar ][ key ]`
-- says which setups carry it, for the shared-slot warning.
function BTV.PlacementSkills( analysis )
	ApplyFlex( analysis )
	local bars, writes, seen = { [ 0 ] = {}, [ 1 ] = {} }, {}, { [ 0 ] = {}, [ 1 ] = {} }
	for i, write in ipairs( analysis.writes ) do
		writes[ i ] = { [ 0 ] = {}, [ 1 ] = {} }
		for hotbar = 0, 1 do
			for slot = 3, 7 do
				local id = write.raw.skills[ hotbar ][ slot ]
				if id and id ~= 0 then
					local key = BTV.SkillKey( id )
					writes[ i ][ hotbar ][ key ] = true
					if not seen[ hotbar ][ key ] then
						seen[ hotbar ][ key ] = true
						table.insert( bars[ hotbar ], { key = key, id = id } )
					end
				end
			end
		end
	end
	return bars, writes
end

-- Fill from my bars, and /btv remember: the live front and back bars saved as they sit.
-- The game binds a scribed skill as its grimoire, so it is turned back into an ability.
function BTV.RememberBars()
	local count = 0
	for hotbar = 0, 1 do
		for slot = 3, 7 do
			local id = GetSlotBoundId( slot, hotbar )
			if id ~= 0 and GetSlotType( slot, hotbar ) == ACTION_TYPE_CRAFTED_ABILITY then id = GetAbilityIdForCraftedAbilityId( id ) end
			if id ~= 0 then
				BTV.SavePlacement( id, hotbar, slot )
				count = count + 1
			end
		end
	end
	return count
end

-- The write half (#477): everything an import changes, fed by an analysis. `confirmed`
-- true skips the fast path's own overwrite prompt; the window asks its richer
-- overwrite-or-create question itself and always calls this confirmed.
local PlanLines
function BTV.WriteAnalysis( analysis, confirmed )
	local zone, pageName, payload = analysis.zone, analysis.pageName, analysis.payload
	ApplyFlex( analysis )
	ApplyPlacements( analysis )

	-- WW's own entry point: it selects the zone, seeds its page list if this is the first
	-- time the player has opened it, and leaves the window pointing where we are writing.
	WW.gui.OnZoneSelect( zone )
	-- WW only creates a zone's setups table when a setup is first stored, so a zone whose
	-- pages hold none yet (General, on a fresh install) has no table to index (owner hand
	-- test 2026-09-09).
	WW.setups[ zone.tag ] = WW.setups[ zone.tag ] or {}

	local pageId = BTV.FindPage( zone, pageName )
	local reused = pageId ~= nil
	-- Replacing a page the player may have hand-edited is not something to discover
	-- afterwards, so the second paste onwards asks first (#406), unless the player has
	-- turned the asking off (#467). Re-entry re-reads the text from the top rather than
	-- carrying half-finished state across the dialog.
	if reused and not confirmed and not BTV.Setting( "autoOverwrite" ) then
		WW.gui.ShowConfirmationDialog( "BTVOverwrite", string.format(
			"|cFFFFFF%s|r in %s already holds %d setup%s. Importing replaces them.",
			pageName, zone.name or zone.tag,
			#( WW.setups[ zone.tag ][ pageId ] or {} ),
			#( WW.setups[ zone.tag ][ pageId ] or {} ) == 1 and "" or "s" ),
			function() BTV.Import( analysis.text, true ) end )
		return false
	end
	pageId = pageId or WW.gui.CreatePage( true )
	WW.pages[ zone.tag ][ pageId ].name = pageName
	-- Ours to own: WW seeds a new page with an empty setup per boss, and those carry
	-- conditions that would fight the ones we are about to write.
	WW.setups[ zone.tag ][ pageId ] = {}

	-- What `/btv missing` reprints, and what full verbosity says now: the lines the
	-- analysis collected, replayed in their order.
	BTV.lastReport = {}
	BTV.lastTraits = analysis.traits
	for _, line in ipairs( analysis.report ) do Remember( line ) end

	for index, write in ipairs( analysis.writes ) do
		write.setup:ToStorage( zone.tag, pageId, index )
	end

	-- The page has to be the selected one or WW never loads its conditions.
	WW.selection.pageId = pageId
	WW.markers.BuildGearList()
	WW.gui.BuildPage( zone, pageId, true )
	WW.gui.tree:RefreshTree( WW.gui.tree.tree, zone )

	-- The record this import is recomputed from on any character (#467, #472): the plan,
	-- the fetch list and re-paste all read it back rather than scanning WW pages. A
	-- different page replacing the active import sends the old record to the history,
	-- where Past imports can bring it back (#480); Edit picks rewrites in place.
	local old = BTV.GetRecord()
	if old and not analysis.editing and ( old.pageName ~= pageName or old.zoneTag ~= zone.tag ) then
		PushHistory( old )
	end
	local flexPicks = {}
	for _, block in ipairs( analysis.flex or {} ) do flexPicks[ block.key ] = block.pick end
	-- The checklist (#480), fixed at write time. Edit picks keeps what a line learned on
	-- the way: which alt a made piece turned up on, and whether it was queued (#482), the
	-- latter only while the line still asks for the same trait and quality: a changed pick
	-- is a stale queue line, dropped before it spends.
	local plan = PlanLines( analysis )
	if old and analysis.editing and type( old.plan ) == "table" then
		local oldOf = {}
		for _, line in ipairs( old.plan ) do oldOf[ line.id ] = line end
		for _, line in ipairs( plan ) do
			local was = oldOf[ line.id ]
			line.via = line.via or ( was and was.via )
			if was and was.queued and was.pick and line.pick
				and was.pick.trait == line.pick.trait and was.pick.quality == line.pick.quality then line.queued = true end
		end
	end
	BTV.SaveRecord( {
		player = payload.player,
		roster = payload.roster,
		zoneTag = zone.tag,
		pageName = pageName,
		characterId = GetCurrentCharacterId(),
		characterName = CleanName( GetUnitName( "player" ) ),
		payload = payload,
		startedAt = analysis.startedAt or GetTimeStamp(),
		fingerprint = WriteFingerprint( analysis.writes ),
		-- The checklist (#480): one line per piece and place, boxes read live.
		plan = plan,
		flex = flexPicks,
		quality = analysis.missing and analysis.missing.quality,
		perPiece = analysis.missing and analysis.missing.perPiece or false,
		-- The missing-gear picks (#479): the fast path stores the solver's defaults, the
		-- window whatever the player chose on the step.
		missing = MissingPicks( analysis ),
	} )

	-- The debug trace (#483): one import only, so both arms drop here; the trace itself is
	-- saved after the summary below. Only a capture spends the arm: the window analyzes on
	-- Paste and writes later, so an arm set in between waits for the next import.
	if analysis.trace then
		BTV.debugArmed = false
		if BTV.Setting( "debugTrace" ) then BTV.SetSetting( "debugTrace", false ) end
	end

	local summary = analysis.summary
	local written = #analysis.writes
	local verbosity = BTV.Setting( "verbosity" )
	if verbosity == "full" then
		Say( string.format( "%s: %d setups %s on |cFFFFFF%s|r (%s). Auto-swap set.",
			payload.player or "payload", written, reused and "replaced" or "written", pageName, zone.name or zone.tag ) )
		-- Two different problems, so two different numbers: `toFetch` is owned and elsewhere,
		-- `unplaced` is nothing anywhere fits. Counted as demands, not as report lines: one line
		-- can be the same news in several builds (#413).
		if summary.toFetch > 0 or summary.unplaced > 0 then
			Say( string.format( "|cF8FF70%d to fetch|r, |cFF7070%d unplaced|r. |c7B68EE/btv missing|r for details.",
				summary.toFetch, summary.unplaced ) )
		end
	elseif verbosity == "line" then
		-- The locked one-liner (#473). Silent says nothing at all; errors above always speak.
		-- "Missing" is what the plan has to source: nowhere at all, or owned but elsewhere.
		local missing = summary.unplaced + summary.toFetch
		local tail = "All gear found."
		if missing > 0 or summary.traitCount > 0 then
			tail = string.format( "%d missing, %d off trait. |c7B68EE/btv missing|r for details.", missing, summary.traitCount )
		end
		Say( string.format( "Wrote %d setup%s to \"|cFFFFFF%s|r\". %s",
			written, written == 1 and "" or "s", pageName, tail ) )
		-- A flex slot left open because nothing is learned is worth its one line even at
		-- default verbosity (#478); full verbosity already replayed it with the report.
		for _, line in ipairs( analysis.flexWarnings or {} ) do Say( line ) end
	end
	-- Skills with no saved slot on either bar, once the player has saved one (skill placement).
	local placements = BTV.svAccount.placements
	if verbosity ~= "silent" and BTV.Setting( "usePlacements" ) and next( placements ) then
		local names, seen = {}, {}
		for _, write in ipairs( analysis.writes ) do
			for hotbar = 0, 1 do
				for slot = 3, 7 do
					local id = write.raw.skills[ hotbar ][ slot ]
					local key = id and id ~= 0 and BTV.SkillKey( id )
					if key and not seen[ key ] and not placements[ key ] then
						seen[ key ] = true
						table.insert( names, GetAbilityName( id ) )
					end
				end
			end
		end
		if #names > 0 then
			local one = #names == 1
			Say( string.format( "%d skill%s no saved slot: %s. Place %s on your next |c7B68EE/btv|r import, or put %s on your bars and type |c7B68EE/btv remember|r.",
				#names, one and " has" or "s have", table.concat( names, ", " ), one and "it" or "them", one and "it" or "them" ) )
		end
	end
	-- The trace lands next to the record. SavedVariables only reach disk on a reload or
	-- logout, so the instruction says so, at every verbosity: the player asked for this one.
	if analysis.trace then
		analysis.trace.at = GetTimeStamp()
		analysis.trace.player = payload.player
		analysis.trace.pageName = pageName
		BTV.svAccount.trace = analysis.trace
		Say( "debug trace saved. Type |c7B68EE/reloadui|r, then send |cFFFFFFDocuments\\Elder Scrolls Online\\live\\SavedVariables\\"
			.. BTV.name .. ".lua|r." )
	end
	return true
end

-- The fast path (#473): analyze and write in one breath, which is exactly what the old
-- one-piece Import did. The window walks the same two halves with Review in between.
function BTV.Import( text, confirmed )
	BTV.lastReport = {}
	BTV.lastTraits = {}
	-- A slice per frame, so a big roster never holds the game (BTV.RunSliced).
	BTV.RunSliced( function() return BTV.Analyze( text ) end, function() end, function( analysis, why )
		if not analysis then
			Say( why )
			return
		end
		BTV.WriteAnalysis( analysis, confirmed )
	end )
end

-- ------------------------------------------------------------------- the plan

-- The import, matched again from the record's stored payload with the player's picks put
-- back (#480): what Edit picks opens on, and what the plan is read from. No paste, no
-- write, no chat.
function BTV.RestoreAnalysis( record )
	if type( record.payload ) ~= "table" then
		return nil, "|cFF7070the import record holds no payload. Paste the roster again.|r"
	end
	local analysis, why = BTV.AnalyzePayload( record.payload, record.zoneTag )
	if not analysis then return nil, why end
	-- The page the record owns may be the "... 2" that Create made.
	analysis.pageName = record.pageName
	analysis.startedAt = record.startedAt
	for _, block in ipairs( analysis.flex or {} ) do
		local pick = record.flex and record.flex[ block.key ]
		if pick and block.options[ pick ] and block.options[ pick ].learned then block.pick = pick end
	end
	if record.missing and #record.missing > 0 then
		local missing = analysis.missing
		missing.quality = record.quality or missing.quality
		missing.perPiece = record.perPiece or false
		local forced = {}
		for _, pick in ipairs( record.missing ) do
			table.insert( forced, { key = pick.key, quality = missing.perPiece and pick.quality or nil } )
			missing.pathOf[ pick.set ] = pick.path
		end
		BTV.PlanMissing( analysis, forced )
	end
	return analysis
end

-- The checklist's groups: what has to be made or found first, then where gear has to
-- move (owner, 2026-09-14). Pieces already in the bags at import time close the list,
-- folded away.
local GROUP_RANK = { reconstruct = 1, craft = 2, buy = 3, farm = 4, glyph = 5, character = 6, house = 7, bank = 8, guild = 9, unknown = 10, have = 11 }
local function GroupHead( kind, place )
	if kind == "glyph" then return "Put the right glyph on" end
	if kind == "character" then return "Deposit in the bank on " .. place end
	if kind == "house" then return "Fetch from " .. place end
	if kind == "bank" then return "Withdraw at the bank" end
	if kind == "guild" then return "In the guild bank " .. place .. ", BTV never touches those" end
	if kind == "unknown" then return "Somewhere IIfA did not name" end
	if kind == "reconstruct" then return "Reconstruct at a transmute station" end
	if kind == "craft" then return "Craft" end
	if kind == "buy" then return "Buy from a guild trader" end
	if kind == "have" then return "Already in your bags" end
	return "Farm"
end

-- What a created piece's line says after its name.
local function PickDetail( gap, crafter )
	local facts, cand = gap.cand.facts, gap.cand
	local shape = ShapeWords( cand )
	if cand.trait and cand.trait > 0 then shape = shape .. ", " .. TraitName( cand.trait ) end
	if cand.glyph then shape = shape .. ", " .. cand.glyph .. " glyph" end
	local detail = shape
	if gap.path == "reconstruct" and facts.cost then detail = detail .. string.format( ", %d crystals", facts.cost )
	elseif gap.path == "craft" then detail = detail .. ", on " .. ( crafter and crafter.name or "this character" )
	elseif gap.path == "farm" and facts.where then detail = detail .. ", " .. facts.where end
	if gap.fills > 1 then detail = detail .. string.format( ", fills %d setups", gap.fills ) end
	return detail
end

-- The plan is a fixed list saved with the import (owner hand test 2026-09-09): one line
-- per piece and place, never dropped, its box read live from where the piece is now. A
-- line's `where` names what proves it done: "here" is the importing character's bags,
-- "bank" the bank or here, "any" anywhere the account can see. `slots` are the page
-- slots the piece fills once it is here (row, slot, and which copy when a row wants two).
-- A weapon line says its trait and enchant, so two daggers read apart.
local function WeaponDetail( link )
	if ( GetItemLinkWeaponType( link ) or 0 ) == 0 then return nil end
	local detail = TraitName( GetItemLinkTraitInfo( link ) )
	local glyph = GLYPH_WORD[ GlyphOf( link ) or false ]
	if glyph then detail = detail .. ", " .. glyph .. " glyph" end
	return detail
end

PlanLines = function( analysis )
	local lines, byId, byLink = {}, {}, {}
	local function Line( id, spec )
		local line = byId[ id ]
		if not line then
			line = spec
			line.id, line.count, line.slots = id, 0, {}
			byId[ id ] = line
			table.insert( lines, line )
		end
		line.count = line.count + 1
		return line
	end
	local function Piece( piece, kind, place, where )
		local key = LinkKey( piece.link )
		local detail = WeaponDetail( piece.link )
		local line = Line( kind .. "\1" .. ( place or "" ) .. "\1" .. key,
			{ kind = kind, place = place, name = piece.name, link = piece.link, where = where, detail = detail } )
		byLink[ key ] = byLink[ key ] or line
		-- An owned piece wearing none of the glyphs its slots asked for (owner, 2026-09-19).
		if piece.glyphs and not piece.glyphOk then
			line.glyphs = line.glyphs or {}
			for _, word in ipairs( piece.glyphs ) do table.insert( line.glyphs, word ) end
		end
	end
	for _, piece in ipairs( analysis.found.here ) do Piece( piece, "have", nil, "here" ) end
	for _, piece in ipairs( analysis.found.bank ) do Piece( piece, piece.kind or "bank", piece.place, "here" ) end
	for _, piece in ipairs( analysis.found.away ) do
		if piece.kind == "character" then
			-- Deposited is half done: the withdraw row rides on the line (BuildPlan).
			Piece( piece, "character", piece.place, "bank" )
		else
			Piece( piece, piece.kind, piece.kind ~= "bank" and piece.place or nil, "here" )
		end
	end
	-- A piece written with a placeholder fills that slot once it is here.
	for index, write in ipairs( analysis.writes ) do
		for slot, piece in pairs( write.raw.gear ) do
			if slot ~= "mythic" and tostring( piece.id ):find( "^btv%-" ) then
				local line = byLink[ LinkKey( piece.link ) ]
				if line then table.insert( line.slots, { row = index, slot = slot } ) end
			end
		end
	end

	-- Created pieces: one line per set and shape, however many the page wants. A set
	-- crafted on an alt is deposited by that alt (its line carries `via`); a reconstructed
	-- or farmed piece learns its alt when the check first sees it there.
	local missing = analysis.missing
	local crafterOf = {}
	for _, block in ipairs( missing and missing.sets or {} ) do
		if block.path == "craft" and block.crafter and not block.crafter.here then crafterOf[ block.setId ] = block.crafter end
	end
	local rowsOf = {}
	for index, write in ipairs( analysis.writes ) do
		for ei, review in ipairs( analysis.entries ) do
			if review.entry == write.entry then
				rowsOf[ ei ] = rowsOf[ ei ] or {}
				table.insert( rowsOf[ ei ], index )
			end
		end
	end
	for _, gap in ipairs( missing and missing.gaps or {} ) do
		local cand, crafter = gap.cand, gap.path == "craft" and crafterOf[ gap.cand.setId ] or nil
		local line = Line( gap.path .. "\1" .. gap.key, { kind = gap.path, name = cand.facts.name, where = "any",
			-- A crafted or reconstructed piece is made in a chosen trait, so the asked one is
			-- part of done; a farmed or bought one is whatever drops.
			pick = { set = cand.setId, eq = cand.equipType, quality = gap.quality or missing.quality, glyph = cand.glyph,
				trait = cand.trait, needTrait = ( gap.path == "craft" or gap.path == "reconstruct" ) and ( cand.trait or 0 ) > 0 or nil,
				-- The shape, so a station run can name the pattern and the sticker-book piece (#482).
				armor = cand.armorType, weapon = cand.weaponType },
			detail = PickDetail( gap, crafter ) } )
		if crafter then line.via = { key = crafter.id, name = crafter.name } end
		for ei, slotId in pairs( gap.slots ) do
			for _, index in ipairs( rowsOf[ ei ] or {} ) do table.insert( line.slots, { row = index, slot = slotId } ) end
		end
	end

	-- Which copy each slot takes: a row wanting two daggers gets the first and the second.
	for _, line in ipairs( lines ) do
		table.sort( line.slots, function( a, b )
			if a.row ~= b.row then return a.row < b.row end
			return a.slot < b.slot
		end )
		local seen = {}
		for _, ref in ipairs( line.slots ) do
			seen[ ref.row ] = ( seen[ ref.row ] or 0 ) + 1
			ref.n = seen[ ref.row ]
		end
	end
	return lines
end

-- Where everything is now, per place: "here" for the importing character's bags, "bank",
-- a character key for an alt's bags. The bags this client can read are scanned, the rest
-- comes from IIfA in one pass. No matching, so a check costs nothing the player feels
-- (the old full re-match froze the game on every deposit, owner hand test 2026-09-09).
local function Locate( record )
	local at = {}
	local function Put( tag, link, id, n )
		at[ tag ] = at[ tag ] or {}
		table.insert( at[ tag ], { link = link, key = LinkKey( link ), id = id, n = n or 1 } )
	end
	local function Scan( tag, bag )
		for slot = 0, GetBagSize( bag ) do
			local link = GetItemLink( bag, slot, LINK_STYLE_DEFAULT )
			if link and link ~= "" and GetItemLinkSetInfo( link, false ) then
				Put( tag, link, Id64ToString( GetItemUniqueId( bag, slot ) ) )
			end
		end
	end
	local me, importer = LocationKey( GetCurrentCharacterId() ), LocationKey( record.characterId )
	local scanned = { [ me ] = true }
	local myTag = me == importer and "here" or me
	Scan( myTag, BAG_WORN )
	Scan( myTag, BAG_BACKPACK )
	-- The open bank. A coffer is read from IIfA like any other place: the plan fetches
	-- from it, it never counts as the bank.
	local bankKey = IIFA_LOCATION_KEY_BANK or "Bank"
	if IsBankOpen() then
		local bankBag = GetBankingBag()
		if not ( IsHouseBankBag and IsHouseBankBag( bankBag ) ) then
			scanned[ bankKey ] = true
			Scan( "bank", bankBag )
			if bankBag == BAG_BANK and IsESOPlusSubscriber() then Scan( "bank", BAG_SUBSCRIBER_BANK ) end
		end
	end
	local ok, db = pcall( function() return IIfA:GetInventoryDB() end )
	if ok and type( db ) == "table" then
		for key, entry in pairs( db ) do
			if type( key ) == "string" and key:find( "|H", 1, true ) and type( entry ) == "table" and type( entry.locations ) == "table" then
				for location, held in pairs( entry.locations ) do
					local locKey = LocationKey( location )
					local tag = ( locKey == importer and "here" ) or ( locKey == bankKey and "bank" )
						or ( BTV.PlaceKind( locKey ) == "character" and locKey ) or nil
					if tag and not scanned[ locKey ] then
						local n = 0
						if type( held ) == "table" and type( held.bagSlot ) == "table" then
							for _, c in pairs( held.bagSlot ) do n = n + ( tonumber( c ) or 1 ) end
						end
						Put( tag, key, nil, math.max( n, 1 ) )
					end
				end
			end
		end
	end
	return at
end

-- What a link is, read once per check.
local function Info( memo, link )
	local info = memo[ link ]
	if not info then
		local _, _, _, _, _, setId = GetItemLinkSetInfo( link, false )
		info = { link = link, set = setId, eq = GetItemLinkEquipType( link ), cp = GetItemLinkRequiredChampionPoints( link ) or 0,
			quality = GetItemLinkDisplayQuality( link ) or 0, glyph = GlyphOf( link ), trait = GetItemLinkTraitInfo( link ) }
		memo[ link ] = info
	end
	return info
end

-- What a made piece still lacks, or nil when it is at the picked quality wearing the
-- asked glyph. Only CP160 pieces are ever judged: a low level try counts for nothing.
local QUALITY_WORD = { "white", "green", "blue", "purple", "gold" }
local function QualityWord( quality )
	return GetItemQualityColor( quality ):Colorize( QUALITY_WORD[ quality ] or "?" )
end
local function MadeShort( info, pick, anyQuality )
	local short = {}
	local want = pick.quality or ITEM_DISPLAY_QUALITY_LEGENDARY
	if not anyQuality and info.quality < want then table.insert( short, QualityWord( info.quality ) .. ", needs " .. QualityWord( want ) ) end
	local glyph = pick.glyph and GLYPHS[ pick.glyph ]
	if glyph and not SameGlyph( info.glyph, glyph ) then table.insert( short, "needs a " .. pick.glyph .. " glyph" ) end
	-- Only ever said of a farmed or bought piece (a crafted one is made in its trait, so a
	-- copy in another trait is simply not it, and never shown here).
	if ( pick.trait or 0 ) > 0 and info.trait ~= pick.trait then table.insert( short, "needs " .. TraitName( pick.trait ) ) end
	if #short == 0 then return nil end
	return table.concat( short, "; " )
end

-- Copies of a line's piece in the places `where` names: the exact link for a fetched
-- piece; for a made one the set and shape at CP160, at the picked quality, in the asked
-- glyph. Returns the count, the best CP160 copy still short of that, and where a copy
-- was found. Here and the bank are looked at first, so a copy there names the place.
local WHERE = { here = { "here" }, bank = { "bank", "here" } }
local function Tags( at, where )
	if where ~= "any" then return WHERE[ where ] end
	local tags = { "here", "bank" }
	for tag in pairs( at ) do
		if tag ~= "here" and tag ~= "bank" then table.insert( tags, tag ) end
	end
	return tags
end
-- A made copy belongs to the line whose trait it has (owner, 2026-09-14: one crafted
-- dagger must not read as progress on both dagger lines). A copy in the asked trait is
-- claimed by the first line it is progress for, so a sibling line never shows it; a copy
-- in another trait is progress only on a farmed or bought line, as a note.
-- A glyph lives in the link, so a line waiting on one finds its piece with the enchant
-- fields blanked (owner, 2026-09-19), or the piece would vanish the moment the glyph went
-- on. A copy that is exactly another line's piece is never counted: the staff already
-- wearing reduce power must not tick the bare staff's line. The second to last field goes
-- too: it is the charge a weapon glyph fills (owner hand test 2026-09-19, the row never ticked).
local function GlyphBlind( key )
	return key and ( key:gsub( "^(item:%d+:%d+:%d+):%d+:%d+:%d+", "%1:0:0:0" ):gsub( ":%d+(:%d+)$", ":0%1" ) )
end
local function IsLinePiece( memo, line, item )
	if item.key == line.key then return true end
	return line.glyphs ~= nil and not ( memo.lineKeys and memo.lineKeys[ item.key ] )
		and GlyphBlind( item.key ) == GlyphBlind( line.key )
end

local function Have( at, memo, line, where, anyQuality )
	local count, short, found = 0, nil, nil
	for _, tag in ipairs( Tags( at, where ) ) do
		for _, item in ipairs( at[ tag ] or {} ) do
			local hit = false
			if line.pick then
				local info = Info( memo, item.link )
				if info.set == line.pick.set and info.eq == line.pick.eq and info.cp >= 160 then
					local mine = ( line.pick.trait or 0 ) == 0 or info.trait == line.pick.trait
					if MadeShort( info, line.pick, anyQuality ) == nil then hit = true
					elseif mine and not item.taken then
						if not short or short.trait ~= line.pick.trait or info.quality > short.quality then short = info end
						item.taken = true
					elseif not mine and not line.pick.needTrait and not short and not item.taken then
						short = info
					end
				end
			elseif IsLinePiece( memo, line, item ) then
				hit = true
			end
			if hit then
				count = count + item.n
				found = found or tag
			end
		end
	end
	return count, short, found
end

-- The plan (#480): the record's lines with their boxes read from where every piece is
-- now. A line deposited by an alt (a fetched piece on it, a piece made there) grows a
-- withdraw row; a made piece first seen on an alt remembers that alt, so the rows never
-- vanish as gear moves. Groups every box of which is ticked sink to the bottom, and the
-- pieces that were in the bags all along close the list.
function BTV.BuildPlan( record )
	if type( record.plan ) ~= "table" then
		return nil, "|cFF7070this import predates the checklist. Paste the roster again.|r"
	end
	local at, memo = Locate( record ), {}
	local groups, byKey = {}, {}
	-- `link` is the piece's own for a fetched one, the best copy so far for a made one,
	-- so the name reads in the quality it has right now (owner, 2026-09-14).
	local function Row( kind, place, line, have, detail, link )
		local key = kind .. "\1" .. ( place or "" )
		local group = byKey[ key ]
		if not group then
			group = { kind = kind, place = place, head = GroupHead( kind, place ), lines = {} }
			byKey[ key ] = group
			table.insert( groups, group )
		end
		table.insert( group.lines, { name = line.name, link = link or line.link, count = line.count, have = math.min( have, line.count ),
			done = have >= line.count, detail = detail, id = line.id, queued = line.queued, pick = line.pick,
			skipGlyph = kind == "glyph" and line.skipGlyph or nil } )
	end
	local changed = false
	-- Any quality is fine (owner, 2026-09-14): a per-import switch, so a run can go ahead
	-- before every piece is gold.
	local any = record.anyQuality == true
	memo.lineKeys = {}
	for _, line in ipairs( record.plan ) do
		line.key = line.link and LinkKey( line.link ) or nil
		if line.key then memo.lineKeys[ line.key ] = true end
	end
	-- The glyph changed the link, so the line follows its piece: name, link and detail read
	-- as the piece is now (owner hand test 2026-09-19: the deposit row still said no glyph
	-- once it was on). Only when the old link is gone, so a second bare copy keeps its line.
	for _, line in ipairs( record.plan ) do
		if line.glyphs and line.key then
			local exact, moved
			for _, tag in ipairs( Tags( at, "any" ) ) do
				for _, item in ipairs( at[ tag ] or {} ) do
					if item.key == line.key then exact = true
					elseif not moved and IsLinePiece( memo, line, item ) then moved = item end
				end
			end
			if moved and not exact then
				memo.lineKeys[ line.key ] = nil
				line.link, line.key, line.detail = moved.link, moved.key, WeaponDetail( moved.link )
				memo.lineKeys[ line.key ] = true
				changed = true
			end
		end
	end
	for _, line in ipairs( record.plan ) do
		local count, short, found = Have( at, memo, line, line.where, any )
		if line.pick and not line.via and found and found ~= "here" and found ~= "bank" then
			line.via = { key = found, name = PlaceName( found ) }
			changed = true
		end
		local detail = line.detail
		if line.pick and count < line.count and short then
			detail = ( detail and ( detail .. ", " ) or "" ) .. "|cF8FF70in progress:|r " .. MadeShort( short, line.pick, any )
		end
		Row( line.kind, line.place, line, count, detail, short and short.link or nil )
		-- A made copy wearing the wrong glyph gets its own row (owner, 2026-09-15): the
		-- station made it, the glyph goes on by hand at any bench, and the row ticks with
		-- the line once it is on. The line remembers, so the row stays once the glyph is on.
		if line.pick and line.pick.glyph and short and count < line.count and not SameGlyph( short.glyph, GLYPHS[ line.pick.glyph ] ) then
			line.needsGlyph = true
			changed = true
		end
		if line.needsGlyph then Row( "glyph", nil, line, line.skipGlyph and line.count or count, "needs a " .. line.pick.glyph .. " glyph", short and short.link or nil ) end
		-- An owned piece in the wrong glyph, or in none (owner, 2026-09-19): its own row, ticked
		-- by the copies anywhere that wear a glyph one of its slots asked for.
		-- ponytail: a line of several copies counts any asked glyph on any copy, not one per
		-- slot. Split the line per ask if two identical bare pieces ever want two glyphs.
		if line.glyphs then
			local right = 0
			for _, tag in ipairs( Tags( at, "any" ) ) do
				for _, item in ipairs( at[ tag ] or {} ) do
					if IsLinePiece( memo, line, item ) then
						for _, word in ipairs( line.glyphs ) do
							if SameGlyph( Info( memo, item.link ).glyph, GLYPHS[ word ] ) then right = right + item.n break end
						end
					end
				end
			end
			Row( "glyph", nil, line, line.skipGlyph and line.count or right, "needs a " .. table.concat( line.glyphs, " or " ) .. " glyph" )
		end
		-- A made piece's deposit and withdraw rows wait until one exists: nothing to
		-- deposit yet reads as noise (owner, 2026-09-14). A piece on an alt is a deposit
		-- row first; its withdraw row appears once a copy is in the bank or here (owner
		-- hand test 2026-09-15), and stays: the bank count includes here.
		local via = line.via and ( not line.pick or count > 0 )
		if via then Row( "character", line.via.name, line, ( Have( at, memo, line, "bank", any ) ), line.detail ) end
		if via or ( line.kind == "character" and count > 0 ) then Row( "bank", nil, line, ( Have( at, memo, line, "here", any ) ), line.detail ) end
	end

	local left, total = 0, 0
	for _, group in ipairs( groups ) do
		group.done = true
		for _, line in ipairs( group.lines ) do
			if not line.done then group.done = false end
			if group.kind ~= "have" then
				total = total + 1
				if not line.done then left = left + 1 end
			end
		end
	end
	table.sort( groups, function( a, b )
		local ka = a.kind == "have" and 3 or ( a.done and 2 or 1 )
		local kb = b.kind == "have" and 3 or ( b.done and 2 or 1 )
		if ka ~= kb then return ka < kb end
		if GROUP_RANK[ a.kind ] ~= GROUP_RANK[ b.kind ] then return ( GROUP_RANK[ a.kind ] or 10 ) < ( GROUP_RANK[ b.kind ] or 10 ) end
		return ( a.place or "" ) < ( b.place or "" )
	end )
	return { groups = groups, left = left, total = total, done = left == 0, pageName = record.pageName,
		startedAt = record.startedAt, anyQuality = any, changed = changed, at = at, memo = memo }
end

-- The silent slot fill (#480): a slot written empty for a piece nobody owned, or with a
-- fetch placeholder (#413, WW swaps by unique id and the placeholder never resolves),
-- gets the piece the moment it is in this character's bags, across every waiting row at
-- once. Only such slots are ever touched, so a hand edit is never overwritten, and the
-- fingerprint follows so the page still reads as ours.
local function Waiting( piece )
	return piece == nil or tostring( piece.id ):find( "^btv%-" ) ~= nil
end

-- A better copy of the same set and shape: the gold pair made after a purple try
-- (owner hand test 2026-09-09). Same set and equip type only, so a hand-placed piece of
-- another set is never touched.
local function Outranked( stored, live )
	if not stored or not stored.link or LinkKey( stored.link ) == LinkKey( live.link ) then return false end
	local _, _, _, _, _, storedSet = GetItemLinkSetInfo( stored.link, false )
	local _, _, _, _, _, liveSet = GetItemLinkSetInfo( live.link, false )
	if storedSet ~= liveSet or GetItemLinkEquipType( stored.link ) ~= GetItemLinkEquipType( live.link ) then return false end
	local storedCp, liveCp = GetItemLinkRequiredChampionPoints( stored.link ) or 0, GetItemLinkRequiredChampionPoints( live.link ) or 0
	if storedCp < liveCp then return true end
	return storedCp == liveCp and ( GetItemLinkDisplayQuality( stored.link ) or 0 ) < ( GetItemLinkDisplayQuality( live.link ) or 0 )
end

-- A copy of a line's piece for the fill and the moves (#481): the exact item data for a
-- fetched piece; the set and shape at CP160, in the asked trait, for a made one, whatever
-- its quality (the gold one replaces it later, Outranked).
local function IsCopy( memo, line, item )
	if line.pick then
		local info = Info( memo, item.link )
		return info.set == line.pick.set and info.eq == line.pick.eq and info.cp >= 160
			and ( not line.pick.needTrait or info.trait == line.pick.trait )
	end
	return IsLinePiece( memo, line, item )
end

local function FillSlots( record, at, memo )
	local zone = WW.zones[ record.zoneTag ]
	local pageId = zone and BTV.FindPage( zone, record.pageName )
	if not pageId then return end
	local rows = WW.setups[ zone.tag ] and WW.setups[ zone.tag ][ pageId ] or {}
	-- A hand-edited page still gets its empty slots filled, but keeps reading as edited,
	-- so the next rewrite still asks.
	local ours = BTV.PageMatchesRecord( zone, record.pageName )
	local filled, names, seen = {}, {}, {}
	for _, line in ipairs( record.plan ) do
		if #line.slots > 0 then
			-- The copies in the bags, best first. A made piece fills as soon as a CP160 copy
			-- exists, whatever its quality, and the gold one replaces it later (Outranked).
			local copies = {}
			for _, item in ipairs( at.here or {} ) do
				if item.id and IsCopy( memo, line, item ) then table.insert( copies, item ) end
			end
			table.sort( copies, function( a, b )
				local qa, qb = Info( memo, a.link ).quality, Info( memo, b.link ).quality
				if qa ~= qb then return qa > qb end
				return a.id < b.id
			end )
			for _, ref in ipairs( line.slots ) do
				local copy, stored = copies[ ref.n ], rows[ ref.row ]
				if copy and stored and stored.gear and ( Waiting( stored.gear[ ref.slot ] ) or Outranked( stored.gear[ ref.slot ], copy ) ) then
					stored.gear[ ref.slot ] = { id = copy.id, link = copy.link }
					filled[ ref.row ] = true
					local name = CleanName( GetItemLinkName( copy.link ) )
					if not seen[ name ] then
						seen[ name ] = true
						table.insert( names, name )
					end
				end
			end
		end
	end
	local count = 0
	for _ in pairs( filled ) do count = count + 1 end
	if count == 0 then return end
	WW.markers.BuildGearList()
	if WW.selection.zone == zone and WW.selection.pageId == pageId then
		WW.gui.BuildPage( zone, pageId, true )
	end
	if ours then record.fingerprint = LiveFingerprint( zone, pageId ) end
	if BTV.Setting( "verbosity" ) ~= "silent" then
		Say( string.format( "Filled %d setup%s with %s.", count, count == 1 and "" or "s", table.concat( names, ", " ) ) )
	end
end

-- What one click moves through the open bank or coffer (#481). On the importing
-- character the line's copies still short here come out of the container (fetch); on any
-- other character its backpack copies of lines still short at the importer or in the
-- bank go in (deposit). Guild banks never fire EVENT_OPEN_BANK, so they never get here.
-- Nil when no import is in progress or nothing is open.
-- ponytail: an alt depositing into a coffer ticks nothing until the importer fetches from
-- it (character lines are proved by the bank or here); Fetch still finds it there.
function BTV.Moves( plan )
	local record = BTV.GetRecord()
	if not record or not plan or type( record.plan ) ~= "table" or not IsBankOpen() or BTV.moving then return nil end
	local bag = GetBankingBag()
	local coffer = IsHouseBankBag and IsHouseBankBag( bag )
	local fetch = record.characterId == GetCurrentCharacterId()
	local vault = { bag }
	if bag == BAG_BANK and IsESOPlusSubscriber() then table.insert( vault, BAG_SUBSCRIBER_BANK ) end
	local from, into = fetch and vault or { BAG_BACKPACK }, fetch and { BAG_BACKPACK } or vault
	local counted = fetch and { "here" } or { "here", "bank" }
	local items, used, memo = {}, {}, plan.memo
	for _, line in ipairs( record.plan ) do
		local short = line.count
		for _, tag in ipairs( counted ) do
			for _, item in ipairs( plan.at[ tag ] or {} ) do
				if IsCopy( memo, line, item ) then short = short - item.n end
			end
		end
		for _, b in ipairs( from ) do
			for slot = 0, GetBagSize( b ) - 1 do
				if short > 0 and not ( used[ b ] and used[ b ][ slot ] ) then
					local link = GetItemLink( b, slot, LINK_STYLE_DEFAULT )
					if link and link ~= "" and GetItemLinkSetInfo( link, false )
						and IsCopy( memo, line, { link = link, key = LinkKey( link ) } ) then
						used[ b ] = used[ b ] or {}
						used[ b ][ slot ] = true
						table.insert( items, { bag = b, slot = slot, link = link } )
						short = short - 1
					end
				end
			end
		end
	end
	local place = coffer and PlaceName( LocationKey( GetCollectibleForBag( bag ) ) )
		or ContainerName( IIFA_LOCATION_KEY_BANK or "Bank" )
	return { dir = fetch and "fetch" or "deposit", place = place, items = items, into = into }
end

-- The move itself: one RequestMoveItem per piece into the next free slot, the pattern WW
-- uses for the bank and the probe proved on a coffer (docs/plans/2026-09-02-risk-probe.md).
-- Stops the moment the destination has no free slot and says how many are left.
-- ponytail: paced by a fixed 250ms, not the slot event (a move landed in ~200ms on the
-- PTS); a slow server could hand out one free slot twice and drop a move. Upgrade path:
-- step on EVENT_INVENTORY_SINGLE_SLOT_UPDATE for the last move's destination.
function BTV.MoveGear( moves )
	local verb, where = moves.dir == "fetch" and "Fetched" or "Deposited", moves.dir == "fetch" and "from" or "in"
	local index, moved = 0, 0
	-- No second list (and no button) while this one runs: a click mid-run would send the
	-- same pieces to the same free slot. The check at the end brings the button back.
	BTV.moving = true
	local function Done( line )
		BTV.moving = false
		if line then Say( line ) end
		BTV.CheckPlan()
	end
	local function FreeSlot()
		for _, bag in ipairs( moves.into ) do
			for slot = 0, GetBagSize( bag ) - 1 do
				local link = GetItemLink( bag, slot, LINK_STYLE_DEFAULT )
				if link == nil or link == "" then return bag, slot end
			end
		end
	end
	local function Step()
		-- A cancelled import (#535) stops the move at its next piece.
		if not BTV.GetRecord() then Done() return end
		index = index + 1
		local item = moves.items[ index ]
		if not item then
			Done( moved > 0 and BTV.Setting( "verbosity" ) ~= "silent"
				and string.format( "%s %d %s %s.", verb, moved, where, moves.place ) or nil )
			return
		end
		local bag, slot = FreeSlot()
		if not bag then
			-- A stop always prints: the player is standing there wondering.
			Done( string.format( "%s: %s %d of %d, %d left.", moves.dir == "fetch" and "Backpack full" or ( moves.place .. " is full" ),
				verb:lower(), moved, #moves.items, #moves.items - moved ) )
			return
		end
		-- A refused move (a locked piece, say) is not a moved one.
		if CallSecureProtected( "RequestMoveItem", item.bag, item.slot, bag, slot, 1 ) then moved = moved + 1 end
		zo_callLater( Step, 250 )
	end
	Step()
end

-- The live check (#480): the plan as of now, waiting slots filled, and the record finished
-- the first time every box is ticked. Nil when no import is in progress.
function BTV.CheckPlan()
	local record = BTV.GetRecord()
	if not record then return nil end
	local plan, why = BTV.BuildPlan( record )
	if not plan then
		Say( why )
		return nil
	end
	if record.characterId == GetCurrentCharacterId() then
		FillSlots( record, plan.at, plan.memo )
		if plan.done then
			if not record.doneAt and BTV.Setting( "verbosity" ) ~= "silent" then
				Say( string.format( "Import done: every piece for \"|cFFFFFF%s|r\" is in your bags.", record.pageName ) )
			end
			BTV.FinishRecord()
		end
	end
	if BTV.OnPlanChanged then BTV.OnPlanChanged( plan ) end
	return plan
end

-- Bag changes drive the ticks. Only set pieces landing in the backpack or on the body
-- matter, and looting fires in bursts, so the game filters the event per bag and the
-- check is coalesced.
local checkPending = false
local function OnBagChanged( _, bag, slot )
	if not BTV.GetRecord() or checkPending then return end
	-- An emptied slot is a piece gone (destroyed, deposited, sold), which can untick a
	-- box; a filled one only matters when it holds a set piece.
	local link = GetItemLink( bag, slot, LINK_STYLE_DEFAULT )
	if link and link ~= "" and not GetItemLinkSetInfo( link, false ) then return end
	checkPending = true
	zo_callLater( function()
		checkPending = false
		BTV.CheckPlan()
	end, 750 )
end

-- The banker's greeting is skipped while an import is in progress (owner hand test
-- 2026-09-15, the way Lazy Writ Crafter does it): the option that opens the bank is
-- picked for the player. Only with something to fetch or deposit, so a banker visited
-- for anything else still talks.
local function OnChatterBegin( _, optionCount )
	if not BTV.GetRecord() or not BTV.Setting( "autoOpen" ) then return end
	for i = 1, optionCount do
		local _, optionType = GetChatterOption( i )
		if optionType == CHATTER_START_BANK then
			SelectChatterOption( i )
			return
		end
	end
end

-- A bank or coffer opening or closing (#480, #481): the check runs (what the match can
-- see changed), then, with something to move through it, the plan opens itself and the
-- auto setting moves it at once. A window that opened itself closes with the container.
local function OnBankChanged( event )
	if not BTV.GetRecord() then return end
	local plan = BTV.CheckPlan()
	if event == EVENT_CLOSE_BANK then
		if BTV.OnContainerClosed then BTV.OnContainerClosed() end
		return
	end
	local moves = BTV.Moves( plan )
	if not moves or #moves.items == 0 then return end
	-- Auto deposit/withdraw always shows the window (owner, 2026-10-24): gear never moves
	-- with nothing on screen saying why.
	if ( BTV.Setting( "autoOpen" ) or BTV.Setting( "autoDeposit" ) ) and BTV.OpenWindow then BTV.OpenWindow( "plan", true ) end
	if BTV.Setting( "autoDeposit" ) then BTV.MoveGear( moves ) end
end

-- ------------------------------------------------------------------ the queues

-- The craft and reconstruct queues (#482). A queued line is a flag on the record's plan
-- line, so it survives logout with the record; the station runs below are what spend
-- it. Queueing is always a click on the plan, and Write spends nothing.
-- `on` sets the flag outright (the group head's queue all / unqueue all); nil flips it.
function BTV.ToggleQueue( id, on )
	local record = BTV.GetRecord()
	for _, line in ipairs( record and record.plan or {} ) do
		if line.id == id then
			if on == nil then on = not line.queued end
			line.queued = on or nil
		end
	end
end

-- A glyph row the player does not care about is ticked by hand (owner, 2026-09-19), and
-- unticked the same way. On the line, so it is this import's call and nothing else's.
function BTV.ToggleGlyphSkip( id )
	local record = BTV.GetRecord()
	for _, line in ipairs( record and record.plan or {} ) do
		if line.id == id then line.skipGlyph = not line.skipGlyph or nil end
	end
end

-- Copies of a made line that exist anywhere, whatever their quality or glyph. A station
-- makes the number the sheet asks for and no more: the glyph (and a quality the craft
-- could not reach) is the player's to fix by hand, so the box stays open without another
-- copy being made (owner hand test 2026-09-15: the transmute station made copy after copy).
local function Made( plan, line )
	local n = 0
	for _, items in pairs( plan.at ) do
		for _, item in ipairs( items ) do
			if IsCopy( plan.memo, line, item ) then n = n + item.n end
		end
	end
	return n
end

-- The next queued row of a kind still short of copies, skipping what this station visit
-- already tried.
local function NextQueued( plan, kind, tried )
	for _, group in ipairs( plan.groups ) do
		if group.kind == kind then
			for _, row in ipairs( group.lines ) do
				if row.queued and not row.done and row.pick and not tried[ row.id ] and Made( plan, row ) < row.count then return row end
			end
		end
	end
end

-- LibLazyCrafting's own pattern index for a made piece and the station it is made at
-- (its Smithing.lua weaponTypes and getPatternInfo): weapons per station, armor chest 1
-- to waist 7 then light +1 (the robe stays 1), medium +8, heavy +7; ring 1, neck 2.
local WEAPON_PATTERN = {
	[ WEAPONTYPE_AXE ] = 1, [ WEAPONTYPE_HAMMER ] = 2, [ WEAPONTYPE_SWORD ] = 3, [ WEAPONTYPE_TWO_HANDED_AXE ] = 4,
	[ WEAPONTYPE_TWO_HANDED_HAMMER ] = 5, [ WEAPONTYPE_TWO_HANDED_SWORD ] = 6, [ WEAPONTYPE_DAGGER ] = 7,
	[ WEAPONTYPE_BOW ] = 1, [ WEAPONTYPE_SHIELD ] = 2, [ WEAPONTYPE_FIRE_STAFF ] = 3, [ WEAPONTYPE_FROST_STAFF ] = 4,
	[ WEAPONTYPE_LIGHTNING_STAFF ] = 5, [ WEAPONTYPE_HEALING_STAFF ] = 6,
}
local ARMOR_OFFSET = { [ ARMORTYPE_LIGHT ] = 1, [ ARMORTYPE_MEDIUM ] = 8, [ ARMORTYPE_HEAVY ] = 7 }
local function CraftPattern( pick )
	if ( pick.weapon or 0 ) > 0 then
		local line = WEAPON_LINE[ pick.weapon ]
		return line and line[ 1 ], WEAPON_PATTERN[ pick.weapon ]
	end
	if pick.eq == EQUIP_TYPE_RING then return CRAFTING_TYPE_JEWELRYCRAFTING, 1 end
	if pick.eq == EQUIP_TYPE_NECK then return CRAFTING_TYPE_JEWELRYCRAFTING, 2 end
	local base, craft = ARMOR_LINE[ pick.eq ], ARMOR_CRAFT[ pick.armor ]
	if not base or not craft then return nil end
	if pick.armor == ARMORTYPE_LIGHT and pick.eq == EQUIP_TYPE_CHEST then return craft[ 1 ], 1 end
	return craft[ 1 ], base + ARMOR_OFFSET[ pick.armor ]
end
-- The same guard for a plan row, so the plan says it before a station does.
function BTV.PickBlock( pick ) return BTV.CraftBlock( ( CraftPattern( pick ) ) ) end

-- ponytail: ITEMSTYLE ids equal the race ids except Imperial (race 10, style 34), and a
-- racial style is always known (the probe crafted with it, docs/plans/2026-09-02-risk-probe.md).
local RACE_STYLE = { [ 10 ] = 34 }

-- One line at a time: the next queued craft row for the open station goes to
-- LibLazyCrafting, and the next only once that one is made or refused.
-- ponytail: a refused line waits for the next station visit rather than being retried.
local function CraftNext()
	local run = BTV.crafting
	if not run then return end
	run.reference, run.row = nil, nil
	local plan = BTV.CheckPlan()
	if not plan then
		BTV.crafting = nil
		return
	end
	while true do
		local row = NextQueued( plan, "craft", run.tried )
		if not row then return end
		local craft, pattern = CraftPattern( row.pick )
		-- The guard rail: nothing is crafted on a character short of the passives, said once
		-- per station visit.
		local block = craft == run.station and BTV.CraftBlock( craft )
		if block then
			if not run.warned then
				Say( string.format( "Auto craft is off at this station: %s. Swap to a character with the passives, or learn them.", block ) )
			end
			run.warned = true
		elseif craft == run.station and pattern then
			local race = GetUnitRaceId( "player" )
			run.reference, run.row = "btv:" .. row.id, row
			-- CP160, the pick's trait (the game's index is the trait type plus one) at the
			-- pick's quality, in this character's racial style, crafted now.
			BTV.llc:CraftSmithingItemByLevel( pattern, true, 160, RACE_STYLE[ race ] or race, ( row.pick.trait or 0 ) + 1, false,
				craft, row.pick.set, row.pick.quality or ITEM_DISPLAY_QUALITY_LEGENDARY, true, run.reference )
			return
		end
		run.tried[ row.id ] = true
	end
end

-- LibLazyCrafting's answer. Success is filtered by our reference; "no further craft
-- possible" for this station while ours is pending means this line cannot be made here
-- yet (the probe's reading), and stray ones arrive for other stations while walking a
-- master station, so those are ignored.
-- The next line is handed over a moment later, never inside this callback: the library
-- starts the new white piece at once when a request lands, then, back in its own code,
-- clears its current-craft record, so the piece it just started is never improved
-- (owner hand test 2026-09-15: the second of two pieces stayed white).
local function OnCraftResult( event, station, result )
	local run = BTV.crafting
	if not run or not run.reference then return end
	if event == LLC_CRAFT_SUCCESS then
		if not result or result.reference ~= run.reference then return end
		if BTV.Setting( "verbosity" ) ~= "silent" then Say( "Crafted " .. run.row.name .. "." ) end
		run.reference = nil
		zo_callLater( CraftNext, 250 )
	elseif event == LLC_NO_FURTHER_CRAFT_POSSIBLE and station == run.station then
		BTV.llc:cancelItemByReference( run.reference )
		Say( string.format( "Can't craft %s here yet: research, materials, or the wrong station.", run.row.name ) )
		run.tried[ run.row.id ] = true
		run.reference = nil
		zo_callLater( CraftNext, 250 )
	end
end

local SMITHING = { [ CRAFTING_TYPE_BLACKSMITHING ] = true, [ CRAFTING_TYPE_CLOTHIER ] = true,
	[ CRAFTING_TYPE_WOODWORKING ] = true, [ CRAFTING_TYPE_JEWELRYCRAFTING ] = true }
local function OnStationOpened( _, craftingType )
	if not BTV.GetRecord() or not BTV.Setting( "autoCraft" ) or not SMITHING[ craftingType ] or not LibLazyCrafting then return end
	BTV.llc = BTV.llc or LibLazyCrafting:AddRequestingAddon( BTV.name, true, OnCraftResult )
	BTV.crafting = { station = craftingType, tried = {} }
	CraftNext()
end

local function OnStationClosed()
	local run = BTV.crafting
	if run and run.reference then BTV.llc:cancelItemByReference( run.reference ) end
	BTV.crafting = nil
end

-- Cancel import (owner, 2026-10-24): the active import stops and goes to Past imports,
-- not done, like a replaced one, so it can be picked up again. A bank move stops at
-- its next piece; a queued craft is pulled from LibLazyCrafting.
function BTV.CancelRecord()
	local record = BTV.svAccount.record
	if not record then return end
	local run = BTV.crafting
	if run and run.reference then BTV.llc:cancelItemByReference( run.reference ) end
	BTV.crafting, BTV.reconstructing = nil, nil
	PushHistory( record )
	BTV.svAccount.record = nil
	if BTV.OnRecordChanged then BTV.OnRecordChanged() end
end

-- Reconstruction runs itself at an open transmute station: one request at a time, the
-- pick's trait and quality in the call, the next once EVENT_RECONSTRUCT_RESPONSE answers
-- (the probe settled both). A short balance says what is short and skips the line.
-- ponytail: a response that never comes holds the run until the station closes.
local function ReconstructNext()
	local run = BTV.reconstructing
	if not run then return end
	run.row = nil
	local plan = BTV.CheckPlan()
	if not plan then
		BTV.reconstructing = nil
		return
	end
	while true do
		local row = NextQueued( plan, "reconstruct", run.tried )
		if not row then return end
		run.tried[ row.id ] = true
		local pick = row.pick
		local piece = CollectionPiece( { setId = pick.set, equipType = pick.eq, armorType = pick.armor, weaponType = pick.weapon } )
		local cost = GetItemReconstructionCurrencyOptionCost( pick.set, CURT_CHAOTIC_CREATIA ) or 0
		local balance = GetCurrencyAmount( CURT_CHAOTIC_CREATIA, GetCurrencyPlayerStoredLocation( CURT_CHAOTIC_CREATIA ) ) or 0
		if not piece then
			Say( row.name .. " is not in your sticker book." )
		elseif balance < cost then
			Say( string.format( "Reconstructing %s needs %d crystals, you have %d.", row.name, cost, balance ) )
		else
			run.row = row
			RequestItemReconstruction( piece.pieceId, pick.trait or ITEM_TRAIT_TYPE_NONE,
				pick.quality or ITEM_DISPLAY_QUALITY_LEGENDARY, CURT_CHAOTIC_CREATIA )
			return
		end
	end
end

local function OnReconstructResponse( _, result )
	local run = BTV.reconstructing
	local row = run and run.row
	if not row then return end
	if result == RECONSTRUCT_RESPONSE_SUCCESS then
		-- A line wanting two copies gets its second.
		run.tried[ row.id ] = nil
		if BTV.Setting( "verbosity" ) ~= "silent" then Say( "Reconstructed " .. row.name .. "." ) end
	else
		Say( string.format( "Reconstructing %s failed (code %s).", row.name, tostring( result ) ) )
	end
	ReconstructNext()
end

local function OnTransmuteOpened()
	if not BTV.GetRecord() or not BTV.Setting( "autoCraft" ) then return end
	BTV.reconstructing = { tried = {} }
	ReconstructNext()
end

local function OnTransmuteClosed()
	BTV.reconstructing = nil
end

-- ------------------------------------------------------------------ command

local function OpenDialog()
	local WWT = WW.transfer
	-- ponytail: WW's own paste dialog, retitled, its import button pointed at us. WW
	-- reinstalls its own handler every time it opens the dialog itself, so nothing here
	-- outlives this paste. Build our own window only if that stops being true.
	WWT.ShowImportDialog( WW.selection.zone, WW.selection.pageId, 1 )
	WWT.title:SetText( "BTV IMPORT" )
	WWT.editBox:SetMaxInputChars( BTV.PASTE_LIMIT ) -- a whole run is far past WW's 1000 char budget
	WWT.importButton:SetHandler( "OnClicked", function()
		WWT.dialogWindow:SetHidden( true )
		BTV.Import( WWT.editBox:GetText() )
	end )
end

-- ---------------------------------------------------------------- self check

local function SelfCheck()
	local function Body( slot, set ) return { slot = slot, kind = "body", set = set } end
	local function Item( setId, equipType, trait, armorType, weaponType )
		return { setId = setId, equipType = equipType, trait = trait, armorType = armorType, weaponType = weaponType, rank = 5 }
	end
	local function Count( placed, demands )
		local n = 0
		for i = 1, #demands do if placed[ i ] then n = n + 1 end end
		return n
	end
	-- every body slot medium and Divines, every jewelry slot Bloodthirsty
	local function Req( extra )
		local req = {}
		for _, slotId in ipairs( BODY_ORDER ) do
			req[ slotId ] = JEWELRY_SLOTS[ slotId ] and { trait = 31 } or { trait = 18, weight = "medium" }
		end
		for slotId, want in pairs( extra or {} ) do req[ slotId ] = want end
		return req
	end
	local MEDIUM, HEAVY, LIGHT = ARMORTYPE_MEDIUM, ARMORTYPE_HEAVY, ARMORTYPE_LIGHT

	-- 1. body and jewelry are one pool, so a set reaches the jewelry the player owns and
	-- the other set takes the hands
	local demands = { Body( EQUIP_SLOT_HAND, 1 ), Body( EQUIP_SLOT_RING1, 2 ) }
	local pool = { Item( 1, EQUIP_TYPE_RING, 31 ), Item( 2, EQUIP_TYPE_HAND, 18, MEDIUM ) }
	local placed = BTV.Solve( demands, pool, Req() )
	assert( Count( placed, demands ) == 2, "1: body and jewelry are one pool" )
	assert( placed[ 1 ].slot == EQUIP_SLOT_RING1 and placed[ 2 ].slot == EQUIP_SLOT_HAND, "1: they swapped slots" )

	-- 2. a heavy set cannot take a body slot in a build that wears no heavy at all, but its
	-- jewelry is still fair game. Since rule 13 the weight is not rejected slot by slot, it is
	-- the budget that stops it: `Req()` asks for medium everywhere, so the build's heavy
	-- allowance is zero and there is none to spend.
	demands = { Body( EQUIP_SLOT_CHEST, 3 ), Body( EQUIP_SLOT_RING1, 3 ) }
	pool = { Item( 3, EQUIP_TYPE_CHEST, 18, HEAVY ), Item( 3, EQUIP_TYPE_LEGS, 18, HEAVY ), Item( 3, EQUIP_TYPE_RING, 31 ) }
	assert( Count( BTV.Solve( demands, pool, Req() ), demands ) == 1, "2: a weight the build never asked for is never worn" )

	-- 3. jewelry trait is a preference, not a demand (#401): the off-trait ring is slotted
	-- rather than reported as a miss, and the one in trait is still picked first
	demands = { Body( EQUIP_SLOT_RING1, 4 ), Body( EQUIP_SLOT_RING2, 4 ) }
	pool = { Item( 4, EQUIP_TYPE_RING, 21 ), Item( 4, EQUIP_TYPE_RING, 31 ) }
	placed = BTV.Solve( demands, pool, Req() )
	assert( Count( placed, demands ) == 2, "3: an off-trait ring is still slotted" )
	assert( placed[ 1 ].item.trait == 31, "3: the ring in the asked-for trait goes first" )

	-- 4. weapons and body never trade, either way
	demands = { { slot = EQUIP_SLOT_MAIN_HAND, kind = "weapon", set = 5 } }
	pool = { Item( 5, EQUIP_TYPE_CHEST, 18, MEDIUM ) }
	local req = Req( { [ EQUIP_SLOT_MAIN_HAND ] = { trait = 26, eq = EQUIP_TYPE_ONE_HAND } } )
	assert( Count( BTV.Solve( demands, pool, req ), demands ) == 0, "4: a chest cannot fill a weapon slot" )
	demands = { Body( EQUIP_SLOT_CHEST, 5 ) }
	pool = { Item( 5, EQUIP_TYPE_ONE_HAND, 26, nil, WEAPONTYPE_DAGGER ) }
	assert( Count( BTV.Solve( demands, pool, req ), demands ) == 0, "4: a dagger cannot fill a body slot" )

	-- 5. global, not first-fit. A takes the chest so B can have the only head.
	demands = { Body( EQUIP_SLOT_HEAD, 6 ), Body( EQUIP_SLOT_CHEST, 7 ) }
	pool = { Item( 6, EQUIP_TYPE_HEAD, 18, MEDIUM ), Item( 6, EQUIP_TYPE_CHEST, 18, MEDIUM ), Item( 7, EQUIP_TYPE_HEAD, 18, MEDIUM ) }
	assert( Count( BTV.Solve( demands, pool, Req() ), demands ) == 2, "5: global matching" )

	-- 6. the exact trait wins when both are on offer
	demands = { Body( EQUIP_SLOT_CHEST, 8 ) }
	pool = { Item( 8, EQUIP_TYPE_CHEST, 11, MEDIUM ), Item( 8, EQUIP_TYPE_CHEST, 18, MEDIUM ) }
	assert( BTV.Solve( demands, pool, Req() )[ 1 ].item.trait == 18, "6: exact trait preferred" )

	-- 7. a mythic ignores what the slot asks for, because its own trait and weight are fixed
	-- by the game and there is only ever one of it. Weight is the live half of that now that
	-- jewelry trait is a preference (#401), so a heavy mythic goes in a medium slot.
	demands = { Body( EQUIP_SLOT_CHEST, 11 ) }
	pool = { Item( 11, EQUIP_TYPE_CHEST, 21, HEAVY ) }
	pool[ 1 ].mythic = true
	assert( Count( BTV.Solve( demands, pool, Req() ), demands ) == 1, "7: a mythic ignores the weight" )
	pool[ 1 ].mythic = false
	assert( Count( BTV.Solve( demands, pool, Req() ), demands ) == 0, "7: anything else does not" )

	-- 8. a piece past the set's cap never takes a slot another set still needs. Set 12
	-- caps at 1 and the roster asks for 2, so its second piece waits its turn.
	demands = { Body( EQUIP_SLOT_HEAD, 12 ), Body( EQUIP_SLOT_CHEST, 12 ), Body( EQUIP_SLOT_CHEST, 13 ) }
	pool = { Item( 12, EQUIP_TYPE_HEAD, 18, MEDIUM ), Item( 12, EQUIP_TYPE_CHEST, 18, MEDIUM ), Item( 13, EQUIP_TYPE_CHEST, 18, MEDIUM ) }
	pool[ 1 ].maxEquipped, pool[ 2 ].maxEquipped, pool[ 3 ].maxEquipped = 1, 1, 5
	placed = BTV.Solve( demands, pool, Req() )
	assert( placed[ 3 ] and placed[ 3 ].item.setId == 13, "8: the capped set must not squat on the chest" )
	assert( placed[ 2 ] == nil, "8: the surplus piece is the one that goes without" )

	-- 9. most constrained first: the monster set only fits where its one owned piece goes,
	-- so it chooses before a five-piece set that has options
	demands = { Body( EQUIP_SLOT_SHOULDERS, 14 ), Body( EQUIP_SLOT_WAIST, 14 ), Body( EQUIP_SLOT_HEAD, 15 ) }
	pool = { Item( 14, EQUIP_TYPE_SHOULDERS, 18, MEDIUM ), Item( 14, EQUIP_TYPE_WAIST, 18, MEDIUM ),
		Item( 15, EQUIP_TYPE_SHOULDERS, 18, MEDIUM ) }
	pool[ 1 ].maxEquipped, pool[ 2 ].maxEquipped, pool[ 3 ].maxEquipped = 5, 5, 2
	placed = BTV.Solve( demands, pool, Req() )
	assert( placed[ 3 ] and placed[ 3 ].slot == EQUIP_SLOT_SHOULDERS, "9: the monster set gets its piece" )

	-- 10. a perfected piece stands in for the plain set the roster asked for, and is
	-- preferred over the plain one when both are owned. The pairing comes from the game,
	-- so this has to be a real pair: Arms of Relequen 389, its perfected form 393.
	demands = { Body( EQUIP_SLOT_CHEST, 389 ) }
	pool = { Item( 393, EQUIP_TYPE_CHEST, 18, MEDIUM ) }
	assert( Count( BTV.Solve( demands, pool, Req() ), demands ) == 1, "10: perfected stands in for plain" )
	pool = { Item( 389, EQUIP_TYPE_CHEST, 18, MEDIUM ), Item( 393, EQUIP_TYPE_CHEST, 18, MEDIUM ) }
	assert( BTV.Solve( demands, pool, Req() )[ 1 ].item.setId == 393, "10: perfected wins when both are owned" )

	-- 11. the counts hold. Two of set 9 stays two, however many spare pieces are owned.
	demands = { Body( EQUIP_SLOT_CHEST, 9 ), Body( EQUIP_SLOT_LEGS, 9 ), Body( EQUIP_SLOT_FEET, 10 ) }
	pool = { Item( 9, EQUIP_TYPE_CHEST, 18, MEDIUM ), Item( 9, EQUIP_TYPE_LEGS, 18, MEDIUM ),
		Item( 9, EQUIP_TYPE_FEET, 18, MEDIUM ), Item( 10, EQUIP_TYPE_FEET, 18, MEDIUM ) }
	placed = BTV.Solve( demands, pool, Req() )
	local nine = 0
	for i = 1, #demands do if placed[ i ] and placed[ i ].item.setId == 9 then nine = nine + 1 end end
	assert( Count( placed, demands ) == 3 and nine == 2, "11: set counts are preserved" )

	-- 12. the count is canonical, not the sheet. Three hints for a set the roster only
	-- wants two of yields two demands, and the third slot keeps its requirement for
	-- whatever re-slots into it.
	local warnings = 0
	local parsed, parsedReq = BTV.ParseSetup( {
		sets = { { id = 20, count = 2 } },
		gear = {
			{ slot = EQUIP_SLOT_CHEST, set = 20, trait = 18, weight = "medium" },
			{ slot = EQUIP_SLOT_LEGS, set = 20, trait = 18, weight = "medium" },
			{ slot = EQUIP_SLOT_FEET, set = 20, trait = 18, weight = "heavy" },
		},
	}, function() warnings = warnings + 1 end )
	assert( #parsed == 2, "12: the count wins over the sheet" )
	assert( warnings == 1, "12: an over-seated sheet is warned about once" )
	assert( parsedReq[ EQUIP_SLOT_FEET ].weight == "heavy", "12: the surplus slot keeps its requirement" )

	-- 13. the other way round: a count with no hint left becomes an unpinned body demand
	-- that can still take a slot the roster uses.
	parsed, parsedReq = BTV.ParseSetup( {
		sets = { { id = 21, count = 2 } },
		gear = { { slot = EQUIP_SLOT_CHEST, set = 21, trait = 18, weight = "medium" },
			{ slot = EQUIP_SLOT_LEGS, set = 22, trait = 18, weight = "medium" } },
	}, function() warnings = warnings + 1 end )
	assert( #parsed == 2 and parsed[ 2 ].slot == nil, "13: an unhinted count still becomes a demand" )
	pool = { Item( 21, EQUIP_TYPE_CHEST, 18, MEDIUM ), Item( 21, EQUIP_TYPE_LEGS, 18, MEDIUM ) }
	assert( Count( BTV.Solve( parsed, pool, parsedReq ), parsed ) == 2, "13: it lands on a slot the roster uses" )

	-- 14. a weapon hint pins its demand to its own bar, body hints do not
	parsed = BTV.ParseSetup( {
		sets = { { id = 23, count = 1 } },
		gear = { { slot = EQUIP_SLOT_BACKUP_MAIN, set = 23, trait = 26, eq = EQUIP_TYPE_TWO_HAND, weapon = "bow" } },
	}, function() warnings = warnings + 1 end )
	assert( parsed[ 1 ].kind == "weapon" and parsed[ 1 ].slot == EQUIP_SLOT_BACKUP_MAIN, "14: a weapon hint stays on its bar" )

	-- 15. A two-handed weapon is worth two set pieces, so one bow covers a count of 2. The
	-- real payload that exposed this asked for 2 of Perfected Thunderous Volley, a bow-only
	-- set, and the phantom second demand became an unplaceable body demand.
	parsed = BTV.ParseSetup( {
		sets = { { id = 525, count = 2 } },
		gear = { { slot = EQUIP_SLOT_BACKUP_MAIN, set = 525, trait = 4, eq = EQUIP_TYPE_TWO_HAND, weapon = "bow" } },
	}, function() warnings = warnings + 1 end )
	assert( #parsed == 1 and parsed[ 1 ].kind == "weapon", "15: one two-hander covers a count of two" )
	-- Two daggers on one bar and a greatsword on the other: a lead counts that as four
	-- items, and nothing is left to invent (owner hand test 2026-09-08).
	parsed = BTV.ParseSetup( {
		sets = { { id = 23, count = 4 } },
		gear = { { slot = EQUIP_SLOT_MAIN_HAND, set = 23, trait = 4, eq = EQUIP_TYPE_ONE_HAND, weapon = "dagger" },
			{ slot = EQUIP_SLOT_OFF_HAND, set = 23, trait = 4, eq = EQUIP_TYPE_ONE_HAND, weapon = "dagger" },
			{ slot = EQUIP_SLOT_BACKUP_MAIN, set = 23, trait = 4, eq = EQUIP_TYPE_TWO_HAND, weapon = "greatsword" } },
	}, function() warnings = warnings + 1 end )
	assert( #parsed == 3 and parsed[ 3 ].kind == "weapon", "15: daggers plus a greatsword cover a count of four" )
	-- A one-hander is worth one, so the same count still leaves a piece to find.
	parsed = BTV.ParseSetup( {
		sets = { { id = 23, count = 2 } },
		gear = { { slot = EQUIP_SLOT_MAIN_HAND, set = 23, trait = 4, eq = EQUIP_TYPE_ONE_HAND, weapon = "dagger" } },
	}, function() warnings = warnings + 1 end )
	assert( #parsed == 2 and parsed[ 2 ].slot == nil, "15: a one-hander only covers one" )

	-- 16. a 1 piece monster demand takes any set from its bonus class, but the set the
	-- leader named wins whenever the player owns it. Real ids: Valkyn Skoria 169, Kra'gh
	-- 266 and Lady Malygda 635 all grant 1487 Offensive Penetration.
	demands = { Body( EQUIP_SLOT_HEAD, 169 ) }
	demands[ 1 ].alt = { 266, 635 }
	pool = { Item( 266, EQUIP_TYPE_HEAD, 18, MEDIUM ) }
	assert( Count( BTV.Solve( demands, pool, Req() ), demands ) == 1, "16: a class member stands in" )
	pool = { Item( 266, EQUIP_TYPE_HEAD, 18, MEDIUM ), Item( 169, EQUIP_TYPE_HEAD, 18, MEDIUM ) }
	assert( BTV.Solve( demands, pool, Req() )[ 1 ].item.setId == 169, "16: the set the roster named wins" )
	-- weight is the one thing a class member never gets to swap
	pool = { Item( 266, EQUIP_TYPE_HEAD, 18, HEAVY ) }
	assert( Count( BTV.Solve( demands, pool, Req() ), demands ) == 0, "16: weight is never swapped" )
	-- a set with no class still only answers to itself
	demands = { Body( EQUIP_SLOT_HEAD, 169 ) }
	pool = { Item( 266, EQUIP_TYPE_HEAD, 18, MEDIUM ) }
	assert( Count( BTV.Solve( demands, pool, Req() ), demands ) == 0, "16: no class, no stand in" )

	-- 17. two 1 piece demands from one class must land on two different sets: two pieces
	-- of Kra'gh is Kra'gh's 2 piece proc, not the two 1 piece bonuses that were asked for.
	demands = { Body( EQUIP_SLOT_HEAD, 169 ), Body( EQUIP_SLOT_SHOULDERS, 635 ) }
	demands[ 1 ].alt, demands[ 2 ].alt = { 266, 635 }, { 266, 169 }
	pool = { Item( 266, EQUIP_TYPE_HEAD, 18, MEDIUM ), Item( 266, EQUIP_TYPE_SHOULDERS, 18, MEDIUM ) }
	assert( Count( BTV.Solve( demands, pool, Req() ), demands ) == 1, "17: one set cannot cover both" )
	pool = { Item( 266, EQUIP_TYPE_HEAD, 18, MEDIUM ), Item( 635, EQUIP_TYPE_SHOULDERS, 18, MEDIUM ) }
	placed = BTV.Solve( demands, pool, Req() )
	assert( Count( placed, demands ) == 2 and placed[ 1 ].item.setId ~= placed[ 2 ].item.setId,
		"17: two different sets cover them" )
	-- the class travels on an unpinned demand too, so a count with no hint left can still
	-- stand a member in
	parsed = BTV.ParseSetup( { sets = { { id = 169, count = 1, alt = { 266 } } }, gear = {} },
		function() warnings = warnings + 1 end )
	assert( #parsed == 1 and parsed[ 1 ].alt[ 1 ] == 266, "17: alt reaches an unpinned demand" )
	pool = { Item( 266, EQUIP_TYPE_HEAD, 18, MEDIUM ) }
	assert( Count( BTV.Solve( parsed, pool, Req() ), parsed ) == 1, "17: and it places" )

	-- 18. a plain piece stands in for a perfected demand, ranked under an exact match. Same
	-- real pair as check 10, read the other way: the roster wants Perfected Relequen 393.
	demands = { Body( EQUIP_SLOT_CHEST, 393 ) }
	pool = { Item( 389, EQUIP_TYPE_CHEST, 18, MEDIUM ) }
	assert( Count( BTV.Solve( demands, pool, Req() ), demands ) == 1, "18: a plain piece stands in" )
	pool = { Item( 389, EQUIP_TYPE_CHEST, 18, MEDIUM ), Item( 393, EQUIP_TYPE_CHEST, 18, MEDIUM ) }
	assert( BTV.Solve( demands, pool, Req() )[ 1 ].item.setId == 393, "18: the perfected one still wins" )

	-- 19. quality is a preference above bag priority and never a floor: the legendary in the
	-- bank beats the blue already worn, and the blue is still slotted when it is all there is
	demands = { Body( EQUIP_SLOT_CHEST, 20 ) }
	pool = { Item( 20, EQUIP_TYPE_CHEST, 18, MEDIUM ), Item( 20, EQUIP_TYPE_CHEST, 18, MEDIUM ) }
	pool[ 1 ].quality, pool[ 1 ].rank = 3, 10
	pool[ 2 ].quality, pool[ 2 ].rank = 5, 0
	assert( BTV.Solve( demands, pool, Req() )[ 1 ].item.quality == 5, "19: quality outranks bag priority" )
	pool = { pool[ 1 ] }
	assert( Count( BTV.Solve( demands, pool, Req() ), demands ) == 1, "19: a blue is slotted when it is all there is" )

	-- 20. reach is the lowest rung (#413, reversed by the owner 2026-09-09): between EQUAL
	-- pieces the one in a bag wins, but a better piece elsewhere (gold over purple, the
	-- perfected form over the plain) is taken and fetched. Same real pair as checks 10 and 18.
	demands = { Body( EQUIP_SLOT_CHEST, 393 ) }
	local here = Item( 393, EQUIP_TYPE_CHEST, 18, MEDIUM )
	local away = Item( 393, EQUIP_TYPE_CHEST, 18, MEDIUM )
	away.remote = true
	assert( BTV.Solve( demands, { away, here }, Req() )[ 1 ].item == here, "20: between equals the piece in a bag wins" )
	here.quality, away.quality = 4, 5
	assert( BTV.Solve( demands, { away, here }, Req() )[ 1 ].item == away, "20: gold elsewhere beats purple in the bag" )
	here.quality, away.quality = nil, nil
	here.setId = 389
	assert( BTV.Solve( demands, { away, here }, Req() )[ 1 ].item == away, "20: and the perfected form elsewhere beats the plain one here" )
	placed = BTV.Solve( demands, { away }, Req() )
	assert( placed[ 1 ] and placed[ 1 ].item.remote, "20: and one elsewhere is placed when it is all there is" )

	-- 21. rule 11, from the alpha's Sanity's Edge run (#413 W2). The sheet seats twelve
	-- pieces while the counts add to thirteen, so the thirteenth travels unpinned. The waist
	-- is the one body slot the sheet never names, and the belt it needs is right there.
	-- Before this it stayed homeless next to an empty waist.
	local sheet = { [ EQUIP_SLOT_CHEST ] = { trait = 18, weight = "medium" },
		[ EQUIP_SLOT_LEGS ] = { trait = 18, weight = "medium" } }
	demands = { Body( EQUIP_SLOT_CHEST, 30 ), Body( EQUIP_SLOT_LEGS, 30 ), { set = 30, kind = "body" } }
	pool = { Item( 30, EQUIP_TYPE_CHEST, 18, MEDIUM ), Item( 30, EQUIP_TYPE_LEGS, 18, MEDIUM ),
		Item( 30, EQUIP_TYPE_WAIST, 18, MEDIUM ) }
	placed = BTV.Solve( demands, pool, sheet )
	assert( Count( placed, demands ) == 3, "21: an unnamed body slot still takes a piece" )
	-- Which demand ends up where is the matcher's business, so this asserts the slot got used
	-- rather than which of the three interchangeable pieces landed in it.
	local onWaist = false
	for i = 1, #demands do if placed[ i ] and placed[ i ].slot == EQUIP_SLOT_WAIST then onWaist = true end end
	assert( onWaist, "21: and the slot the sheet left out is the one that took it" )
	-- A weapon slot the sheet leaves out is the opposite case: what is on a bar decides which
	-- skills work, so nothing is put there.
	demands = { { set = 30, kind = "weapon", slot = EQUIP_SLOT_MAIN_HAND } }
	pool = { Item( 30, EQUIP_TYPE_ONE_HAND, 26, nil, WEAPONTYPE_DAGGER ) }
	assert( Count( BTV.Solve( demands, pool, sheet ), demands ) == 0, "21: an unnamed weapon slot stays empty" )

	-- 22. rule 12, from the alpha's Ossein Cage run. The tester's Xoryn's Masterpiece sat on
	-- three body slots and a frost staff on EACH bar, and the back bar staff never equipped:
	-- covered summed the bars, hit five at the front staff and dropped the hint after it.
	-- Both staves are the same five pieces read on two different bars.
	local bothBars = {
		sets = { { id = 31, count = 5 } },
		gear = {
			{ slot = EQUIP_SLOT_CHEST, set = 31, trait = 18, weight = "medium" },
			{ slot = EQUIP_SLOT_LEGS, set = 31, trait = 18, weight = "medium" },
			{ slot = EQUIP_SLOT_FEET, set = 31, trait = 18, weight = "medium" },
			{ slot = EQUIP_SLOT_MAIN_HAND, set = 31, trait = 26, eq = EQUIP_TYPE_TWO_HAND, weapon = "frost" },
			{ slot = EQUIP_SLOT_BACKUP_MAIN, set = 31, trait = 26, eq = EQUIP_TYPE_TWO_HAND, weapon = "frost" },
		},
	}
	local barWarnings = 0
	parsed, parsedReq = BTV.ParseSetup( bothBars, function() barWarnings = barWarnings + 1 end )
	assert( #parsed == 5, "22: the second bar's copy is still a demand" )
	assert( barWarnings == 0, "22: and a sheet that is five on each bar is not an over-seated one" )
	local backBar = false
	for _, d in ipairs( parsed ) do if d.slot == EQUIP_SLOT_BACKUP_MAIN then backBar = true end end
	assert( backBar, "22: the dropped hint was the back bar one" )
	-- It places, given the player owns both staves.
	pool = { Item( 31, EQUIP_TYPE_CHEST, 18, MEDIUM ), Item( 31, EQUIP_TYPE_LEGS, 18, MEDIUM ),
		Item( 31, EQUIP_TYPE_FEET, 18, MEDIUM ),
		Item( 31, EQUIP_TYPE_TWO_HAND, 26, nil, WEAPONTYPE_FROST_STAFF ),
		Item( 31, EQUIP_TYPE_TWO_HAND, 26, nil, WEAPONTYPE_FROST_STAFF ) }
	assert( Count( BTV.Solve( parsed, pool, parsedReq ), parsed ) == 5, "22: and both bars get a staff" )
	-- The cap still holds WITHIN a bar: body and jewellery plus ONE bar may not pass the
	-- count, so a sheet already at five on body alone seats no weapon and is over-seated.
	parsed = BTV.ParseSetup( {
		sets = { { id = 31, count = 5 } },
		gear = {
			{ slot = EQUIP_SLOT_CHEST, set = 31, trait = 18, weight = "medium" },
			{ slot = EQUIP_SLOT_LEGS, set = 31, trait = 18, weight = "medium" },
			{ slot = EQUIP_SLOT_FEET, set = 31, trait = 18, weight = "medium" },
			{ slot = EQUIP_SLOT_HAND, set = 31, trait = 18, weight = "medium" },
			{ slot = EQUIP_SLOT_HEAD, set = 31, trait = 18, weight = "medium" },
			{ slot = EQUIP_SLOT_MAIN_HAND, set = 31, trait = 26, eq = EQUIP_TYPE_TWO_HAND, weapon = "frost" },
		},
	}, function() barWarnings = barWarnings + 1 end )
	assert( #parsed == 5 and barWarnings == 1, "22: body plus one bar is still capped at the count" )

	-- 23. rule 13, from the alpha's Ossein Cage run. The tester owns one Magma Incarnate helm,
	-- in medium, and one setup of the run asked for it in light while ten others asked medium.
	-- The head was left EMPTY for that one, and with WW's unequipEmpty on, the helm is stripped
	-- into the backpack: a whole monster bonus lost to a weight the leader probably never
	-- thought about. The weight moves to the head and the medium it displaces goes elsewhere.
	-- Built by hand rather than through `Req`, which seeds every body slot: the budget is a
	-- tally of the whole sheet, so a sheet naming ten slots has ten weights to spend.
	local weights = {
		[ EQUIP_SLOT_HEAD ] = { trait = 18, weight = "light" },
		[ EQUIP_SLOT_FEET ] = { trait = 18, weight = "medium" },
	}
	demands = { Body( EQUIP_SLOT_HEAD, 32 ), Body( EQUIP_SLOT_FEET, 32 ) }
	pool = { Item( 32, EQUIP_TYPE_HEAD, 18, MEDIUM ), Item( 32, EQUIP_TYPE_FEET, 18, LIGHT ) }
	placed = BTV.Solve( demands, pool, weights )
	assert( Count( placed, demands ) == 2, "23: a weight may move to the slot that owns the piece" )
	assert( placed[ 1 ].item.armorType == MEDIUM and placed[ 2 ].item.armorType == LIGHT,
		"23: and the displaced weight goes where the other piece is" )
	-- The totals are what may not move. One light and one medium were asked for, so a second
	-- medium cannot be worn however many are owned, and the light slot goes without.
	pool = { Item( 32, EQUIP_TYPE_HEAD, 18, MEDIUM ), Item( 32, EQUIP_TYPE_FEET, 18, MEDIUM ) }
	placed = BTV.Solve( demands, pool, weights )
	assert( Count( placed, demands ) == 1, "23: the build never wears more of a weight than it asked for" )
	-- Head and feet are worth the same resistance, so the move in the first case cost nothing
	-- and is not worth telling anyone about.
	pool = { Item( 32, EQUIP_TYPE_HEAD, 18, MEDIUM ), Item( 32, EQUIP_TYPE_FEET, 18, LIGHT ) }
	assert( #WeightMoves( demands, BTV.Solve( demands, pool, weights ), weights ) == 0,
		"23: a move between slots worth the same resistance is silent" )
	-- The waist is not worth the same as the head, so the same trade there is the risky one.
	local risky = {
		[ EQUIP_SLOT_HEAD ] = { trait = 18, weight = "light" },
		[ EQUIP_SLOT_WAIST ] = { trait = 18, weight = "medium" },
	}
	demands = { Body( EQUIP_SLOT_HEAD, 33 ), Body( EQUIP_SLOT_WAIST, 33 ) }
	pool = { Item( 33, EQUIP_TYPE_HEAD, 18, MEDIUM ), Item( 33, EQUIP_TYPE_WAIST, 18, LIGHT ) }
	placed = BTV.Solve( demands, pool, risky )
	assert( Count( placed, demands ) == 2 and #WeightMoves( demands, placed, risky ) == 2,
		"23: a move that changes the build's resistance is flagged" )
	-- A mythic's weight is the game's, so it neither spends the budget nor is blocked by it.
	demands = { Body( EQUIP_SLOT_CHEST, 34 ) }
	pool = { Item( 34, EQUIP_TYPE_CHEST, 21, HEAVY ) }
	pool[ 1 ].mythic = true
	assert( Count( BTV.Solve( demands, pool, Req() ), demands ) == 1, "23: a mythic is outside the budget" )

	-- 24. rule 14, the shape swap. A two-handed staff is two set pieces on its bar and so is a
	-- one-hander plus a shield, so the count is untouched. Taken only where the SITE said the
	-- bar's skills survive it, and only when the staff itself is nowhere to be had.
	local shieldSlot = { [ EQUIP_SLOT_MAIN_HAND ] =
		{ trait = 26, eq = EQUIP_TYPE_TWO_HAND, weapon = "frost", shieldOk = true } }
	demands = { { set = 35, kind = "weapon", slot = EQUIP_SLOT_MAIN_HAND } }
	local sword = Item( 35, EQUIP_TYPE_ONE_HAND, 26, nil, WEAPONTYPE_SWORD )
	local shield = Item( 35, EQUIP_TYPE_OFF_HAND, 26, nil, WEAPONTYPE_SHIELD )
	local staff = Item( 35, EQUIP_TYPE_TWO_HAND, 26, nil, WEAPONTYPE_FROST_STAFF )
	placed = BTV.Solve( demands, { sword, shield }, shieldSlot )
	assert( placed[ 1 ] and placed[ 1 ].pair, "24: a one hander and shield stand in for the staff" )
	assert( placed[ 1 ].slot == EQUIP_SLOT_MAIN_HAND and placed[ 1 ].pair.slot == EQUIP_SLOT_OFF_HAND,
		"24: one demand, two hands" )
	-- The staff is always the better answer where the player owns one.
	placed = BTV.Solve( demands, { sword, shield, staff }, shieldSlot )
	assert( placed[ 1 ].item == staff and not placed[ 1 ].pair, "24: the staff still wins when it is owned" )
	-- Without the site's permission nothing is swapped, whatever is in the bag: what is on a
	-- bar decides which skills work, and only the site can see the bar.
	local noSwap = { [ EQUIP_SLOT_MAIN_HAND ] = { trait = 26, eq = EQUIP_TYPE_TWO_HAND, weapon = "frost" } }
	assert( Count( BTV.Solve( demands, { sword, shield }, noSwap ), demands ) == 0,
		"24: the client never invents a shape swap" )
	-- Half a pair is no pair: a bare one-hander would be one set piece where the bar needs two.
	assert( Count( BTV.Solve( demands, { sword }, shieldSlot ), demands ) == 0,
		"24: a one hander with no shield is not the swap" )

	-- 25. rule 9, the closest shape owned. The alpha's run said "have sword, need frost" at a
	-- player holding a Lightning Staff of Alkosh in the same bag, because it named whichever
	-- spare the bag handed over first. The staff is one drop away and still two set pieces on
	-- that bar, so it is the answer worth printing.
	demands = { { set = 36, kind = "weapon", slot = EQUIP_SLOT_MAIN_HAND } }
	local spares = { Item( 36, EQUIP_TYPE_ONE_HAND, 26, nil, WEAPONTYPE_SWORD ),
		Item( 36, EQUIP_TYPE_TWO_HAND, 26, nil, WEAPONTYPE_LIGHTNING_STAFF ) }
	assert( ShapeMiss( demands[ 1 ], noSwap, spares ):find( "have lightning", 1, true ),
		"25: the shape that fills the hand the same way is the one named" )

	-- 26. glyph is a preference under trait and never a reject: the copy wearing the glyph
	-- the sheet asked for wins the tie, a lone wrong-glyph copy is still slotted, and a
	-- right trait still beats a right glyph.
	demands = { Body( EQUIP_SLOT_CHEST, 40 ) }
	local glyphReq = Req( { [ EQUIP_SLOT_CHEST ] = { trait = 18, weight = "medium", glyph = "stamina" } } )
	local magChest = Item( 40, EQUIP_TYPE_CHEST, 18, MEDIUM )
	local stamChest = Item( 40, EQUIP_TYPE_CHEST, 18, MEDIUM )
	magChest.glyph = ENCHANTMENT_SEARCH_CATEGORY_MAGICKA
	stamChest.glyph = ENCHANTMENT_SEARCH_CATEGORY_STAMINA
	assert( BTV.Solve( demands, { magChest, stamChest }, glyphReq )[ 1 ].item == stamChest,
		"26: the copy in the asked-for glyph wins" )
	assert( Count( BTV.Solve( demands, { magChest }, glyphReq ), demands ) == 1,
		"26: a wrong glyph is still slotted when it is all there is" )
	local offTrait = Item( 40, EQUIP_TYPE_CHEST, 11, MEDIUM )
	offTrait.glyph = ENCHANTMENT_SEARCH_CATEGORY_STAMINA
	assert( BTV.Solve( demands, { magChest, offTrait }, glyphReq )[ 1 ].item == magChest,
		"26: trait outranks glyph" )

	-- 27. remote picks cluster on the character holding the most gear this import wants,
	-- and the glyph still outranks the trip count.
	demands = { Body( EQUIP_SLOT_CHEST, 41 ), Body( EQUIP_SLOT_LEGS, 41 ) }
	local richChest = Item( 41, EQUIP_TYPE_CHEST, 18, MEDIUM )
	local richLegs = Item( 41, EQUIP_TYPE_LEGS, 18, MEDIUM )
	local poorChest = Item( 41, EQUIP_TYPE_CHEST, 18, MEDIUM )
	richChest.remote, richChest.places = true, { "Rich" }
	richLegs.remote, richLegs.places = true, { "Rich" }
	poorChest.remote, poorChest.places = true, { "Poor" }
	pool = { poorChest, richChest, richLegs }
	BTV.ClusterPool( pool, { [ 41 ] = true } )
	assert( richChest.cluster == 2 and poorChest.cluster == 1, "27: richness counts the wanted pieces per place" )
	assert( BTV.Solve( demands, pool, Req() )[ 1 ].item == richChest,
		"27: the chest comes from the character with the most needed gear" )
	poorChest.glyph = ENCHANTMENT_SEARCH_CATEGORY_STAMINA
	assert( BTV.Solve( { Body( EQUIP_SLOT_CHEST, 41 ) }, { poorChest, richChest }, glyphReq )[ 1 ].item == poorChest,
		"27: the asked-for glyph outranks the shorter trip" )

	-- 28. the missing-gear plan (#479), the Slimecraw flip from #469. The sheet asks a
	-- Slimecraw head and Deadly on five body slots; the player owns a Slimecraw shoulder
	-- and four Deadly pieces. Read literally that is two pieces to get; re-running the
	-- matcher over the gap it is one: create a Deadly head, wear the Slimecraw shoulder.
	local ALL_BODY = { slots = { 0, 1, 2, 3, 6, 8, 9, 11, 12, 16 }, weights = { "medium" } }
	local MONSTER = { slots = { 0, 3 }, weights = { "light", "medium", "heavy" } }
	local function Entry( entryDemands, entryReq, sub )
		return { demands = entryDemands, req = entryReq, isSurplus = {}, entry = { sub = sub },
			demandCount = #entryDemands, rows = 1 }
	end
	local function Plan( planPool, entries )
		local analysis = { pool = planPool, entries = entries }
		BTV.PlanMissing( analysis )
		return analysis
	end
	local flipReq = { [ EQUIP_SLOT_HEAD ] = { trait = 18, weight = "medium", set = 270 } }
	for _, slotId in ipairs( { EQUIP_SLOT_CHEST, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_HAND, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET } ) do
		flipReq[ slotId ] = { trait = 18, weight = "medium", set = 127 }
	end
	demands = { Body( EQUIP_SLOT_CHEST, 127 ), Body( EQUIP_SLOT_SHOULDERS, 127 ), Body( EQUIP_SLOT_HAND, 127 ),
		Body( EQUIP_SLOT_LEGS, 127 ), Body( EQUIP_SLOT_FEET, 127 ), Body( EQUIP_SLOT_HEAD, 270 ) }
	pool = { Item( 270, EQUIP_TYPE_SHOULDERS, 18, MEDIUM ), Item( 127, EQUIP_TYPE_CHEST, 18, MEDIUM ),
		Item( 127, EQUIP_TYPE_HAND, 18, MEDIUM ), Item( 127, EQUIP_TYPE_LEGS, 18, MEDIUM ), Item( 127, EQUIP_TYPE_FEET, 18, MEDIUM ) }
	local flip = Plan( pool, { Entry( demands, flipReq, { [ "127" ] = ALL_BODY, [ "270" ] = MONSTER } ) } )
	local gaps = flip.missing.gaps
	assert( #gaps == 1, "28: one piece to create, got " .. #gaps )
	assert( gaps[ 1 ].cand.setId == 127 and gaps[ 1 ].cand.equipType == EQUIP_TYPE_HEAD, "28: it is a Deadly head" )
	assert( gaps[ 1 ].sheet and gaps[ 1 ].sheet.set == 270, "28: and the sheet's own ask is named" )
	-- Only legal alternatives: a Deadly shoulder fills nothing while the Slimecraw shoulder
	-- is worn there, so it is never offered; the sheet's own Slimecraw head is.
	local sheetOption
	for i, option in ipairs( gaps[ 1 ].options ) do
		assert( not ( option.cand.setId == 127 and option.cand.equipType == EQUIP_TYPE_SHOULDERS ),
			"28: a piece that fills nothing is never offered" )
		if option.cand.setId == 270 and option.cand.equipType == EQUIP_TYPE_HEAD and option.cand.armorType == MEDIUM then
			sheetOption = sheetOption or i
		end
	end
	assert( sheetOption, "28: the sheet's own ask is an alternative" )
	-- Picking it re-plans: Slimecraw moves to the head, and the plan grows the Deadly
	-- shoulders the sheet wrote.
	BTV.PickMissing( flip, gaps[ 1 ], sheetOption )
	gaps = flip.missing.gaps
	assert( #gaps == 2, "28: the literal plan is two pieces, got " .. #gaps )
	assert( gaps[ 1 ].cand.setId == 270 and gaps[ 2 ].cand.setId == 127 and gaps[ 2 ].cand.equipType == EQUIP_TYPE_SHOULDERS,
		"28: the Slimecraw head, then the Deadly shoulders" )

	-- 29. one created piece serves every setup that can seat it: two builds short one
	-- Deadly each, on different slots, are one piece to create rather than two.
	local shared = Plan( {}, {
		Entry( { Body( EQUIP_SLOT_HEAD, 127 ) }, { [ EQUIP_SLOT_HEAD ] = { trait = 18, weight = "medium", set = 127 } }, { [ "127" ] = ALL_BODY } ),
		Entry( { Body( EQUIP_SLOT_WAIST, 127 ) }, { [ EQUIP_SLOT_WAIST ] = { trait = 18, weight = "medium", set = 127 } }, { [ "127" ] = ALL_BODY } ),
	} )
	assert( #shared.missing.gaps == 1 and #shared.missing.gaps[ 1 ].serves == 2, "29: one piece covers both builds" )
	assert( shared.missing.gaps[ 1 ].fills == 2, "29: and fills both setups" )

	-- 30. a weapon is only ever created as the sheet wrote it, and a set with no
	-- substitution space offers nothing but the sheet's own ask.
	local bow = Plan( {}, { Entry( { { set = 316, kind = "weapon", slot = EQUIP_SLOT_BACKUP_MAIN } },
		{ [ EQUIP_SLOT_BACKUP_MAIN ] = { trait = 4, eq = EQUIP_TYPE_TWO_HAND, weapon = "bow", set = 316 } },
		{ [ "316" ] = { slots = { 4, 5, 20, 21 } } } ) } )
	assert( #bow.missing.gaps == 1 and bow.missing.gaps[ 1 ].cand.weaponType == WEAPONTYPE_BOW, "30: the bow as written" )
	local shapes = {}
	for _, option in ipairs( bow.missing.gaps[ 1 ].options ) do shapes[ option.cand.key ] = true end
	local shapeCount = 0
	for _ in pairs( shapes ) do shapeCount = shapeCount + 1 end
	assert( shapeCount == 1, "30: no other shape is offered" )
	local bare = Plan( {}, { Entry( { Body( EQUIP_SLOT_CHEST, 50 ) }, Req(), nil ) } )
	assert( #bare.missing.gaps == 1 and bare.missing.gaps[ 1 ].cand.equipType == EQUIP_TYPE_CHEST
		and #bare.missing.gaps[ 1 ].options == 1,
		"30: no substitution space, the sheet's own ask alone" )

	-- 31. the weight allowance is spent with the rest of the build in mind (owner trace,
	-- 2026-09-15): a missing waist re-slots two sets and lands the monster piece on the
	-- head, where the sheet's "medium" would pick its medium copy over the light one, and
	-- the last medium piece then goes unworn while the light allowance sits unused.
	local cascade = { [ EQUIP_SLOT_HEAD ] = { trait = 18, weight = "medium" }, [ EQUIP_SLOT_SHOULDERS ] = { trait = 18, weight = "light" },
		[ EQUIP_SLOT_WAIST ] = { trait = 18, weight = "medium" } }
	demands = { Body( EQUIP_SLOT_HEAD, 1 ), Body( EQUIP_SLOT_SHOULDERS, 2 ), Body( EQUIP_SLOT_WAIST, 3 ) }
	local lightHead, mediumHead = Item( 2, EQUIP_TYPE_HEAD, 18, LIGHT ), Item( 2, EQUIP_TYPE_HEAD, 18, MEDIUM )
	pool = { Item( 1, EQUIP_TYPE_WAIST, 18, MEDIUM ), lightHead, mediumHead, Item( 3, EQUIP_TYPE_SHOULDERS, 18, MEDIUM ) }
	placed = BTV.Solve( demands, pool, cascade )
	assert( Count( placed, demands ) == 3, "31: every piece is worn" )
	assert( placed[ 2 ].slot == EQUIP_SLOT_HEAD and placed[ 2 ].item == lightHead, "31: the monster piece takes the light copy" )

	-- 32. a one-for-one swap between two sets for quality alone (owner, 2026-09-15): the sheet
	-- puts set 1 on the hands and set 2 on a ring, the player owns set 1's hands only in
	-- purple but gold copies of the other way round, so the sets trade slots. Same weight,
	-- trait and glyph on both slots, only the quality moves.
	local purpleHands, goldRing1, goldRing2, goldHands = Item( 1, EQUIP_TYPE_HAND, 18, MEDIUM ), Item( 1, EQUIP_TYPE_RING, 31 ),
		Item( 2, EQUIP_TYPE_RING, 31 ), Item( 2, EQUIP_TYPE_HAND, 18, MEDIUM )
	purpleHands.quality, goldRing1.quality, goldRing2.quality, goldHands.quality = 4, 5, 5, 5
	demands = { Body( EQUIP_SLOT_HAND, 1 ), Body( EQUIP_SLOT_RING1, 2 ) }
	placed = BTV.Solve( demands, { purpleHands, goldRing1, goldRing2, goldHands }, Req() )
	assert( placed[ 1 ].item == goldRing1 and placed[ 2 ].item == goldHands, "32: the sets trade slots for gold" )
	-- Not when the trade changes the trait a slot gets: an off-trait gold hand stays out.
	local offHands = Item( 2, EQUIP_TYPE_HAND, 20, MEDIUM )
	offHands.quality = 5
	placed = BTV.Solve( demands, { purpleHands, goldRing1, goldRing2, offHands }, Req() )
	assert( placed[ 1 ].item == purpleHands and placed[ 2 ].item == goldRing2, "32: never for a trait" )

	-- 33. a weight shortfall the build already has is nobody's fault (owner, 2026-09-18): the
	-- sheet allows one medium and the player owns the head and the chest in medium only, so
	-- one of them goes unworn whatever else happens. The look-ahead used to blame every pick
	-- before them for that, and a whole setup came back empty, the staff included.
	local short = { [ EQUIP_SLOT_HEAD ] = { trait = 18, weight = "light" }, [ EQUIP_SLOT_CHEST ] = { trait = 18, weight = "light" },
		[ EQUIP_SLOT_SHOULDERS ] = { trait = 18, weight = "medium" }, [ EQUIP_SLOT_MAIN_HAND ] = { eq = EQUIP_TYPE_TWO_HAND } }
	demands = { { slot = EQUIP_SLOT_MAIN_HAND, kind = "weapon", set = 2 }, Body( EQUIP_SLOT_HEAD, 1 ), Body( EQUIP_SLOT_CHEST, 1 ) }
	local staff = Item( 2, EQUIP_TYPE_TWO_HAND, 18, nil, WEAPONTYPE_FIRE_STAFF )
	pool = { staff, Item( 1, EQUIP_TYPE_HEAD, 18, MEDIUM ), Item( 1, EQUIP_TYPE_CHEST, 18, MEDIUM ) }
	placed = BTV.Solve( demands, pool, short )
	assert( placed[ 1 ] and placed[ 1 ].item == staff, "33: the staff is worn, the weights are not its business" )
	assert( Count( placed, demands ) == 2, "33: one medium piece is worn, the other is the only miss" )

	-- 34. the two jewelry damage glyphs are one glyph (owner, 2026-09-18): both give the same
	-- weapon and spell damage, so the copy in the bag is not passed over for a trip. Any
	-- other glyph still loses to the asked-for one, wherever that sits.
	demands = { Body( EQUIP_SLOT_RING1, 60 ) }
	local twinReq = Req( { [ EQUIP_SLOT_RING1 ] = { trait = 31, glyph = "increase spell damage" } } )
	local bagRing, farRing = Item( 60, EQUIP_TYPE_RING, 31 ), Item( 60, EQUIP_TYPE_RING, 31 )
	bagRing.glyph, farRing.glyph = ENCHANTMENT_SEARCH_CATEGORY_INCREASE_PHYSICAL_DAMAGE, ENCHANTMENT_SEARCH_CATEGORY_INCREASE_SPELL_DAMAGE
	farRing.remote = true
	assert( BTV.Solve( demands, { farRing, bagRing }, twinReq )[ 1 ].item == bagRing, "34: the twin glyph in the bag wins" )
	bagRing.glyph = ENCHANTMENT_SEARCH_CATEGORY_MAGICKA_REGEN
	assert( BTV.Solve( demands, { farRing, bagRing }, twinReq )[ 1 ].item == farRing, "34: any other glyph is still worth the trip" )

	-- 35. two missing staffs of one set that differ only in glyph are two pieces to create,
	-- each in its own glyph and on its own bar (owner, 2026-09-19: a reduce power front staff
	-- and a berserker back staff came out as two reduce power staffs).
	local staffReq = { [ EQUIP_SLOT_MAIN_HAND ] = { trait = 4, eq = EQUIP_TYPE_TWO_HAND, weapon = "frost", glyph = "reduce power", set = 75 },
		[ EQUIP_SLOT_BACKUP_MAIN ] = { trait = 4, eq = EQUIP_TYPE_TWO_HAND, weapon = "frost", glyph = "berserker", set = 75 } }
	local staffs = Plan( {}, { Entry( { { set = 75, kind = "weapon", slot = EQUIP_SLOT_MAIN_HAND }, { set = 75, kind = "weapon", slot = EQUIP_SLOT_BACKUP_MAIN } },
		staffReq, { [ "75" ] = { slots = { 4, 5, 20, 21 } } } ) } )
	assert( #staffs.missing.gaps == 2, "35: two staffs to create" )
	for _, gap in ipairs( staffs.missing.gaps ) do
		assert( gap.cand.glyph == staffReq[ gap.slots[ 1 ] ].glyph, "35: each staff in the glyph its bar asked for" )
	end

	-- 36. a demand that went without gets its own slot back from one that only re-slotted
	-- there (owner trace, 2026-10-28): the sheet puts Sergeant's Mail on the chest and one
	-- Trainee on the legs, the player owns a Sergeant chest and a Trainee chest but no Trainee
	-- legs. Trainee took the chest, Sergeant's legs then broke the heavy budget, and the plan
	-- made a second Trainee for the legs.
	local trainee = { [ EQUIP_SLOT_CHEST ] = { trait = 18, weight = "heavy" }, [ EQUIP_SLOT_LEGS ] = { trait = 18, weight = "medium" } }
	demands = { Body( EQUIP_SLOT_CHEST, 29 ), Body( EQUIP_SLOT_LEGS, 281 ) }
	pool = { Item( 29, EQUIP_TYPE_CHEST, 18, HEAVY ), Item( 29, EQUIP_TYPE_LEGS, 18, HEAVY ), Item( 281, EQUIP_TYPE_CHEST, 18, HEAVY ) }
	placed = BTV.Solve( demands, pool, trainee )
	assert( placed[ 1 ] and placed[ 1 ].slot == EQUIP_SLOT_CHEST and placed[ 1 ].item.setId == 29, "36: Sergeant keeps the chest" )
	assert( not placed[ 2 ], "36: Trainee goes without, so the plan makes its legs" )

	Say( "self check: 36 of 36 passed" )
end

-- ---------------------------------------------------------------- settings UI

-- Support is gold by in-game mail, and mail never leaves its megaserver: the author is on
-- PC EU, so every other server gets no button at all.
BTV.canSupport = GetWorldName() == "EU Megaserver"
function BTV.Support()
	MAIL_SEND:ComposeMailTo( "@balltongue_o" )
end

-- LibAddonMenu is a hard dependency (#461, #463) with a >= floor in DependsOn (#533), so the
-- game never loads the addon without it.
local function RegisterSettingsPanel()
	local LAM = LibAddonMenu2
	-- registerForRefresh: without it LibAddonMenu never re-reads the panel's controls
	-- on "LAM-RefreshPanel", so a toggle flipped on the plan showed only after a reload
	-- (owner hand test 2026-09-15).
	BTV.settingsPanel = LAM:RegisterAddonPanel( "BTVToolsOptions", {
		type = "panel", name = "BTV Tools", author = "BallTongue", registerForRefresh = true,
	} )
	local function Toggle( name, key, tooltip )
		return { type = "checkbox", name = name, tooltip = tooltip, default = DEFAULTS[ key ],
			getFunc = function() return BTV.Setting( key ) end,
			setFunc = function( value ) BTV.SetSetting( key, value ) end }
	end
	local options = {
		Toggle( "Account-wide settings", "accountWide",
			"One set of settings for every character. Off keeps a separate set per character. The import record is always account-wide." ),
		Toggle( "Auto-open at bankers and coffers", "autoOpen",
			"While an import is in progress, opening a banker or a storage coffer opens the BTV window with what to move. Always on while Auto deposit/withdraw is on." ),
		{ type = "dropdown", name = "Chat verbosity",
			tooltip = "What an import says in chat. One line is the summary; Full is the whole report; Silent says nothing but errors.",
			choices = { "Silent", "One line", "Full" }, choicesValues = { "silent", "line", "full" },
			default = DEFAULTS.verbosity,
			getFunc = function() return BTV.Setting( "verbosity" ) end,
			setFunc = function( value ) BTV.SetSetting( "verbosity", value ) end },
		{ type = "dropdown", name = "Show Icon",
			tooltip = "When the BTV icon shows on your screen. Click it to open the BTV window, drag it to move it.",
			choices = { "Never", "Always", "When import in progress" }, choicesValues = { "never", "always", "import" },
			default = DEFAULTS.hudIcon,
			getFunc = function() return BTV.Setting( "hudIcon" ) end,
			setFunc = function( value ) BTV.SetSetting( "hudIcon", value ) end },
		Toggle( "Exact traits only", "exactTraits",
			"Never wear an off-trait piece. The import treats it as missing and plans a new one in the roster's trait." ),
		Toggle( "Auto-overwrite our page", "autoOverwrite",
			"Importing over an existing BTV page replaces it without asking. Pages you made yourself are never touched either way." ),
		Toggle( "Auto deposit/withdraw", "autoDeposit",
			"While an import is in progress, move its gear through the open bank or coffer without asking: deposit from a character holding it, withdraw on the importing character. The BTV window opens too, so you see what moves." ),
		Toggle( "Auto craft and reconstruct", "autoCraft",
			"Run the plan's queued craft lines the moment a crafting station opens (needs LibLazyCrafting) and its queued reconstruct lines at a transmute station. Off leaves queued lines waiting." ),
		{ type = "dropdown", name = "Import history size",
			tooltip = "How many done imports to keep. Opening one from Past imports makes it active again.",
			-- The fixed ladder #472 locked, not a slider.
			choices = { "1", "2", "3", "4", "5", "10", "25", "50", "100" },
			choicesValues = { 1, 2, 3, 4, 5, 10, 25, 50, 100 },
			default = DEFAULTS.historySize,
			getFunc = function() return BTV.Setting( "historySize" ) end,
			setFunc = function( value ) BTV.SetSetting( "historySize", value ) end },
		Toggle( "Use my skill placements", "usePlacements",
			"Put each skill in the slot you saved for it, in every setup the addon writes. Off writes the leader's order and never asks." ),
		Toggle( "Debug trace", "debugTrace",
			"Capture a match trace on the next import for a bug report. Turns itself off after one import." ),
		{ type = "button", name = "Show tips again",
			tooltip = "Shows each step's tip again the next time you reach that step in the import window.",
			func = function() BTV.svAccount.tipsSeen = {} end },
	}
	if BTV.canSupport then
		table.insert( options, { type = "button", name = "Support", width = "half",
			tooltip = "Opens a mail to @balltongue_o. Gold is welcome, never needed.",
			func = BTV.Support } )
	end
	LAM:RegisterOptionControls( "BTVToolsOptions", options )
end

-- ------------------------------------------------------------------- wiring

local function OnAddOnLoaded( _, addonName )
	if addonName ~= BTV.name then return end
	EVENT_MANAGER:UnregisterForEvent( BTV.name, EVENT_ADD_ON_LOADED )

	-- The account table is kept per server (ESOUI moderator, 2026-10): an EU import record
	-- means nothing on NA or the PTS. Up to 0.3.0 it lived in the "Default" profile, so the
	-- first server played after the update takes it over, moved, not copied, so a second
	-- server never gets a stale copy too. Done on the raw table before ZO_SavedVars wraps
	-- it, so no metatable is copied; once Default has no "$AccountWide" it never runs again.
	-- Per character data stays in Default: character ids are unique across servers.
	-- ponytail: a player on two servers starts the second one fresh.
	local world, account = GetWorldName(), GetDisplayName()
	local old = BTVToolsVars and BTVToolsVars.Default and BTVToolsVars.Default[ account ]
	if old and old[ "$AccountWide" ] and not ( BTVToolsVars[ world ] and BTVToolsVars[ world ][ account ] ) then
		-- Only this account's entry: the file is shared by every account on this PC.
		BTVToolsVars[ world ] = BTVToolsVars[ world ] or {}
		BTVToolsVars[ world ][ account ] = { [ "$AccountWide" ] = old[ "$AccountWide" ] }
		old[ "$AccountWide" ] = nil
	end
	BTV.svAccount = ZO_SavedVars:NewAccountWide( "BTVToolsVars", 1, nil,
		{ settings = DEFAULTS, history = {}, tipsSeen = {}, placements = {} }, world )
	BTV.svChar = ZO_SavedVars:NewCharacterIdSettings( "BTVToolsVars", 1, nil,
		{ settings = DEFAULTS } )
	-- Auto craft went from on to off by default (2026-10-14). ZO_SavedVars wrote the old
	-- default into every existing file, so it is turned off once per table (the setting can
	-- be per character); a player who turns it back on keeps it.
	for _, sv in ipairs( { BTV.svAccount, BTV.svChar } ) do
		if not sv.autoCraftOff then sv.settings.autoCraft, sv.autoCraftOff = false, true end
	end
	RegisterSettingsPanel()
	-- This character's trait research, kept for every character so the plan knows the
	-- account's best crafter from anywhere. Read again once the player is in the world:
	-- passives are not always readable while addons load.
	BTV.SnapshotResearch()
	EVENT_MANAGER:RegisterForEvent( BTV.name .. "Research", EVENT_PLAYER_ACTIVATED, BTV.SnapshotResearch )

	-- The plan's live triggers (#480): set pieces landing in a bag, and the bank opening or
	-- closing, which changes what the match can see.
	-- One registration per watched bag, so the game drops every other bag's change
	-- before any Lua runs (ESOUI moderator, 2026-10).
	local watched = { BAG_BACKPACK, BAG_WORN, BAG_BANK, BAG_SUBSCRIBER_BANK }
	for bag = BAG_HOUSE_BANK_ONE, BAG_HOUSE_BANK_TEN do table.insert( watched, bag ) end
	for _, bag in ipairs( watched ) do
		local name = BTV.name .. "Bags" .. bag
		EVENT_MANAGER:RegisterForEvent( name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnBagChanged )
		EVENT_MANAGER:AddFilterForEvent( name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
			REGISTER_FILTER_BAG_ID, bag, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT )
	end
	EVENT_MANAGER:RegisterForEvent( BTV.name .. "Chatter", EVENT_CHATTER_BEGIN, OnChatterBegin )
	EVENT_MANAGER:RegisterForEvent( BTV.name .. "BankOpen", EVENT_OPEN_BANK, OnBankChanged )
	EVENT_MANAGER:RegisterForEvent( BTV.name .. "BankClose", EVENT_CLOSE_BANK, OnBankChanged )
	-- The queues (#482): smithing and transmute stations opening and closing, and the
	-- reconstruction's answer.
	EVENT_MANAGER:RegisterForEvent( BTV.name .. "Station", EVENT_CRAFTING_STATION_INTERACT, OnStationOpened )
	EVENT_MANAGER:RegisterForEvent( BTV.name .. "StationEnd", EVENT_END_CRAFTING_STATION_INTERACT, OnStationClosed )
	EVENT_MANAGER:RegisterForEvent( BTV.name .. "Transmute", EVENT_RETRAIT_STATION_INTERACT_START, OnTransmuteOpened )
	EVENT_MANAGER:RegisterForEvent( BTV.name .. "TransmuteEnd", EVENT_RETRAIT_STATION_INTERACT_END, OnTransmuteClosed )
	EVENT_MANAGER:RegisterForEvent( BTV.name .. "Reconstruct", EVENT_RECONSTRUCT_RESPONSE, OnReconstructResponse )

	-- The routes #473 locked. `/btv` bare opens the plan while an import is in progress
	-- and Paste otherwise (#480); `/btv missing` opens the plan.
	SLASH_COMMANDS[ "/btv" ] = function( args )
		args = args and args:gsub( "^%s+", "" ):gsub( "%s+$", "" ):lower() or ""
		if args == "test" then
			SelfCheck()
		elseif args == "missing" then
			if BTV.GetRecord() and BTV.OpenWindow then
				-- The same check /btv bare runs, so the boxes are current on this route too.
				BTV.CheckPlan()
				if BTV.GetRecord() then BTV.OpenWindow( "plan" ) else Say( "No import in progress." ) end
			elseif BTV.GetRecord() then
				Say( string.format( "import in progress on |cFFFFFF%s|r.", BTV.GetRecord().pageName or "a BTV page" ) )
			else
				Say( "No import in progress." )
			end
		elseif args == "settings" then
			LibAddonMenu2:OpenToPanel( BTV.settingsPanel )
		elseif args == "placements" then
			if BTV.OpenWindow then BTV.OpenWindow( "placements" ) end
		elseif args == "remember" then
			local count = BTV.RememberBars()
			Say( string.format( "saved the slots of %d skill%s on your bars.", count, count == 1 and "" or "s" ) )
		elseif args == "debug" then
			BTV.debugArmed = true
			Say( "debug trace armed for the next import." )
		elseif args == "passives" then
			-- What the plan believes about each character's crafting passives, for a hand
			-- test: the material tier per craft (10 makes CP160, 5 for jewelry) and the tempers gold costs.
			local names = { [ CRAFTING_TYPE_BLACKSMITHING ] = "blacksmithing", [ CRAFTING_TYPE_CLOTHIER ] = "clothing",
				[ CRAFTING_TYPE_WOODWORKING ] = "woodworking", [ CRAFTING_TYPE_JEWELRYCRAFTING ] = "jewelry" }
			for _, snap in pairs( BTV.svAccount.research or {} ) do
				local parts = {}
				for _, craft in ipairs( CRAFTS ) do
					local tier = snap.tier and snap.tier[ craft ]
					table.insert( parts, string.format( "%s tier %s, gold %s tempers", names[ craft ],
						tostring( tier or "unread" ), tostring( snap.upgrade and snap.upgrade[ craft ] or "unread" ) ) )
				end
				Say( string.format( "|cFFFFFF%s|r: %s", snap.name or "?", table.concat( parts, "; " ) ) )
			end
		elseif args == "" then
			-- The window file defines OpenWindow; the guard only matters to harness runs
			-- that load this file alone. The check first: a finished import goes to the
			-- history here, and Paste is what opens.
			if BTV.OpenWindow then
				local plan = BTV.CheckPlan()
				BTV.OpenWindow( ( plan and BTV.GetRecord() ) and "plan" or "paste" )
			else
				OpenDialog()
			end
		else
			Say( "usage: |c7B68EE/btv|r to import, |c7B68EE/btvpaste|r for the fast paste, |c7B68EE/btv missing|r for the plan, |c7B68EE/btv placements|r, |c7B68EE/btv remember|r, |c7B68EE/btv settings|r,|c7B68EE/btv debug|r, |c7B68EE/btv test|r." )
		end
	end
	-- The fast path (#473): paste, one line, done. Today the two entries share one dialog;
	-- they part ways when /btv grows the full window.
	SLASH_COMMANDS[ "/btvpaste" ] = function() OpenDialog() end
	-- Last session's import shows the HUD icon at login.
	if BTV.OnRecordChanged then BTV.OnRecordChanged() end
end

EVENT_MANAGER:RegisterForEvent( BTV.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded )
