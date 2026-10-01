local LCCC = LibCodesCommonCode
local Data = CollectiblesTracker.data
local DataGen = CollectiblesTracker.dataGen

local function GetAchievementCategoryName( achievementId )
	local name = GetAchievementSubCategoryInfo(GetCategoryInfoFromAchievementId(achievementId))
	return name
end

function DataGen.cakes() return {
	-- Should be listed from newest to oldest
	14325, -- Jubilee Cake 2026
	13520, -- Jubilee Cake 2025
	12422, -- Jubilee Cake 2024
	11089, -- Jubilee Cake 2023
	10287, -- Jubilee Cake 2022
	9012, -- Jubilee Cake 2021
	7619, -- Jubilee Cake 2020
	5886, -- Jubilee Cake 2019
	4786, -- Jubilee Cake 2018
	1109, -- Jubilee Cake 2017
	356, -- Jubilee Cake 2016
} end

function DataGen.ct() return {
	----------------------------------------------------------------------------
	{
		-- Special empty category for the filter dropdown
		GetString(SI_COLLECTIBLESTRACKER_SOURCE_ALL), { },
	},

	----------------------------------------------------------------------------
	{
		zo_strformat(SI_COLLECTIBLESTRACKER_SOURCE_SEASON, 0),
		{
			14098, -14104, -- Kireth's Kit
			14145, -14154, -- Mesa Stalker (weapons)
			14337, -- Vigor, Dusk Blue
		},
		premium = {
			14394, -- Season Zero Premium Tome (must be first entry in the premium list)
			13533, -- Winterhold Empyrean Wolf
			13897, -- Duo-Dynamo Dungeon Delver Spider
			13901, -- Dungeon Delver Theodolite
			14085, -- Mesa Stalker Piercings
			14105, -14114, -- Vanos Dungeon Delve
			14123, -14144, -- Mesa Stalker (body)
			14336, -- Vigor, Dawn Orange
			14339, -14343, -- Miscellaneous
		},
	},

	----------------------------------------------------------------------------
	{
		zo_strformat(SI_COLLECTIBLESTRACKER_SOURCE_SEASON, 1),
		{
			14087, -- Golden Dwarven Spider
			14315, -14324, -- Charming Rogue (weapons)
			14656, 14657, -- Chevalier's Honor
			14680, -- Blade Cloak, Gold Arrow
		},
		premium = {
			14697, -- Season One Premium Tome (must be first entry in the premium list)
			13726, -- Hew's Bane Hyena
			13747, -- Hew's Bane Hyena Cub
			14204, -- Cambio Zammes, Rooster in Exile
			14293, -14313, -- Charming Rogue (body)
			14350, -- Arrow's Sting
			14366, -14375, -- Valiant Rogue
			14678, -- Blade Cloak, Jade Arrow
			14681, -14684, -- Miscellaneous
		},
	},

	----------------------------------------------------------------------------
	--[[
	{
		zo_strformat(SI_COLLECTIBLESTRACKER_SOURCE_SEASON, 2),
		{
			14423, -14432, -- Maarselok Slayer (weapons)
		},
		premium = {
			15166, -- Season Two Premium Tome (must be first entry in the premium list)
			14401, -14422, -- Maarselok Slayer (body)
			14569, -14578, -- Azureblight Slayer
			14700, -- Azureblight Recall
			14742, -- Maarselok Slayer Mammoth
			14749, -- Spider Hunter Silks
			14750, -- Shagrath's Web
			14752, -- Blightguard Jawplate
			14753, -- Maarselok Hunter's Horns
			14755, -- Maarselok Slayer Piercings
			14757, -- Maarselok Dragon Imp
			14945, -14950, -- Miscellaneous
		},
	},
	--]]

	----------------------------------------------------------------------------
	{
		GetString(SI_COLLECTIBLESTRACKER_SOURCE_UNDAUNTED),
		{
			-- Missing: Stone Husk
			5452, 5453, -- Ilambris
			5454, 5455, -- Molag Kena
			5456, 5457, -- Shadowrend
			5545, 5546, -- Grothdarr
			5607, 5608, -- Troll King
			5615, 5616, -- Iceheart
			5763, 5764, -- Sellistrix
			5924, 5925, -- Bloodspawn
			5926, 5927, -- Swarm Mother
			6044, 6045, -- Engine Guardian
			6174, 6175, -- Valkyn Skoria
			6251, 6252, -- Nightflame
			6388, 6389, -- Lord Warden
			6690, 6691, -- Mighty Chudan
			6692, 6693, -- Velidreth
			6721, 6722, -- Pirate Skeleton
			6744, 6745, -- Chokethorn
			6775, 6776, -- Spawn of Mephala
			6948, 6949, -- Infernal Guardian
			6956, 6957, -- Kra'gh
			6963, 6964, -- Sentinel of Rkugamz
			7329, 7330, -- Slimecraw
			7424, 7425, -- Stormfist
			7426, 7427, -- Balorgh
			7511, 7512, -- Mother Ciannait
			7513, 7514, -- Kjalnar's Nightmare
			7682, 7683, -- Scourge Harvester
			7749, 7750, -- Domihaus
			7784, 7785, -- Nerien'eth
			8147, 8148, -- Maw of the Infernal
			8167, 8168, -- Earthgore
			8176, 8177, -- Tremorscale
			8339, 8340, -- Selene
			8688, 8689, -- Vykosa
			8695, 8696, -- Thurvokun
			8761, 8762, -- Zaan
			8958, 8959, -- Symphony of Blades
			9001, 9002, -- Stonekeeper
			9015, 9016, -- Baron Zaudrus
			9017, 9018, -- Encratis's Behemoth
			9128, 9129, -- Grundwulf
			9273, 9274, -- Maarselok
			9588, 9589, -- Prior Thierric
		--	9629, 9630, -- Magma Incarnate
			10022, 10023, -- Lady Thorn
			10035, 10036, -- Kargaeda
			10042, 10043, -- Nazaray
			10563, 10564, -- Euphotic Gatekeeper
		--	10565, 10566, -- Archdruid Devyric
		--	11003, 11004, -- Ozezan the Inferno
			11010, 11011, -- Roksa the Warped
		--	12014, 12015, -- Anthelmir's Construct
			12021, 12022, -- The Blind
		--	12874, 12875, -- Squall of Retribution
		--	12876, 12877, -- Orpheon the Tactician
		--	13425, 13426, -- Black Gem Monstrosity
		--	13427, 13428, -- Bar-Sakka
		},
	},

	----------------------------------------------------------------------------
	{
		LCCC.GetZoneName(1227), -- Vateshran Hollows
		{
			8856, -8865, -- Hungering Void Weapons
		},
	},

	----------------------------------------------------------------------------
	{
		LCCC.GetZoneName(1436), -- Infinite Archive
		{
			11678, -11684, -- Body: Reawakened Hierophant
			11694, -11735, -- Body: Basalt-Blood Warrior (11694), Nobility in Decay (11701), Soulcleaver (11708), Monolith of Storms (11715), Wrathsun (11722), Gardener of Seasons (11729)
			11667, -11676, -- Weapons: Reawakened Hierophant
			11736, -11795, -- Weapons: Basalt-Blood Warrior (11736), Nobility in Decay (11746), Soulcleaver (11756), Monolith of Storms (11766), Wrathsun (11776), Gardener of Seasons (11786)
		},
	},

	----------------------------------------------------------------------------
	{
		GetString(SI_VETERANCY_MENU_TEXT), -- Veterancy
		{
			9663, -9672, -- Torment's Cut
			13373, -13379, -- Brutal Mercenary
			14658, -- Power Bash, Molten Might
			14664, -14673, -- Fire's Torment
			14677, -- Critical Charge, Vivid Purple
		},
	},

	----------------------------------------------------------------------------
	{
		LCCC.GetZoneName(181), -- Cyrodiil
		{
			5019, 5589, 5746, -- Arena Gladiator
			6064, -- Elinhir Arena Lion
			7338, -7343, 7380, -7384, -- Knight of the Circle
			7595, -- Reach-Mage Ceremonial Skullcap
			9718, -- Siegestomper
			11565, -11578, -- Cumberland Cavalier (11565), Highborn Gallant (11572)
			11581, -11587, -- Thane of Falkreath
			11486, 11487, -- Unfeathered Battle
			12679, 12680, -- Feral Favor
			13854, -- Alliance Banner
			13276, -13281, -- Alliance Face and Body Paints
		},
	},

	----------------------------------------------------------------------------
	{
		LCCC.GetZoneName(584), -- Imperial City
		{
			146, -148, -- Xivkyn
			6665, 6438, -- Siegemaster
			8043, -- Timbercrow Wanderer
			8655, -- Rage of the Reach
			9280, -9286, -- Nibenese Court Wizard
			9853, -9859, -- Dragonguard Berserker
			10531, -10536, -- Red Rook Bandit
			11371, -11377, -- Gravegrasp
			11911, 12427, -- Unkindness of Ravens
		},
	},

	----------------------------------------------------------------------------
	{
		GetString(SI_BATTLEGROUND_HUD_HEADER), -- Battlegrounds
		{
			5355, -5376, 5378, -5387, -- Fanged Worm
			5420, -5451, -- Horned Dragon
			5621, -5634, -- Heavy: Pit Daemon (5621), Storm Lord (5628)
			5645, -5651, -- Heavy: Fire Drake
			6209, -6238, -- Weapons: Storm Lord (6209), Fire Drake (6219), Pit Daemon (6229)
			6632, -6634, -- Chaos Ball Emotes
			6728, -6733, 6782, -6786, -- Battleground Runner
			12313, -12319, -- Galeskirmish Gladiator
			12533, -12563, -- Tokens: Eld Angavar Weapons (12533), Pit Daemon Light (12543), Storm Lord Light (12550), Fire Drake Medium (12557)
			12769, -- Drakes and Daemons Mask
			13111, 13112, -- Drakes and Daemons Duel Face/Body Art
		},
	},

	----------------------------------------------------------------------------
	{
		GetString(SI_ACTIVITY_FINDER_CATEGORY_TRIBUTE), -- Tales of Tribute
		{
			10684, -10690, -- Pelin's Paragon
			11917, -11923, -- Frandar's Tribute
			12564, -12570, 13079, -- Psijic Psion
		},
	},

	----------------------------------------------------------------------------
	{
		GetAchievementCategoryName(4623), -- Dynamic Encounters
		{
			12306, -12312, -- Alessian Rebel
			14400, -- Blood Scion, Coldharbour
			14773, -14775, -- Werewolf Form
		},
	},

	----------------------------------------------------------------------------
	{
		GetString(SI_COLLECTIBLESTRACKER_SOURCE_STABLES), -- Stablemaster
		{
			3, -- Brown Paint Horse
			4, -- Bay Dun Horse
			5, -- Midnight Steed
			177, -- Snow Bear
			233, -- Hammerfell Camel
			314, -- Hearthfire Kagouti
			1250, -- Ebon Dwarven Horse
			1395, -- Shadowghost Guar
			5073, -- Senche-Cougar
			5224, -- Noble Riverhold Senche-Lion
			5709, -- Sapiarchic Senche-Serval
			7525, -- Yorgrim River Ram
			8028, -- Frostborn Durzog Mangler
			8522, -- Spotted Duneracer Senche-raht
			8906, -- Ja'zennji Siir Fox
			9874, -- Rubyflare Torchnix
			10225, -- Bleakrock Snowdog
			10312, -- Highland Spotted Lynx
			10664, -- Faunfrolic Great Elk
			11644, -- Ashbone Sabre Cat
		},
	},

	----------------------------------------------------------------------------
	{
		GetString(SI_PLAYER_MENU_MISC), -- Miscellaneous
		{
			11183, -- Chronometer of the Tribunal
			12809, -- Hroldan Hammer Mining
			13725, -- Sea Witch Weather Totem
		},
	},
} end

function DataGen.ec() return {
	----------------------------------------------------------------------------
	{
		-- Special empty category for the filter dropdown
		GetString(SI_COLLECTIBLESTRACKER_SOURCE_ALL), { },
	},

	----------------------------------------------------------------------------
	{
		GetString(SI_ACTIVITY_FINDER_CATEGORY_PROMOTIONAL_EVENTS), -- Golden Pursuits
		{
			12239, -- Adventure-Ending Arrow
			12717, -- 10-Year Anniversary Nord Hero

			12592, -12601, -- Evergreen Saturalia
			12808, -- Frost Draugr Runegathering
			12263, -- Shoal Bear

			12716, -- 10-Year Anniversary Elven Hero

			12401, -12407, -- Dibella's Exaltation

			13096, -- Mini Siege Mining

			12718, -- 10-Year Anniversary Breton Hero

			12461, -- Kynareth's Icon of Storm Control
			12732, -- Grand Gallery of Tamriel

			12473, -- Golden Honor

			13452, -- Barrier, Verdant Green
			13789, -- Painting: 10-Year Anniversary
			13794, -- Blade Cloak, Mirrormoor

			12663, -- Coldharbour Dremnaken Runt
			13505, -- Wormwrithe Bear-Lizard

			13764, -- New Life Fish Boon Angler
			13844, -- New Life Frostgathering

			12738, -- Anniversary Fellowship Bear

			13964, -- Heart's Day Kiss

			13894, -- Whale Shark Pangrit Nymphling
			14073, 14074, -- Golden Riften Rogue
			14206, -- Not My Coins!

			13632, 13633, -- Dramaturge's Delirium
			14583, -- Runegathering of the Mad God
		},
	},

	----------------------------------------------------------------------------
	{
		zo_strformat(SI_EVENTCOLLECTIBLES_SOURCE_MORPHS, "2018-2020"),
		{
			{ 5710, 6706, -6709, true }, -- Nascent Indrik
			{ 5067, 6659, -6662 }, 5085, -- Dawnwood / Springtide Indrik
			{ 5068, 6694, -6697 }, 5087, -- Luminous / Shimmering Indrik
			{ 5549, 6698, -6701 }, 6616, -- Onyx / Ebon-Glow Indrik
			{ 5550, 6702, -6705 }, 6617, -- Pure-Snow / Frost-Light Indrik
			{ 6942, 7021, -7024 }, 6950, -- Spectral / Haunting Indrik
			{ 7219, 7791, -7794 }, 7278, -- Icebreath / Rimedusk Indrik
			{ 7468, 8126, -8129 }, 7503, -- Mossheart / Sapling Indrik
			{ 7467, 8465, -8468 }, 7502, -- Crimson / Rosethorn Indrik
		},
	},

	----------------------------------------------------------------------------
	{
		zo_strformat(SI_EVENTCOLLECTIBLES_SOURCE_MORPHS, 2021),
		{
			{ 8124, 8866, -8868, true }, -- Unstable Morpholith
			{ 8469, 8869, -8871 }, -- Deadlands Scorcher
			{  774, 9085, -9087 }, -- Deadlands Firewalker
			{ 8880, 9162, -9164 }, -- Dagonic Quasigriff
			{ 9649, 9737, -9741 }, -- Doomchar Plateau
		},
	},

	----------------------------------------------------------------------------
	{
		zo_strformat(SI_EVENTCOLLECTIBLES_SOURCE_MORPHS, 2022),
		{
			{ 9437, 10068, -10070, true }, -- Soulfire Dragon Illusion
			{ 9436, 10071, 10072, 10179 }, -- Scales of Akatosh
			{ 9775, 10232, -10234 }, -- Aurelic Quasigriff
			{ 9790, 10333, -10335 }, -- Daggerfall Paladin
			{ 10587, 10588, -10590 }, -- Sacred Hourglass of Alkosh
		},
	},

	----------------------------------------------------------------------------
	{
		zo_strformat(SI_EVENTCOLLECTIBLES_SOURCE_MORPHS, 2023),
		{
			{ 10697, 11051, -11053, true }, -- Passion Dancer Blossom
			{ 10913, 11055, -11057 }, -- Passion's Muse
			{ 10661, 11176, -11178 }, -- Meadowbreeze Memories
			{ 10702, 11428, -11430 }, -- Passion Dancer's Attire
			{ 10703, 11509, -11511 }, -- Hoardhunter Ursauk
		},
	},

	----------------------------------------------------------------------------
	{
		zo_strformat(SI_EVENTCOLLECTIBLES_SOURCE_MORPHS, 2024),
		{
			{ 11440, 11893, -11895, true }, -- Molag Bal Illusion Imp
			{ 11497, 11896, -11898 }, -- Planemeld's Master Body Art
			{ 11875, 12408, -12410 }, -- Master of Schemes
			{ 11880, 12508, -12510 }, -- Anchorborn Welwa
			{ 12656, 12694, -12698 }, -- Haven of the Five Companions
		},
	},

	----------------------------------------------------------------------------
	{
		zo_strformat(SI_EVENTCOLLECTIBLES_SOURCE_MORPHS, 2025),
		{
			{ 12665, 13082, -13084, true }, -- Stonewisp of Truth and Law
			{ 13095, 13085, -13087 }, -- Logical Rune Extraction
			{ 12671, 13464, -13466 }, -- Robes of Truth and Law
			{ 12802, 13597, -13599 }, -- Law of Julianos Dwarven Spider
			{ 13759, 13845, -13849 }, -- Wildgrown Chapel of Julianos
		},
	},

	----------------------------------------------------------------------------
	{
		zo_strformat(SI_EVENTCOLLECTIBLES_SOURCE_MORPHS, 2026),
		{
			{ 13739, 14059, -14061, true }, -- Roseblood Bat
			{ 14050, 14062, -14064 }, -- Roseblood Wings Recall
			{ 13910, 14385, -14387 }, -- Thorn's Bite Withersteed
		--	{ 14778, 15010, -15014 }, -- Grotto of Desires
		},
	},

	----------------------------------------------------------------------------
	{
		GetAchievementCategoryName(1892), -- Whitestrake's Mayhem
		{
			1248, -- Midyear Victor's Laurel Wreath

			6365, 6493, 6494, -- Alliance Banners
			8196, -8198, -- Alliance Breton Terriers
			9347, -9352, -- Alliance Banner-Bearer Shields/Staves
			9402, 9403, -- The Black Drake's Warpaint
			9877, 9878, -- Battle-Scarred Markings

			6586, -6592, -- Second Legion
			7310, -7316, -- Legion Zero
			8343, -8352, -- Tools of Domination
			8356, -8362, -- Legion Zero Vigiles
			8749, -8755, -- Ebonsteel Knight
			9746, -9752, -- Black Drake Clanwrap
			10279, -10285, -- House Dufort Banneret
			10710, -10716, -- Gloamsedge
			11243, -11259, -- Sancre Tor Sentry
			11824, -11830, -- Dovah's Du'ul
			12188, -12194, -- Ayleid Lich
			12578, -12584, -- Arkay Unending Cycle
			13229, -13235, -- Truth in Wisdom
			13655, -13661, -- Tava's Goshawk
		},
	},

	----------------------------------------------------------------------------
	{
		GetAchievementCategoryName(4478), -- Hearts Week
		{
			13914, -- Amulet of the Heart
			13634, -13636, 13638, -13640, -- Heart's Day Duelist
		},
	},

	----------------------------------------------------------------------------
	{
		GetAchievementCategoryName(1723), -- Jester's Festival
		{
			1107, -- Crown of Misrule

			1108, -- Cherry Blossom Branch
			1167, -- The Pie of Misrule
			4797, -- Jester's Scintillator
			5885, -- Festive Noise Maker
			5887, -- Jester's Festival Joke Popper
			5910, -- Obnoxious Mute Face Paint
			{ 7270, 7609, -7615 }, -- Sovereign Sow
			9006, -- Playful Prankster's Surprise Box
			10235, -- Cadwell's Surprise Box
			10665, -- Jester's Daedroth Suit
			12793, -- Jester's Deadly Headband

			6097, -6106, -- Cadwell
			7616, 7617, -- Broom and Bucket
			9020, -9026, -- Regal Regalia
			10000, -10006, -- Second Seed Raiment
			12002, -12008, -- Jester's Seeker Suit
			12830, -12835, -- Jester's Mimicry
			13986, -13992, -- One Bad Knight
		},
	},

	----------------------------------------------------------------------------
	{
		GetAchievementCategoryName(3827), -- Anniversary Jubilee
		Data.cakes,
		{
			9977, -- Aurora Firepot Spider
			11535, -- Jubilee Steed

			6141, -6146, 6295, -- Prophet
			6147, -6153, 6155, -- Lyris Titanborn
			6157, -6164, -- Sai Sahan
			6165, 6167, -6173, -- Abnur Tharn
			7331, -7337, 7375, -7379, -- Jephrine Paladin
			9028, -9037, -- Imperial Champion
			9846, -9852, -- Saberkeel Panoply
			10898, -10904, -- Bonemold
			11995, -12001, -- Earthbone Ayleid
			12437, -12441, -- Replicas
			12781, -- Nokvroz's Greatsword Replica
			12836, -12842, -- Worm Cult Hunter
			13979, -13985, -- Dapper Daredevil
		},
	},

	----------------------------------------------------------------------------
	{
		GetString(SI_EVENTCOLLECTIBLES_SOURCE_ZENITHAR),
		{
			10292, -10299, -- High Rock Spellsword
			11090, -11095, -- Kwama Miner's Kit
			11392, -11401, -- Ashen Militia
			12181, -12187, 12430, -- Gold Road Dragoon
			13222, -13228, -- Zenithar Battlesmith
			14276, -14282, -- Battlefield Provisioner
		},
	},

	----------------------------------------------------------------------------
	{
		GetString(SI_EVENTCOLLECTIBLES_SOURCE_UNDAUNTED),
		{
			6814, -6818, 6910, 6911, -- Opal Ilambris
			6819, -6823, 6908, 6909, -- Opal Engine Guardian
			6824, -6828, 6906, 6907, -- Opal Bloodspawn
			6829, -6833, 6912, 6913, -- Opal Troll King
			7751, -7771, -- Opal Iceheart (7751), Opal Lord Warden (7758), Opal Nightflame (7765)
			7803, -7809, -- Opal Swarm Mother
			9807, -9813, -- Opal Chokethorn
			9822, -9828, -- Opal Scourge Harvester
			10420, -10426, -- Opal Earthgore
			10556, -10562, -- Opal Velidreth
			10746, -10752, -- Opal Rkugamz Sentinel
		},
	},

	----------------------------------------------------------------------------
	{
		GetAchievementCategoryName(1546), -- Witches Festival
		{
			439, -- Pumpkin Spectre Mask
			440, -- Scarecrow Spectre Mask
			479, -- Witchmother's Whistle
			1338, -- Hollowjack Spectre Mask
			1339, -- Thicketman Spectre Mask
			5547, -- Witches Festival Ghost Netch
			{ 5590, 6737, -6743 }, -- Apple-Bobbing Cauldron
			6643, -- Skeletal Marionette
			6648, -- Witch's Infernal Hat
			8079, -- Throwing Bones
			8654, -- Marshmallow Toasty Treat
			9389, -- Witch-Tamed Bear-Dog
			9530, -- Witch's Bonfire Dust
			10850, -- Ghastly Visitation
			11499, -- Tome of Forbidden Appetites
			12266, -- Senchal Horned Owl
			12724, -- Plunder Skull Blunder
			12964, 12967, -- Lord Hollowjack
			13607, 13608, -- Hagmatron's Markings

			6753, -6762, 6787, -6794, -- Glenmoril Wyrd
			8324, -8333, -- Grave Dancer
			10360, -10366, -- Witchmother's Servant
			11588, -11594, -- Crowborne Hunter
			12320, -12326, -- Eltheric Revenant
			13380, -13386, -- Wickerchain Soul
		--	14803, -14809, -- Zhekleg
		},
	},

	----------------------------------------------------------------------------
	{
		GetAchievementCategoryName(1677), -- New Life Festival
		{
			597, -- Sword-Swallower's Blade
			598, -- Juggler's Knives
			600, -- Fire-Breather's Torches
			601, -- Mud Ball Pouch
			753, -- Nordic Bather's Towel
			754, -- Colovian Filigreed Hood
			755, -- Colovian Fur Hood
			1168, -- Breda's Bottomless Mead Mug
			5725, -- Crystalfrost
			8221, -- Snowball Buddy
			8541, -- Powderwhite Coney
			12719, -- New Life Winter Storm Robes
			13105, -- Surprising Snowglobe

			7293, -7309, -- Skaal Explorer
			8730, -8739, -- Rkindaleft Dwarven
			9798, -9804, -- Nord Carved
			10720, -10722, 10724, -10726, -- Evergreen
			11817, -11823, -- Morningstar Frostwear
			13641, -13647, -- Fish Boon Pioneer
		},
	},

	----------------------------------------------------------------------------
	{
		GetString(SI_EVENTCOLLECTIBLES_SOURCE_GUILDS),
		{
			3720, -3728, 4892, -- Maelstrom weapons
			9297, -9306, -- Old Orsinium
			11810, -11816, -- Bristleback Hunter
		},
	},

	----------------------------------------------------------------------------
	{
		GetString(SI_EVENTCOLLECTIBLES_SOURCE_MURKMIRE),
		{
			{ 6933, 7353, -7359 }, -- Wooden Grave-Stake
		},
	},

	----------------------------------------------------------------------------
	{
		GetString(SI_EVENTCOLLECTIBLES_SOURCE_DAEDRIC_WAR),
		{
			8125, -- Slag Town Diver
			8186, -- Microtized Verminous Fabricant
			8658, -- Thetys Ramarys's Bait Kit
			9401, -- Gloam Gryphon Fledgling

			8116, -8123, -- Snowhawk Mage
			8674, -8680, -- Doctrine Ordinator
			9753, -9762, -- Evergloam Champion
			13648, -13654, -- Light of Knowledge
		},
	},

	----------------------------------------------------------------------------
	{
		GetString(SI_EVENTCOLLECTIBLES_SOURCE_DRAGON),
		{
			9290, -9296, -- Ja'zennji Siir
			10727, -10733, -- Claw-Dance Acolyte
		},
	},

	----------------------------------------------------------------------------
	{
		GetString(SI_EVENTCOLLECTIBLES_SOURCE_DARK_SKYRIM),
		{
			8367, -8373, -- Sovngarde Stalwart
			10336, -10341, -- Saarthal Scholar
		},
	},

	----------------------------------------------------------------------------
	{
		GetString(SI_EVENTCOLLECTIBLES_SOURCE_OBLIVION),
		{
			{ 6689, 7346, -7352 }, -- Voriplasm
			9429, 9430, -- Shadows of Blackwood
			9431, -- Pellucid Swamp Jelly
			11803, -11809, -- Y'ffre's Fallen-Wood
		},
	},

	----------------------------------------------------------------------------
	{
		GetString(SI_EVENTCOLLECTIBLES_SOURCE_BRETON),
		{
			10514, -10520, -- Oaken Order
			12571, -12577, -- Legacy of the Draoife

			10412, 10413, -- Oak's Promise Markings
			10416, -- Plant Yourself
			11063, -- Statuette: Ascendant Lord
		},
	},

	----------------------------------------------------------------------------
	{
		GetString(SI_EVENTCOLLECTIBLES_SOURCE_TELVANNI),
		{
			11595, -11600, -- Apocrypha Expedition

			11209, -- Ebony Dwarven Scarab
			11368, 11369, -- Nightmare Nest
			11525, -- Kelesan'ruhn
			12272, -- Apocryphal Tome
		},
	},

	----------------------------------------------------------------------------
	{
		GetString(SI_EVENTCOLLECTIBLES_SOURCE_WEST_WEALD),
		{
			12327, -12333, 12368, -12377, -- Tree-Sap Legion

			12262, -- Russet Brekka
			12416, -- Vineyard Voriplasm
			12723, -- Aether-Traveled Varla Stone
		},
	},

	----------------------------------------------------------------------------
	{
		GetString(SI_EVENTCOLLECTIBLES_SOURCE_PANTAM),
		{
			12585, -12591, -- Lion Guard Captain
		},
	},

	----------------------------------------------------------------------------
	{
		GetString(SI_ACTIVITY_FINDER_CATEGORY_WRITHING_WALL),
		{
			13397, -13413, -- Wormwrithe
			13506, -- Wormwrithe Haj Mota Hatchling
			13613, -- Worm King's Crown
			13871, -- Caltrops, Bone
		},
	},

	----------------------------------------------------------------------------
	{
		LCCC.GetZoneName(1559), -- Night Market
		{
			13975, -13978, 13993, 13994, -- Helms/Shoulders
			14077, -- Night's Den
			14197, -14199, -- Replicas
			14207, -- Night Market Curator
			14358, -14365, -- Trophies and Busts
		},
	},

	----------------------------------------------------------------------------
	{
		GetString(SI_EVENTCOLLECTIBLES_SOURCE_HIGH_SEAS),
		{
			14594, -14603, -- Abecean Sea Privateer (weapons)
			14984, -14990, -- Abecean Sea Privateer (body)
			{ 14727, 15065, -15067 }, -- Suncleft Grotto Ornaug
			14743, -- Lilmoth Turtle
			15071, -- Ostentatious Pirate Wig and Hat
		},
	},
} end

LCCC.SetupOnDemandDataTable(Data, DataGen)
