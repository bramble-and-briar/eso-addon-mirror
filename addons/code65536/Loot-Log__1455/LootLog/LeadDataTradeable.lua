local LEAD_ITEMS = nil

local function Initialize() LEAD_ITEMS = {
	[226994] = 250, -- Void-Crystal Anomaly
	[227049] = 251, -- Branch of Falinesti
	[227050] = 253, -- Rune-Carved Mammoth Skull
	[227051] = 254, -- Nest of Shadows
	[227052] = 258, -- Sorcerer-King's Blade
	[227053] = 256, -- Remnant of the False Tower
	[227054] = 255, -- Prismatic Sunbird Feather
	[227055] = 264, -- Font of Auri-El
	[227056] = 263, -- Warcaller's Painted Drum
	[227057] = 262, -- Kingmaker's Trove
	[227058] = 269, -- Moons-Blessed Ceremonial Pool
	[227059] = 268, -- St. Nerevar, Moon-and-Star
	[227060] = 266, -- Mnemonic Star-Sphere
	[227061] = 265, -- Echoes of Aldmeris
	[227062] = 274, -- Coil of Satakal
	[227063] = 273, -- Brazier of Frozen Flame
	[227064] = 279, -- St. Alessia, Paravant
	[227065] = 277, -- Golden Idol of Morihaus
	[227066] = 284, -- Moonlight Mirror
	[227067] = 283, -- Cat's Eye Prism
	[227068] = 281, -- Beacon of Tower Zero
	[227069] = 280, -- Blessed Dais of Almalexia
	[227070] = 289, -- Meridian Sconce
	[227071] = 288, -- Stained Glass of Lunar Phases
	[227072] = 287, -- Carved Whale Totem
	[227073] = 295, -- Shrine of Boethra
	[227074] = 302, -- Morwha's Blessing
	[227075] = 308, -- Altar of Celestial Convergence
	[227076] = 307, -- Dwemer Star Chart
	[227077] = 354, -- Vampiric Stained Glass
	[227078] = 376, -- Kothringi Tidal Canoe
	[227079] = 434, -- Dagon's Scalding Gibbet
	[227080] = 511, -- Sea Elf Galleon Helm
	[227081] = 612, -- Umbral Frame
	[227082] = 613, -- Liminal Glass
	[227083] = 614, -- Runic Legs
	[227084] = 652, -- Apocrypha Tentacle Carving
	[227085] = 653, -- Apocrypha Stone Base
	[227086] = 654, -- Hermaeus Mora Eye Engraving
	[227087] = 656, -- Infinite Table of Contents
	[227088] = 655, -- Infinite Tome Cover
	[227089] = 657, -- Infinite Tome Manuscript
	[227090] = 658, -- Archival Light Diffuser, Large
	[227091] = 661, -- Archival Light Diffuser, Small
	[227092] = 662, -- Forged Black Book
	[227093] = 660, -- Petrified Watcher
	[227094] = 659, -- Scrying Brazier, Short
	[227095] = 663, -- Scrying Brazier, Tall
	[227096] = 664, -- Watchful Light
	[227097] = 665, -- Apocrypha Fossil, Ribcage
	[227098] = 666, -- Apocrypha Fossil, Slug
	[227099] = 668, -- Apocrypha Fossil, Tree
	[227100] = 667, -- Apocrypha Fossil, Wall Beast
	[227101] = 767, -- Stone-Nest Gazebo
	[227102] = 768, -- Stone-Nest Pillar, Temple
	[227103] = 779, -- Imperial Titan Slayer
	[227104] = 780, -- Bearer of Fargrave, Broken Skull
	[227105] = 781, -- Valenwood Skull Blocks
	[227106] = 782, -- Bearer of Fargrave, Skeletal Jaw
	[227179] = 249, -- Anvil of Old Orsinium
	[227180] = 433, -- Spell-Scorched Table
	[227181] = 452, -- Daedric Enchanting Apparatus
	[227182] = 453, -- Unhallowed Runic Tome
	[227184] = 537, -- Storm-Weathered Drafting Top
	[227185] = 548, -- Admiral's Carved Trestle Base
	[227186] = 549, -- Tool Grooved Wooden Tray
	[227187] = 647, -- Structural Tentacle Arch
	[227188] = 648, -- Fated Loom Threads
	[227189] = 649, -- Writhing Tendril Harness
	[227190] = 650, -- Carved Mora Treadles
	[227191] = 651, -- Endless Apocryphal Light
	[227192] = 699, -- Heartland Basalt Base
	[227193] = 700, -- Ruin-Carved Smithing Stand
	[227194] = 701, -- Wildsmith Anointing Decoction
	[227195] = 702, -- Dynarian Legacy Bracing
	[227196] = 703, -- Wildsmithed Anvil
	[227197] = 709, -- Perpetual Spinning Wheel
	[227198] = 710, -- Refracting Stone Crucible
	[227199] = 711, -- Vented Potbelly Stove
	[227200] = 712, -- Lapidary Grinding Wheels
	[227201] = 713, -- Tentacled Tool Rack
	[227202] = 714, -- Twisted Shelving Pedestal
	[227203] = 715, -- Entangled Brass Legs
	[227204] = 716, -- Cold Stone Tabletop
	[227205] = 717, -- Ornate Gem Holder
	[227206] = 718, -- Twinned Jade Insets
	[227207] = 759, -- Writhing Wagon Wheel
	[227208] = 760, -- Cultsmith's Water Trough
	[227209] = 761, -- Daedric Anvil
	[227210] = 762, -- Ossified Lantern
	[227211] = 763, -- Worm Cult Wagon Bed
	[227212] = 784, -- Wooden Display Board
	[227213] = 785, -- Surreptitious Cabinet
	[227214] = 786, -- Antique Lockpicking Kit
	[227215] = 787, -- Camouflaged Hood
	[227216] = 788, -- Brigand's Dagger
	[227317] = 804, -- Sea Serpent Skin Scrollcase
	[227318] = 805, -- Coral-Encrusted Cogs
	[227319] = 806, -- Thrassian Compass
	[227320] = 807, -- Pearl-Inlaid Navigation Chart
	[227321] = 808, -- Xirkn-Zel Chamberpot
	[227322] = 809, -- Polwygle Maturation Creche
	[227323] = 810, -- Mixed-Era Coin Cache
	[227324] = 811, -- Louse-Whisperer Ritual Totem
	[227325] = 812, -- Shattered Animunculi Schematic
	[227348] = 813, -- All Flags Navy Astrolabe
} end

function LootLog.GetAntiquityIdFromItem( item )
	if (type(item) == "string") then
		item = GetItemLinkItemId(item)
	end

	if (type(item) == "number" and item > 0) then
		if (not LEAD_ITEMS) then
			Initialize()
		end
		return LEAD_ITEMS[item] or 0
	end

	return 0
end
